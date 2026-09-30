-- Fleet and defence directives after the beginner mine chain.

create or replace function private.directive_ids()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'ore_l1', 'energy', 'ore_l2', 'solar_l2', 'ore_solar_mid',
    'crystal_l1', 'continue_prod', 'deuterium_l1', 'sufficient', 'storage',
    'yard_foundations', 'energy_theory', 'combustion_fighter', 'rocket_screen',
    'orbit_sats', 'laser_screen', 'small_hauler', 'spy_net', 'heavy_fighter',
    'small_dome', 'large_hauler', 'recycler_crew', 'colony_line', 'ion_guns',
    'cruiser_wing', 'crawler_line', 'heavy_laser_battery', 'hyperspace_theory',
    'pathfinder_scout', 'gauss_line', 'large_dome', 'battleship_line',
    'plasma_bomber', 'plasma_guns', 'battlecruiser_wing', 'destroyer_wing',
    'missile_abm', 'missile_ipm', 'reaper_wing', 'nanite_works', 'deathstar'
  ];
$$;

create or replace function private.directive_known(p_id text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_id = any (private.directive_ids());
$$;

create or replace function private.directive_previous(directive_id text)
returns text
language sql
immutable
set search_path = ''
as $$
  select prev
  from (
    select id, lag(id) over (order by ord) as prev
    from unnest(private.directive_ids()) with ordinality as t(id, ord)
  ) q
  where id = directive_id;
$$;

create or replace function private.directive_ship_count(e public.empires, hull text)
returns integer
language sql
stable
set search_path = ''
as $$
  select case
    when hull = 'small_cargo' then coalesce(e.raiders, 0)
    else coalesce((e.ships ->> hull)::integer, 0)
  end;
$$;

create or replace function private.directive_research_level(e public.empires, tech text)
returns integer
language sql
stable
set search_path = ''
as $$
  select case tech
    when 'combustion_drive' then coalesce(e.propulsion_level, 0)
    when 'energy_tech' then coalesce(e.energy_tech, 0)
    when 'laser_tech' then coalesce(e.laser_tech, 0)
    when 'ion_tech' then coalesce(e.ion_tech, 0)
    when 'hyperspace_tech' then coalesce(e.hyperspace_tech, 0)
    when 'plasma_tech' then coalesce(e.plasma_tech, 0)
    when 'impulse_drive' then coalesce(e.impulse_drive, 0)
    when 'hyperspace_drive' then coalesce(e.hyperspace_drive, 0)
    when 'espionage_tech' then coalesce(e.espionage_tech, 0)
    when 'computer_tech' then coalesce(e.computer_tech, 0)
    when 'astrophysics' then coalesce(e.astrophysics, 0)
    when 'intergalactic_research_network' then coalesce(e.intergalactic_research_network, 0)
    when 'graviton_tech' then coalesce(e.graviton_tech, 0)
    when 'weapons_tech' then coalesce(e.weapons_tech, 0)
    when 'shielding_tech' then coalesce(e.shielding_tech, 0)
    when 'armour_tech' then coalesce(e.armour_tech, 0)
    else 0
  end;
$$;

create or replace function private.directive_defence_count(p public.planets, gun text)
returns integer
language sql
stable
set search_path = ''
as $$
  select case gun
    when 'small_shield_dome' then coalesce(p.small_shield_dome, 0)
    when 'large_shield_dome' then coalesce(p.large_shield_dome, 0)
    when 'rocket_launcher' then coalesce(p.rocket_launcher, 0)
    when 'light_laser' then coalesce(p.light_laser, 0)
    when 'heavy_laser' then coalesce(p.heavy_laser, 0)
    when 'gauss_cannon' then coalesce(p.gauss_cannon, 0)
    when 'ion_cannon' then coalesce(p.ion_cannon, 0)
    when 'plasma_turret' then coalesce(p.plasma_turret, 0)
    when 'antiballistic_missile' then coalesce(p.antiballistic_missile, 0)
    when 'interplanetary_missile' then coalesce(p.interplanetary_missile, 0)
    else 0
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
    when 'yard_foundations' then
      p.robotics_factory >= 2 and p.research_lab >= 1 and p.shipyard >= 1
    when 'energy_theory' then private.directive_research_level(e, 'energy_tech') >= 1
    when 'combustion_fighter' then
      private.directive_research_level(e, 'combustion_drive') >= 1
      and private.directive_ship_count(e, 'light_fighter') >= 1
    when 'rocket_screen' then private.directive_defence_count(p, 'rocket_launcher') >= 5
    when 'orbit_sats' then private.directive_ship_count(e, 'solar_satellite') >= 2
    when 'laser_screen' then
      private.directive_research_level(e, 'laser_tech') >= 3
      and p.shipyard >= 2
      and private.directive_defence_count(p, 'light_laser') >= 5
    when 'small_hauler' then
      private.directive_research_level(e, 'combustion_drive') >= 2
      and private.directive_ship_count(e, 'small_cargo') >= 1
    when 'spy_net' then
      p.research_lab >= 3
      and private.directive_research_level(e, 'espionage_tech') >= 2
      and private.directive_research_level(e, 'combustion_drive') >= 3
      and private.directive_research_level(e, 'computer_tech') >= 1
      and private.directive_ship_count(e, 'espionage_probe') >= 1
    when 'heavy_fighter' then
      private.directive_research_level(e, 'impulse_drive') >= 2
      and private.directive_research_level(e, 'armour_tech') >= 2
      and p.shipyard >= 3
      and private.directive_ship_count(e, 'heavy_fighter') >= 1
    when 'small_dome' then
      private.directive_research_level(e, 'shielding_tech') >= 2
      and private.directive_defence_count(p, 'small_shield_dome') >= 1
    when 'large_hauler' then
      private.directive_research_level(e, 'combustion_drive') >= 6
      and p.shipyard >= 4
      and private.directive_ship_count(e, 'large_cargo') >= 1
    when 'recycler_crew' then private.directive_ship_count(e, 'recycler') >= 1
    when 'colony_line' then
      private.directive_research_level(e, 'impulse_drive') >= 3
      and private.directive_ship_count(e, 'colony_ship') >= 1
    when 'ion_guns' then
      p.research_lab >= 4
      and private.directive_research_level(e, 'energy_tech') >= 4
      and private.directive_research_level(e, 'laser_tech') >= 5
      and private.directive_research_level(e, 'ion_tech') >= 4
      and private.directive_defence_count(p, 'ion_cannon') >= 1
    when 'cruiser_wing' then
      private.directive_research_level(e, 'impulse_drive') >= 4
      and p.shipyard >= 5
      and private.directive_ship_count(e, 'cruiser') >= 1
    when 'crawler_line' then
      private.directive_research_level(e, 'combustion_drive') >= 4
      and private.directive_research_level(e, 'armour_tech') >= 4
      and private.directive_research_level(e, 'laser_tech') >= 4
      and private.directive_ship_count(e, 'crawler') >= 1
    when 'heavy_laser_battery' then
      private.directive_research_level(e, 'energy_tech') >= 3
      and private.directive_research_level(e, 'laser_tech') >= 6
      and private.directive_defence_count(p, 'heavy_laser') >= 5
    when 'hyperspace_theory' then
      p.research_lab >= 7
      and private.directive_research_level(e, 'energy_tech') >= 5
      and private.directive_research_level(e, 'shielding_tech') >= 5
      and private.directive_research_level(e, 'hyperspace_tech') >= 3
      and private.directive_research_level(e, 'hyperspace_drive') >= 2
    when 'pathfinder_scout' then private.directive_ship_count(e, 'pathfinder') >= 1
    when 'gauss_line' then
      private.directive_research_level(e, 'energy_tech') >= 6
      and private.directive_research_level(e, 'weapons_tech') >= 3
      and p.shipyard >= 6
      and private.directive_defence_count(p, 'gauss_cannon') >= 1
    when 'large_dome' then
      private.directive_research_level(e, 'shielding_tech') >= 6
      and private.directive_defence_count(p, 'large_shield_dome') >= 1
    when 'battleship_line' then
      private.directive_research_level(e, 'hyperspace_drive') >= 4
      and p.shipyard >= 7
      and private.directive_ship_count(e, 'battleship') >= 1
    when 'plasma_bomber' then
      private.directive_research_level(e, 'energy_tech') >= 8
      and private.directive_research_level(e, 'laser_tech') >= 10
      and private.directive_research_level(e, 'ion_tech') >= 5
      and private.directive_research_level(e, 'plasma_tech') >= 5
      and private.directive_research_level(e, 'impulse_drive') >= 6
      and p.shipyard >= 8
      and private.directive_ship_count(e, 'bomber') >= 1
    when 'plasma_guns' then
      private.directive_research_level(e, 'plasma_tech') >= 7
      and private.directive_defence_count(p, 'plasma_turret') >= 1
    when 'battlecruiser_wing' then
      private.directive_research_level(e, 'hyperspace_drive') >= 5
      and private.directive_research_level(e, 'hyperspace_tech') >= 5
      and private.directive_research_level(e, 'laser_tech') >= 12
      and private.directive_ship_count(e, 'battlecruiser') >= 1
    when 'destroyer_wing' then
      private.directive_research_level(e, 'hyperspace_drive') >= 6
      and p.shipyard >= 9
      and private.directive_ship_count(e, 'destroyer') >= 1
    when 'missile_abm' then
      p.missile_silo >= 2
      and private.directive_defence_count(p, 'antiballistic_missile') >= 1
    when 'missile_ipm' then
      p.missile_silo >= 4
      and private.directive_defence_count(p, 'interplanetary_missile') >= 1
    when 'reaper_wing' then
      private.directive_research_level(e, 'hyperspace_drive') >= 7
      and private.directive_research_level(e, 'hyperspace_tech') >= 6
      and p.shipyard >= 10
      and private.directive_ship_count(e, 'reaper') >= 1
    when 'nanite_works' then
      p.robotics_factory >= 10
      and private.directive_research_level(e, 'computer_tech') >= 10
      and p.nanite_factory >= 1
    when 'deathstar' then
      p.research_lab >= 12
      and private.directive_research_level(e, 'graviton_tech') >= 1
      and p.shipyard >= 12
      and private.directive_ship_count(e, 'deathstar') >= 1
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
    when 'yard_foundations' then ore := 800; crystal := 400; deuterium := 200;
    when 'energy_theory' then crystal := 400; deuterium := 200;
    when 'combustion_fighter' then ore := 2000; crystal := 1000;
    when 'rocket_screen' then ore := 2000;
    when 'orbit_sats' then crystal := 2000; deuterium := 500;
    when 'laser_screen' then ore := 3000; crystal := 2000;
    when 'small_hauler' then ore := 2000; crystal := 2000;
    when 'spy_net' then crystal := 2500; deuterium := 400;
    when 'heavy_fighter' then ore := 4000; crystal := 3000;
    when 'small_dome' then ore := 5000; crystal := 5000;
    when 'large_hauler' then ore := 4000; crystal := 4000;
    when 'recycler_crew' then ore := 5000; crystal := 4000; deuterium := 1000;
    when 'colony_line' then ore := 5000; crystal := 10000; deuterium := 5000;
    when 'ion_guns' then ore := 4000; crystal := 3000;
    when 'cruiser_wing' then ore := 10000; crystal := 4000; deuterium := 1000;
    when 'crawler_line' then ore := 2000; crystal := 2000; deuterium := 1000;
    when 'heavy_laser_battery' then ore := 8000; crystal := 4000;
    when 'hyperspace_theory' then ore := 8000; crystal := 15000; deuterium := 4000;
    when 'pathfinder_scout' then ore := 5000; crystal := 8000; deuterium := 4000;
    when 'gauss_line' then ore := 10000; crystal := 8000; deuterium := 1000;
    when 'large_dome' then ore := 20000; crystal := 20000;
    when 'battleship_line' then ore := 20000; crystal := 8000;
    when 'plasma_bomber' then ore := 25000; crystal := 15000; deuterium := 8000;
    when 'plasma_guns' then ore := 25000; crystal := 25000; deuterium := 15000;
    when 'battlecruiser_wing' then ore := 20000; crystal := 25000; deuterium := 8000;
    when 'destroyer_wing' then ore := 30000; crystal := 25000; deuterium := 8000;
    when 'missile_abm' then ore := 8000; crystal := 4000; deuterium := 2000;
    when 'missile_ipm' then ore := 8000; crystal := 2000; deuterium := 5000;
    when 'reaper_wing' then ore := 40000; crystal := 30000; deuterium := 10000;
    when 'nanite_works' then ore := 50000; crystal := 25000; deuterium := 10000;
    when 'deathstar' then ore := 100000; crystal := 80000; deuterium := 20000;
    else raise exception 'Unknown directive.';
  end case;
end;
$$;

create or replace function public.set_directive_tracked(p_id text, p_tracked boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_id is null or not private.directive_known(p_id) then
    raise exception 'Unknown directive.';
  end if;

  select * into e from public.empires where user_id = uid for update;
  if not found then
    raise exception 'No empire.';
  end if;

  if p_tracked then
    if private.directive_claimed(e.claimed_directives, p_id) then
      raise exception 'Already collected.';
    end if;
    if not (coalesce(e.tracked_directives, '[]'::jsonb) @> jsonb_build_array(p_id)) then
      update public.empires
      set tracked_directives = coalesce(tracked_directives, '[]'::jsonb) || jsonb_build_array(p_id)
      where user_id = uid;
    end if;
  else
    update public.empires
    set tracked_directives = coalesce((
      select jsonb_agg(to_jsonb(elem))
      from jsonb_array_elements_text(coalesce(tracked_directives, '[]'::jsonb)) elem
      where elem is distinct from p_id
    ), '[]'::jsonb)
    where user_id = uid;
  end if;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

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
  if p_id is null or not private.directive_known(p_id) then
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
  set
    claimed_directives = coalesce(claimed_directives, '[]'::jsonb) || jsonb_build_array(p_id),
    tracked_directives = coalesce((
      select jsonb_agg(to_jsonb(elem))
      from jsonb_array_elements_text(coalesce(tracked_directives, '[]'::jsonb)) elem
      where elem is distinct from p_id
    ), '[]'::jsonb)
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function private.directive_ids() from public, anon, authenticated;
revoke all on function private.directive_known(text) from public, anon, authenticated;
revoke all on function private.directive_ship_count(public.empires, text) from public, anon, authenticated;
revoke all on function private.directive_research_level(public.empires, text) from public, anon, authenticated;
revoke all on function private.directive_defence_count(public.planets, text) from public, anon, authenticated;
revoke all on function public.set_directive_tracked(text, boolean) from public, anon;
grant execute on function public.set_directive_tracked(text, boolean) to authenticated;
revoke all on function public.claim_directive(text) from public, anon;
grant execute on function public.claim_directive(text) to authenticated;

notify pgrst, 'reload schema';
