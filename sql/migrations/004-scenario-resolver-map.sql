-- Derived inspection only. No authority or provider selection is authored here.
CREATE OR ALTER VIEW analysis.v_selected_semantic_definition AS
SELECT ed.estate_model_pk,d.semantic_object_definition_pk,d.object_kind,
       s.namespace_pk,n.namespace_id,s.declared_id,d.definition_digest,
       CASE WHEN ISJSON(decoded.source_text)=1 THEN decoded.source_text END AS definition_json
FROM source.current_model cm
JOIN model.estate_definition ed ON ed.estate_model_pk=cm.estate_model_pk
JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=ed.semantic_object_definition_pk
JOIN model.semantic_object s ON s.semantic_object_pk=d.semantic_object_pk
JOIN model.identity_namespace n ON n.namespace_pk=s.namespace_pk
JOIN source.content_object c ON c.content_object_pk=d.canonical_content_pk
CROSS APPLY (SELECT CONVERT(nvarchar(max),CONVERT(varchar(max),c.content_bytes) COLLATE Latin1_General_100_BIN2_UTF8) COLLATE Latin1_General_100_BIN2 AS source_text) decoded;
GO
CREATE OR ALTER VIEW analysis.v_scenario_invocation_closure AS
WITH roots AS (
    SELECT ec.estate_model_pk,ec.capability_version_pk,cs.scenario_version_pk
    FROM source.current_model cm
    JOIN model.estate_capability ec ON ec.estate_model_pk=cm.estate_model_pk
    JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
), walk AS (
    SELECT r.estate_model_pk,r.capability_version_pk,r.scenario_version_pk AS selected_scenario_version_pk,
           r.scenario_version_pk AS downstream_scenario_version_pk,0 AS depth,
           CAST('/'+CONVERT(varchar(20),r.scenario_version_pk)+'/' AS varchar(max)) AS invocation_path,
           CAST(0 AS bit) AS cycle_detected
    FROM roots r
    UNION ALL
    SELECT w.estate_model_pk,w.capability_version_pk,w.selected_scenario_version_pk,
           i.target_scenario_version_pk,w.depth+1,
           CAST(w.invocation_path+CONVERT(varchar(20),i.target_scenario_version_pk)+'/' AS varchar(max)),
           CAST(CASE WHEN CHARINDEX('/'+CONVERT(varchar(20),i.target_scenario_version_pk)+'/',w.invocation_path)>0 THEN 1 ELSE 0 END AS bit)
    FROM walk w
    JOIN model.scenario_event e ON e.scenario_version_pk=w.downstream_scenario_version_pk
    JOIN model.execution_operation op ON op.execution_authority_version_pk=e.execution_authority_version_pk
    JOIN model.operation_scenario_invocation i ON i.execution_operation_pk=op.execution_operation_pk
    JOIN model.scenario_version sv ON sv.scenario_version_pk=i.target_scenario_version_pk
    JOIN model.estate_definition ed ON ed.estate_model_pk=w.estate_model_pk AND ed.semantic_object_definition_pk=sv.semantic_object_definition_pk
    WHERE w.cycle_detected=0
)
SELECT estate_model_pk,capability_version_pk,selected_scenario_version_pk,downstream_scenario_version_pk,
       MIN(depth) AS minimum_depth,MAX(CONVERT(int,cycle_detected)) AS cycle_detected
FROM walk
GROUP BY estate_model_pk,capability_version_pk,selected_scenario_version_pk,downstream_scenario_version_pk;
GO
CREATE OR ALTER FUNCTION analysis.declared_platform_implementations()
RETURNS @implementations TABLE (
    estate_model_pk bigint,capability_version_pk bigint,capability_definition_pk bigint,
    platform_capability_id nvarchar(400) COLLATE Latin1_General_100_BIN2,
    provider_definition_pk bigint,provider_id nvarchar(400) COLLATE Latin1_General_100_BIN2,
    target_language nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    declaration_status nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    implementation_id nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    conformance_ref nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    platform_definition_digest binary(32)
) AS BEGIN
DECLARE @declarations TABLE (
    estate_model_pk bigint,semantic_object_definition_pk bigint,
    declared_id nvarchar(400) COLLATE Latin1_General_100_BIN2,definition_digest binary(32),
    definition_json nvarchar(max) COLLATE Latin1_General_100_BIN2
);
INSERT @declarations
SELECT DISTINCT d.estate_model_pk,d.semantic_object_definition_pk,d.declared_id,d.definition_digest,d.definition_json
FROM model.provider_capability_implementation pi
JOIN model.capability_version cv ON cv.capability_version_pk=pi.capability_version_pk
JOIN analysis.v_selected_semantic_definition d ON d.semantic_object_definition_pk=cv.semantic_object_definition_pk;
INSERT @implementations
SELECT d.estate_model_pk,cv.capability_version_pk,d.semantic_object_definition_pk AS capability_definition_pk,
       d.declared_id AS platform_capability_id,pi.provider_definition_pk,p.provider_id,
       JSON_VALUE(d.definition_json,'$.semantics.projectionTarget') AS target_language,
       JSON_VALUE(d.definition_json,'$.semantics.status') AS declaration_status,
       JSON_VALUE(d.definition_json,'$.semantics.implementationRef') AS implementation_id,
       JSON_VALUE(d.definition_json,'$.semantics.conformanceRef') AS conformance_ref,
       d.definition_digest AS platform_definition_digest
