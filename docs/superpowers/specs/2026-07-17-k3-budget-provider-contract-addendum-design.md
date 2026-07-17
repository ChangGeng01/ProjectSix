# K3 Budget and Provider Contract Addendum

**Date:** 2026-07-17

**Status:** Design decisions approved; document review pending

**Scope:** K3 control-nucleus contracts for bounded RSI/control-loop budget use, Provider branch allocation and execution, Provider evidence, and Provider lineage

**Normative precedence:** This addendum supersedes conflicting K3 budget/Provider wording in the 2026-07-14 architecture design and the 2026-07-15 Contracts, Silicon, Semantic, Sovereign, and Runtime plans. Unchanged rules in those documents remain in force.

## 1. Decision

Qinao uses one composite K3 control nucleus, not a generic EventLog authority and not a collection of sidecar managers:

```swift
public protocol BASK3ControlNucleusStorage:
    AnyObject,
    BASEventLogStorage,
    BASBudgetLeaseControlPort,
    BASProviderBranchControlPort
{}
```

The one selected production object is `BASSQLiteEventLogStorage`. The EventLog source head, Attempt/generation state, budget-lease rows, Provider branch rows, source pin, logical visibility gate, and K3 boundary rows share one SQLite connection, one file, one WAL, one writer lease, and `synchronous=FULL`. No protocol named above owns state; each is a narrow view over that same object.

The approved shape is an independent contract addendum because the existing plans are internally inconsistent at the Provider gate/claim boundary and omit several persisted values required for honest recovery. This addendum does not create a second scheduler, EventLog, retry owner, receipt store, Provider registry, budget manager, or global reducer.

## 2. Current Baseline

At branch `codex/qinao-w1`, commit `ffc9a8922`:

- `BASTurnOperationRef`, typed branch references, `BASProviderExecutionRef`, `BASTurnOperationPayload`, and `BASBudgetLeasePayload` exist.
- `BASEventLogHead` exists as a value projection.
- `BASEventLogStorage` still has only append/read/prune operations; it does not yet expose K3 head-aware budget or Provider command semantics.
- `BASBudgetUseReceipt`, Provider policy/chain/observed values, the five K3 Provider receipts, and both K3 control ports are not implemented.
- Existing plans reference `proposalReceiptArtifactID`, but no generic `BASProviderProposalReceipt` schema or registry owner exists.
- Existing plans reference materialized Provider payload IDs, but no governed, model-neutral materialized-request payload exists.
- `BASControlLoopTerminalReceiptPayload` v1 requires a budget-use receipt even when K3 rejects a claim without spending.

These are implementation gaps, not permission to add parallel owners.

## 3. Scope and Non-Goals

This addendum freezes:

1. the K3 budget-use command, receipt, terminal outcome, recovery, and v1-to-v2 terminal migration;
2. the Provider branch policy and its relationship to `BASSiliconExecutionBinding`;
3. allocation, pre-claim terminal pin, logical visibility, claim, event-head seal, and state-query contracts;
4. the fresh-winner-only physical call capability;
5. the model-neutral materialized request, Provider observation, generic Provider proposal receipt, and attestation closure;
6. the five-ID Provider lineage and the two immutable chain cuts;
7. exact transaction order, crash behavior, hard bounds, and adversarial gates.

It does not choose a model, implement Qwen/MLX/MTP, create a Provider transport, decide semantic content, perform L10/L11/L14 verification, publish bytes, dispatch tools, or commit memory. Those mechanisms remain outside this contract and consume only its evidence.

## 4. Authority and Dependency Boundaries

| Fact or transition | Sole owner | Consumers |
|---|---|---|
| Event/integrity source head, Attempt/generations, budget revision, Provider ordinal/claim/source/visibility rows | K3 / one `BASSQLiteEventLogStorage` | Runtime, semantic layers, Silicon, Sovereign, replay |
| Immutable Artifact identity, canonical payload bytes, ordinary put/read, attestation target index | Artifact Mesh | All packages |
| Provider policy: purpose, roles, causal requirements, counts, answer-only, post-pin permission, visibility mode | `BASProviderBranchPolicy` under `execution.plan-provider-router` | K3 and Silicon binding validator |
| Model/profile/plan-template/materialization/budget mapping | `BASSiliconExecutionBinding` | Silicon executor and replay |
| Exact physical request bytes | `BASMaterializedProviderRequestPayload` under `provider.package-boundary` | K3 claim, executor, W5 permit, observation, replay |
| Transient Provider event tail | `BASTurnRuntimeEngine.TurnOperation` actor | K3 checkpoint/terminal seal |
| Fresh physical invocation | one noncopyable K3 claim permit, and W5 handoff for isolated/remote | `BASProviderAttemptExecutor.executeAtMostOnce` only |
| Capability issuance/claim/anchor | K4 / `BASSovereignTokenAuthority` | K3 boundary fences |
| Provider observation signature validity | existing generic Artifact attestation plus algorithm-agile trust manifest | injected verifier used by K3 sealing/replay |
| Exact output verification and physical visibility | L10/L12/L14 and Sovereign boundary owners | through-visibility chain/release |

Dependency direction remains acyclic:

```text
BASOrgan adapters  →  BASRuntimeCore contracts + sole K3 implementation
                                      ↑
                         BASHostKit composition/injection
                                      ↓
                     BASSovereign verifier conformer / K4
```

`BASSQLiteEventLogStorage` remains in `BASRuntimeCore`; this addendum does not move it or create a BASMemory owner. `BASRuntimeCore` declares the narrow observation-verifier port and never imports BASMemory, BASOrgan, Qinao, or BASSovereign. BASHostKit injects the BASSovereign conformer into the same K3 object. Remote and isolated Provider production paths remain disabled until that verifier and the exact trust-manifest binding are installed.

## 5. Common K3 Command Rules

Every mutating K3 command has:

- a bounded idempotency request ID;
- exact Attempt/root/generation/policy/deletion/boot/deadline bindings, directly or through a referenced prior receipt;
- an expected `BASEventLogHead`;
- a losslessly persisted historical command row;
- a deterministic K3 outcome and the resulting historical source head;
- exact-replay behavior independent of the current later head.

Normal production mutations require exact equality with the active boot. The sole cross-boot mutation is an authenticated isolated/remote query-recovery terminal seal for an existing `sent_or_unknown` row. It carries no call permit, cannot allocate, claim, pin, reopen visibility, or reactivate the root, and must revalidate the original claim/arm plus the current Attempt, generation, policy, deletion, owner, trust-manifest, and recovery-boot facts before the same terminal seal CAS.

Every call follows this rule:

1. bounded-parse only the canonical command envelope needed to obtain command kind, schema version, root, and idempotency key;
2. before reopening any referenced Artifact or consulting current head/epoch/trust state, look up the historical idempotency row;
3. on a hit, compare the incoming canonical request bytes with the stored bytes using that row's schema-pinned decoder and reconstruct the stored receipt body/K3 outcome exactly; the API returns its recovered case and never a fresh permit;
4. treat the same key with different canonical request bytes as corruption;
5. only on a miss, require the current command schema, bounded-decode it, and reopen every referenced Artifact before reducer access;
6. begin one K3 transaction and repeat the idempotency lookup to close the read-to-write race;
7. on a transactional hit, apply steps 3–4; otherwise equality-check live Attempt/generations/epochs, the expected source head, and every historical parent row;
8. mutate only K3-owned rows and append/advance the source event/head in the same transaction;
9. atomically persist the receipt schema version, canonical request bytes, canonical receipt bytes, schema-specific K3 outcome, resulting historical source head, complete identity-factory inputs, commitment-key epoch, and any seal-time proposal identity alias;
10. commit, reconstruct the receipt body solely from that historical row, and use the row-pinned historical-put seam for the self-ID-free receipt outside the K3 transaction.

A crash after K3 commit and before the Artifact put leaves no ambiguity. Recovery reconstructs exactly the same receipt body and identity core from the historical K3 row and may retry only a package-private historical put with the row-pinned commitment-key epoch. Artifact Mesh must retain the verification/commitment material required for that store-owned put. An orphan Artifact put that has no matching K3 historical row is non-authoritative. Current policy or trust revocation may block present adoption/publication, but it cannot rewrite a historical receipt or turn an idempotent replay into a fresh transition.

`BASArtifactStorePort.put` remains the current-epoch path and is not used to reconstruct a committed authoritative receipt. `BASRuntimeCore` declares a separate package-only `BASArtifactHistoricalPutPort`; the same `BASArtifactSQLiteStore` object implements it. K3 captures the epoch from that same store object's immutable active-epoch projection at owner construction, never from a command or factory caller, and writes it into the command row. One store lifetime has one active epoch; rotation installs a new owner/store instance only at the existing quiescent boot boundary, while the resolver retains explicitly supported historical keys. The port's sole put operation accepts an owner-factory identity core plus the commitment-key epoch read from its committed authoritative row, permits only the fixed K3 receipt kinds in this addendum and the existing shared `BASBoundaryArmReceipt`, forces `headUpdate == nil`, resolves that historical key, derives the expected Artifact ID, and then inserts an absent record or byte-verifies an identical existing record. It never consults or substitutes the active epoch.

The existing K3 boundary-arm row follows the same rule: it freezes canonical `BASBoundaryArmReceipt` bytes, complete existing identity-factory inputs, and commitment-key epoch in the arm CAS transaction. All Provider/stream/publication/effect uses share the one existing boundary-arm factory and historical-put helper; this addendum does not change the arm payload, kind, registry entry, or owner. No Provider, plugin, application callback, generic Artifact caller, or proposal factory receives the port, and source gates allow exactly two production factory seams: the addendum K3 receipt factory and the existing shared K3 boundary-arm factory. An unavailable historical key fails Artifact rematerialization closed but does not prevent exact command replay from returning canonical receipt bytes already stored by its authority owner; a boundary that lacks its exact arm Artifact remains non-callable and non-adoptable.

The Artifact identity-core recipe for every addendum payload listed below is schema-specific and not caller-editable. Production code never accepts a caller-built `BASArtifactIdentityCore`; an owner-scoped factory accepts only the validated payload plus authoritative K3/owner facts and calls the existing Artifact Store port. Every listed factory fixes `canonicalizationVersion == "bas-governed-artifact-payload-v1"`, `schemaID ==` the exact Swift type basename, the payload's exact schema version, the kind and producer below, exact `.attempt` scope, owner-derived logical epoch/time, `confidentialityLabel == "qinao-attempt-confidential-v1"`, empty provenance, nil snapshot root, canonical bytes/length from `BASGovernedArtifactPayloadCodec`, and `headUpdate == nil`. Validators reconstruct and compare every identity-core field. The existing generic attestation/trust owners retain their own factories and gain the exact signed-context constraints in Section 12. This prevents multiple caller-selected envelopes around the same payload body.

