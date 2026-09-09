-- Shared selection for preparation publication and invocation. All identities
-- come from the selected model; spelling never establishes the root Scenario.
DECLARE @capability_id nvarchar(4000)=JSON_VALUE(@input,'$.capabilityId'),
        @scenario_id nvarchar(4000)=JSON_VALUE(@input,'$.scenarioId'),
        @namespace_id nvarchar(4000)=JSON_VALUE(@input,'$.namespaceId'),
        @target nvarchar(4000)=JSON_VALUE(@input,'$.target');
IF NULLIF(@capability_id,'') IS NULL THROW 51000,'CAPABILITY_REQUIRED',1;
IF NULLIF(@target,'') IS NULL OR LEN(@target)>100 THROW 51000,'PREPARATION_TARGET_REQUIRED',1;
DECLARE @matches bigint,@capability_pk bigint,@capability_version_pk bigint,@scenario_version_pk bigint;
SELECT @matches=COUNT_BIG(*),@capability_pk=MAX(c.capability_pk),@capability_version_pk=MAX(ec.capability_version_pk)
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk
WHERE ec.estate_model_pk=@estate_model_pk AND c.capability_id=@capability_id
  AND (@namespace_id IS NULL OR n.namespace_id=@namespace_id);
IF @matches=0 THROW 51000,'CAPABILITY_NOT_FOUND',1;
IF @matches<>1 THROW 51000,'CAPABILITY_NAMESPACE_AMBIGUOUS',1;
IF @scenario_id IS NULL
BEGIN
    SELECT @matches=COUNT_BIG(*),@scenario_id=MAX(s.scenario_id)
    FROM model.capability_root_scenario r JOIN model.scenario s ON s.scenario_pk=r.scenario_pk
    WHERE r.capability_version_pk=@capability_version_pk;
    IF @matches<>1 THROW 51000,'CAPABILITY_ROOT_SCENARIO_UNRESOLVED',1;
END;
SELECT @matches=COUNT_BIG(*),@scenario_version_pk=MAX(cs.scenario_version_pk)
FROM model.capability_scenario cs JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
WHERE cs.capability_version_pk=@capability_version_pk AND s.scenario_id=@scenario_id;
IF @matches=0 THROW 51000,'SCENARIO_NOT_IN_CAPABILITY',1;
IF @matches<>1 THROW 51000,'SCENARIO_NAMESPACE_AMBIGUOUS',1;
