Connection string is located in Windows environment variable: sidefx-connection-string
---

# Yes. This is exactly where I’d decouple **inspection** from **mutation**

What you’re describing is not abandoning the Semantic Brain or the database-native change plane. It is creating a **small, brutally practical read-side workspace** that lets *you* take control of the estate before asking agents to change anything.

The operating model should be:

```text
                 AGENTIC HARNESS
              canonical capability estate
                        │
                        │ read only
                        ▼
              SIDEFX DATABASE WORKSPACE
                        │
               snapshot / extract
                        │
          ┌─────────────┴──────────────┐
          ▼                            ▼
   CANONICAL BYTES               RELATIONAL FACTS
   + exact digests               + indexes
   + source lineage              + relationships
          │                            │
          └─────────────┬──────────────┘
                        ▼
                    YOUR SQL
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
       inspect        compare        diagnose
       estate         patterns       defects
          │             │              │
          └─────────────┼──────────────┘
                        ▼
                 CLEAN SEMANTIC MODEL
                        │
                        ▼
             governed change candidates
                        │
                        ▼
                existing conveyor
```

That gives you the thing you’re missing right now:

> **A deterministic microscope over the entire Capability Data Center.**

And the current database-native analysis already gives us strong evidence that this is feasible. It says the estate has been projected into **6,412 JSON documents and fourteen relational indexes**, with hash-bound query receipts. In its words, *observation is solved; mutation is what remains to make equally disciplined.* 

## The one law I would protect from day one

**SQL is the inspection model. It is not the semantic authority.**

That is already the explicit law in the current database-native design: canonical content bytes plus digest remain the artifact identity; relational columns and indexes are **derived, rebuildable access structures**. The SQL schema must not quietly become another authority. 

So every useful normalized row should ultimately be able to answer:

```text
Where did you come from?

estate snapshot
capability
capsule / source artifact
source path / pointer
canonical digest
authority digest
derivation rule
```

That means you can happily do:

```sql
SELECT *
FROM scenario
WHERE ...
```

but you can always drill all the way back to the exact canonical bytes that caused that row to exist.

That is SideFX discipline **with SQL convenience**.

---

# I would make the first workspace deliberately small

Something like:

```text
sidefx-database/
│
├── src/
│   ├── snapshot/
│   ├── ingest/
│   ├── derive/
│   ├── validate/
│   └── query/
│
├── sql/
│   ├── schema/
│   ├── views/
│   ├── diagnostics/
│   └── experiments/
│
├── config/
│   └── harness.json
│
├── receipts/
│
└── README.md
```

**No authoring conveyor. No projector redesign. No capability lifecycle implementation.**

At first its responsibility is just:

```text
Harness
  ↓
observe exactly
  ↓
normalize exactly
  ↓
query freely
```

You can expand capsules into a staging location if that makes extraction easier, but I would make that **disposable staging**, not the durable model. Your more recent architecture already proves all 213 measured capsules are fixture-proven directly from capsule bytes without durable expansion. 

So the database workspace shouldn't develop a dependency on expanded directories if we can avoid it.

---

# The relational model I want you to have

I would divide it into three planes.

| Plane                        | Core relational objects                                                                                                                                         | Purpose                                     |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **Source / provenance**      | `estate_snapshot`, `capability_source`, `canonical_object`, `artifact`, `digest`, `source_pointer`                                                              | Exact reconstruction and traceability       |
| **Semantic / architectural** | `capability`, `feature`, `scenario`, `input`, `event`, `outcome`, `product`, `transition`, `contract`, `schema`, `blueprint_node`, `blueprint_edge`             | What the estate **means**                   |
| **Execution / physical**     | `execution_authority`, `operation`, `mechanic`, `port`, `provider_slot`, `provider`, `provider_binding`, `interface`, `fixture`, `proof_obligation`, `evidence` | How meaning becomes executable and provable |
| **Knowledge / ontology**     | `semantic_term`, `term_relationship`, `classification`, `fact`, `fact_relationship`, `precedent`, `pattern_candidate`                                           | What SideFX **knows about its own estate**  |

And I would resist prematurely creating some giant generic `entity` table.

You want to be able to type:

```sql
SELECT *
FROM scenario;
```

```sql
SELECT *
FROM mechanic;
```

```sql
SELECT *
FROM provider_slot
WHERE provider_id IS NULL;
```

```sql
SELECT *
FROM contract
WHERE consumer_count = 0;
```

That is the whole damned point.

You want the architecture to become **obvious under your fingertips**.

---

# Then put the joins to work

This is where your frustration disappears.

You should be able to ask questions such as:

```sql
-- Which scenario events have execution authority but no
-- resolvable provider slot?

-- Which mechanics occur in only one capability?

-- Which mechanics are duplicated under multiple identities?

-- Which provider slots have multiple incompatible bindings?

-- Which contracts are produced but never consumed?

-- Which inputs have no upstream satisfying product?

-- Which outcomes have no observable conditions?

-- Which scenarios are non-terminal but have no transition?

-- Which transitions reference missing scenarios?

-- Which interfaces point at capabilities that are not admitted?

-- Which fixtures do not exercise all declared outcome variants?

-- Which capabilities contain mechanics that should probably
-- be platform capabilities?

-- Which semantic terms are near-duplicates?

-- Which capability families are using different words
-- for the same concept?

-- Which capabilities contain hidden provider assumptions?

-- Which execution operations are structurally identical
-- across 40 capabilities?

-- Which blueprint identities disagree with observed execution topology?
```

That's the power move.

Today an agent has to rummage around:

```text
open JSON
open another JSON
grep
search
read schema
compare file
forget first file
open first file again
```

