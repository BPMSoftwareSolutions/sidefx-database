import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect,sql} from '../ingest/database.mjs';
import {tables,fq,q,digest} from './catalog.mjs';
import {canonical} from './data.mjs';
import {normalize} from './normalize.mjs';
import {migrationPlan} from './migrate.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const types={K:sql.BigInt,D:sql.Binary(32),ID:sql.NVarChar(400),CODE:sql.VarChar(64),TXT:sql.NVarChar(sql.MAX),PTR:sql.NVarChar(400),N:sql.Int,B:sql.Bit,T:sql.DateTime2(7),BYTES:sql.VarBinary(sql.MAX),bigint:sql.BigInt,tinyint:sql.TinyInt};
export function loadOrder(ds){const pending=new Set([...ds.rows].filter(([,r])=>r.length).map(([n])=>n)),done=new Set(),order=[];while(pending.size){let progress=false;for(const n of pending){const t=tables.get(n);if(t.fks.some(f=>pending.has(f.target)&&f.target!==n))continue;pending.delete(n);done.add(n);order.push(n);progress=true;}if(!progress)throw new Error('TABLE_DEPENDENCY_CYCLE:'+ [...pending].join(','));}return order;}
export async function bulkDataset(tx,ds,{progress=()=>{},onlyTables=loadOrder(ds)}={}){
 for(const name of onlyTables){
  const t=tables.get(name),columns=Object.entries(t.columns),rows=ds.rows.get(name);let index=0;
  while(index<rows.length){const batch=new sql.Table(name);batch.create=false;for(const [c,s]of columns){const type=types[s.token];batch.columns.add(c,typeof type==='function'?type:{...type},{nullable:s.nullable});}let size=0,count=0;
   while(index<rows.length&&count<4000&&size<12*1024*1024){const r=rows[index++];const values=columns.map(([c])=>r[c]);batch.rows.add(...values);for(const v of values)size+=Buffer.isBuffer(v)?v.length:typeof v==='string'?v.length*2:8;count++;}
   try{await new sql.Request(tx).bulk(batch,{checkConstraints:true,fireTriggers:true,keepNulls:true,keepIdentity:true});}catch(e){throw new Error('LOAD_TABLE_'+name+': '+e.message);}
  }progress({table:name,rows:rows.length});
 }
}
function rowSetDigest(name,rows){
 const columns=Object.entries(tables.get(name).columns).filter(([,s])=>s.token!=='BYTES');
 const hashes=rows.map(r=>digest(canonical(columns.map(([c,s])=>{const v=r[c];if(v===null||v===undefined)return null;if(s.token==='D')return Buffer.from(v).toString('hex');if(['K','N','bigint','tinyint'].includes(s.token))return String(v);if(s.token==='T')return new Date(v).toISOString();if(s.token==='B')return Boolean(v);return v;}))));
 return digest(hashes.sort().join('\n'));
}
async function writeState(file,value){await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file+'.tmp',JSON.stringify(value,null,2)+'\n');await fs.rename(file+'.tmp',file);}
export async function load({dryRun=false,progress=()=>{},publish=true,derive=normalize,stage='migration'}={}){
 if(dryRun)throw new Error('TABLE_COMMIT_MODE: use derive for a read-only preview; committed tables are never rolled back by a later step');
 if(!['migration','platform'].includes(stage))throw new Error('INVALID_LOAD_STAGE');
 const stateFile=path.join(root,'data',stage,'table-checkpoints.json'),plan=migrationPlan();
 let state;try{state=JSON.parse(await fs.readFile(stateFile,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
 const evaluatedAt=state?.evaluatedAt??new Date().toISOString(),ds=await derive({evaluatedAt});progress({phase:'NORMALIZED',...ds.summary});
 if(state&&(state.snapshot!==ds.summary.snapshot||state.manifest!==ds.summary.manifest||state.schemaDigest!==plan.digest))throw new Error('TABLE_CHECKPOINT_GENERATION_MISMATCH');
 state??={snapshot:ds.summary.snapshot,manifest:ds.summary.manifest,schemaDigest:plan.digest,evaluatedAt,tables:{}};
 await writeState(stateFile,state);
 const resultFile=path.join(root,'data',stage,'load-result.json'),pool=await connect();
 try{
  const history=await pool.request().input('id',sql.NVarChar(100),plan.id).query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id');if(history.recordset[0]?.migration_digest!==plan.digest)throw new Error('MIGRATION_HISTORY_MISMATCH');
  const selected=await pool.request().input('snapshot',sql.Binary(32),ds.snapshot.snapshot_digest).input('manifest',sql.Binary(32),ds.model.mapping_manifest_digest).query('SELECT m.estate_model_pk FROM source.current_model cm JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk WHERE s.snapshot_digest=@snapshot AND m.mapping_manifest_digest=@manifest AND m.publication_state=\'PUBLISHED\'');
  if(selected.recordset.length)return {status:'ALREADY_LOADED',...ds.summary};
  for(const name of loadOrder(ds)){
   const rows=ds.rows.get(name),expectedDigest=rowSetDigest(name,rows),tx=new sql.Transaction(pool);let active=false;const started=Date.now();
   try{
    await tx.begin();active=true;await new sql.Request(tx).query(`DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1;`);
    const existing=Number((await new sql.Request(tx).query('SELECT COUNT_BIG(*) n FROM '+fq(name))).recordset[0].n);
    if(existing){
     if(existing!==rows.length)throw new Error('EXISTING_TABLE_ROW_COUNT_MISMATCH:'+name);
     if(state.tables[name]?.digest!==expectedDigest){
      const cols=Object.entries(tables.get(name).columns).filter(([,s])=>s.token!=='BYTES').map(([c])=>q(c)).join(',');
      const actual=(await new sql.Request(tx).query(`SELECT ${cols} FROM ${fq(name)}`)).recordset;
      if(rowSetDigest(name,actual)!==expectedDigest)throw new Error('EXISTING_TABLE_CONTENT_MISMATCH:'+name);
     }
    }else{
     await bulkDataset(tx,ds,{onlyTables:[name]});
     const count=Number((await new sql.Request(tx).query('SELECT COUNT_BIG(*) n FROM '+fq(name))).recordset[0].n);
     if(count!==rows.length)throw new Error('LOADED_TABLE_ROW_COUNT_MISMATCH:'+name);
    }
    await tx.commit();active=false;
    // This read happens after COMMIT, outside the loading transaction.
    const committed=Number((await pool.request().query('SELECT COUNT_BIG(*) n FROM '+fq(name))).recordset[0].n);
    if(committed!==rows.length)throw new Error('COMMITTED_TABLE_ROW_COUNT_MISMATCH:'+name);
    state.tables[name]={rows:committed,digest:expectedDigest,verifiedAt:new Date().toISOString()};await writeState(stateFile,state);
    progress({status:existing?'ALREADY_COMMITTED':'COMMITTED',table:name,rows:committed,seconds:Math.round((Date.now()-started)/100)/10});
   }catch(e){if(active)await tx.rollback().catch(()=>{});throw e;}
  }
  const result={status:'TABLES_COMMITTED',committedTables:Object.keys(state.tables).length,...ds.summary};
  await writeState(resultFile,result);
  if(ds.artifactReport)await writeState(path.join(root,'data',stage,'appearance-coverage.json'),ds.artifactReport);
  if(publish){progress({phase:'VALIDATING_COMMITTED_MODEL'});try{await new sql.Request(pool,{requestTimeout:600000}).input('model',sql.BigInt,ds.model.estate_model_pk).query('EXEC source.publish_model @estate_model_pk=@model');result.status='LOADED_AND_SELECTED';}catch(e){result.status='TABLES_COMMITTED_PUBLICATION_PENDING';result.publicationError=e.message;await writeState(resultFile,result);throw new Error('TABLES_REMAIN_COMMITTED; publication failed: '+e.message);}}
  await writeState(resultFile,result);return result;
 }finally{await pool.close();}
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{const r=await load({dryRun:process.argv.includes('--dry-run'),publish:!process.argv.includes('--load-only'),progress:x=>{if(x.table)console.log(`${x.status}: ${x.table} — ${x.rows} rows (${x.seconds}s)`);else console.log(x.phase);}});console.log(JSON.stringify({status:r.status,committedTables:r.committedTables},null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
