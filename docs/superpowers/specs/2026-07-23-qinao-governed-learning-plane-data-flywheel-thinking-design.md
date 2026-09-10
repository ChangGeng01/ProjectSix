# Qinao Governed Learning Plane, Data Flywheel, and Thinking Construction Design

> **Forward development status (2026-08-29):** Superseded by [Qinao single-developer Git and lightweight PR design](2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md). External authority closure was never completed, and no historical authority is retroactively claimed. The single developer selected ordinary Git plus lightweight PR review; former source-admission, controlled-document, signer/trust-root, controller/CAS, authority-receipt, registry, and quorum gates are retired for forward development. Historical facts and hashes remain evidence; a historical non-authority limitation remains a forward gate only when the superseding design explicitly restates it.

**Date:** 2026-07-23

**Status:** Product and architecture decisions approved section by section. This written revision remains under adversarial review. Controlled-document convergence, implementation, migration, device measurement, certification, and production cutover remain `REVISE`.

**Scope:** Evidence-native learning, closed-loop improvement, data curation, reward and causal credit, bounded on-device adaptation, offline model training, observable thinking construction, memory assimilation, multi-agent RSI, recovery, security, evaluation, rollback, and Apple-silicon execution for Qinao on iOS 27 and later.

**Repository snapshot:** `codex/qinao-w1` at `9ba6bf56498c8c0a995d3e75ff0b5f4d57c26224`. The hash records the documentation base before this file. The worktree contains unrelated in-flight W0/W1 changes and is neither implementation truth nor certification evidence.

## 0. Normative Standing

This document specializes, but does not replace:

1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`;
2. `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`;
3. `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`;
4. `docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md`;
5. the 2026-07-15 convergence master and its Contracts, Silicon, Runtime, Semantic, and Sovereign domain plans;
6. `docs/superpowers/specs/qinao-owner-ledger-v1.json`.

It is a design record, not an eighth controlled authority document. Before implementation, every adopted wire, lifecycle, invariant, and code disposition in this design must be atomically reconciled into the existing controlled document set and Owner Ledger. A sentence here cannot create a production owner, schema, store, manager, compiler, scheduler, certification mouth, promotion mouth, or writer.

The architecture cardinalities remain exact:

- fourteen Semantic LayerCores, L1-L14;
- four Physical Kernels, K1-K4;
- four bounded ControlRings: Omega Resource, Omega Grounding, Omega Deliberation, and Omega Effect/Evolution;
- seven orthogonal planes in the canonical architecture.

The current Owner Ledger cardinalities also remain exact: `owners = 29`, `create_allowlist = 14`, `create_permissions = 14`, and `controlled_documents = 7`. This design changes none of those counts by prose.

`Learning Plane` is a convenient name for the cross-cutting protocol view defined here. It is not another counted LayerCore, Physical Kernel, ControlRing, runtime singleton, authority plane, or Swift type. If controlled convergence cannot map a proposed responsibility to an existing honest owner, that capability stays disabled.

The minimum deployment target remains iOS 27 for every selected app, package, extension, generated binary, XCFramework slice, and release-closure Mach-O. OS availability is not capability proof: every model path, profile, converter, custom operation, extension entitlement, and performance tier still requires exact evidence from the selected device and OS cohort.

### 0.1 Requirement language

`MUST`, `MUST NOT`, `SHOULD`, and `MAY` are normative. A design-candidate label describes semantics only until controlled convergence assigns its exact owner, reuse/create classification, schema, fixture, recovery behavior, and non-vacuous gate.

### 0.2 Existing owners remain sole owners

| Responsibility | Sole existing or approved target owner | Learning-plane posture |
|---|---|---|
| Runtime resource envelope, heavy-phase ownership, thermal and memory pressure | K1 | Read constraints; never override them |
| Model inference, declared shadow execution, compiled specialization | K2 | Execute only admitted profiles; no production authority |
| Durable event truth, approved runtime-state/semantic lifecycle references, source head, idempotency, expected-parent CAS | K3 | Sole writer for only those mapped rows; never Policy-A/model production head or current Release |
| Protected exact grant, reserve, claim/use, attestation | K4 | Authorize exact use; never decide semantic quality |
| Immutable artifact bytes, identity, lineage, ordinary storage | Artifact Mesh | Store evidence and manifests; never promote them |
| State retrieval and memory projections | Incumbent L8 plus approved-planned StateLake owners, unavailable before their owning wave/gates | Produce grounded projections; never become source truth |
| Context compilation | Canonical `BASContextCompiler` target | Compile one bounded context; no second “State Compiler” |
| Verification and credit evidence | L10 and mapped verifier owners | Evaluate; never activate a candidate |
| Privacy, disclosure, export eligibility | L11 and mapped privacy owners | Decide disclosure eligibility; K4 only enforces exact grant |
| Candidate preparation/read-set | L13 | Prepare immutable candidates; never approve itself |
| Sovereign admission, revocation, seal | L14 | Admit/revoke exact action; not a global product manager |
| Evaluation/certification | Approved-planned W6 `runtime.certification` | Sole E0-E5 certification owner once created/gated; unavailable before then |
| Canary/full adoption and rollback boundary | Converging W6 `production.cutover` | Sole production deployment/cutover mouth; not a runtime service |
| Weight optimization mechanism | No Qinao authority; isolated external trainer mechanism under exact input/output grants | Returns an untrusted candidate only |

### 0.3 Model and SDK boundary

Qinao remains model-independent. Qwen3.5-4B is the target local Main Provider default only after its exact Provider/profile tree passes W6 certification and full cutover; at this snapshot the public Qinao MLX facade still exposes/defaults Gemma variants and no production Qwen caller is proven. AFM and future local or API Providers are peers behind constrained Provider/Proposal contracts. A Provider may propose text, plans, tool arguments, judgments, features, or candidate work products. It cannot directly change authoritative state, permissions, memory, Self, policy, release status, effects, or the learning curriculum.

The deterministic SDK owns protocols, validation, state, evidence, audit, recovery, certification routing, and host integration. An API model may be more capable than a local model, but it receives no broader authority merely because its intelligence, context window, or price differs.

### 0.4 Repository reality and design vocabulary

This document distinguishes three classes of names:

| Standing | Examples | Meaning |
|---|---|---|
| Repository-existing mechanism | `BASDistillationBank`, `BASUpdateTicketLifecycleCoordinator`, `BASShadowTrialCoordinator`, `BASABProtocolSpec`, `BASCoreAIShadowComparison`, current character-budget `BASContextCompiler.compile`, `QinaoLearningExporter`, `QinaoMemory.LearningExportBundle`, `BASEvolutionLifecycleStage`/`Action`/`Policy`/`Session`, and `MLXLoRATrainer` | May be preserved or reused only with the dispositions in Sections 4.12 and 9.6; existence or current call reachability proves neither completed convergence nor production readiness for a new learning path |
| Approved-planned or converging target | `BASContextCapsule`, the tokenize-once/exact-accounting/progressive-disclosure extensions of incumbent `BASContextCompiler`, K3 Provider contracts, W1 `runtime.semantic-dag`, converging W6 `runtime.semantic-executor`, W5 Zone-C/`BASEffectBroker`, `runtime.certification`, and `production.cutover` | Defined by earlier controlled/specializing plans; only the named missing/converging capability remains unavailable until its owning wave creates or converges it and the exact gates pass |
| New design-candidate semantic label | `ExperienceEnvelope`, `RewardEvidenceVector`, `RewardProjectionManifest`, `VerifierClaimContract`, `DatasetManifest`, `TrainingJobManifest`, `OPEEstimandManifest`, and immutable adaptive-statistics/OPE report shapes | A requirement bundle, not a declaration or authority; controlled convergence must first reuse, extend, adapt, migrate, or honestly create its exact wire under an incumbent owner |

Algorithm and workflow names in this document do not imply Swift type names. No implementation may add a type merely by copying a design-candidate label.

## 1. Executive Decision

Qinao adopts an **evidence-native, dual-speed, three-loop governed learning architecture**.

“Dual-speed” means:

1. a fast path that records typed evidence and may update only tiny, reversible, non-authoritative adaptive sufficient-statistics snapshots through a governed batch process; and
2. a slow path that curates immutable dataset generations, trains model candidates outside the runtime, and returns them through full parity, certification, canary, and rollback governance.

“Three-loop” means three protocol cadences, not three new ControlRings:

1. **runtime strategy loop** — improve finite routing, budgeting, retrieval, reasoning-effort, and predeclared delegation choices;
2. **memory/Self assimilation loop** — turn observations into cleaned, conflicting, provisional, confirmed, or rejected memory and Self candidates;
3. **model release loop** — train, convert, verify, specialize, certify, canary, adopt, or roll back a versioned model candidate.

Every loop shares the same evidence front half, then uses one of three non-interchangeable governed paths:

```text
Observed event or independent outcome
  -> immutable experience envelope
  -> eligibility, cleaning, privacy, lineage, and split gates
  -> typed reward/evidence vector plus attribution/credit status
  -> candidate dataset/Evidence-B/runtime-state/Policy-A/model/code/policy generation
  -> offline replay, counterfactual analysis, and shadow evidence

Authoritative runtime-state target:
  -> L10 verification + L11 revalidation
  -> L13 exact proposal/read-set
  -> K3 invisible stage
  -> L14 exact authorization
  -> complete K4 terminal-seal chain
  -> K3 seal/expected-parent activation

Inert evidence/data/job artifact:
  -> incumbent owner/schema validation and bounded canonicalization
  -> Artifact Mesh ordinary put/reopen of immutable bytes
  -> after the required E/A convergence, K3 retains only mapped semantic
     lifecycle/currentness/reference/deletion-fence facts
  -> every retrieval, evaluation, export, trainer, or protected use is
     separately reauthorized against current purpose/policy/deletion epochs

Non-runtime Policy-A/model/code/policy target:
  -> K3 retains only an inert candidate/evidence reference
  -> runtime.certification E0-E4
  -> production.cutover sealed canary Release/deployment
  -> runtime.certification E5
  -> production.cutover separately sealed full Release

Any path -> monitored independent result -> new source event
```

No output may close the loop by citing itself. No model may generate, judge, certify, and promote the same candidate. Unknown evidence remains unknown; it is never silently coerced to success, zero loss, or neutral reward.

### 1.1 Locked product decisions

The following choices are frozen for this design:

- The complete learning protocol is built into Qinao, but model gradient training is not part of the iPhone runtime.
- iPhone may update only tiny non-generative adaptive sufficient-statistics snapshots with bounded typed features; the finite action set and every decision/exploration/fallback semantic remain in a separately certified build-time policy definition.
- Qinao-owned or fine-tunable Qwen, Main-Agent, Sub-Agent, embedding, verifier, and other local/API-served model candidates undergo weight training or fine-tuning only in isolated external workflows. AFM system weights are never received, owned, trained, fine-tuned, or imported by Qinao; only the versioned AFM context/tool/calibration/profile artifacts in Section 6.9 may be learned.
- Local data is the default. Export requires explicit, current, purpose- and destination-bound user authorization after minimization and cleaning.
- Competence and strategy may create automatic candidates. Stable Self, values, identity commitments, and long-term relationship commitments require independent evidence, shadow/canary where applicable, and explicit user confirmation.
- Observable cognitive work products may be learned from; raw hidden chain of thought, KV state, private scratch, credentials, and unredacted model internals may not be persisted or trained on.
- User utility is optimized under correctness, authority, privacy, safety, and anti-manipulation constraints. Engagement, dependence, time-spent, emotional capture, and compliance are not reward objectives.

### 1.2 Built in versus external

The Qinao SDK MUST supply the following mechanisms only through exact owner mappings produced by controlled convergence and constrained by Section 0.2; the package itself is not an authority owner, and this list does not claim those mappings are already complete:

- experience identity, immutable lineage, causal grouping, and currentness;
- data eligibility, cleaning, purpose limitation, privacy, retention, revocation, deletion, and export protocols;
- reward-evidence and credit-assignment schemas and deterministic reducers;
- dataset-manifest construction, split integrity, contamination detection, and trainer input/output protocols;
- on-device adaptive-statistics update rules, replay, OPE, shadow, certified-policy binding, rollback, and reset;
- memory and stable-Self assimilation gates;
- evaluation suites, hidden holdout isolation, canary policy, and release receipts;
- recovery, audit, causal trace, and fail-closed behavior.

An external trainer MAY perform gradient computation and converter execution. It MUST receive only an exact authorized manifest, MUST have no production authority, and MUST return only staged candidate artifacts and receipts.

### 1.3 Absolute prohibitions

The following remain structurally impossible, not merely discouraged:

- same model-family/root generating the candidate, supplying the only evaluator, and authorizing promotion;
- output text, model confidence, or multi-sample agreement serving as self-corroborating truth;
- direct Provider, App Agent, Main Agent, Sub Agent, trainer, exporter, or UI writes to K3 authority;
- raw chain of thought, private scratch, KV caches, credentials, or unbounded transcripts in a learning dataset;
- one candidate simultaneously defining the behavior policy and its evaluator;
- clicks, dwell time, notification opens, session length, praise, silence, or emotional attachment as direct reward;
- trainer output loaded directly into production;
- an unversioned floating API alias inheriting prior certification;
- an adaptive statistics snapshot expanding or altering its certified feature set, action set, scoring/selection semantics, exploration, fallback, risk ceiling, permissions, or update rule at runtime;
- cross-App-Agent learning or data access by byte copying, shared mutable pools, or inferred consent;
- a “repair” that invents missing source events, guesses an external effect, or self-promotes a replacement.

## 2. Exact 14-Layer, 4-Kernel, and 4-Ring Mapping

### 2.1 Semantic LayerCore responsibilities

| Layer | Learning responsibility | Explicit boundary |
|---|---|---|
| L1 | Observe resource class, foreground/background eligibility, thermal, memory, energy, and maintenance window | Cannot trade safety or authority for throughput |
| L2 | Resolve exact model/profile/action-set/template identities and their certified capability manifests | No floating model identity or undeclared action |
| L3 | Produce context inclusion, omission, compression, and budget decisions through canonical `BASContextCompiler` | No second compiler and no truth creation |
| L4 | Supply grounded world-evidence observations with exact source provenance/freshness | Source-independence eligibility belongs to L7; model output never feeds back as world evidence |
| L5 | Hold user consent, preferences, stable Self, relationship commitments, and companion-expression policy | Expression cannot weaken correctness, safety, or authority |
| L6 | Normalize explicit corrections, comparisons, task outcomes, tool observations, and delayed results | Does not assign promotion or write memory directly |
| L7 | Enforce learning eligibility, source independence, cleaning, split assignment, data-purpose policy, and reward-evidence admission | No mutable training pool and no opaque “safe” Boolean |
| L8 | Build snapshot, memory-candidate, horizon, and retrieval projections | Query results never self-populate governed memory |
| L9 | Build counterfactuals, alternative branches, challenge cases, and ablation plans | Diagnostic proposals only |
| L10 | Verify exact claims, process constraints, causal credit, calibration, regression, and disagreement | Cannot certify or promote alone |
| L11 | Enforce privacy, disclosure, minimization, retention, export, and revocation | No egress through logging, analytics, UI, or trainer side channels |
| L12 | Render approved output and emit forward-only presentation/audit receipts | New user interaction re-enters through Adapter/Input Normalizer to L6; presentation cannot reverse-write truth, memory, reward, or Self |
| L13 | Prepare immutable policy/data/memory/model candidates and exact read-sets/adoption intent | Never activates its own candidate |
| L14 | Authorize or revoke an exact high-consequence adoption/export/effect and seal the decision | Not a general orchestrator, evaluator, or learner |

Layer boundaries are strict; cooperation happens through immutable typed artifacts, exact parentage, currentness receipts, and bounded ports. A shared class, database table, or actor does not merge semantic ownership.

### 2.2 Physical Kernel responsibilities

| Kernel | Learning role | Forbidden role |
|---|---|---|
| K1 | Reserve bounded compute, memory, thermal, energy, background, and I/O envelopes | Quality or promotion decision |
| K2 | Run admitted inference, certified score-projection computation, declared shadow paths, conversion/runtime parity probes, and specialization | Durable lifecycle or release authority |
| K3 | Append immutable events; own only approved dataset/semantic-job/Evidence-B/inert-candidate references, mapped runtime-state currentness, idempotency, deletion fences, expected-parent CAS, and exact recovery rows | Policy-A/model production head/current Release, semantic evaluation, external actuator truth, or permission invention |
| K4 | Issue/reopen/reserve/claim exact protected grants and attestations after semantic owners decide | Decide relevance, correctness, consent, or promotion |

K3 is the only durable writer for the mapped source/runtime-state/semantic lifecycle rows above. Non-runtime Policy-A/model/code/policy adoption remains with certification/cutover, and Zone C owns external actuator truth. SQL projections, vector indexes, caches, experiment dashboards, and training workspaces are rebuildable consumers. None may become a second head or truth source.

### 2.3 ControlRing cooperation

| Ring | Learning-loop duty |
|---|---|
| Omega Resource (`ΩR`) | Admit, defer, cancel, or stop work under K1 and an already-open execution-DAG/foreground-background maintenance window; it creates no schedule |
| Omega Grounding (`ΩG`) | Retrieve, clean, deduplicate, qualify, conflict-check, and bind evidence to source lineage |
| Omega Deliberation (`ΩD`) | Decompose work, build observable cognitive artifacts, allocate Main/Sub branches, test counterexamples, and stop overthinking |
| Omega Effect/Evolution (`ΩE`) | Participate with bounded candidate, outcome, reconciliation, and rollback evidence; it does not run certification/cutover or commit state, and `runtime.certification`, `production.cutover`, L13/L14, K3, K4, and Zone C retain their sole mouths |

The three learning cadences traverse these four existing rings. They MUST NOT be implemented as additional “FastLearningRing”, “MemoryRing”, or “ReleaseRing” schedulers.

### 2.4 Seven-plane projection

The learning protocol is a horizontal projection across the seven canonical planes below. It neither owns a plane nor creates an eighth one.

| Canonical plane | Learning-protocol projection | Explicit boundary |
|---|---|---|
| Semantic Authority | L1-L14 produce and validate typed eligibility, grounding, memory, verification, privacy, candidate, presentation, and authorization semantics | A model, dataset, score, receipt store, or physical kernel cannot acquire semantic authority |
| Kernel Ownership | K1-K4 provide the bounded resource, neural-execution, durable-state, and sovereign-grant mechanisms in Section 2.2 | Mechanism ownership cannot choose truth, policy quality, promotion, or user intent |
| Execution DAG | After its W1 CreateGate, `runtime.semantic-dag` freezes typed topology, dependencies, optional-slot vocabulary, and source order; `runtime.turn-operation` may bind an already authorized proposal to one exact declared slot; K3 alone allocates the winning branch; after W6 convergence/source gates, `runtime.semantic-executor` mechanically consumes the admitted graph through incumbent `BASNativeStageExecutor`/runtime seams | Neither Main/Sub Agents nor Evidence-B may create topology, fill a slot, schedule arbitrary work, reopen a terminal node, or turn the binder/executor into an owner |
| ControlRing | The four existing rings carry bounded admission, grounding, deliberation, effect/evolution, budget-use, progress, and terminal receipts | No fifth loop, general scheduler, mutable iteration manager, or self-certified progress |
| Data Plane | Artifact Mesh holds immutable bytes; K3 holds only its mapped event/lifecycle/currentness/reference facts; SQL, StateLake, vector, cache, and dashboard views remain rebuildable | No mutable training pool, second head, projection-as-truth, or store-driven promotion |
| Adapter/IO | Adapters frame untrusted input and mediate Provider, tool, trainer, UI, and host boundaries through that operation's exact owner-specific protocol; Provider, effect/export, and publication sequences are distinct and never collapse into one generic slash-order | Framing cannot invent consent, eligibility, semantics, authority, retries, or an alternate egress path |
| Observe/Replay | Authoritative terminal/interruption events, independent outcomes, receipts, explanation projections, metrics, and deterministic replay feed the next evidence cycle | Observation cannot fabricate an unobserved outcome, reverse-write state, authorize an effect, or certify/adopt its own replay result |

Silicon Capability Fabric spans only Kernel Ownership, Adapter/IO, and Observe/Replay. It may accelerate mechanisms there and deliver typed facts, offers, or receipts to the owners of the other planes, but it cannot enter Semantic Authority, Execution DAG, ControlRing, or Data Plane and cannot become an eighth plane, semantic owner, route, or release mouth.

### 2.5 Target cooperation across incumbent and approved-planned mechanisms

The diagram is a target composition, not a current-code reachability claim. Approved-missing or approved-planned nodes—including the State Requirement Planner, State Market, exact tokenize-once/accounting/progressive-disclosure context-compiler extensions, Provider egress boundary, certification, and cutover seams—remain unavailable until their owning wave and exact gates pass. The incumbent character-budget `BASContextCompiler.compile` mechanism already exists and is called; that fact does not supply the missing exact extensions or their gates.

Title-case names below are logical phase labels, not permission to create same-named types, routers, gates, or owners. Input normalization maps to the incumbent Adapter/Input Normalizer; intent/risk to L6 classification plus L11 risk/disclosure; eligibility to L7; context budgeting to the sole `BASContextCompiler`; prefill/decode to phase actuation of the already selected `BASExecutionPlan` through K2/Provider contracts; output verification to the branch-specific L10 step; and runtime-state commit to the complete L13 → K3 invisible stage → L14 → K4 terminal-seal → K3 seal/expected-parent-activation chain. A tool remains an L9 proposal: execution requires L10/L11/L13, K3 outbox prepare/handoff, L14 exact authorization, K4 issue/reserve, Zone-C `dispatch_pending`, K4 claim, Zone-C `dispatch_ready`, K3 pending, K4 anchor, K3 arm, one Zone-C dispatch/reconcile, a terminal receipt, and—only if state follows—the full L13/K3/L14/K4/K3 commit suffix. A final response instead requires the pinned terminal source and visibility chain, L12 non-visible spool, L10/L11/L14 release decisions, exact preparation/manifest, K3 prepared row, independent publication-journal reserve, K3 permit, K4 claim/anchor, K3 arm, the sole L12/Adapter-IO sink, journal finalization, and K3 boundary close. These are sibling W5-owned paths and execute neither before their gates nor merely because L10 passed. No independent Prefill Router, Decode Router, Output Verifier, Tool Runtime, Final Response publisher, or State Commit Gate is created by this diagram.

```text
Input Event
  -> Input Normalizer
  -> Intent + Risk Router
  -> State Requirement Planner
  -> Multi-lane StateLake Retrieval
  -> Eligibility Gate
  -> State Market
  -> State Grounding + Conflict Resolution
  -> canonical BASContextCompiler (including context-budget allocation)
  -> Prefill Router
  -> Decode Router
  -> branch-specific output verification/release
     |-- Tool Proposal -> L10 -> exact W5 effect.zone-c-saga path
     `-- Final Candidate -> L12 non-visible spool -> L10
         -> exact W5 release.spool-publication path

Runtime-state candidate, if any:
  -> State Commit Gate when a runtime-state candidate exists
  -> K3/EventLog authoritative event/commit
  -> rebuildable StateLake projection update

Every authoritative K3 event group—not only successful final response:
  normalized input/admission
  + completed | failed | refused | cancelled | crashed | abstained Attempt
  + Provider/tool/effect terminal or indeterminate/query/reconcile receipts
  + verifier, final-response, state-commit, rollback, and delayed-outcome events
  -> immutable Experience Envelope or explicit ineligible receipt
  -> learning eligibility and split
  -> reward evidence + attribution/identified-causal status
  -> memory, Evidence-B, dataset, or non-runtime candidate
  -> its exact governed path from Section 1
```

