-- Cancelling a mine or facility refunds 75% of the remaining cost (25% is spent to start the job).

create or replace function public.cancel_upgrade()
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
  select * into e from public.empires where user_id = uid;
  select * into home from public.planets where id = e.home_planet_id for update;

  if home.upgrade_building is null or home.upgrade_completes_at is null then
    raise exception 'Nothing is being built.';
  end if;

  lvl := private.planet_building_level(home, home.upgrade_building);
  duration_secs := greatest(
    private.building_time_seconds(
      home.upgrade_building,
      lvl,
      home.robotics_factory,
      home.nanite_factory,
      coalesce(e.economy_speed, 1)
    ),
    1
  );
  start_at := coalesce(
    home.upgrade_started_at,
    home.upgrade_completes_at - make_interval(secs => duration_secs)
  );
  progress := least(
    1.0::double precision,
    greatest(
      0.0::double precision,
      extract(epoch from (at - start_at))
        / greatest(extract(epoch from (home.upgrade_completes_at - start_at)), 1.0)::double precision
    )
  );
  cost_ore := private.building_cost_ore(home.upgrade_building, lvl);
  cost_crystal := private.building_cost_crystal(home.upgrade_building, lvl);
  cost_deut := private.building_cost_deuterium(home.upgrade_building, lvl);
  refund_ore := floor(cost_ore * (1.0::double precision - progress) * 0.75)::bigint;
  refund_crystal := floor(cost_crystal * (1.0::double precision - progress) * 0.75)::bigint;
  refund_deut := floor(cost_deut * (1.0::double precision - progress) * 0.75)::bigint;

  update public.planets
  set
    ore = least(private.storage_cap(home.ore_storage), home.ore + refund_ore),
    crystal = least(private.storage_cap(home.crystal_storage), home.crystal + refund_crystal),
    deuterium = least(private.storage_cap(home.deuterium_storage), home.deuterium + refund_deut),
    upgrade_building = null,
    upgrade_completes_at = null,
    upgrade_started_at = null
  where id = home.id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
