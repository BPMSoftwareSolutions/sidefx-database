import {tables,families,owned,digest} from './catalog.mjs';

export const bytesDigest=b=>Buffer.from(digest(b),'hex');
export const canonical=value=>{
  if(value===null||typeof value==='boolean'||typeof value==='string')return JSON.stringify(value);
  if(typeof value==='number'){if(!Number.isFinite(value)||Number.isInteger(value)&&!Number.isSafeInteger(value))throw new Error('NON_IJSON_NUMBER');return JSON.stringify(value);}
  if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
  if(value&&Object.getPrototypeOf(value)===Object.prototype)return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
  throw new Error('NON_IJSON_VALUE');
};
// Parse before JSON.parse can discard duplicate member names or round integers.
export function parseJson(bytes){
  const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes);let p=0;
  const ws=()=>{while(/[\t\n\r ]/.test(text[p]??'!'))p++;};
  const string=()=>{const start=p++;while(p<text.length){if(text[p]==='\\'){p+=2;continue;}if(text[p++]==='"'){const v=JSON.parse(text.slice(start,p));if(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(v))throw new Error('NON_IJSON_SURROGATE');return v;}}throw new Error('INVALID_JSON_STRING');};
  const value=()=>{ws();const c=text[p];if(c==='"')return string();if(c==='{'){p++;ws();const out={},seen=new Set();if(text[p]==='}'){p++;return out;}for(;;){ws();if(text[p]!=='"')throw new Error('INVALID_JSON_KEY');const k=string();if(seen.has(k))throw new Error('DUPLICATE_JSON_KEY');seen.add(k);ws();if(text[p++]!==':')throw new Error('INVALID_JSON_COLON');Object.defineProperty(out,k,{value:value(),enumerable:true,configurable:true,writable:true});ws();const sep=text[p++];if(sep==='}')return out;if(sep!==',')throw new Error('INVALID_JSON_OBJECT');}}
    if(c==='['){p++;ws();const out=[];if(text[p]===']'){p++;return out;}for(;;){out.push(value());ws();const sep=text[p++];if(sep===']')return out;if(sep!==',')throw new Error('INVALID_JSON_ARRAY');}}
    const m=/^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(text.slice(p));if(!m)throw new Error('INVALID_JSON_VALUE');p+=m[0].length;const v=JSON.parse(m[0]);canonical(v);return v;
  };const out=value();ws();if(p!==text.length)throw new Error('INVALID_JSON_TRAILING');return out;
}
export const validId=v=>typeof v==='string'&&v.length>0&&v.length<=400&&v.trim()===v;
export const pointer=s=>s.replaceAll('~','~0').replaceAll('/','~1');

