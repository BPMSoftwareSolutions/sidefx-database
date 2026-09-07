# First verified SideFX Database snapshot

SideFX Database v1 is built and populated in the configured `sidefx` SQL Server database. The workspace reads the Harness and writes only its own observation archive and inspection schemas. No Harness capability was authored, executed, admitted, or published by this task.

## Loaded observation

| Measure | Verified result |
|---|---:|
| Managed capabilities | 219 |
| Managed capsule entries | 6,920 |
| Captured repository files | 1,046 |
| Archived artifact occurrences | 8,178 |
| Unique exact source byte objects | 3,987 |
| Source archive bytes before SQL/text representation | 251,594,434 |
| Domain tables | 39 |
| Diagnostic views | 17 |
| Derived observation rows, including all source classes and copies | 111,998 |
| Default scenario declarations | 969 |
| Capabilities represented by default features and scenarios | 219 |
| Distinct feature byte versions across those capabilities | 233 |
| Capability-owned contract declarations | 667 |
| Observed Semantic Brain attribute facts | 970 |

Snapshot:

`sha256:86d58414531642348bc013dd5bb41aaa7fbb5ce75b7ae6b48847d3c91fd60fb7`

Relational projection:

`sha256:4fd2b3e84785c7920d8d8a49b06490482345d2fcab619060f22081df65e23074`

The full archive includes capsule-contained authority, runtime projections, shared resources, provisioned tokens, tracked repository files, and nonignored working testimony. Counts of all observations intentionally include copies and alternative representations. Default feature/scenario views collapse only identical feature byte copies within the same capability; different bytes remain separate observations.

## Verification

- All **11 local tests passed**, including capsule tampering, path traversal, pointer escaping, fixture separation, feature aliases, Gherkin boundaries, v3 provider-slot observations, and lossless query timestamp/binary formatting.
- Independent rederivation from the frozen source bytes reproduced all **111,998 SQL rows** across all 39 domain tables.
- All **111,960 data observation pointers** resolved to the expected source values. The remaining 38 rows are extraction-issue metadata, checked through their reproduced row digests rather than as source-value objects.
- SQL readback verified the original bytes and derived UTF-8 text for every one of the **3,987 source objects**, along with all 8,178 artifact provenance records.
- Every one of the **17 diagnostic views** was executed, including sample rows that exercise computed columns.
- The query session ran as `sidefx_reader`. SQL Server rejected `INSERT`, `UPDATE`, and `DELETE` with error 229 and rejected `REVERT` with error 15196.
- A deterministic query returned identical result digests on replay. Query limits and explicit truncation were also verified.
- All example query files ran. The architecture-question batch returned identical result digests after the final index and aggregate-query changes; its measured run took **10.134 seconds**. Its final topology result was explicitly capped at the configured 1,000 rows; increase `--limit` to inspect more.
- The Harness estate still verified at close with 219 capsules, 6,920 entries, and no expanded capability directory.

Evidence:

| Claim | Receipt |
|---|---|
| Final SQL load | [Ingestion receipt](../receipts/ingest-c571b16204650d0068509a685021d278673cacd666ee5324c4cd6fad0b47d119.json) |
| Rebuild, provenance, and SQL byte equivalence | [Verification receipt](../receipts/verify-b76cfcd8ce1a245431ab9edbc660f759630dc9806f2ef875045aecdd1863dd33.json) |
| Views, restricted reader, replay, row limit | [Live checks](../receipts/live-checks-0ff5a882f06848c4ddb941da64bc6efba6ada374a83e66cddab0815625935f1a.json) |
| Final indexes preserve query results | [Index check](../receipts/query-index-check-137b90ec72f91d5c25cc1c1e9a632f732e3530056a1ff9a492f086d601629064.json) |
| Counts and initial review queue | [Summary query](../receipts/query-47eb6912667f33e667dcd7b0081732f05b12785a2873a6813bb3122755b75714.json) |
| Working-source drift since capture | [Source observation](../receipts/source-unchanged-d730319c4cb5fb8646e90093595430ed0097b3b7a42db8e3731a6df9a1ae4c2c.json) |

Query text, SQL view definitions, and returned result objects are retained locally by digest. Receipts bind them to the exact snapshot and projection.

## Initial findings

Two capsule entries contain invalid JSON:

- `project-capability-revelation`: `capabilities/project-capability-revelation/contracts/outcome.schema.json` has trailing non-whitespace after the parsed JSON value.
- `project-strategic-evidence-review`: `capabilities/project-strategic-evidence-review/contracts/outcome.schema.json` fails JSON parsing within the object.

Both originals are preserved byte-for-byte. Their extraction status is `PARSE_FAILED`; no repair or semantic substitution was performed.

Fourteen capabilities contain two different feature byte versions. `sidefx.v_feature_source_integrity` exposes these without selecting one as authoritative. Byte differences alone do not prove a semantic conflict.

The default `manage-capsule-estate` feature has 12 scenario declarations without `@scenario` identities. Retained aliases yield 24 capsule-level missing-identity observations. These are visible rather than replaced with generated identifiers.

Eleven capabilities have entries in the initial health review queue. These counts combine extraction and structural observations, and may include multiple observations of one underlying issue. They are not an admission decision or a count of independently proven defects. Nonterminal scenario routes, external platform providers, fixture declarations, and unknown extraction fields require the interpretation documented in the README.

The frozen repository snapshot includes working testimony. At close, `docs/entity-search-closure-review-2026-09-06.md` had changed since capture, and Git state differed. This task performed no Harness writes. The captured database generation remains frozen; a later `npm run refresh` will create a new observation generation. The capsule source files themselves remained byte-identical during the closing source comparison.

## Start inspecting

```powershell
Set-Location C:\lab\sidefx-database
npm run query -- --file sql/diagnostics/start-here.sql
```

Or use a SQL client connected to the configured database:

```sql
SELECT *
FROM sidefx.v_capability_health
ORDER BY finding_count DESC, capability_id;
```

See [README](../README.md), [data dictionary](data-dictionary.md), and [architecture questions](../sql/diagnostics/architecture-questions.sql).
