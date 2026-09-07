# Data dictionary

All domain tables live in `sidefx_data`. Every row includes `snapshot_id` and `projection_id`, plus the common provenance columns below. Current views live in `sidefx`; see README.md for their authority filters.

## Common columns

| Column | Storage |
|---|---|
| `row_id` | SHA-256 digest (varchar 71) |
| `artifact_id` | SHA-256 digest (varchar 71) |
| `capability_id` | Unicode identifier or text |
| `is_primary` | Nullable boolean |
| `origin_layer` | Unicode identifier or text |
| `source_pointer` | Unicode text / JSON (max) |
| `pointer_kind` | Unicode identifier or text |
| `derivation_rule` | Unicode identifier or text |
| `object_digest` | SHA-256 digest (varchar 71) |
| `payload_json` | Unicode text / JSON (max) |

## capability

| Domain column | Storage |
|---|---|
| `name` | Unicode identifier or text |
| `version` | Unicode identifier or text |
| `root_scenario_id` | Unicode identifier or text |
| `experience_id` | Unicode identifier or text |
| `lifecycle` | Unicode identifier or text |

## feature

| Domain column | Storage |
|---|---|
| `name` | Unicode text / JSON (max) |
| `language` | Unicode identifier or text |
| `description` | Unicode text / JSON (max) |
| `scenario_count` | Integer |

## scenario

| Domain column | Storage |
|---|---|
| `scenario_id` | Unicode identifier or text |
| `name` | Unicode text / JSON (max) |
| `terminal` | Nullable boolean |
| `input_id` | Unicode identifier or text |
| `input_contract_id` | Unicode identifier or text |
| `event_id` | Unicode identifier or text |
| `execution_authority_id` | Unicode identifier or text |
| `outcome_id` | Unicode identifier or text |
| `outcome_contract_id` | Unicode identifier or text |
| `variant_count` | Integer |
| `observable_condition_count` | Integer |

## input

| Domain column | Storage |
|---|---|
| `input_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `contract_id` | Unicode identifier or text |

## event

| Domain column | Storage |
|---|---|
| `event_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `execution_authority_id` | Unicode identifier or text |

## outcome

| Domain column | Storage |
|---|---|
| `outcome_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `contract_id` | Unicode identifier or text |
| `terminal` | Nullable boolean |
| `variant_id` | Unicode identifier or text |
| `observable_condition_count` | Integer |

## product

| Domain column | Storage |
|---|---|
| `product_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `contract_id` | Unicode identifier or text |
| `product_role` | Unicode identifier or text |

## contract

| Domain column | Storage |
|---|---|
| `contract_id` | Unicode identifier or text |
| `schema_ref` | Unicode text / JSON (max) |

## schema

| Domain column | Storage |
|---|---|
| `schema_id` | Unicode text / JSON (max) |
| `dialect` | Unicode text / JSON (max) |
| `title` | Unicode text / JSON (max) |
| `declared_type` | Unicode identifier or text |

## blueprint_node

| Domain column | Storage |
|---|---|
| `node_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `altitude` | Unicode identifier or text |
| `ordinal` | Integer |

## blueprint_edge

| Domain column | Storage |
|---|---|
| `edge_id` | Unicode identifier or text |
| `from_id` | Unicode identifier or text |
| `to_id` | Unicode identifier or text |
| `topology` | Unicode identifier or text |
| `variant_id` | Unicode identifier or text |

## observed_blueprint_route

| Domain column | Storage |
|---|---|
| `edge_id` | Unicode identifier or text |
| `from_id` | Unicode identifier or text |
| `to_id` | Unicode identifier or text |
| `topology` | Unicode identifier or text |
| `variant_id` | Unicode identifier or text |

## observed_semantic_graph_transition

| Domain column | Storage |
|---|---|
| `transition_id` | Unicode identifier or text |
| `from_scenario_id` | Unicode identifier or text |
| `to_scenario_id` | Unicode identifier or text |
| `from_outcome_id` | Unicode identifier or text |
| `to_input_id` | Unicode identifier or text |
| `topology` | Unicode identifier or text |
| `variant_id` | Unicode identifier or text |

## observed_execution_invoke_scenario

| Domain column | Storage |
|---|---|
| `operation_id` | Unicode identifier or text |
| `from_scenario_id` | Unicode identifier or text |
| `to_scenario_id` | Unicode identifier or text |
| `execution_authority_id` | Unicode identifier or text |

## observed_runtime_route

| Domain column | Storage |
|---|---|
| `edge_id` | Unicode identifier or text |
| `from_id` | Unicode identifier or text |
| `to_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `altitude` | Unicode identifier or text |

## execution_authority

