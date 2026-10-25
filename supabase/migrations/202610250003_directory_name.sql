begin;

-- Optional name for the listing (artist or stage name). When set, the directory shows it instead of the account name.
alter table public.profiles add column directory_name text not null default '' check(length(directory_name)<=80);

create or replace function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
declare meta jsonb:=coalesce(new.raw_user_meta_data,'{}'); listed boolean:=coalesce(meta->>'directory_consent','')='true';
begin insert into public.profiles(id,email,full_name,phone,directory_consent_at,directory_name,county,area,disciplines,directory_instagram,directory_website,directory_email) values(new.id,coalesce(new.email,''),left(coalesce(meta->>'full_name',''),150),left(coalesce(meta->>'phone',''),30),
  case when listed then now() end,
  case when listed then left(trim(coalesce(meta->>'directory_name','')),80) else '' end,
  case when listed then left(coalesce(meta->>'county',''),40) else '' end,
  case when listed then left(coalesce(meta->>'area',''),60) else '' end,
  case when listed and jsonb_typeof(meta->'disciplines')='array' then array(select left(x,40) from jsonb_array_elements_text(meta->'disciplines') x limit 12) else '{}' end,
  case when listed then private.directory_contact('instagram',meta->>'instagram') else '' end,
  case when listed then private.directory_contact('website',meta->>'website') else '' end,
  case when listed then private.directory_contact('email',meta->>'contact_email') else '' end);
 return new; end; $$;

-- p_name comes last with a default, so the pages already live keep working between this migration and the push.
drop function public.update_directory(boolean,text,text[],text,text,text,text);
create function public.update_directory(p_listed boolean,p_county text,p_disciplines text[],p_area text default '',p_instagram text default '',p_website text default '',p_email text default '',p_name text default '') returns void language plpgsql security definer set search_path='' as $$
declare ig text:=private.directory_contact('instagram',p_instagram); web text:=private.directory_contact('website',p_website); mail text:=private.directory_contact('email',p_email); shown text:=trim(coalesce(p_name,''));
begin if auth.uid() is null then raise exception 'Sign in to update your listing'; end if;
 if p_listed then
  if length(trim(coalesce(p_county,''))) not between 1 and 40 or coalesce(cardinality(p_disciplines),0) not between 1 and 12 then raise exception 'Choose your county and what you do'; end if;
  if length(trim(coalesce(p_area,'')))>60 then raise exception 'Choose an area from the list'; end if;
  if length(shown)>80 then raise exception 'Keep the name on your listing to 80 characters'; end if;
  if shown='' and not exists(select 1 from public.profiles where id=auth.uid() and trim(full_name)<>'') then raise exception 'Add the name you want on your listing'; end if;
  if trim(coalesce(p_instagram,''))<>'' and ig='' then raise exception 'That Instagram username doesn''t look right. Use letters, numbers, dots and underscores'; end if;
  if trim(coalesce(p_website,''))<>'' and web='' then raise exception 'Enter your website as a full address, like https://example.com'; end if;
  if trim(coalesce(p_email,''))<>'' and mail='' then raise exception 'That email address doesn''t look right'; end if;
  if ig='' and web='' and mail='' then raise exception 'Add at least one way for bookers to reach you: Instagram, website or email'; end if;
 end if;
 update public.profiles set directory_consent_at=case when p_listed then coalesce(directory_consent_at,now()) end,
  directory_name=case when p_listed then shown else '' end,
  county=case when p_listed then trim(p_county) else '' end,
  area=case when p_listed then trim(coalesce(p_area,'')) else '' end,
  disciplines=case when p_listed then array(select left(trim(x),40) from unnest(p_disciplines) x where trim(x)<>'') else '{}' end,
  directory_instagram=case when p_listed then ig else '' end,
  directory_website=case when p_listed then web else '' end,
  directory_email=case when p_listed then mail else '' end
 where id=auth.uid(); end; $$;
revoke execute on function public.update_directory(boolean,text,text[],text,text,text,text,text) from public,anon;
grant execute on function public.update_directory(boolean,text,text[],text,text,text,text,text) to authenticated;

-- full_name is the name shown on the listing: the listing name when set, otherwise the account name (never both).
create or replace function public.artist_directory() returns table(full_name text,county text,area text,disciplines text[],instagram text,website text,email text) language sql stable security definer set search_path='' as $$
 select coalesce(nullif(p.directory_name,''),p.full_name),p.county,p.area,p.disciplines,p.directory_instagram,p.directory_website,p.directory_email from public.profiles p
 where p.directory_consent_at is not null and p.county<>'' and cardinality(p.disciplines)>0 and (trim(p.full_name)<>'' or p.directory_name<>'')
  and (p.directory_instagram<>'' or p.directory_website<>'' or p.directory_email<>'')
 order by random() $$;

commit;
