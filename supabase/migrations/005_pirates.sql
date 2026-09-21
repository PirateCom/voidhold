-- NPC pirate waves: 1–2 per real hour, more guns → more hulls. ATK/DEF combat.

alter table public.empires
  add column if not exists next_pirate_at timestamptz;

create or replace function private.defence_attack(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 0
    when 'large_shield_dome' then 0
    when 'rocket_launcher' then 8
    when 'light_laser' then 10
    when 'heavy_laser' then 25
    when 'ion_cannon' then 15
    when 'gauss_cannon' then 110
    else 0
  end;
$$;

create or replace function private.defence_hp(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 200
    when 'large_shield_dome' then 1000
    when 'rocket_launcher' then 20
    when 'light_laser' then 25
    when 'heavy_laser' then 90
    when 'ion_cannon' then 130
    when 'gauss_cannon' then 370
    else 0
  end;
$$;

create or replace function private.defence_units(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0)
       + greatest(coalesce(p.large_shield_dome, 0), 0)
       + greatest(coalesce(p.rocket_launcher, 0), 0)
       + greatest(coalesce(p.light_laser, 0), 0)
       + greatest(coalesce(p.heavy_laser, 0), 0)
       + greatest(coalesce(p.ion_cannon, 0), 0)
       + greatest(coalesce(p.gauss_cannon, 0), 0);
$$;

create or replace function private.planet_attack(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0) * 0
       + greatest(coalesce(p.large_shield_dome, 0), 0) * 0
       + greatest(coalesce(p.rocket_launcher, 0), 0) * 8
       + greatest(coalesce(p.light_laser, 0), 0) * 10
       + greatest(coalesce(p.heavy_laser, 0), 0) * 25
       + greatest(coalesce(p.ion_cannon, 0), 0) * 15
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 110;
$$;

create or replace function private.planet_defence(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(coalesce(p.small_shield_dome, 0), 0) * 200
       + greatest(coalesce(p.large_shield_dome, 0), 0) * 1000
       + greatest(coalesce(p.rocket_launcher, 0), 0) * 20
       + greatest(coalesce(p.light_laser, 0), 0) * 25
       + greatest(coalesce(p.heavy_laser, 0), 0) * 90
       + greatest(coalesce(p.ion_cannon, 0), 0) * 130
       + greatest(coalesce(p.gauss_cannon, 0), 0) * 370;
$$;

create or replace function private.pirate_interval_seconds(units integer)
returns integer
language plpgsql
volatile
set search_path = ''
as $$
declare
  per numeric;
  base numeric;
begin
  if coalesce(units, 0) <= 0 then
    per := 1;
  else
    per := least(2, 1 + units::numeric / 8);
  end if;
  base := 3600 / per;
  return greatest(900, floor(base * (0.85 + random() * 0.30)))::integer;
end;
$$;

create or replace function private.pirate_wave_size(units integer)
returns integer
language sql
volatile
set search_path = ''
as $$
  select greatest(1, coalesce(units, 0) + case when random() >= 0.5 then 1 else 0 end);
$$;

create or replace function private.set_defence_owned(p public.planets, id text, n integer)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  qty integer := greatest(coalesce(n, 0), 0);
begin
  if id = 'small_shield_dome' then
    p.small_shield_dome := least(qty, 1);
  elsif id = 'large_shield_dome' then
    p.large_shield_dome := least(qty, 1);
  elsif id = 'rocket_launcher' then
    p.rocket_launcher := qty;
  elsif id = 'light_laser' then
    p.light_laser := qty;
  elsif id = 'heavy_laser' then
    p.heavy_laser := qty;
  elsif id = 'ion_cannon' then
    p.ion_cannon := qty;
  elsif id = 'gauss_cannon' then
    p.gauss_cannon := qty;
  end if;
  return p;
end;
$$;

create or replace function private.apply_pirate_damage(p public.planets, damage integer)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  remaining integer := greatest(coalesce(damage, 0), 0);
  id text;
  hp integer;
begin
  foreach id in array array[
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'small_shield_dome',
    'large_shield_dome'
  ] loop
    hp := private.defence_hp(id);
    if hp <= 0 then
      continue;
    end if;
    while private.defence_owned(p, id) > 0 and remaining >= hp loop
      p := private.set_defence_owned(p, id, private.defence_owned(p, id) - 1);
      remaining := remaining - hp;
    end loop;
  end loop;
  return p;
end;
$$;

create or replace function private.lost_guns_text(before public.planets, afterp public.planets)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  parts text[] := '{}';
  n integer;
begin
  n := before.rocket_launcher - afterp.rocket_launcher;
  if n > 0 then
    parts := array_append(parts, format('%s rocket launcher%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.light_laser - afterp.light_laser;
  if n > 0 then
    parts := array_append(parts, format('%s light laser%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.heavy_laser - afterp.heavy_laser;
  if n > 0 then
    parts := array_append(parts, format('%s heavy laser%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.ion_cannon - afterp.ion_cannon;
  if n > 0 then
    parts := array_append(parts, format('%s ion cannon%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.gauss_cannon - afterp.gauss_cannon;
  if n > 0 then
    parts := array_append(parts, format('%s gaussian cannon%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.small_shield_dome - afterp.small_shield_dome;
  if n > 0 then
    parts := array_append(parts, format('%s small shield dome%s', n, case when n = 1 then '' else 's' end));
  end if;
  n := before.large_shield_dome - afterp.large_shield_dome;
  if n > 0 then
    parts := array_append(parts, format('%s large shield dome%s', n, case when n = 1 then '' else 's' end));
  end if;
  if cardinality(parts) = 0 then
    return 'no guns';
  end if;
  return array_to_string(parts, ', ');
end;
$$;

create or replace function private.resolve_pirate_wave(p public.planets, uid uuid, at timestamptz)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  units integer;
  ships integer;
  planet_atk integer;
  planet_def integer;
  pirate_atk integer;
  pirate_def integer;
  pirates_lost integer;
  pirates_left integer;
  before public.planets;
  loot_ore bigint := 0;
  loot_crystal bigint := 0;
  held boolean;
  body text;
begin
  before := p;
  units := private.defence_units(p);
  ships := private.pirate_wave_size(units);
  planet_atk := private.planet_attack(p);
  planet_def := private.planet_defence(p);
  pirate_atk := ships * 10;
  pirate_def := ships * 20;
  pirates_lost := least(ships, floor(greatest(planet_atk, 0)::numeric / 20)::integer);
  pirates_left := ships - pirates_lost;
  p := private.apply_pirate_damage(p, pirate_atk);
  held := pirates_left <= 0;
  if not held then
    select h.loot_ore, h.loot_crystal
      into loot_ore, loot_crystal
    from private.raid_haul(p.ore, p.crystal, pirates_left * 800) as h;
    p.ore := p.ore - loot_ore;
    p.crystal := p.crystal - loot_crystal;
  end if;
  body := format(
    '%s pirate hull%s ATK %s DEF %s. Planet ATK %s DEF %s. Destroyed %s pirate%s. Guns lost: %s. %s',
    ships,
    case when ships = 1 then '' else 's' end,
    pirate_atk,
    pirate_def,
    planet_atk,
    planet_def,
    pirates_lost,
    case when pirates_lost = 1 then '' else 's' end,
    private.lost_guns_text(before, p),
    case
      when held then 'The hold held.'
      else format('Looted %s ore, %s crystal.', loot_ore, loot_crystal)
    end
  );
  insert into public.battle_reports (user_id, created_at, title, body, loot_ore, loot_crystal)
  values (
    uid,
    at,
    case when held then 'Pirate raid repelled' else 'Pirate raid' end,
    body,
    loot_ore,
    loot_crystal
  );
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
  loot_ore bigint;
  loot_crystal bigint;
  cargo_left bigint;
  flight integer;
  waves integer;
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e.propulsion_level := e.propulsion_level + 1;
    e.research_completes_at := null;
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
      flight := private.flight_seconds(origin.system, origin.slot, dest.system, dest.slot, e.propulsion_level);

      update public.fleets
      set
        mission = 'return',
        cargo_ore = loot_ore,
        cargo_crystal = loot_crystal,
        arrives_at = f.arrives_at + make_interval(secs => flight),
        report = format('Raid on %s: +%s ore, +%s crystal.', dest.name, loot_ore, loot_crystal)
      where id = f.id;
    else
      select * into origin from public.planets where id = f.origin_planet_id for update;
      origin := private.catch_up_planet(origin, f.arrives_at);
      origin.ore := least(private.storage_cap(origin.ore_mine), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_mine), origin.crystal + f.cargo_crystal);
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
        'Fleet returned',
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
    raiders = e.raiders,
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    research_completes_at = e.research_completes_at,
    next_pirate_at = e.next_pirate_at
  where user_id = uid;
end;
$$;

create or replace function public.spawn_pirates()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home public.planets%rowtype;
  nxt timestamptz;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);

  select * into home from public.planets where owner_id = uid order by id limit 1 for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  home := private.resolve_pirate_wave(home, uid, at);
  nxt := at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
  perform private.persist_planet(home);

  update public.empires
  set next_pirate_at = nxt
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
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
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    power_plant = 1,
    upgrade_building = null,
    upgrade_completes_at = null,
    small_shield_dome = 0,
    large_shield_dome = 0,
    rocket_launcher = 0,
    light_laser = 0,
    heavy_laser = 0,
    ion_cannon = 0,
    gauss_cannon = 0,
    defence_building = null,
    defences_queued = 0,
    defence_completes_at = null
  where owner_id = uid;

  update public.empires
  set
    propulsion_level = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function private.defence_attack(text) from public, anon, authenticated;
revoke all on function private.defence_hp(text) from public, anon, authenticated;
revoke all on function private.defence_units(public.planets) from public, anon, authenticated;
revoke all on function private.planet_attack(public.planets) from public, anon, authenticated;
revoke all on function private.planet_defence(public.planets) from public, anon, authenticated;
revoke all on function private.pirate_interval_seconds(integer) from public, anon, authenticated;
revoke all on function private.pirate_wave_size(integer) from public, anon, authenticated;
revoke all on function private.set_defence_owned(public.planets, text, integer) from public, anon, authenticated;
revoke all on function private.apply_pirate_damage(public.planets, integer) from public, anon, authenticated;
revoke all on function private.lost_guns_text(public.planets, public.planets) from public, anon, authenticated;
revoke all on function private.resolve_pirate_wave(public.planets, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.catch_up(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.spawn_pirates() from public, anon;
grant execute on function public.spawn_pirates() to authenticated;
revoke all on function public.reset_empire() from public, anon;
grant execute on function public.reset_empire() to authenticated;

notify pgrst, 'reload schema';
