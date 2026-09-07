SELECT finding_code,severity,COUNT_BIG(*) finding_count
FROM sidefx.v_circuit_integrity_findings GROUP BY finding_code,severity
ORDER BY severity,finding_code;
SELECT * FROM sidefx.v_assessment_coverage;
SELECT COUNT_BIG(*) selected_scenarios,
       (SELECT COUNT_BIG(*) FROM sidefx.v_complete_scenario) complete_scenarios
FROM sidefx.v_scenario;
