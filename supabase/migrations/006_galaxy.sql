-- OGame-style map: 9 galaxies, 499 systems, 15 slots, one star per system.
-- Field rolls, temperatures, and star multipliers match src/lib/game/catalog.ts.

create or replace function private.inclusive_pick(lo integer, hi integer, value_roll numeric)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when hi <= lo then lo
    else lo + least(
      hi - lo,
      floor(least(1::numeric, greatest(0::numeric, value_roll)) * (hi - lo + 1))
    )::integer
  end;
$$;

create or replace function private.roll_max_fields(p_slot integer, outer_roll numeric, value_roll numeric)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  lo integer;
  hi integer;
  width integer;
  low_lo integer;
  low_hi integer;
begin
  if p_slot <= 3 then
    lo := 40;
    hi := 70;
  elsif p_slot <= 6 then
    lo := 120;
    hi := 310;
  elsif p_slot <= 9 then
    lo := 125;
    hi := 255;
  elsif p_slot <= 12 then
    lo := 75;
    hi := 125;
  else
    lo := 60;
    hi := 190;
  end if;
  width := hi - lo;
  if outer_roll < 0.8 then
    return private.inclusive_pick(lo, hi, value_roll);
  elsif outer_roll < 0.9 then
    low_lo := greatest(20, lo - width);
    low_hi := lo - 1;
    if low_hi < low_lo then
      return private.inclusive_pick(hi + 1, hi + width, value_roll);
    end if;
    return private.inclusive_pick(low_lo, low_hi, value_roll);
  end if;
  return private.inclusive_pick(hi + 1, hi + width, value_roll);
end;
$$;

