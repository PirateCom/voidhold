-- Plasma turret, antiballistic missile, and interplanetary missile.

alter table public.planets
  add column if not exists plasma_turret integer not null default 0,
  add column if not exists antiballistic_missile integer not null default 0,
  add column if not exists interplanetary_missile integer not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'planets_plasma_turret_check') then
    alter table public.planets add constraint planets_plasma_turret_check check (plasma_turret >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_antiballistic_missile_check') then
    alter table public.planets add constraint planets_antiballistic_missile_check check (antiballistic_missile >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_interplanetary_missile_check') then
    alter table public.planets add constraint planets_interplanetary_missile_check check (interplanetary_missile >= 0);
  end if;
end $$;

alter table public.planets drop constraint if exists planets_defence_building_check;
alter table public.planets add constraint planets_defence_building_check check (
  defence_building is null or defence_building in (
    'small_shield_dome',
    'large_shield_dome',
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'plasma_turret',
    'antiballistic_missile',
    'interplanetary_missile'
  )
);

create or replace function private.defence_cost_ore(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 800
    when 'large_shield_dome' then 4000
    when 'rocket_launcher' then 120
    when 'light_laser' then 180
    when 'heavy_laser' then 480
    when 'ion_cannon' then 160
    when 'gauss_cannon' then 1600
    when 'plasma_turret' then 4500
    when 'antiballistic_missile' then 400
    when 'interplanetary_missile' then 1200
    else 0
  end;
$$;

create or replace function private.defence_cost_crystal(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 800
    when 'large_shield_dome' then 4000
    when 'rocket_launcher' then 30
    when 'light_laser' then 60
    when 'heavy_laser' then 160
    when 'ion_cannon' then 480
    when 'gauss_cannon' then 1200
    when 'plasma_turret' then 4000
    when 'antiballistic_missile' then 0
    when 'interplanetary_missile' then 400
    else 0
  end;
$$;

create or replace function private.defence_time_seconds(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 30
    when 'large_shield_dome' then 75
    when 'rocket_launcher' then 10
    when 'light_laser' then 14
    when 'heavy_laser' then 22
    when 'ion_cannon' then 28
    when 'gauss_cannon' then 45
    when 'plasma_turret' then 70
    when 'antiballistic_missile' then 16
    when 'interplanetary_missile' then 32
    else 10
  end;
$$;

create or replace function private.defence_owned(p public.planets, id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then p.small_shield_dome
    when 'large_shield_dome' then p.large_shield_dome
    when 'rocket_launcher' then p.rocket_launcher
    when 'light_laser' then p.light_laser
    when 'heavy_laser' then p.heavy_laser
    when 'ion_cannon' then p.ion_cannon
    when 'gauss_cannon' then p.gauss_cannon
    when 'plasma_turret' then p.plasma_turret
    when 'antiballistic_missile' then p.antiballistic_missile
    when 'interplanetary_missile' then p.interplanetary_missile
    else 0
  end;
$$;

create or replace function private.apply_defence(p public.planets, id text)
returns public.planets
language plpgsql
set search_path = ''
as $$
begin
  if id = 'small_shield_dome' then
    p.small_shield_dome := 1;
  elsif id = 'large_shield_dome' then
    p.large_shield_dome := 1;
  elsif id = 'rocket_launcher' then
    p.rocket_launcher := p.rocket_launcher + 1;
  elsif id = 'light_laser' then
    p.light_laser := p.light_laser + 1;
  elsif id = 'heavy_laser' then
    p.heavy_laser := p.heavy_laser + 1;
  elsif id = 'ion_cannon' then
    p.ion_cannon := p.ion_cannon + 1;
  elsif id = 'gauss_cannon' then
    p.gauss_cannon := p.gauss_cannon + 1;
  elsif id = 'plasma_turret' then
    p.plasma_turret := p.plasma_turret + 1;
  elsif id = 'antiballistic_missile' then
    p.antiballistic_missile := p.antiballistic_missile + 1;
  elsif id = 'interplanetary_missile' then
    p.interplanetary_missile := p.interplanetary_missile + 1;
  end if;
  return p;
end;
$$;

create or replace function private.defence_attack(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 0
    when 'large_shield_dome' then 0
    when 'rocket_launcher' then 8
    when 'light_laser' then 10
    when 'heavy_laser' then 25
    when 'ion_cannon' then 15
    when 'gauss_cannon' then 110
    when 'plasma_turret' then 280
    when 'antiballistic_missile' then 0
    when 'interplanetary_missile' then 80
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
    when 'small_shield_dome' then 200
    when 'large_shield_dome' then 1000
    when 'rocket_launcher' then 20
    when 'light_laser' then 25
    when 'heavy_laser' then 90
    when 'ion_cannon' then 130
    when 'gauss_cannon' then 370
    when 'plasma_turret' then 900
    when 'antiballistic_missile' then 40
    when 'interplanetary_missile' then 50
    else 0
  end;
$$;

create or replace function private.defence_units(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0)
       + greatest(coalesce(p.large_shield_dome, 0), 0)
       + greatest(coalesce(p.rocket_launcher, 0), 0)
       + greatest(coalesce(p.light_laser, 0), 0)
       + greatest(coalesce(p.heavy_laser, 0), 0)
       + greatest(coalesce(p.ion_cannon, 0), 0)
       + greatest(coalesce(p.gauss_cannon, 0), 0)
       + greatest(coalesce(p.plasma_turret, 0), 0)
       + greatest(coalesce(p.antiballistic_missile, 0), 0)
       + greatest(coalesce(p.interplanetary_missile, 0), 0);
$$;

create or replace function private.planet_attack(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.rocket_launcher, 0), 0) * 8
       + greatest(coalesce(p.light_laser, 0), 0) * 10
       + greatest(coalesce(p.heavy_laser, 0), 0) * 25
       + greatest(coalesce(p.ion_cannon, 0), 0) * 15
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 110
       + greatest(coalesce(p.plasma_turret, 0), 0) * 280
       + greatest(coalesce(p.interplanetary_missile, 0), 0) * 80;
$$;

create or replace function private.planet_defence(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0) * 200
       + greatest(coalesce(p.large_shield_dome, 0), 0) * 1000
       + greatest(coalesce(p.rocket_launcher, 0), 0) * 20
       + greatest(coalesce(p.light_laser, 0), 0) * 25
       + greatest(coalesce(p.heavy_laser, 0), 0) * 90
       + greatest(coalesce(p.ion_cannon, 0), 0) * 130
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 370
       + greatest(coalesce(p.plasma_turret, 0), 0) * 900
       + greatest(coalesce(p.antiballistic_missile, 0), 0) * 40
       + greatest(coalesce(p.interplanetary_missile, 0), 0) * 50;
$$;

create or replace function private.set_defence_owned(p public.planets, id text, n integer)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  qty integer := greatest(coalesce(n, 0), 0);
begin
  if id = 'small_shield_dome' then
    p.small_shield_dome := least(qty, 1);
  elsif id = 'large_shield_dome' then
    p.large_shield_dome := least(qty, 1);
  elsif id = 'rocket_launcher' then
    p.rocket_launcher := qty;
  elsif id = 'light_laser' then
    p.light_laser := qty;
  elsif id = 'heavy_laser' then
    p.heavy_laser := qty;
  elsif id = 'ion_cannon' then
    p.ion_cannon := qty;
  elsif id = 'gauss_cannon' then
    p.gauss_cannon := qty;
  elsif id = 'plasma_turret' then
    p.plasma_turret := qty;
  elsif id = 'antiballistic_missile' then
    p.antiballistic_missile := qty;
  elsif id = 'interplanetary_missile' then
    p.interplanetary_missile := qty;
  end if;
  return p;
end;
$$;

create or replace function private.apply_pirate_damage(p public.planets, damage integer)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  remaining integer := greatest(coalesce(damage, 0), 0);
  id text;
  hp integer;
begin
  foreach id in array array[
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'plasma_turret',
    'antiballistic_missile',
    'interplanetary_missile',
    'small_shield_dome',
    'large_shield_dome'
  ] loop
    hp := private.defence_hp(id);
    if hp <= 0 then
      continue;
    end if;
    while private.defence_owned(p, id) > 0 and remaining >= hp loop
      p := private.set_defence_owned(p, id, private.defence_owned(p, id) - 1);
      remaining := remaining - hp;
    end loop;
  end loop;
  return p;
end;
$$;

create or replace function private.lost_guns_text(before public.planets, afterp public.planets)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  parts text[] := '{}';
  n integer;
begin
  n := before.rocket_launcher - afterp.rocket_launcher;
  if n > 0 then
    parts := array_append(parts, format('%s rocket launcher%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.light_laser - afterp.light_laser;
  if n > 0 then
    parts := array_append(parts, format('%s light laser%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.heavy_laser - afterp.heavy_laser;
  if n > 0 then
    parts := array_append(parts, format('%s heavy laser%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.ion_cannon - afterp.ion_cannon;
  if n > 0 then
    parts := array_append(parts, format('%s ion cannon%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.gauss_cannon - afterp.gauss_cannon;
  if n > 0 then
    parts := array_append(parts, format('%s gaussian cannon%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.plasma_turret - afterp.plasma_turret;
  if n > 0 then
    parts := array_append(parts, format('%s plasma turret%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.antiballistic_missile - afterp.antiballistic_missile;
  if n > 0 then
    parts := array_append(parts, format('%s antiballistic missile%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.interplanetary_missile - afterp.interplanetary_missile;
  if n > 0 then
    parts := array_append(parts, format('%s interplanetary missile%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.small_shield_dome - afterp.small_shield_dome;
  if n > 0 then
    parts := array_append(parts, format('%s small shield dome%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.large_shield_dome - afterp.large_shield_dome;
  if n > 0 then
    parts := array_append(parts, format('%s large shield dome%s', n, case when n = 1 then '' else 's' end));
  end if;
  if cardinality(parts) = 0 then
    return 'no guns';
  end if;
  return array_to_string(parts, ', ');
end;
$$;

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
    power_plant = p.power_plant,
    ore_storage = p.ore_storage,
    crystal_storage = p.crystal_storage,
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

create or replace function public.queue_defence(p_id text, p_count integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  cost_ore bigint;
  cost_crystal bigint;
  pending integer;
  valid boolean;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  valid := p_id in (
    'small_shield_dome',
    'large_shield_dome',
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'plasma_turret',
    'antiballistic_missile',
    'interplanetary_missile'
  );
  if not valid then
    raise exception 'Unknown defence.';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one.';
  end if;

  perform private.catch_up(uid, at);
  select * into home from public.planets where owner_id = uid for update;

  if home.defences_queued > 0 and home.defence_building is not null and home.defence_building <> p_id then
    raise exception 'Defence yard occupied.';
  end if;

  pending := case when home.defence_building = p_id then home.defences_queued else 0 end;
  if private.defence_is_unique(p_id) and private.defence_owned(home, p_id) + pending + p_count > 1 then
    raise exception 'Only one of those domes fits on this world.';
  end if;

  cost_ore := private.defence_cost_ore(p_id) * p_count;
  cost_crystal := private.defence_cost_crystal(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    defence_building = p_id,
    defences_queued = home.defences_queued + p_count,
    defence_completes_at = case
      when home.defences_queued = 0 then at + make_interval(secs => private.defence_time_seconds(p_id))
      else home.defence_completes_at
    end
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
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
