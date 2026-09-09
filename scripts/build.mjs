import {build} from 'esbuild';
import {mkdir,cp,readdir,copyFile} from 'node:fs/promises';
await mkdir('assets/vendor',{recursive:true});
await build({stdin:{contents:"export { createClient } from '@supabase/supabase-js';",resolveDir:process.cwd()},bundle:true,format:'esm',platform:'browser',target:['es2022'],minify:true,outfile:'assets/vendor/supabase.js',legalComments:'eof'});
await mkdir('dist',{recursive:true});
for(const file of await readdir('.'))if(file.endsWith('.html')||['robots.txt','sitemap.xml'].includes(file))await copyFile(file,`dist/${file}`);
await cp('assets','dist/assets',{recursive:true});
console.log('Built static site in dist/; backend files and secrets are excluded.');
