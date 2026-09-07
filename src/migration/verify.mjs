import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect,sql} from '../ingest/database.mjs';
import {tables,families,fq,q,validateCatalog} from './catalog.mjs';
import {migrationPlan} from './migrate.mjs';

export async function verify({requireModel=true}={}){
 const pool=await connect();try{
  const p=migrationPlan(),r=await pool.request().input('id',sql.NVarChar(100),p.id).query(`SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id; SELECT COUNT_BIG(*) n FROM sys.foreign_keys WHERE OBJECT_SCHEMA_NAME(parent_object_id) IN('model','source','analysis'); SELECT name FROM sys.foreign_keys WHERE (is_disabled=1 OR is_not_trusted=1) AND OBJECT_SCHEMA_NAME(parent_object_id) IN('model','source','analysis') UNION ALL SELECT name FROM sys.check_constraints WHERE (is_disabled=1 OR is_not_trusted=1) AND OBJECT_SCHEMA_NAME(parent_object_id) IN('model','source','analysis'); SELECT m.estate_model_pk,m.publication_state,CONVERT(varchar(64),s.snapshot_digest,2) snapshot_digest FROM source.current_model c JOIN source.estate_model m ON m.estate_model_pk=c.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk;`);
  if(r.recordsets[0][0]?.migration_digest!==p.digest)throw new Error('MIGRATION_HISTORY_MISMATCH');if(Number(r.recordsets[1][0].n)!==p.foreignKeys||r.recordsets[2].length)throw new Error('CONSTRAINT_CATALOG_INVALID');if(requireModel&&r.recordsets[3][0]?.publication_state!=='PUBLISHED')throw new Error('NO_SELECTED_MODEL');
  const identities=await pool.request().query(families.map(f=>`SELECT '${f.name}' family,COUNT_BIG(*) identity_count,COALESCE(SUM(CONVERT(bigint,CASE WHEN ${q(f.idColumn)} IS NULL OR namespace_pk IS NULL THEN 1 ELSE 0 END)),0) null_id_count,(SELECT COUNT_BIG(*) FROM (SELECT namespace_pk,${q(f.idColumn)} FROM model.${q(f.name)} GROUP BY namespace_pk,${q(f.idColumn)} HAVING COUNT_BIG(*)>1) x) duplicate_key_count FROM model.${q(f.name)}`).join(' UNION ALL '));
  if(identities.recordset.some(r=>Number(r.null_id_count)||Number(r.duplicate_key_count)))throw new Error('ENTITY_INTEGRITY_FAILED');
  const grains=await pool.request().query(`SELECT 'capability' view_name,COUNT_BIG(*) row_count,COUNT(DISTINCT capability_pk) key_count FROM sidefx.v_capability UNION ALL SELECT 'scenario',COUNT_BIG(*),COUNT(DISTINCT scenario_version_pk) FROM sidefx.v_scenario UNION ALL SELECT 'provider',COUNT_BIG(*),COUNT(DISTINCT provider_pk) FROM sidefx.v_provider; SELECT COUNT_BIG(*) scenario_count,SUM(CONVERT(bigint,has_input)) input_count,SUM(CONVERT(bigint,has_event)) event_count,SUM(CONVERT(bigint,has_outcome)) outcome_count,(SELECT COUNT_BIG(*) FROM sidefx.v_complete_scenario) complete_count FROM sidefx.v_scenario; SELECT source_profile,total_count,normalized_count,unresolved_count,unsupported_count,outside_count FROM sidefx.v_assessment_coverage; SELECT finding_code,COUNT_BIG(*) finding_count FROM sidefx.v_circuit_integrity_findings GROUP BY finding_code;`);
  if(grains.recordsets[0].some(r=>Number(r.row_count)!==Number(r.key_count)))throw new Error('VIEW_GRAIN_MULTIPLICATION');
  const completenessExists=(await pool.request().query("SELECT OBJECT_ID('sidefx.v_load_completeness') id")).recordset[0].id;
  let loadCompleteness=null,tableCounts=null;
  if(completenessExists){loadCompleteness=(await pool.request().query('SELECT * FROM sidefx.v_load_completeness')).recordset[0]??null;if(loadCompleteness&&Number(loadCompleteness.captured_appearances)!==Number(loadCompleteness.classified_appearances))throw new Error('SOURCE_CLASSIFICATION_GRAIN_INVALID');}
  if([2,3].includes(Number(loadCompleteness?.estate_model_pk))){
   const stage=Number(loadCompleteness.estate_model_pk)===3?'platform':'completeness';
   const expected=JSON.parse(await fs.readFile(new URL('../../data/'+stage+'/load-result.json',import.meta.url),'utf8'));
   const manifest=(await pool.request().input('model',sql.BigInt,loadCompleteness.estate_model_pk).query('SELECT LOWER(CONVERT(char(64),mapping_manifest_digest,2)) digest FROM source.estate_model WHERE estate_model_pk=@model')).recordset[0].digest;
   if(expected.manifest!==manifest)throw new Error('LOAD_VERIFICATION_GENERATION_MISMATCH');
   tableCounts=(await pool.request().query([...tables.keys()].map(n=>`SELECT '${n}' table_name,COUNT_BIG(*) row_count FROM ${fq(n)}`).join(' UNION ALL '))).recordset;
   for(const t of tableCounts){const count=t.table_name==='source.current_model'?1:expected.counts[t.table_name]??0;if(Number(t.row_count)!==count)throw new Error('COMMITTED_TABLE_COUNT_MISMATCH:'+t.table_name);}
  }
  const result={status:'VERIFIED',migration:p.id,digest:p.digest,catalog:validateCatalog(),selectedModel:r.recordsets[3][0]??null,entities:identities.recordset,viewGrains:grains.recordsets[0],scenarioFaces:grains.recordsets[1],coverage:grains.recordsets[2],findings:grains.recordsets[3],loadCompleteness,tableCounts};
  const dir=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../data/migration');await fs.mkdir(dir,{recursive:true});await fs.writeFile(path.join(dir,'verification.json'),JSON.stringify(result,null,2)+'\n');return result;
 }finally{await pool.close();}
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{console.log(JSON.stringify(await verify({requireModel:!process.argv.includes('--schema-only')}),null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
