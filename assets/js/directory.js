import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e} from './booking-utils.js';
import {COUNTIES,DISCIPLINES} from './directory-data.js';
import {viewBox,counties} from './kenya-counties.js';

const map=document.querySelector('#directory-map'),list=document.querySelector('#directory-list'),summary=document.querySelector('#directory-count');
const roleFilter=document.querySelector('#directory-roles'),countySelect=document.querySelector('#directory-county'),more=document.querySelector('#directory-more');
const PAGE=24;
let artists=[],role='',county='',shown=PAGE;

// Sample listings for a local preview (localhost with ?demo) so the map and filters can be checked before anyone signs up.
const demo=['localhost','127.0.0.1'].includes(location.hostname)&&new URLSearchParams(location.search).has('demo');

function sampleArtists(){
 let seed=7;const rand=()=>(seed=(seed*16807)%2147483647)/2147483647;
 const weighted=[...Array(14).fill('Nairobi'),...Array(4).fill('Mombasa'),...Array(3).fill('Kisumu'),...Array(3).fill('Nakuru'),'Kiambu','Kiambu','Machakos','Uasin Gishu','Kilifi','Kajiado','Nyeri','Kakamega','Meru','Lamu','Turkana','Garissa'];
 return Array.from({length:70},(_,i)=>{const picks=new Set([DISCIPLINES[Math.floor(rand()*DISCIPLINES.length)]]);if(rand()>.6)picks.add(DISCIPLINES[Math.floor(rand()*DISCIPLINES.length)]);
  return {full_name:`Sample artist ${String(i+1).padStart(2,'0')}`,county:weighted[Math.floor(rand()*weighted.length)],disciplines:[...picks],phone:'0700 000 000'};});
}

function telLink(phone){return 'tel:'+phone.replace(/[^\d+]/g,'');}
function whatsappLink(phone){
 let d=phone.replace(/\D/g,'');
 if(/^0[17]\d{8}$/.test(d))d='254'+d.slice(1);else if(/^[17]\d{8}$/.test(d))d='254'+d;
 if(/^254[17]\d{8}$/.test(d)||(phone.trim().startsWith('+')&&d.length>=8&&d.length<=15))return 'https://wa.me/'+d;
 return '';
}

const byRole=a=>!role||a.disciplines.includes(role);
const byCounty=a=>!county||a.county===county;

function drawMap(){
 const tally=new Map();for(const a of artists.filter(byRole))tally.set(a.county,(tally.get(a.county)||0)+1);
 const max=Math.max(1,...tally.values());
 map.querySelectorAll('path').forEach(p=>{const name=p.dataset.county,n=tally.get(name)||0;
  // Square-root scale: Nairobi would otherwise leave every other county looking empty.
  p.dataset.level=n?Math.max(1,Math.ceil(5*Math.sqrt(n/max))):0;p.classList.toggle('is-selected',name===county);
  p.querySelector('title').textContent=`${name}: ${n} ${n===1?'artist':'artists'}${role?' · '+role:''}`;});
}
function drawRoles(){
 const inCounty=artists.filter(byCounty);
 roleFilter.innerHTML=[['','Everyone',inCounty.length],...DISCIPLINES.map(d=>[d,d,inCounty.filter(a=>a.disciplines.includes(d)).length])]
  .map(([v,l,n])=>`<button type="button" data-role="${e(v)}" aria-pressed="${v===role}">${e(l)} <span>${n}</span></button>`).join('');
}
function drawList(){
 const found=artists.filter(a=>byRole(a)&&byCounty(a));
 summary.textContent=`${found.length} ${found.length===1?'person':'people'} · ${role||'Everyone'} · ${county||'All of Kenya'}`;
 list.innerHTML=found.length?found.slice(0,shown).map(a=>{const wa=whatsappLink(a.phone);
  return `<article class="artist-card"><h3>${e(a.full_name)}</h3><p class="artist-county">${e(a.county)}</p><ul class="artist-tags">${a.disciplines.map(d=>`<li>${e(d)}</li>`).join('')}</ul><div class="artist-contact"><a class="button" href="${e(telLink(a.phone))}">Call ${e(a.phone)}</a>${wa?`<a class="secondary-button" href="${e(wa)}" target="_blank" rel="noopener noreferrer">WhatsApp ↗</a>`:''}</div></article>`;}).join('')
  :`<p class="directory-empty">No one listed ${county?'in '+e(county):'yet'}${role?' for '+e(role):''}. <a href="account.html">Create an account</a> to list yourself, or tell people you know.</p>`;
 more.hidden=found.length<=shown;
}
function draw(){drawMap();drawRoles();drawList();}

function setCounty(name){county=name;countySelect.value=name;shown=PAGE;draw();}

function init(){
 map.innerHTML=`<svg viewBox="${viewBox}" role="img" aria-label="Map of Kenya's counties, shaded by how many listed artists are in each. Use the county list to filter.">${counties.map(([name,d])=>`<path d="${d}" data-county="${e(name)}"><title></title></path>`).join('')}</svg>`;
 map.addEventListener('click',event=>{const p=event.target.closest('path');if(p)setCounty(p.dataset.county===county?'':p.dataset.county);});
 countySelect.innerHTML='<option value="">All counties</option>'+COUNTIES.map(c=>`<option>${e(c)}</option>`).join('');
 countySelect.onchange=()=>setCounty(countySelect.value);
 roleFilter.addEventListener('click',event=>{const b=event.target.closest('[data-role]');if(!b)return;role=b.dataset.role;shown=PAGE;draw();});
 more.onclick=()=>{shown+=PAGE;drawList();};
 drawMap();
}

async function load(){
 if(demo){artists=sampleArtists();document.querySelector('#directory-demo').hidden=false;return;}
 if(!configured())throw Error('not configured');
 const db=await getClient();artists=await result(db.rpc('artist_directory'));
}

init();
load().then(draw).catch(()=>{list.innerHTML='<p class="directory-empty">The artist directory is opening soon. <a href="account.html">Create an account</a> and tick “List me in Santuri’s public artist directory” to be on it from day one.</p>';summary.textContent='';});
