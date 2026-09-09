-- Santuri initial setup: run once in a new Supabase project.
-- Generated from the versioned migrations and seed; do not run again after setup.

-- Source: supabase/migrations/202609070001_booking_system.sql
begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create table public.profiles (
 id uuid primary key references auth.users(id), full_name text not null default '' check(length(full_name)<=150),
 email text not null, alumni boolean not null default false, created_at timestamptz not null default now()
);
create table private.staff (user_id uuid primary key references public.profiles(id));
create function public.is_staff() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.staff where user_id=auth.uid()); $$;
create function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.profiles(id,email,full_name) values(new.id,coalesce(new.email,''),left(coalesce(new.raw_user_meta_data->>'full_name',''),150)); return new; end; $$;
create trigger santuri_new_user after insert on auth.users for each row execute function private.new_user();
create function private.email_changed() returns trigger language plpgsql security definer set search_path='' as $$
begin update public.profiles set email=coalesce(new.email,'') where id=new.id; return new; end; $$;
create trigger santuri_email_changed after update of email on auth.users for each row execute function private.email_changed();

create table public.spaces (
 id uuid primary key default gen_random_uuid(), slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 name text not null check(length(name) between 1 and 120), category text not null check(category in ('sound','group','focus')),
 summary text not null default '' check(length(summary)<=2000), description text not null default '' check(length(description)<=6000),
 features text not null default '' check(length(features)<=3000), tag text not null default '' check(length(tag)<=100),
 capacity integer not null check(capacity between 1 and 1000), hourly_rate numeric(10,2) not null check(hourly_rate>=0),
 image_url text not null default '', image_alt text not null default '' check(length(image_alt)<=300),
 calendly_url text not null default '' check(calendly_url='' or calendly_url ~ '^https://calendly[.]com/'),
 allowance_kind text not null default 'none' check(allowance_kind in ('none','production','studio')),
 minimum_minutes integer not null default 60 check(minimum_minutes>=60 and minimum_minutes%30=0),
 maximum_minutes integer not null default 540 check(maximum_minutes>=minimum_minutes and maximum_minutes<=540 and maximum_minutes%30=0),
 notice_hours integer not null default 24 check(notice_hours between 0 and 720),
 active boolean not null default true, booking_enabled boolean not null default false,
 sort_order integer not null default 0, version integer not null default 1,
 updated_at timestamptz not null default now(),
 check(image_url='' or image_url ~ '^assets/images/[a-zA-Z0-9._/-]+$' or image_url ~ '^https://')
);
create table public.space_hours (
 space_id uuid not null references public.spaces(id), weekday integer not null check(weekday between 0 and 6),
 opens time not null, closes time not null, primary key(space_id,weekday),
 check(opens>=time '09:00' and closes<=time '18:00' and closes>opens),
 check(extract(second from opens)=0 and extract(second from closes)=0 and extract(minute from opens)::int%30=0 and extract(minute from closes)::int%30=0)
);
create table public.memberships (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
 tier text not null check(tier in ('mwanzo','midi','sana')), starts_at timestamptz not null,
 expires_at timestamptz not null, check(expires_at=starts_at+interval '30 days')
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), space_id uuid not null references public.spaces(id),
 starts_at timestamptz not null, ends_at timestamptz not null, status text not null default 'requested' check(status in ('requested','confirmed','completed','no_show','cancelled')),
 use_allowance boolean not null default false, allowance_kind text not null check(allowance_kind in ('none','production','studio')),
 membership_id uuid references public.memberships(id), price numeric(10,2) not null check(price>=0),
 space_name text not null, note text not null default '' check(length(note)<=1000),
 request_key uuid not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(user_id,request_key), check(ends_at>starts_at)
);
create index bookings_space_time on public.bookings(space_id,starts_at,ends_at);
create index bookings_user_time on public.bookings(user_id,starts_at);
create table public.payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
 booking_id uuid references public.bookings(id), membership_id uuid references public.memberships(id),
 amount numeric(10,2) not null check(amount>0), reference text not null unique check(length(reference) between 1 and 100),
 status text not null default 'paid' check(status in ('paid','void')), reason text not null default '',
 recorded_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table public.allowance_adjustments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
 week_start date not null check(extract(isodow from week_start)=1), kind text not null check(kind in ('production','studio')),
 units integer not null check(units<>0 and abs(units)<=10000), reason text not null check(length(reason) between 3 and 500),
 recorded_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table public.space_blocks (
 id uuid primary key default gen_random_uuid(), space_id uuid not null references public.spaces(id),
 starts_at timestamptz not null, ends_at timestamptz not null, reason text not null default '' check(length(reason)<=500),
 source text not null default 'staff' check(source in ('staff','google')), external_id text,
 check(ends_at>starts_at), unique(space_id,source,external_id)
);
create table public.audit_log (
 id bigint generated always as identity primary key, actor_id uuid, action text not null, entity_id text,
 details jsonb not null default '{}', created_at timestamptz not null default now()
);
create table public.calendar_connections (
 space_id uuid primary key references public.spaces(id), calendar_id text not null check(length(calendar_id)>0),
 synced_at timestamptz, sync_error text, revision integer not null default 1
);
create table private.calendar_jobs (
 booking_id uuid primary key references public.bookings(id), revision integer not null default 1, synced_revision integer not null default 0,
 error text, updated_at timestamptz not null default now()
);

