-- 084: Stellar Events (star weather), Pirate Strongholds (co-op/competitive PvE bounties),
-- and Ancient Relics (Command Core planetary modules).

create table if not exists public.stellar_events (
  id bigint generated always as identity primary key,
  galaxy smallint not null check (galaxy between 1 and 9),
  system smallint not null check (system between 1 and 499),
  kind text not null check (kind in ('solar_flare', 'ion_storm', 'meteor_shower')),
  starts_at timestamptz not null default timezone('utc', now()),
  ends_at timestamptz not null,
  unique (galaxy, system)
);

create index if not exists stellar_events_ends_at_idx on public.stellar_events (ends_at);
alter table public.stellar_events enable row level security;
revoke all on table public.stellar_events from public, anon, authenticated;

create table if not exists public.pirate_strongholds (
  id bigint generated always as identity primary key,
  galaxy smallint not null check (galaxy between 1 and 9),
  system smallint not null check (system between 1 and 499),
  slot smallint not null check (slot between 1 and 15),
  name text not null default 'Corsair Bastion',
  tier smallint not null default 1 check (tier between 1 and 5),
  ships jsonb not null default '{}'::jsonb,
  defenses jsonb not null default '{}'::jsonb,
  vault_ore bigint not null default 15000 check (vault_ore >= 0),
  vault_crystal bigint not null default 10000 check (vault_crystal >= 0),
  vault_deuterium bigint not null default 5000 check (vault_deuterium >= 0),
  max_hull bigint not null default 100000 check (max_hull > 0),
  current_hull bigint not null default 100000 check (current_hull >= 0),
  expires_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (galaxy, system, slot)
);

create index if not exists pirate_strongholds_coords_idx on public.pirate_strongholds (galaxy, system);
alter table public.pirate_strongholds enable row level security;
revoke all on table public.pirate_strongholds from public, anon, authenticated;

create table if not exists public.empire_relics (
  user_id uuid not null references auth.users (id) on delete cascade,
  relic_id text not null check (relic_id in ('overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites')),
  count integer not null default 0 check (count >= 0),
  last_report_id bigint not null default 0,
  primary key (user_id, relic_id)
);

alter table public.empire_relics enable row level security;
revoke all on table public.empire_relics from public, anon, authenticated;

create table if not exists public.planet_relics (
  planet_id bigint not null references public.planets (id) on delete cascade,
  relic_id text not null check (relic_id in ('overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites')),
  equipped_at timestamptz not null default timezone('utc', now()),
  primary key (planet_id, relic_id)
);

alter table public.planet_relics enable row level security;
revoke all on table public.planet_relics from public, anon, authenticated;

create or replace function private.stronghold_hull_of(p_ships jsonb, p_defenses jsonb)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select
    greatest(coalesce((p_ships->>'light_fighter')::bigint, 0), 0) * 4000
    + greatest(coalesce((p_ships->>'heavy_fighter')::bigint, 0), 0) * 10000
    + greatest(coalesce((p_ships->>'cruiser')::bigint, 0), 0) * 27000
    + greatest(coalesce((p_ships->>'battleship')::bigint, 0), 0) * 60000
    + greatest(coalesce((p_defenses->>'rocket_launcher')::bigint, 0), 0) * 2000
    + greatest(coalesce((p_defenses->>'light_laser')::bigint, 0), 0) * 2000
    + greatest(coalesce((p_defenses->>'heavy_laser')::bigint, 0), 0) * 8000
    + greatest(coalesce((p_defenses->>'gauss_cannon')::bigint, 0), 0) * 35000;
$$;

revoke all on function private.stronghold_hull_of(jsonb, jsonb) from public, anon, authenticated;

