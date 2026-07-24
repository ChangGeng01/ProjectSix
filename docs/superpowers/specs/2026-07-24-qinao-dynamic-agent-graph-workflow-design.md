# Qinao Dynamic Agent Graph and Workflow Design

**Status:** User-approved direction; self-reviewed specification awaiting
final user review before controlled-plan convergence.

**Date:** 2026-07-24

**Scope:** Complete Qinao's existing Execution DAG plane with bounded dynamic
Agent collaboration, durable workflow continuation, loop unrolling, recovery,
and proof obligations. This specification does not implement runtime code and
does not create a seventh executable program plan. Its next implementation
step is a focused amendment of the six current 2026-07-23 executable program
plans; runtime work remains assigned to their existing W0-W6 tasks.

## 1. Decision

Qinao adopts a two-level graph model:

1. A template may express finite conditional branches, optional delegation
   slots, joins, remands, and bounded logical loops.
2. An executing Attempt is an immutable DAG. A logical loop is physically
   unrolled into a new invocation, generation, or Attempt whose predecessor is
   a committed terminal receipt.

The model may propose work, delegation, or a Mission Task Graph patch. It
cannot mutate topology, allocate a production slot, choose a production
Provider branch after allocation, spend a budget, publish state, execute an
effect, or adopt its own proposal. Existing deterministic semantic owners
decide; K1-K4 perform their existing bounded mechanisms.

The architecture remains exactly:

```text
14 Semantic LayerCores
4 Physical Kernels
4 bounded ControlRings
7 orthogonal planes
W0-W6
```

This design adds no L15, K5, fifth ControlRing, eighth plane, W7, second
EventLog, second State Market, second context compiler, generic GraphManager,
WorkflowScheduler, AgentLoopManager, recovery registry, or mutable shared
Agent state.

## 2. Why This Shape

Three alternatives were considered:

| Alternative | Benefit | Fatal cost |
|---|---|---|
| Mutable cyclic runtime graph | Flexible and concise | Hidden in-place state, ambiguous crash replay, graph/model authority leakage |
| Rebuild a fresh static DAG for every decision | Simple execution semantics | Excessive recompilation, weak long-task continuity, poor bounded delegation |
| **Finite template plus immutable physical unrolling** | Dynamic behavior with deterministic replay, CAS allocation, and bounded recovery | Requires explicit invocation, closure, and progress receipts |

The third alternative is selected. It fits the already-approved semantic-DAG,
K3, LayerCell, ControlRing, EventLog, Artifact Mesh, and W0-W6 boundaries
without introducing a parallel architecture.

## 3. Existing Mechanisms Are Reused

The implementation plan must extend or compose these incumbent mechanisms:

| Incumbent mechanism | Role in this design |
|---|---|
| `BASLayerCell` | Sole semantic execution membrane for layer-node work |
| `BASLayerCascadeRunner` | Existing join, remand, cancellation, backpressure, and bounded control-loop machinery |
| `BASJoinArtifact` / `BASRemandArtifact` | Existing typed join and remand evidence |
| `BASControlLoopEnvelopePayload` | Existing immutable logical-loop invocation envelope |
| `BASControlLoopProgressWitnessPayload` | Existing monotonic progress evidence |
| `BASControlLoopTerminalReceiptPayload` | Existing loop terminal truth |
| `BASTurnRuntimeStagePlan` | Existing mechanical stage projection |
| `BASNativeStageExecutor` / `BASParallelStageDispatchExecutor` | Existing serial and independent-frontier dispatch mechanisms |
| `BASHardwareAwareScheduler` | Existing resource-mechanism scheduler; it gains no semantic authority |
| `BASTurnRuntimeEngine` | Sole mechanical turn executor after W6 cutover |
| `BASEventLog` plus the one selected K3 `FULL` SQLite writer | Sole durable ordering and state-transition truth; Swift and Rust writers are mutually exclusive migration alternatives, and a Rust writer is admissible only after a sealed single-writer cutover |
| Artifact Mesh | Immutable bodies, contracts, receipts, manifests, and recovery content |
| `BASContextCompiler` | Sole context budget, compilation, binding, and fingerprint authority |
| K1-K4 | Existing lease, neural, state, and sovereign physical mechanisms |

The following incumbents are not promoted:

- `BASAgentFabricMultiRoundLoop`, `BASAgentDelta`, and
  `BASAgentMergeEngine` may supply compatibility lessons and migration
  fixtures only. They are not production graph or adoption authorities.
- `BASSharedStateGraph` remains a business-state projection. It is not an
  execution graph, workflow store, or Agent scratchpad.
- `BASAppleTaskGraphLifecycleExecutor.refresh` must be read-only or
  production-unreachable before W6. It cannot become a second graph writer.
- Provider KV and neural caches are disposable mechanisms, never workflow or
  context truth.

## 4. Five Graph Domains

The five names below distinguish scope and lifetime. They do not create five
stores or owners.

| ID | Domain | Lifetime | Source of truth |
|---|---|---|---|
| G0 | Authority and Capability Graph | Release/authority epoch | Existing Owner Ledger, controlled catalog, capability and release manifests |
| G1 | Semantic Turn Graph | One Attempt | Immutable `BASSemanticTurnDAG` and Attempt-bound bindings |
| G2 | Mission Task Graph | Workspace/mission | Versioned immutable root and K3 CAS transitions |
| G3 | Control Episode Graph | One bounded ring episode | Existing loop envelopes, progress witnesses, budget receipts, and terminal receipts |
| G4 | Execution Trace Graph | Derived observation | EventLog, Artifact IDs, receipts, spans, and replay projection |

### 4.1 G0 is derived and static

G0 is a read-only closure over already-governed owner, capability, package,
entrypoint, release-profile, and reachability facts. There is no G0 database
or graph writer. A model cannot propose a G0 mutation through the runtime
workflow. Authority changes continue through CreateGate, ExtensionGate,
certification, cutover, and operator-governed release.

### 4.2 G1 is immutable per Attempt

An Attempt pins one exact `BASSemanticTurnDAG` digest before execution. The
topology does not change while that Attempt is active. Runtime variability is
expressed only by finite activation, binding, and successor invocation rules
defined in Section 7.

### 4.3 G2 evolves by root replacement

Long-running work survives Session or process interruption through a
Workspace-bound Mission Task Graph. Every accepted mutation creates a new
root; no node or edge is edited in place. Structural history remains
replayable while governed bodies and decryption keys are retained. Erasure may
replace content with the incumbent tombstone/absence proof; replayability does
not override deletion, retention, disclosure, or key-destruction policy.

### 4.4 G3 is not a fifth ControlRing

G3 is the acyclic receipt graph formed when ΩR, ΩG, ΩD, or ΩE runs one or more
bounded invocations. Each next invocation references a committed predecessor
terminal and progress witness. It does not own the ring decision.

### 4.5 G4 has no live control authority

G4 is a query/replay projection. It may explain causality, diagnose stalls,
measure cost, or certify a run. It cannot schedule a node, change readiness,
retry an effect, or mutate a live head.

## 5. Node Semantics

A graph node represents a bounded deliverable contract. It does not represent
an Agent object, Provider, model, actor, process, thread, or hardware core.

The node contract must identify or reference:

- stable node/slot identity and canonical ordinal;
- semantic owner and purpose;
- typed input contract and output contract digests;
- predecessor obligations;
- capability attenuation;
- budget sublease and deadline;
- execution and containment requirements;
- verification, join, and publication obligations;
- terminal and closure rules.

An Agent or Provider is an eligible executor candidate. Replacing an executor
does not change node meaning. A signed compatible fallback is legal only
before K3 allocates the affected production branch and only under the
architecture's complete pre-allocation fallback predicate. After allocation,
the exact route, model, profile, execution plan, ordinal, and materialized
request are immutable under that Attempt root. Any replacement requires a
newly admitted and authorized Attempt; an allocated or possibly started branch
may only be continued, queried, reconciled, sealed, or finalized under its
existing identity.

## 6. G1 Contracts

The W1 first-governed wire must be complete before it is frozen as `1.0.0`.
The already-approved types and spellings in the 2026-07-19 design and
controlled-convergence source must be carried into the current executable
plan set rather than recreated under new names.

The original `runtime.semantic-dag` M Create freezes one stored
`BASSemanticTurnDAG` payload at `1.0.0`. Its complete wire is:

```text
{
  schemaVersion,
  orderedNodes: [BASSemanticTurnNodeContract],
  orderedEdges: [BASSemanticTurnEdge],
  orderedInputPorts: [BASSemanticTurnInputPortContract],
  orderedAlternativeGroupContracts:
    [BASSemanticTurnAlternativeGroupContract],
  orderedNodeApplicabilityContracts:
    [BASSemanticTurnNodeApplicabilityContract],
  orderedDelegationSlotContracts: [BASDelegationSlotContract],
  orderedJoinContracts: [BASSemanticTurnJoinContract],
  terminalNodeSlotID
}
```

`BASSemanticTurnNodeContract` is:

```text
{
  nodeID,                         // closed BASSemanticTurnNodeID
  nodeSlotID,                     // typed semantic-node-slot namespace
  canonicalOrdinal,              // UInt16
  semanticOwnerID,
  executionShape,                // pureDAG | controlRing
  deliverableContractArtifactID,
  deliverableContractDigest
}
```

The governed deliverable contract must reopen under `semanticOwnerID` and
cover every Section-5 purpose/input/output/predecessor/capability/budget/
deadline/containment/verification/join/publication/terminal obligation. It
cannot contain executable model code. Node IDs, node-slot IDs, delegation-slot
IDs, input-slot IDs, and join IDs use distinct typed namespaces.
`executionShape` is a closed, immutable part of the node and enclosing DAG
bytes. It statically selects the node's execution family: `pureDAG` has no
ControlRing envelope, while `controlRing` requires one real incumbent
ControlRing envelope if the node is invoked. A caller, model, recovered
Artifact, or observed envelope presence cannot change this frozen selection.
A source node with neither an incoming input port nor an attached delegation
slot must use `pureDAG`. Every `controlRing` node must therefore have the one
nonempty join required below; an empty synthetic `BASJoinArtifact` is illegal.

Node ordinals are contiguous `UInt16` values starting at zero and
`orderedNodes` is exactly that order. The edge and input-port vectors have
equal cardinality and are paired one-to-one in the same canonical order:
`(consumer-node ordinal, incomingEdgeOrdinal)`. Within each consumer,
`incomingEdgeOrdinal` is contiguous from zero, so no tie-breaker or printable
ID ordering is permitted. Node-applicability contracts are in node order;
alternative groups use `(consumer-node ordinal, groupID encoded bytes)`;
delegation slots use `(slotOrdinal, slotID encoded bytes)`; joins use
`(consumer-node ordinal, joinOrdinal, joinContractID encoded bytes)`. Every
referenced node, port, slot, group, join, owner, and governed contract exists
exactly once.
Unknown fields/tags, nil/default presence, duplicate/order drift, a gap or
overflow in an ordinal, or a vector mismatch fails before ordinary put. The
subtypes are nested values of the one DAG payload, not separately stored
topology Artifacts or new owners.

The DAG's exact public embedded topology inventory is
`BASSemanticTurnNodeContract`, `BASSemanticTurnEdge`,
`BASSemanticTurnInputPortContract`,
`BASSemanticTurnAlternativeGroupContract`,
`BASSemanticTurnNodeApplicabilityContract`, `BASDelegationSlotContract`,
`BASSemanticTurnJoinContract`, and
`BASSemanticTurnJoinMemberContract`. These eight values carry no independent
`schemaVersion`, schema-registry entry, Artifact factory/put, or standalone
governed fixture; their tags/fields are frozen by the enclosing
`BASSemanticTurnDAG` schema and tested through that root. Closed associated
unions are nested under their named containing type, not unlisted public
roots.

`terminalNodeSlotID` names exactly one node. It is the only sink: every other
node has at least one outgoing path to it, and every activated required,
alternative-group, delegation, verification, effect, and publication
obligation reaches it through the frozen role matrix. A one-node DAG may name
its source as the terminal sink. A second sink, an unreachable branch, or a
terminal node that does not cover all required closures is invalid.

The complete DAG has at most `1_018` join members across all joins. This
fail-before-allocation topology bound follows from the incumbent Artifact
identity limit of `1_024` parents: the largest terminal-evidence prefix is the
two IDs of `remanded.successorAttempt`, so four fixed outer parents + two
prefix IDs +
`1_018` disposition IDs is exactly `1_024`. Independently, for every consumer,
its member count plus the complete canonical policy-input count must be at
most `1_024`. Runtime rechecks both bounds before allocating a vector,
constructing an invocation/receipt, committing the K3 terminal row, or
ordinary/historical put. Overflow, a larger governed predicate-reference
closure, or any body/codec bound that is smaller rejects the DAG; K3 may never
commit a terminal row whose historical receipt is unmaterializable.

The same original M Create freezes one governed
`BASSemanticAttemptTerminalReceiptPayload` at `1.0.0` because a pure DAG
Attempt need not have a ControlRing envelope:

```text
{
  schemaVersion,
  attemptRefArtifactID,
  semanticTurnDAGArtifactID,
  disposition:
    completed(terminalNodeReceiptArtifactID)
    | remanded(
        controlRing(remandArtifactID)
        | successorAttempt(
            failedConsumerNodeSlotID,
            failedPredicateArtifactID,
            targetNodeSlotID,
            successorDeliverableContractArtifactID
          )
      )
    | rejectedNoProgress(
        cause:
          deadlocked(deadlockedFrontierDigest)
          | terminalImpossible(
              failedConsumerNodeSlotID,
              failedPredicateArtifactID
            )
      )
    | deferredBudgetExhausted
    | expiredAwaitUser
    | cancelled(cancellationTerminalArtifactID),
  terminalCutDigest,
  orderedTerminalEvidenceArtifactIDs,
  generationVectorArtifactID,
  policyEpoch,
  deletionEpoch,
  sourceEventHighWatermark,
  sourceEventRootArtifactID
}
```

The selected K3 writer's Attempt terminal row is authority; this payload is
its self-ID-free historical projection and is reconstructed/put/reopened only
after that row commits. `completed` requires the exact
`BASSemanticNodeReceipt` for the DAG's designated `terminalNodeSlotID`, its
governed invocation/input dispositions, completed/converged-verified outcome,
and current Attempt/generation/epochs.

At the terminal transaction, K3 freezes one complete disposition closure:
every currently materialized `BASSemanticJoinMemberDispositionPayload` in
`(consumer-node ordinal, member sourceOrder)`. The exact
`orderedTerminalEvidenceArtifactIDs` grammar is the disposition-specific
primary prefix followed by that complete closure:

- `completed`: the designated terminal-node receipt;
- `remanded.controlRing`: the exact `BASRemandArtifact`;
- `remanded.successorAttempt`: the selected consumer's failed-predicate Artifact
  followed by the exact successor-deliverable-contract Artifact;
- `rejectedNoProgress.terminalImpossible`: the selected consumer's exact
  failed-predicate Artifact;
- `rejectedNoProgress.deadlocked`: the exact designated-terminal
  `BASSemanticNodeReceipt` only for Section 13's
  `designatedTerminalNoProgress` basis, and no primary prefix for an ordinary
  `emptyReadyFrontier` basis;
- `cancelled`: the owner-proved terminal-cancellation Artifact; and
- `deferredBudgetExhausted` or `expiredAwaitUser`: no primary prefix.

The closure may be empty only when no join-member disposition exists at that
terminal cut; every prefixed disposition is therefore always nonempty.
No referenced internal field is repeated separately. Duplicate, missing,
foreign, extra, noncurrent, or reordered evidence fails.
`remanded.controlRing` is valid only when the selected failed consumer's
frozen `executionShape` is `controlRing` and the named Artifact reopens against
a real current admitted invocation, nonnil ControlRing envelope, prior use,
progress witness, remaining budget, and failed predicate.
`remanded.successorAttempt` is valid only when that consumer's frozen
`executionShape` is `pureDAG`, its failed slot names the globally selected
failed-cause tuple, the frozen join contract contains the byte-equal
`successorAttemptRemand.permitted` tuple, every started branch is
terminal/drained, and no protected external boundary remains. If a current
admitted invocation exists, it must reopen with
`controlLoopEnvelopeArtifactID` absent, as required by the frozen shape; K3
does not need or define a reverse consumer-keyed proof that an invocation,
admission, budget-use, or start row is absent. An orphan invocation Artifact
without current K3 admission lineage is inert, and an admitted invocation
whose envelope presence disagrees with `executionShape` fails closed. A
`controlRing` consumer whose join fails before a real ring invocation has no
legal remand path; after any earlier protected wait/drain case is excluded,
the failed-predicate priority terminates it through `terminalImpossible`,
never a successor-Attempt remand. Because no remand is legal, a simultaneous
budget/deadline observation cannot replace that already-selected terminal
cause.
`rejectedNoProgress.deadlocked` is legal only for Section 13's K3-recomputed
closed basis, exactly
`emptyReadyFrontier | designatedTerminalNoProgress`. The latter requires the
current owner-proved non-adoptable receipt of the DAG's designated terminal
node; the digest binds its invocation and receipt ID, canonical receipt bytes,
closed outcome, and currentness. The former has no terminal-node receipt and
binds the ordinary no-ready frontier. Both carry their exact
domain-separated digest, and neither may substitute for a more specific
success/cancellation/wait/remand/budget/deadline result.
`terminalImpossible` requires the exact Attempt-global selected consumer/
failed-predicate pair, reopened evidence, and K3 proof that no legal remand
remains.
`deferredBudgetExhausted` and `expiredAwaitUser` require K3 to recompute the
respectively exhausted lease or expired current-boot deadline from its own
row; their terminal-cut digest and source root remain mandatory even when no
separate evidence Artifact exists.

For every disposition, `terminalCutDigest` is exactly lowercase SHA-256 of
the length-prefixed canonical preimage
`"qinao-semantic-attempt-terminal-cut-v1" + attemptRefArtifactID +
semanticTurnDAGArtifactID + canonical disposition tag/payload +
orderedTerminalEvidenceArtifactIDs + generationVectorArtifactID +
policyEpoch + deletionEpoch + sourceEventHighWatermark +
sourceEventRootArtifactID`. It excludes `schemaVersion` and itself. The
constructor and K3 validator independently recompute it; the disposition
therefore cannot be changed independently of its cause/evidence/currentness,
including a deadlocked frontier or failed predicate. A possible-start,
unresolved boundary, quarantine, requested/draining cancellation, heartbeat
timeout, or caller assertion cannot produce this terminal receipt.

