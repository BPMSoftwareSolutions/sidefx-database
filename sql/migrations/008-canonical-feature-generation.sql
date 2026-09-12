-- 008-canonical-feature-generation.sql
-- One transaction that closes the 007 gaps and the reference defects:
--   1. generation-scoped feature binding (model.estate_capability_feature).
--   2. parsed feature declaration (title, narrative, pinned scenarios) in feature_version.
--   3. materialize the declared-but-absent contracts (schema ABSENT) and authorities (no ops).
--   4. record the 2 VERSION_DEFINITION_CONFLICT ids.
--   5. resolve the affected faces for the generation through an append-only,
--      generation-scoped resolution relation (model.estate_scenario_face_resolution)
--      instead of duplicating immutable scenario/capability definitions.
--
-- Verification mode: builds the new generation, proves it, rolls back.
-- Apply by commenting ROLLBACK and uncommenting COMMIT (and publish).

SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @from bigint = (SELECT estate_model_pk FROM source.current_model WHERE singleton_id = 1);
DECLARE @snap bigint = (SELECT estate_snapshot_pk FROM source.estate_model WHERE estate_model_pk = @from);
DECLARE @rule bigint = (SELECT MAX(mapping_rule_pk) FROM source.estate_model_rule WHERE estate_model_pk = @from);
DECLARE @feature_ns bigint = (SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind='FEATURE' AND namespace_id=N'sidefx:features');
IF @feature_ns IS NULL THROW 51000,'FEATURE_NAMESPACE_MISSING',1;

-- 1. generation-scoped feature membership
IF OBJECT_ID('model.estate_capability_feature','U') IS NULL
CREATE TABLE model.estate_capability_feature (
  estate_model_pk bigint NOT NULL,
  capability_pk bigint NOT NULL,
  capability_version_pk bigint NOT NULL,
  feature_version_pk bigint NOT NULL,
  binding_role varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT PK_model_estate_capability_feature PRIMARY KEY CLUSTERED (estate_model_pk, capability_pk),
  CONSTRAINT CK_model_estate_capability_feature_role CHECK (binding_role IN ('CANONICAL','ALTERNATE')),
  CONSTRAINT FK_ecf_model FOREIGN KEY (estate_model_pk) REFERENCES source.estate_model(estate_model_pk),
  CONSTRAINT FK_ecf_capability FOREIGN KEY (estate_model_pk, capability_pk) REFERENCES model.estate_capability(estate_model_pk, capability_pk),
  CONSTRAINT FK_ecf_version FOREIGN KEY (capability_pk, capability_version_pk) REFERENCES model.capability_version(capability_pk, capability_version_pk),
  CONSTRAINT FK_ecf_feature FOREIGN KEY (capability_pk, feature_version_pk) REFERENCES model.feature_version(capability_pk, feature_version_pk)
);

-- 5. generation-scoped face resolution relation
IF OBJECT_ID('model.estate_scenario_face_resolution','U') IS NULL
CREATE TABLE model.estate_scenario_face_resolution (
  estate_model_pk bigint NOT NULL,
  scenario_version_pk bigint NOT NULL,
  role varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
  contract_version_pk bigint NULL,
  execution_authority_version_pk bigint NULL,
  resolution_state varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT PK_model_estate_scenario_face_resolution PRIMARY KEY CLUSTERED (estate_model_pk, scenario_version_pk, role),
  CONSTRAINT CK_esfr_role CHECK (role IN ('input','event')),
  CONSTRAINT FK_esfr_model FOREIGN KEY (estate_model_pk) REFERENCES source.estate_model(estate_model_pk),
  CONSTRAINT FK_esfr_sv FOREIGN KEY (scenario_version_pk) REFERENCES model.scenario_version(scenario_version_pk),
  CONSTRAINT FK_esfr_contract FOREIGN KEY (contract_version_pk) REFERENCES model.contract_version(contract_version_pk),
  CONSTRAINT FK_esfr_authority FOREIGN KEY (execution_authority_version_pk) REFERENCES model.execution_authority_version(execution_authority_version_pk),
  CONSTRAINT CK_esfr_target CHECK (contract_version_pk IS NOT NULL OR execution_authority_version_pk IS NOT NULL)
);

-- parsed feature declaration
IF OBJECT_ID('tempdb..#parsed') IS NOT NULL DROP TABLE #parsed;
SELECT f.feature_pk, f.capability_pk, f.feature_id, ra.source_appearance_pk, CONVERT(varchar(max), b.content_bytes) AS feature_text
INTO #raw
FROM model.feature f
JOIN model.feature_version fv ON fv.feature_pk=f.feature_pk
JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=fv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk=d.canonical_content_pk
CROSS APPLY (SELECT TOP 1 a.source_appearance_pk, a.content_object_pk FROM source.source_appearance a
  JOIN source.content_object c2 ON c2.content_object_pk=a.content_object_pk
  WHERE a.estate_snapshot_pk=@snap AND a.source_path=JSON_VALUE(CONVERT(varchar(max), co.content_bytes),'$.semantics.source_path')
    AND LOWER(CONVERT(varchar(64), c2.content_digest,2))=ISNULL(JSON_VALUE(CONVERT(varchar(max), co.content_bytes),'$.semantics.content_digest'),'')) ra
JOIN source.content_object b ON b.content_object_pk=ra.content_object_pk;
SELECT r.feature_pk, r.capability_pk, r.feature_id, r.source_appearance_pk,
       CASE WHEN p.ns>0 AND p.nl>p.ns THEN LTRIM(RTRIM(SUBSTRING(r.feature_text,p.ns+8,p.nl-(p.ns+8)))) END AS feature_name,
       CASE WHEN p.nl>0 AND p.de>p.nl+1 THEN LTRIM(RTRIM(SUBSTRING(r.feature_text,p.nl+1,p.de-(p.nl+1)))) END AS feature_description
INTO #parsed
FROM #raw r
CROSS APPLY (SELECT CHARINDEX('Feature:',r.feature_text) AS ns,
  CHARINDEX(CHAR(10),r.feature_text,CHARINDEX('Feature:',r.feature_text)) AS nl,
  CASE WHEN CHARINDEX('@',r.feature_text,CHARINDEX(CHAR(10),r.feature_text,CHARINDEX('Feature:',r.feature_text))+1)=0 THEN LEN(r.feature_text)+1
       ELSE CHARINDEX('@',r.feature_text,CHARINDEX(CHAR(10),r.feature_text,CHARINDEX('Feature:',r.feature_text))+1) END AS de) p;

