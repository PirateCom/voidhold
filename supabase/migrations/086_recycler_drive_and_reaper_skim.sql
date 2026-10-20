-- 086: Recycler engine upgrades (Impulse 17 -> 4000 speed / 600 fuel, Hyperspace 15 -> 6000 speed / 900 fuel)
-- and Reaper 25% post-battle debris auto-skimming.

create or replace function private.ship_fuel(id text, impulse integer, hyperspace integer default 0)
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
    when 'recycler' then
      case
        when coalesce(hyperspace, 0) >= 15 then 900
        when coalesce(impulse, 0) >= 17 then 600
        else 300
      end
    when 'mining_barge' then 40
    when 'espionage_probe' then 1
    when 'reaper' then 1100
    when 'pathfinder' then 300
    else 0
  end;
$$;

revoke all on function private.ship_fuel(text, integer, integer) from public, anon, authenticated;

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
        when 'recycler' then
          case
            when coalesce(hyperspace, 0) >= 15 then 6000
            when coalesce(impulse, 0) >= 17 then 4000
            else 2000
          end
        when 'mining_barge' then 4000
        when 'espionage_probe' then 100000000
        when 'reaper' then 7000
        when 'pathfinder' then 12000
        else 0
      end as speed,
      case
        when id = 'small_cargo' and coalesce(impulse, 0) >= 5 then 'impulse'
        when id = 'bomber' and coalesce(hyperspace, 0) >= 8 then 'hyperspace'
        when id = 'recycler' and coalesce(hyperspace, 0) >= 15 then 'hyperspace'
        when id = 'recycler' and coalesce(impulse, 0) >= 17 then 'impulse'
        when id in ('light_fighter', 'large_cargo', 'recycler', 'mining_barge', 'espionage_probe', 'small_cargo') then 'combustion'
        when id in ('heavy_fighter', 'cruiser', 'colony_ship', 'bomber') then 'impulse'
        when id in ('battleship', 'battlecruiser', 'destroyer', 'deathstar', 'reaper', 'pathfinder') then 'hyperspace'
        else 'combustion'
      end as drive
  ) base;
$$;

revoke all on function private.ship_speed(text, integer, integer, integer) from public, anon, authenticated;

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
  surviving_reapers integer := 0;
  reaper_cap bigint := 0;
  free_cargo bigint := 0;
  skim_cap bigint := 0;
  max_skim_ore bigint := 0;
  max_skim_crystal bigint := 0;
  max_skim_total bigint := 0;
  skim_ore bigint := 0;
  skim_crystal bigint := 0;
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

  -- Reaper 25% post-battle debris auto-skimming
  surviving_reapers := greatest(coalesce((survivors->>'reaper')::integer, 0), 0);
  if surviving_reapers > 0 and (debris_ore + debris_crystal) > 0 then
    reaper_cap := surviving_reapers::bigint * private.unit_cargo('reaper');
    free_cargo := greatest(0, cargo - (coalesce(loot.loot_ore, 0) + coalesce(loot.loot_crystal, 0) + coalesce(loot.loot_deuterium, 0)));
    skim_cap := least(reaper_cap, free_cargo);
    max_skim_ore := floor(debris_ore * 0.25)::bigint;
    max_skim_crystal := floor(debris_crystal * 0.25)::bigint;
    max_skim_total := max_skim_ore + max_skim_crystal;
    if skim_cap > 0 and max_skim_total > 0 then
      if skim_cap >= max_skim_total then
        skim_ore := max_skim_ore;
        skim_crystal := max_skim_crystal;
      else
        skim_ore := least(max_skim_ore, floor((skim_cap::numeric * max_skim_ore) / max_skim_total)::bigint);
        skim_crystal := least(max_skim_crystal, skim_cap - skim_ore);
      end if;
      debris_ore := debris_ore - skim_ore;
      debris_crystal := debris_crystal - skim_crystal;
    end if;
  end if;

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
    coalesce(loot.loot_ore, 0) + skim_ore,
    coalesce(loot.loot_crystal, 0) + skim_crystal,
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
      coalesce(loot.loot_ore, 0) + skim_ore,
      coalesce(loot.loot_crystal, 0) + skim_crystal
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
      cargo_ore = coalesce(loot.loot_ore, 0) + skim_ore,
      cargo_crystal = coalesce(loot.loot_crystal, 0) + skim_crystal,
      cargo_deuterium = coalesce(loot.loot_deuterium, 0),
      arrives_at = f.arrives_at + make_interval(secs => flight),
      report = report_text
    where id = f.id;
  end if;

  return false;
end;
$$;

revoke all on function private.resolve_attack_arrival(uuid, public.empires, public.fleets) from public, anon, authenticated;

notify pgrst, 'reload schema';