The controlled six-plan amendment must add exactly this receipt kind to the
existing addendum K3 receipt factory and its closed
`BASArtifactHistoricalPutPort` allowlist; it must not add a third factory seam
or use generic/current-epoch `put`. The Attempt-terminal transaction persists
the schema version, canonical request bytes, canonical receipt bytes, selected
K3 outcome, resulting source head, complete identity-factory inputs, logical
epoch/time, and commitment-key epoch. Its exact outer identity is
`kind == "semantic-attempt-terminal-receipt"`,
`producerLayerID == .leaseLife`, Attempt scope, the incumbent fixed
canonicalization/confidentiality fields, and ordered parents
`attemptRefArtifactID → semanticTurnDAGArtifactID →
generationVectorArtifactID → sourceEventRootArtifactID → every
orderedTerminalEvidenceArtifactID`. Those parent IDs must be duplicate-free.
The schema remains governed by `runtime.semantic-dag`; the K3 factory only
rematerializes its row-derived historical projection.

A post-commit lost reply reconstructs the byte-identical body and identity
through that sole row-pinned historical seam. Key rotation never substitutes
the active epoch. An unavailable retained key may still return the stored
canonical receipt bytes from K3 history but cannot materialize/adopt the
Artifact; an orphan Artifact without the matching row is inert.

### 6.1 Semantic edge

`BASSemanticTurnEdge` is:

```text
{
  fromSlotID,
  toSlotID,
  dependencyRole,
  consumerInputSlotContractDigest
}
```

The closed `dependencyRole` vocabulary is:

```text
dataConsumption
controlBarrier
authorization
budget
snapshot
verification
effectPredecessor
publicationPredecessor
```

These roles describe semantic dependency. Scheduling priority, Agent role,
Provider identity, hardware placement, retry state, and mutable output do not
belong in this enum.

The four-field edge wire remains unchanged. Conditional applicability and the
consumer's concrete input position are represented by a separate immutable
`BASSemanticTurnInputPortContract` in the same original
`runtime.semantic-dag` M Create:

```text
{
  consumerNodeSlotID,
  incomingEdgeOrdinal,
  consumerInputSlotID,
  expectedDependencyRole,
  expectedInputContractDigest,
  applicability,
  obligation
}

applicability =
  always
  | conditionEvidence(
      evidenceContractDigest,
      evidenceOwnerID,
      ruleID
    )

obligation =
  required
  | alternativeGroup(groupID)
```

The group count is frozen once rather than repeated on each member:

```text
BASSemanticTurnAlternativeGroupContract = {
  consumerNodeSlotID,
  groupID,
  requiredSatisfiedCount          // UInt16, positive
}
```

The DAG carries one canonical input-port vector ordered by the consumer
node's canonical ordinal and then `incomingEdgeOrdinal`, exactly matching the
edge-vector order frozen above. Every incoming edge has exactly one port at
its canonical incoming ordinal; the edge's `toSlotID`, `dependencyRole`, and
`consumerInputSlotContractDigest` must equal the port's consumer,
expected-role, and expected-contract fields. Consumer input-slot IDs and
`(consumerNodeSlotID, incomingEdgeOrdinal)` pairs are unique. Every
`alternativeGroup(groupID)` resolves through exactly one
`(consumerNodeSlotID, groupID)` contract; groups are non-empty, their positive
`requiredSatisfiedCount` does not exceed member cardinality, and one port
belongs to at most one group. A group cannot span consumer nodes. Unknown
applicability or obligation tags fail closed. V1 deliberately has no optional
input-port obligation; optional work is represented only by a bounded
Section-6.3 delegation slot with an exact closure.

The same M Create carries one
`BASSemanticTurnNodeApplicabilityContract` per node:

```text
{
  nodeSlotID,
  allInputsInapplicablePolicy
}

allInputsInapplicablePolicy =
  forbidden
  | permitted(conditionEvidenceVectorContractDigest)
```

This is topology, not runtime state. A condition references an existing
evidence owner and closed rule; it never embeds a model predicate or executes
code from an Artifact.

### 6.2 Dynamic edge binding

Static edges never acquire mutable runtime fields. Attempt-specific evidence
uses the approved `BASSemanticTurnEdgeBinding`:

```text
{
  edgeID,
  predecessorTerminalReceiptArtifactID,
  predecessorOutputArtifactID,
  consumerInputSlotID,
  consumerBindingArtifactID,
  attemptID,
  generation,
  epoch
}
```

The binding is valid only if all referenced artifacts reopen, their contracts
and Attempt/generation/epoch match, the predecessor is terminal, and the
consumer slot is the exact static edge target. A stale or foreign binding
cannot make a node ready.

The static edge does not carry a caller-chosen identity. Before the W1 owner
freezes the first wire, it must freeze one domain-separated `edgeID`
derivation from:

```text
reopened BASSemanticTurnDAG Artifact ID
+ canonical edge ordinal
+ canonical BASSemanticTurnEdge bytes
```

Runtime must recompute that identity; it may not accept arbitrary `edgeID`
bytes. Node ID, static execution slot ID, delegation slot ID, and consumer
input slot ID are distinct typed namespaces. Their serialized bytes are never
interchangeable merely because all are printable as strings.

The W1 `runtime.semantic-dag` owner must also freeze the following exhaustive
role-satisfaction matrix. `predecessorOutputArtifactID` is mandatory typed
evidence for every applicable edge, including non-data barriers:

| `dependencyRole` | Required predecessor condition | Evidence carried by `predecessorOutputArtifactID` |
|---|---|---|
| `dataConsumption` | terminal success under the predecessor output contract | exact consumed output Artifact whose schema/contract digest matches the consumer slot |
| `controlBarrier` | every barrier member has the terminal disposition allowed by the frozen join/remand predicate | exact incumbent `BASJoinArtifact` for a real ControlRing invocation; for a pure DAG join, the exact ordinary-put/reopened `BASSemanticNodeInvocation` Artifact whose `orderedInputArtifactIDs` split into the disposition prefix and canonical policy-input suffix, with every referenced value reopened and the predicate deterministically replayed; or an exact `BASRemandArtifact`/owner-proved terminal evidence selected by that predicate |
| `authorization` | exact current authorization predicate is satisfied | exact L14/K4 authorization/grant/use receipt required by the static consumer contract |
| `budget` | exact lease/use state is current and sufficient | exact K3 `BudgetLease`/latest `BASBudgetUseReceipt` evidence required by the static consumer contract |
| `snapshot` | exact snapshot/generation/epoch predicate is current | exact owner-proved snapshot acquisition/reference evidence required by the consumer |
| `verification` | the required verifier accepted the exact source/output | exact L10 verification receipt over that source/output Artifact |
| `effectPredecessor` | the effect branch has the exact terminal or reconciliation disposition admitted by the consumer | exact Zone-C/K3 effect terminal, reconciliation, or indeterminate receipt named by the frozen predicate |
| `publicationPredecessor` | the publication branch has the exact terminal/close disposition admitted by the consumer | exact publication-journal/K3 finalization or close evidence named by the frozen predicate |

Conditional readiness reuses the current Runtime Task-1 pure readiness
calculation. It reopens typed condition evidence through the exact owner/rule
in the input-port contract and derives `applicable`/`inapplicable`; it does not
introduce a graph-specific skip receipt. An applicable `required` port must be
satisfied, and each applicable `alternativeGroup` must reach its frozen
`requiredSatisfiedCount`; an inapplicable port never counts as success.
Every applicable alternative-group predecessor runs to an owner-proved
terminal disposition; reaching the group count early does not cancel or omit
the remaining members. The frozen group count controls semantic satisfaction,
not speculative scheduling.

For a node with a nonempty input-port set, if every input port is inapplicable,
the node is not invoked only when its
`BASSemanticTurnNodeApplicabilityContract` is `permitted` and the exact
canonical condition-evidence vector matches the frozen digest contract.
Readiness binds that vector into the existing join/remand evidence. This
universal test never applies vacuously to an empty input-port set. A node with
zero input ports but one or more attached delegation slots is a nonempty-join
consumer and resolves those slots normally. A node with neither is the
zero-join `pureDAG` source defined above: incumbent root readiness validates
the current Attempt/head, capability/authority, budget, deadline,
cancellation, and generation/policy/deletion epochs, then admits an invocation
with `orderedInputArtifactIDs == []` and no join/member disposition. Otherwise
the node remains blocked/remanded. There is no synthetic skip terminal, and a
required downstream input is satisfied only by an applicable edge with the
exact role evidence above. `BASSemanticTurnEdgeBinding.consumerInputSlotID`
must equal the unique static port. Optional delegation slots close only
through Section 6.3's existing closure vocabulary.

### 6.3 Delegation slots

The template declares a finite ordered set of
`BASDelegationSlotContract` values. Its complete nested wire is:

```text
{
  slotID,
  slotOrdinal,                    // UInt16
  slotContractDigest,
  parentNodeSlotID,
  allowedProviderStepPurpose,
  allowedProviderOutputRole,
  orderedCandidateProviderRoleIDs,
  maximumInputContractDigest,
  capabilityAttenuationArtifactID,
  budgetCeilingArtifactID,
  deadlineContractArtifactID,
  joinContractID
}
```

`slotContractDigest` is domain-separated over the canonical bytes of every
other field, never over itself. Candidate role IDs are typed, non-empty,
strictly byte-sorted, and duplicate-free. The parent node, join, attenuation,
budget, deadline, purpose, and output role must all resolve inside the
enclosing DAG/Attempt and current governed owners. Slot ordinals are
contiguous `UInt16` values starting at zero. Duplicate IDs or ordinals,
overflow, an open string role/reason, or an absent/default ceiling is invalid.
Canonical total order is `(slotOrdinal, slotID)`.

A Main Agent may emit `BASDelegationProposal` only on its governed internal
proposal branch. Delegation depth is exactly one. A Sub Agent cannot allocate
another Sub Agent. The proposal carries its own stable proposal ID and
canonical digest. `BASDelegationProposal` remains declared in
`BASMemory/BASAgentFabricEnums.swift`; RuntimeCore consumes only its typed
Artifact/reference and must neither redeclare it nor introduce a reverse
package dependency.

The deterministic semantic owner:

1. reopens the proposal and current Attempt;
2. filters eligible unoccupied slots;
3. sorts in canonical slot order;
4. selects the first matching slot;
5. asks K3 to compare-and-swap the proposal ID/digest to that exact slot at
   the current allocation head.

The model, caller, Provider package, App Agent persona, and Sub Agent cannot
choose a production slot or bypass canonical order.

A byte-identical retry reopens the same committed binding. Reusing one
proposal ID with different bytes/digest is corruption. A competing CAS loser
reopens the winning allocation head and recomputes the complete
matching-unoccupied set; it does not try an arbitrary next slot. No match or
exhausted fan-out is a proposal-level deterministic rejection; it does not
pretend that any particular slot rejected after allocation, and every
unoccupied slot later closes as `provedUnused`.

Each optional slot ends in exactly one approved
`BASDelegationSlotClosure` variant:

```text
boundTerminal(childBranchRef, childTerminalReceiptArtifactID)

provedUnused(k3ZeroAllocationProofArtifactID)

rejectedBeforeAllocation(
  reason,
  decisionReceiptArtifactID,
  k3ZeroAllocationProofArtifactID
)
```

`rejectedBeforeAllocation.reason` is the closed encoded enum:

```text
policy-denied
authority-denied
budget-denied
resource-denied
deadline-expired
stale-attempt
```

Started, requested cancellation, unknown, possibly sent, or lease-expired is
not closure.

## 7. Closed Dynamic-Action Grammar

An active G1 Attempt permits only:

1. activate or skip a predeclared node or optional slot according to its
   frozen predicate and current receipts;
2. K3-CAS-bind a bounded Sub Agent or Provider allocation to a predeclared
   slot/branch;
3. append the next bounded invocation under the same ring envelope after its
   committed predecessor terminal/progress receipts;
4. request a same-WorkUnit successor Attempt only through the exact
   strict-quiescent rebase protocol;
5. propose a distinct WorkUnit only through ordinary admission and fresh
   authority.

Receipt-only append is therefore limited to the next invocation of an already
admitted bounded ControlRing. It is not a general successor-creation
authority. A same-WorkUnit successor Attempt is legal only after every old
Provider, visibility, publication, state, and effect boundary is
owner-proved terminal; the old active head is frozen; one expected-head K3 CAS
wins; a fresh Attempt-scoped K4 grant has first been reserved inactive and is
activated only after the winning root is covered; and the successor receives
only the non-widening remaining budget/rights with no deadline extension.
There is never more than one active Attempt or one usable successor grant.
Any unresolved or possibly crossed boundary blocks rebase and enters the
incumbent reconciliation/quarantine path. A new WorkUnit is an independent
ordinary admission, never a disguised retry or resend.

It forbids:

- adding or deleting a G1 node or edge in place;
- modifying a node contract, edge role, slot order, join, or budget;
- direct model-to-model or Sub-to-Sub peer calls;
- mutable shared scratchpads or transcript channels;
- a Provider callback that schedules graph work;
- runtime code rewriting the authority or capability graph;
- treating a trace, cache, timeout, or heuristic as semantic truth.

This closed grammar is mechanically checkable and bounds the state space for
replay, fuzzing, and crash recovery.

## 8. Mission Task Graph Evolution

Architecture Section 14.4 requires a TaskNode/task-graph patch but the current
Owner Ledger has no separate TaskNode/patch owner or planned member. This
specification therefore makes one explicit controlled decision: before the
first W1 implementation, fold the G2 value types below into the already
approved-missing, non-empty `runtime.semantic-dag` M Create at
`BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`.
`BASSemanticTurnDAG` remains the root authority symbol. There is no new owner,
store, writer, scheduler, manager, or allowed source path.

The six-plan amendment must atomically update that existing Owner-Ledger row,
Create candidate manifest/planned-member set, schema registry, fixtures, and
consumer closure. A candidate that adds only part of the wire, changes the
allowed path, or implements K3 behavior before the complete W1 value contract
is rejected. In addition to the G1 members frozen in Sections 6 and 12, the
original M Create must add exactly two independently stored governed payload
roots:

```text
BASTaskGraphJoinEvidencePayload
BASTaskGraphPatchPayload
```

Those two roots have first governed schema `1.0.0`, carry their explicit
`schemaVersion`, receive schema-registry/current-plus-future-rejection
fixtures, and are the only G2 values ordinarily put as independent Artifacts.
Their complete nested public value set is exactly:

```text
BASTaskNodeContract
BASTaskGraphEdge
BASTaskGraphChildHead
BASTaskGraphTerminalBasis
BASTaskGraphParentTerminalOutcome
BASTaskGraphParentAttemptBasis
BASTaskNodeStatusTransition
BASTaskGraphReadPredicate
BASTaskGraphWriteIntent
BASTaskGraphPrecondition
BASTaskBudgetDelta
BASTaskAuthorityDelta
```

These twelve embedded values carry no independent `schemaVersion`, schema
registry entry, Artifact factory/put path, or standalone governed fixture.
Their field order/tags are versioned by the enclosing `1.0.0` payloads and
must be exercised through the canonical and negative fixtures of their
enclosing root; taken together, the two root suites cover all twelve values.

`BASTaskNodeContract.kind` has exactly
the V1 encoded values `mission | objective | workUnit`; `Attempt` is never a
TaskNode. The node wire is:

```text
{
  taskNodeID,
  kind,
  parent,                         // root | parent(taskNodeID)
  canonicalOrdinal,              // UInt16
  semanticOwnerID,
  deliverableContractArtifactID,
  inputContractDigest,
  outputContractDigest,
  maximumDepth,                  // UInt16
  maximumBranches,               // UInt16
  maximumOutstandingAttempts,    // UInt16
  budgetCeilingArtifactID,
  authorityCeilingArtifactID,
  maximumAdmissionDurationNanos, // UInt64
  terminalPredicateArtifactID
}
```

A Mission has no parent; an Objective's parent is a Mission; a WorkUnit's
parent is an Objective. `parent` is a closed presence tag; nil, an empty ID,
and a default parent are invalid. Every Mission has at least one direct
Objective, every Objective has at least one direct WorkUnit, and a WorkUnit
has no TaskNode child. Sibling ordinals are contiguous from zero.
All four maximums are positive, remain
inside the Mission's aggregate graph ceilings, and every descendant ceiling
is non-increasing in the same unit. This field is a duration ceiling, not an
absolute or current-boot time. At first ordinary WorkUnit admission, K3
checked-adds the smallest ancestor duration ceiling to its current monotonic
clock, intersects that result with current policy/warrant limits, and installs
the actual boot-bound deadline only in the existing `BASBudgetLeasePayload`.
Zero, addition overflow, unavailable clock, or a changed boot denies
admission. A successor inherits the earlier installed deadline and never
reapplies the duration ceiling. No UTC/monotonic conversion or mixed deadline
variant exists, and a caller-supplied current-boot scalar is not durable
TaskNode truth. V1 rejects any other shape.
Storage keys on the governed kind tag rather than three hard-coded tables; a
future approved decomposition requires an explicit schema/owner evolution and
never arrives as a caller-defined string. The node's lifecycle value is
exactly `open | completed | cancelled`. A
`BASTaskNodeStatusTransition` binds `{taskNodeID, fromStatus, toStatus,
evidenceArtifactID}`; V1 permits only `open → completed` with exact
owner-proved terminal evidence or `open → cancelled` with exact terminal
cancellation evidence. Requested cancellation, an Attempt failure, timeout,
or possible start is not a TaskNode terminal.

The transition validator branches only by the frozen TaskNode kind and target
status:

- `WorkUnit open → completed` requires `evidenceArtifactID` to reopen the
  current `BASSemanticAttemptTerminalReceiptPayload` with
  `disposition == completed`. Its Attempt reference and terminal generation
  must equal the WorkUnit's current K3 terminal head, and that exact receipt
  ID becomes the accepted status-row terminal evidence. A remanded, rejected,
  deferred, expired, or cancelled Attempt receipt cannot complete a WorkUnit;
- `Objective/Mission open → completed` requires
  `evidenceArtifactID` to reopen the exact
  `BASTaskGraphJoinEvidencePayload` below with
  `parentTerminalOutcome == completed`, the same parent ID/generation/root,
  `parentAttemptBasis == notApplicable`, and a satisfied frozen terminal
  predicate;
- `WorkUnit open → cancelled` requires the join-evidence payload below with
  `parentTerminalOutcome == cancelled`, an empty child vector, and
  `parentAttemptBasis` equal either `neverAdmitted` or an exact
  `terminalAttempt`. The latter binds the current terminal Attempt ref,
  generation, and semantic-Attempt receipt whose disposition is not
  `completed`; the former is legal only when K3 proves no Attempt was ever
  admitted and `activeAttempt == absent`. A current completed Attempt admits
  only the WorkUnit `open → completed` transition, so a later cancellation
  proposal cannot overwrite proven success;
- `Objective/Mission open → cancelled` requires that join-evidence payload
  with `parentTerminalOutcome == cancelled`,
  `parentAttemptBasis == notApplicable`, every child at its accepted terminal
  basis, and every descendant Attempt/effect/publication/Provider boundary
  terminal or quiescent. A request/signal, timeout, merely absent process,
  possible start, or nonterminal Attempt is never terminal evidence.

Mission/Objective completion or cancellation and every WorkUnit cancellation
use the same owner, not the G1 per-Attempt join. Before proposing that terminal
status transition, ordinary Artifact Mesh stores one self-ID-free
`BASTaskGraphJoinEvidencePayload`:

