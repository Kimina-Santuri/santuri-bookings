begin;
-- Student access is staff-assigned and separate from staff privileges and paid tiers.
create table private.students(user_id uuid primary key references public.profiles(id));
revoke all on private.students from public,anon,authenticated;
alter table public.bookings drop constraint bookings_allowance_kind_check;
alter table public.bookings add constraint bookings_allowance_kind_check check(allowance_kind in ('none','production','studio','student'));

create function public.member_is_student(p_user uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  return exists(select 1 from private.students where user_id=p_user);
end; $$;

create function public.set_student_member(p_user uuid,p_student boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  if p_student is null then raise exception 'Student access choice is required'; end if;
  -- Serialize grants/revocations with booking requests for this member.
  perform 1 from public.profiles where id=p_user for update;
  if not found then raise exception 'Member not found'; end if;
  if p_student then
    insert into private.students(user_id) values(p_user) on conflict do nothing;
  else
    delete from private.students where user_id=p_user;
  end if;
  perform private.log(case when p_student then 'student_access_granted' else 'student_access_revoked' end,p_user::text);
end; $$;

create or replace function private.balance(p_user uuid,p_date timestamptz,p_kind text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.memberships; base integer:=0; adjustment integer; used integer; reserved integer; wk date:=private.week_of(p_date);
begin
  if exists(select 1 from private.staff where user_id=p_user) then
    return jsonb_build_object('kind',p_kind,'week_start',wk,'allocated',2147483647,'used',0,'reserved',0,'remaining',2147483647,'tier','staff','unlimited',true,'expires_at',null);
  end if;
  if exists(select 1 from private.students where user_id=p_user) then
    select coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('completed','no_show')),0),
      coalesce(sum(extract(epoch from ends_at-starts_at)::int/60) filter(where status in ('requested','confirmed')),0)
    into used,reserved from public.bookings where user_id=p_user and use_allowance and allowance_kind='student' and private.week_of(starts_at)=wk;
    return jsonb_build_object('kind','student','week_start',wk,'allocated',480,'used',used,'reserved',reserved,'remaining',greatest(0,480-used-reserved),'tier','student','unlimited',false,'expires_at',null);
  end if;
  select * into m from public.memberships where user_id=p_user and p_date>=starts_at and p_date<expires_at order by starts_at desc limit 1;
  if p_kind='production' then base:=case m.tier when 'mwanzo' then 60 when 'midi' then 240 when 'sana' then 480 else 0 end;
  elsif p_kind='studio' then base:=case m.tier when 'midi' then 2 else 0 end; end if;
  select coalesce(sum(units),0) into adjustment from public.allowance_adjustments where user_id=p_user and week_start=wk and kind=p_kind;
  select coalesce(sum(case when p_kind='studio' then 1 else extract(epoch from ends_at-starts_at)::int/60 end) filter(where status in ('completed','no_show')),0),
  coalesce(sum(case when p_kind='studio' then 1 else extract(epoch from ends_at-starts_at)::int/60 end) filter(where status in ('requested','confirmed')),0)
  into used,reserved from public.bookings where user_id=p_user and use_allowance and allowance_kind=p_kind and private.week_of(starts_at)=wk;
  return jsonb_build_object('kind',p_kind,'week_start',wk,'allocated',base+adjustment,'used',used,'reserved',reserved,'remaining',greatest(0,base+adjustment-used-reserved),'tier',coalesce(m.tier,'free'),'unlimited',false,'expires_at',m.expires_at);
end; $$;

create or replace function public.request_booking(p_space uuid,p_start timestamptz,p_minutes integer,p_allowance boolean,p_note text,p_key uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare s public.spaces; m public.memberships; b public.bookings; uid uuid:=auth.uid(); bid uuid; finish timestamptz; cost numeric; units integer; balance jsonb; staff_member boolean; student_member boolean; booking_kind text;
begin
  if uid is null then raise exception 'Sign in required'; end if;
  perform 1 from public.profiles where id=uid for update;
  select * into b from public.bookings where user_id=uid and request_key=p_key;
  if found then return b.id; end if;
  if p_key is null or p_start is null or p_minutes is null or p_allowance is null or p_minutes<60 or p_minutes>540 or p_start>now()+interval '90 days' then raise exception 'Invalid booking request'; end if;
  finish:=p_start+make_interval(mins=>p_minutes);
  select * into s from public.spaces where id=p_space for update;
  if not private.slot_ok(p_space,p_start,finish) then raise exception 'This time is unavailable. Please choose another slot.'; end if;
  staff_member:=exists(select 1 from private.staff where user_id=uid);
  student_member:=exists(select 1 from private.students where user_id=uid);
  booking_kind:=s.allowance_kind;
  select * into m from public.memberships where user_id=uid and starts_at<=now() and p_start>=starts_at and finish<=expires_at order by starts_at desc limit 1;
  cost:=round(s.hourly_rate*p_minutes/60.0*(case m.tier when 'midi' then 0.7 when 'sana' then 0.5 else 1 end),2);
  if staff_member then cost:=0;
  elsif p_allowance and student_member then
    balance:=private.balance(uid,p_start,'student');
    if (balance->>'remaining')::int<p_minutes then raise exception 'Not enough student hours remaining for that week'; end if;
    booking_kind:='student';
    cost:=0;
  elsif p_allowance then
    if m.id is null or s.allowance_kind='none' then raise exception 'No eligible membership allowance for this session'; end if;
    if s.allowance_kind='studio' and p_minutes<>120 then raise exception 'Studio allowance sessions must be two hours'; end if;
    units:=case when s.allowance_kind='studio' then 1 else p_minutes end;
    balance:=private.balance(uid,p_start,s.allowance_kind);
    if (balance->>'remaining')::int<units then raise exception 'Not enough allowance remaining for that week'; end if;
    cost:=0;
  end if;
  insert into public.bookings(user_id,space_id,starts_at,ends_at,use_allowance,allowance_kind,membership_id,price,space_name,note,request_key) values(uid,p_space,p_start,finish,p_allowance,booking_kind,m.id,cost,s.name,coalesce(p_note,''),p_key) returning id into bid;
  perform private.log('booking_requested',bid::text); return bid;
end; $$;

revoke all on function public.member_is_student(uuid),public.set_student_member(uuid,boolean) from public,anon,authenticated;
grant execute on function public.member_is_student(uuid),public.set_student_member(uuid,boolean) to authenticated;
commit;
