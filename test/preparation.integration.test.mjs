import test from 'node:test';
import assert from 'node:assert/strict';
import { query } from '../src/query/run.mjs';
import { readPreparation, storePreparation } from '../src/runtime/preparation.mjs';
import { connect, sql } from '../src/ingest/database.mjs';

const integration = { skip: process.env.SIDEFX_PREPARATION_INTEGRATION !== '1' };
// Requires the documented native sfx preparation acceptance case first.
const selection = { capabilityId: 'resolve-sidefx-eligible-providers', target: 'node' };
async function existing() {
  const result = await query(`SELECT TOP(1) 'sha256:'+LOWER(CONVERT(varchar(64),p.recipe_digest,2)) recipe_digest
    FROM runtime.capability_preparation p JOIN model.capability c ON c.capability_pk=p.capability_pk
    WHERE p.estate_model_pk=@estate_model_pk AND c.capability_id=JSON_VALUE(@input,'$.capabilityId') AND p.target='node'
    ORDER BY p.preparation_pk DESC`, { input: selection, retainObjects: false });
  assert.equal(result.recordsets[0].length, 1, 'Run native sfx capability prepare acceptance first');
  return readPreparation(selection, result.recordsets[0][0].recipe_digest);
}

test('SQL preparation round trips and concurrent identical publication is idempotent', integration, async () => {
  const before = await existing();
  for (const saved of await Promise.all([storePreparation(before.preparation), storePreparation(before.preparation)])) {
    assert.equal(saved.status, 'ALREADY_PREPARED');
    assert.equal(saved.preparationDigest, before.preparationDigest);
    assert.equal(saved.preparedAt, before.preparedAt);
  }
  const after = await existing();
  assert.deepEqual(after.preparation, before.preparation);
  const explicitSelection = structuredClone(before.preparation);
  explicitSelection.bundle.authority.inputDigest = 'sha256:' + '1'.repeat(64);
  assert.equal((await storePreparation(explicitSelection)).preparationDigest, before.preparationDigest);
  const changed = structuredClone(before.preparation); changed.proof.fixtureCount++;
  await assert.rejects(storePreparation(changed), /PREPARATION_CONFLICT/);
  const wrongModel = structuredClone(before.preparation);
  for (const key of ['authority','resolutions','mechanics']) wrongModel.bundle[key].snapshotId = 'sha256:' + '0'.repeat(64);
  await assert.rejects(storePreparation(wrongModel), /CAPABILITY_PREPARATION_STALE/);
  await assert.rejects(readPreparation(selection, 'sha256:' + '0'.repeat(64)), /CAPABILITY_PREPARATION_STALE/);
});

test('SQL reader cannot write preparations and runtime constraints are trusted', integration, async () => {
  for (const statement of [
    'INSERT runtime.capability_preparation(estate_model_pk) SELECT 0 WHERE 1=0',
    'UPDATE runtime.capability_preparation SET target=target WHERE 1=0',
    'DELETE runtime.capability_preparation WHERE 1=0'
  ]) await assert.rejects(query(statement, { retainObjects: false }), /permission|denied/i);
  const pool = await connect(), tx = new sql.Transaction(pool);
  try {
    const constraints = (await pool.request().query(`SELECT name,is_disabled,is_not_trusted FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('runtime.capability_preparation')
      UNION ALL SELECT name,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('runtime.capability_preparation')`)).recordset;
    assert.equal(constraints.length, 4);
    assert(constraints.every(c => !c.is_disabled && !c.is_not_trusted));
    await tx.begin();
    await assert.rejects(new sql.Request(tx).query(`INSERT runtime.capability_preparation(estate_model_pk,capability_pk,capability_version_pk,scenario_version_pk,target,recipe_digest,view_definition_digest,payload_digest,payload_bytes)
      SELECT TOP(1) estate_model_pk,capability_pk,capability_version_pk,scenario_version_pk,target,HASHBYTES('SHA2_256','tamper-test'),view_definition_digest,payload_digest,0x00 FROM runtime.capability_preparation`), /CK_preparation_payload/);
  } finally { await tx.rollback().catch(() => {}); await pool.close(); }
});
