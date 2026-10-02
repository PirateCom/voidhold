-- Transport missions (deliver ore, crystal, deuterium to a planet, then fly home)
-- and expeditions to any empty slot or position 16.

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
    'transport_return'
  ));

create or replace function private.resolve_transport_arrival(f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  dest public.planets%rowtype;
  sender text;
  flight integer;
  delivered boolean := false;
begin
  select * into dest from public.planets where id = f.dest_planet_id for update;
  if found and dest.owner_id is not null then
    dest := private.catch_up_planet(dest, f.arrives_at);
    dest.ore := dest.ore + coalesce(f.cargo_ore, 0);
    dest.crystal := dest.crystal + coalesce(f.cargo_crystal, 0);
    dest.deuterium := dest.deuterium + coalesce(f.cargo_deuterium, 0);
    perform private.persist_planet(dest);
    delivered := true;

    select coalesce(pr.display_name, 'A commander') into sender
    from public.profiles pr
    where pr.user_id = f.owner_id;

    if dest.owner_id is distinct from f.owner_id then
      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        dest.owner_id,
        'Transport received',
        format(
          '%s delivered %s ore, %s crystal, and %s deuterium to %s.',
          coalesce(sender, 'A commander'),
          coalesce(f.cargo_ore, 0),
          coalesce(f.cargo_crystal, 0),
          coalesce(f.cargo_deuterium, 0),
          dest.name
        ),
        coalesce(f.cargo_ore, 0),
        coalesce(f.cargo_crystal, 0)
      );
    end if;
  end if;

  flight := greatest(15, coalesce(f.flight_seconds, extract(epoch from (f.arrives_at - f.created_at))::integer));
  update public.fleets
  set
    mission = 'transport_return',
    cargo_ore = case when delivered then 0 else f.cargo_ore end,
    cargo_crystal = case when delivered then 0 else f.cargo_crystal end,
    cargo_deuterium = case when delivered then 0 else f.cargo_deuterium end,
    arrives_at = f.arrives_at + make_interval(secs => flight),
    report = case
      when delivered then format(
        'Delivered %s ore, %s crystal, and %s deuterium to %s.',
        coalesce(f.cargo_ore, 0),
        coalesce(f.cargo_crystal, 0),
        coalesce(f.cargo_deuterium, 0),
        dest.name
      )
      else 'The destination was gone. The cargo came back.'
    end
  where id = f.id;
end;
$$;

revoke all on function private.resolve_transport_arrival(public.fleets) from public, anon, authenticated;

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
  base_flight integer;
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
    spd := private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive);
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

  base_flight := private.flight_seconds(
    origin.system, origin.slot, dest.system, dest.slot, e.propulsion_level, origin.galaxy, dest.galaxy
  );
  flight := greatest(15, floor(base_flight * (5000.0 / greatest(slowest, 1)) * (100.0 / p_speed))::integer);

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

revoke all on function public.send_transport(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) from public, anon;
grant execute on function public.send_transport(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) to authenticated;

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

  flight := least(30, private.flight_seconds(
    origin.system, origin.slot, p_system, p_slot, e.propulsion_level, origin.galaxy, p_galaxy
  ));
  fuel := private.fleet_fuel_round_trip(
    ships,
    private.small_cargo_fuel(e.impulse_drive),
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, p_slot)
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
    raiders, mission, arrives_at, composition
  )
  values (
    uid, origin.id, null, p_galaxy, p_system, p_slot,
    ships, 'expedition', at + make_interval(secs => flight), jsonb_build_object('small_cargo', ships)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

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
      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        uid,
        'Espionage report',
        coalesce(f.report, 'The probes returned.'),
        0,
        0
      );
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
      flight := least(30, private.flight_seconds(
        origin.system,
        origin.slot,
        coalesce(f.dest_system, origin.system),
        coalesce(f.dest_slot, 16),
        e.propulsion_level,
        origin.galaxy,
        coalesce(f.dest_galaxy, origin.galaxy)
      ));
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
        case when f.mission = 'expedition_return' then 'Expedition returned' when f.mission = 'harvest_return' then 'Harvest returned' when f.mission = 'colonize_return' then 'Colony ship returned' else 'Fleet returned' end,
        coalesce(f.report, 'The raiders dumped their holds.'),
        f.cargo_ore,
        f.cargo_crystal
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
