do $$
declare
  c name;
begin
  select con.conname into c
  from pg_constraint con
  where con.conrelid = 'public.fleets'::regclass
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%attack%return%';
  if c is not null then
    execute format('alter table public.fleets drop constraint %I', c);
  end if;
end $$;

alter table public.fleets
  alter column dest_planet_id drop not null;

alter table public.fleets
  add constraint fleets_mission_check
  check (mission in ('attack', 'return', 'expedition', 'expedition_hold', 'expedition_return'));

alter table public.fleets add column if not exists dest_galaxy smallint;
alter table public.fleets add column if not exists dest_system smallint;
alter table public.fleets add column if not exists dest_slot smallint;
alter table public.fleets add column if not exists cargo_deuterium bigint not null default 0;
alter table public.fleets add column if not exists composition jsonb not null default '{}'::jsonb;

update public.fleets f
set
  dest_galaxy = p.galaxy,
  dest_system = p.system,
  dest_slot = p.slot
from public.planets p
where p.id = f.dest_planet_id
  and f.dest_galaxy is null;

create or replace function private.expedition_fleet_cap(astrophysics integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select floor(sqrt(greatest(coalesce(astrophysics, 0), 0)))::integer;
$$;

revoke all on function private.expedition_fleet_cap(integer) from public, anon, authenticated;

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
        'dest_name', case
          when coalesce(f.dest_slot, dp.slot) = 16 then 'Outer space'
          else dp.name
        end,
        'dest_galaxy', coalesce(f.dest_galaxy, dp.galaxy),
        'dest_system', coalesce(f.dest_system, dp.system),
        'dest_slot', coalesce(f.dest_slot, dp.slot),
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'cargo_deuterium', f.cargo_deuterium,
        'status', f.status,
        'report', f.report
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
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

  update public.empires set raiders = e.raiders - ships where user_id = uid;

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

revoke all on function public.send_expedition(smallint, smallint, jsonb) from public, anon;
grant execute on function public.send_expedition(smallint, smallint, jsonb) to authenticated;
