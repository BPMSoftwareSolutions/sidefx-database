import fs from 'node:fs/promises';
import path from 'node:path';
import { ROOT,config } from '../core.mjs';
import { MODEL,commonColumns } from '../derive/model.mjs';
import { ENTITIES } from '../derive/entities.mjs';
import { entityDDL,entityViews } from './entity-schema.mjs';
import { connect,sql } from './database.mjs';

export const columnType=(name,type)=>name==='capability_id'?'nvarchar(256) COLLATE Latin1_General_100_BIN2':type==='d'?'varchar(71) COLLATE Latin1_General_100_BIN2':type==='i'?'int':type==='b'?'bit':type==='x'?'nvarchar(max)':'nvarchar(4000) COLLATE Latin1_General_100_BIN2';
export const requiredColumn=(_table,name)=>['row_id','artifact_id','is_primary','origin_layer','source_pointer','pointer_kind','derivation_rule','object_digest','payload_json'].includes(name);
export function domainDDL() {
  return Object.entries(MODEL).map(([table,fields])=>`IF OBJECT_ID('sidefx_observation.${table}') IS NULL BEGIN
    CREATE TABLE sidefx_observation.[${table}](
      projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
      snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
      ${Object.entries({...commonColumns,...fields}).map(([name,t])=>`[${name}] ${columnType(name,t)} ${requiredColumn(table,name)?'NOT NULL':'NULL'}`).join(',\n')},
      PRIMARY KEY(projection_id,row_id),
      FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
      FOREIGN KEY(snapshot_id,artifact_id) REFERENCES sidefx_data.artifact(snapshot_id,artifact_id)
    );
    CREATE INDEX ix_${table}_capability ON sidefx_observation.[${table}](projection_id,capability_id,is_primary);
  END;
  ${Object.entries(fields).map(([name,t])=>`IF COL_LENGTH('sidefx_observation.${table}','${name}') IS NULL ALTER TABLE sidefx_observation.[${table}] ADD [${name}] ${columnType(name,t)} NULL;`).join('\n')}`).join('\n');
}
function observationViews() {
  const semantic=new Set(['capability','feature','scenario','input','event','product','contract']);
  const views=Object.keys(MODEL).map(table=>{
    let filter=semantic.has(table)?" WHERE d.is_primary=1 AND d.origin_layer='AUTHORITY'"+(table==='scenario'?" AND d.pointer_kind='LINE'":''):'';
    if(['feature','scenario','input','event','product'].includes(table))filter+=` AND EXISTS(SELECT 1 FROM sidefx_data.artifact a WHERE a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id AND a.entry_id LIKE 'features/{id}.feature%' AND NOT EXISTS(
      SELECT 1 FROM sidefx_data.artifact b WHERE b.snapshot_id=a.snapshot_id AND b.capability_id=a.capability_id AND b.source_class=a.source_class AND b.entry_id LIKE 'features/{id}.feature%' AND b.content_digest=a.content_digest AND b.artifact_id<a.artifact_id))`;
    let extra='';
    if(table==='contract')return `CREATE OR ALTER VIEW sidefx_observed.contract AS
      WITH consumed AS(SELECT contract_id,COUNT(*) AS consumer_count FROM sidefx_observed.input GROUP BY contract_id),
      produced AS(SELECT contract_id,COUNT(*) AS producer_count FROM sidefx_observed.product GROUP BY contract_id)
      SELECT d.*,COALESCE(c.consumer_count,0) AS consumer_count,COALESCE(r.producer_count,0) AS producer_count
      FROM sidefx_observation.contract d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
      LEFT JOIN consumed c ON c.contract_id=d.contract_id LEFT JOIN produced r ON r.contract_id=d.contract_id${filter};`;
    return `CREATE OR ALTER VIEW sidefx_observed.[${table}] AS
SELECT d.*${extra} FROM sidefx_observation.[${table}] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id${filter};`;
  });
  views.push(`CREATE OR ALTER VIEW sidefx_observed.provider_slot AS
    SELECT d.*,b.binding_count,b.provider_count,CASE WHEN b.provider_count=1 THEN b.provider_id ELSE NULL END AS provider_id
    FROM sidefx_observation.provider_slot d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
    OUTER APPLY(SELECT COUNT(*) AS binding_count,COUNT(DISTINCT b.provider_id) AS provider_count,MIN(b.provider_id) AS provider_id
      FROM sidefx_observation.provider_binding b WHERE b.projection_id=d.projection_id AND b.capability_id=d.capability_id AND b.is_primary=1 AND b.origin_layer=d.origin_layer
      AND ((d.slot_id IS NOT NULL AND b.slot_id=d.slot_id) OR (d.port_id IS NOT NULL AND b.port_id=d.port_id))) b;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.observed_scenario AS SELECT d.* FROM sidefx_observation.scenario d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.[transition] AS SELECT d.*,'SEMANTIC_GRAPH' AS representation FROM sidefx_observed.observed_semantic_graph_transition d;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.estate_snapshot AS SELECT * FROM sidefx_data.estate_snapshot;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.artifact AS SELECT a.*,c.format,c.status AS extraction_status,c.root_type FROM sidefx_data.artifact a JOIN sidefx_data.current_pointer p ON p.snapshot_id=a.snapshot_id JOIN sidefx_data.artifact_catalog c ON c.projection_id=p.projection_id AND c.artifact_id=a.artifact_id;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.canonical_object AS SELECT o.* FROM sidefx_data.canonical_object o WHERE EXISTS(SELECT 1 FROM sidefx_observed.artifact a WHERE a.content_digest=o.content_digest);`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.digest AS SELECT content_digest,byte_length FROM sidefx_observed.canonical_object;`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.capability_source AS SELECT DISTINCT a.snapshot_id,a.capability_id,a.capsule_digest,a.authority_digest,a.container_path FROM sidefx_observed.artifact a WHERE a.source_class IN('MANAGED_CAPSULE','MANAGED_RUNTIME','PROVISIONED_CAPSULE');`);
  views.push(`CREATE OR ALTER VIEW sidefx_observed.source_pointer AS ${Object.keys(MODEL).map(t=>`SELECT '${t}' AS object_kind,d.row_id,d.snapshot_id,d.artifact_id,d.capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,a.content_digest AS canonical_digest,a.authority_digest,a.source_path,a.container_path FROM sidefx_observation.[${t}] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id JOIN sidefx_observed.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id`).join('\nUNION ALL\n')};`);
  return views;
}

