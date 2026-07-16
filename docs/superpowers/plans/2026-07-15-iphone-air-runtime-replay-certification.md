# iPhone Air Runtime, Replay, and Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the preceding contracts through one typed owner-led turn root, remove duplicate Provider/result/effect authority, make the complete causal Provider branch chain and unique pinned terminal answer durably replayable, and establish the physical-device gates required for healthy Apple Silicon promotion and any 40/30 claim.

**Architecture:** `BASTurnRuntimeEngine.TurnOperation` is the only lifecycle that may traverse the semantic DAG under one canonical `BASTurnOperationRef`, consume the installed `BASProviderBranchPolicy`, and drive a bounded causally ordered chain of K3-allocated `.providerEgress[requestOrdinal]` branches. Each branch carries one policy `stepRuleID`, distinct `BASProviderStepPurpose` and `BASProviderOutputRole`, one ordinary-put governed `BASPersistedOrganDescriptorPayload` Artifact ID (wrapping the single canonical `BASOrganDescriptor` shape frozen by Silicon Task 7's W1 value-contract slice) bound unchanged through its allocation/claim receipts, one exact branch-bound sequence-zero `BASProviderExecutionRef`, one durable claim, and exactly one physical Provider call; multiple grounding, tool-continuation, terminal-answer, and verifier branches may exist under the same root. Event refs reuse that same type via checked `withRequestSequence(next)` while preserving every stable base field. Only the K3-pinned `terminalAnswerSourceBranchRef` can reach structural terminal seal, the immutable terminal-prefix chain artifact, the post-terminal-seal/pre-publication exact-byte spool, L10, `.finalPublication/0`, replay manifest, and publication finalization. The manifest copies none of the ordered lineage/policy/binding/source/visibility/descriptor facts; it references the authoritative result and the sovereign four-ID release group, then validators reopen both immutable chain payloads, spool, preparation, and receipt-reachable governed descriptor parent/remote evidence to prove equality. The 18-stage plan is a frozen compatibility projection only. Native-`Any` remains shadow/test-only; effects remain proposal/permit/broker driven. Certification proves per-branch exactly-once, one pinned terminal source, no sibling replacement, and both `BASProviderVisibilityMode` paths—not a false one-Provider-call invariant.

**Tech Stack:** Swift 6, SwiftPM, XCTest, SQLite/WAL, BASHostKit, BASRuntimeCore, BASMemory, BASObservability, BASEvaluation, XcodeGen, iOS 27 DeviceTestApp, shell certification scripts, and physical iPhone devices.

## Mandatory Master Wave Order

Task numbers below are reference and commit units; they do not override the master sequence. Every wave consumes the prior wave's immutable receipt and reruns the owner-ledger verifier. A later task section may be read for interface planning, but no production work from it starts while an earlier wave is red.

| Wave | Master scope | Work and hard gate in this plan |
|---|---|---|
| W0 | owner/write freeze | Run Task W0 as an extension of the shared global freeze: record current violations, freeze the owner/create ledger and promotion write set, and prohibit production edits until the gate is installed. |
| W1 | contracts / `TurnOperation` / Provider inversion | Consume the silicon plan's W1 receipt. Complete only Task 1's immutable semantic-DAG contract shapes and the typed operation/Provider boundary declarations; defer executor wiring and runtime behavior to W6. |
| W2 | K3 + erasure | Consume the sovereign K3 Provider-branch-control and erasure receipts only. Runtime does not consume or wire `BASProcessMemoryLedger` in W2. |
| W3 | StateLake / context | Consume the StateLake/context receipt for pure retrieval identity and deterministic/test-injected R5 proposal → R6 validation/revalidation → post-R6 context contracts. Every production Provider path remains disabled; no W4 binding, StateABI, or process ledger is required here. |
| W4 | silicon | Atomically install/reopen the sole Contracts `BASProviderBranchPolicy` artifact and one Silicon execution binding that references it, then consume plan actuation, process-shared MemoryLedger/HeavySeat, and physical-device smoke receipts. Only after the joint policy/binding gate may production R5 grounding → R6 → post-R6 context compilation run. Runtime may not copy branch policy or locally re-elect load/prefill/cache/decode. |
| W5 | K4 / release / Zone C | Complete the sovereign K4/release/Zone-C gate and Task 5 Steps 5A–5B's direct/synthetic-effect retirement and dedicated commit. Only the durable broker may produce execution truth; this closeout must be green before any W6 runtime branch. |
| W6 | runtime / certification | First land the contract-only Task 2 `BASSemanticShadowObservation` prelude and Semantic Task 8 audit-value prelude; the latter freezes first-governed `BASRuntimeAuditProjectionsBundle` 1.0.0 but does not run semantic work. Then Task 1B declares `BASSameRunAuditOutcome` and first-governs the complete final `BASTurnRuntimeAuditEnvelope` 1.0.0 shape. Next land Semantic Task 8's coordinator outcome behavior. Only then may Runtime Tasks 2/3/4/5 consume that outcome, ordinary-put/reopen its bundle, and populate frozen fields; Task 7 last cuts authoritative production from coordinator to engine-owned same-run outcome generation. No later task changes either 1.0.0 wire. |

Task 1 is split between its W1 contract declaration and W6 executor wiring; Task 2 is split into a value-only prelude and later observation behavior; Semantic Task 8 is split into a governed audit-value prelude and later coordinator integration. The mandatory W6 receipt order is `Task 2 value declaration → Semantic Task 8 value/schema declaration → Task 1B outcome contract + final envelope freeze → Semantic Task 8 outcome behavior → Runtime Tasks 2/3/4/5 integration → Task 7 authoritative outcome cutover`, regardless of physical section order. Task 5 Steps 5A–5B are W5 closeout, while its remaining runtime/replay integration is W6.

## Global Constraints

- iOS 27 is the minimum deployment target for every package product and app/extension target.
- Every self-ID-free payload independently ordinary-put through Artifact Mesh must conform to `BASSchemaVersioned`, visibly store `schemaVersion`, and expose an explicit public initializer whose first parameter is `schemaVersion: String = Self.currentSchemaVersion`. Every payload byte used for ordinary put, Artifact identity, or reopen must pass through the Contracts-owned `BASGovernedArtifactPayloadCodec`; raw `JSONEncoder`/`JSONDecoder`, alternate canonical encoders, caller-selected accepted-version sets, and field access before version rejection are forbidden. Each such payload has exactly one `BASEBrainSchemaGovernanceRegistry` entry plus exact current round-trip, pinned first/current-v1 fixture, missing/future-version rejection, and cross-target default-version initializer fixtures. A first-governed 1.0.0 launch must not fabricate a historical migration merely to satisfy the fixture name. A public initializer grants constructibility only: Runtime source/callsite gates still allow authoritative persistence/admission solely through the named owner-private factory and complete reopen validator.
- Exact same-store and same-K3-object claims are compile-time enforceable. The prerequisite Contracts delta makes `BASArtifactStorePort: AnyObject, Sendable`; the runtime K3 composition makes `BASK3ControlNucleusStorage: AnyObject, BASEventLogStorage, ...` (or exposes an equally unforgeable owner-identity API), and all named production conformers remain actors. Tests compare stable actor/object identity across composition, reopener, resolver, audit-bundle put/reopen, replay, and Qinao prepared-effect lookup. Boxing an unconstrained protocol existential as `AnyObject`, comparing transient boxes, or accepting two merely equivalent stores is forbidden.
- A semantic DAG node is an invocation, not another semantic layer. A remand creates a new invocation/artifact node; the canonical dependency graph itself remains acyclic.
- The semantic DAG runs through one `BASTurnRuntimeEngine.TurnOperation`, `BASNativeStageExecutor`'s typed semantic executor, and `BASParallelStageDispatchExecutor`; do not add a second runner actor, scheduler, stage ledger, cancellation tree, provider loop, spool owner, or result-producing coordinator.
- `BASNativeStageExecutor.StageExecutor` (`Any` input/output-erasing compatibility path) is observation-only. Authoritative use fails with `capabilityDenied(.nativeAnyShadowOnly)` before invocation. Typed semantic execution must return and persist the exact `BASSemanticNodeReceipt`; discarding a typed output is forbidden.
- The four rings are bounded, receipt-driven control loops. They do not own answer truth, state truth, external effects, authorization, or release.
- Shadow mode cannot mutate the request, UI, visible state, K4 ledger, Zone-C outbox, execution profile, or fallback selection.
- `semanticDAGAuthoritative` is not added to the runtime enum until Artifact-Mesh manifest persistence, the source-event index, and fail-closed composition exist.
- Authoritative mode calls exactly one `TurnOperation` rooted at one `BASTurnOperationRef`. It may consume multiple K3-allocated Provider branches only when the installed `BASProviderBranchPolicy` authorizes their `stepRuleID`, derived purpose, requested output role, count, causal receipts, terminal-pin state, and `BASProviderVisibilityMode`. Each newly won branch claim permits one physical call; no hidden second answer, sibling terminal replacement, branch-local retry, V1/native-Any, `draft`, or coordinator regeneration is allowed.
- Failure after cutover yields a typed refusal, defer, cancellation, or reconciliation result. Production contains no callable V1/native-Any route to resurrect; rollback deploys the previously certified Git tree.
- A result is not externally publishable until its complete pre-publication replay manifest is durably stored and can be reopened by turn/source-event identity. Publication then uses one durable reservation/idempotency key; its sink receipt is appended as a linked finalization record before the API returns.
- Replay simulates effects from recorded receipts. It never blindly repeats an external write.
- LLM/runtime tool output is proposal-only. External effects require a `BASActionPermit`, durable Zone-C broker reservation, `BASToolEffectAdapter` completion, and broker-authored receipt. `BASToolDispatcher.dispatch` becomes package-scoped and is callable in production only from that broker adapter after authorization; `BASEBrainRuntimeCoordinator`, `BASTurnRuntimeEngine`, Qinao, and model adapters may not fabricate `.executed`, infer execution from a command/proposal, or invoke a registered effect handler directly.
- After the turn's one capability-snapshot artifact exists, every material LayerCell Artifact Mesh buffer, L10 verifier/spool, manifest barrier, outer response-publication call, and replay read set uses the same injected `BASProcessMemoryLedger` and a per-turn resolver backed by `BASMemoryAdmissionContextGateway`. Production composition uses exactly `BASProcessMemoryLedger.processShared`; tests inject one isolated actor. No runtime/domain payload stores admission context, cap, reservation, or activation facts.
- A replay manifest is an ordinary Artifact Mesh payload with no self ID/digest/signature. Only its source-event index and publication journal are separate; there is no replay object store, replay-specific watermark type, or second event-integrity chain.
- `BASProviderBranchPolicy` is the sole plan-provider-router grammar artifact. Replay must reopen it and prove every ordered branch's `stepRuleID`, derived `BASProviderStepPurpose`, requested `BASProviderOutputRole`, causal receipt kinds/order, count/instance bound, answer-only constraint, post-terminal-pin verifier allowance, and `BASProviderVisibilityMode`. `BASSiliconExecutionBinding` contributes only its policy-artifact reference and `stepRuleID → model/profile/plan-template/budget` mapping; manifest/runtime never copy policy fields into another owner.
- Every authoritative result and replay manifest carries `turnOperationRef: BASTurnOperationRef`, never authoritative raw `turnID`. It references exactly two ordinary Artifact-Mesh instances of the shared Contracts `BASProviderBranchChainPayload`: `terminalPrefixProviderBranchChainArtifactID` is cut `.terminalPrefix` through the pinned terminal source and is the only chain ID bound by the spool; `throughVisibilityProviderBranchChainArtifactID` is cut `.throughVisibility`, proves the exact prefix relationship, and additionally binds any authorized post-pin verifier entries plus L10/visibility closure. Result/manifest do not copy the ordered lineage array or declare a local chain/head type. On reopen, every shared lineage entry binds the exact branch/sequence-zero execution ref, `stepRuleID`, plan, allocation/claim/seal/proposal, and causal receipts; the allocation/claim receipts expose the sole `selectedProviderDescriptorArtifactID`, and the seal receipt exposes the paired optional arm/observed-receipt IDs. Policy facts are derived. Exactly one source entry must equal spool, preparation, manifest, provisional/final refs, and publication request; a prefix artifact can never masquerade as the through-visibility artifact.
- `TurnOperation`/the engine actor privately owns only the transient unsealed Provider-event `(nextSequence, digest)` CAS for an already K3-claimed branch. `BASK3ControlNucleusStorage`/`BASSQLiteEventLogStorage` remains the sole durable allocation, claim, bounded checkpoint-head, and terminal-seal authority. Ordinary token/chunk acceptance performs zero SQL, fsync, or Artifact-Mesh writes; replay records only the bounded durable seals. A crash discards the transient tail and leaves the durable claim indeterminate/query-reconcile-only. This split adds no seventh K3 API, sequence store, or sidecar ledger. A claimed/possible-start branch can never be retried or replaced by a fresh ordinal; a later branch is legal only as installed-policy semantic continuation with exact successful terminal/proposal and required durable tool/effect receipt, otherwise recovery exact-queries/finalizes or starts a new Attempt.
- Provider preflight is value-only and occurs before allocation. It contains a policy `stepRuleID`, profile/plan/resource need, and no branch/ref/claim/physical effect. All capability/Pareto/fallback selection ends before `allocateProviderBranch`; Silicon then wraps the selected descriptor in `BASPersistedOrganDescriptorPayload`, ordinary-puts/reopens that parent through `BASGovernedArtifactPayloadCodec`, and allocation freezes the parent's Artifact ID, route, plan, ordinal, causes, and complete sequence-zero `BASProviderExecutionRef`. K3 treats parent bytes/containment as opaque and copies only the exact ID through allocation/claim. An allocated-but-unclaimed branch can only be reopened and claimed as itself, never abandoned for another route/ordinal. After claim, failure is same-branch query/reconciliation or a new Attempt, not fallback. Every successful shared lineage entry has one complete exact-branch base ref and receipt-reachable governed descriptor parent. `BASPlannedOrganRequest` contains no caller-loose Provider-ID authority or `responseSpoolArtifactID`; that spool ID first exists after pinned-source terminal-prefix sealing and ordinary Artifact Mesh put, then is bound once to the pinned source and `.finalPublication/0`.
- The installed `BASProviderVisibilityMode` is immutable and replayed exactly. `.incrementalVerified` requires terminal-source pin plus pre-call/incremental deterministic-verifier evidence before opening the UI gate and permits no later Provider branch. `.bufferedUntilVerified` keeps completion hidden, consumes only policy-preauthorized verifier proposals plus L10 acceptance, opens the gate, then emits the buffered final and permits no later branch. Only the pinned source may become visible; failed/indeterminate source has no sibling replacement.
- Reuse the snapshot-owned canonical `[BASLaneWatermark]` only by referencing and reopening its `semanticSnapshotArtifactID`, plus the plan-owned `BASSiliconExecutionBinding`, exact-release grant, one response-spool artifact, sovereign journal, sole post-reservation `BASCapabilityUseReceipt`, and current `BASEBrainTurnResult`. The pre-publication manifest references only artifact IDs that already exist at its barrier; it never copies a watermark field/vector, and the finalized sovereign journal row links the later capability-use and sink-receipt artifact IDs without rewriting the manifest or copying digest bundles.
- Telemetry contains structure, timing, outcomes, blinded identifiers, and protected evidence references by default—never raw prompt text or an unkeyed low-entropy private hash.
- Simulator and one-device evidence cannot promote a production backend profile. E4 is the minimum; E5 is controlled canary evidence.
- “Cold 40” means thermally-cold, resident, target-verified accepted decode. “Sustained 30” means the declared two-device 1800-second last-quarter protocol. Neither is currently a product promise.
- The default flips only in its own final commit after all physical-device gates are proven and the production target has no V1/native-Any construction or call site. Operational rollback is the preceding certified tree; legacy execution remains test-target-only and is excluded from the shipping composition.
- `BASFieldMetricsCollector`/MetricKit is delayed E5 canary evidence only. E4 is built from deterministic per-run receipts and current device harness logs; no certification verdict waits for or infers a per-run result from MetricKit delivery.

## Reuse Ledger and Approved Missing Owners

| Work | Class | Canonical owner and convergence rule |
|---|---|---|
| semantic topology | M + E | add only the missing DAG contract; extend `BASTurnRuntimeEngine` and project to current `BASTurnRuntimeStagePlan`/executors |
| LayerCell execution/parity | A + E | use the contracts plan's adapter over the existing `BASLayerActor` mesh and extend `BASEBrainTurnResultReplayHarness`; no second semantic actor runner/comparator authority |
| authoritative output | E/A | extend the existing `BASEBrainTurnResult` under `artifact.mesh` and `release.spool-publication`; one payload wraps/projects that current result exactly once, with no alternate public result type or missing-owner claim |
| replay | M + E | one manifest artifact; extend existing `BASEventLogEntry`/`BASSQLiteEventLogStorage` identity and current replay harness; add only an index, not a store of manifest bytes |
| publication | R/E | use the spool/publication journal and coordinator from the sovereign plan; runtime supplies the pre-publication manifest barrier and holds the outer ordinary response-publication memory activation without changing `publishExact` or giving memory dependencies to sovereign/K4 owners |
| certification | M + E/A | add one aggregate E0–E5 verdict/candidate-tree contract and thin controller/verifier; reuse all current scripts, probes, signposts, field metrics, and physical-device logs |
| production cutover | E/delete | modify existing host/cognitive/app entrypoints; remove V1/native-Any from production composition and retain legacy execution in test targets only; rollback is a certified-tree deployment |
| turn/provider/spool lifecycle | R/E | consume the Silicon plan's `BASTurnRuntimeEngine.TurnOperation`; one typed root owns a bounded K3 Provider-branch chain, one pinned terminal source, and one post-terminal-seal/pre-publication exact-byte spool/final lifecycle |
| effect execution truth | R/E | sovereign Zone-C broker is the only executor/receipt owner; dispatcher/coordinator/runtime produce proposals and consume durable receipts only |

Every task must include a concrete R/E/A/M Reuse Decision and, for each production M owner, the full eight-part Create Proof from the master plan. Tests/scripts may be new but must name the existing or allowlisted authority they exercise.

**Mandatory M-owner lifecycle (applies individually to every M task below):** include `docs/superpowers/specs/qinao-owner-ledger-v1.json`, `scripts/check_qinao_owner_ledger.py`, and `scripts/test_check_qinao_owner_ledger.py` in the task's Files/staging set. In one atomic first-create change, create the first allowlisted path, append that path to the matching row's `evidence_paths`, and transition `approved_missing → converging`; every later created allowlisted path is appended to evidence in its own atomic creation change. Remove a `current_conflicts` entry only with the exact freeze/retirement source plus its green proof; move a compatibility view to `allowed_projections` only when tests prove it has no authority, mutable state, or independent recovery. Run both checker scripts after every change. Transition `converging → implemented` only after every allowlisted production path exists, every such path is in `evidence_paths`, every task gate is green, and `current_conflicts == []`. Failure rolls back created paths, evidence, conflict/projection edits, and status together; early `implemented` is forbidden.

## Prerequisites and Cross-Plan Interfaces

- `docs/superpowers/specs/qinao-owner-ledger-v1.json` and `scripts/check_qinao_owner_ledger.py` are the mandatory owner/create preflight. Run the exact command in Task W0 before implementation, after every task, and against the detached candidate tree before E4. A missing ledger row, unresolved sole owner, undeclared production Create, or forbidden duplicate is a certification denial.
- Complete `2026-07-15-iphone-air-contracts-layercell.md` first. This plan consumes `BASArtifactID`, `BASArtifactScopeBinding`, store types, canonical `BASTurnOperationRef`/`BASTurnBranchRef`, `BASProviderStepPurpose`, `BASProviderOutputRole`, complete exact-branch `BASProviderExecutionRef` with its sole checked `withRequestSequence(_:)`, shared exact `BASProviderBranchLineageEntry`, `BASProviderBranchChainPayload` and its cut enum, `BASProviderVisibilityMode`, sole `BASProviderBranchPolicy`, the E-in-place self-ID-free `BASProviderObservedReceipt`, paired seal evidence fields, and injected six-method `BASProviderBranchControlPort` API, plus LayerCell types. It also consumes the exact contracts-owned `BASControlLoopEnvelopePayload`, `BASControlLoopProgressWitnessPayload`, `BASControlLoopTerminalReceiptPayload`, `BASBudgetUseRequest`, `BASBudgetLeaseControlPort`, and `BASBudgetUseReceipt`; Runtime bounded-decodes those exact types and never declares a generic terminal shape, RSI manager, loop store, scheduler, counter, or fifth ring. The shared Provider chain payload owns root/policy/binding, ordered lineage entries, source/designation receipt, cut, and the cut-specific L10/visibility closure. Result, spool, preparation, and manifest reference its ordinary Artifact IDs and never redeclare/copy the vector, descriptor, remote evidence, or chain shape. Raw IDs use only Contracts' canonical legacy codec and never carry authority.
- Complete `2026-07-15-iphone-air-semantic-statelake-context.md` first. This plan consumes `BASStateReadSnapshot` only through its envelope-supplied `semanticSnapshotArtifactID: BASArtifactID`; runtime replay reopens that artifact to validate the snapshot-owned canonical watermarks and integrity-bound source head and never declares a watermark field/vector.
- Complete `2026-07-15-iphone-air-silicon-execution-spine.md` first. Replay consumes its one `TurnOperation`, complete ordered K3 Provider allocation/claim/seal/proposal receipt chain, per-branch `planID`, receipt-bound `selectedProviderDescriptorArtifactID`, and exact sequence-zero `BASProviderExecutionRef`, one installed `providerBranchPolicyArtifactID`, one `executionBindingArtifactID`, exactly one pinned terminal source, visibility receipt/evidence, exact phase actuation receipts, and one post-terminal-seal/pre-publication exact-byte `spoolArtifactID`; it reaches descriptor/paired remote evidence only through existing receipts and does not copy policy/profile/ABI/lease/fallback/descriptor facts or invoke a Provider independently.
- From that Silicon plan consume the exact generic seams `BASMemoryAdmissionContextVerificationPort`, `BASMemoryAdmissionContextGateway`, `BASMemoryAdmissionContext`, `BASProcessMemoryLedger.processShared`, and the ledger's request/token APIs. Runtime forms one turn-scoped `(UInt64) async throws -> BASMemoryAdmissionContext` resolver by capturing the already-verified capability-snapshot artifact; it never reconstructs verified facts or accepts `hardCapBytes`.
- Complete `2026-07-15-iphone-air-sovereign-release-effects.md` through durable spool/publication. This plan consumes sovereign-owned `BASExactReleasePreparationPayload`, `BASResponseReleaseCoordinator.PublicationManifestRequestResolver`, `BASResponseReleaseCoordinator.publishExact(after replayManifestArtifactID: BASArtifactID, spoolArtifactID: BASArtifactID) async throws -> BASPublicationFinalization`, and its package `finalizedPublicationRecord(for:)` read that delegates to the coordinator's own journal, plus one exact-release grant Artifact reference, the sole post-reservation `BASCapabilityUseReceipt` Artifact reference, and one response-spool Artifact reference. It also consumes the sole `BASK3ControlNucleusStorage` composite and nonpersisted `BASK3ActivatedStateEvidence`/`lookupActivatedStateEvidence(turnOperationRef:commitArtifactID:)`; Runtime byte-compares that projection and declares no state receipt/store. Runtime neither declares nor stores publication reservation/finalization state and cannot inject a different journal/K3 view.
- Task 4 of the Semantic State plan must already have extended `BASEventLogStorage` with `BASEventLogHead`, `head(forSession:)`, and conditional append. Replay source identity is that existing integrity-bound head.

## Authority and File Map

| Class | Production file | Single responsibility |
|---|---|---|
| M — Create | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift` | Pure canonical topology, invocation, and receipt payload contracts only |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift` | Sole semantic topology traversal and authoritative runtime dispatch |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeStagePlan.swift` | Frozen 18-stage compatibility projection only |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift` | Typed semantic receipt execution; `Any` compatibility path is shadow-only/capability-denied |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASParallelStageDispatchExecutor.swift` | Execute canonical ready batches through the existing fan-out owner |
| R/E — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderPlanningCore.swift` and `ProviderExecutionCore.swift` | Reuse one frozen route and exactly-once provider claim from the Silicon plan |
| R/E — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift` | One spool payload identity/final; no stream-local second result |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift` | Consume broker receipts; remove synthetic executed-receipt construction |
| E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift` | Assemble only persisted execution receipts |
| E — Modify | `BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift` | Proposal/permit/broker seam only; no direct authoritative handler call |
| E — Modify | `BehavioralAISubstrate/Sources/BASOrgan/BASToolCallingPlanner.swift` | Emit tool proposals through an authorization port; never call dispatcher directly |
| A/E — Modify | `BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift` | Shadow parity and four replay modes over the existing result harness |
| E/A — Modify | `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift` | Extend the one public result with an Artifact-Mesh payload projection; no new owner |
| M — Create | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift` | Complete unsigned manifest payload, index binding, and pre-publication barrier receipt |
| E — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift` | Existing source-event identity and replay-index event kind |
| E/A — Modify | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | Derived manifest-ID index only; no manifest bytes or second integrity truth |
| R — External owner | Sovereign plan publication files | Publication journal, reservation, sink deduplication, finalization, and recovery |
| M — Create | `BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift` | One aggregate E0–E5/candidate-tree/claim verdict authority |
| A — Create | `BehavioralAISubstrate/Sources/BASArchitectureCertVerifier/main.swift` | Thin CLI over the BASEvaluation authority |
| A/E | Existing certification scripts, device runners, probes, and metrics files | Collect deterministic E4 evidence and delayed E5 evidence |

Production-file creation is limited to the two M contract files, one M certification file, and one thin A command-line adapter. New tests, scripts, schemas, and migration/status documents are allowed. This plan creates no semantic runner, LayerCell adapter, shadow comparator, replay object store, publication coordinator, result type, device scheduler, or second telemetry collector.

### Exact OwnerLedger M Permissions and Candidate Manifests

These are the only three production `M` permissions consumed by this plan. Every value must byte-match `docs/superpowers/specs/qinao-owner-ledger-v1.json`; a shortened path, renamed owner, bundled “runtime M” owner, or task-number drift fails before file creation.

| `owner_id` | `authority_symbol` | `create_proof_task` | Exact `candidate_path` |
|---|---|---|---|
| `runtime.semantic-dag` | `BASSemanticTurnDAG` | `runtime-replay-certification:Task 1` | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift` |
| `runtime.replay-manifest` | `BASArchitectureReplayManifest` | `runtime-replay-certification:Task 4` | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift` |
| `runtime.certification` | `BASAppleSiliconCertification` | `runtime-replay-certification:Task 6` | `BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift` |

Before each task's RED command, generate one ephemeral candidate manifest and pass it through the same CreateGate. Its exact top-level fields are `schema_version`, `owner_id`, `classification`, `candidate_path`, `authority_symbol`, `create_proof_task`, and `create_proof`; use `schema_version: 1`, `classification: M`, and the exact row above. Map that task's eight numbered proof paragraphs, without placeholder or abbreviation, to exactly `repository_search`, `public_primitive`, `missing_invariant`, `extension_insufficient`, `single_owner`, `dependency_direction`, `compatibility_retirement`, and `verification`. Candidate manifests are temporary evidence and are never committed. The production Create remains forbidden until this command passes:

```bash
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$CANDIDATE_MANIFEST"
```

---

### Task W0: Prove the Current Authority Violations and Freeze Promotion Gates

**Reuse Decision (R/E):** Use `docs/superpowers/specs/qinao-owner-ledger-v1.json` as the sole machine-readable owner/create ledger and `scripts/check_qinao_owner_ledger.py` as its sole structural verifier. Add runtime/effect/native/cutover owner rows to that ledger and behavioral tests to existing test targets. Do not create a second scanner, ownership manifest, or waiver file.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageCapabilityTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectReceiptTruthTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationCutoverTests.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASToolCallingPlanner.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoLoop/QinaoStreamingOrganEndpoint.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Verify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift`

**Required owner-ledger keys:**

| Exact OwnerLedger `owner_id` | Sole production owner | Promotion-denying duplicate/path |
|---|---|---|
| `runtime.turn-operation` | `BASTurnRuntimeEngine.TurnOperation` | direct `coordinator.runTurn` after semantic execution; a second provider/result loop |
| `runtime.semantic-executor` | typed `BASNativeStageExecutor.SemanticNodeExecutor` | authoritative `StageExecutor`/`RoutedStageExecutor` returning `Any` |
| `runtime.semantic-dag` | `BASSemanticTurnDAG` immutable value contract | second DAG/scheduler/actor/ledger or eighteen-stage semantic authority |
| `runtime.replay-manifest` | `BASArchitectureReplayManifest` | second manifest store/index/watermark/integrity chain or publication-before-manifest |
| `runtime.certification` | `BASAppleSiliconCertification` | telemetry-only verdict or candidate-tree/device identity drift |
| `release.spool-publication` | one TurnOperation plus sovereign spool/publication owners | stream then eager regeneration; two spool/final/publication IDs |
| `effect.zone-c-saga` | durable Zone-C broker + thin `BASToolEffectAdapter`; broker completion is receipt truth | direct runtime/Qinao/model-adapter handler call or synthetic `.executed` receipt |
| `production.cutover` | semantic authoritative composition | production `.v1ByteEqual`, `.nativeV2`, `coordinator.runTurn`, native-Any, or environment-selected mode |
| `platform.ios27` | workspace build manifests/generated project settings | an iOS 18–26 production compatibility slice |

- [ ] **Step 1: Add failing capability/effect/cutover tests**

```swift
func testAuthoritativeCompositionDeniesNativeAnyExecutorBeforeInvocation() async {
    let probe = InvocationProbe()
    let executor = BASNativeStageExecutor()
    await XCTAssertThrowsErrorAsync {
        _ = try await executor.executeStage(
            fixtureStage(),
            request: fixtureRequest(),
            executionClass: .authoritative,
            executor: { _, _ in
                await probe.markInvoked()
                return "discarded"
            })
    } verify: { error in
        XCTAssertEqual(
            error as? NativeExecutionError,
            .capabilityDenied(.nativeAnyShadowOnly))
    }
    let wasInvoked = await probe.wasInvoked
    XCTAssertFalse(wasInvoked)
}

func testCommandOrProposalCannotBecomeExecutedReceipt() async throws {
    let fixture = makeSovereignEffectFixture()
    let proposal = try await fixture.runtime.propose(fixture.command)
    let executionReceipts = await fixture.effectBroker.executionReceipts
    let handlerInvocationCount = await fixture.handler.invocationCount
    XCTAssertEqual(proposal.status, .proposed)
    XCTAssertTrue(executionReceipts.isEmpty)
    XCTAssertEqual(handlerInvocationCount, 0)
}

func testOnlyBrokerCompletionCanProduceExecutedReceipt() async throws {
    let fixture = makePermittedEffectFixture()
    let result = try await fixture.effectBroker.execute(
        turnOperationRef: fixture.turnOperationRef,
        effectBranchRef: fixture.effectBranchRef,
        effectBoundaryInstanceID: fixture.effectBoundaryInstanceID,
        outboxArtifactID: fixture.outboxArtifactID)
    let receiptRecord = try await fixture.artifactStore.read(
        result.receiptArtifactID)
    let receipt = try fixture.decodeEffectReceipt(receiptRecord)
    let handlerInvocationCount = await fixture.handler.invocationCount

    XCTAssertEqual(receipt, result.receipt)
    XCTAssertEqual(receipt.outcome, .succeeded)
    XCTAssertEqual(receipt.turnOperationRef, fixture.turnOperationRef)
    XCTAssertEqual(receipt.effectBranchRef, fixture.effectBranchRef)
    XCTAssertEqual(receipt.effectBoundaryInstanceID, fixture.effectBoundaryInstanceID)
    XCTAssertEqual(receipt.outboxArtifactID, fixture.outboxArtifactID)
    XCTAssertEqual(receipt.toolInvocationArtifactID, fixture.toolInvocationArtifactID)
    XCTAssertEqual(
        receipt.capabilityUseReceiptArtifactID,
        fixture.capabilityUseReceiptArtifactID)
    XCTAssertEqual(
        receipt.effectBoundaryPermitArtifactID,
        fixture.effectBoundaryPermitArtifactID)
    XCTAssertEqual(
        receipt.boundaryAnchorReceiptArtifactID,
        fixture.boundaryAnchorReceiptArtifactID)
    XCTAssertEqual(
        receipt.boundaryArmReceiptArtifactID,
        fixture.boundaryArmReceiptArtifactID)
    XCTAssertEqual(handlerInvocationCount, 1)
}

func testCutoverOperationCallsEachPolicyBranchOnceAndNeverV1() async throws {
    let fixture = makeAuthoritativeTurnOperationFixture()
    let final = try await fixture.engine.beginTurn(fixture.request).final()
    let chain = try await fixture.reopenProviderBranchChain(
        final.throughVisibilityProviderBranchChainArtifactID,
        expectedCut: .throughVisibility)
    let invocationCountsByBranch = await fixture.providers.invocationCountsByBranch
    let v1InvocationCount = await fixture.v1Coordinator.invocationCount
    let spoolFinalizationCount = await fixture.spool.finalizationCount
    XCTAssertEqual(
        invocationCountsByBranch,
        Dictionary(uniqueKeysWithValues:
            chain.orderedEntries.map {
                ($0.providerEgressBranchRef, 1)
            }))
    XCTAssertGreaterThan(chain.orderedEntries.count, 1)
    XCTAssertEqual(chain.orderedEntries.filter {
        $0.providerEgressBranchRef == final.terminalAnswerSourceBranchRef
    }.count, 1)
    XCTAssertEqual(v1InvocationCount, 0)
    XCTAssertEqual(spoolFinalizationCount, 1)
}
```

The effect test fixture uses a handler that increments before touching its fake external system, so a direct-dispatch bypass cannot hide. Add negative mutation cases for missing/expired/mismatched permits, missing broker reservation, duplicate completion, command-only receipt synthesis, and replay simulation; every case leaves the handler count at zero except the single valid broker execution.

- [ ] **Step 2: Run the exact W0 RED gate**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASNativeStageCapabilityTests|BASSovereignEffectReceiptTruthTests|BASTurnOperationCutoverTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoRuntimeGateTests|QinaoTokenSigningTests|QinaoSovereignHostAssemblyTests'
rg -l 'toolExecutor:' \
  "$ROOT/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests" --glob '*.swift' \
  | LC_ALL=C sort
```

Expected RED: native stage execution erases/discards `Any`; the runtime can continue into V1; the coordinator builds `.executed` receipts from commands; `BASToolDispatcher` and Qinao's `ToolExecutor` closure can call a handler without the durable permit/broker path; Qinao streaming recommends a second generation; and the one-operation/provider/spool/final invariants are absent. Preserve the verifier JSON, exact failing test names, and the sorted Qinao constructor inventory as pre-change evidence.

- [ ] **Step 3: Make W0 a hard dependency of every task and E4**

Run the same three commands after Tasks 1–7. A task may not be committed if it adds a new violation. Before the detached candidate tree is measured, all commands must pass with zero violations. The certification verifier consumes the owner-ledger file digest, verifier executable digest, and passing JSON artifact ID; a mismatch or later source change denies promotion.

---

### Task 1 — Part A [W1]: Freeze the Pure Canonical Semantic DAG Contract

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift`

**Reuse Decision (M):** The semantic DAG topology/invocation contract is allowlisted as missing, so one pure RuntimeCore file is created. W1 declares and registers immutable values only. It does not import HostKit, call `executeSemanticTopology`, touch a stage executor/engine/audit envelope, or create any production composition. Scheduling, fan-out, cancellation, stage records, and stage-ledger wiring are deferred to Task 1B in W6 after W5. Do not create `BASNativeSemanticDAGRunner`, another actor, another ledger, or another coordinator.

For owner-ledger key `runtime-replay-certification:Task 1`, the first create delta atomically adds the exact production path permission and create-proof evidence and changes `approved_missing → converging`; subsequent deltas append concrete evidence. Remove a `current_conflicts` item only with proof. Change to `implemented` only when every declared path exists, task tests and owner/checker gates pass, the evidence list is complete, and `current_conflicts == []`. Roll back ledger status/evidence/permission with the source create if the create is rolled back. Stage the ledger, checker, checker test, created source, registry, and focused tests together.

**Create Proof — `BASSemanticTurnDAG.swift`:**

1. Repository search: `rg -n 'SemanticTurnDAG|SemanticNodeInvocation|SemanticNodeReceipt' BehavioralAISubstrate/Sources` finds no semantic topology owner; the nearest mechanisms are `BASTurnRuntimeStagePlan`, `BASTurnRuntimeEngine`, `BASNativeStageExecutor`, and `BASParallelStageDispatchExecutor`.
2. Public/upstream search: Swift actors and `TaskGroup` execute work but do not define the application's semantic dependency, remand, exact-release, or effect/state ordering contract.
3. Missing invariant: one acyclic typed topology whose provisional, exact-response, effect, state, bounded-remand, and contracts-owned bounded-RSI invocation paths can be validated before execution without turning a loop into a graph cycle or mutable scheduler.
4. Extension alone is insufficient because the old 18-stage identity is a legacy compatibility taxonomy; making it the semantic topology would preserve the wrong authority. The new file is values and validation only, while all execution remains in existing owners.
5. Authority/state/storage/failure: this file owns immutable topology and invocation/receipt shapes only; it has no mutable state or storage. Artifact Mesh stores invocation/receipt payloads. Validation and malformed dependency failures are typed and fail before dispatch.
6. Dependency direction: `BASRuntimeCore` depends only on Foundation plus prerequisite RuntimeCore contracts; `BASHostKit` imports it and extends current execution owners. No RuntimeCore import points back to HostKit.
7. Compatibility: `BASTurnRuntimeStagePlan.canonical()` stays frozen at 18 stages and is exposed only through `frozenCompatibilityProjection(of:)`; legacy modes remain explicit until Task 7 certification, then remain rollback/test-only.
8. Mutation/crash/replay/duplicate tests reject cycles, duplicate edges, provisional-to-effect reachability, activation before seal, an invocation that copies loop budget/ring/depth fields instead of referencing one envelope artifact, repeated state digests, A↔B back-edge oscillation, missing/false progress witnesses, stale epochs, exhausted/deadline/depth/branch budgets, post-effect non-reconciliation iteration, noncanonical ready-batch order, a second runner declaration, and any executor path that bypasses the existing engine/stage owners.

**Interfaces:**
- Consumes: `BASSemanticLayerID` (the prerequisite alias of `BASCognitiveLayer`), `BASArtifactID`, the contracts-owned `BASControlLoopEnvelopePayload`/`BASControlLoopProgressWitnessPayload` Artifact IDs, and a caller-supplied logical-time value in the immutable receipt. Loop budgets/ring/depth/branch/deadline/epoch/digest lineage stay inside the reopened envelope and are not copied into invocation fields.
- Produces: `BASSemanticTurnDAG.canonical()`, `validateCanonical()`, package pure `readiness(reopenedNodeEvidence:conditionEvidence:)`, `BASSemanticNodeInvocation`, `BASSemanticNodeReceipt`, and their schema-registry entries. The old IDs-only `readyBatch(completedNodeIDs:)` is not added because it cannot evaluate conditional/alternative edges. This task produces no executor, engine entrypoint, runtime mode, audit wiring, or Provider/effect capability in W1.

- [ ] **Step 1: Write failing topology, remand, projection, and executor-ownership tests**

```swift
import XCTest
@testable import BASRuntimeCore

final class BASSemanticTurnDAGTests: XCTestCase {
    func testCanonicalGraphHasExactNodesEdgesAndNoCycle() throws {
        let dag = BASSemanticTurnDAG.canonical()
        XCTAssertEqual(dag.orderedNodes.count, 28)
        XCTAssertEqual(Set(dag.orderedNodes).count, 28)
        XCTAssertEqual(Set(dag.orderedEdges).count, dag.orderedEdges.count)
        XCTAssertNoThrow(try dag.validateCanonical())
    }

    func testProvisionalPathCannotReachExactEffectOrState() throws {
        let dag = BASSemanticTurnDAG.canonical()
        XCTAssertFalse(dag.hasPath(from: .provisionalRelease, to: .exactReleasePreparation))
        XCTAssertFalse(dag.hasPath(from: .provisionalRelease, to: .effectDispatch))
        XCTAssertFalse(dag.hasPath(from: .provisionalRelease, to: .stateCommit))
        XCTAssertTrue(dag.hasPath(from: .exactAuthorization, to: .exactReleasePreparation))
    }

    func testRemandCreatesNewInvocationArtifactWithoutGraphBackEdge() throws {
        let invocation = try fixtureInvocation(
            nodeID: .exactPresentationSpool,
            parentArtifactIDs: [fixtureArtifactID("risk-remand-receipt")],
            controlLoopEnvelopeArtifactID: fixtureArtifactID("bounded-remand-envelope")
        )
        XCTAssertEqual(
            invocation.controlLoopEnvelopeArtifactID,
            fixtureArtifactID("bounded-remand-envelope")
        )
        XCTAssertNoThrow(try BASSemanticTurnDAG.canonical().validateCanonical())
    }

    func testInvocationReferencesOneEnvelopeAndCopiesNoLoopAuthority() throws {
        let invocation = try fixtureInvocation(
            nodeID: .groundingStateMarket,
            controlLoopEnvelopeArtifactID: fixtureArtifactID("loop-envelope")
        )
        let labels = Set(Mirror(reflecting: invocation).children.compactMap(\.label))
        XCTAssertTrue(labels.contains("controlLoopEnvelopeArtifactID"))
        XCTAssertTrue(labels.isDisjoint(with: [
            "ringID", "round", "maximumRounds", "remainingBudget",
            "maximumDepth", "maximumBranches", "budgetLease", "loopStateDigest",
        ]))
    }

    func testTypedReadinessTreatsFalseEdgeAsInapplicableAndContinuesJoin() throws {
        let dag = BASSemanticTurnDAG.canonical()
        let projection = try dag.readiness(
            reopenedNodeEvidence: fixtureCompletedPredecessorEvidence(),
            conditionEvidence: fixtureConditionEvidence(
                effectRequested: .inapplicable,
                noExternalEffect: .applicable))
        XCTAssertFalse(projection.readyNodeIDs.contains(.effectDispatch))
        XCTAssertTrue(projection.inapplicableNodeIDs.contains(.effectDispatch))
        XCTAssertTrue(projection.readyNodeIDs.contains(.stateCommit))
    }

    func testReadinessRejectsMissingForeignExtraOrSwappedConditionEvidence() throws {
        for mutation in BASSemanticConditionEvidenceMutation.allCases {
            XCTAssertThrowsError(try BASSemanticTurnDAG.canonical().readiness(
                reopenedNodeEvidence: fixtureCompletedPredecessorEvidence(),
                conditionEvidence: fixtureConditionEvidence(mutation: mutation)))
        }
    }

}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_SEMANTIC_DAG_CANDIDATE_MANIFEST:?set the ephemeral runtime.semantic-dag candidate manifest path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$BAS_SEMANTIC_DAG_CANDIDATE_MANIFEST"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter BASSemanticTurnDAGTests
```

Expected: FAIL at compile time with `cannot find 'BASSemanticTurnDAG' in scope`; no new topology file exists. This W1 RED command must not compile or call `executeSemanticTopology` and must not edit HostKit.

- [ ] **Step 3: Add the pure canonical topology, invocation, and receipt payloads**

```swift
import Foundation

public enum BASSemanticTurnNodeID: String, Codable, Sendable, Hashable, CaseIterable {
    case inputNormalize
    case admissionPreflight
    case turnAndResourceLeasePolicy
    case situationAndRiskHints
    case worldPriorProjection
    case hostConstitutionProjection
    case stateRequirementPlan
    case semanticStateRetrieval
    case groundingStateMarket
    case contextCompile
    case provisionalEligibility
    case provisionalReleaseGrant
    case prefill
    case decode
    case streamingVerification
    case provisionalRelease
    case candidateSelection
    case exactPresentationSpool
    case exactVerification
    case finalRisk
    case exactAuthorization
    case exactReleasePreparation
    case statePrepare
    case effectAuthorization
    case effectDispatch
    case stateCommit
    case terminalSeal
    case stateActivation
}

public enum BASSemanticTurnEdgeCondition: String, Codable, Sendable, Hashable {
    case always
    case provisionalEligible
    case chunkVerified
    case exact
    case effectRequested
    case noExternalEffect
    case authorized
    case terminalReceiptPresent
}

public struct BASSemanticTurnEdge: Codable, Sendable, Hashable {
    public let from: BASSemanticTurnNodeID
    public let to: BASSemanticTurnNodeID
    public let condition: BASSemanticTurnEdgeCondition

    public init(
        from: BASSemanticTurnNodeID,
        to: BASSemanticTurnNodeID,
        condition: BASSemanticTurnEdgeCondition
    ) {
        self.from = from
        self.to = to
        self.condition = condition
    }
}

public enum BASSemanticNodeOutcome: String, Codable, Sendable, Equatable {
    case completed
    case degraded
    case remanded
    case refused
    case deferred
    case cancelled
    case reconcileRequired
    case failedClosed
}

public struct BASSemanticTurnDAG: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let orderedNodes: [BASSemanticTurnNodeID]
    public let orderedEdges: [BASSemanticTurnEdge]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        orderedNodes: [BASSemanticTurnNodeID],
        orderedEdges: [BASSemanticTurnEdge]
    ) throws {
        self.schemaVersion = schemaVersion
        self.orderedNodes = orderedNodes
        self.orderedEdges = orderedEdges
        try validateCanonicalShape()
    }

    public static func canonical() -> Self {
        Self(
            uncheckedSchemaVersion: Self.currentSchemaVersion,
            orderedNodes: BASSemanticTurnNodeID.allCases,
            orderedEdges: canonicalEdges
        )
    }

    private init(
        uncheckedSchemaVersion: String,
        orderedNodes: [BASSemanticTurnNodeID],
        orderedEdges: [BASSemanticTurnEdge]
    ) {
        self.schemaVersion = uncheckedSchemaVersion
        self.orderedNodes = orderedNodes
        self.orderedEdges = orderedEdges
    }
}

public struct BASSemanticNodeInvocation: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let nodeID: BASSemanticTurnNodeID
    public let ownerLayer: BASSemanticLayerID?
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let orderedInputArtifactIDs: [BASArtifactID]
    public let controlLoopEnvelopeArtifactID: BASArtifactID?

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        nodeID: BASSemanticTurnNodeID,
        ownerLayer: BASSemanticLayerID?,
        parentArtifactIDs: [BASArtifactID],
        inputArtifactIDs: [BASArtifactID],
        controlLoopEnvelopeArtifactID: BASArtifactID?
    ) throws {
        self.schemaVersion = schemaVersion
        self.nodeID = nodeID
        self.ownerLayer = ownerLayer
        guard Set(parentArtifactIDs).count == parentArtifactIDs.count,
              Set(inputArtifactIDs).count == inputArtifactIDs.count else {
            throw BASSemanticTurnDAGError.duplicateParentOrInputArtifact
        }
        self.orderedParentArtifactIDs = parentArtifactIDs
        self.orderedInputArtifactIDs = inputArtifactIDs
        self.controlLoopEnvelopeArtifactID = controlLoopEnvelopeArtifactID
    }
}

public struct BASSemanticNodeReceipt: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let invocationArtifactID: BASArtifactID
    public let nodeID: BASSemanticTurnNodeID
    public let outputArtifactID: BASArtifactID?
    public let capabilityUseReceiptArtifactID: BASArtifactID?
    public let budgetUseReceiptArtifactID: BASArtifactID?
    public let controlLoopTerminalReceiptArtifactID: BASArtifactID?
    public let executionBindingArtifactID: BASArtifactID?
    public let outcome: BASSemanticNodeOutcome
    public let startedLogicalTime: UInt64
    public let finishedLogicalTime: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        invocationArtifactID: BASArtifactID,
        nodeID: BASSemanticTurnNodeID,
        outputArtifactID: BASArtifactID?,
        capabilityUseReceiptArtifactID: BASArtifactID?,
        budgetUseReceiptArtifactID: BASArtifactID?,
        controlLoopTerminalReceiptArtifactID: BASArtifactID?,
        executionBindingArtifactID: BASArtifactID?,
        outcome: BASSemanticNodeOutcome,
        startedLogicalTime: UInt64,
        finishedLogicalTime: UInt64
    ) throws {
        guard finishedLogicalTime >= startedLogicalTime else {
            throw BASSemanticTurnDAGError.invalidLogicalTime
        }
        self.schemaVersion = schemaVersion
        self.invocationArtifactID = invocationArtifactID
        self.nodeID = nodeID
        self.outputArtifactID = outputArtifactID
        self.capabilityUseReceiptArtifactID = capabilityUseReceiptArtifactID
        self.budgetUseReceiptArtifactID = budgetUseReceiptArtifactID
        self.controlLoopTerminalReceiptArtifactID = controlLoopTerminalReceiptArtifactID
        self.executionBindingArtifactID = executionBindingArtifactID
        self.outcome = outcome
        self.startedLogicalTime = startedLogicalTime
        self.finishedLogicalTime = finishedLogicalTime
    }
}
```

Define `BASSemanticTurnDAGError` with exact cases for duplicate/missing node, duplicate/self/missing-endpoint edge, cycle, invalid provisional reachability, invalid exact ordering, invalid effect/state ordering, malformed loop-envelope reference, control-loop budget evidence mismatch, invalid converged terminal evidence, duplicate parent/input artifact, invalid logical time, no ready node, unknown completed node, missing/foreign/extra/duplicate condition evidence, condition mismatch, and receipt/evidence node mismatch. Budget exhaustion/depth/branch/deadline/progress failures use prerequisite Contracts/K3 errors rather than a Runtime counter.

Add package in-memory values `BASSemanticReopenedNodeEvidence(receiptArtifactID:receipt:)`, `BASSemanticEdgeApplicabilityEvidence(edge:evidenceArtifactIDs:verdict:)`, verdict `.applicable/.inapplicable`, and `BASSemanticReadinessProjection(readyNodeIDs:inapplicableNodeIDs:)`; none is Codable, persisted, or schema-registered. Implement package `readiness(reopenedNodeEvidence:conditionEvidence:)` with deterministic UTF-8 ordering. It validates unique known receipt nodes/IDs and exact edge-key coverage. `.always` edges are applicable without a condition record. A conditional edge from a completed predecessor requires exactly one evidence value whose edge/condition/evidence IDs match; a condition record for an unknown/always/not-yet-evaluable edge is foreign/extra. An applicable edge requires its predecessor's same-store-reopened `.completed` or `convergedVerified` evidence. An inapplicable edge does not count as missing. A node is ready when every applicable incoming edge is complete, no incoming condition is pending, and at least one incoming alternative is applicable (roots are ready with no incoming edge); a node whose evaluated incoming alternatives are all inapplicable enters `inapplicableNodeIDs` and is never invoked. The engine derives the condition values only from reopened sole-owner receipt bodies before calling this pure function. There is no IDs-only overload or default-to-applicable behavior. `validateCanonical()` enforces these exact paths:

```text
inputNormalize → admissionPreflight → turnAndResourceLeasePolicy → situationAndRiskHints
worldPriorProjection + hostConstitutionProjection + situationAndRiskHints → stateRequirementPlan
stateRequirementPlan → semanticStateRetrieval → groundingStateMarket → contextCompile
contextCompile → provisionalEligibility → provisionalReleaseGrant
contextCompile → prefill → decode → streamingVerification
provisionalReleaseGrant → streamingVerification → provisionalRelease
decode → candidateSelection → exactPresentationSpool → exactVerification → finalRisk
exactPresentationSpool + finalRisk → exactAuthorization → exactReleasePreparation
finalRisk → statePrepare
statePrepare → effectAuthorization → effectDispatch → stateCommit
statePrepare → stateCommit only under noExternalEffect
stateCommit → terminalSeal → stateActivation
```

No edge originates at `provisionalRelease`. A remand or bounded RSI continuation creates and stores a new concrete `BASSemanticNodeInvocation` whose `orderedParentArtifactIDs` references the prior node-receipt artifact; it never edits `orderedEdges` or inserts a back-edge. Its sole loop-specific field is optional `controlLoopEnvelopeArtifactID`; the referenced self-ID-free contracts payload carries the exact root/ring/lease/epoch/depth/branch/deadline/state-digest, prior-use-receipt, and typed-progress-witness lineage. Runtime never copies those facts or accepts a free-form “progress” string. Parent/input artifact arrays preserve the canonical DAG-edge/input order supplied by the engine and reject duplicates; they are not sorted by `BASArtifactID`, which is intentionally not `Comparable`. A loop node receipt references the newly won budget-use receipt, and only a converged-and-verified terminal loop receipt may be named by an authoritative downstream invocation; intermediate outputs remain proposal-only. The payloads above contain no own artifact ID, digest, locator, signature, scheduler, or mutable ledger.

- [ ] **Step 4 [W1]: Register only the three immutable payload schemas**

Register `BASSemanticTurnDAG`, `BASSemanticNodeInvocation`, and `BASSemanticNodeReceipt` in the existing schema governance registry and exact-count/backward-decode tests. Do not register executor tuples, ready batches, configuration closures, audit observations, or any W6 runtime surface. The registry change is schema metadata only and must not import HostKit.

All three stored payloads retain `currentSchemaVersion = "1.0.0"`, a visible stored `schemaVersion`, and their explicit public initializers with `schemaVersion: String = Self.currentSchemaVersion` first. Every DAG/invocation/receipt ordinary put, Artifact identity-core payload construction, and reopen must use only `BASGovernedArtifactPayloadCodec.canonicalBytes(for:)`/`decodeCurrent`; a raw encoder/decoder, caller-selected accepted-version set, or topology/receipt field access before version rejection fails the source gate. Register each exact Swift basename once through the normal metatype entry with exact `schema.<Type>.current`, `schema.<Type>.backward_v1`, and `schema.<Type>.future_rejection` fixtures. Tests prove current canonical round-trip, pinned-v1 decode, missing/future rejection before readiness/execution/budget use, exact-one object/test IDs, and registry/current-version parity. A cross-target compile fixture imports `BASRuntimeCore` and constructs all three through their public initializers while omitting `schemaVersion`; constructibility does not permit HostKit execution or persistence outside the owner path.

- [ ] **Step 5 [W1]: Run pure contract/vector GREEN and the wave-boundary scan**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 "$ROOT/scripts/test_check_qinao_owner_ledger.py"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASSemanticTurnDAGTests|BASEBrainSchemaGovernanceRegistryTests'
! rg -n '@testable import BASHostKit|executeSemanticTopology|BASNativeStageExecutor|BASParallelStageDispatchExecutor|BASTurnRuntimeEngine' \
  "$ROOT/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift"
! rg -n 'import BASHostKit|executeSemanticTopology|BASTurnRuntimeStagePlan|BASNativeStageExecutor|BASParallelStageDispatchExecutor|BASTurnRuntimeEngine' \
  "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift"
```

Expected: pure DAG, canonical vectors, malformed topology/remand cases, and registry round trips pass; both source scans print no match. No HostKit production file has a Task 1 Part-A diff.

- [ ] **Step 6 [W1]: Commit the canonical Task 1 create receipt separately**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift
git diff --cached --check
git commit -m "feat: define canonical semantic turn dag"
```

This remains canonical owner-ledger/create-permission `runtime-replay-certification:Task 1`; “Part A” is a wave split, not a renamed owner or a second create task. Preserve this W1 receipt through W2–W5. It contains no executor, engine, stage-plan, audit-envelope, runtime-mode, Provider, spool, release, or publication wiring.

### Task 1 — Part B [W6, only after W5]: Wire the Frozen DAG Through Existing Runtime Owners

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeStagePlan.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASParallelStageDispatchExecutor.swift`
- Modify renamed-alias consumers: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift`
- Modify renamed-alias consumers: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASRuntimeInternalDelegate.swift`
- Modify renamed-alias consumers: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASKernelRegistryDispatchExecutor.swift`
- Modify renamed-alias documentation consumer: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageDispatchLedger.swift`
- Modify renamed-alias doctrine consumer: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASCognitiveOSCompletionDoctrine.swift`
- Modify renamed-alias doctrine consumer: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASPostRadicalSweepDoctrine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Modify complete first/final governed envelope 1.0.0 after the value preludes: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeAuditEnvelope.swift`
- Modify exact persistence membrane: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEventLogEntry+TurnEnvelope.swift`
- Modify pinned schema entry: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageCapabilityTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageExecutorTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASParallelStageDispatchExecutorTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRuntimeInternalDelegateTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRuntimeInternalDelegateRoutedTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASKernelRegistryDispatchExecutorTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineHostInjectionTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift`
- Modify pinned schema fixtures: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Reuse Decision (E):** After W5 is green, extend the existing stage plan, native/parallel executors, engine, and audit envelope. `BASTurnRuntimeStagePlan.canonical()` remains byte-stable and becomes a frozen compatibility projection. Traversal stays in the existing engine and stage ledger; bounded loop admission consumes the same injected contracts-owned `BASBudgetLeaseControlPort` whose K3 implementation is supplied by the W2 sovereign slice. No second runner, ledger, coordinator, registry, RSI manager, counter, or loop store is created. This part consumes the already-committed Part-A schema and does not modify its payload layout or registry entry.

**Interfaces:**
- Consumes: the Part-A DAG/invocation/receipt contracts, `BASEBrainTurnRequest`, existing stage/executor/ledger owners, the one Artifact Mesh, one package same-store semantic artifact reopener/decoder value, and the exact same injected K3 composite storage object conforming to EventLog/index/budget/provider-control views. The K3 object—not a decoded tuple or opaque validation closure—supplies the sole `BASBudgetLeaseControlPort`; the logical clock remains caller-injected.
- Produces: `BASTurnRuntimeStagePlan.frozenCompatibilityProjection(of:)`, package-only prepare/authorize/execute values, `BASNativeStageExecutor.executeSemanticInvocation(_:authorizedBudgetUse:request:reopener:executor:)`, `BASParallelStageDispatchExecutor.dispatchSemanticBatch(_:request:reopener:executor:)`, the existing engine's `executeSemanticTopology`, and optional audit-envelope references. It produces no schema owner, loop owner, reopener cache, or second traversal state.

- [ ] **Step 1 [W6]: Add failing projection and existing-executor ownership tests**

In the W6 change to `BASSemanticTurnDAGTests.swift`, add `@testable import BASHostKit` and these tests; they are deliberately absent from the W1 commit:

```swift
func testLegacyPlanIsFrozenProjectionNotTopologyOwner() throws {
    let projected = try BASTurnRuntimeStagePlan.frozenCompatibilityProjection(
        of: .canonical()
    )
    XCTAssertEqual(projected, .canonical())
    XCTAssertEqual(projected.stageCount, 18)
    XCTAssertEqual(projected.stepCount, 16)
}

func testEngineUsesExistingNativeAndParallelExecutors() async throws {
    let counters = SemanticExecutorCounters()
    _ = try await makeEngine(counters: counters).executeSemanticTopology(
        fixtureRequest(),
        dagArtifactID: fixtureArtifactID("dag"),
        dag: .canonical(),
        nodeExecutor: fixtureNodeExecutor(counters: counters)
    )
    let nativeInvocationCount = await counters.nativeInvocationCount
    let parallelBatchCount = await counters.parallelBatchCount
    let secondRunnerCount = await counters.secondRunnerCount
    let secondLedgerCount = await counters.secondLedgerCount
    XCTAssertGreaterThan(nativeInvocationCount, 0)
    XCTAssertGreaterThan(parallelBatchCount, 0)
    XCTAssertEqual(secondRunnerCount, 0)
    XCTAssertEqual(secondLedgerCount, 0)
}

func testConcurrentSameEnvelopeCanSpendBudgetAndExecuteOnlyOnce() async throws {
    let fixture = makeBoundedLoopEngineFixture()
    async let first = fixture.executeSameInvocation()
    async let second = fixture.executeSameInvocation()
    let outcomes = await [first, second]
    let layerCellCalls = await fixture.layerCellCalls.value
    let newlyWonReceiptCount = await fixture.budgetPort.newlyWonReceiptCount
    XCTAssertEqual(outcomes.filter(\.didWinBudgetAndExecute).count, 1)
    XCTAssertEqual(layerCellCalls, 1)
    XCTAssertEqual(newlyWonReceiptCount, 1)
}

func testInvalidProgressOrBudgetStopsBeforeExecutor() async throws {
    for mutation in BASControlLoopRuntimeMutation.allCases {
        let fixture = makeBoundedLoopEngineFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync { _ = try await fixture.execute() }
        let layerCellCalls = await fixture.layerCellCalls.value
        XCTAssertEqual(layerCellCalls, 0)
    }
    // Includes repeated state digest, A↔B back-edge, missing/false typed witness,
    // stale epoch, exhausted depth/branch/use budget, and passed deadline.
}

func testMixedBatchMissingForeignOrExtraBudgetEvidenceStartsNoChild() async throws {
    for mutation in BASControlLoopBatchBudgetMapMutation.allCases {
        let fixture = makeMixedBatchFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync { _ = try await fixture.dispatch() }
        let loopCalls = await fixture.loopMechanismCalls.value
        let nonLoopCalls = await fixture.nonLoopMechanismCalls.value
        XCTAssertEqual(loopCalls, 0)
        XCTAssertEqual(nonLoopCalls, 0)
    }
}

func testPostEffectLoopCanOnlyReconcileAndReplayNeverSpendsAgain() async throws {
    let fixture = makePostEffectLoopFixture()
    XCTAssertThrowsError(try fixture.makeNextInvocation(purpose: .releaseOrEffect))
    let reconciliation = try fixture.makeNextInvocation(purpose: .reconciliationOnly)
    _ = try await fixture.engine.execute(reconciliation)
    let callsBeforeReplay = await fixture.budgetPort.consumeCalls
    try await fixture.replayAndValidateRecordedChain()
    let callsAfterReplay = await fixture.budgetPort.consumeCalls
    let effectDispatchCalls = await fixture.effectDispatchCalls.value
    XCTAssertEqual(callsAfterReplay, callsBeforeReplay)
    XCTAssertEqual(effectDispatchCalls, 0)
}

func testEnvelopeThenInvocationThenBudgetClaimHasNoIdentityCycle() async throws {
    let fixture = makeBoundedLoopEngineFixture()
    _ = try await fixture.execute()
    let events = await fixture.timeline.events
    XCTAssertEqual(
        events,
        [.envelopePut, .invocationPut, .budgetClaim, .budgetReceiptPut,
         .budgetReceiptReopen, .mechanism, .nodeReceiptPut, .nodeReceiptReopen]
    )
    let envelope = try await fixture.reopenEnvelope()
    let invocation = try await fixture.reopenInvocation()
    XCTAssertEqual(envelope.logicalInvocationKey, fixture.logicalInvocationKey)
    XCTAssertNil(envelope.currentInvocationArtifactIDForTestReflection)
    XCTAssertEqual(
        invocation.controlLoopEnvelopeArtifactID,
        fixture.envelopeArtifactID
    )
    XCTAssertEqual(fixture.claimRequest.invocationArtifactID, fixture.invocationArtifactID)
    XCTAssertEqual(fixture.claimRequest.envelopeArtifactID, fixture.envelopeArtifactID)
}

func testFalseConditionalEdgeIsInapplicableAndAlternativeJoinContinues() async throws {
    let fixture = makeConditionalEdgeFixture(
        predecessorDisposition: .noExternalEffect)
    _ = try await fixture.engine.executeSemanticTopology(fixture.request)
    let falseBranchCalls = await fixture.provisionalEffectCalls.value
    let alternativeJoinCalls = await fixture.alternativeJoinCalls.value
    XCTAssertEqual(falseBranchCalls, 0)
    XCTAssertEqual(alternativeJoinCalls, 1)
}

func testSwappedForeignOrMutatedExecutionReceiptUnlocksNoDownstreamNode() async {
    for mutation in SemanticExecutionReceiptMutation.allCases {
        let fixture = makeReceiptBindingFixture(mutation: mutation)
        await XCTAssertThrowsErrorAsync { _ = try await fixture.execute() }
        let downstreamCalls = await fixture.downstreamMechanismCalls.value
        XCTAssertEqual(downstreamCalls, 0)
    }
}
```

- [ ] **Step 2 [W6]: Run wiring RED without editing the Part-A contract**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticTurnDAGTests|BASNativeStageCapabilityTests'
```

Expected: compile/test failure because the HostKit frozen projection and typed executor/engine wiring do not yet exist. `git diff` shows no W6 edit to `BASSemanticTurnDAG.swift` or its registry entry.

- [ ] **Step 3 [W6]: Extend the current stage plan, native executor, parallel executor, engine, and audit envelope**

Add the frozen projection to `BASTurnRuntimeStagePlan.swift`:

```swift
extension BASTurnRuntimeStagePlan {
    public static func frozenCompatibilityProjection(
        of dag: BASSemanticTurnDAG
    ) throws -> BASTurnRuntimeStagePlan {
        try dag.validateCanonical()
        return .canonical()
    }
}
```

Add semantic dispatch to `BASNativeStageExecutor` without adding state:

```swift
package struct SemanticPreparedInvocation: Sendable {
    package let invocation: BASSemanticNodeInvocation
    package let invocationArtifactID: BASArtifactID
    fileprivate init(
        invocation: BASSemanticNodeInvocation,
        invocationArtifactID: BASArtifactID
    ) {
        self.invocation = invocation
        self.invocationArtifactID = invocationArtifactID
    }
}

package struct SemanticAuthorizedBudgetUse: Sendable {
    package let request: BASBudgetUseRequest
    package let receipt: BASBudgetUseReceipt
    package let receiptArtifactID: BASArtifactID
    fileprivate init(
        request: BASBudgetUseRequest,
        receipt: BASBudgetUseReceipt,
        receiptArtifactID: BASArtifactID
    ) {
        self.request = request
        self.receipt = receipt
        self.receiptArtifactID = receiptArtifactID
    }
}

package struct SemanticNodeExecution: Sendable {
    package let preparedInvocation: SemanticPreparedInvocation
    package let receipt: BASSemanticNodeReceipt
    package let receiptArtifactID: BASArtifactID
    fileprivate init(
        preparedInvocation: SemanticPreparedInvocation,
        receipt: BASSemanticNodeReceipt,
        receiptArtifactID: BASArtifactID
    ) {
        self.preparedInvocation = preparedInvocation
        self.receipt = receipt
        self.receiptArtifactID = receiptArtifactID
    }
}

package enum SemanticBudgetExecutionContext: Sendable {
    case authoritative(any BASK3ControlNucleusStorage)
    case shadowNoBudgetAuthority
}

package typealias SemanticNodeExecutor = @Sendable (
    SemanticPreparedInvocation,
    SemanticAuthorizedBudgetUse?,
    BASEBrainTurnRequest
) async throws -> SemanticNodeExecution

package func executeSemanticInvocation(
    _ invocation: BASSemanticNodeInvocation,
    request: BASEBrainTurnRequest,
    reopener: BASSemanticArtifactReopener,
    budgetContext: SemanticBudgetExecutionContext,
    executor: @escaping SemanticNodeExecutor
) async throws -> SemanticNodeExecution {
    guard case .authoritative = budgetContext else {
        throw BASSemanticArtifactReopenError.shadowExecutionForbidden
    }
    try await reopener.preflightSelfIDFreeEnvelope(for: invocation)
    let prepared = try await reopener.putAndReopenInvocation(invocation)
    let authorized = try await reopener.claimPutAndReopenBudgetUseIfNeeded(
        for: prepared,
        budgetContext: budgetContext
    )
    return try await executePreparedSemanticInvocation(
        prepared,
        authorizedBudgetUse: authorized,
        request: request,
        reopener: reopener,
        executor: executor
    )
}

package func executePreparedSemanticInvocation(
    _ prepared: SemanticPreparedInvocation,
    authorizedBudgetUse: SemanticAuthorizedBudgetUse?,
    request: BASEBrainTurnRequest,
    reopener: BASSemanticArtifactReopener,
    executor: @escaping SemanticNodeExecutor
) async throws -> SemanticNodeExecution {
    try await reopener.validatePreparedInvocationAndNewlyWonBudgetUse(
        prepared,
        authorizedBudgetUse: authorizedBudgetUse
    )
    let returned = try await executor(prepared, authorizedBudgetUse, request)
    return try await reopener.reopenAndValidateExecution(
        returned,
        expectedPreparedInvocation: prepared,
        expectedAuthorizedBudgetUse: authorizedBudgetUse
    )
}
```

At the same time, rename the existing `StageExecutor` and `RoutedStageExecutor` aliases to `ShadowStageExecutor` and `ShadowRoutedStageExecutor`. Their `executeStage`/`executePlan`/routed entrypoints require an explicit `executionClass: .shadowObservation`; passing `.authoritative` throws before the closure runs:

```swift
public enum NativeExecutionClass: Sendable, Equatable {
    case shadowObservation
    case authoritative
}

public enum NativeCapability: Sendable, Equatable {
    case nativeAnyShadowOnly
}

public enum NativeExecutionError: Error, Sendable, Equatable {
    case capabilityDenied(NativeCapability)
}

// Retained Any-erased compatibility entry; authoritative always throws
// before invoking executor.
public func executeStage(
    _ stage: BASTurnRuntimeStage,
    request: BASEBrainTurnRequest,
    executionClass: NativeExecutionClass,
    executor: @escaping ShadowStageExecutor
) async throws -> BASTurnRuntimeStageRecord
```

`BASSemanticArtifactReopener` is a package value implemented in `BASNativeStageExecutor.swift`, deliberately colocated with `SemanticPreparedInvocation`, `SemanticAuthorizedBudgetUse`, and `SemanticNodeExecution`, whose constructing initializers remain `fileprivate`. The reopener holds the exact class-bound Artifact Store and pure bounded decoders for invocation, node receipt, `BASControlLoopEnvelopePayload`, `BASBudgetUseReceipt`, `BASControlLoopProgressWitnessPayload`, and `BASControlLoopTerminalReceiptPayload`; it has no cache or mutable state. Its package initializer is called once by production composition from the identical `artifactStore` held by authoritative dependencies. Add nested package `ReadOnlyView` with a `fileprivate` initializer/token and only exact `reopenDAG`, `reopenInvocation`, `reopenOutput`, and `reopenNodeReceipt` methods; it exposes no store existential, put/head/CAS/attestation/budget method, raw record, or decoder closure. `BASSemanticArtifactReopener.readOnlyView` returns that projection only after stable object-identity comparison with the accepted store. Task 2 receives this view, never the full store/reopener. The class-bound package `BASK3ControlNucleusStorage` composition is the identical injected actor that provides EventLog/budget/provider control; production uses the one concrete `BASSQLiteEventLogStorage`. Cross-file construction of the fileprivate wrappers must fail to compile; a second-but-equivalent store/K3 actor must fail the identity fixture before any read, claim, or mechanism. No decoded tuple or caller-supplied validation closure can authorize execution.

The exact order is immutable: ordinary-put/reopen a self-ID-free envelope first; ordinary-put/reopen the invocation referencing that envelope ID second; submit one `BASBudgetUseRequest` that exact-binds `invocationArtifactID + envelopeArtifactID` third; only a newly won K3 outcome is ordinary-put/reopened into `SemanticAuthorizedBudgetUse`; then call the mechanism; finally ordinary-put/reopen the node/terminal receipt. The envelope's bounded deterministic `logicalInvocationKey`, optional parent invocation Artifact ID, prior-use/witness lineage, root/ring/lease/epochs/digest/depth/branch/deadline facts are canonical-byte-checked, and it contains no current invocation Artifact ID. Placeholder IDs, self-reference, backfill, or mutation are impossible. Exact replay, already-consumed, recovered-without-fresh-win, denied, terminal, and indeterminate claim outcomes are non-callable.

The typed prepared/authorized/execution values have `fileprivate` initializers in `BASNativeStageExecutor.swift`; the package executor and dispatcher can consume but not fabricate them. `reopenAndValidateExecution` reads `receiptArtifactID` from the same store, bounded-decodes and canonical-byte-compares the returned body, and exact-checks receipt root/node against the prepared invocation, `receipt.invocationArtifactID == prepared.invocationArtifactID`, ordered parent/input IDs, exact budget-use ID or nil, loop-terminal ID/binding or nil, and output/capability/effect/state bindings. A swapped, foreign, stale, same-ID/different-body, or correctly typed receipt for another invocation cannot enter the completed set or unlock a child. Update every retained native-stage/internal-delegate/kernel-registry call to pass explicit `.shadowObservation`; there is no silent default or deprecated authoritative alias. The production scanner rejects `ShadowStageExecutor`, `ShadowRoutedStageExecutor`, `executeStage`, `executePlan`, or routed compatibility calls from authoritative engine/configuration/host/app files.

Add canonical ready-batch fan-out to `BASParallelStageDispatchExecutor`:

```swift
package func dispatchSemanticBatch(
    _ invocations: [BASSemanticNodeInvocation],
    request: BASEBrainTurnRequest,
    reopener: BASSemanticArtifactReopener,
    budgetContext: BASNativeStageExecutor.SemanticBudgetExecutionContext,
    semanticInvocationExecutor: BASNativeStageExecutor,
    executor: @escaping BASNativeStageExecutor.SemanticNodeExecutor
) async throws -> [BASNativeStageExecutor.SemanticNodeExecution] {
    let ordered = invocations.sorted {
        $0.nodeID.rawValue.utf8.lexicographicallyPrecedes($1.nodeID.rawValue.utf8)
    }
    for invocation in ordered {
        try await reopener.preflightSelfIDFreeEnvelope(for: invocation)
    }
    var prepared: [BASNativeStageExecutor.SemanticPreparedInvocation] = []
    for invocation in ordered {
        prepared.append(try await reopener.putAndReopenInvocation(invocation))
    }
    var authorized: [BASArtifactID:
        BASNativeStageExecutor.SemanticAuthorizedBudgetUse] = [:]
    for item in prepared {
        if let use = try await reopener.claimPutAndReopenBudgetUseIfNeeded(
            for: item,
            budgetContext: budgetContext
        ) {
            guard authorized.updateValue(
                use,
                forKey: item.invocationArtifactID
            ) == nil else {
                throw BASSemanticTurnDAGError.controlLoopBudgetEvidenceMismatch
            }
        }
    }
    for item in prepared {
        try await reopener.validatePreparedInvocationAndNewlyWonBudgetUse(
            item,
            authorizedBudgetUse: authorized[item.invocationArtifactID]
        )
    }
    return try await withThrowingTaskGroup(
        of: BASNativeStageExecutor.SemanticNodeExecution.self
    ) { group in
        for item in prepared {
            group.addTask {
                try await semanticInvocationExecutor.executePreparedSemanticInvocation(
                    item,
                    authorizedBudgetUse: authorized[item.invocationArtifactID],
                    request: request,
                    reopener: reopener,
                    executor: executor
                )
            }
        }
        var executions: [BASNativeStageExecutor.SemanticNodeExecution] = []
        for try await execution in group { executions.append(execution) }
        return executions.sorted {
            $0.preparedInvocation.invocation.nodeID.rawValue.utf8.lexicographicallyPrecedes(
                $1.preparedInvocation.invocation.nodeID.rawValue.utf8
            )
        }
    }
}
```

Add actor-isolated `executeSemanticTopology(_:dagArtifactID:dag:nodeExecutor:) async throws -> [BASNativeStageExecutor.SemanticNodeExecution]` to `BASTurnRuntimeEngine`. It validates the DAG and maintains only a transient authoritative-ready set whose members have same-store-reopened `.completed` receipts or a reopened `BASControlLoopTerminalReceiptPayload` proving `convergedVerified`. For each candidate batch it reopens typed predecessor invocation/receipt bodies, derives exact `BASSemanticEdgeApplicabilityEvidence` from sole-owner facts (`effectRequested`, `noExternalEffect`, verified/refused/deferred/reconcile outcomes), and calls the one package `dag.readiness(reopenedNodeEvidence:conditionEvidence:)` API. `false` means **inapplicable**, not incomplete. Tests pin no-effect/provisional-false branches at zero calls, applicable alternative joins continuing, and missing/swapped/foreign condition evidence failing before dispatch.

The engine ordinary-puts/reopens each optional loop envelope first, then constructs each invocation's ordered parent list from exact reopened predecessor receipt Artifact IDs. The native/parallel wrappers—not the LayerCell closure—put/reopen the invocation and acquire budget before the closure can run. It uses `BASNativeStageExecutor` for one-node batches and `BASParallelStageDispatchExecutor` for multi-node batches, accepts only post-execution receipts that the same-store reopener exact-validates, and propagates cancellation. A `.remanded` receipt does not enter the completed set: it may dynamically enqueue exactly one new concrete invocation only after ordinary-put/reopening a new self-ID-free envelope that references the immediate prior invocation/node/use receipts, advances depth, carries a new state digest, and names a true typed progress witness, then wins the next budget use. `.degraded`, indeterminate, no-progress, repeated/A↔B digest, exhausted/deadline/depth/branch, refused, deferred, cancelled, reconcile-required, and failed-closed outcomes remain proposal-only terminal and cannot unlock an authoritative downstream ready edge. Task 2's injected closure receives an already prepared invocation plus optional unforgeable newly-won budget evidence, calls one prerequisite `BASLayerCell.process`, ordinary-puts the receipt, and returns it; it never puts or backfills the invocation. The engine may hold a transient execution array, condition-evidence projection, and dynamic-remand queue during one actor turn; it cannot persist a second ledger or mutate canonical DAG edges.

After the mandatory Task-2 value prelude has declared `BASSemanticShadowObservation` and the Semantic Task-8 audit-value prelude has frozen its separate governed bundle, make `BASTurnRuntimeAuditEnvelope` the one governed EventLog parent in place. Task 1B declares its complete first-governed and final 1.0.0 wire **once**: `schemaVersion` first; existing `phase`, `turnID`, `sessionID`, `timestampMs`, engine-local `sequenceNumber`, and `payloadJson`; then `semanticDAGArtifactID: BASArtifactID?`, `orderedSemanticNodeReceiptArtifactIDs: [BASArtifactID]`, `legacyStagePlanWasFrozenProjection: Bool`, `semanticShadowObservation: BASSemanticShadowObservation?`, `runtimeAuditProjectionsBundleArtifactID: BASArtifactID?`, `authoritativeResultArtifactID: BASArtifactID?`, `replayManifestArtifactID: BASArtifactID?`, `publicationCapabilityUseReceiptArtifactID: BASArtifactID?`, and `publicationSinkReceiptArtifactID: BASArtifactID?`. The one explicit public initializer begins `schemaVersion: String = Self.currentSchemaVersion`; to preserve every existing external labeled call, every appended argument has its own source-compatible default: `semanticDAGArtifactID = nil`, `orderedSemanticNodeReceiptArtifactIDs = []`, `legacyStagePlanWasFrozenProjection = false`, `semanticShadowObservation = nil`, `runtimeAuditProjectionsBundleArtifactID = nil`, `authoritativeResultArtifactID = nil`, `replayManifestArtifactID = nil`, `publicationCapabilityUseReceiptArtifactID = nil`, and `publicationSinkReceiptArtifactID = nil`. Start/complete factories delegate to that initializer rather than introducing another shape. The parent retains its existing `Hashable` conformance and has no self Artifact ID/digest/signature. Tasks 2 and 5 and Semantic Task 8 only populate these predeclared fields; they never change 1.0.0, add a migration, or edit the registry shape.

In `BASTurnRuntimeEngine.swift`, declare the one package transport consumed by both pre-cutover coordinator composition and post-cutover engine composition:

```swift
package struct BASSameRunAuditOutcome: Sendable {
    package let result: BASEBrainTurnResult
    package let auditProjections: BASRuntimeAuditProjectionsBundle

    package init(
        result: BASEBrainTurnResult,
        auditProjections: BASRuntimeAuditProjectionsBundle
    ) {
        self.result = result
        self.auditProjections = auditProjections
    }
}
```

This is an unpersisted two-field transport, not a result/schema/store owner. It has no Artifact ID, receipt, store, callback, mutable reference, or caller-injected initializer in public API. Semantic Task 8 factors the existing ordered prefix and suffix stage functions: synchronous public `runTurn` executes the legacy-only chain once and returns its result, while package async `runTurnWithAuditOutcome` executes the same prefix once, awaits R0–R6 at the existing memory/risk seam before any suffix stage, executes that suffix once, and returns the outcome. It must not run a complete synchronous core and then perform post-result shadow work. Runtime integration consumes that exact same-run value once. Task 7 then makes the authoritative engine construct the same type from its own typed stage/result evidence and removes the coordinator call without removing bundle production. A source gate requires exactly one declaration, rejects `lastAudit`/bundle sinks/caches, caller `auditProjections:` flow into authority, and any second execution used to obtain it.

`BASRuntimeAuditProjectionsBundle` is not embedded. Semantic Task 8's package coordinator outcome returns the same public `BASEBrainTurnResult` plus one immutable self-ID-free bundle **value**, never an Artifact ID and never a store receipt. The sole engine/audit-envelope owner canonicalizes that exact same-run value through `BASGovernedArtifactPayloadCodec`, ordinary-puts it once under the exact Attempt/turn root, takes the ID only from the put receipt, reopens it through the same class-bound `BASArtifactStorePort`, current-decodes and byte/equality-checks it, and only then sets `runtimeAuditProjectionsBundleArtifactID`. A coordinator has no store and cannot put, guess, cache, or return the ID. A crash before the envelope append may leave a harmless orphan bundle for ordinary Artifact GC. A publishable/final `.complete` envelope requires the reopened ID; typed early/failure phases may keep it nil only when their phase contract makes the semantic audit projection unavailable.

The engine's actor-private audit-bundle identity factory accepts only active typed root/Attempt evidence and the outcome value; it accepts no caller-selected provenance, epoch, or time. It computes `canonicalPayloadBytes` exactly once with `BASGovernedArtifactPayloadCodec.canonicalBytes(for: outcome.auditProjections)` and sets `payloadLength` to the checked exact `UInt64(canonicalPayloadBytes.count)`. It creates `BASArtifactIdentityCore` with those exact bytes/length, canonicalization version `bas-governed-artifact-payload-v1`, schema ID `bas.runtime-audit-projections-bundle`, schema version 1.0.0, kind `runtime-audit-projections-bundle`, parent `[turnOperationRefArtifactID]`, producer layer `.sovereign`, exact `.attempt(attemptRefArtifactID)` scope, the already-validated logical epoch/time captured from the same engine/K3 run rather than wall clock or caller input, confidentiality `runtime-audit-confidential`, `provenanceArtifactIDs: []`, nil snapshot root, and no head update. The unique parent lineage and typed references inside the governed payload are the complete provenance; the factory cannot accept or reorder another vector. The Attempt artifact must resolve to the exact `BASTurnOperationRef`. Put and reopen repeat the canonical-bytes, checked-length, and every identity/payload comparison; foreign parent/root/scope/Attempt/epoch/logical-time/producer (including any producer other than exact `.sovereign`)/kind/provenance or same bytes under another store fail before the envelope field is set.

Fix the actual persistence membrane in `BASEventLogEntry+TurnEnvelope.swift`: current rows set `payloadJson` to the exact marker `bas.turn-runtime-audit-envelope.v1:` followed by canonical Base64 of `BASGovernedArtifactPayloadCodec.canonicalBytes(for: envelope)`. Because codec encode/decode can fail, replace the nonthrowing factory with `BASEventLogEntry.init(validatingTurnEnvelope:eventID:source:) throws`; it writes indexed timestamp/session/turn/action columns, decodes the just-built governed bytes, and equality-checks those columns against the envelope. `turnRuntimeAuditEnvelope()` is likewise throwing: it requires the exact `.substrateAudit` kind/action/marker, Base64-decodes the suffix once, then requires `decodedData.base64EncodedString() == markerSuffix` before `decodeCurrent`. That equality pins standard padded Base64 and rejects whitespace, alternate pad bits, omitted/extra padding, or every other textual spelling of the same bytes; add an alternate-encoding rejection test. It then equality-checks the duplicated indexed columns before returning the whole parent. The low-level `appendTurnEnvelope` becomes `async throws`, records an optional diagnostic on failure, then rethrows; there is no `try!`, `try?`, silent fallback, or fire-and-forget authoritative append. The public `BASTurnRuntimeEngine.runTurn` remains deliberately nonthrowing: its call site catches that typed append error into the existing `BASAuditEmissionFailureLog`, returns the already-owned single `BASEBrainTurnResult` without synthesizing another result, and marks the run ineligible for replay/certification/audit-complete claims. A live in-memory owner may retry only the identical governed append bytes; after process loss the unreferenced bundle is GC-eligible, sovereign recovery resolves only publication state, and the turn remains permanently audit-incomplete/non-certifiable—no semantic rerun, bundle reconstruction, or sink republish is allowed. EventLog append assigns and may overwrite the row's own `sequenceNumber`/HWM`; that row sequence is intentionally **not** equal to, copied into, or compared with the envelope's engine-local `sequenceNumber`, which survives only inside governed bytes. Interleaved non-envelope EventLog rows must make the two sequences diverge while envelope round-trip/replay remains exact. The membrane never persists only the old summary string, so DAG/receipt/shadow/bundle/result/publication fields cannot be dropped.

Historical rows are explicitly unversioned. Add one private bounded `LegacyTurnRuntimeAuditEnvelopeV0` membrane in the same factory file that recognizes only the old exact `.substrateAudit` action plus marker-absent column/summary shape, projects absent later fields to nil/empty/frozen-false, and is callable only by the historical diagnostic audit-reader path. It is not `BASSchemaVersioned`, not registered, never enters Artifact identity/ordinary put, never accepts a current marker with missing schema, and cannot authorize semantic execution, result evidence, replay, or publication. Current missing/future governed rows fail rather than falling back to this membrane. Source tests allow the legacy type/decoder only in `BASEventLogEntry+TurnEnvelope.swift` and prove new writes always use the governed marker.

Register `BASTurnRuntimeAuditEnvelope` once through the Contracts-approved cycle-safe pinned entry because BASAdmin cannot import BASHostKit. Its current version is first-governed 1.0.0 and its exact IDs remain `schema.BASTurnRuntimeAuditEnvelope.current`, `schema.BASTurnRuntimeAuditEnvelope.backward_v1`, and `schema.BASTurnRuntimeAuditEnvelope.future_rejection`; `backward_v1` pins the first/current v1 wire fixture and performs no fictitious backward migration. Tests cover full current codec/marker round-trip, first-v1 fixture equality, missing/future rejection, private unversioned legacy read-only projection, indexed-column mismatch, interleaved-row row-sequence/envelope-sequence divergence, every optional final field, exact-one entry/test IDs, owner-version parity, cross-target public-default construction, and no second helper/store. The existing `BASTurnRuntimeAuditEmissionSummary.from(result:auditProjections:permitEscalationLedger:stageLedger:stagePlan:)` receives the exact reopened full bundle through `auditProjections:`; its summary and `populatedSlotCount` are derived/equality-checked projections only. Neither is persisted authority and neither may reconstruct or replace the bundle. Do not add an audit store.

Before an invocation with nonnil `controlLoopEnvelopeArtifactID` is prepared, the engine/reopener must ordinary-reopen and canonical-byte-validate that exact self-ID-free `BASControlLoopEnvelopePayload`, its prior `BASBudgetUseReceipt` (when non-root), its typed `BASControlLoopProgressWitnessPayload` (when non-root), the exact parent invocation, and prior node/terminal receipt chain. Exact-check logical invocation key, operation/Attempt/ring/lease IDs, lease and policy epoch, parent invocation/receipt, strictly increasing depth, branch count, monotonic deadline, state digest lineage, and purpose. The witness is a typed structural delta whose predicates must evaluate true against reopened prior/current state; prose such as “improved” is not evidence. Reject a repeated digest, any A→B→A digest back-edge, missing/false witness, stale epoch, depth/branch/deadline/use exhaustion, or a child that does not reference the immediately prior invocation/use receipt. After external effect may have occurred, only a `.reconciliationOnly` envelope is legal and it receives no release/effect port.

Only after every batch member's envelope/parent/witness/prepared invocation validates may the engine call the budget view on the same injected `BASK3ControlNucleusStorage` once per loop member in canonical order for that exact envelope/invocation/lease/use ordinal. A newly won `BASBudgetUseReceipt` is ordinary-put, reopened, equality-checked against both K3 state and the request, and wrapped in `SemanticAuthorizedBudgetUse`; exact replay/already-consumed/recovered/denied/terminal outcomes are non-callable. The node receipt must store that exact `budgetUseReceiptArtifactID`. The parallel executor completes all envelope preflight, all invocation puts/reopens, and all budget authorization/validation before creating its task group, so missing/foreign/extra/duplicate evidence or a member mismatch starts zero mechanisms. Intermediate/remanded loop receipts and outputs are proposal-only: the engine can create a next concrete DAG invocation only from the prior invocation/node/use receipts plus a newly stored true progress witness. Only a same-store-reopened `BASControlLoopTerminalReceiptPayload` proving `convergedVerified` may satisfy an authoritative downstream DAG edge/result/state-commit input. Replay reopens and validates envelope → parent invocation/receipt → prior/current use receipt → witness → terminal receipt without calling the budget port or LayerCell. This is a dynamic artifact chain over concrete DAG invocations, never a topology back-edge or fifth control ring.

Delete any proposed `BASNativeSemanticDAGRunner.swift`, `BASSemanticDAGRunner`, `BASSemanticDAGLedger`, or semantic coordinator reference. The engine remains the one traversal owner, and the 18-stage plan remains unchanged byte-for-byte.

- [ ] **Step 4 [W6]: Run GREEN, retained executor/ledger regressions, and anti-duplication scan**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticTurnDAGTests|BASTurnRuntimeStagePlanTests|BASTurnRuntimeStagePlanValidationTests|BASNativeStageExecutorTests|BASNativeStageCapabilityTests|BASParallelStageDispatchExecutorTests|BASTurnRuntimeStageLedgerTests|BASTurnRuntimePlanLedgerCoherenceTests|BASTurnRuntimeEngineTests|BASTurnRuntimeEngineConfigurationTests|BASRuntimeInternalDelegateTests|BASRuntimeInternalDelegateRoutedTests|BASKernelRegistryDispatchExecutorTests|BASTurnRuntimeEngineHostInjectionTests|BASEBrainSchemaGovernanceRegistryTests'
if rg -n 'actor BASNativeSemanticDAGRunner|actor BASSemanticDAGRunner|struct BASSemanticDAGLedger|class BASSemanticDAGCoordinator' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources; then
  exit 1
fi
```

Expected: all selected tests PASS with 0 failures; the inverted ownership scan prints no match and exits successfully.

- [ ] **Step 5 [W6]: Commit runtime wiring separately**

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeStagePlan.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASParallelStageDispatchExecutor.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASRuntimeInternalDelegate.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASKernelRegistryDispatchExecutor.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageDispatchLedger.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASCognitiveOSCompletionDoctrine.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASPostRadicalSweepDoctrine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeAuditEnvelope.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASEventLogEntry+TurnEnvelope.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageCapabilityTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageExecutorTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASParallelStageDispatchExecutorTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRuntimeInternalDelegateTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRuntimeInternalDelegateRoutedTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASKernelRegistryDispatchExecutorTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineHostInjectionTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git diff --cached --check
git commit -m "feat: add semantic topology to existing turn engine"
```

### Task 2 [W6]: Immutable-Evidence Observation-Only Shadow Parity

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Modify in the mandatory W6 contract-only prelude, before Task 1B: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeAuditEnvelope.swift` (declare only `BASSemanticShadowObservation` and its nested enums; Task 1B later freezes the envelope)
- Verify without modifying in Task 2 behavior: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEventLogEntry+TurnEnvelope.swift`
- Verify without modifying in Task 2 behavior: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticDAGShadowParityTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift`
- Verify Task-1B pinned envelope fixtures without modifying schema expectations: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Reuse Decision (A + E):** Full-result canonicalization and parity already belong to `BASEBrainTurnResultReplayHarness`; extend it instead of creating a shadow comparator. The shadow reuses the baseline result's already persisted immutable receipt/output artifacts through the Task 1 same-store reopener. It does **not** reuse or invoke `BASLayerCell`, `BASLayerActorMechanismAdapter`, Provider, effect, state, lease, K3/K4, Zone-C, tool, network, or filesystem mechanisms: doing so after the baseline would create a second unclaimed physical execution. Add one explicit shadow enum case and exhaustive engine branch. The value-only prelude declares the unregistered observation before Task 1B; Task 1B then embeds it in the complete first-governed envelope 1.0.0. Task 2 behavior only populates that frozen optional field and cannot modify the envelope schema, codec, mapping, registry, or version. Add no runtime memory helper/type/file/map, executor, protocol, router, or store.

**Interfaces:**
- Consumes: the baseline `BASEBrainTurnResult`, `BASSemanticTurnDAG`, the exact Task 1 `BASSemanticArtifactReopener` and Artifact Mesh identity, immutable baseline-owned semantic receipt/output references, the existing runtime-audit append path, and `BASEBrainTurnResultReplayCanonicalizer`. It consumes no executor, budget port, Provider port, process ledger, effect/state/release/tool port, network handle, or mutable-filesystem handle.
- Produces: the prelude receipt for `BASSemanticShadowObservation`, then `.semanticDAGShadow`, package `BASSemanticBaselineEvidence` and `BASSemanticShadowDependencies`, `BASTurnRuntimeEngineConfiguration.observationOnlySemanticDAGShadow(dependencies:)`, `BASEBrainTurnResultReplayHarness.semanticDAGShadowParityVerdict(requests:baseline:shadow:)`, and one exhaustive engine branch that returns the current baseline `BASEBrainTurnResult` unchanged. The shadow is a pure replay projection over the exact same run's baseline-owned immutable artifacts; it never schedules a LayerCell mechanism.

- [ ] **Prelude [must commit before Task 1B]: Declare the final unregistered observation value only**

Add `import BASRuntimeCore`, then add `BASSemanticShadowUnavailableReason`, `BASSemanticShadowProjectionDisposition`, and `BASSemanticShadowObservation` in `BASTurnRuntimeAuditEnvelope.swift` with the exact fields shown in Step 3 and one explicit public initializer in displayed-field order. This prelude does not edit `BASTurnRuntimeAuditEnvelope`, its factories, the EventLog mapping, codec, or registry, and performs no ordinary put or behavior wiring. Run a compile fixture, commit only that source file with message `feat: declare semantic shadow audit value`, and record the receipt consumed by Task 1B. A source gate proves the observation has no `schemaVersion`, Artifact identity, standalone put/reopen, registry entry, or mutable owner.

`BASTurnRuntimeAuditEnvelope` retains its existing `Hashable` conformance and ABI; all three newly nested observation value types therefore conform to `Hashable` in this prelude.

```swift
public enum BASSemanticShadowUnavailableReason: String, Codable, Sendable, Equatable, Hashable {
    case incompleteBaselineEvidence
    case capabilityBearingNode
    case evidenceBindingMismatch
}

public enum BASSemanticShadowProjectionDisposition: Codable, Sendable, Equatable, Hashable {
    case complete
    case unavailable(BASSemanticShadowUnavailableReason)
}

public struct BASSemanticShadowObservation: Codable, Sendable, Equatable, Hashable {
    public let semanticDAGArtifactID: BASArtifactID
    public let orderedReopenedBaselineNodeReceiptArtifactIDs: [BASArtifactID]
    public let baselineCanonicalDigest: String
    public let shadowCanonicalDigest: String
    public let disposition: BASSemanticShadowProjectionDisposition

    public init(
        semanticDAGArtifactID: BASArtifactID,
        orderedReopenedBaselineNodeReceiptArtifactIDs: [BASArtifactID],
        baselineCanonicalDigest: String,
        shadowCanonicalDigest: String,
        disposition: BASSemanticShadowProjectionDisposition
    ) {
        self.semanticDAGArtifactID = semanticDAGArtifactID
        self.orderedReopenedBaselineNodeReceiptArtifactIDs =
            orderedReopenedBaselineNodeReceiptArtifactIDs
        self.baselineCanonicalDigest = baselineCanonicalDigest
        self.shadowCanonicalDigest = shadowCanonicalDigest
        self.disposition = disposition
    }
}
```

- [ ] **Step 1: Write failing shadow inertness, one-adapter, full-result parity, and mode ABI tests**

```swift
import XCTest
@testable import BASHostKit

final class BASSemanticDAGShadowParityTests: XCTestCase {
    func testShadowReturnsBaselineResultAndCannotMutateAuthorities() async throws {
        let fixture = makeShadowFixture()
        let baseline = fixture.recordedBaselineResult
        let shadow = await fixture.shadowEngine.runTurn(fixture.request)
        XCTAssertEqual(
            BASEBrainTurnResultReplayCanonicalizer.canonicalized(shadow),
            BASEBrainTurnResultReplayCanonicalizer.canonicalized(baseline)
        )
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.layerCellProcessCount, 1)
        XCTAssertEqual(counts.layerActorMechanismAdapterInvokeCount, 1)
        XCTAssertEqual(counts.k4MutationCount, 0)
        XCTAssertEqual(counts.releaseCount, 0)
        XCTAssertEqual(counts.effectDispatchCount, 0)
        XCTAssertEqual(counts.visibleStateActivationCount, 0)
        XCTAssertEqual(counts.fallbackSelectionCount, 0)
        XCTAssertEqual(counts.incrementalProviderPhysicalCallCount, 0)
        XCTAssertEqual(counts.incrementalK3CallCount, 0)
        XCTAssertEqual(counts.incrementalNonAuditArtifactMutationCount, 0)
        XCTAssertEqual(counts.governedRuntimeAuditStartAppendCount, 1)
        XCTAssertEqual(counts.governedRuntimeAuditCompleteAppendCount, 1)
        XCTAssertEqual(counts.totalGovernedRuntimeAuditEnvelopeAppendCount, 2)
        XCTAssertEqual(counts.incrementalNetworkCallCount, 0)
        XCTAssertEqual(counts.incrementalMutableFilesystemCallCount, 0)
    }

    func testReplayHarnessComparesWholeResultAndTypedShadowObservation() async {
        let verdict = await BASEBrainTurnResultReplayHarness.semanticDAGShadowParityVerdict(
            requests: canonicalRequests(),
            baseline: baselineRun,
            shadow: shadowRun
        )
        XCTAssertTrue(verdict.fullResultParity)
        XCTAssertTrue(verdict.projectionEvidenceComplete)
        XCTAssertEqual(verdict.divergingRequestIndex, nil)
    }

    func testRuntimeModeRawValuesRemainStableWhenShadowIsAdded() {
        XCTAssertEqual(BASTurnRuntimeMode.v1ByteEqual.rawValue, "v1-byte-equal")
        XCTAssertEqual(BASTurnRuntimeMode.nativeV2.rawValue, "native-v2")
        XCTAssertEqual(BASTurnRuntimeMode.stressSweepDual.rawValue, "stress-sweep-dual")
        XCTAssertEqual(BASTurnRuntimeMode.semanticDAGShadow.rawValue, "semantic-dag-shadow")
        XCTAssertEqual(BASTurnRuntimeMode.allCases.count, 4)
        XCTAssertNil(BASTurnRuntimeMode(rawValue: "semantic-dag-authoritative"))
    }

    func testEveryModeUsesOneExplicitEngineBranch() async {
        for mode in BASTurnRuntimeMode.allCases {
            let counters = await runWithPathCounters(mode: mode)
            XCTAssertEqual(counters.selectedBranchCount, 1)
            XCTAssertEqual(counters.authoritativeSemanticCoordinatorCount, 0)
        }
    }
}
```

In the same class add `testShadowReopensOnlyBaselineOwnedArtifactsFromAcceptedStore`, `testShadowWithProviderOrEffectNodeReturnsUnavailableBeforeMechanism`, `testShadowLoopReturnsUnavailableBeforeInvocationOrBudgetPut`, and `testBaselinePlusShadowAddsZeroPhysicalCapabilityCalls`. Include foreign-store, missing/extra/swapped receipt, same-ID/different-body, wrong DAG/root/node/edge, and baseline-chain omission mutations. Assert the normal paired lifecycle—exactly one governed `.start` and exactly one governed `.complete`, two total—and that only the final `.complete` contains the nested observation. The unpersisted provisional complete value must never appear in EventLog. Assert no standalone shadow Artifact/schema and no invocation/output/receipt, authority head, CAS, state, effect, release, Provider, tool, network, or mutable-filesystem value changes. Compare whole-process owner counters against a baseline-only run so the shadow cannot hide a second Provider call behind an observation field.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticDAGShadowParityTests|BASEBrainTurnResultReplayHarnessTests|BASTurnRuntimeModeTests'
```

Expected: FAIL at compile time because `.semanticDAGShadow`, `BASSemanticShadowObservation`, and `semanticDAGShadowParityVerdict` do not exist.

- [ ] **Step 3: Populate the frozen observation field and extend the replay harness**

Consume and populate the exact observation value already declared and committed by the prelude; Task-2 behavior contains no enum/struct reference copy and must not redeclare or edit that type. The prelude already gave the observation one explicit public initializer in displayed-field order and `Hashable` conformance for the existing envelope's synthesized `Hashable` ABI, plus no `schemaVersion`, Artifact identity, ordinary put, or registry entry. Task 1B already froze optional `semanticShadowObservation: BASSemanticShadowObservation? = nil` inside the complete first-governed envelope 1.0.0 and retains the envelope's existing `Hashable` conformance. Task 2 now only constructs that value and supplies it to the existing final `.complete` factory. It performs no envelope declaration, 1.1.0 bump, migration, codec branch, mapping edit, or registry edit. The cycle-safe entry remains first/current 1.0.0 with the same three test IDs; the private unversioned diagnostic membrane remains read-only and cannot consume a marked governed row.

The append order is exact. After the ordinary baseline result and receipts exist, construct one **unpersisted provisional `.complete` value** solely so the replay harness can validate same-run root/DAG/result/receipt evidence and compute `BASSemanticShadowObservation`. Then discard that provisional value, construct one final `.complete` with the observation, and call the throwing governed append exactly once. Along with the normal one `.start`, phase counts are `.start == 1`, `.complete == 1`, total governed envelopes `== 2`. No nil-observation provisional complete is appended. The nonthrowing engine catches a typed append failure only into the existing audit-failure channel, returns the same baseline result, and leaves replay/certification red.

Extend `BASEBrainTurnResultReplayHarness` in place:

```swift
extension BASEBrainTurnResultReplayHarness {
    public struct SemanticShadowParityVerdict: Sendable, Equatable {
        public let requestCount: Int
        public let fullResultParity: Bool
        public let projectionEvidenceComplete: Bool
        public let divergingRequestIndex: Int?
    }

    public typealias RecordedBaselineLookup = @Sendable (
        BASEBrainTurnRequest
    ) async -> BASEBrainTurnResult

    public typealias AsyncShadowRun = @Sendable (
        BASEBrainTurnRequest
    ) async -> (BASEBrainTurnResult, BASSemanticShadowObservation)

    public static func semanticDAGShadowParityVerdict(
        requests: [BASEBrainTurnRequest],
        baseline: @escaping RecordedBaselineLookup,
        shadow: @escaping AsyncShadowRun
    ) async -> SemanticShadowParityVerdict {
        var firstDivergence: Int?
        var projectionEvidenceComplete = true
        for (index, request) in requests.enumerated() {
            let expected = await baseline(request) // immutable recorded fixture lookup
            let (actual, observation) = await shadow(request)
            let expectedBytes = BASEBrainTurnResultReplayCanonicalizer.canonicalBytes(expected)
            let actualBytes = BASEBrainTurnResultReplayCanonicalizer.canonicalBytes(actual)
            if expectedBytes != actualBytes, firstDivergence == nil { firstDivergence = index }
            projectionEvidenceComplete = projectionEvidenceComplete &&
                observation.disposition == .complete
        }
        return SemanticShadowParityVerdict(
            requestCount: requests.count,
            fullResultParity: firstDivergence == nil,
            projectionEvidenceComplete: projectionEvidenceComplete,
            divergingRequestIndex: firstDivergence
        )
    }
}
```

Use the existing canonicalizer for every field of `BASEBrainTurnResult`; do not compare display text, selected candidate ID, or the old summary digest alone. `RecordedBaselineLookup` is fixture/replay lookup only and is source-gated from invoking an engine, Provider, LayerCell, tool, or external mechanism. In production the `.semanticDAGShadow` engine runs the ordinary baseline exactly once, projects the shadow from artifacts produced by that same run, and returns that same result. Populate the already-frozen observation field only on the unique final `.complete`; do not persist `BASSemanticShadowObservation` standalone, append a provisional complete, or add an in-memory comparator store.

- [ ] **Step 4: Add the shadow mode and inject the exact immutable-evidence bundle**

Append only this case to `BASTurnRuntimeMode`:

```swift
public enum BASTurnRuntimeMode:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case v1ByteEqual = "v1-byte-equal"
    case nativeV2 = "native-v2"
    case stressSweepDual = "stress-sweep-dual"
    case semanticDAGShadow = "semantic-dag-shadow"
}
```

Add `BASSemanticShadowDependencies` next to the configuration; its initializer is package and throwing, so no public signature leaks package types. Put `BASSemanticBaselineEvidence` in `BASTurnRuntimeEngine.swift`, the same file as its sole constructing method; the replay harness may consume its package-visible fields but cannot call its `fileprivate` initializer:

```swift
package struct BASSemanticShadowDependencies: Sendable {
    package let semanticDAGArtifactID: BASArtifactID
    package let semanticDAG: BASSemanticTurnDAG
    package let artifactReadView: BASSemanticArtifactReopener.ReadOnlyView

    package init(
        semanticDAGArtifactID: BASArtifactID,
        semanticDAG: BASSemanticTurnDAG,
        artifactReadView: BASSemanticArtifactReopener.ReadOnlyView
    ) throws {
        try semanticDAG.validateCanonical()
        self.semanticDAGArtifactID = semanticDAGArtifactID
        self.semanticDAG = semanticDAG
        self.artifactReadView = artifactReadView
    }
}

package struct BASSemanticBaselineEvidence: Sendable {
    package let result: BASEBrainTurnResult
    package let auditEnvelope: BASTurnRuntimeAuditEnvelope
    fileprivate init(
        result: BASEBrainTurnResult,
        auditEnvelope: BASTurnRuntimeAuditEnvelope
    ) {
        self.result = result
        self.auditEnvelope = auditEnvelope
    }
}
```

Store one package optional `shadowDependencies: BASSemanticShadowDependencies?` in `BASTurnRuntimeEngineConfiguration` and add only the package factory `observationOnlySemanticDAGShadow(dependencies:)`. The public configuration stays opaque and its designated composition initializer stays package-only. Replace the current `if runtimeMode == .nativeV2` branch with an exhaustive switch. The shadow branch executes the baseline path once, then performs only this immutable replay projection:

```swift
let baselineEvidence = try await runBaselineOnceWithAuditEvidence(request)
let observation = try await BASEBrainTurnResultReplayHarness
    .reopenSemanticDAGShadowObservation(
        baselineEvidence: baselineEvidence,
        dependencies: shadowDependencies
    )
```

`runBaselineOnceWithAuditEvidence` is the existing baseline engine path, not another coordinator: in `BASTurnRuntimeEngine.swift` it constructs `BASSemanticBaselineEvidence` from the result plus an unpersisted provisional complete value only after the same-run immutable receipts exist. Its same-file `fileprivate` initializer prevents caller fabrication while allowing the package replay harness to read immutable fields. `reopenSemanticDAGShadowObservation` first equality-checks the provisional envelope's typed root/result digest/DAG ID against `baselineEvidence.result` and the configured DAG, then reopens `semanticDAGArtifactID` through `artifactReadView` and byte-equals it to the injected canonical DAG. It may consume only the canonical topological invocation/output/receipt Artifact IDs carried by that exact same-run value, reopen them through the read-only view, bounded-decode their concrete bodies, and prove exact root/DAG/node/edge/topological/result binding. It never synthesizes an invocation, calls `executeSemanticTopology`, prepares a budget request, puts invocation/output/receipt artifacts, or calls a LayerCell mechanism. If the same-run evidence does not expose a complete exact receipt chain, or any node would require Provider/effect/state/lease/K3/K4/Zone-C/tool/network/filesystem capability, it returns typed `shadowUnavailable`; it must not fill the gap by executing. The runtime then discards the provisional value and uses the throwing audit path to append exactly one final `.complete` carrying `semanticShadowObservation`; the normal `.start` already exists, so total governed envelopes remain two. It never puts the nested value standalone. That path has no semantic CAS/head/authority operation and cannot persist a mechanism output masquerading as execution.

`executeSemanticInvocation(..., budgetContext: .shadowNoBudgetAuthority, ...)` is separately fail-closed: it throws `shadowExecutionForbidden` before envelope preflight, invocation put, budget request, task-group creation, or mechanism invocation. Add a source/runtime gate proving the shadow engine never calls it. Whole-process counters compare one normal baseline run against one `.semanticDAGShadow` run and require zero incremental Provider physical calls, K3/K4/Zone-C/effect/state/lease/tool calls, network calls, mutable-filesystem calls, mechanism calls, and non-audit Artifact mutations. Emit the nested audit observation, discard transient reopened payloads, and return `baselineEvidence.result` byte-for-byte; the shadow never calls another coordinator or creates a second public result.

Update `EBrainHostRuntimeSynthesis`, the environment bridge, `BASEnvVarBridgeDoctrine`, and all exact-count/raw-value tests. Unknown environment values retain the existing explicit diagnostic and safe legacy behavior. Do not add `semanticDAGAuthoritative` yet.

- [ ] **Step 5: Run GREEN, canonical parity, mode/bridge regressions, and duplicate-adapter scan**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticDAGShadowParityTests|BASEBrainTurnResultReplayHarnessTests|BASTurnRuntimeModeTests|BASChapter668RuntimeModeToggleProofTests|BASSampleHostRuntimeModeEnvVarBridgeTests|BASEnvVarBridgeDoctrineTests|BASTurnRuntimeEngineTests|BASStressSweepCanonical60DriverTests|BASProcessMemoryLedgerTests|BASTurnRuntimeAuditEnvelopeTests|BASEventLogEntryTurnEnvelopeTests|BASEBrainSchemaGovernanceRegistryTests'
if rg -n 'struct BASSemanticLayerCellAdapters|protocol BASSemanticLayerCellExecutor|struct BASLayerCellActorMeshAdapter|class BASSemanticDAGShadowComparator|actor BASSemanticDAGShadowComparator' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources; then
  exit 1
fi
```

Expected: all selected tests PASS with 0 failures; canonical workloads have full-result parity, only one allowlisted immutable audit put, and zero incremental mechanism/Provider/authority mutations; the inverted scan finds no duplicate adapter/comparator.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticDAGShadowParityTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift
git commit -m "feat: project semantic dag shadow from immutable evidence"
```

### Task 3 [W6]: One Artifact-Mesh Payload Around the Existing Public Result

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayCanonicalizer.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Verify Task-1B frozen envelope; Task 3 only supplies its predeclared result ID at the engine call site: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeAuditEnvelope.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSingleAuthoritativeResultTests.swift`

**Reuse Decision (E/A):** `BASEBrainTurnResult` already owns the public result and all host projections; `artifact.mesh` and `release.spool-publication` already own identity/storage and publication. Extend that result with one unsigned Artifact Mesh payload projection binding the same value to exact spool/release/effect/state evidence before publication. Add the projection beside `BASEBrainTurnResult` in `EBrainTurnResult.swift`; it is not an `M` owner and cannot create a second result file, pending-result hierarchy, public answer enum, or semantic result protocol. Extend the existing canonicalizer; the engine only populates Task-1B's predeclared `authoritativeResultArtifactID` and never edits the audit-envelope declaration/version/registry. Task 5 stores the payload through Artifact Mesh and projects its nested result exactly once after publication finalization.

**Interfaces:**
- Consumes: the current `BASEBrainTurnResult`, typed root, the sovereign W5 `BASProviderReleaseEvidenceReference` four-ID group for a completed release, exact typed receipt+Artifact-ID outputs from the semantic DAG executor/Zone-C broker/reconciliation owner, and owner-returned `[BASK3ActivatedStateEvidence]` from the same injected `BASK3ControlNucleusStorage`. State lifecycle evidence binds existing prepare/optional-outbox/commit/event/attestation/optional-active-state/optional-terminal-effect Artifact handles; Runtime declares neither a state receipt nor a parallel state store. One actor-private async factory reopens every supplied Artifact handle through the same Artifact Mesh, repeats the exact K3 lookup, and exact-matches canonical bodies/result facts before freezing any array. Source/branch/execution/policy/lineage remain inside reopened sole-owner payloads and are not copied into this result wrapper.
- Produces: `BASAuthoritativeTurnResultPayload`, transient `BASAuthoritativeTurnDisposition`, actor-private `makeAuthoritativeResultPayload(...) async throws`, and `publicResult() -> BASEBrainTurnResult`. No public host API returns the payload type, and no function derives an Artifact ID from a legacy result string/value.

- [ ] **Step 1: Write failing single-result, no-self-identity, and exact-projection tests**

```swift
import XCTest
@testable import BASHostKit

final class BASSingleAuthoritativeResultTests: XCTestCase {
    func testPayloadWrapsTheExistingPublicResultExactlyOnce() throws {
        let result = fixtureFullTurnResult()
        let payload = try fixtureAuthoritativePayload(result: result)
        XCTAssertEqual(payload.publicResult(), result)
        XCTAssertEqual(payload.result, result)
    }

    func testPayloadHasNoSelfArtifactIdentityDigestOrSignature() throws {
        let payload = try fixtureAuthoritativePayload(result: fixtureFullTurnResult())
        let labels = Set(Mirror(reflecting: payload).children.compactMap(\.label))
        XCTAssertFalse(labels.contains("artifactID"))
        XCTAssertFalse(labels.contains("resultArtifactID"))
        XCTAssertFalse(labels.contains("payloadDigest"))
        XCTAssertFalse(labels.contains("signature"))
        XCTAssertFalse(labels.contains("storageLocator"))
    }

    func testExactDispositionRequiresWholeProviderReleaseEvidenceGroup() throws {
        XCTAssertThrowsError(try fixtureAuthoritativePayload(
            result: fixtureTurnResult(proving: .completedExact),
            providerReleaseEvidence: nil
        ))
    }

    func testEarlyNonPublishableDispositionCannotCarryProviderReleaseEvidence() throws {
        for disposition in [
            BASAuthoritativeTurnDisposition.refused,
            .deferred,
            .cancelled,
            .reconcileRequired
        ] {
            XCTAssertThrowsError(try fixtureAuthoritativePayload(
                result: fixtureTurnResult(proving: disposition),
                providerReleaseEvidence: fixtureProviderReleaseEvidence()
            ))
        }
    }

    func testDispositionCannotBeCallerSelectedOrContradictCanonicalResult() async throws {
        XCTAssertFalse(try authoritativePayloadInitializerSource()
            .contains("disposition: BASAuthoritativeTurnDisposition"))
        await XCTAssertThrowsErrorAsync { _ = try await fixtureAuthoritativePayload(
            result: fixtureTurnResult(proving: .completedExact),
            evidenceMutation: .foreignEffectReceipt
        ) }
    }

    func testAsyncFactoryReopensEveryReceiptBodyBeforeFreezingIDs() async throws {
        for category in CanonicalResultReceiptCategory.allCases {
            for mutation in ReceiptEvidenceMutation.allCases {
                let fixture = makeResultFactoryFixture(category: category, mutation: mutation)
                await XCTAssertThrowsErrorAsync {
                    _ = try await fixture.makeAuthoritativeResultPayload()
                }
                let requiredReadCount = await fixture.artifactStore.requiredReadCount
                XCTAssertEqual(requiredReadCount, fixture.expectedReadsBeforeFailure)
            }
        }
    }

    func testPayloadArraysComeFromValidatedOwnerOutputsNotCallerVectors() throws {
        let source = try authoritativePayloadFactorySource()
        XCTAssertFalse(source.contains("receiptArtifactIDs: [BASArtifactID]"))
        XCTAssertFalse(source.contains("canonicalResultEffectReceiptArtifactIDs"))
        XCTAssertTrue(source.contains("reopenCanonicalReceipt"))
        XCTAssertTrue(source.contains("canonicalBodyMatchesResultFact"))
    }

    func testCanonicalizationUsesExistingWholeResultCanonicalizer() throws {
        let payload = try fixtureAuthoritativePayload(result: fixtureFullTurnResult())
        XCTAssertEqual(
            BASEBrainTurnResultReplayCanonicalizer.canonicalBytes(payload.result),
            BASEBrainTurnResultReplayCanonicalizer.canonicalBytes(payload.publicResult())
        )
    }


    func testCompletedPayloadReferencesSharedReleaseEvidenceWithoutCopyingLineage() throws {
        let payload = try fixtureAuthoritativePayload(
            result: fixtureFullTurnResult())
        XCTAssertEqual(payload.providerReleaseEvidence,
                       fixtureProviderReleaseEvidence())
        let labels = Set(Mirror(reflecting: payload).children.compactMap(\.label))
        XCTAssertFalse(labels.contains("orderedProviderBranches"))
        XCTAssertFalse(labels.contains("terminalProviderExecutionRef"))
        XCTAssertFalse(labels.contains("providerVisibilityMode"))
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASSingleAuthoritativeResultTests
```

Expected: FAIL at compile time with `cannot find 'BASAuthoritativeTurnResultPayload' in scope`; the current public result exists but has no Artifact Mesh wrapper.

- [ ] **Step 3: Add the payload beside the existing result owner**

Add these declarations to `EBrainTurnResult.swift` after `BASEBrainTurnResult`:

```swift
public enum BASAuthoritativeTurnDisposition: String, Codable, Sendable, Equatable {
    case completedExact
    case completedWithEffect
    case refused
    case deferred
    case cancelled
    case reconcileRequired
}

public enum BASAuthoritativeTurnResultPayloadError: Error, Sendable, Equatable {
    case missingProviderReleaseEvidence
    case nonPublishableDispositionCarriesProviderReleaseEvidence
    case effectCompletionMissingReceipt
    case completedTurnMissingStateCommitEvidence
    case reconciliationMissingReceipt
    case duplicateChildReceiptArtifact
    case canonicalReceiptEvidenceMismatch
    case dispositionEvidenceConflict
}

public struct BASAuthoritativeTurnResultPayload:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let result: BASEBrainTurnResult
    public let providerReleaseEvidence: BASProviderReleaseEvidenceReference?
    public let orderedNodeReceiptArtifactIDs: [BASArtifactID]
    public let orderedEffectReceiptArtifactIDs: [BASArtifactID]
    public let orderedStateCommitArtifactIDs: [BASArtifactID]
    public let orderedReconciliationReceiptArtifactIDs: [BASArtifactID]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        result: BASEBrainTurnResult,
        providerReleaseEvidence: BASProviderReleaseEvidenceReference?,
        validatedNodeReceiptArtifactIDs: [BASArtifactID],
        validatedEffectReceiptArtifactIDs: [BASArtifactID],
        validatedStateCommitArtifactIDs: [BASArtifactID],
        validatedReconciliationReceiptArtifactIDs: [BASArtifactID]
    ) throws {
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.result = result
        self.providerReleaseEvidence = providerReleaseEvidence
        self.orderedNodeReceiptArtifactIDs = validatedNodeReceiptArtifactIDs
        self.orderedEffectReceiptArtifactIDs = validatedEffectReceiptArtifactIDs
        self.orderedStateCommitArtifactIDs = validatedStateCommitArtifactIDs
        self.orderedReconciliationReceiptArtifactIDs =
            validatedReconciliationReceiptArtifactIDs
        try validatedForPrePublication()
    }

    public func validatedForPrePublication() throws {
        let disposition = try derivedDisposition()
        let childReceiptArtifactIDs = orderedNodeReceiptArtifactIDs +
            orderedEffectReceiptArtifactIDs +
            orderedStateCommitArtifactIDs +
            orderedReconciliationReceiptArtifactIDs
        guard Set(childReceiptArtifactIDs).count == childReceiptArtifactIDs.count else {
            throw BASAuthoritativeTurnResultPayloadError.duplicateChildReceiptArtifact
        }
        switch disposition {
        case .completedExact:
            guard providerReleaseEvidence != nil else {
                throw BASAuthoritativeTurnResultPayloadError.missingProviderReleaseEvidence
            }
            guard !orderedStateCommitArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.completedTurnMissingStateCommitEvidence
            }
        case .completedWithEffect:
            guard providerReleaseEvidence != nil else {
                throw BASAuthoritativeTurnResultPayloadError.missingProviderReleaseEvidence
            }
            guard !orderedEffectReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.effectCompletionMissingReceipt
            }
            guard !orderedStateCommitArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.completedTurnMissingStateCommitEvidence
            }
        case .reconcileRequired:
            guard providerReleaseEvidence == nil else {
                throw BASAuthoritativeTurnResultPayloadError
                    .nonPublishableDispositionCarriesProviderReleaseEvidence
            }
            guard !orderedReconciliationReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.reconciliationMissingReceipt
            }
        case .refused, .deferred, .cancelled:
            guard providerReleaseEvidence == nil else {
                throw BASAuthoritativeTurnResultPayloadError
                    .nonPublishableDispositionCarriesProviderReleaseEvidence
            }
        }
    }

    public func derivedDisposition() throws -> BASAuthoritativeTurnDisposition {
        try BASEBrainTurnResultReplayCanonicalizer.deriveAuthoritativeDisposition(
            result: result,
            providerReleaseEvidence: providerReleaseEvidence,
            effectReceiptArtifactIDs: orderedEffectReceiptArtifactIDs,
            stateCommitArtifactIDs: orderedStateCommitArtifactIDs,
            reconciliationReceiptArtifactIDs:
                orderedReconciliationReceiptArtifactIDs
        )
    }

    public func publicResult() -> BASEBrainTurnResult { result }
}

extension BASEBrainTurnResultReplayCanonicalizer {
    public static func deriveAuthoritativeDisposition(
        result: BASEBrainTurnResult,
        providerReleaseEvidence: BASProviderReleaseEvidenceReference?,
        effectReceiptArtifactIDs: [BASArtifactID],
        stateCommitArtifactIDs: [BASArtifactID],
        reconciliationReceiptArtifactIDs: [BASArtifactID]
    ) throws -> BASAuthoritativeTurnDisposition {
        guard try canonicalTerminalFactCount(result) == 1 else {
            throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
        }
        if try canonicalResultProvesCancellation(result) {
            guard providerReleaseEvidence == nil,
                  effectReceiptArtifactIDs.isEmpty,
                  stateCommitArtifactIDs.isEmpty,
                  reconciliationReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
            }
            return .cancelled
        }
        if try canonicalResultProvesDeferral(result) {
            guard providerReleaseEvidence == nil,
                  effectReceiptArtifactIDs.isEmpty,
                  stateCommitArtifactIDs.isEmpty,
                  reconciliationReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
            }
            return .deferred
        }
        if try canonicalResultProvesRefusal(result) {
            guard providerReleaseEvidence == nil,
                  effectReceiptArtifactIDs.isEmpty,
                  stateCommitArtifactIDs.isEmpty,
                  reconciliationReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
            }
            return .refused
        }
        if try canonicalResultRequiresReconciliation(result) {
            guard providerReleaseEvidence == nil,
                  effectReceiptArtifactIDs.isEmpty,
                  stateCommitArtifactIDs.isEmpty,
                  !reconciliationReceiptArtifactIDs.isEmpty else {
                throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
            }
            return .reconcileRequired
        }
        guard try canonicalResultProvesCompletedRelease(result),
              providerReleaseEvidence != nil,
              !stateCommitArtifactIDs.isEmpty,
              reconciliationReceiptArtifactIDs.isEmpty else {
            throw BASAuthoritativeTurnResultPayloadError.dispositionEvidenceConflict
        }
        if effectReceiptArtifactIDs.isEmpty { return .completedExact }
        return .completedWithEffect
    }
}
```

Implement only the displayed canonical result predicates/count helpers inside the existing whole-result canonicalizer by inspecting the already-canonical `recoveryDisposition`, emergency/risk/sovereign/action-permit, rendered-output, state/effect/reconciliation summary facts. Do **not** add `canonicalResult…ReceiptArtifactIDs(result)`: the legacy/current `BASEBrainTurnResult` does not contain those Artifact IDs, so deriving them from strings or value content would be fabricated authority. The wrapper has neither a stored/encoded `disposition` field nor a `disposition:` initializer parameter. `derivedDisposition()` computes only a transient outcome after the actor-private factory/barrier has proven the receipt bodies; `validatedForPrePublication()` performs schema, uniqueness, presence, and disposition-shape checks, never claims that an ID body was validated synchronously.

Register persisted `BASAuthoritativeTurnResultPayload` exactly once in the existing `BASEBrainSchemaGovernanceRegistry` with the Contracts-defined cycle-safe call `pinnedEntry("BASAuthoritativeTurnResultPayload", currentVersion: "1.0.0", tests: ["schema.BASAuthoritativeTurnResultPayload.current", "schema.BASAuthoritativeTurnResultPayload.backward_v1", "schema.BASAuthoritativeTurnResultPayload.future_rejection"], learnability: .semiLearnable)`. BASAdmin must not import BASHostKit, and the package dependency graph must remain cycle-free. Every ordinary put, Artifact identity payload, and reopen uses only `BASGovernedArtifactPayloadCodec.canonicalBytes(for:)`/`decodeCurrent`; raw encoder/decoder paths and field access before version rejection fail the source gate. An owner-target parity test compares that pinned version with `BASAuthoritativeTurnResultPayload.currentSchemaVersion`; exact-one object/test-ID tests, current codec round trips, pinned v1 fixtures for every disposition shape, missing/future-version rejection, and an alias/second-helper rejection are mandatory. A cross-target compile fixture imports `BASHostKit` and constructs the value through its public throwing initializer with `schemaVersion` omitted. Constructibility grants no authority: production callsite inventory permits exactly one `BASAuthoritativeTurnResultPayload(...)` call, inside actor-private `makeAuthoritativeResultPayload(...)`; the compile fixture is test-only and no other production site may persist or admit one. `swift package dump-package` is the cycle-direction gate. The transient disposition enum, owner-returned tuples, K3 evidence projection, and factory return are not separately governed persisted schemas. `BASSemanticShadowObservation` remains nested inside the already governed `BASTurnRuntimeAuditEnvelope` and has no standalone object ID or registry entry.

Add one private async `BASTurnRuntimeEngine.makeAuthoritativeResultPayload(...)` factory. Its inputs are owner-produced typed handles—not independent `[BASArtifactID]` parameters: canonical topological `SemanticNodeExecution` values, broker-authored effect receipt tuples, globally ordered `[BASK3ActivatedStateEvidence]` returned by the same K3 composite, reconciliation receipt tuples, and the optional four-ID Provider release group. For every semantic/effect/reconciliation tuple, reopen its Artifact ID from the same store, bounded-decode the expected concrete payload type, canonical-byte-equal the reopened body to the supplied owner-returned body, then exact-match root/node/kind/order/outcome/result facts.

For every `BASK3ActivatedStateEvidence`, call that exact same object's `lookupActivatedStateEvidence(turnOperationRef:commitArtifactID:)`; nil or whole-projection non-byte-equality across **every** field fails. That sole K3 query recomputes `sourceRootArtifactID` from its EventLog integrity/HWM row and rejects stage/seal/active root splits, so Runtime compares the returned root exactly and does not accept a caller root or invent a second root reader. Through the same Artifact Mesh/reopener, mandatory-reopen and bounded-decode `prepareArtifactID`, `commitArtifactID`, and `attestationArtifactID`; paired-reopen nonnil `outboxArtifactID` as `BASStateEffectOutboxPayload` plus its effect-causal-predecessor artifact; paired-reopen nonnil `activeStateArtifactID`; and paired-reopen nonnil `terminalEffectReceiptArtifactID` as `BASEffectReceiptPayload`. Exact-check event ID/sequence, typed root/branch, prepare→outbox→commit→attestation→active causality, expected parent/version/base snapshot, outbox sibling/prepare/effect-request/predecessor bindings, terminal-effect receipt/outcome, policy/deletion epochs, and canonical result state/effect facts. `activeStateArtifactID == nil` is legal only when the reopened commit is a fully validated no-op with `newStateArtifactID == nil` and zero lane mutations; otherwise it must be nonnil and equal `commit.newStateArtifactID`. Outbox, effect receipt, and outcome optionality must match the reopened prepare/commit exactly. The payload freezes only `evidence.commitArtifactID` values as `orderedStateCommitArtifactIDs`; all other handles remain reachable through K3 evidence and are not copied as invented receipt IDs. Runtime defines no `BASState*Receipt`, state store, state writer, or lifecycle owner.

Add a full-field mutation matrix covering omitted/foreign/swapped prepare, commit, attestation, outbox, active-state, terminal-effect, event ID/sequence, source-root fork, policy/deletion epoch, nil/non-nil pairing, outbox sibling, effect-causal-predecessor, no-op/active mismatch, same-ID/different-body, restart/lost-reply, and corrupted K3 row/integrity/HWM evidence. Each case fails before result put; valid restart returns byte-equal evidence and the same ordered commit ID.

For loop nodes, additionally reopen the exact invocation, `BASControlLoopEnvelopePayload`, prior/current `BASBudgetUseReceipt`, `BASControlLoopProgressWitnessPayload`, and `BASControlLoopTerminalReceiptPayload` chain; only `convergedVerified` may be reflected as completed. Omission, reordering, duplicate, foreign ID, same-ID/different-body substitution, wrong kind, K3 evidence drift, result-fact mismatch, or nonconverged loop evidence fails before construction. Only then does the factory derive and freeze node/effect/state-commit/reconciliation arrays and call the public throwing validating initializer. A source test requires exactly one public initializer with `schemaVersion` first/default, rejects every production constructor call outside that actor-private factory, and rejects `BASStateCommitStore`, `BASStatePrepareReceipt`, `BASStateCommitReceipt`, `orderedStateReceiptArtifactIDs`, or any function deriving Artifact IDs from legacy result values.

After decode, Task 5's pre-publication barrier repeats every reopen/body/result equality before trusting `derivedDisposition()`. Thus synthesized `Codable` cannot carry a forged second result label or receipt truth, and neither the payload nor manifest becomes a second receipt owner.

Every reference names a child payload; none is the wrapper's own identity. `providerReleaseEvidence` is the sole optional all-or-nothing Provider release group and contains only four Artifact IDs. A derived publishable disposition requires it; a derived early refused/deferred/cancelled/reconcile disposition requires `nil` and relies on its typed reconciliation receipts for any in-flight branch evidence. No fake policy/binding/chain/source/spool ID is constructed. Task 5 reopens the group, spool, preparation, and both shared chain payloads; validates root/policy/binding/complete lineage/source/proposal+seal+terminal-source receipts/visibility/L10/final branch; and exact-compares result/manifest. Pure result initialization grants no Provider authority. A prefix-only artifact can never satisfy the final barrier.

- [ ] **Step 4: Keep runtime surfaces result-only and reject alternate result authorities**

Keep the public result type unchanged, but remove caller-supplied audit-bundle authority from the authoritative surface:

```swift
public func runTurn(
    _ request: BASEBrainTurnRequest,
    permitEscalationLedger: BASPermitEscalationLedger? = nil,
    stageLedger: BASTurnRuntimeStageLedger? = nil,
    stagePlan: BASTurnRuntimeStagePlan? = nil,
    timestampMsOverride: Int64? = nil
) async -> BASEBrainTurnResult
```

The engine obtains audit projections only from the unique same-run package coordinator outcome defined by Semantic Task 8. If source compatibility requires retaining the old `auditProjections:` overload for one release, mark it diagnostic-only/deprecated, exclude it from authoritative composition, and prove its argument can affect only nonpersisted display diagnostics: it cannot enter the governed bundle put, emission summary, envelope Artifact-ID field, result, replay, release, state, or effect path. No caller can inject or replace the bundle value that the engine persists.

Add the actor-private async factory above; it accepts the owner-returned typed receipt handles, performs the reopen/body/result validation, and returns `BASAuthoritativeTurnResultPayload`; Task 5 stores it. It cannot accept independent receipt-ID vectors, derive IDs from `BASEBrainTurnResult`, publish, reserve, finalize, or call `BASEBrainRuntimeCoordinator`. All public host projections continue to consume only `BASEBrainTurnResult`. Add a source test that rejects declarations named `BASPendingAuthoritativeTurnArtifact`, `BASAuthoritativeTurnArtifact`, `BASSemanticTurnResult`, any public method returning the wrapper payload, a second public/package payload initializer, and any production constructor call outside the actor-private factory. The one public validating initializer exists for cross-target schema construction; only the private factory makes it admissible.

- [ ] **Step 5: Run GREEN, result regressions, and one-public-result scan**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSingleAuthoritativeResultTests|BASEBrainSchemaGovernanceRegistryTests|BASEBrainTurnResultReplayHarnessTests|BASEBrainTurnResultBoxingTests|BASEBrainTurnResultClusterBundleCodableRoundTripTests|BASTurnRuntimeEngineSignatureFreezeTests'
if rg -n 'public (struct|enum|class) (BASPendingAuthoritativeTurnArtifact|BASAuthoritativeTurnArtifact|BASSemanticTurnResult)|public func .*-> BASAuthoritativeTurnResultPayload' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources; then
  exit 1
fi
test "$(rg -n 'BASAuthoritativeTurnResultPayload\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit --glob '*.swift' | wc -l | tr -d ' ')" = 1
! rg -n 'canonicalResult(Effect|State|Reconciliation)ReceiptArtifactIDs|receiptArtifactIDs: \[BASArtifactID\]' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayCanonicalizer.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift
```

Expected: all selected tests PASS with 0 failures; the async factory reopens and exact-matches every receipt body before freezing IDs, the barrier repeats that proof after decode, the wrapper round-trips without self identity, and the scans confirm one construction site, no impossible result-to-ID extractor, and `BASEBrainTurnResult` as the only public result.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayCanonicalizer.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSingleAuthoritativeResultTests.swift
git commit -m "feat: wrap the canonical turn result as one artifact payload"
```

### Task 4 [W6]: One Artifact-Mesh Replay Manifest and an Event-Truth-Derived Index

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASRoutedEventLogStorage.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArchitectureReplayManifestTests.swift`

**Reuse Decision (M + E/A):** A complete pre-publication manifest payload and its source-event lookup are allowlisted as missing. Create one immutable RuntimeCore manifest contract. Store its bytes only through `BASArtifactStorePort`. Extend the existing event log and `BASSQLiteEventLogStorage` with a rebuildable mapping from the existing integrity-bound source head to one `BASArtifactID`; do not create `BASEventLogReplayManifestStore`, a manifest table containing JSON/blob bytes, another event ID, another watermark, or another integrity chain. `BASRoutedEventLogStorage` only forwards the index operation to its selected canonical event-log route.

For owner-ledger key `runtime-replay-certification:Task 4`, the first create delta atomically adds the exact production path permission and create-proof evidence and changes `approved_missing → converging`; subsequent deltas append concrete evidence. Remove a `current_conflicts` item only with proof. Change to `implemented` only when every declared path exists, task tests and owner/checker gates pass, the evidence list is complete, and `current_conflicts == []`. Roll back ledger status/evidence/permission with the source create if the create is rolled back. Stage the ledger, checker, checker test, source/index changes, registry, and focused tests together.

**Create Proof — `BASArchitectureReplayManifest.swift`:**

1. Repository search: `rg -n 'ArchitectureReplayManifest|PrePublicationManifest|ReplayManifestIndex' BehavioralAISubstrate/Sources` finds no complete manifest owner. Nearest owners are `BASEBrainTurnResultReplayHarness`, `BASEventLogReplayBundle`, `BASEventReplayRunner`, `BASAuditReplayEngine`, and existing observability receipt types.
2. Public/upstream search: `Codable`, SQLite indexes, and Artifact Mesh provide encoding/storage mechanisms but no application-specific complete turn/effect/publication-barrier manifest.
3. Missing invariant: one unsigned immutable payload that references every semantic/neural/effect/state/release/loop prerequisite and whose complete topological node-receipt and general receipt vectors are derived from reopened sole-owner evidence—not selected by a caller—before the existing source-event integrity identity can reach publication reservation.
4. Existing replay harnesses cannot satisfy durability/completeness because they compare current values and event bundles; extending them with manifest bytes would make a test/HostKit utility an object store. A new low-entropy payload plus a thin existing-event-log index is required.
5. Authority/state/storage/failure: the manifest file owns payload validation and index-port shape only. Artifact Mesh owns bytes/identity. `BASSQLiteEventLogStorage` owns the derived index transaction. `BASEventLog` owns order/integrity. Missing/tampered child, source mismatch, duplicate receipt, incomplete branch, and reopen failure fail closed before publication.
6. Dependency direction: RuntimeCore manifest values depend on RuntimeCore cross-plan contracts; Artifact Mesh/event-log implementations satisfy ports below them; HostKit composes them later. No storage target imports HostKit.
7. Compatibility: existing replay harnesses remain and are extended in Task 5 to read the manifest. Existing event rows remain readable; schema migration adds only an ID index. The old event replay path freezes as deterministic-semantic compatibility and retires only after authoritative cohorts pass.
8. Mutation/crash/replay/duplicate tests cover omitted/reordered/duplicate/foreign/extra/wrong-kind/substituted node and general receipt references, mutated DAG/State-Market/context IDs, a tampered snapshot reopened by ID, broken loop envelope/use/witness/terminal evidence, any watermark field copied into the manifest, binding mismatch, crash before/after Artifact Mesh put, index transaction rollback, restart/rebuild, event-chain tamper, two manifests for one source, a second manifest-byte store, and publication attempted without reopen.

**Interfaces:**
- Consumes: typed `BASTurnOperationRef`, integrity-bound `BASEventLogHead` whose compatibility session projection round-trips to that root, `BASArtifactID`, reopened semantic DAG/snapshot/State-Market selection/compiled-context/authoritative-result artifacts, terminal-prefix and through-visibility Provider chains, the sovereign prerequisite's sole `BASProviderReleaseEvidenceReference` four-ID group, and typed sole-owner semantic/loop/effect/state/reconciliation/release evidence. The manifest never copies the Provider lineage vector, terminal disposition, policy/binding/source/visibility projections, Attempt/generation/epoch/sink/boundary authority, watermark vectors, spool/preparation fields, or release facts already owned by referenced payloads.
- Produces: publishable-only `BASArchitectureReplayManifest`, `BASReplayReceiptReference`, typed-root `BASReplayManifestIndexBinding`/`BASReplayManifestIndexPort`, `BASPrePublicationManifestBarrierReceipt`, and `validateComplete() throws`; it consumes rather than redeclares shared `BASProviderBranchLineageEntry`, `BASProviderBranchChainPayload`, `BASProviderReleaseEvidenceReference`, or `BASAuthoritativeTurnDisposition`. HostKit derives the latter only by reopening the authoritative result. Early refused/deferred/cancelled/reconcile outcomes persist the result/reconciliation evidence only and never construct, index, or resolve a pre-publication manifest.

- [ ] **Step 1: Write failing manifest identity, completeness, index, restart, and no-second-store tests**

```swift
import XCTest
@testable import BASRuntimeCore

final class BASArchitectureReplayManifestTests: XCTestCase {
    func testManifestUsesCanonicalCrossPlanReferencesWithoutSelfIdentity() throws {
        let manifest = try fixtureCompleteManifest()
        XCTAssertEqual(manifest.semanticDAGArtifactID, fixtureArtifactID("semantic-dag"))
        XCTAssertEqual(manifest.semanticSnapshotArtifactID, fixtureArtifactID("semantic-snapshot"))
        XCTAssertEqual(
            manifest.providerReleaseEvidence.spoolArtifactID,
            fixtureArtifactID("spool")
        )
        XCTAssertEqual(
            manifest.providerReleaseEvidence.throughVisibilityProviderBranchChainArtifactID,
            fixtureArtifactID("through-visibility-chain")
        )
        let labels = Set(Mirror(reflecting: manifest).children.compactMap(\.label))
        XCTAssertFalse(labels.contains("manifestID"))
        XCTAssertFalse(labels.contains("artifactID"))
        XCTAssertFalse(labels.contains("manifestDigest"))
        XCTAssertFalse(labels.contains("signature"))
        XCTAssertFalse(labels.contains("capabilityUseReceiptArtifactID"))
        XCTAssertFalse(labels.contains("terminalDisposition"))
        XCTAssertFalse(labels.contains("orderedProviderBranches"))
        XCTAssertFalse(labels.contains("providerBranchPolicyArtifactID"))
        XCTAssertFalse(labels.contains("executionBindingArtifactID"))
        XCTAssertFalse(labels.contains("terminalAnswerSourceBranchRef"))
        XCTAssertTrue(labels.allSatisfy { !$0.lowercased().contains("watermark") })
        XCTAssertEqual(manifest.turnOperationRef, fixtureTurnOperationRef())
    }

    func testManifestRejectsMissingExactChildOrCopiedBindingDigests() throws {
        XCTAssertThrowsError(try decodeManifest(
            fixtureManifestBytes(omitting: "providerReleaseEvidence")))
        XCTAssertThrowsError(try fixtureCompleteManifest(receiptKindsToDrop: [.exactVerification]))
        XCTAssertFalse(fixtureManifestFieldLabels().contains("qualityDigest"))
        XCTAssertFalse(fixtureManifestFieldLabels().contains("stateABIDigest"))
        XCTAssertFalse(fixtureManifestFieldLabels().contains("fallbackGraphDigest"))
    }

    func testManifestIndexStoresOnlyArtifactIDAndDerivesSourceFromEventTruth() async throws {
        let fixture = try makeSQLiteManifestIndexFixture()
        let binding = fixtureIndexBinding(
            sourceEventHead: fixture.sourceHead,
            manifestArtifactID: fixtureArtifactID("manifest")
        )
        _ = try await fixture.store.indexReplayManifest(
            binding,
            indexEvent: fixture.indexEvent,
            ifCurrentHead: fixture.currentHead
        )
        let resolvedManifestID = try await fixture.store.replayManifestArtifactID(
            for: fixture.turnOperationRef,
            sourceEventHead: fixture.sourceHead)
        XCTAssertEqual(resolvedManifestID, fixtureArtifactID("manifest"))
        let columns = try sqliteColumns(table: "replay_manifest_index", at: fixture.databaseURL)
        XCTAssertEqual(Set(columns), Set([
            "source_session_id", "source_sequence_number", "source_event_id",
            "source_integrity_digest", "source_row_hash", "manifest_artifact_id",
            "index_event_id",
        ]))
        XCTAssertFalse(columns.contains("manifest_json"))
        XCTAssertFalse(columns.contains("manifest_blob"))
        XCTAssertFalse(columns.contains("manifest_digest"))
    }

    func testIndexSurvivesRestartAndRebuildsFromExistingEventRows() async throws {
        let fixture = try makeSQLiteManifestIndexFixture()
        try await fixture.indexCompleteManifest()
        let reopened = try BASSQLiteEventLogStorage(databaseURL: fixture.databaseURL)
        let reopenedManifestID = try await reopened.replayManifestArtifactID(
            for: fixture.turnOperationRef,
            sourceEventHead: fixture.sourceHead)
        XCTAssertEqual(reopenedManifestID, fixtureArtifactID("manifest"))
        try await reopened.rebuildReplayManifestIndex(
            for: fixture.turnOperationRef)
        let rebuiltManifestID = try await reopened.replayManifestArtifactID(
            for: fixture.turnOperationRef,
            sourceEventHead: fixture.sourceHead)
        XCTAssertEqual(rebuiltManifestID, fixtureArtifactID("manifest"))
    }

    func testTwoManifestArtifactsCannotBindSameSourceIdentity() async throws {
        let fixture = try makeSQLiteManifestIndexFixture()
        try await fixture.indexCompleteManifest()
        await XCTAssertThrowsErrorAsync {
            try await fixture.indexManifest(fixtureArtifactID("different-manifest"))
        }
    }


    func testCompleteProviderChainHasOnePinnedTerminalSource() throws {
        let manifest = try fixtureCompleteManifest()
        let chains = try fixtureReopenedProviderChains(for: manifest)
        XCTAssertEqual(chains.terminalPrefix.cut, .terminalPrefix)
        XCTAssertEqual(chains.throughVisibility.cut, .throughVisibility)
        XCTAssertEqual(
            chains.terminalPrefix.orderedEntries,
            Array(chains.throughVisibility.orderedEntries.prefix(
                chains.terminalPrefix.orderedEntries.count
            ))
        )
        XCTAssertEqual(chains.throughVisibility.orderedEntries.filter {
            $0.providerEgressBranchRef == chains.throughVisibility.terminalAnswerSourceBranchRef
        }.count, 1)
    }

    func testPolicyVisibilityOrSiblingSourceMutationFailsClosed() {
        for mutation in BASReplayProviderMutation.allCases {
            XCTAssertThrowsError(try fixtureCompleteManifest(
                providerMutation: mutation))
        }
    }

    func testManifestFactoryVectorsCannotDriftFromReopenedOwnerEvidence() async throws {
        for vector in ManifestDerivedVector.allCases {
            for mutation in ManifestVectorMutation.allCases {
                let fixture = makeManifestFactoryFixture(
                    vector: vector,
                    mutation: mutation
                )
                await XCTAssertThrowsErrorAsync {
                    _ = try await fixture.makeAndValidateManifest()
                }
            }
        }
        // Mutations include omission, reorder, duplicate, foreign, extra,
        // same-ID/different-body substitution, and wrong-kind relabeling.
    }

    func testManifestTopLevelReferencesAreReopenedAndCausallyBound() async throws {
        for mutation in ManifestTopLevelReferenceMutation.allCases {
            let fixture = makeManifestFactoryFixture(topLevelMutation: mutation)
            await XCTAssertThrowsErrorAsync {
                _ = try await fixture.makeAndValidateManifest()
            }
        }
        // Covers DAG, snapshot, State-Market selection, compiled context,
        // result, source head/root, preparation/spool, and both chain IDs.
    }

    func testProviderOwnedReceiptKindsCannotBeDuplicatedIntoManifestVector() {
        XCTAssertFalse(BASReplayReceiptKind.allCases.map(\.rawValue).contains("proposal"))
        XCTAssertFalse(BASReplayReceiptKind.allCases.map(\.rawValue).contains("acceptance"))
        XCTAssertFalse(BASReplayReceiptKind.allCases.map(\.rawValue).contains("fallback"))
        XCTAssertFalse(BASReplayReceiptKind.allCases.map(\.rawValue).contains("terminalSeal"))
    }

    func testBothVisibilityModesRequireExactPolicyEvidence() throws {
        for mode in [
            BASProviderVisibilityMode.incrementalVerified,
            .bufferedUntilVerified,
        ] {
            let manifest = try fixtureCompleteManifest(visibilityMode: mode)
            let chains = try fixtureReopenedProviderChains(for: manifest)
            XCTAssertFalse(
                chains.throughVisibility.orderedVisibilityEvidenceArtifactIDs.isEmpty)
            XCTAssertNotNil(chains.throughVisibility.providerVisibilityReceiptArtifactID)
            try fixtureReplayValidator().validateProviderChain(
                manifest: manifest,
                terminalPrefix: chains.terminalPrefix,
                throughVisibility: chains.throughVisibility
            )
        }
    }
}
```

`BASReplayProviderMutation.allCases` covers reordered/reused/gapped branch ordinal, wrong root/kind, duplicate branch/ref, missing or wrong allocation/claim/head-seal/proposal/causal receipt, incomplete/wrong sequence-zero `BASProviderExecutionRef`, a nonzero event ref with any stable base-field mutation or not produced by checked `withRequestSequence`, missing/mismatched/rewritten selected-descriptor Artifact ID, governed-parent bytes/schema or embedded descriptor/provider/containment mutation, unknown `stepRuleID`, policy/binding mismatch, policy-derived purpose/output-role/count/causality mismatch, a second terminal source, later/sibling final candidate, wrong terminal proposal, visibility mode switch/missing evidence, post-visibility Provider branch, wrong provisional/final branch, paired arm/observation mismatch, and spool/preparation/result disagreement.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_REPLAY_MANIFEST_CANDIDATE_MANIFEST:?set the ephemeral runtime.replay-manifest candidate manifest path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$BAS_REPLAY_MANIFEST_CANDIDATE_MANIFEST"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter BASArchitectureReplayManifestTests
```

Expected: FAIL at compile time because `BASArchitectureReplayManifest` and `BASReplayManifestIndexPort` do not exist.

- [ ] **Step 3: Add the unsigned complete manifest and barrier payloads**

```swift
import Foundation

public enum BASReplayReceiptKind: String, Codable, Sendable, Hashable, CaseIterable {
    case inputNormalization
    case admission
    case resourceLease
    case budgetUse
    case controlLoopProgress
    case controlLoopTerminal
    case exactVerification
    case finalRisk
    case releasePreparation
    case randomness
    case effect
    case statePrepareArtifact
    case stateOutboxArtifact
    case stateCommitArtifact
    case stateAttestationArtifact
    case activeStateArtifact
    case reconciliation
}

public struct BASReplayReceiptReference: Codable, Sendable, Equatable, Hashable {
    public let ordinal: UInt32
    public let kind: BASReplayReceiptKind
    public let artifactID: BASArtifactID

    public init(ordinal: UInt32, kind: BASReplayReceiptKind, artifactID: BASArtifactID) {
        self.ordinal = ordinal
        self.kind = kind
        self.artifactID = artifactID
    }
}

public struct BASArchitectureReplayManifest:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let sourceEventHead: BASEventLogHead
    public let authoritativeResultArtifactID: BASArtifactID
    public let semanticDAGArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let stateMarketSelectionArtifactID: BASArtifactID
    public let compiledContextDescriptorArtifactID: BASArtifactID
    public let providerReleaseEvidence: BASProviderReleaseEvidenceReference
    public let orderedNodeReceiptArtifactIDs: [BASArtifactID]
    public let orderedReceipts: [BASReplayReceiptReference]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        sourceEventHead: BASEventLogHead,
        authoritativeResultArtifactID: BASArtifactID,
        semanticDAGArtifactID: BASArtifactID,
        semanticSnapshotArtifactID: BASArtifactID,
        stateMarketSelectionArtifactID: BASArtifactID,
        compiledContextDescriptorArtifactID: BASArtifactID,
        providerReleaseEvidence: BASProviderReleaseEvidenceReference,
        validatedNodeReceiptArtifactIDs: [BASArtifactID],
        validatedReceipts: [BASReplayReceiptReference]
    ) throws {
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.sourceEventHead = sourceEventHead
        self.authoritativeResultArtifactID = authoritativeResultArtifactID
        self.semanticDAGArtifactID = semanticDAGArtifactID
        self.semanticSnapshotArtifactID = semanticSnapshotArtifactID
        self.stateMarketSelectionArtifactID = stateMarketSelectionArtifactID
        self.compiledContextDescriptorArtifactID = compiledContextDescriptorArtifactID
        self.providerReleaseEvidence = providerReleaseEvidence
        self.orderedNodeReceiptArtifactIDs = validatedNodeReceiptArtifactIDs
        self.orderedReceipts = validatedReceipts
        try validateComplete()
    }
}

public struct BASReplayManifestIndexBinding: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let sourceEventHead: BASEventLogHead
    public let manifestArtifactID: BASArtifactID

    public init(
        turnOperationRef: BASTurnOperationRef,
        sourceEventHead: BASEventLogHead,
        manifestArtifactID: BASArtifactID
    ) {
        self.turnOperationRef = turnOperationRef
        self.sourceEventHead = sourceEventHead
        self.manifestArtifactID = manifestArtifactID
    }
}

public protocol BASReplayManifestIndexPort: Sendable {
    func indexReplayManifest(
        _ binding: BASReplayManifestIndexBinding,
        indexEvent: BASEventLogEntry,
        ifCurrentHead expectedHead: BASEventLogHead
    ) async throws -> BASEventLogHead
    func replayManifestArtifactID(
        for turnOperationRef: BASTurnOperationRef,
        sourceEventHead: BASEventLogHead
    ) async throws -> BASArtifactID?
    func rebuildReplayManifestIndex(
        for turnOperationRef: BASTurnOperationRef
    ) async throws
}

package typealias BASRuntimeK3Composite =
    any BASK3ControlNucleusStorage & BASReplayManifestIndexPort

public struct BASPrePublicationManifestBarrierReceipt: Codable, Sendable, Equatable {
    public let turnOperationRef: BASTurnOperationRef
    public let manifestArtifactID: BASArtifactID
    public let sourceEventHead: BASEventLogHead
    public let authoritativeResultArtifactID: BASArtifactID
    public let providerReleaseEvidence: BASProviderReleaseEvidenceReference

    public init(
        turnOperationRef: BASTurnOperationRef,
        manifestArtifactID: BASArtifactID,
        sourceEventHead: BASEventLogHead,
        authoritativeResultArtifactID: BASArtifactID,
        providerReleaseEvidence: BASProviderReleaseEvidenceReference
    ) {
        self.turnOperationRef = turnOperationRef
        self.manifestArtifactID = manifestArtifactID
        self.sourceEventHead = sourceEventHead
        self.authoritativeResultArtifactID = authoritativeResultArtifactID
        self.providerReleaseEvidence = providerReleaseEvidence
    }
}
```

Implement `validateComplete()` in two layers. Pure RuntimeCore structural validation requires `sourceEventHead.sessionID` to decode through `BASTurnOperationRef(validatingCanonicalLegacyProjection:)` and equal `turnOperationRef`; the nonoptional exact four-ID `providerReleaseEvidence`; nonempty unique node receipts; globally unique general receipt artifacts; and general receipt ordinals continuous from zero. It rejects Provider-owned proposal/allocation/claim/event-head/terminal-source/visibility kinds entirely: those exist only inside the referenced canonical Provider chains and are never duplicated into `orderedReceipts`. This publishable-only layer has no terminal-disposition field, no copied publication-authority snapshot, and cannot import or infer HostKit result truth. The public throwing initializer keeps `schemaVersion` first/default and accepts only arguments prefixed `validated`; production source has exactly one call in actor-private HostKit `makeArchitectureReplayManifest(...)`, while synthesized decode remains subject to the full barrier. A cross-target fixture may compile construction, but it cannot index, persist, or publish a manifest.

The HostKit actor-private manifest factory first reopens the semantic DAG and every topologically ordered `BASSemanticNodeReceipt`/invocation from the validated result-payload evidence; it derives `orderedNodeReceiptArtifactIDs` exactly from those reopened receipts and accepts no node vector parameter. It then constructs the full `orderedReceipts` from reopened sole-owner evidence in canonical causal order: input/admission/resource receipts, every loop envelope's newly won use receipt + true progress witness + converged terminal receipt, exact verification/final risk outputs, release preparation, randomness owner receipts, broker effect receipts, each K3 activated-state evidence projection's mandatory prepare/commit/attestation plus optional outbox and optional active-state artifacts, and reconciliation receipts. A terminal-effect receipt already present under `.effect` is not duplicated under a state kind; equality with the state projection is still mandatory. It accepts no independent general vector. For every allowed kind it reopens the concrete payload, exact-checks root/type/body/causal predecessor/result fact, and assigns the kind itself. Provider chain-owned proposal/terminal-seal evidence is excluded from this vector and validated only through the two canonical chain artifacts.

The barrier repeats this derivation after reopening `authoritativeResultArtifactID`, DAG, both Provider chains, preparation, and all sole-owner evidence. The complete node vector and complete `(ordinal, kind, ArtifactID)` vector must equal the manifest byte-for-byte—not merely be unique/continuous. Effect IDs equal `result.orderedEffectReceiptArtifactIDs`; `.stateCommitArtifact` IDs in global K3 order equal `result.orderedStateCommitArtifactIDs`; every associated mandatory prepare/commit/attestation, optional outbox/causal predecessor, optional active state, and optional terminal-effect receipt is reopened through whole-projection byte-equal `BASK3ActivatedStateEvidence`, with nil active state legal only for a validated no-op commit; publishable reconciliation is empty. Every loop chain exact-reopens invocation → envelope → prior/current `BASBudgetUseReceipt` → typed progress witness → `BASControlLoopTerminalReceiptPayload(convergedVerified)`. Omission, reordering, duplication, foreign/extra ID, same-ID/different-body substitution, wrong kind, repeated/back-edge digest, or nonterminal loop evidence fails before manifest put/index/publication. Refused/deferred/cancelled/reconcile-required results stop before manifest construction/indexing/resolution. This is equality over reopened owner evidence, not a second disposition or caller-selected list.

For a publishable result, the stateless pre-publication validator reopens all four IDs in `providerReleaseEvidence`: response spool, release preparation, `.terminalPrefix` chain, and `.throughVisibility` chain. It requires each cut exactly, then equality-checks root, installed policy ID, binding ID, terminal source, and terminal-source receipt across both chain payloads. The full `terminalPrefix.orderedEntries` must equal the corresponding leading slice of `throughVisibility.orderedEntries`; no field inside the through payload claims this relationship. Every entry reopens its exact plan/allocation/claim/event-head-seal/proposal receipts, requires one common nonempty `selectedProviderDescriptorArtifactID` across allocation/claim, decodes that Artifact as `BASPersistedOrganDescriptorPayload` through `BASGovernedArtifactPayloadCodec`, and only then unwraps/canonical-validates its descriptor. It has one complete sequence-zero exact-branch `BASProviderExecutionRef` and satisfies policy-derived purpose/role/causality/limits. Recorded events reuse only that same ref type through checked `withRequestSequence`, preserve all six stable base fields, and canonicalize back to the receipt ref at sequence zero; no event-ref wrapper/codec is accepted. Local entries require both seal evidence IDs nil; isolated/remote entries require the exact nonnil arm and `providerObservedReceiptArtifactID`, a complete supervisor observation, and the K3 terminal seal described below. Possible-start/`sent_or_unknown`/unsealed/indeterminate branches cannot become terminal evidence or a later retry.

The unique source entry must equal spool/preparation root, source branch, complete terminal execution ref, and selected proposal. Reopen that entry's `proposalReceiptArtifactID` and `eventHeadSealReceiptArtifactID` as the sole proposal/seal evidence; spool/preparation do not copy a fourth execution-receipt field. Their `terminalSourceReceiptArtifactID` equals the chain's canonical `terminalSourceReceiptArtifactID`. The spool binds only `terminalPrefixProviderBranchChainArtifactID`; preparation/result/manifest bind both IDs and the exact proven prefix relation. The through payload supplies the exact visibility receipt and complete mode-specific L10/incremental evidence. Preparation supplies final-publication branch, verification, risk, grant, destination, and spool ID. Before sovereign preparation installation, the resolver obtains Attempt/generation/epochs only from the injected read-only active K3 Attempt/root/source/final-branch/visibility/joint-coverage view, obtains `sinkProfileDigest` only from the injected host sink profile, and recomputes the boundary instance as the versioned canonical instance-zero projection of the exact reopened final branch. It equality-checks those live facts against the reopened evidence immediately before constructing the request; the manifest copies none of them, and no value is defaulted or accepted from a caller string.

- [ ] **Step 4: Add only a rebuildable source-head-to-artifact-ID index to the existing event log**

Add `.replayManifestIndexed = "replay-manifest-indexed"` to `BASEventLogKind`. Raise the existing SQLite schema version by one and create only this table/index during the current migration transaction:

```sql
CREATE TABLE IF NOT EXISTS replay_manifest_index (
    source_session_id TEXT NOT NULL,
    source_sequence_number INTEGER NOT NULL,
    source_event_id TEXT NOT NULL,
    source_integrity_digest TEXT NOT NULL,
    source_row_hash TEXT NOT NULL,
    manifest_artifact_id TEXT NOT NULL,
    index_event_id TEXT NOT NULL,
    PRIMARY KEY (source_session_id, source_sequence_number),
    UNIQUE (source_event_id),
    UNIQUE (manifest_artifact_id)
);
CREATE INDEX IF NOT EXISTS replay_manifest_source_event_idx
    ON replay_manifest_index(source_event_id);
```

Make `BASSQLiteEventLogStorage` conform to `BASReplayManifestIndexPort`. Every index/rebuild/lookup API begins with `BASTurnOperationRef`; it derives `source_session_id` only via `canonicalLegacyProjection()`, decodes every persisted/event-head session with `BASTurnOperationRef(validatingCanonicalLegacyProjection:)`, and requires equality with the supplied root before selection or mutation. The raw TEXT column is a bounded storage compatibility key, never replay authority. `indexReplayManifest` additionally verifies that the source event plus its `event_log_integrity.row_hash` exactly match the complete `sourceEventHead`, begins `BEGIN IMMEDIATE`, checks the current event-log head, appends one typed `.replayManifestIndexed` event through the existing append/integrity helper, inserts all seven scalar index columns (`source_session_id`, `source_sequence_number`, `source_event_id`, `source_integrity_digest`, `source_row_hash`, `manifest_artifact_id`, and `index_event_id`), and commits both writes together. Every Artifact-ID TEXT bind calls `try artifactID.storageScalar`; every read uses `BASArtifactID(storageScalar:)`. No local root/branch/artifact codec exists. On mismatch/conflict/head movement/tamper/malformed scalar/duplicate binding, roll back.

`rebuildReplayManifestIndex(for turnOperationRef:)` deletes only derived rows whose canonical session projection decodes back to that exact root and reconstructs them from integrity-verified `.replayManifestIndexed` event payloads that carry/equality-check the same typed root. `BASRoutedEventLogStorage` forwards this protocol to the selected integrity-capable SQLite route; it cannot cache or merge competing answers. The in-memory event-log owner may implement an actor-isolated dictionary strictly for tests and ephemeral development, derived from the same indexed events; it is not used for authoritative production composition.

Add this typed-root adapter on the injected event-log owner; there is no global/raw `requiredEventLogHead` helper:

```swift
extension BASEventLogStorage {
    public func requiredHead(
        for turnOperationRef: BASTurnOperationRef
    ) async throws -> BASEventLogHead {
        let sessionID = try turnOperationRef.canonicalLegacyProjection()
        guard let head = try await head(forSession: sessionID),
              try BASTurnOperationRef(
                validatingCanonicalLegacyProjection: head.sessionID
              ) == turnOperationRef else {
            throw BASReplayManifestIndexError.sourceHeadUnavailable
        }
        return head
    }
}
```

Every barrier call must spell `dependencies.k3.requiredHead(for:)`. The adapter encodes through `canonicalLegacyProjection()`, delegates only to the EventLog view on that one injected K3 composite, immediately decodes through `init(validatingCanonicalLegacyProjection:)`, and equality-checks the supplied root. The compatibility string never selects authority without that round trip.

Add one three-storage scalar parity test after the contracts and sovereign prerequisites: put an artifact through `BASArtifactSQLiteStore`, bind the same ID in `BASPublicationJournalSQLiteStorage`, and index it through `BASSQLiteEventLogStorage`; read each raw SQLite TEXT value, require all three equal `try artifactID.storageScalar` byte-for-byte, and require `try BASArtifactID(storageScalar:)` returns the original. Mutate each raw scalar with the contracts plan's malformed corpus and require every storage read to fail closed; none may fall back to JSON, `description`, delimiter splitting, or a local parser.

Register `BASArchitectureReplayManifest` exactly once through the normal metatype registry entry—BASAdmin already depends on BASRuntimeCore—in addition to Task 3's cycle-safe pinned entry for the BASHostKit-owned `BASAuthoritativeTurnResultPayload`. Use exact test IDs `schema.BASArchitectureReplayManifest.current`, `schema.BASArchitectureReplayManifest.backward_v1`, and `schema.BASArchitectureReplayManifest.future_rejection`; do not add a string-only/pinned manifest entry. Every ordinary put, identity payload, and reopen uses only `BASGovernedArtifactPayloadCodec`; raw encoding/decoding and field access before `decodeCurrent` are forbidden. Exact-one object/test-ID, current round-trip, pinned-v1 backward decode, missing/future rejection, registered/current-version parity, alias/helper rejection, and a cross-target public-default-initializer compile fixture pin both payloads independently. Production callsite inventory permits exactly one `BASArchitectureReplayManifest(...)` construction, inside actor-private `makeArchitectureReplayManifest(...)`; public constructibility is not indexing, persistence, or publication authority. `BASReplayManifestIndexBinding` is an operation input and `BASPrePublicationManifestBarrierReceipt` is an actor-private orchestration return; consistent with the contracts plan's governance rule, neither in-memory value is a governed persisted schema.

- [ ] **Step 5: Run GREEN, event-integrity regressions, restart/rebuild tests, and no-manifest-store scan**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASArchitectureReplayManifestTests|BASEventLogTests|BASSQLiteEventLogDualWriteInvariantTests|BASEventLogTamperRedTeamTests|BASEventLogSeqHighWaterMarkTests|BASEventLogFailureInjectionTests|BASRoutedEventLogCorruptSurfacingTests|BASEBrainSchemaGovernanceRegistryTests'
if rg -n 'BASEventLogReplayManifestStore|BASReplayManifestStore|manifest_(json|blob|bytes)|struct BASReplayLaneWatermark|laneWatermarks: \[BASSemanticLaneID:' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources; then
  exit 1
fi
if rg -n 'BASLaneWatermark|[Ww]atermark' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift; then
  exit 1
fi
```

Expected: all selected tests PASS with 0 failures; restart and rebuild return the same typed manifest artifact ID, event tamper fails, and the inverted scans find neither a manifest-byte store nor any manifest-owned watermark field/vector.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASRoutedEventLogStorage.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArchitectureReplayManifestTests.swift
git commit -m "feat: index one artifact-backed replay manifest"
```

### Task 5 [W5 Steps 5A–5B, W6 remainder]: Manifest-Before-Reservation Barrier, Four Replay Modes, and Opt-In Authoritative Runtime

**Wave scheduling:** Execute Steps 5A–5B immediately after the sovereign W5 receipt and commit them separately. Only then execute this task's Steps 1–5 and 6–8 as W6 work. Their physical placement keeps the effect audit beside its runtime integration, but does not authorize W6-before-W5 execution or a mixed-wave commit.

**Files:**
- Modify governed record wrapper owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
- Modify governed record wrapper owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift`
- Modify governed record wrapper owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift`
- Modify governed record wrapper owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventReplayRunner.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEventLogReplayBundle.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/BASAuditReplayEngine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Verify Task-1B frozen envelope; Task 5 only populates its predeclared fields: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeAuditEnvelope.swift`
- Verify Task-1B governed mapping without modifying it: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEventLogEntry+TurnEnvelope.swift`
- Verify Task-1B pinned first/current-1.0.0 entry without modifying it: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify governed record wrapper owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrgan/BASToolCallingPlanner.swift`
- Verify W5 public broker seam: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift`
- Modify W5 signed-subject compatibility: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift`
- Modify W5 signed-subject compatibility: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- Modify W5 signed-subject compatibility: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift`
- Verify W5 adapter: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPrePublicationManifestBarrierTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAuthoritativeSemanticRuntimeTests.swift`
- Modify field-population fixtures without changing the frozen schema: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift`
- Modify full-byte append/reopen population fixtures without changing the mapping: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift`
- Verify Task-1B pinned fixtures without modifying schema expectations: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectReceiptTruthTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASToolCallingPlannerTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASToolDispatcherTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/PropertyDemos/PropertyDemoFixture.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationGateChainTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeAutoStreamL1Tests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeAutoStreamL3L5Tests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeChainBreakRecoveryTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeCoverageTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeCrossSessionTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeDeepReviewTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeGateTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeGenerationTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL10L11AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL12AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL13AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL2AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL6AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL7AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL8AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL9AutoStreamTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeLifecycleTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeM153LegacyParityTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeRenderFrameCapTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSendSessionStreamingTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSessionLifecycleTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostFlowTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoTurnArtifactsBridgeTests.swift`
- Modify W5 signed-subject vectors: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoTokenSigningTests.swift`
- Modify W5 closeout: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/Shared/QinaoTestFixture.swift`
- Verify W5 regression: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeBrokerTests.swift`

**Reuse Decision (R + E/A):** Artifact Mesh already owns manifest/result bytes, the existing event log index resolves source identity, and the sovereign plan owns publication reservation/journal/coordinator. Runtime adds only an actor-private manifest-before-reservation barrier and an exhaustive authoritative branch inside `BASTurnRuntimeEngine`. The existing event/replay/result harnesses gain four typed modes, and all reuse the one HostKit memory-scope helper/ledger rather than adding a replay/publication memory owner. Do not create `BASSemanticRuntimeComposition.swift`, a publication contract/journal/coordinator, a replay executor actor, a manifest store, a memory helper/type/map, or a second result-producing coordinator.

**Interfaces:**
- Consumes: the Silicon plan's typed-root operation, installed policy/binding, exact shared lineage, the two immutable Artifact-Mesh `BASProviderBranchChainPayload` artifacts (`terminalPrefixProviderBranchChainArtifactID` and `throughVisibilityProviderBranchChainArtifactID`), pinned source/execution/visibility/spool/preparation projections, Artifact Mesh, branch-control/index ports, typed executor/result/manifest/replay owners, sovereign release/journal/effects, and W4 ledger/context resolver. K3 event/coverage heads remain separate mutable authority and are reopened independently; Runtime never invokes a Provider or reconstructs branch state.
- Produces: `BASTurnRuntimeEngineConfiguration.productionSemantic(dependencies:)`, the read-only publication resolver, `.semanticDAGAuthoritative`, typed-root actor-private manifest barrier, four replay modes, and `BASEBrainTurnResultReplayHarness.replay(...)`. The authoritative branch joins the same operation and persists/revalidates its full Provider chain; it never invokes a Provider, V1 coordinator, native-Any executor, sibling final candidate, or second spool itself.

- [ ] **Step 1: Write failing barrier ordering, no-hidden-V1, fail-closed, and replay-mode tests**

```swift
import XCTest
@testable import BASHostKit

final class BASPrePublicationManifestBarrierTests: XCTestCase {
    func testPublicationReservationOccursOnlyAfterManifestPutReopenIndexAndLookup() async throws {
        let fixture = makeAuthoritativeFixture()
        _ = await fixture.engine.runTurn(fixture.request)
        let events = await fixture.trace.events
        XCTAssertEqual(events, [
            .manifestArtifactIOStarted,
            .authoritativeResultPut,
            .manifestPut,
            .manifestReopened,
            .manifestIndexed,
            .manifestResolvedBySource,
            .manifestReopenedByResolvedID,
            .semanticSnapshotReopenedAndValidated,
            .manifestArtifactIOCompleted,
            .publicationMemoryStarted,
            .publicationReserved,
            .sinkReleased,
            .publicationFinalized,
            .publicationResolvedByManifest,
            .publicationMemoryCompleted,
            .publicResultReturned
        ])
    }

    func testCrashBeforeBarrierNeverCallsPublicationOwner() async {
        for failpoint in ManifestBarrierFailpoint.beforePublicationCases {
            let fixture = makeAuthoritativeFixture(failpoint: failpoint)
            let result = await fixture.engine.runTurn(fixture.request)
            XCTAssertTrue(result.isTypedFailClosedDisposition)
            let counts = await fixture.counters.snapshot()
            XCTAssertEqual(counts.publicationReservationCount, 0)
            XCTAssertEqual(counts.visibleReleaseCount, 0)
        }
    }

    func testManifestEmbeddedSourceHeadMustEqualIndexedHeadExactly() async {
        let fixture = makeAuthoritativeFixture(
            manifestSourceHeadMutation: .sameRootDifferentSequenceEventOrDigest
        )
        let result = await fixture.engine.runTurn(fixture.request)
        XCTAssertTrue(result.isTypedFailClosedDisposition)
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.manifestIndexCount, 0)
        XCTAssertEqual(counts.publicationReservationCount, 0)
        XCTAssertEqual(counts.visibleReleaseCount, 0)
    }

    func testAuthoritativeModeExecutesSemanticTopologyExactlyOnceAndNeverCallsV1Coordinator() async {
        let fixture = makeAuthoritativeFixture()
        _ = await fixture.engine.runTurn(fixture.request)
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.semanticTopologyExecutionCount, 1)
        XCTAssertEqual(counts.v1CoordinatorRunTurnCount, 0)
        XCTAssertEqual(counts.publicResultCount, 1)
    }

    func testPublicationRecoveryIsDelegatedToSovereignCoordinator() async throws {
        let fixture = makeAuthoritativeFixture(failpoint: .afterVisibleSinkBeforeReply)
        let first = await fixture.engine.runTurn(fixture.request)
        let second = await fixture.engine.runTurn(fixture.request)
        XCTAssertEqual(first, second)
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.visibleReleaseCount, 1)
        XCTAssertEqual(counts.publicationFinalizationCount, 1)
        XCTAssertEqual(counts.runtimePublicationRetryLoopCount, 0)
    }

    func testPublicationMemoryDenialPrecedesEveryPublicationMutation() async {
        let fixture = makeAuthoritativeFixture(failpoint: .publicationMemoryDenied)
        let result = await fixture.engine.runTurn(fixture.request)
        XCTAssertTrue(result.isTypedFailClosedDisposition)
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.manifestRequestResolverCount, 0)
        XCTAssertEqual(counts.publicationReservationCount, 0)
        XCTAssertEqual(counts.capabilityClaimCount, 0)
        XCTAssertEqual(counts.sinkLookupCount, 0)
        XCTAssertEqual(counts.visibleReleaseCount, 0)
        XCTAssertEqual(counts.publicationMarkCount, 0)
        XCTAssertEqual(counts.publicationFinalizationCount, 0)
        let memorySnapshot = await fixture.memoryLedger.snapshot()
        XCTAssertTrue(memorySnapshot.reservations.isEmpty)
    }
}

final class BASAuthoritativeSemanticRuntimeTests: XCTestCase {
    func testAuthoritativeModeIsNowExplicitAndRequiresCompleteDependencies() {
        XCTAssertEqual(
            BASTurnRuntimeMode.semanticDAGAuthoritative.rawValue,
            "semantic-dag-authoritative"
        )
        XCTAssertThrowsError(try BASTurnRuntimeEngineConfiguration.productionSemantic(
            dependencies: incompleteAuthoritativeDependencies()
        ))
    }

    func testEffectReplaySimulatesRecordedReceiptWithoutDispatching() async throws {
        let fixture = makeReplayFixture()
        let verdict = try await BASEBrainTurnResultReplayHarness.replay(
            manifestArtifactID: fixture.manifestArtifactID,
            mode: .effectSimulation,
            dependencies: fixture.dependencies
        )
        XCTAssertTrue(verdict.succeeded)
        let counts = await fixture.counters.snapshot()
        XCTAssertEqual(counts.toolDispatcherCount, 0)
        XCTAssertEqual(counts.effectAdapterCount, 0)
    }

    func testExactNeuralReplayRejectsExecutionBindingOrRuntimeMismatch() async {
        for mutation in ExactNeuralReplayMutation.allCases {
            let fixture = makeReplayFixture(mutation: mutation)
            await XCTAssertThrowsErrorAsync {
                try await BASEBrainTurnResultReplayHarness.replay(
                    manifestArtifactID: fixture.manifestArtifactID,
                    mode: .exactNeural,
                    dependencies: fixture.dependencies
                )
            }
        }
    }

    func testReplayClosesPublicationThroughTheSovereignFinalizedRecord() async throws {
        let fixture = makeReplayFixture()
        let verdict = try await BASEBrainTurnResultReplayHarness.replay(
            manifestArtifactID: fixture.manifestArtifactID,
            mode: .deterministicSemantic,
            dependencies: fixture.dependencies
        )
        XCTAssertTrue(verdict.succeeded)
        let record = try await fixture.publicationCoordinator
            .finalizedPublicationRecord(for: fixture.manifestArtifactID)
        let evidence = fixture.manifest.providerReleaseEvidence
        let preparation = try await fixture.reopenReleasePreparation(
            evidence.releasePreparationArtifactID)
        XCTAssertEqual(record.state, .finalized)
        XCTAssertEqual(record.request.spoolArtifactID, evidence.spoolArtifactID)
        XCTAssertEqual(
            record.request.exactGrantArtifactID,
            preparation.exactGrantArtifactID
        )
        XCTAssertNotNil(record.capabilityUseReceiptArtifactID)
        XCTAssertNotNil(record.sinkReceiptArtifactID)
    }

    func testReplayRejectsEveryIncompleteOrConflictingPublicationClosure() async {
        for mutation in PublicationClosureMutation.allCases {
            let fixture = makeReplayFixture(publicationMutation: mutation)
            await XCTAssertThrowsErrorAsync {
                try await BASEBrainTurnResultReplayHarness.replay(
                    manifestArtifactID: fixture.manifestArtifactID,
                    mode: .deterministicSemantic,
                    dependencies: fixture.dependencies
                )
            }
        }
    }

    func testBarrierAndReplayRejectSnapshotVectorOrSourceHeadTamper() async {
        for mutation in SnapshotReopenMutation.allCases {
            let fixture = makeReplayFixture(snapshotMutation: mutation)
            await XCTAssertThrowsErrorAsync {
                _ = try await BASEBrainTurnResultReplayHarness.replay(
                    manifestArtifactID: fixture.manifestArtifactID,
                    mode: .deterministicSemantic,
                    dependencies: fixture.dependencies
                )
            }
        }
    }

    func testManifestRequestResolverRejectsEveryForgedPrePublicationBinding() async {
        for mutation in RuntimeManifestResolverMutation.allCases {
            let fixture = makeManifestResolverFixture(mutation: mutation)
            await XCTAssertThrowsErrorAsync {
                _ = try await fixture.resolver(
                    fixture.manifestArtifactID,
                    fixture.spoolArtifactID
                )
            }
            let counts = await fixture.counters.snapshot()
            XCTAssertEqual(counts.publicationReservationCount, 0)
            XCTAssertEqual(counts.capabilityClaimCount, 0)
            XCTAssertEqual(counts.sinkReleaseCount, 0)
        }
    }

    func testReplayRejectsProviderChainPolicySourceAndVisibilityMutations() async {
        for mutation in BASReplayProviderMutation.allCases {
            let fixture = makeReplayFixture(providerMutation: mutation)
            await XCTAssertThrowsErrorAsync {
                _ = try await BASEBrainTurnResultReplayHarness.replay(
                    manifestArtifactID: fixture.manifestArtifactID,
                    mode: .deterministicSemantic,
                    dependencies: fixture.dependencies)
            }
            let physicalCalls = await fixture.provider.physicalCalls
            let publicationMutations = await fixture.publicationMutations.value
            XCTAssertEqual(physicalCalls, 0)
            XCTAssertEqual(publicationMutations, 0)
        }
    }

    func testReplayVerifiesBothVisibilityModesAndNoPostGateBranch() async throws {
        for mode in [
            BASProviderVisibilityMode.incrementalVerified,
            .bufferedUntilVerified,
        ] {
            let fixture = makeReplayFixture(visibilityMode: mode)
            _ = try await BASEBrainTurnResultReplayHarness.replay(
                manifestArtifactID: fixture.manifestArtifactID,
                mode: .deterministicSemantic,
                dependencies: fixture.dependencies)
            let physicalCalls = await fixture.provider.physicalCalls
            XCTAssertEqual(physicalCalls, 0)
        }
    }
}
```

Add `testManifestPublicationAndReplayCleanupOnThrowCancellationAndContextDrift`, `testReplayUsesCurrentVerifiedContextNotHistoricalExpiredContext`, and `testCertifiedVerifierAndNeuralHeavyNeverOverlap`. Inject failure/cancellation before and after every reserve/start boundary, at each manifest put/read/index/snapshot reopen, inside lost-reply recovery, after final journal lookup, and during replay reads. Assert the exact pending token is cancelled or exact activation completed, the ledger ends empty, cleanup failure maps to a typed fail-closed result, ordinary verifier/replay work may progress while heavy is occupied, and no two heavy activations ever coexist.

Pin test-only `RuntimeManifestResolverMutation.allCases` to `.missingManifest`, `.unindexedManifest`, `.foreignIndexBinding`, `.sourceHeadMismatch`, `.tamperedManifest`, `.manifestSpoolMismatch`, `.authoritativeResultMismatch`, `.semanticDAGMismatch`, `.semanticSnapshotMismatch`, `.nodeVectorOmission`, `.generalReceiptVectorMutation`, `.stateEvidenceMutation`, `.loopEvidenceMutation`, `.effectEvidenceMutation`, `.missingReleasePreparation`, `.duplicateReleasePreparationReference`, `.tamperedReleasePreparation`, `.releasePreparationSpoolMismatch`, `.verificationMismatch`, `.riskPermitMismatch`, `.exactGrantMismatch`, `.providerPolicyMismatch`, `.providerBranchReceiptMismatch`, `.terminalSourceMismatch`, `.visibilityModeMismatch`, `.visibilityEvidenceMismatch`, and `.laterSiblingFinalCandidate`. No case may invoke a publication owner or Provider; the resolver is read-only Artifact Mesh/K3-receipt validation. Every mutation fails in `BASCompleteReplayEvidenceValidator.validateIndexed` before the coordinator can reserve.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASPrePublicationManifestBarrierTests|BASAuthoritativeSemanticRuntimeTests'
```

Expected: FAIL at compile time because `.semanticDAGAuthoritative`, `productionSemantic(dependencies:)`, `BASArchitectureReplayMode`, and the manifest barrier do not exist.

- [ ] **Step 3: Add one dependency bundle to the existing engine configuration**

Add this composition value to `BASTurnRuntimeEngineConfiguration.swift`; it owns no mutable state:

```swift
package enum BASProviderReplayDecoders {
    package static func branchChain(_ record: BASArtifactMeshRecord) throws
        -> BASProviderBranchChainPayload {
        try BASProviderBranchChainPayload(validatingArtifactRecord: record)
    }
    package static func responseSpool(_ record: BASArtifactMeshRecord) throws
        -> BASResponseSpoolPayload {
        try BASResponseSpoolPayload(validatingArtifactRecord: record)
    }
    package static func releasePreparation(_ record: BASArtifactMeshRecord) throws
        -> BASExactReleasePreparationPayload {
        try BASExactReleasePreparationPayload(validatingArtifactRecord: record)
    }
}

package enum BASReplayEvidenceDecoders {
    package static func semanticDAG(_ record: BASArtifactMeshRecord) throws
        -> BASSemanticTurnDAG {
        try BASSemanticTurnDAG(validatingArtifactRecord: record)
    }
    package static func manifest(_ record: BASArtifactMeshRecord) throws
        -> BASArchitectureReplayManifest {
        try BASArchitectureReplayManifest(validatingArtifactRecord: record)
    }
    package static func authoritativeResult(_ record: BASArtifactMeshRecord) throws
        -> BASAuthoritativeTurnResultPayload {
        try BASAuthoritativeTurnResultPayload(validatingArtifactRecord: record)
    }
    package static func semanticSnapshot(_ record: BASArtifactMeshRecord) throws
        -> BASStateReadSnapshot {
        try BASStateReadSnapshot(validatingArtifactRecord: record)
    }
}

package struct BASSemanticAuthoritativeDependencies: Sendable {
    package let semanticDAGArtifactID: BASArtifactID
    package let semanticDAG: BASSemanticTurnDAG
    package let semanticLayerCellExecutor: BASNativeStageExecutor.SemanticNodeExecutor
    package let turnOperationFactory: BASTurnRuntimeEngine.TurnOperationFactory
    package let semanticArtifactReopener: BASSemanticArtifactReopener
    package let artifactStore: any BASArtifactStorePort
    package let k3: BASRuntimeK3Composite
    package let responseReleaseCoordinator: BASResponseReleaseCoordinator
    package let memoryLedger: BASProcessMemoryLedger
    package let memoryContextGateway: BASMemoryAdmissionContextGateway
}

public enum BASAuthoritativeRuntimeFailure: Error, Sendable, Equatable {
    case missingAuthoritativeComposition
    case semanticTopologyFailed
    case authoritativeResultPersistenceFailed
    case authoritativeResultBindingMismatch
    case manifestPersistenceFailed
    case manifestReopenUnavailable
    case manifestReopenMismatch
    case manifestIndexFailed
    case manifestSourceLookupMismatch
    case manifestBarrierIncomplete
    case providerBranchPolicyMismatch
    case providerBranchChainMismatch
    case terminalProviderSourceMismatch
    case providerVisibilityEvidenceMismatch
    case publicationManifestBindingMismatch
    case publicationEvidenceCardinalityMismatch
    case publicationEvidenceBindingMismatch
    case publicationFinalizationMismatch
    case publicationRecordMissing
    case publicationRecordNotFinalized
    case publicationRecordBindingMismatch
    case publicationRecoveryRequired
    case memoryAdmissionFailed
    case memoryActivationFailed
    case memoryCleanupFailed
}
```

Implement each referenced governed payload's package `init(validatingArtifactRecord:)` beside its existing schema owner. The wrapper first requires the exact object kind and bounded payload length, then calls `BASGovernedArtifactPayloadCodec.decodeCurrent(Self.self, from: record.canonicalPayloadBytes)` as its only payload decoder. It verifies Artifact Mesh identity over those exact canonical bytes, re-encodes only through `BASGovernedArtifactPayloadCodec.canonicalBytes(for:)`, and requires byte equality; missing/future/unknown versions, trailing/oversized/noncanonical bytes, or identity drift fail before any payload field is read. No wrapper, fixed decoder enum, or callsite may invoke `JSONDecoder`, a type-local decoder, a caller-selected accepted-version set, or an alternate canonical encoder. The fixed stateless decoder enums above are the only Runtime call surface and contain no stored closure or replaceable conformer. State prepare/outbox/commit/attestation/active/effect bodies remain decoded by the Task 1 exact semantic reopener's fixed typed methods, which apply this same governed codec rule for every governed parent rather than creating a second generic codec.

Add one explicit **package** throwing initializer containing every stored property above and `package validateComplete()`. It calls `semanticDAG.validateCanonical()`, rejects a noncanonical/missing DAG identity, proves `semanticArtifactReopener.artifactStore === artifactStore` through the accepted package construction token, and accepts exactly one `k3: BASRuntimeK3Composite` object that simultaneously supplies existing EventLog, replay-index, budget-use, Provider-branch, and activated-state-evidence operations. Production injects the single `BASSQLiteEventLogStorage` instance; tests inject one conforming actor. There is no separately injectable `eventLog`, replay-index port, `providerBranchControlPort`, `BASBudgetLeaseControlPort`, `readCurrentPublicationAuthority`, decoder closure/bundle, identity closure, failure-result closure, sink-digest closure, memory-observation closure, or state-evidence closure that could split or fabricate authority.

`BASTurnRuntimeEngine.TurnOperationFactory` is a package stateless value with a `fileprivate` initializer. Its one production static constructor requires the exact artifact-store/K3 identities, installed policy/binding IDs, identity-only `BASOrganRegistry`, value-only preflight resolver, semantic executor, process-shared ledger, and memory gateway; it validates those identities once and stores no closure, ordinal, fallback, or mutable authority. Its only `make(admittedRoot:capabilitySnapshotArtifactID:)` method creates the existing `TurnOperation` after exact root/Attempt/lease/policy/binding reopening. `BASSemanticAuthoritativeDependencies.validateComplete()` proves the factory's opaque accepted-identity token equals the bundle's store/K3/ledger/gateway and DAG executor; a caller cannot inject a differently wired Provider operation.

`BASProviderReplayChainValidator` and `BASPublicationAuthorityValidator` are package stateless functions in the existing engine/configuration files. They take the exact `artifactStore` and exact K3 composite object and call only the fixed bounded decoder enums/typed reopener; callers cannot replace them with closures or bundles. The first reopens the installed policy/binding and every plan/allocation/claim/seal/proposal/terminal-source/visibility/governed descriptor-parent payload, validates its current schema before unwrapping the descriptor, validates sequence-zero refs plus checked event sequences, calls the existing K3 queries, and proves local/isolated/remote seal invariants. The second reads the active Attempt/root, exact source/final-branch/visibility/joint-coverage facts only through that same K3 object immediately before request construction. K3 never parses descriptor/containment/plan bytes. Neither validator allocates, claims, arms, begins hand-off, invokes, reserves, installs, caches, or persists.

The engine reopens `semanticSnapshotArtifactID` only with `artifactStore.read`, applies `BASReplayEvidenceDecoders.semanticSnapshot`, canonical-byte-validates it, then checks typed root/source-head prefix against the same K3/EventLog object. No `reopenSemanticSnapshot` authority closure exists. Add fixed package static `BASRuntimeArtifactIdentityFactory.authoritativeResult(payload:verifiedAttemptRefArtifactID:)` and `.replayManifest(manifest:verifiedAttemptRefArtifactID:)`: each takes the Attempt Artifact ID just re-read from the same K3 object, hard-codes `.attempt(verifiedAttemptRefArtifactID)`, schema/object kind, and derives its complete ordered parent set from the exact payload; neither accepts a caller scope, parent array, raw turn/branch ID, or closure. Add wrong-scope, omitted/extra/reordered-parent, and decoder-bypass mutation/source tests. `BASAuthoritativeRuntimeFailureProjector.make(request:failure:)` is likewise a fixed package static pure function. The runtime stores only `responseReleaseCoordinator`; its exact package `finalizedPublicationRecord(for:)` query delegates to the coordinator's own private journal, so an independently injected `publicationJournal` cannot disagree. Memory admission resolves through the concrete `memoryContextGateway` and observes the exact `memoryLedger` actor. Failures map to typed fail-closed results and never collapse uncertainty into a new Attempt or fresh Provider ordinal.

Add package `productionSemantic(dependencies:) throws -> BASTurnRuntimeEngineConfiguration`. HostKit and BASAppleEdgeWiring are targets in the same Swift package and construct it; Qinao/apps receive the returned public opaque configuration and cannot construct the package dependency bundle. The factory validates canonical DAG, exact shared store/K3/reopener/coordinator identities, integrity-capable event logging, and all nonoptional decoders, sets `.semanticDAGAuthoritative`, and installs no legacy fallback. This task temporarily retains named legacy factories only until Task 7 deletes them; no public/package member exposes `SemanticNodeExecutor` or another package type.

Add package stateless `BASCompleteReplayEvidenceValidator` in the existing engine/configuration files. Its private `reopenAndRederiveOwners` implementation reopens the result, DAG, snapshot, state-market selection, compiled context, every node/invocation/general/loop/state/effect/reconciliation artifact, both Provider chains, spool, preparation, and exact state/source-root evidence through the exact store/reopener/K3 plus the fixed decoder enums; it rederives the complete manifest and requires byte equality. `validateBeforeConditionalIndex` additionally requires the K3-derived source head to equal the manifest source head and the index binding to be absent. `validateIndexed` returns the fully validated `BASArchitectureReplayManifest` directly: it reopens the manifest by ID, requires `k3.replayManifestArtifactID(for:sourceEventHead:)` to return that exact ID with matching integrity/index event, then runs the same complete owner rederivation. There is no structural-only publication/replay validator, wrapper projection, or caller-supplied evidence vector. The barrier uses the first fixed entry before indexing and `validateIndexed` immediately after; both the publication resolver and all replay modes must call `validateIndexed` before any reservation or mode-specific work.

Add this pure static resolver builder to the existing configuration owner so the sovereign coordinator can compile before the runtime manifest type and receive the dependency only after Task 4 exists:

```swift
extension BASTurnRuntimeEngineConfiguration {
    package static func publicationManifestRequestResolver(
        artifactStore: any BASArtifactStorePort,
        k3: BASRuntimeK3Composite,
        semanticArtifactReopener: BASSemanticArtifactReopener
    ) -> BASResponseReleaseCoordinator.PublicationManifestRequestResolver {
        { manifestArtifactID, suppliedSpoolArtifactID in
            let manifest = try await BASCompleteReplayEvidenceValidator
                .validateIndexed(
                    manifestArtifactID: manifestArtifactID,
                    artifactStore: artifactStore,
                    semanticArtifactReopener: semanticArtifactReopener,
                    k3: k3
                )
            try manifest.validateComplete()
            let evidence = manifest.providerReleaseEvidence
            guard evidence.spoolArtifactID == suppliedSpoolArtifactID else {
                throw BASAuthoritativeRuntimeFailure.publicationManifestBindingMismatch
            }

            let releaseReferences = manifest.orderedReceipts.filter {
                $0.kind == .releasePreparation
            }
            let verificationReferences = manifest.orderedReceipts.filter {
                $0.kind == .exactVerification
            }
            let riskReferences = manifest.orderedReceipts.filter {
                $0.kind == .finalRisk
            }
            guard releaseReferences.count == 1,
                  releaseReferences[0].artifactID == evidence.releasePreparationArtifactID,
                  verificationReferences.count == 1,
                  riskReferences.count == 1 else {
                throw BASAuthoritativeRuntimeFailure.publicationEvidenceCardinalityMismatch
            }

            async let prefixRead = artifactStore.read(
                evidence.terminalPrefixProviderBranchChainArtifactID)
            async let throughRead = artifactStore.read(
                evidence.throughVisibilityProviderBranchChainArtifactID)
            async let spoolRead = artifactStore.read(evidence.spoolArtifactID)
            async let preparationRead = artifactStore.read(
                evidence.releasePreparationArtifactID)
            let (prefixRecord, throughRecord, spoolRecord, preparationRecord) =
                try await (prefixRead, throughRead, spoolRead, preparationRead)
            let terminalPrefix = try BASProviderReplayDecoders.branchChain(prefixRecord)
            let throughVisibility = try BASProviderReplayDecoders.branchChain(throughRecord)
            let spool = try BASProviderReplayDecoders.responseSpool(spoolRecord)
            let preparation = try BASProviderReplayDecoders
                .releasePreparation(preparationRecord)

            let prefixCount = terminalPrefix.orderedEntries.count
            guard terminalPrefix.cut == .terminalPrefix,
                  throughVisibility.cut == .throughVisibility,
                  throughVisibility.orderedEntries.count >= prefixCount,
                  Array(throughVisibility.orderedEntries.prefix(prefixCount)) ==
                    terminalPrefix.orderedEntries,
                  terminalPrefix.turnOperationRef == manifest.turnOperationRef,
                  throughVisibility.turnOperationRef == manifest.turnOperationRef,
                  terminalPrefix.providerBranchPolicyArtifactID ==
                    throughVisibility.providerBranchPolicyArtifactID,
                  terminalPrefix.executionBindingArtifactID ==
                    throughVisibility.executionBindingArtifactID,
                  terminalPrefix.terminalAnswerSourceBranchRef ==
                    throughVisibility.terminalAnswerSourceBranchRef,
                  terminalPrefix.terminalSourceReceiptArtifactID ==
                    throughVisibility.terminalSourceReceiptArtifactID,
                  let visibilityReceipt =
                    throughVisibility.providerVisibilityReceiptArtifactID else {
                throw BASAuthoritativeRuntimeFailure.providerBranchChainMismatch
            }

            let sourceEntries = terminalPrefix.orderedEntries.filter {
                $0.providerEgressBranchRef ==
                    terminalPrefix.terminalAnswerSourceBranchRef
            }
            guard sourceEntries.count == 1 else {
                throw BASAuthoritativeRuntimeFailure.terminalProviderSourceMismatch
            }
            let sourceEntry = sourceEntries[0]
            guard spool.turnOperationRef == manifest.turnOperationRef,
                  spool.terminalAnswerSourceProviderEgressBranchRef ==
                    sourceEntry.providerEgressBranchRef,
                  spool.terminalProviderExecutionRef ==
                    sourceEntry.providerExecutionRef,
                  spool.selectedCandidateArtifactID == sourceEntry.proposalArtifactID,
                  spool.terminalSourceReceiptArtifactID ==
                    terminalPrefix.terminalSourceReceiptArtifactID,
                  spool.terminalPrefixProviderBranchChainArtifactID ==
                    evidence.terminalPrefixProviderBranchChainArtifactID,
                  preparation.turnOperationRef == manifest.turnOperationRef,
                  preparation.terminalAnswerSourceProviderEgressBranchRef ==
                    sourceEntry.providerEgressBranchRef,
                  preparation.terminalProviderExecutionRef ==
                    sourceEntry.providerExecutionRef,
                  preparation.terminalSourceReceiptArtifactID ==
                    terminalPrefix.terminalSourceReceiptArtifactID,
                  preparation.providerVisibilityReceiptArtifactID == visibilityReceipt,
                  preparation.terminalPrefixProviderBranchChainArtifactID ==
                    evidence.terminalPrefixProviderBranchChainArtifactID,
                  preparation.throughVisibilityProviderBranchChainArtifactID ==
                    evidence.throughVisibilityProviderBranchChainArtifactID,
                  preparation.finalPublicationBranchRef == spool.finalPublicationBranchRef,
                  preparation.spoolArtifactID == evidence.spoolArtifactID,
                  preparation.verificationArtifactID ==
                    verificationReferences[0].artifactID,
                  preparation.riskPermitArtifactID == riskReferences[0].artifactID else {
                throw BASAuthoritativeRuntimeFailure.publicationEvidenceBindingMismatch
            }

            try await BASProviderReplayChainValidator.validate(
                manifest: manifest,
                terminalPrefix: terminalPrefix,
                throughVisibility: throughVisibility,
                spool: spool,
                preparation: preparation,
                artifactStore: artifactStore,
                k3: k3
            )
            let finalBranch = preparation.finalPublicationBranchRef
            guard finalBranch.kind == .finalPublication,
                  finalBranch.ordinal == 0,
                  finalBranch.turnOperationRef == manifest.turnOperationRef else {
                throw BASAuthoritativeRuntimeFailure.publicationManifestBindingMismatch
            }
            let publicationBoundaryInstanceID =
                try finalBranch.canonicalLegacyProjection()
            guard try BASTurnBranchRef(
                validatingCanonicalLegacyProjection: publicationBoundaryInstanceID
            ) == finalBranch else {
                throw BASAuthoritativeRuntimeFailure.publicationManifestBindingMismatch
            }
            let current = try await BASPublicationAuthorityValidator.readCurrent(
                turnOperationRef: manifest.turnOperationRef,
                finalPublicationBranchRef: finalBranch,
                sourceProviderEgressBranchRef: sourceEntry.providerEgressBranchRef,
                visibilityReceiptArtifactID: visibilityReceipt,
                throughVisibilityChainArtifactID:
                    evidence.throughVisibilityProviderBranchChainArtifactID,
                k3: k3
            )
            let currentSinkProfileDigest =
                preparation.destination.canonicalDestinationDigest
            guard !currentSinkProfileDigest.isEmpty else {
                throw BASAuthoritativeRuntimeFailure.publicationEvidenceBindingMismatch
            }

            return BASPublicationReservationRequest(
                idempotencyKey: try BASPublicationReservationRequest.canonicalIdempotencyKey(
                    finalPublicationBranchRef: finalBranch,
                    publicationBoundaryInstanceID: publicationBoundaryInstanceID,
                    replayManifestArtifactID: manifestArtifactID
                ),
                turnOperationRef: manifest.turnOperationRef,
                terminalAnswerSourceProviderEgressBranchRef:
                    sourceEntry.providerEgressBranchRef,
                terminalProviderExecutionRef: sourceEntry.providerExecutionRef,
                terminalSourceReceiptArtifactID:
                    terminalPrefix.terminalSourceReceiptArtifactID,
                providerVisibilityReceiptArtifactID: visibilityReceipt,
                terminalPrefixProviderBranchChainArtifactID:
                    evidence.terminalPrefixProviderBranchChainArtifactID,
                throughVisibilityProviderBranchChainArtifactID:
                    evidence.throughVisibilityProviderBranchChainArtifactID,
                finalPublicationBranchRef: finalBranch,
                publicationBoundaryInstanceID: publicationBoundaryInstanceID,
                spoolArtifactID: evidence.spoolArtifactID,
                releasePreparationArtifactID: evidence.releasePreparationArtifactID,
                replayManifestArtifactID: manifestArtifactID,
                verificationArtifactID: preparation.verificationArtifactID,
                riskPermitArtifactID: preparation.riskPermitArtifactID,
                exactGrantArtifactID: preparation.exactGrantArtifactID,
                destination: preparation.destination,
                sinkProfileDigest: currentSinkProfileDigest,
                attemptRefArtifactID: current.attemptRefArtifactID,
                generationVectorArtifactID: current.generationVectorArtifactID,
                policyEpoch: current.policyEpoch,
                deletionEpoch: current.deletionEpoch
            )
        }
    }
}
```

The closure has only the exact Artifact Mesh, exact K3 composite object, pure bounded decoders, package stateless validators, and host-configured sink-profile projection. It receives no publication journal, token authority, sink call, coordinator, ordinal allocator, installer, or alternate authority-reading closure and cannot allocate, claim, arm, invoke, release, mark, finalize, cache, or persist. It reopens both immutable chain artifacts, spool, and preparation; proves the exact ordered-entry prefix; reopens source-entry proposal/seal receipts through the nonreplaceable package validator; rechecks live K3 Attempt/generation/epochs and sink profile; derives the boundary instance only from the exact ordinal-zero final branch's canonical projection; and constructs the full sovereign request unchanged. Only after it returns does the sovereign coordinator install/revalidate preparation. `BASChengluHostRuntimeBuilder+CoreML` constructs the resolver from the same `artifactStore + k3 + decoder bundles`, injects it into the prerequisite sovereign coordinator, then stores that exact coordinator in `BASSemanticAuthoritativeDependencies`; no source dependency points from sovereign contracts back to the runtime manifest type.

Append this runtime mode only now:

```swift
public enum BASTurnRuntimeMode:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case v1ByteEqual = "v1-byte-equal"
    case nativeV2 = "native-v2"
    case stressSweepDual = "stress-sweep-dual"
    case semanticDAGShadow = "semantic-dag-shadow"
    case semanticDAGAuthoritative = "semantic-dag-authoritative"
}
```

Update mode bridges and exact-count tests to five cases. The environment bridge may decode the raw value for diagnostics, but constructing an authoritative engine without `productionSemantic(dependencies:)` throws `missingAuthoritativeComposition`; it never falls back to V1. Unknown values keep the existing explicit legacy diagnostic until Task 7 removes environment selection from the production entrypoint.

- [ ] **Step 4: Implement the actor-private manifest-before-reservation barrier**

Inside `BASTurnRuntimeEngine`, implement this exact sequence:

```swift
private func persistReopenAndIndexManifest(
    resultPayload: BASAuthoritativeTurnResultPayload,
    makeIndexEvent: @Sendable (
        BASArtifactID,
        BASEventLogHead
    ) throws -> BASEventLogEntry,
    dependencies: BASSemanticAuthoritativeDependencies
) async throws -> BASPrePublicationManifestBarrierReceipt {
    try resultPayload.validatedForPrePublication()
    let sourceEventHead = try await dependencies.k3.requiredHead(
        for: resultPayload.turnOperationRef)
    let verifiedAttemptRefArtifactID = try await BASPublicationAuthorityValidator
        .requiredAttemptRef(
            turnOperationRef: resultPayload.turnOperationRef,
            k3: dependencies.k3)

    let resultReceipt = try await dependencies.artifactStore.put(
        identityCore: try BASRuntimeArtifactIdentityFactory.authoritativeResult(
            payload: resultPayload,
            verifiedAttemptRefArtifactID: verifiedAttemptRefArtifactID),
        headUpdate: nil
    )
    let resultArtifactID = resultReceipt.body.artifactID
    let reopenedResult = try BASReplayEvidenceDecoders.authoritativeResult(
        try await dependencies.artifactStore.read(resultArtifactID)
    )
    guard reopenedResult == resultPayload else {
        throw BASAuthoritativeRuntimeFailure.authoritativeResultBindingMismatch
    }
    switch try reopenedResult.derivedDisposition() {
    case .completedExact, .completedWithEffect:
        break
    case .refused, .deferred, .cancelled, .reconcileRequired:
        throw BASAuthoritativeRuntimeFailure.manifestBarrierIncomplete
    }

    let manifest = try await makeArchitectureReplayManifest(
        resultArtifactID: resultArtifactID,
        authoritativeResult: reopenedResult,
        sourceEventHead: sourceEventHead,
        dependencies: dependencies
    )
    try await validateManifestAgainstReopenedOwners(
        manifest,
        resultArtifactID: resultArtifactID,
        authoritativeResult: reopenedResult,
        sourceEventHead: sourceEventHead,
        dependencies: dependencies
    )
    let evidence = manifest.providerReleaseEvidence

    let manifestReceipt = try await dependencies.artifactStore.put(
        identityCore: try BASRuntimeArtifactIdentityFactory.replayManifest(
            manifest: manifest,
            verifiedAttemptRefArtifactID: verifiedAttemptRefArtifactID),
        headUpdate: nil
    )
    let manifestArtifactID = manifestReceipt.body.artifactID
    let firstRead = try await dependencies.artifactStore.read(manifestArtifactID)
    let firstManifest = try BASReplayEvidenceDecoders.manifest(firstRead)
    try await validateManifestAgainstReopenedOwners(
        firstManifest,
        resultArtifactID: resultArtifactID,
        authoritativeResult: reopenedResult,
        sourceEventHead: sourceEventHead,
        dependencies: dependencies
    )
    guard firstManifest == manifest else {
        throw BASAuthoritativeRuntimeFailure.manifestReopenMismatch
    }
    try await BASCompleteReplayEvidenceValidator.validateBeforeConditionalIndex(
        manifestArtifactID: manifestArtifactID,
        expectedManifest: firstManifest,
        expectedSourceEventHead: sourceEventHead,
        artifactStore: dependencies.artifactStore,
        semanticArtifactReopener: dependencies.semanticArtifactReopener,
        k3: dependencies.k3)
    let latestSourceEventHead = try await dependencies.k3.requiredHead(
        for: resultPayload.turnOperationRef)
    guard latestSourceEventHead == sourceEventHead else {
        throw BASAuthoritativeRuntimeFailure.manifestSourceLookupMismatch
    }
    let indexEvent = try makeIndexEvent(manifestArtifactID, sourceEventHead)
    _ = try await dependencies.k3.indexReplayManifest(
        BASReplayManifestIndexBinding(
            turnOperationRef: resultPayload.turnOperationRef,
            sourceEventHead: sourceEventHead,
            manifestArtifactID: manifestArtifactID
        ),
        indexEvent: indexEvent,
        ifCurrentHead: sourceEventHead
    )
    let resolvedID = try await dependencies.k3.replayManifestArtifactID(
        for: resultPayload.turnOperationRef,
        sourceEventHead: sourceEventHead
    )
    guard resolvedID == manifestArtifactID else {
        throw BASAuthoritativeRuntimeFailure.manifestSourceLookupMismatch
    }
    let indexedManifest = try await BASCompleteReplayEvidenceValidator
        .validateIndexed(
            manifestArtifactID: manifestArtifactID,
            artifactStore: dependencies.artifactStore,
            semanticArtifactReopener: dependencies.semanticArtifactReopener,
            k3: dependencies.k3)
    guard indexedManifest == manifest,
          try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: sourceEventHead.sessionID
          ) == manifest.turnOperationRef,
          indexedManifest.providerReleaseEvidence == evidence else {
        throw BASAuthoritativeRuntimeFailure.manifestBarrierIncomplete
    }
    return BASPrePublicationManifestBarrierReceipt(
        turnOperationRef: manifest.turnOperationRef,
        manifestArtifactID: manifestArtifactID,
        sourceEventHead: sourceEventHead,
        authoritativeResultArtifactID: resultArtifactID,
        providerReleaseEvidence: evidence
    )
}

private func makeArchitectureReplayManifest(
    resultArtifactID: BASArtifactID,
    authoritativeResult: BASAuthoritativeTurnResultPayload,
    sourceEventHead: BASEventLogHead,
    dependencies: BASSemanticAuthoritativeDependencies
) async throws -> BASArchitectureReplayManifest {
    let dagRecord = try await dependencies.artifactStore.read(
        dependencies.semanticDAGArtifactID)
    let dag = try BASReplayEvidenceDecoders.semanticDAG(dagRecord)
    guard dag == dependencies.semanticDAG else {
        throw BASAuthoritativeRuntimeFailure.manifestBarrierIncomplete
    }
    let evidence = try await reopenAndDeriveCanonicalManifestEvidence(
        dag: dag,
        authoritativeResult: authoritativeResult,
        sourceEventHead: sourceEventHead,
        artifactStore: dependencies.artifactStore,
        k3: dependencies.k3,
        semanticReopener: dependencies.semanticArtifactReopener
    )
    guard evidence.orderedNodeReceiptArtifactIDs ==
            authoritativeResult.orderedNodeReceiptArtifactIDs,
          evidence.orderedEffectReceiptArtifactIDs ==
            authoritativeResult.orderedEffectReceiptArtifactIDs,
          evidence.orderedStateCommitArtifactIDs ==
            authoritativeResult.orderedStateCommitArtifactIDs,
          evidence.orderedReconciliationReceiptArtifactIDs ==
            authoritativeResult.orderedReconciliationReceiptArtifactIDs else {
        throw BASAuthoritativeRuntimeFailure.authoritativeResultBindingMismatch
    }
    return try BASArchitectureReplayManifest(
        turnOperationRef: authoritativeResult.turnOperationRef,
        sourceEventHead: sourceEventHead,
        authoritativeResultArtifactID: resultArtifactID,
        semanticDAGArtifactID: dependencies.semanticDAGArtifactID,
        semanticSnapshotArtifactID: evidence.semanticSnapshotArtifactID,
        stateMarketSelectionArtifactID: evidence.stateMarketSelectionArtifactID,
        compiledContextDescriptorArtifactID:
            evidence.compiledContextDescriptorArtifactID,
        providerReleaseEvidence: try requirePublishableReleaseEvidence(
            authoritativeResult.providerReleaseEvidence),
        validatedNodeReceiptArtifactIDs:
            evidence.orderedNodeReceiptArtifactIDs,
        validatedReceipts: evidence.orderedGeneralReceipts
    )
}

private func validateManifestAgainstReopenedOwners(
    _ candidate: BASArchitectureReplayManifest,
    resultArtifactID: BASArtifactID,
    authoritativeResult: BASAuthoritativeTurnResultPayload,
    sourceEventHead: BASEventLogHead,
    dependencies: BASSemanticAuthoritativeDependencies
) async throws {
    let derived = try await makeArchitectureReplayManifest(
        resultArtifactID: resultArtifactID,
        authoritativeResult: authoritativeResult,
        sourceEventHead: sourceEventHead,
        dependencies: dependencies
    )
    guard candidate == derived,
          candidate.semanticDAGArtifactID == dependencies.semanticDAGArtifactID,
          candidate.authoritativeResultArtifactID == resultArtifactID,
          candidate.turnOperationRef == authoritativeResult.turnOperationRef,
          candidate.sourceEventHead == sourceEventHead,
          candidate.providerReleaseEvidence ==
            authoritativeResult.providerReleaseEvidence else {
        throw BASAuthoritativeRuntimeFailure.manifestReopenMismatch
    }
    let release = try await reopenProviderReleaseEvidence(
        candidate.providerReleaseEvidence,
        expectedRoot: candidate.turnOperationRef,
        dependencies: dependencies
    )
    try await BASProviderReplayChainValidator.validate(
        manifest: candidate,
        terminalPrefix: release.terminalPrefix,
        throughVisibility: release.throughVisibility,
        spool: release.spool,
        preparation: release.preparation,
        artifactStore: dependencies.artifactStore,
        k3: dependencies.k3
    )
    let snapshotRecord = try await dependencies.artifactStore.read(
        candidate.semanticSnapshotArtifactID)
    let snapshot = try BASReplayEvidenceDecoders.semanticSnapshot(snapshotRecord)
    try snapshot.validateComplete()
    guard snapshot.turnOperationRef == candidate.turnOperationRef,
          try BASTurnOperationRef(
            validatingCanonicalLegacyProjection: snapshot.eventLogHead.sessionID
          ) == candidate.turnOperationRef,
          snapshot.eventLogHead.sequenceNumber <= sourceEventHead.sequenceNumber else {
        throw BASAuthoritativeRuntimeFailure.manifestBarrierIncomplete
    }
}

private func reopenProviderReleaseEvidence(
    _ evidence: BASProviderReleaseEvidenceReference,
    expectedRoot: BASTurnOperationRef,
    dependencies: BASSemanticAuthoritativeDependencies
) async throws -> (
    terminalPrefix: BASProviderBranchChainPayload,
    throughVisibility: BASProviderBranchChainPayload,
    spool: BASResponseSpoolPayload,
    preparation: BASExactReleasePreparationPayload
) {
    async let prefixRead = dependencies.artifactStore.read(
        evidence.terminalPrefixProviderBranchChainArtifactID)
    async let throughRead = dependencies.artifactStore.read(
        evidence.throughVisibilityProviderBranchChainArtifactID)
    async let spoolRead = dependencies.artifactStore.read(evidence.spoolArtifactID)
    async let preparationRead = dependencies.artifactStore.read(
        evidence.releasePreparationArtifactID)
    let (prefixRecord, throughRecord, spoolRecord, preparationRecord) =
        try await (prefixRead, throughRead, spoolRead, preparationRead)
    let prefix = try BASProviderReplayDecoders.branchChain(prefixRecord)
    let through = try BASProviderReplayDecoders.branchChain(throughRecord)
    let spool = try BASProviderReplayDecoders.responseSpool(spoolRecord)
    let preparation = try BASProviderReplayDecoders.releasePreparation(
        preparationRecord)
    guard prefix.cut == .terminalPrefix,
          through.cut == .throughVisibility,
          prefix.turnOperationRef == expectedRoot,
          through.turnOperationRef == expectedRoot,
          through.orderedEntries.count >= prefix.orderedEntries.count,
          Array(through.orderedEntries.prefix(prefix.orderedEntries.count)) ==
            prefix.orderedEntries,
          spool.turnOperationRef == expectedRoot,
          spool.terminalPrefixProviderBranchChainArtifactID ==
            evidence.terminalPrefixProviderBranchChainArtifactID,
          preparation.turnOperationRef == expectedRoot,
          preparation.spoolArtifactID == evidence.spoolArtifactID,
          preparation.terminalPrefixProviderBranchChainArtifactID ==
            evidence.terminalPrefixProviderBranchChainArtifactID,
          preparation.throughVisibilityProviderBranchChainArtifactID ==
            evidence.throughVisibilityProviderBranchChainArtifactID else {
        throw BASAuthoritativeRuntimeFailure.providerBranchChainMismatch
    }
    return (prefix, through, spool, preparation)
}
```

`reopenAndDeriveCanonicalManifestEvidence` is an actor-private async helper, not an injected closure or store. It traverses the reopened DAG in canonical topology; reopens every invocation and node receipt; derives the exact node vector; obtains semantic-snapshot, State-Market-selection, and compiled-context Artifact IDs only from the typed outputs of their sole owning nodes; and reopens/canonical-byte-validates those three payloads. It derives the complete general vector in causal order from reopened normalization/admission/resource/loop/exact-verification/final-risk/release-preparation/randomness/broker-effect/K3-state-lifecycle/reconciliation evidence. For each state commit it repeats the same K3 `lookupActivatedStateEvidence`, requires whole-projection byte equality (including event ID/sequence, K3-recomputed source root, epochs, and every optional), and applies the exact Task 3 reopen rules to mandatory prepare/commit/attestation, optional outbox plus causal predecessor, optional active state, and optional terminal-effect receipt/outcome. Nil active state is accepted only for the reopened canonical no-op commit. For every loop it exact-reopens invocation → envelope → prior/current budget use → typed witness → `BASControlLoopTerminalReceiptPayload`, admitting only `convergedVerified`. It assigns receipt kinds from decoded concrete types and accepts no top-level ID or node/general vector parameter.

The manifest factory receives `resultReceipt.body.artifactID` only after Artifact Mesh assigns it; the index-event constructor similarly receives `manifestReceipt.body.artifactID` plus the just-read typed-root K3/EventLog head. Neither ID nor predecessor is guessed. Both puts are ordinary. Preserve this order: result put/reopen → full owner-evidence reopen/rederive/exact validation → manifest put → manifest reopen plus full reopen/rederive/exact validation → a third full validation immediately before the typed-root conditional index → source lookup → manifest reopen plus a fourth full validation immediately before publication eligibility → barrier receipt. Every full validation equality-checks the entire manifest, both ordered vectors, DAG/snapshot/market/context/result/source top-level references, state evidence, complete loop chains, and Provider release group; not merely effect/state subsets. `sourceEventHead.sessionID` is used only after Contracts codec round-trip to `turnOperationRef`; no raw session lookup selects authority. The barrier never allocates/claims/invokes a Provider or reserves publication.

At the authoritative call site, wrap this entire function once with `withProcessMemoryAdmission`: use the existing release-preparation artifact ID as `workRootArtifactID` for an exact path and its terminal node-receipt artifact ID for refused/deferred/cancelled/reconciliation paths; use `.artifactIO/.responseSpoolAndArtifactBuffer/.ordinary`. `residentBytes` is zero and `maxTransientBytes` is the checked bound for result/manifest encoding, store records, index-event bytes, and snapshot reopen buffers. The helper resolves the turn context at reserve and immediately before start and retires the exact token/activation on every exit. Do not put a second scope around individual store calls or count neural/verifier allocations inside this Artifact-I/O bound.

- [ ] **Step 5: Add the fail-closed authoritative branch without a hidden V1 call**

Replace runtime dispatch with an exhaustive switch. The authoritative case:

1. joins the one typed-root `TurnOperation`, executes semantic topology once, and reuses unchanged its two immutable terminal-prefix/through-visibility chain Artifact IDs plus reopened source/execution, visibility evidence, spool, and preparation; K3 event/coverage heads remain separate and runtime starts no Provider branch;
2. constructs one `BASAuthoritativeTurnResultPayload` around the semantic path's `BASEBrainTurnResult`, carrying only the exact sovereign four-ID release reference and no copied lineage or raw authority;
3. stores that payload, constructs/stores/reopens/indexes/reopens the complete manifest, reopens the sole `BASProviderBranchPolicy`/binding/branch receipts through the stateless validator, and obtains one exact-equality `BASPrePublicationManifestBarrierReceipt`;
4. calls the sovereign-owned `responseReleaseCoordinator.publishExact(after: barrier.manifestArtifactID, spoolArtifactID: barrier.providerReleaseEvidence.spoolArtifactID)` once;
5. verifies the returned `BASPublicationFinalization` has exactly the same manifest/spool, plus valid capability-use/sink receipts; resolves the same finalized journal row and requires it to match the manifest's exact grant and the barrier's typed root, pinned terminal-source chain, final-publication branch, spool, and preparation evidence;
6. returns `resultPayload.publicResult()` exactly once.

Immediately after the manifest Artifact-I/O activation completes, acquire a distinct ordinary request rooted at `barrier.manifestArtifactID` with `.responsePublication/.responseSpoolAndArtifactBuffer`, zero resident bytes, and a checked transient bound for manifest/preparation/spool/sink-receipt/recovery buffers. Its single scoped operation contains the unchanged `responseReleaseCoordinator.publishExact(after:spoolArtifactID:)` call, sovereign lost-reply recovery, finalization validation, and the final `responseReleaseCoordinator.finalizedPublicationRecord(for:)` read through that same coordinator object; the successful path completes only after the coordinator's private-journal query proves a known terminal state, while throw/cancellation retires the exact activation before producing the typed reconciliation disposition. Memory admission/start denial therefore precedes the manifest-request resolver, journal reserve, K4 claim, sink lookup/release, journal mark, and finalization. Never inject a journal into Runtime/replay, pass a reservation/context/token into `publishExact`, alter its signature, or split recovery into a second activation.

On an error before publication reservation, call only fixed package static `BASAuthoritativeRuntimeFailureProjector.make(request:failure:)` to create a typed refused/deferred/cancelled/reconcile disposition in `BASEBrainTurnResult`. On a lost reply after possible visibility, call the sovereign coordinator's recovery surface with the same barrier; it owns lookup/dedup/finalization. Runtime has no retry loop or publication state. Never call `coordinator.runTurn`, `runWithPlan`'s legacy result closure, a provider directly, or an alternate sink from this branch.

Task 1B already declared `authoritativeResultArtifactID`, `replayManifestArtifactID`, `publicationCapabilityUseReceiptArtifactID`, and `publicationSinkReceiptArtifactID` in the complete first-governed envelope 1.0.0. Task 5 only populates those optionals after reopening the exact referenced artifacts. It performs no envelope source, mapping, codec, version, migration, or registry change. Tests require the frozen Task-1B canonical bytes to remain stable while nil early-phase fields become exact nonnil IDs in the one final `.complete` value.

`BASEventLogEntry+TurnEnvelope` continues to store the complete governed bytes under its exact marker and equality-check indexed columns. The final `.complete` envelope records the authoritative-result and manifest Artifact IDs that passed the pre-publication barrier plus the capability-use and sink-receipt Artifact IDs returned by sovereign finalization; all four survive append/reopen exactly. It does not invent a reservation/finalization artifact ID, copy the journal record, or determine whether publication is allowed. Failure/early envelopes may carry nil only where their typed phase/result makes publication impossible; a finalized result requires all four nonnil and reopens them before the throwing audit append. Because the sink may already have crossed before `publicationSinkReceiptArtifactID` exists, an audit-append failure cannot roll back or blindly repeat publication: the nonthrowing engine records the typed failure, returns its one already-owned result, and leaves replay/certification/audit-complete status red. Only the live owner may retry identical retained bytes. After a crash, the sovereign journal resolves the already-published-or-unknown outcome, but the missing envelope remains permanently audit-incomplete and its orphan bundle may be collected; recovery never reruns semantics, reconstructs the bundle, or calls the sink again. The private legacy membrane can never project any of these fields. `BASEBrainTurnResult` remains the only return type.

- [ ] **Step 5A [W5]: Remove synthetic execution receipts and close every direct-effect path**

Delete `buildSovereignExecutionReceipts` from `EBrainRuntimeCoordinator+SovereignCommit.swift` and remove its call in `EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift`. A command, tool invocation, proposal, state outbox, or runtime trace can produce only proposed/pending evidence. The authoritative result's ordered effect receipt IDs come only from `BASEffectBroker` Artifact Mesh store receipts after its durable dispatch/ack/indeterminate/reconcile transition. Reopen and validate each `BASEffectReceiptPayload`'s directly stored outcome/adapter/boundary/outbox facts, then follow its permit → `BASEffectDispatchReadyReceiptPayload`/K3 evidence graph to recover and exact-check the typed Zone-C tuple `(turnOperationRef, effectBranchRef, effectBoundaryInstanceID, outboxArtifactID, boundSubjectArtifactID, canonicalRequestDigest, sourceK3RootArtifactID)` plus the receipt-reachable anchor/arm/grant-use evidence. The final receipt does not directly store `boundSubjectArtifactID`, `canonicalRequestDigest`, or `sourceK3RootArtifactID`; the seven-field tuple is the complete prepared-context/equality binding. The authoritative Zone-C journal uniqueness key remains exactly `(turnOperationRef, effectBranchRef, effectBoundaryInstanceID)`; the other four fields are equality-checked, and no additional identifier may be synthesized.

Make `BASToolDispatcher.dispatch` and `dispatchBatch` package-scoped. Remove the dispatcher dependency and `dispatchBatch` call from `BASToolCallingPlanner`; its `.invokeTools` decision emits existing `BASToolInvocation` values through one injected stateless `BASToolProposalResolutionPort`. The authoritative port belongs to `TurnOperation`: only after a successful sealed `.turnStep/.internalProposal` tool proposal does it obtain effect authorization, await the durable `BASEffectBroker` receipt, reopen/current-version decode the governed `BASPersistedToolResultPayload` through `BASGovernedArtifactPayloadCodec`, and unwrap/equality-check its unchanged embedded `BASToolResult`. No independent raw `BASToolResult` Artifact put/reopen exists. It then submits only the unchanged installed policy ID, frozen next `stepRuleID`, requested output role, exact materialized plan proof, and ordered prior-proposal/broker/governed-result causes to the already-composed Silicon planned-execution delegate. It does not restate `.turnStep`, choose a route/ordinal, or call `allocateProviderBranch`/`claimProviderExecution` itself. Silicon completes capability/Pareto/fallback selection before allocation, K3 derives purpose and freezes the branch/ref/plan/causes, and only `BASProviderAttemptExecutor.executeExactlyOnce` may cross into `BASOrganAdapter.executePlanned` on the newly won claim.

For every route, the sole Silicon seam reopens the exact `selectedProviderDescriptorArtifactID` copied through allocation/claim as `BASPersistedOrganDescriptorPayload`, version-checks it through `BASGovernedArtifactPayloadCodec`, canonical-byte-compares the unwrapped descriptor to the selected adapter, and derives its required `BASProviderContainmentClass`; a caller-loose Provider ID or containment projection is not authority. Local `inProcessCertified` requires both `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID` nil. `isolatedExtension`/`remote` requires both nonnil. Before its one invoke closure, the same executor—not an outer runtime wrapper or adapter—reopens/equality-checks the sovereign `BASProviderEgressBoundaryPermit`, K4 anchor, K3 arm receipt, receipt-bound governed parent/descriptor, plan/materialized payload/destination, and still-live hand-off deadline, then calls package-only same-owner `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` on the same injected concrete `BASSQLiteEventLogStorage` object that supplies the public branch/control-nucleus views. Only the fresh `egress_boundary_armed → sent_or_unknown` CAS winner gets callable `.won`; exact replay gets non-callable `.alreadyPossible`, so crash/recovery cannot resend. No public K3 protocol exposes callable hand-off.

After a complete isolated/remote result, the existing Qinao endpoint supervisor constructs the shared self-ID-free `BASProviderObservedReceipt` declared as E in `BASLowEntropyPrimitives.swift`; Runtime declares no observation owner. The executor ordinary-puts/reopens it and calls existing `sealProviderEventHead` with the exact paired arm/observation IDs. In the one K3 seal transaction, K3 follows only its own allocation/claim/boundary rows plus arm → permit/anchor, exact-checks root/branch/sequence-zero execution claim/governed descriptor-parent ID/Attempt/generation/epochs/grant/use receipt and the complete authenticated observation, then atomically advances `sent_or_unknown → terminal_or_indeterminate` with the bounded head and seal receipt. K3 never parses the descriptor parent/binding or derives containment; Runtime replay decodes the governed parent through `BASGovernedArtifactPayloadCodec`, unwraps its selected descriptor, and rechecks class ↔ paired evidence plus plan/payload/destination. `BASProviderBranchLineageEntry` remains unchanged because allocation/claim and seal receipts already expose all three Artifact IDs; do not add a descriptor/egress vector or causal-receipt copy. Crash after claim or hand-off CAS, `sent_or_unknown`, lost/unqueryable/foreign observation, or an unsealable remote result is conservative indeterminate/reconciliation-only: query may feed recovered terminal evidence into the same seal transaction, but there is no second send, route, claim, branch, spool, or publication. The old Provider branch is never resumed or called twice, no successor root is created, and a failed/indeterminate prior branch cannot use this continuation as retry/fallback. A later terminal-answer branch separately requires K3 terminal-source designation and an answer-only request. The proposal port has no handler registry, retry, permit synthesis, storage, branch map, or receipt factory. The only production dispatcher call site is `BASToolEffectAdapter.swift`, invoked by `BASEffectBroker` after exact grant claim/durable reservation. Model adapters, HostKit outside the operation port, Qinao, and apps can emit proposals but cannot call the handler.

Do not create another Qinao effect protocol. Consume the sovereign W5 owner exactly as delivered: inject the read-only `QinaoPreparedEffectContextResolver` beside the existing package `QinaoEffectExecuting`/`QinaoEffectExecution` seam in `QinaoEffectExecuting.swift`. Sovereign owns exactly `package typealias QinaoPreparedEffectEvidenceLookup = @Sendable (BASArtifactID, String) async throws -> BASK3PreparedEffectContextEvidence?` and `package static func QinaoRuntime.makePreparedEffectContextResolver(lookup: @escaping QinaoPreparedEffectEvidenceLookup) -> QinaoPreparedEffectContextResolver`; its first argument is `boundSubjectArtifactID`, not outbox ID. The context itself is created only by `package init(validating evidence:) throws`. `QinaoDefaults`/`QinaoSovereignHostAssembly` captures the exact same `BASK3ControlNucleusStorage` instance already injected into authoritative runtime—production-concretely the same `BASSQLiteEventLogStorage` object—exposes from it only `lookupPreparedEffectContext(boundSubjectArtifactID:canonicalRequestDigest:)`, and passes that narrow closure to the factory. It must not directly construct a context, look up a current branch, reimplement evidence validation, or inject another K3 object.

Keep `QinaoRuntime.execute(toolName:payload:intent:signatures:)` source-compatible. Verify and preserve the already-declared trailing `boundSubjectArtifactID: BASArtifactID? = nil` from Sovereign Task 5 on `QinaoRiskGate.ActionPermit`, `QinaoSovereignControlPlane.Warrant`, and `QinaoRuntime.SnapshotContinuityProof` and their existing public initializer/issuance APIs; Runtime does not add or own those fields, and `QinaoRuntime.Signatures` stores no fourth copy. Nil verification/issuance reproduces each exact legacy HMAC preimage byte-for-byte, with no added tag/delimiter/empty/version byte, so old nil non-effect fixtures remain valid. A nonnil subject uses an explicitly versioned, domain-separated, length-prefixed suffix over canonical `BASArtifactID.storageScalar`; stripping it or verifying it as legacy fails. Authoritative effect execution requires all three signed subjects nonnil and equal before resolver/broker calls. The one canonical subject is exactly `outbox.effectRequestArtifactID`; K3 reopens that governed effect request and equality-links its digest/root/branch/outbox to the receipt-reachable `toolInvocationArtifactID`, but the invocation ID is never an alternate subject. Nil, one-of-three presence, pairwise/all-three mismatch, foreign effect request, invocation-ID substitution, mutated/downgraded signature, or signature stripping fails with zero resolver, broker, K4, Zone-C, or adapter calls. The canonical request digest remains the existing signed intent/tool/payload/session/host digest; no subject is derived from those arguments, credentials, UUID, or current/latest branch.

Verify and consume the already-declared exact-one package `QinaoSovereignEffectExecutor: QinaoEffectExecuting` owned by Sovereign Task 5 in that same existing QinaoRuntime file; Runtime neither declares nor modifies this executor. It holds the exact already-injected `BASEffectBroker` actor and forwards the prepared seven-field tuple once to the broker's public cross-package `executePreparedEffect(turnOperationRef:effectBranchRef:effectBoundaryInstanceID:outboxArtifactID:expectedBoundSubjectArtifactID:expectedCanonicalRequestDigest:expectedSourceK3RootArtifactID:) async throws -> BASEffectBrokerExecution`. The broker independently reopens/equality-checks K3 and the final receipt → permit → dispatch-ready → K3 → anchor → arm → use → governed tool-result/invocation/request graph before package-constructing that validated return. Qinao's package `asQinaoExecution` performs only exact equality over the returned store-receipt IDs, payloads, terminal outcome, and public tool/payload/intent/three-signature binding, then unwraps the already-validated governed result; it receives no Artifact store, K3, verifier closure, receipt factory, or success inference. The facade returns bytes only for that broker-authored `.succeeded` projection with real provider/actuator evidence. Permit/anchor/arm/grant-use are not prepared-context fields, and Qinao never assumes subject/digest/root live directly in the final receipt. The facade never derives an operation ID, searches a current branch, chooses a tuple, owns a local map, or synthesizes a permit/receipt; identical retry resolves the same tuple and broker row without a second physical call.

Retire the sovereign plan's transitional test/rollback escape hatch before W6: remove `QinaoRuntime.ToolExecutor`, the closure initializer/property, `consumedBundles`, and the local `tokenAlreadyConsumed` state/error path. Keep the public broker-backed `execute(...)` signature; do not rename it to `submitEffect`, add `QinaoEffectSubmissionPort`, or recreate any operation-ID canonicalizer. An identical retry must resolve byte-for-byte to the same seven-field preprepared context; a missing, changed, ambiguous, or consumed tuple fails closed and never falls back to a current branch or local idempotency map. Partial/cancelled/failed/indeterminate receipts remain typed failures. Convert every test constructor reported by `rg -l 'toolExecutor:'` to the existing resolver plus recording/broker-backed `QinaoEffectExecuting` fixture. Calls to `.execute(...)` remain valid because they now exercise the durable facade, so they must not be banned by a textual scan.

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
! rg -n 'buildSovereignExecutionReceipts|status:[[:space:]]*\.executed' \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit"
test "$(rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)' \
  "$ROOT/BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASToolEffectAdapter.swift" \
  | wc -l | tr -d ' ')" = 1
if rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)|\.dispatchBatch\(invocations:' \
  "$ROOT/BehavioralAISubstrate/Sources" -g '*.swift' \
  | rg -v 'BASToolEffectAdapter.swift|BASToolDispatcher.swift'; then
  exit 1
fi
! rg -n 'ToolExecutor|toolExecutor|consumedBundles|tokenAlreadyConsumed' \
  "$ROOT/QinaoRuntimeSDK/Sources" --glob '*.swift'
rg -q 'QinaoEffectExecuting' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
rg -q 'QinaoPreparedEffectContextResolver' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
rg -q 'QinaoRuntime\.makePreparedEffectContextResolver(lookup:' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift"
test "$(rg -n 'package struct QinaoSovereignEffectExecutor:[[:space:]]*QinaoEffectExecuting' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift" | wc -l | tr -d ' ')" = 1
! rg -n 'QinaoPreparedEffectContext\(validating:|currentEffectBranch|lookupCurrent.*Effect' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoDefaults" --glob '*.swift'
rg -q 'boundSubjectArtifactID' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift"
! rg -n 'derive.*[Oo]perationID|stable.*[Oo]perationID|currentEffectBranch|effectContextMap' \
  "$ROOT/QinaoRuntimeSDK/Sources" --glob '*.swift'
```

`BASSovereignEffectReceiptTruthTests`, `BASToolCallingPlannerTests`, `BASToolDispatcherTests`, `QinaoTokenSigningTests`, and the prerequisite `QinaoEffectFacadeBrokerTests` must prove: proposal-only flows execute zero handlers; the planner cannot be initialized with a dispatcher; Qinao cannot be initialized with an executor closure; nil signed subjects reproduce the pinned legacy preimages byte-for-byte only for non-effect compatibility; nonnil credentials use the exact versioned/domain-separated/length-prefixed subject suffix and cannot be downgraded or stripped; authoritative effects require three equal signatures over exactly `outbox.effectRequestArtifactID`, while invocation-ID substitution, nil, every one/pair/all mutation, foreign subject, or old preimage stops before resolver. `QinaoDefaults` passes the exact same K3 object through the narrow evidence lookup/factory and constructs `QinaoSovereignEffectExecutor` with the exact same broker actor; public arguments resolve `(boundSubjectArtifactID, canonicalRequestDigest)` to exactly one seven-field prepared context; every context mutation/missing/ambiguity stops before execution. An authorized context forwards once; the broker, not Qinao, reopens the complete final evidence graph and yields one validated projection; Qinao exact-checks/unwraps it without a store/K3/verifier seam. Mutating final permit/dispatch-ready/K3/anchor/arm/grant-use/tool-result evidence refuses broker success; identical retry resolves the same tuple/receipt without a second handler call; partial/cancelled/indeterminate never become `.executed` success; replay simulation calls neither resolver-to-execution transition, broker, nor dispatcher. No coordinator/runtime/planner/Qinao helper may construct a broker receipt or prepared context, derive an operation ID, query a current effect branch, own a prepared-context map, or inject a second broker/K3.

Run `rg -l 'toolExecutor:' QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests --glob '*.swift' | LC_ALL=C sort` before edits and save its exact output in the W0 evidence. Convert every listed constructor to the existing W5 recording/broker fixture; after migration the same command must return no match. The complete Qinao suite is the compile-time completeness gate, while `QinaoEffectFacadeBrokerTests` remains the behavioral authority for stable-operation retry and durable receipt truth.

- [ ] **Step 5B [W5]: Prove the effect boundary and commit the W5 closeout separately**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASSovereignEffectReceiptTruthTests|BASToolCallingPlannerTests|BASToolDispatcherTests|BASEffectSagaCrashMatrixTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoEffectFacadeBrokerTests|QinaoRuntimeGateTests|QinaoSovereignHostAssemblyTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK"
! rg -n 'buildSovereignExecutionReceipts|status:[[:space:]]*\.executed' \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit"
test "$(rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)' \
  "$ROOT/BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASToolEffectAdapter.swift" \
  | wc -l | tr -d ' ')" = 1
if rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)|\.dispatchBatch\(invocations:' \
  "$ROOT/BehavioralAISubstrate/Sources" -g '*.swift' \
  | rg -v 'BASToolEffectAdapter.swift|BASToolDispatcher.swift'; then
  exit 1
fi
! rg -n 'ToolExecutor|toolExecutor|consumedBundles|tokenAlreadyConsumed' \
  "$ROOT/QinaoRuntimeSDK/Sources" --glob '*.swift'
rg -q 'QinaoEffectExecuting' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
! rg -n 'toolExecutor:' \
  "$ROOT/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests" --glob '*.swift'

QINAO_EFFECT_MIGRATION_TESTS=(
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/PropertyDemos/PropertyDemoFixture.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationGateChainTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeAutoStreamL1Tests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeAutoStreamL3L5Tests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeChainBreakRecoveryTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeCoverageTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeCrossSessionTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeDeepReviewTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeGateTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeGenerationTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL10L11AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL12AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL13AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL2AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL6AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL7AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL8AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeL9AutoStreamTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeLifecycleTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeM153LegacyParityTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeRenderFrameCapTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSendSessionStreamingTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSessionLifecycleTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostFlowTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoTokenSigningTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeBrokerTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoTurnArtifactsBridgeTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/Shared/QinaoTestFixture.swift
)
git -C "$ROOT" add \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASToolCallingPlanner.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectReceiptTruthTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASToolCallingPlannerTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASToolDispatcherTests.swift \
  QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRisk.swift \
  QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift \
  QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift \
  QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoSovereignSnapshotProof.swift \
  QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift \
  QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift \
  "${QINAO_EFFECT_MIGRATION_TESTS[@]}"
git -C "$ROOT" diff --cached --check
git -C "$ROOT" commit -m "refactor: close durable effect authority"
```

Expected W5 receipt: every effect owner key is green; only `BASToolEffectAdapter` package-calls the dispatcher; Qinao's source-compatible facade reaches the pre-existing `QinaoEffectExecuting`/broker seam and has no direct closure or local idempotency state; the focused and complete Qinao suites pass; and the W5 commit contains no W6 runtime/replay file. Do not begin W6 if any W5 effect violation remains, even if unrelated future W6 owner keys are still red.

- [ ] **Step 6: Extend the current replay owners with four typed modes and privacy projection**

Add to the manifest contract:

```swift
public enum BASArchitectureReplayMode: String, Codable, Sendable, Equatable {
    case deterministicSemantic
    case exactNeural
    case behavioralReevaluation
    case effectSimulation
}
```

Extend `BASEventReplayRunner`, `BASEventLogReplayBundle`, `BASAuditReplayEngine`, and `BASEBrainTurnResultReplayHarness` rather than creating another executor:

- Before every mode, call the same `BASCompleteReplayEvidenceValidator.validateIndexed` used by the publication resolver. It exact-resolves the manifest from the same K3 index/source head, reopens and rederives result/DAG/snapshot/market/context/node/general/loop/state/outbox/effect/reconciliation and both Provider/release chains, and requires whole-manifest/vector equality before publication-record lookup or mode-specific work. Then decode EventLog compatibility to the typed root and call the stateless chain validator. Reopen policy, binding, every shared lineage receipt/ref, both immutable terminal-prefix and through-visibility chain artifacts, unique source designation, visibility evidence, result, spool, and preparation; validate K3 event/coverage heads separately. Derive policy facts; require spool→terminal-prefix and preparation→through-visibility exact equality; reject a prefix-only final, sibling/later source, post-gate branch, failed-source replacement, or claimed-branch retry. Validate both visibility modes without a Provider.
- Before any mode-specific work, reopen the manifest, call only the injected exact `responseReleaseCoordinator.finalizedPublicationRecord(for:)`, and require the returned `BASPublicationRecord` to be `.finalized`; its request carries the same manifest ID, spool ID, and `exactGrantArtifactID`; and its nonnil `capabilityUseReceiptArtifactID` and `sinkReceiptArtifactID` both reopen through the same Artifact Mesh. Missing/nonfinal rows, malformed/duplicate evidence, any manifest/spool/grant mismatch, or either missing/tampered receipt fails closed. Replay receives no journal/read-view field and never mutates or finalizes coordinator state.
- `deterministicSemantic` then consumes the already fully validated evidence plus the two finalized sovereign receipt references and runs the deterministic reducer without invoking a neural backend or effect adapter. Replay owns no watermark field/vector.
- `exactNeural` is verification-only: it performs **zero physical Provider dispatches**. It requires the exact installed runtime executable identity, provider-policy artifact, one execution binding, and every per-branch execution-plan/model/profile/budget/StateABI/fallback/RNG/termination projection; any mismatch fails the verdict rather than dispatching. For every entry it follows lineage → allocation/claim receipt → exact common `selectedProviderDescriptorArtifactID`, reopens and current-version decodes that `BASPersistedOrganDescriptorPayload` through `BASGovernedArtifactPayloadCodec`, unwraps its descriptor, and validates the embedded provider identity and required `BASProviderContainmentClass`; K3 never supplies that interpretation. It requires the allocation/claim/lineage/proposal execution ref to be the same complete sequence-zero value and every recorded event ref to be derived by checked `withRequestSequence`, preserve all six stable base fields, and canonicalize back to that base. A local `inProcessCertified` seal must have both remote-evidence IDs nil. For each `isolatedExtension`/`remote` entry, reopen its seal receipt's exact nonnil `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID`; reopen/equality-check the sovereign permit, K4 anchor, K3 begin-handoff/terminal-seal state, complete supervisor `BASProviderObservedReceipt`, root/branch/execution claim/governed descriptor parent and embedded descriptor/plan/materialized payload/destination/Attempt/epochs/grant/use receipt, and require the one atomic `sent_or_unknown → terminal_or_indeterminate` seal. `sent_or_unknown`, lost/foreign/incomplete observation, expired pre-handoff deadline, `.alreadyPossible`, missing/foreign paired seal evidence, or any transport call during replay is reconciliation-only and cannot be replayed, sealed, published, or certified; Runtime adds no descriptor/fence/evidence array.
- `behavioralReevaluation` may perform neural work only under a newly admitted, explicitly nonpublishable `BASTurnOperationRef` with a fresh Attempt, budget lease, installed Provider policy/binding, and fresh K3-allocated/claimed Provider branches. It never reuses the original root, branch, claim, use receipt, terminal source, visibility, or publication authority. Its result is labeled non-exact, cannot pin a terminal source, publish, write/activate state, dispatch effects/tools, or alter the original manifest; one immutable evaluation artifact may reference the original manifest as provenance. Denied/failure paths perform zero calls, and tests prove fresh-root inequality plus zero original-state/effect/publication/source-pin deltas.
- `effectSimulation` folds recorded effect/state receipts into the current audit replay reducer and never calls `BASToolDispatcher`, a Zone-C adapter, K4 spend, publication sink, or state activation.

Extend the existing replay dependency value—not a new replay owner—with the exact same `artifactStore`, semantic reopener, `BASRuntimeK3Composite`, `BASResponseReleaseCoordinator`, concrete process-shared ledger, concrete memory-context gateway, and current-run capability-snapshot artifact. It has no journal/read-view, decoder/authority/observation closure, or replaceable validator. Each replay call forms a fresh per-run gateway resolution and wraps manifest/coordinator-final-record/receipt/snapshot reads plus deterministic/effect reduction in one ordinary request rooted at `manifestArtifactID` with `.artifactIO/.responseSpoolAndArtifactBuffer`, zero resident bytes, and a checked bound for its read/decode/reducer buffers. It must reverify the current unexpired context; the historical turn's context/expiry is evidence only and is never reused. Behavioral neural execution obtains a separate fresh-root silicon heavy lease; exact-neural is read-only and obtains none. The replay I/O scope excludes neural resident/transient bytes and does not double count them. Cancellation, thrown decode/read, context drift, and publication-closure rejection all retire the exact replay activation before return.

Define the test-only `PublicationClosureMutation: CaseIterable` cases exactly as `.missingRecord`, `.reservedOnly`, `.sinkCommittedOnly`, `.manifestMismatch`, `.spoolMismatch`, `.exactGrantMismatch`, `.missingCapabilityUseReceipt`, `.missingSinkReceipt`, `.tamperedCapabilityUseReceipt`, and `.tamperedSinkReceipt`. The sovereign journal's unique manifest index makes a second row an insertion error; the replay fixture must not normalize that conflict into one apparent record.

Define test-only `SnapshotReopenMutation: CaseIterable` exactly as `.missingSnapshot`, `.duplicateLaneWatermark`, `.nonCanonicalSnapshotWatermarkOrder`, `.watermarkBeyondSnapshotHead`, `.wrongTurn`, `.wrongSession`, `.snapshotHeadAfterManifestHead`, and `.tamperedSnapshotHeadIntegrity`; each must fail before publication reservation in the barrier fixture and before mode-specific work in replay.

Extend `ObservabilityCore.swift` with a projection containing only mode, counts, logical durations, outcomes, keyed/blinded identifiers, and typed evidence artifact IDs. Raw prompt/output bytes remain in Artifact Mesh and require a projection capability. MetricKit is not consulted during replay.

- [ ] **Step 7: Run GREEN, replay/event/release regressions, and anti-owner scans**

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASPrePublicationManifestBarrierTests|BASAuthoritativeSemanticRuntimeTests|BASArchitectureReplayManifestTests|BASSingleAuthoritativeResultTests|BASEBrainTurnResultReplayHarnessTests|BASEventLogReplayBundleIntegrationTests|BASEventLogTamperRedTeamTests|BASChapter816AuditReplayEngineTests|BASResponseReleaseOrderingTests|BASSovereignEffectEndToEndTests|BASSovereignEffectReceiptTruthTests|BASToolCallingPlannerTests|BASToolDispatcherTests|BASTurnOperationCutoverTests|BASTurnRuntimeModeTests|BASEnvVarBridgeDoctrineTests|BASProcessMemoryLedgerTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoEffectFacadeBrokerTests|QinaoRuntimeGateTests|QinaoTokenSigningTests|QinaoAppleFoundationGateChainTests|QinaoSovereignHostAssemblyTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK"
if rg -n 'actor BASSemanticRuntimeComposition|actor BASReplayExecutor|protocol BASReplayManifestStore' \
  "$ROOT/BehavioralAISubstrate/Sources"; then
  exit 1
fi
if rg -n 'struct BASPublicationReservation|actor BASPublicationCoordinator|protocol BASPublicationJournal' \
  "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift" \
  "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventReplayRunner.swift" \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift" \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift" \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift"; then
  exit 1
fi
DOWNSTREAM=(
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASEventLogReplayBundle.swift"
)
if rg -n 'BASProcessMemoryLedger[[:space:]]*\(|hardCapBytes:|private var .*([Rr]eservation|[Hh]eavy)' "${DOWNSTREAM[@]}"; then
  exit 1
fi
test "$(rg -n '\.publishExact\(' \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift" | wc -l | tr -d ' ')" = "1"
! rg -n 'buildSovereignExecutionReceipts|status:[[:space:]]*\.executed' \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit"
if rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)|\.dispatchBatch\(invocations:' \
  "$ROOT/BehavioralAISubstrate/Sources" -g '*.swift' \
  | rg -v 'BASToolEffectAdapter.swift|BASToolDispatcher.swift'; then
  exit 1
fi
! rg -n 'ToolExecutor|toolExecutor|consumedBundles|tokenAlreadyConsumed' \
  "$ROOT/QinaoRuntimeSDK/Sources" --glob '*.swift'
rg -q 'QinaoEffectExecuting' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
! rg -n 'toolExecutor:' \
  "$ROOT/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests" --glob '*.swift'
```

Expected: owner ledger, all selected tests, and the complete Qinao suite PASS with 0 failures; manifest reopen/index precedes reservation, authoritative execution calls no V1/native-Any/provider second path, only the broker adapter can dispatch a handler, no HostKit code synthesizes `.executed`, Qinao exposes neither executor closure nor in-memory execution truth, effect replay dispatches nothing, and the scans find no runtime-owned publication/replay owner or unmigrated Qinao effect call site.

- [ ] **Step 8: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventReplayRunner.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASEventLogReplayBundle.swift \
  BehavioralAISubstrate/Sources/BASOrchestration/BASAuditReplayEngine.swift \
  BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPrePublicationManifestBarrierTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAuthoritativeSemanticRuntimeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeAuditEnvelopeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogEntryTurnEnvelopeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationCutoverTests.swift
git commit -m "feat: gate publication on complete replay manifest"
```

### Task 6 [W6]: Aggregate Existing E0–E5 Evidence and Implement Exact 40/30 Claim Protocols

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASArchitectureCertVerifier/main.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeDefaultModeFlipReadinessGate.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASStressSweepHarness.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASProbeCommon.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASFieldMetricsCollector.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/project.yml`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-device-app-cert.sh`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-endurance-watchdog.sh`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAppleSiliconCertificationTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/Fixtures/certification/deny-missing-e4.json`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-architecture-cert.sh`

**Reuse Decision (M + E/A):** One aggregate E0–E5 verdict/candidate-tree attestation is allowlisted as missing, so create a single BASEvaluation contract/evaluator file. Extend the existing default-flip gate and stress harness to consume it. `run-device-app-cert.sh` gains an exact cold-cohort mode and `run-endurance-watchdog.sh` gains a fail-on-interruption strict mode; they remain the current launch/log owners. `run-spec-decode-cert.sh`, `run-coreai-e2e-cert.sh`, `run-concurrent-turns-cert.sh`, `BASEnduranceAppRunner`, `BASSystemProbe`, `BASThermalTwin`, existing signposts/logs, and `BASFieldMetricsCollector` remain evidence mechanisms. The new CLI and shell file are thin adapters; they cannot invent evidence or override the Swift verdict. MetricKit is accepted only as delayed E5 canary evidence and cannot satisfy an E4 per-run gate.

For owner-ledger key `runtime-replay-certification:Task 6`, the first create delta atomically adds every exact production path permission and create-proof evidence and changes `approved_missing → converging`; subsequent deltas append concrete evidence. Remove a `current_conflicts` item only with proof. Change to `implemented` only when every declared path exists, task tests and owner/checker gates pass, the evidence list is complete, and `current_conflicts == []`. Roll back ledger status/evidence/permissions with the source creates if the create set is rolled back. Stage the ledger, checker, checker test, evaluator/CLI/controller sources, fixtures, and focused tests together.

**Create Proof — `BASAppleSiliconCertification.swift`:**

1. Repository search: `rg -n 'EvidenceGrade|CandidateTreeAttestation|AppleSiliconCertification|thermallyColdResidentAcceptedDecodeTPS' BehavioralAISubstrate/Sources` finds individual regression/readiness verdicts but no aggregate E0–E5/candidate-tree/claim authority. Nearest owners are `BASTurnRuntimeDefaultModeFlipReadinessGate`, `BASStressSweepHarness`, `BASEvalRegressionDetector`, and existing device-probe verdicts.
2. Public/upstream search: XCTest, Xcode device tools, MetricKit, `ProcessInfo.thermalState`, Git trees, and shell scripts collect or transport evidence but do not encode this application's promotion and performance-claim rules.
3. Missing invariant: one deterministic verdict binding every gate to one Git candidate tree, installed executable identity, owner-ledger/verifier identity, toolchain/controller/verifier identity, two physical-device receipts, exclusions, and exact claim definitions.
4. Extending one existing probe would give that probe authority over unrelated quality/memory/effect/replay gates. A pure aggregate evaluator is required; collectors remain unchanged owners and feed it typed references.
5. Authority/state/storage/failure: BASEvaluation owns only pure aggregate decision rules and payloads; it has no mutable store. Evidence bodies remain in Artifact Mesh/device logs. Missing receipt, tree/runtime mismatch, insufficient grade, failed exclusion disclosure, malformed percentile, or protocol mismatch yields typed deny/not-certified.
6. Dependency direction: BASEvaluation imports RuntimeCore/Observability; the thin CLI imports BASEvaluation; DeviceTestApp and scripts emit evidence for the CLI. Evaluation never imports HostKit or controls runtime execution.
7. Compatibility: existing scripts/probes continue to run independently and are wrapped by the aggregate script. Their legacy human-readable summaries remain diagnostic only. Promotion consumes the typed verdict after E4; E5 adds canary evidence without rewriting prior E4 receipts.
8. Mutation/crash/replay/duplicate tests cover every gate bit, grade inflation, MetricKit substituted for E4, candidate-tree/runtime/owner-ledger/controller/verifier/toolchain mutation, duplicate device identity, incomplete run, exclusion tamper, interrupted collection, cold-40 boundary, sustained-30 last-quarter boundary, and two competing verdict authorities.

**Interfaces:**
- Consumes: Artifact Mesh evidence IDs from current scripts/probes, candidate Git tree/runtime/toolchain identities, owner-ledger/verifier evidence, device/OS/profile identity, deterministic per-run E4 receipts, and optional MetricKit E5 IDs. The `.replayAndRecovery` E4 evidence must reference a validated `BASArchitectureReplayManifest`, installed `BASProviderBranchPolicy`/binding, complete per-branch K3 chain, unique terminal source, and separate passing mutation matrices for both `BASProviderVisibilityMode` cases.
- Produces: `BASEvidenceGrade`, `BASCertificationGateID`, `BASCandidateTreeAttestation`, `BASAppleSiliconCertificationInput`, `BASAppleSiliconCertificationVerdict`, `BASPerformanceClaimProtocol`, and CLI commands `evaluate`, `verify`, `scan-entrypoints`, and `require-promotion`.

- [ ] **Step 1: Write failing grade, tree-binding, MetricKit, cold-40, and sustained-30 tests**

```swift
import XCTest
@testable import BASEvaluation

final class BASAppleSiliconCertificationTests: XCTestCase {
    func testE3OrOneDeviceCannotPromote() throws {
        XCTAssertEqual(try evaluateCertification(maximumGrade: .e3).decision, .deny)
        XCTAssertEqual(try evaluateCertification(deviceIDs: ["device-a"]).decision, .deny)
        XCTAssertEqual(
            try evaluateCertification(deviceIDs: ["same", "same"]).decision,
            .deny
        )
    }

    func testMetricKitCannotSubstituteForMissingDeterministicE4Receipt() throws {
        let verdict = try evaluateCertification(
            deterministicE4ReceiptArtifactIDs: [],
            metricKitE5ArtifactIDs: [fixtureArtifactID("metrickit")]
        )
        XCTAssertEqual(verdict.decision, .deny)
        XCTAssertTrue(verdict.denialReasons.contains(.missingDeterministicE4Evidence))
    }

    func testCandidateTreeExecutableAndDeviceReceiptsMustMatchExactly() throws {
        for mutation in CandidateTreeAttestationMutation.allCases {
            XCTAssertEqual(try evaluateCertification(mutation: mutation).decision, .deny)
        }
    }

    func testOwnerLedgerAndVerifierAreCandidateBound() throws {
        for mutation in OwnerLedgerAttestationMutation.allCases {
            let verdict = try evaluateCertification(ownerLedgerMutation: mutation)
            XCTAssertEqual(verdict.decision, .deny)
        }
    }

    func testCold40RequiresTwoDevicesOneHundredTurnsAndP10AtLeastFortyOnEach() throws {
        let passing = try evaluateCold40(
            devices: [coldDevice(id: "a", turns: 100, p10: 40.0),
                      coldDevice(id: "b", turns: 100, p10: 40.0)]
        )
        XCTAssertEqual(passing, .certified)
        XCTAssertEqual(try evaluateCold40(
            devices: [coldDevice(id: "a", turns: 99, p10: 50.0),
                      coldDevice(id: "b", turns: 100, p10: 50.0)]
        ), .denied)
        XCTAssertEqual(try evaluateCold40(
            devices: [coldDevice(id: "a", turns: 100, p10: 39.999),
                      coldDevice(id: "b", turns: 100, p10: 41.0)]
        ), .denied)
    }

    func testSustained30RequiresTwoDevice1800SecondContinuousArrivalAndLastQuarterP10() throws {
        let passing = try evaluateSustained30(devices: [
            sustainedDevice(id: "a", duration: 1800, lastQuarterP10: 30.0),
            sustainedDevice(id: "b", duration: 1800, lastQuarterP10: 30.0)
        ])
        XCTAssertEqual(passing, .certified)
        XCTAssertEqual(try evaluateSustained30(devices: [
            sustainedDevice(id: "a", duration: 1799, lastQuarterP10: 40.0),
            sustainedDevice(id: "b", duration: 1800, lastQuarterP10: 40.0)
        ]), .denied)
        XCTAssertEqual(try evaluateSustained30(devices: [
            sustainedDevice(id: "a", duration: 1800, lastQuarterP10: 29.999),
            sustainedDevice(id: "b", duration: 1800, lastQuarterP10: 31.0)
        ]), .denied)
    }

    func testCold40RejectsEveryConditionsAndTimerMutation() throws {
        for mutation in Cold40ProtocolMutation.allCases {
            XCTAssertEqual(
                try evaluateCold40(devices: coldDevices(mutation: mutation)),
                .denied,
                "mutation must deny: \(mutation)"
            )
        }
    }

    func testSustained30RejectsInterruptionSlopeOrHiddenQualityReduction() throws {
        for mutation in Sustained30ProtocolMutation.allCases {
            XCTAssertEqual(
                try evaluateSustained30(devices: sustainedDevices(mutation: mutation)),
                .denied,
                "mutation must deny: \(mutation)"
            )
        }
    }

    func testRuntimePromotionDoesNotInventA40Or30Claim() throws {
        let verdict = try evaluateCertification(
            cold40Request: .notRequested,
            sustained30Request: .notRequested
        )
        XCTAssertEqual(verdict.decision, .allow)
        XCTAssertEqual(verdict.cold40Claim, .notRequested)
        XCTAssertEqual(verdict.sustained30Claim, .notRequested)
    }

    func testPromotionRequiresProviderChainAndBothVisibilityReplayEvidence() {
        for mutation in ProviderReplayCertificationMutation.allCases {
            XCTAssertEqual(
                try evaluateCertification(providerReplayMutation: mutation)
                    .decision,
                .deny)
        }
    }
}
```

`ProviderReplayCertificationMutation.allCases` is pinned to missing policy, binding-policy mismatch, missing immutable terminal-prefix/through-visibility chain artifact, wrong complete sequence-zero `BASProviderExecutionRef`, event-ref stable-field/checked-sequence violation, duplicate claim, missing/mismatched selected-descriptor Artifact ID, rewritten governed descriptor parent or embedded descriptor/provider/containment, missing bounded seal, terminal-source cardinality not one, sibling/later source replacement, spool/preparation/final-publication mismatch, missing incremental evidence, missing buffered evidence, visibility mode switch, post-gate branch, local seal carrying either remote-evidence ID, remote seal missing/foreign/mismatched arm or observation ID, incomplete/foreign `BASProviderObservedReceipt`, wrong permit/anchor/begin-handoff/claim/descriptor/plan/payload/destination/Attempt/epoch/grant/use binding, expired hand-off, `.alreadyPossible` followed by a call, `sent_or_unknown`, lost/unqueryable remote result, double transport send, and any physical call during replay. K3 event/coverage heads are mutated separately from the two immutable chain payloads.

`Cold40ProtocolMutation.allCases` is pinned to ambient below/above range, Low Power Mode on, non-nominal or less-than-300-second entry, undeclared cooling/competing app, nonresident runtime, cache/prefix mismatch, partial prefill, timer-boundary mismatch, workload/RNG/termination/interval drift, failure, exclusion, wrong turn count, and threshold failure. `Sustained30ProtocolMutation.allCases` is pinned to interruption/relaunch, cool-down gap, arrival/mix/output drift, duration shortfall, last-quarter threshold failure, positive memory slope, hidden quality/output/retrieval/policy reduction, failure, and exclusion. The tests assert the enum has those exact raw cases before iterating so deleting a mutation cannot weaken coverage.

Create `deny-missing-e4.json` by encoding a real `BASAppleSiliconCertificationVerdict` whose decision is `.deny`, denial reasons are exactly `[.missingDeterministicE4Evidence]`, candidate tree is forty zeroes, both claim results are `.notRequested`, and evidence references are empty. The test decodes the committed fixture, compares it to that typed value, re-encodes with sorted keys, and requires byte equality so the CLI negative case cannot drift from the schema.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_CERTIFICATION_CANDIDATE_MANIFEST:?set the ephemeral runtime.certification candidate manifest path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$BAS_CERTIFICATION_CANDIDATE_MANIFEST"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter BASAppleSiliconCertificationTests
```

Expected: FAIL at compile time because `BASAppleSiliconCertificationInput`, `BASCandidateTreeAttestation`, and `BASPerformanceClaimProtocol` do not exist.

- [ ] **Step 3: Add one pure aggregate certification and candidate-tree authority**

```swift
import Foundation
import BASRuntimeCore
import BASObservability

public enum BASEvidenceGrade: Int, Codable, Sendable, Comparable, CaseIterable {
    case e0 = 0
    case e1 = 1
    case e2 = 2
    case e3 = 3
    case e4 = 4
    case e5 = 5

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum BASCertificationGateID: String, Codable, Sendable, Hashable, CaseIterable {
    case ownerLedger
    case fullBloodIdentity
    case memory
    case thermalAndPower
    case concurrencyAndUI
    case mtpAndPromptLookup
    case heterogeneousExecution
    case coreAIPromotion
    case replayAndRecovery
    case sourceEntrypoints
}

public struct BASCertificationEvidenceReference: Codable, Sendable, Equatable {
    public let gateID: BASCertificationGateID
    public let grade: BASEvidenceGrade
    public let evidenceArtifactID: BASArtifactID
    public let candidateTreeID: String
    public let runtimeExecutableDigest: String
    public let deviceID: String?
}

public struct BASCandidateTreeAttestation: Codable, Sendable, Equatable {
    public let candidateTreeID: String
    public let runtimeExecutableDigest: String
    public let runtimeExecutableArtifactID: BASArtifactID
    public let controllerArtifactID: BASArtifactID
    public let verifierArtifactID: BASArtifactID
    public let toolchainArtifactID: BASArtifactID
    public let ownerLedgerArtifactID: BASArtifactID
    public let ownerLedgerVerifierArtifactID: BASArtifactID
    public let ownerLedgerPassArtifactID: BASArtifactID
    public let ownerLedgerDigest: String
    public let ownerLedgerVerifierDigest: String
    public let orderedDeviceReceiptArtifactIDs: [BASArtifactID]
    public let orderedDeviceIDs: [String]
}

public enum BASCertificationDecision: String, Codable, Sendable, Equatable {
    case allow
    case deny
}

public enum BASPerformanceClaimDecision: String, Codable, Sendable, Equatable {
    case notRequested
    case certified
    case denied
}

public struct BASAppleSiliconCertificationInput: Codable, Sendable, Equatable {
    public let candidate: BASCandidateTreeAttestation
    public let evidence: [BASCertificationEvidenceReference]
    public let deterministicE4ReceiptArtifactIDs: [BASArtifactID]
    public let metricKitE5ArtifactIDs: [BASArtifactID]
    public let disclosedFailureArtifactIDs: [BASArtifactID]
    public let disclosedExclusionArtifactIDs: [BASArtifactID]
    public let cold40Request: BASPerformanceClaimProtocol.Cold40Request
    public let sustained30Request: BASPerformanceClaimProtocol.Sustained30Request
}

public struct BASAppleSiliconCertificationVerdict: Codable, Sendable, Equatable {
    public let decision: BASCertificationDecision
    public let candidate: BASCandidateTreeAttestation
    public let orderedGateResults: [BASCertificationGateResult]
    public let denialReasons: [BASCertificationDenialReason]
    public let cold40Claim: BASPerformanceClaimDecision
    public let sustained30Claim: BASPerformanceClaimDecision
}

/// Sole stateless authority declared by the `runtime.certification` ledger row.
public enum BASAppleSiliconCertification {
    public static func evaluate(
        _ input: BASAppleSiliconCertificationInput
    ) throws -> BASAppleSiliconCertificationVerdict {
        try validateCanonicalInput(input)
        let orderedGateResults = try evaluateAllTenGates(input)
        let cold40Claim = try BASPerformanceClaimProtocol.evaluateCold40(
            input.cold40Request)
        let sustained30Claim = try BASPerformanceClaimProtocol.evaluateSustained30(
            input.sustained30Request)
        let denialReasons = try deriveCanonicalDenialReasons(
            input: input,
            gateResults: orderedGateResults,
            cold40Claim: cold40Claim,
            sustained30Claim: sustained30Claim
        )
        return BASAppleSiliconCertificationVerdict(
            decision: denialReasons.isEmpty ? .allow : .deny,
            candidate: input.candidate,
            orderedGateResults: orderedGateResults,
            denialReasons: denialReasons,
            cold40Claim: cold40Claim,
            sustained30Claim: sustained30Claim
        )
    }
}
```

Add explicit public initializers and checked canonical ordering to every payload. Implement `validateCanonicalInput`, `evaluateAllTenGates`, and `deriveCanonicalDenialReasons` as private static methods on this same `BASAppleSiliconCertification` enum, not free functions or another evaluator. `BASAppleSiliconCertification.evaluate(_:)` requires all ten non-claim gates to have deterministic E4 evidence on at least two distinct physical devices where device-scoped. The `.replayAndRecovery` gate additionally reopens exact evidence that the sole policy/binding and complete ordered Provider chain replayed with one pinned terminal source, no sibling/retry, one receipt-bound selected descriptor per branch, checked base-ref/event-sequence equality, and both visibility-mode mutation suites green. For isolated-extension/remote exact-neural evidence it must also decode the receipt-bound `BASPersistedOrganDescriptorPayload` through `BASGovernedArtifactPayloadCodec`, unwrap its descriptor/containment class, and reopen the permit, K4 anchor, K3 arm and fresh begin-handoff winner, the seal receipt's exact paired arm/observation IDs, complete supervisor `BASProviderObservedReceipt`, and one atomic terminal seal; any `sent_or_unknown`, `.alreadyPossible` transport call, lost/unqueryable/foreign observation, missed deadline, double send, or missing seal is deny/reconcile evidence and cannot certify. Local `inProcessCertified` evidence proves both remote-evidence IDs are nil. It verifies candidate tree, executable, owner-ledger/verifier, controller, toolchain, app, and every evidence reference; denies undisclosed failure/exclusion; and returns a pure value. MetricKit cannot fill E4 or change deny. Runtime promotion and performance claims remain separate.

- [ ] **Step 4: Implement the full thermally-cold 40 and sustained 30 protocols**

Define `BASPerformanceClaimProtocol.Cold40Request` so `.requested` carries at least two distinct physical-device cohorts. Each cohort must prove:

- exactly 100 preregistered measured workload turns;
- ambient temperature within `22 ± 2 °C` for every entry;
- Low Power Mode off; declared battery/external-power, screen, and radio conditions;
- no competing heavy app;
- public thermal state continuously `nominal` for at least 300 seconds before every measured turn;
- no undeclared external active cooling;
- model/runtime resident; declared JIT/AOT/specialization and prefix/cache state;
- protocol-specified full prefill; prefix/suffix restore disabled unless the named cache class explicitly permits it;
- decode timer from first target dispatch after prefill through final target-verified accepted or terminal token;
- preregistered prompt/context/output buckets, sampling/RNG contract, natural-termination policy, fixed inter-turn interval, failures, and exclusions;
- per-device `thermallyColdResidentAcceptedDecodeTPS p10 >= 40.0`;
- passing identity, memory, error, and thermal gates;
- separately reported process-cold TTFT, cache-cold prefill TPS, verification/release TPS, and end-to-end goodput.

Define `Sustained30Request` so `.requested` requires two distinct physical devices, each with one uninterrupted 1800-second continuous-arrival cohort, no inserted cool-down gap, fixed/reported arrival pattern, prompt/prefill mix, output buckets, model/cache state, power/ambient conditions, and decode timer. Each device must have last-quarter accepted-decode p10 `>= 30.0`, separately report TTFT and `turnShapedEndToEndGoodput`, have no positive memory slope, and show no hidden quality, output-length, retrieval-coverage, or policy reduction. A missing field, malformed percentile population, device duplication, duration `1799`, value below the threshold, failure, or undisclosed exclusion returns `.denied`. Neither claim is inferred when `.notRequested`.

- [ ] **Step 5: Add the thin verifier CLI and extend existing device evidence producers**

Add a `BASArchitectureCertVerifier` executable target depending only on `BASEvaluation`, `BASRuntimeCore`, and Foundation. Its `main.swift` decodes bounded JSON, invokes `BASAppleSiliconCertification.evaluate`, and implements exactly:

```text
evaluate --input <input.json> --output <verdict.json>
verify --verdict <verdict.json> --expected-tree <tree-id> --expected-runtime-digest <sha256> --expected-owner-ledger-digest <sha256> --expected-owner-verifier-digest <sha256>
scan-entrypoints --root <workspace> --output <inventory.tsv>
require-promotion --verdict <verdict.json> --expected-tree <tree-id> --expected-owner-ledger-digest <sha256> --expected-owner-verifier-digest <sha256>
```

`scan-entrypoints` is a typed lexical/source inventory adapter used in Task 7; it does not decide promotion. Unknown command, malformed JSON, extra field, missing file, duplicate device, unsupported evidence grade, tree mismatch, or deny verdict exits nonzero with one stable diagnostic.

Extend `BASEnduranceAppRunner` and `BASProbeCommon` to emit bounded JSON receipts containing candidate/runtime/device/performance/thermal/memory evidence. Each measured turn references the typed-root manifest, Provider policy/binding, shared lineage, the two immutable terminal-prefix and through-visibility chain Artifact IDs, pinned source/execution, visibility evidence, spool, preparation, final publication, and separately validated K3 event/coverage heads so the controller can reopen/equality-check the full path. Reuse current probes; add no scheduler or codec.

Extend `BASFieldMetricsCollector` only to emit delayed E5 evidence references with `source = metricKitDelayedCanary`; its type cannot initialize a deterministic E4 run receipt. Embed only `BAS_CANDIDATE_TREE_ID` in DeviceTestApp build settings through `project.yml` and the generated project. After installation, `BASProbeCommon` computes SHA-256 from `Bundle.main.executableURL` at runtime and emits that observed installed-executable digest in every E4 receipt; the controller requires one identical digest across the run and writes it to `runtime-identity.env`. Never embed the executable's own digest in the executable, which would be circular. Fail the probe if the embedded tree identity or observed executable digest is absent.

Extend `run-device-app-cert.sh` with `CERT_PROTOCOL=cold40`, `CONDITIONS_JSON=<path>`, and `CERT_RECEIPT_PATH=<path>`. In that mode it launches the existing `BASEnduranceAppRunner`, waits for the protocol-final marker rather than the first smoke line, copies the full bounded receipt, and fails unless the runner proves exactly 100 measured turns. Extend `run-endurance-watchdog.sh` with `STRICT_CONTINUOUS=1`, `CONDITIONS_JSON=<path>`, and `CERT_RECEIPT_PATH=<path>`. Strict mode launches exactly one duration-based runner segment, never kills/relaunches, treats stall/crash/suspension/device lock as terminal failure, requires the runner's monotonic measured duration to be at least 1800 seconds, and preserves every minute sample. The existing default watchdog/recovery behavior remains unchanged outside strict mode.

Both claim modes consume a preregistered per-device conditions JSON whose schema is owned by `BASAppleSiliconCertification.swift`: physical device ID, measured ambient Celsius plus measurement evidence artifact ID, Low Power Mode expectation, battery/external-power state, screen/radio state, declared active-cooling state, competing-app declaration, model/runtime residency, JIT/AOT/specialization state, cache/prefix state, prompt/context/output buckets, sampling/RNG/termination rules, arrival interval, and failure/exclusion policy. The app receipt records the observed device ID, Low Power Mode, public thermal sequence, power state, installed tree/runtime identity, and protocol timestamps; the evaluator requires the declaration and observation to match and requires ambient in `[20.0, 24.0]` for cold 40.

- [ ] **Step 6: Add one shell controller that aggregates the existing scripts**

Create `scripts/run-architecture-cert.sh` with `set -euo pipefail`. It requires `--mode device`, two different UDIDs, `--device-a-conditions <json>`, `--device-b-conditions <json>`, a candidate tree, an output directory that does not exist, and zero or more repeatable `--claim cold40` / `--claim sustained30` arguments. Reject duplicate/unknown claims, missing condition files, and a condition-file device ID that differs from its UDID. It verifies that it is executing inside the exact materialized tree:

```bash
ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_TREE="$BAS_CANDIDATE_TREE_ID"
test "$(git -C "$ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_TREE"
git -C "$ROOT" diff --quiet
git -C "$ROOT" diff --cached --quiet
test "$BAS_DEVICE_A_UDID" != "$BAS_DEVICE_B_UDID"
test -s "$BAS_DEVICE_A_CONDITIONS"
test -s "$BAS_DEVICE_B_CONDITIONS"
mkdir "$BAS_CERT_OUTPUT"
```

Build/install from that root, then invoke the current collectors without changing their internal verdict ownership:

```bash
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  >"$BAS_CERT_OUTPUT/owner-ledger-pass.json"
OWNER_LEDGER_DIGEST="$(shasum -a 256 "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" | awk '{print $1}')"
OWNER_VERIFIER_DIGEST="$(shasum -a 256 "$ROOT/scripts/check_qinao_owner_ledger.py" | awk '{print $1}')"
```

The pass JSON must decode with `status == "pass"`, an empty `violations` array, and the complete canonical `checked_owner_keys` vector. Store the ledger, verifier script, and pass JSON through Artifact Mesh and include all three artifact IDs plus both SHA-256 values in `BASCandidateTreeAttestation`. Re-run the command after device cohorts and deny if either file digest or output changes.

```bash
for device in "$BAS_DEVICE_A_UDID" "$BAS_DEVICE_B_UDID"; do
  DEVICE_ID="$device" BUILD=1 \
    bash "$ROOT/BehavioralAISubstrate/scripts/run-device-app-cert.sh" \
    >"$BAS_CERT_OUTPUT/device-$device-runtime.log" 2>&1
  DEVICE_ID="$device" BUILD=0 \
    bash "$ROOT/BehavioralAISubstrate/scripts/run-spec-decode-cert.sh" \
    >"$BAS_CERT_OUTPUT/device-$device-spec.log" 2>&1
  MODE=device DEVICE_ID="$device" \
    bash "$ROOT/BehavioralAISubstrate/scripts/run-coreai-e2e-cert.sh" \
    >"$BAS_CERT_OUTPUT/device-$device-coreai.log" 2>&1
  DEVICE_ID="$device" BUILD=0 N=8 MODE=fullturn \
    bash "$ROOT/BehavioralAISubstrate/scripts/run-concurrent-turns-cert.sh" \
    >"$BAS_CERT_OUTPUT/device-$device-concurrency.log" 2>&1
done
```

Before launch, decode each conditions file with rejection of unknown fields, canonicalize it, store it through Artifact Mesh, and record its artifact ID and SHA-256 in the preregistration receipt. Re-read it after each cohort and deny on any byte/digest change. After parsing repeatable claims into a duplicate-free list, use this helper and the two extended current launch owners:

```bash
claim_requested() {
  local wanted="$1"
  local claim
  for claim in "${BAS_REQUESTED_CLAIMS[@]}"; do
    test "$claim" = "$wanted" && return 0
  done
  return 1
}

for device in "$BAS_DEVICE_A_UDID" "$BAS_DEVICE_B_UDID"; do
  if test "$device" = "$BAS_DEVICE_A_UDID"; then
    conditions="$BAS_DEVICE_A_CONDITIONS"
    label=device-a
  else
    conditions="$BAS_DEVICE_B_CONDITIONS"
    label=device-b
  fi

  if claim_requested cold40; then
    DEVICE_ID="$device" BUILD=0 CERT_PROTOCOL=cold40 \
      CONDITIONS_JSON="$conditions" \
      CERT_RECEIPT_PATH="$BAS_CERT_OUTPUT/$label-cold40.json" \
      POLL_SEC=15 MAX_POLL=3000 \
      bash "$ROOT/BehavioralAISubstrate/scripts/run-device-app-cert.sh" \
      >"$BAS_CERT_OUTPUT/$label-cold40.log" 2>&1
  fi

  if claim_requested sustained30; then
    DEVICE_ID="$device" BUILD=0 STRICT_CONTINUOUS=1 \
      WATCHDOG_MINUTES=35 CONDITIONS_JSON="$conditions" \
      CERT_RECEIPT_PATH="$BAS_CERT_OUTPUT/$label-sustained30.json" \
      bash "$ROOT/BehavioralAISubstrate/scripts/run-endurance-watchdog.sh" \
      >"$BAS_CERT_OUTPUT/$label-sustained30.log" 2>&1
  fi
done
```

For requested cold 40, the existing app runner preregisters and runs exactly 100 turns per device. Before each measured turn it observes 300 uninterrupted seconds of public `.nominal` thermal state and enforces the ambient/power/cache/timer contract above; any reset restarts that turn's 300-second entry window and is recorded. For requested sustained 30, the existing duration-based runner accepts the fixed workload continuously for at least 1800 monotonic seconds with no inserted cool-down or relaunch, retaining per-minute and last-quarter samples. A controller timeout, process interruption, device lock, incomplete cohort, missing log, parser failure, failed/excluded turn, or receipt/tree/runtime mismatch remains a recorded deny; the script does not delete or reinterpret it.

Convert current outputs to bounded typed evidence JSON, store each body through Artifact Mesh, generate one `BASAppleSiliconCertificationInput`, and run:

```bash
swift run --package-path "$ROOT/BehavioralAISubstrate" \
  --scratch-path "$BAS_CERT_OUTPUT/verifier-build" \
  BASArchitectureCertVerifier evaluate \
  --input "$BAS_CERT_OUTPUT/certification-input.json" \
  --output "$BAS_CERT_OUTPUT/promotion-verdict.json"
swift run --package-path "$ROOT/BehavioralAISubstrate" \
  --scratch-path "$BAS_CERT_OUTPUT/verifier-build" \
  BASArchitectureCertVerifier verify \
  --verdict "$BAS_CERT_OUTPUT/promotion-verdict.json" \
  --expected-tree "$EXPECTED_TREE" \
  --expected-runtime-digest "$(awk -F= '$1 == "runtime_executable_sha256" { print $2 }' "$BAS_CERT_OUTPUT/runtime-identity.env")" \
  --expected-owner-ledger-digest "$OWNER_LEDGER_DIGEST" \
  --expected-owner-verifier-digest "$OWNER_VERIFIER_DIGEST"
```

The script never reads MetricKit output into an E4 gate. If E5 evidence is available, it is attached after the E4 verdict as a canary reference.

- [ ] **Step 7: Run GREEN, CLI negative cases, script syntax, and current collector regressions**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASAppleSiliconCertificationTests|BASTurnRuntimeDefaultModeFlipReadinessGateTests|BASStressSweepHarnessTests|BASSystemProbeTests|BASThermalTwinTests'
bash -n /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-architecture-cert.sh
bash -n /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-device-app-cert.sh
bash -n /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/run-endurance-watchdog.sh
if swift run --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  BASArchitectureCertVerifier require-promotion \
  --verdict /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/Fixtures/certification/deny-missing-e4.json \
  --expected-tree 0000000000000000000000000000000000000000 \
  --expected-owner-ledger-digest 0000000000000000000000000000000000000000000000000000000000000000 \
  --expected-owner-verifier-digest 0000000000000000000000000000000000000000000000000000000000000000; then
  exit 1
fi
```

Expected: all selected tests PASS with 0 failures; all three touched shell scripts pass `bash -n`; the known deny fixture exits nonzero; MetricKit cannot satisfy E4; both threshold protocols pass/fail at every exact condition and threshold boundary.

- [ ] **Step 8: Commit**

```bash
git add BehavioralAISubstrate/Package.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift \
  BehavioralAISubstrate/Sources/BASArchitectureCertVerifier/main.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeDefaultModeFlipReadinessGate.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASStressSweepHarness.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASProbeCommon.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASFieldMetricsCollector.swift \
  BehavioralAISubstrate/DeviceTestApp/project.yml \
  BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj \
  BehavioralAISubstrate/scripts/run-device-app-cert.sh \
  BehavioralAISubstrate/scripts/run-endurance-watchdog.sh \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAppleSiliconCertificationTests.swift \
  BehavioralAISubstrate/Tests/Fixtures/certification/deny-missing-e4.json \
  BehavioralAISubstrate/scripts/run-architecture-cert.sh
git commit -m "feat: aggregate candidate-bound device certification"
```

---

### Task 7 [W6]: Certify the Exact Candidate Tree, Then Cut Over Every Production Entrypoint

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift`
- Relocate without changing the owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry.swift` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry.swift`
- Relocate without changing the owner: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineSQLLoader.swift` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineSQLLoader.swift`
- Relocate supporting literals: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals.swift` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry+AllLiterals.swift`
- Relocate supporting literals: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+Literals.swift` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry+Literals.swift`
- Relocate audit resources: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/010_chapter_doctrine_records_schema.sql` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/010_chapter_doctrine_records_schema.sql`
- Relocate audit resources: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/011_chapter_doctrine_literals_data.sql` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/011_chapter_doctrine_literals_data.sql`
- Relocate audit resources: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/012_chapter_doctrine_phase2_data.sql` → `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/012_chapter_doctrine_phase2_data.sql`
- Modify to retain only the separate entropy SQL path: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEntropyChapterIndex.swift`
- Modify audit consumer tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapterDoctrineRegistryTests.swift`
- Modify audit consumer tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapterDoctrineLoaderDegradeTests.swift`
- Modify audit consumer tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRegistryFrozenHashTests.swift`
- Modify audit consumer tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAllLiteralsByteMirrorTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHistoryAuditProductBoundaryTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift`
- Delete mode-selection surface: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift`
- Delete retired mode-selection doctrine: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Construction.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASSubstrateReauditShadowEvaluator.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASChengluHostRuntimeBuilder+CoreML.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASSSMCautionProbe.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostAFMBenchEntry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostBASHostInvocation.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostBenchPanel.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostBenchPostLLMObserver.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostChengluStressRunner.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostHybridBenchEntry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostLegacyBenchEntry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/SampleHostModel.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/CthulhuEndToEndDemo.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/FullStackBench.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/KunlunEndToEndDemo.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/MultiSessionContinuity.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostDemoExtensions.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostDoctrineBenchExtensions.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLoRAExtensions.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLongSmokeBenchExtensions.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationPhaseFTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExtensionPointInventoryTests.swift`
- Modify as cutover-absence proof: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPhaseLPostFlipV1PathCallabilityProofTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainProbabilityDistributionTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainFacadeIntegrationTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASShadowTrialCarrierLoopTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBiomimeticAutoCheckpointTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBiomimeticCheckpointReplayTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter473CleanupTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineBiomimeticHookTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineHostInjectionTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineLedgerLocalityTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEnginePhaseFTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineTurnSerializationTests.swift`
- Modify explicit-legacy engine tests: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeNativeV2DispatchTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter1039DeliberationLoopTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter1042EvidenceResolutionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter946FourteenLayerFuzzSmokeTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952ExtremeFuzzTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952_4HighBarBenchmarkTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChenglu20MinStressTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluComprehensiveOptInIntegrationTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluFullChainE2ETests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluHostRuntimeBuilderTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluSweepInterpreterTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitConstitutionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitRunModeLaneTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostRuntimeMeshHookTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostRuntimeMeshSweepTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryClosedLoopApplierHostRuntimeIntegrationTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNeuralHeadShadowRecorderTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSSMCautionOperatorRunTurnTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticAdjudicatingStreamingTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSignal10EmpiricalDiagnosisTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSleepConsolidationDriverTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignLedgerHostSinkTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSubstrateReauditShadowEvaluatorTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M299FrontierSummaryConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M300TribunalCoverageConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M303AbyssalPressureConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M304HumanAnchorAndSealConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M305EvolutionLifecycleConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M306MultiSessionContinuityTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M316NarrativeDistortionConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M317AnomalyTraceConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M318AbyssalBranchConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M320UnknownReserveConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M321ForbiddenKnowledgeConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M336SovereignTokenIDDeterminismTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M402KunlunAxisAuditTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M404M405KunlunJadeRiverAuditTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M408M409M410KunlunYaochiTianmenAuditTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M418EscalationSuppressionAuditEmissionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M436LayerReconciliationConsumptionTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M448CthulhuLayerProductionWiringTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M457ForbiddenZoneGateLifecycleIntegrationTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M480KunlunProductionWiringTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M486KunlunDreamLoopWiringTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M491KunlunIntegrityCthulhuLeftoverWiringTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M500KunlunL4LeftoverSurfaceAliasWiringTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M541SubstrateValueAddTests.swift`
- Modify explicit-legacy test call sites: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M603FourteenLayerSmokeTests.swift`
- Modify explicit-legacy Qinao tests: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/M359FullStackBenchTests.swift`
- Modify explicit-legacy Qinao tests: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostCthulhuEndToEndDemoTests.swift`
- Modify explicit-legacy Qinao tests: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostKunlunEndToEndDemoTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAuthoritativeEntrypointTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv`
- Create after successful promotion: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Docs/APPLE_SILICON_14L_CONVERGENCE_STATUS.md`

The file-list labels “explicit-legacy engine tests/call sites” describe their pre-edit inventory state, not their destination. Step 6 converts runtime/host integration tests to authoritative/shadow composition and converts true byte-compatibility tests to direct test-target coordinator fixtures; none retains a legacy runtime/host factory.

**Reuse Decision (E/delete + A):** Extend existing runtime configuration, host synthesis/façades, Apple wiring, apps, and Qinao call sites, then delete production-selectable V1/native-Any routes. Relocate owner-ledger row `history.doctrine-metadata` as its existing class-A archive into one explicitly nonshipping `BASHistoryAudit` target/product; this is relocation of the current registry/loader/SQL bytes, not a new M owner or a second doctrine registry. The HostKit builder is the sole BAS composition point for memory gateway/resolver and the Silicon plan's typed-root, policy-bound `TurnOperation`; Qinao passes the same singleton actor/host-injected Provider registry into that composition and owns neither ledger nor branch router. Apple edge wiring supplies only prerequisite Provider adapters. No new runtime/result/publication/memory/fallback owner is added.

**Interfaces:**
- Consumes: Task 5 dependencies, Task 6 verdict, exact candidate/runtime/two-device/owner-ledger evidence, sovereign release owners, and Silicon's one typed-root `TurnOperation` with installed Provider policy/binding, injected branch-control port, host Provider registry/preflight seam, verifier gateway, and process-shared ledger.
- Produces: required `BASTurnRuntimeEngineConfiguration.productionSemantic(dependencies:)`, async authoritative host entrypoints, a complete migration inventory with no production legacy row, and a promotion commit whose Git tree is byte-identical to the certified tree.
- Production entrypoint rule: `startSession`, `bootstrap`, `handleEntryIntent`, `reopen`, `refreshCurrentBrain`, `BASCognitiveBrain.process`, the Apple builder, and DeviceTestApp use `.semanticDAGAuthoritative` with injected dependencies. None may infer a mode, construct V1, or catch an authoritative failure and call V1.
- Rollback/test rule: after cutover, rollback deploys the preceding certified commit/tree. `.v1ByteEqual`, `.nativeV2`, `.explicitLegacyV1`, mode-selecting environment bridges, `buildLegacyEBrainTurn*`, `startLegacySession`, `bootstrapLegacy`, `handleLegacyEntryIntent`, `reopenLegacySession`, and `refreshLegacyCurrentBrain` are absent from production sources and products. Tests of the old coordinator call test fixtures directly and cannot be linked from app/host/Qinao targets.

- [ ] **Step 0 [owner-ledger A]: Relocate dormant doctrine/history metadata out of the Release graph**

Before changing authoritative entrypoints, export the current `BASChapterDoctrineRegistry.all` canonical bytes, ordered record count, lookup answers, and the SHA-256 of each `010`/`011`/`012` SQL resource into a temporary test fixture outside the source tree. Move the existing registry, SQL loader, literal-support sources, and those exact three SQL files into one `BASHistoryAudit` target with one explicitly dev/audit-only library product of the same name. The target depends on `BASRuntimeCore` only for the existing immutable `BASChapterDoctrineRecord` value. It owns no runtime state, policy, gate, scheduler, persistence writer, or new schema; source-control history plus the relocated resources remain recovery. Do not copy the sources/resources, leave forwarding aliases in `BASRuntimeCore`, or create another metadata owner.

Remove the three doctrine resources from the `BASRuntimeCore` target. Keep `021_entropy_chapter_entries_schema.sql` and `022_entropy_chapter_entries_data.sql` in RuntimeCore, and move their read-only loading into the existing `BASEntropyChapterIndex.swift` owner so production entropy behavior does not retain or link `BASChapterDoctrineSQLLoader`. Migrate every direct registry/loader consumer found by `rg -l 'BASChapterDoctrineRegistry|BASChapterDoctrineSQLLoader' BehavioralAISubstrate/Sources BehavioralAISubstrate/Tests --glob '*.swift'`: historical/audit consumers import `BASHistoryAudit` only from the nonshipping test/audit graph; production files may retain narrative strings but no symbol reference. `Package.swift` must make the shipping products/app targets unable to reach `BASHistoryAudit`; availability as an explicitly selected audit product is not transitive shipping reachability.

Treat this class-A relocation as one exact owner-ledger lifecycle, not a rename-only exception. The starting `relocation_candidate` row lists the seven existing RuntimeCore source/resource paths plus `BehavioralAISubstrate/Package.swift`. In the same atomic change that moves the **first** path and edits `Package.swift`, change the row to `converging` and set `evidence_paths` to `Package.swift` plus every old/new allowlisted path that exists at that partial point. After each later move, atomically replace the evidence list with the exact then-existing old/new set plus `Package.swift`; run both `scripts/check_qinao_owner_ledger.py` and `scripts/test_check_qinao_owner_ledger.py` after every step. Only after all seven BASHistoryAudit destinations exist, all seven RuntimeCore origins are absent, archive/consumer/build/resource/Release-isolation gates pass, and every stated conflict is resolved may the same change set `status: implemented`, set `evidence_paths` to exactly the seven destination paths plus `Package.swift`, and set `current_conflicts: []`; retain the row's satisfied `retirement_gate` as acceptance history. Failure rolls the path move, Package edit, evidence list, conflicts, and status back together. No `retired`/`relocated` pseudo-status or new M row is permitted.

`BASHistoryAuditProductBoundaryTests` proves four gates: (1) archive parity—the moved registry's canonical bytes/count/lookups and all three SQL digests equal the pre-move fixture; (2) consumer parity—all migrated audit tests still pass and entropy-index answers remain byte-equal; (3) build/resource parity—`swift build --product BASHistoryAudit` finds exactly the three doctrine SQL resources once; and (4) Release isolation—the resolved shipping target graph contains no `BASHistoryAudit`, `BASChapterDoctrineRegistry`, or `BASChapterDoctrineSQLLoader`, the built app/library link map and symbol table contain neither registry nor loader, and the Release bundle/archive contains none of the three SQL basenames. Test both generic iOS Release and the package Release products. A missing archive resource, changed byte, unclassified consumer, duplicate resource, or any shipping link/resource occurrence fails closed; silent deletion is never accepted as relocation.

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 "$ROOT/scripts/test_check_qinao_owner_ledger.py"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASHistoryAuditProductBoundaryTests|BASChapterDoctrineRegistryTests|BASChapterDoctrineLoaderDegradeTests|BASRegistryFrozenHashTests|BASAllLiteralsByteMirrorTests|BASEntropyChapterIndexTests'
swift build -c release --package-path "$ROOT/BehavioralAISubstrate" --product BASHistoryAudit
test "$(find "$ROOT/BehavioralAISubstrate/Sources/BASHistoryAudit/SQL" -type f -name '01*_chapter_doctrine_*.sql' | wc -l | tr -d ' ')" = 3
! find "$ROOT/BehavioralAISubstrate/Sources/BASRuntimeCore" -type f \
  \( -name '010_chapter_doctrine_records_schema.sql' \
     -o -name '011_chapter_doctrine_literals_data.sql' \
     -o -name '012_chapter_doctrine_phase2_data.sql' \) -print | grep -q .
! rg -n 'BASChapterDoctrineRegistry|BASChapterDoctrineSQLLoader|010_chapter_doctrine_records_schema|011_chapter_doctrine_literals_data|012_chapter_doctrine_phase2_data' \
  "$ROOT/BehavioralAISubstrate/.build"/release \
  "$ROOT/SampleHost"/build/Release-* 2>/dev/null
```

Expected: the explicit audit product and migrated audit tests preserve the archived bytes, while every certified Release graph/link image/bundle is free of the owner and its three resources. The owner-ledger row follows `relocation_candidate → converging → implemented` only under the exact path/evidence/conflict gates above; no pseudo-status, M row, or runtime authority is added.

- [ ] **Step 1: Generate the pre-edit inventory and write failing cutover tests**

Generate the authoritative-entrypoint inventory before changing a call site. The command must fail if it cannot parse every source file; it must not silently omit an unreadable directory.

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
swift run --package-path "$ROOT/BehavioralAISubstrate" \
  BASArchitectureCertVerifier scan-entrypoints \
  --root "$ROOT" \
  --output "$ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"
```

The TSV has a header and one row for every declaration and call in the five host entrypoint families, every `BASTurnRuntimeEngine`, `BASHostRuntime`, `BASChengluHostRuntimeBuilder`, and `BASCognitiveBrain` construction, every `BASCognitiveBrain.process` call, every `buildEBrainTurn`/`buildEBrainTurnWithRuntimeMode` call, and every runtime-configuration construction. Its columns are exactly:

```text
relative_path\tline\tsymbol\tusage\tclassification\truntime_mode\tdependency_source\tmigration_state
```

Allowed classifications are `productionAsync`, `nonShippingTestHarness`, and `implementationBoundary`. Migration states are `unmigrated`, `authoritativeInjected`, `excludedFromShippingProduct`, and `implementationOnly`; `unmigrated` is permitted only in this pre-edit RED inventory and is forbidden by the final scanner. A `nonShippingTestHarness` row must belong to a test target or a scheme/product excluded from the certified shipping graph; production sources cannot earn that classification. Sort by UTF-8 relative path, line, and symbol; duplicate or unclassified rows are errors.

Create `check-authoritative-entrypoints.sh` now as the executable RED audit harness over Task 6's `scan-entrypoints` command. Give it the strict argument, temporary-regeneration, byte-comparison, and rejection rules specified in Step 6, including rejection of every `unmigrated` row. Run `bash -n` before the RED invocation. The script is test/audit infrastructure; writing it does not implement a production cutover.

Create `BASAuthoritativeEntrypointTests.swift` with spies backed by the existing engine, Artifact Mesh, manifest index, concrete prerequisite LayerCells/mechanism adapters, event log, sovereign publication coordinator, and the same sovereign publication journal:

```swift
import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASAuthoritativeEntrypointTests: XCTestCase {
    func testProductionStartSessionUsesOneSemanticResultAndOnePublication() async throws {
        let fixture = try await AuthoritativeEntrypointFixture.make()
        let session = try await fixture.runtime.startSession(fixture.sessionRequest)

        let semanticTurnCount = await fixture.semanticNodeExecutor.turnCount
        let legacyTurnCount = await fixture.legacyCoordinator.runTurnCount
        let resultPutCount = await fixture.artifactStore.resultPayloadPutCount
        let manifestPutCount = await fixture.artifactStore.manifestPutCount
        let manifestReopenCount = await fixture.artifactStore.manifestReopenCount
        let timeline = await fixture.timeline.events
        let publishExactCount = await fixture.publicationCoordinator.publishExactCount
        let finalizationCount = await fixture.publicationCoordinator.finalizationAppendCount
        let publicationManifestLookupCount = await fixture.publicationCoordinator
            .finalizedPublicationRecordLookupCount
        let resultProjectionCount = await fixture.resultProjectionCount
        let providerInvocationCount = await fixture.provider.invocationCount
        let spoolFinalizationCount = await fixture.spool.finalizationCount
        XCTAssertEqual(semanticTurnCount, 1)
        XCTAssertEqual(legacyTurnCount, 0)
        XCTAssertEqual(resultPutCount, 1)
        XCTAssertEqual(manifestPutCount, 1)
        XCTAssertEqual(manifestReopenCount, 2)
        XCTAssertLessThan(
            try XCTUnwrap(timeline.firstIndex(of: .manifestReopened)),
            try XCTUnwrap(timeline.firstIndex(of: .publicationReserved))
        )
        XCTAssertEqual(publishExactCount, 1)
        XCTAssertEqual(finalizationCount, 1)
        XCTAssertEqual(publicationManifestLookupCount, 1)
        XCTAssertLessThan(
            try XCTUnwrap(timeline.firstIndex(of: .publicationFinalized)),
            try XCTUnwrap(timeline.firstIndex(of: .publicationResolvedByManifest))
        )
        XCTAssertEqual(session.eBrainTurn, fixture.canonicalResult)
        XCTAssertEqual(resultProjectionCount, 1)
        XCTAssertEqual(providerInvocationCount, 1)
        XCTAssertEqual(spoolFinalizationCount, 1)
    }

    func testEveryProductionEntrypointFailsClosedWithoutLegacyFallback() async throws {
        for entrypoint in ProductionEntrypointFixture.allCases {
            let fixture = try await AuthoritativeEntrypointFixture.make(
                failure: .manifestReopenUnavailable
            )
            let result = try await entrypoint.invoke(fixture)
            let legacyTurnCount = await fixture.legacyCoordinator.runTurnCount
            let publishExactCount = await fixture.publicationCoordinator.publishExactCount
            XCTAssertTrue(result.eBrainTurn?.isTypedFailClosedDisposition == true)
            XCTAssertEqual(legacyTurnCount, 0)
            XCTAssertEqual(publishExactCount, 0)
        }
    }

    func testShippingSourceContainsNoLegacyRuntimeSurface() throws {
        let findings = try ShippingSourceScanner.scanForForbiddenRuntimeRoutes()
        XCTAssertTrue(findings.isEmpty, findings.joined(separator: "\n"))
    }

    func testAuthoritativeConfigurationRequiresCompleteDependencies() throws {
        XCTAssertThrowsError(
            try BASTurnRuntimeEngineConfiguration.productionSemantic(
                dependencies: incompleteAuthoritativeDependencies()
            )
        )
        XCTAssertNoThrow(
            try BASTurnRuntimeEngineConfiguration.productionSemantic(
                dependencies: fixtureAuthoritativeDependencies()
            )
        )
    }
}
```

Add focused assertions to the six existing tests so direct constructors, `.nativeV2`, `.v1ByteEqual`, native-Any executors, and direct coordinator calls cannot reappear on production faces. Replace `BASPhaseLPostFlipV1PathCallabilityProofTests` with a cutover-absence assertion; old coordinator byte-compatibility remains covered by its direct unit tests and is not exposed through runtime/host APIs.

Also add `testProductionBuilderUsesOneProcessSharedLedgerAndOneTurnContextLineage`. Obtain the actor references exposed by the semantic lane fixture, `semanticLayerCellExecutor`, authoritative dependencies, publication outer scope, and replay dependencies and assert each is `=== BASProcessMemoryLedger.processShared`. Run one turn and assert every captured reservation token binds the exact turn capability-snapshot artifact ID, epoch, and context version, while reflection over query/result/invocation/receipt/manifest/publication payloads finds no copied admission field. A second test injects isolated ledgers only through test fixtures and proves production builder code has no such constructor path.

- [ ] **Step 2: Run the focused tests and scanner to verify RED**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASAuthoritativeEntrypointTests|BASTurnRuntimeEngineConfigurationPhaseFTests|BASExtensionPointInventoryTests|BASTurnOperationCutoverTests|BASNativeStageCapabilityTests|BASCognitiveBrainProbabilityDistributionTests|BASCognitiveBrainFacadeIntegrationTests|BASShadowTrialCarrierLoopTests'
bash "$ROOT/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh" \
  --root "$ROOT" \
  --inventory "$ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"
```

Expected: tests FAIL because production semantic composition is incomplete and legacy/native-Any routes still exist. The scanner exits nonzero and reports current synchronous production calls, `.nativeV2`/`.v1ByteEqual`, direct coordinator/native-Any/provider calls, and unclassified constructor/call rows. The RED evidence is the exact failing test name plus exact scanner row; do not weaken either rule to make the baseline pass.

- [ ] **Step 3: Make runtime configuration explicit and fail closed**

Extend `BASTurnRuntimeEngineConfiguration` in place. Make its designated initializer private, remove the default value from its `runtimeMode` parameter, remove the zero-argument `.default()` route, and expose only the validated production factory plus the observation-only shadow factory:

```swift
package extension BASTurnRuntimeEngineConfiguration {
    static func productionSemantic(
        dependencies: BASSemanticAuthoritativeDependencies
    ) throws -> Self {
        try dependencies.validateComplete()
        return Self.acceptedProduction(
            eventLog: dependencies.k3,
            runtimeMode: .semanticDAGAuthoritative,
            semanticAuthoritativeDependencies: dependencies
        )
    }

}
```

The package factories validate this matrix: `.semanticDAGAuthoritative` requires complete authoritative dependencies and the exact accepted `TurnOperationFactory`; `.semanticDAGShadow` requires its same-run read-only evidence dependencies and has no publication/effect/provider-authority ports. Qinao/apps receive only the returned public opaque configuration; no public signature mentions a package type. Event IDs and logical time come from the same K3/EventLog owner, never default UUID/wall-clock closures. Remove `.v1ByteEqual`, `.nativeV2`, and `.stressSweepDual` from `BASTurnRuntimeMode`; remove `explicitLegacyV1`, `explicitLegacyNativeV2Migration`, `explicitLegacyStressSweep`, public `with(runtimeMode:)`, and mode-selecting environment bridges. Ancillary immutable update methods preserve and revalidate the existing mode/dependency pair. No public/package zero-argument constructor or raw mode initializer remains.

In `BASTurnRuntimeEngine`, remove the raw multi-parameter and `init(coordinator:configuration:)` entrypoints that accept a V1 coordinator as a result-producing dependency. The public production initializer accepts only validated configuration and the exact dependencies needed by `TurnOperation`. Shadow instrumentation may receive a read-only baseline observation closure in test/nonshipping composition, but authoritative configuration structurally has no V1/native-Any callback slot. Update old engine tests to exercise `BASEBrainRuntimeCoordinator` directly when byte-compatibility is the subject; runtime tests use the production or shadow factory. A production source cannot obtain V1 by omission, enum case, environment, or injected closure.

This cutover must preserve audit-bundle reachability. The authoritative semantic core reduces its own same-run typed node/result/risk/audit evidence into the already-frozen `BASRuntimeAuditProjectionsBundle`, then constructs the sole Task-1B `BASSameRunAuditOutcome(result:auditProjections:)`; it does not call the legacy coordinator, accept a caller bundle, or run a second semantic/result core. The engine consumes that outcome exactly as the pre-cutover path did: central-codec ordinary-put the self-ID-free bundle once under the exact Attempt/turn root, take only the receipt Artifact ID, same-class-bound-store reopen/current-decode/byte-equality-check, and set the final envelope's `runtimeAuditProjectionsBundleArtifactID`. A publishable `.complete` cannot carry nil. Source tests require one outcome declaration, zero production `coordinator.runTurn`/`runTurnWithAuditOutcome` calls after cutover, exactly one bundle put, and no `lastAudit`, bundle sink/cache, caller-supplied bundle, or second execution.

- [ ] **Step 4: Delete production legacy surfaces and make the sole host surfaces async**

In `HostRuntimeCore.swift`, add `public let turnRuntimeConfiguration: BASTurnRuntimeEngineConfiguration` beside the existing immutable dependencies, delete synchronous/mode-selecting runtime entrypoints, and keep one private accepted initializer used only by the validated production initializer. It is not another runtime factory or mode authority:

```swift
extension BASHostRuntime {
    private init(
        accepted configuration: BASHostConfiguration,
        turnRuntimeConfiguration: BASTurnRuntimeEngineConfiguration,
        dependencies: BASHostDependencySet,
        vitalMonitor: (any BASVitalMonitorServicing)?,
        meshRegistry: BASLayerMLHeadRegistry?
    ) {
        self.configuration = configuration
        self.turnRuntimeConfiguration = turnRuntimeConfiguration
        self.dependencies = dependencies
        self.vitalMonitor = vitalMonitor
        self.meshRegistry = meshRegistry
    }

    public init(
        configuration: BASHostConfiguration,
        turnRuntimeConfiguration: BASTurnRuntimeEngineConfiguration,
        dependencies: BASHostDependencySet = BASHostDependencySet(),
        vitalMonitor: (any BASVitalMonitorServicing)? = nil,
        meshRegistry: BASLayerMLHeadRegistry? = nil
    ) throws {
        guard turnRuntimeConfiguration.runtimeMode == .semanticDAGAuthoritative else {
            throw BASAuthoritativeRuntimeFailure.missingAuthoritativeComposition
        }
        self.init(
            accepted: configuration,
            turnRuntimeConfiguration: turnRuntimeConfiguration,
            dependencies: dependencies,
            vitalMonitor: vitalMonitor,
            meshRegistry: meshRegistry
        )
    }

}
```

The production initializer accepts only `.semanticDAGAuthoritative` with complete dependencies. There is no legacy factory, nil/default mode fallback, or production synchronous session surface. Tests that need V1 byte-compatibility instantiate the old coordinator inside the test target without routing it through `BASHostRuntime`.

Add async production methods with the original production names. They reuse the current host projection/bootstrap/presentation helpers but obtain their one turn from the injected `BASTurnRuntimeEngine` authoritative branch:

```swift
public func startSession(
    _ request: BASHostSessionRequest,
    now: Date = .now
) async throws -> BASHostSessionResult

public func bootstrap(
    _ request: BASHostLifecycleRequest,
    now: Date = .now
) async throws -> BASHostSessionResult

public func handleEntryIntent(
    _ request: BASHostSessionRequest,
    now: Date = .now
) async throws -> BASHostSessionResult

public func reopen(
    _ request: BASHostReopenRequest,
    now: Date = .now
) async throws -> BASHostSessionResult

public func refreshCurrentBrain(
    _ request: BASHostSessionRequest,
    now: Date = .now
) async throws -> BASHostCurrentBrain
```

Each production method delegates to `startSession` or the same injected authoritative engine, never to a legacy method. It projects the one returned `BASEBrainTurnResult` into `BASHostSessionResult.eBrainTurn` exactly once. A typed pre-publication failure remains the single fail-closed result supplied by Task 5; an error after possible sink visibility uses sovereign recovery with the same barrier. No `catch` block calls `startLegacySession`, `buildEBrainTurn`, `coordinator.runTurn`, `.nativeV2`, or `.v1ByteEqual`.

In `EBrainHostRuntimeSynthesis.swift`, remove `runtimeMode = .v1ByteEqual` from the production face. The production interface is:

```swift
public func buildEBrainTurn(
    request: BASHostSessionRequest,
    currentBrain: BASHostCurrentBrain,
    projection: BASBrainProjection,
    deviceStateOverride: BASDeviceState? = nil,
    runtimeConfiguration: BASTurnRuntimeEngineConfiguration,
    now: Date = .now
) async throws -> BASEBrainTurnResult
```

It accepts only a validated production configuration, joins exactly one typed-root `TurnOperation`, and returns `BASEBrainTurnResult`. Delete old synchronous/mode-selecting synthesis helpers. If a direct coordinator fixture remains, keep it test-only. The authoritative switch has no V1/native-Any or Provider call outside the operation; every operation-internal physical call is authorized by a newly won K3 branch claim.

- [ ] **Step 5: Inject the certified composition through cognitive, Apple, and app production wiring**

Modify `BASCognitiveBrain` and `BASCognitiveBrain+Construction` so every initializer requires a validated runtime configuration or an already constructed engine. `process(_:)` invokes that engine once. Delete legacy/mode-inferred initializers from production sources; tests construct direct coordinator fixtures when needed.

Modify `BASChengluHostRuntimeBuilder.swift` so its sole shipping overload requires a validated `turnRuntimeConfiguration` and passes it to the production `BASHostRuntime` initializer; delete `buildLegacyForTestOrHarness` and mode-selecting overloads. Modify `BASChengluHostRuntimeBuilder+CoreML.swift` to assemble the prerequisite-owned components and call:

Inside the existing HostKit builder—not `BASAppleEdgeWiring`—use the exact `BASProcessMemoryLedger.processShared` actor supplied by production composition and construct one concrete `BASMemoryAdmissionContextGateway(verifier:)` from the injected prerequisite `BASMemoryAdmissionContextVerificationPort`. Inject that exact actor/gateway into all five semantic adapters, `semanticLayerCellExecutor`, `BASSemanticAuthoritativeDependencies`, outer publication, replay, and the provider-bound `TurnOperationFactory`; do not wrap either in a replaceable closure. At turn start, resolve the accepted capability-snapshot artifact through that gateway and never cache a `BASMemoryAdmissionContext`. `QinaoSovereignHostAssembly.makeProduction` obtains `.processShared` once and passes it into the host provider factory; identity tests prove it is the same actor the HostKit builder receives. It also captures the exact same production `BASK3ControlNucleusStorage` instance passed to HostKit—concretely the same `BASSQLiteEventLogStorage`—projects only the sovereign `QinaoPreparedEffectEvidenceLookup`, and injects only `QinaoRuntime.makePreparedEffectContextResolver(lookup:)` into `QinaoRuntime`; direct `QinaoPreparedEffectContext(validating:)`, a current-branch query, or a second K3 instance is forbidden. The same assembly constructs exactly one `QinaoSovereignEffectExecutor` with the exact `BASEffectBroker` actor from that authoritative host graph; object-identity/call-count tests reject another broker, executor, store/K3 verifier, local map, or receipt/permit synthesis. Unit tests pass isolated actors directly, but no production overload constructs another authority. The Apple-edge extension constructs the existing `BASExecutionPlan.BindingVerificationAdapter` from Apple mechanisms and passes the inferred value plus existing stores/probes into this HostKit assembly. It uses the explicit `BASAppleEdgeWiring → BASOrgan` dependency already added by the prerequisite Sovereign Task 5 for `BASToolEffectAdapter`; do not rely on a `BASHostKit` transitive import or add a second manifest edit here. The Apple edge still does not name or import `BASProcessMemoryLedger`, `BASMemoryAdmissionContextGateway`, or `BASMemoryAdmissionContext`, and it gains no `BASAppleEdgeWiring → BASLeaseLife` dependency.

```swift
let semanticArtifactReopener = try BASSemanticArtifactReopener(
    artifactStore: artifactStore)

let turnOperationFactory = try BASTurnRuntimeEngine.TurnOperationFactory.production(
    artifactStore: artifactStore,
    k3: replayIndexedEventLog,
    providerRegistry: providerRegistry,
    providerPreflightResolver: providerPreflightResolver,
    providerBranchPolicyArtifactID: providerBranchPolicyArtifactID,
    executionBindingArtifactID: executionBindingArtifactID,
    semanticNodeExecutor: semanticLayerCellExecutor,
    memoryLedger: memoryLedger,
    memoryContextGateway: memoryContextGateway)

let publicationManifestRequestResolver =
    BASTurnRuntimeEngineConfiguration.publicationManifestRequestResolver(
        artifactStore: artifactStore,
        k3: replayIndexedEventLog,
        semanticArtifactReopener: semanticArtifactReopener
    )

let responseReleaseCoordinator = try BASResponseReleaseCoordinator(
    artifactStore: artifactStore,
    k3: replayIndexedEventLog,
    publicationJournal: publicationJournal,
    publicationManifestRequestResolver: publicationManifestRequestResolver,
    exactSink: exactSink)

let runtimeConfiguration = try BASTurnRuntimeEngineConfiguration.productionSemantic(
    dependencies: BASSemanticAuthoritativeDependencies(
        semanticDAGArtifactID: semanticDAGArtifactID,
        semanticDAG: .canonical(),
        semanticLayerCellExecutor: semanticLayerCellExecutor,
        turnOperationFactory: turnOperationFactory,
        semanticArtifactReopener: semanticArtifactReopener,
        artifactStore: artifactStore,
        k3: replayIndexedEventLog,
        responseReleaseCoordinator: responseReleaseCoordinator,
        memoryLedger: memoryLedger,
        memoryContextGateway: memoryContextGateway)
)
```

Pass `publicationManifestRequestResolver` as the identically named required initializer argument when constructing `responseReleaseCoordinator`; the builder alone supplies the sovereign journal to that coordinator's private storage seam. Runtime/replay receive only the exact coordinator object and call `finalizedPublicationRecord(for:)`; no journal or read view enters either dependency bundle. The fixed resolver reopens and fully validates the indexed Task 4 manifest and sovereign release evidence before the coordinator becomes the first code that can reserve, claim, touch a sink, mark, or finalize.

Snapshot reopening uses `artifactStore.read` plus `BASReplayEvidenceDecoders.semanticSnapshot` and the exact same K3 integrity-prefix check inside the fixed validator; there is no `reopenSemanticSnapshot` closure or copied watermark vector.

`semanticLayerCellExecutor` is constructed from the concrete prerequisite `BASLayerCell<Core, Actor>` values and the same `artifactStore`, `memoryLedger`, and gateway; it is not a new router object or protocol. The builder returns the current host/cognitive façade and current engine; it does not introduce another composition/factory authority. DeviceTestApp obtains that same production builder and rejects launch when the embedded candidate-tree ID, executable digest, Artifact Mesh, exact `BASRuntimeK3Composite`, LayerCell execution closure, accepted `TurnOperationFactory`, manifest-request resolver, sovereign coordinator, process-shared ledger, memory gateway, or current probe dependency is missing or identity-split. `BASSSMCautionProbe` awaits that production runtime; it cannot use `try?` to erase a fail-closed disposition or call a synchronous legacy surface.

The builder injects the Silicon plan's identity-only Provider registry and preflight endpoint resolver into `TurnOperation`, together with the same branch-control port and shared ledger/gateway. For each policy `stepRuleID`, value-only preflight chooses among signed eligible Provider IDs before K3 allocation; after claim there is no fallback. Main user-model templates resolve `BASModelManifestRegistry.productionDefault` unless the user selected another manifest; signed grounding/verifier templates may resolve auxiliary Providers declared by the binding. Qinao obtains `BASProcessMemoryLedger.processShared` once and passes it into host composition; identity tests require `===`. Concrete MLX/Qwen/Core AI/Foundation Models stay outside Qinao.

Update `BASSubstrateReauditShadowEvaluator` to call only the Task 2 shadow route and existing replay harness. It never constructs authoritative publication dependencies and never returns a second result to a production caller.

- [ ] **Step 6: Migrate every shipping call site and isolate direct-coordinator tests**

Migrate SampleHost's shipping UI/model/invocation faces to `await` the injected semantic production runtime. Remove `SampleHostLegacyBenchEntry.swift` from the shipping SampleHost target (or delete it if no nonshipping scheme consumes it); it cannot call a HostKit legacy surface because none remains. Bench panels compare recorded results through `BASEBrainTurnResultReplayHarness`; they may not run V1 after an authoritative answer.

Migrate runtime/host integration tests to the semantic production or observation-only shadow factory. Tests whose subject is specifically old coordinator byte-compatibility instantiate `BASEBrainRuntimeCoordinator` directly in test fixtures and are classified `nonShippingTestHarness`; they do not construct `BASTurnRuntimeEngine`, `BASHostRuntime`, `BASCognitiveBrain`, or a Qinao host. Rewrite `BASTurnRuntimeNativeV2DispatchTests` as native-Any capability-denial coverage. Migrate QinaoSampleHost demonstrations to the authoritative injected factory or exclude their product/scheme from the shipping graph; no Qinao source calls V1/native-V2/legacy host APIs. Update direct Qinao tests and `M306MultiSessionContinuityTests` to assert authoritative operation/provider/spool identity and the shared ledger actor.

Keep `check-authoritative-entrypoints.sh` as the bounded shell adapter created for RED. It regenerates into a temporary file, byte-compares the committed TSV, and rejects:

- a missing or unclassified entrypoint/configuration row;
- `productionAsync` without `authoritativeInjected` and a nonempty dependency source;
- a production call to any `Legacy` symbol, `.v1ByteEqual`, `.nativeV2`, or `.stressSweepDual`;
- any production `coordinator.runTurn`, native-Any executor, `draft`/`streamDraft`, provider retry helper, synthetic `.executed`, direct tool-dispatch call, or Qinao `ToolExecutor`/`toolExecutor`/`consumedBundles`/direct handler closure;
- a production host entrypoint called without `await`;
- a generic wrapper whose implementation delegates to a legacy symbol;
- a zero-argument/default runtime configuration on a production path;
- a raw/defaulted `BASTurnRuntimeEngine` construction on a production path;
- a production Chenglu builder call without an injected authoritative runtime configuration;
- an implicit `BASCognitiveBrain` production construction;
- `.semanticDAGAuthoritative` without `semanticAuthoritativeDependencies`;
- a Qinao source/product row containing a concrete provider import/factory, legacy runtime route, or independently constructed ledger/HeavySeat;
- a source path absent from the committed inventory.

The script accepts only `--root <path> --inventory <path>`, validates both paths, uses `mktemp` plus `trap`, and emits no inventory body on success. Run `bash -n` before using it.

After all call-site edits, overwrite the pre-edit inventory with the final source-derived inventory and require that it has no `unmigrated` row:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
swift run --package-path "$ROOT/BehavioralAISubstrate" \
  BASArchitectureCertVerifier scan-entrypoints \
  --root "$ROOT" \
  --output "$ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"
if rg -n $'\tunmigrated$' \
  "$ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"; then
  exit 1
fi
```

- [ ] **Step 7: Run local GREEN gates before staging**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
bash -n "$ROOT/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh"
bash "$ROOT/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh" \
  --root "$ROOT" \
  --inventory "$ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASAuthoritativeEntrypointTests|BASTurnRuntimeEngineConfigurationPhaseFTests|BASExtensionPointInventoryTests|BASTurnOperationCutoverTests|BASNativeStageCapabilityTests|BASSovereignEffectReceiptTruthTests|BASProviderExecutionSpoolTests|BASCognitiveBrainProbabilityDistributionTests|BASCognitiveBrainFacadeIntegrationTests|BASShadowTrialCarrierLoopTests|BASProcessMemoryLedgerTests|BASHistoryAuditProductBoundaryTests|BASChapterDoctrineRegistryTests|BASChapterDoctrineLoaderDegradeTests|BASEntropyChapterIndexTests'
HOST_SOURCES=(
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASL8RoutedMemoryService.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift"
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift"
)
if rg -n 'BASProcessMemoryLedger[[:space:]]*\(|hardCapBytes:|private var .*([Rr]eservation|[Hh]eavy)' "${HOST_SOURCES[@]}"; then
  exit 1
fi
if rg -n 'BASProcessMemoryLedger|BASMemoryAdmissionContextGateway|BASMemoryAdmissionContext' \
  "$ROOT/BehavioralAISubstrate/Sources/BASAppleEdgeWiring" --glob '*.swift'; then
  exit 1
fi
swift package --package-path "$ROOT/BehavioralAISubstrate" dump-package | \
python3 -c 'import json,sys; p=json.load(sys.stdin); d={t["name"]:{x["byName"][0] for x in t["dependencies"] if "byName" in x} for t in p["targets"]}; assert {"BASEffectBroker","BASOrgan"} <= d["BASAppleEdgeWiring"]; assert "BASLeaseLife" not in d["BASAppleEdgeWiring"]'
swift test --package-path "$ROOT/BehavioralAISubstrate"
swift test --package-path "$ROOT/QinaoRuntimeSDK"
! rg -n '\.v1ByteEqual|\.nativeV2|\.stressSweepDual|explicitLegacyV1|buildLegacyEBrainTurn|startLegacySession|bootstrapLegacy|handleLegacyEntryIntent|reopenLegacySession|refreshLegacyCurrentBrain' \
  "$ROOT/BehavioralAISubstrate/Sources" "$ROOT/QinaoRuntimeSDK/Sources" \
  "$ROOT/SampleHost" --glob '*.swift'
! rg -n 'buildSovereignExecutionReceipts|status:[[:space:]]*\.executed' \
  "$ROOT/BehavioralAISubstrate/Sources/BASHostKit"
if rg -n 'toolDispatcher\.(dispatch|dispatchBatch)|dispatcher\.(dispatch|dispatchBatch)|\.dispatchBatch\(invocations:' \
  "$ROOT/BehavioralAISubstrate/Sources" -g '*.swift' \
  | rg -v 'BASToolEffectAdapter.swift|BASToolDispatcher.swift'; then
  exit 1
fi
! rg -n 'ToolExecutor|toolExecutor|consumedBundles|tokenAlreadyConsumed' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift"
rg -q 'QinaoEffectExecuting' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
! rg -n 'toolExecutor:' \
  "$ROOT/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests" --glob '*.swift'
(
  cd "$ROOT/SampleHost"
  xcodebuild build \
    -scheme SampleHost \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO
)
```

Expected: owner ledger, shell syntax, inventory, negative route/effect scans, focused and complete BehavioralAISubstrate suites PASS with 0 failures; the complete QinaoRuntimeSDK suite PASS with 0 failures; SampleHost builds for a generic iOS Simulator destination. One typed operation root owns the policy-bounded ordered Provider branch chain; every claimed branch has exactly one physical execution, exactly one pinned terminal source feeds one spool/final, and both visibility modes replay. None of these local/simulator gates counts as E4 or authorizes promotion.

- [ ] **Step 8: Stage only the cutover candidate and materialize its exact Git tree**

Require two physical-device UDIDs and a fresh evidence directory outside the repository. Stage every Task 7 code/test/script/inventory file except the post-promotion status document; do not use `git add -A`.

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
: "${BAS_DEVICE_A_UDID:?set the first physical-device UDID}"
: "${BAS_DEVICE_B_UDID:?set the second physical-device UDID}"
: "${BAS_DEVICE_A_CONDITIONS:?set the first device conditions JSON path}"
: "${BAS_DEVICE_B_CONDITIONS:?set the second device conditions JSON path}"
test "$BAS_DEVICE_A_UDID" != "$BAS_DEVICE_B_UDID"
test -s "$BAS_DEVICE_A_CONDITIONS"
test -s "$BAS_DEVICE_B_CONDITIONS"
git -C "$ROOT" diff --cached --quiet

DIRECT_COORDINATOR_TEST_FILES=(
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBiomimeticAutoCheckpointTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBiomimeticCheckpointReplayTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter1039DeliberationLoopTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter1042EvidenceResolutionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter946FourteenLayerFuzzSmokeTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952ExtremeFuzzTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952_4HighBarBenchmarkTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter473CleanupTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChenglu20MinStressTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluComprehensiveOptInIntegrationTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluFullChainE2ETests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluHostRuntimeBuilderTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluSweepInterpreterTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitConstitutionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitRunModeLaneTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostRuntimeMeshHookTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostRuntimeMeshSweepTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryClosedLoopApplierHostRuntimeIntegrationTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNeuralHeadShadowRecorderTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSSMCautionOperatorRunTurnTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticAdjudicatingStreamingTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSignal10EmpiricalDiagnosisTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSleepConsolidationDriverTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignLedgerHostSinkTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSubstrateReauditShadowEvaluatorTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineBiomimeticHookTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineHostInjectionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineLedgerLocalityTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEnginePhaseFTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineTurnSerializationTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeNativeV2DispatchTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M299FrontierSummaryConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M300TribunalCoverageConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M303AbyssalPressureConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M304HumanAnchorAndSealConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M305EvolutionLifecycleConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M306MultiSessionContinuityTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M316NarrativeDistortionConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M317AnomalyTraceConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M318AbyssalBranchConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M320UnknownReserveConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M321ForbiddenKnowledgeConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M336SovereignTokenIDDeterminismTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M402KunlunAxisAuditTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M404M405KunlunJadeRiverAuditTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M408M409M410KunlunYaochiTianmenAuditTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M418EscalationSuppressionAuditEmissionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M436LayerReconciliationConsumptionTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M448CthulhuLayerProductionWiringTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M457ForbiddenZoneGateLifecycleIntegrationTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M480KunlunProductionWiringTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M486KunlunDreamLoopWiringTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M491KunlunIntegrityCthulhuLeftoverWiringTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M500KunlunL4LeftoverSurfaceAliasWiringTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M541SubstrateValueAddTests.swift
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/M603FourteenLayerSmokeTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/M359FullStackBenchTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostCthulhuEndToEndDemoTests.swift
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostKunlunEndToEndDemoTests.swift
)

git -C "$ROOT" add \
  BehavioralAISubstrate/Package.swift \
  BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry.swift \
  BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineSQLLoader.swift \
  BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry+AllLiterals.swift \
  BehavioralAISubstrate/Sources/BASHistoryAudit/BASChapterDoctrineRegistry+Literals.swift \
  BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/010_chapter_doctrine_records_schema.sql \
  BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/011_chapter_doctrine_literals_data.sql \
  BehavioralAISubstrate/Sources/BASHistoryAudit/SQL/012_chapter_doctrine_phase2_data.sql \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEntropyChapterIndex.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapterDoctrineRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapterDoctrineLoaderDegradeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRegistryFrozenHashTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAllLiteralsByteMirrorTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHistoryAuditProductBoundaryTests.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeMode.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift \
  BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Construction.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASSubstrateReauditShadowEvaluator.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift \
  BehavioralAISubstrate/Sources/BASAppleEdgeWiring/BASChengluHostRuntimeBuilder+CoreML.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASSSMCautionProbe.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeEngineConfigurationPhaseFTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnRuntimeModeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter668RuntimeModeToggleProofTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSampleHostRuntimeModeEnvVarBridgeTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEnvVarBridgeDoctrineTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExtensionPointInventoryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPhaseLPostFlipV1PathCallabilityProofTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainProbabilityDistributionTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainFacadeIntegrationTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASShadowTrialCarrierLoopTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAuthoritativeEntrypointTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNativeStageCapabilityTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignEffectReceiptTruthTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationCutoverTests.swift \
  BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh \
  BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv \
  SampleHost/SampleHostAFMBenchEntry.swift \
  SampleHost/SampleHostBASHostInvocation.swift \
  SampleHost/SampleHostBenchPanel.swift \
  SampleHost/SampleHostBenchPostLLMObserver.swift \
  SampleHost/SampleHostChengluStressRunner.swift \
  SampleHost/SampleHostHybridBenchEntry.swift \
  SampleHost/SampleHostLegacyBenchEntry.swift \
  SampleHost/SampleHostModel.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/CthulhuEndToEndDemo.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/FullStackBench.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/KunlunEndToEndDemo.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/MultiSessionContinuity.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostDemoExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostDoctrineBenchExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLoRAExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLongSmokeBenchExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift \
  "${DIRECT_COORDINATOR_TEST_FILES[@]}"
git -C "$ROOT" add -u -- \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineSQLLoader.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+Literals.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/010_chapter_doctrine_records_schema.sql \
  BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/011_chapter_doctrine_literals_data.sql \
  BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/012_chapter_doctrine_phase2_data.sql \
  BehavioralAISubstrate/Sources/BASHostKit/BASSampleHostRuntimeModeEnvVarBridge.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEnvVarBridgeDoctrine.swift

while IFS= read -r candidate_path; do
  git -C "$ROOT" diff --quiet -- "$candidate_path"
done < <(git -C "$ROOT" diff --cached --name-only)
CANDIDATE_TREE="$(git -C "$ROOT" write-tree)"
CANDIDATE_COMMIT="$(
  printf '%s\n' 'certification-only semantic DAG candidate' |
    git -C "$ROOT" commit-tree "$CANDIDATE_TREE" -p HEAD
)"
CANDIDATE_ROOT="$(mktemp -d)/candidate"
git -C "$ROOT" worktree add --detach "$CANDIDATE_ROOT" "$CANDIDATE_COMMIT"
test "$(git -C "$CANDIDATE_ROOT" rev-parse HEAD^{tree})" = "$CANDIDATE_TREE"
test -z "$(git -C "$CANDIDATE_ROOT" status --porcelain)"
```

Expected: the original worktree has no unstaged Task 7 edits; `CANDIDATE_TREE` is the index tree; the detached certification worktree is clean and has that exact tree. The temporary commit is a materialization mechanism, not promotion.

- [ ] **Step 9: Run all gates and the complete two-device 40/30 protocol inside that tree**

Run from the materialized tree. Keep build scratch and evidence outside it so the source tree remains clean.

```bash
CERT_PARENT="$(mktemp -d)"
CERT_OUTPUT="$CERT_PARENT/apple-silicon-cert"
SCRATCH_ROOT="$CERT_PARENT/scratch"
mkdir "$SCRATCH_ROOT"

python3 "$CANDIDATE_ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$CANDIDATE_ROOT" \
  --ledger "$CANDIDATE_ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
bash -n "$CANDIDATE_ROOT/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh"
bash -n "$CANDIDATE_ROOT/BehavioralAISubstrate/scripts/run-architecture-cert.sh"
bash -n "$CANDIDATE_ROOT/BehavioralAISubstrate/scripts/run-device-app-cert.sh"
bash -n "$CANDIDATE_ROOT/BehavioralAISubstrate/scripts/run-endurance-watchdog.sh"
bash "$CANDIDATE_ROOT/BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh" \
  --root "$CANDIDATE_ROOT" \
  --inventory "$CANDIDATE_ROOT/BehavioralAISubstrate/Docs/AUTHORITATIVE_ENTRYPOINT_MIGRATION.tsv"
swift test --package-path "$CANDIDATE_ROOT/BehavioralAISubstrate" \
  --scratch-path "$SCRATCH_ROOT/bas-focused" \
  --filter 'BASAuthoritativeEntrypointTests|BASTurnOperationCutoverTests|BASNativeStageCapabilityTests|BASSovereignEffectReceiptTruthTests|BASProviderExecutionSpoolTests|BASSemanticTurnDAGTests|BASSemanticDAGShadowParityTests|BASSingleAuthoritativeResultTests|BASArchitectureReplayManifestTests|BASPrePublicationManifestBarrierTests|BASAuthoritativeSemanticRuntimeTests|BASAppleSiliconCertificationTests'
swift test --package-path "$CANDIDATE_ROOT/BehavioralAISubstrate" \
  --scratch-path "$SCRATCH_ROOT/bas-full-a"
swift test --package-path "$CANDIDATE_ROOT/BehavioralAISubstrate" \
  --scratch-path "$SCRATCH_ROOT/bas-full-b"
swift test --package-path "$CANDIDATE_ROOT/BehavioralAISubstrate" \
  --scratch-path "$SCRATCH_ROOT/bas-full-c"
swift test --package-path "$CANDIDATE_ROOT/QinaoRuntimeSDK" \
  --scratch-path "$SCRATCH_ROOT/qinao"
! rg -n 'ToolExecutor|toolExecutor|consumedBundles|tokenAlreadyConsumed' \
  "$CANDIDATE_ROOT/QinaoRuntimeSDK/Sources" --glob '*.swift'
rg -q 'QinaoEffectExecuting' \
  "$CANDIDATE_ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift" \
  "$CANDIDATE_ROOT/QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoEffectExecuting.swift"
! rg -n 'toolExecutor:' \
  "$CANDIDATE_ROOT/QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests" --glob '*.swift'
(
  cd "$CANDIDATE_ROOT/SampleHost"
  xcodebuild build \
    -scheme SampleHost \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$SCRATCH_ROOT/sample-host-derived-data" \
    CODE_SIGNING_ALLOWED=NO
)
(
  cd "$CANDIDATE_ROOT"
  BAS_DEVICE_A_UDID="$BAS_DEVICE_A_UDID" \
  BAS_DEVICE_B_UDID="$BAS_DEVICE_B_UDID" \
  BAS_DEVICE_A_CONDITIONS="$BAS_DEVICE_A_CONDITIONS" \
  BAS_DEVICE_B_CONDITIONS="$BAS_DEVICE_B_CONDITIONS" \
  BAS_CANDIDATE_TREE_ID="$CANDIDATE_TREE" \
    bash BehavioralAISubstrate/scripts/run-architecture-cert.sh \
      --mode device \
      --device-a "$BAS_DEVICE_A_UDID" \
      --device-b "$BAS_DEVICE_B_UDID" \
      --device-a-conditions "$BAS_DEVICE_A_CONDITIONS" \
      --device-b-conditions "$BAS_DEVICE_B_CONDITIONS" \
      --candidate-tree "$CANDIDATE_TREE" \
      --output "$CERT_OUTPUT" \
      --claim cold40 \
      --claim sustained30
)
swift run --package-path "$CANDIDATE_ROOT/BehavioralAISubstrate" \
  --scratch-path "$SCRATCH_ROOT/verifier" \
  BASArchitectureCertVerifier require-promotion \
  --verdict "$CERT_OUTPUT/promotion-verdict.json" \
  --expected-tree "$CANDIDATE_TREE" \
  --expected-owner-ledger-digest "$(shasum -a 256 "$CANDIDATE_ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" | awk '{print $1}')" \
  --expected-owner-verifier-digest "$(shasum -a 256 "$CANDIDATE_ROOT/scripts/check_qinao_owner_ledger.py" | awk '{print $1}')"
test "$(git -C "$CANDIDATE_ROOT" rev-parse HEAD^{tree})" = "$CANDIDATE_TREE"
test -z "$(git -C "$CANDIDATE_ROOT" status --porcelain)"
```

Expected: owner-ledger/scanner gates, focused suite, three complete BehavioralAISubstrate runs, complete QinaoRuntimeSDK suite, and SampleHost build all PASS. Each physical device independently completes the exact 100-turn cold-40 cohort and exact uninterrupted 1800-second sustained-30 cohort from Task 6. The verdict is `.promote`, is E4 for the exact candidate tree/runtime/owner-ledger/controller/verifier/toolchain/device identities, and `require-promotion` exits 0. MetricKit may be attached only as delayed E5 and cannot repair a failed/missing E4 field.

If any command, turn, receipt, identity comparison, threshold, or final cleanliness check fails, stop. Preserve the deny evidence, remove the detached worktree, leave the production index uncommitted, and do not change the default or publish a convergence status claiming success.

- [ ] **Step 10: Promote the exact certified tree and prove no byte changed**

Return to the original worktree and verify its index still materializes the certified tree, its worktree has no unstaged change, and its parent has not moved. Then make the one final production cutover commit:

```bash
test "$(git -C "$ROOT" write-tree)" = "$CANDIDATE_TREE"
while IFS= read -r candidate_path; do
  git -C "$ROOT" diff --quiet -- "$candidate_path"
done < <(git -C "$ROOT" diff --cached --name-only)
test "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$CANDIDATE_ROOT" rev-parse HEAD^)"
git -C "$ROOT" commit -m "feat: promote certified semantic dag runtime"
test "$(git -C "$ROOT" rev-parse HEAD^{tree})" = "$CANDIDATE_TREE"
git -C "$ROOT" worktree remove "$CANDIDATE_ROOT"
```

Expected: the promoted commit's tree ID equals the E4-certified `CANDIDATE_TREE` exactly. This commit is the only default/cutover commit. The certified shipping graph contains no `.nativeV2`, V1, native-Any, mode-environment, or legacy HostKit API route; old coordinator behavior is reachable only by direct test-target fixtures, never through runtime/host/Qinao products.

After promotion succeeds, create `APPLE_SILICON_14L_CONVERGENCE_STATUS.md` as a factual, doc-only record containing the promoted commit ID/tree ID, runtime executable SHA-256, controller/verifier digests, both device/OS identifiers, cold-40 and sustained-30 verdict IDs, Artifact Mesh evidence IDs, E4 grade, E5 status, protocol timestamps, scanner inventory digest, and the explicit legacy rollback command. Every field is copied from the signed/bounded verdict or Git; do not use a pending, unknown, or inferred value.

- [ ] **Step 11: Validate and commit the post-promotion status document separately**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
STATUS="$ROOT/BehavioralAISubstrate/Docs/APPLE_SILICON_14L_CONVERGENCE_STATUS.md"
test -s "$STATUS"
rg -n "$(git -C "$ROOT" rev-parse HEAD)|$(git -C "$ROOT" rev-parse HEAD^{tree})" "$STATUS"
if rg -ni 'placeholder|not[- ]final|awaiting evidence|pending|unknown|inferred' "$STATUS"; then
  exit 1
fi
git -C "$ROOT" add BehavioralAISubstrate/Docs/APPLE_SILICON_14L_CONVERGENCE_STATUS.md
git -C "$ROOT" diff --cached --check
git -C "$ROOT" commit -m "docs: record certified 14-layer convergence"
```

Expected: the status file contains the promoted commit/tree identities, contains no placeholder state, and the doc-only commit does not alter the already certified production tree's files. The status commit's tree necessarily differs by that one document; the production cutover commit immediately before it remains the exact certified tree.

---

## Completion Gate

Do not call this plan complete until every item below is proven:

- [ ] Immutable receipts prove W0 → W1 → W2 → W3 → W4 → W5 → W6 in that order. Task 5 Steps 5A–5B are a dedicated W5 commit containing no W6 runtime/replay file, and no W6 change or certification run predates its passing effect gate.
- [ ] Task W0 has recorded baseline violation JSON/failing tests; all seven implementation tasks have RED evidence, GREEN implementation, exact verification output, and the named commits. Task 7 turns W0 fully green, and its promotion commit exists only after the E4 verdict.
- [ ] `scripts/check_qinao_owner_ledger.py` passes against `docs/superpowers/specs/qinao-owner-ledger-v1.json` before implementation close, in the detached candidate tree, and after both device cohorts. The verdict binds the exact ledger artifact/digest, verifier digest, passing JSON artifact, and complete owner-key vector.
- [ ] Exactly three production M files were created: `BASSemanticTurnDAG.swift`, `BASArchitectureReplayManifest.swift`, and `BASAppleSiliconCertification.swift`; each has the eight-part Create Proof above.
- [ ] `BASArchitectureCertVerifier/main.swift` is the one thin A executable adapter. New tests, the two shell adapters, the replay schema, migration inventory, and final status document own no runtime authority.
- [ ] Owner `history.doctrine-metadata` is relocated byte-for-byte into the explicit nonshipping `BASHistoryAudit` target/product. Audit consumers and the separate entropy index preserve behavior, while certified Release target graphs, link maps/symbol tables, bundles, and archives contain neither the registry/loader nor doctrine SQL `010`/`011`/`012`; no duplicate/forwarding owner or silent deletion exists.
- [ ] There is one lifecycle/traversal owner (`BASTurnRuntimeEngine.TurnOperation`), one frozen 18-stage compatibility projection, one typed semantic executor, one existing parallel executor, and one existing stage ledger. Native-`Any` entrypoints are shadow-only and authoritative requests fail with `capabilityDenied(.nativeAnyShadowOnly)` before invocation. No `BASNativeSemanticDAGRunner`, second scheduler, second ledger, or result-producing coordinator exists.
- [ ] Every operation has one canonical `BASTurnOperationRef`, one installed `BASProviderBranchPolicy`, one Silicon binding referencing it, and a bounded ordered K3 Provider branch chain. Every newly won branch claim invokes exactly one physical Provider call; a claimed/possible-start branch is never retried/replaced by a fresh ordinal. Exactly one pinned terminal source stores one post-terminal-seal/pre-publication exact-byte spool and publishes one finalization; buffered L10/visibility consumes that stored spool, incremental mode terminal-verifies it after the one pre-call gate, and no sibling/later candidate regenerates the answer.
- [ ] Every Provider branch carries exact ordered load/prefill/cache/decode actuation receipts matching its stored `BASExecutionPlan` and binding `stepRuleID`; missing/advisory/local re-election or policy mismatch denies publication.
- [ ] LayerCell execution uses prerequisite `BASLayerCell` values and their stored `BASLayerActorMechanismAdapter` through one injected closure; no second LayerCell protocol/router/adapter exists, and parity plus all four replay modes extend `BASEBrainTurnResultReplayHarness`.
- [ ] `BASEBrainTurnResult` is the only public turn result. One Artifact Mesh payload wraps/projects it once and has no self ID, digest, or signature.
- [ ] The replay manifest is one ordinary Artifact Mesh payload. SQLite stores only its rebuildable source-event-to-artifact-ID index; existing `BASEventLog`/`BASSQLiteEventLogStorage` integrity remains source truth.
- [ ] Each publishable manifest/result carries the same typed root and sovereign four-ID release reference; neither copies Provider lineage. Spool binds the source and immutable terminal-prefix chain Artifact ID; release preparation/final publication bind that spool plus the immutable through-visibility chain Artifact ID/receipt/evidence. Barrier/replay reopen both payloads, exact-compare the ordered-entry prefix relation, validate K3 event/coverage heads separately, reject prefix-only final evidence, and copy no policy/watermark fields.
- [ ] Both `BASProviderVisibilityMode` paths are replay-certified. Incremental mode proves pre-call/incremental verification evidence and zero post-gate branches; buffered mode proves hidden terminal completion, only policy-preauthorized source-causal verifier proposals, L10 acceptance, then gate open and zero post-gate branches. Failed/indeterminate pinned source has no sibling replacement.
- [ ] Runtime proves manifest put, reopen, source-index resolution, and barrier before calling the sovereign-owned publication coordinator. Runtime owns no reservation, finalization, retry, recovery journal, or second sink.
- [ ] Runtime/LLM tool output remains proposal-only until exact permit and durable Zone-C broker dispatch. Only `BASToolEffectAdapter` may package-call `BASToolDispatcher`, only the broker can author an execution receipt, HostKit contains no synthetic `.executed` constructor, and replay invokes neither broker nor dispatcher.
- [ ] The same injected ledger and twice-resolved per-turn context cover L10 verifier/spool, manifest Artifact I/O, the outer unchanged `publishExact` plus recovery/final lookup, and replay; each phase has the exact root/phase/category above, no allocation is double counted, and throw/cancellation/context drift leaves no reservation.
- [ ] Publication memory denial occurs before manifest resolution, journal reserve, K4 claim, sink lookup/release, mark, or finalization; replay uses a current verified context rather than the historical expired context.
- [ ] Deterministic semantic replay, exact neural replay, behavioral re-evaluation, and effect simulation all reopen the same manifest/result artifacts; effect simulation never dispatches an external effect.
- [ ] E0–E5 certification aggregates current scripts, device runners, probes, signposts, and `BASFieldMetricsCollector`. MetricKit contributes E5 only and is structurally incapable of satisfying E4.
- [ ] Cold 40 has two distinct devices with exactly 100 preregistered turns each and per-device accepted-decode p10 `>= 40.0`. Sustained 30 has two distinct uninterrupted 1800-second cohorts and per-device last-quarter accepted-decode p10 `>= 30.0`, with no memory slope or hidden quality reduction.
- [ ] The verifier binds candidate tree, runtime executable, owner-ledger/verifier/pass artifact, controller, verifier, toolchain/profile, and physical-device identities. Missing, duplicate, malformed, mismatched, interrupted, excluded, or sub-threshold evidence denies promotion.
- [ ] Production entrypoints are async, dependency-injected, and authoritative. V1/native-V2/native-Any/mode-environment and `Legacy` host surfaces are absent from production sources/products; rollback deploys the preceding certified tree. No catch, nil dependency, environment override, generic wrapper, or test fixture can select a second production result path.
- [ ] The HostKit production builder and Qinao production factory obtain the identical `BASProcessMemoryLedger.processShared` actor; the builder constructs one generic gateway and injects the same actor/resolver through provider execution, semantic retrieval, LayerCell/L10, manifest, publication, and replay. Apple-edge code names none of those memory types, Qinao constructs no ledger/HeavySeat, and no downstream production file stores a raw cap.
- [ ] The promoted production commit's `HEAD^{tree}` exactly equals the tree materialized and certified on both devices. A failed gate leaves the candidate uncommitted and the old production default untouched.
- [ ] All Swift snippets parse after insertion, every shell script passes `bash -n`, all focused and complete suites named above pass, the generic iOS SampleHost build passes, and the final repository diff passes `git diff --check`.
