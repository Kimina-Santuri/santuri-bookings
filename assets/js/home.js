// Landing page previews of the gear catalogue and the artist directory. Each section keeps its static copy and links if loading fails.
import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e,money,safeImage} from './booking-utils.js';
import {artistCard} from './directory-data.js';

const gearGrid=document.querySelector('#home-gear'),people=document.querySelector('#home-directory'),count=document.querySelector('#home-directory-count');

// Up to four items with photos, rentable ones first.
async function gear(db){
 const items=(await result(db.from('gear_items').select('*').eq('active',true).order('sort_order').order('name'))).filter(g=>g.image_url);
 const open=g=>g.available&&g.quantity>0&&g.price>0;
 const pick=[...items.filter(open),...items.filter(g=>!open(g))].slice(0,4);
 if(!pick.length)return;
 gearGrid.innerHTML=pick.map(g=>`<a class="space-card home-gear-card" href="${open(g)?`rent-gear.html?item=${encodeURIComponent(g.id)}`:'gear.html'}"><div class="space-image"><img src="${e(safeImage(g.image_url))}" alt="${e(g.image_alt||g.name)}" width="800" height="600" loading="lazy"></div><div class="space-body"><p class="space-meta">${open(g)?`${money(g.price)} / ${g.price_unit==='hour'?'hour':'day'}`:'Ask the team'}</p><h3>${e(g.name)}</h3></div></a>`).join('');
 gearGrid.hidden=false;
}

// A live count and three listings in random order (the directory is never ranked).
async function directory(db){
 const photos=db.storage.from('directory-photos');
 const listed=(await result(db.rpc('artist_directory'))).map(a=>({...a,photo_url:a.photo?photos.getPublicUrl(a.photo).data.publicUrl:''}));
 const counties=new Set(listed.map(a=>a.county)).size;
 count.textContent=listed.length?`${listed.length} ${listed.length===1?'person':'people'} listed across ${counties} ${counties===1?'county':'counties'}`:'Be one of the first to list yourself.';
 if(listed.length){people.innerHTML=listed.slice(0,3).map(artistCard).join('');people.hidden=false;}
}

if(configured())getClient().then(db=>Promise.allSettled([gear(db),directory(db)])).catch(()=>{});
