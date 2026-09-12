-- 007-canonical-feature.sql
-- End-to-end canonical feature migration: schema + load + verification.
--
-- ONE transaction. This file is in VERIFICATION mode: it builds the model, loads
-- the data, proves it landed, then rolls back.
--
-- To apply after verification:
--   1. comment out "ROLLBACK TRANSACTION;"
--   2. uncomment "COMMIT TRANSACTION;"
--   3. run the file once.

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- ===== schema (007) =====
IF NOT EXISTS (SELECT 1 FROM model.identity_namespace WHERE namespace_kind='FEATURE' AND namespace_id=N'sidefx:features')
  INSERT model.identity_namespace (namespace_kind, namespace_id) VALUES ('FEATURE', N'sidefx:features');
GO
IF OBJECT_ID(N'model.feature','U') IS NULL
BEGIN
CREATE TABLE model.feature (
  feature_pk bigint IDENTITY(1,1) NOT NULL,
  namespace_pk bigint NOT NULL,
  feature_id nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  capability_pk bigint NOT NULL,
  semantic_object_pk bigint NOT NULL,
  object_kind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT PK_model_feature PRIMARY KEY CLUSTERED (feature_pk),
  CONSTRAINT CK_model_feature_kind CHECK (object_kind='FEATURE'),
  CONSTRAINT FK_model_feature_namespace FOREIGN KEY (namespace_pk) REFERENCES model.identity_namespace(namespace_pk),
  CONSTRAINT FK_model_feature_capability FOREIGN KEY (capability_pk) REFERENCES model.capability(capability_pk),
  CONSTRAINT FK_model_feature_semantic_object FOREIGN KEY (semantic_object_pk, object_kind, namespace_pk, feature_id) REFERENCES model.semantic_object(semantic_object_pk, object_kind, namespace_pk, declared_id)
);
ALTER TABLE model.feature ADD CONSTRAINT AK_model_feature_identity UNIQUE NONCLUSTERED (namespace_pk, feature_id);
ALTER TABLE model.feature ADD CONSTRAINT UK_model_feature_pk_capability UNIQUE NONCLUSTERED (feature_pk, capability_pk);
ALTER TABLE model.feature ADD CONSTRAINT AK_model_feature_pk_semantic_object UNIQUE NONCLUSTERED (feature_pk, semantic_object_pk);
END;
GO
IF OBJECT_ID(N'model.feature_version','U') IS NULL
BEGIN
CREATE TABLE model.feature_version (
  feature_version_pk bigint IDENTITY(1,1) NOT NULL,
  feature_pk bigint NOT NULL,
  capability_pk bigint NOT NULL,
  semantic_object_pk bigint NOT NULL,
  semantic_object_definition_pk bigint NOT NULL,
  definition_digest binary(32) NOT NULL,
  name nvarchar(max) NULL,
  source_profile nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  object_kind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  _owner_definition_pk bigint NOT NULL,
  _canonical_pointer nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT PK_model_feature_version PRIMARY KEY CLUSTERED (feature_version_pk),
  CONSTRAINT CK_model_feature_version_kind CHECK (object_kind='FEATURE'),
  CONSTRAINT FK_model_feature_version_feature FOREIGN KEY (feature_pk, capability_pk) REFERENCES model.feature(feature_pk, capability_pk),
  CONSTRAINT FK_model_feature_version_family FOREIGN KEY (feature_pk, semantic_object_pk) REFERENCES model.feature(feature_pk, semantic_object_pk),
  CONSTRAINT FK_model_feature_version_sod FOREIGN KEY (semantic_object_definition_pk, semantic_object_pk, object_kind, definition_digest) REFERENCES model.semantic_object_definition(semantic_object_definition_pk, semantic_object_pk, object_kind, definition_digest),
  CONSTRAINT FK_model_feature_version_owner FOREIGN KEY (_owner_definition_pk) REFERENCES model.semantic_object_definition(semantic_object_definition_pk)
);
ALTER TABLE model.feature_version ADD CONSTRAINT AK_model_feature_version_definition UNIQUE NONCLUSTERED (feature_pk, definition_digest);
ALTER TABLE model.feature_version ADD CONSTRAINT AK_model_feature_version_sod UNIQUE NONCLUSTERED (semantic_object_definition_pk);
ALTER TABLE model.feature_version ADD CONSTRAINT AK_model_feature_version_capability UNIQUE NONCLUSTERED (capability_pk, feature_version_pk);
END;
GO
IF OBJECT_ID(N'model.feature_scenario','U') IS NULL
BEGIN
CREATE TABLE model.feature_scenario (
  feature_version_pk bigint NOT NULL,
  scenario_pk bigint NOT NULL,
  scenario_version_pk bigint NOT NULL,
  capability_pk bigint NOT NULL,
  ordinal int NOT NULL,
  CONSTRAINT PK_model_feature_scenario PRIMARY KEY CLUSTERED (feature_version_pk, scenario_pk),
  CONSTRAINT CK_model_feature_scenario_ordinal CHECK (ordinal>=0),
  CONSTRAINT FK_model_feature_scenario_fv FOREIGN KEY (capability_pk, feature_version_pk) REFERENCES model.feature_version(capability_pk, feature_version_pk),
  CONSTRAINT FK_model_feature_scenario_scenario FOREIGN KEY (capability_pk, scenario_pk) REFERENCES model.scenario(capability_pk, scenario_pk),
  CONSTRAINT FK_model_feature_scenario_sv FOREIGN KEY (scenario_pk, scenario_version_pk) REFERENCES model.scenario_version(scenario_pk, scenario_version_pk)
);
END;
GO
IF OBJECT_ID(N'model.capability_feature','U') IS NULL
BEGIN
CREATE TABLE model.capability_feature (
  capability_feature_pk bigint IDENTITY(1,1) NOT NULL,
  capability_version_pk bigint NOT NULL,
  feature_version_pk bigint NOT NULL,
  capability_pk bigint NOT NULL,
  binding_role varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT PK_model_capability_feature PRIMARY KEY CLUSTERED (capability_feature_pk),
  CONSTRAINT CK_model_capability_feature_role CHECK (binding_role IN ('CANONICAL','ALTERNATE')),
  CONSTRAINT FK_model_capability_feature_cv FOREIGN KEY (capability_pk, capability_version_pk) REFERENCES model.capability_version(capability_pk, capability_version_pk),
  CONSTRAINT FK_model_capability_feature_fv FOREIGN KEY (capability_pk, feature_version_pk) REFERENCES model.feature_version(capability_pk, feature_version_pk)
);
CREATE UNIQUE NONCLUSTERED INDEX UXF_model_capability_feature_canonical ON model.capability_feature(capability_version_pk) WHERE binding_role='CANONICAL';
END;
GO
CREATE OR ALTER TRIGGER model.guard_feature ON model.feature AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; END;
GO
CREATE OR ALTER TRIGGER model.guard_feature_version ON model.feature_version AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; END;
GO
CREATE OR ALTER TRIGGER model.guard_feature_scenario ON model.feature_scenario AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; END;
GO
CREATE OR ALTER TRIGGER model.guard_capability_feature ON model.capability_feature AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; END;
GO
CREATE OR ALTER VIEW sidefx.v_capability_feature AS
SELECT ec.estate_model_pk, ec.capability_pk, c.capability_id, n.namespace_id,
       ec.capability_version_pk, cf.binding_role, f.feature_pk, f.feature_id,
       fv.feature_version_pk, fv.definition_digest, fv.source_profile
