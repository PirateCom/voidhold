-- Cap defence yard orders at 999. Cancel remaining guns for a full refund (storage capped).
-- Wiki silo: 10 ABM slots per level, one IPM takes two slots.

create or replace function public.queue_defence(p_id text, p_count integer)
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
  pending integer;
  valid boolean;
  blocked text;
  abm integer;
  ipm integer;
  slots integer;
  used integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  valid := p_id in (
    'small_shield_dome',
    'large_shield_dome',
    'rocket_launcher',
    'light_laser',
    'heavy_laser',
    'ion_cannon',
    'gauss_cannon',
    'plasma_turret',
    'antiballistic_missile',
    'interplanetary_missile'
  );
  if not valid then
    raise exception 'Unknown defence.';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one.';
  end if;
  if p_count > 999 then
    raise exception 'Yard queue holds at most 999.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if home.defences_queued > 0 and home.defence_building is not null and home.defence_building <> p_id then
    raise exception 'Defence yard occupied.';
  end if;
  if home.defences_queued + p_count > 999 then
    raise exception 'Yard queue holds at most 999.';
  end if;

  pending := case when home.defence_building = p_id then home.defences_queued else 0 end;
  if private.defence_is_unique(p_id) and private.defence_owned(home, p_id) + pending + p_count > 1 then
    raise exception 'Only one of those domes fits on this world.';
  end if;

  blocked := private.defence_block(home, e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  if p_id in ('antiballistic_missile', 'interplanetary_missile') then
    abm := greatest(coalesce(home.antiballistic_missile, 0), 0);
    ipm := greatest(coalesce(home.interplanetary_missile, 0), 0);
    if home.defence_building = 'antiballistic_missile' then
      abm := abm + greatest(coalesce(home.defences_queued, 0), 0);
    elsif home.defence_building = 'interplanetary_missile' then
      ipm := ipm + greatest(coalesce(home.defences_queued, 0), 0);
    end if;
    slots := 10 * greatest(coalesce(home.missile_silo, 0), 0);
    used := abm + 2 * ipm;
    if p_id = 'antiballistic_missile' and used + p_count > slots then
      raise exception 'Missile silo is full.';
    end if;
    if p_id = 'interplanetary_missile' and used + 2 * p_count > slots then
      raise exception 'Missile silo is full.';
    end if;
  end if;

  cost_ore := private.defence_cost_ore(p_id) * p_count;
  cost_crystal := private.defence_cost_crystal(p_id) * p_count;
  cost_deut := private.defence_cost_deuterium(p_id) * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal or home.deuterium < cost_deut then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut,
    defence_building = p_id,
    defences_queued = home.defences_queued + p_count,
    defence_completes_at = case
      when home.defences_queued = 0 then at + make_interval(secs => private.unit_build_seconds(home, p_id))
      else home.defence_completes_at
    end
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.queue_defence(text, integer) from public, anon;
grant execute on function public.queue_defence(text, integer) to authenticated;

create or replace function public.cancel_defence()
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
  n integer;
  gun text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  n := greatest(coalesce(home.defences_queued, 0), 0);
  gun := nullif(home.defence_building, '');
  if n < 1 or gun is null then
    raise exception 'Nothing is being built.';
  end if;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + private.defence_cost_ore(gun) * n),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + private.defence_cost_crystal(gun) * n),
    deuterium = least(private.storage_cap(home.deuterium_storage), home.deuterium + private.defence_cost_deuterium(gun) * n),
    defence_building = null,
    defences_queued = 0,
    defence_completes_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.cancel_defence() from public, anon;
grant execute on function public.cancel_defence() to authenticated;

notify pgrst, 'reload schema';
