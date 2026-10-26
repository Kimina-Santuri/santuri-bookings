// Dot placement shared by the directory map and the landing page map.
export const SVG='http://www.w3.org/2000/svg';
const spots=new Map();
export function seeded(text){let h=2166136261;for(const c of text)h=Math.imul(h^c.charCodeAt(0),16777619);
 return ()=>{h=h+0x6D2B79F5|0;let t=Math.imul(h^h>>>15,1|h);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
// A point inside the shape for this person, plus a 0–1 phase for their animation. The same person
// gets the same spot on every visit: it is seeded from who they are, not Math.random.
export function spotIn(shape,a){
 const key=[a.full_name,a.instagram,a.website,a.email,a.county,shape.dataset.area||''].join('|');if(spots.has(key))return spots.get(key);
 const rand=seeded(key),b=shape.getBBox(),pt=shape.ownerSVGElement.createSVGPoint();let found=[b.x+b.width/2,b.y+b.height/2];
 for(let i=0;i<40;i++){pt.x=b.x+rand()*b.width;pt.y=b.y+rand()*b.height;if(shape.isPointInFill(pt)){found=[pt.x,pt.y];break;}}
 found.push(rand());spots.set(key,found);return found;
}
// Busier places twinkle faster: 4.2 s for the quietest down to 1.4 s for the busiest.
export const twinkle=(n,max)=>4.2-2.8*Math.sqrt(n/max);
export const dot=(s,speed)=>`<path d="M${s[0].toFixed(1)} ${s[1].toFixed(1)}h.01" style="animation-duration:${speed.toFixed(2)}s;animation-delay:-${(s[2]*speed).toFixed(2)}s"/>`;