create or replace function private.ensure_universe_events(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  home public.planets%rowtype;
  free_slot smallint;
  ev_kind text;
  ships_json jsonb;
  defs_json jsonb;
  total_h bigint;
begin
  delete from public.stellar_events where ends_at <= at;
  delete from public.pirate_strongholds where expires_at <= at or current_hull <= 0;

  select p.* into home
  from public.planets p
  join public.empires e on e.home_planet_id = p.id
  where e.user_id = uid;

  if not found then
    return;
  end if;

  -- Ensure at least 1 active stellar event near the commander's system
  if not exists (
    select 1 from public.stellar_events
    where galaxy = home.galaxy
      and ends_at > at
  ) then
    ev_kind := (array['solar_flare', 'ion_storm', 'meteor_shower'])[1 + floor(random() * 3)::int];
    insert into public.stellar_events (galaxy, system, kind, starts_at, ends_at)
    values (home.galaxy, home.system, ev_kind, at, at + interval '3 hours')
    on conflict (galaxy, system) do update
      set kind = excluded.kind,
          starts_at = excluded.starts_at,
          ends_at = excluded.ends_at;

    if ev_kind = 'meteor_shower' then
      update public.asteroid_belts
      set crystal = crystal + 4500,
          depleted_at = null
      where galaxy = home.galaxy and system = home.system;
    end if;
  end if;

  -- Ensure at least 1 active Pirate Stronghold in the commander's system
  if not exists (
    select 1 from public.pirate_strongholds
    where galaxy = home.galaxy
      and system = home.system
      and expires_at > at
  ) then
    select s.slot::smallint into free_slot
    from generate_series(1, 15) as s(slot)
    where not exists (
      select 1 from public.planets p
      where p.galaxy = home.galaxy and p.system = home.system and p.slot = s.slot
    )
    order by random()
    limit 1;

    if free_slot is not null then
      ships_json := jsonb_build_object(
        'light_fighter', 12,
        'heavy_fighter', 6,
        'cruiser', 2
      );
      defs_json := jsonb_build_object(
        'rocket_launcher', 15,
        'light_laser', 8,
        'heavy_laser', 2
      );
      total_h := private.stronghold_hull_of(ships_json, defs_json);
      insert into public.pirate_strongholds (
        galaxy, system, slot, name, tier, ships, defenses,
        vault_ore, vault_crystal, vault_deuterium,
        max_hull, current_hull, expires_at
      ) values (
        home.galaxy, home.system, free_slot,
        'Corsair Bastion', 1, ships_json, defs_json,
        20000, 12000, 6000,
        total_h, total_h,
        at + interval '24 hours'
      )
      on conflict (galaxy, system, slot) do nothing;
    end if;
  end if;
end;
$$;

revoke all on function private.ensure_universe_events(uuid, timestamptz) from public, anon, authenticated;

create or replace function private.award_relics_from_reports(uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  last_seen bigint := 0;
  rep record;
  picked text;
begin
  select coalesce(max(last_report_id), 0) into last_seen
  from public.empire_relics
  where user_id = uid;

  for rep in
    select id, title, body
    from public.battle_reports
    where user_id = uid
      and id > last_seen
      and (
        title = 'Expedition returned'
        or title like 'Attack on%'
        or title like 'Stronghold%'
      )
    order by id asc
  loop
    if (rep.id % 3 = 0) or rep.title like 'Stronghold%' then
      picked := (array['overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites'])[1 + (rep.id % 4)];
      insert into public.empire_relics (user_id, relic_id, count, last_report_id)
      values (uid, picked, 1, rep.id)
      on conflict (user_id, relic_id) do update
        set count = public.empire_relics.count + 1,
            last_report_id = greatest(public.empire_relics.last_report_id, excluded.last_report_id);
    end if;
    update public.empire_relics
    set last_report_id = greatest(last_report_id, rep.id)
    where user_id = uid;
  end loop;
end;
$$;

revoke all on function private.award_relics_from_reports(uuid) from public, anon, authenticated;

create or replace function public.get_mechanics_state()
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

  perform private.ensure_universe_events(uid, at);
  perform private.award_relics_from_reports(uid);

  return jsonb_build_object(
    'stellar_events', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', se.id,
          'galaxy', se.galaxy,
          'system', se.system,
          'kind', se.kind,
          'starts_at', se.starts_at,
          'ends_at', se.ends_at
        )
        order by se.ends_at asc
      )
      from public.stellar_events se
      where se.ends_at > at
    ), '[]'::jsonb),
    'strongholds', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ps.id,
          'galaxy', ps.galaxy,
          'system', ps.system,
          'slot', ps.slot,
          'name', ps.name,
          'tier', ps.tier,
          'ships', ps.ships,
          'defenses', ps.defenses,
          'vault_ore', ps.vault_ore,
          'vault_crystal', ps.vault_crystal,
          'vault_deuterium', ps.vault_deuterium,
          'max_hull', ps.max_hull,
          'current_hull', ps.current_hull,
          'expires_at', ps.expires_at
        )
        order by ps.expires_at asc
      )
      from public.pirate_strongholds ps
      where ps.expires_at > at and ps.current_hull > 0
    ), '[]'::jsonb),
    'relic_inventory', jsonb_build_object(
      'overclock_drill', coalesce((select count from public.empire_relics where user_id = uid and relic_id = 'overclock_drill'), 0),
      'phase_cloak', coalesce((select count from public.empire_relics where user_id = uid and relic_id = 'phase_cloak'), 0),
      'subspace_beacon', coalesce((select count from public.empire_relics where user_id = uid and relic_id = 'subspace_beacon'), 0),
      'repair_nanites', coalesce((select count from public.empire_relics where user_id = uid and relic_id = 'repair_nanites'), 0)
    ),
    'planet_relics', coalesce((
      select jsonb_object_agg(t.planet_id::text, t.relics)
      from (
        select pr.planet_id, jsonb_agg(pr.relic_id order by pr.equipped_at asc) as relics
        from public.planet_relics pr
        join public.planets p on p.id = pr.planet_id
        where p.owner_id = uid
        group by pr.planet_id
      ) t
    ), '{}'::jsonb)
  );
