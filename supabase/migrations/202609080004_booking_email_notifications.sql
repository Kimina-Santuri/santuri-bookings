begin;

-- Booking notifications are queued in the database and sent by a service-only
-- Edge Function. SMTP credentials never reach the browser or a client RPC.
create table private.email_outbox (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  recipient text not null check(recipient ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'),
  kind text not null check(kind in ('request_received','booking_confirmed','booking_cancelled','booking_completed','booking_no_show','booking_reminder')),
  payload jsonb not null default '{}',
  attempts integer not null default 0 check(attempts>=0),
  next_attempt_at timestamptz not null default now(),
  claimed_at timestamptz,
  claim_token uuid,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique(booking_id,kind)
);
alter table private.email_outbox enable row level security;
revoke all on private.email_outbox from public,anon,authenticated;
grant all on private.email_outbox to service_role;

create function private.queue_booking_email() returns trigger
language plpgsql security definer set search_path='' as $$
declare p public.profiles; k text; subject text;
begin
  select * into p from public.profiles where id=new.user_id;
  if p.email is null or length(trim(p.email))=0 then return new; end if;
  if tg_op='INSERT' then k:='request_received';
  elsif new.status=old.status then return new;
  elsif new.status='confirmed' then k:='booking_confirmed';
  elsif new.status='cancelled' then k:='booking_cancelled';
  elsif new.status='completed' then k:='booking_completed';
  elsif new.status='no_show' then k:='booking_no_show';
  else return new; end if;
  subject:=case k
    when 'request_received' then 'Santuri booking request received'
    when 'booking_confirmed' then 'Santuri booking confirmed'
    when 'booking_cancelled' then 'Santuri booking cancelled'
    when 'booking_completed' then 'Santuri booking completed'
    else 'Santuri booking marked as no-show' end;
  insert into private.email_outbox(booking_id,recipient,kind,payload)
  values(new.id,lower(trim(p.email)),k,jsonb_build_object(
    'subject',subject,'name',p.full_name,'space',new.space_name,
    'starts_at',new.starts_at,'ends_at',new.ends_at,'status',new.status,
    'price',new.price,'use_allowance',new.use_allowance,'note',new.note))
  on conflict(booking_id,kind) do nothing;
  return new;
end; $$;
create trigger booking_email_outbox after insert or update of status on public.bookings
for each row execute function private.queue_booking_email();

-- Claiming is atomic and safe when more than one scheduled invocation overlaps.
create function public.claim_email_jobs(p_token uuid,p_limit integer default 25)
returns table(id uuid,recipient text,kind text,payload jsonb,attempts integer)
language plpgsql security definer set search_path='' as $$
begin
  if p_token is null or p_limit is null or p_limit<1 or p_limit>100 then raise exception 'Invalid email job claim'; end if;
  return query with picked as (
    select o.id from private.email_outbox o
    where o.sent_at is null and o.next_attempt_at<=now()
      and (o.claimed_at is null or o.claimed_at<now()-interval '10 minutes')
    order by o.created_at limit p_limit for update skip locked
  ) update private.email_outbox o
    set claim_token=p_token,claimed_at=now(),attempts=o.attempts+1
    from picked where o.id=picked.id
    returning o.id,o.recipient,o.kind,o.payload,o.attempts;
end; $$;
create function public.complete_email_job(p_id uuid,p_token uuid,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_error is null then
    update private.email_outbox set sent_at=now(),claim_token=null,claimed_at=null,last_error=null where id=p_id and claim_token=p_token;
  else
    update private.email_outbox set next_attempt_at=now()+least(make_interval(mins=>power(2,least(attempts,6))::int),interval '6 hours'),claim_token=null,claimed_at=null,last_error=left(p_error,1000) where id=p_id and claim_token=p_token;
  end if;
end; $$;
revoke all on function public.claim_email_jobs(uuid,integer),public.complete_email_job(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.claim_email_jobs(uuid,integer),public.complete_email_job(uuid,uuid,text) to service_role;

create function public.queue_booking_reminders() returns integer
language plpgsql security definer set search_path='' as $$
declare added integer;
begin
  insert into private.email_outbox(booking_id,recipient,kind,payload)
  select b.id,lower(trim(p.email)),'booking_reminder',jsonb_build_object(
    'subject','Santuri booking reminder','name',p.full_name,'space',b.space_name,
    'starts_at',b.starts_at,'ends_at',b.ends_at,'status',b.status,
    'price',b.price,'use_allowance',b.use_allowance,'note',b.note)
  from public.bookings b join public.profiles p on p.id=b.user_id
  where b.status='confirmed' and b.starts_at between now()+interval '23 hours' and now()+interval '25 hours'
    and p.email is not null and length(trim(p.email))>0
  on conflict(booking_id,kind) do nothing;
  get diagnostics added=row_count; return added;
end; $$;
revoke all on function public.queue_booking_reminders() from public,anon,authenticated;
grant execute on function public.queue_booking_reminders() to service_role;

commit;
