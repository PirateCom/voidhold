-- Deuterium production, wiki spend, fusion burn, and fleet fuel.

create or replace function private.deut_prod_per_hour(level integer, temp_max integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when level is null or level <= 0 then 0
    else greatest(
      0,
      floor(10 * level * power(1.44, level) * (1.36 - 0.004 * coalesce(temp_max, 30)))
    )::bigint
  end;
$$;

create or replace function private.fusion_deut_burn_per_hour(level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when level is null or level <= 0 then 0
    else floor(10 * level * power(1.1, level))::bigint
  end;
$$;

create or replace function private.deut_energy_drain(level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when level is null or level <= 0 then 0
    else floor(20 * level * power(1.1, level))
  end;
$$;

create or replace function private.fusion_output(level integer, energy_tech integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when level is null or level <= 0 then 0
    else floor(30 * level * power(1.05 + 0.01 * greatest(coalesce(energy_tech, 0), 0), level))
  end;
$$;

create or replace function private.energy_factor(
  ore_mine integer,
  crystal_mine integer,
  power_plant integer,
  star_type text,
  deut_mine integer default 0,
  fusion integer default 0,
  energy_tech integer default 0
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when private.mine_energy_drain(ore_mine)
      + private.mine_energy_drain(crystal_mine)
      + private.deut_energy_drain(deut_mine) <= 0 then 1
    else least(
      1::numeric,
      (
        case
          when power_plant <= 0 then 0
          else floor(20 * power_plant * power(1.1, power_plant) * private.star_multiplier(star_type))
        end
        + private.fusion_output(fusion, energy_tech)
      )
        / (
          private.mine_energy_drain(ore_mine)
          + private.mine_energy_drain(crystal_mine)
          + private.deut_energy_drain(deut_mine)
        )
    )
  end;
$$;

revoke all on function private.deut_prod_per_hour(integer, integer) from public, anon, authenticated;
revoke all on function private.fusion_deut_burn_per_hour(integer) from public, anon, authenticated;
revoke all on function private.deut_energy_drain(integer) from public, anon, authenticated;
revoke all on function private.fusion_output(integer, integer) from public, anon, authenticated;
revoke all on function private.energy_factor(integer, integer, integer, text, integer, integer, integer) from public, anon, authenticated;

create or replace function private.tick_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
stable
set search_path = ''
as $$
declare
  elapsed numeric;
  factor numeric;
  factor_fusion numeric;
  ore_add bigint;
  crystal_add bigint;
  deut_add bigint;
  deut_burn bigint;
  star text;
  energy_tech integer := 0;
  synth numeric;
  burn numeric;
  fusion_live boolean;
begin
  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p.galaxy and s.system = p.system;

  if p.owner_id is not null then
    select e.energy_tech into energy_tech
    from public.empires e
    where e.user_id = p.owner_id;
  end if;

  elapsed := greatest(0, extract(epoch from (at - p.last_harvested_at)));
  factor_fusion := private.energy_factor(
    p.ore_mine,
    p.crystal_mine,
    p.power_plant,
    coalesce(star, 'medium'),
    p.deuterium_extractor,
    p.fusion_reactor,
    coalesce(energy_tech, 0)
  );
  synth := private.deut_prod_per_hour(p.deuterium_extractor, p.temp_max);
  burn := private.fusion_deut_burn_per_hour(p.fusion_reactor);
  fusion_live := coalesce(p.fusion_reactor, 0) <= 0
    or p.deuterium + synth * factor_fusion * elapsed / private.game_hour_seconds() >= burn * elapsed / private.game_hour_seconds();
  factor := case
    when fusion_live then factor_fusion
    else private.energy_factor(
      p.ore_mine,
      p.crystal_mine,
      p.power_plant,
      coalesce(star, 'medium'),
      p.deuterium_extractor,
      0,
      coalesce(energy_tech, 0)
    )
  end;
  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  deut_add := floor(synth * factor * elapsed / private.game_hour_seconds())::bigint;
  deut_burn := case when fusion_live then floor(burn * elapsed / private.game_hour_seconds())::bigint else 0 end;
  p.ore := least(private.storage_cap(p.ore_storage), p.ore + ore_add);
  p.crystal := least(private.storage_cap(p.crystal_storage), p.crystal + crystal_add);
  p.deuterium := least(
    private.storage_cap(p.deuterium_storage),
    greatest(0, p.deuterium + deut_add - deut_burn)
  );
  p.last_harvested_at := at;
  return p;
end;
$$;

drop function if exists private.energy_factor(integer, integer, integer, text);

create or replace function private.building_cost_deuterium(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'fusion_reactor' then floor(180 * power(1.8, current_level))::bigint
    when 'robotics_factory' then floor(200 * power(2, current_level))::bigint
    when 'shipyard' then floor(100 * power(2, current_level))::bigint
    when 'research_lab' then floor(200 * power(2, current_level))::bigint
    when 'missile_silo' then floor(1000 * power(2, current_level))::bigint
    when 'nanite_factory' then floor(100000 * power(2, current_level))::bigint
    when 'terraformer' then floor(100000 * power(2, current_level))::bigint
    when 'lunar_base' then floor(20000 * power(2, current_level))::bigint
    when 'phalanx_sensor' then floor(20000 * power(2, current_level))::bigint
    when 'stargate' then floor(2000000 * power(2, current_level))::bigint
    when 'space_station' then floor(50 * power(5, current_level))::bigint
    else 0
  end;
$$;

revoke all on function private.building_cost_deuterium(text, integer) from public, anon, authenticated;

create or replace function private.research_tech_cost_deuterium(id text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor((case id
    when 'energy_tech' then 400
    when 'ion_tech' then 100
    when 'hyperspace_tech' then 2000
    when 'plasma_tech' then 1000
    when 'combustion_drive' then 600
    when 'impulse_drive' then 600
    when 'hyperspace_drive' then 6000
    when 'espionage_tech' then 200
    when 'computer_tech' then 600
    when 'astrophysics' then 4000
    when 'intergalactic_research_network' then 160000
    else 0
  end) * power(case when id = 'astrophysics' then 1.75 else 2 end, greatest(current_level, 0)))::bigint;
$$;

revoke all on function private.research_tech_cost_deuterium(text, integer) from public, anon, authenticated;

create or replace function private.wiki_flight_distance(
  from_galaxy integer,
  from_system integer,
  from_slot integer,
  to_galaxy integer,
  to_system integer,
  to_slot integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when abs(from_galaxy - to_galaxy) > 0 then 20000 * abs(from_galaxy - to_galaxy)
    when abs(from_system - to_system) > 0 then 2700 + 95 * abs(from_system - to_system)
    when abs(from_slot - to_slot) > 0 then 1000 + 5 * abs(from_slot - to_slot)
    else 5
  end;
$$;

create or replace function private.fleet_fuel_round_trip(
  ships integer,
  consumption integer,
  distance integer
)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when ships is null or ships < 1 or consumption is null or consumption <= 0 then 0
    else (2 * greatest(1, round((ships * consumption * greatest(distance, 1)::numeric / 35000) * 4)))::bigint
  end;
$$;

create or replace function private.small_cargo_fuel(impulse integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when coalesce(impulse, 0) >= 5 then 20 else 10 end;
$$;

revoke all on function private.wiki_flight_distance(integer, integer, integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.fleet_fuel_round_trip(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.small_cargo_fuel(integer) from public, anon, authenticated;

create or replace function public.start_upgrade(p_building text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  home public.planets%rowtype;
  lvl integer;
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  blocked text;
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_building not in (
    'ore_mine',
    'crystal_mine',
    'deuterium_extractor',
    'power_plant',
    'fusion_reactor',
    'ore_storage',
    'crystal_storage',
    'deuterium_storage',
    'robotics_factory',
    'shipyard',
    'research_lab',
    'alliance_depot',
    'missile_silo',
    'nanite_factory',
    'terraformer',
    'space_station'
  ) then
    if p_building in ('lunar_base', 'phalanx_sensor', 'stargate') then
      raise exception 'Moon facilities wait for a moon.';
    end if;
    raise exception 'Unknown structure.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where owner_id = uid for update;

  if home.upgrade_building is not null then
    raise exception 'An upgrade is already running.';
  end if;

  blocked := private.facility_block(home, e, p_building);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  if private.planet_fields_used(home) >= home.max_fields then
    raise exception 'No free fields.';
  end if;

  lvl := private.planet_building_level(home, p_building);
  cost_ore := private.building_cost_ore(p_building, lvl);
  cost_crystal := private.building_cost_crystal(p_building, lvl);
  cost_deut := private.building_cost_deuterium(p_building, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut,
    upgrade_building = p_building,
    upgrade_completes_at = at + make_interval(
      secs => private.building_time_seconds(lvl, home.robotics_factory, home.nanite_factory)
    )
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.cancel_upgrade()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  lvl integer;
  duration_secs integer;
  start_at timestamptz;
  progress double precision;
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  refund_ore bigint;
  refund_crystal bigint;
  refund_deut bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into home
  from public.planets
  where owner_id = uid
  for update;

  if home.upgrade_building is null or home.upgrade_completes_at is null then
    raise exception 'Nothing is being built.';
  end if;

  lvl := private.planet_building_level(home, home.upgrade_building);
  duration_secs := greatest(
    private.building_time_seconds(lvl, home.robotics_factory, home.nanite_factory),
    1
  );
  start_at := home.upgrade_completes_at - make_interval(secs => duration_secs);
  progress := least(
    1.0::double precision,
    greatest(
      0.0::double precision,
      extract(epoch from (at - start_at)) / duration_secs::double precision
    )
  );
  cost_ore := private.building_cost_ore(home.upgrade_building, lvl);
  cost_crystal := private.building_cost_crystal(home.upgrade_building, lvl);
  cost_deut := private.building_cost_deuterium(home.upgrade_building, lvl);
  refund_ore := floor(cost_ore * (1.0::double precision - progress) * 0.5)::bigint;
  refund_crystal := floor(cost_crystal * (1.0::double precision - progress) * 0.5)::bigint;
  refund_deut := floor(cost_deut * (1.0::double precision - progress) * 0.5)::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + refund_crystal),
    deuterium = least(private.storage_cap(home.deuterium_storage), home.deuterium + refund_deut),
    upgrade_building = null,
    upgrade_completes_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.start_research(p_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  lvl integer;
  lab_need integer;
  blocked text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_id is null or p_id not in (
    'energy_tech', 'laser_tech', 'ion_tech', 'hyperspace_tech', 'plasma_tech',
    'combustion_drive', 'impulse_drive', 'hyperspace_drive',
    'espionage_tech', 'computer_tech', 'astrophysics', 'intergalactic_research_network', 'graviton_tech',
    'weapons_tech', 'shielding_tech', 'armour_tech'
  ) then
    raise exception 'Unknown research.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null then
    raise exception 'Research already running.';
  end if;

  lab_need := private.research_lab_need(p_id);
  if home.research_lab < lab_need then
    raise exception 'Needs Research lab %.', lab_need;
  end if;

  blocked := private.research_block(e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  lvl := private.research_level(e, p_id);
  cost_ore := private.research_tech_cost_ore(p_id, lvl);
  cost_crystal := private.research_tech_cost_crystal(p_id, lvl);
  cost_deut := private.research_tech_cost_deuterium(p_id, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut
  where id = home.id;

  update public.empires
  set
    research_tech = p_id,
    research_completes_at = at + make_interval(secs => private.research_time_seconds(lvl))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.queue_ship(p_id text, p_count integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  blocked text;
  busy text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  blocked := private.ship_block(home, e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  busy := coalesce(nullif(e.ship_building, ''), 'small_cargo');
  if e.raiders_queued > 0 and busy <> p_id then
    raise exception 'Shipyard occupied.';
  end if;

  cost_ore := private.ship_cost_ore(p_id) * p_count;
  cost_crystal := private.ship_cost_crystal(p_id) * p_count;
  cost_deut := private.ship_cost_deuterium(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut
  where id = home.id;

  update public.empires
  set
    ship_building = p_id,
    raiders_queued = e.raiders_queued + p_count,
    raider_completes_at = case
      when e.raiders_queued = 0 then at + make_interval(secs => 15)
      else e.raider_completes_at
    end
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_raid(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_raiders integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  origin public.planets%rowtype;
  dest public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  flight integer;
  fuel bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_raiders is null or p_raiders < 1 then
    raise exception 'Send at least one raider.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space cannot be raided.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.raiders < p_raiders then
    raise exception 'Not enough raiders.';
  end if;

  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;

  if not found then
    raise exception 'No world at that coordinate.';
  end if;
  if dest.id = origin.id then
    raise exception 'Cannot raid your own planet.';
  end if;
  if dest.owner_id is not null then
    raise exception 'Commander worlds are protected in this version.';
  end if;

  flight := private.flight_seconds(
    origin.system,
    origin.slot,
    dest.system,
    dest.slot,
    e.propulsion_level,
    origin.galaxy,
    dest.galaxy
  );
  fuel := private.fleet_fuel_round_trip(
    p_raiders,
    private.small_cargo_fuel(e.impulse_drive),
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot)
  );
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set deuterium = origin.deuterium - fuel
  where id = origin.id;

  update public.empires
  set
    raiders = e.raiders - p_raiders,
    ships = private.bump_ship(e.ships, 'small_cargo', -p_raiders)
  where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at
  )
  values (
    uid, origin.id, dest.id, p_raiders, 'attack', at + make_interval(secs => flight)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_expedition(p_galaxy smallint, p_system smallint, p_ships jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  origin public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  ships integer;
  active integer;
  cap integer;
  flight integer;
  extra integer;
  fuel bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 then
    raise exception 'That coordinate is outside the universe.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.astrophysics < 1 then
    raise exception 'Needs Astrophysics 1.';
  end if;

  extra := (
    select coalesce(sum((kv.value)::integer), 0)
    from jsonb_each_text(coalesce(p_ships, '{}'::jsonb)) kv
    where kv.key <> 'small_cargo' and (kv.value)::integer > 0
  );
  if extra > 0 then
    raise exception 'That hull is not docked yet.';
  end if;

  ships := coalesce((p_ships ->> 'small_cargo')::integer, 0);
  if ships < 1 then
    raise exception 'Send at least one small cargo.';
  end if;
  if e.raiders < ships then
    raise exception 'Not enough small cargo.';
  end if;

  cap := private.expedition_fleet_cap(e.astrophysics);
  select count(*)::integer into active
  from public.fleets
  where owner_id = uid
    and status = 'en_route'
    and mission in ('expedition', 'expedition_hold', 'expedition_return');
  if active >= cap then
    raise exception 'No free expedition slots.';
  end if;

  flight := least(30, private.flight_seconds(
    origin.system,
    origin.slot,
    p_system,
    16,
    e.propulsion_level,
    origin.galaxy,
    p_galaxy
  ));
  fuel := private.fleet_fuel_round_trip(
    ships,
    private.small_cargo_fuel(e.impulse_drive),
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, 16)
  );
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set deuterium = origin.deuterium - fuel
  where id = origin.id;

  update public.empires
  set
    raiders = e.raiders - ships,
    ships = private.bump_ship(e.ships, 'small_cargo', -ships)
  where user_id = uid;

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
    uid,
    origin.id,
    null,
    p_galaxy,
    p_system,
    16,
    ships,
    'expedition',
    at + make_interval(secs => flight),
    jsonb_build_object('small_cargo', ships)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

grant execute on function public.start_upgrade(text) to authenticated;
grant execute on function public.cancel_upgrade() to authenticated;
grant execute on function public.start_research(text) to authenticated;
grant execute on function public.queue_ship(text, integer) to authenticated;
grant execute on function public.send_raid(smallint, smallint, smallint, integer) to authenticated;
grant execute on function public.send_expedition(smallint, smallint, jsonb) to authenticated;
