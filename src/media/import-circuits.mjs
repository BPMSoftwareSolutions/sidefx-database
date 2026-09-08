import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql,transaction,importAsset,bindAsset,approveAndSelect,sha,jsonBytes,getBlob} from './store.mjs';
import {ROOT} from '../core.mjs';
import {importFileBatch} from './bulk-files.mjs';
import {assertSource,readCatalog} from './catalog.mjs';
const lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission');
const indexPath=path.resolve(lab,process.env.SIDEFX_CIRCUIT_INDEX??'outputs/estate-circuits/index.json');
if(!indexPath.startsWith(lab+path.sep))throw new Error('MEDIA_CIRCUIT_INDEX_OUTSIDE_LAB');
const index=JSON.parse(await fs.readFile(indexPath,'utf8'));
const scope=index.profile??'DECLARED_SOURCE_BOUNDARY';
const compiler=scope==='DECLARED_SOURCE_TOPOLOGY'?'content-lab-topology':'content-lab-scl';
const inventory=JSON.parse(await fs.readFile(path.join(ROOT,'data/media/inventory.json'),'utf8'));
if(sha(jsonBytes(index.source))!==sha(jsonBytes(inventory.source)))throw new Error('MEDIA_CIRCUIT_GENERATION_MISMATCH');
const pool=await connect(),cache=new Map(),result={source:index.source,circuits:[],gaps:index.gaps,files:{}};
const mime=f=>({'.json':'application/json','.js':'application/javascript','.py':'text/x-python','.css':'text/css','.html':'text/html','.svg':'image/svg+xml','.scl':'text/plain','.txt':'text/plain','.webp':'image/webp','.jpg':'image/jpeg','.png':'image/png'})[path.extname(f)]??'application/octet-stream';
async function fileAsset(tx,file){
 if(cache.has(file))return cache.get(file);
 const resolved=path.resolve(lab,file);if(!resolved.startsWith(lab+path.sep))throw new Error('MEDIA_SOURCE_PATH_ESCAPE');
 const bytes=await fs.readFile(resolved);if(sha(bytes)!==index.files[file]?.sha256)throw new Error('MEDIA_CIRCUIT_FILE_CHANGED');
 const imported=await importAsset(tx,{key:'content-lab/'+file,kind:'CIRCUIT_SOURCE',bytes,mediaType:mime(file),provenance:{sourcePath:file,sourceSha256:sha(bytes),sourceGeneration:index.source}});
 cache.set(file,imported);result.files[file]=imported;return imported;
}
async function members(tx,bundle,files){
 const values=files.map(f=>({path:f,revision:cache.get(f).revision}));
 await new sql.Request(tx).input('id',sql.VarChar(64),bundle.revision).input('rows',sql.NVarChar(sql.MAX),JSON.stringify(values)).query(`INSERT media.bundle_member(bundle_revision_id,relative_path,member_revision_id) SELECT @id,j.path,j.revision FROM OPENJSON(@rows) WITH(path nvarchar(800),revision varchar(64)) j WHERE NOT EXISTS(SELECT 1 FROM media.bundle_member m WHERE m.bundle_revision_id=@id AND m.relative_path=j.path);`);
}
async function select(tx,definitionPk,bundle,label){
  const row=(await new sql.Request(tx).input('d',sql.BigInt,definitionPk).query(`SELECT CONVERT(varchar(30),r.requirement_id) id,x.binding_id selected,a.kind selectedKind FROM media.visual_requirement r LEFT JOIN media.visual_selection x ON x.requirement_id=r.requirement_id LEFT JOIN media.entity_visual_binding b ON b.binding_id=x.binding_id LEFT JOIN media.asset_revision v ON v.revision_id=b.revision_id LEFT JOIN media.asset a ON a.asset_id=v.asset_id WHERE r.definition_pk=@d AND r.purpose='CIRCUIT' AND r.locale='en' AND r.variant='default'`)).recordset[0];
 if(!row)throw new Error('MEDIA_CIRCUIT_REQUIREMENT_ABSENT');
 const bindingId=await bindAsset(tx,{requirementId:row.id,revision:bundle.revision,altText:label,presentation:{scope,playback:scope==='DECLARED_SOURCE_TOPOLOGY'?'DECLARED_ROUTE_INSPECTION':'ONLY_AUTHORED_TRACES'}});
 if(scope==='DECLARED_SOURCE_TOPOLOGY'||!row.selected||row.selectedKind==='CIRCUIT_BUNDLE')await approveAndSelect(tx,{bindingId,reviewer:'SideFX compiler, graph coverage and visual review',reason:'Exact source lineage and ownership match. Typed source relations, node/route coverage and rendered geometry verified. Declared route inspection does not establish execution testimony.'});
}
try{
 await assertSource(pool,index.source);
 if(process.argv.includes('--merge-current')){
  const prior=await readCatalog(pool,'circuits',index.source),updated=new Set(index.capabilities.map(c=>c.definitionPk));
  if(sha(jsonBytes(prior.source))!==sha(jsonBytes(index.source)))throw new Error('MEDIA_CIRCUIT_MERGE_SOURCE_MISMATCH');
  result.circuits=prior.circuits.filter(c=>!updated.has(c.capabilityDefinitionPk));result.files={...prior.files};
 }
 const allFiles=Object.keys(index.files);
 for(let start=0;start<allFiles.length;start+=32){
  const files=[];
  for(const f of allFiles.slice(start,start+32)){
   const resolved=path.resolve(lab,f);if(!resolved.startsWith(lab+path.sep))throw new Error('MEDIA_SOURCE_PATH_ESCAPE');
   const bytes=await fs.readFile(resolved);if(sha(bytes)!==index.files[f].sha256)throw new Error('MEDIA_CIRCUIT_FILE_CHANGED');
   files.push({path:f,bytes,mediaType:mime(f)});
  }
  for(const {path:f,...asset} of await importFileBatch(pool,files,index.source)){cache.set(f,asset);result.files[f]=asset;}
  if(start%512===0)console.log(JSON.stringify({storedOriginalFiles:cache.size,total:allFiles.length}));
 }
 for(const cap of index.capabilities){
  const subject=inventory.subjects.find(s=>s.definitionPk===cap.definitionPk&&s.entityId===cap.id&&s.kind==='CAPABILITY'&&s.managed);
  if(!subject||subject.definitionDigest!==cap.definitionDigest||!inventory.lineage.some(l=>l.definitionPk===cap.definitionPk&&l.capsuleDigest===cap.capsuleDigest))throw new Error('MEDIA_CAPSULE_SOURCE_MISMATCH');
  const entries=await transaction(pool,async tx=>{
   const all=[...new Set([...cap.original,...cap.scenarios.flatMap(s=>s.files)])];
   for(const f of all)await fileAsset(tx,f);
   const capBundle=await importAsset(tx,{key:'scl/capability/'+cap.definitionPk,kind:'CIRCUIT_BUNDLE',bytes:jsonBytes({version:1,definitionPk:cap.definitionPk,source:index.source,capsuleDigest:cap.capsuleDigest,members:all.map(f=>({path:f,revision:cache.get(f).revision}))}),mediaType:'application/json',definitionPk:cap.definitionPk,provenance:{compiler,scope}});
   await members(tx,capBundle,all);if(cap.scenarios.length)await select(tx,cap.definitionPk,capBundle,cap.id+' — declared SCL circuit bundle');
   if(cap.blueprintDefinitionPk){
    const blueprint=inventory.subjects.find(s=>s.definitionPk===cap.blueprintDefinitionPk&&s.kind==='BLUEPRINT'&&s.definition.semantics.capability?.capabilityId===cap.id);
    if(!blueprint)throw new Error('MEDIA_BLUEPRINT_OWNER_MISMATCH');
    const bundle=await importAsset(tx,{key:'scl/blueprint/'+blueprint.definitionPk,kind:'CIRCUIT_BUNDLE',bytes:jsonBytes({version:1,definitionPk:blueprint.definitionPk,source:index.source,members:all.map(f=>({path:f,revision:cache.get(f).revision}))}),mediaType:'application/json',definitionPk:blueprint.definitionPk,parents:[{revision:capBundle.revision,role:'CAPABILITY_SOURCE'}],provenance:{compiler,scope,definitionDigest:blueprint.definitionDigest}});
    await members(tx,bundle,all);await select(tx,blueprint.definitionPk,bundle,blueprint.entityId+' — complete blueprint');
   }
   const rows=[];
   for(const scenario of cap.scenarios){
    const definition=inventory.subjects.find(s=>s.definitionPk===scenario.definitionPk&&s.kind==='SCENARIO'&&s.definitionDigest===scenario.definitionDigest&&s.entityId===scenario.scenarioId&&s.definition.semantics.tags?.capability?.includes(cap.id));
    if(!definition)throw new Error('MEDIA_SCENARIO_OWNER_MISMATCH');
    const files=[...new Set([...cap.original,...scenario.files])];
    const bundle=await importAsset(tx,{key:'scl/scenario/'+scenario.definitionPk,kind:'CIRCUIT_BUNDLE',bytes:jsonBytes({version:1,definitionPk:scenario.definitionPk,source:index.source,entry:scenario.entry,members:files.map(f=>({path:f,revision:cache.get(f).revision}))}),mediaType:'application/json',definitionPk:scenario.definitionPk,parents:[{revision:capBundle.revision,role:'CAPABILITY_SOURCE'}],provenance:{compiler,scope}});
    await members(tx,bundle,files);await select(tx,scenario.definitionPk,bundle,scenario.label);
    // SQL is the source of the exported surface, never this working folder.
    const stored=await getBlob(tx,bundle.blob);if(sha(stored.bytes)!==bundle.blob)throw new Error('MEDIA_BUNDLE_READBACK_FAILED');
    rows.push({capabilityId:cap.id,capabilityDefinitionPk:cap.definitionPk,scenarioId:scenario.scenarioId,definitionPk:scenario.definitionPk,objectPk:scenario.objectPk,bundleRevision:bundle.revision,label:scenario.label,entry:scenario.entry,scope,topologyViews:cap.topologyViews??0,publicFiles:[scenario.entry,scenario.data,...cap.original.filter(f=>/\.(js|css|html)$/.test(f)||f.includes('/textures/')),...scenario.files.filter(f=>f.includes('/textures/'))]});
   }
   return rows;
  });
  result.circuits.push(...entries);await fs.writeFile(path.join(ROOT,'data/media/circuit-import.json'),jsonBytes(result));
  console.log(JSON.stringify({capability:cap.id,storedCircuits:result.circuits.length,storedFiles:cache.size}));
 }
 await assertSource(pool,index.source);
 console.log(JSON.stringify({state:'CIRCUITS_STORED_IN_SQL',circuits:result.circuits.length,files:cache.size,gaps:result.gaps}));
}catch(e){console.error('MEDIA_CIRCUIT_IMPORT_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
