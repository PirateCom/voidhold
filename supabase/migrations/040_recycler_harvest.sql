-- Wiki recyclers: harvest debris fields (metal + crystal only). Instant collect on arrival, then return.

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
    'harvest',
    'harvest_return',
    'expedition',
    'expedition_hold',
    'expedition_return'
  ));

create or replace function private.harvest_debris_share(p_ore bigint, p_crystal bigint, p_capacity bigint)
returns table (take_ore bigint, take_crystal bigint)
language sql
immutable
set search_path = ''
as $$
  select
    case
      when coalesce(p_capacity, 0) <= 0 or greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0) <= 0 then 0
      when greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0) <= p_capacity then greatest(coalesce(p_ore, 0), 0)
      else floor(greatest(coalesce(p_ore, 0), 0)::numeric * p_capacity / (greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0)))::bigint
    end,
    case
      when coalesce(p_capacity, 0) <= 0 or greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0) <= 0 then 0
      when greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0) <= p_capacity then greatest(coalesce(p_crystal, 0), 0)
      else least(
        greatest(coalesce(p_crystal, 0), 0),
        p_capacity - floor(greatest(coalesce(p_ore, 0), 0)::numeric * p_capacity / (greatest(coalesce(p_ore, 0), 0) + greatest(coalesce(p_crystal, 0), 0)))::bigint
      )
    end;
$$;