Once normalized:

```text
JOIN.
```

The database-native design itself already calls this out: questions such as *every scenario changed by X*, *every contract whose digest changed*, *every capability consuming product A*, *every candidate using operator `if`*, and *every authority mutation not represented in its blueprint delta* become normal queries rather than directory archaeology. 

---

# And I would bring **everything** in

Not just the happy semantic model.

This is important.

If the Harness contains:

```text
capability authority
feature
blueprint
scenario graph
semantic graph
execution authority
contracts
schemas
transformations
fixtures
interfaces
provider authority
ports
slots
mechanics
projection authority
execution plans
conformance
proof receipts
cross-apply evidence
ontology
knowledge
precedent
observations
```

**ingest it.**

Don't start with:

> “What do we think is important?”

Start with:

> **“What actually exists?”**

The Semantic Brain was already designed around exactly this principle: source observation → classification → immutable snapshot → canonical object catalog → explicit relationship/proof graph, with every fact traceable to source bytes and derivation rules. 

Your database workspace can make that model **human-operable through SQL**.

---

# There is one particularly important architectural trap

### Do not normalize ambiguity away.

Your current change-plane review found a live architectural issue around topology projection: blueprint authority owns the designed topology, but the existing estate has topology represented across semantic graph and execution authorities in ways that still require an explicit projection law. 

So initially I would store:

```text
observed_blueprint_route

observed_semantic_graph_transition

observed_execution_invoke_scenario
```

as **three separate observed facts**.

Do **not** immediately manufacture:

```text
canonical_transition
```

by picking whichever representation seems right.

Let SQL expose:

```text
Blueprint says A → B

Semantic graph says A → B

Execution authority says A → C
```

That's gold.

**That's precisely the kind of shit we want the database to reveal.**

The database becomes the instrument that helps us settle D0 rather than silently making D0's decision for us.

---

# Then we build an estate health dashboard out of views

Not a UI yet. SQL views.

```text
v_capability_health
v_scenario_closure
v_contract_usage
v_transition_integrity
v_mechanic_reuse
v_provider_coverage
v_port_binding_integrity
v_slot_resolution
v_fixture_coverage
v_proof_coverage
v_blueprint_execution_parity
v_semantic_vocabulary_drift
v_duplicate_capability_candidates
v_orphan_products
v_unresolved_dependencies
v_projection_anomalies
```

And then something glorious:

```sql
SELECT *
FROM v_capability_health
ORDER BY finding_count DESC;
```

Now you're looking at the estate as an architect, **not asking an agent whether the estate looks okay.**

---

# And this is where the executable-capability scaffold gets much tighter

Once the current estate is relationally visible, you can reverse-engineer what **good** actually looks like.

For example:

```text
All clean capabilities
       ↓
analyze common topology
       ↓
scenario archetypes
       ↓
mechanic profiles
       ↓
provider patterns
       ↓
contract patterns
       ↓
fixture patterns
       ↓
proof patterns
       ↓
AUTHORING CONVEYOR RULES
```

Remember, your own analysis says **four archetypes currently cover 95.8% of the measured estate**. 

That's huge.

Instead of asking an LLM:

> “What's a reasonable scaffold?”

You can ask SQL:

> **“What does our admitted estate prove a scaffold normally looks like?”**

Then:

```text
GENERATE EXECUTABLE CAPABILITY SCAFFOLD
```

can be driven from actual estate statistics and admitted patterns.

Same with candidate authoring.

Same with provisioning.

Same with provider slots.

Same with contract inference.

Same with ontology cleanup.

---

# I would keep mutation out of v1

This is the part I feel strongest about.

First:

```text
SIDEFX DATABASE v1
=
OBSERVE + QUERY + DIAGNOSE
```

Get the whole estate into SQL.

Prove rebuildability.

Run your own queries.

Find the bullshit.

Clean up our understanding of the architecture.

Only after we trust that model do we open:

```text
SIDEFX DATABASE v2
=
SEMANTIC CHANGE CANDIDATES
```

And even then, **never**:

```sql
UPDATE scenario
SET ...
```

as authoritative mutation.

Instead:

```text
SQL analysis
    ↓
proposed semantic operation

rename-semantic-term
add-scenario
replace-contract
bind-provider-slot
add-transition
replace-operation
...
    ↓
canonical candidate object
    ↓
validate
    ↓
digest
    ↓
existing governed lifecycle
```

Which is precisely where the database-native change-plane design is headed: semantic CRUD operates on canonical semantic objects and creates immutable, content-addressed candidate revisions; relational tables remain rebuildable query projections. 

---

# So I see this as two related but separate things

```text
              SIDEFX DATABASE
                  RIGHT NOW

Harness
  ↓
Snapshot
  ↓
Relational Projection
  ↓
SQL
  ↓
Architectural Intelligence
  ↓
Estate Cleanup


              SIDEFX DATABASE
                   LATER

Architectural Intelligence
  ↓
Semantic Mutation Intent
  ↓
Candidate Revision
  ↓
Conform / Review / Prove
  ↓
Seal
  ↓
Publish
  ↓
Harness / Capability Data Center
```

**Read side first. Write side after we understand the truth.**

And this little separate workspace is perfect for that because we can be aggressive in it. We can write ugly SQL. We can tear schemas apart. We can run 500 diagnostic queries. We can discover contradictions. We can experiment without forcing every insight through the Agentic Harness conveyor while we're still trying to understand the estate.

The Harness stays protected.

The database becomes our laboratory.

And once the model is tight enough, **then we push the learning back into the architecture.**

That is exactly the control I think you're looking for.
