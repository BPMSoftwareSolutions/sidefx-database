-- Cover the joins used by inspection views without reading large JSON payload pages.
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_data.artifact') AND name='ix_artifact_feature_alias')
CREATE INDEX ix_artifact_feature_alias ON sidefx_data.artifact(snapshot_id,capability_id,content_digest,artifact_id) INCLUDE(entry_id,source_class);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.input') AND name='ix_input_contract_usage')
CREATE INDEX ix_input_contract_usage ON sidefx_observation.input(projection_id,is_primary) INCLUDE(capability_id,origin_layer,artifact_id,contract_id,scenario_id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.product') AND name='ix_product_contract_usage')
CREATE INDEX ix_product_contract_usage ON sidefx_observation.product(projection_id,is_primary) INCLUDE(capability_id,origin_layer,artifact_id,contract_id,scenario_id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.provider_binding') AND name='ix_provider_binding_resolution')
CREATE INDEX ix_provider_binding_resolution ON sidefx_observation.provider_binding(projection_id,capability_id,is_primary) INCLUDE(origin_layer,slot_id,port_id,provider_id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.port') AND name='ix_port_resolution')
CREATE INDEX ix_port_resolution ON sidefx_observation.port(projection_id,capability_id,is_primary) INCLUDE(origin_layer,port_id,provider_id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.fixture_assertion') AND name='ix_fixture_assertion_coverage')
CREATE INDEX ix_fixture_assertion_coverage ON sidefx_observation.fixture_assertion(projection_id,capability_id,is_primary) INCLUDE(origin_layer,target_scenario_id,operator,assertion_path,value_json);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('sidefx_observation.outcome') AND name='ix_outcome_variants')
CREATE INDEX ix_outcome_variants ON sidefx_observation.outcome(projection_id,capability_id,is_primary) INCLUDE(origin_layer,scenario_id,variant_id);