export function currentViews() {
  const aliases=['estate_snapshot','artifact','canonical_object','digest','capability_source','source_pointer','observed_scenario','transition','extraction_issue',...Object.keys(MODEL).filter(t=>t.startsWith('observed_'))];
  return [...observationViews(),...entityViews(),...aliases.map(name=>`CREATE OR ALTER VIEW sidefx.[${name}] AS SELECT * FROM sidefx_observed.[${name}];`),
    `CREATE OR ALTER VIEW sidefx.contract AS SELECT d.*,COALESCE(c.consumer_count,0) AS consumer_count,COALESCE(r.producer_count,0) AS producer_count FROM sidefx_data.contract d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
      OUTER APPLY(SELECT COUNT(*) AS consumer_count FROM sidefx.input i WHERE i.contract_id=d.contract_id) c
      OUTER APPLY(SELECT COUNT(*) AS producer_count FROM sidefx.product x WHERE x.contract_id=d.contract_id) r;`,
    `CREATE OR ALTER VIEW sidefx.provider_slot AS SELECT d.*,b.binding_count,b.provider_count,CASE WHEN b.provider_count=1 THEN b.provider_id ELSE NULL END AS provider_id FROM sidefx_data.provider_slot d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id
      OUTER APPLY(SELECT COUNT(*) AS binding_count,COUNT(DISTINCT x.provider_id) AS provider_count,MIN(x.provider_id) AS provider_id FROM sidefx.provider_binding x WHERE x.capability_id=d.capability_id AND ((x.slot_id IS NOT NULL AND x.slot_id=d.slot_id) OR (d.port_id IS NOT NULL AND x.port_id=d.port_id))) b;`
  ];
}
export async function initialize({transaction=null}={}) {
  throw new Error('LEGACY_SCHEMA_RETIRED: use npm run migrate');
  const cfg=await config();if(cfg.databaseSchema!=='sidefx')throw new Error('UNSUPPORTED_SCHEMA_CONFIGURATION');
  const ddl=domainDDL(),entities=entityDDL(),generated=currentViews();
  await fs.writeFile(path.join(ROOT,'sql/schema/002-domain-tables.sql'),'-- Source observations and retained projection history.\n'+ddl+'\n');
  await fs.writeFile(path.join(ROOT,'sql/schema/004-entity-tables.sql'),'-- Current entities with explicit unique keys and source links.\n'+entities+'\n');
  await fs.writeFile(path.join(ROOT,'sql/views/001-current.sql'),generated.join('\nGO\n')+'\n');
  const pool=transaction?null:await connect(),tx=transaction??new sql.Transaction(pool);let begun=false;
  try {
    if(!transaction){await tx.begin();begun=true;}
    for(const resource of ['sidefx-database-schema','sidefx-database-ingestion'])await new sql.Request(tx).input('resource',sql.NVarChar(255),resource).query("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000; IF @r<0 THROW 51000,'Cannot lock inspection schema',1;");
    await new sql.Request(tx).batch(await fs.readFile(path.join(ROOT,'sql/schema/001-archive.sql'),'utf8'));
    const version=(await new sql.Request(tx).query('SELECT schema_version FROM sidefx_data.workspace_identity')).recordset[0].schema_version;
    const populated=(await new sql.Request(tx).query('SELECT COUNT(*) AS n FROM sidefx_data.current_pointer')).recordset[0].n;
    if(version===1&&populated&&!transaction)throw new Error('ENTITY_MODEL_MIGRATION_REQUIRES_ATOMIC_INGEST: run npm run ingest');
    await new sql.Request(tx).batch("IF SCHEMA_ID('sidefx_observation') IS NULL EXEC('CREATE SCHEMA sidefx_observation'); IF SCHEMA_ID('sidefx_observed') IS NULL EXEC('CREATE SCHEMA sidefx_observed');");
    if(version===1)for(const table of Object.keys(MODEL))await new sql.Request(tx).batch(`IF OBJECT_ID('sidefx_data.${table}','U') IS NOT NULL BEGIN
      IF OBJECT_ID('sidefx_observation.${table}') IS NOT NULL THROW 51000,'Observation migration destination already exists',1;
      ALTER SCHEMA sidefx_observation TRANSFER sidefx_data.[${table}];
    END;`);
    await new sql.Request(tx).batch(ddl);
    await new sql.Request(tx).batch(entities);
    await new sql.Request(tx).batch(await fs.readFile(path.join(ROOT,'sql/schema/003-query-indexes.sql'),'utf8'));
    for(const view of generated)await new sql.Request(tx).batch(view);
    for(const file of (await fs.readdir(path.join(ROOT,'sql/views'))).filter(f=>f.endsWith('.sql')&&f!=='001-current.sql').sort())for(const batch of (await fs.readFile(path.join(ROOT,'sql/views',file),'utf8')).split(/^GO\s*$/m).filter(x=>x.trim()))await new sql.Request(tx).batch(batch);
    await new sql.Request(tx).batch("IF DATABASE_PRINCIPAL_ID('sidefx_reader') IS NULL CREATE USER sidefx_reader WITHOUT LOGIN WITH DEFAULT_SCHEMA=sidefx;");
    for(const schema of ['sidefx','sidefx_data','sidefx_observation','sidefx_observed'])await new sql.Request(tx).batch(`GRANT SELECT ON SCHEMA::${schema} TO sidefx_reader; DENY INSERT,UPDATE,DELETE,ALTER,TAKE OWNERSHIP ON SCHEMA::${schema} TO sidefx_reader;`);
    await new sql.Request(tx).query("UPDATE sidefx_data.workspace_identity SET schema_version=3 WHERE product='sidefx-database-observation'");
    if(!transaction){await tx.commit();begun=false;}
    return {disposition:'INSPECTION_SCHEMA_READY',entityTableCount:Object.keys(ENTITIES).length,observationTableCount:Object.keys(MODEL).length};
  }catch(e){if(begun)await tx.rollback().catch(()=>{});throw e;}finally{if(pool)await pool.close();}
}