IF OBJECT_ID('tempdb..#fvdef') IS NOT NULL DROP TABLE #fvdef;
CREATE TABLE #fvdef (feature_pk bigint, capability_pk bigint, semantic_object_pk bigint, feature_id nvarchar(400) COLLATE Latin1_General_100_BIN2, envelope_bytes varbinary(max), definition_digest binary(32));
INSERT #fvdef (feature_pk, capability_pk, semantic_object_pk, feature_id, envelope_bytes)
SELECT p.feature_pk, p.capability_pk, f.semantic_object_pk, p.feature_id, CONVERT(varbinary(max), CONVERT(varchar(max),
  '{"address":{"id":"'+p.feature_id COLLATE DATABASE_DEFAULT+'","kind":"FEATURE","namespace":"sidefx:features"},"format":"sidefx-semantic-definition.v1","semantics":{"name":'
+ ISNULL('"'+STRING_ESCAPE(p.feature_name,'json')+'"','null')
+ ',"description":'+ISNULL('"'+STRING_ESCAPE(p.feature_description,'json')+'"','null')
+ ',"content_digest":"'+ISNULL(JSON_VALUE(CONVERT(varchar(max), fb.content_bytes),'$.semantics.content_digest'),'')+'","source_path":"'+ISNULL(JSON_VALUE(CONVERT(varchar(max), fb.content_bytes),'$.semantics.source_path'),'')+'","scenarios":['
+ ISNULL(STUFF((SELECT ',' + '{"scenarioId":"'+s.scenario_id COLLATE DATABASE_DEFAULT+'","scenarioVersionPk":'+CONVERT(varchar(20),fs.scenario_version_pk)+'}'
     FROM model.feature_scenario fs JOIN model.scenario s ON s.scenario_pk=fs.scenario_pk
     WHERE fs.feature_version_pk=(SELECT TOP 1 fv2.feature_version_pk FROM model.feature_version fv2 WHERE fv2.feature_pk=p.feature_pk ORDER BY fv2.feature_version_pk)
     ORDER BY fs.ordinal FOR XML PATH(''),TYPE).value('.','varchar(max)'),1,1,''),'')+']}}'))
