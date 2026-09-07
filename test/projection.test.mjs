import test from 'node:test';
import assert from 'node:assert/strict';
import { hash,digest,resolvePointer,safePath } from '../src/core.mjs';
import { decodeCapsule } from '../src/snapshot/capture.mjs';
import { MODEL } from '../src/derive/model.mjs';
import { projectArtifact } from '../src/derive/project.mjs';

function project(doc,{file='capabilities/sample/semantic-graph.authority.json',entry='semantic-graph.authority.json',cls='MANAGED_CAPSULE'}={}) {
  const bytes=Buffer.from(typeof doc==='string'?doc:JSON.stringify(doc));
  const a={artifactId:hash({file}),capabilityId:'sample',sourcePath:file,entryId:entry,sourceClass:cls,contentDigest:digest(bytes)};
  const rows=Object.fromEntries(Object.keys(MODEL).map(t=>[t,[]])),catalog=[];
  projectArtifact(a,bytes,rows,catalog);return {rows,catalog};
}
test('raw identity is byte-sensitive and map canonicalization is ordered',()=>{
  assert.notEqual(digest('{"a":1}'),digest('{ "a": 1 }'));
  assert.equal(hash({b:2,a:1}),hash({a:1,b:2}));
});
test('capsule decoding rejects tampering and path escapes',()=>{
  const bytes=Buffer.from('{"capabilityId":"sample"}');
  const cap={capsuleFormat:'sidefx-capsule-pack.v1',capsuleFormatVersion:'1.0.0',capabilityId:'sample',entries:[{entryId:'capability.authority.json',entryRef:'capabilities/sample/capability.authority.json',entryDigest:digest(bytes),entryBytesBase64:bytes.toString('base64')}]};
  assert.equal(decodeCapsule(Buffer.from(JSON.stringify(cap))).entries.length,1);
  const bad=structuredClone(cap);bad.entries[0].entryBytesBase64=Buffer.from('{}').toString('base64');
  assert.throws(()=>decodeCapsule(Buffer.from(JSON.stringify(bad))),/ENTRY_DIGEST_MISMATCH/);
  bad.entries[0].entryRef='../escape';assert.throws(()=>decodeCapsule(Buffer.from(JSON.stringify(bad))),/UNSAFE/);
  assert.throws(()=>safePath('C:/root','/absolute'),/ESCAPES/);
});
test('JSON pointers retain escaped key identity',()=>assert.equal(resolvePointer({'a/b':{'~key':[7]}},'/a~1b/~0key/0'),7));
test('fixture payload authority does not become live scenarios or transitions',()=>{
  const {rows}=project({fixtures:[{fixtureId:'negative',input:{transitions:[{from:'A',to:'B'}],scenarios:[{scenarioId:'fake'}]},expected:{terminalScenarioId:'finish',scenarioSequence:['start','finish']}}]});
  assert.equal(rows.scenario.length,0);assert.equal(rows.observed_semantic_graph_transition.length,0);assert.equal(rows.fixture_scenario.length,2);
});
test('topology representations remain separate despite conflicting endpoints',()=>{
  const graph=project({transitions:[{transitionId:'t',from:{scenarioId:'A'},to:{scenarioId:'B'}}]});
  const execution=project({executionAuthorities:[{id:'e',owningScenarioId:'A',operations:[{kind:'invoke-scenario',scenarioId:'C'}]}]});
  assert.equal(graph.rows.observed_semantic_graph_transition[0].to_scenario_id,'B');
  assert.equal(execution.rows.observed_execution_invoke_scenario[0].to_scenario_id,'C');
  assert.equal(execution.rows.observed_semantic_graph_transition.length,0);
});
test('Gherkin rules, outlines and docstrings preserve scenario boundary',()=>{
  const source=`@capability:sample\nFeature: Sample\n  Rule: Rule one\n    @scenario:real\n    @input:request\n    @input-contract:request.v1\n    @event:go\n    @event-authority:go.v1\n    @outcome:done\n    @outcome-contract:done.v1\n    @outcome-terminal\n    Scenario Outline: Real <value>\n      Given a description\n        \"\"\"\n        Scenario: fake inside docstring\n        \"\"\"\n      Examples:\n        | value |\n        | one   |\n`;
  const result=project(source,{file:'features/sample.feature',entry:'features/{id}.feature'});
  assert.equal(result.rows.scenario.length,1);assert.equal(result.rows.scenario[0].scenario_id,'real');assert.equal(result.rows.scenario[0].terminal,true);assert.equal(result.rows.scenario[0].pointer_kind,'LINE');
});
test('shared copies and provisioned tokens cannot be primary managed authority',()=>{
  const shared=project({transitions:[{from:'a',to:'b'}]},{file:'semantic-authority/shared.json'});
  assert.equal(shared.rows.observed_semantic_graph_transition[0].is_primary,false);
  const provisional=project({transitions:[{from:'a',to:'b'}]},{cls:'PROVISIONED_CAPSULE'});
  assert.equal(provisional.rows.observed_semantic_graph_transition[0].origin_layer,'PROVISIONED');
});
test('v3 slots and overlay bindings are independently observable',()=>{
  const result=project({executionEmbodimentPlanType:'consumer-execution-embodiment-plan.v3',canonicalGraph:{requiredProviderSlots:[{slotId:'slot-a',cellId:'a',mechanicId:'m'}],edges:[{edgeId:'e',from:{cellId:'a'},to:{cellId:'b'},kind:'sequence'}]},realizationOverlay:{providerBindings:[{slotId:'slot-a',mechanicId:'m',providerProfileId:'provider-one'}]}},{file:'capsule-runtime/sample/execution-plan.node.json',cls:'MANAGED_RUNTIME'});
  assert.equal(result.rows.provider_slot[0].declared_provider_id,null);assert.equal(result.rows.provider_binding[0].provider_id,'provider-one');assert.equal(result.rows.observed_runtime_route[0].to_id,'b');
});
test('declared SideFX feature entries are owned; fixture resources remain testimony',()=>{
  const source='@capability:sample\nFeature: Sample\n @scenario:one\n Scenario: One\n  Given something\n';
  const semantic=project(source,{file:'authority/sidefx-semantic-brain/capabilities/sample/capability.feature',entry:'features/{id}.feature.sidefx'});
  assert.equal(semantic.rows.scenario[0].is_primary,true);assert.equal(semantic.rows.scenario[0].origin_layer,'AUTHORITY');
  const fixture=project(source,{file:'capabilities/sample/fixtures/resources/example.feature',entry:'fixtures/resources/example.feature'});
  assert.equal(fixture.rows.scenario[0].is_primary,false);assert.equal(fixture.rows.scenario[0].origin_layer,'FIXTURE_RESOURCE');
});
test('unknown and malformed content stays visible in extraction coverage',()=>{
  assert.equal(project({newUnknownAuthority:42}).catalog[0].status,'JSON_ARCHIVED');
  const bad=project('{bad json');assert.equal(bad.catalog[0].status,'PARSE_FAILED');assert.equal(bad.rows.extraction_issue[0].code,'JSON_PARSE_FAILED');
});
