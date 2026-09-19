begin;

-- NURA sessions now run 11:00-19:00 EAT on Friday and Saturday (was 11:00-18:00),
-- so the last visible start slot is 18:00 instead of 17:00. Friday's DJ Practice
-- Room and Saturday's Classroom share the same physical space_hours as regular
-- bookings, so the closing cap has to move for those rows too; this also opens
-- an 18:00-19:00 slot for non-NURA bookings on those two days.
do $$
declare cname text;
begin
  select conname into cname from pg_constraint
    where conrelid='public.space_hours'::regclass
      and pg_get_constraintdef(oid) ilike '%18:00%';
  if cname is not null then
    execute format('alter table public.space_hours drop constraint %I', cname);
  end if;
end $$;
alter table public.space_hours add constraint space_hours_range_check check(opens>=time '09:00' and closes<=time '19:00' and closes>opens);

create or replace function public.nura_slots(p_day date,p_minutes integer)
returns table(starts_at timestamptz,ends_at timestamptz,space_id uuid,space_name text)
language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.nura_space(p_day); balance jsonb:=private.nura_balance(auth.uid(),(p_day+time '12:00') at time zone 'Africa/Nairobi');
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not (balance->>'active')::boolean and not (balance->>'unlimited')::boolean then raise exception 'NURA access must be assigned by staff'; end if;
  if p_minutes is null or p_minutes<60 or p_minutes>240 or p_minutes%30<>0 then raise exception 'Choose a NURA duration between one and four hours'; end if;
  return query select a.starts_at,a.ends_at,s.id,s.name from public.available_slots(sid,p_day,p_minutes) a
    join public.spaces s on s.id=sid
    where (a.starts_at at time zone 'Africa/Nairobi')::time>=time '11:00'
      and (a.ends_at at time zone 'Africa/Nairobi')::time<=time '19:00';
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
    values(uid,s.id,p_start,finish,true,'nura',0,s.name,coalesce(p_note,''),p_key) returning id into bid;
  perform private.log('booking_requested',bid::text);
  return bid;
end; $$;

update public.space_hours set closes='19:00' where weekday=5 and space_id=(select id from public.spaces where slug='dj');
update public.space_hours set closes='19:00' where weekday=6 and space_id=(select id from public.spaces where slug='classroom');

commit;
