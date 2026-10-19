begin;
-- Staff can move an upcoming requested or confirmed booking to a new date, time or length
-- in the same space. Moving between spaces would leave the old Google event in the old
-- room's calendar, so it is cancel-and-rebook instead. Staff skip the member notice period;
-- every other availability rule still applies, ignoring the booking's own current slot.
-- Allowances are rechecked for the new week, the price is recalculated, Google Calendar is
-- updated, and the member is emailed the old and new times.

alter table private.email_outbox drop constraint email_outbox_kind_check;
alter table private.email_outbox add constraint email_outbox_kind_check check(kind in ('request_received','booking_confirmed','booking_cancelled','booking_completed','booking_no_show','booking_reminder','role_assigned','booking_rescheduled'));

-- private.slot_ok without the notice rules, and ignoring the booking being moved.
create function private.reschedule_ok(p_booking uuid,p_space uuid,p_start timestamptz,p_end timestamptz) returns boolean language plpgsql security definer set search_path='' as $$
declare s public.spaces; local_start timestamp:=p_start at time zone 'Africa/Nairobi'; local_end timestamp:=p_end at time zone 'Africa/Nairobi'; duration numeric:=extract(epoch from p_end-p_start)/60;
begin
 select * into s from public.spaces where id=p_space;
 if not found or not s.active or not s.booking_enabled or duration<s.minimum_minutes or duration>s.maximum_minutes or duration%30<>0 or local_start::date<>local_end::date or extract(second from local_start)<>0 or extract(minute from local_start)::int%30<>0 or p_start<=now() or p_start>now()+interval '90 days' then return false; end if;
 if not exists(select 1 from public.space_hours where space_id=p_space and weekday=extract(dow from local_start) and local_start::time>=opens and local_end::time<=closes) then return false; end if;
 if exists(select 1 from public.calendar_connections where space_id=p_space and (synced_at is null or synced_at<now()-interval '10 minutes' or sync_error is not null)) then return false; end if;
 if exists(select 1 from public.bookings where space_id=p_space and id<>p_booking and status<>'cancelled' and starts_at<p_end and ends_at>p_start) or exists(select 1 from public.space_blocks where space_id=p_space and starts_at<p_end and ends_at>p_start) then return false; end if;
 return true;
end; $$;

-- Free start times for the reschedule dialog.
create function public.reschedule_slots(p_booking uuid,p_day date,p_minutes integer) returns table(starts_at timestamptz,ends_at timestamptz) language plpgsql security definer set search_path='' as $$
declare b public.bookings;
begin perform private.require_staff();
 select * into b from public.bookings where id=p_booking;
 if not found then raise exception 'Booking not found'; end if;
 if p_minutes is null or p_minutes<30 or p_minutes>540 or p_minutes%30<>0 then raise exception 'Choose a valid duration'; end if;
 return query select t,t+make_interval(mins=>p_minutes) from generate_series((p_day+time '09:00') at time zone 'Africa/Nairobi',(p_day+time '19:00') at time zone 'Africa/Nairobi',interval '30 minutes') t
  where private.reschedule_ok(b.id,b.space_id,t,t+make_interval(mins=>p_minutes))
   and (b.allowance_kind<>'nura' or ((t at time zone 'Africa/Nairobi')::time>=time '11:00' and ((t+make_interval(mins=>p_minutes)) at time zone 'Africa/Nairobi')::time<=time '19:00' and private.nura_space(p_day)=b.space_id and p_minutes<=240));
end; $$;

