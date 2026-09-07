-- Views report observed evidence and candidates, never admission decisions.
CREATE OR ALTER VIEW sidefx.v_scenario_closure AS
SELECT s.*,
  (SELECT COUNT(*) FROM sidefx_observed.execution_authority e WHERE e.capability_id=s.capability_id AND e.is_primary=1 AND e.origin_layer='AUTHORITY' AND e.execution_authority_id=s.execution_authority_id) AS execution_authority_count,
  (SELECT COUNT(*) FROM sidefx_observed.observed_semantic_graph_transition t WHERE t.capability_id=s.capability_id AND t.is_primary=1 AND t.origin_layer='AUTHORITY' AND t.from_scenario_id=s.scenario_id) AS declared_transition_count,
  (SELECT COUNT(*) FROM sidefx_observed.observed_execution_invoke_scenario t WHERE t.capability_id=s.capability_id AND t.is_primary=1 AND t.origin_layer='AUTHORITY' AND t.from_scenario_id=s.scenario_id) AS invoked_scenario_count,
  CASE WHEN s.terminal=1 THEN 'DECLARED_TERMINAL' WHEN s.terminal=0 THEN 'NONTERMINAL_REVIEW_TOPOLOGY' ELSE 'TERMINALITY_UNKNOWN' END AS closure_observation
FROM sidefx_observed.scenario s WHERE s.is_primary=1 AND s.origin_layer='AUTHORITY' AND s.pointer_kind='LINE';
GO
CREATE OR ALTER VIEW sidefx.v_contract_usage AS
WITH declarations AS (SELECT * FROM sidefx_observed.contract WHERE is_primary=1 AND origin_layer='AUTHORITY')
SELECT c.*,
 (SELECT COUNT(*) FROM sidefx_observed.input i WHERE i.contract_id=c.contract_id AND i.capability_id<>c.capability_id AND i.origin_layer='AUTHORITY' AND i.is_primary=1) AS external_consumer_count
FROM declarations c;
GO
CREATE OR ALTER VIEW sidefx.v_transition_integrity AS
SELECT t.*,CASE
 WHEN t.from_scenario_id IS NULL OR t.to_scenario_id IS NULL THEN 'ENDPOINT_NOT_EXTRACTED'
 WHEN NOT EXISTS(SELECT 1 FROM sidefx_observed.scenario s WHERE s.capability_id=t.capability_id AND s.scenario_id=t.from_scenario_id AND s.is_primary=1 AND s.origin_layer='AUTHORITY' AND s.pointer_kind='LINE') THEN 'SOURCE_SCENARIO_NOT_OBSERVED'
 WHEN NOT EXISTS(SELECT 1 FROM sidefx_observed.scenario s WHERE s.capability_id=t.capability_id AND s.scenario_id=t.to_scenario_id AND s.is_primary=1 AND s.origin_layer='AUTHORITY' AND s.pointer_kind='LINE') THEN 'TARGET_SCENARIO_NOT_OBSERVED'
 ELSE 'ENDPOINTS_OBSERVED' END AS observation
FROM sidefx_observed.observed_semantic_graph_transition t WHERE t.is_primary=1 AND t.origin_layer='AUTHORITY';
GO
CREATE OR ALTER VIEW sidefx.v_mechanic_reuse AS
SELECT mechanic_id,mechanic_type,COUNT(*) AS binding_count,COUNT(DISTINCT capability_id) AS capability_count,
 COUNT(DISTINCT provider_id) AS provider_count,COUNT(DISTINCT configuration_digest) AS configuration_count
FROM sidefx_observed.mechanic WHERE is_primary=1 AND origin_layer='RUNTIME' GROUP BY mechanic_id,mechanic_type;
GO
CREATE OR ALTER VIEW sidefx.v_slot_resolution AS
SELECT s.*,
 CASE WHEN s.binding_count=0 THEN 'NO_BINDING_OBSERVED' WHEN s.provider_count>1 THEN 'MULTIPLE_PROVIDERS_OBSERVED' WHEN s.provider_count=0 THEN 'PROVIDER_ID_NOT_EXTRACTED' ELSE 'ONE_PROVIDER_OBSERVED' END AS resolution_observation
FROM sidefx_observed.provider_slot s
WHERE s.is_primary=1 AND s.origin_layer IN('AUTHORITY','RUNTIME');
GO
CREATE OR ALTER VIEW sidefx.v_provider_coverage AS
SELECT capability_id,origin_layer,COUNT(*) AS slot_count,SUM(CASE WHEN provider_count=1 THEN 1 ELSE 0 END) AS resolved_slot_count,
 SUM(CASE WHEN binding_count=0 THEN 1 ELSE 0 END) AS unbound_slot_count,SUM(CASE WHEN provider_count>1 THEN 1 ELSE 0 END) AS ambiguous_slot_count
