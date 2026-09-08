-- Enforce semantic provenance at the database boundary, including direct SQL.
CREATE TRIGGER media.validate_binding ON media.entity_visual_binding AFTER INSERT AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN media.visual_requirement r ON r.requirement_id=i.requirement_id
 WHERE NOT EXISTS(SELECT 1 FROM media.asset_semantic_source s WHERE s.revision_id=i.revision_id AND s.definition_pk=r.definition_pk AND s.role='SUBJECT'))
 THROW 51104,'MEDIA_SUBJECT_SOURCE_REQUIRED',1;
END;
GO
CREATE TRIGGER media.validate_review ON media.asset_review AFTER INSERT AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN media.entity_visual_binding b ON b.binding_id=i.binding_id WHERE b.revision_id<>i.revision_id)
 THROW 51106,'MEDIA_REVIEW_REVISION_MISMATCH',1;
END;
GO
CREATE TRIGGER media.protect_subject ON media.subject INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_SUBJECT_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_requirement ON media.visual_requirement INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_REQUIREMENT_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_asset_source ON media.asset_source INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_ASSET_SOURCE_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_semantic_source ON media.asset_semantic_source INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_SEMANTIC_SOURCE_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_bundle_member ON media.bundle_member INSTEAD OF UPDATE, DELETE AS THROW 51101,'MEDIA_BUNDLE_MEMBER_IMMUTABLE',1;
GO
CREATE TRIGGER media.protect_generation_input ON media.generation_request AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF UPDATE(request_id) OR UPDATE(requirement_id) OR UPDATE(provider) OR UPDATE(model) OR UPDATE(request_blob_digest)
 THROW 51101,'MEDIA_GENERATION_INPUT_IMMUTABLE',1;
END;
