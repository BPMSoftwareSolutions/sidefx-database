import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql} from './store.mjs';
import {ROOT} from '../core.mjs';
import {query} from '../query/run.mjs';

export async function inventory(){
 const pool=await connect();
 try {
  const tx=new sql.Transaction(pool);await tx.begin();
  try {
   await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Shared',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51100,'MEDIA_MODEL_LOCK',1;");
   const source=(await new sql.Request(tx).query(`SELECT CONVERT(varchar(30),cm.estate_model_pk) estateModelPk,LOWER(CONVERT(varchar(64),s.snapshot_digest,2)) snapshotDigest,LOWER(CONVERT(varchar(64),m.mapping_manifest_digest,2)) mappingDigest FROM source.current_model cm WITH(HOLDLOCK) JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk`)).recordset[0];
   const rows=(await new sql.Request(tx).query(`SELECT CONVERT(varchar(30),s.definition_pk) definitionPk,CONVERT(varchar(30),s.object_pk) objectPk,s.object_kind kind,LOWER(CONVERT(varchar(64),s.definition_digest,2)) definitionDigest,o.declared_id entityId,n.namespace_id namespaceId,n.namespace_kind namespaceKind,c.content_bytes,
    CONVERT(bit,CASE WHEN ec.capability_pk IS NULL THEN 0 ELSE 1 END) managed
    FROM media.subject s JOIN model.semantic_object o ON o.semantic_object_pk=s.object_pk JOIN model.identity_namespace n ON n.namespace_pk=o.namespace_pk
    JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=s.definition_pk JOIN source.content_object c ON c.content_object_pk=d.canonical_content_pk
    JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=s.definition_pk JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk
    LEFT JOIN model.capability_version cv ON cv.semantic_object_definition_pk=s.definition_pk LEFT JOIN model.estate_capability ec ON ec.capability_version_pk=cv.capability_version_pk AND ec.estate_model_pk=cm.estate_model_pk
    ORDER BY s.object_kind,o.declared_id,s.definition_pk`)).recordset;
   const subjects=rows.map(({content_bytes,...r})=>({...r,definition:JSON.parse(content_bytes.toString('utf8'))}));
   const requirements=(await new sql.Request(tx).query(`SELECT CONVERT(varchar(30),requirement_id) requirementId,CONVERT(varchar(30),definition_pk) definitionPk,purpose,state FROM media.v_requirement WHERE is_current=1`)).recordset;
   const lineage=(await new sql.Request(tx).query(`SELECT DISTINCT CONVERT(varchar(30),semantic_object_definition_pk) definitionPk,LOWER(CONVERT(varchar(64),capsule_digest,2)) capsuleDigest FROM sidefx.v_definition_lineage WHERE capsule_digest IS NOT NULL`)).recordset;
   await tx.commit();
   return {source,subjects,requirements,lineage,observedAt:new Date().toISOString()};
  }catch(e){await tx.rollback().catch(()=>{});throw e;}
 }finally{await pool.close();}
}
if(process.argv[1]?.endsWith('inventory.mjs')){
 try{
  const data=await inventory(),dest=path.join(ROOT,'data/media');await fs.mkdir(dest,{recursive:true});await fs.writeFile(path.join(dest,'inventory.json'),JSON.stringify(data,null,2)+'\n');
  // Extend the original inspection result with correctly typed capability identities.
  const statement=await fs.readFile(path.join(ROOT,'sql/diagnostics/website-visual-inventory.sql'),'utf8');
  const extra=`\nSELECT c.capability_id,ns.namespace_id,c.semantic_object_pk,cv.semantic_object_definition_pk,CAST(NULL AS varchar(100)) definition_profile,cv.name,cv.intent,cv.outcome FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk JOIN model.identity_namespace ns ON ns.namespace_pk=c.namespace_pk JOIN model.capability_version cv ON cv.capability_version_pk=ec.capability_version_pk WHERE ec.estate_model_pk=@estate_model_pk ORDER BY c.capability_id;`;
  const publication=await query(statement+extra,{rowLimit:5000});
  await fs.writeFile(path.join(dest,'website-inventory.json'),JSON.stringify(publication,null,2)+'\n');
  console.log(JSON.stringify({subjects:data.subjects.length,requirements:data.requirements.length,publicationCounts:publication.rowCounts,source:data.source}));
 }catch(e){console.error('MEDIA_INVENTORY_FAILED',e.number??e.code??e.message);process.exitCode=1;}
}
