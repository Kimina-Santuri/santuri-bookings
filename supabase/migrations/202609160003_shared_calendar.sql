-- A minimal schedule for signed-in members, without exposing other members' records.
create or replace function public.shared_calendar(p_start timestamptz, p_end timestamptz)
returns table(kind text, space_id uuid, space_name text, starts_at timestamptz, ends_at timestamptz, status text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end)
    or p_end <= p_start or p_end > p_start + interval '32 days' then
  raise exception 'Choose a calendar range of at most 32 days';
 end if;
 return query
 select 'booking'::text, b.space_id, b.space_name, b.starts_at, b.ends_at, b.status
 from public.bookings b
 where b.status <> 'cancelled' and b.starts_at < p_end and b.ends_at > p_start
 union all
 select 'block'::text, x.space_id, s.name, x.starts_at, x.ends_at, 'blocked'::text
 from public.space_blocks x join public.spaces s on s.id=x.space_id
 where x.starts_at < p_end and x.ends_at > p_start
 order by starts_at;
end;
$$;
revoke all on function public.shared_calendar(timestamptz,timestamptz) from public, anon;
grant execute on function public.shared_calendar(timestamptz,timestamptz) to authenticated;
