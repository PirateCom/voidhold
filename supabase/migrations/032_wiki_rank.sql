-- Wiki Points: Scores = floor(resources spent / 1000) on completed buildings,
-- research, ships, and defence. Fuel and in-progress jobs do not count.
-- Research ranking = sum of tech levels. Fleet ranking = ship count.

create or replace function private.spent_on_building(id text, lvl integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select coalesce((
    select sum(
      coalesce(private.building_cost_ore(id, g.i), 0)
      + coalesce(private.building_cost_crystal(id, g.i), 0)
      + coalesce(private.building_cost_deuterium(id, g.i), 0)
    )
    from pg_catalog.generate_series(0, greatest(coalesce(lvl, 0), 0) - 1) as g(i)
  ), 0)::bigint;
$$;

create or replace function private.spent_on_research(id text, lvl integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select coalesce((
    select sum(
      coalesce(private.research_tech_cost_ore(id, g.i), 0)
      + coalesce(private.research_tech_cost_crystal(id, g.i), 0)
      + coalesce(private.research_tech_cost_deuterium(id, g.i), 0)
    )
    from pg_catalog.generate_series(0, greatest(coalesce(lvl, 0), 0) - 1) as g(i)
  ), 0)::bigint;
$$;

create or replace function private.unit_resource_cost(kind text, id text)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case kind
    when 'ship' then
      coalesce(private.ship_cost_ore(id), 0)
      + coalesce(private.ship_cost_crystal(id), 0)
      + coalesce(private.ship_cost_deuterium(id), 0)
    when 'defence' then
      coalesce(private.defence_cost_ore(id), 0)
      + coalesce(private.defence_cost_crystal(id), 0)
      + coalesce(private.defence_cost_deuterium(id), 0)
    else 0
  end::bigint;
$$;

create or replace function private.planet_defence_count(p public.planets, id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then p.small_shield_dome
    when 'large_shield_dome' then p.large_shield_dome
    when 'rocket_launcher' then p.rocket_launcher
    when 'light_laser' then p.light_laser
    when 'heavy_laser' then p.heavy_laser
    when 'ion_cannon' then p.ion_cannon
    when 'gauss_cannon' then p.gauss_cannon
    when 'plasma_turret' then p.plasma_turret
    when 'antiballistic_missile' then p.antiballistic_missile
    when 'interplanetary_missile' then p.interplanetary_missile
    else 0
  end;
$$;

create or replace function private.fleet_ship_json(composition jsonb, raiders integer)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when composition is not null and composition <> '{}'::jsonb then composition
    when coalesce(raiders, 0) > 0 then jsonb_build_object('small_cargo', raiders)
    else '{}'::jsonb
  end;
$$;

create or replace function private.score_resources(uid uuid)
returns bigint
language plpgsql
stable
set search_path = ''
as $$
declare
  p public.planets%rowtype;
  e public.empires%rowtype;
  spent bigint := 0;
  asset_id text;
  n integer;
  kv record;
begin
  select * into e from public.empires where user_id = uid;
  if not found then
    return 0;
  end if;
  select * into p from public.planets pl where pl.id = e.home_planet_id;
  if not found then
    return 0;
  end if;

  foreach asset_id in array array[
    'ore_mine', 'crystal_mine', 'deuterium_extractor', 'power_plant', 'fusion_reactor',
    'ore_storage', 'crystal_storage', 'deuterium_storage',
    'robotics_factory', 'shipyard', 'research_lab', 'alliance_depot', 'missile_silo',
    'nanite_factory', 'terraformer', 'lunar_base', 'phalanx_sensor', 'stargate', 'space_station'
  ]
  loop
    spent := spent + private.spent_on_building(asset_id, private.planet_building_level(p, asset_id));
  end loop;

  foreach asset_id in array array[
    'energy_tech', 'laser_tech', 'ion_tech', 'hyperspace_tech', 'plasma_tech',
    'combustion_drive', 'impulse_drive', 'hyperspace_drive',
    'espionage_tech', 'computer_tech', 'astrophysics', 'intergalactic_research_network',
    'graviton_tech', 'weapons_tech', 'shielding_tech', 'armour_tech'
  ]
  loop
    spent := spent + private.spent_on_research(asset_id, private.research_level(e, asset_id));
  end loop;

  foreach asset_id in array array[
    'small_shield_dome', 'large_shield_dome', 'rocket_launcher', 'light_laser',
    'heavy_laser', 'ion_cannon', 'gauss_cannon', 'plasma_turret',
    'antiballistic_missile', 'interplanetary_missile'
  ]
  loop
    n := greatest(coalesce(private.planet_defence_count(p, asset_id), 0), 0);
    spent := spent + n * private.unit_resource_cost('defence', asset_id);
  end loop;

  for kv in
    select key, value
    from pg_catalog.jsonb_each_text(coalesce(e.ships, '{}'::jsonb))
  loop
    n := greatest(coalesce(kv.value::integer, 0), 0);
    spent := spent + n * private.unit_resource_cost('ship', kv.key);
  end loop;

  for kv in
    select j.key, j.value
    from public.fleets f
    cross join lateral pg_catalog.jsonb_each_text(private.fleet_ship_json(f.composition, f.raiders)) as j
    where f.owner_id = uid
      and f.status = 'en_route'
  loop
    n := greatest(coalesce(kv.value::integer, 0), 0);
    spent := spent + n * private.unit_resource_cost('ship', kv.key);
  end loop;

  return spent;
end;
$$;

create or replace function private.score_points(uid uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select floor(private.score_resources(uid)::numeric / 1000)::bigint;
$$;

create or replace function private.research_rank_points(uid uuid)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select
      e.energy_tech + e.laser_tech + e.ion_tech + e.hyperspace_tech + e.plasma_tech
      + e.propulsion_level + e.impulse_drive + e.hyperspace_drive
      + e.espionage_tech + e.computer_tech + e.astrophysics + e.intergalactic_research_network
      + e.graviton_tech + e.weapons_tech + e.shielding_tech + e.armour_tech
    from public.empires e
    where e.user_id = uid
  ), 0);
$$;

create or replace function private.fleet_rank_points(uid uuid)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select sum(greatest(coalesce(kv.value::integer, 0), 0))
    from public.empires e,
      pg_catalog.jsonb_each_text(coalesce(e.ships, '{}'::jsonb)) kv
    where e.user_id = uid
  ), 0)::integer
  + coalesce((
    select sum(greatest(coalesce(j.value::integer, 0), 0))
    from public.fleets f
    cross join lateral pg_catalog.jsonb_each_text(private.fleet_ship_json(f.composition, f.raiders)) as j
    where f.owner_id = uid
      and f.status = 'en_route'
  ), 0)::integer;
