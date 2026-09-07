import test from 'node:test';
import assert from 'node:assert/strict';
import {platform} from '../src/migration/platform.mjs';
import {canonical} from '../src/migration/data.mjs';

test('pinned platform supplies declared mechanic identities and unique provider implementation pairs',async()=>{
 const d=await platform({evaluatedAt:'2026-09-07T12:00:00.000Z'});
 assert.equal(d.rows.get('model.mechanic').length,191);
 assert.equal(d.rows.get('model.provider_mechanic_implementation').length,314);
 assert.equal(d.rows.get('model.provider').length,74);
 assert.equal(d.rows.get('model.provider_profile').length,2);
 assert.equal(d.rows.get('model.contract').length,616);
 assert.equal(d.rows.get('model.operation_state_projection').length,3);
 assert.equal(d.rows.get('model.fixture_assertion_condition').length,432);
 assert.equal(d.rows.get('model.blueprint_fan_out_set').length,3);
 // The complete candidate includes shared operations before any model is published.
 assert.ok(d.rows.get('source.estate_model').every(r=>r.publication_state==='BUILDING'));
 const sharedIds=new Set(d.rows.get('model.execution_authority').filter(r=>['resolve-governed-agent-step.v1','materialize-admitted-feature-source.v1'].includes(r.execution_authority_id)).map(r=>r.execution_authority_pk));
 const sharedVersions=new Set(d.rows.get('model.execution_authority_version').filter(r=>sharedIds.has(r.execution_authority_pk)).map(r=>r.execution_authority_version_pk));
 assert.ok(d.rows.get('model.execution_operation').filter(r=>sharedVersions.has(r.execution_authority_version_pk)).length>=16);
 const links=d.rows.get('model.provider_mechanic_implementation');
 assert.equal(new Set(links.map(r=>r.provider_definition_pk+':'+r.mechanic_version_pk)).size,314);
 const providerDefs=new Set(d.rows.get('model.provider_definition').map(r=>r.provider_definition_pk)),mechanicDefs=new Set(d.rows.get('model.mechanic_version').map(r=>r.mechanic_version_pk));
 assert.ok(links.every(r=>providerDefs.has(r.provider_definition_pk)&&mechanicDefs.has(r.mechanic_version_pk)));
 const names=new Set(d.rows.get('model.provider').map(r=>r.provider_id));
 assert.ok(names.has('ScenarioKernel.NodePlatform'));
 assert.ok(!names.has('sda-node-consumer-runtime.v1'),'platform capability IDs are not provider IDs');
 assert.equal(d.rows.get('model.estate_capability').filter(r=>r.estate_model_pk===d.model.estate_model_pk).length,219);
 const sourcePks=new Set(d.rows.get('source.source_appearance').filter(r=>r.estate_snapshot_pk===d.snapshot.estate_snapshot_pk).map(r=>r.source_appearance_pk));
 const observationPks=new Set(d.rows.get('source.source_observation').filter(r=>sourcePks.has(r.source_appearance_pk)).map(r=>r.source_observation_pk));
 assert.ok(d.rows.get('source.source_lineage').filter(r=>r.mapping_rule_pk===d.rule.mapping_rule_pk).every(r=>observationPks.has(r.source_observation_pk)));
 assert.equal(sourcePks.size,8183);
 for(const t of ['model.provider','model.mechanic'])assert.ok(d.rows.get(t).every(r=>r[t.split('.')[1]+'_id']));
});
