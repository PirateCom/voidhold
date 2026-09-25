-- Wiki solar satellites: floor((average temp + 160) / 6) each, then the system star bonus.

create or replace function private.solar_satellite_output(
  temp_min integer,
  temp_max integer,
  star_type text,
  satellites integer
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(satellites, 0) <= 0 then 0
    else floor(
      greatest(
        0,
        floor(((coalesce(temp_min, 30) + coalesce(temp_max, 30))::numeric / 2 + 160) / 6)
      ) * private.star_multiplier(star_type)
    ) * satellites
  end;
$$;

revoke all on function private.solar_satellite_output(integer, integer, text, integer) from public, anon, authenticated;

create or replace function private.energy_factor(
  ore_mine integer,
  crystal_mine integer,
  power_plant integer,
  star_type text,
  deut_mine integer default 0,
  fusion integer default 0,
  energy_tech integer default 0,
  satellites integer default 0,
  temp_min integer default 30,
  temp_max integer default 30
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when private.mine_energy_drain(ore_mine)
      + private.mine_energy_drain(crystal_mine)
      + private.deut_energy_drain(deut_mine) <= 0 then 1
    else least(
      1::numeric,
      (
        case
          when power_plant <= 0 then 0
          else floor(20 * power_plant * power(1.1, power_plant) * private.star_multiplier(star_type))
        end
        + private.fusion_output(fusion, energy_tech)
        + private.solar_satellite_output(temp_min, temp_max, star_type, satellites)
      )
        / (
          private.mine_energy_drain(ore_mine)
          + private.mine_energy_drain(crystal_mine)
          + private.deut_energy_drain(deut_mine)
        )
    )
  end;
$$;

create or replace function private.tick_planet(p public.planets, at timestamptz)
returns public.planets
language plpgsql
stable
set search_path = ''
as $$
declare
  elapsed numeric;
  factor numeric;
  factor_fusion numeric;
  ore_add bigint;
  crystal_add bigint;
  deut_add bigint;
  deut_burn bigint;
  star text;
  energy_tech integer := 0;
  satellites integer := 0;
  synth numeric;
  burn numeric;
  fusion_live boolean;
begin
  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p.galaxy and s.system = p.system;

  if p.owner_id is not null then
    select e.energy_tech, coalesce((e.ships->>'solar_satellite')::integer, 0)
      into energy_tech, satellites
    from public.empires e
    where e.user_id = p.owner_id;
  end if;

  elapsed := greatest(0, extract(epoch from (at - p.last_harvested_at)));
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
    or p.deuterium + synth * factor_fusion * elapsed / private.game_hour_seconds() >= burn * elapsed / private.game_hour_seconds();
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
  ore_add := floor(private.mine_prod_per_hour(p.ore_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  crystal_add := floor(private.crystal_prod_per_hour(p.crystal_mine) * factor * elapsed / private.game_hour_seconds())::bigint;
  deut_add := floor(synth * factor * elapsed / private.game_hour_seconds())::bigint;
  deut_burn := case when fusion_live then floor(burn * elapsed / private.game_hour_seconds())::bigint else 0 end;
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

drop function if exists private.energy_factor(integer, integer, integer, text, integer, integer, integer);

revoke all on function private.energy_factor(integer, integer, integer, text, integer, integer, integer, integer, integer, integer) from public, anon, authenticated;

notify pgrst, 'reload schema';
