-- Persist facility and resource-building levels when catch-up completes an upgrade.

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
