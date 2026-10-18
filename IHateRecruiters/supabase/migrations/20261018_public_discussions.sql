-- Public, persistent discussions. Authors are private auth IDs; no public profiles.
create table if not exists public.discussion_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 category text not null check (category in ('feedback','feature','community')),
 title text not null check (char_length(btrim(title)) between 3 and 160),
 body text not null check (char_length(btrim(body)) between 2 and 5000),
 created_at timestamptz not null default now(),
 moderated_at timestamptz
);
create index if not exists discussion_posts_created_idx on public.discussion_posts (created_at desc);
alter table public.discussion_posts enable row level security;
create policy "discussion_posts_public_read" on public.discussion_posts for select to anon,authenticated using (true);
create policy "discussion_posts_insert" on public.discussion_posts for insert to authenticated with check (author_id=auth.uid() and public.can_contribute());
grant select on public.discussion_posts to anon,authenticated;
grant insert on public.discussion_posts to authenticated;

create table if not exists public.discussion_replies (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.discussion_posts(id) on delete cascade,
 author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 body text not null check (char_length(btrim(body)) between 2 and 2000),
 created_at timestamptz not null default now(),
 moderated_at timestamptz
);
create index if not exists discussion_replies_post_idx on public.discussion_replies (post_id,created_at);
alter table public.discussion_replies enable row level security;
create policy "discussion_replies_public_read" on public.discussion_replies for select to anon,authenticated using (true);
create policy "discussion_replies_insert" on public.discussion_replies for insert to authenticated with check (author_id=auth.uid() and public.can_contribute());
grant select on public.discussion_replies to anon,authenticated;
grant insert on public.discussion_replies to authenticated;

-- Admin moderation replaces text but keeps discussions/replies and references intact.
create or replace function public.moderate_discussion_post(p_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
 if current_user not in ('postgres','service_role') then raise exception 'Administrator only'; end if;
 update public.discussion_posts set title='Post removed by moderation',body='This post has been removed by moderation.',moderated_at=now()
 where id=p_id and moderated_at is null;
 return found;
end;
$$;
revoke all on function public.moderate_discussion_post(uuid) from public,anon,authenticated;
create or replace function public.moderate_discussion_reply(p_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$
begin
 if current_user not in ('postgres','service_role') then raise exception 'Administrator only'; end if;
 update public.discussion_replies set body='This reply has been removed by moderation.',moderated_at=now()
 where id=p_id and moderated_at is null;
 return found;
end;
$$;
revoke all on function public.moderate_discussion_reply(uuid) from public,anon,authenticated;
