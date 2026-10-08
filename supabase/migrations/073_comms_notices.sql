-- Universe-wide Comms: News and Admin notices, readable by every commander.
-- Writes stay on operator RPCs (private.require_debug). Table is not granted to clients.

create table public.comms_notices (
  id bigint generated always as identity primary key,
  channel text not null check (channel in ('news', 'admin')),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.profiles (user_id) on delete set null
);

create index comms_notices_channel_created_at_idx
  on public.comms_notices (channel, created_at desc);

alter table public.comms_notices enable row level security;
alter table public.comms_notices force row level security;

revoke all on table public.comms_notices from public, anon, authenticated;

create or replace function public.get_comms_notices()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'channel', n.channel,
        'title', n.title,
        'body', n.body,
        'created_at', n.created_at
      )
      order by n.created_at desc
    )
    from (
      select id, channel, title, body, created_at
      from public.comms_notices
      order by created_at desc
      limit 80
    ) n
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_comms_notices() from public, anon;
grant execute on function public.get_comms_notices() to authenticated;

create or replace function public.post_comms_notice(p_channel text, p_title text, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  channel text := lower(btrim(coalesce(p_channel, '')));
  headline text := btrim(coalesce(p_title, ''));
  copy text := btrim(coalesce(p_body, ''));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();
  if channel not in ('news', 'admin') then
    raise exception 'Unknown channel.';
  end if;
  if headline = '' or copy = '' then
    raise exception 'Title and body are required.';
  end if;
  insert into public.comms_notices (channel, title, body, created_by)
  values (channel, left(headline, 80), left(copy, 4000), uid);
  return public.get_comms_notices();
end;
$$;

revoke all on function public.post_comms_notice(text, text, text) from public, anon;
grant execute on function public.post_comms_notice(text, text, text) to authenticated;

create or replace function public.delete_comms_notice(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  deleted integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();
  if p_id is null then
    raise exception 'Unknown notice.';
  end if;
  delete from public.comms_notices where id = p_id;
  get diagnostics deleted = row_count;
  if deleted = 0 then
    raise exception 'Unknown notice.';
  end if;
  return public.get_comms_notices();
end;
$$;

revoke all on function public.delete_comms_notice(bigint) from public, anon;
grant execute on function public.delete_comms_notice(bigint) to authenticated;

notify pgrst, 'reload schema';