FROM sidefx.v_slot_resolution GROUP BY capability_id,origin_layer;
GO
CREATE OR ALTER VIEW sidefx.v_port_binding_integrity AS
SELECT o.*,b.binding_count,b.provider_count,
 CASE WHEN o.port_id IS NULL THEN 'PORT_ID_NOT_EXTRACTED' WHEN b.binding_count=0 THEN 'PORT_BINDING_NOT_OBSERVED' WHEN b.provider_count>1 THEN 'MULTIPLE_PROVIDERS_OBSERVED' ELSE 'BINDING_OBSERVED' END AS observation
FROM sidefx_observed.operation o
OUTER APPLY(SELECT COUNT(*) AS binding_count,COUNT(DISTINCT p.provider_id) AS provider_count FROM sidefx_observed.port p
 WHERE p.capability_id=o.capability_id AND p.port_id=o.port_id AND p.is_primary=1 AND p.origin_layer='AUTHORITY') b
WHERE o.is_primary=1 AND o.origin_layer='AUTHORITY' AND o.kind='invoke-port';
GO
CREATE OR ALTER VIEW sidefx.v_fixture_coverage AS
SELECT s.capability_id,s.scenario_id,s.row_id AS scenario_row_id,
 (SELECT COUNT(DISTINCT f.fixture_id) FROM sidefx_observed.fixture_scenario f WHERE f.capability_id=s.capability_id AND f.scenario_id=s.scenario_id AND f.is_primary=1 AND f.origin_layer='AUTHORITY') AS declared_fixture_sequence_count,
 (SELECT COUNT(DISTINCT f.variant_id) FROM sidefx_observed.outcome f WHERE f.capability_id=s.capability_id AND f.scenario_id=s.scenario_id AND f.variant_id IS NOT NULL AND f.is_primary=1 AND f.origin_layer='AUTHORITY') AS declared_variant_count,
 (SELECT COUNT(DISTINCT o.variant_id) FROM sidefx_observed.outcome o WHERE o.capability_id=s.capability_id AND o.scenario_id=s.scenario_id AND o.is_primary=1 AND o.origin_layer='AUTHORITY' AND o.variant_id IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM sidefx_observed.fixture_assertion f WHERE f.capability_id=o.capability_id AND f.target_scenario_id=o.scenario_id AND f.is_primary=1 AND f.origin_layer='AUTHORITY' AND f.operator='equals' AND f.assertion_path IN('disposition','variant','variantId') AND f.value_json COLLATE Latin1_General_100_BIN2='"'+STRING_ESCAPE(o.variant_id,'json')+'"')) AS variants_without_matching_terminal_assertion,
 'DECLARED_EXPECTATIONS_ONLY_NOT_EXECUTED_COVERAGE' AS coverage_basis
FROM sidefx.v_scenario_closure s;
GO
CREATE OR ALTER VIEW sidefx.v_proof_coverage AS
SELECT c.capability_id,
 (SELECT COUNT(*) FROM sidefx_observed.proof_obligation p WHERE p.capability_id=c.capability_id AND p.is_primary=1 AND p.origin_layer='AUTHORITY') AS declared_obligation_count,
 (SELECT COUNT(*) FROM sidefx_observed.evidence e WHERE e.capability_id=c.capability_id AND e.is_primary=1 AND e.origin_layer='AUTHORITY') AS observed_evidence_count,
 'PROOF_VALIDITY_NOT_ADJUDICATED' AS coverage_basis
FROM sidefx_observed.capability c WHERE c.is_primary=1 AND c.origin_layer='AUTHORITY';
GO
CREATE OR ALTER VIEW sidefx.v_blueprint_execution_parity AS
WITH routes AS (
 SELECT capability_id,from_id,to_id,'BLUEPRINT' AS representation FROM sidefx_observed.observed_blueprint_route WHERE is_primary=1 AND origin_layer='AUTHORITY'
 UNION ALL SELECT capability_id,from_scenario_id,to_scenario_id,'SEMANTIC_GRAPH' FROM sidefx_observed.observed_semantic_graph_transition WHERE is_primary=1 AND origin_layer='AUTHORITY'
 UNION ALL SELECT capability_id,from_scenario_id,to_scenario_id,'EXECUTION_INVOKE' FROM sidefx_observed.observed_execution_invoke_scenario WHERE is_primary=1 AND origin_layer='AUTHORITY')
SELECT capability_id,from_id,to_id,
 SUM(CASE WHEN representation='BLUEPRINT' THEN 1 ELSE 0 END) AS blueprint_observations,
 SUM(CASE WHEN representation='SEMANTIC_GRAPH' THEN 1 ELSE 0 END) AS semantic_observations,
 SUM(CASE WHEN representation='EXECUTION_INVOKE' THEN 1 ELSE 0 END) AS execution_observations,
 'RAW_ENDPOINT_COMPARISON_PROJECTION_LAW_UNRESOLVED' AS comparison_basis
FROM routes GROUP BY capability_id,from_id,to_id;
GO
CREATE OR ALTER VIEW sidefx.v_semantic_vocabulary_drift AS
SELECT normalized_label,vocabulary_kind,COUNT(DISTINCT term_id) AS identity_count,COUNT(DISTINCT capability_id) AS capability_count,
 'LEXICAL_NORMALIZATION_CANDIDATE' AS observation
