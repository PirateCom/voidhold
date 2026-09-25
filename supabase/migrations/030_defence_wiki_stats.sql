-- Wiki defence hull / shield / weapon power (https://ogame.fandom.com/wiki/Defense).

create or replace function private.defence_attack(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 1
    when 'large_shield_dome' then 1
    when 'rocket_launcher' then 80
    when 'light_laser' then 100
    when 'heavy_laser' then 250
    when 'ion_cannon' then 150
    when 'gauss_cannon' then 1100
    when 'plasma_turret' then 3000
    when 'antiballistic_missile' then 1
    when 'interplanetary_missile' then 12000
    else 0
  end;
$$;

create or replace function private.defence_hp(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 2000
    when 'large_shield_dome' then 10000
    when 'rocket_launcher' then 20
    when 'light_laser' then 25
    when 'heavy_laser' then 100
    when 'ion_cannon' then 500
    when 'gauss_cannon' then 200
    when 'plasma_turret' then 300
    when 'antiballistic_missile' then 1
    when 'interplanetary_missile' then 1
    else 0
  end;
$$;

create or replace function private.planet_attack(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0) * 1
       + greatest(coalesce(p.large_shield_dome, 0), 0) * 1
       + greatest(coalesce(p.rocket_launcher, 0), 0) * 80
       + greatest(coalesce(p.light_laser, 0), 0) * 100
       + greatest(coalesce(p.heavy_laser, 0), 0) * 250
       + greatest(coalesce(p.ion_cannon, 0), 0) * 150
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 1100
       + greatest(coalesce(p.plasma_turret, 0), 0) * 3000
       + greatest(coalesce(p.antiballistic_missile, 0), 0) * 1
       + greatest(coalesce(p.interplanetary_missile, 0), 0) * 12000;
$$;

create or replace function private.planet_defence(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0) * 2000
       + greatest(coalesce(p.large_shield_dome, 0), 0) * 10000
       + greatest(coalesce(p.rocket_launcher, 0), 0) * 20
       + greatest(coalesce(p.light_laser, 0), 0) * 25
       + greatest(coalesce(p.heavy_laser, 0), 0) * 100
       + greatest(coalesce(p.ion_cannon, 0), 0) * 500
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 200
       + greatest(coalesce(p.plasma_turret, 0), 0) * 300
       + greatest(coalesce(p.antiballistic_missile, 0), 0) * 1
       + greatest(coalesce(p.interplanetary_missile, 0), 0) * 1;
$$;
