-- Append-only product analytics ledger, without account or visitor identifiers.
create table public.analytics_events (
 id bigint generated always as identity primary key,
 occurred_at timestamptz not null default now(),
 event_type text not null check (event_type in (
 'page_view','job_view','job_outbound_click','account_created','account_deleted',
 'job_shared','job_expired','job_deleted','question_created','reply_created',
 'question_deleted','reply_deleted')),
 page text,
 job_id uuid
);
create index analytics_events_time_idx on public.analytics_events(occurred_at desc);
create index analytics_events_type_time_idx on public.analytics_events(event_type,occurred_at desc);
alter table public.analytics_events enable row level security;
revoke all on public.analytics_events from public,anon,authenticated;
create function public.prevent_analytics_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Analytics events are append-only'; end $$;
create trigger analytics_events_immutable before update or delete on public.analytics_events
for each row execute function public.prevent_analytics_mutation();

create or replace function public.record_product_event(p_event text,p_page text,p_job_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not (
 (p_event='page_view' and p_page in ('home','job','contribute','about') and p_job_id is null)
 or (p_event in ('job_view','job_outbound_click') and p_page='job' and p_job_id is not null
 and exists(select 1 from public.jobs j where j.id=p_job_id and j.expires_at>now()))
 ) then raise exception 'Invalid product event'; end if;
 insert into public.analytics_events(event_type,page,job_id) values(p_event,p_page,p_job_id);
end $$;
revoke all on function public.record_product_event(text,text,uuid) from public;
grant execute on function public.record_product_event(text,text,uuid) to anon,authenticated;

create function public.log_job_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.analytics_events(event_type) values('job_shared');
  return new;
 end if;
 insert into public.analytics_events(event_type)
 values(case when old.expires_at<=now() then 'job_expired' else 'job_deleted' end);
 return old;
end $$;
create trigger analytics_job_insert after insert on public.jobs
for each row execute function public.log_job_event();
create trigger analytics_job_delete after delete on public.jobs
for each row execute function public.log_job_event();

create function public.log_comment_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.analytics_events(event_type)
  values(case when new.parent_id is null then 'question_created' else 'reply_created' end);
  return new;
 end if;
 insert into public.analytics_events(event_type)
 values(case when old.parent_id is null then 'question_deleted' else 'reply_deleted' end);
 return old;
end $$;
create trigger analytics_comment_insert after insert on public.comments
for each row execute function public.log_comment_event();
create trigger analytics_comment_delete after delete on public.comments
for each row execute function public.log_comment_event();

create function public.log_account_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.analytics_events(event_type)
 values(case when tg_op='INSERT' then 'account_created' else 'account_deleted' end);
 if tg_op='INSERT' then return new; end if;
 return old;
end $$;
create trigger analytics_account_insert after insert on auth.users
for each row execute function public.log_account_event();
create trigger analytics_account_delete after delete on auth.users
for each row execute function public.log_account_event();

comment on table public.product_metrics_daily is 'Legacy aggregate counters before append-only analytics migration; do not write new events here.';
