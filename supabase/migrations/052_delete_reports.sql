-- Reports last 7 real days (wiki-style combat mail). Players can delete earlier.

create or replace function private.prune_battle_reports(at timestamptz)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.battle_reports
  where created_at <= coalesce(at, timezone('utc', now())) - interval '7 days';
$$;

revoke all on function private.prune_battle_reports(timestamptz) from public, anon, authenticated;

create or replace function public.delete_report(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  deleted integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_id is null then
    raise exception 'Unknown report.';
  end if;

  perform private.prune_battle_reports(at);

  delete from public.battle_reports
  where id = p_id and user_id = uid;
  get diagnostics deleted = row_count;
  if deleted = 0 then
    raise exception 'Unknown report.';
  end if;

  return private.empire_state_json(uid, at);
end;
$$;

revoke all on function public.delete_report(bigint) from public, anon;
grant execute on function public.delete_report(bigint) to authenticated;

create or replace function private.empire_state_json(uid uuid, at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.prune_battle_reports(at);
  perform private.catch_up(uid, at);
  perform private.catch_up(o.user_id, at)
  from public.empires o
  where o.user_id is distinct from uid;

  select jsonb_build_object(
    'profile', jsonb_build_object(
      'user_id', pr.user_id,
      'display_name', pr.display_name
    ),
    'planet', to_jsonb(p),
    'colonies', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'galaxy', c.galaxy,
        'system', c.system,
        'slot', c.slot,
        'is_homeworld', c.is_homeworld
      ) order by c.is_homeworld desc, c.id), '[]'::jsonb)
      from public.planets c
      where c.owner_id = uid
    ),
    'empire', to_jsonb(e) || jsonb_build_object(
      'raiders_queued', p.ships_queued,
      'ship_building', p.ship_building,
      'raider_completes_at', p.ship_completes_at
    ),
    'star', jsonb_build_object(
      'type', coalesce(s.star_type, 'medium'),
      'multiplier', private.star_multiplier(coalesce(s.star_type, 'medium'))
    ),
    'rank', private.rank_payload(uid),
    'fleets', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'owner_id', f.owner_id,
        'origin_planet_id', f.origin_planet_id,
        'dest_planet_id', f.dest_planet_id,
        'dest_name', case
          when coalesce(f.dest_slot, dp.slot) = 16 then 'Outer space'
          when f.mission in ('harvest', 'harvest_return') then coalesce(dp.name, 'Debris field')
          when f.mission in ('colonize', 'colonize_return') then coalesce(dp.name, 'Empty slot')
          else dp.name
        end,
        'dest_galaxy', coalesce(f.dest_galaxy, dp.galaxy),
        'dest_system', coalesce(f.dest_system, dp.system),
        'dest_slot', coalesce(f.dest_slot, dp.slot),
        'origin_name', coalesce(op.name, 'Deep space'),
        'origin_galaxy', coalesce(op.galaxy, dp.galaxy),
        'origin_system', coalesce(op.system, dp.system),
        'origin_slot', coalesce(op.slot, dp.slot),
        'created_at', f.created_at,
        'raiders', f.raiders,
        'mission', f.mission,
        'arrives_at', f.arrives_at,
        'cargo_ore', f.cargo_ore,
        'cargo_crystal', f.cargo_crystal,
        'cargo_deuterium', f.cargo_deuterium,
        'status', f.status,
        'report', f.report,
        'inbound', (f.owner_id is distinct from uid),
        'attacker_name', case when f.owner_id is null then 'Pirates' else ap.display_name end,
        'ship_count', case
          when f.composition is not null and f.composition <> '{}'::jsonb then (
            select coalesce(sum(greatest(value::integer, 0)), 0)::integer
            from jsonb_each_text(f.composition)
          )
          else f.raiders
        end,
        'composition', case
          when f.owner_id is distinct from uid then '{}'::jsonb
          else f.composition
        end
      ) order by f.arrives_at), '[]'::jsonb)
      from public.fleets f
      left join public.planets dp on dp.id = f.dest_planet_id
      left join public.planets op on op.id = f.origin_planet_id
      left join public.profiles ap on ap.user_id = f.owner_id
      where f.status = 'en_route'
        and (f.owner_id = uid or f.dest_planet_id in (select pl.id from public.planets pl where pl.owner_id = uid))
    ),
    'reports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'title', r.title,
        'body', r.body,
        'loot_ore', r.loot_ore,
        'loot_crystal', r.loot_crystal
      ) order by r.created_at desc), '[]'::jsonb)
      from (
        select * from public.battle_reports
        where user_id = uid
          and created_at > at - interval '7 days'
        order by created_at desc
        limit 15
      ) r
    ),
    'server_now', at,
    'debug', private.debug_operator()
  )
  into result
  from public.empires e
  join public.planets p on p.id = e.home_planet_id
  join public.profiles pr on pr.user_id = e.user_id
  left join public.solar_systems s on s.galaxy = p.galaxy and s.system = p.system
  where e.user_id = uid;

  return result;
end;
$$;
