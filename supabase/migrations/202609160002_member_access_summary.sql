begin;

create function public.member_access_summary()
returns table(user_id uuid,is_staff boolean,is_student boolean,is_nura boolean,membership_tier text)
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_staff();
  return query
    select p.id,
      exists(select 1 from private.staff st where st.user_id=p.id),
      exists(select 1 from private.students su where su.user_id=p.id),
      exists(select 1 from private.nura_members nm where nm.user_id=p.id),
      (select m.tier from public.memberships m where m.user_id=p.id and now()>=m.starts_at and now()<m.expires_at order by m.starts_at desc limit 1)
    from public.profiles p;
end; $$;

revoke all on function public.member_access_summary() from public,anon,authenticated;
grant execute on function public.member_access_summary() to authenticated;
commit;
