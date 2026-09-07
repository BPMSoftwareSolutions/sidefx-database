import test from 'node:test';
import assert from 'node:assert/strict';
import {complete,validateKeys} from '../src/migration/complete.mjs';
import {rowDigest} from '../src/migration/load-complete.mjs';

test('frozen snapshot extension preserves identity, rejects unresolved pins, and accounts for every appearance',async()=>{
 const ds=await complete({evaluatedAt:'2026-09-07T12:00:00.000Z'});
 assert.equal(validateKeys(ds),true);
 assert.equal(ds.rows.get('model.capability').length,219);
 assert.equal(ds.rows.get('model.scenario').length,824);
 assert.equal(ds.rows.get('model.provider').length,5);
 for(const kind of ['product','mechanic','provider_profile','blueprint_edge'])assert.equal(ds.rows.get('model.'+kind).length,0,'missing declarations must not become '+kind+' entities');
 assert.equal(ds.summary.declaredBlueprints,49);
 assert.equal(ds.summary.loadedBlueprints,35);
 assert.ok(ds.rows.get('model.blueprint_node').length>400);
 const classification=ds.rows.get('source.source_classification').filter(r=>r.mapping_rule_pk===ds.rule.mapping_rule_pk);
 assert.equal(classification.length,8178);
 assert.equal(new Set(classification.map(r=>r.source_appearance_pk)).size,8178);
 assert.equal(Object.values(ds.summary.coverage).slice(1).reduce((a,b)=>a+b,0),8178);
 const shared=ds.rows.get('model.identity_namespace').find(r=>r.namespace_id==='sidefx:shared:agentic'&&r.namespace_kind==='TRANSFORMATION');
 assert.equal(ds.rows.get('model.transformation').filter(r=>r.namespace_pk===shared.namespace_pk&&r.transformation_id==='resolve-governed-agent-step.v1').length,1);
 const contents=new Map(ds.rows.get('source.content_object').map(r=>[r.content_object_pk,r]));
 for(const schema of ds.rows.get('model.schema_object').slice(ds.baseCounts['model.schema_object'])){
  const body=JSON.parse(contents.get(schema.content_object_pk).content_bytes.toString('utf8'));
  assert.notEqual(body.runtimeType,'sfx-process-runtime.v1','instances with $schema must not become schema definitions');
 }
 const data=ds.rows.get('model.blueprint');
 assert.equal(rowDigest('model.blueprint',data),rowDigest('model.blueprint',[...data].reverse()));
 const changed=data.map((r,i)=>i? r:{...r,blueprint_id:r.blueprint_id+'-tampered'});
 assert.notEqual(rowDigest('model.blueprint',data),rowDigest('model.blueprint',changed),'resume must detect modified rows even when counts match');
});
