// Register an authored capability in the selected model as a new generation.
//
// Published membership is immutable: model.estate_capability,
// model.estate_definition and seven sibling tables THROW
// 51003 PUBLISHED_MEMBERSHIP_IMMUTABLE on any insert whose estate_model is
// PUBLISHED. A capability is therefore added by building a NEW estate model,
// carrying the current membership into it, adding the new rows, and publishing:
//
//   new source.estate_model (BUILDING)
//     -> copy model.estate_definition / model.estate_capability
//        / source.estate_model_rule from the current model
//     -> insert the authored capability's source and model rows
//     -> EXEC source.validate_model   (requires BUILDING; runs the lineage gates)
//     -> EXEC source.publish_model    (flips source.current_model)
//
// The registration commits in phases rather than one transaction:
//
//   phase 0  rule + generation record (the BUILDING model becomes visible)
//   phase 1  membership carry
//   phase 2  source layer: content objects, appearances, observations
//   phase 3  model layer: definitions, versions, expression trees, operations,
//            faces, lineage
//   phase 4  validate + publish
//
// Every statement is an idempotent INSERT (or a reuse lookup), so a failed run
// keeps the phases it completed, a re-run converges instead of colliding, and
// each phase is observable as it commits. Nothing here suspends a guard or
// edits a published row.
//
// The promoted shape mirrors normalize.mjs: contracts (catalog + schemas),
// ports (interface bindings), transformations (expression trees), execution
// authorities (operations and their links), then faces carrying resolved
// references. Every definition envelope carries the provisioning manifest
// digest, exactly as normalize.mjs carries authority_manifest_digest, so a
// corrected registration mints new definitions instead of colliding with the
// ones an earlier, incomplete registration left behind. Identity rows are
// deduplicated; definitions are content-addressed and always fresh.
//
// Deterministic: identical inputs produce identical content digests, an
// identical capsule digest, and identical canonical envelopes. Re-registering
// unchanged bytes is refused as ALREADY_REGISTERED rather than duplicated.
import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { connect, sql } from '../ingest/database.mjs';
import { stable } from '../core.mjs';
import { canonical, bytesDigest } from '../migration/data.mjs';
import { packCapability } from './pack.mjs';
import { decodeCapsule } from '../snapshot/capture.mjs';

// Registration is its own mapping rule. normalize.mjs selects MANAGED_CAPSULE
// only, so PROVISIONED_CAPSULE -- a first-class source class the capture
// already produces -- has no normalization lane. This rule supplies one.
const RULE_ID = 'sidefx-capability-provisioning.v1';
const RULE_PROFILE = 'authored-provisioned-capsule.v1';

const sha = bytes => createHash('sha256').update(bytes).digest();
const pointer = key => String(key).replaceAll('~', '~0').replaceAll('/', '~1');

// Canonical envelope for a normalized object, matching the derivation's
// sidefx-semantic-definition.v1 shape. `stable` fixes key order, so the digest
// is a function of meaning rather than of authoring order. The provisioning
// manifest digest rides in the semantics: a changed capsule changes every
// definition derived from it.
const envelope = (kind, id, namespace, semantics, manifestDigest) =>
  Buffer.from(stable({ address: { id, kind, namespace }, format: 'sidefx-semantic-definition.v1',
    semantics: { ...semantics, provisioning_manifest_digest: manifestDigest } }), 'utf8');

async function readTree(dir) {
  const out = [];
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...await readTree(full));
    else out.push(full);
  }
  return out;
}

/**
 * @param {object} spec
 * @param {string} spec.dir            authored capability directory
 * @param {string} spec.featureFile    reviewed .feature for this capability
 * @param {string} spec.capabilityId
 * @param {string} spec.rootScenarioId
 * @param {Array}  spec.scenarios      { scenarioId, inputId, inputContractId, eventId,
 *                                       eventAuthorityId, outcomeId, outcomeContractId,
 *                                       terminalDisposition, responsibility }
 */
export async function planCapability(spec) {
  // One byte path. The capsule is packed, then read back through the estate's
  // own decodeCapsule, and the registered rows come from THAT decode -- never
  // from a second walk of the directory. So the rows written here and the rows a
  // later `capture` produces from the same .sfxcap carry identical bytes,
  // identical entry digests and one capsule digest.
  const packed = await packCapability(spec);
  const decoded = decodeCapsule(packed.bytes, null);

  // capture.mjs records entryRef as source_path and entryId as entry_id.
  const entries = decoded.entries.map(entry => ({
    bytes: entry.bytes,
    entryId: entry.entryId,
    sourcePath: entry.entryRef,
    digest: sha(entry.bytes)
  }));

  return {
    ...spec,
    packed,
    entries,
    containerLocator: `provisioning/${packed.fileName}`,
    // The digest of the capsule file itself, which is what capture stores.
    capsuleDigest: Buffer.from(packed.capsuleDigest.slice('sha256:'.length), 'hex')
  };
}

