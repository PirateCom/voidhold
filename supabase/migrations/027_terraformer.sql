-- Wiki terraformer: crystal/deut/energy costs, extra fields = floor(5.5 * level).

create or replace function private.terraformer_energy(current_level integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select floor(1000 * power(2, greatest(coalesce(current_level, 0), 0)));
$$;

create or replace function private.terraformer_extra_fields(level integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select floor(5.5 * greatest(coalesce(level, 0), 0))::integer;
$$;

create or replace function private.planet_field_cap(p public.planets)
returns integer
language sql
immutable
set search_path = ''
as $$
  select p.max_fields + private.terraformer_extra_fields(p.terraformer);
$$;

create or replace function private.energy_output(
  power_plant integer,
  star_type text,
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
      else floor(
        20 * power_plant * power(1.1, power_plant) * private.star_multiplier(star_type)
      )
    end
    + private.fusion_output(coalesce(fusion, 0), coalesce(energy_tech, 0))
    + private.solar_satellite_output(
      coalesce(temp_min, 30),
      coalesce(temp_max, 30),
      star_type,
      coalesce(satellites, 0)
    );
$$;

revoke all on function private.terraformer_energy(integer) from public, anon, authenticated;
revoke all on function private.terraformer_extra_fields(integer) from public, anon, authenticated;
revoke all on function private.planet_field_cap(public.planets) from public, anon, authenticated;
revoke all on function private.energy_output(integer, text, integer, integer, integer, integer, integer) from public, anon, authenticated;

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
