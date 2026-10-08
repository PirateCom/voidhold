-- Belt remaining ore/crystal is not public on the galaxy map. Spy probes report stock at arrival.

create or replace function public.get_solar_system(p_galaxy smallint, p_system smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  result jsonb;
  star text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 then
    raise exception 'That coordinate is outside the universe.';
  end if;

  delete from public.debris_fields d
  where d.galaxy = p_galaxy and d.system = p_system
    and d.fresh_at <= timezone('utc', now()) - interval '4 hours';

  perform private.tick_asteroid_mining(timezone('utc', now()));

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p_galaxy and s.system = p_system;

  select jsonb_build_object(
    'galaxy', p_galaxy,
    'system', p_system,
    'star_type', coalesce(star, 'medium'),
    'multiplier', private.star_multiplier(coalesce(star, 'medium')),
    'slots', (
      select coalesce(jsonb_agg(row.obj order by row.sort_key), '[]'::jsonb)
      from (
        select
          sl.slot::numeric as sort_key,
          jsonb_build_object(
            'slot', sl.slot,
            'kind', case
              when sl.slot = 16 then 'outer'
              when pl.id is null then 'empty'
              when pl.owner_id = uid then 'home'
              when pl.owner_id is not null then 'player'
              else 'npc'
            end,
            'planet_id', pl.id,
            'name', case when sl.slot = 16 then 'Outer space' else pl.name end,
            'owner_id', pl.owner_id,
            'owner_name', pf.display_name,
            'debris_ore', floor(coalesce(df.ore, 0) * private.debris_factor(df.fresh_at, timezone('utc', now())))::bigint,
            'debris_crystal', floor(coalesce(df.crystal, 0) * private.debris_factor(df.fresh_at, timezone('utc', now())))::bigint,
            'debris_decays_at', df.fresh_at + interval '2 hours',
            'debris_gone_at', df.fresh_at + interval '4 hours'
          ) as obj
        from generate_series(1, 16) as sl(slot)
        left join public.planets pl
          on pl.galaxy = p_galaxy
          and pl.system = p_system
          and pl.slot = sl.slot
          and sl.slot <= 15
        left join public.profiles pf on pf.user_id = pl.owner_id
        left join public.debris_fields df
          on df.galaxy = p_galaxy
          and df.system = p_system
          and df.slot = sl.slot
        union all
        select
          b.after_slot + 0.5 as sort_key,
          jsonb_build_object(
            'slot', b.belt_slot,
            'kind', 'belt',
            'planet_id', null,
            'name', 'Asteroid belt',
            'owner_id', null,
            'owner_name', null,
            'belt_after_slot', b.after_slot
          ) as obj
        from public.asteroid_belts b
        where b.galaxy = p_galaxy and b.system = p_system
      ) row
    )
  )
  into result;

  return result;
end;
$$;

revoke all on function public.get_solar_system(smallint, smallint) from public, anon;
grant execute on function public.get_solar_system(smallint, smallint) to authenticated;

create or replace function private.resolve_belt_espionage(uid uuid, attacker public.empires, f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  belt public.asteroid_belts%rowtype;
  body text;
  miner_lines text;
  flight integer;
  dest_slot smallint;
begin
  perform private.tick_asteroid_mining(f.arrives_at);
  select * into origin from public.planets where id = f.origin_planet_id;
  select * into belt
  from public.asteroid_belts
  where galaxy = coalesce(f.dest_galaxy, origin.galaxy)
    and system = coalesce(f.dest_system, origin.system)
    and belt_slot = coalesce(f.dest_slot, 17);

  select string_agg(
    format(
      '%s: %s barge%s (%s%% full)',
      coalesce(pf.display_name, f2.owner_id::text),
      greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0),
      case when greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) = 1 then '' else 's' end,
      case
        when greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) * private.unit_cargo('mining_barge') <= 0 then 0
        else round(
          100.0 * (f2.cargo_ore + f2.cargo_crystal)
          / (greatest(coalesce((f2.composition->>'mining_barge')::integer, 0), 0) * private.unit_cargo('mining_barge'))
        )
      end
    ),
    E'\n'
  )
  into miner_lines
  from public.fleets f2
  left join public.profiles pf on pf.user_id = f2.owner_id
  where f2.status = 'en_route'
    and f2.mission = 'mine_hold'
    and coalesce(f2.dest_galaxy, 1) = coalesce(f.dest_galaxy, origin.galaxy)
    and coalesce(f2.dest_system, 0) = coalesce(f.dest_system, origin.system)
    and f2.dest_slot = f.dest_slot;

  body := concat_ws(
    E'\n',
    format('Espionage report from asteroid belt [%s:%s:%s]', coalesce(f.dest_galaxy, 1), coalesce(f.dest_system, 0), coalesce(f.dest_slot, 17)),
    '',
    'Resources at probe arrival',
    format('Ore: %s', coalesce(belt.ore, 0)),
    format('Crystal: %s', coalesce(belt.crystal, 0)),
    '',
    'Miners',
    coalesce(nullif(miner_lines, ''), 'None')
  );

  dest_slot := coalesce(belt.after_slot, origin.slot);
  flight := private.wiki_travel_seconds(
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), dest_slot),
    private.ship_speed('espionage_probe', attacker.impulse_drive, attacker.hyperspace_drive, attacker.propulsion_level),
    100
  );

  insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
  values (uid, 'Espionage report', body, 0, 0);

  update public.fleets
  set
    mission = 'espionage_return',
    dest_planet_id = origin.id,
    dest_galaxy = origin.galaxy,
    dest_system = origin.system,
    dest_slot = origin.slot,
    created_at = f.arrives_at,
    arrives_at = f.arrives_at + make_interval(secs => flight),
    flight_seconds = flight,
    report = body
  where id = f.id;
end;
$$;

create or replace function private.send_miner_home(f public.fleets, at timestamptz, reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  e public.empires%rowtype;
  flight integer;
  dest_slot smallint;
begin
  if f.mission <> 'mine_hold' and f.mission <> 'mine' then
    return;
  end if;
  select * into origin from public.planets where id = f.origin_planet_id;
  select * into e from public.empires where user_id = f.owner_id;
  dest_slot := private.belt_flight_slot(coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), coalesce(f.dest_slot, 17));
  flight := private.wiki_travel_seconds(
    private.wiki_flight_distance(origin.galaxy, origin.system, origin.slot, coalesce(f.dest_galaxy, origin.galaxy), coalesce(f.dest_system, origin.system), dest_slot),
    private.ship_speed('mining_barge', e.impulse_drive, e.hyperspace_drive, e.propulsion_level),
    100
  );
  update public.fleets
  set
    mission = 'mine_return',
    dest_planet_id = origin.id,
    dest_galaxy = origin.galaxy,
    dest_system = origin.system,
    dest_slot = origin.slot,
    created_at = at,
    arrives_at = at + make_interval(secs => flight),
    flight_seconds = flight,
    report = reason
  where id = f.id;
end;
$$;

notify pgrst, 'reload schema';
