-- Asteroid belts: sparse pre-seed, mining barges sit on site and share a pool.

alter table public.fleets drop constraint if exists fleets_mission_check;
alter table public.fleets
  add constraint fleets_mission_check
  check (mission in (
    'attack',
    'return',
    'espionage',
    'espionage_return',
    'harvest',
    'harvest_return',
    'colonize',
    'colonize_return',
    'expedition',
    'expedition_hold',
    'expedition_return',
    'transport',
    'transport_return',
    'deploy',
    'mine',
    'mine_hold',
    'mine_return'
  ));

create table if not exists public.asteroid_belts (
  galaxy smallint not null check (galaxy between 1 and 9),
  system smallint not null check (system between 1 and 499),
  belt_slot smallint not null check (belt_slot in (17, 18)),
  after_slot smallint not null check (after_slot between 1 and 14),
  ore bigint not null default 0 check (ore >= 0),
  crystal bigint not null default 0 check (crystal >= 0),
  cap_ore bigint not null check (cap_ore >= 0),
  cap_crystal bigint not null check (cap_crystal >= 0),
  emptied_at timestamptz,
  last_mined_at timestamptz not null default timezone('utc', now()),
  primary key (galaxy, system, belt_slot)
);

alter table public.asteroid_belts enable row level security;
revoke all on table public.asteroid_belts from public, anon, authenticated;

do $$
declare
  g integer;
  s integer;
  n integer;
  i integer;
  skip integer;
  after_a integer;
  after_b integer;
  total integer;
  heavy integer;
  ore_amt bigint;
  cry_amt bigint;
  h bigint;
begin
  if exists (select 1 from public.asteroid_belts limit 1) then
    return;
  end if;
  for g in 1..9 loop
    s := 1;
    while s <= 499 loop
      h := ('x' || substr(md5(g::text || ':' || s::text || ':n'), 1, 8))::bit(32)::bigint;
      n := 1 + (h % 2)::int;
      after_a := 1 + (('x' || substr(md5(g::text || ':' || s::text || ':a'), 1, 8))::bit(32)::bigint % 14)::int;
      after_b := 1 + (('x' || substr(md5(g::text || ':' || s::text || ':b'), 1, 8))::bit(32)::bigint % 14)::int;
      if after_b = after_a then
        after_b := 1 + (after_a % 14);
      end if;
      for i in 1..n loop
        total := 80000 + (('x' || substr(md5(g::text || ':' || s::text || ':t' || i::text), 1, 8))::bit(32)::bigint % 140001)::int;
        heavy := (('x' || substr(md5(g::text || ':' || s::text || ':h' || i::text), 1, 8))::bit(32)::bigint % 2)::int;
        if heavy = 0 then
          ore_amt := floor(total * (0.75 + ((case when i = 1 then after_a else after_b end) % 16) / 100.0));
        else
          ore_amt := floor(total * (0.10 + ((case when i = 1 then after_a else after_b end) % 16) / 100.0));
        end if;
        cry_amt := total - ore_amt;
        insert into public.asteroid_belts (
          galaxy, system, belt_slot, after_slot, ore, crystal, cap_ore, cap_crystal, last_mined_at
        ) values (
          g, s, (16 + i)::smallint, (case when i = 1 then after_a else after_b end)::smallint,
          ore_amt, cry_amt, ore_amt, cry_amt, timezone('utc', now())
        );
      end loop;
      skip := 1 + (('x' || substr(md5(g::text || ':' || s::text || ':skip'), 1, 8))::bit(32)::bigint % 2)::int;
      s := s + skip;
    end loop;
  end loop;
end;
$$;

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
    when 'mining_barge' then 3
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
  elsif id = 'mining_barge' and private.research_level(e, 'combustion_drive') < 3 then
    return 'Needs Combustion drive 3.';
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

