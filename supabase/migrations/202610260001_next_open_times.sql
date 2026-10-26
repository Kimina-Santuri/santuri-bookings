begin;

-- For the landing page: each bookable space's next free start within a week, at its minimum length.
-- Public, so it reveals only that one time per space (no bookings, names or other slots). It uses the
-- same rules as booking (notice, opening hours, blocks, calendar sync), and the scan stops at the first free slot.
create function public.next_open_times() returns table(slug text,name text,starts_at timestamptz,minutes integer) language sql stable security definer set search_path='' as $$
 select s.slug,s.name,o.t,s.minimum_minutes from public.spaces s
 cross join lateral (select t from generate_series(date_trunc('hour',now())+interval '30 minutes',now()+interval '7 days',interval '30 minutes') t
  where private.slot_ok(s.id,t,t+make_interval(mins=>s.minimum_minutes)) order by t limit 1) o
 where s.active and s.booking_enabled
 order by o.t,s.sort_order $$;
revoke execute on function public.next_open_times() from public;
grant execute on function public.next_open_times() to anon,authenticated;

commit;
