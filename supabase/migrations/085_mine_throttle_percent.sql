-- 085: Per-mine output throttle (0% to 100% in 10% increments) scaling both production and energy drain,
-- multi-hull expeditions with Pathfinder ×2 bonus, and standard ×1 solar multiplier across all systems.

create or replace function private.star_multiplier(star_type text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 1::numeric;
$$;

revoke all on function private.star_multiplier(text) from public, anon, authenticated;

alter table public.planets
  add column if not exists ore_mine_pct smallint not null default 100
    check (ore_mine_pct between 0 and 100 and ore_mine_pct % 10 = 0),
  add column if not exists crystal_mine_pct smallint not null default 100
    check (crystal_mine_pct between 0 and 100 and crystal_mine_pct % 10 = 0),
  add column if not exists deuterium_extractor_pct smallint not null default 100
    check (deuterium_extractor_pct between 0 and 100 and deuterium_extractor_pct % 10 = 0);

create or replace function private.tick_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
stable
set search_path = ''
as $$
declare
  elapsed numeric;
  worked numeric;
  factor numeric;
  factor_fusion numeric;
  ore_add bigint;
  crystal_add bigint;
  deut_add bigint;
  deut_burn bigint;
  star text;
  energy_tech integer := 0;
  satellites integer := 0;
  crawlers integer := 0;
  spd integer := 1;
  ore_pct numeric := greatest(0, least(100, coalesce(p.ore_mine_pct, 100)))::numeric / 100.0;
  cry_pct numeric := greatest(0, least(100, coalesce(p.crystal_mine_pct, 100)))::numeric / 100.0;
  deut_pct numeric := greatest(0, least(100, coalesce(p.deuterium_extractor_pct, 100)))::numeric / 100.0;
  synth numeric;
  burn numeric;
  fusion_live boolean;
  energy_out_with_fusion numeric;
  energy_out_no_fusion numeric;
  energy_out numeric;
  mine_drain numeric;
  bonus numeric := 1;
  flare_bonus numeric := 1;
begin
  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p.galaxy and s.system = p.system;

  if exists (
    select 1 from public.stellar_events se
    where se.galaxy = p.galaxy
      and se.system = p.system
      and se.kind = 'solar_flare'
      and se.ends_at > at
  ) then
    flare_bonus := 1.25;
  end if;

  if p.owner_id is not null then
    select
      e.energy_tech,
      coalesce((e.ships->>'solar_satellite')::integer, 0),
      coalesce(e.economy_speed, 1),
      coalesce((e.ships->>'crawler')::integer, 0)
      into energy_tech, satellites, spd, crawlers
    from public.empires e
    where e.user_id = p.owner_id;
  end if;

  elapsed := greatest(0, extract(epoch from (at - p.last_harvested_at)));
  worked := elapsed * greatest(coalesce(spd, 1), 1);

  mine_drain :=
    floor(private.mine_energy_drain(p.ore_mine) * ore_pct)
    + floor(private.mine_energy_drain(p.crystal_mine) * cry_pct)
    + floor(private.deut_energy_drain(p.deuterium_extractor) * deut_pct);

  energy_out_with_fusion := private.energy_output(
    p.power_plant,
    coalesce(star, 'medium'),
    p.fusion_reactor,
    coalesce(energy_tech, 0),
    coalesce(satellites, 0),
    p.temp_min,
    p.temp_max
  );

  energy_out_no_fusion := private.energy_output(
    p.power_plant,
    coalesce(star, 'medium'),
    0,
    coalesce(energy_tech, 0),
    coalesce(satellites, 0),
    p.temp_min,
    p.temp_max
  );

  factor_fusion := case
    when mine_drain <= 0 then 1
    else least(1::numeric, energy_out_with_fusion / mine_drain)
  end;

  synth := private.deut_prod_per_hour(p.deuterium_extractor, p.temp_max, p.temp_min) * deut_pct * flare_bonus;
  burn := private.fusion_deut_burn_per_hour(p.fusion_reactor);
  fusion_live := coalesce(p.fusion_reactor, 0) <= 0
    or p.deuterium + synth * factor_fusion * worked / private.game_hour_seconds() >= burn * worked / private.game_hour_seconds();

  energy_out := case when fusion_live then energy_out_with_fusion else energy_out_no_fusion end;
  factor := case
    when mine_drain <= 0 then 1
    else least(1::numeric, energy_out / mine_drain)
  end;

  bonus := private.crawler_production_bonus(
    private.working_crawlers(
      crawlers,
      p.ore_mine,
      p.crystal_mine,
      p.deuterium_extractor,
      energy_out,
      mine_drain
    )
  );

  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * ore_pct * flare_bonus * factor * bonus * worked / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * cry_pct * flare_bonus * factor * bonus * worked / private.game_hour_seconds())::bigint;
  deut_add := floor(synth * factor * bonus * worked / private.game_hour_seconds())::bigint;
  deut_burn := case when fusion_live then floor(burn * worked / private.game_hour_seconds())::bigint else 0 end;

  p.ore := least(private.storage_cap(p.ore_storage), p.ore + ore_add);
  p.crystal := least(private.storage_cap(p.crystal_storage), p.crystal + crystal_add);
  p.deuterium := least(
    private.storage_cap(p.deuterium_storage),
    greatest(0, p.deuterium + deut_add - deut_burn)
  );
  p.last_harvested_at := at;
  return p;
