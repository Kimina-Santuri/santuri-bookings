import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e} from './booking-utils.js';
import {COUNTIES,DISCIPLINES,AREAS,countySlug} from './directory-data.js';
import {viewBox,counties} from './kenya-counties.js';

const map=document.querySelector('#directory-map'),list=document.querySelector('#directory-list'),summary=document.querySelector('#directory-count');
const roleFilter=document.querySelector('#directory-roles'),countySelect=document.querySelector('#directory-county'),areaSelect=document.querySelector('#directory-area'),more=document.querySelector('#directory-more');
const PAGE=24;
const reduceMotion=matchMedia('(prefers-reduced-motion: reduce)');
const fullView=viewBox.split(' ').map(Number);
const SVG='http://www.w3.org/2000/svg';
let view=fullView.slice(),zooming=0;
let artists=[],role='',county='',area='',shown=PAGE;
const areaShapes=new Map(); // county -> constituency outlines, fetched the first time that county is opened

// Sample listings for a local preview (localhost with ?demo) so the map and filters can be checked before anyone signs up.
const demo=['localhost','127.0.0.1'].includes(location.hostname)&&new URLSearchParams(location.search).has('demo');

function sampleArtists(){
 let seed=7;const rand=()=>(seed=(seed*16807)%2147483647)/2147483647;
 const weighted=[...Array(14).fill('Nairobi'),...Array(4).fill('Mombasa'),...Array(3).fill('Kisumu'),...Array(3).fill('Nakuru'),'Kiambu','Kiambu','Machakos','Uasin Gishu','Kilifi','Kajiado','Nyeri','Kakamega','Meru','Lamu','Turkana','Garissa'];
 return Array.from({length:70},(_,i)=>{const picks=new Set([DISCIPLINES[Math.floor(rand()*DISCIPLINES.length)]]);if(rand()>.6)picks.add(DISCIPLINES[Math.floor(rand()*DISCIPLINES.length)]);
  const c=weighted[Math.floor(rand()*weighted.length)],areas=AREAS[c]||[],a=rand()>.25?areas[Math.floor(rand()*Math.min(areas.length,c==='Nairobi'?8:areas.length))]||'':'';
  return {full_name:`Sample artist ${String(i+1).padStart(2,'0')}`,county:c,area:a,disciplines:[...picks],phone:'0700 000 000'};});
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
const byArea=a=>!area||a.area===area;
// Square-root scale: Nairobi would otherwise leave every other county looking empty.
const level=(n,max)=>n?Math.max(1,Math.ceil(5*Math.sqrt(n/max))):0;
const people=n=>`${n} ${n===1?'person':'people'}`;

function drawMap(){
 const listed=artists.filter(byRole),tally=new Map();for(const a of listed)tally.set(a.county,(tally.get(a.county)||0)+1);
 const max=Math.max(1,...tally.values());
 map.querySelectorAll('path[data-county]').forEach(p=>{const name=p.dataset.county,n=tally.get(name)||0;
  p.dataset.level=level(n,max);p.classList.toggle('is-selected',name===county);
  p.querySelector('title').textContent=`${name}: ${people(n)}${role?' · '+role:''}`;});
 const group=map.querySelector('.map-areas');if(!group?.dataset.county)return;
 const local=new Map();for(const a of listed)if(a.county===group.dataset.county&&a.area)local.set(a.area,(local.get(a.area)||0)+1);
 const localMax=Math.max(1,...local.values());
 group.querySelectorAll('path[data-area]').forEach(p=>{const name=p.dataset.area,n=local.get(name)||0;
  p.dataset.level=level(n,localMax);p.classList.toggle('is-selected',name===area);
  p.querySelector('title').textContent=`${name}: ${people(n)}${role?' · '+role:''}`;});
}
function drawRoles(){
 const here=artists.filter(a=>byCounty(a)&&byArea(a));
 roleFilter.innerHTML=[['','Everyone',here.length],...DISCIPLINES.map(d=>[d,d,here.filter(a=>a.disciplines.includes(d)).length])]
  .map(([v,l,n])=>`<button type="button" data-role="${e(v)}" aria-pressed="${v===role}">${e(l)} <span>${n}</span></button>`).join('');
}
function drawList(){
 const found=artists.filter(a=>byRole(a)&&byCounty(a)&&byArea(a));
 summary.textContent=`${people(found.length)} · ${role||'Everyone'} · ${area?area+', '+county:county||'All of Kenya'}`;
 list.innerHTML=found.length?found.slice(0,shown).map(a=>{const wa=whatsappLink(a.phone);
  return `<article class="artist-card"><h3>${e(a.full_name)}</h3><p class="artist-county">${a.area?e(a.area)+' · ':''}${e(a.county)}</p><ul class="artist-tags">${a.disciplines.map(d=>`<li>${e(d)}</li>`).join('')}</ul><div class="artist-contact"><a class="button" href="${e(telLink(a.phone))}">Call ${e(a.phone)}</a>${wa?`<a class="secondary-button" href="${e(wa)}" target="_blank" rel="noopener noreferrer">WhatsApp ↗</a>`:''}</div></article>`;}).join('')
  :`<p class="directory-empty">No one listed ${area?'in '+e(area):county?'in '+e(county):'yet'}${role?' for '+e(role):''}. <a href="account.html">Create an account</a> to list yourself, or tell people you know.</p>`;
 more.hidden=found.length<=shown;
}
function draw(){drawMap();drawRoles();drawList();}

// Constituencies of the open county are drawn over it, with their names, once its outline file has loaded.
async function showAreas(name){
 const svg=map.querySelector('svg');map.querySelector('.map-areas')?.remove();
 svg.querySelectorAll('path[data-county]').forEach(p=>p.classList.toggle('has-areas',false));
 if(!name)return;
 if(!areaShapes.has(name))areaShapes.set(name,fetch(`assets/data/areas/${countySlug(name)}.json`).then(r=>r.ok?r.json():null).catch(()=>null));
 const data=await areaShapes.get(name);
 if(!data||name!==county||map.querySelector('.map-areas'))return;
 const group=document.createElementNS(SVG,'g');group.classList.add('map-areas');group.dataset.county=name;
 group.innerHTML=data.areas.map(([n,d])=>`<path d="${d}" data-area="${e(n)}"><title></title></path>`).join('');
 svg.append(group);svg.querySelector(`path[data-county="${CSS.escape(name)}"]`)?.classList.add('has-areas');
 const labels=document.createElementNS(SVG,'g');labels.classList.add('map-labels');
 // Name only the areas whose label fits inside them without touching another, biggest first; the rest stay tappable and in the Area list.
 const size=zoomTarget(name)[2]/42,placed=[];
 [...group.querySelectorAll('path')].map(p=>[p,p.getBBox()]).sort((x,y)=>y[1].width*y[1].height-x[1].width*x[1].height).forEach(([p,b])=>{
  const w=p.dataset.area.length*size*.62,h=size*1.2,box=[b.x+b.width/2-w/2,b.y+b.height/2-h/2,w,h];
  if(w>b.width*1.05||h>b.height*.8||placed.some(o=>box[0]<o[0]+o[2]&&o[0]<box[0]+w&&box[1]<o[1]+o[3]&&o[1]<box[1]+h))return;
  placed.push(box);const t=document.createElementNS(SVG,'text');
  t.setAttribute('x',b.x+b.width/2);t.setAttribute('y',b.y+b.height/2);t.setAttribute('font-size',size);t.textContent=p.dataset.area;labels.append(t);});
 group.append(labels);drawMap();
}

// Zoom to the chosen county so its areas fill the map, or to the chosen area with a margin so its neighbours stay in view.
function zoomTarget(countyName=county){
 const path=area?map.querySelector(`path[data-area="${CSS.escape(area)}"]`):countyName&&map.querySelector(`path[data-county="${CSS.escape(countyName)}"]`);
 if(!path)return fullView;
 const b=path.getBBox(),size=Math.max(b.width,b.height*fullView[2]/fullView[3],fullView[2]*(area?.015:.04))*(area?2.4:1.3);
 const w=size,h=size*fullView[3]/fullView[2];
 return [b.x+b.width/2-w/2,b.y+b.height/2-h/2,w,h];
}
function zoom(){
 const svg=map.querySelector('svg'),from=view.slice(),to=zoomTarget(),run=++zooming,start=performance.now(),ms=reduceMotion.matches?0:450;
 const reset=map.querySelector('.map-reset');reset.hidden=!county;reset.textContent=area?`Back to ${county}`:'All of Kenya ×';
 const step=now=>{if(run!==zooming)return;const t=ms?Math.min(1,(now-start)/ms):1,k=1-Math.pow(1-t,3);
  view=from.map((v,i)=>v+(to[i]-v)*k);svg.setAttribute('viewBox',view.join(' '));if(t<1)requestAnimationFrame(step);};
 requestAnimationFrame(step);
}
function fillAreas(){
 const names=AREAS[county]||[];areaSelect.closest('label').hidden=!county;
 areaSelect.innerHTML=`<option value="">All of ${e(county)}</option>`+names.map(n=>`<option>${e(n)}</option>`).join('');areaSelect.value=area;
}
function setCounty(name){const changed=name!==county;county=name;area='';countySelect.value=name;shown=PAGE;fillAreas();draw();zoom();if(changed)showAreas(name);}
function setArea(name){area=name;areaSelect.value=name;shown=PAGE;draw();zoom();}

function init(){
 map.innerHTML=`<svg viewBox="${viewBox}" role="img" aria-label="Map of Kenya's counties, shaded by how many listed artists are in each. Use the county and area lists to filter.">${counties.map(([name,d])=>`<path d="${d}" data-county="${e(name)}"><title></title></path>`).join('')}</svg><button class="map-reset" type="button" hidden>All of Kenya ×</button>`;
 map.querySelector('.map-reset').onclick=()=>area?setArea(''):setCounty('');
 map.addEventListener('click',event=>{
  const a=event.target.closest('path[data-area]');if(a){setArea(a.dataset.area===area?'':a.dataset.area);return;}
  const p=event.target.closest('path[data-county]');if(p)setCounty(p.dataset.county===county?'':p.dataset.county);
 });
 countySelect.innerHTML='<option value="">All counties</option>'+COUNTIES.map(c=>`<option>${e(c)}</option>`).join('');
 countySelect.onchange=()=>setCounty(countySelect.value);
 areaSelect.onchange=()=>setArea(areaSelect.value);
 roleFilter.addEventListener('click',event=>{const b=event.target.closest('[data-role]');if(!b)return;role=b.dataset.role;shown=PAGE;draw();});
 more.onclick=()=>{shown+=PAGE;drawList();};
 fillAreas();drawMap();
}

async function load(){
 if(demo){artists=sampleArtists();document.querySelector('#directory-demo').hidden=false;return;}
 if(!configured())throw Error('not configured');
 const db=await getClient();artists=(await result(db.rpc('artist_directory'))).map(a=>({...a,area:a.area||''}));
}

init();
load().then(draw).catch(()=>{list.innerHTML='<p class="directory-empty">The artist directory is opening soon. <a href="account.html">Create an account</a> and tick “List me in Santuri’s public artist directory” to be on it from day one.</p>';summary.textContent='';});
