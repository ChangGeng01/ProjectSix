# iPhone Air → Future Apple Silicon 14-Layer System Architecture Design

**Status:** Final Qinao cognitive-substrate convergence locked after adversarial review; implementation conformance remains `REVISE`
**Date:** 2026-07-14; final convergence revision 2026-07-16
**Scope:** Current iPhone Air/A19 Pro baseline, iOS 27 minimum across every workspace-owned iOS package slice/app/extension target, and capability-driven future Apple Silicon
**Decision:** Adopt a capability-driven backend portfolio under invariant semantic, quality, state, and sovereign contracts

## 1. Executive Decision

The architecture is fixed on four independent axes plus seven orthogonal views:

> **14 Semantic LayerCores own semantic authority; 4 Physical Kernels own shared mechanisms; 4 bounded ControlRings own feedback cadence; 7 top-level planes describe orthogonal system views. Silicon Capability Fabric connects capabilities and evidence across planes without becoming an eighth plane.**

The four counts must never be added together:

- `14` is exactly the semantic layer count, `L1` through `L14`.
- `4` Physical Kernels are software mechanism, deployment, resource, and fault-ownership domains; they are not Apple CPU/GPU cores.
- `4` ControlRings are bounded feedback protocols; they are not semantic layers or mutable-state owners.
- `7` planes are orthogonal views; they are not serial pipeline stages.

The selected runtime direction is:

- Qinao is the model-neutral deterministic application substrate. It owns protocol, authority, state, planning, verification, audit, recovery, and host integration; every LLM/runtime remains outside the SDK behind a constrained Provider/Proposal boundary.
- The host's signed default profile selects Qwen3.5-4B through an external certified MLX/Metal Provider. Qwen3.5-4B is never hard-coded as an SDK default and a Provider cannot mutate authoritative state.
- Core ML is used only for separately certified microheads.
- Core AI is a research/certification lane until exact model, quality, StateABI, memory, thermal, and recovery gates pass.
- Future devices are admitted by observed capability and exact evidence profile, never by speculative `if A20/A21` chip-name branches.
- A turn has one authoritative heavy backend owner per phase. Healthy Apple Silicon utilization means best verified goodput, energy, memory, latency, and recovery behavior—not simultaneously saturating CPU, GPU, Neural Accelerators, and Neural Engine.

The final verdict is deliberately split:

| Question | Verdict |
|---|---|
| Is the revised architecture internally consistent under the abstract fault model? | **PASS** |
| Does current production code conform to this complete architecture? | **REVISE** |
| Can current iPhone Air promise general or sustained `40 tok/s`? | **NO; thermally-cold resident accepted-decode 40 is an UNVERIFIED workload-qualified stretch target** |
| Can current iPhone Air promise sustained `30 tok/s`? | **NO under current evidence** |

`PASS` in this document never means that the future architecture is implemented or production-certified.

## 2. Goal

Design a complete on-device cognitive runtime that:

1. preserves the exact 14-layer semantic doctrine;
2. gives every semantic decision, mutable mechanism, feedback loop, and hardware adapter one clear boundary;
3. allows deep cooperation through typed immutable artifacts and attenuated capabilities rather than hidden callbacks;
4. extracts the best healthy performance from current and future Apple Silicon;
5. preserves full model quality under thermal, memory, cache, backend, helper, and effect failures;
6. makes retrieval, generation, verification, external effects, and state evolution crash-recoverable and auditable;
7. can evolve across iOS and silicon generations without changing semantic authority or silently weakening quality.

## 3. Non-Goals

This design does not:

- claim the target architecture already exists in the repository;
- define an implementation task sequence or authorize production code changes;
- promise 40 tok/s on every prompt, context length, sampling policy, thermal state, or OS build;
- treat requested Core ML/Core AI compute units as proof of actual ANE placement;
- promise general exactly-once semantics for arbitrary external effects;
- invent public APIs for P/E-core pinning, ANE utilization, thermal-frequency control, or hard silicon reservations;
- make a new smaller, lower-bit, fixed-expert, or separately trained model a thermal fallback for the current full-quality model lineage;
- let a model/Provider read Qinao's SQL stores, StateLake, tool credentials, actors, or mutable state directly; select its own routing/authorization; or publish a proposal as truth;
- create one physical model runtime, scheduler, or database owner per logical context window;
- turn Silicon Capability Fabric, Effect Broker, Input Normalizer, or an operator recovery root into another semantic layer or Physical Kernel.

## 4. Evidence and Repository Truth

### 4.1 Evidence grades

Every runtime profile, optimization, and public performance claim carries one grade:

| Grade | Meaning |
|---|---|
| `E0` | Design or schema only |
| `E1` | Pure-function or canonicalization unit evidence |
| `E2` | Simulator or local functional evidence |
| `E3` | Reproducible evidence from one physical device and one OS/runtime build |
| `E4` | Multi-device, multi-cohort evidence including cold/warm cache, thermal, memory, revocation, helper crash/upgrade, and effect fault injection |
| `E5` | Controlled production canary with rollback, revocation, and incident drill |

A production `ModelExecutionProfile` requires at least E4. A cache hit, architecture label, API availability check, or microbenchmark cannot promote a backend.

### 4.2 Current iPhone Air public facts

Apple currently specifies iPhone Air with:

- A19 Pro;
- 6-core CPU: 2 performance and 4 efficiency cores;
- 5-core GPU with Neural Accelerators;
- 16-core Neural Engine;
- Apple C1X cellular modem and N1 wireless networking chip.

These public facts describe available hardware, not third-party scheduling authority. The app can request work through public frameworks and observe supported signals, but it cannot reserve silicon, pin arbitrary work to P/E cores, prove ANE utilization from a compute-unit preference, or command thermal frequency.

### 4.3 Current repository truth to preserve

The repository already contains valuable foundations:

- stable `L1...L14` identities and naming assets;
- MLX/Metal as the real 4B decode hot path;
- `BASDecodePlanner` and never-worse/acceptance concepts;
- thermal sampling, memory-cap modeling, pressure-ladder primitives, prefix/session state, and device evidence ledgers;
- sovereign token and signature foundations;
- SQLite event-log transactions;
- Core AI shadow/research gates;
- NAX-capable vendored MLX paths.

These are foundations, not proof of conformance. Current code also contains structural gaps that the target design must not disguise:

- `BASExecutionPlan` elects more than it actuates; load, prefill, and cache decisions are not one authoritative production spine.
- native-v2 stage closures can have outputs discarded before the v1 coordinator runs, creating future double-compute or double-effect risk when closures become real.
- multiple routing authorities overlap: execution plan, hardware scheduler, device routing, and MLX decode planner.
- live memory headroom is observed but not consistently used for admission.
- current ANE capability records contain estimates that are not direct hardware observations.
- requested tensor backing or compute units do not prove physical placement.
- the current `.statelake` reader is a neural NDArray/tensor-state format, not the semantic multi-lane memory system specified here.
- sovereign issuance, nonce, spent, and consumed-bundle state is currently in memory in important paths.
- the current Ed25519 raw seed is stored as a Keychain generic password and reconstructed in process; that is Keychain at-rest protection, not a non-exportable Secure Enclave Ed25519 key.
- no production implementation yet exists for the complete Artifact Mesh, Capability Mesh, LayerCell membrane, durable Effect Broker, StateABI fallback graph, or unified MemoryLedger described here.
- `QinaoRuntimeSDK` currently publishes concrete `QinaoMLX` and Apple Foundation Models products/targets and exposes a raw-string organ endpoint; the target boundary must be inverted so concrete model/runtime packages depend on the SDK contracts, never the SDK on a concrete LLM runtime.
- the current host turn request has no canonical workspace/window/generation identity, the prompt cache is substantially keyed by two hashes, and the current commit gate is shape-oriented rather than an authority/snapshot/effect proof.
- workspace-owned package manifests and the Rust XCFramework build script still contain iOS 18 deployment declarations. The product decision is iOS 27 minimum, so every app/package/extension/binary slice and emitted Mach-O minimum must converge before implementation can claim conformance.

The code audit captured these concrete ship blockers at the review snapshot:

| Area | Repository evidence | Target disposition |
|---|---|---|
| execution actuation | `BASExecutionPlan` explicitly limits actuation while load/prefill/cache remain elected; production sources do not show one universal elector→actuator spine | one typed plan owns load through receipt |
| admission | `BASExecutionPlanElector` observes memory headroom but admission is still dominated by static profile estimates; a non-fit plain plan can still exist | dynamic resident+transient reservation must reject before load |
| session path | `MLXOrganAdapter` session decode has paths that bypass or diverge from the shared planner/fallback behavior | every entry point consumes the same exact plan/executor |
| MTP recovery | stateless execution has a plain recovery path, while fused/session paths do not uniformly prove the same catch, rollback, and hysteresis | one fallback state machine and rollback receipt |
| target/speculation state | current trunk checkpoint/session persistence does not bind the complete pending-token/RNG/sampler/grammar state, and draft paths can mutate cache before rejection rollback | one logical target checkpoint/version; generation-isolated disposable scratch; accepted-receipt CAS is the only advance |
| dual runtime | `BASNativeStageExecutor` can execute closure-shaped stages whose outputs are not the authoritative turn result, followed by unconditional coordinator execution | one typed result owner; shadow work is explicitly non-authoritative |
| hardware scheduler | assignments describe backing/kernel/cost, while latency multipliers and ANE capacity fields include estimates | split raw observation, certified profile, policy preference, and actual receipt |
| model default | capability manifest and zero-argument MLX adapter name different production-default model families | one signed bundle/profile selection SSOT |
| SDK/model boundary | `QinaoRuntimeSDK/Package.swift` publishes `QinaoMLX`; `QinaoOrganEndpoint` is raw-string shaped; proposal adoption and commit checks do not yet enforce the complete authority closure | move concrete Qwen/MLX implementation outside the SDK; add value-only Provider/Proposal contracts and deterministic adoption gates |
| workspace/attempt identity | `EBrainTurnRequest` lacks workspace/window/generation/attempt binding; prompt/session artifacts can outlive the semantic snapshot that justified them | one `ContextWorkspaceRef` + `AttemptRef` + active-attempt CAS fence on every derived artifact and capability |
| pressure behavior | pressure-ladder actuation is feature-gated in important paths; pressure can quantize session KV despite known continuation divergence | production-default ledger policy; no unqualified identity-changing fallback |
| state reader | `BASStateLakeReader` performs neural tensor-state reads with multiple potential transient representations | rename/reframe as NeuralStateCache I/O and stream/map under ledger |
| retrieval fusion ABI | a pure Rust RRF implementation exists in `bas-retrieval-ranker`, while the current C ABI exposes other fusion operations rather than that RRF production call | extend the existing narrow Rust ABI/Swift bridge with byte/parity tests; do not add another ranker |
| semantic memory | existing cognition/memory paths can collapse candidates into a ranking pool and lose scope/sensitivity in projections | snapshot lanes, hard eligibility, typed conflict, preserved projection labels |
| mesh | `BAS14LayerMeshMap` is declared zero-behavior-change with no production semantic/capability spine; reference actors/hooks are not the authoritative path | migrate behind LayerCell contracts without claiming current conformance |
| kill/revoke | layer kill and production kill-switch identities are split and lack one pervasive generation check | one monotonic epoch checked through queue, dispatch, receipt, and seal |
| capability default | at least one adapter treats an empty allowed-domain set as permissive | empty/missing authority is deny |
| sovereign state | `BASSovereignTokenAuthority` and relevant consumed-bundle paths retain in-memory issuance/spend state | helper-private transactional durable ledger |
| receipt semantics | current control-plane receipts lack exact effect/profile/adapter/idempotency/seal state; some coordinator paths synthesize generic execution | expanded signed operation receipt and durable saga |
| state folding | SQLite event append has a strong transaction foundation, but convenience folding paths can start from zero, ignore duplicate/new status, or continue after append error | hydrate from log, deterministic event identity, CAS and projector cursor |

All entries in this table are implementation `REVISE`; none invalidates the selected target architecture.

### 4.4 Reuse-first convergence doctrine

The implementation default is **existing-owner convergence**, not an additive clean-room facade. A clearer boundary does not by itself justify a new public type, actor, target, registry, store, ledger, planner, compiler, receipt family, or state machine. An implementation is acceptable only when each semantic fact and each mutable transition has one canonical owner.

The absence of an exact type name is not evidence that a capability is missing. The review found no exact-name collision between the proposed types and current declarations, while finding many semantic duplicates whose different names would evade the compiler and create contradictory digests, grants, release decisions, watermarks, receipts, or recovery states. Reuse review therefore compares responsibility and authority, not spelling.

Every proposed component is classified before implementation:

| Class | Meaning | Required action |
|---|---|---|
| **R — Reuse** | The invariant and production mechanism already exist | Call it directly; do not wrap unless a dependency/process boundary requires translation |
| **E — Extend** | The current owner is correct but lacks fields, canonical identity, durability, or a stricter invariant | Modify that owner in place or add a same-owner extension; preserve wire/source compatibility |
| **A — Adapter only** | A real module, process, framework, or legacy-wire boundary exists | Translate once; the adapter cannot rank, authorize, persist a second truth, cache independently, or execute a second effect |
| **M — Missing** | No repository owner or public/upstream primitive satisfies the required invariant | A new owner is allowed only after the create gate below passes |

#### Canonical owner map

| Domain | Canonical owner to reuse or extend | Locked convergence rule |
|---|---|---|
| L1–L14 identity | `BASCognitiveLayer`, with existing motherboard mappings as compatibility views | `BASSemanticLayerID` is an alias/projection, never a second 14-case enum |
| kernel/ring/plane identity | `BASMotherboardKernel` plus current motherboard compatibility types | Extend the four-kernel owner with stable K1–K4 projection; add only the genuinely missing ring and seven-view identities; explicitly map the legacy three-domain plane rather than treating it as the seven-view taxonomy |
| layer execution | `BASLayerActor`, `BASLayerReferenceActor`, `BASLayerCascadeRunner`, `BAS14LayerMeshMap/Assembler`, `BASLayerSlice`, current kill-switch state | LayerCell adds pure ingress/core/egress membranes around this actor mesh; budgets and kill epochs have one owner and are projected, not deducted or advanced twice |
| common envelopes | `BASResult`, `BASFrameEnvelope`, `BASPermit`, `BASBundle`, `BASCard` | New domain records reuse these low-entropy shapes unless a materially different canonical payload is proven |
| event truth and replay order | `BASEventLogEntry`, `BASEventLogStorage`, `BASSQLiteEventLogStorage`, existing integrity chain and replay harnesses | State commit, replay identity, and manifest indexing derive from this sequence/hash truth; no second event log, cursor timeline, WAL, or hash chain |
| retrieval mechanisms | `BASL8RoutedMemoryService`, `BASRAGRetriever`, vector/FTS/temporal/entity/graph stores | SemanticStateLake lanes are adapters and snapshot-bound projections; they never rebuild an index or retrieval engine |
| context packing | `BASContextCompiler` in `ContextCompilerCore.swift` | Tokenize-once spans, exact budgets, and descriptor binding extend this owner; scoped/semantic/turn compilers supply inputs or compatibility projections |
| model identity and invocation | `BASModelCapabilityManifest`, `BASModelManifestRegistry`, `BASLLMInvocationContract` | Quality identity is a canonical projection; the neural execution contract extends/nests the invocation contract rather than becoming a third editable model identity |
| model-neutral SDK boundary | `QinaoRuntime`, existing Qinao proposal/release/seat contracts, BAS manifest/invocation/plan chain | Extend these into value-only Provider/Proposal ports; concrete Qwen/MLX/Core AI/Foundation Models implementations live in host/provider packages and cannot become SDK-owned products |
| workspace/task/attempt identity | existing turn/session/task identities plus the event-log sequence | Extend into one canonical workspace generation and AttemptRef; do not create a second task manager, attempt registry, or scheduler truth |
| execution plan | `BASExecutionPlan`, `BASExecutionPlanElector`, current decode planner and MLX session/executor paths | One canonical execution binding root is owned by the plan; request, lease, and receipt reference it instead of repeating digest bundles |
| memory and thermal evidence | `BASMLXMemoryModel/Budget`, `BASThermalTwin`, `BASSystemProbe`, existing pressure and device probes | A new process ledger consumes these measurements; it does not replace estimators, probes, or framework memory managers |
| thermal and placement taxonomy | canonical system thermal classification in RuntimeCore; `BASComputeTier` for physical tier; a separate evidence-status axis | The duplicate five-case Metal thermal enum becomes an alias/adapter; physical tier never mixes with `observed/inferred/unknown` epistemic status |
| risk and release decision | existing L10/L11 risk types, `BASExecutionGovernance`, `BASProviderReleaseGate`, current render/candidate types | Exact/provisional durability extends the current gate; no second independently permissive L11 or release authority |
| sovereign issuance and audit | `BASSovereignTokenAuthority`, commit token/warrant/enforcer, `BASSovereignAuditLedger` | CapabilityGrant supplies the canonical attenuated semantic contract; durable K4 extends the one mint/reserve/claim/spend authority and explicitly migrates the existing token schema |
| tool execution | `BASToolInvocation`, `BASToolResult`, `BASToolDispatcher` | Effect Broker wraps these payloads and becomes the only production dispatch path; it does not define a second tool protocol |
| runtime scheduling | `BASTurnRuntimeEngine`, stage plan/ledger, native/parallel stage executors, `BASEBrainRuntimeCoordinator` | The semantic DAG becomes the v2 topology truth but executes through these mechanisms; the legacy stage plan is a frozen projection, not a second canonical topology |
| public result | `BASEBrainTurnResult` and its current host projections | A pending/final authoritative artifact wraps and ultimately projects this result exactly once; it does not create another externally visible answer type |
| Apple lifecycle/telemetry | existing BGTask bridge, device harnesses, signpost/field-metric collectors | New architecture gates aggregate their evidence; they do not create another background scheduler, live tracer, or device measurement protocol |

#### Create gate

Every new production `Create` must carry a reviewable proof containing all of the following:

1. the repository search and exact existing-owner candidates;
2. the relevant Apple/public/upstream primitive search;
3. the one invariant that is absent today;
4. why extension, composition, a generic low-entropy primitive, or a thin adapter cannot satisfy it;
5. its single authority, mutable-state owner, storage owner, and failure/recovery boundary;
6. its dependency direction and why it does not introduce a second source of truth;
7. its compatibility projection and the old path's freeze, migration, or retirement condition;
8. mutation, crash, replay, and duplicate-authority tests that would fail if a second owner appeared.

A cleaner name, a preferred folder layout, a new `Core`/`Manager`/`Registry`/`Store` suffix, or an exact-name `rg` miss is never sufficient. When the proof is incomplete, the item defaults to **E** or **A**, not **M**.

#### Identity and receipt normalization

- A domain payload never encodes its own `BASArtifactID`, artifact digest, storage locator, or signature. The Artifact Mesh envelope alone owns its ID. The sole signature-byte payload is a child attestation: it may contain the proof over another artifact, but never its own ID/digest.
- Attestation is an ordinary artifact payload stored through the same `put → BASArtifactStoreReceipt` path. There is no special attestation store or second identity algorithm.
- New cross-plan artifact, receipt, signature, snapshot, spool, manifest, and authorization references use typed `BASArtifactID`; raw `String` references remain only in legacy-wire adapters.
- A signature is a child attestation over an unsigned canonical artifact payload. A transport may be self-contained, but its signed transport envelope is not a second canonical artifact identity.
- `BASCapabilityUseReceipt` and K4 claim receipt are one canonical durable consumption fact. Validation and claim cannot each consume or persist the same grant independently.
- One ordered `BASLaneWatermark` representation carries lane, sequence, root/provenance, and required proof. Snapshot and replay reuse it; dictionary counters and replay-specific copies are forbidden.
- A response spool is one Artifact Mesh object derived from the existing canonical rendered output. Verification, risk, release, sink, reservation, and finalization records reference its artifact ID instead of copying spool/digest/presentation tuples.
- A replay manifest is stored as an artifact. Its index and publication journal may be separate ports, but they cannot become another immutable-object store.
- The execution plan owns one canonical silicon execution binding. Requests, child leases, K4 authorization context, usage receipts, and replay records reference that binding root; caller-supplied parallel lists of quality/profile/ABI/fallback digests are forbidden.

