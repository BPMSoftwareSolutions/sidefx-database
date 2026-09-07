Yes. **This is where we need to be ruthless about the ontology before writing tables.** The database needs to speak SDA natively. If we get the nouns or relationships wrong now, SQL will make the wrong model feel legitimate simply because it is easy to query.

There are a few places where I would tighten what we just discussed.

# 1. Start with the fractal as the relational spine

The center is still:

```text
CAPABILITY
    │
    └── has SCENARIOS
               │
               ├── INPUT
               ├── EVENT
               └── OUTCOME
                       │
                       └── ESTABLISHES PRODUCT
                                  │
                                  └── SATISFIES downstream INPUT
```

That is not just an explanatory diagram. It should be visible in the foreign keys.

ADR-001 is explicit about this semantic backplane:

```text
Capability A
  -> Outcome A
  -> ESTABLISHES Product A / Observable State
  -> SATISFIES admitted Input B
  -> Capability B
```

It is also explicit that **Outcome and Product are related but are not interchangeable authority.** 

So I would freeze these as distinct entities:

```text
Capability
Scenario
ScenarioInput
ScenarioEvent
ScenarioOutcome
Product
Contract
```

### Cardinality

```text
Capability 1 ─────── * Scenario

Scenario   1 ─────── 1 Input
Scenario   1 ─────── 1 Event
Scenario   1 ─────── 1 Outcome

Outcome    1 ─────── * Product

Product    * ─────── * downstream Input
           through governed blueprint/backplane relationships
```

I would allow **one Outcome to establish multiple Products**. We don't want to paint ourselves into `Outcome = one blob of data`.

---

# 2. Product does **not** need another schema system

This is our first duplication trap.

We should **not** have:

```text
InputSchema
OutcomeSchema
ProductSchema
PortSchema
```

as independent schema entities.

We have:

```text
CONTRACT
```

with versioned contract definitions.

Then:

```text
ScenarioInput ────── uses ──────► ContractVersion

ScenarioOutcome ──── uses ──────► ContractVersion

Product ──────────── conforms ──► ContractVersion

Port ─────────────── consumes /
                                  produces ContractVersion
```

The same contract may legitimately be used by several semantic objects.

So:

```text
contract
contract_version
```

own the JSON Schema bytes.

Everything else references them.

**No duplicated schema definitions.**

---

# 3. Scenario is the named behavioral unit

I agree completely here.

I would not create another thing called `Behavior`, `ScenarioBehavior`, or `BehavioralUnit`.

```text
Scenario
=
named behavioral unit
+
Input
+
Event
+
Outcome
```

The database should make that painfully obvious.

Something like conceptually:

```text
capability
    capability_pk
    capability_id

scenario
    scenario_pk
    capability_pk FK
    scenario_id
    name
```

with:

```text
UNIQUE(capability_pk, scenario_id)
```

Then:

```text
scenario_input
    scenario_pk PK/FK
    input_id
    contract_version_pk FK

scenario_event
    scenario_pk PK/FK
    event_id
    execution_authority_pk FK

scenario_outcome
    scenario_pk PK/FK
    outcome_id
    contract_version_pk FK
```

Using `scenario_pk` as the primary key of each face gives us **at most one Input, Event, and Outcome per Scenario structurally**.

Then our integrity evaluator verifies that every canonical Scenario has all three.

---

# 4. Event and Execution Authority are not duplicates

Another place to be careful.

```text
Scenario Event
```

is semantic.

It says:

> **What meaningful responsibility occurs?**

`ExecutionAuthority` answers:

> **How is that responsibility declaratively resolved?**

Therefore:

```text
ScenarioEvent
       │
       └── governed by
              │
              ▼
      ExecutionAuthority
              │
              └── has
                  ExecutionOperations[]
```

And the current change-plane design already treats execution authorities and their operations as a distinct governed layer. The operation vocabulary is currently bounded to things such as `invoke-port`, `invoke-scenario`, and `project-state`. 

So:

```text
scenario_event
execution_authority
execution_operation
```

are all legitimate separate entities.

---

# 5. Operation and Mechanic are also **not** the same thing

This distinction matters.

I would model:

```text
EXECUTION OPERATION
=
a declared execution step belonging to execution authority

MECHANIC
=
a reusable bounded primitive that performs a class of work
```

So:

```text
ExecutionAuthority
     │
     └── Operations
             │
             ├── INVOKE_SCENARIO
             │
             ├── INVOKE_PORT
             │
             └── PROJECT_STATE
                       │
                       ▼
                    Mechanic
                    where applicable
```

Mechanics should have **one canonical identity across the estate**.

For example:

```text
mechanic
    mechanic_pk
    mechanic_id UNIQUE

mechanic_version
    mechanic_version_pk
    mechanic_pk
    version
    authority_digest
```

If 47 capabilities use `path.v1`, we should have:

```text
1 mechanic
47 usages
```

not:

```text
47 mechanics named path
```

That's exactly the kind of garbage SQL should expose immediately.

---

# 6. Provider Mechanic should be a relationship, not another Mechanic

This is another major one.

I do **not** want:

```text
Mechanic
ProviderMechanic
```

to become parallel semantic definitions.

Instead:

```text
MECHANIC
     │
     │ can be realized by
     ▼
PROVIDER MECHANIC IMPLEMENTATION
     │
     ▼
PROVIDER
```

So conceptually:

```text
provider
provider_definition
mechanic
provider_mechanic_implementation
```

where:

```text
provider_mechanic_implementation
    provider_definition_pk FK
    mechanic_version_pk FK
    implementation_profile
    evidence/proof refs
```

The provider mechanic row says:

> **Provider X claims/proves that it can physically realize Mechanic Y.**

It does **not** create `Provider-X-Mechanic-Y` as new semantic meaning.

That's important.

---

# 7. Provider itself gets one stable identity

Same pattern.

Not:

```text
Azure-SQL-provider-for-capability-A
Azure-SQL-provider-for-capability-B
Azure-SQL-provider-for-capability-C
```

We want:

```text
Provider
    provider_id = azure-sql
```

and then versioned definitions:

```text
Provider
    │
    └── ProviderDefinition v1
    └── ProviderDefinition v2
```

Then relationships say what that provider supplies.

```text
ProviderDefinition
     │
     ├── implements Port A
     ├── realizes Mechanic B
     ├── supplies Capability C
     └── supports Profile D
```

That gives us genuine provider reuse and impact analysis.

---

# 8. Port and Provider Slot are **different things**

This one is crucial.

I would define the distinction as:

> **Port = the governed interface through which a mechanic/capability may be exercised.**

> **Provider Slot = a place in a blueprint where realization is required but provider identity remains subordinate/replaceable.**

So:

```text
PORT
=
what must be physically callable
```

versus:

```text
PROVIDER SLOT
=
where this circuit requires a qualifying provider
```

Then:

```text
ProviderSlot
      │
      │ requires
      ▼
     Port
      │
      │ implemented by
      ▼
ProviderPortImplementation
      │
      │ selected through
      ▼
ProviderBinding
```

This gives us a very clean chain:

```text
SCENARIO EVENT
      ↓
EXECUTION AUTHORITY
      ↓
EXECUTION OPERATION
      ↓
PORT REQUIREMENT
      ↓
PROVIDER SLOT
      ↓
PROVIDER BINDING
      ↓
PROVIDER DEFINITION
      ↓
PROVIDER MECHANIC
      ↓
PHYSICAL EFFECT
```

And crucially:

### `ProviderBinding` is **not** `ProviderPortImplementation`.

One says:

> Provider X *can* implement this port.

The other says:

> **For this exact slot/environment/profile, Provider X has been selected.**

That distinction will be incredibly valuable later.