create or replace function private.collect_debris(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_capacity bigint
)
returns table (take_ore bigint, take_crystal bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  field public.debris_fields%rowtype;
  ore_take bigint := 0;
  crystal_take bigint := 0;
begin
  select * into field
  from public.debris_fields
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;

  if not found then
    take_ore := 0;
    take_crystal := 0;
    return next;
    return;
  end if;

  select s.take_ore, s.take_crystal
  into ore_take, crystal_take
  from private.harvest_debris_share(field.ore, field.crystal, p_capacity) s;

  if field.ore - ore_take <= 0 and field.crystal - crystal_take <= 0 then
    delete from public.debris_fields
    where galaxy = p_galaxy and system = p_system and slot = p_slot;
  else
    update public.debris_fields
    set
      ore = field.ore - ore_take,
      crystal = field.crystal - crystal_take
    where galaxy = p_galaxy and system = p_system and slot = p_slot;
  end if;

  take_ore := ore_take;
  take_crystal := crystal_take;
  return next;
end;
$$;

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
  base_flight integer;
begin
  select * into origin from public.planets where id = f.origin_planet_id;
  dest_g := coalesce(f.dest_galaxy, origin.galaxy);
  dest_s := coalesce(f.dest_system, origin.system);
  dest_sl := coalesce(f.dest_slot, origin.slot);
  recyclers := greatest(coalesce((f.composition->>'recycler')::integer, 0), 0);
  cap := recyclers::bigint * private.ship_cargo('recycler');

  select c.take_ore, c.take_crystal
  into ore_take, crystal_take
  from private.collect_debris(dest_g, dest_s, dest_sl, cap) c;

  slowest := private.ship_speed('recycler', e.impulse_drive, e.hyperspace_drive);
  base_flight := private.flight_seconds(
    origin.system, origin.slot, dest_s, dest_sl, e.propulsion_level, origin.galaxy, dest_g
  );
  flight := greatest(15, floor(base_flight * (5000.0 / greatest(slowest, 1)))::integer);

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
  base_flight integer;
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

  slowest := private.ship_speed('recycler', e.impulse_drive, e.hyperspace_drive);
  base_flight := private.flight_seconds(
    origin.system, origin.slot, p_system, p_slot, e.propulsion_level, origin.galaxy, p_galaxy
  );
  flight := greatest(15, floor(base_flight * (5000.0 / greatest(slowest, 1)))::integer);

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

revoke all on function public.send_harvest(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_harvest(smallint, smallint, smallint, integer) to authenticated;

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
  if f.mission not in ('attack', 'expedition', 'espionage', 'harvest') then
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
      when f.mission = 'harvest' then 'harvest_return'
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
        or (mission = 'attack' and dest_planet_id = e.home_planet_id)
      )
    order by arrives_at
    limit 1
    for update skip locked;

    exit when not found;

    if f.owner_id is null then
      home := private.resolve_pirate_wave(home, uid, f.arrives_at, f.raiders);
      update public.fleets set status = 'completed' where id = f.id;
    elsif f.mission = 'attack' then
      if private.resolve_attack_arrival(coalesce(f.owner_id, uid), e, f) then
        exit;
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
        case when f.mission = 'expedition_return' then 'Expedition returned' when f.mission = 'harvest_return' then 'Harvest returned' else 'Fleet returned' end,
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
  perform private.catch_up(o.user_id, at)
  from public.empires o
  where o.user_id is distinct from uid;

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
    'rank', private.rank_payload(uid),
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', case
          when coalesce(f.dest_slot, dp.slot) = 16 then 'Outer space'
          when f.mission in ('harvest', 'harvest_return') then coalesce(dp.name, 'Debris field')
          else dp.name
        end,
        'dest_galaxy', coalesce(f.dest_galaxy, dp.galaxy),
        'dest_system', coalesce(f.dest_system, dp.system),
        'dest_slot', coalesce(f.dest_slot, dp.slot),
        'origin_name', coalesce(op.name, 'Deep space'),
        'origin_galaxy', coalesce(op.galaxy, dp.galaxy),
        'origin_system', coalesce(op.system, dp.system),
        'origin_slot', coalesce(op.slot, dp.slot),
        'created_at', f.created_at,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'cargo_deuterium', f.cargo_deuterium,
        'status', f.status,
        'report', f.report,
        'inbound', (f.owner_id is distinct from uid),
        'attacker_name', case when f.owner_id is null then 'Pirates' else ap.display_name end,
        'ship_count', case
          when f.composition is not null and f.composition <> '{}'::jsonb then (
            select coalesce(sum(greatest(value::integer, 0)), 0)::integer
            from jsonb_each_text(f.composition)
          )
          else f.raiders
        end,
        'composition', case
          when f.owner_id is distinct from uid then '{}'::jsonb
          else f.composition
        end
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
      left join public.planets op on op.id = f.origin_planet_id
      left join public.profiles ap on ap.user_id = f.owner_id
      where f.status = 'en_route'
        and (f.owner_id = uid or f.dest_planet_id = p.id)
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

revoke all on function private.ship_speed(text, integer, integer) from public, anon, authenticated;
revoke all on function private.ship_fuel(text, integer) from public, anon, authenticated;
revoke all on function private.rapid_fire(text, text) from public, anon, authenticated;
revoke all on function private.unit_label(text) from public, anon, authenticated;
revoke all on function private.unit_cargo(text) from public, anon, authenticated;
revoke all on function private.combat_stats(text) from public, anon, authenticated;
revoke all on function private.plunder(bigint, bigint, bigint, bigint) from public, anon, authenticated;
revoke all on function private.lcg_step(bigint) from public, anon, authenticated;
revoke all on function private.apply_volley(jsonb, integer, numeric, numeric, numeric) from public, anon, authenticated;
revoke all on function private.scaled_profiles(jsonb, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.stacks_from_profiles(jsonb) from public, anon, authenticated;
revoke all on function private.force_alive(jsonb) from public, anon, authenticated;
revoke all on function private.combat_shoot(jsonb, jsonb, jsonb, jsonb) from public, anon, authenticated;
revoke all on function private.explode_force(jsonb, jsonb, bigint) from public, anon, authenticated;
revoke all on function private.survivor_counts(jsonb) from public, anon, authenticated;
revoke all on function private.resolve_combat(jsonb, jsonb, integer, integer, integer, integer, integer, integer, bigint) from public, anon, authenticated;
revoke all on function private.assign_defence(public.planets, text, integer) from public, anon, authenticated;
revoke all on function private.loss_line(jsonb, jsonb) from public, anon, authenticated;
revoke all on function private.resolve_attack_arrival(uuid, public.empires, public.fleets) from public, anon, authenticated;

revoke all on function public.send_harvest(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.send_harvest(smallint, smallint, smallint, integer) to authenticated;
notify pgrst, 'reload schema';
