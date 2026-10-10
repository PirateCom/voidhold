-- Operator-only universe census for the Commander page.

create or replace function public.get_universe_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  ships_docked bigint;
  ships_flight bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  select coalesce(sum((kv.value)::bigint), 0)
  into ships_docked
  from public.empires e
  cross join lateral jsonb_each_text(coalesce(e.ships, '{}'::jsonb)) kv
  where (kv.value)::bigint > 0;

  select coalesce(sum((kv.value)::bigint), 0)
  into ships_flight
  from public.fleets f
  cross join lateral jsonb_each_text(coalesce(f.composition, '{}'::jsonb)) kv
  where f.status = 'en_route'
    and (kv.value)::bigint > 0;

  return jsonb_build_object(
    'generated_at', at,
    'commanders', (select count(*)::integer from public.empires),
    'auth_users', (select count(*)::integer from auth.users),
    'commander_cap', private.max_registered_users(),
    'registration_open', (select count(*)::integer from auth.users) < private.max_registered_users(),
    'fake_commander', exists (
      select 1 from public.empires e where e.user_id = private.fake_commander_id()
    ),
    'active_24h', (
      select count(*)::integer
      from public.empires e
      join public.planets p on p.id = e.home_planet_id
      where p.last_harvested_at >= at - interval '24 hours'
    ),
    'active_7d', (
      select count(*)::integer
      from public.empires e
      join public.planets p on p.id = e.home_planet_id
      where p.last_harvested_at >= at - interval '7 days'
    ),
    'planets', (select count(*)::integer from public.planets where owner_id is not null),
    'homeworlds', (select count(*)::integer from public.planets where is_homeworld),
    'colonies', (
      select count(*)::integer
      from public.planets
      where owner_id is not null and not is_homeworld
    ),
    'occupied_systems', (
      select count(*)::integer
      from (
        select distinct galaxy, system
        from public.planets
        where owner_id is not null
      ) s
    ),
    'total_score', (
      select coalesce(sum(private.score_points(e.user_id)), 0)::bigint
      from public.empires e
    ),
    'ore', (select coalesce(sum(ore), 0)::bigint from public.planets),
    'crystal', (select coalesce(sum(crystal), 0)::bigint from public.planets),
    'deuterium', (select coalesce(sum(deuterium), 0)::bigint from public.planets),
    'ships_docked', coalesce(ships_docked, 0),
    'ships_in_flight', coalesce(ships_flight, 0),
    'fleets_en_route', (
      select count(*)::integer from public.fleets where status = 'en_route'
    ),
    'player_fleets', (
      select count(*)::integer
      from public.fleets
      where status = 'en_route' and owner_id is not null
    ),
    'pirate_fleets', (
      select count(*)::integer
      from public.fleets
      where status = 'en_route' and owner_id is null
    ),
    'mining_holds', (
      select count(*)::integer
      from public.fleets
      where status = 'en_route' and mission = 'mine_hold'
    ),
    'belts', (select count(*)::integer from public.asteroid_belts),
    'empty_belts', (
      select count(*)::integer
      from public.asteroid_belts
      where ore = 0 and crystal = 0
    ),
    'belt_ore', (select coalesce(sum(ore), 0)::bigint from public.asteroid_belts),
    'belt_crystal', (select coalesce(sum(crystal), 0)::bigint from public.asteroid_belts),
    'upgrades_in_progress', (
      select count(*)::integer
      from public.planets
      where upgrade_building is not null
    )
  );
end;
$$;

revoke all on function public.get_universe_stats() from public, anon;
grant execute on function public.get_universe_stats() to authenticated;

notify pgrst, 'reload schema';