create or replace function private.slot_temp_min(p_slot integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_slot
    when 1 then 200
    when 2 then 150
    when 3 then 100
    when 4 then 50
    when 5 then 40
    when 6 then 30
    when 7 then 20
    when 8 then 10
    when 9 then 0
    when 10 then -10
    when 11 then -20
    when 12 then -30
    when 13 then -70
    when 14 then -110
    when 15 then -180
    else 10
  end;
$$;

create or replace function private.slot_temp_max(p_slot integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_slot
    when 1 then 260
    when 2 then 190
    when 3 then 140
    when 4 then 90
    when 5 then 80
    when 6 then 70
    when 7 then 60
    when 8 then 50
    when 9 then 40
    when 10 then 30
    when 11 then 20
    when 12 then 10
    when 13 then -30
    when 14 then -70
    when 15 then -110
    else 50
  end;
$$;

create or replace function private.star_multiplier(star_type text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case star_type
    when 'young_hot' then 1.5
    when 'old_cold' then 0.75
    when 'pulsar' then 3
    else 1
  end;
$$;

create table public.solar_systems (
  galaxy smallint not null check (galaxy between 1 and 9),
  system smallint not null check (system between 1 and 499),
  star_type text not null check (star_type in ('young_hot', 'medium', 'old_cold', 'pulsar')),
  primary key (galaxy, system)
);

insert into public.solar_systems (galaxy, system, star_type)
select galaxy, system,
  case
    when roll < 0.03 then 'pulsar'
    when roll < 0.28 then 'young_hot'
    when roll < 0.50 then 'old_cold'
    else 'medium'
  end
from (
  select g as galaxy, s as system, random() as roll
  from generate_series(1, 9) as g
  cross join generate_series(1, 499) as s
) seeded;

alter table public.solar_systems enable row level security;
alter table public.solar_systems force row level security;

create policy solar_systems_select
  on public.solar_systems
  for select
  to authenticated
  using (true);

grant select on table public.solar_systems to authenticated;
revoke all on table public.solar_systems from anon;

alter table public.planets drop constraint if exists planets_galaxy_check;
alter table public.planets drop constraint if exists planets_system_check;
alter table public.planets drop constraint if exists planets_slot_check;

alter table public.planets
  add constraint planets_galaxy_check check (galaxy between 1 and 9),
  add constraint planets_system_check check (system between 1 and 499),
  add constraint planets_slot_check check (slot between 1 and 15);

alter table public.planets
  add column temp_min smallint,
  add column temp_max smallint,
  add column max_fields smallint,
  add column diameter_km integer;

update public.planets as p
set
  max_fields = rolled.fields,
  diameter_km = round(1000 * sqrt(rolled.fields))::integer,
  temp_min = (private.slot_temp_min(p.slot) + rolled.offset)::smallint,
  temp_max = (private.slot_temp_max(p.slot) + rolled.offset)::smallint
from (
  select
    id,
    private.roll_max_fields(slot, random()::numeric, random()::numeric) as fields,
    (floor(random() * 21) - 10)::integer as offset
  from public.planets
) as rolled
where p.id = rolled.id;

alter table public.planets
  alter column temp_min set not null,
  alter column temp_max set not null,
  alter column max_fields set not null,
  alter column diameter_km set not null;

alter table public.planets
  add constraint planets_temp_order_check check (temp_max >= temp_min),
  add constraint planets_max_fields_check check (max_fields >= 20),
  add constraint planets_diameter_check check (diameter_km > 0);

create or replace function private.energy_factor(
  ore_mine integer,
  crystal_mine integer,
  power_plant integer,
  star_type text
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when private.mine_energy_drain(ore_mine) + private.mine_energy_drain(crystal_mine) <= 0 then 1
    else least(
      1::numeric,
      (
        case
          when power_plant <= 0 then 0
          else floor(20 * power_plant * power(1.1, power_plant) * private.star_multiplier(star_type))
        end
      )
        / (private.mine_energy_drain(ore_mine) + private.mine_energy_drain(crystal_mine))
    )
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
  p.ore := least(private.storage_cap(p.ore_mine), p.ore + ore_add);
  p.crystal := least(private.storage_cap(p.crystal_mine), p.crystal + crystal_add);
  p.last_harvested_at := at;
  return p;
end;
$$;

drop function if exists private.energy_factor(integer, integer, integer);

create or replace function private.flight_seconds(
  from_system integer,
  from_slot integer,
  to_system integer,
  to_slot integer,
  propulsion_level integer,
  from_galaxy integer default 0,
  to_galaxy integer default 0
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    15,
    floor(
      (
        20 + 12 * greatest(
          abs(from_galaxy - to_galaxy) * 40
            + abs(from_system - to_system)
            + abs(from_slot - to_slot),
          1
        )
      )
      / (1 + 0.1 * propulsion_level)
    )
  )::integer;
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
      origin.ore := least(private.storage_cap(origin.ore_mine), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_mine), origin.crystal + f.cargo_crystal);
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

create or replace function private.empire_state_json(uid uuid, at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.catch_up(uid, at);

  select jsonb_build_object(
    'profile', jsonb_build_object(
      'user_id', pr.user_id,
      'display_name', pr.display_name
    ),
    'planet', to_jsonb(p),
    'empire', to_jsonb(e),
    'star', jsonb_build_object(
      'type', coalesce(s.star_type, 'medium'),
      'multiplier', private.star_multiplier(coalesce(s.star_type, 'medium'))
    ),
    'rank', jsonb_build_object(
      'points', 0,
      'place', 1 + (
        select count(*)
        from public.empires earlier
        where earlier.created_at < e.created_at
          or (earlier.created_at = e.created_at and earlier.user_id < e.user_id)
      ),
      'total', (select count(*) from public.empires)
    ),
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', dp.name,
        'dest_galaxy', dp.galaxy,
        'dest_system', dp.system,
        'dest_slot', dp.slot,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'status', f.status,
        'report', f.report
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      join public.planets dp on dp.id = f.dest_planet_id
      where f.owner_id = uid and f.status = 'en_route'
    ),
    'reports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'title', r.title,
        'body', r.body,
        'loot_ore', r.loot_ore,
        'loot_crystal', r.loot_crystal
      ) order by r.created_at desc), '[]'::jsonb)
      from (
        select * from public.battle_reports
        where user_id = uid
        order by created_at desc
        limit 15
      ) r
    ),
    'server_now', at
  )
  into result
  from public.empires e
  join public.planets p on p.id = e.home_planet_id
  join public.profiles pr on pr.user_id = e.user_id
  left join public.solar_systems s on s.galaxy = p.galaxy and s.system = p.system
  where e.user_id = uid;

  return result;
end;
$$;

