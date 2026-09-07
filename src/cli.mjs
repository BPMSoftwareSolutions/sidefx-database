import { probe } from './ingest/database.mjs';
import { capture } from './snapshot/capture.mjs';
import { migrate,emitMigration } from './migration/migrate.mjs';
import { platform } from './migration/platform.mjs';
import { loadPlatform } from './migration/load-platform.mjs';
import { query } from './query/run.mjs';
import { verify } from './migration/verify.mjs';
import { prove } from './migration/prove.mjs';
import fs from 'node:fs/promises';

try {
  const command = process.argv[2];
  let result;
  if (command === 'probe') result = await probe();
  else if (command === 'snapshot') result = await capture();
  else if (command === 'derive') result=(await platform()).summary;
  else if (command === 'init'||command==='migrate') result = await migrate({dryRun:process.argv.includes('--dry-run')});
  else if (command === 'schema:emit') {const {plan,file}=await emitMigration();result={file,digest:plan.digest};}
  else if (command === 'ingest') result = await loadPlatform({dryRun:process.argv.includes('--dry-run'),publish:!process.argv.includes('--load-only'),progress:x=>{if(x.table)console.error(`${x.status}: ${x.table} (${x.rows} rows)`);}});
  else if (command === 'verify') result = await verify();
  else if (command === 'check') result = await verify();
  else if (command === 'prove') result=await prove();
  else if (command === 'refresh') {await migrate();result=await loadPlatform();}
  else if (command === 'query') {
    const args=process.argv.slice(3),value=key=>args[args.indexOf(key)+1];
    const statement=args.includes('--file')?await fs.readFile(value('--file'),'utf8'):args.includes('--sql')?value('--sql'):await new Promise((resolve,reject)=>{let s='';process.stdin.setEncoding('utf8');process.stdin.on('data',v=>s+=v);process.stdin.on('end',()=>resolve(s));process.stdin.on('error',reject);});
    result=await query(statement,{rowLimit:args.includes('--limit')?Number(value('--limit')):undefined,committed:args.includes('--committed')});
  }
  else throw new Error('COMMAND_NOT_IMPLEMENTED:' + command);
  console.log(JSON.stringify(result, null, 2));
} catch (e) {
  // Do not serialize driver errors/configuration: they may carry connection credentials.
  console.error(JSON.stringify({ error: e.message, code: e.code ?? null }));
  process.exitCode = 1;
}