The learning path begins from authoritative events and independent receipts at every terminal/interruption boundary, including work with no output or state commit. It is never an alternate direct output-to-memory or output-to-training shortcut. This avoids survivorship bias toward successful turns.

## 3. Experience, Reward Evidence, Attribution, and Causal Credit

### 3.1 Experience envelope

Controlled convergence MUST define or reuse one immutable governed experience-envelope schema with at least the following semantic fields:

| Group | Required bindings |
|---|---|
| Identity | Exact App Agent, Session, logical Main, Main execution generation, Attempt, WorkUnit, branch/Sub role, Provider invocation, and event IDs |
| Runtime | Exact Provider/model/profile/tokenizer/processor/template/context ABI/policy identities and device/OS capability cohort |
| Decision | Frozen state snapshot/high-water mark, finite eligible action set, chosen action, behavior-policy identity, exact propensity, exposure/cohort, and abstention state |
| Task graph | Objective, Mission/WorkUnit/DAG node identity, parent edges, tool state transitions, effect/query receipts, and verifier receipts |
| Outcome | Bounded delayed-outcome window, independent result references, user correction/comparison, task completion, and rollback/reversal facts |
| Epistemics | Uncertainty, conflict, missingness, source independence, support class, and unresolved requirements |
| Governance | Data purpose, consent epoch, privacy class, retention policy, deletion/revocation epochs, legal/provider-use constraint, and current eligibility |
| Lineage | Ordered parent artifacts, source events, derivation manifest, root causal group, and schema/canonicalization versions |

The envelope MUST NOT contain raw hidden chain of thought, KV state, credentials, secret tool material, unbounded transcripts, or an answer relabeled as ground truth merely because the model emitted it. Typed receipts and features are preferred.

Learning content follows the controlled requirement for a signed W2 durable-content operator Decision Gate; this specification presumes neither that a signed disposition already exists nor that either branch was selected. With no valid current signed disposition, every path that requires durable raw/content bytes—materialization, dataset, export, trainer, or cold replay—is disabled; a provably content-free typed-receipt/feature-only path may still proceed through its own purpose/privacy/authority gates. If **Approved**, only the enumerated covered content classes may use separately encrypted, minimized, purpose-bound content-addressed artifacts referenced by digest, with the approved erasure/retention closure. If **Disapproved**, Experience/dataset state contains only digests, typed structure, minimum source-span metadata, and ephemeral purpose-bound materialization; no new durable raw-content writer/schema/cold-replay path is reachable, and restart returns typed `contentUnavailable` rather than reconstructing content. Every dataset materialization, export, trainer job, and recovery path binds and reopens that signed disposition when it depends on durable content.

There is a controlled-document conflict to close atomically: the 2026-07-19 specialization's unconditional statement that persisting canonical raw content is an approved change cannot substitute for the master/W2 signed Decision Gate or its selected branch. W1/W2 must revise that statement and all dependent fixtures together with the actual signed disposition. Until then, it grants no authority and every durable raw-content writer remains disabled.

An envelope may be incomplete. Missing values are explicit tagged states, never empty strings or fabricated defaults. A late result appends a new child event; it does not mutate historical evidence.

### 3.2 Reward evidence is a vector, not one seductive score

Each eligible experience produces a typed `RewardEvidenceVector` semantic value with separate dimensions:

1. correctness and factual support;
2. task completion and constraint satisfaction;
3. process integrity and tool/effect honesty;
4. safety, authority, privacy, and policy compliance;
5. user utility and explicit preference fit;
6. calibration, abstention quality, and uncertainty honesty;
7. robustness across perturbation, provider, device, and temporal cohorts;
8. latency, energy, memory, token, byte, and monetary efficiency;
9. data quality, independence, coverage, and contamination risk.

Selection order is lexicographic and fail-closed:

1. apply hard eligibility and veto gates;
2. reject any uncompensable safety, authority, privacy, or effect-integrity failure;
3. require correctness and all necessary constraints;
4. compare survivors on a declared Pareto frontier;
5. apply one versioned deterministic tie-break only after the above.

A high utility or speed score cannot compensate for wrongness, unauthorized action, privacy leakage, or unverifiable effects.

If one external optimization algorithm requires a scalar, the dataset references a versioned, immutable `RewardProjectionManifest` design-candidate semantic. It is scoped to one experiment, records every transform/weight/clip/missing-value rule, and has no production authority. Changing it creates a new experiment identity and invalidates comparisons that assumed the old projection.

### 3.3 Claim-specific evidence eligibility

There is no global evidence total order across unlike claims. An exact compiler receipt can prove compilation but not user preference; an explicit user choice can prove that stated preference but not an external-world fact. L7/L10 use a frozen claim/evidence eligibility matrix:

| Claim kind | Primary eligible evidence | Boundary |
|---|---|---|
| Deterministic task/property | Exact test/compiler/database/solver/replay receipt | Proves only the encoded property under the bound environment |
| Tool/effect/external state | Authenticated actuator/tool receipt or independently queryable delayed outcome | Unknown delivery remains indeterminate |
| World fact | Authoritative/cited source plus provenance, freshness, conflict, and independence | Repetition/model agreement cannot raise authority |
| User preference/consent/correction | Explicit current user event in the exact scope/presentation | Proves the user's statement/choice, not general truth |
| Process integrity | Structured precommitted state/tool/verifier transitions with exact inputs and receipts | Post-hoc explanation is not process evidence |
| Open-ended quality weak label | Independent model judge with exact identity, prompt, uncertainty, bias tests, and correlation class | Never sole truth, safety, or promotion evidence |

Within one claim kind, more direct, independent, current, and reproducible evidence may dominate weaker evidence according to its frozen rule. Cross-kind evidence cannot substitute by numeric score.

Every machine verifier is bound by a `VerifierClaimContract` design-candidate semantic: exact subclaim, input/environment domain, accepted/rejected language, soundness class, completeness/coverage class, known blind spots, nondeterminism, version, and independent test roots. “Deterministic” means reproducible, not automatically sound, complete, or task-correct. Only an exhaustive/proof-grade verifier whose contract covers the whole task may establish full correctness alone; a compiler pass, unit test, SQL execution, format checker, or public reward script establishes only its exact subclaim.

The following do not constitute reward evidence by themselves:

- clicks, dwell time, response length, session duration, opens, praise, silence, or no response;
- the candidate model's confidence or self-critique;
- majority vote among samples sharing the same base/model-family/root data;
- a synthetic example's generator label;
- an external API response with no independent support;
- a same-turn output converted into a ticket and then replayed against itself.

### 3.4 Observable thinking construction

Qinao learns from **observable cognitive work products**, not hidden chain of thought. A task may emit bounded typed artifacts for:

- mission, objective, WorkUnit, and completion condition;
- premises, hard constraints, variables, entities, temporal facts, and dependencies;
- evidence references and their authority/source-independence class;
- candidate answers or plans and concise rationale codes;
- counterexamples, contradictions, alternative hypotheses, and unresolved questions;
- tool requests/results, verifier requests/results, and effect state;
- uncertainty, missing prerequisites, sufficiency, abstention, and terminal receipt.

These artifacts are designed for replay, verification, credit, and recovery. They MUST NOT request or reconstruct private token-by-token reasoning. Free prose is treated as untrusted content, not state.

A cognitive work product earns process evidence only when its parent is committed before the child/action it claims to guide and an exact downstream-consumer receipt proves that the decision consumed it. EventLog order, not a caller wall-clock, establishes before-use. A rationale emitted after the answer, or never consumed by the next step, is labeled `explanationOnly`; it receives zero process-reward and causal-credit weight.

### 3.5 Attribution and causal credit across Main and Sub Agents

Credit assignment follows the event DAG rather than averaging Agent outputs or rewarding a final speaker. For each claimed contribution, the system records:

- the exact parent state and evidence visible to that actor;
- the proposed delta and downstream consumer;
- direct verifier/tool/outcome receipts attributable to the delta;
- whether the contribution was used, superseded, contradicted, or merely correlated;
- model-family, prompt-template, dataset-root, and evaluator correlation classes;
- missing counterfactual support.

Every result carries one epistemic status:

- `directAttribution` — an exact receipt proves which contribution/tool/action produced a recorded transition, without claiming what would have happened otherwise;
- `diagnosticAssociation` — replay, ablation, Shapley-, or COMA-like analysis suggests marginal usefulness but may be off-distribution or confounded;
- `identifiedCausalEffect` — a randomized logged intervention, or an explicit validated structural causal model with support and stated assumptions, identifies the declared estimand;
- `indeterminate` — evidence is insufficient or assumptions fail.

Preferred analysis methods are:

1. direct deterministic receipt attribution;
2. exact replay or leave-one-contribution-out ablation labeled diagnostic unless the environment transition is fully deterministic and the counterfactual remains on support;
3. preregistered randomized or otherwise identified counterfactual evaluation on supported finite decisions;
4. Shapley- or COMA-like approximations for diagnostics only, with distribution shift, approximation error, and correlation disclosed.

Changing or removing an Agent contribution can alter all downstream context, so leave-one-out is not automatically causal. Unknown credit is `indeterminate`; it is not zero and not shared equally. Subject to the status/use matrix below, eligible V1 attribution/credit may curate data and improve non-authoritative adaptive-statistics candidates. It MUST NOT directly update Main-model weights, Stable Self, or a route.

Credit use is mechanically limited:

| Status | Permitted use | Optimization influence |
|---|---|---|
| `directAttribution` | Provenance, process-quality label, audit, deterministic transition accounting | May weight only the exact observed transition property; no counterfactual action-value claim |
| `diagnosticAssociation` | Debugging, failure clustering, experiment/counterfactual design | Exactly zero training/reward/policy-update weight |
| `identifiedCausalEffect` | Update the declared causal action value inside the exact estimand/support/assumption scope | Bounded by the preregistered influence cap |
| `indeterminate` | Preserve uncertainty and request evidence | Exactly zero optimization weight |

No generic `creditScore` may erase this status or widen its estimand.

### 3.6 Off-policy evaluation boundary

OPE applies only to finite, logged decisions whose behavior policy is known. Each experiment freezes an `OPEEstimandManifest` design-candidate semantic that binds:

- exact target population, time window, decision unit, treatment/action, comparator, and outcome;
- horizon, delayed/censored-outcome handling, and missingness assumptions;
- full eligible action set and exposure mechanism;
- behavior-policy identity and exact propensity for the chosen action;
- target-policy identity and probability kernel;
- estimator, clipping/switch rule, sensitivity analyses, and confidence procedure;
- nuisance-learner specification identity, feature set, hyperparameters, fitting mode, fold rule, and fold seed, all frozen before evaluation-root access; for an external-prefit mode, the exact fitted artifact/data-root receipt; for an in-root OOF mode, the exact fold count/index/schema, deterministic child-receipt identity derivation, and ordered-child-set rule. Each post-open fit emits a new immutable per-fold training-root/fitted-artifact child receipt, and the final evaluation bundle binds their complete ordered set; the parent manifest bytes never change;
- grouping unit plus longitudinal dependence, carryover, and interference assumptions;
- support/overlap diagnostics and effective sample size;
- all data-purpose, privacy, and deletion epochs.

Cross-fitting keeps a causal root/Agent/episode/time block wholly outside the nuisance-model fold that scores it. Confidence intervals cluster at the declared dependence unit. If treatment versions, interference, carryover, censoring, or adaptive collection cannot be modeled honestly, the report narrows its estimand or becomes `notIdentifiable`.

For V1, each OPE root/epoch either freezes the behavior policy and assignment mechanism for its full collection interval, with epochs stratified and never naively pooled, or preregisters an estimator/confidence process valid for adaptive dependent collection. The latter binds the history filtration, policy-update epochs, predictable propensities, dependence unit, stopping rule, and martingale/anytime-valid or dependent-bandit assumptions. Ordinary iid intervals, ordinary cross-fitting, and ordinary contextual DR do not become adaptive-valid merely because propensities were logged.

Where overlap is absent or propensity is unknown, the result is `notIdentifiable`. It cannot be repaired by a larger model, a fabricated propensity, or an ordinary shadow replay.

### 3.7 Reward firewall

Every learning experiment preregisters:

- the frozen candidate and baseline identities;
- hypothesis, metrics, vetoes, cohorts, split roots, and stopping rule;
- generator, behavior-policy, verifier, judge, certification, and cutover identities;
- model-family/data-root correlation classes;
- contamination, leakage, deletion, and privacy checks;
- allowed adaptations and maximum influence.

Before split assignment, the system computes immutable causal-root keys and discovers exact/semantic duplicate and near-duplicate connected components using a frozen detector. It does not yet collapse, sample, transform, augment, translate, summarize, or generate examples. Each connected component and every descendant of one task/document/tool trace/temporal episode/synthetic seed then enters exactly one train/validation/visible-evaluation/hidden-holdout split. All later derivation happens inside that split.

For a forward temporal cutoff, a duplicate/ancestry connected component that has members on both sides is indivisible: the whole component is assigned to the later split, or the whole component is purged when that assignment would violate the frozen cohort/estimand contract. No earlier member may remain in training while a linked later member enters evaluation. Component discovery may use only the frozen detector and immutable provenance needed for grouping; it may not use future labels or outcomes as training features.

The split policy matches the estimand. Population/general-model evaluation uses user/App-Agent-group-disjoint splits. Per-App-Agent local adaptation keeps the App-Agent compartment fixed but uses forward temporal/episode splits with no future leakage. Longitudinal evaluation groups carryover episodes. An App-Agent scope is always an isolation boundary, but it is not blindly a single split when the estimand is within-Agent future performance.

A generator never supplies truth for its own sample. Human/verifier anchors, rare failures, safety cases, and historical regressions remain represented. Missing or conflicting evidence never becomes a favorable default.

User pairwise collection records the exact shown candidate bytes/digests, randomized and blinded left/right order, exposure propensity, tie/skip/none-of-the-above, timing window, solicitation copy, and user-input identity. It prohibits leading prompts, repeated pressure, sycophantic framing, and treating non-response as preference.

Model-judge evaluation randomizes order, blinds candidate/provider labels, reverses positions, isolates quoted untrusted content, and tests position, verbosity, self-reference, and prompt-injection bias. A judge failure or disagreement remains a weak-label limitation, not a hidden tie-break.

### 3.8 User feedback and stable Self

An explicit user correction is a new Input Event with its own time, scope, and provenance. `candidateLeft > candidateRight` establishes only that user's stated pairwise preference under that presented context. Undoing a task effect is a task/effect signal, not automatically a personality or relationship preference.

Automatic competence/strategy candidates MAY be derived when evidence and reversibility permit. A Stable-Self/value/relationship mutation still requires:

1. independent evidence beyond model output;
2. conflict and contamination review;
3. an immutable candidate with exact before/after diff and consequence preview;
4. L10 validation against the frozen candidate, complete read set, and evidence;
5. L11 risk/disclosure revalidation plus explicit current confirmation from the self-governance principal;
6. L13 exact adoption-intent prepare and K3 invisible stage with frozen K4 request material;
7. L14 authorization of only that candidate/read-set root;
8. mandatory domain-separated K4 issue/reopen, reserve, claim/use, claimed-target attestation create/reopen, and caller-side ordinary target-attestation put;
9. independent K3 state-commit seal followed by expected-parent activation CAS;
10. inspect, revoke, and rollback behavior.

No amount of implicit engagement can satisfy these steps.

## 4. Immutable Data Flywheel

### 4.1 Data generations, not a mutable pool

The data flywheel is a lineage of immutable, purpose-bound dataset generations. It is not a `TrainingPool`, `DistillationBank`, `LearningStore`, appendable bag, mutable queue, or latest-wins table.

```text
Source Event high-water mark
  -> eligible Experience Envelopes
  -> pre-split causal identity plus exact/semantic duplicate-component discovery
  -> freeze each complete component into exactly one split
  -> purpose-specific within-split cleaning, collapse, and materialization
  -> immutable Dataset Manifest generation N
  -> authorized trainer or adaptive-statistics batch
  -> candidate + receipts
  -> evaluation/cutover outcome
  -> new independent Source Events
  -> generation N+1, never mutation of N
```

