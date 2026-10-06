begin;

-- Gear rental: staff maintain the inventory (name, price per hour or per day, number of
-- units, availability); members request items for a period; staff approve, record the
-- handover and the return. No items, prices or quantities are seeded here.
create table public.gear_items (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(name) between 1 and 120),
 category text not null default '' check(length(category)<=60),
 description text not null default '' check(length(description)<=2000),
 image_url text not null default '' check(image_url='' or image_url ~ '^assets/images/[a-zA-Z0-9._/-]+$' or image_url ~ '^https://'),
 image_alt text not null default '' check(length(image_alt)<=300),
 price numeric(10,2) not null check(price>=0),
 price_unit text not null check(price_unit in ('hour','day')),
 quantity integer not null check(quantity between 0 and 1000),
 available boolean not null default true,
 active boolean not null default true,
 sort_order integer not null default 0, version integer not null default 1,
 updated_at timestamptz not null default now()
);
create table public.gear_rentals (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id),
 item_id uuid not null references public.gear_items(id),
 item_name text not null, quantity integer not null check(quantity between 1 and 1000),
 starts_at timestamptz not null, ends_at timestamptz not null,
 price_unit text not null check(price_unit in ('hour','day')),
 unit_price numeric(10,2) not null check(unit_price>=0), units integer not null check(units>0),
 discount text not null default 'none' check(discount in ('none','midi','sana','staff')),
 membership_id uuid references public.memberships(id),
 price numeric(10,2) not null check(price>=0),
 status text not null default 'requested' check(status in ('requested','approved','picked_up','returned','cancelled')),
 note text not null default '' check(length(note)<=1000),
 picked_up_at timestamptz, returned_at timestamptz,
 request_key uuid not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(user_id,request_key), check(ends_at>starts_at)
);
create index gear_rentals_item_time on public.gear_rentals(item_id,starts_at,ends_at);
create index gear_rentals_user_time on public.gear_rentals(user_id,starts_at);

alter table public.gear_items enable row level security;
alter table public.gear_rentals enable row level security;
revoke all on public.gear_items,public.gear_rentals from public,anon,authenticated;
grant select on public.gear_items to anon,authenticated;
grant select on public.gear_rentals to authenticated;
grant all on public.gear_items,public.gear_rentals to service_role;
create policy read_gear_items on public.gear_items for select using(active or public.is_staff());
create policy read_gear_rentals on public.gear_rentals for select to authenticated using(user_id=auth.uid() or public.is_staff());

-- Day rentals run from opening (09:00) on the pickup date to closing (18:00) on the return
-- date and are counted in calendar days, inclusive. Hour rentals sit within 09:00–18:00
-- on a single Nairobi day, in whole hours.
create function private.gear_window(p_unit text,p_start timestamptz,p_end timestamptz,out starts_at timestamptz,out ends_at timestamptz,out units integer) language plpgsql stable set search_path='' as $$
declare ls timestamp:=p_start at time zone 'Africa/Nairobi'; le timestamp:=p_end at time zone 'Africa/Nairobi'; today date:=(now() at time zone 'Africa/Nairobi')::date; minutes numeric;
begin
 if p_start is null or p_end is null then raise exception 'Choose rental dates'; end if;
 if p_unit='day' then
  if ls::date<today then raise exception 'Choose a pickup date from today onwards'; end if;
  if le::date<ls::date then raise exception 'The return date must be on or after the pickup date'; end if;
  units:=le::date-ls::date+1;
  if units>30 then raise exception 'Day rentals can run for up to 30 days. Contact the team for longer rentals.'; end if;
  starts_at:=(ls::date+time '09:00') at time zone 'Africa/Nairobi'; ends_at:=(le::date+time '18:00') at time zone 'Africa/Nairobi';
 else
  minutes:=extract(epoch from p_end-p_start)/60;
  if p_start<now() then raise exception 'Choose a future start time'; end if;
  if ls::date<>le::date or ls::time<time '09:00' or le::time>time '18:00' or minutes<60 or minutes%60<>0 or extract(second from ls)<>0 or extract(minute from ls)::int%30<>0 then raise exception 'Hourly rentals run in whole hours between 09:00 and 18:00 EAT on one day'; end if;
  units:=(minutes/60)::int; starts_at:=p_start; ends_at:=p_end;
 end if;
 if starts_at>now()+interval '90 days' then raise exception 'Choose a date within the next 90 days'; end if;
