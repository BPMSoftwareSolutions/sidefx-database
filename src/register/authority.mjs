// Promote the authority a registered capability's faces refer to.
//
// Registering identity alone leaves every reference dangling: the resolver map
// reports INPUT_CONTRACT / EVENT_AUTHORITY / OUTCOME_CONTRACT as
// MISSING_AUTHORITY and node readiness holds at NOT_OBSERVABLE. This module
// promotes the rest of the chain from the same capsule bytes:
//
//   contracts (+ schema objects) -> transformations (+ expression trees)
//   -> ports -> execution authorities (+ operations and their invocations)
//
// Order matters and is forced by the guards: model tables reject UPDATE, so a
// face cannot be inserted first and resolved later. Everything a face
// references must exist before the face row is written.
import { sql } from '../ingest/database.mjs';
import { escapePointer } from '../core.mjs';

const EXPRESSION_ROOT = '/semantics/expression';

/**
 * @param {object} ctx  { run, scalar, content, define, lineage, ensureNamespace, model }
 * @param {object} plan { capabilityId, entryText }
 */
export async function promoteAuthority(ctx, plan, capabilityDefinitionPk, observation) {
  const { run, scalar, content, define, lineage, ensureNamespace } = ctx;
  const doc = id => JSON.parse(plan.entryText(id));
  const scope = `sidefx:capability:${plan.capabilityId}`;

  const contractNs = await ensureNamespace('CONTRACT', 'sidefx:contracts');
  const portNs = await ensureNamespace('PORT', scope);
  const transformNs = await ensureNamespace('TRANSFORMATION', scope);
  const authorityNs = await ensureNamespace('EXECUTION_AUTHORITY', scope);

  // ---- contracts ---------------------------------------------------------
  // One contract id, one schema file. The catalog was de-aliased when the
  // artifacts were authored, so no two ids share a schema.
  const catalog = doc('contracts/contract-catalog.json');
  const contracts = new Map();
  for (const [contractId, schemaFile] of Object.entries(catalog)) {
    const bytes = plan.entryBytes(`contracts/${schemaFile}`);
    if (!bytes) throw new Error('CONTRACT_SCHEMA_ENTRY_MISSING:' + schemaFile);
    const schema = JSON.parse(bytes.toString('utf8'));
    const contentPk = await content(bytes);

    let schemaObject = await scalar(
      `SELECT schema_object_pk FROM model.schema_object WHERE content_digest = HASHBYTES('SHA2_256', @b)`,
      { b: [sql.VarBinary, bytes] });
    if (!schemaObject) {
      schemaObject = await scalar(
        `INSERT model.schema_object (content_digest, dialect, content_object_pk)
         VALUES (HASHBYTES('SHA2_256', @b), @d, @c); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS schema_object_pk`,
        { b: [sql.VarBinary, bytes], d: [sql.NVarChar, schema.$schema ?? null], c: [sql.BigInt, contentPk] });
    }

    const def = await define('CONTRACT', contractId, { contractId, schemaRef: schemaFile, title: schema.title ?? null },
      contractNs.namespacePk, contractNs.namespaceId);
    await run(`IF NOT EXISTS (SELECT 1 FROM model.contract WHERE namespace_pk = @ns AND contract_id = @id)
               INSERT model.contract (namespace_pk, contract_id, semantic_object_pk, object_kind) VALUES (@ns, @id, @so, 'CONTRACT')`,
      { ns: [sql.BigInt, contractNs.namespacePk], id: [sql.NVarChar, contractId], so: [sql.BigInt, def.so] });
    const contractPk = (await scalar(`SELECT contract_pk FROM model.contract WHERE namespace_pk = @ns AND contract_id = @id`,
      { ns: [sql.BigInt, contractNs.namespacePk], id: [sql.NVarChar, contractId] })).contract_pk;
    const versionPk = (await scalar(
      `INSERT model.contract_version (contract_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest,
         name, schema_object_pk, object_kind, _owner_definition_pk, _canonical_pointer, schema_reference_state)
       VALUES (@c, @so, @sod, @d, @n, @sch, 'CONTRACT', @sod, N'', 'RESOLVED'); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS contract_version_pk`,
      { c: [sql.BigInt, contractPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
        d: [sql.VarBinary, def.digest], n: [sql.NVarChar, schema.title ?? null],
        sch: [sql.BigInt, schemaObject.schema_object_pk] })).contract_version_pk;
    await lineage(def.sod, 'contract_version', '', observation);
    contracts.set(contractId, versionPk);
  }

  // ---- transformations ---------------------------------------------------
  const transformations = new Map();
  for (const t of doc('semantic-transformation.authority.json').transformations ?? []) {
    if (t.expression === undefined) continue;
    const def = await define('TRANSFORMATION', t.id, t, transformNs.namespacePk, transformNs.namespaceId);
    await run(`IF NOT EXISTS (SELECT 1 FROM model.transformation WHERE namespace_pk = @ns AND transformation_id = @id)
               INSERT model.transformation (namespace_pk, transformation_id, semantic_object_pk, object_kind) VALUES (@ns, @id, @so, 'TRANSFORMATION')`,
      { ns: [sql.BigInt, transformNs.namespacePk], id: [sql.NVarChar, t.id], so: [sql.BigInt, def.so] });
    const transformationPk = (await scalar(`SELECT transformation_pk FROM model.transformation WHERE namespace_pk = @ns AND transformation_id = @id`,
      { ns: [sql.BigInt, transformNs.namespacePk], id: [sql.NVarChar, t.id] })).transformation_pk;
    const versionPk = (await scalar(
      `INSERT model.transformation_version (transformation_pk, semantic_object_pk, semantic_object_definition_pk,
         definition_digest, expression_profile, object_kind, _owner_definition_pk, _canonical_pointer)
       VALUES (@t, @so, @sod, @d, N'json-expression-tree.v1', 'TRANSFORMATION', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS transformation_version_pk`,
      { t: [sql.BigInt, transformationPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
        d: [sql.VarBinary, def.digest] })).transformation_version_pk;
    await lineage(def.sod, 'transformation_version', '', observation);

    await writeExpressionTree(ctx, versionPk, def.sod, t.expression, observation);
    transformations.set(t.id, versionPk);
  }

  // ---- ports -------------------------------------------------------------
  const interfaces = doc('interfaces.authority.json');
  const ports = new Map();
  for (const binding of interfaces.portBindings ?? []) {
    const def = await define('PORT', binding.portId, binding, portNs.namespacePk, portNs.namespaceId);
    await run(`IF NOT EXISTS (SELECT 1 FROM model.port WHERE namespace_pk = @ns AND port_id = @id)
               INSERT model.port (namespace_pk, port_id, semantic_object_pk, object_kind) VALUES (@ns, @id, @so, 'PORT')`,
      { ns: [sql.BigInt, portNs.namespacePk], id: [sql.NVarChar, binding.portId], so: [sql.BigInt, def.so] });
    const portPk = (await scalar(`SELECT port_pk FROM model.port WHERE namespace_pk = @ns AND port_id = @id`,
      { ns: [sql.BigInt, portNs.namespacePk], id: [sql.NVarChar, binding.portId] })).port_pk;
    const versionPk = (await scalar(
      `INSERT model.port_version (port_pk, semantic_object_pk, semantic_object_definition_pk, definition_digest,
         port_profile, object_kind, _owner_definition_pk, _canonical_pointer)
       VALUES (@p, @so, @sod, @d, N'consumer-interface-authority.v1', 'PORT', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS port_version_pk`,
      { p: [sql.BigInt, portPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
        d: [sql.VarBinary, def.digest] })).port_version_pk;
    await lineage(def.sod, 'port_version', '', observation);
    ports.set(binding.portId, versionPk);
  }

  return { contracts, transformations, ports, authorityNs,
    executionAuthorities: doc('execution-authorities.authority.json').executionAuthorities ?? [] };
}

/**
 * Execution authorities are written after scenarios exist, because
 * invoke-scenario operations reference scenario versions.
 */
export async function promoteExecutionAuthorities(ctx, plan, promoted, scenarioVersions, observation) {
  const { run, scalar, define, lineage } = ctx;
  const { authorityNs, ports } = promoted;
  const authorities = new Map();

  for (const authority of promoted.executionAuthorities) {
    const def = await define('EXECUTION_AUTHORITY', authority.id, authority,
      authorityNs.namespacePk, authorityNs.namespaceId);
    await run(`IF NOT EXISTS (SELECT 1 FROM model.execution_authority WHERE namespace_pk = @ns AND execution_authority_id = @id)
               INSERT model.execution_authority (namespace_pk, execution_authority_id, semantic_object_pk, object_kind) VALUES (@ns, @id, @so, 'EXECUTION_AUTHORITY')`,
      { ns: [sql.BigInt, authorityNs.namespacePk], id: [sql.NVarChar, authority.id], so: [sql.BigInt, def.so] });
    const authorityPk = (await scalar(`SELECT execution_authority_pk FROM model.execution_authority WHERE namespace_pk = @ns AND execution_authority_id = @id`,
      { ns: [sql.BigInt, authorityNs.namespacePk], id: [sql.NVarChar, authority.id] })).execution_authority_pk;
    const versionPk = (await scalar(
      `INSERT model.execution_authority_version (execution_authority_pk, semantic_object_pk, semantic_object_definition_pk,
         definition_digest, authority_profile, object_kind, _owner_definition_pk, _canonical_pointer)
       VALUES (@a, @so, @sod, @d, N'execution-authorities.v1', 'EXECUTION_AUTHORITY', @sod, N''); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS execution_authority_version_pk`,
      { a: [sql.BigInt, authorityPk], so: [sql.BigInt, def.so], sod: [sql.BigInt, def.sod],
        d: [sql.VarBinary, def.digest] })).execution_authority_version_pk;
    await lineage(def.sod, 'execution_authority_version', '', observation);

    for (const [ordinal, operation] of (authority.operations ?? []).entries()) {
      const pointer = `/semantics/operations/${ordinal}`;
      const operationPk = (await scalar(
        `INSERT model.execution_operation (execution_authority_version_pk, operation_id, ordinal, operation_kind,
           _owner_definition_pk, _canonical_pointer)
         VALUES (@v, @oid, @ord, @k, @sod, @ptr); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS execution_operation_pk`,
        { v: [sql.BigInt, versionPk], oid: [sql.NVarChar, operation.operationId ?? null],
          ord: [sql.Int, ordinal], k: [sql.VarChar, operation.kind],
          sod: [sql.BigInt, def.sod], ptr: [sql.NVarChar, pointer] })).execution_operation_pk;
      await lineage(def.sod, 'execution_operation', pointer, observation);

      if (operation.kind === 'invoke-port') {
        const portVersion = ports.get(operation.portId);
        if (!portVersion) throw new Error('OPERATION_PORT_NOT_DECLARED:' + operation.portId);
        await run(`INSERT model.operation_port_invocation (execution_operation_pk, port_version_pk, operation_kind,
                     _owner_definition_pk, _canonical_pointer)
                   VALUES (@o, @p, @k, @sod, @ptr)`,
          { o: [sql.BigInt, operationPk], p: [sql.BigInt, portVersion], k: [sql.VarChar, operation.kind],
            sod: [sql.BigInt, def.sod], ptr: [sql.NVarChar, pointer] });
        await lineage(def.sod, 'operation_port_invocation', pointer, observation);
      } else if (operation.kind === 'invoke-scenario') {
        const target = scenarioVersions.get(operation.scenarioId);
        if (!target) throw new Error('OPERATION_SCENARIO_NOT_DECLARED:' + operation.scenarioId);
        await run(`INSERT model.operation_scenario_invocation (execution_operation_pk, target_scenario_version_pk,
                     operation_kind, _owner_definition_pk, _canonical_pointer)
                   VALUES (@o, @s, @k, @sod, @ptr)`,
          { o: [sql.BigInt, operationPk], s: [sql.BigInt, target], k: [sql.VarChar, operation.kind],
            sod: [sql.BigInt, def.sod], ptr: [sql.NVarChar, pointer] });
        await lineage(def.sod, 'operation_scenario_invocation', pointer, observation);
      }
    }
    authorities.set(authority.id, versionPk);
  }
  return authorities;
}

// The expression tree, written the way normalize.mjs writes it: one node per
// JSON position, children linked by member kind, and a root member.
async function writeExpressionTree(ctx, versionPk, ownerSod, expression, observation) {
  const { run, scalar, content, lineage } = ctx;

  const nodes = [];
  (function visit(value, pointer) {
    const kind = Array.isArray(value) ? 'ARRAY' : value && typeof value === 'object' ? 'OBJECT' : 'LITERAL';
    nodes.push({ pointer, kind, value });
    if (kind === 'OBJECT' || kind === 'ARRAY')
      for (const [key, child] of Object.entries(value))
        visit(child, `${pointer}/${escapePointer(key)}`);
  })(expression, EXPRESSION_ROOT);

  const pks = new Map();
  for (const node of nodes) {
    const literalPk = node.kind === 'LITERAL'
      ? await content(Buffer.from(JSON.stringify(node.value ?? null), 'utf8')) : null;
    const pk = (await scalar(
      `INSERT model.transformation_expression_node (transformation_version_pk, node_pointer, node_kind,
         operator, literal_content_pk, reference_name, _owner_definition_pk, _canonical_pointer)
       VALUES (@v, @ptr, @k, NULL, @lit, NULL, @sod, @ptr); SELECT CAST(SCOPE_IDENTITY() AS bigint) AS expression_node_pk`,
      { v: [sql.BigInt, versionPk], ptr: [sql.NVarChar, node.pointer], k: [sql.VarChar, node.kind],
        lit: [sql.BigInt, literalPk], sod: [sql.BigInt, ownerSod] })).expression_node_pk;
    pks.set(node.pointer, pk);
    await lineage(ownerSod, 'transformation_expression_node', node.pointer, observation);
  }

  for (const node of nodes) {
    if (node.kind === 'LITERAL') continue;
    for (const [key, child] of Object.entries(node.value)) {
      const childPointer = `${node.pointer}/${escapePointer(key)}`;
      await run(`INSERT model.transformation_expression_child (transformation_version_pk, parent_node_pk, child_node_pk,
                   member_kind, member_name, ordinal, _owner_definition_pk, _canonical_pointer)
                 VALUES (@v, @p, @c, @mk, @mn, @ord, @sod, @ptr)`,
        { v: [sql.BigInt, versionPk], p: [sql.BigInt, pks.get(node.pointer)], c: [sql.BigInt, pks.get(childPointer)],
          mk: [sql.VarChar, node.kind === 'ARRAY' ? 'ARRAY_MEMBER' : 'OBJECT_MEMBER'],
          mn: [sql.NVarChar, node.kind === 'OBJECT' ? key : null],
          ord: [sql.Int, node.kind === 'ARRAY' ? Number(key) : null],
          sod: [sql.BigInt, ownerSod], ptr: [sql.NVarChar, childPointer] });
      await lineage(ownerSod, 'transformation_expression_child', childPointer, observation);
    }
  }

  await run(`INSERT model.transformation_root (transformation_version_pk, expression_node_pk, _owner_definition_pk, _canonical_pointer)
             VALUES (@v, @n, @sod, @ptr)`,
    { v: [sql.BigInt, versionPk], n: [sql.BigInt, pks.get(EXPRESSION_ROOT)],
      sod: [sql.BigInt, ownerSod], ptr: [sql.NVarChar, EXPRESSION_ROOT] });
  await lineage(ownerSod, 'transformation_root', EXPRESSION_ROOT, observation);

  return nodes.length;
}
