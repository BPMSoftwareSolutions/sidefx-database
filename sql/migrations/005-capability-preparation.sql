-- Derived execution preparation. Source/model authority remains immutable and
-- unchanged. Runtime reads do not call the inspection resolver functions.
CREATE SCHEMA runtime AUTHORIZATION dbo;
GO
CREATE TABLE runtime.capability_preparation (
    preparation_pk bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    estate_model_pk bigint NOT NULL,
    capability_pk bigint NOT NULL,
    capability_version_pk bigint NOT NULL,
    scenario_version_pk bigint NOT NULL,
    target nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
    recipe_digest binary(32) NOT NULL,
    view_definition_digest binary(32) NOT NULL,
    payload_digest binary(32) NOT NULL,
    payload_bytes varbinary(max) NOT NULL,
    prepared_at datetime2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_preparation_model FOREIGN KEY(estate_model_pk) REFERENCES source.estate_model(estate_model_pk),
    CONSTRAINT FK_preparation_capability FOREIGN KEY(capability_pk) REFERENCES model.capability(capability_pk),
    CONSTRAINT FK_preparation_scenario FOREIGN KEY(capability_version_pk,scenario_version_pk) REFERENCES model.capability_scenario(capability_version_pk,scenario_version_pk),
    CONSTRAINT CK_preparation_payload CHECK(DATALENGTH(payload_bytes)>0 AND HASHBYTES('SHA2_256',payload_bytes)=payload_digest),
    CONSTRAINT UQ_preparation_context UNIQUE(estate_model_pk,capability_version_pk,scenario_version_pk,target,recipe_digest,view_definition_digest)
);
CREATE INDEX IX_preparation_capability ON runtime.capability_preparation(capability_pk,target);
GO
CREATE TRIGGER runtime.capability_preparation_immutable ON runtime.capability_preparation
INSTEAD OF UPDATE, DELETE AS
BEGIN
    THROW 51000,'PREPARATION_IMMUTABLE',1;
END;
GO
CREATE USER sidefx_preparer WITHOUT LOGIN;
GRANT SELECT ON SCHEMA::runtime TO sidefx_reader;
DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::runtime TO sidefx_reader;
GRANT SELECT ON SCHEMA::source TO sidefx_preparer;
GRANT SELECT ON SCHEMA::model TO sidefx_preparer;
GRANT SELECT ON SCHEMA::runtime TO sidefx_preparer;
GRANT INSERT ON OBJECT::runtime.capability_preparation TO sidefx_preparer;
DENY UPDATE, DELETE, ALTER ON SCHEMA::runtime TO sidefx_preparer;
GO
