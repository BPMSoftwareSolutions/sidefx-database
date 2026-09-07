import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const digest = bytes => 'sha256:' + createHash('sha256').update(bytes).digest('hex');
export const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
export function stable(value) {
  if (Array.isArray(value)) return '[' + Array.from(value,v=>v===undefined?'null':stable(v)).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).filter(k=>value[k]!==undefined).sort(compare).map(k => JSON.stringify(k) + ':' + stable(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
export const hash = value => digest(stable(value));
export async function config() { return JSON.parse(await fs.readFile(path.join(ROOT, 'config/harness.json'), 'utf8')); }
export const json = async file => JSON.parse(await fs.readFile(file, 'utf8'));
export async function writeJson(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, JSON.stringify(value, null, 2) + '\n');
}
export function digestToken(id) {
  if (!/^sha256:[0-9a-f]{64}$/.test(id)) throw new Error('INVALID_DIGEST');
  return id.slice(7);
}
export const blobPath = id => path.join(ROOT, 'data', 'objects', digestToken(id).slice(0, 2), digestToken(id));
export async function putBlob(bytes) {
  const id = digest(bytes), file = blobPath(id);
  await fs.mkdir(path.dirname(file), { recursive: true });
  try { await fs.writeFile(file, bytes, { flag: 'wx' }); }
  catch (e) { if (e.code !== 'EEXIST') throw e; if (digest(await fs.readFile(file)) !== id) throw new Error('EXISTING_OBJECT_CORRUPT:' + id); }
  return id;
}
export async function readBlob(id) {
  const bytes = await fs.readFile(blobPath(id));
  if (digest(bytes) !== id) throw new Error('OBJECT_DIGEST_MISMATCH:' + id);
  return bytes;
}
export async function receipt(kind, body) {
  const value = { receiptType: 'sidefx-database-' + kind + '.v1', observedAt: new Date().toISOString(), ...body };
  value.receiptDigest = hash(value);
  const file = path.join(ROOT, 'receipts', kind + '-' + digestToken(value.receiptDigest) + '.json');
  await writeJson(file, value);
  return { ...value, receiptPath: file };
}
export function safePath(root, relative) {
  if (typeof relative !== 'string' || !relative || relative.includes('\\') || relative.includes(':') || relative.split('/').some(p => p === '..' || p === '.')) throw new Error('UNSAFE_SOURCE_PATH');
  const absolute = path.resolve(root, relative), base = path.resolve(root) + path.sep;
  if (!absolute.startsWith(base)) throw new Error('SOURCE_PATH_ESCAPES_ROOT');
  return absolute;
}
export const escapePointer = s => String(s).replaceAll('~', '~0').replaceAll('/', '~1');
export function resolvePointer(object, pointer) {
  if (pointer === '') return object;
  if (!pointer.startsWith('/')) throw new Error('INVALID_JSON_POINTER');
  return pointer.slice(1).split('/').reduce((v, k) => v?.[k.replaceAll('~1', '/').replaceAll('~0', '~')], object);
}
