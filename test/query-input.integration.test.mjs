import test from 'node:test';
import assert from 'node:assert/strict';
import { query } from '../src/query/run.mjs';

const integration = { skip: process.env.SIDEFX_QUERY_INTEGRATION !== '1' };

test('query binds Unicode and SQL-looking request values as data', integration, async () => {
  const input = { capabilityId: "é能力'; SELECT 'injected' AS unexpected; --" };
  const result = await query("SELECT JSON_VALUE(@input, '$.capabilityId') AS capability_id", { input });
  assert.equal(result.truncated, false);
  assert.deepEqual(result.recordsets, [[{ capability_id: input.capabilityId }]]);
  assert.match(result.inputDigest, /^sha256:[0-9a-f]{64}$/);
});

test('query evidence distinguishes inputs without changing the SQL identity', integration, async () => {
  const statement = "SELECT JSON_VALUE(@input, '$.scenarioId') AS scenario_id";
  const first = await query(statement, { input: { scenarioId: 'first' } });
  const second = await query(statement, { input: { scenarioId: 'second' } });
  assert.equal(first.queryDigest, second.queryDigest);
  assert.notEqual(first.inputDigest, second.inputDigest);
  assert.notEqual(first.resultDigest, second.resultDigest);
});

test('omitting query input preserves the existing receipt shape', integration, async () => {
  const result = await query('SELECT @input AS input');
  assert.equal(Object.hasOwn(result, 'inputDigest'), false);
  assert.deepEqual(result.recordsets, [[{ input: null }]]);
});

test('committed-table inspection uses the same parameter binding', integration, async () => {
  const result = await query("SELECT JSON_VALUE(@input, '$.scenarioId') AS scenario_id", {
    committed: true, input: { scenarioId: 'requested-scenario' }
  });
  assert.equal(result.inspectionState, 'COMMITTED_TABLES');
  assert.deepEqual(result.recordsets, [[{ scenario_id: 'requested-scenario' }]]);
  assert.match(result.inputDigest, /^sha256:[0-9a-f]{64}$/);
});

test('retention limits do not truncate intermediate requirements before aggregation', integration, async () => {
  const statement = 'DECLARE @requirements TABLE(id int); INSERT @requirements VALUES(1),(2),(3),(4),(5),(6); SELECT COUNT(*) AS required_count FROM @requirements;';
  for (const committed of [false, true]) {
    const result = await query(statement, { rowLimit: 1, committed });
    assert.equal(result.truncated, false);
    assert.deepEqual(result.recordsets, [[{ required_count: 6 }]]);
  }
});