create or replace function private.ship_cost_ore(id text)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'light_fighter' then 3000
    when 'heavy_fighter' then 6000
    when 'cruiser' then 20000
    when 'battleship' then 45000
    when 'battlecruiser' then 30000
    when 'bomber' then 50000
    when 'destroyer' then 60000
    when 'deathstar' then 5000000
    when 'small_cargo' then 2000
    when 'large_cargo' then 6000
    when 'colony_ship' then 10000
    when 'recycler' then 10000
    when 'mining_barge' then 5000
    when 'espionage_probe' then 0
    when 'reaper' then 85000
    when 'pathfinder' then 8000
    when 'crawler' then 2000
    when 'solar_satellite' then 0
    else null
  end;
$$;

create or replace function private.ship_cost_crystal(id text)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'light_fighter' then 1000
    when 'heavy_fighter' then 4000
    when 'cruiser' then 7000
    when 'battleship' then 15000
    when 'battlecruiser' then 40000
    when 'bomber' then 25000
    when 'destroyer' then 50000
    when 'deathstar' then 4000000
    when 'small_cargo' then 2000
    when 'large_cargo' then 6000
    when 'colony_ship' then 20000
    when 'recycler' then 6000
    when 'mining_barge' then 3000
    when 'espionage_probe' then 1000
    when 'reaper' then 55000
    when 'pathfinder' then 15000
    when 'crawler' then 2000
    when 'solar_satellite' then 2000
    else null
  end;
$$;

revoke all on function private.ship_cost_ore(text) from public, anon, authenticated;
revoke all on function private.ship_cost_crystal(text) from public, anon, authenticated;

create or replace function private.unit_cargo(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'light_fighter' then 50
    when 'heavy_fighter' then 100
    when 'cruiser' then 800
    when 'battleship' then 1500
    when 'battlecruiser' then 750
    when 'bomber' then 500
    when 'destroyer' then 2000
    when 'deathstar' then 1000000
    when 'small_cargo' then 5000
    when 'large_cargo' then 25000
    when 'colony_ship' then 7500
    when 'recycler' then 20000
    when 'mining_barge' then 12000
    when 'espionage_probe' then 0
    when 'reaper' then 10000
    when 'pathfinder' then 10000
    else 0
  end;
$$;

revoke all on function private.unit_cargo(text) from public, anon, authenticated;

create or replace function private.ship_fuel(id text, impulse integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'light_fighter' then 20
    when 'heavy_fighter' then 75
    when 'cruiser' then 300
    when 'battleship' then 500
    when 'battlecruiser' then 250
    when 'bomber' then 700
    when 'destroyer' then 1000
    when 'deathstar' then 1
    when 'small_cargo' then case when coalesce(impulse, 0) >= 5 then 20 else 10 end
    when 'large_cargo' then 50
    when 'colony_ship' then 1000
    when 'recycler' then 300
    when 'mining_barge' then 40
    when 'espionage_probe' then 1
    when 'reaper' then 1100
    when 'pathfinder' then 300
    else 0
  end;
$$;

revoke all on function private.ship_fuel(text, integer) from public, anon, authenticated;

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
        when 'mining_barge' then 4000
        when 'espionage_probe' then 100000000
        when 'reaper' then 7000
        when 'pathfinder' then 12000
        else 0
      end as speed,
      case
        when id = 'small_cargo' and coalesce(impulse, 0) >= 5 then 'impulse'
        when id = 'bomber' and coalesce(hyperspace, 0) >= 8 then 'hyperspace'
        when id in ('light_fighter', 'large_cargo', 'recycler', 'mining_barge', 'espionage_probe', 'small_cargo') then 'combustion'
        when id in ('heavy_fighter', 'cruiser', 'colony_ship', 'bomber') then 'impulse'
        when id in ('battleship', 'battlecruiser', 'destroyer', 'deathstar', 'reaper', 'pathfinder') then 'hyperspace'
        else 'combustion'
      end as drive
  ) base;
$$;

revoke all on function private.ship_speed(text, integer, integer, integer) from public, anon, authenticated;

create or replace function private.belt_flight_slot(p_galaxy smallint, p_system smallint, p_belt_slot smallint)
returns smallint
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select b.after_slot from public.asteroid_belts b
     where b.galaxy = p_galaxy and b.system = p_system and b.belt_slot = p_belt_slot),
    p_belt_slot
  );