FROM @declarations d
JOIN model.capability_version cv ON cv.semantic_object_definition_pk=d.semantic_object_definition_pk
JOIN model.provider_capability_implementation pi ON pi.capability_version_pk=cv.capability_version_pk
JOIN model.provider_definition pd ON pd.provider_definition_pk=pi.provider_definition_pk
JOIN analysis.v_selected_semantic_definition retained_provider ON retained_provider.semantic_object_definition_pk=pd.semantic_object_definition_pk AND retained_provider.estate_model_pk=d.estate_model_pk
JOIN model.provider p ON p.provider_pk=pd.provider_pk
WHERE JSON_VALUE(d.definition_json,'$.semantics.projectionTarget') IS NOT NULL;
RETURN;
END;
GO
CREATE OR ALTER VIEW analysis.v_declared_platform_implementation AS
SELECT * FROM analysis.declared_platform_implementations();
GO
CREATE OR ALTER VIEW analysis.v_declared_port_transformation AS
-- A reference is resolved only through the port's declared namespace AND exact
-- retained source entry in its capsule. Similar names are never aliases.
SELECT DISTINCT p.estate_model_pk,pv.port_version_pk,tv.transformation_version_pk,
       t.semantic_object_definition_pk AS transformation_definition_pk,
       JSON_VALUE(p.definition_json,'$.semantics.configuration.transformationAuthorityRef') AS authority_ref
FROM analysis.v_selected_semantic_definition p
JOIN model.port_version pv ON pv.semantic_object_definition_pk=p.semantic_object_definition_pk
JOIN analysis.v_selected_semantic_definition t ON t.estate_model_pk=p.estate_model_pk
 AND t.object_kind='TRANSFORMATION' AND t.namespace_id=p.namespace_id
 AND t.declared_id=JSON_VALUE(p.definition_json,'$.semantics.configuration.transformationId')