FROM #parsed p
JOIN model.feature f ON f.feature_pk=p.feature_pk
JOIN model.feature_version fvv ON fvv.feature_pk=p.feature_pk
JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=fvv.semantic_object_definition_pk
JOIN source.content_object fb ON fb.content_object_pk=d.canonical_content_pk;
UPDATE #fvdef SET definition_digest=HASHBYTES('SHA2_256',envelope_bytes);
INSERT source.content_object (content_digest, content_bytes, byte_length)
SELECT DISTINCT definition_digest, envelope_bytes, DATALENGTH(envelope_bytes) FROM #fvdef v WHERE NOT EXISTS (SELECT 1 FROM source.content_object c WHERE c.content_digest=v.definition_digest);
INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
SELECT DISTINCT v.semantic_object_pk, 'FEATURE', v.definition_digest, co.content_object_pk FROM #fvdef v JOIN source.content_object co ON co.content_digest=v.definition_digest
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition d WHERE d.semantic_object_pk=v.semantic_object_pk AND d.definition_digest=v.definition_digest);
INSERT model.feature_version (feature_pk, capability_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest, name, source_profile, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT DISTINCT v.feature_pk, v.capability_pk, v.semantic_object_pk, d.semantic_object_definition_pk, v.definition_digest, v.feature_id, 'parsed-feature-declaration.v1', 'FEATURE', d.semantic_object_definition_pk, N''
FROM #fvdef v JOIN model.semantic_object_definition d ON d.semantic_object_pk=v.semantic_object_pk AND d.definition_digest=v.definition_digest
WHERE NOT EXISTS (SELECT 1 FROM model.feature_version x WHERE x.feature_pk=v.feature_pk AND x.definition_digest=v.definition_digest);
INSERT source.source_observation (source_appearance_pk, locator, locator_digest, observation_kind, presence_state, observed_value_content_pk)
SELECT DISTINCT p.source_appearance_pk, N'', HASHBYTES('SHA2_256',CONVERT(varbinary(max),'')), 'DECLARATION', 'PRESENT', a.content_object_pk
FROM #parsed p JOIN source.source_appearance a ON a.source_appearance_pk=p.source_appearance_pk
WHERE NOT EXISTS (SELECT 1 FROM source.source_observation o WHERE o.source_appearance_pk=p.source_appearance_pk AND o.locator=N'' AND o.observation_kind='DECLARATION');
INSERT source.source_lineage (semantic_object_definition_pk, member_kind, canonical_pointer, source_observation_pk, mapping_rule_pk, contribution_role)
SELECT DISTINCT d.semantic_object_definition_pk, 'feature_version', N'', o.source_observation_pk, @rule, 'DECLARATION'
FROM #parsed p JOIN model.feature_version fv ON fv.feature_pk=p.feature_pk AND fv.source_profile='parsed-feature-declaration.v1'
JOIN model.semantic_object_definition d ON d.semantic_object_pk=fv.semantic_object_pk AND d.definition_digest=fv.definition_digest
JOIN source.source_observation o ON o.source_appearance_pk=p.source_appearance_pk AND o.locator=N'' AND o.observation_kind='DECLARATION'
WHERE NOT EXISTS (SELECT 1 FROM source.source_lineage l WHERE l.semantic_object_definition_pk=d.semantic_object_definition_pk AND l.member_kind='feature_version' AND l.canonical_pointer=N'' AND l.source_observation_pk=o.source_observation_pk AND l.mapping_rule_pk=@rule);

-- unresolved faces on the selected model
IF OBJECT_ID('tempdb..#unres') IS NOT NULL DROP TABLE #unres;
SELECT c.capability_id, c.capability_pk, ec.capability_version_pk, s.scenario_id, s.scenario_pk, sv.scenario_version_pk,
       i.contract_reference_state, e.authority_reference_state,
       tg.declared_contract, tg.declared_authority, p.source_appearance_pk
INTO #unres
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk AND n.namespace_id='sidefx:capabilities'
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk=sv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk=sd.canonical_content_pk
JOIN #parsed p ON p.capability_pk=ec.capability_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk=sv.scenario_version_pk
OUTER APPLY (SELECT MAX(CASE WHEN j.[key]='input-contract' THEN JSON_VALUE(j.value,'$[0]') END) COLLATE Latin1_General_100_BIN2 AS declared_contract,
                    MAX(CASE WHEN j.[key]='event-authority' THEN JSON_VALUE(j.value,'$[0]') END) COLLATE Latin1_General_100_BIN2 AS declared_authority
  FROM OPENJSON(CONVERT(varchar(max), co.content_bytes),'$.semantics.tags') j) tg
WHERE ec.estate_model_pk=@from AND (i.contract_reference_state='UNRESOLVED' OR e.authority_reference_state='UNRESOLVED');

-- materialize missing contracts
IF OBJECT_ID('tempdb..#missing_contract') IS NOT NULL DROP TABLE #missing_contract;
SELECT DISTINCT u.declared_contract AS contract_id INTO #missing_contract FROM #unres u
WHERE u.contract_reference_state='UNRESOLVED' AND u.declared_contract IS NOT NULL AND NOT EXISTS (SELECT 1 FROM model.contract c WHERE c.contract_id=u.declared_contract);
DECLARE @contract_ns bigint=(SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind='CONTRACT' AND namespace_id='sidefx:contracts');
IF @contract_ns IS NULL BEGIN INSERT model.identity_namespace (namespace_kind, namespace_id) VALUES ('CONTRACT','sidefx:contracts'); SET @contract_ns=(SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind='CONTRACT' AND namespace_id='sidefx:contracts'); END;
INSERT model.semantic_object (object_kind, namespace_pk, declared_id)
SELECT 'CONTRACT', @contract_ns, mc.contract_id FROM #missing_contract mc WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object so WHERE so.namespace_pk=@contract_ns AND so.declared_id=mc.contract_id);
IF OBJECT_ID('tempdb..#cdef') IS NOT NULL DROP TABLE #cdef;
CREATE TABLE #cdef (contract_id nvarchar(400) COLLATE Latin1_General_100_BIN2, semantic_object_pk bigint, envelope_bytes varbinary(max), definition_digest binary(32));
INSERT #cdef (contract_id, semantic_object_pk) SELECT mc.contract_id, so.semantic_object_pk FROM #missing_contract mc JOIN model.semantic_object so ON so.namespace_pk=@contract_ns AND so.declared_id=mc.contract_id AND so.object_kind='CONTRACT';
UPDATE #cdef SET envelope_bytes=CONVERT(varbinary(max),CONVERT(varchar(max),'{"address":{"id":"'+contract_id+'","kind":"CONTRACT","namespace":"sidefx:contracts"},"format":"sidefx-semantic-definition.v1","semantics":{"schema_digest":null}}'));
UPDATE #cdef SET definition_digest=HASHBYTES('SHA2_256',envelope_bytes);
INSERT source.content_object (content_digest, content_bytes, byte_length) SELECT DISTINCT definition_digest, envelope_bytes, DATALENGTH(envelope_bytes) FROM #cdef d WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=d.definition_digest);
INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk) SELECT DISTINCT d.semantic_object_pk,'CONTRACT',d.definition_digest,co.content_object_pk FROM #cdef d JOIN source.content_object co ON co.content_digest=d.definition_digest WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=d.semantic_object_pk AND x.definition_digest=d.definition_digest);
INSERT model.contract (namespace_pk, contract_id, semantic_object_pk, object_kind) SELECT @contract_ns,d.contract_id,d.semantic_object_pk,'CONTRACT' FROM #cdef d WHERE NOT EXISTS (SELECT 1 FROM model.contract c WHERE c.namespace_pk=@contract_ns AND c.contract_id=d.contract_id);
INSERT model.contract_version (contract_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest, name, contract_kind, schema_object_pk, schema_reference_state, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT c.contract_pk,d.semantic_object_pk,sod.semantic_object_definition_pk,d.definition_digest,NULL,NULL,NULL,'ABSENT','CONTRACT',sod.semantic_object_definition_pk,N''
FROM #cdef d JOIN model.contract c ON c.namespace_pk=@contract_ns AND c.contract_id=d.contract_id JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=d.semantic_object_pk AND sod.definition_digest=d.definition_digest;

-- materialize missing authorities
IF OBJECT_ID('tempdb..#missing_authority') IS NOT NULL DROP TABLE #missing_authority;
SELECT DISTINCT u.capability_id, u.scenario_id, u.declared_authority AS authority_id INTO #missing_authority FROM #unres u
WHERE u.authority_reference_state='UNRESOLVED' AND u.declared_authority IS NOT NULL AND NOT EXISTS (SELECT 1 FROM model.execution_authority ea WHERE ea.execution_authority_id=u.declared_authority);
IF OBJECT_ID('tempdb..#adef') IS NOT NULL DROP TABLE #adef;
CREATE TABLE #adef (capability_id nvarchar(400) COLLATE Latin1_General_100_BIN2, scenario_id nvarchar(400) COLLATE Latin1_General_100_BIN2, authority_id nvarchar(400) COLLATE Latin1_General_100_BIN2, namespace_pk bigint, semantic_object_pk bigint, envelope_bytes varbinary(max), definition_digest binary(32));
INSERT #adef (capability_id, scenario_id, authority_id) SELECT DISTINCT capability_id, scenario_id, authority_id FROM #missing_authority;
INSERT model.identity_namespace (namespace_kind, namespace_id) SELECT DISTINCT 'EXECUTION_AUTHORITY','sidefx:capability:'+a.capability_id FROM #adef a WHERE NOT EXISTS (SELECT 1 FROM model.identity_namespace x WHERE x.namespace_kind='EXECUTION_AUTHORITY' AND x.namespace_id='sidefx:capability:'+a.capability_id);
UPDATE a SET namespace_pk=x.namespace_pk FROM #adef a JOIN model.identity_namespace x ON x.namespace_kind='EXECUTION_AUTHORITY' AND x.namespace_id='sidefx:capability:'+a.capability_id;
INSERT model.semantic_object (object_kind, namespace_pk, declared_id) SELECT DISTINCT 'EXECUTION_AUTHORITY',a.namespace_pk,a.authority_id FROM #adef a WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object so WHERE so.namespace_pk=a.namespace_pk AND so.declared_id=a.authority_id AND so.object_kind='EXECUTION_AUTHORITY');
UPDATE a SET semantic_object_pk=so.semantic_object_pk FROM #adef a JOIN model.semantic_object so ON so.namespace_pk=a.namespace_pk AND so.declared_id=a.authority_id AND so.object_kind='EXECUTION_AUTHORITY';
UPDATE #adef SET envelope_bytes=CONVERT(varbinary(max),CONVERT(varchar(max),'{"address":{"id":"'+authority_id+'","kind":"EXECUTION_AUTHORITY","namespace":"sidefx:capability:'+capability_id+'"},"format":"sidefx-semantic-definition.v1","semantics":{"authority":{"id":"'+authority_id+'","operations":[],"owningScenarioId":"'+scenario_id+'"}}}'));
UPDATE #adef SET definition_digest=HASHBYTES('SHA2_256',envelope_bytes);
INSERT source.content_object (content_digest, content_bytes, byte_length) SELECT DISTINCT definition_digest, envelope_bytes, DATALENGTH(envelope_bytes) FROM #adef d WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=d.definition_digest);
INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk) SELECT DISTINCT d.semantic_object_pk,'EXECUTION_AUTHORITY',d.definition_digest,co.content_object_pk FROM #adef d JOIN source.content_object co ON co.content_digest=d.definition_digest WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=d.semantic_object_pk AND x.definition_digest=d.definition_digest);
INSERT model.execution_authority (namespace_pk, execution_authority_id, semantic_object_pk, object_kind) SELECT DISTINCT a.namespace_pk,a.authority_id,a.semantic_object_pk,'EXECUTION_AUTHORITY' FROM #adef a WHERE NOT EXISTS (SELECT 1 FROM model.execution_authority ea WHERE ea.namespace_pk=a.namespace_pk AND ea.execution_authority_id=a.authority_id);
INSERT model.execution_authority_version (execution_authority_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest, authority_profile, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT ea.execution_authority_pk,a.semantic_object_pk,sod.semantic_object_definition_pk,a.definition_digest,'execution-authorities.v1','EXECUTION_AUTHORITY',sod.semantic_object_definition_pk,N''
FROM #adef a JOIN model.execution_authority ea ON ea.namespace_pk=a.namespace_pk AND ea.execution_authority_id=a.authority_id JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=a.semantic_object_pk AND sod.definition_digest=a.definition_digest
WHERE NOT EXISTS (SELECT 1 FROM model.execution_authority_version x WHERE x.execution_authority_pk=ea.execution_authority_pk AND x.definition_digest=a.definition_digest);

-- resolved targets per affected scenario
IF OBJECT_ID('tempdb..#contract_res') IS NOT NULL DROP TABLE #contract_res;
SELECT contract_id, MAX(contract_version_pk) AS contract_version_pk INTO #contract_res FROM (
  SELECT c.contract_id, cv.contract_version_pk FROM model.contract c JOIN model.contract_version cv ON cv.contract_pk=c.contract_pk
    JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=cv.semantic_object_definition_pk AND ed.estate_model_pk=@from
  UNION ALL SELECT c.contract_id, cv.contract_version_pk FROM model.contract c JOIN model.contract_version cv ON cv.contract_pk=c.contract_pk WHERE c.contract_id IN (SELECT contract_id FROM #cdef)
) x GROUP BY contract_id;
IF OBJECT_ID('tempdb..#authority_res') IS NOT NULL DROP TABLE #authority_res;
SELECT ea.execution_authority_id AS authority_id, MAX(eav.execution_authority_version_pk) AS authority_version_pk INTO #authority_res
FROM model.execution_authority ea JOIN model.execution_authority_version eav ON eav.execution_authority_pk=ea.execution_authority_pk
WHERE ea.execution_authority_id IN (SELECT authority_id FROM #adef) GROUP BY ea.execution_authority_id;

-- Re-version only the capabilities whose selected scenario lacks an authored spec
-- while an authored scenario_version already exists for the same scenario.
IF OBJECT_ID('tempdb..#reversion') IS NOT NULL DROP TABLE #reversion;
SELECT ec.capability_pk, ec.capability_version_pk AS old_capver, cv.semantic_object_pk AS cap_semantic_object_pk,
       cv.name AS cap_name, cv.actor, cv.intent, cv.outcome, cv.experience_id, cv.experience_actor, cv.experience_promise,
       cs.scenario_pk, s.scenario_id, cs.scenario_version_pk AS old_scnver,
       (SELECT MAX(au.scenario_version_pk) FROM model.scenario_version au
          JOIN model.semantic_object_definition aud ON aud.semantic_object_definition_pk=au.semantic_object_definition_pk
          JOIN source.content_object auc ON auc.content_object_pk=aud.canonical_content_pk
          WHERE au.scenario_pk=cs.scenario_pk AND JSON_QUERY(CONVERT(varchar(max),auc.content_bytes),'$.semantics.scenario') IS NOT NULL) AS authored_scnver,
       JSON_QUERY(CONVERT(varchar(max),co.content_bytes),'$.address') AS cap_address_json,
       JSON_QUERY(CONVERT(varchar(max),co.content_bytes),'$.semantics') AS cap_semantics_json,
       (SELECT COUNT(*) FROM model.capability_root_scenario r WHERE r.capability_version_pk=ec.capability_version_pk AND r.scenario_pk=cs.scenario_pk) AS is_root
INTO #reversion
FROM model.estate_capability ec
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk=sv.semantic_object_definition_pk
JOIN source.content_object sc ON sc.content_object_pk=sd.canonical_content_pk
JOIN model.capability_version cv ON cv.capability_version_pk=ec.capability_version_pk
JOIN model.semantic_object_definition cd ON cd.semantic_object_definition_pk=cv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk=cd.canonical_content_pk
WHERE ec.estate_model_pk=@from AND JSON_QUERY(CONVERT(varchar(max),sc.content_bytes),'$.semantics.scenario') IS NULL;
DELETE FROM #reversion WHERE authored_scnver IS NULL OR authored_scnver=old_scnver;
ALTER TABLE #reversion ADD new_envelope varchar(max), new_digest binary(32), new_sod bigint, new_capver bigint;
UPDATE #reversion SET new_envelope = '{"address":'+cap_address_json+',"format":"sidefx-semantic-definition.v1","semantics":'
  + LEFT(cap_semantics_json, LEN(cap_semantics_json)-1) + ',"scenario_version_pins":{"'+scenario_id COLLATE DATABASE_DEFAULT+'":'+CONVERT(varchar(20),authored_scnver)+'}}';
UPDATE #reversion SET new_digest = HASHBYTES('SHA2_256', CONVERT(varbinary(max), CONVERT(varchar(max), new_envelope)));
INSERT source.content_object (content_digest, content_bytes, byte_length)
SELECT DISTINCT new_digest, CONVERT(varbinary(max),CONVERT(varchar(max),new_envelope)), DATALENGTH(CONVERT(varbinary(max),CONVERT(varchar(max),new_envelope))) FROM #reversion r
WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=r.new_digest);
INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
SELECT DISTINCT r.cap_semantic_object_pk,'CAPABILITY',r.new_digest,co.content_object_pk FROM #reversion r JOIN source.content_object co ON co.content_digest=r.new_digest
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=r.cap_semantic_object_pk AND x.definition_digest=r.new_digest);
UPDATE r SET new_sod=sod.semantic_object_definition_pk FROM #reversion r JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=r.cap_semantic_object_pk AND sod.definition_digest=r.new_digest;
INSERT model.capability_version (capability_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest, name, actor, intent, outcome, experience_id, experience_actor, experience_promise, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT r.capability_pk, r.cap_semantic_object_pk, r.new_sod, r.new_digest, r.cap_name, r.actor, r.intent, r.outcome, r.experience_id, r.experience_actor, r.experience_promise, 'CAPABILITY', r.new_sod, N''
FROM #reversion r WHERE NOT EXISTS (SELECT 1 FROM model.capability_version x WHERE x.capability_pk=r.capability_pk AND x.definition_digest=r.new_digest);
UPDATE r SET new_capver=cv2.capability_version_pk FROM #reversion r JOIN model.capability_version cv2 ON cv2.capability_pk=r.capability_pk AND cv2.definition_digest=r.new_digest;
INSERT model.capability_scenario (capability_pk, capability_version_pk, scenario_pk, scenario_version_pk, _owner_definition_pk, _canonical_pointer)
SELECT r.capability_pk, r.new_capver, r.scenario_pk, r.authored_scnver, r.new_sod, '/semantics/scenario_version_pins/'+r.scenario_id
FROM #reversion r WHERE NOT EXISTS (SELECT 1 FROM model.capability_scenario x WHERE x.capability_version_pk=r.new_capver AND x.scenario_pk=r.scenario_pk);
INSERT model.capability_root_scenario (capability_version_pk, scenario_pk, _owner_definition_pk, _canonical_pointer)
SELECT r.new_capver, r.scenario_pk, r.new_sod, N'' FROM #reversion r WHERE r.is_root>0
  AND NOT EXISTS (SELECT 1 FROM model.capability_root_scenario x WHERE x.capability_version_pk=r.new_capver);

-- build fresh faces owned by the authored scenario version
IF OBJECT_ID('tempdb..#revface') IS NOT NULL DROP TABLE #revface;
SELECT r.capability_pk, r.scenario_pk, r.authored_scnver, r.old_scnver,
       LOWER(CONVERT(varchar(64), asv.definition_digest,2)) AS authored_scn_hex,
       si.input_id, si.semantic_object_pk AS input_sop, si.contract_reference_state AS input_state, si.input_contract_version_pk,
       LOWER(CONVERT(varchar(64), icv.definition_digest,2)) AS input_target_hex,
       JSON_QUERY(CONVERT(varchar(max), inb.content_bytes),'$.address') AS input_address,
       se.event_id, se.semantic_object_pk AS event_sop, se.authority_reference_state AS event_state, se.execution_authority_version_pk,
       LOWER(CONVERT(varchar(64), eav.definition_digest,2)) AS event_target_hex,
       JSON_QUERY(CONVERT(varchar(max), evb.content_bytes),'$.address') AS event_address,
       so.outcome_id, so.semantic_object_pk AS outcome_sop, so.experience, so.terminal, so.terminal_disposition,
       JSON_QUERY(CONVERT(varchar(max), oub.content_bytes),'$.address') AS outcome_address
INTO #revface
FROM #reversion r
JOIN model.scenario_version asv ON asv.scenario_version_pk=r.authored_scnver
JOIN model.scenario_input si ON si.scenario_version_pk=r.old_scnver
JOIN model.contract_version icv ON icv.contract_version_pk=si.input_contract_version_pk
JOIN model.semantic_object_definition ind ON ind.semantic_object_definition_pk=si.semantic_object_definition_pk
JOIN source.content_object inb ON inb.content_object_pk=ind.canonical_content_pk
JOIN model.scenario_event se ON se.scenario_version_pk=r.old_scnver
JOIN model.execution_authority_version eav ON eav.execution_authority_version_pk=se.execution_authority_version_pk
JOIN model.semantic_object_definition evd ON evd.semantic_object_definition_pk=se.semantic_object_definition_pk
JOIN source.content_object evb ON evb.content_object_pk=evd.canonical_content_pk
JOIN model.scenario_outcome so ON so.scenario_version_pk=r.old_scnver
JOIN model.semantic_object_definition oud ON oud.semantic_object_definition_pk=so.semantic_object_definition_pk
JOIN source.content_object oub ON oub.content_object_pk=oud.canonical_content_pk;
ALTER TABLE #revface ADD input_env varchar(max), input_dig binary(32), input_sod bigint,
                       event_env varchar(max), event_dig binary(32), event_sod bigint,
                       outcome_env varchar(max), outcome_dig binary(32), outcome_sod bigint;
UPDATE #revface SET input_env='{"address":'+input_address+',"format":"sidefx-semantic-definition.v1","semantics":{"id":"'+input_id COLLATE DATABASE_DEFAULT+'","owner_definition_digest":"'+authored_scn_hex+'","role":"input","target_definition_digest":"'+input_target_hex+'"}}';
UPDATE #revface SET event_env='{"address":'+event_address+',"format":"sidefx-semantic-definition.v1","semantics":{"id":"'+event_id COLLATE DATABASE_DEFAULT+'","owner_definition_digest":"'+authored_scn_hex+'","role":"event","target_definition_digest":"'+event_target_hex+'"}}';
UPDATE #revface SET outcome_env='{"address":'+outcome_address+',"format":"sidefx-semantic-definition.v1","semantics":{"id":"'+outcome_id COLLATE DATABASE_DEFAULT+'","owner_definition_digest":"'+authored_scn_hex+'","role":"outcome"}}';
UPDATE #revface SET input_dig=HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(varchar(max),input_env))),
                    event_dig=HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(varchar(max),event_env))),
                    outcome_dig=HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(varchar(max),outcome_env)));
