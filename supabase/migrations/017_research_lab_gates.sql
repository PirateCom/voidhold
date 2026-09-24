create or replace function private.research_lab_need(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'energy_tech' then 1
    when 'laser_tech' then 1
    when 'ion_tech' then 4
    when 'hyperspace_tech' then 7
    when 'plasma_tech' then 4
    when 'combustion_drive' then 1
    when 'impulse_drive' then 2
    when 'hyperspace_drive' then 7
    when 'espionage_tech' then 3
    when 'computer_tech' then 1
    when 'astrophysics' then 3
    when 'intergalactic_research_network' then 10
    when 'graviton_tech' then 12
    when 'weapons_tech' then 4
    when 'shielding_tech' then 6
    when 'armour_tech' then 2
    else 1
  end;
$$;

revoke all on function private.research_lab_need(text) from public, anon, authenticated;

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
  lab_need integer;
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
