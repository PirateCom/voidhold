-- Small cargo needs Impulse drive 5 to queue, matching the shipyard "Needs" line.

create or replace function private.ship_block(p public.planets, e public.empires, id text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  yard integer;
begin
  yard := case id
    when 'light_fighter' then 1
    when 'heavy_fighter' then 3
    when 'cruiser' then 5
    when 'battleship' then 7
    when 'battlecruiser' then 8
    when 'bomber' then 8
    when 'destroyer' then 9
    when 'deathstar' then 12
    when 'small_cargo' then 2
    when 'large_cargo' then 4
    when 'colony_ship' then 4
    when 'recycler' then 4
    when 'espionage_probe' then 3
    when 'reaper' then 10
    when 'pathfinder' then 5
    when 'crawler' then 5
    when 'solar_satellite' then 1
    else null
  end;
  if yard is null then
    return 'Unknown hull.';
  end if;
  if p.shipyard < yard then
    return format('Needs Shipyard %s.', yard);
  end if;

  if id = 'light_fighter' and private.research_level(e, 'combustion_drive') < 1 then
    return 'Needs Combustion drive 1.';
  elsif id = 'heavy_fighter' and private.research_level(e, 'impulse_drive') < 2 then
    return 'Needs Impulse drive 2.';
  elsif id = 'heavy_fighter' and private.research_level(e, 'armour_tech') < 2 then
    return 'Needs Armour technology 2.';
  elsif id = 'cruiser' and private.research_level(e, 'impulse_drive') < 4 then
    return 'Needs Impulse drive 4.';
  elsif id = 'cruiser' and private.research_level(e, 'ion_tech') < 2 then
    return 'Needs Ion technology 2.';
  elsif id = 'battleship' and private.research_level(e, 'hyperspace_drive') < 4 then
    return 'Needs Hyperspace drive 4.';
  elsif id = 'battlecruiser' and private.research_level(e, 'hyperspace_drive') < 5 then
    return 'Needs Hyperspace drive 5.';
  elsif id = 'battlecruiser' and private.research_level(e, 'hyperspace_tech') < 5 then
    return 'Needs Hyperspace technology 5.';
  elsif id = 'battlecruiser' and private.research_level(e, 'laser_tech') < 12 then
    return 'Needs Laser technology 12.';
  elsif id = 'bomber' and private.research_level(e, 'impulse_drive') < 6 then
    return 'Needs Impulse drive 6.';
  elsif id = 'bomber' and private.research_level(e, 'plasma_tech') < 5 then
    return 'Needs Plasma technology 5.';
  elsif id = 'bomber' and private.research_level(e, 'hyperspace_drive') < 8 then
    return 'Needs Hyperspace drive 8.';
  elsif id = 'destroyer' and private.research_level(e, 'hyperspace_drive') < 6 then
    return 'Needs Hyperspace drive 6.';
  elsif id = 'destroyer' and private.research_level(e, 'hyperspace_tech') < 5 then
    return 'Needs Hyperspace technology 5.';
  elsif id = 'deathstar' and private.research_level(e, 'hyperspace_drive') < 7 then
    return 'Needs Hyperspace drive 7.';
  elsif id = 'deathstar' and private.research_level(e, 'hyperspace_tech') < 6 then
    return 'Needs Hyperspace technology 6.';
  elsif id = 'deathstar' and private.research_level(e, 'graviton_tech') < 1 then
    return 'Needs Graviton technology 1.';
  elsif id = 'small_cargo' and private.research_level(e, 'combustion_drive') < 2 then
    return 'Needs Combustion drive 2.';
  elsif id = 'small_cargo' and private.research_level(e, 'impulse_drive') < 5 then
    return 'Needs Impulse drive 5.';
  elsif id = 'large_cargo' and private.research_level(e, 'combustion_drive') < 6 then
    return 'Needs Combustion drive 6.';
  elsif id = 'colony_ship' and private.research_level(e, 'impulse_drive') < 3 then
    return 'Needs Impulse drive 3.';
  elsif id = 'recycler' and private.research_level(e, 'combustion_drive') < 6 then
    return 'Needs Combustion drive 6.';
  elsif id = 'recycler' and private.research_level(e, 'shielding_tech') < 2 then
    return 'Needs Shielding technology 2.';
  elsif id = 'espionage_probe' and private.research_level(e, 'combustion_drive') < 3 then
    return 'Needs Combustion drive 3.';
  elsif id = 'espionage_probe' and private.research_level(e, 'espionage_tech') < 2 then
    return 'Needs Espionage technology 2.';
  elsif id = 'reaper' and private.research_level(e, 'hyperspace_drive') < 7 then
    return 'Needs Hyperspace drive 7.';
  elsif id = 'reaper' and private.research_level(e, 'hyperspace_tech') < 6 then
    return 'Needs Hyperspace technology 6.';
  elsif id = 'reaper' and private.research_level(e, 'shielding_tech') < 6 then
    return 'Needs Shielding technology 6.';
  elsif id = 'pathfinder' and private.research_level(e, 'hyperspace_drive') < 2 then
    return 'Needs Hyperspace drive 2.';
  elsif id = 'crawler' and private.research_level(e, 'combustion_drive') < 4 then
    return 'Needs Combustion drive 4.';
  elsif id = 'crawler' and private.research_level(e, 'armour_tech') < 4 then
    return 'Needs Armour technology 4.';
  elsif id = 'crawler' and private.research_level(e, 'laser_tech') < 4 then
    return 'Needs Laser technology 4.';
  end if;
  return null;
end;
$$;

revoke all on function private.ship_block(public.planets, public.empires, text) from public, anon, authenticated;
