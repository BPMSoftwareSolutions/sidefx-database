# Capability execution preparation

Migration `005-capability-preparation` adds `runtime.capability_preparation` as
derived execution data. It does not change source/model authority or migration
004's inspection functions. Apply it explicitly:

```powershell
node src/migration/capability-preparation.mjs --dry-run
node src/migration/capability-preparation.mjs
```

The `sfx-embody` provider implements `sfx capability prepare <identity>`. It reads
the selected capability, resolves its requirements, builds its native body in
memory, executes its retained fixtures, and calls `storePreparation`. Only a
resolved, proved bundle is accepted. Invocation calls `readPreparation`, which
performs an indexed lookup through the existing restricted query reader. It
never runs the resolver or prepares implicitly.

The key contains the selected model, capability and Scenario versions, target,
SQL view/function definition digest and preparation recipe digest. The recipe
identifies the adapter/query implementation and runtime version. The immutable
payload contains the authority bundle and proof, with an SQL-enforced SHA-256
check over its exact UTF-8 bytes. The provider verifies the payload digest, query
result digests, selection, revision and proof before using it. Rebuilding a body
for invocation must reproduce every prepared Scenario artifact and platform
digest.

Publication reacquires the same shared model lock and selected-generation pin
used by the reader. A preparation whose generation or resolver definitions
changed during derivation cannot be published. Identical publication is
idempotent; different payloads for the same context are rejected. Rows are append
only, with an immutable trigger and separate insert-only `sidefx_preparer` user.
The generic SQL reader has SELECT permission and is denied runtime writes.

The selected generation conservatively covers all declaration dependencies.
Publishing a different model invalidates previous preparations even if an
unrelated capability caused the change. Dependency-minimal reuse is not claimed.
`CAPABILITY_PREPARATION_REQUIRED` means no preparation exists for the capability;
`CAPABILITY_PREPARATION_STALE` means an existing preparation does not match the
current context. Neither condition starts analysis. Missing authority and
ambiguous namespaces retain their existing explicit errors.

The preparation table is derived execution data, not a managed admission record.
Published authority still follows the existing immutable import model. Candidate
editing and a capsulization adapter are separate boundaries; this record provides
the exact bundle and proof identity that such an adapter must consume.

Tests: `node --test test/preparation.test.mjs`; after native CLI preparation,
set `SIDEFX_PREPARATION_INTEGRATION=1` and run
`node --test test/preparation.integration.test.mjs` for publication, invalidation,
reader permissions, concurrency, digest constraints and foreign-key trust.