FROM source.current_model cm
JOIN model.estate_capability ec ON ec.estate_model_pk = cm.estate_model_pk
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk
LEFT JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role='CANONICAL'
LEFT JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
LEFT JOIN model.feature f ON f.feature_pk = fv.feature_pk
WHERE cm.singleton_id = 1;
GO
CREATE OR ALTER VIEW sidefx.v_capability_feature_scenarios AS
SELECT ec.estate_model_pk, ec.capability_pk, cf.feature_version_pk,
       fs.scenario_pk, s.scenario_id, fs.scenario_version_pk, fs.ordinal
FROM source.current_model cm
JOIN model.estate_capability ec ON ec.estate_model_pk = cm.estate_model_pk
JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role='CANONICAL'
JOIN model.feature_scenario fs ON fs.feature_version_pk = cf.feature_version_pk
JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
WHERE cm.singleton_id = 1;
GO
CREATE OR ALTER PROCEDURE source.validate_canonical_features @estate_model_pk bigint AS
BEGIN
SET NOCOUNT ON;
IF EXISTS (
  SELECT 1 FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk
  JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk
  WHERE ec.estate_model_pk = @estate_model_pk AND n.namespace_id = 'sidefx:capabilities'
    AND NOT EXISTS (SELECT 1 FROM model.capability_feature cf
                    WHERE cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL')
) THROW 51001,'G_CAPABILITY_CANONICAL_FEATURE',1;
IF EXISTS (
  SELECT 1 FROM model.capability_feature cf
  JOIN model.feature_scenario fs ON fs.feature_version_pk = cf.feature_version_pk
  JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
  WHERE cf.capability_pk <> s.capability_pk
) THROW 51001,'G_FEATURE_SCENARIO_OWNER',1;
IF EXISTS (
  SELECT 1 FROM model.capability_feature cf
  JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
  WHERE cf.capability_pk <> fv.capability_pk
) THROW 51001,'G_FEATURE_VERSION_OWNER',1;
END;

GO

-- ===== load (008) =====

DECLARE @model bigint = (SELECT estate_model_pk FROM source.current_model WHERE singleton_id = 1);
DECLARE @snap  bigint = (SELECT estate_snapshot_pk FROM source.estate_model WHERE estate_model_pk = @model);
DECLARE @feature_ns bigint = (SELECT namespace_pk FROM model.identity_namespace
                              WHERE namespace_kind = 'FEATURE' AND namespace_id = N'sidefx:features');
IF @feature_ns IS NULL THROW 51000, 'FEATURE_NAMESPACE_MISSING', 1;

-- A. Feature appearances that supplied this capability's scenario definitions.
IF OBJECT_ID('tempdb..#candidate') IS NOT NULL DROP TABLE #candidate;
CREATE TABLE #candidate (
  capability_pk bigint, capability_id nvarchar(400) COLLATE Latin1_General_100_BIN2, capability_version_pk bigint,
  source_appearance_pk bigint, source_path nvarchar(max) COLLATE Latin1_General_100_BIN2,
  source_class varchar(64) COLLATE Latin1_General_100_BIN2,
  capsule_digest binary(32), content_object_pk bigint, content_digest binary(32)
);

