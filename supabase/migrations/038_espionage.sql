-- Wiki espionage probes: spy mission, reports, counter-espionage.

do $$
declare
  c text;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'fleets'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%mission%'
  loop
    execute format('alter table public.fleets drop constraint %I', c);
  end loop;
end
$$;

alter table public.fleets
  add constraint fleets_mission_check
  check (mission in (
    'attack',
    'return',
    'espionage',
    'espionage_return',
    'expedition',
    'expedition_hold',
    'expedition_return'
  ));

create or replace function private.espionage_probes_needed(x integer, yours integer, enemy integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    1,
    x + (
      case
        when yours > enemy then -1
        when yours < enemy then 1
        else 0
      end
    ) * (yours - enemy) * (yours - enemy)
  );
$$;

create or replace function private.counter_espionage_chance(yours integer, enemy integer, probes integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select least(
    1::numeric,
    greatest(coalesce(probes, 1), 1)::numeric
      * (greatest(coalesce(enemy, 0), 0) + 1)
      / ((greatest(coalesce(yours, 0), 0) + 1)::numeric * (greatest(coalesce(yours, 0), 0) + 1))
  );
$$;

create or replace function private.docked_combat_ships(ships jsonb)
returns integer
language sql
immutable
set search_path = ''
as $$
  select coalesce(sum(greatest((value)::integer, 0)), 0)::integer
  from jsonb_each_text(coalesce(ships, '{}'::jsonb))
  where key not in ('espionage_probe', 'solar_satellite', 'crawler');
$$;

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

  flight := private.flight_seconds(
    origin.system,
    origin.slot,
    dest.system,
    dest.slot,
    attacker.propulsion_level,
    origin.galaxy,
    dest.galaxy
  );

  if destroyed then
    update public.fleets
    set
      status = 'completed',
      raiders = 0,
      report = body
    where id = f.id;
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (uid, 'Espionage report', body, 0, 0);
  else
    update public.fleets
    set
      mission = 'espionage_return',
      arrives_at = f.arrives_at + make_interval(secs => flight),
      report = body
    where id = f.id;
  end if;
end;
$$;

revoke all on function private.espionage_probes_needed(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.counter_espionage_chance(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.docked_combat_ships(jsonb) from public, anon, authenticated;
revoke all on function private.resolve_espionage_arrival(uuid, public.empires, public.fleets) from public, anon, authenticated;

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

  flight := private.flight_seconds(
    origin.system,
    origin.slot,
    dest.system,
    dest.slot,
    e.propulsion_level,
    origin.galaxy,
    dest.galaxy
  );
  fuel := private.fleet_fuel_round_trip(
    p_probes,
    1,
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot)
  );
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
    raiders, mission, arrives_at, composition
  )
  values (
    uid, origin.id, dest.id,
    dest.galaxy, dest.system, dest.slot,
    p_probes, 'espionage', at + make_interval(secs => flight),
    jsonb_build_object('espionage_probe', p_probes)
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
  flown double precision;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into f from public.fleets where id = p_id for update;
  if not found or f.owner_id is distinct from uid or f.status <> 'en_route' then
    raise exception 'Fleet not found.';
  end if;
  if f.mission not in ('attack', 'expedition', 'espionage') then
    raise exception 'That fleet cannot be recalled.';
  end if;
  if f.arrives_at <= at then
    raise exception 'The fleet already reached its target.';
  end if;

  select * into origin from public.planets where id = f.origin_planet_id;
  flown := greatest(extract(epoch from (at - f.created_at)), 1);

  update public.fleets
  set
    mission = case
      when f.mission = 'expedition' then 'expedition_return'
      when f.mission = 'espionage' then 'espionage_return'
      else 'return'
    end,
    dest_planet_id = f.origin_planet_id,
    dest_galaxy = origin.galaxy,
    dest_system = origin.system,
    dest_slot = origin.slot,
    created_at = at,
    arrives_at = at + make_interval(secs => flown),
    report = 'Fleet recalled.'
  where id = f.id;

  return private.empire_state_json(uid, timezone('utc', now()));
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
    where status = 'en_route'
      and arrives_at <= at
      and (
        owner_id = uid
        or (owner_id is null and dest_planet_id = e.home_planet_id)
      )
    order by arrives_at
    limit 1
    for update skip locked;

    exit when not found;

    if f.owner_id is null then
      home := private.resolve_pirate_wave(home, uid, f.arrives_at, f.raiders);
      update public.fleets set status = 'completed' where id = f.id;
    elsif f.mission = 'attack' then
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

notify pgrst, 'reload schema';
