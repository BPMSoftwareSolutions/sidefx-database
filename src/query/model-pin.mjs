import { sql } from '../ingest/database.mjs';
import { digest, stable } from '../core.mjs';

// Shared by observation and preparation publication: neither may straddle a
// selected-model change. Definition identity also invalidates derived results.
export async function pinModel(tx) {
  await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Shared',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51000,'Cannot pin inspection model',1;");
  const pinned = (await new sql.Request(tx).query("SELECT m.estate_model_pk,'sha256:'+LOWER(CONVERT(varchar(64),s.snapshot_digest,2)) snapshot_id,'sha256:'+LOWER(CONVERT(varchar(64),m.mapping_manifest_digest,2)) projection_id FROM source.current_model cm WITH(HOLDLOCK) JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk WHERE cm.singleton_id=1")).recordset[0];
  if (!pinned) throw new Error('NO_LOADED_SNAPSHOT');
  const definitions = (await new sql.Request(tx).query("SELECT s.name+'.'+o.name AS object_name,o.type,m.definition FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE s.name IN('sidefx','analysis') AND o.type IN('V','IF','TF','FN') ORDER BY s.name COLLATE Latin1_General_100_BIN2,o.name COLLATE Latin1_General_100_BIN2")).recordset;
  return { ...pinned, definitions, viewDefinitionDigest: digest(Buffer.from(stable(definitions))) };
}