#### Public and upstream primitives that must not be rebuilt

- Swift actors own business state; `TaskGroup` handles bounded fan-out; `AsyncStream` handles streams; `ContinuousClock` or the existing monotonic wrapper handles duration. No custom thread pool, blocking-semaphore scheduler, lock queue, or third time system is introduced.
- Vendored MLX `WiredMemoryManager.shared`, `WiredMemoryTicket`, cancellation/waiting, hysteresis, baseline restoration, and `Memory.snapshot()` remain the sole MLX wired-memory mechanism. The BAS ledger is an application-level cross-framework reservation owner, not a second MLX limit manager.
- Core ML uses public `computeUnits` and `MLState`; requested or planned device usage remains distinct from observed placement. No custom Core ML state-buffer manager or ANE scheduler is created.
- MLX, MPSGraph, and MPS are preferred over custom Metal. A custom kernel requires a missing public primitive, numerical parity, measured device benefit, and a complete fallback. Vendor patches may add observation only and may not alter model mathematics or hidden scheduling semantics.
- SQLite transactions, constraints, WAL, backup/checkpoint behavior, FTS5, and BM25 remain the database primitives. The project does not implement a WAL, B-tree, FTS engine, or lexical scorer. Every SQLite store reuses the existing file-protection, integrity, and secure-delete policy for the database and its WAL/SHM sidecars.
- CryptoKit, Security, Keychain, Secure Enclave P-256, and system randomness own cryptographic primitives and encodings. The system does not implement signature algorithms, PRNGs, DER/ASN.1, or call a Keychain-stored exportable Ed25519 seed a Secure Enclave key.
- Enhanced Security helper extensions and public XPC/ExtensionFoundation mechanisms own process isolation. No private Mach/XPC protocol, custom socket, or release-mode in-process imitation is accepted.
- The existing `AppleBGTaskSchedulerBridge` owns background scheduling. Durable recovery must remain correct when no background launch occurs or a task expires; no daemon or keepalive loop is created.
- `Logger`/`OSSignposter` mirror live structure and timings but do not replace canonical evidence. MetricKit is delayed field/canary evidence, not an E4 per-run deterministic verdict source.

#### Genuinely missing owner allowlist

The audit permits new ownership only for these currently absent invariants, while still reusing the mechanisms above:

- keyed Artifact Mesh identity, CAS head/store, and ordinary child attestations;
- immutable multi-lane semantic snapshot/barrier and typed state-requirement planning;
- complete cross-backend StateABI and canonical execution-binding contracts;
- one application-level process MemoryLedger/local-heavy-owner authority across MLX, Core ML/Core AI, Metal, retrieval, verifier, and spool memory;
- durable response spool, hash-chain verification, idempotent publication reservation/finalization;
- algorithm-agile trust manifest and optional Secure Enclave P-256 root, with the current fingerprint manifest as a v1 migration view;
- durable K4 issue/reserve/claim/spend/recovery in the iOS 27 Enhanced Security helper;
- durable Zone-C effect saga/outbox/reconciliation and sealed state prepare/stage/activate protocol;
- canonical semantic DAG contracts, complete pre-publication replay manifest, aggregate E0–E5 certification, candidate-tree attestation, and source-entry audit.

Adding any other new production owner requires an explicit amendment to this design. Tests, schemas, migrations, scripts, and deliberately thin adapters may still be new files, but their owning runtime concept must be one of the existing or allowlisted authorities above.

#### Anti-duplication acceptance assertions

The implementation plans and code gates must prove at least:

1. semantic layer identity is an alias/projection of `BASCognitiveLayer`;
2. LayerCell mechanism dispatch reaches the existing `BASLayerActor` mesh and cannot execute a second semantic actor path;
3. exactly one capability/K4 authority can mint and atomically consume a grant, with one durable token schema and one use receipt;
4. exactly one event sequence and integrity chain owns state-commit and replay source identity;
5. exactly one context packer tokenizes, allocates, orders, and hashes a compiled prompt;
6. exactly one execution plan/binding and one heavy-owner lease can actuate each neural phase;
7. exactly one final spool/publication path can make response bytes visible, and one finalized `BASEBrainTurnResult` leaves the runtime;
8. K3 outbox owns prepare/stage/seal/activation while Zone C owns dispatch/ack/indeterminate/reconcile; neither reducer can write the other's state;
9. the semantic DAG runs through the current turn engine/stage executors and cannot execute a hidden second coordinator result;
10. no adapter contains independent ranking, authorization, persistence, retry truth, cache authority, or external-effect logic.

### 4.5 Current performance truth

Repository device ledgers establish a more conservative reality than a headline peak:

- best observed short, nominal/thermally-cool Qwen3.5-4B decode result is approximately `34.6 tok/s`; this is not process-cold TTFT or end-to-end turn goodput;
- a 20-minute run reports approximately `15.9 tok/s` in the final quarter;
- measured memory bandwidth around `59 GB/s` implies a plain-decode roof around `25 tok/s` for the current 4-bit target path;
- existing adaptive multi-token evidence is workload-dependent, with acceptance and thermal behavior determining accepted-token goodput.

Therefore:

- `40 tok/s` is a qualified future certification target, not a current general capability;
- short nominal `30+` observations must not be presented as a product SLA;
- sustained `30 tok/s` is not supported by the current long-run evidence;
- the performance target is **accepted, verified, correctly terminated tokens per second**, not speculative proposals per second.

## 5. Approaches Considered

### Approach A — Capability-driven portfolio under invariant semantic contracts

Keep MLX/Metal as the incumbent, Core ML for certified microheads, Core AI as a measured promotion lane, and future silicon behind capability/evidence profiles.

Advantages:

- preserves current working paths while enabling deep Apple-specific optimization;
- avoids depending on a beta framework or an unreleased chip name;
- makes promotion, demotion, StateABI, thermal, and quality rules explicit;
- keeps the 14-layer semantic architecture stable.

Costs:

- requires a real profile registry, one execution actuator, receipts, and recovery protocols;
- does not offer a shortcut around physical bandwidth or thermal limits.

### Approach B — Air-first vertical specialization

Optimize directly around A19 Pro/Air implementation details, then abstract later.

Advantages:

- concentrated near-term engineering;
- may reach a local benchmark faster.

Costs:

- higher migration debt;
- invites chip-name policy and inferred-placement claims;
- makes future OS/runtime invalidation harder to contain.

### Approach C — Core AI-first migration

Make Core AI the primary trunk and adapt the model/runtime around it immediately.

Advantages:

- potential future stateful/AOT/layout benefits;
- closer alignment with Apple’s new generative-inference direction.

Costs:

- current API and conversion path are not yet certified for exact Qwen3.5 behavior, custom operations, StateABI, thermal stability, or full recovery;
- an OS-managed placement request is not a placement receipt;
- premature migration risks lower quality and silent state incompatibility.

### Decision

Choose **Approach A**. Approaches B and C remain bounded experiments whose artifacts can be promoted only through the same evidence gates.

## 6. Locked Counting and Naming Model

### 6.1 Cardinality invariant

The architecture contains exactly:

- `14` Semantic LayerCores;
- `4` Physical Kernels;
- `4` bounded ControlRings;
- `7` orthogonal top-level planes.

No object may be introduced as another member of these sets without a new architecture decision. In particular:

- there is no additional semantic layer after L14;
- there is no additional Physical Kernel for effects;
- Silicon Capability Fabric is not a top-level plane;
- outer feedback loops are not included in the 14 semantic count.

### 6.2 Stable identity and aliases

`L1...L14`, `K1...K4`, and the four ring IDs are canonical. Human names are aliases resolved through one `NamingMatrix`.

The target naming policy must reconcile current repository drift, including multiple layer identity types and the L9 `Kunlun`/`Dream` alias. Serialization, signatures, capability audience, kill epochs, telemetry, and replay use stable IDs, never a display alias.

### 6.3 Core distinction

The word “core” has two different qualified uses:

- **Semantic LayerCore:** owns meaning and a bounded semantic decision.
- **Physical Kernel:** owns shared mutable mechanism, resource, deployment, and fault containment.

“Physical” here means mechanism/fault-domain placement in the software architecture. It does not mean one-to-one binding to a CPU, GPU, Neural Engine, or hardware core.

## 7. Seven Orthogonal Top-Level Planes

| Plane | Owns | Does not own |
|---|---|---|
| **Semantic Authority** | L1–L14 decision ownership and semantic invariants | kernel implementation, hardware placement |
| **Kernel Ownership** | K1–K4 mutable mechanisms, resource brokers, fault domains | semantic truth or user-facing verdicts |
| **Execution DAG** | per-turn artifact dependencies, joins, remands, cancellation, deadlines | layer identity or durable state truth |
| **ControlRing** | bounded receipt-driven adaptation protocols | final decisions, state, effects, data ownership |
| **Data Plane** | immutable artifact bodies, snapshots, CAS, indexes, logs, outboxes, ledgers | semantic interpretation |
| **Adapter / IO** | model/runtime/storage/OS/tool/network bridges and Zone-C Effect Broker | semantic authorization |
| **Observe / Replay** | evidence, receipts, traces, deterministic replay, certification | live control authority or hidden mutation |

Silicon Capability Fabric spans only:

- Kernel Ownership;
- Adapter / IO;
- Observe / Replay.

It exposes facts, certified profiles, revocable offers, and receipts. It never generates a semantic answer, risk permit, state truth, or authorization decision.

## 8. Four Physical Kernels

| Kernel | Mechanism ownership | Required boundaries |
|---|---|---|
| **K1 Lease & Life** | thermal/power/memory observation, process-wide MemoryLedger, admission reservation, process-wide local heavy-owner gate, cancellation/checkpoint signals | consumes policy from L1; cannot decide answer/risk/state truth |
| **K2 Neural Organ** | Provider-independent neural orchestration, logical neural-state identity/version/lease/checkpoint contracts, cache admission, prefill/decode supervision, and the Provider gateway | consumes neural plan from L2; never owns concrete model/runtime packages or silently chooses model identity; a leased Provider owns only its physical model/session/state bytes |
| **K3 State & Evolution** | SemanticStateLake stores/indexes, artifact storage, event log, durable outbox, staged state, projector cursors, evolution graph | consumes L7/L8/L13 decisions; cannot make eligibility, conflict, or promotion truth by itself |
| **K4 Sovereign Microkernel** | signer, key manifest, durable issuance/reserve/spend ledger, nonce/replay defense, audit log, helper-private persistence | consumes L14 decision; cannot schedule silicon, execute tools, decode, or author an answer |

Layers do not have a unique “home kernel.” A layer may use multiple mechanism ports through membranes, while its semantic authority remains singular. Any current `primaryKernel` mapping is a migration aid, not the target authority model.

The Zone-C Effect Broker is Adapter/IO infrastructure, not another Physical Kernel.

## 9. Four Bounded ControlRings

| Ring | Observes | May request | Hard bound | Forbidden |
|---|---|---|---|---|
| **ΩR Resource** | lease, thermal, power, memory, command-buffer, latency receipts | defer, pause, cache eviction, safe checkpoint, compatible backend remand | transition deadline, retry cap, phase budget | semantic answer/risk/policy changes |
| **ΩG Grounding** | coverage, conflict, freshness, lane watermarks | bounded extra query, partial join, remand to requirements | max epochs, lanes, bytes, tokens, deadline | silent truth selection or completed-turn mutation |
| **ΩD Deliberation** | proposal, critique, verification receipts | bounded candidate revision or new branch | max branches, rounds, tokens, queue bytes | unbounded self-dialogue or commit authority |
| **ΩE Effect / Evolution** | prepare, authorization, dispatch, receipt, reconcile, seal | query provider, compensate, remand, activate next state/version | saga deadline, attempt/reconcile cap, operator escalation | automatic replay of an indeterminate irreversible effect |

A ControlRing may observe receipts, request a bounded remand, and propose adaptation. It owns no semantic truth, mutable state, verdict, or external effect.

Every ring terminates with one typed state:

- `converged`;
- `degraded_with_coverage`;
- `deferred`;
- `rejected`;
- `needs_confirmation`;
- `indeterminate_needs_reconciliation`.

Cycle detection or budget exhaustion cannot silently return a committable “last answer.”

### 9.1 RSI is a bounded protocol, not a fifth ring

RSI means a receipt-driven improvement protocol shared by the four rings:

```text
Observe → Diagnose → Propose → Simulate/Compare
→ Authorize → Act → Verify → Consolidate candidate
```

There is no `RSIManager`, recursive super-agent, hidden scheduler, fifth ring, or additional commit gate. Each iteration is an immutable invocation artifact whose `LoopEnvelope` references—not copies—the existing authority and budget truth:

```text
root AttemptRef + ring + invocationID + parentInvocationRef
WorkspaceReadSnapshot artifact ID + epoch vector
CapabilityGrant artifact ID + BudgetLease artifact ID
prior BudgetUseReceipt + progress-witness artifact ID
visited state/decision digest-set commitment
declared remand edge + depth/branch/deadline bounds
```

Before each step the one budget owner atomically claims tokens/bytes/branches/time against `BudgetLease` using compare-and-swap and emits `BudgetUseReceipt`; concurrent branches cannot spend an envelope-local counter. Authorized operations/remands derive from the one `CapabilityGrant` and current epochs. Projected “remaining” values are display-only equality-checked views. Terminal reason lives in the terminal receipt, not mutable envelope state.

Continuing a loop requires a monotonic, phase-specific witness. Valid witnesses include new required-lane coverage, strict deficiency/conflict reduction, resource transition toward a safe terminal state, or effect-saga rank advance. Novel prose, a different random sample, or revisiting an existing digest is not progress. Repeated digest, exhausted/failed budget claim, missing witness, stale epoch, or illegal remand terminates deterministically.

Ring **types** may alternate ΩG → ΩD → ΩG, so the type relation is not claimed acyclic. Every concrete invocation graph is nevertheless a DAG: a remand creates a new child artifact with a new digest, strictly greater remand depth, an unspent budget receipt, and a progress witness; it can never reopen or point back to an earlier invocation/digest. Boundary rules are:

- ΩD may remand to a **new** ΩG invocation only before visible output/effect dispatch and only under the grant's declared edge/depth/budget; the resulting evidence may feed only a new ΩD child;
- no terminal invocation is re-entered and no prior state/decision digest counts as progress;
- ΩR is pre-emptive pause/checkpoint/resume control, not a semantic child loop;
- ΩE after the effect dispatch boundary may only query, reconcile, compensate under a new authorization, or seal an established result; it cannot regenerate and redispatch;
- a new problem-solving cycle after a terminal boundary is a new Attempt, not recursive continuation of the old one.

Self-scheduling is deterministic within signed budgets. Adaptation can change only fields inside a signed adaptation envelope. Self-repair can rebuild derived projections, caches, indexes, and certified physical state from authority. Self-evolution is shadow/offline evidence for a future signed epoch. On-device loops cannot rewrite executable code, model weights, schema authority, security policy, or the currently executing semantic cores.

## 10. LayerCell Boundary

Every semantic layer is implemented as:

```text
typed ingress membrane
    ↓ validate schema, parent, capability, epoch, snapshot
pure semantic core
    ↓ emit decision/proposal artifact; no direct I/O
typed egress membrane
    ↓ attenuate capability; invoke private mechanism port if authorized
```

The pure core:

- is deterministic relative to explicit inputs and declared model/non-determinism receipts;
- holds no cross-turn shared mutable state;
- does not call another layer’s private mechanism;
- does not perform filesystem, network, model-runtime, signer, or external-tool I/O;
- cannot bypass capabilities or kill epochs.

The membrane:

- validates canonical bytes, schema, lineage, audience, epoch, snapshot, deadline, and budget;
- translates semantic decisions into narrowly scoped mechanism requests;
- records request and usage receipts;
- attenuates—not broadens—capabilities across every edge.

L14 illustrates the boundary precisely:

- the L14 core emits an immutable `AuthorizationDecisionArtifact`, revocation decision, or seal decision;
- the L14 egress membrane asks K4 to mint/sign/reserve/spend/seal;
- K4 does not invent the decision;
- a helper process protects keys and ledger state but does not prove a compromised host’s semantic reasoning was correct.

### 10.1 Qinao SDK and external Provider boundary

Qinao SDK is a model-independent deterministic substrate. Its public boundary is capability-shaped, value-only, versioned, and auditable:

```text
Host model selection + signed policy
    ↓
Qinao capability/profile admission
    ↓
materialized ProviderRequest values
    ↓
external Provider executes leased physical state
    ↓
untrusted ProviderProposal + ProviderClaimReceipt
    ↓
Qinao observed receipt, verification, adoption, release, commit
```

The boundary names contract roles, not permission to add parallel owners. Existing Qinao proposal/release/seat types and the BAS manifest/invocation/plan chain are extended where possible.

Qinao owns:

- `QualityIdentity`, exact per-turn neural contract, execution binding, routing/fallback plan, admission and all capabilities;
- logical neural-state identity, version, ownership fence, cache visibility, checkpoint requirements, retry truth, publication/effect truth, and the observed usage receipt;
- materializing the minimum input projection and validating the structural/Attempt binding plus target-observed acceptance of proposed tokens, and independently gating every tool request, grounding claim, state delta, and completion. Qinao does not claim to re-prove the Provider's neural logits without executing the target.

The selected Provider owns only its leased physical implementation:

- model and optional native-MTP tensor bytes;
- concrete tokenizer/runtime session when the signed contract delegates that mechanism;
- opaque/COW physical KV, GDN, convolution, RNG, and decoder state that implements the Qinao-owned logical state version;
- runtime-local command buffers and transient allocations within the granted ledger/phase lease.

Every neural wire message carries one Qinao-minted, non-authoritative correlation value:

```text
ProviderExecutionRef = {
  attemptRefArtifactID,
  providerLeaseArtifactID,
  providerExecutionID,
  acceptanceGeneration,
  requestSequence
}
```

The Provider only echoes the **entire** value. Qinao checks the active lease and acceptance generation on every request, chunk, checkpoint, proposal, and receipt. Adoption is a compare-and-swap over `(ProviderExecutionRef, expectedLogicalStateVersion, requestSequence)`: one exact sequence/digest may advance target state at most once; an identical duplicate is audit-only, a same-sequence/different-digest claim is a protocol violation, and old/out-of-order/mismatched refs are rejected.

Model-specific tokenization may execute in the external Provider package as a deterministic value-only adapter, but the signed tokenizer asset/config digest and known-answer vectors are part of the bundle. Qinao owns the resulting canonical token sequence/span descriptor and tokenization receipt; prefill must bind exactly those tokens. The Provider cannot silently retokenize under another template/tokenizer.

A Provider never receives dereferenceable Qinao actors, SQL handles, StateLake handles, mutable artifact stores, tool credentials, sovereign keys, release sinks, or a general host callback. Requests contain copied/materialized values and attenuated opaque artifact references whose projection has already been authorized. It cannot select its own model, fallback, retry, cache visibility, tool, state commit, or publication path.

The package dependency graph enforces the architectural half of this rule: Qinao SDK/Provider-contract targets cannot import or link concrete Provider targets, and an `inProcessCertified` Provider target may depend only on the contract/value module plus its runtime/upstream libraries—not Qinao state, SQL, tool, risk, release, or sovereign modules. CI dependency/lint/link-symbol gates pin that closure. This prevents accidental capability growth; because code still shares a process, it does not defend against malicious native code. Hostile/unreviewed Providers require `isolatedExtension` or `remote` containment.

Provider trust/deployment classes are explicit:

| Trust class | Boundary | Required interpretation |
|---|---|---|
| `inProcessCertified` | separate package/target behind the same value contract | performance boundary only; it is **not** malicious-code isolation and shares the host process fault domain |
| `isolatedExtension` | XPC/extension transport with schema and capability checks | stronger memory/process containment; still untrusted semantic output |
| `remote` | authenticated network transport | additionally requires L11 disclosure approval, L14 egress authorization, data-residency policy, and a redacted/materialized request projection |

`ProviderProposal` and `ProviderClaimReceipt` are untrusted claims about what the Provider attempted and observed. Qinao's supervisor independently records the actual request binding, timing, cancellation, bytes/tokens accepted, state transition, and terminal result in a `ProviderObservedReceipt`; a Provider receipt never promotes itself.

For remote execution, an unverifiable backend/model placement remains `unknown` in the observed receipt. It cannot serve as an invisible same-identity fallback unless a signed deployment attestation and the complete bundle/runtime identity satisfy the certified profile; API/model-name agreement alone is insufficient.

The host chooses the model before exact context tokenization. Qwen3.5-4B is the signed host default for the current product profile, not an SDK constant. Automatic fallback may remain invisible only when the target is exactly attested under the same `QualityIdentity`, exact per-turn contract, and signed fallback edge. Any cross-model or cross-lineage change terminates with `model_change_required`, discloses the change, obtains explicit host/user consent when policy requires it, recompiles context, and starts a new Attempt with new authorization.

## 11. Fourteen Semantic LayerCores

| Layer | Semantic authority | Primary outputs | Explicitly forbidden |
|---|---|---|---|
| **L1 Wick Life** | turn-life, resource-policy, phase budget, and lease-requirement truth | `TurnLifePolicy`, `ResourceRequirement`, `LeaseAcceptanceDecision` | reading prompt content beyond required labels; implementing thermal/memory mechanism |
| **L2 Brain Tissue (semantic)** | model requirement, neural execution plan, neural receipt interpretation | `NeuralRequirement`, `NeuralPlanDecision`, `NeuralResultArtifact` | owning model bytes/KV/token loop; silently changing model identity |
| **L3 Folded Lung** | context admission, budget allocation, compile/binding/fingerprint decisions | `ContextProjection`, `ContextBudget`, `CompiledContextDescriptor` | retrieval truth; direct model/file I/O |
| **L4 World Prior** | versioned world claims and domain assumptions | `WorldClaimSet`, `PriorRevision` | treating stale claims as timeless; direct final ranking |
| **L5 Host Constitution** | host preference, policy, disclosure, persona, and user-bound constraint truth | `ConstitutionProjection`, `PolicyEpoch` | effect execution; hardware scheduling |
| **L6 Situation** | normalized intent, current context, task frame, and risk hints | `SituationArtifact`, `IntentSet`, `RiskHintSet` | final risk permit; authoritative memory selection |
| **L7 Mirror Blade / Grounding** | StateRequirementPlan, hard eligibility, lane fusion, coverage, conflict manifest | `StateRequirementPlan`, `EligibleEvidenceSet`, `ConflictManifest`, `CoverageVector` | owning L8 storage; silently resolving unresolved material conflict |
| **L8 Hippocampal Memory** | snapshot/projection semantics and retrieval candidate production | `StateSnapshotRef`, `LaneResult`, `MemoryProjection` | final eligibility, market winner, answer truth; neural KV ownership |
| **L9 Kunlun / Dream** | candidate portfolio, alternatives, counterfactuals, and selection | `CandidatePortfolio`, `SelectedCandidate` | final verification, effect execution |
| **L10 Tribunal** | streaming-chunk constraint verification, exact-output verification, critique, claim support, and convergence status | `ChunkVerificationReceipt`, `ExactOutputVerification`, `ClaimSupportMap`, `ConvergenceDecision` | risk permit, state commit, unbounded self-loop |
| **L11 Risk** | provisional eligibility, final risk classification, confirmation requirement, and RiskPermit truth | `ProvisionalEligibility`, `RiskPermit`, `ConfirmationRequirement`, `DisclosureRequirement` | executing effects or weakening L14 policy |
| **L12 Soft Hand** | response projection, spool policy, provisional/final release semantics | `ResponseSpool`, `ReleaseProposal`, `PresentationProjection` | allowing provisional text to drive tools/state; bypassing the L10 streaming or exact-output verifier |
| **L13 Evolution** | prepare/commit/evolution proposal, reconciliation interpretation, next-version candidate truth | `StatePrepareIntent`, `StateCommitIntent`, `ReconciliationDecision`, `EvolutionProposal` | same-turn self-modification; activating unsealed staged state |
| **L14 Sovereign** | request admission preflight, exact authorization, revocation, and seal decisions | `AdmissionDecision`, `AuthorizationDecisionArtifact`, `RevocationDecision`, `SealDecision` | model execution, silicon scheduling, answer generation, direct tool/effect execution |

Additional invariants:

- L8 returns candidates bound to one immutable `WorkspaceReadSnapshot` and Attempt generation.
- L7 owns eligibility, fusion, coverage, and conflict semantics.
- L9 owns portfolio selection.
- L10 owns verification and critique.
- L11 owns the risk permit and confirmation requirement.
- L13 may prepare proposals and interpret receipts but cannot make staged state visible.
- L14 is invoked at admission and commit/release points; multiple L14 artifact nodes in a turn do not create a cyclic semantic graph.
- late optional retrieval results cannot mutate a completed Attempt and may enter only the next declared snapshot/Attempt generation.

## 12. Dual Mesh

### 12.1 Artifact Mesh

Artifact Mesh is the immutable, typed, **keyed-content-addressed** semantic DAG inside one protected commitment scope. It carries meaning and evidence, never ambient authority.

Identity, storage, and attestation are three non-circular records.

Minimum `ArtifactIdentityCore` fields—the only bytes used to derive content identity—are:

```text
canonicalizationVersion
schemaID + schemaVersion
kind
parents[]
producerLayerID
scopeBinding(tag + authority/workspace/task/Attempt artifact ID)
logicalEpoch
createdLogicalTime
canonicalPayloadBytes + payloadLength
confidentialityLabel
provenanceRefs[]
snapshotRoot / readVersionVector when applicable
```

The canonical encoder rejects duplicate keys, non-canonical numbers/strings, unknown required fields, or unordered fields where order is semantic. It serializes the IdentityCore exactly once.

```text
artifactID = {
  integrityAlgorithm,
  commitmentKeyEpoch,
  KeyedCommit(commitmentScopeKey, CanonicalEncode(ArtifactIdentityCore))
}
```

`artifactID`, `payloadRef`, storage encoding/compression/encryption metadata, signature/MAC bytes, and producer/usage receipts are explicitly excluded from `ArtifactIdentityCore`. This prevents self-reference, locator-dependent identity, and receipt/signature dependency cycles.

`ArtifactStorageEnvelope` contains only storage concerns:

```text
artifactID
payloadRef
storedLength
storageEncoding / compression
encryptionKeyID + encryption metadata
```

Changing or relocating `payloadRef` cannot change `artifactID`; storage reads recompute the keyed commitment from canonical decoded payload and IdentityCore before use.

`ArtifactAttestationPayload` is a separate ordinary child-artifact payload:

```text
targetArtifactID
attestationPurpose
producerReceiptArtifactID / usageReceiptArtifactIDs[]
signature/hash suite + key ID/epoch + custody class
signedStatementDigest + signature/MAC bytes
logicalTime + policy/key epoch
```

Its signature signs `targetArtifactID + attestation context`. The payload contains no `attestationArtifactID` or self digest. After the proof bytes exist, the same Artifact Mesh `put` path derives the child artifact ID and returns the ordinary `ArtifactStoreReceipt`; a target index is only a query index. The target artifact never points backward to that child.

`scopeBinding` is a tagged union that prevents bootstrap cycles: public assets bind `public`; a `ContextWorkspaceRef` binds its authority-scope artifact; an `AttemptRef` binds its `ContextWorkspaceRef`; attempt-scoped artifacts bind `attemptRefArtifactID`. The Attempt reference transitively binds the canonical workspace/window/session/task/turn/branch/attempt generations; those fields are not copied into a second editable tuple. The same canonical `ArtifactIdentityCore` in one protected user/device/tenant scope and key epoch has the same ID; the same payload with different provenance, parent, Attempt, or logical identity is intentionally a different artifact. Content across different scopes or key epochs is not publicly linkable. Public telemetry must not expose raw hashes of low-entropy private artifacts. The design separates:

- internal integrity identity: the keyed canonical `artifactID`;
- storage location: an independent protected random `payloadRef`, never treated as content identity;
- external/audit correlation: blinded or keyed commitment with scoped disclosure;
- public performance correlation: non-content operation IDs.

Immutable DAG nodes are never updated in place. A saga, remand, revocation, or state transition appends a new transition artifact and updates a mutable head/index transactionally. Logical remand may revisit a layer ID, but every invocation creates a new artifact node, so the physical graph remains acyclic.

### 12.2 Capability Mesh

Capability Mesh is default-deny authority. It never travels as an unscoped boolean.

Minimum `CapabilityGrant` fields:

```text
issuer + subject + audience
operation + resource
requestDigest / inputDigest
neuralExecutionContractDigest when neural work is authorized
outputSchemaDigest + outputConstraintsDigest
projectionPolicyDigest
purpose
scopeBinding(attemptRefArtifactID or explicit durableWarrantScopeArtifactID)
workspaceReadSnapshotArtifactID when state-dependent
generationVectorArtifactID + logicalEpoch
bootSessionID or durable warrant epoch
notBefore + monotonicDeadline / durable expiry
maxUses + maxFanout + maxBytes + maxCost
parentGrantArtifactID
revocationGeneration
nonce
```

The unsigned canonical grant payload is stored through Artifact Mesh; its `BASArtifactID` is the grant identity. Its K4 signature is a child attestation. A self-contained XPC/wire wrapper may carry grant bytes, artifact ID, and attestation together, but it is not another grant schema or identity. K4 remains the only mint/reserve/claim/spend authority.

The generation-vector artifact is derived from the one referenced Attempt/workspace snapshot and contains workspace, window, session, task, Attempt, capability, policy, deletion, and kill generations. It is loaded and equality-checked at use; callers cannot supply an alternate loose tuple. Provider, retrieval, release, effect, and state-mutation grants require an Attempt + snapshot closure. A durable warrant cannot act directly; it may only authorize K4 to derive a narrower Attempt-scoped grant. Missing required scope/snapshot/generation denies.

Rules:

- absent audience, operation, resource, purpose, projection, epoch, or digest binding means deny;
- child grants can only reduce audience, operation, projection, duration, uses, bytes, or cost;
- grant maxima are authorization ceilings; the one referenced `BudgetLease`/budget owner owns reservation and atomic spend, and usage receipts prove `spent ≤ lease ≤ grant` without decrementing two counters;
- a queued task revalidates Attempt/generation vector, revocation generation, deadline, and snapshot at start;
- short-lived grants bind `bootSessionID` and monotonic deadlines; a reboot invalidates them;
- long-lived warrants bind a durable, server/operator-authoritative epoch and wall-clock policy;
- capability bytes are never used as an implicit data payload.

“Exact digest” is phase-aware:

- before a result exists, a query/generation capability binds `requestDigest + outputSchemaDigest + outputConstraintsDigest`;
- after a result exists, a derived release/commit capability binds `resultArtifactDigest` exactly;
- an effect authorization binds a canonical `EffectRequestDigest` and stable operation identity;
- the terminal receipt binds both request and result/observed-state digests.

This avoids the impossible requirement to predict a result digest before computation.

### 12.3 Kill and recovery epochs

Every layer and kernel boundary consumes a signed/authorized epoch:

```text
layerOrKernelID
monotonicGeneration
activationSequence
reason
authority
```

The epoch is an unsigned canonical artifact payload whose authorization is a child attestation. Runtime boundaries receive typed epoch and attestation artifact references; the epoch does not embed a second signature identity.

Kill/revoke and the full Attempt/generation vector are checked at ingress, queue start, every Provider chunk acceptance, mechanism dispatch, provisional/exact publication boundary, Zone-C pre-dispatch boundary, effect authorization, state commit, and seal—not only once when an actor first receives input.

If L14/K4 is unavailable:

- new effects and durable state activation fail closed;
- local refusal and safe read-only responses may continue only under pre-authorized policy;
- recovery authority comes from a physical/operator root or signed recovery manifest, not from another semantic layer;
- ledger loss or integrity failure enters quarantine and cannot restart under the same key epoch with an empty spent history.

## 13. Collaboration Grammar

Cross-layer semantics use exactly five high-level verbs:

1. **Query** — request a bounded projection from an authority.
2. **Fan-out / Join** — create independent branches and reduce them under an explicit join policy.
3. **Proposal / Critique** — propose a candidate and attach typed criticism or verification.
4. **Remand** — return a typed deficiency to a named layer under bounded budget.
5. **Commit Saga** — prepare, authorize, execute/release, reconcile, seal, and activate.

Cancellation, deadline, retry, backpressure, reservation, and reconciliation are transport/control protocols, not additional semantic verbs.

Minimum typed control artifacts:

- `JoinArtifact`: expected/received/missing branches, policy, quorum, deadline, conflict sets, input digests;
- `RemandArtifact`: parent artifact/digest, target layer, missing evidence/schema, round/hop, visited-set commitment, `BudgetLease` + prior `BudgetUseReceipt` references, deadline, resolution state;
- `CancellationSignal`: Attempt/branch/operation target, generation vector, reason, dispatch boundary, monotonic sequence;
- `BackpressureReceipt`: queue bytes, concurrency, resource debt, accepted/deferred/rejected result.

These are ordinary Artifact Mesh payloads: their envelope supplies identity, and every attempt-scoped record inherits `AttemptRef`/generation binding. Numeric budget fields are observations/receipts; only the single BudgetLease owner reserves or spends.

Remand invariants:

- maximum rounds, hops, branch count, tokens, bytes, and deadline are explicit;
- the resolution set must grow monotonically or the ring terminates;
- missing mandatory L5 or L14 input fails closed;
- optional retrieval lanes may degrade only with an explicit coverage vector;
- a branch stopped by cycle or budget cannot acquire a committable capability unless a downstream authority explicitly accepts the degraded state.

## 14. Canonical End-to-End Execution DAG

The canonical turn is a DAG, not fourteen serial actors:

```mermaid
flowchart TD
    A[Input Event] --> B[Input Normalizer]
    B --> C[L14 Admission Preflight]
    C --> WS[WorkspaceReadSnapshot and active AttemptRef]
    WS --> D[L1 Turn and Resource Lease Policy]
    D --> E[L6 Intent and Risk Hints]
    W[L4 World Prior] --> F[L7 State Requirement Planner]
    H[L5 Host Constitution] --> F
    E --> F
    F --> G[L8 SemanticStateLake Snapshot and Multi-lane Retrieval]
    G --> I[L7 Eligibility, Fusion, State Market, Conflict and Coverage]
    I --> MS[Host Model Selection and Provider Capability Admission]
    MS --> J[L3 Context Budget Allocator and State Compiler]
    J --> PE[L11 Provisional Eligibility]
    PE --> PG[L14 Bounded Provisional Release Grant]
    J --> K[L2 Prefill Router]
    K --> L[L2 Decode Router]
    PG --> SV[L10 Streaming Chunk Constraint Gate]
    L --> SV
    SV --> PS[L12 Provisional Stream Membrane]
    L --> M[L9 Candidate Portfolio and Selection]
    M --> P[L12 Exact Presentation Projection and Spool]
    P --> N[L10 Exact-Output Verification and Critique]
    N --> O[L11 Final Risk Permit or Confirmation]
    P --> RA[L14 Exact Result Authorization]
    O --> RA
    RA --> RR[L12 Exact Response Release]
    O --> Q[L13 StatePrepareIntent and Durable Effect Outbox]
    Q --> R[L14 Exact Effect Authorization]
    R --> S[Zone-C Effect Broker]
    S --> T[L13 Receipt, StateCommitIntent and Invisible Staged State]
    T --> U[L14 Terminal Seal]
    U --> V[K3 Activate or Append SemanticStateLake and Audit]
```

The provisional, exact-response, and external-effect paths are distinct:

- L12 cannot release a provisional byte until L11 provisional eligibility and an L14 bounded grant exist **and** L10 has approved that exact hash-chained chunk under the streaming constraint set. Low-risk input classification alone never authorizes raw decode bytes.
- Completion flows through L9 selection → L12 exact projection/spool → L10 verification of those exact bytes → L11 final risk/confirmation → L14 exact-digest authorization → L12 release.
- If L10 or L11 requires a presentation change, a bounded typed remand creates a new L12 spool and repeats exact-output verification/risk; the previous digest can never be released under the new decision.
- A pure response does not pass through the external-effect outbox or Effect Broker.
- An external effect follows the independent L13/K3 → L14/K4 → Zone-C saga. A turn that both replies and acts may have both branches, but their capabilities and terminal states remain separate.
- A response-linked internal state update may use the direct known-result `StateCommitIntent` path after exact bytes exist; it is not disguised as an external effect.

### 14.1 Input Normalizer

Input Normalizer is Adapter/IO infrastructure outside Semantic Authority. It:

- establishes byte identity, source identity, event ID, encoding, length bounds, and canonical transport form;
- performs structural validation, not semantic intent or risk decisions;
- emits the ingress artifact consumed by L14 preflight and L6;
- cannot authorize the request.

### 14.2 Admission before expensive work

L14 preflight rejects structurally forbidden operations, invalid epochs, unavailable sovereign state, and impossible policy scopes before model load or retrieval fan-out. It does not pre-authorize the eventual effect. A later low-risk provisional grant may bind request plus output constraints before content exists, but it cannot authorize tools or state; exact response/effect authorization occurs only after the corresponding result or effect-request closure is known.

### 14.3 Parallelism

Parallelism exists only where artifacts are independent and budgets permit:

- retrieval lanes may fan out under one snapshot;
- candidate branches may fan out under ΩD;
- CPU parsing/index work may overlap low-intensity waits;
- a heavy neural backend retains one authoritative result owner;
- verifier work using the same constrained accelerator runs serially unless a certified profile proves parallel net benefit.

No execution path is allowed to run a routed stage, discard its result, and then recompute the same authoritative result through a legacy coordinator.

### 14.4 Workspace, task graph, and Attempt identity

The system supports many independent logical context windows without pretending the phone can sustain many independent 4B runtimes. Every admitted input binds one canonical `ContextWorkspaceRef`:

```text
authorityScopeDigest
workspaceID + workspaceGeneration
windowID + windowGeneration
sessionID + sessionGeneration
capabilityEpoch + policyEpoch + deletionEpoch
```

Stable IDs name containment; their generations fence change at the smallest safe scope. A window-local edit advances `windowGeneration`, not every sibling window. Workspace-wide authority/state-root change advances `workspaceGeneration`; session replacement advances `sessionGeneration`. The whole value has one Artifact Mesh identity, so callers cannot mix IDs from one generation with epochs from another.

The task hierarchy is structural and finite:

```text
Mission → Objective → WorkUnit → Attempt → SolutionArtifact
```

One canonical `AttemptRef` binds every derived object:

```text
contextWorkspaceRefArtifactID
taskNodeID + taskNodeGeneration
turnID + branchID
attemptID + attemptGeneration
```

Provider requests/chunks, capabilities, snapshots, compiled context, caches, heavy-seat leases, response spool, publication records, effect receipts, and state commits all carry that same Attempt binding. Each WorkUnit has one `activeAttempt` compare-and-swap head. Cancellation, remand, recovery, or replacement fences the old attempt generation before a successor can start. Late Provider, retrieval, tool, or publication results from a fenced generation may be retained as audit evidence but cannot release, commit, activate, or spend authority.

Task-graph mutation is an explicit patch over a base root:

```text
baseTaskGraphRoot
readSet + writeSet
preconditions
candidate nodes/edges/status transitions
budget and authority deltas
```

