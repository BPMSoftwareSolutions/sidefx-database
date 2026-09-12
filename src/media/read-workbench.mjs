// Read retained publication bytes only. This module neither compiles media nor
// restores a filesystem tree. Publication identity is selected by SQL snapshot.
import { connect, sql, getBlob, sha } from './store.mjs';
import { currentSource, assertSource } from './catalog.mjs';

const PREFIX = '/media/library/outputs/estate-topology/';
export function readPayload(bytes, variable) {
  const match = bytes.toString('utf8').match(new RegExp('^\\s*window\\.' + variable + '\\s*=\\s*([\\s\\S]*?)\\s*;?\\s*$'));
  if (!match) throw new Error('CIRCUIT_PAYLOAD_INVALID');
  return JSON.parse(match[1]);
}
export function verifiedArtifact(bytes, entry) {
  if (!entry || bytes.length !== entry.bytes || sha(bytes) !== entry.sha256) throw new Error('MEDIA_PUBLICATION_BYTES_MISMATCH');
  return bytes;
}
export async function readWorkbench({ operation, capabilityId, viewId, artifactDigest } = {}) {
  const pool = await connect();
  try {
    const current = await currentSource(pool);
    // Registrations can change the model/projection while retaining the source
    // snapshot. Read that snapshot's latest explicit media publication, retain
    // its own model/projection identity, and never cross a snapshot boundary.
    const row = (await pool.request().input('snapshot', sql.Binary(32), Buffer.from(current.snapshotDigest, 'hex')).query(`
      SELECT TOP(1) LOWER(CONVERT(varchar(64),r.blob_digest,2)) digest
      FROM media.asset a JOIN media.asset_revision r ON r.asset_id=a.asset_id
      JOIN source.estate_model m ON a.logical_key=CONCAT('media-catalog/',m.estate_model_pk,'/website-visual-publication')
      JOIN source.estate_snapshot s ON s.estate_snapshot_pk=m.estate_snapshot_pk
      WHERE s.snapshot_digest=@snapshot ORDER BY r.created_at DESC,r.revision_id`)).recordset[0];
    if (!row) throw new Error('CIRCUIT_PUBLICATION_UNAVAILABLE');
    const publication = JSON.parse((await getBlob(pool, row.digest)).bytes.toString('utf8'));
    if (publication.source.snapshotDigest !== current.snapshotDigest) throw new Error('CIRCUIT_PUBLICATION_SNAPSHOT_MISMATCH');
    const identity = { snapshotId: 'sha256:' + current.snapshotDigest, projectionDigest: 'sha256:' + current.mappingDigest,
      publicationDigest: 'sha256:' + row.digest, publicationSource: publication.source };
    const read = async url => {
      const entry = publication.artifacts[url];
      if (!entry) throw new Error('CIRCUIT_ARTIFACT_UNAVAILABLE');
      const bytes = verifiedArtifact((await getBlob(pool, entry.sha256)).bytes, entry);
      return { bytes, entry };
    };
    let result;
    if (operation === 'catalogue') {
      const capabilities = (await pool.request().input('model', sql.BigInt, current.estateModelPk).query(`
        SELECT c.capability_id AS capabilityId,n.namespace_id AS namespaceId FROM model.estate_capability ec
        JOIN model.capability c ON c.capability_pk=ec.capability_pk
        JOIN model.identity_namespace n ON n.namespace_pk=c.namespace_pk WHERE ec.estate_model_pk=@model ORDER BY c.capability_id`)).recordset;
      result = { ...identity, capabilities: capabilities.map(c => ({ ...c,
        circuitAvailable: !!publication.artifacts[PREFIX + c.capabilityId + '/catalog.js'] })) };
    } else if (operation === 'artifact') {
      if (!/^[a-f0-9]{64}$/.test(artifactDigest ?? '')) throw new Error('MEDIA_IDENTITY_INVALID');
      const url = Object.keys(publication.artifacts).find(url => url.startsWith(PREFIX + 'textures/') && publication.artifacts[url].sha256 === artifactDigest);
      if (!url) throw new Error('CIRCUIT_ARTIFACT_UNAVAILABLE');
      const { bytes, entry } = await read(url);
      result = { ...identity, artifact: { url, ...entry, base64: bytes.toString('base64') } };
    } else {
      if (!/^[a-z0-9][a-z0-9-]{0,127}$/.test(capabilityId ?? '')) throw new Error('CAPABILITY_IDENTITY_INVALID');
      const url = PREFIX + capabilityId + '/catalog.js';
      const { bytes } = await read(url);
      const catalogue = readPayload(bytes, 'ESTATE_TOPOLOGY_CATALOG');
      if (catalogue.capabilityId !== capabilityId || catalogue.source.snapshotDigest !== current.snapshotDigest) throw new Error('CIRCUIT_CATALOGUE_IDENTITY_MISMATCH');
      if (viewId === undefined) result = { ...identity, capabilityId, views: catalogue.views };
      else {
        if (!/^n-[a-f0-9]{24}$/.test(viewId)) throw new Error('CIRCUIT_VIEW_IDENTITY_INVALID');
        const view = catalogue.views.find(view => view.id === viewId);
        if (!view || view.url !== PREFIX + capabilityId + '/' + viewId + '.js') throw new Error('CIRCUIT_VIEW_UNAVAILABLE');
        const { bytes: payload, entry } = await read(view.url);
        // Send the original retained payload, not a regenerated graph or SVG.
        const parsed = readPayload(payload, 'ESTATE_TOPOLOGY_VIEW');
        if (parsed.id !== viewId || !parsed.identity.startsWith(capabilityId + '/') || !parsed.svg) throw new Error('CIRCUIT_VIEW_IDENTITY_MISMATCH');
        result = { ...identity, capabilityId, viewId, view, artifact: { url: view.url, ...entry, base64: payload.toString('base64') } };
      }
    }
    await assertSource(pool, current);
    return result;
  } finally { await pool.close(); }
}