end;
$$;

revoke all on function public.get_mechanics_state() from public, anon;
grant execute on function public.get_mechanics_state() to authenticated;

create or replace function public.toggle_planet_relic(p_planet_id bigint, p_relic_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  pl public.planets%rowtype;
  owned integer;
  in_use integer;
  slot_count integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_relic_id not in ('overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites') then
    raise exception 'Unknown relic.';
  end if;

  select * into pl from public.planets where id = p_planet_id and owner_id = uid;
  if not found then
    raise exception 'Planet not found.';
  end if;

  if exists (select 1 from public.planet_relics where planet_id = p_planet_id and relic_id = p_relic_id) then
    delete from public.planet_relics where planet_id = p_planet_id and relic_id = p_relic_id;
    return public.get_mechanics_state();
  end if;

  select count(*) into slot_count from public.planet_relics where planet_id = p_planet_id;
  if slot_count >= 2 then
    raise exception 'Command Core holds at most 2 active relics per planet.';
  end if;

  select coalesce(count, 0) into owned
  from public.empire_relics
  where user_id = uid and relic_id = p_relic_id;

  select count(*) into in_use
  from public.planet_relics pr
  join public.planets p on p.id = pr.planet_id
  where p.owner_id = uid and pr.relic_id = p_relic_id;

  if in_use >= owned then
    raise exception 'No spare copy of that relic in your inventory.';
  end if;

  insert into public.planet_relics (planet_id, relic_id)
  values (p_planet_id, p_relic_id);

  return public.get_mechanics_state();
end;
$$;

revoke all on function public.toggle_planet_relic(bigint, text) from public, anon;
grant execute on function public.toggle_planet_relic(bigint, text) to authenticated;

create or replace function public.strike_pirate_stronghold(p_stronghold_id bigint, p_ships jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  e public.empires%rowtype;
  home public.planets%rowtype;
  sh public.pirate_strongholds%rowtype;
  lf integer := greatest(coalesce((p_ships->>'light_fighter')::integer, 0), 0);
  hf integer := greatest(coalesce((p_ships->>'heavy_fighter')::integer, 0), 0);
  cr integer := greatest(coalesce((p_ships->>'cruiser')::integer, 0), 0);
  bs integer := greatest(coalesce((p_ships->>'battleship')::integer, 0), 0);
  bc integer := greatest(coalesce((p_ships->>'battlecruiser')::integer, 0), 0);
  bm integer := greatest(coalesce((p_ships->>'bomber')::integer, 0), 0);
  ds integer := greatest(coalesce((p_ships->>'destroyer')::integer, 0), 0);
  rp integer := greatest(coalesce((p_ships->>'reaper')::integer, 0), 0);
  fleet_atk bigint;
  weapons_mul numeric;
  dmg_hull bigint;
  old_hull bigint;
  new_hull bigint;
  ratio numeric;
  bounty_ore bigint;
  bounty_crystal bigint;
  bounty_deut bigint := 0;
  cleared boolean := false;
  relic_drop text;
  rep_body text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;
  select * into sh from public.pirate_strongholds where id = p_stronghold_id and expires_at > at and current_hull > 0 for update;

  if not found then
    raise exception 'That pirate stronghold is no longer active.';
  end if;

  if lf > coalesce((e.ships->>'light_fighter')::integer, 0)
     or hf > coalesce((e.ships->>'heavy_fighter')::integer, 0)
     or cr > coalesce((e.ships->>'cruiser')::integer, 0)
     or bs > coalesce((e.ships->>'battleship')::integer, 0)
     or bc > coalesce((e.ships->>'battlecruiser')::integer, 0)
     or bm > coalesce((e.ships->>'bomber')::integer, 0)
     or ds > coalesce((e.ships->>'destroyer')::integer, 0)
     or rp > coalesce((e.ships->>'reaper')::integer, 0) then
    raise exception 'Not enough docked combat ships for this strike.';
  end if;

  weapons_mul := 1 + 0.1 * greatest(coalesce(e.weapons_tech, 0), 0);
  fleet_atk := floor((
    lf * 50 + hf * 150 + cr * 400 + bs * 1000 + bc * 700 + bm * 1000 + ds * 2000 + rp * 2800
  ) * weapons_mul)::bigint;

  if fleet_atk <= 0 then
    raise exception 'Select at least one combat ship to strike the stronghold.';
  end if;

  old_hull := sh.current_hull;
  dmg_hull := least(old_hull, fleet_atk * 6);
  new_hull := greatest(0, old_hull - dmg_hull);
  cleared := (new_hull = 0);

  -- Bounty proportional to hull destroyed (25% of destroyed hull in ore, 15% in crystal)
  bounty_ore := floor(dmg_hull * 0.25)::bigint;
  bounty_crystal := floor(dmg_hull * 0.15)::bigint;

  if cleared then
    bounty_ore := bounty_ore + sh.vault_ore;
    bounty_crystal := bounty_crystal + sh.vault_crystal;
    bounty_deut := sh.vault_deuterium;
    relic_drop := (array['overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites'])[1 + (sh.id % 4)];

    insert into public.empire_relics (user_id, relic_id, count)
    values (uid, relic_drop, 1)
    on conflict (user_id, relic_id) do update
      set count = public.empire_relics.count + 1;

    delete from public.pirate_strongholds where id = sh.id;
  else
    ratio := new_hull::numeric / greatest(1, sh.max_hull)::numeric;
    update public.pirate_strongholds
    set
      current_hull = new_hull,
      ships = jsonb_build_object(
        'light_fighter', ceil(coalesce((sh.ships->>'light_fighter')::numeric, 0) * ratio)::int,
        'heavy_fighter', ceil(coalesce((sh.ships->>'heavy_fighter')::numeric, 0) * ratio)::int,
        'cruiser', ceil(coalesce((sh.ships->>'cruiser')::numeric, 0) * ratio)::int
      ),
      defenses = jsonb_build_object(
        'rocket_launcher', ceil(coalesce((sh.defenses->>'rocket_launcher')::numeric, 0) * ratio)::int,
        'light_laser', ceil(coalesce((sh.defenses->>'light_laser')::numeric, 0) * ratio)::int,
        'heavy_laser', ceil(coalesce((sh.defenses->>'heavy_laser')::numeric, 0) * ratio)::int
      )
    where id = sh.id;
  end if;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + bounty_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + bounty_crystal),
    deuterium = least(private.storage_cap(home.deuterium_storage), home.deuterium + bounty_deut)
  where id = home.id;

  rep_body := case
    when cleared then format(
      'Stronghold [%s:%s:%s] %s destroyed! Dealt %s hull damage. Claimed bounty + vault jackpot: %s ore, %s crystal, %s deuterium. Recovered Ancient Relic: %s.',
      sh.galaxy, sh.system, sh.slot, sh.name, dmg_hull, bounty_ore, bounty_crystal, bounty_deut, relic_drop
    )
    else format(
      'Struck %s at [%s:%s:%s] for %s hull damage (%s / %s hull remaining). Bounty paid: %s ore, %s crystal.',
      sh.name, sh.galaxy, sh.system, sh.slot, dmg_hull, new_hull, sh.max_hull, bounty_ore, bounty_crystal
    )
  end;

  insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
  values (
    uid,
    case when cleared then 'Stronghold destroyed' else 'Stronghold strike' end,
    rep_body,
    bounty_ore,
    bounty_crystal
  );

  return public.get_mechanics_state();
end;
$$;

revoke all on function public.strike_pirate_stronghold(bigint, jsonb) from public, anon;
grant execute on function public.strike_pirate_stronghold(bigint, jsonb) to authenticated;

create or replace function public.debug_spawn_stellar_event(p_galaxy smallint, p_system smallint, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  at timestamptz := timezone('utc', now());
begin
  perform private.require_debug();
  if p_kind not in ('solar_flare', 'ion_storm', 'meteor_shower') then
    raise exception 'Unknown stellar event kind.';
  end if;
  insert into public.stellar_events (galaxy, system, kind, starts_at, ends_at)
  values (p_galaxy, p_system, p_kind, at, at + interval '3 hours')
  on conflict (galaxy, system) do update
    set kind = excluded.kind,
        starts_at = excluded.starts_at,
        ends_at = excluded.ends_at;

  if p_kind = 'meteor_shower' then
    update public.asteroid_belts
    set crystal = crystal + 4500,
        depleted_at = null
    where galaxy = p_galaxy and system = p_system;
  end if;

  return public.get_mechanics_state();
end;
$$;

revoke all on function public.debug_spawn_stellar_event(smallint, smallint, text) from public, anon;
grant execute on function public.debug_spawn_stellar_event(smallint, smallint, text) to authenticated;

create or replace function public.debug_grant_relics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  r text;
begin
  perform private.require_debug();
  foreach r in array array['overclock_drill', 'phase_cloak', 'subspace_beacon', 'repair_nanites'] loop
    insert into public.empire_relics (user_id, relic_id, count)
    values (uid, r, 1)
    on conflict (user_id, relic_id) do update
      set count = public.empire_relics.count + 1;
  end loop;
  return public.get_mechanics_state();
end;
$$;

revoke all on function public.debug_grant_relics() from public, anon;
grant execute on function public.debug_grant_relics() to authenticated;

notify pgrst, 'reload schema';
