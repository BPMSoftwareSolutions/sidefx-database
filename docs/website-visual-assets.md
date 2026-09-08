# Estate visual assets and website discovery

Status: proposed additive storage and website integration design, updated 2026-09-08. The inventory below was queried from the selected live database through the existing restricted reader. This document does not apply a migration, generate images, or modify semantic authority.

## Observed estate

Run the reusable [visual inventory query](../sql/diagnostics/website-visual-inventory.sql):

```powershell
node src/cli.mjs query --file sql/diagnostics/website-visual-inventory.sql --limit 5000
```

The inspected query completed with `READ_QUERY_COMPLETE`, `truncated: false`. Its nine result sets contain generation identity, entity/definition counts, managed-capability membership, mechanics, exact implementation relationships, providers, selected scenario faces, blueprints and source-byte totals.

| Selected scope | Identities | Definitions / relationships |
| --- | ---: | ---: |
| Managed capabilities | 219 | One selected managed definition per capability |
| All selected capability identities, including platform declarations | 289 | 304 definitions |
| Mechanics | 191 | 191 definitions |
| Providers | 74 | 74 definitions |
| Provider–mechanic implementations | — | 314 declared relationships |
| Scenarios | 824 | 824 selected definitions, each with input/event/outcome members |
| Blueprints | 35 | 449 normalized nodes, zero normalized edges |
| Contracts | 616 | 630 definitions |
| Ports | 1,013 | 1,013 definitions |
| Provider profiles | 6 | 6 definitions |

The first image inventory contains **484 subjects** for the 219 managed capabilities, 191 mechanics and 74 providers. Including the 70 additional platform capability identities gives **554 subjects**. These are subject counts, not generation-call counts or a statement that imagery is already present. Revisions, crops and production failures have their own accounting.

The pasted mechanic inventory contains exactly the same 191 mechanic IDs as this selected generation. This comparison establishes ID-set agreement, not equivalence of every definition field or runtime implementation.

Generation inspected:

- Snapshot: `sha256:9847398372268c4ff2b5ae36f61c332e6f84ef38418dd478fe6b0f641143f2de`.
- Mapping manifest: `sha256:819be21225c4e644a335863f427bf0ef3ccf1c8526e2a4e49f8cb79603f75d00`.
- The current source byte store contains 32,972 content objects / 329,030,255 bytes. Those are captured-source objects; the query does not classify them as generated images.

### Mechanics and their providers

| Definition profile | Mechanics | With rows in provider_mechanic_implementation | Display name coverage |
| --- | ---: | ---: | --- |
| `semantic-value-mechanics-authority.v1` | 36 | 0 | 36 named |
| `platform-effect-mechanics-authority.v1` | 18 | 0 | 18 named |
| `sda-platform-provided-mechanic.v1` | 137 | 137 | All 137 name fields absent |

The 54 atomic mechanics include value transformation and controlled effects: `map`, `filter`, `parse-json`, `sha256`, `perform-http-exchange`, `write-file-atomically`, and `execute-bounded-process`. Their zero relationship count in this table does not establish an absence of native language implementations. Language registries and scenario resolution expose a separate declaration surface; preserve the source distinction.

The platform vocabulary covers responsibilities such as `scenario-orchestration`, `schema-admission`, `authority-resolution`, `telemetry-observation`, `interface-delivery`, and `runtime-projection`. Labels and illustrations can make these discoverable. Store a reviewed editorial name/description as presentation metadata, retain the exact mechanic ID, and cite the source used to explain the mechanic. A name-only declaration cannot support invented input/output behavior.

Examples of actual provider relationships:

| Provider identity | Declared mechanic relationships | Declared capability relationships |
| --- | ---: | ---: |
| `ScenarioKernel.Adapters.Consumer.AdmittedConsumerPlatform` | 22 | 6 |
| `scenario_kernel.platform.consumer` | 19 | 4 |
| `ScenarioKernel.Wpf.AuthorityBackedViewModel` | 15 | 1 |
| `ScenarioKernel.NodePlatform` | 14 | 1 |

These counts support discoverability and comparison of declarations. They do not demonstrate runtime readiness, provider interchangeability or conformance. Public target labels must come from actual target metadata, not guesses based on provider names.

### Query precision

The user's base-table queries are useful for inspection. For website content, pin the selected model and join the selected capability/scenario membership before retrieving faces. Joining every `scenario_version` can mix historical definitions; inner joins to input/event/outcome omit incomplete scenarios. The reusable query uses exact selected membership and left joins to retain missing faces.

