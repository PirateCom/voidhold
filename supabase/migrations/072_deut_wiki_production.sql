-- Wiki deuterium: floor(10 × L × 1.1^L × (1.36 − 0.004 × Tavg)).
-- Tavg = (temp_min + temp_max) / 2 when both are known; otherwise Tmax.

drop function if exists private.deut_prod_per_hour(integer, integer);

create function private.deut_prod_per_hour(level integer, temp_max integer, temp_min integer default null)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  climate numeric;
  t_avg numeric;
begin
  if coalesce(level, 0) <= 0 then
    return 0;
  end if;
  t_avg := case
    when temp_min is null then coalesce(temp_max, 30)::numeric
    else (temp_min::numeric + coalesce(temp_max, 30)::numeric) / 2.0
  end;
  climate := 1.36 - 0.004 * t_avg;
  return greatest(0, floor(10 * level * power(1.1, level) * climate));
end;
$$;

revoke all on function private.deut_prod_per_hour(integer, integer, integer) from public;
grant execute on function private.deut_prod_per_hour(integer, integer, integer) to postgres, service_role;

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
  synth numeric;
  burn numeric;
  fusion_live boolean;
  energy_out numeric;
  mine_drain numeric;
  bonus numeric := 1;
begin
  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p.galaxy and s.system = p.system;

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
  factor_fusion := private.energy_factor(
    p.ore_mine,
    p.crystal_mine,
    p.power_plant,
    coalesce(star, 'medium'),
    p.deuterium_extractor,
    p.fusion_reactor,
    coalesce(energy_tech, 0),
    coalesce(satellites, 0),
    p.temp_min,
    p.temp_max
  );
  synth := private.deut_prod_per_hour(p.deuterium_extractor, p.temp_max, p.temp_min);
  burn := private.fusion_deut_burn_per_hour(p.fusion_reactor);
  fusion_live := coalesce(p.fusion_reactor, 0) <= 0
    or p.deuterium + synth * factor_fusion * worked / private.game_hour_seconds() >= burn * worked / private.game_hour_seconds();
  factor := case
    when fusion_live then factor_fusion
    else private.energy_factor(
      p.ore_mine,
      p.crystal_mine,
      p.power_plant,
      coalesce(star, 'medium'),
      p.deuterium_extractor,
      0,
      coalesce(energy_tech, 0),
      coalesce(satellites, 0),
      p.temp_min,
      p.temp_max
    )
  end;
  energy_out := private.energy_output(
    p.power_plant,
    coalesce(star, 'medium'),
    case when fusion_live then p.fusion_reactor else 0 end,
    coalesce(energy_tech, 0),
    coalesce(satellites, 0),
    p.temp_min,
    p.temp_max
  );
  mine_drain := private.energy_drain_now(p.ore_mine, p.crystal_mine, p.deuterium_extractor);
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
  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * factor * bonus * worked / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * factor * bonus * worked / private.game_hour_seconds())::bigint;
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
