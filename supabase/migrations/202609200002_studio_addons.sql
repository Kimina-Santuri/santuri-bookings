begin;

-- Recording Studio, DJ Practice Room and Classroom can offer a recording engineer
-- (1,500 KES/hour) or a studio hand (1,000 KES/hour) as a last-step booking add-on.
-- The two are mutually exclusive per booking and the fee applies even when the room
-- itself is booked free via a membership allowance.
alter table public.spaces add column staff_addons boolean not null default false;
update public.spaces set staff_addons=true where slug in ('studio','dj','classroom');

alter table public.bookings add column addon_kind text not null default 'none' check(addon_kind in ('none','engineer','hand'));
alter table public.bookings add column addon_price numeric not null default 0 check(addon_price>=0);

drop function public.request_booking(uuid,timestamptz,integer,boolean,text,uuid);
create function public.request_booking(p_space uuid,p_start timestamptz,p_minutes integer,p_allowance boolean,p_note text,p_key uuid,p_addon text default 'none') returns uuid language plpgsql security definer set search_path='' as $$
declare s public.spaces; m public.memberships; b public.bookings; uid uuid:=auth.uid(); bid uuid; finish timestamptz; cost numeric; addon_cost numeric; units integer; balance jsonb; addon text:=coalesce(p_addon,'none');
begin
 if uid is null then raise exception 'Sign in required'; end if;
 perform 1 from public.profiles where id=uid for update;
 select * into b from public.bookings where user_id=uid and request_key=p_key;
 if found then return b.id; end if;
 if p_key is null or p_start is null or p_minutes is null or p_allowance is null or p_minutes<60 or p_minutes>540 or p_start>now()+interval '90 days' then raise exception 'Invalid booking request'; end if;
 if addon not in ('none','engineer','hand') then raise exception 'Invalid add-on selection'; end if;
 finish:=p_start+make_interval(mins=>p_minutes);
 select * into s from public.spaces where id=p_space for update;
 if addon<>'none' and not s.staff_addons then raise exception 'A recording engineer or studio hand is not available for this space'; end if;
 if not private.slot_ok(p_space,p_start,finish) then raise exception 'This time is unavailable. Please choose another slot.'; end if;
 select * into m from public.memberships where user_id=uid and starts_at<=now() and p_start>=starts_at and finish<=expires_at order by starts_at desc limit 1;
 cost:=round(s.hourly_rate*p_minutes/60.0*(case m.tier when 'midi' then 0.7 when 'sana' then 0.5 else 1 end),2);
 if p_allowance then
  if m.id is null or s.allowance_kind='none' then raise exception 'No eligible membership allowance for this session'; end if;
  if s.allowance_kind='studio' and p_minutes<>120 then raise exception 'Studio allowance sessions must be two hours'; end if;
  units:=case when s.allowance_kind='studio' then 1 else p_minutes end;
  balance:=private.balance(uid,p_start,s.allowance_kind);
  if (balance->>'remaining')::int<units then raise exception 'Not enough allowance remaining for that week'; end if;
  cost:=0;
 end if;
 addon_cost:=round((case addon when 'engineer' then 1500 when 'hand' then 1000 else 0 end)*p_minutes/60.0,2);
 insert into public.bookings(user_id,space_id,starts_at,ends_at,use_allowance,allowance_kind,membership_id,price,addon_kind,addon_price,space_name,note,request_key) values(uid,p_space,p_start,finish,p_allowance,s.allowance_kind,m.id,cost+addon_cost,addon,addon_cost,s.name,coalesce(p_note,''),p_key) returning id into bid;
 perform private.log('booking_requested',bid::text); return bid;
end; $$;
grant execute on function public.request_booking(uuid,timestamptz,integer,boolean,text,uuid,text) to authenticated;

commit;
