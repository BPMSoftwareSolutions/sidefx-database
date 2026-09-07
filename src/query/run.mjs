import { connect, sql } from '../ingest/database.mjs';
import { config, hash, stable, receipt, putBlob } from '../core.mjs';

export function normalizeSql(value) {
  if(value instanceof Date)return value.toISOString();
  if(Buffer.isBuffer(value))return {sqlType:'varbinary',base64:value.toString('base64')};
  if(typeof value==='bigint')return value.toString();
  if(Array.isArray(value))return value.map(normalizeSql);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,normalizeSql(v)]));
  return value;
}

export async function query(statement,{writeReceipt=false,rowLimit,committed=false}={}) {
  if(typeof statement!=='string'||!statement.trim())throw new Error('QUERY_TEXT_REQUIRED');
  const cfg=await config(),limit=rowLimit??cfg.queryRowLimit;
  if(!Number.isSafeInteger(limit)||limit<1||limit>100000)throw new Error('INVALID_QUERY_ROW_LIMIT');
  const pool=await connect(),tx=new sql.Transaction(pool);let begun=false;
  try {
    await tx.begin();begun=true;
    if(committed){
      // Explicit inspection of tables committed so far; no selected-model claim.
      await new sql.Request(tx).batch("EXECUTE AS USER='sidefx_reader' WITH NO REVERT;");
      await new sql.Request(tx).batch(`SET ROWCOUNT ${limit+1}; SET LOCK_TIMEOUT 30000;`);
      const result=await new sql.Request(tx).query(statement);
      const truncated=result.recordsets.some(r=>r.length>limit),recordsets=result.recordsets.map(r=>r.slice(0,limit).map(normalizeSql));
      await tx.rollback();begun=false;
      return {inspectionState:'COMMITTED_TABLES',rowLimit:limit,truncated,rowCounts:recordsets.map(r=>r.length),recordsets};
    }
    await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Shared',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51000,'Cannot pin inspection model',1;");
    // HOLDLOCK pins the selected generation throughout this query transaction.
    const pinned=(await new sql.Request(tx).query("SELECT m.estate_model_pk,'sha256:'+LOWER(CONVERT(varchar(64),s.snapshot_digest,2)) snapshot_id,'sha256:'+LOWER(CONVERT(varchar(64),m.mapping_manifest_digest,2)) projection_id FROM source.current_model cm WITH(HOLDLOCK) JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk WHERE cm.singleton_id=1")).recordset[0];
    if(!pinned)throw new Error('NO_LOADED_SNAPSHOT');
    const definitions=(await new sql.Request(tx).query("SELECT s.name+'.'+v.name AS view_name,m.definition FROM sys.views v JOIN sys.schemas s ON s.schema_id=v.schema_id JOIN sys.sql_modules m ON m.object_id=v.object_id WHERE s.name='sidefx' ORDER BY v.name COLLATE Latin1_General_100_BIN2")).recordset;
    // SQL Server enforces the read boundary. NO REVERT prevents submitted SQL
    // from escaping impersonation. This dedicated pool is closed after the query.
    await new sql.Request(tx).batch("EXECUTE AS USER='sidefx_reader' WITH NO REVERT;");
    await new sql.Request(tx).batch(`SET ROWCOUNT ${limit+1}; SET LOCK_TIMEOUT 30000;`);
    const result=await new sql.Request(tx).input('estate_model_pk',sql.BigInt,pinned.estate_model_pk).input('snapshot_id',sql.VarChar(71),pinned.snapshot_id).input('projection_id',sql.VarChar(71),pinned.projection_id).query(statement);
    const truncated=result.recordsets.some(r=>r.length>limit);
    const recordsets=result.recordsets.map(r=>r.slice(0,limit).map(normalizeSql));
    // Hash each result as a sorted multiset; row order without ORDER BY has no meaning.
    const resultDigest=hash(recordsets.map(r=>r.map(stable).sort()));
    await tx.rollback();begun=false;
    const body={snapshotId:pinned.snapshot_id,projectionDigest:pinned.projection_id,viewDefinitionDigest:await putBlob(Buffer.from(stable(definitions))),queryDigest:await putBlob(Buffer.from(statement)),resultDigest,resultObjectDigest:await putBlob(Buffer.from(stable(recordsets))),resultCanonicalization:'sorted-multiset-per-recordset.v1',rowLimit:limit,truncated,rowCounts:recordsets.map(r=>r.length),disposition:truncated?'READ_QUERY_TRUNCATED':'READ_QUERY_COMPLETE'};
    const proof=writeReceipt?await receipt('query',body):body;
    return {...proof,recordsets};
  }catch(e){if(begun)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