-- Every table is closed by default. Mutations below are narrow, checked functions.
alter table public.profiles enable row level security;
alter table private.staff enable row level security;
alter table public.spaces enable row level security;
alter table public.space_hours enable row level security;
alter table public.memberships enable row level security;
alter table public.bookings enable row level security;
alter table public.payments enable row level security;
alter table public.allowance_adjustments enable row level security;
alter table public.space_blocks enable row level security;
alter table public.audit_log enable row level security;
alter table public.calendar_connections enable row level security;
alter table private.calendar_jobs enable row level security;
revoke all on all tables in schema public from anon,authenticated;
grant select on public.spaces,public.space_hours to anon,authenticated;
grant select on public.profiles,public.memberships,public.bookings,public.payments,public.allowance_adjustments,public.space_blocks,public.audit_log,public.calendar_connections to authenticated;
grant all on all tables in schema public to service_role;
grant all on all tables in schema private to service_role;
grant all on all sequences in schema public to service_role;
create policy read_spaces on public.spaces for select using(active or public.is_staff());
create policy read_hours on public.space_hours for select using(exists(select 1 from public.spaces where id=space_id));
create policy read_profile on public.profiles for select to authenticated using(id=auth.uid() or public.is_staff());
create policy read_memberships on public.memberships for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy read_bookings on public.bookings for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy read_payments on public.payments for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy read_adjustments on public.allowance_adjustments for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy read_blocks on public.space_blocks for select to authenticated using(public.is_staff());
create policy read_audit on public.audit_log for select to authenticated using(public.is_staff());
create policy read_calendars on public.calendar_connections for select to authenticated using(public.is_staff());

create function private.require_staff() returns void language plpgsql security definer set search_path='' as $$
begin if not public.is_staff() then raise exception 'Staff access required'; end if; end; $$;
create function private.log(p_action text,p_id text,p_details jsonb default '{}') returns void language sql security definer set search_path='' as $$
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),p_action,p_id,p_details); $$;
create function private.week_of(p_time timestamptz) returns date language sql immutable set search_path='' as $$
 select date_trunc('week',p_time at time zone 'Africa/Nairobi')::date; $$;
