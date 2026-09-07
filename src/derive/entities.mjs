import { MODEL } from './model.mjs';
import { hash,stable,compare } from '../core.mjs';

const spec=(source,keys,fields,selection='authority',scope=true)=>({source,keys,fields,selection,scope});
const own=(table,key,fields,selection='authority')=>spec(table,['capability_id',...key.split(',')],['capability_id',...fields.split(',')],selection);
const global=(table,key,fields,selection='knowledge')=>spec(table,key.split(','),fields.split(','),selection,false);
// Keys express actual identity scope. Ordered anonymous children use their declared
// parent and array ordinal. Source appearances are linked separately, never entities.
export const ENTITIES={
  capability:spec('capability',['capability_id'],['capability_id','name','version','root_scenario_id','experience_id','lifecycle']),
  feature:own('feature','capability_id','name,language,description,scenario_count','feature'),
  scenario:own('scenario','scenario_id','scenario_id,name,terminal,input_id,input_contract_id,event_id,execution_authority_id,outcome_id,outcome_contract_id','feature'),
  input:own('input','input_id','input_id,contract_id','feature'),
  event:own('event','event_id','event_id,execution_authority_id','feature'),
  outcome:own('outcome','outcome_id','outcome_id,contract_id,terminal','feature'),
  outcome_variant:own('outcome','scenario_id,variant_id','scenario_id,variant_id,observable_condition_count','variant'),
  product:own('product','product_id','product_id,contract_id,product_role','feature'),
  contract:own('contract','contract_id','contract_id,schema_ref'),
  schema:global('schema','schema_id','schema_id,dialect,title,declared_type'),
  blueprint_node:own('blueprint_node','node_id','node_id,kind,altitude,ordinal'),
  blueprint_edge:own('blueprint_edge','edge_id','edge_id,from_id,to_id,topology,variant_id'),
  execution_authority:own('execution_authority','execution_authority_id','execution_authority_id,scenario_id,operation_count'),
  operation:own('operation','execution_authority_id,ordinal','execution_authority_id,ordinal,scenario_id,kind,port_id,target_scenario_id,mechanic_binding_id,structural_digest'),
  transformation:own('transformation','transformation_id','transformation_id,expression_digest'),
  mechanic:global('mechanic','mechanic_id','mechanic_id,mechanic_type','runtime'),
  port:own('port','port_id','port_id,provider_id,transformation_id,binding_kind'),
  provider_slot:own('provider_slot','slot_id','slot_id,cell_id,port_id,mechanic_id,declared_provider_id,profile_constraints','authority-runtime'),
  provider:spec('provider',['provider_id'],['provider_id','capability_id','authority_id','lifecycle','responsibility']),
  external_provider:global('external_provider','provider_id','provider_id,name'),
  external_provider_capability:global('external_provider_capability','provider_id,bound_capability_id,verb,object','provider_id,bound_capability_id,verb,object'),
  provider_binding:own('provider_binding','binding_kind,binding_id','binding_kind,binding_id,slot_id,cell_id,port_id,mechanic_id,provider_id,provider_digest,implementation_ref,binding_digest','authority-runtime'),
  interface:own('interface','interface_id','interface_id,kind,root_scenario_id,target_capability_id'),
  fixture:own('fixture','fixture_id','fixture_id,terminal_scenario_id,expected_disposition,assertion_count'),
  fixture_scenario:own('fixture_scenario','fixture_id,ordinal','fixture_id,ordinal,scenario_id'),
  fixture_assertion:own('fixture_assertion','fixture_id,ordinal','fixture_id,ordinal,assertion_path,operator,value_json,target_scenario_id'),
  proof_obligation:global('proof_obligation','obligation_id','obligation_id,kind,status,subject_id'),
  evidence:global('evidence','evidence_digest','evidence_digest,kind,disposition,declared_digest'),
  projection_authority:own('projection_authority','projection_authority_id','projection_authority_id,kind,input_contract_id,output_contract_id'),
  dependency:own('dependency','target_capability_id','target_capability_id,target_digest,binding_ref,binding_digest,dependency_kind','dependency'),
  semantic_term:global('semantic_term','vocabulary_kind,term_id','vocabulary_kind,term_id,label,normalized_label,definition'),
  term_relationship:global('term_relationship','relationship_id','relationship_id,from_term_id,to_term_id,kind'),
  classification:global('classification','subject_id,classification','subject_id,classification,classified_kind'),
  fact:global('fact','fact_id','fact_id,subject_id,predicate,object_id,value_json'),
  fact_relationship:global('fact_relationship','relationship_id','relationship_id,from_fact_id,to_fact_id,kind'),
  semantic_object:global('semantic_object','semantic_object_id','semantic_object_id,canonical_id,kind'),
  semantic_object_relationship:global('semantic_object_relationship','relationship_id','relationship_id,from_semantic_object_id,to_semantic_object_id,kind'),
  precedent:global('precedent','precedent_id','precedent_id,subject_id,kind'),
  pattern_candidate:global('pattern_candidate','pattern_id','pattern_id,kind,status')
};
ENTITIES.feature.keys=['capability_id'];
for(const e of Object.values(ENTITIES))e.fields=[...new Set(e.fields)];
export const entityColumns=name=>Object.fromEntries(ENTITIES[name].fields.map(k=>[k,k==='capability_id'?'n':MODEL[ENTITIES[name].source][k]]));
export const entityMetadata={row_id:'d',resolution_status:'n',source_count:'i',conflict_fields_json:'x'};
export const entityRequired=(name,key)=>ENTITIES[name].keys.includes(key)||key==='capability_id'||key==='bound_capability_id'||Object.hasOwn(entityMetadata,key);
export const REFERENCES=[
  ['scenario',['capability_id','execution_authority_id'],'execution_authority',['capability_id','execution_authority_id']],
  ['event',['capability_id','execution_authority_id'],'execution_authority',['capability_id','execution_authority_id']],
  ['operation',['capability_id','execution_authority_id'],'execution_authority',['capability_id','execution_authority_id']],
  ['fixture_scenario',['capability_id','fixture_id'],'fixture',['capability_id','fixture_id']],
  ['fixture_assertion',['capability_id','fixture_id'],'fixture',['capability_id','fixture_id']],
  ['blueprint_edge',['capability_id','from_id'],'blueprint_node',['capability_id','node_id']],
  ['blueprint_edge',['capability_id','to_id'],'blueprint_node',['capability_id','node_id']],
  ['dependency',['target_capability_id'],'capability',['capability_id']],
  ['external_provider_capability',['provider_id'],'external_provider',['provider_id']],
  ['external_provider_capability',['bound_capability_id'],'capability',['capability_id']],
  ['semantic_object_relationship',['from_semantic_object_id'],'semantic_object',['semantic_object_id']],
  ['semantic_object_relationship',['to_semantic_object_id'],'semantic_object',['semantic_object_id']],
  ['fact_relationship',['from_fact_id'],'fact',['fact_id']],
  ['fact_relationship',['to_fact_id'],'fact',['fact_id']]
];
const validKey=v=>Number.isInteger(v)||typeof v==='string'&&v.length>0&&v.length<=256&&v.trim()===v;
export function buildEntities(snapshot,rows) {
  const artifacts=new Map(snapshot.artifacts.map(a=>[a.artifactId,a]));
  const managed=new Set(rows.capability.filter(r=>r.is_primary&&r.origin_layer==='AUTHORITY').map(r=>r.capability_id));
  const entities={},sources={},findings=[],coverage={};
  const finding=(table,code,subject,detail)=>{const f={entity_table:table,code,subject_key:subject,detail_json:stable(detail)};findings.push({row_id:hash(f),...f});};
  for(const [table,e] of Object.entries(ENTITIES)) {
    const groups=new Map();let eligible=0,unidentified=0;
    for(const r of rows[e.source]) {
      const a=artifacts.get(r.artifact_id);
      if(!a)throw new Error('ENTITY_SOURCE_ARTIFACT_MISSING');
      const authority=r.is_primary&&r.origin_layer==='AUTHORITY';
      const runtime=r.is_primary&&r.origin_layer==='RUNTIME';
      if(e.scope&&!managed.has(r.capability_id))continue;
      if(e.selection==='authority'&&!authority)continue;
      if(e.selection==='runtime'&&!runtime)continue;
      if(e.selection==='authority-runtime'&&!authority&&!runtime)continue;
      if(e.selection==='feature'&&(!authority||r.pointer_kind!=='LINE'||!a.entryId?.startsWith('features/{id}.feature')))continue;
      if(e.selection==='variant'&&(!authority||r.variant_id===null))continue;
      if(e.selection==='knowledge'&&['FIXTURE_RESOURCE','CAPSULE_EVIDENCE','PROVISIONED'].includes(r.origin_layer))continue;
      eligible++;
      if(r.bound_capability_id!==undefined&&!managed.has(r.bound_capability_id)) {
        unidentified++;finding(table,'TARGET_NOT_IN_MANAGED_ESTATE',r.row_id,{capability_id:r.bound_capability_id,artifact_id:r.artifact_id,source_pointer:r.source_pointer});continue;
      }
      const missing=e.keys.filter(k=>!validKey(r[k]));
      if(missing.length){unidentified++;finding(table,'SOURCE_IDENTITY_MISSING',r.row_id,{columns:missing,artifact_id:r.artifact_id,source_pointer:r.source_pointer});continue;}
      const key=stable(e.keys.map(k=>r[k]));
      if(!groups.has(key))groups.set(key,[]);
      groups.get(key).push(r);
    }
    entities[table]=[];sources[table]=[];
    for(const [key,group] of groups) {
      const row_id=hash({entity:table,key:JSON.parse(key)}),conflicts=[];
      const values=Object.fromEntries(e.fields.map(k=>{
        const observed=new Map(group.filter(r=>r[k]!==null).map(r=>[stable(r[k]),r[k]]));
        if(observed.size>1)conflicts.push(k);
        return [k,observed.size===1?[...observed.values()][0]:null];
      }));
      for(const k of e.fields.filter(k=>entityRequired(table,k)))if(!validKey(values[k]))throw new Error('INVALID_ENTITY_IDENTITY:'+table+':'+k);
      if(conflicts.length)finding(table,'CONFLICTING_ENTITY_ATTRIBUTES',row_id,{key:JSON.parse(key),fields:conflicts,observations:group.map(r=>r.row_id).sort(compare)});
      entities[table].push({row_id,...values,resolution_status:conflicts.length?'CONFLICTING_DECLARATIONS':'RESOLVED',source_count:group.length,conflict_fields_json:stable(conflicts.sort(compare))});
      for(const r of group)sources[table].push({entity_row_id:row_id,observation_row_id:r.row_id});
    }
    entities[table].sort((a,b)=>compare(a.row_id,b.row_id));
    sources[table].sort((a,b)=>compare(stable(a),stable(b)));
    coverage[table]={eligibleObservations:eligible,unresolvedObservations:unidentified,entities:entities[table].length,sourceLinks:sources[table].length};
    if(eligible!==unidentified+sources[table].length)throw new Error('ENTITY_SOURCE_ACCOUNTING_MISMATCH');
  }
  for(const [from,columns,to,target] of REFERENCES) {
    const keys=new Set(entities[to].map(r=>stable(target.map(k=>r[k]))));
    for(const r of entities[from])if(columns.every(k=>r[k]!==null)&&!keys.has(stable(columns.map(k=>r[k]))))finding(from,'UNRESOLVED_ENTITY_REFERENCE',r.row_id,{columns,target_table:to,target_columns:target,values:columns.map(k=>r[k])});
  }
  const uniqueFindings=[...new Map(findings.map(r=>[r.row_id,r])).values()].sort((a,b)=>compare(a.row_id,b.row_id));
  validateEntities(entities,sources,rows,managed.size);
  return {entities,entitySources:sources,integrityFindings:uniqueFindings,entityCoverage:coverage};
}
export function validateEntities(entities,sources,rows,expectedCapabilities) {
  const caps=new Set(entities.capability.map(r=>r.capability_id));
  if(caps.size!==expectedCapabilities)throw new Error('ENTITY_CAPABILITY_COVERAGE_MISMATCH');
  for(const [name,e] of Object.entries(ENTITIES)) {
    const keys=new Set(),ids=new Set(),observations=new Set(rows[e.source].map(r=>r.row_id));
    for(const r of entities[name]) {
      for(const k of e.fields.filter(k=>entityRequired(name,k)))if(!validKey(r[k]))throw new Error('ENTITY_NULL_OR_INVALID_KEY:'+name+':'+k);
      const key=stable(e.keys.map(k=>r[k]));
      if(keys.has(key)||ids.has(r.row_id))throw new Error('DUPLICATE_ENTITY_KEY:'+name);
      keys.add(key);ids.add(r.row_id);
      if(r.capability_id!==undefined&&!caps.has(r.capability_id))throw new Error('ENTITY_CAPABILITY_ORPHAN:'+name);
      if(r.bound_capability_id!==undefined&&!caps.has(r.bound_capability_id))throw new Error('ENTITY_BOUND_CAPABILITY_ORPHAN:'+name);
    }
    const links=new Set(),counts=new Map();
    for(const r of sources[name]) {
      if(!ids.has(r.entity_row_id)||!observations.has(r.observation_row_id))throw new Error('ENTITY_SOURCE_ORPHAN:'+name);
      const key=stable(r);if(links.has(key))throw new Error('DUPLICATE_ENTITY_SOURCE:'+name);links.add(key);
      counts.set(r.entity_row_id,(counts.get(r.entity_row_id)??0)+1);
    }
    for(const r of entities[name])if(!counts.get(r.row_id)||counts.get(r.row_id)!==r.source_count)throw new Error('ENTITY_SOURCE_COUNT_MISMATCH:'+name);
  }
}