```text
{
  schemaVersion,
  parentTaskNodeID,
  parentGeneration,
  baseTaskGraphRoot,
  parentAttemptBasis: BASTaskGraphParentAttemptBasis =
    notApplicable
    | neverAdmitted
    | terminalAttempt(
        terminalAttemptRefArtifactID,
        terminalAttemptGeneration,
        terminalAttemptReceiptArtifactID
      ),
  orderedChildHeads: [BASTaskGraphChildHead] = [
    {
      childTaskNodeID,
      childGeneration,
      childTerminalStatus,       // completed | cancelled
      terminalBasis: BASTaskGraphTerminalBasis =
        workUnitAttempt(
          terminalAttemptRefArtifactID,
          terminalAttemptGeneration,
          childTerminalReceiptArtifactID
        )
        | childTaskJoin(childJoinEvidenceArtifactID)
        | taskNodeCancellation(terminalCancellationEvidenceArtifactID)
    }
  ],
  parentTerminalOutcome: BASTaskGraphParentTerminalOutcome =
    completed(completionPredicateArtifactID)
    | cancelled(cancellationPredicateArtifactID)
}
```

`BASTaskGraphChildHead` is the concrete public struct represented by each
array member, and `BASTaskGraphTerminalBasis` is the concrete closed public
enum represented after `terminalBasis`; neither is an anonymous Swift/Codable
shape or an independently governed payload.
`BASTaskGraphParentTerminalOutcome` is the concrete closed public enum shown
after `parentTerminalOutcome` and is likewise embedded rather than separately
stored or governed. `BASTaskGraphParentAttemptBasis` is the concrete closed
public enum shown after `parentAttemptBasis` and has the same embedded status.
For a Mission or Objective it is exactly `notApplicable`. For a WorkUnit
cancel it is `neverAdmitted` or `terminalAttempt`; `notApplicable` is
forbidden. `terminalAttempt` reopens the exact current row-pinned
`BASSemanticAttemptTerminalReceiptPayload`, accepts any of its closed
owner-proved terminal dispositions except `completed`, and equality-binds the
receipt's Attempt reference plus K3 terminal generation to the three basis
fields and current head. A completed receipt is legal only as the direct
WorkUnit-completion evidence above. `neverAdmitted` requires K3 to prove no
historical/current Attempt admission, not merely an empty current slot.

Children appear exactly once in the parent's canonical child order. A
WorkUnit basis carries its current terminal `AttemptRef`; an Objective basis
recursively reopens its accepted join evidence. Mission children are
Objectives, Objective children are WorkUnits, and any other basis/kind pairing
fails. `workUnitAttempt` is legal only for a `completed` WorkUnit and its
`childTerminalReceiptArtifactID` reopens the exact Section-6
`BASSemanticAttemptTerminalReceiptPayload` with `disposition == completed`.
Its Attempt reference and `terminalAttemptGeneration` must equal both the
basis and that WorkUnit's current K3 terminal head, and its Artifact ID must
equal the terminal evidence in the WorkUnit's accepted `open → completed`
status row. `childTaskJoin` is legal only for a `completed` Objective; its one
Artifact ID must reopen with `parentTerminalOutcome == completed` and equal
the terminal evidence bound in that child's accepted status row. There is no
second TaskNode terminal-receipt type. `taskNodeCancellation` is legal only
for a `cancelled` WorkUnit or Objective and must equal the exact evidence
bound in that child's accepted status row. It always reopens the exact
`parentTerminalOutcome == cancelled` join evidence described above. For a
WorkUnit that evidence must bind either the exact current
`terminalAttempt` or a K3-proved `neverAdmitted` basis; for an Objective it
must carry `notApplicable`. A remanded, rejected, deferred, expired, or
cancelled Attempt receipt cannot be laundered through `workUnitAttempt`, and
a join-evidence Artifact cannot omit, hide, or replace an admitted WorkUnit
Attempt.
A parent may include a cancelled child only when its selected frozen terminal
predicate explicitly permits that exact disposition; under a `completed`
parent outcome, cancellation never becomes success by default.

The one predicate Artifact ID carried by the selected
`parentTerminalOutcome` variant must equal the parent's frozen
`terminalPredicateArtifactID` and reopen under that node's
`semanticOwnerID`. `completed` evaluates its closed completion rule;
`cancelled` evaluates its closed terminal-cancellation/quiescence rule. The
node's deliverable and terminal contracts use the same mapped owner; an
unknown or caller-invented owner is invalid. Neither rule is model code or a
cancellation request.

The evidence Artifact alone is not task truth. In the same K3 transaction that
accepts a Mission/Objective completion or any TaskNode cancellation, K3
requires
`baseTaskGraphRoot == current taskGraphRoot`, equality-checks the parent and
every child generation/status, and reopens each terminal basis. Every
completed WorkUnit's terminal Attempt reference must equal its current
terminal head and its receipt must be `completed`. Every cancelled child must
equality-match its accepted `parentTerminalOutcome == cancelled` evidence and
have no nonterminal active Attempt; a previously terminal Attempt, when
present, cannot replace or contradict that TaskNode cancellation basis. For a
cancelled parent the vector covers every child and all are terminal; a
never-admitted WorkUnit is the only legal empty-child/absent-active-Attempt
shape. For a WorkUnit completion, K3 instead reopens the exact row-pinned
semantic-Attempt receipt, proves `disposition == completed`, and
equality-checks its Attempt reference/generation against the current terminal
head before accepting the status row. A superseded Attempt, stale recursive
join, missing child, failed required child, changed predicate, nonquiescent
cancellation, request-only signal, or root drift rejects the status
transition. The accepted status row binds this exact evidence Artifact ID, so
completion and cancellation are replayable without introducing a G2 join
writer, cancellation payload, or second `BASJoinArtifact`.

`BASTaskGraphEdge` is
`{edgeID, fromTaskNodeID, toTaskNodeID, dependencyContractArtifactID}`.
Its ID is exactly lowercase SHA-256 of the length-prefixed canonical bytes:

```text
"qinao-task-graph-edge-v1"
+ fromTaskNodeID
+ toTaskNodeID
+ dependencyContractArtifactID
```

The derivation excludes `edgeID` itself. It remains stable when an unchanged
edge is carried into a successor root and is always recomputed rather than
caller-chosen. Self edges, duplicate IDs/endpoints, a parent edge disguised as
a dependency edge, and an edge whose contract cannot be reopened are invalid.

All expected-value unions are explicit:

```text
expectedNode =
  absent
  | present(generation: UInt64, valueDigest: lowerHex64)

expectedEdge =
  absent
  | present(revision: UInt64, valueDigest: lowerHex64)

expectedStatus =
  absent
  | present(
      revision: UInt64,
      status: open | completed | cancelled,
      terminalEvidence: absent | present(artifactID)
    )

expectedAttempt =
  absent
  | present(attemptRefArtifactID, attemptGeneration: UInt64)

expectedBudget =
  absent
  | present(revision: UInt64, bindingArtifactID, valueDigest: lowerHex64)

expectedAuthority =
  absent
  | present(epoch: UInt64, grantArtifactID, valueDigest: lowerHex64)
```

There is no nil/null/default spelling for absence. Revisions, generations, and
epochs are unsigned 64-bit integers and never wrap.

The read set is a canonical sorted vector of closed
`BASTaskGraphReadPredicate` variants:

```text
root(expectedRoot)
node(taskNodeID, expectedNode)
edge(edgeID, expectedEdge)
nodeStatus(taskNodeID, expectedStatus)
activeAttempt(workUnitTaskNodeID, expectedAttempt)
budgetBinding(taskNodeID, expectedBudget)
authorityBinding(taskNodeID, expectedAuthority)
```

For an open status, terminal evidence is absent; for either terminal status it
is present and reopens as the exact owner-proved completion/cancellation
evidence. Read order is the variant rank `root < node < edge < nodeStatus <
activeAttempt < budgetBinding < authorityBinding`, then the canonical typed
ID bytes. The write set uses exactly these closed
`BASTaskGraphWriteIntent` variants:

```text
putNode(taskNodeID, expectedNode, candidateNodeDigest)
putEdge(edgeID, expectedEdge, candidateEdgeDigest)
transitionStatus(
  taskNodeID,
  expectedStatus,
  candidateStatusTransitionDigest
)
updateBudget(taskNodeID, expectedBudget, candidateBudgetDeltaDigest)
updateAuthority(
  taskNodeID,
  expectedAuthority,
  candidateAuthorityDeltaDigest
)
```

V1 has no node/edge deletion or tombstone and no `activeAttempt` write
variant. `activeAttempt` is read/currentness evidence only; the selected K3
writer derives and fences Attempt heads from accepted status, budget,
authority, and strict-successor transitions. An untrusted patch can never
propose or replace an `AttemptRef`.

`putNode(expectedNode: absent, ...)` additionally requires the matching
`nodeStatus(taskNodeID, absent)` read and atomically installs lifecycle
`open`, revision zero, with absent terminal evidence. It cannot initialize a
terminal node. No separate status-transition candidate is emitted for that
deterministic initialization; the new open status row is included in the
derived root.

Write order is the variant rank shown above, then canonical typed ID bytes.
Every write has exactly one same-key currentness read, except that a new-node
write requires both the absent node and absent status reads just specified. It
also maps
bijectively to one same-ID/same-digest member of, respectively,
`candidateNodes`, `candidateEdges`, `statusTransitions`, `budgetDeltas`, or
`authorityDeltas`; every candidate vector member has exactly one write.
Unknown keys, duplicate keys, contradictory expectations, unsorted vectors,
or an unmatched read/write/candidate fails closed.

K3 derives every next row counter; no candidate or caller supplies it. The
complete counter transition table is:

| Write | `absent` expectation | `present` expectation |
|---|---|---|
| `putNode` | install generation `0` | require a different candidate digest and install `checkedAdd(expected.generation, 1)` |
| `putEdge` | install revision `0` | require a different candidate digest and install `checkedAdd(expected.revision, 1)` |
| `transitionStatus` | illegal (except the deterministic new-node `open` row above) | validate the closed status transition and install `checkedAdd(expected.revision, 1)` |
| `updateBudget(preserve)` | install revision `0` from the exact reopened source binding | retain the exact row and revision; this is a currentness assertion, not a physical mutation |
| `updateBudget(attenuate)` | install revision `0` from the exact reopened attenuated binding/proof | install `checkedAdd(expected.revision, 1)` |
| `updateBudget(freshAdmission)` | install revision `0` from the exact reopened admission/install receipts | illegal |
| `updateAuthority(preserve)` | install binding epoch `0` from the exact reopened source grant | retain the exact row and binding epoch; this is a currentness assertion, not a physical mutation |
| `updateAuthority(attenuate)` | install binding epoch `0` from the exact reopened attenuated grant/proof | install `checkedAdd(expected.epoch, 1)` |
| `updateAuthority(freshAdmission)` | install binding epoch `0` from the exact reopened admission/grant receipts | illegal |

An absent-row install is legal only where the corresponding delta-mode rules
below admit a newly governed node. A present `preserve` must reproduce the
same binding/grant Artifact ID and value digest byte-for-byte; it never
silently increments a counter. A patch containing only present-preserve
assertions, or otherwise deriving the same graph root, is a rejected no-op.
Every checked addition is performed before any row, Artifact, EventLog entry,
or projector cursor is written; `UInt64.max` rejects closed and never wraps.

The authority-binding row's `epoch` is specifically the Task Graph binding
revision. It is not copied from, compared numerically with, or substituted
for the referenced grant's policy/deletion/revocation epochs. K3 reopens and
currentness-checks those grant epochs independently. Thus the same immutable
patch bytes plus the same pre-state derive exactly one set of row bytes and
one successor root, and a lost-reply replay can only reopen those bytes.

Preconditions use only these complete closed variants:

```text
rootEquals(expectedRoot)
nodeStatusEquals(taskNodeID, expectedStatus, evidenceArtifactID)
parentTerminal(parentTaskNodeID, terminalReceiptArtifactID)
activeAttemptEquals(workUnitTaskNodeID, expectedAttempt)
governedArtifactReopens(ownerID, artifactID, contractDigest)
```

Their canonical order is the variant rank shown, then typed logical key, then
Artifact ID bytes. Each referenced Artifact must reopen under the named owner
and exact contract. No prose predicate, executable rule, or caller-defined
precondition tag is legal.

`BASTaskBudgetDelta` and `BASTaskAuthorityDelta` are proposals, not leases or
grants. Their distinct exact wires are:

```text
BASTaskBudgetDelta = {
  taskNodeID,
  mode:
    preserve(sourceBudgetBindingArtifactID)
    | attenuate(
        sourceBudgetBindingArtifactID,
        attenuatedBudgetBindingArtifactID,
        attenuationProofArtifactID
      )
    | freshAdmission(
        admissionReceiptArtifactID,
        installedBudgetBindingArtifactID
      )
}

BASTaskAuthorityDelta = {
  taskNodeID,
  mode:
    preserve(sourceGrantArtifactID)
    | attenuate(
        sourceGrantArtifactID,
        attenuatedGrantArtifactID,
        attenuationProofArtifactID
      )
    | freshAdmission(
        admissionReceiptArtifactID,
        installedGrantArtifactID
      )
}
```

`preserve` is byte-identical; `attenuate` must be owner-proved non-widening
and cannot extend the deadline; `freshAdmission` is legal only for a newly
ordinarily admitted Mission root or WorkUnit and only binds an
already-existing exact K3 budget installation or L14/K4 admission/grant
receipt. A new Objective receives only an owner-proved preserve/attenuation
from its parent; it cannot independently widen authority. A patch cannot mint,
edit, amplify, or infer a lease/grant. G0 mutation is unrepresentable.

`BASTaskGraphPatchPayload` is exactly:

```text
{
  schemaVersion,
  patchOperationID,
  baseTaskGraphRoot,
  readSet,
  writeSet,
  preconditions,
  candidateNodes,
  candidateEdges,
  statusTransitions,
  budgetDeltas,
  authorityDeltas
}
```

`candidateNodes` orders by `(ancestryDepth, parent-ID encoded bytes,
canonicalOrdinal, taskNodeID encoded bytes)`; `candidateEdges` by
`(toTaskNodeID, fromTaskNodeID, edgeID)`; and each status/budget/authority
vector by `taskNodeID`, all using canonical typed bytes. Every vector rejects
duplicate identities and its bounded count is enforced before allocation.
Patch Artifact ID plus `patchOperationID` and `baseTaskGraphRoot` supplies the
idempotency identity; the same operation ID with different canonical bytes is
corruption. The patch Artifact is only a proposal. K3 rows remain the physical
truth for roots, generations, `activeAttempt`, budgets, and authority.

`expectedRoot` and `baseTaskGraphRoot` are lowercase SHA-256 values. K3
derives the current Task Graph root from these length-prefixed canonical
preimage components:

```text
"qinao-task-graph-root-v1"
+ schemaVersion
+ ordered current node rows:
     (taskNodeID, generation, BASTaskNodeContract digest)
+ ordered current edge rows:
     (edgeID, revision, BASTaskGraphEdge digest)
+ ordered current status rows:
     (taskNodeID, revision, status, terminal-evidence presence/value)
+ ordered current budget-binding rows:
     (taskNodeID, revision, bindingArtifactID, valueDigest)
+ ordered current authority-binding rows:
     (taskNodeID, epoch, grantArtifactID, valueDigest)
```

The vectors use the same canonical orders defined above and encode their
counts even when empty. The root deliberately excludes `activeAttempt`,
EventLog offset, projector cursor, caches, and wall-clock observations; those
remain separately CASed/currentness-checked incumbent K3 facts. K3 recomputes
the root from reopened rows and never accepts caller-computed bytes. Every
patch contains exactly one `root(expectedRoot)` read, and
`expectedRoot == baseTaskGraphRoot` is mandatory.

Before acceptance, K3 derives the complete affected-WorkUnit closure; the
caller cannot declare or shrink it. It contains:

- the changed WorkUnit itself, or every descendant WorkUnit of a changed
  Mission/Objective node, status, budget, authority, or parent relation;
- every WorkUnit reachable downstream from a changed dependency edge; and
- every WorkUnit whose inherited ceiling, completion predicate, generation,
  grant, or terminal-currentness proof depends on one of those members.

For every member of that closure the patch must carry exactly one
`activeAttempt(workUnitTaskNodeID, expectedAttempt)` read, even though
`activeAttempt` is excluded from the graph-root hash. K3 equality-rechecks all
of them in the commit transaction. It then derives the full physical mutation
footprint: graph/root and declared row keys plus every affected descendant
task/window/Attempt generation, active-head fence, budget row, authority row,
and `CapabilityGrant` fence. Missing closure reads, closure drift, an
unrepresentable fence, or a nonterminal Attempt for which the governing
transition does not authorize fencing rejects the patch.

For each patch, K3 canonicalizes all direct and derived generation causes into
one duplicate-free `generationAdvanceSet` keyed by the exact physical
`taskNode | window | Attempt` row identity. Every existing member advances
exactly once with `checkedAdd(pre-patch generation, 1)`, regardless of how
many changed ancestors, edges, statuses, budget bindings, authority bindings,
or direct writes reach it. A present `putNode` member's counter-table advance
is this same one advance, not a second increment; a newly installed node
starts at generation `0` and is not incremented again in its creation patch.
Existing TaskNode rows outside the set retain their generation. A graph patch
never creates an absent window/Attempt row merely to satisfy this set;
required admission remains a separate authority transition.

The advance set is sorted by row-kind rank `taskNode < window < Attempt` and
then canonical typed key bytes, and its canonical bytes are part of the
derived physical footprint. Common-base batching therefore rejects two
members whose derived advance sets share a key; it never adds once per cause
or once per batch member. Any `UInt64.max`, missing expected generation,
changed row, or failed grant/active-head fence aborts the patch or whole batch
before every root/EventLog/projector write. The Task Graph root uses the
resulting once-advanced TaskNode generations; window/Attempt generations stay
outside that root but are committed and replayed in the same transaction.

A model-generated patch is an untrusted proposal. Acceptance requires:

- base-root and read-set currentness;
- acyclicity of the complete candidate graph after applying the patch,
  including existing, cross-root, and reference edges rather than only the
  proposed slice;
- closed node and edge contracts;
- no orphan, duplicate, or impossible terminal;
- budget, deadline, fan-out, and depth bounds;
- capability non-amplification;
- effect/publication predecessor completeness;
- required L10/L11/L14 receipts;
- no conflicting write-set transition;
- deterministic canonical encoding.

