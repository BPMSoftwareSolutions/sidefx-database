SELECT m.estate_model_pk,m.publication_state,
       LOWER(CONVERT(varchar(64),s.snapshot_digest,2)) snapshot_digest,
       LOWER(CONVERT(varchar(64),m.mapping_manifest_digest,2)) mapping_manifest_digest,
       COUNT(ed.semantic_object_definition_pk) definition_count
FROM source.estate_model m
JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk
LEFT JOIN model.estate_definition ed ON ed.estate_model_pk=m.estate_model_pk
GROUP BY m.estate_model_pk,m.publication_state,s.snapshot_digest,m.mapping_manifest_digest;
