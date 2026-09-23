-- Planet facilities from the sprite row and ogame.fandom.com/wiki/Facilities.
-- Moon buildings are stored at 0. Deuterium and terraformer energy are listed in the client and not charged.

alter table public.planets
  add column if not exists robotics_factory smallint not null default 0,
  add column if not exists shipyard smallint not null default 0,
  add column if not exists research_lab smallint not null default 0,
  add column if not exists alliance_depot smallint not null default 0,
  add column if not exists missile_silo smallint not null default 0,
  add column if not exists nanite_factory smallint not null default 0,
  add column if not exists terraformer smallint not null default 0,
  add column if not exists lunar_base smallint not null default 0,
  add column if not exists phalanx_sensor smallint not null default 0,
  add column if not exists stargate smallint not null default 0,
  add column if not exists space_station smallint not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'planets_robotics_factory_check') then
    alter table public.planets add constraint planets_robotics_factory_check check (robotics_factory >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_shipyard_check') then
    alter table public.planets add constraint planets_shipyard_check check (shipyard >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_research_lab_check') then
    alter table public.planets add constraint planets_research_lab_check check (research_lab >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_alliance_depot_check') then
    alter table public.planets add constraint planets_alliance_depot_check check (alliance_depot >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_missile_silo_check') then
    alter table public.planets add constraint planets_missile_silo_check check (missile_silo >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_nanite_factory_check') then
    alter table public.planets add constraint planets_nanite_factory_check check (nanite_factory >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_terraformer_check') then
    alter table public.planets add constraint planets_terraformer_check check (terraformer >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_lunar_base_check') then
    alter table public.planets add constraint planets_lunar_base_check check (lunar_base >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_phalanx_sensor_check') then
    alter table public.planets add constraint planets_phalanx_sensor_check check (phalanx_sensor >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_stargate_check') then
    alter table public.planets add constraint planets_stargate_check check (stargate >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_space_station_check') then
    alter table public.planets add constraint planets_space_station_check check (space_station >= 0);
  end if;
end $$;

alter table public.planets drop constraint if exists planets_upgrade_building_check;
alter table public.planets add constraint planets_upgrade_building_check check (
  upgrade_building is null or upgrade_building in (
    'ore_mine',
    'crystal_mine',
    'power_plant',
    'ore_storage',
    'crystal_storage',
    'robotics_factory',
    'shipyard',
    'research_lab',
    'alliance_depot',
    'missile_silo',
    'nanite_factory',
    'terraformer',
    'lunar_base',
    'phalanx_sensor',
    'stargate',
    'space_station'
  )
);

create or replace function private.building_cost_ore(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(60 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(48 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(75 * power(1.5, current_level))::bigint
    when 'ore_storage' then floor(1000 * power(2, current_level))::bigint
    when 'crystal_storage' then floor(1000 * power(2, current_level))::bigint
    when 'robotics_factory' then floor(400 * power(2, current_level))::bigint
    when 'shipyard' then floor(400 * power(2, current_level))::bigint
    when 'research_lab' then floor(200 * power(2, current_level))::bigint
    when 'alliance_depot' then floor(20000 * power(2, current_level))::bigint
    when 'missile_silo' then floor(20000 * power(2, current_level))::bigint
    when 'nanite_factory' then floor(1000000 * power(2, current_level))::bigint
    when 'terraformer' then 0
    when 'space_station' then floor(200 * power(5, current_level))::bigint
    else 0
  end;
$$;

create or replace function private.building_cost_crystal(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(15 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(24 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(30 * power(1.5, current_level))::bigint
    when 'ore_storage' then 0
    when 'crystal_storage' then floor(500 * power(2, current_level))::bigint
    when 'robotics_factory' then floor(120 * power(2, current_level))::bigint
    when 'shipyard' then floor(200 * power(2, current_level))::bigint
    when 'research_lab' then floor(400 * power(2, current_level))::bigint
    when 'alliance_depot' then floor(40000 * power(2, current_level))::bigint
    when 'missile_silo' then floor(20000 * power(2, current_level))::bigint
    when 'nanite_factory' then floor(500000 * power(2, current_level))::bigint
    when 'terraformer' then floor(50000 * power(2, current_level))::bigint
    when 'space_station' then 0
    else 0
  end;
$$;

create or replace function private.planet_building_level(p public.planets, id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'ore_mine' then p.ore_mine
    when 'crystal_mine' then p.crystal_mine
    when 'power_plant' then p.power_plant
    when 'ore_storage' then p.ore_storage
    when 'crystal_storage' then p.crystal_storage
    when 'robotics_factory' then p.robotics_factory
    when 'shipyard' then p.shipyard
    when 'research_lab' then p.research_lab
    when 'alliance_depot' then p.alliance_depot
    when 'missile_silo' then p.missile_silo
    when 'nanite_factory' then p.nanite_factory
    when 'terraformer' then p.terraformer
    when 'lunar_base' then p.lunar_base
    when 'phalanx_sensor' then p.phalanx_sensor
    when 'stargate' then p.stargate
    when 'space_station' then p.space_station
    else 0
  end;
$$;

create or replace function private.planet_fields_used(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select p.ore_mine + p.crystal_mine + p.power_plant + p.ore_storage + p.crystal_storage
    + p.robotics_factory + p.shipyard + p.research_lab + p.alliance_depot + p.missile_silo
    + p.nanite_factory + p.terraformer + p.space_station;
$$;

create or replace function private.facility_block(p public.planets, e public.empires, id text)
returns text
language plpgsql
stable
set search_path = ''
as $$
begin
  if id in ('lunar_base', 'phalanx_sensor', 'stargate') then
    return 'Moon facilities wait for a moon.';
  elsif id = 'shipyard' and p.robotics_factory < 2 then
    return 'Needs Robotics factory 2.';
  elsif id = 'missile_silo' and p.shipyard < 1 then
    return 'Needs Shipyard 1.';
  elsif id = 'nanite_factory' and p.robotics_factory < 10 then
    return 'Needs Robotics factory 10.';
  elsif id = 'nanite_factory' and p.shipyard < 1 then
    return 'Needs Shipyard 1.';
  elsif id = 'nanite_factory' and e.computer_tech < 10 then
    return 'Needs Computer technology 10.';
  elsif id = 'terraformer' and p.nanite_factory < 1 then
    return 'Needs Nanite factory 1.';
  elsif id = 'terraformer' and e.energy_tech < 12 then
    return 'Needs Energy technology 12.';
  elsif id = 'space_station' and p.shipyard < 2 then
    return 'Needs Shipyard 2.';
  end if;
  return null;
end;
$$;

create or replace function private.catch_up_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
set search_path = ''
as $$
begin
  if p.upgrade_completes_at is not null and p.upgrade_completes_at <= at then
    p := private.tick_planet(p, p.upgrade_completes_at);
    if p.upgrade_building = 'ore_mine' then
      p.ore_mine := p.ore_mine + 1;
    elsif p.upgrade_building = 'crystal_mine' then
      p.crystal_mine := p.crystal_mine + 1;
    elsif p.upgrade_building = 'power_plant' then
      p.power_plant := p.power_plant + 1;
    elsif p.upgrade_building = 'ore_storage' then
      p.ore_storage := p.ore_storage + 1;
    elsif p.upgrade_building = 'crystal_storage' then
      p.crystal_storage := p.crystal_storage + 1;
    elsif p.upgrade_building = 'robotics_factory' then
      p.robotics_factory := p.robotics_factory + 1;
    elsif p.upgrade_building = 'shipyard' then
      p.shipyard := p.shipyard + 1;
    elsif p.upgrade_building = 'research_lab' then
      p.research_lab := p.research_lab + 1;
    elsif p.upgrade_building = 'alliance_depot' then
      p.alliance_depot := p.alliance_depot + 1;
    elsif p.upgrade_building = 'missile_silo' then
      p.missile_silo := p.missile_silo + 1;
    elsif p.upgrade_building = 'nanite_factory' then
      p.nanite_factory := p.nanite_factory + 1;
    elsif p.upgrade_building = 'terraformer' then
      p.terraformer := p.terraformer + 1;
    elsif p.upgrade_building = 'lunar_base' then
      p.lunar_base := p.lunar_base + 1;
    elsif p.upgrade_building = 'phalanx_sensor' then
      p.phalanx_sensor := p.phalanx_sensor + 1;
    elsif p.upgrade_building = 'stargate' then
      p.stargate := p.stargate + 1;
    elsif p.upgrade_building = 'space_station' then
      p.space_station := p.space_station + 1;
    end if;
    p.upgrade_building := null;
    p.upgrade_completes_at := null;
  end if;

  while p.defences_queued > 0 and p.defence_building is not null and p.defence_completes_at is not null and p.defence_completes_at <= at loop
    p := private.apply_defence(p, p.defence_building);
    p.defences_queued := p.defences_queued - 1;
    if p.defences_queued > 0 then
      p.defence_completes_at := p.defence_completes_at + make_interval(secs => private.defence_time_seconds(p.defence_building));
    else
      p.defence_building := null;
      p.defence_completes_at := null;
    end if;
  end loop;

  p := private.tick_planet(p, at);
  return p;
end;
$$;

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
  blocked text;
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_building not in (
    'ore_mine',
    'crystal_mine',
    'power_plant',
    'ore_storage',
    'crystal_storage',
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
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    upgrade_building = p_building,
    upgrade_completes_at = at + make_interval(secs => private.building_time_seconds(lvl))
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
  refund_ore bigint;
  refund_crystal bigint;
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
  duration_secs := greatest(private.building_time_seconds(lvl), 1);
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
  refund_ore := floor(cost_ore * (1.0::double precision - progress) * 0.5)::bigint;
  refund_crystal := floor(cost_crystal * (1.0::double precision - progress) * 0.5)::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + refund_crystal),
    upgrade_building = null,
    upgrade_completes_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.reset_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.fleets where owner_id = uid;
  delete from public.battle_reports where user_id = uid;

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    power_plant = 1,
    ore_storage = 0,
    crystal_storage = 0,
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
    defence_completes_at = null
  where owner_id = uid;

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
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
