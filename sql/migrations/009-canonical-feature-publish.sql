-- 009-canonical-feature-publish.sql
-- Make the committed canonical-feature generation publishable:
--   A. add the missing declaration_observation subtype rows for parsed features.
--   B. extend the generated witness views to include model.feature / feature_version.
--   C. close the generation's estate_definition closure for every referenced SOD.
--   D. validate (and, when toggled, publish) the generation.
--
-- Runs in one transaction. Verification mode rolls back; apply by swapping
-- ROLLBACK for COMMIT and uncommenting publish.

SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @to bigint = (SELECT MAX(estate_model_pk) FROM source.estate_model WHERE publication_state='BUILDING');
IF @to IS NULL THROW 51000,'NO_BUILDING_GENERATION',1;

-- A. declaration observations for parsed features.
INSERT source.declaration_observation (source_observation_pk, declared_kind, declared_id, namespace_text, observation_kind)
SELECT o.source_observation_pk, 'FEATURE', f.feature_id, 'sidefx:features', 'DECLARATION'
FROM source.source_observation o
JOIN source.source_lineage l ON l.source_observation_pk=o.source_observation_pk
JOIN model.feature_version fv ON fv.semantic_object_definition_pk=l.semantic_object_definition_pk AND fv.source_profile='parsed-feature-declaration.v1'
JOIN model.feature f ON f.feature_pk=fv.feature_pk
WHERE o.observation_kind='DECLARATION' AND o.locator=N''
  AND NOT EXISTS (SELECT 1 FROM source.declaration_observation d WHERE d.source_observation_pk=o.source_observation_pk);

-- B. witness views include the feature model.
CREATE OR ALTER VIEW source.v_definition_witness AS
SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.capability_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.product_definition
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.contract_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.execution_authority_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.transformation_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.mechanic_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.port_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.provider_definition
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.provider_profile_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.blueprint_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.authority_definition
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.scenario_version
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.scenario_input
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.scenario_event
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.scenario_outcome
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.fixture
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.observable_condition
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.proof_obligation
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.c4_context
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.c4_container
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.c4_component
UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM model.feature_version;

CREATE OR ALTER VIEW source.v_identity_witness AS
SELECT DISTINCT semantic_object_pk,object_kind FROM model.capability
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.product
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.contract
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.execution_authority
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.transformation
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.mechanic
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.port
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.provider
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.provider_profile
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.blueprint
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.authority
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.scenario
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.scenario_input
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.scenario_event
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.scenario_outcome
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.fixture
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.observable_condition
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.proof_obligation
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.c4_context
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.c4_container
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.c4_component
UNION SELECT DISTINCT semantic_object_pk,object_kind FROM model.feature;

-- C. estate_definition closure for the generation.
INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT DISTINCT @to, sv.semantic_object_definition_pk
FROM model.estate_capability ec
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
WHERE ec.estate_model_pk=@to
  AND NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=sv.semantic_object_definition_pk);

INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT DISTINCT @to, f.sod
FROM (
  SELECT i.semantic_object_definition_pk AS sod, i.scenario_version_pk AS sv FROM model.scenario_input i
  UNION ALL SELECT e.semantic_object_definition_pk, e.scenario_version_pk FROM model.scenario_event e
  UNION ALL SELECT o.semantic_object_definition_pk, o.scenario_version_pk FROM model.scenario_outcome o
) f
JOIN model.capability_scenario cs ON cs.scenario_version_pk=f.sv
JOIN model.estate_capability ec ON ec.capability_version_pk=cs.capability_version_pk AND ec.estate_model_pk=@to
WHERE NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=f.sod);

INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT DISTINCT @to, cv.semantic_object_definition_pk
FROM model.contract_version cv
WHERE cv.contract_version_pk IN (
  SELECT i.input_contract_version_pk FROM model.scenario_input i
  JOIN model.capability_scenario cs ON cs.scenario_version_pk=i.scenario_version_pk
  JOIN model.estate_capability ec ON ec.capability_version_pk=cs.capability_version_pk AND ec.estate_model_pk=@to
  WHERE i.input_contract_version_pk IS NOT NULL
  UNION SELECT soc.contract_version_pk FROM model.scenario_outcome_contract soc
  JOIN model.capability_scenario cs ON cs.scenario_version_pk=soc.scenario_version_pk
  JOIN model.estate_capability ec ON ec.capability_version_pk=cs.capability_version_pk AND ec.estate_model_pk=@to)
  AND NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=cv.semantic_object_definition_pk);

INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT DISTINCT @to, eav.semantic_object_definition_pk
FROM model.execution_authority_version eav
WHERE eav.execution_authority_version_pk IN (
  SELECT e.execution_authority_version_pk FROM model.scenario_event e
  JOIN model.capability_scenario cs ON cs.scenario_version_pk=e.scenario_version_pk
  JOIN model.estate_capability ec ON ec.capability_version_pk=cs.capability_version_pk AND ec.estate_model_pk=@to
  WHERE e.execution_authority_version_pk IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=eav.semantic_object_definition_pk);

-- D. validate and (optionally) publish.
EXEC source.validate_model @estate_model_pk=@to;
SELECT 'validated' AS section, @to AS generation,
       (SELECT COUNT(*) FROM model.estate_definition WHERE estate_model_pk=@to) AS definitions,
       (SELECT COUNT(*) FROM source.declaration_observation d JOIN source.source_observation o ON o.source_observation_pk=d.source_observation_pk WHERE o.observation_kind='DECLARATION') AS declaration_subtypes;

ROLLBACK TRANSACTION;
-- COMMIT TRANSACTION;
-- EXEC source.publish_model @estate_model_pk=@to;
