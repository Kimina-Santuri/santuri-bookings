-- Show the approved booker's name alongside the space in synced calendar events.
drop function if exists public.calendar_jobs();

create function public.calendar_jobs() returns table(
  booking_id uuid,
  revision integer,
  calendar_id text,
  status text,
  starts_at timestamptz,
  ends_at timestamptz,
  space_name text,
  requester_name text
) language sql security definer set search_path='' as $$
  select b.id,
    j.revision,
    c.calendar_id,
    b.status,
    b.starts_at,
    b.ends_at,
    b.space_name,
    coalesce(nullif(trim(p.full_name),''), p.email, 'Santuri guest')
  from private.calendar_jobs j
  join public.bookings b on b.id=j.booking_id
  join public.profiles p on p.id=b.user_id
  join public.calendar_connections c on c.space_id=b.space_id
  where j.revision>j.synced_revision
  order by j.updated_at
  limit 100;
$$;

revoke all on function public.calendar_jobs() from public, anon, authenticated;
grant execute on function public.calendar_jobs() to service_role;
