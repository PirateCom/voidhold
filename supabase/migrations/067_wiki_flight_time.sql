-- Wiki distance (circular systems) and hull base speed with drive bonuses drive flight time.
-- Duration: round((35000 / % * sqrt(distance * 1000 / speed) + 10) / universe fleet speed).

drop function if exists private.ship_speed(text, integer, integer);

create or replace function private.wiki_flight_distance(
  from_galaxy integer,
  from_system integer,
  from_slot integer,
  to_galaxy integer,
  to_system integer,
  to_slot integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when abs(from_galaxy - to_galaxy) > 0 then 20000 * abs(from_galaxy - to_galaxy)
    when abs(from_system - to_system) > 0 then
      2700 + 95 * least(abs(from_system - to_system), 499 - abs(from_system - to_system))
    when abs(from_slot - to_slot) > 0 then 1000 + 5 * abs(from_slot - to_slot)
    else 5
  end;
$$;

create or replace function private.wiki_travel_seconds(
  distance integer,
  ship_speed integer,
  speed_percent integer default 100
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    1,
    round(
      35000.0 / greatest(10, least(100, coalesce(speed_percent, 100)))
        * sqrt(greatest(distance, 1)::numeric * 1000 / greatest(ship_speed, 1))
        + 10
    )::integer
  );
$$;

create or replace function private.ship_speed(
  id text,
  impulse integer,
  hyperspace integer,
  combustion integer default 0
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when base.speed <= 0 then 0
    else floor(
      base.speed * (
        1 + case base.drive
          when 'combustion' then 0.1 * coalesce(combustion, 0)
          when 'impulse' then 0.2 * coalesce(impulse, 0)
          else 0.3 * coalesce(hyperspace, 0)
        end
      )
    )::integer
  end
  from (
    select
      case id
        when 'light_fighter' then 12500
        when 'heavy_fighter' then 10000
        when 'cruiser' then 15000
        when 'battleship' then 10000
        when 'battlecruiser' then 10000
        when 'bomber' then case when coalesce(hyperspace, 0) >= 8 then 5000 else 4000 end
        when 'destroyer' then 5000
        when 'deathstar' then 100
        when 'small_cargo' then case when coalesce(impulse, 0) >= 5 then 10000 else 5000 end
        when 'large_cargo' then 7500
        when 'colony_ship' then 2500
        when 'recycler' then 2000
        when 'espionage_probe' then 100000000
        when 'reaper' then 7000
        when 'pathfinder' then 12000
        else 0
      end as speed,
      case
        when id = 'small_cargo' and coalesce(impulse, 0) >= 5 then 'impulse'
        when id = 'bomber' and coalesce(hyperspace, 0) >= 8 then 'hyperspace'
        when id in ('light_fighter', 'large_cargo', 'recycler', 'espionage_probe', 'small_cargo') then 'combustion'
        when id in ('heavy_fighter', 'cruiser', 'colony_ship', 'bomber') then 'impulse'
        when id in ('battleship', 'battlecruiser', 'destroyer', 'deathstar', 'reaper', 'pathfinder') then 'hyperspace'
        else 'combustion'
      end as drive
  ) base;
$$;

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
  select private.wiki_travel_seconds(
    private.wiki_flight_distance(from_galaxy, from_system, from_slot, to_galaxy, to_system, to_slot),
    private.ship_speed('small_cargo', 0, 0, propulsion_level),
    100
  );
$$;

revoke all on function private.wiki_flight_distance(integer, integer, integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.wiki_travel_seconds(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.ship_speed(text, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.flight_seconds(integer, integer, integer, integer, integer, integer, integer) from public, anon, authenticated;

create or replace function public.send_attack(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_ships jsonb,
  p_speed smallint default 100
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
  ships jsonb := '{}'::jsonb;
  rec record;
  have integer;
  total integer := 0;
  recent integer;
  counter boolean;
  distance integer;
  fuel bigint := 0;
  slowest integer;
  spd integer;
  flight integer;
  factor numeric;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_speed is null then
    p_speed := 100;
  end if;
  if p_speed < 10 or p_speed > 100 or p_speed % 10 <> 0 then
    raise exception 'Speed must be 10 to 100 percent.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space cannot be attacked.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;
  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;
  if not found then
    raise exception 'No world at that coordinate.';
  end if;
  if dest.id = origin.id or dest.owner_id = uid then
    raise exception 'Cannot attack your own planet.';
  end if;

  for rec in
    select key, greatest(value::integer, 0) as n
    from jsonb_each_text(coalesce(p_ships, '{}'::jsonb))
  loop
    if rec.n <= 0 then
      continue;
    end if;
    if private.ship_speed(rec.key, 0, 0) <= 0 then
      raise exception 'That hull cannot fly.';
    end if;
    have := coalesce((e.ships->>rec.key)::integer, 0);
    if rec.key = 'small_cargo' then
      have := greatest(have, e.raiders);
    end if;
    if have < rec.n then
      raise exception 'Not enough ships.';
    end if;
    ships := ships || jsonb_build_object(rec.key, rec.n);
    total := total + rec.n;
  end loop;
  if total < 1 then
    raise exception 'Send at least one ship.';
  end if;

  if dest.owner_id is not null then
    select count(*)::integer into recent
    from public.fleets
    where owner_id = uid
      and dest_planet_id = dest.id
      and created_at > at - interval '24 hours'
      and mission in ('attack', 'return');
    select exists (
      select 1
      from public.fleets
      where owner_id = dest.owner_id
        and dest_planet_id = origin.id
        and created_at > at - interval '24 hours'
        and mission in ('attack', 'return')
    ) into counter;
    if recent >= 6 and not counter then
      raise exception 'Bash protection: that planet was already attacked 6 times in 24 hours.';
    end if;
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot);
  slowest := null;
  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    fuel := fuel + private.fleet_fuel_round_trip(rec.n, private.ship_fuel(rec.key, e.impulse_drive), distance);
    spd := private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
    if slowest is null or spd < slowest then
      slowest := spd;
    end if;
  end loop;
  factor := power((p_speed / 10.0) + 1, 2) / 121.0;
  if fuel > 0 then
    fuel := greatest(1, round(fuel * factor)::bigint);
  end if;
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  flight := private.wiki_travel_seconds(distance, slowest, p_speed);

  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    e.ships := private.bump_ship(e.ships, rec.key, -rec.n);
    if rec.key = 'small_cargo' then
      e.raiders := e.raiders - rec.n;
    end if;
  end loop;

  update public.planets set deuterium = origin.deuterium - fuel where id = origin.id;
  update public.empires set raiders = e.raiders, ships = e.ships where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid,
    origin.id,
    dest.id,
    coalesce((ships->>'small_cargo')::integer, 0),
    'attack',
    at + make_interval(secs => flight),
    ships,
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_transport(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_ships jsonb,
  p_ore bigint,
  p_crystal bigint,
  p_deuterium bigint,
  p_speed smallint default 100
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
  ships jsonb := '{}'::jsonb;
  rec record;
  have integer;
  total integer := 0;
  capacity bigint := 0;
  load_ore bigint := greatest(coalesce(p_ore, 0), 0);
  load_crystal bigint := greatest(coalesce(p_crystal, 0), 0);
  load_deut bigint := greatest(coalesce(p_deuterium, 0), 0);
  distance integer;
  fuel bigint := 0;
  slowest integer;
  spd integer;
  flight integer;
  factor numeric;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_speed is null then
    p_speed := 100;
  end if;
  if p_speed < 10 or p_speed > 100 or p_speed % 10 <> 0 then
    raise exception 'Speed must be 10 to 100 percent.';
  end if;
  if p_slot < 1 or p_slot > 15 then
    raise exception 'Transports need a planet.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;
  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot;
  if not found or dest.owner_id is null then
    raise exception 'Transports need a commander''s planet.';
  end if;
  if dest.id = origin.id then
    raise exception 'That is the planet you are sending from.';
  end if;

  for rec in
    select key, greatest(value::integer, 0) as n
    from jsonb_each_text(coalesce(p_ships, '{}'::jsonb))
  loop
    if rec.n <= 0 then
      continue;
    end if;
    if private.ship_speed(rec.key, 0, 0) <= 0 then
      raise exception 'That hull cannot fly.';
    end if;
    have := coalesce((e.ships->>rec.key)::integer, 0);
    if rec.key = 'small_cargo' then
      have := greatest(have, e.raiders);
    end if;
    if have < rec.n then
      raise exception 'Not enough ships.';
    end if;
    ships := ships || jsonb_build_object(rec.key, rec.n);
    total := total + rec.n;
    capacity := capacity + rec.n::bigint * coalesce(private.ship_cargo(rec.key), 0);
  end loop;
  if total < 1 then
    raise exception 'Send at least one ship.';
  end if;
  if load_ore + load_crystal + load_deut < 1 then
    raise exception 'Load some cargo.';
  end if;
  if load_ore + load_crystal + load_deut > capacity then
    raise exception 'Not enough cargo space.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot);
  slowest := null;
  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    fuel := fuel + private.fleet_fuel_round_trip(rec.n, private.ship_fuel(rec.key, e.impulse_drive), distance);
    spd := private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
    if slowest is null or spd < slowest then
      slowest := spd;
    end if;
  end loop;
  factor := power((p_speed / 10.0) + 1, 2) / 121.0;
  if fuel > 0 then
    fuel := greatest(1, round(fuel * factor)::bigint);
  end if;
  if origin.ore < load_ore or origin.crystal < load_crystal or origin.deuterium < load_deut + fuel then
    raise exception 'Not enough resources.';
  end if;

  flight := private.wiki_travel_seconds(distance, slowest, p_speed);

  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    e.ships := private.bump_ship(e.ships, rec.key, -rec.n);
    if rec.key = 'small_cargo' then
      e.raiders := e.raiders - rec.n;
    end if;
  end loop;

  update public.planets
  set
    ore = origin.ore - load_ore,
    crystal = origin.crystal - load_crystal,
    deuterium = origin.deuterium - load_deut - fuel
  where id = origin.id;
  update public.empires set raiders = e.raiders, ships = e.ships where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at, composition, flight_seconds,
    cargo_ore, cargo_crystal, cargo_deuterium
  )
  values (
    uid,
    origin.id,
    dest.id,
    coalesce((ships->>'small_cargo')::integer, 0),
    'transport',
    at + make_interval(secs => flight),
    ships,
    flight,
    load_ore,
    load_crystal,
    load_deut
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_colonize(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_ships integer default 1
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
  at timestamptz := timezone('utc', now());
  have integer;
  used integer;
  inflight integer;
  distance integer;
  fuel bigint := 0;
  slowest integer;
  flight integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_ships is null or p_ships < 1 then
    raise exception 'Send at least one colony ship.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space cannot be colonized.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.astrophysics < 1 then
    raise exception 'Needs Astrophysics 1.';
  end if;
  if p_slot < private.colonize_slot_min(e.astrophysics) or p_slot > private.colonize_slot_max(e.astrophysics) then
    raise exception 'Astrophysics only allows slots %–%.',
      private.colonize_slot_min(e.astrophysics),
      private.colonize_slot_max(e.astrophysics);
  end if;

  have := coalesce((e.ships->>'colony_ship')::integer, 0);
  if have < p_ships then
    raise exception 'Not enough colony ships.';
  end if;

  if exists (
    select 1 from public.planets p
    where p.galaxy = p_galaxy and p.system = p_system and p.slot = p_slot
  ) then
    raise exception 'That slot is already occupied.';
  end if;

  select count(*)::integer into used from public.planets p where p.owner_id = uid;
  select count(*)::integer into inflight
  from public.fleets f
  where f.owner_id = uid and f.status = 'en_route' and f.mission = 'colonize';
  if used + inflight >= private.max_planets(e.astrophysics) then
    raise exception 'No free colony slots. Research more Astrophysics.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, p_slot);
  fuel := private.fleet_fuel_round_trip(p_ships, private.ship_fuel('colony_ship', e.impulse_drive), distance);
  if fuel > 0 then
    fuel := greatest(1, fuel);
  end if;
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  slowest := private.ship_speed('colony_ship', e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
  flight := private.wiki_travel_seconds(distance, slowest, 100);

  update public.planets set deuterium = origin.deuterium - fuel where id = origin.id;
  update public.empires set ships = private.bump_ship(e.ships, 'colony_ship', -p_ships) where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id,
    dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid,
    origin.id,
    null,
    p_galaxy,
    p_system,
    p_slot,
    0,
    'colonize',
    at + make_interval(secs => flight),
    jsonb_build_object('colony_ship', p_ships),
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_harvest(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_recyclers integer
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
  dest_planet_id bigint;
  at timestamptz := timezone('utc', now());
  have integer;
  distance integer;
  fuel bigint := 0;
  slowest integer;
  flight integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_recyclers is null or p_recyclers < 1 then
    raise exception 'Send at least one recycler.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space has no debris field.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  have := coalesce((e.ships->>'recycler')::integer, 0);
  if have < p_recyclers then
    raise exception 'Not enough recyclers.';
  end if;

  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;
  dest_planet_id := dest.id;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, p_slot);
  fuel := private.fleet_fuel_round_trip(p_recyclers, private.ship_fuel('recycler', e.impulse_drive), distance);
  if fuel > 0 then
    fuel := greatest(1, fuel);
  end if;
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  slowest := private.ship_speed('recycler', e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
  flight := private.wiki_travel_seconds(distance, slowest, 100);

  update public.planets set deuterium = origin.deuterium - fuel where id = origin.id;
  update public.empires set ships = private.bump_ship(e.ships, 'recycler', -p_recyclers) where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id,
    dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid,
    origin.id,
    dest_planet_id,
    p_galaxy,
    p_system,
    p_slot,
    0,
    'harvest',
    at + make_interval(secs => flight),
    jsonb_build_object('recycler', p_recyclers),
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_spy(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_probes integer
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
  docked integer;
  flight integer;
  fuel bigint;
  distance integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_probes is null or p_probes < 1 then
    raise exception 'Send at least one probe.';
  end if;
  if p_slot = 16 then
    raise exception 'Outer space cannot be probed.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if private.research_level(e, 'espionage_tech') < 2 then
    raise exception 'Needs Espionage technology 2.';
  end if;

  docked := coalesce((e.ships->>'espionage_probe')::integer, 0);
  if docked < p_probes then
    raise exception 'Not enough espionage probes.';
  end if;

  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;

  if not found then
    raise exception 'No world at that coordinate.';
  end if;
  if dest.id = origin.id then
    raise exception 'Cannot spy on your own planet.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot);
  flight := private.wiki_travel_seconds(
    distance,
    private.ship_speed('espionage_probe', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
    100
  );
  fuel := private.fleet_fuel_round_trip(p_probes, 1, distance);
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set deuterium = origin.deuterium - fuel
  where id = origin.id;

  update public.empires
  set ships = private.bump_ship(e.ships, 'espionage_probe', -p_probes)
  where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id,
    dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid, origin.id, dest.id,
    dest.galaxy, dest.system, dest.slot,
    p_probes, 'espionage', at + make_interval(secs => flight),
    jsonb_build_object('espionage_probe', p_probes),
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_expedition_to(p_galaxy smallint, p_system smallint, p_slot smallint, p_ships jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  origin public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  ships integer;
  active integer;
  cap integer;
  flight integer;
  extra integer;
  fuel bigint;
  distance integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 or p_slot < 1 or p_slot > 16 then
    raise exception 'That coordinate is outside the universe.';
  end if;
  if p_slot <> 16 and exists (
    select 1 from public.planets pl
    where pl.galaxy = p_galaxy and pl.system = p_system and pl.slot = p_slot
  ) then
    raise exception 'Expeditions need an empty slot or position 16.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.astrophysics < 1 then
    raise exception 'Needs Astrophysics 1.';
  end if;

  extra := (
    select coalesce(sum((kv.value)::integer), 0)
    from jsonb_each_text(coalesce(p_ships, '{}'::jsonb)) kv
    where kv.key <> 'small_cargo' and (kv.value)::integer > 0
  );
  if extra > 0 then
    raise exception 'That hull is not docked yet.';
  end if;

  ships := coalesce((p_ships ->> 'small_cargo')::integer, 0);
  if ships < 1 then
    raise exception 'Send at least one small cargo.';
  end if;
  if e.raiders < ships then
    raise exception 'Not enough small cargo.';
  end if;

  cap := private.expedition_fleet_cap(e.astrophysics);
  select count(*)::integer into active
  from public.fleets
  where owner_id = uid
    and status = 'en_route'
    and mission in ('expedition', 'expedition_hold', 'expedition_return');
  if active >= cap then
    raise exception 'No free expedition slots.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, p_slot);
  flight := private.wiki_travel_seconds(
    distance,
    private.ship_speed('small_cargo', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
    100
  );
  fuel := private.fleet_fuel_round_trip(
    ships,
    private.small_cargo_fuel(e.impulse_drive),
    distance
  );
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set deuterium = origin.deuterium - fuel
  where id = origin.id;

  update public.empires
  set
    raiders = e.raiders - ships,
    ships = private.bump_ship(e.ships, 'small_cargo', -ships)
  where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid, origin.id, null, p_galaxy, p_system, p_slot,
    ships, 'expedition', at + make_interval(secs => flight), jsonb_build_object('small_cargo', ships),
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.send_attack(smallint, smallint, smallint, jsonb, smallint) from public, anon;
grant execute on function public.send_attack(smallint, smallint, smallint, jsonb, smallint) to authenticated;
revoke all on function public.send_transport(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) from public, anon;
grant execute on function public.send_transport(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) to authenticated;
revoke all on function public.send_colonize(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_colonize(smallint, smallint, smallint, integer) to authenticated;
revoke all on function public.send_harvest(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_harvest(smallint, smallint, smallint, integer) to authenticated;
revoke all on function public.send_spy(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_spy(smallint, smallint, smallint, integer) to authenticated;
revoke all on function public.send_expedition_to(smallint, smallint, smallint, jsonb) from public, anon;
grant execute on function public.send_expedition_to(smallint, smallint, smallint, jsonb) to authenticated;


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
  owned public.planets%rowtype;
  loot_ore bigint;
  loot_crystal bigint;
  loot_deut bigint;
  cargo_left bigint;
  flight integer;
  waves integer;
  kind text;
  amount bigint;
  lost integer;
  extra integer;
  pick integer;
  hull text;
  kv record;
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e := private.apply_research(e, coalesce(e.research_tech, 'combustion_drive'));
  end if;


  loop
    select * into f
    from public.fleets
    where status = 'en_route'
      and arrives_at <= at
      and (
        owner_id = uid
        or (owner_id is null and dest_planet_id in (select id from public.planets where owner_id = uid))
        or (mission = 'attack' and dest_planet_id in (select id from public.planets where owner_id = uid))
      )
    order by arrives_at
    limit 1
    for update skip locked;

    exit when not found;

    if f.owner_id is null then
      select * into dest from public.planets where id = f.dest_planet_id for update;
      dest := private.resolve_pirate_wave(dest, uid, f.arrives_at, f.raiders);
      perform private.persist_planet(dest);
      if dest.id = home.id then
        home := dest;
      end if;
      update public.fleets set status = 'completed' where id = f.id;
    elsif f.mission = 'attack' then
      if private.resolve_attack_arrival(coalesce(f.owner_id, uid), e, f) then
        exit;
      end if;
    elsif f.mission = 'transport' then
      perform private.resolve_transport_arrival(f);
      if f.dest_planet_id = home.id then
        select * into home from public.planets where id = home.id for update;
      end if;
    elsif f.mission = 'espionage' then
      perform private.resolve_espionage_arrival(uid, e, f);
    elsif f.mission = 'espionage_return' then
      select * into origin from public.planets where id = f.origin_planet_id for update;
      origin := private.catch_up_planet(origin, f.arrives_at);
      perform private.persist_planet(origin);
      e.ships := private.bump_ship(e.ships, 'espionage_probe', f.raiders);
      if origin.id = home.id then
        home := origin;
      end if;
      update public.fleets set status = 'completed' where id = f.id;
    elsif f.mission = 'harvest' then
      perform private.resolve_harvest_arrival(uid, e, f);
    elsif f.mission = 'colonize' then
      perform private.resolve_colonize_arrival(uid, e, f);
    elsif f.mission = 'expedition' then
      update public.fleets
      set
        mission = 'expedition_hold',
        arrives_at = f.arrives_at + make_interval(secs => 60)
      where id = f.id;
    elsif f.mission = 'expedition_hold' then
      select * into origin from public.planets where id = f.origin_planet_id;
      flight := private.wiki_travel_seconds(
        private.wiki_flight_distance(
          origin.galaxy,
          origin.system,
          origin.slot,
          coalesce(f.dest_galaxy, origin.galaxy),
          coalesce(f.dest_system, origin.system),
          coalesce(f.dest_slot, 16)
        ),
        private.ship_speed('small_cargo', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
        100
      );
      pick := floor(random() * 1000)::integer;
      if pick < 300 then
        kind := 'nothing';
      elsif pick < 580 then
        kind := 'resources';
      elsif pick < 680 then
        kind := 'ships';
      elsif pick < 736 then
        kind := 'pirates';
      elsif pick < 762 then
        kind := 'aliens';
      elsif pick < 790 then
        kind := 'lost';
      elsif pick < 890 then
        kind := 'delay';
      else
        kind := 'nothing';
      end if;

      if kind = 'delay' then
        update public.fleets
        set
          arrives_at = f.arrives_at + make_interval(secs => 60),
          report = 'The void stretched. The expedition is delayed.'
        where id = f.id;
      elsif kind = 'lost' then
        update public.fleets
        set
          status = 'completed',
          raiders = 0,
          report = 'The fleet was lost in the void.'
        where id = f.id;
        insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
        values (
          uid,
          'Expedition lost',
          'Contact with the expedition fleet ended. The ships did not return.',
          0,
          0
        );
      else
        loot_ore := 0;
        loot_crystal := 0;
        loot_deut := 0;
        extra := 0;
        lost := 0;
        if kind = 'pirates' then
          lost := least(f.raiders, greatest(1, floor(f.raiders * 0.33)::integer));
        elsif kind = 'aliens' then
          lost := least(f.raiders, greatest(1, floor(f.raiders * 0.5)::integer));
        elsif kind = 'resources' then
          amount := greatest(1, floor(f.raiders * 5000 * (0.15 + random() * 0.35))::bigint);
          pick := floor(random() * 3)::integer;
          if pick = 0 then
            loot_ore := amount;
          elsif pick = 1 then
            loot_crystal := amount;
          else
            loot_deut := amount;
          end if;
        elsif kind = 'ships' then
          extra := 1 + floor(random() * 3)::integer;
        end if;

        if f.raiders - lost < 1 then
          update public.fleets
          set
            status = 'completed',
            raiders = 0,
            report = case
              when kind = 'pirates' then format('Pirates struck. %s small cargo lost.', lost)
              else format('Aliens struck. %s small cargo lost.', lost)
            end
          where id = f.id;
          insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
          values (
            uid,
            'Expedition defeated',
            case
              when kind = 'pirates' then format('Pirates struck. %s small cargo lost.', lost)
              else format('Aliens struck. %s small cargo lost.', lost)
            end,
            0,
            0
          );
        else
          update public.fleets
          set
            mission = 'expedition_return',
            raiders = f.raiders - lost + extra,
            cargo_ore = loot_ore,
            cargo_crystal = loot_crystal,
            cargo_deuterium = loot_deut,
            arrives_at = f.arrives_at + make_interval(secs => flight),
            report = case
              when kind = 'resources' and loot_ore > 0 then format('The holders found %s ore.', loot_ore)
              when kind = 'resources' and loot_crystal > 0 then format('The holders found %s crystal.', loot_crystal)
              when kind = 'resources' then format('The holders found %s deuterium.', loot_deut)
              when kind = 'ships' then format('The expedition recovered %s small cargo.', extra)
              when kind = 'pirates' then format('Pirates struck. %s small cargo lost.', lost)
              when kind = 'aliens' then format('Aliens struck. %s small cargo lost.', lost)
              else 'The expedition found empty space.'
            end
          where id = f.id;
        end if;
      end if;
    else
      select * into origin from public.planets where id = f.origin_planet_id for update;
      origin := private.catch_up_planet(origin, f.arrives_at);
      loot_ore := origin.ore;
      loot_crystal := origin.crystal;
      loot_deut := origin.deuterium;
      origin.ore := least(private.storage_cap(origin.ore_storage), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_storage), origin.crystal + f.cargo_crystal);
      origin.deuterium := least(
        private.storage_cap(origin.deuterium_storage),
        origin.deuterium + coalesce(f.cargo_deuterium, 0)
      );
      perform private.persist_planet(origin);

      if f.mission <> 'expedition_return' and coalesce(f.composition, '{}'::jsonb) <> '{}'::jsonb then
        for kv in
          select j.key, (j.value)::integer as n
          from jsonb_each_text(f.composition) as j
        loop
          if kv.n > 0 then
            e.ships := private.bump_ship(e.ships, kv.key, kv.n);
            if kv.key = 'small_cargo' then
              e.raiders := e.raiders + kv.n;
            end if;
          end if;
        end loop;
      else
        e.raiders := e.raiders + f.raiders;
        e.ships := private.bump_ship(e.ships, 'small_cargo', f.raiders);
      end if;
      if origin.id = home.id then
        home := origin;
      end if;

      update public.fleets
      set status = 'completed'
      where id = f.id;

      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        uid,
        case f.mission
          when 'return' then 'Attack fleet returned'
          when 'harvest_return' then 'Recyclers returned'
          when 'colonize_return' then 'Colony ship returned'
          when 'expedition_return' then 'Expedition returned'
          when 'transport_return' then 'Transport fleet returned'
          else 'Fleet returned'
        end,
        concat_ws(
          ' ',
          f.report,
          case
            when coalesce(f.cargo_ore, 0) + coalesce(f.cargo_crystal, 0) + coalesce(f.cargo_deuterium, 0) > 0 then
              format(
                'Unloaded at %s [%s:%s:%s]: %s ore, %s crystal, %s deuterium.',
                origin.name, origin.galaxy, origin.system, origin.slot,
                origin.ore - loot_ore, origin.crystal - loot_crystal, origin.deuterium - loot_deut
              )
              || case
                when (origin.ore - loot_ore) + (origin.crystal - loot_crystal) + (origin.deuterium - loot_deut)
                  < coalesce(f.cargo_ore, 0) + coalesce(f.cargo_crystal, 0) + coalesce(f.cargo_deuterium, 0)
                then format(
                  ' Storage was full, so %s of the cargo was lost.',
                  coalesce(f.cargo_ore, 0) + coalesce(f.cargo_crystal, 0) + coalesce(f.cargo_deuterium, 0)
                    - ((origin.ore - loot_ore) + (origin.crystal - loot_crystal) + (origin.deuterium - loot_deut))
                )
                else ''
              end
            else format('Docked at %s [%s:%s:%s] with empty holds.', origin.name, origin.galaxy, origin.system, origin.slot)
          end
        ),
        origin.ore - loot_ore,
        origin.crystal - loot_crystal
      );
    end if;
  end loop;

  for owned in
    select * from public.planets
    where owner_id = uid
    order by id
    for update
  loop
    owned := private.catch_up_planet(owned, at);
    hull := coalesce(nullif(owned.ship_building, ''), 'small_cargo');
    while owned.ships_queued > 0 and owned.ship_completes_at is not null and owned.ship_completes_at <= at loop
      e.ships := private.bump_ship(e.ships, hull, 1);
      if hull = 'small_cargo' then
        e.raiders := e.raiders + 1;
      end if;
      owned.ships_queued := owned.ships_queued - 1;
      if owned.ships_queued > 0 then
        owned.ship_completes_at := owned.ship_completes_at + make_interval(secs => private.unit_build_seconds(owned, hull));
      else
        owned.ship_completes_at := null;
        owned.ship_building := null;
      end if;
    end loop;
    perform private.persist_planet(owned);
    if owned.id = e.home_planet_id then
      home := owned;
    end if;
  end loop;

  if coalesce(e.pirate_raids_enabled, true) then
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
  else
    e.next_pirate_at := null;
  end if;

  perform private.persist_planet(home);

  update public.empires
  set
    propulsion_level = e.propulsion_level,
    energy_tech = e.energy_tech,
    laser_tech = e.laser_tech,
    ion_tech = e.ion_tech,
    hyperspace_tech = e.hyperspace_tech,
    plasma_tech = e.plasma_tech,
    impulse_drive = e.impulse_drive,
    hyperspace_drive = e.hyperspace_drive,
    espionage_tech = e.espionage_tech,
    computer_tech = e.computer_tech,
    astrophysics = e.astrophysics,
    intergalactic_research_network = e.intergalactic_research_network,
    graviton_tech = e.graviton_tech,
    weapons_tech = e.weapons_tech,
    shielding_tech = e.shielding_tech,
    armour_tech = e.armour_tech,
    raiders = e.raiders,
    raiders_queued = 0,
    raider_completes_at = null,
    ships = e.ships,
    ship_building = null,
    research_tech = e.research_tech,
    research_completes_at = e.research_completes_at,
    next_pirate_at = e.next_pirate_at
  where user_id = uid;
end;
$$;

notify pgrst, 'reload schema';

create or replace function private.resolve_harvest_arrival(uid uuid, e public.empires, f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  dest_g smallint;
  dest_s smallint;
  dest_sl smallint;
  recyclers integer;
  cap bigint;
  ore_take bigint := 0;
  crystal_take bigint := 0;
  flight integer;
  slowest integer;
begin
  select * into origin from public.planets where id = f.origin_planet_id;
  dest_g := coalesce(f.dest_galaxy, origin.galaxy);
  dest_s := coalesce(f.dest_system, origin.system);
  dest_sl := coalesce(f.dest_slot, origin.slot);
  recyclers := greatest(coalesce((f.composition->>'recycler')::integer, 0), 0);
  cap := recyclers::bigint * private.ship_cargo('recycler'::text);

  select c.take_ore, c.take_crystal
  into ore_take, crystal_take
  from private.collect_debris(dest_g, dest_s, dest_sl, cap) c;

  slowest := private.ship_speed('recycler'::text, e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
  flight := coalesce(
    nullif(f.flight_seconds, 0),
    private.wiki_travel_seconds(
      private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest_g, dest_s, dest_sl),
      slowest,
      100
    )
  );

  update public.fleets
  set
    mission = 'harvest_return',
    cargo_ore = ore_take,
    cargo_crystal = crystal_take,
    arrives_at = f.arrives_at + make_interval(secs => flight),
    report = case
      when ore_take + crystal_take > 0 then format('Recyclers harvested %s ore and %s crystal.', ore_take, crystal_take)
      else 'The debris field was empty.'
    end
  where id = f.id;
end;
$$;

revoke all on function private.resolve_harvest_arrival(uuid, public.empires, public.fleets) from public, anon, authenticated;

create or replace function private.resolve_espionage_arrival(
  uid uuid,
  attacker public.empires,
  f public.fleets
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  dest public.planets%rowtype;
  origin public.planets%rowtype;
  te public.empires%rowtype;
  yours integer;
  enemy integer;
  probes integer;
  sees_fleet boolean;
  sees_def boolean;
  sees_bld boolean;
  sees_res boolean;
  chance numeric;
  detected boolean;
  destroyed boolean;
  body text;
  fleet_lines text;
  def_lines text;
  bld_lines text;
  res_lines text;
  flight integer;
  guns integer;
  combat integer;
begin
  select * into dest from public.planets where id = f.dest_planet_id for update;
  if not found then
    update public.fleets set status = 'completed', report = 'No world at that coordinate.' where id = f.id;
    return;
  end if;
  dest := private.catch_up_planet(dest, f.arrives_at);
  perform private.persist_planet(dest);

  select * into origin from public.planets where id = f.origin_planet_id;
  yours := coalesce(attacker.espionage_tech, 0);
  enemy := 0;
  combat := 0;
  if dest.owner_id is not null then
    select * into te from public.empires where user_id = dest.owner_id;
    if found then
      enemy := coalesce(te.espionage_tech, 0);
      combat := private.docked_combat_ships(te.ships);
    end if;
  end if;
  probes := greatest(coalesce(f.raiders, 0), 0);
  sees_fleet := probes >= private.espionage_probes_needed(2, yours, enemy);
  sees_def := probes >= private.espionage_probes_needed(3, yours, enemy);
  sees_bld := probes >= private.espionage_probes_needed(5, yours, enemy);
  sees_res := probes >= private.espionage_probes_needed(7, yours, enemy);
  chance := private.counter_espionage_chance(yours, enemy, probes);
  detected := random() < chance;
  guns := private.defence_units(dest);
  destroyed := detected and (guns > 0 or combat > 0);

  body := format(
    E'Espionage report from %s [%s:%s:%s]\n\nResources\nOre: %s  Crystal: %s  Deuterium: %s',
    dest.name,
    dest.galaxy,
    dest.system,
    dest.slot,
    dest.ore,
    dest.crystal,
    dest.deuterium
  );

  if sees_fleet then
    select string_agg(format('%s: %s', key, value), E'\n' order by key)
      into fleet_lines
    from jsonb_each_text(coalesce(te.ships, '{}'::jsonb))
    where (value)::integer > 0;
    body := body || E'\n\nFleets\n' || coalesce(nullif(fleet_lines, ''), 'None');
  end if;

  if sees_def then
    def_lines := concat_ws(
      E'\n',
      case when dest.rocket_launcher > 0 then format('Rocket launcher: %s', dest.rocket_launcher) end,
      case when dest.light_laser > 0 then format('Light laser: %s', dest.light_laser) end,
      case when dest.heavy_laser > 0 then format('Heavy laser: %s', dest.heavy_laser) end,
      case when dest.ion_cannon > 0 then format('Ion cannon: %s', dest.ion_cannon) end,
      case when dest.gauss_cannon > 0 then format('Gauss cannon: %s', dest.gauss_cannon) end,
      case when dest.plasma_turret > 0 then format('Plasma turret: %s', dest.plasma_turret) end,
      case when dest.small_shield_dome > 0 then format('Small shield dome: %s', dest.small_shield_dome) end,
      case when dest.large_shield_dome > 0 then format('Large shield dome: %s', dest.large_shield_dome) end
    );
    body := body || E'\n\nDefense\n' || coalesce(nullif(def_lines, ''), 'None');
  end if;

  if sees_bld then
    bld_lines := concat_ws(
      E'\n',
      format('Ore mine: %s', dest.ore_mine),
      format('Crystal mine: %s', dest.crystal_mine),
      format('Deuterium extractor: %s', dest.deuterium_extractor),
      format('Power plant: %s', dest.power_plant),
      format('Fusion reactor: %s', dest.fusion_reactor),
      format('Ore storage: %s', dest.ore_storage),
      format('Crystal storage: %s', dest.crystal_storage),
      format('Deuterium storage: %s', dest.deuterium_storage),
      format('Robotics factory: %s', dest.robotics_factory),
      format('Shipyard: %s', dest.shipyard),
      format('Research lab: %s', dest.research_lab)
    );
    body := body || E'\n\nBuildings\n' || bld_lines;
  end if;

  if sees_res and dest.owner_id is not null and te.user_id is not null then
    res_lines := concat_ws(
      E'\n',
      format('Energy technology: %s', te.energy_tech),
      format('Laser technology: %s', te.laser_tech),
      format('Espionage technology: %s', te.espionage_tech),
      format('Combustion drive: %s', te.propulsion_level),
      format('Impulse drive: %s', te.impulse_drive),
      format('Weapons technology: %s', te.weapons_tech),
      format('Shielding technology: %s', te.shielding_tech),
      format('Armour technology: %s', te.armour_tech)
    );
    body := body || E'\n\nResearch\n' || res_lines;
  elsif sees_res then
    body := body || E'\n\nResearch\nNone';
  end if;

  if destroyed then
    body := body || E'\n\nCounter-espionage destroyed the probes. The report still arrived.';
  elsif detected then
    body := body || E'\n\nThe target noticed the probes. They returned.';
  end if;

  if detected and dest.owner_id is not null and dest.owner_id is distinct from uid then
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (
      dest.owner_id,
      'Counter-espionage',
      format(
        'A foreign fleet from [%s:%s:%s] was detected. %s espionage probe%s %s.',
        origin.galaxy,
        origin.system,
        origin.slot,
        probes,
        case when probes = 1 then '' else 's' end,
        case when destroyed then 'were destroyed' else 'slipped away' end
      ),
      0,
      0
    );
  end if;

  insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
  values (uid, 'Espionage report', body, 0, 0);

  flight := coalesce(
    nullif(f.flight_seconds, 0),
    private.wiki_travel_seconds(
      private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot),
      private.ship_speed('espionage_probe', attacker.impulse_drive, attacker.hyperspace_drive, attacker.propulsion_level),
      100
    )
  );

  if destroyed then
    update public.fleets
    set
      status = 'completed',
      raiders = 0,
      report = body
    where id = f.id;
  else
    update public.fleets
    set
      mission = 'espionage_return',
      created_at = f.arrives_at,
      arrives_at = f.arrives_at + make_interval(secs => flight),
      report = body
    where id = f.id;
  end if;
end;
$$;

revoke all on function private.resolve_espionage_arrival(uuid, public.empires, public.fleets) from public, anon, authenticated;

