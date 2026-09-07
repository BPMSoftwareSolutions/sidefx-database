CREATE OR ALTER VIEW sidefx.[capability] AS
SELECT d.* FROM sidefx_data.[capability] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY';
GO
CREATE OR ALTER VIEW sidefx.[feature] AS
SELECT d.* FROM sidefx_data.[feature] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY' AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id));
GO
CREATE OR ALTER VIEW sidefx.[scenario] AS
SELECT d.* FROM sidefx_data.[scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY' AND d.pointer_kind='LINE' AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id));
GO
CREATE OR ALTER VIEW sidefx.[input] AS
SELECT d.* FROM sidefx_data.[input] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY' AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id));
GO
CREATE OR ALTER VIEW sidefx.[event] AS
SELECT d.* FROM sidefx_data.[event] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY' AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id));
GO
CREATE OR ALTER VIEW sidefx.[outcome] AS
SELECT d.* FROM sidefx_data.[outcome] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[product] AS
SELECT d.* FROM sidefx_data.[product] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY' AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id));
GO
CREATE OR ALTER VIEW sidefx.contract AS
      WITH consumed AS(SELECT contract_id,COUNT(*) AS consumer_count FROM sidefx.input GROUP BY contract_id),
      produced AS(SELECT contract_id,COUNT(*) AS producer_count FROM sidefx.product GROUP BY contract_id)
      SELECT d.*,COALESCE(c.consumer_count,0) AS consumer_count,COALESCE(r.producer_count,0) AS producer_count
      FROM sidefx_data.contract d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
      LEFT JOIN consumed c ON c.contract_id=d.contract_id LEFT JOIN produced r ON r.contract_id=d.contract_id WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY';
GO
CREATE OR ALTER VIEW sidefx.[schema] AS
SELECT d.* FROM sidefx_data.[schema] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[blueprint_node] AS
SELECT d.* FROM sidefx_data.[blueprint_node] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[blueprint_edge] AS
SELECT d.* FROM sidefx_data.[blueprint_edge] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[observed_blueprint_route] AS
SELECT d.* FROM sidefx_data.[observed_blueprint_route] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[observed_semantic_graph_transition] AS
SELECT d.* FROM sidefx_data.[observed_semantic_graph_transition] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[observed_execution_invoke_scenario] AS
SELECT d.* FROM sidefx_data.[observed_execution_invoke_scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[observed_runtime_route] AS
SELECT d.* FROM sidefx_data.[observed_runtime_route] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[execution_authority] AS
SELECT d.* FROM sidefx_data.[execution_authority] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[operation] AS
SELECT d.* FROM sidefx_data.[operation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[transformation] AS
SELECT d.* FROM sidefx_data.[transformation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[mechanic] AS
SELECT d.* FROM sidefx_data.[mechanic] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[port] AS
SELECT d.* FROM sidefx_data.[port] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[provider_slot] AS
SELECT d.* FROM sidefx_data.[provider_slot] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[provider] AS
SELECT d.* FROM sidefx_data.[provider] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[provider_binding] AS
SELECT d.* FROM sidefx_data.[provider_binding] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[interface] AS
SELECT d.* FROM sidefx_data.[interface] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[fixture] AS
SELECT d.* FROM sidefx_data.[fixture] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[fixture_scenario] AS
SELECT d.* FROM sidefx_data.[fixture_scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[fixture_assertion] AS
SELECT d.* FROM sidefx_data.[fixture_assertion] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[proof_obligation] AS
SELECT d.* FROM sidefx_data.[proof_obligation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[evidence] AS
SELECT d.* FROM sidefx_data.[evidence] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[projection_authority] AS
SELECT d.* FROM sidefx_data.[projection_authority] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[dependency] AS
SELECT d.* FROM sidefx_data.[dependency] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[semantic_term] AS
SELECT d.* FROM sidefx_data.[semantic_term] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[term_relationship] AS
SELECT d.* FROM sidefx_data.[term_relationship] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[classification] AS
SELECT d.* FROM sidefx_data.[classification] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[fact] AS
SELECT d.* FROM sidefx_data.[fact] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[fact_relationship] AS
SELECT d.* FROM sidefx_data.[fact_relationship] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[precedent] AS
SELECT d.* FROM sidefx_data.[precedent] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[pattern_candidate] AS
SELECT d.* FROM sidefx_data.[pattern_candidate] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[extraction_issue] AS
SELECT d.* FROM sidefx_data.[extraction_issue] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.provider_slot AS
    SELECT d.*,b.binding_count,b.provider_count,CASE WHEN b.provider_count=1 THEN b.provider_id ELSE NULL END AS provider_id
    FROM sidefx_data.provider_slot d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
    OUTER APPLY(SELECT COUNT(*) AS binding_count,COUNT(DISTINCT b.provider_id) AS provider_count,MIN(b.provider_id) AS provider_id
      FROM sidefx_data.provider_binding b WHERE b.projection_id=d.projection_id AND b.capability_id=d.capability_id AND b.is_primary=1 AND b.origin_layer=d.origin_layer
      AND ((d.slot_id IS NOT NULL AND b.slot_id=d.slot_id) OR (d.port_id IS NOT NULL AND b.port_id=d.port_id))) b;
GO
CREATE OR ALTER VIEW sidefx.observed_scenario AS SELECT d.* FROM sidefx_data.scenario d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;
GO
CREATE OR ALTER VIEW sidefx.[transition] AS SELECT d.*,'SEMANTIC_GRAPH' AS representation FROM sidefx.observed_semantic_graph_transition d;
GO
CREATE OR ALTER VIEW sidefx.estate_snapshot AS SELECT * FROM sidefx_data.estate_snapshot;
GO
CREATE OR ALTER VIEW sidefx.artifact AS SELECT a.*,c.format,c.status AS extraction_status,c.root_type FROM sidefx_data.artifact a JOIN sidefx_data.current_pointer p ON p.snapshot_id=a.snapshot_id JOIN sidefx_data.artifact_catalog c ON c.projection_id=p.projection_id AND c.artifact_id=a.artifact_id;
GO
CREATE OR ALTER VIEW sidefx.canonical_object AS SELECT o.* FROM sidefx_data.canonical_object o WHERE EXISTS(SELECT 1 FROM sidefx.artifact a WHERE a.content_digest=o.content_digest);
GO
CREATE OR ALTER VIEW sidefx.digest AS SELECT content_digest,byte_length FROM sidefx.canonical_object;
GO
CREATE OR ALTER VIEW sidefx.capability_source AS SELECT DISTINCT a.snapshot_id,a.capability_id,a.capsule_digest,a.authority_digest,a.container_path FROM sidefx.artifact a WHERE a.source_class IN('MANAGED_CAPSULE','MANAGED_RUNTIME','PROVISIONED_CAPSULE');
GO
CREATE OR ALTER VIEW sidefx.source_pointer AS SELECT 'capability' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[capability] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'feature' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[feature] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'scenario' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'input' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[input] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'event' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[event] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'outcome' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[outcome] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'product' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[product] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'contract' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[contract] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'schema' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[schema] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'blueprint_node' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[blueprint_node] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'blueprint_edge' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[blueprint_edge] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'observed_blueprint_route' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[observed_blueprint_route] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'observed_semantic_graph_transition' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[observed_semantic_graph_transition] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'observed_execution_invoke_scenario' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[observed_execution_invoke_scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'observed_runtime_route' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[observed_runtime_route] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'execution_authority' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[execution_authority] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'operation' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[operation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'transformation' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[transformation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'mechanic' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[mechanic] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'port' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[port] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'provider_slot' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[provider_slot] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'provider' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[provider] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'provider_binding' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[provider_binding] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'interface' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[interface] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'fixture' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[fixture] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'fixture_scenario' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[fixture_scenario] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'fixture_assertion' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[fixture_assertion] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'proof_obligation' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[proof_obligation] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'evidence' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[evidence] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'projection_authority' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[projection_authority] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'dependency' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[dependency] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'semantic_term' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[semantic_term] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'term_relationship' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[term_relationship] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'classification' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[classification] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'fact' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[fact] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'fact_relationship' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[fact_relationship] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'precedent' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[precedent] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'pattern_candidate' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[pattern_candidate] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id
UNION ALL
SELECT 'extraction_issue' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_data.[extraction_issue] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id;
