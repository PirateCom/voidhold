-- Operator-only: raise the selected planet's mines, facilities, and all research to level 10.

create or replace function public.debug_boost_hold()
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

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set
    ore_mine = greatest(ore_mine, 10),
    crystal_mine = greatest(crystal_mine, 10),
    deuterium_extractor = greatest(deuterium_extractor, 10),
    power_plant = greatest(power_plant, 10),
    fusion_reactor = greatest(fusion_reactor, 10),
    ore_storage = greatest(ore_storage, 10),
    crystal_storage = greatest(crystal_storage, 10),
    deuterium_storage = greatest(deuterium_storage, 10),
    robotics_factory = greatest(robotics_factory, 10),
    shipyard = greatest(shipyard, 10),
    research_lab = greatest(research_lab, 10),
    alliance_depot = greatest(alliance_depot, 10),
    missile_silo = greatest(missile_silo, 10),
    nanite_factory = greatest(nanite_factory, 10),
    terraformer = greatest(terraformer, 10),
    lunar_base = greatest(lunar_base, 10),
    phalanx_sensor = greatest(phalanx_sensor, 10),
    stargate = greatest(stargate, 10),
    space_station = greatest(space_station, 10),
    upgrade_building = null,
    upgrade_completes_at = null,
    upgrade_started_at = null
  where id = home.id;

  update public.empires
  set
    propulsion_level = greatest(propulsion_level, 10),
    energy_tech = greatest(energy_tech, 10),
    laser_tech = greatest(laser_tech, 10),
    ion_tech = greatest(ion_tech, 10),
    hyperspace_tech = greatest(hyperspace_tech, 10),
    plasma_tech = greatest(plasma_tech, 10),
    impulse_drive = greatest(impulse_drive, 10),
    hyperspace_drive = greatest(hyperspace_drive, 10),
    espionage_tech = greatest(espionage_tech, 10),
    computer_tech = greatest(computer_tech, 10),
    astrophysics = greatest(astrophysics, 10),
    intergalactic_research_network = greatest(intergalactic_research_network, 10),
    graviton_tech = greatest(graviton_tech, 10),
    weapons_tech = greatest(weapons_tech, 10),
    shielding_tech = greatest(shielding_tech, 10),
    armour_tech = greatest(armour_tech, 10),
    research_tech = null,
    research_completes_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.debug_boost_hold() from public, anon;
grant execute on function public.debug_boost_hold() to authenticated;
