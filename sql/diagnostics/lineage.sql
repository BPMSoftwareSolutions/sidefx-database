SELECT l.semantic_object_definition_pk,l.member_kind,l.canonical_pointer,
       l.source_path,l.locator,l.mapping_rule_pk
FROM sidefx.v_definition_lineage l
ORDER BY l.semantic_object_definition_pk,l.member_kind,l.source_path;
