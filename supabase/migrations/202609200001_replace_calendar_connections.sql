begin;

-- Classroom, Creative Workstation and Recording Studio had their Google Calendars
-- deleted and recreated; point the existing connections at the new calendars and
-- requeue their bookings to sync.
update public.calendar_connections
set calendar_id='589865304df3ebf4a1560e70f1b571bcff335ac51ff5155159ff5790924a3c95@group.calendar.google.com',
    sync_error=null, synced_at=null, revision=revision+1
where space_id='2ce394e1-2539-40b0-8438-a67a2b893f39';

update public.calendar_connections
set calendar_id='34fc1c4aceabc261c3b2990596a18127f39e4c29591f6ecf8e5c705772e49ad2@group.calendar.google.com',
    sync_error=null, synced_at=null, revision=revision+1
where space_id='264cf6ac-08ee-47e1-8b12-42e69f26da88';

update public.calendar_connections
set calendar_id='c1cad181d64a06bb448caa80a49075aaa7f5bbb308a0366f15aaf15c27ccb44c@group.calendar.google.com',
    sync_error=null, synced_at=null, revision=revision+1
where space_id='f0df1aa2-227a-444f-a920-c586650afd66';

insert into private.calendar_jobs(booking_id)
select id from public.bookings where space_id in ('2ce394e1-2539-40b0-8438-a67a2b893f39','264cf6ac-08ee-47e1-8b12-42e69f26da88','f0df1aa2-227a-444f-a920-c586650afd66')
on conflict(booking_id) do update set revision=private.calendar_jobs.revision+1;

commit;
