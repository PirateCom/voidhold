-- Deuterium extractor, deuterium tank, and fusion reactor on the resource row.

alter table public.planets
  add column if not exists deuterium_extractor smallint not null default 0,
  add column if not exists deuterium_storage smallint not null default 0,
  add column if not exists fusion_reactor smallint not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'planets_deuterium_extractor_check') then
    alter table public.planets add constraint planets_deuterium_extractor_check check (deuterium_extractor >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_deuterium_storage_check') then
    alter table public.planets add constraint planets_deuterium_storage_check check (deuterium_storage >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_fusion_reactor_check') then
    alter table public.planets add constraint planets_fusion_reactor_check check (fusion_reactor >= 0);
  end if;
end $$;

alter table public.planets drop constraint if exists planets_upgrade_building_check;
alter table public.planets add constraint planets_upgrade_building_check check (
  upgrade_building is null or upgrade_building in (
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
    when 'deuterium_extractor' then floor(225 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(75 * power(1.5, current_level))::bigint
    when 'fusion_reactor' then floor(900 * power(1.8, current_level))::bigint
    when 'ore_storage' then floor(1000 * power(2, current_level))::bigint
    when 'crystal_storage' then floor(1000 * power(2, current_level))::bigint
    when 'deuterium_storage' then floor(1000 * power(2, current_level))::bigint
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
    when 'deuterium_extractor' then floor(75 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(30 * power(1.5, current_level))::bigint
    when 'fusion_reactor' then floor(360 * power(1.8, current_level))::bigint
    when 'ore_storage' then 0
    when 'crystal_storage' then floor(500 * power(2, current_level))::bigint
    when 'deuterium_storage' then floor(1000 * power(2, current_level))::bigint
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
    when 'deuterium_extractor' then p.deuterium_extractor
    when 'power_plant' then p.power_plant
    when 'fusion_reactor' then p.fusion_reactor
    when 'ore_storage' then p.ore_storage
    when 'crystal_storage' then p.crystal_storage
    when 'deuterium_storage' then p.deuterium_storage
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
  select p.ore_mine + p.crystal_mine + p.deuterium_extractor + p.power_plant + p.fusion_reactor
    + p.ore_storage + p.crystal_storage + p.deuterium_storage
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
  elsif id = 'fusion_reactor' and e.energy_tech < 3 then
    return 'Needs Energy technology 3.';
  elsif id = 'fusion_reactor' and p.deuterium_extractor < 5 then
    return 'Needs Deuterium extractor 5.';
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
    elsif p.upgrade_building = 'deuterium_extractor' then
      p.deuterium_extractor := p.deuterium_extractor + 1;
    elsif p.upgrade_building = 'power_plant' then
      p.power_plant := p.power_plant + 1;
    elsif p.upgrade_building = 'fusion_reactor' then
      p.fusion_reactor := p.fusion_reactor + 1;
    elsif p.upgrade_building = 'ore_storage' then
      p.ore_storage := p.ore_storage + 1;
    elsif p.upgrade_building = 'crystal_storage' then
      p.crystal_storage := p.crystal_storage + 1;
    elsif p.upgrade_building = 'deuterium_storage' then
      p.deuterium_storage := p.deuterium_storage + 1;
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
