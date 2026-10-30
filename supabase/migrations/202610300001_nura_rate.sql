begin;
-- NURA x JCK, agreed with the team 2026-10-30:
-- * Open to every signed-in member for now: staff no longer need to grant NURA access.
--   private.nura_members and set_nura_member stay so access can be restricted again by
--   restoring the exists() check in private.nura_balance.
-- * Sessions cost a flat 1,000 KES per hour (previously no rental charge). The four-hour
--   weekly cap per member stays; staff still book free.
-- The rate is not the room's own rate: DJ Practice Room and Classroom stay at 1,500 KES/hr
-- for everyone else. Existing NURA bookings keep their saved price (0) unless rescheduled.

create or replace function private.nura_balance(p_user uuid,p_date timestamptz) returns jsonb
language plpgsql security definer set search_path='' as $$
declare used integer; reserved integer; wk date:=private.week_of(p_date);
  active boolean:=p_user is not null; -- open to every signed-in member for now; private.nura_members is kept but no longer checked
  staff_member boolean:=exists(select 1 from private.staff where user_id=p_user);
begin
  select coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('completed','no_show')),0),
    coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('requested','confirmed')),0)
    into used,reserved from public.bookings where user_id=p_user and use_allowance and allowance_kind='nura' and private.week_of(starts_at)=wk;
  return jsonb_build_object('active',active,'unlimited',staff_member,'week_start',wk,'allocated',case when active then 240 else 0 end,
    'used',used,'reserved',reserved,'remaining',case when active then greatest(0,240-used-reserved) else 0 end);
end; $$;

create or replace function public.request_nura_booking(p_start timestamptz,p_minutes integer,p_note text,p_key uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); b public.bookings; s public.spaces; bid uuid; finish timestamptz;
  local_start timestamp:=p_start at time zone 'Africa/Nairobi'; balance jsonb;
begin
  if uid is null then raise exception 'Sign in required'; end if;
  perform 1 from public.profiles where id=uid for update;
  select * into b from public.bookings where user_id=uid and request_key=p_key;
  if found then
    if b.allowance_kind<>'nura' then raise exception 'Request key already used for another booking'; end if;
    return b.id;
  end if;
  if p_key is null or p_start is null or p_minutes is null or p_minutes<60 or p_minutes>240 or p_minutes%30<>0 or p_start>now()+interval '90 days' then raise exception 'Invalid NURA booking request'; end if;
  finish:=p_start+make_interval(mins=>p_minutes);
  if extract(isodow from local_start) not in (5,6) or local_start::time<time '11:00'
    or (finish at time zone 'Africa/Nairobi')::date<>local_start::date
    or (finish at time zone 'Africa/Nairobi')::time>time '19:00' then raise exception 'NURA sessions run Friday and Saturday, 11:00–19:00 EAT'; end if;
  balance:=private.nura_balance(uid,p_start);
  if not (balance->>'active')::boolean and not (balance->>'unlimited')::boolean then raise exception 'NURA access must be assigned by staff'; end if;
  if not (balance->>'unlimited')::boolean and (balance->>'remaining')::int<p_minutes then raise exception 'Not enough NURA hours remaining for that week'; end if;
  select * into s from public.spaces where id=private.nura_space(local_start::date) for update;
  if not found or not private.slot_ok(s.id,p_start,finish) then raise exception 'This time is unavailable. Please choose another slot.'; end if;
  insert into public.bookings(user_id,space_id,starts_at,ends_at,use_allowance,allowance_kind,price,space_name,note,request_key)
    values(uid,s.id,p_start,finish,true,'nura',case when (balance->>'unlimited')::boolean then 0 else round(1000*p_minutes/60.0,2) end,s.name,coalesce(p_note,''),p_key) returning id into bid;
  perform private.log('booking_requested',bid::text);
  return bid;
end; $$;

create or replace function public.reschedule_booking(p_id uuid,p_start timestamptz,p_minutes integer,p_reason text) returns void language plpgsql security definer set search_path='' as $$
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
 -- Price follows request_booking: membership discount, allowance or staff sessions free, NURA a flat rate, add-on per hour.
 select * into m from public.memberships where user_id=b.user_id and starts_at<=now() and p_start>=starts_at and finish<=expires_at order by starts_at desc limit 1;
 cost:=case when staff_member then 0 when b.allowance_kind='nura' then round(1000*p_minutes/60.0,2) when b.use_allowance then 0 else round(s.hourly_rate*p_minutes/60.0*(case m.tier when 'midi' then 0.7 when 'sana' then 0.5 else 1 end),2) end;
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

commit;
