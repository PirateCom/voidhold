-- Universe highscore list for the Commander page (wiki score points).

create or replace function public.get_highscores()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(e.user_id, at)
  from public.empires e;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'user_id', ranked.user_id,
        'display_name', ranked.display_name,
        'points', ranked.points
      )
      order by ranked.place
    )
    from (
      select
        s.user_id,
        s.display_name,
        s.points,
        row_number() over (order by s.points desc, s.display_name) as place
      from (
        select
          e.user_id,
          pr.display_name,
          private.score_points(e.user_id) as points
        from public.empires e
        join public.profiles pr on pr.user_id = e.user_id
      ) s
    ) ranked
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_highscores() from public, anon;
grant execute on function public.get_highscores() to authenticated;
