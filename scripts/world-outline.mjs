// Usage: node scripts/world-outline.mjs land-110m.json assets/data/world.json
// Input: world-atlas@2.0.2 land-110m.json (https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/land-110m.json), Natural Earth data, public domain.
// Turns Natural Earth land (world-atlas TopoJSON) into one SVG path in the Kenya map's units.
// Kenya map projection (fitted): x=(lon-33.909)*500.2, y=(5.416-lat)*500.2. Path is drawn in 0.1° steps with a transform.
import {readFileSync,writeFileSync} from 'node:fs';
const [src,out]=process.argv.slice(2);
const topo=JSON.parse(readFileSync(src,'utf8')),{scale,translate}=topo.transform;
const arcs=topo.arcs.map(arc=>{let x=0,y=0;return arc.map(([dx,dy])=>{x+=dx;y+=dy;return [x*scale[0]+translate[0],y*scale[1]+translate[1]];});});
const ringOf=ids=>ids.flatMap((i,n)=>{const a=i<0?arcs[~i].slice().reverse():arcs[i];return n?a.slice(1):a;});
const polys=topo.objects.land.geometries.flatMap(g=>g.type==='Polygon'?[g.arcs]:g.arcs);
const box={w:-60,e:100,s:-70,n:85},MIN_AREA=40; // area in (0.1°)², drops specks
let d='',kept=0,points=0;
for(const poly of polys)for(const ids of poly){
 const ring=ringOf(ids);const lons=ring.map(p=>p[0]),lats=ring.map(p=>p[1]);
 if(Math.max(...lons)<box.w||Math.min(...lons)>box.e||Math.max(...lats)<box.s||Math.min(...lats)>box.n)continue;
 const g=[];for(const [lon,lat] of ring){const p=[Math.round(lon*10),Math.round(-lat*10)];const q=g[g.length-1];if(!q||q[0]!==p[0]||q[1]!==p[1])g.push(p);}
 if(g.length<4)continue;let area=0;for(let i=0;i<g.length;i++){const [a,b]=g[i],[c,e]=g[(i+1)%g.length];area+=a*e-c*b;}if(Math.abs(area)/2<MIN_AREA)continue;
 // A ring crossing the 180° meridian (e.g. Fiji) would draw a line right round the map: start a new subpath at each jump.
 const jump=(p,q)=>Math.abs(p[0]-q[0])>1800,crosses=g.some((p,i)=>i&&jump(p,g[i-1]));
 d+=`M${g[0][0]} ${g[0][1]}`+g.slice(1).map((p,i)=>jump(p,g[i])?`M${p[0]} ${p[1]}`:`l${p[0]-g[i][0]} ${p[1]-g[i][1]}`).join('').replace(/l(-?\d+) (-?\d+)/g,(m,a,b)=>`l${a}${b.startsWith('-')?'':' '}${b}`)+(crosses?'':'z');kept++;points+=g.length;
}
// lon*10 -> x: (gx/10-33.909)*500.2 = gx*50.02-16961.3 ; -lat*10 -> y: (5.416+gy/10)*500.2 = gy*50.02+2709.1
writeFileSync(out,JSON.stringify({transform:'matrix(50.02 0 0 50.02 -16961.3 2709.1)',d}));
console.log(`${kept} rings, ${points} points, ${d.length} chars`);
