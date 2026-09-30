-- Store when a building/research job began so progress bars stay mid-fill
-- when another device opens with time still left.

alter table public.planets
  add column if not exists upgrade_started_at timestamptz;

alter table public.empires
  add column if not exists research_started_at timestamptz;

create or replace function private.persist_planet(p public.planets)
returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.planets
  set
    ore = p.ore,
    crystal = p.crystal,
    deuterium = p.deuterium,
    last_harvested_at = p.last_harvested_at,
    ore_mine = p.ore_mine,
    crystal_mine = p.crystal_mine,
    deuterium_extractor = p.deuterium_extractor,
    power_plant = p.power_plant,
    fusion_reactor = p.fusion_reactor,
    ore_storage = p.ore_storage,
    crystal_storage = p.crystal_storage,
    deuterium_storage = p.deuterium_storage,
    robotics_factory = p.robotics_factory,
    shipyard = p.shipyard,
    research_lab = p.research_lab,
    alliance_depot = p.alliance_depot,
    missile_silo = p.missile_silo,
    nanite_factory = p.nanite_factory,
    terraformer = p.terraformer,
    lunar_base = p.lunar_base,
    phalanx_sensor = p.phalanx_sensor,
    stargate = p.stargate,
    space_station = p.space_station,
    upgrade_building = p.upgrade_building,
    upgrade_completes_at = p.upgrade_completes_at,
    upgrade_started_at = p.upgrade_started_at,
    small_shield_dome = p.small_shield_dome,
    large_shield_dome = p.large_shield_dome,
    rocket_launcher = p.rocket_launcher,
    light_laser = p.light_laser,
    heavy_laser = p.heavy_laser,
    ion_cannon = p.ion_cannon,
    gauss_cannon = p.gauss_cannon,
    plasma_turret = p.plasma_turret,
    antiballistic_missile = p.antiballistic_missile,
    interplanetary_missile = p.interplanetary_missile,
    defence_building = p.defence_building,
    defences_queued = p.defences_queued,
    defence_completes_at = p.defence_completes_at,
    ship_building = p.ship_building,
    ships_queued = p.ships_queued,
    ship_completes_at = p.ship_completes_at
  where id = p.id;
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
    p.upgrade_started_at := null;
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
  cost_deut bigint;
  blocked text;
  star text;
  satellites integer := 0;
  produced numeric;
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
  select * into home from public.planets where id = e.home_planet_id for update;

  if home.upgrade_building is not null then
    raise exception 'An upgrade is already running.';
  end if;

  if p_building = 'research_lab' and e.research_completes_at is not null then
    raise exception 'Research lab is in use.';
  end if;

  blocked := private.facility_block(home, e, p_building);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  if private.planet_fields_used(home) >= private.planet_field_cap(home) then
    raise exception 'No free fields.';
  end if;

  lvl := private.planet_building_level(home, p_building);
  if p_building = 'terraformer' then
    select s.star_type into star
    from public.solar_systems s
    where s.galaxy = home.galaxy and s.system = home.system;
    satellites := coalesce((e.ships->>'solar_satellite')::integer, 0);
    produced := private.energy_output(
      home.power_plant,
      coalesce(star, 'medium'),
      home.fusion_reactor,
      e.energy_tech,
      satellites,
      home.temp_min,
      home.temp_max
    );
    if produced < private.terraformer_energy(lvl) then
      raise exception 'Need more energy.';
    end if;
  end if;

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
    upgrade_started_at = at,
    upgrade_completes_at = at + make_interval(
      secs => private.building_time_seconds(
        p_building,
        lvl,
        home.robotics_factory,
        home.nanite_factory,
        coalesce(e.economy_speed, 1)
      )
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
  e public.empires%rowtype;
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
  select * into e from public.empires where user_id = uid;
  select * into home from public.planets where id = e.home_planet_id for update;

  if home.upgrade_building is null or home.upgrade_completes_at is null then
    raise exception 'Nothing is being built.';
  end if;

  lvl := private.planet_building_level(home, home.upgrade_building);
  duration_secs := greatest(
    private.building_time_seconds(
      home.upgrade_building,
      lvl,
      home.robotics_factory,
      home.nanite_factory,
      coalesce(e.economy_speed, 1)
    ),
    1
  );
  start_at := coalesce(
    home.upgrade_started_at,
    home.upgrade_completes_at - make_interval(secs => duration_secs)
  );
  progress := least(
    1.0::double precision,
    greatest(
      0.0::double precision,
      extract(epoch from (at - start_at))
        / greatest(extract(epoch from (home.upgrade_completes_at - start_at)), 1.0)::double precision
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
    upgrade_completes_at = null,
    upgrade_started_at = null
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

  if home.upgrade_building = 'research_lab' then
    raise exception 'Research lab is being upgraded.';
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
    research_started_at = at,
    research_completes_at = at + make_interval(secs => private.research_time_seconds(lvl))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function private.apply_research(e public.empires, id text)
returns public.empires
language plpgsql
set search_path = ''
as $$
begin
  if id = 'energy_tech' then
    e.energy_tech := e.energy_tech + 1;
  elsif id = 'laser_tech' then
    e.laser_tech := e.laser_tech + 1;
  elsif id = 'ion_tech' then
    e.ion_tech := e.ion_tech + 1;
  elsif id = 'hyperspace_tech' then
    e.hyperspace_tech := e.hyperspace_tech + 1;
  elsif id = 'plasma_tech' then
    e.plasma_tech := e.plasma_tech + 1;
  elsif id = 'impulse_drive' then
    e.impulse_drive := e.impulse_drive + 1;
  elsif id = 'hyperspace_drive' then
    e.hyperspace_drive := e.hyperspace_drive + 1;
  elsif id = 'espionage_tech' then
    e.espionage_tech := e.espionage_tech + 1;
  elsif id = 'computer_tech' then
    e.computer_tech := e.computer_tech + 1;
  elsif id = 'astrophysics' then
    e.astrophysics := e.astrophysics + 1;
  elsif id = 'intergalactic_research_network' then
    e.intergalactic_research_network := e.intergalactic_research_network + 1;
  elsif id = 'graviton_tech' then
    e.graviton_tech := e.graviton_tech + 1;
  elsif id = 'weapons_tech' then
    e.weapons_tech := e.weapons_tech + 1;
  elsif id = 'shielding_tech' then
    e.shielding_tech := e.shielding_tech + 1;
  elsif id = 'armour_tech' then
    e.armour_tech := e.armour_tech + 1;
  else
    e.propulsion_level := e.propulsion_level + 1;
  end if;
  e.research_tech := null;
  e.research_completes_at := null;
  e.research_started_at := null;
  return e;
end;
$$;

drop trigger if exists planets_clear_upgrade_started on public.planets;
drop trigger if exists empires_clear_research_started on public.empires;
drop function if exists private.clear_job_started_at();

create or replace function private.clear_upgrade_started()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if NEW.upgrade_completes_at is null then
    NEW.upgrade_started_at := null;
  end if;
  return NEW;
end;
$$;

create or replace function private.clear_research_started()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if NEW.research_completes_at is null then
    NEW.research_started_at := null;
  end if;
  return NEW;
end;
$$;

create trigger planets_clear_upgrade_started
before update on public.planets
for each row
execute function private.clear_upgrade_started();

create trigger empires_clear_research_started
before update on public.empires
for each row
execute function private.clear_research_started();

update public.planets p
set upgrade_started_at = p.upgrade_completes_at - make_interval(
  secs => private.building_time_seconds(
    p.upgrade_building,
    private.planet_building_level(p, p.upgrade_building),
    p.robotics_factory,
    p.nanite_factory,
    coalesce(e.economy_speed, 1)
  )
)
from public.empires e
where e.user_id = p.owner_id
  and p.upgrade_completes_at is not null
  and p.upgrade_building is not null
  and p.upgrade_started_at is null;

update public.empires e
set research_started_at = e.research_completes_at - make_interval(
  secs => private.research_time_seconds(private.research_level(e, e.research_tech))
)
where e.research_completes_at is not null
  and e.research_tech is not null
  and e.research_started_at is null;
