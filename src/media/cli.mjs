import {migrateMedia,seedRequirements,connect} from './store.mjs';
try {
 const cmd=process.argv[2];
 if(cmd==='migrate')for(const version of ['005-media-registry','006-media-integrity'])console.log(JSON.stringify(await migrateMedia(version)));
 else if(cmd==='seed') {const pool=await connect();try{console.log(JSON.stringify(await seedRequirements(pool),null,2));}finally{await pool.close();}}
 else throw new Error('UNKNOWN_MEDIA_COMMAND');
}catch(e){console.error(JSON.stringify({error:e.code??'MEDIA_OPERATION_FAILED',message:/^MEDIA_|^UNKNOWN_/.test(e.message)?e.message:'Operation failed; credentials and SQL driver configuration withheld.'}));process.exitCode=1;}
