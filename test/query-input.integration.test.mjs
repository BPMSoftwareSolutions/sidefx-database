import test from 'node:test';
import assert from 'node:assert/strict';
import { query } from '../src/query/run.mjs';
import { readFile } from 'node:fs/promises';

const integration = { skip: process.env.SIDEFX_QUERY_INTEGRATION !== '1' };

test('capability invocation selects its normalized root and preserves explicit scenario selection', integration, async () => {
  const statement = await readFile(new URL('../sql/diagnostics/capability-embodiment.sql', import.meta.url), 'utf8');
  const input = { capabilityId: 'resolve-sidefx-eligible-providers' };
  const root = await query(statement, { input, retainObjects: false });
  assert.equal(root.recordsets[0][0].scenario_id, 'resolve-sidefx-eligible-providers');
  const explicit = await query(statement, { input: { ...input, scenarioId: root.recordsets[0][0].scenario_id }, retainObjects: false });
  assert.deepEqual(root.recordsets, explicit.recordsets);
  await assert.rejects(query(statement, { input: { capabilityId: 'nonexistent-capability-for-cli-test' }, retainObjects: false }), /CAPABILITY_NOT_FOUND/);
  await assert.rejects(query(statement, { input: { ...input, scenarioId: 'nonexistent-scenario-for-cli-test' }, retainObjects: false }), /SCENARIO_NOT_IN_CAPABILITY/);
});

test('a memory-only query cannot emit a receipt for unretained objects', async () => {
  await assert.rejects(query('SELECT 1', { retainObjects: false, writeReceipt: true }), /QUERY_RECEIPT_REQUIRES_RETAINED_OBJECTS/);
});

test('memory-only queries preserve identities and declare their retention scope', integration, async () => {
  const statement = 'SELECT @snapshot_id AS snapshot_id, @input AS input';
  const options = { input: { capabilityId: 'memory-only-query-proof' } };
  const retained = await query(statement, options);
  const memory = await query(statement, { ...options, retainObjects: false });
  assert.equal(Object.hasOwn(retained, 'objectRetention'), false);
  assert.equal(memory.objectRetention, 'MEMORY_ONLY');
  assert.equal(Object.hasOwn(memory, 'receiptPath'), false);
  const { objectRetention, ...unchanged } = memory;
  assert.deepEqual(unchanged, retained);
});

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
