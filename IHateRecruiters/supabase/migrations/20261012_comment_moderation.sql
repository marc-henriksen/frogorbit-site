-- Moderate an individual question or reply without deleting its thread.
-- Moderation is performed from the Supabase SQL Editor using:
-- select public.moderate_comment('COMMENT_UUID');
-- The original comment text is permanently replaced, and replies remain.
alter table public.comments add column if not exists moderated_at timestamptz;
comment on column public.comments.moderated_at is 'Set by an administrator when comment body is replaced with moderation notice. Original body is discarded.';

create or replace function public.moderate_comment(p_comment_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'Administrator only';
  end if;
  update public.comments
  set body = 'This comment has been removed by moderation.',
      moderated_at = now()
  where id = p_comment_id and moderated_at is null;
  return found;
end;
$$;
revoke all on function public.moderate_comment(uuid) from public, anon, authenticated;
comment on function public.moderate_comment(uuid) is 'Admin-only soft moderation. Run via SQL editor; preserves reply thread and removes original text.';
