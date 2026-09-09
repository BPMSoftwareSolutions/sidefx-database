import { connect, sql } from '../ingest/database.mjs';
import { pinModel } from './model-pin.mjs';
import { config, digest, hash, stable, receipt, putBlob } from '../core.mjs';

export function normalizeSql(value) {
  if(value instanceof Date)return value.toISOString();
  if(Buffer.isBuffer(value))return {sqlType:'varbinary',base64:value.toString('base64')};
  if(typeof value==='bigint')return value.toString();
  if(Array.isArray(value))return value.map(normalizeSql);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,normalizeSql(v)]));
  return value;
}

export async function query(statement,{writeReceipt=false,retainObjects=true,rowLimit,committed=false,input}={}) {
  if(typeof retainObjects!=='boolean')throw new Error('INVALID_QUERY_OBJECT_RETENTION');
  if(!retainObjects&&writeReceipt)throw new Error('QUERY_RECEIPT_REQUIRES_RETAINED_OBJECTS');
  if(typeof statement!=='string'||!statement.trim())throw new Error('QUERY_TEXT_REQUIRED');
  const inputText=input===undefined?null:JSON.stringify(input);
  if(input!==undefined&&typeof inputText!=='string')throw new Error('QUERY_INPUT_MUST_BE_JSON');
  const inputIdentity=inputText===null?{}:{inputDigest:hash(JSON.parse(inputText))};
  const cfg=await config(),limit=rowLimit??cfg.queryRowLimit;
  if(!Number.isSafeInteger(limit)||limit<1||limit>100000)throw new Error('INVALID_QUERY_ROW_LIMIT');
  const pool=await connect(),tx=new sql.Transaction(pool);let begun=false;
  try {
    await tx.begin();begun=true;
    if(committed){
      // Explicit inspection of tables committed so far; no selected-model claim.
      await new sql.Request(tx).batch("EXECUTE AS USER='sidefx_reader' WITH NO REVERT;");
      await new sql.Request(tx).batch('SET LOCK_TIMEOUT 30000;');
      const result=await new sql.Request(tx).input('input',sql.NVarChar(sql.MAX),inputText).query(statement);
      const truncated=result.recordsets.some(r=>r.length>limit),recordsets=result.recordsets.map(r=>r.slice(0,limit).map(normalizeSql));
      await tx.rollback();begun=false;
      return {inspectionState:'COMMITTED_TABLES',...inputIdentity,rowLimit:limit,truncated,rowCounts:recordsets.map(r=>r.length),recordsets};
    }
    const pinned = await pinModel(tx);
    const definitions = pinned.definitions;
    // SQL Server enforces the read boundary. NO REVERT prevents submitted SQL
    // from escaping impersonation. This dedicated pool is closed after the query.
    await new sql.Request(tx).batch("EXECUTE AS USER='sidefx_reader' WITH NO REVERT;");
    // Retention limits apply below, after SQL computes the complete result.
    // SET ROWCOUNT also truncates intermediate table-variable inserts and can
    // make aggregate coverage claims false while returning only one result row.
    await new sql.Request(tx).batch('SET LOCK_TIMEOUT 30000;');
    const result=await new sql.Request(tx).input('estate_model_pk',sql.BigInt,pinned.estate_model_pk).input('snapshot_id',sql.VarChar(71),pinned.snapshot_id).input('projection_id',sql.VarChar(71),pinned.projection_id).input('view_definition_digest',sql.VarChar(71),pinned.viewDefinitionDigest).input('input',sql.NVarChar(sql.MAX),inputText).query(statement);
    const truncated=result.recordsets.some(r=>r.length>limit);
    const recordsets=result.recordsets.map(r=>r.slice(0,limit).map(normalizeSql));
    // Hash each result as a sorted multiset; row order without ORDER BY has no meaning.
    const resultDigest=hash(recordsets.map(r=>r.map(stable).sort()));
    await tx.rollback();begun=false;
    const identify=retainObjects?putBlob:digest;
    const body={snapshotId:pinned.snapshot_id,projectionDigest:pinned.projection_id,viewDefinitionDigest:await identify(Buffer.from(stable(definitions))),queryDigest:await identify(Buffer.from(statement)),resultDigest,resultObjectDigest:await identify(Buffer.from(stable(recordsets))),resultCanonicalization:'sorted-multiset-per-recordset.v1',rowLimit:limit,truncated,rowCounts:recordsets.map(r=>r.length),disposition:truncated?'READ_QUERY_TRUNCATED':'READ_QUERY_COMPLETE'};
    if(!retainObjects)body.objectRetention='MEMORY_ONLY';
    Object.assign(body,inputIdentity);
    const proof=writeReceipt?await receipt('query',body):body;
    return {...proof,recordsets};
  }catch(e){if(begun)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
