-- Beginner directives (OGame officer tutorial, Voidhold names). No mine-output sliders.

alter table public.empires
  add column if not exists claimed_directives jsonb not null default '[]'::jsonb;

create or replace function private.energy_output_now(
  ore_mine integer,
  crystal_mine integer,
  power_plant integer,
  star_type text,
  deut_mine integer,
  fusion integer,
  energy_tech integer,
  satellites integer,
  temp_min integer,
  temp_max integer
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select
    case
      when coalesce(power_plant, 0) <= 0 then 0
      else floor(20 * power_plant * power(1.1, power_plant) * private.star_multiplier(coalesce(star_type, 'medium')))
    end
    + private.fusion_output(coalesce(fusion, 0), coalesce(energy_tech, 0))
    + private.solar_satellite_output(
      coalesce(temp_min, 30),
      coalesce(temp_max, 30),
      coalesce(star_type, 'medium'),
      coalesce(satellites, 0)
    );
$$;

create or replace function private.energy_drain_now(
  ore_mine integer,
  crystal_mine integer,
  deut_mine integer
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select private.mine_energy_drain(coalesce(ore_mine, 0))
    + private.mine_energy_drain(coalesce(crystal_mine, 0))
    + private.deut_energy_drain(coalesce(deut_mine, 0));
$$;

create or replace function private.directive_claimed(claimed jsonb, directive_id text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(claimed, '[]'::jsonb) @> jsonb_build_array(directive_id);
$$;

create or replace function private.directive_previous(directive_id text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case directive_id
    when 'ore_l1' then null
    when 'energy' then 'ore_l1'
    when 'ore_l2' then 'energy'
    when 'solar_l2' then 'ore_l2'
    when 'ore_solar_mid' then 'solar_l2'
    when 'crystal_l1' then 'ore_solar_mid'
    when 'continue_prod' then 'crystal_l1'
    when 'deuterium_l1' then 'continue_prod'
    when 'sufficient' then 'deuterium_l1'
    when 'storage' then 'sufficient'
    else null
  end;
$$;

create or replace function private.directive_objectives_met(
  p public.planets,
  e public.empires,
  star_type text,
  directive_id text
)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  surplus boolean;
  satellites integer := coalesce((e.ships ->> 'solar_satellite')::integer, 0);
begin
  surplus := private.energy_output_now(
    p.ore_mine, p.crystal_mine, p.power_plant, coalesce(star_type, 'medium'),
    p.deuterium_extractor, p.fusion_reactor, coalesce(e.energy_tech, 0),
    satellites, p.temp_min, p.temp_max
  ) > private.energy_drain_now(p.ore_mine, p.crystal_mine, p.deuterium_extractor);

  return case directive_id
    when 'ore_l1' then p.ore_mine >= 1
    when 'energy' then p.power_plant >= 1 and surplus
    when 'ore_l2' then p.ore_mine >= 2
    when 'solar_l2' then p.power_plant >= 2
    when 'ore_solar_mid' then p.ore_mine >= 4 and p.power_plant >= 3
    when 'crystal_l1' then p.crystal_mine >= 1
    when 'continue_prod' then
      p.power_plant >= 5 and p.ore_mine >= 5 and p.crystal_mine >= 3
    when 'deuterium_l1' then p.deuterium_extractor >= 1
    when 'sufficient' then
      p.power_plant >= 9 and p.ore_mine >= 7 and p.crystal_mine >= 5
      and p.deuterium_extractor >= 5
    when 'storage' then
      p.ore_storage >= 1 and p.crystal_storage >= 1 and p.deuterium_storage >= 1
    else false
  end;
end;
$$;

create or replace function private.directive_reward(directive_id text, out ore bigint, out crystal bigint, out deuterium bigint)
language plpgsql
immutable
set search_path = ''
as $$
begin
  ore := 0;
  crystal := 0;
  deuterium := 0;
  case directive_id
    when 'ore_l1' then ore := 50;
    when 'energy' then ore := 50;
    when 'ore_l2' then ore := 50;
    when 'solar_l2' then ore := 50; crystal := 30;
    when 'ore_solar_mid' then ore := 150; crystal := 50;
    when 'crystal_l1' then ore := 50; crystal := 30;
    when 'continue_prod' then ore := 400; crystal := 200;
    when 'deuterium_l1' then ore := 200; crystal := 100;
    when 'sufficient' then ore := 3000; crystal := 1000;
    when 'storage' then ore := 3000; crystal := 1500;
    else raise exception 'Unknown directive.';
  end case;
end;
$$;

revoke all on function private.energy_output_now(integer, integer, integer, text, integer, integer, integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function private.energy_drain_now(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.directive_claimed(jsonb, text) from public, anon, authenticated;
revoke all on function private.directive_previous(text) from public, anon, authenticated;
revoke all on function private.directive_objectives_met(public.planets, public.empires, text, text) from public, anon, authenticated;
revoke all on function private.directive_reward(text) from public, anon, authenticated;

create or replace function public.claim_directive(p_id text)
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
  star text;
  prev_id text;
  reward_ore bigint;
  reward_crystal bigint;
  reward_deut bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_id is null or p_id not in (
    'ore_l1', 'energy', 'ore_l2', 'solar_l2', 'ore_solar_mid',
    'crystal_l1', 'continue_prod', 'deuterium_l1', 'sufficient', 'storage'
  ) then
    raise exception 'Unknown directive.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  if not found then
    raise exception 'No empire.';
  end if;
  select * into home from public.planets pl where pl.id = e.home_planet_id for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  if private.directive_claimed(e.claimed_directives, p_id) then
    raise exception 'Already collected.';
  end if;

  prev_id := private.directive_previous(p_id);
  if prev_id is not null and not private.directive_claimed(e.claimed_directives, prev_id) then
    raise exception 'Complete the previous directive first.';
  end if;

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = home.galaxy and s.system = home.system;

  if not private.directive_objectives_met(home, e, coalesce(star, 'medium'), p_id) then
    raise exception 'Objectives are not complete.';
  end if;

  select r.ore, r.crystal, r.deuterium
  into reward_ore, reward_crystal, reward_deut
  from private.directive_reward(p_id) r;

  update public.planets
  set
    ore = least(private.storage_cap(ore_storage), ore + reward_ore),
    crystal = least(private.storage_cap(crystal_storage), crystal + reward_crystal),
    deuterium = least(private.storage_cap(deuterium_storage), deuterium + reward_deut)
  where public.planets.id = home.id;

  update public.empires
  set claimed_directives = coalesce(claimed_directives, '[]'::jsonb) || jsonb_build_array(p_id)
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.claim_directive(text) from public, anon;
grant execute on function public.claim_directive(text) to authenticated;

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

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid);
  delete from public.battle_reports where user_id = uid;
  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

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
    defence_completes_at = null
  where owner_id = uid;

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
    claimed_directives = '[]'::jsonb
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
