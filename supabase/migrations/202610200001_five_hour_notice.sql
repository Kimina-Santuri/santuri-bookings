begin;
-- Members can book and cancel up to 5 hours before a session starts.
-- Booking notice now comes only from each space's notice_hours (the hard 24-hour floor for
-- production and studio spaces is removed), and any space above 5 hours is lowered to 5.
-- Spaces already below 5 hours keep their shorter notice. Staff still bypass cancellation notice.

alter table public.spaces alter column notice_hours set default 5;
update public.spaces set notice_hours=5,version=version+1,updated_at=now() where notice_hours>5;

create or replace function private.slot_ok(p_space uuid,p_start timestamptz,p_end timestamptz) returns boolean language plpgsql security definer set search_path='' as $$
declare s public.spaces; local_start timestamp:=p_start at time zone 'Africa/Nairobi'; local_end timestamp:=p_end at time zone 'Africa/Nairobi'; duration numeric:=extract(epoch from p_end-p_start)/60;
begin
 select * into s from public.spaces where id=p_space;
 if not found or not s.active or not s.booking_enabled or duration<s.minimum_minutes or duration>s.maximum_minutes or duration%30<>0 or local_start::date<>local_end::date or extract(second from local_start)<>0 or extract(minute from local_start)::int%30<>0 or p_start<now()+make_interval(hours=>s.notice_hours) then return false; end if;
 if not exists(select 1 from public.space_hours where space_id=p_space and weekday=extract(dow from local_start) and local_start::time>=opens and local_end::time<=closes) then return false; end if;
 if exists(select 1 from public.calendar_connections where space_id=p_space and (synced_at is null or synced_at<now()-interval '10 minutes' or sync_error is not null)) then return false; end if;
 if exists(select 1 from public.bookings where space_id=p_space and status<>'cancelled' and starts_at<p_end and ends_at>p_start) or exists(select 1 from public.space_blocks where space_id=p_space and starts_at<p_end and ends_at>p_start) then return false; end if;
 return true;
end; $$;

create or replace function public.set_booking_status(p_id uuid,p_status text,p_reason text default '') returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings; staff boolean:=public.is_staff(); uid uuid;
begin
 select user_id into uid from public.bookings where id=p_id;
 if auth.uid() is null or (uid<>auth.uid() and not staff) then raise exception 'Access denied'; end if;
 perform 1 from public.profiles where id=uid for update;
 select * into b from public.bookings where id=p_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if b.status=p_status then return; end if;
 if p_status='cancelled' then
  if b.status not in ('requested','confirmed') then raise exception 'This booking cannot be cancelled'; end if;
  if not staff and b.starts_at<now()+interval '5 hours' then raise exception 'Cancellations require 5 hours notice. Contact the team.'; end if;
  if staff and length(trim(p_reason))<3 then raise exception 'Enter a reason'; end if;
 elsif p_status='confirmed' then
  perform private.require_staff();
  if b.status<>'requested' or b.starts_at<now() then raise exception 'Only upcoming requests can be confirmed'; end if;
  perform 1 from public.spaces where id=b.space_id for update;
  if exists(select 1 from public.space_blocks where space_id=b.space_id and starts_at<b.ends_at and ends_at>b.starts_at) or exists(select 1 from public.calendar_connections where space_id=b.space_id and (synced_at is null or synced_at<now()-interval '10 minutes' or sync_error is not null)) then raise exception 'Resolve calendar availability before confirming'; end if;
 elsif p_status in ('completed','no_show') then
  perform private.require_staff();
  if b.status<>'confirmed' or b.ends_at>now() then raise exception 'Mark attendance after a confirmed session ends'; end if;
 else raise exception 'Invalid status transition'; end if;
 update public.bookings set status=p_status,updated_at=now() where id=p_id;
 perform private.log('booking_'||p_status,p_id::text,jsonb_build_object('previous_status',b.status,'reason',p_reason));
end; $$;

commit;
