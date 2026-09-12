// Run a .sql migration file batch-by-batch on ONE connection so a transaction
// opened inside the script spans GO batches.
//
//   node sql/migrations/run-file.mjs sql/migrations/<file>.sql
//
// If the script ends in ROLLBACK (verification mode), nothing is persisted and
// the SELECT verification result sets are printed. Flip ROLLBACK to COMMIT in the
// script to apply. The connection uses the database's configured importer login.
import fs from 'node:fs/promises';
import { connect, sql } from '../../src/ingest/database.mjs';

const file = process.argv[2];
if (!file) throw new Error('usage: node sql/migrations/run-file.mjs <sql-file>');

const text = await fs.readFile(file, 'utf8');
const batches = text.split(/^\s*GO\s*$/mi).map(s => s.trim()).filter(Boolean);

const pool = await connect();
const tx = new sql.Transaction(pool);
try {
  await tx.begin();
  let index = 0;
  for (const batch of batches) {
    index++;
    try {
      const result = await new sql.Request(tx).batch(batch);
      for (const rs of result.recordsets) {
        if (!rs.length) continue;
        const name = rs[0].section ?? rs[0].check_name ?? ('(batch ' + index + ')');
        console.log('RS', name, 'rows', rs.length, JSON.stringify(rs.slice(0, 5)));
      }
    } catch (e) {
      console.log('BATCH', index, 'FAILED:', e.message, 'number=' + e.number, 'line=' + e.lineNumber);
      const lines = batch.split('\n');
      if (e.lineNumber) console.log('LINE ' + e.lineNumber + ': ' + lines[e.lineNumber - 1]);
      throw e;
    }
  }
  console.log('ALL BATCHES EXECUTED');
} catch (e) {
  console.error('FAILED:', e.message);
  process.exitCode = 1;
} finally {
  try { await pool.close(); } catch {}
}