---

# 9. Therefore I want this provider model

```text
PROVIDER
    │
    └── PROVIDER DEFINITION
              │
              ├── PROVIDER PORT IMPLEMENTATION
              │         │
              │         └── PORT
              │
              └── PROVIDER MECHANIC IMPLEMENTATION
                        │
                        └── MECHANIC


BLUEPRINT PROVIDER SLOT
          │
          │ requires
          ▼
        PORT
          │
          ▼
   PROVIDER BINDING
          │
          ▼
PROVIDER PORT IMPLEMENTATION
```

That is much stronger than:

```text
port
provider
binding
```

because now we can distinguish **eligibility** from **selection**.

And we can query:

```sql
Which providers can satisfy this port?

Which provider is currently bound?

Which mechanics does that provider use?

What other providers could replace it?

Which slots have only one eligible provider?

Which provider change affects which capabilities?
```

ADR-001 explicitly requires the estate to trace a provider or mechanic through the semantic backplane to affected capabilities, contracts, targets, and proof obligations. 

---

# 10. Blueprint cannot become another copy of the capability

This may be the biggest database-integrity rule.

The blueprint should **reference**:

```text
Scenario
Input
Event
Outcome
Product
Mechanic
ProviderSlot
Contract
```

It should not redefine them.

The accepted law says exactly that: feature authority owns promise and root Input/Event/Outcome meaning, blueprint authority owns designed topology, and downstream representations reference rather than re-author upstream facts. A repeated representation that can drift is duplicate authority. 

So:

```text
blueprint
blueprint_node
blueprint_edge
```

are legitimate.

But `blueprint_node` should say:

```text
Node X
kind = responsibility
semanticRef = Event Y
```

rather than copying:

```text
eventId
eventName
contractId
executionAuthorityId
...
```

all over again.

---

# 11. I would introduce one **thin identity spine**

Normally I don't love generic entity tables.

But we have one legitimate need: blueprint nodes, evidence, semantic addresses, dependency analysis, and Cross-Apply need to reference heterogeneous objects safely.

So I would allow:

```text
semantic_object
    semantic_object_pk
    object_kind
    canonical_id
```

But **that table owns zero meaning**.

Think:

```text
semantic_object
=
global address book
```

not:

```text
semantic_object
=
generic JSON junk drawer
```

Concrete meaning lives in:

```text
scenario
scenario_input
scenario_event
scenario_outcome
product
mechanic
port
provider_slot
...
```

Each concrete entity has a corresponding semantic identity.

That lets:

```text
blueprint_node.semantic_object_pk
```

point safely to anything the blueprint is representing without inventing weak strings like:

```text
subjectType = 'outcome'
subjectId = 'foo'
```

all over the schema.

---

# 12. Blueprint edges should preserve the four orthogonal dimensions

The accepted blueprint design is very clear here. An edge is **not just a transition**.

It carries separate meanings:

```text
Topology
Contract Relation
Semantic Progress
Selecting Variant
```

The allowed dimensions include things such as:

```text
Topology
────────
TRANSITION
BRANCH_ROUTE
FAN_OUT_MEMBER
CONVERGENCE_REQUIREMENT
ALTITUDE_DESCENT
BOUNDED_RETURN

Contract
────────
SATISFIES
REQUIRES

Progress
────────
NARROWS
ESTABLISHES
TERMINATES
DESCENDS
BOUNDED_RETURN
```

Those dimensions must never be collapsed into one generic relationship type. 

So I would have:

```text
blueprint_edge
    blueprint_edge_pk
    blueprint_pk
    from_node_pk
    to_node_pk

    topology_role
    contract_relation       NULL where not applicable
    semantic_progress
    selecting_variant_pk    NULL except where applicable

    binding_authority_digest
    projection_ordinal
```

**Not**:

```text
relationship_type = "approved-branch-narrows-satisfies"
```

That would be awful.

---

# 13. OutcomeVariant deserves an entity

Because variants own decisionality.

Not the branch.

Not the code.

Not some decision-node table.

So:

```text
scenario_outcome
      │
      └── outcome_variant[]
```

Then:

```text
blueprint_edge.selecting_variant_pk
        ↓
outcome_variant
```

This lets SQL answer:

```sql
Which outcome variants have no route?

Which variants terminate?

Which variants establish products?

Which variants descend to providers?

Which branches are never exercised by fixtures?
```

Beautiful.

---

# 14. Convergence should not become another inferred relationship

The blueprint law says multiple inbound arrows do **not** mean convergence. Convergence is explicit and declares the complete set of required upstream products. 

Therefore:

```text
blueprint_node.kind = CONVERGENCE
```

plus:

```text
blueprint_edge.topology_role =
CONVERGENCE_REQUIREMENT
```

gives us the required products.

We don't need:

```text
convergence
convergence_input
convergence_product
```

as a parallel semantic model unless later evidence proves we need more attributes.

Initially, that would duplicate the blueprint topology.

---

# 15. C4 Components should remain structural mappings

You mentioned components.

I would absolutely ingest them, but don't confuse:

```text
Component
```

with:

```text
Capability
```

A C4 component is a **structural realization lens**.

So:

```text
c4_context
c4_container
c4_component
c4_code_mapping
```

should reference semantic identities and blueprint identities.

For example:

```text
Capability X
   ↓ projected structurally as
Container A
   ↓
Component B
```

The Component doesn't become the capability.

The ADR explicitly describes C4 as a governed structural lens over blueprint/execution/physical authority rather than another semantic authority. 

---

# 16. Semantic Authority itself should **not** be one giant entity

I would avoid:

```text
semantic_authority
    id
    json
```

as the canonical relational model.

Because **which authority?**

We already have distinct owners:

```text
Feature Authority
Blueprint Authority
Capability Authority
Execution Authority
Transformation Authority
Interface Authority
Contract Authority
Provider Authority
Proof Authority
...
```

So the raw-source layer can absolutely have:

```text
canonical_object
    digest PK
    bytes
    authority_kind
    source_path
```

But the semantic model should break those bytes into their **actual nouns**.

The DB-native design already states that the canonical bytes remain identity and that normalized relational projections are rebuildable query structures rather than semantic authority. 

---

# 17. Contracts and their definitions

I would use:

```text
contract
    contract_pk
    contract_id

contract_version
    contract_version_pk
    contract_pk
    version
    schema_object_digest
    schema_dialect
```

With:

```text
UNIQUE(contract_id)

UNIQUE(contract_pk, version)

UNIQUE(schema_object_digest)
```

Then don't duplicate schemas elsewhere.

This is also where we can start seeing:

```sql
same schema digest
different contract identity
```

which may reveal accidental semantic duplication.

And conversely:

```sql
same contract identity
different schema digest
same version
```

which should be a screaming integrity finding.

---

# 18. Stable identity and version need to be separated everywhere important

This is a major PK decision.

I do **not** want:

```text
capability row = capability version
```

because then the same capability appears fifteen times and looks like fifteen capabilities.

Use:

```text
Capability Identity
        │
        ├── Version 1
        ├── Version 2
        └── Version 3
```

Same for:

```text
Provider
Contract
Mechanic
Port
Blueprint
```

So:

```text
capability
    capability_pk PK
    capability_id UNIQUE

capability_version
    capability_version_pk PK
    capability_pk FK
    version
    authority_digest
```

And:

```text
UNIQUE(capability_pk, version)
UNIQUE(authority_digest)
```

This gives us:

> **186 versions of 160 capabilities**

instead of incorrectly saying:

> **186 capabilities**

if we ever have multiple versions loaded.

---

# 19. Source provenance gets attached to every normalized fact

This matters because this is an **inspection database**.

Every normalized fact should know:

