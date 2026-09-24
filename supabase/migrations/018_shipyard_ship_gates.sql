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

  if home.shipyard < 2 then
    raise exception 'Needs Shipyard 2.';
  end if;
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
