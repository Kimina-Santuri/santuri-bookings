begin;

-- Listing photos. The listing page shrinks each photo on the member's device (640px square WebP or JPEG, usually under 100 KB)
-- before upload; the bucket's 300 KB limit is only a backstop. Each member writes only inside their own folder: <user id>/<file>.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('directory-photos','directory-photos',true,307200,array['image/webp','image/jpeg']) on conflict(id) do nothing;
create policy member_upload_directory_photo on storage.objects for insert to authenticated with check(bucket_id='directory-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy member_read_directory_photo on storage.objects for select to authenticated using(bucket_id='directory-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy member_delete_directory_photo on storage.objects for delete to authenticated using(bucket_id='directory-photos' and split_part(name,'/',1)=auth.uid()::text);

alter table public.profiles add column directory_photo text not null default '' check(directory_photo='' or directory_photo ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|jpg)$');

-- Point the listing at a photo the member has uploaded to their own folder, or '' to remove it.
create function public.set_directory_photo(p_path text) returns void language plpgsql security definer set search_path='' as $$
declare path text:=coalesce(p_path,'');
begin if auth.uid() is null then raise exception 'Sign in to update your listing'; end if;
 if path<>'' and (split_part(path,'/',1)<>auth.uid()::text or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|jpg)$'
  or not exists(select 1 from storage.objects where bucket_id='directory-photos' and name=path)) then raise exception 'That photo could not be found. Please upload it again'; end if;
 update public.profiles set directory_photo=path where id=auth.uid(); end; $$;
revoke execute on function public.set_directory_photo(text) from public,anon;
grant execute on function public.set_directory_photo(text) to authenticated;

-- Leaving the directory drops the photo from the listing too (the page also deletes the file).
create function private.clear_directory_photo() returns trigger language plpgsql set search_path='' as $$
begin if new.directory_consent_at is null then new.directory_photo:=''; end if; return new; end; $$;
create trigger clear_directory_photo before update of directory_consent_at on public.profiles for each row execute function private.clear_directory_photo();

drop function public.artist_directory();
create function public.artist_directory() returns table(full_name text,county text,area text,disciplines text[],instagram text,website text,email text,photo text) language sql stable security definer set search_path='' as $$
 select coalesce(nullif(p.directory_name,''),p.full_name),p.county,p.area,p.disciplines,p.directory_instagram,p.directory_website,p.directory_email,p.directory_photo from public.profiles p
 where p.directory_consent_at is not null and p.county<>'' and cardinality(p.disciplines)>0 and (trim(p.full_name)<>'' or p.directory_name<>'')
  and (p.directory_instagram<>'' or p.directory_website<>'' or p.directory_email<>'')
 order by random() $$;
revoke execute on function public.artist_directory() from public;
grant execute on function public.artist_directory() to anon,authenticated;

commit;