FROM sidefx_observed.semantic_term WHERE is_primary=1 AND origin_layer='AUTHORITY' AND normalized_label<>'' GROUP BY normalized_label,vocabulary_kind;
GO
CREATE OR ALTER VIEW sidefx.v_duplicate_capability_candidates AS
SELECT expression_digest,COUNT(DISTINCT transformation_id) AS transformation_identity_count,COUNT(DISTINCT capability_id) AS capability_count,
 'IDENTICAL_EXPRESSION_BYTES_CANDIDATE' AS observation
FROM sidefx_observed.transformation WHERE is_primary=1 AND origin_layer='AUTHORITY' GROUP BY expression_digest HAVING COUNT(DISTINCT capability_id)>1;
GO
CREATE OR ALTER VIEW sidefx.v_orphan_products AS
SELECT p.*,'NO_MATCHING_DECLARED_INPUT_CONTRACT_IN_SNAPSHOT' AS observation FROM sidefx_observed.product p
WHERE p.is_primary=1 AND p.origin_layer='AUTHORITY' AND p.contract_id IS NOT NULL
AND NOT EXISTS(SELECT 1 FROM sidefx_observed.input i WHERE i.is_primary=1 AND i.origin_layer='AUTHORITY' AND i.contract_id=p.contract_id);
GO
CREATE OR ALTER VIEW sidefx.v_unresolved_dependencies AS
SELECT d.*,CASE WHEN EXISTS(SELECT 1 FROM sidefx_observed.capability c WHERE c.is_primary=1 AND c.origin_layer='AUTHORITY' AND c.capability_id=d.target_capability_id) THEN 'CAPABILITY_OBSERVED' ELSE 'TARGET_NOT_IN_MANAGED_CAPSULE_MANIFEST' END AS observation
FROM sidefx_observed.dependency d;
GO
CREATE OR ALTER VIEW sidefx.v_projection_anomalies AS
SELECT a.snapshot_id,a.artifact_id,a.capability_id,a.source_path,a.source_class,a.content_digest,a.extraction_status,
 CASE WHEN a.extraction_status='PARSE_FAILED' THEN 'PARSE_FAILURE' WHEN a.extraction_status='JSON_ARCHIVED' THEN 'NO_TYPED_ADAPTER_FOR_ROOT' ELSE 'NON_JSON_BYTES_RETAINED' END AS observation
FROM sidefx.artifact a WHERE a.extraction_status<>'TYPED';
GO
CREATE OR ALTER VIEW sidefx.v_capability_health AS
SELECT c.capability_id,s.scenario_count,
 s.missing_execution_authority_count,t.transition_finding_count,p.port_finding_count,
 x.extraction_issue_count,x.parse_failure_count,
 s.missing_execution_authority_count+t.transition_finding_count+p.port_finding_count+x.extraction_issue_count AS finding_count,
 s.nonterminal_without_transition_count,
 (SELECT COUNT(*) FROM sidefx.artifact a WHERE a.capability_id=c.capability_id AND a.source_class IN('MANAGED_CAPSULE','MANAGED_RUNTIME') AND a.extraction_status='JSON_ARCHIVED') AS untyped_json_artifact_count,
 'OBSERVATION_ONLY_NO_ADMISSION_OR_HEALTH_CERTIFICATION' AS assessment_basis
FROM sidefx_observed.capability c
OUTER APPLY(SELECT COUNT(*) AS scenario_count,COALESCE(SUM(CASE WHEN execution_authority_count=0 THEN 1 ELSE 0 END),0) AS missing_execution_authority_count,
 COALESCE(SUM(CASE WHEN terminal=0 AND declared_transition_count=0 THEN 1 ELSE 0 END),0) AS nonterminal_without_transition_count FROM sidefx.v_scenario_closure s WHERE s.capability_id=c.capability_id) s
OUTER APPLY(SELECT COUNT(*) AS transition_finding_count FROM sidefx.v_transition_integrity t WHERE t.capability_id=c.capability_id AND t.observation<>'ENDPOINTS_OBSERVED') t
OUTER APPLY(SELECT COUNT(*) AS port_finding_count FROM sidefx.v_port_binding_integrity p WHERE p.capability_id=c.capability_id AND p.observation<>'BINDING_OBSERVED') p
OUTER APPLY(SELECT COUNT(*) AS extraction_issue_count,COALESCE(SUM(CASE WHEN e.code IN('JSON_PARSE_FAILED','GHERKIN_PARSE_FAILED') THEN 1 ELSE 0 END),0) AS parse_failure_count FROM sidefx_observed.extraction_issue e WHERE e.capability_id=c.capability_id AND e.is_primary=1 AND e.origin_layer='AUTHORITY') x
WHERE c.is_primary=1 AND c.origin_layer='AUTHORITY';
