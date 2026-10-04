-- Deploy (station) fleets among a commander's own planets.
-- Ships dock per planet. Optional cargo stays at the destination; the fleet does not return.

alter table public.planets
  add column if not exists ships jsonb not null default '{}'::jsonb;

update public.planets p
set ships = coalesce(e.ships, '{}'::jsonb)
from public.empires e
where e.home_planet_id = p.id
  and (p.ships is null or p.ships = '{}'::jsonb)
  and coalesce(e.ships, '{}'::jsonb) <> '{}'::jsonb;

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
    'deploy'
  ));

create or replace function private.merge_ships(a jsonb, b jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  rec record;
  out jsonb := coalesce(a, '{}'::jsonb);
begin
  for rec in select key, greatest(value::integer, 0) as n from jsonb_each_text(coalesce(b, '{}'::jsonb)) loop
    if rec.n > 0 then
      out := private.bump_ship(out, rec.key, rec.n);
    end if;
  end loop;
  return out;
end;
$$;

create or replace function private.sync_empire_home_ships()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  parked jsonb;
begin
  if tg_op = 'UPDATE' and new.home_planet_id is distinct from old.home_planet_id then
    update public.planets
    set ships = coalesce(old.ships, '{}'::jsonb)
    where id = old.home_planet_id;
    select coalesce(ships, '{}'::jsonb) into parked
    from public.planets
    where id = new.home_planet_id;
    new.ships := coalesce(parked, '{}'::jsonb);
    new.raiders := coalesce((new.ships->>'small_cargo')::integer, 0);
  elsif tg_op = 'UPDATE' and new.ships is distinct from old.ships then
    update public.planets
    set ships = coalesce(new.ships, '{}'::jsonb)
    where id = new.home_planet_id;
  end if;
  return new;
end;
$$;

drop trigger if exists empires_sync_home_ships on public.empires;
create trigger empires_sync_home_ships
  before update of home_planet_id, ships on public.empires
  for each row execute function private.sync_empire_home_ships();

create or replace function private.resolve_deploy_arrival(f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  dest public.planets%rowtype;
  origin public.planets%rowtype;
  owner public.empires%rowtype;
  kv record;
  parked jsonb;
begin
  select * into dest from public.planets where id = f.dest_planet_id for update;
  if not found or dest.owner_id is distinct from f.owner_id then
    select * into origin from public.planets where id = f.origin_planet_id for update;
    if found then
      origin := private.catch_up_planet(origin, f.arrives_at);
      origin.ore := least(private.storage_cap(origin.ore_storage), origin.ore + coalesce(f.cargo_ore, 0));
      origin.crystal := least(private.storage_cap(origin.crystal_storage), origin.crystal + coalesce(f.cargo_crystal, 0));
      origin.deuterium := least(private.storage_cap(origin.deuterium_storage), origin.deuterium + coalesce(f.cargo_deuterium, 0));
      for kv in select key, greatest(value::integer, 0) as n from jsonb_each_text(coalesce(f.composition, '{}'::jsonb)) loop
        if kv.n > 0 then
          origin.ships := private.bump_ship(origin.ships, kv.key, kv.n);
        end if;
      end loop;
      perform private.persist_planet(origin);
      select * into owner from public.empires where user_id = f.owner_id for update;
      if found and owner.home_planet_id = origin.id then
        update public.empires
        set ships = origin.ships, raiders = coalesce((origin.ships->>'small_cargo')::integer, 0)
        where user_id = owner.user_id;
      end if;
    end if;
    update public.fleets
    set status = 'completed', report = 'The destination was gone. The fleet returned to origin.'
    where id = f.id;
    return;
  end if;

  dest := private.catch_up_planet(dest, f.arrives_at);
  dest.ore := least(private.storage_cap(dest.ore_storage), dest.ore + coalesce(f.cargo_ore, 0));
  dest.crystal := least(private.storage_cap(dest.crystal_storage), dest.crystal + coalesce(f.cargo_crystal, 0));
  dest.deuterium := least(private.storage_cap(dest.deuterium_storage), dest.deuterium + coalesce(f.cargo_deuterium, 0));
  parked := coalesce(dest.ships, '{}'::jsonb);
  for kv in select key, greatest(value::integer, 0) as n from jsonb_each_text(coalesce(f.composition, '{}'::jsonb)) loop
    if kv.n > 0 then
      parked := private.bump_ship(parked, kv.key, kv.n);
    end if;
  end loop;
  dest.ships := parked;
  perform private.persist_planet(dest);

  select * into owner from public.empires where user_id = dest.owner_id for update;
  if found and owner.home_planet_id = dest.id then
    update public.empires
    set ships = dest.ships, raiders = coalesce((dest.ships->>'small_cargo')::integer, 0)
    where user_id = owner.user_id;
  end if;

  update public.fleets
  set
    status = 'completed',
    report = format(
      'Deployed at %s [%s:%s:%s].',
      dest.name, dest.galaxy, dest.system, dest.slot
    )
  where id = f.id;

  insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
  values (
    f.owner_id,
    'Fleet deployed',
    concat_ws(
      ' ',
      format('Stationed at %s [%s:%s:%s].', dest.name, dest.galaxy, dest.system, dest.slot),
      case
        when coalesce(f.cargo_ore, 0) + coalesce(f.cargo_crystal, 0) + coalesce(f.cargo_deuterium, 0) > 0 then
          format(
            'Unloaded %s ore, %s crystal, %s deuterium.',
            coalesce(f.cargo_ore, 0), coalesce(f.cargo_crystal, 0), coalesce(f.cargo_deuterium, 0)
          )
        else 'Holds were empty.'
      end
    ),
    coalesce(f.cargo_ore, 0),
    coalesce(f.cargo_crystal, 0)
  );
end;
$$;

revoke all on function private.resolve_deploy_arrival(public.fleets) from public, anon, authenticated;

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
    deuterium = p.deuterium,
    last_harvested_at = p.last_harvested_at,
    ore_mine = p.ore_mine,
    crystal_mine = p.crystal_mine,
    deuterium_extractor = p.deuterium_extractor,
    power_plant = p.power_plant,
    fusion_reactor = p.fusion_reactor,
    ore_storage = p.ore_storage,
    crystal_storage = p.crystal_storage,
    deuterium_storage = p.deuterium_storage,
    robotics_factory = p.robotics_factory,
    shipyard = p.shipyard,
    research_lab = p.research_lab,
    alliance_depot = p.alliance_depot,
    missile_silo = p.missile_silo,
    nanite_factory = p.nanite_factory,
    terraformer = p.terraformer,
    lunar_base = p.lunar_base,
    phalanx_sensor = p.phalanx_sensor,
    stargate = p.stargate,
    space_station = p.space_station,
    upgrade_building = p.upgrade_building,
    upgrade_completes_at = p.upgrade_completes_at,
    upgrade_started_at = p.upgrade_started_at,
    small_shield_dome = p.small_shield_dome,
    large_shield_dome = p.large_shield_dome,
    rocket_launcher = p.rocket_launcher,
    light_laser = p.light_laser,
    heavy_laser = p.heavy_laser,
    ion_cannon = p.ion_cannon,
    gauss_cannon = p.gauss_cannon,
    plasma_turret = p.plasma_turret,
    antiballistic_missile = p.antiballistic_missile,
    interplanetary_missile = p.interplanetary_missile,
    defence_building = p.defence_building,
    defences_queued = p.defences_queued,
    defence_completes_at = p.defence_completes_at,
    ship_building = p.ship_building,
    ships_queued = p.ships_queued,
    ship_completes_at = p.ship_completes_at,
    ships = coalesce(p.ships, '{}'::jsonb)
  where id = p.id;
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
  perform private.prune_battle_reports(at);
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
    'colonies', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'galaxy', c.galaxy,
        'system', c.system,
        'slot', c.slot,
        'is_homeworld', c.is_homeworld
      ) order by c.is_homeworld desc, c.id), '[]'::jsonb)
      from public.planets c
      where c.owner_id = uid
    ),
    'empire', to_jsonb(e) || jsonb_build_object(
      'ships', coalesce(p.ships, e.ships, '{}'::jsonb),
      'raiders', coalesce((coalesce(p.ships, e.ships)->>'small_cargo')::integer, e.raiders),
      'raiders_queued', p.ships_queued,
      'ship_building', p.ship_building,
      'raider_completes_at', p.ship_completes_at
    ),
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
          when f.mission in ('colonize', 'colonize_return') then coalesce(dp.name, 'Empty slot')
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
        and (f.owner_id = uid or f.dest_planet_id in (select pl.id from public.planets pl where pl.owner_id = uid))
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
          and created_at > at - interval '7 days'
        order by created_at desc
        limit 15
      ) r
    ),
    'server_now', at,
    'debug', private.debug_operator()
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

