import { createClient } from 'npm:@supabase/supabase-js@2.115.0';

// Cron-only endpoint. The shared secret is verified here; no client may invoke it.
// Service-account calendar access avoids storing Google credentials in the website.
const enc = new TextEncoder();
const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
async function sameSecret(a: string, b: string) {
  const [x,y] = await Promise.all([a,b].map(s=>crypto.subtle.digest('SHA-256',enc.encode(s))));
  let difference=0;const xx=new Uint8Array(x),yy=new Uint8Array(y);for(let i=0;i<xx.length;i++)difference|=xx[i]^yy[i];return difference===0;
}
async function googleToken() {
  const email=Deno.env.get('GOOGLE_SERVICE_ACCOUNT_EMAIL');
  const pem=Deno.env.get('GOOGLE_PRIVATE_KEY')?.replace(/\\n/g,'\n');
  if(!email||!pem)throw Error('Google credentials are not configured');
  const raw=Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g,'').replace(/\s/g,'')),c=>c.charCodeAt(0));
  const key=await crypto.subtle.importKey('pkcs8',raw,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const now=Math.floor(Date.now()/1000);const header=b64url(enc.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
  const claims=b64url(enc.encode(JSON.stringify({iss:email,scope:'https://www.googleapis.com/auth/calendar.events',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
  const input=`${header}.${claims}`,signature=b64url(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(input))));
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${input}.${signature}`}),signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw Error(`Google authentication failed (${response.status})`);return (await response.json()).access_token;
}
Deno.serve(async request=>{
  if(request.method!=='POST')return new Response('Method not allowed',{status:405});
  const secret=Deno.env.get('CALENDAR_SYNC_SECRET');
  if(!secret||!await sameSecret(request.headers.get('x-sync-secret')||'',secret))return new Response('Unauthorized',{status:401});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const token=crypto.randomUUID();let lease=false;let errors=0;
  async function checked(query: PromiseLike<{data: any,error: any}>) {const {data,error}=await query;if(error)throw Error(error.message);return data;}
  try {
    lease=await checked(db.rpc('claim_calendar_sync',{p_token:token}));if(!lease)return Response.json({status:'already_running'});
    const deadline=Date.now()+110000;
    const access=await googleToken();
    async function google(path:string,options:RequestInit={}) {if(Date.now()>deadline-2000)throw Error('Sync time budget reached; retrying next run');return fetch(`https://www.googleapis.com/calendar/v3/${path}`,{...options,headers:{Authorization:`Bearer ${access}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(Math.max(1,Math.min(15000,deadline-Date.now())))});}
    const jobs=await checked(db.rpc('calendar_jobs'));
    const failedCalendars=new Set<string>();
    for(const job of jobs){
      if(Date.now()>deadline-10000)break;
      try {
        const id=`santuri${job.booking_id.replaceAll('-','')}`;const path=`calendars/${encodeURIComponent(job.calendar_id)}/events`;
        if(job.status==='cancelled'){
          const response=await google(`${path}/${id}?sendUpdates=none`,{method:'DELETE'});
          if(!response.ok&&![404,410].includes(response.status))throw Error(`Calendar delete failed (${response.status})`);
        }else{
          // Pending requests reserve the resource in both calendars, without inviting people.
          const event={id,summary:`${job.status==='requested'?'[Requested] ':''}${job.requester_name} · ${job.space_name}`,start:{dateTime:job.starts_at,timeZone:'Africa/Nairobi'},end:{dateTime:job.ends_at,timeZone:'Africa/Nairobi'},status:'confirmed',transparency:'opaque',extendedProperties:{private:{santuriBookingId:job.booking_id}},description:'Manage this booking in the Santuri staff dashboard.'};
          let response=await google(`${path}/${id}?sendUpdates=none`,{method:'PUT',body:JSON.stringify(event)});
          if([404,410].includes(response.status))response=await google(`${path}?sendUpdates=none`,{method:'POST',body:JSON.stringify(event)});
          if(response.status===409)response=await google(`${path}/${id}?sendUpdates=none`,{method:'PUT',body:JSON.stringify(event)});
          if(!response.ok)throw Error(`Calendar event sync failed (${response.status})`);
        }
        await checked(db.rpc('calendar_job_done',{p_id:job.booking_id,p_revision:job.revision,p_error:null}));
      }catch(error){errors++;failedCalendars.add(job.calendar_id);await checked(db.rpc('calendar_job_done',{p_id:job.booking_id,p_revision:job.revision,p_error:(error as Error).message}));}
    }
    const connections=await checked(db.from('calendar_connections').select('*'));
    for(const connection of connections){
      if(Date.now()>deadline-10000)break;
      try {
        if(failedCalendars.has(connection.calendar_id))throw Error('A booking event could not sync. The next run will retry.');
        const params=new URLSearchParams({timeMin:new Date(Date.now()-86400000).toISOString(),timeMax:new Date(Date.now()+92*86400000).toISOString(),singleEvents:'true',maxResults:'2500',timeZone:'Africa/Nairobi'});
        const blocks=[];let pageToken='';let pages=0;
        do {
          if(++pages>20)throw Error('Calendar is too large to sync safely');
          if(pageToken)params.set('pageToken',pageToken);
          const response=await google(`calendars/${encodeURIComponent(connection.calendar_id)}/events?${params}`);
          if(!response.ok)throw Error(`Calendar availability check failed (${response.status})`);
          const data=await response.json();
          for(const event of data.items||[]){
            const own=event.extendedProperties?.private?.santuriBookingId;
            if(own&&event.id===`santuri${own.replaceAll('-','')}`)continue;
            if(event.status==='cancelled'||event.transparency==='transparent')continue;
            const start=event.start?.dateTime||(event.start?.date?`${event.start.date}T00:00:00+03:00`:null);
            const end=event.end?.dateTime||(event.end?.date?`${event.end.date}T00:00:00+03:00`:null);
            if(start&&end)blocks.push({id:event.id,start,end});
          }
          pageToken=data.nextPageToken||'';
        }while(pageToken);
        await checked(db.rpc('replace_google_blocks',{p_space:connection.space_id,p_blocks:blocks,p_revision:connection.revision}));
      }catch(error){errors++;await checked(db.from('calendar_connections').update({sync_error:(error as Error).message}).eq('space_id',connection.space_id));}
    }
    return Response.json({status:errors?'retry_needed':'ok',errors});
  }catch(error){console.error('Calendar sync failed:',(error as Error).message);return Response.json({error:'Calendar sync failed. Check function logs and configuration.'},{status:500});}
  finally{if(lease)await db.rpc('release_calendar_sync',{p_token:token});}
});
