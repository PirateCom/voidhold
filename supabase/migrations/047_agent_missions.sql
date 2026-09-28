-- Agent missions: mining (recyclers/debris), exploration (slot 16 or spy), combat (pirates).

create table if not exists public.agent_missions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  agent_id text not null check (agent_id in ('mining', 'exploration', 'combat')),
  kind text not null check (kind in ('harvest', 'expedition', 'espionage', 'pirate')),
  status text not null check (status in ('offered', 'active', 'ready', 'claimed')),
  dest_galaxy smallint,
  dest_system smallint,
  dest_slot smallint,
  title text not null,
  blurb text not null,
  reward_ore bigint not null default 0 check (reward_ore >= 0),
  reward_crystal bigint not null default 0 check (reward_crystal >= 0),
  reward_deuterium bigint not null default 0 check (reward_deuterium >= 0),
  accepted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'agent_missions_one_live'
  ) then
    create unique index agent_missions_one_live
      on public.agent_missions (user_id, agent_id)
      where status in ('offered', 'active', 'ready');
  end if;
end $$;

alter table public.agent_missions enable row level security;

revoke all on table public.agent_missions from public, anon, authenticated;

create or replace function private.agent_mission_report_matches(p_kind text, p_title text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'harvest' then p_title = 'Harvest returned'
    when 'expedition' then p_title = 'Expedition returned'
    when 'espionage' then p_title = 'Espionage report'
    when 'pirate' then p_title like 'Pirates struck%'
    else false
  end;
$$;

revoke all on function private.agent_mission_report_matches(text, text) from public, anon, authenticated;

create or replace function private.refresh_agent_missions(uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.agent_missions m
  set status = 'ready'
  where m.user_id = uid
    and m.status = 'active'
    and m.accepted_at is not null
    and exists (
      select 1
      from public.battle_reports r
      where r.user_id = uid
        and r.created_at >= m.accepted_at
        and private.agent_mission_report_matches(m.kind, r.title)
    );
end;
$$;

revoke all on function private.refresh_agent_missions(uuid) from public, anon, authenticated;

create or replace function private.insert_agent_offer(uid uuid, p_agent_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  home public.planets%rowtype;
  p_kind text;
  g smallint;
  s smallint;
  sl smallint;
  p_title text;
  p_blurb text;
  ore bigint;
  crystal bigint;
  deut bigint;
  spy public.planets%rowtype;
  empty_slot smallint;
begin
  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid);
  if not found then
    raise exception 'No homeworld.';
  end if;

  if p_agent_id = 'mining' then
    p_kind := 'harvest';
    select gs.slot into empty_slot
    from generate_series(1, 15) as gs(slot)
    where not exists (
      select 1 from public.planets p
      where p.galaxy = home.galaxy and p.system = home.system and p.slot = gs.slot
    )
    order by gs.slot
    limit 1;
    g := home.galaxy;
    s := home.system;
    sl := coalesce(empty_slot, home.slot);
    p_title := 'Asteroid salvage';
    p_blurb := format(
      'Take recyclers to the debris at [%s:%s:%s] and haul the ore and crystal home.',
      g, s, sl
    );
    ore := 800; crystal := 200; deut := 50;
  elsif p_agent_id = 'exploration' then
    select * into spy
    from public.planets
    where owner_id is not null and owner_id is distinct from uid
    order by random()
    limit 1;
    if found and random() < 0.5 then
      p_kind := 'espionage';
      g := spy.galaxy; s := spy.system; sl := spy.slot;
      p_title := 'Silent recon';
      p_blurb := format(
        'Send probes to [%s:%s:%s] and bring back an espionage report.',
        g, s, sl
      );
      ore := 200; crystal := 300; deut := 150;
    else
      p_kind := 'expedition';
      g := home.galaxy;
      s := home.system;
      sl := 16;
      p_title := 'Deep void survey';
      p_blurb := format(
        'Launch an expedition into outer space at [%s:%s:16] and return with a survey log.',
        g, s
      );
      ore := 400; crystal := 400; deut := 200;
    end if;
  elsif p_agent_id = 'combat' then
    p_kind := 'pirate';
    g := home.galaxy; s := home.system; sl := home.slot;
    p_title := 'Pirate intercept';
    p_blurb := 'A fighting agent is vectoring pirates onto your hold. Survive the inbound wave.';
    ore := 300; crystal := 500; deut := 250;
  else
    raise exception 'Unknown agent.';
  end if;

  insert into public.agent_missions (
    user_id, agent_id, kind, status, dest_galaxy, dest_system, dest_slot,
    title, blurb, reward_ore, reward_crystal, reward_deuterium
  ) values (
    uid, p_agent_id, p_kind, 'offered', g, s, sl,
    p_title, p_blurb, ore, crystal, deut
  );
end;
$$;

revoke all on function private.insert_agent_offer(uuid, text) from public, anon, authenticated;

create or replace function private.ensure_agent_offers(uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  aid text;
begin
  foreach aid in array array['mining', 'exploration', 'combat']
  loop
    if not exists (
      select 1 from public.agent_missions
      where user_id = uid and agent_id = aid and status in ('offered', 'active', 'ready')
    ) then
      perform private.insert_agent_offer(uid, aid);
    end if;
  end loop;
end;
$$;

revoke all on function private.ensure_agent_offers(uuid) from public, anon, authenticated;

create or replace function private.agent_missions_payload(uid uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'agent_id', m.agent_id,
    'kind', m.kind,
    'status', m.status,
    'dest_galaxy', m.dest_galaxy,
    'dest_system', m.dest_system,
    'dest_slot', m.dest_slot,
    'title', m.title,
    'blurb', m.blurb,
    'reward_ore', m.reward_ore,
    'reward_crystal', m.reward_crystal,
    'reward_deuterium', m.reward_deuterium,
    'accepted_at', m.accepted_at
  ) order by array_position(array['mining', 'exploration', 'combat'], m.agent_id)), '[]'::jsonb)
  from public.agent_missions m
  where m.user_id = uid
    and m.status in ('offered', 'active', 'ready');
$$;

revoke all on function private.agent_missions_payload(uuid) from public, anon, authenticated;

create or replace function private.spawn_mission_pirates(uid uuid, home public.planets, at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ships integer;
  eta timestamptz;
  raids_on boolean;
begin
  ships := private.pirate_wave_size(private.defence_units(home));
  eta := at + make_interval(secs => 600);
  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition
  ) values (
    null, home.id, home.id, home.galaxy, home.system, home.slot,
    ships, 'attack', eta, jsonb_build_object('pirate', ships)
  );
  select coalesce(pirate_raids_enabled, true) into raids_on from public.empires where user_id = uid;
  if raids_on then
    update public.empires
    set next_pirate_at = eta + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)))
    where user_id = uid;
  else
    update public.empires
    set next_pirate_at = null
    where user_id = uid;
  end if;