JOIN model.transformation_version tv ON tv.semantic_object_definition_pk=t.semantic_object_definition_pk
WHERE EXISTS (
    SELECT 1 FROM source.source_lineage pl
    JOIN source.source_observation po ON po.source_observation_pk=pl.source_observation_pk
    JOIN source.source_appearance pa ON pa.source_appearance_pk=po.source_appearance_pk
    JOIN source.source_lineage tl ON tl.semantic_object_definition_pk=t.semantic_object_definition_pk
    JOIN source.source_observation too ON too.source_observation_pk=tl.source_observation_pk
    JOIN source.source_appearance ta ON ta.source_appearance_pk=too.source_appearance_pk
    JOIN source.estate_model em ON em.estate_model_pk=p.estate_model_pk
    WHERE pl.semantic_object_definition_pk=p.semantic_object_definition_pk
      AND pa.estate_snapshot_pk=em.estate_snapshot_pk AND ta.estate_snapshot_pk=em.estate_snapshot_pk
      AND pa.capsule_digest=ta.capsule_digest
      AND ta.entry_id=JSON_VALUE(p.definition_json,'$.semantics.configuration.transformationAuthorityRef')
);
GO
CREATE OR ALTER FUNCTION analysis.scenario_transformation_mechanics(@transformation_version_pk bigint)
RETURNS TABLE AS RETURN (
WITH expression_nodes AS (
    SELECT n.transformation_version_pk,n.expression_node_pk,n.node_pointer,
           JSON_VALUE(CONCAT('{"op":',CONVERT(varchar(max),v.content_bytes),'}'),'$.op') COLLATE Latin1_General_100_BIN2 AS operation_name,
           md.semantic_object_definition_pk AS mechanic_definition_pk,md.definition_json
    FROM model.transformation_expression_node n
    JOIN model.transformation_expression_child c ON c.parent_node_pk=n.expression_node_pk AND c.member_name='op'
    JOIN model.transformation_expression_node atom ON atom.expression_node_pk=c.child_node_pk AND atom.node_kind='LITERAL'
    JOIN source.content_object v ON v.content_object_pk=atom.literal_content_pk
    LEFT JOIN analysis.v_selected_semantic_definition md ON md.object_kind='MECHANIC'
     AND JSON_VALUE(md.definition_json,'$.semantics.mechanic.authoringForm.operation')=JSON_VALUE(CONCAT('{"op":',CONVERT(varchar(max),v.content_bytes),'}'),'$.op')
    WHERE n.transformation_version_pk=@transformation_version_pk
), expression_edges AS (
    SELECT n.expression_node_pk AS parent_node_pk,c.child_node_pk
    FROM expression_nodes n
    CROSS APPLY OPENJSON(n.definition_json,'$.semantics.mechanic.authoringForm.arguments') a
    JOIN model.transformation_expression_child c ON c.parent_node_pk=n.expression_node_pk AND c.member_name=a.[key] COLLATE Latin1_General_100_BIN2
    WHERE a.value='semantic-expression'
    UNION ALL
    SELECT n.expression_node_pk,member.child_node_pk
    FROM expression_nodes n
    CROSS APPLY OPENJSON(n.definition_json,'$.semantics.mechanic.authoringForm.arguments') a
    JOIN model.transformation_expression_child collection ON collection.parent_node_pk=n.expression_node_pk AND collection.member_name=a.[key] COLLATE Latin1_General_100_BIN2
    JOIN model.transformation_expression_child member ON member.parent_node_pk=collection.child_node_pk
    WHERE (a.value='expression-map' AND member.member_kind='OBJECT_MEMBER')
       OR (a.value='expression-list' AND member.member_kind='ARRAY_MEMBER')
), walk AS (
    SELECT r.transformation_version_pk,r.expression_node_pk FROM model.transformation_root r
    WHERE r.transformation_version_pk=@transformation_version_pk
    UNION ALL
    SELECT w.transformation_version_pk,e.child_node_pk FROM walk w
    JOIN expression_edges e ON e.parent_node_pk=w.expression_node_pk
)
SELECT w.transformation_version_pk,w.expression_node_pk,n.node_pointer,n.operation_name,n.mechanic_definition_pk
FROM walk w LEFT JOIN expression_nodes n ON n.expression_node_pk=w.expression_node_pk);
GO
CREATE OR ALTER FUNCTION analysis.scenario_embodiment_requirements(@capability_version_pk bigint,@selected_scenario_version_pk bigint)
RETURNS @requirements TABLE (
    estate_model_pk bigint,capability_version_pk bigint,selected_scenario_version_pk bigint,
    downstream_scenario_version_pk bigint,minimum_depth int,cycle_detected int,
    altitude varchar(32),requirement_kind varchar(40),requirement_use varchar(200),
    requirement_definition_pk bigint,requirement_id nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    requirement_definition_digest binary(32),source_definition_pk bigint,
    source_pointer nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    execution_operation_pk bigint,port_version_pk bigint,transformation_version_pk bigint,
    provenance_class varchar(32)
) AS BEGIN
DECLARE @selected_scenarios TABLE (
    estate_model_pk bigint,capability_version_pk bigint,selected_scenario_version_pk bigint,
    downstream_scenario_version_pk bigint,minimum_depth int,cycle_detected int
);
INSERT @selected_scenarios
SELECT * FROM analysis.v_scenario_invocation_closure
WHERE capability_version_pk=@capability_version_pk AND selected_scenario_version_pk=@selected_scenario_version_pk;
WITH scenario_requirements AS (
    SELECT sv.scenario_version_pk,CAST('SCENARIO' AS varchar(32)) AS altitude,
           CAST('INPUT_CONTRACT' AS varchar(40)) AS requirement_kind,
           CAST('input' AS varchar(200)) AS requirement_use,
           cv.semantic_object_definition_pk AS requirement_definition_pk,
           COALESCE(e.semantic_object_definition_pk,sv.semantic_object_definition_pk) AS source_definition_pk,
           CAST(NULL AS bigint) AS execution_operation_pk,CAST(NULL AS bigint) AS port_version_pk,
           CAST(NULL AS bigint) AS transformation_version_pk,
           CAST(NULL AS nvarchar(4000)) COLLATE Latin1_General_100_BIN2 AS declared_reference,
           CAST(NULL AS nvarchar(4000)) COLLATE Latin1_General_100_BIN2 AS source_pointer
    FROM @selected_scenarios ss JOIN model.scenario_version sv ON sv.scenario_version_pk=ss.downstream_scenario_version_pk
    LEFT JOIN model.scenario_input e ON e.scenario_version_pk=sv.scenario_version_pk
    LEFT JOIN model.contract_version cv ON cv.contract_version_pk=e.input_contract_version_pk
    UNION ALL
    SELECT sv.scenario_version_pk,'SCENARIO','EVENT_AUTHORITY','event',a.semantic_object_definition_pk,
           COALESCE(e.semantic_object_definition_pk,sv.semantic_object_definition_pk),NULL,NULL,NULL,NULL,NULL
    FROM @selected_scenarios ss JOIN model.scenario_version sv ON sv.scenario_version_pk=ss.downstream_scenario_version_pk
    LEFT JOIN model.scenario_event e ON e.scenario_version_pk=sv.scenario_version_pk
    LEFT JOIN model.execution_authority_version a ON a.execution_authority_version_pk=e.execution_authority_version_pk
    UNION ALL
    SELECT sv.scenario_version_pk,'SCENARIO','OUTCOME_CONTRACT','outcome',c.semantic_object_definition_pk,
           COALESCE(e.semantic_object_definition_pk,sv.semantic_object_definition_pk),NULL,NULL,NULL,NULL,NULL
    FROM @selected_scenarios ss JOIN model.scenario_version sv ON sv.scenario_version_pk=ss.downstream_scenario_version_pk
    LEFT JOIN model.scenario_outcome e ON e.scenario_version_pk=sv.scenario_version_pk
    LEFT JOIN model.scenario_outcome_contract oc ON oc.scenario_version_pk=e.scenario_version_pk
    LEFT JOIN model.contract_version c ON c.contract_version_pk=oc.contract_version_pk
), operation_requirements AS (
    SELECT e.scenario_version_pk,op.execution_operation_pk,op.operation_kind,op.ordinal,
           op._owner_definition_pk AS source_definition_pk,op._canonical_pointer_key AS source_pointer,
           p.port_version_pk,pv.semantic_object_definition_pk AS port_definition_pk,
           si.target_scenario_version_pk,sv.semantic_object_definition_pk AS target_scenario_definition_pk
    FROM @selected_scenarios ss JOIN model.scenario_event e ON e.scenario_version_pk=ss.downstream_scenario_version_pk
    JOIN model.execution_operation op ON op.execution_authority_version_pk=e.execution_authority_version_pk
    LEFT JOIN model.operation_port_invocation p ON p.execution_operation_pk=op.execution_operation_pk
    LEFT JOIN model.port_version pv ON pv.port_version_pk=p.port_version_pk
    LEFT JOIN model.operation_scenario_invocation si ON si.execution_operation_pk=op.execution_operation_pk
    LEFT JOIN model.scenario_version sv ON sv.scenario_version_pk=si.target_scenario_version_pk
), transformations AS (
    SELECT op.scenario_version_pk,op.execution_operation_pk,op.port_version_pk,pt.transformation_version_pk,
           pt.transformation_definition_pk,op.source_definition_pk,op.source_pointer
    FROM operation_requirements op JOIN analysis.v_declared_port_transformation pt ON pt.port_version_pk=op.port_version_pk
    UNION
    SELECT op.scenario_version_pk,op.execution_operation_pk,op.port_version_pk,sp.transformation_version_pk,
           t.semantic_object_definition_pk,op.source_definition_pk,op.source_pointer
    FROM operation_requirements op JOIN model.operation_state_projection sp ON sp.execution_operation_pk=op.execution_operation_pk
    JOIN model.transformation_version t ON t.transformation_version_pk=sp.transformation_version_pk
    UNION
    SELECT op.scenario_version_pk,op.execution_operation_pk,op.port_version_pk,ot.transformation_version_pk,
           t.semantic_object_definition_pk,op.source_definition_pk,op.source_pointer
    FROM operation_requirements op JOIN model.operation_transformation ot ON ot.execution_operation_pk=op.execution_operation_pk
    JOIN model.transformation_version t ON t.transformation_version_pk=ot.transformation_version_pk
), requirements AS (
    SELECT * FROM scenario_requirements
    UNION ALL
    SELECT scenario_version_pk,'EXECUTION','OPERATION',CONCAT('operation:',execution_operation_pk),
           source_definition_pk,source_definition_pk,execution_operation_pk,port_version_pk,NULL,operation_kind,source_pointer
    FROM operation_requirements
    UNION ALL
    SELECT scenario_version_pk,'EXECUTION','SCENARIO_INVOCATION',CONCAT('invocation:',execution_operation_pk),
           target_scenario_definition_pk,source_definition_pk,execution_operation_pk,NULL,NULL,NULL,source_pointer
    FROM operation_requirements WHERE target_scenario_version_pk IS NOT NULL
    UNION ALL
    SELECT scenario_version_pk,'PROVIDER','PORT',CONCAT('port:',execution_operation_pk),
           port_definition_pk,source_definition_pk,execution_operation_pk,port_version_pk,NULL,NULL,source_pointer
    FROM operation_requirements WHERE port_version_pk IS NOT NULL
    UNION ALL
    SELECT op.scenario_version_pk,'PROVIDER','PLATFORM_CAPABILITY',CONCAT('port-provider:',op.execution_operation_pk),
           NULL,p.semantic_object_definition_pk,op.execution_operation_pk,op.port_version_pk,NULL,
           JSON_VALUE(p.definition_json,'$.semantics.platformCapabilityId'),'$.semantics.platformCapabilityId'
    FROM operation_requirements op JOIN analysis.v_selected_semantic_definition p ON p.semantic_object_definition_pk=op.port_definition_pk
    UNION ALL
    SELECT op.scenario_version_pk,'MECHANIC','TRANSFORMATION_REFERENCE',CONCAT('transformation-reference:',op.execution_operation_pk),
           NULL,p.semantic_object_definition_pk,op.execution_operation_pk,op.port_version_pk,NULL,
           JSON_VALUE(p.definition_json,'$.semantics.configuration.transformationId'),'$.semantics.configuration'
    FROM operation_requirements op JOIN analysis.v_selected_semantic_definition p ON p.semantic_object_definition_pk=op.port_definition_pk
    WHERE (JSON_VALUE(p.definition_json,'$.semantics.configuration.transformationId') IS NOT NULL
        OR JSON_QUERY(p.definition_json,'$.semantics.configuration.expression') IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM analysis.v_declared_port_transformation pt WHERE pt.port_version_pk=op.port_version_pk)
    UNION ALL
    SELECT scenario_version_pk,'MECHANIC','TRANSFORMATION',CONCAT('transformation:',execution_operation_pk,':',transformation_version_pk),
           transformation_definition_pk,source_definition_pk,execution_operation_pk,port_version_pk,transformation_version_pk,NULL,source_pointer
    FROM transformations
    UNION ALL
    SELECT tr.scenario_version_pk,'MECHANIC','MECHANIC',CONCAT('expression:',tr.execution_operation_pk,':',n.expression_node_pk),
           n.mechanic_definition_pk,tr.transformation_definition_pk,tr.execution_operation_pk,tr.port_version_pk,tr.transformation_version_pk,
           n.operation_name,n.node_pointer
    FROM transformations tr
    CROSS APPLY analysis.scenario_transformation_mechanics(tr.transformation_version_pk) n
    UNION ALL
    SELECT op.scenario_version_pk,'MECHANIC','MECHANIC',CONCAT('mechanic:',op.execution_operation_pk,':',m.mechanic_version_pk,':',m.role),
           mv.semantic_object_definition_pk,op.source_definition_pk,op.execution_operation_pk,op.port_version_pk,NULL,NULL,op.source_pointer
    FROM operation_requirements op JOIN model.operation_mechanic m ON m.execution_operation_pk=op.execution_operation_pk
    JOIN model.mechanic_version mv ON mv.mechanic_version_pk=m.mechanic_version_pk
    UNION ALL
    SELECT op.scenario_version_pk,'PROVIDER','PROVIDER_SLOT',CONCAT('slot:',op.execution_operation_pk,':',s.provider_slot_pk),
           s._owner_definition_pk,op.source_definition_pk,op.execution_operation_pk,op.port_version_pk,NULL,s.slot_id,op.source_pointer
    FROM operation_requirements op JOIN model.provider_slot_operation so ON so.execution_operation_pk=op.execution_operation_pk
    JOIN model.provider_slot s ON s.provider_slot_pk=so.provider_slot_pk
)
INSERT @requirements
SELECT cl.estate_model_pk,cl.capability_version_pk,cl.selected_scenario_version_pk,
       cl.downstream_scenario_version_pk,cl.minimum_depth,cl.cycle_detected,
       r.altitude,r.requirement_kind,r.requirement_use,r.requirement_definition_pk,
       COALESCE(r.declared_reference,d.declared_id) AS requirement_id,d.definition_digest AS requirement_definition_digest,
       r.source_definition_pk,r.source_pointer,r.execution_operation_pk,r.port_version_pk,r.transformation_version_pk,
       CAST('DECLARED_AUTHORITY' AS varchar(32)) AS provenance_class