There is no automatic rewrite or rebase of a stale patch. K3 may admit one
atomic common-base batch only when every member names the same current
`baseTaskGraphRoot`. Before any member commits, K3 derives and freezes each
member's complete physical mutation footprint above. That footprint must be
disjoint from every other member's declared or derived
read/write/precondition keys except for the one identical shared
`baseTaskGraphRoot` read/root-transition key owned by the batch transaction;
the fully composed graph must pass every DAG, budget, Attempt, authority, and
parent/child-terminal invariant. K3 orders the frozen batch by
`(patchOperationID encoded bytes, patchArtifactID encoded bytes)`, simulates
each patch and its derived fences in that order, and derives the successive
roots. The one identical `root(expectedRoot)` read and any matching
`rootEquals(expectedRoot)` precondition are validated exactly once against
the pre-batch snapshot and are excluded from later simulated-state rechecks;
this is the only common-base exception. Every non-root read, precondition,
declared key, derived closure fact, and fence of each later patch is
equality-rechecked against the state produced by all earlier simulated
members. Each EventLog transition records the immutable patch's common base
identity plus K3's derived immediate predecessor and successor roots; those
derived roots do not rewrite the patch. K3 appends one such transition per
member and exposes only the final root in one transaction. Any overlap, newly
stale non-root fact, root-derivation mismatch, or other failure rolls back the
whole batch. Once any patch commits outside that batch, an old-base patch
receives a typed conflict/remand; a replacement must be an ordinarily
validated new patch with a new operation identity and the current root.
Last-writer-wins is forbidden.

Only then may the one selected K3 `FULL` writer apply the immutable patch in
one storage transaction that:

1. appends an EventLog entry referencing the patch Artifact;
2. compare-and-swaps `taskGraphRoot` and every affected node generation, then
   derives and fences every affected `activeAttempt` head from the accepted
   transitions rather than caller-authored values;
3. advances the task-graph projector cursor to that exact EventLog offset;
4. for an ancestor, budget, or authority change, computes the dependent
   descendant closure and advances/fences every affected
   window/task/Attempt generation and `CapabilityGrant` before exposing the
   new head.

Failure of any step exposes no new root. A lost reply is queried by the same
operation identity; it does not create another patch/root. K3 never edits an
issued grant. A runtime authority widening requires ordinary admission, a
fresh L14/K4 grant, and a new Attempt. CreateGate applies only at design time
when governance intentionally creates the first new production owner or type;
it is not a runtime privilege-escalation path.

## 9. End-to-End Data Flow

```text
Input / ordinary admission
→ mapped semantic owners form or reopen a Mission Task Graph proposal
→ deterministic validation
→ K3 CAS publishes the next Mission root when authorized
→ Attempt pins one BASSemanticTurnDAG and its admission-time attemptFrame
→ pure readiness calculation over static edges and terminal bindings
→ user/host-selected certified Provider capability admission
→ L2 freezes the exact neural/Provider requirement and eligible plan
  template/CertifiedOperatingEnvelope
→ L3 forms the bounded context candidate, equality-reopens any opaque
  external accounting receipt, and BASContextCompiler finalizes the exact
  authorized sections and context-budget allocation
→ BASCompiledContextDescriptor
→ L2 freezes the exact BASExecutionPlan bound to that descriptor
→ after value-only route selection, Silicon constructs, ordinary-puts, and
  reopens the self-ID-free BASPersistedOrganDescriptorPayload PD for the
  selected Provider/containment descriptor; raw BASOrganDescriptor is never
  independently stored
→ K1 admits/reserves physical resources without changing model, route,
  profile, plan, output role, or semantic branch
→ the selected K3 FULL writer commits the exact budget-use row, then its
  historical receipt seam rematerializes, ordinary-puts, and reopens the exact
  BASBudgetUseReceipt
→ K3 allocates that exact typed Provider branch bound to Plan + PD + budget-use
  receipt by CAS, then reconstructs, ordinary-puts, and reopens allocation A
→ runtime.turn-operation constructs, ordinary-puts, and reopens providerStep
  only from reopened A and the already-frozen owner references
→ the Provider package reopens A + Plan + PD, separately validates providerStep
  as derivation input, materializes the exact request, and reopens M with exact
  ordered parents [A, Plan, PD]
→ terminal-answer branch only: K3 pins the one answer source, then
  reconstructs, ordinary-puts, and reopens terminal-source receipt T
→ isolated/custom remote only: L11 authorizes disclosure and L14 authorizes
  the exact physical destination and payload
→ PCC only: L11 authorizes disclosure and L14 authorizes the exact logical
  service/profile/canonical fields while platform-hidden physical fields stay
  explicitly unavailable
→ isolated/remote only: K4 claims the distinct one-shot authorization and
  returns the exact BASCapabilityUseReceipt bound to M + PD + authorization
→ isolated/remote only: Artifact Mesh ordinary-puts/reopens the governed
  BASProviderEgressBoundaryPermit; K3 validates A/M/[T]/permit/use/currentness
  and installs the dormant pending row
→ isolated/remote only: K4 anchors that committed K3 source root and its
  receipt is ordinary-put/reopened; K3 arms the exact pending row and
  reconstructs/reopens boundary-arm receipt B
→ K3 issues the fresh branch claim at the route's canonical post-arm/local
  start gate
→ isolated/remote only: beginProviderEgressHandoff consumes that fresh claim
  plus B, advances armed-to-sent_or_unknown, and returns the one immediate
  noncopyable transport permit
→ K2/BASTurnRuntimeEngine supervises the at-most-once Provider mechanism
  through BASLayerCell
→ completed: ordinary-put/reopen governed proposal P + terminal result;
  isolated/remote additionally ordinary-put/reopen authenticated O then signed
  At; reconstruct/row-pinned-put/reopen C from Q; K3 commits Srow (local binds
  nil arm/observation, isolated/remote binds exact B/O and freezes At/trust
  snapshot); reconstruct/row-pinned-put/reopen S; ordinary-put/reopen R bound
  exactly to M/P/S; validate and append exact (A, C, S, P, R) lineage
→ observed current-owner local failed/cancelled/indeterminate, or the narrow
  same-boot owner-loss case with exact physical-quiescence proof:
  reconstruct/reopen C → K3 Srow with P/B/O nil → reconstruct/reopen S
→ authenticated isolated/remote failed/cancelled/indeterminate:
  ordinary-put/reopen O then At with P nil → reconstruct/reopen C → K3 Srow
  bound to exact B/O and frozen At/trust snapshot → reconstruct/reopen S
→ unobserved local owner/boot loss, unauthenticated isolated/remote terminal,
  or sent_or_unknown: remain unsealed query/reconcile/quarantine-only
→ every non-completed branch omits P/R and completed lineage; no unsealed,
  unknown, or lineage-mismatched branch is consumable proposal evidence
→ canonical barrier/join
→ optional next ControlRing invocation or exact strict-successor path
→ L9 selects immutable candidate C0 only from an already K3-pinned,
  terminal-sealed source and proves bufferedUntilVerified mode plus zero
  visible source bytes
→ build/reopen the exact terminal-prefix X
→ L12 ordinary-puts/reopens the non-visible exact ResponseSpool Sp0,
  PresentationContract, semantic-conservation manifest, and immutable
  PresentationReleaseEnvelope Env0/digest
→ execute the complete preauthorized verifier suffix; for every
  .verifierProposal/.internalProposal ordinal:
    → materialize, ordinary-put, and equality-reopen the exact verifier
      BASExecutionPlan PlanV over the pinned terminal source and authorized
      verifier prerequisites
    → finish value-only route preflight and ordinary-put/equality-reopen the
      selected BASPersistedOrganDescriptorPayload PDV
    → profile-specific K1 reserve → committed K3 budget use
    → K3 typed allocation bound to PlanV + PDV, then reconstruct,
      ordinary-put, and equality-reopen A
    → compile, ordinary-put, and equality-reopen the verifier-purpose
      providerStep ContextCapsule from A + PlanV + exact candidate/verifier
      context
    → the exact request materializer reopens A/PlanV/PDV, separately validates
      that capsule, and ordinary-puts/equality-reopens M with exact ordered
      parents [A, PlanV, PDV]
    → .inProcessCertified: fresh K3 claim Q → K2 consumes Q and executes once
      OR .isolatedExtension/.remote: equality-reopen A/M and continue the
      incumbent Provider-egress path through applicable L11/L14/K4 use →
      egress permit/dormant pending → anchor → arm → fresh Q → handoff → one
      physical execution, without reallocating or rematerializing
    → complete the incumbent canonical Provider completion suffix:
      completed ordinary-puts/equality-reopens P + terminal result;
      isolatedExtension/remote additionally ordinary-puts/equality-reopens
      authenticated O then At; reconstructs/equality-reopens C from Q; K3
      seals Srow (local binds P with arm/observation nil/nil, while
      isolatedExtension/remote binds exact B/O and freezes At + installed
      trust snapshot); reconstructs/equality-reopens S; then ordinary-puts/
      equality-reopens R whose exact value/parents bind M/P/S and validates
      the full A/C/S/P/R lineage (+ B/O/At where required)
    → observed current-owner local failed/cancelled/indeterminate, or the
      narrow same-boot owner-loss case with exact physical-quiescence proof:
      reconstruct/equality-reopen C → K3 Srow with P/B/O nil →
      reconstruct/equality-reopen S
    → authenticated isolatedExtension/remote failed/cancelled/indeterminate:
      ordinary-put/equality-reopen O then At with P nil →
      reconstruct/equality-reopen C → K3 Srow bound to exact B/O and frozen
      At/trust snapshot → reconstruct/equality-reopen S
    → unobserved local owner/boot loss, unauthenticated isolatedExtension/
      remote terminal, or sent_or_unknown remains unsealed
      query/reconcile/quarantine-only
    → every non-completed outcome creates no P, no R, and no completed-lineage
      entry
→ every allocated verifier ordinal is terminal-resolved before L10; pending,
  unknown, unsealed, or lineage-mismatched blocks, and failure of a required
  verifier makes C0 non-releasable rather than fabricating P/R
→ L10 exact-envelope/output verification of C0/Sp0
→ exact-pass only: ordinary-put/equality-reopen exact-output-verification
  Artifact Everify0 over Sp0 + exact verifier contract/constraint, with
  display coverage absent in buffered V1; validation transitively reaches and
  equality-checks X through Sp0, but X is not an Everify field or parent
→ L11 exact-envelope risk/privacy/confirmation/disclosure decision for
  C0/Sp0/Everify0
→ Information Sufficiency forms a presentation candidate for that immutable
  semantic disposition; it is not a final result
→ L14 makes the exact release decision only after reopening and
  equality-checking the L11 receipt
→ final Information Sufficiency outcome reopens C0/Sp0/Everify0 + exact L14
  receipt + terminal branch heads/current epochs
→ closed release branch:
    exactRelease:
      L10 exact-verified + L11 exact-allow + L14 released + final outcome
      equal to C0's already-frozen semantic disposition
      → select the candidate-owned authorized tuple
        (Candidate*, T*, S*, X*, Sp*, Env*, Everify*) =
        (C0, T, S, X, Sp0, Env0, Everify0); only readyVerified may be
        unqualified terminalComplete
    replacementRequired:
      any L10 failure; any L11/L14/final-sufficiency result other than the
      exact release required by C0's frozen semantic disposition, including
      remand, redaction, confirmation, clarification, partial, abstention,
      denial, or semantic-disposition change
      → permanently mark C0/Sp0/Env0/[Everify0 if present] nonpublishable
      → either stop with an exact zero-byte terminal marker where the contract
        permits, or separately admit policy-authorized successor C1 with its
        own Sp1/Env1/Everify1 and repeat the complete verifier/L10/L11/L14/
        final-sufficiency path
      → C1 may equality-reopen X only while the pinned source cut and every
        currentness fact remain exact; otherwise it requires a successor
        Attempt/source and X1
      → finalOutcome.denied binds the exact L14 denial receipt; a visible
        denial uses only a separately authorized denial Env1, never Env0/Sp0
      → a successor that reaches exactRelease selects only its own complete
        (Candidate*, T*, S*, X*, Sp*, Env*, Everify*) tuple; no tuple member
        may be borrowed from the abandoned candidate
→ if and only if the complete authorized
  (Candidate*, T*, S*, X*, Sp*, Env*, Everify*) tuple exists:
    → derive rootCompletedVerifierEntries as exactly every completed
      policy-authorized post-pin verifier ordinal before the one
      visibility-close head, including closed history from abandoned
      same-root presentation candidates; every other allocated ordinal has
      exact failed/cancelled/indeterminate history and none remains pending
    → orderedVerifierR = rootCompletedVerifierEntries.map(R)
    → K3 installs/reopens exact buffered-visibility row Vrow bound to terminal
      source T* + source seal S* + orderedVerifierR + Everify*
    → reconstruct, ordinary-put, and equality-reopen visibility receipt V
      from Vrow
    → build/reopen through-visibility chain Y from exact policy ID +
      execution-binding ID + byte-identical terminal-prefix entries + T* +
      Everify* + V + rootCompletedVerifierEntries; validation reopens X*
      side-by-side, but X* is not a direct Y field or parent
→ ordinary-put/equality-reopen the complete controlled self-ID-free
  BASExactReleasePreparationPayload: TurnOperation + pinned terminal-answer
  source branch + final-publication branch + terminal ProviderExecutionRef +
  T* + V + X*/Y chain IDs + Sp* + Everify* + exact L11 risk permit + exact
  release grant + destination
→ construct the one BASProviderReleaseEvidenceReference {X*, Y, Sp*,
  preparation}
→ Artifact Mesh ordinary-puts/equality-reopens the complete pre-publication
  manifest carrying that exact four-ID reference; preparation contains no
  future manifest ID, boundary identity, idempotency key, or later receipt
→ K3 installs the non-usable prepared row
→ the independent publication journal reserves the publication identity
→ Artifact Mesh ordinary-puts/reopens immutable BASPublicationBoundaryPermit;
  K3 validates it and advances prepared → publication_permit_pending
→ K4 claimAndAnchorBoundary internally ordinary-puts U + H before its CAS,
  atomically records the exact capability-use and boundary-anchor receipts,
  and returns the ordinary store receipt identifying H
→ caller reopens H then the U named by H and ordinary-puts neither again
→ K3 arm CAS → reconstruct/ordinary-put/reopen exact boundary-arm receipt
→ the sole CAS winner queries the exact sink identity with the derived
  idempotency key:
    matching exact sink receipt → equality-check the full root/branch/
      instance/permit/anchor/arm/envelope tuple; call count remains zero
    no matching receipt → L12/BASResponseReleaseCoordinator calls the sole
      Adapter/IO sink exactly once with byte-identical Env*, then
      ordinary-puts/equality-reopens the exact
      BASExactReleaseSinkReceiptPayload
    unqueryable/contradictory/unknown → no release or retry; retain
      publication_indeterminate/query-reconcile-only
→ publication journal appends linked finalized evidence with nonnull
  U/H/arm/sink receipt, or linked indeterminate evidence
→ K3 closes or marks indeterminate only its own publication-boundary row
→ ContextContinuityManifest and WorkUnitRecoveryCursor projection
```

The response branch above is separate from durable state/effect work. A
state/effect proposal follows its existing `L13/K3 → L14/K4 → Zone C`
protocol and cannot hitchhike on response authorization. L14 authorizes and
seals exact identities; it is not the presentation or sink-call owner.

Readiness is a pure function of the pinned DAG, exact Attempt/generation,
terminal predecessor bindings, current authority/policy/deletion epochs,
budget/lease facts, and cancellation state. It cannot depend on an Agent's
private prose, an uncommitted cache, or wall-clock ordering between siblings.

## 10. Main, Sub, and App Agent Boundaries

Session is a UI projection over a Workspace, not execution truth and not an
owner of a mutable Main-Agent object. The App-Agent contract derives exactly
one Session-stable `sessionMainAgentID` as logical attribution. It remains
stable across WorkUnits, Attempts, context rebuilds, and compatible Provider
re-embodiments; it grants no authority and creates no Agent registry/manager.
Physical execution cardinality is separately Attempt-bound:

- zero or one Main Provider identity per Attempt, where deterministic,
  denial, await-user, or pure recovery paths may have zero;
- zero or more bounded depth-one Sub Provider branches inside that exact
  immutable Attempt DAG;
- one independently compiled and budgeted context window per invoked branch.

The separate App-Agent specification may bind exactly one selected App Agent
identity to each visible Session. This design consumes that binding but does
not reinterpret it as Session-owned execution authority or a globally current
Main object.

The logical Main role owns synthesis responsibility for the candidate response,
not semantic authority. A Main Provider is one replaceable physical
embodiment; its output remains untrusted proposal evidence, and a newly
authorized compatible Provider/Attempt preserves the same logical
`sessionMainAgentID`. Sub Provider roles behave as typed bounded tools: they
return Artifact references, coverage, conflicts, uncertainty, and terminal
receipts. They do not write one another's memory, inherit the full Main
transcript, or directly address the user.

App Agent identity, user-recognition state, values, persona, disclosure, and
style remain governed L5/App-Agent projections. A Main model may influence
the Session response through its proposal, but it cannot directly rewrite the
App Agent. Persona affects presentation structure and voice; L7/L10/L11/L14
still prevent persona from weakening truth, safety, or authorization.

Multiple App Agents may read explicitly shared compartments through governed
read-only projections. Each App Agent has isolated writable state and cannot
modify another App Agent's data.

## 11. Context Engineering

`BASContextCapsule` remains one strictly tagged contract, never an optional
all-fields bag and never the output authority of a second compiler:

- `attemptFrame` exists at WorkUnit admission. It binds the exact
  `TurnOperationRef`/`AttemptRef`, Workspace snapshot and generation vector,
  task/output contract, constraint/evidence references, `BudgetLease`,
  attenuated capability, and disclosure compartment. It contains no future
  Provider allocation identity.
- `providerStep` may be constructed only after reopening the exact K3
  allocation receipt. It binds one canonical `BASProviderExecutionRef`,
  step/output role and Provider-policy identities, exact
  model/profile/execution-plan identity, the correct R5-reservoir or
  R6-compiled-context branch, latest required K3 budget-use receipt, inherited
  `attemptFrame`, and attenuated capability. The reopened allocation already
  binds PD; the capsule does not add a duplicate descriptor field.

`semantics.layercell` and the mapped L5/L6/L7/L9/plan owners authorize capsule
contents. `runtime.turn-operation` composes their exact references for the
Attempt. `BASContextCompiler` is the sole L3 context budget/compilation/
binding/fingerprint mechanism and produces the exact
`BASCompiledContextDescriptor` and authorized context sections; it does not
own or widen capsule authority.

Context adaptation applies equally to local models, AFM/SystemLanguageModel,
PCC, custom APIs, and later Providers. The API has no higher authority merely
because its model is stronger.

For each invoked branch, `BASContextCompiler` derives one independent
effective input ceiling as the minimum of the reopened Provider capability
limit, certified model/profile geometry, selected execution-plan ceiling,
remaining K3 context-budget slice, current K1 memory/thermal eligibility
ceiling, and L5/L11 disclosure/compartment ceiling, after reserving the
profile's exact output/tool/protocol allowance. Every operand is expressed
through that profile's certified accounting mode; character heuristics,
cross-tokenizer conversion, and a remote preflight used merely to count are
forbidden. A negative or unprovable remainder makes the branch ineligible.
This calculation narrows execution only: K1 telemetry cannot widen K3 budget,
L14 authority, or the compiled context contract.

