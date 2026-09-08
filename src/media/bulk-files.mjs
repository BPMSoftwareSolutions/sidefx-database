import {sql,transaction,sha,jsonBytes} from './store.mjs';

/** Commit original file bytes in bounded batches. SQL hash checks validate every
 * byte payload; revisions use exactly the same recipe as importAsset(). */
export async function importFileBatch(pool,files,source){
 const prepared=files.map(({path,bytes,mediaType})=>{
  const asset=sha('content-lab/'+path),blob=sha(bytes),proofBytes=jsonBytes({sourcePath:path,sourceSha256:blob,sourceGeneration:source}),proof=sha(proofBytes);
  const revision=sha(jsonBytes({asset,blob,proof,origin:'IMPORTED',width:null,height:null,parents:[],definitionPk:null,requestId:null}));
  return {path,bytes,mediaType,asset,blob,proofBytes,proof,revision};
 });
 await transaction(pool,async tx=>{
  const table=new sql.Table('#media_files');table.create=true;
  for(const [name,type] of [['asset',sql.VarChar(64)],['logical_key',sql.NVarChar(900)],['revision',sql.VarChar(64)],['blob',sql.Binary(32)],['bytes',sql.VarBinary(sql.MAX)],['length',sql.BigInt],['media_type',sql.VarChar(100)],['proof',sql.Binary(32)],['proof_bytes',sql.VarBinary(sql.MAX)]])table.columns.add(name,type,{nullable:false});
  for(const r of prepared)table.rows.add(r.asset,'content-lab/'+r.path,r.revision,Buffer.from(r.blob,'hex'),r.bytes,r.bytes.length,r.mediaType,Buffer.from(r.proof,'hex'),r.proofBytes);
  await new sql.Request(tx).bulk(table);
  await new sql.Request(tx).query(`
   IF EXISTS(SELECT 1 FROM #media_files f JOIN media.blob b ON b.digest=f.blob WHERE b.byte_length<>f.length OR b.media_type<>f.media_type) THROW 51103,'MEDIA_EXISTING_BLOB_MISMATCH',1;
   ;WITH f AS(SELECT *,ROW_NUMBER() OVER(PARTITION BY blob ORDER BY asset) rn FROM #media_files)
   INSERT media.blob(digest,bytes,byte_length,media_type) SELECT blob,bytes,length,media_type FROM f WHERE rn=1 AND NOT EXISTS(SELECT 1 FROM media.blob b WITH(UPDLOCK,HOLDLOCK) WHERE b.digest=f.blob);
   ;WITH f AS(SELECT *,ROW_NUMBER() OVER(PARTITION BY proof ORDER BY asset) rn FROM #media_files)
   INSERT media.blob(digest,bytes,byte_length,media_type) SELECT proof,proof_bytes,DATALENGTH(proof_bytes),'application/json' FROM f WHERE rn=1 AND NOT EXISTS(SELECT 1 FROM media.blob b WITH(UPDLOCK,HOLDLOCK) WHERE b.digest=f.proof);
   ;WITH f AS(SELECT *,ROW_NUMBER() OVER(PARTITION BY asset ORDER BY asset) rn FROM #media_files)
   INSERT media.asset(asset_id,logical_key,kind) SELECT asset,logical_key,'CIRCUIT_SOURCE' FROM f WHERE rn=1 AND NOT EXISTS(SELECT 1 FROM media.asset a WITH(UPDLOCK,HOLDLOCK) WHERE a.asset_id=f.asset);
   INSERT media.asset_revision(revision_id,asset_id,blob_digest,provenance_digest,origin) SELECT revision,asset,blob,proof,'IMPORTED' FROM #media_files f WHERE NOT EXISTS(SELECT 1 FROM media.asset_revision a WITH(UPDLOCK,HOLDLOCK) WHERE a.revision_id=f.revision);
   IF EXISTS(SELECT 1 FROM #media_files f LEFT JOIN media.asset_revision r ON r.revision_id=f.revision AND r.blob_digest=f.blob AND r.provenance_digest=f.proof WHERE r.revision_id IS NULL) THROW 51107,'MEDIA_BULK_VERIFY_FAILED',1;
   DROP TABLE #media_files;
  `);
 });
 return prepared.map(({path,revision,blob,mediaType})=>({path,revision,blob,mediaType,width:null,height:null}));
}
