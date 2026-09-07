import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {complete,validateKeys} from './complete.mjs';
import {load,loadOrder,bulkDataset} from './load.mjs';
import {canonical} from './data.mjs';
import {tables,digest,q,fq} from './catalog.mjs';
import {connect,sql} from '../ingest/database.mjs';
import {migrationPlan} from './migrate.mjs';
import {migrateCoverageViews} from './coverage-views.mjs';
import {migrateLineageGate} from './lineage-gate.mjs';

export function rowDigest(name,rows){const cols=Object.entries(tables.get(name).columns).filter(([,s])=>s.token!=='BYTES');return digest(rows.map(r=>digest(canonical(cols.map(([c,s])=>{const v=r[c];if(v==null)return null;if(s.token==='D')return Buffer.from(v).toString('hex');if(['K','N','bigint','tinyint'].includes(s.token))return String(v);if(s.token==='T')return new Date(v).toISOString();if(s.token==='B')return Boolean(v);return v;})))).sort().join('\n'));}
async function save(file,state){await fs.writeFile(new URL(file.href+'.tmp'),JSON.stringify(state,null,2)+'\n');await fs.rename(new URL(file.href+'.tmp'),file);}
export async function loadComplete({progress=()=>{},publish=true,dryRun=false,derive=complete,stage='completeness',baseModelPk=1,ensureBase=load}={}){
 if(!['completeness','platform'].includes(stage))throw new Error('INVALID_LOAD_STAGE');
 const stateFile=new URL('../../data/'+stage+'/table-checkpoints.json',import.meta.url);
 await fs.mkdir(new URL('../../data/'+stage+'/',import.meta.url),{recursive:true});
 if(dryRun)throw new Error('Use derive for a read-only preview. Committed tables are never rolled back by later failures.');
 let state;try{state=JSON.parse(await fs.readFile(stateFile));}catch(e){if(e.code!=='ENOENT')throw e;}
 const evaluatedAt=state?.evaluatedAt??new Date().toISOString(),ds=await derive({evaluatedAt});validateKeys(ds);progress({phase:'COMPLETENESS_NORMALIZED',...ds.summary});
 const basePlan=migrationPlan();if(state&&(state.manifest!==ds.summary.manifest||state.schemaDigest!==basePlan.digest))throw new Error('COMPLETENESS_CHECKPOINT_GENERATION_MISMATCH');
 state??={snapshot:ds.summary.snapshot,manifest:ds.summary.manifest,schemaDigest:basePlan.digest,evaluatedAt,tables:{}};
 let pool=await connect();
 const base=(await pool.request().input('base',sql.BigInt,baseModelPk).query('SELECT publication_state FROM source.estate_model WHERE estate_model_pk=@base')).recordset[0];
 await pool.close();if(!base||base.publication_state!=='PUBLISHED')await ensureBase({progress});
 await migrateCoverageViews();await migrateLineageGate();pool=await connect();
 try{
  const history=(await pool.request().input('id',sql.NVarChar(100),basePlan.id).query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id')).recordset[0];if(history?.migration_digest!==basePlan.digest)throw new Error('MIGRATION_HISTORY_MISMATCH');
  const selected=Number((await pool.request().query('SELECT estate_model_pk FROM source.current_model')).recordset[0]?.estate_model_pk);
  await save(stateFile,state);
  const allRows=ds.rows,delta={rows:new Map([...allRows].map(([n,r])=>[n,r.slice(ds.baseCounts[n]??0)]))};
  for(const name of loadOrder(delta)){
   const rows=delta.rows.get(name),baseCount=ds.baseCounts[name]??0,total=baseCount+rows.length,expected=rowDigest(name,rows),t=tables.get(name),tx=new sql.Transaction(pool);let active=false;const start=Date.now();
   try{await tx.begin();active=true;await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @r<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1;");const n=Number((await new sql.Request(tx).query('SELECT COUNT_BIG(*) n FROM '+fq(name))).recordset[0].n);
    if(n===baseCount){await bulkDataset(tx,delta,{onlyTables:[name]});}else if(n===total){
     // Verify the actual appended rows even if a prior process died after COMMIT.
     const cols=Object.entries(t.columns).filter(([,s])=>s.token!=='BYTES').map(([c])=>q(c)).join(',');let predicate='';const request=new sql.Request(tx);
     if(t.identity&&t.pk.length===1){const min=rows.reduce((m,r)=>Math.min(m,r[t.pk[0]]),Infinity);request.input('min',sql.BigInt,min);predicate=' WHERE '+q(t.pk[0])+'>=@min';}
     const actual=(await request.query('SELECT '+cols+' FROM '+fq(name)+predicate)).recordset;
     const wanted=new Set(rows.map(r=>canonical(t.pk.map(c=>Buffer.isBuffer(r[c])?r[c].toString('hex'):String(r[c])))));
     let appended=predicate?actual:actual.filter(r=>wanted.has(canonical(t.pk.map(c=>Buffer.isBuffer(r[c])?r[c].toString('hex'):String(r[c])))));
     // Publication is the one authorized mutable state transition after table loading.
     if(name==='source.estate_model'&&selected===ds.model.estate_model_pk)appended=appended.map(r=>Number(r.estate_model_pk)===selected&&r.publication_state==='PUBLISHED'?{...r,publication_state:'BUILDING'}:r);
     if(rowDigest(name,appended)!==expected)throw new Error('COMMITTED_CONTENT_MISMATCH:'+name);
    }else throw new Error('UNEXPECTED_TABLE_ROW_COUNT:'+name+':'+n+':expected '+baseCount+' or '+total);
    await tx.commit();active=false;const committed=Number((await pool.request().query('SELECT COUNT_BIG(*) n FROM '+fq(name))).recordset[0].n);if(committed!==total)throw new Error('COMMITTED_COUNT_MISMATCH:'+name);
    state.tables[name]={added:rows.length,rows:total,digest:expected};await save(stateFile,state);progress({status:n===baseCount?'COMMITTED':'ALREADY_COMMITTED',table:name,rows:total,added:rows.length,seconds:(Date.now()-start)/1000});
   }catch(e){if(active)await tx.rollback().catch(()=>{});throw e;}
  }
  let status='TABLES_COMMITTED';if(publish){const current=(await pool.request().query('SELECT estate_model_pk FROM source.current_model')).recordset[0];if(Number(current?.estate_model_pk)===ds.model.estate_model_pk)status='ALREADY_LOADED';else{progress({phase:'VALIDATING_COMMITTED_MODEL'});await new sql.Request(pool,{requestTimeout:600000}).input('model',sql.BigInt,ds.model.estate_model_pk).query('EXEC source.publish_model @estate_model_pk=@model');status='LOADED_AND_SELECTED';}}
  const result={status,...ds.summary};await save(new URL('../../data/'+stage+'/load-result.json',import.meta.url),result);await save(new URL('../../data/'+stage+'/appearance-coverage.json',import.meta.url),ds.artifactReport);return result;
 }finally{await pool.close();}
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{const r=await loadComplete({publish:!process.argv.includes('--load-only'),progress:x=>console.log(x.table?`${x.status}: ${x.table} +${x.added} (${x.rows} committed)`:x.phase)});console.log(JSON.stringify(r,null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