$$;

create or replace function private.send_miner_home(f public.fleets, at timestamptz, reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  e public.empires%rowtype;
  flight integer;
  dest_slot smallint;
begin
  if f.mission <> 'mine_hold' and f.mission <> 'mine' then
    return;
  end if;
  select * into origin from public.planets where id = f.origin_planet_id;
  select * into e from public.empires where user_id = f.owner_id;
  dest_slot := private.belt_flight_slot(coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), coalesce(f.dest_slot, 17));
  flight := private.wiki_travel_seconds(
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), dest_slot),
    private.ship_speed('mining_barge', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
    100
  );
  update public.fleets
  set
    mission = 'mine_return',
    dest_planet_id = origin.id,
    dest_galaxy = origin.galaxy,
    dest_system = origin.system,
    dest_slot = origin.slot,
    arrives_at = at + make_interval(secs => flight),
    flight_seconds = flight,
    report = reason
  where id = f.id;
end;
$$;

create or replace function private.resolve_mine_arrival(f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.asteroid_belts b
  set last_mined_at = greatest(b.last_mined_at, f.arrives_at)
  where b.galaxy = coalesce(f.dest_galaxy, 1)
    and b.system = coalesce(f.dest_system, 0)
    and b.belt_slot = coalesce(f.dest_slot, 17);

  update public.fleets
  set
    mission = 'mine_hold',
    arrives_at = f.arrives_at + interval '48 hours'
  where id = f.id;

  perform private.tick_asteroid_mining(f.arrives_at);
end;
$$;

create or replace function private.tick_asteroid_mining(until timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  belt public.asteroid_belts%rowtype;
  miner public.fleets%rowtype;
  last_at timestamptz;
  remaining numeric;
  total_rate numeric;
  time_to_full numeric;
  time_to_empty numeric;
  step numeric;
  extracted numeric;
  take_ore bigint;
  take_crystal bigint;
  given_ore bigint;
  given_crystal bigint;
  barges integer;
  cap bigint;
  left_hold numeric;
  rate numeric;
  speed integer;
  guard integer;
begin
  update public.asteroid_belts
  set
    ore = cap_ore,
    crystal = cap_crystal,
    emptied_at = null,
    last_mined_at = greatest(last_mined_at, emptied_at + interval '24 hours')
  where emptied_at is not null
    and emptied_at + interval '24 hours' <= until;

  for belt in
    select b.*
    from public.asteroid_belts b
    where exists (
      select 1 from public.fleets f
      where f.status = 'en_route'
        and f.mission = 'mine_hold'
        and coalesce(f.dest_galaxy, 1) = b.galaxy
        and coalesce(f.dest_system, 0) = b.system
        and f.dest_slot = b.belt_slot
    )
    for update
  loop
    last_at := belt.last_mined_at;
    guard := 0;
    while last_at < until and guard < 40 loop
      guard := guard + 1;
      remaining := belt.ore + belt.crystal;
      if remaining <= 0 then
        belt.emptied_at := coalesce(belt.emptied_at, last_at);
        for miner in
          select * from public.fleets
          where status = 'en_route' and mission = 'mine_hold'
            and coalesce(dest_galaxy, 1) = belt.galaxy
            and coalesce(dest_system, 0) = belt.system
            and dest_slot = belt.belt_slot
        loop
          perform private.send_miner_home(miner, last_at, 'The asteroid belt was exhausted.');
        end loop;
        exit;
      end if;

      select coalesce(sum(
        greatest(coalesce((f.composition->>'mining_barge')::integer, 0), 0)
        * 300.0
        * greatest(coalesce(em.economy_speed, 1), 1)
        / 3600.0
      ), 0)
      into total_rate
      from public.fleets f
      left join public.empires em on em.user_id = f.owner_id
      where f.status = 'en_route' and f.mission = 'mine_hold'
        and coalesce(f.dest_galaxy, 1) = belt.galaxy
        and coalesce(f.dest_system, 0) = belt.system
        and f.dest_slot = belt.belt_slot;

      if total_rate <= 0 then
        last_at := until;
        exit;
      end if;

      time_to_full := null;
      for miner in
        select * from public.fleets
        where status = 'en_route' and mission = 'mine_hold'
          and coalesce(dest_galaxy, 1) = belt.galaxy
          and coalesce(dest_system, 0) = belt.system
          and dest_slot = belt.belt_slot
      loop
        barges := greatest(coalesce((miner.composition->>'mining_barge')::integer, 0), 0);
        select greatest(coalesce(em.economy_speed, 1), 1) into speed
        from public.empires em where em.user_id = miner.owner_id;
        speed := coalesce(speed, 1);
        rate := barges * 300.0 * speed / 3600.0;
        cap := barges::bigint * private.unit_cargo('mining_barge');
        left_hold := greatest(0, cap - miner.cargo_ore - miner.cargo_crystal);
        if rate > 0 then
          if time_to_full is null or left_hold / rate < time_to_full then
            time_to_full := left_hold / rate;
          end if;
        end if;
      end loop;

      time_to_empty := remaining / total_rate;
      step := extract(epoch from (until - last_at));
      if time_to_empty < step then step := time_to_empty; end if;
      if time_to_full is not null and time_to_full < step then step := time_to_full; end if;
      if step <= 0 then
        exit;
      end if;

      extracted := step * total_rate;
      take_ore := least(belt.ore, floor(extracted * belt.ore / remaining))::bigint;
      take_crystal := least(belt.crystal, floor(extracted - take_ore))::bigint;
      given_ore := 0;
      given_crystal := 0;

      for miner in
        select * from public.fleets
        where status = 'en_route' and mission = 'mine_hold'
          and coalesce(dest_galaxy, 1) = belt.galaxy
          and coalesce(dest_system, 0) = belt.system
          and dest_slot = belt.belt_slot
      loop
        barges := greatest(coalesce((miner.composition->>'mining_barge')::integer, 0), 0);
        select greatest(coalesce(em.economy_speed, 1), 1) into speed
        from public.empires em where em.user_id = miner.owner_id;
        speed := coalesce(speed, 1);
        rate := barges * 300.0 * speed / 3600.0;
        update public.fleets
        set
          cargo_ore = cargo_ore + floor(take_ore * rate / total_rate)::bigint,
          cargo_crystal = cargo_crystal + floor(take_crystal * rate / total_rate)::bigint
        where id = miner.id
        returning cargo_ore, cargo_crystal into miner.cargo_ore, miner.cargo_crystal;
        given_ore := given_ore + floor(take_ore * rate / total_rate)::bigint;
        given_crystal := given_crystal + floor(take_crystal * rate / total_rate)::bigint;
      end loop;

      belt.ore := belt.ore - given_ore;
      belt.crystal := belt.crystal - given_crystal;
      last_at := last_at + make_interval(secs => step);
      belt.last_mined_at := last_at;

      for miner in
        select * from public.fleets
        where status = 'en_route' and mission = 'mine_hold'
          and coalesce(dest_galaxy, 1) = belt.galaxy
          and coalesce(dest_system, 0) = belt.system
          and dest_slot = belt.belt_slot
      loop
        barges := greatest(coalesce((miner.composition->>'mining_barge')::integer, 0), 0);
        cap := barges::bigint * private.unit_cargo('mining_barge');
        if miner.cargo_ore + miner.cargo_crystal >= cap then
          perform private.send_miner_home(miner, last_at, 'The mining barges filled their holds.');
        end if;
      end loop;

      if belt.ore + belt.crystal <= 0 then
        belt.ore := 0;
        belt.crystal := 0;
        belt.emptied_at := last_at;
        for miner in
          select * from public.fleets
          where status = 'en_route' and mission = 'mine_hold'
            and coalesce(dest_galaxy, 1) = belt.galaxy
            and coalesce(dest_system, 0) = belt.system
            and dest_slot = belt.belt_slot
        loop
          perform private.send_miner_home(miner, last_at, 'The asteroid belt was exhausted.');
        end loop;
        exit;
      end if;
    end loop;

    belt.last_mined_at := last_at;
    update public.asteroid_belts
    set ore = belt.ore, crystal = belt.crystal, emptied_at = belt.emptied_at, last_mined_at = belt.last_mined_at
    where galaxy = belt.galaxy and system = belt.system and belt_slot = belt.belt_slot;
  end loop;
end;
$$;

create or replace function private.resolve_belt_espionage(uid uuid, attacker public.empires, f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  belt public.asteroid_belts%rowtype;
  body text;
  miner_lines text;
  flight integer;
  dest_slot smallint;
begin
  perform private.tick_asteroid_mining(f.arrives_at);
  select * into origin from public.planets where id = f.origin_planet_id;
  select * into belt
  from public.asteroid_belts
  where galaxy = coalesce(f.dest_galaxy, origin.galaxy)
    and system = coalesce(f.dest_system, origin.system)
    and belt_slot = coalesce(f.dest_slot, 17);

  select string_agg(
    format(
      '%s: %s barge%s (%s%% full)',
      coalesce(pf.display_name, f2.owner_id::text),
      greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0),
      case when greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) = 1 then '' else 's' end,
      case
        when greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) * private.unit_cargo('mining_barge') <= 0 then 0
        else round(
          100.0 * (f2.cargo_ore + f2.cargo_crystal)
          / (greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) * private.unit_cargo('mining_barge'))
        )
      end
    ),
    E'\n'
  )
  into miner_lines
  from public.fleets f2
  left join public.profiles pf on pf.user_id = f2.owner_id
  where f2.status = 'en_route'
    and f2.mission = 'mine_hold'
    and coalesce(f2.dest_galaxy, 1) = coalesce(f.dest_galaxy, origin.galaxy)
    and coalesce(f2.dest_system, 0) = coalesce(f.dest_system, origin.system)
    and f2.dest_slot = f.dest_slot;

  body := concat_ws(
    E'\n',
    format('Espionage report from asteroid belt [%s:%s:%s]', coalesce(f.dest_galaxy, 1), coalesce(f.dest_system, 0), coalesce(f.dest_slot, 17)),
    '',
    format('Ore: %s  Crystal: %s', coalesce(belt.ore, 0), coalesce(belt.crystal, 0)),
    '',
    'Miners',
    coalesce(nullif(miner_lines, ''), 'None')
  );

  dest_slot := coalesce(belt.after_slot, origin.slot);
  flight := private.wiki_travel_seconds(
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), dest_slot),
    private.ship_speed('espionage_probe', attacker.impulse_drive, attacker.hyperspace_drive, attacker.propulsion_level),
    100
  );

  insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
  values (uid, 'Espionage report', body, 0, 0);

  update public.fleets
  set
    mission = 'espionage_return',
    dest_planet_id = origin.id,
    arrives_at = f.arrives_at + make_interval(secs => flight),
    report = body
  where id = f.id;
