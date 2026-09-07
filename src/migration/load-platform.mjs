import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {platform} from './platform.mjs';
import {loadComplete} from './load-complete.mjs';
export async function loadPlatform(options={}){
 if(!options.dryRun){
  try{await fs.access(new URL('../../data/completeness/table-checkpoints.json',import.meta.url));}
  catch(e){if(e.code!=='ENOENT')throw e;await loadComplete({progress:options.progress});}
 }
 return loadComplete({...options,derive:platform,stage:'platform',baseModelPk:2,ensureBase:loadComplete});
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{const r=await loadPlatform({publish:!process.argv.includes('--load-only'),progress:x=>console.log(x.table?`${x.status}: ${x.table} +${x.added} (${x.rows} committed)`:x.phase)});console.log(JSON.stringify(r,null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