The receipt factory derives parent IDs in exactly this order; optional slots are omitted only when the nested request field is nil, and a bounded ordered vector is appended without sorting:

| Receipt | Exact ordered Artifact parents |
|---|---|
| `BASBudgetUseReceipt` | Attempt, generation vector, budget lease, control-loop envelope, invocation, optional parent invocation, optional prior use receipt, optional progress witness |
| `BASProviderBranchAllocationReceipt` | Attempt, generation vector, Provider policy, execution binding, execution plan, selected descriptor parent, authorizing budget-use receipt, then ordered causal receipts |
| `BASProviderTerminalSourceReceipt` | allocation receipt, materialized request |
| `BASProviderExecutionClaimReceipt` | allocation receipt, materialized request, optional terminal-source receipt |
| `BASProviderEventHeadSealReceipt` | claim receipt, optional proposal, optional boundary-arm receipt, optional observed receipt, then for isolated/remote terminal seals the K3-selected observation attestation and installed trust manifest |
| `BASProviderVisibilityReceipt` | terminal-source receipt, then the installed mode's typed evidence in request order |

These parent arrays belong to the outer Artifact identity core, not to the receipt body. They add no second receipt schema or authority field. A caller cannot provide or reorder them.

Exact identity kinds and producers are:

| Governed type/cut | Exact `kind` | `producerLayerID` | Exact ordered parents beyond the receipt table |
|---|---|---|---|
| `BASBudgetUseReceipt` | `k3-budget-use-receipt` | `.leaseLife` | receipt table |
| `BASControlLoopTerminalReceiptPayload` | `control-loop-terminal-receipt` | `.leaseLife` | invocation, control-loop envelope, optional budget-use receipt, then ordered evidence IDs |
| `BASProviderBranchAllocationReceipt` | `k3-provider-allocation-receipt` | `.leaseLife` | receipt table |
| `BASProviderTerminalSourceReceipt` | `k3-provider-terminal-source-receipt` | `.leaseLife` | receipt table |
| `BASProviderExecutionClaimReceipt` | `k3-provider-claim-receipt` | `.leaseLife` | receipt table |
| `BASProviderEventHeadSealReceipt` | `k3-provider-event-head-seal-receipt` | `.leaseLife` | receipt table |
| `BASProviderVisibilityReceipt` | `k3-provider-visibility-receipt` | `.leaseLife` | receipt table |
| `BASProviderBranchPolicy` | `provider-branch-policy` | `.neuralOrgan` | empty |
| `BASMaterializedProviderRequestPayload` | `provider-materialized-request` | `.neuralOrgan` | allocation receipt, execution plan, selected descriptor, materialization contract |
| `BASProviderObservedReceipt` | `provider-observed-receipt` | `.neuralOrgan` | boundary-arm receipt, materialized request, selected descriptor, optional terminal proposal, optional terminal result |
| `BASProviderProposalReceipt` | `provider-proposal-receipt` | `.neuralOrgan` | materialized request, proposal, seal receipt |
| `BASExactOutputVerificationPayload` | `exact-output-verification` | `.sovereign` | spool, verifier contract, constraint, then ordered provisional-display receipts when incremental |
| `BASProviderBranchChainPayload.terminalPrefix` | `provider-branch-chain` | `.neuralOrgan` | policy, execution binding, every entry's A/C/S/P/R IDs in entry and field order, then terminal-source receipt |
| `BASProviderBranchChainPayload.throughVisibility` | `provider-branch-chain` | `.sovereign` | policy, execution binding, every entry's A/C/S/P/R IDs in entry and field order, terminal-source receipt, exact-output verification, visibility receipt |

The policy factory resolves Attempt scope and workspace authority from the turn-admission context; every other row derives Attempt scope from its execution/allocation lineage. The materialized-request factory requires the exact allocation receipt as an authoritative construction input and verifies its execution ref against the payload. The addendum K3 receipt factory and existing boundary-arm factory use only the logical epoch/time and commitment-key epoch frozen in their historical rows and reach the package-only historical-put port above. No rotation, retry, generic current-epoch put, or external caller may select a different key epoch for the same committed receipt.

## 6. Budget-Use Contract

### 6.1 Embedded values

```swift
public struct BASBudgetUseDelta: Codable, Sendable, Hashable {
    public let tokenCount: UInt64
    public let byteCount: UInt64
    public let branchCount: UInt64
    public let remandRoundCount: UInt64
    public let hopCount: UInt64
    public let costMicrounits: UInt64
}

public struct BASBudgetCumulativeUse: Codable, Sendable, Hashable {
    public let tokenCount: UInt64
    public let byteCount: UInt64
    public let branchCount: UInt64
    public let remandRoundCount: UInt64
    public let hopCount: UInt64
    public let costMicrounits: UInt64
}
```

Both are embedded values, not independently registered payloads. All additions use checked arithmetic. Deadline is validated as an absolute monotonic time from the installed lease, not represented as an invented mutable time counter.

### 6.2 Request

```swift
public struct BASBudgetUseRequest: Codable, Sendable, Hashable {
    public let requestID: String
    public let turnOperationRef: BASTurnOperationRef
    public let budgetLeaseArtifactID: BASArtifactID
    public let controlLoopEnvelopeArtifactID: BASArtifactID
    public let invocationArtifactID: BASArtifactID
    public let parentInvocationArtifactID: BASArtifactID?
    public let priorBudgetUseReceiptArtifactID: BASArtifactID?
    public let ringID: BASControlRingID
    public let declaredEdge: BASCollaborationVerb?
    public let depth: UInt64
    public let candidateStateDecisionDigest: String
    public let progressWitnessArtifactID: BASArtifactID?
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let bootSessionID: String
    public let expectedLeaseRevision: UInt64
    public let delta: BASBudgetUseDelta
    public let observedMonotonicNanos: UInt64
    public let expectedSourceHead: BASEventLogHead
}
```

The root form requires all four child fields—parent invocation, prior use receipt, declared edge, and progress witness—to be nil. A child form requires all four nonnil. The envelope and invocation already exist before the request. K3 reopens both and requires their canonical root/ring/edge/depth/lease/Attempt/epoch/deadline facts to equal the request. No caller may restate a lease ceiling or remaining counter.

### 6.3 Receipt, outcome, and query

```swift
public struct BASBudgetUseReceipt:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let request: BASBudgetUseRequest
    public let priorCumulativeUse: BASBudgetCumulativeUse
    public let newCumulativeUse: BASBudgetCumulativeUse
    public let priorLeaseRevision: UInt64
    public let newLeaseRevision: UInt64
    public let resultingSourceHead: BASEventLogHead
}

public enum BASBudgetUseClaimOutcome: Sendable {
    case newlyWon(BASBudgetUseReceipt)
    case idempotentlyRecovered(BASBudgetUseReceipt)
    case terminated(BASControlLoopTerminalReceiptPayload)
}

public protocol BASBudgetLeaseControlPort: Sendable {
    func claimBudgetUse(
        _ request: BASBudgetUseRequest
    ) async throws -> BASBudgetUseClaimOutcome

    func budgetLeaseState(
        turnOperationRef: BASTurnOperationRef
    ) async throws -> BASBudgetLeaseState
}
```

The state projection is transient, atomic, unregistered, and non-authoritative outside the K3 lookup. It reports installed lease identity, revision, cumulative use, terminal row if any, and current source head; it never returns a mutable “remaining” value.

### 6.4 Transaction decision order

K3 applies one deterministic precedence before any spend:

1. malformed/current-schema/scope/reference failure;
2. idempotency conflict;
3. wrong root, lease, Attempt, generation, policy/deletion/boot epoch, deadline, or expected source head;
4. envelope/invocation/parent/edge/depth mismatch;
5. missing, foreign, or non-improving phase-specific progress witness;
6. repeated state/decision digest or cycle;
7. checked-add overflow or lease ceiling exhaustion;
8. accepted use.

Steps 3–7 create one typed K3 terminal row where the request is structurally attributable to the active loop; they spend zero budget and invoke zero semantic, Provider, tool, state, or release mechanism. Step 8 atomically advances cumulative counters, lease revision, visited digest, and EventLog source head. The same request ID always reconstructs the same branch of this decision.

Only a terminal payload whose pair is `converged + convergedVerified` and whose committed use receipt is present may become authoritative downstream input. Every other terminal outcome remains proposal/degraded/deferred/rejected/reconciliation evidence.

### 6.5 `BASControlLoopTerminalReceiptPayload` v2

V1 cannot honestly represent a zero-spend terminal rejection because `budgetUseReceiptArtifactID` is required. The minimal migration is:

- `currentSchemaVersion = "2.0.0"`;
- all existing fields and their order remain unchanged;
- only `budgetUseReceiptArtifactID` changes from `BASArtifactID` to `BASArtifactID?`.

Presence is decided by the historical K3 terminal row:

- a rejected zero-spend claim uses nil;
- a terminal decision after a committed use uses that exact nonnil receipt ID;
- `converged + convergedVerified` requires nonnil, and `isAdoptable` checks it;
- other state/reason pairs do not infer presence without the K3 `use_committed` fact.

Canonical v2 encoding omits the optional key for nil. Explicit JSON `null` is rejected by current decode followed by canonical re-encode equality. Historical v1 bytes and Artifact IDs are never rewritten. The typed v1 migration produces an in-memory v2 value with `.some(oldID)`; an optional new v2 ordinary put creates a new v2 Artifact and cannot masquerade as the v1 Artifact.

### 6.6 Owner-local typed migration seams

The existing `BASGovernedArtifactPayloadCodec.decodeCurrent` remains current-only. Its same owner adds exactly two type-specific paths—`decodeControlLoopTerminalReceiptMigratingV1` here and the exact-output-verification v1 path in Section 9.8—rather than a second codec or a generic migration framework:

1. Artifact Mesh first reopens and verifies the original record, Artifact ID, identity core, canonicalization version, schema/kind, scope, bytes, and length;
2. v2 bytes go through ordinary `decodeCurrent`;
3. v1 bytes are bounded-decoded with one private frozen v1 wire struct, canonical-reencoded, and required byte-identical before projection to v2 with `.some(oldBudgetUseReceiptArtifactID)`;
4. a missing version, malformed v1, noncanonical v1, explicit-null v2, or any future version fails;
5. migration returns only an in-memory semantic value and never relabels, rewrites, or stores over the v1 Artifact.

These two frozen paths are the only backward-read exceptions introduced by this addendum. New K3 commands and caller-authored ordinary puts remain current-version only; deterministic K3 receipt rematerialization instead uses its schema-pinned row and historical-put seam.

## 7. Provider Policy and Binding

### 7.1 Policy values

