import {sql,transaction,importAsset,getBlob,jsonBytes,sha} from './store.mjs';
export async function currentSource(db){
 return (await new sql.Request(db).query(`SELECT CONVERT(varchar(30),cm.estate_model_pk) estateModelPk,LOWER(CONVERT(varchar(64),s.snapshot_digest,2)) snapshotDigest,LOWER(CONVERT(varchar(64),m.mapping_manifest_digest,2)) mappingDigest FROM source.current_model cm JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk`)).recordset[0];
}
export async function assertSource(db,source){if(sha(jsonBytes(await currentSource(db)))!==sha(jsonBytes(source)))throw new Error('MEDIA_CURRENT_SOURCE_CHANGED');}
export async function saveCatalog(pool,name,source,value){
 await assertSource(pool,source);
 return transaction(pool,tx=>importAsset(tx,{key:`media-catalog/${source.estateModelPk}/${name}`,kind:'MEDIA_CATALOG',bytes:jsonBytes(value),mediaType:'application/json',provenance:{source,catalog:name}}));
}
export async function readCatalog(pool,name,source){
 const row=(await pool.request().input('id',sql.VarChar(64),sha(`media-catalog/${source.estateModelPk}/${name}`)).query(`SELECT TOP(1) LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest FROM media.asset_revision r WHERE r.asset_id=@id ORDER BY r.created_at DESC,r.revision_id`)).recordset[0];
 if(!row)throw new Error('MEDIA_CATALOG_MISSING:'+name);
 return JSON.parse((await getBlob(pool,row.digest)).bytes.toString('utf8'));
}
