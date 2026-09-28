-- Pin / unpin beginner directives. Resources only shows tracked, unclaimed ones.

alter table public.empires
  add column if not exists tracked_directives jsonb not null default '[]'::jsonb;

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
  if p_id is null or p_id not in (
    'ore_l1', 'energy', 'ore_l2', 'solar_l2', 'ore_solar_mid',
    'crystal_l1', 'continue_prod', 'deuterium_l1', 'sufficient', 'storage'
  ) then
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

revoke all on function public.set_directive_tracked(text, boolean) from public, anon;
grant execute on function public.set_directive_tracked(text, boolean) to authenticated;

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
  if p_id is null or p_id not in (
    'ore_l1', 'energy', 'ore_l2', 'solar_l2', 'ore_solar_mid',
    'crystal_l1', 'continue_prod', 'deuterium_l1', 'sufficient', 'storage'
  ) then
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

notify pgrst, 'reload schema';
