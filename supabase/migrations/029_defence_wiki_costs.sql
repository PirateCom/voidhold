-- Wiki defence costs (https://ogame.fandom.com/wiki/Defense). Rocket launchers are metal only.

create or replace function private.defence_cost_ore(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 10000
    when 'large_shield_dome' then 50000
    when 'rocket_launcher' then 2000
    when 'light_laser' then 1500
    when 'heavy_laser' then 6000
    when 'ion_cannon' then 5000
    when 'gauss_cannon' then 20000
    when 'plasma_turret' then 50000
    when 'antiballistic_missile' then 8000
    when 'interplanetary_missile' then 12500
    else 0
  end;
$$;

create or replace function private.defence_cost_crystal(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'small_shield_dome' then 10000
    when 'large_shield_dome' then 50000
    when 'rocket_launcher' then 0
    when 'light_laser' then 500
    when 'heavy_laser' then 2000
    when 'ion_cannon' then 3000
    when 'gauss_cannon' then 15000
    when 'plasma_turret' then 50000
    when 'antiballistic_missile' then 0
    when 'interplanetary_missile' then 2500
    else 0
  end;
$$;

create or replace function private.defence_cost_deuterium(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'gauss_cannon' then 2000
    when 'plasma_turret' then 30000
    when 'antiballistic_missile' then 2000
    when 'interplanetary_missile' then 10000
    else 0
  end;
$$;

revoke all on function private.defence_cost_deuterium(text) from public, anon, authenticated;

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

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where owner_id = uid for update;

  if home.defences_queued > 0 and home.defence_building is not null and home.defence_building <> p_id then
    raise exception 'Defence yard occupied.';
  end if;

  pending := case when home.defence_building = p_id then home.defences_queued else 0 end;
  if private.defence_is_unique(p_id) and private.defence_owned(home, p_id) + pending + p_count > 1 then
    raise exception 'Only one of those domes fits on this world.';
  end if;

  blocked := private.defence_block(home, e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
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
      when home.defences_queued = 0 then at + make_interval(secs => private.defence_time_seconds(p_id))
      else home.defence_completes_at
    end
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
