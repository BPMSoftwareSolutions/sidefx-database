# Migration closure

The source-to-table reconciliation is complete. Every one of the 124 application tables has an
evidenced disposition, and no table is empty because of a missing or incorrect importer mapping.

Closing state, verified in SQL against the selected model:

| Fact | Value |
|---|---|
| Selected model | `estate_model_pk` 3, `PUBLISHED` |
| Snapshot | `sha256:38debec6dbfa1266f68d903166f69b831c178ffe967208900efcddd9ce2973bc` |
| Pinned dependency | `sda-bootstrap@87ae918ce46fe4acadd0aecbdcb030c9b55043d9` |
| Verification | `VERIFIED` |
| Application tables | 124 — 82 populated, 42 empty and dispositioned |
| Captured appearances | 8,183 — all classified |
| Foreign keys / CHECK constraints | 355 / 177, **zero** disabled or untrusted |
| Entity keys | zero null semantic IDs, zero duplicate semantic keys |
| Repeat load | `ALREADY_LOADED` — unchanged counts and contents |

## What the reconciliation changed

The audit separated importer defects from source defects by resolving every declaration against the
captured source rather than against generated rows. Five importer defects were found and corrected;
the corrected mappings were proven locally before any database load, then loaded by one controlled
rebuild through the approved schema and the existing table-by-table loader.

| Fix | Defect | Correction |
|---|---|---|
| Contract references | 84 catalog entries resolved their schema locator against the capsule *entry* root. Locators such as `../../../authority/sidefx-semantic-brain/contracts/sidefx-semantic-common.schema.json` escape that root and failed. | A locator now resolves against the entry root first, then against the catalog's captured repository source path within the same capsule. All 84 resolve; zero ambiguous. |
| Shared event authorities | Scenario event binding consulted only the capsule-local authority, so a scenario declaring a shared-library authority went unresolved. | Shared `agentic` and `feature-authoring` authorities are bound under explicit namespaces before capsule scenarios. A capsule-local declaration of the same ID still wins. |
| `project-state` operations | The operation kind was rejected outright, which also invalidated its whole execution authority. | A `project-state` operation resolves when its `projectionId` is declared by the same capsule interface authority and names an exact `transformationId` in that capsule's transformation authority. |
| Assertion conditions | The declared `conditionId` was stored as a column but never joined to its condition. | An assertion binds a condition only when that condition is declared by the capability owning the fixture. An unresolved reference is recorded separately and never invents a condition. |
| Fan-out sets | Declared sets were never emitted. | A declared set loads with its blueprint, independent of edge binding authority. Membership still waits for a resolvable edge. |

Measured effect, against the previously committed generation:

| Measure | Before | After |
|---|---|---|
| Complete Scenarios (`v_complete_scenario`) | 763 | **806** of 824 |
| Normalized appearances | 4,686 | **4,712** |
| Unsupported appearances | 1,934 | **1,908** |
| `model.contract` | 565 | **616** |
| `model.fixture_assertion_condition` | 0 | **432** |
| `model.operation_state_projection` | 0 | **3** |
| `model.blueprint_fan_out_set` | 0 | **3** |

Scenario completeness improved by 43, not by the sum of the individual findings: the corrected
contract and event bindings overlap on the same scenarios. The 3,840 declared `conditionId`
references likewise produced 432 valid relationships, not 3,840 — the rest do not resolve within
their declared ownership scope and are recorded as source gaps.

## Disposition of the 42 empty tables

Nineteen are a verified absence of any declaring source, nine are an exclusion the approved
architecture already states, and fourteen are blocked by a source defect. **None is an importer gap.**

