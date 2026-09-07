import { loadSnapshot } from '../snapshot/capture.mjs';
import { readBlob } from '../core.mjs';

export async function inventory() {
  const snap = await loadSnapshot(), groups = new Map(), examples = {};
  const wanted = new Set(['semantic-graph.authority.json','provider-authority.json','provider-slots.authority.json','fixtures.authority.json','runtime.execution-plan.node.v2.json','blueprint.authority.json']);
  for (const a of snap.artifacts.filter(a => a.sourceClass === 'MANAGED_CAPSULE' || a.sourceClass === 'MANAGED_RUNTIME')) {
    if (!a.sourcePath.endsWith('.json')) continue;
    let j; try { j = JSON.parse((await readBlob(a.contentDigest)).toString('utf8')); } catch { continue; }
    const key = a.entryId + ' | ' + Object.keys(j).sort().join(',');
    groups.set(key, (groups.get(key) ?? 0) + 1);
    if (wanted.has(a.entryId) && !examples[a.entryId]) {
      if (a.entryId === 'semantic-graph.authority.json' && !j.transitions?.length) continue;
      const example = {};
      for (const [k,v] of Object.entries(j)) {
        if (Array.isArray(v)) example[k] = v.slice(0,1).map(x => x && typeof x === 'object' ? Object.fromEntries(Object.entries(x).filter(([p]) => !['input','configuration','expected','expression','payload'].includes(p))) : x);
        else if (typeof v !== 'object') example[k] = v;
      }
      examples[a.entryId] = example;
    }
  }
  return { shapes: [...groups].sort((a,b) => b[1]-a[1]), examples };
}
