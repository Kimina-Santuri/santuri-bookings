begin;

alter table public.profiles add column phone text not null default '' check(length(phone)<=30);

create or replace function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.profiles(id,email,full_name,phone) values(new.id,coalesce(new.email,''),left(coalesce(new.raw_user_meta_data->>'full_name',''),150),left(coalesce(new.raw_user_meta_data->>'phone',''),30)); return new; end; $$;

drop function if exists public.update_profile(text);
create function public.update_profile(p_name text,p_phone text) returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null or length(trim(p_name)) not between 1 and 150 then raise exception 'Enter your name'; end if;
 if length(trim(coalesce(p_phone,'')))>30 then raise exception 'Enter a valid phone number'; end if;
 update public.profiles set full_name=trim(p_name), phone=trim(coalesce(p_phone,'')) where id=auth.uid(); end; $$;
grant execute on function public.update_profile(text,text) to authenticated;

commit;
