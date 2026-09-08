import fs from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';
import { connect, sql } from '../src/ingest/database.mjs';
import { stable, hash } from '../src/core.mjs';

test('Scenario resolver map against retained database authority; all DDL rolls back',
  { skip: process.env.SIDEFX_QUERY_INTEGRATION !== '1' }, async t => {
    const pool = await connect(), tx = new sql.Transaction(pool);
    async function read(statement, input) {
      const request = new sql.Request(tx).input('input', sql.NVarChar(sql.MAX), JSON.stringify(input ?? {}));
      const timer = setTimeout(() => request.cancel(), 45000);
      try { return await request.query(statement); } finally { clearTimeout(timer); }
    }
    await tx.begin();
    try {
      const migration = await fs.readFile(new URL('../sql/migrations/004-scenario-resolver-map.sql', import.meta.url), 'utf8');
      for (const batch of migration.split(/^GO\s*$/m).filter(s => s.trim())) await new sql.Request(tx).batch(batch);
      const selection = { capabilityId: 'adapt-job-market-intelligence-evidence', scenarioId: 'verify-jmi-type-admission' };
      const diagnostic = 'DECLARE @estate_model_pk bigint=(SELECT estate_model_pk FROM source.current_model);\n' +
        await fs.readFile(new URL('../sql/diagnostics/scenario-resolver-map.sql', import.meta.url), 'utf8');
      let map;
      await t.test('a leaf includes its I/E/O and mechanics, with no parent or sibling Scenarios', async () => {
        map = await read(diagnostic, selection);
        assert.deepEqual(map.recordsets[2].map(r => r.downstream_scenario_id), [selection.scenarioId]);
        assert.equal(map.recordsets[1].find(r => r.target_language === 'node').requirement_count, '33');
        const node = map.recordsets[0].filter(r => r.target_language === 'node');
        assert.equal(node.filter(r => r.requirement_kind === 'MECHANIC').length, 26);
        assert.deepEqual(new Set(node.filter(r => r.altitude === 'SCENARIO').map(r => r.requirement_kind)),
          new Set(['INPUT_CONTRACT', 'EVENT_AUTHORITY', 'OUTCOME_CONTRACT']));
        assert(node.every(r => r.provenance_class === 'DECLARED_AUTHORITY' && r.conformance_status === 'NOT_EVALUATED'));
        assert(node.filter(r => r.requirement_kind === 'MECHANIC').every(r => r.source_pointer && r.requirement_definition_digest));
      });
      await t.test('unobserved language bindings cannot become eligibility or conformance claims', () => {
        const summary = map.recordsets[1];
        assert.equal(summary.find(r => r.target_language === 'node').readiness, 'CAN_ATTEMPT_EMBODIMENT');
        assert(summary.filter(r => r.target_language !== 'node').every(r => r.readiness === 'NOT_OBSERVABLE'));
        assert(summary.every(r => r.conformance_status === 'NOT_EVALUATED'));
      });
      await t.test('root traversal follows the three declared Scenario invocations', async () => {
        const result = await read(`SELECT s.scenario_id FROM analysis.v_scenario_invocation_closure cl
          JOIN model.capability_version cv ON cv.capability_version_pk=cl.capability_version_pk
          JOIN model.capability c ON c.capability_pk=cv.capability_pk
          JOIN model.scenario_version root ON root.scenario_version_pk=cl.selected_scenario_version_pk
          JOIN model.scenario rs ON rs.scenario_pk=root.scenario_pk
          JOIN model.scenario_version sv ON sv.scenario_version_pk=cl.downstream_scenario_version_pk
          JOIN model.scenario s ON s.scenario_pk=sv.scenario_pk
          WHERE c.capability_id=JSON_VALUE(@input,'$.capabilityId') AND rs.scenario_id=c.capability_id` , selection);
        assert.deepEqual(new Set(result.recordset.map(r => r.scenario_id)), new Set([
          selection.capabilityId, 'verify-jmi-record-binding', selection.scenarioId, 'bind-jmi-adapter-receipt'
        ]));
      });
      await t.test('native profile references match the retained mechanic authority digest algorithm', async () => {
        const rows = (await read(`SELECT DISTINCT c.content_bytes FROM source.current_model cm
          JOIN source.estate_model em ON em.estate_model_pk=cm.estate_model_pk
          JOIN source.source_appearance a ON a.estate_snapshot_pk=em.estate_snapshot_pk
          JOIN source.content_object c ON c.content_object_pk=a.content_object_pk
          WHERE a.source_class='PINNED_PLATFORM_AUTHORITY'`)).recordset;
        const expected = new Set(map.recordsets[0].map(r => r.declared_authority_digest).filter(Boolean));
        let checked = 0;
        for (const row of rows) {
          const document = JSON.parse(row.content_bytes.toString('utf8'));
          if (!expected.has(document.authorityDigest)) continue;
          const { authorityDigest, ...authority } = document;
          assert.equal(hash(JSON.parse(stable(authority))), authorityDigest); checked++;
        }
        assert.equal(checked, expected.size);
        assert(checked > 0);
      });
      await t.test('invalid selection stays explicit rather than falling back to another Scenario', async () => {
        await assert.rejects(read(diagnostic, { ...selection, scenarioId: 'not-declared' }), /SCENARIO_NOT_IN_CAPABILITY/);
        await assert.rejects(read(diagnostic, { ...selection, target: 'not-declared' }), /TARGET_NOT_DECLARED/);
        await assert.rejects(read(diagnostic, {}), /CAPABILITY_AND_SCENARIO_REQUIRED/);
      });
      await t.test('ambiguous implementation candidates remain held without doubling requirement counts', async () => {
        const declaration = migration.split(/^GO\s*$/m).map(s => s.trim())
          .find(s => s.startsWith('CREATE OR ALTER VIEW analysis.v_declared_mechanic_resolution AS'));
        const body = declaration.slice(declaration.indexOf(' AS') + 3).trim().replace(/;$/, '');
        try {
          await new sql.Request(tx).batch(`CREATE OR ALTER VIEW analysis.v_declared_mechanic_resolution AS
            WITH candidates AS (${body}) SELECT * FROM candidates UNION ALL SELECT * FROM candidates;`);
          const ambiguous = await read(diagnostic, { ...selection, target: 'node' });
          const mechanics = ambiguous.recordsets[0].filter(r => r.requirement_kind === 'MECHANIC');
          assert.equal(mechanics.length, 52);
          assert(mechanics.every(r => r.resolution_status === 'NOT_OBSERVABLE' && r.resolution_candidate_count === '2'));
          assert.equal(ambiguous.recordsets[1][0].requirement_count, '33');
          assert.equal(ambiguous.recordsets[1][0].readiness, 'NOT_OBSERVABLE');
        } finally { await new sql.Request(tx).batch(declaration); }
      });
    } finally {
      await tx.rollback().catch(() => {});
      await pool.close();
    }
  });
