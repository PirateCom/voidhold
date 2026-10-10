-- Wiki Intergalactic Research Network: extra labs join research time.

create or replace function private.combined_research_lab(
  uid uuid,
  start_planet_id bigint,
  lab_need integer,
  irn integer
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  start_lab integer := 0;
  extra integer := 0;
begin
  select coalesce(p.research_lab, 0) into start_lab
  from public.planets p
  where p.id = start_planet_id
    and p.owner_id = uid;
  if not found then
    start_lab := 0;
  end if;

  select coalesce(sum(x.research_lab), 0) into extra
  from (
    select p.research_lab
    from public.planets p
    where p.owner_id = uid
      and p.id is distinct from start_planet_id
      and p.research_lab >= greatest(coalesce(lab_need, 0), 0)
    order by p.research_lab desc, p.id
    limit greatest(coalesce(irn, 0), 0)
  ) x;

  return start_lab + extra;
end;
$$;

revoke all on function private.combined_research_lab(uuid, bigint, integer, integer)
  from public, anon, authenticated;

create or replace function private.research_duration_seconds(
  current_level integer,
  combined_lab integer,
  start_lab integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    1,
    floor(
      45 * power(1.5, greatest(coalesce(current_level, 0), 0))
      * (1 + greatest(coalesce(start_lab, 0), 0))::numeric
      / (1 + greatest(coalesce(combined_lab, 0), coalesce(start_lab, 0), 0))::numeric
    )
  )::integer;
$$;

revoke all on function private.research_duration_seconds(integer, integer, integer)
  from public, anon, authenticated;

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
  combined integer;
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

  combined := private.combined_research_lab(
    uid,
    home.id,
    lab_need,
    coalesce(e.intergalactic_research_network, 0)
  );

  update public.planets
  set
    ore = home.ore - cost_ore,
    crystal = home.crystal - cost_crystal,
    deuterium = home.deuterium - cost_deut
  where id = home.id;

  update public.empires
  set
    research_tech = p_id,
    research_started_at = at,
    research_completes_at = at + make_interval(
      secs => private.research_duration_seconds(lvl, combined, home.research_lab)
    )
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.start_research(text) from public, anon;
grant execute on function public.start_research(text) to authenticated;

create or replace function private.empire_state_json(uid uuid, at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.prune_battle_reports(at);
  perform private.catch_up(uid, at);
  perform private.catch_up(o.user_id, at)
  from public.empires o
  where o.user_id is distinct from uid;

  select jsonb_build_object(
    'profile', jsonb_build_object(
      'user_id', pr.user_id,
      'display_name', pr.display_name
    ),
    'planet', to_jsonb(p),
    'colonies', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'galaxy', c.galaxy,
        'system', c.system,
        'slot', c.slot,
        'is_homeworld', c.is_homeworld,
        'research_lab', c.research_lab
      ) order by c.is_homeworld desc, c.id), '[]'::jsonb)
      from public.planets c
      where c.owner_id = uid
    ),
    'empire', to_jsonb(e) || jsonb_build_object(
      'ships', coalesce(p.ships, e.ships, '{}'::jsonb),
      'raiders', coalesce((coalesce(p.ships, e.ships)->>'small_cargo')::integer, e.raiders),
      'raiders_queued', p.ships_queued,
      'ship_building', p.ship_building,
      'raider_completes_at', p.ship_completes_at
    ),
    'star', jsonb_build_object(
      'type', coalesce(s.star_type, 'medium'),
      'multiplier', private.star_multiplier(coalesce(s.star_type, 'medium'))
    ),
    'rank', private.rank_payload(uid),
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', case
          when coalesce(f.dest_slot, dp.slot) = 16 then 'Outer space'
          when f.mission in ('harvest', 'harvest_return') then coalesce(dp.name, 'Debris field')
          when f.mission in ('colonize', 'colonize_return') then coalesce(dp.name, 'Empty slot')
          else dp.name
        end,
        'dest_galaxy', coalesce(f.dest_galaxy, dp.galaxy),
        'dest_system', coalesce(f.dest_system, dp.system),
        'dest_slot', coalesce(f.dest_slot, dp.slot),
        'origin_name', coalesce(op.name, 'Deep space'),
        'origin_galaxy', coalesce(op.galaxy, dp.galaxy),
        'origin_system', coalesce(op.system, dp.system),
        'origin_slot', coalesce(op.slot, dp.slot),
        'created_at', f.created_at,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'cargo_deuterium', f.cargo_deuterium,
        'status', f.status,
        'report', f.report,
        'inbound', (f.owner_id is distinct from uid),
        'attacker_name', case when f.owner_id is null then 'Pirates' else ap.display_name end,
        'ship_count', case
          when f.composition is not null and f.composition <> '{}'::jsonb then (
            select coalesce(sum(greatest(value::integer, 0)), 0)::integer
            from jsonb_each_text(f.composition)
          )
          else f.raiders
        end,
        'composition', case
          when f.owner_id is distinct from uid then '{}'::jsonb
          else f.composition
        end
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
      left join public.planets op on op.id = f.origin_planet_id
      left join public.profiles ap on ap.user_id = f.owner_id
      where f.status = 'en_route'
        and (f.owner_id = uid or f.dest_planet_id in (select pl.id from public.planets pl where pl.owner_id = uid))
    ),
    'reports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'title', r.title,
        'body', r.body,
        'loot_ore', r.loot_ore,
        'loot_crystal', r.loot_crystal
      ) order by r.created_at desc), '[]'::jsonb)
      from (
        select * from public.battle_reports
        where user_id = uid
          and created_at > at - interval '7 days'
        order by created_at desc
        limit 15
      ) r
    ),
    'server_now', at,
    'debug', private.debug_operator()
  )
  into result
  from public.empires e
  join public.planets p on p.id = e.home_planet_id
  join public.profiles pr on pr.user_id = e.user_id
  left join public.solar_systems s on s.galaxy = p.galaxy and s.system = p.system
  where e.user_id = uid;

  return result;
end;
$$;

notify pgrst, 'reload schema';
