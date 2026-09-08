# Scenario embodiment from database authority

The entry point is a Capability and one of its Scenarios. The database supplies
Input, Event, Outcome, execution authority, declared Scenario invocations,
mechanics, ports and explicitly associated provider slots. Existing SDA language
resolvers and projectors own executable embodiment.

The accepted outcome is language-native object-oriented code whose Scenario,
contracts, dependencies and mechanic/provider implementations can be traced to
that authority. Contract classes, a runtime entry point, a graph compilation and
an executable Scenario with all required mechanics are different proof surfaces.
None establishes the others automatically.

## Database inspection boundary

Migration `004-scenario-resolver-map.sql` defines derived inspection objects:

- `analysis.v_scenario_embodiment_requirement`: each declared requirement in the
  selected Scenario's invocation closure, retaining definition identity and pointer.
- `analysis.v_scenario_language_resolution`: exact declared target bindings and
  candidate implementations, with unresolved and ambiguous selection exposed.
- `analysis.v_scenario_embodiment_readiness`: one count per requirement, regardless
  of how many candidate implementations exist.

Supporting views read existing normalized tables and retained canonical source
bytes. SQL functions restrict the walk to the selected Scenario and interpret
expression arguments using each mechanic's declared `authoringForm`. Their
intermediate rows are transient query results. No authority tables, language
catalog or provider selection policy are introduced.

The walk follows `operation_scenario_invocation`. A neighboring Scenario or an
unrelated Blueprint route does not enter the walk. Transformation references must
match their declared identity, namespace and retained source entry. Literal
payloads are not executable expressions. A compiler-internal operation is not
automatically a declared semantic mechanic.

Language identity comes from catalog `projectionTarget` or registry `language`.
The map also uses existing provider–mechanic implementation relationships through
the exact retained definitions. It does not infer a target from a provider name.
Several candidates remain visible and yield `NOT_OBSERVABLE` until selection is
established. Missing target evidence is not evidence that a language cannot
implement the mechanic.

`CAN_ATTEMPT_EMBODIMENT` means the inspected declaration requirements are accounted
for. Implementation evidence remains `DECLARATION_ONLY` and conformance remains
`NOT_EVALUATED`. Compilation, fixtures, Reveal, Compare and Cross-Apply must still
establish their own results. Authority digests and raw source digests remain
distinct; verification must use the source's declared digest algorithm.

## Query interface

The existing restricted database reader accepts a JSON file via `--input` and
binds it as the SQL parameter `@input`. Query evidence includes its digest as well
as the selected model, result and SQL object-definition digests.

```json
{
  "capabilityId": "adapt-job-market-intelligence-evidence",
  "scenarioId": "verify-jmi-type-admission"
}
```

Optional `namespaceId` disambiguates a Capability and optional `target` selects a
declared target. The query is `sql/diagnostics/scenario-resolver-map.sql`; it returns
the requirement map, readiness and the exact downstream Scenarios with I/E/O.
Its transient result table avoids re-running resolution for each output. The
reader reports truncation; a truncated result must not be used as a complete map.

`sql/diagnostics/capability-embodiment.sql` is the separate retained-authority
export for supplying source bytes to existing SDA parsers. Its whole-Capability
export is not a claim that every Scenario belongs to the selected Scenario's
execution descent.

## Existing SDA boundaries inspected

At SDA commit `6fcb8b34f0b85c70a8984940cc21a20cfdb507dd`:

| Surface | Observed behavior | Consequence for this work |
| --- | --- | --- |
| `tools/src/consumer-projection/providers/node/consumer-application-provider.ts` | Emits runtime, query and CLI bindings to the admitted consumer platform | This path alone does not demonstrate a native class for the selected Scenario with injected mechanics |
| `tools/src/consumer-projection/providers/python/consumer-application-provider.ts` | Emits an entry point calling `scenario_kernel.platform.consumer.main` | The entry point is not the full OO embodiment required here |
| `tools/src/consumer-projection/providers/csharp/consumer-application-provider.ts` | Emits a generic SDK client accepting `JsonNode` and delegating execution | A generic client is a distinct surface from selected Scenario and contract classes |
| `tools/src/projection/providers/python/structural-projection-provider.ts` | Renders native contract dataclasses from the target structural graph | Reuse this boundary where its admitted input contract applies; do not hand-write replacement contract generators |
| `tools/src/projection/providers/execution-rendering.ts` | Renders the canonical Scenario Kernel execution vector | Kernel embodiment does not establish full downstream mechanic embodiment for a selected Capability |
| `ConsumerExecutionEmbodimentCompiler.compileV3` | Supplies a compatibility implementation reference when an exact mechanic resolution is absent | Pass explicit evidenced profiles; the default cannot establish exact provider coverage |
| Node `admitted-consumer-platform.mjs` graph provider | Catches expression evaluation errors and returns the incoming value, including the lexical-scope fallback | A successful run through that fallback cannot establish mechanic-level execution correctness |

These findings are about the inspected paths, not a claim that every SDA surface
has been evaluated. The next implementation proof must identify the existing
resolver responsible for the requested OO surface and demonstrate its output
from database authority. If it lacks that surface, the repair belongs to its
declared resolver/projection boundary. CLI dispatch and semantic authority do not
acquire compensating Scenario-specific code.

The repository command model remains `sfx <object> <operation> [identity]`.
No new CLI syntax or successful CLI embodiment is claimed by this database work.

