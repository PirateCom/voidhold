-- Alliance depot, moon facilities, and space dock are not in this universe.

do $$
begin
  if to_regprocedure('public.start_upgrade_live(text)') is null then
    alter function public.start_upgrade(text) rename to start_upgrade_live;
  end if;
end $$;

create or replace function public.start_upgrade(p_building text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_building in (
    'alliance_depot',
    'lunar_base',
    'phalanx_sensor',
    'stargate',
    'space_station'
  ) then
    raise exception 'That facility is not available.';
  end if;
  return public.start_upgrade_live(p_building);
end;
$$;

revoke all on function public.start_upgrade_live(text) from public, anon, authenticated;
revoke all on function public.start_upgrade(text) from public, anon;
grant execute on function public.start_upgrade(text) to authenticated;

notify pgrst, 'reload schema';
