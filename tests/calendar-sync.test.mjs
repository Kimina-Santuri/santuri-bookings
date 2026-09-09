import {test} from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

test('calendar sync authenticates cron, retries deterministically and imports private busy times',async t=>{
 const env=new Map([['CALENDAR_SYNC_SECRET','test-secret-only'],['SUPABASE_URL','https://test.supabase.co'],['SUPABASE_SERVICE_ROLE_KEY','not-a-real-key'],['GOOGLE_SERVICE_ACCOUNT_EMAIL','calendar@example.test']]);
 const pair=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const der=Buffer.from(await crypto.subtle.exportKey('pkcs8',pair.privateKey)).toString('base64');env.set('GOOGLE_PRIVATE_KEY',`-----BEGIN PRIVATE KEY-----\n${der}\n-----END PRIVATE KEY-----`);
 let handler;globalThis.Deno={env:{get:k=>env.get(k)},serve:fn=>{handler=fn;}};
 const output=await build({entryPoints:['supabase/functions/calendar-sync/index.ts'],bundle:true,write:false,format:'esm',platform:'neutral',plugins:[{name:'test-db',setup(build){build.onResolve({filter:/^npm:/},()=>({path:'db',namespace:'test'}));build.onLoad({filter:/.*/,namespace:'test'},()=>({contents:'export const createClient = () => globalThis.__calendarTestDb;',loader:'js'}));}}]});
 await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
 const originalFetch=globalThis.fetch;let requests=[];let calls=[];let updates=[];let claimed=true;
 const id='11111111-1111-4111-8111-111111111111';
 const jobs=[{booking_id:id,revision:2,calendar_id:'room@example.test',status:'requested',space_name:'Recording Studio',starts_at:'2026-09-10T06:00:00Z',ends_at:'2026-09-10T08:00:00Z'},{booking_id:'22222222-2222-4222-8222-222222222222',revision:3,calendar_id:'room@example.test',status:'cancelled'}];
 globalThis.__calendarTestDb={rpc:async(name,args)=>{calls.push({name,args});return {error:null,data:name==='claim_calendar_sync'?claimed:name==='calendar_jobs'?jobs:null};},from:()=>({select:async()=>({error:null,data:[{space_id:'space-1',calendar_id:'room@example.test',revision:1}]}),update:data=>({eq:async()=>{updates.push(data);return {error:null,data:null};}})})};
 let failEvents=false;
 globalThis.fetch=async(url,opts={})=>{
  requests.push({url:String(url),...opts});
  if(String(url).includes('oauth2.googleapis.com')){
   const assertion=opts.body.get('assertion');const parts=assertion.split('.');assert.equal(JSON.parse(Buffer.from(parts[1],'base64url')).iss,'calendar@example.test');assert.equal(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',pair.publicKey,Buffer.from(parts[2],'base64url'),new TextEncoder().encode(parts.slice(0,2).join('.'))),true);
   return Response.json({access_token:'google-test-token'});
  }
  if(opts.method==='DELETE')return new Response(null,{status:410});
  if(opts.method==='PUT')return new Response(null,{status:failEvents?503:404});
  if(opts.method==='POST')return Response.json({id:'created'});
  const u=new URL(url);if(u.searchParams.has('pageToken'))return Response.json({items:[{id:'all-day',start:{date:'2026-09-12'},end:{date:'2026-09-13'}}]});
  return Response.json({nextPageToken:'next',items:[{id:'santuri'+id.replaceAll('-',''),extendedProperties:{private:{santuriBookingId:id}},start:{dateTime:'2026-09-10T06:00:00Z'},end:{dateTime:'2026-09-10T08:00:00Z'}},{id:'busy',start:{dateTime:'2026-09-11T09:00:00+03:00'},end:{dateTime:'2026-09-11T10:00:00+03:00'}},{id:'free',transparency:'transparent',start:{date:'2026-09-12'},end:{date:'2026-09-13'}},{id:'cancelled',status:'cancelled',start:{date:'2026-09-12'},end:{date:'2026-09-13'}}]});
 };
 const request=()=>new Request('https://test.test/sync',{method:'POST',headers:{'x-sync-secret':'test-secret-only'}});
 try {
  await t.test('rejects unsigned requests before accessing services',async()=>{assert.equal((await handler(new Request('https://test.test/sync',{method:'POST'}))).status,401);assert.equal(requests.length,0);assert.equal(calls.length,0);assert.equal((await handler(new Request('https://test.test/sync'))).status,405);});
  await t.test('a run already holding the lease prevents duplicate processing',async()=>{claimed=false;assert.equal((await (await handler(request())).json()).status,'already_running');assert.equal(requests.length,0);claimed=true;calls=[];});
  await t.test('creates requested events, treats already-deleted cancellations as success and paginates',async()=>{
   const response=await handler(request());assert.equal(response.status,200);assert.equal((await response.json()).status,'ok');
   const event=JSON.parse(requests.find(r=>r.method==='POST'&&r.url.includes('/events')).body);assert.equal(event.id,'santuri'+id.replaceAll('-',''));assert.equal(event.summary,'[Requested] Recording Studio · Santuri');assert.equal(event.attendees,undefined);
   const imported=calls.find(c=>c.name==='replace_google_blocks').args.p_blocks;assert.deepEqual(imported.map(b=>b.id),['busy','all-day']);assert.equal(imported[1].start,'2026-09-12T00:00:00+03:00');assert.equal(calls.filter(c=>c.name==='calendar_job_done'&&c.args.p_error===null).length,2);assert.equal(calls.at(-1).name,'release_calendar_sync');
  });
  await t.test('failed Google writes remain retryable and close the affected calendar',async()=>{requests=[];calls=[];failEvents=true;const response=await handler(request());assert.equal((await response.json()).status,'retry_needed');assert.ok(calls.find(c=>c.name==='calendar_job_done'&&c.args.p_id===id&&c.args.p_error));assert.equal(calls.some(c=>c.name==='replace_google_blocks'),false);assert.ok(updates[0].sync_error);assert.equal(calls.at(-1).name,'release_calendar_sync');});
 }finally{globalThis.fetch=originalFetch;delete globalThis.Deno;delete globalThis.__calendarTestDb;}
});
