-- Ore and crystal storage. Capacity is floor(2.5 * e^((20/33) * level)) * 5000.
-- Level 0 is 10,000. Cost factor is 2: ore storage 1000 metal, crystal storage 1000 metal and 500 crystal.

alter table public.planets
  add column ore_storage smallint not null default 0,
  add column crystal_storage smallint not null default 0;

alter table public.planets
  add constraint planets_ore_storage_check check (ore_storage >= 0),
  add constraint planets_crystal_storage_check check (crystal_storage >= 0);

alter table public.planets drop constraint if exists planets_upgrade_building_check;

alter table public.planets
  add constraint planets_upgrade_building_check
  check (
    upgrade_building is null
    or upgrade_building in ('ore_mine', 'crystal_mine', 'power_plant', 'ore_storage', 'crystal_storage')
  );

create or replace function private.storage_cap(mine_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select (floor(2.5 * exp((20.0 / 33.0) * greatest(mine_level, 0))) * 5000)::bigint;
$$;

update public.planets as p
set
  ore_storage = needed.ore_level,
  crystal_storage = needed.crystal_level
from (
  select
    id,
    coalesce((
      select min(gs)
      from generate_series(0, 30) as gs
      where private.storage_cap(gs) >= planets.ore
    ), 0) as ore_level,
    coalesce((
      select min(gs)
      from generate_series(0, 30) as gs
      where private.storage_cap(gs) >= planets.crystal
    ), 0) as crystal_level
  from public.planets
) as needed
where p.id = needed.id;

create or replace function private.building_cost_ore(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(60 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(48 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(75 * power(1.5, current_level))::bigint
    when 'ore_storage' then floor(1000 * power(2, current_level))::bigint
    when 'crystal_storage' then floor(1000 * power(2, current_level))::bigint
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
    when 'crystal_mine' then floor(24 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(30 * power(1.5, current_level))::bigint
    when 'ore_storage' then 0
    when 'crystal_storage' then floor(500 * power(2, current_level))::bigint
    else 0
  end;
$$;

create or replace function private.tick_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
stable
set search_path = ''
as $$
declare
  elapsed numeric;
  factor numeric;
  ore_add bigint;
  crystal_add bigint;
  star text;
begin
  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p.galaxy and s.system = p.system;

  elapsed := greatest(0, extract(epoch from (at - p.last_harvested_at)));
  factor := private.energy_factor(p.ore_mine, p.crystal_mine, p.power_plant, coalesce(star, 'medium'));
  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  p.ore := least(private.storage_cap(p.ore_storage), p.ore + ore_add);
  p.crystal := least(private.storage_cap(p.crystal_storage), p.crystal + crystal_add);
  p.last_harvested_at := at;
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
    elsif p.upgrade_building = 'ore_storage' then
      p.ore_storage := p.ore_storage + 1;
    elsif p.upgrade_building = 'crystal_storage' then
      p.crystal_storage := p.crystal_storage + 1;
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

create or replace function private.catch_up(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.empires%rowtype;
  home public.planets%rowtype;
  dest public.planets%rowtype;
  origin public.planets%rowtype;
  f public.fleets%rowtype;
  loot_ore bigint;
  loot_crystal bigint;
  cargo_left bigint;
  flight integer;
  waves integer;
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e.propulsion_level := e.propulsion_level + 1;
    e.research_completes_at := null;
  end if;

  while e.raiders_queued > 0 and e.raider_completes_at is not null and e.raider_completes_at <= at loop
    e.raiders := e.raiders + 1;
    e.raiders_queued := e.raiders_queued - 1;
    if e.raiders_queued > 0 then
      e.raider_completes_at := e.raider_completes_at + make_interval(secs => 15);
    else
      e.raider_completes_at := null;
    end if;
  end loop;

  loop
    select * into f
    from public.fleets
    where owner_id = uid
      and status = 'en_route'
      and arrives_at <= at
    order by arrives_at
    limit 1
    for update skip locked;

    exit when not found;

    if f.mission = 'attack' then
      select * into dest from public.planets where id = f.dest_planet_id for update;
      dest := private.catch_up_planet(dest, f.arrives_at);
      cargo_left := f.raiders * 5000;
      select h.loot_ore, h.loot_crystal
        into loot_ore, loot_crystal
      from private.raid_haul(dest.ore, dest.crystal, cargo_left) as h;
      dest.ore := dest.ore - loot_ore;
      dest.crystal := dest.crystal - loot_crystal;
      perform private.persist_planet(dest);

      select * into origin from public.planets where id = f.origin_planet_id;
      flight := private.flight_seconds(
        origin.system,
        origin.slot,
        dest.system,
        dest.slot,
        e.propulsion_level,
        origin.galaxy,
        dest.galaxy
      );

      update public.fleets
      set
        mission = 'return',
        cargo_ore = loot_ore,
        cargo_crystal = loot_crystal,
        arrives_at = f.arrives_at + make_interval(secs => flight),
        report = format('Raid on %s: +%s ore, +%s crystal.', dest.name, loot_ore, loot_crystal)
      where id = f.id;
    else
      select * into origin from public.planets where id = f.origin_planet_id for update;
      origin := private.catch_up_planet(origin, f.arrives_at);
      origin.ore := least(private.storage_cap(origin.ore_storage), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_storage), origin.crystal + f.cargo_crystal);
      perform private.persist_planet(origin);

      e.raiders := e.raiders + f.raiders;
      if origin.id = home.id then
        home := origin;
      end if;

      update public.fleets
      set status = 'completed'
      where id = f.id;

      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        uid,
        'Fleet returned',
        coalesce(f.report, 'The raiders dumped their holds.'),
        f.cargo_ore,
        f.cargo_crystal
      );
    end if;
  end loop;

  home := private.catch_up_planet(home, at);

  if e.next_pirate_at is null then
    e.next_pirate_at := at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
  else
    waves := 0;
    while e.next_pirate_at is not null and e.next_pirate_at <= at and waves < 8 loop
      home := private.resolve_pirate_wave(home, uid, e.next_pirate_at);
      e.next_pirate_at := e.next_pirate_at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
      waves := waves + 1;
    end loop;
    if e.next_pirate_at is not null and e.next_pirate_at <= at then
      e.next_pirate_at := at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
    end if;
  end if;

  perform private.persist_planet(home);

  update public.empires
  set
    propulsion_level = e.propulsion_level,
    raiders = e.raiders,
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    research_completes_at = e.research_completes_at,
    next_pirate_at = e.next_pirate_at
  where user_id = uid;
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
  home public.planets%rowtype;
  lvl integer;
  cost_ore bigint;
  cost_crystal bigint;
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_building not in ('ore_mine', 'crystal_mine', 'power_plant', 'ore_storage', 'crystal_storage') then
    raise exception 'Unknown structure.';
  end if;

  perform private.catch_up(uid, at);
  select * into home
  from public.planets
  where owner_id = uid
  for update;

  if home.upgrade_building is not null then
    raise exception 'An upgrade is already running.';
  end if;
  if home.ore_mine + home.crystal_mine + home.power_plant + home.ore_storage + home.crystal_storage >= home.max_fields then
    raise exception 'No free fields.';
  end if;

  lvl := case p_building
    when 'ore_mine' then home.ore_mine
    when 'crystal_mine' then home.crystal_mine
    when 'power_plant' then home.power_plant
    when 'ore_storage' then home.ore_storage
    else home.crystal_storage
  end;
  cost_ore := private.building_cost_ore(p_building, lvl);
  cost_crystal := private.building_cost_crystal(p_building, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    upgrade_building = p_building,
    upgrade_completes_at = at + make_interval(secs => private.building_time_seconds(lvl))
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
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  lvl integer;
  duration_secs integer;
  start_at timestamptz;
  progress double precision;
  cost_ore bigint;
  cost_crystal bigint;
  refund_ore bigint;
  refund_crystal bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into home
  from public.planets
  where owner_id = uid
  for update;

  if home.upgrade_building is null or home.upgrade_completes_at is null then
    raise exception 'Nothing is being built.';
  end if;

  lvl := case home.upgrade_building
    when 'ore_mine' then home.ore_mine
    when 'crystal_mine' then home.crystal_mine
    when 'power_plant' then home.power_plant
    when 'ore_storage' then home.ore_storage
    else home.crystal_storage
  end;
  duration_secs := greatest(private.building_time_seconds(lvl), 1);
  start_at := home.upgrade_completes_at - make_interval(secs => duration_secs);
  progress := least(
    1.0::double precision,
    greatest(
      0.0::double precision,
      extract(epoch from (at - start_at)) / duration_secs::double precision
    )
  );
  cost_ore := private.building_cost_ore(home.upgrade_building, lvl);
  cost_crystal := private.building_cost_crystal(home.upgrade_building, lvl);
  refund_ore := floor(cost_ore * (1.0 - progress))::bigint;
  refund_crystal := floor(cost_crystal * (1.0 - progress))::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + refund_crystal),
    upgrade_building = null,
    upgrade_completes_at = null
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