INSERT source.content_object (content_digest, content_bytes, byte_length)
SELECT DISTINCT input_dig, CONVERT(varbinary(max),CONVERT(varchar(max),input_env)), DATALENGTH(CONVERT(varbinary(max),CONVERT(varchar(max),input_env))) FROM #revface r WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=r.input_dig)
UNION SELECT DISTINCT event_dig, CONVERT(varbinary(max),CONVERT(varchar(max),event_env)), DATALENGTH(CONVERT(varbinary(max),CONVERT(varchar(max),event_env))) FROM #revface r WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=r.event_dig)
UNION SELECT DISTINCT outcome_dig, CONVERT(varbinary(max),CONVERT(varchar(max),outcome_env)), DATALENGTH(CONVERT(varbinary(max),CONVERT(varchar(max),outcome_env))) FROM #revface r WHERE NOT EXISTS (SELECT 1 FROM source.content_object co WHERE co.content_digest=r.outcome_dig);
INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
SELECT DISTINCT r.input_sop,'SCENARIO_INPUT',r.input_dig,co.content_object_pk FROM #revface r JOIN source.content_object co ON co.content_digest=r.input_dig
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=r.input_sop AND x.definition_digest=r.input_dig)
UNION SELECT DISTINCT r.event_sop,'SCENARIO_EVENT',r.event_dig,co.content_object_pk FROM #revface r JOIN source.content_object co ON co.content_digest=r.event_dig
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=r.event_sop AND x.definition_digest=r.event_dig)
UNION SELECT DISTINCT r.outcome_sop,'SCENARIO_OUTCOME',r.outcome_dig,co.content_object_pk FROM #revface r JOIN source.content_object co ON co.content_digest=r.outcome_dig
WHERE NOT EXISTS (SELECT 1 FROM model.semantic_object_definition x WHERE x.semantic_object_pk=r.outcome_sop AND x.definition_digest=r.outcome_dig);
UPDATE r SET input_sod=sod.semantic_object_definition_pk FROM #revface r JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=r.input_sop AND sod.definition_digest=r.input_dig;
UPDATE r SET event_sod=sod.semantic_object_definition_pk FROM #revface r JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=r.event_sop AND sod.definition_digest=r.event_dig;
UPDATE r SET outcome_sod=sod.semantic_object_definition_pk FROM #revface r JOIN model.semantic_object_definition sod ON sod.semantic_object_pk=r.outcome_sop AND sod.definition_digest=r.outcome_dig;
INSERT model.scenario_input (scenario_version_pk, input_id, semantic_object_pk, semantic_object_definition_pk, namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer, input_contract_version_pk, contract_reference_state)
SELECT r.authored_scnver, r.input_id, r.input_sop, r.input_sod, so.namespace_pk, r.input_dig, 'SCENARIO_INPUT', r.input_sod, N'', r.input_contract_version_pk, r.input_state
FROM #revface r JOIN model.semantic_object so ON so.semantic_object_pk=r.input_sop
WHERE NOT EXISTS (SELECT 1 FROM model.scenario_input x WHERE x.scenario_version_pk=r.authored_scnver);
INSERT model.scenario_event (scenario_version_pk, event_id, responsibility, semantic_object_pk, semantic_object_definition_pk, namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer, execution_authority_version_pk, authority_reference_state)
SELECT r.authored_scnver, r.event_id, so.responsibility, r.event_sop, r.event_sod, so.namespace_pk, r.event_dig, 'SCENARIO_EVENT', r.event_sod, N'', r.execution_authority_version_pk, r.event_state
FROM #revface r JOIN model.scenario_event so ON so.scenario_version_pk=r.old_scnver
WHERE NOT EXISTS (SELECT 1 FROM model.scenario_event x WHERE x.scenario_version_pk=r.authored_scnver);
INSERT model.scenario_outcome (scenario_version_pk, outcome_id, experience, terminal, terminal_disposition, semantic_object_pk, semantic_object_definition_pk, namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer)
SELECT r.authored_scnver, r.outcome_id, r.experience, r.terminal, r.terminal_disposition, r.outcome_sop, r.outcome_sod, so.namespace_pk, r.outcome_dig, 'SCENARIO_OUTCOME', r.outcome_sod, N''
FROM #revface r JOIN model.semantic_object so ON so.semantic_object_pk=r.outcome_sop
WHERE NOT EXISTS (SELECT 1 FROM model.scenario_outcome x WHERE x.scenario_version_pk=r.authored_scnver);