create or replace function private.resolve_attack_arrival(
  uid uuid,
  attacker public.empires,
  f public.fleets
)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  dest public.planets%rowtype;
  def public.empires%rowtype;
  has_defender boolean := false;
  attackers jsonb := '{}'::jsonb;
  defenders jsonb := '{}'::jsonb;
  fought jsonb;
  seed bigint;
  defence_id text;
  rec record;
  survivors jsonb;
  def_survivors jsonb;
  loot record;
  cargo bigint := 0;
  report_text text;
  debris_ore bigint := 0;
  debris_crystal bigint := 0;
  lost integer;
  restored integer;
  i integer;
  stepped record;
  ship_survivors jsonb := '{}'::jsonb;
  new_ships jsonb;
  flight integer;
  outcome text;
  rounds integer;
begin
  if f.owner_id is null then
    return false;
  end if;
  if attacker.user_id is distinct from f.owner_id then
    select * into attacker from public.empires where user_id = f.owner_id for update skip locked;
    if not found then
      return true;
    end if;
  end if;

  perform 1 from public.planets where id = f.dest_planet_id;
  if not found then
    update public.fleets
    set status = 'completed', raiders = 0, report = 'The target is gone.'
    where id = f.id;
    return false;
  end if;

  select * into dest from public.planets where id = f.dest_planet_id for update skip locked;
  if not found then
    return true;
  end if;

  if dest.owner_id is not null then
    perform 1 from public.empires where user_id = dest.owner_id;
    if found then
      select * into def from public.empires where user_id = dest.owner_id for update skip locked;
      if not found then
        return true;
      end if;
      has_defender := true;
      if def.research_completes_at is not null and def.research_completes_at <= f.arrives_at then
        def := private.apply_research(def, coalesce(def.research_tech, 'combustion_drive'));
      end if;
      while def.raiders_queued > 0 and def.raider_completes_at is not null and def.raider_completes_at <= f.arrives_at loop
        def.ships := private.bump_ship(def.ships, coalesce(nullif(def.ship_building, ''), 'small_cargo'), 1);
        if coalesce(nullif(def.ship_building, ''), 'small_cargo') = 'small_cargo' then
          def.raiders := def.raiders + 1;
        end if;
        def.raiders_queued := def.raiders_queued - 1;
        if def.raiders_queued > 0 then
          def.raider_completes_at := def.raider_completes_at + make_interval(secs => 15);
        else
          def.raider_completes_at := null;
          def.ship_building := null;
        end if;
      end loop;
    end if;
  end if;

  dest := private.catch_up_planet(dest, f.arrives_at);

  if coalesce(f.composition, '{}'::jsonb) = '{}'::jsonb then
    attackers := jsonb_build_object('small_cargo', greatest(f.raiders, 0));
  else
    attackers := f.composition;
  end if;
  for rec in select key, greatest(value::integer, 0) as n from jsonb_each_text(attackers) loop
    if rec.n <= 0 or private.ship_speed(rec.key, 0, 0) <= 0 then
      attackers := attackers - rec.key;
    end if;
  end loop;

  if has_defender then
    defenders := coalesce(dest.ships, def.ships, '{}'::jsonb);
    if dest.id = def.home_planet_id and def.raiders > coalesce((defenders->>'small_cargo')::integer, 0) then
      defenders := jsonb_set(defenders, '{small_cargo}', to_jsonb(def.raiders), true);
    end if;
  else
    defenders := coalesce(dest.garrison, '{}'::jsonb);
  end if;
  foreach defence_id in array array[
    'small_shield_dome', 'large_shield_dome', 'rocket_launcher', 'light_laser', 'heavy_laser',
    'ion_cannon', 'gauss_cannon', 'plasma_turret'
  ]
  loop
    if private.planet_defence_count(dest, defence_id) > 0 then
      defenders := defenders || jsonb_build_object(defence_id, private.planet_defence_count(dest, defence_id));
    end if;
  end loop;

  seed := mod(f.id, 4294967296);
  if seed <= 0 then
    seed := 1;
  end if;
  fought := private.resolve_combat(
    attackers,
    defenders,
    attacker.weapons_tech,
    attacker.shielding_tech,
    attacker.armour_tech,
    case when has_defender then def.weapons_tech else 0 end,
    case when has_defender then def.shielding_tech else 0 end,
    case when has_defender then def.armour_tech else 0 end,
    seed
  );
  seed := coalesce((fought->>'seed')::bigint, seed);
  outcome := fought->>'outcome';
  rounds := coalesce((fought->>'rounds')::integer, 0);
  survivors := coalesce(fought->'attackers', '{}'::jsonb);
  def_survivors := coalesce(fought->'defenders', '{}'::jsonb);

  for rec in select key, greatest(value::integer, 0) as n from jsonb_each_text(defenders) loop
    lost := rec.n - coalesce((def_survivors->>rec.key)::integer, 0);
    if lost < 0 then
      lost := 0;
    end if;
    if lost > 0 then
      debris_ore := debris_ore + floor(coalesce(private.ship_cost_ore(rec.key), private.defence_cost_ore(rec.key)::bigint, 0)::numeric * 0.3)::bigint * lost;
      debris_crystal := debris_crystal + floor(coalesce(private.ship_cost_crystal(rec.key), private.defence_cost_crystal(rec.key)::bigint, 0)::numeric * 0.3)::bigint * lost;
    end if;
    if exists (select 1 from private.combat_stats(rec.key) s where s.is_defense) then
      restored := 0;
      for i in 1..lost loop
        select * into stepped from private.lcg_step(seed);
        seed := stepped.next_seed;
        if stepped.roll < 0.7 then
          restored := restored + 1;
        end if;
      end loop;
      dest := private.assign_defence(dest, rec.key, coalesce((def_survivors->>rec.key)::integer, 0) + restored);
    else
      ship_survivors := ship_survivors || jsonb_build_object(rec.key, coalesce((def_survivors->>rec.key)::integer, 0));
    end if;
  end loop;

  for rec in select key, greatest(value::integer, 0) as n from jsonb_each_text(attackers) loop
    lost := rec.n - coalesce((survivors->>rec.key)::integer, 0);
    if lost > 0 then
      debris_ore := debris_ore + floor(coalesce(private.ship_cost_ore(rec.key), 0)::numeric * 0.3)::bigint * lost;
      debris_crystal := debris_crystal + floor(coalesce(private.ship_cost_crystal(rec.key), 0)::numeric * 0.3)::bigint * lost;
    end if;
    cargo := cargo + coalesce((survivors->>rec.key)::integer, 0) * private.unit_cargo(rec.key);
  end loop;

  if outcome = 'attacker' then
    select * into loot from private.plunder(cargo, dest.ore, dest.crystal, dest.deuterium);
  else
    select * into loot from private.plunder(0, 0, 0, 0);
  end if;
  dest.ore := greatest(0, dest.ore - coalesce(loot.loot_ore, 0));
  dest.crystal := greatest(0, dest.crystal - coalesce(loot.loot_crystal, 0));
  dest.deuterium := greatest(0, dest.deuterium - coalesce(loot.loot_deuterium, 0));
  perform private.persist_planet(dest);
  if dest.owner_id is null then
    update public.planets set garrison = ship_survivors where id = dest.id;
  end if;
  perform private.bump_debris(dest.galaxy, dest.system, dest.slot, debris_ore, debris_crystal);

  report_text := format(
    '%s Attacker losses: %s. Defender losses: %s. Plunder %s ore, %s crystal, %s deuterium. %s',
    case
      when defenders = '{}'::jsonb then 'The hold had no fleet or defenses.'
      when outcome = 'attacker' then format('Attacker wins after %s round%s.', rounds, case when rounds = 1 then '' else 's' end)
      when outcome = 'defender' then format('Defender holds after %s round%s.', rounds, case when rounds = 1 then '' else 's' end)
      else format('Draw after %s round%s.', rounds, case when rounds = 1 then '' else 's' end)
    end,
    private.loss_line(attackers, survivors),
    private.loss_line(defenders, def_survivors),
    coalesce(loot.loot_ore, 0),
    coalesce(loot.loot_crystal, 0),
    coalesce(loot.loot_deuterium, 0),
    case
      when debris_ore + debris_crystal > 0 then format('Debris %s ore, %s crystal.', debris_ore, debris_crystal)
      else 'No debris.'
    end
  );

  if has_defender then
    new_ships := coalesce(dest.ships, def.ships, '{}'::jsonb);
    for rec in select key, value from jsonb_each(ship_survivors) loop
      new_ships := jsonb_set(new_ships, array[rec.key], rec.value, true);
    end loop;
    update public.planets set ships = new_ships where id = dest.id;
    update public.empires
    set
      ships = case when dest.id = def.home_planet_id then new_ships else ships end,
      raiders = case
        when dest.id = def.home_planet_id then coalesce((new_ships->>'small_cargo')::integer, 0)
        else raiders
      end,
      propulsion_level = def.propulsion_level,
      energy_tech = def.energy_tech,
      laser_tech = def.laser_tech,
      ion_tech = def.ion_tech,
      hyperspace_tech = def.hyperspace_tech,
      plasma_tech = def.plasma_tech,
      impulse_drive = def.impulse_drive,
      hyperspace_drive = def.hyperspace_drive,
      espionage_tech = def.espionage_tech,
      computer_tech = def.computer_tech,
      astrophysics = def.astrophysics,
      intergalactic_research_network = def.intergalactic_research_network,
      graviton_tech = def.graviton_tech,
      weapons_tech = def.weapons_tech,
      shielding_tech = def.shielding_tech,
      armour_tech = def.armour_tech,
      raiders_queued = def.raiders_queued,
      raider_completes_at = def.raider_completes_at,
      ship_building = def.ship_building,
      research_tech = def.research_tech,
      research_completes_at = def.research_completes_at
    where user_id = def.user_id;
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (
      def.user_id,
      format('Attack on %s', dest.name),
      report_text,
      coalesce(loot.loot_ore, 0),
      coalesce(loot.loot_crystal, 0)
    );
  end if;

  select coalesce(f.flight_seconds, private.flight_seconds(
    (select system from public.planets where id = f.origin_planet_id),
    (select slot from public.planets where id = f.origin_planet_id),
    dest.system,
    dest.slot,
    attacker.propulsion_level,
    (select galaxy from public.planets where id = f.origin_planet_id),
    dest.galaxy
  )) into flight;

  if survivors = '{}'::jsonb then
    update public.fleets
    set status = 'completed', raiders = 0, composition = '{}'::jsonb, report = report_text
    where id = f.id;
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (f.owner_id, format('Attack on %s', dest.name), report_text, 0, 0);
  else
    update public.fleets
    set
      mission = 'return',
      raiders = coalesce((survivors->>'small_cargo')::integer, 0),
      composition = survivors,
      cargo_ore = coalesce(loot.loot_ore, 0),
      cargo_crystal = coalesce(loot.loot_crystal, 0),
      cargo_deuterium = coalesce(loot.loot_deuterium, 0),
      arrives_at = f.arrives_at + make_interval(secs => flight),
      report = report_text
    where id = f.id;
  end if;

  return false;
