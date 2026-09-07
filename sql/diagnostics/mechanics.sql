-- Committed entity and relationship counts.
SELECT 'model.mechanic' AS table_name, COUNT_BIG(*) AS row_count FROM model.mechanic
UNION ALL SELECT 'model.mechanic_version', COUNT_BIG(*) FROM model.mechanic_version
UNION ALL SELECT 'model.provider', COUNT_BIG(*) FROM model.provider
UNION ALL SELECT 'model.provider_mechanic_implementation', COUNT_BIG(*) FROM model.provider_mechanic_implementation
UNION ALL SELECT 'model.provider_capability_implementation', COUNT_BIG(*) FROM model.provider_capability_implementation;

-- This must return zero missing endpoints and zero duplicate pairs.
SELECT
  (SELECT COUNT_BIG(*)
   FROM model.provider_mechanic_implementation i
   LEFT JOIN model.provider_definition pd ON pd.provider_definition_pk = i.provider_definition_pk
   LEFT JOIN model.provider p ON p.provider_pk = pd.provider_pk
   LEFT JOIN model.mechanic_version mv ON mv.mechanic_version_pk = i.mechanic_version_pk
   LEFT JOIN model.mechanic m ON m.mechanic_pk = mv.mechanic_pk
   WHERE p.provider_pk IS NULL OR m.mechanic_pk IS NULL) AS missing_endpoints,
  (SELECT COUNT_BIG(*) FROM (
    SELECT provider_definition_pk, mechanic_version_pk
    FROM model.provider_mechanic_implementation
    GROUP BY provider_definition_pk, mechanic_version_pk HAVING COUNT_BIG(*) > 1
  ) d) AS duplicate_implementation_pairs;

-- Explicit vocabulary declarations and richer atomic definitions remain distinct.
SELECT mv.definition_profile, COUNT_BIG(*) AS mechanic_definitions,
       COUNT_BIG(i.mechanic_version_pk) AS mechanics_with_declared_provider
FROM model.mechanic_version mv
LEFT JOIN (SELECT DISTINCT mechanic_version_pk FROM model.provider_mechanic_implementation) i
  ON i.mechanic_version_pk = mv.mechanic_version_pk
GROUP BY mv.definition_profile;

-- One row per declared provider/mechanic pair, through exact definitions.
SELECT p.provider_id, m.mechanic_id, mv.definition_profile
FROM model.provider_mechanic_implementation i
JOIN model.provider_definition pd ON pd.provider_definition_pk = i.provider_definition_pk
JOIN model.provider p ON p.provider_pk = pd.provider_pk
JOIN model.mechanic_version mv ON mv.mechanic_version_pk = i.mechanic_version_pk
JOIN model.mechanic m ON m.mechanic_pk = mv.mechanic_pk
JOIN source.current_model cm ON cm.singleton_id = 1
JOIN model.estate_definition ep ON ep.estate_model_pk = cm.estate_model_pk
  AND ep.semantic_object_definition_pk = pd.semantic_object_definition_pk
JOIN model.estate_definition em ON em.estate_model_pk = cm.estate_model_pk
  AND em.semantic_object_definition_pk = mv.semantic_object_definition_pk
ORDER BY p.provider_id, m.mechanic_id;

SELECT * FROM sidefx.v_load_completeness;