All 824 scenarios currently have the three face members; that is weaker than complete reference resolution or execution proof. Likewise, zero normalized blueprint edges is a documented source-resolution gap, not permission to infer wiring from node order or images. Use source-backed boundary views where detailed topology is unavailable.

## Storage decision

**Generated image bytes must be stored durably in this SQL Server database, together with generation provenance and entity bindings.** A local file path, provider URL, external object-store URL or CDN URL alone does not satisfy this requirement. Keep original outputs, reviewed derivatives, and any circuit/vector source used to produce those derivatives recoverable from the database.

Use an additive `media` schema. Semantic tables retain their existing meaning. The current `source.content_object` implementation demonstrates the content-addressed `varbinary(max)` pattern, but generated visual assets belong to media production rather than captured estate testimony. Do not insert generated art as a source declaration or change immutable semantic definitions to attach an image.

The production website reads approved media through an application service. It may publish hash-addressed copies to a CDN for delivery; those copies are rebuildable from database bytes. Catalog queries return metadata, dimensions and media identity, never bulk binary columns. Binary retrieval is a separate streaming operation with an exact asset revision, digest and content type.

### Proposed relations

These names and columns are a migration design, not existing tables. Keep binary storage, generation, semantic attachment, editorial review and current selection as separate records.

| Relation | Required contract |
| --- | --- |
| `media.blob` | Blob PK; unique SHA-256 digest; exact `varbinary(max)` bytes; nonnegative byte length matching `DATALENGTH`; media type; creation timestamp. Validate hash against bytes. Preserve original provider bytes without re-encoding. |
| `media.generation_request` | Durable request/job identity; idempotency key; owner/scope; requested subject and exact source definition; visual purpose; prompt/direction/reference digests and retained request content; provider/model; attempts; status; timestamps; provider request ID and failure/reconciliation state. Credential values are excluded. |
| `media.asset` | Stable logical asset identity and purpose, with ownership/access scope. Multiple revisions belong to one asset. |
| `media.asset_revision` | Immutable revision; asset PK; blob FK; origin (`GENERATED`, `COMPOSITED`, `DERIVED`, `IMPORTED`); generation request when applicable; decoded format/dimensions; source/direction/renderer versions; creation identity/time. A format change produces new bytes and a new revision. |
| `media.asset_source` | Exact source asset revision or semantic definition used for generation/composition, with role and digest. Use typed relations for semantic sources and asset parents so every reference has a real FK. Multiple parents support a circuit composed with several material plates. |
| `media.entity_visual_binding` | Asset revision plus `semantic_object_pk` and exact `semantic_object_definition_pk`; subject role, visual role (hero/card/portrait/explainer/circuit), locale, variant and presentation description/alt text. Composite FK proves that the definition belongs to that semantic object. |
| `media.asset_review` | Append-only decision against exact revision, source binding and purpose; reviewer, disposition, reasons and timestamp. Generation success alone does not approve an image for publication. |
| `media.visual_requirement` | One required subject-definition/visual-role/locale/variant slot, its art direction and production state; records absence before an image exists. Includes capability, mechanic and provider requirements by default. |
| `media.visual_selection` | Current approved revision/binding for one requirement slot, selected transactionally with concurrency control and retained selection history. Selection requires a matching source definition, permitted binding and applicable review. |

An input reference set must be relationally inspectable and hashable; JSON may retain the exact provider request/response, but cannot be the sole storage of entity ownership or parent-asset relationships. Distinct generation requests may yield identical bytes: deduplicate the blob, retain each request/revision lineage.

### Entity identity and version integrity

Capabilities, mechanics, providers, scenarios, blueprints and other modeled entities already have `model.semantic_object` identities and exact `model.semantic_object_definition` definitions. Bind media to those real keys. Avoid an unconstrained pair such as `entity_type='mechanic', entity_id='filter'`, which loses namespace and FK integrity. Titles and slugs never serve as foreign keys.

Use `(semantic_object_definition_pk, semantic_object_pk, object_kind, definition_digest)` or the applicable existing composite key to validate the attachment. Both stable identity and exact definition are retained: identity supports discovery, while the definition determines whether an image's meaning is current. Several reviewed bindings may reuse an unchanged asset across source revisions; new source meaning requires explicit compatibility review or regeneration.

Owned drafts that have not entered the estate require a separate draft binding with a real FK to the implemented workspace revision store. Do not manufacture a published semantic object merely to store draft art. Admission can add an exact semantic binding while retaining draft and generation lineage; storage bytes need not be copied.

