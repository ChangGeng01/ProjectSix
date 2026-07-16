# iPhone Air Silicon Execution Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Converge the iPhone Air path on one model/invocation identity chain, one `TurnOperation` root, one bounded K3-declared causal chain of typed Provider-egress branches with exactly one physical call per branch, one pinned terminal-answer source, executable `BASExecutionPlan` actuation for every branch, one response spool/finalization, one versioned capability snapshot, and one process-wide ordinary/heavy memory owner. Streaming and eager are two views over the same pinned terminal source—not two generations.

**Architecture:** `BASTurnRuntimeEngine.TurnOperation` is the lifecycle owner for the whole admitted task/turn. It consumes one Contracts Task 2A `BASTurnOperationRef` and keeps that root across a causally ordered, bounded series of K3-allocated `providerEgress[requestOrdinal]` branches. Each branch has an explicit signed `purpose` (`groundingProposal`, `turnStep`, or `verifierProposal`) and separate `outputRole` (`internalProposal` or `terminalAnswerCandidate`); each branch receives one complete non-authoritative `BASProviderExecutionRef = (turnOperationRef, providerEgressBranchRef, attemptRef, leaseID, providerExecutionID, acceptanceGeneration, requestSequence)`, one durable K3/Attempt claim, and exactly one physical Provider call. Intermediate outputs are proposal-only. Contracts Task 2A's declared `BASProviderBranchPolicy` is the sole W1/W2 owner of step rules, roles, causal edges, branch/instance limits, terminal-pin permissions, and `BASProviderVisibilityMode`; W4 atomically installs one policy artifact with its matching execution binding. `BASSiliconExecutionBinding` remains the one W4 execution-binding root and contains only the policy Artifact ID plus a canonical `stepRuleID → model/profile/plan-template/budget` mapping; identity, ABI, bundle, fallback, purpose, role, causal, ordinal, limit, and visibility facts are reopened through those referenced artifacts rather than copied into the binding. K3 instantiates an exact policy rule/ordinal/causal predecessor under that root rather than creating a binding list or a second router. Task 7's explicit W1 value-contract slice extends the one canonical `BASOrganDescriptor` exactly once with required `BASProviderContainmentClass`, migrates every constructor explicitly, and freezes that final embedded shape in same-file first-governed `BASPersistedOrganDescriptorPayload` 1.0.0. Task 3 W4 only consumes those bytes and, after value-only preflight selects one route, ordinary-puts that parent; only its returned ID becomes `selectedProviderDescriptorArtifactID`. K3 treats its bytes as opaque but persists that exact ID in the allocation row and allocation/claim receipts; the existing lineage reaches it through the allocation receipt. `BASProviderAttemptExecutor.executeExactlyOnce` is only the thin invocation adapter over the per-branch durable claim and receipt-bound governed descriptor parent. `BASOrganRegistry` is an identity store (`providerID → descriptor/adapter`) and performs no ranking, fallback, descriptor persistence, or route authority. Each instantiated `BASExecutionPlan` owns its signed phase plan and the Provider adapter returns phase receipts proving that its elected load, prefill, cache, and decode axes were actuated. Only the K3-pinned terminal-answer-source egress may feed the root's unique ordinal-zero `provisionalStream` and `finalPublication` branches. After the pinned terminal bytes are structurally verified and terminal-prefix-sealed, W5 ordinary-puts one non-publishable, self-ID-free `BASResponseSpoolPayload`; buffered L10/visibility then verifies that exact stored payload, while incremental mode terminal-verifies the same payload after its pre-call visibility gate. The returned `spoolArtifactID` never exists before that put and is bound once to the pinned source/final-publication branch. `BASModelManifestRegistry.productionDefault` remains Qwen 3.5 4B for user-facing `turnStep` model work; grounder/verifier steps may use only signed auxiliary profiles declared in the same binding root. Concrete Qwen/MLX, Core AI, and Foundation Models implementations remain in `BASMLXAdapter`/`BASAppleAdapters` or host composition—never in Qinao SDK. `BASProcessMemoryLedger.processShared` is also the HeavySeat authority: its `heavy-active` projection is the one seat, not a parallel seat manager.

**Tech Stack:** Swift 6, SwiftPM, Crypto/CryptoKit, XCTest, Python/pytest for StateLake assets, vendored MLX Swift 0.31.1, Core ML/Core AI conditional APIs, Metal/C++, Artifact Mesh contracts from the preceding plan, and physical iOS 27 device tests.

## Mandatory Master Wave Order

Task numbers below are reference and commit units; they are not permission to execute sections in document order. Every worker must follow this master sequence, preserve the prior wave's receipt, and rerun the owner-ledger verifier at each boundary. No wave may start while an earlier wave is red.

| Wave | Master scope | Work and hard gate in this plan |
|---|---|---|
| W0 | owner/write freeze | Run Task W0, freeze the owner/create ledger and baseline violation artifact, and make the write boundary enforceable before any production edit. |
| W1 | contracts / `TurnOperation` / Provider inversion | Complete Task 1 and Task 7's explicit Step 0 value-contract slice plus the contract/boundary portions of Steps 1, 2, 4, 5, 7, and 7A: freeze required descriptor containment and first-governed parent before any consumer, one operation root, the shared K3 Provider-branch control port, identity-only registry, preflight-only routing, exactly-once physical invocation per claimed egress branch, one model-manifest default, one terminal-source pin, and no concrete model implementation in Qinao. Commit the W1 receipt before W2; do not start silicon tuning here. |
| W2 | K3 + memory + erasure | Consume the sovereign K3/erasure prerequisite receipt only; this plan makes no production edit and does not create the process MemoryLedger in W2. |
| W3 | StateLake / context | Consume the semantic W3 receipt for pure snapshot-bound retrieval/context contracts, deterministic rebuild/replay, and test-injected lane execution. This plan makes no production edit and does not create StateABI in W3. |
| W4 | silicon | First complete Task 2 (`BASStateABI`) and Task 5 (`BASProcessMemoryLedger`), then complete Tasks 3, 4, and 6 plus Task 7 Step 4's K3 production wiring, Step 5B, and Steps 3, 6, 8, and 9. This is the sole wave that creates those two silicon M owners, wires the W2-implemented `BASProviderBranchControlPort` plus production memory admission, actuates each branch's frozen `BASExecutionPlan` as load → prefill → cache → decode, and collects device evidence; it may not revise W1–W3 authority or create a response spool. |
| W5 | K4 / release / Zone C | Consume the sovereign release plan's passing K4, release, and durable Zone-C effect receipts, then execute only Task 7 Step 5C and Step 10's spool/release handoff. No response publication/effect integration and no W6 work may proceed without this gate. |
| W6 | runtime / certification | Execute only the companion runtime/replay/certification plan after W5 is green; this document cannot self-authorize W6. |

Task 7 is deliberately split across W1, W4, and W5: its named W1 steps establish contracts and Provider inversion and Step 7A commits that receipt; its named W4 steps actuate and certify the already-frozen plan in a later commit; Step 5C/Step 10 consume the sovereign release receipt and close spool/L10/visibility in a third commit. Physical placement later in this document does not permit W4 work before W2/W3, W5 work before its sovereign receipt, or a mixed-wave commit.

## Global Constraints

- The Contracts and LayerCell plan is a prerequisite: BASArtifactID, ordinary Artifact Mesh put/read receipts, and attestation references must already compile and pass.
- iOS 27 is the deployment floor for every workspace-owned iOS package slice, app, and extension target.
- Every self-ID-free payload independently ordinary-put through Artifact Mesh must conform to `BASSchemaVersioned`, visibly store `schemaVersion`, and expose an explicit public initializer whose first parameter is `schemaVersion: String = Self.currentSchemaVersion`. Every payload byte used for ordinary put, Artifact identity, or reopen must pass through the Contracts-owned `BASGovernedArtifactPayloadCodec`; raw `JSONEncoder`/`JSONDecoder`, alternate canonical encoders, caller-selected accepted-version sets, and field access before version rejection are forbidden. Each such payload has exactly one `BASEBrainSchemaGovernanceRegistry` entry plus exact current round-trip, pinned backward-version, missing/future-version rejection, and cross-target default-version initializer fixtures. A historical version is readable only through an explicit typed migration inside that one codec; authoritative actuation still requires the exact current version after migration and full-field validation.
- R/E/A/M is mandatory: reuse an owner, extend it in place, or add one boundary adapter before considering a missing owner.
- BASModelCapabilityManifest/BASModelManifestRegistry are the only model/QualityIdentity owners. BASLLMInvocationContract is the only per-turn NeuralExecutionContract owner. Do not create BASQualityIdentity.swift, BASNeuralExecutionContract.swift, or another model/profile registry.
- The turn owns exactly one `BASSiliconExecutionBinding` root. Freeze it after the capability snapshot and `BASStateRequirementPlan` exist but before R5. Its payload contains **only** one `providerBranchPolicyArtifactID` and a canonical `stepRuleID → model/profile/plan-template/budget` mapping—never top-level identity/NeuralExecution/StateABI/bundle/profile/fallback fields, copied purpose/role/causal/ordinal/limit/visibility policy, a future grounding proposal, compiled context, branch, Provider execution, spool, or receipt. Contracts W1 declares the sole `BASProviderBranchPolicy` value contract; K3 W2 implements the port and fails closed while no policy is attached, without depending on Silicon types; W4 stores, jointly validates, and atomically installs one policy artifact plus this binding before any production branch. The policy remains sole authority for branch facts. Model/profile/plan-template readers reopen and validate their own QualityIdentity, NeuralExecution, StateABI, bundle, and fallback children; none is projected back into the binding. The per-turn capability-snapshot Artifact ID remains separately equality-checked with its child attestation. Caller-supplied binding lists, quality/profile/ABI/fallback digest lists, and phantom admission-context IDs are forbidden.
- Materialize one ordinary Artifact-Mesh `BASExecutionPlan` artifact per K3 Provider branch only when that step's causal inputs exist, proving it is an allowed instantiation of the single binding root. The R5 grounding plan binds the exact reservoir/snapshot/requirement-plan artifacts; the terminal decode plan cannot exist until R6 finishes and the sole `BASContextCompiler` has produced the compiled-context descriptor. After preflight selects one route and before allocation, ordinary-put `BASPersistedOrganDescriptorPayload(descriptor: selectedDescriptor)` through the governed codec; `BASProviderBranchAllocationRequest` carries that exact plan artifact ID, binding-root proof, and returned governed-parent `selectedProviderDescriptorArtifactID`. K3 stores that ID opaquely in its allocation row and echoes it unchanged in allocation/claim receipts; neither K3 nor an adapter accepts a future plan/descriptor ID, a caller-loose Provider ID, or locally re-elects a route/profile. The embedded `BASOrganDescriptor` is never independently put or registered.
- `BASExecutionPlanElector`, `BASDecodeLanePolicy`, `BASDecodeStrategy`, `MLXOrganAdapter+Executor`, prompt lookup, MTP, acceptance/hysteresis, trunk checkpoints, session pools, FIFO gates, and stream pumps remain subordinate mechanisms. They may not re-elect a plan, provider, fallback, `planID`, or execution mode after `TurnOperation` is frozen.
- One `TurnOperation` may own multiple Provider calls only as distinct K3-allocated `.providerEgress` branches under the same root. Ordinals are strictly increasing, never reused, and allocated by the existing K3/Attempt head only after the signed step DAG permits the exact `purpose` (`groundingProposal`, `turnStep`, or `verifierProposal`), `outputRole` (`internalProposal` or `terminalAnswerCandidate`), and durable causal predecessor receipt. Purpose and output role are separate fields; neither can be inferred from Provider/model identity. Each branch permits exactly one physical call; a second call on the same branch, an adapter-selected ordinal, an undeclared purpose/output role, or a branch without its causal receipt is forbidden.
- A tool/effect result that requires another model iteration stays under the same `BASTurnOperationRef`: K3 verifies the durable effect receipt and prior egress terminal, then CAS-allocates the next non-reused egress ordinal as `.turnStep` and binds that receipt as its causal predecessor. The tool callback/runtime cannot resume an old Provider execution, choose the ordinal, or call a Provider before the CAS.
- Grounding and verification model outputs use `.groundingProposal/.internalProposal` and `.verifierProposal/.internalProposal`. They may feed deterministic validation/gates and a later causally authorized egress, but cannot write the terminal spool, stream publicly, publish, commit state, or become `BASEBrainTurnResult` directly.
- Before invoking the one `.turnStep/.terminalAnswerCandidate` selected to source the answer, K3 compare-and-sets the unique `terminalSourceBranch` from absent to that exact egress branch. After the pin, no new `.turnStep` or `.terminalAnswerCandidate` branch may be allocated; only verifier branches already pre-authorized by the installed `BASProviderBranchPolicy` and causally bound to that exact source may run as internal proposals. Once the UI-visibility gate opens, no new Provider branch of any purpose may start. Only the pinned source can feed `.provisionalStream/0`, L10 verification, terminal spool, or `.finalPublication/0`; if it fails or becomes indeterminate, a sibling branch cannot replace it and the turn fails/reconciles.
- Streaming and eager observe the same designated terminal-answer Provider execution with the same `turnOperationRef`, exact terminal `providerEgressBranchRef`, `providerExecutionRef`, `planID`, provider ID, binding ID, decode strategy, fallback graph, lease, and spool. Provisional UI events use only the unique ordinal-zero `.provisionalStream` branch; the canonical terminal/release input uses only the distinct unique ordinal-zero `.finalPublication` branch. No stream completion path may call `draft`, `produceBody`, `generateCandidates`, or another decode to construct the canonical result.
- A raw `operationID`, `turnID`, `branchID`, stream ID, or publication ID is compatibility data only. It must be produced and decoded by the Contracts Task 2A bounded legacy codec, equality-check to the exact `BASTurnOperationRef`/`BASTurnBranchRef`, and never enter routing, Provider claim, spool deduplication, publication idempotency, retry, or result authority. No adapter may mint authority from a free UUID or `String`.
- `BASProviderExecutionRef` is a complete value, never a partial correlation ID: `turnOperationRef`, exact `providerEgressBranchRef`, exact active Attempt ref, exact lease Artifact ID, Qinao-minted Provider-execution ID, acceptance generation, and per-call message sequence. Its root must equal `providerEgressBranchRef.turnOperationRef`; branch kind must be `.providerEgress` and its non-reused ordinal is the K3-allocated request ordinal. The Provider may only echo the complete ref; every request, phase, chunk, checkpoint, proposal, and terminal event is rejected on any Attempt/lease/generation/execution/root/branch/purpose/output-role mismatch.
- Exactly-once Provider execution is a per-egress K3/Attempt CAS invariant, not an actor-task convention. Before each possible physical start, the current K3 owner atomically claims `(turnOperationRef, providerEgressBranchRef, stepRuleID, providerStepPurpose, causalPredecessorReceiptArtifactID, providerExecutionRef-with-sequence-zero)` against the active Attempt/generation/lease, installed `BASProviderBranchPolicy`, and matching execution-binding template. Reconstructed handles for that branch may only join, query, or reconcile its claim. **All** Provider capability/Pareto/fallback selection finishes during value-only preflight before `allocateProviderBranch`; allocation freezes route, plan, ordinal, causes, and the complete sequence-zero `BASProviderExecutionRef`. An allocated-but-unclaimed branch may only be reopened and claimed as that same branch—it cannot be abandoned, skipped, or exchanged for another route/ordinal. Once a branch is durably claimed/`possibleStarted`, crash, cancellation, zero-byte terminal failure, refusal, or lost reply can never authorize a fresh ordinal as retry/replacement/fallback. Recovery may exact-query/finalize that same branch or begin a new Attempt; a later branch is legal only as policy-authorized semantic continuation of a successful sealed proposal/terminal plus its required durable causal receipt (for example, a tool result), never as replacement for the failed call. Every successful shared lineage entry therefore carries one complete exact-branch `BASProviderExecutionRef`; no partial or allocation-only entry is certifiable.
- Allocation/claim/lineage/proposal evidence freezes the complete sequence-zero `BASProviderExecutionRef`. Each Provider event is canonicalized and digested before adoption by the `TurnOperation`/engine actor's private transient unsealed `(nextSequence, digest)` CAS and carries the same type derived only through checked `withRequestSequence(next)`. Validation canonicalizes back to zero through that same checked API, equality-checks all six stable base fields, and advances that transient head once; an identical duplicate sequence+digest is audit-only/idempotent, the same sequence with another digest is a protocol violation, and a gap, out-of-order value, stable-field mutation, stale acceptance generation, inactive lease, wrong Attempt, operation root, egress branch, purpose, or output role is rejected without touching spool, logical state, or UI. `BASK3ControlNucleusStorage`/`BASSQLiteEventLogStorage` is separately the sole durable allocation, claim, bounded checkpoint-head, and terminal-seal authority. No second event-ref type/codec, seventh K3 API, sequence store, or sidecar ledger exists. Ordinary token/chunk events perform zero SQLite transaction, `synchronous=FULL` write, fsync, or Artifact Mesh put. A crash discards the transient unsealed tail, leaves the durable claim `possibleStarted/indeterminate`, and is query-only, never a blind retry or sibling substitution.
- `BASPlannedOrganRequest` never contains `responseSpoolArtifactID`: no spool artifact exists during Provider planning or execution. Provider correlation uses only the exact operation root, K3-allocated egress branch/role/causal predecessor, and Provider execution ref. After the designated terminal-answer egress reaches a structurally valid terminal and K3 seals the shared `.terminalPrefix` chain cut, W5 ordinary-puts the exact bytes as a non-publishable spool and only then obtains its ID. Buffered L10 acceptance and visibility closure consume that exact spool; incremental mode also terminal-verifies the same spool. K3 binds the returned ID exactly once to that egress plus `.finalPublication/0`; callers, Providers, and adapters cannot predict, preallocate, or replace it.
- W4 authorizes only Provider routes whose trust profile requires no unimplemented disclosure transport. An `isolatedExtension`/`remote` descriptor is preflight-ineligible until W5 wires the sovereign `BASProviderEgressBoundaryPermit` for the exact materialized payload/root/exact `.providerEgress[requestOrdinal]` branch: K3 pending permit → K4 anchor → K3 arm → K3 begin-handoff CAS → one transport call → canonical supervisor observation → event-head seal. `executePlanned` cannot call such a Provider from a policy check alone, and no adapter may synthesize the permit/anchor/arm or promote a Provider-authored receipt. The permit, anchor, arm, receipt-bound selected descriptor, and live hand-off deadline are consumed and exact-validated inside the same sole `BASProviderAttemptExecutor.executeExactlyOnce` invocation seam; an outer caller cannot arm then bypass the executor. Immediately before invoke, that executor calls package-only `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` on the same injected concrete `BASSQLiteEventLogStorage` object that implements the public branch/control-nucleus views: only the `egress_boundary_armed → sent_or_unknown` CAS winner receives callable `.won`; exact replay receives non-callable `.alreadyPossible`. A complete authenticated supervisor `BASProviderObservedReceipt` is then consumed by the existing `sealProviderEventHead`, which atomically advances `sent_or_unknown → terminal_or_indeterminate` in the same K3 transaction as the event-head seal/receipt. Local `inProcessCertified` calls require no disclosure fence or egress-handoff state. This plan consumes the existing sovereign fence when available and creates no egress broker, permit owner, seventh public branch-control method, public hand-off capability, or second terminalization CAS.
- `BASExecutionPlan` is executable truth, not advisory metadata. A successful provider completion must contain one ordered actuation receipt for every required phase—load, prefill, cache, decode—and each receipt must match the phase projection frozen in the plan. Missing, extra, reordered, or locally re-elected phases fail closed before publication.
- `BASOrganRegistry` stores identity only. Role-based LIFO selection, neural-matrix ranking, availability fallback, and retry leave the registry; authoritative routing lives only in `ProviderPlanningCore.swift`, and exact provider invocation lives only in `ProviderExecutionCore.swift`.
- `BASModelManifestRegistry.productionDefault` is the sole default. Qinao model enums, MLX catalog lists, sample-app defaults, and provider factories may project or request a manifest model ID, but cannot define another default.
- Qinao SDK remains model-independent. `QinaoMLX`, `QinaoAppleFoundation`, and Qinao-owned concrete provider factories are retired; Qinao factories accept a host-injected provider endpoint already bound to the process-shared HeavySeat/MemoryLedger. Qinao cannot import, instantiate, load, or select Qwen, MLX, Core AI, or Foundation Models.
- BASSystemProbe owns canonical system thermal classification and the BASSystemSnapshot capability payload shape; Artifact Mesh alone owns its ID/storage. BASThermalTwin owns live/accumulated thermal and Low Power observation. BASComputeTier is the physical CPU/GPU/Neural Engine axis. Placement evidence status is a different enum.
- Unknown thermal and unknown placement remain unknown. They never decode as nominal or observed.
- BASProcessMemoryLedger owns every cross-framework application reservation. Its one reservation map is the only pending/ordinary-active/heavy-active truth; ordinary work may overlap, while at most one heavy activation exists. Every admission uses one opaque BASMemoryAdmissionContext derived in memory from the verified BASSystemSnapshot capability artifact and child attestation, binding snapshot ID/epoch, context version, expiry, hard-cap policy artifact/digest, derivation version/source, and resolved cap. The context is not Codable, persisted, or independently identified; adapters never pass a naked hard cap. No second offer, active map, or active-lease dictionary is permitted.
- For MLX, acquisition order is BAS reservation/lease then vendored WiredMemoryTicket using WiredMemoryManager.shared. Release order is WiredMemoryTicket then BAS lease. No second MLX waiter, hysteresis, baseline, wired-limit manager, direct mlx_set_wired_limit path, or cached replacement for Memory.snapshot() is allowed.
- Core ML uses computeUnits and MLState. Core AI and NAX are evidence adapters only in this plan and cannot enter an authorized production fallback graph.
- NAX evidence describes an MLX/Metal GPU mechanism; it is not Apple Neural Engine custody and must not be labeled BASComputeTier.npu.
- Quality-preserving fallback may queue, slow, pause, reduce speculation, evict non-authoritative caches, or canonical re-prefill. It may not change weights, quantization, tokenizer, template/tool protocol, RNG/termination semantics, verifier, sovereign epoch, or mandatory coverage.
- Swift actors own business state; TaskGroup handles bounded fan-out; AsyncStream handles streams; the existing monotonic wrapper handles wire deadlines. Do not add a thread pool, blocking-semaphore scheduler, lock queue, or third clock.
- Logger/OSSignposter and MetricKit remain observation mirrors. They do not replace canonical evidence; MetricKit is not a per-run E4 verdict.
- Every task follows RED → minimal implementation → focused GREEN → regression GREEN → commit. Do not combine tasks into one commit.
- Every cross-target value shown with public fields receives an explicit public initializer in the exact displayed field order; never rely on an internal synthesized memberwise initializer. The sole exception is opaque BASMemoryAdmissionContext: its initializer remains BASLeaseLife-internal so an adapter cannot manufacture a hard cap; other targets obtain it only from a stateless verified-context gateway.

## Ownership and File Map

| Concern | Canonical owner after this plan | Change class | Production file action |
|---|---|---|---|
| Model and QualityIdentity | BASModelCapabilityManifest + BASModelManifestRegistry | E | Modify BASModelCapabilityManifest.swift |
| Per-turn neural identity | BASLLMInvocationContract | E | Modify BASLLMInvocationContract.swift and BASLLMContractDeriver.swift |
| Canonical numeric framing | BASSovereignCanonicalBytes | E | Modify BASSovereignCanonicalBytes.swift |
| Complete cross-backend state identity | BASStateABI | M | Create BASStateABI.swift |
| Plan and one binding root | BASExecutionPlan + BASExecutionPlanElector | E | Modify BASExecutionPlan.swift and BASExecutionPlanElector.swift |
| Per-turn lifecycle | BASTurnRuntimeEngine.TurnOperation | E | Modify BASTurnRuntimeEngine.swift; no parallel coordinator |
| Provider route/fallback plan | BASExecutableProviderPlanner | E | Modify ProviderPlanningCore.swift; preflight only |
| Exactly-once Provider claim/invocation per egress branch | Existing K3 `BASProviderBranchControlPort` + BASProviderAttemptExecutor | R/E | Consume the shared durable claim; modify ProviderExecutionCore.swift only as the claimed-call adapter |
| Provider identity lookup | BASOrganRegistry | E | Modify BASOrganRegistry.swift; remove role/ranking/fallback selection |
| Plan actuation and phase proof | BASExecutionPlan + BASOrganAdapter | E | Modify BASExecutionPlan.swift and BASOrganAdapter.swift; adapters return exact actuation receipts |
| One chunk source / one final | TurnOperation + sovereign BASResponseSpoolPayload/publication journal | R/E | One in-memory projection, one Artifact Mesh put, one final; eager never starts a second decode |
| Decode strategy taxonomy | BASDecodeStrategy | E | Modify BASDecodeStrategy.swift |
| Thermal truth | BASSystemProbe + BASThermalTwin | E | Modify existing files |
| Capability snapshot payload/identity | BASSystemSnapshot + Artifact Mesh | E/A | Version BASSystemSnapshot in BASSystemProbe.swift; ordinary put/read owns the ID, no new payload type |
| Physical placement | BASComputeTier | E/move without duplication | Move declaration to RuntimeCore and modify compatibility users |
| App memory admission, ordinary/heavy activation, lifecycle CAS | BASProcessMemoryLedger | M | Create BASProcessMemoryLedger.swift; its one reservation map is the only active truth |
| Exact signed-binding verification seam | BASExecutionPlan.BindingVerificationAdapter | A | Modify BASExecutionPlan.swift; it translates and verifies but owns no state or profile policy |
| Generic verified memory context seam | BASMemoryAdmissionContextGateway | A | Modify BASLeaseLifeCoordinator.swift; verifier-only, no context artifact/cache/map |
| Signed-profile offer/compare-and-start orchestration | Existing BASLeaseLifeCoordinator + stateless BASSiliconLeaseGateway | E/A | Modify BASLeaseLifeCoordinator.swift; gateway retains references only and owns no offer/active state |
| MLX actuation | Existing MLXOrganAdapter files | A | Modify existing entry/executor/stream/session files |
| Foundation Models provider | Existing BASAppleAdapters implementation | A | Keep concrete implementation outside Qinao; host injects it by provider ID |
| Core AI provider/evidence | Existing BASAppleAdapters implementation and shadow composer | A | Keep concrete implementation outside Qinao; production authorization still requires certification |
| NAX evidence | Vendored observation counters + existing MLX attribution | A | Modify vendor bridge and existing adapter |
| Qinao provider composition | Host-injected QinaoOrganEndpoint | E/delete | Modify QinaoDefaults/QinaoLoop neutral seams; delete Qinao concrete provider targets/factories |
| HeavySeat and memory | BASProcessMemoryLedger.processShared | E | Heavy-active is the sole seat projection; Qinao receives a host-bound endpoint using the same actor |

### Production Create Budget

Only these two production Creates are permitted by this plan:

1. BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift
2. BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift

Both have a complete Section 4.4 create proof in their task. New XCTest and Python test files are test assets, not production owners. Any third production Create requires a spec amendment.

### Exact OwnerLedger M Permissions and Candidate Manifests

These are the only two production `M` permissions consumed by this plan. `owner_id`, symbol, task, and workspace-relative path must byte-match `docs/superpowers/specs/qinao-owner-ledger-v1.json`; aliases such as `heavy.seat`, `stateABI`, or a package-relative `Sources/...` path are not OwnerLedger IDs and fail the CreateGate.

| `owner_id` | `authority_symbol` | `create_proof_task` | Exact `candidate_path` |
|---|---|---|---|
| `resource.process-memory-ledger` | `BASProcessMemoryLedger` | `silicon-execution-spine:Task 5` | `BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift` |
| `execution.state-abi` | `BASStateABI` | `silicon-execution-spine:Task 2` | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift` |

Before the RED command for either production Create, generate one ephemeral candidate manifest and pass it with repeatable `--candidate-manifest`. Its exact top-level fields are `schema_version`, `owner_id`, `classification`, `candidate_path`, `authority_symbol`, `create_proof_task`, and `create_proof`; `schema_version` is `1`, `classification` is `M`, and the other four identity values come verbatim from the row above. The proof object maps the task's eight numbered proof paragraphs, without abbreviation or placeholder, to exactly `repository_search`, `public_primitive`, `missing_invariant`, `extension_insufficient`, `single_owner`, `dependency_direction`, `compatibility_retirement`, and `verification`. Candidate manifests are temporary evidence, never a committed policy source. No production file may be created until this exact command passes:

For **each** of Task 2 (`execution.state-abi`) and Task 5 (`resource.process-memory-ledger`), add `docs/superpowers/specs/qinao-owner-ledger-v1.json`, `scripts/check_qinao_owner_ledger.py`, and `scripts/test_check_qinao_owner_ledger.py` to the task's Files and staging set. In the atomic change that creates its first allowlisted production path, append that path to the matching OwnerCard's `evidence_paths` and transition `approved_missing → converging`; append every later allowlisted path in its own creation change. Remove each `current_conflicts` item only with exact freeze/retirement source evidence and green tests; move a view to `allowed_projections` only after proving it has no authority, mutable state, or independent recovery. Run both checker scripts after every step. Transition `converging → implemented` only after every allowlisted path exists and is evidence-listed, every task gate passes, and `current_conflicts == []`. On failure, roll back code paths, evidence, conflict/projection changes, and status together; early `implemented` is forbidden.

```bash
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$CANDIDATE_MANIFEST"
```

---

### Task W0: Freeze the Owner Ledger and Make Current Split-Brain Paths Fail

**Reuse Decision:** R/E — `docs/superpowers/specs/qinao-owner-ledger-v1.json` is the machine-readable owner/create ledger and `scripts/check_qinao_owner_ledger.py` is its sole structural verifier. Extend their declared checks; do not create a second ownership table, scanner, or allowlist. This task is a blocking gate: capture the current failures before Task 1 and require the identical command to pass before any device certification.

**Files:**
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Create: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationOwnershipTests.swift`
- Create: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderBoundaryTests.swift`
- Create: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoProviderBoundaryTests.swift`
- Verify: `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoStreamingOrganEndpoint.swift`
- Verify: `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`
- Verify: `QinaoRuntimeSDK/Sources/QinaoMLX/QinaoMLXEndpoint.swift`
- Verify: `QinaoRuntimeSDK/Sources/QinaoAppleFoundation/QinaoAppleFoundationEndpoint.swift`
- Verify: `BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift`
- Verify: `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift`
- Verify: `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXModelCatalog.swift`
- Verify: `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderPlanningCore.swift`
- Verify: `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift`

**Owner-ledger records added in this task:**

| Exact OwnerLedger `owner_id` | Sole owner | Forbidden duplicates |
|---|---|---|
| `runtime.turn-operation` | `BASTurnRuntimeEngine.TurnOperation` | Qinao loop-local generation lifecycle, provider-local final owner, or post-start second Provider call |
| `execution.plan-provider-router` | `BASExecutionPlan`/`BASExecutionPlanElector` with one `BASExecutableProviderPlanner` route and `BASProviderAttemptExecutor.executeExactlyOnce` claim | role/LIFO registry routing, adapter-local plan/decode re-election, hidden retry/fallback |
| `model.manifest-invocation` | `BASModelCapabilityManifest` + `BASLLMInvocationContract`; default projected only by `BASModelManifestRegistry.productionDefault` | Qinao/catalog/provider competing model or default identity |
| `provider.package-boundary` | Qinao value-only Provider/Proposal contracts; concrete Provider-private runtime outside Qinao | Qinao concrete Qwen/MLX/Core AI/Foundation target/import/factory |
| `resource.process-memory-ledger` | `BASProcessMemoryLedger.processShared` | Qinao/provider seat manager, second pending/active/heavy map, or raw-cap owner |
| `execution.state-abi` | `BASStateABI` | partial attention-only ABI or second compatibility identity |
| `release.spool-publication` | sovereign spool/publication owners observed by `TurnOperation` | stream-local canonical body followed by eager regeneration or a second spool/final |
| `platform.ios27` | workspace build manifests/generated project settings | an iOS 18–26 production compatibility slice |

- [ ] **Step 1: Add the ledger rules and failing behavioral tests**

The owner-ledger verifier must validate every evidence path and exact Create permission, reject undeclared production Creates and forbidden owner/path drift, and emit deterministic PASS/error output. The behavioral tests below then prove symbol-level single ownership at the runtime seams; preserve their stable failure names as the W0 violation artifact rather than adding a second ownership scanner or report authority. Add these exact tests:

```swift
func testStreamingAndEagerViewsShareOneOperationAndProviderInvocation() async throws {
    let fixture = makeTurnOperationFixture()
    let operation = try await fixture.runtime.beginTurn(fixture.request)
    async let streamed = operation.stream().final()
    async let eager = operation.final()
    let (streamFinal, eagerFinal) = try await (streamed, eager)

    XCTAssertEqual(streamFinal.turnOperationRef, eagerFinal.turnOperationRef)
    XCTAssertEqual(streamFinal.providerEgressBranchRef, eagerFinal.providerEgressBranchRef)
    XCTAssertEqual(streamFinal.provisionalStreamBranchRef, eagerFinal.provisionalStreamBranchRef)
    XCTAssertEqual(streamFinal.finalPublicationBranchRef, eagerFinal.finalPublicationBranchRef)
    XCTAssertEqual(streamFinal.provisionalStreamBranchRef.kind, .provisionalStream)
    XCTAssertEqual(streamFinal.provisionalStreamBranchRef.ordinal, 0)
    XCTAssertEqual(streamFinal.finalPublicationBranchRef.kind, .finalPublication)
    XCTAssertEqual(streamFinal.finalPublicationBranchRef.ordinal, 0)
    XCTAssertEqual(streamFinal.providerEgressBranchRef.kind, .providerEgress)
    XCTAssertEqual(
        streamFinal.providerEgressBranchRef,
        streamFinal.terminalAnswerSourceBranchRef
    )
    XCTAssertEqual(streamFinal.planID, eagerFinal.planID)
    XCTAssertEqual(streamFinal.spoolArtifactID, eagerFinal.spoolArtifactID)
    let invocationCount = await fixture.provider.invocationCount
    let finalizationCount = await fixture.spool.finalizationCount
    XCTAssertEqual(invocationCount, 1)
    XCTAssertEqual(finalizationCount, 1)
}

func testRegistryResolvesOnlyAnExplicitProviderID() async throws {
    let registry = BASOrganRegistry()
    await registry.register(makeProvider(id: "provider-a"))
    await registry.register(makeProvider(id: "provider-b"))

    let adapter = try await registry.adapter(providerID: "provider-a")
    XCTAssertEqual(adapter.descriptor.providerID, "provider-a")
    await XCTAssertThrowsErrorAsync {
        _ = try await registry.adapter(providerID: "missing")
    }
}

func testProductionDefaultComesFromManifestOnly() {
    XCTAssertEqual(
        BASModelManifestRegistry.productionDefault.modelID,
        BASModelManifestRegistry.qwen35_4B_4bit.modelID)
}
```

`QinaoProviderBoundaryTests` parses `QinaoRuntimeSDK/Package.swift` and every file below `QinaoRuntimeSDK/Sources`; it fails if the SDK declares `QinaoMLX`, `QinaoAppleFoundation`, `QinaoMLXModel`, imports `BASMLXAdapter`/`BASAppleAdapters`, or constructs `MLXOrganAdapter`, `AppleFoundationOrganAdapter`, or any Core AI runner.

