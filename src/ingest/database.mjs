import sql from 'mssql';
import { execFileSync } from 'node:child_process';
import { config } from '../core.mjs';

export { sql };
export function connectionString(name) {
  if (process.env[name]) return process.env[name];
  if (process.platform === 'win32') {
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error('INVALID_CONNECTION_VARIABLE_NAME');
    const script = `$v=[Environment]::GetEnvironmentVariable('${name}','User'); if(-not $v){$v=[Environment]::GetEnvironmentVariable('${name}','Machine')}; [Console]::Write($v)`;
    const value = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', windowsHide: true }).trim();
    if (value) return value;
  }
  throw new Error('CONNECTION_VARIABLE_NOT_FOUND:' + name);
}
export async function connect() {
  const cfg = await config();
  let parsed;
  try { parsed = sql.ConnectionPool.parseConnectionString(connectionString(cfg.connectionEnvironmentVariable)); }
  catch { throw new Error('INVALID_OR_MISSING_SQL_CONNECTION_CONFIGURATION:' + cfg.connectionEnvironmentVariable); }
  parsed.requestTimeout = cfg.requestTimeoutMs;
  parsed.pool = { max: 2, min: 0, idleTimeoutMillis: 10000 };
  const pool = new sql.ConnectionPool(parsed);
  pool.on('error', () => {});
  try { return await pool.connect(); }
  catch (e) { await pool.close().catch(() => {}); throw new Error('DATABASE_CONNECTION_FAILED:' + (e.code ?? 'UNKNOWN')); }
}
export async function probe() {
  const pool = await connect();
  try {
    const r = await pool.request().query(`SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS product_version,
      DB_NAME() AS database_name, (SELECT compatibility_level FROM sys.databases WHERE name=DB_NAME()) AS compatibility_level;
      SELECT s.name AS schema_name,t.name AS table_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id ORDER BY s.name,t.name;
      SELECT HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE TABLE') AS can_create_table,
      HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE SCHEMA') AS can_create_schema,
      HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','ALTER ANY USER') AS can_create_reader;`);
    return { database: r.recordsets[0], existingTables: r.recordsets[1], permissions: r.recordsets[2] };
  } finally { await pool.close(); }
}