end;
$$;

create or replace function public.set_mine_percent(p_mine text, p_pct integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  e public.empires%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_mine not in ('ore_mine', 'crystal_mine', 'deuterium_extractor') then
    raise exception 'Unknown mine.';
  end if;
  if p_pct is null or p_pct < 0 or p_pct > 100 or (p_pct % 10) <> 0 then
    raise exception 'Mine output must be between 0%% and 100%% in 10%% steps.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;

  update public.planets
  set
    ore_mine_pct = case when p_mine = 'ore_mine' then p_pct::smallint else ore_mine_pct end,
    crystal_mine_pct = case when p_mine = 'crystal_mine' then p_pct::smallint else crystal_mine_pct end,
    deuterium_extractor_pct = case when p_mine = 'deuterium_extractor' then p_pct::smallint else deuterium_extractor_pct end
  where id = e.home_planet_id and owner_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.set_mine_percent(text, integer) from public, anon;
grant execute on function public.set_mine_percent(text, integer) to authenticated;

create or replace function public.send_expedition_to(p_galaxy smallint, p_system smallint, p_slot smallint, p_ships jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  origin public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  ships jsonb := '{}'::jsonb;
  rec record;
  have integer;
  total integer := 0;
  effective_cargo_units integer := 0;
  has_pathfinder boolean := false;
  active integer;
  cap integer;
  flight integer;
  fuel bigint := 0;
  distance integer;
  slowest integer := null;
  spd integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 or p_slot < 1 or p_slot > 16 then
    raise exception 'That coordinate is outside the universe.';
  end if;
  if p_slot <> 16 and exists (
    select 1 from public.planets pl
    where pl.galaxy = p_galaxy and pl.system = p_system and pl.slot = p_slot
  ) then
    raise exception 'Expeditions need an empty slot or position 16.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into origin from public.planets where id = e.home_planet_id for update;

  if e.astrophysics < 1 then
    raise exception 'Needs Astronomy 1.';
  end if;

  for rec in
    select key, floor((value)::numeric)::integer as n
    from jsonb_each_text(coalesce(p_ships, '{}'::jsonb))
  loop
    if rec.n > 0 then
      if private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive, e.propulsion_level) <= 0 then
        raise exception 'That hull cannot fly.';
      end if;
      have := case
        when rec.key = 'small_cargo' then e.raiders
        else coalesce((e.ships ->> rec.key)::integer, 0)
      end;
      if have < rec.n then
        raise exception 'Not enough docked ships.';
      end if;
      ships := ships || jsonb_build_object(rec.key, rec.n);
      total := total + rec.n;
      effective_cargo_units := effective_cargo_units + greatest(1, floor(private.unit_cargo(rec.key) / 5000.0)::integer) * rec.n;
      if rec.key = 'pathfinder' then
        has_pathfinder := true;
      end if;
    end if;
  end loop;

  if total < 1 then
    raise exception 'Select at least one ship.';
  end if;

  if has_pathfinder then
    effective_cargo_units := effective_cargo_units * 2;
  end if;

  cap := private.expedition_fleet_cap(e.astrophysics);
  select count(*)::integer into active
  from public.fleets
  where owner_id = uid
    and status = 'en_route'
    and mission in ('expedition', 'expedition_hold', 'expedition_return');
  if active >= cap then
    raise exception 'No free expedition slots.';
  end if;

  distance := private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, p_galaxy, p_system, p_slot);
  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    fuel := fuel + private.fleet_fuel_round_trip(rec.n, private.ship_fuel(rec.key, e.impulse_drive), distance);
    spd := private.ship_speed(rec.key, e.impulse_drive, e.hyperspace_drive, e.propulsion_level);
    if slowest is null or spd < slowest then
      slowest := spd;
    end if;
  end loop;

  flight := private.wiki_travel_seconds(distance, coalesce(slowest, 5000), 100);
  if origin.deuterium < fuel then
    raise exception 'Not enough resources.';
  end if;

  for rec in select key, value::integer as n from jsonb_each_text(ships) loop
    origin.ships := private.bump_ship(origin.ships, rec.key, -rec.n);
  end loop;
  e.ships := origin.ships;
  e.raiders := coalesce((origin.ships->>'small_cargo')::integer, 0);

  update public.planets
  set
    deuterium = origin.deuterium - fuel,
    ships = origin.ships
  where id = origin.id;

  update public.empires
  set
    raiders = e.raiders,
    ships = e.ships
  where user_id = uid;

  insert into public.fleets (
    owner_id, origin_planet_id, dest_planet_id, dest_galaxy, dest_system, dest_slot,
    raiders, mission, arrives_at, composition, flight_seconds
  )
  values (
    uid, origin.id, null, p_galaxy, p_system, p_slot,
    effective_cargo_units, 'expedition', at + make_interval(secs => flight), ships,
    flight
  );

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.send_expedition_to(smallint, smallint, smallint, jsonb) from public, anon;
grant execute on function public.send_expedition_to(smallint, smallint, smallint, jsonb) to authenticated;