FROM @selected_scenarios cl
JOIN requirements r ON r.scenario_version_pk=cl.downstream_scenario_version_pk
LEFT JOIN analysis.v_selected_semantic_definition d ON d.estate_model_pk=cl.estate_model_pk AND d.semantic_object_definition_pk=r.requirement_definition_pk;
RETURN;
END;
GO
CREATE OR ALTER VIEW analysis.v_scenario_embodiment_requirement AS
SELECT ec.estate_model_pk,ec.capability_version_pk,cs.scenario_version_pk AS selected_scenario_version_pk,
       r.downstream_scenario_version_pk,r.minimum_depth,r.cycle_detected,
       r.altitude,r.requirement_kind,r.requirement_use,r.requirement_definition_pk,
       r.requirement_id,r.requirement_definition_digest,r.source_definition_pk,r.source_pointer,
       r.execution_operation_pk,r.port_version_pk,r.transformation_version_pk,r.provenance_class
FROM source.current_model cm
JOIN model.estate_capability ec ON ec.estate_model_pk=cm.estate_model_pk
JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk
CROSS APPLY analysis.scenario_embodiment_requirements(ec.capability_version_pk,cs.scenario_version_pk) r;
GO
CREATE OR ALTER FUNCTION analysis.declared_native_mechanic_resolutions()
RETURNS @resolutions TABLE (
    estate_model_pk bigint,mechanic_definition_pk bigint,profile_definition_pk bigint,
    provider_profile_id nvarchar(400) COLLATE Latin1_General_100_BIN2,
    target_language nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    resolver_id nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    implementation_id nvarchar(max) COLLATE Latin1_General_100_BIN2,
    implementation_export nvarchar(4000) COLLATE Latin1_General_100_BIN2,
    mechanic_source_digest binary(32),registry_source_digest binary(32),
    declared_authority_digest nvarchar(4000) COLLATE Latin1_General_100_BIN2
) AS BEGIN
-- The registry declares the language and native module. The referenced mechanic
-- authority supplies the vocabulary. No inference from provider names occurs.
DECLARE @definitions TABLE (
    estate_model_pk bigint,semantic_object_definition_pk bigint,
    definition_json nvarchar(max) COLLATE Latin1_General_100_BIN2
);
INSERT @definitions
SELECT estate_model_pk,semantic_object_definition_pk,definition_json
FROM analysis.v_selected_semantic_definition WHERE object_kind IN('PROVIDER_PROFILE','MECHANIC');
DECLARE @sources TABLE (
    source_appearance_pk bigint,estate_snapshot_pk bigint,content_digest binary(32),
    definition_json nvarchar(max) COLLATE Latin1_General_100_BIN2
);
INSERT @sources
SELECT a.source_appearance_pk,a.estate_snapshot_pk,c.content_digest,
       CONVERT(nvarchar(max),CONVERT(varchar(max),c.content_bytes) COLLATE Latin1_General_100_BIN2_UTF8)
