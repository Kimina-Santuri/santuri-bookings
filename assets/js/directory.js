import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e} from './booking-utils.js';
import {COUNTIES,DISCIPLINES} from './directory-data.js';
import {viewBox,counties} from './kenya-counties.js';

const map=document.querySelector('#directory-map'),list=document.querySelector('#directory-list'),summary=document.querySelector('#directory-count');
const roleFilter=document.querySelector('#directory-roles'),countySelect=document.querySelector('#directory-county'),more=document.querySelector('#directory-more');
const PAGE=24;
const reduceMotion=matchMedia('(prefers-reduced-motion: reduce)');
const fullView=viewBox.split(' ').map(Number);
let view=fullView.slice(),zooming=0;
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

// Zoom the map to the chosen county, with a margin so its neighbours stay in view.
function zoomTarget(){
 const path=county&&map.querySelector(`path[data-county="${CSS.escape(county)}"]`);if(!path)return fullView;
 const b=path.getBBox(),size=Math.max(b.width,b.height*fullView[2]/fullView[3],fullView[2]*.04)*1.9;
 const w=size,h=size*fullView[3]/fullView[2];
 return [b.x+b.width/2-w/2,b.y+b.height/2-h/2,w,h];
}
function zoom(){
 const svg=map.querySelector('svg'),from=view.slice(),to=zoomTarget(),run=++zooming,start=performance.now(),ms=reduceMotion.matches?0:450;
 map.querySelector('.map-reset').hidden=!county;
 const step=now=>{if(run!==zooming)return;const t=ms?Math.min(1,(now-start)/ms):1,k=1-Math.pow(1-t,3);
  view=from.map((v,i)=>v+(to[i]-v)*k);svg.setAttribute('viewBox',view.join(' '));if(t<1)requestAnimationFrame(step);};
 requestAnimationFrame(step);
}
function setCounty(name){county=name;countySelect.value=name;shown=PAGE;draw();zoom();}

function init(){
 map.innerHTML=`<svg viewBox="${viewBox}" role="img" aria-label="Map of Kenya's counties, shaded by how many listed artists are in each. Use the county list to filter.">${counties.map(([name,d])=>`<path d="${d}" data-county="${e(name)}"><title></title></path>`).join('')}</svg><button class="map-reset" type="button" hidden>All of Kenya ×</button>`;
 map.querySelector('.map-reset').onclick=()=>setCounty('');
 map.addEventListener('click',event=>{const p=event.target.closest('path[data-county]');if(p)setCounty(p.dataset.county===county?'':p.dataset.county);});
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