```swift
public struct BASProviderCausalReceiptRequirement:
    Codable, Sendable, Hashable
{
    public let receiptSchemaID: String
    public let receiptSchemaVersion: String
    public let exactCount: UInt64
}

public struct BASProviderBranchStepRule: Codable, Sendable, Hashable {
    public let stepRuleID: String
    public let purpose: BASProviderStepPurpose
    public let allowedOutputRoles: [BASProviderOutputRole]
    public let maximumInstances: UInt64
    public let orderedCausalReceiptRequirements:
        [BASProviderCausalReceiptRequirement]
    public let answerOnly: Bool
    public let mayRunAfterTerminalPin: Bool
}

public struct BASProviderBranchPolicy:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let orderedStepRules: [BASProviderBranchStepRule]
    public let totalMaximumBranchCount: UInt64
    public let visibilityMode: BASProviderVisibilityMode
    public let maximumPreauthorizedVerifierBranches: UInt64
}
```

The policy has exactly one answer rule. That rule is `.turnStep`, allows only `.terminalAnswerCandidate`, has `answerOnly == true`, has `maximumInstances == 1`, cannot run after the terminal pin, and exposes no tool/effect/capability/continuation schema. Grounding and verifier rules are internal-proposal only. A post-pin rule is legal only for `.verifierProposal/.internalProposal`, only in `bufferedUntilVerified`, and only within the frozen verifier ceiling. K3 cannot allocate such a branch until the pinned source has a completed terminal seal. Incremental mode requires `maximumPreauthorizedVerifierBranches == 0` and permits no post-pin Provider allocation.

Rule IDs, allowed roles, and causal requirements are canonical and unique. `allowedOutputRoles.count <= 2`. A causal requirement uses `1...64`; an empty requirement vector means no causal receipt. Every `maximumInstances`, `maximumPreauthorizedVerifierBranches`, and checked sum of rule instances is at most 64 and cannot exceed `totalMaximumBranchCount <= 64`. Policy rule count, total branch count, and all per-rule instance counts are bounded before allocation.

### 7.2 Binding

`BASSiliconExecutionBinding` contains only:

- `schemaVersion`;
- `providerBranchPolicyArtifactID`;
- a canonical one-to-one mapping, in policy order, from every `stepRuleID` to model/profile/plan-template/materialization/budget Artifact references.

It does not copy purpose, roles, count, causal, answer-only, post-pin, visibility, or trust-manifest facts. K3 atomically attaches one policy ID and one binding ID only after proving the binding references that exact policy and covers every rule exactly once. The same internal root-attachment transaction may additionally install one optional Provider-observation trust-manifest ID/epoch. That pair is both nil for local-only eligibility or both nonnil; it is not a binding field and grants no call authority. A half-installed pair, a second pair, a foreign policy, or a changed mapping fails before any production allocation. Isolated/remote boundary prepare fails until the trust pair and injected verifier are present.

Preflight/Pareto evaluation may consider multiple Provider/model candidates as value-only alternatives. Only the selected route is materialized and allocated. The answer rule still has exactly one K3 instance.

## 8. Model-Neutral Materialized Request

```swift
public struct BASMaterializedProviderRequestPayload:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let providerExecutionRef: BASProviderExecutionRef
    public let executionPlanArtifactID: BASArtifactID
    public let selectedProviderDescriptorArtifactID: BASArtifactID
    public let materializationContractArtifactID: BASArtifactID
    public let requestBytes: Data
}
```

This type lives in `BASRuntimeCore/BASLowEntropyPrimitives.swift` under the existing `provider.package-boundary` owner. It does not contain `BASOrganRequest`, destination, digest, self ID, signature, mutable handle, callback, or transport credential. BASOrgan/external Provider packages deterministically materialize their evolving request values according to the plan-bound materialization contract.

Construction requires a sequence-zero execution ref, three canonical Artifact IDs, and nonempty bounded bytes. The caller ordinary-puts, reopens, current-decodes, canonical-reencodes, and byte-compares the payload before claim. Every containment mode invokes the Provider only from reopened `requestBytes`; the live request object is never a second call input.

Its schema factory fixes the outer Artifact parent order to `[allocation receipt, execution plan, selected Provider descriptor, materialization contract]`, derives the Attempt scope from the sequence-zero execution ref, requires the allocation outcome's execution ref to equal the payload execution ref, and permits no caller-selected identity-core field.

For a terminal-answer candidate, the source pin freezes this exact materialized-request Artifact ID. This prevents a gate-then-substitute attack. The terminal claim must equal the pin. For an internal branch, claim is the first K3 binding of the materialized request.

The core equality is:

```text
ClaimRequest.materializedProviderRequestArtifactID
    == TerminalSourceRequest.materializedProviderRequestArtifactID  // terminal only
    == BASProviderEgressBoundaryPermit.payloadArtifactID            // isolated/remote
    == BASProviderObservedReceipt.materializedRequestArtifactID      // isolated/remote
```

## 9. Provider Commands and Receipts

### 9.1 Port surface

```swift
public protocol BASProviderBranchControlPort: Sendable {
    func allocateProviderBranch(
        _ request: BASProviderBranchAllocationRequest
    ) async throws -> BASProviderBranchAllocationReceipt

    func claimProviderExecution(
        _ request: BASProviderExecutionClaimRequest
    ) async throws -> BASProviderExecutionClaimOutcome

    func sealProviderEventHead(
        _ request: BASProviderEventHeadSealRequest
    ) async throws -> BASProviderEventHeadSealReceipt

    func designateTerminalSource(
        _ request: BASProviderTerminalSourceRequest
    ) async throws -> BASProviderTerminalSourceReceipt

    func openProviderVisibilityGate(
        _ request: BASProviderVisibilityRequest
    ) async throws -> BASProviderVisibilityReceipt

    func providerBranchState(
        turnOperationRef: BASTurnOperationRef,
        branchRef: BASTurnBranchRef
    ) async throws -> BASProviderBranchState
}
```

This replaces the obsolete copyable claim-return signature. The six-method count is unchanged; only claim returns the transient fresh/recovered outcome required for honest call authority.

### 9.2 Exact five-receipt wire envelope

All five governed Provider K3 receipts have exactly four outer `CodingKeys`, in this semantic order and with no additional key:

```text
schemaVersion
request
outcome
resultingSourceHead
```

The request and outcome are embedded, unregistered values. Each receipt is current schema `1.0.0`. The exact outcome shapes are:

```swift
public struct BASProviderBranchAllocationReceiptOutcome:
    Codable, Sendable, Hashable
{
    public let providerExecutionRef: BASProviderExecutionRef
    public let allocationRevision: UInt64
}

public struct BASProviderTerminalSourceReceiptOutcome:
    Codable, Sendable, Hashable
{
    public let pinRevision: UInt64
}

public struct BASProviderExecutionClaimReceiptOutcome:
    Codable, Sendable, Hashable
{
    public let claimRevision: UInt64
}

public struct BASProviderEventHeadSealReceiptOutcome:
    Codable, Sendable, Hashable
{
    public let sealRevision: UInt64
}

public struct BASProviderVisibilityReceiptOutcome:
    Codable, Sendable, Hashable
{
    public let visibilityRevision: UInt64
}
```

The branch is derived only from `providerExecutionRef.providerEgressBranchRef`; it is not copied beside the execution ref. Revisions are positive, root-local, monotonic K3 facts. No outcome copies a request, root, policy, binding, descriptor, plan, materialized request, evidence vector, state enum, self ID, future ID, SQL locator, or current head. Fixed canonical-byte fixtures and historical-row reconstruction pin all five envelopes.

### 9.3 Allocation request

The allocation request contains:

- request ID and expected source head;
- turn root and active Attempt/generation/policy/deletion/boot/deadline bindings;
- exact installed policy and binding Artifact IDs;
- one `stepRuleID` and requested output role;
- execution-plan and selected governed descriptor-parent Artifact IDs;
- exact ordered causal receipt Artifact IDs;
- installed lease and the exact budget-use receipt that authorized this branch delta.

It contains no ordinal, branch ref, purpose, policy limit, model/provider ID, containment class, visibility mode, provider-execution ID, acceptance generation, retry number, or fallback list.

K3 derives the next never-reused ordinal, branch ref, policy purpose, accepted role, installed lease, active acceptance generation, and one canonical 32-byte/lowercase-hex Provider execution correlation value. It returns only K3-new facts:

```swift
public struct BASProviderBranchAllocationReceipt: ... {
    public let schemaVersion: String
    public let request: BASProviderBranchAllocationRequest
    public let outcome: BASProviderBranchAllocationReceiptOutcome
    public let resultingSourceHead: BASEventLogHead
}
```

### 9.4 Terminal-source request

```text
BASProviderTerminalSourceRequest = {
  requestID,
  allocationReceiptArtifactID,
  materializedProviderRequestArtifactID,
  expectedSourceHead
}
```

The referenced allocation must be the unique answer-only terminal candidate, still unclaimed, and the current K3 allocation frontier. Every lower ordinal must already be terminal-resolved. K3 pins one source and the exact materialized-request ID before claim. It never pins a preflight candidate or raw branch supplied by a caller.

The receipt uses the exact four-key envelope and `BASProviderTerminalSourceReceiptOutcome`. Its Artifact ID is materialized through the row-pinned historical-put seam and reopened before the terminal claim.

### 9.5 Claim request and fresh permit

```text
BASProviderExecutionClaimRequest = {
  requestID,
  allocationReceiptArtifactID,
  materializedProviderRequestArtifactID,
  terminalSourceReceiptArtifactID?,
  expectedSourceHead
}
```

The terminal-source receipt is required exactly for the terminal-answer branch and nil for an internal branch. Claim request/receipt categorically contain no visibility-receipt Artifact ID. In incremental mode K3 checks its own root visibility row directly and allows exactly one post-gate exception: the already allocated, pinned, still-unclaimed exact source may claim once with the pinned materialized request. The gate forbids every new claim transition, new allocation, sibling claim, and source replacement. Exact replay of the already committed canonical claim still returns `.idempotentlyRecovered` with the same receipt and no permit; changed replay fails.

```swift
public struct BASProviderFreshCallPermit: ~Copyable, Sendable {
    fileprivate init(/* K3 claim binding */) { /* same file only */ }
}

public enum BASProviderExecutionClaimOutcome: ~Copyable, Sendable {
    case newlyWon(
        receipt: BASProviderExecutionClaimReceipt,
        permit: BASProviderFreshCallPermit
    )
    case idempotentlyRecovered(
        receipt: BASProviderExecutionClaimReceipt
    )
}
```

The permit has exactly one `fileprivate` initializer in the production claim implementation's file. It is noncopyable, non-Codable, non-Hashable, non-Equatable, nonpersistable, and nonrecoverable. Production source may not retain it in a property, collection, continuation, cache, or actor state; it exists only on the fresh call stack/task until consumed. It binds the exact root, branch, sequence-zero execution ref, materialized request, claim revision, deadline, owner epoch, and boot session. A receipt, SQL row, query, reconstructed handle, or exact replay can never recreate it.

