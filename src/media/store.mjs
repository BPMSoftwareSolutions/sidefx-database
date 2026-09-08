import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { connect, sql } from '../ingest/database.mjs';
import { ROOT, stable } from '../core.mjs';

export const sha = bytes => createHash('sha256').update(bytes).digest('hex');
export const jsonBytes = value => Buffer.from(stable(value));
const bin = value => Buffer.from(value.replace(/^sha256:/,''),'hex');
export { connect, sql };

export async function migrateMedia(version='005-media-registry') {
 if(!['005-media-registry','006-media-integrity'].includes(version))throw new Error('MEDIA_UNKNOWN_MIGRATION');
 const file=await fs.readFile(path.join(ROOT,'sql/migrations',version+'.sql'),'utf8'),digest=sha(file);
 const pool=await connect(),tx=new sql.Transaction(pool);let active=false;
 try {
  await tx.begin();active=true;
  await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:media-migration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51100,'MEDIA_MIGRATION_LOCK',1;");
  const exists=(await new sql.Request(tx).query("SELECT OBJECT_ID('media.schema_version') id")).recordset[0].id;
  if(exists){
   const prior=(await new sql.Request(tx).input('version',sql.VarChar(100),version).query("SELECT LOWER(CONVERT(varchar(64),digest,2)) digest FROM media.schema_version WHERE version=@version")).recordset[0];
   if(prior){
    if(prior.digest!==digest)throw new Error('MEDIA_MIGRATION_DIGEST_MISMATCH');
    await tx.commit();active=false;return {state:'ALREADY_INSTALLED',version,digest};
   }
  }
  await new sql.Request(tx).query("IF SCHEMA_ID('media') IS NULL EXEC('CREATE SCHEMA media AUTHORIZATION dbo');");
  for(const batch of file.split(/^GO\s*$/m).filter(x=>x.trim()))await new sql.Request(tx).batch(batch);
  await new sql.Request(tx).input('version',sql.VarChar(100),version).input('digest',sql.Binary(32),bin(digest)).query("INSERT media.schema_version(version,digest) VALUES(@version,@digest)");
  await tx.commit();active=false;return {state:'INSTALLED',version,digest};
 } finally {if(active)await tx.rollback().catch(()=>{});await pool.close();}
}

