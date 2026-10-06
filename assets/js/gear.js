import {getClient,configured,result} from './supabase-client.js';
import {escapeHTML as e,money,safeImage} from './booking-utils.js';
const grid=document.querySelector('#gear-grid');
const unavailable='<p>Gear listings could not be loaded. Please <a href="mailto:bookings@santuri.org?subject=Gear rental enquiry">contact the team</a> about equipment rental.</p>';
if(!configured())grid.innerHTML='<p>Online gear rental is opening soon. Contact <a href="mailto:bookings@santuri.org?subject=Gear rental enquiry">bookings@santuri.org</a> to ask about equipment.</p>';
else load().catch(()=>{grid.innerHTML=unavailable;});
async function load(){
 const db=await getClient();const items=await result(db.from('gear_items').select('*').eq('active',true).order('sort_order').order('name'));
 grid.innerHTML=items.length?items.map(g=>{const open=g.available&&g.quantity>0;return `<article class="space-card gear-card">${g.image_url?`<div class="space-image"><img src="${e(safeImage(g.image_url))}" alt="${e(g.image_alt)}" width="800" height="600" loading="lazy"></div>`:''}<div class="space-body"><div class="space-meta">${g.category?`<span>${e(g.category)}</span>`:''}<span>${money(g.price)} / ${g.price_unit==='hour'?'hour':'day'} · ${g.quantity} ${g.quantity===1?'unit':'units'}</span></div><h3>${e(g.name)}</h3>${g.description?`<p>${e(g.description)}</p>`:''}<div class="space-actions">${open?`<a class="button" href="rent-gear.html?item=${encodeURIComponent(g.id)}">Request rental ↗</a>`:'<span class="secondary-button" aria-disabled="true">Currently unavailable</span>'}</div></div></article>`;}).join(''):'<p>No gear is listed for rental at the moment. Contact <a href="mailto:bookings@santuri.org?subject=Gear rental enquiry">bookings@santuri.org</a> to ask about equipment.</p>';
}
