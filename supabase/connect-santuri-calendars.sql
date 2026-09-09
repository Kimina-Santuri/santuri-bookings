-- Run in the Supabase SQL Editor after Google service-account sharing is set up.
-- This maps existing calendars; it does not prove Google access or start sync.
-- New bookings pause for connected spaces until their first successful sync.
begin;
do $$
declare
  mapping record;
  sid uuid;
  existing_calendar text;
begin
  for mapping in select * from (values
    ('studio', 'studio@santuri.org'),
    ('classroom', 'c_4ac8f2fd22a525d9ec1a0d4dd280517c66b353cee4198cfb3cb3ea222c7113db@group.calendar.google.com'),
    ('workstation', 'c_d6a6b0ecf67e7d36185da732e86334adad6e48d9065b42b8ddc7f4676d3d1d4e@group.calendar.google.com'),
    ('dj', 'djpractice@santuri.org')
  ) as calendars(slug, calendar_id)
  loop
    select id into sid from public.spaces where slug=mapping.slug for update;
    if sid is null then raise exception 'Missing space: %', mapping.slug; end if;
    select calendar_id into existing_calendar from public.calendar_connections where space_id=sid;
    if existing_calendar is not null and existing_calendar<>mapping.calendar_id then
      raise exception 'Space % already has a different calendar. Review its existing events before changing it.',mapping.slug;
    end if;
    insert into public.calendar_connections(space_id,calendar_id)
    values(sid,mapping.calendar_id) on conflict(space_id) do nothing;
    if found then
      insert into private.calendar_jobs(booking_id)
      select id from public.bookings where space_id=sid
      on conflict(booking_id) do update set revision=private.calendar_jobs.revision+1;
      insert into public.audit_log(action,entity_id,details)
      values('calendar_connected',sid::text,jsonb_build_object('source','owner_sql_setup','calendar_id',mapping.calendar_id));
    end if;
  end loop;
end $$;
commit;

select s.name,c.calendar_id,c.synced_at,c.sync_error
from public.calendar_connections c join public.spaces s on s.id=c.space_id
order by s.sort_order;