end;
$$;

create or replace function public.send_mine(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_barges integer
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
  belt public.asteroid_belts%rowtype;
  at timestamptz := timezone('utc', now());
  have integer;
  distance integer;
  fuel bigint := 0;
  slowest integer;
  flight integer;
  dest_slot smallint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_barges is null or p_barges < 1 then
    raise exception 'Send at least one mining barge.';
  end if;
  if p_slot not in (17, 18) then
    raise exception 'No asteroid belt at that coordinate.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  select * into belt
  from public.asteroid_belts
  where galaxy = p_galaxy and system = p_system and belt_slot = p_slot
  for update;
  if not found then
    raise exception 'No asteroid belt at that coordinate.';
  end if;

  have := coalesce((e.ships->>'mining_barge')::integer, 0);
  if have < p_barges then
    raise exception 'Not enough mining barges.';
  end if;

  dest_slot := belt.after_slot;
  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, dest_slot);
  fuel := private.fleet_fuel_round_trip(p_barges, private.ship_fuel('mining_barge', e.impulse_drive), distance);
  if fuel > 0 then
    fuel := greatest(1, fuel);
  end if;
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  slowest := private.ship_speed('mining_barge', e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
  flight := private.wiki_travel_seconds(distance, slowest, 100);

  update public.planets set deuterium = origin.deuterium - fuel where id = origin.id;
  update public.empires set ships = private.bump_ship(e.ships, 'mining_barge', -p_barges) where user_id = uid;

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
    p_barges,
    'mine',
    at + make_interval(secs => flight),
    jsonb_build_object('mining_barge', p_barges),
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.send_mine(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_mine(smallint, smallint, smallint, integer) to authenticated;

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
  belt public.asteroid_belts%rowtype;
  at timestamptz := timezone('utc', now());
  docked integer;
  flight integer;
  fuel bigint;
  distance integer;
  dest_slot smallint;
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

  if p_slot in (17, 18) then
    select * into belt
    from public.asteroid_belts
    where galaxy = p_galaxy and system = p_system and belt_slot = p_slot;
    if not found then
      raise exception 'No asteroid belt at that coordinate.';
    end if;
    dest_slot := belt.after_slot;
    distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, dest_slot);
    flight := private.wiki_travel_seconds(
      distance,
      private.ship_speed('espionage_probe', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
      100
    );
    fuel := private.fleet_fuel_round_trip(p_probes, 1, distance);
    if origin.deuterium < fuel then
      raise exception 'Not enough resources.';
    end if;
    update public.planets set deuterium = origin.deuterium - fuel where id = origin.id;
    update public.empires set ships = private.bump_ship(e.ships, 'espionage_probe', -p_probes) where user_id = uid;
    insert into public.fleets (
      owner_id, origin_planet_id, dest_planet_id,
      dest_galaxy, dest_system, dest_slot,
      raiders, mission, arrives_at, composition, flight_seconds
    )
    values (
      uid, origin.id, null,
      p_galaxy, p_system, p_slot,
      p_probes, 'espionage', at + make_interval(secs => flight),
      jsonb_build_object('espionage_probe', p_probes),
      flight
    );
    return private.empire_state_json(uid, timezone('utc', now()));
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

revoke all on function public.send_spy(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_spy(smallint, smallint, smallint, integer) to authenticated;

create or replace function public.recall_fleet(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  f public.fleets%rowtype;
  origin public.planets%rowtype;
  e public.empires%rowtype;
  flown double precision;
  dest_slot smallint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into f from public.fleets where id = p_id for update;
  if not found or f.owner_id is distinct from uid or f.status <> 'en_route' then
    raise exception 'Fleet not found.';
  end if;
  if f.mission not in ('attack', 'expedition', 'espionage', 'harvest', 'colonize', 'deploy', 'mine', 'mine_hold') then
    raise exception 'That fleet cannot be recalled.';
  end if;
  if f.mission <> 'mine_hold' and f.arrives_at <= at then
    raise exception 'The fleet already reached its target.';
  end if;

  select * into origin from public.planets where id = f.origin_planet_id;
  select * into e from public.empires where user_id = uid;
  if f.mission = 'mine_hold' then
    dest_slot := private.belt_flight_slot(coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), coalesce(f.dest_slot, 17));
    flown := private.wiki_travel_seconds(
      private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), dest_slot),
      private.ship_speed('mining_barge', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
      100
    );
  else
    flown := greatest(extract(epoch from (at - f.created_at)), 1);
  end if;

  update public.fleets
  set
    mission = case
      when f.mission = 'expedition' then 'expedition_return'
      when f.mission = 'espionage' then 'espionage_return'
      when f.mission = 'harvest' then 'harvest_return'
      when f.mission = 'colonize' then 'colonize_return'
      when f.mission = 'deploy' then 'return'
      when f.mission in ('mine', 'mine_hold') then 'mine_return'
      else 'return'
    end,
    dest_planet_id = f.origin_planet_id,
    dest_galaxy = origin.galaxy,
    dest_system = origin.system,
    dest_slot = origin.slot,
    created_at = at,
    arrives_at = at + make_interval(secs => flown),
    report = case when f.mission = 'mine_hold' then 'Mining barge recalled with loaded cargo.' else 'Fleet recalled.' end
  where id = f.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.recall_fleet(bigint) from public, anon;
grant execute on function public.recall_fleet(bigint) to authenticated;

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

  delete from public.debris_fields d
  where d.galaxy = p_galaxy and d.system = p_system
    and d.fresh_at <= timezone('utc', now()) - interval '4 hours';

  perform private.tick_asteroid_mining(timezone('utc', now()));

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p_galaxy and s.system = p_system;

  select jsonb_build_object(
    'galaxy', p_galaxy,
    'system', p_system,
    'star_type', coalesce(star, 'medium'),
    'multiplier', private.star_multiplier(coalesce(star, 'medium')),
    'slots', (
      select coalesce(jsonb_agg(row.obj order by row.sort_key), '[]'::jsonb)
      from (
        select
          sl.slot::numeric as sort_key,
          jsonb_build_object(
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
            'owner_id', pl.owner_id,
            'owner_name', pf.display_name,
            'debris_ore', floor(coalesce(df.ore, 0) * private.debris_factor(df.fresh_at, timezone('utc', now())))::bigint,
            'debris_crystal', floor(coalesce(df.crystal, 0) * private.debris_factor(df.fresh_at, timezone('utc', now())))::bigint,
            'debris_decays_at', df.fresh_at + interval '2 hours',
            'debris_gone_at', df.fresh_at + interval '4 hours'
          ) as obj
        from generate_series(1, 16) as sl(slot)
        left join public.planets pl
          on pl.galaxy = p_galaxy
          and pl.system = p_system
          and pl.slot = sl.slot
          and sl.slot <= 15
        left join public.profiles pf on pf.user_id = pl.owner_id
        left join public.debris_fields df
          on df.galaxy = p_galaxy
          and df.system = p_system
          and df.slot = sl.slot
        union all
        select
          b.after_slot + 0.5 as sort_key,
          jsonb_build_object(
            'slot', b.belt_slot,
            'kind', 'belt',
            'planet_id', null,
            'name', 'Asteroid belt',
            'owner_id', null,
            'owner_name', null,
            'belt_ore', b.ore,
            'belt_crystal', b.crystal,
            'belt_after_slot', b.after_slot
          ) as obj
        from public.asteroid_belts b
        where b.galaxy = p_galaxy and b.system = p_system
      ) row
    )
  )
  into result;

  return result;
end;
$$;

revoke all on function public.get_solar_system(smallint, smallint) from public, anon;
grant execute on function public.get_solar_system(smallint, smallint) to authenticated;

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
  if coalesce(f.dest_slot, 0) in (17, 18) and f.dest_planet_id is null then
    perform private.resolve_belt_espionage(uid, attacker, f);
    return;
  end if;
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
      combat := private.docked_combat_ships(coalesce(dest.ships, te.ships));
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
    perform private.tick_asteroid_mining((
      select coalesce(min(arrives_at), at)
      from public.fleets
      where status = 'en_route'
        and arrives_at <= at
        and mission <> 'mine_hold'
        and (
          owner_id = uid
          or (owner_id is null and dest_planet_id in (select id from public.planets where owner_id = uid))
          or (mission = 'attack' and dest_planet_id in (select id from public.planets where owner_id = uid))
        )
    ));

    select * into f
    from public.fleets
    where status = 'en_route'
      and arrives_at <= at
      and mission <> 'mine_hold'
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
    elsif f.mission = 'deploy' then
      perform private.resolve_deploy_arrival(f);
      if f.dest_planet_id = home.id then
        select * into home from public.planets where id = home.id for update;
        select * into e from public.empires where user_id = uid for update;
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
      origin.ships := private.bump_ship(origin.ships, 'espionage_probe', f.raiders);
      if origin.id = home.id then
        e.ships := origin.ships;
        e.raiders := coalesce((origin.ships->>'small_cargo')::integer, 0);
        home := origin;
      end if;
      perform private.persist_planet(origin);
      update public.fleets set status = 'completed' where id = f.id;
    elsif f.mission = 'harvest' then
      perform private.resolve_harvest_arrival(uid, e, f);
    elsif f.mission = 'mine' then
      perform private.resolve_mine_arrival(f);
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
            origin.ships := private.bump_ship(origin.ships, kv.key, kv.n);
          end if;
        end loop;
      else
        origin.ships := private.bump_ship(origin.ships, 'small_cargo', f.raiders);
      end if;
      if origin.id = home.id then
        e.ships := origin.ships;
        e.raiders := coalesce((origin.ships->>'small_cargo')::integer, 0);
        home := origin;
      end if;
      perform private.persist_planet(origin);

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
          when 'mine_return' then 'Mining barge returned'
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

  perform private.tick_asteroid_mining(at);

  for owned in
    select * from public.planets
    where owner_id = uid
    order by id
    for update
  loop
    owned := private.catch_up_planet(owned, at);
    hull := coalesce(nullif(owned.ship_building, ''), 'small_cargo');
    while owned.ships_queued > 0 and owned.ship_completes_at is not null and owned.ship_completes_at <= at loop
      owned.ships := private.bump_ship(owned.ships, hull, 1);
      if owned.id = home.id then
        e.ships := owned.ships;
        e.raiders := coalesce((owned.ships->>'small_cargo')::integer, 0);
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

create or replace function public.debug_grant_fleet()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home public.planets%rowtype;
  fleet jsonb := '{
    "light_fighter": 20,
    "heavy_fighter": 20,
    "cruiser": 10,
    "battleship": 10,
    "battlecruiser": 5,
    "bomber": 5,
    "destroyer": 5,
    "deathstar": 1,
    "small_cargo": 20,
    "large_cargo": 20,
    "colony_ship": 10,
    "recycler": 20,
    "mining_barge": 20,
    "espionage_probe": 50,
    "reaper": 5,
    "pathfinder": 5,
    "crawler": 10,
    "solar_satellite": 10
  }'::jsonb;
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
  set deuterium = greatest(deuterium, least(private.storage_cap(deuterium_storage), 50000))
  where id = home.id;

  update public.empires
  set
    ships = fleet,
    raiders = 20,
    propulsion_level = greatest(propulsion_level, 6),
    energy_tech = greatest(energy_tech, 1),
    impulse_drive = greatest(impulse_drive, 5),
    espionage_tech = greatest(espionage_tech, 2),
    astrophysics = greatest(astrophysics, 1),
    shielding_tech = greatest(shielding_tech, 2)
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.debug_grant_fleet() from public, anon;
grant execute on function public.debug_grant_fleet() to authenticated;

notify pgrst, 'reload schema';
