begin;

-- Optional constituency ("area") for directory listings, e.g. Westlands in Nairobi or Thika Town in Kiambu.
alter table public.profiles add column area text not null default '' check(length(area)<=60);

create or replace function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
declare meta jsonb:=coalesce(new.raw_user_meta_data,'{}'); listed boolean:=coalesce(meta->>'directory_consent','')='true';
begin insert into public.profiles(id,email,full_name,phone,directory_consent_at,county,area,disciplines) values(new.id,coalesce(new.email,''),left(coalesce(meta->>'full_name',''),150),left(coalesce(meta->>'phone',''),30),
  case when listed then now() end,
  case when listed then left(coalesce(meta->>'county',''),40) else '' end,
  case when listed then left(coalesce(meta->>'area',''),60) else '' end,
  case when listed and jsonb_typeof(meta->'disciplines')='array' then array(select left(x,40) from jsonb_array_elements_text(meta->'disciplines') x limit 12) else '{}' end);
 return new; end; $$;

drop function public.update_directory(boolean,text,text[]);
create function public.update_directory(p_listed boolean,p_county text,p_disciplines text[],p_area text default '') returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Sign in to update your listing'; end if;
 if p_listed and (length(trim(coalesce(p_county,''))) not between 1 and 40 or coalesce(cardinality(p_disciplines),0) not between 1 and 12) then raise exception 'Choose your county and what you do'; end if;
 if p_listed and length(trim(coalesce(p_area,'')))>60 then raise exception 'Choose an area from the list'; end if;
 if p_listed and not exists(select 1 from public.profiles where id=auth.uid() and trim(phone)<>'') then raise exception 'Add your phone number to your profile so bookers can reach you'; end if;
 update public.profiles set directory_consent_at=case when p_listed then coalesce(directory_consent_at,now()) end,
  county=case when p_listed then trim(p_county) else '' end,
  area=case when p_listed then trim(coalesce(p_area,'')) else '' end,
  disciplines=case when p_listed then array(select left(trim(x),40) from unnest(p_disciplines) x where trim(x)<>'') else '{}' end
 where id=auth.uid(); end; $$;
revoke execute on function public.update_directory(boolean,text,text[],text) from public,anon;
grant execute on function public.update_directory(boolean,text,text[],text) to authenticated;

drop function public.artist_directory();
create function public.artist_directory() returns table(full_name text,county text,area text,disciplines text[],phone text) language sql stable security definer set search_path='' as $$
 select p.full_name,p.county,p.area,p.disciplines,p.phone from public.profiles p
 where p.directory_consent_at is not null and p.county<>'' and cardinality(p.disciplines)>0 and trim(p.full_name)<>'' and trim(p.phone)<>''
 order by random() $$;
revoke execute on function public.artist_directory() from public;
grant execute on function public.artist_directory() to anon,authenticated;

commit;
