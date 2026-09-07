import { MODEL, commonColumns } from '../derive/model.mjs';
import { derive, validateCapabilityIntegrity } from '../derive/project.mjs';
import { initialize, requiredColumn } from './schema.mjs';
import { loadSnapshot } from '../snapshot/capture.mjs';
import { readBlob, digest, hash, stable, receipt } from '../core.mjs';
import { sql, connect } from './database.mjs';

const fieldType=(key,t)=>key==='capability_id'?sql.NVarChar(256):t==='d'?sql.VarChar(71):t==='b'?sql.Bit:t==='i'?sql.Int:t==='x'?sql.NVarChar(sql.MAX):sql.NVarChar(4000);
export async function bulk(tx,table,columns,rows) {
  let batch=[],size=0;
  async function flush() {
    if(!batch.length)return;
    const t=new sql.Table('sidefx_data.'+table);
    t.create=false;
    for(const [name,type,nullable=true] of columns)t.columns.add(name,type,{nullable});
    for(const row of batch)t.rows.add(...columns.map(([key])=>row[key]??null));
    await new sql.Request(tx).bulk(t,{checkConstraints:true});
    batch=[];size=0;
  }
  for(const row of rows) {
    batch.push(row);size+=Buffer.byteLength(stable(row));
    if(batch.length>=500||size>=4*1024*1024)await flush();
  }
  await flush();
}
export async function verifyDatabase(tx,snapshot,projection,{objects=true}={}) {
  const snapshotId=snapshot.snapshotId,id=projection.projectionDigest;
  const request=()=>new sql.Request(tx).input('snapshot',sql.VarChar(71),snapshotId).input('projection',sql.VarChar(71),id);
  const stored=(await request().query('SELECT manifest_json FROM sidefx_data.estate_snapshot WHERE snapshot_id=@snapshot')).recordset[0];
  if(!stored||hash(JSON.parse(stored.manifest_json))!==hash(snapshot))throw new Error('DATABASE_SNAPSHOT_MANIFEST_MISMATCH');
  const storedProjection=(await request().query('SELECT adapter_digest,rule_version,table_digests_json,catalog_digest FROM sidefx_data.projection_run WHERE projection_id=@projection')).recordset[0];
  if(!storedProjection||storedProjection.adapter_digest!==projection.adapterDigest||storedProjection.rule_version!==projection.ruleVersion||hash(JSON.parse(storedProjection.table_digests_json))!==hash(projection.tableDigests)||storedProjection.catalog_digest!==projection.catalogDigest)throw new Error('DATABASE_PROJECTION_MANIFEST_MISMATCH');
  const artifacts=(await request().query('SELECT * FROM sidefx_data.artifact WHERE snapshot_id=@snapshot')).recordset;
  const actual=new Map(artifacts.map(a=>[a.artifact_id,a]));
  if(actual.size!==snapshot.artifacts.length)throw new Error('DATABASE_ARTIFACT_COUNT_MISMATCH');
  for(const a of snapshot.artifacts){
    const v=actual.get(a.artifactId);
    if(!v||v.content_digest!==a.contentDigest||v.source_path!==a.sourcePath||v.source_class!==a.sourceClass||v.capability_id!==a.capabilityId||v.capsule_digest!==a.capsuleDigest||v.authority_digest!==a.authorityDigest||v.entry_id!==a.entryId||v.container_path!==a.containerPath||Number(v.byte_length)!==a.byteLength)throw new Error('DATABASE_ARTIFACT_LINEAGE_MISMATCH:'+a.artifactId);
  }
  const catalog=(await request().query('SELECT artifact_id,format,status,root_type FROM sidefx_data.artifact_catalog WHERE projection_id=@projection ORDER BY artifact_id')).recordset;
  if(hash(catalog)!==projection.catalogDigest)throw new Error('DATABASE_CATALOG_MISMATCH');
  for(const [table,fields] of Object.entries(MODEL)) {
    const columns=Object.keys({...commonColumns,...fields}).map(k=>'['+k+']').join(',');
    const values=(await request().query(`SELECT ${columns} FROM sidefx_data.[${table}] WHERE projection_id=@projection ORDER BY row_id`)).recordset;
    if(values.length!==projection.tableDigests[table].rowCount||hash(values)!==projection.tableDigests[table].digest)throw new Error('DATABASE_DERIVATION_MISMATCH:'+table);
  }
  let verifiedObjects=0;
  if(objects) {
    const ids=[...new Set(snapshot.artifacts.map(a=>a.contentDigest))].sort();
    for(let i=0;i<ids.length;i+=50) {
      const request=new sql.Request(tx).input('ids',sql.NVarChar(sql.MAX),JSON.stringify(ids.slice(i,i+50)));
      const values=(await request.query("SELECT content_digest,canonical_bytes,content_text,byte_length FROM sidefx_data.canonical_object WHERE content_digest IN(SELECT value FROM OPENJSON(@ids))")).recordset;
      if(values.length!==ids.slice(i,i+50).length)throw new Error('DATABASE_CANONICAL_OBJECT_MISSING');
      for(const v of values) {
        if(digest(v.canonical_bytes)!==v.content_digest||Number(v.byte_length)!==v.canonical_bytes.length)throw new Error('DATABASE_SOURCE_BYTES_MISMATCH:'+v.content_digest);
        let decoded=null;try{decoded=new TextDecoder('utf-8',{fatal:true}).decode(v.canonical_bytes);}catch{}
        if(v.content_text!==decoded)throw new Error('DATABASE_DERIVED_TEXT_MISMATCH:'+v.content_digest);
        verifiedObjects++;
      }
    }
  }
  const capabilityIntegrity=validateCapabilityIntegrity(snapshot,projection.rows);
  const entityCount=(await request().query('SELECT COUNT(*) AS n FROM sidefx_data.capability')).recordset[0].n;
  if(entityCount!==capabilityIntegrity.managedCapabilities)throw new Error('DATABASE_CAPABILITY_ENTITY_COUNT_MISMATCH');
  return {verifiedObjects,verifiedArtifacts:artifacts.length,verifiedTables:Object.keys(MODEL).length,verifiedRows:Object.values(projection.tableDigests).reduce((n,t)=>n+t.rowCount,0),capabilityIntegrity};
}
export async function ingest(snapshot,projection) {
  throw new Error('LEGACY_IMPORTER_RETIRED: use the normalized migration loader');
  snapshot??=await loadSnapshot();projection??=await derive(snapshot);
  if(projection.snapshotId!==snapshot.snapshotId)throw new Error('PROJECTION_SNAPSHOT_MISMATCH');
  validateCapabilityIntegrity(snapshot,projection.rows);
  const pool=await connect(),tx=new sql.Transaction(pool);let begun=false;
  const progress=message=>console.error(message);
  try {
    await tx.begin();begun=true;
    // Schema migration, entity replacement, and pointer selection commit together.
    await initialize({transaction:tx});
    await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx-database-ingestion',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51000,'Cannot lock observation workspace',1;");
    const previous=(await new sql.Request(tx).query('SELECT * FROM sidefx_data.current_pointer WITH(UPDLOCK,HOLDLOCK) WHERE pointer_id=1')).recordset[0]??null;
    const exists=(await new sql.Request(tx).input('id',sql.VarChar(71),projection.projectionDigest).query('SELECT projection_id FROM sidefx_data.projection_run WHERE projection_id=@id')).recordset.length>0;
    if(!exists) {
      const snapshotExists=(await new sql.Request(tx).input('id',sql.VarChar(71),snapshot.snapshotId).query('SELECT snapshot_id FROM sidefx_data.estate_snapshot WHERE snapshot_id=@id')).recordset.length>0;
      if(!snapshotExists) {
        progress('Loading exact source objects.');
        const known=new Set((await new sql.Request(tx).query('SELECT content_digest FROM sidefx_data.canonical_object')).recordset.map(x=>x.content_digest));
        const ids=[...new Set(snapshot.artifacts.map(a=>a.contentDigest))].sort();
        for(let i=0;i<ids.length;i+=50) {
          const objects=[];
          for(const id of ids.slice(i,i+50).filter(id=>!known.has(id))) {
            const bytes=await readBlob(id);let contentText=null;
            try{contentText=new TextDecoder('utf-8',{fatal:true}).decode(bytes);}catch{}
            objects.push({content_digest:id,byte_length:bytes.length,canonical_bytes:bytes,content_text:contentText});
          }
          await bulk(tx,'canonical_object',[['content_digest',sql.VarChar(71),false],['byte_length',sql.BigInt,false],['canonical_bytes',sql.VarBinary(sql.MAX),false],['content_text',sql.NVarChar(sql.MAX)]],objects);
        }
        await new sql.Request(tx).input('id',sql.VarChar(71),snapshot.snapshotId).input('estate',sql.VarChar(71),snapshot.estateManifestDigest).input('head',sql.VarChar(64),snapshot.sourceHead).input('status',sql.NVarChar(sql.MAX),snapshot.sourceStatus).input('caps',sql.Int,snapshot.verified.capabilityCount).input('count',sql.Int,snapshot.artifacts.length).input('manifest',sql.NVarChar(sql.MAX),JSON.stringify(snapshot)).query('INSERT sidefx_data.estate_snapshot(snapshot_id,estate_manifest_digest,source_head,source_status,capability_count,artifact_count,manifest_json) VALUES(@id,@estate,@head,@status,@caps,@count,@manifest)');
        const artifactRows=snapshot.artifacts.map(a=>({snapshot_id:snapshot.snapshotId,artifact_id:a.artifactId,content_digest:a.contentDigest,source_path:a.sourcePath,source_class:a.sourceClass,capability_id:a.capabilityId,capsule_digest:a.capsuleDigest,authority_digest:a.authorityDigest,entry_id:a.entryId,container_path:a.containerPath,byte_length:a.byteLength}));
        await bulk(tx,'artifact',[['snapshot_id',sql.VarChar(71),false],['artifact_id',sql.VarChar(71),false],['content_digest',sql.VarChar(71),false],['source_path',sql.NVarChar(2048),false],['source_class',sql.VarChar(40),false],['capability_id',sql.NVarChar(256)],['capsule_digest',sql.VarChar(71)],['authority_digest',sql.VarChar(71)],['entry_id',sql.NVarChar(2048)],['container_path',sql.NVarChar(2048)],['byte_length',sql.BigInt,false]],artifactRows);
      }
      await new sql.Request(tx).input('id',sql.VarChar(71),projection.projectionDigest).input('snapshot',sql.VarChar(71),snapshot.snapshotId).input('adapter',sql.VarChar(71),projection.adapterDigest).input('rule',sql.VarChar(128),projection.ruleVersion).input('tables',sql.NVarChar(sql.MAX),stable(projection.tableDigests)).input('catalog',sql.VarChar(71),projection.catalogDigest).query('INSERT sidefx_data.projection_run(projection_id,snapshot_id,adapter_digest,rule_version,table_digests_json,catalog_digest) VALUES(@id,@snapshot,@adapter,@rule,@tables,@catalog)');
      const bound=values=>values.map(r=>({projection_id:projection.projectionDigest,snapshot_id:snapshot.snapshotId,...r}));
      await bulk(tx,'artifact_catalog',[['projection_id',sql.VarChar(71),false],['snapshot_id',sql.VarChar(71),false],['artifact_id',sql.VarChar(71),false],['format',sql.VarChar(16),false],['status',sql.VarChar(32),false],['root_type',sql.NVarChar(2048)]],bound(projection.catalog));
      const prior=(await new sql.Request(tx).input('snapshot',sql.VarChar(71),snapshot.snapshotId).input('new',sql.VarChar(71),projection.projectionDigest).query('SELECT TOP(1) projection_id,table_digests_json FROM sidefx_data.projection_run WHERE snapshot_id=@snapshot AND projection_id<>@new ORDER BY loaded_at DESC')).recordset[0];
      const priorDigests=prior?JSON.parse(prior.table_digests_json):{};
      for(const [table,fields] of Object.entries(MODEL)) {
        if(table==='capability')continue; // Current entities are replaced after all observations exist.
        if(prior && hash(priorDigests[table]??null)===hash(projection.tableDigests[table])) {
          progress(`Reusing identical ${table} observations from the same snapshot.`);
          const names=Object.keys({...commonColumns,...fields}).map(k=>'['+k+']').join(',');
          await new sql.Request(tx).input('old',sql.VarChar(71),prior.projection_id).input('new',sql.VarChar(71),projection.projectionDigest).input('snapshot',sql.VarChar(71),snapshot.snapshotId).query(`INSERT sidefx_data.[${table}](projection_id,snapshot_id,${names}) SELECT @new,@snapshot,${names} FROM sidefx_data.[${table}] WHERE projection_id=@old`);
          continue;
        }
        progress(`Loading ${table}: ${projection.rows[table].length} observations.`);
        await bulk(tx,table,[['projection_id',sql.VarChar(71),false],['snapshot_id',sql.VarChar(71),false],...Object.entries({...commonColumns,...fields}).map(([k,t])=>[k,fieldType(k,t),!requiredColumn(table,k)])],bound(projection.rows[table]));
      }
    }
    await new sql.Request(tx).query('DELETE FROM sidefx_data.capability');
    await bulk(tx,'capability',[['projection_id',sql.VarChar(71),false],['snapshot_id',sql.VarChar(71),false],...Object.entries({...commonColumns,...MODEL.capability}).map(([k,t])=>[k,fieldType(k,t),!requiredColumn('capability',k)])],projection.rows.capability.map(r=>({projection_id:projection.projectionDigest,snapshot_id:snapshot.snapshotId,...r})));
    progress('Verifying SQL rows, source bytes, and provenance before selecting the snapshot.');
    const proof=await verifyDatabase(tx,snapshot,projection);
    await new sql.Request(tx).input('snapshot',sql.VarChar(71),snapshot.snapshotId).input('projection',sql.VarChar(71),projection.projectionDigest).query('IF EXISTS(SELECT 1 FROM sidefx_data.current_pointer WHERE pointer_id=1) UPDATE sidefx_data.current_pointer SET snapshot_id=@snapshot,projection_id=@projection WHERE pointer_id=1; ELSE INSERT sidefx_data.current_pointer VALUES(1,@snapshot,@projection);');
    await tx.commit();begun=false;
    return await receipt('ingest',{snapshotId:snapshot.snapshotId,projectionDigest:projection.projectionDigest,previousSnapshotId:previous?.snapshot_id??null,disposition:exists?'EXISTING_PROJECTION_VERIFIED':'SQL_OBSERVATION_LOADED',...proof});
  } catch(e){if(begun)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
