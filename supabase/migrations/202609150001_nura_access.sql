begin;
-- NURA is a booking programme, not another physical room. Requests reserve the
-- existing DJ/Classroom row so all booking routes and calendar sync share locks.
create table private.nura_members(user_id uuid primary key references public.profiles(id));
revoke all on private.nura_members from public,anon,authenticated;
alter table public.bookings drop constraint bookings_allowance_kind_check;
alter table public.bookings add constraint bookings_allowance_kind_check check(allowance_kind in ('none','production','studio','student','nura'));

create function public.set_nura_member(p_user uuid,p_nura boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  if p_nura is null then raise exception 'NURA access choice is required'; end if;
  perform 1 from public.profiles where id=p_user for update;
  if not found then raise exception 'Member not found'; end if;
  if p_nura then
    insert into private.nura_members values(p_user) on conflict do nothing;
  else
    delete from private.nura_members where user_id=p_user;
  end if;
  perform private.log(case when p_nura then 'nura_access_granted' else 'nura_access_revoked' end,p_user::text);
end; $$;

create function private.nura_balance(p_user uuid,p_date timestamptz) returns jsonb
language plpgsql security definer set search_path='' as $$
declare used integer; reserved integer; wk date:=private.week_of(p_date);
  active boolean:=exists(select 1 from private.nura_members where user_id=p_user);
  staff_member boolean:=exists(select 1 from private.staff where user_id=p_user);
begin
  select coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('completed','no_show')),0),
    coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('requested','confirmed')),0)
    into used,reserved from public.bookings where user_id=p_user and use_allowance and allowance_kind='nura' and private.week_of(starts_at)=wk;
  return jsonb_build_object('active',active,'unlimited',staff_member,'week_start',wk,'allocated',case when active then 240 else 0 end,
    'used',used,'reserved',reserved,'remaining',case when active then greatest(0,240-used-reserved) else 0 end);
end; $$;

create or replace function public.my_allowances(p_date timestamptz default now()) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  return jsonb_build_object('production',private.balance(auth.uid(),p_date,'production'),'studio',private.balance(auth.uid(),p_date,'studio'),'nura',private.nura_balance(auth.uid(),p_date));
end; $$;
create or replace function public.member_allowances(p_user uuid,p_date timestamptz default now()) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  return jsonb_build_object('production',private.balance(p_user,p_date,'production'),'studio',private.balance(p_user,p_date,'studio'),'nura',private.nura_balance(p_user,p_date));
end; $$;

create function private.nura_space(p_day date) returns uuid
language sql stable security definer set search_path='' as $$
  select id from public.spaces where slug=case extract(isodow from p_day) when 5 then 'dj' when 6 then 'classroom' end;
$$;

create function public.nura_slots(p_day date,p_minutes integer)
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
      and (a.ends_at at time zone 'Africa/Nairobi')::time<=time '18:00';
end; $$;

create function public.request_nura_booking(p_start timestamptz,p_minutes integer,p_note text,p_key uuid) returns uuid
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
    or (finish at time zone 'Africa/Nairobi')::time>time '18:00' then raise exception 'NURA sessions run Friday and Saturday, 11:00–18:00 EAT'; end if;
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

revoke all on function private.nura_balance(uuid,timestamptz),private.nura_space(date) from public,anon,authenticated;
revoke all on function public.set_nura_member(uuid,boolean),public.nura_slots(date,integer),public.request_nura_booking(timestamptz,integer,text,uuid) from public,anon,authenticated;
grant execute on function public.set_nura_member(uuid,boolean),public.nura_slots(date,integer),public.request_nura_booking(timestamptz,integer,text,uuid) to authenticated;
commit;
