-- Debug: dock every hull and raise the research floors needed to fly spy / harvest / colonize.

create or replace function public.debug_grant_fleet()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  home public.planets%rowtype;
  fleet jsonb := '{
    "light_fighter": 20,
    "heavy_fighter": 20,
    "cruiser": 10,
    "battleship": 10,
    "battlecruiser": 5,
    "bomber": 5,
    "destroyer": 5,
    "deathstar": 1,
    "small_cargo": 20,
    "large_cargo": 20,
    "colony_ship": 10,
    "recycler": 20,
    "espionage_probe": 50,
    "reaper": 5,
    "pathfinder": 5,
    "crawler": 10,
    "solar_satellite": 10
  }'::jsonb;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set deuterium = greatest(deuterium, least(private.storage_cap(deuterium_storage), 50000))
  where id = home.id;

  update public.empires
  set
    ships = fleet,
    raiders = 20,
    propulsion_level = greatest(propulsion_level, 6),
    energy_tech = greatest(energy_tech, 1),
    impulse_drive = greatest(impulse_drive, 5),
    espionage_tech = greatest(espionage_tech, 2),
    astrophysics = greatest(astrophysics, 1),
    shielding_tech = greatest(shielding_tech, 2)
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.debug_grant_fleet() from public, anon;
grant execute on function public.debug_grant_fleet() to authenticated;

notify pgrst, 'reload schema';
