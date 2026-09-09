import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-email-secret, content-type"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const escape=(value:unknown)=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]??c));
const dateLabel=(value:string)=>new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Nairobi',dateStyle:'full'}).format(new Date(value));
const timeLabel=(value:string)=>new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Nairobi',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(value));

const secret=Deno.env.get('EMAIL_NOTIFICATIONS_SECRET');
const supabaseUrl=Deno.env.get('SUPABASE_URL');
const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const smtpHost=Deno.env.get('SMTP_HOST')||'smtppro.zoho.com';
const smtpPort=Number(Deno.env.get('SMTP_PORT')||465);
const smtpUser=Deno.env.get('SMTP_USER');
const smtpPass=Deno.env.get('SMTP_PASS');
const sender=Deno.env.get('SMTP_FROM')||smtpUser;
const senderName=Deno.env.get('SMTP_SENDER_NAME')||'Santuri East Africa';

function message(job:{kind:string,payload:Record<string,unknown>}){
 const p=job.payload, name=escape(p.name||'there'), space=escape(p.space), date=escape(dateLabel(String(p.starts_at))), start=escape(timeLabel(String(p.starts_at))), end=escape(timeLabel(String(p.ends_at))), note=String(p.note||'').trim();
 const subject=String(p.subject||'Santuri booking update');
 const intro=job.kind==='request_received'?'We received your booking request. The Santuri team will review it and send a confirmation.':job.kind==='booking_confirmed'?'Your Santuri booking is confirmed.':job.kind==='booking_cancelled'?'Your Santuri booking has been cancelled.':job.kind==='booking_completed'?'Your Santuri session has been marked completed.':job.kind==='booking_reminder'?'This is a reminder that your Santuri session is tomorrow.':'Your Santuri booking was marked as a no-show.';
 const text=`Hello ${p.name||'there'},\n\n${intro}\n\nSpace: ${p.space}\nDate: ${date}\nTime: ${start}–${end} EAT${note?`\nNote: ${note}`:''}\n\nManage your bookings: https://bookings.santuri.org/bookings.html\n\nSanturi East Africa\nbookings@santuri.org`;
 const html=`<div style="font-family:Arial,sans-serif;line-height:1.5;color:#111;max-width:600px"><p>Hello ${name},</p><p>${escape(intro)}</p><p><strong>Space:</strong> ${space}<br><strong>Date:</strong> ${date}<br><strong>Time:</strong> ${start}–${end} EAT${note?`<br><strong>Note:</strong> ${escape(note)}`:''}</p><p><a href="https://bookings.santuri.org/bookings.html">Manage your bookings</a></p><p>Santuri East Africa<br><a href="mailto:bookings@santuri.org">bookings@santuri.org</a></p></div>`;
 return {from:`${senderName} <${sender}>`,to:String(p.recipient||''),subject,text,html};
}

Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST'||!secret||req.headers.get('x-email-secret')!==secret)return json({error:'Unauthorized'},401);
 if(!supabaseUrl||!serviceKey||!smtpUser||!smtpPass||!sender)return json({error:'Email service is not configured'},500);
 const db=createClient(supabaseUrl,serviceKey),token=crypto.randomUUID();
 const reminderResult=await db.rpc('queue_booking_reminders');
 if(reminderResult.error)return json({error:reminderResult.error.message},500);
 const {data:jobs,error}=await db.rpc('claim_email_jobs',{p_token:token,p_limit:25});
 if(error)return json({error:error.message},500);
 const transporter=nodemailer.createTransport({host:smtpHost,port:smtpPort,secure:smtpPort===465,auth:{user:smtpUser,pass:smtpPass}});
 let sent=0,failed=0;
 for(const job of jobs||[]){try{await transporter.sendMail(message({...job,payload:{...job.payload,recipient:job.recipient}}));await db.rpc('complete_email_job',{p_id:job.id,p_token:token});sent++;}catch(err){failed++;await db.rpc('complete_email_job',{p_id:job.id,p_token:token,p_error:String(err)});}}
 return json({claimed:(jobs||[]).length,sent,failed});
});
