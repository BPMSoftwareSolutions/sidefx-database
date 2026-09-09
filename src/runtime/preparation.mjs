import fs from 'node:fs/promises';
import { connect, sql } from '../ingest/database.mjs';
import { digest, digestToken, hash, stable } from '../core.mjs';
import { query } from '../query/run.mjs';
import { pinModel } from '../query/model-pin.mjs';

const selectionSql = () => fs.readFile(new URL('../../sql/runtime/select-capability.sql', import.meta.url), 'utf8');
export const preparationFormat = 'sfx-capability-preparation.v1';

export function validatePreparation(value, { snapshotId, projectionDigest, viewDefinitionDigest, recipeDigest, selection } = {}) {
  if (value?.preparationType !== preparationFormat || value.proof?.status !== 'PASSED'
    || !value.proof.fixtureCount || !Array.isArray(value.proof.artifacts) || !value.proof.artifacts.length)
    throw new Error('PREPARATION_PROOF_REQUIRED');
  const { bundle } = value;
  const selected = bundle?.authority?.recordsets?.[0];
  if (selected?.length !== 1 || selected[0].capability_id !== bundle.selection?.capabilityId
    || selected[0].scenario_id !== bundle.selection?.scenarioId || !bundle.selection?.namespaceId
    || selected[0].namespace_id !== bundle.selection.namespaceId)
    throw new Error('PREPARATION_SELECTION_INVALID');
  for (const result of [bundle.authority, bundle.resolutions, bundle.mechanics]) {
    if (!result || result.truncated || result.snapshotId !== bundle.authority.snapshotId
      || result.projectionDigest !== bundle.authority.projectionDigest
      || result.viewDefinitionDigest !== bundle.authority.viewDefinitionDigest
      || result.resultDigest !== hash(result.recordsets.map(rows => rows.map(stable).sort())))
      throw new Error('PREPARATION_AUTHORITY_INVALID');
  }
  const readiness = bundle.resolutions.recordsets[1]?.filter(row => row.target_language === bundle.selection.target);
  if (readiness?.length !== 1 || readiness[0].readiness !== 'CAN_ATTEMPT_EMBODIMENT' || Number(readiness[0].open_requirement_count) !== 0)
    throw new Error('PREPARATION_BINDINGS_HELD');
  const stale = (actual, expected) => expected !== undefined && actual !== expected;
  if (stale(bundle.authority.snapshotId, snapshotId) || stale(bundle.authority.projectionDigest, projectionDigest)
    || stale(bundle.authority.viewDefinitionDigest, viewDefinitionDigest) || stale(value.recipeDigest, recipeDigest)
    || (selection && ['capabilityId', 'scenarioId', 'namespaceId', 'target'].some(key => stale(bundle.selection[key], selection[key]))))
    throw new Error('CAPABILITY_PREPARATION_STALE: prepare the selected revision again');
  digestToken(value.recipeDigest);
  return value;
}

export async function readPreparation(selection, recipeDigest) {
  digestToken(recipeDigest);
  const statement = await selectionSql() + '\n' + await fs.readFile(new URL('../../sql/runtime/read-preparation.sql', import.meta.url), 'utf8');
  const evidence = await query(statement, { input: { ...selection, recipeDigest }, retainObjects: false });
  if (evidence.truncated || evidence.recordsets[0]?.length !== 1) throw new Error('PREPARATION_READ_INVALID');
  const row = evidence.recordsets[0][0];
  const bytes = Buffer.from(row.payload_bytes.base64, 'base64');
  if (digest(bytes) !== row.preparation_digest) throw new Error('PREPARATION_PAYLOAD_CORRUPT');
  const preparation = validatePreparation(JSON.parse(bytes.toString('utf8')), { ...evidence, recipeDigest, selection });
  const { recordsets, ...queryEvidence } = evidence;
  return { preparation, preparationDigest: row.preparation_digest, preparedAt: row.prepared_at, queryEvidence };
}