end;
$$;

revoke all on function private.spawn_mission_pirates(uuid, public.planets, timestamptz) from public, anon, authenticated;

create or replace function public.list_agent_missions()
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
  perform private.catch_up(uid, timezone('utc', now()));
  perform private.refresh_agent_missions(uid);
  perform private.ensure_agent_offers(uid);
  return private.agent_missions_payload(uid);
end;
$$;

revoke all on function public.list_agent_missions() from public, anon;
grant execute on function public.list_agent_missions() to authenticated;

create or replace function public.accept_agent_mission(p_agent_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  m public.agent_missions%rowtype;
  home public.planets%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_agent_id not in ('mining', 'exploration', 'combat') then
    raise exception 'Unknown agent.';
  end if;

  perform private.catch_up(uid, at);
  perform private.refresh_agent_missions(uid);
  perform private.ensure_agent_offers(uid);

  select * into m
  from public.agent_missions
  where user_id = uid and agent_id = p_agent_id and status in ('offered', 'active', 'ready')
  for update;
  if not found then
    raise exception 'No mission.';
  end if;
  if m.status <> 'offered' then
    raise exception 'That job is already underway.';
  end if;

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;

  if m.kind = 'harvest' then
    perform private.bump_debris(
      m.dest_galaxy,
      m.dest_system,
      m.dest_slot,
      12000,
      4000
    );
  elsif m.kind = 'pirate' then
    perform private.spawn_mission_pirates(uid, home, at);
  end if;

  update public.agent_missions
  set status = 'active', accepted_at = at
  where id = m.id;

  return private.agent_missions_payload(uid);
end;
$$;

revoke all on function public.accept_agent_mission(text) from public, anon;
grant execute on function public.accept_agent_mission(text) to authenticated;

create or replace function public.claim_agent_mission(p_agent_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  m public.agent_missions%rowtype;
  home public.planets%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_agent_id not in ('mining', 'exploration', 'combat') then
    raise exception 'Unknown agent.';
  end if;

  perform private.catch_up(uid, at);
  perform private.refresh_agent_missions(uid);

  select * into m
  from public.agent_missions
  where user_id = uid and agent_id = p_agent_id and status = 'ready'
  for update;
  if not found then
    raise exception 'Nothing to collect.';
  end if;

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set
    ore = least(private.storage_cap(ore_storage), ore + m.reward_ore),
    crystal = least(private.storage_cap(crystal_storage), crystal + m.reward_crystal),
    deuterium = least(private.storage_cap(deuterium_storage), deuterium + m.reward_deuterium)
  where id = home.id;

  update public.agent_missions
  set status = 'claimed'
  where id = m.id;

  perform private.insert_agent_offer(uid, p_agent_id);
  return private.agent_missions_payload(uid);
end;
$$;

revoke all on function public.claim_agent_mission(text) from public, anon;
grant execute on function public.claim_agent_mission(text) to authenticated;

create or replace function public.reset_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home_id bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();

  select p.id into home_id
  from public.planets p
  where p.owner_id = uid and p.is_homeworld
  order by p.id
  limit 1;
  if home_id is null then
    select home_planet_id into home_id from public.empires where user_id = uid;
  end if;

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid);
  delete from public.battle_reports where user_id = uid;
  delete from public.agent_missions where user_id = uid;
  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

  delete from public.planets
  where owner_id = uid and id is distinct from home_id;

  update public.empires set home_planet_id = home_id where user_id = uid;

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    deuterium = 0,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    deuterium_extractor = 0,
    power_plant = 1,
    fusion_reactor = 0,
    ore_storage = 0,
    crystal_storage = 0,
    deuterium_storage = 0,
    robotics_factory = 0,
    shipyard = 0,
    research_lab = 0,
    alliance_depot = 0,
    missile_silo = 0,
    nanite_factory = 0,
    terraformer = 0,
    lunar_base = 0,
    phalanx_sensor = 0,
    stargate = 0,
    space_station = 0,
    upgrade_building = null,
    upgrade_completes_at = null,
    small_shield_dome = 0,
    large_shield_dome = 0,
    rocket_launcher = 0,
    light_laser = 0,
    heavy_laser = 0,
    ion_cannon = 0,
    gauss_cannon = 0,
    plasma_turret = 0,
    antiballistic_missile = 0,
    interplanetary_missile = 0,
    defence_building = null,
    defences_queued = 0,
    defence_completes_at = null,
    ship_building = null,
    ships_queued = 0,
    ship_completes_at = null,
    is_homeworld = true
  where id = home_id;

  update public.empires
  set
    propulsion_level = 0,
    energy_tech = 0,
    laser_tech = 0,
    ion_tech = 0,
    hyperspace_tech = 0,
    plasma_tech = 0,
    impulse_drive = 0,
    hyperspace_drive = 0,
    espionage_tech = 0,
    computer_tech = 0,
    astrophysics = 0,
    intergalactic_research_network = 0,
    graviton_tech = 0,
    weapons_tech = 0,
    shielding_tech = 0,
    armour_tech = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    ships = '{}'::jsonb,
    ship_building = null,
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null,
    claimed_directives = '[]'::jsonb,
    tracked_directives = '[]'::jsonb
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.delete_own_account(p_confirmation text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  if lower(btrim(coalesce(p_confirmation, ''))) <> 'delete' then
    raise exception 'Type delete to confirm.';
  end if;

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid)
     or origin_planet_id in (select id from public.planets where owner_id = uid);

  delete from public.battle_reports where user_id = uid;
  delete from public.agent_missions where user_id = uid;

  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

  delete from public.empires where user_id = uid;
  delete from public.planets where owner_id = uid;
  delete from public.profiles where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

notify pgrst, 'reload schema';
