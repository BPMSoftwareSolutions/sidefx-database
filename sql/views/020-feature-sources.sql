CREATE OR ALTER VIEW sidefx.v_feature_source_integrity AS
SELECT capability_id,COUNT(*) AS source_copy_count,COUNT(DISTINCT content_digest) AS distinct_byte_versions,
 CASE WHEN COUNT(DISTINCT content_digest)>1 THEN 'DIFFERENT_FEATURE_BYTES_RETAINED' ELSE 'ONE_FEATURE_BYTE_VERSION' END AS observation
FROM sidefx.artifact WHERE source_class='MANAGED_CAPSULE' AND entry_id LIKE 'features/{id}.feature%'
GROUP BY capability_id;
