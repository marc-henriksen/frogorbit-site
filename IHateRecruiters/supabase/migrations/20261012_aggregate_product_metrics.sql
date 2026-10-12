-- Daily aggregate counters. No visitor identifiers, IP addresses, or individual event rows.
create table if not exists public.product_metrics_daily (
 day date not null default (now() at time zone 'utc')::date,
 event_type text not null check (event_type in ('page_view','job_view','job_outbound_click')),
 page text not null check (page in ('home','job','contribute','about')),
 job_id uuid,
 total bigint not null default 0 check (total >= 0)
);
create unique index if not exists product_metrics_daily_unique
 on public.product_metrics_daily (day,event_type,page,coalesce(job_id,'00000000-0000-0000-0000-000000000000'::uuid));
alter table public.product_metrics_daily enable row level security;
revoke all on public.product_metrics_daily from anon,authenticated;
create or replace function public.record_product_event(p_event text,p_page text,p_job_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not (
  (p_event='page_view' and p_page in ('home','job','contribute','about') and p_job_id is null)
  or (p_event in ('job_view','job_outbound_click') and p_page='job' and p_job_id is not null
   and exists(select 1 from public.jobs j where j.id=p_job_id and j.expires_at>now()))
 ) then raise exception 'Invalid product event'; end if;
 insert into public.product_metrics_daily(day,event_type,page,job_id,total)
 values ((now() at time zone 'utc')::date,p_event,p_page,p_job_id,1)
 on conflict (day,event_type,page,coalesce(job_id,'00000000-0000-0000-0000-000000000000'::uuid))
 do update set total=public.product_metrics_daily.total+1;
end $$;
revoke all on function public.record_product_event(text,text,uuid) from public;
grant execute on function public.record_product_event(text,text,uuid) to anon,authenticated;
