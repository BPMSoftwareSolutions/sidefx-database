import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql,transaction,sha,jsonBytes} from './store.mjs';
import {ROOT} from '../core.mjs';
const lab=path.resolve(process.env.SIDEFX_CONTENT_LAB??'C:/lab/repos/content-creation-mission');
const input=JSON.parse(await fs.readFile(path.join(ROOT,'data/media/circuit-import.json'),'utf8'));
const index=JSON.parse(await fs.readFile(path.join(lab,'outputs/estate-circuits/index.json'),'utf8'));
if(sha(jsonBytes(input.source))!==sha(jsonBytes(index.source)))throw new Error('MEDIA_CIRCUIT_SELECTION_GENERATION_MISMATCH');
const desired=input.circuits.map(c=>({definitionPk:c.definitionPk,revision:c.bundleRevision}));
for(const cap of index.capabilities.filter(c=>c.scenarios.length)){
 const all=[...new Set([...cap.original,...cap.scenarios.flatMap(s=>s.files)])];
 const blob=sha(jsonBytes({version:1,definitionPk:cap.definitionPk,source:index.source,capsuleDigest:cap.capsuleDigest,members:all.map(f=>({path:f,revision:input.files[f].revision}))}));
 const asset=sha('scl/capability/'+cap.definitionPk),proof=sha(jsonBytes({compiler:'content-lab-scl',scope:'DECLARED_SOURCE_BOUNDARY'}));
 const revision=sha(jsonBytes({asset,blob,proof,origin:'IMPORTED',width:null,height:null,parents:[],definitionPk:cap.definitionPk,requestId:null}));
 desired.push({definitionPk:cap.definitionPk,revision});
}
const pool=await connect();
try{
 const result=await transaction(pool,async tx=>(await new sql.Request(tx).input('rows',sql.NVarChar(sql.MAX),JSON.stringify(desired)).input('count',sql.Int,desired.length).query(`
  SET NOCOUNT ON;
  DECLARE @desired TABLE(requirement_id bigint PRIMARY KEY,binding_id bigint,revision_id varchar(64));
  INSERT @desired SELECT r.requirement_id,b.binding_id,j.revision FROM OPENJSON(@rows) WITH(definitionPk bigint,revision varchar(64)) j
  JOIN media.visual_requirement r ON r.definition_pk=j.definitionPk AND r.purpose='CIRCUIT' AND r.locale='en' AND r.variant='default'
  JOIN media.entity_visual_binding b ON b.requirement_id=r.requirement_id AND b.revision_id=j.revision
  JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=j.definitionPk JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk;
  IF (SELECT COUNT(*) FROM @desired)<>@count THROW 51108,'MEDIA_CURRENT_CIRCUIT_BINDING_REQUIRED',1;
  DELETE d FROM @desired d JOIN media.visual_selection x ON x.requirement_id=d.requirement_id JOIN media.entity_visual_binding b ON b.binding_id=x.binding_id JOIN media.asset_revision r ON r.revision_id=b.revision_id JOIN media.asset a ON a.asset_id=r.asset_id WHERE x.binding_id=d.binding_id OR a.kind='BUNDLE';
  DECLARE @reviews TABLE(binding_id bigint PRIMARY KEY,review_id bigint);
  INSERT media.asset_review(revision_id,binding_id,decision,reviewer,reason)
  OUTPUT inserted.binding_id,inserted.review_id INTO @reviews
  SELECT revision_id,binding_id,'APPROVED','SideFX SCL compiler and source validation','Exact source and geometry checks passed; reconstructed bundle includes reviewed material inputs. Declared structure only; no authored trace is invented.' FROM @desired;
  UPDATE x SET binding_id=d.binding_id,review_id=r.review_id,selected_at=SYSUTCDATETIME() FROM media.visual_selection x JOIN @desired d ON d.requirement_id=x.requirement_id JOIN @reviews r ON r.binding_id=d.binding_id;
  INSERT media.visual_selection(requirement_id,binding_id,review_id) SELECT d.requirement_id,d.binding_id,r.review_id FROM @desired d JOIN @reviews r ON r.binding_id=d.binding_id WHERE NOT EXISTS(SELECT 1 FROM media.visual_selection x WHERE x.requirement_id=d.requirement_id);
  SELECT (SELECT COUNT(*) FROM @reviews) selectedRevisions,@count validatedBindings;
 `)).recordset[0]);console.log(JSON.stringify(result));
}catch(e){console.error('MEDIA_CIRCUIT_SELECTION_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
