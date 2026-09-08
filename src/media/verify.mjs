// Exercise real SQL constraints inside rolled-back transactions.
import assert from 'node:assert/strict';
import {connect,sql,getBlob,sha} from './store.mjs';
const pool=await connect();
async function rejected(name,statement,expected){
 const tx=new sql.Transaction(pool);await tx.begin();let rolledBack=false;tx.on('rollback',()=>{rolledBack=true;});
 try{await assert.rejects(new sql.Request(tx).query(statement),e=>e.number===expected);console.log('PASS '+name);}
 finally{if(!rolledBack)await tx.rollback();}
}
try{
 await rejected('bytes must match their SHA-256',"INSERT media.blob(digest,bytes,byte_length,media_type) VALUES(0x0000000000000000000000000000000000000000000000000000000000000000,0x414243,3,'application/octet-stream')",547);
 await rejected('original bytes cannot be changed','UPDATE TOP(1) media.blob SET bytes=bytes',51101);
 await rejected('revision identity cannot be edited','UPDATE TOP(1) media.asset_revision SET origin=origin',51101);
 await rejected('semantic subject cannot be rebound','UPDATE TOP(1) media.subject SET object_pk=object_pk',51101);
 await rejected('source lineage cannot be removed','DELETE TOP(1) FROM media.asset_source',51101);
 await rejected('bundle closure cannot be removed','DELETE TOP(1) FROM media.bundle_member',51101);
 await rejected('direct cross-entity binding fails',`DECLARE @r bigint,@v varchar(64);SELECT TOP(1) @v=revision_id FROM media.asset_semantic_source WHERE role='SUBJECT';SELECT TOP(1) @r=r.requirement_id FROM media.visual_requirement r WHERE NOT EXISTS(SELECT 1 FROM media.asset_semantic_source s WHERE s.revision_id=@v AND s.definition_pk=r.definition_pk AND s.role='SUBJECT');INSERT media.entity_visual_binding(requirement_id,revision_id,alt_text) VALUES(@r,@v,'invalid cross-entity test');`,51104);
 await rejected('review cannot approve a different revision',`DECLARE @b bigint,@v varchar(64);SELECT TOP(1) @b=b.binding_id,@v=a.revision_id FROM media.entity_visual_binding b CROSS JOIN media.asset_revision a WHERE a.revision_id<>b.revision_id;INSERT media.asset_review(binding_id,revision_id,decision,reviewer,reason) VALUES(@b,@v,'APPROVED','SQL integrity test','rolled back');`,51106);
 await rejected('selection cannot use an unrelated review',`DECLARE @r bigint,@bad bigint;SELECT TOP(1) @r=x.requirement_id,@bad=y.review_id FROM media.visual_selection x JOIN media.asset_review y ON y.binding_id<>x.binding_id;UPDATE media.visual_selection SET review_id=@bad WHERE requirement_id=@r;`,51102);
 await rejected('generation source cannot be replaced','UPDATE TOP(1) media.generation_request SET model=model',51101);
 const originals=(await pool.request().query(`SELECT DISTINCT LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest FROM media.visual_selection x JOIN media.entity_visual_binding b ON b.binding_id=x.binding_id JOIN media.asset_source s ON s.revision_id=b.revision_id AND s.role='ORIGINAL' JOIN media.asset_revision r ON r.revision_id=s.parent_revision_id`)).recordset;
 assert.ok(originals.length>=10);for(const {digest} of originals){const row=await getBlob(pool,digest);assert.equal(sha(row.bytes),digest);}
 console.log('PASS '+originals.length+' selected originals read back byte-for-byte from SQL');
 const rows=(await pool.request().query(`SELECT (SELECT COUNT(*) FROM media.blob) blobs,(SELECT COUNT(*) FROM media.asset_revision) revisions,(SELECT COUNT(*) FROM media.visual_selection) selections,(SELECT COUNT(*) FROM media.generation_request WHERE state='QUEUED') queued,(SELECT COUNT(*) FROM media.generation_request WHERE state='REVIEW_REQUIRED') awaitingReview`)).recordset;
 console.log(JSON.stringify({state:'SQL_MEDIA_INTEGRITY_VERIFIED',...rows[0]}));
}catch(e){console.error('MEDIA_VERIFY_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