// Explicit preparation is the only writer. Recheck the model/definition pin at
// publication, then use an insert-only principal. No authority or filesystem write.
export async function storePreparation(preparation) {
  validatePreparation(preparation);
  preparation = structuredClone(preparation);
  // Omitted versus explicit namespace/root can select identical authority. The
  // normalized selection and result digests identify the retained preparation;
  // request spelling remains in the prepare command's query evidence.
  for (const key of ['authority', 'resolutions', 'mechanics']) delete preparation.bundle[key].inputDigest;
  const { bundle } = preparation;
  const bytes = Buffer.from(stable(preparation)), payloadDigest = digest(bytes);
  const pool = await connect(), tx = new sql.Transaction(pool);
  let active = false;
  try {
    await tx.begin(); active = true;
    const pinned = await pinModel(tx);
    validatePreparation(preparation, { snapshotId: pinned.snapshot_id, projectionDigest: pinned.projection_id, viewDefinitionDigest: pinned.viewDefinitionDigest });
    await new sql.Request(tx).batch("EXECUTE AS USER='sidefx_preparer' WITH NO REVERT; SET LOCK_TIMEOUT 30000;");
    const result = await new sql.Request(tx)
      .input('estate_model_pk', sql.BigInt, pinned.estate_model_pk)
      .input('input', sql.NVarChar(sql.MAX), JSON.stringify(bundle.selection))
      .input('recipe', sql.Binary(32), Buffer.from(digestToken(preparation.recipeDigest), 'hex'))
      .input('views', sql.Binary(32), Buffer.from(digestToken(pinned.viewDefinitionDigest), 'hex'))
      .input('payload_digest', sql.Binary(32), Buffer.from(digestToken(payloadDigest), 'hex'))
      .input('payload', sql.VarBinary(sql.MAX), bytes)
      .input('capability_digest', sql.VarChar(71), bundle.authority.recordsets[0][0].capability_definition_digest)
      .input('scenario_digest', sql.VarChar(71), bundle.authority.recordsets[0][0].scenario_definition_digest)
      .query(await selectionSql() + `
IF NOT EXISTS(SELECT 1 FROM model.capability_version WHERE capability_version_pk=@capability_version_pk
  AND definition_digest=CONVERT(binary(32),SUBSTRING(@capability_digest,8,64),2))
  OR NOT EXISTS(SELECT 1 FROM model.scenario_version WHERE scenario_version_pk=@scenario_version_pk
  AND definition_digest=CONVERT(binary(32),SUBSTRING(@scenario_digest,8,64),2))
    THROW 51000,'CAPABILITY_PREPARATION_STALE',1;
DECLARE @old binary(32),@prepared_at datetime2(7);
SELECT @old=payload_digest,@prepared_at=prepared_at FROM runtime.capability_preparation WITH(UPDLOCK,HOLDLOCK)
WHERE estate_model_pk=@estate_model_pk AND capability_version_pk=@capability_version_pk
  AND scenario_version_pk=@scenario_version_pk AND target=@target AND recipe_digest=@recipe AND view_definition_digest=@views;
IF @old IS NOT NULL AND @old<>@payload_digest THROW 51000,'PREPARATION_CONFLICT',1;
IF @old IS NULL
BEGIN
  SET @prepared_at=SYSUTCDATETIME();
  INSERT runtime.capability_preparation(estate_model_pk,capability_pk,capability_version_pk,scenario_version_pk,target,recipe_digest,view_definition_digest,payload_digest,payload_bytes,prepared_at)
  VALUES(@estate_model_pk,@capability_pk,@capability_version_pk,@scenario_version_pk,@target,@recipe,@views,@payload_digest,@payload,@prepared_at);
END;
SELECT CASE WHEN @old IS NULL THEN 'STORED' ELSE 'ALREADY_PREPARED' END AS status,@prepared_at AS prepared_at;`);
    await tx.commit(); active = false;
    return { preparationDigest: payloadDigest, status: result.recordset[0].status, preparedAt: result.recordset[0].prepared_at.toISOString(), byteLength: bytes.length };
  } catch (error) {
    if (active) await tx.rollback().catch(() => {});
    throw error;
  } finally { await pool.close(); }
}