The resulting descriptor freezes the Provider/model/profile/tokenizer/
template identities, accounting mode, admitted sections and spans, exact
reserve, and cache-compatibility fingerprint. Different Main/Sub Providers
therefore may receive different-sized context windows while sharing only
governed Artifact references. Provider fallback or API/local switching
recomputes this ceiling and recompiles unless the already-certified
compatibility contract proves byte-identical reuse; it never truncates one
Provider's compiled window into another Provider's truth.

Cross-invocation sharing is references-only by default. A read-only compiled
prefix or Provider cache may be reused only when every compatibility key,
tokenizer/template digest, boundary ownership rule, policy epoch, deletion
epoch, and acquisition scope matches. Otherwise the context is rebuilt.
Provider KV state never becomes continuity truth.

The `state.snapshot-contracts` owner alone owns
`ContextContinuityManifest`, including its nested value-only
`WorkUnitRecoveryCursor`. It preserves references to plans, accepted
Artifacts, unresolved obligations, boundary identities, current heads/epochs,
the L11/L14-produced `ContinuationPolicy`, the optional latest committed
budget-use receipt, visited-state commitment, and exact recovery coordinates.
That receipt may be nil only when the historical K3 row proves zero use; a
caller omission is not such proof. K3 may validate current referenced rows and
bind one opaque continuity-reference Artifact ID; K3 does not own or interpret
either value. Neither value preserves hidden chain-of-thought nor copies full
private transcripts between Agents.

The post-answer `BASNextQuestionProjection` remains an L12/UI projection. It
performs no speculative Agent, retrieval, tool, network, or memory work before
the user acts. A semantic-null reveal tap only expands the already-buffered
projection. Only a later explicit submit tap creates one idempotent normalized
Input Event; ordinary admission then decides whether to create a WorkUnit and
Attempt.

## 12. Supersteps, Joins, and Scheduling

Execution uses one bounded micro-superstep with the canonical W6 three-phase
start protocol:

```text
open fixed snapshot and calculate the canonical ready frontier
→ barrier 1: pure prepare every member
→ barrier 2: source-ordered durable admission for every member
→ create the task group only after both barriers close
→ per-member immediate start recheck and route-specific fresh claim
→ execute independent value-producing members
→ commit each member's Artifact and owner-proved terminal independently
→ drain or quiesce every started member
→ frozen source-order join
→ calculate the next frontier
```

Barrier 1 performs, for **all** members, only exact governed-mechanism lookup,
immutable argument/request preparation, canonical schema validation, and
reopen of branch, capability, generation/policy/deletion/revocation epochs,
cancellation, deadline, and block evidence.

Barrier 2 runs in canonical source order and before a task group exists. It
puts/reopens every invocation/envelope, obtains and equality-checks every
required K3 budget-use authorization and existing non-consuming admission
receipt named by the frozen plan, proves the complete concurrency-class and
conflict-set predicates, and closes every unused preparatory reservation on
failure. One missing, foreign, stale, duplicate, denied, or mismatched member
starts zero mechanisms. Neither barrier calls an external mechanism nor
pretends to be a cross-owner atomic transaction.

Immediately before each physical start or protected handoff, that member
reopens its immutable digest, cancellation state, all relevant epochs,
deadline, grant, budget receipt, concurrency proof, and K1 lease. A local
Provider branch then wins its fresh K3 claim at the existing start gate. An
isolated/remote branch instead follows dormant K3 prepare → K4 anchor → K3 arm,
wins its fresh claim at the canonical post-arm point, then hands off the
single-use transport permit. Post-barrier drift, denial, expiry, or a CAS loser
executes no physical mechanism.

Only value-producing retrieval/model/proposal branches enter this task group.
Effect and publication mechanisms remain outside it under their exact
K3/K4/Zone-C or publication-journal protocols. Completion-order events are
non-authoritative progress observations. The executor joins causal results in
frozen source order and drains or quiesces every started child. A successful
sibling is not rerun because another sibling fails; `sent_or_unknown`,
effect/publication ambiguity, or any other protected nonterminal remains a
typed reconciliation disposition and blocks/remands every required join.

The original `runtime.semantic-dag` M Create also freezes one
`BASSemanticTurnJoinContract`:

```text
{
  joinContractID,
  consumerNodeSlotID,
  joinOrdinal,                  // UInt16
  members: [BASSemanticTurnJoinMemberContract] = [
    {
      memberSlotID,
      source:
        inputPort(consumerInputSlotID)
        | delegationSlot(delegationSlotID),
      requirement,              // derived mandatory | contributory
      applicabilitySource:
        inputPortDeclared
        | always
        | conditionEvidence(
            evidenceOwnerID,
            evidenceContractDigest,
            ruleID
          )
    }
  ],
  policy,                       // BASJoinPolicy
  quorumEligibleSlotIDs,
  artifactQuorum,               // UInt64, positive for every policy
  satisfactionPredicateArtifactID,
  coveragePredicateArtifactID,  // absent | present(artifactID)
  conflictPredicateArtifactID,
  disclosurePredicateArtifactID,
  successorAttemptRemand:
    forbidden
    | permitted(
        targetNodeSlotID,
        successorDeliverableContractArtifactID
      ),
  sourceOrder
}
```

Each `members` array item is the concrete embedded
`BASSemanticTurnJoinMemberContract` named in Section 6's exact topology
inventory, not an anonymous public wire or separately stored payload.

V1 permits exactly one join for every consumer that has at least one incoming
input port or attached delegation slot, and zero joins for a source node with
neither. A zero-join source must have `executionShape == pureDAG`; every
`controlRing` node is a consumer here and its unique join has at least one
member. An empty join or `controlRing` source fails DAG validation. The join's
`joinOrdinal` is therefore always zero. Its members cover every such input
port and attached delegation slot exactly once, with no foreign or omitted
source. This makes the one join outcome the consumer's complete readiness
combination; there is no implicit “any join”/“all joins” rule.
`joinContractID` is lowercase SHA-256 of length-prefixed
`"qinao-semantic-turn-join-v1"`, consumer slot ID, ordinal, and the canonical
bytes of every remaining field; it excludes itself. Runtime recomputes it.
Members are canonical by `memberSlotID`; `sourceOrder` is a duplicate-free
permutation of the same typed member IDs and freezes result order. Every input
source resolves to one port of the consumer; every delegation source resolves
to one exact Section-6 slot whose `joinContractID` points back here. Generic
retrieval/model members use their owner-proved terminal/inapplicability
evidence and are not falsely given a delegation-slot closure.

`memberSlotID` is a typed join-member ID derived as lowercase SHA-256 of
length-prefixed `"qinao-semantic-join-member-v1"`, the source tag, and the
typed source ID. It excludes itself and is recomputed. Source IDs are
one-to-one: no input port or delegation slot appears in two members of the
same join. `inputPortDeclared` is legal only for an input-port source and is
byte-equal to that port's Section-6.1 `applicability`; at runtime its exact
owner/rule evidence is reopened. A delegation source uses only `always` or the
fully named governed `conditionEvidence`; the resulting evidence Artifact
must reopen under `evidenceOwnerID`, match the digest/rule, and bind the
current Attempt/generation/epochs. Missing, stale, or mismatched evidence
cannot prove inapplicability. Unknown source/applicability tag combinations
fail closed.

`successorAttemptRemand` is part of the join-contract ID and is never selected
at runtime by the model. `permitted` is legal only when this join's consumer
node has frozen `executionShape == pureDAG`; every join of a `controlRing`
consumer must encode `forbidden`. `permitted` must name one existing DAG node
slot, and its contract Artifact must be byte-equal to that node's frozen
`deliverableContractArtifactID`; a foreign target, mismatched contract, shape
violation, or cycle within the active Attempt is invalid. It authorizes only the
`remanded.successorAttempt` terminal projection above. It does not create the
successor: Section 7's strict-quiescent expected-head CAS, fresh
inactive-then-activated grant, remaining-budget attenuation, inherited
deadline, and new Attempt still apply. `forbidden` makes a terminal failed
predicate non-remandable. An invocation with a real ControlRing envelope
instead uses the incumbent ring's exact `BASRemandArtifact`; it never consumes
this successor-Attempt tag.

`satisfactionPredicateArtifactID` reopens under the consumer's semantic owner
and freezes the mandatory/alternative-group/quorum matrix itself. It is not a
caller success flag. Together with the three specialized predicate fields, it
makes every terminal failure class nameable even when no individual
predecessor has a failure Artifact.

`requirement` is not caller-selectable. An input port whose obligation is
`required` maps to `mandatory`; an `alternativeGroup(groupID)` port maps to
`contributory`; every V1 delegation slot is bounded optional work and maps to
`contributory`. Before any Join Artifact is constructed, every applicable
alternative-group predecessor must have an owner-proved terminal disposition
and each `(consumerNodeSlotID, groupID)` independently reaches its exact
`requiredSatisfiedCount`. One group's successes cannot satisfy another group,
and the global Artifact quorum cannot replace these per-group predicates.

The same M Create freezes one governed, self-ID-free
`BASSemanticJoinMemberDispositionPayload` at `1.0.0`:

```text
{
  schemaVersion,
  attemptRefArtifactID,
  semanticTurnDAGArtifactID,
  joinContractID,
  memberSlotID,
  source,                         // exact member source tag + typed ID
  disposition:
    inputSatisfied(
      edgeBindingArtifactID,
      predecessorTerminalReceiptArtifactID
    )
    | inputInapplicable(conditionEvidenceArtifactID)
    | inputTerminalNonCounting(predecessorTerminalReceiptArtifactID)
    | inputTerminalUnsatisfied(
        predecessorTerminalReceiptArtifactID,
        failedPredicateArtifactID
      )
    | delegationClosed(BASDelegationSlotClosure),
  generationVectorArtifactID,
  policyEpoch,
  deletionEpoch,
  sourceEventHighWatermark,
  sourceEventRootArtifactID
}
```

There is exactly one current disposition Artifact per member. Its
`memberSlotID` and source are equality-derived from the join contract, so two
ports that consume the same predecessor output or condition evidence still
produce distinct Artifact IDs. `inputTerminalNonCounting` is legal only for a
terminal contributory input that does not satisfy its group/quorum.
`inputTerminalUnsatisfied` is legal only for an owner-proved terminal
failed/cancelled/disallowed input and binds both its exact terminal receipt and
the exact failed join/group/coverage predicate evidence. It never contributes
semantic success: for a mandatory member or a member needed to satisfy its
frozen group/quorum/coverage predicate it drives the exact remand-or-terminal-
impossibility path; a noncritical contributory member is only a structurally
settled member under `.all` and remains typed missing under the other policies.
`delegationClosed` embeds exactly one Section-6.3 closure. The constructor
reopens every underlying evidence/zero-allocation/terminal fact and current
Attempt/generation/epochs; possible-start or caller-defaulted absence cannot
produce a disposition. Duplicate member IDs or disposition Artifact IDs fail
before readiness or join construction.

`artifactQuorum` is present and positive for every policy because the
incumbent `BASJoinArtifact` requires it. For `all` it equals member count. For
`quorum` it equals mandatory-member count plus the frozen positive number of
eligible contributory successes; `quorumEligibleSlotIDs` is exactly that
canonical contributory set. For `best-effort-with-coverage` it is the frozen
positive minimum-received count and cannot be lower than the mandatory-member
count unless every mandatory member is provably inapplicable. The eligible
vector is empty outside `quorum`. Coverage is present only for
`best-effort-with-coverage` and absent otherwise; every policy still binds
exact conflict and disclosure predicates. A member carrying safety,
authorization, effect, publication, or terminal-verification obligations is
always `mandatory`. Every conditional field uses the closed
`absent | present(value)` tag; nil/null/default inference fails.

The consumer node's frozen `executionShape` selects exactly one path;
`BASSemanticNodeInvocation.controlLoopEnvelopeArtifactID` only validates that
selection. For every admitted invocation the equivalence is exact:
`executionShape == pureDAG` if and only if the field is absent, and
`executionShape == controlRing` if and only if it is present and reopens a real
current ControlRing envelope. Barrier 2 validates this equality against the
pinned DAG before the invocation ordinary put/admission or any mechanism
start; mismatch, unknown shape, or orphan envelope fails closed. A real
ControlRing invocation therefore always has a nonempty unique join, must
produce the existing `BASJoinArtifact`, and must fill all incumbent envelope/
progress/remaining-budget/deadline fields. A pure DAG invocation produces no
second join payload: pure readiness evaluates the same frozen contract and
binds the exact member dispositions plus canonical policy inputs into the existing
`BASSemanticNodeInvocation.orderedInputArtifactIDs`. The common member/policy
projection is:

1. before evaluation, every member has one distinct current
   `BASSemanticJoinMemberDispositionPayload`. Because V1 has no optional input
   port and executes every applicable alternative member to terminal, no
   synthetic input zero-start receipt is needed. A possible-start, unsealed,
   or reconciliation-pending member prevents readiness/join construction;
2. the expected vector is those unique disposition Artifact IDs in frozen
   `sourceOrder`;
3. `orderedReceivedInputArtifactIDs` is the stable subsequence whose
   dispositions satisfy the selected policy; `orderedMissingInputArtifactIDs`
   is its stable complementary subsequence;
4. `policy` and `quorum` equal the contract policy and `artifactQuorum`;
5. Runtime reopens the exact governed predicate Artifacts and every direct
   Artifact-reference field they canonically contain. The canonical
   policy-input vector is the satisfaction predicate and its referenced
   inputs, then the coverage predicate and its inputs when present, then the
   conflict predicate and inputs, then the disclosure predicate and inputs,
   with stable-first-occurrence de-duplication. Its IDs are disjoint from the
   disposition IDs. The predicate contracts must define pure deterministic
   evaluation over this vector plus the dispositions; an ambient query,
   caller boolean, model judgment, or uncommitted cache is illegal;
6. `orderedConflictArtifactIDs` is exactly the duplicate-free set of conflict
   subject Artifact IDs derived by the reopened conflict predicate, ordered
   by canonical encoded Artifact-ID bytes. `orderedEvidenceArtifactIDs` is the
   policy-input vector followed by the underlying member evidence in
   `sourceOrder` and disposition-field order (`edgeBinding`, predecessor
   terminal, condition, failed predicate, then delegation-closure fields);
   IDs already present in either earlier position or the conflict vector are
   omitted by stable first occurrence. The validator reconstructs both
   vectors and rejects any missing, extra, duplicate, reordered, or
   arrival-ordered value; and
7. the ControlRing path writes those vectors into `BASJoinArtifact` and obtains
   parent, remaining budget,
   lease/prior-use/progress/envelope, and monotonic deadline from the exact
   current invocation; the pure-DAG path requires the same semantic predicate
   to pass and sets `orderedInputArtifactIDs` to the complete expected vector
   followed by the canonical policy-input vector. Its member-count prefix
   and policy-input suffix are therefore mechanically separable and
   replayable; it carries no ring-only field.

The partition in step 3 is exact. For `.all`, construction occurs only after
all mandatory/group/coverage/conflict/disclosure predicates pass; every
structurally terminal disposition is then `received` and `missing` is empty,
as the incumbent validator requires. For `.quorum`, `received` contains every
successful or permitted-inapplicable mandatory member plus only successful
members of `quorumEligibleSlotIDs`; every other contributory
inapplicable/non-counting/unsatisfied/unused/rejected closure is `missing`.
For `.best-effort-with-coverage`, the same mandatory rule applies and every
successful contributory member is `received`, while terminal non-successes
are `missing`. A `delegationClosed.boundTerminal` is successful only when its
reopened child terminal/output contract passes; `provedUnused` and
`rejectedBeforeAllocation` are structural terminals but never semantic
successes. Thus the numeric incumbent quorum cannot be inflated by an
ineligible or merely terminal member.

After calculating the complete frozen Attempt frontier, Runtime evaluates
every member and predicate of every terminal-failed consumer before choosing a
cause; it never stops at the first arrival or first locally visited join. It
forms candidate tuples ordered by:

```text
(
  consumer-node canonicalOrdinal,
  causeRank,
  member sourceOrder index or zero
)
```

The closed `causeRank` is encoded `UInt8` in this exact order (`0` through
`4`):

1. `memberUnsatisfied`: each
   `inputTerminalUnsatisfied.failedPredicateArtifactID` whose member
   participates in a false mandatory/group/quorum predicate, using its source
   index;
2. `satisfaction`: `satisfactionPredicateArtifactID` when the mandatory,
   alternative-group, or Artifact-quorum matrix is false;
3. `coverage`: `coveragePredicateArtifactID` when present and false;
4. `conflict`: `conflictPredicateArtifactID` when false; and
5. `disclosure`: `disclosurePredicateArtifactID` when false.

Canonical tuple order is global across the Attempt; local source-order indices
never compare across consumers without the consumer ordinal. Each candidate
value is the pair `(failedConsumerNodeSlotID, failedPredicateArtifactID)`;
stable first occurrence after sorting removes only duplicate pairs, never the
same predicate reused by a different consumer. A noncritical failed member
that does not make a frozen predicate false is not a cause candidate. The
vector must be nonempty for every non-satisfying terminal result, and the
selected failed-cause pair is exactly its first value. K3 reconstructs the
full vector from the complete terminal disposition set and predicate inputs
before committing remand or terminal impossibility; a caller cannot select a
later failure. The pair is therefore deterministic when several joins and
predicates fail simultaneously.

ControlRing construction is legal only when the incumbent validator's
nonempty expected vector, exact partition, stable-subsequence, positive-quorum,
policy, budget, and deadline rules all pass. Pure-DAG readiness enforces the
same vector/partition/subsequence/quorum/policy semantics and reopens the
policy-input suffix, then Barrier 2 reopens the invocation/dispositions and
rechecks exact K3 Attempt, lease/use, generation/epoch/deadline, and EventLog
currentness before start.

The Section-6.1 all-inputs-inapplicable path proves the frozen inapplicability
vector, closes every delegation slot unused/rejected as applicable, and does
not construct an invocation or Join Artifact. Any invoked consumer has a
nonempty expected vector. A zero-join pure-DAG source instead follows the
incumbent no-incoming-edge root-readiness rule; its invocation has an empty
`orderedInputArtifactIDs` vector and never fabricates a member disposition or
`BASJoinArtifact`.

Join policy reuses exactly the existing `BASJoinPolicy` encoded values and has
the following exhaustive outcome matrix:

