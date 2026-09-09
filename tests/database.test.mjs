import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {randomUUID} from 'node:crypto';

test('database enforces booking, payment and staff permissions',async t=>{
 const db=new PGlite();
 await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
 create schema auth; create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth to anon,authenticated,service_role;grant execute on function auth.uid() to anon,authenticated,service_role;
 create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);alter table storage.objects enable row level security;
 grant usage on schema storage to authenticated;grant insert,select on storage.objects to authenticated;`);
 for(const file of (await readdir('supabase/migrations')).sort())await db.exec(await readFile(`supabase/migrations/${file}`,'utf8'));
 await db.exec(await readFile('supabase/seed.sql','utf8'));
 const admin=randomUUID(),alice=randomUUID(),bob=randomUUID();
 for(const [id,name] of [[admin,'Admin'],[alice,'Alice'],[bob,'Bob']])await db.query(`insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3)`,[id,`${name.toLowerCase()}@example.test`,{full_name:name,role:'admin',alumni:true}]);
 await db.query('insert into private.staff values($1)',[admin]);
 const query=async(sql,params=[]) => (await db.query(sql,params)).rows;
 async function as(id,role='authenticated'){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id||'']);await db.exec(`set role ${role}`);}
 const rpc=async(name,args=[])=>{const rows=await query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as value`,args);return rows[0].value;};
 async function rejects(fn,pattern){await assert.rejects(fn,pattern);}
 const room=(await query("select * from public.spaces where slug='workstation'"))[0];
 let start,bookingId;
 await t.test('anonymous catalog is readable; private records and RPCs are closed',async()=>{
  await as(null,'anon');assert.equal((await query('select * from public.spaces')).length,4);
  await rejects(()=>query('select * from public.profiles'),/permission denied/);
  await rejects(()=>rpc('calendar_jobs'),/permission denied/);
  await rejects(()=>rpc('request_booking',[room.id,new Date().toISOString(),60,false,'',randomUUID()]),/permission denied/);
 });
 await t.test('signup metadata cannot assign staff or alumni access',async()=>{
  await as(alice);assert.equal(await rpc('is_staff'),false);assert.equal((await query('select * from public.profiles'))[0].alumni,false);
  assert.equal((await query('select * from public.profiles')).length,1);
  await rejects(()=>query('update public.profiles set alumni=true'),/permission denied/);
  await rejects(()=>rpc('set_alumni',[alice,true]),/Staff access/);
  await rejects(()=>rpc('activate_membership',[alice,'sana','BAD']),/Staff access/);
  await rejects(()=>query('select * from private.staff'),/permission denied/);
  await rejects(()=>rpc('member_allowances',[bob]),/Staff access/);
 });
 await t.test('staff configure schedules and protect against stale edits',async()=>{
  await as(admin);assert.equal(await rpc('is_staff'),true);
  const hours=Array.from({length:7},(_,weekday)=>({weekday,opens:'09:00',closes:'18:00'}));
  await rpc('save_space',[room.id,room.version,{...room,booking_enabled:true},hours]);
  await rejects(()=>rpc('save_space',[room.id,room.version,{...room,name:'Lost update'},hours]),/changed/);
  await rejects(()=>rpc('save_space',[room.id,2,{...room,booking_enabled:true},[{weekday:1,opens:'08:00',closes:'18:00'}]]),/check constraint/);
  await rpc('set_alumni',[alice,true]);await rpc('activate_membership',[alice,'midi','TEST-MIDI-1']);
  await rejects(()=>rpc('activate_membership',[alice,'midi','TEST-MIDI-2']),/active membership/);
 await rejects(()=>rpc('activate_membership',[bob,'midi','TEST-MIDI-3']),/alumni/);
  start=(await query("select ((date_trunc('week',now() at time zone 'Africa/Nairobi')::date+7)+time '09:00') at time zone 'Africa/Nairobi' as start"))[0].start;
  await rpc('set_staff_member',[alice,true]);assert.equal(await rpc('member_is_staff',[alice]),true);
  await as(alice);const staffBalance=await rpc('member_allowances',[alice,start]);assert.equal(staffBalance.production.tier,'staff');assert.equal(staffBalance.production.unlimited,true);assert.equal(staffBalance.studio.unlimited,true);
  await as(admin);await rpc('set_staff_member',[alice,false]);assert.equal(await rpc('member_is_staff',[alice]),false);
 });
 await t.test('slot validation, reservations and idempotency run in the database',async()=>{
  await as(alice);const date=new Date(new Date(start).getTime()+3*3600000).toISOString().slice(0,10);
  const slots=await query('select * from available_slots($1,$2,60)',[room.id,date]);assert.ok(slots.length>0);
  const key=randomUUID();bookingId=await rpc('request_booking',[room.id,start,60,true,'Test',key]);
  assert.equal(await rpc('request_booking',[room.id,start,60,true,'Test',key]),bookingId);
  await as(null,'service_role');assert.equal((await query("select kind,recipient from private.email_outbox where booking_id=$1",[bookingId]))[0].kind,'request_received');assert.equal((await query("select recipient from private.email_outbox where booking_id=$1",[bookingId]))[0].recipient,'alice@example.test');await as(alice);
  await rejects(()=>rpc('request_booking',[room.id,start,60,true,'',randomUUID()]),/unavailable/);
  await rejects(()=>rpc('request_booking',[room.id,new Date(new Date(start).getTime()+60000).toISOString(),60,true,'',randomUUID()]),/unavailable/);
  const balance=await rpc('my_allowances',[start]);assert.equal(balance.production.remaining,180);assert.equal(balance.production.reserved,60);
  assert.equal((await query('select * from payments')).length,1);
  await rejects(()=>query("update bookings set status='confirmed'"),/permission denied/);
  await rejects(()=>rpc('set_booking_status',[bookingId,'confirmed','']),/Staff access/);
  await as(bob);assert.equal((await query('select * from bookings')).length,0);assert.equal((await query('select * from payments')).length,0);
  await rejects(()=>rpc('set_booking_status',[bookingId,'cancelled','']),/Access denied/);
  await rejects(()=>rpc('request_booking',[room.id,start,60,false,'',randomUUID()]),/unavailable/);
 });
 await t.test('cancellation releases allowance; Monday resets and expiry use Nairobi time',async()=>{
  await as(alice);await rpc('set_booking_status',[bookingId,'cancelled','']);assert.equal((await rpc('my_allowances',[start])).production.remaining,240);
  const later=new Date(new Date(start).getTime()+7*86400000).toISOString();assert.equal((await rpc('my_allowances',[later])).production.remaining,240);
  const expired=new Date(Date.now()+31*86400000).toISOString();assert.equal((await rpc('my_allowances',[expired])).production.tier,'free');
  const time2=new Date(new Date(start).getTime()+3600000).toISOString();bookingId=await rpc('request_booking',[room.id,time2,60,false,'',randomUUID()]);
  assert.equal(Number((await query('select price from bookings where id=$1',[bookingId]))[0].price),700);
 });
 await t.test('payments are staff-only, bounded, reference-unique and auditable',async()=>{
  await rejects(()=>rpc('record_payment',[bookingId,700,'UNAUTH']),/Staff access/);
  await as(admin);const payment=await rpc('record_payment',[bookingId,500,'TEST-PARTIAL']);
  await rejects(()=>rpc('record_payment',[bookingId,300,'TEST-OVER']),/outstanding/);
  await rejects(()=>rpc('record_payment',[bookingId,100,'TEST-PARTIAL']),/unique constraint/);
  await rpc('void_payment',[payment,'Incorrect reference']);assert.equal((await query('select status from payments where id=$1',[payment]))[0].status,'void');
  await rpc('record_payment',[bookingId,700,'TEST-FULL']);
  assert.ok((await query("select * from audit_log where action='payment_voided'")).length===1);
 });
 await t.test('staff blocks and archive preserve bookings',async()=>{
  const b=(await query('select * from bookings where id=$1',[bookingId]))[0];
  await rejects(()=>rpc('add_block',[room.id,b.starts_at,b.ends_at,'Maintenance']),/overlapping/);
  const current=(await query('select * from spaces where id=$1',[room.id]))[0];await rpc('archive_space',[room.id,current.version,false]);
  assert.ok((await query('select * from bookings where id=$1',[bookingId])).length===1);
  await as(alice);assert.equal((await query('select * from spaces where id=$1',[room.id])).length,0);
  await rejects(()=>rpc('request_booking',[room.id,start,60,true,'',randomUUID()]),/unavailable/);
  await as(admin);await rpc('archive_space',[room.id,current.version+1,true]);
 });
 await t.test('Sana studio frequency is not invented; explicit weekly grants work',async()=>{
  await rpc('set_alumni',[bob,true]);await rpc('activate_membership',[bob,'sana','TEST-SANA']);
  const balances=await rpc('member_allowances',[bob,start]);assert.equal(balances.studio.allocated,0);assert.equal(balances.production.allocated,480);
  await rpc('adjust_allowance',[bob,balances.production.week_start,'studio',4,'Team approved for this week']);
  assert.equal((await rpc('member_allowances',[bob,start])).studio.remaining,4);
  await as(bob);await rejects(()=>rpc('adjust_allowance',[bob,balances.production.week_start,'studio',20,'Self grant']),/Staff access/);
 });
 await t.test('calendar sync functions are service-only and stale calendars close slots',async()=>{
  await as(admin);await rpc('connect_calendar',[room.id,'test@group.calendar.google.com']);
  await as(alice);await rejects(()=>rpc('request_booking',[room.id,start,60,true,'',randomUUID()]),/unavailable/);
  await rejects(()=>rpc('replace_google_blocks',[room.id,[],1]),/permission denied/);
  await as(null,'service_role');const token=randomUUID();assert.equal(await rpc('claim_calendar_sync',[token]),true);assert.equal(await rpc('claim_calendar_sync',[randomUUID()]),false);await rpc('release_calendar_sync',[token]);
  await rpc('replace_google_blocks',[room.id,[],1]);
  await as(alice);assert.ok(await rpc('request_booking',[room.id,start,60,true,'',randomUUID()]));
 });
 await t.test('image storage policies deny non-staff uploads',async()=>{
  await as(alice);await rejects(()=>query("insert into storage.objects(bucket_id,name) values('space-images','alice.jpg')"),/row-level security/);
  await as(admin);await query("insert into storage.objects(bucket_id,name) values('space-images','staff.jpg')");
 });
 await db.close();
});