Every material change to membership, transform, split, objective, policy, consent, deletion state, weight, or output class creates a new manifest identity. SQL tables may index manifests; they cannot redefine them.

### 4.2 Purpose classes

Data eligibility is evaluated independently for each declared purpose:

| Purpose | Default posture |
|---|---|
| On-device Evidence-B sufficient-statistics/calibration improvement under a separately certified finite Policy-A definition | Local-only, typed/minimized, reversible, exact App-Agent/Profile/domain compartment |
| App-Agent personalization and memory assimilation | Local-only, purpose-bound, Stable-Self rules still apply |
| Feature and system evaluation | Local where possible; export only with exact authorization |
| Product-quality model training | Default denied until explicit current authorization and all export gates pass |
| Safety and regression corpus | Separate purpose and retention class; minimization and user rights still apply |
| General/base-model training | Default denied and never inferred from ordinary product use |

Authorization for one purpose does not authorize another. Sharing data with another App Agent, showing it in a session, or calling an API does not grant training rights.

### 4.3 Seven-pass cleaning pipeline

Every item MUST pass the exact cleaning responsibilities already approved by the App-Agent design before durable dataset, memory, policy, evaluation, or export eligibility:

1. **Structural:** bounded schema/canonical bytes, Unicode/control characters, type, and parser validation.
2. **Instruction:** external instructions remain escaped data and cannot become system/tool/control instructions.
3. **Provenance:** complete lineage, request correlation, source identity, circularity, replay freshness, and root-independence checks.
4. **Epistemic:** preserve the distinction among direct observation, user self-report, external claim, model inference, opinion, and emotion hypothesis.
5. **Semantic:** before split, discover and freeze exact/semantic duplicate components without collapsing them; after split, collapse/deduplicate only within the component's assigned split, normalize entity/time where justified, disambiguate, and preserve contradiction rather than averaging it away.
6. **Privacy:** enforce secrets/PII, App-Agent/Workspace scope, remote disclosure, retention, deletion, and minimum-necessary materialization.
7. **Self-contamination:** detect prompt injection, sycophancy, reward gaming, self-authored value change, abrupt personality drift, and model-specific bias.

Unknown or failed results enter quarantine and receive no best-effort admission. The responsibilities remain distributed across Adapter/IO, L7, L10, L11, L13, L14, and K3 as defined by the incumbent architecture; this list does not create a `DataCleaningManager`. Model-assisted cleaning is an untrusted Proposal and cannot raise source authority.

### 4.4 Dataset manifest contract

A controlled `DatasetManifest` semantic contract MUST bind at least:

| Group | Required fields |
|---|---|
| Identity | Dataset ID, generation, schema/canonicalization versions, purpose, parent generation, creation job, and immutable root digest |
| Source | Exact EventLog snapshot/high-water mark, member Experience IDs, root causal groups, and inclusion/exclusion reason manifests |
| Example | Exact example kinds, App-Agent compartments, source roles, modalities, language/domain tags, and content/materialization references |
| Governance | Consent/purpose/policy/deletion/revocation epochs, privacy/retention/license/provider-terms class, export destination, and expiry |
| Splits | Frozen train, validation, visible evaluation, hidden holdout, predeployment-canary fixture, and rejection sets with grouping keys; this fixture split is not a production canary Release/cohort |
| Derivation | Deduplication, cleaning, redaction, normalization, augmentation, synthetic generation, weighting, sampling, and transform identities |
| Evaluation independence | Generator, behavior-policy, judge, verifier, model-family, data-root, and correlation classes |
| Quality | Strata, source caps, rare-case coverage, balance, contamination/leakage results, temporal window, and drift facts |
| Trainer | Exact allowed trainer class, input materialization, objective class, allowed output classes, and forbidden uses |
| Captured lifecycle | Parent generation, frozen eligibility/policy/deletion epochs, expiry, and retained proof/cleanup obligations as they existed when the manifest was created |

The manifest references immutable members. It does not inline an uncontrolled corpus or convey permission by possession.

Membership and split lists are bounded Merkle manifests, never unbounded arrays. Each canonical Artifact is at most the existing 16 MiB Artifact-Mesh limit; leaf chunks contain a bounded ordered set of member/root-group references, intermediate nodes have a fixed maximum fan-out, and the dataset root binds each split's Merkle root, member/chunk counts, byte totals, and ordering/canonicalization rule. A hidden-holdout root lives in its certification-only compartment. Pagination, chunk loss, duplicate membership, reordered leaves, count mismatch, or a root whose closure exceeds declared bounds fails closed.

Post-creation facts—current eligibility, a superseding generation, a newly installed deletion fence, job use, and cleanup progress—MUST live in exact K3 lifecycle events/receipts and rebuildable projections that reference the immutable manifest. They cannot be edited into generation N or inferred from the existence of generation N+1.

### 4.5 Example kinds remain distinct

The flywheel MUST NOT flatten heterogeneous evidence into generic prompt/response rows. At minimum it distinguishes:

- independently verified demonstration;
- explicit pairwise preference;
- desirable/undesirable point example;
- tool or effect trajectory with exact state receipts;
- observable cognitive-process transition;
- delayed independent outcome;
- contextual-bandit `(x, actionSet, behaviorPolicy, propensity, action, outcome)` tuple;
- counterexample and frozen regression case;
- abstention and calibration example.

Conversion between kinds requires a named transform with proof obligations. A user pairwise preference does not become factual ground truth; a synthetic demonstration does not become a deterministic verifier result; an outcome without support does not become an OPE tuple.

### 4.6 Split integrity and contamination control

Root grouping plus exact/semantic duplicate-component discovery happen before split assignment; actual deduplication/collapse and every derivation, augmentation, translation, summarization, sampling, or synthetic expansion happen only after the connected component is frozen into one split. Task/document/tool-trace/episode/synthetic-seed descendants never cross splits. User/App-Agent grouping follows the preregistered estimand: group-disjoint for population/generalization claims, forward temporal/episode splits inside one isolated App-Agent compartment for local personalization claims.

Dataset-level gates MUST check:

- complete lineage and current eligibility;
- exact and semantic near-duplicate leakage;
- benchmark and hidden-holdout contamination;
- prompt/tool/data injection and executable payloads;
- direct PII, secrets, and semantic re-identification risk;
- license, provider terms, residency, and purpose restrictions;
- per-source, per-user, per-App-Agent, per-model-family, and synthetic source caps;
- demographic/domain/language/length/difficulty and outcome balance where relevant;
- rare failure, abstention, safety, and adversarial coverage;
- generator/judge/verifier correlation and same-root majority risk;
- temporal drift, OS/model/profile changes, and stale consent/deletion epochs.

A single Boolean such as `privacySafe`, `scrubbed`, or `sovereignSafe` is not sufficient evidence. Each decision must reopen typed receipts, exact policy epochs, the transformation lineage, and a bounded reason set.

### 4.7 Sampling recipe

Each dataset generation preregisters the following required strata:

1. human or deterministic-verifier anchors;
2. historical regression fixtures;
3. safety, authority, privacy, and effect-integrity cases;
4. rare failures and explicit abstentions;
5. explicit user corrections and pairwise choices;
6. representative domain and device/profile cohorts;
7. recent temporal drift samples;
8. bounded synthetic augmentation isolated by source class.

Every stratum is either non-empty with declared minimum count/weight/coverage or carries a typed, owner-issued `notApplicable`/`unavailable` receipt with the claim scope and reason. Silent omission, an empty array, or “as applicable” prose is not a completed sampling recipe. Synthetic augmentation may legitimately be `notApplicable`; it is never required merely to fill volume.

Synthetic data is a coverage tool, not truth. Every sample carries transitive synthetic ancestry, generation depth, generator-root lineage, prompt/configuration identity, correlation class, and independent acceptance test. A human edit does not erase synthetic provenance; independent proof may add a verified label for an exact claim but cannot relabel the ancestry as human-origin. Caps apply both to row count and to effective weighted influence aggregated across all descendants/generations of one synthetic root, so recursive generations cannot launder one source, compound their weight, or crowd out anchors and rare real failures.

### 4.8 App-Agent isolation and sharing

Each private example binds exactly one App-Agent authority scope. No authorized path lets another App Agent read, mutate, train on, retrieve, or query it. User-owned neutral shared Workspace data remains a separate scope and requires an exact share/release envelope for each consumer and purpose.

An explicit share grants only the stated read/use. It does not:

- merge memories or relationships;
- transfer identity or Stable Self;
- authorize training;
- permit onward export;
- permit the recipient to alter the source App Agent's data;
- survive revocation, deletion, or expiry beyond the exact policy.

Weights, adapters, checkpoints, optimizer state, calibration material, embeddings, synthetic descendants, training receipts, metrics, logs, and evaluation outputs are protected tainted derived artifacts; transformation or trainer return never declassifies their sources. Their allowed consumer scope and purposes are the intersection of all source grants, not the union. A candidate trained on one App Agent's private data is same-App-Agent-only by default and cannot be selected for another App Agent, a neutral shared Workspace, a general product model, or an API teacher. Shared/general derived use requires every source to carry an explicit grant for that purpose and consumer class.

Every derived candidate additionally passes memorization, rare-string/canary extraction, nearest-neighbor reconstruction, membership-inference, prompt-extraction, and cross-App-Agent negative suites. Passing reduces measured leakage risk; it does not prove differential privacy or authorize a wider scope. Scope enforcement remains mandatory at model/profile selection, context materialization, candidate evaluation, export, and cutover. Deletion/revocation fences every descendant candidate/checkpoint immediately and triggers the honest unlearning/retirement lifecycle in Section 4.11.

### 4.9 Local-first export path

Learning data stays local by default. The sole corpus/trainer export path is the approved-planned W5 physical effect/egress boundary. It does not exist at this snapshot; `QinaoLearningExporter` may prepare minimized inert bytes but cannot own or perform transport:

```text
Frozen purpose-specific Dataset Manifest
  -> minimum necessary materialization
  -> L11 privacy/disclosure/retention/license checks
  -> explicit current user authorization
  -> L13 binds the exact causal predecessor, effect request, branch intent,
     outbox content, destination, purpose, payload, and read set
  -> K3 prepare/enqueue the exact outbox and effect branch
  -> L14 authorizes that exact branch + destination + purpose + payload
  -> domain-separated K4 issue/reopen/reserve
  -> K3 handOffEffectToZoneC for that prepared tuple
  -> approved-planned W5 Zone-C/BASEffectBroker persists dispatch_pending
  -> K4 claims the exact branch-bound capability/use
  -> Zone C persists that claim and advances to dispatch_ready
  -> K3 advances the same tuple to effect_permit_pending
  -> K4 anchor the claimed boundary
  -> K3 arm the exact boundary
  -> Zone C atomically consumes the exact permit + anchor + arm and CASes
     dispatch_ready -> dispatch_boundary_armed before the handoff deadline
  -> only that local CAS winner calls the sole physical egress adapter at most once
  -> adapter query/reconcile/ack or typed indeterminate
  -> governed terminal receipt and K3 closure
```

The exact order, ownership, crash matrix, queryability, and possible-start semantics are those approved for the W5 Sovereign Zone-C effect protocol. Corpus export requires a separately approved exact effect profile on the sole planned `BASEffectBroker`. Until W5 creates/gates that broker and the profile honestly expresses destination, retention, deletion, and query semantics, external corpus export is disabled. A `TrainerTransport`, direct URL session, exporter-owned retry, or parallel egress journal is forbidden.

The authorization MUST bind the exact App Agent, data categories, purpose, destination, trainer class, manifest digest, payload digest/byte count, retention/deletion terms, expiry, and onward-use policy. A generic “improve the app” toggle, prior export, login, API key, or subscription is insufficient.

Content minimization preference is:

1. typed verifier/tool/outcome receipts and bounded numeric/categorical features;
2. exact necessary spans kept device-local for cleaning/verification;
3. generalized/redacted structural text when its export is separately necessary and authorized.

V1 never exports raw user conversation, attachments, private memory content, or unredacted tool traces as an improvement corpus, even with a generic approval. A future posture change requires explicit controlled-document and privacy approval; it cannot be introduced by widening this minimization list.

Logs, crash reports, analytics, UI previews, caches, model prompts, and trainer stdout are not alternate export channels.

### 4.10 On-device data posture and user controls

The on-device adaptive-statistics path consumes typed, bounded features and outcomes only. Raw conversational content, hidden model state, stable identifiers, emotional labels, and cross-App-Agent embeddings are prohibited.

Local strategy adaptation MAY be enabled by default only after product/privacy review proves that it is local, reversible, non-authoritative, inspectable, and non-sensitive. The user MUST be able to:

- inspect what decision domains adapt;
- pause further updates;
- reset one adaptive-statistics domain to absence/its clean parent so the certified Policy-A definition selects its deterministic baseline;
- disable adaptation without losing ordinary product access;
- delete eligible local learning data and see an honest cleanup state;
- distinguish local adaptation from external model training/export.

Stable-Self learning is never hidden behind this setting.

### 4.11 Continual-learning and forgetting posture

Model improvement uses a frozen base plus a versioned adapter or full candidate, a declared trainable-module set, replay data, and full-domain regression. Any change to weights, adapter, quantization, tokenizer, template, context ABI, converter, custom operation, MTP behavior, or model package creates a new candidate identity.

Every candidate is evaluated against an **all-clean-ancestor retention matrix**, not merely its immediate parent. Constitutional, hard-zero, authority, privacy, safety, and effect-integrity invariants are permanently non-retirable and remain represented in every candidate family. Previously accepted domains, rare regression roots, App-Agent scopes, and capability cohorts also remain represented; only a superseded cohort or obsolete fixture may retire, and only through its sole owner's controlled policy/schema-migration receipt with explicit replacement coverage—not through a candidate, job, trainer, or generic “justified” receipt. The ordered adapter stack, merge order, merge precision, and interference against each ancestor are frozen and tested; replay coverage is reported by ancestor/domain/root rather than as one aggregate. For every stochastic cell, the job/certification manifest freezes the exact estimand, direction, non-inferiority/harm margin, hard-veto status, sample/information target, and the simultaneous or anytime-valid error control over the full ancestor × domain × cohort × candidate/interim family. Any required cell that crosses its bound or remains inconclusive blocks certification, canary, and full cutover. Each algorithm has a preregistered uncertainty, sensitivity, and replication plan appropriate to its determinism and variance. A nominally deterministic run still requires environment/reproducibility and perturbation sensitivity; a blanket “two seeds” rule is not evidence of stability.

Deletion is staged and honest:

1. synchronously fence the source and every not-yet-used descendant from retrieval, training, evaluation, export, and adoption;
2. mark affected immutable manifests/candidates ineligible without rewriting history;
3. cancel or quarantine in-flight jobs and late results;
4. perform bounded physical cleanup of materialized copies, caches, checkpoints, and exports;
5. retain only the minimum tombstone/proof required for non-reuse and compliance;
6. record whether already-trained weights can be exactly unlearned, require candidate retirement/retraining, or cannot honestly satisfy the requested guarantee.

If the product promises exact unlearning for a data class and the system cannot implement it, that data class MUST NOT enter training. Cryptographic erasure of encrypted material does not prove semantic unlearning from already-produced weights.

Federated learning and differential privacy are future candidate capabilities, not V1 claims. They require separately approved clipping, privacy accounting, secure aggregation, poisoning resistance, cohort thresholds, device attestation, dropout handling, deletion semantics, and empirical utility/privacy evidence.

### 4.12 Current-code disposition

| Existing mechanism | Reality | Required disposition before production learning |
|---|---|---|
| `BASDistillationBank` | Immutable value type whose `ingesting` method returns a new bank, but caller-asserted `scrubbed`/`privacySafe`/`sovereignSafe`, composite score, and `exportManifest` can mint favorable Booleans and a pool-like export view | Treat as a non-authoritative compatibility projection or retire; never a dataset, truth, eligibility, export, or promotion owner |
| `BASAppleInterventionBanditAdvisor` / `BASAppleInterventionBanditSnapshot` | Dormant value mechanism with caller-supplied string bucket/action IDs and Boolean reward; no production caller or governed Policy-A/Evidence-B lineage is proven | Fixture/mechanism-only or retire; its wire and updater cannot become a Policy-A definition, Evidence-B snapshot, reward truth, routing owner, or production adaptive-state mouth |
| `QinaoLearningExporter` / `QinaoMemory.LearningExportBundle` | Useful export scaffold with coarse string/Boolean gates | Rebind to exact typed manifests, current policy receipts, minimization, destination/purpose authorization, transfer receipt, and negative fixtures |
| `BASUpdateTicketLifecycleCoordinator` | Existing actor with ticket lifecycle and distillation-queue semantics; plain public `approveForDistillation` and `markDistilled` remain reachable alongside optional forbidden-zone/counter-host wrappers | Source-gate/remove the plain production mouths and reduce the mechanism to a projection/client of K3 lifecycle or retire it; no independent queue/head/promotion/recovery mouth |
| `BASEvolutionLifecycleStage`/`Action`/`Policy`/`Session`, including `.promoted` | Legacy lifecycle vocabulary and value/session mechanism; there is no single `BASEvolutionLifecycle` Swift type | Map atomically to L13 candidate plus `runtime.certification` and `production.cutover`, or fence from production |
| `BASTrainingDataExporter` | Raw EventLog-to-JSONL actor; filtering/privacy is caller responsibility and full state may be inlined | Fence from production/release closure; at most a developer diagnostic over separately authorized synthetic fixtures—never the governed export path |
| `BASTrainingExampleSublimator` | Mutable in-memory buffer that emits training rows | Projection/demo only or retire; cannot create dataset membership, truth, split, reward, or trainer authorization |
| `EBrainRuntimeCoordinator+EvolutionGovernance` learning bundles and `BASDistillation*Ingest` | Same-turn candidate/output path can synthesize `scrubbed/privacySafe/sovereignSafe == true` | Remove/fence from learning eligibility; hard-coded Booleans and same-turn pseudo-shadow are negative fixtures, never evidence |
| `BASRetractionFurnace` | Mutable legacy entry/queue value and schema | Compatibility projection only or retire; no retraction, recovery, cleanup, or cutover authority |
| `BASMemorySleepConsolidationPass` / `BASSleepConsolidationDriver` | Off-turn mechanism can call `BASMemoryClosedLoopApplier` and apply L8 tier mutations when not dry-run | Force projection/dry-run until every mutation routes through the canonical memory adoption/commit owner; never a second scheduler/writer |
| Qwen3.5 capability manifest/MTP seams versus Qinao MLX facade | Manifest declares Qwen3.5-4B as chartered default and MTP mechanisms exist, but no production Qinao caller is proven; public Qinao MLX paths still expose/default Gemma variants | Record as design target, not current default; require exact Qwen Provider package, load/caller/release reachability, conversion/runtime evidence, and certification |
| SampleHost learning/export paths | Demonstration seams; current bench code directly calls plain `approveForDistillation` then `markDistilled` | Must remain negative/non-production fixtures, with a source/reachability gate proving they cannot enter release composition, until exact runtime composition and gates exist |

The lifecycle convergence must also fix durability semantics, not merely naming. Current lifecycle mutation precedes `persistQuietly`, and a failed save leaves the in-memory transition visible while only incrementing an error counter. Production replacement/convergence must use an atomic durable transaction or an explicit prepared/invisible/recovery protocol; a persistence failure can never expose an in-memory winner, queue entry, distilled terminal, or downstream eligibility that a restart cannot reconstruct.

## 5. On-Device Adaptive Ranking Evidence, OPE, Shadow, and Rollback

### 5.0 Two non-interchangeable objects

On-device adaptation is legal only after separating the fixed decision policy from its runtime evidence:

| Object | Contents | Lifecycle |
|---|---|---|
| **Policy-A — certified finite-decision policy definition** | Complete feature schema, finite action set, update math, score consumption, hard vetoes, Pareto/tie-break order, thresholds, uncertainty/abstention, safe-exploration/epsilon/cohort rule, and deterministic fallback | A non-runtime policy candidate. Any semantic change starts at E0/E1, passes `runtime.certification` through E4, then preregistered canary/E5 and separately sealed full `production.cutover` |
| **Evidence-B — immutable adaptive sufficient-statistics snapshot** | Canonical bounded observations/statistics plus lineage, currentness, uncertainty, and invalidation epochs needed by Policy-A | Non-authoritative runtime evidence only. It contains no selected action, route, action probability, epsilon, tie-break, fallback, permission, or policy semantics |

Only the one build/deployment-selected, certified `execution.plan-provider-router` or the corresponding incumbent domain router may consume Evidence-B under Policy-A's deterministic rules. The router's `mutable_state_owner` remains `none locally`; Evidence-B cannot route, lower a quality/risk gate, promote itself, or become a second plan elector. Missing, malformed, stale, unsupported, or conflicting Evidence-B yields Policy-A's deterministic baseline or abstention.

Controlled convergence MUST map Evidence-B to an existing runtime-state semantic target and exact state-commit path before activation. K3's ability to store a reference is not proof of semantic ownership. An E/A mapping requires the non-empty ExtensionGate; CreateGate is limited to an already Owner-Ledger-allowlisted `approved_missing` M production candidate and does not authorize a thirtieth owner. If no incumbent/allowlisted mapping survives the applicable gate, every on-device Evidence-B remains shadow-only in V1. This document does not reopen `production.cutover` as a runtime-selectable route.

### 5.1 Finite decision domains

V1 may produce separate Evidence-B snapshots for separate finite domains under separately certified Policy-A definitions. No shared “general intelligence head” is allowed. Candidate evidence domains are:

- Provider/Profile selection among already admitted choices;
- retrieval lane selection and bounded retrieval budget;
- pre-certified context geometry and compression choice;
- predeclared Sub-Agent topology/role allocation;
- reasoning-effort tier and stop/continue/clarify/abstain choice;
- predeclared tool-branch proposal choice;
- resource-plan selection within K1 limits.

Each Evidence-B snapshot is isolated by exact App Agent, device/profile cohort, decision domain, certified Policy-A identity, reward-evidence contract, and baseline generation as required by privacy and data sufficiency. Cross-user or cross-App-Agent aggregation is prohibited unless a separately authorized privacy-preserving protocol exists.

Policy-A and Evidence-B may provide score evidence only at an incumbent or approved-planned domain decision point, and an approved-planned point is unusable until its owning wave and exact gate pass. “Corresponding router” is not an escape hatch:

| Domain | Sole semantic/physical owner at decision | Evidence-B may influence only before | Immutable freeze point | Policy-A/Evidence-B may never override |
|---|---|---|---|---|
| Provider/Profile | Certified `execution.plan-provider-router`; K3 owns allocation/frozen branch identity | Router selects among already admitted descriptors | Provider allocation-receipt Artifact (`Provider-A`, unrelated to Policy-A), descriptor, plan, ordinal, and sequence-zero identity | Capability, currentness, Pareto hard gates, allocation, recovery, or in-Attempt fallback/re-election |
| Retrieval | L7 eligibility plus incumbent L8 retrieval; only after their W3 gates, approved-missing `state.snapshot-coordinator` and `state.snapshot-market` own snapshot/join semantics | Eligible lane/budget choice for one retrieval request | Required-lane set, source snapshot/high-water mark, join/omission contract | Required lanes, source authority, freshness/conflict rule, snapshot, or memory status |
| Context | Canonical `BASContextCompiler` | Selection among pre-certified geometry/compression options | Compiled context descriptor/materialization identity | Constitutional minimum, owner-required evidence, privacy, token hard cap, or compiler receipt |
| Delegation | Once created/gated, W1 `runtime.semantic-dag` owns only immutable slot vocabulary/topology; `runtime.turn-operation` binds an already authorized proposal to one exact declared slot; K3 alone allocates the winning branch by first-matching-unoccupied CAS | Whole certified DAG-template choice before DAG admission | DAG identity/topology, exact proposal-to-slot binding, then the unique occupied-slot branch CAS | Arbitrary topology/role/slot, direct slot filling, slot replacement, branch authority, or scheduler ownership |
| Reasoning effort/termination | Once created/gated, the approved-planned semantic-DAG/ControlRing protocol; K3 terminal/budget/progress receipts | Tier choice or next legal transition before a terminal receipt | Each admitted WorkUnit transition and any valid terminal state/reason | Information sufficiency, L10/L11, budget/progress witness, or reopening `cycleDetected`, `budgetExhausted`, `noProgress`, `needsConfirmation`, or any terminal branch |
| Tool branch | L9 proposal owner followed by the incumbent effect branch/Zone-C contract where applicable | Ranking among already eligible, predeclared proposal branches | Authorized tool proposal and any K3/K4/Zone-C prepare/claim boundary | Tool eligibility, permission, out-of-schema arguments, effect semantics, possible-start recovery, or resend |
| Resource plan | K1 | Choice among already admitted resource plans before lease | K1 lease/envelope and cancellation generation | Thermal/memory/energy ceiling, lease, cancellation, background eligibility, or user-path priority |

For all domains, Evidence-B is evidence consumed by Policy-A's frozen rule; it is never the decision owner. Once an incumbent terminal or freeze point is committed, neither a newer Evidence-B nor a recomputed score may continue, reopen, replace, or fork that decision.

Provider/Profile scoring and every capability/currentness/Pareto/fallback decision finish before any K3 Provider-branch allocation. Allocation freezes the selected descriptor, execution plan, route, ordinal, and sequence-zero execution identity. Later Evidence-B staleness, rollback, or score change cannot re-elect, abandon, fallback, or allocate a replacement inside the same Attempt; an allocated branch continues as itself, and possible-start recovery only joins/queries/reconciles/terminates it. A different route requires a newly authorized Attempt.

Sub-Agent topology is equally bounded. Once the approved-planned W1 `runtime.semantic-dag` is created/gated, Policy-A may use Evidence-B to choose only among whole preregistered certified DAG templates before Attempt/DAG admission. Once the DAG is frozen, `runtime.turn-operation` may bind one already authorized proposal to one exact declared optional slot, and K3 alone allocates the winning branch by first-matching-unoccupied CAS. The DAG owner does not fill slots; Evidence-B/callers cannot choose an arbitrary slot, alter topology, allocate a branch, or become a scheduler. Before W1 the contract is unavailable; before the converging W6 `runtime.semantic-executor` adaptation of incumbent `BASNativeStageExecutor` passes its convergence/source gates, execution is fixture/shadow-only. A new topology is a non-runtime Policy-A candidate and follows E0-E4, canary, E5, and full cutover.

### 5.2 Forbidden decisions

An adaptive statistics snapshot cannot decide, encode, or change:

- factual truth, final answer content, or evidence authority;
- memory, Stable Self, values, commitments, or relationship state;
- risk classification, eligibility veto, consent, privacy purpose, or disclosure;
- capability, permission, effect execution, payment, notification, or publication;
- model installation, certification, canary, full cutover, or rollback authority;
- feature/action/update-rule expansion.

It supplies bounded statistics from which the one certified router deterministically computes score evidence, uncertainty, and abstention under Policy-A. The router, not Evidence-B or K3, chooses only among the already certified finite set after every hard gate.

### 5.3 Feature contract

Features are owner-defined, typed, bounded, versioned, and purpose-specific. Every feature declares range, unit, missing-value representation, source owner, sensitivity, stability, and invalidation epoch.

Prohibited features include:

- raw text or raw embeddings of user content;
- hidden chain of thought, KV state, or logits beyond an approved calibration statistic;
- stable global user/device identifiers;
- inferred emotion, vulnerability, dependence, or manipulability;
- private data from another App Agent;
- a feature derived from the candidate's own future outcome;
- an opaque aggregate that can encode forbidden data.

Missingness is explicit. Unknown, overflow, NaN, infinity, schema mismatch, stale profile, or unauthorized feature makes Evidence-B ineligible and makes Policy-A select the deterministic baseline or abstain.

### 5.4 V1 algorithm and canonical evidence

The fixed Policy-A definition chooses exactly one algorithm class. A constrained linear contextual bandit is used only when Policy-A defines a logged probability policy and certified exploration/support. A calibrated linear ranker is a distinct deterministic class; it does not manufacture propensities or make alternative-action OPE identifiable. Both prioritize auditability, deterministic recovery, bounded influence, and cheap CPU execution over maximum theoretical expressivity.

Each candidate Evidence-B snapshot consists only of:

- the exact certified Policy-A Artifact ID/digest rather than copied policy values;
- immutable parent snapshot;
- canonical fixed-point sufficient statistics;
- deterministic sample order and batch high-water mark;
- influence/budget counters and current policy/deletion/invalidation epochs;
- complete training-example lineage and exclusion receipts.

Policy-A owns the fixed feature/action/reward/update definitions, regularization, clipping, missing-value, fixed-point scale, rounding, iteration order, overflow behavior, objective, score normalization, probability kernel, sampler, PRF, tie-break, exploration, and fallback. Canonical updates execute those rules with checked arithmetic. Fast-math, nondeterministic reductions, silent saturation, NaN, or platform-dependent floating serialization are forbidden in Evidence-B. A floating scoring projection may be recomputed from canonical statistics under Policy-A and verified against tolerance fixtures; it is disposable and non-authoritative.

Per-dimension scores are filtered and selected through Policy-A's frozen hard-veto, Pareto, and tie-break order from Section 3.2. When a behavior distribution is required, Policy-A maps the score vector to exact action probabilities with its versioned deterministic probability kernel and samples with its bound PRF/sampler before outcome observation. The logged distribution and chosen-action propensity must recompute byte-for-byte. A deterministic ranker logs its deterministic exposure and normally has no support for unchosen alternatives. An implementation cannot hide a new compensating scalar objective inside Evidence-B.

### 5.5 Safe exploration

Exploration belongs entirely to Policy-A and its preregistered canary mechanism; Evidence-B cannot select or modify epsilon. Where Policy-A permits exploration, it is restricted to a certified safe/reversible action set:

```text
behaviorPolicy = (1 - epsilon) * candidatePolicy
               + epsilon * certifiedSafeDistribution
```

The certified experiment manifest binds exact epsilon, PRF/cohort assignment, safe distribution, candidate action probabilities, chosen-action propensity, exposure, and expiry. Those values are logged as behavior evidence but never stored in Evidence-B. Epsilon is exactly zero when:

- risk, privacy, authority, effect, or consequence is high;
- any action lacks independent safety/eligibility/reversibility proof, or data quality cannot support safe logging;
- the user disabled adaptation;
- the profile/action/feature schema is stale;
- resource or recovery state is degraded;
- an action is not immediately reversible.

The system cannot explore by weakening a verifier, withholding required context, changing disclosure, or trying an unauthorized tool/effect.

Safety/eligibility support and statistical outcome overlap are distinct. Low overlap blocks OPE-based adoption but does not permanently prevent evidence collection. A separately preregistered, capped experiment may acquire support only over independently certified safe, immediately reversible actions, with a frozen positive probability floor, maximum exposure/influence, exact assignment/propensity logging, stopping/rollback rule, and all ordinary L10/L11/L14/K3/K4/cutover gates applicable to that domain. If those safety proofs or the certified exploration semantics are absent, epsilon remains zero and the deterministic baseline remains current. A cold-start negative/positive fixture MUST prove both halves: unsupported unsafe actions are never explored, while a certified safe experiment can acquire overlap without weakening any gate.

### 5.6 Update and adoption protocol

```text
Verified eligible Experience Envelopes
  -> frozen local batch and root grouping
  -> deterministic sufficient-statistic update
  -> immutable candidate Evidence-B snapshot
  -> invariant, replay, regression, and baseline-reset tests
  -> OPE when identifiable
  -> declared shadow comparisons
  -> L10 verification
  -> L11 consent/privacy/deletion revalidation
  -> L13 exact runtime-evidence candidate/read-set/adoption intent
  -> K3 invisible stage through the mapped runtime-state path
  -> L14 exact authorization of that candidate/read set
  -> complete incumbent K4 terminal-seal chain
  -> K3 expected-parent seal/activation of the current Evidence-B reference
  -> one certified router consumes Evidence-B under Policy-A or selects baseline/abstain
```

An update never mutates a snapshot in place and never commits a route. Training statistics and scoring projections are distinct. A candidate that loses currentness, consent, deletion, profile, or data eligibility before the runtime-state commit is rejected or rebuilt; it is not “mostly current.”

Changing any Policy-A semantic—including feature/action/update/selection/tie-break/epsilon/fallback/score-consumption, reward contract, isolation scope, influence cap, or scoring meaning—is a non-runtime policy change. It requires E0/E1 through E4, canary/E5, and separately sealed full `production.cutover`, not an ordinary Evidence-B batch.

### 5.7 OPE report

V1 OPE identifies only one intervention per causal root, or one frozen joint action at one exact intervention position followed by an identical frozen continuation policy in behavior and target arms. A trajectory with later adaptive decisions, policy-dependent termination, unmodeled censoring, or different continuation policies returns `notIdentifiable`. Future sequential OPE requires a separately approved trajectory contract with per-step behavior/target probabilities, state transitions, rewards, termination/censoring, sequential support, and an estimator such as sequential doubly robust or FQE with its own assumptions; contextual DM/IPS/SNIPS/DR cannot be relabeled as sequential evidence.

The target Evidence-B snapshot, target Policy-A, score projection, estimator, nuisance learner family/features/hyperparameters, fold rule, and fold seed are frozen before opening the evaluation root. Nuisance parameters follow exactly one legal path: they were fitted on a completely independent external nuisance root and frozen before access, or they are fitted after opening the root using only each declared training fold, with every scored block strictly out of fold and each fitted identity/data-root receipt recorded. Same-fold fit/score, full-root pretraining disguised as frozen nuisance state, or hidden access during learner selection invalidates OPE. Nested causal-root/App-Agent/time cross-fitting may evaluate the complete selection/training procedure, but that result is labeled `selectionProcedureEvidence`: its outer folds contain different policy identities and do not certify a later full-data refit. The exact production target still requires a fresh untouched root unless the deployed target is the byte-identical frozen fold ensemble and its probability kernel, composition, and identity are bound in the manifest. Selecting/refitting a target on an evaluation root and then reporting that root—or fold evidence for a different refit—as exact-target evidence is forbidden. Every sibling, repeated, or adaptively chosen OPE query consumes the same protected adaptive-evaluation budget; exhaustion returns `notIdentifiable` or requires a fresh independent root.

For a supported finite decision, the evaluation bundle reopens the exact `OPEEstimandManifest` and reports every preregistered required estimator and diagnostic. Its finite estimator set may include:

- direct method (DM);
- inverse propensity scoring (IPS);
- self-normalized IPS (SNIPS);
- doubly robust (DR);
- SWITCH or another preregistered bounded estimator;
- overlap/support by action and cohort;
- effective sample size;
- clipping threshold, estimated clipping-bias diagnostic, and the conservative clipping/truncation-bias upper bound for the original estimand, including its derivation method and assumptions;
- reported-estimand identity, exactly `originalTarget` when that auditable bound is incorporated or `clippedSensitivityOnly` when the result describes only the clipped/truncated sensitivity estimand;
- grouped confidence intervals by root causal unit;
- behavior-policy/assignment epochs and either frozen-epoch stratification or the exact adaptive/dependent collection estimator, history filtration, and anytime-valid confidence contract;
- sensitivity to missing/censored outcomes and model specification;
- every `RewardEvidenceVector` dimension with simultaneous one-sided bounds for correctness and hard-veto violation, plus the preregistered vector/Pareto non-inferiority result;
- one terminal status: `identifiable`, `weakSupport`, or `notIdentifiable`.

Clipping/truncation changes the estimand unless its bias is bounded. A hard-gate interval for the original target-policy estimand must incorporate an auditable conservative clipping/truncation-bias bound into its simultaneous confidence sequence. Otherwise the report is explicitly a clipped-estimand/sensitivity result and cannot clear a hard gate. Small post-clipping variance with large tail mass is `weakSupport` or `notIdentifiable`, never false safety.

No single estimator is certification/cutover truth. A scalar projection may summarize an allowed soft objective, but it can never compensate for or clear a hard correctness/safety/authority/privacy/effect gate. Disagreement, low support, unstable confidence intervals, failed simultaneous bounds, or absent vector dominance/non-inferiority require more data, a separately governed safe experiment, or baseline retention.

### 5.8 Shadow evidence

Shadow execution may prove:

- deterministic invariants and parser/ABI compatibility;
- replay parity on logged states;
- latency, energy, memory, token, and byte costs;
- baseline/candidate choice disagreement;
- verifier and regression outcomes on supported examples;
- fallback and recovery behavior.

Shadow execution cannot prove the unobserved real-world outcome of an action not taken. It cannot convert missing OPE support to truth, create user consent, or authorize production adoption.

Existing `BASABProtocolSpec`/A-B mechanisms, `BASCoreAIShadowComparison`, `BASShadowTrialCoordinator`, and Qinao Furnace seams MAY be reused as mechanisms only after their state and verdicts are subordinated to the canonical K3 lifecycle, `runtime.certification`, and `production.cutover`. Their existence is not evidence that production learning is already wired.

### 5.9 Certification and canary

The approved-planned W6 `runtime.certification` remains the sole owner of aggregate E0-E5 evidence and verdicts once created and gated. No current implementation is implied. Each candidate binds exact tests, fixtures, metrics, cohorts, environment, evidence roots, and toolchain identities. The certification owner consumes but does not invent training or cutover evidence.

Sequence is exact: `runtime.certification` closes E0-E4 before exposure; `production.cutover` creates the separately sealed canary Release/admission and deploys only that candidate tree to its preregistered cohort; delayed field evidence returns to `runtime.certification` for the E5 verdict; only then may `production.cutover` create a different, separately sealed full Release. E5 cannot precede canary, and one mutable rollout row cannot stand in for either Release.

Canary is a separate preregistered production experiment. Before exposure it freezes:

- baseline/candidate identities and cohort PRF;
- assignment unit, inclusion/exclusion, isolation unit, exposure/noncompliance definition, and exact assignment-versus-exposure logging;
- primary intention-to-treat estimand, with any per-protocol/exposure estimand explicitly secondary;
- primary metrics, guardrails, hard vetoes, and failure matrix;
- minimum detectable effect, sample-size or information target, and maximum duration;
- sequential testing/alpha-spending rule;
- sample-ratio-mismatch test; attrition/censoring/missing-outcome method; interference/spillover, carryover, and washout assumptions;
- cluster or switchback design where one App Agent is the population or ordinary individual randomization is invalid;
- one multiplicity family spanning primary, guardrail, subgroup, interim, and adaptive analyses;
- stopping, rollback, contamination, and late-result handling;
- user/privacy/region/device/profile eligibility.

Every stochastic hard guardrail separately binds its estimand, one-sided harm or non-inferiority margin, simultaneous/anytime-valid upper confidence bound, and information/power target. “No statistically significant harm” is not a pass: an underpowered or inconclusive guardrail retains baseline/rolls back and cannot satisfy E5. An observed deterministic or immediate hard-veto event triggers the synchronous fail-fast fence without waiting for statistical accumulation. The canary passes only when every required hard bound clears and the preregistered primary estimand satisfies its decision rule.

Certification, canary admission, canary result, and full cutover are separate immutable sealed joins. Passing one cannot imply the next.

### 5.10 Rollback and invalidation

Every decision domain retains:

- one deterministic built-in baseline;
- at most one current immutable Evidence-B reference under an already mapped runtime-state owner;
- at most one declared shadow candidate per admitted experiment slot;
- a clean parent chain and exact data/profile/deletion epochs.

