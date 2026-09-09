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
