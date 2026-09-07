# Committed data and mapping coverage

The remaining migration work and its stopping criteria are in [completion-plan.md](completion-plan.md).

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

- Snapshot: `sha256:38debec6dbfa1266f68d903166f69b831c178ffe967208900efcddd9ce2973bc`.
- Mapping manifest: `81eb41f0faeadcb413d1b5bae9ba991f2d9d753489cfb3a8919c5f72e71f7d28`.
- Load counts: `data/platform/load-result.json`.
- Database verification: `data/migration/verification.json`.
- Table commit log: `data/platform/corrected-load.log`.
- Restart verification: `data/platform/corrected-resume.log`.

## Remaining mapping work

The expected rows for the implemented mappings are loaded. **The complete estate is not yet fully normalized.** Current source coverage is:

| Classification | Source appearances |
|---|---:|
| Normalized | 4,712 |
| Unresolved | 14 |
| Unsupported mapping | 1,908 |
| Outside declared scope | 1,549 |
| Total captured and classified | 8,183 |

These counts describe source appearances, including repeated copies, rather than unique entities. There are 3,804 unresolved reference records in the selected model. This count now includes assertion-condition references that the previous importer did not inspect. All 824 Scenarios have Input, Event and Outcome rows, but 18 do not satisfy the complete-scenario view because required references remain unresolved or absent.

Historical Contract catalog path resolution is corrected. Remaining coverage includes partial interface, fixture and shared-library mappings and historical Blueprint authority references. Thirty-five Blueprints have normalized nodes and supported face/Scenario links. Their unresolved edge-authority pins have not been replaced with inferred topology. Product, binding, qualification and proof tables require explicit matching declarations or supported mappings; an empty table alone does not authorize inventing an entity or assessment.

Use `sidefx.v_load_completeness` for the aggregate and `sidefx.v_source_reference_gap` for source paths and unresolved roles. Appearance-level detail is in `data/platform/appearance-coverage.json`. A successful integrity check proves the committed relational data meets the implemented constraints; it does not erase these mapping gaps.
