-- Wiki crawlers: cap (ore+crystal+deut mine levels)×8, 50 energy each from leftover
-- after mines, +0.02% mine production per working unit. Over-cap units stay idle.

create or replace function private.crawler_cap(
  ore_mine integer,
  crystal_mine integer,
  deut_mine integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select (
    greatest(coalesce(ore_mine, 0), 0)
    + greatest(coalesce(crystal_mine, 0), 0)
    + greatest(coalesce(deut_mine, 0), 0)
  ) * 8;
$$;

create or replace function private.working_crawlers(
  owned integer,
  ore_mine integer,
  crystal_mine integer,
  deut_mine integer,
  energy_output numeric,
  mine_drain numeric
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(
    greatest(coalesce(owned, 0), 0),
    private.crawler_cap(ore_mine, crystal_mine, deut_mine),
    case
      when coalesce(energy_output, 0) - coalesce(mine_drain, 0) <= 0 then 0
      else floor((coalesce(energy_output, 0) - coalesce(mine_drain, 0)) / 50)
    end
  )::integer;
$$;

create or replace function private.crawler_production_bonus(working integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 1 + greatest(coalesce(working, 0), 0) * 0.0002;
$$;

revoke all on function private.crawler_cap(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.working_crawlers(integer, integer, integer, integer, numeric, numeric) from public, anon, authenticated;
revoke all on function private.crawler_production_bonus(integer) from public, anon, authenticated;

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
  synth := private.deut_prod_per_hour(p.deuterium_extractor, p.temp_max);
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
