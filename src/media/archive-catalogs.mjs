import fs from 'node:fs/promises';
import path from 'node:path';
import {connect} from './store.mjs';
import {saveCatalog,currentSource} from './catalog.mjs';
import {ROOT} from '../core.mjs';
const pool=await connect();
try{
 const source=await currentSource(pool);
 for(const [name,file] of [['lab','lab-import.json'],['circuits','circuit-import.json'],['inventory','inventory.json'],['website-inventory','website-inventory.json']]){
  const value=JSON.parse(await fs.readFile(path.join(ROOT,'data/media',file),'utf8'));
  const stored=await saveCatalog(pool,name,source,value);console.log('SQL_CATALOG',name,stored.revision);
 }
}catch(e){console.error('MEDIA_CATALOG_ARCHIVE_FAILED',e.number??e.code??e.message);process.exitCode=1;}finally{await pool.close();}