```text
estate_snapshot
source_object_digest
source_json_pointer
derivation_rule
```

At minimum.

I want to click:

```text
provider_binding 734
```

and ask:

> Where exactly did you come from?

and get:

```text
Estate generation   sha256:...
Capsule              ...
Authority document   interfaces.authority.json
Document digest      sha256:...
JSON pointer         /ports/2/binding
```

Then there is no:

> “The database says…”

No.

**The database says the canonical bytes at this exact address said.**

---

# 20. We should NOT let bad data prevent ingestion

This is subtle but incredibly important.

If the current estate contains:

```text
missing contract
duplicate scenario id
orphan provider slot
invalid binding
missing event authority
```

I **want that shit in the database.**

If our relational constraints simply reject the load:

```text
FOREIGN KEY violation
```

then the database becomes incapable of showing us the problem we're trying to find.

So I would have:

### Raw/source truth

```text
canonical_object
source_observation
```

Never loses anything.

### Normalized facts

As much referential integrity as possible without fabricating missing relationships.

### Integrity findings

```text
integrity_finding
    finding_pk
    snapshot_pk
    semantic_object_pk
    finding_code
    severity
    expected
    observed
    source_digest
    source_pointer
```

### Clean views

```text
v_admitted_scenario
v_closed_provider_binding
v_contract_integrity
...
```

So malformed estate state is **observable rather than un-loadable**.

---

# The relational core I would freeze

If I strip everything down, **this is the schema spine I want before loading a byte**:

```text
IDENTITY + PROVENANCE
────────────────────────────────
estate_snapshot
canonical_object
semantic_object


CAPABILITY / FRACTAL
────────────────────────────────
capability
capability_version

scenario
scenario_version

scenario_input
scenario_event
scenario_outcome
outcome_variant

product

contract
contract_version


EXECUTION
────────────────────────────────
execution_authority
execution_authority_version
execution_operation

transformation
mechanic
mechanic_version


PORT / PROVIDER
────────────────────────────────
port
port_version

provider
provider_definition

provider_port_implementation
provider_mechanic_implementation

provider_slot
provider_binding


BLUEPRINT
────────────────────────────────
blueprint
blueprint_version

blueprint_node
blueprint_edge


STRUCTURE
────────────────────────────────
c4_context
c4_container
c4_component
c4_code_mapping


PROOF / OBSERVATION
────────────────────────────────
fixture
fixture_assertion
proof_obligation
evidence
integrity_finding
```

I don't see obvious semantic duplication in that set.

---

# And these are the relationships that matter most

```text
CAPABILITY
    1 ──── * SCENARIO

SCENARIO
    1 ──── 1 INPUT
    1 ──── 1 EVENT
    1 ──── 1 OUTCOME

INPUT
    * ──── 1 CONTRACT VERSION

OUTCOME
    * ──── 1 CONTRACT VERSION

OUTCOME
    1 ──── * PRODUCT

PRODUCT
    * ──── 1 CONTRACT VERSION


EVENT
    * ──── 1 EXECUTION AUTHORITY

EXECUTION AUTHORITY
    1 ──── * EXECUTION OPERATION


EXECUTION OPERATION
    * ──── * MECHANIC          where applicable

EXECUTION OPERATION
    * ──── PORT                for invoke-port

EXECUTION OPERATION
    * ──── SCENARIO            for invoke-scenario


PROVIDER
    1 ──── * PROVIDER DEFINITION

PROVIDER DEFINITION
    1 ──── * PROVIDER PORT IMPLEMENTATION

PROVIDER PORT IMPLEMENTATION
    * ──── 1 PORT

PROVIDER DEFINITION
    * ──── * MECHANIC
            through provider_mechanic_implementation


PROVIDER SLOT
    * ──── 1 required PORT

PROVIDER BINDING
    * ──── 1 PROVIDER SLOT
    * ──── 1 PROVIDER PORT IMPLEMENTATION


BLUEPRINT
    1 ──── * BLUEPRINT NODE
    1 ──── * BLUEPRINT EDGE

BLUEPRINT NODE
    ──── references canonical semantic object

BLUEPRINT EDGE
    ──── topology
    ──── contract relation
    ──── semantic progress
    ──── selecting Outcome variant
```

And then the entire backplane reappears:

```text
Outcome
   │
   └── ESTABLISHES
          │
          ▼
       Product
          │
          └── SATISFIES
                 │
                 ▼
         downstream Input
                 │
                 ▼
             Scenario
                 │
                 ▼
            Capability
```

**That looks like SideFX.**

Not a generic application database with our concepts shoved into it.

---

## One thing I would deliberately leave unresolved

I would **not create a canonical `transition` table yet.**

This is important.

The current database-native review found that today's estate carries scenario ordering in two different places—24 capabilities through semantic-graph transitions and 80 through `invoke-scenario` execution operations—while the accepted architecture says **the blueprint owns the topology**. The unresolved D0 decision is specifically how blueprint-owned topology should project into those downstream representations. 

So initially I would ingest them honestly as:

```text
observed_semantic_graph_transition

observed_execution_scenario_invocation

canonical_blueprint_edge
```

and **not pretend we've already decided that one of those is the canonical transition entity**.

Then SQL can show us:

```text
Blueprint     A → B
Graph         A → B
Execution     A → B
```

or:

```text
Blueprint     A → B
Graph         A → B
Execution     A → C
```

or:

```text
Blueprint     absent
Graph         empty
Execution     A → B
```

That's exactly the shit we want to see.

**Don't let the relational model prematurely answer D0 for us.**

That, to me, is the integrity line.

If we freeze this ontology before the first full load, then the database becomes what you're after: **a relational embodiment of the SideFX fractal and semantic backplane, not another accidental interpretation of the Harness.**

---

Exactly. **Once the estate is relational, monotonic circuit design stops being an architectural principle we merely inspect—it becomes something the database can actively police.**

The canonical blueprint already defines the fractal geometry:

```text
Scenario cell
Input → Event → Outcome

Execution cell
Input → Responsibility → Result

Mechanic cell
Input → Mechanic → Result

Provider cell
Physical Input → Native Operation → Physical Result
```

with authority expanding downward and evidence returning upward. 

SQL can turn that into a genuine **circuit control plane**.

## The database can know every cell

Above the concrete semantic tables we just discussed, I would expose a normalized circuit view:

```text
CIRCUIT CELL

cell identity
capability
scenario
altitude

input identity
execution/responsibility identity
outcome identity

incoming routes
outgoing routes

authority digest
blueprint identity
provider slot
proof state
```

Not as competing authority—the canonical Scenario/Event/Mechanic/etc. tables remain the owners—but as a **derived control-plane projection**.

Conceptually:

```text
v_circuit_cell
─────────────────────────────
cell_id
capability_id
blueprint_id
altitude

input_object_id
responsibility_object_id
outcome_object_id

input_contract_id
outcome_contract_id

authority_digest
```

Now I can ask:

```sql
SELECT *
FROM v_circuit_cell
WHERE input_contract_id IS NULL;
```

or:

```sql
SELECT *
FROM v_circuit_cell
WHERE responsibility_object_id IS NULL;
```

or:

```sql
SELECT *
FROM v_circuit_cell
WHERE outcome_object_id IS NULL;
```

Those aren't generic database errors.

They're **broken transistors**.

---

# And monotonicity itself becomes queryable

The circuit law is essentially:

> A cell consumes admitted state and produces either a narrower state, an established state, a descent, a bounded return, or termination.

The blueprint already requires semantic progress to be represented explicitly rather than inferred from physical adjacency or implementation flow. 

So every blueprint edge can carry:

```text
NARROWS
ESTABLISHES
DESCENDS
BOUNDED_RETURN
TERMINATES
```