INSERT #candidate
SELECT DISTINCT ec.capability_pk, c.capability_id, ec.capability_version_pk,
       a.source_appearance_pk, a.source_path, a.source_class, a.capsule_digest,
       co.content_object_pk, co.content_digest
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk = cs.scenario_version_pk
JOIN source.source_lineage l ON l.semantic_object_definition_pk = sv.semantic_object_definition_pk
JOIN source.source_observation o ON o.source_observation_pk = l.source_observation_pk
JOIN source.source_appearance a ON a.source_appearance_pk = o.source_appearance_pk AND a.source_path LIKE '%.feature'
JOIN source.content_object co ON co.content_object_pk = a.content_object_pk
WHERE ec.estate_model_pk = @model;

-- B. Path-convention fallback for capabilities whose scenarios carry no feature lineage.
INSERT #candidate
SELECT DISTINCT ec.capability_pk, c.capability_id, ec.capability_version_pk,
       a.source_appearance_pk, a.source_path, a.source_class, a.capsule_digest,
       co.content_object_pk, co.content_digest
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN source.source_appearance a ON a.estate_snapshot_pk = @snap AND a.source_path LIKE '%.feature'
JOIN source.content_object co ON co.content_object_pk = a.content_object_pk
WHERE ec.estate_model_pk = @model
  AND (a.source_path = 'features/' + c.capability_id COLLATE DATABASE_DEFAULT + '.feature'
       OR a.source_path LIKE '%/' + c.capability_id COLLATE DATABASE_DEFAULT + '.feature')
  AND NOT EXISTS (SELECT 1 FROM #candidate x WHERE x.capability_pk = ec.capability_pk);

-- Optional explicit canonical choice per capability. Populate to override the
-- automatic ranking, for example the equity revision. Match on appearance or class.
IF OBJECT_ID('tempdb..#override') IS NOT NULL DROP TABLE #override;
CREATE TABLE #override (
  capability_id nvarchar(400) COLLATE Latin1_General_100_BIN2,
  source_appearance_pk bigint NULL,
  source_class varchar(64) COLLATE Latin1_General_100_BIN2 NULL
);
-- INSERT #override (capability_id, source_appearance_pk, source_class) VALUES
--   (N'resolve-equity-market-price-evidence', NULL, 'PROVISIONED_CAPSULE');

