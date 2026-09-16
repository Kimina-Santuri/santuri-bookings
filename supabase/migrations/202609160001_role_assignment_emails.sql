begin;

-- Role notices use the same private, retryable outbox as booking messages.
alter table private.email_outbox alter column booking_id drop not null;
alter table private.email_outbox drop constraint email_outbox_kind_check;
alter table private.email_outbox add constraint email_outbox_kind_check check(kind in ('request_received','booking_confirmed','booking_cancelled','booking_completed','booking_no_show','booking_reminder','role_assigned'));

create function private.queue_role_assignment_email(p_user uuid,p_role text) returns void
language plpgsql security definer set search_path='' as $$
declare p public.profiles; role_label text;
begin
  if p_role not in ('staff','student','nura') then raise exception 'Invalid role for email notification'; end if;
  select * into p from public.profiles where id=p_user;
  if p.email is null or length(trim(p.email))=0 then return; end if;
  role_label:=case p_role when 'staff' then 'Staff access' when 'student' then 'Student access' else 'NURA access' end;
  insert into private.email_outbox(booking_id,recipient,kind,payload)
  values(null,lower(trim(p.email)),'role_assigned',jsonb_build_object('subject','Santuri access updated','name',p.full_name,'role',p_role,'role_label',role_label))
  on conflict do nothing;
end; $$;

create or replace function public.set_staff_member(p_user uuid,p_staff boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  if p_staff then
    if not exists(select 1 from private.staff where user_id=p_user) then
      insert into private.staff(user_id) values(p_user);
      perform private.queue_role_assignment_email(p_user,'staff');
    end if;
  else delete from private.staff where user_id=p_user; end if;
  perform private.log(case when p_staff then 'staff_access_granted' else 'staff_access_revoked' end,p_user::text);
end; $$;

create or replace function public.set_student_member(p_user uuid,p_student boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  if p_student is null then raise exception 'Student access choice is required'; end if;
  perform 1 from public.profiles where id=p_user for update;
  if not found then raise exception 'Member not found'; end if;
  if p_student then
    if not exists(select 1 from private.students where user_id=p_user) then
      insert into private.students(user_id) values(p_user);
      perform private.queue_role_assignment_email(p_user,'student');
    end if;
  else delete from private.students where user_id=p_user; end if;
  perform private.log(case when p_student then 'student_access_granted' else 'student_access_revoked' end,p_user::text);
end; $$;

create or replace function public.set_nura_member(p_user uuid,p_nura boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  if p_nura is null then raise exception 'NURA access choice is required'; end if;
  perform 1 from public.profiles where id=p_user for update;
  if not found then raise exception 'Member not found'; end if;
  if p_nura then
    if not exists(select 1 from private.nura_members where user_id=p_user) then
      insert into private.nura_members(user_id) values(p_user);
      perform private.queue_role_assignment_email(p_user,'nura');
    end if;
  else delete from private.nura_members where user_id=p_user; end if;
  perform private.log(case when p_nura then 'nura_access_granted' else 'nura_access_revoked' end,p_user::text);
end; $$;

revoke all on function private.queue_role_assignment_email(uuid,text) from public,anon,authenticated;
commit;