Now we can create:

```text
v_monotonic_route
```

and ask:

```sql
SELECT *
FROM v_monotonic_route
WHERE semantic_progress IS NULL;
```

That means:

> **We have connectivity without declared semantic advancement.**

That's a serious finding.

Or:

```sql
SELECT *
FROM v_monotonic_route
WHERE from_contract_id <> satisfying_contract_id;
```

Now we're detecting transitions where the state doesn't legitimately feed the next cell.

---

# The control plane can distinguish topology from progress

This is important because:

```text
A → B
```

doesn't tell us enough.

We need to know:

```text
Topology:
TRANSITION

Contract:
SATISFIES

Semantic progress:
NARROWS

Selecting variant:
APPROVED
```

Those are independent facts.

So the relational control plane can detect nonsense like:

```text
BRANCH_ROUTE
with no selecting outcome variant
```

or:

```text
CONVERGENCE_REQUIREMENT
with no required product
```

or:

```text
ALTITUDE_DESCENT
whose target is another scenario-level node
```

or:

```text
TERMINATES
with an outgoing semantic route
```

Now the database is enforcing **circuit grammar**.

---

# Branches become extraordinarily clean

Because decisionality belongs to the outcome variant.

```text
Cell A
Input
  ↓
Event
  ↓
Outcome
  ├── APPROVED
  ├── REJECTED
  └── HELD
```

And the routing plane says:

```text
APPROVED → Cell B
REJECTED → Cell C
HELD     → terminal/hold
```

SQL can immediately answer:

```sql
SELECT ov.*
FROM outcome_variant ov
LEFT JOIN blueprint_edge e
  ON e.selecting_variant_pk = ov.outcome_variant_pk
WHERE ov.terminal = false
  AND e.blueprint_edge_pk IS NULL;
```

Meaning:

> **Nonterminal variant with nowhere to go.**

No static analyzer spelunking through an `if`.

No agent interpretation.

Just a failed circuit route.

---

# Convergence gets even better

Suppose:

```text
Product A ─┐
Product B ─┼─→ Convergence → Input C
Product C ─┘
```

Because convergence is explicit, the DB knows:

```text
required products:
A
B
C
```

At runtime:

```text
A ✓
B ✓
C ✗
```

Therefore:

```text
CELL C NOT ADMISSIBLE
```

Not:

```text
"maybe call the next method?"
```

That lets the control plane distinguish:

```text
topology exists
```

from:

```text
execution is currently admissible
```

That's incredibly important.

---

# Then provider resolution is simply another descent through the circuit

At execution altitude:

```text
Execution Operation
        ↓
Provider Slot
        ↓
Required Port
        ↓
Eligible Provider Implementations
        ↓
Provider Binding
        ↓
Provider Mechanic
```

The database can evaluate:

```text
slot exists                     ✓
port requirement known          ✓
eligible providers              3
current binding                 1
binding admitted                ✓
provider mechanic supported     ✓
provider proof current          ✓
```

Then:

```text
PROVIDER CELL ENERGIZED
```

Or:

```text
NO ELIGIBLE PROVIDER
```

And that failure stays exactly where it belongs.

It does not magically change the scenario's meaning.

---

# That gives us a fantastic estate visualization

Imagine every capability reduced to:

```text
GREEN
closed monotonic circuit

YELLOW
valid circuit, incomplete observation/proof

RED
declared circuit defect

GRAY
not applicable / not presently energized
```

Then:

```text
Capability Estate
      ↓
Circuit Domain
      ↓
Capability
      ↓
Scenario
      ↓
Execution
      ↓
Mechanic
      ↓
Provider
```

You can drill from:

> **Why is this capability red?**

to:

```text
Scenario:
project-capability

Cell:
resolve-target-provider

Finding:
PROVIDER_SLOT_UNBOUND

Required port:
runtime-projection-port.v2

Eligible providers:
0
```

That's a **control room**, not a file browser.

---

# And then execution testimony feeds the same graph

This is where the architecture really snaps together.

Design says:

```text
expected circuit
```

Execution receipts give us:

```text
observed traversal
```

So:

```text
CANONICAL BLUEPRINT
        ↕
OBSERVED EXECUTION
```

Now SQL can tell us:

```text
Designed cells           19
Executed cells           18

Designed routes          23
Observed routes          22

Unexpected routes         0

Missing traversal:
cell:admit-final-outcome

Disposition:
EXECUTION_INCOMPLETE
```

Or more seriously:

```text
Observed route exists
but no corresponding blueprint edge
```

which becomes:

```text
UNDECLARED_EXECUTION_ROUTE
```

That should scream.

---

# This also gives us monotonicity across semantic altitude

We can make another invariant explicit:

```text
Scenario
    ↓ DESCENDS
Execution
    ↓ DESCENDS
Mechanic
    ↓ DESCENDS
Provider
```

and:

```text
Provider testimony
    ↑
Mechanic result
    ↑
Execution result
    ↑
Scenario outcome
```

So an execution mechanic cannot suddenly manufacture new product intent.

A provider cannot promote itself into semantic authority.

Evidence may return upward.

**Meaning may not leak upward from physics.**

That is arguably one of the strongest control-plane rules we could implement.

---

# And SQL becomes the architectural adversary

This is what excites me most about this workspace.

We can write views such as:

```text
v_cells_without_progress
v_routes_without_contract_satisfaction
v_variants_without_routes
v_illegal_altitude_transitions
v_unbound_provider_slots
v_provider_bindings_without_mechanic_support
v_products_without_consumers
v_inputs_without_satisfying_products
v_nonterminal_scenarios_without_routes
v_blueprint_execution_divergence
v_observed_undeclared_routes
v_convergences_missing_requirements
v_mechanics_without_provider_realization
v_execution_operations_without_authority
```

Then one query:

```sql
SELECT *
FROM v_circuit_integrity_findings
ORDER BY capability_id, altitude, cell_id;
```

And you've got the architectural work queue.

---

## Eventually this can become the heart of authoring too

Because once we understand the estate sufficiently, candidate authoring can ask the database:

```text
Current cell?
Required Input?
Required outgoing state?
Known contract?
Known mechanic?
Known provider slot?
Known precedent?
Known clean circuits with this shape?
```

So the agent receives:

```text
CURRENT ALTITUDE
Scenario

CURRENT CELL
resolve-provider-binding

INPUT
UnboundProviderSlot

EVENT
resolve-provider-binding

OUTCOME
BoundProviderSlot

DOWNSTREAM OBLIGATION
execute-bound-provider

KNOWN PRECEDENTS
17 admitted cells

AUTHORIZED SCOPE
close this cell
```

That is **bounded autonomy from the circuit itself**.

The accepted database-native change-plane direction already moves toward durable semantic objects rather than expanded mutable workspaces, while keeping SQL merely as derived access structures. 

So yes: **SideFX Database can give us the mechanical control plane for the monotonic architecture before we even turn mutation on.**

First we make the circuit completely observable.

Then completely queryable.

Then mechanically diagnosable.

And eventually, when we're confident in the model:

> **The database can tell the authoring conveyor exactly which transistor in the capability circuit needs to close next.**

---

## Review disposition: **APPROVE THE ARCHITECTURE BASELINE. HOLD THE DDL.**

This is strong. More importantly, it is **much more careful than our initial conversational model**. It repeatedly refuses to turn convenient SQL assumptions into SideFX truth: scenario faces remain scenario-owned; contract equality does not magically establish compatibility; provider implementation is separated from provider selection and runtime readiness; blueprint topology stays distinct from execution invocation; malformed estate facts remain observable without fabricating valid entities. 