$$;

create or replace function private.rank_payload(uid uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  pts bigint;
begin
  pts := private.score_points(uid);
  return jsonb_build_object(
    'points', pts,
    'place', 1 + (
      select count(*)
      from public.empires o
      where private.score_points(o.user_id) > pts
         or (private.score_points(o.user_id) = pts and o.user_id < uid)
    ),
    'total', (select count(*) from public.empires),
    'research', private.research_rank_points(uid),
    'fleet', private.fleet_rank_points(uid)
  );
end;
$$;

revoke all on function private.spent_on_building(text, integer) from public, anon, authenticated;
revoke all on function private.spent_on_research(text, integer) from public, anon, authenticated;
revoke all on function private.unit_resource_cost(text, text) from public, anon, authenticated;
revoke all on function private.planet_defence_count(public.planets, text) from public, anon, authenticated;
revoke all on function private.fleet_ship_json(jsonb, integer) from public, anon, authenticated;
revoke all on function private.score_resources(uuid) from public, anon, authenticated;
revoke all on function private.score_points(uuid) from public, anon, authenticated;
revoke all on function private.research_rank_points(uuid) from public, anon, authenticated;
revoke all on function private.fleet_rank_points(uuid) from public, anon, authenticated;
revoke all on function private.rank_payload(uuid) from public, anon, authenticated;

create or replace function private.empire_state_json(uid uuid, at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.catch_up(uid, at);
  perform private.catch_up(o.user_id, at)
  from public.empires o
  where o.user_id is distinct from uid;

  select jsonb_build_object(
    'profile', jsonb_build_object(
      'user_id', pr.user_id,
      'display_name', pr.display_name
    ),
    'planet', to_jsonb(p),
    'empire', to_jsonb(e),
    'star', jsonb_build_object(
      'type', coalesce(s.star_type, 'medium'),
      'multiplier', private.star_multiplier(coalesce(s.star_type, 'medium'))
    ),
    'rank', private.rank_payload(uid),
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', case
          when coalesce(f.dest_slot, dp.slot) = 16 then 'Outer space'
          else dp.name
        end,
        'dest_galaxy', coalesce(f.dest_galaxy, dp.galaxy),
        'dest_system', coalesce(f.dest_system, dp.system),
        'dest_slot', coalesce(f.dest_slot, dp.slot),
        'origin_name', coalesce(op.name, 'Deep space'),
        'origin_galaxy', coalesce(op.galaxy, dp.galaxy),
        'origin_system', coalesce(op.system, dp.system),
        'origin_slot', coalesce(op.slot, dp.slot),
        'created_at', f.created_at,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'cargo_deuterium', f.cargo_deuterium,
        'status', f.status,
        'report', f.report,
        'inbound', (f.owner_id is distinct from uid),
        'attacker_name', case when f.owner_id is null then 'Pirates' else ap.display_name end,
        'ship_count', f.raiders,
        'composition', f.composition
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
      left join public.planets op on op.id = f.origin_planet_id
      left join public.profiles ap on ap.user_id = f.owner_id
      where f.status = 'en_route'
        and (f.owner_id = uid or f.dest_planet_id = p.id)
    ),
    'reports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'title', r.title,
        'body', r.body,
        'loot_ore', r.loot_ore,
        'loot_crystal', r.loot_crystal
      ) order by r.created_at desc), '[]'::jsonb)
      from (
        select * from public.battle_reports
        where user_id = uid
        order by created_at desc
        limit 15
      ) r
    ),
    'server_now', at
  )
  into result
  from public.empires e
  join public.planets p on p.id = e.home_planet_id
  join public.profiles pr on pr.user_id = e.user_id
  left join public.solar_systems s on s.galaxy = p.galaxy and s.system = p.system
  where e.user_id = uid;

  return result;
end;
$$;