- [ ] **Step 2: Run W0 RED and preserve the exact violation JSON**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASTurnOperationOwnershipTests|BASProviderBoundaryTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoProviderBoundaryTests'
```

Expected RED: the verifier reports the current double-generation stream guidance, role/LIFO registry router, Qinao concrete provider factories, competing Gemma/catalog default, missing exact-once operation owner, and missing load/prefill/cache/decode actuation proof. The Swift tests fail for those same reasons. Save the JSON and failing test names as the baseline evidence; do not relax the ledger.

- [ ] **Step 3: Make this gate mandatory for every subsequent task**

Every Task 1–7 commit runs the three W0 commands after its focused tests. A task may temporarily leave unrelated W0 violations, but its owner key must move monotonically from failing to passing. Task 7 and physical-device certification require zero violations and all W0 tests green.

---

### Task 1 [W1]: Extend the Existing Manifest and Invocation Owners for Exact Identity

**Reuse Decision:** E — BASModelCapabilityManifest/BASModelManifestRegistry already own model identity, and BASLLMInvocationContract already owns per-call canonical identity. Extend them; do not create a parallel QualityIdentity or NeuralExecutionContract file/type hierarchy.

**Files:**
- Modify: BehavioralAISubstrate/Sources/BASRuntimeCore/BASSovereignCanonicalBytes.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASLLMInvocationContract.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASLLMContractDeriver.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLLMInvocationContractTests.swift

**Interfaces:**
- Consumes: BASSovereignCanonicalBytes.lengthPrefixed, SHA256 from Crypto, BASOrganRequest, BASOrganPreset, and the existing static BASModelManifestRegistry entries.
- Produces: BASModelCapabilityManifest.QualityIdentity, BASModelManifestRegistry.certifiedQualityIdentity(_:forModelID:), BASLLMInvocationContract.NeuralExecutionIdentity, neuralExecutionContractDigest, and deriveBound(purpose:request:qualityIdentity:rngAlgorithm:rngSeedOrStreamDigest:logitProcessorsDigest:stopEOSAndTerminationDigest:outputAndToolProtocolDigest:).

- [ ] **Step 1: Add failing owner, mutation, and v1 compatibility tests**

~~~swift
func testQualityIdentityLivesUnderManifestOwner() throws {
    let identity = fixtureQualityIdentity()
    let certified = try BASModelManifestRegistry.certifiedQualityIdentity(
        identity,
        forModelID: BASModelManifestRegistry.qwen35_4B_4bit.modelID
    )
    XCTAssertEqual(certified, identity)
    XCTAssertFalse(try identity.digestHex().isEmpty)
}

func testRegistryRejectsAnotherModelLineage() {
    XCTAssertThrowsError(
        try BASModelManifestRegistry.certifiedQualityIdentity(
            fixtureQualityIdentity(modelLineageID: "different/model"),
            forModelID: BASModelManifestRegistry.qwen35_4B_4bit.modelID
        )
    )
}

func testEveryQualityFieldAndNeuralFieldChangesOwningDigest() throws {
    XCTAssertEqual(QualityMutation.allCases.count, 9)
    XCTAssertEqual(NeuralMutation.allCases.count, 9)
    for mutation in QualityMutation.allCases {
        XCTAssertNotEqual(
            try fixtureQualityIdentity().digestHex(),
            try fixtureQualityIdentity(mutating: mutation).digestHex()
        )
    }
    for mutation in NeuralMutation.allCases {
        XCTAssertNotEqual(
            try fixtureNeuralIdentity().digestHex(),
            try fixtureNeuralIdentity(mutating: mutation).digestHex()
        )
    }
}

func testLegacyInvocationBytesRemainByteExact() throws {
    let decoded = try JSONDecoder().decode(
        BASLLMInvocationContract.self,
        from: legacyV1JSONFixture
    )
    XCTAssertNil(decoded.neuralExecutionIdentity)
    XCTAssertEqual(decoded.canonicalBytes(), legacyV1CanonicalBytesFixture)
    XCTAssertEqual(decoded.canonicalDomainForPayload, "bas.llm.invocation.contract/1.0.0")
}

func testBoundInvocationUsesV11AndExactTurnInputs() throws {
    let first = try fixtureBoundContract(rngStreamDigest: "stream-1")
    let second = try fixtureBoundContract(rngStreamDigest: "stream-2")
    XCTAssertEqual(first.canonicalDomainForPayload, "bas.llm.invocation.contract/1.1.0")
    XCTAssertNotEqual(
        try first.neuralExecutionContractDigest,
        try second.neuralExecutionContractDigest)
    XCTAssertNotEqual(first.canonicalBytes(), legacyV1CanonicalBytesFixture)
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASLLMInvocationContractTests
~~~

Expected: FAIL because nested QualityIdentity, NeuralExecutionIdentity, certifiedQualityIdentity, and v1.1 framing do not exist.

- [ ] **Step 3: Extend the one canonical byte utility with fixed-width binary fields**

~~~swift
public enum BASSovereignCanonicalBytes {
    public static func fields(_ fields: [Data]) -> Data {
        var output = Data()
        for field in fields {
            output.append(contentsOf: Array(String(field.count).utf8))
            output.append(0x3A)
            output.append(field)
        }
        return output
    }

    public static func lengthPrefixed(_ fields: [String]) -> Data {
        Self.fields(fields.map { Data($0.utf8) })
    }

    public static func uint64BigEndian(_ value: UInt64) -> Data {
        var encoded = value.bigEndian
        return withUnsafeBytes(of: &encoded) { Data($0) }
    }

    public static func doubleIEEE754BigEndian(_ value: Double) -> Data {
        uint64BigEndian(value.bitPattern)
    }

    public static func listData(_ values: [String]) -> [Data] {
        [uint64BigEndian(UInt64(values.count))] + values.map { Data($0.utf8) }
    }
}
~~~

Keep the existing public list(_:) behavior byte-identical. Add regression assertions for the old string encoder and exact eight-byte vectors for 0, UInt64.max, 0.0, and 1.0.

- [ ] **Step 4: Nest QualityIdentity under the existing manifest and validate it through the existing registry**

~~~swift
extension BASModelCapabilityManifest {
    public struct QualityIdentity: Codable, Sendable, Equatable, Hashable {
        public let modelLineageID: String
        public let architectureDigest: String
        public let weightsDigest: String
        public let quantizationDigest: String
        public let tokenizerDigest: String
        public let templateAndToolProtocolDigest: String
        public let generationSemanticsDigest: String
        public let verifierDigest: String
        public let sovereignPolicyEpoch: UInt64

        public init(
            modelLineageID: String,
            architectureDigest: String,
            weightsDigest: String,
            quantizationDigest: String,
            tokenizerDigest: String,
            templateAndToolProtocolDigest: String,
            generationSemanticsDigest: String,
            verifierDigest: String,
            sovereignPolicyEpoch: UInt64
        ) {
            self.modelLineageID = modelLineageID
            self.architectureDigest = architectureDigest
            self.weightsDigest = weightsDigest
            self.quantizationDigest = quantizationDigest
            self.tokenizerDigest = tokenizerDigest
            self.templateAndToolProtocolDigest =
                templateAndToolProtocolDigest
            self.generationSemanticsDigest = generationSemanticsDigest
            self.verifierDigest = verifierDigest
            self.sovereignPolicyEpoch = sovereignPolicyEpoch
        }

        public func canonicalBytes() throws -> Data {
            let strings = [
                modelLineageID, architectureDigest, weightsDigest,
                quantizationDigest, tokenizerDigest,
                templateAndToolProtocolDigest, generationSemanticsDigest,
                verifierDigest,
            ]
            guard strings.allSatisfy({ !$0.isEmpty }) else {
                throw BASModelIdentityError.emptyIdentityField
            }
            return BASSovereignCanonicalBytes.fields([
                Data("bas.model.quality-identity/1.0.0".utf8),
                Data(modelLineageID.utf8),
                Data(architectureDigest.utf8),
                Data(weightsDigest.utf8),
                Data(quantizationDigest.utf8),
                Data(tokenizerDigest.utf8),
                Data(templateAndToolProtocolDigest.utf8),
                Data(generationSemanticsDigest.utf8),
                Data(verifierDigest.utf8),
                BASSovereignCanonicalBytes.uint64BigEndian(sovereignPolicyEpoch),
            ])
        }

        public func digestHex() throws -> String {
            BASAutoRouteRanker.bytesToHexLower(
                Array(SHA256.hash(data: try canonicalBytes()))
            )
        }
    }
}

public enum BASModelIdentityError: Error, Equatable {
    case unknownModel(String)
    case lineageMismatch(expected: String, actual: String)
    case emptyIdentityField
    case invalidNumericField
}

extension BASModelManifestRegistry {
    public static func certifiedQualityIdentity(
        _ identity: BASModelCapabilityManifest.QualityIdentity,
        forModelID modelID: String
    ) throws -> BASModelCapabilityManifest.QualityIdentity {
        guard manifest(forModelID: modelID) != nil else {
            throw BASModelIdentityError.unknownModel(modelID)
        }
        guard identity.modelLineageID == modelID else {
            throw BASModelIdentityError.lineageMismatch(
                expected: modelID,
                actual: identity.modelLineageID
            )
        }
        _ = try identity.canonicalBytes()
        return identity
    }
}
~~~

Do not insert invented hash literals into the seeded registry. Exact digest material arrives from the signed profile seam in Task 6; until then, a model can continue on the legacy compatibility path but cannot enter authoritative silicon mode.

- [ ] **Step 5: Extend BASLLMInvocationContract in place and add an exact bound derivation**

~~~swift
extension BASLLMInvocationContract {
    public struct NeuralExecutionIdentity: Codable, Sendable, Equatable {
        public let qualityIdentityDigest: String
        public let temperature: Double
        public let topP: Double
        public let rngAlgorithm: String
        public let rngSeedOrStreamDigest: String
        public let logitProcessorsDigest: String
        public let stopEOSAndTerminationDigest: String
        public let outputAndToolProtocolDigest: String
        public let maximumOutputTokens: UInt64

        public init(
            qualityIdentityDigest: String,
            temperature: Double,
            topP: Double,
            rngAlgorithm: String,
            rngSeedOrStreamDigest: String,
            logitProcessorsDigest: String,
            stopEOSAndTerminationDigest: String,
            outputAndToolProtocolDigest: String,
            maximumOutputTokens: UInt64
        ) {
            self.qualityIdentityDigest = qualityIdentityDigest
            self.temperature = temperature
            self.topP = topP
            self.rngAlgorithm = rngAlgorithm
            self.rngSeedOrStreamDigest = rngSeedOrStreamDigest
            self.logitProcessorsDigest = logitProcessorsDigest
            self.stopEOSAndTerminationDigest =
                stopEOSAndTerminationDigest
            self.outputAndToolProtocolDigest =
                outputAndToolProtocolDigest
            self.maximumOutputTokens = maximumOutputTokens
        }

        public func canonicalBytes() throws -> Data {
            guard temperature.isFinite, topP.isFinite else {
                throw BASModelIdentityError.invalidNumericField
            }
            guard !qualityIdentityDigest.isEmpty,
                  !rngAlgorithm.isEmpty,
                  !rngSeedOrStreamDigest.isEmpty,
                  !logitProcessorsDigest.isEmpty,
                  !stopEOSAndTerminationDigest.isEmpty,
                  !outputAndToolProtocolDigest.isEmpty
            else {
                throw BASModelIdentityError.emptyIdentityField
            }
            return BASSovereignCanonicalBytes.fields([
                Data("bas.llm.neural-execution-identity/1.0.0".utf8),
                Data(qualityIdentityDigest.utf8),
                BASSovereignCanonicalBytes.doubleIEEE754BigEndian(temperature),
                BASSovereignCanonicalBytes.doubleIEEE754BigEndian(topP),
                Data(rngAlgorithm.utf8),
                Data(rngSeedOrStreamDigest.utf8),
                Data(logitProcessorsDigest.utf8),
                Data(stopEOSAndTerminationDigest.utf8),
                Data(outputAndToolProtocolDigest.utf8),
                BASSovereignCanonicalBytes.uint64BigEndian(maximumOutputTokens),
            ])
        }

        public func digestHex() throws -> String {
            BASAutoRouteRanker.bytesToHexLower(
                Array(SHA256.hash(data: try canonicalBytes()))
            )
        }
    }
}
~~~

Add neuralExecutionIdentity as an optional stored field to BASLLMInvocationContract, default nil in the existing initializer, and use this exact domain selection:

~~~swift
public extension BASLLMInvocationContract {
public var canonicalDomainForPayload: String {
    neuralExecutionIdentity == nil
        ? "bas.llm.invocation.contract/1.0.0"
        : "bas.llm.invocation.contract/1.1.0"
}

public var neuralExecutionContractDigest: String? {
    get throws {
        try neuralExecutionIdentity?.digestHex()
    }
}
}
~~~

The nil branch must execute the existing v1 canonicalBytes body unchanged. The nonnil branch encodes the same v1 fields under the v1.1 domain and appends exactly one field: the nested NeuralExecutionIdentity canonical bytes. Add this exact bound deriver; every argument has no default:

~~~swift
public extension BASLLMContractDeriver {
public static func deriveBound(
    purpose: BASLLMCallPurpose,
    request: BASOrganRequest,
    qualityIdentity: BASModelCapabilityManifest.QualityIdentity,
    rngAlgorithm: String,
    rngSeedOrStreamDigest: String,
    logitProcessorsDigest: String,
    stopEOSAndTerminationDigest: String,
    outputAndToolProtocolDigest: String
) throws -> BASLLMInvocationContract {
    let rawMaximum = request.maxOutputTokens
        ?? request.preset.maxOutputTokens
    guard rawMaximum >= 0 else {
        throw BASModelIdentityError.invalidNumericField
    }
    let maximum = UInt64(rawMaximum)
    let neural = BASLLMInvocationContract.NeuralExecutionIdentity(
        qualityIdentityDigest: try qualityIdentity.digestHex(),
        temperature: request.preset.temperature,
        topP: request.preset.topP,
        rngAlgorithm: rngAlgorithm,
        rngSeedOrStreamDigest: rngSeedOrStreamDigest,
        logitProcessorsDigest: logitProcessorsDigest,
        stopEOSAndTerminationDigest: stopEOSAndTerminationDigest,
        outputAndToolProtocolDigest: outputAndToolProtocolDigest,
        maximumOutputTokens: maximum
    )
    return BASLLMContractDeriver.derive(
        purpose: purpose,
        request: request,
        neuralExecutionIdentity: neural
    )
}
}
~~~

Extend the existing derive function with neuralExecutionIdentity defaulting to nil solely for source compatibility. Authoritative silicon admission in Task 6 rejects nil.

- [ ] **Step 6: Run focused and compatibility GREEN**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASLLMInvocationContractTests|BASSovereignCanonicalBytesInjectivityTests|BASExecutionPlanElectorTests'
~~~

Expected: PASS; the legacy v1 fixture remains byte-identical, every identity mutation changes its digest, and no top-level BASQualityIdentity declaration exists.

- [ ] **Step 7: Commit**

~~~bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASSovereignCanonicalBytes.swift BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift BehavioralAISubstrate/Sources/BASOrgan/BASLLMInvocationContract.swift BehavioralAISubstrate/Sources/BASOrgan/BASLLMContractDeriver.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLLMInvocationContractTests.swift
git commit -m "feat: extend model and invocation identity owners"
~~~

### Task 2 [W4]: Add the Missing Complete Cross-Backend StateABI

**Reuse Decision:** M — BASSessionKVStore and BASStateLakeReader own concrete persisted state, but neither describes every byte-level invariant needed to move state between MLX and Core AI. Extend those stores to consume one new RuntimeCore StateABI; do not add another state store or converter registry.

Task-local M gate for `silicon-execution-spine:Task 2`: the first source-create delta stages the ledger/checker/checker-test, adds the exact production-path permission and evidence, and atomically changes `approved_missing → converging`; later deltas append evidence. Remove conflicts only with proof. Set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Files:**
- Modify: docs/superpowers/specs/qinao-owner-ledger-v1.json
- Modify: scripts/check_qinao_owner_ledger.py
- Modify: scripts/test_check_qinao_owner_ledger.py
- Create: BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift
- Modify: BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/BASSessionKVStore.swift
- Modify: BehavioralAISubstrate/Sources/BASAppleAdapters/BASStateLakeReader.swift
- Modify: BehavioralAISubstrate/DeviceTestApp/Sources/App/BASCoreAIStateLakeProbe.swift
- Modify: BehavioralAISubstrate/Tools/mamba3_statelake.py
- Modify: BehavioralAISubstrate/Tools/mamba3_statelake_device_prep.py
- Create: BehavioralAISubstrate/Tools/test_statelake_state_abi.py
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateABITests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateLakeReaderABITests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift

**Interfaces:**
- Consumes: BASArtifactID and Artifact Mesh receipts from the prerequisite plan, BASSovereignCanonicalBytes fixed-width fields, existing KV/session metadata, existing StateLake checksum/model/version validation.
- Produces: BASStateABI, BASVerifiedStateConverter, BASStateSwitchRule, BASStateSwitchDecisionPayload, and mandatory stateABIArtifactID/stateABIDigest checks at every state reader.

**Production Create Proof — BASStateABI.swift:**

1. Repository search: rg -n "StateABI|state abi|tensorNames|strides|rope|cache.index" BehavioralAISubstrate/Sources lists BASSessionKVStore, BASStateLakeReader, Core AI state probes, and model-specific cache values; it finds no complete cross-backend ABI owner.
2. Public/upstream search: Core ML MLState owns Core ML buffers and MLX owns its cache objects, but neither public primitive defines an application cross-backend tensor/layout/position contract.
3. Missing invariant: one exhaustive, canonical digest covering schema, names/order, dtype, shape, stride, layout, endianness, head grouping, positions, RoPE, quantization, fill semantics, limits, model binding, and runtime state version.
4. Extension/composition failure: adding a digest independently to each reader would create multiple field inventories and contradictory switching decisions.
5. Authority/state/storage/failure: BASStateABI is immutable RuntimeCore value authority; it owns no mutable state or store. Artifact Mesh owns storage. Mismatch fails before payload bytes are exposed and falls back to canonical re-prefill.
6. Dependency direction: RuntimeCore has no MLX/Core AI dependency; concrete stores depend downward on BASStateABI.
7. Compatibility: existing persisted state without ABI is decodeable only by an explicit legacy migration tool and is never admitted to cross-backend reuse.
8. Duplicate-owner tests: count-pinned field mutation, reader-before-bytes rejection, converter ambiguity, expiry, corrupt state, and source scan for a second StateABI declaration.

- [ ] **Step 1: Write failing ABI, converter, and reader-before-bytes tests**

~~~swift
func testEveryStateABIFieldMutationChangesDigest() throws {
    XCTAssertEqual(StateABIMutation.allCases.count, 17)
    for mutation in StateABIMutation.allCases {
        XCTAssertNotEqual(
            try fixtureStateABI().digestHex(),
            try fixtureStateABI(mutating: mutation).digestHex()
        )
    }
}

func testStrideRoPEAndRuntimeVersionMismatchCanonicalReprefill() throws {
    let source = fixtureStateABI()
    for target in [
        fixtureStateABI(strides: [[128, 1]]),
        fixtureStateABI(ropeAndScalingDigest: "rope-b"),
        fixtureStateABI(runtimeFunctionStateVersion: "coreai-state-v4"),
    ] {
        XCTAssertEqual(
            try BASStateABISwitching.select(
                source: source,
                target: target,
                verifiedConverters: [],
                atLogicalTime: 50
            ).rule,
            .canonicalReprefill
        )
    }
}

func testExactlyOneUnexpiredVerifiedConverterMayRun() throws {
    let converter = fixtureVerifiedConverter(expiryLogicalTime: 100)
    XCTAssertEqual(
        try BASStateABISwitching.select(
            source: fixtureSourceABI(),
            target: fixtureTargetABI(),
            verifiedConverters: [converter],
            atLogicalTime: 99
        ).rule,
        .convert(converterArtifactID: converter.converterArtifactID)
    )
    XCTAssertEqual(
        try BASStateABISwitching.select(
            source: fixtureSourceABI(),
            target: fixtureTargetABI(),
            verifiedConverters: [converter],
            atLogicalTime: 100
        ).rule,
        .canonicalReprefill
    )
}

func testReaderRejectsMismatchBeforeTensorLoaderRuns() throws {
    var tensorLoaderCalls = 0
    XCTAssertThrowsError(
        try fixtureReader(tensorLoader: { tensorLoaderCalls += 1 })
            .read(expectedStateABIDigest: "expected")
    )
    XCTAssertEqual(tensorLoaderCalls, 0)
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_STATE_ABI_CANDIDATE_MANIFEST:?set the ephemeral execution.state-abi candidate manifest path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$BAS_STATE_ABI_CANDIDATE_MANIFEST"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASStateABITests|BASStateLakeReaderABITests'
~~~

Expected: FAIL because BASStateABI and the mandatory reader arguments do not exist.

- [ ] **Step 3: Create the complete immutable ABI and deterministic switch rule**

~~~swift
import Foundation
import Crypto

public struct BASStateABI: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let canonicalizationVersion: String
    public let tensorNamesInOrder: [String]
    public let dtypes: [String]
    public let shapes: [[UInt64]]
    public let strides: [[UInt64]]
    public let layout: String
    public let endianness: String
    public let layerHeadGroupingDigest: String
    public let positionAndCacheIndexDigest: String
    public let ropeAndScalingDigest: String
    public let quantizationDigest: String
    public let fillAndEmptySemanticsDigest: String
    public let maximumSequence: UInt64
    public let maximumBatch: UInt64
    public let modelConfigWeightsDigest: String
    public let runtimeFunctionStateVersion: String

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        canonicalizationVersion: String,
        tensorNamesInOrder: [String],
        dtypes: [String],
        shapes: [[UInt64]],
        strides: [[UInt64]],
        layout: String,
        endianness: String,
        layerHeadGroupingDigest: String,
        positionAndCacheIndexDigest: String,
        ropeAndScalingDigest: String,
        quantizationDigest: String,
        fillAndEmptySemanticsDigest: String,
        maximumSequence: UInt64,
        maximumBatch: UInt64,
        modelConfigWeightsDigest: String,
        runtimeFunctionStateVersion: String
    ) {
        self.schemaVersion = schemaVersion
        self.canonicalizationVersion = canonicalizationVersion
        self.tensorNamesInOrder = tensorNamesInOrder
        self.dtypes = dtypes
        self.shapes = shapes
        self.strides = strides
        self.layout = layout
        self.endianness = endianness
        self.layerHeadGroupingDigest = layerHeadGroupingDigest
        self.positionAndCacheIndexDigest = positionAndCacheIndexDigest
        self.ropeAndScalingDigest = ropeAndScalingDigest
        self.quantizationDigest = quantizationDigest
        self.fillAndEmptySemanticsDigest = fillAndEmptySemanticsDigest
        self.maximumSequence = maximumSequence
        self.maximumBatch = maximumBatch
        self.modelConfigWeightsDigest = modelConfigWeightsDigest
        self.runtimeFunctionStateVersion = runtimeFunctionStateVersion
    }

    public func canonicalBytes() throws -> Data {
        guard tensorNamesInOrder.count == dtypes.count,
              dtypes.count == shapes.count,
              shapes.count == strides.count,
              !tensorNamesInOrder.isEmpty,
              endianness == "little" || endianness == "big"
        else {
            throw BASStateABIError.invalidFieldCardinality
        }
        func rows(_ values: [[UInt64]]) -> [Data] {
            [BASSovereignCanonicalBytes.uint64BigEndian(UInt64(values.count))]
            + values.flatMap { row in
                [BASSovereignCanonicalBytes.uint64BigEndian(UInt64(row.count))]
                + row.map(BASSovereignCanonicalBytes.uint64BigEndian)
            }
        }
        var fields: [Data] = [
            Data("bas.state-abi/1.0.0".utf8),
            Data(schemaVersion.utf8),
            Data(canonicalizationVersion.utf8),
        ]
        fields += BASSovereignCanonicalBytes.listData(tensorNamesInOrder)
        fields += BASSovereignCanonicalBytes.listData(dtypes)
        fields += rows(shapes)
        fields += rows(strides)
        fields += [
            Data(layout.utf8),
            Data(endianness.utf8),
            Data(layerHeadGroupingDigest.utf8),
            Data(positionAndCacheIndexDigest.utf8),
            Data(ropeAndScalingDigest.utf8),
            Data(quantizationDigest.utf8),
            Data(fillAndEmptySemanticsDigest.utf8),
            BASSovereignCanonicalBytes.uint64BigEndian(maximumSequence),
            BASSovereignCanonicalBytes.uint64BigEndian(maximumBatch),
            Data(modelConfigWeightsDigest.utf8),
            Data(runtimeFunctionStateVersion.utf8),
        ]
        return BASSovereignCanonicalBytes.fields(fields)
    }

    public func digestHex() throws -> String {
        BASAutoRouteRanker.bytesToHexLower(
            Array(SHA256.hash(data: try canonicalBytes()))
        )
    }
}

public enum BASStateABIError: Error, Equatable {
    case invalidFieldCardinality
    case digestMismatch(expected: String, actual: String)
}

public enum BASStateSwitchRule: Codable, Sendable, Equatable {
    case directReuse
    case convert(converterArtifactID: BASArtifactID)
    case canonicalReprefill
}

public struct BASVerifiedStateConverter: Codable, Sendable, Equatable {
    public let converterArtifactID: BASArtifactID
    public let attestationArtifactID: BASArtifactID
    public let sourceStateABIDigest: String
    public let targetStateABIDigest: String
    public let implementationArtifactID: BASArtifactID
    public let evidenceManifestArtifactID: BASArtifactID
    public let resourceProfileArtifactID: BASArtifactID
    public let fallbackReceiptArtifactID: BASArtifactID
    public let expiryLogicalTime: UInt64

    public init(
        converterArtifactID: BASArtifactID,
        attestationArtifactID: BASArtifactID,
        sourceStateABIDigest: String,
        targetStateABIDigest: String,
        implementationArtifactID: BASArtifactID,
        evidenceManifestArtifactID: BASArtifactID,
        resourceProfileArtifactID: BASArtifactID,
        fallbackReceiptArtifactID: BASArtifactID,
        expiryLogicalTime: UInt64
    ) {
        self.converterArtifactID = converterArtifactID
        self.attestationArtifactID = attestationArtifactID
        self.sourceStateABIDigest = sourceStateABIDigest
        self.targetStateABIDigest = targetStateABIDigest
        self.implementationArtifactID = implementationArtifactID
        self.evidenceManifestArtifactID = evidenceManifestArtifactID
        self.resourceProfileArtifactID = resourceProfileArtifactID
        self.fallbackReceiptArtifactID = fallbackReceiptArtifactID
        self.expiryLogicalTime = expiryLogicalTime
    }
}

public struct BASStateSwitchDecisionPayload: Codable, Sendable, Equatable {
    public let sourceStateABIDigest: String
    public let targetStateABIDigest: String
    public let evaluatedLogicalTime: UInt64
    public let eligibleConverterArtifactIDs: [BASArtifactID]
    public let rule: BASStateSwitchRule

    public init(
        sourceStateABIDigest: String,
        targetStateABIDigest: String,
        evaluatedLogicalTime: UInt64,
        eligibleConverterArtifactIDs: [BASArtifactID],
        rule: BASStateSwitchRule
    ) {
        self.sourceStateABIDigest = sourceStateABIDigest
        self.targetStateABIDigest = targetStateABIDigest
        self.evaluatedLogicalTime = evaluatedLogicalTime
        self.eligibleConverterArtifactIDs = eligibleConverterArtifactIDs
        self.rule = rule
    }
}

public enum BASStateABISwitching {
    public static func select(
        source: BASStateABI,
        target: BASStateABI,
        verifiedConverters: [BASVerifiedStateConverter],
        atLogicalTime: UInt64
    ) throws -> BASStateSwitchDecisionPayload {
        let sourceDigest = try source.digestHex()
        let targetDigest = try target.digestHex()
        if sourceDigest == targetDigest {
            return BASStateSwitchDecisionPayload(
                sourceStateABIDigest: sourceDigest,
                targetStateABIDigest: targetDigest,
                evaluatedLogicalTime: atLogicalTime,
                eligibleConverterArtifactIDs: [],
                rule: .directReuse
            )
        }
        let eligible = verifiedConverters.filter {
            $0.sourceStateABIDigest == sourceDigest
            && $0.targetStateABIDigest == targetDigest
            && atLogicalTime < $0.expiryLogicalTime
        }
        return BASStateSwitchDecisionPayload(
            sourceStateABIDigest: sourceDigest,
            targetStateABIDigest: targetDigest,
            evaluatedLogicalTime: atLogicalTime,
            eligibleConverterArtifactIDs: eligible.map(\.converterArtifactID),
            rule: eligible.count == 1
                ? .convert(converterArtifactID: eligible[0].converterArtifactID)
                : .canonicalReprefill
        )
    }
}
~~~

`BASStateABI` is independently ordinary-put, so every write, identity-byte construction, and reopen must use the Contracts-owned `BASGovernedArtifactPayloadCodec`; raw encoder/decoder paths and use-before-version-check fail the gate. Register it exactly once in the existing registry with `entry("BASStateABI", versionedType: BASStateABI.self, tests: ["schema.BASStateABI.current", "schema.BASStateABI.backward_v1", "schema.BASStateABI.future_rejection"], learnability: .semiLearnable)`. The registry tests assert exact-one object ID, registered-version equality to `BASStateABI.currentSchemaVersion`, current codec round-trip, pinned v1 backward fixture, missing/future-version rejection before a state reader/tensor loader, and no alias entry. A test-target compile fixture imports `BASRuntimeCore` and constructs `BASStateABI` through the explicit public initializer while omitting `schemaVersion`, proving the default is cross-target usable. SQL/tool representations may embed the ABI Artifact ID/digest, but no embedded switch rule or converter becomes a separately registered payload merely by being a field.

select is throwing because canonical validation can fail; tests must prove malformed ABI returns an error, never a trap. The shown field inventory and branch semantics are exact.

- [ ] **Step 4: Bind existing KV and StateLake stores before payload access**

Add stateABIArtifactID and stateABIDigest to existing KV/session metadata. In BASStateLakeReader, decode header.json first and execute this guard before opening any tensor file:

~~~swift
guard header.stateABIArtifactID == expectedStateABIArtifactID,
      header.stateABIDigest == expectedStateABIDigest
else {
    throw BASStateLakeReaderError.stateABIMismatch(
        expectedArtifactID: expectedStateABIArtifactID,
        expectedDigest: expectedStateABIDigest,
        actualArtifactID: header.stateABIArtifactID,
        actualDigest: header.stateABIDigest
    )
}
~~~

Remove the production overload that omits expected ABI. Update BASCoreAIStateLakeProbe to pass the binding-derived artifact ID and digest. Preserve existing checksum, model ID, version, and binding-key checks after the ABI guard.

- [ ] **Step 5: Make both Python writers and readers require the same ABI fields**

~~~python
def state_abi_header_fields(state_abi_artifact_id: dict, state_abi_digest: str) -> dict:
    if not state_abi_artifact_id:
        raise ValueError("state_abi_artifact_id is required")
    if not state_abi_digest:
        raise ValueError("state_abi_digest is required")
    return {
        "state_abi_artifact_id": state_abi_artifact_id,
        "state_abi_digest": state_abi_digest,
    }

def require_state_abi(header: dict, expected_artifact_id: dict, expected_digest: str) -> None:
    if header.get("state_abi_artifact_id") != expected_artifact_id:
        raise ValueError("state ABI artifact mismatch")
    if header.get("state_abi_digest") != expected_digest:
        raise ValueError("state ABI digest mismatch")
~~~

Call these exact helpers from mamba3_statelake.serialize_artifact and mamba3_statelake_device_prep.write_statelake, and from their local read/verify paths before loading binary payloads.

- [ ] **Step 6: Run Swift and Python GREEN**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASStateABITests|BASStateLakeReaderABITests|BASSessionKVStoreModelIDTests|BASSessionKVStoreQuantizeTests|BASEBrainSchemaGovernanceRegistryTests'
uv run --with pytest pytest /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/test_statelake_state_abi.py
test "$(rg -n '^public struct BASStateABI:' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
~~~

Expected: all selected Swift tests PASS; pytest reports PASS; the shell assertion exits 0; missing/mismatched ABI fails before tensorLoader is called.

- [ ] **Step 7: Commit**

~~~bash
git add docs/superpowers/specs/qinao-owner-ledger-v1.json scripts/check_qinao_owner_ledger.py scripts/test_check_qinao_owner_ledger.py BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Sources/BASMLXAdapter/BASSessionKVStore.swift BehavioralAISubstrate/Sources/BASAppleAdapters/BASStateLakeReader.swift BehavioralAISubstrate/DeviceTestApp/Sources/App/BASCoreAIStateLakeProbe.swift BehavioralAISubstrate/Tools/mamba3_statelake.py BehavioralAISubstrate/Tools/mamba3_statelake_device_prep.py BehavioralAISubstrate/Tools/test_statelake_state_abi.py BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateABITests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStateLakeReaderABITests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git commit -m "feat: add complete cross-backend state abi"
~~~

### Task 3 [W4]: Make BASExecutionPlan Own One Canonical Silicon Binding Root

**Reuse Decision:** E — `BASExecutionPlan` and `BASExecutionPlanElector` already own execution election. Extend that owner with the canonical binding payload/root and keep exact-profile verification as a stateless adapter inside its file. Consume the descriptor/containment value contract and first-governed parent already frozen by Task 7's W1 slice; Task 3 may ordinary-put that parent after routing but cannot declare the enum/property/parent, migrate constructors, or add its registry entry. Do not create `BASSiliconExecutionContracts.swift`, `BASCertifiedProfileRegistry.swift`, or another mutable registry.

**Files:**
- Modify: BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlanElector.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASDecodeStrategy.swift
- Modify: BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExecutionPlanElectorTests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconExecutionBindingTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift

**Interfaces:**
- Consumes: certified QualityIdentity and NeuralExecutionIdentity from Task 1, BASStateABI artifact/digest from Task 2, BASArtifactID/Artifact Mesh, existing BASDecodeStrategy and BASExecutionPlan axes, signed main/auxiliary model manifests/profiles, exact Provider-step budget-policy artifacts, and the Contracts Task 2A `BASProviderBranchPolicy` plus shared `BASProviderStepPurpose`, `BASProviderOutputRole`, and `BASProviderVisibilityMode` types.
- Produces: `BASCertifiedBackendProfilePayload`, `BASSiliconFallbackGraphPayload`, one bounded `stepRuleID → model/profile/plan-template/budget` execution mapping inside `BASSiliconExecutionBinding`, `BASExecutionPlan.Election`, and exactly one `executionBindingArtifactID` on every authoritative turn/step request. It consumes Task 7 W1's already-final `BASPersistedOrganDescriptorPayload` 1.0.0 and may ordinary-put it after route selection; it never produces or mutates that contract. Per-egress K3 instantiation references this root and the already-installed policy root; it never produces an execution-binding array or second policy.

- [ ] **Step 1: Write failing single-root, exact-fallback, and quarantine tests**

~~~swift
func testPlanOwnsOnlyOneBindingRoot() throws {
    let plan = try fixtureMaterializedStepPlan(
        executionBindingArtifactID: fixtureArtifactID("binding"),
        causalInputArtifactIDs: [fixtureArtifactID("snapshot")]
    )
    XCTAssertEqual(plan.executionBindingArtifactID, fixtureArtifactID("binding"))
    XCTAssertFalse(Mirror(reflecting: plan).children.contains {
        ["qualityIdentityDigest", "stateABIDigest", "fallbackGraphDigest"]
            .contains($0.label)
    })
}

func testFallbackNamesExactProfileBundleStrategyStateRuleAndRecovery() throws {
    let edge = try XCTUnwrap(fixtureBinding().fallbackGraph.edges.first)
    XCTAssertFalse(edge.backendProfileArtifactID.commitmentHex.isEmpty)
    XCTAssertFalse(edge.bundleArtifactID.commitmentHex.isEmpty)
    XCTAssertEqual(edge.strategy, .plain)
    XCTAssertEqual(edge.stateRule, .canonicalReprefill)
    XCTAssertEqual(edge.recoveryAction, .rebuildPrefill)
}

func testUnknownDeviceCannotInheritA19Profile() {
    XCTAssertThrowsError(
        try BASExecutionPlanElector.elect(
            input: fixtureElectionInput(deviceFingerprint: "unknown-device"),
            certifiedProfiles: [fixtureA19Profile()]
        )
    ) { error in
        XCTAssertEqual(error as? BASExecutionPlanElectionError, .quarantinedUnknownDevice)
    }
}

func testRequestCarriesBindingRootWithoutParallelDigestList() {
    let request = fixtureOrganRequest(
        executionBindingArtifactID: fixtureArtifactID("binding")
    )
    XCTAssertEqual(request.executionBindingArtifactID, fixtureArtifactID("binding"))
}

func testOneBindingRootContainsBoundedSignedProviderStepDAG() throws {
    let binding = try fixtureBinding()
    XCTAssertEqual(
        binding.orderedProviderStepTemplates.map(\.stepRuleID),
        ["grounding", "tool-step", "terminal-answer", "verifier"]
    )
    XCTAssertEqual(
        binding.providerBranchPolicyArtifactID,
        fixtureArtifactID("provider-branch-policy")
    )
    XCTAssertEqual(
        try binding.template(stepRuleID: "terminal-answer")
            .modelManifestArtifactID,
        fixtureQwen35_4BManifestArtifactID()
    )
    XCTAssertFalse(Mirror(reflecting: binding).children.compactMap(\.label)
        .contains("visibilityPolicy"))
    XCTAssertFalse(Mirror(reflecting: binding).children.compactMap(\.label)
        .contains("ordinalAllocationPolicy"))
    XCTAssertFalse(Mirror(reflecting: binding).children.compactMap(\.label)
        .contains("executionBindingArtifactIDs"))
    let forbiddenTopLevelCopies: Set<String> = [
        "qualityIdentityDigest", "neuralExecutionContractDigest",
        "stateABIArtifactID", "stateABIDigest", "bundleArtifactID",
        "primaryBackendProfileArtifactID", "fallbackGraphArtifactID",
        "providerStepPurpose", "providerOutputRole"
    ]
    XCTAssertTrue(
        Set(Mirror(reflecting: binding).children.compactMap(\.label))
            .isDisjoint(with: forbiddenTopLevelCopies))
}
~~~

In `BASSiliconExecutionBindingTests`, consume the Task-7-W1 pinned descriptor fixture unchanged at the first W4 routing/ordinary-put call site. Reopen/current-decode it and require exact parent plus embedded-descriptor equality before binding/allocation. The owner fixture, all containment cases, missing/unknown-field rejection, and constructor inventory remain Task 7 W1 tests and are rerun here without regeneration or schema edits.

- [ ] **Step 2: Run RED**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconExecutionBindingTests|BASExecutionPlanElectorTests'
~~~

Expected: FAIL because the W4 binding/profile/fallback/plan payloads and one-root request field do not exist; the Task-7-W1 descriptor contract already compiles and its fixture stays green.

- [ ] **Step 3: Make BASDecodeStrategy canonically Codable in its existing file**

Use an explicit tagged wire form; never String(describing:):

First extend the existing RuntimeCore control vocabulary; this is the sole phase enum consumed by BASOrgan and BASLeaseLife:

~~~swift
public enum BASSiliconExecutionPhase:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case load
    case prefill
    case cache
    case decode
}
~~~

~~~swift
extension BASDecodeStrategy: Codable {
private enum CodingKeys: String, CodingKey { case kind, value }
private enum Kind: String, Codable {
    case plain, draftModelSpec, promptLookup, suffixLookup
    case saguaro, mtpSpec, mtpSpecSampling, probeOnly
}

public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .plain:
        try container.encode(Kind.plain, forKey: .kind)
    case .draftModelSpec(let value):
        try container.encode(Kind.draftModelSpec, forKey: .kind)
        try container.encode(value, forKey: .value)
    case .promptLookup(let value):
        try container.encode(Kind.promptLookup, forKey: .kind)
        try container.encode(value, forKey: .value)
    case .suffixLookup(let value):
        try container.encode(Kind.suffixLookup, forKey: .kind)
        try container.encode(value, forKey: .value)
    case .saguaro(let value):
        try container.encode(Kind.saguaro, forKey: .kind)
        try container.encode(value, forKey: .value)
    case .mtpSpec:
        try container.encode(Kind.mtpSpec, forKey: .kind)
    case .mtpSpecSampling:
        try container.encode(Kind.mtpSpecSampling, forKey: .kind)
    case .probeOnly:
        try container.encode(Kind.probeOnly, forKey: .kind)
    }
}
}
~~~

Implement the symmetrical decoder inside the same conformance extension and reject negative K. Add a round-trip vector for every case.

- [ ] **Step 4: Add the four governed W4 profile/fallback/binding/plan values and consume the frozen W1 descriptor parent**

Task 7's earlier W1 value-contract receipt already added `BASProviderContainmentClass`, required `BASOrganDescriptor.containmentClass`, migrated the frozen constructor inventory, declared same-file first-governed `BASPersistedOrganDescriptorPayload` 1.0.0, and installed its cycle-safe registry entry. Task 3 byte-consumes those declarations and the pinned fixture only. It adds the four W4 governed execution values below, then may construct/ordinary-put/reopen the existing descriptor parent after routing. No Task-3 diff may touch the descriptor enum/property/initializer, constructor inventory, parent declaration, its registry entry, or its fixture bytes.

~~~swift

public struct BASCertifiedBackendProfilePayload:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let qualityIdentityDigest: String
    public let generationContractFamilyDigest: String
    public let bundleArtifactID: BASArtifactID
    public let adapterBuildDigest: String
    public let backendGraphDigest: String
    public let deviceCapabilityFingerprint: String
    public let skuCohortDigest: String
    public let osBuildCohortDigest: String
    public let runtimeVendorCommitDigest: String
    public let phase: BASSiliconExecutionPhase
    public let batchContextShapeDigest: String
    public let stateABIArtifactID: BASArtifactID
    public let stateABIDigest: String
    public let specializationOptionsDigest: String
    public let evidenceManifestArtifactID: BASArtifactID
    public let evidenceGrade: String
    public let sampleCount: UInt64
    public let expiryLogicalTime: UInt64
    public let fallbackGraphArtifactID: BASArtifactID

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        qualityIdentityDigest: String,
        generationContractFamilyDigest: String,
        bundleArtifactID: BASArtifactID,
        adapterBuildDigest: String,
        backendGraphDigest: String,
        deviceCapabilityFingerprint: String,
        skuCohortDigest: String,
        osBuildCohortDigest: String,
        runtimeVendorCommitDigest: String,
        phase: BASSiliconExecutionPhase,
        batchContextShapeDigest: String,
        stateABIArtifactID: BASArtifactID,
        stateABIDigest: String,
        specializationOptionsDigest: String,
        evidenceManifestArtifactID: BASArtifactID,
        evidenceGrade: String,
        sampleCount: UInt64,
        expiryLogicalTime: UInt64,
        fallbackGraphArtifactID: BASArtifactID
    ) {
        self.schemaVersion = schemaVersion
        self.qualityIdentityDigest = qualityIdentityDigest
        self.generationContractFamilyDigest =
            generationContractFamilyDigest
        self.bundleArtifactID = bundleArtifactID
        self.adapterBuildDigest = adapterBuildDigest
        self.backendGraphDigest = backendGraphDigest
        self.deviceCapabilityFingerprint = deviceCapabilityFingerprint
        self.skuCohortDigest = skuCohortDigest
        self.osBuildCohortDigest = osBuildCohortDigest
        self.runtimeVendorCommitDigest = runtimeVendorCommitDigest
        self.phase = phase
        self.batchContextShapeDigest = batchContextShapeDigest
        self.stateABIArtifactID = stateABIArtifactID
        self.stateABIDigest = stateABIDigest
        self.specializationOptionsDigest = specializationOptionsDigest
        self.evidenceManifestArtifactID = evidenceManifestArtifactID
        self.evidenceGrade = evidenceGrade
        self.sampleCount = sampleCount
        self.expiryLogicalTime = expiryLogicalTime
        self.fallbackGraphArtifactID = fallbackGraphArtifactID
    }
}

public enum BASSiliconRecoveryAction: String, Codable, Sendable {
    case continueCompatibleState
    case rebuildPrefill
    case queue
    case pauseAtCheckpoint
    case reject
}

public struct BASSiliconFallbackEdge: Codable, Sendable, Equatable {
    public let backendProfileArtifactID: BASArtifactID
    public let bundleArtifactID: BASArtifactID
    public let strategy: BASDecodeStrategy
    public let stateRule: BASStateSwitchRule
    public let recoveryAction: BASSiliconRecoveryAction

    public init(
        backendProfileArtifactID: BASArtifactID,
        bundleArtifactID: BASArtifactID,
        strategy: BASDecodeStrategy,
        stateRule: BASStateSwitchRule,
        recoveryAction: BASSiliconRecoveryAction
    ) {
        self.backendProfileArtifactID = backendProfileArtifactID
        self.bundleArtifactID = bundleArtifactID
        self.strategy = strategy
        self.stateRule = stateRule
        self.recoveryAction = recoveryAction
    }
}

public struct BASSiliconFallbackGraphPayload:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let edges: [BASSiliconFallbackEdge]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        edges: [BASSiliconFallbackEdge]
    ) {
        self.schemaVersion = schemaVersion
        self.edges = edges
    }
}

public struct BASSiliconProviderStepTemplate: Codable, Sendable, Equatable {
    public let stepRuleID: String
    public let modelManifestArtifactID: BASArtifactID
    public let backendProfileArtifactID: BASArtifactID
    public let executionPlanTemplateArtifactID: BASArtifactID
    public let budgetPolicyArtifactID: BASArtifactID

    public init(
        stepRuleID: String,
        modelManifestArtifactID: BASArtifactID,
        backendProfileArtifactID: BASArtifactID,
        executionPlanTemplateArtifactID: BASArtifactID,
        budgetPolicyArtifactID: BASArtifactID
    ) {
        self.stepRuleID = stepRuleID
        self.modelManifestArtifactID = modelManifestArtifactID
        self.backendProfileArtifactID = backendProfileArtifactID
        self.executionPlanTemplateArtifactID =
            executionPlanTemplateArtifactID
        self.budgetPolicyArtifactID = budgetPolicyArtifactID
    }
}

public struct BASSiliconExecutionBinding:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let orderedProviderStepTemplates: [BASSiliconProviderStepTemplate]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        providerBranchPolicyArtifactID: BASArtifactID,
        providerStepTemplates: [BASSiliconProviderStepTemplate]
    ) {
        self.schemaVersion = schemaVersion
        self.providerBranchPolicyArtifactID =
            providerBranchPolicyArtifactID
        self.orderedProviderStepTemplates = providerStepTemplates
    }
}

~~~

These four Task-3 values are ordinary Artifact Mesh payloads and contain no self artifact ID or signature. Extend the existing `BASExecutionPlan` declaration in place to conform to `BASSchemaVersioned`, keep its current Codable/source surface, add `public static let currentSchemaVersion = "1.0.0"`, add `schemaVersion` as its first stored field, and make `schemaVersion: String = Self.currentSchemaVersion` the first parameter of every public construction path. Do not create a plan wrapper. Every ordinary put/reopen of `BASCertifiedBackendProfilePayload`, `BASSiliconFallbackGraphPayload`, `BASSiliconExecutionBinding`, `BASExecutionPlan`, or the already-frozen `BASPersistedOrganDescriptorPayload` uses the Contracts-owned `BASGovernedArtifactPayloadCodec`; reject missing/unknown versions before reading identity, fallback, binding, actuation, or descriptor fields. Embedded fallback/template values remain unregistered children; descriptor containment children and their parent governance are consumed from Task 7 W1 unchanged.

Because BASAdmin must not gain a new direct dependency on the leaf `BASOrgan` target, register exactly the four Task-3 payloads with the existing Contracts string-only helper: `BASCertifiedBackendProfilePayload`, `BASSiliconFallbackGraphPayload`, `BASSiliconExecutionBinding`, and `BASExecutionPlan`. Task 3 must find the pre-existing exact-one `BASPersistedOrganDescriptorPayload` entry from Task 7 W1 and leave it byte-for-byte unchanged. Owner-target parity tests cover the four new entries and rerun the descriptor owner's first-v1/current/missing/future fixture. A cross-target compile fixture constructs the four new values and the already-existing descriptor parent through their explicit public default-version initializers. `swift package dump-package` proves the dependency graph remains cycle-free.

Silicon consumes—without redeclaring—the Contracts Task 2A/W1 `BASProviderStepPurpose`, `BASProviderOutputRole`, `BASProviderVisibilityMode`, `BASProviderExecutionRef`, and sole `BASProviderBranchPolicy` from `BASLowEntropyPrimitives.swift`; request/receipt/port types remain solely in `BASEventLog.swift`. The signed profile is an ordinary child attestation checked by Task 6. `BASSiliconExecutionBinding.validateComplete()` reopens `providerBranchPolicyArtifactID`, requires canonical unique `stepRuleID` order, proves every template names exactly one rule from that policy, and requires non-empty model/profile/plan-template/budget Artifact IDs. It also reopens each referenced model/profile/plan-template and validates their QualityIdentity, NeuralExecution, StateABI, bundle, backend, and fallback graph transitively; those facts remain children of the referenced artifacts and are never copied into the binding. The binding does not contain top-level identity/NeuralExecution/StateABI/bundle/profile/fallback fields, purpose, allowed output roles, instance limits, causal edges, answer-only state, post-terminal-pin permission, ordinal limits, visibility mode, or verifier limits. Those are artifact- or K3-authoritative facts available without a second binding owner. The policy must expose exactly one answer-only `.turnStep/.terminalAnswerCandidate` rule whose template names the selected user model (Qwen 3.5 4B by default); grounding/verifier rules are `.internalProposal` and their templates may name only signed auxiliary profiles.

The binding is the entire turn's one signed Provider-step DAG/template projection, not a list of per-call binding roots and not a second branch-policy owner. Each `BASProviderBranchAllocationRequest` sent through the prerequisite `BASProviderBranchControlPort` names the installed `providerBranchPolicyArtifactID`, this one `executionBindingArtifactID`, one exact `stepRuleID`, its plan artifact/root-membership proof, the post-preflight governed-parent `selectedProviderDescriptorArtifactID`, and ordered causal receipt artifacts. K3 validates purpose/output role, monotonic non-reused ordinal, max instances/branches, causal rule, answer-only restriction, terminal-pin rule, and `BASProviderVisibilityMode` exclusively against its already-installed `BASProviderBranchPolicy`; it persists the parent Artifact ID opaquely in its allocation row and exact-copies it into allocation/claim receipts. Silicon reopens/version-checks `BASPersistedOrganDescriptorPayload`, unwraps its descriptor, and validates embedded provider/containment plus model/profile/plan/budget membership. Neither the binding nor lineage gains a descriptor field; Silicon/Qinao never maintain an ordinal counter or instantiate a policy rule locally.

Add this sole authoritative reference to BASExecutionPlan:

~~~swift
public let executionBindingArtifactID: BASArtifactID
~~~

Keep fallbackChain only as a decode-only legacy/diagnostic projection derived from the elected fallback artifact. Mark it unavailable to authorization and actuation code. New initializers require executionBindingArtifactID. A custom legacy decoder may decode old plans into an explicit legacyUnbound compatibility value, but BASExecutionPlan.BindingVerificationAdapter rejects it before the stateless silicon gateway can reserve memory.

Add this sole reference to BASOrganRequest:

~~~swift
public let executionBindingArtifactID: BASArtifactID?
~~~

Default nil only for legacy decoding/source compatibility. Do not add quality/profile/ABI/fallback fields to BASOrganRequest.

- [ ] **Step 5: Materialize one binding root, then causal per-branch plans**

`BASExecutionPlanElector.electBinding(...)` runs only after the capability snapshot and StateRequirementPlan exist. It returns a transient `BindingElection` containing the self-ID-free `BASSiliconExecutionBinding`; the caller stores that one payload through ordinary Artifact Mesh, obtains `executionBindingArtifactID`, reopens/validates it, and attaches the ID once to the K3 TurnOperation head. It does not produce a branch, Provider execution, grounding proposal, compiled context, spool, or final decode plan.

Extend the existing `BASExecutionPlan` payload with only `stepRuleID`, the checked non-authoritative `requestedProviderOutputRole`, `orderedCausalInputArtifactIDs`, and the single `executionBindingArtifactID`. Do not store `providerStepPurpose`: K3 always derives it from the reopened policy rule. On every plan reopen, equality-check `stepRuleID`, requested role, causes, and template membership against the exact installed policy/binding before use. Then add this pure materializer to the existing elector:

~~~swift
public static func materializeStepPlan(
    executionBindingArtifactID: BASArtifactID,
    binding: BASSiliconExecutionBinding,
    template: BASSiliconProviderStepTemplate,
    providerBranchPolicy: BASProviderBranchPolicy,
    causalInputArtifactIDs: [BASArtifactID],
    templatePlan: BASExecutionPlan
) throws -> BASExecutionPlan
~~~

It reopens/equality-checks the template's plan/profile/model/budget artifacts, proves the template belongs to `binding`, proves its `stepRuleID` belongs to the reopened exact policy artifact, canonicalizes unique ordered causes, and copies the existing load/prefill/cache/decode/fallback actuation axes without re-election. `stepRuleID` is the lookup key and requested output role is only a checked projection of that shared policy rule; neither is independently chosen by Silicon, and purpose is not copied into the plan at all. The R5 `.groundingProposal/.internalProposal` call supplies exactly the semantic snapshot, requirement plan, and bounded reservoir/proposal-input artifacts. A `.turnStep/.terminalAnswerCandidate` plan is illegal until R6's validated grounding/State-Market receipt and the post-R6 compiled-context descriptor artifact exist; those exact IDs are its causes. A `.verifierProposal/.internalProposal` plan must name the pinned terminal source and verifier prerequisite artifacts authorized by the shared policy. The caller stores each returned self-ID-free plan once through ordinary Artifact Mesh, completes Provider preflight, constructs same-file governed `BASPersistedOrganDescriptorPayload(descriptor: selectedDescriptor)`, stores/reopens that parent through `BASGovernedArtifactPayloadCodec`, and passes returned `planID` plus governed-parent `selectedProviderDescriptorArtifactID`, `providerBranchPolicyArtifactID`, `stepRuleID`, requested role, and `executionBindingArtifactID` to `BASProviderBranchAllocationRequest`. K3 reopens policy, derives purpose, validates requested-role/rule/causes, and binds the opaque parent ID before allocating an ordinal; Silicon validates plan membership and later reopens/unwraps the receipt-bound parent. No plan/descriptor ID is predicted, no future context enters the binding, and no branch carries a binding or descriptor field.

- [ ] **Step 6: Run binding/elector regressions**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconExecutionBindingTests|BASExecutionPlanElectorTests|BASDecodeStrategyTests|BASLLMInvocationContractTests|BASEBrainSchemaGovernanceRegistryTests'
swift package --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate dump-package >/dev/null
swift test --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK --filter 'QinaoOrganErrorTranslationTests|QinaoOrganRoutingTests'
swift build --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK
~~~

Expected: PASS; unknown devices quarantine, all decode cases round-trip, requests/plans expose one binding root with no parallel identity list, every descriptor construction explicitly selects containment, and the governed descriptor parent's pinned v1 bytes already have the final embedded shape consumed by Task 7.

- [ ] **Step 7: Commit**

~~~bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlanElector.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASDecodeStrategy.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExecutionPlanElectorTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconExecutionBindingTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git diff --cached --check
git commit -m "feat: bind execution plan to one silicon root"
~~~

### Task 4 [W4]: Converge Thermal and Placement Owners; Keep Core AI/NAX Evidence-Only

**Reuse Decision:** E/A — extend BASSystemProbe, its existing BASSystemSnapshot payload, BASThermalTwin, and BASComputeTier; turn the duplicate Metal thermal type into an alias. The authoritative capability snapshot is a versioned BASSystemSnapshot stored through ordinary Artifact Mesh put/read, never a new BASCapabilitySnapshot type or a naked ID. Core AI and NAX only translate observations into the shared evidence shape.

**Files:**
- Modify: BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift
- Modify governed codec owner for current-only snapshot support: BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift
- Modify: BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift
- Modify: BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift
- Modify: BehavioralAISubstrate/Sources/BASLeaseLife/BASThermalTwin.swift
- Modify: BehavioralAISubstrate/Sources/BASLeaseLife/BASComputeTierThermal.swift
- Modify: BehavioralAISubstrate/Sources/BASMetalSubstrate/BASANECapability.swift
- Modify: BehavioralAISubstrate/Sources/BASMetalSubstrate/BASThermalAwareKernelSelectionPolicy.swift
- Modify: BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIVerdictEvidenceComposer.swift
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/metal.h
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/metal.cpp
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/matmul.cpp
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/quantized.cpp
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/scaled_dot_product_attention.cpp
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/include/mlx/c/metal.h
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx-c/mlx/c/metal.cpp
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/include-framework/mlx-c-metal.h
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/GPU+Metal.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSystemProbeTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluHostRuntimeBuilderTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASThermalTwinTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASComputeTierThermalTests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconEvidenceAdapterTests.swift

**Interfaces:**
- Consumes: ProcessInfo thermal/Low Power/OS/runtime signals, signed memory-policy provenance, ordinary BASArtifactStorePort put/read/attestation receipts from the prerequisite plan, existing BASSystemProbe and BASThermalTwin streams, existing Core AI evidence, and MLX dispatch branches.
- Produces: one BASThermalBucket including unknown, one versioned BASSystemSnapshot capability payload with epoch/context-version/expiry/resolved hard cap/policy/provenance, one BASComputeTier physical axis, BASPlacementEvidenceStatus, BASPlacementEvidence, and observation-only Core AI/NAX projections.

- [ ] **Step 1: Write failing taxonomy and no-fake-placement tests**

~~~swift
func testUnknownThermalIsConservativeNotNominal() {
    XCTAssertEqual(BASThermalBucket.thermalSeverity(from: "unknown"), .unknown)
    XCTAssertTrue(BASThermalBucket.unknown.requiresConservativeAdmission)
}

func testPhysicalTierAndEvidenceStatusAreDifferentAxes() {
    let evidence = BASPlacementEvidence(
        requestedTier: .npu,
        physicalTier: nil,
        status: .unknown,
        scope: .operation,
        mechanism: "coreai",
        provenanceArtifactID: nil
    )
    XCTAssertEqual(evidence.requestedTier, .npu)
    XCTAssertNil(evidence.physicalTier)
    XCTAssertEqual(evidence.status, .unknown)
}

func testNAXIsGPUMechanismNotANEPlacement() {
    let evidence = BASPlacementEvidence.nax(
        selectedDelta: 4,
        exclusiveOperationLease: true,
        provenanceArtifactID: fixtureArtifactID("nax-window")
    )
    XCTAssertEqual(evidence.physicalTier, .gpu)
    XCTAssertEqual(evidence.status, .observed)
    XCTAssertEqual(evidence.mechanism, "mlx.metal.nax")
}

func testAvailabilityAloneNeverBecomesObserved() {
    XCTAssertEqual(
        fixtureCoreAIEvidence(apiAvailable: true, importedDeviceTrace: nil).status,
        .unknown
    )
}

func testCapabilitySnapshotUsesSystemSnapshotAndReopensFromArtifactMesh()
    async throws
{
    let store = fixtureArtifactStore()
    let snapshot = try fixtureSystemSnapshot(
        physFootprintBytes: 2_300_000_000
    ).withCapabilityArtifactFields(
        snapshotEpoch: 7,
        contextVersion: 1,
        capturedLogicalTime: 10,
        expiryLogicalTime: 50_000,
        resolvedHardCapBytes: 3_500_000_000,
        hardCapPolicyArtifactID: fixtureArtifactID("memory-policy"),
        hardCapPolicyDigest: "memory-policy-v7",
        hardCapPolicyProofExpiryLogicalTime: 60_000,
        hardCapDerivationVersion: "1.0.0",
        hardCapDerivationSource: .liveFootprintPlusAvailableAdvice,
        lowPowerModeEnabled: false,
        operatingSystemVersion: "27.0",
        operatingSystemBuild: "24A123",
        runtimeIdentifier: "mlx-swift@verified-commit",
        runtimeVendorCommitDigest: "sha256:runtime-commit",
        accessClass: "on-device-authoritative",
        deviceCapabilityFingerprint: "iphone-air:a19pro:verified",
        publicAPIAvailabilityObservations: [
            .init(apiIdentifier: "core-ai", isAvailable: true),
            .init(apiIdentifier: "mlx-metal-nax", isAvailable: true),
        ],
        availableMemoryAdviceBytes: 1_200_000_000,
        placementProjections: [
            BASPlacementEvidence(
                requestedTier: .gpu,
                physicalTier: nil,
                status: .unknown,
                scope: .operation,
                mechanism: "pre-actuation",
                provenanceArtifactID: nil),
        ],
        probeObservationQuality: .observed,
        provenanceArtifactIDs: [fixtureArtifactID("policy")])
    let turnOperationRef = fixtureTurnOperationRef()
    let attemptRefArtifactID = fixtureArtifactID("attempt")
    let attemptScope: BASArtifactScopeBinding =
        .attempt(attemptRefArtifactID)
    let identity = try snapshot.capabilityArtifactIdentityCore(
        scopeBinding: attemptScope,
        logicalEpoch: 7,
        createdLogicalTime: 10)
    let receipt = try await store.put(
        identityCore: identity, headUpdate: nil)
    let reopened = try await store.read(receipt.body.artifactID)
    let decoded = try decodeSystemSnapshot(reopened)
    let resolvedTurnOperationRef = try await fixtureAttemptResolver()
        .turnOperationRef(for: attemptRefArtifactID)

    XCTAssertEqual(reopened.identityCore.scopeBinding, attemptScope)
    XCTAssertEqual(resolvedTurnOperationRef, turnOperationRef)
    XCTAssertEqual(decoded, snapshot)
    XCTAssertEqual(decoded.schemaVersion,
                   BASSystemSnapshot.currentSchemaVersion)
    XCTAssertEqual(decoded.resolvedHardCapBytes, 3_500_000_000)
    XCTAssertEqual(decoded.deviceCapabilityFingerprint,
                   "iphone-air:a19pro:verified")
    XCTAssertEqual(decoded.availableMemoryAdviceBytes, 1_200_000_000)
    XCTAssertEqual(decoded.operatingSystemBuild, "24A123")
    XCTAssertEqual(decoded.runtimeVendorCommitDigest,
                   "sha256:runtime-commit")
    XCTAssertEqual(decoded.probeObservationQuality, .observed)
    XCTAssertEqual(decoded.capabilityPlacementProjections?.first?.status,
                   .unknown)
    XCTAssertEqual(decoded.capabilityProvenanceArtifactIDs,
                   [fixtureArtifactID("policy")])
    XCTAssertFalse(Mirror(reflecting: decoded).children.contains {
        $0.label == "capabilitySnapshotArtifactID"
    })
}

func testGovernedSystemSnapshotRejectsMissingSchemaBeforeFieldAccess() throws {
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(fixtureSystemSnapshot()))
            as? [String: Any])
    object.removeValue(forKey: "schemaVersion")
    let missingVersion = try JSONSerialization.data(withJSONObject: object)

    XCTAssertThrowsError(
        try BASGovernedArtifactPayloadCodec.decodeCurrent(
            BASSystemSnapshot.self,
            from: missingVersion))
    XCTAssertTrue(
        try systemSnapshotDiagnosticMembraneCanInspectButNeverPromote(
            missingVersion))
    XCTAssertEqual(authoritativeSnapshotPutCount(for: missingVersion), 0)
}

func testSystemSnapshotIsRegisteredExactlyOnce() {
    let entries = BASEBrainSchemaGovernanceRegistry.governedSchemas
        .filter { $0.objectID == "BASSystemSnapshot" }
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(
        entries[0].currentVersion,
        BASSystemSnapshot.currentSchemaVersion)
}

func testCapabilitySnapshotRequiresOrdinaryChildAttestation() async throws {
    let fixture = try await storedCapabilitySnapshotFixture()
    let children = try await fixture.store.attestationArtifactIDs(
        targeting: fixture.snapshotArtifactID)
    XCTAssertEqual(children.items, [fixture.attestationArtifactID])
    XCTAssertThrowsError(
        try fixture.verifier.verify(snapshotArtifactID:
            fixture.snapshotArtifactID,
            omittingAttestation: true))
}

func testCapabilitySnapshotRejectsZeroOrMultipleAttestationChildren()
    async
{
    for count in [0, 2] {
        let fixture = await storedCapabilitySnapshotFixture(
            attestationChildCount: count)
        await XCTAssertThrowsErrorAsync {
            try await fixture.verifier.verifyMemoryAdmissionFacts(
                capabilitySnapshotArtifactID:
                    fixture.snapshotArtifactID,
                atLogicalTime: 20)
        }
    }
}

func testCapabilityAttestationTimeMustStayInsideCaptureAndPolicyBounds()
    async
{
    for logicalTime in [9, 50_000, 60_001] {
        let fixture = await storedCapabilitySnapshotFixture(
            attestationLogicalTime: UInt64(logicalTime))
        await XCTAssertThrowsErrorAsync {
            try await fixture.verifier.verifyMemoryAdmissionFacts(
                capabilitySnapshotArtifactID:
                    fixture.snapshotArtifactID,
                atLogicalTime: 20)
        }
    }
}

func testHostPublisherPerformsPolicyProbePutAttestAndReopen()
    async throws
{
    let fixture = capabilityPublisherFixture()
    let published = try await BASChengluHostRuntimeBuilder
        .publishCapabilitySnapshot(
            systemProbe: fixture.probe,
            artifactStore: fixture.store,
            hardCapPolicyArtifactID: fixture.policyArtifactID,
            requestedExpiryLogicalTime: 50_000,
            turnOperationRef: fixture.turnOperationRef,
            attemptScopeBinding:
                .attempt(fixture.attemptRefArtifactID),
            logicalEpoch: 7,
            nowLogicalTime: 10,
            deviceCapabilityFingerprint: fixture.deviceFingerprint,
            operatingSystemVersion: "27.0",
            operatingSystemBuild: "24A123",
            runtimeIdentifier: "mlx-swift",
            runtimeVendorCommitDigest: "sha256:runtime-commit",
            capabilityAccessClass: "on-device-authoritative",
            publicAPIAvailabilityObservations:
                fixture.apiObservations,
            placementProjections: fixture.placementProjections,
            probeObservationQuality: .observed,
            provenanceArtifactIDs: [fixture.policyArtifactID],
            verifySignedPolicy: fixture.verifySignedPolicy,
            verifyAttemptScope: fixture.verifyAttemptScope,
            makeSignedChildAttestation: fixture.makeAttestation)

    let events = await fixture.trace.events
    XCTAssertEqual(events, [
        "attempt.verify", "probe", "policy.verify", "snapshot.put",
        "attestation.put", "snapshot.read", "attestation.read",
    ])
    let reopened = try await fixture.store.read(
        published.snapshotArtifactID)
    let resolvedTurnOperationRef = try await fixture.attemptResolver
        .turnOperationRef(for: fixture.attemptRefArtifactID)
    XCTAssertEqual(
        reopened.identityCore.scopeBinding,
        .attempt(fixture.attemptRefArtifactID))
    XCTAssertEqual(resolvedTurnOperationRef, fixture.turnOperationRef)
    let children = try await fixture.store.attestationArtifactIDs(
        targeting: published.snapshotArtifactID)
    XCTAssertEqual(children.items,
                   [published.derivationAttestationArtifactID])
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconEvidenceAdapterTests|BASSystemProbeTests|BASThermalTwinTests|BASComputeTierThermalTests'
~~~

Expected: FAIL because unknown, shared placement evidence, and the alias do not exist.

- [ ] **Step 3: Put canonical thermal and physical/evidence placement in RuntimeCore**

~~~swift
public enum BASThermalBucket:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    case nominal, fair, serious, critical, unknown

    public var conservativeSeverity: Int {
        switch self {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical, .unknown: 3
        }
    }

    public var requiresConservativeAdmission: Bool {
        self == .unknown || conservativeSeverity >= 2
    }
}

public enum BASComputeTier:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case cpu, gpu, npu
}

public enum BASPlacementEvidenceStatus:
    String, Codable, Sendable, Hashable
{
    case observed, inferred, unknown
}

public enum BASPlacementEvidenceScope:
    String, Codable, Sendable, Hashable
{
    case operation, processWindow, importedDeviceTrace
}

public struct BASPlacementEvidence: Codable, Sendable, Equatable, Hashable {
    public let requestedTier: BASComputeTier?
    public let physicalTier: BASComputeTier?
    public let status: BASPlacementEvidenceStatus
    public let scope: BASPlacementEvidenceScope
    public let mechanism: String
    public let provenanceArtifactID: BASArtifactID?

    public init(
        requestedTier: BASComputeTier?,
        physicalTier: BASComputeTier?,
        status: BASPlacementEvidenceStatus,
        scope: BASPlacementEvidenceScope,
        mechanism: String,
        provenanceArtifactID: BASArtifactID?
    ) {
        self.requestedTier = requestedTier
        self.physicalTier = physicalTier
        self.status = status
        self.scope = scope
        self.mechanism = mechanism
        self.provenanceArtifactID = provenanceArtifactID
    }
}
~~~

Move BASComputeTier from BASComputeTierThermal.swift to this RuntimeCore declaration; do not copy it. Remove "unknown" from knownNonThermalProfileStrings and parse it as .unknown. Replace BASThermalTwin.OSThermalState with a source-compatible typealias to BASThermalBucket, add Low Power as an independent Reading field, make the unsupported/default reader return .unknown, and map unknown to the conservative legacy guard without erasing Reading.osState.

Replace BASSystemSnapshot's nominalizing optional accessor with:

~~~swift
public extension BASSystemSnapshot {
public var thermalBucketOrUnknown: BASThermalBucket {
    thermalBucket ?? .unknown
}

@available(*, deprecated, message: "Use thermalBucketOrUnknown")
public var thermalBucketOrNominal: BASThermalBucket {
    thermalBucketOrUnknown
}
}
~~~

Migrate production callers to thermalBucketOrUnknown. The deprecated spelling remains source-compatible but no longer converts missing evidence to nominal.

`BASSystemSnapshot` is a **first-governed 1.0.0** payload: source evidence must prove that no authoritative Artifact Mesh baseline predates this launch, and no other complete semver or fabricated migration is permitted for this type.

Make `BASSystemSnapshot` conform to `BASSchemaVersioned` in its existing declaration—not in a new payload file. Add nonoptional `schemaVersion` as the first stored property and first initializer parameter defaulting to `currentSchemaVersion`, then include the complete final capability field set below in this first 1.0.0 shape. `PublicAPIAvailabilityObservation` and `ProbeObservationQuality` are low-entropy nested values, not owners or parallel snapshot payloads. Reuse `BASPlacementEvidence` directly. Add these exact owner-facing declarations in `BASSystemProbe.swift`:

~~~swift
public struct BASSystemSnapshot:
    BASSchemaVersioned, Sendable, Equatable, Hashable
{
// Retain every existing probe property here, then add:
public static let currentSchemaVersion = "1.0.0"
public static let capabilitySchemaID =
    "bas.system-snapshot.capability"
public static let capabilityArtifactKind =
    "system-capability-snapshot"
public static let capabilityCanonicalizationVersion =
    "bas-system-snapshot-capability-canonical-v1"
public static let capabilityDerivationAttestationPurpose =
    "bas.system-snapshot.capability-derivation.v1"
public let schemaVersion: String
public let capabilitySnapshotEpoch: UInt64?
public let capabilityContextVersion: UInt64?
public let capabilityCapturedLogicalTime: UInt64?
public let capabilityExpiryLogicalTime: UInt64?
public let resolvedHardCapBytes: UInt64?
public let hardCapPolicyArtifactID: BASArtifactID?
public let hardCapPolicyDigest: String?
public let hardCapPolicyProofExpiryLogicalTime: UInt64?
public let hardCapDerivationVersion: String?
public let hardCapDerivationSource: HardCapDerivationSource?
public let lowPowerModeEnabled: Bool?
public let operatingSystemVersion: String?
public let operatingSystemBuild: String?
public let runtimeIdentifier: String?
public let runtimeVendorCommitDigest: String?
public let capabilityAccessClass: String?
public let deviceCapabilityFingerprint: String?
public let publicAPIAvailabilityObservations:
    [PublicAPIAvailabilityObservation]?
public let availableMemoryAdviceBytes: UInt64?
public let capabilityPlacementProjections: [BASPlacementEvidence]?
public let probeObservationQuality: ProbeObservationQuality?
public let capabilityProvenanceArtifactIDs: [BASArtifactID]?

public struct PublicAPIAvailabilityObservation:
    Codable, Sendable, Equatable, Hashable
{
    public let apiIdentifier: String
    public let isAvailable: Bool

    public init(apiIdentifier: String, isAvailable: Bool) {
        self.apiIdentifier = apiIdentifier
        self.isAvailable = isAvailable
    }
}

public enum ProbeObservationQuality:
    String, Codable, Sendable, Equatable, Hashable
{
    case observed
    case partial
    case unavailable
}

public enum HardCapDerivationSource:
    String, Codable, Sendable, Equatable, Hashable
{
    case liveFootprintPlusAvailableAdvice
    case signedPolicyFallback
}

public func withCapabilityArtifactFields(
    snapshotEpoch: UInt64,
    contextVersion: UInt64,
    capturedLogicalTime: UInt64,
    expiryLogicalTime: UInt64,
    resolvedHardCapBytes: UInt64,
    hardCapPolicyArtifactID: BASArtifactID,
    hardCapPolicyDigest: String,
    hardCapPolicyProofExpiryLogicalTime: UInt64,
    hardCapDerivationVersion: String,
    hardCapDerivationSource: HardCapDerivationSource,
    lowPowerModeEnabled: Bool,
    operatingSystemVersion: String,
    operatingSystemBuild: String,
    runtimeIdentifier: String,
    runtimeVendorCommitDigest: String,
    accessClass: String,
    deviceCapabilityFingerprint: String,
    publicAPIAvailabilityObservations:
        [PublicAPIAvailabilityObservation],
    availableMemoryAdviceBytes: UInt64?,
    placementProjections: [BASPlacementEvidence],
    probeObservationQuality: ProbeObservationQuality,
    provenanceArtifactIDs: [BASArtifactID]
) throws -> BASSystemSnapshot {
    // Exact validation and copy implementation described below.
    fatalError("implementation required")
}

public func capabilityArtifactIdentityCore(
    scopeBinding: BASArtifactScopeBinding,
    logicalEpoch: UInt64,
    createdLogicalTime: UInt64
) throws -> BASArtifactIdentityCore {
    guard logicalEpoch == capabilitySnapshotEpoch,
          createdLogicalTime == capabilityCapturedLogicalTime,
          case .attempt = scopeBinding,
          let hardCapPolicyArtifactID,
          let capabilityProvenanceArtifactIDs
    else {
        throw EncodingError.invalidValue(
            self,
            EncodingError.Context(
                codingPath: [],
                debugDescription:
                    "capability identity metadata mismatch"))
    }
    let payload = try BASGovernedArtifactPayloadCodec
        .canonicalBytes(for: self)
    return BASArtifactIdentityCore(
        canonicalizationVersion:
            Self.capabilityCanonicalizationVersion,
        schemaID: Self.capabilitySchemaID,
        schemaVersion: Self.currentSchemaVersion,
        kind: Self.capabilityArtifactKind,
        parentArtifactIDs: [hardCapPolicyArtifactID],
        producerLayerID: .leaseLife,
        scopeBinding: scopeBinding,
        logicalEpoch: logicalEpoch,
        createdLogicalTime: createdLogicalTime,
        canonicalPayloadBytes: payload,
        payloadLength: UInt64(payload.count),
        confidentialityLabel: "device-capability-confidential",
        provenanceArtifactIDs: capabilityProvenanceArtifactIDs,
        snapshotRootArtifactID: nil)
}

public func capabilityDerivationStatementBytes(
    snapshotArtifactID: BASArtifactID
) throws -> Data {
    // Canonical fixed-order statement coverage described below.
    fatalError("implementation required")
}
}
~~~

Use the ordinary complete `Codable` surface only as the value representation consumed by the central governed codec. Current Artifact identity/put/reopen accepts an explicit `schemaVersion == "1.0.0"` and the complete final fields; missing or future versions fail before any capability field is read. Do not implement a governed missing-schema fallback, custom authoritative `init(from:)`, or 1.0→1.1 migration. If repository evidence finds historical unversioned JSON, one private bounded diagnostic-only membrane in `BASSystemProbe.swift` may decode that exact shape for read-only observability; it is not `BASSchemaVersioned`, is not registered, never enters Artifact identity/ordinary put/admission, and cannot be promoted to current bytes. A source/evidence test inventories prior Artifact puts/registry entries and must stop implementation if it finds an authoritative persisted baseline.

Only withCapabilityArtifactFields may produce the all-present authoritative form. It requires schemaVersion == currentSchemaVersion and rejects zero epoch/version/cap, empty policy digest/derivation version/OS version/OS build/runtime identifier/runtime vendor commit digest/access/device fingerprint/API observations/placement projections/provenance, duplicate API identifiers or provenance IDs, empty policy/provenance commitments, .unavailable probe quality, expiry not later than capturedLogicalTime, or snapshot expiry later than hardCapPolicyProofExpiryLogicalTime. OS version/build and runtime identifier/vendor commit remain separate exact fields; no verifier reconstructs them by splitting or concatenating a free-form string. Public API availability is observation only; true never upgrades a placement projection from unknown to observed. requestedTier, physicalTier, and status remain the existing BASPlacementEvidence axes, so requested/observed/unknown cannot collapse into a Boolean. capabilityArtifactIdentityCore additionally requires createdLogicalTime == capabilityCapturedLogicalTime. The payload contains no BASArtifactID for itself, digest, signature, storage locator, or attestation bytes.

Hard-cap derivation has exactly two fail-closed branches. For liveFootprintPlusAvailableAdvice, physFootprintBytes and availableMemoryAdviceBytes must both be present/nonzero; compute their sum with addingReportingOverflow, require it equals resolvedHardCapBytes exactly, and require it does not exceed the reopened signed BASCapabilityGrant.maxBytes. For signedPolicyFallback, availableMemoryAdviceBytes must be nil and resolvedHardCapBytes must equal that verified grant's maxBytes exactly. No other source string is decodable. In both branches hardCapPolicyArtifactID must be the exact reopened grant receipt ID, hardCapPolicyDigest must equal the canonical grant-policy digest, and the grant child signature/revocation/time/audience/operation/resource bindings must verify. This on-device transient policy requires BASCapabilityGrant.monotonicDeadlineNanos; copy it directly to hardCapPolicyProofExpiryLogicalTime using the existing monotonic clock domain, reject durable-wall-clock-only grants, and require capabilityExpiryLogicalTime no later than it. Advice is recorded evidence and may help derive the signed snapshot once; it is never reread as ledger authority.

Add `BASSystemSnapshot.capabilityArtifactIdentityCore(...)` in `BASSystemProbe.swift`. It requires the all-present form and obtains its canonical payload bytes **only** from `BASGovernedArtifactPayloadCodec.canonicalBytes(for: self)`. It returns a `BASArtifactIdentityCore` with schemaID `bas.system-snapshot.capability`, schemaVersion `BASSystemSnapshot.currentSchemaVersion`, kind `system-capability-snapshot`, the exact verified `.attempt(attemptRefArtifactID)` scope, logical metadata, and ordered capability provenance. It has no raw `turnID`/`branchID` parameter or field. The composition root calls ordinary `BASArtifactStorePort.put(identityCore:headUpdate:nil)`, takes `capabilitySnapshotArtifactID` only from the receipt, stores the child attestation through the same ordinary path/scope, and later reopens with `read`. The Task 6 verifier calls `BASGovernedArtifactPayloadCodec.decodeCurrent(BASSystemSnapshot.self, from: record.canonicalPayloadBytes)` before any field access, then re-encodes and requires exact record payload/identity equality. It accepts only explicit current 1.0.0, complete fields, exact Attempt/root binding, exact child attestation, and matching fresh thermal/Low Power/access/OS/runtime facts. `BASSystemProbe` remains the live fact owner; Artifact Mesh remains identity/store owner; neither gains a parallel registry.

Do not implement `canonicalCapabilityPayloadBytes` or any second payload serializer. Before central encoding, validate unique raw-UTF8 ordering for public API observations and canonical semantic ordering for placement/provenance arrays; the Contracts codec alone frames the complete 1.0.0 payload. `capabilityDerivationStatementBytes` may remain a private attestation-statement framing function: it length-prefixes the snapshot Artifact ID storage scalar, identity metadata, the **exact governed-codec payload bytes**, hard-cap policy/proof facts, derivation source, epochs, cap, capture/expiry, and attestation purpose. It cannot encode a competing snapshot payload or feed Artifact identity through another path. The child attestation digest covers exactly that statement.

On reopen, verify the record envelope's canonicalizationVersion, schemaID, schemaVersion, kind, parent policy ID, producerLayerID == .leaseLife, exact `.attempt` scope binding and its resolution to the same typed `BASTurnOperationRef`, confidentiality label, ordered provenance, and nil snapshotRootArtifactID. Then `decodeCurrent`, re-encode through the same codec, and require exact payload bytes/length plus logicalEpoch/capture-time equality before reading capability authority. Require exactly one attestation artifact targeting the snapshot. Zero or more than one child fails closed. Its purpose, target, identical Attempt scope, policy lineage, statement digest, proof suite/key epoch/custody, proof bytes, and logical-time bounds must verify. No latest-child selection is allowed.

Extend the existing BASChengluHostRuntimeBuilder composition root with one stateless per-turn publisher; do not add an actor, registry, cache, receipt type, or store:

~~~swift
public extension BASChengluHostRuntimeBuilder {
public static func publishCapabilitySnapshot(
    systemProbe: BASSystemProbe,
    artifactStore: any BASArtifactStorePort,
    hardCapPolicyArtifactID: BASArtifactID,
    requestedExpiryLogicalTime: UInt64,
    turnOperationRef: BASTurnOperationRef,
    attemptScopeBinding: BASArtifactScopeBinding,
    logicalEpoch: UInt64,
    nowLogicalTime: UInt64,
    deviceCapabilityFingerprint: String,
    operatingSystemVersion: String,
    operatingSystemBuild: String,
    runtimeIdentifier: String,
    runtimeVendorCommitDigest: String,
    capabilityAccessClass: String,
    publicAPIAvailabilityObservations:
        [BASSystemSnapshot.PublicAPIAvailabilityObservation],
    placementProjections: [BASPlacementEvidence],
    probeObservationQuality:
        BASSystemSnapshot.ProbeObservationQuality,
    provenanceArtifactIDs: [BASArtifactID],
    verifySignedPolicy: @escaping @Sendable (
        BASArtifactID, UInt64
    ) async throws -> BASCapabilityGrant,
    verifyAttemptScope: @escaping @Sendable (
        BASTurnOperationRef, BASArtifactScopeBinding
    ) async throws -> Void,
    makeSignedChildAttestation: @escaping @Sendable (
        BASArtifactID, String, Data, UInt64
    ) async throws -> BASArtifactAttestationPayload
) async throws -> (
    snapshotArtifactID: BASArtifactID,
    derivationAttestationArtifactID: BASArtifactID
) {
    try await verifyAttemptScope(
        turnOperationRef, attemptScopeBinding)
    let live = await systemProbe.probe()
    try validateExactSystemProjection(
        live,
        operatingSystemVersion: operatingSystemVersion,
        operatingSystemBuild: operatingSystemBuild)
    let policy = try await verifySignedPolicy(
        hardCapPolicyArtifactID, nowLogicalTime)
    let proofExpiry = try requiredMonotonicDeadline(policy)
    let derivation = try deriveHardCap(
        snapshot: live, verifiedPolicy: policy)
    let expiry = min(requestedExpiryLogicalTime, proofExpiry)
    let snapshot = try live.withCapabilityArtifactFields(
        snapshotEpoch: logicalEpoch,
        contextVersion: 1,
        capturedLogicalTime: nowLogicalTime,
        expiryLogicalTime: expiry,
        resolvedHardCapBytes: derivation.bytes,
        hardCapPolicyArtifactID: hardCapPolicyArtifactID,
        hardCapPolicyDigest: try canonicalPolicyDigest(policy),
        hardCapPolicyProofExpiryLogicalTime: proofExpiry,
        hardCapDerivationVersion: "1.0.0",
        hardCapDerivationSource: derivation.source,
        lowPowerModeEnabled:
            try requiredLowPowerObservation(live),
        operatingSystemVersion: operatingSystemVersion,
        operatingSystemBuild: operatingSystemBuild,
        runtimeIdentifier: runtimeIdentifier,
        runtimeVendorCommitDigest: runtimeVendorCommitDigest,
        accessClass: capabilityAccessClass,
        deviceCapabilityFingerprint: deviceCapabilityFingerprint,
        publicAPIAvailabilityObservations:
            publicAPIAvailabilityObservations,
        availableMemoryAdviceBytes:
            live.availableMemoryAdviceBytes,
        placementProjections: placementProjections,
        probeObservationQuality: probeObservationQuality,
        provenanceArtifactIDs: provenanceArtifactIDs)
    let snapshotIdentity = try snapshot.capabilityArtifactIdentityCore(
        scopeBinding: attemptScopeBinding,
        logicalEpoch: logicalEpoch,
        createdLogicalTime: nowLogicalTime)
    let snapshotReceipt = try await artifactStore.put(
        identityCore: snapshotIdentity, headUpdate: nil)
    let snapshotID = snapshotReceipt.body.artifactID
    let statement = try snapshot.capabilityDerivationStatementBytes(
        snapshotArtifactID: snapshotID)
    let attestation = try await makeSignedChildAttestation(
        snapshotID,
        BASSystemSnapshot.capabilityDerivationAttestationPurpose,
        statement,
        nowLogicalTime)
    let attestationIdentity = try attestationIdentityCore(
        attestation,
        scopeBinding: attemptScopeBinding,
        logicalEpoch: logicalEpoch,
        createdLogicalTime: nowLogicalTime)
    let attestationReceipt = try await artifactStore.put(
        identityCore: attestationIdentity, headUpdate: nil)
    let snapshotRecord = try await artifactStore.read(snapshotID)
    let attestationRecord = try await artifactStore.read(
        attestationReceipt.body.artifactID)
    let children = try await artifactStore.attestationArtifactIDs(
        targeting: snapshotID)
    try verifyPublishedCapabilitySnapshot(
        snapshotRecord: snapshotRecord,
        attestationRecord: attestationRecord,
        exactChildren: children,
        verifiedPolicy: policy,
        nowLogicalTime: nowLogicalTime)
    return (
        snapshotArtifactID: snapshotID,
        derivationAttestationArtifactID:
            attestationReceipt.body.artifactID)
}
}
~~~

The production body first verifies that `attemptScopeBinding` is exactly `.attempt` and that its Attempt artifact resolves through K3 to the supplied typed `turnOperationRef`; it never accepts or locally derives a raw legacy ID. It then awaits systemProbe.probe(), including one iOS os_proc_available_memory observation added to that existing probe owner. It exact-compares the publisher's OS version/build and runtime identifier/vendor commit inputs with the canonical probe plus certified backend-profile projection; mismatch fails rather than parsing a combined string. It then reopens and verifies the signed BASCapabilityGrant through verifySignedPolicy, derives the cap using the two branches above, computes the canonical grant-policy digest, bounds expiry by the verified policy proof, and calls withCapabilityArtifactFields. It creates the fully populated scope-bound identity core, performs the ordinary snapshot put, builds the exact statement bytes from the returned snapshot ID, obtains a signed BASArtifactAttestationPayload whose target/purpose/time exactly match, creates its ordinary Artifact Mesh identity core with the identical scope binding, and performs the ordinary attestation put. Finally it reopens both records, calls attestationArtifactIDs(targeting:), applies all record/payload/proof/time checks above, and only then returns the two ordinary receipt IDs. Both closure-based and Core ML host wiring call this same publisher for each bound turn; they do not capture a startup-era snapshot. Task 6 receives only snapshotArtifactID as the admission root and discovers the attestation from the store.

All helper spellings used by publishCapabilitySnapshot are private static functions in the same BASChengluHostRuntimeBuilder file. deriveHardCap returns only a `(bytes: UInt64, source: BASSystemSnapshot.HardCapDerivationSource)` tuple; the other helpers validate or canonically translate existing values. None is a protocol, actor, registry, cache, policy owner, or alternate store. provenanceArtifactIDs must contain hardCapPolicyArtifactID and the certified runtime/profile proof IDs in exact semantic order; the Task 6 verifier reopens those proofs and exact-compares operatingSystemBuild and runtimeVendorCommitDigest before returning any admission facts.

Extend BASEBrainSchemaGovernanceRegistry in place with exactly one entry:

~~~swift
entry(
    "BASSystemSnapshot",
    versionedType: BASSystemSnapshot.self,
    tests: ["schema.BASSystemSnapshot.current",
            "schema.BASSystemSnapshot.backward_v1",
            "schema.BASSystemSnapshot.future_rejection"]
)
~~~

After the prerequisite Contracts plan, Task 7 W1 value-contract receipt, and Tasks 2–3 are green, derive the Task-4 entry baseline `N` from the exact committed governed-object-ID fixture; never copy a repository-era numeric count. Task 4 adds exactly `BASSystemSnapshot`, so assert the complete registry ID set equals `postTask3ExpectedObjectIDs ∪ {"BASSystemSnapshot"}` and `governedSchemas.count == postTask3ExpectedObjectIDs.count + 1`. Also assert `entry(for: "BASSystemSnapshot")?.currentVersion == BASSystemSnapshot.currentSchemaVersion`. Do not register a `CapabilitySnapshot` name. The fixture enumerates every prerequisite ID, including Contracts objects, `BASStateABI`, Task 7 W1's governed descriptor parent, and Task 3's four BASOrgan execution payloads. The `backward_v1` test pins the first/current v1 fixture; it is not a migration. Add current codec round-trip, missing/future rejection before capability access, cross-target default-init, exact-one entry/test IDs, and the no-prior-authoritative-baseline evidence test.

In BASANECapability.swift replace the duplicate enum with:

~~~swift
public typealias BASCapabilityThermalSnapshot = BASThermalBucket
~~~

Update all exhaustive switches. Remove BASComputeRouter's coolest-below-floor fallback: when no fully observed tier is above minHeadroom it returns nil, so critical or missing/unknown evidence is never converted into a physical placement choice.

- [ ] **Step 4: Add observation-only NAX counters and Core AI projection**

Add process-global relaxed atomics in vendor metal.cpp, declarations in metal.h, and one C snapshot bridge:

~~~cpp
struct NAXDispatchSnapshot {
  uint64_t eligible;
  uint64_t selected;
  uint64_t fallback;
};

void record_nax_dispatch(bool eligible, bool selected) noexcept {
  if (!eligible) return;
  g_nax_eligible.fetch_add(1, std::memory_order_relaxed);
  (selected ? g_nax_selected : g_nax_fallback)
      .fetch_add(1, std::memory_order_relaxed);
}
~~~

Call record_nax_dispatch at the existing matmul, quantized, and attention selection branches only. Do not alter predicates, return targets, kernel names, generated kernels, or math. Expose a monotonic GPU.NAXDispatchSnapshot through the existing C/framework/Swift bridge.

Map a selected delta to physicalTier .gpu and mechanism mlx.metal.nax. It is observed only when an exclusive operation lease proves one in-flight MLX operation; otherwise it is inferred/processWindow. Zero selected delta remains unknown. Extend BASCoreAIVerdictEvidenceComposer so API availability/requested compute records requestedTier only; physical observed requires an imported device-trace artifact. Neither adapter may create a profile, lease, fallback edge, or production result.

Add the projection on the existing BASPlacementEvidence owner and use it from Task 6:

~~~swift
public extension BASPlacementEvidence {
public static func nax(
    selectedDelta: UInt64,
    exclusiveOperationLease: Bool,
    provenanceArtifactID: BASArtifactID?
) -> BASPlacementEvidence {
    guard selectedDelta > 0 else {
        return BASPlacementEvidence(
            requestedTier: .gpu,
            physicalTier: nil,
            status: .unknown,
            scope: exclusiveOperationLease ? .operation : .processWindow,
            mechanism: "mlx.metal.nax",
            provenanceArtifactID: provenanceArtifactID)
    }
    return BASPlacementEvidence(
        requestedTier: .gpu,
        physicalTier: .gpu,
        status: exclusiveOperationLease ? .observed : .inferred,
        scope: exclusiveOperationLease ? .operation : .processWindow,
        mechanism: "mlx.metal.nax",
        provenanceArtifactID: provenanceArtifactID)
}
}
~~~

- [ ] **Step 5: Run GREEN and vendor-diff guard**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconEvidenceAdapterTests|BASSystemProbeTests|BASEBrainSchemaGovernanceRegistryTests|BASChengluHostRuntimeBuilderTests|BASArtifactMeshTests|BASArtifactStoreTests|BASThermalTwinTests|BASThermalTwinNotificationTests|BASComputeTierThermalTests|BASCoreAIShadowComparisonTests|BASCoreAIMigrationVerdictTests'
git diff --check -- BehavioralAISubstrate/Vendor/mlx-swift
! rg -n 'struct BASCapabilitySnapshot|enum BASCapabilitySnapshot' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources
rg -q 'bas\.system-snapshot\.capability' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift
rg -q 'BASSchemaVersioned' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift
rg -q 'hardCapPolicyArtifactID' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift
rg -q 'capabilityDerivationAttestationPurpose' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift
test "$(rg -n '"BASSystemSnapshot"' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift | wc -l | tr -d ' ')" = 1
rg -q 'postTask3ExpectedObjectIDs.count + 1' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
rg -q 'publishCapabilitySnapshot' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift
~~~

Expected: tests PASS; the complete dynamically derived post-Task-3 registry set gains exactly one `BASSystemSnapshot` entry and no other delta; governed missing-schema/future bytes fail before field access, any private unversioned diagnostic membrane remains non-promotable, and Artifact Mesh put/read reopens the byte-equal first/current 1.0.0 `BASSystemSnapshot` plus its exact child attestation through the central codec. The no-prior-authoritative-baseline test is green; all capability-owner guards exit 0; git diff --check is silent; and no generated kernel or selection predicate changes appear in the vendor diff.

- [ ] **Step 6: Commit**

~~~bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift BehavioralAISubstrate/Sources/BASLeaseLife/BASThermalTwin.swift BehavioralAISubstrate/Sources/BASLeaseLife/BASComputeTierThermal.swift BehavioralAISubstrate/Sources/BASMetalSubstrate/BASANECapability.swift BehavioralAISubstrate/Sources/BASMetalSubstrate/BASThermalAwareKernelSelectionPolicy.swift BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIVerdictEvidenceComposer.swift BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/metal.h BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/metal.cpp BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/matmul.cpp BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/quantized.cpp BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/scaled_dot_product_attention.cpp BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/include/mlx/c/metal.h BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/mlx-c/mlx/c/metal.cpp BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/include-framework/mlx-c-metal.h BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/GPU+Metal.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSystemProbeTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChengluHostRuntimeBuilderTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASThermalTwinTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASComputeTierThermalTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconEvidenceAdapterTests.swift
git commit -m "refactor: converge thermal and placement evidence owners"
~~~

### Task 5 [W4]: Add the One Generic Process Memory Ledger and Typed Activation CAS

**Reuse Decision:** M — existing MLX memory models, OS probes, pressure gates, and BASLeaseLifeCoordinator remain estimators, observations, and composition seams. None owns cross-framework reservations spanning neural, retrieval, verification, publication, and Artifact Mesh I/O, so add one generic actor under BASLeaseLife and inject the same instance through the coordinator. The actor owns one reservation map; it does not add a neural-only ledger, ordinary-active map, heavy-active map, or lease authority.

Task-local M gate for `silicon-execution-spine:Task 5`: the first source-create delta stages the ledger/checker/checker-test, adds the exact production-path permission and evidence, and atomically changes `approved_missing → converging`; later deltas append evidence. Remove conflicts only with proof. Set `implemented` only after all declared paths/evidence/tests/gates exist and `current_conflicts == []`; roll back source, permission, evidence, conflicts/projections, and status together.

**Files:**
- Modify: docs/superpowers/specs/qinao-owner-ledger-v1.json
- Modify: scripts/check_qinao_owner_ledger.py
- Modify: scripts/test_check_qinao_owner_ledger.py
- Create: BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift
- Modify: BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProcessMemoryLedgerTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLeaseLifeCoordinatorTests.swift

**Interfaces:**
- Consumes: typed workRootArtifactID, K1-owned BASMemoryWorkPhase, BASMemoryCategory, BASMemoryActivationClass, an opaque verified BASMemoryAdmissionContext, current process physical footprint, optional os_proc_available_memory advice, and backend estimates.
- Produces: exact BASMemoryReservationToken and BASMemoryActivationToken values, ordinary activation overlap, at-most-one heavy activation, same-byte/context transfer, monotonic ledger epochs, and one BASProcessMemorySnapshot projected from the sole reservation map.

**Production Create Proof — BASProcessMemoryLedger.swift:**

1. Repository search: rg -n "memory.*reservation|heavy.*owner|jetsam|Memory.snapshot|available_memory" BehavioralAISubstrate/Sources finds BASMLXMemoryModel/Budget, process probes, pressure gates, BASLeaseLifeCoordinator, and MLX-local wired coordination, but no application-wide reservation actor.
2. Public/upstream search: os_proc_available_memory is advisory and framework allocators are framework-local; vendored WiredMemoryManager is the MLX wired-memory owner, not a cross-framework application authority.
3. Missing invariant: every category must reserve against the same verified capability-snapshot-derived context; ordinary work may overlap without consuming the global heavy slot, while heavy activation is atomically limited to one.
4. Extension/composition failure: estimators and probes cannot mutate a global reservation set; putting the data into BASLeaseLifeCoordinator would mix composition with admission state, while one ledger composed by it preserves both owners.
5. Authority/state/storage/failure: the actor exclusively owns one in-memory reservation map and epoch. Pending and active state are fields of entries in that map; heavyOwner is a derived snapshot projection, never another mutable property. It has no durable store. Context/version/expiry/cap, token, deadline, activation, and arithmetic conflicts fail closed.
6. Dependency direction: BASLeaseLife depends only on BASRuntimeCore and imports no MLX/Core AI module. Adapters translate their estimates into requests.
7. Compatibility/retirement: existing MLX admission and pressure/decode gates remain compatibility clients for one release, but cannot grant authority; retire their independent admission booleans after callers consume ledger receipts.
8. Duplicate-owner tests: every category and work phase completes a full lifecycle; ordinary activations overlap; heavy activations exclude only each other; cancel/start, transfer/restart ABA, duplicate completion, cap arithmetic, opaque-context enforcement, coordinator identity, and source scans pin exactly one ledger actor/map and no copied wired manager.

- [ ] **Step 1: Write failing generic-context, ordinary/heavy, exact-token, and lifecycle tests**

~~~swift
func testReservationsUseHardCapAndNotAvailableMemoryAdvice() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 100)
    let context = fixtureMemoryAdmissionContext(hardCapBytes: 1_000)
    let request = fixtureMemoryRequest(
        phase: .retrieval,
        activationClass: .ordinary,
        residentBytes: 300,
        maxTransientBytes: 200)
    let admitted = try await ledger.reserve(
        request,
        admissionContext: context,
        observation: .init(
            physicalFootprintBytes: 350,
            availableMemoryAdviceBytes: 0),
        nowLogicalTime: 10)
    XCTAssertEqual(admitted.reservedBytes, 500)

    _ = try await ledger.cancelPending(admitted.token)
    await XCTAssertThrowsErrorAsync {
        try await ledger.reserve(
            request,
            admissionContext: fixtureMemoryAdmissionContext(
                hardCapBytes: 900),
            observation: .init(
                physicalFootprintBytes: 350,
                availableMemoryAdviceBytes: 8_000_000_000),
            nowLogicalTime: 10)
    }
}

func testActivationRequiresTheExactReverifiedAdmissionContext() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let original = fixtureMemoryAdmissionContext(
        contextVersion: 7, hardCapBytes: 2_000)
    let changed = fixtureMemoryAdmissionContext(
        contextVersion: 8, hardCapBytes: 2_000)
    let reservation = try await ledger.reserve(
        fixtureMemoryRequest(
            phase: .verification,
            activationClass: .ordinary),
        admissionContext: original,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 1)

    await XCTAssertThrowsErrorAsync {
        try await ledger.compareAndStart(
            reservation.token,
            revalidatedContext: changed,
            observation: fixtureMemoryObservation(),
            nowLogicalTime: 2)
    }
    let snapshot = await ledger.snapshot()
    XCTAssertEqual(snapshot.reservations.count, 1)
    XCTAssertTrue(snapshot.activeReservations.isEmpty)
}

func testEveryCategoryAndWorkPhaseCompletesOneLifecycle() async throws {
    XCTAssertEqual(BASMemoryCategory.allCases.count, 12)
    XCTAssertEqual(BASMemoryWorkPhase.allCases.count, 8)
    var seenPhases = Set<BASMemoryWorkPhase>()

    for (index, category) in BASMemoryCategory.allCases.enumerated() {
        let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
        let phase = BASMemoryWorkPhase.allCases[
            index % BASMemoryWorkPhase.allCases.count]
        seenPhases.insert(phase)
        let context = fixtureMemoryAdmissionContext()
        let reservation = try await ledger.reserve(
            fixtureMemoryRequest(
                ownerID: "work-\(index)",
                phase: phase,
                category: category,
                activationClass: .ordinary),
            admissionContext: context,
            observation: fixtureMemoryObservation(),
            nowLogicalTime: 1)
        let activation = try await ledger.compareAndStart(
            reservation.token,
            revalidatedContext: context,
            observation: fixtureMemoryObservation(),
            nowLogicalTime: 2)
        _ = try await ledger.complete(
            activation, actualPeakBytes: 700)
        let snapshot = await ledger.snapshot()
        XCTAssertTrue(snapshot.reservations.isEmpty)
    }
    XCTAssertEqual(seenPhases, Set(BASMemoryWorkPhase.allCases))
}

func testOrdinaryActivationsOverlapAndDoNotOccupyHeavySlot() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let context = fixtureMemoryAdmissionContext()
    let retrieval = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "retrieval",
            phase: .retrieval,
            activationClass: .ordinary),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 1)
    let verifier = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "verifier",
            phase: .verification,
            activationClass: .ordinary),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 2)
    _ = try await ledger.compareAndStart(
        retrieval.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 3)
    _ = try await ledger.compareAndStart(
        verifier.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 4)

    let snapshot = await ledger.snapshot()
    XCTAssertEqual(snapshot.activeReservations.count, 2)
    XCTAssertNil(snapshot.heavyOwner)
}

func testHeavyActivationsExcludeEachOtherButAllowOrdinaryOverlap() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let context = fixtureMemoryAdmissionContext()
    let firstHeavy = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "decode-a",
            phase: .neuralDecode,
            activationClass: .heavy),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 1)
    let secondHeavy = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "decode-b",
            phase: .neuralDecode,
            activationClass: .heavy),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 2)
    let publication = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "publish",
            phase: .responsePublication,
            activationClass: .ordinary),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 3)

    let heavy = try await ledger.compareAndStart(
        firstHeavy.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 4)
    _ = try await ledger.compareAndStart(
        publication.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 5)
    await XCTAssertThrowsErrorAsync {
        try await ledger.compareAndStart(
            secondHeavy.token,
            revalidatedContext: context,
            observation: fixtureMemoryObservation(),
            nowLogicalTime: 6)
    }
    let heavySnapshot = await ledger.snapshot()
    XCTAssertEqual(heavySnapshot.heavyOwner, heavy)
}

func testTransferAndRestartRejectOldActivationABA() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let context = fixtureMemoryAdmissionContext()
    let reservation = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "load",
            phase: .neuralLoad,
            activationClass: .heavy),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 1)
    let first = try await ledger.compareAndStart(
        reservation.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 2)
    let transferred = try await ledger.transfer(
        first,
        toOwnerID: "prefill",
        toPhase: .neuralPrefill,
        toCategory: .otherMaximumTransient,
        deadlineLogicalTime: 100,
        nowLogicalTime: 3)
    let second = try await ledger.compareAndStart(
        transferred.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 4)

    XCTAssertEqual(transferred.reservedBytes, reservation.reservedBytes)
    XCTAssertEqual(
        transferred.request.workRootArtifactID,
        reservation.request.workRootArtifactID)
    XCTAssertNotEqual(first.activationEpoch, second.activationEpoch)
    await XCTAssertThrowsErrorAsync {
        try await ledger.complete(first, actualPeakBytes: 700)
    }
    _ = try await ledger.complete(second, actualPeakBytes: 700)
    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
}

func testCancelAndDuplicateCompleteLeaveNoReservationLeak() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let context = fixtureMemoryAdmissionContext()
    let pending = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "artifact-io",
            phase: .artifactIO,
            activationClass: .ordinary),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 1)
    let cancelled = try await ledger.cancelPending(pending.token)
    XCTAssertTrue(cancelled)

    let active = try await ledger.reserve(
        fixtureMemoryRequest(
            ownerID: "spool",
            phase: .responsePublication,
            activationClass: .ordinary),
        admissionContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 2)
    let token = try await ledger.compareAndStart(
        active.token,
        revalidatedContext: context,
        observation: fixtureMemoryObservation(),
        nowLogicalTime: 3)
    let firstCompletion = try await ledger.complete(
        token, actualPeakBytes: 700)
    XCTAssertNotNil(firstCompletion)
    let duplicateCompletion = try await ledger.complete(
        token, actualPeakBytes: 800)
    XCTAssertNil(duplicateCompletion)
    let finalSnapshot = await ledger.snapshot()
    XCTAssertTrue(finalSnapshot.reservations.isEmpty)
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_PROCESS_MEMORY_LEDGER_CANDIDATE_MANIFEST:?set the ephemeral resource.process-memory-ledger candidate manifest path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" \
  --candidate-manifest "$BAS_PROCESS_MEMORY_LEDGER_CANDIDATE_MANIFEST"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASProcessMemoryLedgerTests|BASLeaseLifeCoordinatorTests'
~~~

Expected: FAIL because BASProcessMemoryLedger and coordinator injection do not exist.

- [ ] **Step 3: Implement the ledger as the sole mutable owner**

Add these exact public values and actor implementation; use addingReportingOverflow for every byte sum and return arithmeticOverflow on overflow:

~~~swift
import Foundation
import BASRuntimeCore

public enum BASMemoryCategory:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case trunkWeightsAndMappedAssets
    case draftMTPWeights
    case neuralStateCache
    case prefixSessionCache
    case mlxPoolAndCommandBuffer
    case coreMLFunctionAndIntermediate
    case coreAIFunctionAndIntermediate
    case metalResource
    case retrievalIndexAndLaneResult
    case verifierAuxiliary
    case responseSpoolAndArtifactBuffer
    case otherMaximumTransient
}

public enum BASMemoryWorkPhase:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case neuralLoad
    case neuralPrefill
    case neuralCache
    case neuralDecode
    case retrieval
    case verification
    case responsePublication
    case artifactIO
}

public enum BASMemoryActivationClass:
    String, Codable, Sendable, Hashable
{
    case ordinary
    case heavy
}

public struct BASVerifiedMemoryAdmissionFacts:
    Codable, Sendable, Equatable
{
    public let capabilitySnapshotArtifactID: BASArtifactID
    public let capabilitySnapshotEpoch: UInt64
    public let contextVersion: UInt64
    public let hardCapBytes: UInt64
    public let expiryLogicalTime: UInt64
    public let hardCapPolicyArtifactID: BASArtifactID
    public let hardCapPolicyProofExpiryLogicalTime: UInt64
    public let policyDigest: String
    public let derivationVersion: String
    public let derivationSource:
        BASSystemSnapshot.HardCapDerivationSource
    public let derivationAttestationArtifactID: BASArtifactID

    public init(
        capabilitySnapshotArtifactID: BASArtifactID,
        capabilitySnapshotEpoch: UInt64,
        contextVersion: UInt64,
        hardCapBytes: UInt64,
        expiryLogicalTime: UInt64,
        hardCapPolicyArtifactID: BASArtifactID,
        hardCapPolicyProofExpiryLogicalTime: UInt64,
        policyDigest: String,
        derivationVersion: String,
        derivationSource:
            BASSystemSnapshot.HardCapDerivationSource,
        derivationAttestationArtifactID: BASArtifactID
    ) {
        self.capabilitySnapshotArtifactID = capabilitySnapshotArtifactID
        self.capabilitySnapshotEpoch = capabilitySnapshotEpoch
        self.contextVersion = contextVersion
        self.hardCapBytes = hardCapBytes
        self.expiryLogicalTime = expiryLogicalTime
        self.hardCapPolicyArtifactID = hardCapPolicyArtifactID
        self.hardCapPolicyProofExpiryLogicalTime =
            hardCapPolicyProofExpiryLogicalTime
        self.policyDigest = policyDigest
        self.derivationVersion = derivationVersion
        self.derivationSource = derivationSource
        self.derivationAttestationArtifactID =
            derivationAttestationArtifactID
    }
}

public struct BASMemoryAdmissionContext: Sendable, Equatable {
    let verifiedFacts: BASVerifiedMemoryAdmissionFacts

    public var capabilitySnapshotArtifactID: BASArtifactID {
        verifiedFacts.capabilitySnapshotArtifactID
    }
    public var capabilitySnapshotEpoch: UInt64 {
        verifiedFacts.capabilitySnapshotEpoch
    }
    public var contextVersion: UInt64 {
        verifiedFacts.contextVersion
    }
    public var expiryLogicalTime: UInt64 {
        verifiedFacts.expiryLogicalTime
    }

    // Deliberately BASLeaseLife-internal. Only a verifier-backed gateway
    // in this target may turn verified facts into admission authority.
    init(verifiedFacts: BASVerifiedMemoryAdmissionFacts) {
        self.verifiedFacts = verifiedFacts
    }
}

public enum BASMemoryAdmissionContextError: Error, Equatable {
    case snapshotMismatch
    case invalidProjection
    case expired
}

extension BASVerifiedMemoryAdmissionFacts {
    func validate(
        expectedCapabilitySnapshotArtifactID: BASArtifactID,
        atLogicalTime nowLogicalTime: UInt64
    ) throws {
        guard capabilitySnapshotArtifactID
                == expectedCapabilitySnapshotArtifactID
        else {
            throw BASMemoryAdmissionContextError.snapshotMismatch
        }
        guard capabilitySnapshotEpoch > 0,
              contextVersion > 0,
              hardCapBytes > 0,
              expiryLogicalTime
                <= hardCapPolicyProofExpiryLogicalTime,
              !policyDigest.isEmpty,
              !derivationVersion.isEmpty,
              !capabilitySnapshotArtifactID.commitmentHex.isEmpty,
              !hardCapPolicyArtifactID.commitmentHex.isEmpty,
              !derivationAttestationArtifactID.commitmentHex.isEmpty
        else {
            throw BASMemoryAdmissionContextError.invalidProjection
        }
        guard nowLogicalTime < expiryLogicalTime else {
            throw BASMemoryAdmissionContextError.expired
        }
    }
}

public struct BASMemoryAdmissionObservation:
    Codable, Sendable, Equatable
{
    public let physicalFootprintBytes: UInt64
    public let availableMemoryAdviceBytes: UInt64?

    public init(
        physicalFootprintBytes: UInt64,
        availableMemoryAdviceBytes: UInt64?
    ) {
        self.physicalFootprintBytes = physicalFootprintBytes
        self.availableMemoryAdviceBytes = availableMemoryAdviceBytes
    }
}

public struct BASMemoryReservationRequest: Codable, Sendable, Equatable {
    public let workRootArtifactID: BASArtifactID
    public let ownerID: String
    public let phase: BASMemoryWorkPhase
    public let category: BASMemoryCategory
    public let activationClass: BASMemoryActivationClass
    public let residentBytes: UInt64
    public let maxTransientBytes: UInt64
    public let deadlineLogicalTime: UInt64

    public init(
        workRootArtifactID: BASArtifactID,
        ownerID: String,
        phase: BASMemoryWorkPhase,
        category: BASMemoryCategory,
        activationClass: BASMemoryActivationClass,
        residentBytes: UInt64,
        maxTransientBytes: UInt64,
        deadlineLogicalTime: UInt64
    ) {
        self.workRootArtifactID = workRootArtifactID
        self.ownerID = ownerID
        self.phase = phase
        self.category = category
        self.activationClass = activationClass
        self.residentBytes = residentBytes
        self.maxTransientBytes = maxTransientBytes
        self.deadlineLogicalTime = deadlineLogicalTime
    }
}

public struct BASMemoryReservationToken:
    Codable, Sendable, Equatable, Hashable
{
    public let reservationID: UUID
    public let workRootArtifactID: BASArtifactID
    public let capabilitySnapshotArtifactID: BASArtifactID
    public let capabilitySnapshotEpoch: UInt64
    public let contextVersion: UInt64
    public let reservationVersion: UInt64

    public init(
        reservationID: UUID,
        workRootArtifactID: BASArtifactID,
        capabilitySnapshotArtifactID: BASArtifactID,
        capabilitySnapshotEpoch: UInt64,
        contextVersion: UInt64,
        reservationVersion: UInt64
    ) {
        self.reservationID = reservationID
        self.workRootArtifactID = workRootArtifactID
        self.capabilitySnapshotArtifactID =
            capabilitySnapshotArtifactID
        self.capabilitySnapshotEpoch = capabilitySnapshotEpoch
        self.contextVersion = contextVersion
        self.reservationVersion = reservationVersion
    }
}

public struct BASMemoryActivationToken:
    Codable, Sendable, Equatable, Hashable
{
    public let reservationToken: BASMemoryReservationToken
    public let ownerID: String
    public let phase: BASMemoryWorkPhase
    public let activationClass: BASMemoryActivationClass
    public let activationEpoch: UInt64
    public let startedLogicalTime: UInt64

    public init(
        reservationToken: BASMemoryReservationToken,
        ownerID: String,
        phase: BASMemoryWorkPhase,
        activationClass: BASMemoryActivationClass,
        activationEpoch: UInt64,
        startedLogicalTime: UInt64
    ) {
        self.reservationToken = reservationToken
        self.ownerID = ownerID
        self.phase = phase
        self.activationClass = activationClass
        self.activationEpoch = activationEpoch
        self.startedLogicalTime = startedLogicalTime
    }
}

public struct BASMemoryReservation: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let request: BASMemoryReservationRequest
    public let admissionContext: BASMemoryAdmissionContext
    public let reservedBytes: UInt64
    public let reservationVersion: UInt64
    public let activation: BASMemoryActivationToken?

    public var token: BASMemoryReservationToken {
        BASMemoryReservationToken(
            reservationID: id,
            workRootArtifactID: request.workRootArtifactID,
            capabilitySnapshotArtifactID:
                admissionContext.capabilitySnapshotArtifactID,
            capabilitySnapshotEpoch:
                admissionContext.capabilitySnapshotEpoch,
            contextVersion: admissionContext.contextVersion,
            reservationVersion: reservationVersion)
    }

    public init(
        id: UUID,
        request: BASMemoryReservationRequest,
        admissionContext: BASMemoryAdmissionContext,
        reservedBytes: UInt64,
        reservationVersion: UInt64,
        activation: BASMemoryActivationToken?
    ) {
        self.id = id
        self.request = request
        self.admissionContext = admissionContext
        self.reservedBytes = reservedBytes
        self.reservationVersion = reservationVersion
        self.activation = activation
    }
}

public struct BASProcessMemorySnapshot: Sendable, Equatable {
    public let epoch: UInt64
    public let reservations: [BASMemoryReservation]
    public let activeReservations: [BASMemoryActivationToken]
    public let heavyOwner: BASMemoryActivationToken?
    public let lastObservation: BASMemoryAdmissionObservation?
    public let lastActualPeakBytes: UInt64?

    public init(
        epoch: UInt64,
        reservations: [BASMemoryReservation],
        activeReservations: [BASMemoryActivationToken],
        heavyOwner: BASMemoryActivationToken?,
        lastObservation: BASMemoryAdmissionObservation?,
        lastActualPeakBytes: UInt64?
    ) {
        self.epoch = epoch
        self.reservations = reservations
        self.activeReservations = activeReservations
        self.heavyOwner = heavyOwner
        self.lastObservation = lastObservation
        self.lastActualPeakBytes = lastActualPeakBytes
    }
}

public struct BASMemoryReleaseOutcome: Sendable, Equatable {
    public let reservation: BASMemoryReservation
    public let activation: BASMemoryActivationToken
    public let ledgerEpoch: UInt64
    public let actualPeakBytes: UInt64?

    public init(
        reservation: BASMemoryReservation,
        activation: BASMemoryActivationToken,
        ledgerEpoch: UInt64,
        actualPeakBytes: UInt64?
    ) {
        self.reservation = reservation
        self.activation = activation
        self.ledgerEpoch = ledgerEpoch
        self.actualPeakBytes = actualPeakBytes
    }
}

public enum BASProcessMemoryLedgerError: Error, Equatable {
    case invalidAdmissionContext
    case admissionContextMismatch
    case invalidRequest
    case expired
    case arithmeticOverflow
    case capExceeded(projectedBytes: UInt64, hardCapBytes: UInt64)
    case reservationNotFound
    case reservationAlreadyActive
    case reservationNotActive
    case tokenMismatch
    case heavyOwnerBusy(ownerID: String)
}

public actor BASProcessMemoryLedger {
    public static let productionSafetyMarginBytes: UInt64 =
        512 * 1_024 * 1_024
    public static let processShared = BASProcessMemoryLedger(
        safetyMarginBytes: productionSafetyMarginBytes)

    private let safetyMarginBytes: UInt64
    private var epoch: UInt64 = 0
    private var reservations: [UUID: BASMemoryReservation] = [:]
    private var lastObservation: BASMemoryAdmissionObservation?
    private var lastActualPeakBytes: UInt64?

    public init(safetyMarginBytes: UInt64) {
        self.safetyMarginBytes = safetyMarginBytes
    }

    public func reserve(
        _ request: BASMemoryReservationRequest,
        admissionContext: BASMemoryAdmissionContext,
        observation: BASMemoryAdmissionObservation,
        nowLogicalTime: UInt64
    ) throws -> BASMemoryReservation {
        try validate(admissionContext, atLogicalTime: nowLogicalTime)
        guard nowLogicalTime < request.deadlineLogicalTime else {
            throw BASProcessMemoryLedgerError.expired
        }
        guard request.deadlineLogicalTime
                <= admissionContext.expiryLogicalTime,
              !request.ownerID.isEmpty,
              !request.workRootArtifactID.commitmentHex.isEmpty
        else {
            throw BASProcessMemoryLedgerError.invalidRequest
        }
        let reservedBytes = try checkedSum([
            request.residentBytes, request.maxTransientBytes,
        ])
        let outstanding = try checkedSum(
            reservations.values.map(\.reservedBytes))
        let projected = try checkedSum([
            observation.physicalFootprintBytes,
            outstanding,
            reservedBytes,
            safetyMarginBytes,
        ])
        guard projected <= admissionContext.verifiedFacts.hardCapBytes else {
            throw BASProcessMemoryLedgerError.capExceeded(
                projectedBytes: projected,
                hardCapBytes:
                    admissionContext.verifiedFacts.hardCapBytes)
        }
        let nextEpoch = try incrementedEpoch()
        let reservation = BASMemoryReservation(
            id: UUID(),
            request: request,
            admissionContext: admissionContext,
            reservedBytes: reservedBytes,
            reservationVersion: nextEpoch,
            activation: nil)
        reservations[reservation.id] = reservation
        lastObservation = observation
        epoch = nextEpoch
        return reservation
    }

    public func compareAndStart(
        _ expectedReservationToken: BASMemoryReservationToken,
        revalidatedContext: BASMemoryAdmissionContext,
        observation: BASMemoryAdmissionObservation,
        nowLogicalTime: UInt64
    ) throws -> BASMemoryActivationToken {
        try validate(revalidatedContext, atLogicalTime: nowLogicalTime)
        guard let reservation =
                reservations[expectedReservationToken.reservationID]
        else {
            throw BASProcessMemoryLedgerError.reservationNotFound
        }
        guard reservation.token == expectedReservationToken else {
            throw BASProcessMemoryLedgerError.tokenMismatch
        }
        guard reservation.activation == nil else {
            throw BASProcessMemoryLedgerError.reservationAlreadyActive
        }
        guard reservation.admissionContext == revalidatedContext else {
            throw BASProcessMemoryLedgerError.admissionContextMismatch
        }
        guard nowLogicalTime < reservation.request.deadlineLogicalTime else {
            throw BASProcessMemoryLedgerError.expired
        }
        let outstanding = try checkedSum(
            reservations.values.map(\.reservedBytes))
        let projected = try checkedSum([
            observation.physicalFootprintBytes,
            outstanding,
            safetyMarginBytes,
        ])
        guard projected <= revalidatedContext.verifiedFacts.hardCapBytes else {
            throw BASProcessMemoryLedgerError.capExceeded(
                projectedBytes: projected,
                hardCapBytes:
                    revalidatedContext.verifiedFacts.hardCapBytes)
        }
        if reservation.request.activationClass == .heavy,
           let existing = reservations.values
            .compactMap(\.activation)
            .first(where: { $0.activationClass == .heavy })
        {
            throw BASProcessMemoryLedgerError.heavyOwnerBusy(
                ownerID: existing.ownerID)
        }
        let nextEpoch = try incrementedEpoch()
        let activation = BASMemoryActivationToken(
            reservationToken: reservation.token,
            ownerID: reservation.request.ownerID,
            phase: reservation.request.phase,
            activationClass: reservation.request.activationClass,
            activationEpoch: nextEpoch,
            startedLogicalTime: nowLogicalTime)
        reservations[reservation.id] = BASMemoryReservation(
            id: reservation.id,
            request: reservation.request,
            admissionContext: reservation.admissionContext,
            reservedBytes: reservation.reservedBytes,
            reservationVersion: reservation.reservationVersion,
            activation: activation)
        lastObservation = observation
        epoch = nextEpoch
        return activation
    }

    public func transfer(
        _ expectedActivation: BASMemoryActivationToken,
        toOwnerID: String,
        toPhase: BASMemoryWorkPhase,
        toCategory: BASMemoryCategory,
        deadlineLogicalTime: UInt64,
        nowLogicalTime: UInt64
    ) throws -> BASMemoryReservation {
        guard nowLogicalTime < deadlineLogicalTime else {
            throw BASProcessMemoryLedgerError.expired
        }
        guard !toOwnerID.isEmpty else {
            throw BASProcessMemoryLedgerError.invalidRequest
        }
        let reservationID =
            expectedActivation.reservationToken.reservationID
        guard let current = reservations[reservationID] else {
            throw BASProcessMemoryLedgerError.reservationNotFound
        }
        guard let active = current.activation else {
            throw BASProcessMemoryLedgerError.reservationNotActive
        }
        guard active == expectedActivation,
              current.token == expectedActivation.reservationToken
        else {
            throw BASProcessMemoryLedgerError.tokenMismatch
        }
        try validate(
            current.admissionContext,
            atLogicalTime: nowLogicalTime)
        guard deadlineLogicalTime
                <= current.admissionContext.expiryLogicalTime
        else {
            throw BASProcessMemoryLedgerError.invalidRequest
        }
        let request = BASMemoryReservationRequest(
            workRootArtifactID: current.request.workRootArtifactID,
            ownerID: toOwnerID,
            phase: toPhase,
            category: toCategory,
            activationClass: current.request.activationClass,
            residentBytes: current.request.residentBytes,
            maxTransientBytes: current.request.maxTransientBytes,
            deadlineLogicalTime: deadlineLogicalTime)
        let nextEpoch = try incrementedEpoch()
        let transferred = BASMemoryReservation(
            id: reservationID,
            request: request,
            admissionContext: current.admissionContext,
            reservedBytes: current.reservedBytes,
            reservationVersion: nextEpoch,
            activation: nil)
        reservations[reservationID] = transferred
        epoch = nextEpoch
        return transferred
    }

    @discardableResult
    public func cancelPending(
        _ expectedToken: BASMemoryReservationToken
    ) throws -> Bool {
        guard let reservation =
                reservations[expectedToken.reservationID]
        else {
            return false
        }
        guard reservation.token == expectedToken else {
            throw BASProcessMemoryLedgerError.tokenMismatch
        }
        guard reservation.activation == nil else {
            throw BASProcessMemoryLedgerError.reservationAlreadyActive
        }
        let nextEpoch = try incrementedEpoch()
        reservations.removeValue(forKey: expectedToken.reservationID)
        epoch = nextEpoch
        return true
    }

    @discardableResult
    public func complete(
        _ expectedActivation: BASMemoryActivationToken,
        actualPeakBytes: UInt64?
    ) throws -> BASMemoryReleaseOutcome? {
        let reservationID =
            expectedActivation.reservationToken.reservationID
        guard let reservation = reservations[reservationID] else {
            return nil
        }
        guard let activation = reservation.activation else {
            throw BASProcessMemoryLedgerError.reservationNotActive
        }
        guard activation == expectedActivation,
              reservation.token == expectedActivation.reservationToken
        else {
            throw BASProcessMemoryLedgerError.tokenMismatch
        }
        let nextEpoch = try incrementedEpoch()
        reservations.removeValue(forKey: reservationID)
        if let actualPeakBytes { lastActualPeakBytes = actualPeakBytes }
        epoch = nextEpoch
        return BASMemoryReleaseOutcome(
            reservation: reservation,
            activation: activation,
            ledgerEpoch: nextEpoch,
            actualPeakBytes: actualPeakBytes)
    }

    public func snapshot() -> BASProcessMemorySnapshot {
        let ordered = reservations.values.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
        let active = ordered.compactMap(\.activation)
        return BASProcessMemorySnapshot(
            epoch: epoch,
            reservations: ordered,
            activeReservations: active,
            heavyOwner: active.first(where: {
                $0.activationClass == .heavy
            }),
            lastObservation: lastObservation,
            lastActualPeakBytes: lastActualPeakBytes)
    }

    private func validate(
        _ context: BASMemoryAdmissionContext,
        atLogicalTime nowLogicalTime: UInt64
    ) throws {
        let facts = context.verifiedFacts
        do {
            try facts.validate(
                expectedCapabilitySnapshotArtifactID:
                    facts.capabilitySnapshotArtifactID,
                atLogicalTime: nowLogicalTime)
        } catch {
            throw BASProcessMemoryLedgerError.invalidAdmissionContext
        }
    }

    private func checkedSum(_ values: [UInt64]) throws -> UInt64 {
        try values.reduce(0) { partial, value in
            let (sum, overflow) = partial.addingReportingOverflow(value)
            guard !overflow else {
                throw BASProcessMemoryLedgerError.arithmeticOverflow
            }
            return sum
        }
    }

    private func incrementedEpoch() throws -> UInt64 {
        let (next, overflow) = epoch.addingReportingOverflow(1)
        guard !overflow else {
            throw BASProcessMemoryLedgerError.arithmeticOverflow
        }
        return next
    }
}
~~~

reserve computes exactly physicalFootprintBytes + sum(all outstanding reservedBytes) + residentBytes + maxTransientBytes + safetyMarginBytes and compares it only with the immutable hardCapBytes hidden inside BASMemoryAdmissionContext. availableMemoryAdviceBytes is copied to lastObservation for evidence and never participates in authority. The context is an in-memory, non-Codable projection created only from the one verified BASSystemSnapshot capability artifact plus its exact child attestation; it has no artifact ID, store row, or second root of its own. It binds the snapshot artifact ID, positive snapshot epoch/context version, hard-cap policy artifact/digest, derivation version/source, attestation, expiry, and resolved cap, and cannot be initialized by an adapter. The request deadline may not outlive the context. reserve rejects every invalid input before mutation, increments epoch once, and returns residentBytes + maxTransientBytes as reservedBytes.

compareAndStart checks the exact BASMemoryReservationToken rather than a process-global epoch, so unrelated reservations cannot revoke a valid offer. It requires byte-for-byte equality with a freshly verified BASMemoryAdmissionContext, recomputes live footprint + all reservations + safety against that same context's cap, and updates only the matching entry in reservations. Ordinary activation never occupies or checks the heavy slot. Heavy activation scans the active fields in that same map and fails if one heavy token already exists. heavyOwner and activeReservations are snapshot projections, never stored actor properties. A repeated start is rejected and activationEpoch makes completion/transfer ABA-safe.

transfer is the only nonterminal active-to-pending handoff. It compare-and-swaps the exact BASMemoryActivationToken, preserves workRootArtifactID, admission context, reservation ID, activation class, resident/transient bytes, and total reserved bytes, and changes only owner/phase/category/deadline plus reservationVersion. cancelPending removes only an exact inactive BASMemoryReservationToken. complete is the sole terminal active-release CAS: it checks and removes the exact activation token and returns nil for duplicate completion. Every fallible epoch increment is computed before mutation. There is exactly one reservations dictionary and no heavy-owner property, continuation, waiter, queue, hysteresis, offer map, active map, or timer in this actor.

- [ ] **Step 4: Inject one shared ledger through the existing coordinator**

Add the ledger reference to the existing coordinator declaration and replace its initializer/default factory with these exact signatures. Existing callers remain source-compatible through the process-shared default; tests inject an isolated ledger explicitly. No coordinator method mirrors reservation, owner, offer, or active state:

~~~swift
public actor BASLeaseLifeCoordinator {
    private let lung: BASLungStateAccumulator
    private let thermal: BASThermalTwin
    private let scheduler: BASBreathScheduler
    private let memoryLedger: BASProcessMemoryLedger

    public init(
        lung: BASLungStateAccumulator,
        thermal: BASThermalTwin,
        scheduler: BASBreathScheduler,
        memoryLedger: BASProcessMemoryLedger = .processShared
    ) {
        self.lung = lung
        self.thermal = thermal
        self.scheduler = scheduler
        self.memoryLedger = memoryLedger
    }

    public static func makeDefault(
        timeConstantSeconds: Double = 180,
        thermalReader: @escaping BASThermalTwin.Reader =
            BASThermalTwin.defaultReader,
        clock: @escaping @Sendable () -> Date = { Date() },
        memoryLedger: BASProcessMemoryLedger = .processShared
    ) -> BASLeaseLifeCoordinator {
        BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: timeConstantSeconds, clock: clock),
            thermal: BASThermalTwin(reader: thermalReader, clock: clock),
            scheduler: BASBreathScheduler(clock: clock),
            memoryLedger: memoryLedger)
    }

    public func memoryLedgerActor() -> BASProcessMemoryLedger {
        memoryLedger
    }
}
~~~

The snippet shows only the stored properties, initializer, factory, and accessor that replace their current counterparts; retain the coordinator's existing lifecycle methods verbatim. BASProcessMemoryLedger.processShared is the sole production instance and uses the named production safety margin. Add a test using === on the actor references returned by two accessor calls and another proving two default coordinators resolve the same processShared actor; isolated tests continue to inject their own ledger.

~~~swift
func testCoordinatorReturnsOneInjectedLedgerIdentity() async {
    let injected = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let coordinator = BASLeaseLifeCoordinator(
        lung: BASLungStateAccumulator(timeConstantSeconds: 180),
        thermal: BASThermalTwin(),
        scheduler: BASBreathScheduler(),
        memoryLedger: injected)
    let first = await coordinator.memoryLedgerActor()
    let second = await coordinator.memoryLedgerActor()
    XCTAssertTrue(first === injected)
    XCTAssertTrue(first === second)
}

func testDefaultCoordinatorsUseTheOneProcessLedger() async {
    let first = await BASLeaseLifeCoordinator.makeDefault()
        .memoryLedgerActor()
    let second = await BASLeaseLifeCoordinator.makeDefault()
        .memoryLedgerActor()
    XCTAssertTrue(first === BASProcessMemoryLedger.processShared)
    XCTAssertTrue(first === second)
}
~~~

- [ ] **Step 5: Run focused and regression GREEN**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASProcessMemoryLedgerTests|BASLeaseLifeCoordinatorTests|BASBudgetFrameLiveThermalTests|BASMLXMemoryBudgetTests|BASMLXMemoryModelTests'
test "$(rg -n '^public actor BASProcessMemoryLedger' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
rg -q '^    public static let processShared = BASProcessMemoryLedger' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift
~~~

Expected: tests PASS; both shell guards exit 0; stale exact tokens, changed admission contexts, and a second heavy activation are refused; ordinary activations overlap without occupying the heavy projection; unrelated reservation mutations do not revoke valid offers; cancellation returns to zero reservations; and available-memory advice cannot grant admission.

- [ ] **Step 6: Commit**

~~~bash
git add docs/superpowers/specs/qinao-owner-ledger-v1.json scripts/check_qinao_owner_ledger.py scripts/test_check_qinao_owner_ledger.py BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProcessMemoryLedgerTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLeaseLifeCoordinatorTests.swift
git commit -m "feat: add process memory reservation owner"
~~~

### Task 6 [W4]: Extend the Existing Lease Coordinator with a Stateless Signed-Binding Gateway and Thin MLX Ticket Actuator

**Reuse Decision:** E/A — BASProcessMemoryLedger from Task 5 already owns every pending/ordinary-active/heavy-active reservation, exact activation CAS, and idempotent retirement. Extend BASLeaseLifeCoordinator with one generic stateless BASMemoryAdmissionContextGateway and one neural-specific stateless BASSiliconLeaseGateway over that same ledger. The MLX side remains an adapter around the existing BASExecutionPlanElector, BASDecodeLanePolicy/BASDecodeStrategy, _execute bodies, prompt/MTP paths, ChatSession pool, FIFO gates, and AsyncStream pump. Do not create a second lease authority, context artifact, offer registry, active registry, or replacement decode/session mechanism.

**Files:**
- Modify: BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift
- Modify: BehavioralAISubstrate/Package.swift
- Modify: BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Streaming.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+PromptLookup.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+SessionPersist.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/BASMLXMemoryModel.swift
- Modify: BehavioralAISubstrate/Sources/BASMLXAdapter/BASMLXMemoryBudget.swift
- Modify: BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/WiredMemory.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952RealMLXOnDeviceTests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconLeaseGatewayTests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMLXUnifiedLeaseTests.swift
- Create: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconOwnerUniquenessTests.swift
- Modify: BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconExecutionBindingTests.swift

**Interfaces:**
- Consumes: one executionBindingArtifactID, the one persisted BASSystemSnapshot capabilitySnapshotArtifactID, authorization context artifact, phase, plan projection digest, logical time, the exact verified signed profile/snapshot/child-attestation projection, BASProcessMemoryLedger, and WiredMemoryManager.shared.
- Produces: a generic verifier-backed BASMemoryAdmissionContextGateway, BASVerifiedSiliconAdmission containing BASVerifiedMemoryAdmissionFacts rather than a naked cap, a reservation-backed transient offer, one exact BASMemoryActivationToken-backed active lease, `BASResult<BASSiliconLeaseCompletionBody>` with signed phase/mapped work phase/activation/placement evidence, and one thin MLX wrapper. Context, offer, and active values are immutable projections; they own no mutable truth.

**Extension/Adapter Proof — no production Create:**

1. Repository search: rg -n "compareAndStart|lease.*authority|signed.*profile|executionBindingArtifactID" BehavioralAISubstrate/Sources finds BASLeaseLifeCoordinator, the Task 5 ledger, the plan elector, and decode/session gates. The missing work is orchestration and translation, not another state owner.
2. Ownership allocation: BASExecutionPlan.BindingVerificationAdapter owns only Artifact Mesh translation/verification; BASMemoryAdmissionContextGateway retains one verifier reference; BASSiliconLeaseGateway retains one verifier and one ledger reference; BASProcessMemoryLedger remains the sole pending/active/completed CAS truth.
3. Failure semantics: snapshot/artifact verification, expiry, epoch/context-version, exact neural phase mapping, cancellation, and profile drift fail closed. A pending reservation is cancelled only by exact BASMemoryReservationToken; an active lease is released only by exact BASMemoryActivationToken; duplicate completion returns nil. Every gateway-owned cleanup is awaited, and a cleanup throw preserves both the primary and cleanup diagnostics instead of being swallowed.
4. Dependency direction: BASLeaseLife depends only on RuntimeCore plus its verification port and does not import BASOrgan, MLX, Core ML, or Core AI. BASOrgan implements the port; BASMLXAdapter consumes the gateway.
5. Compatibility/retirement: legacy unbound adapter calls remain explicit compatibility mode for one release. Production-required mode rejects a missing admission request; after all orchestrator callers use bound overloads, remove compatibility mode and independent admission booleans.
6. Duplicate-owner guards: source scans forbid BASSiliconLeaseAuthority, BASMemoryAdmissionContext persistence or a second artifact ID, private offer/active/context dictionaries, a second ledger, copied WiredMemoryManager, and backend-local production grants.

- [ ] **Step 1: Write failing exact-verification and atomic-start tests**

~~~swift
func testGenericContextGatewayBindsTheOneVerifiedSnapshot() async throws {
    let expected = fixtureArtifactID("capability-snapshot")
    let gateway = BASMemoryAdmissionContextGateway(
        verifier: ConstantMemoryFactsVerifier(
            fixtureVerifiedMemoryFacts(
                capabilitySnapshotArtifactID: expected)))
    let context = try await gateway.resolve(
        capabilitySnapshotArtifactID: expected,
        nowLogicalTime: 10)

    XCTAssertEqual(context.capabilitySnapshotArtifactID, expected)
    XCTAssertEqual(context.capabilitySnapshotEpoch, 7)
    XCTAssertEqual(context.contextVersion, 1)
}

func testGenericContextGatewayRejectsReturnedSnapshotMismatch() async {
    let gateway = BASMemoryAdmissionContextGateway(
        verifier: ConstantMemoryFactsVerifier(
            fixtureVerifiedMemoryFacts(
                capabilitySnapshotArtifactID:
                    fixtureArtifactID("wrong-snapshot"))))
    await XCTAssertThrowsErrorAsync {
        try await gateway.resolve(
            capabilitySnapshotArtifactID:
                fixtureArtifactID("expected-snapshot"),
            nowLogicalTime: 10)
    }
}

func testPersistedSnapshotAttestationVerifierGatewayAndLedgerIntegrate()
    async throws
{
    let fixture = try await publishedCapabilityIntegrationFixture()
    let contextGateway = BASMemoryAdmissionContextGateway(
        verifier: fixture.bindingVerificationAdapter)
    let context = try await contextGateway.resolve(
        capabilitySnapshotArtifactID:
            fixture.snapshotArtifactID,
        nowLogicalTime: 20)
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let reservation = try await ledger.reserve(
        BASMemoryReservationRequest(
            workRootArtifactID: fixture.retrievalWorkRootArtifactID,
            ownerID: "retrieval-lane",
            phase: .retrieval,
            category: .retrievalIndexAndLaneResult,
            activationClass: .ordinary,
            residentBytes: 100,
            maxTransientBytes: 50,
            deadlineLogicalTime: 100),
        admissionContext: context,
        observation: .init(
            physicalFootprintBytes: 1_000,
            availableMemoryAdviceBytes: 1_200_000_000),
        nowLogicalTime: 20)
    let freshContext = try await contextGateway.resolve(
        capabilitySnapshotArtifactID:
            fixture.snapshotArtifactID,
        nowLogicalTime: 21)
    let activation = try await ledger.compareAndStart(
        reservation.token,
        revalidatedContext: freshContext,
        observation: .init(
            physicalFootprintBytes: 1_000,
            availableMemoryAdviceBytes: 1_200_000_000),
        nowLogicalTime: 21)
    _ = try await ledger.complete(
        activation, actualPeakBytes: 1_100)

    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
    XCTAssertNil(snapshot.heavyOwner)
}

func testEverySiliconPhaseMapsExactlyToOneHeavyMemoryPhase() async throws {
    let pairs: [(BASSiliconExecutionPhase, BASMemoryWorkPhase)] = [
        (.load, .neuralLoad),
        (.prefill, .neuralPrefill),
        (.cache, .neuralCache),
        (.decode, .neuralDecode),
    ]
    for (siliconPhase, memoryPhase) in pairs {
        let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
        let gateway = BASSiliconLeaseGateway(
            verifier: ConstantVerifier(
                fixtureVerifiedAdmission(phase: siliconPhase)),
            ledger: ledger)
        let offer = try await gateway.offer(
            fixtureAdmissionRequest(phase: siliconPhase),
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 10)
        XCTAssertEqual(offer.reservation.request.phase, memoryPhase)
        XCTAssertEqual(
            offer.reservation.request.activationClass, .heavy)
        _ = try await gateway.cancel(offer)
    }
}

func testOfferRejectsAnyExactProjectionMismatch() async {
    for mutation in AdmissionMutation.allCases {
        let gateway = await fixtureCoordinator().siliconLeaseGateway(
            verifier: fixtureVerifier(mutation: mutation))
        await XCTAssertThrowsErrorAsync {
            try await gateway.offer(
                fixtureAdmissionRequest(),
                physicalFootprintBytes: 100,
                availableMemoryAdviceBytes: 1_000,
                nowLogicalTime: 10)
        }
    }
}

func testStartRevalidatesAndRejectsProfileDrift() async throws {
    let verifier = SequencedVerifier([
        fixtureVerifiedAdmission(profile: "profile-a"),
        fixtureVerifiedAdmission(profile: "profile-b"),
    ])
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let gateway = BASSiliconLeaseGateway(
        verifier: verifier, ledger: ledger)
    let offer = try await gateway.offer(
        fixtureAdmissionRequest(),
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 10)
    await XCTAssertThrowsErrorAsync {
        try await gateway.compareAndStart(
            offer,
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 11)
    }
    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
}

func testGatewayCleanupFailurePreservesPrimaryAndCleanupDiagnostics()
    async throws
{
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let gateway = BASSiliconLeaseGateway(
        verifier: SequencedVerifier([
            fixtureVerifiedAdmission(profile: "profile-a"),
            fixtureVerifiedAdmission(profile: "profile-b"),
        ]),
        ledger: ledger)
    let offer = try await gateway.offer(
        fixtureAdmissionRequest(),
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 10)
    let mismatchedVersion =
        offer.reservation.token.reservationVersion &+ 1
    let corruptedOffer = BASSiliconLeaseOffer(
        request: offer.request,
        verified: offer.verified,
        admissionContext: offer.admissionContext,
        reservation: BASMemoryReservation(
            id: offer.reservation.id,
            request: offer.reservation.request,
            admissionContext: offer.reservation.admissionContext,
            reservedBytes: offer.reservation.reservedBytes,
            reservationVersion: mismatchedVersion,
            activation: nil))

    do {
        _ = try await gateway.compareAndStart(
            corruptedOffer,
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 11)
        XCTFail("profile drift plus token mismatch must fail")
    } catch let error as BASSiliconLeaseGatewayError {
        guard case let .cleanupFailed(primary, cleanup) = error else {
            return XCTFail("unexpected error: \(error)")
        }
        XCTAssertTrue(primary.contains("exactProjectionMismatch"))
        XCTAssertTrue(cleanup.contains("tokenMismatch"))
    }

    let cancelled = try await gateway.cancel(offer)
    XCTAssertTrue(cancelled)
    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
}

func testConcurrentDoubleStartProducesExactlyOneActiveLease() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let gateway = BASSiliconLeaseGateway(
        verifier: ConstantVerifier(fixtureVerifiedAdmission()),
        ledger: ledger)
    let offer = try await gateway.offer(
        fixtureAdmissionRequest(),
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 10)

    let left = Task {
        try await gateway.compareAndStart(
            offer,
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 11)
    }
    let right = Task {
        try await gateway.compareAndStart(
            offer,
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 11)
    }
    let leftResult = await left.result
    let rightResult = await right.result
    let leases = [leftResult, rightResult].compactMap { try? $0.get() }

    XCTAssertEqual(leases.count, 1)
    let activeSnapshot = await ledger.snapshot()
    XCTAssertEqual(activeSnapshot.heavyOwner, leases[0].activation)
    _ = try await gateway.finish(
        leases[0],
        placementEvidence: .nax(
            selectedDelta: 1,
            exclusiveOperationLease: true,
            provenanceArtifactID: nil),
        actualPeakBytes: 700)
}

actor StartRaceVerifier: BASSiliconBindingVerificationPort {
    private let projection: BASVerifiedSiliconAdmission
    private var callCount = 0
    private var secondEntered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeSecond: CheckedContinuation<Void, Never>?

    init(_ projection: BASVerifiedSiliconAdmission) {
        self.projection = projection
    }

    func verify(
        executionBindingArtifactID: BASArtifactID,
        capabilitySnapshotArtifactID: BASArtifactID,
        authorizationContextArtifactID: BASArtifactID,
        phase: BASSiliconExecutionPhase,
        planProjectionDigest: String,
        atLogicalTime: UInt64
    ) async throws -> BASVerifiedSiliconAdmission {
        callCount += 1
        if callCount == 2 {
            secondEntered = true
            enteredWaiters.forEach { $0.resume() }
            enteredWaiters.removeAll()
            await withCheckedContinuation { resumeSecond = $0 }
        }
        return projection
    }

    func waitUntilSecondVerifyEntered() async {
        if secondEntered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func resumeSecondVerify() {
        resumeSecond?.resume()
        resumeSecond = nil
    }
}

func testPendingCancelWinsAgainstSuspendedStartWithoutLeak() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let verifier = StartRaceVerifier(fixtureVerifiedAdmission())
    let gateway = BASSiliconLeaseGateway(
        verifier: verifier, ledger: ledger)
    let offer = try await gateway.offer(
        fixtureAdmissionRequest(),
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 10)
    let start = Task {
        try await gateway.compareAndStart(
            offer,
            physicalFootprintBytes: 100,
            availableMemoryAdviceBytes: nil,
            nowLogicalTime: 11)
    }

    await verifier.waitUntilSecondVerifyEntered()
    let cancelled = try await gateway.cancel(offer)
    XCTAssertTrue(cancelled)
    await verifier.resumeSecondVerify()
    if case .success = await start.result {
        XCTFail("cancelled pending reservation must not start")
    }
    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
    XCTAssertNil(snapshot.heavyOwner)
}

func testConcurrentFinishEmitsExactlyOneReceipt() async throws {
    let ledger = BASProcessMemoryLedger(safetyMarginBytes: 0)
    let gateway = BASSiliconLeaseGateway(
        verifier: ConstantVerifier(fixtureVerifiedAdmission()),
        ledger: ledger)
    let offer = try await gateway.offer(
        fixtureAdmissionRequest(),
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 10)
    let lease = try await gateway.compareAndStart(
        offer,
        physicalFootprintBytes: 100,
        availableMemoryAdviceBytes: nil,
        nowLogicalTime: 11)
    let evidence = BASPlacementEvidence.nax(
        selectedDelta: 1,
        exclusiveOperationLease: true,
        provenanceArtifactID: nil)

    let left = Task {
        try await gateway.finish(
            lease, placementEvidence: evidence, actualPeakBytes: 700)
    }
    let right = Task {
        try await gateway.finish(
            lease, placementEvidence: evidence, actualPeakBytes: 700)
    }
    let leftReceipt = try await left.value
    let rightReceipt = try await right.value
    XCTAssertEqual([leftReceipt, rightReceipt].compactMap { $0 }.count, 1)
    let snapshot = await ledger.snapshot()
    XCTAssertTrue(snapshot.reservations.isEmpty)
    XCTAssertNil(snapshot.heavyOwner)
}

func testLeaseAndMLXTicketOrderOnSuccessAndCancellation() async throws {
    let success = try await runInstrumentedMLXTurn(cancel: false)
    XCTAssertEqual(success, [
        "bas.offer", "bas.start", "mlx.start", "mlx.end", "bas.finish",
    ])
    let cancelled = try await runInstrumentedMLXTurn(cancel: true)
    XCTAssertEqual(cancelled, [
        "bas.offer", "bas.start", "mlx.start", "mlx.end", "bas.finish",
    ])
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconLeaseGatewayTests|BASMLXUnifiedLeaseTests|BASSiliconOwnerUniquenessTests'
~~~

Expected: FAIL because the stateless gateway, exact verification port, and unified MLX wrapper do not exist.

- [ ] **Step 3: Implement the exact signed-binding verification seam**

Add these value/protocol declarations beside the existing coordinator in BASLeaseLifeCoordinator.swift. They are immutable contracts; the verification result is a full projection, never a Boolean. Every initializer is explicit because BASOrgan and BASMLXAdapter cross the target boundary:

~~~swift
import Foundation
import BASRuntimeCore

public struct BASSiliconAdmissionRequest: Codable, Sendable, Equatable {
    public let executionBindingArtifactID: BASArtifactID
    public let capabilitySnapshotArtifactID: BASArtifactID
    public let authorizationContextArtifactID: BASArtifactID
    public let phase: BASSiliconExecutionPhase
    public let heavyOwnerID: String
    public let planProjectionDigest: String
    public let deadlineLogicalTime: UInt64

    public init(
        executionBindingArtifactID: BASArtifactID,
        capabilitySnapshotArtifactID: BASArtifactID,
        authorizationContextArtifactID: BASArtifactID,
        phase: BASSiliconExecutionPhase,
        heavyOwnerID: String,
        planProjectionDigest: String,
        deadlineLogicalTime: UInt64
    ) {
        self.executionBindingArtifactID = executionBindingArtifactID
        self.capabilitySnapshotArtifactID = capabilitySnapshotArtifactID
        self.authorizationContextArtifactID = authorizationContextArtifactID
        self.phase = phase
        self.heavyOwnerID = heavyOwnerID
        self.planProjectionDigest = planProjectionDigest
        self.deadlineLogicalTime = deadlineLogicalTime
    }
}

public protocol BASMemoryAdmissionContextVerificationPort: Sendable {
    func verifyMemoryAdmissionFacts(
        capabilitySnapshotArtifactID: BASArtifactID,
        atLogicalTime: UInt64
    ) async throws -> BASVerifiedMemoryAdmissionFacts
}

public struct BASMemoryAdmissionContextGateway: Sendable {
    private let verifier: any BASMemoryAdmissionContextVerificationPort

    public init(
        verifier: any BASMemoryAdmissionContextVerificationPort
    ) {
        self.verifier = verifier
    }

    public func resolve(
        capabilitySnapshotArtifactID: BASArtifactID,
        nowLogicalTime: UInt64
    ) async throws -> BASMemoryAdmissionContext {
        let facts = try await verifier.verifyMemoryAdmissionFacts(
            capabilitySnapshotArtifactID:
                capabilitySnapshotArtifactID,
            atLogicalTime: nowLogicalTime)
        try facts.validate(
            expectedCapabilitySnapshotArtifactID:
                capabilitySnapshotArtifactID,
            atLogicalTime: nowLogicalTime)
        return BASMemoryAdmissionContext(verifiedFacts: facts)
    }
}

public struct BASVerifiedSiliconAdmission: Codable, Sendable, Equatable {
    public let executionBindingArtifactID: BASArtifactID
    public let certifiedProfileArtifactID: BASArtifactID
    public let authorizationContextArtifactID: BASArtifactID
    public let phase: BASSiliconExecutionPhase
    public let planProjectionDigest: String
    public let memoryRequest: BASMemoryReservationRequest
    public let memoryAdmissionFacts: BASVerifiedMemoryAdmissionFacts
    public let requestedTier: BASComputeTier

    public init(
        executionBindingArtifactID: BASArtifactID,
        certifiedProfileArtifactID: BASArtifactID,
        authorizationContextArtifactID: BASArtifactID,
        phase: BASSiliconExecutionPhase,
        planProjectionDigest: String,
        memoryRequest: BASMemoryReservationRequest,
        memoryAdmissionFacts: BASVerifiedMemoryAdmissionFacts,
        requestedTier: BASComputeTier
    ) {
        self.executionBindingArtifactID = executionBindingArtifactID
        self.certifiedProfileArtifactID = certifiedProfileArtifactID
        self.authorizationContextArtifactID = authorizationContextArtifactID
        self.phase = phase
        self.planProjectionDigest = planProjectionDigest
        self.memoryRequest = memoryRequest
        self.memoryAdmissionFacts = memoryAdmissionFacts
        self.requestedTier = requestedTier
    }
}

public protocol BASSiliconBindingVerificationPort: Sendable {
    func verify(
        executionBindingArtifactID: BASArtifactID,
        capabilitySnapshotArtifactID: BASArtifactID,
        authorizationContextArtifactID: BASArtifactID,
        phase: BASSiliconExecutionPhase,
        planProjectionDigest: String,
        atLogicalTime: UInt64
    ) async throws -> BASVerifiedSiliconAdmission
}

public struct BASSiliconLeaseOffer: Sendable, Equatable, Identifiable {
    public let request: BASSiliconAdmissionRequest
    public let verified: BASVerifiedSiliconAdmission
    public let admissionContext: BASMemoryAdmissionContext
    public let reservation: BASMemoryReservation

    public var id: UUID { reservation.id }

    public init(
        request: BASSiliconAdmissionRequest,
        verified: BASVerifiedSiliconAdmission,
        admissionContext: BASMemoryAdmissionContext,
        reservation: BASMemoryReservation
    ) {
        self.request = request
        self.verified = verified
        self.admissionContext = admissionContext
        self.reservation = reservation
    }
}

public struct BASSiliconActiveLease: Sendable, Equatable, Identifiable {
    public let activation: BASMemoryActivationToken
    public let verified: BASVerifiedSiliconAdmission

    public var id: UUID {
        activation.reservationToken.reservationID
    }
    public var executionBindingArtifactID: BASArtifactID {
        verified.executionBindingArtifactID
    }

    public init(
        activation: BASMemoryActivationToken,
        verified: BASVerifiedSiliconAdmission
    ) {
        self.activation = activation
        self.verified = verified
    }
}

public struct BASSiliconLeaseCompletionBody: Codable, Sendable, Equatable, Hashable {
    public let leaseID: UUID
    public let executionBindingArtifactID: BASArtifactID
    public let certifiedProfileArtifactID: BASArtifactID
    public let capabilitySnapshotArtifactID: BASArtifactID
    public let capabilitySnapshotEpoch: UInt64
    public let memoryContextVersion: UInt64
    public let hardCapPolicyArtifactID: BASArtifactID
    public let hardCapPolicyProofExpiryLogicalTime: UInt64
    public let hardCapPolicyDigest: String
    public let hardCapDerivationVersion: String
    public let hardCapDerivationSource:
        BASSystemSnapshot.HardCapDerivationSource
    public let reservationID: UUID
    public let phase: BASSiliconExecutionPhase
    public let memoryWorkPhase: BASMemoryWorkPhase
    public let activationEpoch: UInt64
    public let derivationAttestationArtifactID: BASArtifactID
    public let placementEvidence: BASPlacementEvidence
    public let actualPeakBytes: UInt64?

    public init(
        leaseID: UUID,
        executionBindingArtifactID: BASArtifactID,
        certifiedProfileArtifactID: BASArtifactID,
        capabilitySnapshotArtifactID: BASArtifactID,
        capabilitySnapshotEpoch: UInt64,
        memoryContextVersion: UInt64,
        hardCapPolicyArtifactID: BASArtifactID,
        hardCapPolicyProofExpiryLogicalTime: UInt64,
        hardCapPolicyDigest: String,
        hardCapDerivationVersion: String,
        hardCapDerivationSource:
            BASSystemSnapshot.HardCapDerivationSource,
        reservationID: UUID,
        phase: BASSiliconExecutionPhase,
        memoryWorkPhase: BASMemoryWorkPhase,
        activationEpoch: UInt64,
        derivationAttestationArtifactID: BASArtifactID,
        placementEvidence: BASPlacementEvidence,
        actualPeakBytes: UInt64?
    ) {
        self.leaseID = leaseID
        self.executionBindingArtifactID = executionBindingArtifactID
        self.certifiedProfileArtifactID = certifiedProfileArtifactID
        self.capabilitySnapshotArtifactID = capabilitySnapshotArtifactID
        self.capabilitySnapshotEpoch = capabilitySnapshotEpoch
        self.memoryContextVersion = memoryContextVersion
        self.hardCapPolicyArtifactID = hardCapPolicyArtifactID
        self.hardCapPolicyProofExpiryLogicalTime =
            hardCapPolicyProofExpiryLogicalTime
        self.hardCapPolicyDigest = hardCapPolicyDigest
        self.hardCapDerivationVersion = hardCapDerivationVersion
        self.hardCapDerivationSource = hardCapDerivationSource
        self.reservationID = reservationID
        self.phase = phase
        self.memoryWorkPhase = memoryWorkPhase
        self.activationEpoch = activationEpoch
        self.derivationAttestationArtifactID =
            derivationAttestationArtifactID
        self.placementEvidence = placementEvidence
        self.actualPeakBytes = actualPeakBytes
    }
}

public typealias BASSiliconLeaseCompletionReceipt =
    BASResult<BASSiliconLeaseCompletionBody>

public enum BASSiliconLeaseGatewayError: Error, Equatable {
    case exactProjectionMismatch
    case invalidNeuralPhaseMapping
    case expired
    case cleanupFailed(primary: String, cleanup: String)
}
~~~

Extend the existing BASExecutionPlan.swift owner with one nested BASExecutionPlan.BindingVerificationAdapter conforming to both verification ports. Package.swift adds BASLeaseLife to the existing BASOrgan target as well as to BASMLXAdapter; BASLeaseLife itself still imports only RuntimeCore, so the graph remains acyclic. The adapter reads through BASArtifactStorePort, decodes BASSiliconExecutionBinding, its exact primary profile, the existing BASSystemSnapshot capability payload, authorization context, and ordinary child attestation, checks each Artifact Mesh commitment and expiry, and compares snapshot epoch plus thermal/Low Power/access/OS-version/OS-build/runtime-identifier/runtime-vendor-commit/device-fingerprint/public-API/advice/placement/probe-quality facts with the fresh canonical probe/twin and certified-profile projections. Every comparison uses its dedicated typed field; no free-form split/concatenation is allowed. It copies resolvedHardCapBytes, snapshot/context versions, expiry, policy artifact/digest, derivation version/source, and child-attestation ID into BASVerifiedMemoryAdmissionFacts only after all checks pass. It has no cache, registry, mutable state, backend branch, second snapshot type, or independently stored admission context. Add binding tests that mutate each child ID, payload commitment, signature, snapshot epoch/context version/cap/policy, thermal/Low Power/access/OS version/OS build/runtime identifier/runtime vendor commit/device fingerprint/API availability/advice/placement status/probe quality, phase, plan projection, and expiry independently and require rejection.

The generic gateway accepts only capabilitySnapshotArtifactID and logical time, requires exact returned-ID equality plus all verified-facts invariants, and internally creates the non-Codable context. The silicon gateway compares every returned binding/snapshot/authorization/phase/digest field with BASSiliconAdmissionRequest; requires memoryRequest.workRootArtifactID == executionBindingArtifactID, exact load/prefill/cache/decode mapping to neuralLoad/neuralPrefill/neuralCache/neuralDecode, activationClass == .heavy, owner/deadline equality, and deadline no later than snapshot expiry. No caller passes hardCapBytes, quality digest, StateABI digest, profile ID, fallback list, attestation ID, or an independently forgeable context.

- [ ] **Step 4: Implement offer, revalidation, compare-and-start, and idempotent cleanup**

~~~swift
public struct BASSiliconLeaseGateway: Sendable {
    private let verifier: any BASSiliconBindingVerificationPort
    private let ledger: BASProcessMemoryLedger

    public init(
        verifier: any BASSiliconBindingVerificationPort,
        ledger: BASProcessMemoryLedger
    ) {
        self.verifier = verifier
        self.ledger = ledger
    }

    public func offer(
        _ request: BASSiliconAdmissionRequest,
        physicalFootprintBytes: UInt64,
        availableMemoryAdviceBytes: UInt64?,
        nowLogicalTime: UInt64
    ) async throws -> BASSiliconLeaseOffer {
        let (verified, admissionContext) = try await verifiedAdmission(
            for: request, atLogicalTime: nowLogicalTime)
        try Task.checkCancellation()
        let reservation = try await ledger.reserve(
            verified.memoryRequest,
            admissionContext: admissionContext,
            observation: BASMemoryAdmissionObservation(
                physicalFootprintBytes: physicalFootprintBytes,
                availableMemoryAdviceBytes: availableMemoryAdviceBytes),
            nowLogicalTime: nowLogicalTime)
        do {
            try Task.checkCancellation()
        } catch {
            try await cancelAndRethrow(
                reservation.token, primaryError: error)
        }
        return BASSiliconLeaseOffer(
            request: request,
            verified: verified,
            admissionContext: admissionContext,
            reservation: reservation)
    }

    public func compareAndStart(
        _ offer: BASSiliconLeaseOffer,
        physicalFootprintBytes: UInt64,
        availableMemoryAdviceBytes: UInt64?,
        nowLogicalTime: UInt64
    ) async throws -> BASSiliconActiveLease {
        let freshPair: (
            BASVerifiedSiliconAdmission,
            BASMemoryAdmissionContext
        )
        do {
            freshPair = try await verifiedAdmission(
                for: offer.request, atLogicalTime: nowLogicalTime)
            try Task.checkCancellation()
        } catch {
            try await cancelAndRethrow(
                offer.reservation.token, primaryError: error)
        }
        let (fresh, freshContext) = freshPair
        guard fresh == offer.verified,
              freshContext == offer.admissionContext
        else {
            try await cancelAndRethrow(
                offer.reservation.token,
                primaryError:
                    BASSiliconLeaseGatewayError.exactProjectionMismatch)
        }

        let activation: BASMemoryActivationToken
        do {
            activation = try await ledger.compareAndStart(
                offer.reservation.token,
                revalidatedContext: freshContext,
                observation: BASMemoryAdmissionObservation(
                    physicalFootprintBytes: physicalFootprintBytes,
                    availableMemoryAdviceBytes:
                        availableMemoryAdviceBytes),
                nowLogicalTime: nowLogicalTime)
        } catch {
            try await cancelAndRethrow(
                offer.reservation.token, primaryError: error)
        }

        do {
            try Task.checkCancellation()
        } catch {
            try await completeAndRethrow(
                activation, primaryError: error)
        }
        return BASSiliconActiveLease(
            activation: activation,
            verified: fresh)
    }

    @discardableResult
    public func finish(
        _ lease: BASSiliconActiveLease,
        placementEvidence: BASPlacementEvidence,
        actualPeakBytes: UInt64?
    ) async throws -> BASSiliconLeaseCompletionReceipt? {
        guard try await ledger.complete(
            lease.activation,
            actualPeakBytes: actualPeakBytes) != nil
        else {
            return nil
        }
        let facts = lease.verified.memoryAdmissionFacts
        return BASResult(
            success: true,
            body: BASSiliconLeaseCompletionBody(
                leaseID: lease.id,
                executionBindingArtifactID:
                    lease.executionBindingArtifactID,
                certifiedProfileArtifactID:
                    lease.verified.certifiedProfileArtifactID,
                capabilitySnapshotArtifactID:
                    facts.capabilitySnapshotArtifactID,
                capabilitySnapshotEpoch:
                    facts.capabilitySnapshotEpoch,
                memoryContextVersion: facts.contextVersion,
                hardCapPolicyArtifactID:
                    facts.hardCapPolicyArtifactID,
                hardCapPolicyProofExpiryLogicalTime:
                    facts.hardCapPolicyProofExpiryLogicalTime,
                hardCapPolicyDigest: facts.policyDigest,
                hardCapDerivationVersion:
                    facts.derivationVersion,
                hardCapDerivationSource:
                    facts.derivationSource,
                reservationID:
                    lease.activation.reservationToken.reservationID,
                phase: lease.verified.phase,
                memoryWorkPhase: lease.activation.phase,
                activationEpoch: lease.activation.activationEpoch,
                derivationAttestationArtifactID:
                    facts.derivationAttestationArtifactID,
                placementEvidence: placementEvidence,
                actualPeakBytes: actualPeakBytes),
            diagnostics: [])
    }

    @discardableResult
    public func cancel(
        _ offer: BASSiliconLeaseOffer
    ) async throws -> Bool {
        try await ledger.cancelPending(offer.reservation.token)
    }

    private func cancelAndRethrow(
        _ token: BASMemoryReservationToken,
        primaryError: any Error
    ) async throws -> Never {
        do {
            // false means another exact-token cleanup already retired it.
            _ = try await ledger.cancelPending(token)
        } catch let cleanupError {
            throw BASSiliconLeaseGatewayError.cleanupFailed(
                primary: String(describing: primaryError),
                cleanup: String(describing: cleanupError))
        }
        throw primaryError
    }

    private func completeAndRethrow(
        _ activation: BASMemoryActivationToken,
        primaryError: any Error
    ) async throws -> Never {
        do {
            // nil means another exact-token completion already retired it.
            _ = try await ledger.complete(
                activation, actualPeakBytes: nil)
        } catch let cleanupError {
            throw BASSiliconLeaseGatewayError.cleanupFailed(
                primary: String(describing: primaryError),
                cleanup: String(describing: cleanupError))
        }
        throw primaryError
    }

    private func verifiedAdmission(
        for request: BASSiliconAdmissionRequest,
        atLogicalTime now: UInt64
    ) async throws -> (
        BASVerifiedSiliconAdmission,
        BASMemoryAdmissionContext
    ) {
        guard now < request.deadlineLogicalTime else {
            throw BASSiliconLeaseGatewayError.expired
        }
        let verified = try await verifier.verify(
            executionBindingArtifactID:
                request.executionBindingArtifactID,
            capabilitySnapshotArtifactID:
                request.capabilitySnapshotArtifactID,
            authorizationContextArtifactID:
                request.authorizationContextArtifactID,
            phase: request.phase,
            planProjectionDigest: request.planProjectionDigest,
            atLogicalTime: now)
        let facts = verified.memoryAdmissionFacts
        try facts.validate(
            expectedCapabilitySnapshotArtifactID:
                request.capabilitySnapshotArtifactID,
            atLogicalTime: now)
        let mappedPhase = memoryPhase(for: request.phase)
        guard verified.executionBindingArtifactID
                == request.executionBindingArtifactID,
              verified.authorizationContextArtifactID
                == request.authorizationContextArtifactID,
              verified.phase == request.phase,
              verified.planProjectionDigest
                == request.planProjectionDigest,
              verified.memoryRequest.workRootArtifactID
                == request.executionBindingArtifactID,
              verified.memoryRequest.ownerID == request.heavyOwnerID,
              verified.memoryRequest.phase == mappedPhase,
              verified.memoryRequest.activationClass == .heavy,
              verified.memoryRequest.deadlineLogicalTime
                == request.deadlineLogicalTime,
              request.deadlineLogicalTime
                <= facts.expiryLogicalTime
        else {
            throw BASSiliconLeaseGatewayError.exactProjectionMismatch
        }
        return (
            verified,
            BASMemoryAdmissionContext(verifiedFacts: facts))
    }

    private func memoryPhase(
        for phase: BASSiliconExecutionPhase
    ) -> BASMemoryWorkPhase {
        switch phase {
        case .load: return .neuralLoad
        case .prefill: return .neuralPrefill
        case .cache: return .neuralCache
        case .decode: return .neuralDecode
        }
    }
}

public extension BASLeaseLifeCoordinator {
    func memoryAdmissionContextGateway(
        verifier: any BASMemoryAdmissionContextVerificationPort
    ) -> BASMemoryAdmissionContextGateway {
        BASMemoryAdmissionContextGateway(verifier: verifier)
    }

    func siliconLeaseGateway(
        verifier: any BASSiliconBindingVerificationPort
    ) -> BASSiliconLeaseGateway {
        BASSiliconLeaseGateway(
            verifier: verifier,
            ledger: memoryLedger)
    }
}
~~~

offer verifies once, internally materializes the in-memory context from the returned snapshot facts, reserves the verifier-derived neural-heavy request, and returns a transient value whose ID is the ledger reservation ID. It stores no offer registry. compareAndStart verifies the same signed inputs again, requires equality of the complete immutable projection and derived context, and calls the ledger with the exact reservation token. The mapping function is total and the equality guard makes any execution-phase/work-phase mismatch fail before actuation. The ledger rejects every second heavy start while unrelated ordinary activation and unrelated reservation mutations do not invalidate the offer.

Cancellation before start calls cancelPending with the exact reservation token; cancellation after ledger CAS calls complete with the exact activation token. Every gateway-owned cleanup is awaited in an explicit do/catch: a thrown cleanup error becomes `cleanupFailed(primary:cleanup:)`, while false/nil means the same exact token was already idempotently retired. No cleanup uses `try?`. finish uses the same activation-token CAS and returns the only completion receipt; duplicate finish returns nil. The generic context gateway retains only its verifier; the silicon gateway retains only verifier and ledger. Neither has mutable state, retry loop, queue, fallback selection, context/offer/active map, or persistence. Race tests suspend verification, cancel the exact pending token, resume verification, and prove start fails without leaks or double actuation.

- [ ] **Step 5: Add BASLeaseLife to BASMLXAdapter and route every entry through one thin actuator**

In Package.swift add "BASLeaseLife" to the existing BASOrgan and BASMLXAdapter dependency arrays. Import BASLeaseLife only in the files that implement or consume the seam. The application composition root asks its one BASLeaseLifeCoordinator for a gateway using BASExecutionPlan.BindingVerificationAdapter, then injects that same stateless gateway into MLXOrganAdapter. Production-required mode rejects an absent gateway or BASSiliconAdmissionRequest with SiliconActuationError.gatewayRequired; the old BASOrganAdapter requirement is explicitly compatibility-only for one release.

First extend the vendored owner instead of inventing a BAS-side cleanup latch. The current WiredMemoryTicket.withWiredLimit cancellation handler launches ticket.end in an unstructured Task; if cancellation wins its local EndOnceGuard, the operation path can throw before that Task has finished. Replace only that local guard/wrapper with this shared completion barrier so withWiredLimit never returns or throws until the one upstream end operation has completed:

~~~swift
extension WiredMemoryTicket {
    private actor EndOnceBarrier {
        private var endTask: Task<Int, Never>?

        func end(_ ticket: WiredMemoryTicket) async -> Int {
            if let endTask { return await endTask.value }
            let task = Task { await ticket.end() }
            endTask = task
            return await task.value
        }
    }

    public static func withWiredLimit<R>(
        _ ticket: WiredMemoryTicket,
        _ body: () async throws -> R
    ) async rethrows -> R {
        _ = await ticket.start()
        let endBarrier = EndOnceBarrier()
        return try await withTaskCancellationHandler {
            do {
                let result = try await body()
                _ = await endBarrier.end(ticket)
                return result
            } catch {
                _ = await endBarrier.end(ticket)
                throw error
            }
        } onCancel: {
            Task { _ = await endBarrier.end(ticket) }
        }
    }
}
~~~

Replace the existing WiredMemoryManager.end body with the byte-equivalent method below except for deleting the contradictory DEBUG assertion on a missing/cancelled-before-admission ticket. The documented idempotent path still emits ticketEndIgnored and returns the current limit:

~~~swift
public func end(id: UUID, policy: any WiredMemoryPolicy) -> Int {
    if let waiter = waiters.removeValue(forKey: id) {
        waiter.resume()
    }

    guard WiredMemoryBackend.isSupported || policyOnlyMode else {
        if baseline == nil { baseline = 0 }
        return baseline ?? 0
    }

    guard let state = tickets.removeValue(forKey: id) else {
        emit(kind: .ticketEndIgnored, ticketID: id)
        return currentLimit ?? baseline ?? 0
    }

    emit(
        kind: .ticketEnded,
        ticketID: id,
        size: state.size,
        policy: state.policyLabel,
        baseline: baseline)
    if !tickets.values.contains(where: {
        $0.policyKey == state.policyKey
    }) {
        policies.removeValue(forKey: state.policyKey)
    }

    if tickets.isEmpty {
        let baselineValue = baseline ?? 0
        applyLimitIfNeeded(baselineValue)
        emit(
            kind: .baselineRestored,
            baseline: baselineValue,
            appliedLimit: currentLimit)
        baseline = nil
        resumeWaiters()
        return baselineValue
    }

    applyCurrentLimit()
    resumeWaiters()
    return currentLimit ?? baseline ?? 0
}
~~~

Do not change the manager's ticket dictionary, waiter, policy, hysteresis, baseline, limit calculation, or backend calls. Add a cancellation test that suspends the body, cancels the wrapper, releases the body, and proves the awaited wrapper result is delivered only after exactly one ticketEnded or ticketEndIgnored event. EndOnceBarrier is ticket-local lifecycle joining, not a capacity waiter or a BAS-owned state authority.

Extend the existing BASMLXMemoryModel observation seam rather than adding another probe owner:

~~~swift
public extension BASMLXMemoryModel {
internal struct RuntimeAdmissionObservation: Sendable, Equatable {
    let physicalFootprintBytes: UInt64
    let availableMemoryAdviceBytes: UInt64?
}

internal static func runtimeAdmissionObservation()
    -> RuntimeAdmissionObservation
{
    #if os(iOS)
    let footprint = (try? BASTaskVmInfoProbe.rawSnapshot()
        .physFootprintBytes) ?? 0
    let available = os_proc_available_memory()
    return RuntimeAdmissionObservation(
        physicalFootprintBytes: footprint,
        availableMemoryAdviceBytes:
            available > 0 ? UInt64(available) : nil)
    #else
    return RuntimeAdmissionObservation(
        physicalFootprintBytes: 0,
        availableMemoryAdviceBytes: nil)
    #endif
}
}
~~~

Do not derive a hard cap from physicalFootprintBytes + availableMemoryAdviceBytes. Keep the existing resolvedActiveHardCapBytes spelling for one release only as deprecated diagnostic compatibility, outside authoritative admission; do not call it from the production load/prefill/cache/decode actuator. Retire production calls to wouldExceedActiveHardCap and the old independent enforceMemoryAdmission Boolean. The only cap used by reserve/start is the resolved cap inside the verified BASSystemSnapshot-derived BASMemoryAdmissionContext. runtimeAdmissionObservation owns the one live footprint/advice read, and advice remains telemetry only.

Add this wrapper to MLXOrganAdapter+Executor.swift, using a single stable upstream policy value:

~~~swift
extension MLXOrganAdapter {
private static let siliconWiredPolicy = WiredSumPolicy(
    id: UUID(uuidString: "1D2C697B-52B6-4D8D-9A7C-8AEB86D1D4B7")!
)

func _withUnifiedSiliconLease<Output>(
    admission: BASSiliconAdmissionRequest,
    wiredBytes: Int,
    body: () async throws -> Output
) async throws -> Output {
    guard let gateway = siliconLeaseGateway else {
        throw SiliconActuationError.gatewayRequired
    }
    let runtimeMemory = BASMLXMemoryModel.runtimeAdmissionObservation()
    let offer = try await gateway.offer(
        admission,
        physicalFootprintBytes: runtimeMemory.physicalFootprintBytes,
        availableMemoryAdviceBytes:
            runtimeMemory.availableMemoryAdviceBytes,
        nowLogicalTime: BASMonotonicNanos.defaultV1Nanos())

    let startMemory = BASMLXMemoryModel.runtimeAdmissionObservation()
    let lease = try await gateway.compareAndStart(
        offer,
        physicalFootprintBytes:
            startMemory.physicalFootprintBytes,
        availableMemoryAdviceBytes:
            startMemory.availableMemoryAdviceBytes,
        nowLogicalTime: BASMonotonicNanos.defaultV1Nanos())

    let ticket = WiredMemoryTicket(
        size: max(0, wiredBytes),
        policy: Self.siliconWiredPolicy,
        manager: WiredMemoryManager.shared,
        kind: .active)
    do {
        let measured = try await WiredMemoryTicket.withWiredLimit(ticket) {
            try Task.checkCancellation()
            let before = Memory.snapshot()
            let naxBefore = GPU.naxDispatchSnapshot()
            let output = try await body()
            let naxAfter = GPU.naxDispatchSnapshot()
            let after = Memory.snapshot()
            return (
                output: output,
                selectedDelta: naxAfter.selected >= naxBefore.selected
                    ? naxAfter.selected - naxBefore.selected : 0,
                actualPeakBytes: UInt64(
                    max(0, max(before.peakMemory, after.peakMemory))))
        }
        // The upstream wrapper cannot return until its one end task completes.
        guard try await gateway.finish(
            lease,
            placementEvidence: .nax(
                selectedDelta: measured.selectedDelta,
                exclusiveOperationLease: true,
                provenanceArtifactID: nil),
            actualPeakBytes: measured.actualPeakBytes) != nil
        else {
            throw SiliconActuationError.completionCASLost
        }
        return measured.output
    } catch let primaryError {
        let after = Memory.snapshot()
        // withWiredLimit has already joined its ticket-end task before throwing.
        do {
            _ = try await gateway.finish(
                lease,
                placementEvidence: BASPlacementEvidence(
                    requestedTier: .gpu,
                    physicalTier: nil,
                    status: .unknown,
                    scope: .operation,
                    mechanism: "mlx.failure",
                    provenanceArtifactID: nil),
                actualPeakBytes: UInt64(max(0, after.peakMemory)))
        } catch let cleanupError {
            throw SiliconActuationError.cleanupFailed(
                primary: String(describing: primaryError),
                cleanup: String(describing: cleanupError))
        }
        throw primaryError
    }
}
}
~~~

BASMLXMemoryModel and BASMLXMemoryBudget only compute wiredBytes and the verifier's memory request inputs; delete/disable their independent production grant. Reuse the strengthened WiredMemoryTicket.withWiredLimit for upstream waiting/cancellation/pairing and its awaited end barrier, then call gateway.finish only after the wrapper returns or throws. The BAS adapter never calls ticket.end directly. Do not add a manager, admission waiter, continuation, baseline, hysteresis, cache of Memory.snapshot(), direct mlx_set_wired_limit call, or a second limit controller. WiredMemoryManager.shared remains the sole MLX wired owner.

Bound eager overloads call _withUnifiedSiliconLease and keep _execute unchanged inside body. Bound session overloads keep the same ChatSession pool/FIFO body. Bound stream overloads acquire once around the existing stream pump, and continuation.onTermination cancels that task so withWiredLimit joins upstream ticket cleanup before the catch path calls gateway.finish. `compareAndStart` itself owns every pre-activation failure cleanup and preserves any cleanup failure, so the MLX wrapper never issues a second cancel after that call throws. Prompt lookup, MTP, suffix, Saguaro, and plain remain branches of the existing executor; none acquires its own lease or ticket.

The successful release order is always upstream ticket end completion then gateway.finish; the cancellation/error order is identical. Never use defer for async cleanup and never call ticket.end from BASMLXAdapter. Add one nested SiliconActuationError under the existing MLXOrganAdapter with gatewayRequired, completionCASLost, and cleanupFailed(primary:cleanup:); do not create an error file or top-level owner. completionCASLost prevents a successful model output when this caller lost terminal owner CAS, while cleanupFailed preserves both primary and cleanup diagnostics instead of silently leaking a ledger owner.

- [ ] **Step 6: Run focused tests, full build, and single-owner guards**

~~~bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASSiliconLeaseGatewayTests|BASProcessMemoryLedgerTests|BASMLXUnifiedLeaseTests|BASSiliconOwnerUniquenessTests|BASExecutionPlanElectorTests|BASDecodeStrategyTests|MLXOrganAdapterTests|BASSessionLaneTests|BASSessionDecodeSlotHandoffTests|BASStreamCancellationPropagationTests|BASPromptLookupCarryForwardTests'
swift build --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
git diff --check -- BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/WiredMemory.swift
test "$(rg -n '^public struct BASSiliconExecutionBinding' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
test "$(rg -n '^public actor BASProcessMemoryLedger' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
test "$(rg -n '^public struct BASMemoryAdmissionContextGateway' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
test "$(rg -n '^public struct BASSiliconLeaseGateway' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources | wc -l | tr -d ' ')" = 1
! rg -n 'BASSiliconLeaseAuthority' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources
! rg -n 'admissionContextArtifactID|BASCapabilitySnapshot' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources
! rg -n 'BASMemoryAdmissionContext.*Codable|extension BASMemoryAdmissionContext:.*Codable' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife
! awk '/public struct BASMemoryAdmissionContext:/{inside=1} inside{print} /^public enum BASMemoryAdmissionContextError/{exit}' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift | rg -n 'public init\('
! rg -n 'private var (offers|active|activeLeases|leaseOffers|contexts|heavyOwner):' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife
test "$(rg -n '^    private var reservations: \[UUID: BASMemoryReservation\] = \[:\]$' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift | wc -l | tr -d ' ')" = 1
if rg -n -U 'try\?[[:space:]]+await[[:space:]]+(ledger\.(cancelPending|complete)|gateway\.(cancel|finish)|cancel)\(' \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift; then
  exit 1
fi
test "$(awk '/public struct BASMemoryAdmissionContextGateway/{inside=1} inside && /public init\(/{exit} inside && /private let verifier:/{n++} END{print n+0}' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift)" = 1
test "$(awk '/public struct BASSiliconLeaseGateway/{inside=1} inside && /public init\(/{exit} inside && /private let/{n++} END{print n+0}' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift)" = 2
! awk '/public struct BASSiliconLeaseGateway/{inside=1} inside{print} /^public extension BASLeaseLifeCoordinator/{exit}' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift | rg -n 'private var|Dictionary<|\[[^]]+:[^]]+\]'
! awk '/public struct BASMemoryAdmissionContextGateway/{inside=1} inside{print} /^public struct BASVerifiedSiliconAdmission/{exit}' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift | rg -n 'private var|Dictionary<|\[[^]]+:[^]]+\]'
! rg -n 'mlx_set_wired_limit|WiredMemoryManager\(' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter
! rg -n 'hardCapBytes:' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter
! rg -n 'resolvedActiveHardCapBytes|wouldExceedActiveHardCap|enforceMemoryAdmission' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift
rg -q 'WiredMemoryTicket\.withWiredLimit' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift
! rg -n '\bticket\.end\(' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMLXAdapter
rg -q 'private actor EndOnceBarrier' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/WiredMemory.swift
! rg -n 'BASCertifiedProfileRegistry|BASSiliconThermalState|public struct BASQualityIdentity|public enum BASCapabilityThermalSnapshot|enum OSThermalState' /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources
~~~

Expected: selected tests PASS, build completes, vendor diff check is silent, all owner/count guards exit 0, and all negative rg commands return no matches. Order tests report BAS offer/start before MLX start and the awaited upstream end event before BAS finish for success, throw, and cancellation. Concurrent double-start yields exactly one active lease, cancel-versus-start leaves no reservation, and concurrent duplicate finish produces exactly one receipt.

- [ ] **Step 7: Build and run the device proof**

Extend the real-device branch of BASChapter952RealMLXOnDeviceTests with testUnifiedSiliconLeaseTicketOrderAndEvidence. It creates a real bound Qwen turn in production-required mode, records gateway/ledger lifecycle plus WiredMemoryManager DEBUG ticket events, cancels a second streamed turn after its first chunk, and asserts both paths end with zero ledger reservations/owner, zero upstream active tickets, exact release order, unchanged output identity, and NAX evidence classified only as mlx.metal.nax/.gpu when selectedDelta is positive.

~~~bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj -scheme BASDeviceTestApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
test -n "$BAS_IOS27_DEVICE_UDID"
xcodebuild -project /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj -scheme BASDeviceTestApp -destination "platform=iOS,id=$BAS_IOS27_DEVICE_UDID" test -only-testing:BASDeviceTests/BASChapter952RealMLXOnDeviceTests/testUnifiedSiliconLeaseTicketOrderAndEvidence
~~~

Expected: generic build prints BUILD SUCCEEDED; the environment assertion exits 0; the physical iOS 27 run passes with zero binding/profile/ledger/order invariant failures. Core AI remains evidence-only, and a NAX-selected delta is recorded as an MLX/Metal GPU mechanism—not Neural Engine custody.

- [ ] **Step 8: Commit**

~~~bash
git add BehavioralAISubstrate/Package.swift BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Streaming.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+PromptLookup.swift BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+SessionPersist.swift BehavioralAISubstrate/Sources/BASMLXAdapter/BASMLXMemoryModel.swift BehavioralAISubstrate/Sources/BASMLXAdapter/BASMLXMemoryBudget.swift BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/WiredMemory.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASChapter952RealMLXOnDeviceTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconLeaseGatewayTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMLXUnifiedLeaseTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconOwnerUniquenessTests.swift BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSiliconExecutionBindingTests.swift
git commit -m "feat: unify signed silicon lease actuation"
~~~

### Task 7 [W1 contracts, W4 actuation, W5 release handoff]: Converge TurnOperation, Provider Execution, Plan Actuation, and Qinao Composition

**Wave scheduling:** In W1 execute Step 0's descriptor value-contract freeze, then only the W1 cases from Steps 1–2, Step 4's Provider-inversion portion, Step 5A, and the W1 portion of Step 7; run Step 7A and its dedicated commit. W1 uses only the Contracts Task 2A in-memory branch-control conformer and has no shipping branch allocation, physical Provider call, spool, or release path. Consume W2 and W3 next without running Silicon Tasks 2 or 5. At W4, complete Tasks 2 and 5 first; Task 3 consumes the frozen W1 descriptor contract, then wire Step 4's production `BASProviderBranchControlPort` flow and execute Steps 3, 5B, 6, the W4 shared-resource portion of Step 7, and Steps 8–9. Only after the sovereign W5 receipt may Step 5C and Step 10 add spool/L10/visibility-release handoff. Physical grouping never authorizes W4-before-W2/W3, W5-before-release, or a combined-wave commit.

**Reuse Decision:** E/delete — extend the existing runtime engine, provider planner/executor, execution plan, organ protocol/registry, adapter implementations, sovereign spool, and Qinao endpoint injection seam. Delete Qinao-owned concrete provider factories and their package targets. Do not create another router, operation coordinator, response accumulator, model catalog, HeavySeat manager, provider registry, or provider implementation inside Qinao. This task adds no production file and therefore does not change the Production Create Budget.

**Files:**
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderPlanningCore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlanElector.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASOrganAdapter.swift`
- Mechanically modify in W1 every pre-existing `BASOrganDescriptor(...)` construction returned by the frozen `rg -l 'BASOrganDescriptor\(' BehavioralAISubstrate QinaoRuntimeSDK SampleHost --glob '*.swift'` inventory; every call must spell `containmentClass:` explicitly
- Modify: `BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASStreamingOrganAdapter.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXModelCatalog.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Executor.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Streaming.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/AppleFoundationOrganAdapter.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/AppleFoundationOrganAdapter+Streaming.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift`
- Modify in separate W1/W4/W5 deltas: `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Modify in separate W1/W4/W5 deltas: `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift`
- Modify: `BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift`
- Consume only in W5 after the sovereign receipt: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift` (no Silicon-owned edit)
- Modify: `QinaoRuntimeSDK/Package.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpoint.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoStreamingOrganEndpoint.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoLoop/BASOrganRegistryEndpoint.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoDefaults.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Modify to a dormant read-only logical projection: `QinaoRuntimeSDK/Sources/QinaoSeats/QinaoSeatResidencyManager.swift`
- Modify to provider-neutral sample injection: `QinaoRuntimeSDK/Sources/QinaoSample/SampleProvider.swift`
- Modify to provider-neutral sample injection: `QinaoRuntimeSDK/Sources/QinaoSample/SampleSession.swift`
- Modify/delete concrete-provider sample surface: `QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLoRAExtensions.swift`
- Modify/delete concrete-provider sample surface: `QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLongSmokeBenchExtensions.swift`
- Delete concrete-provider sample surface: `QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostMLXExtensions.swift`
- Modify/delete concrete-provider sample surface: `QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift`
- Modify to host-injected endpoint: `QinaoRuntimeSDK/Sources/QinaoSampleHost/main.swift`
- Delete: `QinaoRuntimeSDK/Sources/QinaoMLX/QinaoMLXEndpoint.swift`
- Delete: `QinaoRuntimeSDK/Sources/QinaoAppleFoundation/QinaoAppleFoundationEndpoint.swift`
- Modify host composition: `SampleHost/SampleHostBASHostInvocation.swift`
- Modify host composition: `BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift`
- Create: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExecutionPlanActuationTests.swift`
- Create only in W5: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderExecutionSpoolTests.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASOrganRegistryTests.swift`
- Create in W1: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPersistedOrganDescriptorPayloadTests.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASExecutionPlanElectorTests.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/MLXOrganAdapterTests.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleFoundationStreamingTests.swift`
- Create: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSharedResourceTests.swift`
- Modify: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSeatResidencyManagerTests.swift`
- Modify: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSeatFabricDormancyBoundaryTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationAuditChainTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationConcurrencyTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationFactoryTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationFurnaceChainTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationGateChainTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationMemoryChainTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationRiskGateTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationWorldPriorChainTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoLoopStreamBodyTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMLXSpeculativeSurfaceTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostFlowTests.swift`
- Modify to provider-neutral fixture: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleSessionTests.swift`
- Modify: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSendSessionStreamingTests.swift`
- Delete: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMLXEndpointTests.swift`