create function private.balance(p_user uuid,p_date timestamptz,p_kind text) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.memberships; base integer:=0; adjustment integer; used integer; reserved integer; wk date:=private.week_of(p_date);
begin
 select * into m from public.memberships where user_id=p_user and p_date>=starts_at and p_date<expires_at order by starts_at desc limit 1;
 if p_kind='production' then base:=case m.tier when 'mwanzo' then 60 when 'midi' then 240 when 'sana' then 480 else 0 end;
 elsif p_kind='studio' then base:=case m.tier when 'midi' then 2 else 0 end; end if;
 select coalesce(sum(units),0) into adjustment from public.allowance_adjustments where user_id=p_user and week_start=wk and kind=p_kind;
 select coalesce(sum(case when p_kind='studio' then 1 else extract(epoch from ends_at-starts_at)::int/60 end) filter(where status in ('completed','no_show')),0),
 coalesce(sum(case when p_kind='studio' then 1 else extract(epoch from ends_at-starts_at)::int/60 end) filter(where status in ('requested','confirmed')),0)
 into used,reserved from public.bookings where user_id=p_user and use_allowance and allowance_kind=p_kind and private.week_of(starts_at)=wk;
 return jsonb_build_object('kind',p_kind,'week_start',wk,'allocated',base+adjustment,'used',used,'reserved',reserved,'remaining',greatest(0,base+adjustment-used-reserved),'tier',coalesce(m.tier,'free'),'expires_at',m.expires_at);
end; $$;
create function public.my_allowances(p_date timestamptz default now()) returns jsonb language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Sign in required'; end if;
 return jsonb_build_object('production',private.balance(auth.uid(),p_date,'production'),'studio',private.balance(auth.uid(),p_date,'studio')); end; $$;
create function public.update_profile(p_name text) returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null or length(trim(p_name)) not between 1 and 150 then raise exception 'Enter your name'; end if;
 update public.profiles set full_name=trim(p_name) where id=auth.uid(); end; $$;