## Validation

The database integration suite creates these SQL objects inside a transaction
and rolls back. Run it serially with other live reader tests because DDL takes
schema locks:

```powershell
$env:SIDEFX_QUERY_INTEGRATION='1'
node --test --test-concurrency=1 test/scenario-resolver-map.integration.test.mjs test/query-input.integration.test.mjs test/query-format.test.mjs
```

Application of migration 004 is a separate operation through
`src/migration/resolver-views.mjs`; `--dry-run` validates and rolls back. A passing
database test is not a native embodiment, managed admission or publication.

## Observed result, 2026-09-07

Migration 004 was applied transactionally with digest
`12254fefc6661afb0214220edecaa6e3724629f59b15763c05c300f82b67e7e0`.
A repeat returned `ALREADY_APPLIED`. It adds nine derived views and four SQL
query functions, including the three public map views above.

The live integration command passed all 13 checks. The broader `npm test`
passed 17 checks, with its six opt-in integration entries skipped; those entries
were exercised separately by the live command. The reader's former server-side
`SET ROWCOUNT` could truncate intermediate SQL table variables and produce false
coverage totals. Limits now apply to retained result rows after SQL calculation;
both selected-model and committed-table inspection have a regression check.

Two different Capability/Scenario requests were executed through the database
CLI using the same SQL, with exit code 0 and `READ_QUERY_COMPLETE`:

| Capability | Selected Scenario | Requirements | Observed result |
| --- | --- | ---: | --- |
| `adapt-job-market-intelligence-evidence` | `verify-jmi-type-admission` | 33, including 26 mechanic uses | Node `CAN_ATTEMPT_EMBODIMENT`; Python/C# have 26 open requirements, Java/Go/C++ have 27 |
| `admit-canonical-circuit-blueprint` | `require-blueprint-geometry-proof` | 131 | Node `CAN_ATTEMPT_EMBODIMENT` |

The first request returns only its selected leaf Scenario. A separate invocation
closure check confirms that selecting its parent follows exactly its three
declared Scenario invocations. Duplicate candidate injection, confined to a
rolled-back derived view, holds resolution without doubling requirement counts.

The exact input and native output are retained at
`C:/lab/experiments/sidefx-embodiment/scenario-resolver-map.input.json` and
`scenario-resolver-map.result.json`; the second request is retained as
`second-capability.input.json` and `second-capability.result.json` in that directory.

```powershell
node src/cli.mjs query --file sql/diagnostics/scenario-resolver-map.sql --input C:\lab\experiments\sidefx-embodiment\scenario-resolver-map.input.json --limit 1000
```

The database map's conformance status remains `NOT_EVALUATED`; query coverage is
not execution proof. A subsequent external lab implementation at
`C:/lab/experiments/sidefx-embodiment/README.md` now materializes native Node bodies
through a candidate implementation of the existing SDA
`ConsumerApplicationProvider.render` protocol. It reuses the SDA Scenario graph
compiler, contract renderer and real Scenario Kernel/admission source.

The layout is
`embodiments/<capability-id>/scenarios/<scenario-id>/<target>/{body,evidence}`,
with an `embodiment.receipt.json` beside them. Paths are derived from database IDs.
For `adapt-job-market-intelligence-evidence`, its root and three declared child
Scenarios execute all five retained fixtures successfully. The current proof
includes 100 kernel observations, 20 native port comparisons against the selected
provider, contract fidelity checks, invalid-input rejection and child-failure
propagation. Receipts report `EXECUTION_CHECKS_PASSED`; child
evidence identifies its scope as executions within the parent fixtures.

The final combined regression generated and executed three complete Capabilities
using identical implementation components throughout the run:

| Capability | Scenario bodies executed | Retained fixtures passed |
| --- | ---: | ---: |
| `adapt-job-market-intelligence-evidence` | 4 | 5/5 |
| `admit-canonical-circuit-blueprint` | 5 | 8/8 |
| `resolve-sidefx-eligible-providers` | 1 | 4/4 |

`C:/lab/experiments/sidefx-embodiment/regression-results.json` retains the successful
`node verify-estate.mjs regression.cases.json` run: 17 fixtures, 320 kernel
observations, 64 native port comparisons, inverse checks for all 994 native
expression regions, contract fidelity checks and five invalid-input/child-failure
checks. The earlier interpreter-shaped implementation and its 6,248 invocation
observations are preserved separately in the lab's frozen baseline. The blueprint
leaf now has execution evidence inside its parent fixtures. Four additional
resolver tests cover schema-view equivalence, relative references, literal data
preservation and explicit unsupported-union rejection.

Shared candidate resolver fixes handle the declared contract catalog/reference
closure, nullable type arrays, quoted TypeScript property identities and constant
export namespaces. Original schemas remain runtime admission authority. These
fixes contain no Capability-specific branches. Native projection now preserves
all 46 declared bindings as lexical variables and retires numbered Expression
objects. A 200-vector corpus covers all 32 pure mechanics in the selected native
provider, including inverse projection. The current acceptance report is
`C:/lab/experiments/sidefx-embodiment/review/native-embodiment-repair.md`.
Other language binding gaps, unsupported topology, full Capability/Scenario
round-trip equivalence, governed Reveal/Compare/Cross-Apply and managed admission
remain open. No conformance/admission result has been written back to the database.