I would **not** send an agent off to build the schema yet, though. There are a handful of physical-model decisions that must be nailed down first. The document itself correctly says this is an architecture review baseline rather than approved DDL. 

### What I think is now genuinely solid

The four-grain model is exactly right:

```text
IDENTITY
    Provider X

DEFINITION
    Exact Provider X definition

ESTATE MEMBERSHIP
    This definition participates in snapshot S

USE
    This exact provider definition is selected/bound here
```

That single distinction will prevent a tremendous amount of garbage. Forty uses of one provider do not become forty providers. Two copies of the same contract file do not become two contracts. Two distinct contract identities using the same schema bytes also do **not** collapse into one contract. 

The scenario model is also right:

```text
Capability
    ↓ owns
Scenario Identity
    ↓ exact definition
Scenario Version
    ├── Input
    ├── Event
    └── Outcome
```

Input/Event/Outcome are **faces of the scenario definition**, not reusable global nouns that happen to have the same label. That keeps the fractal honest:

```text
SCENARIO
=
INPUT → EVENT → OUTCOME
```

while allowing the reusable things *behind* those faces—contracts, execution authorities, products, mechanics—to remain independently shared. 

The provider model may be the strongest part of the document:

```text
Provider Identity
       ↓
Provider Definition
       ├── implements Port
       └── realizes Mechanic

Provider Slot
       ├── requires Port        where declared
       ├── requires Mechanic    where declared
       └── requires Profile     where declared
                 ↓
             Binding
                 ↓
      selected Provider Definition
                 ↓
      exact implementation relationships
```

That is much better than forcing every slot through a port. The document correctly found that current v3 provider slots can be mechanic/profile-driven with no port at all. 

And the monotonic control-plane boundary is now excellent:

```text
DECLARED NARROWS
≠
PROVEN NARROWING

DECLARED PROVIDER IMPLEMENTATION
≠
QUALIFIED PROVIDER

BINDING
≠
RUNTIME READINESS

DESIGNED ROUTE
≠
OBSERVED TRAVERSAL
```

That is exactly the honesty we need.

---

# The first thing I would tighten: **Product identity**

This is the one place where I think the ontology is still slightly ambiguous.

The strategy has:

```text
PRODUCT_DEFINITION
```

but no clearly established:

```text
PRODUCT
→ PRODUCT_DEFINITION
```

And section 4.3 does not include Product among the independently versioned identity/definition families. Yet Product is a first-class participant in the semantic backplane:

```text
Outcome
   ↓ ESTABLISHES
Product
   ↓ SATISFIES
Input
```

We need to make a deliberate choice.

If a Product is **scenario/outcome-owned state with no independent durable identity**, then make that explicit and rename the table accordingly, perhaps conceptually:

```text
scenario_product
```

or:

```text
outcome_product_definition
```

Its identity is then scoped by the scenario/outcome definition.

But if SideFX authority actually gives products durable IDs that survive scenario versions and can be referenced independently from multiple places, then we need:

```text
product
product_definition
```

just like:

```text
provider
provider_definition

contract
contract_version

mechanic
mechanic_version
```

I would **not leave a half-model** where something called `product_definition` exists without clearly stating what owns the corresponding product identity.

That's the one semantic issue I would resolve before proceeding.

---

# Second: make `capability_scenario` impossible to corrupt physically

The conceptual relationship is correct:

```text
CapabilityVersion
       ↓ includes
ScenarioVersion
```

But because a stable Scenario is already capability-owned, the DDL must prevent this kind of impossible row:

```text
Capability A version 7
       ↓
Scenario belonging to Capability B
```

The prose says it cannot happen. Good.

The database must **prove** it cannot happen.

I want the physical model to enforce the equivalent of:

```text
scenario.capability_pk
=
capability_version.capability_pk

AND

scenario_version.scenario_pk
=
capability_scenario.scenario_pk
```

through composite candidate keys/FKs or another mechanically enforceable scheme.

Not loader convention.

Not:

> “Our importer wouldn't do that.”

The same applies throughout the model wherever identity and definition are both referenced.

This database exists precisely because we don't want to trust an agent to maintain those invariants.

---

# Third: the semantic-address registry is correct conceptually—but dangerous physically

I like this:

```text
semantic_object
semantic_object_definition
```

as a **global address book**.

I agree completely that it must contain no semantic payload.

But SQL Server polymorphic integrity is where clever ontology designs go to die.

The document already recognizes the risk:

> if kind-discriminated references cannot be mechanically enforced, use explicit typed reference tables instead. 

I would go even harder:

> **Default to typed references unless the proposed DDL proves the registry can enforce subtype integrity.**

I don't want:

```text
semantic_object_kind = 'SCENARIO'
```

while the associated concrete PK secretly points at:

```text
provider_definition
```

and some application-layer validator is the only thing preventing it.

If the registry implementation cannot make wrong-kind references structurally impossible or reliably rejected at publication, simplify it.

The address spine is convenience.

**Integrity is the product.**

---

# Fourth: provider **qualification** needs an explicit status in the architecture boundary

The document beautifully distinguishes:

```text
Declared Implementation

Qualification Assessment

Binding

Runtime Readiness
```

But only three of those have a very clear relational landing place in the current v1 model.

That's okay **if qualification remains deferred**.

What I want to prohibit is a view quietly doing this:

```text
Provider implements mechanic
+
Provider selected for slot

therefore

eligible_provider = true
```

No.

At static v1, we can say:

```text
DECLARED IMPLEMENTATION     ✓
SELECTION                   ✓

QUALIFICATION               NOT EVALUATED / OUTSIDE CURRENT MODEL
RUNTIME READINESS           NOT EVALUATED / OUTSIDE CURRENT MODEL
```

If current estate authority contains durable qualification declarations that we're ingesting, then they deserve a separately scoped assessment relation.

If not, leave the state visibly unresolved.

This distinction will become extremely important once you start asking:

> “Show me all providers I could switch this slot to.”

Static implementation coverage is not enough to answer that truthfully.

---

# Fifth: `definition_key` and identity namespace are actual DDL blockers

These aren't documentation niceties.

They determine whether your primary and unique keys are correct.

The document correctly calls both out as unresolved. 

For example:

```text
mechanic:path.v1
```

What establishes its stable identity?

Is `.v1` part of the declared ID?

Is it a version label?

Is its namespace:

```text
mechanic
```

or:

```text
platform-mechanic
```

or authority-family-specific?

Likewise:

```text
providerId
platformCapabilityId
portId
providerProfileId
external service ID
```

cannot merely live in:

```text
VARCHAR UNIQUE
```

because those namespaces may overlap legitimately.

Likewise, `exact_definition_key` needs an exact law per family:

```text
canonical semantic digest?
raw authority document digest?
multi-document source-set digest?
explicit declared definition ID?
```

Until those mapping laws exist, **we don't actually know what some of the UNIQUE constraints are**.

So I consider these P0 before schema generation.

---

## The blueprint design is excellent

I would barely touch this section.

This is exactly right:

```text
BLUEPRINT
owns topology

SEMANTIC OBJECTS
own meaning
```

A node says:

```text
"I represent this exact semantic definition."
```

It does **not** reproduce that definition.

And the four-dimensional edge model is essential:

```text
TOPOLOGY
TRANSITION / BRANCH_ROUTE / FAN_OUT_MEMBER / ...

CONTRACT
SATISFIES / REQUIRES

SEMANTIC PROGRESS
NARROWS / ESTABLISHES / DESCENDS / ...

SELECTION
exact outcome variant
```

Those are orthogonal facts. They should never become:

```text
BRANCH_SATISFIES_NARROWS_WHEN_APPROVED
```

as one monstrous relationship type. 

This is precisely what will make the database an effective monotonic-circuit control plane.

---

# The document also got D0 exactly right

