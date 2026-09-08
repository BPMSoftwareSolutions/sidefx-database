import fs from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';
import {platform} from '../src/migration/platform.mjs';
import {parseJson} from '../src/migration/data.mjs';
import {EVALUATED_AT,differences,platformExpectation,readExpectations,snapshotAppearances} from '../src/migration/expectations.mjs';

// One run, two independent subtests. A moved count reports itself without
// stopping the invariants below it from running.
const dataset=platform({evaluatedAt:EVALUATED_AT});

test('pinned platform supplies declared mechanic identities and unique provider implementation pairs',async()=>{
 const d=await dataset;
 // The complete candidate includes shared operations before any model is published.
 assert.ok(d.rows.get('source.estate_model').every(r=>r.publication_state==='BUILDING'));
 const sharedIds=new Set(d.rows.get('model.execution_authority').filter(r=>['resolve-governed-agent-step.v1','materialize-admitted-feature-source.v1'].includes(r.execution_authority_id)).map(r=>r.execution_authority_pk));
 const sharedVersions=new Set(d.rows.get('model.execution_authority_version').filter(r=>sharedIds.has(r.execution_authority_pk)).map(r=>r.execution_authority_version_pk));
 assert.ok(d.rows.get('model.execution_operation').filter(r=>sharedVersions.has(r.execution_authority_version_pk)).length>=16);
 const links=d.rows.get('model.provider_mechanic_implementation');
 assert.equal(new Set(links.map(r=>r.provider_definition_pk+':'+r.mechanic_version_pk)).size,links.length,'a provider implements a mechanic at most once');
 const providerDefs=new Set(d.rows.get('model.provider_definition').map(r=>r.provider_definition_pk)),mechanicDefs=new Set(d.rows.get('model.mechanic_version').map(r=>r.mechanic_version_pk));
 assert.ok(links.every(r=>providerDefs.has(r.provider_definition_pk)&&mechanicDefs.has(r.mechanic_version_pk)));
 const names=new Set(d.rows.get('model.provider').map(r=>r.provider_id));
 assert.ok(names.has('ScenarioKernel.NodePlatform'));
 assert.ok(!names.has('sda-node-consumer-runtime.v1'),'platform capability IDs are not provider IDs');
 // Every declared registry source becomes an ingested registry authority with
 // its profiles. Without this, reading only one registry looks indistinguishable
 // from reading all of them, and only a hard-coded row count objects.
 const cfg=parseJson(await fs.readFile(new URL('../config/platform-normalization.json',import.meta.url)));
 const declaredRegistries=cfg.sources.filter(f=>f.endsWith('-mechanic-registry.authority.v1.json'));
 const registryAuthorities=d.rows.get('model.authority_definition').filter(r=>r.authority_kind==='MECHANIC_REGISTRY');
 assert.equal(registryAuthorities.length,declaredRegistries.length,'every declared mechanic registry is ingested as a registry authority');
 assert.ok(d.rows.get('model.provider_profile').length>=registryAuthorities.length,'each registry authority contributes at least one provider profile');
 const sourcePks=snapshotAppearances(d);
 const observationPks=new Set(d.rows.get('source.source_observation').filter(r=>sourcePks.has(r.source_appearance_pk)).map(r=>r.source_observation_pk));
 assert.ok(d.rows.get('source.source_lineage').filter(r=>r.mapping_rule_pk===d.rule.mapping_rule_pk).every(r=>observationPks.has(r.source_observation_pk)));
 for(const t of ['model.provider','model.mechanic'])assert.ok(d.rows.get(t).every(r=>r[t.split('.')[1]+'_id']));
});

test('platform generation matches the committed expectations',async()=>{
 const drift=differences((await readExpectations()).platform,platformExpectation(await dataset));
 assert.deepEqual(drift,[],'inputs moved; review the change and regenerate with npm run expectations\n'+drift.join('\n'));
});
