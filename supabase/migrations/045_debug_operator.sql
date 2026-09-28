-- Operator-only debug: hide via empire state.debug, refuse RPCs for everyone else.

create schema if not exists private;

create or replace function private.debug_operator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    where u.id = (select auth.uid())
      and lower(u.email) = 'zanugreuu@gmail.com'
  );
$$;

revoke all on function private.debug_operator() from public, anon, authenticated;

create or replace function private.require_debug()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.debug_operator() then
    raise exception 'Not allowed.';
  end if;
end;
$$;

revoke all on function private.require_debug() from public, anon, authenticated;

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
    'colonies', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'galaxy', c.galaxy,
        'system', c.system,
        'slot', c.slot,
        'is_homeworld', c.is_homeworld
      ) order by c.is_homeworld desc, c.id), '[]'::jsonb)
      from public.planets c
      where c.owner_id = uid
    ),
    'empire', to_jsonb(e) || jsonb_build_object(
      'raiders_queued', p.ships_queued,
      'ship_building', p.ship_building,
      'raider_completes_at', p.ship_completes_at
    ),
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
          when f.mission in ('harvest', 'harvest_return') then coalesce(dp.name, 'Debris field')
          when f.mission in ('colonize', 'colonize_return') then coalesce(dp.name, 'Empty slot')
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
        'ship_count', case
          when f.composition is not null and f.composition <> '{}'::jsonb then (
            select coalesce(sum(greatest(value::integer, 0)), 0)::integer
            from jsonb_each_text(f.composition)
          )
          else f.raiders
        end,
        'composition', case
          when f.owner_id is distinct from uid then '{}'::jsonb
          else f.composition
        end
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
      left join public.planets op on op.id = f.origin_planet_id
      left join public.profiles ap on ap.user_id = f.owner_id
      where f.status = 'en_route'
        and (f.owner_id = uid or f.dest_planet_id in (select pl.id from public.planets pl where pl.owner_id = uid))
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
    'server_now', at,
    'debug', private.debug_operator()
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

create or replace function public.debug_fill_resources()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home public.planets%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  perform private.catch_up(uid, at);

  select e.home_planet_id into home.id from public.empires e where e.user_id = uid;
  select * into home from public.planets where id = home.id for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set
    ore = private.storage_cap(home.ore_storage),
    crystal = private.storage_cap(home.crystal_storage),
    deuterium = private.storage_cap(home.deuterium_storage),
    last_harvested_at = at
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.debug_grant_fleet()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home public.planets%rowtype;
  fleet jsonb := '{
    "light_fighter": 20,
    "heavy_fighter": 20,
    "cruiser": 10,
    "battleship": 10,
    "battlecruiser": 5,
    "bomber": 5,
    "destroyer": 5,
    "deathstar": 1,
    "small_cargo": 20,
    "large_cargo": 20,
    "colony_ship": 10,
    "recycler": 20,
    "espionage_probe": 50,
    "reaper": 5,
    "pathfinder": 5,
    "crawler": 10,
    "solar_satellite": 10
  }'::jsonb;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  perform private.catch_up(uid, at);

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set deuterium = greatest(deuterium, least(private.storage_cap(deuterium_storage), 50000))
  where id = home.id;

  update public.empires
  set
    ships = fleet,
    raiders = 20,
    propulsion_level = greatest(propulsion_level, 6),
    energy_tech = greatest(energy_tech, 1),
    impulse_drive = greatest(impulse_drive, 5),
    espionage_tech = greatest(espionage_tech, 2),
    astrophysics = greatest(astrophysics, 1),
    shielding_tech = greatest(shielding_tech, 2)
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.debug_grant_fleet() from public, anon;
grant execute on function public.debug_grant_fleet() to authenticated;

