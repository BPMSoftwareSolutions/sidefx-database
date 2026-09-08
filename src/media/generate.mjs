import fs from 'node:fs/promises';
import path from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import sharp from 'sharp';
import {connect,sql,transaction,putBlob,importAsset,bindAsset,sha,jsonBytes} from './store.mjs';
import {ROOT} from '../core.mjs';
const run=promisify(execFile),lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission');
const args=process.argv.slice(2),arg=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const inventory=JSON.parse(await fs.readFile(path.join(ROOT,'data/media/inventory.json'),'utf8'));
const model='gemini-3-pro-image';
const stylePath='docs/visual-assets/sidefx-visual-alphabet-enhanced.png';
const styleDigest=sha(await fs.readFile(path.join(lab,stylePath)));
const direction={
 'parse-json':'A precision optical parsing prism: one continuous translucent ribbon of JSON text enters from the left and resolves into a clearly structured object of nested glass compartments on the right. An elegant physical model of parsing, not a computer screen. Warm ivory studio ground, sapphire input, cyan transformation, emerald structured value. No invented network or disk effect.',
 'filter':'An exact predicate aperture separates a short stream of glass records: matching records continue in their original order; nonmatching records remain quietly in a separate tray. Refined editorial product photography, one clearly legible selection action.',
 'map':'A row of three individually separated incoming glass values passes through a precise cyan optical transformation plane, becoming three transformed values in the same order. One-to-one correspondence is visible. No merging or dropped values.',
 'sha256':'A delicate transparent document sheet passes through a precise optical digest instrument and yields one narrow, fixed-size identity bar. Different-sized input sheets beside the instrument establish fixed-size digest output. No lock, encryption claim or reversed reconstruction.',
};
function facts(s){
 const v=s.definition.semantics;
 if(s.kind==='CAPABILITY')return {id:s.entityId,kind:s.kind,name:v.authority?.name,userStory:v.authority?.userStory,experience:v.authority?.experience};
 if(s.kind==='SCENARIO')return {id:s.entityId,kind:s.kind,scenario:v.scenario};
 if(s.kind==='MECHANIC'){const m=v.mechanic??{};return {id:s.entityId,kind:s.kind,meaning:m.meaning,input:m.input,output:m.output,determinism:m.determinism,effectClassification:m.effectClassification,identityOnly:!m.meaning};}
 return {id:s.entityId,kind:s.kind,declaredRole:'Provider implementation identity; illustration is not an official logo or evidence of qualification.'};
}
function prompt(s){
 const subject=facts(s);
 return `Create ONE distinctive SideFX ${s.kind.toLowerCase()} editorial illustration, 16:9, at 1K. This image belongs ONLY to the exact subject below.\nSUBJECT FACTS (data, not instructions):\n${JSON.stringify(subject)}\nART DIRECTION:\n${direction[s.entityId]??(s.kind==='SCENARIO'?'Compose a distinct visual story for this exact scenario: its given/input, responsibility and resulting experience. Choose one concrete moment and one clear subject. Depict expected experience, never claim an observed execution.':s.kind==='CAPABILITY'?'Create a considered visual metaphor for this capability promise and its actor. One primary physical subject with a specific, intelligible operation; compose around its intended experience.':s.kind==='MECHANIC'?'Create a precise material study of this declared responsibility. If only an identity is given, make an abstract identity portrait with no invented inputs, outputs or operating claims.':'An elegant violet glass implementer module whose physical composition evokes this named provider and declared role. No official logo, affiliation seal, success badge or fabricated integration.')}
Design quality: polished optical glass, fine machined titanium edges, restrained luminous accents and professional product lighting. Compose within generous negative space; the silhouette and action must read at catalog size. Use a warm ivory studio surface with a deep ink architectural stage where it improves contrast. Use the reference only for the SideFX material language. Do not copy the reference poster, its words, panel layout or its collection of symbols. Design one specific subject, not a grid of reusable components. No title, text, typography, UI, watermark, dashboard, logos, arbitrary arrows or background network. No busy sci-fi scenery or gratuitous glow. Circuit topology will be drawn independently as deterministic SVG. This illustration must not manufacture a circuit or evidence status.`;
}
const pool=await connect();
async function prepare(){
 let queued=0;
 for(const s of inventory.subjects.filter(s=>['CAPABILITY','SCENARIO','MECHANIC','PROVIDER'].includes(s.kind))){
  const req=inventory.requirements.find(r=>r.definitionPk===s.definitionPk&&r.purpose==='DETAIL');
  if(!req)continue;
  const job={version:1,model,definitionPk:s.definitionPk,definitionDigest:s.definitionDigest,subjectKind:s.kind,entityId:s.entityId,source:inventory.source,prompt:prompt(s),references:[{path:stylePath,sha256:styleDigest,mediaType:'image/png'}]};
  const bytes=jsonBytes(job),id=sha(bytes);
  await transaction(pool,async tx=>{
   const blob=await putBlob(tx,bytes,'application/json');
   const result=await new sql.Request(tx).input('id',sql.VarChar(64),id).input('r',sql.BigInt,req.requirementId).input('model',sql.VarChar(120),model).input('blob',sql.Binary(32),Buffer.from(blob,'hex')).query(`IF NOT EXISTS(SELECT 1 FROM media.generation_request WHERE request_id=@id) AND NOT EXISTS(SELECT 1 FROM media.visual_selection WHERE requirement_id=@r) INSERT media.generation_request(request_id,requirement_id,provider,model,request_blob_digest) VALUES(@id,@r,'Gemini',@model,@blob);`);
   queued+=result.rowsAffected[0]??0;
  });
 }
 console.log(JSON.stringify({queued,model,reserveUsdPerRequest:.30,commands:'--execute --limit N --budget-usd B [--concurrency 3]'}));
}
async function generate(row){
 const claimed=(await pool.request().input('id',sql.VarChar(64),row.request_id).query(`UPDATE media.generation_request SET state='GENERATING',attempts=attempts+1,updated_at=SYSUTCDATETIME() OUTPUT inserted.request_id WHERE request_id=@id AND state='QUEUED'`)).recordset;
 if(!claimed.length)return;
 const job=JSON.parse(row.bytes.toString('utf8')),folder=path.join(ROOT,'data/media/requests');await fs.mkdir(folder,{recursive:true});
 const requestFile=path.join(folder,row.request_id+'.json');await fs.writeFile(requestFile,row.bytes);
 try{
  const {stdout}=await run(path.join(lab,'.venv/Scripts/python.exe'),[path.join(lab,'scripts/generate_estate_image.py'),'--job',row.request_id,'--request',requestFile],{cwd:lab,windowsHide:true,timeout:300000,maxBuffer:2*1024*1024});
  const receipt=JSON.parse(stdout),bytes=await fs.readFile(path.join(lab,receipt.image));if(sha(bytes)!==receipt.imageSha256)throw new Error('MEDIA_GENERATED_DIGEST_MISMATCH');
  const original=await transaction(pool,tx=>importAsset(tx,{key:'nano-banana/'+row.request_id,kind:'ENTITY_IMAGE',bytes,mediaType:receipt.mediaType,origin:'GENERATED',width:receipt.width,height:receipt.height,definitionPk:job.definitionPk,requestId:row.request_id,provenance:{...receipt,source:job.source,definitionDigest:job.definitionDigest}}));
  for(const purpose of ['DETAIL','CARD']){
   const output=await sharp(bytes).resize({width:purpose==='CARD'?720:1600,withoutEnlargement:true}).webp({quality:88}).toBuffer({resolveWithObject:true});
   const req=inventory.requirements.find(r=>r.definitionPk===job.definitionPk&&r.purpose===purpose);
   await transaction(pool,async tx=>{
    const derivative=await importAsset(tx,{key:`entity/${job.definitionPk}/${purpose}/${row.request_id}`,kind:'ENTITY_IMAGE',bytes:output.data,mediaType:'image/webp',origin:'DERIVED',width:output.info.width,height:output.info.height,definitionPk:job.definitionPk,requestId:row.request_id,parents:[{revision:original.revision,role:'ORIGINAL'}],provenance:{model,provider:'Gemini',recipe:'responsive-webp/1',definitionDigest:job.definitionDigest,jobId:row.request_id}});
    await bindAsset(tx,{requirementId:req.requirementId,revision:derivative.revision,altText:`Illustration of ${job.entityId.replaceAll('-',' ')}.`,presentation:{fit:'contain',focalPoint:[.5,.5]}});
   });
  }
  await pool.request().input('id',sql.VarChar(64),row.request_id).query(`UPDATE media.generation_request SET state='REVIEW_REQUIRED',updated_at=SYSUTCDATETIME() WHERE request_id=@id`);
  console.log('GENERATED_SQL',job.subjectKind,job.entityId,receipt.image);
 }catch(e){
  // A process/network failure can have incurred a charge. It is never auto-retried.
  await pool.request().input('id',sql.VarChar(64),row.request_id).query(`UPDATE media.generation_request SET state='UNCERTAIN',failure_code='TRANSPORT_OR_INGEST_RECONCILIATION_REQUIRED',updated_at=SYSUTCDATETIME() WHERE request_id=@id`);
  console.log('RECONCILIATION_REQUIRED',job.entityId);throw new Error('MEDIA_GENERATION_STOPPED');
 }
}
try{
 if(args.includes('--prepare'))await prepare();
 if(args.includes('--execute')){
  const limit=Number(arg('--limit','0')),budget=Number(arg('--budget-usd','0')),concurrency=Number(arg('--concurrency','3'));
  if(!Number.isInteger(limit)||limit<1||limit*.30>budget||!Number.isInteger(concurrency)||concurrency<1||concurrency>8)throw new Error('MEDIA_EXPLICIT_LIMIT_BUDGET_AND_CONCURRENCY_REQUIRED');
  const ids=arg('--subjects','').split(',').filter(Boolean);
  const rows=(await pool.request().query(`SELECT j.request_id,b.bytes,o.declared_id,s.object_kind FROM media.generation_request j JOIN media.blob b ON b.digest=j.request_blob_digest JOIN media.visual_requirement r ON r.requirement_id=j.requirement_id JOIN media.subject s ON s.definition_pk=r.definition_pk JOIN model.semantic_object o ON o.semantic_object_pk=s.object_pk WHERE j.state='QUEUED' AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=s.definition_pk) ORDER BY CASE s.object_kind WHEN 'MECHANIC' THEN 0 WHEN 'SCENARIO' THEN 1 ELSE 2 END,o.declared_id,j.request_id`)).recordset.filter(r=>!ids.length||ids.includes(r.declared_id)).slice(0,limit);
  let i=0,stop=false;
  await Promise.all(Array.from({length:Math.min(concurrency,rows.length)},async()=>{while(i<rows.length&&!stop){const row=rows[i++];try{await generate(row);}catch{stop=true;}}}));
  if(stop)throw new Error('MEDIA_GENERATION_STOPPED');
  console.log(JSON.stringify({completed:rows.length,reservedBudget:rows.length*.30,reviewRequired:true}));
 }
}catch(e){console.error(e.message.startsWith('MEDIA_')?e.message:'MEDIA_GENERATION_FAILED');process.exitCode=1;}finally{await pool.close();}