| Table | Disposition | Evidence |
|---|---|---|
| `model.definition_version_label` | VERIFIED ABSENCE | No managed capsule authority declares a version label. Every `version`/`capabilityVersion` field in the snapshot sits on a repository authority document outside the labelled-definition profile. |
| `model.product` | VERIFIED ABSENCE | Product is declared only by the carrier profile (S-02/S-03 `/scenarios/*/outcome/product`). The snapshot contains carrier **schemas only** — zero carrier instance documents. Every other `product` occurrence is a schema `$defs` entry or a fixture payload value, which §v2 sourceBoundary classes as a value, not a declaration. |
| `model.product_definition` | VERIFIED ABSENCE | As `model.product`. |
| `model.outcome_product` | VERIFIED ABSENCE | Requires a declared Product. No scenario outcome in any captured profile declares one. |
| `model.outcome_variant_product` | VERIFIED ABSENCE | Requires a declared Product and an explicitly conditioned establishment; neither is declared. |
| `model.port_contract` | VERIFIED ABSENCE | All 1,039 `portBindings` across 222 distinct `consumer-interface-authority.v1` documents declare exactly `{portId, platformCapabilityId, configuration}`. Zero declare a port contract in any direction. |
| `model.operation_mechanic` | VERIFIED ABSENCE | `mechanicRefs` occurs only in carrier schemas and fixture payload values. All 1,576 `execution-authorities.v1` operations are exactly `{kind, portId|scenarioId|projectionId}`. |
| `model.operation_predecessor` | VERIFIED ABSENCE | `predecessorRefs` occurs only in carrier schemas and fixture payloads. Operation order is the declared array ordinal; no dependency edge is declared. |
| `model.expression_semantic_reference` | VERIFIED ABSENCE | The expression grammar is pure data transformation (`path`, `literal`, `object`, `equals`, `if`, `array`, `format`, `merge`, …). Only 2 `scenarioId` operands appear anywhere and neither is a reviewed governed-reference form. |
| `model.operation_transformation` | VERIFIED ABSENCE | No execution operation declares a transformation use. Port and projection configurations are separate declarations, already mapped. |
| `model.provider_port_implementation` | AGREED EXCLUSION | §7.1 requires an explicit classified implementation declaration. S-12 supplies `operations`/`candidateCapabilities`/`commandBindings`/`conformanceClaims`, all explicitly ruled insufficient; S-06 `platformCapabilityId` is a Capability reference, never a Provider. |
| `model.slot_mechanic_requirement` | VERIFIED ABSENCE | 55 provider slots and 41 port requirements ARE loaded. All **99** declared `providerSlot` objects have exactly `{portId, mode}` — zero declare a mechanic. Matches S-09 ("this schema's `providerSlot` requires `portId,mode`"). Mechanic slots exist only in S-11 runtime plans (`MANAGED_RUNTIME`, outside the approved boundary). |
| `model.slot_profile_requirement` | VERIFIED ABSENCE | As above: zero of 99 `providerSlot` declarations name a profile. The 2 Provider Profiles that do exist come from the pinned dependency and are loaded. |
| `model.slot_profile_constraint` | VERIFIED ABSENCE | As above: zero of 99 `providerSlot` declarations carry constraints. S-11 `profileConstraints` is the only source and is outside the current model. |
| `model.binding_context` | AGREED EXCLUSION | Binding is declared only by S-11 `realizationOverlay.providerBindings` (`MANAGED_RUNTIME`), outside the approved boundary. |
| `model.provider_binding_scope` | AGREED EXCLUSION | As `binding_context`. |
| `model.provider_binding` | AGREED EXCLUSION | As `binding_context`. |
| `model.binding_port_implementation` | AGREED EXCLUSION | As `binding_context`; also requires `provider_port_implementation`. |
| `model.binding_mechanic_implementation` | AGREED EXCLUSION | As `binding_context`. |
| `model.provider_slot_operation` | VERIFIED ABSENCE | §7.1: slot existence does not imply an operation association. No source declares the mapping. |
| `model.blueprint_edge` | SOURCE DEFECT | 879 edges are declared with complete topology, but `binding_authority_definition_pk` is NOT NULL and **0 of 2,153** blueprint authority references resolve to a declared authority document anywhere in the pinned scope (Harness + `sda-bootstrap@87ae918`). 9 of 35 referenced digests are each claimed by 3 different `authorityId`s, which no single document can satisfy. 554 `DEFINITION_UNRESOLVED` findings record this. |
| `model.blueprint_edge_contract` | SOURCE DEFECT | Requires `blueprint_edge` and a declared Product; both unavailable. 30 edges declare `contractRelation`. |
| `model.blueprint_convergence_requirement` | SOURCE DEFECT | 20 blueprint nodes declare `requiredProducts`, but no Product is declared anywhere — references without targets (`CONVERGENCE_PRODUCT`). |
| `model.blueprint_fan_out_member` | SOURCE DEFECT | Members are edges. The 3 declared fan-out **sets** now load; membership waits on a resolvable edge. |
| `model.blueprint_bounded_return` | SOURCE DEFECT | 141 edges declare `boundedReturn`, each requiring its edge plus an authority reference from the same unresolvable pin set. |
| `model.proof_obligation` | AGREED EXCLUSION | The only `proofObligation` declarations are S-16 evaluation evidence (107 in `sidefx-semantic-relationship-graph.v1.json`) and 560 fixture payload values. §3/§9.1 forbid promoting evaluation evidence into capability-owned admitted obligations. |
| `model.proof_obligation_subject` | AGREED EXCLUSION | As `proof_obligation`. |
| `model.proof_obligation_fixture` | AGREED EXCLUSION | As `proof_obligation`. |
| `model.c4_context` | SOURCE DEFECT | 46 of 49 blueprints declare `structuralMapping.context` with `elementId` and `nodeIds`, but `realization_authority_definition_pk` is NOT NULL and its `realizationAuthority` pins come from the same unresolvable, digest-contradictory set. |
| `model.c4_container` | SOURCE DEFECT | As `c4_context`. |
| `model.c4_component` | SOURCE DEFECT | As `c4_context`. |
| `model.c4_code_mapping` | SOURCE DEFECT | As `c4_context`. |
| `model.c4_context_node` | SOURCE DEFECT | Members of an unloadable parent. |
| `model.c4_container_node` | SOURCE DEFECT | Members of an unloadable parent. |
| `model.c4_component_node` | SOURCE DEFECT | Members of an unloadable parent. |
| `model.c4_code_mapping_node` | SOURCE DEFECT | Members of an unloadable parent. |
| `model.blueprint_observed_transition_mapping` | VERIFIED ABSENCE | §10 requires a declared D0 mapping authority; none exists, and there are no blueprint edges to map to. §10 states absence of D0 mapping is itself the recorded gap. |
| `model.blueprint_observed_invocation_mapping` | VERIFIED ABSENCE | As above. |
| `analysis.assessment_definition_input` | VERIFIED ABSENCE | Both assessments in this model (integrity, coverage) are scoped over source observations, recorded in `assessment_source_input` (28,024 rows). Neither declares a definition-scoped input, so no row is fabricated. |
| `analysis.compatibility_assessment` | VERIFIED ABSENCE | No compatibility authority or rule is declared. §11: equality is not a compatibility rule; no row means view status `NOT_EVALUATED`. |
| `analysis.circuit_assessment` | SOURCE DEFECT | `G-GEOMETRY` cannot be evaluated without blueprint edges (see `blueprint_edge`). |
| `analysis.provider_qualification_assessment` | VERIFIED ABSENCE | §7.2: S-12 `conformanceClaims` and a plan's `providerProfileId` are explicitly insufficient to establish qualification authority. None is declared. |

