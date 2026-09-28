-- Harvest arrival called private.ship_cargo, which was never created.
-- Recyclers already have cargo on private.unit_cargo('recycler') = 20000.

create or replace function private.ship_cargo(id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select private.unit_cargo(id);
$$;

revoke all on function private.ship_cargo(text) from public, anon, authenticated;

create or replace function private.resolve_harvest_arrival(uid uuid, e public.empires, f public.fleets)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  origin public.planets%rowtype;
  dest_g smallint;
  dest_s smallint;
  dest_sl smallint;
  recyclers integer;
  cap bigint;
  ore_take bigint := 0;
  crystal_take bigint := 0;
  flight integer;
  slowest integer;
  base_flight integer;
begin
  select * into origin from public.planets where id = f.origin_planet_id;
  dest_g := coalesce(f.dest_galaxy, origin.galaxy);
  dest_s := coalesce(f.dest_system, origin.system);
  dest_sl := coalesce(f.dest_slot, origin.slot);
  recyclers := greatest(coalesce((f.composition->>'recycler')::integer, 0), 0);
  cap := recyclers::bigint * private.ship_cargo('recycler'::text);

  select c.take_ore, c.take_crystal
  into ore_take, crystal_take
  from private.collect_debris(dest_g, dest_s, dest_sl, cap) c;

  slowest := private.ship_speed('recycler'::text, e.impulse_drive, e.hyperspace_drive);
  base_flight := private.flight_seconds(
    origin.system, origin.slot, dest_s, dest_sl, e.propulsion_level, origin.galaxy, dest_g
  );
  flight := greatest(15, floor(base_flight * (5000.0 / greatest(slowest, 1)))::integer);

  update public.fleets
  set
    mission = 'harvest_return',
    cargo_ore = ore_take,
    cargo_crystal = crystal_take,
    arrives_at = f.arrives_at + make_interval(secs => flight),
    report = case
      when ore_take + crystal_take > 0 then format('Recyclers harvested %s ore and %s crystal.', ore_take, crystal_take)
      else 'The debris field was empty.'
    end
  where id = f.id;
end;
$$;

notify pgrst, 'reload schema';
