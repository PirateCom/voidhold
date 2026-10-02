-- Test commander with a homeworld at [1:1:2]. No password, so nobody can sign in as it.

do $$
declare
  fake_id uuid := '00000000-0000-4000-8000-00000000f001';
  planet_id bigint;
  fields integer := floor(power(12800::numeric / 1000, 2))::integer + 10;
begin
  if exists (select 1 from public.empires where user_id = fake_id) then
    return;
  end if;
  if exists (select 1 from public.planets where galaxy = 1 and system = 1 and slot = 2) then
    raise exception '[1:1:2] is already taken.';
  end if;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  )
  values (
    fake_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test.commander@voidhold.invalid',
    '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do nothing;

  insert into public.profiles (user_id, display_name)
  values (fake_id, 'Test Commander')
  on conflict (user_id) do update set display_name = excluded.display_name;

  insert into public.planets (
    owner_id, galaxy, system, slot, name, ore, crystal, last_harvested_at,
    ore_mine, crystal_mine, power_plant,
    temp_min, temp_max, max_fields, diameter_km
  )
  values (
    fake_id, 1, 1, 2, 'Test Homeworld', 1200, 500, timezone('utc', now()),
    1, 1, 1,
    private.slot_temp_min(2)::smallint,
    private.slot_temp_max(2)::smallint,
    fields,
    12800
  )
  returning id into planet_id;

  insert into public.empires (user_id, home_planet_id)
  values (fake_id, planet_id);
end;
$$;