This was one of the areas I cared about most.

It refuses to create:

```text
canonical_transition
```

and then arbitrarily load one of these into it:

```text
Blueprint edge
Semantic graph transition
Execution invoke-scenario
Runtime traversal
```

Those are **four different claims**.

The database must retain them separately:

```text
DESIGNED
blueprint topology

PROJECTED / REPRESENTED
semantic graph topology

DECLARED EXECUTION
invoke-scenario operation

OBSERVED
runtime traversal
```

Then later:

```text
DESIGNED ↔ PROJECTED
DESIGNED ↔ DECLARED EXECUTION
DESIGNED ↔ OBSERVED
```

can become conformance relationships.

That is far more valuable than prematurely flattening them into one graph. 

---

# The circuit control plane is now correctly three-layered

This document gives us a cleaner formulation than what we discussed earlier:

```text
LAYER 1
STATIC CIRCUIT INTEGRITY
────────────────────────
Does the declared circuit make structural sense?

faces
variants
routes
altitude
convergence
slots
implementations
contracts


LAYER 2
SEMANTIC / QUALIFICATION ASSESSMENT
────────────────────────
Do the declared pieces legitimately satisfy
one another?

contract compatibility
provider qualification
proof requirements
mapping conformance


LAYER 3
RUNTIME CIRCUIT TESTIMONY
────────────────────────
What actually happened in this exact execution?

selected variant
traversed route
product arrival
provider used
proof currency
outcome admission
```

And importantly:

```text
Layer 1 PASS
does not imply Layer 2 PASS

Layer 2 PASS
does not imply Layer 3 happened

Layer 3 observation
does not redefine Layers 1 or 2
```

**That's a real control plane.**

The strategy explicitly keeps runtime/evidence as a later extension rather than contaminating the first semantic database with run receipts. 

---

## My gate assessment

| Area                                   | Disposition                              |
| -------------------------------------- | ---------------------------------------- |
| SideFX ontology                        | **APPROVE**                              |
| Identity / definition / use separation | **APPROVE**                              |
| Scenario fractal                       | **APPROVE**                              |
| Contract model                         | **APPROVE**                              |
| Execution / mechanic separation        | **APPROVE**                              |
| Provider / port / slot / binding model | **APPROVE**                              |
| Blueprint ownership and edge geometry  | **APPROVE**                              |
| Source-defect preservation             | **APPROVE**                              |
| Circuit-analysis boundary              | **APPROVE**                              |
| Runtime separation                     | **APPROVE**                              |
| Product identity grain                 | **CLARIFY BEFORE DDL**                   |
| Identity namespace mappings            | **BLOCK DDL UNTIL RESOLVED**             |
| Definition-key mappings                | **BLOCK DDL UNTIL RESOLVED**             |
| Scenario-version membership FK design  | **PROVE IN DDL**                         |
| Heterogeneous address enforcement      | **PROVE IN DDL OR USE TYPED REFERENCES** |
| Provider binding/profile multiplicity  | **RESOLVE FROM CURRENT SOURCE PROFILES** |

So my actual verdict is:

> **The ontology is ready. The database is not yet ready to build.**

And that's a good place to be.

We have finally separated the hard conceptual question—

> **What does SideFX actually contain and how are those things related?**

—from the physical question—

> **Exactly how does SQL Server enforce those truths?**

The next artifact should therefore **not be implementation code**.

It should be the thing the document itself calls for:

```text
PHYSICAL DATA MODEL REVIEW

table
↓
row grain
↓
natural identity
↓
surrogate PK
↓
unique keys
↓
FKs
↓
cardinality
↓
source fields
↓
source authority/profile
↓
absence/null rules
↓
conflict handling
↓
lineage
↓
representative query
```

Then we take the **five or six hardest tables first**—`capability/scenario`, Product, Contract, Provider/Binding, and Blueprint—and try to break the model before we load a single capability.

If those survive, we can build this thing with confidence.

---

Yes. **We should stop treating settled SideFX concepts as open design questions.** The remaining work is physical enforcement.

The architecture strategy already gives us the governing law: ontology first; stable identity, exact definition, membership, and use are separate; Scenario owns Input/Event/Outcome; Outcome and Product differ; shared Contracts/Mechanics/Providers are referenced rather than copied; Blueprints own topology; SQL does not invent authority. 

So I would now **freeze the semantic DDL decisions**.

# 1. Product identity: GREEN, first-class

Absolutely.

A Product is not an incidental JSON payload. It is a durable semantic object on the backplane:

```text id="yhhvqf"
Outcome
   ↓ ESTABLISHES
Product
   ↓ SATISFIES
Input
   ↓
Scenario
   ↓
Capability
```

That matters even more with where SideFX is going:

```text id="xflz0t"
Capability:
analyze architecture
    ↓
Product:
architecture analysis

Capability:
compose narrative
    ↓
Product:
narrative

Capability:
project cognitive video
    ↓
Product:
video projection

Capability:
publish video
    ↓
Product:
published media artifact
```

So freeze:

```text id="6og6yt"
product
────────────────
product_pk
namespace_pk
product_id

UNIQUE(namespace_pk, product_id)


product_definition
────────────────
product_definition_pk
product_pk FK
definition_digest
declared_version_label NULL
contract_version_pk FK where declared
semantic_object_definition_pk

UNIQUE(product_pk, definition_digest)
```

Then:

```text id="qwbz56"
outcome_product
────────────────
scenario_version_pk FK
product_definition_pk FK

PK(
  scenario_version_pk,
  product_definition_pk
)
```

And separately:

```text id="7l6if8"
outcome_variant_product
────────────────
outcome_variant_pk FK
product_definition_pk FK

PK(
  outcome_variant_pk,
  product_definition_pk
)
```

No nullable variant trickery.

**Product identity is settled.**

---

# 2. Freeze the entire identity pattern

Every reusable SideFX noun gets:

```text id="lx5h7o"
IDENTITY
    ↓
EXACT DEFINITION(S)
    ↓
ESTATE MEMBERSHIP / USE
```

Therefore:

```text id="74kf22"
capability
capability_version

scenario
scenario_version

product
product_definition

contract
contract_version

execution_authority
execution_authority_version

mechanic
mechanic_version

port
port_version

provider
provider_definition

provider_profile
provider_profile_version

blueprint
blueprint_version
```

This is the rule:

> **Another identity row means another semantic thing. Another definition row means another definition of the same thing. Another use row means another use of an already-known thing.**

That is no longer negotiable.

---

# 3. Definition identity: freeze it as content-addressed

We do not need philosophical ambiguity here either.

For independently governed definitions:

```text id="t5os8k"
definition_digest
=
canonical content-addressed identity
of the exact semantic definition
```

Other digests retain their own meanings:

```text id="bnvljy"
raw_document_digest
        ≠
definition_digest

capsule_digest
        ≠
definition_digest

referenced_authority_digest
        ≠
definition_digest
```

If one semantic definition is assembled from an authority set rather than a single document, its definition digest is over the **canonical definition manifest/source set**, not whichever file the importer happened to encounter first.

The strategy already insists these digest kinds cannot be treated as interchangeable merely because they all begin with `sha256:`. 

Good. Freeze it.

Version labels are aliases over definitions:

```text id="z1xdsy"
"v3"
   ↓
exact definition digest
```

They do **not** create identity.

---

# 4. Namespace is explicit everywhere identity is reusable

No fuzzy global string matching.

Have:

```text id="65xhum"
identity_namespace
────────────────
namespace_pk
namespace_kind
namespace_id

UNIQUE(namespace_kind, namespace_id)
```

Reusable identities carry:

```text id="1v9h1l"
namespace_pk
declared_id
```

So:

```text id="7qbvgi"
UNIQUE(namespace_pk, declared_id)
```

This prevents us from conflating:

```text id="8t8arp"
mechanic:path.v1
provider:path.v1
external-catalog:path.v1
port:path.v1
```

because they happen to share text.

The importer maps each current authority family into its declared namespace.

**No filenames. No display-name deduplication. No guessing.**

---

# 5. Capability → Scenario is frozen

```text id="cnydtc"
capability
    1 ───────── *
scenario
```

Physical model:

```text id="m1b95v"
capability
────────────────
capability_pk
namespace_pk
capability_id

UNIQUE(namespace_pk, capability_id)


capability_version
────────────────
capability_version_pk
capability_pk FK
definition_digest
version_label NULL


scenario
────────────────
scenario_pk
capability_pk FK
scenario_id

UNIQUE(capability_pk, scenario_id)


scenario_version
────────────────
scenario_version_pk
scenario_pk FK
definition_digest
version_label NULL
```

And exact membership:

```text id="u4ldtb"
capability_scenario
────────────────
capability_version_pk
scenario_pk
scenario_version_pk
```

DDL must enforce:

```text id="q098wi"
Scenario.Capability
=
CapabilityVersion.Capability
```

through composite keys/FKs.

Not loader convention.

The strategy already requires that a capability version cannot include another capability's scenario. 

---

# 6. Scenario faces are frozen

No reusable global Input/Event/Outcome nonsense.

```text id="eicard"
ScenarioVersion
   ├── exactly one Input
   ├── exactly one Event
   └── exactly one Outcome
```

Tables:

```text id="z2cizl"
scenario_input
────────────────
scenario_version_pk PK/FK
input_id
input_contract_version_pk FK


scenario_event
────────────────
scenario_version_pk PK/FK
event_id
responsibility
execution_authority_version_pk FK where declared


scenario_outcome
────────────────
scenario_version_pk PK/FK
outcome_id
experience
terminality / declared attributes
```

And:

```text id="nt2hwh"
outcome_variant
────────────────
outcome_variant_pk
scenario_version_pk FK
variant_id
terminal

UNIQUE(
  scenario_version_pk,
  variant_id
)
```

Shared PKs guarantee **at most one face**.

The complete-scenario integrity gate guarantees **all three exist** before the definition appears in `v_complete_scenario`. 

---

# 7. One contract system. Finished.

```text id="zq9gfq"
contract
contract_version
schema_object
```

No:

```text id="r66c8e"
InputSchema
OutcomeSchema
ProductSchema
PortSchema
```

`schema_object` owns deduplicated schema bytes:

```text id="hzfqwf"
schema_object
────────────────
schema_object_pk
content_digest UNIQUE
dialect
content_object_pk FK
```

Then:

```text id="0ttccb"
contract_version
    → schema_object
```

And everything semantic references the exact contract version:

```text id="9lprrn"
ScenarioInput
      → ContractVersion

ProductDefinition
      → ContractVersion

ScenarioOutcome
      → ContractVersion
        only where separately declared

PortDirection
      → ContractVersion
```

Same schema bytes may support different Contracts.

**Shape equality is not semantic identity.** The strategy explicitly establishes that. 

---

# 8. Product satisfaction remains governed topology

Never:

```text id="xjqahx"
same contract_id
therefore
Product satisfies Input
```

Instead:

```text id="ww58aa"
ProductDefinition
        │
        │ explicit governed binding
        ▼
ScenarioInput
```

through the Blueprint.

So:

```text id="y0aj23"
blueprint_edge_contract
────────────────
blueprint_edge_pk PK/FK

contract_relation
    SATISFIES | REQUIRES

product_definition_pk FK
downstream_scenario_version_pk FK

compatibility_authority_definition_pk
    where declared
```

Then:

```text id="nzd03k"
v_product_input_satisfaction
```

can make composition obvious.

---

# 9. Event → Execution Authority → Operations

Frozen.

```text id="v68a5o"
ScenarioEvent
      ↓
ExecutionAuthorityVersion
      ↓
ExecutionOperation[]
```

Tables:

```text id="lyyqqz"
execution_authority
execution_authority_version

execution_operation
────────────────
execution_operation_pk
execution_authority_version_pk
operation_id NULL
ordinal
operation_kind

UNIQUE(authority_version_pk, ordinal)
```

Filtered unique:

```text id="z5miar"
(authority_version_pk, operation_id)
WHERE operation_id IS NOT NULL
```

Then type-specific tables:

```text id="vuk7my"
operation_port_invocation
operation_scenario_invocation
operation_state_projection
```

No giant nullable operation target table.

The current inspected profile uses exactly those operation families, while the architecture correctly refuses to pretend those are universal for all future profiles. 

---

# 10. Mechanic is first-class and globally reusable within its namespace

```text id="oblf6j"
mechanic
mechanic_version
```

And:

```text id="8j03kk"
operation_mechanic
────────────────
execution_operation_pk
mechanic_version_pk
role
```

If 100 capabilities use:

```text id="du375a"
path.v1
```

then:

```text id="0xx90j"
1 mechanic identity
1 or N exact definitions
100 uses
```

Not 100 mechanics.

---

# 11. Provider model is frozen exactly as the strategy now states it

```text id="bic1n5"
Provider
    ↓
Provider Definition
    ├── Port Implementations
    └── Mechanic Implementations
```

Tables:

```text id="q1kzit"
provider
provider_definition

provider_port_implementation

provider_mechanic_implementation
```

### Provider mechanic is a relationship

Not:

```text id="q9qyd6"
ProviderMechanic
=
new mechanic identity
```

It means:

```text id="hcgo2d"
Provider Definition X
REALIZES
Mechanic Version Y
```

Exactly right.

---

# 12. Provider Slot is its own architectural noun

Also frozen.

A slot says:

> **This exact circuit address requires physical realization.**

It may require:

```text id="3s0uda"
Port
Mechanic
Profile
Constraints
```

depending upon its declared profile.

Therefore:

```text id="fx0gh3"
provider_slot
────────────────
provider_slot_pk
blueprint_version_pk
slot_id
owner_node_pk / semantic address

UNIQUE(
  blueprint_version_pk,
  slot_id
)
```

Then typed requirements:

```text id="02qmr5"
slot_port_requirement
slot_mechanic_requirement
slot_profile_requirement
```

No universal fake `port_id`.

The strategy correctly corrected that assumption from observed v3 data. 

---

# 13. Provider implementation and provider selection remain separate

```text id="rs01nu"
ProviderDefinition
CAN IMPLEMENT
Port / Mechanic

        ≠

ProviderDefinition
IS SELECTED
for Slot
```

Therefore:

```text id="qdx47p"
provider_binding
────────────────
provider_binding_pk
provider_slot_pk
provider_definition_pk
binding_context_pk where declared
binding_role where declared
ordinal where profile allows sets
```

And exact selections:

```text id="r8opjs"
binding_port_implementation

binding_mechanic_implementation
```

This proves the binding actually points to implementations belonging to the selected provider definition.

Good.

---

# 14. Qualification is explicitly separate

Freeze the four-state provider concept:

```text id="kqlxvx"
1. DECLARATION
provider claims capability

2. QUALIFICATION
applicable proof/profile evaluated

3. BINDING
provider selected

4. READINESS
this exact run may execute
```

Static v1 models **1 and 3** fully.

If durable qualification authority is present in the captured estate, normalize it separately.

Otherwise:

```text id="6dwkcs"
qualification = NOT_EVALUATED
```

Never infer qualification from declaration + binding.

Runtime readiness stays out of v1.

This distinction is already explicit in the strategy. 

---

# 15. Blueprint is first-class design identity

