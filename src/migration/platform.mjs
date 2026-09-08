import fs from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {complete,validateKeys} from './complete.mjs';
import {canonical,parseJson,bytesDigest,pointer,validId} from './data.mjs';
import {tables,digest} from './catalog.mjs';

export async function platform({evaluatedAt=new Date().toISOString()}={}){
 const cfg=parseJson(await fs.readFile(new URL('../../config/platform-normalization.json',import.meta.url)));
 const ds=await complete({evaluatedAt});
 const baseCounts=ds.counts(),baseModel=ds.model,baseSnapshot=ds.snapshot,baseRule=ds.rule;
 const original=parseJson(await fs.readFile(new URL('../../data/snapshots/'+cfg.baseSnapshot.slice(7)+'.json',import.meta.url)));
 const lockArtifact=original.artifacts.find(a=>a.sourcePath==='package-lock.json'&&a.sourceClass==='REPOSITORY_TRACKED');
 const lockContent=ds.contents.get(lockArtifact.contentDigest.slice(7));const pin=parseJson(lockContent.content_bytes).packages['node_modules/sda-bootstrap'];
 if(!pin.resolved.endsWith('/'+cfg.bootstrapRevision+'.tar.gz'))throw new Error('BOOTSTRAP_PIN_MISMATCH');
 const inputs=cfg.sources.map(file=>{const bytes=execFileSync('git',['show',cfg.bootstrapRevision+':'+file],{cwd:cfg.bootstrapRepository,windowsHide:true,maxBuffer:16*1024*1024});return {file,bytes,json:parseJson(bytes),digest:'sha256:'+digest(bytes)};});
 const body={snapshotFormat:'sidefx-pinned-dependency-closure.v1',baseSnapshot:cfg.baseSnapshot,estateManifestDigest:original.estateManifestDigest,sourceHead:original.sourceHead,dependency:{package:'sda-bootstrap',revision:cfg.bootstrapRevision,packageLockDigest:lockArtifact.contentDigest,resolved:pin.resolved,integrity:pin.integrity},artifacts:[...original.artifacts,...inputs.map(x=>({sourcePath:'sda-bootstrap@'+cfg.bootstrapRevision+'/'+x.file,sourceClass:'PINNED_PLATFORM_AUTHORITY',contentDigest:x.digest,byteLength:x.bytes.length,capabilityId:null,capsuleDigest:null,authorityDigest:null,entryId:x.file,containerPath:pin.resolved}))]};
 for(const a of body.artifacts)if(!a.artifactId)a.artifactId='sha256:'+digest(canonical(a));
 const snapshotId='sha256:'+digest(canonical(body));await fs.writeFile(new URL('../../data/snapshots/'+snapshotId.slice(7)+'.json',import.meta.url),JSON.stringify({snapshotId,...body},null,2)+'\n');
 ds.snapshot=ds.add('source.estate_snapshot',{snapshot_digest:Buffer.from(snapshotId.slice(7),'hex'),estate_manifest_digest:baseSnapshot.estate_manifest_digest,source_head:baseSnapshot.source_head,captured_at:null});
 const ruleContent=ds.json({...cfg,extendsManifest:ds.summary.manifest,dependency:body.dependency,implementationDigest:digest(await fs.readFile(new URL('./platform.mjs',import.meta.url)))});
 ds.rule=ds.add('source.mapping_rule',{rule_id:cfg.ruleId,rule_digest:ruleContent.content_digest,source_profile:'pinned-platform-catalog.v1',rule_content_object_pk:ruleContent.content_object_pk,canonicalization_profile:'JCS-IJSON-safe-integers.v1'});
 ds.model=ds.add('source.estate_model',{estate_snapshot_pk:ds.snapshot.estate_snapshot_pk,mapping_manifest_digest:bytesDigest(canonical([{id:cfg.ruleId,digest:ruleContent.content_digest.toString('hex')}])),publication_state:'BUILDING'});
 ds.add('source.estate_model_rule',{estate_model_pk:ds.model.estate_model_pk,mapping_rule_pk:ds.rule.mapping_rule_pk});
 const clone=(name,row,changes={})=>{const v={...row,...changes},t=tables.get(name);if(t.identity)delete v[t.pk[0]];return ds.add(name,v,{dedup:true});};
 const appearanceMap=new Map(),observationMap=new Map();
 for(const a of ds.rows.get('source.source_appearance').slice())if(a.estate_snapshot_pk===baseSnapshot.estate_snapshot_pk){const r=clone('source.source_appearance',a,{estate_snapshot_pk:ds.snapshot.estate_snapshot_pk});appearanceMap.set(a.source_appearance_pk,r.source_appearance_pk);}
 for(const o of ds.rows.get('source.source_observation').slice())if(appearanceMap.has(o.source_appearance_pk)){const r=clone('source.source_observation',o,{source_appearance_pk:appearanceMap.get(o.source_appearance_pk)});observationMap.set(o.source_observation_pk,r.source_observation_pk);}
 for(const table of ['source.declaration_observation','source.relationship_observation'])for(const o of ds.rows.get(table).slice())if(observationMap.has(o.source_observation_pk))clone(table,o,{source_observation_pk:observationMap.get(o.source_observation_pk)});
 for(const r of ds.rows.get('source.source_lineage').slice())if(observationMap.has(r.source_observation_pk))clone('source.source_lineage',r,{source_observation_pk:observationMap.get(r.source_observation_pk),mapping_rule_pk:ds.rule.mapping_rule_pk});
 for(const table of ['model.estate_definition','model.estate_capability'])for(const r of ds.rows.get(table).slice())if(r.estate_model_pk===baseModel.estate_model_pk)clone(table,r,{estate_model_pk:ds.model.estate_model_pk});
 for(const table of ['model.observed_transition_resolution','model.observed_invocation_resolution'])for(const r of ds.rows.get(table).slice())if(r.estate_model_pk===baseModel.estate_model_pk)clone(table,r,{estate_model_pk:ds.model.estate_model_pk,source_observation_pk:observationMap.get(r.source_observation_pk)});
 for(const table of ['model.observed_semantic_graph_transition','model.observed_execution_scenario_invocation'])for(const r of ds.rows.get(table).slice())if(observationMap.has(r.source_observation_pk))clone(table,r,{source_observation_pk:observationMap.get(r.source_observation_pk)});
 for(const r of ds.rows.get('source.namespace_mapping').slice())clone('source.namespace_mapping',r,{mapping_rule_pk:ds.rule.mapping_rule_pk});
 for(const r of ds.rows.get('source.source_classification').slice())if(r.mapping_rule_pk===baseRule.mapping_rule_pk)clone('source.source_classification',r,{source_appearance_pk:appearanceMap.get(r.source_appearance_pk),mapping_rule_pk:ds.rule.mapping_rule_pk});
 const sources=new Map();for(const x of inputs){const c=ds.content(x.bytes),sourcePath='sda-bootstrap@'+cfg.bootstrapRevision+'/'+x.file;const a=ds.add('source.source_appearance',{estate_snapshot_pk:ds.snapshot.estate_snapshot_pk,content_object_pk:c.content_object_pk,appearance_digest:Buffer.from(body.artifacts.find(a=>a.sourcePath===sourcePath).artifactId.slice(7),'hex'),source_path:sourcePath,source_class:'PINNED_PLATFORM_AUTHORITY',container_locator:pin.resolved,capsule_digest:null,referenced_authority_digest:null,entry_id:x.file});sources.set(x.file,{...x,a});ds.add('source.source_classification',{source_appearance_pk:a.source_appearance_pk,mapping_rule_pk:ds.rule.mapping_rule_pk,family_code:x.file==='package.json'?'DEPENDENCY_PIN':'PLATFORM_DECLARATION',classification_state:x.file==='package.json'?'OUTSIDE_SCOPE':'SUPPORTED'});}
 const observe=(s,ptr,value,kind,id=null)=>ds.observation(s.a,'json-pointer:'+ptr,'DECLARATION',value,{kind,id});
 const ns=kind=>{const n=ds.namespace(kind,cfg.namespaces[kind]);ds.add('source.namespace_mapping',{mapping_rule_pk:ds.rule.mapping_rule_pk,object_kind:kind,source_scope:cfg.namespaces[kind],namespace_pk:n.namespace_pk},{dedup:true});return n;};
 const define=(kind,id,semantics,fields,observations)=>ds.definition(ds.identity(kind,id,ns(kind)),semantics,fields,observations);
 const catalogSource=sources.get('platform/kernel/semantic-authority/consumer/sda-platform-capabilities.semantic-authority.json'),catalog=catalogSource.json;
 if(catalog.catalogType!=='sda-platform-capability-catalog.v1')throw new Error('UNSUPPORTED_PLATFORM_CATALOG');
 const mechanics=new Map(),providers=new Map(),implementationPairs=new Map();
 for(const s of sources.values())if(['semantic-value-mechanics-authority.v1','platform-effect-mechanics-authority.v1'].includes(s.json.authorityType)){
  define('AUTHORITY',s.json.authorityId,s.json,{authority_kind:'MECHANIC_VOCABULARY',authority_profile:s.json.authorityType},[observe(s,'',s.json,'AUTHORITY',s.json.authorityId)]);
  for(const [i,m]of s.json.mechanics.entries()){if(!validId(m.mechanicId))throw new Error('INVALID_MECHANIC_DECLARATION');const d=define('MECHANIC',m.mechanicId,{authorityId:s.json.authorityId,mechanic:m},{name:m.meaning??null,mechanic_kind:m.effectClassification,definition_profile:s.json.authorityType},[observe(s,'/mechanics/'+i,m,'MECHANIC',m.mechanicId)]);mechanics.set(m.mechanicId,d);}
 }
 const groups=new Map();for(const [i,c]of catalog.capabilities.entries()){if(!validId(c.provider)||!validId(c.capabilityId))throw new Error('INVALID_PLATFORM_DECLARATION');if(!groups.has(c.provider))groups.set(c.provider,[]);groups.get(c.provider).push({c,i});}
 for(const [providerId,entries]of groups){const pd=define('PROVIDER',providerId,{catalogType:catalog.catalogType,capabilities:entries.map(x=>x.c)},{name:providerId,declaration_profile:catalog.catalogType},entries.map(({c,i})=>observe(catalogSource,'/capabilities/'+i,c,'PLATFORM_CAPABILITY',c.capabilityId)));providers.set(providerId,pd);
  for(const [ordinal,{c,i}]of entries.entries()){const o=observe(catalogSource,'/capabilities/'+i,c,'PLATFORM_CAPABILITY',c.capabilityId);const cv=define('CAPABILITY',c.capabilityId,c,{name:c.capabilityId,actor:null,intent:null,outcome:null,experience_id:null,experience_actor:null,experience_promise:null},[o]);const ptr='/semantics/capabilities/'+ordinal;
   ds.member('provider_capability_implementation',{provider_definition_pk:pd.provider_definition_pk,capability_version_pk:cv.capability_version_pk,role:'DECLARED_PLATFORM_CAPABILITY'},pd,ptr,[o]);
   for(const [j,id]of c.providesMechanics.entries()){if(!validId(id))throw new Error('INVALID_PROVIDED_MECHANIC');const mo=observe(catalogSource,`/capabilities/${i}/providesMechanics/${j}`,id,'PROVIDED_MECHANIC',id);let md=mechanics.get(id);
    if(!md){md=define('MECHANIC',id,{vocabulary:catalog.catalogType,mechanicId:id},{name:null,mechanic_kind:'PLATFORM_CAPABILITY_MECHANIC',definition_profile:'sda-platform-provided-mechanic.v1'},[mo]);mechanics.set(id,md);}else ds.lineage(md.table,md.semantic_object_definition_pk,'',[mo]);
    const key=pd.provider_definition_pk+':'+md.mechanic_version_pk;let member=implementationPairs.get(key);if(!member){member=ds.member('provider_mechanic_implementation',{provider_definition_pk:pd.provider_definition_pk,mechanic_version_pk:md.mechanic_version_pk,provider_profile_version_pk:null,role:null},pd,ptr+'/providesMechanics/'+j,[o,mo]);implementationPairs.set(key,member);}else ds.lineage('provider_mechanic_implementation',pd.semantic_object_definition_pk,member._canonical_pointer,[o,mo]);
   }
  }
 }
  const registries=[...sources.values()].filter(s=>s.json.registryType?.endsWith('-mechanic-registry-authority.v1'));
  if(!registries.length)throw new Error('NO_MECHANIC_REGISTRY_SOURCES');
  for(const registry of registries){
   define('AUTHORITY',registry.json.authorityId,registry.json,{authority_kind:'MECHANIC_REGISTRY',authority_profile:registry.json.registryType},[observe(registry,'',registry.json,'AUTHORITY',registry.json.authorityId)]);
   for(const [i,p]of registry.json.graphProviderProfiles.entries()){const o=observe(registry,'/graphProviderProfiles/'+i,p,'PROVIDER_PROFILE',p.profileId),d=define('PROVIDER_PROFILE',p.profileId,p,{profile_name:null,profile_authority:registry.json.authorityId},[o]);for(const [ordinal,key]of ['effectClassification','testimonyRequired'].entries())if(Object.hasOwn(p,key))ds.member('provider_profile_constraint',{provider_profile_version_pk:d.provider_profile_version_pk,ordinal,constraint_kind:'DECLARED_REQUIREMENT',constraint_term:key,operand_content_pk:ds.json(p[key]).content_object_pk},d,'/semantics/'+key,[o]);}
  }
 const irc=ds.json({rule:'pinned-platform-coverage.v1',mapping_digest:ds.rule.rule_digest.toString('hex')});const ir=ds.add('analysis.integrity_rule',{rule_id:'pinned-platform-coverage.v1',rule_digest:irc.content_digest,layer:1,rule_content_pk:irc.content_object_pk});
 // Carry existing reference gaps into the expanded source generation with their exact new observations.
 const carriedInputs=[...new Set(ds.rows.get('analysis.unresolved_reference').filter(r=>r.estate_model_pk===baseModel.estate_model_pk).map(r=>observationMap.get(r.source_observation_pk)))].sort((a,b)=>a-b);
 const assessment=ds.add('analysis.assessment',{estate_model_pk:ds.model.estate_model_pk,integrity_rule_pk:ir.integrity_rule_pk,assessment_kind:'INTEGRITY',scope_digest:ds.snapshot.snapshot_digest,input_set_digest:bytesDigest(canonical(carriedInputs)),evaluation_state:'EVALUATED',evaluated_at:new Date(evaluatedAt)});
 const oldFindings=new Map(ds.rows.get('analysis.integrity_finding').map(f=>[f.integrity_finding_pk,f]));
 for(const r of ds.rows.get('analysis.unresolved_reference').slice())if(r.estate_model_pk===baseModel.estate_model_pk){const old=oldFindings.get(r.finding_pk),observation=observationMap.get(r.source_observation_pk);let finding=null;if(old){finding=clone('analysis.integrity_finding',old,{assessment_pk:assessment.assessment_pk,source_observation_pk:observation,finding_digest:bytesDigest(canonical({role:r.reference_role,observation,state:r.resolution_state}))});}ds.add('analysis.assessment_source_input',{assessment_pk:assessment.assessment_pk,source_observation_pk:observation,role:'CARRIED_REFERENCE_INPUT'},{dedup:true});clone('analysis.unresolved_reference',r,{estate_model_pk:ds.model.estate_model_pk,source_observation_pk:observation,finding_pk:finding?.integrity_finding_pk??null});}
 const classes=ds.rows.get('source.source_classification').filter(r=>r.mapping_rule_pk===ds.rule.mapping_rule_pk),coverage={total_count:classes.length,normalized_count:0,unresolved_count:0,unsupported_count:0,outside_count:0};
 for(const c of classes)coverage[{SUPPORTED:'normalized_count',AMBIGUOUS:'unresolved_count',UNSUPPORTED:'unsupported_count',OUTSIDE_SCOPE:'outside_count'}[c.classification_state]]++;
 const ca=ds.add('analysis.assessment',{estate_model_pk:ds.model.estate_model_pk,integrity_rule_pk:ir.integrity_rule_pk,assessment_kind:'COVERAGE',scope_digest:ds.snapshot.snapshot_digest,input_set_digest:bytesDigest(canonical(classes.map(r=>r.source_appearance_pk))),evaluation_state:'EVALUATED',evaluated_at:new Date(evaluatedAt)});
 ds.add('analysis.coverage_assessment',{assessment_pk:ca.assessment_pk,assessment_kind:'COVERAGE',source_profile:'pinned-platform-closure.v1',count_unit:'APPEARANCE',...coverage});
 const sourceByPk=new Map(ds.rows.get('source.source_appearance').map(a=>[a.source_appearance_pk,a]));ds.artifactReport=classes.map(c=>({path:sourceByPk.get(c.source_appearance_pk).source_path,family:c.family_code,state:c.classification_state}));
 ds.baseCounts=baseCounts;ds.summary={snapshot:snapshotId,manifest:ds.model.mapping_manifest_digest.toString('hex'),counts:ds.counts(),added:Object.fromEntries([...ds.rows].map(([n,r])=>[n,r.length-(baseCounts[n]??0)]).filter(([,n])=>n)),platform:{providers:providers.size,mechanics:mechanics.size,providerMechanicImplementations:implementationPairs.size,bootstrapRevision:cfg.bootstrapRevision},coverage};
 validateKeys(ds);return ds;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){const ds=await platform();await fs.mkdir(new URL('../../data/platform/',import.meta.url),{recursive:true});await fs.writeFile(new URL('../../data/platform/preview.json',import.meta.url),JSON.stringify(ds.summary,null,2));console.log(JSON.stringify(ds.summary,null,2));}
