-- One row per selected capability identity.
SELECT capability_id, name, capability_version_pk
FROM sidefx.v_capability ORDER BY capability_id;

-- One row per selected scenario, with its owned faces.
SELECT c.capability_id, s.scenario_id, i.input_id, e.event_id, o.outcome_id,
       s.contract_reference_state, s.authority_reference_state
FROM sidefx.v_capability c
JOIN sidefx.v_scenario s ON s.capability_pk=c.capability_pk
LEFT JOIN model.scenario_input i ON i.scenario_version_pk=s.scenario_version_pk
LEFT JOIN model.scenario_event e ON e.scenario_version_pk=s.scenario_version_pk
LEFT JOIN model.scenario_outcome o ON o.scenario_version_pk=s.scenario_version_pk
ORDER BY c.capability_id,s.scenario_id;

SELECT source_profile,total_count,normalized_count,unresolved_count,unsupported_count,outside_count
FROM sidefx.v_assessment_coverage ORDER BY source_profile;