**Interfaces:**
- Consumes: the Contracts Task 2A `BASTurnOperationRef` installed in the active K3 Attempt head, the one injected six-method `BASProviderBranchControlPort` and its allocation/claim/seal/terminal-source/visibility/state receipts, W5's package-only same-owner `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` view on that same injected concrete storage object, one stored execution-binding root plus causally materialized per-branch `BASExecutionPlan` artifact IDs, the selected immutable descriptor artifact, `BASProviderSelectionPlan`, explicit Provider IDs during value-only preflight, `BASProcessMemoryLedger.processShared`, signed silicon leases, the sovereign `BASResponseSpoolPayload` contract, Artifact Mesh, and existing Provider adapters.
- Produces in W1: required `BASProviderContainmentClass`, the final source-breaking `BASOrganDescriptor.containmentClass`, same-file first-governed `BASPersistedOrganDescriptorPayload` 1.0.0, explicit constructor migration, and its exact-one cycle-safe registry/fixture receipt. It also produces `BASTurnRuntimeEngine.beginTurn(_:) async throws -> TurnOperation`, causal typed Provider-branch submissions/receipts, `TurnOperation.stream()`, `TurnOperation.final()`, the unique ordinal-zero `.provisionalStream` and `.finalPublication` views of the pinned terminal source, `BASProviderAttemptExecutor.executeExactlyOnce`, `BASOrganAdapter.executePlanned(_:)`, exact phase receipts, identity-only `BASOrganRegistry.adapter(providerID:)`, and host-injected Qinao endpoints. W4/W5 consume the frozen descriptor contract without changing its bytes. It produces no ordinal/claim/source/visibility/descriptor-store owner and does not declare `BASProviderObservedReceipt`.
- Exactly-once invariant: for every K3-allocated Provider egress branch, `physicalProviderInvocationCount(branch) == 1` iff its claim receipt is newly won; an existing/indeterminate claim causes zero additional calls. The whole operation has a bounded call count equal to the number of newly won branch claims, one terminal-source pin, and `spoolFinalizationCount ∈ {0,1}`. There is no post-claim fallback on a branch and no sibling replacement after terminal-source pin.
- View invariant: stream and eager expose the same `turnOperationRef`, exact immutable shared `terminalPrefixProviderBranchChainArtifactID` and `throughVisibilityProviderBranchChainArtifactID`, pinned `terminalAnswerSourceBranchRef`, that source's `providerExecutionRef`/plan/provider/binding/fallback identity, ordinal-zero provisional/final refs, spool artifact ID, terminal draft, verifier result, and publication finalization. K3 event/coverage heads remain separate authority and are reopened by validators; no third mutable lineage head exists. The only view difference is when UI deltas are revealed; neither view accepts caller-minted raw IDs or an unpinned candidate branch.

