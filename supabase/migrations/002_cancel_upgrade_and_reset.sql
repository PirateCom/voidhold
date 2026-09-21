-- Cancel in-progress upgrades with remaining-time refunds, plus a debug reset.

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
  refund_ore bigint;
  refund_crystal bigint;
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

  lvl := case home.upgrade_building
    when 'ore_mine' then home.ore_mine
    when 'crystal_mine' then home.crystal_mine
    else home.power_plant
  end;
  duration_secs := greatest(private.building_time_seconds(lvl), 1);
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
  refund_ore := floor(cost_ore * (1.0 - progress))::bigint;
  refund_crystal := floor(cost_crystal * (1.0 - progress))::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_mine), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_mine), home.crystal + refund_crystal),
    upgrade_building = null,
    upgrade_completes_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.reset_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.fleets where owner_id = uid;
  delete from public.battle_reports where user_id = uid;

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    power_plant = 1,
    upgrade_building = null,
    upgrade_completes_at = null
  where owner_id = uid;

  update public.empires
  set
    propulsion_level = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    research_completes_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.cancel_upgrade() from public, anon;
revoke all on function public.reset_empire() from public, anon;
grant execute on function public.cancel_upgrade() to authenticated;
grant execute on function public.reset_empire() to authenticated;
