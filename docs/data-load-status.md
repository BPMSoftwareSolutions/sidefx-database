# Committed data and mapping coverage

The remaining migration work and its stopping criteria are in [completion-plan.md](completion-plan.md).

Model 3 is published and selected in the inspection database. The mechanic load is committed: `model.mechanic` contains **191** rows and `model.provider_mechanic_implementation` contains **314** rows. Each table was committed separately before the final validation and selection transaction.

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

The platform catalog supplies 69 Provider identities in addition to five previously loaded Providers. Its explicit `provider` field supplies the identity; each `providesMechanics` entry supplies a declared implementation relationship. Repeated declarations share one Provider entity and one relationship per exact Provider definition and Mechanic version. All contributing source observations remain linked to that relationship.

The 191 Mechanics comprise 54 atomic definitions from the semantic-value and platform-effect authorities and 137 named vocabulary entries explicitly declared by the platform catalog. The latter have no invented description. The source vocabularies use different names; the load does not equate similar terms or manufacture implementation links between them. The 314 declared relationships target the catalog's 137 Mechanics. The 54 atomic definitions have no exact Provider relationship in these declarations. Declared implementation is separate from qualification or runtime readiness.

Platform Capability declarations occupy their own namespace: 70 identities and 85 exact definitions. The selected managed estate still contains 219 Capabilities. Provider identity is independent of Capability identity; the implementation tables express the relationships.

Run [mechanics.sql](../sql/diagnostics/mechanics.sql) to inspect counts, endpoint integrity, vocabulary coverage, and all Provider-to-Mechanic pairs through their exact definitions. It also reports overall source coverage.

## Verification and resumption

`npm run verify` checked the stored counts of all 124 application tables against the load manifest. Every count matched. Entity families had zero null IDs and zero duplicate semantic keys. All 355 foreign keys and all CHECK constraints were enabled and trusted. The Mechanic implementation query returned zero missing endpoints and zero duplicate definition pairs. The selected views retain their declared row grain.

The focused normalization tests cover declared identity, implementation-pair uniqueness, endpoint existence, preservation of managed membership, and lineage within the dependency snapshot. The earlier shared-library and Blueprint mapping tests also passed.

The final validation timeout came from repeatedly expanding the normalized-member union while checking lineage. Migration 003 materializes that member set once and indexes it for the same checks. A database test inserted an invalid lineage pointer, confirmed `G_LINEAGE_DANGLING` rejection, and rolled back the test row. Final publication then passed with the checks retained.

The load uses `data/platform/table-checkpoints.json` to resume this extension. A full restart completed successfully with `ALREADY_LOADED`: every appended table was checked against its actual committed contents and skipped without inserting duplicate rows. Final validation cannot roll back earlier table commits. Keep the mapping implementations and their configuration unchanged for this already committed generation; a changed mapping requires a new version.

Current generation:

- Snapshot: `sha256:38debec6dbfa1266f68d903166f69b831c178ffe967208900efcddd9ce2973bc`.
- Mapping manifest: `2b02af3cb0250f0efed911e6a25bffc13e58e05f0a51ee37ed95f5611a9a3dca`.
- Load counts: `data/platform/load-result.json`.
- Database verification: `data/migration/verification.json`.
- Executed read query: `data/platform/mechanics-query.json`.
- Restart verification: `data/platform/resume-verification.log`.

## Remaining mapping work

The expected rows for the implemented mappings are loaded. **The complete estate is not yet fully normalized.** Current source coverage is:

| Classification | Source appearances |
|---|---:|
| Normalized | 4,686 |
| Unresolved | 14 |
| Unsupported mapping | 1,934 |
| Outside declared scope | 1,549 |
| Total captured and classified | 8,183 |

These counts describe source appearances, including repeated copies, rather than unique entities. There are 735 unresolved reference records in the selected model. All 824 Scenarios have Input, Event and Outcome rows, but 61 do not satisfy the complete-scenario view because required references remain unresolved.

Known remaining work includes resolving historical Contract catalog paths to captured repository schemas; completing partial interface, fixture and shared-library mappings; and handling historical Blueprint authority references. Thirty-five Blueprints have normalized nodes and supported face/Scenario links. Their unresolved edge-authority pins have not been replaced with inferred topology. Product, binding, qualification and proof tables require explicit matching declarations or supported mappings; an empty table alone does not authorize inventing an entity or assessment.

Use `sidefx.v_load_completeness` for the aggregate and `sidefx.v_source_reference_gap` for source paths and unresolved roles. Appearance-level detail is in `data/platform/appearance-coverage.json`. A successful integrity check proves the committed relational data meets the implemented constraints; it does not erase these mapping gaps.
