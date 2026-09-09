-- Generated from src/migration/catalog.mjs, schema.mjs and views.mjs.
-- Migration 001-normalized-estate; sha256:9bcfa631dc60e994f4954c3a037c2be1c7592c5174f35226e12da136c0447df6
-- Apply transactionally through npm run migrate.

IF SCHEMA_ID('source') IS NULL EXEC('CREATE SCHEMA [source] AUTHORIZATION dbo');
GO
IF SCHEMA_ID('model') IS NULL EXEC('CREATE SCHEMA [model] AUTHORIZATION dbo');
GO
IF SCHEMA_ID('analysis') IS NULL EXEC('CREATE SCHEMA [analysis] AUTHORIZATION dbo');
GO
IF SCHEMA_ID('sidefx') IS NULL EXEC('CREATE SCHEMA [sidefx] AUTHORIZATION dbo');
GO
CREATE TABLE [source].[estate_snapshot] (
  [estate_snapshot_pk] bigint IDENTITY(1,1) NOT NULL,
  [snapshot_digest] binary(32) NOT NULL,
  [estate_manifest_digest] binary(32) NOT NULL,
  [source_head] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [captured_at] datetime2(7) NULL,
  CONSTRAINT [PK_source_estate_snapshot_35dcd30fe825] PRIMARY KEY CLUSTERED ([estate_snapshot_pk]),
  CONSTRAINT [AK_source_estate_snapshot_e2f0f88ebcc7] UNIQUE NONCLUSTERED ([snapshot_digest]),
  CONSTRAINT [CK_source_estate_snapshot_c60421197fd9] CHECK ([source_head] IS NULL OR (DATALENGTH([source_head])>0 AND DATALENGTH([source_head])=DATALENGTH(LTRIM(RTRIM([source_head]))) AND UNICODE(LEFT([source_head],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([source_head],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [source].[content_object] (
  [content_object_pk] bigint IDENTITY(1,1) NOT NULL,
  [content_digest] binary(32) NOT NULL,
  [content_bytes] varbinary(max) NOT NULL,
  [byte_length] bigint NOT NULL,
  CONSTRAINT [PK_source_content_object_36b9754af42f] PRIMARY KEY CLUSTERED ([content_object_pk]),
  CONSTRAINT [AK_source_content_object_054f8126d141] UNIQUE NONCLUSTERED ([content_digest]),
  CONSTRAINT [CK_source_content_object_83d242475883] CHECK (byte_length>=0 AND byte_length=DATALENGTH(content_bytes)),
  CONSTRAINT [CK_source_content_object_c981f428252e] CHECK (content_digest=HASHBYTES('SHA2_256',content_bytes))
);
GO
CREATE TABLE [source].[source_appearance] (
  [source_appearance_pk] bigint IDENTITY(1,1) NOT NULL,
  [estate_snapshot_pk] bigint NOT NULL,
  [content_object_pk] bigint NOT NULL,
  [appearance_digest] binary(32) NOT NULL,
  [source_path] nvarchar(max) NOT NULL,
  [source_class] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [container_locator] nvarchar(max) NULL,
  [capsule_digest] binary(32) NULL,
  [referenced_authority_digest] binary(32) NULL,
  [entry_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  CONSTRAINT [PK_source_source_appearance_5c34d695c33d] PRIMARY KEY CLUSTERED ([source_appearance_pk]),
  CONSTRAINT [AK_source_source_appearance_135cd90d16b8] UNIQUE NONCLUSTERED ([estate_snapshot_pk],[appearance_digest]),
  CONSTRAINT [CK_source_source_appearance_22abd9cc329b] CHECK ([entry_id] IS NULL OR (DATALENGTH([entry_id])>0 AND DATALENGTH([entry_id])=DATALENGTH(LTRIM(RTRIM([entry_id]))) AND UNICODE(LEFT([entry_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([entry_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [source].[mapping_rule] (
  [mapping_rule_pk] bigint IDENTITY(1,1) NOT NULL,
  [rule_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [rule_digest] binary(32) NOT NULL,
  [source_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [rule_content_object_pk] bigint NOT NULL,
  [canonicalization_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_mapping_rule_603e2241c2aa] PRIMARY KEY CLUSTERED ([mapping_rule_pk]),
  CONSTRAINT [AK_source_mapping_rule_2d82aaf900c4] UNIQUE NONCLUSTERED ([rule_id],[rule_digest]),
  CONSTRAINT [CK_source_mapping_rule_12fbbb26c91b] CHECK ((DATALENGTH([rule_id])>0 AND DATALENGTH([rule_id])=DATALENGTH(LTRIM(RTRIM([rule_id]))) AND UNICODE(LEFT([rule_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([rule_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_source_mapping_rule_391cd16f2e69] CHECK ((DATALENGTH([source_profile])>0 AND DATALENGTH([source_profile])=DATALENGTH(LTRIM(RTRIM([source_profile]))) AND UNICODE(LEFT([source_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([source_profile],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_source_mapping_rule_525e973b9191] CHECK ((DATALENGTH([canonicalization_profile])>0 AND DATALENGTH([canonicalization_profile])=DATALENGTH(LTRIM(RTRIM([canonicalization_profile]))) AND UNICODE(LEFT([canonicalization_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([canonicalization_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [source].[source_classification] (
  [source_appearance_pk] bigint NOT NULL,
  [mapping_rule_pk] bigint NOT NULL,
  [family_code] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [classification_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_source_classification_4ffcaa0b7496] PRIMARY KEY CLUSTERED ([source_appearance_pk],[mapping_rule_pk],[family_code]),
  CONSTRAINT [CK_source_source_classification_e285cfd9180f] CHECK ([classification_state] IN ('SUPPORTED','UNSUPPORTED','AMBIGUOUS','OUTSIDE_SCOPE'))
);
GO
CREATE TABLE [source].[namespace_mapping] (
  [mapping_rule_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_scope] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [namespace_pk] bigint NOT NULL,
  CONSTRAINT [PK_source_namespace_mapping_4d21fe5ccf1d] PRIMARY KEY CLUSTERED ([mapping_rule_pk],[object_kind],[source_scope]),
  CONSTRAINT [CK_source_namespace_mapping_23e58ce8d157] CHECK ((DATALENGTH([source_scope])>0 AND DATALENGTH([source_scope])=DATALENGTH(LTRIM(RTRIM([source_scope]))) AND UNICODE(LEFT([source_scope],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([source_scope],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [source].[source_observation] (
  [source_observation_pk] bigint IDENTITY(1,1) NOT NULL,
  [source_appearance_pk] bigint NOT NULL,
  [locator] nvarchar(max) NOT NULL,
  [locator_digest] binary(32) NOT NULL,
  [observation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [presence_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [observed_value_content_pk] bigint NULL,
  CONSTRAINT [PK_source_source_observation_c2be5368d838] PRIMARY KEY CLUSTERED ([source_observation_pk]),
  CONSTRAINT [AK_source_source_observation_8daa7c27d537] UNIQUE NONCLUSTERED ([source_appearance_pk],[locator_digest],[observation_kind]),
  CONSTRAINT [AK_source_source_observation_99a0a7ac5edb] UNIQUE NONCLUSTERED ([source_observation_pk],[observation_kind]),
  CONSTRAINT [CK_source_source_observation_c8538343907e] CHECK ([presence_state] IN ('PRESENT','ABSENT','EXPLICIT_NULL','NOT_APPLICABLE'))
);
GO
CREATE TABLE [source].[declaration_observation] (
  [source_observation_pk] bigint NOT NULL,
  [declared_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [declared_id] nvarchar(max) NULL,
  [namespace_text] nvarchar(max) NULL,
  [observation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_declaration_observation_c2be5368d838] PRIMARY KEY CLUSTERED ([source_observation_pk]),
  CONSTRAINT [CK_source_declaration_observation_37dd8bbc576c] CHECK ([observation_kind]='DECLARATION')
);
GO
CREATE TABLE [source].[relationship_observation] (
  [source_observation_pk] bigint NOT NULL,
  [relationship_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_reference] nvarchar(max) NULL,
  [target_reference] nvarchar(max) NULL,
  [declared_target_digest] binary(32) NULL,
  [observation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_relationship_observation_c2be5368d838] PRIMARY KEY CLUSTERED ([source_observation_pk]),
  CONSTRAINT [CK_source_relationship_observation_b0e60987b8c8] CHECK ([observation_kind]='RELATIONSHIP')
);
GO
CREATE TABLE [source].[source_lineage] (
  [source_lineage_pk] bigint IDENTITY(1,1) NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [member_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [canonical_pointer_key] AS CONVERT(varbinary(800),[canonical_pointer]) PERSISTED,
  [source_observation_pk] bigint NOT NULL,
  [mapping_rule_pk] bigint NOT NULL,
  [contribution_role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_source_lineage_ca71cd9f3bde] PRIMARY KEY CLUSTERED ([source_lineage_pk]),
  CONSTRAINT [AK_source_source_lineage_f989de52e91d] UNIQUE NONCLUSTERED ([semantic_object_definition_pk],[member_kind],[canonical_pointer_key],[source_observation_pk],[mapping_rule_pk],[contribution_role])
);
GO
CREATE TABLE [source].[estate_model] (
  [estate_model_pk] bigint IDENTITY(1,1) NOT NULL,
  [estate_snapshot_pk] bigint NOT NULL,
  [mapping_manifest_digest] binary(32) NOT NULL,
  [publication_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_source_estate_model_e806c12f937d] PRIMARY KEY CLUSTERED ([estate_model_pk]),
  CONSTRAINT [AK_source_estate_model_c376e08d1de0] UNIQUE NONCLUSTERED ([estate_snapshot_pk],[mapping_manifest_digest]),
  CONSTRAINT [CK_source_estate_model_0a81b752c34d] CHECK ([publication_state] IN ('BUILDING','PUBLISHED','FAILED'))
);
GO
CREATE TABLE [source].[estate_model_rule] (
  [estate_model_pk] bigint NOT NULL,
  [mapping_rule_pk] bigint NOT NULL,
  CONSTRAINT [PK_source_estate_model_rule_ad7b4a743df8] PRIMARY KEY CLUSTERED ([estate_model_pk],[mapping_rule_pk])
);
GO
CREATE TABLE [source].[current_model] (
  [singleton_id] tinyint NOT NULL,
  [estate_model_pk] bigint NOT NULL,
  CONSTRAINT [PK_source_current_model_4286d5d0fdcc] PRIMARY KEY CLUSTERED ([singleton_id]),
  CONSTRAINT [CK_source_current_model_88d8e657608a] CHECK (singleton_id=1)
);
GO
CREATE TABLE [model].[identity_namespace] (
  [namespace_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [namespace_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_identity_namespace_186d86d7e450] PRIMARY KEY CLUSTERED ([namespace_pk]),
  CONSTRAINT [AK_model_identity_namespace_7472895d7383] UNIQUE NONCLUSTERED ([namespace_kind],[namespace_id]),
  CONSTRAINT [CK_model_identity_namespace_6254c05a0537] CHECK ((DATALENGTH([namespace_id])>0 AND DATALENGTH([namespace_id])=DATALENGTH(LTRIM(RTRIM([namespace_id]))) AND UNICODE(LEFT([namespace_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([namespace_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[namespace_owner] (
  [namespace_pk] bigint NOT NULL,
  [owner_semantic_object_pk] bigint NOT NULL,
  [scope_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_namespace_owner_186d86d7e450] PRIMARY KEY CLUSTERED ([namespace_pk]),
  CONSTRAINT [AK_model_namespace_owner_593c6f448b55] UNIQUE NONCLUSTERED ([owner_semantic_object_pk],[scope_kind])
);
GO
CREATE TABLE [model].[semantic_object] (
  [semantic_object_pk] bigint IDENTITY(1,1) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [declared_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_semantic_object_803f49d72016] PRIMARY KEY CLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_semantic_object_3ddadb1c9387] UNIQUE NONCLUSTERED ([namespace_pk],[declared_id]),
  CONSTRAINT [AK_model_semantic_object_4abae4ea23d6] UNIQUE NONCLUSTERED ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]),
  CONSTRAINT [AK_model_semantic_object_aa3d27e36011] UNIQUE NONCLUSTERED ([semantic_object_pk],[object_kind]),
  CONSTRAINT [CK_model_semantic_object_0c417ab3a06a] CHECK ((DATALENGTH([declared_id])>0 AND DATALENGTH([declared_id])=DATALENGTH(LTRIM(RTRIM([declared_id]))) AND UNICODE(LEFT([declared_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([declared_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[semantic_object_definition] (
  [semantic_object_definition_pk] bigint IDENTITY(1,1) NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [canonical_content_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_semantic_object_definition_524212dcbc38] PRIMARY KEY CLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_semantic_object_definition_225c4638c685] UNIQUE NONCLUSTERED ([semantic_object_pk],[definition_digest]),
  CONSTRAINT [AK_model_semantic_object_definition_12b758f1a94f] UNIQUE NONCLUSTERED ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]),
  CONSTRAINT [AK_model_semantic_object_definition_2c91dc1ef44f] UNIQUE NONCLUSTERED ([semantic_object_definition_pk],[semantic_object_pk],[definition_digest]),
  CONSTRAINT [AK_model_semantic_object_definition_64d6e926b69a] UNIQUE NONCLUSTERED ([semantic_object_definition_pk],[object_kind])
);
GO
CREATE TABLE [model].[definition_version_label] (
  [semantic_object_pk] bigint NOT NULL,
  [version_label] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_definition_version_label_e9701e4d69d5] PRIMARY KEY CLUSTERED ([semantic_object_pk],[version_label]),
  CONSTRAINT [CK_model_definition_version_label_615bff8cfcc4] CHECK ((DATALENGTH([version_label])>0 AND DATALENGTH([version_label])=DATALENGTH(LTRIM(RTRIM([version_label]))) AND UNICODE(LEFT([version_label],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([version_label],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[estate_definition] (
  [estate_model_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_estate_definition_5082f0275978] PRIMARY KEY CLUSTERED ([estate_model_pk],[semantic_object_definition_pk])
);
GO
CREATE TABLE [model].[estate_capability] (
  [estate_model_pk] bigint NOT NULL,
  [capability_pk] bigint NOT NULL,
  [capability_version_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_estate_capability_2c4ae80d4ce0] PRIMARY KEY CLUSTERED ([estate_model_pk],[capability_pk])
);
GO
CREATE TABLE [model].[capability] (
  [capability_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [capability_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_capability_5c236d60f8bf] PRIMARY KEY CLUSTERED ([capability_pk]),
  CONSTRAINT [AK_model_capability_9f42373e7c6b] UNIQUE NONCLUSTERED ([namespace_pk],[capability_id]),
  CONSTRAINT [AK_model_capability_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_capability_d0faabd572ac] UNIQUE NONCLUSTERED ([capability_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_capability_f5a166424aec] CHECK ([object_kind]='CAPABILITY'),
  CONSTRAINT [CK_model_capability_14d5449fcd4d] CHECK ((DATALENGTH([capability_id])>0 AND DATALENGTH([capability_id])=DATALENGTH(LTRIM(RTRIM([capability_id]))) AND UNICODE(LEFT([capability_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([capability_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[capability_version] (
  [capability_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [capability_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NOT NULL,
  [actor] nvarchar(max) NULL,
  [intent] nvarchar(max) NULL,
  [outcome] nvarchar(max) NULL,
  [experience_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [experience_actor] nvarchar(max) NULL,
  [experience_promise] nvarchar(max) NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_capability_version_9469b5d8b15f] PRIMARY KEY CLUSTERED ([capability_version_pk]),
  CONSTRAINT [AK_model_capability_version_da7269949524] UNIQUE NONCLUSTERED ([capability_pk],[definition_digest]),
  CONSTRAINT [AK_model_capability_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_capability_version_cee137d3dee6] UNIQUE NONCLUSTERED ([capability_pk],[capability_version_pk]),
  CONSTRAINT [AK_model_capability_version_c27f2822f77d] UNIQUE NONCLUSTERED ([capability_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_capability_version_f5a166424aec] CHECK ([object_kind]='CAPABILITY'),
  CONSTRAINT [CK_model_capability_version_890f3a185038] CHECK ([experience_id] IS NULL OR (DATALENGTH([experience_id])>0 AND DATALENGTH([experience_id])=DATALENGTH(LTRIM(RTRIM([experience_id]))) AND UNICODE(LEFT([experience_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([experience_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[product] (
  [product_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [product_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_product_c7a51a1e752d] PRIMARY KEY CLUSTERED ([product_pk]),
  CONSTRAINT [AK_model_product_519264bac898] UNIQUE NONCLUSTERED ([namespace_pk],[product_id]),
  CONSTRAINT [AK_model_product_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_product_ae8cc738abf8] UNIQUE NONCLUSTERED ([product_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_product_d38a9f9cd9aa] CHECK ([object_kind]='PRODUCT'),
  CONSTRAINT [CK_model_product_d32206fc5d10] CHECK ((DATALENGTH([product_id])>0 AND DATALENGTH([product_id])=DATALENGTH(LTRIM(RTRIM([product_id]))) AND UNICODE(LEFT([product_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([product_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[product_definition] (
  [product_definition_pk] bigint IDENTITY(1,1) NOT NULL,
  [product_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NOT NULL,
  [contract_version_pk] bigint NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [contract_reference_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_product_definition_f0fc7329bbd2] PRIMARY KEY CLUSTERED ([product_definition_pk]),
  CONSTRAINT [AK_model_product_definition_e7cc720621e9] UNIQUE NONCLUSTERED ([product_pk],[definition_digest]),
  CONSTRAINT [AK_model_product_definition_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_product_definition_70ed79022d27] UNIQUE NONCLUSTERED ([product_pk],[product_definition_pk]),
  CONSTRAINT [AK_model_product_definition_40917cf15f3d] UNIQUE NONCLUSTERED ([product_definition_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_product_definition_d38a9f9cd9aa] CHECK ([object_kind]='PRODUCT'),
  CONSTRAINT [CK_model_product_definition_b5418f07ca19] CHECK ([contract_reference_state] IN ('RESOLVED','ABSENT','EXPLICIT_NULL','UNRESOLVED','NOT_APPLICABLE')),
  CONSTRAINT [CK_model_product_definition_aba9f49632e4] CHECK (([contract_reference_state]='RESOLVED' AND [contract_version_pk] IS NOT NULL) OR ([contract_reference_state]<>'RESOLVED' AND [contract_version_pk] IS NULL))
);
GO
CREATE TABLE [model].[contract] (
  [contract_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [contract_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_contract_1548f8c6e8bc] PRIMARY KEY CLUSTERED ([contract_pk]),
  CONSTRAINT [AK_model_contract_5ada93135754] UNIQUE NONCLUSTERED ([namespace_pk],[contract_id]),
  CONSTRAINT [AK_model_contract_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_contract_0dcd7ce7f6ff] UNIQUE NONCLUSTERED ([contract_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_contract_fe6575f12e49] CHECK ([object_kind]='CONTRACT'),
  CONSTRAINT [CK_model_contract_2fbd6be71e8d] CHECK ((DATALENGTH([contract_id])>0 AND DATALENGTH([contract_id])=DATALENGTH(LTRIM(RTRIM([contract_id]))) AND UNICODE(LEFT([contract_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([contract_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[contract_version] (
  [contract_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [contract_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NULL,
  [contract_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [schema_object_pk] bigint NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [schema_reference_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_contract_version_ec8352c40547] PRIMARY KEY CLUSTERED ([contract_version_pk]),
  CONSTRAINT [AK_model_contract_version_cb5f7f26518c] UNIQUE NONCLUSTERED ([contract_pk],[definition_digest]),
  CONSTRAINT [AK_model_contract_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_contract_version_f2c1027eff34] UNIQUE NONCLUSTERED ([contract_pk],[contract_version_pk]),
  CONSTRAINT [AK_model_contract_version_9708cc34d128] UNIQUE NONCLUSTERED ([contract_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_contract_version_fe6575f12e49] CHECK ([object_kind]='CONTRACT'),
  CONSTRAINT [CK_model_contract_version_ec6583f1dea6] CHECK ([schema_reference_state] IN ('RESOLVED','ABSENT','EXPLICIT_NULL','UNRESOLVED','NOT_APPLICABLE')),
  CONSTRAINT [CK_model_contract_version_f5a5b15ef200] CHECK (([schema_reference_state]='RESOLVED' AND [schema_object_pk] IS NOT NULL) OR ([schema_reference_state]<>'RESOLVED' AND [schema_object_pk] IS NULL))
);
GO
CREATE TABLE [model].[execution_authority] (
  [execution_authority_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [execution_authority_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_execution_authority_77d7d971413f] PRIMARY KEY CLUSTERED ([execution_authority_pk]),
  CONSTRAINT [AK_model_execution_authority_ff4d40f0c086] UNIQUE NONCLUSTERED ([namespace_pk],[execution_authority_id]),
  CONSTRAINT [AK_model_execution_authority_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_execution_authority_d328cae9c33c] UNIQUE NONCLUSTERED ([execution_authority_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_execution_authority_7a27453134f8] CHECK ([object_kind]='EXECUTION_AUTHORITY'),
  CONSTRAINT [CK_model_execution_authority_e787c9e0c56b] CHECK ((DATALENGTH([execution_authority_id])>0 AND DATALENGTH([execution_authority_id])=DATALENGTH(LTRIM(RTRIM([execution_authority_id]))) AND UNICODE(LEFT([execution_authority_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([execution_authority_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[execution_authority_version] (
  [execution_authority_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [execution_authority_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [authority_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_execution_authority_version_b4adc4a9e74d] PRIMARY KEY CLUSTERED ([execution_authority_version_pk]),
  CONSTRAINT [AK_model_execution_authority_version_5f0024938111] UNIQUE NONCLUSTERED ([execution_authority_pk],[definition_digest]),
  CONSTRAINT [AK_model_execution_authority_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_execution_authority_version_662d975bf9c6] UNIQUE NONCLUSTERED ([execution_authority_pk],[execution_authority_version_pk]),
  CONSTRAINT [AK_model_execution_authority_version_3ae8b947f4d3] UNIQUE NONCLUSTERED ([execution_authority_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_execution_authority_version_7a27453134f8] CHECK ([object_kind]='EXECUTION_AUTHORITY'),
  CONSTRAINT [CK_model_execution_authority_version_2a1ec0d17cdc] CHECK ((DATALENGTH([authority_profile])>0 AND DATALENGTH([authority_profile])=DATALENGTH(LTRIM(RTRIM([authority_profile]))) AND UNICODE(LEFT([authority_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([authority_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[transformation] (
  [transformation_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [transformation_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_transformation_16e0b4b4df7a] PRIMARY KEY CLUSTERED ([transformation_pk]),
  CONSTRAINT [AK_model_transformation_dc4578b578a9] UNIQUE NONCLUSTERED ([namespace_pk],[transformation_id]),
  CONSTRAINT [AK_model_transformation_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_transformation_ad9cb09b668f] UNIQUE NONCLUSTERED ([transformation_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_transformation_38d6705a1156] CHECK ([object_kind]='TRANSFORMATION'),
  CONSTRAINT [CK_model_transformation_7ca39cbf808d] CHECK ((DATALENGTH([transformation_id])>0 AND DATALENGTH([transformation_id])=DATALENGTH(LTRIM(RTRIM([transformation_id]))) AND UNICODE(LEFT([transformation_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([transformation_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[transformation_version] (
  [transformation_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [transformation_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [expression_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_transformation_version_f43ab338f814] PRIMARY KEY CLUSTERED ([transformation_version_pk]),
  CONSTRAINT [AK_model_transformation_version_8c050b95384a] UNIQUE NONCLUSTERED ([transformation_pk],[definition_digest]),
  CONSTRAINT [AK_model_transformation_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_transformation_version_1ea210a76243] UNIQUE NONCLUSTERED ([transformation_pk],[transformation_version_pk]),
  CONSTRAINT [AK_model_transformation_version_b65edaa79192] UNIQUE NONCLUSTERED ([transformation_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_transformation_version_38d6705a1156] CHECK ([object_kind]='TRANSFORMATION'),
  CONSTRAINT [CK_model_transformation_version_c577a9315e83] CHECK ((DATALENGTH([expression_profile])>0 AND DATALENGTH([expression_profile])=DATALENGTH(LTRIM(RTRIM([expression_profile]))) AND UNICODE(LEFT([expression_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([expression_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[mechanic] (
  [mechanic_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [mechanic_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_mechanic_0ec155a9fbab] PRIMARY KEY CLUSTERED ([mechanic_pk]),
  CONSTRAINT [AK_model_mechanic_6fb9870ebbd0] UNIQUE NONCLUSTERED ([namespace_pk],[mechanic_id]),
  CONSTRAINT [AK_model_mechanic_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_mechanic_8dfef6422e88] UNIQUE NONCLUSTERED ([mechanic_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_mechanic_981b1f02e45c] CHECK ([object_kind]='MECHANIC'),
  CONSTRAINT [CK_model_mechanic_2401c8c389ac] CHECK ((DATALENGTH([mechanic_id])>0 AND DATALENGTH([mechanic_id])=DATALENGTH(LTRIM(RTRIM([mechanic_id]))) AND UNICODE(LEFT([mechanic_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([mechanic_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[mechanic_version] (
  [mechanic_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [mechanic_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NULL,
  [mechanic_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [definition_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_mechanic_version_cd1260ad298e] PRIMARY KEY CLUSTERED ([mechanic_version_pk]),
  CONSTRAINT [AK_model_mechanic_version_bcb2703b8f00] UNIQUE NONCLUSTERED ([mechanic_pk],[definition_digest]),
  CONSTRAINT [AK_model_mechanic_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_mechanic_version_61ae3a3dd447] UNIQUE NONCLUSTERED ([mechanic_pk],[mechanic_version_pk]),
  CONSTRAINT [AK_model_mechanic_version_63b2bdce4b61] UNIQUE NONCLUSTERED ([mechanic_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_mechanic_version_981b1f02e45c] CHECK ([object_kind]='MECHANIC'),
  CONSTRAINT [CK_model_mechanic_version_954fbd2b3ba3] CHECK ((DATALENGTH([definition_profile])>0 AND DATALENGTH([definition_profile])=DATALENGTH(LTRIM(RTRIM([definition_profile]))) AND UNICODE(LEFT([definition_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([definition_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[port] (
  [port_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [port_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_port_3211419909e4] PRIMARY KEY CLUSTERED ([port_pk]),
  CONSTRAINT [AK_model_port_17a313173914] UNIQUE NONCLUSTERED ([namespace_pk],[port_id]),
  CONSTRAINT [AK_model_port_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_port_ff5170187ad8] UNIQUE NONCLUSTERED ([port_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_port_b3bfb9df412e] CHECK ([object_kind]='PORT'),
  CONSTRAINT [CK_model_port_e21900f30d18] CHECK ((DATALENGTH([port_id])>0 AND DATALENGTH([port_id])=DATALENGTH(LTRIM(RTRIM([port_id]))) AND UNICODE(LEFT([port_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([port_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[port_version] (
  [port_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [port_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NULL,
  [port_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_port_version_6008a02f3aa8] PRIMARY KEY CLUSTERED ([port_version_pk]),
  CONSTRAINT [AK_model_port_version_eb44af324b45] UNIQUE NONCLUSTERED ([port_pk],[definition_digest]),
  CONSTRAINT [AK_model_port_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_port_version_fe03078f44b7] UNIQUE NONCLUSTERED ([port_pk],[port_version_pk]),
  CONSTRAINT [AK_model_port_version_efcf86319926] UNIQUE NONCLUSTERED ([port_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_port_version_b3bfb9df412e] CHECK ([object_kind]='PORT'),
  CONSTRAINT [CK_model_port_version_d049b1508691] CHECK ((DATALENGTH([port_profile])>0 AND DATALENGTH([port_profile])=DATALENGTH(LTRIM(RTRIM([port_profile]))) AND UNICODE(LEFT([port_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([port_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider] (
  [provider_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [provider_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_provider_de4be832508a] PRIMARY KEY CLUSTERED ([provider_pk]),
  CONSTRAINT [AK_model_provider_d0e30bd260db] UNIQUE NONCLUSTERED ([namespace_pk],[provider_id]),
  CONSTRAINT [AK_model_provider_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_provider_c9ffc12320e5] UNIQUE NONCLUSTERED ([provider_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_provider_85026c97bc4f] CHECK ([object_kind]='PROVIDER'),
  CONSTRAINT [CK_model_provider_290ab3b34b3e] CHECK ((DATALENGTH([provider_id])>0 AND DATALENGTH([provider_id])=DATALENGTH(LTRIM(RTRIM([provider_id]))) AND UNICODE(LEFT([provider_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([provider_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_definition] (
  [provider_definition_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NULL,
  [declaration_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_definition_ef326537e30b] PRIMARY KEY CLUSTERED ([provider_definition_pk]),
  CONSTRAINT [AK_model_provider_definition_d172cc03f25d] UNIQUE NONCLUSTERED ([provider_pk],[definition_digest]),
  CONSTRAINT [AK_model_provider_definition_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_provider_definition_7539e2b68af0] UNIQUE NONCLUSTERED ([provider_pk],[provider_definition_pk]),
  CONSTRAINT [AK_model_provider_definition_197fbb357d5c] UNIQUE NONCLUSTERED ([provider_definition_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_provider_definition_85026c97bc4f] CHECK ([object_kind]='PROVIDER'),
  CONSTRAINT [CK_model_provider_definition_701cfcc47212] CHECK ((DATALENGTH([declaration_profile])>0 AND DATALENGTH([declaration_profile])=DATALENGTH(LTRIM(RTRIM([declaration_profile]))) AND UNICODE(LEFT([declaration_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([declaration_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_profile] (
  [provider_profile_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [provider_profile_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_provider_profile_e4e8b0592695] PRIMARY KEY CLUSTERED ([provider_profile_pk]),
  CONSTRAINT [AK_model_provider_profile_a996fab24b56] UNIQUE NONCLUSTERED ([namespace_pk],[provider_profile_id]),
  CONSTRAINT [AK_model_provider_profile_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_provider_profile_39882957d83d] UNIQUE NONCLUSTERED ([provider_profile_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_provider_profile_e5c7f2cf591e] CHECK ([object_kind]='PROVIDER_PROFILE'),
  CONSTRAINT [CK_model_provider_profile_bf65acb042ef] CHECK ((DATALENGTH([provider_profile_id])>0 AND DATALENGTH([provider_profile_id])=DATALENGTH(LTRIM(RTRIM([provider_profile_id]))) AND UNICODE(LEFT([provider_profile_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([provider_profile_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_profile_version] (
  [provider_profile_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_profile_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [profile_name] nvarchar(max) NULL,
  [profile_authority] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_profile_version_83c139ce8c61] PRIMARY KEY CLUSTERED ([provider_profile_version_pk]),
  CONSTRAINT [AK_model_provider_profile_version_c8a5457849f8] UNIQUE NONCLUSTERED ([provider_profile_pk],[definition_digest]),
  CONSTRAINT [AK_model_provider_profile_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_provider_profile_version_18d512ab6e2c] UNIQUE NONCLUSTERED ([provider_profile_pk],[provider_profile_version_pk]),
  CONSTRAINT [AK_model_provider_profile_version_3ce3b2d79f7f] UNIQUE NONCLUSTERED ([provider_profile_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_provider_profile_version_e5c7f2cf591e] CHECK ([object_kind]='PROVIDER_PROFILE'),
  CONSTRAINT [CK_model_provider_profile_version_cfc956ab1617] CHECK ((DATALENGTH([profile_authority])>0 AND DATALENGTH([profile_authority])=DATALENGTH(LTRIM(RTRIM([profile_authority]))) AND UNICODE(LEFT([profile_authority],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([profile_authority],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[blueprint] (
  [blueprint_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [blueprint_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_blueprint_11bb1dbc38d1] PRIMARY KEY CLUSTERED ([blueprint_pk]),
  CONSTRAINT [AK_model_blueprint_89b1d0981e1c] UNIQUE NONCLUSTERED ([namespace_pk],[blueprint_id]),
  CONSTRAINT [AK_model_blueprint_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_blueprint_d58ec0897b46] UNIQUE NONCLUSTERED ([blueprint_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_blueprint_e7589cf1aa49] CHECK ([object_kind]='BLUEPRINT'),
  CONSTRAINT [CK_model_blueprint_1fa72854be31] CHECK ((DATALENGTH([blueprint_id])>0 AND DATALENGTH([blueprint_id])=DATALENGTH(LTRIM(RTRIM([blueprint_id]))) AND UNICODE(LEFT([blueprint_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([blueprint_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[blueprint_version] (
  [blueprint_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [capability_pk] bigint NOT NULL,
  [capability_version_pk] bigint NOT NULL,
  [carrier_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_disposition] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_version_df08dc159ba2] PRIMARY KEY CLUSTERED ([blueprint_version_pk]),
  CONSTRAINT [AK_model_blueprint_version_bd1496616e7c] UNIQUE NONCLUSTERED ([blueprint_pk],[definition_digest]),
  CONSTRAINT [AK_model_blueprint_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_blueprint_version_40565439301f] UNIQUE NONCLUSTERED ([blueprint_pk],[blueprint_version_pk]),
  CONSTRAINT [AK_model_blueprint_version_46563658bc8a] UNIQUE NONCLUSTERED ([blueprint_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_blueprint_version_e7589cf1aa49] CHECK ([object_kind]='BLUEPRINT'),
  CONSTRAINT [CK_model_blueprint_version_dfaaf6408b15] CHECK ((DATALENGTH([carrier_profile])>0 AND DATALENGTH([carrier_profile])=DATALENGTH(LTRIM(RTRIM([carrier_profile]))) AND UNICODE(LEFT([carrier_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([carrier_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[authority] (
  [authority_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [authority_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_authority_b32b418e694d] PRIMARY KEY CLUSTERED ([authority_pk]),
  CONSTRAINT [AK_model_authority_bbe14e1be4af] UNIQUE NONCLUSTERED ([namespace_pk],[authority_id]),
  CONSTRAINT [AK_model_authority_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_authority_edd03ad97c88] UNIQUE NONCLUSTERED ([authority_pk],[semantic_object_pk]),
  CONSTRAINT [CK_model_authority_49d33dd20d31] CHECK ([object_kind]='AUTHORITY'),
  CONSTRAINT [CK_model_authority_c3839251289f] CHECK ((DATALENGTH([authority_id])>0 AND DATALENGTH([authority_id])=DATALENGTH(LTRIM(RTRIM([authority_id]))) AND UNICODE(LEFT([authority_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([authority_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[authority_definition] (
  [authority_definition_pk] bigint IDENTITY(1,1) NOT NULL,
  [authority_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [authority_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [authority_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_authority_definition_a14c24ea68bc] PRIMARY KEY CLUSTERED ([authority_definition_pk]),
  CONSTRAINT [AK_model_authority_definition_fbef32138d50] UNIQUE NONCLUSTERED ([authority_pk],[definition_digest]),
  CONSTRAINT [AK_model_authority_definition_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_authority_definition_a3407cf70d6d] UNIQUE NONCLUSTERED ([authority_pk],[authority_definition_pk]),
  CONSTRAINT [AK_model_authority_definition_97c3907fdad4] UNIQUE NONCLUSTERED ([authority_definition_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_authority_definition_49d33dd20d31] CHECK ([object_kind]='AUTHORITY'),
  CONSTRAINT [CK_model_authority_definition_2a1ec0d17cdc] CHECK ((DATALENGTH([authority_profile])>0 AND DATALENGTH([authority_profile])=DATALENGTH(LTRIM(RTRIM([authority_profile]))) AND UNICODE(LEFT([authority_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([authority_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[scenario] (
  [scenario_pk] bigint IDENTITY(1,1) NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [scenario_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_scenario_ee797d25e9d2] PRIMARY KEY CLUSTERED ([scenario_pk]),
  CONSTRAINT [AK_model_scenario_d99355b2bba0] UNIQUE NONCLUSTERED ([namespace_pk],[scenario_id]),
  CONSTRAINT [AK_model_scenario_803f49d72016] UNIQUE NONCLUSTERED ([semantic_object_pk]),
  CONSTRAINT [AK_model_scenario_96520949b565] UNIQUE NONCLUSTERED ([scenario_pk],[semantic_object_pk]),
  CONSTRAINT [AK_model_scenario_b21bc24c677f] UNIQUE NONCLUSTERED ([capability_pk],[scenario_id]),
  CONSTRAINT [AK_model_scenario_212ddc8759c0] UNIQUE NONCLUSTERED ([capability_pk],[scenario_pk]),
  CONSTRAINT [CK_model_scenario_5722261711af] CHECK ([object_kind]='SCENARIO'),
  CONSTRAINT [CK_model_scenario_7608be36a368] CHECK ((DATALENGTH([scenario_id])>0 AND DATALENGTH([scenario_id])=DATALENGTH(LTRIM(RTRIM([scenario_id]))) AND UNICODE(LEFT([scenario_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([scenario_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[scenario_version] (
  [scenario_version_pk] bigint IDENTITY(1,1) NOT NULL,
  [scenario_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [name] nvarchar(max) NOT NULL,
  [source_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_scenario_version_d350a81083bd] PRIMARY KEY CLUSTERED ([scenario_version_pk]),
  CONSTRAINT [AK_model_scenario_version_65937833eb9e] UNIQUE NONCLUSTERED ([scenario_pk],[definition_digest]),
  CONSTRAINT [AK_model_scenario_version_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [AK_model_scenario_version_4ec4967ac269] UNIQUE NONCLUSTERED ([scenario_pk],[scenario_version_pk]),
  CONSTRAINT [AK_model_scenario_version_ed973feca087] UNIQUE NONCLUSTERED ([scenario_version_pk],[semantic_object_definition_pk]),
  CONSTRAINT [CK_model_scenario_version_5722261711af] CHECK ([object_kind]='SCENARIO'),
  CONSTRAINT [CK_model_scenario_version_391cd16f2e69] CHECK ((DATALENGTH([source_profile])>0 AND DATALENGTH([source_profile])=DATALENGTH(LTRIM(RTRIM([source_profile]))) AND UNICODE(LEFT([source_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([source_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[capability_scenario] (
  [capability_pk] bigint NOT NULL,
  [capability_version_pk] bigint NOT NULL,
  [scenario_pk] bigint NOT NULL,
  [scenario_version_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_capability_scenario_d7000a20760f] PRIMARY KEY CLUSTERED ([capability_version_pk],[scenario_pk]),
  CONSTRAINT [AK_model_capability_scenario_26dc88b05c34] UNIQUE NONCLUSTERED ([capability_version_pk],[scenario_version_pk])
);
GO
CREATE TABLE [model].[capability_root_scenario] (
  [capability_version_pk] bigint NOT NULL,
  [scenario_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_capability_root_scenario_9469b5d8b15f] PRIMARY KEY CLUSTERED ([capability_version_pk])
);
GO
CREATE TABLE [model].[scenario_input] (
  [scenario_version_pk] bigint NOT NULL,
  [input_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [name] nvarchar(max) NULL,
  [input_contract_version_pk] bigint NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [contract_reference_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_scenario_input_d350a81083bd] PRIMARY KEY CLUSTERED ([scenario_version_pk]),
  CONSTRAINT [AK_model_scenario_input_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_scenario_input_37c0a4d2a67e] CHECK ([object_kind]='SCENARIO_INPUT'),
  CONSTRAINT [CK_model_scenario_input_b5418f07ca19] CHECK ([contract_reference_state] IN ('RESOLVED','ABSENT','EXPLICIT_NULL','UNRESOLVED','NOT_APPLICABLE')),
  CONSTRAINT [CK_model_scenario_input_044b3bb0efc5] CHECK (([contract_reference_state]='RESOLVED' AND [input_contract_version_pk] IS NOT NULL) OR ([contract_reference_state]<>'RESOLVED' AND [input_contract_version_pk] IS NULL)),
  CONSTRAINT [CK_model_scenario_input_bc1d0e3e2d6c] CHECK ((DATALENGTH([input_id])>0 AND DATALENGTH([input_id])=DATALENGTH(LTRIM(RTRIM([input_id]))) AND UNICODE(LEFT([input_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([input_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[scenario_event] (
  [scenario_version_pk] bigint NOT NULL,
  [event_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [name] nvarchar(max) NULL,
  [responsibility] nvarchar(max) NOT NULL,
  [execution_authority_version_pk] bigint NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [authority_reference_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_model_scenario_event_d350a81083bd] PRIMARY KEY CLUSTERED ([scenario_version_pk]),
  CONSTRAINT [AK_model_scenario_event_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_scenario_event_2b04d48e0ad7] CHECK ([object_kind]='SCENARIO_EVENT'),
  CONSTRAINT [CK_model_scenario_event_8a7211d9ee55] CHECK ([authority_reference_state] IN ('RESOLVED','ABSENT','EXPLICIT_NULL','UNRESOLVED','NOT_APPLICABLE')),
  CONSTRAINT [CK_model_scenario_event_158bbc66a482] CHECK (([authority_reference_state]='RESOLVED' AND [execution_authority_version_pk] IS NOT NULL) OR ([authority_reference_state]<>'RESOLVED' AND [execution_authority_version_pk] IS NULL)),
  CONSTRAINT [CK_model_scenario_event_4cf0c5dc13e6] CHECK ((DATALENGTH([event_id])>0 AND DATALENGTH([event_id])=DATALENGTH(LTRIM(RTRIM([event_id]))) AND UNICODE(LEFT([event_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([event_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[scenario_outcome] (
  [scenario_version_pk] bigint NOT NULL,
  [outcome_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [name] nvarchar(max) NULL,
  [experience] nvarchar(max) NOT NULL,
  [terminal] bit NULL,
  [terminal_disposition] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_scenario_outcome_d350a81083bd] PRIMARY KEY CLUSTERED ([scenario_version_pk]),
  CONSTRAINT [AK_model_scenario_outcome_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_scenario_outcome_989965d0d6b1] CHECK ([object_kind]='SCENARIO_OUTCOME'),
  CONSTRAINT [CK_model_scenario_outcome_896898e602bd] CHECK ((DATALENGTH([outcome_id])>0 AND DATALENGTH([outcome_id])=DATALENGTH(LTRIM(RTRIM([outcome_id]))) AND UNICODE(LEFT([outcome_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([outcome_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_scenario_outcome_bee46161dae0] CHECK ([terminal_disposition] IS NULL OR (DATALENGTH([terminal_disposition])>0 AND DATALENGTH([terminal_disposition])=DATALENGTH(LTRIM(RTRIM([terminal_disposition]))) AND UNICODE(LEFT([terminal_disposition],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([terminal_disposition],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[outcome_variant] (
  [outcome_variant_pk] bigint IDENTITY(1,1) NOT NULL,
  [scenario_version_pk] bigint NOT NULL,
  [variant_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [terminal] bit NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_outcome_variant_7df030ec378f] PRIMARY KEY CLUSTERED ([outcome_variant_pk]),
  CONSTRAINT [AK_model_outcome_variant_fe9fbee157d4] UNIQUE NONCLUSTERED ([scenario_version_pk],[variant_id]),
  CONSTRAINT [AK_model_outcome_variant_d08e91c98df0] UNIQUE NONCLUSTERED ([scenario_version_pk],[outcome_variant_pk]),
  CONSTRAINT [CK_model_outcome_variant_61b6d8e284ae] CHECK ((DATALENGTH([variant_id])>0 AND DATALENGTH([variant_id])=DATALENGTH(LTRIM(RTRIM([variant_id]))) AND UNICODE(LEFT([variant_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([variant_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[outcome_product] (
  [scenario_version_pk] bigint NOT NULL,
  [product_definition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_outcome_product_dbe9f2daef0c] PRIMARY KEY CLUSTERED ([scenario_version_pk],[product_definition_pk])
);
GO
CREATE TABLE [model].[outcome_variant_product] (
  [outcome_variant_pk] bigint NOT NULL,
  [product_definition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_outcome_variant_product_c3af520a85c7] PRIMARY KEY CLUSTERED ([outcome_variant_pk],[product_definition_pk])
);
GO
CREATE TABLE [model].[scenario_outcome_contract] (
  [scenario_version_pk] bigint NOT NULL,
  [contract_version_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_scenario_outcome_contract_d350a81083bd] PRIMARY KEY CLUSTERED ([scenario_version_pk])
);
GO
CREATE TABLE [model].[schema_object] (
  [schema_object_pk] bigint IDENTITY(1,1) NOT NULL,
  [content_digest] binary(32) NOT NULL,
  [dialect] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [content_object_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_schema_object_97c6d7ada933] PRIMARY KEY CLUSTERED ([schema_object_pk]),
  CONSTRAINT [AK_model_schema_object_054f8126d141] UNIQUE NONCLUSTERED ([content_digest]),
  CONSTRAINT [AK_model_schema_object_36b9754af42f] UNIQUE NONCLUSTERED ([content_object_pk]),
  CONSTRAINT [CK_model_schema_object_3cf54fee478f] CHECK ([dialect] IS NULL OR (DATALENGTH([dialect])>0 AND DATALENGTH([dialect])=DATALENGTH(LTRIM(RTRIM([dialect]))) AND UNICODE(LEFT([dialect],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([dialect],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[port_contract] (
  [port_version_pk] bigint NOT NULL,
  [direction] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [member_ordinal] int NOT NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [contract_version_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_port_contract_e6da1b44aa7f] PRIMARY KEY CLUSTERED ([port_version_pk],[direction],[member_ordinal]),
  CONSTRAINT [CK_model_port_contract_91bd8a8a0aa3] CHECK ([member_ordinal]>=0),
  CONSTRAINT [CK_model_port_contract_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[execution_operation] (
  [execution_operation_pk] bigint IDENTITY(1,1) NOT NULL,
  [execution_authority_version_pk] bigint NOT NULL,
  [operation_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [ordinal] int NOT NULL,
  [operation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_execution_operation_2dd7848b775d] PRIMARY KEY CLUSTERED ([execution_operation_pk]),
  CONSTRAINT [AK_model_execution_operation_89e8e9c522ad] UNIQUE NONCLUSTERED ([execution_authority_version_pk],[ordinal]),
  CONSTRAINT [AK_model_execution_operation_42e9e528211f] UNIQUE NONCLUSTERED ([execution_authority_version_pk],[execution_operation_pk]),
  CONSTRAINT [AK_model_execution_operation_b4a851f26b30] UNIQUE NONCLUSTERED ([execution_operation_pk],[operation_kind]),
  CONSTRAINT [CK_model_execution_operation_c30c969b2875] CHECK ([operation_id] IS NULL OR (DATALENGTH([operation_id])>0 AND DATALENGTH([operation_id])=DATALENGTH(LTRIM(RTRIM([operation_id]))) AND UNICODE(LEFT([operation_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([operation_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_execution_operation_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[operation_port_invocation] (
  [execution_operation_pk] bigint NOT NULL,
  [port_version_pk] bigint NOT NULL,
  [operation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_port_invocation_2dd7848b775d] PRIMARY KEY CLUSTERED ([execution_operation_pk]),
  CONSTRAINT [CK_model_operation_port_invocation_ca96da3c0da6] CHECK ([operation_kind]='invoke-port')
);
GO
CREATE TABLE [model].[operation_scenario_invocation] (
  [execution_operation_pk] bigint NOT NULL,
  [target_scenario_version_pk] bigint NOT NULL,
  [operation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_scenario_invocation_2dd7848b775d] PRIMARY KEY CLUSTERED ([execution_operation_pk]),
  CONSTRAINT [CK_model_operation_scenario_invocation_38aefe654a95] CHECK ([operation_kind]='invoke-scenario')
);
GO
CREATE TABLE [model].[operation_state_projection] (
  [execution_operation_pk] bigint NOT NULL,
  [transformation_version_pk] bigint NOT NULL,
  [operation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_state_projection_2dd7848b775d] PRIMARY KEY CLUSTERED ([execution_operation_pk]),
  CONSTRAINT [CK_model_operation_state_projection_92e96b24f3e0] CHECK ([operation_kind]='project-state')
);
GO
CREATE TABLE [model].[operation_mechanic] (
  [execution_operation_pk] bigint NOT NULL,
  [mechanic_version_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_mechanic_6ea1c3e4a6d2] PRIMARY KEY CLUSTERED ([execution_operation_pk],[mechanic_version_pk],[role])
);
GO
CREATE TABLE [model].[operation_predecessor] (
  [execution_authority_version_pk] bigint NOT NULL,
  [execution_operation_pk] bigint NOT NULL,
  [predecessor_operation_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_predecessor_b3b6dcc36c71] PRIMARY KEY CLUSTERED ([execution_operation_pk],[predecessor_operation_pk]),
  CONSTRAINT [CK_model_operation_predecessor_56b6846bc1cc] CHECK (execution_operation_pk<>predecessor_operation_pk)
);
GO
CREATE TABLE [model].[transformation_expression_node] (
  [expression_node_pk] bigint IDENTITY(1,1) NOT NULL,
  [transformation_version_pk] bigint NOT NULL,
  [node_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [node_pointer_key] AS CONVERT(varbinary(800),[node_pointer]) PERSISTED,
  [node_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [operator] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [literal_content_pk] bigint NULL,
  [reference_name] nvarchar(max) NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_transformation_expression_node_9d4746d24e9a] PRIMARY KEY CLUSTERED ([expression_node_pk]),
  CONSTRAINT [AK_model_transformation_expression_node_05dfd5cc624a] UNIQUE NONCLUSTERED ([transformation_version_pk],[node_pointer_key]),
  CONSTRAINT [AK_model_transformation_expression_node_0840c862dd68] UNIQUE NONCLUSTERED ([transformation_version_pk],[expression_node_pk]),
  CONSTRAINT [CK_model_transformation_expression_node_8d8e9d928d94] CHECK ([node_kind] IN ('OPERATOR','OBJECT','ARRAY','LITERAL','REFERENCE')),
  CONSTRAINT [CK_model_transformation_expression_node_2cc04437c0dc] CHECK ((node_kind='OPERATOR' AND operator IS NOT NULL AND literal_content_pk IS NULL AND reference_name IS NULL) OR (node_kind IN ('OBJECT','ARRAY') AND operator IS NULL AND literal_content_pk IS NULL AND reference_name IS NULL) OR (node_kind='LITERAL' AND operator IS NULL AND literal_content_pk IS NOT NULL AND reference_name IS NULL) OR (node_kind='REFERENCE' AND operator IS NULL AND literal_content_pk IS NULL AND reference_name IS NOT NULL)),
  CONSTRAINT [CK_model_transformation_expression_node_b24e133d5080] CHECK ([operator] IS NULL OR (DATALENGTH([operator])>0 AND DATALENGTH([operator])=DATALENGTH(LTRIM(RTRIM([operator]))) AND UNICODE(LEFT([operator],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([operator],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[transformation_expression_child] (
  [transformation_version_pk] bigint NOT NULL,
  [parent_node_pk] bigint NOT NULL,
  [child_node_pk] bigint NOT NULL,
  [member_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [member_name] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [member_name_key] AS CONVERT(varbinary(800),[member_name]) PERSISTED,
  [ordinal] int NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_transformation_expression_child_681a68a76198] PRIMARY KEY CLUSTERED ([parent_node_pk],[child_node_pk]),
  CONSTRAINT [AK_model_transformation_expression_child_6154224d57b5] UNIQUE NONCLUSTERED ([child_node_pk]),
  CONSTRAINT [CK_model_transformation_expression_child_deb7b8850d6e] CHECK (parent_node_pk<>child_node_pk),
  CONSTRAINT [CK_model_transformation_expression_child_91f464427a65] CHECK ((member_kind='OBJECT_MEMBER' AND member_name IS NOT NULL AND ordinal IS NULL) OR (member_kind='ARRAY_MEMBER' AND member_name IS NULL AND ordinal IS NOT NULL)),
  CONSTRAINT [CK_model_transformation_expression_child_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[transformation_root] (
  [transformation_version_pk] bigint NOT NULL,
  [expression_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_transformation_root_f43ab338f814] PRIMARY KEY CLUSTERED ([transformation_version_pk])
);
GO
CREATE TABLE [model].[expression_semantic_reference] (
  [expression_node_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [expected_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_expression_semantic_reference_9d4746d24e9a] PRIMARY KEY CLUSTERED ([expression_node_pk])
);
GO
CREATE TABLE [model].[operation_transformation] (
  [execution_operation_pk] bigint NOT NULL,
  [transformation_version_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_operation_transformation_f8d2b5298b4e] PRIMARY KEY CLUSTERED ([execution_operation_pk],[transformation_version_pk],[role])
);
GO
CREATE TABLE [model].[provider_port_implementation] (
  [provider_port_implementation_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [port_version_pk] bigint NOT NULL,
  [provider_profile_version_pk] bigint NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_port_implementation_5314caf22c9e] PRIMARY KEY CLUSTERED ([provider_port_implementation_pk]),
  CONSTRAINT [AK_model_provider_port_implementation_b39a7ee90d3d] UNIQUE NONCLUSTERED ([provider_definition_pk],[provider_port_implementation_pk],[port_version_pk]),
  CONSTRAINT [CK_model_provider_port_implementation_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_mechanic_implementation] (
  [provider_mechanic_implementation_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [mechanic_version_pk] bigint NOT NULL,
  [provider_profile_version_pk] bigint NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_mechanic_implementation_26806e490aee] PRIMARY KEY CLUSTERED ([provider_mechanic_implementation_pk]),
  CONSTRAINT [AK_model_provider_mechanic_implementation_7d92e42fef29] UNIQUE NONCLUSTERED ([provider_definition_pk],[provider_mechanic_implementation_pk],[mechanic_version_pk]),
  CONSTRAINT [CK_model_provider_mechanic_implementation_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_capability_implementation] (
  [provider_definition_pk] bigint NOT NULL,
  [capability_version_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_capability_implementation_393458b8939d] PRIMARY KEY CLUSTERED ([provider_definition_pk],[capability_version_pk],[role])
);
GO
CREATE TABLE [model].[provider_profile_constraint] (
  [provider_profile_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [constraint_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [constraint_term] nvarchar(max) NOT NULL,
  [operand_content_pk] bigint NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_profile_constraint_0db881ad2c01] PRIMARY KEY CLUSTERED ([provider_profile_version_pk],[ordinal]),
  CONSTRAINT [CK_model_provider_profile_constraint_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[provider_slot] (
  [provider_slot_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [slot_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [owner_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_slot_2d90e73aca32] PRIMARY KEY CLUSTERED ([provider_slot_pk]),
  CONSTRAINT [AK_model_provider_slot_b6ec7ebccfe8] UNIQUE NONCLUSTERED ([blueprint_version_pk],[slot_id]),
  CONSTRAINT [AK_model_provider_slot_269decc8ee11] UNIQUE NONCLUSTERED ([blueprint_version_pk],[provider_slot_pk]),
  CONSTRAINT [AK_model_provider_slot_a6e07252c220] UNIQUE NONCLUSTERED ([provider_slot_pk],[blueprint_version_pk],[owner_node_pk]),
  CONSTRAINT [CK_model_provider_slot_86e8545a543a] CHECK ((DATALENGTH([slot_id])>0 AND DATALENGTH([slot_id])=DATALENGTH(LTRIM(RTRIM([slot_id]))) AND UNICODE(LEFT([slot_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([slot_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[slot_port_requirement] (
  [slot_port_requirement_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [port_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_slot_port_requirement_eac8ab7019f4] PRIMARY KEY CLUSTERED ([slot_port_requirement_pk]),
  CONSTRAINT [AK_model_slot_port_requirement_cc0e8fbbd105] UNIQUE NONCLUSTERED ([provider_slot_pk],[ordinal]),
  CONSTRAINT [AK_model_slot_port_requirement_c32de64f55b5] UNIQUE NONCLUSTERED ([provider_slot_pk],[slot_port_requirement_pk],[port_version_pk]),
  CONSTRAINT [CK_model_slot_port_requirement_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_slot_port_requirement_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[slot_mechanic_requirement] (
  [slot_mechanic_requirement_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [mechanic_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_slot_mechanic_requirement_075521c34a69] PRIMARY KEY CLUSTERED ([slot_mechanic_requirement_pk]),
  CONSTRAINT [AK_model_slot_mechanic_requirement_cc0e8fbbd105] UNIQUE NONCLUSTERED ([provider_slot_pk],[ordinal]),
  CONSTRAINT [AK_model_slot_mechanic_requirement_52e6ef05422e] UNIQUE NONCLUSTERED ([provider_slot_pk],[slot_mechanic_requirement_pk],[mechanic_version_pk]),
  CONSTRAINT [CK_model_slot_mechanic_requirement_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_slot_mechanic_requirement_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[slot_profile_requirement] (
  [slot_profile_requirement_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [provider_profile_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_slot_profile_requirement_29b72d54822f] PRIMARY KEY CLUSTERED ([slot_profile_requirement_pk]),
  CONSTRAINT [AK_model_slot_profile_requirement_cc0e8fbbd105] UNIQUE NONCLUSTERED ([provider_slot_pk],[ordinal]),
  CONSTRAINT [AK_model_slot_profile_requirement_5bd2dfd7acdf] UNIQUE NONCLUSTERED ([provider_slot_pk],[slot_profile_requirement_pk],[provider_profile_version_pk]),
  CONSTRAINT [CK_model_slot_profile_requirement_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_slot_profile_requirement_22d997f80954] CHECK ([role] IS NULL OR (DATALENGTH([role])>0 AND DATALENGTH([role])=DATALENGTH(LTRIM(RTRIM([role]))) AND UNICODE(LEFT([role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[slot_profile_constraint] (
  [provider_slot_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [constraint_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [constraint_term] nvarchar(max) NOT NULL,
  [operand_content_pk] bigint NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_slot_profile_constraint_cc0e8fbbd105] PRIMARY KEY CLUSTERED ([provider_slot_pk],[ordinal]),
  CONSTRAINT [CK_model_slot_profile_constraint_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[binding_context] (
  [binding_context_pk] bigint IDENTITY(1,1) NOT NULL,
  [context_digest] binary(32) NOT NULL,
  [target_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [environment_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_profile_version_pk] bigint NULL,
  [canonical_content_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_binding_context_06cb5c3edcaa] PRIMARY KEY CLUSTERED ([binding_context_pk]),
  CONSTRAINT [AK_model_binding_context_8fda6c4eb4d6] UNIQUE NONCLUSTERED ([context_digest]),
  CONSTRAINT [CK_model_binding_context_82cab3784e9f] CHECK (target_id IS NOT NULL OR environment_id IS NOT NULL OR provider_profile_version_pk IS NOT NULL),
  CONSTRAINT [CK_model_binding_context_ea8eb32fd8e5] CHECK ([target_id] IS NULL OR (DATALENGTH([target_id])>0 AND DATALENGTH([target_id])=DATALENGTH(LTRIM(RTRIM([target_id]))) AND UNICODE(LEFT([target_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([target_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_binding_context_930c68e7610d] CHECK ([environment_id] IS NULL OR (DATALENGTH([environment_id])>0 AND DATALENGTH([environment_id])=DATALENGTH(LTRIM(RTRIM([environment_id]))) AND UNICODE(LEFT([environment_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([environment_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_binding_scope] (
  [provider_binding_scope_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [binding_context_pk] bigint NULL,
  [binding_role] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [selection_policy] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_binding_scope_ccd4a839acb4] PRIMARY KEY CLUSTERED ([provider_binding_scope_pk]),
  CONSTRAINT [AK_model_provider_binding_scope_1b7e76ba739e] UNIQUE NONCLUSTERED ([provider_binding_scope_pk],[provider_slot_pk],[selection_policy]),
  CONSTRAINT [CK_model_provider_binding_scope_2d7116c3e27a] CHECK ([selection_policy] IN ('SINGLE','ORDERED_SET')),
  CONSTRAINT [CK_model_provider_binding_scope_9790e0803bdb] CHECK ([binding_role] IS NULL OR (DATALENGTH([binding_role])>0 AND DATALENGTH([binding_role])=DATALENGTH(LTRIM(RTRIM([binding_role]))) AND UNICODE(LEFT([binding_role],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([binding_role],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[provider_binding] (
  [provider_binding_pk] bigint IDENTITY(1,1) NOT NULL,
  [provider_binding_scope_pk] bigint NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [selection_policy] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [ordinal] int NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_binding_753335fc4ca0] PRIMARY KEY CLUSTERED ([provider_binding_pk]),
  CONSTRAINT [AK_model_provider_binding_b7f362322d87] UNIQUE NONCLUSTERED ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]),
  CONSTRAINT [AK_model_provider_binding_765489c0f3cb] UNIQUE NONCLUSTERED ([provider_binding_scope_pk],[provider_definition_pk]),
  CONSTRAINT [CK_model_provider_binding_9f7ec692a64b] CHECK ((selection_policy='SINGLE' AND ordinal IS NULL) OR (selection_policy='ORDERED_SET' AND ordinal IS NOT NULL)),
  CONSTRAINT [CK_model_provider_binding_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[binding_port_implementation] (
  [provider_binding_pk] bigint NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [slot_port_requirement_pk] bigint NOT NULL,
  [port_version_pk] bigint NOT NULL,
  [provider_port_implementation_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_binding_port_implementation_3e5600b18aa3] PRIMARY KEY CLUSTERED ([provider_binding_pk],[slot_port_requirement_pk])
);
GO
CREATE TABLE [model].[binding_mechanic_implementation] (
  [provider_binding_pk] bigint NOT NULL,
  [provider_slot_pk] bigint NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [slot_mechanic_requirement_pk] bigint NOT NULL,
  [mechanic_version_pk] bigint NOT NULL,
  [provider_mechanic_implementation_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_binding_mechanic_implementation_0bcf2e701ef3] PRIMARY KEY CLUSTERED ([provider_binding_pk],[slot_mechanic_requirement_pk])
);
GO
CREATE TABLE [model].[provider_slot_operation] (
  [provider_slot_pk] bigint NOT NULL,
  [execution_operation_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_provider_slot_operation_d265d5c77acf] PRIMARY KEY CLUSTERED ([provider_slot_pk],[execution_operation_pk])
);
GO
CREATE TABLE [model].[blueprint_node] (
  [blueprint_node_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [node_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [node_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [altitude] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [projection_ordinal] int NOT NULL,
  [semantic_object_definition_pk] bigint NULL,
  [expected_semantic_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [terminal_disposition] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_node_76de1b6cda99] PRIMARY KEY CLUSTERED ([blueprint_node_pk]),
  CONSTRAINT [AK_model_blueprint_node_f63e73444ebd] UNIQUE NONCLUSTERED ([blueprint_version_pk],[node_id]),
  CONSTRAINT [AK_model_blueprint_node_89bacf6f12db] UNIQUE NONCLUSTERED ([blueprint_version_pk],[blueprint_node_pk]),
  CONSTRAINT [CK_model_blueprint_node_e6c0dd519fb9] CHECK (([semantic_object_definition_pk] IS NULL AND [expected_semantic_kind] IS NULL) OR ([semantic_object_definition_pk] IS NOT NULL AND [expected_semantic_kind] IS NOT NULL)),
  CONSTRAINT [CK_model_blueprint_node_5587db5c4f1e] CHECK ([altitude] IN ('CAPABILITY','OPERATION','MECHANIC','PROVIDER')),
  CONSTRAINT [CK_model_blueprint_node_96be918005ee] CHECK ([node_kind] IN ('state','responsibility','outcome','junction','convergence','provider-slot','terminal')),
  CONSTRAINT [CK_model_blueprint_node_f89afdb9e4a5] CHECK ((DATALENGTH([node_id])>0 AND DATALENGTH([node_id])=DATALENGTH(LTRIM(RTRIM([node_id]))) AND UNICODE(LEFT([node_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([node_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_blueprint_node_d55871c80e6b] CHECK ([projection_ordinal]>=0),
  CONSTRAINT [CK_model_blueprint_node_bee46161dae0] CHECK ([terminal_disposition] IS NULL OR (DATALENGTH([terminal_disposition])>0 AND DATALENGTH([terminal_disposition])=DATALENGTH(LTRIM(RTRIM([terminal_disposition]))) AND UNICODE(LEFT([terminal_disposition],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([terminal_disposition],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[blueprint_node_face] (
  [blueprint_node_pk] bigint NOT NULL,
  [position] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [expected_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_node_face_3e2a93dfbab6] PRIMARY KEY CLUSTERED ([blueprint_node_pk],[position]),
  CONSTRAINT [CK_model_blueprint_node_face_5d551220e94e] CHECK ([position] IN ('FIRST','ENERGIZED','RESULT'))
);
GO
CREATE TABLE [model].[blueprint_node_scenario] (
  [blueprint_version_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NOT NULL,
  [scenario_version_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_node_scenario_76de1b6cda99] PRIMARY KEY CLUSTERED ([blueprint_node_pk]),
  CONSTRAINT [AK_model_blueprint_node_scenario_1963acd8543b] UNIQUE NONCLUSTERED ([blueprint_version_pk],[blueprint_node_pk],[scenario_version_pk])
);
GO
CREATE TABLE [model].[blueprint_edge] (
  [blueprint_edge_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [edge_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [from_node_pk] bigint NOT NULL,
  [to_node_pk] bigint NOT NULL,
  [topology_role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [contract_relation] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [semantic_progress] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [source_scenario_version_pk] bigint NULL,
  [selecting_variant_pk] bigint NULL,
  [semantic_precedence] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [projection_ordinal] int NOT NULL,
  [binding_authority_definition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_edge_7c4029561e22] PRIMARY KEY CLUSTERED ([blueprint_edge_pk]),
  CONSTRAINT [AK_model_blueprint_edge_0f580f4cca16] UNIQUE NONCLUSTERED ([blueprint_version_pk],[edge_id]),
  CONSTRAINT [AK_model_blueprint_edge_4c1e2191a32e] UNIQUE NONCLUSTERED ([blueprint_version_pk],[blueprint_edge_pk]),
  CONSTRAINT [AK_model_blueprint_edge_a11fceebcfcf] UNIQUE NONCLUSTERED ([blueprint_edge_pk],[contract_relation]),
  CONSTRAINT [CK_model_blueprint_edge_a0e75ec1ffee] CHECK (([source_scenario_version_pk] IS NULL AND [selecting_variant_pk] IS NULL) OR ([source_scenario_version_pk] IS NOT NULL AND [selecting_variant_pk] IS NOT NULL)),
  CONSTRAINT [CK_model_blueprint_edge_1eabf8769054] CHECK ([topology_role] IN ('TRANSITION','BRANCH_ROUTE','FAN_OUT_MEMBER','CONVERGENCE_REQUIREMENT','ALTITUDE_DESCENT','BOUNDED_RETURN')),
  CONSTRAINT [CK_model_blueprint_edge_af44b1d6af0f] CHECK ([contract_relation] IS NULL OR [contract_relation] IN ('SATISFIES','REQUIRES')),
  CONSTRAINT [CK_model_blueprint_edge_4f0687ac600b] CHECK ([semantic_progress] IS NULL OR [semantic_progress] IN ('NARROWS','ESTABLISHES','TERMINATES','DESCENDS','BOUNDED_RETURN')),
  CONSTRAINT [CK_model_blueprint_edge_4aa33ee8a613] CHECK ([semantic_precedence] IN ('REQUIRED','INDEPENDENT')),
  CONSTRAINT [CK_model_blueprint_edge_e988edbaecfa] CHECK (topology_role<>'BRANCH_ROUTE' OR (selecting_variant_pk IS NOT NULL AND semantic_progress IS NOT NULL)),
  CONSTRAINT [CK_model_blueprint_edge_a31cba512283] CHECK (topology_role NOT IN ('TRANSITION','FAN_OUT_MEMBER','CONVERGENCE_REQUIREMENT','ALTITUDE_DESCENT') OR selecting_variant_pk IS NULL),
  CONSTRAINT [CK_model_blueprint_edge_a201b9c1f17d] CHECK (topology_role NOT IN ('TRANSITION','FAN_OUT_MEMBER','ALTITUDE_DESCENT') OR semantic_progress IS NOT NULL),
  CONSTRAINT [CK_model_blueprint_edge_1d8ee6353d0a] CHECK (topology_role<>'CONVERGENCE_REQUIREMENT' OR (contract_relation IS NOT NULL AND contract_relation='REQUIRES')),
  CONSTRAINT [CK_model_blueprint_edge_d93719d60642] CHECK (topology_role<>'ALTITUDE_DESCENT' OR (semantic_progress IS NOT NULL AND semantic_progress='DESCENDS')),
  CONSTRAINT [CK_model_blueprint_edge_57cb774751b5] CHECK (topology_role<>'BOUNDED_RETURN' OR (semantic_progress IS NOT NULL AND semantic_progress='BOUNDED_RETURN')),
  CONSTRAINT [CK_model_blueprint_edge_ae271505ad1e] CHECK ((DATALENGTH([edge_id])>0 AND DATALENGTH([edge_id])=DATALENGTH(LTRIM(RTRIM([edge_id]))) AND UNICODE(LEFT([edge_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([edge_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_blueprint_edge_d55871c80e6b] CHECK ([projection_ordinal]>=0)
);
GO
CREATE TABLE [model].[blueprint_edge_contract] (
  [blueprint_edge_pk] bigint NOT NULL,
  [contract_relation] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [product_definition_pk] bigint NOT NULL,
  [downstream_scenario_version_pk] bigint NOT NULL,
  [compatibility_authority_definition_pk] bigint NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_edge_contract_7c4029561e22] PRIMARY KEY CLUSTERED ([blueprint_edge_pk]),
  CONSTRAINT [CK_model_blueprint_edge_contract_b1ff2c019934] CHECK ([contract_relation] IN ('SATISFIES','REQUIRES'))
);
GO
CREATE TABLE [model].[blueprint_convergence_requirement] (
  [blueprint_version_pk] bigint NOT NULL,
  [convergence_node_pk] bigint NOT NULL,
  [product_definition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_convergence_requirement_4248e028dc7e] PRIMARY KEY CLUSTERED ([convergence_node_pk],[product_definition_pk])
);
GO
CREATE TABLE [model].[blueprint_fan_out_set] (
  [blueprint_fan_out_set_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [fan_out_set_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_fan_out_set_d8c22a06731d] PRIMARY KEY CLUSTERED ([blueprint_fan_out_set_pk]),
  CONSTRAINT [AK_model_blueprint_fan_out_set_cd1f797af474] UNIQUE NONCLUSTERED ([blueprint_version_pk],[fan_out_set_id]),
  CONSTRAINT [AK_model_blueprint_fan_out_set_7196b5b79908] UNIQUE NONCLUSTERED ([blueprint_version_pk],[blueprint_fan_out_set_pk]),
  CONSTRAINT [CK_model_blueprint_fan_out_set_d051e702178c] CHECK ((DATALENGTH([fan_out_set_id])>0 AND DATALENGTH([fan_out_set_id])=DATALENGTH(LTRIM(RTRIM([fan_out_set_id]))) AND UNICODE(LEFT([fan_out_set_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([fan_out_set_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[blueprint_fan_out_member] (
  [blueprint_version_pk] bigint NOT NULL,
  [blueprint_fan_out_set_pk] bigint NOT NULL,
  [blueprint_edge_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_fan_out_member_c0f04590b5d6] PRIMARY KEY CLUSTERED ([blueprint_fan_out_set_pk],[blueprint_edge_pk]),
  CONSTRAINT [AK_model_blueprint_fan_out_member_7c4029561e22] UNIQUE NONCLUSTERED ([blueprint_edge_pk])
);
GO
CREATE TABLE [model].[blueprint_bounded_return] (
  [blueprint_edge_pk] bigint NOT NULL,
  [return_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [declared_bound_content_pk] bigint NOT NULL,
  [authority_definition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_blueprint_bounded_return_7c4029561e22] PRIMARY KEY CLUSTERED ([blueprint_edge_pk]),
  CONSTRAINT [CK_model_blueprint_bounded_return_b6949c911072] CHECK ([return_kind] IN ('REPAIR','RESUMPTION','ITERATION'))
);
GO
CREATE TABLE [model].[fixture] (
  [fixture_pk] bigint IDENTITY(1,1) NOT NULL,
  [owner_definition_pk] bigint NOT NULL,
  [fixture_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [fixture_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_3dc8e0709e86] PRIMARY KEY CLUSTERED ([fixture_pk]),
  CONSTRAINT [AK_model_fixture_1da62aab3c59] UNIQUE NONCLUSTERED ([owner_definition_pk],[fixture_id]),
  CONSTRAINT [AK_model_fixture_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_fixture_2428135a39c7] CHECK ([object_kind]='FIXTURE'),
  CONSTRAINT [CK_model_fixture_e54146529b25] CHECK ((DATALENGTH([fixture_id])>0 AND DATALENGTH([fixture_id])=DATALENGTH(LTRIM(RTRIM([fixture_id]))) AND UNICODE(LEFT([fixture_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([fixture_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_fixture_1b4c97718028] CHECK ((DATALENGTH([fixture_profile])>0 AND DATALENGTH([fixture_profile])=DATALENGTH(LTRIM(RTRIM([fixture_profile]))) AND UNICODE(LEFT([fixture_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([fixture_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[fixture_case] (
  [fixture_case_pk] bigint IDENTITY(1,1) NOT NULL,
  [fixture_pk] bigint NOT NULL,
  [case_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [ordinal] int NOT NULL,
  [input_content_pk] bigint NOT NULL,
  [expected_disposition] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [terminal_scenario_version_pk] bigint NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_case_0bbd6178664f] PRIMARY KEY CLUSTERED ([fixture_case_pk]),
  CONSTRAINT [AK_model_fixture_case_099c0d1d96a0] UNIQUE NONCLUSTERED ([fixture_pk],[ordinal]),
  CONSTRAINT [AK_model_fixture_case_984a7b2ecc9f] UNIQUE NONCLUSTERED ([fixture_pk],[fixture_case_pk]),
  CONSTRAINT [CK_model_fixture_case_accd780ae0bb] CHECK ([case_id] IS NULL OR (DATALENGTH([case_id])>0 AND DATALENGTH([case_id])=DATALENGTH(LTRIM(RTRIM([case_id]))) AND UNICODE(LEFT([case_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([case_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_fixture_case_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_fixture_case_8ba0196b8201] CHECK ([expected_disposition] IS NULL OR (DATALENGTH([expected_disposition])>0 AND DATALENGTH([expected_disposition])=DATALENGTH(LTRIM(RTRIM([expected_disposition]))) AND UNICODE(LEFT([expected_disposition],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([expected_disposition],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[fixture_assertion] (
  [fixture_assertion_pk] bigint IDENTITY(1,1) NOT NULL,
  [fixture_case_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [condition_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [path] nvarchar(max) NOT NULL,
  [operator] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [expected_value_content_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_assertion_a86b9466e73b] PRIMARY KEY CLUSTERED ([fixture_assertion_pk]),
  CONSTRAINT [AK_model_fixture_assertion_1abd2345ecd2] UNIQUE NONCLUSTERED ([fixture_case_pk],[ordinal]),
  CONSTRAINT [CK_model_fixture_assertion_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_fixture_assertion_196f3e4b007f] CHECK ([condition_id] IS NULL OR (DATALENGTH([condition_id])>0 AND DATALENGTH([condition_id])=DATALENGTH(LTRIM(RTRIM([condition_id]))) AND UNICODE(LEFT([condition_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([condition_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_fixture_assertion_88059510b5c6] CHECK ((DATALENGTH([operator])>0 AND DATALENGTH([operator])=DATALENGTH(LTRIM(RTRIM([operator]))) AND UNICODE(LEFT([operator],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([operator],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[fixture_scenario_step] (
  [fixture_case_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [scenario_version_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_scenario_step_1abd2345ecd2] PRIMARY KEY CLUSTERED ([fixture_case_pk],[ordinal]),
  CONSTRAINT [CK_model_fixture_scenario_step_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[fixture_port_outcome] (
  [fixture_case_pk] bigint NOT NULL,
  [port_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [content_object_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_port_outcome_14b529830528] PRIMARY KEY CLUSTERED ([fixture_case_pk],[port_version_pk],[ordinal]),
  CONSTRAINT [CK_model_fixture_port_outcome_6f9d4a68a8fd] CHECK ([ordinal]>=0)
);
GO
CREATE TABLE [model].[observable_condition] (
  [observable_condition_pk] bigint IDENTITY(1,1) NOT NULL,
  [owner_definition_pk] bigint NOT NULL,
  [condition_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [statement] nvarchar(max) NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_observable_condition_ea0496d70763] PRIMARY KEY CLUSTERED ([observable_condition_pk]),
  CONSTRAINT [AK_model_observable_condition_045350218214] UNIQUE NONCLUSTERED ([owner_definition_pk],[condition_id]),
  CONSTRAINT [AK_model_observable_condition_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_observable_condition_b6ffa8bbbf27] CHECK ([object_kind]='OBSERVABLE_CONDITION'),
  CONSTRAINT [CK_model_observable_condition_a81b1eca6fb4] CHECK ((DATALENGTH([condition_id])>0 AND DATALENGTH([condition_id])=DATALENGTH(LTRIM(RTRIM([condition_id]))) AND UNICODE(LEFT([condition_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([condition_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[fixture_assertion_condition] (
  [fixture_assertion_pk] bigint NOT NULL,
  [observable_condition_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_fixture_assertion_condition_c08ef4063397] PRIMARY KEY CLUSTERED ([fixture_assertion_pk],[observable_condition_pk])
);
GO
CREATE TABLE [model].[proof_obligation] (
  [proof_obligation_pk] bigint IDENTITY(1,1) NOT NULL,
  [owner_definition_pk] bigint NOT NULL,
  [proof_obligation_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [obligation_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [statement] nvarchar(max) NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_proof_obligation_152bc5e394af] PRIMARY KEY CLUSTERED ([proof_obligation_pk]),
  CONSTRAINT [AK_model_proof_obligation_9c2cdb56ce67] UNIQUE NONCLUSTERED ([owner_definition_pk],[proof_obligation_id]),
  CONSTRAINT [AK_model_proof_obligation_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_proof_obligation_83bd1452b590] CHECK ([object_kind]='PROOF_OBLIGATION'),
  CONSTRAINT [CK_model_proof_obligation_ed52cace2648] CHECK ((DATALENGTH([proof_obligation_id])>0 AND DATALENGTH([proof_obligation_id])=DATALENGTH(LTRIM(RTRIM([proof_obligation_id]))) AND UNICODE(LEFT([proof_obligation_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([proof_obligation_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[proof_obligation_subject] (
  [proof_obligation_pk] bigint NOT NULL,
  [subject_definition_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_proof_obligation_subject_0bcdbae421d1] PRIMARY KEY CLUSTERED ([proof_obligation_pk],[subject_definition_pk],[role])
);
GO
CREATE TABLE [model].[proof_obligation_fixture] (
  [proof_obligation_pk] bigint NOT NULL,
  [fixture_case_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_proof_obligation_fixture_c6baa0caf237] PRIMARY KEY CLUSTERED ([proof_obligation_pk],[fixture_case_pk],[role])
);
GO
CREATE TABLE [model].[c4_context] (
  [c4_context_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [element_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [realization_authority_definition_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_context_5f8ca0c8a69b] PRIMARY KEY CLUSTERED ([c4_context_pk]),
  CONSTRAINT [AK_model_c4_context_9df481e5e2f6] UNIQUE NONCLUSTERED ([blueprint_version_pk],[element_id]),
  CONSTRAINT [AK_model_c4_context_c68a6c7cfe2c] UNIQUE NONCLUSTERED ([blueprint_version_pk],[c4_context_pk]),
  CONSTRAINT [AK_model_c4_context_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_c4_context_be92a49fa97a] CHECK ([object_kind]='C4_CONTEXT'),
  CONSTRAINT [CK_model_c4_context_df482eca7e9b] CHECK ((DATALENGTH([element_id])>0 AND DATALENGTH([element_id])=DATALENGTH(LTRIM(RTRIM([element_id]))) AND UNICODE(LEFT([element_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([element_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[c4_container] (
  [c4_container_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [element_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [realization_authority_definition_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [c4_context_pk] bigint NULL,
  CONSTRAINT [PK_model_c4_container_ed80edcc10f8] PRIMARY KEY CLUSTERED ([c4_container_pk]),
  CONSTRAINT [AK_model_c4_container_9df481e5e2f6] UNIQUE NONCLUSTERED ([blueprint_version_pk],[element_id]),
  CONSTRAINT [AK_model_c4_container_4e2f93f247dc] UNIQUE NONCLUSTERED ([blueprint_version_pk],[c4_container_pk]),
  CONSTRAINT [AK_model_c4_container_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_c4_container_bfa446f38399] CHECK ([object_kind]='C4_CONTAINER'),
  CONSTRAINT [CK_model_c4_container_df482eca7e9b] CHECK ((DATALENGTH([element_id])>0 AND DATALENGTH([element_id])=DATALENGTH(LTRIM(RTRIM([element_id]))) AND UNICODE(LEFT([element_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([element_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[c4_component] (
  [c4_component_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [element_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [realization_authority_definition_pk] bigint NOT NULL,
  [semantic_object_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [namespace_pk] bigint NOT NULL,
  [definition_digest] binary(32) NOT NULL,
  [object_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  [c4_container_pk] bigint NULL,
  CONSTRAINT [PK_model_c4_component_e8e6a7d8c0a4] PRIMARY KEY CLUSTERED ([c4_component_pk]),
  CONSTRAINT [AK_model_c4_component_9df481e5e2f6] UNIQUE NONCLUSTERED ([blueprint_version_pk],[element_id]),
  CONSTRAINT [AK_model_c4_component_7699c39afe34] UNIQUE NONCLUSTERED ([blueprint_version_pk],[c4_component_pk]),
  CONSTRAINT [AK_model_c4_component_524212dcbc38] UNIQUE NONCLUSTERED ([semantic_object_definition_pk]),
  CONSTRAINT [CK_model_c4_component_4d3462840803] CHECK ([object_kind]='C4_COMPONENT'),
  CONSTRAINT [CK_model_c4_component_df482eca7e9b] CHECK ((DATALENGTH([element_id])>0 AND DATALENGTH([element_id])=DATALENGTH(LTRIM(RTRIM([element_id]))) AND UNICODE(LEFT([element_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([element_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[c4_code_mapping] (
  [c4_code_mapping_pk] bigint IDENTITY(1,1) NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [ordinal] int NOT NULL,
  [element_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [c4_component_pk] bigint NULL,
  [realization_authority_definition_pk] bigint NOT NULL,
  [code_locator] nvarchar(max) NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_code_mapping_13407f1f4013] PRIMARY KEY CLUSTERED ([c4_code_mapping_pk]),
  CONSTRAINT [AK_model_c4_code_mapping_e862dee64897] UNIQUE NONCLUSTERED ([blueprint_version_pk],[ordinal]),
  CONSTRAINT [AK_model_c4_code_mapping_87ff7fd03da4] UNIQUE NONCLUSTERED ([blueprint_version_pk],[c4_code_mapping_pk]),
  CONSTRAINT [CK_model_c4_code_mapping_6f9d4a68a8fd] CHECK ([ordinal]>=0),
  CONSTRAINT [CK_model_c4_code_mapping_f88fd0b6531f] CHECK ([element_id] IS NULL OR (DATALENGTH([element_id])>0 AND DATALENGTH([element_id])=DATALENGTH(LTRIM(RTRIM([element_id]))) AND UNICODE(LEFT([element_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([element_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[c4_context_node] (
  [blueprint_version_pk] bigint NOT NULL,
  [c4_context_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_context_node_df3dc6e546e9] PRIMARY KEY CLUSTERED ([c4_context_pk],[blueprint_node_pk])
);
GO
CREATE TABLE [model].[c4_container_node] (
  [blueprint_version_pk] bigint NOT NULL,
  [c4_container_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_container_node_3f91dbf0de63] PRIMARY KEY CLUSTERED ([c4_container_pk],[blueprint_node_pk])
);
GO
CREATE TABLE [model].[c4_component_node] (
  [blueprint_version_pk] bigint NOT NULL,
  [c4_component_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_component_node_79a1ab8d899b] PRIMARY KEY CLUSTERED ([c4_component_pk],[blueprint_node_pk])
);
GO
CREATE TABLE [model].[c4_code_mapping_node] (
  [blueprint_version_pk] bigint NOT NULL,
  [c4_code_mapping_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NOT NULL,
  [_owner_definition_pk] bigint NOT NULL,
  [_canonical_pointer] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [_canonical_pointer_key] AS CONVERT(varbinary(800),[_canonical_pointer]) PERSISTED,
  CONSTRAINT [PK_model_c4_code_mapping_node_3f723676fff8] PRIMARY KEY CLUSTERED ([c4_code_mapping_pk],[blueprint_node_pk])
);
GO
CREATE TABLE [model].[observed_semantic_graph_transition] (
  [source_observation_pk] bigint NOT NULL,
  [transition_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [from_scenario_ref] nvarchar(max) NULL,
  [from_outcome_ref] nvarchar(max) NULL,
  [to_scenario_ref] nvarchar(max) NULL,
  [to_input_ref] nvarchar(max) NULL,
  [declared_topology] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [declared_progress] nvarchar(400) COLLATE Latin1_General_100_BIN2 NULL,
  [selected_variant_ref] nvarchar(max) NULL,
  CONSTRAINT [PK_model_observed_semantic_graph_transition_c2be5368d838] PRIMARY KEY CLUSTERED ([source_observation_pk]),
  CONSTRAINT [CK_model_observed_semantic_graph_transition_cdf2540ddcac] CHECK ([transition_id] IS NULL OR (DATALENGTH([transition_id])>0 AND DATALENGTH([transition_id])=DATALENGTH(LTRIM(RTRIM([transition_id]))) AND UNICODE(LEFT([transition_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([transition_id],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_observed_semantic_graph_transition_77ef8e7eb4ae] CHECK ([declared_topology] IS NULL OR (DATALENGTH([declared_topology])>0 AND DATALENGTH([declared_topology])=DATALENGTH(LTRIM(RTRIM([declared_topology]))) AND UNICODE(LEFT([declared_topology],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([declared_topology],1)) NOT IN(9,10,13))),
  CONSTRAINT [CK_model_observed_semantic_graph_transition_6a1b614907c3] CHECK ([declared_progress] IS NULL OR (DATALENGTH([declared_progress])>0 AND DATALENGTH([declared_progress])=DATALENGTH(LTRIM(RTRIM([declared_progress]))) AND UNICODE(LEFT([declared_progress],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([declared_progress],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [model].[observed_execution_scenario_invocation] (
  [source_observation_pk] bigint NOT NULL,
  [execution_authority_ref] nvarchar(max) NULL,
  [operation_ordinal] int NOT NULL,
  [target_scenario_ref] nvarchar(max) NULL,
  CONSTRAINT [PK_model_observed_execution_scenario_invocation_c2be5368d838] PRIMARY KEY CLUSTERED ([source_observation_pk]),
  CONSTRAINT [CK_model_observed_execution_scenario_invocation_3bac19c6fc07] CHECK ([operation_ordinal]>=0)
);
GO
CREATE TABLE [model].[observed_transition_resolution] (
  [estate_model_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [source_scenario_version_pk] bigint NOT NULL,
  [target_scenario_version_pk] bigint NOT NULL,
  [selecting_variant_pk] bigint NULL,
  CONSTRAINT [PK_model_observed_transition_resolution_e8f3aa6d65ac] PRIMARY KEY CLUSTERED ([estate_model_pk],[source_observation_pk])
);
GO
CREATE TABLE [model].[observed_invocation_resolution] (
  [estate_model_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [execution_operation_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_observed_invocation_resolution_e8f3aa6d65ac] PRIMARY KEY CLUSTERED ([estate_model_pk],[source_observation_pk])
);
GO
CREATE TABLE [model].[blueprint_observed_transition_mapping] (
  [estate_model_pk] bigint NOT NULL,
  [blueprint_edge_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [mapping_authority_definition_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_blueprint_observed_transition_mapping_16fc9766b520] PRIMARY KEY CLUSTERED ([estate_model_pk],[blueprint_edge_pk],[source_observation_pk],[mapping_authority_definition_pk])
);
GO
CREATE TABLE [model].[blueprint_observed_invocation_mapping] (
  [estate_model_pk] bigint NOT NULL,
  [blueprint_edge_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [mapping_authority_definition_pk] bigint NOT NULL,
  CONSTRAINT [PK_model_blueprint_observed_invocation_mapping_16fc9766b520] PRIMARY KEY CLUSTERED ([estate_model_pk],[blueprint_edge_pk],[source_observation_pk],[mapping_authority_definition_pk])
);
GO
CREATE TABLE [analysis].[integrity_rule] (
  [integrity_rule_pk] bigint IDENTITY(1,1) NOT NULL,
  [rule_id] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [rule_digest] binary(32) NOT NULL,
  [layer] tinyint NOT NULL,
  [rule_content_pk] bigint NOT NULL,
  CONSTRAINT [PK_analysis_integrity_rule_1ed460bcc7ad] PRIMARY KEY CLUSTERED ([integrity_rule_pk]),
  CONSTRAINT [AK_analysis_integrity_rule_2d82aaf900c4] UNIQUE NONCLUSTERED ([rule_id],[rule_digest]),
  CONSTRAINT [CK_analysis_integrity_rule_b9a10bad0f76] CHECK (layer IN (1,2)),
  CONSTRAINT [CK_analysis_integrity_rule_12fbbb26c91b] CHECK ((DATALENGTH([rule_id])>0 AND DATALENGTH([rule_id])=DATALENGTH(LTRIM(RTRIM([rule_id]))) AND UNICODE(LEFT([rule_id],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([rule_id],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [analysis].[assessment] (
  [assessment_pk] bigint IDENTITY(1,1) NOT NULL,
  [estate_model_pk] bigint NOT NULL,
  [integrity_rule_pk] bigint NOT NULL,
  [assessment_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [scope_digest] binary(32) NOT NULL,
  [input_set_digest] binary(32) NOT NULL,
  [evaluation_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [evaluated_at] datetime2(7) NULL,
  CONSTRAINT [PK_analysis_assessment_5d2fe613941d] PRIMARY KEY CLUSTERED ([assessment_pk]),
  CONSTRAINT [AK_analysis_assessment_6fbb920075d9] UNIQUE NONCLUSTERED ([estate_model_pk],[integrity_rule_pk],[assessment_kind],[scope_digest],[input_set_digest]),
  CONSTRAINT [AK_analysis_assessment_a1186643516d] UNIQUE NONCLUSTERED ([assessment_pk],[assessment_kind]),
  CONSTRAINT [CK_analysis_assessment_ee93f9f222a5] CHECK ([evaluation_state] IN ('EVALUATED','NOT_EVALUATED','OUTSIDE_CURRENT_MODEL'))
);
GO
CREATE TABLE [analysis].[assessment_source_input] (
  [assessment_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_assessment_source_input_d0e40e33faaa] PRIMARY KEY CLUSTERED ([assessment_pk],[source_observation_pk],[role])
);
GO
CREATE TABLE [analysis].[assessment_definition_input] (
  [assessment_pk] bigint NOT NULL,
  [semantic_object_definition_pk] bigint NOT NULL,
  [role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_assessment_definition_input_fcba3a2b539a] PRIMARY KEY CLUSTERED ([assessment_pk],[semantic_object_definition_pk],[role])
);
GO
CREATE TABLE [analysis].[integrity_finding] (
  [integrity_finding_pk] bigint IDENTITY(1,1) NOT NULL,
  [assessment_pk] bigint NOT NULL,
  [finding_digest] binary(32) NOT NULL,
  [finding_code] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [severity] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_observation_pk] bigint NULL,
  [subject_definition_pk] bigint NULL,
  [expected_content_pk] bigint NULL,
  [observed_content_pk] bigint NULL,
  [message] nvarchar(max) NOT NULL,
  CONSTRAINT [PK_analysis_integrity_finding_c2406dd79a2a] PRIMARY KEY CLUSTERED ([integrity_finding_pk]),
  CONSTRAINT [AK_analysis_integrity_finding_28a23edb28f1] UNIQUE NONCLUSTERED ([assessment_pk],[finding_digest]),
  CONSTRAINT [CK_analysis_integrity_finding_3215eab40a1d] CHECK ([severity] IN ('INFO','WARNING','ERROR'))
);
GO
CREATE TABLE [analysis].[unresolved_reference] (
  [estate_model_pk] bigint NOT NULL,
  [source_observation_pk] bigint NOT NULL,
  [reference_role] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [resolution_state] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [finding_pk] bigint NULL,
  CONSTRAINT [PK_analysis_unresolved_reference_5cefb1810b06] PRIMARY KEY CLUSTERED ([estate_model_pk],[source_observation_pk],[reference_role]),
  CONSTRAINT [CK_analysis_unresolved_reference_114d63609dd1] CHECK ([resolution_state] IN ('MISSING_ID','MISSING_TARGET','AMBIGUOUS_TARGET','WRONG_KIND','PROFILE_UNSUPPORTED','NAMESPACE_UNMAPPED','DEFINITION_UNRESOLVED'))
);
GO
CREATE TABLE [analysis].[compatibility_assessment] (
  [assessment_pk] bigint NOT NULL,
  [producer_contract_version_pk] bigint NOT NULL,
  [consumer_contract_version_pk] bigint NOT NULL,
  [authority_definition_pk] bigint NULL,
  [result_code] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [assessment_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_compatibility_assessment_5d2fe613941d] PRIMARY KEY CLUSTERED ([assessment_pk]),
  CONSTRAINT [CK_analysis_compatibility_assessment_6e4f9afa0ba4] CHECK ([assessment_kind]='COMPATIBILITY'),
  CONSTRAINT [CK_analysis_compatibility_assessment_f2e16b432176] CHECK ([result_code] IS NULL OR [result_code] IN ('COMPATIBLE','INCOMPATIBLE'))
);
GO
CREATE TABLE [analysis].[coverage_assessment] (
  [assessment_pk] bigint NOT NULL,
  [source_profile] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [count_unit] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [total_count] bigint NOT NULL,
  [normalized_count] bigint NOT NULL,
  [unresolved_count] bigint NOT NULL,
  [unsupported_count] bigint NOT NULL,
  [outside_count] bigint NOT NULL,
  [assessment_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_coverage_assessment_5d2fe613941d] PRIMARY KEY CLUSTERED ([assessment_pk]),
  CONSTRAINT [CK_analysis_coverage_assessment_d148af71b8d7] CHECK ([assessment_kind]='COVERAGE'),
  CONSTRAINT [CK_analysis_coverage_assessment_4430f4a864e7] CHECK (total_count>=0 AND normalized_count>=0 AND unresolved_count>=0 AND unsupported_count>=0 AND outside_count>=0 AND total_count=normalized_count+unresolved_count+unsupported_count+outside_count),
  CONSTRAINT [CK_analysis_coverage_assessment_cd00e7e56c36] CHECK ([count_unit] IN ('APPEARANCE','OBSERVATION')),
  CONSTRAINT [CK_analysis_coverage_assessment_391cd16f2e69] CHECK ((DATALENGTH([source_profile])>0 AND DATALENGTH([source_profile])=DATALENGTH(LTRIM(RTRIM([source_profile]))) AND UNICODE(LEFT([source_profile],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([source_profile],1)) NOT IN(9,10,13)))
);
GO
CREATE TABLE [analysis].[circuit_assessment] (
  [assessment_pk] bigint NOT NULL,
  [blueprint_version_pk] bigint NOT NULL,
  [blueprint_node_pk] bigint NULL,
  [result_code] varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
  [assessment_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_circuit_assessment_5d2fe613941d] PRIMARY KEY CLUSTERED ([assessment_pk]),
  CONSTRAINT [CK_analysis_circuit_assessment_5e53d290b441] CHECK ([assessment_kind]='CIRCUIT'),
  CONSTRAINT [CK_analysis_circuit_assessment_5a76358e1376] CHECK ([result_code] IS NULL OR [result_code] IN ('CHECKED_CLEAR','FINDINGS','INCOMPLETE','NOT_APPLICABLE'))
);
GO
CREATE TABLE [analysis].[provider_qualification_assessment] (
  [assessment_pk] bigint NOT NULL,
  [provider_definition_pk] bigint NOT NULL,
  [provider_profile_version_pk] bigint NULL,
  [provider_slot_pk] bigint NULL,
  [authority_definition_pk] bigint NOT NULL,
  [rule_definition_pk] bigint NOT NULL,
  [result_code] nvarchar(400) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [effective_until] datetime2(7) NULL,
  [source_observation_pk] bigint NOT NULL,
  [assessment_kind] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
  CONSTRAINT [PK_analysis_provider_qualification_assessment_5d2fe613941d] PRIMARY KEY CLUSTERED ([assessment_pk]),
  CONSTRAINT [CK_analysis_provider_qualification_assessment_5400feb9a5d4] CHECK ([assessment_kind]='PROVIDER_QUALIFICATION'),
  CONSTRAINT [CK_analysis_provider_qualification_assessment_c96038829403] CHECK ((DATALENGTH([result_code])>0 AND DATALENGTH([result_code])=DATALENGTH(LTRIM(RTRIM([result_code]))) AND UNICODE(LEFT([result_code],1)) NOT IN(9,10,13) AND UNICODE(RIGHT([result_code],1)) NOT IN(9,10,13)))
);
GO
ALTER TABLE [source].[source_appearance] WITH CHECK ADD CONSTRAINT [FK_source_source_appearance_c77d1fd4bc10] FOREIGN KEY ([estate_snapshot_pk]) REFERENCES [source].[estate_snapshot] ([estate_snapshot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[source_appearance] WITH CHECK ADD CONSTRAINT [FK_source_source_appearance_4956e6ee4f2d] FOREIGN KEY ([content_object_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_source_appearance_36b9754af42f] ON [source].[source_appearance] ([content_object_pk]);
GO
ALTER TABLE [source].[mapping_rule] WITH CHECK ADD CONSTRAINT [FK_source_mapping_rule_2e7e90adc6e8] FOREIGN KEY ([rule_content_object_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_mapping_rule_892c134ca9e7] ON [source].[mapping_rule] ([rule_content_object_pk]);
GO
ALTER TABLE [source].[source_classification] WITH CHECK ADD CONSTRAINT [FK_source_source_classification_0f6eecbb3259] FOREIGN KEY ([source_appearance_pk]) REFERENCES [source].[source_appearance] ([source_appearance_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[source_classification] WITH CHECK ADD CONSTRAINT [FK_source_source_classification_45aee98d505d] FOREIGN KEY ([mapping_rule_pk]) REFERENCES [source].[mapping_rule] ([mapping_rule_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_source_classification_603e2241c2aa] ON [source].[source_classification] ([mapping_rule_pk]);
GO
ALTER TABLE [source].[namespace_mapping] WITH CHECK ADD CONSTRAINT [FK_source_namespace_mapping_45aee98d505d] FOREIGN KEY ([mapping_rule_pk]) REFERENCES [source].[mapping_rule] ([mapping_rule_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[namespace_mapping] WITH CHECK ADD CONSTRAINT [FK_source_namespace_mapping_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_namespace_mapping_186d86d7e450] ON [source].[namespace_mapping] ([namespace_pk]);
GO
ALTER TABLE [source].[source_observation] WITH CHECK ADD CONSTRAINT [FK_source_source_observation_0f6eecbb3259] FOREIGN KEY ([source_appearance_pk]) REFERENCES [source].[source_appearance] ([source_appearance_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[source_observation] WITH CHECK ADD CONSTRAINT [FK_source_source_observation_f39a982aa1b0] FOREIGN KEY ([observed_value_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_source_observation_ba8c8b23dc0b] ON [source].[source_observation] ([observed_value_content_pk]);
GO
ALTER TABLE [source].[declaration_observation] WITH CHECK ADD CONSTRAINT [FK_source_declaration_observation_6342112d2367] FOREIGN KEY ([source_observation_pk],[observation_kind]) REFERENCES [source].[source_observation] ([source_observation_pk],[observation_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_declaration_observation_99a0a7ac5edb] ON [source].[declaration_observation] ([source_observation_pk],[observation_kind]);
GO
ALTER TABLE [source].[relationship_observation] WITH CHECK ADD CONSTRAINT [FK_source_relationship_observation_6342112d2367] FOREIGN KEY ([source_observation_pk],[observation_kind]) REFERENCES [source].[source_observation] ([source_observation_pk],[observation_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_relationship_observation_99a0a7ac5edb] ON [source].[relationship_observation] ([source_observation_pk],[observation_kind]);
GO
ALTER TABLE [source].[source_lineage] WITH CHECK ADD CONSTRAINT [FK_source_source_lineage_7a45d8b4ff2b] FOREIGN KEY ([semantic_object_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[source_lineage] WITH CHECK ADD CONSTRAINT [FK_source_source_lineage_180e518fc932] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[source_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[source_lineage] WITH CHECK ADD CONSTRAINT [FK_source_source_lineage_45aee98d505d] FOREIGN KEY ([mapping_rule_pk]) REFERENCES [source].[mapping_rule] ([mapping_rule_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_source_lineage_c2be5368d838] ON [source].[source_lineage] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_source_source_lineage_603e2241c2aa] ON [source].[source_lineage] ([mapping_rule_pk]);
GO
ALTER TABLE [source].[estate_model] WITH CHECK ADD CONSTRAINT [FK_source_estate_model_c77d1fd4bc10] FOREIGN KEY ([estate_snapshot_pk]) REFERENCES [source].[estate_snapshot] ([estate_snapshot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[estate_model_rule] WITH CHECK ADD CONSTRAINT [FK_source_estate_model_rule_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [source].[estate_model_rule] WITH CHECK ADD CONSTRAINT [FK_source_estate_model_rule_45aee98d505d] FOREIGN KEY ([mapping_rule_pk]) REFERENCES [source].[mapping_rule] ([mapping_rule_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_estate_model_rule_603e2241c2aa] ON [source].[estate_model_rule] ([mapping_rule_pk]);
GO
ALTER TABLE [source].[current_model] WITH CHECK ADD CONSTRAINT [FK_source_current_model_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_source_current_model_e806c12f937d] ON [source].[current_model] ([estate_model_pk]);
GO
ALTER TABLE [model].[namespace_owner] WITH CHECK ADD CONSTRAINT [FK_model_namespace_owner_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[namespace_owner] WITH CHECK ADD CONSTRAINT [FK_model_namespace_owner_e87d0ad739b0] FOREIGN KEY ([owner_semantic_object_pk]) REFERENCES [model].[semantic_object] ([semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[semantic_object] WITH CHECK ADD CONSTRAINT [FK_model_semantic_object_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[semantic_object_definition] WITH CHECK ADD CONSTRAINT [FK_model_semantic_object_definition_9bbbec7f1db1] FOREIGN KEY ([semantic_object_pk],[object_kind]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[semantic_object_definition] WITH CHECK ADD CONSTRAINT [FK_model_semantic_object_definition_e2e13aae8f66] FOREIGN KEY ([canonical_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_semantic_object_definition_aa3d27e36011] ON [model].[semantic_object_definition] ([semantic_object_pk],[object_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_semantic_object_definition_3a7137d75648] ON [model].[semantic_object_definition] ([canonical_content_pk]);
GO
ALTER TABLE [model].[definition_version_label] WITH CHECK ADD CONSTRAINT [FK_model_definition_version_label_26584b930211] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[definition_version_label] WITH CHECK ADD CONSTRAINT [FK_model_definition_version_label_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_definition_version_label_2c91dc1ef44f] ON [model].[definition_version_label] ([semantic_object_definition_pk],[semantic_object_pk],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_definition_version_label_4237e5fd127c] ON [model].[definition_version_label] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[estate_definition] WITH CHECK ADD CONSTRAINT [FK_model_estate_definition_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[estate_definition] WITH CHECK ADD CONSTRAINT [FK_model_estate_definition_7a45d8b4ff2b] FOREIGN KEY ([semantic_object_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_estate_definition_6bd2fb41453b] ON [model].[estate_definition] ([semantic_object_definition_pk],[estate_model_pk]);
GO
ALTER TABLE [model].[estate_capability] WITH CHECK ADD CONSTRAINT [FK_model_estate_capability_b17efc78b944] FOREIGN KEY ([estate_model_pk],[semantic_object_definition_pk]) REFERENCES [model].[estate_definition] ([estate_model_pk],[semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[estate_capability] WITH CHECK ADD CONSTRAINT [FK_model_estate_capability_683fc86813d4] FOREIGN KEY ([capability_pk],[capability_version_pk]) REFERENCES [model].[capability_version] ([capability_pk],[capability_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[estate_capability] WITH CHECK ADD CONSTRAINT [FK_model_estate_capability_39327f2a19ce] FOREIGN KEY ([capability_version_pk],[semantic_object_definition_pk]) REFERENCES [model].[capability_version] ([capability_version_pk],[semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_estate_capability_5082f0275978] ON [model].[estate_capability] ([estate_model_pk],[semantic_object_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_estate_capability_cee137d3dee6] ON [model].[estate_capability] ([capability_pk],[capability_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_estate_capability_c27f2822f77d] ON [model].[estate_capability] ([capability_version_pk],[semantic_object_definition_pk]);
GO
ALTER TABLE [model].[capability] WITH CHECK ADD CONSTRAINT [FK_model_capability_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability] WITH CHECK ADD CONSTRAINT [FK_model_capability_402cadd68d7a] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[capability_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_d747889a5f33] ON [model].[capability] ([semantic_object_pk],[object_kind],[namespace_pk],[capability_id]);
GO
ALTER TABLE [model].[capability_version] WITH CHECK ADD CONSTRAINT [FK_model_capability_version_1742eee7fad7] FOREIGN KEY ([capability_pk],[semantic_object_pk]) REFERENCES [model].[capability] ([capability_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_version] WITH CHECK ADD CONSTRAINT [FK_model_capability_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_version] WITH CHECK ADD CONSTRAINT [FK_model_capability_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_version_d0faabd572ac] ON [model].[capability_version] ([capability_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_version_12b758f1a94f] ON [model].[capability_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_version_4237e5fd127c] ON [model].[capability_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[product] WITH CHECK ADD CONSTRAINT [FK_model_product_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[product] WITH CHECK ADD CONSTRAINT [FK_model_product_fe2690004b82] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[product_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_product_308877758442] ON [model].[product] ([semantic_object_pk],[object_kind],[namespace_pk],[product_id]);
GO
ALTER TABLE [model].[product_definition] WITH CHECK ADD CONSTRAINT [FK_model_product_definition_a78d7b251f89] FOREIGN KEY ([product_pk],[semantic_object_pk]) REFERENCES [model].[product] ([product_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[product_definition] WITH CHECK ADD CONSTRAINT [FK_model_product_definition_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[product_definition] WITH CHECK ADD CONSTRAINT [FK_model_product_definition_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[product_definition] WITH CHECK ADD CONSTRAINT [FK_model_product_definition_306741a6cc15] FOREIGN KEY ([contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_product_definition_ae8cc738abf8] ON [model].[product_definition] ([product_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_product_definition_12b758f1a94f] ON [model].[product_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_product_definition_4237e5fd127c] ON [model].[product_definition] ([_owner_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_product_definition_ec8352c40547] ON [model].[product_definition] ([contract_version_pk]);
GO
ALTER TABLE [model].[contract] WITH CHECK ADD CONSTRAINT [FK_model_contract_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[contract] WITH CHECK ADD CONSTRAINT [FK_model_contract_382fcecbcc48] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[contract_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_contract_c72cad51868a] ON [model].[contract] ([semantic_object_pk],[object_kind],[namespace_pk],[contract_id]);
GO
ALTER TABLE [model].[contract_version] WITH CHECK ADD CONSTRAINT [FK_model_contract_version_18d3d43a2307] FOREIGN KEY ([contract_pk],[semantic_object_pk]) REFERENCES [model].[contract] ([contract_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[contract_version] WITH CHECK ADD CONSTRAINT [FK_model_contract_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[contract_version] WITH CHECK ADD CONSTRAINT [FK_model_contract_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[contract_version] WITH CHECK ADD CONSTRAINT [FK_model_contract_version_421b80ff41a1] FOREIGN KEY ([schema_object_pk]) REFERENCES [model].[schema_object] ([schema_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_contract_version_0dcd7ce7f6ff] ON [model].[contract_version] ([contract_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_contract_version_12b758f1a94f] ON [model].[contract_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_contract_version_4237e5fd127c] ON [model].[contract_version] ([_owner_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_contract_version_97c6d7ada933] ON [model].[contract_version] ([schema_object_pk]);
GO
ALTER TABLE [model].[execution_authority] WITH CHECK ADD CONSTRAINT [FK_model_execution_authority_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[execution_authority] WITH CHECK ADD CONSTRAINT [FK_model_execution_authority_cd452c7a444d] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[execution_authority_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_execution_authority_2d4b472b0bb3] ON [model].[execution_authority] ([semantic_object_pk],[object_kind],[namespace_pk],[execution_authority_id]);
GO
ALTER TABLE [model].[execution_authority_version] WITH CHECK ADD CONSTRAINT [FK_model_execution_authority_version_e6c3aae3aeab] FOREIGN KEY ([execution_authority_pk],[semantic_object_pk]) REFERENCES [model].[execution_authority] ([execution_authority_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[execution_authority_version] WITH CHECK ADD CONSTRAINT [FK_model_execution_authority_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[execution_authority_version] WITH CHECK ADD CONSTRAINT [FK_model_execution_authority_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_execution_authority_version_d328cae9c33c] ON [model].[execution_authority_version] ([execution_authority_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_execution_authority_version_12b758f1a94f] ON [model].[execution_authority_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_execution_authority_version_4237e5fd127c] ON [model].[execution_authority_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[transformation] WITH CHECK ADD CONSTRAINT [FK_model_transformation_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation] WITH CHECK ADD CONSTRAINT [FK_model_transformation_b6b0400750e9] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[transformation_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_90da8bf2e51b] ON [model].[transformation] ([semantic_object_pk],[object_kind],[namespace_pk],[transformation_id]);
GO
ALTER TABLE [model].[transformation_version] WITH CHECK ADD CONSTRAINT [FK_model_transformation_version_5f1e022f312c] FOREIGN KEY ([transformation_pk],[semantic_object_pk]) REFERENCES [model].[transformation] ([transformation_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_version] WITH CHECK ADD CONSTRAINT [FK_model_transformation_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_version] WITH CHECK ADD CONSTRAINT [FK_model_transformation_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_version_ad9cb09b668f] ON [model].[transformation_version] ([transformation_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_version_12b758f1a94f] ON [model].[transformation_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_version_4237e5fd127c] ON [model].[transformation_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[mechanic] WITH CHECK ADD CONSTRAINT [FK_model_mechanic_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[mechanic] WITH CHECK ADD CONSTRAINT [FK_model_mechanic_45bb6df19ade] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[mechanic_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_mechanic_baf752fdc7f2] ON [model].[mechanic] ([semantic_object_pk],[object_kind],[namespace_pk],[mechanic_id]);
GO
ALTER TABLE [model].[mechanic_version] WITH CHECK ADD CONSTRAINT [FK_model_mechanic_version_dd464218836f] FOREIGN KEY ([mechanic_pk],[semantic_object_pk]) REFERENCES [model].[mechanic] ([mechanic_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[mechanic_version] WITH CHECK ADD CONSTRAINT [FK_model_mechanic_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[mechanic_version] WITH CHECK ADD CONSTRAINT [FK_model_mechanic_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_mechanic_version_8dfef6422e88] ON [model].[mechanic_version] ([mechanic_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_mechanic_version_12b758f1a94f] ON [model].[mechanic_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_mechanic_version_4237e5fd127c] ON [model].[mechanic_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[port] WITH CHECK ADD CONSTRAINT [FK_model_port_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port] WITH CHECK ADD CONSTRAINT [FK_model_port_104c5d35fec7] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[port_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_port_bd89d1d776f7] ON [model].[port] ([semantic_object_pk],[object_kind],[namespace_pk],[port_id]);
GO
ALTER TABLE [model].[port_version] WITH CHECK ADD CONSTRAINT [FK_model_port_version_dbe321cfebcb] FOREIGN KEY ([port_pk],[semantic_object_pk]) REFERENCES [model].[port] ([port_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port_version] WITH CHECK ADD CONSTRAINT [FK_model_port_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port_version] WITH CHECK ADD CONSTRAINT [FK_model_port_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_port_version_ff5170187ad8] ON [model].[port_version] ([port_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_port_version_12b758f1a94f] ON [model].[port_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_port_version_4237e5fd127c] ON [model].[port_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider] WITH CHECK ADD CONSTRAINT [FK_model_provider_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider] WITH CHECK ADD CONSTRAINT [FK_model_provider_8990469cdfa8] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[provider_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_6117843a7f7f] ON [model].[provider] ([semantic_object_pk],[object_kind],[namespace_pk],[provider_id]);
GO
ALTER TABLE [model].[provider_definition] WITH CHECK ADD CONSTRAINT [FK_model_provider_definition_4a75d56b856e] FOREIGN KEY ([provider_pk],[semantic_object_pk]) REFERENCES [model].[provider] ([provider_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_definition] WITH CHECK ADD CONSTRAINT [FK_model_provider_definition_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_definition] WITH CHECK ADD CONSTRAINT [FK_model_provider_definition_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_definition_c9ffc12320e5] ON [model].[provider_definition] ([provider_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_definition_12b758f1a94f] ON [model].[provider_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_definition_4237e5fd127c] ON [model].[provider_definition] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_profile] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_profile] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_a0fb12dbff39] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[provider_profile_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_730e5878ec57] ON [model].[provider_profile] ([semantic_object_pk],[object_kind],[namespace_pk],[provider_profile_id]);
GO
ALTER TABLE [model].[provider_profile_version] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_version_77680ea670bf] FOREIGN KEY ([provider_profile_pk],[semantic_object_pk]) REFERENCES [model].[provider_profile] ([provider_profile_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_profile_version] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_profile_version] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_version_39882957d83d] ON [model].[provider_profile_version] ([provider_profile_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_version_12b758f1a94f] ON [model].[provider_profile_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_version_4237e5fd127c] ON [model].[provider_profile_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_926279b1ce5f] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[blueprint_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_10d4c75618bf] ON [model].[blueprint] ([semantic_object_pk],[object_kind],[namespace_pk],[blueprint_id]);
GO
ALTER TABLE [model].[blueprint_version] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_version_eda84a7ffed5] FOREIGN KEY ([blueprint_pk],[semantic_object_pk]) REFERENCES [model].[blueprint] ([blueprint_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_version] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_version] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_version] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_version_683fc86813d4] FOREIGN KEY ([capability_pk],[capability_version_pk]) REFERENCES [model].[capability_version] ([capability_pk],[capability_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_version_d58ec0897b46] ON [model].[blueprint_version] ([blueprint_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_version_12b758f1a94f] ON [model].[blueprint_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_version_4237e5fd127c] ON [model].[blueprint_version] ([_owner_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_version_cee137d3dee6] ON [model].[blueprint_version] ([capability_pk],[capability_version_pk]);
GO
ALTER TABLE [model].[authority] WITH CHECK ADD CONSTRAINT [FK_model_authority_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[authority] WITH CHECK ADD CONSTRAINT [FK_model_authority_7d644ab5d057] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[authority_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_authority_b66e1576a89d] ON [model].[authority] ([semantic_object_pk],[object_kind],[namespace_pk],[authority_id]);
GO
ALTER TABLE [model].[authority_definition] WITH CHECK ADD CONSTRAINT [FK_model_authority_definition_28ffe2140fdf] FOREIGN KEY ([authority_pk],[semantic_object_pk]) REFERENCES [model].[authority] ([authority_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[authority_definition] WITH CHECK ADD CONSTRAINT [FK_model_authority_definition_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[authority_definition] WITH CHECK ADD CONSTRAINT [FK_model_authority_definition_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_authority_definition_edd03ad97c88] ON [model].[authority_definition] ([authority_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_authority_definition_12b758f1a94f] ON [model].[authority_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_authority_definition_4237e5fd127c] ON [model].[authority_definition] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[scenario] WITH CHECK ADD CONSTRAINT [FK_model_scenario_b38e6c29d98f] FOREIGN KEY ([namespace_pk]) REFERENCES [model].[identity_namespace] ([namespace_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario] WITH CHECK ADD CONSTRAINT [FK_model_scenario_2c1516c9bf56] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[scenario_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario] WITH CHECK ADD CONSTRAINT [FK_model_scenario_547b7c2a327e] FOREIGN KEY ([capability_pk]) REFERENCES [model].[capability] ([capability_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_5944f245a758] ON [model].[scenario] ([semantic_object_pk],[object_kind],[namespace_pk],[scenario_id]);
GO
ALTER TABLE [model].[scenario_version] WITH CHECK ADD CONSTRAINT [FK_model_scenario_version_a0e5e31bc539] FOREIGN KEY ([scenario_pk],[semantic_object_pk]) REFERENCES [model].[scenario] ([scenario_pk],[semantic_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_version] WITH CHECK ADD CONSTRAINT [FK_model_scenario_version_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_version] WITH CHECK ADD CONSTRAINT [FK_model_scenario_version_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_version_96520949b565] ON [model].[scenario_version] ([scenario_pk],[semantic_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_version_12b758f1a94f] ON [model].[scenario_version] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_version_4237e5fd127c] ON [model].[scenario_version] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[capability_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_scenario_683fc86813d4] FOREIGN KEY ([capability_pk],[capability_version_pk]) REFERENCES [model].[capability_version] ([capability_pk],[capability_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_scenario_1194183b41e1] FOREIGN KEY ([capability_pk],[scenario_pk]) REFERENCES [model].[scenario] ([capability_pk],[scenario_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_scenario_d45078442215] FOREIGN KEY ([scenario_pk],[scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_pk],[scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_scenario_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_scenario_accf0e7a6441] ON [model].[capability_scenario] ([scenario_version_pk],[capability_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_scenario_cee137d3dee6] ON [model].[capability_scenario] ([capability_pk],[capability_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_scenario_212ddc8759c0] ON [model].[capability_scenario] ([capability_pk],[scenario_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_scenario_4ec4967ac269] ON [model].[capability_scenario] ([scenario_pk],[scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_scenario_4237e5fd127c] ON [model].[capability_scenario] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[capability_root_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_root_scenario_23d3956d67ad] FOREIGN KEY ([capability_version_pk],[scenario_pk]) REFERENCES [model].[capability_scenario] ([capability_version_pk],[scenario_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[capability_root_scenario] WITH CHECK ADD CONSTRAINT [FK_model_capability_root_scenario_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_root_scenario_d7000a20760f] ON [model].[capability_root_scenario] ([capability_version_pk],[scenario_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_capability_root_scenario_4237e5fd127c] ON [model].[capability_root_scenario] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[scenario_input] WITH CHECK ADD CONSTRAINT [FK_model_scenario_input_776c5704dc25] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_input] WITH CHECK ADD CONSTRAINT [FK_model_scenario_input_3d847b8c4527] FOREIGN KEY ([input_contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_input] WITH CHECK ADD CONSTRAINT [FK_model_scenario_input_9ee5402ff486] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[input_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_input] WITH CHECK ADD CONSTRAINT [FK_model_scenario_input_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_input] WITH CHECK ADD CONSTRAINT [FK_model_scenario_input_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_input_a9467f3aa021] ON [model].[scenario_input] ([input_contract_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_input_a4695bdeadbc] ON [model].[scenario_input] ([semantic_object_pk],[object_kind],[namespace_pk],[input_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_input_12b758f1a94f] ON [model].[scenario_input] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_input_4237e5fd127c] ON [model].[scenario_input] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[scenario_event] WITH CHECK ADD CONSTRAINT [FK_model_scenario_event_776c5704dc25] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_event] WITH CHECK ADD CONSTRAINT [FK_model_scenario_event_0ab0d563a2e9] FOREIGN KEY ([execution_authority_version_pk]) REFERENCES [model].[execution_authority_version] ([execution_authority_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_event] WITH CHECK ADD CONSTRAINT [FK_model_scenario_event_c2b231ae5a6b] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[event_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_event] WITH CHECK ADD CONSTRAINT [FK_model_scenario_event_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_event] WITH CHECK ADD CONSTRAINT [FK_model_scenario_event_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_event_b4adc4a9e74d] ON [model].[scenario_event] ([execution_authority_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_event_ea8c62b5aa30] ON [model].[scenario_event] ([semantic_object_pk],[object_kind],[namespace_pk],[event_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_event_12b758f1a94f] ON [model].[scenario_event] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_event_4237e5fd127c] ON [model].[scenario_event] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[scenario_outcome] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_776c5704dc25] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_outcome] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_8dafc7ff2cb1] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[outcome_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_outcome] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_outcome] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_outcome_acc5c729f301] ON [model].[scenario_outcome] ([semantic_object_pk],[object_kind],[namespace_pk],[outcome_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_outcome_12b758f1a94f] ON [model].[scenario_outcome] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_outcome_4237e5fd127c] ON [model].[scenario_outcome] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[outcome_variant] WITH CHECK ADD CONSTRAINT [FK_model_outcome_variant_6fe3e06852f4] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_outcome] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[outcome_variant] WITH CHECK ADD CONSTRAINT [FK_model_outcome_variant_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_outcome_variant_4237e5fd127c] ON [model].[outcome_variant] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[outcome_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_product_6fe3e06852f4] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_outcome] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[outcome_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_product_3d15ddc17bf3] FOREIGN KEY ([product_definition_pk]) REFERENCES [model].[product_definition] ([product_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[outcome_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_product_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_outcome_product_160c6cc3a5a8] ON [model].[outcome_product] ([product_definition_pk],[scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_outcome_product_4237e5fd127c] ON [model].[outcome_product] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[outcome_variant_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_variant_product_7b3cb9d8069b] FOREIGN KEY ([outcome_variant_pk]) REFERENCES [model].[outcome_variant] ([outcome_variant_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[outcome_variant_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_variant_product_3d15ddc17bf3] FOREIGN KEY ([product_definition_pk]) REFERENCES [model].[product_definition] ([product_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[outcome_variant_product] WITH CHECK ADD CONSTRAINT [FK_model_outcome_variant_product_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_outcome_variant_product_9015fc1da767] ON [model].[outcome_variant_product] ([product_definition_pk],[outcome_variant_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_outcome_variant_product_4237e5fd127c] ON [model].[outcome_variant_product] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[scenario_outcome_contract] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_contract_6fe3e06852f4] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_outcome] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_outcome_contract] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_contract_306741a6cc15] FOREIGN KEY ([contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[scenario_outcome_contract] WITH CHECK ADD CONSTRAINT [FK_model_scenario_outcome_contract_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_outcome_contract_ec8352c40547] ON [model].[scenario_outcome_contract] ([contract_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_scenario_outcome_contract_4237e5fd127c] ON [model].[scenario_outcome_contract] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[schema_object] WITH CHECK ADD CONSTRAINT [FK_model_schema_object_4956e6ee4f2d] FOREIGN KEY ([content_object_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port_contract] WITH CHECK ADD CONSTRAINT [FK_model_port_contract_b09b8c4bcba0] FOREIGN KEY ([port_version_pk]) REFERENCES [model].[port_version] ([port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port_contract] WITH CHECK ADD CONSTRAINT [FK_model_port_contract_306741a6cc15] FOREIGN KEY ([contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[port_contract] WITH CHECK ADD CONSTRAINT [FK_model_port_contract_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_port_contract_cb57c2450269] ON [model].[port_contract] ([port_version_pk],[direction],[role]) WHERE role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_port_contract_ec8352c40547] ON [model].[port_contract] ([contract_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_port_contract_4237e5fd127c] ON [model].[port_contract] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[execution_operation] WITH CHECK ADD CONSTRAINT [FK_model_execution_operation_0ab0d563a2e9] FOREIGN KEY ([execution_authority_version_pk]) REFERENCES [model].[execution_authority_version] ([execution_authority_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[execution_operation] WITH CHECK ADD CONSTRAINT [FK_model_execution_operation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_execution_operation_3062e6e5a919] ON [model].[execution_operation] ([execution_authority_version_pk],[operation_id]) WHERE operation_id IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_execution_operation_4237e5fd127c] ON [model].[execution_operation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_port_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_port_invocation_fbacc5ff349e] FOREIGN KEY ([execution_operation_pk],[operation_kind]) REFERENCES [model].[execution_operation] ([execution_operation_pk],[operation_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_port_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_port_invocation_b09b8c4bcba0] FOREIGN KEY ([port_version_pk]) REFERENCES [model].[port_version] ([port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_port_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_port_invocation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_port_invocation_b4a851f26b30] ON [model].[operation_port_invocation] ([execution_operation_pk],[operation_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_port_invocation_6008a02f3aa8] ON [model].[operation_port_invocation] ([port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_port_invocation_4237e5fd127c] ON [model].[operation_port_invocation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_scenario_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_scenario_invocation_fbacc5ff349e] FOREIGN KEY ([execution_operation_pk],[operation_kind]) REFERENCES [model].[execution_operation] ([execution_operation_pk],[operation_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_scenario_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_scenario_invocation_52541ac3779b] FOREIGN KEY ([target_scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_scenario_invocation] WITH CHECK ADD CONSTRAINT [FK_model_operation_scenario_invocation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_scenario_invocation_b4a851f26b30] ON [model].[operation_scenario_invocation] ([execution_operation_pk],[operation_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_scenario_invocation_0aaf60a09cd3] ON [model].[operation_scenario_invocation] ([target_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_scenario_invocation_4237e5fd127c] ON [model].[operation_scenario_invocation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_state_projection] WITH CHECK ADD CONSTRAINT [FK_model_operation_state_projection_fbacc5ff349e] FOREIGN KEY ([execution_operation_pk],[operation_kind]) REFERENCES [model].[execution_operation] ([execution_operation_pk],[operation_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_state_projection] WITH CHECK ADD CONSTRAINT [FK_model_operation_state_projection_8cd0a0f02be6] FOREIGN KEY ([transformation_version_pk]) REFERENCES [model].[transformation_version] ([transformation_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_state_projection] WITH CHECK ADD CONSTRAINT [FK_model_operation_state_projection_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_state_projection_b4a851f26b30] ON [model].[operation_state_projection] ([execution_operation_pk],[operation_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_state_projection_f43ab338f814] ON [model].[operation_state_projection] ([transformation_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_state_projection_4237e5fd127c] ON [model].[operation_state_projection] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_mechanic] WITH CHECK ADD CONSTRAINT [FK_model_operation_mechanic_67dfc8c10b11] FOREIGN KEY ([execution_operation_pk]) REFERENCES [model].[execution_operation] ([execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_mechanic] WITH CHECK ADD CONSTRAINT [FK_model_operation_mechanic_ea701d3e4c75] FOREIGN KEY ([mechanic_version_pk]) REFERENCES [model].[mechanic_version] ([mechanic_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_mechanic] WITH CHECK ADD CONSTRAINT [FK_model_operation_mechanic_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_mechanic_cd1260ad298e] ON [model].[operation_mechanic] ([mechanic_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_mechanic_4237e5fd127c] ON [model].[operation_mechanic] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_predecessor] WITH CHECK ADD CONSTRAINT [FK_model_operation_predecessor_f9f24faa2cc6] FOREIGN KEY ([execution_authority_version_pk],[execution_operation_pk]) REFERENCES [model].[execution_operation] ([execution_authority_version_pk],[execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_predecessor] WITH CHECK ADD CONSTRAINT [FK_model_operation_predecessor_8d6418b63548] FOREIGN KEY ([execution_authority_version_pk],[predecessor_operation_pk]) REFERENCES [model].[execution_operation] ([execution_authority_version_pk],[execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_predecessor] WITH CHECK ADD CONSTRAINT [FK_model_operation_predecessor_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_predecessor_42e9e528211f] ON [model].[operation_predecessor] ([execution_authority_version_pk],[execution_operation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_predecessor_fdc5e2e18594] ON [model].[operation_predecessor] ([execution_authority_version_pk],[predecessor_operation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_predecessor_4237e5fd127c] ON [model].[operation_predecessor] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[transformation_expression_node] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_node_8cd0a0f02be6] FOREIGN KEY ([transformation_version_pk]) REFERENCES [model].[transformation_version] ([transformation_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_expression_node] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_node_9bd45eda8716] FOREIGN KEY ([literal_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_expression_node] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_expression_node_80ae1e688268] ON [model].[transformation_expression_node] ([literal_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_expression_node_4237e5fd127c] ON [model].[transformation_expression_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[transformation_expression_child] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_child_b218ab00334b] FOREIGN KEY ([transformation_version_pk],[parent_node_pk]) REFERENCES [model].[transformation_expression_node] ([transformation_version_pk],[expression_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_expression_child] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_child_fdf64d20ca8b] FOREIGN KEY ([transformation_version_pk],[child_node_pk]) REFERENCES [model].[transformation_expression_node] ([transformation_version_pk],[expression_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_expression_child] WITH CHECK ADD CONSTRAINT [FK_model_transformation_expression_child_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_transformation_expression_child_1fc95d18225d] ON [model].[transformation_expression_child] ([parent_node_pk],[member_name_key]) WHERE member_name IS NOT NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_transformation_expression_child_a597ba23bad8] ON [model].[transformation_expression_child] ([parent_node_pk],[ordinal]) WHERE ordinal IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_expression_child_439d68ed812a] ON [model].[transformation_expression_child] ([transformation_version_pk],[parent_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_expression_child_8aadc76edd13] ON [model].[transformation_expression_child] ([transformation_version_pk],[child_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_expression_child_4237e5fd127c] ON [model].[transformation_expression_child] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[transformation_root] WITH CHECK ADD CONSTRAINT [FK_model_transformation_root_a489d4bf346c] FOREIGN KEY ([transformation_version_pk],[expression_node_pk]) REFERENCES [model].[transformation_expression_node] ([transformation_version_pk],[expression_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[transformation_root] WITH CHECK ADD CONSTRAINT [FK_model_transformation_root_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_root_0840c862dd68] ON [model].[transformation_root] ([transformation_version_pk],[expression_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_transformation_root_4237e5fd127c] ON [model].[transformation_root] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[expression_semantic_reference] WITH CHECK ADD CONSTRAINT [FK_model_expression_semantic_reference_e7dfc225eef0] FOREIGN KEY ([expression_node_pk]) REFERENCES [model].[transformation_expression_node] ([expression_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[expression_semantic_reference] WITH CHECK ADD CONSTRAINT [FK_model_expression_semantic_reference_8105d7539bd1] FOREIGN KEY ([semantic_object_definition_pk],[expected_kind]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[object_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[expression_semantic_reference] WITH CHECK ADD CONSTRAINT [FK_model_expression_semantic_reference_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_expression_semantic_reference_980bdcc90d08] ON [model].[expression_semantic_reference] ([semantic_object_definition_pk],[expected_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_expression_semantic_reference_4237e5fd127c] ON [model].[expression_semantic_reference] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[operation_transformation] WITH CHECK ADD CONSTRAINT [FK_model_operation_transformation_67dfc8c10b11] FOREIGN KEY ([execution_operation_pk]) REFERENCES [model].[execution_operation] ([execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_transformation] WITH CHECK ADD CONSTRAINT [FK_model_operation_transformation_8cd0a0f02be6] FOREIGN KEY ([transformation_version_pk]) REFERENCES [model].[transformation_version] ([transformation_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[operation_transformation] WITH CHECK ADD CONSTRAINT [FK_model_operation_transformation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_transformation_f43ab338f814] ON [model].[operation_transformation] ([transformation_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_operation_transformation_4237e5fd127c] ON [model].[operation_transformation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_port_implementation_f1492ae284e9] FOREIGN KEY ([provider_definition_pk]) REFERENCES [model].[provider_definition] ([provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_port_implementation_b09b8c4bcba0] FOREIGN KEY ([port_version_pk]) REFERENCES [model].[port_version] ([port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_port_implementation_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_port_implementation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_port_implementation_528b850f329d] ON [model].[provider_port_implementation] ([provider_definition_pk],[port_version_pk]) WHERE provider_profile_version_pk IS NULL AND role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_port_implementation_5228352304b2] ON [model].[provider_port_implementation] ([provider_definition_pk],[port_version_pk],[provider_profile_version_pk]) WHERE provider_profile_version_pk IS NOT NULL AND role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_port_implementation_e013518f18d0] ON [model].[provider_port_implementation] ([provider_definition_pk],[port_version_pk],[role]) WHERE provider_profile_version_pk IS NULL AND role IS NOT NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_port_implementation_b2247301178f] ON [model].[provider_port_implementation] ([provider_definition_pk],[port_version_pk],[provider_profile_version_pk],[role]) WHERE provider_profile_version_pk IS NOT NULL AND role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_port_implementation_6008a02f3aa8] ON [model].[provider_port_implementation] ([port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_port_implementation_83c139ce8c61] ON [model].[provider_port_implementation] ([provider_profile_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_port_implementation_4237e5fd127c] ON [model].[provider_port_implementation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_mechanic_implementation_f1492ae284e9] FOREIGN KEY ([provider_definition_pk]) REFERENCES [model].[provider_definition] ([provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_mechanic_implementation_ea701d3e4c75] FOREIGN KEY ([mechanic_version_pk]) REFERENCES [model].[mechanic_version] ([mechanic_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_mechanic_implementation_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_mechanic_implementation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_mechanic_implementation_85f07551f4a0] ON [model].[provider_mechanic_implementation] ([provider_definition_pk],[mechanic_version_pk]) WHERE provider_profile_version_pk IS NULL AND role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_mechanic_implementation_7ff2ab1072e0] ON [model].[provider_mechanic_implementation] ([provider_definition_pk],[mechanic_version_pk],[provider_profile_version_pk]) WHERE provider_profile_version_pk IS NOT NULL AND role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_mechanic_implementation_7b30193c0862] ON [model].[provider_mechanic_implementation] ([provider_definition_pk],[mechanic_version_pk],[role]) WHERE provider_profile_version_pk IS NULL AND role IS NOT NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_mechanic_implementation_e75dd81ec9ce] ON [model].[provider_mechanic_implementation] ([provider_definition_pk],[mechanic_version_pk],[provider_profile_version_pk],[role]) WHERE provider_profile_version_pk IS NOT NULL AND role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_mechanic_implementation_cd1260ad298e] ON [model].[provider_mechanic_implementation] ([mechanic_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_mechanic_implementation_83c139ce8c61] ON [model].[provider_mechanic_implementation] ([provider_profile_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_mechanic_implementation_4237e5fd127c] ON [model].[provider_mechanic_implementation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_capability_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_capability_implementation_f1492ae284e9] FOREIGN KEY ([provider_definition_pk]) REFERENCES [model].[provider_definition] ([provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_capability_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_capability_implementation_591640488206] FOREIGN KEY ([capability_version_pk]) REFERENCES [model].[capability_version] ([capability_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_capability_implementation] WITH CHECK ADD CONSTRAINT [FK_model_provider_capability_implementation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_capability_implementation_9469b5d8b15f] ON [model].[provider_capability_implementation] ([capability_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_capability_implementation_4237e5fd127c] ON [model].[provider_capability_implementation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_constraint_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_constraint_858753a6f588] FOREIGN KEY ([operand_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_provider_profile_constraint_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_constraint_0c38b6efcdc4] ON [model].[provider_profile_constraint] ([operand_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_profile_constraint_4237e5fd127c] ON [model].[provider_profile_constraint] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_slot] WITH CHECK ADD CONSTRAINT [FK_model_provider_slot_8cee8d034382] FOREIGN KEY ([blueprint_version_pk],[owner_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_slot] WITH CHECK ADD CONSTRAINT [FK_model_provider_slot_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_slot_0f70e496f87d] ON [model].[provider_slot] ([blueprint_version_pk],[owner_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_slot_4237e5fd127c] ON [model].[provider_slot] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[slot_port_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_port_requirement_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_port_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_port_requirement_b09b8c4bcba0] FOREIGN KEY ([port_version_pk]) REFERENCES [model].[port_version] ([port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_port_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_port_requirement_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_port_requirement_5b1cb10bacc8] ON [model].[slot_port_requirement] ([provider_slot_pk],[port_version_pk]) WHERE role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_port_requirement_dd9ce58cda87] ON [model].[slot_port_requirement] ([provider_slot_pk],[port_version_pk],[role]) WHERE role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_port_requirement_6008a02f3aa8] ON [model].[slot_port_requirement] ([port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_port_requirement_4237e5fd127c] ON [model].[slot_port_requirement] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[slot_mechanic_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_mechanic_requirement_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_mechanic_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_mechanic_requirement_ea701d3e4c75] FOREIGN KEY ([mechanic_version_pk]) REFERENCES [model].[mechanic_version] ([mechanic_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_mechanic_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_mechanic_requirement_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_mechanic_requirement_6a10b777a819] ON [model].[slot_mechanic_requirement] ([provider_slot_pk],[mechanic_version_pk]) WHERE role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_mechanic_requirement_322a2b76b2f6] ON [model].[slot_mechanic_requirement] ([provider_slot_pk],[mechanic_version_pk],[role]) WHERE role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_mechanic_requirement_cd1260ad298e] ON [model].[slot_mechanic_requirement] ([mechanic_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_mechanic_requirement_4237e5fd127c] ON [model].[slot_mechanic_requirement] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[slot_profile_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_requirement_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_profile_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_requirement_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_profile_requirement] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_requirement_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_profile_requirement_e33093d3505e] ON [model].[slot_profile_requirement] ([provider_slot_pk],[provider_profile_version_pk]) WHERE role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_slot_profile_requirement_18142a8a5813] ON [model].[slot_profile_requirement] ([provider_slot_pk],[provider_profile_version_pk],[role]) WHERE role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_profile_requirement_83c139ce8c61] ON [model].[slot_profile_requirement] ([provider_profile_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_profile_requirement_4237e5fd127c] ON [model].[slot_profile_requirement] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[slot_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_constraint_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_constraint_858753a6f588] FOREIGN KEY ([operand_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[slot_profile_constraint] WITH CHECK ADD CONSTRAINT [FK_model_slot_profile_constraint_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_profile_constraint_0c38b6efcdc4] ON [model].[slot_profile_constraint] ([operand_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_slot_profile_constraint_4237e5fd127c] ON [model].[slot_profile_constraint] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[binding_context] WITH CHECK ADD CONSTRAINT [FK_model_binding_context_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_context] WITH CHECK ADD CONSTRAINT [FK_model_binding_context_e2e13aae8f66] FOREIGN KEY ([canonical_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_context_83c139ce8c61] ON [model].[binding_context] ([provider_profile_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_context_3a7137d75648] ON [model].[binding_context] ([canonical_content_pk]);
GO
ALTER TABLE [model].[provider_binding_scope] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_scope_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_binding_scope] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_scope_568b9f117934] FOREIGN KEY ([binding_context_pk]) REFERENCES [model].[binding_context] ([binding_context_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_binding_scope] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_scope_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_scope_ef960abebe84] ON [model].[provider_binding_scope] ([provider_slot_pk]) WHERE binding_context_pk IS NULL AND binding_role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_scope_8a00f2f6c0b5] ON [model].[provider_binding_scope] ([provider_slot_pk],[binding_context_pk]) WHERE binding_context_pk IS NOT NULL AND binding_role IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_scope_58001f720597] ON [model].[provider_binding_scope] ([provider_slot_pk],[binding_role]) WHERE binding_context_pk IS NULL AND binding_role IS NOT NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_scope_380ff397911d] ON [model].[provider_binding_scope] ([provider_slot_pk],[binding_context_pk],[binding_role]) WHERE binding_context_pk IS NOT NULL AND binding_role IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_scope_2d90e73aca32] ON [model].[provider_binding_scope] ([provider_slot_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_scope_06cb5c3edcaa] ON [model].[provider_binding_scope] ([binding_context_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_scope_4237e5fd127c] ON [model].[provider_binding_scope] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_binding] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_8b340dc76e79] FOREIGN KEY ([provider_binding_scope_pk],[provider_slot_pk],[selection_policy]) REFERENCES [model].[provider_binding_scope] ([provider_binding_scope_pk],[provider_slot_pk],[selection_policy]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_binding] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_f1492ae284e9] FOREIGN KEY ([provider_definition_pk]) REFERENCES [model].[provider_definition] ([provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_binding] WITH CHECK ADD CONSTRAINT [FK_model_provider_binding_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_01913730bece] ON [model].[provider_binding] ([provider_binding_scope_pk]) WHERE selection_policy='SINGLE';
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_provider_binding_06182971c969] ON [model].[provider_binding] ([provider_binding_scope_pk],[ordinal]) WHERE selection_policy='ORDERED_SET';
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_19a9760e1c0c] ON [model].[provider_binding] ([provider_definition_pk],[provider_slot_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_1b7e76ba739e] ON [model].[provider_binding] ([provider_binding_scope_pk],[provider_slot_pk],[selection_policy]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_binding_4237e5fd127c] ON [model].[provider_binding] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[binding_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_port_implementation_970ddab10710] FOREIGN KEY ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]) REFERENCES [model].[provider_binding] ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_port_implementation_8940823ff348] FOREIGN KEY ([provider_slot_pk],[slot_port_requirement_pk],[port_version_pk]) REFERENCES [model].[slot_port_requirement] ([provider_slot_pk],[slot_port_requirement_pk],[port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_port_implementation_8db5e757a11a] FOREIGN KEY ([provider_definition_pk],[provider_port_implementation_pk],[port_version_pk]) REFERENCES [model].[provider_port_implementation] ([provider_definition_pk],[provider_port_implementation_pk],[port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_port_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_port_implementation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_port_implementation_b7f362322d87] ON [model].[binding_port_implementation] ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_port_implementation_c32de64f55b5] ON [model].[binding_port_implementation] ([provider_slot_pk],[slot_port_requirement_pk],[port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_port_implementation_b39a7ee90d3d] ON [model].[binding_port_implementation] ([provider_definition_pk],[provider_port_implementation_pk],[port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_port_implementation_4237e5fd127c] ON [model].[binding_port_implementation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[binding_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_mechanic_implementation_970ddab10710] FOREIGN KEY ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]) REFERENCES [model].[provider_binding] ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_mechanic_implementation_a01e286c4ec2] FOREIGN KEY ([provider_slot_pk],[slot_mechanic_requirement_pk],[mechanic_version_pk]) REFERENCES [model].[slot_mechanic_requirement] ([provider_slot_pk],[slot_mechanic_requirement_pk],[mechanic_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_mechanic_implementation_463ab9a95988] FOREIGN KEY ([provider_definition_pk],[provider_mechanic_implementation_pk],[mechanic_version_pk]) REFERENCES [model].[provider_mechanic_implementation] ([provider_definition_pk],[provider_mechanic_implementation_pk],[mechanic_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[binding_mechanic_implementation] WITH CHECK ADD CONSTRAINT [FK_model_binding_mechanic_implementation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_mechanic_implementation_b7f362322d87] ON [model].[binding_mechanic_implementation] ([provider_binding_pk],[provider_slot_pk],[provider_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_mechanic_implementation_52e6ef05422e] ON [model].[binding_mechanic_implementation] ([provider_slot_pk],[slot_mechanic_requirement_pk],[mechanic_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_mechanic_implementation_7d92e42fef29] ON [model].[binding_mechanic_implementation] ([provider_definition_pk],[provider_mechanic_implementation_pk],[mechanic_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_binding_mechanic_implementation_4237e5fd127c] ON [model].[binding_mechanic_implementation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[provider_slot_operation] WITH CHECK ADD CONSTRAINT [FK_model_provider_slot_operation_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_slot_operation] WITH CHECK ADD CONSTRAINT [FK_model_provider_slot_operation_67dfc8c10b11] FOREIGN KEY ([execution_operation_pk]) REFERENCES [model].[execution_operation] ([execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[provider_slot_operation] WITH CHECK ADD CONSTRAINT [FK_model_provider_slot_operation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_slot_operation_fe66a5364d5a] ON [model].[provider_slot_operation] ([execution_operation_pk],[provider_slot_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_provider_slot_operation_4237e5fd127c] ON [model].[provider_slot_operation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_node] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_25739c0d9f42] FOREIGN KEY ([semantic_object_definition_pk],[expected_semantic_kind]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[object_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_8f1139c3b661] ON [model].[blueprint_node] ([blueprint_version_pk],[altitude],[node_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_37690802b645] ON [model].[blueprint_node] ([semantic_object_definition_pk],[expected_semantic_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_4237e5fd127c] ON [model].[blueprint_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_node_face] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_face_8c977188cc86] FOREIGN KEY ([blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node_face] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_face_8105d7539bd1] FOREIGN KEY ([semantic_object_definition_pk],[expected_kind]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[object_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node_face] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_face_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_face_980bdcc90d08] ON [model].[blueprint_node_face] ([semantic_object_definition_pk],[expected_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_face_4237e5fd127c] ON [model].[blueprint_node_face] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_node_scenario] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_scenario_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node_scenario] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_scenario_776c5704dc25] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_node_scenario] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_node_scenario_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_scenario_d350a81083bd] ON [model].[blueprint_node_scenario] ([scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_node_scenario_4237e5fd127c] ON [model].[blueprint_node_scenario] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_93c1d068d9e7] FOREIGN KEY ([blueprint_version_pk],[from_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_33141d23418c] FOREIGN KEY ([blueprint_version_pk],[to_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_e80b8553a291] FOREIGN KEY ([blueprint_version_pk],[from_node_pk],[source_scenario_version_pk]) REFERENCES [model].[blueprint_node_scenario] ([blueprint_version_pk],[blueprint_node_pk],[scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_c8aef5bacc7a] FOREIGN KEY ([source_scenario_version_pk],[selecting_variant_pk]) REFERENCES [model].[outcome_variant] ([scenario_version_pk],[outcome_variant_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_d8a2bee3fece] FOREIGN KEY ([binding_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_89a9fde0071a] ON [model].[blueprint_edge] ([blueprint_version_pk],[from_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_d8a5321f3b5b] ON [model].[blueprint_edge] ([blueprint_version_pk],[to_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_6a78b110b3d9] ON [model].[blueprint_edge] ([blueprint_version_pk],[from_node_pk],[source_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_22a103c1672e] ON [model].[blueprint_edge] ([source_scenario_version_pk],[selecting_variant_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_59171bbd0cd6] ON [model].[blueprint_edge] ([binding_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_4237e5fd127c] ON [model].[blueprint_edge] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_edge_contract] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_contract_59d2d6aeacb0] FOREIGN KEY ([blueprint_edge_pk],[contract_relation]) REFERENCES [model].[blueprint_edge] ([blueprint_edge_pk],[contract_relation]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge_contract] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_contract_3d15ddc17bf3] FOREIGN KEY ([product_definition_pk]) REFERENCES [model].[product_definition] ([product_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge_contract] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_contract_785b1266f5e3] FOREIGN KEY ([downstream_scenario_version_pk]) REFERENCES [model].[scenario_input] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge_contract] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_contract_8e1ed15545ab] FOREIGN KEY ([compatibility_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_edge_contract] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_edge_contract_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_contract_a11fceebcfcf] ON [model].[blueprint_edge_contract] ([blueprint_edge_pk],[contract_relation]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_contract_f0fc7329bbd2] ON [model].[blueprint_edge_contract] ([product_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_contract_8947972c72d1] ON [model].[blueprint_edge_contract] ([downstream_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_contract_92c3adbf3a5d] ON [model].[blueprint_edge_contract] ([compatibility_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_edge_contract_4237e5fd127c] ON [model].[blueprint_edge_contract] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_convergence_requirement] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_convergence_requirement_e5f91c6c6128] FOREIGN KEY ([blueprint_version_pk],[convergence_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_convergence_requirement] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_convergence_requirement_3d15ddc17bf3] FOREIGN KEY ([product_definition_pk]) REFERENCES [model].[product_definition] ([product_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_convergence_requirement] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_convergence_requirement_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_convergence_requirement_41acc2e934a0] ON [model].[blueprint_convergence_requirement] ([blueprint_version_pk],[convergence_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_convergence_requirement_f0fc7329bbd2] ON [model].[blueprint_convergence_requirement] ([product_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_convergence_requirement_4237e5fd127c] ON [model].[blueprint_convergence_requirement] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_fan_out_set] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_fan_out_set_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_fan_out_set] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_fan_out_set_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_fan_out_set_4237e5fd127c] ON [model].[blueprint_fan_out_set] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_fan_out_member] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_fan_out_member_4987b61b1954] FOREIGN KEY ([blueprint_version_pk],[blueprint_fan_out_set_pk]) REFERENCES [model].[blueprint_fan_out_set] ([blueprint_version_pk],[blueprint_fan_out_set_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_fan_out_member] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_fan_out_member_aa7eed0a07ef] FOREIGN KEY ([blueprint_version_pk],[blueprint_edge_pk]) REFERENCES [model].[blueprint_edge] ([blueprint_version_pk],[blueprint_edge_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_fan_out_member] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_fan_out_member_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_fan_out_member_7196b5b79908] ON [model].[blueprint_fan_out_member] ([blueprint_version_pk],[blueprint_fan_out_set_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_fan_out_member_4c1e2191a32e] ON [model].[blueprint_fan_out_member] ([blueprint_version_pk],[blueprint_edge_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_fan_out_member_4237e5fd127c] ON [model].[blueprint_fan_out_member] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[blueprint_bounded_return] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_bounded_return_5b126447857a] FOREIGN KEY ([blueprint_edge_pk]) REFERENCES [model].[blueprint_edge] ([blueprint_edge_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_bounded_return] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_bounded_return_c079ee5410ba] FOREIGN KEY ([declared_bound_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_bounded_return] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_bounded_return_b2c5575795f7] FOREIGN KEY ([authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_bounded_return] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_bounded_return_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_bounded_return_542176eb1f7a] ON [model].[blueprint_bounded_return] ([declared_bound_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_bounded_return_a14c24ea68bc] ON [model].[blueprint_bounded_return] ([authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_bounded_return_4237e5fd127c] ON [model].[blueprint_bounded_return] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture] WITH CHECK ADD CONSTRAINT [FK_model_fixture_6db8dd96866d] FOREIGN KEY ([owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture] WITH CHECK ADD CONSTRAINT [FK_model_fixture_78ccffbada3b] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[fixture_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture] WITH CHECK ADD CONSTRAINT [FK_model_fixture_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture] WITH CHECK ADD CONSTRAINT [FK_model_fixture_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_55bfb454b02d] ON [model].[fixture] ([semantic_object_pk],[object_kind],[namespace_pk],[fixture_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_12b758f1a94f] ON [model].[fixture] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_4237e5fd127c] ON [model].[fixture] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture_case] WITH CHECK ADD CONSTRAINT [FK_model_fixture_case_c73872f3bafb] FOREIGN KEY ([fixture_pk]) REFERENCES [model].[fixture] ([fixture_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_case] WITH CHECK ADD CONSTRAINT [FK_model_fixture_case_2a72a7a0bf11] FOREIGN KEY ([input_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_case] WITH CHECK ADD CONSTRAINT [FK_model_fixture_case_eca23b8542fa] FOREIGN KEY ([terminal_scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_case] WITH CHECK ADD CONSTRAINT [FK_model_fixture_case_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_fixture_case_519017b86a86] ON [model].[fixture_case] ([fixture_pk],[case_id]) WHERE case_id IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_case_f359e306fa98] ON [model].[fixture_case] ([input_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_case_cce557f5ec29] ON [model].[fixture_case] ([terminal_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_case_4237e5fd127c] ON [model].[fixture_case] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture_assertion] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_246817366c50] FOREIGN KEY ([fixture_case_pk]) REFERENCES [model].[fixture_case] ([fixture_case_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_assertion] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_894d06498a29] FOREIGN KEY ([expected_value_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_assertion] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_assertion_7eb693dd2961] ON [model].[fixture_assertion] ([expected_value_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_assertion_4237e5fd127c] ON [model].[fixture_assertion] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture_scenario_step] WITH CHECK ADD CONSTRAINT [FK_model_fixture_scenario_step_246817366c50] FOREIGN KEY ([fixture_case_pk]) REFERENCES [model].[fixture_case] ([fixture_case_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_scenario_step] WITH CHECK ADD CONSTRAINT [FK_model_fixture_scenario_step_776c5704dc25] FOREIGN KEY ([scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_scenario_step] WITH CHECK ADD CONSTRAINT [FK_model_fixture_scenario_step_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_scenario_step_d350a81083bd] ON [model].[fixture_scenario_step] ([scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_scenario_step_4237e5fd127c] ON [model].[fixture_scenario_step] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture_port_outcome] WITH CHECK ADD CONSTRAINT [FK_model_fixture_port_outcome_246817366c50] FOREIGN KEY ([fixture_case_pk]) REFERENCES [model].[fixture_case] ([fixture_case_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_port_outcome] WITH CHECK ADD CONSTRAINT [FK_model_fixture_port_outcome_b09b8c4bcba0] FOREIGN KEY ([port_version_pk]) REFERENCES [model].[port_version] ([port_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_port_outcome] WITH CHECK ADD CONSTRAINT [FK_model_fixture_port_outcome_4956e6ee4f2d] FOREIGN KEY ([content_object_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_port_outcome] WITH CHECK ADD CONSTRAINT [FK_model_fixture_port_outcome_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_port_outcome_6008a02f3aa8] ON [model].[fixture_port_outcome] ([port_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_port_outcome_36b9754af42f] ON [model].[fixture_port_outcome] ([content_object_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_port_outcome_4237e5fd127c] ON [model].[fixture_port_outcome] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[observable_condition] WITH CHECK ADD CONSTRAINT [FK_model_observable_condition_6db8dd96866d] FOREIGN KEY ([owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observable_condition] WITH CHECK ADD CONSTRAINT [FK_model_observable_condition_97562897f5bf] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[condition_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observable_condition] WITH CHECK ADD CONSTRAINT [FK_model_observable_condition_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observable_condition] WITH CHECK ADD CONSTRAINT [FK_model_observable_condition_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_observable_condition_41bc355c9128] ON [model].[observable_condition] ([semantic_object_pk],[object_kind],[namespace_pk],[condition_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observable_condition_12b758f1a94f] ON [model].[observable_condition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observable_condition_4237e5fd127c] ON [model].[observable_condition] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[fixture_assertion_condition] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_condition_3abeb2e05554] FOREIGN KEY ([fixture_assertion_pk]) REFERENCES [model].[fixture_assertion] ([fixture_assertion_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_assertion_condition] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_condition_0bfc570b21fc] FOREIGN KEY ([observable_condition_pk]) REFERENCES [model].[observable_condition] ([observable_condition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[fixture_assertion_condition] WITH CHECK ADD CONSTRAINT [FK_model_fixture_assertion_condition_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_assertion_condition_ea0496d70763] ON [model].[fixture_assertion_condition] ([observable_condition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_fixture_assertion_condition_4237e5fd127c] ON [model].[fixture_assertion_condition] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[proof_obligation] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_6db8dd96866d] FOREIGN KEY ([owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_cc8cb59d1b00] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[proof_obligation_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_eb6f925840a9] ON [model].[proof_obligation] ([semantic_object_pk],[object_kind],[namespace_pk],[proof_obligation_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_12b758f1a94f] ON [model].[proof_obligation] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_4237e5fd127c] ON [model].[proof_obligation] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[proof_obligation_subject] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_subject_3ddea469ac79] FOREIGN KEY ([proof_obligation_pk]) REFERENCES [model].[proof_obligation] ([proof_obligation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation_subject] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_subject_ae8eda366e93] FOREIGN KEY ([subject_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation_subject] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_subject_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_subject_d1beea3deb4e] ON [model].[proof_obligation_subject] ([subject_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_subject_4237e5fd127c] ON [model].[proof_obligation_subject] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[proof_obligation_fixture] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_fixture_3ddea469ac79] FOREIGN KEY ([proof_obligation_pk]) REFERENCES [model].[proof_obligation] ([proof_obligation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation_fixture] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_fixture_246817366c50] FOREIGN KEY ([fixture_case_pk]) REFERENCES [model].[fixture_case] ([fixture_case_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[proof_obligation_fixture] WITH CHECK ADD CONSTRAINT [FK_model_proof_obligation_fixture_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_fixture_0bbd6178664f] ON [model].[proof_obligation_fixture] ([fixture_case_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_proof_obligation_fixture_4237e5fd127c] ON [model].[proof_obligation_fixture] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_context] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_0b3c19cb107d] FOREIGN KEY ([realization_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_4966d8dbe0df] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_32206e35f851] ON [model].[c4_context] ([realization_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_6fe192bc297b] ON [model].[c4_context] ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_12b758f1a94f] ON [model].[c4_context] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_4237e5fd127c] ON [model].[c4_context] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_0b3c19cb107d] FOREIGN KEY ([realization_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_4966d8dbe0df] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_b0830731073b] FOREIGN KEY ([blueprint_version_pk],[c4_context_pk]) REFERENCES [model].[c4_context] ([blueprint_version_pk],[c4_context_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_32206e35f851] ON [model].[c4_container] ([realization_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_6fe192bc297b] ON [model].[c4_container] ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_12b758f1a94f] ON [model].[c4_container] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_4237e5fd127c] ON [model].[c4_container] ([_owner_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_c68a6c7cfe2c] ON [model].[c4_container] ([blueprint_version_pk],[c4_context_pk]);
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_0b3c19cb107d] FOREIGN KEY ([realization_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_4966d8dbe0df] FOREIGN KEY ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]) REFERENCES [model].[semantic_object] ([semantic_object_pk],[object_kind],[namespace_pk],[declared_id]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_38605ba41d7d] FOREIGN KEY ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_8f5e64aa8881] FOREIGN KEY ([blueprint_version_pk],[c4_container_pk]) REFERENCES [model].[c4_container] ([blueprint_version_pk],[c4_container_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_32206e35f851] ON [model].[c4_component] ([realization_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_6fe192bc297b] ON [model].[c4_component] ([semantic_object_pk],[object_kind],[namespace_pk],[element_id]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_12b758f1a94f] ON [model].[c4_component] ([semantic_object_definition_pk],[semantic_object_pk],[object_kind],[definition_digest]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_4237e5fd127c] ON [model].[c4_component] ([_owner_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_4e2f93f247dc] ON [model].[c4_component] ([blueprint_version_pk],[c4_container_pk]);
GO
ALTER TABLE [model].[c4_code_mapping] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_code_mapping] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_d541aaa0f3bd] FOREIGN KEY ([blueprint_version_pk],[c4_component_pk]) REFERENCES [model].[c4_component] ([blueprint_version_pk],[c4_component_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_code_mapping] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_0b3c19cb107d] FOREIGN KEY ([realization_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_code_mapping] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UXF_model_c4_code_mapping_2cf4ce269041] ON [model].[c4_code_mapping] ([blueprint_version_pk],[element_id]) WHERE element_id IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_7699c39afe34] ON [model].[c4_code_mapping] ([blueprint_version_pk],[c4_component_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_32206e35f851] ON [model].[c4_code_mapping] ([realization_authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_4237e5fd127c] ON [model].[c4_code_mapping] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_context_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_node_b0830731073b] FOREIGN KEY ([blueprint_version_pk],[c4_context_pk]) REFERENCES [model].[c4_context] ([blueprint_version_pk],[c4_context_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_node_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_context_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_context_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_node_c68a6c7cfe2c] ON [model].[c4_context_node] ([blueprint_version_pk],[c4_context_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_node_89bacf6f12db] ON [model].[c4_context_node] ([blueprint_version_pk],[blueprint_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_context_node_4237e5fd127c] ON [model].[c4_context_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_container_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_node_8f5e64aa8881] FOREIGN KEY ([blueprint_version_pk],[c4_container_pk]) REFERENCES [model].[c4_container] ([blueprint_version_pk],[c4_container_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_node_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_container_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_container_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_node_4e2f93f247dc] ON [model].[c4_container_node] ([blueprint_version_pk],[c4_container_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_node_89bacf6f12db] ON [model].[c4_container_node] ([blueprint_version_pk],[blueprint_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_container_node_4237e5fd127c] ON [model].[c4_container_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_component_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_node_d541aaa0f3bd] FOREIGN KEY ([blueprint_version_pk],[c4_component_pk]) REFERENCES [model].[c4_component] ([blueprint_version_pk],[c4_component_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_node_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_component_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_component_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_node_7699c39afe34] ON [model].[c4_component_node] ([blueprint_version_pk],[c4_component_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_node_89bacf6f12db] ON [model].[c4_component_node] ([blueprint_version_pk],[blueprint_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_component_node_4237e5fd127c] ON [model].[c4_component_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[c4_code_mapping_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_node_a51b2f79b29a] FOREIGN KEY ([blueprint_version_pk],[c4_code_mapping_pk]) REFERENCES [model].[c4_code_mapping] ([blueprint_version_pk],[c4_code_mapping_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_code_mapping_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_node_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[c4_code_mapping_node] WITH CHECK ADD CONSTRAINT [FK_model_c4_code_mapping_node_984a29dfcbb0] FOREIGN KEY ([_owner_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_node_87ff7fd03da4] ON [model].[c4_code_mapping_node] ([blueprint_version_pk],[c4_code_mapping_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_node_89bacf6f12db] ON [model].[c4_code_mapping_node] ([blueprint_version_pk],[blueprint_node_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_c4_code_mapping_node_4237e5fd127c] ON [model].[c4_code_mapping_node] ([_owner_definition_pk]);
GO
ALTER TABLE [model].[observed_semantic_graph_transition] WITH CHECK ADD CONSTRAINT [FK_model_observed_semantic_graph_transition_7b4863193d6f] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[relationship_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_execution_scenario_invocation] WITH CHECK ADD CONSTRAINT [FK_model_observed_execution_scenario_invocation_7b4863193d6f] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[relationship_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_transition_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_transition_resolution_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_transition_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_transition_resolution_9527a9a427b4] FOREIGN KEY ([source_observation_pk]) REFERENCES [model].[observed_semantic_graph_transition] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_transition_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_transition_resolution_605ee6ba7db2] FOREIGN KEY ([source_scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_transition_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_transition_resolution_52541ac3779b] FOREIGN KEY ([target_scenario_version_pk]) REFERENCES [model].[scenario_version] ([scenario_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_transition_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_transition_resolution_c8aef5bacc7a] FOREIGN KEY ([source_scenario_version_pk],[selecting_variant_pk]) REFERENCES [model].[outcome_variant] ([scenario_version_pk],[outcome_variant_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_transition_resolution_c2be5368d838] ON [model].[observed_transition_resolution] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_transition_resolution_d53805719008] ON [model].[observed_transition_resolution] ([source_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_transition_resolution_0aaf60a09cd3] ON [model].[observed_transition_resolution] ([target_scenario_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_transition_resolution_22a103c1672e] ON [model].[observed_transition_resolution] ([source_scenario_version_pk],[selecting_variant_pk]);
GO
ALTER TABLE [model].[observed_invocation_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_invocation_resolution_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_invocation_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_invocation_resolution_be20331661e9] FOREIGN KEY ([source_observation_pk]) REFERENCES [model].[observed_execution_scenario_invocation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[observed_invocation_resolution] WITH CHECK ADD CONSTRAINT [FK_model_observed_invocation_resolution_8d6232e4d503] FOREIGN KEY ([execution_operation_pk]) REFERENCES [model].[operation_scenario_invocation] ([execution_operation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_invocation_resolution_c2be5368d838] ON [model].[observed_invocation_resolution] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_observed_invocation_resolution_2dd7848b775d] ON [model].[observed_invocation_resolution] ([execution_operation_pk]);
GO
ALTER TABLE [model].[blueprint_observed_transition_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_transition_mapping_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_transition_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_transition_mapping_5b126447857a] FOREIGN KEY ([blueprint_edge_pk]) REFERENCES [model].[blueprint_edge] ([blueprint_edge_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_transition_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_transition_mapping_9527a9a427b4] FOREIGN KEY ([source_observation_pk]) REFERENCES [model].[observed_semantic_graph_transition] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_transition_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_transition_mapping_58b61b69587e] FOREIGN KEY ([mapping_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_transition_mapping_7c4029561e22] ON [model].[blueprint_observed_transition_mapping] ([blueprint_edge_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_transition_mapping_c2be5368d838] ON [model].[blueprint_observed_transition_mapping] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_transition_mapping_c218bb10055f] ON [model].[blueprint_observed_transition_mapping] ([mapping_authority_definition_pk]);
GO
ALTER TABLE [model].[blueprint_observed_invocation_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_invocation_mapping_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_invocation_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_invocation_mapping_5b126447857a] FOREIGN KEY ([blueprint_edge_pk]) REFERENCES [model].[blueprint_edge] ([blueprint_edge_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_invocation_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_invocation_mapping_be20331661e9] FOREIGN KEY ([source_observation_pk]) REFERENCES [model].[observed_execution_scenario_invocation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [model].[blueprint_observed_invocation_mapping] WITH CHECK ADD CONSTRAINT [FK_model_blueprint_observed_invocation_mapping_58b61b69587e] FOREIGN KEY ([mapping_authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_invocation_mapping_7c4029561e22] ON [model].[blueprint_observed_invocation_mapping] ([blueprint_edge_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_invocation_mapping_c2be5368d838] ON [model].[blueprint_observed_invocation_mapping] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_model_blueprint_observed_invocation_mapping_c218bb10055f] ON [model].[blueprint_observed_invocation_mapping] ([mapping_authority_definition_pk]);
GO
ALTER TABLE [analysis].[integrity_rule] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_rule_46dae8c1f674] FOREIGN KEY ([rule_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_rule_2a87caac84ea] ON [analysis].[integrity_rule] ([rule_content_pk]);
GO
ALTER TABLE [analysis].[assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_bcbcac1124f4] FOREIGN KEY ([integrity_rule_pk]) REFERENCES [analysis].[integrity_rule] ([integrity_rule_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_assessment_e9a7d142e27b] ON [analysis].[assessment] ([estate_model_pk],[assessment_kind],[integrity_rule_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_assessment_1ed460bcc7ad] ON [analysis].[assessment] ([integrity_rule_pk]);
GO
ALTER TABLE [analysis].[assessment_source_input] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_source_input_7d59f398e7f4] FOREIGN KEY ([assessment_pk]) REFERENCES [analysis].[assessment] ([assessment_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[assessment_source_input] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_source_input_180e518fc932] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[source_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_assessment_source_input_c2be5368d838] ON [analysis].[assessment_source_input] ([source_observation_pk]);
GO
ALTER TABLE [analysis].[assessment_definition_input] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_definition_input_7d59f398e7f4] FOREIGN KEY ([assessment_pk]) REFERENCES [analysis].[assessment] ([assessment_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[assessment_definition_input] WITH CHECK ADD CONSTRAINT [FK_analysis_assessment_definition_input_7a45d8b4ff2b] FOREIGN KEY ([semantic_object_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_assessment_definition_input_524212dcbc38] ON [analysis].[assessment_definition_input] ([semantic_object_definition_pk]);
GO
ALTER TABLE [analysis].[integrity_finding] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_finding_7d59f398e7f4] FOREIGN KEY ([assessment_pk]) REFERENCES [analysis].[assessment] ([assessment_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[integrity_finding] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_finding_180e518fc932] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[source_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[integrity_finding] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_finding_ae8eda366e93] FOREIGN KEY ([subject_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[integrity_finding] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_finding_03886fde409d] FOREIGN KEY ([expected_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[integrity_finding] WITH CHECK ADD CONSTRAINT [FK_analysis_integrity_finding_d1f5ad89f04a] FOREIGN KEY ([observed_content_pk]) REFERENCES [source].[content_object] ([content_object_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_finding_e828be72285d] ON [analysis].[integrity_finding] ([assessment_pk],[severity],[finding_code]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_finding_c2be5368d838] ON [analysis].[integrity_finding] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_finding_d1beea3deb4e] ON [analysis].[integrity_finding] ([subject_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_finding_3e0add4ef74b] ON [analysis].[integrity_finding] ([expected_content_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_integrity_finding_e079f042cd9e] ON [analysis].[integrity_finding] ([observed_content_pk]);
GO
ALTER TABLE [analysis].[unresolved_reference] WITH CHECK ADD CONSTRAINT [FK_analysis_unresolved_reference_b0f7f61fd6e3] FOREIGN KEY ([estate_model_pk]) REFERENCES [source].[estate_model] ([estate_model_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[unresolved_reference] WITH CHECK ADD CONSTRAINT [FK_analysis_unresolved_reference_7b4863193d6f] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[relationship_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[unresolved_reference] WITH CHECK ADD CONSTRAINT [FK_analysis_unresolved_reference_c5d37f5b30f6] FOREIGN KEY ([finding_pk]) REFERENCES [analysis].[integrity_finding] ([integrity_finding_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_unresolved_reference_c2be5368d838] ON [analysis].[unresolved_reference] ([source_observation_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_unresolved_reference_373cfc0e6173] ON [analysis].[unresolved_reference] ([finding_pk]);
GO
ALTER TABLE [analysis].[compatibility_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_compatibility_assessment_9851d8c36b81] FOREIGN KEY ([assessment_pk],[assessment_kind]) REFERENCES [analysis].[assessment] ([assessment_pk],[assessment_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[compatibility_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_compatibility_assessment_5a3eb2aae52c] FOREIGN KEY ([producer_contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[compatibility_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_compatibility_assessment_c67a609716c6] FOREIGN KEY ([consumer_contract_version_pk]) REFERENCES [model].[contract_version] ([contract_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[compatibility_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_compatibility_assessment_b2c5575795f7] FOREIGN KEY ([authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_compatibility_assessment_a1186643516d] ON [analysis].[compatibility_assessment] ([assessment_pk],[assessment_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_compatibility_assessment_dfafdb282302] ON [analysis].[compatibility_assessment] ([producer_contract_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_compatibility_assessment_3a387cf70702] ON [analysis].[compatibility_assessment] ([consumer_contract_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_compatibility_assessment_a14c24ea68bc] ON [analysis].[compatibility_assessment] ([authority_definition_pk]);
GO
ALTER TABLE [analysis].[coverage_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_coverage_assessment_9851d8c36b81] FOREIGN KEY ([assessment_pk],[assessment_kind]) REFERENCES [analysis].[assessment] ([assessment_pk],[assessment_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_coverage_assessment_a1186643516d] ON [analysis].[coverage_assessment] ([assessment_pk],[assessment_kind]);
GO
ALTER TABLE [analysis].[circuit_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_circuit_assessment_9851d8c36b81] FOREIGN KEY ([assessment_pk],[assessment_kind]) REFERENCES [analysis].[assessment] ([assessment_pk],[assessment_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[circuit_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_circuit_assessment_4dd4121569ea] FOREIGN KEY ([blueprint_version_pk]) REFERENCES [model].[blueprint_version] ([blueprint_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[circuit_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_circuit_assessment_d7f5ffbac08f] FOREIGN KEY ([blueprint_version_pk],[blueprint_node_pk]) REFERENCES [model].[blueprint_node] ([blueprint_version_pk],[blueprint_node_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_circuit_assessment_a1186643516d] ON [analysis].[circuit_assessment] ([assessment_pk],[assessment_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_circuit_assessment_df08dc159ba2] ON [analysis].[circuit_assessment] ([blueprint_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_circuit_assessment_89bacf6f12db] ON [analysis].[circuit_assessment] ([blueprint_version_pk],[blueprint_node_pk]);
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_9851d8c36b81] FOREIGN KEY ([assessment_pk],[assessment_kind]) REFERENCES [analysis].[assessment] ([assessment_pk],[assessment_kind]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_f1492ae284e9] FOREIGN KEY ([provider_definition_pk]) REFERENCES [model].[provider_definition] ([provider_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_755237afca03] FOREIGN KEY ([provider_profile_version_pk]) REFERENCES [model].[provider_profile_version] ([provider_profile_version_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_9eb3412e05f4] FOREIGN KEY ([provider_slot_pk]) REFERENCES [model].[provider_slot] ([provider_slot_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_b2c5575795f7] FOREIGN KEY ([authority_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_50f026f45392] FOREIGN KEY ([rule_definition_pk]) REFERENCES [model].[semantic_object_definition] ([semantic_object_definition_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
ALTER TABLE [analysis].[provider_qualification_assessment] WITH CHECK ADD CONSTRAINT [FK_analysis_provider_qualification_assessment_180e518fc932] FOREIGN KEY ([source_observation_pk]) REFERENCES [source].[source_observation] ([source_observation_pk]) ON UPDATE NO ACTION ON DELETE NO ACTION;
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_a1186643516d] ON [analysis].[provider_qualification_assessment] ([assessment_pk],[assessment_kind]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_ef326537e30b] ON [analysis].[provider_qualification_assessment] ([provider_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_83c139ce8c61] ON [analysis].[provider_qualification_assessment] ([provider_profile_version_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_2d90e73aca32] ON [analysis].[provider_qualification_assessment] ([provider_slot_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_a14c24ea68bc] ON [analysis].[provider_qualification_assessment] ([authority_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_10c0f93db99b] ON [analysis].[provider_qualification_assessment] ([rule_definition_pk]);
GO
CREATE NONCLUSTERED INDEX [IX_analysis_provider_qualification_assessment_c2be5368d838] ON [analysis].[provider_qualification_assessment] ([source_observation_pk]);
GO
CREATE VIEW source.v_definition_witness AS SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[capability_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[product_definition] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[contract_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[execution_authority_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[transformation_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[mechanic_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[port_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[provider_definition] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[provider_profile_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[blueprint_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[authority_definition] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[scenario_version] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[scenario_input] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[scenario_event] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[scenario_outcome] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[fixture] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[observable_condition] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[proof_obligation] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[c4_context] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[c4_container] UNION ALL SELECT semantic_object_definition_pk,semantic_object_pk,object_kind FROM [model].[c4_component];
GO
CREATE VIEW source.v_identity_witness AS SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[capability] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[product] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[contract] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[execution_authority] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[transformation] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[mechanic] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[port] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[provider] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[provider_profile] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[blueprint] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[authority] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[scenario] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[scenario_input] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[scenario_event] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[scenario_outcome] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[fixture] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[observable_condition] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[proof_obligation] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[c4_context] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[c4_container] UNION SELECT DISTINCT semantic_object_pk,object_kind FROM [model].[c4_component];
GO
CREATE VIEW source.v_normalized_member AS SELECT _owner_definition_pk,CAST('definition_version_label' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[definition_version_label] UNION ALL SELECT _owner_definition_pk,CAST('capability_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[capability_version] UNION ALL SELECT _owner_definition_pk,CAST('product_definition' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[product_definition] UNION ALL SELECT _owner_definition_pk,CAST('contract_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[contract_version] UNION ALL SELECT _owner_definition_pk,CAST('execution_authority_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[execution_authority_version] UNION ALL SELECT _owner_definition_pk,CAST('transformation_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[transformation_version] UNION ALL SELECT _owner_definition_pk,CAST('mechanic_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[mechanic_version] UNION ALL SELECT _owner_definition_pk,CAST('port_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[port_version] UNION ALL SELECT _owner_definition_pk,CAST('provider_definition' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_definition] UNION ALL SELECT _owner_definition_pk,CAST('provider_profile_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_profile_version] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_version] UNION ALL SELECT _owner_definition_pk,CAST('authority_definition' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[authority_definition] UNION ALL SELECT _owner_definition_pk,CAST('scenario_version' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[scenario_version] UNION ALL SELECT _owner_definition_pk,CAST('capability_scenario' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[capability_scenario] UNION ALL SELECT _owner_definition_pk,CAST('capability_root_scenario' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[capability_root_scenario] UNION ALL SELECT _owner_definition_pk,CAST('scenario_input' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[scenario_input] UNION ALL SELECT _owner_definition_pk,CAST('scenario_event' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[scenario_event] UNION ALL SELECT _owner_definition_pk,CAST('scenario_outcome' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[scenario_outcome] UNION ALL SELECT _owner_definition_pk,CAST('outcome_variant' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[outcome_variant] UNION ALL SELECT _owner_definition_pk,CAST('outcome_product' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[outcome_product] UNION ALL SELECT _owner_definition_pk,CAST('outcome_variant_product' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[outcome_variant_product] UNION ALL SELECT _owner_definition_pk,CAST('scenario_outcome_contract' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[scenario_outcome_contract] UNION ALL SELECT _owner_definition_pk,CAST('port_contract' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[port_contract] UNION ALL SELECT _owner_definition_pk,CAST('execution_operation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[execution_operation] UNION ALL SELECT _owner_definition_pk,CAST('operation_port_invocation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_port_invocation] UNION ALL SELECT _owner_definition_pk,CAST('operation_scenario_invocation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_scenario_invocation] UNION ALL SELECT _owner_definition_pk,CAST('operation_state_projection' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_state_projection] UNION ALL SELECT _owner_definition_pk,CAST('operation_mechanic' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_mechanic] UNION ALL SELECT _owner_definition_pk,CAST('operation_predecessor' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_predecessor] UNION ALL SELECT _owner_definition_pk,CAST('transformation_expression_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[transformation_expression_node] UNION ALL SELECT _owner_definition_pk,CAST('transformation_expression_child' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[transformation_expression_child] UNION ALL SELECT _owner_definition_pk,CAST('transformation_root' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[transformation_root] UNION ALL SELECT _owner_definition_pk,CAST('expression_semantic_reference' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[expression_semantic_reference] UNION ALL SELECT _owner_definition_pk,CAST('operation_transformation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[operation_transformation] UNION ALL SELECT _owner_definition_pk,CAST('provider_port_implementation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_port_implementation] UNION ALL SELECT _owner_definition_pk,CAST('provider_mechanic_implementation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_mechanic_implementation] UNION ALL SELECT _owner_definition_pk,CAST('provider_capability_implementation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_capability_implementation] UNION ALL SELECT _owner_definition_pk,CAST('provider_profile_constraint' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_profile_constraint] UNION ALL SELECT _owner_definition_pk,CAST('provider_slot' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_slot] UNION ALL SELECT _owner_definition_pk,CAST('slot_port_requirement' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[slot_port_requirement] UNION ALL SELECT _owner_definition_pk,CAST('slot_mechanic_requirement' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[slot_mechanic_requirement] UNION ALL SELECT _owner_definition_pk,CAST('slot_profile_requirement' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[slot_profile_requirement] UNION ALL SELECT _owner_definition_pk,CAST('slot_profile_constraint' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[slot_profile_constraint] UNION ALL SELECT _owner_definition_pk,CAST('provider_binding_scope' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_binding_scope] UNION ALL SELECT _owner_definition_pk,CAST('provider_binding' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_binding] UNION ALL SELECT _owner_definition_pk,CAST('binding_port_implementation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[binding_port_implementation] UNION ALL SELECT _owner_definition_pk,CAST('binding_mechanic_implementation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[binding_mechanic_implementation] UNION ALL SELECT _owner_definition_pk,CAST('provider_slot_operation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[provider_slot_operation] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_node] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_node_face' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_node_face] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_node_scenario' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_node_scenario] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_edge' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_edge] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_edge_contract' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_edge_contract] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_convergence_requirement' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_convergence_requirement] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_fan_out_set' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_fan_out_set] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_fan_out_member' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_fan_out_member] UNION ALL SELECT _owner_definition_pk,CAST('blueprint_bounded_return' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[blueprint_bounded_return] UNION ALL SELECT _owner_definition_pk,CAST('fixture' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture] UNION ALL SELECT _owner_definition_pk,CAST('fixture_case' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture_case] UNION ALL SELECT _owner_definition_pk,CAST('fixture_assertion' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture_assertion] UNION ALL SELECT _owner_definition_pk,CAST('fixture_scenario_step' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture_scenario_step] UNION ALL SELECT _owner_definition_pk,CAST('fixture_port_outcome' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture_port_outcome] UNION ALL SELECT _owner_definition_pk,CAST('observable_condition' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[observable_condition] UNION ALL SELECT _owner_definition_pk,CAST('fixture_assertion_condition' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[fixture_assertion_condition] UNION ALL SELECT _owner_definition_pk,CAST('proof_obligation' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[proof_obligation] UNION ALL SELECT _owner_definition_pk,CAST('proof_obligation_subject' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[proof_obligation_subject] UNION ALL SELECT _owner_definition_pk,CAST('proof_obligation_fixture' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[proof_obligation_fixture] UNION ALL SELECT _owner_definition_pk,CAST('c4_context' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_context] UNION ALL SELECT _owner_definition_pk,CAST('c4_container' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_container] UNION ALL SELECT _owner_definition_pk,CAST('c4_component' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_component] UNION ALL SELECT _owner_definition_pk,CAST('c4_code_mapping' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_code_mapping] UNION ALL SELECT _owner_definition_pk,CAST('c4_context_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_context_node] UNION ALL SELECT _owner_definition_pk,CAST('c4_container_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_container_node] UNION ALL SELECT _owner_definition_pk,CAST('c4_component_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_component_node] UNION ALL SELECT _owner_definition_pk,CAST('c4_code_mapping_node' AS varchar(64)) COLLATE Latin1_General_100_BIN2 member_kind,_canonical_pointer_key FROM [model].[c4_code_mapping_node];
GO
CREATE PROCEDURE source.validate_model @estate_model_pk bigint WITH EXECUTE AS OWNER AS BEGIN SET NOCOUNT ON; IF EXISTS (SELECT 1 FROM source.estate_model WHERE estate_model_pk=@estate_model_pk AND publication_state<>'BUILDING') THROW 51001, 'MODEL_NOT_BUILDING', 1;
IF NOT EXISTS(SELECT 1 FROM source.estate_model WHERE estate_model_pk=@estate_model_pk) THROW 51001, 'MODEL_NOT_FOUND', 1;
IF NOT EXISTS(SELECT 1 FROM source.estate_model_rule WHERE estate_model_pk=@estate_model_pk) THROW 51001, 'G_PUBLISH_MAPPING_REQUIRED', 1;
IF EXISTS (SELECT 1 FROM source.mapping_rule r JOIN source.content_object c ON c.content_object_pk=r.rule_content_object_pk WHERE r.rule_digest<>c.content_digest) THROW 51001, 'G_CONTENT_MAPPING_RULE', 1;
IF EXISTS (SELECT 1 FROM source.source_observation o JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk JOIN source.estate_model m ON m.estate_snapshot_pk=a.estate_snapshot_pk WHERE m.estate_model_pk=@estate_model_pk AND o.locator_digest<>HASHBYTES('SHA2_256',CONVERT(varchar(max),o.locator COLLATE Latin1_General_100_BIN2_UTF8))) THROW 51001, 'G_CONTENT_LOCATOR', 1;
IF EXISTS (SELECT 1 FROM source.source_observation o JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk JOIN source.estate_model m ON m.estate_snapshot_pk=a.estate_snapshot_pk WHERE m.estate_model_pk=@estate_model_pk AND ((o.observation_kind='DECLARATION' AND NOT EXISTS(SELECT 1 FROM source.declaration_observation d WHERE d.source_observation_pk=o.source_observation_pk)) OR (o.observation_kind='RELATIONSHIP' AND NOT EXISTS(SELECT 1 FROM source.relationship_observation r WHERE r.source_observation_pk=o.source_observation_pk)))) THROW 51001, 'G_OBSERVATION_SUBTYPE', 1;
IF EXISTS (SELECT 1 FROM model.estate_definition ed JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=ed.semantic_object_definition_pk OUTER APPLY (SELECT COUNT_BIG(*) n FROM source.v_definition_witness w WHERE w.semantic_object_definition_pk=d.semantic_object_definition_pk AND w.semantic_object_pk=d.semantic_object_pk AND w.object_kind=d.object_kind) w WHERE ed.estate_model_pk=@estate_model_pk AND w.n<>1) THROW 51001, 'G_SUBTYPE_DEFINITION', 1;
IF EXISTS (SELECT 1 FROM model.estate_definition ed JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=ed.semantic_object_definition_pk WHERE ed.estate_model_pk=@estate_model_pk AND NOT EXISTS(SELECT 1 FROM source.v_identity_witness w WHERE w.semantic_object_pk=d.semantic_object_pk AND w.object_kind=d.object_kind)) THROW 51001, 'G_SUBTYPE_IDENTITY', 1;
IF EXISTS (SELECT 1 FROM model.estate_definition ed JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=ed.semantic_object_definition_pk JOIN source.content_object c ON c.content_object_pk=d.canonical_content_pk WHERE ed.estate_model_pk=@estate_model_pk AND (d.definition_digest<>c.content_digest OR ISJSON(CONVERT(varchar(max),c.content_bytes) COLLATE Latin1_General_100_BIN2_UTF8)<>1)) THROW 51001, 'G_CONTENT_DEFINITION', 1;
IF EXISTS (SELECT 1 FROM model.schema_object s JOIN source.content_object c ON c.content_object_pk=s.content_object_pk WHERE s.content_digest<>c.content_digest) THROW 51001, 'G_CONTENT_SCHEMA', 1;
IF EXISTS (SELECT 1 FROM model.binding_context b JOIN source.content_object c ON c.content_object_pk=b.canonical_content_pk WHERE b.context_digest<>c.content_digest) THROW 51001, 'G_CONTENT_CONTEXT', 1;
IF EXISTS (SELECT 1 FROM model.semantic_object o JOIN model.identity_namespace n ON n.namespace_pk=o.namespace_pk WHERE n.namespace_kind<>o.object_kind AND EXISTS(SELECT 1 FROM model.semantic_object_definition d JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=d.semantic_object_definition_pk WHERE ed.estate_model_pk=@estate_model_pk AND d.semantic_object_pk=o.semantic_object_pk)) THROW 51001, 'G_NAMESPACE_KIND', 1;
IF EXISTS (SELECT 1 FROM model.scenario s JOIN model.capability c ON c.capability_pk=s.capability_pk WHERE EXISTS(SELECT 1 FROM model.scenario_version v JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=v.semantic_object_definition_pk WHERE ed.estate_model_pk=@estate_model_pk AND v.scenario_pk=s.scenario_pk) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=s.namespace_pk AND n.owner_semantic_object_pk=c.semantic_object_pk AND n.scope_kind='SCENARIO')) THROW 51001, 'G_NAMESPACE_SCENARIO_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.scenario_input f JOIN model.scenario_version v ON v.scenario_version_pk=f.scenario_version_pk JOIN model.scenario s ON s.scenario_pk=v.scenario_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=s.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_FACE_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.scenario_event f JOIN model.scenario_version v ON v.scenario_version_pk=f.scenario_version_pk JOIN model.scenario s ON s.scenario_pk=v.scenario_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=s.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_FACE_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.scenario_outcome f JOIN model.scenario_version v ON v.scenario_version_pk=f.scenario_version_pk JOIN model.scenario s ON s.scenario_pk=v.scenario_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=s.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_FACE_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.fixture f JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=f.owner_definition_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=d.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_FIXTURE_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.observable_condition f JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=f.owner_definition_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=d.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_OBSERVABLE_CONDITION_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.proof_obligation f JOIN model.semantic_object_definition d ON d.semantic_object_definition_pk=f.owner_definition_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=d.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_PROOF_OBLIGATION_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.c4_context f JOIN model.blueprint_version v ON v.blueprint_version_pk=f.blueprint_version_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=v.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_C4_CONTEXT_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.c4_container f JOIN model.blueprint_version v ON v.blueprint_version_pk=f.blueprint_version_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=v.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_C4_CONTAINER_OWNER', 1;
IF EXISTS (SELECT 1 FROM model.c4_component f JOIN model.blueprint_version v ON v.blueprint_version_pk=f.blueprint_version_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=f.namespace_pk AND n.owner_semantic_object_pk=v.semantic_object_pk AND n.scope_kind=f.object_kind)) THROW 51001, 'G_NAMESPACE_C4_COMPONENT_OWNER', 1;
;WITH ancestry AS (SELECT o.semantic_object_pk,0 depth FROM model.semantic_object o WHERE NOT EXISTS(SELECT 1 FROM model.namespace_owner n WHERE n.namespace_pk=o.namespace_pk) UNION ALL SELECT o.semantic_object_pk,p.depth+1 FROM ancestry p JOIN model.namespace_owner n ON n.owner_semantic_object_pk=p.semantic_object_pk JOIN model.semantic_object o ON o.namespace_pk=n.namespace_pk) SELECT semantic_object_pk INTO #namespace_roots FROM ancestry OPTION(MAXRECURSION 32767); IF EXISTS (SELECT 1 FROM model.semantic_object_definition d JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=d.semantic_object_definition_pk WHERE ed.estate_model_pk=@estate_model_pk AND NOT EXISTS(SELECT 1 FROM #namespace_roots r WHERE r.semantic_object_pk=d.semantic_object_pk)) THROW 51001, 'G_NAMESPACE_OWNER_CYCLE', 1; DROP TABLE #namespace_roots;
IF EXISTS (SELECT 1 FROM [model].[definition_version_label] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_definition_version_label', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_capability_version', 1;
IF EXISTS (SELECT 1 FROM [model].[product_definition] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_product_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[contract_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_contract_version', 1;
IF EXISTS (SELECT 1 FROM [model].[execution_authority_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_execution_authority_version', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_transformation_version', 1;
IF EXISTS (SELECT 1 FROM [model].[mechanic_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_mechanic_version', 1;
IF EXISTS (SELECT 1 FROM [model].[port_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_port_version', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_definition] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_provider_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_profile_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_provider_profile_version', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_blueprint_version', 1;
IF EXISTS (SELECT 1 FROM [model].[authority_definition] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_authority_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_version] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_scenario_version', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_scenario] r JOIN [model].[capability_version] p ON p.[capability_version_pk]=r.[capability_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_capability_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_root_scenario] r JOIN [model].[capability_version] p ON p.[capability_version_pk]=r.[capability_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_capability_root_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_input] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_scenario_input', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_event] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_scenario_event', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_scenario_outcome', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_variant] r JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=r.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_outcome_variant', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_product] r JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=r.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_outcome_product', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_variant_product] r JOIN [model].[outcome_variant] p ON p.[outcome_variant_pk]=r.[outcome_variant_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_outcome_variant_product', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome_contract] r JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=r.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_scenario_outcome_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[port_contract] r JOIN [model].[port_version] p ON p.[port_version_pk]=r.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_port_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[execution_operation] r JOIN [model].[execution_authority_version] p ON p.[execution_authority_version_pk]=r.[execution_authority_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_execution_operation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_port_invocation] r JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=r.[execution_operation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_operation_port_invocation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_scenario_invocation] r JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=r.[execution_operation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_operation_scenario_invocation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_state_projection] r JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=r.[execution_operation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_operation_state_projection', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_mechanic] r JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=r.[execution_operation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_operation_mechanic', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_predecessor] r JOIN [model].[execution_authority_version] p ON p.[execution_authority_version_pk]=r.[execution_authority_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_operation_predecessor', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_expression_node] r JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=r.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_transformation_expression_node', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_expression_child] r JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=r.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_transformation_expression_child', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_root] r JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=r.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_transformation_root', 1;
IF EXISTS (SELECT 1 FROM [model].[expression_semantic_reference] r JOIN [model].[transformation_expression_node] p ON p.[expression_node_pk]=r.[expression_node_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_expression_semantic_reference', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_transformation] r JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=r.[execution_operation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_operation_transformation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_port_implementation] r JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=r.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_provider_port_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_mechanic_implementation] r JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=r.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_provider_mechanic_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_capability_implementation] r JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=r.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_provider_capability_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_profile_constraint] r JOIN [model].[provider_profile_version] p ON p.[provider_profile_version_pk]=r.[provider_profile_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_provider_profile_constraint', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_slot] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_provider_slot', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_port_requirement] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_slot_port_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_mechanic_requirement] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_slot_mechanic_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_profile_requirement] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_slot_profile_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_profile_constraint] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_slot_profile_constraint', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_binding_scope] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_provider_binding_scope', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_binding] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_provider_binding', 1;
IF EXISTS (SELECT 1 FROM [model].[binding_port_implementation] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_binding_port_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[binding_mechanic_implementation] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_binding_mechanic_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_slot_operation] r JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=r.[provider_slot_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_provider_slot_operation', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_node', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node_face] r JOIN [model].[blueprint_node] p ON p.[blueprint_node_pk]=r.[blueprint_node_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_blueprint_node_face', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node_scenario] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_node_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_edge', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge_contract] r JOIN [model].[blueprint_edge] p ON p.[blueprint_edge_pk]=r.[blueprint_edge_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_blueprint_edge_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_convergence_requirement] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_convergence_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_fan_out_set] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_fan_out_set', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_fan_out_member] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_blueprint_fan_out_member', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_bounded_return] r JOIN [model].[blueprint_edge] p ON p.[blueprint_edge_pk]=r.[blueprint_edge_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_blueprint_bounded_return', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_fixture', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_case] r JOIN [model].[fixture] p ON p.[fixture_pk]=r.[fixture_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_fixture_case', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_assertion] r JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=r.[fixture_case_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_fixture_assertion', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_scenario_step] r JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=r.[fixture_case_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_fixture_scenario_step', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_port_outcome] r JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=r.[fixture_case_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_fixture_port_outcome', 1;
IF EXISTS (SELECT 1 FROM [model].[observable_condition] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_observable_condition', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_assertion_condition] r JOIN [model].[fixture_assertion] p ON p.[fixture_assertion_pk]=r.[fixture_assertion_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[_owner_definition_pk]) THROW 51001, 'G_OWNER_fixture_assertion_condition', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_proof_obligation', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation_subject] r JOIN [model].[proof_obligation] p ON p.[proof_obligation_pk]=r.[proof_obligation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_proof_obligation_subject', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation_fixture] r JOIN [model].[proof_obligation] p ON p.[proof_obligation_pk]=r.[proof_obligation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_proof_obligation_fixture', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_c4_context', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_c4_container', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component] r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>r.semantic_object_definition_pk) THROW 51001, 'G_OWNER_c4_component', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_code_mapping] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_c4_code_mapping', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context_node] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_c4_context_node', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container_node] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_c4_container_node', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component_node] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_c4_component_node', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_code_mapping_node] r JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=r.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND r._owner_definition_pk<>p.[semantic_object_definition_pk]) THROW 51001, 'G_OWNER_c4_code_mapping_node', 1;
IF EXISTS (SELECT 1 FROM source.v_normalized_member r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM source.source_lineage l JOIN source.source_observation o ON o.source_observation_pk=l.source_observation_pk JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk JOIN source.estate_model m ON m.estate_snapshot_pk=a.estate_snapshot_pk AND m.estate_model_pk=@estate_model_pk JOIN source.estate_model_rule mr ON mr.estate_model_pk=m.estate_model_pk AND mr.mapping_rule_pk=l.mapping_rule_pk WHERE l.semantic_object_definition_pk=r._owner_definition_pk AND l.member_kind=r.member_kind AND l.canonical_pointer_key=r._canonical_pointer_key)) THROW 51001, 'G_LINEAGE_MEMBER', 1;
IF EXISTS (SELECT 1 FROM source.source_lineage l WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=l.[semantic_object_definition_pk]) AND NOT EXISTS(SELECT 1 FROM source.v_normalized_member r WHERE r._owner_definition_pk=l.semantic_object_definition_pk AND r.member_kind=l.member_kind AND r._canonical_pointer_key=l.canonical_pointer_key)) THROW 51001, 'G_LINEAGE_DANGLING', 1;
IF EXISTS (SELECT 1 FROM [model].[definition_version_label] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_definition_version_label', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_capability_version', 1;
IF EXISTS (SELECT 1 FROM [model].[product_definition] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_product_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[product_definition] r JOIN [model].[contract_version] p ON r.[contract_version_pk]=p.[contract_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_product_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[contract_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_contract_version', 1;
IF EXISTS (SELECT 1 FROM [model].[execution_authority_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_execution_authority_version', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_transformation_version', 1;
IF EXISTS (SELECT 1 FROM [model].[mechanic_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_mechanic_version', 1;
IF EXISTS (SELECT 1 FROM [model].[port_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_port_version', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_definition] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_profile_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_profile_version', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_version', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_version] r JOIN [model].[capability_version] p ON r.[capability_pk]=p.[capability_pk] AND r.[capability_version_pk]=p.[capability_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_version', 1;
IF EXISTS (SELECT 1 FROM [model].[authority_definition] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_authority_definition', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_version] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_version', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_scenario] r JOIN [model].[capability_version] p ON r.[capability_pk]=p.[capability_pk] AND r.[capability_version_pk]=p.[capability_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_capability_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[capability_scenario] r JOIN [model].[scenario_version] p ON r.[scenario_pk]=p.[scenario_pk] AND r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_capability_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_input] r JOIN [model].[scenario_version] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_input', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_input] r JOIN [model].[contract_version] p ON r.[input_contract_version_pk]=p.[contract_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_input', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_input] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_input', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_event] r JOIN [model].[scenario_version] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_event', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_event] r JOIN [model].[execution_authority_version] p ON r.[execution_authority_version_pk]=p.[execution_authority_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_event', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_event] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_event', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome] r JOIN [model].[scenario_version] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_outcome', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_outcome', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_variant] r JOIN [model].[scenario_outcome] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_outcome_variant', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_product] r JOIN [model].[scenario_outcome] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_outcome_product', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_product] r JOIN [model].[product_definition] p ON r.[product_definition_pk]=p.[product_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_outcome_product', 1;
IF EXISTS (SELECT 1 FROM [model].[outcome_variant_product] r JOIN [model].[product_definition] p ON r.[product_definition_pk]=p.[product_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_outcome_variant_product', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome_contract] r JOIN [model].[scenario_outcome] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_outcome_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[scenario_outcome_contract] r JOIN [model].[contract_version] p ON r.[contract_version_pk]=p.[contract_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_scenario_outcome_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[port_contract] r JOIN [model].[port_version] p ON r.[port_version_pk]=p.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_port_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[port_contract] r JOIN [model].[contract_version] p ON r.[contract_version_pk]=p.[contract_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_port_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[execution_operation] r JOIN [model].[execution_authority_version] p ON r.[execution_authority_version_pk]=p.[execution_authority_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_execution_operation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_port_invocation] r JOIN [model].[port_version] p ON r.[port_version_pk]=p.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_operation_port_invocation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_scenario_invocation] r JOIN [model].[scenario_version] p ON r.[target_scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_operation_scenario_invocation', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_state_projection] r JOIN [model].[transformation_version] p ON r.[transformation_version_pk]=p.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_operation_state_projection', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_mechanic] r JOIN [model].[mechanic_version] p ON r.[mechanic_version_pk]=p.[mechanic_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_operation_mechanic', 1;
IF EXISTS (SELECT 1 FROM [model].[transformation_expression_node] r JOIN [model].[transformation_version] p ON r.[transformation_version_pk]=p.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_transformation_expression_node', 1;
IF EXISTS (SELECT 1 FROM [model].[expression_semantic_reference] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[expected_kind]=p.[object_kind] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_expression_semantic_reference', 1;
IF EXISTS (SELECT 1 FROM [model].[operation_transformation] r JOIN [model].[transformation_version] p ON r.[transformation_version_pk]=p.[transformation_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_operation_transformation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_port_implementation] r JOIN [model].[provider_definition] p ON r.[provider_definition_pk]=p.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_port_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_port_implementation] r JOIN [model].[port_version] p ON r.[port_version_pk]=p.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_port_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_port_implementation] r JOIN [model].[provider_profile_version] p ON r.[provider_profile_version_pk]=p.[provider_profile_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_port_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_mechanic_implementation] r JOIN [model].[provider_definition] p ON r.[provider_definition_pk]=p.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_mechanic_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_mechanic_implementation] r JOIN [model].[mechanic_version] p ON r.[mechanic_version_pk]=p.[mechanic_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_mechanic_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_mechanic_implementation] r JOIN [model].[provider_profile_version] p ON r.[provider_profile_version_pk]=p.[provider_profile_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_mechanic_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_capability_implementation] r JOIN [model].[provider_definition] p ON r.[provider_definition_pk]=p.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_capability_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_capability_implementation] r JOIN [model].[capability_version] p ON r.[capability_version_pk]=p.[capability_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_capability_implementation', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_profile_constraint] r JOIN [model].[provider_profile_version] p ON r.[provider_profile_version_pk]=p.[provider_profile_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_profile_constraint', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_port_requirement] r JOIN [model].[port_version] p ON r.[port_version_pk]=p.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_slot_port_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_mechanic_requirement] r JOIN [model].[mechanic_version] p ON r.[mechanic_version_pk]=p.[mechanic_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_slot_mechanic_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[slot_profile_requirement] r JOIN [model].[provider_profile_version] p ON r.[provider_profile_version_pk]=p.[provider_profile_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_slot_profile_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[provider_binding] r JOIN [model].[provider_definition] p ON r.[provider_definition_pk]=p.[provider_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_provider_binding', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_node', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[expected_semantic_kind]=p.[object_kind] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_node', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node_face] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[expected_kind]=p.[object_kind] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_node_face', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_node_scenario] r JOIN [model].[scenario_version] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_node_scenario', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge] r JOIN [model].[semantic_object_definition] p ON r.[binding_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_edge', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge_contract] r JOIN [model].[product_definition] p ON r.[product_definition_pk]=p.[product_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_edge_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge_contract] r JOIN [model].[scenario_input] p ON r.[downstream_scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_edge_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_edge_contract] r JOIN [model].[semantic_object_definition] p ON r.[compatibility_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_edge_contract', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_convergence_requirement] r JOIN [model].[product_definition] p ON r.[product_definition_pk]=p.[product_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_convergence_requirement', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_fan_out_set] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_fan_out_set', 1;
IF EXISTS (SELECT 1 FROM [model].[blueprint_bounded_return] r JOIN [model].[semantic_object_definition] p ON r.[authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_blueprint_bounded_return', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture] r JOIN [model].[semantic_object_definition] p ON r.[owner_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_case] r JOIN [model].[fixture] p ON r.[fixture_pk]=p.[fixture_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture_case', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_case] r JOIN [model].[scenario_version] p ON r.[terminal_scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture_case', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_scenario_step] r JOIN [model].[scenario_version] p ON r.[scenario_version_pk]=p.[scenario_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture_scenario_step', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_port_outcome] r JOIN [model].[port_version] p ON r.[port_version_pk]=p.[port_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture_port_outcome', 1;
IF EXISTS (SELECT 1 FROM [model].[observable_condition] r JOIN [model].[semantic_object_definition] p ON r.[owner_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_observable_condition', 1;
IF EXISTS (SELECT 1 FROM [model].[observable_condition] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_observable_condition', 1;
IF EXISTS (SELECT 1 FROM [model].[fixture_assertion_condition] r JOIN [model].[observable_condition] p ON r.[observable_condition_pk]=p.[observable_condition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_fixture_assertion_condition', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation] r JOIN [model].[semantic_object_definition] p ON r.[owner_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_proof_obligation', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_proof_obligation', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation_subject] r JOIN [model].[proof_obligation] p ON r.[proof_obligation_pk]=p.[proof_obligation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_proof_obligation_subject', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation_subject] r JOIN [model].[semantic_object_definition] p ON r.[subject_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_proof_obligation_subject', 1;
IF EXISTS (SELECT 1 FROM [model].[proof_obligation_fixture] r JOIN [model].[proof_obligation] p ON r.[proof_obligation_pk]=p.[proof_obligation_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_proof_obligation_fixture', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_context', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context] r JOIN [model].[semantic_object_definition] p ON r.[realization_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_context', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_context', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_container', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container] r JOIN [model].[semantic_object_definition] p ON r.[realization_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_container', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_container', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container] r JOIN [model].[c4_context] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_context_pk]=p.[c4_context_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_container', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_component', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component] r JOIN [model].[semantic_object_definition] p ON r.[realization_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_component', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component] r JOIN [model].[semantic_object_definition] p ON r.[semantic_object_definition_pk]=p.[semantic_object_definition_pk] AND r.[semantic_object_pk]=p.[semantic_object_pk] AND r.[object_kind]=p.[object_kind] AND r.[definition_digest]=p.[definition_digest] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_component', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component] r JOIN [model].[c4_container] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_container_pk]=p.[c4_container_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_component', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_code_mapping] r JOIN [model].[blueprint_version] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_code_mapping', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_code_mapping] r JOIN [model].[c4_component] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_component_pk]=p.[c4_component_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_code_mapping', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_code_mapping] r JOIN [model].[semantic_object_definition] p ON r.[realization_authority_definition_pk]=p.[semantic_object_definition_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_code_mapping', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_context_node] r JOIN [model].[c4_context] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_context_pk]=p.[c4_context_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_context_node', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_container_node] r JOIN [model].[c4_container] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_container_pk]=p.[c4_container_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_container_node', 1;
IF EXISTS (SELECT 1 FROM [model].[c4_component_node] r JOIN [model].[c4_component] p ON r.[blueprint_version_pk]=p.[blueprint_version_pk] AND r.[c4_component_pk]=p.[c4_component_pk] WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=p.semantic_object_definition_pk)) THROW 51001, 'G_ESTATE_CLOSURE_c4_component_node', 1;
IF EXISTS (SELECT 1 FROM model.execution_operation o WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=o.[_owner_definition_pk]) AND ((o.operation_kind='invoke-port' AND NOT EXISTS(SELECT 1 FROM model.operation_port_invocation p WHERE p.execution_operation_pk=o.execution_operation_pk)) OR (o.operation_kind='invoke-scenario' AND NOT EXISTS(SELECT 1 FROM model.operation_scenario_invocation p WHERE p.execution_operation_pk=o.execution_operation_pk)) OR (o.operation_kind='project-state' AND NOT EXISTS(SELECT 1 FROM model.operation_state_projection p WHERE p.execution_operation_pk=o.execution_operation_pk)) OR o.operation_kind NOT IN('invoke-port','invoke-scenario','project-state'))) THROW 51001, 'G_EXECUTION_SUBTYPE', 1;
IF EXISTS (SELECT 1 FROM model.transformation_version v WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=v.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.transformation_root r WHERE r.transformation_version_pk=v.transformation_version_pk)) THROW 51001, 'G_EXPRESSION_ROOT', 1;
IF EXISTS (SELECT 1 FROM model.transformation_root r JOIN model.transformation_expression_child c ON c.child_node_pk=r.expression_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk])) THROW 51001, 'G_EXPRESSION_ROOT_PARENT', 1;
IF EXISTS (SELECT 1 FROM model.transformation_expression_node n WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=n.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.transformation_root r WHERE r.expression_node_pk=n.expression_node_pk) AND NOT EXISTS(SELECT 1 FROM model.transformation_expression_child c WHERE c.child_node_pk=n.expression_node_pk)) THROW 51001, 'G_EXPRESSION_DISCONNECTED', 1;
;WITH reachable AS (SELECT r.transformation_version_pk,r.expression_node_pk FROM model.transformation_root r WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) UNION ALL SELECT c.transformation_version_pk,c.child_node_pk FROM reachable r JOIN model.transformation_expression_child c ON c.parent_node_pk=r.expression_node_pk) SELECT DISTINCT expression_node_pk INTO #reachable FROM reachable OPTION(MAXRECURSION 32767); IF EXISTS (SELECT 1 FROM model.transformation_expression_node n WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=n.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM #reachable r WHERE r.expression_node_pk=n.expression_node_pk)) THROW 51001, 'G_EXPRESSION_CYCLE_OR_UNREACHABLE', 1; DROP TABLE #reachable;
IF EXISTS (SELECT 1 FROM model.transformation_expression_child c JOIN model.transformation_expression_node p ON p.expression_node_pk=c.parent_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=c.[_owner_definition_pk]) AND ((c.member_kind='ARRAY_MEMBER' AND p.node_kind<>'ARRAY') OR (c.member_kind='OBJECT_MEMBER' AND p.node_kind NOT IN ('OBJECT','OPERATOR')))) THROW 51001, 'G_EXPRESSION_PARENT_KIND', 1;
IF EXISTS (SELECT 1 FROM model.transformation_expression_child c WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=c.[_owner_definition_pk]) AND c.member_kind='ARRAY_MEMBER' GROUP BY c.parent_node_pk HAVING MIN(c.ordinal)<>0 OR MAX(c.ordinal)+1<>COUNT_BIG(*)) THROW 51001, 'G_EXPRESSION_ARRAY_ORDINALS', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_node_face f JOIN model.blueprint_node n ON n.blueprint_node_pk=f.blueprint_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND n.altitude='CAPABILITY' AND ((f.position='FIRST' AND f.expected_kind<>'SCENARIO_INPUT') OR (f.position='ENERGIZED' AND f.expected_kind<>'SCENARIO_EVENT') OR (f.position='RESULT' AND f.expected_kind NOT IN('SCENARIO_OUTCOME','PRODUCT')))) THROW 51001, 'G_GEOMETRY_FACE_KIND', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_node_face f JOIN model.scenario_input s ON s.semantic_object_definition_pk=f.semantic_object_definition_pk JOIN model.blueprint_node_scenario ns ON ns.blueprint_node_pk=f.blueprint_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND s.scenario_version_pk<>ns.scenario_version_pk) THROW 51001, 'G_GEOMETRY_FACE_SCENARIO', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_node_face f JOIN model.scenario_event s ON s.semantic_object_definition_pk=f.semantic_object_definition_pk JOIN model.blueprint_node_scenario ns ON ns.blueprint_node_pk=f.blueprint_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND s.scenario_version_pk<>ns.scenario_version_pk) THROW 51001, 'G_GEOMETRY_FACE_SCENARIO', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_node_face f JOIN model.scenario_outcome s ON s.semantic_object_definition_pk=f.semantic_object_definition_pk JOIN model.blueprint_node_scenario ns ON ns.blueprint_node_pk=f.blueprint_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=f.[_owner_definition_pk]) AND s.scenario_version_pk<>ns.scenario_version_pk) THROW 51001, 'G_GEOMETRY_FACE_SCENARIO', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_edge e WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=e.[_owner_definition_pk]) AND ((e.contract_relation IS NOT NULL AND NOT EXISTS(SELECT 1 FROM model.blueprint_edge_contract c WHERE c.blueprint_edge_pk=e.blueprint_edge_pk)) OR (e.topology_role='BOUNDED_RETURN' AND NOT EXISTS(SELECT 1 FROM model.blueprint_bounded_return b WHERE b.blueprint_edge_pk=e.blueprint_edge_pk)) OR (e.topology_role='FAN_OUT_MEMBER' AND NOT EXISTS(SELECT 1 FROM model.blueprint_fan_out_member f WHERE f.blueprint_edge_pk=e.blueprint_edge_pk)))) THROW 51001, 'G_GEOMETRY_REQUIRED_EXTENSION', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_bounded_return b JOIN model.blueprint_edge e ON e.blueprint_edge_pk=b.blueprint_edge_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=b.[_owner_definition_pk]) AND e.topology_role<>'BOUNDED_RETURN') THROW 51001, 'G_GEOMETRY_RETURN_KIND', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_fan_out_member b JOIN model.blueprint_edge e ON e.blueprint_edge_pk=b.blueprint_edge_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=b.[_owner_definition_pk]) AND e.topology_role<>'FAN_OUT_MEMBER') THROW 51001, 'G_GEOMETRY_FANOUT_KIND', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_convergence_requirement r JOIN model.blueprint_node n ON n.blueprint_node_pk=r.convergence_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=r.[_owner_definition_pk]) AND n.node_kind<>'convergence') THROW 51001, 'G_GEOMETRY_CONVERGENCE_KIND', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_edge e JOIN model.blueprint_node f ON f.blueprint_node_pk=e.from_node_pk JOIN model.blueprint_node t ON t.blueprint_node_pk=e.to_node_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=e.[_owner_definition_pk]) AND ((e.topology_role<>'ALTITUDE_DESCENT' AND f.altitude<>t.altitude) OR (e.topology_role='ALTITUDE_DESCENT' AND CASE f.altitude WHEN 'CAPABILITY' THEN 0 WHEN 'OPERATION' THEN 1 WHEN 'MECHANIC' THEN 2 ELSE 3 END >= CASE t.altitude WHEN 'CAPABILITY' THEN 0 WHEN 'OPERATION' THEN 1 WHEN 'MECHANIC' THEN 2 ELSE 3 END))) THROW 51001, 'G_GEOMETRY_ALTITUDE', 1;
IF EXISTS (SELECT 1 FROM model.blueprint_edge_contract c JOIN model.blueprint_edge e ON e.blueprint_edge_pk=c.blueprint_edge_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=c.[_owner_definition_pk]) AND (NOT EXISTS(SELECT 1 FROM model.blueprint_node_scenario n WHERE n.blueprint_node_pk=e.to_node_pk AND n.scenario_version_pk=c.downstream_scenario_version_pk) OR NOT EXISTS(SELECT 1 FROM model.blueprint_node_scenario n JOIN model.outcome_product p ON p.scenario_version_pk=n.scenario_version_pk WHERE n.blueprint_node_pk=e.from_node_pk AND p.product_definition_pk=c.product_definition_pk) AND NOT EXISTS(SELECT 1 FROM model.outcome_variant_product p WHERE p.outcome_variant_pk=e.selecting_variant_pk AND p.product_definition_pk=c.product_definition_pk))) THROW 51001, 'G_GEOMETRY_CONTRACT_ENDPOINT', 1;
IF EXISTS (SELECT 1 FROM model.provider_binding b JOIN model.slot_port_requirement r ON r.provider_slot_pk=b.provider_slot_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=b.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.binding_port_implementation i WHERE i.provider_binding_pk=b.provider_binding_pk AND i.slot_port_requirement_pk=r.slot_port_requirement_pk)) THROW 51001, 'G_BINDING_PORT_COVERAGE', 1;
IF EXISTS (SELECT 1 FROM model.provider_binding b JOIN model.slot_mechanic_requirement r ON r.provider_slot_pk=b.provider_slot_pk WHERE EXISTS (SELECT 1 FROM model.estate_definition ed WHERE ed.estate_model_pk=@estate_model_pk AND ed.semantic_object_definition_pk=b.[_owner_definition_pk]) AND NOT EXISTS(SELECT 1 FROM model.binding_mechanic_implementation i WHERE i.provider_binding_pk=b.provider_binding_pk AND i.slot_mechanic_requirement_pk=r.slot_mechanic_requirement_pk)) THROW 51001, 'G_BINDING_MECHANIC_COVERAGE', 1;
IF EXISTS (SELECT 1 FROM analysis.assessment a WHERE a.estate_model_pk=@estate_model_pk AND ((a.assessment_kind='COMPATIBILITY' AND NOT EXISTS(SELECT 1 FROM analysis.compatibility_assessment x WHERE x.assessment_pk=a.assessment_pk)) OR (a.assessment_kind='COVERAGE' AND NOT EXISTS(SELECT 1 FROM analysis.coverage_assessment x WHERE x.assessment_pk=a.assessment_pk)) OR (a.assessment_kind='CIRCUIT' AND NOT EXISTS(SELECT 1 FROM analysis.circuit_assessment x WHERE x.assessment_pk=a.assessment_pk)) OR (a.assessment_kind='PROVIDER_QUALIFICATION' AND NOT EXISTS(SELECT 1 FROM analysis.provider_qualification_assessment x WHERE x.assessment_pk=a.assessment_pk)) OR a.assessment_kind NOT IN('INTEGRITY','COMPATIBILITY','COVERAGE','CIRCUIT','PROVIDER_QUALIFICATION'))) THROW 51001, 'G_ASSESSMENT_SUBTYPE', 1;
IF EXISTS (SELECT 1 FROM analysis.compatibility_assessment c JOIN analysis.assessment a ON a.assessment_pk=c.assessment_pk WHERE a.estate_model_pk=@estate_model_pk AND ((a.evaluation_state<>'EVALUATED' AND c.result_code IS NOT NULL) OR (a.evaluation_state='EVALUATED' AND c.result_code IS NULL))) THROW 51001, 'G_ASSESSMENT_RESULT_STATE', 1;
IF EXISTS (SELECT 1 FROM analysis.circuit_assessment c JOIN analysis.assessment a ON a.assessment_pk=c.assessment_pk WHERE a.estate_model_pk=@estate_model_pk AND ((a.evaluation_state<>'EVALUATED' AND c.result_code IS NOT NULL) OR (a.evaluation_state='EVALUATED' AND c.result_code IS NULL))) THROW 51001, 'G_ASSESSMENT_RESULT_STATE', 1;
IF EXISTS (SELECT 1 FROM analysis.provider_qualification_assessment c JOIN analysis.assessment a ON a.assessment_pk=c.assessment_pk WHERE a.estate_model_pk=@estate_model_pk AND (a.evaluation_state<>'EVALUATED' OR c.effective_until<a.evaluated_at)) THROW 51001, 'G_ASSESSMENT_QUALIFICATION', 1;
IF EXISTS (SELECT 1 FROM analysis.assessment a WHERE a.estate_model_pk=@estate_model_pk AND ((a.evaluation_state='EVALUATED' AND a.evaluated_at IS NULL) OR (a.evaluation_state<>'EVALUATED' AND a.evaluated_at IS NOT NULL))) THROW 51001, 'G_ASSESSMENT_EVALUATION_TIME', 1;
IF EXISTS (SELECT 1 FROM analysis.assessment_definition_input i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk WHERE a.estate_model_pk=@estate_model_pk AND NOT EXISTS(SELECT 1 FROM model.estate_definition d WHERE d.estate_model_pk=a.estate_model_pk AND d.semantic_object_definition_pk=i.semantic_object_definition_pk)) THROW 51001, 'G_ASSESSMENT_INPUT_ESTATE', 1;
IF EXISTS (SELECT 1 FROM analysis.assessment_source_input i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.source_observation o ON o.source_observation_pk=i.source_observation_pk JOIN source.source_appearance p ON p.source_appearance_pk=o.source_appearance_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE a.estate_model_pk=@estate_model_pk AND p.estate_snapshot_pk<>m.estate_snapshot_pk) THROW 51001, 'G_ASSESSMENT_SOURCE_ESTATE', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE (is_disabled=1 OR is_not_trusted=1) AND OBJECT_SCHEMA_NAME(parent_object_id) IN('model','source','analysis') UNION ALL SELECT 1 FROM sys.check_constraints WHERE (is_disabled=1 OR is_not_trusted=1) AND OBJECT_SCHEMA_NAME(parent_object_id) IN('model','source','analysis')) THROW 51001, 'G_PUBLISH_UNTRUSTED_CONSTRAINT', 1; END;
GO
CREATE PROCEDURE source.publish_model @estate_model_pk bigint WITH EXECUTE AS OWNER AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRY BEGIN TRANSACTION; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF NOT EXISTS(SELECT 1 FROM source.estate_model WHERE estate_model_pk=@estate_model_pk) THROW 51001,'MODEL_NOT_FOUND',1; IF EXISTS(SELECT 1 FROM source.estate_model WHERE estate_model_pk=@estate_model_pk AND publication_state<>'BUILDING') THROW 51001,'MODEL_NOT_BUILDING',1; IF NOT EXISTS(SELECT 1 FROM model.estate_capability WHERE estate_model_pk=@estate_model_pk) THROW 51001,'MODEL_EMPTY_MEMBERSHIP',1; UPDATE source.estate_model SET publication_state='PUBLISHED' WHERE estate_model_pk=@estate_model_pk; UPDATE source.current_model SET estate_model_pk=@estate_model_pk WHERE singleton_id=1; IF @@ROWCOUNT=0 INSERT source.current_model(singleton_id,estate_model_pk) VALUES(1,@estate_model_pk); COMMIT; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH END;
GO
CREATE TRIGGER [source].[guard_estate_snapshot] ON [source].[estate_snapshot] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_content_object] ON [source].[content_object] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_source_appearance] ON [source].[source_appearance] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_mapping_rule] ON [source].[mapping_rule] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_source_classification] ON [source].[source_classification] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_namespace_mapping] ON [source].[namespace_mapping] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_source_observation] ON [source].[source_observation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_declaration_observation] ON [source].[declaration_observation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_relationship_observation] ON [source].[relationship_observation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_source_lineage] ON [source].[source_lineage] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [source].[guard_estate_model_rule] ON [source].[estate_model_rule] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_identity_namespace] ON [model].[identity_namespace] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_namespace_owner] ON [model].[namespace_owner] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_semantic_object] ON [model].[semantic_object] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_semantic_object_definition] ON [model].[semantic_object_definition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_definition_version_label] ON [model].[definition_version_label] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_estate_definition] ON [model].[estate_definition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_estate_capability] ON [model].[estate_capability] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_capability] ON [model].[capability] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_capability_version] ON [model].[capability_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_product] ON [model].[product] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_product_definition] ON [model].[product_definition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_contract] ON [model].[contract] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_contract_version] ON [model].[contract_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_execution_authority] ON [model].[execution_authority] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_execution_authority_version] ON [model].[execution_authority_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_transformation] ON [model].[transformation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_transformation_version] ON [model].[transformation_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_mechanic] ON [model].[mechanic] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_mechanic_version] ON [model].[mechanic_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_port] ON [model].[port] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_port_version] ON [model].[port_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider] ON [model].[provider] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_provider_definition] ON [model].[provider_definition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_profile] ON [model].[provider_profile] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_provider_profile_version] ON [model].[provider_profile_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint] ON [model].[blueprint] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_blueprint_version] ON [model].[blueprint_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_authority] ON [model].[authority] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_authority_definition] ON [model].[authority_definition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_scenario] ON [model].[scenario] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_scenario_version] ON [model].[scenario_version] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_capability_scenario] ON [model].[capability_scenario] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[capability_version] p ON p.[capability_version_pk]=i.[capability_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_capability_root_scenario] ON [model].[capability_root_scenario] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[capability_version] p ON p.[capability_version_pk]=i.[capability_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_scenario_input] ON [model].[scenario_input] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.scenario_version v ON v.scenario_version_pk=i.scenario_version_pk JOIN model.estate_definition d ON d.semantic_object_definition_pk=v.semantic_object_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_SCENARIO_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_scenario_event] ON [model].[scenario_event] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.scenario_version v ON v.scenario_version_pk=i.scenario_version_pk JOIN model.estate_definition d ON d.semantic_object_definition_pk=v.semantic_object_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_SCENARIO_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_scenario_outcome] ON [model].[scenario_outcome] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.scenario_version v ON v.scenario_version_pk=i.scenario_version_pk JOIN model.estate_definition d ON d.semantic_object_definition_pk=v.semantic_object_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_SCENARIO_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_outcome_variant] ON [model].[outcome_variant] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=i.[scenario_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_outcome_product] ON [model].[outcome_product] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=i.[scenario_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_outcome_variant_product] ON [model].[outcome_variant_product] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[outcome_variant] p ON p.[outcome_variant_pk]=i.[outcome_variant_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_scenario_outcome_contract] ON [model].[scenario_outcome_contract] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[scenario_version] p ON p.[scenario_version_pk]=i.[scenario_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_schema_object] ON [model].[schema_object] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_port_contract] ON [model].[port_contract] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[port_version] p ON p.[port_version_pk]=i.[port_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_execution_operation] ON [model].[execution_operation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_authority_version] p ON p.[execution_authority_version_pk]=i.[execution_authority_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_port_invocation] ON [model].[operation_port_invocation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=i.[execution_operation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_scenario_invocation] ON [model].[operation_scenario_invocation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=i.[execution_operation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_state_projection] ON [model].[operation_state_projection] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=i.[execution_operation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_mechanic] ON [model].[operation_mechanic] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=i.[execution_operation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_predecessor] ON [model].[operation_predecessor] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_authority_version] p ON p.[execution_authority_version_pk]=i.[execution_authority_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_transformation_expression_node] ON [model].[transformation_expression_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=i.[transformation_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_transformation_expression_child] ON [model].[transformation_expression_child] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=i.[transformation_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_transformation_root] ON [model].[transformation_root] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[transformation_version] p ON p.[transformation_version_pk]=i.[transformation_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_expression_semantic_reference] ON [model].[expression_semantic_reference] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[transformation_expression_node] p ON p.[expression_node_pk]=i.[expression_node_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_operation_transformation] ON [model].[operation_transformation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[execution_operation] p ON p.[execution_operation_pk]=i.[execution_operation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_port_implementation] ON [model].[provider_port_implementation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=i.[provider_definition_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_mechanic_implementation] ON [model].[provider_mechanic_implementation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=i.[provider_definition_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_capability_implementation] ON [model].[provider_capability_implementation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_definition] p ON p.[provider_definition_pk]=i.[provider_definition_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_profile_constraint] ON [model].[provider_profile_constraint] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_profile_version] p ON p.[provider_profile_version_pk]=i.[provider_profile_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_slot] ON [model].[provider_slot] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_slot_port_requirement] ON [model].[slot_port_requirement] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_slot_mechanic_requirement] ON [model].[slot_mechanic_requirement] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_slot_profile_requirement] ON [model].[slot_profile_requirement] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_slot_profile_constraint] ON [model].[slot_profile_constraint] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_binding_context] ON [model].[binding_context] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_provider_binding_scope] ON [model].[provider_binding_scope] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_binding] ON [model].[provider_binding] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_binding_port_implementation] ON [model].[binding_port_implementation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_binding_mechanic_implementation] ON [model].[binding_mechanic_implementation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_provider_slot_operation] ON [model].[provider_slot_operation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[provider_slot] p ON p.[provider_slot_pk]=i.[provider_slot_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_node] ON [model].[blueprint_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_node_face] ON [model].[blueprint_node_face] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_node] p ON p.[blueprint_node_pk]=i.[blueprint_node_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_node_scenario] ON [model].[blueprint_node_scenario] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_edge] ON [model].[blueprint_edge] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_edge_contract] ON [model].[blueprint_edge_contract] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_edge] p ON p.[blueprint_edge_pk]=i.[blueprint_edge_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_convergence_requirement] ON [model].[blueprint_convergence_requirement] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_fan_out_set] ON [model].[blueprint_fan_out_set] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_fan_out_member] ON [model].[blueprint_fan_out_member] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_bounded_return] ON [model].[blueprint_bounded_return] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_edge] p ON p.[blueprint_edge_pk]=i.[blueprint_edge_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture] ON [model].[fixture] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture_case] ON [model].[fixture_case] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[fixture] p ON p.[fixture_pk]=i.[fixture_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture_assertion] ON [model].[fixture_assertion] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=i.[fixture_case_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture_scenario_step] ON [model].[fixture_scenario_step] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=i.[fixture_case_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture_port_outcome] ON [model].[fixture_port_outcome] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[fixture_case] p ON p.[fixture_case_pk]=i.[fixture_case_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_observable_condition] ON [model].[observable_condition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_fixture_assertion_condition] ON [model].[fixture_assertion_condition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[fixture_assertion] p ON p.[fixture_assertion_pk]=i.[fixture_assertion_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[_owner_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_proof_obligation] ON [model].[proof_obligation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_proof_obligation_subject] ON [model].[proof_obligation_subject] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[proof_obligation] p ON p.[proof_obligation_pk]=i.[proof_obligation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_proof_obligation_fixture] ON [model].[proof_obligation_fixture] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[proof_obligation] p ON p.[proof_obligation_pk]=i.[proof_obligation_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_context] ON [model].[c4_context] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_container] ON [model].[c4_container] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_component] ON [model].[c4_component] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_code_mapping] ON [model].[c4_code_mapping] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_context_node] ON [model].[c4_context_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_container_node] ON [model].[c4_container_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_component_node] ON [model].[c4_component_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_c4_code_mapping_node] ON [model].[c4_code_mapping_node] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN model.estate_definition d ON d.semantic_object_definition_pk=i._owner_definition_pk JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_DEFINITION_IMMUTABLE',1; IF EXISTS(SELECT 1 FROM inserted i JOIN [model].[blueprint_version] p ON p.[blueprint_version_pk]=i.[blueprint_version_pk] JOIN model.estate_definition d ON d.semantic_object_definition_pk=p.[semantic_object_definition_pk] JOIN source.estate_model m ON m.estate_model_pk=d.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_OWNER_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_observed_semantic_graph_transition] ON [model].[observed_semantic_graph_transition] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_observed_execution_scenario_invocation] ON [model].[observed_execution_scenario_invocation] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [model].[guard_observed_transition_resolution] ON [model].[observed_transition_resolution] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_observed_invocation_resolution] ON [model].[observed_invocation_resolution] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_observed_transition_mapping] ON [model].[blueprint_observed_transition_mapping] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [model].[guard_blueprint_observed_invocation_mapping] ON [model].[blueprint_observed_invocation_mapping] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_integrity_rule] ON [analysis].[integrity_rule] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  END;
GO
CREATE TRIGGER [analysis].[guard_assessment] ON [analysis].[assessment] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_assessment_source_input] ON [analysis].[assessment_source_input] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_assessment_definition_input] ON [analysis].[assessment_definition_input] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_integrity_finding] ON [analysis].[integrity_finding] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_unresolved_reference] ON [analysis].[unresolved_reference] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1; IF EXISTS(SELECT 1 FROM inserted i JOIN source.estate_model m ON m.estate_model_pk=i.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_MEMBERSHIP_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_compatibility_assessment] ON [analysis].[compatibility_assessment] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_coverage_assessment] ON [analysis].[coverage_assessment] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_circuit_assessment] ON [analysis].[circuit_assessment] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
CREATE TRIGGER [analysis].[guard_provider_qualification_assessment] ON [analysis].[provider_qualification_assessment] AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='sidefx:model-write',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @lock<0 THROW 51002,'MODEL_LOCK_UNAVAILABLE',1; IF EXISTS(SELECT 1 FROM deleted) THROW 51003,'IMMUTABLE_INSPECTION_DATA',1;  IF EXISTS(SELECT 1 FROM inserted i JOIN analysis.assessment a ON a.assessment_pk=i.assessment_pk JOIN source.estate_model m ON m.estate_model_pk=a.estate_model_pk WHERE m.publication_state='PUBLISHED') THROW 51003,'PUBLISHED_ASSESSMENT_IMMUTABLE',1; END;
GO
IF DATABASE_PRINCIPAL_ID('sidefx_reader') IS NULL CREATE USER sidefx_reader WITHOUT LOGIN; IF DATABASE_PRINCIPAL_ID('sidefx_importer') IS NULL CREATE USER sidefx_importer WITHOUT LOGIN; GRANT SELECT ON SCHEMA::sidefx TO sidefx_reader; GRANT SELECT ON SCHEMA::model TO sidefx_reader; GRANT SELECT ON SCHEMA::source TO sidefx_reader; GRANT SELECT ON SCHEMA::analysis TO sidefx_reader; DENY INSERT,UPDATE,DELETE,ALTER ON SCHEMA::model TO sidefx_reader; DENY INSERT,UPDATE,DELETE,ALTER ON SCHEMA::source TO sidefx_reader; DENY INSERT,UPDATE,DELETE,ALTER ON SCHEMA::analysis TO sidefx_reader; DENY ALTER ON SCHEMA::sidefx TO sidefx_reader; GRANT SELECT,INSERT ON SCHEMA::model TO sidefx_importer; GRANT SELECT,INSERT ON SCHEMA::source TO sidefx_importer; GRANT SELECT,INSERT ON SCHEMA::analysis TO sidefx_importer; DENY UPDATE,DELETE,ALTER ON SCHEMA::model TO sidefx_importer; DENY UPDATE,DELETE,ALTER ON SCHEMA::source TO sidefx_importer; DENY UPDATE,DELETE,ALTER ON SCHEMA::analysis TO sidefx_importer; DENY INSERT,UPDATE,DELETE ON OBJECT::source.current_model TO sidefx_importer; GRANT EXECUTE ON OBJECT::source.validate_model TO sidefx_importer; GRANT EXECUTE ON OBJECT::source.publish_model TO sidefx_importer;
GO
CREATE TRIGGER source.guard_estate_model ON source.estate_model AFTER INSERT AS BEGIN IF EXISTS(SELECT 1 FROM inserted WHERE publication_state<>'BUILDING') THROW 51003,'MODEL_MUST_START_BUILDING',1; END;
GO
CREATE VIEW sidefx.[v_capability_version] AS SELECT v.[capability_version_pk],v.[capability_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[actor],v.[intent],v.[outcome],v.[experience_id],v.[experience_actor],v.[experience_promise],v.[object_kind] FROM model.capability_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_capability] AS SELECT c.capability_pk,c.namespace_pk,c.capability_id,v.capability_version_pk,v.definition_digest,v.name,v.experience_id FROM source.current_model cm JOIN model.estate_capability ec ON ec.estate_model_pk=cm.estate_model_pk JOIN model.capability c ON c.capability_pk=ec.capability_pk JOIN model.capability_version v ON v.capability_version_pk=ec.capability_version_pk;
GO
CREATE VIEW sidefx.[v_product_definition] AS SELECT v.[product_definition_pk],v.[product_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[contract_version_pk],v.[object_kind],v.[contract_reference_state] FROM model.product_definition v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_product] AS SELECT i.[product_pk],i.[namespace_pk],i.[product_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.product_definition v WHERE v.product_pk=i.product_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.product i WHERE EXISTS(SELECT 1 FROM model.product_definition v WHERE v.product_pk=i.product_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_contract_version] AS SELECT v.[contract_version_pk],v.[contract_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[contract_kind],v.[schema_object_pk],v.[object_kind],v.[schema_reference_state] FROM model.contract_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_contract] AS SELECT i.[contract_pk],i.[namespace_pk],i.[contract_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.contract_version v WHERE v.contract_pk=i.contract_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.contract i WHERE EXISTS(SELECT 1 FROM model.contract_version v WHERE v.contract_pk=i.contract_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_execution_authority_version] AS SELECT v.[execution_authority_version_pk],v.[execution_authority_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[authority_profile],v.[object_kind] FROM model.execution_authority_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_transformation_version] AS SELECT v.[transformation_version_pk],v.[transformation_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[expression_profile],v.[object_kind] FROM model.transformation_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_transformation] AS SELECT i.[transformation_pk],i.[namespace_pk],i.[transformation_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.transformation_version v WHERE v.transformation_pk=i.transformation_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.transformation i WHERE EXISTS(SELECT 1 FROM model.transformation_version v WHERE v.transformation_pk=i.transformation_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_mechanic_version] AS SELECT v.[mechanic_version_pk],v.[mechanic_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[mechanic_kind],v.[definition_profile],v.[object_kind] FROM model.mechanic_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_mechanic] AS SELECT i.[mechanic_pk],i.[namespace_pk],i.[mechanic_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.mechanic_version v WHERE v.mechanic_pk=i.mechanic_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.mechanic i WHERE EXISTS(SELECT 1 FROM model.mechanic_version v WHERE v.mechanic_pk=i.mechanic_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_port_version] AS SELECT v.[port_version_pk],v.[port_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[port_profile],v.[object_kind] FROM model.port_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_port] AS SELECT i.[port_pk],i.[namespace_pk],i.[port_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.port_version v WHERE v.port_pk=i.port_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.port i WHERE EXISTS(SELECT 1 FROM model.port_version v WHERE v.port_pk=i.port_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_provider_definition] AS SELECT v.[provider_definition_pk],v.[provider_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[declaration_profile],v.[object_kind] FROM model.provider_definition v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_provider] AS SELECT i.[provider_pk],i.[namespace_pk],i.[provider_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.provider_definition v WHERE v.provider_pk=i.provider_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.provider i WHERE EXISTS(SELECT 1 FROM model.provider_definition v WHERE v.provider_pk=i.provider_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_provider_profile_version] AS SELECT v.[provider_profile_version_pk],v.[provider_profile_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[profile_name],v.[profile_authority],v.[object_kind] FROM model.provider_profile_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_provider_profile] AS SELECT i.[provider_profile_pk],i.[namespace_pk],i.[provider_profile_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.provider_profile_version v WHERE v.provider_profile_pk=i.provider_profile_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.provider_profile i WHERE EXISTS(SELECT 1 FROM model.provider_profile_version v WHERE v.provider_profile_pk=i.provider_profile_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_blueprint_version] AS SELECT v.[blueprint_version_pk],v.[blueprint_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[capability_pk],v.[capability_version_pk],v.[carrier_profile],v.[source_disposition],v.[object_kind] FROM model.blueprint_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_authority_definition] AS SELECT v.[authority_definition_pk],v.[authority_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[authority_kind],v.[authority_profile],v.[object_kind] FROM model.authority_definition v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_authority] AS SELECT i.[authority_pk],i.[namespace_pk],i.[authority_id],i.[semantic_object_pk],i.[object_kind],(SELECT COUNT_BIG(*) FROM model.authority_definition v WHERE v.authority_pk=i.authority_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk)) definition_count FROM model.authority i WHERE EXISTS(SELECT 1 FROM model.authority_definition v WHERE v.authority_pk=i.authority_pk AND EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk));
GO
CREATE VIEW sidefx.[v_scenario_version] AS SELECT v.[scenario_version_pk],v.[scenario_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[name],v.[source_profile],v.[object_kind] FROM model.scenario_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_scenario] AS SELECT s.scenario_pk,s.capability_pk,s.scenario_id,v.scenario_version_pk,cs.capability_version_pk,v.definition_digest,v.name,v.source_profile,CONVERT(bit,CASE WHEN i.scenario_version_pk IS NOT NULL THEN 1 ELSE 0 END) has_input,CONVERT(bit,CASE WHEN e.scenario_version_pk IS NOT NULL THEN 1 ELSE 0 END) has_event,CONVERT(bit,CASE WHEN o.scenario_version_pk IS NOT NULL THEN 1 ELSE 0 END) has_outcome,i.contract_reference_state,e.authority_reference_state FROM source.current_model cm JOIN model.estate_capability ec ON ec.estate_model_pk=cm.estate_model_pk JOIN model.capability_scenario cs ON cs.capability_version_pk=ec.capability_version_pk JOIN model.scenario s ON s.scenario_pk=cs.scenario_pk JOIN model.scenario_version v ON v.scenario_version_pk=cs.scenario_version_pk LEFT JOIN model.scenario_input i ON i.scenario_version_pk=v.scenario_version_pk LEFT JOIN model.scenario_event e ON e.scenario_version_pk=v.scenario_version_pk LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk=v.scenario_version_pk;
GO
CREATE VIEW sidefx.[v_complete_scenario] AS SELECT s.* FROM sidefx.v_scenario s WHERE has_input=1 AND has_event=1 AND has_outcome=1 AND contract_reference_state='RESOLVED' AND authority_reference_state IN('RESOLVED','ABSENT','NOT_APPLICABLE') AND (source_profile NOT LIKE 'scenario-semantic-carrier%' OR EXISTS(SELECT 1 FROM model.outcome_product p WHERE p.scenario_version_pk=s.scenario_version_pk));
GO
CREATE VIEW sidefx.[v_execution_authority] AS SELECT v.[execution_authority_version_pk],v.[execution_authority_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[authority_profile],v.[object_kind] FROM model.execution_authority_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_blueprint] AS SELECT v.[blueprint_version_pk],v.[blueprint_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[definition_digest],v.[capability_pk],v.[capability_version_pk],v.[carrier_profile],v.[source_disposition],v.[object_kind] FROM model.blueprint_version v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v.semantic_object_definition_pk);
GO
CREATE VIEW sidefx.[v_execution_operation] AS SELECT v.[execution_operation_pk],v.[execution_authority_version_pk],v.[operation_id],v.[ordinal],v.[operation_kind] FROM model.execution_operation v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_blueprint_node] AS SELECT v.[blueprint_node_pk],v.[blueprint_version_pk],v.[node_id],v.[node_kind],v.[altitude],v.[projection_ordinal],v.[semantic_object_definition_pk],v.[expected_semantic_kind],v.[terminal_disposition] FROM model.blueprint_node v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_blueprint_edge] AS SELECT v.[blueprint_edge_pk],v.[blueprint_version_pk],v.[edge_id],v.[from_node_pk],v.[to_node_pk],v.[topology_role],v.[contract_relation],v.[semantic_progress],v.[source_scenario_version_pk],v.[selecting_variant_pk],v.[semantic_precedence],v.[projection_ordinal],v.[binding_authority_definition_pk] FROM model.blueprint_edge v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_provider_slot] AS SELECT v.[provider_slot_pk],v.[blueprint_version_pk],v.[slot_id],v.[owner_node_pk] FROM model.provider_slot v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_outcome_product] AS SELECT v.[scenario_version_pk],v.[product_definition_pk] FROM model.outcome_product v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_outcome_variant_product] AS SELECT v.[outcome_variant_pk],v.[product_definition_pk] FROM model.outcome_variant_product v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_outcome_variant] AS SELECT v.[outcome_variant_pk],v.[scenario_version_pk],v.[variant_id],v.[terminal] FROM model.outcome_variant v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_scenario_input] AS SELECT v.[scenario_version_pk],v.[input_id],v.[name],v.[input_contract_version_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind],v.[contract_reference_state] FROM model.scenario_input v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_scenario_event] AS SELECT v.[scenario_version_pk],v.[event_id],v.[name],v.[responsibility],v.[execution_authority_version_pk],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind],v.[authority_reference_state] FROM model.scenario_event v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_scenario_outcome] AS SELECT v.[scenario_version_pk],v.[outcome_id],v.[name],v.[experience],v.[terminal],v.[terminal_disposition],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind] FROM model.scenario_outcome v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_port_contract] AS SELECT v.[port_version_pk],v.[direction],v.[member_ordinal],v.[role],v.[contract_version_pk] FROM model.port_contract v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_slot_port_requirement] AS SELECT v.[slot_port_requirement_pk],v.[provider_slot_pk],v.[port_version_pk],v.[ordinal],v.[role] FROM model.slot_port_requirement v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_slot_mechanic_requirement] AS SELECT v.[slot_mechanic_requirement_pk],v.[provider_slot_pk],v.[mechanic_version_pk],v.[ordinal],v.[role] FROM model.slot_mechanic_requirement v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_slot_profile_requirement] AS SELECT v.[slot_profile_requirement_pk],v.[provider_slot_pk],v.[provider_profile_version_pk],v.[ordinal],v.[role] FROM model.slot_profile_requirement v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_fixture] AS SELECT v.[fixture_pk],v.[owner_definition_pk],v.[fixture_id],v.[fixture_profile],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind] FROM model.fixture v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_fixture_case] AS SELECT v.[fixture_case_pk],v.[fixture_pk],v.[case_id],v.[ordinal],v.[input_content_pk],v.[expected_disposition],v.[terminal_scenario_version_pk] FROM model.fixture_case v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_fixture_assertion] AS SELECT v.[fixture_assertion_pk],v.[fixture_case_pk],v.[ordinal],v.[condition_id],v.[path],v.[operator],v.[expected_value_content_pk] FROM model.fixture_assertion v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_observable_condition] AS SELECT v.[observable_condition_pk],v.[owner_definition_pk],v.[condition_id],v.[statement],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind] FROM model.observable_condition v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_proof_obligation] AS SELECT v.[proof_obligation_pk],v.[owner_definition_pk],v.[proof_obligation_id],v.[obligation_kind],v.[statement],v.[semantic_object_pk],v.[semantic_object_definition_pk],v.[namespace_pk],v.[definition_digest],v.[object_kind] FROM model.proof_obligation v WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=v._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_provider_implementation] AS SELECT CAST('PORT' AS varchar(64)) implementation_kind,i.provider_port_implementation_pk implementation_pk,i.provider_definition_pk,i.port_version_pk target_version_pk,i.provider_profile_version_pk,i.role FROM model.provider_port_implementation i WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=i._owner_definition_pk) UNION ALL SELECT CAST('MECHANIC' AS varchar(64)) implementation_kind,i.provider_mechanic_implementation_pk implementation_pk,i.provider_definition_pk,i.mechanic_version_pk target_version_pk,i.provider_profile_version_pk,i.role FROM model.provider_mechanic_implementation i WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=i._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_provider_binding] AS SELECT b.provider_binding_pk,b.provider_binding_scope_pk,b.provider_slot_pk,b.provider_definition_pk,b.selection_policy,b.ordinal,s.binding_context_pk,s.binding_role,CAST('NOT_EVALUATED' AS varchar(64)) qualification_status,CAST('OUTSIDE_CURRENT_MODEL' AS varchar(64)) runtime_readiness_status FROM model.provider_binding b JOIN model.provider_binding_scope s ON s.provider_binding_scope_pk=b.provider_binding_scope_pk WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=b._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_provider_qualification_assessment] AS SELECT q.*,a.estate_model_pk,a.evaluation_state,a.scope_digest,a.input_set_digest,a.evaluated_at FROM analysis.provider_qualification_assessment q JOIN analysis.assessment a ON a.assessment_pk=q.assessment_pk JOIN source.current_model cm ON cm.estate_model_pk=a.estate_model_pk;
GO
CREATE VIEW sidefx.[v_provider_impact] AS SELECT b.provider_definition_pk,cs.capability_version_pk,CAST('CONSUMES' AS varchar(64)) dependency_role,COUNT_BIG(*) path_count FROM source.current_model cm JOIN model.provider_binding b ON EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=b._owner_definition_pk) JOIN model.provider_slot_operation u ON u.provider_slot_pk=b.provider_slot_pk JOIN model.execution_operation op ON op.execution_operation_pk=u.execution_operation_pk JOIN model.scenario_event e ON e.execution_authority_version_pk=op.execution_authority_version_pk JOIN model.capability_scenario cs ON cs.scenario_version_pk=e.scenario_version_pk JOIN model.estate_capability ec ON ec.estate_model_pk=cm.estate_model_pk AND ec.capability_version_pk=cs.capability_version_pk GROUP BY b.provider_definition_pk,cs.capability_version_pk UNION ALL SELECT i.provider_definition_pk,i.capability_version_pk,CAST('IMPLEMENTS' AS varchar(64)),COUNT_BIG(*) FROM model.provider_capability_implementation i WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=i._owner_definition_pk) GROUP BY i.provider_definition_pk,i.capability_version_pk;
GO
CREATE VIEW sidefx.[v_product_input_satisfaction] AS SELECT c.blueprint_edge_pk,e.blueprint_version_pk,c.product_definition_pk,c.downstream_scenario_version_pk,c.contract_relation,c.compatibility_authority_definition_pk,CASE WHEN a.n=0 THEN 'NOT_EVALUATED' WHEN a.codes>1 THEN 'CONFLICTING_ASSESSMENTS' ELSE a.result END compatibility_status FROM model.blueprint_edge_contract c JOIN model.blueprint_edge e ON e.blueprint_edge_pk=c.blueprint_edge_pk JOIN model.product_definition p ON p.product_definition_pk=c.product_definition_pk JOIN model.scenario_input i ON i.scenario_version_pk=c.downstream_scenario_version_pk OUTER APPLY(SELECT COUNT_BIG(*) n,COUNT(DISTINCT ca.result_code) codes,MIN(ca.result_code) result FROM analysis.compatibility_assessment ca JOIN analysis.assessment a ON a.assessment_pk=ca.assessment_pk JOIN source.current_model cm ON cm.estate_model_pk=a.estate_model_pk WHERE a.evaluation_state='EVALUATED' AND ca.producer_contract_version_pk=p.contract_version_pk AND ca.consumer_contract_version_pk=i.input_contract_version_pk AND ca.authority_definition_pk=c.compatibility_authority_definition_pk) a WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=c._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_circuit_cell] AS SELECT n.blueprint_version_pk,n.blueprint_node_pk,n.node_id,n.altitude,n.node_kind,f.semantic_object_definition_pk first_definition_pk,f.expected_kind first_kind,e.semantic_object_definition_pk energized_definition_pk,e.expected_kind energized_kind,r.semantic_object_definition_pk result_definition_pk,r.expected_kind result_kind,i.input_contract_version_pk first_contract_version_pk,COALESCE(p.contract_version_pk,oc.contract_version_pk) result_contract_version_pk,CAST('NOT_EVALUATED' AS varchar(64)) semantic_assessment_status,CAST('OUTSIDE_CURRENT_MODEL' AS varchar(64)) runtime_status FROM model.blueprint_node n LEFT JOIN model.blueprint_node_face f ON f.blueprint_node_pk=n.blueprint_node_pk AND f.position='FIRST' LEFT JOIN model.blueprint_node_face e ON e.blueprint_node_pk=n.blueprint_node_pk AND e.position='ENERGIZED' LEFT JOIN model.blueprint_node_face r ON r.blueprint_node_pk=n.blueprint_node_pk AND r.position='RESULT' LEFT JOIN model.scenario_input i ON i.semantic_object_definition_pk=f.semantic_object_definition_pk LEFT JOIN model.product_definition p ON p.semantic_object_definition_pk=r.semantic_object_definition_pk LEFT JOIN model.scenario_outcome o ON o.semantic_object_definition_pk=r.semantic_object_definition_pk LEFT JOIN model.scenario_outcome_contract oc ON oc.scenario_version_pk=o.scenario_version_pk WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=n._owner_definition_pk);
GO
CREATE VIEW sidefx.[v_circuit_route] AS SELECT * FROM sidefx.v_blueprint_edge;
GO
CREATE VIEW sidefx.[v_circuit_integrity_findings] AS SELECT f.*,a.estate_model_pk,a.integrity_rule_pk,r.layer,c.blueprint_version_pk,c.blueprint_node_pk FROM analysis.integrity_finding f JOIN analysis.assessment a ON a.assessment_pk=f.assessment_pk JOIN analysis.integrity_rule r ON r.integrity_rule_pk=a.integrity_rule_pk JOIN source.current_model cm ON cm.estate_model_pk=a.estate_model_pk LEFT JOIN analysis.circuit_assessment c ON c.assessment_pk=a.assessment_pk WHERE a.assessment_kind IN('CIRCUIT','INTEGRITY');
GO
CREATE VIEW sidefx.[v_estate_inventory] AS SELECT a.source_appearance_pk,a.source_path,a.source_class,a.content_object_pk,c.family_code,c.classification_state,c.mapping_rule_pk FROM source.current_model cm JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.source_appearance a ON a.estate_snapshot_pk=m.estate_snapshot_pk LEFT JOIN source.source_classification c ON c.source_appearance_pk=a.source_appearance_pk AND EXISTS(SELECT 1 FROM source.estate_model_rule mr WHERE mr.estate_model_pk=m.estate_model_pk AND mr.mapping_rule_pk=c.mapping_rule_pk);
GO
CREATE VIEW sidefx.[v_definition_lineage] AS SELECT l.source_lineage_pk,l.semantic_object_definition_pk,l.member_kind,l.canonical_pointer,l.mapping_rule_pk,l.contribution_role,o.source_observation_pk,o.locator,a.source_path,a.source_class,a.capsule_digest,a.referenced_authority_digest FROM source.current_model cm JOIN source.estate_model m ON m.estate_model_pk=cm.estate_model_pk JOIN source.source_lineage l ON EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=l.semantic_object_definition_pk) JOIN source.source_observation o ON o.source_observation_pk=l.source_observation_pk JOIN source.source_appearance a ON a.source_appearance_pk=o.source_appearance_pk AND a.estate_snapshot_pk=m.estate_snapshot_pk WHERE EXISTS(SELECT 1 FROM source.estate_model_rule r WHERE r.estate_model_pk=m.estate_model_pk AND r.mapping_rule_pk=l.mapping_rule_pk);
GO
CREATE VIEW sidefx.[v_assessment_coverage] AS SELECT c.*,a.estate_model_pk,a.evaluation_state FROM analysis.coverage_assessment c JOIN analysis.assessment a ON a.assessment_pk=c.assessment_pk JOIN source.current_model cm ON cm.estate_model_pk=a.estate_model_pk;
GO
CREATE VIEW sidefx.[v_version_label] AS SELECT l.semantic_object_pk,l.version_label,l.semantic_object_definition_pk,l.definition_digest FROM model.definition_version_label l WHERE EXISTS(SELECT 1 FROM model.estate_definition ed JOIN source.current_model cm ON cm.estate_model_pk=ed.estate_model_pk WHERE ed.semantic_object_definition_pk=l.semantic_object_definition_pk);