Rollback performs a synchronous eligibility fence and, only through the mapped runtime-state commit protocol, changes the current Evidence-B reference to the exact clean parent or absence. Policy-A then selects its deterministic baseline. This is evidence-state rollback, not runtime-route cutover; it requires no model call and does not wait for asynchronous cleanup. Late outcomes and late trainer/shadow results remain inert after the fence.

Thermal or latency degradation may cause Policy-A to select its baseline without rewriting Evidence-B. Feature, model, tokenizer, template, OS, hardware, converter, context ABI, reward, privacy, or action-set drift invalidates the affected statistics and scoring projection. Silent reuse is prohibited.

### 5.11 Healthy Apple-silicon implementation

Use each technology where it is structurally strongest:

| Technology | Preferred role |
|---|---|
| Swift | Actor-safe orchestration, typed contracts, app lifecycle, policy presentation, and integration |
| Rust | Canonical encoding/hashing, fixed-point statistics, deterministic OPE/replay kernels, bounded parsers, lineage checks |
| SQLite/SQL | Existing K3 truth and rebuildable StateLake/experiment projections with strict transactions and indexes |
| C/C++ | Small verified numerical kernels or converter/runtime interop where ABI evidence requires it |
| Accelerate/BNNS | Non-authoritative vectorized batch projection/evaluation when measurement proves benefit |
| Metal/Core AI | Substantial model or batch inference/specialization workloads after profiling |

A tiny linear head should normally remain on CPU. Waking GPU/ANE, transferring buffers, compiling a graph, or holding accelerator residency for microsecond-scale scoring is counterproductive unless real device traces prove otherwise. No numeric accelerator result is authoritative until canonical replay verifies it.

## 6. External Trainer and Model Candidate Protocol

### 6.1 Disaggregate execution, training, and authority

The runtime, trainer, evaluator, certification owner, and cutover owner are separate trust domains:

```text
Qinao runtime / K3 source truth
  -> authorized immutable Dataset + Training Job manifests
  -> isolated trainer (untrusted computation)
  -> staged candidate package + training receipts
  -> independent reference evaluation and conversion parity
  -> runtime.certification E0-E4
  -> production.cutover sealed canary Release/deployment
  -> runtime.certification E5 from delayed field evidence
  -> production.cutover separately sealed full Release
```

Physical colocation does not collapse these boundaries. A trainer running on the user's Mac, a private server, or a vendor API still cannot read undeclared data or hidden-holdout membership/root material. Only a separately authorized candidate execution may see one minimum-necessary evaluator-materialized case under Section 6.11; that never grants the trainer or candidate persistence, lookup, or bulk access. Neither trainer nor candidate may alter K3, invoke production effects, sign its own certification, or install its output.

### 6.2 Training job manifest

Every external job consumes one immutable `TrainingJobManifest` semantic contract containing at least:

| Group | Required bindings |
|---|---|
| Job | Job identity, idempotency key, purpose, parent/retry lineage, submitter authorization, created/expiry epochs |
| Base | Exact architecture, base weights, adapter parent, tokenizer/processor, prompt/chat/tool template, context ABI, State ABI, and license |
| Data | Exact dataset-generation digest, trainer-visible train/allowed-validation materialization, sample weights, deletion/policy epochs, opaque hidden-root commitment, and proof that hidden membership/keys/bytes are absent |
| Objective | Algorithm, objective/reward projection, process/output targets, verifier contract, and forbidden optimization signals |
| Trainability | Exact trainable/frozen modules, adapter topology, rank/precision, optimizer, scheduler, regularization, clipping, and adaptation budget |
| Reproducibility | Seeds, framework/container/commit, compiler/converter versions, hardware topology, deterministic flags, and known nondeterminism |
| Lifecycle | Checkpoint interval, resume rules, max steps/time/energy/cost, early stop, cancellation, crash/query behavior, retention, and deletion |
| Security | Network policy, credentials class, sandbox, SBOM, dependency digests, encryption, destination, logging/redaction, and egress cap |
| Output | Allowed candidate classes, packaging schema, receipts, metrics, provenance, and rejection conditions |

A retry with the same idempotency key and byte-identical manifest reopens the same semantic job and its exact physical-effect receipts or terminal result. Different bytes under the same key are corruption. A resubmission after a material change is a new job, not a retry.

K3 owns only the approved semantic-job currentness, inert-candidate reference/fence status, and immutable receipt references; it does not own candidate quality, production currentness, or a Release. Once W5 creates and gates the planned Zone-C/`BASEffectBroker`, physical submit, query, cancel, and reconcile MUST use that sole path with an exact trainer effect profile and adapter capabilities. Zone C then owns physical dispatch/ack/indeterminate/reconcile; K3 must not record external actuator truth, and the broker must not write K3 semantic lifecycle. Before that path exists, or if its effect profile cannot represent a trainer operation, the operation remains disabled rather than creating `TrainerDispatcher`, `TrainingJobRunner`, or another journal.

### 6.3 Algorithm routing by evidence shape

The optimizer is selected from the dataset's honest evidence shape, not from fashion:

| Data/evidence shape | Candidate algorithm | Boundary |
|---|---|---|
| Independently verified demonstrations | Supervised fine-tuning (SFT) | Preserve anchors and regressions; no self-label promotion |
| Explicit pairwise preferences | DPO as the default preference baseline | Pair proves preference, not factual truth |
| Desirable/undesirable point feedback | KTO candidate | Requires calibrated class balance and user/source grouping |
| Pairwise preferences where preregistered robustness evidence favors IPO | IPO research candidate | Must beat DPO in that exact noise/model-shift regime; no universal robustness claim |
| Initial preference tuning without separate reference path | ORPO research candidate | Not a default release shortcut |
| Narrow deterministic reward domains | RLVR/GRPO-family candidate | Only where exact independent verification exists |
| Observable structured cognitive transitions | Process-supervised SFT/preference objective | No raw hidden chain of thought |
| Finite online decisions with propensities | Contextual bandit/OPE pipeline | Remains separate from generative weight training |

RLVR/GRPO-family training is restricted to domains such as compiler/test outcomes, exact SQL results, bounded math/solver problems, replayable tools, and exact structural formats. Even there, a public deterministic verifier proves only its `VerifierClaimContract` and may be gamed. Training and evaluation use independent verifier families, hidden/randomized seeds, isomorphic/metamorphic/property tests, adversarial anti-shortcut fixtures, and held-out task generators. Only proof/exhaustive coverage may label whole-task correctness; partial verifiers optimize and report their subclaim only. RLVR is prohibited for personality, open-ended companionship, subjective values, engagement, consent, safety authority, and unverifiable general chat.

The job manifest records why the selected algorithm is identifiable and appropriate. “Better benchmark score” cannot excuse an evidence-shape mismatch.

### 6.4 Thinking training boundary

Training targets may include typed observable cognitive actions: constraint extraction, evidence linking, tool selection, counterexample generation, sufficiency classification, uncertainty, and abstention. They must remain concise, externally inspectable, and independently scoreable.

The trainer MUST NOT request raw private chain of thought, infer it from hidden activations, reward verbosity as reasoning quality, or train on secrets embedded in tool traces. A model can learn a better public problem-solving protocol without Qinao claiming access to an internal mind.

### 6.5 API distillation and stronger models

A stronger API model may propose demonstrations, critiques, decompositions, synthetic cases, or weak labels only when:

- provider terms permit the exact use;
- source content is authorized for that destination and purpose;
- the API model identity/configuration and response provenance are captured;
- the proposal is isolated as synthetic/teacher-origin evidence;
- an independent verifier or human anchor determines acceptance;
- teacher output never becomes its own truth or certification.

The stronger API model receives the same authority ceiling as any local Provider. Intelligence changes proposal quality, not governance.

An API teacher/inference request is remote Provider egress, not corpus export. It MUST use the approved Provider order exactly. Value-only routing/preflight finishes; K3 allocates the branch and the allocation-receipt Artifact (`Provider-A`, unrelated to Policy-A) is ordinary-put/reopened, followed by request materialization M and any terminal-source pin T. L11 and L14 then decide the exact governed destination, payload, purpose, and disclosure class; K4 performs the matching one-shot authorization claim/use and returns its use receipt. The authorization claim/use is the first K4 operation and is not the later boundary anchor. While the Provider claim row is still absent, the governed Artifact path ordinary-puts/reopens the dormant `BASProviderEgressBoundaryPermit`; K3 egress-prepare atomically reopens Provider-A/M/[T], that permit, the K4 use receipt, Attempt/generations, and current policy/deletion epochs; K4 separately anchors the committed source root and its receipt is ordinary-put/reopened; then K3 arms the exact permit/anchor pair and its arm receipt is put/reopened. Incremental mode then opens its required zero-byte visibility gate. Only afterward may fresh K3 claim Q win, `beginProviderEgressHandoff` consume the fresh claim and arm, atomically move the pre-armed row to `sent_or_unknown`, and return the noncopyable remote-call permit consumed immediately by the sole `BASProviderAttemptExecutor.executeAtMostOnce`. Authenticated supervisor observation, event-head seal, and mode-specific visibility close follow the frozen contract. A lost/replayed/recovered handoff gets no call capability. Until that planned boundary is implemented/gated, the call is disabled. Corpus upload or remote fine-tuning job control instead uses the planned W5 Zone-C trainer-effect profile. Neither path may instantiate direct `URLSession`, a Provider-local retry/egress journal, or a generic transport escape hatch.

### 6.6 Trainer isolation

The trainer runs with:

- a short-lived, read-only, purpose-bound input grant;
- no access to hidden holdout or production K3 credentials;
- zero direct or ambient network in a local/Mac trainer sandbox; dependencies, base models, and tools are prefetched and injected as read-only digest-pinned inputs;
- no access to user secrets, unrelated App Agents, production effects, or host UI;
- output access only to an inert staging area;
- dependency lock, SBOM, model/package digests, and reproducible environment receipt;
- encrypted datasets/checkpoints and bounded redacted logs;
- independent cleanup and late-result fencing.

For a managed remote trainer, corpus/job bytes enter only through the exact authorized Zone-C transfer in Section 4.9; the Provider's internal network is not a Qinao sandbox capability and remains bounded by the provider contract, attestation, destination, and receipts. If a mechanism genuinely requires a callback, the broker—not trainer code—must construct a fixed non-corpus request whose bytes, headers, path, call count, and destination are preregistered and whose single egress receipt is governed; the trainer cannot select or encode any part of the call. Otherwise that mechanism is disabled. An allowlisted hostname alone never authorizes corpus bytes in body, path, headers, DNS labels, timing, or repeated-call patterns.

Each release candidate follows the algorithm-specific uncertainty, sensitivity, and replication plan frozen in its job manifest and Section 4.11's all-clean-ancestor retention contract. Seed count, deterministic replay, perturbations, resampling, and environment replication are chosen and justified for that algorithm; neither two seeds nor one nominally deterministic run is a universal sufficiency rule. Material instability, checkpoint divergence, unexplained loss spikes, or evaluator disagreement remains visible in the training receipt.

### 6.7 Complete candidate identity

A model candidate identity binds all behavior-affecting material, including:

- architecture and exact base/full weight digests;
- ordered adapter stack and merge recipe;
- training lineage and dataset roots;
- tokenizer, processor, vocabulary, normalization, and special tokens;
- system/chat/tool templates and context/State ABI;
- KV-cache format, attention implementation, context length, and position scaling;
- quantization/calibration data and per-layer precision;
- MTP/speculative decoding topology, draft identity, acceptance rule, and fallback;
- modality preprocessors, tool grammar, structured-output constraints, and stop rules;
- framework, runtime, converter, compiler, custom operations, and deployment package;
- OS/device/hardware cohorts and specialization artifacts;
- exact derived-artifact consumer scope, App-Agent/Workspace compartment, allowed purposes, and the intersection of source grants;
- memorization/extraction/membership-inference/cross-scope evaluation roots;
- privacy, license, provider-terms, export, deletion, unlearning class, and retention lineage.

Changing any behavior-affecting item creates a new candidate identity and invalidates inherited evidence not explicitly proven portable.

### 6.8 Qwen3.5 path

The target-default Qwen3.5-4B path, conditional on W6 full cutover, is:

```text
Authorized dataset generation
  -> isolated MLX or PyTorch training
  -> frozen adapter/full candidate in its training framework
  -> when trained in MLX, merge/export into a supported reference representation
     with per-tensor/numeric parity rather than assuming direct MLX conversion
  -> supported PyTorch export/coreai-torch conversion and Core AI compilation candidate
  -> reference-framework evaluation
  -> numeric and semantic parity
  -> quantization, tokenizer/template, tool, context, MTP, and fallback tests
  -> device-cohort specialization evidence
  -> E0-E4 certification
  -> sealed canary Release/deployment
  -> E5 field-evidence verdict
  -> separately sealed full cutover
```

Qwen's native MTP or another speculative path is a candidate execution mode, not an assumed speedup. Its exact draft/head topology, acceptance semantics, cache compatibility, quality delta, memory cost, thermal behavior, and fallback are separately measured and certified.

Core AI is the on-device inference/runtime substrate. PyTorch/coreai-torch and the pinned build toolchain perform supported export, conversion, optimization, and compilation; MLX or PyTorch may be used for external training. The repository's `coreai-torch 0.4.0` artifacts are denied historical mechanism evidence on iOS 27 beta 2 and later. Any Qwen/Core AI candidate requires compatible 0.4.1-or-newer reconversion plus full numeric, StateABI, device, cache, thermal, and recovery recertification; a historical `.aimodel` cannot enter W4 parity as a production-capable asset.

### 6.9 AFM path

On iOS 27, AFM is an external system Provider behind its supported Foundation Models interface. Qinao does not receive or own AFM base weights. The Foundation Models adapter-training toolkit documented for the previous generation is not treated as an iOS 27+ training route.

Qinao may learn and version AFM-specific:

- context compilation and prompt/template choices;
- tool schemas and routing;
- verifier/calibration profiles;
- capability and failure-mode manifests;
- non-authoritative AFM routing/calibration statistics under a separately certified finite policy definition;
- OS/device/profile performance evidence.

An OS, Foundation Models framework, model-behavior, tool/API, language-coverage, or availability change invalidates the affected AFM profile. There is no floating “Apple model” certification.

### 6.10 API Provider path

An API Provider profile binds provider, endpoint/model version, account/region/residency class, request template, tool/structured-output mode, context/token limits, pricing/cost epoch, retry/idempotency semantics, privacy/retention/training terms, and observed capability/performance cohort.

A fine-tuned endpoint is a new exact candidate. A provider alias such as `latest` may be resolved for discovery but cannot inherit production certification. If exact server-side weights are opaque, Qinao binds every observable version/configuration fact available and treats unexplained drift as profile invalidation.

Every API inference/teacher/fine-tuned-endpoint invocation still crosses the same approved remote Provider egress boundary described in Section 6.5. Creating or selecting an API profile never authorizes corpus upload, provider training use, or a second network stack.

### 6.11 Holdout, adaptation budget, and candidate return

Hidden holdout membership, roots, keys, lookup surfaces, and examples are physically and logically unavailable to the trainer, data generator, candidate prompt builder, and ordinary visible evaluator. A candidate execution sees only the one minimum-necessary case materialized by the independent evaluator, with no membership identity or persistence authority. The full dataset manifest may commit to a hidden split root, but the trainer-visible materialization contains only train/allowed-validation member IDs plus the opaque hidden-root commitment; it contains no hidden membership, key, lookup surface, examples, per-example metric, or metadata side channel.

Each hidden root is classified in the same governed `DatasetManifest` generation—only after W1 owner/schema convergence and gates—as either `localOnly` or `remoteEvalEligible(provider, destination, purpose, terms, consentEpoch)`. A remote API/fine-tuned endpoint may never receive a `localOnly` case. Its hidden evaluation uses a separate independent root containing only minimized non-private material explicitly authorized for that exact Provider, account/region, destination, evaluation purpose, bounded acceptable retention, `providerTrainingUse = denied`, and consent epoch. Every case invocation traverses the complete Remote Provider egress protocol in Section 6.5, records Provider exposure/retention, and uses a shorter preregistered rotation window. Provider/region/terms drift fences the root immediately. If training use cannot be denied or retention cannot be bounded acceptably, one exposure may at most produce a provider-exposed diagnostic; the root retires immediately and cannot supply hidden certification evidence. Even contractual denial is exposure evidence, not technical secrecy. TLS, PCC, or an assertion that the Provider “does not look” is not confidentiality evidence. Without an eligible authorized remote root, hidden evaluation for that API candidate is `unavailable` and certification cannot pass.

After creation/gating, the approved-planned W6 `runtime.certification` may submit an exact hidden-evaluation request; verdict ownership does not grant data access. L11 revalidates purpose/minimization, L14 makes the exact protected-use decision, K4 issue/reserve/claim authorizes an independent holdout evaluator through the incumbent Artifact-scope gateway, and K3 may retain only the exact use/budget/result references. The runner never returns raw membership, keys, examples, per-example results, or a lookup surface to certification; certification consumes only the sealed aggregate result.

The hidden evaluator launches a fresh isolated instance with no production tool/effect capability. A local candidate sandbox has zero network. A remote candidate evaluator has zero direct or ambient network; its sole outward call capability is the exact per-case noncopyable Remote Provider permit authorized by the preceding paragraph, and the result can flow only into the sealed aggregator. The evaluator may otherwise use only manifest-frozen hermetic deterministic simulator/replay tools with bounded case-local state; their typed receipts are explicitly `simulated` and can never masquerade as real external outcomes. Candidate package/import roots are read-only. KV/state/RNG and any case-local scratch reset at the preregistered case/episode boundary; no persistent cache, temporary file, shared specialization state, or cross-root mutable state survives. The only outward value is the sealed schema-bounded aggregate. Evaluation teardown destroys sandbox/cache/tmp material and emits an independently checked cleanup receipt. Any attempted external network/tool/effect escape, attempted write, state carryover, later reuse of evaluator state, or case-N information appearing at case N+1 invalidates the evaluation and rotates the affected holdout root.

The protected-use/access receipt described here is a design-candidate semantic that MUST map to an incumbent owner/schema and non-empty ExtensionGate. If that mapping or independent evaluator does not exist, hidden evaluation remains disabled. V1 gives each root one terminal sealed test of one exact candidate frozen before access, with no actionable intermediate feedback. The request binds candidate identity, operator, evaluator, metric set, cohort, root size, returned bits/thresholds, selection rule, query purpose, and the resulting finite information/error bound. Sibling-family winner selection cannot reuse that root; an adaptively selected winner requires a fresh independent confirmation root. A future reusable root must bind a separately approved reusable-holdout or differential-privacy/information mechanism with its sample-size-dependent generalization/error guarantee, accounting composition, and output contract; a finite query count alone is not a guarantee. Results remain coarse and minimum-necessary. Repeated threshold probing, per-example output, gradient-like feedback, sibling laundering, or unaccounted reuse is forbidden. Budget exhaustion or suspected leakage retires the root and invalidates affected evaluation; rotation cannot retroactively repair adaptive leakage. No holdout access ledger/manager is created.

Every candidate has an adaptation budget: maximum data generations, trainable parameters, steps, influence, domains, and acceptable regression envelope relative to its frozen parent. Budget exhaustion produces a terminal outcome, never an implicit extension.

Every byte returned by an external trainer—including candidate package, receipt, metric, log, checkpoint metadata, and evaluation output—is tainted derived material whose consumer scope/purpose is the intersection of the input grants. The frozen `TrainingJobManifest.Output` section—not a second grant or owner—binds two disjoint allowlisted classes, maximum bytes, and total information budget:

