-- Official OGame technology costs and the small-cargo research gate.
-- Deuterium and the 300,000 energy graviton cost are recorded in the client and are not charged.

create or replace function private.research_tech_cost_ore(id text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor((case id
    when 'energy_tech' then 0
    when 'laser_tech' then 200
    when 'ion_tech' then 1000
    when 'hyperspace_tech' then 0
    when 'plasma_tech' then 2000
    when 'combustion_drive' then 400
    when 'impulse_drive' then 2000
    when 'hyperspace_drive' then 10000
    when 'espionage_tech' then 200
    when 'computer_tech' then 0
    when 'astrophysics' then 4000
    when 'intergalactic_research_network' then 240000
    when 'graviton_tech' then 0
    when 'weapons_tech' then 800
    when 'shielding_tech' then 200
    when 'armour_tech' then 1000
    else 0
  end) * power(case when id = 'astrophysics' then 1.75 else 2 end, greatest(current_level, 0)))::bigint;
$$;

create or replace function private.research_tech_cost_crystal(id text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor((case id
    when 'energy_tech' then 800
    when 'laser_tech' then 100
    when 'ion_tech' then 300
    when 'hyperspace_tech' then 4000
    when 'plasma_tech' then 4000
    when 'combustion_drive' then 0
    when 'impulse_drive' then 4000
    when 'hyperspace_drive' then 20000
    when 'espionage_tech' then 1000
    when 'computer_tech' then 400
    when 'astrophysics' then 8000
    when 'intergalactic_research_network' then 400000
    when 'graviton_tech' then 0
    when 'weapons_tech' then 200
    when 'shielding_tech' then 600
    when 'armour_tech' then 0
    else 0
  end) * power(case when id = 'astrophysics' then 1.75 else 2 end, greatest(current_level, 0)))::bigint;
$$;

create or replace function private.research_block(e public.empires, id text)
returns text
language plpgsql
stable
set search_path = ''
as $$
begin
  if id = 'laser_tech' and private.research_level(e, 'energy_tech') < 2 then
    return 'Needs Energy technology 2.';
  elsif id = 'ion_tech' and private.research_level(e, 'laser_tech') < 5 then
    return 'Needs Laser technology 5.';
  elsif id = 'ion_tech' and private.research_level(e, 'energy_tech') < 4 then
    return 'Needs Energy technology 4.';
  elsif id = 'hyperspace_tech' and private.research_level(e, 'shielding_tech') < 5 then
    return 'Needs Shielding technology 5.';
  elsif id = 'hyperspace_tech' and private.research_level(e, 'energy_tech') < 5 then
    return 'Needs Energy technology 5.';
  elsif id = 'plasma_tech' and private.research_level(e, 'energy_tech') < 8 then
    return 'Needs Energy technology 8.';
  elsif id = 'plasma_tech' and private.research_level(e, 'laser_tech') < 10 then
    return 'Needs Laser technology 10.';
  elsif id = 'plasma_tech' and private.research_level(e, 'ion_tech') < 5 then
    return 'Needs Ion technology 5.';
  elsif id = 'combustion_drive' and private.research_level(e, 'energy_tech') < 1 then
    return 'Needs Energy technology 1.';
  elsif id = 'impulse_drive' and private.research_level(e, 'energy_tech') < 1 then
    return 'Needs Energy technology 1.';
  elsif id = 'hyperspace_drive' and private.research_level(e, 'energy_tech') < 5 then
    return 'Needs Energy technology 5.';
  elsif id = 'hyperspace_drive' and private.research_level(e, 'shielding_tech') < 5 then
    return 'Needs Shielding technology 5.';
  elsif id = 'hyperspace_drive' and private.research_level(e, 'hyperspace_tech') < 3 then
    return 'Needs Hyperspace technology 3.';
  elsif id = 'astrophysics' and private.research_level(e, 'espionage_tech') < 4 then
    return 'Needs Espionage technology 4.';
  elsif id = 'astrophysics' and private.research_level(e, 'impulse_drive') < 3 then
    return 'Needs Impulse drive 3.';
  elsif id = 'intergalactic_research_network' and private.research_level(e, 'computer_tech') < 8 then
    return 'Needs Computer technology 8.';
  elsif id = 'intergalactic_research_network' and private.research_level(e, 'hyperspace_tech') < 8 then
    return 'Needs Hyperspace technology 8.';
  elsif id = 'shielding_tech' and private.research_level(e, 'energy_tech') < 3 then
    return 'Needs Energy technology 3.';
  end if;
  return null;
end;
$$;

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
  lvl integer;
  valid boolean;
  blocked text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  valid := p_id in (
    'energy_tech',
    'laser_tech',
    'ion_tech',
    'hyperspace_tech',
    'plasma_tech',
    'combustion_drive',
    'impulse_drive',
    'hyperspace_drive',
    'espionage_tech',
    'computer_tech',
    'astrophysics',
    'intergalactic_research_network',
    'graviton_tech',
    'weapons_tech',
    'shielding_tech',
    'armour_tech'
  );
  if not valid then
    raise exception 'Unknown research.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null then
    raise exception 'Research already running.';
  end if;

  blocked := private.research_block(e, p_id);
  if blocked is not null then
    raise exception '%', blocked;
  end if;

  lvl := private.research_level(e, p_id);
  cost_ore := private.research_tech_cost_ore(p_id, lvl);
  cost_crystal := private.research_tech_cost_crystal(p_id, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set
    research_tech = p_id,
    research_completes_at = at + make_interval(secs => private.research_time_seconds(lvl))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.queue_raiders(p_count integer)
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
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'Build at least one small cargo.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.propulsion_level < 2 then
    raise exception 'Needs Combustion drive 2.';
  end if;

  cost_ore := 2000 * p_count;
  cost_crystal := 2000 * p_count;
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set
    raiders_queued = e.raiders_queued + p_count,
    raider_completes_at = case
      when e.raiders_queued = 0 then at + make_interval(secs => 15)
      else e.raider_completes_at
    end
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
