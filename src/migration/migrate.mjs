import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect,sql} from '../ingest/database.mjs';
import {tableBatches,gateBatches} from './schema.mjs';
import {viewBatches} from './views.mjs';
import {digest,validateCatalog} from './catalog.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export function migrationPlan(){const batches=[...tableBatches(),...gateBatches(),...viewBatches()];return {id:'001-normalized-estate',digest:digest(batches.join('\nGO\n')),batches,...validateCatalog(),views:viewBatches().length};}
export async function emitMigration(){const plan=migrationPlan();const file=path.join(root,'sql/migrations',plan.id+'.sql');await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,`-- Generated from src/migration/catalog.mjs, schema.mjs and views.mjs.\n-- Migration ${plan.id}; sha256:${plan.digest}\n-- Apply transactionally through npm run migrate.\n\n`+plan.batches.join('\nGO\n')+'\n');return {plan,file};}
export async function migrate({dryRun=false}={}){
 const {plan,file}=await emitMigration();const pool=await connect();const tx=new sql.Transaction(pool);let active=false;
 try{
  await tx.begin();active=true;
  const r=await new sql.Request(tx).query(`DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:ddl-migration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MIGRATION_LOCK_UNAVAILABLE',1; SELECT COUNT_BIG(*) n FROM sys.tables WHERE is_ms_shipped=0; SELECT OBJECT_ID('source.schema_migration') ledger;`);
  if(r.recordsets[1][0].ledger){const applied=await new sql.Request(tx).input('id',sql.NVarChar(100),plan.id).query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id');if(applied.recordset[0]?.migration_digest===plan.digest){await tx.rollback();active=false;return {status:'ALREADY_APPLIED',migration:plan.id,digest:plan.digest,...validateCatalog()};}throw new Error('MIGRATION_HISTORY_MISMATCH');}
  if(Number(r.recordsets[0][0].n)!==0)throw new Error('DATABASE_NOT_EMPTY_NO_MIGRATION_LEDGER');
  // DDL is atomic. No partially constructed schema is left after a failed batch.
  const execution=[];let pending=[];
  for(const batch of plan.batches){if(/^CREATE (VIEW|PROCEDURE|TRIGGER)\b/.test(batch)){if(pending.length){execution.push(pending.join('\n'));pending=[];}execution.push(batch);}else pending.push(batch);}
  if(pending.length)execution.push(pending.join('\n'));
  for(let i=0;i<execution.length;i++)try{await new sql.Request(tx).batch(execution[i]);}catch(e){throw new Error(`MIGRATION_BATCH_${i}: ${e.message}`);}
  await new sql.Request(tx).batch('CREATE TABLE source.schema_migration(migration_id nvarchar(100) NOT NULL PRIMARY KEY,migration_digest char(64) NOT NULL,applied_at datetime2(7) NOT NULL DEFAULT SYSUTCDATETIME());');
  await new sql.Request(tx).input('id',sql.NVarChar(100),plan.id).input('hash',sql.Char(64),plan.digest).query('INSERT source.schema_migration(migration_id,migration_digest) VALUES(@id,@hash)');
  await new sql.Request(tx).batch('DENY INSERT,UPDATE,DELETE ON OBJECT::source.schema_migration TO sidefx_importer;');
  if(dryRun)await tx.rollback();else await tx.commit();active=false;return {status:dryRun?'VALIDATED_AND_ROLLED_BACK':'APPLIED',migration:plan.id,digest:plan.digest,sqlFile:file,...validateCatalog(),views:plan.views};
 }catch(e){if(active)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{console.log(JSON.stringify(process.argv.includes('--emit-only')?((await emitMigration()).plan.batches.length):await migrate({dryRun:process.argv.includes('--dry-run')}),null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