- [ ] **Step 0 [W1 value-contract]: Freeze descriptor containment and its governed parent before every consumer**

In `BASOrganAdapter.swift`, atomically add the required enum/property and same-file parent before any parent v1 bytes exist:

```swift
public enum BASProviderContainmentClass:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case inProcessCertified
    case isolatedExtension
    case remote
}

// Required in the existing BASOrganDescriptor declaration and initializer.
public let containmentClass: BASProviderContainmentClass

public struct BASPersistedOrganDescriptorPayload:
    BASSchemaVersioned, Codable, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let descriptor: BASOrganDescriptor

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        descriptor: BASOrganDescriptor
    ) {
        self.schemaVersion = schemaVersion
        self.descriptor = descriptor
    }
}
```

There is no initializer default, compatibility overload, or inference from `providerKind`/`runsOnDevice`. The W1 **constructor inventory** is the complete frozen `rg -l 'BASOrganDescriptor\('` result; migrate every construction in the same atomic change. Current Chat Completions is `.remote`; in-process Apple Foundation, MLX, deterministic, mock, routing, and test providers spell `.inProcessCertified`; `.isolatedExtension` is legal only for an already-certified sovereign extension boundary. Every test fixture chooses explicitly. An unlisted constructor, inferred class, temporary package break, or later constructor backfill fails the W1 gate.

