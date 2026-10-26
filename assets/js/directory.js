import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e} from './booking-utils.js';
import {COUNTIES,DISCIPLINES,AREAS,countySlug,artistCard} from './directory-data.js';
import {viewBox,counties} from './kenya-counties.js';
import {SVG,spotIn,twinkle,dot} from './map-dots.js';

const map=document.querySelector('#directory-map'),list=document.querySelector('#directory-list'),summary=document.querySelector('#directory-count');
const roleFilter=document.querySelector('#directory-roles'),countySelect=document.querySelector('#directory-county'),areaSelect=document.querySelector('#directory-area'),more=document.querySelector('#directory-more');
const PAGE=24;
const reduceMotion=matchMedia('(prefers-reduced-motion: reduce)');
const fullView=viewBox.split(' ').map(Number);
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
  return {full_name:`Sample artist ${String(i+1).padStart(2,'0')}`,county:c,area:a,disciplines:[...picks],instagram:`sample_artist_${i+1}`,website:rand()>.6?'https://example.com':'',email:rand()>.5?'artist@example.com':''};});
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
 drawLights(listed,tally,max);
 const group=map.querySelector('.map-areas');if(!group?.dataset.county)return;
 const local=new Map();for(const a of listed)if(a.county===group.dataset.county&&a.area)local.set(a.area,(local.get(a.area)||0)+1);
 const localMax=Math.max(1,...local.values());
 group.querySelectorAll('path[data-area]').forEach(p=>{const name=p.dataset.area,n=local.get(name)||0;
  p.dataset.level=level(n,localMax);p.classList.toggle('is-selected',name===area);
  p.querySelector('title').textContent=`${name}: ${people(n)}${role?' · '+role:''}`;});
}

// One twinkling dot per listed person, somewhere inside their area (once its outlines are loaded) or county.
// Busier places twinkle faster. Above MAX_LIGHTS each light stands for several people, so cheap phones keep up.
const MAX_LIGHTS=400,MAX_RIPPLES=80,RIPPLE_PX=44;
function spot(a){
 const shape=(a.area&&map.querySelector(`.map-areas[data-county="${CSS.escape(a.county)}"] path[data-area="${CSS.escape(a.area)}"]`))||map.querySelector(`path[data-county="${CSS.escape(a.county)}"]`);
 return shape?spotIn(shape,a):null;
}
function drawLights(listed,tally,max){
 const svg=map.querySelector('svg');let lights=svg.querySelector('.map-lights');
 if(!lights){lights=document.createElementNS(SVG,'g');lights.classList.add('map-lights');lights.setAttribute('aria-hidden','true');}
 svg.insertBefore(lights,svg.querySelector('.map-labels'));
 const per=Math.ceil(listed.length/MAX_LIGHTS)||1;
 lights.innerHTML=listed.filter((_,i)=>i%per===0).map(a=>{const s=spot(a);if(!s)return '';
  return dot(s,twinkle(tally.get(a.county)||0,max));}).join('');
 lights.classList.toggle('is-zoomed',!!county);
 drawRipples(listed.filter(a=>a.county===county&&(!area||a.area===area)));
 document.querySelector('#map-light-key').textContent=per>1?`Each dot is about ${per} people.`:'Each dot is one person.';
}
// Zoomed into a county, each dot there sends out radar rings. Their radius is set in map units for the zoom being
// shown, so the rings come out about RIPPLE_PX wide on screen; the ring line itself doesn't scale.
function drawRipples(here){
 const svg=map.querySelector('svg');let ripples=svg.querySelector('.map-ripples');
 if(!ripples){ripples=document.createElementNS(SVG,'g');ripples.classList.add('map-ripples');ripples.setAttribute('aria-hidden','true');}
 svg.insertBefore(ripples,svg.querySelector('.map-lights'));
 if(!county||reduceMotion.matches){ripples.innerHTML='';return;}
 const r=(RIPPLE_PX*zoomTarget()[2]/(svg.getBoundingClientRect().width||500)).toFixed(2);
 ripples.innerHTML=here.slice(0,MAX_RIPPLES).map(a=>{const s=spot(a);if(!s)return '';
  // Two rings half a beat apart, each dot starting at its own point in the beat.
  return [0,1.3].map(offset=>`<circle cx="${s[0].toFixed(1)}" cy="${s[1].toFixed(1)}" r="${r}" style="animation-delay:-${((s[2]*2.6+offset)%2.6).toFixed(2)}s"/>`).join('');}).join('');
}
function drawRoles(){
 const here=artists.filter(a=>byCounty(a)&&byArea(a));
 roleFilter.innerHTML=[['','Everyone',here.length],...DISCIPLINES.map(d=>[d,d,here.filter(a=>a.disciplines.includes(d)).length])]
  .map(([v,l,n])=>`<button type="button" data-role="${e(v)}" aria-pressed="${v===role}">${e(l)} <span>${n}</span></button>`).join('');
}
function drawList(){
 const found=artists.filter(a=>byRole(a)&&byCounty(a)&&byArea(a));
 summary.textContent=`${people(found.length)} · ${role||'Everyone'} · ${area?area+', '+county:county||'All of Kenya'}`;
 list.innerHTML=found.length?found.slice(0,shown).map(artistCard).join('')
  :`<p class="directory-empty">No one listed ${area?'in '+e(area):county?'in '+e(county):'yet'}${role?' for '+e(role):''}. <a href="listing.html">List yourself</a>, or tell people you know.</p>`;
 more.hidden=found.length<=shown;
}
function draw(){drawMap();drawRoles();drawList();}

// Constituencies of the open county are drawn over it, with their names, once its outline file has loaded.
async function showAreas(name){
 const svg=map.querySelector('svg');map.querySelector('.map-areas')?.remove();map.querySelector('.map-labels')?.remove();
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
 svg.append(labels);drawMap();
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
 map.innerHTML=`<svg viewBox="${viewBox}" role="img" aria-label="Map of Kenya's counties, with one dot for each listed person. Use the county and area lists to filter.">${counties.map(([name,d])=>`<path d="${d}" data-county="${e(name)}"><title></title></path>`).join('')}</svg><button class="map-reset" type="button" hidden>All of Kenya ×</button>`;
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
 const db=await getClient(),photos=db.storage.from('directory-photos');
 artists=(await result(db.rpc('artist_directory'))).map(a=>({...a,area:a.area||'',photo_url:a.photo?photos.getPublicUrl(a.photo).data.publicUrl:''}));
}

init();
load().then(draw).catch(()=>{list.innerHTML='<p class="directory-empty">The artist directory is opening soon. <a href="account.html">Create an account</a> and tick “List me in Santuri’s public artist directory” to be on it from day one.</p>';summary.textContent='';});
