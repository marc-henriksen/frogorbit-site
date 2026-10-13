-- IHateRecruiters product analytics: daily activity, UTC calendar days.
-- Change the lookback window by editing the interval below.
-- Counts are historical actions, not unique people or current database row counts.
-- Deleted content still contributes to creation counts.
with days as (
  select generate_series(
    (current_timestamp at time zone 'UTC')::date - 29,
    (current_timestamp at time zone 'UTC')::date,
    interval '1 day'
  )::date as day
),
daily as (
  select (occurred_at at time zone 'UTC')::date as day,
    count(*) filter (where event_type = 'page_view')::int as page_views,
    count(*) filter (where event_type = 'job_view')::int as job_views,
    count(*) filter (where event_type = 'job_outbound_click')::int as outbound_clicks,
    count(*) filter (where event_type = 'account_created')::int as accounts_created,
    count(*) filter (where event_type = 'account_deleted')::int as accounts_deleted,
    count(*) filter (where event_type = 'job_shared')::int as jobs_shared,
    count(*) filter (where event_type = 'job_expired')::int as jobs_expired,
    count(*) filter (where event_type = 'job_deleted')::int as jobs_deleted,
    count(*) filter (where event_type = 'question_created')::int as questions_created,
    count(*) filter (where event_type = 'reply_created')::int as replies_created,
    count(*) filter (where event_type = 'question_deleted')::int as questions_deleted,
    count(*) filter (where event_type = 'reply_deleted')::int as replies_deleted
  from public.analytics_events
  where occurred_at >= ((current_timestamp at time zone 'UTC')::date - 29) at time zone 'UTC'
  group by 1
)
select d.day, coalesce(a.page_views,0) as page_views,
  coalesce(a.job_views,0) as job_views,
  coalesce(a.outbound_clicks,0) as outbound_clicks,
  coalesce(a.accounts_created,0) as accounts_created,
  coalesce(a.accounts_deleted,0) as accounts_deleted,
  coalesce(a.jobs_shared,0) as jobs_shared,
  coalesce(a.jobs_expired,0) as jobs_expired,
  coalesce(a.jobs_deleted,0) as jobs_deleted,
  coalesce(a.questions_created,0) as questions_created,
  coalesce(a.replies_created,0) as replies_created,
  coalesce(a.questions_deleted,0) as questions_deleted,
  coalesce(a.replies_deleted,0) as replies_deleted
from days d left join daily a using(day)
order by d.day;