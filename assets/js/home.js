// Landing page: the hero map and "Open next" times, plus previews of the gear catalogue and the artist directory.
// Each part keeps its static copy and links if loading fails.
import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e,money,safeImage} from './booking-utils.js';
import {artistCard} from './directory-data.js';
import {SVG,spotIn,twinkle,dot} from './map-dots.js';

const gearGrid=document.querySelector('#home-gear'),people=document.querySelector('#home-directory'),count=document.querySelector('#home-directory-count');
const heroMap=document.querySelector('#hero-map'),openNext=document.querySelector('#open-next');
const reduceMotion=matchMedia('(prefers-reduced-motion: reduce)');
// Santuri at The Mall, Westlands, in kenya-counties.js map units (fitted from Nairobi county's outline).
const SANTURI=[1446,3349],MAX_DOTS=400,RING_PX=30,MARK_PX=13;
const pad=n=>String(n).padStart(2,'0');
function fact(id,value,label){document.querySelector('#'+id).textContent=value;document.querySelector(`#${id}-label`).textContent=label;}

// Up to four items with photos, rentable ones first.
async function gear(db){
 const items=(await result(db.from('gear_items').select('*').eq('active',true).order('sort_order').order('name'))).filter(g=>g.image_url);
 const open=g=>g.available&&g.quantity>0&&g.price>0;
 const pick=[...items.filter(open),...items.filter(g=>!open(g))].slice(0,4);
 if(!pick.length)return;
 gearGrid.innerHTML=pick.map(g=>`<a class="space-card home-gear-card" href="${open(g)?`rent-gear.html?item=${encodeURIComponent(g.id)}`:'gear.html'}"><div class="space-image"><img src="${e(safeImage(g.image_url))}" alt="${e(g.image_alt||g.name)}" width="800" height="600" loading="lazy"></div><div class="space-body"><p class="space-meta">${open(g)?`${money(g.price)} / ${g.price_unit==='hour'?'hour':'day'}`:'Ask the team'}</p><h3>${e(g.name)}</h3></div></a>`).join('');
 gearGrid.hidden=false;
}

// Kenya with one twinkling dot per listed person and a radar ring on Santuri. The outlines load after the page text.
async function drawMap(listed){
 const {viewBox,counties}=await import('./kenya-counties.js');
 heroMap.innerHTML=`<svg viewBox="${viewBox}" role="img" aria-label="Map of Kenya with one dot for each artist in the Santuri directory and a ring marking Santuri in Westlands, Nairobi.">${counties.map(([name,d])=>`<path d="${d}" data-county="${e(name)}"></path>`).join('')}</svg>`;
 const svg=heroMap.querySelector('svg'),tally=new Map();for(const a of listed)tally.set(a.county,(tally.get(a.county)||0)+1);
 const max=Math.max(1,...tally.values()),per=Math.ceil(listed.length/MAX_DOTS)||1;
 const shape=a=>svg.querySelector(`path[data-county="${CSS.escape(a.county)}"]`);
 const dots=listed.filter((_,i)=>i%per===0).map(a=>{const p=shape(a);return p?dot(spotIn(p,a),twinkle(tally.get(a.county)||0,max)):'';}).join('');
 // Sizes in map units for how wide the map is drawn. Santuri is a hollow square under the dots, so artists there stay visible.
 const unit=Number(viewBox.split(' ')[2])/(svg.getBoundingClientRect().width||400),r=(RING_PX*unit).toFixed(1),m=MARK_PX*unit,[x,y]=SANTURI;
 svg.insertAdjacentHTML('beforeend',`${reduceMotion.matches?'':`<g class="map-ripples" aria-hidden="true">${[0,1.3].map(d=>`<circle cx="${x}" cy="${y}" r="${r}" style="animation-delay:-${d}s"/>`).join('')}</g>`}<rect class="map-santuri" x="${(x-m/2).toFixed(1)}" y="${(y-m/2).toFixed(1)}" width="${m.toFixed(1)}" height="${m.toFixed(1)}" aria-hidden="true"/><g class="map-lights" aria-hidden="true">${dots}</g>`);
}

// A live count and three listings in random order (the directory is never ranked).
async function directory(db){
 const photos=db.storage.from('directory-photos');
 const listed=(await result(db.rpc('artist_directory'))).map(a=>({...a,photo_url:a.photo?photos.getPublicUrl(a.photo).data.publicUrl:''}));
 const counties=new Set(listed.map(a=>a.county)).size;
 count.textContent=listed.length?`${listed.length} ${listed.length===1?'person':'people'} listed across ${counties} ${counties===1?'county':'counties'}`:'Be one of the first to list yourself.';
 if(listed.length){people.innerHTML=listed.slice(0,3).map(artistCard).join('');people.hidden=false;
  fact('fact-people',pad(listed.length),listed.length===1?'Artist listed':'Artists listed');fact('fact-counties',pad(counties),counties===1?'County':'Counties');}
 await drawMap(listed);
}

// "Open next": each room's next free hour, in Nairobi time.
const dayOf=d=>new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Nairobi'}).format(d);
function when(iso){
 const d=new Date(iso),day=dayOf(d),time=new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Nairobi',hour:'2-digit',minute:'2-digit'}).format(d);
 if(day===dayOf(new Date()))return `Today ${time}`;if(day===dayOf(new Date(Date.now()+864e5)))return `Tomorrow ${time}`;
 return `${new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Nairobi',weekday:'short'}).format(d)} ${time}`;
}
async function openTimes(db){
 const rooms=await result(db.rpc('next_open_times'));
 openNext.innerHTML=rooms.length?rooms.map(r=>`<li><a href="book.html?space=${encodeURIComponent(r.slug)}"><span>${e(r.name)}</span><b>${when(r.starts_at)} ↗</b></a></li>`).join('')
  :'<li><a href="mailto:bookings@santuri.org?subject=Booking enquiry"><span>Fully booked this week</span><b>Ask the team ↗</b></a></li>';
}

if(configured())getClient().then(db=>Promise.allSettled([openTimes(db),directory(db).catch(()=>drawMap([])),gear(db)])).catch(()=>{});