export async function transaction(pool,fn){
 const tx=new sql.Transaction(pool);await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
 try{const result=await fn(tx);await tx.commit();return result;}catch(e){await tx.rollback().catch(()=>{});throw e;}
}
export async function putBlob(db,bytes,mediaType){
 if(!Buffer.isBuffer(bytes)||!bytes.length)throw new Error('MEDIA_BYTES_REQUIRED');
 const digest=sha(bytes);
 await new sql.Request(db).input('digest',sql.Binary(32),bin(digest)).input('bytes',sql.VarBinary(sql.MAX),bytes).input('length',sql.BigInt,bytes.length).input('type',sql.VarChar(100),mediaType).query(`
 IF NOT EXISTS(SELECT 1 FROM media.blob WITH(UPDLOCK,HOLDLOCK) WHERE digest=@digest)
 INSERT media.blob(digest,bytes,byte_length,media_type) VALUES(@digest,@bytes,@length,@type);
 ELSE IF EXISTS(SELECT 1 FROM media.blob WHERE digest=@digest AND (byte_length<>@length OR media_type<>@type)) THROW 51103,'MEDIA_EXISTING_BLOB_MISMATCH',1;`);
 return digest;
}
export async function getBlob(db,digest){
 const row=(await new sql.Request(db).input('digest',sql.Binary(32),bin(digest)).query('SELECT bytes,media_type,byte_length FROM media.blob WHERE digest=@digest')).recordset[0];
 if(!row||sha(row.bytes)!==digest.replace(/^sha256:/,''))throw new Error('MEDIA_BLOB_MISSING_OR_CORRUPT');
 return row;
}
export async function importAsset(db,{key,kind='SOURCE',bytes,mediaType,origin='IMPORTED',provenance={},width=null,height=null,parents=[],definitionPk=null,requestId=null}){
 const blob=await putBlob(db,bytes,mediaType),proof=await putBlob(db,jsonBytes(provenance),'application/json');
 const asset=sha(key),revision=sha(jsonBytes({asset,blob,proof,origin,width,height,parents,definitionPk,requestId}));
 await new sql.Request(db).input('asset',sql.VarChar(64),asset).input('key',sql.NVarChar(900),key).input('kind',sql.VarChar(40),kind).query(`IF NOT EXISTS(SELECT 1 FROM media.asset WITH(UPDLOCK,HOLDLOCK) WHERE asset_id=@asset) INSERT media.asset(asset_id,logical_key,kind) VALUES(@asset,@key,@kind);`);
 await new sql.Request(db).input('id',sql.VarChar(64),revision).input('asset',sql.VarChar(64),asset).input('blob',sql.Binary(32),bin(blob)).input('proof',sql.Binary(32),bin(proof)).input('origin',sql.VarChar(20),origin).input('width',sql.Int,width).input('height',sql.Int,height).input('job',sql.VarChar(64),requestId).query(`IF NOT EXISTS(SELECT 1 FROM media.asset_revision WITH(UPDLOCK,HOLDLOCK) WHERE revision_id=@id) INSERT media.asset_revision(revision_id,asset_id,blob_digest,provenance_digest,origin,width,height,generation_request_id) VALUES(@id,@asset,@blob,@proof,@origin,@width,@height,@job);`);
 for(const parent of parents)await new sql.Request(db).input('id',sql.VarChar(64),revision).input('parent',sql.VarChar(64),parent.revision).input('role',sql.VarChar(40),parent.role).query(`IF NOT EXISTS(SELECT 1 FROM media.asset_source WHERE revision_id=@id AND parent_revision_id=@parent AND role=@role) INSERT media.asset_source VALUES(@id,@parent,@role)`);
 if(definitionPk)await new sql.Request(db).input('id',sql.VarChar(64),revision).input('definition',sql.BigInt,definitionPk).query(`IF NOT EXISTS(SELECT 1 FROM media.asset_semantic_source WHERE revision_id=@id AND definition_pk=@definition AND role='SUBJECT') INSERT media.asset_semantic_source VALUES(@id,@definition,'SUBJECT')`);
 return {revision,blob,mediaType,width,height};
}
export async function bindAsset(db,{requirementId,revision,altText,presentation={}}){
 const row=(await new sql.Request(db).input('r',sql.BigInt,requirementId).input('v',sql.VarChar(64),revision).input('alt',sql.NVarChar(2000),altText).input('presentation',sql.NVarChar(sql.MAX),JSON.stringify(presentation)).query(`
 IF NOT EXISTS(SELECT 1 FROM media.asset_semantic_source a JOIN media.visual_requirement r ON r.definition_pk=a.definition_pk WHERE r.requirement_id=@r AND a.revision_id=@v AND a.role='SUBJECT') THROW 51104,'MEDIA_SUBJECT_SOURCE_REQUIRED',1;
 IF NOT EXISTS(SELECT 1 FROM media.entity_visual_binding WITH(UPDLOCK,HOLDLOCK) WHERE requirement_id=@r AND revision_id=@v)
 INSERT media.entity_visual_binding(requirement_id,revision_id,alt_text,presentation_json) VALUES(@r,@v,@alt,@presentation);
 SELECT binding_id FROM media.entity_visual_binding WHERE requirement_id=@r AND revision_id=@v;`)).recordset[0];
 return String(row.binding_id);
}
export async function approveAndSelect(db,{bindingId,reviewer,reason}){
 // Exact binding review is append-only. Selection plus history commit atomically.
 return (await new sql.Request(db).input('binding',sql.BigInt,bindingId).input('reviewer',sql.NVarChar(200),reviewer).input('reason',sql.NVarChar(2000),reason).query(`
 DECLARE @r bigint,@v varchar(64),@review bigint;
 SELECT @r=requirement_id,@v=revision_id FROM media.entity_visual_binding WHERE binding_id=@binding;
 IF @r IS NULL THROW 51105,'MEDIA_BINDING_NOT_FOUND',1;
 IF EXISTS(SELECT 1 FROM media.visual_selection WHERE requirement_id=@r AND binding_id=@binding) BEGIN SELECT binding_id FROM media.visual_selection WHERE requirement_id=@r; RETURN; END;
 INSERT media.asset_review(revision_id,binding_id,decision,reviewer,reason) VALUES(@v,@binding,'APPROVED',@reviewer,@reason); SET @review=SCOPE_IDENTITY();
 IF EXISTS(SELECT 1 FROM media.visual_selection WITH(UPDLOCK,HOLDLOCK) WHERE requirement_id=@r) UPDATE media.visual_selection SET binding_id=@binding,review_id=@review,selected_at=SYSUTCDATETIME() WHERE requirement_id=@r;
 ELSE INSERT media.visual_selection(requirement_id,binding_id,review_id) VALUES(@r,@binding,@review);
 SELECT @binding binding_id;`)).recordset[0];
}
export async function seedRequirements(pool){
 return transaction(pool,async tx=>(await new sql.Request(tx).query(`
 INSERT media.subject(definition_pk,object_pk,object_kind,definition_digest)
 SELECT d.semantic_object_definition_pk,d.semantic_object_pk,d.object_kind,d.definition_digest
 FROM model.semantic_object_definition d JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=d.semantic_object_definition_pk
 JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk
 WHERE d.object_kind IN('CAPABILITY','SCENARIO','MECHANIC','PROVIDER','BLUEPRINT') AND NOT EXISTS(SELECT 1 FROM media.subject s WHERE s.definition_pk=d.semantic_object_definition_pk);
 INSERT media.visual_requirement(definition_pk,purpose)
 SELECT s.definition_pk,p.purpose FROM media.subject s CROSS JOIN(VALUES('DETAIL'),('CARD')) p(purpose)
 WHERE s.object_kind IN('CAPABILITY','SCENARIO','MECHANIC','PROVIDER') AND NOT EXISTS(SELECT 1 FROM media.visual_requirement r WHERE r.definition_pk=s.definition_pk AND r.purpose=p.purpose AND r.locale='en' AND r.variant='default');
 INSERT media.visual_requirement(definition_pk,purpose)
 SELECT s.definition_pk,'CIRCUIT' FROM media.subject s WHERE s.object_kind IN('CAPABILITY','SCENARIO','BLUEPRINT') AND NOT EXISTS(SELECT 1 FROM media.visual_requirement r WHERE r.definition_pk=s.definition_pk AND r.purpose='CIRCUIT');
 SELECT object_kind,purpose,state,COUNT(*) n FROM media.v_requirement WHERE is_current=1 GROUP BY object_kind,purpose,state ORDER BY object_kind,purpose,state;`)).recordset);
}
