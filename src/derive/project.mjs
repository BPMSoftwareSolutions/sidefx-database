import fs from 'node:fs/promises';
import path from 'node:path';
import { ROOT, readBlob, hash, digest, stable, compare, escapePointer, digestToken, writeJson, receipt } from '../core.mjs';
import { MODEL, commonColumns } from './model.mjs';
import { parseFeature, featureScenarios, tagsToValues } from './feature.mjs';
import { loadSnapshot } from '../snapshot/capture.mjs';
import { buildEntities } from './entities.mjs';

export const RULE_VERSION='sidefx-observed-projection.v2';
const array=v=>Array.isArray(v)?v:[];
const text=v=>typeof v==='string'?v:null;
const identity=v=>text(v) ?? text(v?.scenarioId) ?? text(v?.nodeId) ?? text(v?.cellId) ?? text(v?.identity) ?? text(v?.id);
const contract=v=>text(v?.contractId) ?? text(v?.authorityId) ?? text(v);
export function validateCapabilityIdentity(id) {
  if(typeof id!=='string'||!id.length||id.trim()!==id||id.length>256)throw new Error('INVALID_DECLARED_CAPABILITY_ID');
  return id;
}
export function validateCapabilityIntegrity(snapshot,rows) {
  const declared=new Set();
  for(const r of rows.capability) {
    validateCapabilityIdentity(r.capability_id);
    if(JSON.parse(r.payload_json).capabilityId!==r.capability_id)throw new Error('CAPABILITY_DECLARED_ID_MISMATCH');
    if(r.is_primary&&['AUTHORITY','PROVISIONED'].includes(r.origin_layer)&&r.container_capability_id!==r.capability_id)throw new Error('CAPABILITY_CONTAINER_ID_MISMATCH');
  }
  const expected=snapshot.artifacts.filter(a=>a.sourceClass==='MANAGED_CAPSULE'&&a.entryId==='capability.authority.json');
  if(expected.length!==snapshot.verified.capabilityCount||new Set(expected.map(a=>a.capabilityId)).size!==expected.length)throw new Error('MANAGED_CAPABILITY_SOURCE_IDENTITY_VIOLATION');
  const sources=new Map(expected.map(a=>[a.capabilityId,a]));
  for(const r of rows.capability.filter(r=>r.is_primary&&r.origin_layer==='AUTHORITY')) {
    validateCapabilityIdentity(r.capability_id);
    if(declared.has(r.capability_id))throw new Error('DUPLICATE_MANAGED_CAPABILITY_ID:'+r.capability_id);
    declared.add(r.capability_id);
    const a=sources.get(r.capability_id);
    if(!a||a.artifactId!==r.artifact_id||a.contentDigest!==a.authorityDigest||!r.is_primary||r.origin_layer!=='AUTHORITY')throw new Error('MANAGED_CAPABILITY_SOURCE_MISMATCH');
    if(JSON.parse(r.payload_json).capabilityId!==r.capability_id)throw new Error('CAPABILITY_DECLARED_ID_MISMATCH');
  }
  if(declared.size!==sources.size)throw new Error('MANAGED_CAPABILITY_COVERAGE_MISMATCH');
  return {managedCapabilities:declared.size,capabilityObservations:rows.capability.length};
}
export function primaryArtifact(a) {
  if(a.entryId==='capability.authority.json')return Boolean(a.capabilityId);
  if(a.entryId?.startsWith('features/{id}.feature'))return Boolean(a.capabilityId);
  if(a.entryId?.startsWith('fixtures/resources/')||a.entryId?.startsWith('capsule-closure/'))return false;
  return Boolean(a.capabilityId && (a.sourcePath.startsWith(`capabilities/${a.capabilityId}/`) || a.sourcePath.startsWith(`capsule-runtime/${a.capabilityId}/`) || a.sourcePath===`features/${a.capabilityId}.feature`));
}
export function layer(a) {
  if(a.sourceClass.includes('PROVISIONED')) return 'PROVISIONED';
  if(a.sourceClass==='MANAGED_RUNTIME') return 'RUNTIME';
  if(a.sourceClass==='MANAGED_CAPSULE'&&a.entryId?.startsWith('fixtures/resources/'))return 'FIXTURE_RESOURCE';
  if(a.sourceClass==='MANAGED_CAPSULE'&&a.entryId?.startsWith('capsule-closure/'))return 'CAPSULE_EVIDENCE';
  if(a.sourceClass==='MANAGED_CAPSULE') return primaryArtifact(a)?'AUTHORITY':'SHARED_AUTHORITY';
  return 'REPOSITORY';
}
function expressionShape(v) {
  if(Array.isArray(v))return v.map(expressionShape);
  if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).filter(([k])=>!['operationId','id','scenarioId','scenarioNodeId','portId','mechanicBindingId'].includes(k)).map(([k,x])=>[k,expressionShape(x)]));
  return v;
}
export function projectArtifact(a, bytes, rows, catalog) {
  const origin=layer(a), primary=primaryArtifact(a);
  function add(table,pointer,value,fields={},rule=table,pointerKind='JSON_POINTER') {
    if(!MODEL[table]) throw new Error('UNKNOWN_PROJECTION_TABLE:'+table);
    const base={ artifact_id:a.artifactId, capability_id:a.capabilityId, is_primary:primary, origin_layer:origin, source_pointer:pointer, pointer_kind:pointerKind, derivation_rule:RULE_VERSION+':'+rule, object_digest:hash(value), payload_json:stable(value) };
    const normalize=(value,type)=>value==null?null:type==='b'?Boolean(value):type==='i'?Number(value):typeof value==='string'?value:stable(value);
    const row={row_id:hash({artifact:a.artifactId,table,pointer,rule}),...base,...Object.fromEntries(Object.entries(MODEL[table]).map(([k,t])=>[k,normalize(fields[k],t)]))};
    if(Object.values(row).some(x=>x===undefined)) throw new Error('UNDEFINED_ROW_FIELD');
    rows[table].push(row);
    return row;
  }
  function issue(code,detail,pointer='') { add('extraction_issue',pointer,{code,detail},{code,detail,severity:'OBSERVATION_GAP'},code); }
  let sourceText;
  try { sourceText=new TextDecoder('utf-8',{fatal:true}).decode(bytes); }
  catch { catalog.push({artifact_id:a.artifactId,format:'BINARY',status:'ARCHIVED_BINARY',root_type:null});return; }
  if(a.sourcePath.endsWith('.feature')) {
    try {
      const doc=parseFeature(sourceText), feature=doc.feature;
      if(!feature) throw new Error('Missing Feature');
      const scenarios=featureScenarios(feature);
      add('feature',`line:${feature.location.line}`,feature,{name:feature.name,language:feature.language,description:feature.description,scenario_count:scenarios.length},'gherkin-feature','LINE');
      for(const {scenario:s,inherited} of scenarios) {
        const tags=tagsToValues([...inherited,...s.tags]), get=k=>text(tags[k]?.at(-1));
        const sid=get('scenario'), pointer=`line:${s.location.line}`;
        const fields={scenario_id:sid,name:s.name,terminal:tags['outcome-terminal']?true:false,input_id:get('input'),input_contract_id:get('input-contract'),event_id:get('event'),execution_authority_id:get('event-authority'),outcome_id:get('outcome'),outcome_contract_id:get('outcome-contract'),variant_count:null,observable_condition_count:null};
        add('scenario',pointer,s,fields,'gherkin-scenario','LINE');
        if(!sid) issue('SCENARIO_ID_NOT_DECLARED',s.name,pointer);
        add('input',pointer,s,{input_id:fields.input_id,scenario_id:sid,contract_id:fields.input_contract_id},'gherkin-input','LINE');
        add('event',pointer,s,{event_id:fields.event_id,scenario_id:sid,execution_authority_id:fields.execution_authority_id},'gherkin-event','LINE');
        add('outcome',pointer,s,{outcome_id:fields.outcome_id,scenario_id:sid,contract_id:fields.outcome_contract_id,terminal:fields.terminal},'gherkin-outcome','LINE');
        add('product',pointer,s,{product_id:fields.outcome_id,scenario_id:sid,contract_id:fields.outcome_contract_id,product_role:'DECLARED_SCENARIO_OUTCOME'},'gherkin-product','LINE');
        for(const [kind,label] of [['scenario',sid],['input',fields.input_id],['event',fields.event_id],['outcome',fields.outcome_id]]) if(label) add('semantic_term',pointer,s,{term_id:label,label,normalized_label:label.toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(),vocabulary_kind:kind},'gherkin-term-'+kind,'LINE');
      }
      catalog.push({artifact_id:a.artifactId,format:'GHERKIN',status:'TYPED',root_type:'Feature'});
    } catch(e) { issue('GHERKIN_PARSE_FAILED',e.message);catalog.push({artifact_id:a.artifactId,format:'GHERKIN',status:'PARSE_FAILED',root_type:null}); }
    return;
  }
  let j;
  try { j=JSON.parse(sourceText); }
  catch {
    const expected=a.sourcePath.endsWith('.json') || a.sourcePath.endsWith('.sfxcap');
    if(expected)issue('JSON_PARSE_FAILED','Exact bytes retained; JSON parsing failed.');
    catalog.push({artifact_id:a.artifactId,format:expected?'JSON':'TEXT',status:expected?'PARSE_FAILED':'ARCHIVED_TEXT',root_type:null});return;
  }
  let typed=false;
  const rootType=text(j?.authorityType)??text(j?.carrierVersion)??text(j?.executionEmbodimentPlanType)??text(j?.receiptType)??text(j?.$schema);
  const beforeCount=Object.values(rows).reduce((sum,r)=>sum+r.length,0);
  if(j?.capsuleFormat) {
    for(let i=0;i<array(j.declaredDependencies).length;i++){const d=j.declaredDependencies[i];add('dependency','/declaredDependencies/'+i,d,{target_capability_id:text(d.capabilityId)??text(d),target_version:text(d.capabilityVersion)??text(d.version),target_digest:text(d.capabilityAuthorityDigest)??text(d.capsuleDigest)??text(d.digest),binding_ref:text(d.bindingRef),binding_digest:text(d.bindingDigest),dependency_kind:'CAPSULE_DECLARATION'});}
  }
  if(a.entryId==='capability.authority.json'||a.sourcePath.endsWith('/capability.authority.json')) {
    const declaredId=validateCapabilityIdentity(j?.capabilityId);
    if(primary&&['AUTHORITY','PROVISIONED'].includes(origin)&&a.capabilityId!==declaredId)throw new Error('CAPABILITY_CONTAINER_ID_MISMATCH');
    const fields={name:j.name,root_scenario_id:j.rootScenarioId,experience_id:j.experience?.experienceId,lifecycle:text(j.lifecycle?.status)??text(j.lifecycle),version:j.version??j.capabilityVersion};
    const observation=add('capability','',j,{...fields,container_capability_id:a.capabilityId},'declared-capability-identity.v2');
    observation.capability_id=declaredId;
  }
  if(j && typeof j==='object' && (String(j.$schema).includes('json-schema.org')||a.sourcePath.endsWith('.schema.json'))) add('schema','',j,{schema_id:j.$id,dialect:j.$schema,title:j.title,declared_type:typeof j.type==='string'?j.type:null});
  if(a.sourcePath.endsWith('contract-catalog.json') && !Array.isArray(j)) {
    for(const [id,ref] of Object.entries(j)) if(typeof ref==='string')add('contract','/'+escapePointer(id),ref,{contract_id:id,schema_ref:ref});
  }
  function scenarios(values,prefix) {
    values.forEach((s,i)=>{
      const p=prefix+'/'+i;
      add('scenario',p,s,{scenario_id:s.scenarioId,name:s.name,terminal:s.outcome?.terminal,input_id:s.input?.inputId,input_contract_id:contract(s.input?.contract),event_id:s.event?.eventId,execution_authority_id:s.event?.executionAuthorityId,outcome_id:s.outcome?.outcomeId,outcome_contract_id:contract(s.outcome?.contract),variant_count:Array.isArray(s.outcome?.variants)?s.outcome.variants.length:null,observable_condition_count:Array.isArray(s.outcome?.observableConditions)?s.outcome.observableConditions.length:null},'observed-scenario');
    });
  }
  function operations(ops,prefix,sid,authority) {
    array(ops).forEach((op,i)=>{
      const p=prefix+'/'+i, oid=op.operationId??op.id;
      add('operation',p,op,{operation_id:oid,ordinal:i,scenario_id:sid,execution_authority_id:authority,kind:op.kind??op.op,port_id:op.portId,target_scenario_id:op.scenarioId??op.scenarioNodeId,mechanic_binding_id:op.mechanicBindingId,structural_digest:hash(expressionShape(op))});
      if(op.kind==='invoke-scenario')add('observed_execution_invoke_scenario',p,op,{operation_id:oid,from_scenario_id:sid,to_scenario_id:op.scenarioId??op.scenarioNodeId,execution_authority_id:authority});
    });
  }
  array(j?.executionAuthorities).forEach((x,i)=>{
    const p='/executionAuthorities/'+i,sid=x.owningScenarioId??x.scenarioId,id=x.id??x.executionAuthorityId;
    add('execution_authority',p,x,{execution_authority_id:id,scenario_id:sid,operation_count:array(x.operations).length});
    operations(x.operations,p+'/operations',sid,id);
  });
  array(j?.transformations).forEach((x,i)=>add('transformation','/transformations/'+i,x,{transformation_id:x.id??x.transformationId,expression_digest:hash(x.expression??x)}));
  array(j?.projectionAuthorities).forEach((x,i)=>add('projection_authority','/projectionAuthorities/'+i,x,{projection_authority_id:x.id??x.projectionAuthorityId,kind:x.kind,input_contract_id:contract(x.inputContract),output_contract_id:contract(x.outputContract)}));
  array(j?.interfaces).forEach((x,i)=>add('interface','/interfaces/'+i,x,{interface_id:x.interfaceId,kind:x.kind,root_scenario_id:x.rootScenarioId,target_capability_id:x.platformCapabilityId??x.capabilityId}));
  array(j?.portBindings).forEach((x,i)=>{
    const p='/portBindings/'+i;
    add('port',p,x,{port_id:x.portId,provider_id:x.platformCapabilityId,transformation_id:x.configuration?.transformationId,binding_kind:'DECLARED_PORT_BINDING'});
    add('provider_binding',p,x,{binding_id:x.portId,binding_kind:'PORT',port_id:x.portId,provider_id:x.platformCapabilityId,binding_digest:hash(x),mechanic_id:x.platformCapabilityId},'port-provider-binding');
  });
  array(j?.transitions).forEach((x,i)=>add('observed_semantic_graph_transition','/transitions/'+i,x,{transition_id:x.transitionId??x.id,from_scenario_id:identity(x.from)??x.fromScenarioId,to_scenario_id:identity(x.to)??x.toScenarioId,from_outcome_id:x.from?.outcomeId,to_input_id:x.to?.inputId,topology:x.topologyKind??x.kind,variant_id:x.selectsVariant}));
  array(j?.scenarioOutcomes).forEach((x,i)=>array(x.variants).forEach((v,k)=>add('outcome',`/scenarioOutcomes/${i}/variants/${k}`,v,{scenario_id:x.scenarioId,variant_id:identity(v)??v?.variantId,outcome_id:x.outcomeId,observable_condition_count:Array.isArray(v?.observableConditions)?v.observableConditions.length:null},'semantic-outcome-variant')));
  if(j?.carrierVersion?.startsWith('canonical-circuit-blueprint')) {
    array(j.nodes).forEach((x,i)=>{
      const p='/nodes/'+i;
      add('blueprint_node',p,x,{node_id:x.nodeId,kind:x.kind,altitude:x.altitude,ordinal:x.projectionOrdinal});
      if(x.providerSlot)add('provider_slot',p+'/providerSlot',x.providerSlot,{slot_id:x.nodeId,cell_id:x.nodeId,port_id:x.providerSlot.portId,declared_provider_id:x.providerSlot.providerId,mechanic_id:x.providerSlot.mechanicId},'blueprint-provider-slot');
      array(x.cell?.result?.variants).forEach((v,k)=>add('outcome',p+'/cell/result/variants/'+k,v,{scenario_id:x.nodeId,outcome_id:x.cell.result.identity,contract_id:contract(x.cell.result.contract),variant_id:v.variantId,observable_condition_count:Array.isArray(v.observableConditions)?v.observableConditions.length:null},'blueprint-outcome-variant'));
    });
    array(j.edges).forEach((x,i)=>{const fields={edge_id:x.edgeId,from_id:identity(x.from),to_id:identity(x.to),topology:x.topology??x.kind,variant_id:x.selectsVariant};add('blueprint_edge','/edges/'+i,x,fields);add('observed_blueprint_route','/edges/'+i,x,fields);});
  }
  if(j?.executionEmbodimentPlanType?.endsWith('.v2')) {
    array(j.nodes).forEach((x,i)=>{
      if(x.scenario) { const s=x.scenario,p='/nodes/'+i+'/scenario'; add('scenario',p,s,{scenario_id:s.scenarioId,terminal:s.outcome?.terminal,input_id:s.input?.inputId,input_contract_id:contract(s.input?.contract),event_id:s.event?.eventId,execution_authority_id:s.event?.executionAuthorityId,outcome_id:s.outcome?.outcomeId,outcome_contract_id:contract(s.outcome?.contract)},'runtime-scenario'); }
      operations(x.operations,'/nodes/'+i+'/operations',x.scenario?.scenarioId??x.nodeId,x.scenario?.event?.executionAuthorityId);
      if(x.transition)add('observed_runtime_route','/nodes/'+i+'/transition',x.transition,{edge_id:x.transition.transitionId,from_id:x.nodeId,to_id:identity(x.transition.to)??x.transition.targetNodeId,kind:'transition',altitude:'scenario'});
    });
    array(j.mechanicBindings).forEach((x,i)=>{
      const p='/mechanicBindings/'+i;
      add('mechanic',p,x,{mechanic_id:x.providerCapabilityId??x.mechanicType,binding_id:x.bindingId,mechanic_type:x.mechanicType,provider_id:x.providerCapabilityId,provider_name:x.provider,implementation_ref:x.implementationRef,configuration_digest:hash(x.configuration??{})});
      add('provider_binding',p,x,{binding_id:x.bindingId,binding_kind:'RUNTIME_V2',port_id:x.bindingId?.startsWith('port:')?x.bindingId.slice(5):null,provider_id:x.providerCapabilityId,mechanic_id:x.providerCapabilityId,implementation_ref:x.implementationRef,binding_digest:hash(x)},'runtime-v2-binding');
    });
  }
  if(j?.executionEmbodimentPlanType?.endsWith('.v3')) {
    array(j.canonicalGraph?.edges).forEach((x,i)=>add('observed_runtime_route','/canonicalGraph/edges/'+i,x,{edge_id:x.edgeId,from_id:identity(x.from),to_id:identity(x.to),kind:x.kind,altitude:'graph-cell'}));
    array(j.canonicalGraph?.requiredProviderSlots).forEach((x,i)=>add('provider_slot','/canonicalGraph/requiredProviderSlots/'+i,x,{slot_id:x.slotId,cell_id:x.cellId,mechanic_id:x.mechanicId,profile_constraints:stable(x.profileConstraints??[])},'runtime-v3-slot'));
    array(j.realizationOverlay?.providerBindings).forEach((x,i)=>{
      const p='/realizationOverlay/providerBindings/'+i;
      add('provider_binding',p,x,{binding_id:x.slotId,binding_kind:'RUNTIME_V3',slot_id:x.slotId,cell_id:x.cellId,mechanic_id:x.mechanicId,provider_id:x.providerProfileId,provider_digest:x.providerProfileDigest,implementation_ref:x.implementationRef,binding_digest:hash(x)},'runtime-v3-binding');
      add('mechanic',p,x,{mechanic_id:x.mechanicId,binding_id:x.slotId,mechanic_type:'v3-provider-slot',provider_id:x.providerProfileId,implementation_ref:x.implementationRef,configuration_digest:hash(x)},'runtime-v3-mechanic');
    });
  }
  array(j?.fixtures).forEach((x,i)=>{
    const p='/fixtures/'+i,id=x.fixtureId??x.id, expected=x.expected??{};
    add('fixture',p,x,{fixture_id:id,terminal_scenario_id:expected.terminalScenarioId,expected_disposition:expected.disposition,assertion_count:Array.isArray(expected.outcomeAssertions)?expected.outcomeAssertions.length:null});
    array(expected.scenarioSequence).forEach((s,k)=>add('fixture_scenario',p+'/expected/scenarioSequence/'+k,s,{fixture_id:id,scenario_id:identity(s),ordinal:k}));
    array(expected.outcomeAssertions).forEach((v,k)=>add('fixture_assertion',p+'/expected/outcomeAssertions/'+k,v,{fixture_id:id,ordinal:k,condition_id:v.conditionId,assertion_path:v.path,operator:v.operator,value_json:stable(v.value??null),target_scenario_id:expected.terminalScenarioId}));
  });
  if(j?.platformCapabilityId && typeof j.authorityId==='string'&&String(j.authorityType).includes('provider-authority'))add('provider','',j,{provider_id:j.platformCapabilityId,authority_id:j.authorityId,lifecycle:text(j.lifecycle)??text(j.lifecycle?.status),responsibility:text(j.responsibility)},'provider-authority');
  if(j?.receiptType||j?.receiptVersion||j?.evidenceType||j?.conformanceType) add('evidence','',j,{evidence_digest:hash(j),evidence_id:j.receiptId??j.evidenceId??j.authorityId,kind:j.receiptType??j.receiptVersion??j.evidenceType??j.conformanceType,disposition:j.disposition??j.assemblyDisposition,declared_digest:j.receiptDigest??j.evidenceDigest,subject_id:j.capabilityId??j.subjectId},'receipt-root');
  // Knowledge and obligation extraction is limited to declared root collections;
  // fixture payloads and expression constants never masquerade as observed authority.
  const collections={
    proofObligations:['proof_obligation',x=>({obligation_id:x.proofObligationId??x.obligationId??x.id,kind:x.kind,status:x.status??x.disposition,subject_id:x.subjectSemanticObjectId??x.subjectId})],
    obligations:['proof_obligation',x=>({obligation_id:x.obligationId??x.id??text(x),kind:x.kind,status:x.status??x.disposition,subject_id:x.subjectId})],
    semanticTerms:['semantic_term',x=>({term_id:x.termId??x.id,label:x.label??x.name,normalized_label:String(x.label??x.name??'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(),definition:x.definition,vocabulary_kind:'DECLARED_TERM'})],
    terms:['semantic_term',x=>({term_id:x.termId??x.id,label:x.label??x.name,normalized_label:String(x.label??x.name??'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(),definition:x.definition,vocabulary_kind:'DECLARED_TERM'})],
    termRelationships:['term_relationship',x=>({relationship_id:x.relationshipId??x.id,from_term_id:identity(x.from)??x.sourceTermId,to_term_id:identity(x.to)??x.targetTermId,kind:x.kind??x.relation})],
    classifications:['classification',x=>({subject_id:x.subjectId??x.semanticObjectId,classification:x.classification??x.sourceClass,classified_kind:x.kind})],
    facts:['fact',x=>({fact_id:x.factId??x.id,subject_id:x.subjectId??identity(x.subject),predicate:x.predicate??x.kind,object_id:x.objectId??identity(x.object),value_json:stable(x.value??null)})],
    relationships:['semantic_object_relationship',x=>({relationship_id:x.relationshipId??x.id,from_semantic_object_id:x.fromSemanticObjectId,to_semantic_object_id:x.toSemanticObjectId,kind:x.kind??x.relationshipType})],
    precedents:['precedent',x=>({precedent_id:x.precedentId??x.id,subject_id:x.capabilityId??x.subjectId,kind:x.kind??x.precedentClass})],
    patterns:['pattern_candidate',x=>({pattern_id:x.patternId??x.id,kind:x.kind,status:x.status??x.disposition})],
    candidates:['pattern_candidate',x=>({pattern_id:x.patternId??x.candidateId,kind:x.kind,status:x.status??x.disposition})]
  };
  if(j&&typeof j==='object'&&!Array.isArray(j)&&!j.$schema?.includes('json-schema.org')) {
    for(const [key,[table,fields]] of Object.entries(collections)) array(j[key]).forEach((x,i)=>{if(x!==null)add(table,'/'+key+'/'+i,x,fields(x),'declared-'+key);});
    if(Array.isArray(j.scenarios))scenarios(j.scenarios,'/scenarios');
    if(a.sourcePath==='authority/cli/provider-catalog.json')array(j.providers).forEach((x,i)=>{
      add('external_provider','/providers/'+i,x,{provider_id:x.providerId,name:x.name},'declared-external-provider-catalog');
      array(x.commandBindings).forEach((b,k)=>add('external_provider_capability',`/providers/${i}/commandBindings/${k}`,b,{provider_id:x.providerId,bound_capability_id:b.capabilityId,verb:b.verb,object:b.object},'declared-external-provider-command-binding'));
    });
    array(j.resources).forEach((x,i)=>{if(x.sourceClass)add('classification','/resources/'+i,x,{subject_id:x.resourceId,classification:x.sourceClass,classified_kind:'OBSERVED_SOURCE_RESOURCE'},'declared-resource-classification');});
    if(j.catalogType==='sidefx-semantic-object-catalog.v1')array(j.objects).forEach((x,i)=>{
      const p='/objects/'+i;
      add('semantic_object',p,x,{semantic_object_id:x.semanticObjectId,canonical_id:x.canonicalId,kind:x.kind},'declared-semantic-object-identity');
      add('classification',p,x,{subject_id:x.semanticObjectId,classification:x.sourceClass,classified_kind:x.kind},'declared-semantic-object');
      add('semantic_term',p,x,{term_id:x.canonicalId,label:x.searchRepresentation??x.canonicalId,normalized_label:String(x.canonicalId??'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(),definition:x.searchRepresentation,vocabulary_kind:x.kind},'declared-semantic-catalog-term');
      for(const [key,value] of Object.entries(x.attributes??{}))add('fact',p+'/attributes/'+escapePointer(key),value,{fact_id:x.semanticObjectId+'#'+key,subject_id:x.semanticObjectId,predicate:key,value_json:stable(value)},'declared-semantic-attribute');
    });
    if(j.ontologyType)for(const key of ['sourceClasses','populatedObjectKinds','reservedObjectKinds','relationshipKinds','relationshipDispositions'])array(j[key]).forEach((x,i)=>add('semantic_term','/'+key+'/'+i,x,{term_id:text(x),label:text(x),normalized_label:String(x).toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(),vocabulary_kind:key},'declared-ontology-term'));
    array(j.evidence).forEach((x,i)=>{if(x&&typeof x==='object')add('evidence','/evidence/'+i,x,{evidence_digest:hash(x),evidence_id:x.evidenceId??x.reference,kind:'DECLARED_EVIDENCE_REFERENCE',disposition:x.disposition,declared_digest:x.digest??x.evidenceDigest,subject_id:x.subjectId},'declared-evidence-reference');});
  }
  typed=Object.values(rows).reduce((sum,r)=>sum+r.length,0)>beforeCount;
  catalog.push({artifact_id:a.artifactId,format:'JSON',status:typed?'TYPED':'JSON_ARCHIVED',root_type:rootType});
}
export async function derive(snapshot, {persist=true}={}) {
  snapshot ??= await loadSnapshot();
  const rows=Object.fromEntries(Object.keys(MODEL).map(t=>[t,[]])),catalog=[];
  for(const a of snapshot.artifacts) {
    // Assign capsule envelope dependency rows to the capsule identity, never infer admission.
    let source=a;
    const bytes=await readBlob(a.contentDigest);
    if(a.sourcePath.endsWith('.sfxcap')) {
      const cap=JSON.parse(bytes.toString('utf8'));
      source={...a,capabilityId:cap.capabilityId};
    }
    projectArtifact(source,bytes,rows,catalog);
  }
  validateCapabilityIntegrity(snapshot,rows);
  // Dependency identity is resolved by the exact declared authority digest over
  // this frozen snapshot, never by guessing a capability name from a path.
  const authorities=new Map();
  for(const a of snapshot.artifacts.filter(a=>a.sourceClass==='MANAGED_CAPSULE'&&a.entryId==='capability.authority.json')) {
    if(!authorities.has(a.authorityDigest))authorities.set(a.authorityDigest,new Set());
    authorities.get(a.authorityDigest).add(a.capabilityId);
  }
  for(const r of rows.dependency)if(r.target_capability_id===null) {
    const candidates=authorities.get(r.target_digest);
    if(candidates?.size===1)r.target_capability_id=[...candidates][0];
  }
  const tableDigests={};
  for(const [table,values] of Object.entries(rows)) {
    values.sort((a,b)=>compare(a.row_id,b.row_id));
    if(new Set(values.map(r=>r.row_id)).size!==values.length)throw new Error('DUPLICATE_DERIVED_ROW:'+table);
    tableDigests[table]={rowCount:values.length,digest:hash(values)};
  }
  catalog.sort((a,b)=>compare(a.artifact_id,b.artifact_id));
  const normalized=buildEntities(snapshot,rows);
  const entityDigests=Object.fromEntries(Object.keys(normalized.entities).map(table=>[table,{rowCount:normalized.entities[table].length,digest:hash(normalized.entities[table]),sourceCount:normalized.entitySources[table].length,sourceDigest:hash(normalized.entitySources[table])}]));
  const sourceFiles=['src/core.mjs','src/derive/model.mjs','src/derive/project.mjs','src/derive/feature.mjs','src/derive/entities.mjs','package-lock.json'];
  const adapterDigest=hash(await Promise.all(sourceFiles.map(async file=>({file,digest:digest(await fs.readFile(path.join(ROOT,file)))}))));
  const body={snapshotId:snapshot.snapshotId,ruleVersion:RULE_VERSION,adapterDigest,tableDigests,catalogDigest:hash(catalog),entityDigests,integrityFindingsDigest:hash(normalized.integrityFindings),entityCoverage:normalized.entityCoverage};
  const projection={...body,projectionDigest:hash(body),rows,catalog,...normalized};
  if(persist) {
    const directory=path.join(ROOT,'data/projections',digestToken(projection.projectionDigest));
    for(const [name,values] of Object.entries(rows)) {
      await fs.mkdir(directory,{recursive:true});
      await fs.writeFile(path.join(directory,name+'.ndjson'),values.map(stable).join('\n')+(values.length?'\n':''));
    }
    await writeJson(path.join(directory,'manifest.json'),{...body,projectionDigest:projection.projectionDigest,catalog});
    await writeJson(path.join(directory,'entities.json'),normalized);
    await receipt('derive',{...body,projectionDigest:projection.projectionDigest,disposition:'DERIVED_OBSERVATIONS'});
  }
  return projection;
}