1. `modelArtifact`: one exact package/container and tensor inventory with names, shapes, dtypes, sizes, digests, parent lineage, and allowed checkpoint members. A package importer/parser plus SBOM, signature, parity, malware/executable-member, memorization, and extraction suites rejects an unknown tensor, extra file, executable/custom code outside the separately frozen candidate identity, malformed container, or digest/shape drift. Declared model bytes may be high entropy, but their inherited scope never widens.
2. `auxiliaryMetadata`: one canonical schema of aggregate numeric values, bounded enums, and digests that the importer independently recomputes over an admitted artifact or byte-equal matches to a manifest-precommitted digest, with exact field identities, dimensions, numeric precision/ranges, cardinality, and information budget. Opaque trainer-chosen digests/IDs are forbidden. The one exception is an authenticated provider-issued fine-tuned endpoint reference reopened from the sole Zone-C adapter/query receipt—not copied from trainer prose—and bound to exact provider, account, region, base/version, job, purpose, source-scope intersection, fixed character/length grammar, and fresh-query verification. It remains an inert candidate reference and cannot carry arbitrary text or authority. The independent importer rejects unknown fields, per-example values, raw/free-text payloads, gradients, activations, arbitrary/high-entropy blobs, excessive precision, steganographic encodings, or size/cardinality drift.

No trainer-authored field is trusted merely because it is signed or bounded, and neither class may smuggle members of the other.

The trainer returns only:

1. the inert candidate package/checkpoints allowed by the manifest;
2. a complete training receipt and lineage;
3. declared metrics and predeclared schema-bounded aggregate evaluation outputs admitted by the independent importer;
4. nondeterminism, incidents, exclusions, and cleanup state.

It never returns `approved`, `promoted`, `productionReady`, or a production path.

### 6.12 Crash and recovery

Recovery derives one typed aggregate from two non-overlapping owners:

- K3 semantic job currentness and references: prepared, fenced, expired, quarantined, or terminal-result-accepted;
- after W5 exists, Zone-C effect evidence: dispatch/ack/indeterminate/reconcile plus authenticated trainer observations such as running, checkpointed, cancelled, failed, or completed-staged.

No new row owns both. Recovery uses the exact job identity, manifest digest, effect branch/instance, checkpoint digest, environment identity, and source/deletion epochs.

An unknown external side effect is queried/reconciled, never blindly repeated. A checkpoint is resumable only when all bound material remains current. Late output after cancellation, deletion, policy revocation, expiry, or parent supersession is stored only as inert incident evidence or discarded according to policy; it cannot re-enter certification.

### 6.13 Existing `MLXLoRATrainer`

The repository's `MLXLoRATrainer` is an operator/developer scaffold, not an in-app production learning facade. Production convergence MUST remove any raw-corpus, arbitrary-path, implicit-network, or direct-load surface from app reachability. If retained, it becomes an isolated plugin behind exact manifests and staging receipts; otherwise it is fenced from the release closure.

As fixed in Section 6.8, the Core AI framework is the inference/runtime substrate; the pinned PyTorch/coreai-torch build toolchain owns supported export/conversion/compilation, while MLX or PyTorch may perform isolated external training. None is a Qinao production gradient-training authority.

## 7. RSI, Memory, Multi-Agent Contexts, and Thinking Discipline

### 7.1 Three time scales

Learning and reasoning operate at three explicitly separated time scales:

| Time scale | Mutable working state | Durable result |
|---|---|---|
| Attempt | Independent Main/Sub context windows, scratch artifacts, tool/effect state, budget, counterexamples | Terminal Attempt/work receipts; no direct long-term learning |
| Session and cross-session | Workspace DAG, current/day/week/month projections, provisional memory, user corrections, continuity | Cleaned memory/strategy candidates and exact recovery state |
| Release | Immutable dataset/Policy-A/model generations, certification and canary evidence | Immutable candidate generation or separately sealed production Release with rollback parent |

An Attempt may inform a later candidate; it cannot directly rewrite Session memory or release state.

### 7.2 Memory lanes and semantic hygiene

The StateLake keeps distinct semantic lanes for:

- facts and world claims;
- user preferences;
- relationship events and commitments;
- episodes and temporal sequences;
- procedural/task knowledge;
- failures, counterexamples, and lessons;
- calibration and capability observations;
- Stable Self/value candidates;
- adaptive companion-expression preferences.

These lanes may share infrastructure, but their eligibility, conflict, confirmation, retention, deletion, and authority rules remain separate. A style preference cannot become a fact; repeated facts cannot become values; task failure cannot become user identity; expression cannot change competence or safety.

Memory assimilation is:

```text
Source events
  -> normalization and data cleaning
  -> source independence and epistemic classification
  -> exact/semantic dedupe and conflict graph
  -> scratch | quarantine | provisional | confirmed candidate
  -> L10 domain-specific verification/confirmation
  -> L11 purpose/privacy/deletion/currentness revalidation
  -> L13 prepare + exact read-set
  -> K3 invisible stage for an authoritative runtime-state adoption
  -> L14 exact authorization + complete incumbent K4 terminal-seal chain
  -> K3 expected-parent seal/activation
  -> rebuildable current/day/week/month/archival projections
```

Scratch, quarantine, and rebuildable projections stop before the adoption chain. Every authoritative confirmed memory or Self runtime-state adoption uses the complete chain; “low risk” does not make K4 optional.

`current`, `day`, `week`, `month`, and `archival` are the exact temporal-horizon projections over source truth, not five stores. They record exact coverage, omissions, policy/deletion epochs, and rebuild lineage.

### 7.3 Query results cannot self-populate memory

Retrieval, RAG, model output, summaries, and context capsules are evidence proposals. They cannot append themselves to governed memory merely because they were selected or repeated. The existing L8 query/self-pop path must be removed from production reachability or converted into an explicitly non-authoritative scratch cache with negative gates.

An item enters memory only from an eligible source event through the assimilation path above. A later retrieval references the source/memory artifact; it does not generate a new corroborating source.

### 7.4 Independent context windows

Each Main and Sub Agent receives an independent `BASContextCapsule`-class target projection compiled for its exact role, Provider capability, context limit, privacy scope, and budget. Contexts are not string slices of a single shared transcript and do not share Provider KV state across identities or Providers.

The retrieval input may combine exact/grep, FTS/BM25, dense semantic, temporal/episode, and entity/relation lanes through the governed State Market. A small embedding, reranking, or grounding model—including a future Granite-class role—remains a K2 proposal producer with an exact profile and calibration evidence; it cannot assign truth, eligibility, authority, or memory status.

The capsule binds:

- App Agent/Session/Main/Sub/Attempt/WorkUnit identities;
- objective and finite output contract;
- constitutional minimum and authority ceiling;
- exact StateLake snapshot/high-water mark and evidence references;
- budget, context geometry, omissions, compression provenance, and uncertainty;
- tool/provider/capability boundaries;
- parent request and expected result binding;
- expiry, currentness, and revocation.

Models with different context sizes, modalities, tokenizer behavior, tool support, reasoning controls, latency, and cost receive different compiled capsules. The task semantics remain stable; materialization adapts to the selected Provider profile.

### 7.5 Typed agent communication

Main/Sub communication uses bounded typed artifacts, never shared mutable thought:

```text
Delegation request
  = role + question + evidence refs + constraints + budget
  + output schema + uncertainty contract + completion condition

Delegation result
  = request binding + findings + evidence refs + coverage
  + conflicts + counterexamples + uncertainty + terminal state
```

The Main Agent synthesizes results under evidence/authority rules. It does not majority-vote Agents as independent truth. Correlated Agents sharing model family, prompt, data root, retrieval source, or evaluator are marked as correlated, and their agreement cannot masquerade as independent confirmation.

Agents have no direct peer-to-peer channel and no shared mutable scratch/state. Every message is brokered through the frozen semantic DAG and one bounded canonical request/result schema with exact sender, recipient, causal parent, purpose, maximum bytes, bounded field cardinality, and low-entropy reason enums. High-risk roles cannot relay unconstrained free text, executable instructions, secrets, tool capabilities, or opaque embeddings to one another. Timing, ordering gaps, cache hits, and response length are not semantic fields; high-risk workflows use a frozen channel budget with coarse/fixed timing and size buckets. If that budget/padding cannot be enforced, those roles cannot share the high-risk coalition and the branch fails closed. Each role receives least-privilege tool/network capability, and an independent verifier outside the candidate coalition checks the claimed result. Adversarial fixtures cover collusive agreement, steganographic/covert channels, prompt relay, shared-cache signaling, timing/length signaling, cyclic delegation, and attempts to smuggle authority through a typed field.

Low-latency cooperation reuses immutable evidence/materializations by digest rather than copying private context. One authorized StateLake result or deterministic encoding may be referenced by several role capsules only when each role independently passes disclosure and currentness. Cache keys bind App Agent/Workspace scope, snapshot, Provider/tokenizer/template/context ABI, policy/deletion epochs, and materialization identity. Provider KV state and mutable scratch are never shared across Agent or Provider identities.

Credit attaches to exact used contributions and verifier receipts. It is not averaged by role and does not automatically reward the Main for all Sub work or the final speaker for synthesis.

### 7.6 RSI cycle

RSI here means bounded recursive self-improvement of the current solution process, not unconstrained self-modifying code or authority. Each immutable cycle is:

```text
Observe current task/evidence/state
  -> Diagnose exact gap or failure class
  -> Propose one bounded strategy delta
  -> Predict measurable progress and risk
  -> Execute inside current grant/budget
  -> Verify against independent evidence
  -> Compare lexicographic potential
  -> continue | remand | abstain | terminate
```

Every cycle binds an exact parent, Attempt/generation, budget lease/use, strategy identity, evidence set, progress witness, known-issue-set digest, and terminal receipt. A cycle cannot erase an earlier contradiction or relabel failure as success.

The four-ring mapping is:

- `ΩR`: budget, thermal, time, branch, hop, and remand admission;
- `ΩG`: evidence completeness, conflict, grounding, and source independence;
- `ΩD`: decomposition, hypothesis, counterexample, strategy selection, and verification plan;
- `ΩE`: candidate preparation, authorized state/effect, outcome observation, and lesson proposal.

### 7.7 Honest progress and anti-overthinking

Progress may be claimed only by a typed monotonic witness such as:

- increased required-evidence coverage;
- satisfaction of a previously unsatisfied hard constraint;
- resolution or explicit isolation of a conflict;
- discovery/closure of a counterexample class;
- reduction of an exact unresolved WorkUnit set;
- new independent verifier/tool/effect receipt;
- completed recovery/reconciliation state;
- reduced resource cost without losing required quality.

Longer prose, a new random sample, higher model confidence, repeated conclusions, rephrasing, or self-agreement are not progress.

Once the approved-planned W1 `runtime.semantic-dag` is created/gated, it freezes the potential contract; only after the converging W6 `runtime.semantic-executor` adaptation of incumbent `BASNativeStageExecutor` passes its convergence/source gates may its bounded mechanical executor evaluate that contract in production. Before those gates, this is fixture/shadow behavior, and no `DeliberationController` is created. The potential is, for example:

```text
(hard violations,
 missing required evidence,
 unresolved contradictions,
 uncovered counterexample classes,
 unresolved WorkUnits,
 uncertainty requiring action,
 remaining cost)
```

The first six components must not worsen merely to reduce cost. Re-entering an equivalent abstract state with the same strategy is cycle detection. The next step must change strategy, obtain new evidence, narrow scope, ask the user, abstain, or terminate. Remand rounds, hops, branches, tokens, bytes, time, and cost are bounded. Only a converged, independently verified candidate with the required K3/authority receipts is adoptable.

Terminal state and termination reason are separate closed enums. The semantic state set is exactly:

- `converged`;
- `degradedWithCoverage`;
- `deferred`;
- `rejected`;
- `needsConfirmation`;
- `indeterminateNeedsReconciliation`.

The semantic reason set is exactly `convergedVerified`, `coverageBound`, `resourceDeferred`, `policyRejected`, `confirmationRequired`, `cycleDetected`, `budgetExhausted`, `noProgress`, `staleEpoch`, `illegalRemand`, and `effectReconciliationIndeterminate`. Cycle, budget, and progress outcomes are reasons, not extra terminal states. Only the validated `converged + convergedVerified` pair with its committed K3 budget-use receipt may feed adoption; every other valid pair remains proposal/remand/disclosure evidence.

There is a controlled-document encoding conflict that W0/W1 MUST close atomically. Repository code and the later 2026-07-19 RSI specialization freeze hyphenated raw values such as `degraded-with-coverage`, `needs-confirmation`, `indeterminate-needs-reconciliation`, `cycle-detected`, `budget-exhausted`, and `no-progress`; the earlier Contracts target text incorrectly specifies underscore forms for several states. Preserve the existing hyphenated wire with no migration and atomically correct Contracts plus its current/backward/future fixtures and tests. This design adds no seventh state.

### 7.8 Task-specific cognitive protocols

One generic “think harder” prompt is prohibited. L6 emits the typed task classification; once their respective gates pass, the approved-planned W1 `runtime.semantic-dag` mapping selects a bounded protocol and the converged/source-gated W6 `runtime.semantic-executor` adaptation mechanically instantiates its work products through the incumbent executor seams. Before then the path is fixture/shadow-only, and no separate cognitive router is created:

| Task class | Required work products |
|---|---|
| Multi-constraint logic/sorting | Entities, domains, constraints, propagation table/solver result, complete assignment, contradiction and uniqueness checks |
| Long-text extraction/transformation | Source map, span/section references, requested schema, coverage matrix, transformation lineage, omission/conflict report |
| Turtle soup/abductive mystery | Observations, hypothesis set, discriminating questions, answer constraints, falsification, unresolved alternatives |
| Strongly leading subjective prompt | Claim/evidence/value separation, user premise audit, alternative framings, uncertainty, non-manipulative answer |
| Tool/effect task | Preconditions, exact state, idempotency/effect protocol, execution receipt, postcondition, unknown/reconcile path |
| Code/math/SQL | Executable artifact, compiler/test/solver/query receipt, counterexample/regression, environment identity |
| Insufficient information | Missing prerequisite list, acquisition cost/risk, safe partial result, clarification or abstention |

Small models receive more structure, narrower WorkUnits, stronger deterministic checks, and smaller independent contexts. Larger local/API models may receive broader synthesis work, but never fewer authority or evidence requirements.

### 7.9 Learning from repeated challenge

When a user challenges an answer, each challenge is a new Input Event. The system does not merely increase confidence or restate. It classifies the failure:

- missing prerequisite;
- misunderstood intent;
- retrieval miss or stale evidence;
- reasoning/constraint error;
- tool/effect uncertainty;
- context omission/compression error;
- Provider capability mismatch;
- verifier gap;
- presentation misunderstanding;
- genuinely unresolved disagreement.

A reproducible lesson becomes only a candidate after independent evidence and cross-case support. A user challenge is strong evidence of dissatisfaction or a possible error, not automatic proof that the user's factual alternative is correct.

### 7.10 Session interruption and recovery

Recovery resumes from Qinao-owned Workspace/DAG state and immutable receipts, not from a transcript illusion, Provider session, KV cache, or regenerated chain of thought.

The recovery capsule binds:

- selected App Agent and logical Main identity;
- fenced predecessor and successor execution generation;
- exact Attempt/WorkUnit/DAG statuses;
- state snapshot/high-water mark and context-compiler inputs;
- completed tool/effect/provider receipts;
- pending, sent-or-unknown, reconcile, and terminal branches;
- budgets, deadlines, current policy/deletion/authorization epochs;
- unanswered user-input requirements;
- last verified progress witness and known-issue-set digest.

Pure computation may be replayed idempotently. An external side effect in unknown state must be queried or reconciled; it is never repeated because “the session stopped.” A late predecessor cannot publish, commit, contribute learning data, or alter progress after the generation fence.

### 7.11 Three Self tiers

The App Agent preserves three non-interchangeable tiers:

1. **immutable constitutional core** — product/system safety and authority invariants, never learned from interaction;
2. **stable Self** — user-approved values, commitments, long-term relationship posture, and identity continuity under the explicit confirmation protocol;
3. **adaptive expression** — reversible tone, structure, humor, vocabulary, initiative cadence, and presentation preferences.

An expression preset may make the companion sound shy, silly, terse, playful, or use a user-approved catchphrase. It cannot reduce factual accuracy, omit uncertainty, weaken verification, manipulate dependence, counterfeit incapacity, or change authority. The verified semantic answer first becomes an immutable typed payload. Expression rendering may deterministically map only allowlisted tone/structure slots; it cannot alter claims, polarity/negation, evidence, numbers, citations, uncertainty, safety/risk qualifications, actions, or tool/effect state. The final rendering must pass exact field/byte preservation where applicable and a post-render semantic-equivalence check; failure falls back to the unstyled verified baseline. Pre-render verification alone is never sufficient for a free-text/model rewrite.

Each App Agent has isolated private Self, memory, and relationship lineages. Shared user-owned data is read through exact releases and remains immutable to other App Agents. One Session selects exactly one App Agent and one logical Main Agent; bounded Sub Agents do not become alternate App Agents.

## 8. Learning-Plane Threat Model and Repair

### 8.1 Scope and assets

This threat model covers experience ingress, reward evidence, memory assimilation, Evidence-B sufficient-statistics updates and certified Policy-A scoring, dataset curation/export, trainer execution, candidate import, evaluation, certification, cutover, and rollback. It does not replace the repository-wide threat model; it supplies learning-specific requirements for controlled convergence.

Protected assets include:

- authoritative EventLog/K3 state and exact current heads;
- App-Agent identity, Stable Self, relationship, private memory, and consent;
- user content, credentials, PII, deletion rights, and purpose restrictions;
- experience, reward, dataset, trainer, model, evaluation, and release lineage;
- hidden holdout, verifier integrity, behavior-policy propensities, and canary assignment;
- model/adapter packages, tokenizer/templates, converter/custom operations, and SBOM;
- effect at-most-once/possible-start/indeterminate state, recovery rows, grants, attestations, and audit evidence;
- availability, thermal/memory safety, latency, and deterministic fallback.

### 8.2 Trust boundaries and input classes

The system treats the following as separate untrusted or partially trusted input classes:

1. user text, files, corrections, preferences, and authorization gestures;
2. retrieved local/remote documents, Web/API content, tool results, and imported memories;
3. local/API Main and Sub Provider output, including judges and synthetic-data generators;
4. trainer software, dependencies, checkpoints, packages, converters, and candidate models;
5. analytics/performance observations and delayed external outcomes;
6. operator input such as dataset selection, rollout action, exception handling, and incident recovery;
7. developer input such as code, schemas, fixtures, feature definitions, objectives, prompts, and evaluator logic.

Operator and developer inputs are not model inputs and must not hide behind “human approved.” Each requires authenticated identity, exact change/artifact binding, least privilege, separation of duties, audit, and rollback. A user can authorize use of their data but cannot waive core authority integrity. A developer can define a mechanism but cannot certify the candidate produced by an undisclosed change.

Primary trust boundaries are:

- UI/presentation to normalized Input Event;
- Provider/tool/retrieval content to deterministic SDK;
- source truth to rebuildable StateLake/feature/dataset projections;
- local device to any network destination;
- Qinao runtime to trainer sandbox;
- trainer staging to candidate import;
- candidate/evaluator to hidden holdout and certification;
- certification to production cutover;
- App-Agent private scopes and user-owned shared Workspace;
- K1/K2/K3 to K4 protected grant use.

### 8.3 Threats and mandatory controls