`BASPersistedOrganDescriptorPayload` is self-ID-free and first/current 1.0.0. All identity/put/reopen bytes use only `BASGovernedArtifactPayloadCodec`; `BASOrganDescriptor` and the enum remain unregistered embedded values. Because BASAdmin cannot import the leaf target, add exactly one Contracts-approved cycle-safe **registry entry**: `pinnedEntry("BASPersistedOrganDescriptorPayload", currentVersion: "1.0.0", tests: ["schema.BASPersistedOrganDescriptorPayload.current", "schema.BASPersistedOrganDescriptorPayload.backward_v1", "schema.BASPersistedOrganDescriptorPayload.future_rejection"], learnability: .semiLearnable)`. The **backward_v1 fixture** is the first/current v1 fixture and performs no migration.

`BASPersistedOrganDescriptorPayloadTests` iterates every containment case, central-codec round-trips and canonical-byte-equals parent plus descriptor, rejects missing/unknown/rewritten containment and missing/future schema before registry/routing/allocation/invocation, and source-inventories every constructor for explicit `containmentClass:`. Registry tests require exact-one object/test IDs and owner-version parity; a cross-target fixture imports BASOrgan and omits only the default schema parameter. `swift package dump-package` proves no BASAdmin↔BASOrgan cycle. Commit this declaration/inventory/registry/fixture in Step 7A; Tasks 3, 7 W4, and 7 W5 only consume it.