Archive/source refresh and media retention have distinct lifecycles. Ordinary estate ingestion must not clear media tables. Never cascade-delete image history when retiring a model definition. Database rebuild/migration must preserve bytes and portable bindings (namespace kind/ID, object kind/ID, definition digest), then rebind verified identities; a surrogate PK alone cannot survive a rebuild safely. This is a required restore test.

### Publication and recovery

Generation and upload commit an immutable blob/revision first. A later reviewed selection atomically makes that revision current for its exact subject and purpose. An interrupted job cannot publish a half-written image; uncertain generation outcomes must be reconciled before reissuing a paid request. Failed generations retain the requirement and diagnostics.

Serve only selected, approved, authorized revisions; a guessed media ID cannot expose another workspace's images or request metadata. Give media-writing service roles only the required insertion/selection operations. Keep the estate reader boundary intact. Public cache URLs expose a reviewed artifact identity, not database connection details or private prompts.

Image replacement updates the selected binding, not old bytes. Historical articles/videos retain their pinned visual revision. Revocation invalidates public copies while preserving internal audit data according to the retention policy. Backups include image bytes, requests, reviews, source bindings and selection history. Retention/garbage collection must account for all those references before deleting any unreferenced blob.

## What gets an image

| Subject | Required depiction | Source-specific rule |
| --- | --- | --- |
| Capability | Intended human experience and its inspectable circuit | Dedicated Nano Banana image plus deterministic SCL view |
| Mechanic | Its declared transformation/responsibility, recognizable at small size | One reusable subject image across occurrences; concrete I/O example only when supported by the definition |
| Provider | The provider's declared role and its supported mechanics/ports | Distinct provider portrait/tile; generated art is not an official logo or proof of affiliation |
| Scenario | Input → event → outcome and the intended experience | Exact scenario owner/revision; source-derived circuit before decorative enhancement |
| Blueprint | Its declared graph/architecture | Deterministic geometry first; incomplete topology remains visible |
| Port/contract | Required responsibility or data boundary | Reuse the typed grammar; richer illustration when its detail page or teaching use requires it |
| Input/event/outcome, authority, evidence, provider profile | Typed symbol and optional contextual explanation | Extend through the same registry; do not issue unique generative jobs for every occurrence of a shared symbol |

Core coverage is mandatory for each capability, mechanic and provider. Scenarios/blueprints and other subjects receive explicit requirements when surfaced in pages, teaching material or authoring. This defines “etc.” without turning thousands of repeated graph primitives into separate image-generation jobs. Shared symbols/materials coexist with distinct entity artwork.

## Website and IDE use

Add mechanic and provider catalogs/detail pages backed by selected definitions. A mechanic page shows its exact identity, readable description, dedicated image, declared inputs/results where available, providers and source-backed usage. A provider page shows its portrait, declared mechanics/ports/capabilities, profile/target declarations and evidence. Selecting a mechanic or provider from a capability circuit opens the same entity view and image, preserving source revision.

Capability → selected scenario → execution requirement → mechanic → declared provider is a navigable chain only where explicit relations support it. Mechanic names alone cannot establish a capability dependency. Expose implementation declarations separately from selected bindings and qualification results. These pages also supply reusable, source-bound YouTube lessons and IDE explanations.

The existing content-lab Nano Banana workflow remains the image provider; SCL owns circuit structure. After generation, ingest original image bytes and provenance into the media service; ingest each composite/crop as its own derivative with source links. A successful provider URL response without a committed database asset is an incomplete production job.

## Implementation acceptance

- A migration adds the media relations without changing source definitions, selected-model membership or immutable estate data.
- Round-trip an actual generated PNG/JPEG through the database; downloaded bytes have the original digest. Derivative bytes have their own digests and parent lineage.
- Reject wrong-entity/wrong-definition bindings, duplicate selected slots, missing bytes, mismatched hash/length, and unapproved public selection. Keep a positive valid attachment for each rejected case.
- The same provider/mechanic image is reused across its graph occurrences without losing exact subject revision.
- A second generation, an editorial rejection, a failed upload, and an interrupted selection retain the previous approved image and complete history.
- Coverage reports count required/queued/failed/stale/ready subjects by kind; missing image rows cannot disappear from the denominator.
- Catalog requests do not retrieve binary payloads; a detail request streams only the selected authorized asset and verifies its digest/type.
- A source revision change marks affected bindings stale; unchanged semantic meaning can be explicitly rebound after review. Restoring the database preserves images and exact portable subject identity.
- No schema or image-generation acceptance is claimed by this design-only update. The read-only inventory query has been executed successfully against the selected database.