## Remaining source defects

These are defects in the authoritative estate, not in this inspection database. Exposing them is
part of its purpose. Every one is queryable through `sidefx.v_source_reference_gap` by
`reference_role` and `resolution_state`.

| Role | State | Count | What the source actually declares |
|---|---|---:|---|
| `ASSERTION_CONDITION` | `MISSING_TARGET` | 3,114 | A `conditionId` used as a free assertion label. The overwhelming majority name IDs never declared as an observable condition anywhere (`adapted`, `held`, `no-findings`); 39 name a condition owned by a different capability. |
| `BLUEPRINT_EDGE` | `DEFINITION_UNRESOLVED` | 508 | Edges declare complete topology but pin a binding authority that does not exist. **Zero of 2,153** blueprint authority references resolve to a declared authority document in the pinned scope, and 9 of 35 referenced digests are each claimed by 3 different `authorityId`s. |
| `BLUEPRINT_SCENARIO_FACES` | `MISSING_TARGET` | 59 | A node cell whose three face identities do not agree with any one scenario of the declared capability. |
| `C4_REALIZATION_AUTHORITY` | `DEFINITION_UNRESOLVED` | 32 | `structuralMapping` realization authorities drawn from the same unresolvable, contradictory pin set. |
| `EVENT_AUTHORITY` | `MISSING_TARGET` | 16 | Scenario `@event-authority` IDs declared in no authority document anywhere in the pinned scope. |
| `CONVERGENCE_PRODUCT` | `MISSING_TARGET` | 15 | Blueprint nodes require Products, but no Product is declared anywhere in the captured estate. |
| `BLUEPRINT_CAPABILITY` | `DEFINITION_UNRESOLVED` | 14 | A blueprint whose `capabilityAuthorityDigest` is not an exact contribution to the selected capability definition. |
| `SLOT_PORT` | `MISSING_TARGET` | 14 | Provider slots naming ports declared nowhere. 44 of the 99 declared slots resolve to their own capability's ports; **none** resolve to a shared-library port, so this is not an importer scope limit. |
| `INPUT_CONTRACT` | `MISSING_TARGET` | 12 | Scenario `@input-contract` IDs absent from the capsule catalog after the corrected path resolution. |
| `SEMANTIC_GRAPH_TRANSITION` | `MISSING_TARGET` | 11 | Observed transitions whose endpoints do not resolve to exact declared faces and variants. |
| `BLUEPRINT_NODE` | `PROFILE_UNSUPPORTED` | 7 | Nodes lacking a required declared ID or projection ordinal. |
| `PROVIDER_PROFILE` | `MISSING_TARGET` | 1 | A runtime declaration referencing a profile with no definition. |
| `PROVIDER_CAPABILITY` | `MISSING_TARGET` | 1 | A provider capability pin that resolves to no managed capsule. |
| | | **3,804** | |

