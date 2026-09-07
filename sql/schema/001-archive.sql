IF SCHEMA_ID('sidefx_data') IS NULL EXEC('CREATE SCHEMA sidefx_data');
IF SCHEMA_ID('sidefx') IS NULL EXEC('CREATE SCHEMA sidefx');
IF OBJECT_ID('sidefx_data.workspace_identity') IS NULL
BEGIN
  IF EXISTS(SELECT 1 FROM sys.objects WHERE schema_id IN(SCHEMA_ID('sidefx'),SCHEMA_ID('sidefx_data')) AND type IN('U','V','P'))
    THROW 51000,'Inspection schemas already contain unowned objects.',1;
  CREATE TABLE sidefx_data.workspace_identity(product varchar(64) NOT NULL PRIMARY KEY, schema_version int NOT NULL);
  INSERT sidefx_data.workspace_identity VALUES('sidefx-database-observation',1);
END;
IF NOT EXISTS(SELECT 1 FROM sidefx_data.workspace_identity WHERE product='sidefx-database-observation' AND schema_version IN(1,3))
  THROW 51000,'Inspection schema identity mismatch.',1;
IF OBJECT_ID('sidefx_data.canonical_object') IS NULL
CREATE TABLE sidefx_data.canonical_object(
  content_digest varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
  byte_length bigint NOT NULL,
  canonical_bytes varbinary(max) NOT NULL,
  content_text nvarchar(max) NULL,
  CHECK(byte_length=DATALENGTH(canonical_bytes))
);
IF OBJECT_ID('sidefx_data.estate_snapshot') IS NULL
CREATE TABLE sidefx_data.estate_snapshot(
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
  estate_manifest_digest varchar(71) NOT NULL,
  source_head varchar(64) NOT NULL,
  source_status nvarchar(max) NOT NULL,
  capability_count int NOT NULL,
  artifact_count int NOT NULL,
  manifest_json nvarchar(max) NOT NULL CHECK(ISJSON(manifest_json)=1),
  captured_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);
IF OBJECT_ID('sidefx_data.artifact') IS NULL
CREATE TABLE sidefx_data.artifact(
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  artifact_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  content_digest varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  source_path nvarchar(2048) COLLATE Latin1_General_100_BIN2 NOT NULL,
  source_class varchar(40) NOT NULL,
  capability_id nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  capsule_digest varchar(71) NULL,
  authority_digest varchar(71) NULL,
  entry_id nvarchar(2048) NULL,
  container_path nvarchar(2048) NULL,
  byte_length bigint NOT NULL,
  PRIMARY KEY(snapshot_id,artifact_id),
  FOREIGN KEY(snapshot_id) REFERENCES sidefx_data.estate_snapshot(snapshot_id),
  FOREIGN KEY(content_digest) REFERENCES sidefx_data.canonical_object(content_digest)
);
IF OBJECT_ID('sidefx_data.projection_run') IS NULL
CREATE TABLE sidefx_data.projection_run(
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  adapter_digest varchar(71) NOT NULL,
  rule_version varchar(128) NOT NULL,
  table_digests_json nvarchar(max) NOT NULL CHECK(ISJSON(table_digests_json)=1),
  catalog_digest varchar(71) NOT NULL,
  loaded_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
  UNIQUE(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id) REFERENCES sidefx_data.estate_snapshot(snapshot_id)
);
IF OBJECT_ID('sidefx_data.artifact_catalog') IS NULL
CREATE TABLE sidefx_data.artifact_catalog(
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  artifact_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  format varchar(16) NOT NULL,
  status varchar(32) NOT NULL,
  root_type nvarchar(2048) NULL,
  PRIMARY KEY(projection_id,artifact_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
IF OBJECT_ID('sidefx_data.current_pointer') IS NULL
CREATE TABLE sidefx_data.current_pointer(
  pointer_id int NOT NULL PRIMARY KEY CHECK(pointer_id=1),
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id)
);
