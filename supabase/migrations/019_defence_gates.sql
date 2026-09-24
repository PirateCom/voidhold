create or replace function private.defence_block(p public.planets, e public.empires, id text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  yard integer;
  silo integer;
begin
  yard := case id
    when 'rocket_launcher' then 1
    when 'light_laser' then 2
    when 'heavy_laser' then 4
    when 'ion_cannon' then 4
    when 'gauss_cannon' then 6
    when 'plasma_turret' then 8
    when 'small_shield_dome' then 1
    when 'large_shield_dome' then 6
    when 'antiballistic_missile' then 1
    when 'interplanetary_missile' then 1
    else 1
  end;
  if p.shipyard < yard then
    return format('Needs Shipyard %s.', yard);
  end if;

  silo := case id
    when 'antiballistic_missile' then 2
    when 'interplanetary_missile' then 4
    else 0
  end;
  if silo > 0 and p.missile_silo < silo then
    return format('Needs Missile silo %s.', silo);
  end if;

  if id = 'light_laser' and private.research_level(e, 'energy_tech') < 1 then
    return 'Needs Energy technology 1.';
  elsif id = 'light_laser' and private.research_level(e, 'laser_tech') < 3 then
    return 'Needs Laser technology 3.';
  elsif id = 'heavy_laser' and private.research_level(e, 'energy_tech') < 3 then
    return 'Needs Energy technology 3.';
  elsif id = 'heavy_laser' and private.research_level(e, 'laser_tech') < 6 then
    return 'Needs Laser technology 6.';
  elsif id = 'ion_cannon' and private.research_level(e, 'ion_tech') < 4 then
    return 'Needs Ion technology 4.';
  elsif id = 'gauss_cannon' and private.research_level(e, 'energy_tech') < 6 then
    return 'Needs Energy technology 6.';
  elsif id = 'gauss_cannon' and private.research_level(e, 'weapons_tech') < 3 then
    return 'Needs Weapons technology 3.';
  elsif id = 'gauss_cannon' and private.research_level(e, 'shielding_tech') < 1 then
    return 'Needs Shielding technology 1.';
  elsif id = 'plasma_turret' and private.research_level(e, 'plasma_tech') < 7 then
    return 'Needs Plasma technology 7.';
  elsif id = 'small_shield_dome' and private.research_level(e, 'shielding_tech') < 2 then
    return 'Needs Shielding technology 2.';
  elsif id = 'large_shield_dome' and private.research_level(e, 'shielding_tech') < 6 then
    return 'Needs Shielding technology 6.';
  elsif id = 'interplanetary_missile' and private.research_level(e, 'impulse_drive') < 1 then
    return 'Needs Impulse drive 1.';
  end if;
  return null;
end;
$$;

revoke all on function private.defence_block(public.planets, public.empires, text) from public, anon, authenticated;

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
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
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
