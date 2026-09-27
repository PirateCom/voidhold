-- Attack mission: flyable fleets raid player planets or ownerless worlds.
-- Combat is six rounds, shields regen, rapid fire uses the wiki values, and a win
-- plunders at most half of each resource. Ownerless planets keep a garrison jsonb
-- so later NPC worlds can fight with the same resolver.

alter table public.planets
  add column if not exists garrison jsonb not null default '{}'::jsonb;

alter table public.fleets
  add column if not exists flight_seconds integer;

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
      and pg_get_constraintdef(con.oid) ilike '%raiders%'
  loop
    execute format('alter table public.fleets drop constraint %I', c);
  end loop;
end
$$;

alter table public.fleets
  add constraint fleets_raiders_check check (raiders >= 0);

create index if not exists fleets_attack_window_idx
  on public.fleets (owner_id, dest_planet_id, created_at);

create or replace function private.ship_speed(id text, impulse integer, hyperspace integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
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
  end;
$$;

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
    when 'espionage_probe' then 1
    when 'reaper' then 1100
    when 'pathfinder' then 300
    else 0
  end;
$$;

create or replace function private.rapid_fire(attacker text, target text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when attacker = 'heavy_fighter' and target = 'small_cargo' then 3
    when attacker = 'cruiser' and target = 'light_fighter' then 6
    when attacker = 'cruiser' and target = 'rocket_launcher' then 10
    when attacker = 'battleship' and target = 'pathfinder' then 5
    when attacker = 'battlecruiser' and target = 'small_cargo' then 3
    when attacker = 'battlecruiser' and target = 'large_cargo' then 3
    when attacker = 'battlecruiser' and target = 'heavy_fighter' then 4
    when attacker = 'battlecruiser' and target = 'cruiser' then 4
    when attacker = 'battlecruiser' and target = 'battleship' then 7
    when attacker = 'battlecruiser' and target = 'espionage_probe' then 44
    when attacker = 'bomber' and target = 'rocket_launcher' then 20
    when attacker = 'bomber' and target = 'light_laser' then 20
    when attacker = 'bomber' and target = 'heavy_laser' then 10
    when attacker = 'bomber' and target = 'ion_cannon' then 10
    when attacker = 'bomber' and target = 'gauss_cannon' then 5
    when attacker = 'bomber' and target = 'plasma_turret' then 5
    when attacker = 'destroyer' and target = 'battlecruiser' then 2
    when attacker = 'destroyer' and target = 'light_laser' then 10
    when attacker = 'deathstar' and target = 'espionage_probe' then 1250
    when attacker = 'deathstar' and target = 'solar_satellite' then 1250
    when attacker = 'deathstar' and target = 'crawler' then 1250
    when attacker = 'deathstar' and target = 'small_cargo' then 250
    when attacker = 'deathstar' and target = 'large_cargo' then 250
    when attacker = 'deathstar' and target = 'colony_ship' then 250
    when attacker = 'deathstar' and target = 'recycler' then 250
    when attacker = 'deathstar' and target = 'light_fighter' then 200
    when attacker = 'deathstar' and target = 'rocket_launcher' then 200
    when attacker = 'deathstar' and target = 'light_laser' then 200
    when attacker = 'deathstar' and target = 'heavy_fighter' then 100
    when attacker = 'deathstar' and target = 'heavy_laser' then 100
    when attacker = 'deathstar' and target = 'ion_cannon' then 100
    when attacker = 'deathstar' and target = 'gauss_cannon' then 50
    when attacker = 'deathstar' and target = 'cruiser' then 33
    when attacker = 'deathstar' and target = 'battleship' then 30
    when attacker = 'deathstar' and target = 'reaper' then 30
    when attacker = 'deathstar' and target = 'bomber' then 25
    when attacker = 'deathstar' and target = 'battlecruiser' then 15
    when attacker = 'deathstar' and target = 'pathfinder' then 10
    when attacker = 'deathstar' and target = 'destroyer' then 5
    when attacker = 'reaper' and target = 'battleship' then 7
    when attacker = 'reaper' and target = 'bomber' then 4
    when attacker = 'reaper' and target = 'destroyer' then 3
    when attacker = 'pathfinder' and target = 'cruiser' then 3
    when attacker = 'pathfinder' and target = 'light_fighter' then 3
    when attacker = 'pathfinder' and target = 'heavy_fighter' then 2
    when attacker = 'ion_cannon' and target = 'reaper' then 2
    when target in ('espionage_probe', 'solar_satellite', 'crawler')
      and attacker in (
        'light_fighter', 'heavy_fighter', 'cruiser', 'battleship', 'battlecruiser', 'bomber',
        'destroyer', 'small_cargo', 'large_cargo', 'colony_ship', 'recycler', 'reaper', 'pathfinder'
      )
    then 5
    else 1
  end;
$$;

create or replace function private.unit_label(id text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'light_fighter' then 'Light fighter'
    when 'heavy_fighter' then 'Heavy fighter'
    when 'cruiser' then 'Cruiser'
    when 'battleship' then 'Battleship'
    when 'battlecruiser' then 'Battlecruiser'
    when 'bomber' then 'Bomber'
    when 'destroyer' then 'Destroyer'
    when 'deathstar' then 'Deathstar'
    when 'small_cargo' then 'Small cargo'
    when 'large_cargo' then 'Large cargo'
    when 'colony_ship' then 'Colony ship'
    when 'recycler' then 'Recycler'
    when 'espionage_probe' then 'Espionage probe'
    when 'reaper' then 'Reaper'
    when 'pathfinder' then 'Pathfinder'
    when 'crawler' then 'Crawler'
    when 'solar_satellite' then 'Solar satellite'
    when 'small_shield_dome' then 'Small shield dome'
    when 'large_shield_dome' then 'Large shield dome'
    when 'rocket_launcher' then 'Rocket launcher'
    when 'light_laser' then 'Light laser turret'
    when 'heavy_laser' then 'Heavy laser turret'
    when 'gauss_cannon' then 'Gaussian cannon turret'
    when 'ion_cannon' then 'Ion cannon'
    when 'plasma_turret' then 'Plasma turret'
    else id
  end;
$$;

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
    when 'espionage_probe' then 5
    when 'reaper' then 10000
    when 'pathfinder' then 10000
    else 0
  end;
$$;

create or replace function private.combat_stats(id text)
returns table (attack numeric, shield numeric, hull numeric, is_defense boolean)
language sql
immutable
set search_path = ''
as $$
  select stats.attack, stats.shield, stats.hull, stats.is_defense
  from (
    select
      case id
        when 'light_fighter' then 50
        when 'heavy_fighter' then 150
        when 'cruiser' then 400
        when 'battleship' then 1000
        when 'battlecruiser' then 700
        when 'bomber' then 1000
        when 'destroyer' then 2000
        when 'deathstar' then 200000
        when 'small_cargo' then 5
        when 'large_cargo' then 5
        when 'colony_ship' then 50
        when 'recycler' then 1
        when 'espionage_probe' then 0.01
        when 'reaper' then 2800
        when 'pathfinder' then 200
        when 'crawler' then 1
        when 'solar_satellite' then 1
        when 'small_shield_dome' then 1
        when 'large_shield_dome' then 1
        when 'rocket_launcher' then 80
        when 'light_laser' then 100
        when 'heavy_laser' then 250
        when 'ion_cannon' then 150
        when 'gauss_cannon' then 1100
        when 'plasma_turret' then 3000
        else 0
      end as attack,
      case id
        when 'light_fighter' then 10
        when 'heavy_fighter' then 25
        when 'cruiser' then 50
        when 'battleship' then 200
        when 'battlecruiser' then 400
        when 'bomber' then 500
        when 'destroyer' then 500
        when 'deathstar' then 50000
        when 'small_cargo' then 10
        when 'large_cargo' then 25
        when 'colony_ship' then 100
        when 'recycler' then 10
        when 'espionage_probe' then 0.01
        when 'reaper' then 700
        when 'pathfinder' then 100
        when 'crawler' then 1
        when 'solar_satellite' then 1
        when 'small_shield_dome' then 2000
        when 'large_shield_dome' then 10000
        when 'rocket_launcher' then 20
        when 'light_laser' then 25
        when 'heavy_laser' then 100
        when 'ion_cannon' then 500
        when 'gauss_cannon' then 200
        when 'plasma_turret' then 300
        else 0
      end as shield,
      case id
        when 'light_fighter' then 4000
        when 'heavy_fighter' then 10000
        when 'cruiser' then 27000
        when 'battleship' then 60000
        when 'battlecruiser' then 70000
        when 'bomber' then 75000
        when 'destroyer' then 110000
        when 'deathstar' then 9000000
        when 'small_cargo' then 4000
        when 'large_cargo' then 12000
        when 'colony_ship' then 30000
        when 'recycler' then 16000
        when 'espionage_probe' then 1000
        when 'reaper' then 140000
        when 'pathfinder' then 23000
        when 'crawler' then 4000
        when 'solar_satellite' then 2000
        when 'small_shield_dome' then 20000
        when 'large_shield_dome' then 100000
        when 'rocket_launcher' then 2000
        when 'light_laser' then 2000
        when 'heavy_laser' then 8000
        when 'ion_cannon' then 8000
        when 'gauss_cannon' then 35000
        when 'plasma_turret' then 100000
        else 0
      end as hull,
      case
        when id in (
          'small_shield_dome', 'large_shield_dome', 'rocket_launcher', 'light_laser', 'heavy_laser',
          'ion_cannon', 'gauss_cannon', 'plasma_turret'
        ) then true
        else false
      end as is_defense
  ) stats
  where stats.hull > 0 or stats.attack > 0;
$$;

create or replace function private.plunder(capacity bigint, metal bigint, crystal bigint, deut bigint)
returns table (loot_ore bigint, loot_crystal bigint, loot_deuterium bigint)
language plpgsql
immutable
set search_path = ''
as $$
declare
  m bigint := floor(greatest(coalesce(metal, 0), 0)::numeric / 2)::bigint;
  c bigint := floor(greatest(coalesce(crystal, 0), 0)::numeric / 2)::bigint;
  d bigint := floor(greatest(coalesce(deut, 0), 0)::numeric / 2)::bigint;
  cap bigint := greatest(coalesce(capacity, 0), 0);
  n bigint;
begin
  loot_ore := 0;
  loot_crystal := 0;
  loot_deuterium := 0;
  n := least(m, greatest(0, floor(cap / 3.0)::bigint));
  loot_ore := loot_ore + n; m := m - n; cap := cap - n;
  n := least(c, greatest(0, floor(cap / 2.0)::bigint));
  loot_crystal := loot_crystal + n; c := c - n; cap := cap - n;
  n := least(d, cap);
  loot_deuterium := loot_deuterium + n; d := d - n; cap := cap - n;
  n := least(m, greatest(0, floor(cap / 2.0)::bigint));
  loot_ore := loot_ore + n; m := m - n; cap := cap - n;
  n := least(c, cap);
  loot_crystal := loot_crystal + n; c := c - n; cap := cap - n;
  n := least(m, cap);
  loot_ore := loot_ore + n; cap := cap - n;
  n := least(d, cap);
  loot_deuterium := loot_deuterium + n;
  return next;
end;
$$;

create or replace function private.lcg_step(seed bigint)
returns table (next_seed bigint, roll numeric)
language sql
immutable
set search_path = ''
as $$
  select stepped.next_seed, stepped.next_seed::numeric / 4294967296
  from (
    select mod(1664525::bigint * case when coalesce(seed, 0) <= 0 then 1 else seed end + 1013904223, 4294967296)::bigint as next_seed
  ) stepped;
$$;

create or replace function private.apply_volley(
  stack jsonb,
  shots integer,
  attack numeric,
  shield numeric,
  max_hull numeric
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  intact integer := coalesce((stack->>'intact')::integer, 0);
  wounded integer := case when coalesce((stack->>'wounded')::integer, 0) > 0 then 1 else 0 end;
  wounded_hull numeric := case when coalesce((stack->>'wounded')::integer, 0) > 0 then (stack->>'hull')::numeric else max_hull end;
  wounded_shield numeric := case when coalesce((stack->>'wounded')::integer, 0) > 0 then (stack->>'shield')::numeric else shield end;
  left_shots integer := greatest(coalesce(shots, 0), 0);
  need numeric;
  dealt numeric;
  hull_dmg numeric;
  killed integer;
begin
  if left_shots <= 0 or attack <= 0 or intact + wounded <= 0 then
    return stack;
  end if;
  if shield > 0 and attack < shield * 0.01 and (wounded = 0 or attack < wounded_shield * 0.01) then
    return stack;
  end if;

  if wounded = 1 then
    if wounded_hull <= 0 or (wounded_shield > 0 and attack < wounded_shield * 0.01) then
      left_shots := 0;
    else
      need := ceil((wounded_shield + wounded_hull) / attack);
      if left_shots >= need then
        left_shots := left_shots - need::integer;
        wounded := 0;
        wounded_hull := max_hull;
        wounded_shield := shield;
      else
        dealt := left_shots * attack;
        hull_dmg := greatest(0, dealt - wounded_shield);
        wounded_shield := greatest(0, wounded_shield - dealt);
        wounded_hull := greatest(0, wounded_hull - hull_dmg);
        left_shots := 0;
        if wounded_hull <= 0 then
          wounded := 0;
        end if;
      end if;
    end if;
  end if;

  if max_hull > 0 and not (shield > 0 and attack < shield * 0.01) and left_shots > 0 and intact > 0 then
    need := ceil((shield + max_hull) / attack);
    killed := least(intact, floor(left_shots / need)::integer);
    intact := intact - killed;
    left_shots := left_shots - (killed * need)::integer;
    if left_shots > 0 and intact > 0 then
      intact := intact - 1;
      dealt := left_shots * attack;
      hull_dmg := greatest(0, dealt - shield);
      wounded := 1;
      wounded_hull := greatest(0, max_hull - hull_dmg);
      wounded_shield := greatest(0, shield - dealt);
      if wounded_hull <= 0 then
        wounded := 0;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'intact', intact,
    'wounded', wounded,
    'hull', case when wounded = 1 then wounded_hull else max_hull end,
    'shield', case when wounded = 1 then wounded_shield else shield end
  );
end;
$$;

create or replace function private.scaled_profiles(counts jsonb, weapons integer, shielding integer, armour integer)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  profiles jsonb := '{}'::jsonb;
  rec record;
  stats record;
  scale_atk numeric := 1 + 0.1 * greatest(coalesce(weapons, 0), 0);
  scale_sh numeric := 1 + 0.1 * greatest(coalesce(shielding, 0), 0);
  scale_hu numeric := 1 + 0.1 * greatest(coalesce(armour, 0), 0);
begin
  for rec in
    select key, greatest(value::integer, 0) as n
    from jsonb_each_text(coalesce(counts, '{}'::jsonb))
  loop
    if rec.n <= 0 or rec.key in ('antiballistic_missile', 'interplanetary_missile') then
      continue;
    end if;
    select * into stats from private.combat_stats(rec.key);
    if not found then
      continue;
    end if;
    profiles := profiles || jsonb_build_object(
      rec.key,
      jsonb_build_object(
        'attack', stats.attack * scale_atk,
        'shield', stats.shield * scale_sh,
        'hull', stats.hull * scale_hu,
        'defense', stats.is_defense,
        'count', rec.n
      )
    );
  end loop;
  return profiles;
end;
$$;

create or replace function private.stacks_from_profiles(profiles jsonb)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(
    key,
    jsonb_build_object(
      'intact', (value->>'count')::integer,
      'wounded', 0,
      'hull', (value->>'hull')::numeric,
      'shield', (value->>'shield')::numeric
    )
  ), '{}'::jsonb)
  from jsonb_each(coalesce(profiles, '{}'::jsonb));
$$;

create or replace function private.force_alive(force jsonb)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from jsonb_each(coalesce(force, '{}'::jsonb)) s
    where coalesce((s.value->>'intact')::integer, 0) + case when coalesce((s.value->>'wounded')::integer, 0) > 0 then 1 else 0 end > 0
  );
$$;

create or replace function private.combat_shoot(shooters jsonb, targets jsonb, shooter_profiles jsonb, target_profiles jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  next_targets jsonb := coalesce(targets, '{}'::jsonb);
  shooter record;
  target text;
  target_stack jsonb;
  shots integer;
  count_n integer;
  atk numeric;
  shield numeric;
  hull numeric;
begin
  for shooter in
    select s.key as id
    from jsonb_each(coalesce(shooters, '{}'::jsonb)) s
    order by 1
  loop
    count_n := coalesce((shooters->shooter.id->>'intact')::integer, 0)
      + case when coalesce((shooters->shooter.id->>'wounded')::integer, 0) > 0 then 1 else 0 end;
    atk := coalesce((shooter_profiles->shooter.id->>'attack')::numeric, 0);
    if count_n <= 0 or atk <= 0 then
      continue;
    end if;
    select s.key into target
    from jsonb_each(coalesce(targets, '{}'::jsonb)) s
    where coalesce((s.value->>'intact')::integer, 0) + case when coalesce((s.value->>'wounded')::integer, 0) > 0 then 1 else 0 end > 0
    order by
      coalesce((s.value->>'intact')::numeric, 0) * coalesce((target_profiles->s.key->>'hull')::numeric, 0)
      + case when coalesce((s.value->>'wounded')::integer, 0) > 0 then coalesce((s.value->>'hull')::numeric, 0) else 0 end
      desc,
      s.key
    limit 1;
    if target is null then
      continue;
    end if;
    shots := count_n * private.rapid_fire(shooter.id, target);
    shield := coalesce((target_profiles->target->>'shield')::numeric, 0);
    hull := coalesce((target_profiles->target->>'hull')::numeric, 0);
    target_stack := coalesce(next_targets->target, targets->target);
    next_targets := jsonb_set(
      next_targets,
      array[target],
      private.apply_volley(target_stack, shots, atk, shield, hull)
    );
  end loop;
  return next_targets;
end;
$$;

create or replace function private.explode_force(force jsonb, profiles jsonb, seed bigint)
returns table (next_force jsonb, next_seed bigint)
language plpgsql
stable
set search_path = ''
as $$
declare
  result jsonb := '{}'::jsonb;
  unit record;
  wounded integer;
  hull numeric;
  max_hull numeric;
  stepped record;
begin
  next_seed := case when coalesce(seed, 0) <= 0 then 1 else seed end;
  for unit in
    select key as id, value as stack
    from jsonb_each(coalesce(force, '{}'::jsonb))
    order by 1
  loop
    wounded := case when coalesce((unit.stack->>'wounded')::integer, 0) > 0 then 1 else 0 end;
    hull := coalesce((unit.stack->>'hull')::numeric, 0);
    max_hull := coalesce((profiles->unit.id->>'hull')::numeric, 0);
    if wounded = 1 and max_hull > 0 and hull < max_hull * 0.7 then
      select * into stepped from private.lcg_step(next_seed);
      next_seed := stepped.next_seed;
      if stepped.roll < (1 - hull / max_hull) then
        wounded := 0;
        hull := max_hull;
      end if;
    end if;
    if coalesce((unit.stack->>'intact')::integer, 0) + wounded > 0 then
      result := result || jsonb_build_object(
        unit.id,
        jsonb_build_object(
          'intact', coalesce((unit.stack->>'intact')::integer, 0),
          'wounded', wounded,
          'hull', case when wounded = 1 then hull else max_hull end,
          'shield', coalesce((profiles->unit.id->>'shield')::numeric, 0)
        )
      );
    end if;
  end loop;
  next_force := result;
  return next;
end;
$$;

create or replace function private.survivor_counts(force jsonb)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(
    s.key,
    coalesce((s.value->>'intact')::integer, 0) + case when coalesce((s.value->>'wounded')::integer, 0) > 0 then 1 else 0 end
  ), '{}'::jsonb)
  from jsonb_each(coalesce(force, '{}'::jsonb)) s
  where coalesce((s.value->>'intact')::integer, 0) + case when coalesce((s.value->>'wounded')::integer, 0) > 0 then 1 else 0 end > 0;
$$;

create or replace function private.resolve_combat(
  attackers jsonb,
  defenders jsonb,
  attacker_weapons integer,
  attacker_shielding integer,
  attacker_armour integer,
  defender_weapons integer,
  defender_shielding integer,
  defender_armour integer,
  seed bigint
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  att_profiles jsonb := private.scaled_profiles(attackers, attacker_weapons, attacker_shielding, attacker_armour);
  def_profiles jsonb := private.scaled_profiles(defenders, defender_weapons, defender_shielding, defender_armour);
  att jsonb := private.stacks_from_profiles(att_profiles);
  def jsonb := private.stacks_from_profiles(def_profiles);
  rounds integer := 0;
  snapshot_att jsonb;
  snapshot_def jsonb;
  exploded record;
  outcome text;
  current_seed bigint := case when coalesce(seed, 0) <= 0 then 1 else seed end;
begin
  if not private.force_alive(att) or not private.force_alive(def) then
    outcome := case
      when private.force_alive(att) then 'attacker'
      when private.force_alive(def) then 'defender'
      else 'draw'
    end;
    return jsonb_build_object(
      'outcome', outcome,
      'rounds', 0,
      'attackers', private.survivor_counts(att),
      'defenders', private.survivor_counts(def),
      'seed', current_seed
    );
  end if;

  while rounds < 6 and private.force_alive(att) and private.force_alive(def) loop
    rounds := rounds + 1;
    snapshot_att := att;
    snapshot_def := def;
    def := private.combat_shoot(snapshot_att, snapshot_def, att_profiles, def_profiles);
    att := private.combat_shoot(snapshot_def, snapshot_att, def_profiles, att_profiles);
    select * into exploded from private.explode_force(att, att_profiles, current_seed);
    att := exploded.next_force;
    current_seed := exploded.next_seed;
    select * into exploded from private.explode_force(def, def_profiles, current_seed);
    def := exploded.next_force;
    current_seed := exploded.next_seed;
  end loop;

  outcome := case
    when private.force_alive(att) and not private.force_alive(def) then 'attacker'
    when private.force_alive(def) and not private.force_alive(att) then 'defender'
    else 'draw'
  end;
  return jsonb_build_object(
    'outcome', outcome,
    'rounds', rounds,
    'attackers', private.survivor_counts(att),
    'defenders', private.survivor_counts(def),
    'seed', current_seed
  );
end;
$$;

create or replace function private.assign_defence(p public.planets, id text, n integer)
returns public.planets
language plpgsql
immutable
set search_path = ''
as $$
begin
  n := greatest(coalesce(n, 0), 0);
  case id
    when 'small_shield_dome' then p.small_shield_dome := n;
    when 'large_shield_dome' then p.large_shield_dome := n;
    when 'rocket_launcher' then p.rocket_launcher := n;
    when 'light_laser' then p.light_laser := n;
    when 'heavy_laser' then p.heavy_laser := n;
    when 'ion_cannon' then p.ion_cannon := n;
    when 'gauss_cannon' then p.gauss_cannon := n;
    when 'plasma_turret' then p.plasma_turret := n;
    else
      null;
  end case;
  return p;
end;
$$;

create or replace function private.loss_line(initial jsonb, left_counts jsonb)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(string_agg(
      format('%s %s', (coalesce((initial->>unit_id)::integer, 0) - coalesce((left_counts->>unit_id)::integer, 0)), private.unit_label(unit_id)),
      ', ' order by unit_id
    ), ''),
    'none'
  )
  from jsonb_object_keys(coalesce(initial, '{}'::jsonb)) as t(unit_id)
  where coalesce((initial->>unit_id)::integer, 0) - coalesce((left_counts->>unit_id)::integer, 0) > 0;
$$;

-- True when the defender row is locked and the fleet should be retried.
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
  report text;
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
    defenders := coalesce(def.ships, '{}'::jsonb);
    if def.raiders > coalesce((defenders->>'small_cargo')::integer, 0) then
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

  report := format(
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
    new_ships := coalesce(def.ships, '{}'::jsonb);
    for rec in select key, value from jsonb_each(ship_survivors) loop
      new_ships := jsonb_set(new_ships, array[rec.key], rec.value, true);
    end loop;
    update public.empires
    set
      ships = new_ships,
      raiders = coalesce((new_ships->>'small_cargo')::integer, 0),
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
      report,
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
    set status = 'completed', raiders = 0, composition = '{}'::jsonb, report = report
    where id = f.id;
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (f.owner_id, format('Attack on %s', dest.name), report, 0, 0);
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
      report = report
    where id = f.id;
  end if;

  return false;
end;
$$;

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
    spd := private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive);
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
begin
  if p_raiders is null or p_raiders < 1 then
    raise exception 'Send at least one raider.';
  end if;
  return public.send_attack(p_galaxy, p_system, p_slot, jsonb_build_object('small_cargo', p_raiders), 100);
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

      if f.mission = 'return' and coalesce(f.composition, '{}'::jsonb) <> '{}'::jsonb then
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

revoke all on function public.send_attack(smallint, smallint, smallint, jsonb, smallint) from public, anon;
grant execute on function public.send_attack(smallint, smallint, smallint, jsonb, smallint) to authenticated;
grant execute on function public.send_raid(smallint, smallint, smallint, integer) to authenticated;

notify pgrst, 'reload schema';
