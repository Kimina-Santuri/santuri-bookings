begin;

-- Listings show the contacts each artist chooses (Instagram, website, email) instead of their phone number.
alter table public.profiles
 add column directory_instagram text not null default '' check(directory_instagram='' or directory_instagram ~ '^[A-Za-z0-9._]{1,30}$'),
 add column directory_website text not null default '' check(directory_website='' or (directory_website ~* '^https?://[^[:space:]<>"]+$' and length(directory_website)<=200)),
 add column directory_email text not null default '' check(directory_email='' or (directory_email ~* '^[^[:space:]@<>"]+@[^[:space:]@<>"]+\.[^[:space:]@<>"]+$' and length(directory_email)<=254));

-- A contact in its stored form, or '' when it isn't valid. Instagram accepts @handle.
create function private.directory_contact(p_kind text,p_value text) returns text language sql immutable set search_path='' as $$
 select case
  when p_kind='instagram' and ltrim(trim(coalesce(p_value,'')),'@') ~ '^[A-Za-z0-9._]{1,30}$' then ltrim(trim(p_value),'@')
  when p_kind='website' and trim(coalesce(p_value,'')) ~* '^https?://[^[:space:]<>"]+$' and length(trim(p_value))<=200 then trim(p_value)
  when p_kind='email' and trim(coalesce(p_value,'')) ~* '^[^[:space:]@<>"]+@[^[:space:]@<>"]+\.[^[:space:]@<>"]+$' and length(trim(p_value))<=254 then lower(trim(p_value))
  else '' end $$;

-- Sign-up keeps going when a contact is malformed; that contact is just left out.
create or replace function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
declare meta jsonb:=coalesce(new.raw_user_meta_data,'{}'); listed boolean:=coalesce(meta->>'directory_consent','')='true';
begin insert into public.profiles(id,email,full_name,phone,directory_consent_at,county,area,disciplines,directory_instagram,directory_website,directory_email) values(new.id,coalesce(new.email,''),left(coalesce(meta->>'full_name',''),150),left(coalesce(meta->>'phone',''),30),
  case when listed then now() end,
  case when listed then left(coalesce(meta->>'county',''),40) else '' end,
  case when listed then left(coalesce(meta->>'area',''),60) else '' end,
  case when listed and jsonb_typeof(meta->'disciplines')='array' then array(select left(x,40) from jsonb_array_elements_text(meta->'disciplines') x limit 12) else '{}' end,
  case when listed then private.directory_contact('instagram',meta->>'instagram') else '' end,
  case when listed then private.directory_contact('website',meta->>'website') else '' end,
  case when listed then private.directory_contact('email',meta->>'contact_email') else '' end);
 return new; end; $$;

drop function public.update_directory(boolean,text,text[],text);
create function public.update_directory(p_listed boolean,p_county text,p_disciplines text[],p_area text default '',p_instagram text default '',p_website text default '',p_email text default '') returns void language plpgsql security definer set search_path='' as $$
declare ig text:=private.directory_contact('instagram',p_instagram); web text:=private.directory_contact('website',p_website); mail text:=private.directory_contact('email',p_email);
begin if auth.uid() is null then raise exception 'Sign in to update your listing'; end if;
 if p_listed then
  if length(trim(coalesce(p_county,''))) not between 1 and 40 or coalesce(cardinality(p_disciplines),0) not between 1 and 12 then raise exception 'Choose your county and what you do'; end if;
  if length(trim(coalesce(p_area,'')))>60 then raise exception 'Choose an area from the list'; end if;
  if trim(coalesce(p_instagram,''))<>'' and ig='' then raise exception 'That Instagram username doesn''t look right. Use letters, numbers, dots and underscores'; end if;
  if trim(coalesce(p_website,''))<>'' and web='' then raise exception 'Enter your website as a full address, like https://example.com'; end if;
  if trim(coalesce(p_email,''))<>'' and mail='' then raise exception 'That email address doesn''t look right'; end if;
  if ig='' and web='' and mail='' then raise exception 'Add at least one way for bookers to reach you: Instagram, website or email'; end if;
 end if;
 update public.profiles set directory_consent_at=case when p_listed then coalesce(directory_consent_at,now()) end,
  county=case when p_listed then trim(p_county) else '' end,
  area=case when p_listed then trim(coalesce(p_area,'')) else '' end,
  disciplines=case when p_listed then array(select left(trim(x),40) from unnest(p_disciplines) x where trim(x)<>'') else '{}' end,
  directory_instagram=case when p_listed then ig else '' end,
  directory_website=case when p_listed then web else '' end,
  directory_email=case when p_listed then mail else '' end
 where id=auth.uid(); end; $$;
revoke execute on function public.update_directory(boolean,text,text[],text,text,text,text) from public,anon;
grant execute on function public.update_directory(boolean,text,text[],text,text,text,text) to authenticated;

-- Phone numbers are no longer published.
drop function public.artist_directory();
create function public.artist_directory() returns table(full_name text,county text,area text,disciplines text[],instagram text,website text,email text) language sql stable security definer set search_path='' as $$
 select p.full_name,p.county,p.area,p.disciplines,p.directory_instagram,p.directory_website,p.directory_email from public.profiles p
 where p.directory_consent_at is not null and p.county<>'' and cardinality(p.disciplines)>0 and trim(p.full_name)<>''
  and (p.directory_instagram<>'' or p.directory_website<>'' or p.directory_email<>'')
 order by random() $$;
revoke execute on function public.artist_directory() from public;
grant execute on function public.artist_directory() to anon,authenticated;

commit;