-- new generation (built before the overlay so estate_model_pk exists)
DECLARE @manifest binary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),'canonical-feature-generation:'+CONVERT(varchar(20),@from)));
INSERT source.estate_model (estate_snapshot_pk, mapping_manifest_digest, publication_state) VALUES (@snap,@manifest,'BUILDING');
DECLARE @to bigint=CAST(SCOPE_IDENTITY() AS bigint);
INSERT source.estate_model_rule (estate_model_pk, mapping_rule_pk) SELECT @to, mapping_rule_pk FROM source.estate_model_rule WHERE estate_model_pk=@from;
INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT @to, ed.semantic_object_definition_pk FROM model.estate_definition ed WHERE ed.estate_model_pk=@from
  AND NOT EXISTS (SELECT 1 FROM model.estate_definition e2 WHERE e2.estate_model_pk=@to AND e2.semantic_object_definition_pk=ed.semantic_object_definition_pk);
INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
SELECT @to, ec.capability_pk, ec.capability_version_pk, ec.semantic_object_definition_pk FROM model.estate_capability ec
WHERE ec.estate_model_pk=@from AND ec.capability_pk NOT IN (SELECT capability_pk FROM #reversion);
INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT @to, r.new_sod FROM #reversion r WHERE NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=r.new_sod);
INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
SELECT @to, r.capability_pk, r.new_capver, r.new_sod FROM #reversion r;
INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
SELECT @to, d.semantic_object_definition_pk FROM model.feature_version fv JOIN model.semantic_object_definition d ON d.semantic_object_pk=fv.semantic_object_pk AND d.definition_digest=fv.definition_digest
WHERE fv.source_profile='parsed-feature-declaration.v1' AND NOT EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@to AND ed.semantic_object_definition_pk=d.semantic_object_definition_pk);
INSERT model.estate_capability_feature (estate_model_pk, capability_pk, capability_version_pk, feature_version_pk, binding_role)
SELECT @to, cf.capability_pk, cf.capability_version_pk, fvn.feature_version_pk, 'CANONICAL' FROM model.capability_feature cf
JOIN model.feature_version fv ON fv.feature_version_pk=cf.feature_version_pk
JOIN model.feature_version fvn ON fvn.feature_pk=fv.feature_pk AND fvn.source_profile='parsed-feature-declaration.v1'
WHERE cf.binding_role='CANONICAL' AND cf.capability_pk NOT IN (SELECT capability_pk FROM #reversion);
INSERT model.estate_capability_feature (estate_model_pk, capability_pk, capability_version_pk, feature_version_pk, binding_role)
SELECT @to, r.capability_pk, r.new_capver, fvn.feature_version_pk, 'CANONICAL' FROM #reversion r
JOIN model.feature f ON f.capability_pk=r.capability_pk
JOIN model.feature_version fvn ON fvn.feature_pk=f.feature_pk AND fvn.source_profile='parsed-feature-declaration.v1';

-- pin the parsed feature versions to the generation's selected scenarios
INSERT model.feature_scenario (feature_version_pk, scenario_pk, scenario_version_pk, capability_pk, ordinal)
SELECT fvn.feature_version_pk, cs.scenario_pk, cs.scenario_version_pk, f.capability_pk,
       ROW_NUMBER() OVER (PARTITION BY f.capability_pk ORDER BY s.scenario_id)-1
FROM model.feature_version fvn
JOIN model.feature f ON f.feature_pk=fvn.feature_pk
JOIN model.estate_capability ec ON ec.estate_model_pk=@to AND ec.capability_pk=f.capability_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
WHERE fvn.source_profile='parsed-feature-declaration.v1'
  AND NOT EXISTS (SELECT 1 FROM model.feature_scenario x WHERE x.feature_version_pk=fvn.feature_version_pk AND x.scenario_pk=cs.scenario_pk);

-- 5. resolve the affected faces for this generation
INSERT model.estate_scenario_face_resolution (estate_model_pk, scenario_version_pk, role, contract_version_pk, execution_authority_version_pk, resolution_state)
SELECT @to, COALESCE(rv.authored_scnver, u.scenario_version_pk), 'input', cr.contract_version_pk, NULL, 'RESOLVED'
FROM #unres u JOIN #contract_res cr ON cr.contract_id=u.declared_contract
LEFT JOIN #reversion rv ON rv.capability_pk=u.capability_pk AND rv.scenario_pk=u.scenario_pk
WHERE u.contract_reference_state='UNRESOLVED'
UNION ALL
SELECT @to, COALESCE(rv.authored_scnver, u.scenario_version_pk), 'event', NULL, ar.authority_version_pk, 'RESOLVED'
FROM #unres u JOIN #authority_res ar ON ar.authority_id=u.declared_authority
LEFT JOIN #reversion rv ON rv.capability_pk=u.capability_pk AND rv.scenario_pk=u.scenario_pk
WHERE u.authority_reference_state='UNRESOLVED';

-- findings
INSERT analysis.integrity_rule (rule_id, rule_digest, layer, rule_content_pk)
SELECT 'canonical-feature-reference-reconciliation.v1', HASHBYTES('SHA2_256',CONVERT(varbinary(max),'canonical-feature-reference-reconciliation.v1')), 1, (SELECT TOP 1 content_object_pk FROM source.content_object ORDER BY content_object_pk)
WHERE NOT EXISTS (SELECT 1 FROM analysis.integrity_rule WHERE rule_id='canonical-feature-reference-reconciliation.v1');
DECLARE @rr_rule bigint=(SELECT integrity_rule_pk FROM analysis.integrity_rule WHERE rule_id='canonical-feature-reference-reconciliation.v1');
INSERT analysis.assessment (estate_model_pk, integrity_rule_pk, assessment_kind, scope_digest, input_set_digest, evaluation_state, evaluated_at)
VALUES (@to,@rr_rule,'INTEGRITY',CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(varchar(20),@to))),CONVERT(binary(32),HASHBYTES('SHA2_256','reference-reconciliation')),'EVALUATED',SYSUTCDATETIME());
DECLARE @rr_assessment bigint=CAST(SCOPE_IDENTITY() AS bigint);
INSERT analysis.integrity_finding (assessment_pk, finding_digest, finding_code, severity, source_observation_pk, subject_definition_pk, expected_content_pk, observed_content_pk, message)
SELECT @rr_assessment, CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(varchar(400),c.contract_id+'/VERSION_DEFINITION_CONFLICT'))), 'VERSION_DEFINITION_CONFLICT','WARNING',NULL,NULL,NULL,NULL,
       'Contract id '+c.contract_id+' has '+CONVERT(varchar(10),COUNT(*))+' selected definitions.'