Only:

```swift
func executeAtMostOnce(
    _ permit: consuming BASProviderFreshCallPermit,
    /* reopened request + local invoke closure */
) async throws -> BASProviderAttemptResult

func dispatch(_ outcome: consuming BASProviderExecutionClaimOutcome) async throws {
    switch consume outcome {
    case .newlyWon(_, let permit):
        _ = try await executeAtMostOnce(permit)
    case .idempotentlyRecovered:
        return
    }
}
```

is the only local physical invocation seam. The recovered case has no callable path.

W5 prepare/anchor/arm is pre-claim and uses one transient, unregistered, bounded command:

```swift
package struct BASK3ProviderEgressPrepareRequest:
    Codable, Sendable, Hashable
{
    package let requestID: String
    package let providerEgressBoundaryPermitArtifactID: BASArtifactID
    package let allocationReceiptArtifactID: BASArtifactID
    package let materializedProviderRequestArtifactID: BASArtifactID
    package let terminalSourceReceiptArtifactID: BASArtifactID?
    package let expectedSourceHead: BASEventLogHead
}
```

K3 reopens the governed boundary permit and requires `permit.payloadArtifactID == materializedProviderRequestArtifactID`, exact allocation/root/branch/Attempt/generation/epoch equality, terminal-source presence exactly for the answer branch, and `claim == nil`. It derives the sequence-zero execution ref from the allocation row. Prepare, K4 anchor, and K3 arm are idempotent state transitions on that tuple and cannot reference a claim row or claim-receipt Artifact. The arm is dormant and non-callable.

After the fresh K3 claim, the package-only seam is exact:

```swift
package struct BASProviderFreshRemoteCallPermit: ~Copyable, Sendable {
    fileprivate init(/* joined claim + arm binding */) {}
}

package func beginProviderEgressHandoff(
    _ claimPermit: consuming BASProviderFreshCallPermit,
    boundaryArmReceiptArtifactID: BASArtifactID
) async throws -> BASProviderFreshRemoteCallPermit
```

It equality-checks the committed claim row against the pre-armed tuple and performs the sole `armed → sent_or_unknown` CAS. Only the fresh winner returns the combined noncopyable, nonpersistable remote-call permit; the executor immediately consumes it at the remote `executeAtMostOnce` overload. A lost/recovered handoff result is non-callable. Thus remote invocation proves both authorities without a seventh public K3 method, while the claim-receipt Artifact may still be materialized through the row-pinned historical-put seam after the physical call and before seal.

### 9.6 Seal request

The seal request contains:

- request ID, claim-receipt Artifact ID, expected source head;
- accepted Provider event ref and event-head digest;
- typed seal kind: checkpoint or terminal state;
- `proposalArtifactID: BASArtifactID?`;
- exactly the paired optional `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID`.

It never contains `proposalReceiptArtifactID`, a chain ID, a spool ID, or an attestation Artifact ID. The generic observation attestation is discovered by target lookup.

Presence is exact:

| Seal | Proposal | Arm/observation pair | Lineage eligible |
|---|---:|---:|---:|
| checkpoint | nil | nil/nil for every containment | no |
| terminal completed | nonnil | local nil/nil; isolated/remote nonnil/nonnil | yes |
| terminal failed | nil | local nil/nil; isolated/remote nonnil/nonnil | no |
| terminal cancelled | nil | local nil/nil; isolated/remote nonnil/nonnil | no |
| terminal indeterminate | nil | local nil/nil; isolated/remote nonnil/nonnil when authenticated, otherwise no remote seal | no |

Half-pairs fail. A checkpoint never consumes W5 terminal evidence and never advances the handoff row. For isolated/remote terminal sealing, the observed terminal state must equal the requested terminal state; completed additionally requires `request.proposalArtifactID == observed.terminalProposalArtifactID`, while every non-completed state requires both proposal IDs nil. `sent_or_unknown` without an authenticated observation remains unsealed and cannot enter any chain. K3 stores the checkpoint/terminal outcome plus historical event head and source head; the receipt is again only `{ schemaVersion, request, K3 outcome, resultingSourceHead }`.

Local completed sealing intentionally relies on the trusted SDK-host boundary rather than fabricating remote attestation. BASHostKit injects the K3 object only into the Runtime/Silicon executor path; BASOrgan adapters, Provider code, plugins, models, and application callbacks receive neither the concrete object nor the branch-control existential. The sole production local-completed seal call site is downstream of the consuming `executeAtMostOnce` result in `BASProviderAttemptExecutor`; source/link gates reject any second call site. This is an explicit threat-model assumption, not a cryptographic proof. Checkpoint and non-completed administrative sealing remain separately callable by trusted runtime code under their exact state rules.

### 9.7 Visibility request

Visibility evidence is typed rather than a free mixed vector:

```text
incrementalVerified {
  terminalSourceReceiptArtifactID,
  preCallVerificationPolicyReceiptArtifactID
}

bufferedUntilVerified {
  terminalSourceReceiptArtifactID,
  terminalEventHeadSealReceiptArtifactID,
  orderedVerifierProposalReceiptArtifactIDs,
  exactOutputVerificationArtifactID
}
```

The installed policy chooses the case. The request cannot change it. Incremental logical visibility is a zero-byte authorization and occurs before claim. Buffered logical visibility occurs only after the exact spool, verifier suffix, and L10 verification exist. Physical UI/network bytes still require the independent stream/publication K3→K4→K3 boundary fence.

The successful root visibility row closes all future allocation. It closes all future claim except the unique incremental exact-source first claim described above.

### 9.8 Exact-output verification closure

The retained W5 `BASExactOutputVerificationPayload` becomes v2 so incremental evidence is actually reachable without flattening every chunk:

```swift
public struct BASExactOutputVerificationPayload:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "2.0.0"
    public let schemaVersion: String
    public let spoolArtifactID: BASArtifactID
    public let verifierContractArtifactID: BASArtifactID
    public let constraintArtifactID: BASArtifactID
    public let passed: Bool
    public let orderedProvisionalDisplayReceiptArtifactIDs: [BASArtifactID]?
}
```

Every buffered visibility use and every through-chain use requires `passed == true`, exact spool/source/prefix equality, and a current verifier contract/constraint. Incremental Vrow is pre-call and therefore does not depend on E; its later through-chain does. Incremental E requires a nonnil canonical array of 0...256 display-receipt IDs. Each display receipt reopens its exact stream-batch permit, and each permit reopens 1...64 ordered chunk-verification receipts. Every nested receipt/permit must match Y's root, source branch, T, V, verifier contract, and constraint. Across all displays the chunk ranges and chain digests are contiguous, nonoverlapping, and start at byte zero; every verification is positive. Their final range derives `provisionallyDisplayedByteCount <= spool.presentationBytes.count`, and the ordered concatenation of verified `chunkBytes` must be byte-identical to `spool.presentationBytes.prefix(provisionallyDisplayedByteCount)`, not merely length- or self-digest-equal. An empty array means exactly zero provisional bytes and is legal even for a nonempty final spool; E still verifies the entire spool for later final release. Checked multiplication caps the transitive chunk total at `256 × 64 = 16,384` without copying those IDs into E or the Provider chain.

Buffered mode requires the optional field nil, encoded by omitting the key; explicit JSON null is noncanonical. E is created before buffered visibility and must not acquire an E→visibility back-edge. The codec owner's type-specific `decodeExactOutputVerificationMigratingV1` validates a frozen v1 wire struct by bounded decode plus canonical re-encode equality, then projects only to the v2 nil form. That form is valid only under buffered policy; incremental v1 is insufficient and fails closed. Historical v1 bytes/Artifact IDs are never rewritten. The registry object count is unchanged. The arrows `E → display receipt → stream permit → chunk receipt → visibility receipt` describe reverse reference traversal; creation order is visibility receipt, chunks/permits/displays, then E.

## 10. Provider Runtime State Without a Giant Reducer

Durable ownership remains split by fact:

- K3 branch row: allocation, possible-start claim, checkpoint and terminal seals;
- K3 root row: unique terminal source and logical visibility authorization;
- K2 TurnOperation actor: transient unsealed event tail;
- Silicon task: fresh in-flight permit and result observation;
- W5 boundary row: prepared/pending/armed/sent-or-unknown/terminal-or-indeterminate transport state.

The public queries are transient projections:

```swift
public struct BASProviderRootState: Sendable {
    public let installedProviderBranchPolicyArtifactID: BASArtifactID
    public let installedExecutionBindingArtifactID: BASArtifactID
    public let terminalSource: BASProviderTerminalSourceReceipt?
    public let visibilityAuthorization: BASProviderVisibilityReceipt?
}

public struct BASProviderBranchState: Sendable {
    public let allocation: BASProviderBranchAllocationReceipt
    public let claim: BASProviderExecutionClaimReceipt?
    public let latestEventHeadSeal: BASProviderEventHeadSealReceipt?
    public let root: BASProviderRootState
    public let currentSourceHead: BASEventLogHead
}
```

They are not Codable, schema-versioned, registered, persisted, or independently cached. One atomic K3 read constructs them. A branch cannot exist before the policy/binding pair is atomically installed, so both IDs in this branch-root projection are nonoptional and immutable; pre-allocation root admission uses its existing internal path. External validators consume only this narrow projection through `providerBranchState`, never the concrete K3 object.

A claim row means `possibleStarted`, never proof that the Provider executed. Incremental mode has one legal intermediate root state: source pinned, visibility authorized, claim nil, and zero visible bytes. Only that exact source may perform its first claim. Buffered visibility requires the completed source seal, the complete verifier suffix, exact-output verification, and L10 closure.

## 11. Exact Invocation Order

All fallible prerequisites that do not consume the Provider claim—candidate preflight, Pareto selection, plan, descriptor, materialization contract, budget authorization, and for isolated/remote the dormant W5 fence—finish before the fresh claim. The W5 fence is stateful but non-callable: ordinary-put/reopen the egress permit, K3 prepare, K4 anchor and put/reopen its receipt, then K3 arm and put/reopen its receipt. It grants no call authority until the fresh claim permit is consumed by the post-claim `beginProviderEgressHandoff` CAS.

The notation below distinguishes durable state from Artifact IDs:

- A = allocation-receipt Artifact;
- M = materialized-request Artifact;
- T = terminal-source-receipt Artifact;
- Q = K3 claim row plus fresh noncopyable permit, never an Artifact;
- C = claim-receipt Artifact reconstructed from Q;
- P = governed proposal Artifact;
- O/At = observed-receipt/selected-attestation Artifacts for isolated/remote;
- Srow/S = K3 terminal-seal row / seal-receipt Artifact;
- R = generic proposal-receipt Artifact;
- Vrow/V = K3 visibility row / visibility-receipt Artifact;
- X/E/Y = terminal-prefix chain / exact-output verification / through-visibility chain.