| Policy | Satisfaction rule | Non-satisfying outcome |
|---|---|---|
| `all` | every required member succeeds or is permitted-inapplicable, every alternative group independently reaches its count, every non-counting alternative is terminal, and every delegation has an allowed terminal/unused closure; all expected disposition IDs are received and `quorum == expected.count` | a terminal failed/disallowed required/group disposition selects the exact path-specific remand contract when legal; possible-start or unresolved protected work follows reconciliation and emits no Join Artifact |
| `quorum` | every mandatory member succeeds or is provably inapplicable, and at least frozen `q` eligible contributory members succeed; Artifact quorum is mandatory count plus `q` | terminal failed/cancelled/inapplicable contributory members remain in the missing partition with evidence; terminal impossibility selects only the exact path-specific remand contract, while possible-start work reconciles |
| `best-effort-with-coverage` | every mandatory member succeeds or is provably inapplicable, the frozen positive Artifact quorum is met, and the exact L7/L10 coverage plus conflict/disclosure predicates pass | noncritical terminal failures remain typed missing/coverage evidence; terminal insufficient/conflicting coverage selects only the exact path-specific remand contract, while possible-start work reconciles |

Quorum proves completeness, never truth or model-majority authority. A
cancellation request is nonterminal. A contributory inapplicability never
counts toward quorum; a mandatory inapplicability only proves that its
mandatory obligation does not apply. A ControlRing `BASJoinArtifact` is
emitted, or a pure-DAG invocation is admitted with the exact input/evidence
layout above, if and only if the selected matrix row and its exact validator
both pass. Every possible-start row enters the existing same-operation
reconciliation path and remains non-adoptable until terminal.

`BASRemandArtifact` remains strictly ControlRing-only: its remaining-budget,
prior-use, progress-witness, and nonnil envelope fields must reopen from an
already-real ring invocation. A failed join before invocation admission, or a
current pure-DAG invocation, never fabricates those facts. Instead, a failed
predicate on a consumer whose frozen `executionShape == pureDAG`, with the
exact frozen `successorAttemptRemand.permitted` contract and complete
frontier/branch-drain facts, may make K3 terminalize the current Attempt as
`remanded.successorAttempt(failedConsumerNodeSlotID,
failedPredicateArtifactID, targetNodeSlotID,
successorDeliverableContractArtifactID)`. That closed value is carried by the
same semantic-Attempt terminal row/receipt; it is not a second remand Artifact,
owner, store, or authority. If a current admitted pure-DAG invocation exists,
its envelope field must be absent; no reverse absence query is required.
Orphan invocation Artifacts remain inert. A `controlRing` consumer without a
real current ring invocation cannot use either remand representation.

The successor-Attempt terminal disposition merely authorizes Section 7's ordinary
strict-quiescent successor-Admission check. It starts no Provider/effect/
publication mechanism, does not rerun completed siblings, and cannot itself
activate a grant or new Attempt. If budget/deadline/currentness has changed,
the frozen remand contract is forbidden, or a protected possible-start/
cancellation boundary remains, the exhaustive Section-13 classification
selects deferred, terminal-impossible, await/reconcile, cancellation drain, or
a fresh readiness calculation. A nil envelope is never laundered into ring
evidence.

Arrival order cannot change truth, membership, quorum, coverage, or output
order. Every matrix cell, including cancellation, inapplicability, partial
failure, and possible-start, requires a distinct mutation oracle.

V1 serializes optional Agent fan-out, and even serialized optional fan-out is
admitted only when an existing signed device/profile measurement proves a
positive bounded net benefit for that exact specialist set under current
latency, energy, thermal, memory, and quality ceilings. Absence or drift means
one Main branch, not speculative Agents. Overlap is permitted only for
semantically required independent coverage whose frozen execution plan binds:

- a plan-owned `concurrencyClass` for every member;
- a plan-owned `sideEffectClass` and immutable per-member `proofDigest`;
- a canonical sorted conflict set of exact `{ownerID, resource/slot key}`
  values;
- the exact compatibility-matrix/algorithm Artifact ID, owner, version, and
  digest, with unknown class pairs incompatible;
- pairwise disjoint conflict sets or an existing mapped owner's certified
  commutativity receipt over the exact keys;
- one frozen low-entropy communication-profile Artifact ID owned by the
  existing `execution.plan-provider-router`, plus schema version and digest;
  and
- the two barriers, per-member start gate, deterministic cancellation, and
  join matrix above.

For serialized optional fan-out, the plan additionally binds
`optionalFanoutBenefitEvidenceArtifactID`, its
`runtime.certification` owner/schema version/digest, exact device/OS and
Provider/profile set, ordered specialist-set IDs, one-Main serial baseline
plan/profile IDs, measurement cohort and minimum sample count, measurement
window/freshness deadline, and the existing plan-owner acceptance-predicate
Artifact ID/digest. The certificate reports confidence bounds for latency,
energy, thermal, peak memory, and governed quality metrics over the same
cohort. The frozen predicate requires every hard ceiling and non-regression
bound to pass and at least one predeclared primary benefit's conservative
lower bound to be strictly positive; it computes no new scalar utility score.
Wrong device/model/specialist set, baseline substitution, overlapping cohort,
insufficient samples, stale evidence, unknown metric, or digest drift rejects
fan-out.

That communication profile freezes the only Agent-envelope schema, permitted
typed fields, correlation/source labels, maximum evidence references, exact
byte-size bucket boundaries, and exact monotonic send/receive timing buckets
relative to the superstep start. Every envelope must land in exactly one
declared size and timing bucket. Free-form hidden fields, peer channels,
shared scratchpads, unclassified length/timing, or profile mismatch denies the
independence claim.

Before a member may count as independent coverage or quorum, a separately
scoped deterministic validator (or an independently admitted verifier when
the governed predicate requires it) compares model/checkpoint ancestry, prompt
and instruction lineage, evidence ancestry, cache acquisitions, retrieval
sources, and tool-result ancestry. Shared or unknown ancestry is
correlation-labeled and discounted/rejected by the frozen predicate; agreement
cannot masquerade as independent consensus. The immutable source Artifact may
be shared only after each branch independently passes eligibility, and mutable
prompt/KV/sampler/tool/credential/Provider-session state is never shared.

The executor never infers independence. Every local model trunk carries the
same process-wide `HeavyPhase` conflict key. GPU/Neural Engine heterogeneous
overlap additionally requires current exact-profile evidence that parallel
wall time is `≤ 0.95 ×` serial wall time with no memory, thermal, energy, or
quality regression; otherwise it serializes. The communication buckets bound
the certification profile but do not claim timing privacy is perfect; residual
leakage remains measured threat-model evidence. The graph cannot load several
large models merely because branches are semantically independent. The
semantic/plan owner selects the predeclared specialist, route, profile, and
output role before allocation. K1 only reserves, defers, rejects, or
serializes physical resources and cannot make those semantic choices.

## 13. Bounded Loop Semantics

Only three operational loop classes exist:

1. **Semantic/evaluator loop:** critique, grounding remand, solution revision,
   or RSI evidence production.
2. **Technical retry loop:** a pure or demonstrably not-started mechanism
   failure under unchanged semantics, unchanged identity/budget, an approved
   retry policy, and Section 14's exact recovery matrix.
3. **Unknown-effect reconciliation loop:** query and reconcile a possibly
   executed external action without resending it.

They reuse the existing ControlRing payload family and K3 decision row. This
design adds no loop owner or mutable loop row. The currently implemented
envelope/progress fields remain authoritative, and the currently implemented
enums plus allowed terminal pair matrix remain the exact raw spellings. The
governing K3 addendum Sections 6.5-6.6, however, deliberately migrates
`BASControlLoopTerminalReceiptPayload` to `2.0.0`: all field order is
unchanged and only `budgetUseReceiptArtifactID` becomes optional.

Nil is legal only for a zero-spend rejection whose historical K3 terminal row
proves zero use. A terminal after committed use carries that exact nonnil
receipt. `converged + converged-verified` requires a current nonnil
`BASBudgetUseReceipt` whose Artifact and K3 use row equality-reopen; a caller
cannot make a receipt optional by omission. Canonical v2 omits the nil key and
rejects explicit JSON `null`.

Historical v1 bytes and Artifact IDs are never rewritten. The sole backward
read seam is the owner-local
`decodeControlLoopTerminalReceiptMigratingV1`: Artifact Mesh first verifies
the original identity and bytes; a frozen bounded v1 struct must
canonical-reencode byte-identically; projection to v2 uses
`.some(oldBudgetUseReceiptArtifactID)` in memory only. Malformed,
noncanonical, missing-version, or future bytes fail, and no generic migration
framework is introduced.

This specification adds no prose-derived `state`, `strategy`, `evidence`, or
shadow fields. Every successor invocation carries the same `BudgetLease`, the
latest committed `BASBudgetUseReceipt` when applicable, and the inherited
visited-state commitment. Nil is accepted only with K3 zero-use proof and
cannot support authoritative adoption. Round, branch, time, token, cost, and
remand budgets never reset or replenish across invocations.

Progress uses exactly the existing `BASControlLoopProgressKind` encoded
values:

```text
new-required-lane-coverage
strict-deficiency-reduction
strict-conflict-reduction
resource-safe-transition
effect-saga-rank-advance
```

A completed obligation counts only when the existing witness proves
`strict-deficiency-reduction`; this design adds no “completed obligation”
progress kind. Different prose, resampling, time passage, a heartbeat, or
revisiting a digest is not progress.

The existing `BASControlLoopTerminalReceiptPayload` accepts exactly these
terminal-state/reason pairs:

| `BASControlRingTerminalState` encoded value | Allowed `BASControlLoopTerminationReason` encoded value |
|---|---|
| `converged` | `converged-verified` |
| `degraded-with-coverage` | `coverage-bound` |
| `deferred` | `resource-deferred` |
| `deferred` | `budget-exhausted` |
| `rejected` | `policy-rejected` |
| `rejected` | `cycle-detected` |
| `rejected` | `no-progress` |
| `rejected` | `stale-epoch` |
| `rejected` | `illegal-remand` |
| `needs-confirmation` | `confirmation-required` |
| `indeterminate-needs-reconciliation` | `effect-reconciliation-indeterminate` |

Only `converged + converged-verified` together with a current committed nonnil
K3 `BASBudgetUseReceipt` may feed authoritative downstream adoption. Repeated
canonical state/strategy commitment uses `rejected + cycle-detected`; missing
admissible progress uses `rejected + no-progress`; a failed hard-budget claim
uses `deferred + budget-exhausted`; verified partial coverage uses
`degraded-with-coverage + coverage-bound` without adopting the unresolved
remainder. No underscore or alternative raw spelling is introduced.

The `runtime.semantic-executor` computes one exhaustive frozen-frontier
classification from the pinned DAG and owner-proved receipts:

```text
terminalAlreadySealed(exact K3 Attempt-terminal row)
| terminalSatisfied(exact designated-terminal evidence)
| terminalCancelled(exact owner-proved terminal cancellation)
| legalWait(exact protected possible-start/reconciliation identity)
| cancellationDraining(exact cancellation/drain identity)
| failedTerminalPredicate(
    failedConsumerNodeSlotID,
    exact failed predicate/evidence,
    controlRingRemand
    | successorAttemptRemand(
        targetNodeSlotID,
        successorDeliverableContractArtifactID
      )
    | noLegalRemand
  )
| budgetExhausted(exact K3 lease row)
| deadlineExpired(exact K3 current-boot deadline row)
| terminalNonAdoptable(exact designated-terminal node receipt)
| ready(nonempty canonical frontier)
| deadlocked
```

The variants above are also the fixed K3 decision priority, evaluated against
one transaction snapshot. An existing terminal row always reopens unchanged.
Already-proved terminal success wins over a later cancellation/budget/deadline
observation; an owner-proved terminal cancellation wins once every started
member is drained or quiesced. Protected possible-start/reconciliation remains
`legalWait`, and a merely requested or draining cancellation remains
`cancellationDraining`; neither may be converted into terminal truth.

A failed predicate derives exactly one resolution from the selected consumer's
frozen `executionShape` and join contract. `controlRing` permits only
`controlRingRemand`, and only when a current authoritative invocation reopens
with a nonnil ring envelope plus its exact prior-use/progress/remaining-budget
lineage; before such a real invocation it yields `noLegalRemand`.
`pureDAG` permits only `successorAttemptRemand`, and only when the join carries
the exact `successorAttemptRemand.permitted` tuple and the complete
frontier/branch-drain facts pass. A current admitted pure-DAG invocation, if
one exists, must reopen with a nil envelope, but K3 never needs a
consumer-keyed absence-row query; an orphan invocation is inert. A forbidden
tag, shape/envelope mismatch, unknown shape, or missing ring lineage yields
`noLegalRemand`. That resolution commits `terminalImpossible` at the fixed
failed-predicate priority and does not fall through to a simultaneous
budget/deadline observation. Either of the two legal remand resolutions is
selected only while budget and deadline permit it; otherwise classification
falls through to `budgetExhausted` before `deadlineExpired`.
After those two cases, an exact `terminalNonAdoptable` receipt precedes a
nonempty ready frontier, and only then may ordinary `deadlocked` be selected.
Therefore the classifier's final `deadlocked` variant—and thus the persisted
`emptyReadyFrontier` basis—means every earlier variant is false: no terminal
row/success/cancellation, failed terminal predicate, protected wait/drain,
budget/deadline cause, designated-terminal non-adoptable receipt, or ready
member exists. The persisted `rejectedNoProgress.deadlocked` union also
serves the earlier `designatedTerminalNoProgress` basis exactly as specified
below. Overlapping observations cannot make the caller choose a cause, and
the terminal-row CAS makes a race reopen the winner rather than reclassify it.

The designated terminal node's existing `BASSemanticNodeOutcome` has this
closed classifier routing; Runtime may not infer from prose or a missing
field:

| Node outcome | Only legal classifier projection |
|---|---|
| `completed` | `terminalSatisfied`, and only with the exact completed or converged-verified receipt/verification chain; a malformed or unverified completed claim is invalid evidence, not no-progress |
| `cancelled` | `terminalCancelled` after owner-proved terminal cancellation and complete drain, otherwise `cancellationDraining` |
| `reconcileRequired` | `legalWait` with the exact protected reconciliation identity |
| `remanded` | the exact `failedTerminalPredicate` path when a selected failed cause and legal/no-legal remand resolution exists; otherwise `terminalNonAdoptable` only after K3 proves the owner-proved receipt is terminal and no continuation remains |
| `deferred` | `legalWait` while its exact governed boundary remains resumable, `budgetExhausted` or `deadlineExpired` with the exact K3 cause, otherwise `terminalNonAdoptable` only for an owner-proved terminal deferred reason with no legal wait |
| `degraded`, `refused`, or `failedClosed` | `terminalNonAdoptable` after its current invocation and receipt reopen and every earlier specialized case is false |

`terminalNonAdoptable` is an in-memory classification variant, not a new
persisted wire. It commits the existing
`rejectedNoProgress.deadlocked(deadlockedFrontierDigest)` disposition with
basis `designatedTerminalNoProgress`; its terminal-evidence primary prefix is
the exact designated-terminal receipt followed by the complete disposition
closure. This applies equally to a zero-join one-node source/sink and to a sink
whose incoming join succeeded before its own execution failed. Unknown
outcomes, invalid outcome/receipt combinations, stale receipts, and
nonterminal possible-start evidence enter corruption/reconciliation handling
and cannot be laundered into this basis.

`failedTerminalPredicate.controlRingRemand` constructs the exact incumbent
`BASRemandArtifact` and commits `remanded.controlRing`;
`failedTerminalPredicate.successorAttemptRemand` commits the exact
`remanded.successorAttempt(failedConsumerNodeSlotID, failedPredicateArtifactID,
targetNodeSlotID, successorDeliverableContractArtifactID)` fields from the
selected consumer's join contract. Neither reruns completed
siblings. `noLegalRemand` commits
`rejectedNoProgress.terminalImpossible(failedConsumerNodeSlotID,
failedPredicateArtifactID)`, never the deadlocked cause.

For deadlock or terminal impossibility with no remand, Runtime submits one
idempotent semantic-Attempt terminal request
through the existing `state.k3-control-nucleus` terminal-fact owner. The
transient request carries its idempotency request ID, Attempt/DAG IDs, expected
active head, generation/policy/deletion epochs, expected EventLog head, a
closed
`deadlocked | terminalImpossible(failedConsumerNodeSlotID,
failedPredicateArtifactID)` cause, and its lowercase SHA-256 classification
digest. Deadlock uses the
`"qinao-deadlocked-frontier-v1"` domain followed by the closed
`emptyReadyFrontier | designatedTerminalNoProgress` basis tag. The latter
then binds the designated terminal invocation Artifact ID, receipt Artifact
ID, canonical receipt bytes/outcome, and currentness fields; the former binds
none of those nonexistent values. Terminal impossibility uses
`"qinao-terminal-impossible-frontier-v1"` plus the selected consumer slot and
failed-predicate Artifact ID. Both then cover the same canonical node states,
edge bindings, join dispositions, and current generation/epoch vector. K3
recomputes the selected domain/digest and the exact fixed-priority predicate
in one transaction.
If the selected cause still holds, it commits the existing Attempt terminal
fact and matching `rejectedNoProgress` disposition, then the historical seam
reconstructs and reopens Section 6's
`BASSemanticAttemptTerminalReceiptPayload`. A byte-identical retry reopens the
same row/receipt; the same request ID with different bytes is corruption, and
currentness drift rejects and forces a fresh readiness calculation. An actual
ControlRing's own no-progress termination still uses its existing
`rejected + no-progress` pair; the pure-DAG deadlock/terminal-impossibility
terminal path never fabricates a ControlRing envelope. Section 12's
path-specific remand either reuses an already-real ring or records only the
closed successor-Attempt admission projection. This adds no deadlock owner or
state machine.

A possible-start or `sent_or_unknown` boundary is never deadlock: it is
`legalWait` only while its exact reconciliation protocol and deadline remain
live, then resolves through Section 14's matrix. A heartbeat timeout is merely
a stalled observation and cannot manufacture either terminal or no-start
truth. The K3 lease/deadline row is durable deadline truth; K1 wakeups and
heartbeats are observations only. The inherited monotonic deadline cannot be
reset, extended, or re-armed by a retry, heartbeat, recovery, Session reopen,
or process restart.

At the exact current-boot monotonic deadline, Runtime submits one idempotent
K3 budget/terminal request carrying the observed monotonic time and never
re-arms that wait. A ControlRing time-budget expiry resolves to
`deferred + budget-exhausted`; a zero-spend case may omit the budget-use
receipt only with K3 proof. A `ContinuationPolicy` expiry resolves to
`awaitUser`. An external Provider/effect/visibility/publication/command
deadline follows Section 14's exact boundary-state matrix:
`closedUnused`, `reconcileSameOperation`, or `quarantine`; it never authorizes
a resend. A boot relation that cannot compare the old monotonic clock also
uses that matrix rather than inventing remaining time. Tests must prove that
no live wait survives its deadline.

For a pure DAG with no ControlRing envelope, K3 instead recomputes its own
lease/deadline row in the semantic-Attempt terminal transaction and commits
`deferredBudgetExhausted` or `expiredAwaitUser`; the historical seam then
reconstructs the same `BASSemanticAttemptTerminalReceiptPayload`. Deadline
expiry first partitions any protected possible-start boundary into Section
14's reconcile/quarantine matrix; only a graph with no such boundary may use
`expiredAwaitUser`. Neither outcome creates a ring envelope, refreshes a
budget, or extends a deadline.

