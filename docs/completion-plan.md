# Path to migration completion

The migration finishes when the database faithfully represents the agreed static estate and every missing fact has an established explanation. Successful inserts and matching loader-generated counts are necessary but do not prove source coverage.

The architecture remains the approved [data architecture strategy](data-architecture-strategy.md). This plan closes the migration; it does not add runtime monitoring, qualification execution, or a capability-authoring system.

The corrected reload is committed and verified: 806 complete Scenarios, 616 Contracts, 432 assertion-condition links, three state projections and three fan-out sets. All 17 local tests passed, all 124 stored table counts matched, and restart returned `ALREADY_LOADED`. See [current load status](data-load-status.md) for the final manifest and remaining coverage.

## Baseline before the corrected reload

- Model 3 is committed and selected. Table transactions, final validation, and restart verification have passed.
- All 124 application-table counts match the implemented load manifest; entity keys and constraint trust pass.
- 45 application tables are empty. Their disposition still needs a complete source-to-table reconciliation.
- 1,934 unsupported appearances contain 902 distinct content digests. These are source counts, not 1,934 separate implementation tasks.
- 14 appearances have unresolved classification/definition mapping, and the selected model exposes 735 unresolved references. Those measures overlap and must not be added together as a task count.
- 61 of 824 Scenarios remain outside the complete-scenario view.

These numbers come from `data/completeness/appearance-coverage.json`, `data/platform/load-result.json`, and `data/migration/verification.json`. They are the starting backlog, not acceptance thresholds.

## Five completion steps

| Step | Work | Exit condition |
|---|---|---|
| 1. Close the inventory | Audit the agreed authority locations and exact pinned dependencies; follow declared references to establish the required source set. Enumerate distinct profiles and declarations, including already classified outside-scope material, against the approved boundary. Map all 124 tables to their source declarations. | One finite source/profile work list; every empty table has a pending mapping, a verified absence of declarations, a source defect, or an already agreed exclusion. No unexplained table or unexamined catch-all remains. |
| 2. Finish the mappings locally | Resolve source paths and exact version pins; implement missing family mappings; reconcile shared declarations and typed relationships. Establish source-side expected identities and relationships separately from the loader's output. | Every valid in-scope declaration has its expected normalized representation. All resolvable references resolve. No missing importer implementation is relabeled as a source defect or excluded to improve coverage. |
| 3. Resolve the exception list | Examine each remaining unresolved declaration/reference within the closed source set. Record the exact source, declared target, resolution attempt, and defect. Apply the existing architecture's exclusions. | Each remaining exception is reproducible from source. Existing source defects are visible in SQL and excluded from complete/qualified claims as required. No unresolved importer gap remains. |
| 4. Commit the completed mapping set | Preserve existing committed data. Reconcile stable identities and append corrected definitions/relationships under one final mapping generation. Use the existing per-table transactions and restart mechanism. | All expected tables are committed; validation passes; the final model is selected. A retry resumes safely or returns `ALREADY_LOADED`. |
| 5. Run acceptance and stop | Compare source-derived expectations with SQL identities, definitions and relationships; execute the agreed representative joins; check keys, ownership, constraints, lineage and view grain. | The completion checklist below passes. Record the final counts and source exceptions once, then close the migration. |

The inventory and local reconciliation precede another database generation. Work is organized by source profile and shared resolver, so one mapping can address repeated copies across many Capabilities.

## Known work to include

1. Historical Contract catalog paths and Scenario contract/execution references, including the 61 incomplete Scenarios.
2. Local and shared interface mappings, fixture members and observed graph forms.
3. Provider declarations, implementations, requirements, slots and bindings, including remaining partial catalogs/runtime declarations.
4. Blueprint definitions, exact authority pins, nodes and topology. Observed execution does not substitute for missing designed topology authority.
5. Product, proof-definition, qualification-declaration and other empty table families: locate their actual declarations within the agreed scope and implement mappings where applicable; establish absence with source evidence where not present.

The current catch-all `UNMAPPED_SEMANTIC_SOURCE` contains 1,170 appearances. Splitting it into actual source profiles is part of step 1, not a reason to begin another speculative load.

## Completion checklist

- [ ] Required source locations and exact dependency references are accounted for.
- [ ] Every table has an evidenced source/coverage disposition; zero unexplained empty tables.
- [ ] Zero valid in-scope declarations omitted because an importer mapping is missing.
- [ ] Zero resolvable references left unresolved because of importer path, namespace or version handling.
- [ ] Every remaining source defect has an exact, queryable explanation; none is disguised as a complete entity relationship or passing assessment.
- [ ] No null semantic IDs, duplicate semantic keys, duplicate uses at their declared grain, broken FKs or disabled/untrusted constraints.
- [ ] Source-derived entity and relationship expectations agree with the selected SQL model; repeated source copies do not multiply entities.
- [ ] Capability-to-Scenario-to-Input/Event/Outcome, Contract use, Provider-to-Mechanic/Capability, slot/binding, and applicable Blueprint/Product queries return correct relationships or explicit source gaps.
- [x] The corrected candidate loads successfully and a restart returns `ALREADY_LOADED` without adding rows.

Source defects can remain in a completed inspection database: exposing them is part of its purpose. Repairing the authoritative Harness estate is separate work. Missing importer mappings and incomplete capture cannot be excused as source defects. Additional authority changes after the agreed source set is closed belong to a subsequent refresh and do not continuously reset this migration's finish line.
