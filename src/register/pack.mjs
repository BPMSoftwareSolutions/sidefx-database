// Pack authored capability artifacts into a deterministic sidefx-capsule-pack.v1
// capsule.
//
// The estate's own provisioner builds a capsule FROM a reviewed feature, which
// regenerates a scaffold with open slots. It has no entry point that packages
// externally authored authority, so authored transformations and contracts would
// be discarded by it. This packer takes the authored bytes as given and emits
// the same capsule format, so one set of bytes serves both registration and the
// harness's provisioning/ directory -- one digest, no divergence.
//
// Determinism: entries are ordered by entryRef, the envelope is canonical JSON
// with sorted keys, and every digest is computed from the bytes actually
// carried. Packing the same inputs twice yields byte-identical capsules.
//
// The capsule is PROVISIONAL. It carries authored authority; it is not an
// admitted managed capsule and nothing here claims admission.
import fs from 'node:fs/promises';
import path from 'node:path';
import { digest, compare } from '../core.mjs';
import { canonical } from '../migration/data.mjs';

// capture.mjs classifies a .sfxcap under capsules/ as MANAGED_ESTATE and throws
// UNMANIFESTED_MANAGED_CAPSULE when it is not in the estate manifest. A
// provisioned capsule therefore belongs under provisioning/.
export const PROVISIONING_DIR = 'provisioning';

async function readTree(dir) {
  const found = [];
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...await readTree(full));
    else found.push(full);
  }
  return found;
}

/**
 * Build the capsule envelope for one authored capability.
 *
 * @param {object} spec
 * @param {string} spec.capabilityId
 * @param {string} spec.dir          authored artifact directory
 * @param {string} spec.featureFile  the reviewed .feature
 * @returns {Promise<{bytes:Buffer, capsuleDigest:string, entries:Array, fileName:string}>}
 */
export async function packCapability(spec) {
  const entries = [];

  for (const file of (await readTree(spec.dir)).sort(compare)) {
    const bytes = await fs.readFile(file);
    // entryId is the path within the capability; entryRef is the estate path.
    // project.mjs enforces container identity, so entryRef must be
    // capabilities/<capabilityId>/... or the capture rejects it with
    // CAPABILITY_CONTAINER_ID_MISMATCH.
    const entryId = path.relative(spec.dir, file).split(path.sep).join('/');
    entries.push({
      entryRef: `capabilities/${spec.capabilityId}/${entryId}`,
      entryId,
      entryDigest: digest(bytes),
      entryBytesBase64: bytes.toString('base64')
    });
  }

  const featureBytes = await fs.readFile(spec.featureFile);
  entries.push({
    entryRef: `features/${spec.capabilityId}.feature`,
    entryId: 'features/{id}.feature',
    entryDigest: digest(featureBytes),
    entryBytesBase64: featureBytes.toString('base64')
  });

  entries.sort((a, b) => compare(a.entryRef, b.entryRef));

  const seen = new Set();
  for (const entry of entries) {
    if (seen.has(entry.entryRef)) throw new Error('DUPLICATE_CAPSULE_ENTRY:' + entry.entryRef);
    seen.add(entry.entryRef);
    // decodeCapsule re-encodes and compares, so a non-canonical base64 string
    // would fail there rather than here.
    if (Buffer.from(entry.entryBytesBase64, 'base64').toString('base64') !== entry.entryBytesBase64)
      throw new Error('NON_CANONICAL_ENTRY_ENCODING:' + entry.entryRef);
  }
  if (!entries.some(e => e.entryId === 'capability.authority.json'))
    throw new Error('CAPABILITY_AUTHORITY_ENTRY_MISSING:' + spec.capabilityId);

  const capsule = {
    capabilityId: spec.capabilityId,
    capabilityVersion: spec.capabilityVersion ?? '0.0.0-provisioned',
    capsuleFormat: 'sidefx-capsule-pack.v1',
    capsuleFormatVersion: '1.0.0',
    declaredDependencies: spec.declaredDependencies ?? [],
    entries,
    externalToolRoots: [],
    lifecycleDisposition: 'PROVISIONAL',
    lineage: `features/${spec.capabilityId}.feature`,
    packing: 'canonical-json',
    // No runtime binding is claimed: these artifacts are authored authority, not
    // a projected runtime. An empty set is the honest statement.
    runtimeBindings: []
  };

  const bytes = Buffer.from(canonical(capsule), 'utf8');
  return {
    bytes,
    capsuleDigest: digest(bytes),
    entries,
    fileName: `${spec.capabilityId}-${digest(bytes).slice('sha256:'.length, 'sha256:'.length + 16)}.sfxcap`
  };
}

/** Write the capsule into a harness provisioning directory. */
export async function writeCapsule(packed, harnessRoot) {
  const target = path.join(harnessRoot, PROVISIONING_DIR, packed.fileName);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, packed.bytes);
  return target;
}