| Domain column | Storage |
|---|---|
| `execution_authority_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `operation_count` | Integer |

## operation

| Domain column | Storage |
|---|---|
| `operation_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `execution_authority_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `port_id` | Unicode identifier or text |
| `target_scenario_id` | Unicode identifier or text |
| `mechanic_binding_id` | Unicode identifier or text |
| `structural_digest` | SHA-256 digest (varchar 71) |

## transformation

| Domain column | Storage |
|---|---|
| `transformation_id` | Unicode identifier or text |
| `expression_digest` | SHA-256 digest (varchar 71) |

## mechanic

| Domain column | Storage |
|---|---|
| `mechanic_id` | Unicode identifier or text |
| `binding_id` | Unicode identifier or text |
| `mechanic_type` | Unicode identifier or text |
| `provider_id` | Unicode identifier or text |
| `provider_name` | Unicode text / JSON (max) |
| `implementation_ref` | Unicode text / JSON (max) |
| `configuration_digest` | SHA-256 digest (varchar 71) |

## port

| Domain column | Storage |
|---|---|
| `port_id` | Unicode identifier or text |
| `provider_id` | Unicode identifier or text |
| `transformation_id` | Unicode identifier or text |
| `binding_kind` | Unicode identifier or text |

## provider_slot

| Domain column | Storage |
|---|---|
| `slot_id` | Unicode identifier or text |
| `cell_id` | Unicode identifier or text |
| `port_id` | Unicode identifier or text |
| `mechanic_id` | Unicode identifier or text |
| `declared_provider_id` | Unicode identifier or text |
| `profile_constraints` | Unicode text / JSON (max) |

## provider

| Domain column | Storage |
|---|---|
| `provider_id` | Unicode identifier or text |
| `authority_id` | Unicode identifier or text |
| `lifecycle` | Unicode identifier or text |
| `responsibility` | Unicode text / JSON (max) |

## provider_binding

| Domain column | Storage |
|---|---|
| `binding_id` | Unicode identifier or text |
| `slot_id` | Unicode identifier or text |
| `cell_id` | Unicode identifier or text |
| `port_id` | Unicode identifier or text |
| `mechanic_id` | Unicode identifier or text |
| `provider_id` | Unicode identifier or text |
| `provider_digest` | Unicode text / JSON (max) |
| `implementation_ref` | Unicode text / JSON (max) |
| `binding_digest` | SHA-256 digest (varchar 71) |

## interface

| Domain column | Storage |
|---|---|
| `interface_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `root_scenario_id` | Unicode identifier or text |
| `target_capability_id` | Unicode identifier or text |

## fixture

| Domain column | Storage |
|---|---|
| `fixture_id` | Unicode identifier or text |
| `terminal_scenario_id` | Unicode identifier or text |
| `expected_disposition` | Unicode identifier or text |
| `assertion_count` | Integer |

## fixture_scenario

| Domain column | Storage |
|---|---|
| `fixture_id` | Unicode identifier or text |
| `scenario_id` | Unicode identifier or text |
| `ordinal` | Integer |

## fixture_assertion

| Domain column | Storage |
|---|---|
| `fixture_id` | Unicode identifier or text |
| `condition_id` | Unicode identifier or text |
| `assertion_path` | Unicode text / JSON (max) |
| `operator` | Unicode identifier or text |
| `value_json` | Unicode text / JSON (max) |
| `target_scenario_id` | Unicode identifier or text |

## proof_obligation

| Domain column | Storage |
|---|---|
| `obligation_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `status` | Unicode identifier or text |
| `subject_id` | Unicode identifier or text |

## evidence

| Domain column | Storage |
|---|---|
| `evidence_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `disposition` | Unicode identifier or text |
| `declared_digest` | Unicode text / JSON (max) |
| `subject_id` | Unicode identifier or text |

## projection_authority

| Domain column | Storage |
|---|---|
| `projection_authority_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `input_contract_id` | Unicode identifier or text |
| `output_contract_id` | Unicode identifier or text |

## dependency

| Domain column | Storage |
|---|---|
| `target_capability_id` | Unicode identifier or text |
| `target_version` | Unicode identifier or text |
| `target_digest` | Unicode text / JSON (max) |
| `dependency_kind` | Unicode identifier or text |

## semantic_term

| Domain column | Storage |
|---|---|
| `term_id` | Unicode identifier or text |
| `label` | Unicode text / JSON (max) |
| `normalized_label` | Unicode text / JSON (max) |
| `definition` | Unicode text / JSON (max) |
| `vocabulary_kind` | Unicode identifier or text |

## term_relationship

| Domain column | Storage |
|---|---|
| `relationship_id` | Unicode identifier or text |
| `from_term_id` | Unicode identifier or text |
| `to_term_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |

## classification

| Domain column | Storage |
|---|---|
| `subject_id` | Unicode identifier or text |
| `classification` | Unicode identifier or text |
| `classified_kind` | Unicode identifier or text |

## fact

| Domain column | Storage |
|---|---|
| `fact_id` | Unicode identifier or text |
| `subject_id` | Unicode identifier or text |
| `predicate` | Unicode identifier or text |
| `object_id` | Unicode identifier or text |
| `value_json` | Unicode text / JSON (max) |

## fact_relationship

| Domain column | Storage |
|---|---|
| `relationship_id` | Unicode identifier or text |
| `from_fact_id` | Unicode identifier or text |
| `to_fact_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |

## precedent

| Domain column | Storage |
|---|---|
| `precedent_id` | Unicode identifier or text |
| `subject_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |

## pattern_candidate

| Domain column | Storage |
|---|---|
| `pattern_id` | Unicode identifier or text |
| `kind` | Unicode identifier or text |
| `status` | Unicode identifier or text |

## extraction_issue

| Domain column | Storage |
|---|---|
| `code` | Unicode identifier or text |
| `detail` | Unicode text / JSON (max) |
| `severity` | Unicode identifier or text |