-- One canonical appearance per capability: explicit override, then repository-tracked,
-- then managed, then provisioned.
IF OBJECT_ID('tempdb..#ranked') IS NOT NULL DROP TABLE #ranked;
SELECT q.*, ROW_NUMBER() OVER (PARTITION BY q.capability_pk ORDER BY
  CASE WHEN EXISTS (SELECT 1 FROM #override ov WHERE ov.capability_id = q.capability_id
                    AND (ov.source_appearance_pk = q.source_appearance_pk OR ov.source_class = q.source_class))
       THEN 0 ELSE 1 END,
  CASE q.source_class WHEN 'REPOSITORY_TRACKED' THEN 1 WHEN 'MANAGED_CAPSULE' THEN 2
                      WHEN 'PROVISIONED_CAPSULE' THEN 3 ELSE 4 END, q.source_appearance_pk) AS rn
INTO #ranked FROM #candidate q;

IF OBJECT_ID('tempdb..#canonical') IS NOT NULL DROP TABLE #canonical;
SELECT * INTO #canonical FROM #ranked WHERE rn = 1;

-- Feature identity.
INSERT model.semantic_object (object_kind, namespace_pk, declared_id)
SELECT 'FEATURE', @feature_ns, q.capability_id
FROM #canonical q
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object so
                  WHERE so.object_kind = 'FEATURE' AND so.namespace_pk = @feature_ns AND so.declared_id = q.capability_id);

INSERT model.feature (namespace_pk, feature_id, capability_pk, semantic_object_pk, object_kind)
SELECT @feature_ns, q.capability_id, q.capability_pk, so.semantic_object_pk, 'FEATURE'
FROM #canonical q
JOIN model.semantic_object so ON so.object_kind = 'FEATURE' AND so.namespace_pk = @feature_ns AND so.declared_id = q.capability_id
WHERE NOT EXISTS (SELECT 1 FROM model.feature f WHERE f.namespace_pk = @feature_ns AND f.feature_id = q.capability_id);

-- Feature version definition: canonical manifest binding the retained source bytes.
IF OBJECT_ID('tempdb..#fv') IS NOT NULL DROP TABLE #fv;
CREATE TABLE #fv (
  feature_pk bigint, capability_pk bigint, capability_id nvarchar(400) COLLATE Latin1_General_100_BIN2,
  source_path nvarchar(max) COLLATE Latin1_General_100_BIN2,
  source_class varchar(64) COLLATE Latin1_General_100_BIN2, content_digest binary(32),
  envelope_json varchar(max), envelope_bytes varbinary(max), definition_digest binary(32)
);
INSERT #fv (feature_pk, capability_pk, capability_id, source_path, source_class, content_digest, envelope_json)
SELECT f.feature_pk, f.capability_pk, q.capability_id, q.source_path, q.source_class, q.content_digest,
       '{"address":{"id":"' + q.capability_id + '","kind":"FEATURE","namespace":"sidefx:features"},'
     + '"format":"sidefx-semantic-definition.v1",'
     + '"semantics":{"content_digest":"' + LOWER(CONVERT(varchar(64), q.content_digest, 2)) + '",'
     + '"source_class":"' + q.source_class + '",'
     + '"source_path":"' + REPLACE(q.source_path, '"', '\"') + '"}}'
FROM #canonical q
JOIN model.feature f ON f.namespace_pk = @feature_ns AND f.feature_id = q.capability_id;

