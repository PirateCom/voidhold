-- Classic Voidhold early-build boost: first upgrades divide time by max(4 - nextLevel/2, 1).
-- Nanite factory, lunar base, sensor phalanx, and jump gate skip it.

create or replace function private.building_time_seconds(
  building text,
  current_level integer,
  robotics_level integer default 0,
  nanite_level integer default 0,
  p_speed integer default 1
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    1,
    floor(
      (
        coalesce(private.building_cost_ore(building, current_level), 0)
        + coalesce(private.building_cost_crystal(building, current_level), 0)
      )::numeric
      * 3600
      / (
        2500
        * case
            when building in ('nanite_factory', 'lunar_base', 'phalanx_sensor', 'stargate') then 1::numeric
            else greatest(4 - (greatest(coalesce(current_level, 0), 0) + 1)::numeric / 2, 1)
          end
        * (1 + greatest(coalesce(robotics_level, 0), 0))
        * power(2, greatest(coalesce(nanite_level, 0), 0))
        * greatest(coalesce(p_speed, 1), 1)
      )
    )::integer
  );
$$;

revoke all on function private.building_time_seconds(text, integer, integer, integer, integer) from public, anon, authenticated;
