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
//        / source.estate_model_rule / analysis.assessment from the current model
//     -> insert the authored capability's source and model rows
//     -> EXEC source.validate_model   (requires BUILDING; runs the lineage gates)
//     -> EXEC source.publish_model    (flips source.current_model)
//
// Every step is INSERT plus the two granted procedures, so nothing here
// suspends a guard or edits a published row.
//
// Deterministic: identical inputs produce identical content digests, an
// identical capsule digest, and identical canonical envelopes. Re-registering
// unchanged bytes is refused as ALREADY_REGISTERED rather than duplicated.
import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { connect, sql } from '../ingest/database.mjs';
import { stable, compare } from '../core.mjs';
import { canonical, bytesDigest } from '../migration/data.mjs';
import { packCapability } from './pack.mjs';
import { decodeCapsule } from '../snapshot/capture.mjs';

// Registration is its own mapping rule. normalize.mjs selects MANAGED_CAPSULE
// only, so PROVISIONED_CAPSULE -- a first-class source class the capture
// already produces -- has no normalization lane. This rule supplies one.
const RULE_ID = 'sidefx-capability-provisioning.v1';
const RULE_PROFILE = 'authored-provisioned-capsule.v1';

const sha = bytes => createHash('sha256').update(bytes).digest();
const hex = buf => '0x' + buf.toString('hex').toUpperCase();

