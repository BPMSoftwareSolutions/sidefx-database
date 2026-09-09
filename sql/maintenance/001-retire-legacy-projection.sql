-- Retire the legacy sidefx_data projection.
--
-- The sidefx_data table architecture was retired in favour of the
-- source/model/analysis schemas built by `npm run migrate`
-- (src/ingest/schema.mjs initialize() now throws LEGACY_SCHEMA_RETIRED).
-- The tables were removed but the 64 views that read them were left behind,
-- so every one of them is unbindable. They are the sole cause of the 3447
-- SQL71501 errors that block BACPAC / data-tier export.
--
-- Safe by construction: the script refuses to run if sidefx_data holds any
-- object, and refuses to drop any view that currently binds successfully.
-- Idempotent. Apply transactionally.

SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- Guard 1: the legacy projection must still be empty. If tables came back,
-- these views may be live again and this cleanup is not the right action.
IF EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
          WHERE s.name='sidefx_data' AND o.is_ms_shipped=0)
  THROW 51100,'sidefx_data is not empty; legacy projection still in use.',1;

DECLARE @retired TABLE(name sysname PRIMARY KEY);
INSERT @retired(name) VALUES
  (N'artifact'),
  (N'blueprint_edge'),
  (N'blueprint_node'),
  (N'canonical_object'),
  (N'capability'),
  (N'capability_source'),
  (N'classification'),
  (N'contract'),
  (N'dependency'),
  (N'digest'),
  (N'estate_snapshot'),
  (N'event'),
  (N'evidence'),
  (N'execution_authority'),
  (N'extraction_issue'),
  (N'fact'),
  (N'fact_relationship'),
  (N'feature'),
  (N'fixture'),
  (N'fixture_assertion'),
  (N'fixture_scenario'),
  (N'input'),
  (N'interface'),
  (N'mechanic'),
  (N'observed_blueprint_route'),
  (N'observed_execution_invoke_scenario'),
  (N'observed_runtime_route'),
  (N'observed_scenario'),
  (N'observed_semantic_graph_transition'),
  (N'operation'),
  (N'outcome'),
  (N'pattern_candidate'),
  (N'port'),
  (N'precedent'),
  (N'product'),
  (N'projection_authority'),
  (N'proof_obligation'),
  (N'provider'),
  (N'provider_binding'),
  (N'provider_slot'),
  (N'scenario'),
  (N'schema'),
  (N'semantic_term'),
  (N'source_pointer'),
  (N'term_relationship'),
  (N'transformation'),
  (N'transition'),
  (N'v_blueprint_execution_parity'),
  (N'v_capability_health'),
  (N'v_contract_usage'),
  (N'v_duplicate_capability_candidates'),
  (N'v_feature_source_integrity'),
  (N'v_fixture_coverage'),
  (N'v_mechanic_reuse'),
  (N'v_orphan_products'),
  (N'v_port_binding_integrity'),
  (N'v_projection_anomalies'),
  (N'v_proof_coverage'),
  (N'v_provider_coverage'),
  (N'v_scenario_closure'),
  (N'v_semantic_vocabulary_drift'),
  (N'v_slot_resolution'),
  (N'v_transition_integrity'),
  (N'v_unresolved_dependencies');

-- Guard 2: never drop a view that still binds. Anything that resolves today
-- is part of the current architecture and must survive.
DECLARE @live nvarchar(max);
SELECT @live=STRING_AGG(v.name,', ')
FROM sys.views v
JOIN sys.schemas s ON s.schema_id=v.schema_id
JOIN @retired r ON r.name=v.name
WHERE s.name='sidefx'
  AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_describe_first_result_set(
        N'SELECT * FROM sidefx.'+QUOTENAME(v.name),NULL,0) d
      WHERE d.error_message IS NOT NULL);
IF @live IS NOT NULL
  THROW 51101,'Refusing to drop views that still bind.',1;

DECLARE @sql nvarchar(max)=N'';
SELECT @sql=@sql+N'DROP VIEW sidefx.'+QUOTENAME(v.name)+N';'+CHAR(10)
FROM sys.views v
JOIN sys.schemas s ON s.schema_id=v.schema_id
JOIN @retired r ON r.name=v.name
WHERE s.name='sidefx';
EXEC sys.sp_executesql @sql;

-- The projection schema itself is now empty and unreferenced.
IF SCHEMA_ID('sidefx_data') IS NOT NULL DROP SCHEMA sidefx_data;

COMMIT TRANSACTION;
