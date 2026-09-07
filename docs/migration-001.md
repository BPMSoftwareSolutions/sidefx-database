# Migration 001: normalized estate inspection

**Authorized:** 7 September 2026, after the user confirmed the database was empty and directed the migration to proceed.

**Initial load completed:** 62 populated tables, 594,247 committed rows. Every committed table count matched its expected count. Final publication validation ran separately and passed in 20 seconds; model 1 was selected for this initial load. Entity checks found zero null IDs and zero duplicate natural keys. All 355 foreign keys and all CHECK constraints remained enabled and trusted. This records the initial mapping scope described below. Model 3 is now selected; see [current load status](data-load-status.md) for subsequent mappings and remaining gaps.

This is the implementation record for the approved [architecture](data-architecture-strategy.md) and [physical specification](physical-data-model-review.md). The executable schema source is `src/migration/catalog.mjs`, `schema.mjs`, and `views.mjs`; the generated migration is [001-normalized-estate.sql](../sql/migrations/001-normalized-estate.sql). Machine-readable results are under `data/migration/`.

## Physical implementation

Migration 001 creates 124 application tables, a migration history table, 355 foreign keys, 165 declared alternate keys, filtered unique indexes for nullable context policies, and 56 semantic views. The supporting tables implement membership, typed relationship subtypes, expression members, provenance and assessment inputs from the physical specification; they do not add receipt entities to the semantic surface.

The target is Azure SQL, engine version `12.0.2000.8`, compatibility level 170. Semantic identifiers use `Latin1_General_100_BIN2`. Identifiers cannot be empty or have surrounding whitespace. Pointer indexes use the full persisted binary representation, preserving empty property names and whitespace within JSON pointers. All foreign keys and CHECK constraints remain enabled and trusted.

Entity IDs and mandatory relationship keys are non-null. Entity uniqueness is namespace plus declared ID, with the declared Capability owner additionally enforced for Scenarios. Definition identity is separate from source appearance and schema-content identity. Composite foreign keys enforce capability/scenario ownership, exact version selection, operation subtype, provider/implementation agreement, slot requirements, Blueprint endpoints and source outcome variants. Shared scenario-face primary keys prevent duplicate Input/Event/Outcome records for one Scenario version.

Publication validates registry subtype witnesses, namespace ownership, required lineage membership, definition-content digests, exact definition closure, operation subtypes, expression trees, supported geometry rules, binding coverage and assessment state. It selects the candidate through a singleton pointer in the same transaction under an exclusive writer lock. The reader cannot mutate data. The ordinary importer cannot update/delete data, alter constraints, write migration history or bypass pointer selection. Triggers reject changes to immutable data and additions to published definition members, including additions with a forged owner field.

The database gates prove the implemented relational invariants. They do not constitute an independent implementation of every source-profile semantic compiler or every circuit/qualification rule described in the physical specification. Exact source interpretation remains the versioned loader's responsibility. Unimplemented profiles do not receive a complete-model or passing semantic assessment.

## Initial mapping scope

The input is the already captured snapshot `sha256:86d58414531642348bc013dd5bb41aaa7fbb5ce75b7ae6b48847d3c91fd60fb7`, containing 8,178 appearances. The mapping contract is [normalization-v1.json](../config/normalization-v1.json). The stored mapping rule also binds the normalizer, canonicalizer, feature parser adapter and dependency-lock digests.

Implemented mappings include managed Capability declarations; explicit feature Scenario/Input/Event/Outcome tags; Contract catalogs and shared schema content; declared local Ports; supported execution authorities and typed operations; JSON expression structure; observable conditions; fixture definitions/assertions/scenario steps and resolvable port outcomes; and observed semantic-graph transitions. Observed transitions and execution invocations retain separate records and are not promoted into Blueprint topology.

Four external Provider declarations come from the explicit provider catalog. Candidate capabilities, command bindings, platform capability names, profile references and implementation paths do not by themselves establish Provider implementation, selection or qualification relationships. Product identity is implemented in the schema; this initial managed-feature mapping does not turn Outcome IDs or contract IDs into Product IDs.

Carrier v2/v3 composition, historical Blueprint variants, projected graph/slot mappings, reusable Mechanic and Provider Profile declarations, proof-authority admission and qualification sources require additional profile mappings. Their captured sources remain queryable with explicit coverage and findings. Unsupported occurrences are counted by appearance, so repeated source copies can each contribute to coverage while normalized entities remain unique.

A canonical definition contains its explicit semantic address and source-profile semantic fragment/manifest. Legacy recursive scenario references use a finite manifest of canonical authority contributions; they do not recursively hash derived SQL keys. Surrogate keys, import times and source paths are excluded from definition identity. JSON duplicate properties, unsafe integer values and invalid UTF-8 are rejected by the parser before normalization. Literal payloads remain content objects; repeating expression and fixture structures are separate rows.

## Executed checks

- The complete DDL compiled on the target and was rolled back before installation.
- The installed schema passed 63 adversarial/positive SQL checks under the importer and reader accounts. The tests verify the intended database error rather than treating a later rollback as rejection. Test data remaining: zero.
- The bulk-loading path was separately exercised with constraints and triggers enabled, validated through the publication gate, and rolled back.
- All 15 local tests passed, including canonicalization, duplicate-key JSON rejection, identity preservation and source-boundary regressions.

The exact SQL results are in `data/migration/sql-proof.json`. The data transaction and post-load verification results are recorded separately in `load-result.json` and `verification.json`; those files provide the final counts and selected generation.

## Operational boundaries

`npm run migrate` verifies an existing migration's digest and refuses a nonempty database without matching migration history. It never performs an implicit drop/rebuild. The user subsequently directed table-by-table commits. `npm run ingest` now loads each table in its own transaction, verifies the count after commit, and records a resumable checkpoint. Failed tables roll back independently; previously committed tables remain queryable. Final publication is a separate transaction. Repeating the same generation resumes unfinished tables or returns `ALREADY_LOADED` when already selected. A different generation still requires explicit key reconciliation.

The old SQL files and projections are historical artifacts, excluded from the current migration path. The old initialization and ingestion entry points fail immediately. Current command wiring and diagnostics use `source`, `model`, `analysis` and the `sidefx.v_*` views.

The physical specification's N-01 through N-40 remain a broader acceptance catalog. The executed checks above are specific evidence, not a claim that every future profile mapping, all concurrency interleavings or every semantic assessment has already been proven. Additional mappings must include source-specific positive and negative examples and must preserve the installed integrity constraints.
