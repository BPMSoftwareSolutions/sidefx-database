import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import {connect,sql,transaction,importAsset,bindAsset,approveAndSelect,sha,jsonBytes,getBlob} from './store.mjs';
import {ROOT} from '../core.mjs';

const lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission');
const mime={'.json':'application/json','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.html':'text/html','.mp4':'video/mp4','.vtt':'text/vtt','.md':'text/markdown','.scl':'text/plain','.py':'text/x-python','.wav':'audio/wav'};
const read=async relative=>{
 const file=path.resolve(lab,relative);if(!file.startsWith(lab+path.sep))throw new Error('MEDIA_LAB_PATH_ESCAPE');return fs.readFile(file);
};
const load=async relative=>JSON.parse((await read(relative)).toString('utf8'));
const inventory=JSON.parse(await fs.readFile(path.join(ROOT,'data/media/inventory.json'),'utf8'));
const pool=await connect();const cache=new Map();const exports={version:1,materials:[],editions:[],files:{}};

async function fileAsset(relative,expected,{kind='SOURCE',provenance={},definitionPk=null,parents=[]}={}){
 const bytes=await read(relative);if(expected&&sha(bytes)!==expected.replace(/^sha256:/,''))throw new Error('MEDIA_STALE_LAB_FILE:'+relative);
 const cacheKey=relative+':'+(definitionPk??'');if(cache.has(cacheKey))return cache.get(cacheKey);
 const type=mime[path.extname(relative).toLowerCase()]??'application/octet-stream';
 let dimensions={};if(['image/png','image/jpeg','image/webp'].includes(type)){const m=await sharp(bytes).metadata();dimensions={width:m.width,height:m.height};}
 const asset=await transaction(pool,tx=>importAsset(tx,{key:'content-lab/'+relative,bytes,mediaType:type,kind,provenance:{sourcePath:relative,sourceSha256:sha(bytes),...provenance},definitionPk,parents,...dimensions}));
 // Verify the persisted bytes, not the local file used for insertion.
 const roundtrip=await getBlob(pool,asset.blob);if(!bytes.equals(roundtrip.bytes))throw new Error('MEDIA_SQL_ROUNDTRIP_FAILED');
 cache.set(cacheKey,asset);exports.files[relative]={...asset};return asset;
}
async function selectImage(subject,relative,expected,context,provenance){
 const original=await fileAsset(relative,expected,{kind:'ENTITY_IMAGE',definitionPk:subject.definitionPk,provenance});
 const bytes=(await getBlob(pool,original.blob)).bytes;
 for(const purpose of ['DETAIL','CARD']){
  const output=await sharp(bytes).resize({width:purpose==='CARD'?720:1600,withoutEnlargement:true}).webp({quality:88}).toBuffer({resolveWithObject:true});
  const asset=await transaction(pool,tx=>importAsset(tx,{key:`entity/${subject.definitionPk}/${purpose}`,kind:'ENTITY_IMAGE',bytes:output.data,mediaType:'image/webp',origin:'DERIVED',width:output.info.width,height:output.info.height,definitionPk:subject.definitionPk,parents:[{revision:original.revision,role:'ORIGINAL'}],provenance:{...provenance,recipe:'responsive-webp/1',purpose}}));
  const requirement=inventory.requirements.find(r=>r.definitionPk===subject.definitionPk&&r.purpose===purpose);
  await transaction(pool,async tx=>{
   const bindingId=await bindAsset(tx,{requirementId:requirement.requirementId,revision:asset.revision,altText:context,presentation:{fit:'contain',focalPoint:[.5,.5]}});
   await approveAndSelect(tx,{bindingId,reviewer:'Content Creation Mission reviewed edition import',reason:'Exact reviewed page manifest, source capsule lineage and original/derivative bytes verified. Artwork illustrates the declared content scope.'});
  });
 }
 return original;
}
try{
 // Preserve every existing provider original and its generation receipt, including candidates.
 for(const name of await fs.readdir(path.join(lab,'outputs/generated'))){
  if(!name.endsWith('.json'))continue;
  const receipt=await load('outputs/generated/'+name);
  const receiptAsset=await fileAsset('outputs/generated/'+name,null,{kind:'PROVENANCE'});
  for(const im of receipt.images??[])await fileAsset('outputs/generated/'+im.path,im.sha256,{kind:'GENERATED_CANDIDATE',provenance:{model:receipt.model,provider:'Gemini',jobId:receipt.jobId,reviewState:receipt.semanticReview},parents:[{revision:receiptAsset.revision,role:'RECEIPT'}]});
 }
 const review=await load('evaluations/component-enhancement-review.json');
 for(const [id,r] of Object.entries(review.assets)){
  const receipt=await load(`outputs/component-enhancements/${id}/receipt.json`);
  if(r.status!=='ACCEPTED_MATERIAL'||r.imageSha256!==receipt.imageSha256)throw new Error('MEDIA_COMPONENT_REVIEW_MISMATCH');
  const asset=await fileAsset(receipt.image,r.imageSha256,{kind:'COMPONENT',provenance:{model:receipt.model,provider:receipt.provider,component:id,receipt,review:r,permittedUse:'Canonical-mask compositing only'}});
  await transaction(pool,async tx=>{await new sql.Request(tx).input('id',sql.VarChar(64),asset.revision).input('reason',sql.NVarChar(2000),r.note).query(`IF NOT EXISTS(SELECT 1 FROM media.asset_review WHERE revision_id=@id AND binding_id IS NULL AND decision='APPROVED') INSERT media.asset_review(revision_id,decision,reviewer,reason) VALUES(@id,'APPROVED','Content Creation Mission existing material review',@reason)`);});
  exports.materials.push({id,...asset});
 }
 for(const name of await fs.readdir(path.join(lab,'docs/visual-assets')))if(name.endsWith('.png'))await fileAsset('docs/visual-assets/'+name,null,{kind:'DESIGN_REFERENCE',provenance:{reviewState:'REFERENCE_ONLY'}});
 for(const id of ['interlock-agent-operation','generate-governed-narration']){
  const manifest=await load(`declarations/capability-pages/${id}.json`),content=await load(manifest.content.path),receipt=await load(`samples/capability-pages/${id}/build-receipt.json`);
  const subject=inventory.subjects.find(s=>s.kind==='CAPABILITY'&&s.entityId===id&&s.managed);
  if(!subject||content.status!=='EDITORIALLY_REVIEWED'||!inventory.lineage.some(l=>l.definitionPk===subject.definitionPk&&l.capsuleDigest===content.source.capsuleDigest.replace(/^sha256:/,'')))throw new Error('MEDIA_EDITION_SOURCE_MISMATCH:'+id);
  const members=[];
  for(const [relative,expected] of Object.entries(receipt.inputs)){
   const asset=await fileAsset(relative,expected,{kind:'EDITION_SOURCE'});members.push({path:relative,revision:asset.revision});
  }
  for(const [name,expected] of Object.entries(receipt.outputs)){
   const relative=`samples/capability-pages/${id}/${name}`,asset=await fileAsset(relative,expected,{kind:'EDITION_RUNTIME'});members.push({path:relative,revision:asset.revision});
  }
  const poster=manifest.film.poster;
  await selectImage(subject,poster.path,poster.sha256,content.humanProblem,{model:'gemini-3-pro-image',provider:'Gemini',contentContractSha256:manifest.content.sha256,sourceCapsuleDigest:content.source.capsuleDigest,edition:id,scope:content.scope??'Reviewed illustrative story; execution claims retain their original evidence scope.'});
  const bundleManifest={version:1,capabilityId:id,definitionPk:subject.definitionPk,definitionDigest:subject.definitionDigest,entry:`samples/capability-pages/${id}/index.html`,members,sourceCapsuleDigest:content.source.capsuleDigest};
  const bundle=await transaction(pool,tx=>importAsset(tx,{key:'edition/'+id,kind:'BUNDLE',bytes:jsonBytes(bundleManifest),mediaType:'application/json',definitionPk:subject.definitionPk,provenance:{sourceCapsuleDigest:content.source.capsuleDigest,buildReceiptSha256:sha(jsonBytes(receipt)),status:receipt.status}}));
  await transaction(pool,async tx=>{
   for(const member of members)await new sql.Request(tx).input('bundle',sql.VarChar(64),bundle.revision).input('path',sql.NVarChar(800),member.path).input('member',sql.VarChar(64),member.revision).query(`IF NOT EXISTS(SELECT 1 FROM media.bundle_member WHERE bundle_revision_id=@bundle AND relative_path=@path) INSERT media.bundle_member VALUES(@bundle,@path,@member)`);
   const requirement=inventory.requirements.find(r=>r.definitionPk===subject.definitionPk&&r.purpose==='CIRCUIT');
   const bindingId=await bindAsset(tx,{requirementId:requirement.requirementId,revision:bundle.revision,altText:content.title+' — reviewed visual edition',presentation:{profile:'content-lab-edition/1',circuitCount:manifest.circuits.length}});
   if(manifest.circuits.length)await approveAndSelect(tx,{bindingId,reviewer:'Content Creation Mission reviewed edition import',reason:'Reviewed source-bound compiled circuits, exact runtime assets and all 96-or-fewer input hashes verified; related target circuits retain their labels.'});
  });
  exports.editions.push({id,definitionPk:subject.definitionPk,bundleRevision:bundle.revision,entry:bundleManifest.entry,storyTitle:receipt.storyTitle,contentTitle:content.title,experience:content.experience,humanProblem:content.humanProblem,circuitCount:manifest.circuits.length,poster:exports.files[poster.path],film:exports.files[manifest.film.media.path],captions:exports.files[manifest.film.captions.path],members:members.map(m=>m.path)});
  console.log('IMPORTED_EDITION',id,members.length);
 }
 await fs.mkdir(path.join(ROOT,'data/media'),{recursive:true});await fs.writeFile(path.join(ROOT,'data/media/lab-import.json'),JSON.stringify(exports,null,2)+'\n');
 console.log(JSON.stringify({status:'SQL_BYTES_VERIFIED',files:Object.keys(exports.files).length,materials:exports.materials.length,editions:exports.editions.length}));
}catch(e){console.error('MEDIA_LAB_IMPORT_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