end;
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

create or replace function public.send_deploy(
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
    raise exception 'Deploy needs a planet.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;
  select * into dest
  from public.planets
  where galaxy = p_galaxy and system = p_system and slot = p_slot;
  if not found or dest.owner_id is distinct from uid then
    raise exception 'Deploy only among your own planets.';
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
  if load_ore + load_crystal + load_deut > capacity then
    raise exception 'Not enough cargo space.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, dest.galaxy, dest.system, dest.slot);
  slowest := null;
  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    fuel := fuel + private.fleet_fuel_round_trip(rec.n, private.ship_fuel(rec.key, e.impulse_drive), distance) / 2;
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
    'deploy',
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

create or replace function public.abandon_planet(p_planet_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  target public.planets;
  next_id bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into target
  from public.planets
  where id = p_planet_id and owner_id = uid
  for update;
  if not found then
    raise exception 'That is not your planet.';
  end if;

  perform private.catch_up(uid, timezone('utc', now()));

  if (select count(*) from public.planets where owner_id = uid) < 2 then
    raise exception 'You need at least one other planet before abandoning this one.';
  end if;

  if exists (
    select 1 from public.fleets f
    where f.status = 'en_route'
      and (f.origin_planet_id = p_planet_id or f.dest_planet_id = p_planet_id)
  ) then
    raise exception 'Fleets are still moving to or from this planet.';
  end if;

  select id into next_id
  from public.planets
  where owner_id = uid and id <> p_planet_id
  order by is_homeworld desc, id
  limit 1;

  update public.planets p
  set ships = private.merge_ships(p.ships, coalesce(target.ships, '{}'::jsonb))
  where p.id = case
    when (select home_planet_id from public.empires where user_id = uid) = target.id then next_id
    else (select home_planet_id from public.empires where user_id = uid)
  end;

  update public.empires e
  set
    ships = private.merge_ships(e.ships, coalesce(target.ships, '{}'::jsonb)),
    raiders = coalesce((private.merge_ships(e.ships, coalesce(target.ships, '{}'::jsonb))->>'small_cargo')::integer, 0)
  where e.user_id = uid
    and e.home_planet_id is distinct from target.id;

  update public.empires
  set home_planet_id = next_id
  where user_id = uid and home_planet_id = p_planet_id;

  if target.is_homeworld then
    update public.planets set is_homeworld = true where id = next_id;
  end if;

  delete from public.fleets
  where origin_planet_id = p_planet_id or dest_planet_id = p_planet_id;

  delete from public.planets where id = p_planet_id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

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
  if f.mission not in ('attack', 'expedition', 'espionage', 'harvest', 'colonize', 'deploy') then
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
      when f.mission = 'colonize' then 'colonize_return'
      when f.mission = 'deploy' then 'return'
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

revoke all on function public.send_deploy(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) from public, anon;
grant execute on function public.send_deploy(smallint, smallint, smallint, jsonb, bigint, bigint, bigint, smallint) to authenticated;

notify pgrst, 'reload schema';
