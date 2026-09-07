import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeSql } from '../src/query/run.mjs';
import { hash } from '../src/core.mjs';

test('query receipts preserve timestamp and binary values instead of empty objects',()=>{
  const first=normalizeSql({observed:new Date('2026-09-06T12:00:00Z'),bytes:Buffer.from([0,255]),large:9007199254740993n});
  const second=normalizeSql({observed:new Date('2026-09-06T12:00:01Z'),bytes:Buffer.from([0,255]),large:9007199254740993n});
  assert.notEqual(hash(first),hash(second));
  assert.equal(first.observed,'2026-09-06T12:00:00.000Z');
  assert.deepEqual(Buffer.from(first.bytes.base64,'base64'),Buffer.from([0,255]));
  assert.equal(first.large,'9007199254740993');
});
