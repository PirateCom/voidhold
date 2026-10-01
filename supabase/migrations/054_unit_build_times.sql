-- Ship and defence build time from cost: (metal + crystal) / 12500 hours at Robotics 0 / Nanite 0,
-- divided by (1 + robotics) * 2^nanite * economy speed.

create or replace function private.unit_build_seconds(p public.planets, id text)
returns integer
language sql
stable
set search_path = ''
as $$
  select greatest(1, floor(
    (
      coalesce(private.ship_cost_ore(id), private.defence_cost_ore(id), 0)
      + coalesce(private.ship_cost_crystal(id), private.defence_cost_crystal(id), 0)
    )::numeric * 3600 / 12500
    / (
      (1 + greatest(coalesce(p.robotics_factory, 0), 0))
      * power(2, greatest(coalesce(p.nanite_factory, 0), 0))
      * greatest(coalesce((select e.economy_speed from public.empires e where e.user_id = p.owner_id), 1), 1)
    )
  ))::integer;
$$;

revoke all on function private.unit_build_seconds(public.planets, text) from public, anon, authenticated;
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
    elsif p.upgrade_building = 'deuterium_extractor' then
      p.deuterium_extractor := p.deuterium_extractor + 1;
    elsif p.upgrade_building = 'power_plant' then
      p.power_plant := p.power_plant + 1;
    elsif p.upgrade_building = 'fusion_reactor' then
      p.fusion_reactor := p.fusion_reactor + 1;
    elsif p.upgrade_building = 'ore_storage' then
      p.ore_storage := p.ore_storage + 1;
    elsif p.upgrade_building = 'crystal_storage' then
      p.crystal_storage := p.crystal_storage + 1;
    elsif p.upgrade_building = 'deuterium_storage' then
      p.deuterium_storage := p.deuterium_storage + 1;
    elsif p.upgrade_building = 'robotics_factory' then
      p.robotics_factory := p.robotics_factory + 1;
    elsif p.upgrade_building = 'shipyard' then
      p.shipyard := p.shipyard + 1;
    elsif p.upgrade_building = 'research_lab' then
      p.research_lab := p.research_lab + 1;
    elsif p.upgrade_building = 'alliance_depot' then
      p.alliance_depot := p.alliance_depot + 1;
    elsif p.upgrade_building = 'missile_silo' then
      p.missile_silo := p.missile_silo + 1;
    elsif p.upgrade_building = 'nanite_factory' then
      p.nanite_factory := p.nanite_factory + 1;
    elsif p.upgrade_building = 'terraformer' then
      p.terraformer := p.terraformer + 1;
    elsif p.upgrade_building = 'lunar_base' then
      p.lunar_base := p.lunar_base + 1;
    elsif p.upgrade_building = 'phalanx_sensor' then
      p.phalanx_sensor := p.phalanx_sensor + 1;
    elsif p.upgrade_building = 'stargate' then
      p.stargate := p.stargate + 1;
    elsif p.upgrade_building = 'space_station' then
      p.space_station := p.space_station + 1;
    end if;
    p.upgrade_building := null;
    p.upgrade_completes_at := null;
    p.upgrade_started_at := null;
  end if;

  while p.defences_queued > 0 and p.defence_building is not null and p.defence_completes_at is not null and p.defence_completes_at <= at loop
    p := private.apply_defence(p, p.defence_building);
    p.defences_queued := p.defences_queued - 1;
    if p.defences_queued > 0 then
      p.defence_completes_at := p.defence_completes_at + make_interval(secs => private.unit_build_seconds(p, p.defence_building));
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

create or replace function public.queue_defence(p_id text, p_count integer)
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
  cost_deut bigint;
  pending integer;
  valid boolean;
  blocked text;
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
    'gauss_cannon',
    'plasma_turret',
    'antiballistic_missile',
    'interplanetary_missile'
  );
  if not valid then
    raise exception 'Unknown defence.';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if home.defences_queued > 0 and home.defence_building is not null and home.defence_building <> p_id then
    raise exception 'Defence yard occupied.';
  end if;

  pending := case when home.defence_building = p_id then home.defences_queued else 0 end;
  if private.defence_is_unique(p_id) and private.defence_owned(home, p_id) + pending + p_count > 1 then
    raise exception 'Only one of those domes fits on this world.';
  end if;

  blocked := private.defence_block(home, e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  cost_ore := private.defence_cost_ore(p_id) * p_count;
  cost_crystal := private.defence_cost_crystal(p_id) * p_count;
  cost_deut := private.defence_cost_deuterium(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut,
    defence_building = p_id,
    defences_queued = home.defences_queued + p_count,
    defence_completes_at = case
      when home.defences_queued = 0 then at + make_interval(secs => private.unit_build_seconds(home, p_id))
      else home.defence_completes_at
    end
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

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
  cost_deut bigint;
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

  busy := coalesce(nullif(home.ship_building, ''), 'small_cargo');
  if home.ships_queued > 0 and busy <> p_id then
    raise exception 'Shipyard occupied.';
  end if;

  cost_ore := private.ship_cost_ore(p_id) * p_count;
  cost_crystal := private.ship_cost_crystal(p_id) * p_count;
  cost_deut := private.ship_cost_deuterium(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut,
    ship_building = p_id,
    ships_queued = home.ships_queued + p_count,
    ship_completes_at = case
      when home.ships_queued = 0 then at + make_interval(secs => private.unit_build_seconds(home, p_id))
      else home.ship_completes_at
    end
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
