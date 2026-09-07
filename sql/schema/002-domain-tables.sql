-- Generated from src/derive/model.mjs. Derived inspection structures only.
IF OBJECT_ID('sidefx_data.capability') IS NULL
BEGIN
CREATE TABLE sidefx_data.[capability](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [name] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [version] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [root_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [experience_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [lifecycle] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_capability_capability ON sidefx_data.[capability](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.feature') IS NULL
BEGIN
CREATE TABLE sidefx_data.[feature](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [name] nvarchar(max) NULL,
  [language] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [description] nvarchar(max) NULL,
  [scenario_count] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_feature_capability ON sidefx_data.[feature](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.scenario') IS NULL
BEGIN
CREATE TABLE sidefx_data.[scenario](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [name] nvarchar(max) NULL,
  [terminal] bit NULL,
  [input_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [input_contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [event_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [execution_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [outcome_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [outcome_contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [variant_count] int NULL,
  [observable_condition_count] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_scenario_capability ON sidefx_data.[scenario](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.input') IS NULL
BEGIN
CREATE TABLE sidefx_data.[input](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [input_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_input_capability ON sidefx_data.[input](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.event') IS NULL
BEGIN
CREATE TABLE sidefx_data.[event](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [event_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [execution_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_event_capability ON sidefx_data.[event](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.outcome') IS NULL
BEGIN
CREATE TABLE sidefx_data.[outcome](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [outcome_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [terminal] bit NULL,
  [variant_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [observable_condition_count] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_outcome_capability ON sidefx_data.[outcome](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.product') IS NULL
BEGIN
CREATE TABLE sidefx_data.[product](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [product_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [product_role] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_product_capability ON sidefx_data.[product](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.contract') IS NULL
BEGIN
CREATE TABLE sidefx_data.[contract](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [schema_ref] nvarchar(max) NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_contract_capability ON sidefx_data.[contract](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.schema') IS NULL
BEGIN
CREATE TABLE sidefx_data.[schema](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [schema_id] nvarchar(max) NULL,
  [dialect] nvarchar(max) NULL,
  [title] nvarchar(max) NULL,
  [declared_type] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_schema_capability ON sidefx_data.[schema](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.blueprint_node') IS NULL
BEGIN
CREATE TABLE sidefx_data.[blueprint_node](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [node_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [altitude] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [ordinal] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_blueprint_node_capability ON sidefx_data.[blueprint_node](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.blueprint_edge') IS NULL
BEGIN
CREATE TABLE sidefx_data.[blueprint_edge](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [edge_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [topology] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [variant_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_blueprint_edge_capability ON sidefx_data.[blueprint_edge](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.observed_blueprint_route') IS NULL
BEGIN
CREATE TABLE sidefx_data.[observed_blueprint_route](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [edge_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [topology] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [variant_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_observed_blueprint_route_capability ON sidefx_data.[observed_blueprint_route](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.observed_semantic_graph_transition') IS NULL
BEGIN
CREATE TABLE sidefx_data.[observed_semantic_graph_transition](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [transition_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_outcome_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_input_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [topology] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [variant_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_observed_semantic_graph_transition_capability ON sidefx_data.[observed_semantic_graph_transition](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.observed_execution_invoke_scenario') IS NULL
BEGIN
CREATE TABLE sidefx_data.[observed_execution_invoke_scenario](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [operation_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [execution_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_observed_execution_invoke_scenario_capability ON sidefx_data.[observed_execution_invoke_scenario](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.observed_runtime_route') IS NULL
BEGIN
CREATE TABLE sidefx_data.[observed_runtime_route](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [edge_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [altitude] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_observed_runtime_route_capability ON sidefx_data.[observed_runtime_route](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.execution_authority') IS NULL
BEGIN
CREATE TABLE sidefx_data.[execution_authority](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [execution_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [operation_count] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_execution_authority_capability ON sidefx_data.[execution_authority](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.operation') IS NULL
BEGIN
CREATE TABLE sidefx_data.[operation](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [operation_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [execution_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [port_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [target_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [mechanic_binding_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [structural_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_operation_capability ON sidefx_data.[operation](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.transformation') IS NULL
BEGIN
CREATE TABLE sidefx_data.[transformation](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [transformation_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [expression_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_transformation_capability ON sidefx_data.[transformation](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.mechanic') IS NULL
BEGIN
CREATE TABLE sidefx_data.[mechanic](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [mechanic_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [binding_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [mechanic_type] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_name] nvarchar(max) NULL,
  [implementation_ref] nvarchar(max) NULL,
  [configuration_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_mechanic_capability ON sidefx_data.[mechanic](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.port') IS NULL
BEGIN
CREATE TABLE sidefx_data.[port](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [port_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [transformation_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [binding_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_port_capability ON sidefx_data.[port](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.provider_slot') IS NULL
BEGIN
CREATE TABLE sidefx_data.[provider_slot](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [slot_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [cell_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [port_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [mechanic_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [declared_provider_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [profile_constraints] nvarchar(max) NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_provider_slot_capability ON sidefx_data.[provider_slot](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.provider') IS NULL
BEGIN
CREATE TABLE sidefx_data.[provider](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [provider_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [lifecycle] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [responsibility] nvarchar(max) NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_provider_capability ON sidefx_data.[provider](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.provider_binding') IS NULL
BEGIN
CREATE TABLE sidefx_data.[provider_binding](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [binding_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [slot_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [cell_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [port_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [mechanic_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [provider_digest] nvarchar(max) NULL,
  [implementation_ref] nvarchar(max) NULL,
  [binding_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_provider_binding_capability ON sidefx_data.[provider_binding](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.interface') IS NULL
BEGIN
CREATE TABLE sidefx_data.[interface](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [interface_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [root_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [target_capability_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_interface_capability ON sidefx_data.[interface](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.fixture') IS NULL
BEGIN
CREATE TABLE sidefx_data.[fixture](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [fixture_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [terminal_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [expected_disposition] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [assertion_count] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_fixture_capability ON sidefx_data.[fixture](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.fixture_scenario') IS NULL
BEGIN
CREATE TABLE sidefx_data.[fixture_scenario](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [fixture_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [ordinal] int NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_fixture_scenario_capability ON sidefx_data.[fixture_scenario](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.fixture_assertion') IS NULL
BEGIN
CREATE TABLE sidefx_data.[fixture_assertion](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [fixture_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [condition_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [assertion_path] nvarchar(max) NULL,
  [operator] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [value_json] nvarchar(max) NULL,
  [target_scenario_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_fixture_assertion_capability ON sidefx_data.[fixture_assertion](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.proof_obligation') IS NULL
BEGIN
CREATE TABLE sidefx_data.[proof_obligation](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [obligation_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [status] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [subject_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_proof_obligation_capability ON sidefx_data.[proof_obligation](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.evidence') IS NULL
BEGIN
CREATE TABLE sidefx_data.[evidence](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [evidence_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [disposition] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [declared_digest] nvarchar(max) NULL,
  [subject_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_evidence_capability ON sidefx_data.[evidence](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.projection_authority') IS NULL
BEGIN
CREATE TABLE sidefx_data.[projection_authority](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [projection_authority_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [input_contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [output_contract_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_projection_authority_capability ON sidefx_data.[projection_authority](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.dependency') IS NULL
BEGIN
CREATE TABLE sidefx_data.[dependency](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [target_capability_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [target_version] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [target_digest] nvarchar(max) NULL,
  [dependency_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_dependency_capability ON sidefx_data.[dependency](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.semantic_term') IS NULL
BEGIN
CREATE TABLE sidefx_data.[semantic_term](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [term_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [label] nvarchar(max) NULL,
  [normalized_label] nvarchar(max) NULL,
  [definition] nvarchar(max) NULL,
  [vocabulary_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_semantic_term_capability ON sidefx_data.[semantic_term](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.term_relationship') IS NULL
BEGIN
CREATE TABLE sidefx_data.[term_relationship](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [relationship_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_term_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_term_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_term_relationship_capability ON sidefx_data.[term_relationship](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.classification') IS NULL
BEGIN
CREATE TABLE sidefx_data.[classification](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [subject_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [classification] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [classified_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_classification_capability ON sidefx_data.[classification](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.fact') IS NULL
BEGIN
CREATE TABLE sidefx_data.[fact](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [fact_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [subject_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [predicate] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [object_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [value_json] nvarchar(max) NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_fact_capability ON sidefx_data.[fact](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.fact_relationship') IS NULL
BEGIN
CREATE TABLE sidefx_data.[fact_relationship](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [relationship_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [from_fact_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [to_fact_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_fact_relationship_capability ON sidefx_data.[fact_relationship](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.precedent') IS NULL
BEGIN
CREATE TABLE sidefx_data.[precedent](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [precedent_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [subject_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_precedent_capability ON sidefx_data.[precedent](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.pattern_candidate') IS NULL
BEGIN
CREATE TABLE sidefx_data.[pattern_candidate](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [pattern_id] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [status] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_pattern_candidate_capability ON sidefx_data.[pattern_candidate](projection_id,capability_id,is_primary);
END;

IF OBJECT_ID('sidefx_data.extraction_issue') IS NULL
BEGIN
CREATE TABLE sidefx_data.[extraction_issue](
  projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [row_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [artifact_id] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [capability_id] nvarchar(256) COLLATE Latin1_General_100_BIN2 NULL,
  [is_primary] bit NOT NULL,
  [origin_layer] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [source_pointer] nvarchar(max) NOT NULL,
  [pointer_kind] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [derivation_rule] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [object_digest] varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [payload_json] nvarchar(max) NOT NULL,
  [code] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  [detail] nvarchar(max) NULL,
  [severity] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NULL,
  PRIMARY KEY(projection_id,row_id),
  FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
  FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
);
CREATE INDEX ix_extraction_issue_capability ON sidefx_data.[extraction_issue](projection_id,capability_id,is_primary);
END;