create or replace function public.reset_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home_id bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  select p.id into home_id
  from public.planets p
  where p.owner_id = uid and p.is_homeworld
  order by p.id
  limit 1;
  if home_id is null then
    select home_planet_id into home_id from public.empires where user_id = uid;
  end if;

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid);
  delete from public.battle_reports where user_id = uid;
  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

  delete from public.planets
  where owner_id = uid and id is distinct from home_id;

  update public.empires set home_planet_id = home_id where user_id = uid;

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    deuterium = 0,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    deuterium_extractor = 0,
    power_plant = 1,
    fusion_reactor = 0,
    ore_storage = 0,
    crystal_storage = 0,
    deuterium_storage = 0,
    robotics_factory = 0,
    shipyard = 0,
    research_lab = 0,
    alliance_depot = 0,
    missile_silo = 0,
    nanite_factory = 0,
    terraformer = 0,
    lunar_base = 0,
    phalanx_sensor = 0,
    stargate = 0,
    space_station = 0,
    upgrade_building = null,
    upgrade_completes_at = null,
    small_shield_dome = 0,
    large_shield_dome = 0,
    rocket_launcher = 0,
    light_laser = 0,
    heavy_laser = 0,
    ion_cannon = 0,
    gauss_cannon = 0,
    plasma_turret = 0,
    antiballistic_missile = 0,
    interplanetary_missile = 0,
    defence_building = null,
    defences_queued = 0,
    defence_completes_at = null,
    ship_building = null,
    ships_queued = 0,
    ship_completes_at = null,
    is_homeworld = true
  where id = home_id;

  update public.empires
  set
    propulsion_level = 0,
    energy_tech = 0,
    laser_tech = 0,
    ion_tech = 0,
    hyperspace_tech = 0,
    plasma_tech = 0,
    impulse_drive = 0,
    hyperspace_drive = 0,
    espionage_tech = 0,
    computer_tech = 0,
    astrophysics = 0,
    intergalactic_research_network = 0,
    graviton_tech = 0,
    weapons_tech = 0,
    shielding_tech = 0,
    armour_tech = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    ships = '{}'::jsonb,
    ship_building = null,
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null,
    claimed_directives = '[]'::jsonb
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.debug_set_economy_speed(p_speed integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();
  if p_speed is null or p_speed not in (1, 3, 5) then
    raise exception 'Economy speed must be 1, 3, or 5.';
  end if;

  perform public.reset_empire();

  update public.empires
  set economy_speed = p_speed
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.set_pirate_raids(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  e public.empires%rowtype;
  home public.planets%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  if not found then
    raise exception 'No empire.';
  end if;
  select * into home from public.planets where id = e.home_planet_id for update;

  if p_enabled then
    update public.empires
    set
      pirate_raids_enabled = true,
      next_pirate_at = at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)))
    where user_id = uid;
  else
    update public.fleets
    set
      status = 'completed',
      report = 'Pirate raid cancelled.'
    where owner_id is null
      and dest_planet_id = e.home_planet_id
      and status = 'en_route'
      and mission = 'attack';

    update public.empires
    set
      pirate_raids_enabled = false,
      next_pirate_at = null
    where user_id = uid;
  end if;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.spawn_pirates()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  e public.empires%rowtype;
  home public.planets%rowtype;
  ships integer;
  eta timestamptz;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  ships := private.pirate_wave_size(private.defence_units(home));
  eta := at + make_interval(secs => 600);

  insert into public.fleets (
    owner_id,
    origin_planet_id,
    dest_planet_id,
    dest_galaxy,
    dest_system,
    dest_slot,
    raiders,
    mission,
    arrives_at,
    composition
  )
  values (
    null,
    home.id,
    home.id,
    home.galaxy,
    home.system,
    home.slot,
    ships,
    'attack',
    eta,
    jsonb_build_object('pirate', ships)
  );

  if e.pirate_raids_enabled then
    update public.empires
    set next_pirate_at = eta + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)))
    where user_id = uid;
  else
    update public.empires
    set next_pirate_at = null
    where user_id = uid;
  end if;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

notify pgrst, 'reload schema';
