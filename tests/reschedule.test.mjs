import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {randomUUID} from 'node:crypto';

test('staff reschedule keeps availability, allowance, price, calendar and email consistent',async t=>{
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
 for(const [id,name] of [[admin,'Admin'],[alice,'Alice'],[bob,'Bob']])await db.query(`insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3)`,[id,`${name.toLowerCase()}@example.test`,{full_name:name}]);
 await db.query('insert into private.staff values($1)',[admin]);
 const query=async(sql,params=[]) => (await db.query(sql,params)).rows;
 async function as(id,role='authenticated'){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id||'']);await db.exec(`set role ${role}`);}
 const rpc=async(name,args=[])=>{const rows=await query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as value`,args);return rows[0].value;};
 const rejects=(fn,pattern)=>assert.rejects(fn,pattern);
 const hours=n=>n*3600000,at=(base,ms)=>new Date(new Date(base).getTime()+ms).toISOString();
 const booking=async id=>(await query('select * from bookings where id=$1',[id]))[0];
 const asService=async fn=>{await as(null,'service_role');const out=await fn();await as(admin);return out;};

 await as(admin);
 for(const r of await query('select * from spaces'))await rpc('save_space',[r.id,r.version,{...r,booking_enabled:true},Array.from({length:7},(_,weekday)=>({weekday,opens:'09:00',closes:['dj','classroom'].includes(r.slug)&&[5,6].includes(weekday)?'19:00':'18:00'}))]);
 await rpc('set_alumni',[alice,true]);await rpc('activate_membership',[alice,'midi','TEST-MIDI']);
 const workstation=(await query("select * from spaces where slug='workstation'"))[0],dj=(await query("select * from spaces where slug='dj'"))[0];
 const monday=(await query("select ((date_trunc('week',now() at time zone 'Africa/Nairobi')::date+7)+time '09:00') at time zone 'Africa/Nairobi' as t"))[0].t.toISOString();
 await as(alice);const allowanceBooking=await rpc('request_booking',[workstation.id,monday,60,true,'',randomUUID(),'none']);
 await as(bob);const paidBooking=await rpc('request_booking',[dj.id,at(monday,hours(25)),120,false,'',randomUUID(),'hand']);
 assert.equal(Number((await booking(paidBooking)).price),4000);

 await t.test('only staff can reschedule, with a reason, into a free slot',async()=>{
  await as(alice);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,hours(2)),60,'Member moved']),/Staff access/);
  await rejects(()=>query('select * from reschedule_slots($1,$2,60)',[allowanceBooking,monday.slice(0,10)]),/Staff access/);
  await as(admin);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,hours(2)),60,'']),/reason/);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,monday,60,'No change']),/different time/);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,-hours(1)),60,'Before opening']),/unavailable/);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,hours(8.5)),60,'After closing']),/unavailable/);
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,hours(0.25)),60,'Off the half hour']),/unavailable/);
  await rejects(()=>rpc('reschedule_booking',[paidBooking,at(monday,-hours(7*24)),120,'Into the past']),/unavailable/);
  await as(bob);const blocker=await rpc('request_booking',[workstation.id,at(monday,hours(3)),60,false,'',randomUUID(),'none']);
  await as(admin);await rejects(()=>rpc('reschedule_booking',[allowanceBooking,at(monday,hours(3)),60,'Onto Bob']),/unavailable/);
  const slots=await query('select * from reschedule_slots($1,$2,90)',[allowanceBooking,monday.slice(0,10)]);
  assert.ok(slots.some(s=>s.starts_at.toISOString()===monday),'its own current slot is free to extend');
  assert.ok(!slots.some(s=>s.starts_at.toISOString()===at(monday,hours(2.5))),'overlapping another booking is not offered');
  await rpc('set_booking_status',[blocker,'cancelled','Test cleanup']);
 });

 await t.test('extending in the same week re-checks the allowance and updates calendar, email and audit',async()=>{
  const revision=async()=>asService(async()=>(await query('select revision from private.calendar_jobs where booking_id=$1',[allowanceBooking]))[0].revision);
  const before=await revision();
  await asService(()=>query("insert into private.email_outbox(booking_id,recipient,kind) values($1,'alice@example.test','booking_reminder')",[allowanceBooking]));
  await rpc('reschedule_booking',[allowanceBooking,monday,90,'Member asked for longer']);
  const row=await booking(allowanceBooking);assert.equal(row.ends_at.toISOString(),at(monday,hours(1.5)));assert.equal(Number(row.price),0);
  assert.equal(await revision(),before+1);
  assert.equal((await rpc('member_allowances',[alice,monday])).production.remaining,150);
  const mail=await asService(()=>query("select * from private.email_outbox where booking_id=$1 order by kind",[allowanceBooking]));
  assert.deepEqual(mail.map(m=>m.kind),['booking_rescheduled','request_received'],'stale reminder removed');
  const payload=mail[0].payload;assert.equal(new Date(payload.previous_ends_at).toISOString(),at(monday,hours(1)));assert.equal(new Date(payload.ends_at).toISOString(),at(monday,hours(1.5)));
  assert.equal((await query("select details->>'reason' as reason from audit_log where action='booking_rescheduled'"))[0].reason,'Member asked for longer');
  await rejects(()=>rpc('reschedule_booking',[allowanceBooking,monday,300,'Too long for allowance']),/Not enough allowance/);
 });

 await t.test('moving to another week releases the old week; a second move re-sends the email',async()=>{
  await asService(()=>query("update private.email_outbox set sent_at=now(),attempts=1 where booking_id=$1 and kind='booking_rescheduled'",[allowanceBooking]));
  const nextWeek=at(monday,hours(7*24+2));
  await rpc('reschedule_booking',[allowanceBooking,nextWeek,120,'Moved a week']);
  assert.equal((await rpc('member_allowances',[alice,monday])).production.remaining,240);
  assert.equal((await rpc('member_allowances',[alice,nextWeek])).production.remaining,120);
  const mail=(await asService(()=>query("select * from private.email_outbox where booking_id=$1 and kind='booking_rescheduled'",[allowanceBooking])))[0];
  assert.equal(mail.sent_at,null);assert.equal(mail.attempts,0);assert.equal(new Date(mail.payload.starts_at).toISOString(),nextWeek);
 });

 await t.test('prices follow the new length and never drop below recorded payments',async()=>{
  const start=(await booking(paidBooking)).starts_at.toISOString();
  await rpc('reschedule_booking',[paidBooking,start,180,'Longer session']);
  let row=await booking(paidBooking);assert.equal(Number(row.price),6000);assert.equal(Number(row.addon_price),3000);
  await rpc('record_payment',[paidBooking,5000,'TEST-PAID']);
  await rejects(()=>rpc('reschedule_booking',[paidBooking,start,120,'Shorter']),/exceed the new price/);
  await rpc('reschedule_booking',[paidBooking,at(start,hours(1)),180,'Same length, later']);
  row=await booking(paidBooking);assert.equal(Number(row.price),6000);assert.equal(row.starts_at.toISOString(),at(start,hours(1)));
 });

 await t.test('only upcoming active bookings move; NURA stays within its rules',async()=>{
  await rpc('set_booking_status',[paidBooking,'cancelled','Member cancelled']);
  await rejects(()=>rpc('reschedule_booking',[paidBooking,at(monday,hours(26)),60,'Revive']),/Only upcoming/);
  await rpc('set_nura_member',[alice,true]);
  const friday=at(monday,hours(4*24+2));
  await as(alice);const nura=await rpc('request_nura_booking',[friday,60,'',randomUUID()]);
  await as(admin);
  await rejects(()=>rpc('reschedule_booking',[nura,at(friday,hours(24)),60,'To Saturday']),/NURA/);
  await rejects(()=>rpc('reschedule_booking',[nura,at(friday,-hours(1)),60,'Before 11']),/NURA/);
  await rejects(()=>rpc('reschedule_booking',[nura,friday,300,'Too long']),/NURA/);
  await rpc('reschedule_booking',[nura,at(friday,hours(7)),60,'Evening slot']);
  assert.equal(new Date((await booking(nura)).ends_at).getUTCHours(),16,'ends 19:00 EAT');
  await rpc('reschedule_booking',[nura,at(friday,hours(5)),120,'Longer']);
  assert.equal(Number((await booking(nura)).price),2000,'NURA stays 1,000 KES/hr when rescheduled');
  const slots=await query('select * from reschedule_slots($1,$2,60)',[nura,friday.slice(0,10)]);
  assert.ok(slots.length&&slots.every(s=>s.starts_at.getUTCHours()>=8));
 });
});
