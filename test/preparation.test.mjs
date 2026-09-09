import test from 'node:test';
import assert from 'node:assert/strict';
import { hash, stable } from '../src/core.mjs';
import { validatePreparation, preparationFormat } from '../src/runtime/preparation.mjs';

const selection = { capabilityId: 'example', scenarioId: 'declared-root', namespaceId: 'scope', target: 'node' };
const pins = { snapshotId: hash('snapshot'), projectionDigest: hash('projection'), viewDefinitionDigest: hash('resolver') };
function sample() {
  const result = recordsets => ({ ...pins, truncated: false, recordsets, resultDigest: hash(recordsets.map(rows => rows.map(stable).sort())) });
  return { preparationType: preparationFormat, recipeDigest: hash('recipe'), proof: { status: 'PASSED', fixtureCount: 1, artifacts: [{}] },
    bundle: { selection: { ...selection },
      authority: result([[{ capability_id: 'example', scenario_id: 'declared-root', namespace_id: 'scope' }], [], []]),
      resolutions: result([[], [{ target_language: 'node', readiness: 'CAN_ATTEMPT_EMBODIMENT', open_requirement_count: 0 }], []]), mechanics: result([[]]) } };
}

test('preparation is bound to every revision, resolver and selection axis', () => {
  const value = sample();
  assert.equal(validatePreparation(value, { ...pins, recipeDigest: value.recipeDigest, selection }), value);
  for (const field of Object.keys(pins).concat('recipeDigest'))
    assert.throws(() => validatePreparation(value, { ...pins, recipeDigest: value.recipeDigest, [field]: hash('changed') }), /CAPABILITY_PREPARATION_STALE/, field);
  for (const field of Object.keys(selection))
    assert.throws(() => validatePreparation(value, { selection: { ...selection, [field]: 'changed' } }), /CAPABILITY_PREPARATION_STALE/, field);
});

test('preparation rejects corrupt, truncated or mixed authority and unresolved bindings', () => {
  for (const name of ['authority', 'resolutions', 'mechanics']) {
    for (const corrupt of [r => r.truncated = true, r => r.snapshotId = hash('changed'), r => r.recordsets.at(-1).push({ injected: true })]) {
      const value = sample(); corrupt(value.bundle[name]);
      assert.throws(() => validatePreparation(value), /PREPARATION_AUTHORITY_INVALID/);
    }
  }
  const held = sample();
  held.bundle.resolutions.recordsets[1][0].open_requirement_count = 1;
  held.bundle.resolutions.resultDigest = hash(held.bundle.resolutions.recordsets.map(rows => rows.map(stable).sort()));
  assert.throws(() => validatePreparation(held), /PREPARATION_BINDINGS_HELD/);
  const unproved = sample(); unproved.proof.fixtureCount = 0;
  assert.throws(() => validatePreparation(unproved), /PREPARATION_PROOF_REQUIRED/);
});