FROM source.current_model cm JOIN source.estate_model em ON em.estate_model_pk=cm.estate_model_pk
JOIN source.source_appearance a ON a.estate_snapshot_pk=em.estate_snapshot_pk
JOIN source.content_object c ON c.content_object_pk=a.content_object_pk
WHERE a.source_class='PINNED_PLATFORM_AUTHORITY';
INSERT @resolutions
SELECT DISTINCT md.estate_model_pk,md.semantic_object_definition_pk AS mechanic_definition_pk,
       pd.semantic_object_definition_pk AS profile_definition_pk,p.provider_profile_id,
       JSON_VALUE(registry_text.json_text,'$.language') AS target_language,
       JSON_VALUE(registry_text.json_text,'$.authorityId') AS resolver_id,
       CONCAT(JSON_VALUE(registry_text.json_text,'$.providerModuleRoot'),'/',JSON_VALUE(pd.definition_json,'$.semantics.providerModule')) AS implementation_id,
       JSON_VALUE(pd.definition_json,'$.semantics.providerExport') AS implementation_export,
       ma.content_digest AS mechanic_source_digest,pa.content_digest AS registry_source_digest,
       JSON_VALUE(pd.definition_json,'$.semantics.mechanicAuthorityDigest') AS declared_authority_digest
