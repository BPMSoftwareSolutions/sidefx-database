// Restore the media publication from SQL alone: no content-lab files or provider calls.
import fs from 'node:fs/promises';
import path from 'node:path';
import {connect,sql,sha,jsonBytes} from './store.mjs';
import {currentSource,readCatalog} from './catalog.mjs';
const args=process.argv.slice(2),at=args.indexOf('--output'),verifyOnly=args.includes('--verify-only');
if(!verifyOnly&&at<0)throw new Error('MEDIA_RESTORE_OUTPUT_REQUIRED');
const output=at<0?null:path.resolve(args[at+1]),pool=await connect();
try{
 const source=await currentSource(pool),manifest=await readCatalog(pool,'website-visual-publication',source);
 if(sha(jsonBytes(manifest.source))!==sha(jsonBytes(source)))throw new Error('MEDIA_RESTORE_SOURCE_MISMATCH');
 const entries=Object.entries(manifest.artifacts);let bytes=0;
 for(let start=0;start<entries.length;start+=48){
  const batch=entries.slice(start,start+48);
  const rows=(await pool.request().input('hashes',sql.NVarChar(sql.MAX),JSON.stringify([...new Set(batch.map(([,a])=>a.sha256))])).query(`SELECT LOWER(CONVERT(varchar(64),b.digest,2)) digest,b.bytes FROM media.blob b JOIN OPENJSON(@hashes) j ON b.digest=CONVERT(binary(32),j.value,2)`)).recordset;
  for(const [url,artifact] of batch){
   if(!/^\/media\/[a-zA-Z0-9_./-]+$/.test(url)||url.includes('..'))throw new Error('MEDIA_RESTORE_PATH_ESCAPE');
   const row=rows.find(r=>r.digest===artifact.sha256);if(!row||row.bytes.length!==artifact.bytes||sha(row.bytes)!==artifact.sha256)throw new Error('MEDIA_RESTORE_BYTES_MISMATCH');
   bytes+=row.bytes.length;
   if(output){const target=path.resolve(output,'public',url.slice(1));if(!target.startsWith(output+path.sep))throw new Error('MEDIA_RESTORE_PATH_ESCAPE');await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,row.bytes);}
  }
 }
 if(output){await fs.mkdir(path.join(output,'generated'),{recursive:true});await fs.writeFile(path.join(output,'generated/visual-publication.json'),jsonBytes(manifest));}
 console.log(JSON.stringify({state:verifyOnly?'SQL_ONLY_RECONSTRUCTION_VERIFIED':'RESTORED_FROM_SQL',artifacts:entries.length,bytes,manifestSha256:sha(jsonBytes(manifest))}));
}catch(e){console.error('MEDIA_RESTORE_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
