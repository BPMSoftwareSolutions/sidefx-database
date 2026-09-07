import test from 'node:test';
import assert from 'node:assert/strict';
import {canonical,parseJson,Dataset,bytesDigest} from '../src/migration/data.mjs';
import {migrationPlan} from '../src/migration/migrate.mjs';

test('canonical identity excludes formatting, retains case, suffix and array order',()=>{
 assert.equal(canonical(parseJson(Buffer.from('{"b":2,"a":1}'))),'{"a":1,"b":2}');
 assert.notEqual(canonical({id:'Port.v1'}),canonical({id:'port.v1'}));
 assert.notEqual(canonical({id:'Port.v1'}),canonical({id:'Port'}));
 assert.notEqual(canonical([1,2]),canonical([2,1]));
});
test('ambiguous JSON and unsafe numeric sources are rejected before normalization',()=>{
 for(const text of ['{"id":"a","id":"b"}','{"a":{"x":1,"x":2}}','{"n":9007199254740993}','{"s":"\\ud800"}','{"a":1} trailing'])assert.throws(()=>parseJson(Buffer.from(text)));
 assert.deepEqual(parseJson(Buffer.from('{"x":null,"a":[true,1.25,"😀"]}')),{x:null,a:[true,1.25,'😀']});
});
test('identity does not merge declared case, namespace or suffix; content has a separate key',()=>{
 const d=new Dataset();const a=d.identity('PROVIDER','tool.v1','providers'),same=d.identity('PROVIDER','tool.v1','providers');
 assert.equal(a.provider_pk,same.provider_pk);
 for(const other of [d.identity('PROVIDER','Tool.v1','providers'),d.identity('PROVIDER','tool','providers'),d.identity('PROVIDER','tool.v1','another')])assert.notEqual(a.provider_pk,other.provider_pk);
 for(const id of [null,'',' tool','tool ','x'.repeat(401)])assert.throws(()=>d.identity('PROVIDER',id,'providers'));
 assert.equal(d.content('same').content_object_pk,d.content('same').content_object_pk);
 assert.notEqual(d.content('same ').content_object_pk,d.content('same').content_object_pk);
});
test('schema generation is deterministic and references only declared candidate keys',()=>{const a=migrationPlan(),b=migrationPlan();assert.equal(a.digest,b.digest);assert.equal(a.tables,124);assert.equal(a.foreignKeys,355);assert.equal(a.views,56);});
