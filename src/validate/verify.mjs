import { derive } from '../derive/project.mjs';
import { loadSnapshot,verifySnapshot } from '../snapshot/capture.mjs';
import { connect,sql } from '../ingest/database.mjs';
import { verifyDatabase } from '../ingest/load.mjs';
import { hash,readBlob,resolvePointer,receipt } from '../core.mjs';
import { parseFeature,featureScenarios } from '../derive/feature.mjs';

export async function verify() {
  const pool=await connect(),tx=new sql.Transaction(pool);let begun=false;
  try {
    await tx.begin();begun=true;
    const pinned=(await new sql.Request(tx).query('SELECT snapshot_id,projection_id FROM sidefx_data.current_pointer WITH(HOLDLOCK) WHERE pointer_id=1')).recordset[0];
    if(!pinned)throw new Error('NO_LOADED_SNAPSHOT');
    const snapshot=await loadSnapshot(pinned.snapshot_id);
    const local=await verifySnapshot(snapshot);
    console.error('Rebuilding relational observations from frozen source bytes.');
    const rebuilt=await derive(snapshot,{persist:false});
    if(rebuilt.projectionDigest!==pinned.projection_id)throw new Error('ADAPTER_CHANGED_REINGEST_REQUIRED');
    const artifacts=new Map(snapshot.artifacts.map(a=>[a.artifactId,a]));
    const docs=new Map(),features=new Map();let checkedPointers=0;
    for(const [table,rows] of Object.entries(rebuilt.rows))for(const row of rows) {
      if(table==='extraction_issue')continue;
      const a=artifacts.get(row.artifact_id);if(!a)throw new Error('ORPHAN_PROVENANCE_ROW');
      let value;
      if(row.pointer_kind==='JSON_POINTER') {
        if(!docs.has(a.contentDigest))docs.set(a.contentDigest,JSON.parse((await readBlob(a.contentDigest)).toString('utf8')));
        value=resolvePointer(docs.get(a.contentDigest),row.source_pointer);
      }else if(row.pointer_kind==='LINE') {
        if(!features.has(a.contentDigest)) {
          const f=parseFeature((await readBlob(a.contentDigest)).toString('utf8')).feature;
          features.set(a.contentDigest,new Map([[`line:${f.location.line}`,f],...featureScenarios(f).map(({scenario:s})=>[`line:${s.location.line}`,s])]));
        }
        value=features.get(a.contentDigest).get(row.source_pointer);
      }
      if(value===undefined||hash(value)!==row.object_digest)throw new Error('SOURCE_POINTER_VALUE_MISMATCH:'+table+':'+row.row_id);
      checkedPointers++;
    }
    console.error('Comparing rebuilt rows and original bytes with SQL storage.');
    const database=await verifyDatabase(tx,snapshot,rebuilt);
    await tx.rollback();begun=false;
    return receipt('verify',{snapshotId:snapshot.snapshotId,projectionDigest:rebuilt.projectionDigest,adapterDigest:rebuilt.adapterDigest,disposition:'REBUILD_AND_SQL_EQUIVALENCE_VERIFIED',localObjectCount:local.verifiedObjects,checkedPointers,...database});
  }catch(e){if(begun)await tx.rollback().catch(()=>{});throw e;}finally{await pool.close();}
}
