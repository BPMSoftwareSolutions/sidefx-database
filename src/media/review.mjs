import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql,transaction,approveAndSelect} from './store.mjs';
const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1],id=get('--job');
if(!/^[a-f0-9]{64}$/.test(id??''))throw new Error('MEDIA_JOB_ID_REQUIRED');
const pool=await connect();
try{
 if(args.includes('--retry-transient')){
  const lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission'),file=path.join(lab,'outputs/estate-generated',id,'receipt.json');
  const raw=await fs.readFile(file),receipt=JSON.parse(raw);
  if(receipt.jobId!==id||receipt.status!=='HTTP_FAILED'||![429,500,502,503,504].includes(receipt.httpStatus))throw new Error('MEDIA_RETRY_NOT_A_CONFIRMED_TRANSIENT_HTTP_FAILURE');
  const row=(await pool.request().input('id',sql.VarChar(64),id).query("SELECT state,attempts FROM media.generation_request WHERE request_id=@id")).recordset[0];
  if(row?.state!=='UNCERTAIN'||row.attempts>=4)throw new Error('MEDIA_RETRY_LIMIT_OR_STATE');
  await fs.writeFile(path.join(path.dirname(file),'prior-job-attempt-'+row.attempts+'.json'),raw);
  await fs.writeFile(file,JSON.stringify({...receipt,retryAuthorized:true}));
  await pool.request().input('id',sql.VarChar(64),id).query("UPDATE media.generation_request SET state='QUEUED',failure_code=NULL,updated_at=SYSUTCDATETIME() WHERE request_id=@id AND state='UNCERTAIN'");
  console.log('RETRY_QUEUED_AFTER_CONFIRMED_HTTP_FAILURE');
 }else if(args.includes('--approve')){
  const reason=get('--reason');if(!reason?.trim())throw new Error('MEDIA_REVIEW_REASON_REQUIRED');
  await transaction(pool,async tx=>{
   const rows=(await new sql.Request(tx).input('id',sql.VarChar(64),id).query("SELECT b.binding_id FROM media.entity_visual_binding b JOIN media.asset_revision r ON r.revision_id=b.revision_id JOIN media.generation_request j ON j.request_id=r.generation_request_id WHERE j.request_id=@id AND j.state='REVIEW_REQUIRED'")).recordset;
   if(rows.length!==2)throw new Error('MEDIA_CARD_AND_DETAIL_REVIEW_REQUIRED');
   for(const row of rows)await approveAndSelect(tx,{bindingId:String(row.binding_id),reviewer:'Codex visual and source review',reason});
   await new sql.Request(tx).input('id',sql.VarChar(64),id).query("UPDATE media.generation_request SET state='COMPLETE',updated_at=SYSUTCDATETIME() WHERE request_id=@id");
  });console.log('REVIEWED_AND_SELECTED_CARD_AND_DETAIL');
 }else throw new Error('MEDIA_REVIEW_ACTION_REQUIRED');
}finally{await pool.close();}