create or replace function private.bootstrap_empire(uid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  gal smallint;
  sys smallint;
  sl smallint;
  planet_id bigint;
  display text;
  placed boolean := false;
  attempt integer := 0;
  band numeric;
  fields integer;
  temp_shift integer;
begin
  if exists (select 1 from public.empires where user_id = uid) then
    return private.empire_state_json(uid, timezone('utc', now()));
  end if;

  select coalesce(split_part(u.email, '@', 1), 'Commander')
  into display
  from auth.users u
  where u.id = uid;

  insert into public.profiles (user_id, display_name)
  values (uid, coalesce(nullif(display, ''), 'Commander'))
  on conflict (user_id) do nothing;

  while attempt < 30 and not placed loop
    attempt := attempt + 1;
    gal := (1 + floor(random() * 9))::smallint;
    sys := (1 + floor(random() * 499))::smallint;
    band := random();
    if band < 0.90 then
      sl := (4 + floor(random() * 9))::smallint;
    elsif band < 0.95 then
      sl := (1 + floor(random() * 3))::smallint;
    else
      sl := (13 + floor(random() * 3))::smallint;
    end if;

    if not exists (
      select 1 from public.planets p
      where p.galaxy = gal and p.system = sys and p.slot = sl
    ) then
      placed := true;
    end if;
  end loop;

  if not placed then
    raise exception 'The void is full. No free worlds remain.';
  end if;

  -- Homeworlds are 12,800 km: floor(12.8^2) = 163 fields, plus 10 universe fields = 173.
  fields := floor(power(12800::numeric / 1000, 2))::integer + 10;
  temp_shift := (floor(random() * 21) - 10)::integer;

  insert into public.planets (
    owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at,
    ore_mine, crystal_mine, power_plant,
    temp_min, temp_max, max_fields, diameter_km
  )
  values (
    uid, gal, sys, sl, 'Homeworld', 1200, 500, timezone('utc', now()),
    1, 1, 1,
    (private.slot_temp_min(sl) + temp_shift)::smallint,
    (private.slot_temp_max(sl) + temp_shift)::smallint,
    fields,
    12800
  )
  returning id into planet_id;

  insert into public.empires (user_id, home_planet_id)
  values (uid, planet_id);

  return private.empire_state_json(uid, timezone('utc', now()));
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
  if p_building not in ('ore_mine', 'crystal_mine', 'power_plant') then
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
  if home.ore_mine + home.crystal_mine + home.power_plant >= home.max_fields then
    raise exception 'No free fields.';
  end if;

  lvl := case p_building
    when 'ore_mine' then home.ore_mine
    when 'crystal_mine' then home.crystal_mine
    else home.power_plant
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

drop function if exists public.send_raid(smallint, smallint, integer);

create or replace function public.send_raid(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_raiders integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  origin public.planets%rowtype;
  dest public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  flight integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_raiders is null or p_raiders < 1 then
    raise exception 'Send at least one raider.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space cannot be raided.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.raiders < p_raiders then
    raise exception 'Not enough raiders.';
  end if;

  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;

  if not found then
    raise exception 'No world at that coordinate.';
  end if;
  if dest.id = origin.id then
    raise exception 'Cannot raid your own planet.';
  end if;
  if dest.owner_id is not null then
    raise exception 'Commander worlds are protected in this version.';
  end if;

  flight := private.flight_seconds(
    origin.system,
    origin.slot,
    dest.system,
    dest.slot,
    e.propulsion_level,
    origin.galaxy,
    dest.galaxy
  );

  update public.empires set raiders = e.raiders - p_raiders where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at
  )
  values (
    uid, origin.id, dest.id, p_raiders, 'attack', at + make_interval(secs => flight)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.get_solar_system(p_galaxy smallint, p_system smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  result jsonb;
  star text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 then
    raise exception 'That coordinate is outside the universe.';
  end if;

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p_galaxy and s.system = p_system;

  select jsonb_build_object(
    'galaxy', p_galaxy,
    'system', p_system,
    'star_type', coalesce(star, 'medium'),
    'multiplier', private.star_multiplier(coalesce(star, 'medium')),
    'slots', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'slot', sl.slot,
        'kind', case
          when sl.slot = 16 then 'outer'
          when pl.id is null then 'empty'
          when pl.owner_id = uid then 'home'
          when pl.owner_id is not null then 'player'
          else 'npc'
        end,
        'planet_id', pl.id,
        'name', case when sl.slot = 16 then 'Outer space' else pl.name end,
        'owner_name', pf.display_name
      ) order by sl.slot), '[]'::jsonb)
      from generate_series(1, 16) as sl(slot)
      left join public.planets pl
        on pl.galaxy = p_galaxy
        and pl.system = p_system
        and pl.slot = sl.slot
        and sl.slot <= 15
      left join public.profiles pf on pf.user_id = pl.owner_id
    )
  )
  into result;

  return result;
end;
$$;

drop function if exists private.flight_seconds(integer, integer, integer, integer, integer);

revoke all on function private.inclusive_pick(integer, integer, numeric) from public, anon, authenticated;
revoke all on function private.roll_max_fields(integer, numeric, numeric) from public, anon, authenticated;
revoke all on function private.slot_temp_min(integer) from public, anon, authenticated;
revoke all on function private.slot_temp_max(integer) from public, anon, authenticated;
revoke all on function private.star_multiplier(text) from public, anon, authenticated;
revoke all on function private.energy_factor(integer, integer, integer, text) from public, anon, authenticated;
revoke all on function private.flight_seconds(integer, integer, integer, integer, integer, integer, integer) from public, anon, authenticated;

revoke all on function public.send_raid(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_raid(smallint, smallint, smallint, integer) to authenticated;

revoke all on function public.get_solar_system(smallint, smallint) from public, anon;
grant execute on function public.get_solar_system(smallint, smallint) to authenticated;