create function public.save_space(p_id uuid,p_version integer,p_data jsonb,p_hours jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid:=coalesce(p_id,gen_random_uuid()); current_version integer;
begin perform private.require_staff();
 if p_id is not null then
  select version into current_version from public.spaces where id=p_id for update;
  if current_version is null or current_version<>p_version then raise exception 'This space changed. Reload before saving.'; end if;
 end if;
 if jsonb_typeof(p_hours)<>'array' or jsonb_array_length(p_hours)>7 then raise exception 'Invalid schedule'; end if;
 if coalesce((p_data->>'booking_enabled')::boolean,false) and jsonb_array_length(p_hours)=0 then raise exception 'Set opening days before enabling bookings'; end if;
 insert into public.spaces(id,slug,name,category,summary,description,features,tag,capacity,hourly_rate,image_url,image_alt,calendly_url,allowance_kind,minimum_minutes,maximum_minutes,notice_hours,active,booking_enabled,sort_order)
 values(sid,p_data->>'slug',trim(p_data->>'name'),p_data->>'category',coalesce(p_data->>'summary',''),coalesce(p_data->>'description',''),coalesce(p_data->>'features',''),coalesce(p_data->>'tag',''),(p_data->>'capacity')::int,(p_data->>'hourly_rate')::numeric,coalesce(p_data->>'image_url',''),coalesce(p_data->>'image_alt',''),coalesce(p_data->>'calendly_url',''),p_data->>'allowance_kind',(p_data->>'minimum_minutes')::int,(p_data->>'maximum_minutes')::int,(p_data->>'notice_hours')::int,coalesce((p_data->>'active')::boolean,true),coalesce((p_data->>'booking_enabled')::boolean,false),coalesce((p_data->>'sort_order')::int,0))
 on conflict(id) do update set name=excluded.name,category=excluded.category,summary=excluded.summary,description=excluded.description,features=excluded.features,tag=excluded.tag,capacity=excluded.capacity,hourly_rate=excluded.hourly_rate,image_url=excluded.image_url,image_alt=excluded.image_alt,calendly_url=excluded.calendly_url,allowance_kind=excluded.allowance_kind,minimum_minutes=excluded.minimum_minutes,maximum_minutes=excluded.maximum_minutes,notice_hours=excluded.notice_hours,active=excluded.active,booking_enabled=excluded.booking_enabled,sort_order=excluded.sort_order,version=public.spaces.version+1,updated_at=now();
 delete from public.space_hours where space_id=sid;
 insert into public.space_hours(space_id,weekday,opens,closes) select sid,(x->>'weekday')::int,(x->>'opens')::time,(x->>'closes')::time from jsonb_array_elements(p_hours) x;
 perform private.log('space_saved',sid::text,jsonb_build_object('before_version',current_version,'data',p_data,'hours',p_hours)); return sid;
end; $$;
create function public.archive_space(p_id uuid,p_version integer,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); update public.spaces set active=p_active,version=version+1,updated_at=now() where id=p_id and version=p_version;
 if not found then raise exception 'This space changed. Reload before saving.'; end if;
 perform private.log(case when p_active then 'space_restored' else 'space_archived' end,p_id::text); end; $$;

-- Space row locks serialize slot validation, requests, and staff blocking.
-- All booking writes use these functions; clients have no direct write grants.
create function private.slot_ok(p_space uuid,p_start timestamptz,p_end timestamptz) returns boolean language plpgsql security definer set search_path='' as $$
declare s public.spaces; local_start timestamp:=p_start at time zone 'Africa/Nairobi'; local_end timestamp:=p_end at time zone 'Africa/Nairobi'; duration numeric:=extract(epoch from p_end-p_start)/60;
begin
 select * into s from public.spaces where id=p_space;
 if not found or not s.active or not s.booking_enabled or duration<s.minimum_minutes or duration>s.maximum_minutes or duration%30<>0 or local_start::date<>local_end::date or extract(second from local_start)<>0 or extract(minute from local_start)::int%30<>0 or p_start<now()+make_interval(hours=>s.notice_hours) then return false; end if;
 if s.allowance_kind in ('production','studio') and p_start<now()+interval '24 hours' then return false; end if;
 if not exists(select 1 from public.space_hours where space_id=p_space and weekday=extract(dow from local_start) and local_start::time>=opens and local_end::time<=closes) then return false; end if;
 if exists(select 1 from public.calendar_connections where space_id=p_space and (synced_at is null or synced_at<now()-interval '10 minutes' or sync_error is not null)) then return false; end if;
 if exists(select 1 from public.bookings where space_id=p_space and status<>'cancelled' and starts_at<p_end and ends_at>p_start) or exists(select 1 from public.space_blocks where space_id=p_space and starts_at<p_end and ends_at>p_start) then return false; end if;
 return true;
end; $$;
create function public.available_slots(p_space uuid,p_day date,p_minutes integer) returns table(starts_at timestamptz,ends_at timestamptz) language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_minutes is null or p_minutes<60 or p_minutes>540 or p_minutes%30<>0 or p_day<(now() at time zone 'Africa/Nairobi')::date or p_day>(now() at time zone 'Africa/Nairobi')::date+90 then raise exception 'Choose a date within the next 90 days and a valid duration'; end if;
 return query select t,t+make_interval(mins=>p_minutes) from generate_series((p_day+time '09:00') at time zone 'Africa/Nairobi',(p_day+time '18:00') at time zone 'Africa/Nairobi',interval '30 minutes') t where private.slot_ok(p_space,t,t+make_interval(mins=>p_minutes));
end; $$;
create function public.request_booking(p_space uuid,p_start timestamptz,p_minutes integer,p_allowance boolean,p_note text,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare s public.spaces; m public.memberships; b public.bookings; uid uuid:=auth.uid(); bid uuid; finish timestamptz; cost numeric; units integer; balance jsonb;
begin
 if uid is null then raise exception 'Sign in required'; end if;
 perform 1 from public.profiles where id=uid for update;
 select * into b from public.bookings where user_id=uid and request_key=p_key;
 if found then return b.id; end if;
 if p_key is null or p_start is null or p_minutes is null or p_allowance is null or p_minutes<60 or p_minutes>540 or p_start>now()+interval '90 days' then raise exception 'Invalid booking request'; end if;
 finish:=p_start+make_interval(mins=>p_minutes);
 select * into s from public.spaces where id=p_space for update;
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
 insert into public.bookings(user_id,space_id,starts_at,ends_at,use_allowance,allowance_kind,membership_id,price,space_name,note,request_key) values(uid,p_space,p_start,finish,p_allowance,s.allowance_kind,m.id,cost,s.name,coalesce(p_note,''),p_key) returning id into bid;
 perform private.log('booking_requested',bid::text); return bid;
end; $$;
create function public.set_booking_status(p_id uuid,p_status text,p_reason text default '') returns void language plpgsql security definer set search_path='' as $$
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
  if not staff and b.starts_at<now()+interval '12 hours' then raise exception 'Cancellations require 12 hours notice. Contact the team.'; end if;
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
create function public.add_block(p_space uuid,p_start timestamptz,p_end timestamptz,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare bid uuid;
begin perform private.require_staff(); perform 1 from public.spaces where id=p_space for update;
 if p_start is null or p_end is null or p_end<=p_start or length(trim(p_reason))<3 then raise exception 'Enter a valid block and reason'; end if;
 if exists(select 1 from public.bookings where space_id=p_space and status<>'cancelled' and starts_at<p_end and ends_at>p_start) then raise exception 'Cancel overlapping bookings before blocking this time'; end if;
 insert into public.space_blocks(space_id,starts_at,ends_at,reason) values(p_space,p_start,p_end,p_reason) returning id into bid;
 perform private.log('time_blocked',bid::text,jsonb_build_object('space_id',p_space,'starts_at',p_start,'ends_at',p_end,'reason',p_reason)); return bid; end; $$;
create function public.remove_block(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); delete from public.space_blocks where id=p_id and source='staff'; if not found then raise exception 'Only staff blocks can be removed here'; end if; perform private.log('block_removed',p_id::text); end; $$;
create function public.set_alumni(p_user uuid,p_alumni boolean) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); update public.profiles set alumni=p_alumni where id=p_user; perform private.log('alumni_updated',p_user::text,jsonb_build_object('alumni',p_alumni)); end; $$;
create function public.activate_membership(p_user uuid,p_tier text,p_reference text) returns uuid language plpgsql security definer set search_path='' as $$
declare mid uuid; amount numeric; eligible boolean;
begin perform private.require_staff(); select alumni into eligible from public.profiles where id=p_user for update;
 if not coalesce(eligible,false) then raise exception 'Confirm alumni eligibility first'; end if;
 if exists(select 1 from public.memberships where user_id=p_user and expires_at>now()) then raise exception 'This member already has an active membership'; end if;
 amount:=case p_tier when 'mwanzo' then 500 when 'midi' then 1500 when 'sana' then 3000 end;
 if amount is null then raise exception 'Unknown membership tier'; end if;
 insert into public.memberships(user_id,tier,starts_at,expires_at) values(p_user,p_tier,now(),now()+interval '30 days') returning id into mid;
 insert into public.payments(user_id,membership_id,amount,reference,recorded_by) values(p_user,mid,amount,upper(trim(p_reference)),auth.uid());
 perform private.log('membership_activated',mid::text,jsonb_build_object('tier',p_tier,'user_id',p_user)); return mid; end; $$;
create function public.record_payment(p_booking uuid,p_amount numeric,p_reference text) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.bookings; pid uuid; paid numeric;
begin perform private.require_staff(); select * into b from public.bookings where id=p_booking for update;
 if not found or b.status='cancelled' then raise exception 'Choose an active booking'; end if;
 select coalesce(sum(amount),0) into paid from public.payments where booking_id=p_booking and status='paid';
 if p_amount is null or p_amount<=0 or p_amount+paid>b.price then raise exception 'Payment must not exceed the outstanding amount'; end if;
 insert into public.payments(user_id,booking_id,amount,reference,recorded_by) values(b.user_id,p_booking,p_amount,upper(trim(p_reference)),auth.uid()) returning id into pid;
 perform private.log('payment_recorded',pid::text,jsonb_build_object('booking_id',p_booking,'amount',p_amount)); return pid; end; $$;
create function public.void_payment(p_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); if length(trim(p_reason))<3 then raise exception 'Enter a reason'; end if;
 if exists(select 1 from public.payments where id=p_id and membership_id is not null) then raise exception 'Membership payment corrections require a reviewed membership adjustment'; end if;
 update public.payments set status='void',reason=p_reason where id=p_id and status='paid'; if not found then raise exception 'Payment not found or already void'; end if;
 perform private.log('payment_voided',p_id::text,jsonb_build_object('reason',p_reason)); end; $$;
create function public.adjust_allowance(p_user uuid,p_week date,p_kind text,p_units integer,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); perform 1 from public.profiles where id=p_user for update;
 insert into public.allowance_adjustments(user_id,week_start,kind,units,reason,recorded_by) values(p_user,p_week,p_kind,p_units,p_reason,auth.uid());
 perform private.log('allowance_adjusted',p_user::text,jsonb_build_object('week',p_week,'kind',p_kind,'units',p_units,'reason',p_reason)); end; $$;

-- Google jobs are durable and revisioned, allowing safe retries after API failures.
create function private.queue_calendar() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into private.calendar_jobs(booking_id) values(new.id) on conflict(booking_id) do update set revision=private.calendar_jobs.revision+1,updated_at=now(); return new; end; $$;
create trigger booking_calendar_job after insert or update of status on public.bookings for each row execute function private.queue_calendar();
create function public.connect_calendar(p_space uuid,p_calendar text) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); perform 1 from public.spaces where id=p_space for update;
 if exists(select 1 from public.calendar_connections where space_id=p_space and calendar_id<>trim(p_calendar)) then raise exception 'Disconnecting or replacing a calendar requires a reviewed migration of its events'; end if;
 insert into public.calendar_connections(space_id,calendar_id) values(p_space,trim(p_calendar)) on conflict(space_id) do nothing;
 insert into private.calendar_jobs(booking_id) select id from public.bookings where space_id=p_space on conflict(booking_id) do update set revision=private.calendar_jobs.revision+1;
 perform private.log('calendar_connected',p_space::text); end; $$;
create function public.calendar_jobs() returns table(booking_id uuid,revision integer,calendar_id text,status text,starts_at timestamptz,ends_at timestamptz,space_name text) language sql security definer set search_path='' as $$
 select b.id,j.revision,c.calendar_id,b.status,b.starts_at,b.ends_at,b.space_name from private.calendar_jobs j join public.bookings b on b.id=j.booking_id join public.calendar_connections c on c.space_id=b.space_id where j.revision>j.synced_revision order by j.updated_at limit 100; $$;
create function public.calendar_job_done(p_id uuid,p_revision integer,p_error text default null) returns void language plpgsql security definer set search_path='' as $$
begin update private.calendar_jobs set synced_revision=case when p_error is null then greatest(synced_revision,p_revision) else synced_revision end,error=p_error where booking_id=p_id; end; $$;
create function public.replace_google_blocks(p_space uuid,p_blocks jsonb,p_revision integer) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.spaces where id=p_space for update;
 if not exists(select 1 from public.calendar_connections where space_id=p_space and revision=p_revision) then raise exception 'Calendar connection changed'; end if;
 delete from public.space_blocks where space_id=p_space and source='google';
 insert into public.space_blocks(space_id,starts_at,ends_at,source,external_id) select p_space,(x->>'start')::timestamptz,(x->>'end')::timestamptz,'google',x->>'id' from jsonb_array_elements(p_blocks) x;
 update public.calendar_connections set synced_at=now(),sync_error=case when exists(select 1 from public.bookings b join public.space_blocks s on s.space_id=b.space_id and s.starts_at<b.ends_at and s.ends_at>b.starts_at where b.space_id=p_space and b.status in ('requested','confirmed')) then 'Google calendar overlaps an existing booking. Resolve the conflict.' else null end where space_id=p_space;
end; $$;

-- Explicit function allowlist. Internal helpers are never callable by clients.
revoke all on all functions in schema public from public,anon,authenticated;
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function public.is_staff() to anon,authenticated;
grant execute on function public.my_allowances(timestamptz),public.update_profile(text),public.available_slots(uuid,date,integer),public.request_booking(uuid,timestamptz,integer,boolean,text,uuid),public.set_booking_status(uuid,text,text),public.save_space(uuid,integer,jsonb,jsonb),public.archive_space(uuid,integer,boolean),public.add_block(uuid,timestamptz,timestamptz,text),public.remove_block(uuid),public.set_alumni(uuid,boolean),public.activate_membership(uuid,text,text),public.record_payment(uuid,numeric,text),public.void_payment(uuid,text),public.adjust_allowance(uuid,date,text,integer,text),public.connect_calendar(uuid,text) to authenticated;
grant execute on function public.calendar_jobs(),public.calendar_job_done(uuid,integer,text),public.replace_google_blocks(uuid,jsonb,integer) to service_role;

-- Public room photography; only staff can upload, no arbitrary SVG/HTML uploads.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('space-images','space-images',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy staff_upload_space_images on storage.objects for insert to authenticated with check(bucket_id='space-images' and public.is_staff());
create policy staff_read_space_images on storage.objects for select to authenticated using(bucket_id='space-images' and public.is_staff());
commit;


-- Source: supabase/migrations/202609070002_staff_balances_and_sync_lock.sql
begin;
create function public.member_allowances(p_user uuid,p_date timestamptz default now()) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform private.require_staff(); return jsonb_build_object('production',private.balance(p_user,p_date,'production'),'studio',private.balance(p_user,p_date,'studio')); end; $$;
revoke all on function public.member_allowances(uuid,timestamptz) from public,anon;
grant execute on function public.member_allowances(uuid,timestamptz) to authenticated;
create table private.sync_lease(id integer primary key check(id=1),token uuid not null,expires_at timestamptz not null);
alter table private.sync_lease enable row level security;
create function public.claim_calendar_sync(p_token uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin insert into private.sync_lease values(1,p_token,now()+interval '4 minutes') on conflict(id) do update set token=excluded.token,expires_at=excluded.expires_at where private.sync_lease.expires_at<now(); return found; end; $$;
create function public.release_calendar_sync(p_token uuid) returns void language sql security definer set search_path='' as $$
 delete from private.sync_lease where token=p_token; $$;
revoke all on function public.claim_calendar_sync(uuid),public.release_calendar_sync(uuid) from public,anon,authenticated;
grant execute on function public.claim_calendar_sync(uuid),public.release_calendar_sync(uuid) to service_role;
commit;


-- Backfill any accounts created before the profile trigger.
insert into public.profiles(id,email,full_name)
select id,coalesce(email,''),left(coalesce(raw_user_meta_data->>'full_name',''),150)
from auth.users on conflict(id) do nothing;

-- Source: supabase/seed.sql
-- Confirmed existing spaces. Opening DAYS are deliberately not invented.
-- Configure weekly hours in the staff dashboard before enabling bookings.
insert into public.spaces(slug,name,category,summary,description,features,tag,image_url,image_alt,calendly_url,allowance_kind,capacity,hourly_rate,sort_order) values
('studio','Recording Studio','sound','A maintained production room for recording, mixing and collaborative sessions.','A focused production and recording environment for turning an idea into a finished piece of audio.','Music production
Recording sessions
Mixing and mastering
Collaborative projects
Podcast and voice-over recording','Record · Produce · Mix','assets/images/studio-large.jpg','Santuri production and recording studio','https://calendly.com/studio-santuri/studio-bookings','studio',5,1000,0),
('dj','DJ Practice Room','sound','Dedicated time on a professional DJ setup, whether you’re learning or preparing a set.','Dedicated time and space to learn the equipment, develop transitions and prepare a set without distraction.','Pioneer CDJ setup
Traktor controller setup
Private practice sessions
Private lessons','Practice · Learn · Refine','assets/images/dj-room-large.jpg','Santuri DJ practice room with professional decks','https://calendly.com/djpractice-santuri/30min?primary_color=787878','none',3,1000,1),
('classroom','Classroom','group','A flexible group space for workshops, rehearsals, meetings and collaboration.','A flexible shared room for exchanging knowledge, developing ideas and bringing groups together.','Workshops and training
Group rehearsals
Community meetings
Creative collaboration','Teach · Meet · Rehearse','assets/images/classroom-large.webp','Santuri classroom set up for a group session','https://calendly.com/classroompractice-santuri/30min','none',20,1000,2),
('workstation','Creative Workstation','focus','A focused station for online work, music technology practice and electronics projects.','A focused desk for independent work, hands-on learning and smaller technical projects.','Online meetings
Personal gear practice
Self-paced synth learning
Email and document work
Electronics projects','Work · Learn · Build','assets/images/workstation-large2.jpg','Santuri workstation for focused creative work','https://calendly.com/santuriworkstations-santuri/30min','production',1,1000,3)
on conflict(slug) do nothing;
