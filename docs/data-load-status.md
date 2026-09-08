# Committed data and mapping coverage

The migration is closed. The disposition of every empty table and the exact remaining source defects are in [migration-closure.md](migration-closure.md); the plan it satisfies is [completion-plan.md](completion-plan.md).

The corrected model 3 is published and selected in the inspection database. **81 table loads committed 1,038,999 rows**, followed by the selected-model pointer. All 124 application-table counts were verified against the corrected manifest. Each table committed separately before the final validation and selection transaction.

The corrected load resolves catalog source paths, shared event authorities and declared state projections, and adds assertion-condition and fan-out-set relationships. Complete Scenarios increased from 763 to **806 of 824**. Contracts increased from 565 to **616**. The shared authorities and all 16 of their operations now load before publication.

The earlier importer omitted declarations supplied by the pinned bootstrap dependency. It captured the Harness repository and capsules but did not include that dependency's platform catalog and mechanic authorities. The extension now reads those declarations at revision `87ae918ce46fe4acadd0aecbdcb030c9b55043d9`, the revision named by the captured `package-lock.json`.

## Loaded relationships

| Table | Committed rows |
|---|---:|
| `model.mechanic` | 191 |
| `model.mechanic_version` | 191 |
| `model.provider` | 74 |
| `model.provider_definition` | 74 |
| `model.provider_mechanic_implementation` | 314 |
| `model.provider_capability_implementation` | 85 |
| `model.provider_profile` | 2 |
| `model.blueprint` | 35 |
| `model.authority` | 34 |
| `model.scenario` | 824 |
| `model.contract` | 616 |
| `model.operation_state_projection` | 3 |
| `model.fixture_assertion_condition` | 432 |
| `model.blueprint_fan_out_set` | 3 |

The platform catalog supplies 69 Provider identities in addition to five previously loaded Providers. Its explicit `provider` field supplies the identity; each `providesMechanics` entry supplies a declared implementation relationship. Repeated declarations share one Provider entity and one relationship per exact Provider definition and Mechanic version. All contributing source observations remain linked to that relationship.

The 191 Mechanics comprise 54 atomic definitions from the semantic-value and platform-effect authorities and 137 named vocabulary entries explicitly declared by the platform catalog. The latter have no invented description. The source vocabularies use different names; the load does not equate similar terms or manufacture implementation links between them. The 314 declared relationships target the catalog's 137 Mechanics. The 54 atomic definitions have no exact Provider relationship in these declarations. Declared implementation is separate from qualification or runtime readiness.

Platform Capability declarations occupy their own namespace: 70 identities and 85 exact definitions. The selected managed estate still contains 219 Capabilities. Provider identity is independent of Capability identity; the implementation tables express the relationships.

Run [mechanics.sql](../sql/diagnostics/mechanics.sql) to inspect counts, endpoint integrity, vocabulary coverage, and all Provider-to-Mechanic pairs through their exact definitions. It also reports overall source coverage.

## Verification and resumption

`npm run verify` checked the stored counts of all 124 application tables against the load manifest. Every count matched. Entity families had zero null IDs and zero duplicate semantic keys. All 355 foreign keys and all CHECK constraints were enabled and trusted. The Mechanic implementation query returned zero missing endpoints and zero duplicate definition pairs. The selected views retain their declared row grain.

All 17 local tests passed, including the complete platform candidate and the corrected relationship counts. SQL verified zero assertion-condition links crossing Capability ownership and all 16 shared execution operations. Entity keys, relationship constraints and view grains passed verification.

The final validation timeout came from repeatedly expanding the normalized-member union while checking lineage. Migration 003 materializes that member set once and indexes it for the same checks. A database test inserted an invalid lineage pointer, confirmed `G_LINEAGE_DANGLING` rejection, and rolled back the test row. Final publication then passed with the checks retained.

The load uses `data/platform/table-checkpoints.json`. It builds the complete candidate first, commits each table independently, and publishes once after all tables finish. A full restart returned `ALREADY_LOADED` without inserting duplicate rows. Final validation cannot roll back earlier table commits. Changed mapping bytes cannot reuse this generation's checkpoint.

