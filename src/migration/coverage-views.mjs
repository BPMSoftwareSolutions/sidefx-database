import fs from 'node:fs/promises';
import {connect,sql} from '../ingest/database.mjs';
import {digest} from './catalog.mjs';

export const coverageViews=[`CREATE OR ALTER VIEW sidefx.v_estate_inventory AS
SELECT a.source_appearance_pk,a.source_path,a.source_class,a.content_object_pk,c.family_code,c.classification_state,c.mapping_rule_pk
FROM source.current_model cm
JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk
JOIN source.source_appearance a ON a.estate_snapshot_pk=m.estate_snapshot_pk
LEFT JOIN source.source_classification c ON c.source_appearance_pk=a.source_appearance_pk
 AND EXISTS(SELECT 1 FROM source.estate_model_rule r WHERE r.estate_model_pk=m.estate_model_pk AND r.mapping_rule_pk=c.mapping_rule_pk)
 AND NOT EXISTS(
   SELECT 1 FROM source.mapping_rule predecessor
   JOIN source.estate_model_rule active ON active.estate_model_pk=m.estate_model_pk
   JOIN source.mapping_rule successor ON successor.mapping_rule_pk=active.mapping_rule_pk
   JOIN source.content_object body ON body.content_object_pk=successor.rule_content_object_pk
   WHERE predecessor.mapping_rule_pk=c.mapping_rule_pk
    AND JSON_VALUE(CONVERT(varchar(max),body.content_bytes),'$.supersedesClassificationRuleDigest')=LOWER(CONVERT(char(64),predecessor.rule_digest,2))
 );`,
`CREATE OR ALTER VIEW sidefx.v_source_reference_gap AS
SELECT r.estate_model_pk,r.reference_role,r.resolution_state,a.source_path,a.source_class,o.locator,f.finding_code,f.message,r.source_observation_pk
FROM source.current_model cm JOIN analysis.unresolved_reference r ON r.estate_model_pk=cm.estate_model_pk
JOIN source.source_observation o ON o.source_observation_pk=r.source_observation_pk
JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk
LEFT JOIN analysis.integrity_finding f ON f.integrity_finding_pk=r.finding_pk;`,
`CREATE OR ALTER VIEW sidefx.v_load_completeness AS
SELECT cm.estate_model_pk,m.publication_state,
(SELECT COUNT_BIG(*) FROM source.source_appearance a WHERE a.estate_snapshot_pk=m.estate_snapshot_pk) captured_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_estate_inventory) classified_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_estate_inventory WHERE classification_state='SUPPORTED') normalized_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_estate_inventory WHERE classification_state='UNSUPPORTED') unsupported_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_estate_inventory WHERE classification_state='AMBIGUOUS') unresolved_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_estate_inventory WHERE classification_state='OUTSIDE_SCOPE') outside_scope_appearances,
(SELECT COUNT_BIG(*) FROM sidefx.v_source_reference_gap) unresolved_references
FROM source.current_model cm JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk;`];

export async function migrateCoverageViews(){const id='002-completeness-views',hash=digest(coverageViews.join('\nGO\n'));const pool=await connect(),tx=new sql.Transaction(pool);let active=false;
 try{await tx.begin();active=true;await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:ddl-migration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @r<0 THROW 51002,'MIGRATION_LOCK_UNAVAILABLE',1;");const old=(await new sql.Request(tx).input('id',sql.NVarChar(100),id).query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id')).recordset[0];if(old&&old.migration_digest!==hash)throw new Error('MIGRATION_HISTORY_MISMATCH:'+id);if(!old){for(const batch of coverageViews)await new sql.Request(tx).batch(batch);await new sql.Request(tx).input('id',sql.NVarChar(100),id).input('hash',sql.Char(64),hash).query('INSERT source.schema_migration(migration_id,migration_digest) VALUES(@id,@hash)');}await tx.commit();active=false;await fs.writeFile(new URL('../../sql/migrations/002-completeness-views.sql',import.meta.url),coverageViews.join('\nGO\n')+'\n');return {id,digest:hash};}catch(e){if(active)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
