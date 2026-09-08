-- @input is JSON bound by the existing restricted query reader.
-- Required: capabilityId. Optional: scenarioId, namespaceId.
-- Omitting scenarioId selects the declared normalized root, never an ID heuristic.
-- Return the selected Scenario and the complete retained Capability authority.
-- SDA owns downstream traversal, contract admission and mechanic resolution.
DECLARE @capability_id nvarchar(4000) = JSON_VALUE(@input, '$.capabilityId');
DECLARE @scenario_id nvarchar(4000) = JSON_VALUE(@input, '$.scenarioId');
DECLARE @namespace_id nvarchar(4000) = JSON_VALUE(@input, '$.namespaceId');
IF NULLIF(@capability_id, '') IS NULL
    THROW 51000, 'CAPABILITY_REQUIRED', 1;

DECLARE @matches bigint, @capability_pk bigint, @capability_version_pk bigint,
        @capability_definition_pk bigint, @scenario_version_pk bigint,
        @snapshot_pk bigint, @capsule_digest binary(32);
SELECT @snapshot_pk = estate_snapshot_pk
FROM source.estate_model WHERE estate_model_pk = @estate_model_pk;

SELECT @matches = COUNT_BIG(*), @capability_pk = MAX(c.capability_pk),
       @capability_version_pk = MAX(ec.capability_version_pk),
       @capability_definition_pk = MAX(ec.semantic_object_definition_pk)
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk
WHERE ec.estate_model_pk = @estate_model_pk AND c.capability_id = @capability_id
  AND (@namespace_id IS NULL OR n.namespace_id = @namespace_id);
IF @matches = 0 THROW 51000, 'CAPABILITY_NOT_FOUND', 1;
IF @matches <> 1 THROW 51000, 'CAPABILITY_NAMESPACE_AMBIGUOUS', 1;

IF @scenario_id IS NULL
BEGIN
    SELECT @matches = COUNT_BIG(*), @scenario_id = MAX(s.scenario_id)
    FROM model.capability_root_scenario r
    JOIN model.scenario s ON s.scenario_pk = r.scenario_pk
    WHERE r.capability_version_pk = @capability_version_pk;
    IF @matches <> 1 THROW 51000, 'CAPABILITY_ROOT_SCENARIO_UNRESOLVED', 1;
END;

SELECT @matches=COUNT_BIG(*),@scenario_version_pk = MAX(cs.scenario_version_pk)
FROM model.capability_scenario cs
JOIN model.scenario s ON s.scenario_pk = cs.scenario_pk
WHERE cs.capability_version_pk = @capability_version_pk AND s.scenario_id = @scenario_id;
IF @matches=0 THROW 51000, 'SCENARIO_NOT_IN_CAPABILITY', 1;
IF @matches<>1 THROW 51000, 'SCENARIO_NAMESPACE_AMBIGUOUS', 1;

SELECT @matches = COUNT_BIG(*) FROM (
    SELECT DISTINCT a.capsule_digest
    FROM source.source_lineage l
    JOIN source.source_observation o ON o.source_observation_pk = l.source_observation_pk
    JOIN source.source_appearance a ON a.source_appearance_pk = o.source_appearance_pk
    WHERE l.semantic_object_definition_pk = @capability_definition_pk
      AND a.estate_snapshot_pk = @snapshot_pk AND a.source_class = 'MANAGED_CAPSULE'
      AND a.capsule_digest IS NOT NULL
) candidates;
IF @matches <> 1 THROW 51000, 'CAPABILITY_SOURCE_AUTHORITY_UNRESOLVED', 1;
SELECT DISTINCT @capsule_digest = a.capsule_digest
FROM source.source_lineage l
JOIN source.source_observation o ON o.source_observation_pk = l.source_observation_pk
JOIN source.source_appearance a ON a.source_appearance_pk = o.source_appearance_pk
WHERE l.semantic_object_definition_pk = @capability_definition_pk
  AND a.estate_snapshot_pk = @snapshot_pk AND a.source_class = 'MANAGED_CAPSULE'
  AND a.capsule_digest IS NOT NULL;

SELECT c.capability_id, n.namespace_id, s.scenario_id,
       i.input_id, i.contract_reference_state AS input_contract_state,
       e.event_id, e.responsibility, e.authority_reference_state AS event_authority_state,
       o.outcome_id, oc.contract_version_pk AS outcome_contract_version_pk,
       'sha256:' + LOWER(CONVERT(varchar(64), cv.definition_digest, 2)) AS capability_definition_digest,
       'sha256:' + LOWER(CONVERT(varchar(64), sv.definition_digest, 2)) AS scenario_definition_digest,
       'sha256:' + LOWER(CONVERT(varchar(64), @capsule_digest, 2)) AS capsule_digest
FROM model.capability c
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk
JOIN model.capability_version cv ON cv.capability_version_pk = @capability_version_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk = @scenario_version_pk
JOIN model.scenario s ON s.scenario_pk = sv.scenario_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk = sv.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk = sv.scenario_version_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk = sv.scenario_version_pk
LEFT JOIN model.scenario_outcome_contract oc ON oc.scenario_version_pk = sv.scenario_version_pk
WHERE c.capability_pk = @capability_pk;

-- Exact source bytes, including retained source profiles not yet normalized.
-- Paths and entry identities come from stored lineage, never naming conventions.
SELECT DISTINCT a.source_path, a.entry_id, a.container_locator, c.byte_length,
       'sha256:' + LOWER(CONVERT(varchar(64), c.content_digest, 2)) AS content_digest,
       c.content_bytes
FROM source.source_appearance a
JOIN source.content_object c ON c.content_object_pk = a.content_object_pk
WHERE a.estate_snapshot_pk = @snapshot_pk AND a.capsule_digest = @capsule_digest
  AND a.source_class = 'MANAGED_CAPSULE'
ORDER BY a.source_path, a.entry_id;

-- Resolve the stored platform catalog and mechanic registries by their declared
-- profiles. The reader supplies all retained platform declarations as bytes;
-- it does not equate mechanic names or implement language selection.
SELECT a.source_path, a.entry_id, a.container_locator, c.byte_length,
       'sha256:' + LOWER(CONVERT(varchar(64), c.content_digest, 2)) AS content_digest,
       c.content_bytes
FROM source.source_appearance a
JOIN source.content_object c ON c.content_object_pk = a.content_object_pk
WHERE a.estate_snapshot_pk = @snapshot_pk AND a.source_class = 'PINNED_PLATFORM_AUTHORITY'
ORDER BY a.source_path;
