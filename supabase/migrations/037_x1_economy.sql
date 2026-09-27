-- x1 economy: 1 game-hour of production is 1 real hour; wiki building construction time.

create or replace function private.economy_speed()
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 1::numeric;
$$;

create or replace function private.game_hour_seconds()
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 3600::numeric;
$$;

drop function if exists private.building_time_seconds(integer, integer, integer);

create function private.building_time_seconds(
  building text,
  current_level integer,
  robotics_level integer default 0,
  nanite_level integer default 0
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    1,
    floor(
      (
        coalesce(private.building_cost_ore(building, current_level), 0)
        + coalesce(private.building_cost_crystal(building, current_level), 0)
      )::numeric
      * 3600
      / (
        2500
        * (1 + greatest(coalesce(robotics_level, 0), 0))
        * power(2, greatest(coalesce(nanite_level, 0), 0))
        * private.economy_speed()
      )
    )::integer
  );
$$;

revoke all on function private.economy_speed() from public, anon, authenticated;
revoke all on function private.building_time_seconds(text, integer, integer, integer) from public, anon, authenticated;

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
      secs => private.building_time_seconds(p_building, lvl, home.robotics_factory, home.nanite_factory)
    )
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.cancel_upgrade()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  lvl integer;
  duration_secs integer;
  start_at timestamptz;
  progress double precision;
  cost_ore bigint;
  cost_crystal bigint;
  cost_deut bigint;
  refund_ore bigint;
  refund_crystal bigint;
  refund_deut bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into home
  from public.planets
  where owner_id = uid
  for update;

  if home.upgrade_building is null or home.upgrade_completes_at is null then
    raise exception 'Nothing is being built.';
  end if;

  lvl := private.planet_building_level(home, home.upgrade_building);
  duration_secs := greatest(
    private.building_time_seconds(
      home.upgrade_building,
      lvl,
      home.robotics_factory,
      home.nanite_factory
    ),
    1
  );
  start_at := home.upgrade_completes_at - make_interval(secs => duration_secs);
  progress := least(
    1.0::double precision,
    greatest(
      0.0::double precision,
      extract(epoch from (at - start_at)) / duration_secs::double precision
    )
  );
  cost_ore := private.building_cost_ore(home.upgrade_building, lvl);
  cost_crystal := private.building_cost_crystal(home.upgrade_building, lvl);
  cost_deut := private.building_cost_deuterium(home.upgrade_building, lvl);
  refund_ore := floor(cost_ore * (1.0::double precision - progress) * 0.5)::bigint;
  refund_crystal := floor(cost_crystal * (1.0::double precision - progress) * 0.5)::bigint;
  refund_deut := floor(cost_deut * (1.0::double precision - progress) * 0.5)::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + refund_crystal),
    deuterium = least(private.storage_cap(home.deuterium_storage), home.deuterium + refund_deut),
    upgrade_building = null,
    upgrade_completes_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