```text id="1g9siu"
blueprint
blueprint_version
```

Then:

```text id="xrr75c"
blueprint_node
blueprint_edge
```

Blueprint **references meaning**.

It does not copy it.

So a node stores:

```text id="t8kzjt"
node_id
node_kind
altitude
semantic_object_definition_pk
provider_slot/address where applicable
```

not another copied Scenario/Event/Outcome payload.

This directly preserves ADR-001's authority rule as restated in the strategy. 

---

# 16. Semantic address spine: keep it, enforce it

We're not leaving this fuzzy either.

Use:

```text id="vcjpfq"
semantic_object
────────────────
semantic_object_pk
object_kind
namespace_pk
declared_id

semantic_object_definition
────────────────
semantic_object_definition_pk
semantic_object_pk
definition_digest
```

But every concrete table must bind one-to-one to its exact registry address.

No arbitrary:

```text id="b36k3d"
subject_type
subject_id
```

string polymorphism.

If SQL Server cannot enforce the subtype relationship sufficiently through candidate keys/FKs/checks, we fall back to typed reference tables.

**We do not weaken integrity to preserve a clever abstraction.**

That's already the strategy's stated fallback. 

---

# 17. Blueprint edges retain all four independent dimensions

Freeze:

```text id="5zjcow"
blueprint_edge
────────────────

topology_role

contract_relation NULL where N/A

semantic_progress NULL where N/A

selecting_variant_pk NULL where N/A
```

Topology:

```text id="scra1c"
TRANSITION
BRANCH_ROUTE
FAN_OUT_MEMBER
CONVERGENCE_REQUIREMENT
ALTITUDE_DESCENT
BOUNDED_RETURN
```

Contract:

```text id="zr40ku"
SATISFIES
REQUIRES
```

Progress:

```text id="l0m4fq"
NARROWS
ESTABLISHES
TERMINATES
DESCENDS
BOUNDED_RETURN
```

Selection:

```text id="bq1rwo"
exact OutcomeVariant
```

No concatenated relationship type. 

---

# 18. D0 remains correctly separated—but isn't an ontology decision

This distinction matters.

We are **not fuzzy about what topology is**.

Blueprint owns topology.

What D0 still decides is:

> How blueprint-owned topology is projected into downstream semantic-graph and execution representations.

Therefore retain:

```text id="plksp5"
canonical_blueprint_edge

observed_semantic_graph_transition

declared_execution_scenario_invocation

observed_runtime_traversal   later
```

No generic `transition` table that washes those distinctions away.

The strategy explicitly protects this boundary. 

---

# 19. Monotonic circuit control-plane views are part of the DDL contract

Not an afterthought.

We already know where this is going.

Initial views:

```text id="x9f0ne"
sidefx.v_capability
sidefx.v_capability_version

sidefx.v_scenario
sidefx.v_complete_scenario

sidefx.v_product
sidefx.v_product_input_satisfaction

sidefx.v_contract

sidefx.v_execution_authority
sidefx.v_execution_operation
sidefx.v_mechanic

sidefx.v_provider
sidefx.v_provider_implementation
sidefx.v_provider_binding
sidefx.v_provider_impact

sidefx.v_blueprint
sidefx.v_blueprint_node
sidefx.v_blueprint_edge

sidefx.v_circuit_cell
sidefx.v_circuit_route
sidefx.v_circuit_integrity_findings
```

And those circuit views remain **derived lenses**, not another circuit ontology. 

---

# 20. Source corruption and semantic corruption remain visible

Also frozen.

```text id="u3h5ht"
SOURCE
says something invalid
        ↓
PRESERVE IT

NORMALIZED MODEL
does not fabricate validity
        ↓
FINDING
```

So:

```text id="vtm9z5"
source.estate_snapshot
source.content_object
source.appearance
source.declaration_observation
source.relationship_observation
source.lineage
```

plus:

```text id="2ongpy"
analysis.integrity_finding
analysis.unresolved_reference
analysis.compatibility_assessment
analysis.coverage
```

A missing ID never becomes:

```text id="ydn9dn"
UNKNOWN_123
```

A missing target never produces a fake FK target.

A malformed scenario doesn't get imaginary faces.

This is one of the best parts of the architecture strategy. 

---

# So I would now freeze the DDL families as this

```text id="qu3ktz"
SOURCE
────────────────────────────────
estate_snapshot
content_object
source_appearance
source_classification
source_observation
source_lineage
mapping_rule


IDENTITY
────────────────────────────────
identity_namespace
semantic_object
semantic_object_definition


CAPABILITY FRACTAL
────────────────────────────────
capability
capability_version

scenario
scenario_version
capability_scenario

scenario_input
scenario_event
scenario_outcome
outcome_variant

product
product_definition
outcome_product
outcome_variant_product


CONTRACT
────────────────────────────────
schema_object
contract
contract_version
scenario_outcome_contract
port_contract


EXECUTION
────────────────────────────────
execution_authority
execution_authority_version
execution_operation

operation_port_invocation
operation_scenario_invocation
operation_state_projection

transformation
transformation_version
transformation_expression_node
transformation_expression_child

mechanic
mechanic_version
operation_mechanic


PROVIDER
────────────────────────────────
port
port_version

provider
provider_definition

provider_profile
provider_profile_version

provider_port_implementation
provider_mechanic_implementation

provider_slot

slot_port_requirement
slot_mechanic_requirement
slot_profile_requirement

provider_binding
binding_port_implementation
binding_mechanic_implementation


BLUEPRINT
────────────────────────────────
blueprint
blueprint_version

blueprint_node
blueprint_edge
blueprint_edge_contract
blueprint_convergence_requirement


PROOF DEFINITIONS
────────────────────────────────
fixture
fixture_case
fixture_assertion
observable_condition
proof_obligation


STRUCTURAL PROJECTION
────────────────────────────────
c4_context
c4_container
c4_component
c4_code_mapping


OBSERVED DOWNSTREAM REPRESENTATIONS
────────────────────────────────
observed_semantic_graph_transition
observed_execution_scenario_invocation


ANALYSIS
────────────────────────────────
integrity_rule
integrity_finding
unresolved_reference
compatibility_assessment
coverage_assessment
circuit_assessment
```

That is the model I would now treat as the **DDL architecture baseline**.

---

## What's actually left is mechanical

The remaining work is no longer:

> “Do Products have identity?”

Yes.

> “Are Providers shared?”

Yes.

> “Are Mechanics shared?”

Yes.

> “Does Scenario own Input/Event/Outcome?”

Yes.

> “Does Blueprint own topology?”

Yes.

> “Are Provider capability and Provider binding different?”

Yes.

> “Can a slot be mechanic-based without a port?”

Yes.

> “Can SQL infer compatibility?”

No.

> “Can SQL infer runtime readiness?”

No.

> “Can observed execution rewrite the Blueprint?”

Absolutely not.

Those are settled.

The remaining work is:

```text id="6e8du8"
SOURCE CONTRACT
        ↓
COLUMN MAPPING
        ↓
PK
        ↓
UNIQUE KEY
        ↓
FK
        ↓
CHECK
        ↓
INDEX
        ↓
NEGATIVE TEST
        ↓
REPRESENTATIVE QUERY
```

**That's where we should be now.**

And that is exactly consistent with the strategy's own next gate: review the concrete table/constraint specification and family-by-family source mappings, then build and load the corrected model once. 

So I would stop reopening SideFX semantics and tell the repo agent:

> **The semantic architecture is frozen for DDL design. Produce the complete physical SQL Server specification from this model, including every PK, alternate key, FK, filtered unique constraint, CHECK constraint, source mapping, unresolved-reference behavior, and negative integrity test. No implementation or load begins until that specification is reviewed.**