## 14. Crash, Session, and Command Recovery

Recovery reconstructs logical work from durable boundaries. It does not
pretend that an arbitrary OS process can resume from an instruction pointer.

`ContextContinuityManifest` and `WorkUnitRecoveryCursor` must resolve:

```text
mission root
Attempt ID and semantic-DAG digest
node/slot and branch identity
invocation, generation, and epoch
input/output Artifact references
terminal and edge-binding receipts
lease/budget state
publication/effect boundary state
unknown-effect disposition
```

Recovery is governed normatively by the exact `ContinuationPolicy` and
exhaustive `RecoveryDisposition` receipt-presence matrix in
`docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`,
Section 4.6. This document neither summarizes that matrix into broader rules
nor creates a graph-specific recovery classifier.

The matrix first partitions by boundary kind and boot relation, then by owner
liveness, current epochs/deadline, possible-start, and the exact
`A/M/D/K/B/Q/X/O/S/P/Jr/Jf` presence shape. Policy evaluation plus that matrix
derives exactly one existing aggregate disposition:

```text
restoreCompleted
resumeSameAttempt
reconcileSameOperation
rebuildAfterTerminal
awaitUser
quarantine
```

Artifact existence alone never establishes completion, currentness, or
authority. The Artifact must be hash-covered by its exact K3/EventLog
head/seal or other mapped owner truth, and the matrix must admit the
transition. Lease expiry does not authorize an automatic new generation.
Authenticated effect failure does not authorize an automatic resend. Any
possibly crossed Provider, visibility, publication, command, or effect
boundary is limited to exact-identity query/reconcile/seal/finalize; later
independent work uses ordinary admission.

The buffered-response path has one exact fault-injection chain:

```text
terminal-prefix X
→ Sp0 / PresentationContract / conservation manifest / Env0
→ for every verifier ordinal:
     PlanV → PDV → K1 reserve / K3 budget use → A
     → providerStep ContextCapsule → M
     → [Provider-egress permit / anchor / arm] → Q → [handoff]
     → physical-call boundary
     → completed:
         P / terminal result → [O → At] → C → Srow → S → R
         → validated A/C/S/P/R lineage (+ B/O/At where required)
       OR observed local non-completed:
         C → Srow with P/B/O nil → S → exact terminal history, no P/R
       OR authenticated isolatedExtension/remote non-completed:
         O → At with P nil → C → Srow bound to B/O → S
         → exact terminal history, no P/R
       OR unresolved possible-start terminal without a seal
     → exact terminal or unresolved history
→ all-verifier-ordinals-terminal barrier
→ Everify
→ L11 decision
→ Information Sufficiency presentation candidate
→ L14 decision
→ final Information Sufficiency outcome
→ Vrow → V → Y
→ exact release preparation → four-ID release-evidence reference → manifest
→ K3 prepared row → publication reservation
→ publication permit → K3 publication_permit_pending
→ U / H → publication arm
→ sink query / possible call → sink receipt
→ publication finalization or indeterminate record → K3 boundary closure
```

Fault injection cuts immediately before and after every durable element above,
before and after each verifier's physical-call boundary, and at the
post-call/pre-observation and post-sink/pre-receipt gaps. A cut before a
verifier terminal history may resume only the same allocated ordinal when the
incumbent Provider recovery matrix proves no possible start, or
query/reconcile the same identity after a possible start. A completed verifier
reopens the exact `A/C/S/P/R` lineage; a failed/cancelled/indeterminate
verifier reopens only its exact terminal history with no fabricated `P` or
`R`; an unknown or unsealed verifier blocks `Everify`. A cut after
`replacementRequired` may never reopen the abandoned `Sp/Env/Everify/Vrow/V/Y`
as publishable. A cut after `Vrow` but before `V`, or after `V` but before `Y`,
reconstructs only from the exact installed row and same evidence; it does not
repeat verification or widen visibility. After publication arm or any possible
sink crossing, recovery only queries, reconciles, seals, or finalizes the same
publication identity. It never creates a sibling permit, re-arms, calls the
sink blindly, or treats a spool, `Everify`, `Vrow`, `V`, or `Y` as public
completion by itself.

For command execution, existing runtime and adapter receipts must be committed
as an ordered boundary chain referenced by the recovery cursor. Pre-call
receipts contain only already-known intent, permit, anchor, arm, and handoff
facts; none may predict future output, status, or success. Post-call observed
and terminal receipts bind the actual process/operation handle when available,
output Artifact references, heartbeat/checkpoint observations, and terminal
result. Recovery resumes or reconciles from the exact chain position. This
design adds no graph-specific command store.

The command boundary has the exact crash-cut sequence
`intent → permit → anchor → arm → handoff → physical-call boundary →
observation → terminal seal`. Each durable transition has a stable operation
identity and is idempotently reopenable. Fault injection cuts immediately
before and after every element, including the non-durable moment at which the
physical adapter call may cross. A pre-call receipt cannot claim that crossing
did not occur after its own commit, and an observation cannot substitute for
the owner-proved terminal seal. Any crash between handoff and terminal truth
therefore follows the exact possible-start reconciliation row, never a generic
retry.

If the process is alive, the adapter may reattach through its governed handle
only when the matrix admits that exact live invocation. If it is dead, a pure,
idempotent, or explicitly restartable command may restart only when the matrix
proves the same certified step, committed inputs, current epochs, unchanged
budget, and no possible external start. An effectful command with unknown
outcome enters the same reconcile-only rule as every other external effect.

## 15. Self-Repair and RSI

Self-repair has three non-overlapping levels:

| Level | Permitted action | Authority ceiling |
|---|---|---|
| L1 deterministic recovery | cache discard, currentness/lease classification, exact-branch continue/query/reconcile/seal/finalize, and matrix-authorized same-live-invocation checkpoint reopen | No semantic, route, model, profile, request, budget, or authority change |
| L2 bounded graph replan | propose/validate a G2 patch within current capability and budget | Existing semantic owners plus L14; K3 only CAS-publishes |
| L3 governed RSI | proposal → sandbox trial → evidence → comparison → operator adoption | Cannot self-adopt code, weights, schema, policy, or owner changes |

L13 may create an evolution proposal and read set. K3 may stage and preserve
evidence. Certification and production cutover remain the only paths to a new
authoritative epoch. A live Attempt cannot rewrite its own semantic core.
Signed compatible fallback is only the architecture's pre-allocation case in
Section 5. Once allocation or possible start exists, no self-repair level may
replace or locally retry that branch under the old root.

## 16. Fourteen-Layer Mapping

The graph adds no semantic layer:

| Layer | Graph contribution |
|---|---|
| L1 Wick Life | life policy, node/loop resource requirements, budgets, leases, hard caps |
| L2 Brain Tissue | per-node model requirement, neural plan, neural-result interpretation |
| L3 Folded Lung | independent context admission, compilation, binding, accounting, fingerprint |
| L4 World Prior | versioned world claims referenced by node inputs |
| L5 Host Constitution | user/App-Agent policy, persona, disclosure, isolation |
| L6 Situation | normalized intent, task frame, current situation, risk hints |
| L7 Mirror Blade / Grounding | evidence requirements, eligibility, fusion, coverage, conflict |
| L8 Hippocampal Memory | snapshot-bound SQL/exact/FTS/BM25/dense/temporal/entity projections |
| L9 Kunlun / Dream | candidate decomposition, alternatives, portfolio, selection |
| L10 Tribunal | node/output constraints, critique, claim support, convergence, verification |
| L11 Risk | risk, confirmation, disclosure, continuation and egress eligibility |
| L12 Soft Hand | non-visible exact spool, presentation, `BASResponseReleaseCoordinator` sink release, `BASNextQuestionProjection` |
| L13 Evolution | prepare/commit/reconcile/evolution and Mission-patch proposals |
| L14 Sovereign | admission, exact-digest authorization, revocation, graph-version adoption, terminal seal; never the presentation/sink owner |

The current mapped owners compose these receipts. The graph executor itself
does not acquire any row's semantic authority.

## 17. Kernel and ControlRing Mapping

| Axis | Responsibility |
|---|---|
| K1 Lease & Life | resource observation, reserve/defer/reject/serialize, heavy-owner gate, cancellation/checkpoint signals; no model/route/profile/branch selection |
| K2 Neural Organ | execute the already-selected Provider-neutral neural plan, prefill/decode/cache mechanism and neural-state leases |
| K3 State & Evolution | one selected `FULL` EventLog writer; roots, Attempt heads, Provider/delegation allocation CAS, terminal facts, zero-allocation proofs, budget rows, and opaque continuity-reference binding |
| K4 Sovereign Microkernel | capability issue/reserve/claim/anchor, replay defense, audit |
| ΩR Resource | resource transition, pause, checkpoint, eviction, compatible remand |
| ΩG Grounding | additional bounded retrieval, coverage/conflict remand |
| ΩD Deliberation | candidate revision, verifier-driven branch or stop |
| ΩE Effect/Evolution | effect query/reconcile/compensate and offline evolution evidence |

G3 is only the observable invocation graph of these four rings. It does not
change their exact count or authority.

`BASSemanticTurnEdgeBinding` remains a W1 `runtime.turn-operation` value
consumed by the W6 Runtime executor; K3 persists/compares the referenced
allocation and terminal facts but does not own that value contract.
`WorkUnitRecoveryCursor` remains a W1 `state.snapshot-contracts` nested value
inside `ContextContinuityManifest`; K3 binds its Artifact reference opaquely
and never interprets its continuation semantics.

## 18. W0-W6 Placement

No work moves to W7:

| Wave | Required graph work |
|---|---|
| W0 | Freeze second graph writers, second schedulers, shared mutable Agent state, direct Provider scheduling, and legacy multi-round adoption paths. Extend existing hazards; do not implement future APIs. |
| W1 | Complete the original `runtime.semantic-dag` M Create with model-neutral immutable DAG/edge/input-port/node-applicability/join, delegation/closure, semantic-Attempt terminal receipt, and exact Section-8 G2 V1/task-join values; freeze context/continuity/recovery and RSI contracts. Atomically update the incumbent candidate manifest/ledger/schema/fixtures; perform no retrieval, execution, allocation, network, effect, or activation. |
| W2 | Install one K3 `FULL` nucleus with Workspace/Mission/Attempt roots, active-head CAS, Provider/delegation allocation CAS, terminal facts, zero-allocation proofs, budget rows, opaque continuity-reference ordering, and the semantic-Attempt terminal receipt in the existing sole K3 receipt-factory/historical-put allowlist. W1 Runtime values remain foreign contracts. Production Provider allocation remains disabled. |
| W3 | Integrate snapshot retrieval, grounding, State Market, context compilation, structured reasoning, and graph fixtures in shadow mode. |
| W4 | Integrate external Core AI/AFM/local/API Provider packages, execution plans, certified envelopes, K1/K2/K3 handoff, cache/prefill/decode mechanisms, and graph-bound values only. W4 performs no semantic-DAG executor wiring, graph shadow parity, replay cutover, or activation. |
| W5 | Complete K4, isolated/remote egress, tools/effects, publication, erasure, unknown-effect reconciliation, and durable boundary recovery. |
| W6 | Preserve the master's exact order: Runtime Task 2 value-declaration prelude → Semantic Task 8 audit-value/schema prelude → Runtime Task 1 Part B outcome/final-audit-envelope freeze → Semantic Task 8 coordinator behavior → Runtime Tasks 2/3/4 plus Task 5 remainder → Runtime Task 6 aggregate certification → content-intake `production.cutover` A slice → all-seven-slice reachability while visibility remains dark → Runtime Task 7 sealed cutover. Mechanical DAG wiring, Section-12 two all-member barriers/per-member start gate, frozen join, shadow parity, replay, and recovery must be assigned to their mapped pre-Task-7 Runtime slices; Task 1B is not redefined as the whole executor. |

Cold 40 tok/s and sustained 30 tok/s remain optional exact-profile physical
claims. They are not graph, W6, or architecture completion criteria.

## 19. Exact Six-Plan Amendments

The implementation plan produced from this specification is limited to these
six executable documents:

### 19.1 Reconstruction master

`docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md`

- add the graph invariants and G0-G4 distinction;
- add the W0-W6 placement and dependency order;
- bind the design spec commit/blob/digest;
- keep five executable children and existing terminal/handoff structure;
- do not create a graph child plan or W7.

### 19.2 Authority Ledger and Cw evidence

`docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md`

- merge exact graph terms into the existing 7 controlled documents and 4
  governing addenda;
- extend the incumbent convergence checker, mutant corpus, Owner-Ledger
  closure, production reachability, and source/entrypoint classification;
- carry forward approved graph contracts currently present only in the
  non-executable 2026-07-19 controlled-convergence source;
- do not add a twelfth authority document or a graph owner.

The 7 controlled documents divide responsibility as:

| Document | Graph responsibility |
|---|---|
| Architecture | G0-G4, 14/4/4/7 invariants, cross-axis boundaries |
| Convergence master | W0-W6 dependency, cutover, proof order |
| Contracts | immutable wire values and fixtures |
| Runtime | mechanical readiness, barrier, replay, recovery, retirement |
| Semantic | snapshot, retrieval, grounding, context inputs |
| Silicon | physical Provider execution and envelopes, no graph authority |
| Sovereign | authorization, effect/recovery boundaries, terminal seal |

The 4 governing addenda divide responsibility as:

| Addendum | Graph responsibility |
|---|---|
| K3/Provider | roots, CAS, bindings, branch identity, unknown-effect rules |
| Agent/Context/RSI | delegation, independent context, continuity, loops |
| App Agent | Session/App-Agent identity, persona and writable-state isolation |
| Governed Learning | evidence flywheel, candidate strategy, operator adoption |

### 19.3 Bootstrap verifier and admission

`docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md`

- retain the fixed 19 gate contracts/modules/corpora, 152-cell wave matrix,
  and non-empty discovery rules; add no twentieth gate;
- Bootstrap owns the authoritative B0 gate contracts, modules, non-empty
  corpora, verifier behavior, fixed selection, anti-vacuity/dependency rules,
  evidence admission, and its independent
  `production_graph_reachability` evaluation primitive;
- Authority owns candidate-side evidence production, source classification,
  and parity/checker helpers, never the authoritative B0 verdict; each domain
  plan owns its semantic suites, fixtures, output schema, and mutations;
- map graph checks into the existing IDs
  `qinao.owner-ledger`, `qinao.production-reachability`,
  `qinao.architecture-closure`, `qinao.w0-open-set`,
  `qinao.contracts-layercell`, `qinao.semantic-statelake-context`,
  `qinao.silicon-execution-spine`, `qinao.sovereign-release-effects`, and
  `qinao.runtime-replay-certification`;
- retain predecessor-derived verifier/module selection;
- do not let the candidate judge its own wave.

### 19.4 C0 provenance and safe import

`docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md`

- make no C0 schema or semantic change;
- preserve this design as held inventory/provenance input and bind its
  reviewed commit/blob/SHA in the amended plans;
- enforce the exact order: commit all six plan amendments in preserved source
  → run C0 inventory/provenance capture → execute the sole fixed ten-row C1
  context/review/apply workflow;
- never add this design as C1 row eleven or “refreeze” C1 after the amendment;
- do not add a graph-specific import path or bypass review.

### 19.5 W0 safety and K4 proof

`docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md`

- keep the existing closed 16-ID W0 hazard set;
- extend the existing `runtime.untyped-shared-agent-state` hazard's source,
  reachability, fixture, and negative-token coverage to include second graph
  writers, shared scratchpads, direct peer calls, and legacy loop authority;
- classify `BASAppleTaskGraphLifecycleExecutor.refresh` as read-only or
  production-unreachable;
- create no future graph contract or behavior at W0.

### 19.6 Artifact Mesh W1 Task 0

`docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md`

- make no graph-specific schema, owner, field, store, or handoff change;
- graph contracts, bindings, cursors, and receipts use existing ordinary-put,
  reopen, durability, and recovery mechanisms;
- retain the exact Task-0 owner transition and Phase-A/Phase-B proof.

### 19.7 Normative dependency and ownership pins

The six-plan amendment must preserve the following ownership map. A later
plan may pin this specification's reviewed commit, blob, and SHA-256; this
file cannot truthfully embed the digest of its own not-yet-created review
commit.

