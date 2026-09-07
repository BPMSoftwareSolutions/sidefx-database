import {fileURLToPath} from 'node:url';
import {platform} from './platform.mjs';
import {load} from './load.mjs';
import {migrateCoverageViews} from './coverage-views.mjs';
import {migrateLineageGate} from './lineage-gate.mjs';
export async function loadPlatform(options={}){
 if(options.dryRun)throw new Error('Use derive for a read-only preview.');
 await migrateCoverageViews();await migrateLineageGate();
 // Compose every family before loading. Publish only after all tables commit.
 return load({...options,derive:platform,stage:'platform'});
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{const r=await loadPlatform({publish:!process.argv.includes('--load-only'),progress:x=>console.log(x.table?`${x.status}: ${x.table} (${x.rows} committed)`:x.phase)});console.log(JSON.stringify(r,null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