// Canonical envelope for a normalized object, matching the derivation's
// sidefx-semantic-definition.v1 shape. `stable` fixes key order, so the digest
// is a function of meaning rather than of authoring order.
const envelope = (kind, id, namespace, semantics) =>
  Buffer.from(stable({ address: { id, kind, namespace }, format: 'sidefx-semantic-definition.v1', semantics }), 'utf8');

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
  const tx = new sql.Transaction(pool);
  const run = async (text, inputs = {}) => {
    const request = new sql.Request(tx);
    for (const [name, [type, value]] of Object.entries(inputs)) request.input(name, type, value);
    return request.query(text);
  };
  const scalar = async (text, inputs) => (await run(text, inputs)).recordset?.[0];

  await tx.begin();
  const summary = { generation: null, capabilities: [], published: false, validated: false };
  try {
    const current = await scalar(`SELECT m.estate_model_pk, m.estate_snapshot_pk, m.mapping_manifest_digest
      FROM source.current_model c JOIN source.estate_model m ON m.estate_model_pk = c.estate_model_pk
      WHERE c.singleton_id = 1`);
    if (!current) throw new Error('CURRENT_MODEL_NOT_FOUND');

    for (const plan of plans) {
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

    // --- the provisioning mapping rule --------------------------------------
    // AK_source_estate_model is (estate_snapshot_pk, mapping_manifest_digest),
    // so many models may share one snapshot provided their rule sets differ --
    // models 1 and 2 already do that over snapshot 1. Registration is therefore
    // a new rule over the SAME snapshot, not a new snapshot: no appearance is
    // copied and no source is duplicated.
    //
    // The rule's content records the exact selection it promoted, so rule_digest
    // and the manifest derived from it are distinct per registration. That is
    // what keeps registration atomic: each call is its own generation, and two
    // registrations cannot collide on the unique key.
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
    const ruleContentPk = await content(ruleBytes);
    const rule = (await scalar(
      `INSERT source.mapping_rule (rule_id, rule_digest, source_profile, rule_content_object_pk, canonicalization_profile)
       VALUES (@id, @d, @p, @c, @cz); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS mapping_rule_pk`,
      { id: [sql.NVarChar, RULE_ID], d: [sql.VarBinary, sha(ruleBytes)], p: [sql.NVarChar, RULE_PROFILE],
        c: [sql.BigInt, ruleContentPk], cz: [sql.NVarChar, 'JCS-IJSON-safe-integers.v1'] })).mapping_rule_pk;

    // Same manifest convention as complete.mjs: a digest over the ordered rule set.
    const manifest = bytesDigest(canonical([
      ...baseRules.map(r => ({ id: r.rule_id, digest: r.rule_digest.toString('hex') })),
      { id: RULE_ID, digest: sha(ruleBytes).toString('hex') }
    ]));

    // --- new generation, membership carried forward --------------------------
    const created = await scalar(
      `INSERT source.estate_model (estate_snapshot_pk, mapping_manifest_digest, publication_state)
       VALUES (@snap, @manifest, 'BUILDING'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS estate_model_pk`,
      { snap: [sql.BigInt, current.estate_snapshot_pk], manifest: [sql.VarBinary, manifest] });
    const model = created.estate_model_pk;
    summary.generation = {
      from: Number(current.estate_model_pk), to: Number(model),
      snapshot: Number(current.estate_snapshot_pk), rule: RULE_ID,
      ruleDigest: 'sha256:' + sha(ruleBytes).toString('hex'),
      manifestDigest: 'sha256:' + manifest.toString('hex')
    };

    const carry = { model: [sql.BigInt, model], from: [sql.BigInt, current.estate_model_pk] };
    await run(`INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk)
               SELECT @model, semantic_object_definition_pk FROM model.estate_definition WHERE estate_model_pk = @from`, carry);
    await run(`INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
               SELECT @model, capability_pk, capability_version_pk, semantic_object_definition_pk
               FROM model.estate_capability WHERE estate_model_pk = @from`, carry);
    await run(`INSERT source.estate_model_rule (estate_model_pk, mapping_rule_pk)
               SELECT @model, mapping_rule_pk FROM source.estate_model_rule WHERE estate_model_pk = @from`, carry);
    await run(`INSERT source.estate_model_rule (estate_model_pk, mapping_rule_pk) VALUES (@model, @rule)`,
      { model: [sql.BigInt, model], rule: [sql.BigInt, rule] });

    const ns = (await scalar(`SELECT namespace_pk FROM model.identity_namespace WHERE namespace_id = N'sidefx:capabilities'`)).namespace_pk;

    // AK_model_semantic_object is (namespace_pk, declared_id) with no
    // object_kind, so a capability and its like-named root scenario would
    // collide in one namespace. normalize.mjs avoids this with owned
    // namespaces -- a scenario is owned by its capability, a face by its
    // scenario -- keyed by the digest of the owner's address.
    const ownedNamespace = async (kind, ownerAddress, ownerSemanticObjectPk) => {
      const namespaceId = 'owner:sha256:' + createHash('sha256').update(canonical(ownerAddress)).digest('hex');
      await run(`IF NOT EXISTS (SELECT 1 FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id)
                 INSERT model.identity_namespace (namespace_kind, namespace_id) VALUES (@k, @id)`,
        { k: [sql.VarChar, kind], id: [sql.NVarChar, namespaceId] });
      const row = await scalar(`SELECT namespace_pk FROM model.identity_namespace WHERE namespace_kind = @k AND namespace_id = @id`,
        { k: [sql.VarChar, kind], id: [sql.NVarChar, namespaceId] });
      // G_NAMESPACE_SCENARIO_OWNER and its siblings: an owned namespace must
      // record which semantic object owns it, and under which scope.
      await run(`IF NOT EXISTS (SELECT 1 FROM model.namespace_owner
                                 WHERE namespace_pk = @n AND owner_semantic_object_pk = @o AND scope_kind = @k)
                 INSERT model.namespace_owner (namespace_pk, owner_semantic_object_pk, scope_kind)
                 VALUES (@n, @o, @k)`,
        { n: [sql.BigInt, row.namespace_pk], o: [sql.BigInt, ownerSemanticObjectPk], k: [sql.VarChar, kind] });
      return { namespacePk: row.namespace_pk, namespaceId };
    };

    // G_LINEAGE_MEMBER: every normalized member must trace to an observation
    // under a rule this model declares, matched on owner definition, member
    // kind and canonical pointer.
    const lineage = (ownerSod, memberKind, pointer, observationPk) =>
      run(`INSERT source.source_lineage (semantic_object_definition_pk, member_kind, canonical_pointer,
             source_observation_pk, mapping_rule_pk, contribution_role)
           VALUES (@d, @k, @p, @o, @r, 'DECLARATION')`,
        { d: [sql.BigInt, ownerSod], k: [sql.VarChar, memberKind], p: [sql.NVarChar, pointer],
          o: [sql.BigInt, observationPk], r: [sql.BigInt, rule] });

    const define = async (kind, declaredId, semantics, namespacePk = ns, namespaceId = 'sidefx:capabilities') => {
      const bytes = envelope(kind, declaredId, namespaceId, semantics);
      const contentPk = await content(bytes);
      const so = (await scalar(
        `INSERT model.semantic_object (object_kind, namespace_pk, declared_id)
         VALUES (@k, @ns, @id); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS semantic_object_pk`,
        { k: [sql.VarChar, kind], ns: [sql.BigInt, namespacePk], id: [sql.NVarChar, declaredId] })).semantic_object_pk;
      const sod = (await scalar(
        `INSERT model.semantic_object_definition (semantic_object_pk, object_kind, definition_digest, canonical_content_pk)
         VALUES (@so, @k, @d, @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS semantic_object_definition_pk`,
        { so: [sql.BigInt, so], k: [sql.VarChar, kind], d: [sql.VarBinary, sha(bytes)], c: [sql.BigInt, contentPk] })).semantic_object_definition_pk;
      await run(`INSERT model.estate_definition (estate_model_pk, semantic_object_definition_pk) VALUES (@m, @d)`,
        { m: [sql.BigInt, model], d: [sql.BigInt, sod] });
      return { so, sod, digest: sha(bytes) };
    };

    for (const plan of plans) {
      // --- source layer -----------------------------------------------------
      let observation = null;
      for (const entry of plan.entries) {
        const contentPk = await content(entry.bytes);
        const appearanceDigest = sha(Buffer.from(
          `${plan.capsuleDigest.toString('hex')}:${entry.sourcePath}:${entry.digest.toString('hex')}`, 'utf8'));
        const appearance = (await scalar(
          `INSERT source.source_appearance (estate_snapshot_pk, content_object_pk, appearance_digest,
             source_path, source_class, container_locator, capsule_digest, entry_id)
           VALUES (@snap, @c, @ad, @sp, 'PROVISIONED_CAPSULE', @loc, @capsule, @eid); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS source_appearance_pk`,
          { snap: [sql.BigInt, current.estate_snapshot_pk], c: [sql.BigInt, contentPk],
            ad: [sql.VarBinary, appearanceDigest], sp: [sql.NVarChar, entry.sourcePath],
            loc: [sql.NVarChar, plan.containerLocator],
            capsule: [sql.VarBinary, plan.capsuleDigest], eid: [sql.NVarChar, entry.entryId] })).source_appearance_pk;
        if (entry.entryId === 'capability.authority.json') {
          observation = (await scalar(
            `INSERT source.source_observation (source_appearance_pk, locator, locator_digest,
               observation_kind, presence_state, observed_value_content_pk)
             VALUES (@a, N'', @ld, 'DECLARATION', 'PRESENT', @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS source_observation_pk`,
            { a: [sql.BigInt, appearance], ld: [sql.VarBinary, sha(Buffer.from('', 'utf8'))],
              c: [sql.BigInt, contentPk] })).source_observation_pk;
          // G_OBSERVATION_SUBTYPE: a DECLARATION observation must carry its
          // subtype row, naming what was declared.
          await run(`INSERT source.declaration_observation (source_observation_pk, declared_kind, declared_id, namespace_text, observation_kind)
                     VALUES (@o, 'CAPABILITY', @id, @nsText, 'DECLARATION')`,
            { o: [sql.BigInt, observation], id: [sql.NVarChar, plan.capabilityId],
              nsText: [sql.NVarChar, 'sidefx:capabilities'] });
        }
      }
      if (!observation) throw new Error('CAPABILITY_AUTHORITY_ENTRY_MISSING:' + plan.capabilityId);

      // --- capability -------------------------------------------------------
      const authority = JSON.parse(await fs.readFile(path.join(plan.dir, 'capability.authority.json'), 'utf8'));
      const cap = await define('CAPABILITY', plan.capabilityId, authority);
      const capPk = (await scalar(
        `INSERT model.capability (namespace_pk, capability_id, semantic_object_pk, object_kind)
         VALUES (@ns, @id, @so, 'CAPABILITY'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS capability_pk`,
        { ns: [sql.BigInt, ns], id: [sql.NVarChar, plan.capabilityId], so: [sql.BigInt, cap.so] })).capability_pk;
      const capVer = (await scalar(
        `INSERT model.capability_version (capability_pk, semantic_object_pk, semantic_object_definition_pk,
           definition_digest, name, object_kind, _owner_definition_pk, _canonical_pointer)
         VALUES (@c, @so, @sod, @d, @n, 'CAPABILITY', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS capability_version_pk`,
        { c: [sql.BigInt, capPk], so: [sql.BigInt, cap.so], sod: [sql.BigInt, cap.sod],
          d: [sql.VarBinary, cap.digest], n: [sql.NVarChar, authority.name ?? plan.capabilityId] })).capability_version_pk;
      await run(`INSERT model.estate_capability (estate_model_pk, capability_pk, capability_version_pk, semantic_object_definition_pk)
                 VALUES (@m, @c, @v, @d)`,
        { m: [sql.BigInt, model], c: [sql.BigInt, capPk], v: [sql.BigInt, capVer], d: [sql.BigInt, cap.sod] });
      await lineage(cap.sod, 'capability_version', '', observation);

      // --- scenarios and their faces ----------------------------------------
      for (const s of plan.scenarios) {
        const scenarioNs = await ownedNamespace('SCENARIO',
          { id: plan.capabilityId, kind: 'CAPABILITY', namespace: 'sidefx:capabilities' }, cap.so);
        const scn = await define('SCENARIO', s.scenarioId,
          { scenarioId: s.scenarioId, capabilityId: plan.capabilityId, input: s.inputId, event: s.eventId, outcome: s.outcomeId },
          scenarioNs.namespacePk, scenarioNs.namespaceId);
        // Faces are owned by their scenario, one level down again.
        const faceOwner = { id: s.scenarioId, kind: 'SCENARIO', namespace: scenarioNs.namespaceId };
        const scnPk = (await scalar(
          `INSERT model.scenario (namespace_pk, scenario_id, semantic_object_pk, object_kind, capability_pk)
           VALUES (@ns, @id, @so, 'SCENARIO', @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS scenario_pk`,
          { ns: [sql.BigInt, scenarioNs.namespacePk], id: [sql.NVarChar, s.scenarioId], so: [sql.BigInt, scn.so], c: [sql.BigInt, capPk] })).scenario_pk;
        const scnVer = (await scalar(
          `INSERT model.scenario_version (scenario_pk, semantic_object_pk, semantic_object_definition_pk,
             definition_digest, name, source_profile, object_kind, _owner_definition_pk, _canonical_pointer)
           VALUES (@s, @so, @sod, @d, @n, N'managed-feature-tags.v1', 'SCENARIO', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS scenario_version_pk`,
          { s: [sql.BigInt, scnPk], so: [sql.BigInt, scn.so], sod: [sql.BigInt, scn.sod],
            d: [sql.VarBinary, scn.digest], n: [sql.NVarChar, s.scenarioId] })).scenario_version_pk;
        await lineage(scn.sod, 'scenario_version', '', observation);
        await run(`INSERT model.capability_scenario (capability_pk, capability_version_pk, scenario_pk, scenario_version_pk, _owner_definition_pk, _canonical_pointer)
                   VALUES (@c, @v, @s, @sv, @sod, @ptr)`,
          { c: [sql.BigInt, capPk], v: [sql.BigInt, capVer], s: [sql.BigInt, scnPk], sv: [sql.BigInt, scnVer], sod: [sql.BigInt, cap.sod], ptr: [sql.NVarChar, `/semantics/scenario_members/${s.scenarioId}`] });
        await lineage(cap.sod, 'capability_scenario', `/semantics/scenario_members/${s.scenarioId}`, observation);
        if (s.scenarioId === plan.rootScenarioId) {
          await run(`INSERT model.capability_root_scenario (capability_version_pk, scenario_pk, _owner_definition_pk, _canonical_pointer)
                     VALUES (@v, @s, @sod, N'')`,
            { v: [sql.BigInt, capVer], s: [sql.BigInt, scnPk], sod: [sql.BigInt, cap.sod] });
          await lineage(cap.sod, 'capability_root_scenario', '', observation);
        }

        const inputNs = await ownedNamespace('SCENARIO_INPUT', faceOwner, scn.so);
        const inp = await define('SCENARIO_INPUT', s.inputId,
          { inputId: s.inputId, contractId: s.inputContractId, scenarioId: s.scenarioId },
          inputNs.namespacePk, inputNs.namespaceId);
        await run(`INSERT model.scenario_input (scenario_version_pk, input_id, semantic_object_pk, semantic_object_definition_pk,
                     namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer, contract_reference_state)
                   VALUES (@sv, @id, @so, @sod, @ns, @d, 'SCENARIO_INPUT', @owner, N'', 'UNRESOLVED')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.inputId], so: [sql.BigInt, inp.so], sod: [sql.BigInt, inp.sod],
            ns: [sql.BigInt, inputNs.namespacePk], d: [sql.VarBinary, inp.digest], owner: [sql.BigInt, inp.sod] });
        await lineage(inp.sod, 'scenario_input', '', observation);

        const eventNs = await ownedNamespace('SCENARIO_EVENT', faceOwner, scn.so);
        const evt = await define('SCENARIO_EVENT', s.eventId,
          { eventId: s.eventId, executionAuthorityId: s.eventAuthorityId, scenarioId: s.scenarioId },
          eventNs.namespacePk, eventNs.namespaceId);
        await run(`INSERT model.scenario_event (scenario_version_pk, event_id, responsibility, semantic_object_pk, semantic_object_definition_pk,
                     namespace_pk, definition_digest, object_kind, _owner_definition_pk, _canonical_pointer, authority_reference_state)
                   VALUES (@sv, @id, @r, @so, @sod, @ns, @d, 'SCENARIO_EVENT', @owner, N'', 'UNRESOLVED')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.eventId], r: [sql.NVarChar, s.responsibility],
            so: [sql.BigInt, evt.so], sod: [sql.BigInt, evt.sod], ns: [sql.BigInt, eventNs.namespacePk],
            d: [sql.VarBinary, evt.digest], owner: [sql.BigInt, evt.sod] });
        await lineage(evt.sod, 'scenario_event', '', observation);

        const outcomeNs = await ownedNamespace('SCENARIO_OUTCOME', faceOwner, scn.so);
        const out = await define('SCENARIO_OUTCOME', s.outcomeId,
          { outcomeId: s.outcomeId, contractId: s.outcomeContractId, terminalDisposition: s.terminalDisposition, scenarioId: s.scenarioId },
          outcomeNs.namespacePk, outcomeNs.namespaceId);
        await run(`INSERT model.scenario_outcome (scenario_version_pk, outcome_id, experience, terminal, terminal_disposition,
                     semantic_object_pk, semantic_object_definition_pk, namespace_pk, definition_digest, object_kind,
                     _owner_definition_pk, _canonical_pointer)
                   VALUES (@sv, @id, @e, 1, @td, @so, @sod, @ns, @d, 'SCENARIO_OUTCOME', @owner, N'')`,
          { sv: [sql.BigInt, scnVer], id: [sql.NVarChar, s.outcomeId], e: [sql.NVarChar, s.responsibility],
            td: [sql.NVarChar, s.terminalDisposition], so: [sql.BigInt, out.so], sod: [sql.BigInt, out.sod],
            ns: [sql.BigInt, outcomeNs.namespacePk], d: [sql.VarBinary, out.digest], owner: [sql.BigInt, out.sod] });
        await lineage(out.sod, 'scenario_outcome', '', observation);
      }

      summary.capabilities.push({
        capabilityId: plan.capabilityId,
        capsuleDigest: 'sha256:' + plan.capsuleDigest.toString('hex'),
        entries: plan.entries.length,
        scenarios: plan.scenarios.length
      });
    }

    // --- gates -------------------------------------------------------------
    if (options.validate !== false) {
      await run(`EXEC source.validate_model @m`, { m: [sql.BigInt, model] });
      summary.validated = true;
    }
    if (options.publish) {
      await run(`EXEC source.publish_model @m`, { m: [sql.BigInt, model] });
      summary.published = true;
    }

    if (options.dryRun) { await tx.rollback(); summary.disposition = 'ROLLED_BACK'; }
    else { await tx.commit(); summary.disposition = summary.published ? 'PUBLISHED' : 'BUILT'; }
    return summary;
  } catch (error) {
    try { await tx.rollback(); } catch {}
    throw error;
  } finally {
    await pool.close().catch(() => {});
  }
}
