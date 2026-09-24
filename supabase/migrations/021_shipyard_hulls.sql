alter table public.empires
  add column if not exists ships jsonb not null default '{}'::jsonb;

alter table public.empires
  add column if not exists ship_building text;

update public.empires
set ships = jsonb_set(coalesce(ships, '{}'::jsonb), '{small_cargo}', to_jsonb(raiders), true)
where raiders > 0
  and coalesce((ships ->> 'small_cargo')::integer, 0) = 0;

create or replace function private.bump_ship(ships jsonb, id text, n integer)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_set(
    coalesce(ships, '{}'::jsonb),
    array[id],
    to_jsonb(greatest(0, coalesce((ships ->> id)::integer, 0) + n))
  );
$$;

revoke all on function private.bump_ship(jsonb, text, integer) from public, anon, authenticated;

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
    when 'espionage_probe' then 1000
    when 'reaper' then 55000
    when 'pathfinder' then 15000
    when 'crawler' then 2000
    when 'solar_satellite' then 2000
    else null
  end;
$$;

create or replace function private.ship_cost_deuterium(id text)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'cruiser' then 2000
    when 'battlecruiser' then 15000
    when 'bomber' then 15000
    when 'destroyer' then 15000
    when 'deathstar' then 1000000
    when 'colony_ship' then 10000
    when 'recycler' then 2000
    when 'reaper' then 20000
    when 'pathfinder' then 8000
    when 'crawler' then 1000
    when 'solar_satellite' then 500
    else 0
  end;
$$;

revoke all on function private.ship_cost_ore(text) from public, anon, authenticated;
revoke all on function private.ship_cost_crystal(text) from public, anon, authenticated;
revoke all on function private.ship_cost_deuterium(text) from public, anon, authenticated;

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

create or replace function public.queue_ship(p_id text, p_count integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  cost_ore bigint;
  cost_crystal bigint;
  blocked text;
  busy text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  blocked := private.ship_block(home, e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  busy := coalesce(nullif(e.ship_building, ''), 'small_cargo');
  if e.raiders_queued > 0 and busy <> p_id then
    raise exception 'Shipyard occupied.';
  end if;

  cost_ore := private.ship_cost_ore(p_id) * p_count;
  cost_crystal := private.ship_cost_crystal(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set
    ship_building = p_id,
    raiders_queued = e.raiders_queued + p_count,
    raider_completes_at = case
      when e.raiders_queued = 0 then at + make_interval(secs => 15)
      else e.raider_completes_at
    end
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.queue_ship(text, integer) from public, anon;
grant execute on function public.queue_ship(text, integer) to authenticated;

create or replace function public.queue_raiders(p_count integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.queue_ship('small_cargo', p_count);
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
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e := private.apply_research(e, coalesce(e.research_tech, 'combustion_drive'));
  end if;

  while e.raiders_queued > 0 and e.raider_completes_at is not null and e.raider_completes_at <= at loop
    hull := coalesce(nullif(e.ship_building, ''), 'small_cargo');
    e.ships := private.bump_ship(e.ships, hull, 1);
    if hull = 'small_cargo' then
      e.raiders := e.raiders + 1;
    end if;
    e.raiders_queued := e.raiders_queued - 1;
    if e.raiders_queued > 0 then
      e.raider_completes_at := e.raider_completes_at + make_interval(secs => 15);
    else
      e.raider_completes_at := null;
      e.ship_building := null;
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

      e.raiders := e.raiders + f.raiders;
      e.ships := private.bump_ship(e.ships, 'small_cargo', f.raiders);
      if origin.id = home.id then
        home := origin;
      end if;

      update public.fleets
      set status = 'completed'
      where id = f.id;

      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        uid,
        case when f.mission = 'expedition_return' then 'Expedition returned' else 'Fleet returned' end,
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
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    ships = e.ships,
    ship_building = e.ship_building,
    research_tech = e.research_tech,
    research_completes_at = e.research_completes_at,
    next_pirate_at = e.next_pirate_at
  where user_id = uid;
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
    deuterium = 0,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    deuterium_extractor = 0,
    power_plant = 1,
    fusion_reactor = 0,
    ore_storage = 0,
    crystal_storage = 0,
    deuterium_storage = 0,
    robotics_factory = 0,
    shipyard = 0,
    research_lab = 0,
    alliance_depot = 0,
    missile_silo = 0,
    nanite_factory = 0,
    terraformer = 0,
    lunar_base = 0,
    phalanx_sensor = 0,
    stargate = 0,
    space_station = 0,
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
    energy_tech = 0,
    laser_tech = 0,
    ion_tech = 0,
    hyperspace_tech = 0,
    plasma_tech = 0,
    impulse_drive = 0,
    hyperspace_drive = 0,
    espionage_tech = 0,
    computer_tech = 0,
    astrophysics = 0,
    intergalactic_research_network = 0,
    graviton_tech = 0,
    weapons_tech = 0,
    shielding_tech = 0,
    armour_tech = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    ships = '{}'::jsonb,
    ship_building = null,
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

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

  update public.empires
  set
    raiders = e.raiders - p_raiders,
    ships = private.bump_ship(e.ships, 'small_cargo', -p_raiders)
  where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at
  )
  values (
    uid, origin.id, dest.id, p_raiders, 'attack', at + make_interval(secs => flight)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_expedition(p_galaxy smallint, p_system smallint, p_ships jsonb)
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
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 then
    raise exception 'That coordinate is outside the universe.';
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
    origin.system,
    origin.slot,
    p_system,
    16,
    e.propulsion_level,
    origin.galaxy,
    p_galaxy
  ));

  update public.empires
  set
    raiders = e.raiders - ships,
    ships = private.bump_ship(e.ships, 'small_cargo', -ships)
  where user_id = uid;

  insert into public.fleets (
    owner_id,
    origin_planet_id,
    dest_planet_id,
    dest_galaxy,
    dest_system,
    dest_slot,
    raiders,
    mission,
    arrives_at,
    composition
  )
  values (
    uid,
    origin.id,
    null,
    p_galaxy,
    p_system,
    16,
    ships,
    'expedition',
    at + make_interval(secs => flight),
    jsonb_build_object('small_cargo', ships)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