create function public.reschedule_booking(p_id uuid,p_start timestamptz,p_minutes integer,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare owner uuid; b public.bookings; s public.spaces; m public.memberships; finish timestamptz; local_start timestamp; units integer; old_units integer; remaining integer; balance jsonb; allowance text;
 cost numeric; addon_cost numeric; paid numeric; staff_member boolean;
begin perform private.require_staff();
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Enter a reason'; end if;
 select user_id into owner from public.bookings where id=p_id;
 if owner is null then raise exception 'Booking not found'; end if;
 -- Same lock order as booking requests: member, then booking, then space.
 perform 1 from public.profiles where id=owner for update;
 select * into b from public.bookings where id=p_id for update;
 if b.status not in ('requested','confirmed') or b.starts_at<=now() then raise exception 'Only upcoming requested or confirmed bookings can be rescheduled'; end if;
 if p_start is null or p_minutes is null or p_minutes%30<>0 then raise exception 'Choose a valid time and duration'; end if;
 finish:=p_start+make_interval(mins=>p_minutes);local_start:=p_start at time zone 'Africa/Nairobi';
 if p_start=b.starts_at and finish=b.ends_at then raise exception 'Choose a different time'; end if;
 select * into s from public.spaces where id=b.space_id for update;
 if not private.reschedule_ok(b.id,b.space_id,p_start,finish) then raise exception 'That time is unavailable for this space.'; end if;
 if b.allowance_kind='nura' and (extract(isodow from local_start) not in (5,6) or private.nura_space(local_start::date)<>b.space_id or local_start::time<time '11:00' or (finish at time zone 'Africa/Nairobi')::time>time '19:00' or p_minutes>240) then
  raise exception 'NURA sessions in this room must stay on its NURA day, 11:00–19:00 EAT, up to four hours'; end if;
 staff_member:=exists(select 1 from private.staff where user_id=b.user_id);
 -- Allowances: the booking's own reservation is added back when it stays in the same week.
 if b.use_allowance and not staff_member then
  allowance:=b.allowance_kind;
  if allowance='studio' and p_minutes<>120 then raise exception 'Studio allowance sessions must be two hours'; end if;
  units:=case when allowance='studio' then 1 else p_minutes end;
  old_units:=case when allowance='studio' then 1 else extract(epoch from b.ends_at-b.starts_at)::int/60 end;
  balance:=case when allowance='nura' then private.nura_balance(b.user_id,p_start) else private.balance(b.user_id,p_start,allowance) end;
  if not coalesce((balance->>'unlimited')::boolean,false) then
   remaining:=(balance->>'remaining')::int+case when private.week_of(b.starts_at)=private.week_of(p_start) then old_units else 0 end;
   if remaining<units then raise exception 'Not enough allowance in that week. Adjust the member''s allowance first.'; end if;
  end if;
 end if;
 -- Price follows request_booking: membership discount, allowance or staff sessions free, add-on per hour.
 select * into m from public.memberships where user_id=b.user_id and starts_at<=now() and p_start>=starts_at and finish<=expires_at order by starts_at desc limit 1;
 cost:=case when staff_member or b.use_allowance then 0 else round(s.hourly_rate*p_minutes/60.0*(case m.tier when 'midi' then 0.7 when 'sana' then 0.5 else 1 end),2) end;
 addon_cost:=round((case b.addon_kind when 'engineer' then 1500 when 'hand' then 1000 else 0 end)*p_minutes/60.0,2);
 select coalesce(sum(amount),0) into paid from public.payments where booking_id=b.id and status='paid';
 if paid>cost+addon_cost then raise exception 'Recorded payments (%) exceed the new price (%). Void or correct a payment first.',paid,cost+addon_cost; end if;
 update public.bookings set starts_at=p_start,ends_at=finish,price=cost+addon_cost,addon_price=addon_cost,membership_id=coalesce(m.id,case when b.use_allowance then b.membership_id end),updated_at=now() where id=b.id;
 insert into private.calendar_jobs(booking_id) values(b.id) on conflict(booking_id) do update set revision=private.calendar_jobs.revision+1,updated_at=now();
 -- A fresh reminder is queued for the new date; the member is told about the change.
 delete from private.email_outbox where booking_id=b.id and kind='booking_reminder';
 insert into private.email_outbox(booking_id,recipient,kind,payload)
 select b.id,lower(trim(p.email)),'booking_rescheduled',jsonb_build_object('subject','Santuri booking rescheduled','name',p.full_name,'space',b.space_name,
  'starts_at',p_start,'ends_at',finish,'previous_starts_at',b.starts_at,'previous_ends_at',b.ends_at,'status',b.status,'price',cost+addon_cost,'use_allowance',b.use_allowance,'note',b.note)
 from public.profiles p where p.id=b.user_id and p.email is not null and length(trim(p.email))>0
 on conflict(booking_id,kind) do update set recipient=excluded.recipient,payload=excluded.payload,attempts=0,next_attempt_at=now(),claimed_at=null,claim_token=null,sent_at=null,last_error=null,created_at=now();
 perform private.log('booking_rescheduled',b.id::text,jsonb_build_object('reason',trim(p_reason),'previous_starts_at',b.starts_at,'previous_ends_at',b.ends_at,'starts_at',p_start,'ends_at',finish,'previous_price',b.price,'price',cost+addon_cost));
end; $$;

revoke all on function private.reschedule_ok(uuid,uuid,timestamptz,timestamptz),public.reschedule_slots(uuid,date,integer),public.reschedule_booking(uuid,timestamptz,integer,text) from public,anon,authenticated;
grant execute on function public.reschedule_slots(uuid,date,integer),public.reschedule_booking(uuid,timestamptz,integer,text) to authenticated;
commit;
