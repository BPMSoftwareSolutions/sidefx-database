import { query } from '../query/run.mjs';
import { receipt } from '../core.mjs';

const views=['v_capability_health','v_scenario_closure','v_contract_usage','v_transition_integrity','v_mechanic_reuse','v_provider_coverage','v_port_binding_integrity','v_slot_resolution','v_fixture_coverage','v_proof_coverage','v_blueprint_execution_parity','v_semantic_vocabulary_drift','v_duplicate_capability_candidates','v_orphan_products','v_unresolved_dependencies','v_projection_anomalies','v_feature_source_integrity'];
export async function liveChecks() {
  const counts={};let snapshotId,projectionDigest;
  for(const view of views) {
    const r=await query(`SELECT COUNT_BIG(*) AS row_count FROM sidefx.${view}; SELECT TOP(3) * FROM sidefx.${view};`,{writeReceipt:false});
    snapshotId??=r.snapshotId;projectionDigest??=r.projectionDigest;
    if(snapshotId!==r.snapshotId||projectionDigest!==r.projectionDigest)throw new Error('SNAPSHOT_CHANGED_DURING_LIVE_CHECKS');
    counts[view]=Number(r.recordsets[0][0].row_count);
  }
  const read=await query('SELECT USER_NAME() AS reader,COUNT_BIG(*) AS scenario_count FROM sidefx.scenario',{writeReceipt:false});
  if(read.recordsets[0][0].reader!=='sidefx_reader')throw new Error('QUERY_NOT_RUNNING_AS_RESTRICTED_READER');
  const coverage=await query('SELECT (SELECT COUNT(*) FROM sidefx.capability) AS capabilities,(SELECT COUNT(DISTINCT capability_id) FROM sidefx.feature) AS feature_capabilities,(SELECT COUNT(*) FROM sidefx.feature) AS distinct_feature_byte_versions',{writeReceipt:false});
  if(coverage.recordsets[0][0].capabilities!==coverage.recordsets[0][0].feature_capabilities)throw new Error('MANAGED_CAPABILITY_FEATURE_COVERAGE_GAP');
  const rejected=[];
  for(const statement of [
    'UPDATE sidefx_data.current_pointer SET snapshot_id=snapshot_id WHERE 1=0;',
    'DELETE FROM sidefx_data.current_pointer WHERE 1=0;',
    'INSERT sidefx_data.current_pointer SELECT * FROM sidefx_data.current_pointer WHERE 1=0;',
    'REVERT; SELECT USER_NAME() AS escaped_user;'
  ]) {
    try {await query(statement,{writeReceipt:false});throw new Error('READER_BOUNDARY_NOT_ENFORCED');}
    catch(e) {if(!['EREQUEST'].includes(e.code))throw e;rejected.push({sqlErrorNumber:e.number,operation:statement.split(' ')[0]});}
  }
  const statement='SELECT capability_id,COUNT(*) AS scenario_count FROM sidefx.scenario GROUP BY capability_id ORDER BY capability_id';
  const first=await query(statement),second=await query(statement);
  if(first.snapshotId!==snapshotId||first.resultDigest!==second.resultDigest)throw new Error('QUERY_REPLAY_DIVERGED');
  const limited=await query('SELECT capability_id FROM sidefx.scenario ORDER BY capability_id',{rowLimit:1,writeReceipt:false});
  if(!limited.truncated||limited.recordsets[0].length!==1)throw new Error('QUERY_LIMIT_NOT_ENFORCED');
  return receipt('live-checks',{snapshotId,projectionDigest,disposition:'DIAGNOSTICS_AND_READER_BOUNDARY_VERIFIED',featureCoverage:coverage.recordsets[0][0],viewRowCounts:counts,rejectedWrites:rejected,queryReplayDigest:first.resultDigest,queryReceipts:[first.receiptPath,second.receiptPath],rowLimitVerified:true});
}