Automatic rebase is allowed only when the concurrent patches are serializable: each patch's writes are disjoint from the other's reads and writes, the base facts it observed remain true, and the merged graph is rechecked for DAG, budget, attempt, authority, and parent/child terminal invariants. Otherwise the patch receives a typed remand/conflict; “last writer wins” is forbidden.

The immutable patch artifact is not task truth by itself. K3 applies it in the same storage transaction that:

1. appends an EventLog entry referencing the patch artifact;
2. compare-and-swaps `taskGraphRoot`, affected node generations, and `activeAttempt` heads;
3. advances the task-graph projector cursor to that exact EventLog offset;
4. for any ancestor/budget/authority change, computes the dependent descendant closure and advances/fences every affected window/task/Attempt generation and CapabilityGrant before exposing the new head.

If any part fails, no new graph head becomes visible; an unreferenced immutable patch may be garbage-collected. A patch on an unrelated subtree does not fence unrelated windows. Rebase never edits an already issued CapabilityGrant: it revokes/fences the affected generation and a successor must obtain a new grant.

Logical windows have three physical residency classes:

- `active`: eligible to hold the one authoritative Provider lease and compete for the process-wide heavy phase;
- `warm`: immutable compiled artifacts and compatible cache/state references may remain under the MemoryLedger, but no independent heavy runtime is implied;
- `cold`: only durable canonical events/artifacts/projections remain and context is rebuilt on admission.

Each Attempt has at most one authoritative Provider lease. The process has one local accelerator-heavy `HeavyPhaseLease`; prefill is chunked and scheduling is weighted-fair with aging and a profile-derived maximum uninterruptible quantum. Remote I/O and CPU/storage work may overlap other Attempts, but a remote and local Provider cannot race to produce the authoritative result for the same Attempt. Revoking a remote lease does not claim the remote machine physically stopped: Qinao atomically advances the acceptance generation, fences the old lease, and rejects every late chunk/receipt before admitting a successor. Optional parallel proposals remain explicitly shadow/non-authoritative and can never win through arrival order.

`HeavyPhaseLease` deliberately covers work coupled to this iPhone's accelerator residency, peak memory, power, and thermal envelope. Remote compute is outside that physical envelope and uses a bounded K1 network/Provider lease, so it may overlap a different local Attempt; this is not a second local heavy seat. The invariant is therefore **one local heavy phase process-wide plus one authoritative acceptance generation per Attempt**, not an unverifiable claim that a remote machine is idle.

## 15. SemanticStateLake

### 15.1 Naming boundary

The design uses two distinct terms:

- **SemanticStateLake** — L8/K3 episodic, factual, entity, relation, metadata, and semantic retrieval state.
- **NeuralStateCache** — L2/K2 KV/recurrent/token-position state used by neural execution.

The current `BASStateLakeReader` reads a neural `.statelake` tensor bundle. It must be treated or migrated as a neural-state reader. It is not evidence that SemanticStateLake exists.

### 15.2 Workspace read snapshot

At Attempt admission, K3 creates one immutable `WorkspaceReadSnapshot` Artifact Mesh payload. Its artifact envelope supplies the snapshot identity; neither the payload nor replay manifest invents a parallel ID:

```text
AttemptRef artifact ID (transitively binds ContextWorkspaceRef)
authorityScopeDigest equality proof
workspaceRoot + taskGraphRoot + semanticStateRoot
versionVector + deletionEpoch
eventLogHighWatermark
ordered laneWatermarks[]
policyEpoch + schemaEpoch
calendarPolicyArtifactID + derived CalendarPolicyDigest
openedLogicalTime
```

There is one canonical `LaneWatermark` shape: lane ID, event/index sequence, root/integrity commitment, source/provenance identity, completeness, and required proof/attestation reference. Snapshot, lane result, and replay reuse that exact type. A dictionary of bare counters or a replay-specific watermark wrapper is not allowed because it would discard proof and ordering fields.