FROM model.provider_profile_version pv
JOIN @definitions pd ON pd.semantic_object_definition_pk=pv.semantic_object_definition_pk
JOIN model.provider_profile p ON p.provider_profile_pk=pv.provider_profile_pk
JOIN source.source_lineage pl ON pl.semantic_object_definition_pk=pd.semantic_object_definition_pk
JOIN source.source_observation po ON po.source_observation_pk=pl.source_observation_pk
JOIN @sources pa ON pa.source_appearance_pk=po.source_appearance_pk
CROSS APPLY (SELECT pa.definition_json AS source_text) registry_source
CROSS APPLY (SELECT CASE WHEN ISJSON(registry_source.source_text)=1 THEN registry_source.source_text ELSE N'{}' END AS json_text) registry_text
JOIN source.estate_model em ON em.estate_model_pk=pd.estate_model_pk AND em.estate_snapshot_pk=pa.estate_snapshot_pk
JOIN model.mechanic_version mv ON 1=1
JOIN @definitions md ON md.semantic_object_definition_pk=mv.semantic_object_definition_pk AND md.estate_model_pk=pd.estate_model_pk
JOIN source.source_lineage ml ON ml.semantic_object_definition_pk=md.semantic_object_definition_pk
JOIN source.source_observation mo ON mo.source_observation_pk=ml.source_observation_pk
JOIN @sources ma ON ma.source_appearance_pk=mo.source_appearance_pk AND ma.estate_snapshot_pk=em.estate_snapshot_pk
CROSS APPLY (SELECT ma.definition_json AS source_text) mechanic_source
CROSS APPLY (SELECT CASE WHEN ISJSON(mechanic_source.source_text)=1 THEN mechanic_source.source_text ELSE N'{}' END AS json_text) mechanic_text
WHERE JSON_VALUE(mechanic_text.json_text,'$.authorityDigest')=JSON_VALUE(pd.definition_json,'$.semantics.mechanicAuthorityDigest')
  AND JSON_VALUE(mechanic_text.json_text,'$.authorityId')=JSON_VALUE(md.definition_json,'$.semantics.authorityId')
  AND JSON_VALUE(registry_text.json_text,'$.language') IS NOT NULL;