### 11.1 Internal branch

```text
allocate → put/reopen A → put/reopen M
→ [isolated/remote: put/reopen permit → prepare → anchor/receipt
   → arm/receipt]
→ fresh Q
→ immediate local executeAtMostOnce
   OR beginProviderEgressHandoff(Q, arm) → immediate remote executeAtMostOnce
→ put/reopen P and terminal result
→ [isolated/remote: put/reopen O → put/reopen signed At]
→ reconstruct/put/reopen C
→ K3 terminal Srow → reconstruct/put/reopen S
→ put/reopen R
→ completed lineage entry
```

This is the completed path. Failed, cancelled, or indeterminate terminal paths omit P/R and never create a lineage entry.

### 11.2 Incremental terminal source

```text
allocate → put/reopen A → put/reopen M
→ pre-claim terminal pin → put/reopen T
→ [isolated/remote: put/reopen permit → prepare → anchor/receipt
   → arm/receipt]
→ zero-byte incremental Vrow
→ fresh Q immediately, with no Artifact put or mechanism between Vrow and Q
→ immediate local invoke OR begin-handoff(Q, arm) + immediate remote invoke
→ reconstruct/put/reopen V before any stream permit or visible byte
→ bounded verified provisional stream
→ put/reopen P and terminal result
→ [isolated/remote: put/reopen O → put/reopen signed At]
→ reconstruct/put/reopen C
→ K3 terminal Srow → reconstruct/put/reopen S → put/reopen R
→ X → spool → passed E v2 with exact incremental coverage
→ Y using exact E and V
```

The V Artifact put is deliberately after Q so no Artifact mechanism sits between Vrow and claim, but it must complete before the first stream boundary permit or physical visibility. Claim reads Vrow, not a caller-provided V Artifact ID.

### 11.3 Buffered terminal source

```text
allocate → put/reopen A → put/reopen M
→ pre-claim terminal pin → put/reopen T
→ [isolated/remote: put/reopen permit → prepare → anchor/receipt
   → arm/receipt]
→ fresh Q → immediate local invoke OR begin-handoff(Q, arm) + remote invoke
→ put/reopen P and terminal result
→ [isolated/remote: put/reopen O → put/reopen signed At]
→ reconstruct/put/reopen C
→ K3 terminal Srow → reconstruct/put/reopen S → put/reopen R
→ X → spool
→ allocate/complete every policy-authorized post-pin verifier branch through R
→ passed E v2/L10 with incremental coverage field nil
→ prove every post-pin ordinal terminal-resolved
→ buffered Vrow → reconstruct/put/reopen V
→ Y using exact E and V
```

After a claim, there is no route fallback, model fallback, sibling replacement, or same-root retry. A changed route requires a newly authorized Attempt.

## 12. Provider Observation and Attestation

```swift
public enum BASProviderObservedTerminalState:
    String, Codable, Sendable, Hashable
{
    case completed, failed, cancelled, indeterminate
}

public enum BASProviderObservationOrigin:
    String, Codable, Sendable, Hashable
{
    case immediateReturn
    case authenticatedQueryRecovery
}

public struct BASProviderObservedReceipt:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let providerExecutionRef: BASProviderExecutionRef
    public let selectedProviderDescriptorArtifactID: BASArtifactID
    public let materializedRequestArtifactID: BASArtifactID
    public let acceptedTerminalEventRef: BASProviderExecutionRef
    public let acceptedTerminalEventHeadDigest: String
    public let observationOrigin: BASProviderObservationOrigin
    public let observationBootSessionID: String
    public let observationStartedAtMonotonicNanos: UInt64
    public let observationEndedAtMonotonicNanos: UInt64
    public let cancellationObserved: Bool
    public let observedByteCount: UInt64
    public let observedTokenCount: UInt64
    public let terminalProposalArtifactID: BASArtifactID?
    public let terminalResultArtifactID: BASArtifactID?
    public let terminalState: BASProviderObservedTerminalState
}
```

The untyped `echoedProviderReceipt: String?` is removed. Provider-native receipts belong inside a governed terminal-result Artifact and never promote themselves.

Validation requires sequence-zero base equality, a positive terminal event sequence, equality of all six stable fields, a 64-character lowercase hexadecimal head digest, bounded counts, a bounded boot ID, and an ordered observation interval wholly measured in `observationBootSessionID`. The interval measures the supervisor observation window, not claimed remote execution duration.

`immediateReturn` requires the observation boot to equal the original arm/claim boot. `authenticatedQueryRecovery` may use a later boot, but its attestation must bind that recovery boot and the original execution/arm tuple. K3 reopens the historical `sent_or_unknown` row, proves that no terminal seal already won, revalidates current Attempt/generation/policy/deletion/owner/trust epochs, and performs only the terminal seal transition. It does not rewrite the historical arm boot, mint a permit, resend, or resume generation.

Terminal-state presence is exact:

- completed: proposal and terminal result are both nonnil; cancellation is false;
- failed: both are nil; cancellation is false;
- cancelled: both are nil; cancellation is true;
- indeterminate: both are nil; cancellation may record whether cancellation was also observed.

For isolated/remote execution, the supervisor ordinary-puts the observed receipt and then uses the existing generic `BASArtifactAttestationPayload` path. Before isolated/remote boundary prepare, K3 must already have the exact trust-manifest Artifact ID and manifest epoch attached to the root; boundary prepare/arm copies that binding only into its private row. A half-installed or changed binding makes the route ineligible.

The existing generic Artifact Store target lookup gains a bounded, purpose-aware overload on the same owner/store, not a Provider-specific index:

```swift
func attestationArtifactIDs(
    targeting targetArtifactID: BASArtifactID,
    purpose: String,
    maximumCount: Int
) async throws -> (
    artifactIDs: [BASArtifactID],
    exceededMaximum: Bool
)
```

Before touching SQLite, the API validates purpose as the exact canonical 1...128-byte UTF-8/no-NUL identifier used by the attestation payload and rejects `maximumCount` outside `1...8`. It uses checked addition to derive `maximumCount + 1` and converts only that bounded value to the SQL limit type. SQLite then filters by exact target and purpose, orders by canonical Artifact-ID storage scalar, executes the bounded limit, and returns at most the first `maximumCount` IDs plus the overflow bit. K3 asks for eight. Overflow, zero fully valid candidates, or more than one fully valid candidate fails closed; other-purpose children neither authorize nor consume this purpose-specific bound.

This overload requires an explicit Artifact Mesh database migration; it cannot be implemented as an unbounded fetch followed by in-memory purpose filtering. `BASArtifactSQLiteStore.schemaVersion` advances from 1 to exactly 2. The v2 `artifact_mesh_attestation_targets` projection has nonnull `attestation_artifact_id`, `target_artifact_id`, and canonical `attestation_purpose` columns, with the purpose constrained to 1...128 UTF-8 bytes and no NUL; it preserves the attestation primary key and both record foreign keys, removes the old two-column target index, and installs one covering index in this exact order:

```text
(target_artifact_id, attestation_purpose, attestation_artifact_id)
```

Opening a v1 database performs one `BEGIN IMMEDIATE` shadow-table migration owned solely by `BASArtifactSQLiteStore`: validate the exact v1 schema; scan existing projection rows in canonical attestation-ID order; reopen and cryptographically verify each referenced Artifact record; bounded-current-decode it as `BASArtifactAttestationPayload`; require its target to equal the projected target and its purpose to be canonical; insert the verified target, purpose, and attestation ID into the v2 shadow table; reject any missing, malformed, duplicate, noncanonical, or inconsistent row; replace the v1 table and index; validate the exact v2 schema and all row counts; set `PRAGMA user_version=2`; then commit. Any failure rolls back and leaves v1 untouched. Fresh databases create v2 directly; version 0 with application tables, versions above 2, and partial v1/v2 shapes fail closed.

Every new ordinary attestation put derives target and purpose from the already verified payload and inserts all three projection values in the same Artifact-store transaction; callers cannot supply the indexed purpose. The purpose-aware lookup binds target and purpose in SQL before ordering and the checked limit, then reopens every returned Artifact and rechecks its canonical payload target and purpose. The legacy target-only API is deprecated, never used by authorization, and is made bounded in the same change: it performs `LIMIT 9`, returns at most eight children, and throws a typed overflow error on the ninth. No production target lookup retains all matching rows in memory.

The embedded `BASSovereignSignatureStatement` advances to v2 and signs the complete authorization tuple, not merely the target: exact Attempt scope, target ID, attestation purpose, producer arm-receipt ID, bounded ordered usage-receipt IDs, policy epoch, logical time, proof suite, key role/ID/epoch, custody class, trust-manifest ID/epoch, recovery boot/owner context when present, and the canonical digest of the outer attestation projection excluding both `proofBytes` and the self-referential `signedStatementDigest`. The existing trust-manifest entry gains the exact key role and allowed purpose set. The verifier requires every signed field to equal the outer generic attestation and installed K3 binding; rewrapping the same proof under another purpose/context therefore fails.

K3 requires exactly one fully validating candidate:

- purpose `provider-supervisor-observation-v1`;
- identical Attempt scope and policy epoch;
- target equal to the observed-receipt Artifact ID;
- `producerReceiptArtifactID` equal to the exact boundary-arm receipt;
- `usageReceiptArtifactIDs` equal to the installed purpose-specific ordered authorization context; query recovery additionally binds the current recovery-boot/owner authorization selected by the trust manifest;
- expected proof suite, key role/ID/epoch, custody class, statement digest, proof bytes, and the exact installed, nonrevoked trust-manifest entry.

A RuntimeCore-defined injected verifier returns one transient typed result containing attestation ID, manifest ID/epoch, key role/ID/epoch, purpose, and signed-context digest. K3 verifies outside SQL, then the transaction rechecks the immutable target, installed K3 trust/policy epochs, arm/handoff rows, and source head. The seal row persists the selected attestation ID, manifest ID/epoch, and verifier result needed for historical validation. The public seal request/receipt body and five-ID lineage still contain no attestation or manifest field; the receipt factory appends the K3-selected pair only to its outer identity-core parents.

Historical evidence validation or present adoption opens the row-selected attestation and manifest directly; it never reruns a current-child election, so a later child cannot change evidence selection. This is not exact idempotent command replay. An exact seal-command replay reads only its K3 historical row, compares canonical request bytes, and returns the stored receipt body without opening the attestation, manifest, proposal, or any current Artifact/trust state. A later trust revocation or unavailable evidence may deny present adoption/publication but cannot rewrite the historical seal or its replay. Only a concurrently changed K3-installed trust/policy epoch is claimed to abort the original SQL seal; this contract does not pretend an unpropagated external K4 revocation is atomically visible inside the K3 transaction.