| Threat | Example path | Mandatory prevention/detection | Fail-closed result |
|---|---|---|---|
| Prompt/data injection | Retrieved page asks the system to export memory or label itself correct | Content/data separation, typed parsing, tool/purpose allowlist, source independence, injection fixtures | Quarantine source/derived candidate; ordinary answer may continue only from clean evidence |
| Memory poisoning | Repeated model claim enters L8 as a “fact” | No query self-pop, eligible source events only, conflict graph, provenance, independent verification | Candidate stays scratch/quarantine/provisional |
| Self-corroboration | Output -> ticket -> shadow replay -> success | Root-lineage correlation, generator/evaluator separation, output not world evidence | Reject learning evidence; incident marker |
| Reward hacking | Verbosity, engagement, or easy verifier gaming raises score | Vector reward, hard vetoes, anchors, counterexamples, outcome audit, no engagement objective | Candidate fails eligibility/certification |
| Evaluator tampering | Candidate prompt or developer change modifies judge | Frozen evaluator package/config, SBOM, hidden holdout, separation of duties, parity fixtures | Certification invalidated; no canary |
| Multi-Agent collusion/correlation | Same base model in several roles agrees | Model/data/prompt/root correlation labels; direct receipts; no majority truth | Agreement counted as one correlated source |
| Multi-Agent covert channel | Agents collude through free text, shared scratch/cache, timing, length, tools, or a permissive typed field | No peer channel/shared mutable state; bounded canonical low-entropy envelopes; fixed/coarse timing-size buckets for high risk; least-privilege tools/network; independent verifier; adversarial steganography/relay fixtures | Reject message/result and DAG branch; quarantine evidence and raise an incident |
| Dataset poisoning | Malicious examples/backdoor trigger dominate | Source caps, influence functions/leave-group-out diagnostics, trigger scans, anchors, rare-case sampling | Dataset generation quarantined |
| Split/holdout leakage | Augmented sibling enters train and eval | Split-before-derive, causal/near-dup groups, hidden holdout isolation, access audit | Evaluation invalidated; regenerate splits |
| Training bypass | Trainer loads arbitrary corpus or output directly | Exact manifests/grants, sandbox, staging-only output, import validation | Job/candidate quarantined |
| Model backdoor | Trigger survives aggregate benchmarks | Trigger/adversarial suites, differential behavior, activation/package scans where supported, canary guardrails | Candidate rejected or synchronously rolled back |
| Cross-App-Agent leak | Shared cache/index or memorizing adapter/model exposes private memory | Exact source/derived-artifact scope intersection, model/profile selection gate, scoped cache keys, extraction/membership tests, release envelopes | Fence projection/cache/model candidate; incident, rollback, and honest unlearning/retirement |
| Egress bypass | Logs, crash report, analytics, prompt, or trainer stdout leak data | Closed egress-kind classification: corpus/trainer transfer uses only the Zone-C effect profile; remote Provider request uses only the Provider-egress boundary; sink inventory, redaction, network deny-by-default, and byte/destination caps forbid alternate channels | Block sink/transfer; exact reconcile if unknown |
| Replay/rollback attack | Old head, consent, model, or grant becomes current | Generation/epoch/currentness binding, expected-parent CAS, monotonic floors, anti-rollback receipts | Reject replay; retain current clean head |
| Deletion failure | Deleted sample persists in job/checkpoint/model | Synchronous descendant fence, lifecycle index, cleanup receipts, honest unlearning class | Stop training/adoption; retire/retrain candidate where required |
| Supply-chain compromise | Converter/custom op/dependency alters model | Lockfile, SBOM, signatures/digests, reproducible conversion, isolated build, parity | Package cannot enter certification |
| Resource denial | Learning work heats device or evicts runtime | K1 envelope, off-hot-path batching, cancellation, strict quotas, deterministic baseline | Stop/defer learning; preserve user task |
| Propensity fraud | Logger fabricates probability after outcome | Behavior policy frozen before exposure, deterministic recomputation, signed event order | OPE `notIdentifiable`; no OPE-based adoption |
| Consent spoofing | UI gesture reused for another purpose/destination | L11/L14 exact current authorization, payload digest, expiry, domain-separated K4 grant | Export denied |
| Unknown external effect replay | Interrupted job/tool is blindly repeated | At-most-once command, query/reconcile, sent-or-unknown state | No retry until exact reconciliation |

### 8.4 Presentation-to-learning firewall

The single checked-in typed `PresentationReverseInfluenceManifest` already required by the App-Agent specialization remains the closed inventory. It has one row for every canonical presentation field and every direct/transitive sink, declaring whether that path is retired, forward-only audit, or an exact scope/envelope-bound untrusted observation eligible for the seven cleaning passes. This design does not create one manifest per L12 event or a second reverse-influence owner. Default is no learning influence.

Examples:

- explicit “this fact is wrong” may create a correction event, not immediate truth;
- explicit pairwise candidate selection may create a scoped preference pair;
- “undo this action” may update task/effect outcome;
- a click, scroll, dwell, emoji, silence, or notification open has no reward meaning;
- companion-style feedback may propose an adaptive-expression change, never competence or Stable Self.

That one manifest is enforced across Adapter/Input Normalizer, L6, and the L7 eligibility boundary with exact digest/cardinality and negative mutations. Comments and naming conventions are insufficient.

### 8.5 Poisoning and influence analysis

Before a dataset, Evidence-B, Policy-A, or model candidate proceeds, diagnostics report:

- per-source/root/App-Agent contribution and cap utilization;
- exact/semantic duplicate clusters;
- leave-one-root/source/group-out metric changes;
- feature/action influence and update norm;
- rare trigger/co-occurrence patterns;
- label/reward disagreement and judge correlation;
- temporal and cohort concentration;
- deleted/revoked/stale descendant count;
- anchor and regression displacement.

Diagnostics do not themselves authorize removal or promotion. They produce bounded evidence for L7/L10 and incident review. A suspicious group is quarantined with descendants and can later be exonerated through exact replay.

### 8.6 Evidence-B sufficient-statistics and certified Policy-A scoring integrity

For each decision domain, gates freeze and verify the separately certified Policy-A definition and each immutable Evidence-B snapshot:

- exact owner-defined feature list and sensitivity class;
- exact finite action set and safe subset;
- feature range/missing/overflow behavior;
- fixed-point scale, order, regularization, clipping, and influence cap;
- behavior-policy recomputation and propensity parity;
- App-Agent/Profile/domain isolation;
- baseline reset and rollback parent;
- no permission/risk/effect/Stable-Self output;
- no raw content or identifying feature path.

Malformed or stale input cannot fall through to a candidate score. It selects the deterministic baseline and records a bounded incident/coverage signal.

### 8.7 Model and supply-chain integrity

Candidate import reopens and verifies every package member, digest, signature, license, SBOM, training receipt, converter/custom-op identity, tokenizer/template, quantization calibration, and deployment profile. Reference and converted runtimes run fixed parity suites before any device shadow.

Unsigned, partially downloaded, dynamically code-loaded, runtime-modified, or dependency-drifted material remains inert. Download completion is not installation; installation is not certification; certification is not canary; canary is not full cutover.

### 8.8 Contamination recovery

When a source, transform, evaluator, feature, dataset, trainer, or model is found contaminated:

```text
Detection and exact affected-root calculation
  -> L14 emits the exact revocation/admission decision when required
  -> the mapped owner applies an atomic K3 eligibility/invalidation CAS,
     or production.cutover applies the non-runtime exposure fence
  -> synchronous retrieval/training/export/adoption block
  -> asynchronous descendant scan and physical cleanup
  -> runtime-state/memory/Evidence-B rollback through its mapped K3 commit path
  -> non-runtime Policy-A/model rollback only by production.cutover deploying
     a separately certified clean tree/Release
  -> rebuild projections and replay clean evidence
  -> expose uncertainty, coverage loss, and unresolved external copies
```

Semantic contamination, privacy deletion, and model rollback are distinct lifecycles. One may trigger another, but their receipts and completion criteria cannot be conflated.

Self-repair MAY:

- rebuild a projection, cache, index, or specialization from authoritative sources;
- recompute canonical statistics from eligible experiences;
- reopen exact committed rows/artifacts and resume an idempotent job;
- request a mapped runtime-state rollback or a `production.cutover` deployment of a separately certified clean tree;
- quarantine a candidate and request reconciliation.

Self-repair MUST NOT:

- invent a missing event, receipt, propensity, consent, or effect result;
- guess that an unknown external effect did or did not occur;
- rewrite immutable history;
- silently discard contradictory evidence;
- certify, canary, or promote its own repair candidate.

### 8.9 Failure matrix

Each failure class has one canonical safe outcome:

| Failure class | Canonical outcome |
|---|---|
| Missing/malformed feature | Deterministic baseline; candidate not scored |
| Unknown propensity/no overlap | OPE `notIdentifiable`; no OPE claim |
| Stale consent/deletion/profile/head | Synchronous eligibility fence |
| Corrupted manifest/artifact/receipt | Quarantine and corruption incident |
| Trainer crash before known terminal | Query exact job; no duplicate job/effect |
| External transfer/effect unknown | `.indeterminateNeedsReconciliation` with the existing hyphenated wire; no blind retry |
| Candidate/evaluator correlation violation | Evaluation invalid; independent rerun required |
| Holdout leak | Candidate evaluation invalid; holdout/split rotation |
| Canary hard-veto breach | Synchronously fence further exposure; K3 rolls back only mapped runtime evidence/state, while `production.cutover` deploys a separately certified clean Policy-A/model tree—never a hidden route flip |
| Thermal/memory pressure | Cancel/defer learning; baseline user path continues |
| K3/K4 unavailable | No adoption/export/effect; read-only/degraded response where safe |
| Deletion cannot meet promised semantics | Block data class or retire/retrain affected candidate |

### 8.10 Severity calibration

- **Critical:** unauthorized authority/state/effect/egress, cross-App-Agent private leak, direct production loading, hidden-holdout compromise affecting release, deletion-right violation with active use, or irrecoverable source-truth corruption.
- **High:** contamination reaching deployed Policy-A/model material or current Evidence-B/memory state, backdoor, fabricated propensity/evidence, repeated effect risk, or certification/cutover bypass with a clean rollback available.
- **Medium:** bounded non-production candidate/evaluation corruption, stale projection, local resource exhaustion, or reversible incorrect adaptation without protected-data exposure.
- **Low:** documentation/observability defect that cannot change behavior but can mislead an operator and therefore requires closure before relying on the evidence.

Severity never replaces the canonical fail-closed response.

## 9. Verification, Waves, and Completion

### 9.1 Non-vacuous gate doctrine

Every executable gate MUST obey all of the following:

1. assert every named path, target, fixture, manifest, and checker exists before scanning or executing it;
2. pass an explicit non-empty manifest document/record for every active wave and candidate class: `present` requires a non-empty entry set and exact count, while reviewed `notApplicable` requires exactly zero entries plus a closed typed reason; Create, Extension, shape/fixture, and source-boundary classes cannot satisfy one another;
3. fail when a test filter discovers zero tests, even if the test runner exits zero;
4. separate test discovery from execution and record both counts;
5. require exact positive and negative match counts where cardinality is part of the invariant;
6. run at least one controlled negative mutation proving the gate detects the forbidden state;
7. distinguish `rg`/scanner exit 1 (no match where allowed) from exit 2 (error); an error never passes;
8. require a glob to expand to a non-empty reviewed set before its results can pass;
9. run checker unit tests in CI using declared available tooling, not a developer-only environment;
10. record the exact command, candidate tree/commit, tool version, discovered target/tests, match set, and negative-control result.

These rules apply to owner, schema, LayerCore, iOS floor, source-boundary, forbidden-pattern, filter, fixture, package, model, dataset, privacy, supply-chain, and performance gates. A green command with an empty candidate set, missing file, unmatched filter, or skipped checker is a red architecture result.

### 9.2 Validation matrix

| Domain | Required positive evidence | Required negative/adversarial evidence |
|---|---|---|
| Owner/authority | Exact owner/reuse-create manifest and ledger closure | New parallel owner/store/manager fails |
| Experience | Canonical round-trip, lineage, late outcome append | Output self-proof, missing source, cross-scope parent fail |
| Reward/credit | Vector ordering/vetoes plus exact status-to-allowed-use matrix | Engagement reward, correlated vote, unknown-as-zero, or `diagnosticAssociation` with nonzero optimization weight fails |
| Dataset | Split/manifest reproducibility, purpose eligibility, and indivisible later-split/purge handling for duplicate or ancestry components spanning a temporal cutoff | Near-dup leakage, cross-cutoff component split, future-label grouping, poison, or stale consent/deletion fails |
| Corpus/trainer export | Exact L11/current-user authorization; L13 causal predecessor/request/branch/outbox/read-set preparation; K3 prepare/enqueue; L14 exact branch/destination/purpose/payload authorization; K4 issue/reserve; K3 handoff; Zone-C `dispatch_pending`; K4 claim/use; Zone-C `dispatch_ready`; K3 `effect_permit_pending`; K4 anchor; K3 arm; Zone-C `dispatch_ready -> dispatch_boundary_armed` winner; adapter observation/reconcile/terminal receipt; and K3 closure | Missing/swapped L13/K3/L14 binding, claim before `dispatch_pending`, ready before claim, logs/analytics/wrong destination/purpose, missing arm/anchor/use, second CAS winner, alternate transport, or blind replay fails |
| Remote Provider egress | Exact Provider-A/M/[T], L11/L14 decision, first K4 one-shot use, governed permit put/reopen, K3 prepare, distinct K4 anchor receipt put/reopen, K3 arm receipt put/reopen, incremental zero-byte visibility open when required, fresh Q/noncopyable handoff, authenticated observation/seal, and mode-specific visibility close | Direct `URLSession`, wrong descriptor/materialization/use/permit/arm, missing visibility open/close, lost-reply or recovery resend, redirects, and Provider-local retry journal fail |
| Policy-A/Evidence-B | Fixed-point replay, propensity parity, baseline/reset, terminal/freeze-point matrix | NaN/overflow/raw feature/action expansion, terminal reopen, or Evidence-B-carried action/epsilon/tie-break fails |
| OPE | Frozen exact target/eval roots; nuisance learner/fold rule frozen pre-access with external-root fit or strict fold-specific OOF receipts; `selectionProcedureEvidence` separated from a fresh exact-target root or byte-identical fold ensemble; adaptive-valid/frozen-epoch estimator; clipping-bias-aware vector simultaneous bounds; support/ESS/query accounting | Same-fold fit/score, full-root nuisance leakage, full-data refit/fold-identity mismatch, unknown propensity/no overlap, sequential-contextual mismatch, naive pooled drift, large clipped tail with small variance, scalar hard-gate compensation, or budget exhaustion returns `weakSupport`/`notIdentifiable`/fails |
| Shadow | Replay/invariant/cost/disagreement evidence | Shadow cannot claim unobserved outcome |
| Trainer/holdout | Manifest/idempotency/checkpoint/staging/SBOM plus independently imported model artifact/aggregate metadata, authenticated Zone-C endpoint receipt, one frozen candidate/one terminal root use, fresh-winner confirmation root, isolated cleanup receipt, hermetic simulated-tool receipts, and remote-root/Provider exposure evidence when applicable | Network/holdout/credential/direct-load, allowlisted-host exfiltration via body/path/header/DNS/timing/call pattern, sibling/adaptive winner reusing root, unknown tensor/member/field, high-entropy/per-example/free-text metadata, encoded-secret/output smuggling, forged/cross-account/stale/rebound endpoint, stateful case-N→N+1 leakage, sandbox escape/real effect, post-evaluation state reuse, local-private holdout sent to API, wrong provider/region, or terms drift fails |
| Continual retention | All-clean-ancestor matrix with permanent constitutional/hard-zero/authority/privacy/safety/effect invariants plus per-cell estimand/margin/info target and family-wide simultaneous/anytime bounds | Candidate/job attempts to retire an invariant, parent-only coverage, retirement without sole-owner migration/replacement, required inconclusive cell, or uncorrected ancestor × domain × cohort × interim multiplicity fails |
| Model conversion | Reference parity, quantization/tool/context/MTP fallback | Tokenizer/template/custom-op/package drift fail |
| Memory/Self/expression | Lane-specific conflict/confirmation/currentness plus immutable semantic-payload and post-render preservation/equivalence | Query self-pop, expression-to-Self, cross-Agent leak, removed negation/uncertainty, changed number/citation/risk qualifier, or semantic rewrite fails and falls back unstyled |
| Multi-Agent/RSI | Request-result binding, credit, cycle stop, independent verifier, bounded-envelope/least-privilege evidence | Majority self-proof, same-state same-strategy loop, free-text relay, shared mutable state/cache, timing/size covert channel, or typed-field steganography fails |
| Recovery | Crash-point replay/query/reconcile and generation fence | Unknown effect resend and late predecessor fail |
| Canary/E5 | Reopen the exact complete preregistered canary manifest and byte-bind every frozen field in Section 5.9 to assignment, exposure, result, and E5 receipts; then verify ITT, SRM, attrition/censoring/missingness, interference/carryover/washout, required cluster/switchback design, one multiplicity family with interim/adaptive alpha spending, and per-hard-guardrail one-sided simultaneous/anytime bounds with declared information targets | Candidate/baseline, cohort/PRF, filter, isolation, metric/veto, MDE/information, maximum-duration, stopping/rollback, contamination/late-result, or eligibility drift; assignment/exposure substitution; SRM; informative attrition; untreated interference/carryover; missing washout; invalid individual randomization; unaccounted multiplicity or alpha reset/reuse; peeking; underpowered/inconclusive guardrail; and “no significant harm” all fail E5 or retain baseline |
| Certification/cutover | Separate E0-E4, canary Release, hard-guardrail one-sided simultaneous/anytime bounds, E5, and full Release joins in that order | Trainer/self-evaluator bypass, underpowered/no-significant-harm false pass, inconclusive hard guardrail, or mutable single-rollout-row shortcut fails |
| Resource/performance | Real-device latency/energy/memory/thermal traces | Learning work starves decode or survives K1 cancellation fail |

### 9.3 Hard-zero invariants

The following observed counts MUST remain exactly zero in every release candidate:

- unauthorized durable writes;
- unauthorized network/data egress;
- cross-App-Agent private read/write/training leakage;
- direct output-to-memory, output-to-reward, or output-to-dataset adoption;
- uncertified policy/model activation;
- duplicate external effect or transfer caused by recovery;
- hidden-holdout membership/root/bulk access by trainer/generator/candidate, or candidate access outside one authorized evaluator-materialized case;
- use-after-delete/revoke/expiry;
- persisted or trained raw hidden chain of thought/credentials/KV state;
- production test gates with zero discovered tests;
- candidate behavior policy and sole evaluator in the same trust/correlation class.

Any nonzero value blocks release regardless of aggregate score.

### 9.4 Quality and system metrics

Metrics are reported as vectors by cohort, not collapsed into one vanity score:

- task correctness, completion, hard-constraint satisfaction, and exact first-pass success;
- factual citation/support, retrieval recall/precision/coverage, grounding conflict, and stale-source rate;
- logic uniqueness/contradiction detection, long-text extraction fidelity, tool/effect honesty, abstention and calibration;
- Main/Sub contribution coverage, verifier yield, correlated-consensus rate, branch/remand efficiency, and cycle termination;
- dataset lineage completeness, split leakage, duplicate/source concentration, poison/contamination alerts, deletion fence latency;
- Policy-A/Evidence-B regret on supported decisions, OPE support/ESS/interval width, shadow disagreement, canary effect/guardrails;
- model regression, catastrophic-forgetting, safety/privacy/authority failure, and rollback recovery time;
- time-to-first-token, decode rate, end-to-end latency, tool latency, memory peak, energy, thermal state, cache hit, and crash recovery;
- user-inspect/pause/reset/delete success and authorization comprehension;
- security hard-zero violations and incident closure.

Judge scores are labeled by judge identity/correlation and never replace deterministic or user/outcome evidence.

### 9.5 iPhone performance posture

The interactive hot path should perform only bounded event framing, reference append/currentness checks, already-materialized typed feature extraction, and certified Policy-A CPU scoring over Evidence-B. Dataset derivation, Evidence-B updates, OPE, replay, consolidation, conversion, training, broad evaluation, and cleanup run off the decode hot path under K1.