UPDATE #fv SET envelope_bytes = CONVERT(varbinary(max), envelope_json);
UPDATE #fv SET definition_digest = HASHBYTES('SHA2_256', envelope_bytes);

INSERT source.content_object (content_digest, content_bytes, byte_length)
SELECT DISTINCT fv.definition_digest, fv.envelope_bytes, DATALENGTH(fv.envelope_bytes)
FROM #fv fv
WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest = fv.definition_digest);

INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
SELECT DISTINCT f.semantic_object_pk, 'FEATURE', fv.definition_digest, co.content_object_pk
FROM #fv fv
JOIN model.feature f ON f.feature_pk = fv.feature_pk
JOIN source.content_object co ON co.content_digest = fv.definition_digest
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition d
                  WHERE d.semantic_object_pk = f.semantic_object_pk AND d.definition_digest = fv.definition_digest);

INSERT model.feature_version (feature_pk, capability_pk, semantic_object_pk, semantic_object_definition_pk,
  definition_digest, name, source_profile, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT f.feature_pk, fv.capability_pk, f.semantic_object_pk, d.semantic_object_definition_pk,
       fv.definition_digest, fv.capability_id, 'retained-feature-binding.v1', 'FEATURE',
       d.semantic_object_definition_pk, N''
FROM #fv fv
JOIN model.feature f ON f.feature_pk = fv.feature_pk
JOIN model.semantic_object_definition d ON d.semantic_object_pk = f.semantic_object_pk AND d.definition_digest = fv.definition_digest
WHERE NOT EXISTS (SELECT 1 FROM model.feature_version x WHERE x.feature_pk = f.feature_pk AND x.definition_digest = fv.definition_digest);

-- Feature-declared scenario set (the selected normalized scenarios of the bound feature).
INSERT model.feature_scenario (feature_version_pk, scenario_pk, scenario_version_pk, capability_pk, ordinal)
SELECT fvr.feature_version_pk, cs.scenario_pk, cs.scenario_version_pk, ec.capability_pk,
       ROW_NUMBER() OVER (PARTITION BY ec.capability_pk ORDER BY s.scenario_id) - 1
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk = cs.scenario_pk
JOIN model.feature f ON f.capability_pk = ec.capability_pk
JOIN (SELECT feature_pk, MAX(feature_version_pk) AS feature_version_pk FROM model.feature_version GROUP BY feature_pk) fvr
  ON fvr.feature_pk = f.feature_pk
WHERE ec.estate_model_pk = @model
  AND NOT EXISTS (SELECT 1 FROM model.feature_scenario x
                  WHERE x.feature_version_pk = fvr.feature_version_pk AND x.scenario_pk = cs.scenario_pk);

-- Canonical binding.
INSERT model.capability_feature (capability_version_pk, feature_version_pk, capability_pk, binding_role)
SELECT ec.capability_version_pk, fvr.feature_version_pk, ec.capability_pk, 'CANONICAL'
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN model.feature f ON f.capability_pk = ec.capability_pk
JOIN (SELECT feature_pk, MAX(feature_version_pk) AS feature_version_pk FROM model.feature_version GROUP BY feature_pk) fvr
  ON fvr.feature_pk = f.feature_pk
WHERE ec.estate_model_pk = @model
  AND NOT EXISTS (SELECT 1 FROM model.capability_feature x
                  WHERE x.capability_version_pk = ec.capability_version_pk AND x.binding_role = 'CANONICAL');



-- ===== verification (runs before rollback) =====
SELECT 'counts' AS check_name,
       (SELECT COUNT(*) FROM model.feature) AS features,
       (SELECT COUNT(*) FROM model.feature_version) AS feature_versions,
       (SELECT COUNT(*) FROM model.feature_scenario) AS feature_scenarios,
       (SELECT COUNT(*) FROM model.capability_feature WHERE binding_role='CANONICAL') AS canonical_bindings;

SELECT 'gap_capability' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS outcome,
       COUNT(*) AS violations,
       STRING_AGG(t.capability_id, ', ') AS offenders
FROM (
  SELECT c.capability_id
  FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk
  JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
  WHERE ec.estate_model_pk = @model
    AND NOT EXISTS (SELECT 1 FROM model.feature f WHERE f.capability_pk = ec.capability_pk)
) t;

SELECT 'gate_missing_binding' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS outcome,
       COUNT(*) AS violations,
       STRING_AGG(t.capability_id, ', ') AS offenders
FROM (
  SELECT c.capability_id
  FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk
  JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
  WHERE ec.estate_model_pk = @model
    AND NOT EXISTS (SELECT 1 FROM model.capability_feature cf
                    WHERE cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL')
) t;

SELECT 'gate_scenario_owner' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS outcome,
       COUNT(*) AS violations,
       STRING_AGG(t.scenario_id, ', ') AS offenders
FROM (
  SELECT s.scenario_id
  FROM model.capability_feature cf
  JOIN model.feature_scenario fs ON fs.feature_version_pk = cf.feature_version_pk
  JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
  WHERE cf.capability_pk <> s.capability_pk
) t;

SELECT 'binding_sample' AS check_name, c.capability_id,
       JSON_VALUE(CONVERT(varchar(max), co.content_bytes), '$.semantics.source_path') AS source_path,
       JSON_VALUE(CONVERT(varchar(max), co.content_bytes), '$.semantics.source_class') AS source_class,
       LOWER(CONVERT(varchar(64), fv.definition_digest, 2)) AS feature_digest,
       (SELECT COUNT(*) FROM model.feature_scenario fs WHERE fs.feature_version_pk = fv.feature_version_pk) AS feature_scenarios
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL'
JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk = fv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk = d.canonical_content_pk
WHERE ec.estate_model_pk = @model
  AND c.capability_id IN ('resolve-equity-market-price-evidence', 'manage-capsule-estate', 'resolve-sidefx-eligible-providers');

-- Full relationship report: one row per selected capability.
-- feature_scenarios vs selected_scenarios and the scenario-set match prove the binding covers the whole capability.
SELECT 'feature_capability_rollup' AS check_name, c.capability_id, n.namespace_id AS capability_namespace,
       ec.capability_version_pk,
       LOWER(CONVERT(varchar(64), cv.definition_digest, 2)) AS capability_digest,
       cf.binding_role, f.feature_id, fv.feature_version_pk,
       LOWER(CONVERT(varchar(64), fv.definition_digest, 2)) AS feature_digest,
       JSON_VALUE(CONVERT(varchar(max), co.content_bytes), '$.semantics.source_path') AS feature_source_path,
       JSON_VALUE(CONVERT(varchar(max), co.content_bytes), '$.semantics.source_class') AS feature_source_class,
       JSON_VALUE(CONVERT(varchar(max), co.content_bytes), '$.semantics.content_digest') AS feature_content_digest,
       (SELECT COUNT(*) FROM model.feature_scenario fs WHERE fs.feature_version_pk = fv.feature_version_pk) AS feature_scenarios,
       (SELECT COUNT(*) FROM model.capability_scenario cs WHERE cs.capability_version_pk = ec.capability_version_pk) AS selected_scenarios,
       (SELECT COUNT(*) FROM model.feature_scenario fs
        JOIN model.scenario_version sv ON sv.scenario_version_pk = fs.scenario_version_pk
        JOIN model.semantic_object_definition d2 ON d2.semantic_object_definition_pk = sv.semantic_object_definition_pk
        JOIN source.content_object co2 ON co2.content_object_pk = d2.canonical_content_pk
        WHERE fs.feature_version_pk = fv.feature_version_pk
          AND JSON_QUERY(CONVERT(varchar(max), co2.content_bytes), '$.semantics.scenario') IS NOT NULL) AS authored_spec_scenarios,
       CASE WHEN EXISTS (
              SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk = ec.capability_version_pk
              EXCEPT
              SELECT fs.scenario_pk FROM model.feature_scenario fs WHERE fs.feature_version_pk = fv.feature_version_pk)
            OR EXISTS (
              SELECT fs.scenario_pk FROM model.feature_scenario fs WHERE fs.feature_version_pk = fv.feature_version_pk
              EXCEPT
              SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk = ec.capability_version_pk)
         THEN 'MISMATCH' ELSE 'MATCH' END AS scenario_set_match
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN model.capability_version cv ON cv.capability_version_pk = ec.capability_version_pk
LEFT JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL'
LEFT JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
LEFT JOIN model.feature f ON f.feature_pk = fv.feature_pk
LEFT JOIN model.semantic_object_definition fd ON fd.semantic_object_definition_pk = fv.semantic_object_definition_pk
LEFT JOIN source.content_object co ON co.content_object_pk = fd.canonical_content_pk
WHERE ec.estate_model_pk = @model
ORDER BY c.capability_id;

-- Full relationship report: one row per feature scenario, with the authored-spec state.
SELECT 'feature_scenario_detail' AS check_name, c.capability_id, f.feature_id, fs.ordinal,
       s.scenario_id, fs.scenario_pk, fs.scenario_version_pk,
       LOWER(CONVERT(varchar(64), sv.definition_digest, 2)) AS scenario_digest,
       sv.source_profile,
       CASE WHEN JSON_QUERY(CONVERT(varchar(max), co2.content_bytes), '$.semantics.scenario') IS NOT NULL THEN 1 ELSE 0 END AS has_authored_spec,
       (SELECT COUNT(*) FROM OPENJSON(CONVERT(varchar(max), co2.content_bytes), '$.semantics.scenario.steps')) AS step_count,
       CASE WHEN cs.scenario_version_pk = fs.scenario_version_pk THEN 1 ELSE 0 END AS pinned_equals_selected
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk = ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL'
JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
JOIN model.feature f ON f.feature_pk = fv.feature_pk
JOIN model.feature_scenario fs ON fs.feature_version_pk = fv.feature_version_pk
JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk = fs.scenario_version_pk
JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk = sv.semantic_object_definition_pk
JOIN source.content_object co2 ON co2.content_object_pk = sd.canonical_content_pk
LEFT JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk AND cs.scenario_pk = fs.scenario_pk
WHERE ec.estate_model_pk = @model
ORDER BY c.capability_id, fs.ordinal;

-- Gate: every bound feature scenario carries an authored specification.
SELECT 'gate_authored_spec' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS outcome,
       COUNT(*) AS violations,
       STRING_AGG(t.scenario_id, ', ') AS offenders
FROM (
  SELECT DISTINCT s.scenario_id
  FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk
  JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
  JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL'
  JOIN model.feature_scenario fs ON fs.feature_version_pk = cf.feature_version_pk
  JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
  JOIN model.scenario_version sv ON sv.scenario_version_pk = fs.scenario_version_pk
  JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk = sv.semantic_object_definition_pk
  JOIN source.content_object co ON co.content_object_pk = sd.canonical_content_pk
  WHERE ec.estate_model_pk = @model
    AND JSON_QUERY(CONVERT(varchar(max), co.content_bytes), '$.semantics.scenario') IS NULL
) t;

-- Face normalization report: one row per feature scenario. The declared @input/@event/
-- @outcome (and their contract/authority tags) are read from the authored AST and
-- compared to the normalized model.scenario_input/event/outcome rows.
IF OBJECT_ID('tempdb..#faces') IS NOT NULL DROP TABLE #faces;
WITH base AS (
  SELECT c.capability_id, f.feature_id, fs.ordinal, s.scenario_id, sv.scenario_version_pk,
         CONVERT(varchar(max), co.content_bytes) AS scenario_json
  FROM model.estate_capability ec
  JOIN model.capability c ON c.capability_pk = ec.capability_pk
  JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk AND n.namespace_id = 'sidefx:capabilities'
  JOIN model.capability_feature cf ON cf.capability_version_pk = ec.capability_version_pk AND cf.binding_role = 'CANONICAL'
  JOIN model.feature_version fv ON fv.feature_version_pk = cf.feature_version_pk
  JOIN model.feature f ON f.feature_pk = fv.feature_pk
  JOIN model.feature_scenario fs ON fs.feature_version_pk = fv.feature_version_pk
  JOIN model.scenario s ON s.scenario_pk = fs.scenario_pk
  JOIN model.scenario_version sv ON sv.scenario_version_pk = fs.scenario_version_pk
  JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk = sv.semantic_object_definition_pk
  JOIN source.content_object co ON co.content_object_pk = d.canonical_content_pk
  WHERE ec.estate_model_pk = @model
)
SELECT b.capability_id, b.feature_id, b.scenario_id, b.ordinal, b.scenario_version_pk,
       tg.tag_input, i.input_id, ic.contract_id AS input_contract, i.contract_reference_state AS input_ref_state,
       tg.tag_input_contract, tg.tag_event, e.event_id, ea.execution_authority_id AS event_authority,
       e.authority_reference_state AS event_ref_state, tg.tag_event_authority,
       tg.tag_outcome, o.outcome_id, occ.contract_id AS outcome_contract, o.terminal, o.terminal_disposition,
       tg.tag_outcome_contract, tg.tag_terminal_disposition,
       CASE WHEN JSON_QUERY(b.scenario_json, '$.semantics.scenario') IS NOT NULL THEN 1 ELSE 0 END AS has_authored_spec,
       (SELECT COUNT(*) FROM OPENJSON(b.scenario_json, '$.semantics.scenario.steps')) AS step_count,
       CASE WHEN i.scenario_version_pk IS NOT NULL AND e.scenario_version_pk IS NOT NULL AND o.scenario_version_pk IS NOT NULL
             AND i.contract_reference_state = 'RESOLVED'
             AND e.authority_reference_state IN ('RESOLVED', 'ABSENT', 'NOT_APPLICABLE')
            THEN 1 ELSE 0 END AS face_complete,
       CASE WHEN (tg.tag_input IS NULL OR tg.tag_input = i.input_id)
             AND (tg.tag_event IS NULL OR tg.tag_event = e.event_id)
             AND (tg.tag_outcome IS NULL OR tg.tag_outcome = o.outcome_id)
            THEN 1 ELSE 0 END AS face_match
INTO #faces
FROM base b
OUTER APPLY (
  SELECT
    MAX(CASE WHEN j.[key] = 'input' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_input,
    MAX(CASE WHEN j.[key] = 'input-contract' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_input_contract,
    MAX(CASE WHEN j.[key] = 'event' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_event,
    MAX(CASE WHEN j.[key] = 'event-authority' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_event_authority,
    MAX(CASE WHEN j.[key] = 'outcome' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_outcome,
    MAX(CASE WHEN j.[key] = 'outcome-contract' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_outcome_contract,
    MAX(CASE WHEN j.[key] = 'terminal-disposition' THEN JSON_VALUE(j.value, '$[0]') END) COLLATE Latin1_General_100_BIN2 AS tag_terminal_disposition
  FROM OPENJSON(b.scenario_json, '$.semantics.tags') j
) tg
LEFT JOIN model.scenario_input i ON i.scenario_version_pk = b.scenario_version_pk
LEFT JOIN model.contract_version icv ON icv.contract_version_pk = i.input_contract_version_pk
LEFT JOIN model.contract ic ON ic.contract_pk = icv.contract_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk = b.scenario_version_pk
LEFT JOIN model.execution_authority_version eav ON eav.execution_authority_version_pk = e.execution_authority_version_pk
LEFT JOIN model.execution_authority ea ON ea.execution_authority_pk = eav.execution_authority_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk = b.scenario_version_pk
LEFT JOIN model.scenario_outcome_contract soc ON soc.scenario_version_pk = b.scenario_version_pk
LEFT JOIN model.contract_version ocv ON ocv.contract_version_pk = soc.contract_version_pk
LEFT JOIN model.contract occ ON occ.contract_pk = ocv.contract_pk;

SELECT 'feature_scenario_faces' AS check_name, *
FROM #faces
ORDER BY capability_id, ordinal;

-- Gate: every bound feature scenario has a complete, matching normalized face.
SELECT 'gate_scenario_faces' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS outcome,
       COUNT(*) AS violations,
       STRING_AGG(t.capability_id + '/' + t.scenario_id, ', ') AS offenders
FROM (SELECT * FROM #faces WHERE face_complete = 0 OR face_match = 0) t;

ROLLBACK TRANSACTION;

-- COMMIT TRANSACTION;
