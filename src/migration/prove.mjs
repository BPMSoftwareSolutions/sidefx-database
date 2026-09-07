import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {connect,sql} from '../ingest/database.mjs';
import {tables} from './catalog.mjs';
import {bytesDigest} from './data.mjs';
import {fixture,seedSql,insertSql,literal} from './proof-fixture.mjs';

export async function prove(){
 const f=fixture(),{d}=f,seed=seedSql(d),pool=await connect(),results=[];
 const row=(name,patch={},index=0)=>{const n=name.includes('.')?name:'model.'+name,t=tables.get(n),r={...d.rows.get(n)[index],...patch};if(t.identity)delete r[t.pk[0]];return insertSql(n,r);};
 const cases=[];const reject=(name,statement,pattern)=>cases.push({name,statement,pattern});const accept=(name,statement)=>cases.push({name,statement});
 const member=(name,fields,owner=f.bp.semantic_object_definition_pk,ptr='/proof-extra')=>insertSql(name,{...fields,_owner_definition_pk:owner,_canonical_pointer:ptr});
 const lineage=(name,owner,ptr)=>row('source.source_lineage',{semantic_object_definition_pk:owner,member_kind:name,canonical_pointer:ptr});
 try{
  const state=await pool.request().query('SELECT COUNT_BIG(*) n FROM source.content_object');if(Number(state.recordset[0].n))throw new Error('PROOF_REQUIRES_EMPTY_MODEL; all proof data is rolled back');
  for(const family of ['capability','provider','product']){
   reject(family+' null ID',row(family,{[family+'_id']:null}),/515/);reject(family+' null namespace',row(family,{namespace_pk:null}),/515/);
   reject(family+' duplicate identity',row(family),/2601|2627/);reject(family+' whitespace ID',row('semantic_object',{object_kind:family.toUpperCase(),namespace_pk:f[family==='product'?'product':family==='provider'?'provider':'cap'].namespace_pk,declared_id:' bad '}),/547/);
  }
  for(const family of ['capability_version','provider_definition','product_definition'])reject(family+' duplicate exact definition',row(family),/2601|2627/);
  reject('content cannot lie about its digest',row('source.content_object',{content_digest:bytesDigest('wrong-digest'),content_bytes:Buffer.from('different'),byte_length:9}),/547/);
  reject('capability cannot own another capability scenario',row('capability_scenario',{scenario_pk:f.sc2.scenario_pk,scenario_version_pk:f.sc2.scenario_version_pk}),/547/);
  reject('scenario version must match identity',row('capability_scenario',{scenario_pk:f.sc3.scenario_pk,scenario_version_pk:f.sc2.scenario_version_pk}),/547/);
  for(const family of ['scenario_input','scenario_event','scenario_outcome'])reject('duplicate '+family,row(family),/2601|2627/);
  reject('root must belong to capability',member('capability_root_scenario',{capability_version_pk:f.cap.capability_version_pk,scenario_pk:f.sc2.scenario_pk},f.cap.semantic_object_definition_pk),/547/);
  reject('duplicate product establishment',row('outcome_product'),/2601|2627/);
  reject('wrong registry discriminator',row('provider',{provider_id:'different',semantic_object_pk:f.sc.semantic_object_pk,object_kind:'SCENARIO'}),/547/);
  reject('duplicate anonymous operation ordinal',row('execution_operation'),/2601|2627/);
  accept('different anonymous operation ordinal allowed',row('execution_operation',{ordinal:1}));
  reject('operation subtype must match discriminator',member('operation_scenario_invocation',{execution_operation_pk:f.op.execution_operation_pk,operation_kind:'invoke-scenario',target_scenario_version_pk:f.sc.scenario_version_pk},f.ea.semantic_object_definition_pk),/547/);
  reject('cross-transformation expression child',member('transformation_expression_child',{transformation_version_pk:f.tr.transformation_version_pk,parent_node_pk:f.exp.expression_node_pk,child_node_pk:f.exp2.expression_node_pk,member_kind:'OBJECT_MEMBER',member_name:'x',ordinal:null},f.tr.semantic_object_definition_pk),/547/);
  reject('expression literal requires content',row('transformation_expression_node',{node_pointer:'/bad',node_kind:'LITERAL'}),/547/);
  for(const profile of [null,f.profile.provider_profile_version_pk])for(const role of [null,'role']){
   const r={provider_profile_version_pk:profile,role};const first=row('provider_mechanic_implementation',r);reject('duplicate implementation profile='+profile+' role='+role,(profile!==null||role!==null?first:'')+first,/2601|2627/);
  }
  const freshBinding=row('provider_binding_scope',{binding_role:'proof-extra'})+' DECLARE @proof_scope bigint=SCOPE_IDENTITY(); '+row('provider_binding').replace(/VALUES\([^,]+,/, 'VALUES(@proof_scope,')+' DECLARE @proof_binding bigint=SCOPE_IDENTITY(); ';
  reject('binding cannot use another provider implementation',freshBinding+row('binding_mechanic_implementation',{provider_mechanic_implementation_pk:f.implementation2.provider_mechanic_implementation_pk}).replace(/VALUES\([^,]+,/, 'VALUES(@proof_binding,'),/547/);
  reject('binding requirement target must agree',freshBinding+row('binding_mechanic_implementation',{mechanic_version_pk:f.mechanic2.mechanic_version_pk}).replace(/VALUES\([^,]+,/, 'VALUES(@proof_binding,'),/547/);
  reject('slot owner node must share blueprint',row('provider_slot',{slot_id:'foreign',owner_node_pk:f.foreign.blueprint_node_pk}),/547/);
  reject('duplicate slot ID',row('provider_slot'),/2601|2627/);
  reject('second single selection',row('provider_binding',{provider_definition_pk:f.provider2.provider_definition_pk}),/2601|2627/);
  reject('binding policy cannot differ from scope',row('provider_binding',{provider_definition_pk:f.provider2.provider_definition_pk,selection_policy:'ORDERED_SET',ordinal:0}),/547/);
  reject('single selection cannot have ordinal',row('provider_binding_scope',{binding_role:'ordinal-proof'})+' DECLARE @proof_scope bigint=SCOPE_IDENTITY(); '+row('provider_binding',{provider_definition_pk:f.provider2.provider_definition_pk,ordinal:0}).replace(/VALUES\([^,]+,/, 'VALUES(@proof_scope,'),/547/);
  const edge={blueprint_version_pk:f.bp.blueprint_version_pk,edge_id:'edge',from_node_pk:f.n.blueprint_node_pk,to_node_pk:f.n2.blueprint_node_pk,topology_role:'TRANSITION',contract_relation:null,semantic_progress:'ESTABLISHES',source_scenario_version_pk:null,selecting_variant_pk:null,semantic_precedence:'REQUIRED',projection_ordinal:0,binding_authority_definition_pk:f.authority.semantic_object_definition_pk};
  reject('cross-blueprint endpoint',member('blueprint_edge',{...edge,to_node_pk:f.foreign.blueprint_node_pk}),/547/);
  reject('branch requires selecting variant',member('blueprint_edge',{...edge,topology_role:'BRANCH_ROUTE'}),/547/);
  reject('branch variant must belong to source outcome',member('blueprint_edge',{...edge,topology_role:'BRANCH_ROUTE',source_scenario_version_pk:f.sc.scenario_version_pk,selecting_variant_pk:f.variant2.outcome_variant_pk}),/547/);
  reject('descent must declare DESCENDS progress',member('blueprint_edge',{...edge,topology_role:'ALTITUDE_DESCENT'}),/547/);
  reject('convergence must declare REQUIRES relation',member('blueprint_edge',{...edge,topology_role:'CONVERGENCE_REQUIREMENT'}),/547/);
  reject('bounded return must declare its progress',member('blueprint_edge',{...edge,topology_role:'BOUNDED_RETURN'}),/547/);
  reject('lineage cannot point at nonexistent definition',row('source.source_lineage',{semantic_object_definition_pk:99999999}),/547/);
  reject('importer cannot disable constraints','ALTER TABLE model.provider NOCHECK CONSTRAINT ALL;',/229|1088|15247|15151/);
  reject('importer cannot select current model','INSERT source.current_model(singleton_id,estate_model_pk) VALUES(1,1);',/229/);
  reject('importer cannot alter model state',"UPDATE source.estate_model SET publication_state='PUBLISHED' WHERE estate_model_pk=1;",/229/);
  reject('importer cannot rewrite existing identity',"UPDATE model.provider SET provider_id='changed' WHERE provider_pk=1;",/229/);
  reject('importer cannot add migration history',"INSERT source.schema_migration(migration_id,migration_digest) VALUES('fake','fake');",/229/);
  reject('gate rejects missing required operation subtype',row('execution_operation',{ordinal:1,_canonical_pointer:'/new'})+lineage('execution_operation',f.ea.semantic_object_definition_pk,'/new')+'EXEC source.validate_model 1;',/G_EXECUTION_SUBTYPE/);
  reject('gate rejects spoofed child owner',row('execution_operation',{ordinal:1,_owner_definition_pk:f.cap.semantic_object_definition_pk})+'EXEC source.validate_model 1;',/G_OWNER_execution_operation/);
  reject('gate rejects nonexistent lineage member',row('source.source_lineage',{canonical_pointer:'/not-a-member'})+'EXEC source.validate_model 1;',/G_LINEAGE_DANGLING/);
  reject('gate rejects missing fan-out membership',member('blueprint_edge',{...edge,topology_role:'FAN_OUT_MEMBER'})+lineage('blueprint_edge',f.bp.semantic_object_definition_pk,'/proof-extra')+'EXEC source.validate_model 1;',/G_GEOMETRY_REQUIRED_EXTENSION/);
  accept('two contracts share schema bytes',`IF (SELECT COUNT(*) FROM model.contract_version WHERE schema_object_pk=1)<>2 THROW 51999,'SHARED_SCHEMA_FAILED',1;`);
  accept('mechanic slot has no fabricated port',`IF EXISTS(SELECT 1 FROM model.slot_port_requirement) OR NOT EXISTS(SELECT 1 FROM model.slot_mechanic_requirement) THROW 51999,'MECHANIC_SLOT_FAILED',1;`);
  accept('baseline passes all publication gates','EXEC source.validate_model 1;');
  for(const c of cases){const tx=new sql.Transaction(pool);await tx.begin();try{
   await new sql.Request(tx).batch(seed);
   const statement=`SET XACT_ABORT OFF; EXECUTE AS USER='sidefx_importer'; BEGIN TRY EXEC(${literal(c.statement)}); SELECT CAST(NULL AS int) error_number,CAST(NULL AS nvarchar(max)) error_message; END TRY BEGIN CATCH SELECT ERROR_NUMBER() error_number,ERROR_MESSAGE() error_message; IF XACT_STATE()=-1 ROLLBACK; END CATCH; REVERT;`;
    let r;try{r=await new sql.Request(tx).batch(statement);}catch(e){throw new Error(c.name+': '+e.message);}const e=r.recordset?.[0];if(c.pattern){assert.ok(e?.error_number&&c.pattern.test(e.error_number+':'+e.error_message),c.name+': expected '+c.pattern+' got '+JSON.stringify(e));}else assert.equal(e?.error_number,null,c.name+': '+JSON.stringify(e));results.push({test:c.name,status:'PASS',...(e.error_number?{errorNumber:e.error_number}: {})});
  }finally{await tx.rollback().catch(()=>{});}}
  // Reader gets SELECT access to normalized tables, but no mutation permission.
  {const tx=new sql.Transaction(pool);await tx.begin();try{await new sql.Request(tx).batch(seed);const reader=await new sql.Request(tx).batch(`EXECUTE AS USER='sidefx_reader'; SELECT COUNT_BIG(*) n FROM model.capability; REVERT;`);assert.equal(Number(reader.recordset[0].n),2);results.push({test:'reader can query normalized tables',status:'PASS'});}finally{await tx.rollback().catch(()=>{});}}
  // Trigger rejections abort their transaction. Exercise each against an independent seed.
  for(const c of [
   {name:'published definition cannot be changed even by a privileged data writer',statement:"UPDATE model.provider_definition SET name='changed' WHERE provider_definition_pk=1;",match:/IMMUTABLE_INSPECTION_DATA/},
   {name:'published child cannot be appended with a forged owner',statement:row('execution_operation',{ordinal:1,_owner_definition_pk:f.cap2.semantic_object_definition_pk}),match:/PUBLISHED_DEFINITION_IMMUTABLE|PUBLISHED_OWNER_IMMUTABLE/},
   {name:'published content cannot be deleted',statement:'DELETE source.content_object;',match:/547|IMMUTABLE_INSPECTION_DATA/}
  ]){const t=new sql.Transaction(pool);await t.begin();try{await new sql.Request(t).batch(seed);await new sql.Request(t).batch("EXECUTE AS USER='sidefx_importer'; EXEC source.publish_model 1; REVERT;");let caught;try{await new sql.Request(t).batch(c.statement);}catch(e){caught=e;}assert.ok(caught&&c.match.test((caught.number??'')+':'+caught.message),c.name+': '+caught?.message);results.push({test:c.name,status:'PASS'});}finally{await t.rollback().catch(()=>{});}}
  const remain=await pool.request().query('SELECT COUNT_BIG(*) n FROM source.content_object');assert.equal(Number(remain.recordset[0].n),0);
  const report={status:'PROVEN',passed:results.length,results,proofDataRemaining:0};const dir=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../data/migration');await fs.mkdir(dir,{recursive:true});await fs.writeFile(path.join(dir,'sql-proof.json'),JSON.stringify(report,null,2)+'\n');return report;
 }finally{await pool.close();}
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{const r=await prove();console.log(JSON.stringify({status:r.status,passed:r.passed,proofDataRemaining:r.proofDataRemaining},null,2));}catch(e){console.error(JSON.stringify({error:e.message}));process.exitCode=1;}
