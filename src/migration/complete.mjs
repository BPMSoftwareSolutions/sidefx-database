import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {normalize} from './normalize.mjs';
import {canonical,parseJson,bytesDigest,validId,pointer} from './data.mjs';
import {tables,digest} from './catalog.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export async function complete({evaluatedAt=new Date().toISOString()}={}){
 const ds=await normalize(),baseCounts=ds.counts(),baseRule=ds.rule,baseModel=ds.model;
 const config=parseJson(await fs.readFile(path.join(root,'config/normalization-v2.json')));
 const implementation={};for(const f of ['src/migration/complete.mjs','config/normalization-v2.json'])implementation[f]=digest(await fs.readFile(path.join(root,f)));
 const rc=ds.json({...config,implementation,extendsRuleDigest:baseRule.rule_digest.toString('hex'),supersedesClassificationRuleDigest:baseRule.rule_digest.toString('hex')});
 ds.rule=ds.add('source.mapping_rule',{rule_id:config.ruleId,rule_digest:rc.content_digest,source_profile:config.profile,rule_content_object_pk:rc.content_object_pk,canonicalization_profile:config.canonicalization});
 ds.model=ds.add('source.estate_model',{estate_snapshot_pk:ds.snapshot.estate_snapshot_pk,mapping_manifest_digest:bytesDigest(canonical([{id:baseRule.rule_id,digest:baseRule.rule_digest.toString('hex')},{id:ds.rule.rule_id,digest:ds.rule.rule_digest.toString('hex')}])),publication_state:'BUILDING'});
 for(const r of [baseRule,ds.rule])ds.add('source.estate_model_rule',{estate_model_pk:ds.model.estate_model_pk,mapping_rule_pk:r.mapping_rule_pk});
 for(const name of ['model.estate_definition','model.estate_capability','model.observed_transition_resolution','model.observed_invocation_resolution'])for(const r of ds.rows.get(name).slice())if(r.estate_model_pk===baseModel.estate_model_pk)ds.add(name,{...r,estate_model_pk:ds.model.estate_model_pk});
 const snapshot=parseJson(await fs.readFile(path.join(root,'data/snapshots',ds.summary.snapshot.slice(7)+'.json')));
 const appearances=new Map(ds.rows.get('source.source_appearance').map(r=>[r.appearance_digest.toString('hex'),r]));
 const contents=new Map(ds.rows.get('source.content_object').map(r=>[r.content_object_pk,r]));
 const classification=new Map(ds.rows.get('source.source_classification').map(r=>[r.source_appearance_pk,{family:r.family_code,state:r.classification_state}]));
 const parsed=new Map();
 const artifacts=snapshot.artifacts.map(a=>{const appearance=appearances.get(a.artifactId.slice(7)),content=contents.get(appearance.content_object_pk);let json;if(a.sourcePath.endsWith('.json')&&a.byteLength<4000000){if(!parsed.has(a.contentDigest)){try{parsed.set(a.contentDigest,parseJson(content.content_bytes));}catch{parsed.set(a.contentDigest,undefined);}}json=parsed.get(a.contentDigest);}return {...a,appearance,content,json,...classification.get(appearance.source_appearance_pk)};});
 const issues=[],obsCache=new Map();
 const obs=(a,ptr,value,kind='DOCUMENT',id=null)=>{const key=a.artifactId+'\0'+ptr;let o=obsCache.get(key);if(!o){o=ds.observation(a.appearance,'v2:json-pointer:'+ptr,'DECLARATION',value,{kind,id});obsCache.set(key,o);}return o;};
 const ref=(a,ptr,value,role,code='MISSING_TARGET',message='The exact declared target is not present in the captured source.')=>{const o=ds.observation(a.appearance,'v2:reference:'+ptr,'RELATIONSHIP',value,{role,target:typeof value==='string'?value:canonical(value)});issues.push({a,o,code,role,message});return o;};
 const ns=(kind,id)=>{const n=ds.namespace(kind,id);ds.add('source.namespace_mapping',{mapping_rule_pk:ds.rule.mapping_rule_pk,object_kind:kind,source_scope:id,namespace_pk:n.namespace_pk},{dedup:true});return n;};
 const def=(kind,id,scope,semantics,fields,sources)=>ds.definition(ds.identity(kind,id,ns(kind,scope)),semantics,fields,sources);
 const mark=(a,family,state='SUPPORTED')=>{a.family=family;a.state=state;};
 const definitions=new Map([...ds.definitions.values()].map(d=>[d.semantic_object_definition_pk,d]));
 const objectsByContent=new Map(),observationByPk=new Map(ds.rows.get('source.source_observation').map(o=>[o.source_observation_pk,o]));
 for(const l of ds.rows.get('source.source_lineage')){const o=observationByPk.get(l.source_observation_pk),a=ds.rows.get('source.source_appearance')[o.source_appearance_pk-1];if(!objectsByContent.has(a.content_object_pk))objectsByContent.set(a.content_object_pk,new Set());objectsByContent.get(a.content_object_pk).add(l.semantic_object_definition_pk);}
 // Repeated evidence attaches at the definition root. Existing member lineage remains exact.
 const representatives=new Map(),representativeContents=new Map();for(const a of artifacts)if(a.state==='SUPPORTED'){const k=a.contentDigest+'\0'+(a.family==='SCHEMA'||a.family==='CONTRACT_CATALOG'?'GLOBAL':a.capabilityId??'GLOBAL');if(!representatives.has(k))representatives.set(k,a);if(!representativeContents.has(a.contentDigest))representativeContents.set(a.contentDigest,new Map());representativeContents.get(a.contentDigest).set(k,a);}
 let aliases=0;
 for(const a of artifacts){if(a.state==='SUPPORTED'||!['MANAGED_CAPSULE','REPOSITORY_TRACKED'].includes(a.sourceClass))continue;const choices=representativeContents.get(a.contentDigest);const p=representatives.get(a.contentDigest+'\0'+(a.capabilityId??'GLOBAL'))??representatives.get(a.contentDigest+'\0GLOBAL')??(!a.capabilityId&&choices?.size===1?[...choices.values()][0]:null);if(!p)continue;
  const o=obs(a,'',a.json??a.content.content_bytes.toString('utf8'),'EXACT_SOURCE_ALIAS');
  for(const pk of objectsByContent.get(p.appearance.content_object_pk)??[]){const d=definitions.get(pk);if(d)ds.lineage(d.table,pk,'',[{...o,contribution_role:'EXACT_SOURCE_ALIAS'}]);}
  mark(a,p.family);aliases++;
 }
 // Schemas are shared by exact bytes; a schema without a catalog does not acquire a Contract ID.
 for(const a of artifacts)if(a.json!==undefined&&(/\.schema\.json$/.test(a.sourcePath)||/^https?:\/\/json-schema.org\//.test(a.json?.$schema??''))){ds.add('schema_object',{content_digest:a.content.content_digest,dialect:a.json?.$schema??null,content_object_pk:a.content.content_object_pk},{dedup:true});if(a.state==='OUTSIDE_SCOPE')mark(a,'SCHEMA');}
 const byContainer=new Map();for(const a of artifacts){const key=a.capsuleDigest??'REPOSITORY';if(!byContainer.has(key))byContainer.set(key,new Map());byContainer.get(key).set(a.entryId??a.sourcePath,a);}
 const libs=[['agentic',config.namespaceBindings.sharedAgentic],['feature-authoring',config.namespaceBindings.sharedFeatureAuthoring]];
 const shared=new Map();for(const [label,scope] of libs){
  const all=artifacts.filter(a=>a.sourceClass==='MANAGED_CAPSULE'||a.sourceClass==='REPOSITORY_TRACKED');
  const ports=new Map(),transforms=new Map();
  for(const a of all.filter(a=>(a.entryId??a.sourcePath)===`semantic-authority/${label}-interfaces.authority.json`&&a.json?.interfaceAuthorityType==='consumer-interface-authority.v1')){
   for(const [i,p]of (a.json.portBindings??[]).entries()){if(!validId(p.portId))continue;const d=def('PORT',p.portId,scope,p,{name:null,port_profile:'consumer-interface-authority.v1'},[obs(a,`/portBindings/${i}`,p,'PORT',p.portId)]);ports.set(p.portId,d);}
   mark(a,'PARTIAL_SHARED_INTERFACE','UNSUPPORTED');
  }
  for(const a of all.filter(a=>(a.entryId??a.sourcePath)===`semantic-authority/${label}-transformations.authority.json`&&Array.isArray(a.json?.transformations))){let full=true;
   for(const [i,t]of a.json.transformations.entries()){if(!validId(t.id)||!Object.hasOwn(t,'expression')){full=false;continue;}const o=obs(a,`/transformations/${i}`,t,'TRANSFORMATION',t.id),d=def('TRANSFORMATION',t.id,scope,t,{expression_profile:'json-expression-tree.v1'},[o]);transforms.set(t.id,d);
    if(ds.rows.get('model.transformation_root').some(r=>r.transformation_version_pk===d.transformation_version_pk))continue;
    const visit=(v,p)=>{const kind=Array.isArray(v)?'ARRAY':v&&typeof v==='object'?'OBJECT':'LITERAL';const n=ds.member('transformation_expression_node',{transformation_version_pk:d.transformation_version_pk,node_pointer:p,node_kind:kind,operator:null,literal_content_pk:kind==='LITERAL'?ds.json(v).content_object_pk:null,reference_name:null},d,'/semantics/expression'+p,[o]);if(kind!=='LITERAL')for(const [k,x]of Object.entries(v)){const ch=visit(x,p+'/'+pointer(k));ds.member('transformation_expression_child',{transformation_version_pk:d.transformation_version_pk,parent_node_pk:n.expression_node_pk,child_node_pk:ch.expression_node_pk,member_kind:kind==='ARRAY'?'ARRAY_MEMBER':'OBJECT_MEMBER',member_name:kind==='OBJECT'?k:null,ordinal:kind==='ARRAY'?Number(k):null},d,'/semantics/expression'+p+'/'+pointer(k),[o]);}return n;};
    const n=visit(t.expression,'');ds.member('transformation_root',{transformation_version_pk:d.transformation_version_pk,expression_node_pk:n.expression_node_pk},d,'/semantics/expression',[o]);
   }mark(a,full?'SHARED_TRANSFORMATION':'PARTIAL_SHARED_TRANSFORMATION',full?'SUPPORTED':'UNSUPPORTED');
  }
  for(const a of all.filter(a=>(a.entryId??a.sourcePath)===`contracts/${label}-contract-catalog.json`&&a.json)){let full=true;
   for(const [id,locator]of Object.entries(a.json)){if(!validId(id)||typeof locator!=='string'){full=false;continue;}const schema=byContainer.get(a.capsuleDigest??'REPOSITORY')?.get(path.posix.normalize(path.posix.join('contracts',locator)));if(!schema?.json){full=false;ref(a,'/'+pointer(id),locator,'CONTRACT_SCHEMA');continue;}
    const so=ds.add('schema_object',{content_digest:schema.content.content_digest,dialect:schema.json.$schema??null,content_object_pk:schema.content.content_object_pk},{dedup:true});def('CONTRACT',id,config.namespaceBindings.CONTRACT,{schema_digest:schema.content.content_digest.toString('hex')},{name:schema.json.title??null,contract_kind:null,schema_object_pk:so.schema_object_pk,schema_reference_state:'RESOLVED'},[obs(a,'/'+pointer(id),locator,'CONTRACT',id),obs(schema,'',schema.json,'SCHEMA')]);mark(schema,'SCHEMA');
   }mark(a,full?'SHARED_CONTRACT_CATALOG':'PARTIAL_SHARED_CONTRACT_CATALOG',full?'SUPPORTED':'UNSUPPORTED');
  }
  for(const a of all.filter(a=>(a.entryId??a.sourcePath)===`semantic-authority/${label}-execution-authorities.authority.json`&&Array.isArray(a.json?.executionAuthorities))){let full=true;
   for(const [i,e]of a.json.executionAuthorities.entries()){if(!validId(e.id)||!Array.isArray(e.operations)){full=false;continue;}const o=obs(a,`/executionAuthorities/${i}`,e,'EXECUTION_AUTHORITY',e.id),d=def('EXECUTION_AUTHORITY',e.id,scope,e,{authority_profile:'execution-authorities.v1'},[o]);
    for(const [j,op]of e.operations.entries()){const p=ports.get(op.portId);if(op.kind!=='invoke-port'||!p){full=false;ref(a,`/executionAuthorities/${i}/operations/${j}`,op,'EXECUTION_OPERATION');continue;}
     const ptr=`/semantics/operations/${j}`;const r=ds.member('execution_operation',{execution_authority_version_pk:d.execution_authority_version_pk,operation_id:op.operationId??null,ordinal:j,operation_kind:'invoke-port'},d,ptr,[o]);ds.member('operation_port_invocation',{execution_operation_pk:r.execution_operation_pk,port_version_pk:p.port_version_pk,operation_kind:'invoke-port'},d,ptr,[o]);
    }
   }mark(a,full?'SHARED_EXECUTION_AUTHORITY':'PARTIAL_SHARED_EXECUTION_AUTHORITY',full?'SUPPORTED':'UNSUPPORTED');
  }shared.set(label,{ports,transforms});
 }
 // Empty declared graphs still have a complete, inspectable zero-member mapping.
 for(const a of artifacts)if(['MANAGED_CAPSULE','REPOSITORY_TRACKED'].includes(a.sourceClass)&&/^semantic-authority\/(agentic|feature-authoring)-scenario-graph.authority.json$/.test(a.entryId??a.sourcePath)&&Array.isArray(a.json?.transitions)&&a.json.transitions.length===0&&Object.keys(a.json).length===1){obs(a,'',a.json,'EMPTY_SEMANTIC_GRAPH');mark(a,'OBSERVED_SEMANTIC_GRAPH');}
 // Runtime projections stay outside the approved initial semantic authority scope.
 for(const a of artifacts)if(a.sourceClass==='MANAGED_RUNTIME')mark(a,'RUNTIME_PROJECTION','OUTSIDE_SCOPE');
 const caps=new Map([...ds.definitions.values()].filter(d=>d.object_kind==='CAPABILITY').map(d=>[d.capability_id,d]));
 for(const a of artifacts){const j=a.json;if(!j||!['MANAGED_CAPSULE','REPOSITORY_TRACKED'].includes(a.sourceClass))continue;
  if(validId(j.authorityId)&&validId(j.authorityType??j.policyType??j.profileType)&&!/receipt|conformance|evidence|schema/i.test(j.authorityType??j.policyType??j.profileType)&&!a.sourcePath.startsWith('docs/')){const profile=j.authorityType??j.policyType??j.profileType;def('AUTHORITY',j.authorityId,config.namespaceBindings.AUTHORITY,j,{authority_kind:'DECLARED',authority_profile:profile},[obs(a,'',j,'AUTHORITY',j.authorityId)]);mark(a,'DECLARED_AUTHORITY');}
  if(j.runtimeType==='sfx-process-runtime.v1'&&validId(j.providerId)&&j.capabilities){const d=def('PROVIDER',j.providerId,config.namespaceBindings.PROVIDER,j,{name:null,declaration_profile:j.runtimeType},[obs(a,'',j,'PROVIDER',j.providerId)]);let full=true;
   for(const [id,locator]of Object.entries(j.capabilities)){const cap=caps.get(id),pin=j.artifacts?.[locator],matches=artifacts.filter(x=>x.contentDigest===pin&&x.json?.capabilityId===id);if(!cap||!matches.some(x=>x.sourceClass==='MANAGED_CAPSULE')){full=false;ref(a,'/capabilities/'+pointer(id),{id,locator,digest:pin??null},'PROVIDER_CAPABILITY');continue;}ds.member('provider_capability_implementation',{provider_definition_pk:d.provider_definition_pk,capability_version_pk:cap.capability_version_pk,role:'DECLARES_IMPLEMENTATION'},d,'/semantics/capabilities/'+pointer(id),[obs(a,'/capabilities/'+pointer(id),locator,'CAPABILITY_REFERENCE',id)]);}
   if(j.profileId)ref(a,'/profileId',j.profileId,'PROVIDER_PROFILE');mark(a,'PARTIAL_PROVIDER_RUNTIME',full&&!j.profileId?'SUPPORTED':'UNSUPPORTED');
  }
 }
 const byDigest=new Map();for(const a of artifacts){if(!byDigest.has(a.contentDigest))byDigest.set(a.contentDigest,[]);byDigest.get(a.contentDigest).push(a);}
 const allDefs=[...ds.definitions.values()],scenarioDefs=allDefs.filter(d=>d.object_kind==='SCENARIO');
 const faceMaps=Object.fromEntries(['input','event','outcome'].map(role=>[role,new Map(ds.rows.get('model.scenario_'+role).map(r=>[r.scenario_version_pk,r]))]));
 let declaredBlueprints=0,loadedBlueprints=0,observedEdges=0;
 for(const a of artifacts.filter(a=>a.sourceClass==='MANAGED_CAPSULE'&&a.entryId==='blueprint.authority.json'&&a.json?.carrierVersion==='canonical-circuit-blueprint.v1')){
  declaredBlueprints++;const j=a.json,cap=caps.get(j.capability?.capabilityId),pin=j.capability?.capabilityAuthorityDigest;
  const matched=(byDigest.get(pin)??[]).some(x=>x.capsuleDigest===a.capsuleDigest&&/\.feature(?:\.local)?$/.test(x.entryId??'')&&(objectsByContent.get(x.appearance.content_object_pk)??new Set()).has(cap?.semantic_object_definition_pk));
  if(!cap||!matched||!validId(j.blueprintAuthority?.blueprintId)){ref(a,'/capability',j.capability??null,'BLUEPRINT_CAPABILITY','DEFINITION_UNRESOLVED','Blueprint feature authority is not an exact contribution to the selected capability definition.');mark(a,'UNRESOLVED_BLUEPRINT_CAPABILITY','AMBIGUOUS');continue;}
  const o=obs(a,'',j,'BLUEPRINT',j.blueprintAuthority.blueprintId),d=def('BLUEPRINT',j.blueprintAuthority.blueprintId,config.namespaceBindings.BLUEPRINT,j,{capability_pk:cap.capability_pk,capability_version_pk:cap.capability_version_pk,carrier_profile:j.carrierVersion,source_disposition:j.sourceAuthority?.disposition??'UNSPECIFIED'},[o]);loadedBlueprints++;
  for(const [i,n]of (j.nodes??[]).entries()){if(!validId(n.nodeId)||!Number.isInteger(n.projectionOrdinal)||n.projectionOrdinal<0){ref(a,`/nodes/${i}`,n,'BLUEPRINT_NODE','PROFILE_UNSUPPORTED','Node lacks its required declared ID or projection ordinal.');continue;}const ptr='/semantics/nodes/'+i,r=ds.member('blueprint_node',{blueprint_version_pk:d.blueprint_version_pk,node_id:n.nodeId,node_kind:n.kind,altitude:n.altitude,projection_ordinal:n.projectionOrdinal,semantic_object_definition_pk:null,expected_semantic_kind:null,terminal_disposition:n.terminalDisposition??null},d,ptr,[o]);
   if(n.cell){const pinsMatch=n.altitude==='CAPABILITY'&&[n.cell.first?.contract?.digest,n.cell.energized?.authority?.digest,n.cell.result?.contract?.digest].every(x=>x===pin);const candidates=pinsMatch?scenarioDefs.filter(s=>s.capability_pk===cap.capability_pk&&faceMaps.input.get(s.scenario_version_pk)?.input_id===n.cell.first?.identity&&faceMaps.event.get(s.scenario_version_pk)?.event_id===n.cell.energized?.identity&&faceMaps.outcome.get(s.scenario_version_pk)?.outcome_id===n.cell.result?.identity):[];if(candidates.length===1){const s=candidates[0];ds.member('blueprint_node_scenario',{blueprint_version_pk:d.blueprint_version_pk,blueprint_node_pk:r.blueprint_node_pk,scenario_version_pk:s.scenario_version_pk},d,ptr,[o]);for(const [position,role]of [['FIRST','input'],['ENERGIZED','event'],['RESULT','outcome']]){const face=faceMaps[role].get(s.scenario_version_pk);ds.member('blueprint_node_face',{blueprint_node_pk:r.blueprint_node_pk,position,semantic_object_definition_pk:face.semantic_object_definition_pk,expected_kind:face.object_kind},d,ptr+'/cell/'+({input:'first',event:'energized',outcome:'result'}[role]),[o]);}}else ref(a,`/nodes/${i}/cell`,n.cell,'BLUEPRINT_SCENARIO_FACES',candidates.length?'AMBIGUOUS_TARGET':'MISSING_TARGET');}
   if(n.providerSlot){const slot=ds.member('provider_slot',{blueprint_version_pk:d.blueprint_version_pk,slot_id:n.nodeId,owner_node_pk:r.blueprint_node_pk},d,ptr+'/providerSlot',[o]);const ps=allDefs.filter(p=>p.object_kind==='PORT'&&p.port_id===n.providerSlot.portId&&p.address.namespace==='sidefx:capability:'+cap.capability_id);if(ps.length===1)ds.member('slot_port_requirement',{provider_slot_pk:slot.provider_slot_pk,port_version_pk:ps[0].port_version_pk,ordinal:0,role:n.providerSlot.mode??null},d,ptr+'/providerSlot/portId',[o]);else ref(a,`/nodes/${i}/providerSlot`,n.providerSlot,'SLOT_PORT',ps.length?'AMBIGUOUS_TARGET':'MISSING_TARGET');}
   for(const [k,p]of (n.requiredProducts??[]).entries())ref(a,`/nodes/${i}/requiredProducts/${k}`,p,'CONVERGENCE_PRODUCT');
  }
  for(const [i,e]of (j.edges??[]).entries()){observedEdges++;ref(a,'/edges/'+i,e,'BLUEPRINT_EDGE','DEFINITION_UNRESOLVED','Edge requires exact binding authority and applicable Product/variant endpoints. The captured historical authority pins do not resolve; no normalized edge was fabricated.');}
  if(j.structuralMapping)ref(a,'/structuralMapping',j.structuralMapping,'C4_REALIZATION_AUTHORITY','DEFINITION_UNRESOLVED');
  mark(a,'PARTIAL_CANONICAL_BLUEPRINT','UNSUPPORTED');
 }
 // Record real document values for unimplemented profiles, rather than v1's null placeholders.
 for(const a of artifacts)if(['UNSUPPORTED','AMBIGUOUS'].includes(a.state))obs(a,'',a.json??a.content.content_bytes.toString('utf8'),'UNMAPPED_DOCUMENT');
 const content=ds.json({rule:'inspection-completeness-coverage.v2',mapping_digest:ds.rule.rule_digest.toString('hex')});const ir=ds.add('analysis.integrity_rule',{rule_id:'inspection-completeness-coverage.v2',rule_digest:content.content_digest,layer:1,rule_content_pk:content.content_object_pk});
 const newObs=ds.rows.get('source.source_observation').slice(baseCounts['source.source_observation']);
 const assessment=ds.add('analysis.assessment',{estate_model_pk:ds.model.estate_model_pk,integrity_rule_pk:ir.integrity_rule_pk,assessment_kind:'INTEGRITY',scope_digest:ds.snapshot.snapshot_digest,input_set_digest:bytesDigest(canonical(newObs.map(o=>o.source_observation_pk))),evaluation_state:'EVALUATED',evaluated_at:new Date(evaluatedAt)});
 for(const o of newObs)ds.add('analysis.assessment_source_input',{assessment_pk:assessment.assessment_pk,source_observation_pk:o.source_observation_pk,role:'MAPPING_INPUT'});
 for(const x of issues){const f=ds.add('analysis.integrity_finding',{assessment_pk:assessment.assessment_pk,finding_digest:bytesDigest(canonical({observation:x.o.source_observation_pk,role:x.role,code:x.code})),finding_code:x.code,severity:'WARNING',source_observation_pk:x.o.source_observation_pk,subject_definition_pk:null,expected_content_pk:null,observed_content_pk:null,message:x.message},{dedup:true});ds.add('analysis.unresolved_reference',{estate_model_pk:ds.model.estate_model_pk,source_observation_pk:x.o.source_observation_pk,reference_role:x.role,resolution_state:x.code,finding_pk:f.integrity_finding_pk},{dedup:true});}
 // Keep unresolved v1 references visible in the new model as well.
 for(const r of ds.rows.get('analysis.unresolved_reference').slice())if(r.estate_model_pk===baseModel.estate_model_pk)ds.add('analysis.unresolved_reference',{...r,estate_model_pk:ds.model.estate_model_pk});
 for(const a of artifacts)ds.add('source.source_classification',{source_appearance_pk:a.appearance.source_appearance_pk,mapping_rule_pk:ds.rule.mapping_rule_pk,family_code:a.family,classification_state:a.state});
 const coverage=[];for(const family of [...new Set(artifacts.map(a=>a.family))].sort()){const xs=artifacts.filter(a=>a.family===family),count=s=>xs.filter(a=>a.state===s).length;const a=ds.add('analysis.assessment',{estate_model_pk:ds.model.estate_model_pk,integrity_rule_pk:ir.integrity_rule_pk,assessment_kind:'COVERAGE',scope_digest:bytesDigest(family),input_set_digest:bytesDigest(canonical(xs.map(a=>a.artifactId).sort())),evaluation_state:'EVALUATED',evaluated_at:new Date(evaluatedAt)});const r=ds.add('analysis.coverage_assessment',{assessment_pk:a.assessment_pk,assessment_kind:'COVERAGE',source_profile:family,count_unit:'APPEARANCE',total_count:xs.length,normalized_count:count('SUPPORTED'),unresolved_count:count('AMBIGUOUS'),unsupported_count:count('UNSUPPORTED'),outside_count:count('OUTSIDE_SCOPE')});coverage.push(r);}
 ds.baseCounts=baseCounts;ds.artifactReport=artifacts.map(a=>({path:a.sourcePath,entry:a.entryId,sourceClass:a.sourceClass,digest:a.contentDigest,family:a.family,state:a.state}));
 ds.summary={snapshot:snapshot.snapshotId,manifest:ds.model.mapping_manifest_digest.toString('hex'),counts:ds.counts(),added:Object.fromEntries([...ds.rows].map(([n,r])=>[n,r.length-(baseCounts[n]??0)]).filter(([,n])=>n)),aliases,declaredBlueprints,loadedBlueprints,observedEdges,newReferenceGaps:issues.length,coverage:coverage.reduce((s,r)=>{for(const k of ['total_count','normalized_count','unresolved_count','unsupported_count','outside_count'])s[k]=(s[k]??0)+r[k];return s;},{})};
 return ds;
}
export function validateKeys(ds){for(const [name,rows]of ds.rows){const t=tables.get(name);for(const cols of [t.pk,...t.aks]){const seen=new Set();for(const r of rows){const key=canonical(cols.map(c=>Buffer.isBuffer(r[c])?r[c].toString('hex'):r[c]));if(seen.has(key))throw new Error('DUPLICATE_CANDIDATE_KEY:'+name+':'+cols.join(',')+':'+key);seen.add(key);}}}return true;}
if(process.argv[1]===fileURLToPath(import.meta.url)){const ds=await complete();validateKeys(ds);await fs.writeFile(path.join(root,'data/completeness/normalization-preview.json'),JSON.stringify(ds.summary,null,2));await fs.writeFile(path.join(root,'data/completeness/appearance-coverage.json'),JSON.stringify(ds.artifactReport,null,2));console.log(JSON.stringify(ds.summary,null,2));}
