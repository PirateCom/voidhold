-- Player-facing rename: Astrophysics → Astronomy. Column and RPC ids stay astrophysics.

do $$
declare
  r record;
  def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prosrc like '%Astrophysics%'
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
    def := replace(def, 'Astrophysics', 'Astronomy');
    execute def;
  end loop;
end $$;

notify pgrst, 'reload schema';
