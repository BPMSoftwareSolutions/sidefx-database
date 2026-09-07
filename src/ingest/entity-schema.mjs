import { ENTITIES,entityColumns,entityMetadata,entityRequired } from '../derive/entities.mjs';

export const entityColumnType=(name,key,t)=>ENTITIES[name].keys.includes(key)||key==='capability_id'||key==='bound_capability_id'
  ?t==='i'?'int':`nvarchar(${['verb','object','binding_kind'].includes(key)?64:256}) COLLATE Latin1_General_100_BIN2`
  :t==='d'?'varchar(71) COLLATE Latin1_General_100_BIN2':t==='i'?'int':t==='b'?'bit':t==='x'?'nvarchar(max)':'nvarchar(4000) COLLATE Latin1_General_100_BIN2';
export function entityDDL() {
  const result=[];
  for(const [name,e] of Object.entries(ENTITIES)) {
    const cols={...entityColumns(name),...entityMetadata};
    result.push(`IF OBJECT_ID('sidefx_data.${name}') IS NULL BEGIN
      CREATE TABLE sidefx_data.[${name}](
        projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
        snapshot_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
        ${Object.entries(cols).map(([k,t])=>`[${k}] ${entityColumnType(name,k,t)} ${entityRequired(name,k)?'NOT NULL':'NULL'}`).join(',\n')},
        PRIMARY KEY(row_id),
        UNIQUE(${e.keys.map(k=>'['+k+']').join(',')}),
        FOREIGN KEY(projection_id,snapshot_id) REFERENCES sidefx_data.projection_run(projection_id,snapshot_id),
        CHECK(source_count>0),
        CHECK(resolution_status IN('RESOLVED','CONFLICTING_DECLARATIONS')),
        CHECK(ISJSON(conflict_fields_json)=1)
        ${e.keys.filter(k=>cols[k]!=='i').map(k=>`,CHECK(DATALENGTH([${k}])>0 AND DATALENGTH([${k}])=DATALENGTH(LTRIM(RTRIM([${k}]))))`).join('')}
        ${name!=='capability'&&e.fields.includes('capability_id')?',FOREIGN KEY(capability_id) REFERENCES sidefx_data.capability(capability_id)':''}
        ${e.fields.includes('bound_capability_id')?',FOREIGN KEY(bound_capability_id) REFERENCES sidefx_data.capability(capability_id)':''}
        ${name==='external_provider_capability'?',FOREIGN KEY(provider_id) REFERENCES sidefx_data.external_provider(provider_id)':''}
      );
    END;
    IF OBJECT_ID('sidefx_data.${name}_source') IS NULL BEGIN
      CREATE TABLE sidefx_data.[${name}_source](
        projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
        entity_row_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
        observation_row_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL,
        PRIMARY KEY(entity_row_id,observation_row_id),
        FOREIGN KEY(entity_row_id) REFERENCES sidefx_data.[${name}](row_id),
        FOREIGN KEY(projection_id,observation_row_id) REFERENCES sidefx_observation.[${e.source}](projection_id,row_id)
      );
    END;`);
  }
  result.push(`IF OBJECT_ID('sidefx_data.entity_integrity_finding') IS NULL
    CREATE TABLE sidefx_data.entity_integrity_finding(
      projection_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL REFERENCES sidefx_data.projection_run(projection_id),
      row_id varchar(71) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
      entity_table nvarchar(256) NOT NULL,code nvarchar(256) NOT NULL,subject_key nvarchar(4000) NOT NULL,
      detail_json nvarchar(max) NOT NULL CHECK(ISJSON(detail_json)=1)
    );
    IF COL_LENGTH('sidefx_data.projection_run','entity_manifest_json') IS NULL
      ALTER TABLE sidefx_data.projection_run ADD entity_manifest_json nvarchar(max) NULL;`);
  return result.join('\n');
}
export function entityViews() {
  return Object.entries(ENTITIES).flatMap(([name,e])=>[
    `CREATE OR ALTER VIEW sidefx.[${name}] AS SELECT d.* FROM sidefx_data.[${name}] d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;`,
    `CREATE OR ALTER VIEW sidefx.[${name}_source] AS SELECT l.*,d.artifact_id,d.capability_id AS source_capability_id,d.source_pointer,d.pointer_kind,d.derivation_rule,d.object_digest,a.source_path,a.content_digest,a.capsule_digest,a.authority_digest
     FROM sidefx_data.[${name}_source] l JOIN sidefx_observation.[${e.source}] d ON d.projection_id=l.projection_id AND d.row_id=l.observation_row_id JOIN sidefx_data.artifact a ON a.snapshot_id=d.snapshot_id AND a.artifact_id=d.artifact_id JOIN sidefx_data.current_pointer p ON p.projection_id=l.projection_id;`
  ]).concat([
    `CREATE OR ALTER VIEW sidefx.entity_integrity_finding AS SELECT d.* FROM sidefx_data.entity_integrity_finding d JOIN sidefx_data.current_pointer p ON p.projection_id=d.projection_id;`,
    `CREATE OR ALTER VIEW sidefx.v_entity_integrity AS ${Object.entries(ENTITIES).map(([name,e])=>`SELECT '${name}' AS entity_table,COUNT_BIG(*) AS entity_count,COALESCE(SUM(CASE WHEN ${e.keys.map(k=>`[${k}] IS NULL`).join(' OR ')} THEN 1 ELSE 0 END),0) AS null_key_count,COALESCE(SUM(CASE WHEN resolution_status='CONFLICTING_DECLARATIONS' THEN 1 ELSE 0 END),0) AS conflicting_entity_count FROM sidefx_data.[${name}]`).join(' UNION ALL ')};`
  ]);
}
