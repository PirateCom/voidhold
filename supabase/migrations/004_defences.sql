-- Planetary defences: two unique domes and five turret tiers.

alter table public.planets
  add column if not exists small_shield_dome smallint not null default 0,
  add column if not exists large_shield_dome smallint not null default 0,
  add column if not exists rocket_launcher integer not null default 0,
  add column if not exists light_laser integer not null default 0,
  add column if not exists heavy_laser integer not null default 0,
  add column if not exists ion_cannon integer not null default 0,
  add column if not exists gauss_cannon integer not null default 0,
  add column if not exists defence_building text,
  add column if not exists defences_queued integer not null default 0,
  add column if not exists defence_completes_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'planets_small_shield_dome_check') then
    alter table public.planets add constraint planets_small_shield_dome_check check (small_shield_dome between 0 and 1);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_large_shield_dome_check') then
    alter table public.planets add constraint planets_large_shield_dome_check check (large_shield_dome between 0 and 1);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_rocket_launcher_check') then
    alter table public.planets add constraint planets_rocket_launcher_check check (rocket_launcher >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_light_laser_check') then
    alter table public.planets add constraint planets_light_laser_check check (light_laser >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_heavy_laser_check') then
    alter table public.planets add constraint planets_heavy_laser_check check (heavy_laser >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_ion_cannon_check') then
    alter table public.planets add constraint planets_ion_cannon_check check (ion_cannon >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_gauss_cannon_check') then
    alter table public.planets add constraint planets_gauss_cannon_check check (gauss_cannon >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_defences_queued_check') then
    alter table public.planets add constraint planets_defences_queued_check check (defences_queued >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'planets_defence_building_check') then
    alter table public.planets add constraint planets_defence_building_check check (
      defence_building is null or defence_building in (
        'small_shield_dome',
        'large_shield_dome',
        'rocket_launcher',
        'light_laser',
        'heavy_laser',
        'ion_cannon',
        'gauss_cannon'
      )
    );
  end if;
end $$;

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
    else 10
  end;
$$;

create or replace function private.defence_is_unique(id text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select id in ('small_shield_dome', 'large_shield_dome');
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
  end if;
  return p;
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
    upgrade_building = p.upgrade_building,
    upgrade_completes_at = p.upgrade_completes_at,
    small_shield_dome = p.small_shield_dome,
    large_shield_dome = p.large_shield_dome,
    rocket_launcher = p.rocket_launcher,
    light_laser = p.light_laser,
    heavy_laser = p.heavy_laser,
    ion_cannon = p.ion_cannon,
    gauss_cannon = p.gauss_cannon,
    defence_building = p.defence_building,
    defences_queued = p.defences_queued,
    defence_completes_at = p.defence_completes_at
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
    elsif p.upgrade_building = 'power_plant' then
      p.power_plant := p.power_plant + 1;
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
    'gauss_cannon'
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
    upgrade_building = null,
    upgrade_completes_at = null,
    small_shield_dome = 0,
    large_shield_dome = 0,
    rocket_launcher = 0,
    light_laser = 0,
    heavy_laser = 0,
    ion_cannon = 0,
    gauss_cannon = 0,
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
    research_completes_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function private.defence_cost_ore(text) from public, anon, authenticated;
revoke all on function private.defence_cost_crystal(text) from public, anon, authenticated;
revoke all on function private.defence_time_seconds(text) from public, anon, authenticated;
revoke all on function private.defence_is_unique(text) from public, anon, authenticated;
revoke all on function private.defence_owned(public.planets, text) from public, anon, authenticated;
revoke all on function private.apply_defence(public.planets, text) from public, anon, authenticated;
revoke all on function public.queue_defence(text, integer) from public, anon;
grant execute on function public.queue_defence(text, integer) to authenticated;
revoke all on function public.reset_empire() from public, anon;
grant execute on function public.reset_empire() to authenticated;

notify pgrst, 'reload schema';
