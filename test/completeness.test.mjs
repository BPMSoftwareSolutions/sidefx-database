import test from 'node:test';
import assert from 'node:assert/strict';
import {complete,validateKeys} from '../src/migration/complete.mjs';
import {rowDigest} from '../src/migration/load-complete.mjs';
import {EVALUATED_AT,classifiedAppearances,completeExpectation,differences,readExpectations} from '../src/migration/expectations.mjs';

// One run, two independent subtests. A moved count reports itself without
// stopping the invariants below it from running.
const dataset=complete({evaluatedAt:EVALUATED_AT});

test('frozen snapshot extension preserves identity, rejects unresolved pins, and accounts for every appearance',async()=>{
 const ds=await dataset;
 assert.equal(validateKeys(ds),true);
 for(const kind of ['product','mechanic','provider_profile','blueprint_edge'])assert.equal(ds.rows.get('model.'+kind).length,0,'missing declarations must not become '+kind+' entities');
 const classification=classifiedAppearances(ds);
 assert.equal(new Set(classification.map(r=>r.source_appearance_pk)).size,classification.length,'no appearance is classified twice');
 assert.equal(Object.values(ds.summary.coverage).slice(1).reduce((a,b)=>a+b,0),classification.length,'every classified appearance lands in exactly one coverage bucket');
 assert.ok(ds.summary.loadedBlueprints<=ds.summary.declaredBlueprints,'a blueprint cannot load without being declared');
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

test('base generation matches the committed expectations',async()=>{
 const drift=differences((await readExpectations()).complete,completeExpectation(await dataset));
 assert.deepEqual(drift,[],'inputs moved; review the change and regenerate with npm run expectations\n'+drift.join('\n'));
});
