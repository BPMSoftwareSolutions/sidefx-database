import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { complete } from './complete.mjs';
import { platform } from './platform.mjs';

// Row counts are facts about one loaded generation, not invariants. Asserting
// them inline made every legitimate input change look like a defect, and
// because an assertion ends its subtest, the first stale count also stopped
// every invariant below it from running. They are emitted here and committed
// as data instead, so an input change arrives as a reviewable diff to
// test/generation-expectations.json and the invariants keep running either way.
export const EVALUATED_AT = '2026-09-07T12:00:00.000Z';
const FILE = new URL('../../test/generation-expectations.json', import.meta.url);

export function completeExpectation(ds) {
  return {
    snapshot: ds.summary.snapshot,
    declaredBlueprints: ds.summary.declaredBlueprints,
    loadedBlueprints: ds.summary.loadedBlueprints,
    observedEdges: ds.summary.observedEdges,
    newReferenceGaps: ds.summary.newReferenceGaps,
    classifications: classifiedAppearances(ds).length,
    coverage: ds.summary.coverage,
    counts: ds.summary.counts
  };
}

export function platformExpectation(ds) {
  return {
    snapshot: ds.summary.snapshot,
    platform: ds.summary.platform,
    estateCapabilities: ds.rows.get('model.estate_capability')
      .filter(r => r.estate_model_pk === ds.model.estate_model_pk).length,
    appearances: snapshotAppearances(ds).size,
    coverage: ds.summary.coverage,
    counts: ds.summary.counts
  };
}

export function classifiedAppearances(ds) {
  return ds.rows.get('source.source_classification').filter(r => r.mapping_rule_pk === ds.rule.mapping_rule_pk);
}

export function snapshotAppearances(ds) {
  return new Set(ds.rows.get('source.source_appearance')
    .filter(r => r.estate_snapshot_pk === ds.snapshot.estate_snapshot_pk)
    .map(r => r.source_appearance_pk));
}

export async function readExpectations() {
  return JSON.parse(await fs.readFile(FILE, 'utf8'));
}

// A flat difference list, so a mismatch names the table that moved rather than
// printing two large objects side by side.
export function differences(expected, actual, at = '') {
  const out = [];
  const keys = [...new Set([...Object.keys(expected ?? {}), ...Object.keys(actual ?? {})])].sort();
  for (const key of keys) {
    const e = expected?.[key], a = actual?.[key], path = at ? at + '.' + key : key;
    if (e && a && typeof e === 'object' && typeof a === 'object') out.push(...differences(e, a, path));
    else if (e !== a) out.push(`${path}: expected ${show(e)}, got ${show(a)}`);
  }
  return out;
}

const show = value => value === undefined ? '(absent)' : String(value);

export async function emit() {
  return {
    note: 'Emitted by src/migration/expectations.mjs. Counts belong to one generation; invariants live in the tests. Regenerate with npm run expectations and review the diff.',
    complete: completeExpectation(await complete({ evaluatedAt: EVALUATED_AT })),
    platform: platformExpectation(await platform({ evaluatedAt: EVALUATED_AT }))
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const document = await emit();
  if (process.argv.includes('--write')) {
    await fs.writeFile(FILE, JSON.stringify(document, null, 1) + '\n');
    console.log(JSON.stringify({ status: 'WRITTEN', file: fileURLToPath(FILE) }));
  } else {
    const current = await readExpectations().catch(() => null);
    const drift = current ? differences(current, document) : ['(no committed expectations)'];
    console.log(JSON.stringify({ status: drift.length ? 'DRIFTED' : 'MATCHES', drift }, null, 1));
    if (drift.length) process.exitCode = 1;
  }
}
