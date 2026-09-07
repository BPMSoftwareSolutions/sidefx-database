import fs from 'node:fs/promises';
import {gateBatches} from './schema.mjs';
import {digest} from './catalog.mjs';
import {connect,sql} from '../ingest/database.mjs';

export function lineageGateSql(){
 const original=gateBatches().find(s=>s.startsWith('CREATE PROCEDURE source.validate_model '));
 if(original.split('source.v_normalized_member').length!==3)throw new Error('UNEXPECTED_LINEAGE_GATE_SHAPE');
 const cached=`SELECT r._owner_definition_pk,r.member_kind,r._canonical_pointer_key INTO #normalized_members FROM source.v_normalized_member r WHERE EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r._owner_definition_pk); CREATE CLUSTERED INDEX IX_normalized_members ON #normalized_members(_owner_definition_pk,member_kind,_canonical_pointer_key);`;
 return original.replace('CREATE PROCEDURE','ALTER PROCEDURE').replaceAll('source.v_normalized_member','#normalized_members').replace('SET NOCOUNT ON;','SET NOCOUNT ON; '+cached);
}
export async function migrateLineageGate(){const id='003-index-lineage-validation',body=lineageGateSql(),hash=digest(body),pool=await connect(),tx=new sql.Transaction(pool);let active=false;
 try{await tx.begin();active=true;await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:ddl-migration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @r<0 THROW 51002,'MIGRATION_LOCK_UNAVAILABLE',1;");const old=(await new sql.Request(tx).input('id',sql.NVarChar(100),id).query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id')).recordset[0];if(old&&old.migration_digest!==hash)throw new Error('MIGRATION_HISTORY_MISMATCH:'+id);if(!old){await new sql.Request(tx).batch(body);await new sql.Request(tx).input('id',sql.NVarChar(100),id).input('hash',sql.Char(64),hash).query('INSERT source.schema_migration(migration_id,migration_digest) VALUES(@id,@hash)');}await tx.commit();active=false;await fs.writeFile(new URL('../../sql/migrations/003-index-lineage-validation.sql',import.meta.url),body+'\n');return {id,digest:hash};}catch(e){if(active)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
