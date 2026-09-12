// Run a rollback experiment and capture its full result sets to disk.
//
//   node sql/experiments/run-and-capture.mjs <experiment.sql> [dataset.json]
//
// The experiment is expected to end in ROLLBACK. The runner injects a dataset
// extraction immediately before that reullback (in the same batch, so the
// experiment's variables are still in scope), executes the batch on one
// connection, and writes every result set in full to the output file. Nothing is
// persisted: the experiment's own ROLLBACK runs after the extraction.
import fs from 'node:fs/promises';
import { connect, sql } from '../../src/ingest/database.mjs';

const file = process.argv[2];
if (!file) throw new Error('usage: node sql/experiments/run-and-capture.mjs <experiment.sql> [dataset.json]');
const out = process.argv[3] ?? file.replace(/\.sql$/i, '.dataset.json');

const norm = value => {
  if (value === null || value === undefined) return value;
  if (Buffer.isBuffer(value)) return { $bytes: value.toString('base64') };
  if (typeof value === 'bigint') return value.toString();
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(norm);
  if (typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, norm(v)]));
  return value;
};

const dataset = `
SELECT 'dataset.identity_namespace' AS result_set, * FROM model.identity_namespace
  WHERE namespace_id IN (N'sidefx:capabilities', N'owner:scenario:' + @CapabilityId);
SELECT 'dataset.semantic_object' AS result_set, * FROM model.semantic_object
  WHERE declared_id = @CapabilityId;
SELECT 'dataset.semantic_object_definition' AS result_set, d.* FROM model.semantic_object_definition d
  JOIN model.semantic_object o ON o.semantic_object_pk = d.semantic_object_pk WHERE o.declared_id = @CapabilityId;
SELECT 'dataset.capability' AS result_set, * FROM model.capability WHERE capability_id = @CapabilityId;
SELECT 'dataset.capability_version' AS result_set, cv.* FROM model.capability_version cv
  JOIN model.capability c ON c.capability_pk = cv.capability_pk WHERE c.capability_id = @CapabilityId;
SELECT 'dataset.estate_capability' AS result_set, ec.* FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk WHERE ec.estate_model_pk = @model AND c.capability_id = @CapabilityId;
SELECT 'dataset.scenario' AS result_set, s.* FROM model.scenario s JOIN model.capability c ON c.capability_pk = s.capability_pk WHERE c.capability_id = @CapabilityId;
SELECT 'dataset.scenario_version' AS result_set, sv.* FROM model.scenario_version sv
  JOIN model.scenario s ON s.scenario_pk = sv.scenario_pk JOIN model.capability c ON c.capability_pk = s.capability_pk WHERE c.capability_id = @CapabilityId;
SELECT 'dataset.capability_scenario' AS result_set, cs.* FROM model.capability_scenario cs
  JOIN model.capability c ON c.capability_pk = cs.capability_pk WHERE c.capability_id = @CapabilityId;
SELECT 'dataset.capability_root_scenario' AS result_set, crs.* FROM model.capability_root_scenario crs
  JOIN model.capability_version cv ON cv.capability_version_pk = crs.capability_version_pk
  JOIN model.capability c ON c.capability_pk = cv.capability_pk WHERE c.capability_id = @CapabilityId;
SELECT 'dataset.source_appearance' AS result_set, * FROM source.source_appearance
  WHERE source_path LIKE N'capabilities/' + @CapabilityId + N'/%' OR source_path = N'features/' + @CapabilityId + N'.feature';
SELECT 'dataset.content_object' AS result_set, c.* FROM source.content_object c
  WHERE c.content_object_pk IN (SELECT content_object_pk FROM source.source_appearance
    WHERE source_path LIKE N'capabilities/' + @CapabilityId + N'/%' OR source_path = N'features/' + @CapabilityId + N'.feature');
SELECT 'dataset.source_observation' AS result_set, o.* FROM source.source_observation o
  WHERE o.source_appearance_pk IN (SELECT source_appearance_pk FROM source.source_appearance
    WHERE source_path LIKE N'capabilities/' + @CapabilityId + N'/%');
SELECT 'dataset.declaration_observation' AS result_set, d.* FROM source.declaration_observation d
  WHERE d.source_observation_pk IN (SELECT o.source_observation_pk FROM source.source_observation o
    JOIN source.source_appearance a ON a.source_appearance_pk = o.source_appearance_pk
    WHERE a.source_path LIKE N'capabilities/' + @CapabilityId + N'/%');
SELECT 'dataset.source_lineage' AS result_set, l.* FROM source.source_lineage l
  WHERE l.source_observation_pk IN (SELECT o.source_observation_pk FROM source.source_observation o
    JOIN source.source_appearance a ON a.source_appearance_pk = o.source_appearance_pk
    WHERE a.source_path LIKE N'capabilities/' + @CapabilityId + N'/%');
`;

let text = await fs.readFile(file, 'utf8');
const marker = 'ROLLBACK TRANSACTION;';
const at = text.lastIndexOf(marker);
if (at < 0) throw new Error('NO_ROLLBACK_IN_EXPERIMENT');
text = text.slice(0, at) + dataset + '\n' + text.slice(at);
const batches = text.split(/^\s*GO\s*$/mi).map(s => s.trim()).filter(Boolean);

const capture = { sourceFile: file, capturedAt: new Date().toISOString(), resultSets: [] };
const pool = await connect();
const tx = new sql.Transaction(pool);
try {
  await tx.begin();
  let index = 0;
  for (const batch of batches) {
    index++;
    const result = await new sql.Request(tx).batch(batch);
    for (const rs of result.recordsets) {
      const name = rs[0]?.result_set ?? ('(batch ' + index + ')');
      capture.resultSets.push({ name, rowCount: rs.length, rows: rs.map(norm) });
      console.log('RS', name, 'rows', rs.length);
    }
  }
  console.log('EXECUTED', batches.length, 'batch(es)');
} catch (e) {
  console.error('FAILED:', e.message, 'number=' + e.number, 'line=' + e.lineNumber);
  process.exitCode = 1;
} finally {
  try { await tx.rollback(); } catch {}
  try { await pool.close(); } catch {}
}

await fs.writeFile(out, JSON.stringify(capture, null, 2) + '\n');
console.log('DATASET', out, 'sections', capture.resultSets.length, 'rows', capture.resultSets.reduce((n, r) => n + r.rowCount, 0));
