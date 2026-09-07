import fs from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { ROOT, config, digest, hash, compare, putBlob, readBlob, json, writeJson, receipt, safePath, digestToken } from '../core.mjs';

function git(root, args) { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, windowsHide: true }); }
function verification(root) {
  // The installed manager is the existing read-only estate verification boundary.
  const packageRoot = path.join(root, 'node_modules/sda-bootstrap');
  const metadata = JSON.parse(readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
  const cli = path.resolve(packageRoot, metadata.bin['sda-bootstrap']);
  return JSON.parse(execFileSync(process.execPath, [cli, 'verify'], { cwd: root, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024, windowsHide: true }));
}
function sourceClass(relative, tracked) {
  if (relative.startsWith('capsules/')) return 'MANAGED_ESTATE';
  if (relative.startsWith('provisioning/')) return 'PROVISIONED_TESTIMONY';
  return tracked ? 'REPOSITORY_TRACKED' : 'WORKING_TREE_TESTIMONY';
}
export function decodeCapsule(bytes, record) {
  if (record && digest(bytes) !== record.capsuleDigest) throw new Error('CAPSULE_DIGEST_MISMATCH:' + record.capabilityId);
  const cap = JSON.parse(bytes.toString('utf8'));
  if (cap.capsuleFormat !== 'sidefx-capsule-pack.v1' || cap.capsuleFormatVersion !== '1.0.0' || !Array.isArray(cap.entries)) throw new Error('UNSUPPORTED_CAPSULE_FORMAT');
  if (record && cap.capabilityId !== record.capabilityId) throw new Error('CAPSULE_IDENTITY_MISMATCH');
  const refs = new Set();
  const entries = cap.entries.map(e => {
    safePath(ROOT, e.entryRef);
    if (refs.has(e.entryRef)) throw new Error('DUPLICATE_CAPSULE_ENTRY:' + e.entryRef);
    refs.add(e.entryRef);
    if (typeof e.entryBytesBase64 !== 'string') throw new Error('MISSING_ENTRY_BYTES');
    const data = Buffer.from(e.entryBytesBase64, 'base64');
    if (data.toString('base64') !== e.entryBytesBase64 || digest(data) !== e.entryDigest) throw new Error('ENTRY_DIGEST_MISMATCH:' + e.entryRef);
    return { ...e, bytes: data };
  });
  if (record && !entries.some(e => e.entryId === 'capability.authority.json' && e.entryDigest === record.capabilityAuthorityDigest)) throw new Error('CAPABILITY_AUTHORITY_MISMATCH');
  return { ...cap, entries };
}
export async function capture() {
  const cfg = await config(), root = await fs.realpath(cfg.harnessRoot);
  if (ROOT.toLowerCase().startsWith((root + path.sep).toLowerCase())) throw new Error('OBSERVATION_WORKSPACE_INSIDE_HARNESS');
  const verified = verification(root);
  const state = () => ({ head: git(root, ['rev-parse', 'HEAD']).trim(), status: git(root, ['status', '--porcelain=v1', '-uall']) });
  const before = state();
  const tracked = new Set(git(root, ['ls-files', '-z']).split('\0').filter(Boolean));
  const paths = () => [...new Set([...tracked, ...(cfg.includeUntracked ? git(root, ['ls-files', '--others', '--exclude-standard', '-z']).split('\0').filter(Boolean) : [])])].sort(compare);
  const allPaths = paths();
  const manifestBytes = await fs.readFile(path.join(root, 'capsules/capsule-estate.manifest.json'));
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  if (manifest.capabilityCount !== manifest.capsules.length || manifest.capabilityCount !== verified.capabilityCount) throw new Error('ESTATE_COUNT_MISMATCH');
  const managed = new Map(manifest.capsules.map(c => ['capsules/' + c.file, c]));
  if (managed.size !== manifest.capabilityCount) throw new Error('DUPLICATE_ESTATE_CAPSULE');
  const artifacts = [], sources = [], exclusions = [], missing = [];
  for (const relative of allPaths) {
    if (cfg.excludedPaths.some(prefix => relative.startsWith(prefix)) || /(^|\/)(\.env($|\.)|[^/]+\.(pfx|p12|pem|key)$)/i.test(relative)) {
      exclusions.push({ path: relative, reason: 'SECRET_OR_INFRASTRUCTURE_EXCLUSION' }); continue;
    }
    const file = safePath(root, relative);
    let stat;
    try { stat = await fs.lstat(file); } catch (e) { if (e.code === 'ENOENT') { missing.push(relative); continue; } throw e; }
    if (stat.isSymbolicLink() || !stat.isFile() || (await fs.realpath(file)).toLowerCase() !== file.toLowerCase()) throw new Error('UNSUPPORTED_SOURCE_LINK:' + relative);
    const bytes = await fs.readFile(file), id = await putBlob(bytes);
    const cls = sourceClass(relative, tracked.has(relative));
    const base = { sourcePath: relative, sourceClass: cls, contentDigest: id, byteLength: bytes.length, capabilityId: null, capsuleDigest: null, authorityDigest: null, entryId: null, containerPath: null };
    artifacts.push(base); sources.push({ path: relative, digest: id, tracked: tracked.has(relative) });
    if (relative.endsWith('.sfxcap')) {
      const record = managed.get(relative);
      if (relative.startsWith('capsules/') && !record) throw new Error('UNMANIFESTED_MANAGED_CAPSULE:' + relative);
      const cap = decodeCapsule(bytes, record);
      const authority = record?.capabilityAuthorityDigest ?? cap.entries.find(e => e.entryId === 'capability.authority.json')?.entryDigest ?? null;
      for (const entry of cap.entries) {
        const entryDigest = await putBlob(entry.bytes);
        artifacts.push({ sourcePath: entry.entryRef, sourceClass: record ? (entry.entryRef.startsWith('capsule-runtime/') ? 'MANAGED_RUNTIME' : 'MANAGED_CAPSULE') : 'PROVISIONED_CAPSULE', contentDigest: entryDigest, byteLength: entry.bytes.length, capabilityId: cap.capabilityId, capsuleDigest: id, authorityDigest: authority, entryId: entry.entryId, containerPath: relative });
      }
    }
  }
  if (manifest.capsules.some(c => !sources.some(s => s.path === 'capsules/' + c.file))) throw new Error('MISSING_MANAGED_CAPSULE');
  // A second complete byte pass and inventory/state comparison reject mixed captures.
  for (const s of sources) if (digest(await fs.readFile(safePath(root, s.path))) !== s.digest) throw new Error('SOURCE_CHANGED_DURING_CAPTURE:' + s.path);
  if (hash(allPaths) !== hash(paths()) || hash(before) !== hash(state()) || digest(manifestBytes) !== digest(await fs.readFile(path.join(root, 'capsules/capsule-estate.manifest.json')))) throw new Error('ESTATE_CHANGED_DURING_CAPTURE');
  const verifiedAfter = verification(root);
  if (hash(verified) !== hash(verifiedAfter)) throw new Error('ESTATE_VERIFICATION_CHANGED');
  artifacts.sort((a,b) => compare(stableKey(a), stableKey(b)));
  for (const a of artifacts) a.artifactId = hash(a);
  const body = { snapshotFormat: 'sidefx-observation-snapshot.v1', estateManifestDigest: digest(manifestBytes), sourceHead: before.head, sourceStatus: before.status, scope: { includeUntracked: cfg.includeUntracked, excludedPaths: cfg.excludedPaths }, verified, sources, exclusions, missing, artifacts };
  const snapshotId = hash(body), snapshot = { snapshotId, ...body };
  const file = path.join(ROOT, 'data/snapshots', digestToken(snapshotId) + '.json');
  try { await fs.mkdir(path.dirname(file), { recursive: true }); await fs.writeFile(file, JSON.stringify(snapshot, null, 2) + '\n', { flag: 'wx' }); }
  catch (e) { if (e.code !== 'EEXIST') throw e; if (hash(await json(file)) !== hash(snapshot)) throw new Error('SNAPSHOT_CONFLICT'); }
  await writeJson(path.join(ROOT, 'data/current.json'), { snapshotId });
  const proof = await receipt('snapshot', { snapshotId, estateManifestDigest: body.estateManifestDigest, verified, sourceCount: sources.length, artifactCount: artifacts.length, exclusionCount: exclusions.length, missingCount: missing.length, sourceRoot: root, disposition: 'CAPTURED_VERIFIED_OBSERVATION' });
  return { snapshotId, sourceCount: sources.length, artifactCount: artifacts.length, capabilityCount: verified.capabilityCount, receiptPath: proof.receiptPath };
}
const stableKey = a => `${a.containerPath ?? ''}\0${a.sourcePath}\0${a.contentDigest}`;
export async function loadSnapshot(id) {
  id ??= (await json(path.join(ROOT, 'data/current.json'))).snapshotId;
  const snapshot = await json(path.join(ROOT, 'data/snapshots', digestToken(id) + '.json'));
  const { snapshotId, ...body } = snapshot;
  if (id !== snapshotId || hash(body) !== id) throw new Error('SNAPSHOT_DIGEST_MISMATCH');
  return snapshot;
}
export async function verifySnapshot(snapshot) {
  const unique = new Set(snapshot.artifacts.map(a => a.contentDigest));
  for (const id of unique) await readBlob(id);
  return { snapshotId: snapshot.snapshotId, verifiedObjects: unique.size };
}