- [ ] **Step 1 [wave-partitioned]: Write each RED test only in its owning wave**

Partition the cases before editing: W1 adds only typed-handle/fail-closed boundary, provider-neutral registry, and duplicate-claim contract tests; W4 adds plan actuation, route/preflight, physical invocation, source-pin, event-CAS, visibility-policy actuation, and shared-resource tests; W5 alone creates `BASProviderExecutionSpoolTests.swift` and adds spool/L10/through-visibility/release-handshake cases. Do not create or stage a future-wave test to make an earlier wave red. Add these exact assertions in their owning wave:

```swift
func testPlanActuatesEveryFrozenPhaseExactlyOnce() async throws {
    let fixture = makePlannedProviderFixture()
    let final = try await fixture.operation.final()

    XCTAssertEqual(
        final.actuationReceipts.map(\.phase),
        [.load, .prefill, .cache, .decode])
    XCTAssertEqual(
        final.actuationReceipts.map(\.planID),
        Array(repeating: fixture.planID, count: 4))
    XCTAssertEqual(
        final.actuationReceipts.map(\.projectionDigest),
        try fixture.plan.requiredPhaseProjectionDigests())
    let invocationCount = await fixture.provider.invocationCount
    XCTAssertEqual(invocationCount, 1)
}

func testFailureAfterProviderClaimDoesNotGenerateFallbackAnswer() async {
    let fixture = makeFailingClaimedProviderFixture()
    await XCTAssertThrowsErrorAsync {
        _ = try await fixture.operation.final()
    }
    let primaryCalls = await fixture.primary.invocationCount
    let fallbackCalls = await fixture.fallback.invocationCount
    let finalizationCount = await fixture.spool.finalizationCount
    XCTAssertEqual(primaryCalls, 1)
    XCTAssertEqual(fallbackCalls, 0)
    XCTAssertEqual(finalizationCount, 0)
}

func testStreamAndEagerDrainOneExecutionIntoOneSpool() async throws {
    let fixture = makeTurnOperationFixture()
    let operation = try await fixture.engine.beginTurn(fixture.request)
    async let streamFinal = operation.stream().final()
    async let eagerFinal = operation.final()
    let (lhs, rhs) = try await (streamFinal, eagerFinal)

    XCTAssertEqual(lhs, rhs)
    XCTAssertEqual(lhs.spoolArtifactID, rhs.spoolArtifactID)
    let invocationCount = await fixture.provider.invocationCount
    let appendedDeltas = await fixture.spool.appendedDeltas
    let finalizationCount = await fixture.spool.finalizationCount
    XCTAssertEqual(invocationCount, 1)
    XCTAssertEqual(appendedDeltas, fixture.provider.emittedDeltas)
    XCTAssertEqual(finalizationCount, 1)
}

func testQinaoProductionFactoryPassesTheProcessSharedLedgerToHostProviderFactory() async throws {
    let capture = LedgerIdentityCapture()
    _ = try await QinaoSovereignHostAssembly.makeProduction {
        ledger in
        await capture.record(ledger)
        return HostInjectedEndpoint(ledger: ledger)
    }
    let capturedLedger = await capture.value
    XCTAssertTrue(capturedLedger === BASProcessMemoryLedger.processShared)
}
```