`cold40` and `sustained30` token/s are named conditional performance tiers for an exact model/profile/device/OS/thermal/context/decode configuration. They are not universal completion gates or promises. A tier may be claimed only with preregistered real-device evidence including:

- exact hardware model and memory class;
- OS/build, app/runtime/compiler/converter versions;
- model, quantization, context, prompt, cache, MTP/speculative, and sampling identities;
- cold/warm definition, token count, run count, distribution, thermal start/end, power/energy, and memory peak;
- correctness/parity and fallback results;
- sustained duration and throttling behavior.

Architecture completion depends on deterministic capability tiers and honest fallback, not achieving a target that the selected profile cannot physically sustain.

### 9.6 Repository-reality dispositions

Controlled convergence MUST explicitly classify and close these current seams:

| Current seam | Keep/reuse | Required closure |
|---|---|---|
| Real EBrain turn path | Reuse only as an in-memory turn-observation/result producer | W3 must bind an authorized K3 source-event emission before Experience lineage exists; `runTurnAndIngest` ticket submission is not EventLog truth and no direct learning write is allowed |
| `BASUpdateTicketLifecycleCoordinator` | Mechanism/projection only if useful | Source-gate plain `approveForDistillation`/`markDistilled`, remove independent queue/head authority, and prevent persistence failure from exposing an in-memory winner |
| `BASShadowTrialCoordinator` and Furnace bridge | Reuse shadow mechanics | Subordinate lifecycle/verdict to K3 + `runtime.certification`; no promotion mouth |
| `QinaoLearningExporter` | Reuse minimum export shell | Replace opaque/coarse approval with exact typed manifest/grants/receipts |
| Incumbent `BASContextCompiler.compile` | Preserve the live pure character-budget mechanism and sole compiler identity | Converge tokenize-once, exact Provider accounting, progressive disclosure, and exact descriptor semantics in W3 behind the same owner; never declare a second compiler or treat the current call as proof that those extensions exist |
| Core AI probes/shadow/migration primitives | Dormant/historical mechanisms, not a live production Qinao K2 path | Converge into the sole K2 path only after compatible reconversion and gates; keep inference-only, with exact candidate identity/parity/certification |
| `BASAppleInterventionBanditAdvisor.updatedSnapshot` | Dormant caller-driven string-bucket/string-action/Boolean-reward mechanism with no proven production caller | Keep fixture-only or retire; never expose it as Policy-A, Evidence-B, reward, routing, currentness, or adoption authority |
| Provider execution path | Reuse approved Provider contracts | Proposal-only, at-most-once, exact materialization and observation lineage |
| Sleep consolidation | Dormant bounded driver/pass shape; no production source caller currently proves a live foreground/background gate | First bind an exact incumbent app-lifecycle/execution-DAG call site; keep dry-run/projection until every mutation routes through the canonical memory commit owner, and never treat it as a general scheduler |
| L8 query self-pop | Do not reuse | Remove/fence; scratch-only cache if retained |
| Raw `MLXLoRATrainer` facade | Developer-only plugin or retire | No app production reachability/raw corpus/direct load |
| `privacySafe`/`sovereignSafe` booleans | Compatibility display only | Reopen typed evidence; Boolean cannot gate production |
| `BASEvolutionLifecycleStage.promoted` with `Action`/`Policy`/`Session` | Legacy compatibility only | Atomically map to sole certification/cutover owners or fence |
| Raw training exporters/sublimator and same-turn true-Boolean bundles | Do not reuse as authority | Fence to developer fixtures or replace with the governed Experience/Dataset/Zone-C path |
| Qwen3.5 manifest/MTP without production Qinao caller | Design/mechanism evidence only | No “current default” claim until exact Provider load-to-release reachability and certification pass |

No current mechanism is “already done” merely because a schema or demo exists.

### 9.7 Delivery waves

The learning design is integrated into the existing W0-W6 architecture waves; it does not add a second roadmap.

#### W0 — Freeze and truth

- treat the K4 platform spike as a hard predecessor to every later wave, not merely W5. At this snapshot its recorded `overall_gate = blocked`; therefore W0 is blocked and W1-W6 are non-executable until the selected release Xcode/iOS 27 SDK, signed archive/actual entitlements, physical install/launch, direct+async exact XPC, and canonical checker/index closure all pass;
- record exact implementation base, dirty-tree exclusions, current owners, symbols, targets, tests, platform evidence, and code reachability;
- add non-vacuous negative gates for parallel authority, empty filters/globs, direct learning writes, raw CoT, direct trainer loading, self-pop, and egress bypass;
- classify all existing learning/evolution/shadow/export mechanisms as production, mechanism-only, projection-only, demo, or retire;
- pin every historical `coreai-torch 0.4.0` `.aimodel` digest on iOS 27 beta 2 and later, including any currently packaged classifier asset; inventory-deny every Release claim and freeze the exact W4 reject-before-load mutation/expected-red fixture and contract. W0 does not alter the production resource/load path or require that future fixture to pass;
- freeze the hard-zero invariants and exact expected-open set.

#### W1 — Contracts

- converge Experience, reward-evidence, attribution/credit, dataset, training-job, candidate-identity, Policy-A/Evidence-B adaptive evidence, OPE, canary, deletion, and recovery semantics into existing owners;
- authorize zero new authority owners. Only an already ledger-allowlisted `approved_missing` M production candidate may use a non-empty current CreateGate manifest; E/A changes use a separate non-empty current ExtensionGate manifest; schema/current/backward/future fixtures use their own non-empty governed fixture set—no class satisfies another. A candidate outside the current ledger keeps this design `REVISE` until a separate atomic ledger/cardinality decision;
- freeze fixtures, migrations, the RSI state/reason encoding decision, canonicalization, malformed-input bounds, and authority source gates;
- atomically reconcile the 2026-07-19 unconditional raw-content “approved change” wording with the still-unresolved signed W2 Decision Gate and its selected branch; prose alone is not a receipt and no raw-content writer may open first;
- remove terminology conflicts such as independent “promotion”, opaque approval, or second compiler/manager.

#### W2 — K3 lifecycle and recovery

- first atomically amend the 2026-07-17 frozen K3 composite contract, all affected controlled documents, and Owner Ledger through a non-empty E/A ExtensionGate; no learning row may be appended ad hoc to the composite;
- then implement only the approved K3 rows/commands for dataset lifecycle references, semantic job/currentness references, Evidence-B references, inert candidate references, expected-parent CAS, idempotency, deletion fences, and exact replay/query—never Policy-A/model production head/current Release or Zone-C external-actuator truth;
- implement synchronous fence plus asynchronous cleanup and late-result inertia;
- prove crash points and historical receipt reconstruction without a second queue/head.

#### W3 — StateLake, context, and memory

- emit Experience envelopes from authoritative events;
- build rebuildable SQL/FTS/vector/temporal/entity projections and immutable temporal horizons;
- remove query self-pop and enforce lane-specific memory/Self assimilation;
- compile adaptive independent Main/Sub contexts through canonical `BASContextCompiler`;
- adapt the dormant `BASSleepConsolidationDriver` shape only after W3 binds a real incumbent lifecycle call site; keep it dry-run and bounded to the approved memory-horizon pass until that proof exists. It is not a general scheduler and has no authority to schedule cleaning, split, dataset, or Evidence-B work;
- map each other off-turn workload to an exact existing K1/execution-DAG/app-lifecycle admission owner and port through controlled convergence. If no incumbent owns initiation, the capability remains disabled rather than adding or casually selecting a scheduler.

#### W4 — Execution and shadow for learning candidates; no learning adoption

- run the frozen inert Policy-A fixture/candidate definition over shadow Evidence-B candidates, OPE, replay, in-process/test Provider conformers, and multi-Agent RSI; W4 makes no certification claim, and remote/isolated Provider execution remains disabled until W5;
- run Core AI/reference parity only against precommitted inert W0/W1 fixture packages through a non-production staging seam; execute the W0-pinned mutation so every denied historical 0.4.0 digest is now excluded/rejected before load, and require that negative fixture to turn green. Positive Core AI evidence requires an exact compatible 0.4.1-or-newer reconversion. Parity for externally imported candidates waits until the W5 protected import path exists;
- reuse shadow mechanisms only behind exact lifecycle/evidence contracts;
- expose metrics, incidents, reset, and deterministic baseline;
- no learning-generated Evidence-B, Policy-A, or model candidate activates or invokes W6 `production.cutover` in this wave. This restriction does not delay the convergence master's W4 host-selected local Provider production wiring for R5 grounding, R6 validation/market, post-R6 context compile, and terminal execution through the incumbent high-level runtime; isolated/remote Provider execution remains W5-gated.

#### W5 — Sovereign privacy and egress

W5 reopens and consumes the hard W0 K4 platform proof. It cannot weaken, replace, or defer that predecessor. At this specification's snapshot, `docs/superpowers/evidence/qinao-k4-platform-spike/status.json` records `overall_gate = blocked`: the toolchain is beta, intended-profile archive/provisioning and physical install are blocked, and Monitor/direct-XPC/async-XPC runtime evidence is absent.

- only after that entry gate, implement corpus/trainer export in the exact order L11/current-user authorization → L13 exact causal-predecessor/request/branch/outbox/read-set preparation → K3 prepare/enqueue → L14 exact branch/destination/purpose/payload authorization → K4 issue/reserve → K3 handoff → Zone-C `dispatch_pending` → K4 claim/use → Zone-C `dispatch_ready` → K3 `effect_permit_pending` → K4 anchor → K3 arm → Zone-C one-shot consume/dispatch/reconcile/terminal receipt → K3 closure; candidate import and every other protected use retain their own incumbent protocol rather than borrowing this order;
- complete App-Agent isolation, user inspect/pause/reset/delete, destination/purpose grants, and transfer reconciliation;
- prove every unauthorized sink and cross-scope path fails.

#### W6 — Certification, cutover, rollback, and performance

- connect every model, policy, execution-profile, and release candidate that requires certification to the sole `runtime.certification` owner for E0-E4 and post-canary E5;
- implement the ordered `E0-E4 → sealed canary Release/deployment → E5 → separately sealed full Release` protocol with `production.cutover` as the only deployment/cutover owner;
- prove immediate rollback, contamination recovery, deletion/model retirement, and late-result fencing;
- certify every exact Qwen, AFM, local, or API/remote profile actually proposed or enabled for production, plus its conditional performance tiers on the applicable real device/endpoint cohort; the enabled API/remote profile count may remain exactly zero;
- close all hard-zero, security, resource, and non-vacuity gates.

Wave order is a dependency order. A later-wave symbol or behavior cannot be used as a W0/W1 baseline test. A wave exit cannot require behavior explicitly forbidden until a later wave.

### 9.8 Completion criteria

The design is implemented only when all of the following are true:

1. exact 14/4/4/7 cardinality and existing owner boundaries remain mechanically enforced;
2. every experience has complete or explicitly missing lineage and no output self-corroboration path;
3. reward remains a governed vector with hard vetoes and no engagement objective;
4. Main/Sub attribution and credit carry explicit attribution/diagnostic/identified-causal/indeterminate status, correlation and assumption evidence, and unknown-safe behavior;
5. datasets are immutable purpose-bound generations with split-before-derive and deletion fences;
6. local data is default; every corpus/trainer export proves exact L11/current-user → L13 exact prepare → K3 outbox prepare/enqueue → L14 exact authorization → K4 issue/reserve → K3 handoff → Zone-C `dispatch_pending` → K4 claim/use → Zone-C `dispatch_ready` → K3 pending → K4 anchor → K3 arm → Zone-C one-shot dispatch/reconcile/terminal → K3 closure evidence, while every remote Provider egress separately proves exact Provider-A/M/[T]/L11/L14/K4-use/permit-put/K3-prepare/K4-anchor/K3-arm/required-visibility/fresh-handoff/observation/seal/visibility-close evidence;
7. certified Policy-A definitions and non-authoritative Evidence-B statistics are mechanically disjoint; Evidence-B uses bounded typed evidence, canonical deterministic state, baseline behavior, and exact evidence-state rollback without a second route/adoption mouth;
8. OPE reports only identified estimands, vector hard-gate bounds, adaptive-collection validity, and support honestly, returning `notIdentifiable` when required;
9. trainer and holdout are isolated, idempotent, supply-chain pinned, and return inert candidates only;
10. every Qwen or other model candidate proposed for production, and every enabled AFM/local/API/remote Provider profile, has a complete non-floating identity and independent certification; the enabled API/remote profile count may be exactly zero;
11. memory/Self/expression lanes, App-Agent scopes, and independent Agent contexts cannot contaminate one another;
12. RSI proves progress, stops cycles/overthinking, and recovers interrupted work without resending unknown effects;
13. contamination, deletion, and rollback have distinct fail-closed lifecycles and tested repair;
14. all non-vacuous gates, negative mutations, checker tests, hard-zero invariants, and real-device resource tests pass;
15. `runtime.certification` and `production.cutover` are the sole non-runtime Policy-A/model/execution-profile/Release certification and deployment/cutover mouths, with a deterministic no-model rollback path; mapped runtime-state adoption remains solely on its incumbent L13/L14/K3/K4 state-commit chain.

Failure of any item keeps production status `REVISE`.

## 10. Controlled Convergence Requirements

Before an implementation plan may execute this design, it MUST:

1. pin the reviewed commit and blob digest of this specification;
2. produce a cross-document semantic diff against all seven controlled documents and the 2026-07-17, 2026-07-19, and 2026-07-22 specializations;
3. produce a current code-reality ledger that distinguishes existing symbol, approved-planned target, and new design candidate;
4. classify each candidate as reuse, extend, adapt, migrate, create, or retire with one exact owner;
5. use separate non-empty manifest documents/records for create, extend/adapt, schema/fixture, and source-boundary gates, with exact `present` versus reviewed `notApplicable` cardinality semantics and no cross-class satisfaction;
6. atomically eliminate duplicate promotion, training, export, memory, context, recovery, and lifecycle mouths;
7. define exact schema, identity, canonicalization, bounds, malformed-input behavior, migration, fixture, recovery, deletion, and source gates for each adopted wire;
8. map every task to W0-W6 with real dependency order and only then author red/green tests;
9. prove every test target/filter/path/glob/checker exists and is non-empty before treating it as a gate;
10. leave unsupported future capabilities—federated learning, differential privacy, exact model unlearning, runtime training, or universal performance promises—explicitly disabled.

If a proposed feature requires a new authority, writer, store, manager, scheduler, compiler, or promotion mouth, the plan must first prove that no incumbent owns the responsibility and pass the honest CreateGate. Convenience is not proof.

## 11. Research Basis

The design uses primary sources for external technical claims:

- Apple, [Meet Core AI](https://developer.apple.com/videos/play/wwdc2026/324/): model conversion, optimization, specialization, profiling, and deployment.
- Apple, [Machine Learning & AI Group Lab](https://developer.apple.com/videos/play/wwdc2026/8016/): Core AI is an inference framework; training and supported conversion/toolchain responsibilities remain separate.
- Apple, [iOS & iPadOS 27 release notes, Core AI issue 177008303](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes): on-device specialization of 0.4.0-converted `.aimodel` material requires compatible 0.4.1-or-newer reconversion for the affected profile.
- Apple, [Evaluations framework](https://developer.apple.com/documentation/Evaluations) and [Evaluate your agentic app](https://developer.apple.com/videos/play/wwdc2026/299/): Xcode 27 evaluation structures and agentic-app evaluation.
- Apple, [Foundation Models adapter training](https://developer.apple.com/apple-intelligence/foundation-models-adapter/): the prior-generation adapter toolkit and its stated OS compatibility boundary.
- Apple, [Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels): current API evolution must be treated as profile/version evidence.
- Luo et al., [Agent Lightning: Train ANY AI Agents with Reinforcement Learning](https://arxiv.org/abs/2508.03680): disaggregation of agent execution and training plus trajectory credit.
- Lightman et al., [Let's Verify Step by Step](https://arxiv.org/abs/2305.20050): process supervision as distinct from outcome-only supervision.
- Rafailov et al., [Direct Preference Optimization](https://arxiv.org/abs/2305.18290); Ethayarajh et al., [KTO](https://arxiv.org/abs/2402.01306); Azar et al., [IPO](https://arxiv.org/abs/2310.12036); Hong et al., [ORPO](https://arxiv.org/abs/2403.07691): preference-learning choices by evidence shape.
- Shao et al., [DeepSeekMath](https://arxiv.org/abs/2402.03300): GRPO in a narrow verifiable mathematical setting, not justification for universal RL.
- Pan et al., [Feedback Loops With Language Models Drive In-Context Reward Hacking](https://arxiv.org/abs/2402.06627): feedback-loop reward-hacking risk.
- Turpin et al., [Language Models Don't Always Say What They Think](https://arxiv.org/abs/2305.04388): plausible post-hoc explanations may be unfaithful, motivating before-use work-product/consumer receipts.
- Lee et al., [RLAIF vs. RLHF](https://arxiv.org/abs/2309.00267): AI-generated preference labels can train policies, but same-checkpoint/model-family evidence remains correlated rather than independent truth.
- Dudík et al., [Doubly Robust Policy Evaluation and Learning](https://arxiv.org/abs/1103.4601): propensity/support-aware off-policy evaluation.
- Jiang and Li, [Doubly Robust Off-policy Value Evaluation for Reinforcement Learning](https://arxiv.org/abs/1511.03722): sequential DR requires trajectory-level state/action/reward/termination contracts rather than contextual-bandit relabeling.
- Kato and Kaneko, [Off-Policy Evaluation of Bandit Algorithm from Dependent Samples under Batch Update Policy](https://arxiv.org/abs/2010.13554): adaptive batch-policy logs are dependent and require an estimator/interval valid for that collection process.
- Ek et al., [Off-Policy Evaluation with Out-of-Sample Guarantees](https://arxiv.org/abs/2301.08649): target/evaluation separation and explicit assumptions for out-of-sample policy claims.
- Helff et al., [LLMs Gaming Verifiers: RLVR can Lead to Reward Hacking](https://arxiv.org/abs/2604.15149): imperfect extensional verifiers can reward shortcuts; isomorphic/metamorphic evaluation motivates verifier-family separation.
- Carlini et al., [Extracting Training Data from Large Language Models](https://arxiv.org/abs/2012.07805): model transformation does not erase training-data extraction risk, motivating derived-artifact scope and extraction tests.
- Dwork et al., [Generalization in Adaptive Data Analysis and Holdout Reuse](https://arxiv.org/abs/1506.02629): repeated adaptive holdout queries require an explicit information/query budget and protected reporting contract.
- Mathew et al., [Hidden in Plain Text](https://arxiv.org/abs/2410.03768): steganographic collusion can emerge in model communication and ordinary output oversight is insufficient.
- Shumailov et al., [The Curse of Recursion](https://arxiv.org/abs/2305.17493): recursive synthetic-data/model-collapse risk.
- Luo et al., [An Empirical Study of Catastrophic Forgetting in Large Language Models During Continual Fine-tuning](https://arxiv.org/abs/2308.08747): continual fine-tuning and regression/forgetting risk.

External research motivates mechanisms; it does not override Qinao's authority, privacy, evidence, or iOS constraints.

## 12. Final Architectural Invariants

The concise system contract is:

```text
Models propose.
Deterministic owners frame, validate, and record.
Independent evidence—not output confidence—supports learning.
Data generations are immutable, purpose-bound, and deletable by honest lifecycle.
The phone may update only bounded immutable Evidence-B under a separately certified finite Policy-A; Policy-A semantics change only through certification and cutover.
External trainers return candidates, never authority.
Stable Self changes slowly, explicitly, and with user confirmation.
Every Agent has an independent bounded context and typed communication.
RSI must prove progress or stop.
Certification and production cutover remain separate sole owners.
Every active candidate has a clean deterministic rollback parent.
```

This is the required foundation for a Qinao that can learn continuously without letting intelligence, personalization, or speed dissolve component boundaries, user agency, causal truth, or recoverability.
