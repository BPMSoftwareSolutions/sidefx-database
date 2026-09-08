-- Read through: node src/cli.mjs query --file sql/diagnostics/website-visual-inventory.sql --limit 5000
-- @estate_model_pk is pinned by the existing restricted reader.
-- No mutation. Definitions and identities are counted separately.

SELECT @estate_model_pk AS estate_model_pk, @snapshot_id AS snapshot_id,
       @projection_id AS mapping_manifest_digest;

SELECT d.object_kind, COUNT_BIG(*) AS selected_definitions,
       COUNT_BIG(DISTINCT d.semantic_object_pk) AS selected_identities
FROM model.estate_definition ed
JOIN model.semantic_object_definition d
  ON d.semantic_object_definition_pk = ed.semantic_object_definition_pk
WHERE ed.estate_model_pk = @estate_model_pk
GROUP BY d.object_kind ORDER BY d.object_kind;

-- Managed capabilities have their own selected-membership contract.
SELECT COUNT_BIG(*) AS selected_managed_capabilities
FROM model.estate_capability WHERE estate_model_pk = @estate_model_pk;

-- One row per selected Mechanic definition. Provider relationships are grouped
-- before aggregation so several providers cannot inflate the Mechanic count.
WITH implementations AS (
  SELECT i.mechanic_version_pk,
         COUNT_BIG(*) AS implementation_relationships,
         COUNT_BIG(DISTINCT pd.provider_pk) AS provider_identities
  FROM model.provider_mechanic_implementation i
  JOIN model.provider_definition pd ON pd.provider_definition_pk = i.provider_definition_pk
  WHERE EXISTS (SELECT 1 FROM model.estate_definition ed
                WHERE ed.estate_model_pk = @estate_model_pk
                  AND ed.semantic_object_definition_pk = pd.semantic_object_definition_pk)
  GROUP BY i.mechanic_version_pk
)
SELECT m.mechanic_id, ns.namespace_id, m.semantic_object_pk,
       mv.semantic_object_definition_pk, mv.mechanic_version_pk,
       mv.definition_profile, mv.mechanic_kind, mv.name,
       COALESCE(i.implementation_relationships, 0) AS implementation_relationships,
       COALESCE(i.provider_identities, 0) AS provider_identities
FROM model.mechanic m
JOIN model.identity_namespace ns ON ns.namespace_pk = m.namespace_pk
JOIN model.mechanic_version mv ON mv.mechanic_pk = m.mechanic_pk
LEFT JOIN implementations i ON i.mechanic_version_pk = mv.mechanic_version_pk
WHERE EXISTS (SELECT 1 FROM model.estate_definition ed
              WHERE ed.estate_model_pk = @estate_model_pk
                AND ed.semantic_object_definition_pk = mv.semantic_object_definition_pk)
ORDER BY mv.definition_profile, m.mechanic_id, mv.mechanic_version_pk;

-- Exact declared implementation rows; this is not qualification/readiness.
SELECT p.provider_id, m.mechanic_id,
       i.provider_mechanic_implementation_pk, pd.provider_definition_pk,
       mv.mechanic_version_pk, i.provider_profile_version_pk, i.role
FROM model.provider_mechanic_implementation i
JOIN model.provider_definition pd ON pd.provider_definition_pk = i.provider_definition_pk
JOIN model.provider p ON p.provider_pk = pd.provider_pk
JOIN model.mechanic_version mv ON mv.mechanic_version_pk = i.mechanic_version_pk
JOIN model.mechanic m ON m.mechanic_pk = mv.mechanic_pk
WHERE EXISTS (SELECT 1 FROM model.estate_definition ed
              WHERE ed.estate_model_pk = @estate_model_pk
                AND ed.semantic_object_definition_pk = pd.semantic_object_definition_pk)
  AND EXISTS (SELECT 1 FROM model.estate_definition ed
              WHERE ed.estate_model_pk = @estate_model_pk
                AND ed.semantic_object_definition_pk = mv.semantic_object_definition_pk)
ORDER BY p.provider_id, m.mechanic_id, i.provider_mechanic_implementation_pk;

SELECT p.provider_id, ns.namespace_id, p.semantic_object_pk,
       pd.semantic_object_definition_pk, pd.provider_definition_pk,
       pd.name, pd.declaration_profile,
       (SELECT COUNT_BIG(*) FROM model.provider_mechanic_implementation i
        JOIN model.mechanic_version mv ON mv.mechanic_version_pk = i.mechanic_version_pk
        WHERE i.provider_definition_pk = pd.provider_definition_pk
          AND EXISTS (SELECT 1 FROM model.estate_definition ed
                      WHERE ed.estate_model_pk = @estate_model_pk
                        AND ed.semantic_object_definition_pk = mv.semantic_object_definition_pk)) AS mechanic_relationships,
       (SELECT COUNT_BIG(*) FROM model.provider_capability_implementation i
        JOIN model.capability_version cv ON cv.capability_version_pk = i.capability_version_pk
        WHERE i.provider_definition_pk = pd.provider_definition_pk
          AND EXISTS (SELECT 1 FROM model.estate_definition ed
                      WHERE ed.estate_model_pk = @estate_model_pk
                        AND ed.semantic_object_definition_pk = cv.semantic_object_definition_pk)) AS capability_relationships
FROM model.provider p
JOIN model.identity_namespace ns ON ns.namespace_pk = p.namespace_pk
JOIN model.provider_definition pd ON pd.provider_pk = p.provider_pk
WHERE EXISTS (SELECT 1 FROM model.estate_definition ed
              WHERE ed.estate_model_pk = @estate_model_pk
                AND ed.semantic_object_definition_pk = pd.semantic_object_definition_pk)
ORDER BY p.provider_id, pd.provider_definition_pk;

-- Selected capability/scenario association plus optional faces. Raw joins through
-- all scenario_version rows mix revisions; inner face joins conceal missing data.
SELECT c.capability_id, s.scenario_id, s.semantic_object_pk,
       cs.scenario_version_pk, sv.semantic_object_definition_pk,
       i.input_id, e.event_id, e.responsibility, o.outcome_id,
       i.contract_reference_state AS input_contract_state,
       e.authority_reference_state AS event_authority_state
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk = cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk = cs.scenario_version_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk = cs.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk = cs.scenario_version_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk = cs.scenario_version_pk
WHERE ec.estate_model_pk = @estate_model_pk
ORDER BY c.capability_id, s.scenario_id;

SELECT b.blueprint_id, b.semantic_object_pk, bv.semantic_object_definition_pk,
       bv.blueprint_version_pk, c.capability_id, bv.carrier_profile,
       bv.source_disposition,
       (SELECT COUNT_BIG(*) FROM model.blueprint_node n
        WHERE n.blueprint_version_pk = bv.blueprint_version_pk) AS node_count,
       (SELECT COUNT_BIG(*) FROM model.blueprint_edge e
        WHERE e.blueprint_version_pk = bv.blueprint_version_pk) AS edge_count
FROM model.blueprint b
JOIN model.blueprint_version bv ON bv.blueprint_pk = b.blueprint_pk
JOIN model.capability c ON c.capability_pk = bv.capability_pk
WHERE EXISTS (SELECT 1 FROM model.estate_definition ed
              WHERE ed.estate_model_pk = @estate_model_pk
                AND ed.semantic_object_definition_pk = bv.semantic_object_definition_pk)
ORDER BY b.blueprint_id, bv.blueprint_version_pk;

-- Existing byte-store contract. No full content bytes are returned here.
SELECT COUNT_BIG(*) AS captured_content_objects,
       SUM(byte_length) AS captured_content_bytes
FROM source.content_object;