Only a fresh armed→`sent_or_unknown` handoff winner may send. Crash after that CAS, lost reply, or unqueryable result produces zero resend. An authenticated query may recover the same operation and submit the same canonical observation to the seal CAS; it never obtains a fresh call permit. Identical committed-seal replay is idempotent, while changed observation evidence is corruption.

## 13. Generic Provider Proposal Receipt

The five-ID lineage needs one model-neutral, governed proposal receipt for every purpose. Grounding, turn, and verifier branches cannot substitute different lineage receipt schemas.

```swift
public struct BASProviderProposalReceipt:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let providerExecutionRef: BASProviderExecutionRef
    public let materializedRequestArtifactID: BASArtifactID
    public let proposalArtifactID: BASArtifactID
    public let eventHeadSealReceiptArtifactID: BASArtifactID
}
```

It is created only after a completed K3 seal receipt exists. The execution ref is its sole root/branch projection. It contains no claim ID, policy, source head, visibility, self ID, signature, chain ID, or future ID. Its Artifact parents are in the fixed order `[materialized request, proposal, seal receipt]`.

Validation reopens the materialized request and seal, reconstructs the historical allocation/claim/seal rows, and requires one sequence-zero execution ref, materialized request, proposal, and completed seal. The proposal Artifact itself must be a governed payload whose schema/version equals the output schema frozen by the selected execution plan. A specialized `BASGroundingProposalReceipt`, if retained as a semantic projection, must reference this generic receipt and cannot occupy the lineage field or copy K3 authority.

## 14. Five-ID Lineage and Chain Cuts

### 14.1 Entry

```swift
public struct BASProviderBranchLineageEntry:
    Codable, Sendable, Hashable
{
    public let allocationReceiptArtifactID: BASArtifactID
    public let claimReceiptArtifactID: BASArtifactID
    public let eventHeadSealReceiptArtifactID: BASArtifactID
    public let proposalArtifactID: BASArtifactID
    public let proposalReceiptArtifactID: BASArtifactID
}
```

The removed branch, rule, execution-ref, plan, and causal fields are derived by reopening the receipt chain. They do not remain as duplicated audit authority. A transient expanded debug view may project them after full validation.

Every entry validation must:

1. reopen all five IDs from the same Artifact store with current schemas, correct kinds/scopes, canonical bytes, and distinct identities;
2. reconstruct the historical allocation, claim, and seal receipt bodies byte-for-byte from K3 rows;
3. traverse claim → allocation and require one root, branch, policy, binding, rule, plan, descriptor, causes, sequence-zero execution ref, and materialized request;
4. require seal → claim and `seal.request.proposalArtifactID == entry.proposalArtifactID != nil`;
5. require a completed seal, never a checkpoint/failure/cancel/indeterminate seal;
6. require the generic proposal receipt to close the same execution/materialized/proposal/seal tuple;
7. validate local nil/nil boundary evidence or isolated/remote arm→observation→attestation evidence solely through the seal-receipt Artifact plus its historical K3 row/identity parents;
8. reject all current/future causal back-edges.

For one entry, let A/C/S/P/R denote its five IDs and M denote `C.request.materializedProviderRequestArtifactID`. The validator requires these exact equalities:

```text
C.request.allocationReceiptArtifactID == A
S.request.claimReceiptArtifactID == C
S.request.proposalArtifactID == P

R.providerExecutionRef
    == A.outcome.providerExecutionRef
    == reopen(M).providerExecutionRef
R.materializedRequestArtifactID == M
R.proposalArtifactID == P
R.eventHeadSealReceiptArtifactID == S
```

Artifact IDs include the commitment-key epoch, so `proposalArtifactID` alone is not a sufficient uniqueness key. On seal, K3 reopens P, obtains `identityBytes = BASArtifactMesh.canonicalIdentityBytes(for: P.identityCore)`, and computes `proposalIdentityAlias` as lowercase SHA-256 of `BASSovereignCanonicalBytes.lengthPrefixed(["bas-provider-proposal-identity-alias-v1", identityBytes.base64EncodedString()])`. The alias excludes P's Artifact-ID algorithm, key epoch, commitment, storage envelope, and payload locator. The caller cannot provide it. A completed seal requires P and its 64-hex alias both nonnil; every checkpoint or non-completed terminal seal requires both nil. The seal table has a partial unique index on `(turn_operation_ref, proposal_identity_alias) WHERE proposal_identity_alias IS NOT NULL`, while retaining P for exact lineage. Thus the same verified identity core reminted under a later commitment epoch cannot seal another branch. Chain validation recomputes every alias from the reopened P and requires the matching historical seal row. Across one chain, the union of every entry's A/C/S/P/R IDs still has exactly `orderedEntries.count × 5` members: no ID may repeat within or across entries.

### 14.2 Chain payload

```swift
public enum BASProviderBranchChainCut:
    String, Codable, Sendable, Hashable
{
    case terminalPrefix
    case throughVisibility
}

public struct BASProviderBranchChainPayload:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let cut: BASProviderBranchChainCut
    public let orderedEntries: [BASProviderBranchLineageEntry]
    public let terminalAnswerSourceBranchRef: BASTurnBranchRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let exactOutputVerificationArtifactID: BASArtifactID?
    public let providerVisibilityReceiptArtifactID: BASArtifactID?
}
```

Both cuts independently close their root authority; equality between a prefix and a through cut is never sufficient. For every entry, let A be its allocation receipt and let `rootAuthority` be the `BASProviderRootState` returned in the same atomic `providerBranchState` read for that chain/root. Validation requires:

```text
reopen(A).request.turnOperationRef == chain.turnOperationRef
reopen(A).request.providerBranchPolicyArtifactID
    == chain.providerBranchPolicyArtifactID
    == rootAuthority.installedProviderBranchPolicyArtifactID
reopen(A).request.executionBindingArtifactID
    == chain.executionBindingArtifactID
    == rootAuthority.installedExecutionBindingArtifactID
reopen(chain.executionBindingArtifactID).providerBranchPolicyArtifactID
    == chain.providerBranchPolicyArtifactID
```

The same equations must hold for every A in `orderedEntries`; a mixed-root entry, a foreign but mutually consistent policy/binding pair, or a prefix and through cut that agree with each other but not with the root-installed pair fails closed. The transient projection is constructed directly from the historical K3 root row and proves that the pair was atomically installed before the first allocation and was never replaced; validators never query a second store or concrete K3 implementation.

The generic `orderedVisibilityEvidenceArtifactIDs` field is removed. Mode-required opening evidence is already inside the nested visibility request. The one exact-output-verification Artifact closes terminal bytes in both modes. In incremental mode that L10 artifact reaches bounded provisional evidence hierarchically:

```text
exact-output verification
  → ordered provisional-display receipts
    → stream-batch permits
      → bounded ordered chunk-verification receipts
```

The chain never flattens every chunk into an unbounded evidence array.

### 14.3 Terminal prefix

`terminalPrefix` requires:

- both optional closing IDs nil;
- the pinned source entry is exactly `orderedEntries.last`;
- the entries are exactly all completed Provider branches whose ordinal is less than or equal to the pinned-source ordinal, in strict K3 ordinal order;
- every omitted ordinal in that closed range is proven by historical K3 rows to be failed, cancelled, or indeterminate;
- the source pin was accepted only at the allocation frontier and all lower ordinals were terminal-resolved;
- no higher post-pin verifier ordinal appears in the prefix;
- no visibility, spool, through-chain, release, arm, observation, or attestation ID is copied as a direct chain field, chain parent, or chain provenance edge. Remote arm/observation evidence remains transitively reachable through the entry's seal receipt; its selected attestation/trust snapshot is frozen in the K3 seal row and seal-receipt identity parents.

Only this cut may be referenced by `BASResponseSpoolPayload`.

### 14.4 Through visibility

`throughVisibility` requires both closing IDs nonnil. It has no direct terminal-prefix field or identity parent. A validator receives and reopens both chain Artifacts, independently applies the root-installed equations above to each cut, and then requires root, policy, binding, source branch, and source receipt equality plus byte-identical equality between the prefix's full entries and the through chain's leading slice.

- incremental: through entries equal prefix entries exactly; suffix is empty;
- buffered: through begins with the exact prefix and appends exactly every completed, policy-authorized post-pin `.verifierProposal/.internalProposal` branch before the visibility-close head, in K3 ordinal order, with no omission or extra entry. At gate time every allocated post-pin ordinal must be terminal-resolved; completed ordinals occur once in the suffix, failed/cancelled/indeterminate ordinals have historical proof, and any allocated-unclaimed, claimed-unsealed, or otherwise pending ordinal rejects the gate.

Let T/V/E be the chain's terminal-source, visibility, and exact-output-verification IDs, and `sourceEntry` be its source. T and V receipts must first reconstruct byte-for-byte from historical K3 rows. Validation then requires:

```text
T.request.allocationReceiptArtifactID == sourceEntry.A
T.request.materializedProviderRequestArtifactID
    == reopen(sourceEntry.C).request.materializedProviderRequestArtifactID
reopen(T.request.allocationReceiptArtifactID)
    .outcome.providerExecutionRef.providerEgressBranchRef
    == chain.terminalAnswerSourceBranchRef
    == sourceEntry.A.outcome.providerExecutionRef.providerEgressBranchRef

V.request.terminalSourceReceiptArtifactID == T
E.passed == true
E.spoolArtifactID → spool.terminalPrefixProviderBranchChainArtifactID
    == the side-by-side supplied terminalPrefix Artifact ID
spool source/ref/proposal == values derived from sourceEntry
```

Buffered additionally requires `V.request.terminalEventHeadSealReceiptArtifactID == sourceEntry.S`, `V.request.orderedVerifierProposalReceiptArtifactIDs == throughSuffix.map(\.R)`, and `V.request.exactOutputVerificationArtifactID == E`. Incremental requires exact E-v2 display/permit/chunk coverage and through entries exactly equal prefix entries. The E→spool→prefix path is a required transitive reference, not a forbidden direct through→prefix field. The release-evidence grouping holds both chain IDs side by side and the validator checks both the transitive exact ID and the leading-slice bytes.

## 15. Artifact DAG

The completed terminal path is acyclic. Arrows below mean creation/dependency order; Q, Vrow, handoff, and Srow are K3 rows/transient capabilities, while capital letters A/M/T/C/P/O/At/S/R/V/X/E/Y are Artifact IDs:

```text
policy / binding / plan / descriptor
    → allocation receipt A
    → materialized request M
    → terminal-source receipt T(A, M)

isolated/remote: A + M + optional T
    → egress permit → K3 prepare → K4 anchor → K3 arm

incremental: T + optional arm → visibility row Vrow → claim row/permit Q
buffered:    T + optional arm → claim row/permit Q

local:  Q → physical call
remote: Q + arm → handoff row → physical call

physical call → governed proposal P + terminal result
remote result → observed receipt O → signed attestation At
Q → claim receipt C                         // put after call, before seal
(C, P, optional arm/O/At/trust manifest) → terminal seal row Srow
Srow → seal receipt S
(M, P, S) → generic proposal receipt R
(A, C, S, P, R) → five-ID lineage entry

entries through source ordinal + T → terminalPrefix X
X → spool Sp

incremental:
    Vrow → visibility receipt V
    V → chunk verification → stream permits → display receipts
    (Sp, ordered display receipts) → passed E

buffered:
    X → complete verifier suffix
    (Sp, nil display coverage) → passed E
    E + complete terminal-resolved suffix → visibility row Vrow
    Vrow → visibility receipt V

(E, V, prefix entries, exact optional verifier suffix)
  → throughVisibility Y
  → release preparation
```

The seal never points at the future proposal receipt. C is never treated as pre-call authority; only Q is. Vrow is never confused with V. The spool never points at future visibility or through chain. The through chain has no direct prefix field/parent, although E must reach the exact prefix through its spool. Incremental E may depend on V; buffered E must not. Release preparation is created only after both cuts, spool, positive verification, and visibility exist.

## 16. Crash and Recovery Matrix

| Crash cut | Durable interpretation | Allowed recovery | Forbidden action |
|---|---|---|---|
| before allocation commit | no branch | retry same request | burn/caller-mint ordinal |
| allocation commit before reply/Artifact put | allocated | reconstruct same receipt, row-pinned historical-put | allocate replacement |
| materialized request put before pin/claim | orphan value | reuse only if exact route/ref still live | treat as claimed |
| remote K3 prepare commit before K4 anchor | pending non-callable fence | reconstruct same source commit and exact-resume anchor | change payload/branch or claim/send |
| K4 anchor commit before K3 arm | anchored non-callable fence | reopen same anchor and exact-resume arm while deadline is live | issue another anchor or send |
| isolated/remote arm commit before Artifact put, reply, or key rotation | dormant non-callable fence with row-pinned identity | reconstruct the same arm Artifact through the historical-put seam; exact bound branch may continue to its first fresh claim | active-epoch remint, send, synthesize claim, or re-arm another payload |
| dormant arm deadline expires before claim | no call and no claim transition | terminalize/reconcile the pinned root or begin a newly authorized Attempt | re-arm, fallback, or reuse capability |
| pin commit before reply | source and exact request frozen | reconstruct same pin receipt | pin sibling or replace request |
| incremental gate commit before claim | zero-byte gate open | exact pinned source may claim once | allocate/sibling claim/visible byte |
| claim commit before permit delivery | possible-start | query/reconcile only | recreate permit or call |
| local permit delivered before/during invoke | possible-start | join known live task if still in-process | reconstruct permit, blind reinvoke, fallback |
| remote handoff CAS before invoke | `sent_or_unknown` | query exact external operation only | recreate either permit or resend |
| incremental Q/invoke before V Artifact put | possible-start, zero visible bytes | reconstruct/put exact V from Vrow; join/query call only | display, new claim, or call again |
| Provider returned before proposal put | possible-start | query authenticated same operation | call again |
| proposal/result put before C put | completed call, claim row authoritative | reconstruct/put exact C from Q, then continue seal | call again or fabricate another C |
| proposal/observation/attestation put before seal | orphan evidence | exact seal retry | lineage/publication |
| seal commit before reply/receipt put or key rotation | historical terminal row with pinned key epoch | reconstruct same seal receipt/ID with historical key material | changed evidence or current-key remint |
| seal receipt before proposal receipt/chain | completed branch | deterministic wrapping only | Provider call |
| new matching attestation child after seal | later non-authoritative child | historical evidence validation uses the row-selected attestation/manifest; exact command replay uses only K3 bytes | rerun election or rewrite seal |
| prefix/spool before buffered visibility | hidden exact bytes | continue verifier/L10/gate | publish |
| remote `sent_or_unknown` with no query result | disclosure/call possible | quarantine/query/reconcile | resend, sibling replacement |

Cancellation does not free a claimed branch for fallback. A failed/indeterminate source cannot be replaced under the same root. A new user-visible attempt is a new Attempt/root with new authorization.

## 17. Hard Bounds

Decode and query bounds are fixed before allocation:

| Surface | Hard maximum |
|---|---:|
| governed payload canonical bytes | existing Artifact Mesh maximum, 16 MiB |
| materialized Provider `requestBytes` | 8 MiB and additionally bounded by plan/profile/lease |
| governed proposal or terminal-result canonical bytes | 16 MiB each, additionally bounded by plan/profile/lease |
| `observedByteCount` / `observedTokenCount` | 16 MiB / 262,144 |
| Provider policy rules | 64 |
| Provider branches / lineage entries | 64 branches; every chain has 1...64 entries |
| allowed output roles per rule | 2 |
| any rule instance/causal exact count/preauthorized verifier count | 64; checked aggregate also <= 64 |
| causal receipt IDs per branch | 64 |
| causal requirements per rule | 64 |
| buffered verifier receipt IDs | 64 |
| checkpoint seals per branch | 64 |
| unsealed Provider events between durable seals | 4,096 |
| total Provider event sequence per branch | 262,144 |
| `stepRuleID` | 128 UTF-8 bytes |
| request/provider-execution/boot identifiers | 256 UTF-8 bytes |
| Artifact-ID storage scalar | existing 4,096 UTF-8 bytes |
| EventLog head session/event ID/digest | 4,096 / 256 UTF-8 bytes / exactly 64 lowercase hex |
| matching observation attestation children inspected | 8 |
| attestation purpose | 128 UTF-8 bytes |
| attestation suite/key/custody identifiers | 256 UTF-8 bytes each |
| proposal identity alias | exactly 64 lowercase hexadecimal bytes |
| attestation usage receipt IDs | 64 |
| generic attestation proof bytes | 4,096; Ed25519 exactly 64 |
| provisional display receipts in one terminal verification | 256 |
| chunk-verification receipts in one stream batch | 64 |
| transitive chunk-verification receipts in one terminal output | 16,384 checked, never flattened |
| Artifact identity parents for an addendum payload | 384; provenance exactly 0 |
| one K3 historical canonical command/receipt row | 16 MiB |
| Provider branch-chain canonical bytes | 1 MiB |

The effective limit is always `min(global hard cap, policy, binding/profile, plan, lease)`. SQL uses `LIMIT cap + 1`; decoders count before accepting item `cap + 1`; all multiplication and byte/count conversion is checked. No unbounded target-index, lineage, causal, evidence, or chunk query is legal.

The existing `BASGovernedArtifactPayloadCodec.maximumWireBytes(for:)` becomes an owner-controlled per-type table. It checks `BASProviderBranchChainPayload` against 1 MiB before entering `JSONDecoder`; all other addendum payloads retain the 16 MiB global wire ceiling, with their stricter raw/vector limits enforced by validating initializers. A caller cannot select or widen the table.

## 18. Prohibited Designs

The implementation must fail static or runtime gates if it introduces:

- another K3 store, writer, WAL, head, ordinal, claim map, source flag, visibility flag, or retry owner;
- caller-generated branch ordinals, Provider execution IDs, purposes, containment, limits, or visibility policy;
- a copyable, persisted, recoverable, Codable, or public-construction call permit;
- `executeExactlyOnce`; the honest name and guarantee are `executeAtMostOnce`;
- a visibility Artifact ID in claim request/receipt;
- a seal reference to a future proposal receipt;
- descriptor, arm, observation, attestation, policy fields, causal lists, or prefix-chain IDs copied into a lineage entry;
- `orderedVisibilityEvidenceArtifactIDs` on the chain;
- a failed/cancelled/indeterminate/checkpoint branch in completed lineage;
- a Provider/LLM-authored authoritative receipt, attestation, state mutation, tool call, publication, or commit;
- a raw `BASOrganRequest` persisted as the model-neutral physical payload;
- a bare-Codable Artifact put, raw JSON decoder, alternate canonical codec, self-ID field, receipt digest, or storage locator;
- a production call site that accepts a caller-built `BASArtifactIdentityCore`, caller-selected commitment-key epoch, or nonnil Artifact head update for these values;
- reconstruction of a committed K3/arm receipt through the generic active-epoch `put`, or exposure of the package-only historical-put port outside its two fixed owner factories;
- current Artifact/head/trust lookup before an exact historical idempotency hit is recovered;
- an unbounded attestation target lookup or a seal that fails to freeze the selected attestation/trust snapshot in its historical row;
- buffered visibility while any post-pin branch is allocated-unclaimed, claimed-unsealed, or otherwise nonterminal;
- exposing the concrete K3 object/branch-control port to BASOrgan, Provider/plugin/model, or application callback code;
- current/latest loose lookup in place of historical-row byte reconstruction;
- same-root post-claim reroute, retry, fallback, model swap, or sibling source replacement.

## 19. Verification and Test Gates

### 19.1 Budget tests

- concurrent expected-revision claims: one winner, exact replay returns the same body;
- same request ID/different canonical bytes: corruption;
- mutation of every root/lease/envelope/invocation/parent/ring/edge/depth/digest/witness/epoch/deadline/delta/head field;
- checked-add overflow and every lease ceiling;
- repeated digest, A→B→A cycle, false/no-progress witness;
- terminal zero-spend nil receipt ID; committed-use nonnil ID; converged nil rejection;
- v1 fixed bytes → v2 `.some`, v2 omitted-key nil, explicit-null rejection, future-version rejection;
- v1 identity/Artifact ID remains unchanged and the type-specific migration never performs an ordinary put;
- historical exact replay succeeds after the current head advances, current schema changes, referenced Artifact decoding becomes unavailable, or present trust is revoked; adoption still revalidates current policy;
- hard kill at validate/begin/row insert/head append/commit/reply/row-pinned historical-put boundaries;
- zero semantic/Provider/tool/effect/release calls for every terminal rejection.

### 19.2 Policy and allocation tests

- duplicate/reordered/unknown rules and roles;
- missing/multiple answer rules, answer `maximumInstances != 1`, tool/effect schema on answer;
- binding omission/duplicate/foreign policy/copied authority drift;
- allocation before atomic policy+binding installation;
- caller-supplied ordinal/purpose/provider/containment/limit/visibility/execution ID;
- concurrent ordinal allocation, no reuse/gap/ABA;
- non-frontier pin, unfinished lower ordinal, second pin, materialized-request substitution;
- incremental policy with any post-pin verifier allowance and buffered post-pin allocation before source completion both fail.