Also mutate each load/prefill/cache/decode projection independently and assert that the adapter refuses a receipt with the old digest. Test two causally valid egress branches and prove distinct monotonic ordinals, one physical call per newly won claim, complete branch-bound sequence-zero execution refs, and one root. Add duplicate-claim/reconstructed-handle, selected-descriptor Artifact-ID/bytes/provider/containment mutations, same-sequence/same-digest, same-sequence/different-digest, gap/out-of-order/stale Attempt/generation/lease, stable-field mutation under a nonzero event sequence, pre-call crash, unsealed-tail crash, terminal-source race, post-pin sibling, post-visibility allocation, sibling-replacement, and terminal-answer tool/effect-proposal mutations. Run both `BASProviderVisibilityMode` paths and reject missing/wrong evidence or a mode switch.

In W5 add the exact isolated/remote hand-off crash matrix: crash before begin-handoff; CAS win then crash before invoke; transport return before supervisor-observation put; observation put/reopen before seal; seal commit before reply; lost/unqueryable remote result; and query-recovered terminal evidence. Assert only a fresh `.won` result from `beginProviderEgressHandoff` reaches the invoke closure, exact replay returns non-callable `.alreadyPossible`, every post-CAS recovery performs zero sends, and missing/foreign/incomplete `BASProviderObservedReceipt` leaves `sent_or_unknown` unsealed. Mutate request/root/branch/base execution ref/descriptor Artifact ID/arm ID/Attempt/generation/epochs/grant/use receipt and every observed-result binding independently. A valid terminal seal must atomically persist the exact arm and observation Artifact IDs and advance the same row to `terminal_or_indeterminate`; no intermediate success state or second CAS exists. Assert no per-token/chunk SQLite/fsync write, only bounded phase/checkpoint/terminal seals, zero leaked heavy reservations, one pinned terminal source, and no finalized partial/sibling body.

- [ ] **Step 2 [W1/W4/W5]: Run the owning wave's focused RED plus the owner-ledger gate**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASTurnOperationOwnershipTests|BASProviderBoundaryTests|BASOrganRegistryTests|BASEBrainSchemaGovernanceRegistryTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoProviderBoundaryTests|QinaoRuntimeSendSessionStreamingTests'
```

Expected W1 RED: typed fail-closed operation/provider-neutral boundary and identity-only registry do not yet exist. After W1 is committed and W2/W3 are consumed, W4 reruns the owner gate plus `BASExecutionPlanActuationTests|BASExecutionPlanElectorTests|MLXOrganAdapterTests|AppleFoundationStreamingTests|BASMLXUnifiedLeaseTests|QinaoRuntimeSharedResourceTests`; expected RED is advisory phases, missing production K3/binding actuation, and duplicate concrete/default owners. Only after the sovereign W5 receipt run `BASProviderExecutionSpoolTests`; expected RED is the missing terminal-prefix-spool → L10 → visibility → through-visibility/release-preparation handshake. No wave's RED references a source/test file owned by a later wave.

- [ ] **Step 3 [W4]: Make plan identity and phase actuation explicit in existing owners**

Keep `BASExecutionPlan` self-ID-free. Artifact Mesh returns its `planID`; `TurnOperation` and every provider event carry that external ID. Consume the Contracts Task 2A/W1 `BASProviderStepPurpose`, `BASProviderOutputRole`, and complete branch-bound `BASProviderExecutionRef` from `BASLowEntropyPrimitives.swift`; Silicon must not redeclare any of them. Consume this task's own Step-0/W1 `BASProviderContainmentClass`, required `BASOrganDescriptor.containmentClass`, and same-file `BASPersistedOrganDescriptorPayload` exactly as frozen; W4 must not redeclare them or change the parent's v1 bytes. Add only the remaining W4 values below in `BASExecutionPlan.swift` and `BASOrganAdapter.swift`:

```swift
// BASProviderContainmentClass, BASOrganDescriptor.containmentClass, and
// BASPersistedOrganDescriptorPayload already exist from Task 7 Step 0/W1.
// W4 consumes only.

public struct BASExecutionPhaseReceipt: Codable, Sendable, Equatable {
    public let planID: BASArtifactID
    public let phase: BASSiliconExecutionPhase
    public let projectionDigest: String
    public let reusedResidentState: Bool

    public init(
        planID: BASArtifactID,
        phase: BASSiliconExecutionPhase,
        projectionDigest: String,
        reusedResidentState: Bool
    ) {
        self.planID = planID
        self.phase = phase
        self.projectionDigest = projectionDigest
        self.reusedResidentState = reusedResidentState
    }
}

public struct BASProviderPreflightRequest: Sendable {
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let stepRuleID: String
    public let planID: BASArtifactID
    public let providerStepPurpose: BASProviderStepPurpose
    public let providerOutputRole: BASProviderOutputRole
    public let orderedCausalArtifactIDs: [BASArtifactID]
    public let providerID: String
    public let request: BASOrganRequest
    public let plan: BASExecutionPlan
}

public struct BASPlannedOrganRequest: Sendable {
    public let turnOperationRef: BASTurnOperationRef
    public let providerEgressBranchRef: BASTurnBranchRef
    public let providerExecutionRef: BASProviderExecutionRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let stepRuleID: String
    public let providerStepPurpose: BASProviderStepPurpose
    public let providerOutputRole: BASProviderOutputRole
    public let orderedCausalArtifactIDs: [BASArtifactID]
    public let planID: BASArtifactID
    public let selectedProviderDescriptorArtifactID: BASArtifactID
    public let request: BASOrganRequest
    public let plan: BASExecutionPlan
    public let executionBindingArtifactID: BASArtifactID
}

public enum BASProviderExecutionEvent: Sendable, Equatable {
    case phase(
        executionRef: BASProviderExecutionRef,
        eventDigest: String,
        receipt: BASExecutionPhaseReceipt
    )
    case chunk(
        executionRef: BASProviderExecutionRef,
        eventDigest: String,
        chunk: BASOrganDraftChunk
    )
    case terminal(
        executionRef: BASProviderExecutionRef,
        eventDigest: String,
        draft: BASOrganDraft
    )
}