FROM model.contract c JOIN model.contract_version cv ON cv.contract_pk=c.contract_pk
JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=cv.semantic_object_definition_pk AND ed.estate_model_pk=@from
WHERE c.contract_id IN ('governed-feature-authoring-context.v1','governed-agent-execution-context.v1') GROUP BY c.contract_id HAVING COUNT(*)>1;

-- ===== verification (detail) =====

-- V1. Coverage summary.
SELECT 'coverage_summary' AS section, @from AS predecessor, @to AS candidate,
       (SELECT COUNT(*) FROM model.estate_capability WHERE estate_model_pk=@to) AS capabilities,
       (SELECT COUNT(*) FROM model.estate_capability ec WHERE ec.estate_model_pk=@to
          AND NOT EXISTS (SELECT 1 FROM model.estate_capability_feature f WHERE f.estate_model_pk=@to AND f.capability_pk=ec.capability_pk)) AS capabilities_without_binding,
       (SELECT COUNT(*) FROM model.estate_capability_feature WHERE estate_model_pk=@to) AS feature_bindings,
       (SELECT COUNT(*) FROM model.feature_version WHERE source_profile='parsed-feature-declaration.v1') AS parsed_feature_versions,
       (SELECT COUNT(*) FROM model.feature_scenario fs
          JOIN model.feature_version fv ON fv.feature_version_pk=fs.feature_version_pk
          WHERE fv.source_profile='parsed-feature-declaration.v1') AS pinned_scenarios,
       (SELECT COUNT(*) FROM #missing_contract) AS materialized_contracts,
       (SELECT COUNT(*) FROM #missing_authority) AS materialized_authorities,
       (SELECT COUNT(*) FROM model.estate_scenario_face_resolution WHERE estate_model_pk=@to) AS face_resolutions,
       (SELECT COUNT(*) FROM analysis.integrity_finding WHERE assessment_pk=@rr_assessment AND finding_code='VERSION_DEFINITION_CONFLICT') AS conflicts;

-- V2. One row per selected capability: generation-scoped feature binding and coverage.
SELECT 'capability_feature' AS section, c.capability_id, n.namespace_id,
       ec.capability_version_pk, LOWER(CONVERT(varchar(64),cv.definition_digest,2)) AS capability_digest,
       ef.binding_role, f.feature_pk, f.feature_id, ef.feature_version_pk,
       LOWER(CONVERT(varchar(64),fv.definition_digest,2)) AS feature_digest, fv.source_profile,
       JSON_VALUE(CONVERT(varchar(max),co.content_bytes),'$.semantics.source_path') AS feature_source_path,
       JSON_VALUE(CONVERT(varchar(max),co.content_bytes),'$.semantics.source_class') AS feature_source_class,
       JSON_VALUE(CONVERT(varchar(max),co.content_bytes),'$.semantics.content_digest') AS feature_content_digest,
       JSON_VALUE(CONVERT(varchar(max),co.content_bytes),'$.semantics.name') AS feature_name,
       (SELECT COUNT(*) FROM model.feature_scenario fs WHERE fs.feature_version_pk=ef.feature_version_pk) AS pinned_scenarios,
       (SELECT COUNT(*) FROM model.capability_scenario cs WHERE cs.capability_version_pk=ec.capability_version_pk) AS selected_scenarios,
       (SELECT COUNT(*) FROM model.capability_scenario cs JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
          JOIN model.semantic_object_definition d2 ON d2.semantic_object_definition_pk=sv.semantic_object_definition_pk
          JOIN source.content_object c2 ON c2.content_object_pk=d2.canonical_content_pk
          WHERE cs.capability_version_pk=ec.capability_version_pk AND JSON_QUERY(CONVERT(varchar(max),c2.content_bytes),'$.semantics.scenario') IS NOT NULL) AS authored_specs,
       CASE WHEN EXISTS (SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk=ec.capability_version_pk
                         EXCEPT SELECT fs2.scenario_pk FROM model.feature_scenario fs2 WHERE fs2.feature_version_pk=ef.feature_version_pk)
              OR EXISTS (SELECT fs2.scenario_pk FROM model.feature_scenario fs2 WHERE fs2.feature_version_pk=ef.feature_version_pk
                         EXCEPT SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk=ec.capability_version_pk)
            THEN 'MISMATCH' ELSE 'MATCH' END AS scenario_set_match
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk
JOIN model.capability_version cv ON cv.capability_version_pk=ec.capability_version_pk
LEFT JOIN model.estate_capability_feature ef ON ef.estate_model_pk=ec.estate_model_pk AND ef.capability_pk=ec.capability_pk
LEFT JOIN model.feature_version fv ON fv.feature_version_pk=ef.feature_version_pk
LEFT JOIN model.feature f ON f.feature_pk=fv.feature_pk
LEFT JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=fv.semantic_object_definition_pk
LEFT JOIN source.content_object co ON co.content_object_pk=d.canonical_content_pk
WHERE ec.estate_model_pk=@to AND n.namespace_id='sidefx:capabilities'
ORDER BY c.capability_id;

-- V3. One row per selected scenario face: base state, generation resolution, effective state, authored spec.
SELECT 'scenario_face' AS section, c.capability_id, s.scenario_id, ec.capability_version_pk, sv.scenario_version_pk,
       i.input_id, ic.contract_id AS base_input_contract, i.contract_reference_state AS base_input_state,
       orc.contract_id AS resolved_input_contract, CASE WHEN ri.scenario_version_pk IS NOT NULL THEN 'RESOLVED' ELSE i.contract_reference_state END AS effective_input_state,
       e.event_id, ea.execution_authority_id AS base_event_authority, e.authority_reference_state AS base_event_state,
       ora.execution_authority_id AS resolved_event_authority, CASE WHEN re.scenario_version_pk IS NOT NULL THEN 'RESOLVED' ELSE e.authority_reference_state END AS effective_event_state,
       o.outcome_id, o.terminal, o.terminal_disposition,
       CASE WHEN JSON_QUERY(CONVERT(varchar(max),co.content_bytes),'$.semantics.scenario') IS NOT NULL THEN 1 ELSE 0 END AS has_authored_spec,
       (SELECT COUNT(*) FROM OPENJSON(CONVERT(varchar(max),co.content_bytes),'$.semantics.scenario.steps')) AS step_count
FROM model.estate_capability ec
JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk AND n.namespace_id='sidefx:capabilities'
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk=sv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk=sd.canonical_content_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.contract_version icv ON icv.contract_version_pk=i.input_contract_version_pk
LEFT JOIN model.contract ic ON ic.contract_pk=icv.contract_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.execution_authority_version eav ON eav.execution_authority_version_pk=e.execution_authority_version_pk
LEFT JOIN model.execution_authority ea ON ea.execution_authority_pk=eav.execution_authority_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.estate_scenario_face_resolution ri ON ri.estate_model_pk=ec.estate_model_pk AND ri.scenario_version_pk=sv.scenario_version_pk AND ri.role='input'
LEFT JOIN model.contract_version icvr ON icvr.contract_version_pk=ri.contract_version_pk
LEFT JOIN model.contract orc ON orc.contract_pk=icvr.contract_pk
LEFT JOIN model.estate_scenario_face_resolution re ON re.estate_model_pk=ec.estate_model_pk AND re.scenario_version_pk=sv.scenario_version_pk AND re.role='event'
LEFT JOIN model.execution_authority_version eavr ON eavr.execution_authority_version_pk=re.execution_authority_version_pk
LEFT JOIN model.execution_authority ora ON ora.execution_authority_pk=eavr.execution_authority_pk
WHERE ec.estate_model_pk=@to
ORDER BY c.capability_id, s.scenario_id;

-- V4. Materialized declarations (contracts with absent schema, authorities with no operations).
SELECT 'materialized_contract' AS section, c.contract_id AS declared_id, n.namespace_id, cv.schema_reference_state AS declaration_state,
       LOWER(CONVERT(varchar(64),cv.definition_digest,2)) AS definition_digest
FROM model.contract c JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk
JOIN model.contract_version cv ON cv.contract_pk=c.contract_pk
WHERE c.contract_id IN (SELECT contract_id FROM #missing_contract)
UNION ALL
SELECT 'materialized_authority', ea.execution_authority_id, n.namespace_id, eav.authority_profile,
       LOWER(CONVERT(varchar(64),eav.definition_digest,2))
FROM model.execution_authority ea JOIN model.identity_namespace n ON n.namespace_pk=ea.namespace_pk
JOIN model.execution_authority_version eav ON eav.execution_authority_pk=ea.execution_authority_pk
WHERE ea.execution_authority_id IN (SELECT authority_id FROM #missing_authority);

-- V5. Gaps: anything still not covered (expect empty except any known authored-spec gap).
SELECT 'gap_unbound_capability' AS section, c.capability_id AS subject, NULL AS detail
FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk
WHERE ec.estate_model_pk=@to
  AND NOT EXISTS (SELECT 1 FROM model.estate_capability_feature f WHERE f.estate_model_pk=@to AND f.capability_pk=ec.capability_pk)
UNION ALL
SELECT 'gap_unresolved_input', c.capability_id, s.scenario_id
FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.estate_scenario_face_resolution ri ON ri.estate_model_pk=@to AND ri.scenario_version_pk=sv.scenario_version_pk AND ri.role='input'
WHERE ec.estate_model_pk=@to AND (i.scenario_version_pk IS NULL OR (i.contract_reference_state<>'RESOLVED' AND ri.scenario_version_pk IS NULL))
UNION ALL
SELECT 'gap_unresolved_event', c.capability_id, s.scenario_id
FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk=sv.scenario_version_pk
LEFT JOIN model.estate_scenario_face_resolution re ON re.estate_model_pk=@to AND re.scenario_version_pk=sv.scenario_version_pk AND re.role='event'
WHERE ec.estate_model_pk=@to AND (e.scenario_version_pk IS NULL OR (e.authority_reference_state NOT IN ('RESOLVED','ABSENT','NOT_APPLICABLE') AND re.scenario_version_pk IS NULL))
UNION ALL
SELECT 'gap_scenario_set_mismatch', c.capability_id, NULL
FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.estate_capability_feature ef ON ef.estate_model_pk=ec.estate_model_pk AND ef.capability_pk=ec.capability_pk
WHERE ec.estate_model_pk=@to AND (
  EXISTS (SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk=ec.capability_version_pk
          EXCEPT SELECT fs2.scenario_pk FROM model.feature_scenario fs2 WHERE fs2.feature_version_pk=ef.feature_version_pk)
  OR EXISTS (SELECT fs2.scenario_pk FROM model.feature_scenario fs2 WHERE fs2.feature_version_pk=ef.feature_version_pk
          EXCEPT SELECT cs.scenario_pk FROM model.capability_scenario cs WHERE cs.capability_version_pk=ec.capability_version_pk))
UNION ALL
SELECT 'gap_authored_spec', c.capability_id, s.scenario_id
FROM model.estate_capability ec JOIN model.capability c ON c.capability_pk=ec.capability_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=cs.scenario_version_pk
JOIN model.semantic_object_definition sd ON sd.semantic_object_definition_pk=sv.semantic_object_definition_pk
JOIN source.content_object co ON co.content_object_pk=sd.canonical_content_pk
WHERE ec.estate_model_pk=@to AND JSON_QUERY(CONVERT(varchar(max),co.content_bytes),'$.semantics.scenario') IS NULL;

ROLLBACK TRANSACTION;
-- COMMIT TRANSACTION;
-- EXEC source.validate_model @to;
-- EXEC source.publish_model @to;
