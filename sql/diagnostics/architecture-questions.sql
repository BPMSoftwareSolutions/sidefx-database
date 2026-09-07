-- Entity natural keys are unique within their explicit namespace.
SELECT n.namespace_id,p.provider_id,p.definition_count
FROM sidefx.v_provider p JOIN model.identity_namespace n ON n.namespace_pk=p.namespace_pk
ORDER BY n.namespace_id,p.provider_id;

-- Reused bytes do not merge Contract identities.
SELECT cv.schema_object_pk,COUNT(DISTINCT cv.contract_pk) contract_identity_count
FROM sidefx.v_contract_version cv GROUP BY cv.schema_object_pk
HAVING COUNT(DISTINCT cv.contract_pk)>1;

-- Scope and resolution remain explicit.
SELECT ur.reference_role,ur.resolution_state,a.source_path,o.locator,r.target_reference
FROM source.current_model cm
JOIN analysis.unresolved_reference ur ON ur.estate_model_pk=cm.estate_model_pk
JOIN source.relationship_observation r ON r.source_observation_pk=ur.source_observation_pk
JOIN source.source_observation o ON o.source_observation_pk=r.source_observation_pk
JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk;