RETURN;
END;
GO
CREATE OR ALTER VIEW analysis.v_declared_native_mechanic_resolution AS
SELECT * FROM analysis.declared_native_mechanic_resolutions();
GO
CREATE OR ALTER VIEW analysis.v_declared_mechanic_resolution AS
SELECT nr.estate_model_pk,nr.mechanic_definition_pk,nr.target_language,
       CAST(NULL AS bigint) AS provider_definition_pk,
       CAST(NULL AS nvarchar(400)) COLLATE Latin1_General_100_BIN2 AS provider_id,
       nr.profile_definition_pk,nr.provider_profile_id,nr.resolver_id,
       nr.implementation_id,nr.implementation_export,
       CAST(NULL AS nvarchar(4000)) COLLATE Latin1_General_100_BIN2 AS conformance_ref,
       nr.mechanic_source_digest,nr.registry_source_digest,nr.declared_authority_digest
FROM analysis.v_declared_native_mechanic_resolution nr
UNION
SELECT pi.estate_model_pk,mv.semantic_object_definition_pk,pi.target_language,
       pi.provider_definition_pk,pi.provider_id,NULL,NULL,NULL,
       pi.implementation_id,NULL,pi.conformance_ref,NULL,NULL,NULL
FROM analysis.v_declared_platform_implementation pi
JOIN model.provider_mechanic_implementation pm ON pm.provider_definition_pk=pi.provider_definition_pk
JOIN model.mechanic_version mv ON mv.mechanic_version_pk=pm.mechanic_version_pk
JOIN model.estate_definition ed ON ed.estate_model_pk=pi.estate_model_pk AND ed.semantic_object_definition_pk=mv.semantic_object_definition_pk
WHERE pi.declaration_status='ADMITTED';
GO
CREATE OR ALTER VIEW analysis.v_scenario_language_resolution AS
WITH targets AS (
    SELECT DISTINCT estate_model_pk,target_language FROM analysis.v_declared_platform_implementation
), resolutions AS (
    SELECT r.*,t.target_language,
           COALESCE(pi.provider_definition_pk,nr.provider_definition_pk) AS provider_definition_pk,
           COALESCE(pi.provider_id,nr.provider_id) AS provider_id,
           nr.profile_definition_pk,nr.provider_profile_id,nr.resolver_id,
           COALESCE(pi.implementation_id,nr.implementation_id) AS implementation_id,
           nr.implementation_export,COALESCE(pi.conformance_ref,nr.conformance_ref) AS conformance_ref,
           nr.mechanic_source_digest,nr.registry_source_digest,nr.declared_authority_digest,
           COUNT_BIG(*) OVER(PARTITION BY r.estate_model_pk,r.capability_version_pk,r.selected_scenario_version_pk,
             r.downstream_scenario_version_pk,r.requirement_use,t.target_language) AS resolution_candidate_count,
           CASE
             WHEN r.cycle_detected<>0 THEN 'NOT_OBSERVABLE'
             WHEN r.requirement_kind='TRANSFORMATION_REFERENCE' THEN 'NOT_OBSERVABLE'
             WHEN r.requirement_kind='PLATFORM_CAPABILITY' AND pi.capability_definition_pk IS NULL THEN 'NOT_OBSERVABLE'
             WHEN r.requirement_kind='PLATFORM_CAPABILITY' AND ISNULL(pi.declaration_status,'')<>'ADMITTED' THEN 'NOT_OBSERVABLE'
             WHEN r.requirement_kind<>'PLATFORM_CAPABILITY' AND r.requirement_definition_pk IS NULL THEN 'MISSING_AUTHORITY'
             WHEN r.requirement_kind='MECHANIC' AND nr.mechanic_definition_pk IS NULL THEN 'NOT_OBSERVABLE'
             WHEN r.requirement_kind='PROVIDER_SLOT' THEN 'NOT_OBSERVABLE'
             ELSE 'RESOLVED'
           END AS base_resolution_status,
           CASE
             WHEN r.cycle_detected<>0 THEN 'INVOCATION_CYCLE_REQUIRES_AUTHORITY_REVIEW'
             WHEN r.requirement_kind='TRANSFORMATION_REFERENCE' THEN 'EXACT_TRANSFORMATION_REFERENCE_NOT_RESOLVED'
             WHEN r.requirement_kind='PLATFORM_CAPABILITY' AND pi.capability_definition_pk IS NULL THEN 'TARGET_BINDING_NOT_ESTABLISHED'
             WHEN r.requirement_kind='PLATFORM_CAPABILITY' AND ISNULL(pi.declaration_status,'')<>'ADMITTED' THEN 'PROVIDER_DECLARATION_NOT_ADMITTED'
             WHEN r.requirement_kind<>'PLATFORM_CAPABILITY' AND r.requirement_definition_pk IS NULL THEN 'REQUIRED_DEFINITION_NOT_RESOLVED'
             WHEN r.requirement_kind='MECHANIC' AND nr.mechanic_definition_pk IS NULL THEN 'EXACT_MECHANIC_TARGET_BINDING_NOT_ESTABLISHED'
             WHEN r.requirement_kind='PROVIDER_SLOT' THEN 'SLOT_SELECTION_NOT_ESTABLISHED'
             ELSE 'DECLARED_REQUIREMENT_ACCOUNTED_FOR'
           END AS base_diagnostic
    FROM analysis.v_scenario_embodiment_requirement r
    JOIN targets t ON t.estate_model_pk=r.estate_model_pk
    LEFT JOIN analysis.v_declared_platform_implementation pi ON r.requirement_kind='PLATFORM_CAPABILITY'
     AND pi.estate_model_pk=r.estate_model_pk AND pi.target_language=t.target_language AND pi.platform_capability_id=r.requirement_id
    LEFT JOIN analysis.v_declared_mechanic_resolution nr ON r.requirement_kind='MECHANIC'
     AND nr.estate_model_pk=r.estate_model_pk AND nr.target_language=t.target_language AND nr.mechanic_definition_pk=r.requirement_definition_pk
)
SELECT c.capability_id,s.scenario_id,ds.scenario_id AS downstream_scenario_id,
       sv.definition_digest AS scenario_definition_digest,r.*,
       CASE WHEN resolution_candidate_count>1 THEN 'NOT_OBSERVABLE' ELSE base_resolution_status END AS resolution_status,
       CASE WHEN resolution_candidate_count>1 THEN 'PROVIDER_SELECTION_NOT_ESTABLISHED' ELSE base_diagnostic END AS diagnostic,
       CASE WHEN base_resolution_status='MISSING_AUTHORITY' THEN 'SEMANTIC_AUTHORITY'
            WHEN resolution_candidate_count>1 OR base_resolution_status='NOT_OBSERVABLE' THEN 'DECLARATION_AND_BINDING_EVIDENCE'
            ELSE NULL END AS repair_boundary,
       CAST('NOT_EVALUATED' AS varchar(32)) AS conformance_status,
       CAST('DECLARATION_ONLY' AS varchar(32)) AS implementation_evidence_state
