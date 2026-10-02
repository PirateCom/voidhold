-- Operator-only: found a colony at [1:1:3] for testing abandon and multi-planet flows.

create or replace function public.debug_grant_colony()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  occupant public.planets%rowtype;
  owned integer;
  need_astro integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.require_debug();
  perform private.catch_up(uid, at);

  select * into occupant
  from public.planets
  where galaxy = 1 and system = 1 and slot = 3
  for update;

  if found then
    if occupant.owner_id = uid then
      return private.empire_state_json(uid, timezone('utc', now()));
    end if;
    raise exception 'Slot [1:1:3] is already occupied.';
  end if;

  select count(*)::integer into owned from public.planets where owner_id = uid;
  need_astro := greatest(0, 2 * owned - 1);
  update public.empires
  set astrophysics = greatest(astrophysics, need_astro)
  where user_id = uid;

  perform private.found_colony(uid, 1::smallint, 1::smallint, 3::smallint, at);
  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.debug_grant_colony() from public, anon;
grant execute on function public.debug_grant_colony() to authenticated;
