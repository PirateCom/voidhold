-- Galaxy slots carry the owner's user id so clients can draw their planet avatar.

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
        'debris_ore', coalesce(df.ore, 0),
        'debris_crystal', coalesce(df.crystal, 0)
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
