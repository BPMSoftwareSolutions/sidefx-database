import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql,getBlob,importAsset,transaction,sha,jsonBytes} from './store.mjs';
import {ROOT} from '../core.mjs';
import {readCatalog,saveCatalog,currentSource,assertSource} from './catalog.mjs';
const website=path.resolve(process.env.SIDEFX_WEBSITE_ROOT??'C:/lab/repos/sfx-platform');
const pool=await connect();
const source=await currentSource(pool),imported=await readCatalog(pool,'lab',source),inventory=await readCatalog(pool,'inventory',source);
const manifest={version:1,source:inventory.source,visuals:[],materials:[],editions:[],circuits:[],artifacts:{},coverage:[]};
let previous={artifacts:{}};
try{previous=JSON.parse(await fs.readFile(path.join(website,'generated/visual-publication.json'),'utf8'));}catch{}
async function copyBlob(relative,digest){
 if(relative.includes('..')||relative.includes('\\')||path.isAbsolute(relative))throw new Error('MEDIA_EXPORT_PATH_ESCAPE');
 if(manifest.artifacts['/'+relative]){if(manifest.artifacts['/'+relative].sha256!==digest)throw new Error('MEDIA_EXPORT_PATH_COLLISION');return '/'+relative;}
 const target=path.join(website,'public',relative),prior=previous.artifacts['/'+relative];
 if(prior?.sha256===digest){try{const local=await fs.readFile(target);if(sha(local)===digest){manifest.artifacts['/'+relative]=prior;return '/'+relative;}}catch{}}
 const blob=await getBlob(pool,digest);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,blob.bytes);
 manifest.artifacts['/'+relative]={sha256:digest,mediaType:blob.media_type,bytes:blob.bytes.length};return '/'+relative;
}
try{
 const rows=(await pool.request().query(`SELECT CONVERT(varchar(30),requirement_id) requirementId,CONVERT(varchar(30),definition_pk) definitionPk,CONVERT(varchar(30),object_pk) objectPk,object_kind kind,declared_id entityId,namespace_id namespaceId,purpose,state,revision_id revision,LOWER(CONVERT(varchar(64),blob_digest,2)) digest,width,height,media_type mediaType,alt_text altText,generator_model model,presentation_json presentation FROM media.v_requirement WHERE is_current=1 ORDER BY object_kind,definition_pk,purpose`)).recordset;
 for(const r of rows){
  if(r.state==='READY'&&r.mediaType?.startsWith('image/')){
   const ext=r.mediaType==='image/webp'?'webp':r.mediaType==='image/jpeg'?'jpg':'png';
   const url=await copyBlob(`media/assets/${r.digest}.${ext}`,r.digest);
   const original=(await pool.request().input('id',sql.VarChar(64),r.revision).query(`SELECT LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest FROM media.asset_source s JOIN media.asset_revision r ON r.revision_id=s.parent_revision_id WHERE s.revision_id=@id AND s.role='ORIGINAL'`)).recordset;
   if(original.length!==1)throw new Error('MEDIA_UNIQUE_ORIGINAL_REQUIRED');
   manifest.visuals.push({...r,originalDigest:original[0].digest,url,presentation:JSON.parse(r.presentation)});
  }
 }
 for(const m of imported.materials){
  const url=await copyBlob(`media/materials/${m.blob}.jpg`,m.blob);manifest.materials.push({id:m.id,revision:m.revision,digest:m.blob,url});
 }
 for(const edition of imported.editions){
  // The source-bound bundle is read back from SQL; local manifests only locate it.
  const revision=(await pool.request().input('id',sql.VarChar(64),edition.bundleRevision).query('SELECT LOWER(CONVERT(varchar(64),blob_digest,2)) digest FROM media.asset_revision WHERE revision_id=@id')).recordset[0];
  const bundle=JSON.parse((await getBlob(pool,revision.digest)).bytes.toString('utf8'));
  if(bundle.definitionPk!==edition.definitionPk)throw new Error('MEDIA_BUNDLE_SUBJECT_MISMATCH');
  const members=(await pool.request().input('id',sql.VarChar(64),edition.bundleRevision).query(`SELECT m.relative_path path,m.member_revision_id revision,LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest FROM media.bundle_member m JOIN media.asset_revision r ON r.revision_id=m.member_revision_id WHERE m.bundle_revision_id=@id`)).recordset;
  if(members.length!==bundle.members.length||bundle.members.some(m=>!members.some(v=>v.path===m.path&&v.revision===m.revision)))throw new Error('MEDIA_BUNDLE_CLOSURE_MISMATCH');
  for(const member of members)await copyBlob('media/library/'+member.path,member.digest);
  let circuitUrl=null;
  if(edition.circuitCount){
   const entry=members.find(m=>m.path===bundle.entry),original=(await getBlob(pool,entry.digest)).bytes.toString('utf8');
   const style=`<style>.top,#story,.experience,#evidence,#learn,#surfaces,footer,.skip{display:none!important}main{max-width:none;padding:0}#circuit{padding:0;border:0}#circuit>.section-heading{display:none}.inspection{padding:24px}.circuit-intro{padding:0 24px}.circuit-tabs{padding:20px 24px 0}.workbench{border-radius:0}#viewport{max-height:620px;min-height:260px}.section{padding:0}</style>`;
   const resize=`<style>html,body{height:auto!important;min-height:0!important;overflow:hidden!important}</style><script>addEventListener('load',()=>{const report=()=>parent.postMessage({type:'sidefx-circuit-height',height:document.body.scrollHeight},'*');new ResizeObserver(report).observe(document.body);report();});</script>`;
   const html=original.replace('</head>',style+resize+'</head>');
   const prior=(await pool.request().input('blob',sql.Binary(32),Buffer.from(sha(Buffer.from(html)),'hex')).input('asset',sql.VarChar(64),sha('website/circuit-embed/'+edition.id)).query('SELECT revision_id revision,LOWER(CONVERT(varchar(64),blob_digest,2)) blob FROM media.asset_revision WHERE asset_id=@asset AND blob_digest=@blob')).recordset[0];
   const asset=prior??await transaction(pool,tx=>importAsset(tx,{key:'website/circuit-embed/'+edition.id,kind:'CIRCUIT_EMBED',bytes:Buffer.from(html),mediaType:'text/html',origin:'DERIVED',definitionPk:edition.definitionPk,parents:[{revision:entry.revision,role:'ORIGINAL'},{revision:edition.bundleRevision,role:'BUNDLE'}],provenance:{recipe:'content-lab-circuit-embed/2',bundleRevision:edition.bundleRevision}}));
   circuitUrl=await copyBlob(`media/library/samples/capability-pages/${edition.id}/circuit.html`,asset.blob);
  }
  const library=p=>p?'/media/library/'+p:null;
  const matching=manifest.visuals.find(v=>v.definitionPk===edition.definitionPk&&v.purpose==='DETAIL');
  manifest.editions.push({id:edition.id,definitionPk:edition.definitionPk,bundleRevision:edition.bundleRevision,storyTitle:edition.storyTitle,humanProblem:edition.humanProblem,experience:edition.experience,circuitCount:edition.circuitCount,circuitUrl,image:matching?.url??null,entry:library(edition.entry),film:library(Object.entries(imported.files).find(([,v])=>v.revision===edition.film?.revision)?.[0]),captions:library(Object.entries(imported.files).find(([,v])=>v.revision===edition.captions?.revision)?.[0])});
 }
 const circuitImport=await readCatalog(pool,'circuits',source);
 let runtime=null;
 try{runtime=await readCatalog(pool,'topology-runtime',source);}catch(e){if(e.message!=='MEDIA_CATALOG_MISSING:topology-runtime')throw e;}
 if(runtime&&(runtime.profile!=='sidefx-estate-topology.v1'||sha(jsonBytes(runtime.source))!==sha(jsonBytes(source))))throw new Error('MEDIA_TOPOLOGY_RUNTIME_SOURCE_MISMATCH');
 if(circuitImport){
  if(sha(jsonBytes(circuitImport.source))!==sha(jsonBytes(inventory.source)))throw new Error('MEDIA_CIRCUIT_EXPORT_GENERATION_MISMATCH');
  for(const circuit of circuitImport.circuits){
   const selected=rows.find(r=>r.definitionPk===circuit.definitionPk&&r.purpose==='CIRCUIT'&&r.state==='READY'&&r.revision===circuit.bundleRevision);
   if(!selected)continue;
   const members=(await pool.request().input('id',sql.VarChar(64),circuit.bundleRevision).query(`SELECT m.relative_path path,m.member_revision_id revision,LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest FROM media.bundle_member m JOIN media.asset_revision r ON r.revision_id=m.member_revision_id WHERE m.bundle_revision_id=@id`)).recordset;
   // ADR 0001: the website renders topology from validated graph data, so the compiled diagram
   // pages, catalogs, per-view scripts and viewer runtime are no longer delivered. The material
   // textures the renderer references are still exported; SQL retains every dropped artifact.
   const delivered=circuit.scope==='DECLARED_SOURCE_TOPOLOGY'
    ?circuit.publicFiles.filter(f=>f.includes('/estate-topology/textures/'))
    :circuit.publicFiles;
   for(const file of delivered){
    const member=members.find(m=>m.path===file);if(!member)throw new Error('MEDIA_CIRCUIT_PUBLIC_FILE_OUTSIDE_BUNDLE');
    const replacement=runtime?.files.find(r=>r.path===file);
    if(replacement){
     if(!replacement.baseRevisions.includes(member.revision)&&replacement.blob!==member.digest)throw new Error('MEDIA_TOPOLOGY_RUNTIME_BASE_MISMATCH');
     await copyBlob('media/library/'+file,replacement.blob);
    }else if(file==='templates/estate-circuit/viewer.js'&&!manifest.artifacts['/media/library/'+file]){
     const original=(await getBlob(pool,member.digest)).bytes;
     const bytes=Buffer.concat([original,Buffer.from(`\naddEventListener('load',()=>{const stage=document.getElementById('stage');const expose=()=>stage.firstElementChild?.setAttribute('role','group');new MutationObserver(expose).observe(stage,{childList:true});expose();const report=()=>parent.postMessage({type:'sidefx-circuit-height',height:document.body.scrollHeight},'*');new ResizeObserver(report).observe(document.body);report();});`)]);
     const derived=await transaction(pool,tx=>importAsset(tx,{key:'website/stored-circuit-viewer',kind:'CIRCUIT_RUNTIME',bytes,mediaType:'application/javascript',origin:'DERIVED',parents:[{revision:member.revision,role:'ORIGINAL'}],provenance:{recipe:'circuit-embed-sizing-accessibility/2',originalDigest:member.digest}}));
     await copyBlob('media/library/'+file,derived.blob);
    }else if(!manifest.artifacts['/media/library/'+file])await copyBlob('media/library/'+file,member.digest);
   }
   // A topology circuit no longer has a delivered entry page to point at; the website resolves it
   // through generated/topology instead, so it is not published as a stored circuit.
   if(circuit.scope!=='DECLARED_SOURCE_TOPOLOGY')manifest.circuits.push({capabilityId:circuit.capabilityId,capabilityDefinitionPk:circuit.capabilityDefinitionPk,scenarioId:circuit.scenarioId,definitionPk:circuit.definitionPk,objectPk:circuit.objectPk,bundleRevision:circuit.bundleRevision,label:circuit.label,url:'/media/library/'+circuit.entry,artifacts:circuit.publicFiles.map(f=>'/media/library/'+f),scope:circuit.scope??'DECLARED_SOURCE_BOUNDARY',topologyViews:circuit.topologyViews??0});
  }
 }
 manifest.coverage=(await pool.request().query('SELECT object_kind kind,purpose,state,COUNT(*) count FROM media.v_requirement WHERE is_current=1 GROUP BY object_kind,purpose,state ORDER BY object_kind,purpose,state')).recordset;
 await assertSource(pool,source);await saveCatalog(pool,'website-visual-publication',source,manifest);
 const bytes=jsonBytes(manifest);await fs.mkdir(path.join(website,'generated'),{recursive:true});await fs.writeFile(path.join(website,'generated/visual-publication.json.tmp'),bytes);await fs.rename(path.join(website,'generated/visual-publication.json.tmp'),path.join(website,'generated/visual-publication.json'));
 console.log(JSON.stringify({state:'EXPORTED_FROM_SQL',visuals:manifest.visuals.length,materials:manifest.materials.length,editions:manifest.editions.length,circuits:manifest.circuits.length,artifacts:Object.keys(manifest.artifacts).length,bytes:Object.values(manifest.artifacts).reduce((n,a)=>n+a.bytes,0),digest:sha(bytes)}));
}catch(e){console.error('MEDIA_EXPORT_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