| Normative source | Exact section/type | Authority consumed here |
|---|---|---|
| `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md` | §14.4 `TaskNode`, task-graph patch, `AttemptRef`, `activeAttempt`; §26.2 exact buffered response release; §26.3 fallback/rebase boundary; §33.6 physical parallel threshold | one Task DAG transaction, one Attempt boundary, exact response order, pre-allocation-only fallback, and `0.95 ×` physical proof |
| `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md` | §1.3 owner map; §3.2 `BASDelegationProposal` and optional slots; §4.1 `BASContextCapsule`; §4.2 joins; §4.3 two barriers/per-member start; §4.5 strict rebase; §4.6 `ContinuationPolicy`, `WorkUnitRecoveryCursor`, `RecoveryDisposition`; §5 receipt-driven RSI; §8 next-question projection; §9.1 Provider flow | model-neutral collaboration, capsule variants, continuity, exact recovery matrix, loop discipline, scheduling barriers, and Provider order |
| `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md` | §5 sole K3 receipt factory/row-pinned historical-put seam; §6.5 `BASControlLoopTerminalReceiptPayload` v2; §6.6 sole v1 migration seam; §11 exact invocation order; §16 crash/recovery matrix | byte-identical K3 receipt rematerialization, optional budget-use receipt only with K3 zero-use truth, adoptability proof, exact Provider ordering, and presence-shape recovery |
| `docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md` | §3.2-§3.4 Main/Sub/Session meaning; §5.5 capsules; §9.2 recovery; §12.2 `BASNextQuestionProjection` | App-Agent/Session selection and persona isolation remain separate from Attempt execution truth |
| `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md` | §3.4 context/model ordering; §4.1 final response; §5 and §5.1 governed PD/egress/completion order; §6.4-§6.5 continuity/fallback; §6.7 independent contexts/cache; §7 next-question correction; §11 K4/wave discipline | corrected end-to-end ordering, completion suffix, Agent independence, and controlled-convergence precedence |
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerCascadeRunner.swift` | `BASJoinPolicy`, `BASControlLoopProgressKind`, `BASControlRingTerminalState`, `BASControlLoopTerminationReason`, and terminal pair validation | exact currently implemented raw spellings and allowed pairs only; payload currentness/migration is governed by the K3 addendum |
| existing Owner Ledger rows | `runtime.semantic-dag`, `runtime.turn-operation`, `state.snapshot-contracts`, `state.context-compiler`, `semantics.layercell`, K3/K4, Zone C, publication, `runtime.certification`, `production.cutover` | unique production owner/mechanism boundaries; no graph owner is created |

The W1 `runtime.semantic-dag` first-wire owner freezes G1 topology, typed edge
roles, input-port/applicability contracts, optional slots/closure, and the
frozen join contract plus its K3-derived semantic-Attempt terminal receipt.
There is no separately mapped TaskNode/patch/join owner. As a controlled
pre-implementation delta to that same approved-missing M Create, Section 8
adds the complete G2 V1 value set, including Task Graph join evidence. The
six-plan amendment must update the original Owner-Ledger domain and Create
candidate's planned-member/schema/fixture/consumer closure atomically while
preserving root authority symbol `BASSemanticTurnDAG` and the one allowed
source path.
`runtime.turn-operation` composes Attempt-bound references and
`BASSemanticTurnEdgeBinding`. `state.snapshot-contracts` owns continuity
values. `state.context-compiler` owns compilation. K3 owns only the physical
rows and CAS facts listed in Section 17. The six amended plans must point each
proof to one of the existing gate IDs in Section 19.3 and must not create a
seventh plan, twelfth governing document, or twentieth gate.

## 20. Proof Obligations

The items below are future W0-W6 runtime proof obligations to be assigned
mechanically into the six executable plans. They are not claims that this
specification already implements or passes runtime behavior. Existing
controlled gate programs must gain non-vacuous coverage for:

### 20.1 Contract and topology

- exact G1 acyclicity and stable canonical ordering;
- exact G1 DAG-root versus eight embedded-topology-type schema/registry/
  fixture closure, including the concrete join-member contract;
- aggregate `1_018` terminal-disposition and per-invocation `1_024` input/
  policy bounds, including exact-boundary acceptance and plus-one rejection
  before K3 commit or Artifact put;
- full post-patch G2 acyclicity including incumbent/cross-root/reference edges;
- closed dependency-role vocabulary;
- deterministic edge-ID derivation and typed identity namespaces;
- total one-to-one edge/input-port mapping; closed applicability/obligation
  tags; alternative-group cardinality; and exact all-inapplicable evidence;
- complete role-satisfaction matrix with typed evidence on every applicable
  edge;
- exact semantic-Attempt terminal receipt reconstruction from the preceding K3
  terminal row, its outcome-specific evidence grammar and terminal-cut digest,
  including the frozen `executionShape`/invocation-envelope equivalence,
  pure-DAG-only successor-Attempt remand, denial of both remand forms for a
  controlRing-shaped consumer before a real ring invocation, inert orphan
  invocation Artifacts, deterministic `noLegalRemand` precedence over a
  simultaneous budget/deadline observation, and no fabricated ControlRing
  envelope, through the extended sole K3 receipt-factory/historical-put
  allowlist with row-pinned identity inputs and key epoch;
- exhaustive designated-terminal outcome routing, including
  `designatedTerminalNoProgress` for both zero-join and joined sinks, exact
  invocation/receipt bytes and currentness in its deadlocked-frontier digest,
  its one-ID evidence prefix, ordinary empty-frontier zero-prefix separation,
  and mutations proving success/cancellation/remand/reconciliation/budget/
  deadline cannot be swallowed by direct terminal no-progress;
- finite delegation slots and exact depth-one rule;
- every optional slot has exactly one legal closure;
- exact one-join-per-consumer coverage, input-obligation-derived member
  requirement, unique per-member terminal disposition including unsatisfied
  required members, deterministic conflict/evidence vector generation,
  exact per-policy received/missing partition, pure-DAG disposition-prefix/
  policy-input-suffix replay, Attempt-global failed-cause ordering,
  path-specific remand, zero-join pure-DAG source acceptance, `controlRing`
  source/empty-join rejection, nonvacuous all-inputs-inapplicable evaluation,
  and an independent mutation oracle for every alternative group;
- exact Section-8 G2 V1 fields/tags/canonical order, Mission/Objective/WorkUnit
  hierarchy, Attempt exclusion, typed read/write/precondition sets, legal
  kind-specific status transitions, two stored schema roots versus twelve
  unregistered embedded values, WorkUnit completion restricted to the exact
  current semantic-Attempt `completed` receipt, completed/cancelled child
  terminal-basis coverage, completed-versus-cancelled parent outcome
  fixtures, exact `notApplicable | neverAdmitted | terminalAttempt` parent
  basis, recursive cancellation quiescence, never-admitted and
  terminal-Attempt WorkUnit cancellation, cross-Attempt evidence-reuse
  rejection, completed-receipt cancellation-basis rejection and deterministic
  completion-versus-cancellation CAS competition, request/timeout/
  possible-start rejection, and budget/authority non-amplification;
- deterministic Task Graph root preimage, initial-open installation,
  checked initial/successor counter table with no wrap, affected-WorkUnit/
  active-Attempt closure, transitive batch footprint, one-time common-base
  root validation plus simulated non-root rechecks/successive roots, and
  Mission/Objective join evidence against current child generations and
  terminal Attempt refs;
- atomic `runtime.semantic-dag` Owner-Ledger/candidate-manifest/schema/fixture
  closure with no partial first wire or second TaskNode owner;
- no orphan edge, unresolved required input, or duplicate terminal;
- no topology mutation inside one Attempt;
- no new manager, owner, EventLog, compiler, scheduler, ring, kernel, or plane.

### 20.2 Concurrency and durability

- K1/K3 CAS competition, duplicate requests, stale generation, and ABA cases;
- exact Provider ordering from capability admission through L2/L3 plan freeze,
  governed descriptor-parent PD, K1 reservation, K3 use/allocation reopen A,
  providerStep, materialization reopen M, answer-source pin, route-specific
  L11/L14 one-shot K4 use, governed egress permit, pending/anchor/arm B, fresh
  claim/handoff, K2 execution, exact completed P/O/At/C/Srow/S/R/lineage
  suffix, and closed sealed/unsealed non-completed suffixes;
- exact terminal-prefix X → Sp/Env → every preauthorized verifier
  PlanV/PDV/A/providerStep/M/route/completion closure → all-ordinal terminal
  barrier → Everify → L11/L14/final outcome → Vrow/V/Y → preparation/
  manifest/publication chain, including permanent abandoned-candidate fences;
- first-matching-unoccupied delegation under concurrent proposals;
- per-node durable completion and no successful-sibling rerun;
- deterministic ready-frontier calculation;
- zero mechanism starts until both all-member barriers pass; source-order
  preparatory cleanup; immediate per-member drift/lease/grant/budget/claim
  recheck; and exact local versus isolated/remote start order;
- every `all`/`quorum`/`best-effort-with-coverage` matrix cell under
  applicability, cancellation, partial failure, impossible quorum, coverage
  gap, conflict, and possible-start;
- optional Agent fan-out remains serial and rejects missing/stale/drifted
  certification, wrong device/Provider/specialist set, substituted one-Main
  baseline, overlapping/undersized cohort, failed confidence bound, or hard
  ceiling regression; required overlap rejects unknown
  concurrency/side-effect classes, missing/drifted proof digests, conflicts,
  missing/wrong communication-profile owner/version/digest, unbucketed
  size/timing, missing correlation/source labels, shared or unknown
  model/prompt/evidence/cache/retrieval/tool ancestry counted as independent,
  wrong validator scope, and GPU/Neural Engine profiles above the `0.95 ×`
  threshold or with any regression;
- exact replay from EventLog plus Artifact Mesh after cache clearing.

### 20.3 Crash-cutpoint matrix

Fault injection must cut immediately before and after every durable or
protected boundary, including:

- graph-patch proposal put, slot/delegation allocation, graph/root CAS,
  descendant/active-head/grant fences, edge binding, and join/remand put;
- governed PD ordinary-put/reopen → K1 reservation/lease acquisition, including
  lost reply, expiry, and exact cleanup with no semantic reroute or second
  reservation;
- K3 budget-use row commit → historical `BASBudgetUseReceipt` put/reopen;
- K3 Provider allocation row → reconstructed A put/reopen → `providerStep`
  put/reopen → M put/reopen;
- terminal-answer source-pin row → reconstructed T put/reopen;
- isolated/remote K4 use row → use receipt, egress-permit ordinary put →
  dormant K3 pending row, K4 anchor row → anchor-receipt put, and K3 arm row →
  reconstructed B put/reopen;
- fresh K3 claim Q → local physical-call boundary, or Q+B handoff CAS →
  remote physical-call boundary;
- completed P/terminal-result put, isolated/remote O put then At put, C
  reconstruction, K3 terminal Srow, S reconstruction, R put, and five-ID
  lineage append;
- observed local non-completed C/Srow/S, authenticated isolated/remote
  non-completed O/At/C/Srow/S, and every unsealed local-owner-loss,
  unauthenticated-remote, or `sent_or_unknown` presence shape;
- terminal-prefix X, response spool/Env, every verifier PlanV/PDV/A/
  providerStep/M/route/call/P-or-terminal-history seam, all-ordinal barrier,
  Everify, L11 and L14 authorization/denial/final outcome, Vrow/V/Y,
  release-preparation/manifest put, K3 prepared row,
  publication-journal reserve, K3 publication permit, K4 anchor, K3 arm, sink
  call, sink observation, journal finalization/indeterminate row, K3
  close/indeterminate row, and continuity projection;
- effect permit/anchor/arm/handoff/observation/terminal or indeterminate seal;
  and
- command intent, permit, anchor, arm, handoff, physical-call boundary,
  observation, and terminal seal.

Each row→Artifact seam is a separate cut: a committed authoritative row with a
lost reply reconstructs only the byte-equal historical receipt, while an
orphan ordinary Artifact without its required row is inert. Each
Artifact→row seam is also separate and may only adopt the exact reopened
Artifact. A cut at or after a physical call/handoff never uses absence of a
later receipt as proof of no start. The oracle records the exact
`A/M/T/use/permit/pending/anchor/B/Q/P/O/At/C/Srow/S/R/lineage` presence shape
and must select the corresponding completed, sealed-noncompleted,
reconcile-only, or quarantine row from the governing Provider matrix.

Every cutpoint must resolve through Section 14's exact `ContinuationPolicy`
and recovery matrix to `restoreCompleted`, `resumeSameAttempt`,
`reconcileSameOperation`, `rebuildAfterTerminal`, `awaitUser`, or
`quarantine`. A strict successor or independently admitted WorkUnit must
satisfy its own authority protocol; “retry with a new generation” and “run
everything again” are not accepted oracles.

### 20.4 Loop and liveness

- repeated state-plus-strategy detects a cycle;
- unchanged evidence/conflict/unresolved sets detect no progress;
- every hard budget terminates;
- no-ready/no-wait/no-terminal causes the idempotent K3
  `rejectedNoProgress` Attempt terminal transition and byte-equal
  `BASSemanticAttemptTerminalReceiptPayload` recovery; an actual ControlRing
  separately uses `rejected + no-progress`, while protected possible-start
  remains reconciliation rather than deadlock;
- heartbeat timeout remains an observation;
- v2 canonical optional-key encoding, explicit-null rejection, byte-identical
  v1 migration, future-version rejection, and no historical rewrite;
- nil budget-use receipt is accepted only against a K3 zero-use terminal row;
- only `converged + converged-verified` plus a current committed nonnil K3
  `BASBudgetUseReceipt` feeds authoritative adoption;
- deadline expiry cannot reset/re-arm, no legal wait survives it, and each
  ControlRing/ContinuationPolicy/external-boundary case reaches the exact
  Section-13 outcome.

### 20.5 Agent and context isolation

- exactly one Session-stable logical `sessionMainAgentID` across WorkUnits,
  Attempts, context rebuilds, and authorized Provider re-embodiments, alongside
  zero-or-one Main Provider identity per Attempt with zero allowed for
  deterministic/denial paths;
- exactly one selected App Agent per visible Session only through the separate
  App-Agent binding;
- no Sub-to-Sub or shared mutable scratchpad path;
- capability attenuation and budget isolation;
- incompatible Provider/tokenizer/template contexts rebuild;
- each Main/Sub/local/AFM/PCC/API branch derives its independent effective
  context ceiling from the exact minimum/reserve rule, with no character
  heuristic, pre-authorization remote count, authority widening, or
  cross-profile truncation/reuse;
- static compartment/source-query/cache-key/trace/reference reachability
  invariants prevent a foreign ContextWorkspace/App-Agent scope from becoming
  an eligible SQL, FTS, vector, cache, trace, or Provider input, with a
  cross-scope negative corpus for every path;
- exact low-entropy Agent-envelope fields, communication-profile
  owner/version/digest, size/timing buckets, correlation/source labels,
  ancestry comparison, independently scoped validator, and denial/discount
  mutations for every missing, mismatched, shared, unknown, or drifted field;
- timing leakage is not claimed impossible: it remains an explicit measured
  threat-model/certification item with profile-specific bounds and regression
  evidence;
- persona cannot bypass verification, risk, or authorization.

### 20.6 Source, CI, and cutover integrity

- every filtered test first proves positive discovery;
- every named source scan first proves a readable regular file and treats
  exit 2 as failure;
- checker tests run in CI and cannot be zero-discovery;
- production build/link/factory/DI/call-graph closure makes incumbent graph
  and scheduling authorities unreachable before new activation;
- W6 has no dual-write or dual-adoption interval;
- optional 40/30 performance evidence is not an unconditional gate.

Property tests, randomized bounded DAGs, mutation testing, differential
scheduler tests, deterministic replay, concurrency stress, physical-device
fault injection, thermal/memory pressure, Provider loss, remote disconnect,
and unknown-effect matrices are all required at their existing wave.

## 21. Research Translation

External systems are inspiration, not dependencies or authorities:

- LangGraph demonstrates checkpointed graph execution, subgraph interface
  isolation, and per-invocation Sub Agent state. Qinao keeps the isolation and
  recovery lessons but pins the exact Attempt DAG; it does not resume against
  an arbitrarily changed graph definition.
- Temporal demonstrates append-only workflow history, deterministic workflow
  replay, and explicit idempotent/non-retryable activity boundaries. Qinao
  applies those lessons only at its existing EventLog and effect boundaries;
  it does not event-source every application object.
- OpenAI Agents SDK distinguishes manager-owned synthesis, handoffs, bounded
  Agents-as-tools, code orchestration, and maximum turns. Qinao selects
  Main-owned synthesis plus bounded Sub-as-tool semantics while retaining
  deterministic slot allocation and semantic gates outside the model.
- Pregel motivates frontier computation followed by a barrier. Qinao uses a
  small per-turn variant with durable per-node receipts, not a distributed
  mutable vertex store.

Primary references:

All references were accessed on 2026-07-24. Repository sources are pinned to a
tag or full commit, and Pregel by its DOI. They remain design inspiration only;
Qinao's implementation and tests depend on the governed local contracts above.

- LangGraph `1.0.10`:
  <https://github.com/langchain-ai/langgraph/tree/1.0.10>
- Temporal
  `0df2dad51c0b19b135c7bb803f21ec11f9842c58`:
  <https://github.com/temporalio/temporal/blob/0df2dad51c0b19b135c7bb803f21ec11f9842c58/docs/architecture/README.md>
- OpenAI Agents SDK
  `5921667f570aa73a9f1d18b9a4ba0cb6c9549669`:
  <https://github.com/openai/openai-agents-python/blob/5921667f570aa73a9f1d18b9a4ba0cb6c9549669/docs/quickstart.md>
  and
  <https://github.com/openai/openai-agents-python/blob/5921667f570aa73a9f1d18b9a4ba0cb6c9549669/docs/running_agents.md>
  and
  <https://github.com/openai/openai-agents-python/blob/5921667f570aa73a9f1d18b9a4ba0cb6c9549669/docs/multi_agent.md>
- Pregel, DOI `10.1145/1807167.1807184`:
  <https://doi.org/10.1145/1807167.1807184>

## 22. Explicit Non-Goals

This design does not:

- adopt LangGraph, Temporal, an Agents SDK, or another server framework into
  the iOS authority path;
- expose private chain-of-thought or persist it as memory;
- permit arbitrary graph generation or self-modifying code;
- promise that every task benefits from multiple Agents;
- parallelize dependent tasks for appearance;
- share model sessions, transcripts, or KV state across incompatible
  Providers;
- make a stronger API model more authoritative than a local model;
- introduce a general global event-sourcing architecture;
- activate incremental visible output in V1;
- implement production graph behavior before its existing W0-W6 gate;
- modify Artifact Mesh Task-0's owner or handoff;
- reinterpret a stalled process as a resumable CPU continuation.

## 23. Acceptance Criteria

These criteria accept only the mechanical amendment of the six executable
plans. They do not claim that future runtime behavior is implemented,
benchmarked, certified, or cut over. The amendment is complete only when:

1. the reconstruction master binds this reviewed spec commit/blob/SHA and
   contains the sole authoritative full wave/program order; every child binds
   the same reviewed spec, references that master order, and declares only its
   local insertion/dependency/handoff;
2. the 7+4 convergence matrix carries every approved graph contract to exactly
   one incumbent owner and introduces no owner/document/plan;
3. W1 atomically completes the original `runtime.semantic-dag` M candidate
   with edge/input-port/applicability/join, delegation, semantic-Attempt
   terminal receipt, and exact G2 V1 contracts/Task Graph join evidence plus
   ledger/schema/fixture/consumer closure; capsule/continuity and loop-v2
   compatibility are complete rather than placeholders, and a completed
   WorkUnit Attempt cannot be reclassified by a competing cancellation
   transition;
4. W0 assigns second-writer/shared-state/legacy-loop freezes to the existing
   16-ID hazard set and `qinao.w0-open-set`, without a seventeenth ID;
5. Bootstrap retains exactly 19 gates and the 152-cell matrix, and maps graph
   proof only into `qinao.owner-ledger`,
   `qinao.production-reachability`, `qinao.architecture-closure`,
   `qinao.w0-open-set`, `qinao.contracts-layercell`,
   `qinao.semantic-statelake-context`, `qinao.silicon-execution-spine`,
   `qinao.sovereign-release-effects`, and
   `qinao.runtime-replay-certification`;
6. Bootstrap owns the authoritative B0 contracts/modules/corpora/verifier and
   independent reachability evaluation; Authority owns candidate-side
   evidence/parity helpers; domain plans own their suites/fixtures/schema/
   mutations;
7. C0 follows `six-plan amendment commit → C0 capture → fixed ten-row C1`,
   while Artifact Mesh Task 0 retains its exact owner transition and schema;
8. the plans preserve exactly 14/4/4/7 and W0-W6, leave executor
   wiring/shadow parity out of W4, and preserve W6's exact
   `Runtime 2 prelude → Semantic 8 prelude → Runtime 1B → Semantic 8 behavior
   → Runtime 2/3/4/5 remainder → Runtime 6 → intake A/reachability-dark
   → Runtime 7` order;
9. every loop, strict successor, command, recovery, publication, and
   unknown-effect proof is assigned to its exact incumbent contract/matrix and
   named gate; Provider ordering and W6's two barriers/per-member start gate
   are explicit, with no generic retry or recovery authority;
10. W6 plans one sealed cutover proof with no dual production graph,
    scheduling, adoption, or state writer interval; completion remains a
    future certified result rather than a statement made by this design.