export async function registerCapabilities(specs, options = {}) {
  const plans = [];
  for (const spec of specs) plans.push(await planCapability(spec));

  const pool = await connect();
  const run = async (text, inputs = {}) => {
    const request = pool.request();
    for (const [name, [type, value]] of Object.entries(inputs)) request.input(name, type, value);
    return request.query(text);
  };
  const scalar = async (text, inputs) => (await run(text, inputs)).recordset?.[0];

  const summary = { generation: null, phases: [], capabilities: [], published: false, validated: false };
  const phase = async (name, work) => {
    const start = performance.now();
    const rows = await work();
    summary.phases.push({ phase: name, milliseconds: Math.round(performance.now() - start), rows });
    return rows;
  };

  const current = await scalar(`SELECT m.estate_model_pk, m.estate_snapshot_pk, m.mapping_manifest_digest
    FROM source.current_model c JOIN source.estate_model m ON m.estate_model_pk = c.estate_model_pk
    WHERE c.singleton_id = 1`);
  if (!current) throw new Error('CURRENT_MODEL_NOT_FOUND');

  for (const plan of plans) {
    if (!options.supersede) {
      const existing = await scalar(
        `SELECT TOP 1 source_appearance_pk FROM source.source_appearance
          WHERE estate_snapshot_pk = @snap AND capsule_digest = @capsule`,
        { snap: [sql.BigInt, current.estate_snapshot_pk], capsule: [sql.VarBinary, plan.capsuleDigest] });
      if (existing) throw new Error('ALREADY_REGISTERED:' + plan.capabilityId);
      const clash = await scalar(
        `SELECT TOP 1 c.capability_pk FROM model.capability c
          JOIN model.estate_capability ec ON ec.capability_pk = c.capability_pk
          WHERE ec.estate_model_pk = @model AND c.capability_id = @id`,
        { model: [sql.BigInt, current.estate_model_pk], id: [sql.NVarChar, plan.capabilityId] });
      if (clash) throw new Error('CAPABILITY_ID_ALREADY_IN_MODEL:' + plan.capabilityId);
    }
  }

  // Content is addressed by digest, so identical bytes are stored once and
  // shared across generations rather than copied.
  const content = async bytes => {
    const digest = sha(bytes);
    await run(`IF NOT EXISTS (SELECT 1 FROM source.content_object WHERE content_digest = @d)
               INSERT source.content_object (content_digest, content_bytes, byte_length) VALUES (@d, @b, @n)`,
      { d: [sql.VarBinary, digest], b: [sql.VarBinary, bytes], n: [sql.BigInt, bytes.length] });
    return (await scalar(`SELECT content_object_pk FROM source.content_object WHERE content_digest = @d`,
      { d: [sql.VarBinary, digest] })).content_object_pk;
  };

  // --- the provisioning mapping rule ----------------------------------------
  const baseRules = (await run(
    `SELECT r.mapping_rule_pk, r.rule_id, r.rule_digest
       FROM source.estate_model_rule mr
       JOIN source.mapping_rule r ON r.mapping_rule_pk = mr.mapping_rule_pk
      WHERE mr.estate_model_pk = @from ORDER BY r.mapping_rule_pk`,
    { from: [sql.BigInt, current.estate_model_pk] })).recordset;
  if (!baseRules.length) throw new Error('BASE_MAPPING_RULE_NOT_FOUND');

  const ruleBytes = Buffer.from(canonical({
    ruleId: RULE_ID,
    profile: RULE_PROFILE,
    canonicalization: 'JCS-IJSON-safe-integers.v1',
    selects: 'PROVISIONED_CAPSULE entries declared in this registration',
    extendsRuleDigests: baseRules.map(r => r.rule_digest.toString('hex')),
    selection: plans.map(p => ({
      capabilityId: p.capabilityId,
      rootScenarioId: p.rootScenarioId,
      capsuleDigest: p.capsuleDigest.toString('hex'),
      containerLocator: p.containerLocator,
      entries: p.entries.map(e => ({ sourcePath: e.sourcePath, digest: e.digest.toString('hex') }))
    }))
  }), 'utf8');
  const manifest = bytesDigest(canonical([
    ...baseRules.map(r => ({ id: r.rule_id, digest: r.rule_digest.toString('hex') })),
    { id: RULE_ID, digest: sha(ruleBytes).toString('hex') }
  ]));

  // --- phase 0: rule + generation record ------------------------------------
  await phase('generation', async () => {
    const ruleContentPk = await content(ruleBytes);
    let rule = (await scalar(
      `SELECT mapping_rule_pk FROM source.mapping_rule WHERE rule_id = @id AND rule_digest = @d`,
      { id: [sql.NVarChar, RULE_ID], d: [sql.VarBinary, sha(ruleBytes)] }))?.mapping_rule_pk;
    if (!rule) {
      rule = (await scalar(
        `INSERT source.mapping_rule (rule_id, rule_digest, source_profile, rule_content_object_pk, canonicalization_profile)
         VALUES (@id, @d, @p, @c, @cz); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS mapping_rule_pk`,
        { id: [sql.NVarChar, RULE_ID], d: [sql.VarBinary, sha(ruleBytes)], p: [sql.NVarChar, RULE_PROFILE],
          c: [sql.BigInt, ruleContentPk], cz: [sql.NVarChar, 'JCS-IJSON-safe-integers.v1'] })).mapping_rule_pk;
    }
    let model = (await scalar(
      `SELECT estate_model_pk FROM source.estate_model
        WHERE estate_snapshot_pk = @snap AND mapping_manifest_digest = @manifest`,
      { snap: [sql.BigInt, current.estate_snapshot_pk], manifest: [sql.VarBinary, manifest] }))?.estate_model_pk;
    if (!model) {
      model = (await scalar(
        `INSERT source.estate_model (estate_snapshot_pk, mapping_manifest_digest, publication_state)
         VALUES (@snap, @manifest, 'BUILDING'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS estate_model_pk`,
        { snap: [sql.BigInt, current.estate_snapshot_pk], manifest: [sql.VarBinary, manifest] })).estate_model_pk;
    }
    summary.generation = {
      from: Number(current.estate_model_pk), to: Number(model),
      snapshot: Number(current.estate_snapshot_pk), rule: RULE_ID,
      ruleDigest: 'sha256:' + sha(ruleBytes).toString('hex'),
      manifestDigest: 'sha256:' + manifest.toString('hex')
    };
    return { model, rule };
  });
  const model = summary.generation.to;
  const rule = (await scalar(`SELECT mapping_rule_pk FROM source.mapping_rule WHERE rule_id = @id AND rule_digest = @d`,
    { id: [sql.NVarChar, RULE_ID], d: [sql.VarBinary, sha(ruleBytes)] })).mapping_rule_pk;

  // --- phase 1: membership carry (idempotent, supersede excludes) -----------
  await phase('membership-carry', async () => {
    let supersededIds = '[]';
    let supersededSods = '[]';
    if (options.supersede) {
      const superseded = [];
      for (const plan of plans) {
        const pk = (await scalar(
          `SELECT c.capability_pk FROM model.capability c
            JOIN model.identity_namespace n ON n.namespace_pk = c.namespace_pk
           WHERE n.namespace_id = N'sidefx:capabilities' AND c.capability_id = @id`,
          { id: [sql.NVarChar, plan.capabilityId] }))?.capability_pk;
        if (pk) superseded.push(pk);
      }
      supersededIds = JSON.stringify(superseded);
      if (superseded.length) {
        const rows = (await run(
          `SELECT cv.semantic_object_definition_pk
             FROM model.estate_capability ec
             JOIN model.capability_version cv ON cv.capability_version_pk = ec.capability_version_pk
            WHERE ec.estate_model_pk = @from AND ec.capability_pk IN (SELECT value FROM OPENJSON(@ids))
            UNION SELECT sv.semantic_object_definition_pk
             FROM model.estate_capability ec
             JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
             JOIN model.scenario_version sv ON sv.scenario_version_pk = cs.scenario_version_pk
            WHERE ec.estate_model_pk = @from AND ec.capability_pk IN (SELECT value FROM OPENJSON(@ids))
            UNION SELECT f.semantic_object_definition_pk
             FROM model.estate_capability ec
             JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
             JOIN model.scenario_input f ON f.scenario_version_pk = cs.scenario_version_pk
            WHERE ec.estate_model_pk = @from AND ec.capability_pk IN (SELECT value FROM OPENJSON(@ids))
            UNION SELECT f.semantic_object_definition_pk
             FROM model.estate_capability ec
             JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
             JOIN model.scenario_event f ON f.scenario_version_pk = cs.scenario_version_pk
            WHERE ec.estate_model_pk = @from AND ec.capability_pk IN (SELECT value FROM OPENJSON(@ids))
            UNION SELECT f.semantic_object_definition_pk
             FROM model.estate_capability ec
             JOIN model.capability_scenario cs ON cs.capability_version_pk = ec.capability_version_pk
             JOIN model.scenario_outcome f ON f.scenario_version_pk = cs.scenario_version_pk
            WHERE ec.estate_model_pk = @from AND ec.capability_pk IN (SELECT value FROM OPENJSON(@ids))`,
          { from: [sql.BigInt, current.estate_model_pk], ids: [sql.NVarChar, supersededIds] })).recordset;
        supersededSods = JSON.stringify(rows.map(r => Number(r.semantic_object_definition_pk)));
      }
    }
    const carry = { model: [sql.BigInt, model], from: [sql.BigInt, current.estate_model_pk],
      ids: [sql.NVarChar, supersededIds], sods: [sql.NVarChar, supersededSods] };
    const ed = await run(`INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
               SELECT @model, ed.semantic_object_definition_pk FROM model.estate_definition ed
               WHERE ed.estate_model_pk = @from
                 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@sods) WHERE value = ed.semantic_object_definition_pk)
                 AND NOT EXISTS (SELECT 1 FROM model.estate_definition e2
                                  WHERE e2.estate_model_pk = @model AND e2.semantic_object_definition_pk = ed.semantic_object_definition_pk)`, carry);
    const ec = await run(`INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
               SELECT @model, ec.capability_pk, ec.capability_version_pk, ec.semantic_object_definition_pk
               FROM model.estate_capability ec
               WHERE ec.estate_model_pk = @from
                 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ids) WHERE value = ec.capability_pk)
                 AND NOT EXISTS (SELECT 1 FROM model.estate_capability e2
                                  WHERE e2.estate_model_pk = @model AND e2.capability_pk = ec.capability_pk)`, carry);
    const mr = await run(`INSERT source.estate_model_rule (estate_model_pk, mapping_rule_pk)
               SELECT @model, emr.mapping_rule_pk FROM source.estate_model_rule emr
               WHERE emr.estate_model_pk = @from
                 AND NOT EXISTS (SELECT 1 FROM source.estate_model_rule e2
                                  WHERE e2.estate_model_pk = @model AND e2.mapping_rule_pk = emr.mapping_rule_pk)`, carry);
    await run(`IF NOT EXISTS (SELECT 1 FROM source.estate_model_rule WHERE estate_model_pk = @model AND mapping_rule_pk = @rule)
               INSERT source.estate_model_rule (estate_model_pk, mapping_rule_pk) VALUES (@model, @rule)`,
      { model: [sql.BigInt, model], rule: [sql.BigInt, rule] });
    return { estateDefinitionRows: ed.rowsAffected[0], estateCapabilityRows: ec.rowsAffected[0],
      carriedRules: mr.rowsAffected[0] };
  });

  const ns = (await scalar(`SELECT namespace_pk FROM model.identity_namespace WHERE namespace_id = N'sidefx:capabilities'`)).namespace_pk;

  // AK_model_semantic_object is (namespace_pk, declared_id) with no object_kind,
  // so a capability and its like-named root scenario collide in one namespace.
  // normalize.mjs avoids this with owned namespaces keyed by the digest of the
  // owner's address.
  const ownedNamespace = async (kind, ownerAddress, ownerSemanticObjectPk) => {
    const namespaceId = 'owner:sha256:' + createHash('sha256').update(canonical(ownerAddress)).digest('hex');
    await run(`IF NOT EXISTS (SELECT 1 FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id)
               INSERT model.identity_namespace (namespace_kind, namespace_id) VALUES (@k, @id)`,
      { k: [sql.VarChar, kind], id: [sql.NVarChar, namespaceId] });
    const row = await scalar(`SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id`,
      { k: [sql.VarChar, kind], id: [sql.NVarChar, namespaceId] });
    await run(`IF NOT EXISTS (SELECT 1 FROM model.namespace_owner
                               WHERE namespace_pk = @n AND owner_semantic_object_pk = @o AND scope_kind = @k)
               INSERT model.namespace_owner (namespace_pk, owner_semantic_object_pk, scope_kind)
               VALUES (@n, @o, @k)`,
      { n: [sql.BigInt, row.namespace_pk], o: [sql.BigInt, ownerSemanticObjectPk], k: [sql.VarChar, kind] });
    return { namespacePk: row.namespace_pk, namespaceId };
  };

  const scopedNamespace = async kind => {
    const id = 'sidefx:capability:' + plans[0].capabilityId;
    await run(`IF NOT EXISTS (SELECT 1 FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id)
               INSERT model.identity_namespace (namespace_kind, namespace_id) VALUES (@k, @id)`,
      { k: [sql.VarChar, kind], id: [sql.NVarChar, id] });
    const row = await scalar(`SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id`,
      { k: [sql.VarChar, kind], id: [sql.NVarChar, id] });
    return { namespacePk: row.namespace_pk, namespaceId: id };
  };

  // G_LINEAGE_MEMBER: every normalized member must trace to an observation
  // under a rule this model declares, matched on owner definition, member
  // kind and canonical pointer.
  const lineage = async (ownerSod, memberKind, ptr, observationPk) =>
    run(`INSERT source.source_lineage (semantic_object_definition_pk, member_kind, canonical_pointer,
           source_observation_pk, mapping_rule_pk, contribution_role)
         SELECT @d, @k, @p, @o, @r, 'DECLARATION'
         WHERE NOT EXISTS (SELECT 1 FROM source.source_lineage l2
                            WHERE l2.semantic_object_definition_pk = @d AND l2.member_kind = @k
                              AND l2.canonical_pointer = @p AND l2.source_observation_pk = @o
                              AND l2.mapping_rule_pk = @r)`,
      { d: [sql.BigInt, ownerSod], k: [sql.VarChar, memberKind], p: [sql.NVarChar, ptr],
        o: [sql.BigInt, observationPk], r: [sql.BigInt, rule] });

  // Identity rows are keyed by declared id and shared across generations;
  // definitions are content-addressed and minted fresh per capsule revision.
  const define = async (kind, declaredId, semantics, namespacePk = ns, namespaceId = 'sidefx:capabilities', manifestHex) => {
    const bytes = envelope(kind, declaredId, namespaceId, semantics, manifestHex);
    let so = (await scalar(
      `SELECT semantic_object_pk FROM model.semantic_object WHERE object_kind = @k AND namespace_pk = @ns AND declared_id = @id`,
      { k: [sql.VarChar, kind], ns: [sql.BigInt, namespacePk], id: [sql.NVarChar, declaredId] }))?.semantic_object_pk;
    if (!so) {
      so = (await scalar(
        `INSERT model.semantic_object (object_kind, namespace_pk, declared_id)
         VALUES (@k, @ns, @id); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS semantic_object_pk`,
        { k: [sql.VarChar, kind], ns: [sql.BigInt, namespacePk], id: [sql.NVarChar, declaredId] })).semantic_object_pk;
    }
    let sod = (await scalar(
      `SELECT semantic_object_definition_pk FROM model.semantic_object_definition
        WHERE semantic_object_pk = @so AND definition_digest = @d`,
      { so: [sql.BigInt, so], d: [sql.VarBinary, sha(bytes)] }))?.semantic_object_definition_pk;
    if (!sod) {
      const contentPk = await content(bytes);
      sod = (await scalar(
        `INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
         VALUES (@so, @k, @d, @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS semantic_object_definition_pk`,
        { so: [sql.BigInt, so], k: [sql.VarChar, kind], d: [sql.VarBinary, sha(bytes)], c: [sql.BigInt, contentPk] })).semantic_object_definition_pk;
    }
    await run(`IF NOT EXISTS (SELECT 1 FROM model.estate_definition WHERE estate_model_pk = @m AND semantic_object_definition_pk = @d)
               INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk) VALUES (@m, @d)`,
      { m: [sql.BigInt, model], d: [sql.BigInt, sod] });
    return { so, sod, digest: sha(bytes) };
  };

  // --- phase 2 + 3: source layer and model layer, per capability ------------
  for (const plan of plans) {
    const manifestHex = plan.capsuleDigest.toString('hex');

    // --- source layer -------------------------------------------------------
    await phase('source-layer:' + plan.capabilityId, async () => {
      const entries = new Map();
      let observation = null;
      for (const entry of plan.entries) {
        const contentPk = await content(entry.bytes);
        const appearanceDigest = sha(Buffer.from(
          `${plan.capsuleDigest.toString('hex')}:${entry.sourcePath}:${entry.digest.toString('hex')}`, 'utf8'));
        let appearance = (await scalar(
          `SELECT source_appearance_pk FROM source.source_appearance
            WHERE estate_snapshot_pk = @snap AND capsule_digest = @capsule AND source_path = @sp`,
          { snap: [sql.BigInt, current.estate_snapshot_pk], capsule: [sql.VarBinary, plan.capsuleDigest],
            sp: [sql.NVarChar, entry.sourcePath] }))?.source_appearance_pk;
        if (!appearance) {
          appearance = (await scalar(
            `INSERT source.source_appearance (estate_snapshot_pk, content_object_pk, appearance_digest,
               source_path, source_class, container_locator, capsule_digest, entry_id)
             VALUES (@snap, @c, @ad, @sp, 'PROVISIONED_CAPSULE', @loc, @capsule, @eid); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS source_appearance_pk`,
            { snap: [sql.BigInt, current.estate_snapshot_pk], c: [sql.BigInt, contentPk],
              ad: [sql.VarBinary, appearanceDigest], sp: [sql.NVarChar, entry.sourcePath],
              loc: [sql.NVarChar, plan.containerLocator],
              capsule: [sql.VarBinary, plan.capsuleDigest], eid: [sql.NVarChar, entry.entryId] })).source_appearance_pk;
        }
        entries.set(entry.entryId, { ...entry, contentPk, appearance });
        if (entry.entryId === 'capability.authority.json') {
          observation = (await scalar(
            `SELECT source_observation_pk FROM source.source_observation
              WHERE source_appearance_pk = @a AND locator = N'' AND observation_kind = 'DECLARATION'`,
            { a: [sql.BigInt, appearance] }))?.source_observation_pk;
          if (!observation) {
            observation = (await scalar(
              `INSERT source.source_observation (source_appearance_pk, locator, locator_digest,
                 observation_kind, presence_state, observed_value_content_pk)
               VALUES (@a, N'', @ld, 'DECLARATION', 'PRESENT', @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS source_observation_pk`,
              { a: [sql.BigInt, appearance], ld: [sql.VarBinary, sha(Buffer.from('', 'utf8'))],
                c: [sql.BigInt, contentPk] })).source_observation_pk;
          }
          await run(`IF NOT EXISTS (SELECT 1 FROM source.declaration_observation WHERE source_observation_pk = @o)
                     INSERT source.declaration_observation (source_observation_pk, declared_kind, declared_id, namespace_text, observation_kind)
                     VALUES (@o, 'CAPABILITY', @id, @nsText, 'DECLARATION')`,
            { o: [sql.BigInt, observation], id: [sql.NVarChar, plan.capabilityId],
              nsText: [sql.NVarChar, 'sidefx:capabilities'] });
        }
      }
      if (!observation) throw new Error('CAPABILITY_AUTHORITY_ENTRY_MISSING:' + plan.capabilityId);
      plan._entries = entries;
      plan._observation = observation;
      return { appearances: plan.entries.length };
    });
    const entries = plan._entries;
    const observation = plan._observation;

    const json = async entryId => {
      const entry = entries.get(entryId);
      if (!entry) return null;
      try { return JSON.parse(entry.bytes.toString('utf8')); }
      catch { return null; }
    };
    const declaration = async (entry, kind, id, locator, namespaceText) => {
      const appearance = entries.get(entry).appearance;
      const locatorDigest = sha(Buffer.from(locator, 'utf8'));
      let observed = (await scalar(
        `SELECT source_observation_pk FROM source.source_observation
          WHERE source_appearance_pk = @a AND locator = @loc AND observation_kind = 'DECLARATION'`,
        { a: [sql.BigInt, appearance], loc: [sql.NVarChar, locator] }))?.source_observation_pk;
      if (!observed) {
        observed = (await scalar(
          `INSERT source.source_observation (source_appearance_pk, locator, locator_digest,
             observation_kind, presence_state, observed_value_content_pk)
           VALUES (@a, @loc, @ld, 'DECLARATION', 'PRESENT', @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS source_observation_pk`,
          { a: [sql.BigInt, appearance], loc: [sql.NVarChar, locator],
            ld: [sql.VarBinary, locatorDigest],
            c: [sql.BigInt, entries.get(entry).contentPk] })).source_observation_pk;
      }
      await run(`IF NOT EXISTS (SELECT 1 FROM source.declaration_observation WHERE source_observation_pk = @o)
                 INSERT source.declaration_observation (source_observation_pk, declared_kind, declared_id, namespace_text, observation_kind)
                 VALUES (@o, @k, @id, @ns, 'DECLARATION')`,
        { o: [sql.BigInt, observed], k: [sql.VarChar, kind], id: [sql.NVarChar, id],
          ns: [sql.NVarChar, namespaceText ?? 'sidefx:capabilities'] });
      return observed;
    };

    // --- capability ---------------------------------------------------------
    await phase('model-layer:' + plan.capabilityId, async () => {
      const authority = JSON.parse(entries.get('capability.authority.json').bytes.toString('utf8'));
      const cap = await define('CAPABILITY', plan.capabilityId, authority, ns, 'sidefx:capabilities', manifestHex);
      let capPk = (await scalar(
        `SELECT capability_pk FROM model.capability WHERE namespace_pk = @ns AND capability_id = @id`,
        { ns: [sql.BigInt, ns], id: [sql.NVarChar, plan.capabilityId] }))?.capability_pk;
      if (!capPk) {
        capPk = (await scalar(
          `INSERT model.capability (namespace_pk, capability_id, semantic_object_pk, object_kind)
           VALUES (@ns, @id, @so, 'CAPABILITY'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS capability_pk`,
          { ns: [sql.BigInt, ns], id: [sql.NVarChar, plan.capabilityId], so: [sql.BigInt, cap.so] })).capability_pk;
      }
      let capVer = (await scalar(
        `SELECT capability_version_pk FROM model.capability_version WHERE capability_pk = @c AND definition_digest = @d`,
        { c: [sql.BigInt, capPk], d: [sql.VarBinary, cap.digest] }))?.capability_version_pk;
      if (!capVer) {
        capVer = (await scalar(
          `INSERT model.capability_version (capability_pk, semantic_object_pk, semantic_object_definition_pk,
             definition_digest, name, object_kind, _owner_definition_pk, _canonical_pointer)
           VALUES (@c, @so, @sod, @d, @n, 'CAPABILITY', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS capability_version_pk`,
          { c: [sql.BigInt, capPk], so: [sql.BigInt, cap.so], sod: [sql.BigInt, cap.sod],
            d: [sql.VarBinary, cap.digest], n: [sql.NVarChar, authority.name ?? plan.capabilityId] })).capability_version_pk;
      }
      await run(`IF NOT EXISTS (SELECT 1 FROM model.estate_capability WHERE estate_model_pk = @m AND capability_pk = @c)
                 INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
                 VALUES (@m, @c, @v, @d)`,
        { m: [sql.BigInt, model], c: [sql.BigInt, capPk], v: [sql.BigInt, capVer], d: [sql.BigInt, cap.sod] });
      await lineage(cap.sod, 'capability_version', '', observation);

      // --- contracts: catalog + schemas -------------------------------------
      const contracts = new Map();
      const catalogJson = await json('contracts/contract-catalog.json');
      if (catalogJson && typeof catalogJson === 'object' && !Array.isArray(catalogJson)) {
        for (const [id, locator] of Object.entries(catalogJson)) {
          if (typeof locator !== 'string') throw new Error('CONTRACT_CATALOG_LOCATOR_REQUIRED:' + id);
          const schemaEntry = entries.get('contracts/' + locator);
          if (!schemaEntry) throw new Error('CONTRACT_SCHEMA_ENTRY_MISSING:' + locator);
          const schemaJson = await json('contracts/' + locator);
          if (!schemaJson) throw new Error('CONTRACT_SCHEMA_INVALID_JSON:' + locator);
          let schemaPk = (await scalar(
            `SELECT schema_object_pk FROM model.schema_object WHERE content_digest = @d`,
            { d: [sql.VarBinary, sha(schemaEntry.bytes)] }))?.schema_object_pk;
          if (!schemaPk) {
            schemaPk = (await scalar(
              `INSERT model.schema_object (content_digest, dialect, content_object_pk)
               VALUES (@d, @dialect, @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS schema_object_pk`,
              { d: [sql.VarBinary, sha(schemaEntry.bytes)],
                dialect: [sql.NVarChar, schemaJson.$schema ?? null],
                c: [sql.BigInt, schemaEntry.contentPk] })).schema_object_pk;
          }
          const scope = await scopedNamespace('CONTRACT');
          const def = await define('CONTRACT', id,
            { schema_digest: sha(schemaEntry.bytes).toString('hex') },
            scope.namespacePk, scope.namespaceId, manifestHex);
          let contractPk = (await scalar(
            `SELECT contract_pk FROM model.contract WHERE namespace_pk = @ns AND contract_id = @id`,
            { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, id] }))?.contract_pk;
          if (!contractPk) {
            contractPk = (await scalar(
              `INSERT model.contract (namespace_pk, contract_id, semantic_object_pk, object_kind)
               VALUES (@ns, @id, @so, 'CONTRACT'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS contract_pk`,
              { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, id], so: [sql.BigInt, def.so] })).contract_pk;
          }
          let contractVer = (await scalar(
            `SELECT contract_version_pk FROM model.contract_version WHERE contract_pk = @c AND definition_digest = @d`,
            { c: [sql.BigInt, contractPk], d: [sql.VarBinary, def.digest] }))?.contract_version_pk;
          if (!contractVer) {
            contractVer = (await scalar(
              `INSERT model.contract_version (contract_pk, semantic_object_pk, semantic_object_definition_pk,
                 definition_digest, name, contract_kind, schema_object_pk, schema_reference_state, object_kind,
                 _owner_definition_pk, _canonical_pointer)
               VALUES (@c, @so, @sod, @d, @n, NULL, @sch, 'RESOLVED', 'CONTRACT', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS contract_version_pk`,
              { c: [sql.BigInt, contractPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
                d: [sql.VarBinary, def.digest], n: [sql.NVarChar, schemaJson.title ?? null],
                sch: [sql.BigInt, schemaPk] })).contract_version_pk;
          }
          await lineage(def.sod, 'contract_version', '', observation);
          contracts.set(id, { ...def, contractPk, contractVer });
        }
      }

      // --- ports: interface bindings ----------------------------------------
      const ports = new Map();
      const interfacesJson = await json('interfaces.authority.json');
      for (const [i, binding] of (interfacesJson?.portBindings ?? []).entries()) {
        const portId = binding.portId;
        if (typeof portId !== 'string' || !portId.length) throw new Error('PORT_ID_REQUIRED:' + i);
        const scope = await scopedNamespace('PORT');
        const def = await define('PORT', portId, binding, scope.namespacePk, scope.namespaceId, manifestHex);
        let portPk = (await scalar(
          `SELECT port_pk FROM model.port WHERE namespace_pk = @ns AND port_id = @id`,
          { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, portId] }))?.port_pk;
        if (!portPk) {
          portPk = (await scalar(
            `INSERT model.port (namespace_pk, port_id, semantic_object_pk, object_kind)
             VALUES (@ns, @id, @so, 'PORT'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS port_pk`,
            { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, portId], so: [sql.BigInt, def.so] })).port_pk;
        }
        let portVer = (await scalar(
          `SELECT port_version_pk FROM model.port_version WHERE port_pk = @p AND definition_digest = @d`,
          { p: [sql.BigInt, portPk], d: [sql.VarBinary, def.digest] }))?.port_version_pk;
        if (!portVer) {
          portVer = (await scalar(
            `INSERT model.port_version (port_pk, semantic_object_pk, semantic_object_definition_pk,
               definition_digest, name, port_profile, object_kind, _owner_definition_pk, _canonical_pointer)
             VALUES (@p, @so, @sod, @d, NULL, 'consumer-interface-authority.v1', 'PORT', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS port_version_pk`,
            { p: [sql.BigInt, portPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
              d: [sql.VarBinary, def.digest] })).port_version_pk;
        }
        await lineage(def.sod, 'port_version', '', observation);
        ports.set(portId, { ...def, portPk, portVer });
      }

      // --- transformations: expression trees --------------------------------
      const transforms = new Map();
      const taJson = await json('semantic-transformation.authority.json');
      for (const [i, t] of (taJson?.transformations ?? []).entries()) {
        if (typeof t.id !== 'string' || !Object.hasOwn(t, 'expression')) throw new Error('TRANSFORMATION_SHAPE_REQUIRED:' + i);
        const scope = await scopedNamespace('TRANSFORMATION');
        const tObservation = await declaration('semantic-transformation.authority.json', 'TRANSFORMATION', t.id,
          '/transformations/' + i, scope.namespaceId);
        const def = await define('TRANSFORMATION', t.id, { id: t.id, expression: t.expression },
          scope.namespacePk, scope.namespaceId, manifestHex);
        let tPk = (await scalar(
          `SELECT transformation_pk FROM model.transformation WHERE namespace_pk = @ns AND transformation_id = @id`,
          { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, t.id] }))?.transformation_pk;
        if (!tPk) {
          tPk = (await scalar(
            `INSERT model.transformation (namespace_pk, transformation_id, semantic_object_pk, object_kind)
             VALUES (@ns, @id, @so, 'TRANSFORMATION'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS transformation_pk`,
            { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, t.id], so: [sql.BigInt, def.so] })).transformation_pk;
        }
        let tVer = (await scalar(
          `SELECT transformation_version_pk FROM model.transformation_version WHERE transformation_pk = @t AND definition_digest = @d`,
          { t: [sql.BigInt, tPk], d: [sql.VarBinary, def.digest] }))?.transformation_version_pk;
        if (!tVer) {
          tVer = (await scalar(
            `INSERT model.transformation_version (transformation_pk, semantic_object_pk, semantic_object_definition_pk,
               definition_digest, expression_profile, object_kind, _owner_definition_pk, _canonical_pointer)
             VALUES (@t, @so, @sod, @d, 'json-expression-tree.v1', 'TRANSFORMATION', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS transformation_version_pk`,
            { t: [sql.BigInt, tPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
              d: [sql.VarBinary, def.digest] })).transformation_version_pk;
        }
        await lineage(def.sod, 'transformation_version', '', tObservation);

        const visit = async (value, ptr) => {
          const kind = Array.isArray(value) ? 'ARRAY' : (value && typeof value === 'object') ? 'OBJECT' : 'LITERAL';
          const literalPk = kind === 'LITERAL' ? await content(Buffer.from(JSON.stringify(value), 'utf8')) : null;
          let node = (await scalar(
            `SELECT expression_node_pk FROM model.transformation_expression_node
              WHERE transformation_version_pk = @tv AND node_pointer = @ptr`,
            { tv: [sql.BigInt, tVer], ptr: [sql.NVarChar, ptr] }))?.expression_node_pk;
          if (!node) {
            node = (await scalar(
              `INSERT model.transformation_expression_node (transformation_version_pk, node_pointer, node_kind,
                 operator, literal_content_pk, reference_name, _owner_definition_pk, _canonical_pointer)
               VALUES (@tv, @ptr, @kind, NULL, @lit, NULL, @owner, @ptr); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS expression_node_pk`,
              { tv: [sql.BigInt, tVer], ptr: [sql.NVarChar, ptr], kind: [sql.VarChar, kind],
                lit: [sql.BigInt, literalPk], owner: [sql.BigInt, def.sod] })).expression_node_pk;
          }
          await lineage(def.sod, 'transformation_expression_node', ptr, tObservation);
          if (kind === 'OBJECT' || kind === 'ARRAY') {
            for (const [k, x] of Object.entries(value)) {
              const childPtr = ptr + '/' + pointer(k);
              const child = await visit(x, childPtr);
              const mk = kind === 'ARRAY' ? 'ARRAY_MEMBER' : 'OBJECT_MEMBER';
              const existingChild = await scalar(
                `SELECT child_node_pk FROM model.transformation_expression_child
                  WHERE parent_node_pk = @p AND member_kind = @mk
                    AND (member_name = @mn OR ordinal = @ord)`,
                { p: [sql.BigInt, node], mk: [sql.VarChar, mk],
                  mn: [sql.NVarChar, kind === 'OBJECT' ? k : null], ord: [sql.Int, kind === 'ARRAY' ? Number(k) : null] });
              if (!existingChild) {
                await run(`INSERT model.transformation_expression_child (transformation_version_pk, parent_node_pk, child_node_pk,
                             member_kind, member_name, ordinal, _owner_definition_pk, _canonical_pointer)
                           VALUES (@tv, @parent, @child, @mk, @mn, @ord, @owner, @ptr)`,
                  { tv: [sql.BigInt, tVer], parent: [sql.BigInt, node], child: [sql.BigInt, child],
                    mk: [sql.VarChar, mk],
                    mn: [sql.NVarChar, kind === 'OBJECT' ? k : null], ord: [sql.Int, kind === 'ARRAY' ? Number(k) : null],
                    owner: [sql.BigInt, def.sod], ptr: [sql.NVarChar, childPtr] });
              }
              await lineage(def.sod, 'transformation_expression_child', childPtr, tObservation);
            }
          }
          return node;
        };
        const rootNode = await visit(t.expression, '/semantics/expression');
        await run(`IF NOT EXISTS (SELECT 1 FROM model.transformation_root WHERE transformation_version_pk = @tv)
                   INSERT model.transformation_root (transformation_version_pk, expression_node_pk, _owner_definition_pk, _canonical_pointer)
                   VALUES (@tv, @n, @owner, N'/semantics/expression')`,
          { tv: [sql.BigInt, tVer], n: [sql.BigInt, rootNode], owner: [sql.BigInt, def.sod] });
        await lineage(def.sod, 'transformation_root', '/semantics/expression', tObservation);
        transforms.set(t.id, { ...def, tPk, tVer });
      }

      // --- scenario identity -------------------------------------------------
      for (const s of plan.scenarios) {
        const scenarioNs = await ownedNamespace('SCENARIO',
          { id: plan.capabilityId, kind: 'CAPABILITY', namespace: 'sidefx:capabilities' }, cap.so);
        const scn = await define('SCENARIO', s.scenarioId,
          { scenarioId: s.scenarioId, capabilityId: plan.capabilityId, input: s.inputId, event: s.eventId, outcome: s.outcomeId },
          scenarioNs.namespacePk, scenarioNs.namespaceId, manifestHex);
        let scnPk = (await scalar(
          `SELECT scenario_pk FROM model.scenario WHERE capability_pk = @c AND scenario_id = @id`,
          { c: [sql.BigInt, capPk], id: [sql.NVarChar, s.scenarioId] }))?.scenario_pk;
        if (!scnPk) {
          scnPk = (await scalar(
            `INSERT model.scenario (namespace_pk, scenario_id, semantic_object_pk, object_kind, capability_pk)
             VALUES (@ns, @id, @so, 'SCENARIO', @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS scenario_pk`,
            { ns: [sql.BigInt, scenarioNs.namespacePk], id: [sql.NVarChar, s.scenarioId], so: [sql.BigInt, scn.so], c: [sql.BigInt, capPk] })).scenario_pk;
        }
        let scnVer = (await scalar(
          `SELECT scenario_version_pk FROM model.scenario_version WHERE scenario_pk = @s AND definition_digest = @d`,
          { s: [sql.BigInt, scnPk], d: [sql.VarBinary, scn.digest] }))?.scenario_version_pk;
        if (!scnVer) {
          scnVer = (await scalar(
            `INSERT model.scenario_version (scenario_pk, semantic_object_pk, semantic_object_definition_pk,
               definition_digest, name, source_profile, object_kind, _owner_definition_pk, _canonical_pointer)
             VALUES (@s, @so, @sod, @d, @n, N'managed-feature-tags.v1', 'SCENARIO', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS scenario_version_pk`,
            { s: [sql.BigInt, scnPk], so: [sql.BigInt, scn.so], sod: [sql.BigInt, scn.sod],
              d: [sql.VarBinary, scn.digest], n: [sql.NVarChar, s.scenarioId] })).scenario_version_pk;
        }
        await lineage(scn.sod, 'scenario_version', '', observation);
        await run(`IF NOT EXISTS (SELECT 1 FROM model.capability_scenario WHERE capability_version_pk = @v AND scenario_version_pk = @sv)
                   INSERT model.capability_scenario (capability_pk, capability_version_pk, scenario_pk, scenario_version_pk, _owner_definition_pk, _canonical_pointer)
                   VALUES (@c, @v, @s, @sv, @sod, @ptr)`,
          { c: [sql.BigInt, capPk], v: [sql.BigInt, capVer], s: [sql.BigInt, scnPk], sv: [sql.BigInt, scnVer], sod: [sql.BigInt, cap.sod], ptr: [sql.NVarChar, `/semantics/scenario_members/${s.scenarioId}`] });
        await lineage(cap.sod, 'capability_scenario', `/semantics/scenario_members/${s.scenarioId}`, observation);
        if (s.scenarioId === plan.rootScenarioId) {
          await run(`IF NOT EXISTS (SELECT 1 FROM model.capability_root_scenario WHERE capability_version_pk = @v)
                     INSERT model.capability_root_scenario (capability_version_pk, scenario_pk, _owner_definition_pk, _canonical_pointer)
                     VALUES (@v, @s, @sod, N'')`,
            { v: [sql.BigInt, capVer], s: [sql.BigInt, scnPk], sod: [sql.BigInt, cap.sod] });
          await lineage(cap.sod, 'capability_root_scenario', '', observation);
        }
        s._scenarioVersionPk = scnVer;
        s._scenarioNs = scenarioNs;
        s._scnSo = scn.so;
        s._scnSod = scn.sod;
      }

      // --- execution authorities: operations and their links -----------------
      const execs = new Map();
      const eaJson = await json('execution-authorities.authority.json');
      for (const [i, e] of (eaJson?.executionAuthorities ?? []).entries()) {
        if (typeof e.id !== 'string' || !Array.isArray(e.operations)) throw new Error('EXECUTION_AUTHORITY_SHAPE_REQUIRED:' + i);
        const scope = await scopedNamespace('EXECUTION_AUTHORITY');
        const def = await define('EXECUTION_AUTHORITY', e.id, { authority: e },
          scope.namespacePk, scope.namespaceId, manifestHex);
        let eaPk = (await scalar(
          `SELECT execution_authority_pk FROM model.execution_authority WHERE namespace_pk = @ns AND execution_authority_id = @id`,
          { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, e.id] }))?.execution_authority_pk;
        if (!eaPk) {
          eaPk = (await scalar(
            `INSERT model.execution_authority (namespace_pk, execution_authority_id, semantic_object_pk, object_kind)
             VALUES (@ns, @id, @so, 'EXECUTION_AUTHORITY'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS execution_authority_pk`,
            { ns: [sql.BigInt, scope.namespacePk], id: [sql.NVarChar, e.id], so: [sql.BigInt, def.so] })).execution_authority_pk;
        }
        let eaVer = (await scalar(
          `SELECT execution_authority_version_pk FROM model.execution_authority_version WHERE execution_authority_pk = @a AND definition_digest = @d`,
          { a: [sql.BigInt, eaPk], d: [sql.VarBinary, def.digest] }))?.execution_authority_version_pk;
        if (!eaVer) {
          eaVer = (await scalar(
            `INSERT model.execution_authority_version (execution_authority_pk, semantic_object_pk, semantic_object_definition_pk,
               definition_digest, authority_profile, object_kind, _owner_definition_pk, _canonical_pointer)
             VALUES (@a, @so, @sod, @d, 'execution-authorities.v1', 'EXECUTION_AUTHORITY', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS execution_authority_version_pk`,
            { a: [sql.BigInt, eaPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
              d: [sql.VarBinary, def.digest] })).execution_authority_version_pk;
        }
        await lineage(def.sod, 'execution_authority_version', '', observation);

        for (const [j, op] of e.operations.entries()) {
          if (!['invoke-port', 'invoke-scenario', 'project-state'].includes(op.kind)) throw new Error('OPERATION_KIND_UNSUPPORTED:' + op.kind);
          const opPtr = '/semantics/authority/operations/' + j;
          let opPk = (await scalar(
            `SELECT execution_operation_pk FROM model.execution_operation
              WHERE execution_authority_version_pk = @v AND ordinal = @ord`,
            { v: [sql.BigInt, eaVer], ord: [sql.Int, j] }))?.execution_operation_pk;
          if (!opPk) {
            opPk = (await scalar(
              `INSERT model.execution_operation (execution_authority_version_pk, operation_id, ordinal, operation_kind,
                 _owner_definition_pk, _canonical_pointer)
               VALUES (@v, @id, @ord, @kind, @owner, @ptr); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS execution_operation_pk`,
              { v: [sql.BigInt, eaVer], id: [sql.NVarChar, op.id ?? null], ord: [sql.Int, j],
                kind: [sql.VarChar, op.kind], owner: [sql.BigInt, def.sod], ptr: [sql.NVarChar, opPtr] })).execution_operation_pk;
          }
          await lineage(def.sod, 'execution_operation', opPtr, observation);
          if (op.kind === 'invoke-port') {
            const port = ports.get(op.portId);
            if (!port) throw new Error('PORT_REFERENCE_UNRESOLVED:' + op.portId);
            await run(`IF NOT EXISTS (SELECT 1 FROM model.operation_port_invocation WHERE execution_operation_pk = @o)
                       INSERT model.operation_port_invocation (execution_operation_pk, operation_kind, port_version_pk,
                         _owner_definition_pk, _canonical_pointer)
                       VALUES (@o, 'invoke-port', @p, @owner, @ptr)`,
              { o: [sql.BigInt, opPk], p: [sql.BigInt, port.portVer], owner: [sql.BigInt, def.sod], ptr: [sql.NVarChar, opPtr] });
            await lineage(def.sod, 'operation_port_invocation', opPtr, observation);
          } else if (op.kind === 'invoke-scenario') {
            const target = plan.scenarios.find(s => s.scenarioId === op.scenarioId);
            if (!target || !target._scenarioVersionPk) throw new Error('SCENARIO_REFERENCE_UNRESOLVED:' + op.scenarioId);
            await run(`IF NOT EXISTS (SELECT 1 FROM model.operation_scenario_invocation WHERE execution_operation_pk = @o)
                       INSERT model.operation_scenario_invocation (execution_operation_pk, operation_kind, target_scenario_version_pk,
                         _owner_definition_pk, _canonical_pointer)
                       VALUES (@o, 'invoke-scenario', @s, @owner, @ptr)`,
              { o: [sql.BigInt, opPk], s: [sql.BigInt, target._scenarioVersionPk], owner: [sql.BigInt, def.sod], ptr: [sql.NVarChar, opPtr] });
            await lineage(def.sod, 'operation_scenario_invocation', opPtr, observation);
          } else if (op.kind === 'project-state') {
            const projection = (interfacesJson?.projectionBindings ?? []).find(p => p.projectionId === op.projectionId);
            const t = projection ? transforms.get(projection.configuration?.transformationId) : null;
            if (!t) throw new Error('PROJECTION_REFERENCE_UNRESOLVED:' + op.projectionId);
            await run(`IF NOT EXISTS (SELECT 1 FROM model.operation_state_projection WHERE execution_operation_pk = @o)
                       INSERT model.operation_state_projection (execution_operation_pk, operation_kind, transformation_version_pk,
                         _owner_definition_pk, _canonical_pointer)
                       VALUES (@o, 'project-state', @t, @owner, @ptr)`,
              { o: [sql.BigInt, opPk], t: [sql.BigInt, t.tVer], owner: [sql.BigInt, def.sod], ptr: [sql.NVarChar, opPtr] });
            await lineage(def.sod, 'operation_state_projection', opPtr, observation);
          }
        }
        execs.set(e.id, { ...def, eaPk, eaVer });
      }

      // --- faces: linked to the promoted contracts and authorities -----------
      for (const s of plan.scenarios) {
        const { _scenarioVersionPk: scnVer, _scenarioNs: scenarioNs, _scnSo: scnSo, _scnSod: scnSod } = s;
        const faceOwner = { id: s.scenarioId, kind: 'SCENARIO', namespace: scenarioNs.namespaceId };

        const inputNs = await ownedNamespace('SCENARIO_INPUT', faceOwner, scnSo);
        const inputContract = contracts.get(s.inputContractId);
        if (!inputContract) throw new Error('INPUT_CONTRACT_UNRESOLVED:' + s.inputContractId);
        const inp = await define('SCENARIO_INPUT', s.inputId,
          { inputId: s.inputId, contractId: s.inputContractId, scenarioId: s.scenarioId },
          inputNs.namespacePk, inputNs.namespaceId, manifestHex);
        await run(`IF NOT EXISTS (SELECT 1 FROM model.scenario_input WHERE scenario_version_pk = @sv)
                   INSERT model.scenario_input (scenario_version_pk, input_id, semantic_object_pk, semantic_object_definition_pk,
                     namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer,
                     input_contract_version_pk, contract_reference_state)
                   VALUES (@sv, @id, @so, @sod, @ns, @d, 'SCENARIO_INPUT', @owner, N'', @cv, 'RESOLVED')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.inputId], so: [sql.BigInt, inp.so], sod: [sql.BigInt, inp.sod],
            ns: [sql.BigInt, inputNs.namespacePk], d: [sql.VarBinary, inp.digest], owner: [sql.BigInt, inp.sod],
            cv: [sql.BigInt, inputContract.contractVer] });
        await lineage(inp.sod, 'scenario_input', '', observation);

        const eventNs = await ownedNamespace('SCENARIO_EVENT', faceOwner, scnSo);
        const eventAuthority = execs.get(s.eventAuthorityId);
        if (!eventAuthority) throw new Error('EVENT_AUTHORITY_UNRESOLVED:' + s.eventAuthorityId);
        const evt = await define('SCENARIO_EVENT', s.eventId,
          { eventId: s.eventId, executionAuthorityId: s.eventAuthorityId, scenarioId: s.scenarioId },
          eventNs.namespacePk, eventNs.namespaceId, manifestHex);
        await run(`IF NOT EXISTS (SELECT 1 FROM model.scenario_event WHERE scenario_version_pk = @sv)
                   INSERT model.scenario_event (scenario_version_pk, event_id, responsibility, semantic_object_pk, semantic_object_definition_pk,
                     namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer,
                     execution_authority_version_pk, authority_reference_state)
                   VALUES (@sv, @id, @r, @so, @sod, @ns, @d, 'SCENARIO_EVENT', @owner, N'', @av, 'RESOLVED')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.eventId], r: [sql.NVarChar, s.responsibility],
            so: [sql.BigInt, evt.so], sod: [sql.BigInt, evt.sod], ns: [sql.BigInt, eventNs.namespacePk],
            d: [sql.VarBinary, evt.digest], owner: [sql.BigInt, evt.sod],
            av: [sql.BigInt, eventAuthority.eaVer] });
        await lineage(evt.sod, 'scenario_event', '', observation);

        const outcomeNs = await ownedNamespace('SCENARIO_OUTCOME', faceOwner, scnSo);
        const outcomeContract = contracts.get(s.outcomeContractId);
        if (!outcomeContract) throw new Error('OUTCOME_CONTRACT_UNRESOLVED:' + s.outcomeContractId);
        const out = await define('SCENARIO_OUTCOME', s.outcomeId,
          { outcomeId: s.outcomeId, contractId: s.outcomeContractId, terminalDisposition: s.terminalDisposition, scenarioId: s.scenarioId },
          outcomeNs.namespacePk, outcomeNs.namespaceId, manifestHex);
        await run(`IF NOT EXISTS (SELECT 1 FROM model.scenario_outcome WHERE scenario_version_pk = @sv)
                   INSERT model.scenario_outcome (scenario_version_pk, outcome_id, experience, terminal, terminal_disposition,
                     semantic_object_pk, semantic_object_definition_pk, namespace_pk, definition_digest, object_kind,
                     _owner_definition_pk, _canonical_pointer)
                   VALUES (@sv, @id, @e, 1, @td, @so, @sod, @ns, @d, 'SCENARIO_OUTCOME', @owner, N'')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.outcomeId], e: [sql.NVarChar, s.responsibility],
            td: [sql.NVarChar, s.terminalDisposition], so: [sql.BigInt, out.so], sod: [sql.BigInt, out.sod],
            ns: [sql.BigInt, outcomeNs.namespacePk], d: [sql.VarBinary, out.digest], owner: [sql.BigInt, out.sod] });
        await lineage(out.sod, 'scenario_outcome', '', observation);
        await run(`IF NOT EXISTS (SELECT 1 FROM model.scenario_outcome_contract WHERE scenario_version_pk = @sv)
                   INSERT model.scenario_outcome_contract (scenario_version_pk, contract_version_pk, _owner_definition_pk, _canonical_pointer)
                   VALUES (@sv, @cv, @owner, N'/semantics/tags/outcome-contract')`,
          { sv: [sql.BigInt, scnVer], cv: [sql.BigInt, outcomeContract.contractVer], owner: [sql.BigInt, scnSod] });
        await lineage(scnSod, 'scenario_outcome_contract', '/semantics/tags/outcome-contract', observation);
      }

      summary.capabilities.push({
        capabilityId: plan.capabilityId,
        capsuleDigest: 'sha256:' + plan.capsuleDigest.toString('hex'),
        entries: plan.entries.length,
        scenarios: plan.scenarios.length,
        contracts: contracts.size,
        ports: ports.size,
        transformations: transforms.size,
        executionAuthorities: execs.size
      });
      return { capabilityId: plan.capabilityId };
    });
  }

  // --- phase 4: gates --------------------------------------------------------
  // A dry run still builds and validates the generation (committed, resumable);
  // it only withholds the pointer flip.
  if (options.validate !== false) {
    await phase('validate', async () => {
      await run(`EXEC source.validate_model @m`, { m: [sql.BigInt, model] });
      summary.validated = true;
      return 0;
    });
  }
  if (options.publish && !options.dryRun) {
    await phase('publish', async () => {
      await run(`EXEC source.publish_model @m`, { m: [sql.BigInt, model] });
      summary.published = true;
      return 0;
    });
  }

  summary.disposition = summary.published ? 'PUBLISHED' : (summary.validated ? 'VALIDATED' : 'BUILT');
  return summary;
}
