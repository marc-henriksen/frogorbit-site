-- IHateRecruiters: minimal, expiring job data and private email identities
create extension if not exists pg_cron with schema pg_catalog;

create table public.blocked_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text,
  blocked_at timestamptz not null default now()
);
alter table public.blocked_users enable row level security;
revoke all on public.blocked_users from anon, authenticated;

create function public.can_contribute() returns boolean
language sql stable security definer set search_path = ''
as $$ select auth.uid() is not null and not exists
  (select 1 from public.blocked_users b where b.user_id = auth.uid()) $$;
revoke all on function public.can_contribute() from public, anon;
grant execute on function public.can_contribute() to authenticated;

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  url text not null check (length(url) between 12 and 2048 and url ~* '^https://[^[:space:]]+$'),
  title text not null check (length(trim(title)) between 2 and 160),
  company text not null check (length(trim(company)) between 2 and 160),
  author_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  constraint jobs_expiration check (expires_at > created_at)
);
create index jobs_active_idx on public.jobs (expires_at, created_at desc);
create index jobs_author_idx on public.jobs (author_id);
alter table public.jobs enable row level security;
create policy jobs_public_read on public.jobs for select to anon, authenticated
  using (expires_at > now());
create policy jobs_author_insert on public.jobs for insert to authenticated
  with check (author_id = auth.uid() and public.can_contribute());
-- Prevent clients from changing expiration, author or any job data after posting
grant select on public.jobs to anon, authenticated;
grant insert (url, title, company) on public.jobs to authenticated;

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  body text not null check (length(trim(body)) between 2 and 2000),
  created_at timestamptz not null default now()
);
create index comments_job_idx on public.comments(job_id, created_at);
create index comments_author_idx on public.comments(author_id);
alter table public.comments enable row level security;
create policy comments_public_read on public.comments for select to anon, authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id and j.expires_at > now()));
create policy comments_author_insert on public.comments for insert to authenticated
  with check (author_id = auth.uid() and public.can_contribute()
    and exists (select 1 from public.jobs j where j.id = job_id and j.expires_at > now()));
grant select on public.comments to anon, authenticated;
grant insert (job_id, body) on public.comments to authenticated;

-- Account deletion removes authored jobs (and their threads), authored comments and auth identity
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = ''
as $$
declare current_user_id uuid := auth.uid();
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  delete from auth.users where id = current_user_id;
  if not found then raise exception 'Account not found'; end if;
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Jobs and their comments are removed from the active database automatically
select cron.schedule('ihaterecruiters_expire_jobs', '17 * * * *',
  $$delete from public.jobs where expires_at <= now()$$);