create or replace function private.ensure_universe_events(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  home public.planets%rowtype;
  free_slot smallint;
  ev_kind text;
  ships_json jsonb;
  defs_json jsonb;
  total_h bigint;
begin
  delete from public.stellar_events where ends_at <= at;
  delete from public.pirate_strongholds ps
  where ps.expires_at <= at
     or ps.current_hull <= 0
     or exists (
       select 1 from public.planets p
       where p.galaxy = ps.galaxy and p.system = ps.system and p.slot = ps.slot
     );

  select p.* into home
  from public.planets p
  join public.empires e on e.home_planet_id = p.id
  where e.user_id = uid;

  if not found then
    return;
  end if;

  if not exists (
    select 1 from public.stellar_events
    where galaxy = home.galaxy
      and ends_at > at
  ) then
    ev_kind := (array['solar_flare', 'ion_storm', 'meteor_shower'])[1 + floor(random() * 3)::int];
    insert into public.stellar_events (galaxy, system, kind, starts_at, ends_at)
    values (home.galaxy, home.system, ev_kind, at, at + interval '3 hours')
    on conflict (galaxy, system) do update
      set kind = excluded.kind,
          starts_at = excluded.starts_at,
          ends_at = excluded.ends_at;

    if ev_kind = 'meteor_shower' then
      update public.asteroid_belts
      set crystal = crystal + 4500,
          depleted_at = null
      where galaxy = home.galaxy and system = home.system;
    end if;
  end if;

  if not exists (
    select 1 from public.pirate_strongholds
    where galaxy = home.galaxy
      and system = home.system
      and expires_at > at
  ) then
    select s.slot::smallint into free_slot
    from generate_series(1, 15) as s(slot)
    where not exists (
      select 1 from public.planets p
      where p.galaxy = home.galaxy and p.system = home.system and p.slot = s.slot
    )
    and not exists (
      select 1 from public.fleets f
      where f.status = 'en_route'
        and f.mission = 'colonize'
        and f.dest_galaxy = home.galaxy
        and f.dest_system = home.system
        and f.dest_slot = s.slot
    )
    order by random()
    limit 1;

    if free_slot is not null then
      ships_json := jsonb_build_object(
        'light_fighter', 12,
        'heavy_fighter', 6,
        'cruiser', 2
      );
      defs_json := jsonb_build_object(
        'rocket_launcher', 15,
        'light_laser', 8,
        'heavy_laser', 2
      );
      total_h := private.stronghold_hull_of(ships_json, defs_json);
      insert into public.pirate_strongholds (
        galaxy, system, slot, name, tier, ships, defenses,
        vault_ore, vault_crystal, vault_deuterium,
        max_hull, current_hull, expires_at
      ) values (
        home.galaxy, home.system, free_slot,
        'Corsair Bastion', 1, ships_json, defs_json,
        20000, 12000, 6000,
        total_h, total_h,
        at + interval '24 hours'
      )
      on conflict (galaxy, system, slot) do nothing;
    end if;
  end if;
end;
$$;

revoke all on function private.ensure_universe_events(uuid, timestamptz) from public, anon, authenticated;

notify pgrst, 'reload schema';