public protocol BASOrganAdapter: Sendable {
    var descriptor: BASOrganDescriptor { get }
    func preflight(_ request: BASProviderPreflightRequest) async -> BASOrganCapacity
    func executePlanned(
        _ request: BASPlannedOrganRequest
    ) -> AsyncThrowingStream<BASProviderExecutionEvent, Error>
}
```

`BASProviderPreflightRequest` is value-only and has no branch ref, `BASProviderExecutionRef`, allocation/claim receipt, visibility receipt, or physical side effect. It projects one allowed binding `stepRuleID` plus its model/profile/plan/resource need to a candidate Provider; purpose/output role are checked projections from the exact shared policy rule, not a local authority. Preflight every ordered candidate and finish capability/Pareto/fallback selection before calling any K3 branch operation; choose one explicit eligible Provider/plan. Only then construct `BASPersistedOrganDescriptorPayload(descriptor: selectedDescriptor)`, canonicalize/ordinary-put/reopen that governed parent through Contracts' `BASGovernedArtifactPayloadCodec`, retain only its returned Artifact ID, and call `allocateProviderBranch → claimProviderExecution` with that ID. The ID always names the parent; `BASOrganDescriptor` remains its embedded domain value and is never independently put or registered. Allocation freezes the receipt-bound descriptor route, plan, ordinal, causes, and complete sequence-zero execution ref. An allocated-but-unclaimed branch must be reopened/claimed as itself and can never be abandoned for the next candidate. A Provider cannot become allocated merely to ask capacity, and no K3 ordinal is burned for a rejected preflight candidate.

`BASPlannedOrganRequest` has no public initializer from loose fields. Its package-only async factory consumes one `BASProviderBranchAllocationReceipt` plus the matching newly-won `BASProviderExecutionClaimReceipt` from the injected prerequisite `BASProviderBranchControlPort`, reopens exactly their common `selectedProviderDescriptorArtifactID`, bounded-decodes `BASPersistedOrganDescriptorPayload` through `BASGovernedArtifactPayloadCodec`, rejects unsupported versions before reading `descriptor`, and then unwraps and compares the canonical descriptor value with the selected adapter. It requires exact governed-parent ID equality in request/allocation/claim; the exact installed `providerBranchPolicyArtifactID` and `stepRuleID`; `providerEgressBranchRef.turnOperationRef == turnOperationRef`; branch kind `.providerEgress`; exact allocation-receipt ordinal equality; `providerExecutionRef.turnOperationRef == turnOperationRef`; `providerExecutionRef.providerEgressBranchRef == providerEgressBranchRef`; `providerExecutionRef.requestSequence == 0`; exact policy-derived purpose/output-role/ordered-causal-receipt equality with the allocation/claim receipts and binding template; and the exact active Attempt, accepted lease, and acceptance generation. Mismatch fails before Provider invocation and there is no overload taking an independent UUID/string operation ID, caller-loose Provider ID/descriptor, locally chosen ordinal/role, copied policy limit, or precomputed spool ID. `providerExecutionID` is Qinao-minted correlation inside the complete ref, not authority. Add `requiredPhaseProjectionDigests()` and `validateActuationReceipts(_:planID:)` to `BASExecutionPlan`. Canonicalize the complete load/prefill/cache/decode projections with the existing canonical byte owner. Validation requires the exact ordered four-phase vector and exact digest equality. A resident load/cache reuse is still an explicit phase receipt with `reusedResidentState == true`; omission is never treated as proof. Delete the source comment that says only decode actuates today.

Consume the exact-one governed-parent registry entry installed by this task's Step-0/W1 receipt; do not register `BASOrganDescriptor`, containment class, adapter, or another descriptor wrapper. W4 `BASEBrainSchemaGovernanceRegistryTests` and `BASOrganRegistryTests` rerun exact-one object/test IDs, owner-target version parity, current codec round-trip, first-v1 fixture decode, missing/future rejection before K3 allocation/Provider work, no alias/helper duplication, and unchanged embedded-descriptor equality at the first production put/reopen call site. The cross-target fixture still imports `BASOrgan` and constructs the public initializer with default schema version. `swift package dump-package` proves the pinned string entry avoids a BASAdmin↔BASOrgan cycle.

Allocation, claim, lineage entries, proposal receipts, and terminal-source evidence freeze the complete sequence-zero `BASProviderExecutionRef`. Every phase/chunk/terminal event uses that same type, derived only by its checked `withRequestSequence(next)` method; no initializer accepts the seven fields independently and no `BASProviderEventExecutionRef`/event-ref codec exists. Before exposing or appending an event, HostKit recomputes `eventDigest` from the canonical event payload and calls the `TurnOperation`/engine actor's private transient unsealed `(nextSequence, digest)` CAS for that already-claimed branch. The validator canonicalizes the event ref back to sequence zero only through the same checked method/initializer, requires equality of all six stable base fields with the claimed ref plus the exact next `requestSequence`, and then advances that transient head once. An identical duplicate sequence+digest is audit-only, the same sequence with another digest is a protocol violation, and a gap, out-of-order sequence, or stable-field/Attempt/lease/generation/execution/root/branch mismatch fails closed.

Do not turn that transient per-event CAS into a K3 SQLite write. The existing `BASK3ControlNucleusStorage`/`BASSQLiteEventLogStorage` physical writer alone durably stores allocation and one pre-call `possibleStarted` claim per egress branch, then bounded checkpoint-head and terminal seals/receipts; ordinary token/chunk events perform zero SQL/fsync/Artifact-Mesh I/O. Batch size and maximum unsealed tail are frozen in the binding/branch plan, never adapter-selected. Crash before a seal discards the actor-private transient tail and leaves that durable branch claim `indeterminate`; recovery is query/reconcile-only and cannot reinvoke or allocate a causally dependent branch until exact terminal/reconciliation evidence exists. This uses the existing six-method public K3 branch-control boundary and creates no seventh API, Provider ledger, sequence actor/store, event log, WAL, or sidecar table.

Existing `draft`, purpose-based `draft`, and `streamDraft` remain source-compatibility adapters for one migration commit only. They construct an explicit non-authoritative compatibility plan and delegate to `executePlanned`; no planned path delegates in the opposite direction. Task 7's final commit makes production call sites use only `executePlanned`.

- [ ] **Step 4 [W1 contract/inversion; W4 K3 wiring]: Restrict routing to preflight and invocation to exactly once per K3 branch**

In W1, declare/invert only the Silicon-owned value surfaces: `BASProviderPreflightRequest`, `BASPlannedOrganRequest`, typed Provider events, and the claimed-call adapter. Consume the shared branch-bound `BASProviderExecutionRef` and purpose/output-role/policy types from Contracts Task 2A rather than redeclaring them. The focused fixture consumes the Contracts Task 2A in-memory `BASProviderBranchControlPort` conformer. Shipping composition still has no branch-control call site in W1.

In W4, after the W2 SQLite conformer and W4 binding/ledger are green, extend `BASProviderSelectionPlan` with its plan artifact/binding references at the execution boundary; do not put self identity inside the stored plan payload. `BASExecutableProviderPlanner.resolve` remains pure and returns ordered explicit IDs. For each signed step, preflight every value-only descriptor/capacity and finish Pareto/fallback selection, then select one eligible Provider before K3 allocation. Wrap the selected descriptor in `BASPersistedOrganDescriptorPayload`, canonicalize/ordinary-put/reopen that governed parent through `BASGovernedArtifactPayloadCodec`, then ask the injected production `BASProviderBranchControlPort.allocateProviderBranch` to allocate the exact next causal branch with the parent's `selectedProviderDescriptorArtifactID` and return its complete branch-bound sequence-zero `BASProviderExecutionRef`; the allocation row/receipt and subsequent claim receipt must echo that parent ID exactly. Then call `claimProviderExecution`. Allocation failure fails closed; allocated-unclaimed recovery reopens/claims only that same ref and descriptor parent and never reruns routing. In `ProviderExecutionCore.swift`, `executeExactlyOnce` is the sole generative invocation adapter, but it can invoke only with the matching allocation and newly-won claim receipts returned by that K3 port:

```swift
public enum BASProviderAttemptExecutor {
    public static func executeExactlyOnce<Provider: BASOrganAdapter, Output: Sendable>(
        allocation: BASProviderBranchAllocationReceipt,
        newlyWonClaim: BASProviderExecutionClaimReceipt,
        provider: Provider,
        reopenSelectedDescriptor: @Sendable (
            BASArtifactID
        ) async throws -> BASPersistedOrganDescriptorPayload,
        expectedExecutionRef: BASProviderExecutionRef,
        invoke: (Provider) async throws -> Output
    ) async throws -> Output {
        guard newlyWonClaim.isNewlyClaimedPossibleStart,
              allocation.selectedProviderDescriptorArtifactID
                == newlyWonClaim.selectedProviderDescriptorArtifactID,
              newlyWonClaim.providerExecutionRef == expectedExecutionRef,
              expectedExecutionRef.providerEgressBranchRef.turnOperationRef
                == expectedExecutionRef.turnOperationRef,
              expectedExecutionRef.providerEgressBranchRef.kind == .providerEgress,
              expectedExecutionRef.requestSequence == 0 else {
            throw BASProviderExecutionError.providerIdentityMismatch
        }
        let persisted = try await reopenSelectedDescriptor(
            allocation.selectedProviderDescriptorArtifactID)
        let selected = persisted.descriptor
        guard selected == provider.descriptor else {
            throw BASProviderExecutionError.providerIdentityMismatch
        }
        return try await invoke(provider)
    }
}
```

The compact sketch assumes `reopenSelectedDescriptor` has already read the exact Artifact record and called `BASGovernedArtifactPayloadCodec.decodeCurrent(BASPersistedOrganDescriptorPayload.self, ...)`; no raw decoder or descriptor-only canonical codec exists. The executor also requires the allocation/claim receipt roots, branches, plan/binding proofs, policy/rule, expected source heads, and the governed parent's canonical identity bytes to match, omitted from the compact sketch only for space. No caller-supplied `expectedProviderID`, loose descriptor, registry lookup result, or adapter-local route choice is authority. `BASProviderExecutionClaimReceipt` is the exact source-head-bound receipt from the one prerequisite `BASProviderBranchControlPort`; Silicon declares no claim token, map, port, or receipt alias. `executeExactlyOnce` cannot allocate, claim, retry, recover, or infer authority from actor memory. A reconstructed handle calls `providerBranchState(turnOperationRef:branchRef:)` and never treats an existing claim as newly won. If the durable branch is `possibleStarted` without a known terminal receipt, the result is typed `providerExecutionIndeterminate`; recovery may query the Provider by the exact branch-bound execution ref when its certified boundary supports query, but may not invoke generation again.

In W5, extend this same `BASProviderAttemptExecutor.executeExactlyOnce` function—do not wrap it with another executor—with optional sovereign `BASProviderEgressBoundaryPermit`, `BASBoundaryAnchorReceipt`, and `BASBoundaryArmReceipt` inputs. The executor reopens/version-checks the receipt-bound `BASPersistedOrganDescriptorPayload`, unwraps its descriptor, and derives containment from the embedded canonical `containmentClass`: `inProcessCertified` requires all three boundary values absent; `isolatedExtension`/`remote` requires all three present. For an isolated/remote route, immediately before the same invoke closure, the executor reopens/equality-checks permit → anchor → arm, exact materialized payload/root/egress branch/complete execution claim/governed descriptor-parent ID and embedded descriptor/plan/destination/Attempt/generation/epochs/grant/use receipt, K3 `egress_boundary_armed`, current owner/boot epoch, and an unexpired hand-off deadline. It then calls package-only same-owner `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` on the same injected concrete `BASSQLiteEventLogStorage`, which equality-checks its own boundary/claim/allocation rows and performs the sole `egress_boundary_armed → sent_or_unknown` CAS. Only the in-flight caller receiving `.won` may enter the invoke closure; exact request replay returns `.alreadyPossible` and is non-callable. The six-method public `BASProviderBranchControlPort` remains unchanged and no public K3 protocol exposes callable hand-off. The adapter cannot self-validate and an outer caller cannot arm or begin hand-off then bypass this executor. Claim-before-fence or hand-off-CAS-before-invoke crash remains conservatively indeterminate and is never recalled.

Consume the W5 prerequisite's in-place extensions to the existing `BASProviderEventHeadSealRequest` and `BASProviderEventHeadSealReceipt`: exactly two paired optional Artifact IDs, `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID`. Also consume its self-ID-free `BASProviderObservedReceipt`, added as E to the existing low-entropy provider-package-boundary contract in `BASLowEntropyPrimitives.swift`, not as a new receipt owner/file/store. `QinaoOrganEndpoint.swift` is only the supervisor/endpoint adapter that constructs the value from the actual request binding, timing/cancellation, accepted bytes/tokens, state transition, and terminal result; a Provider-authored proposal/claim/transport receipt cannot promote itself.

Local execution requires both optional IDs nil. Isolated/remote execution requires both nonnil and exact request/receipt equality. After a complete remote result, the sole executor ordinary-puts and reopens the canonical supervisor observation, then submits the existing `sealProviderEventHead` request with that observation ID plus the same arm ID. K3 keeps the governed descriptor-parent ID and `BASSiliconExecutionBinding` opaque. In one `BEGIN IMMEDIATE ... COMMIT`, seal validation reopens its own allocation/claim/boundary rows, arm → permit/anchor, and supervisor observation; requires the identical request ID, root, branch, sequence-zero execution ref/claim, governed parent Artifact ID, arm ID, Attempt/generation/epochs/grant/use facts, and structurally complete terminal result; advances `sent_or_unknown → terminal_or_indeterminate`; commits the bounded event head; and persists/returns the one seal receipt with both IDs. Any missing/incomplete/foreign observation or changed binding rolls back the whole transaction. There is no `egress_terminal_observed` state, separate terminal-observation API, or second finalization CAS. Runtime replay separately follows lineage entry → allocation/claim receipt → governed parent ID, decodes it through `BASGovernedArtifactPayloadCodec`, unwraps the selected descriptor, and rechecks parent identity bytes, embedded adapter/provider identity, containment-class ↔ paired evidence, and plan/payload/destination equality.

`BASProviderBranchLineageEntry` and `BASProviderExecutionRef` stay unchanged: lineage already reaches the descriptor through its allocation/claim receipt and the paired remote evidence through its sole event-head-seal receipt. Do not put descriptor/observation/arm IDs in ordered causal receipts and do not create a manifest/lineage egress-evidence array. Query-only reconciliation may obtain the same canonical supervisor observation by the exact remote operation/sequence-zero execution ref and feed it into the same seal transaction, but it never invokes generation or transport again. Exact replay of an already committed identical seal is read-only/idempotent; a changed observation is corruption. A lost, incomplete, foreign, or unqueryable remote result stays `sent_or_unknown`; it cannot seal, enter a terminal-prefix chain, spool, or publish.

The existing multi-attempt helper remains available only to non-generative test/retrieval paths and is renamed to make that scope explicit. The owner-ledger scanner rejects its use from `BASHostKit`, `BASOrgan`, `BASMLXAdapter`, `BASAppleAdapters`, or Qinao generation paths. Once `TurnOperation` claims a Provider, it never asks the planner/registry for another ID. Capacity loss or a thrown Provider stream yields a typed terminal failure or query-only indeterminate state and an unfinalized spool.

Reduce `BASOrganRegistry` to `register`, `unregister(providerID:)`, `adapter(providerID:)`, `descriptor(providerID:)`, `descriptors`, and `count`. Delete both `adapter(for:)` overloads, registration-order routing, and neural-matrix selection. Registration order may remain only as deterministic descriptor presentation and must not affect execution.

- [ ] **Step 5A [W1]: Declare the typed TurnOperation handle and fail-closed port boundary**

Add nested `TurnOperation` value/handle surfaces to `BASTurnRuntimeEngine.swift`. W1 consumes the K3-installed `BASTurnOperationRef`, Contracts types, and injected `BASProviderBranchControlPort`, validates active Attempt/generation/epochs in focused in-memory tests, and never calls `UUID()`, reconstructs a root from text, or owns an ordinal/claim/terminal-source/visibility map. Shipping composition remains fail-closed and has no branch-allocation/Provider/spool call site in W1 because no W4 policy/binding or W5 release receipt exists. A reconstructed test handle may use only `providerBranchState(turnOperationRef:branchRef:)`; possible-start without terminal is query/reconcile-only.

- [ ] **Step 5B [W4]: Enable policy/binding-backed branch execution, source pin, and visibility**

Only after W4 atomically stores, jointly validates, and installs one `BASProviderBranchPolicy` artifact plus the one `BASSiliconExecutionBinding` that references it may the production initializer become available. It accepts the typed root, exact policy/binding Artifact IDs, Artifact Mesh governed-payload reopener, and injected port. For each permitted model step it completes preflight, ordinary-puts/reopens one `BASPersistedOrganDescriptorPayload` through `BASGovernedArtifactPayloadCodec`, then submits one `BASProviderBranchAllocationRequest` containing only `providerBranchPolicyArtifactID`, exact `stepRuleID`, requested output role, ordered causal receipt evidence, plan/binding membership proof, governed-parent `selectedProviderDescriptorArtifactID`, budget/deadline, and active Attempt facts. K3 reopens the policy and derives `BASProviderStepPurpose`; it treats that parent ID as opaque, persists it in the allocation row, and copies it exactly into allocation/claim receipts. The request contains no caller-supplied purpose, Provider-ID authority, descriptor bytes, containment projection, or copied policy limit. `TurnOperation` reopens/version-checks/unwraps the receipt-bound parent and exact-compares its embedded descriptor against the selected adapter before constructing `BASPlannedOrganRequest`, consumes the returned branch/ref, submits one claim, and creates a Provider child only for a newly won claim. A reconstructed handle can join a known live task/reopen a known terminal; possible-start is never reinvoked.

Every Provider phase/chunk/terminal carries the branch-bound execution ref and is accepted by the `TurnOperation`/engine actor's private transient unsealed `(nextSequence, digest)` CAS before it changes a projection. The configured bounded phase/checkpoint points call `sealProviderEventHead` to commit the contiguous event-hash head through the sole durable K3 writer, but ordinary token/chunk acceptance has zero synchronous durable writes. Crash drops the transient tail and leaves the durable claim indeterminate. `.groundingProposal/.internalProposal`, `.turnStep/.internalProposal`, and `.verifierProposal/.internalProposal` terminal payloads are stored only as proposal receipts and can trigger another branch only through a new K3 allocation whose ordered causes include that receipt (and, for tool continuation, the durable effect/result receipt).

Before invoking a `.turnStep/.terminalAnswerCandidate`, `TurnOperation` calls `designateTerminalSource`; only the winning receipt authorizes that exact branch to become the answer source. That branch is answer-only: its request contains no tool/effect schema, capability, or continuation surface, and any Provider tool/effect proposal is a protocol failure rather than permission to reopen the loop or select a sibling. It binds the deterministic `.provisionalStream/0` view to this source and follows exactly the installed `BASProviderBranchPolicy` artifact's frozen `BASProviderVisibilityMode`; the execution binding merely references that policy artifact:

- `.incrementalVerified`: before the physical terminal call, obtain the exact pre-call/incremental deterministic-verifier policy receipt bound to the pinned source, mode, plan, tokenizer/output constraints, and visibility epoch; then call `openProviderVisibilityGate` with that evidence. After the visibility receipt, only the already-claimed pinned source may cross its one physical-call seam, and each delta is exposed only after the declared incremental deterministic check; no other/new branch may allocate, claim, or start. On structurally valid terminal completion, seal the source event head and ordinary-put the shared Contracts `BASProviderBranchChainPayload(cut: .terminalPrefix)` through that pinned source. W4 then stops; it has no spool, terminal L10-over-spool receipt, through-visibility chain payload, release preparation, or publication capability.
- `.bufferedUntilVerified`: keep the pinned source completely hidden through terminal completion/seal, then ordinary-put the shared `BASProviderBranchChainPayload(cut: .terminalPrefix)` through that pinned source. Execute only policy-preauthorized `.verifierProposal/.internalProposal` branches causally bound to that source and retain their validated proposal receipts. **Stop hidden in W4.** Do not run terminal L10, call `openProviderVisibilityGate`, form the `.throughVisibility` cut, or emit buffered bytes here, because sovereign L10 must verify the exact W5 spool that does not yet exist.

`BASProviderVisibilityRequest` always binds the frozen mode and its exact evidence vector; a terminal-prefix chain artifact alone is insufficient, and runtime cannot silently switch modes. Only bytes from the pinned source may enter the W5 spool or L10. Failure/indeterminate after pin is terminal/reconcile-required; a sibling candidate cannot replace it. Silicon consumes, without redeclaring, the Contracts `BASProviderBranchLineageEntry`, `BASProviderBranchChainPayload`, and chain-cut enum: `.terminalPrefix` contains the exact root/policy/binding, ordered complete branch entries through the pinned source, and canonical `terminalSourceReceiptArtifactID` but no L10/visibility closure; `.throughVisibility` additionally binds every authorized post-pin verifier entry plus exact L10 and visibility receipts. The relationship is never a field inside the through payload: validators reopen both payloads and require equal root/policy/binding/source facts plus byte-identical equality between the prefix payload's full `orderedEntries` and the corresponding leading slice of the through payload's `orderedEntries`.

- [ ] **Step 5C [W5 consumption]: Spool the terminal-prefix bytes, then close verification and visibility**

Consume the sovereign W5 prerequisite's sole `BASProviderReleaseEvidenceReference` declaration from the existing `BASResponsePublicationContracts.swift`; Silicon must not declare, extend, or edit that shared type. The sovereign value contains exactly four Artifact IDs—terminal-prefix chain, through-visibility chain, response spool, and release preparation—with no self ID, root/source/execution/receipt/branch/policy/role/lineage copy and no capability. Runtime/result/manifest reuse it rather than copying release facts. A publishable result must carry the whole group and reopen/equality-check all four artifacts; an early refused/deferred/cancelled/reconcile result with no completed release carries `nil`, never placeholder IDs.

W4 cannot create or publish a spool. W5 reopens the exact `.terminalPrefix` chain artifact, canonical terminal-source/terminal receipts, terminal `BASProviderExecutionRef`, provisional/final branch refs, and byte digest. It first constructs one self-ID-free, explicitly non-publishable `BASResponseSpoolPayload` from those exact pinned-source bytes and ordinary-puts it once. The spool carries `terminalPrefixProviderBranchChainArtifactID` only—never a `.throughVisibility` artifact ID or future L10/visibility receipt. Only then does `spoolArtifactID` exist; K3 binds the returned ID once to the same source and `.finalPublication/0`. A sibling/later branch or second/precomputed/Provider-supplied spool ID fails closed.

The sovereign verifier now runs terminal L10 over the exact reopened spool bytes and produces an acceptance receipt bound to that spool/root/source/execution/prefix:

- `.incrementalVerified`: equality-check the already-open W4 visibility receipt and every incremental verifier receipt against the spool, L10 acceptance, policy, and source. Ordinary-put one shared `BASProviderBranchChainPayload(cut: .throughVisibility)` whose closure contains the L10 plus visibility evidence; do not open a second gate or emit a second stream. Reopen that new payload and the payload at `terminalPrefixProviderBranchChainArtifactID`; require exact root/policy/binding/source equality and require the prefix payload's complete `orderedEntries` array to equal the leading slice of the through payload's `orderedEntries`. Do not add a `terminalPrefix` field to the through payload.
- `.bufferedUntilVerified`: equality-check the W4 post-pin verifier proposal entries/receipts against the same spool and L10 acceptance, then call `openProviderVisibilityGate` with that complete evidence. Only its newly won receipt permits the exact buffered spool bytes to be emitted once. Ordinary-put the `.throughVisibility` chain payload including those verifier entries, L10 receipt, and visibility receipt.

Finally W5 creates `BASExactReleasePreparationPayload` bound to `spoolArtifactID`, `throughVisibilityProviderBranchChainArtifactID`, the proven terminal-prefix relationship, mode/visibility receipt, pinned source, exact terminal execution ref, and `.finalPublication/0`. The spool is always pre-publication evidence; in buffered mode it is also pre-visibility, while incremental mode's gate was already opened once in W4. Release preparation is the publishable handshake. Runtime/release owns publication and `final()` waiting; Silicon introduces no publication journal/coordinator. `runTurn(_:)` may delegate to `beginTurn(request).final()` only after this W5 hookup.

Cancellation of one UI observer detaches that observer only. Cancellation of the operation owner cancels the provider task, joins ticket/lease cleanup, leaves the spool unfinalized, and returns one typed cancellation. There is no detached decode task and no `defer`-based async cleanup.

Update `QinaoStreamingOrganEndpoint.swift` and `QinaoLoop.swift`: delete the documented “stream, then call generateCandidates with the same prompt” flow and remove prompt-based production overloads that can silently start independent turns. `beginTurn(sessionID:prompt:context:role:)` may retain `sessionID` only as a source-compatible lookup argument; HostKit resolves it to the already-installed `BASTurnOperationRef` and returns one `QinaoTurnOperation` handle carrying that root. Grounding/tool/verifier continuation methods submit typed causal inputs to `TurnOperation`, which alone consumes `BASProviderBranchControlPort` allocation/claim receipts; Qinao never chooses an ordinal, purpose/output role, terminal source, or visibility state and never invokes a Provider directly. `generateCandidates(operation:)` waits on the handle's pinned-source `finalResponse`; `streamBody(operation:)` observes only its ordinal-zero provisional stream; frontier scoring consumes that same final response and never calls `produceBody` again. A convenience API may create an operation and choose one view, but it cannot correlate by prompt/session or regenerate a canonical result. Carry `turnOperationRef`, the exact shared `.terminalPrefix` and `.throughVisibility` Provider-chain Artifact IDs, pinned `terminalAnswerSourceBranchRef`, `provisionalStreamBranchRef`, `finalPublicationBranchRef`, terminal `providerExecutionRef`, `planID`, router/fallback identity, `spoolArtifactID`, and release-preparation ID through the terminal Qinao response/audit projection. Reopen the shared chain payloads for ordered branch details; do not copy a lossy local receipt-ID list. Any exposed legacy `operationID` is a read-only compatibility encoding that must round-trip to the root and cannot be accepted back as authority.

- [ ] **Step 6 [W4]: Actuate the exact plan in MLX, Foundation Models, and Core AI adapters**

In MLX, apply the plan's model identity at load, `stepSize` at the actual prefill call, `kvBits/maxKVSize` at session/cache construction, and the exact elected decode strategy at both eager and UI-stream views. Remove `.scoutDefault` from the stream path and any purpose/decode re-election below `executePlanned`. Load/prewarm/session reuse emits explicit reused-phase receipts. Prompt lookup, Qwen 3.5 MTP, and plain decode remain executor branches selected by the frozen plan; none owns fallback or a second spool.

`AppleFoundationOrganAdapter` and `BASCoreAIModelRunner` implement the same planned event contract in `BASAppleAdapters`. Unsupported axes return a preflight capability denial before claim. Core AI cannot enter the authorized provider list until its exact model/backend profile is certified, but its implementation and evidence stay outside Qinao. Foundation Models' system model identity is explicit in its descriptor/manifest projection; it cannot become the open-model default by registration order.

- [ ] **Step 7 [W1 provider inversion; W4 shared-resource bind]: Make the manifest the only default and move concrete providers out of Qinao**

**W1 provider-inversion portion:**

Keep `BASModelManifestRegistry.productionDefault == qwen35_4B_4bit`. Rename `MLXModelCatalog.defaultEntries` to `certifiedEntries`; it is a catalog projection, not a default. Add `MLXModelCatalog.entry(for manifest: BASModelCapabilityManifest)` and make the MLX host factory resolve the selected manifest through it. Delete `QinaoMLXModel` and every default argument naming Gemma/Llama/Qwen outside the manifest registry.

Delete Qinao's `QinaoMLX` and `QinaoAppleFoundation` targets/products and their concrete factory files. `QinaoLoop` keeps only provider-neutral endpoint/operation protocols and the identity bridge. During W1, `QinaoSovereignHostAssembly` accepts an already-constructed provider-neutral endpoint and has no concrete model selection/import; it does not yet mention the W4 memory type. Host binding to the process-shared ledger is deliberately deferred to W4.

- [ ] **Step 7A [W1]: Prove and commit the contracts/TurnOperation/Provider-inversion receipt**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASTurnOperationOwnershipTests|BASProviderBoundaryTests|BASOrganRegistryTests|BASPersistedOrganDescriptorPayloadTests|BASEBrainSchemaGovernanceRegistryTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoProviderBoundaryTests|QinaoRuntimeSendSessionStreamingTests'
swift test --package-path "$ROOT/BehavioralAISubstrate"
swift test --package-path "$ROOT/QinaoRuntimeSDK"
test "$(rg -n 'public static let productionDefault' \
  "$ROOT/BehavioralAISubstrate/Sources" | wc -l | tr -d ' ')" = 1
! rg -n 'adapter\(for:|registryDefault|neuralMatrix' \
  "$ROOT/BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift"
! rg -n 'QinaoMLX|QinaoAppleFoundation|QinaoMLXModel|BASMLXAdapter|BASAppleAdapters|MLXOrganAdapter|AppleFoundationOrganAdapter|BASCoreAI' \
  "$ROOT/QinaoRuntimeSDK/Package.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources"
! rg -n 'streamBody.*generateCandidates|generateCandidates.*streamBody|streamDraft\(|\.draft\(' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoLoop"
test "$(rg -n 'pinnedEntry\("BASPersistedOrganDescriptorPayload"' \
  "$ROOT/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift" | wc -l | tr -d ' ')" = 1
if rg -n 'BASOrganDescriptor\(' "$ROOT/BehavioralAISubstrate" "$ROOT/QinaoRuntimeSDK" "$ROOT/SampleHost" --glob '*.swift' \
  | while IFS=: read -r file line rest; do sed -n "${line},$((line + 20))p" "$file" | rg -L 'containmentClass:'; done \
  | rg .; then
  exit 1
fi

DESCRIPTOR_CALLSITE_FILES=()
while IFS= read -r -d '' path; do
  DESCRIPTOR_CALLSITE_FILES+=("$path")
done < <(rg -l -0 'BASOrganDescriptor\(' \
  "$ROOT/BehavioralAISubstrate" "$ROOT/QinaoRuntimeSDK" "$ROOT/SampleHost" --glob '*.swift')

git -C "$ROOT" add -- "${DESCRIPTOR_CALLSITE_FILES[@]}" \
  BehavioralAISubstrate/Sources/BASOrgan/BASOrganAdapter.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASPersistedOrganDescriptorPayloadTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderPlanningCore.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift \
  BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift \
  BehavioralAISubstrate/Sources/BASMLXAdapter/MLXModelCatalog.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationOwnershipTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderBoundaryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASOrganRegistryTests.swift \
  QinaoRuntimeSDK/Package.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoStreamingOrganEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/BASOrganRegistryEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoDefaults.swift \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift \
  QinaoRuntimeSDK/Sources/QinaoSample/SampleProvider.swift \
  QinaoRuntimeSDK/Sources/QinaoSample/SampleSession.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLoRAExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostLongSmokeBenchExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/main.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoProviderBoundaryTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationAuditChainTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationConcurrencyTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationFactoryTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationFurnaceChainTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationGateChainTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationMemoryChainTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationRiskGateTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoAppleFoundationWorldPriorChainTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoLoopStreamBodyTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMLXSpeculativeSurfaceTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleHostFlowTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSampleSessionTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSendSessionStreamingTests.swift
git -C "$ROOT" add -u \
  QinaoRuntimeSDK/Sources/QinaoMLX/QinaoMLXEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoAppleFoundation/QinaoAppleFoundationEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoSampleHost/SampleHostMLXExtensions.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoMLXEndpointTests.swift
git -C "$ROOT" diff --cached --check
git -C "$ROOT" commit -m "refactor: establish one provider turn operation"
```

Expected W1 receipt: one typed operation root and the shared K3 Provider-branch value/port contract compile with fake/provider-neutral adapters; reconstructed/duplicate claims fail closed and the shipping composition has zero branch-allocation, physical Provider, source-pin, visibility, spool, or final-publication call sites. The registry is identity-only; Qinao has no concrete model target/import/default or locally continued generation; and this commit contains neither W4 M owner/actuation nor W5 response-publication contract/test. Do not begin W2 while any W1 owner key is red.

**W4 shared-resource portion (only after W2 and W3 receipts and after W4 Tasks 2 and 5 pass):** Existing SampleHost and DeviceTestApp composition files import `BASMLXAdapter`/`BASAppleAdapters`, build the concrete provider, register it by explicit ID, bind it to the shared ledger/gateway, and inject the resulting endpoint into Qinao.

In `QinaoSovereignHostAssembly.swift`, make the production factory obtain the shared resource once and pass it to the host's provider closure:

```swift
public static func makeProduction(
    providerEndpointFactory: @Sendable (
        BASProcessMemoryLedger
    ) async throws -> any QinaoOrganEndpoint
) async throws -> QinaoSovereignHostAssembly {
    let sharedLedger = BASProcessMemoryLedger.processShared
    let endpoint = try await providerEndpointFactory(sharedLedger)
    return try await makeProduction(
        endpoint: endpoint,
        memoryLedger: sharedLedger)
}
```

The private overload passes that exact actor to runtime memory scopes and does not construct a ledger. The host closure binds the same actor to the silicon gateway used by its concrete adapter. “HeavySeat” is the ledger's `heavy-active` projection; do not introduce `HeavySeatManager`, a semaphore, a second actor, or a Qinao-local owner map.

Freeze the existing `QinaoSeatResidencyManager` as a dormant, rebuildable, read-only **logical scheduling/test projection** under owner `resource.process-memory-ledger`; it is not a residency or resource authority despite its legacy name. Remove production-callable `wakeup`, `sleep`, factory capture/registration, mutable instance cache, and any path that constructs a seat. Its retained query projection may describe configured hot/cold intent for tests, but it cannot import Provider/MLX/Metal/ledger modules, retain a concrete or `@Sendable` heavy-seat factory, register/unregister an implementation, start/stop work, reserve/activate memory, decide HeavySeat eligibility, or grant memory-admission authority. The one production residency truth is the injected `BASProcessMemoryLedger.processShared` plus the signed silicon gateway; the dormant projection is reconstructible from immutable seat metadata and its loss cannot affect execution. `QinaoSeatResidencyManagerTests` assert pure deterministic projection/rebuild behavior. `QinaoSeatFabricDormancyBoundaryTests` source-scan every non-test Qinao source and fail on manager construction, `.wakeup(`, `.sleep(`, seat-factory capture, Provider/MLX/Metal/`BASProcessMemoryLedger` imports/references in the manager, or production registration calls. No compatibility overload may silently keep the old actuation path.

- [ ] **Step 8 [W4]: Run GREEN, structural guards, and device smoke**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASTurnOperationOwnershipTests|BASExecutionPlanActuationTests|BASProviderBoundaryTests|BASOrganRegistryTests|BASExecutionPlanElectorTests|MLXOrganAdapterTests|AppleFoundationStreamingTests|BASMLXUnifiedLeaseTests|BASEBrainSchemaGovernanceRegistryTests'
swift package --package-path "$ROOT/BehavioralAISubstrate" dump-package >/dev/null
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoProviderBoundaryTests|QinaoRuntimeSharedResourceTests|QinaoSeatResidencyManagerTests|QinaoSeatFabricDormancyBoundaryTests|QinaoRuntimeSendSessionStreamingTests'
swift test --package-path "$ROOT/BehavioralAISubstrate"
swift test --package-path "$ROOT/QinaoRuntimeSDK"
swift build --package-path "$ROOT/SampleHost"
test "$(rg -n 'public static let productionDefault' "$ROOT/BehavioralAISubstrate/Sources" | wc -l | tr -d ' ')" = 1
! rg -n 'adapter\(for:|registryDefault|neuralMatrix' \
  "$ROOT/BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift"
! rg -n 'QinaoMLX|QinaoAppleFoundation|QinaoMLXModel|BASMLXAdapter|BASAppleAdapters|MLXOrganAdapter|AppleFoundationOrganAdapter|BASCoreAI' \
  "$ROOT/QinaoRuntimeSDK/Package.swift" \
  "$ROOT/QinaoRuntimeSDK/Sources"
! rg -n 'streamBody.*generateCandidates|generateCandidates.*streamBody|streamDraft\(|\.draft\(' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoLoop"
! rg -n 'scoutDefault' \
  "$ROOT/BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+Streaming.swift"
test "$(rg -n 'BASProcessMemoryLedger\(' "$ROOT/QinaoRuntimeSDK/Sources" | wc -l | tr -d ' ')" = 0
rg -q 'BASProcessMemoryLedger\.processShared' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift"
! rg -n 'QinaoSeatResidencyManager\(|\.wakeup\(|\.sleep\(' \
  "$ROOT/QinaoRuntimeSDK/Sources" \
  --glob '!QinaoSeats/QinaoSeatResidencyManager.swift'
! rg -n 'QinaoSeatFactory|BASProcessMemoryLedger|HeavySeat|BASMLX|MLX|Metal|Provider|func (wakeup|sleep)\b|register\(' \
  "$ROOT/QinaoRuntimeSDK/Sources/QinaoSeats/QinaoSeatResidencyManager.swift"
```

Expected W4: owner ledger returns `status: pass` with all declared owner keys checked; all focused/full suites and SampleHost build pass; scans find one model default, identity-only registry, no Qinao concrete model/provider code, no stream/eager double-generation call, no stream-local decode re-election, no Qinao ledger construction, and no production-callable seat residency factory/wake/sleep/registration path. `QinaoSeatResidencyManager` remains only a deterministic read-only logical projection and cannot grant HeavySeat or memory-admission authority. The W4 diff contains no `BASResponsePublicationContracts.swift` or `BASProviderExecutionSpoolTests.swift`; buffered mode ends hidden with terminal-prefix/verifier evidence and incremental mode has one pre-call gate but no spool/release preparation.

Run one physical iOS 27 smoke with a cold Qwen 3.5 4B operation and one warm streamed operation. The receipt must show one physical invocation and four exact phase receipts for every newly won Provider branch claim, a bounded causal branch count matching the binding, exactly one pinned terminal-answer source, and zero calls for repeated claims. The warm stream must reuse residency/cache explicitly, match eager final bytes from that pinned source, use one spool/final, and end with zero heavy reservations.

```bash
test -n "$BAS_IOS27_DEVICE_UDID"
xcodebuild \
  -project "$ROOT/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj" \
  -scheme BASDeviceTestApp \
  -destination "platform=iOS,id=$BAS_IOS27_DEVICE_UDID" \
  test \
  -only-testing:BASDeviceTests/BASChapter952RealMLXOnDeviceTests/testTurnOperationExactlyOncePlanActuation
```

Expected: the test passes on physical iOS 27; cold and warm outputs carry the manifest default model ID and identical plan/router/fallback identity across stream/eager views. This smoke proves integration only; the runtime/replay plan owns the later two-device 40/30 certification.

- [ ] **Step 9 [W4]: Commit the silicon-actuation delta**

```bash
git add docs/superpowers/specs/qinao-owner-ledger-v1.json scripts/check_qinao_owner_ledger.py \
  BehavioralAISubstrate/Package.swift BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderPlanningCore.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift BehavioralAISubstrate/Sources/BASOrgan \
  BehavioralAISubstrate/Sources/BASOrgan/BASOrganAdapter.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Sources/BASMLXAdapter BehavioralAISubstrate/Sources/BASAppleAdapters \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASChengluHostRuntimeBuilder.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASOrganRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  QinaoRuntimeSDK/Package.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop QinaoRuntimeSDK/Sources/QinaoDefaults \
  QinaoRuntimeSDK/Sources/QinaoSeats/QinaoSeatResidencyManager.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSeatResidencyManagerTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSeatFabricDormancyBoundaryTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSharedResourceTests.swift \
  SampleHost/SampleHostBASHostInvocation.swift \
  BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift
git diff --cached --check
git commit -m "feat: actuate one certified silicon execution plan"
```

- [ ] **Step 10 [W5]: Verify and commit the terminal-prefix spool/release handoff separately**

Require the sovereign K4/release/Zone-C receipt before editing. Reopen both shared `BASProviderBranchChainPayload` artifacts and run the exact two-mode tests:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
test -s "${BAS_W5_SOVEREIGN_RELEASE_RECEIPT:?set the verified W5 receipt path}"
python3 "$ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$ROOT" \
  --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift test --package-path "$ROOT/BehavioralAISubstrate" \
  --filter 'BASProviderExecutionSpoolTests|BASPrePublicationManifestBarrierTests|BASSovereignReleasePreparationTests'
swift test --package-path "$ROOT/QinaoRuntimeSDK" \
  --filter 'QinaoProviderBoundaryTests|QinaoRuntimeSendSessionStreamingTests'
! rg -n 'throughVisibilityProviderBranchChainArtifactID.*BASResponseSpoolPayload|BASResponseSpoolPayload.*throughVisibilityProviderBranchChainArtifactID' \
  "$ROOT/BehavioralAISubstrate/Sources"
```

Expected: incremental mode reuses exactly one pre-call visibility receipt and never emits a second stream; buffered mode remains hidden until the exact spool passes L10 and the gate opens. Both modes ordinary-put one spool bound only to immutable `terminalPrefixProviderBranchChainArtifactID`, then one release preparation bound to immutable `throughVisibilityProviderBranchChainArtifactID`; the shared validator reopens both chain payloads and proves the exact ordered-entry prefix relation. K3 event/coverage heads remain separately validated authority. Wrong prefix relation, policy/binding/root/source/execution ref, verifier entry, L10 receipt, visibility receipt/mode, byte digest, or final branch fails before publication. No second spool, gate, generation, mutable chain head, or local lineage type exists.

```bash
git add \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngineConfiguration.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProviderExecutionSpoolTests.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoStreamingOrganEndpoint.swift \
  QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeSendSessionStreamingTests.swift
git diff --cached --check
git commit -m "feat: bind terminal spool to sovereign release"
```

## Completion Gate

- [ ] Immutable wave receipts prove strict W0 → W1 → W2 → W3 → W4 execution; W5 is then supplied by the sovereign release plan and W6 by the runtime/certification plan. No task's physical section order or combined commit bypassed a wave boundary.
- [ ] `scripts/check_qinao_owner_ledger.py` passes against `docs/superpowers/specs/qinao-owner-ledger-v1.json`; the ledger declares every production owner and every allowed production Create in this plan.
- [ ] One `TurnOperation` owns one K3-installed `BASTurnOperationRef`, one bounded causal chain of K3-allocated Provider-egress branches, one execution-binding root, one pinned terminal-answer source, and one spool/final lifecycle. Each branch allocation/claim binds one ordinary-put governed `BASPersistedOrganDescriptorPayload` Artifact ID and one complete sequence-zero execution ref; event refs use only checked `withRequestSequence(next)` while preserving the six stable base fields. Each newly won branch claim invokes one physical Provider exactly once; repeated/indeterminate claims invoke none, and no raw UUID/string/local counter can create another root, branch, role, claim, source pin, or visibility transition.
- [ ] Grounder/turn-step/verifier egresses use exact purpose plus independent output role; all intermediate results remain proposal-only. Tool continuation remains under the same root and requires K3 allocation causally bound to the durable effect/result receipt.
- [ ] Stream and eager views share the same root, exact immutable terminal-prefix and through-visibility chain Artifact IDs, pinned terminal egress, terminal `BASProviderExecutionRef`, ordinal-zero `.provisionalStream`/`.finalPublication`, terminal plan/router/fallback identity, spool, verifier, and finalization. K3 event/coverage heads remain separate validated authority. After pin no sibling can replace the source; after UI visibility no new Provider branch starts.
- [ ] The public `BASProviderBranchControlPort` remains exactly the sole six-method allocation/claim/seal/terminal-source/visibility/state boundary; Silicon owns no parallel maps/port/receipt aliases. The only extra W5 operation is package-only `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` on the same injected concrete `BASSQLiteEventLogStorage` object, whose newly won armed→`sent_or_unknown` CAS is the sole callable transport hand-off; no public K3 protocol exposes it. `TurnOperation`/the engine actor owns only the transient unsealed `(nextSequence, digest)` CAS; K3/SQLite alone owns durable allocation, claim, checkpoint-head, and terminal seals. Crash drops the transient tail and leaves the claim indeterminate; no per-token/chunk SQL/fsync/Artifact-Mesh write or seventh K3 API exists.
- [ ] `BASOrganDescriptor` remains the sole Codable descriptor domain value. Task 7 Step 0/W1 makes one source-breaking, inventory-complete addition of required canonical `BASProviderContainmentClass` before the first `BASPersistedOrganDescriptorPayload` v1 fixture/put; every constructor is migrated explicitly in that W1 receipt. Task 3 W4 and Task 7 W4/W5 only consume the frozen schema. Preflight embeds it in the same-file parent; only that governed parent is codec-written, registered, and K3-bound. `BASPlannedOrganRequest` plus the executor reopen/version-check/unwrap it and exact-compare the descriptor to the adapter. No default/inference, second wrapper, descriptor field in binding/lineage, descriptor registry/store, caller-loose Provider ID, or changed `BASProviderExecutionRef` tuple exists.
- [ ] Local seal requests/receipts carry nil arm/observation IDs. Isolated/remote begins hand-off once, remains `sent_or_unknown` unless the existing event-head-seal transaction reopens a complete supervisor-authored `BASProviderObservedReceipt`, exact arm, allocation/claim/descriptor, and atomically advances to `terminal_or_indeterminate`. Lost/unqueryable evidence cannot seal/spool/publish; recovery may feed recovered evidence to the same seal but performs zero resends. `BASProviderObservedReceipt` extends `BASLowEntropyPrimitives.swift`; Qinao endpoint code only constructs it, and no second observation owner/state/CAS/lineage/manifest field exists.
- [ ] Every successful provider result has exact ordered load/prefill/cache/decode receipts matching `BASExecutionPlan`; no phase is merely elected or re-elected in an adapter.
- [ ] `BASOrganRegistry` is an identity store only; `ProviderPlanningCore` is the only router and `ProviderExecutionCore` is the only provider-invocation primitive.
- [ ] `BASModelManifestRegistry.productionDefault` is the single default and resolves Qwen 3.5 4B; catalogs and Qinao define no competing default.
- [ ] Qwen/MLX, Foundation Models, and Core AI concrete implementations live outside Qinao SDK. Qinao contains only provider-neutral protocols/bridges and accepts host injection.
- [ ] The Qinao production factory obtains `BASProcessMemoryLedger.processShared` once, passes that exact actor to host provider composition and runtime scopes, and constructs no separate HeavySeat or memory ledger.
- [ ] `QinaoSeatResidencyManager` is frozen as a dormant, read-only, rebuildable logical scheduling/test projection: production cannot construct it or call wake/sleep/register; its source captures no heavy factory and imports/names no Provider, MLX, Metal, memory ledger, HeavySeat, or admission authority. `QinaoSeatResidencyManagerTests` and `QinaoSeatFabricDormancyBoundaryTests` pin that boundary under owner `resource.process-memory-ledger`.
- [ ] Focused/full Swift suites, owner/negative scans, SampleHost build, generic iOS build, and the physical iOS 27 exactly-once actuation smoke all pass before the runtime/replay certification plan begins.