Current generation:

- Snapshot: `sha256:9847398372268c4ff2b5ae36f61c332e6f84ef38418dd478fe6b0f641143f2de`.
- Mapping manifest: `819be21225c4e644a335863f427bf0ef3ccf1c8526e2a4e49f8cb79603f75d00`.
- Load counts: `data/platform/load-result.json`.
- Database verification: `data/migration/verification.json`.
- Table commit log: `data/platform/corrected-load.log` (prior generation; the generation-four log is the load result itself).
- Restart verification: `data/platform/corrected-resume.log` (prior generation).

## Generation four: python and csharp mechanic registries

The pinned bootstrap moved from `87ae918c…` to `78e23b6…`, whose platform closure carries the python and csharp mechanic registries declared on the SDA branch (`0e52d24`) alongside the node registry. The normalization reads all three registry sources, and the platform importer ingests every `*-mechanic-registry-authority.v1` source instead of the node registry alone.

The estate was administratively replaced rather than amended: the immutability triggers were disabled for the duration, 124 tables were cleared in foreign-key-safe order (1,039,000 rows), the triggers re-enabled, and the previous generation's checkpoints preserved under `data/preserved/before-python-csharp-registries-*` before the new load began.

The load committed 81 tables and published the new generation:

- Snapshot: `sha256:9847398372268c4ff2b5ae36f61c332e6f84ef38418dd478fe6b0f641143f2de`.
- Mapping manifest: `819be21225c4e644a335863f427bf0ef3ccf1c8526e2a4e49f8cb79603f75d00`.
- Load result: `LOADED_AND_SELECTED` (`data/platform/load-result.json`).
- Database verification: `VERIFIED` (`data/migration/verification.json`).

New relationships: `model.provider_profile` grew from 2 to **6** (one pure and one effect profile per language), profile constraints from 4 to 12, and the two registry authorities were added. Every one of the 54 atomic mechanics now has a declared native resolution for node, python and csharp.

Readiness was measured per selected scenario with `data/platform/readiness-all.mjs`, which replicates the aggregate view's resolution logic over the requirements function (the aggregate view itself exceeds the query budget). Node, python and csharp account for 100% of requirements on all 10 selected scenario bodies and report `CAN_ATTEMPT_EMBODIMENT`; cpp, go and java remain `NOT_OBSERVABLE` until their registries exist. No mechanic requirement carries more than one binding candidate.

## Source coverage and remaining gaps

Every valid in-scope declaration is loaded and **no table is empty because of a missing importer mapping**. The estate is not fully normalized, because the remaining gaps are source defects and agreed exclusions, each dispositioned in [migration-closure.md](migration-closure.md). Current source coverage is:

| Classification | Source appearances |
|---|---:|
| Normalized | 4,714 |
| Unresolved | 14 |
| Unsupported mapping | 1,908 |
| Outside declared scope | 1,567 |
| Total captured and classified | 8,203 |

These counts describe source appearances, including repeated copies, rather than unique entities. There are 3,804 unresolved reference records in the selected model. This count now includes assertion-condition references that the previous importer did not inspect. All 824 Scenarios have Input, Event and Outcome rows, but 18 do not satisfy the complete-scenario view because required references remain unresolved or absent.

Historical Contract catalog path resolution is corrected. The largest remaining gap is the Blueprint authority pins: **zero of 2,153** blueprint authority references resolve to a declared authority document anywhere in the pinned scope, and 9 of 35 referenced digests are each claimed by three different `authorityId`s. Thirty-five Blueprints have normalized nodes and supported face/Scenario links; their unresolved edge-authority pins have not been replaced with inferred topology. Product, binding, qualification and proof tables have no matching declaration in the agreed scope; an empty table alone does not authorize inventing an entity or assessment.

Use `sidefx.v_load_completeness` for the aggregate and `sidefx.v_source_reference_gap` for source paths and unresolved roles. Appearance-level detail is in `data/platform/appearance-coverage.json`. A successful integrity check proves the committed relational data meets the implemented constraints; it does not erase these mapping gaps.
