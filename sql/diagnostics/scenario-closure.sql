-- Selection is data bound as @input by the restricted query reader.
-- Required: capabilityId, scenarioId. Optional: namespaceId.
--
-- The declared downstream closure for one selected Scenario: which Scenarios it
-- reaches, at what depth, and their Input/Event/Outcome faces.
--
-- This is the third result set of scenario-resolver-map.sql, lifted verbatim.
-- It reads analysis.v_scenario_invocation_closure and the Scenario tables only;
-- it does not touch the language-resolution chain. Measured at 1 ms against a
-- four-Scenario capability, where the same rows obtained through the resolver
-- map cost 30 s -- the resolver map's own requirement view CROSS APPLYs a
-- multi-statement function across every capability/scenario pair in the estate
-- before filtering to the selected one.
--
-- Embodiment planning needs this closure, the retained authority bytes, and the
-- pinned mechanic registry. It does not need the requirement matrix.
IF @input IS NULL OR ISJSON(@input)<>1 THROW 51000,'JSON_INPUT_REQUIRED',1;
DECLARE @capability_id nvarchar(4000)=JSON_VALUE(@input,'$.capabilityId'),
        @scenario_id nvarchar(4000)=JSON_VALUE(@input,'$.scenarioId'),
        @namespace_id nvarchar(4000)=JSON_VALUE(@input,'$.namespaceId');
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
