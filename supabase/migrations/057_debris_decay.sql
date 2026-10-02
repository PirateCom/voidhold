-- Debris fields hold 100% for 2 hours after the last wreck, then fade linearly to 0% over the next 2 hours.
-- Stored ore/crystal are the full-strength amounts; reads multiply by debris_factor.

alter table public.debris_fields
  add column if not exists fresh_at timestamptz not null default timezone('utc', now());

create or replace function private.debris_factor(p_fresh_at timestamptz, p_at timestamptz)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_fresh_at is null then 1
    when extract(epoch from (p_at - p_fresh_at)) <= 7200 then 1
    when extract(epoch from (p_at - p_fresh_at)) >= 14400 then 0
    else 1 - (extract(epoch from (p_at - p_fresh_at)) - 7200) / 7200.0
  end::numeric;
$$;

revoke all on function private.debris_factor(timestamptz, timestamptz) from public, anon, authenticated;

create or replace function private.bump_debris(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_ore bigint,
  p_crystal bigint
)
returns void
language plpgsql
set search_path = public
as $$
declare
  at timestamptz := timezone('utc', now());
begin
  if coalesce(p_ore, 0) = 0 and coalesce(p_crystal, 0) = 0 then
    return;
  end if;
  insert into public.debris_fields (galaxy, system, slot, ore, crystal, fresh_at)
  values (p_galaxy, p_system, p_slot, greatest(p_ore, 0), greatest(p_crystal, 0), at)
  on conflict (galaxy, system, slot)
  do update set
    ore = floor(public.debris_fields.ore * private.debris_factor(public.debris_fields.fresh_at, at))::bigint + excluded.ore,
    crystal = floor(public.debris_fields.crystal * private.debris_factor(public.debris_fields.fresh_at, at))::bigint + excluded.crystal,
    fresh_at = at;
end;
$$;

create or replace function private.collect_debris(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_capacity bigint
)
returns table (take_ore bigint, take_crystal bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  field public.debris_fields%rowtype;
  factor numeric;
  live_ore bigint;
  live_crystal bigint;
  ore_take bigint := 0;
  crystal_take bigint := 0;
begin
  select * into field
  from public.debris_fields
  where galaxy = p_galaxy and system = p_system and slot = p_slot
  for update;

  if not found then
    take_ore := 0;
    take_crystal := 0;
    return next;
    return;
  end if;

  factor := private.debris_factor(field.fresh_at, timezone('utc', now()));
  live_ore := floor(field.ore * factor)::bigint;
  live_crystal := floor(field.crystal * factor)::bigint;

  select s.take_ore, s.take_crystal
  into ore_take, crystal_take
  from private.harvest_debris_share(live_ore, live_crystal, p_capacity) s;

  if factor <= 0 or (live_ore - ore_take <= 0 and live_crystal - crystal_take <= 0) then
    delete from public.debris_fields
    where galaxy = p_galaxy and system = p_system and slot = p_slot;
  else
    update public.debris_fields
    set
      ore = ceil((live_ore - ore_take) / factor)::bigint,
      crystal = ceil((live_crystal - crystal_take) / factor)::bigint
    where galaxy = p_galaxy and system = p_system and slot = p_slot;
  end if;

  take_ore := ore_take;
  take_crystal := crystal_take;
  return next;
end;
$$;


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

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p_galaxy and s.system = p_system;

  select jsonb_build_object(
    'galaxy', p_galaxy,
    'system', p_system,
    'star_type', coalesce(star, 'medium'),
    'multiplier', private.star_multiplier(coalesce(star, 'medium')),
    'slots', (
      select coalesce(jsonb_agg(jsonb_build_object(
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
      ) order by sl.slot), '[]'::jsonb)
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
    )
  )
  into result;

  return result;
end;
$$;
