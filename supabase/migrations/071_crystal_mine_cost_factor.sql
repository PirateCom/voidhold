-- Wiki: crystal mine cost factor is 1.6, not 1.5 (metal mine stays 1.5).
-- Cost of the next level = floor(base * factor^current_level).

create or replace function private.building_cost_ore(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(60 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(48 * power(1.6, current_level))::bigint
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
    when 'lunar_base' then floor(20000 * power(2, current_level))::bigint
    when 'phalanx_sensor' then floor(20000 * power(2, current_level))::bigint
    when 'stargate' then floor(2000000 * power(2, current_level))::bigint
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
    when 'crystal_mine' then floor(24 * power(1.6, current_level))::bigint
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
    when 'lunar_base' then floor(40000 * power(2, current_level))::bigint
    when 'phalanx_sensor' then floor(40000 * power(2, current_level))::bigint
    when 'stargate' then floor(4000000 * power(2, current_level))::bigint
    when 'space_station' then 0
    else 0
  end;
$$;

notify pgrst, 'reload schema';
