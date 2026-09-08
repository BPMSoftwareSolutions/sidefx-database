// Version shared presentation code without regenerating or changing source graphs.
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {connect,sql,transaction,importAsset,sha,getBlob} from './store.mjs';
import {currentSource,assertSource,readCatalog,saveCatalog} from './catalog.mjs';
const lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission'),pool=await connect();
try{
 const source=await currentSource(pool),catalog=await readCatalog(pool,'circuits',source);
 const bundles=[...new Set(catalog.circuits.filter(c=>c.scope==='DECLARED_SOURCE_TOPOLOGY').map(c=>c.bundleRevision))];
 if(!bundles.length)throw new Error('TOPOLOGY_RUNTIME_NO_SOURCE_BUNDLES');
 const files=[];
 for(const name of ['viewer.js','viewer.css']){
  const file='templates/estate-topology/'+name,bytes=await fs.readFile(path.join(lab,file));
  if(name.endsWith('.js'))new vm.Script(bytes.toString('utf8'),{filename:file});
  const originals=(await pool.request().input('bundles',sql.NVarChar(sql.MAX),JSON.stringify(bundles)).input('path',sql.NVarChar(800),file).query(`SELECT DISTINCT m.member_revision_id revision FROM OPENJSON(@bundles) j JOIN media.bundle_member m ON m.bundle_revision_id=j.value WHERE m.relative_path=@path`)).recordset;
  if(!originals.length)throw new Error('TOPOLOGY_RUNTIME_ORIGINAL_MISSING');
  const asset=await transaction(pool,tx=>importAsset(tx,{key:'website/topology-runtime/'+name,kind:'CIRCUIT_RUNTIME',bytes,mediaType:name.endsWith('.js')?'application/javascript':'text/css',origin:'DERIVED',parents:originals.map(r=>({revision:r.revision,role:'ORIGINAL'})),provenance:{recipe:'estate-topology-complete-trace/1',source,sourcePath:file,sourceSha256:sha(bytes),profile:'sidefx-estate-topology.v1'}}));
  await getBlob(pool,asset.blob);
  files.push({path:file,...asset,baseRevisions:originals.map(r=>r.revision)});
 }
 await assertSource(pool,source);
 const result=await saveCatalog(pool,'topology-runtime',source,{version:1,source,profile:'sidefx-estate-topology.v1',files});
 console.log(JSON.stringify({state:'TOPOLOGY_RUNTIME_STORED_IN_SQL',catalogRevision:result.revision,files:files.map(f=>({path:f.path,digest:f.blob}))}));
}catch(e){console.error('TOPOLOGY_RUNTIME_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