end; $$;

-- Units already promised for an overlapping period. Picked-up gear counts as out until it
-- is actually returned, even after its planned return time.
create function private.gear_units_out(p_item uuid,p_start timestamptz,p_end timestamptz) returns integer language sql stable security definer set search_path='' as $$
 select coalesce(sum(quantity),0)::int from public.gear_rentals
 where item_id=p_item and status in ('requested','approved','picked_up') and starts_at<p_end
  and (case when status='picked_up' then greatest(ends_at,now()) else ends_at end)>p_start; $$;

-- Staff access rents free; Midi and Sana members receive 30% and 50% off when their paid
-- membership covers the whole rental, matching space rental pricing.
create function private.gear_quote(p_user uuid,p_item public.gear_items,p_quantity integer,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w record; m public.memberships; discount text:='none'; factor numeric:=1;
begin
 if p_quantity is null or p_quantity<1 then raise exception 'Choose how many units you need'; end if;
 select * into w from private.gear_window(p_item.price_unit,p_start,p_end);
 if exists(select 1 from private.staff where user_id=p_user) then discount:='staff'; factor:=0;
 else
  select * into m from public.memberships where user_id=p_user and starts_at<=now() and w.starts_at>=starts_at and w.ends_at<=expires_at order by starts_at desc limit 1;
  if m.tier='midi' then discount:='midi'; factor:=0.7; elsif m.tier='sana' then discount:='sana'; factor:=0.5; end if;
 end if;
 return jsonb_build_object('starts_at',w.starts_at,'ends_at',w.ends_at,'units',w.units,'price_unit',p_item.price_unit,'unit_price',p_item.price,
  'quantity',p_quantity,'discount',discount,'membership_id',m.id,'price',round(p_item.price*w.units*p_quantity*factor,2),
  'units_free',greatest(0,p_item.quantity-private.gear_units_out(p_item.id,w.starts_at,w.ends_at)));
end; $$;

create function public.gear_quote(p_item uuid,p_quantity integer,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare g public.gear_items; q jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into g from public.gear_items where id=p_item and active;
 if not found then raise exception 'This item is not listed'; end if;
 q:=private.gear_quote(auth.uid(),g,p_quantity,p_start,p_end);
 return (q-'membership_id')||jsonb_build_object('available',g.available);
end; $$;

create function public.request_gear_rental(p_item uuid,p_quantity integer,p_start timestamptz,p_end timestamptz,p_note text,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); g public.gear_items; r public.gear_rentals; q jsonb; rid uuid;
begin
 if uid is null then raise exception 'Sign in required'; end if;
 if p_key is null then raise exception 'Invalid rental request'; end if;
 perform 1 from public.profiles where id=uid for update;
 select * into r from public.gear_rentals where user_id=uid and request_key=p_key;
 if found then return r.id; end if;
 -- The item row lock serializes availability checks for the same gear.
 select * into g from public.gear_items where id=p_item for update;
 if not found or not g.active then raise exception 'This item is not listed'; end if;
 if not g.available then raise exception 'This item is not currently available for rental'; end if;
 q:=private.gear_quote(uid,g,p_quantity,p_start,p_end);
 if (q->>'units_free')::int<p_quantity then raise exception 'Not enough units are available for those dates. Try fewer units or other dates.'; end if;
 insert into public.gear_rentals(user_id,item_id,item_name,quantity,starts_at,ends_at,price_unit,unit_price,units,discount,membership_id,price,note,request_key)
 values(uid,g.id,g.name,p_quantity,(q->>'starts_at')::timestamptz,(q->>'ends_at')::timestamptz,g.price_unit,g.price,(q->>'units')::int,q->>'discount',(q->>'membership_id')::uuid,(q->>'price')::numeric,left(coalesce(p_note,''),1000),p_key)
 returning id into rid;
 perform private.log('gear_requested',rid::text,jsonb_build_object('item_id',g.id,'quantity',p_quantity)); return rid;
end; $$;

create function public.set_gear_rental_status(p_id uuid,p_status text,p_reason text default '') returns void language plpgsql security definer set search_path='' as $$
declare r public.gear_rentals; staff boolean:=public.is_staff();
begin
 select * into r from public.gear_rentals where id=p_id for update;
 if auth.uid() is null or not found or (r.user_id<>auth.uid() and not staff) then raise exception 'Access denied'; end if;
 if r.status=p_status then return; end if;
 if p_status='cancelled' then
  if r.status not in ('requested','approved') then raise exception 'Only rentals that have not been picked up can be cancelled'; end if;
  if staff and r.user_id<>auth.uid() and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Enter a reason'; end if;
 elsif p_status='approved' then
  perform private.require_staff();
  if r.status<>'requested' or r.ends_at<now() then raise exception 'Only current requests can be approved'; end if;
 elsif p_status='picked_up' then
  perform private.require_staff();
  if r.status not in ('requested','approved') then raise exception 'Only requested or approved rentals can be handed over'; end if;
 elsif p_status='returned' then
  perform private.require_staff();
  if r.status<>'picked_up' then raise exception 'Only picked-up rentals can be returned'; end if;
 else raise exception 'Invalid status transition'; end if;
 update public.gear_rentals set status=p_status,updated_at=now(),
  picked_up_at=case when p_status='picked_up' then now() else picked_up_at end,
  returned_at=case when p_status='returned' then now() else returned_at end
 where id=p_id;
 perform private.log('gear_'||p_status,p_id::text,jsonb_build_object('previous_status',r.status,'reason',p_reason));
end; $$;

create function public.save_gear_item(p_id uuid,p_version integer,p_data jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare gid uuid:=coalesce(p_id,gen_random_uuid()); current_version integer;
begin perform private.require_staff();
 if p_id is not null then
  select version into current_version from public.gear_items where id=p_id for update;
  if current_version is null or current_version<>p_version then raise exception 'This item changed. Reload before saving.'; end if;
 end if;
 insert into public.gear_items(id,name,category,description,image_url,image_alt,price,price_unit,quantity,available,active,sort_order)
 values(gid,trim(p_data->>'name'),trim(coalesce(p_data->>'category','')),coalesce(p_data->>'description',''),coalesce(p_data->>'image_url',''),coalesce(p_data->>'image_alt',''),(p_data->>'price')::numeric,p_data->>'price_unit',(p_data->>'quantity')::int,coalesce((p_data->>'available')::boolean,true),coalesce((p_data->>'active')::boolean,true),coalesce((p_data->>'sort_order')::int,0))
 on conflict(id) do update set name=excluded.name,category=excluded.category,description=excluded.description,image_url=excluded.image_url,image_alt=excluded.image_alt,price=excluded.price,price_unit=excluded.price_unit,quantity=excluded.quantity,available=excluded.available,active=excluded.active,sort_order=excluded.sort_order,version=public.gear_items.version+1,updated_at=now();
 perform private.log('gear_item_saved',gid::text,jsonb_build_object('before_version',current_version,'data',p_data)); return gid;
end; $$;

revoke all on function private.gear_window(text,timestamptz,timestamptz),private.gear_units_out(uuid,timestamptz,timestamptz),private.gear_quote(uuid,public.gear_items,integer,timestamptz,timestamptz) from public,anon,authenticated;
revoke all on function public.gear_quote(uuid,integer,timestamptz,timestamptz),public.request_gear_rental(uuid,integer,timestamptz,timestamptz,text,uuid),public.set_gear_rental_status(uuid,text,text),public.save_gear_item(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.gear_quote(uuid,integer,timestamptz,timestamptz),public.request_gear_rental(uuid,integer,timestamptz,timestamptz,text,uuid),public.set_gear_rental_status(uuid,text,text),public.save_gear_item(uuid,integer,jsonb) to authenticated;

commit;
