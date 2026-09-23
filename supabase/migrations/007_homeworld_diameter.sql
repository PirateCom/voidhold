-- Homeworlds match a new OGame start: 12,800 km, floor(12.8^2) = 163 fields, plus 10.

update public.planets
set
  diameter_km = 12800,
  max_fields = (floor(power(12800::numeric / 1000, 2)) + 10)::smallint
where owner_id is not null;

create or replace function private.bootstrap_empire(uid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  gal smallint;
  sys smallint;
  sl smallint;
  planet_id bigint;
  display text;
  placed boolean := false;
  attempt integer := 0;
  band numeric;
  fields integer;
  temp_shift integer;
begin
  if exists (select 1 from public.empires where user_id = uid) then
    return private.empire_state_json(uid, timezone('utc', now()));
  end if;

  select coalesce(split_part(u.email, '@', 1), 'Commander')
  into display
  from auth.users u
  where u.id = uid;

  insert into public.profiles (user_id, display_name)
  values (uid, coalesce(nullif(display, ''), 'Commander'))
  on conflict (user_id) do nothing;

  while attempt < 30 and not placed loop
    attempt := attempt + 1;
    gal := (1 + floor(random() * 9))::smallint;
    sys := (1 + floor(random() * 499))::smallint;
    band := random();
    if band < 0.90 then
      sl := (4 + floor(random() * 9))::smallint;
    elsif band < 0.95 then
      sl := (1 + floor(random() * 3))::smallint;
    else
      sl := (13 + floor(random() * 3))::smallint;
    end if;

    if not exists (
      select 1 from public.planets p
      where p.galaxy = gal and p.system = sys and p.slot = sl
    ) then
      placed := true;
    end if;
  end loop;

  if not placed then
    raise exception 'The void is full. No free worlds remain.';
  end if;

  -- Homeworlds are 12,800 km: floor(12.8^2) = 163 fields, plus 10 universe fields = 173.
  fields := floor(power(12800::numeric / 1000, 2))::integer + 10;
  temp_shift := (floor(random() * 21) - 10)::integer;

  insert into public.planets (
    owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at,
    ore_mine, crystal_mine, power_plant,
    temp_min, temp_max, max_fields, diameter_km
  )
  values (
    uid, gal, sys, sl, 'Homeworld', 1200, 500, timezone('utc', now()),
    1, 1, 1,
    (private.slot_temp_min(sl) + temp_shift)::smallint,
    (private.slot_temp_max(sl) + temp_shift)::smallint,
    fields,
    12800
  )
  returning id into planet_id;

  insert into public.empires (user_id, home_planet_id)
  values (uid, planet_id);

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;