export class Dataset {
  constructor(){this.rows=new Map([...tables.keys()].map(n=>[n,[]]));this.memo=new Map();this.sequences=new Map();this.definitions=new Map();this.issues=[];this.contents=new Map();this.memberKeys=new Set();}
  add(name,values,{dedup=false}={}){if(!name.includes('.'))name='model.'+name;const t=tables.get(name);if(!t)throw new Error('UNKNOWN_TABLE:'+name);const row={...values};
    if(t.identity&&t.pk.length===1&&!Object.hasOwn(row,t.pk[0]))row[t.pk[0]]=(this.sequences.get(name)??0)+1;
    const natural=Object.fromEntries(Object.entries(row).filter(([k])=>!t.identity||!t.pk.includes(k)));const mkey=name+':'+canonical(Object.fromEntries(Object.entries(natural).map(([k,v])=>[k,Buffer.isBuffer(v)?v.toString('hex'):v instanceof Date?v.toISOString():v])));
    if(dedup&&this.memo.has(mkey))return this.memo.get(mkey);
    for(const [c,s]of Object.entries(t.columns)){if(row[c]===undefined){if(s.nullable)row[c]=null;else throw new Error('MISSING_COLUMN:'+name+':'+c);}if(row[c]===null&&!s.nullable)throw new Error('NULL_REQUIRED:'+name+':'+c);if(row[c]!==null&&s.token==='ID'&&!validId(row[c]))throw new Error('INVALID_ID:'+name+':'+c);if(row[c]!==null&&s.token==='PTR'&&row[c].length>400)throw new Error('POINTER_TOO_LONG');}
    if(t.identity&&t.pk.length===1)this.sequences.set(name,Math.max(this.sequences.get(name)??0,row[t.pk[0]]));
    this.rows.get(name).push(row);this.memo.set(mkey,row);return row;
  }
  content(bytes){bytes=Buffer.isBuffer(bytes)?bytes:Buffer.from(bytes);const h=digest(bytes);if(this.contents.has(h)){const r=this.contents.get(h);if(!r.content_bytes.equals(bytes))throw new Error('CONTENT_DIGEST_COLLISION');return r;}const r=this.add('source.content_object',{content_digest:Buffer.from(h,'hex'),content_bytes:bytes,byte_length:bytes.length});this.contents.set(h,r);return r;}
  json(value){return this.content(canonical(value));}
  namespace(kind,id,owner=null){if(!validId(id))throw new Error('INVALID_NAMESPACE');const n=this.add('identity_namespace',{namespace_kind:kind,namespace_id:id},{dedup:true});if(owner)this.add('namespace_owner',{namespace_pk:n.namespace_pk,owner_semantic_object_pk:owner.semantic_object_pk,scope_kind:kind},{dedup:true});return n;}
  ownedNamespace(kind,owner){return this.namespace(kind,'owner:sha256:'+digest(canonical(owner.address)),owner);}
  identity(kind,id,namespace,extra={}){if(!validId(id))throw new Error('INVALID_DECLARED_ID:'+kind);const ns=typeof namespace==='string'?this.namespace(kind,namespace):namespace;const r=this.add('semantic_object',{object_kind:kind,namespace_pk:ns.namespace_pk,declared_id:id},{dedup:true});const f=families.find(f=>f.kind===kind);let concrete=null;if(f)concrete=this.add(f.name,{namespace_pk:ns.namespace_pk,[f.idColumn]:id,semantic_object_pk:r.semantic_object_pk,object_kind:kind,...extra},{dedup:true});return {...r,...concrete,address:{kind,namespace:ns.namespace_id,id},ns};}
  definition(identity,semantics,fields={},sources=[],{table:tableName,pk={}}={}){
    const envelope={format:'sidefx-semantic-definition.v1',address:identity.address,semantics};const content=this.json(envelope);const key=identity.semantic_object_pk+':'+content.content_digest.toString('hex');
    let d=this.definitions.get(key);if(!d){const registry=this.add('semantic_object_definition',{semantic_object_pk:identity.semantic_object_pk,object_kind:identity.object_kind,definition_digest:content.content_digest,canonical_content_pk:content.content_object_pk});const f=families.find(f=>f.kind===identity.object_kind);tableName??=f?.version;if(!tableName)throw new Error('DEFINITION_TABLE_REQUIRED');const c={...pk,...(f?{[f.name+'_pk']:identity[f.name+'_pk']}:{namespace_pk:identity.namespace_pk}),semantic_object_pk:identity.semantic_object_pk,semantic_object_definition_pk:registry.semantic_object_definition_pk,object_kind:identity.object_kind,definition_digest:content.content_digest,...fields,_owner_definition_pk:registry.semantic_object_definition_pk,_canonical_pointer:''};const row=this.add(tableName,c);d={...identity,...registry,...row,table:tableName,envelope};this.definitions.set(key,d);this.add('estate_definition',{estate_model_pk:this.model.estate_model_pk,semantic_object_definition_pk:d.semantic_object_definition_pk});}
    this.lineage(d.table,d.semantic_object_definition_pk,'',sources);return d;
  }
  lineage(table,owner,ptr,sources){table=table.split('.').at(-1);for(const s of sources)this.add('source.source_lineage',{semantic_object_definition_pk:owner,member_kind:table,canonical_pointer:ptr,source_observation_pk:s.source_observation_pk,mapping_rule_pk:s.mapping_rule_pk??this.rule.mapping_rule_pk,contribution_role:s.contribution_role??'DECLARATION'},{dedup:true});}
  member(table,fields,owner,ptr,sources){const r=this.add(table,{...fields,_owner_definition_pk:owner.semantic_object_definition_pk,_canonical_pointer:ptr},{dedup:true});this.lineage(table,owner.semantic_object_definition_pk,ptr,sources);return r;}
  observation(appearance,locator,kind='DECLARATION',value=null,extra={}){const r=this.add('source.source_observation',{source_appearance_pk:appearance.source_appearance_pk,locator,locator_digest:bytesDigest(locator),observation_kind:kind,presence_state:value===null?'EXPLICIT_NULL':'PRESENT',observed_value_content_pk:this.json(value).content_object_pk},{dedup:true});if(kind==='DECLARATION')this.add('source.declaration_observation',{source_observation_pk:r.source_observation_pk,observation_kind:kind,declared_kind:extra.kind??'DOCUMENT',declared_id:extra.id??null,namespace_text:extra.namespace??null},{dedup:true});if(kind==='RELATIONSHIP')this.add('source.relationship_observation',{source_observation_pk:r.source_observation_pk,observation_kind:kind,relationship_kind:extra.role??'DECLARED_REFERENCE',source_reference:extra.source??null,target_reference:extra.target??null,declared_target_digest:extra.targetDigest??null},{dedup:true});return {...r,mapping_rule_pk:this.rule.mapping_rule_pk};}
  counts(){return Object.fromEntries([...this.rows].filter(([,r])=>r.length).map(([n,r])=>[n,r.length]));}
}
