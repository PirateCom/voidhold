-- Research stays independent of other buildings. The lab is offline while it upgrades.

create or replace function public.start_research(p_id text)
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
  cost_deut bigint;
  lvl integer;
  lab_need integer;
  blocked text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_id is null or p_id not in (
    'energy_tech', 'laser_tech', 'ion_tech', 'hyperspace_tech', 'plasma_tech',
    'combustion_drive', 'impulse_drive', 'hyperspace_drive',
    'espionage_tech', 'computer_tech', 'astrophysics', 'intergalactic_research_network', 'graviton_tech',
    'weapons_tech', 'shielding_tech', 'armour_tech'
  ) then
    raise exception 'Unknown research.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null then
    raise exception 'Research already running.';
  end if;

  if home.upgrade_building = 'research_lab' then
    raise exception 'Research lab is being upgraded.';
  end if;

  lab_need := private.research_lab_need(p_id);
  if home.research_lab < lab_need then
    raise exception 'Needs Research lab %.', lab_need;
  end if;

  blocked := private.research_block(e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  lvl := private.research_level(e, p_id);
  cost_ore := private.research_tech_cost_ore(p_id, lvl);
  cost_crystal := private.research_tech_cost_crystal(p_id, lvl);
  cost_deut := private.research_tech_cost_deuterium(p_id, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut
  where id = home.id;

  update public.empires
  set
    research_tech = p_id,
    research_completes_at = at + make_interval(secs => private.research_time_seconds(lvl))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
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
  e public.empires%rowtype;
  home public.planets%rowtype;
  lvl integer;
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  blocked text;
  star text;
  satellites integer := 0;
  produced numeric;
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_building not in (
    'ore_mine',
    'crystal_mine',
    'deuterium_extractor',
    'power_plant',
    'fusion_reactor',
    'ore_storage',
    'crystal_storage',
    'deuterium_storage',
    'robotics_factory',
    'shipyard',
    'research_lab',
    'alliance_depot',
    'missile_silo',
    'nanite_factory',
    'terraformer',
    'space_station'
  ) then
    if p_building in ('lunar_base', 'phalanx_sensor', 'stargate') then
      raise exception 'Moon facilities wait for a moon.';
    end if;
    raise exception 'Unknown structure.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where owner_id = uid for update;

  if home.upgrade_building is not null then
    raise exception 'An upgrade is already running.';
  end if;

  if p_building = 'research_lab' and e.research_completes_at is not null then
    raise exception 'Research lab is in use.';
  end if;

  blocked := private.facility_block(home, e, p_building);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  if private.planet_fields_used(home) >= private.planet_field_cap(home) then
    raise exception 'No free fields.';
  end if;

  lvl := private.planet_building_level(home, p_building);
  if p_building = 'terraformer' then
    select s.star_type into star
    from public.solar_systems s
    where s.galaxy = home.galaxy and s.system = home.system;
    satellites := coalesce((e.ships->>'solar_satellite')::integer, 0);
    produced := private.energy_output(
      home.power_plant,
      coalesce(star, 'medium'),
      home.fusion_reactor,
      e.energy_tech,
      satellites,
      home.temp_min,
      home.temp_max
    );
    if produced < private.terraformer_energy(lvl) then
      raise exception 'Need more energy.';
    end if;
  end if;

  cost_ore := private.building_cost_ore(p_building, lvl);
  cost_crystal := private.building_cost_crystal(p_building, lvl);
  cost_deut := private.building_cost_deuterium(p_building, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut,
    upgrade_building = p_building,
    upgrade_completes_at = at + make_interval(
      secs => private.building_time_seconds(lvl, home.robotics_factory, home.nanite_factory)
    )
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
