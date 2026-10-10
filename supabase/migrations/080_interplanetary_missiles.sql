-- Wiki IPM launch and ABM intercept. Missiles are not a fleet slot.

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
    'deploy',
    'mine',
    'mine_hold',
    'mine_return',
    'missile'
  ));

create or replace function private.ipm_range_systems(impulse integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(5 * greatest(coalesce(impulse, 0), 0) - 1, 0);
$$;

create or replace function private.ipm_system_distance(from_system integer, to_system integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(
    abs(coalesce(from_system, 0) - coalesce(to_system, 0)),
    499 - abs(coalesce(from_system, 0) - coalesce(to_system, 0))
  );
$$;

create or replace function private.ipm_flight_seconds(from_system integer, to_system integer, universe_speed integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(1, floor(
    (30 + 60 * private.ipm_system_distance(from_system, to_system))
    / greatest(coalesce(universe_speed, 1), 1)
  )::integer);
$$;

create or replace function private.ipm_target_hull(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'rocket_launcher' then 2000
    when 'light_laser' then 2000
    when 'heavy_laser' then 8000
    when 'ion_cannon' then 8000
    when 'gauss_cannon' then 35000
    when 'plasma_turret' then 100000
    when 'small_shield_dome' then 20000
    when 'large_shield_dome' then 100000
    when 'interplanetary_missile' then 15000
    else 0
  end;
$$;

revoke all on function private.ipm_range_systems(integer) from public, anon, authenticated;
revoke all on function private.ipm_system_distance(integer, integer) from public, anon, authenticated;
revoke all on function private.ipm_flight_seconds(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.ipm_target_hull(text) from public, anon, authenticated;

create or replace function private.apply_ipm_damage(
  p public.planets,
  hits integer,
  weapons_tech integer,
  armour_tech integer
)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  dmg numeric;
  id text;
  hull numeric;
  have integer;
  kill integer;
begin
  dmg := greatest(coalesce(hits, 0), 0) * 12000 * (1 + 0.1 * greatest(coalesce(weapons_tech, 0), 0));
  foreach id in array array[
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'plasma_turret',
    'small_shield_dome',
    'large_shield_dome',
    'interplanetary_missile'
  ]
  loop
    if dmg <= 0 then
      exit;
    end if;
    hull := private.ipm_target_hull(id) * (1 + 0.1 * greatest(coalesce(armour_tech, 0), 0));
    if hull <= 0 then
      continue;
    end if;
    have := private.defence_owned(p, id);
    if have <= 0 then
      continue;
    end if;
    kill := least(have, floor(dmg / hull)::integer);
    if kill > 0 then
      p := private.set_defence_owned(p, id, have - kill);
      dmg := dmg - kill * hull;
    end if;
  end loop;
  return p;
end;
$$;

revoke all on function private.apply_ipm_damage(public.planets, integer, integer, integer)
  from public, anon, authenticated;

create or replace function private.resolve_missile_arrival(f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  dest public.planets%rowtype;
  origin public.planets%rowtype;
  attacker public.empires%rowtype;
  defender public.empires%rowtype;
  before public.planets%rowtype;
  launched integer;
  intercepted integer;
  hits integer;
  abm integer;
  body text;
  guns text;
  attacker_name text;
begin
  launched := greatest(coalesce(f.raiders, 0), coalesce((f.composition->>'interplanetary_missile')::integer, 0));
  select * into dest from public.planets where id = f.dest_planet_id for update;
  if not found then
    update public.fleets
    set status = 'completed', report = 'The target is gone.'
    where id = f.id;
    return;
  end if;
  dest := private.catch_up_planet(dest, f.arrives_at);
  before := dest;
  select * into origin from public.planets where id = f.origin_planet_id;
  select * into attacker from public.empires where user_id = f.owner_id;
  if dest.owner_id is not null then
    select * into defender from public.empires where user_id = dest.owner_id;
  end if;
  select coalesce(pr.display_name, 'A commander') into attacker_name
  from public.profiles pr
  where pr.user_id = f.owner_id;

  abm := greatest(coalesce(dest.antiballistic_missile, 0), 0);
  intercepted := least(launched, abm);
  hits := launched - intercepted;
  dest.antiballistic_missile := abm - intercepted;
  dest := private.apply_ipm_damage(
    dest,
    hits,
    coalesce(attacker.weapons_tech, 0),
    coalesce(defender.armour_tech, 0)
  );
  dest.last_harvested_at := f.arrives_at;
  perform private.persist_planet(dest);

  guns := private.lost_guns_text(before, dest);
  body := concat_ws(
    ' ',
    format(
      '%s interplanetary missile%s from %s at [%s:%s:%s] struck %s [%s:%s:%s].',
      launched,
      case when launched = 1 then '' else 's' end,
      coalesce(attacker_name, 'A commander'),
      coalesce(origin.galaxy, dest.galaxy),
      coalesce(origin.system, dest.system),
      coalesce(origin.slot, dest.slot),
      dest.name,
      dest.galaxy,
      dest.system,
      dest.slot
    ),
    case
      when intercepted > 0 then format(
        '%s anti-ballistic missile%s intercepted %s inbound.',
        intercepted,
        case when intercepted = 1 then '' else 's' end,
        intercepted
      )
      else 'No anti-ballistic missiles intercepted the strike.'
    end,
    case
      when hits < 1 then 'No missiles reached the guns.'
      when guns is not null and guns <> '' then format('Destroyed: %s.', guns)
      else 'The missiles hit but found no guns left to wreck.'
    end
  );

  update public.fleets
  set status = 'completed', report = body
  where id = f.id;

  if f.owner_id is not null then
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (f.owner_id, 'Missile strike', body, 0, 0);
  end if;
  if dest.owner_id is not null and dest.owner_id is distinct from f.owner_id then
    insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
    values (dest.owner_id, 'Missile strike', body, 0, 0);
  end if;
end;
$$;

revoke all on function private.resolve_missile_arrival(public.fleets) from public, anon, authenticated;

create or replace function private.resolve_due_missiles(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  f public.fleets%rowtype;
begin
  loop
    select * into f
    from public.fleets
    where status = 'en_route'
      and arrives_at <= at
      and mission = 'missile'
      and (
        owner_id = uid
        or dest_planet_id in (select id from public.planets where owner_id = uid)
      )
    order by arrives_at
    limit 1
    for update skip locked;
    exit when not found;
    perform private.resolve_missile_arrival(f);
  end loop;
end;
$$;

revoke all on function private.resolve_due_missiles(uuid, timestamptz) from public, anon, authenticated;

do $$
begin
  if to_regprocedure('private.catch_up_pre_missile(uuid, timestamptz)') is null then
    alter function private.catch_up(uuid, timestamptz) rename to catch_up_pre_missile;
  end if;
end $$;

create or replace function private.catch_up(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.resolve_due_missiles(uid, at);
  perform private.catch_up_pre_missile(uid, at);
end;
$$;

revoke all on function private.catch_up_pre_missile(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.catch_up(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.send_ipm(
  p_galaxy integer,
  p_system integer,
  p_slot integer,
  p_missiles integer
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
  missiles integer := greatest(coalesce(p_missiles, 0), 0);
  range integer;
  systems integer;
  flight integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if missiles < 1 then
    raise exception 'Launch at least one interplanetary missile.';
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
    raise exception 'Cannot strike your own planet.';
  end if;
  if dest.galaxy is distinct from origin.galaxy then
    raise exception 'Interplanetary missiles stay in this galaxy.';
  end if;
  range := private.ipm_range_systems(e.impulse_drive);
  systems := private.ipm_system_distance(origin.system, dest.system);
  if systems > range then
    raise exception 'Impulse drive range is % systems.', range;
  end if;
  if origin.interplanetary_missile < missiles then
    raise exception 'Not enough interplanetary missiles.';
  end if;

  flight := private.ipm_flight_seconds(origin.system, dest.system, coalesce(e.economy_speed, 1));

  update public.planets
  set interplanetary_missile = origin.interplanetary_missile - missiles
  where id = origin.id;

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
    created_at,
    composition
  )
  values (
    uid,
    origin.id,
    dest.id,
    dest.galaxy,
    dest.system,
    dest.slot,
    missiles,
    'missile',
    at + make_interval(secs => flight),
    at,
    jsonb_build_object('interplanetary_missile', missiles)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.send_ipm(integer, integer, integer, integer) from public, anon;
grant execute on function public.send_ipm(integer, integer, integer, integer) to authenticated;

notify pgrst, 'reload schema';