FROM resolutions r
JOIN model.capability_version cv ON cv.capability_version_pk=r.capability_version_pk
JOIN model.capability c ON c.capability_pk=cv.capability_pk
JOIN model.scenario_version sv ON sv.scenario_version_pk=r.selected_scenario_version_pk
JOIN model.scenario s ON s.scenario_pk=sv.scenario_pk
JOIN model.scenario_version dsv ON dsv.scenario_version_pk=r.downstream_scenario_version_pk
JOIN model.scenario ds ON ds.scenario_pk=dsv.scenario_pk;
GO
CREATE OR ALTER VIEW analysis.v_scenario_embodiment_readiness AS
WITH obligations AS (
    SELECT estate_model_pk,capability_version_pk,capability_id,scenario_id,selected_scenario_version_pk,target_language,
           downstream_scenario_version_pk,requirement_use,
           MAX(CASE WHEN resolution_status<>'RESOLVED' THEN 1 ELSE 0 END) AS is_open
    FROM analysis.v_scenario_language_resolution
    GROUP BY estate_model_pk,capability_version_pk,capability_id,scenario_id,selected_scenario_version_pk,target_language,
             downstream_scenario_version_pk,requirement_use
)
SELECT estate_model_pk,capability_version_pk,capability_id,scenario_id,selected_scenario_version_pk,target_language,
       COUNT_BIG(*) AS requirement_count,
       SUM(CONVERT(bigint,1-is_open)) AS accounted_requirement_count,
       SUM(CONVERT(bigint,is_open)) AS open_requirement_count,
       CASE WHEN SUM(is_open)=0
            THEN 'CAN_ATTEMPT_EMBODIMENT' ELSE 'NOT_OBSERVABLE' END AS readiness,
       CAST('NOT_EVALUATED' AS varchar(32)) AS conformance_status
FROM obligations
GROUP BY estate_model_pk,capability_version_pk,capability_id,scenario_id,selected_scenario_version_pk,target_language;