### 19.3 Claim and physical-call tests

- exact incremental sequence `A → M → T → Vrow → Q → call → V → C`, with no mechanism between Vrow and Q and no visible byte before V;
- gate-after-pin exact source first claim succeeds;
- sibling, duplicate, changed-materialized, missing-terminal-source claim fails;
- fresh outcome alone carries a noncopyable permit;
- recovered outcome, receipt, row, and state lookup never call;
- compiler probe for async protocol returning the noncopyable outcome under Swift 6;
- remote pre-arm rejects any claim-receipt dependency and post-claim handoff requires the matching fresh claim row plus permit;
- prepare-before-anchor, anchor-before-arm, arm-before-claim, expired-arm, Q-before-permit-delivery, and handoff-before-invoke crash cuts;
- arm commit → pre-put/reply → quiescent key rotation reconstructs the identical arm ID from its row-pinned epoch and the observation attestation's producer ID remains exact; unavailable old key still replays row bytes but makes handoff/call/adoption fail closed, and active-epoch remint is rejected;
- remote requires both fresh claim permit and W5 handoff winner;
- every post-claim crash path performs zero resend;
- compile/source gates prove the permit's sole `fileprivate init`, no production retention property, and exactly one local plus one remote consuming call seam.

### 19.4 Seal, observation, and lineage tests

- checkpoint nil proposal and nil/nil evidence for every containment; completed nonnil; non-success nil;
- local terminal nil/nil and isolated/remote terminal nonnil/nonnil arm/observation matrix;
- missing/foreign/multiple-purpose/invalid/revoked observation attestation;
- signed-statement mutation of purpose, producer arm, usage order, policy/time, scope, recovery boot, key role, or manifest binding;
- purpose-aware attestation lookup with zero, one, two, eight, and nine matches; eight other-purpose children do not hide one valid Provider-purpose child;
- purpose-aware input rejects empty, oversized, NUL-bearing, or noncanonical purpose and count `-1`, `0`, `9`, or `Int.max` before SQL; the deprecated target-only API fails closed on its ninth child;
- fresh Artifact Mesh v2 creation; exact v1→v2 migration and reopen; mixed/partial/future schema rejection; migration rollback on missing, malformed, duplicate, target-mismatched, or noncanonical-purpose rows; covering-index shape; and proof that SQL applies `(target, purpose)` before `LIMIT cap + 1`;
- a child added after seal cannot change historical replay; current trust revocation can deny adoption but cannot rewrite receipt bytes;
- exact seal replay succeeds from K3 bytes when its selected attestation/manifest cannot be reopened, while present adoption fails closed;
- immediate-return same-boot and authenticated-query-recovery later-boot validation, including stale recovery authority;
- descriptor/plan/materialized request/permit/arm/observation mismatch;
- fake public receipt Artifact with no historical K3 row;
- exact four-key CodingKeys, fixed canonical bytes, and commit-before-put row reconstruction for all five receipts;
- five-ID root/branch/request/proposal/seal substitution, omission, duplicate, reorder, extra entry;
- prefix-only, through-only, and mutually agreeing prefix+through substitution of a foreign turn/policy/binding pair; mixed-root entries; binding→policy mismatch; and mismatch with the historical root-installed pair;
- same proposal reused by two branches, any A/C/S/P/R reuse across entries, foreign T/V/E, and E→foreign spool/prefix;
- the same proposal identity core put under two commitment-key epochs and offered to two branches: Artifact IDs differ, aliases match, and the second seal fails;
- proposal receipt schema, fixed parent order, no seal back-edge;
- prefix last equals source; omitted completed branch fails; skipped non-completed ordinal requires historical proof;
- incremental through entries equal prefix exactly;
- incremental E v1, nil coverage, false E/chunk verification, coverage gaps/overlaps, and cap multiplication fail;
- buffered suffix is exact and complete; pending/in-flight post-pin ordinals reject visibility;
- prefix visibility pollution, through prefix-ID field, future/back-edge, and Artifact cycle rejection;
- chain payload and request/evidence hard-limit `cap + 1` failures.

### 19.5 Ownership and schema tests

- exact one symbol and registry object ID for every governed payload;
- current/backward/future fixtures through `BASGovernedArtifactPayloadCodec`, including terminal-receipt and exact-output v2 migrations;
- mutation of every schema-derived identity-core field/parent position for receipts, policy, M, O, R, E, and both chain cuts, plus nonnil head update and commitment-key rotation;
- package-only historical put reconstructs K3 and boundary-arm row-pinned IDs across rotation, rejects unavailable historical keys, has exactly the two fixed production owner-factory seams, and never falls back to the active epoch; exact command replay still returns stored bytes when rematerialization cannot run;
- same concrete-object identity for EventLog, budget, Provider, and package-only W5 handoff views;
- atomic branch-root projection exposes the exact immutable installed policy/binding pair needed by both chain validators without exposing concrete K3;
- no `RSIManager`, budget actor/store, Provider manager/store, or second K3 writer;
- OwnerLedger checker and candidate-manifest/CreateGate remain green.

## 20. Schema Registry and OwnerLedger Delta

This addendum reuses existing owners. OwnerLedger counts remain:

```text
owners = 29
create_allowlist = 14
create_permissions = 14
controlled_documents = 7
```

Two previously omitted governed payloads are added to the planned registry set:

1. `BASMaterializedProviderRequestPayload`;
2. `BASProviderProposalReceipt`.

Each has one typed registry entry and `.current`, `.backward_v1`, and `.future_rejection` fixtures. Against the current isolated baseline of 284 governed objects, landing only these two changes yields 286. Against the prior full Task-2A target of 295, the corrected full target is 297. Implementation must assert the actual pre-change count plus two rather than hard-code a stale intermediate total.

`BASControlLoopTerminalReceiptPayload` remains one registry object; its current fixture moves to v2 while its backward-v1 fixture preserves the original bytes.

`BASExactOutputVerificationPayload` also remains one registry object; its current fixture moves to v2 and its backward-v1 fixture is buffered-only. The v2 sovereign signature statement and trust-manifest entry update their already planned owners and do not create another governed object.

Artifact Mesh storage separately advances from database schema v1 to v2 for the purpose projection. This is a storage migration, not a governed payload or registry-object addition. `BASArtifactSQLiteStore`, its generated/embedded schema source, v1 fixture, v2 fresh fixture, and v1→v2 migration fixtures remain under the existing Artifact Store owner and add no second writer, owner, or OwnerLedger count.

Allowing the already governed `BASBoundaryArmReceipt` through the shared historical-put seam changes neither its schema nor the registry total. Its existing K3 boundary owner merely persists the already required identity inputs and commitment epoch beside the arm row.

Both new payloads live in `BASRuntimeCore/BASLowEntropyPrimitives.swift` under the existing `provider.package-boundary` owner. No production file, target, owner, Create permission, store, or generic migration framework is added for them.

Without changing the four ledger counts, implementation updates the `provider.package-boundary` row, its `BASLowEntropyPrimitives.swift` evidence path, all seven controlled documents, and the checker-required terms from `executeExactlyOnce` to `executeAtMostOnce`. The six Provider-relevant documents add `BASMaterializedProviderRequestPayload`; all seven add `BASProviderProposalReceipt` and the generic-lineage rule. The checker, ledger, evidence, and source must land atomically so an old required term cannot certify the new design.

## 21. Explicit Overrides to Older Plans

The following later rules win wherever older text differs:

1. terminal source is designated before claim, not merely before call;
2. incremental terminal order is allocate → materialize → pin → zero-byte gate → fresh claim → call;
3. gate closes all claims except the exact pinned source's first claim;
4. terminal pin freezes the materialized request;
5. claim returns a fresh/recovered noncopyable outcome, not a copyable receipt-only call authority;
6. `executeAtMostOnce` replaces `executeExactlyOnce`;
7. seal proposal ID is optional by terminal state and seal never references proposal receipt;
8. five K3 receipts nest their requests and do not echo descriptor/policy/root fields;
9. lineage has exactly five IDs;
10. every lineage purpose uses generic `BASProviderProposalReceipt`;
11. terminalPrefix ends at the source; incremental through has no suffix; buffered through has only the complete verifier suffix;
12. through does not contain terminalPrefix Artifact ID;
13. chain uses exact-output verification plus visibility receipt, not a generic visibility-evidence array;
14. remote/isolated observation requires discoverable generic attestation and the existing trust-manifest verifier;
15. `BASControlLoopTerminalReceiptPayload` v2 permits nil budget-use receipt only when the K3 row proves zero spend;
16. W5 prepare/anchor/arm is allocation/materialized-request bound and pre-claim; only its later same-owner handoff CAS binds the committed fresh claim row, so no W5 artifact depends on a not-yet-created claim receipt;
17. exact historical idempotency recovery precedes current Artifact/head/trust checks and never recreates a fresh permit;
18. Q/Vrow are K3 state and cannot be confused with C/V Artifacts;
19. prefix membership is closed by ordinal through the source, while only buffered through-visibility may add the exact terminal-resolved verifier suffix;
20. exact-output verification is v2, requires `passed == true`, and carries bounded incremental display closure only in incremental mode;
21. the initial attestation election is bounded and purpose-aware; K3 freezes the selected attestation and trust snapshot internally without adding a public seal/lineage field;
22. all addendum Artifact identity cores come from owner factories with exact parents, scope, producer, time, confidentiality, provenance, snapshot, head-update, and commitment-key rules.

## 22. Completion Criteria

This contract is implemented only when:

- every new mutation current-decodes before reducer use; an exact historical idempotency hit instead uses its schema-pinned backward decoder and never re-enters the reducer;
- one `BASSQLiteEventLogStorage` object implements all public K3 views and the package-only W5 handoff view;
- historical rows reconstruct every receipt byte-for-byte after commit-before-reply and commit-before-put crashes;
- every governed addendum value reconstructs its complete owner-derived identity core and passes the per-type pre-decode wire cap;
- only a fresh noncopyable permit can reach the physical Provider seam;
- the materialized request is immutable from pin through claim, permit, observation, seal, and replay;
- every completed Provider lineage is five-ID, K3-reconstructable, acyclic, and bounded;
- prefix/spool/verification/visibility/through/release form the exact DAG above in both modes;
- bounded purpose-aware attestation lookup, signed outer-context binding, and row-frozen trust evidence make remote replay historically stable;
- proposal identity aliases remain stable across commitment-key rotation, and every committed K3 or boundary-arm receipt rematerializes only through its row-pinned historical-key seam;
- all adversarial, crash, schema, owner, dependency, and no-duplicate-authority gates pass repeatedly;
- local in-process execution remains independent of W5 trust availability, while remote/isolated production fails closed until its boundary and observation attestation verifier are installed.
