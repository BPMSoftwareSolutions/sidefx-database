-- Selection is data bound as @input by the restricted query reader.
-- Required: capabilityId, scenarioId. Optional: namespaceId, target.
IF @input IS NULL OR ISJSON(@input)<>1 THROW 51000,'JSON_INPUT_REQUIRED',1;
DECLARE @capability_id nvarchar(4000)=JSON_VALUE(@input,'$.capabilityId'),
        @scenario_id nvarchar(4000)=JSON_VALUE(@input,'$.scenarioId'),
        @namespace_id nvarchar(4000)=JSON_VALUE(@input,'$.namespaceId'),
        @target nvarchar(4000)=JSON_VALUE(@input,'$.target');
IF NULLIF(@capability_id,'') IS NULL OR NULLIF(@scenario_id,'') IS NULL
    THROW 51000,'CAPABILITY_AND_SCENARIO_REQUIRED',1;
DECLARE @matches bigint,@capability_version_pk bigint,@scenario_version_pk bigint;
SELECT @matches=COUNT_BIG(*),@capability_version_pk=MAX(ec.capability_version_pk)
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk
WHERE ec.estate_model_pk=@estate_model_pk AND c.capability_id=@capability_id
  AND (@namespace_id IS NULL OR n.namespace_id=@namespace_id);
IF @matches=0 THROW 51000,'CAPABILITY_NOT_FOUND',1;
IF @matches<>1 THROW 51000,'CAPABILITY_NAMESPACE_AMBIGUOUS',1;
SELECT @matches=COUNT_BIG(*),@scenario_version_pk=MAX(cs.scenario_version_pk)
FROM model.capability_scenario cs JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
WHERE cs.capability_version_pk=@capability_version_pk AND s.scenario_id=@scenario_id;
IF @matches=0 THROW 51000,'SCENARIO_NOT_IN_CAPABILITY',1;
IF @matches<>1 THROW 51000,'SCENARIO_NAMESPACE_AMBIGUOUS',1;
IF @target IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM analysis.v_declared_platform_implementation
    WHERE estate_model_pk=@estate_model_pk AND target_language=@target
) THROW 51000,'TARGET_NOT_DECLARED',1;

-- ROWCOUNT must not truncate intermediate requirements before aggregation.
-- The reader still limits retained results and reports truncated evidence.
SET ROWCOUNT 0;
SELECT * INTO #resolver_map
FROM analysis.v_scenario_language_resolution
WHERE estate_model_pk=@estate_model_pk AND capability_version_pk=@capability_version_pk
  AND selected_scenario_version_pk=@scenario_version_pk
  AND (@target IS NULL OR target_language=@target)
OPTION(RECOMPILE,MAXRECURSION 32767);

SELECT capability_id,scenario_id,downstream_scenario_id,altitude,requirement_kind,
       requirement_id,requirement_use,target_language,provenance_class,
       source_definition_pk,source_pointer,requirement_definition_pk,requirement_definition_digest,
       resolver_id,provider_id,provider_definition_pk,provider_profile_id,profile_definition_pk,
       implementation_id,implementation_export,resolution_candidate_count,
       mechanic_source_digest,registry_source_digest,declared_authority_digest,
       resolution_status,diagnostic,repair_boundary,implementation_evidence_state,conformance_status
FROM #resolver_map
ORDER BY target_language,minimum_depth,downstream_scenario_id,requirement_use,implementation_id;

WITH obligations AS (
    SELECT target_language,downstream_scenario_version_pk,requirement_use,
           MAX(CASE WHEN resolution_status<>'RESOLVED' THEN 1 ELSE 0 END) AS is_open
    FROM #resolver_map GROUP BY target_language,downstream_scenario_version_pk,requirement_use
)
SELECT @capability_id AS capability_id,@scenario_id AS scenario_id,target_language,
       COUNT_BIG(*) AS requirement_count,SUM(CONVERT(bigint,is_open)) AS open_requirement_count,
       CASE WHEN SUM(is_open)=0 THEN 'CAN_ATTEMPT_EMBODIMENT' ELSE 'NOT_OBSERVABLE' END AS readiness,
       'NOT_EVALUATED' AS conformance_status
FROM obligations GROUP BY target_language ORDER BY target_language;

SELECT DISTINCT s.scenario_id AS downstream_scenario_id,cl.minimum_depth,cl.cycle_detected,
       i.input_id,e.event_id,e.responsibility,o.outcome_id,sv.definition_digest AS scenario_definition_digest
FROM analysis.v_scenario_invocation_closure cl
JOIN model.scenario_version sv ON sv.scenario_version_pk=cl.downstream_scenario_version_pk
JOIN model.scenario s ON s.scenario_pk=sv.scenario_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk=sv.scenario_version_pk
WHERE cl.capability_version_pk=@capability_version_pk AND cl.selected_scenario_version_pk=@scenario_version_pk
ORDER BY cl.minimum_depth,s.scenario_id
OPTION(MAXRECURSION 32767);
