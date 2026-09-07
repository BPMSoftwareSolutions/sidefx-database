# SideFX Database

Normalized SQL Server inspection of the SideFX estate. The semantic baseline is in [data-architecture-strategy.md](docs/data-architecture-strategy.md); the physical contract is in [physical-data-model-review.md](docs/physical-data-model-review.md). See [data-load-status.md](docs/data-load-status.md) for current committed data and remaining mappings, and [migration-001.md](docs/migration-001.md) for the initial schema implementation.

## Local setup

Use Node.js 20 or later and install dependencies with `npm ci`. Source code, SQL, configuration and documentation are tracked in Git. Captured estate data, load checkpoints, receipts, dependencies and environment files remain local under the existing `.gitignore` rules.

The frozen-estate integration tests and ingestion commands require the configured local snapshot/content store and the pinned bootstrap Git objects. A fresh clone does not contain those inputs or SQL credentials. The independent local tests can run with:

```powershell
node --test test/normalized-model.test.mjs test/projection.test.mjs test/query-format.test.mjs
```

The full local test suite is `npm test` once the frozen inputs are available. `.gitattributes` preserves exact file bytes because committed mapping manifests include source and configuration digests.

## Query the data

```powershell
Set-Location C:\lab\sidefx-database
npm run verify
npm run query -- --file sql/diagnostics/start-here.sql
npm run query -- --file sql/diagnostics/mechanics.sql --limit 1000
```

The connection comes from `sidefx-connection-string` in the process, Windows User, or Windows Machine environment. Credentials are never written to this workspace.

```sql
SELECT capability_id, name FROM sidefx.v_capability ORDER BY capability_id;

SELECT c.capability_id, s.scenario_id, i.input_id, e.event_id, o.outcome_id
FROM sidefx.v_capability c
JOIN sidefx.v_scenario s ON s.capability_pk = c.capability_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk = s.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk = s.scenario_version_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk = s.scenario_version_pk;

SELECT * FROM sidefx.v_provider;
SELECT * FROM sidefx.v_assessment_coverage;
```

## Storage and relationships

| Schema | Responsibility |
|---|---|
| `model` | Stable identities, exact definitions, normalized members and relationships |
| `source` | Captured sources, mapping rules, lineage, model membership and atomic selection |
| `analysis` | Scoped findings and explicit coverage or assessment results |
| `sidefx` | Views over the selected model, with a documented row grain |

Every entity has a non-null primary key and a unique semantic key. Definitions have separate content identity. Scenarios belong to Capabilities; their Input, Event and Outcome rows share the Scenario version key. Providers are independent identities. Capability implementation, provider requirements, selections and qualifications are separate relationships. A Provider does not have a nullable Capability owner column.

A declaration that cannot be normalized remains source data with a finding. Missing identifiers, unsupported profiles and unresolved targets never produce placeholder entities. A missing assessment is not a passing assessment. The initial mapping does not claim complete coverage of historical blueprints, carrier profiles or provider runtime selections.

## Commands

| Command | Behavior |
|---|---|
| `npm run probe` | Inspect target database and permissions |
| `npm run schema:emit` | Generate the reviewed SQL migration from the schema catalog |
| `npm run migrate` | Apply migration 001 transactionally to an empty database, or verify its existing digest |
| `npm run migrate -- --dry-run` | Compile the schema against an empty target, then roll it back |
| `npm run derive` | Normalize the explicitly selected frozen snapshot locally and report counts |
| `npm run ingest` | Load and commit one table at a time with constraints enabled; resume from committed tables; validate selection separately |
| `npm run ingest -- --load-only` | Commit and verify tables without running final publication validation |
| `npm run refresh` | Apply/verify the migration and load the configured frozen generation; does not recapture Harness |
| `npm run verify` / `npm run check` | Check migration identity, constraint trust, selected model, entity keys and view grains |
| `npm run query -- --file ...` | Run a query under the restricted reader account |
| `npm test` | Run local canonicalization, source boundary and extraction regression checks |
| `npm run test:sql` | Run adversarial SQL proofs against an empty migrated model; all test data is rolled back |
| `npm run snapshot` | Capture a new observation using the existing read-only estate verification boundary |

The loader composes the original frozen capture, the mappings in `config/normalization-v2.json`, and the pinned dependency declarations in `config/platform-normalization.json`. The dependency is read from its exact Git revision in the configured local bootstrap repository. Each table is committed in its own transaction and its row count is verified after COMMIT. Stage checkpoints live under `data/migration/`, `data/completeness/`, and `data/platform/` as `table-checkpoints.json`. The extension loaders compare the actual appended row contents before skipping a committed table. An error rolls back only the table currently loading. Final publication runs separately and cannot undo earlier commits. Repeating a fully selected load returns `ALREADY_LOADED`. A different generation requires explicit key reconciliation. No command silently drops tables, disables constraints or falls back to the retired flattened importer.

Extension loading also applies migrations 002 and 003: corrected coverage views and indexed lineage validation. These preserve the original schema constraints. The selected model includes 191 Mechanic identities and 314 declared Provider-to-Mechanic relationships. Relational verification does not mean all source profiles are normalized; the remaining gaps are exposed by `sidefx.v_load_completeness` and `sidefx.v_source_reference_gap`.

`src/ingest/schema.mjs`, `src/ingest/load.mjs`, `sql/schema/`, and `sql/views/` are retired historical implementation files. Their old mutation entry points fail immediately. They are not migration inputs. Historical documents and local projections describe the previous model only.

## Inspection boundaries

`npm run query` pins the selected model, impersonates `sidefx_reader` with `NO REVERT`, applies a row limit, and closes its dedicated connection. The reader can SELECT the normalized and supporting schemas, and cannot mutate them. The command supplies `@estate_model_pk`, `@snapshot_id`, and the mapping manifest digest as `@projection_id`. Query receipts are off by default. During a load, use `npm run query -- --committed --sql "SELECT COUNT_BIG(*) FROM model.capability"` to inspect committed tables before final model selection.

The ordinary importer can append candidate data and invoke the owner-executed publication procedure. It cannot update/delete data, disable constraints, change migration history, or write the selected-model pointer. Publication takes an exclusive writer lock and runs the database gates in the same transaction. Published definitions and their members are immutable.

This workspace writes its own inspection database and local artifacts. It does not change, admit, publish or execute Harness capabilities.
