-- Voidhold v1 schema. RLS on. Mutations go through SECURITY DEFINER RPCs.
-- Formulas must match src/lib/game/catalog.ts.

create schema if not exists private;

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Commander',
  created_at timestamptz not null default now()
);

create table public.planets (
  id bigint generated always as identity primary key,
  owner_id uuid references public.profiles (user_id) on delete cascade,
  galaxy smallint not null default 1 check (galaxy = 1),
  system smallint not null check (system between 1 and 10),
  slot smallint not null check (slot between 1 and 10),
  name text not null default 'Homeworld',
  ore bigint not null default 0 check (ore >= 0),
  crystal bigint not null default 0 check (crystal >= 0),
  last_harvested_at timestamptz not null default now(),
  ore_mine smallint not null default 1 check (ore_mine >= 0),
  crystal_mine smallint not null default 1 check (crystal_mine >= 0),
  power_plant smallint not null default 1 check (power_plant >= 0),
  upgrade_building text
    check (upgrade_building is null or upgrade_building in ('ore_mine', 'crystal_mine', 'power_plant')),
  upgrade_completes_at timestamptz,
  unique (galaxy, system, slot)
);

create unique index planets_one_home_per_user_idx
  on public.planets (owner_id)
  where owner_id is not null;

create index planets_owner_id_idx on public.planets (owner_id);

create table public.empires (
  user_id uuid primary key references public.profiles (user_id) on delete cascade,
  home_planet_id bigint not null references public.planets (id),
  propulsion_level smallint not null default 0 check (propulsion_level >= 0),
  raiders integer not null default 0 check (raiders >= 0),
  raiders_queued integer not null default 0 check (raiders_queued >= 0),
  raider_completes_at timestamptz,
  research_completes_at timestamptz,
  created_at timestamptz not null default now()
);

create index empires_home_planet_id_idx on public.empires (home_planet_id);

create table public.fleets (
  id bigint generated always as identity primary key,
  owner_id uuid not null references public.profiles (user_id) on delete cascade,
  origin_planet_id bigint not null references public.planets (id),
  dest_planet_id bigint not null references public.planets (id),
  raiders integer not null check (raiders > 0),
  mission text not null check (mission in ('attack', 'return')),
  arrives_at timestamptz not null,
  cargo_ore bigint not null default 0 check (cargo_ore >= 0),
  cargo_crystal bigint not null default 0 check (cargo_crystal >= 0),
  status text not null default 'en_route' check (status in ('en_route', 'completed')),
  report text,
  created_at timestamptz not null default now()
);

create index fleets_owner_id_idx on public.fleets (owner_id);
create index fleets_dest_planet_id_idx on public.fleets (dest_planet_id);
create index fleets_origin_planet_id_idx on public.fleets (origin_planet_id);
create index fleets_due_idx on public.fleets (arrives_at)
  where status = 'en_route';

create table public.battle_reports (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  title text not null,
  body text not null,
  loot_ore bigint not null default 0,
  loot_crystal bigint not null default 0
);

create index battle_reports_user_id_idx on public.battle_reports (user_id);

alter table public.profiles enable row level security;
alter table public.planets enable row level security;
alter table public.empires enable row level security;
alter table public.fleets enable row level security;
alter table public.battle_reports enable row level security;
alter table public.profiles force row level security;
alter table public.planets force row level security;
alter table public.empires force row level security;
alter table public.fleets force row level security;
alter table public.battle_reports force row level security;

create policy profiles_select
  on public.profiles
  for select
  to authenticated
  using (true);

create policy planets_select
  on public.planets
  for select
  to authenticated
  using (true);

create policy empires_select_own
  on public.empires
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy fleets_select_own
  on public.fleets
  for select
  to authenticated
  using ((select auth.uid()) = owner_id);

create policy reports_select_own
  on public.battle_reports
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant usage on schema public to authenticated, anon;
grant select on table public.profiles to authenticated;
grant select (id, owner_id, galaxy, system, slot, name) on table public.planets to authenticated;
grant select on table public.empires to authenticated;
grant select on table public.fleets to authenticated;
grant select on table public.battle_reports to authenticated;
revoke all on table public.profiles from anon;
revoke all on table public.planets from anon;
revoke all on table public.empires from anon;
revoke all on table public.fleets from anon;
revoke all on table public.battle_reports from anon;

-- Formulas (keep in sync with src/lib/game/catalog.ts)

