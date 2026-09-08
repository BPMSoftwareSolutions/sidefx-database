-- Additive media persistence. Applied transactionally by src/media/store.mjs.
CREATE TABLE media.schema_version (version varchar(80) NOT NULL PRIMARY KEY, digest binary(32) NOT NULL, installed_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE media.blob (
 digest binary(32) NOT NULL PRIMARY KEY,
 bytes varbinary(max) NOT NULL,
 byte_length bigint NOT NULL,
 media_type varchar(100) NOT NULL,
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_media_blob_length CHECK (byte_length > 0 AND byte_length = DATALENGTH(bytes)),
 CONSTRAINT CK_media_blob_digest CHECK (digest = HASHBYTES('SHA2_256',bytes))
);
CREATE TABLE media.subject (
 definition_pk bigint NOT NULL PRIMARY KEY,
 object_pk bigint NOT NULL,
 object_kind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 definition_digest binary(32) NOT NULL,
 CONSTRAINT FK_media_subject_definition FOREIGN KEY(definition_pk,object_pk,object_kind,definition_digest)
 REFERENCES model.semantic_object_definition(semantic_object_definition_pk,semantic_object_pk,object_kind,definition_digest)
);
CREATE TABLE media.visual_requirement (
 requirement_id bigint IDENTITY PRIMARY KEY,
 definition_pk bigint NOT NULL REFERENCES media.subject(definition_pk),
 purpose varchar(40) NOT NULL,
 locale varchar(20) NOT NULL DEFAULT 'en',
 variant varchar(40) NOT NULL DEFAULT 'default',
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_media_requirement UNIQUE(definition_pk,purpose,locale,variant)
);
CREATE TABLE media.generation_request (
 request_id varchar(64) NOT NULL PRIMARY KEY,
 requirement_id bigint NOT NULL REFERENCES media.visual_requirement(requirement_id),
 provider varchar(80) NOT NULL,
 model varchar(120) NOT NULL,
 request_blob_digest binary(32) NOT NULL REFERENCES media.blob(digest),
 state varchar(40) NOT NULL DEFAULT 'QUEUED',
 attempts int NOT NULL DEFAULT 0,
 provider_request_id varchar(200) NULL,
 failure_code varchar(100) NULL,
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 updated_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_media_job_state CHECK(state IN('QUEUED','GENERATING','REVIEW_REQUIRED','COMPLETE','FAILED','UNCERTAIN'))
);
CREATE TABLE media.asset (
 asset_id varchar(64) NOT NULL PRIMARY KEY,
 logical_key nvarchar(900) NOT NULL,
 kind varchar(40) NOT NULL,
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE media.asset_revision (
 revision_id varchar(64) NOT NULL PRIMARY KEY,
 asset_id varchar(64) NOT NULL REFERENCES media.asset(asset_id),
 blob_digest binary(32) NOT NULL REFERENCES media.blob(digest),
 origin varchar(20) NOT NULL,
 generation_request_id varchar(64) NULL REFERENCES media.generation_request(request_id),
 width int NULL,
 height int NULL,
 provenance_digest binary(32) NOT NULL REFERENCES media.blob(digest),
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_media_revision_dimensions CHECK ((width IS NULL AND height IS NULL) OR (width > 0 AND height > 0)),
 CONSTRAINT CK_media_revision_origin CHECK(origin IN('GENERATED','COMPOSITED','DERIVED','IMPORTED'))
);
CREATE TABLE media.asset_source (
 revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 parent_revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 role varchar(40) NOT NULL,
 PRIMARY KEY(revision_id,parent_revision_id,role),
 CONSTRAINT CK_media_parent_not_self CHECK(revision_id <> parent_revision_id)
);
CREATE TABLE media.asset_semantic_source (
 revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 definition_pk bigint NOT NULL REFERENCES media.subject(definition_pk),
 role varchar(40) NOT NULL,
 PRIMARY KEY(revision_id,definition_pk,role)
);
CREATE TABLE media.entity_visual_binding (
 binding_id bigint IDENTITY PRIMARY KEY,
 requirement_id bigint NOT NULL REFERENCES media.visual_requirement(requirement_id),
 revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 alt_text nvarchar(2000) NOT NULL,
 presentation_json nvarchar(max) NOT NULL DEFAULT '{}',
 CONSTRAINT UQ_media_binding UNIQUE(requirement_id,revision_id),
 CONSTRAINT UQ_media_binding_requirement UNIQUE(binding_id,requirement_id),
 CONSTRAINT CK_media_presentation CHECK(ISJSON(presentation_json)=1)
);
CREATE TABLE media.asset_review (
 review_id bigint IDENTITY PRIMARY KEY,
 revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 binding_id bigint NULL REFERENCES media.entity_visual_binding(binding_id),
 decision varchar(20) NOT NULL,
 reviewer nvarchar(200) NOT NULL,
 reason nvarchar(2000) NOT NULL,
 created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_media_review CHECK(decision IN('APPROVED','REJECTED'))
);
CREATE TABLE media.visual_selection (
 requirement_id bigint NOT NULL PRIMARY KEY REFERENCES media.visual_requirement(requirement_id),
 binding_id bigint NOT NULL,
 review_id bigint NOT NULL REFERENCES media.asset_review(review_id),
 selected_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 version rowversion,
 CONSTRAINT FK_media_selection_binding FOREIGN KEY(binding_id,requirement_id) REFERENCES media.entity_visual_binding(binding_id,requirement_id)
);
CREATE TABLE media.selection_history (
 selection_id bigint IDENTITY PRIMARY KEY,
 requirement_id bigint NOT NULL REFERENCES media.visual_requirement(requirement_id),
 binding_id bigint NOT NULL REFERENCES media.entity_visual_binding(binding_id),
 review_id bigint NOT NULL REFERENCES media.asset_review(review_id),
 selected_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE media.bundle_member (
 bundle_revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 relative_path nvarchar(800) NOT NULL,
 member_revision_id varchar(64) NOT NULL REFERENCES media.asset_revision(revision_id),
 PRIMARY KEY(bundle_revision_id,relative_path)
);
GO
CREATE TRIGGER media.protect_blob ON media.blob INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_BLOB_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_revision ON media.asset_revision INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_REVISION_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_review ON media.asset_review INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_REVIEW_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_binding ON media.entity_visual_binding INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_BINDING_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_history ON media.selection_history INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_HISTORY_IMMUTABLE',1;
GO
CREATE TRIGGER media.validate_selection ON media.visual_selection AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN media.entity_visual_binding b ON b.binding_id=i.binding_id
 LEFT JOIN media.asset_review r ON r.review_id=i.review_id AND r.binding_id=b.binding_id AND r.revision_id=b.revision_id AND r.decision='APPROVED'
 WHERE r.review_id IS NULL) THROW 51102,'MEDIA_APPROVED_BINDING_REQUIRED',1;
 INSERT media.selection_history(requirement_id,binding_id,review_id) SELECT requirement_id,binding_id,review_id FROM inserted;
END;
GO
CREATE VIEW media.v_requirement AS
 SELECT r.requirement_id,r.definition_pk,s.object_pk,s.object_kind,s.definition_digest,o.declared_id,n.namespace_kind,n.namespace_id,r.purpose,
 CASE WHEN x.binding_id IS NOT NULL THEN 'READY' ELSE COALESCE(j.state,'REQUIRED') END state,
 b.revision_id,b.alt_text,b.presentation_json,a.blob_digest,a.width,a.height,bl.media_type,
 COALESCE(j.model,JSON_VALUE(CONVERT(varchar(max),pb.bytes),'$.model')) generator_model,
 CONVERT(bit,CASE WHEN ed.semantic_object_definition_pk IS NULL THEN 0 ELSE 1 END) is_current
 FROM media.visual_requirement r JOIN media.subject s ON s.definition_pk=r.definition_pk
 JOIN model.semantic_object o ON o.semantic_object_pk=s.object_pk
 JOIN model.identity_namespace n ON n.namespace_pk=o.namespace_pk
 LEFT JOIN media.visual_selection x ON x.requirement_id=r.requirement_id
 LEFT JOIN media.entity_visual_binding b ON b.binding_id=x.binding_id
 LEFT JOIN media.asset_revision a ON a.revision_id=b.revision_id
 LEFT JOIN media.blob bl ON bl.digest=a.blob_digest
 LEFT JOIN media.blob pb ON pb.digest=a.provenance_digest
 LEFT JOIN model.estate_definition ed ON ed.semantic_object_definition_pk=s.definition_pk AND ed.estate_model_pk=(SELECT estate_model_pk FROM source.current_model WHERE singleton_id=1)
 OUTER APPLY(SELECT TOP(1) state,model FROM media.generation_request j WHERE j.requirement_id=r.requirement_id ORDER BY j.created_at DESC,j.request_id) j;
GO
-- Existing estate reader gains only metadata, never media mutation or raw bytes.
GRANT SELECT ON OBJECT::media.v_requirement TO sidefx_reader;
