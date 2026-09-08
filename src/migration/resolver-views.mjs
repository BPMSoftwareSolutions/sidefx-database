import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { connect, sql } from '../ingest/database.mjs';
import { digest } from './catalog.mjs';

export async function migrateResolverViews({ dryRun = false } = {}) {
  const id = '004-scenario-resolver-map';
  const source = await fs.readFile(new URL(`../../sql/migrations/${id}.sql`, import.meta.url), 'utf8');
  const hash = digest(source);
  const batches = source.split(/^GO\s*$/m).map(s => s.trim()).filter(Boolean);
  const pool = await connect(), tx = new sql.Transaction(pool);
  let active = false;
  try {
    await tx.begin(); active = true;
    await new sql.Request(tx).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='sidefx:ddl-migration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=60000; IF @r<0 THROW 51002,'MIGRATION_LOCK_UNAVAILABLE',1;");
    const old = (await new sql.Request(tx).input('id', sql.NVarChar(100), id)
      .query('SELECT migration_digest FROM source.schema_migration WHERE migration_id=@id')).recordset[0];
    if (old && old.migration_digest !== hash) throw new Error(`MIGRATION_HISTORY_MISMATCH:${id}`);
    if (!old) {
      for (let i = 0; i < batches.length; i++) {
        try { await new sql.Request(tx).batch(batches[i]); }
        catch (error) { throw new Error(`RESOLVER_VIEW_BATCH_${i}: ${error.message}`); }
      }
      await new sql.Request(tx).input('id', sql.NVarChar(100), id).input('hash', sql.Char(64), hash)
        .query('INSERT source.schema_migration(migration_id,migration_digest) VALUES(@id,@hash)');
    }
    if (dryRun) await tx.rollback(); else await tx.commit();
    active = false;
    return { id, digest: hash, objects: batches.length,
      status: old ? 'ALREADY_APPLIED' : dryRun ? 'VALIDATED_AND_ROLLED_BACK' : 'APPLIED' };
  } catch (error) {
    if (active) await tx.rollback().catch(() => {});
    throw error;
  } finally { await pool.close(); }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(await migrateResolverViews({ dryRun: process.argv.includes('--dry-run') }))); }
  catch (error) { console.error(JSON.stringify({ error: error.message })); process.exitCode = 1; }
}