create or replace function private.game_hour_seconds()
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 60::numeric;
$$;

create or replace function private.mine_prod_per_hour(level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when level <= 0 then 0 else floor(30 * level * power(1.1, level)) end;
$$;

create or replace function private.crystal_prod_per_hour(level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when level <= 0 then 0 else floor(20 * level * power(1.1, level)) end;
$$;

create or replace function private.power_output(level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when level <= 0 then 0 else floor(20 * level * power(1.1, level)) end;
$$;

create or replace function private.mine_energy_drain(level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when level <= 0 then 0 else floor(10 * level * power(1.1, level)) end;
$$;

create or replace function private.energy_factor(ore_mine integer, crystal_mine integer, power_plant integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when private.mine_energy_drain(ore_mine) + private.mine_energy_drain(crystal_mine) <= 0 then 1
    else least(
      1::numeric,
      private.power_output(power_plant)
        / (private.mine_energy_drain(ore_mine) + private.mine_energy_drain(crystal_mine))
    )
  end;
$$;

create or replace function private.storage_cap(mine_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select (10000 + 5000 * greatest(mine_level, 0))::bigint;
$$;

create or replace function private.building_cost_ore(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(60 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(48 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(75 * power(1.5, current_level))::bigint
    else 0
  end;
$$;

create or replace function private.building_cost_crystal(building text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case building
    when 'ore_mine' then floor(15 * power(1.5, current_level))::bigint
    when 'crystal_mine' then floor(24 * power(1.5, current_level))::bigint
    when 'power_plant' then floor(30 * power(1.5, current_level))::bigint
    else 0
  end;
$$;

create or replace function private.building_time_seconds(current_level integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select floor(20 * power(1.5, current_level))::integer;
$$;

create or replace function private.research_cost_ore(current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor(200 * power(2, current_level))::bigint;
$$;

create or replace function private.research_cost_crystal(current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor(400 * power(2, current_level))::bigint;
$$;

create or replace function private.research_time_seconds(current_level integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select floor(45 * power(1.5, current_level))::integer;
$$;

create or replace function private.flight_seconds(
  from_system integer,
  from_slot integer,
  to_system integer,
  to_slot integer,
  propulsion_level integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    15,
    floor(
      (20 + 12 * greatest(abs(from_system - to_system) + abs(from_slot - to_slot), 1))
      / (1 + 0.1 * propulsion_level)
    )
  )::integer;
$$;

create or replace function private.tick_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
stable
set search_path = ''
as $$
declare
  elapsed numeric;
  factor numeric;
  ore_add bigint;
  crystal_add bigint;
begin
  elapsed := greatest(0, extract(epoch from (at - p.last_harvested_at)));
  factor := private.energy_factor(p.ore_mine, p.crystal_mine, p.power_plant);
  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  p.ore := least(private.storage_cap(p.ore_mine), p.ore + ore_add);
  p.crystal := least(private.storage_cap(p.crystal_mine), p.crystal + crystal_add);
  p.last_harvested_at := at;
  return p;
end;
$$;

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
    last_harvested_at = p.last_harvested_at,
    ore_mine = p.ore_mine,
    crystal_mine = p.crystal_mine,
    power_plant = p.power_plant,
    upgrade_building = p.upgrade_building,
    upgrade_completes_at = p.upgrade_completes_at
  where id = p.id;
end;
$$;

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
    elsif p.upgrade_building = 'power_plant' then
      p.power_plant := p.power_plant + 1;
    end if;
    p.upgrade_building := null;
    p.upgrade_completes_at := null;
  end if;
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
  loot_ore bigint;
  loot_crystal bigint;
  cargo_left bigint;
  flight integer;
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
      loot_ore := least(cargo_left, floor(dest.ore * 0.5))::bigint;
      cargo_left := cargo_left - loot_ore;
      loot_crystal := least(cargo_left, floor(dest.crystal * 0.5))::bigint;
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
  perform private.persist_planet(home);

  update public.empires
  set
    propulsion_level = e.propulsion_level,
    raiders = e.raiders,
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    research_completes_at = e.research_completes_at
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
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', dp.name,
        'dest_system', dp.system,
        'dest_slot', dp.slot,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'status', f.status,
        'report', f.report
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      join public.planets dp on dp.id = f.dest_planet_id
      where f.owner_id = uid and f.status = 'en_route'
    ),
    'galaxy', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'system', g.system,
        'slot', g.slot,
        'kind', case
          when g.planet_id is null then 'empty'
          when g.owner_id = uid then 'home'
          when g.owner_id is not null then 'player'
          else 'npc'
        end,
        'planet_id', g.planet_id,
        'name', g.name,
        'owner_name', g.owner_name
      ) order by g.system, g.slot), '[]'::jsonb)
      from (
        select
          sys as system,
          sl as slot,
          pl.id as planet_id,
          pl.owner_id,
          pl.name,
          pf.display_name as owner_name
        from generate_series(1, 10) as sys
        cross join generate_series(1, 10) as sl
        left join public.planets pl
          on pl.galaxy = 1 and pl.system = sys and pl.slot = sl
        left join public.profiles pf on pf.user_id = pl.owner_id
      ) g
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
  where e.user_id = uid;

  return result;
end;
$$;

create or replace function private.bootstrap_empire(uid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sys integer;
  sl integer;
  planet_id bigint;
  display text;
begin
  if exists (select 1 from public.empires where user_id = uid) then
    return private.empire_state_json(uid, timezone('utc', now()));
  end if;

  select coalesce(split_part(u.email, '@', 1), 'Commander')
  into display
  from auth.users u
  where u.id = uid;

  insert into public.profiles (user_id, display_name)
  values (uid, coalesce(nullif(display, ''), 'Commander'))
  on conflict (user_id) do nothing;

  select gs, slt
  into sys, sl
  from generate_series(1, 10) gs
  cross join generate_series(1, 10) slt
  where not exists (
    select 1 from public.planets p
    where p.galaxy = 1 and p.system = gs and p.slot = slt
  )
  order by gs, slt
  limit 1;

  if sys is null then
    raise exception 'The void is full. No free worlds remain.';
  end if;

  insert into public.planets (
    owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at,
    ore_mine, crystal_mine, power_plant
  )
  values (
    uid, 1, sys, sl, 'Homeworld', 1200, 500, timezone('utc', now()),
    1, 1, 1
  )
  returning id into planet_id;

  insert into public.empires (user_id, home_planet_id)
  values (uid, planet_id);

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(nullif(split_part(new.email, '@', 1), ''), 'Commander')
  );
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create or replace function public.get_empire_state()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from public.empires where user_id = uid) then
    return private.bootstrap_empire(uid);
  end if;
  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.bootstrap_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  return private.bootstrap_empire(uid);
end;
$$;

create or replace function public.start_upgrade(p_building text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  home public.planets%rowtype;
  lvl integer;
  cost_ore bigint;
  cost_crystal bigint;
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_building not in ('ore_mine', 'crystal_mine', 'power_plant') then
    raise exception 'Unknown structure.';
  end if;

  perform private.catch_up(uid, at);
  select * into home
  from public.planets
  where owner_id = uid
  for update;

  if home.upgrade_building is not null then
    raise exception 'An upgrade is already running.';
  end if;

  lvl := case p_building
    when 'ore_mine' then home.ore_mine
    when 'crystal_mine' then home.crystal_mine
    else home.power_plant
  end;
  cost_ore := private.building_cost_ore(p_building, lvl);
  cost_crystal := private.building_cost_crystal(p_building, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    upgrade_building = p_building,
    upgrade_completes_at = at + make_interval(secs => private.building_time_seconds(lvl))
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.start_research()
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
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null then
    raise exception 'Research already running.';
  end if;

  cost_ore := private.research_cost_ore(e.propulsion_level);
  cost_crystal := private.research_cost_crystal(e.propulsion_level);
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set research_completes_at = at + make_interval(secs => private.research_time_seconds(e.propulsion_level))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.queue_raiders(p_count integer)
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
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one raider.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  cost_ore := 400 * p_count;
  cost_crystal := 100 * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set
    raiders_queued = e.raiders_queued + p_count,
    raider_completes_at = case
      when e.raiders_queued = 0 then at + make_interval(secs => 15)
      else e.raider_completes_at
    end
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.send_raid(p_system smallint, p_slot smallint, p_raiders integer)
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

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.raiders < p_raiders then
    raise exception 'Not enough raiders.';
  end if;

  select * into dest
  from public.planets
  where galaxy = 1 and system = p_system and slot = p_slot
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

  flight := private.flight_seconds(origin.system, origin.slot, dest.system, dest.slot, e.propulsion_level);

  update public.empires set raiders = e.raiders - p_raiders where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, raiders, mission, arrives_at
  )
  values (
    uid, origin.id, dest.id, p_raiders, 'attack', at + make_interval(secs => flight)
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.get_empire_state() from public, anon;
revoke all on function public.bootstrap_empire() from public, anon;
revoke all on function public.start_upgrade(text) from public, anon;
revoke all on function public.start_research() from public, anon;
revoke all on function public.queue_raiders(integer) from public, anon;
revoke all on function public.send_raid(smallint, smallint, integer) from public, anon;

grant execute on function public.get_empire_state() to authenticated;
grant execute on function public.bootstrap_empire() to authenticated;
grant execute on function public.start_upgrade(text) to authenticated;
grant execute on function public.start_research() to authenticated;
grant execute on function public.queue_raiders(integer) to authenticated;
grant execute on function public.send_raid(smallint, smallint, integer) to authenticated;

revoke all on function private.game_hour_seconds() from public, anon, authenticated;
revoke all on function private.mine_prod_per_hour(integer) from public, anon, authenticated;
revoke all on function private.crystal_prod_per_hour(integer) from public, anon, authenticated;
revoke all on function private.power_output(integer) from public, anon, authenticated;
revoke all on function private.mine_energy_drain(integer) from public, anon, authenticated;
revoke all on function private.energy_factor(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.storage_cap(integer) from public, anon, authenticated;
revoke all on function private.building_cost_ore(text, integer) from public, anon, authenticated;
revoke all on function private.building_cost_crystal(text, integer) from public, anon, authenticated;
revoke all on function private.building_time_seconds(integer) from public, anon, authenticated;
revoke all on function private.research_cost_ore(integer) from public, anon, authenticated;
revoke all on function private.research_cost_crystal(integer) from public, anon, authenticated;
revoke all on function private.research_time_seconds(integer) from public, anon, authenticated;
revoke all on function private.flight_seconds(integer, integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.tick_planet(public.planets, timestamptz) from public, anon, authenticated;
revoke all on function private.persist_planet(public.planets) from public, anon, authenticated;
revoke all on function private.catch_up_planet(public.planets, timestamptz) from public, anon, authenticated;
revoke all on function private.catch_up(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.empire_state_json(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.bootstrap_empire(uuid) from public, anon, authenticated;

insert into public.planets (
  owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at, ore_mine, crystal_mine, power_plant
)
values
  (null, 1, 1, 5, 'Silent Quarry', 3200, 1400, now(), 2, 1, 1),
  (null, 1, 1, 9, 'Ash Drift', 1800, 900, now(), 1, 1, 1),
  (null, 1, 2, 3, 'Derelict Hulk', 5400, 2100, now(), 2, 2, 1),
  (null, 1, 2, 8, 'Iron Wake', 2600, 1600, now(), 1, 2, 1),
  (null, 1, 3, 5, 'Glass Hollow', 4100, 2800, now(), 2, 2, 2),
  (null, 1, 3, 10, 'Pale Spire', 1500, 2200, now(), 1, 2, 1),
  (null, 1, 4, 1, 'Cinder Well', 6000, 800, now(), 3, 1, 2),
  (null, 1, 4, 7, 'Broken Relay', 2200, 1900, now(), 1, 1, 2),
  (null, 1, 5, 4, 'Orefall', 4800, 1200, now(), 3, 1, 1),
  (null, 1, 5, 9, 'Veil Cache', 900, 3600, now(), 1, 3, 2),
  (null, 1, 6, 2, 'Rust Moon', 3300, 1100, now(), 2, 1, 1),
  (null, 1, 6, 6, 'Cold Battery', 1700, 2500, now(), 1, 2, 3),
  (null, 1, 7, 3, 'Wreck of Ix', 7000, 2400, now(), 3, 2, 2),
  (null, 1, 7, 8, 'Dust Abbey', 2100, 1700, now(), 1, 1, 1),
  (null, 1, 8, 4, 'Needle Field', 2800, 3100, now(), 2, 3, 2),
  (null, 1, 8, 10, 'Last Beacon', 1200, 800, now(), 1, 1, 1),
  (null, 1, 9, 1, 'Hollow Crown', 4500, 2000, now(), 2, 2, 2),
  (null, 1, 9, 6, 'Sable Pit', 3900, 600, now(), 3, 1, 1),
  (null, 1, 10, 3, 'Far Kiln', 2500, 2500, now(), 2, 2, 2),
  (null, 1, 10, 7, 'Night Quarry', 5100, 1500, now(), 3, 1, 2);
