-- Fix: PL/pgSQL variable "id" shadowed planets.id in score_resources.

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

revoke all on function private.score_resources(uuid) from public, anon, authenticated;