All projections are read at the same EventLog high watermark. A lane may be older only when its canonical watermark explicitly proves that staleness and policy accepts the resulting coverage state; it cannot silently read a newer event and create a fractured snapshot. Every lane query/result, task-graph patch, compiled context, cache key, Provider request, release, and commit binds the workspace snapshot plus Attempt generation. Provider ingress/chunk acceptance, provisional/exact release, effect authorization, and state commit revalidate the current workspace/window/task/capability/policy/**deletion** epochs; erasure or authority change fences an older snapshot before it can disclose or commit. Required lanes that cannot satisfy the snapshot fail or remand according to policy. Optional late results are recorded for a later epoch and cannot change the completed Attempt.

### 15.3 Retrieval lanes

The standard lanes are:

- SQL / metadata;
- exact / FTS / BM25;
- dense semantic;
- temporal / episode;
- entity / relation.

Each `LaneQuery` carries:

- lane ID and query digest;
- snapshot root and `asOf` requirement;
- requested projection, sensitivity ceiling, scope, limit, byte/token budget, deadline;
- source/authority requirements.

Each `LaneResult` carries:

- lane ID, query digest, semantic snapshot artifact ID, the canonical watermark, and completeness;
- claim key and candidate ID;
- one canonical `BitemporalInterval`: `validTime = [worldFrom, worldTo)` and `transactionTime = [eventOffsetStart, eventOffsetEnd)`;
- source observation timestamp/revision inside provenance metadata, never as an alternate validity/transaction axis;
- sensitivity, scope, authority, freshness, and projection label;
- typed payload artifact ID and integrity commitment;
- missing/timeout/error receipt.

Lane stores produce candidates; they do not decide final rank or truth.

Event payloads, SQL rows, lane results, horizon manifests, conflicts, retractions, and replay all reuse this one `BitemporalInterval` representation. A correction/retraction appends a new event that closes/supersedes the prior transaction interval; it does not rewrite valid time or introduce parallel `validFrom`/`observedAt` truth fields.

### 15.4 Hard Eligibility Gate

L7 owns one versioned `EligibilityPredicate` and applies it in two forms without creating two authorities:

1. **pre-query compiled projection** — K3 compiles the predicate's scope/purpose/sensitivity/deletion/snapshot constraints into SQL/index partitions before exact/FTS/ANN/graph access;
2. **post-retrieval authoritative validation** — L7 evaluates the complete predicate and proofs on every fused candidate before State Market.

The shared non-compensable constraints are:

- capability audience/purpose/projection;
- user/tenant/turn scope;
- sensitivity and disclosure policy;
- snapshot and schema compatibility;
- authority minimum;
- hard validity/expiry;
- provenance requirement;
- kill/revocation epoch;
- token/byte budget admissibility.

The SQL/index filter is a lossless, equality-tested projection of the L7 predicate, not an independent policy engine. Forbidden/deleted/other-authority partitions are never searched or sent to Rust/ANN/grounding, and per-candidate forbidden timing is not exposed. An ineligible candidate cannot re-enter because its relevance score is high.

### 15.5 State Market

Eligible candidates enter constrained multi-objective selection. The preserved vector is:

```text
relevance
authority
freshness
utility
diversity
tokenCost
conflictRisk
```

The implementation uses fixed-point/integer arithmetic, a versioned objective, stable artifact-ID tie-breaks, and a bounded epsilon/Pareto front. It may use staged optimization, Pareto filtering, or a constrained objective, but it must not erase individual dimensions into an uninspectable magic scalar or rely on platform-dependent floating-point order.

Minimum selection requirements:

- reserve budget for constitution, unresolved conflict, user request, and citations before optional enrichment;
- prevent one source/lane/entity from consuming all context;
- preserve diversity until conflict resolution is complete;
- emit selected, rejected, and truncated candidate reasons;
- emit a `CoverageVector`, not merely a top-k list.

### 15.6 Conflict resolution and grounding

L7 emits typed conflict sets keyed by claim identity. Conflict resolution considers:

- source authority and revision lineage;
- canonical valid/transaction intervals and source-observation provenance;
- direct versus inferred evidence;
- user-specific versus general scope;
- retraction/supersession edges;
- explicit uncertainty.

Material unresolved conflicts survive into L10/L11 or cause remand. They are never silently removed by a score tie-break.

The optional small grounding model is an external Provider proposal lane after deterministic retrieval/fusion, never an authority. Policy marks grounding `required` or `optional` for the request class. A required grounding failure blocks/remands; an optional failure is recorded in coverage. The model may propose claim/evidence alignments, contradiction labels, or compression, but deterministic Qinao validation can prove only structure, referenced spans/artifacts, eligibility, scope, freshness, and rule compliance—not that a semantic judgment is true. Accepted labels retain `proposal` epistemic status and cannot raise authority.

If validated proposal features change relevance/utility/conflict inputs, the **same** L7 State Market owner reruns its versioned deterministic objective once over the same eligible set and emits the final selection/coverage receipt. This is recomputation by one owner, not a second market or grounding-owned truth. A fluent proposal cannot hide a failed required lane, introduce a new candidate, or establish authority by itself.

### 15.7 State prepare and commit truth

Before an external result exists, a `StatePrepareIntent` binds only what can be known:

```text
expectedParentStateDigest + expectedVersion
sourceEventDigest
baseSnapshotRoot
effectRequestDigest when applicable
allowedOutcomeSchemaDigest
allowedMutationConstraintsDigest
policyEpoch
```

It does not contain a guessed result or new-state digest.

After computation or a terminal effect receipt exists, a `StateCommitIntent` binds:

```text
expectedParentStateDigest + expectedVersion
sourceEventDigest
terminalReceiptDigest when applicable
terminalOutcome
laneMutationDigests[]
baseSnapshotRoot
policyEpoch
newStateDigest
```

Pure internal mutations whose exact output is already known may create `StateCommitIntent` directly. Result-dependent external mutations must pass through prepare → terminal receipt → exact commit. Commit uses compare-and-swap. Same event ID with different canonical payload is a conflict. Duplicate identical events are idempotent. Event append is the source of truth; lane projectors persist `(logOffset, snapshotRoot)` and replay after crash. Append failure cannot be swallowed while state still folds forward.

### 15.8 Memory horizons are projections, not duplicated memories

`BASEventLogEntry/Storage` remains the sole durable source sequence. “Current / day / week / month” are rebuildable projection manifests over event ranges, not four stores that copy and independently edit content:

| Horizon | Meaning | Manifest proof |
|---|---|---|
| `current` | active working set for the admitted Mission/Objective/WorkUnit | exact workspace/task roots, active Attempt, source ranges and high watermark |
| `day` | calendar-day episode/summary projection | source ranges, timezone/calendar policy digest, provenance, coverage, invalidation epoch |
| `week` | calendar-week consolidation and unresolved threads | original source ranges or sealed lossless checkpoint; day manifests are acceleration/provenance hints only |
| `month` | longer consolidation, durable patterns, and supersession graph | original source ranges or sealed lossless checkpoint; week manifests are hints, never source truth |

One versioned `CalendarPolicy` artifact binds calendar identifier, locale, timezone identifier, tzdb/ICU/OS rule build, week start, minimum days in first week, day boundary, ambiguous/nonexistent DST resolution, and effective transaction interval. `CalendarPolicyDigest` is derived from that artifact and never supplied as a second raw identity. A timezone/calendar/rule change creates a new artifact, supersedes/invalidates affected manifests, and deterministically rebuilds them without rewriting source events. Each projection preserves the canonical `BitemporalInterval`, provenance, coverage/loss, source watermarks, calendar artifact ID, and policy/deletion epoch.

A lossy day/week summary can never become the sole input to a higher horizon. Every projection must replay directly from original events or a sealed **lossless** checkpoint whose source range/root and replay equivalence were proven. Parent manifests only accelerate discovery. EventLog pruning/compaction is allowed only after such a checkpoint and retention authorization are sealed; erased payloads remain erased and rebuild to blinded tombstones, not recovered content.

Memory classification is orthogonal rather than one giant enum:

- cognitive kind: episodic, semantic/factual, procedural, preference/constitution, task, entity/relation, evidence/conflict;
- temporal horizon: current, day, week, month, archival;
- physical tier: active memory, mapped/indexed, durable local, optional remote projection;
- governance state: eligible, quarantined, superseded, retracted, erasure-pending, erased tombstone;
- authority scope: host/user/workspace/project/task/purpose/projection.

Privacy erasure and append-only audit are reconciled by a durable, idempotent `ErasureSaga`. Erasable content is stored as an encrypted payload/artifact reference under a per-erasure-domain data key; the append-only EventLog retains only the minimum blinded identity, ordering, policy, and integrity commitment needed for audit. Its persisted rank is:

```text
requested
→ quarantine_committed(deletionEpoch advanced + grants revoked + dependent Attempts fenced)
→ closure_frozen
→ key_destruction_pending → key_destroyed
→ owner_purge_receipts_collected
→ rescan_verified
→ sealed_blinded_tombstone
```

The first K3 transaction appends the request/quarantine transition, advances `deletionEpoch`, removes query eligibility, and transitively revokes/fences affected snapshots, caches, grants, Provider leases, and Attempts **before** any physical deletion. Every later transition is append-only and replayable. Key destruction has a durable pending state; after a crash, recovery queries key absence and continues rather than recreating it. Each cache/index/Provider/storage owner returns a purge receipt, then a closure rescan verifies no eligible derivative remains. An unreachable Provider/backup produces `erasure_indeterminate`: access remains permanently quarantined and the uncertainty is disclosed; the system never reports verified erasure or re-enables reads.

This promises immediate logical revocation, cryptographic erasure of locally controlled ciphertext, and best-effort physical purge; it does not claim flash-cell bit zeroing or deletion of an unreachable third-party copy without a receipt. Snapshots/caches/releases/commits bind and recheck `deletionEpoch`, and RSI/projectors are forbidden to reconstruct deleted material from obsolete derivatives.

### 15.9 Sparse linguistic annotation graph

Language structure is a lazy, sparse annotation graph over canonical spans, not a mandatory serial NLP pipeline or a new universal ontology. An Attempt requests only the annotation strata needed for grounding, memory, verification, or tool schema:

```text
span/token → lemma/morphology → dependency syntax
→ predicate/arguments → entity/coreference
→ proposition + polarity/modality/negation
→ event/time → discourse/dialogue act
→ evidence/provenance/conflict → pragmatic goal
```

Annotation identity uses canonical normalized-text artifact ID + UTF-8 byte-span `[start,end)` + annotation-kind ID. Token indices are derived views bound to a tokenizer digest and never stable identity. Every annotation records annotator/provider ID, model/rule/config version, confidence and epistemic status, required/optional/unsupported outcome, source/provenance, snapshot/policy/deletion epochs, and parent annotation references. A Provider-produced annotation stays an untrusted proposal until its schema/span/provenance checks pass; missing optional strata degrade explicitly, while missing required strata remand/fail.

L6 owns situation/intent/dialogue-act interpretation, L7 owns evidence/conflict/grounding semantics, and L8 owns stored/queryable annotations and their provenance. Adapters preserve stable external identifiers and mappings to Universal Dependencies, Universal PropBank-style predicate roles, UMR, and ISO 24617-2 dialogue acts where applicable. Qinao reuses certified parsers/taggers or deterministic rules through Provider/adapter contracts; it does not reimplement every linguistic analyzer or force absent/uncertain annotations into fake certainty.

### 15.10 Retrieval execution chain and storage ownership

The default query plan is cheap-to-expensive and authority-preserving:

```text
L7 EligibilityPredicate
→ compiled SQL/index hard prefilter
→ exact/grep
→ SQLite FTS5/BM25
→ dense ANN
→ temporal/episode
→ entity/relation graph
→ existing Rust reciprocal-rank fusion
→ L7 full hard-eligibility validation
→ deterministic State Market frontier
→ optional/required small-model grounding proposal
→ deterministic grounding validation
→ bounded final State Market recomputation when accepted features changed
```

Lanes may fan out after hard SQL/scope pruning when the profile proves net benefit; the written order is a logical guard order, not a requirement to serialize every I/O. Exact/FTS keeps lexical precision, dense retrieval recovers semantic paraphrase, temporal and entity lanes preserve episode/relation structure, and fusion retains lane/provenance labels through selection.

“grep” means a bounded in-process literal/regex scan over already authorized materialized bytes; iOS does not spawn a shell process. It emits span/provenance receipts and is skipped when FTS metadata proves the same query can be answered more cheaply.

K3 has one SQLite ownership domain, and each database path/WAL has exactly one Swift connection-pool/write owner. Existing Swift event/memory stores converge as ports or migrations inside that domain and supply immutable rows by extending the existing narrow Rust C-ABI seam to reuse the existing pure Rust RRF implementation; Swift and Rust must not independently open the same WAL. A future Rust database owner is allowed only as an end-to-end storage migration with cutover/replay proof and retirement of the Swift owner, never dual-open coexistence. Metal/MLX is reserved for certified dense/neural kernels; C/C++ is used only at stable upstream/runtime ABI seams, not to duplicate orchestration or authority already owned in Swift/Rust/SQL.

## 16. Context Budget Allocation and State Compilation

L3 receives only L7-approved projections. It allocates a total context budget across:

- immutable system/sovereign instructions;
- L5 constitution;
- user input and conversation state;
- grounded evidence and conflict disclosures;
- tool schema/protocol;
- generation reserve.

`ContextBudget` records requested, admitted, truncated, compressed, and reserved tokens by class. Compression is provenance-preserving: the summary artifact points to source artifacts and declares loss/coverage.

`CompiledContextDescriptor` binds:

- `attemptRefArtifactID` (transitively binding `ContextWorkspaceRef`) and `workspaceReadSnapshotArtifactID/root`;
- canonical token history digest;
- tokenizer and template/tool-protocol digest;
- ordered projection digests;
- position convention;
- prefix-cache key;
- context budget receipt;
- the canonical `executionBindingArtifactID`, from which QualityIdentity and the exact per-turn `NeuralExecutionContractDigest` are derived and equality-checked.

Tokenization is performed once per canonical compiled context. That single call returns the flattened canonical tokens plus one ordered contiguous token span per selected segment. Spans cover the stream exactly and let L3 validate each segment's certified bound, exact per-class allocation, and the total limit without a second tokenization; malformed/missing/overlapping spans fail closed. Token and span digests are both part of the descriptor. Any backend receiving the context must prove compatibility with the same tokenizer/template and boundary-ownership contract.

### 16.1 Context engineering for independent windows

Each logical window has an independent context graph, budget history, summary lineage, conflict set, task projection, and active Attempt fence. It does not have an independently mutable copy of global memory or an assumed resident model instance. The State Compiler materializes a bounded, ordered packet from immutable references:

```text
sovereign/system prefix
→ host constitution
→ Mission/Objective/WorkUnit frame
→ current input and minimal dialogue state
→ selected evidence + conflicts + provenance
→ tool/protocol schema
→ generation reserve
```

Context is treated as an allocated working set, not an append-only chat transcript. Old turns enter only through provenance-bound state/memory projections. Summaries declare source ranges, loss, coverage, and invalidation; no summary becomes source truth. Tool observations and model proposals are labelled and scoped so they cannot masquerade as host/user instructions.

The signed host model choice and Provider capability admission occur before exact tokenization because tokenizer, template, tool protocol, positional convention, and cache geometry are model-bound. A same-identity backend switch may reuse the descriptor only with exact compatibility proof. A cross-model choice recompiles from canonical pre-token artifacts; tokens, prefix state, proposal state, and capabilities from the prior model are not transplanted.

The compiler emits both the exact provider-facing projection and the full provenance/authority map retained by Qinao. The Provider sees only the authorized materialized packet; it cannot request arbitrary workspace expansion. ΩG may propose one bounded retrieval/remand before visibility, after which the next change is a new compiled descriptor generation and old Provider work is fenced.

## 17. Cache Taxonomy

Caches are distinct and independently budgeted:

| Cache | Owner | Key requirements | Recovery rule |
|---|---|---|---|
| compiled context cache | L3/K3 | projection order, tokenizer/template, policy epoch | rebuild from artifacts |
| prefix cache | L2/K2 | exact model/quant/tokenizer/template, generation contract, prefix tokens, StateABI | discard/re-prefill on mismatch |
| NeuralStateCache | L2/K2 | session, position, exact QualityIdentity, NeuralExecutionContractDigest, StateABI | never reinterpret bytes under another ABI |
| Core AI specialization/AOT cache | Adapter/IO | source/AOT digest, device architecture, OS build, options, function/tensor ABI | cache miss/OS update triggers re-specialization and profile invalidation |
| SemanticStateLake index cache | K3 | snapshot/schema/index epoch | reload/rebuild without changing semantic source of truth |
| verifier/result cache | L10 mechanism port | exact input/model/policy/verifier digests | never cross policy or verifier epoch |

A cache is an optimization, not evidence of placement, correctness, authorization, or durability.

Every entry carries a `CacheVisibilityClass`, authority/workspace scope where private, source snapshot/deletion/policy epochs, exact model/runtime binding where neural, and an immutable content identity. Sharing is allowed only as follows:

- process-global immutable public material: signed model weights, public AOT/specialization artifacts, and token prefixes explicitly classified as public;
- authority/workspace-private material: compiled context, private/public-mixed prefix state, neural checkpoints, Provider proposals, verifier results, and response spools, all keyed by authority scope + workspace + snapshot + policy/deletion epochs;
- no cache key or hit/miss timing may expose another workspace's private membership through an API-visible side channel.

Immutable shared entries use reference-counted leases. Cancelling/fencing one Attempt releases only that reference; it cannot invalidate another Attempt's compatible public entry. Eviction prevents new acquisition, waits for current safe references, and never converts an in-use authoritative checkpoint into missing truth.

Qwen3.5-4B is a hybrid Gated DeltaNet/attention model. Its continuation state is therefore not safely modeled as an arbitrary trimmable attention-only KV prefix. Reuse requires an exact compatible prefix checkpoint covering attention KV **and** recurrent/convolution state at the same accepted-token boundary; otherwise Qinao performs canonical re-prefill. Apple EpiCache-style episodic eviction remains a research lane until the hybrid StateABI, continuation quality, and recovery proof pass.

## 18. Silicon Capability Fabric

Silicon Capability Fabric is the cross-plane contract that makes current Air optimizations and future-device evolution honest.

### 18.1 `CapabilitySnapshot`

Contains raw or explicitly classified observations and is stored as an Artifact Mesh payload. Its artifact envelope supplies identity:

```text
capturedAt + freshness
device capability fingerprint
OS build + runtime/vendor build
public API availability
thermal state + Low Power state
memory advisory + resolved active hard cap
model/runtime access state
requested/observed/unknown placement fields
probe provenance + observation quality
```

Rules:

- unknown enum/state is not mapped to nominal;
- presence of an ANE does not imply operation support, batch size, memory, latency, or placement;
- private/undocumented diagnostics are research-only and cannot become a public SDK contract;
- architecture/chip names may namespace assets and evidence, but cannot alone select a production strategy.

### 18.2 `CertifiedBackendProfile`

The promoted profile is an Artifact Mesh payload; `profileArtifactID` is the profile identity. Its certification key is:

```text
QualityIdentity
supported generationSemanticsDigest / contract family
artifact/bundle digest
adapter binary/build digest
backend graph/kernel digest
device capability fingerprint + SKU cohort
OS build cohort + runtime/vendor commit
phase + batch + context + shape bucket
StateABIDigest
specialization/AOT options and function identity
quality, latency, memory, thermal, energy evidence
evidence grade + sample count + devices + expiry
fallback graph digest
```

Any key change invalidates the profile. Outliers and cross-cohort aggregation are rejected unless the profile explicitly declares a safe common scope.

### 18.3 `SiliconLeaseOffer`

A lease is an app-level cooperative promise, not an OS silicon reservation. It carries:

```text
leaseID
parentRunLeaseArtifactID
capabilitySnapshotArtifactID + snapshotEpoch
profileArtifactID + executionBindingArtifactID
phase + heavyOwnerID
memory reservation + maximum transient
deadline + expiry
revalidation conditions
cancellation/checkpoint policy
authorization binding digest
```

Start uses compare-and-start revalidation. Thermal, memory, access, OS, or profile changes may defer/revoke the offer. Running work moves through `revoke_pending` and reaches a safe checkpoint; it does not pretend that the OS resource was physically reserved.

### 18.4 `UsageReceipt`

Records actual outcome:

```text
leaseArtifactID / parentRunLeaseArtifactID
profileArtifactID / capabilitySnapshotArtifactID / executionBindingArtifactID
actual backend and strategy
requested, observed, inferred, and unknown placement fields
phase times and accepted-token counts
memory footprint and maximum transient
thermal/power transitions
cache/JIT/specialization state
MTP proposed/accepted/fallback data
command-buffer/runtime failures
state migration/rebuild decision and resulting StateABI artifact reference
quality/verifier/termination result
```

Repeated quality/profile/StateABI/fallback fields in request, lease, authorization, and receipt are derived display projections only and must assert equality with the one execution binding; they are never independent caller inputs.

Requested placement and actual placement remain separate. Unknown remains unknown.

### 18.5 Unknown future devices

A new device starts in `quarantine/conservative`:

1. validate public API compatibility;
2. run known-answer quality and canonicalization probes;
3. resolve memory cap and reserve a safe baseline;
4. execute bounded cold/warm/thermal/failure probes;
5. create exact-scope E3 evidence;
6. require E4 before production promotion.

An unknown device never inherits fixed ANE claims or performance certificates from A19 merely because it reports an accelerator.

If no portable profile passes admission, the feature is unavailable. It does not automatically run a 4B model on CPU.

### 18.6 Robust Pareto selection and deterministic fallback

Candidate plans enter optimization only after hard gates for exact quality/model identity, authority/disclosure, memory fit, StateABI/rebuild legality, profile freshness/evidence, and signed fallback closure pass. A faster ineligible plan is not on the Pareto frontier.

For each eligible plan the evidence record carries confidence intervals and freshness for latency/accepted goodput, energy, resident/peak memory, thermal slope, failure rate, and rebuild/switching cost. Dominance is uncertainty-aware: a challenger replaces the incumbent only when its conservative envelope improves the configured objective without worsening a hard-constrained dimension, or policy declares a versioned trade-off. Stable plan-ID tie-breaks, hysteresis, minimum dwell time, and switching cost prevent oscillation. Same-turn adaptation may select only nodes/edges in the pre-authorized signed envelope.

Every fallback transition re-runs resource feasibility against the current `CapabilitySnapshot` and MemoryLedger. At serious/critical pressure the order is: fence the failing physical state, stop new heavy dispatch, release optional residency, pause, then re-admit an exact-compatible target or canonical re-prefill. A fallback edge is authorization to *consider* a target, not proof that it currently fits. Unknown thermal/capability state never inherits nominal admission.

The objective is healthy completed-task utility: verified accepted/released goodput, energy, memory headroom, thermal sustainability, UI responsiveness, and recovery risk. It is never “keep every Apple engine busy.”

## 19. Healthy Phase Ownership on Apple Silicon

| Phase | Authoritative owner | Useful cooperation | Prohibited pattern |
|---|---|---|---|
| normalize / intent | CPU at appropriate QoS | storage/network adapters supply bytes | blocking UI thread with model or whole-file state reads |
| retrieval | CPU + SQLite/index/storage under K3 budget | independent lanes fan out; dense microhead only if certified | SemanticStateLake work stealing heavy decode memory without reservation |
| context compile | CPU/K3 mechanism | copy-on-write artifacts, tokenize once | repeated serialization and tokenization per backend |
| model load | one external Provider under a K2 logical lease | storage read, signature verification, prewarm | SDK-owned concrete model package, two private trunks, or load before dynamic admission |
| prefill | one Provider holding the process-wide local `HeavyPhaseLease` | GPU/NAX/ANE path only as certified by exact profile; bounded chunk yield | parallel “race” whose losing full prefill is discarded |
| decode | one authoritative Provider lease; MLX may internally multiplex only as certified | prompt lookup/native MTP proposal verified by target | concurrent Providers both producing authoritative output for one Attempt |
| verification | CPU first; accelerator only by profile | independent cheap checks overlap | verifier contention that reduces accepted-token goodput |
| prepare/commit | K3 storage + K4 helper + Zone-C broker | small crypto/SQLite work | model residency duplicated for commit |

“One heavy owner” means one authoritative local accelerator-intensive execution owner process-wide per phase, and one authoritative Provider lease per Attempt. It does not prevent safe internal batching inside that owner, remote/network waits overlapping a different local phase, or CPU/storage work under separate reservations. Weighted fairness, aging, bounded prefill chunks, and a profile-derived maximum uninterruptible quantum prevent one long-context window from indefinitely blocking others.

## 20. Backend Portfolio and Horizons

### 20.1 H0 — Current production baseline

**External certified Qwen3.5-4B MLX/Metal Provider**

- is the current signed host-default full-quality Provider, not a concrete runtime embedded in Qinao SDK;
- owns leased physical model bytes, runtime sessions, load, prefill, token loop, and physical prefix/continuation state while Qinao K2 owns the logical plan, identity, lease, checkpoint, acceptance, and retry truth;
- NAX/TensorOps use is an internal MLX/Metal optimization that requires actual-use evidence; a miss falls back inside the same MLX/Metal model identity;
- all entry points, including session decode, use the same planner/executor/fallback semantics.
- the official Qwen3.5-4B bundle describes a hybrid Gated DeltaNet/attention trunk and multi-step-trained MTP; production native MTP therefore requires the exact signed MTP tensors, decoder algorithm/configuration, target-verification contract, and StateABI. Model-name or head-presence detection is insufficient, and Qinao does not train a redundant second MTP head.
- the model card's native `262,144` context is a model capability, not an iPhone admission promise. L3/K1 select a smaller exact context/window whenever the certified resident+transient ledger cannot prove the larger shape fits; they report truncation/coverage rather than loading an unsafe advertised maximum.

**Core ML microheads**

- independent classifiers, rerankers, detectors, or verifiers;
- certified per model, function, shape, OS cohort, latency, memory, quality, and thermal result;
- `.all` or an accelerator preference means “allowed compute units,” not proof of Neural Engine placement.

**Foundation Models sidecar**

- optional and availability-gated;
- suitable only for replaceable auxiliary tasks with an explicit semantic contract;
- not the sovereign full-quality model, SemanticStateLake authority, or hidden fallback.

All three are Provider/adapter implementations outside Qinao SDK. Only the signed host policy may select them, and every output remains a proposal until its Qinao adoption path completes.

### 20.2 H1 — Core AI research and certification lane

Core AI may provide AOT, stateful inference, optimized layouts, preallocation, and improved framework integration. Its `InferenceFunction` concurrency capability permits concurrent tasks when memory policy allows; serialization is therefore a memory/thermal/ownership policy, not an assumed API-safety requirement.

Core AI remains research-only until it proves:

- exact source/model/function/options identity;
- compatible tokenizer/template and output semantics;
- exact StateABI or a certified converter/re-prefill path;
- quality and termination parity;
- memory and maximum transient within the global ledger;
- cold/warm specialization behavior across OS updates and cache eviction;
- thermal, energy, cancellation, helper, and recovery behavior;
- no regression under two devices and the required OS cohorts.

A 32-step architecture probe or one-device beta run is not a generative-backend certificate.

### 20.3 H2 — Future Apple Silicon

Future hardware changes only:

- `CapabilitySnapshot` values;
- available adapter implementations;
- certifiable backend profiles;
- measured performance/energy envelopes.

It does not change:

- 14-layer semantic authority;
- 4 kernel boundaries;
- 4 ring semantics;
- 7 plane count;
- Artifact/Capability Mesh;
- QualityIdentity, NeuralExecutionContractDigest, StateABI, authorization, effect saga, or evidence rules.

## 21. Full-Blood Quality Contract

### 21.1 Quality identity

```text
QualityIdentity = {
  modelLineageID,
  architectureDigest,
  weightsDigest,
  quantizationDigest,
  tokenizerDigest,
  templateAndToolProtocolDigest,
  generationSemanticsDigest,
  verifierDigest,
  sovereignPolicyEpoch
}
```

`generationSemanticsDigest` covers the versioned generation algorithm and defaults:

- greedy/sampling/speculative decision semantics;
- temperature, top-p/top-k/min-p and other warpers;
- logit processors, repetition/presence/frequency penalties, forced/banned tokens;
- RNG algorithm and seed/stream-derivation contract;
- stop/EOS, tool-call, structured-output, termination, and maximum-token semantics.

Every turn derives an exact:

```text
NeuralExecutionContractDigest = H(
  QualityIdentity,
  actual turn sampling parameters,
  RNG algorithm + seed/stream identity,
  active logit processors,
  stop/EOS/termination grammar,
  output/tool protocol and token limit
)
```

The model bundle declares the supported generation-semantics family. The exact per-turn `NeuralExecutionContractDigest` is bound into compiled context, lease, authorization, fallback edges, and usage/result receipts. Two backends are full-blood equivalent for a turn only if both QualityIdentity and this per-turn contract are identical.

Canonical identity encoding is tagged, versioned, and exhaustive. Every stored field participates exactly once; `sovereignPolicyEpoch` and the per-turn maximum-output-token limit use fixed-width unsigned canonical bytes rather than native `Int` or JSON formatting. A count-pinned field-mutation suite must fail if any single stored field changes without changing its owning digest.

The signed model bundle additionally binds runtime and execution material:

```text
bundleDigest = H(
  QualityIdentity,
  config + RoPE + adapters/LoRA,
  function/graph/kernel identity,
  StateABIDigest,
  supported generation-semantics contract,
  backend/runtime build,
  certified fallback graph
)
```

### 21.2 Allowed full-blood adaptation

Thermal or memory response may:

- run more slowly;
- reduce speculative depth or disable a negative-value speculative lane;
- wait, queue, pause, or reject new work;
- evict non-authoritative caches;
- preserve an incremental checkpoint at a safe token boundary;
- discard incompatible neural state and rebuild prefill from canonical token history;
- switch to a backend certified equivalent under the same QualityIdentity, per-turn NeuralExecutionContractDigest, and state rules.

It may not:

- change weights, quantization, tokenizer, template/tool protocol, verifier, or sovereign policy;
- silently switch to a smaller model;
- change KV precision in a way that fails quality identity gates;
- reduce mandatory retrieval, conflict, verification, or risk coverage;
- skip required verification or relax L14;
- cap the answer merely to make a throughput claim look better.

A separately trained 2-bit, fixed-expert, pruned, distilled, ReDrafter, or native-MTP model is a new model lineage. It may become a future promoted product profile after full certification, but it is never an in-turn thermal fallback for the current lineage.

### 21.3 Speculation never owns truth

Prompt lookup, MTP, ReDrafter, or other speculative mechanisms propose tokens. The target trunk verifies accepted tokens and termination. Every mechanism must pass a never-worse gate based on accepted-token goodput, quality, memory, energy, and thermal behavior.

The fallback from speculation is an explicit plan such as `mlxPlain(bundleDigest)`, not a generic decode purpose that might select speculation again.

## 22. Prefill and Decode Routing

### 22.1 Prefill Router

The four modes are:

1. **full prefill** — consume complete canonical tokens;
2. **suffix continuation** — reuse an exact compatible prefix state and prefill only the suffix;
3. **prefix cache restore** — restore state whose prefix key, QualityIdentity, NeuralExecutionContractDigest, and StateABI match exactly;
4. **context rebuild** — discard state and reconstruct canonical context/tokens before full prefill.

Selection records why a cache/state was accepted or rejected. “File exists” or “same model name” is insufficient.

### 22.2 Decode Router

The decode strategies are:

- plain target decode;
- prompt lookup with target verification;
- multi-token prediction/drafting with target verification.

Fallback is not a fourth decode strategy. It is a signed lease/recovery graph whose edges name an exact backend, strategy, bundle, StateABI rule, and recovery action.

All decode entry points share:

- the same dynamic admission;
- the same QualityIdentity and NeuralExecutionContractDigest;
- the same planner/executor;
- the same acceptance/fallback logic;
- the same receipt schema;
- the same state rollback/rebuild proof.

## 23. StateABI and Backend Switching

### 23.1 StateABI digest

`StateABIDigest` covers at least:

```text
state schema and canonicalization version
tensor names and order
dtypes, shapes, strides, layout and endianness
layer/head grouping
position and cache-index convention
RoPE/scaling convention
quantization scales/groups and precision
fill/empty value semantics
maximum sequence and batch semantics
model/config/weights binding
runtime/function state version
attention KV + GDN recurrent/conv state geometry
pending-input token ID/digest, ownership, and accepted-boundary convention
RNG/sampler/logit-processor state convention
stop/tool/structured-grammar automaton state convention
```

### 23.2 Target truth and speculation scratch are separate

Each accepted target boundary has one Qinao-owned logical `TargetContinuationCheckpoint`. Provider bytes may be opaque or copy-on-write, but the Provider cannot choose the logical identity/version or advance it without an accepted observed receipt. The checkpoint binds:

```text
attemptRefArtifactID + visible-prefix/command fence
QualityIdentity + NeuralExecutionContractDigest
Provider state lease ID + logical version
StateABIDigest + model/runtime/bundle binding
attention KV + GDN recurrent/conv physical-state reference
absolute/logical position + cache geometry + dtype/layout + RoPE
canonical accepted-token history digest
pending input token ID/digest + ownership
RNG algorithm/stream/cursor
sampler + logit-processor state
stop/EOS/tool/structured-output grammar automaton state
checkpoint integrity/availability proof
```

MTP, prompt lookup, ReDrafter, or any future draft mechanism receives a distinct disposable `SpeculationScratch`. Draft tokens and draft recurrent/KV state never overwrite the target checkpoint. Only target-verified accepted tokens can atomically advance the target logical version. Rejection discards scratch and leaves target truth unchanged.

### 23.3 Switching and unknown-state rule

- Before prefill creates neural state, any admitted certified Provider may be selected.
- After state exists, physical bytes may cross a Provider/backend boundary only when `StateABIDigest` matches exactly or a certified source→target converter exists.
- A converter has its own digest, quality proof, resource profile, expiry logical time, and fallback receipt. Selection receives the immutable Attempt logical time explicitly; a converter is invalid at or after expiry, and replay records the evaluated time and expiry rather than consulting wall clock.
- Otherwise K2 fences/releases the Provider state and redoes prefill from canonical accepted token history under a newly admitted Provider lease.
- A crash, timeout, corrupt reply, or missing observed receipt that leaves Provider physical state unknown invalidates that state; finite-looking bytes are not evidence of compatibility.

Canonical rebuild is an automatic recovery option only before any output became visible and before an effect/publication boundary. After visible output, Provider-state loss requires a user-visible resume/new Attempt policy; Qinao never silently regenerates the same turn and risks a duplicate/divergent continuation.

Every fallback edge and converter identity is inside the signed authorization/model bundle closure. Runtime code cannot invent a wider fallback after authorization.

### 23.4 Native MTP collapse and re-probe

When native MTP acceptance or net utility collapses, K2:

1. stops admitting new draft commands and fences the current scratch generation;
2. discards `SpeculationScratch`;
3. restores or proves the last `TargetContinuationCheckpoint`;
4. re-admits the signed plain-target node against current memory/thermal constraints;
5. continues only if canonical target state, termination automaton, RNG cursor, and visible-prefix fence match.

The never-worse gate uses a paired sliding window over accepted-token goodput, energy per accepted token, memory/transient cost, and thermal slope—not proposed-token throughput. Demotion and bounded re-probe have separate thresholds, minimum sample counts, dwell time, and hysteresis. A failed/collapsed path cannot immediately oscillate back on one favorable sample.

## 24. Process-Wide Memory Ledger

K1 owns one process-wide `MemoryLedger` covering:

- trunk weights and mapped model assets;
- draft/MTP weights;
- active KV/recurrent/NeuralStateCache;
- prefix/session caches;
- MLX pools and command buffers;
- Core AI/Core ML loaded functions and intermediates;
- SemanticStateLake indexes, lane results, whole-file/transient copies;
- verifier/model auxiliaries;
- response spool and artifact buffers;
- maximum concurrent activation/transient allocation;
- safety reserve for UI, OS, framework, and untracked growth.

`os_proc_available_memory` or equivalent public advice is advisory. Admission combines:

- resolved entitlement-aware active hard cap;
- live footprint/headroom;
- certified resident and peak/transient requirements;
- current reservations;
- safety reserve;
- thermal and Low Power policy.

The ledger does not reimplement framework-local memory management. For MLX work, it first grants the BAS application-level reservation and then acquires the vendored upstream `WiredMemoryManager.shared` ticket; release happens in reverse order. MLX waiting, cancellation, hysteresis, baseline restoration, wired-limit ownership, and live snapshots remain upstream responsibilities. A second MLX waiter/limit manager, direct `mlx_set_wired_limit` control path, or duplicated hysteresis state is forbidden. Core ML/Core AI/Metal reservations use their public runtime ownership and feed actual observations back into the same BAS application ledger.

The phase transaction is:

```text
observe → reserve resident + maximum transient → compare-and-start
→ allocate/execute → record actual peak → release or transfer reservation
```

If it does not fit, the system rejects/defer the phase before model load. Disabling speculation and then loading an unadmitted trunk is forbidden.

No large emergency checkpoint is first created at critical memory. Small incremental recovery state is maintained at already safe boundaries; critical handling releases optional memory and pauses at the next safe point.

## 25. Thermal, Power, Cancellation, and Backpressure

The resource state is explicit:

- `nominal`;
- `fair`;
- `serious`;
- `critical`;
- `unknown`;
- Low Power Mode as an independent signal.

Unknown is conservative/defer, not nominal.

Policy:

| State | New work | Running work | Quality |
|---|---|---|---|
| nominal | admit by profile and ledger | normal certified plan | unchanged |
| fair | reduce optional concurrency/spec depth; preserve headroom | continue with receipt | unchanged |
| serious | stop optional specialization/JIT/index work; prefer certified plain path; queue/defer | checkpoint, slow, or switch only by exact fallback rule | unchanged |
| critical | reject new heavy dispatch | stop accepting new commands, reach safe boundary, release optional residency, pause/recover | unchanged |
| unknown | defer until bounded probe or safe baseline | conservative cancellation/checkpoint | unchanged |
| Low Power | tighten concurrency and pace policy | continue only within certified envelope | unchanged |

Cancellation semantics:

- pure undispatched branches can be cancelled recursively;
- a submitted accelerator command may become `cancel_pending` and must be observed to a safe terminal result;
- effect cancellation before dispatch may be terminal;
- effect cancellation after dispatch becomes `cancel_requested` and requires reconciliation;
- cancellation never converts an unknown external outcome into “not executed.”

Backpressure bounds exist at turn, lane, branch, heavy-owner, state-commit, and effect-broker queues. Every queue declares concurrency, bytes, tokens/cost, deadline, and starvation policy.

## 26. Output Spooling and Streaming

Output has two release classes:

### 26.1 Low-risk provisional stream

Before the first byte, L11 evaluates provisional eligibility from the admitted request, L5 policy, L7 coverage/conflict state, and L3 compiled-context descriptor. L14 then issues a bounded provisional release grant whose operation and budget cover only L10 streaming verification and L12 provisional UI release. Every L2 chunk must then pass the L10 streaming constraint gate before L12 may release it:

- output is hash-chained and marked provisional;
- `ChunkVerificationReceipt` binds prior-chain digest, chunk digest/index, active constraint/policy digests, sensitivity/risk result, Attempt/generation vector, and the authoritative `BudgetUseReceipt`;
- a denied, timed-out, or missing chunk receipt stops provisional release; it never fails open;
- it cannot drive tools, external effects, durable state, or evolution;
- final verification may retract or replace it according to declared UI semantics;
- its grant binds maximum bytes/tokens, audience, Attempt/snapshot/generation vector, policy/deletion epochs, and expiry;
- once any provisional byte is visible, Provider failure cannot trigger automatic same-turn regeneration; the runtime may finalize already-proven material, disclose interruption, or offer an explicit new/resume Attempt.

L12 releases verified chunks in bounded contiguous sink batches, never by an unguarded per-token callback. Immediately before each batch, the K3 active-Attempt owner runs one conditional transaction that requires the exact active Attempt/generation, prior stream-chain head, and unarmed `[firstChunkIndex,lastChunkIndex]`; it then issues a one-use `StreamBatchBoundaryPermit` and records that exact batch as `visible_or_unknown`. The first permit also marks `stream_visibility_armed`, permanently disabling same-turn retry. L12 can call the sink only by consuming that permit. Revocation after issuance cannot pretend the armed batch stayed invisible, while any later batch fails the active-generation CAS.

The sink uses `(streamID, firstChunkIndex, lastChunkIndex, chainDigest)` as an idempotency/query key when supported. A crash or missing receipt after permit issuance is never resent; an unqueryable batch terminates the stream as visibility-indeterminate. Batch bounds come from the signed latency/byte profile, so this closes the check→revoke→sink race without requiring a SQLite transaction per decoded token.

The streaming gate is deliberately narrower than final L10 but has real L10 verification authority and its own latency/resource budget. It may use deterministic constraints and separately certified classifiers; “low-risk request” is not a substitute for examining each chunk. The provisional grant does not authorize the final answer. Completed output still passes L9 selection, L12 exact presentation/spooling, L10 exact-byte verification, L11 final risk/confirmation, and L14 exact-result authorization.

### 26.2 Medium/high-risk exact release

- L12 deterministically projects the current canonical `BASRenderedOutput` into one spool artifact without releasing it;
- L10 verifies the bytes addressed by that exact `spoolArtifactID` and their claim/projection mapping;
- L11 issues the final risk permit/confirmation requirement over that same artifact ID;
- L14 authorizes that exact result artifact ID;
- L12 first emits an exact release-preparation artifact; K3 stores/reopens the complete pre-publication manifest and reserves one publication idempotency key;
- immediately before the sink call, one K3 conditional transaction requires `activeAttempt == expected`, exact current generation vector, and publication state `prepared`, then advances `prepared → sink_boundary_armed`; only that atomic transition permits the one call;
- the sink receipt advances `sink_boundary_armed → finalized`. Crash/timeout after arm but without a queryable receipt becomes `publication_indeterminate`; recovery never calls the sink again, even though this conservative at-most-once rule can under-deliver.

If L10/L11 remands the presentation, L12 emits a new spool artifact and the old artifact's authorization path is abandoned. Medium/high-risk output has no provisional release. Pure response release and external-effect execution are separate branches; an ordinary response does not enter the effect outbox. Provisional content never becomes an implicit state/effect instruction.

### 26.3 Attempt recovery and branch join

Same-turn automatic retry is admitted only when **all** of these predicates are proven from K3/K4/Provider-observed evidence:

1. the workspace/Attempt generation is still active, the failed physical attempt and **every spawned response/publication/effect branch** are terminal or generation-fenced, and none remains `dispatch_ready`, `stream_visibility_armed`, or `sink_boundary_armed`;
2. semantic mutation is absent or has been atomically restored by Qinao proof; append-only audit evidence alone is not semantic mutation;
3. no provisional visibility fence was ever armed; observed “zero bytes” without that persisted proof is insufficient;
4. no publication/stream boundary permit or `EffectBoundaryPermit` was issued and no sink/effect boundary was armed/crossed;
5. `QualityIdentity` and the exact per-turn neural contract are unchanged;
6. target StateABI is compatible or canonical context/accepted-history rebuild is available;
7. the transition is a signed fallback edge inside the original authorization envelope;
8. current memory, thermal, deadline, capability, and Provider admission passes again.

`restored` requires a Qinao-produced `MutationRestorationProof`. Post-recovery workspace/task/semantic heads must equal the admissible pre-attempt semantic roots, while the pre-attempt EventLog is a verified prefix of the new log. The suffix may contain only allowlisted failure, audit, fence, and restoration transitions whose deterministic fold proves that semantic-root equality. Grants, leases, nonces, and budgets are **not** rolled back or resurrected: the proof requires their terminal/fenced/spent/released disposition and a successor obtains fresh authority/resources. Staged/outbox branches must be absent or terminal, and no stream/publication/effect boundary permit may have been issued. A Provider assertion cannot prove restoration.

Any unknown predicate is false. Fencing a branch invalidates acceptance but does not pretend an already armed/crossed external boundary was cancelled. A pure `AttemptRecoveryDecision` derives from persisted evidence; it is not a fourth reducer, hidden retry manager, or Provider choice. Cross-model fallback is never same-turn recovery: it terminates `model_change_required`, discloses the change, recompiles context, and starts a newly authorized Attempt.

Response publication and external effect are independent terminal branches. Their read-only join may expose states such as `response_finalized_effect_indeterminate`; it never erases branch truth. In that example the response is not generated or published again, while ΩE may only reconcile/query the existing effect operation or seek separately authorized compensation.

After a publication sink call, loss of the sink receipt permits only query/finalize under the same publication identity. If the sink cannot establish whether bytes were displayed/persisted, terminal state is `publication_indeterminate`; Qinao does not republish. After effect dispatch, recovery permits only query/reconcile/finalize or separately authorized compensation—never regenerate and redispatch.

## 27. Process and Security Zones

### Zone A — Host runtime

Contains Qinao L1–L13 semantic execution and host-side L14 decision invocation, UI, retrieval, context compiler, verifier, logical K2 orchestration, and public Provider gateway. It has public verification keys but no K4 private key or writable spent ledger. Qinao SDK owns no concrete MLX/Qwen/Foundation Models/Core AI runtime implementation.

### Zone P — Provider deployment boundary

Contains only the selected Provider package/runtime, leased physical model assets/state, and narrow transport. For `inProcessCertified`, Zone P is a logical/package boundary inside the Zone-A process and offers no hostile-code isolation; for `isolatedExtension` or `remote`, it is a real process/network boundary with stronger projection and transport controls. In every class its proposals are untrusted and it has no Qinao store, tool, release, effect, or sovereign capability.

### Zone B — Enhanced Security helper / K4

On the iOS 27 minimum deployment, a minimal Enhanced Security helper owns:

- signature operation;
- issuance/reserve/spend ledger plus non-deletable global nonce tombstones across authorization IDs and key rotation;
- key manifest and rotation state;
- audit-chain anchoring;
- query-by-requestID recovery protocol.

It contains no model, KV, prompt corpus, UI, or effect adapter. Its private storage is not writable by Zone A. Enhanced Security narrows process/sandbox exposure; it does not automatically provide transactionality, remote attestation, semantic correctness, or effect idempotency.

The product deployment floor is iOS 27. Production K4 therefore always uses the Enhanced Security helper extension boundary; there is no in-process production compatibility mode. A same-process signer/service may exist only in tests and must be labeled `testOnly`, use separate keys/storage, and remain impossible to select from a release build.

### Zone C — Effect Broker

Contains adapter-scoped external capabilities and a durable outbox. It receives an exact operation authorization, not a general L14 private key or model context. Each adapter has the minimum network/filesystem/account entitlement required.

## 28. Signer and Key Lifecycle

### 28.1 Current truth

The current Ed25519 implementation stores a raw seed in Keychain and reconstructs a `Curve25519.Signing.PrivateKey` in process. The accurate claim is:

- Keychain at-rest protection;
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` in the current binding;
- process/helper isolation according to deployment;
- not a non-exportable Secure Enclave Ed25519 private key.

### 28.2 Algorithm-agile target

`SovereignSigner` supports explicit suites:

- v1 compatibility: Ed25519 in Keychain/helper, with honest custody label;
- optional hardware-root/epoch anchor: `SecureEnclave.P256.Signing.PrivateKey` where supported and policy-selected;
- future suites only after public API availability and separate certification.

Minimum `SignatureEnvelope` proof body inside an `ArtifactAttestationPayload` or self-contained transport wrapper:

```text
signatureSuite
hashSuite
signatureEncoding
canonicalizationVersion
keyID + keyEpoch
publicKeyDigest
targetArtifactID
signedStatementDigest
signatureBytes
custodyClass
```

Replay identity is `authID + nonce + exact request digest`, never ECDSA signature bytes.

Rotation uses one algorithm-agile signed trusted-key manifest, overlapping verification window, legacy verify-only status, explicit revocation, and audit continuity. The current `BASSovereignFingerprintManifest` is a v1 decode/migration view, not a second active trust root. Unknown suites, downgrade attempts, key/ledger discontinuity, or missing historical verification keys fail closed.

## 29. Durable Authorization Ledger

K4 commits issuance before returning a signature. The helper-private transaction covers:

```text
requestID uniqueness
authID + nonce uniqueness
capabilityGrantArtifactID
authorizationContextArtifactID + canonical root
issued/reserved/spent/revoked status
operationID binding
key epoch + policy epoch + boot/warrant epoch
deadline
audit-chain link
```

The authorization-context artifact is owned by the exact execution/effect/release plan and binds its request, model/profile/lease/effect/fallback/StateABI/quality/neural facts once. K4 loads and recomputes the grant and context roots; a caller cannot supply a second `grantCanonicalDigest` or an optional list of equivalent identity fields.

The K4-local claim transaction atomically changes `issued/reserved → spent_for_operation` and persists the one canonical capability-use/claim receipt before returning it. Validation and claim cannot each consume the grant or write competing receipts. That atomicity stops at the K4 storage boundary; it does not include Zone-C storage. A crash or lost IPC reply is recovered by querying the same `requestID/operationID`; the host does not ask for a fresh signature.

Ledger corruption, rollback suspicion, missing schema migration, or loss enters quarantine. Recreating an empty ledger under the same signing key is forbidden.

The helper XPC boundary treats Zone A as untrusted input:

- bounded message lengths;
- canonical decoding and schema version;
- anti-downgrade negotiation;
- deadlines and cancellation;
- request/response correlation;
- replay checks before semantic acceptance.

## 30. Effect Broker and Commit Saga

### 30.1 Effect classes

Every adapter declares one class:

- `readOnly`;
- `idempotentWrite`;
- `queryableWrite`;
- `compensatable`;
- `irreversibleNonQueryable`.

This classification determines recovery. It is part of the adapter profile and effect authorization digest.

### 30.2 Durable protocol

The end-to-end view is derived from three append-only state machines with non-overlapping write ownership:

```text
K3 state/outbox:
prepared → handed_to_zone_c → effect_boundary_possible → effect_terminal_recorded
→ staged → sealed → activated

K4 authorization:
issued → reserved → claimed_for_operation / revoked / expired

Zone C effect:
dispatch_pending → claim_observed → dispatch_ready → dispatch_boundary_armed
→ succeeded | failed_before_effect | failed_final | partial | outcome_indeterminate
→ reconciling / compensating when allowed
→ succeeded | failed_final | compensated | reconciled_indeterminate
```

Zone C never writes `staged`, `sealed`, or `activated`; K3 never writes provider dispatch/ack/reconciliation truth. A coordinator may expose a read-only joined transaction view, but cannot advance a fourth global reducer.

Required ordering:

1. L13 creates `StatePrepareIntent`, stable `operationID`, canonical `EffectRequestDigest`, expected base revision, allowed outcome/mutation constraints, and adapter recovery class. It does not guess the provider result or `newStateDigest`.
2. K3 appends that typed intent to the existing `BASEventLogEntry` sequence/integrity chain and transactionally persists the outbox/prepare projection before dispatch. A state-commit store may own invisible staging rows, but not a second event sequence, projector-cursor timeline, or hash chain.
3. L14 decides exact authorization; K4 durably issues/reserves it.
4. Zone C uses a local transaction to persist `dispatch_pending(operationID, authID, requestDigest, attemptRefArtifactID, generationVectorArtifactID)`.
5. Zone C asks K4 to claim that exact authorization. K4 uses its own transaction to bind/spend it for the operation and returns the durable capability-use/claim receipt artifact.
6. Zone C uses a second local transaction to persist that receipt reference, move to `dispatch_ready`, and emit a `DispatchReadyReceipt` bound to the full Attempt/generation vector.
7. Zone C presents that receipt to the K3 active-Attempt owner. One K3 conditional transaction requires `activeAttempt == expected`, exact current generations, the matching K4 claim, no prior boundary permit, and the K3 outbox branch still `handed_to_zone_c`; it then appends `effect_boundary_possible`, makes same-turn retry impossible, and issues one-use `EffectBoundaryPermit(operationID, AttemptRef, generationVector, dispatchReadyReceipt)`.
8. Zone C can advance `dispatch_ready → dispatch_boundary_armed` only by atomically consuming that exact permit once. The permit is a K3 recovery/hand-off fence, not a second semantic authorization; L14/K4's exact effect authorization remains required. Only then may Zone C call the adapter once with the stable provider idempotency key where supported.
9. The existing tool/effect adapter executes; Zone C records provider transaction/result/observed-state data as a terminal or indeterminate receipt artifact plus child signature attestation.
10. L13 reconciles the exact receipt, creates `StateCommitIntent` with terminal receipt/outcome and `newStateDigest`, and stages the resulting state invisibly under compare-and-swap.
11. L14 decides the terminal seal; K4 signs it.
12. K3 activates staged state and advances the visible head only after seal.

There is no cross-process atomic transaction between K4 and Zone C. Crash gaps close by stable identity and queries:

- after Zone-C `dispatch_pending` but before K4 claim, retry/query the same K4 request;
- after K4 claim but before Zone C stores the reply, recover the same ClaimReceipt by `requestID/operationID`;
- after `dispatch_ready` but before K3 issues `EffectBoundaryPermit`, resume only the same still-active branch; a fenced generation fails the K3 conditional transaction;
- once K3 issues `EffectBoundaryPermit`, recovery treats the boundary as possible even if Zone C never records consumption; it never asks for another permit or dispatches again;
- at or after permit issuance/`dispatch_boundary_armed`, only query/reconcile/finalize the same provider operation, or remain `outcome_indeterminate` when the adapter cannot establish truth; even a crash between arm and the physical call does not authorize a second dispatch.

### 30.3 Failure rules

- effect success followed by reply/receipt/seal failure is `succeeded_unsealed`; only receipt/seal is retried;
- dispatch with unknown provider outcome is `outcome_indeterminate`;
- idempotent/queryable operations reuse the same operation/idempotency key only to query/reconcile/finalize after dispatch; they are not automatically called again;
- compensatable operations require a separately authorized compensation saga;
- irreversible non-queryable operations are never automatically retried after ambiguous dispatch;
- a generic exception cannot be mapped to ordinary failure without dispatch-boundary evidence;
- only signed terminal outcomes may be sealed as their matching terminal state;
- `partial`, `cancel_requested`, or unresolved unknown outcomes cannot be sealed as committed success;
- capability reserve/spend is a durable saga continuation, not a one-shot burn that prevents recovery.

The system does not promise general exactly-once external effects. It promises durable intent, stable identity, no automatic redispatch after the durable dispatch boundary, adapter query/idempotency evidence, explicit indeterminate state, separately authorized compensation where defined, and auditable recovery.

### 30.4 Minimum effect receipt

```text
operationID + attemptRefArtifactID + generationVectorArtifactID + idempotencyKey
request/action digest
adapter ID + version + recovery class
effectBoundaryPermitArtifactID + dispatchReadyReceiptArtifactID
target and target revision
dispatch boundary and timestamps
provider transaction ID
outcome
result/observed-state digest
cancellation/partial/unknown fields
reconcile/compensation lineage
authorization and lease references
```

The effect-receipt payload has no self ID, embedded signature, or K3 seal state. Its Artifact Mesh envelope supplies identity; its signature is a child attestation; K3 records the terminal receipt artifact ID and owns the later seal/activation artifacts.

## 31. State Evolution

L13 evolution consumes completed, sealed experience from prior turns. It never modifies the currently executing semantic core, model bundle, policy, or SemanticStateLake schema in place.

Evolution flow:

```text
sealed evidence → candidate → shadow trial → critique/risk
→ signed promotion proposal → L14 authorization
→ versioned activation at a future epoch → monitored canary
→ promote, demote, quarantine, or retract
```

New trained models, quantizations, expert/pruning layouts, draft heads, converters, indexes, policies, and adapters each have explicit lineage. A promotion changes future profile selection only after its own evidence gate; it never appears as an opportunistic fallback inside an already authorized turn.

## 32. Observe, Replay, and Privacy

### 32.1 Required metrics

Latency and throughput are not collapsed into one tok/s number:

- `processColdTTFT` — process/model not resident, including verified load and required specialization;
- `warmResidentTTFT` — model and required assets resident;
- `cacheColdPrefillTPS` and cache-warm `prefillTPS` by prompt/context bucket;
- `thermallyColdResidentAcceptedDecodeTPS` — model/runtime resident, decode timer only, device entering under the declared cool-state protocol;
- `proposedDecodeTPS` and `acceptedDecodeTPS`;
- `verifiedReleaseTPS`;
- `turnShapedEndToEndGoodput` and task completion latency, including the declared normalize/retrieval/prefill/decode/verify/release boundaries;
- MTP proposed/accepted distribution and termination identity;
- energy per accepted/released token and per completed task;
- process footprint, ledger reservations, maximum transient, allocation slope;
- thermal state/time and transition latency;
- cache/JIT/AOT/specialization hit class;
- requested/observed/unknown placement;
- retrieval coverage/conflict/remand data;
- effect recovery class and terminal saga state.

`Logger` and `OSSignposter` may mirror these fields for live diagnosis. MetricKit contributes delayed E5 field/canary evidence only; its aggregated delivery cannot decide an E4 single-run certification verdict or replace the canonical device harness and Instruments evidence.

### 32.2 Replay record

A replayable turn records references to:

- canonical input and source event identity;
- policy, naming, layer-kill, and key epochs;
- SemanticStateLake snapshot and lane watermarks;
- admitted/selected artifacts and conflict manifest;
- canonical compiled token history;
- the one execution-binding artifact plus its referenced bundle, profile, lease, fallback graph, and StateABI artifacts;
- randomness seed/sampling receipt where policy permits;
- every proposal, acceptance, fallback, remand, verification, risk, release-preparation, effect, state, and seal receipt;
- the linked publication reservation, idempotency key, sink receipt, and publication finalization record.

Publication uses a durable at-most-once replay barrier. The complete pre-publication manifest contains the decision graph and prepared release but cannot contain a sink receipt that does not exist yet. K3 durably stores/reopens that manifest and reserves one publication identity/idempotency key. Immediately before the one sink call it revalidates Attempt/generation and persists `sink_boundary_armed`; that state is conservatively visibility-possible and forbids automatic retry/republish. The sink receipt is appended as a linked finalization record before the host API returns. Recovery only queries/finalizes the same publication identity. If the sink cannot establish truth, the branch remains `publication_indeterminate`; a raw prepared manifest permits a same-branch continuation only before arm, while an armed manifest is never permission to repeat the call.

Replay differentiates:

- deterministic semantic replay from immutable artifacts;
- neural replay under exact runtime/model identity;
- behavioral re-evaluation under a new runtime/profile;
- effect simulation—never blind re-execution.

### 32.3 Privacy

Tracing uses data minimization:

- artifact bodies stay in their protected data plane;
- telemetry exposes IDs and blinded/keyed commitments, not raw private text or low-entropy hashes;
- projection capabilities constrain what a verifier, adapter, or debug UI can inspect;
- production logs default to structure, sizes, timings, outcomes, and evidence references;
- explicit user/developer consent and policy are required for payload capture;
- trace retention, export, deletion, and key rotation are independently governed.

## 33. Production Certification Gates

The following are target ship gates, not claims that current code already passes them.

Final promotion evidence is bound to a Git candidate-tree ID and the exact installed runtime executable digest, not merely to a mutable working directory or branch name. The certification controller, verifier, package/app gates, and device binary all execute or build from a disposable materialization of that tree; controller/verifier/toolchain digests bind the verdict, the app reports its embedded tree identity and runtime digest, both physical-device receipts must match, and the eventual runtime commit must have the identical tree. Untracked or unstaged caller inputs cannot participate in a certified build or authorization decision.

### 33.1 Full-blood identity gate

- exact `bundleDigest` covers QualityIdentity, supported generation semantics, and runtime material; every turn also binds its exact NeuralExecutionContractDigest through lease, authorization, fallback, and receipt;
- greedy: at least `50 prompts × 2 physical devices × every fallback transition`, with 100% token and termination identity;
- sampling: at least 128 draws per arm, total-variation distance `≤ 0.01` and no worse than self-noise baseline by more than `0.003`;
- no policy, retrieval, verifier, tool-protocol, or termination drift.

### 33.2 Memory gate

- measured phase `phys_footprint ≤ 0.85 × resolvedActiveHardCap`;
- before a reallocating phase, headroom is at least `max(15% of cap, 512 MiB, certified next-phase maximum transient)`;
- zero jetsam, OOM, second trunk residency, unledgered whole-file decode-state copy, or positive long-run footprint slope;
- pressure handling is production-default, not a disabled environment-variable experiment;
- full-blood mode evicts/defers/pauses at pressure boundaries rather than changing model/KV precision without identity certification.

### 33.3 Thermal and power gate

- every exact profile runs `1800 s` on at least two physical devices;
- zero crash, jetsam, non-finite output, state corruption, or policy drift;
- minute-by-minute accepted TPS, thermal state, acceptance, energy, and footprint are reported;
- Low Power/thermal transition is reflected within one decode round or 250 ms, whichever is later under the public API observation cadence;
- critical stops accepting new heavy dispatch within 250 ms after the runtime receives the transition signal and drains only already-submitted commands;
- serious-path paired accepted-goodput ratio against matched certified plain is `p10 ≥ 0.95`, or the profile selects plain directly.

### 33.4 Concurrency and UI gate

- one process-wide **local** authoritative heavy owner, plus a separately bounded remote-I/O lease class that cannot race the same Attempt;
- at most the separately certified internal decode slots for that owner; the current candidate cap is two;
- eight-logical-window stress: no starvation, no duplicate authoritative result, one local heavy phase, and footprint remains under the same cap;
- main-thread synchronous blocking `p99 < 8 ms`;
- model and SemanticStateLake files are not synchronously whole-file-read on MainActor;
- cancellation and backpressure leave no orphan reservation, branch, session, or saga.

### 33.5 MTP/prompt lookup gate

- target verification proves token and termination identity;
- paired windows measure accepted-token goodput, energy, memory, and thermal drift;
- collapse if `EMA accepted < 0.15` or two consecutive paired windows have net ratio `< 1.0`;
- fallback is immediate, exact, and state-rollback verified;
- promotion requires at least 50 prompts per device, zero correctness failures, engaged mean `≥ 1.20×`, and every arm outside the measured thermal drift band;
- re-probe uses hysteresis to prevent oscillation.

### 33.6 NAX and heterogeneous execution gate

- actual runtime/kernel receipt, not OS/architecture availability alone;
- a NAX-labeled profile requires at least 95% of eligible dispatches to show the expected path under the available observation mechanism;
- miss versus matched Metal regression `≤ 5%` and full identity gate remains green;
- GPU/Neural Engine parallelism is allowed only if parallel wall time `≤ 0.95 ×` serial wall time without memory, thermal, energy, or quality regression;
- otherwise the work is serialized.

### 33.7 Core AI promotion gate

At minimum:

- `n ≥ 50` representative cases on each of at least two physical devices;
- label/token/termination agreement according to the task contract;
- tensor/state numerical MAE `≤ 1e-3` where applicable, plus end-task quality parity;
- latency and memory each improve by at least 5% after including specialization and copy costs for the declared cache class;
- cold/warm cache, OS-update invalidation, helper interruption, state rebuild, cancellation, memory warning, and thermal tests pass;
- a generative fallback additionally passes complete QualityIdentity, NeuralExecutionContractDigest, and StateABI gates.

### 33.8 40/30 performance claim gates

The word “cold” is never used without a qualifier. Four different claims remain separate:

| Metric | Residency/cache state | Thermal state | Timer |
|---|---|---|---|
| `processColdTTFT` | process/model absent; required load/specialization included | declared | event receipt → first releasable token |
| `cacheColdPrefillTPS` | model state declared; prefix/state cache absent | declared | first prefill dispatch → final prefill state |
| `thermallyColdResidentAcceptedDecodeTPS` | model/runtime resident; JIT/specialization and prefix policy declared | standardized cool entry | first target decode dispatch → final target-verified accepted/terminal token |
| `turnShapedEndToEndGoodput` | every residency/cache class declared | full observed trajectory | admitted input → exact final release/effect terminal state |

Any public performance statement names:

```text
device/SKU + OS/runtime build + bundle/profile digest
prompt/context/output buckets + sampling policy
process/model/cache/thermal state
metric definition, timer boundaries and percentile
power/accessory/ambient conditions
cool-down or inter-turn interval and background-load policy
device count, run count, failures and exclusions
```

The user-facing “cold 40” target is defined here specifically as **thermally-cold, resident, accepted decode 40**, not process-cold or end-to-end performance. To claim it:

- at least two physical devices;
- at least 100 defined workload turns per certified cohort;
- each measured turn begins at ambient `22 ± 2 °C`, Low Power Mode off, declared battery/external-power and screen/radio conditions, no competing heavy app, and public thermal state continuously `nominal` for at least 300 seconds; external active cooling is forbidden unless named in the claim;
- the model/runtime is already resident; JIT/AOT/specialization state is declared; each turn performs the protocol’s specified full prefill, with prefix/suffix restore disabled unless the claim explicitly names that cache class;
- decode timing starts at the first target decode dispatch after prefill and ends at the final target-verified accepted/terminal token; prefill, TTFT, L10 verification, and end-to-end goodput are reported separately rather than hidden;
- prompt/context/output buckets, natural termination handling, sampling/RNG contract, fixed inter-turn interval, and all exclusions are pre-registered;
- `thermallyColdResidentAcceptedDecodeTPS p10 ≥ 40 tok/s` on each device;
- identity, memory, error, and thermal gates all pass.

To claim **sustained 30 tok/s**:

- the two-device 1800-second continuous-arrival protocol passes with no inserted cool-down gaps;
- arrival pattern, prompt/prefill mix, output buckets, model/cache state, power/ambient conditions, and decode timer are fixed and reported;
- `last-quarter accepted decode p10 ≥ 30 tok/s` on each device, with separate `turnShapedEndToEndGoodput` and TTFT results;
- no positive memory slope or hidden quality/length/coverage reduction.

Until then, “40” remains a workload-qualified thermally-cool resident-decode stretch target and “30+” may only describe the exact measured short-run condition. Neither number implies process-cold TTFT or end-to-end turn goodput.

The certification harness/protocol is implementation-complete when it deterministically emits an evidence-backed `promote` **or** `deny` verdict. Product-default cutover and a public 40/30 claim require `promote`; architecture/runtime completion does not falsify or bypass physics by requiring a known-failing benchmark to pass.

## 34. Eight Adversarial Verification Loops

Three independent domain reviews attacked semantic/state boundaries, performance/thermal/memory behavior, and sovereign/future-device behavior. A fourth independent lock review then attacked the integrated specification and forced two more correction rounds. The Qinao Provider/workspace/memory/RSI convergence reopened all eight loops rather than assuming the earlier pass transferred; they close only under the stronger invariants below.

| Loop | Failure found | Revision locked | Design result |
|---|---|---|---|
| **1. Cardinality/counting** | 14 could be misread as 10 cores + 4 loops; Silicon was called another plane | four independent axes; exact seven-plane list; Silicon Capability Fabric is cross-plane only | PASS |
| **2. Authority/purity** | L14 appeared both pure and stateful; an SDK-owned model or fluent Provider proposal could become hidden authority | L14 core emits decisions and K4 signs; Qinao owns identity/adoption/release/commit while value-only external Providers return untrusted proposals/claims | PASS |
| **3. Artifact/capability isolation** | workspace-private state/cache could cross windows; late attempts could spend old authority; unknown result/new-state digests were pre-bound | `ContextWorkspaceRef` + snapshot + Attempt generation on all artifacts/capabilities, active-attempt CAS fence, visibility-scoped caches, StatePrepare before exact result | PASS |
| **4. Crash/effect saga** | Provider/response/effect retry could duplicate visible bytes or external action after a lost receipt | automatic retry requires eight proven preconditions; no retry after visibility; publication/effect query/reconcile only after boundary; independent branch join preserves indeterminate truth | PASS |
| **5. StateABI/fallback** | attention-only KV reasoning ignored Qwen GDN state; MTP scratch could corrupt target truth; Provider state could become unknown | complete hybrid/RNG/grammar/pending-token checkpoint, target/scratch split, exact ABI/converter or canonical re-prefill, unknown state invalidated, hysteretic MTP fallback | PASS |
| **6. Thermal/full-blood** | serious/critical collapsed; fallback edge looked like resource admission; headline tok/s ignored energy/thermal/rebuild cost | explicit states, one MemoryLedger/heavy phase, re-admission on every edge, uncertainty-aware Pareto/hysteresis, exact 40/30 protocols | PASS |
| **7. Replay/release/concurrency** | multiple windows implied multiple runtimes; task patch rebase and RSI could loop/re-enter; retrieval projections could fracture | logical active/warm/cold windows, fair single heavy phase, serializable patch proof, one snapshot watermark, progress-witness/cross-ring DAG, one result owner | PASS |
| **8. Security/memory/evolution** | in-process Provider looked sandboxed; calendar memories duplicated truth; erasure conflicted with append-only audit; self-repair could become self-modification | trust classes, EventLog+bitemporal manifests, erasure key destruction/blinded tombstone/deletion epoch, future-epoch shadow evolution, quarantine-first device profiles | PASS |

These are abstract architecture results. The same loops remain `REVISE` against current implementation until the corresponding code and physical-device tests exist.

## 35. Current Code: Reuse, Extend, Adapt, Missing

Section 4.4 is the implementation authority for this classification. The architecture is not permission to create a parallel namespace that mirrors the current system.

### 35.1 Reuse unchanged or through existing public extension points

- stable `BASCognitiveLayer` identity and explicit motherboard compatibility mappings;
- `BASLayerActor`, layer reference/cascade/mesh machinery, budgets and kill-switch foundations;
- `BASLowEntropyPrimitives` and `BASSovereignCanonicalBytes`/Rust parity;
- MLX/Metal production mechanisms **inside an external Provider package**, `BASExecutionPlan`, decode policy/planner, acceptance, rollback, sessions, pressure primitives, and upstream wired-memory manager;
- `BASEventLogEntry/Storage`, the one Swift SQLite WAL/integrity/replay owner, `BASMemoryAtom`, current FTS/vector/temporal/entity indexes, existing pure Rust RRF, and current replay harnesses;
- `BASContextCompiler` and current renderers/compilers as the one packing chain;
- current model manifest, invocation contract, device/thermal probes, and Core AI shadow evidence;
- current candidate/render/risk/provider-release types;
- sovereign token, Keychain Ed25519, audit-ledger, tool invocation/result/dispatcher foundations;
- `QinaoRuntime.execute` as the current real tool side-effect gate to strengthen and place behind the Effect Broker, plus the current turn engine, stage executors/ledger, coordinator, public result, device harnesses, lifecycle bridge, and telemetry collectors.

### 35.2 Extend the existing owner

- add stable K1–K4/ring/seven-plane projections without duplicating L1–L14;
- add LayerCell membranes around the actor mesh without a new actor scheduler;
- add canonical attenuated CapabilityGrant semantics while extending the one sovereign mint/consume authority;
- add exact snapshot-bound eligibility/conflict/State Market projections without another retrieval or ranking truth;
- add tokenize-once spans, exact allocation, and descriptor binding to `BASContextCompiler`;
- add canonical quality/StateABI/execution binding to the existing manifest/invocation/plan chain;
- add `ContextWorkspaceRef`, task-DAG roots/patches, `AttemptRef` generation fencing, read snapshots, fair heavy-phase admission, and active/warm/cold residency to the existing turn/session/task owners;
- add value-only Provider/Proposal contracts, trust classes, observed receipts, and Provider state leases by extending existing Qinao proposal/release/seat/runtime gates;
- add bitemporal EventLog projections, calendar manifests, linguistic annotations, deletion epoch/erasure closure, and deterministic State Market/grounding validation to the current state owners;
- add durable spool/finalization to the existing candidate/render/risk/release chain;
- add algorithm agility and durable K4 lifecycle while explicitly migrating current fingerprint/token schemas;
- add v2 semantic topology and receipts while freezing the current stage topology as a compatibility projection;
- add complete artifact-indexed replay/certification around the existing event/result/device evidence.

### 35.3 Thin adapters only

- motherboard aliases, legacy raw-value/wire decoding, and source-compatible result projections;
- existing retrieval engines into snapshot-bound semantic lanes;
- existing actor mesh into LayerCell ingress/egress;
- MLX/Core AI/Core ML/Metal mechanisms into the single silicon execution authority;
- Qwen/MLX, Core AI, Core ML, and Foundation Models implementations into external host-selected Provider packages behind the same value-only gateway;
- current Ed25519/Keychain implementation into the algorithm-agile signer boundary;
- current tool dispatcher behind the Effect Broker;
- Enhanced Security transport, app composition, shadow comparators, legacy stage-to-node mapping, and manifest indexes.

Adapters cannot mint authority, select a competing result, maintain a second ledger/cache, independently retry an effect, or become an alternate production entry point.

### 35.4 New owners permitted only for missing invariants

- Artifact Mesh identity/CAS/ordinary attestation store;
- immutable semantic snapshot barrier and typed state-requirement planner;
- complete cross-backend StateABI/execution binding and application-level process MemoryLedger;
- durable response spool and publication journal;
- algorithm-agile trust manifest, durable Enhanced Security K4 lifecycle, and optional P-256 hardware root;
- Zone-C effect saga plus sealed state prepare/stage/activate protocol;
- canonical semantic DAG contract, pre-publication replay manifest, and aggregate certification/attestation gate.

Every other proposed production `Create` is presumed to be an extension or adapter until its Section 4.4 create proof is approved.

### 35.5 Relocate and freeze

Required relocation:

- move the `QinaoMLX` product/target and every concrete Qwen/MLX/Core AI/Foundation Models implementation out of `QinaoRuntimeSDK`; Provider packages depend inward on Qinao contracts, while Qinao SDK has no dependency back to them;
- keep Provider-private model/state bytes behind the leased physical-state boundary; only Qinao logical identities, plans, checkpoints, and observed receipts cross back.

Paths frozen as compatibility/test-only until retirement:

- raw-string `QinaoOrganEndpoint` as a production semantic boundary;
- automatic model-proposal adoption or presence/shape-only commit checks;
- direct `BASToolDispatcher` production invocation that bypasses the durable Effect Broker;
- dormant opaque `StateGraphBus`-style transport as an alternate state/authority mesh;
- any model default embedded in SDK code or any entry point that bypasses the one execution binding/attempt fence.

The converged implementation has no duplicate event log, SQL owner/WAL, retrieval index, RRF ranker, context compiler, task/attempt scheduler, model registry, MemoryLedger, heavy-seat arbiter, commit gate, publication journal, effect reducer, or retry truth. Swift owns host orchestration and Apple lifecycle; SQL owns indexed durable projections under one connection owner; Rust owns existing pure deterministic fusion/canonical hot logic behind narrow C ABI; Metal/MLX and unavoidable C/C++ runtime code stay inside Provider/upstream execution seams.

## 36. Dependency Seams for Later Planning

This section defines architectural seams, not an implementation plan. A later implementation plan must preserve these dependency constraints:

- an inventory/owner/public-primitive proof must precede every production `Create`;
- typed identity/canonicalization must precede signatures and cross-process persistence;
- model-neutral SDK/package inversion and value-only Provider contracts must precede adding or promoting another model runtime;
- workspace generation, snapshot, task-DAG, and Attempt fencing must precede concurrent independent windows or automatic retry;
- one execution authority and MemoryLedger must precede adding another production backend;
- StateABI must precede any cross-backend resident-state handoff;
- target checkpoint/speculation-scratch separation must precede native MTP production enablement;
- durable prepare/outbox and ledger semantics must precede external-effect migration;
- SemanticStateLake snapshot/eligibility/conflict contracts must precede widening retrieval lanes;
- deletion epochs/erasure closure must precede retaining derived day/week/month, vector, linguistic, or Provider caches;
- every workspace-owned package/app/extension declaration, Rust/XCFramework build environment, regenerated project, and emitted Mach-O minimum must reach and be mechanically verified at iOS 27 before the Enhanced Security boundary is a product invariant;
- observation-only profile collection must precede promotion automation;
- Core AI and future-device work remains shadow-only until certification closes.

Compatibility adapters may bridge existing paths, but only one path may own the authoritative result or effect for a turn. Plans must name the current owner they modify, the exact adapter boundary, and the old path's freeze or retirement gate; a semantically parallel type with a different name is still a duplicate.

## 37. Acceptance Matrix

| Area | Required verification |
|---|---|
| reuse/authority | every production `Create` has an R/E/A/M proof; semantic duplicate scan; one-owner mutation tests; adapters contain no independent decision/storage/retry/effect path |
| counts/naming | compile/schema test finds exactly L1–L14, K1–K4, four ring IDs, seven plane IDs; aliases round-trip to stable IDs |
| SDK/provider boundary | dependency graph forbids concrete model runtimes inside Qinao SDK; request has no handles/credentials; hostile proposal mutation corpus; `ProviderExecutionRef` duplicate-sequence replay and same-sequence/different-digest rejection; in-process trust disclaimer; remote L11/L14 egress gates |
| workspace/task/attempt | workspace-vs-window generation/ABA races; EventLog+graph-head+activeAttempt one-transaction failure injection; transitive descendant grant fencing; late-result rejection; serializable task-patch rebase; DAG/budget/authority invariants; active/warm/cold rebuild equivalence |
| LayerCell purity | dependency/lint tests reject direct I/O/private mechanism calls from pure cores; deterministic fixture replay |
| artifact canonicalization | cross-process/platform vectors; parent/schema/epoch tamper rejection; privacy commitment non-linkability tests |
| capability attenuation | mutate each audience/operation/resource/projection/purpose/turn/epoch/digest/budget field; every mismatch denies |
| kill/revoke | queue, start, dispatch, and seal epoch races; stale work cannot commit; physical-root recovery tested |
| SemanticStateLake snapshot | lane delay/crash/restart, partial joins, conflict preservation, late result next epoch, deterministic projector replay |
| memory projections/privacy | one `BitemporalInterval`; direct EventLog/lossless-checkpoint rebuild; timezone/tzdb/DST/week-rule changes; current/day/week/month provenance; crash at every erasure rank; quarantine-first generation revoke; key-absence recovery; owner-rescan/indeterminate; no old-snapshot release or resurrection |
| linguistic IR | canonical UTF-8 byte spans and normalization identity; tokenizer-view drift; annotator/config/epistemic/deletion provenance; required/optional/unsupported strata; UD/UMR/dialogue-act adapter round trips; no ontology-owned authority |
| retrieval/grounding | one SQLite WAL owner; compiled pre-query predicate equals L7 authority; forbidden partition never reaches ANN/RRF; lexical/vector/temporal/entity labels survive fusion; required/optional grounding failure; proposal epistemic status; bounded same-owner final recomputation |
| State Market | hard-ineligible high-score items never enter; diversity/budget/conflict invariants; selection reasons replay |
| context compiler | tokenization once; projection order and budget identity; cache collision and policy-epoch invalidation |
| backend plan | every entry point consumes one exact plan; no discarded authoritative result; no second trunk |
| StateABI | field-by-field mismatch including GDN/RNG/grammar/pending-token state, corrupt/unknown Provider state, converter failure, mid-decode revoke; target/scratch isolation; canonical re-prefill identity |
| memory | resident/transient reservation, warning/jetsam simulation, cache eviction, eight-logical-window/one-local-heavy stress, no reservation leaks |
| thermal/power | Low Power and each thermal state, unknown enum, transition race, critical checkpoint and resume |
| MTP/prompt lookup | acceptance collapse, head mismatch, termination mismatch, state rollback, hysteretic re-probe |
| RSI/control rings | concurrent branch BudgetLease CAS/double-spend; repeated digest; false textual progress; invocation-DAG remand depth; stale grant/epoch; resource pre-emption; post-effect reconciliation-only behavior |
| K4 ledger | crash before/after commit/reply/spend, replay, duplicate request, corruption, rollback, schema upgrade, key rotation |
| Effect Broker | crash at every state transition for all five adapter classes; `EffectBoundaryPermit` duplicate consumption; K3 Attempt-fence-versus-permit-issue CAS race; duplicate delivery; partial/cancel/unknown/reconcile/compensate |
| response/recovery join | provisional arm-before-first-sink crash; chunk generation race; exact sink-boundary arm crash; exact-spool mismatch; branch-quiescence retry proof; restoration-root mutation; lost publication receipt query/finalize or indeterminate; response/effect branch truth preserved |
| future profile | unknown device quarantine, OS/runtime/profile invalidation, specialization-cache loss, evidence promotion/demotion |
| performance | two-device cold/warm/1800-second protocols, accepted goodput, energy, memory slope, thermal and failure disclosure |

## 38. Non-Promises and Hard Boundaries

The architecture explicitly refuses these claims:

- “A19 Pro has Neural Accelerators, therefore this operation ran there.”
- “The app obtained a lease, therefore the OS reserved silicon.”
- “The model name and parameter count match, therefore state/backends are equivalent.”
- “The signature helper approved a digest, therefore host semantic reasoning is uncompromised.”
- “The external call returned no receipt, therefore it did not happen.”
- “The current Ed25519 key is a Secure Enclave key.”
- “Shared memory means zero-copy, synchronization-free, or contention-free.”
- “A cache hit is certification evidence.”
- “An in-process Provider package is a malicious-code sandbox.”
- “A model proposal, grounding score, or fluent citation can establish authority or commit state.”
- “Independent context windows imply independent resident 4B runtimes.”
- “An idempotency key permits automatic redispatch after an ambiguous publication/effect boundary.”
- “All hardware units at 100% is the healthiest or fastest execution.”
- “51 existing unit tests or an abstract model prove the future system is production-ready.”
- “Current iPhone Air is a sustained 30 or 40 tok/s product.”

## 39. Locked Decisions and Remaining Empirical Questions

### Locked by this design

- counting, naming, plane, layer, kernel, ring, and fabric boundaries;
- LayerCell purity and Dual Mesh interaction;
- Qinao SDK model neutrality, external value-only Provider/Proposal boundary, and host-owned signed model selection;
- workspace/task/Attempt identity, logical multi-window residency, one local heavy phase, and generation fencing;
- L7/L8/L9/L10/L11/L13/L14 authority split;
- one process-wide local heavy owner and one authoritative acceptance generation/result per Attempt;
- QualityIdentity, NeuralExecutionContractDigest, and new-model lineage rule;
- StateABI handoff/re-prefill rule;
- target-checkpoint/speculation-scratch separation and Qwen hybrid-state completeness;
- EventLog source truth, bitemporal horizon projections, sparse linguistic graph, one SQLite owner, and erasure/deletion-epoch closure;
- RSI as a bounded cross-ring protocol with progress witnesses rather than another manager/layer/ring;
- durable authorization/effect saga and indeterminate semantics;
- signer custody truth and algorithm agility;
- quarantine-first future-device policy;
- evidence grades and performance-claim protocol.

### Empirical questions intentionally left to implementation and device research

- which A19 shapes actually use NAX under a supportable evidence mechanism;
- the best fused Qwen3.5-4B token loop and memory layout in the pinned MLX/runtime version;
- prompt classes where lookup or MTP produces stable accepted-token gains;
- whether the exact included Qwen native-MTP bundle produces stable net benefit on A19 Pro; any deeper/retrained MTP, ReDrafter, or 2-bit variant is a separately certified lineage;
- whether EpiCache-like eviction or learned KV/state eviction can preserve exact hybrid GDN/attention continuation StateABI and quality;
- whether Core AI can represent the exact trunk and StateABI with net end-to-end benefit across iOS cohorts;
- which future devices/OS builds earn a production profile;
- whether a workload-qualified cold 40 and sustained 30 certification can actually be achieved.

These questions can change backend profiles and performance claims. They cannot change the locked semantic architecture without a new reviewed design decision.

## 40. Source Grounding

### Apple public platform sources

- [iPhone Air Technical Specifications](https://www.apple.com/iphone-air/specs/)
- [Introducing iPhone Air](https://www.apple.com/newsroom/2025/09/introducing-iphone-air-a-powerful-new-iphone-with-a-breakthrough-design/)
- [Metal capabilities](https://developer.apple.com/metal/capabilities/)
- [A19 and M5 TensorOps tech talk](https://developer.apple.com/videos/play/tech-talks/111432/)
- [Core AI](https://developer.apple.com/core-ai/)
- [Core AI InferenceFunction](https://developer.apple.com/documentation/coreai/inferencefunction)
- [Managing Core AI model specialization and caching](https://developer.apple.com/documentation/coreai/managing-model-specialization-and-caching)
- [Compiling Core AI models ahead of time](https://developer.apple.com/documentation/coreai/compiling-core-ai-models-ahead-of-time)
- [Core ML compute units](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- [Core ML MLState](https://developer.apple.com/documentation/coreml/mlstate)
- [Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency)
- [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)
- [OSSignposter](https://developer.apple.com/documentation/os/ossignposter)
- [MetricKit](https://developer.apple.com/documentation/metrickit)
- [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo)
- [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Scheduling CPU work efficiently](https://developer.apple.com/documentation/xcode/scheduling-cpu-work-efficiently)
- [Creating Enhanced Security helper extensions](https://developer.apple.com/documentation/xcode/creating-enhanced-security-helper-extensions)
- [AppExtensionPoint.Definition and EnhancedSecurity](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/definition)
- [Enabling enhanced security for your app](https://developer.apple.com/documentation/xcode/enabling-enhanced-security-for-your-app)
- [SecureEnclave P-256 Signing](https://developer.apple.com/documentation/cryptokit/secureenclave/p256/signing)
- [Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave)

### Apple research directions used only as research inputs

- [Apple Foundation Models 2025 updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [ReDrafter: Recurrent Drafting for Fast Speculative Decoding](https://machinelearning.apple.com/research/recurrent-drafter)
- [EpiCache](https://machinelearning.apple.com/research/epicache)
- [QuantSpec](https://machinelearning.apple.com/research/quantspec)
- [Learning to Evict from a Large Language Model's Key-Value Cache](https://machinelearning.apple.com/research/evict)

These research results motivate certifiable experiments; they do not prove this repository’s model, device, workload, or thermal envelope.

### Model, context, retrieval, memory, and agent-system sources

- [Qwen3.5-4B official model card](https://huggingface.co/Qwen/Qwen3.5-4B) — hybrid Gated DeltaNet/attention layout, trained multi-step MTP, and native context facts used by the StateABI/MTP design.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [SQLite FTS5](https://www.sqlite.org/fts5.html)
- [Reciprocal Rank Fusion](https://cormack.uwaterloo.ca/cormacksigir09-rrf.pdf)
- [Universal Dependencies](https://universaldependencies.org/)
- [Uniform Meaning Representation](https://umr4nlp.github.io/web/)
- [ISO 24617-2 dialogue acts](https://www.iso.org/standard/76443.html)
- [MemGPT](https://arxiv.org/abs/2310.08560)
- [SGLang](https://arxiv.org/abs/2312.07104)
- [ReAct](https://arxiv.org/abs/2210.03629)
- [Tree of Thoughts](https://proceedings.neurips.cc/paper_files/paper/2023/hash/271db9922b8d1f4dd7aaef84ed5ac703-Abstract.html)
- [Language Agent Tree Search](https://arxiv.org/abs/2310.04406)
- [Reflexion](https://arxiv.org/abs/2303.11366)
- [A-MEM](https://arxiv.org/abs/2502.12110)
- [Graphiti](https://arxiv.org/abs/2501.13956)

These sources inform bounded context/memory/search/proposal mechanisms. They do not transfer model authority to an agent loop or justify unbounded self-revision; Qinao retains deterministic authority, budgets, and commit/recovery gates.

### Repository evidence reviewed

The design was grounded against, among others:

- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardLayerMapping.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardArchitecture.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlanElector.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASDecodePlanner.swift`
- `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter.swift`
- `BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/WiredMemory.swift`
- `BehavioralAISubstrate/Vendor/mlx-swift/Source/MLX/Memory.swift`
- `BehavioralAISubstrate/Sources/BASHostKit/BASNativeStageExecutor.swift`
- `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- `BehavioralAISubstrate/Sources/BASAppleAdapters/BASStateLakeReader.swift`
- `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift`
- `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignKeychainBinding.swift`
- `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- `BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`
- `BehavioralAISubstrate/Sources/BASMemory/BASMemoryAtomStore.swift`
- `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASAutoRouteRanker+RankFuse.swift`
- `BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/fuser.rs`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnRequest.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASLLMPromptCache.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASToolDispatcher.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSystemProbe.swift`
- `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift`
- `BehavioralAISubstrate/Sources/BASMLXAdapter/BASSessionKVStore.swift`
- `BehavioralAISubstrate/Sources/BASMLXAdapter/MLXOrganAdapter+SessionPersist.swift`
- `BehavioralAISubstrate/Sources/BASMLXAdapter/BASTrunkCheckpoint.swift`
- `BehavioralAISubstrate/Sources/BASMLXAdapter/BASQwen35MTPSpecDecoder+FusedChain.swift`
- `QinaoRuntimeSDK/Package.swift`
- `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpoint.swift`
- `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`
- `QinaoRuntimeSDK/Sources/QinaoSeats/QinaoAgentProposal.swift`
- `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
- `QinaoRuntimeSDK/Sources/QinaoMLX/QinaoMLXEndpoint.swift`
- `BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/lib.rs`
- `BehavioralAISubstrate/scripts/build-rust-xcframework.sh`
- `BehavioralAISubstrate/Docs/THROUGHPUT_CAMPAIGN_2026-06.md`
- `BehavioralAISubstrate/Docs/SYSTEM_EFFICIENCY_CAMPAIGN_2026-07.md`
- `BehavioralAISubstrate/Docs/FRONTIER_2026H2_EVOLUTION.md`
- `BehavioralAISubstrate/Docs/COREML_COREAI_DECISION.md`
- `BehavioralAISubstrate/Docs/ONDEVICE_DUET_ARCHITECTURE.md`

## 41. Final Architecture Statement

The target is not a fourteen-stage monolith and not “10 cores + 4 loops.” It has exactly fourteen semantic LayerCores, while four Physical Kernels, four bounded ControlRings, and seven orthogonal planes cooperate across them through typed artifacts, attenuated capabilities, snapshots, leases, and receipts. Boundaries stay crisp because authority never moves; cooperation stays deep because every dependency and recovery edge is explicit.

Qinao is the model-neutral deterministic application substrate. The host selects a signed model profile—currently Qwen3.5-4B by default—and an external Provider leases physical execution. A model may propose; it cannot read arbitrary Qinao state, route itself, call tools, publish, commit, or change authoritative memory. One Attempt, workspace snapshot, execution binding, target checkpoint, heavy-phase admission, output/effect branch identity, and commit/recovery truth span the complete chain:

```text
Input Event → Normalizer → Intent/Risk → State Requirement
→ SQL/Exact/FTS/Dense/Temporal/Entity retrieval
→ Hard Eligibility → deterministic State Market
→ Grounding/Conflict → Context Budget/Compiler
→ Prefill Router → Decode Router/target verification
→ Output Verifier → Response and/or Tool Runtime
→ Publication/Effect reconciliation → State Commit Gate
→ EventLog append → rebuildable StateLake projections
```

Logical workspaces/windows remain independent through generation-fenced task graphs, snapshots, context and memory projections; the phone remains healthy through one fair local heavy phase, cache/refcount discipline, exact Qwen hybrid StateABI, bounded RSI progress, robust Pareto selection, and deterministic fallback. Current/day/week/month memory is structured life-like projection over one bitemporal event truth, not duplicated stores.

For current iPhone Air, the elegant path is to relocate the existing MLX trunk behind the Provider boundary and make the existing plan, context, SQL/event, retrieval, memory, thermal, checkpoint, verification, publication, and effect owners converge before adding concurrent backends. For future Apple Silicon, the same architecture accepts stronger capabilities through certified profiles without renaming truth, weakening full-blood quality, or adding hidden authority. The healthy target is verified task goodput under energy/memory/thermal constraints; `40 tok/s` cold-resident p10 and sustained `30 tok/s` remain unproven certification targets, not promises.

## 42. Design Validation Record

Before this design was locked:

- three independent reuse audits compared every proposed production `Create`, cross-plan public contract, and Apple/upstream mechanism against current repository owners. They found no exact-name collision but identified semantic duplicates that would otherwise create parallel digest, grant, event, release, lease, and recovery truth; Section 4.4 and the R/E/A/M owner map close those gaps before planning;
- three independent domain red teams reviewed semantic/state correctness, performance/thermal/memory behavior, and security/future-device behavior; a fourth independent lock reviewer found nine integration blockers over two rounds, all of which were corrected before its final `PASS`;
- the eight adversarial loops in Section 34 were revised to a design-level pass;
- the final broad abstract model executed 832 assertions and the post-lock-review focused model executed another 264 assertions: 1,096 final-design assertions covering capability mutation, branch/release ordering, effect crashes and cross-domain gaps, StateABI, memory admission, bounded remand, exact generation identity, keyed artifact identity, and the thermally-cold 40 entry protocol;
- after the workspace/Attempt, Provider, RSI, retrieval/grounding, erasure, output, and effect boundaries converged, a fresh exhaustive abstract model executed another 47,347 assertions over recovery, restoration, TaskGraph transactions, budget CAS, cache scope, Provider adoption CAS, publication/effect boundary permits, erasure, eligibility, MTP rollback, RSI termination, and response/effect joins; every assertion passed, but this remains a design-model proof rather than implementation certification;
- the completion replay independently executed 133,006 assertions over the same final invariants with broader TaskGraph closure enumeration. Its first run was rejected because the test oracle conflated a second permit-consumption **attempt** with a successful second consumption; the oracle was corrected to model attempted and accepted consumption separately, then the complete model was rerun from zero and passed;
- the first abstract-model run exposed a bug in its own string-based oracle; that oracle was corrected to an enum-equivalence check before any pass was accepted;
- the existing `BASExecutionPlanElectorTests`, `BASNativeStageExecutorTests`, `BASSovereignTokenAuthorityTests`, and `BASThermalTwinTests` were run three consecutive times: `153/153` test executions passed with zero failures;
- three independent final spec-only reviews re-ran the authority/recovery, context-memory-RSI, and execution/performance boundary matrices; all returned `PASS` with no remaining P0/P1 finding;
- final static structure validation found exactly 14 authoritative layer rows, 4 kernel rows, 4 ring rows, and 7 plane rows; 82 fence markers formed 41 balanced code blocks and all 44 referenced local evidence paths were present;
- `git diff --check` and Markdown structural validation passed for the design artifact.

The existing Swift tests validate retained foundations only. They do not test or certify the not-yet-implemented Artifact Mesh, Capability Mesh, durable K4 ledger, Effect Broker, StateABI graph, SemanticStateLake, unified MemoryLedger, future backend profiles, or 40/30 performance gates.