Two further defects are visible as findings rather than reference gaps: 14 capsules carry two
divergent feature documents for one capability (a capsule-local `.feature.local` and the
repository-root feature, with different bytes declaring the same scenario IDs), and
`manage-capsule-estate` carries a feature with no `@capability` tag. Conflicting declarations
remain unsupported by rule rather than being silently merged.

## Completion checklist

- [x] Required source locations and exact dependency references are accounted for, including the pinned bootstrap revision.
- [x] Every table has an evidenced source/coverage disposition; zero unexplained empty tables.
- [x] Zero valid in-scope declarations omitted because an importer mapping is missing.
- [x] Zero resolvable references left unresolved because of importer path, namespace or version handling.
- [x] Every remaining source defect has an exact, queryable explanation and is excluded from complete or qualified claims.
- [x] No null semantic IDs, duplicate semantic keys, broken FKs or disabled/untrusted constraints.
- [x] Source-derived expectations agree with the selected SQL model; repeated source copies did not multiply entities.
- [x] Representative Capability/Scenario/face, Contract, Provider and slot queries return correct relationships or explicit source gaps.
- [x] A complete load and restart pass, with unchanged semantic contents and counts on retry.

Repairing the authoritative Harness estate is separate work. Additional authority changes after this
agreed source set belong to a subsequent refresh and do not reopen this migration.
