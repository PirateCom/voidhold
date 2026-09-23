-- Debug fill to storage caps. Deuterium stockpile is stored; production still stays at 0.

alter table public.planets
  add column if not exists deuterium bigint not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'planets_deuterium_check') then
    alter table public.planets add constraint planets_deuterium_check check (deuterium >= 0);
  end if;
end $$;

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
    defence_completes_at = p.defence_completes_at
  where id = p.id;
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

  perform private.catch_up(uid, at);

  select * into home from public.planets where owner_id = uid for update;
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

revoke all on function public.debug_fill_resources() from public, anon;
grant execute on function public.debug_fill_resources() to authenticated;

notify pgrst, 'reload schema';
