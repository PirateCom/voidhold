-- New homeworlds land 1-3 systems from an existing commander (slots 4, 8 or 12 first,
-- then any slot 4-12, then a widening search). Colonies or homeworlds can be abandoned
-- once the commander owns another planet and no fleets are moving to or from it.

create or replace function private.find_homeworld_slot()
returns smallint[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  anchor record;
  dist integer;
  dir integer;
  sys integer;
  sl integer;
  pass integer;
  slots integer[];
  attempt integer := 0;
  gal integer;
begin
  select p.galaxy, p.system into anchor
  from public.planets p
  where p.owner_id is not null
  order by (p.owner_id = private.fake_commander_id()), random()
  limit 1;

  if found then
    for pass in 1..2 loop
      for dist in 1..50 loop
        if pass = 1 and dist > 3 then
          exit;
        end if;
        for dir in select d from unnest(array[-1, 1]) d order by random() loop
          sys := ((anchor.system - 1 + dir * dist) % 499 + 499) % 499 + 1;
          if pass = 1 then
            slots := array(select s from unnest(array[4, 8, 12]) s order by random());
          else
            slots := array(select s from generate_series(4, 12) s order by random());
          end if;
          foreach sl in array slots loop
            if not exists (
              select 1 from public.planets p
              where p.galaxy = anchor.galaxy and p.system = sys and p.slot = sl
            ) then
              return array[anchor.galaxy, sys, sl]::smallint[];
            end if;
          end loop;
        end loop;
      end loop;
    end loop;
  end if;

  while attempt < 200 loop
    attempt := attempt + 1;
    gal := 1 + floor(random() * 9)::integer;
    sys := 1 + floor(random() * 499)::integer;
    sl := (array[4, 8, 12])[1 + floor(random() * 3)::integer];
    if not exists (
      select 1 from public.planets p
      where p.galaxy = gal and p.system = sys and p.slot = sl
    ) then
      return array[gal, sys, sl]::smallint[];
    end if;
  end loop;

  raise exception 'The void is full. No free worlds remain.';
end;
$$;

revoke all on function private.find_homeworld_slot() from public, anon, authenticated;

create or replace function private.bootstrap_empire(uid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  spot smallint[];
  planet_id bigint;
  display text;
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

  spot := private.find_homeworld_slot();

  -- Homeworlds are 12,800 km: floor(12.8^2) = 163 fields, plus 10 universe fields = 173.
  fields := floor(power(12800::numeric / 1000, 2))::integer + 10;
  temp_shift := (floor(random() * 21) - 10)::integer;

  insert into public.planets (
    owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at,
    ore_mine, crystal_mine, power_plant,
    temp_min, temp_max, max_fields, diameter_km
  )
  values (
    uid, spot[1], spot[2], spot[3], 'Homeworld', 1200, 500, timezone('utc', now()),
    1, 1, 1,
    (private.slot_temp_min(spot[3]) + temp_shift)::smallint,
    (private.slot_temp_max(spot[3]) + temp_shift)::smallint,
    fields,
    12800
  )
  returning id into planet_id;

  insert into public.empires (user_id, home_planet_id)
  values (uid, planet_id);

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

create or replace function public.abandon_planet(p_planet_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  target public.planets;
  next_id bigint;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into target
  from public.planets
  where id = p_planet_id and owner_id = uid
  for update;
  if not found then
    raise exception 'That is not your planet.';
  end if;

  perform private.catch_up(uid, timezone('utc', now()));

  if (select count(*) from public.planets where owner_id = uid) < 2 then
    raise exception 'You need at least one other planet before abandoning this one.';
  end if;

  if exists (
    select 1 from public.fleets f
    where f.status = 'en_route'
      and (f.origin_planet_id = p_planet_id or f.dest_planet_id = p_planet_id)
  ) then
    raise exception 'Fleets are still moving to or from this planet.';
  end if;

  select id into next_id
  from public.planets
  where owner_id = uid and id <> p_planet_id
  order by is_homeworld desc, id
  limit 1;

  update public.empires
  set home_planet_id = next_id
  where user_id = uid and home_planet_id = p_planet_id;

  if target.is_homeworld then
    update public.planets set is_homeworld = true where id = next_id;
  end if;

  delete from public.fleets
  where origin_planet_id = p_planet_id or dest_planet_id = p_planet_id;

  delete from public.planets where id = p_planet_id;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.abandon_planet(bigint) from public, anon;
grant execute on function public.abandon_planet(bigint) to authenticated;

notify pgrst, 'reload schema';
