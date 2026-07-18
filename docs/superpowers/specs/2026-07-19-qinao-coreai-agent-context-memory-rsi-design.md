# Qinao Core AI Agent, Context, Memory, and RSI Architecture Addendum

**Date:** 2026-07-19

**Status:** Design decisions approved; implementation and production certification remain `REVISE`; user written-spec review pending

**Scope:** Model-neutral Agent composition, Core AI production target, independent context windows, structured reasoning, bounded RSI, semantic memory/context compilation, Apple Silicon execution, anticipatory next-question projection, and validation/promotion rules

**Repository snapshot:** `codex/qinao-w1` at `9bc71c98f8986d04cec3c7d3733535039543f3a2`. This hash is provenance, not a permanent implementation base. The worktree also contains in-flight W0/W1 candidate changes that are not implementation truth until independently verified and committed.

**Normative precedence:** This addendum supersedes only conflicting target-state wording in the 2026-07-14 architecture design and the 2026-07-15 domain plans concerning the final local production backend, the approved main/sub-Agent portfolio, independent context windows, RSI interpretation, and `NextQuestionProjection`. The 2026-07-17 K3 budget and Provider contract addendum remains authoritative for exact K3 budget, allocation, claim, lineage, and recovery protocols. Every unchanged authority, durability, security, effect, erasure, and `14 / 4 / 4 / 7` rule in the 2026-07-14 design remains in force.

This is a normative design addendum, not an eighth Owner Ledger controlled document. Before W1, W0 must atomically merge every adopted decision into the architecture master and six domain plans, regenerate the Owner Ledger provenance/digests/required terms, and run the non-empty owner/create/shape/iOS-floor gates. Until that seven-document convergence and its independent receipts exist, this document does not directly authorize a new production owner or a production cutover. The in-flight corruption-recovery companion remains non-normative unless each proposed lifecycle and monotonic floor is mapped to an existing physical/operator authority; anything that would decide write eligibility outside those roots must pass CreateGate and an Owner Ledger amendment first.

## Executive Decision

Qinao remains a model-neutral deterministic application substrate. It owns protocols, state, authority, planning, verification, audit, recovery, and host integration. Every language or vision model remains outside Qinao SDK behind constrained value-only Provider and Proposal interfaces. No model may directly mutate authoritative state, execute a tool, issue a capability, publish bytes, or promote its own output.

The target local production backend for workspace- or host-managed model weights is now **certified Core AI**, not a permanently MLX-backed default. This changes the target backend decision, not present-tense repository truth:

- before E4/E5 certification and the sealed W6 cutover, MLX/Metal remains the current execution baseline, quality oracle, migration bridge, and shadow comparator;
- Core AI remains non-authoritative until the exact model/profile passes all quality, StateABI, memory, energy, thermal, cancellation, recovery, and release gates;
- after the sealed Core AI-only production cutover, MLX may remain only in a non-Release lab or a separately sealed non-authoritative shadow build/cohort; production Release source, link, factory, and reachability gates reject every MLX Provider/runtime path;
- a failed Core AI candidate yields `deny`, `unavailable`, `quarantine`, or an explicit newly authorized model change—not weaker gates or a hidden backend change.

Core AI-only does not mean ANE-only. A certified Core AI execution plan may use CPU, GPU, Neural Engine, or a digested custom operation reached through a public Core AI/coreai-torch extension point according to measured phase-specific evidence. The neural graph and mutable neural-state transition remain Core AI functions; an independent Metal trunk, head, KV/cache, or neural scheduler is a second backend and is prohibited after cutover. Host tokenization, deterministic sampling, and non-neural data processing may remain on CPU. OS placement requests are not treated as physical-placement receipts.

The approved model portfolio is:

| Role | Approved model family | Production representation | Authority status |
|---|---|---|---|
| selectable main Agent | Qwen3.5-4B, first candidate `textOnly` | self-converted, signed, certified Core AI assets | external Provider; proposal-only; `vision=false` initially |
| selectable main Agent | Apple Foundation Model (AFM) | system FoundationModels Provider | external Provider; proposal-only; not a conversion target |
| text specialist | MiniCPM5-1B | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| vision specialist | MiniCPM-V 4.6 | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| retrieval embedding mechanism | Granite Embedding 97M multilingual r2 | self-converted, signed, certified Core AI assets | L8 embedding Provider mechanism; not an Agent |

The current intended host default is `Qwen3.5-4B/textOnly`. The family name does not inherit the upstream VLM or MTP capabilities: vision is false and native MTP is false until the exact signed tensors, functions, StateABI, acceptance verifier, and rollback path are separately certified. A future full-vision Qwen profile is a different candidate. AFM is an explicit user-selectable alternative when its exact device, locale, language, availability, and task-capability profile is certified. This preference is host policy, not an SDK constant.

Names alone never identify production material. Every workspace/host-managed Core AI asset use binds exact source digest, tokenizer/template, conversion recipe, quantization, function graph, custom operation set, StateABI, toolchain, OS/runtime cohort, and certified execution profile.

That full material tuple applies to workspace/host-managed Core AI Provider assets. AFM weights and internal StateABI are opaque: an AFM use instead binds the exact OS/runtime cohort, FoundationModels capability and availability profile, locale/language, input/output schema, safety/tool contract, and Qinao request/profile identities. AFM has no KV, prefix, continuation, or StateABI compatibility with Qwen or another host-managed model.

The Core AI-only rule applies to the Qwen/MiniCPM/Granite Provider portfolio, not to every learned mechanism in the host. Existing Core ML microheads remain on an exact purpose-and-digest allowlist while their role-specific evidence favors the incumbent. That allowlist is only a derived immutable projection of the signed host profile, exact execution plan, and certification evidence; it has no independent store, registry, environment switch, or runtime editor, and a change creates a new profile/tree identity. A microhead migrates only after a fresh Pareto verdict wins on parity, latency, memory, energy, and integration cost. An allowlisted Core ML microhead may not impersonate or silently replace any of the five portfolio roles.

The architecture keeps exactly fourteen semantic LayerCores, four Physical Kernels, four bounded ControlRings, and seven orthogonal planes. Agents, context windows, StateLake lanes, Core AI functions, next-question projection, and RSI iterations do not add members to those sets.

The deployment floor is iOS 27 across every app, package, extension, generated binary, XCFramework slice, and Mach-O minimum. A lower deployment declaration anywhere in the selected Release closure is a build-gate failure.

At this design snapshot, Core AI and iOS 27 documentation is still preliminary. Exact API, toolchain, specialization, entitlement, and lifecycle assumptions must be revalidated against the final selected Xcode/iOS 27 build; a material SDK/runtime change creates new evidence identity.

## Current Repository Truth and Evidence Status

The target is not yet implemented or production-certified. The repository currently has useful mechanisms that must be extended or adapted rather than recreated:

- exact L1–L14 identities, LayerCell and artifact foundations;
- a K3 EventLog/control-nucleus convergence path and the approved K3 budget/Provider contract addendum;
- MLX/Metal Qwen execution, decode planning, MTP experiments, sessions, pressure primitives, and device evidence;
- a generic `BASCoreAIModelRunner`, Core AI prefill/decode sessions, an NLI verifier path, array bridging, and conversion scripts;
- FTS, vector, temporal, entity, retrieval-fusion, memory, and replay mechanisms;
- FoundationModels integration, sovereign authorization, publication, effect, and audit foundations.

The most recent Core AI evidence supports only a candidate mechanism, not production:

- full-causal KV plus int8 is the current fidelity-supported candidate recipe in the recorded T=32 comparison; stale int4/windowed claims are not ship evidence and this is not general task-quality proof;
- one iPhone Air probe demonstrated the fused-state GDN mechanism and top-5 agreement for its recorded T=32 chain case against the MLX golden path; it is not broad full-chain parity evidence;
- the large vocabulary head exceeded the tested ANE width and therefore used a GPU-stage split;
- the sequential multi-asset chain was roughly 10 token/s in the recorded experiment, not 40/30;
- the approximately 4.2 GB figure is a candidate file/package total, not a resident-memory claim; multi-asset residency, specialization/cache peak, install/update peak disk use, and the active hard-cap plan remain open;
- repository Qwen/Core AI probes that produced `.aimodel` material with `coreai-torch 0.4.0` are historical mechanism evidence only: Apple's v0.4.1 compatibility note says 0.4.0 artifacts fail to load/specialize from OS 27 beta 2 onward. `knownIssueSet` therefore denies those assets; an exact compatible 0.4.1-or-newer coreai-torch/coreai-core/Xcode/Metal toolchain must reconvert/AOT and rerun numeric, StateABI, device, cache, thermal, and recovery certification;
- the existing context-classifier campaign is decisive evidence *against* migrating that microhead today: 112/112 parity on two iPhone Air devices, but Core AI measured about 0.71 ms versus Core ML 0.14 ms and about 2.6× the sampled memory, so its recorded verdict remains `doNotMigrate`;
- for the Qwen/portfolio candidates, sustained power/thermal benefit, two-device evidence, representative quality, cancellation, recovery, and release certification remain open.

MiniCPM5-1B, MiniCPM-V 4.6, and Granite 97M Core AI conversions are approved targets and spikes, not completed conversions. AFM is already system-managed through FoundationModels but still requires a Qinao capability profile and the same proposal/adoption discipline.

The current Owner Ledger cardinalities remain `owners = 29`, `create_allowlist = 14`, `create_permissions = 14`, and `controlled_documents = 7`. No new layer, kernel, ring, plane, router, store, registry, scheduler, or semantic authority is authorized merely by this addendum. Any later owner change must pass the existing Owner Ledger/CreateGate process with a non-empty candidate manifest.

## 1. Locked Architecture Axes and Authority Boundaries

### 1.1 Cardinality

The architecture contains exactly:

- fourteen Semantic LayerCores, L1–L14;
- four Physical Kernels, K1–K4;
- four bounded ControlRings, ΩR/ΩG/ΩD/ΩE;
- seven orthogonal top-level planes.

This is fourteen semantic layers **plus** four external feedback rings, never “ten semantic cores plus four loops.”

The seven planes remain Semantic Authority, Kernel Ownership, Execution DAG, ControlRing, Data Plane, Adapter/IO, and Observe/Replay. Silicon Capability Fabric spans existing planes and is not an eighth plane.

The four Physical Kernels retain their existing ownership:

| Kernel | Sole mechanism responsibility in this design | Explicit limit |
|---|---|---|
| K1 Lease & Life | admission reservation, process-wide memory/thermal/power accounting, cancellation/checkpoint pressure, one local HeavyPhase owner | no semantic answer, model choice, or state truth |
| K2 Neural Organ | Provider-independent neural orchestration, model/session/state leases, prefill/decode supervision, Provider gateway | no concrete model ownership and no semantic adoption |
| K3 State & Evolution | one `FULL` control nucleus, EventLog, branch ordering/claim/fences, durable state/effect staging, indexes and projections | no global scheduler, semantic truth, risk verdict, or model choice |
| K4 Sovereign Microkernel | keys, signer, durable grants/claims/revocation/anchors and helper-private sovereignty state | no model execution, tool execution, or silicon scheduling |

The existing semantic-DAG topology contract owns the immutable graph shape; the W6 Turn Runtime executor may only validate membership/readiness and dispatch that graph. It does not become a second topology, policy, or scheduling authority. K1 admits and arbitrates heavy resources. K2 supervises neural execution. K3 persists branch ordinals, claims, Attempt fences, event heads, visibility boundaries, and recovery truth. Models may propose delegation but cannot schedule, spawn, or call one another.

### 1.2 LayerCell boundary

Every semantic layer is expressed as:

```text
typed ingress → validation membrane → pure LayerCore → typed egress
```

Adjacent pure LayerCores may be executed as a physical superstep only when policy, authorization, I/O, visibility, and effect boundaries are not crossed. The executor must still produce per-layer artifacts or canonical no-op receipts. A superstep is an optimization, not a fused semantic owner.

### 1.3 One owner for every truth

The design does not create a second:

- EventLog, control WAL, writable memory truth, Artifact Store, State Market, retrieval ranker, context compiler, task scheduler, model registry, Agent registry, cache authority, promotion store, effect journal, publication journal, retry truth, or commit gate;
- model-internal route that bypasses Provider claims;
- legacy coordinator path whose result can compete with the authoritative DAG;
- role/LIFO Agent registry, dormant Agent Fabric authority, or Qinao actor-memory source of truth.

New Swift, Rust, SQL, C/C++, or Metal code is justified only when it fills a missing invariant behind an existing authority seam. Language preference alone is never permission to duplicate a mechanism.

## 2. Reliability and Structured Reasoning

The system is optimized for verified task correctness, not for making a small model sound confident. “Answer correctly on the first visible response” is a product objective implemented through structured hidden work and exact verification; it is not a universal accuracy promise.

### 2.1 Shared reasoning artifacts

Models exchange only bounded typed artifacts, including:

- `ConstraintLedger` with explicit variables, domains, hard/soft constraints, ordering relations, and unresolved clauses;
- `EvidenceArtifact` and `SourceSpanArtifact` with exact UTF-8 byte spans, provenance, snapshot, authority, and freshness;
- `CandidateSolution`, `CritiqueArtifact`, `UncertaintyArtifact`, and `VerificationReceipt`;
- `VisualObservationArtifact` for vision-derived claims and regions;
- `PerspectiveArtifact` separating facts, inferred interpretations, value judgments, and user preference assumptions;
- `ClarificationProposal` when a required variable cannot be safely inferred;
- `JoinArtifact` that records which branches were included, excluded, contradicted, or left unresolved.

Raw chain-of-thought is neither a collaboration protocol nor durable memory. It is not requested from Providers, shared between models, stored in StateLake, exposed in telemetry, or treated as evidence. Qinao retains decisions, constraints, citations, counterexamples, uncertainty, and verification receipts.

### 2.2 Semantic status is separate from transport status

Every reasoning WorkUnit closes with a semantic state independent of whether a Provider call technically succeeded:

```text
verified | disproved | unresolved | notApplicable | skippedByPolicy
```

A successful token stream cannot turn `unresolved` into `verified`. A timeout does not rewrite a previously verified fact. Visible output may be released only when the task's required semantic predicates are satisfied or when the exact unresolved coverage is disclosed and policy permits a partial answer.

### 2.3 Problem-specific flows

**Multi-constraint logic and ordering problems**

1. L6 normalizes entities, variables, domains, quantifiers, negation, and the question target while preserving every originating raw span.
2. L7 creates the exact ConstraintLedger and rejects ambiguous aliases or hidden domain assumptions. Every constraint binds the raw span, canonical AST, normalized interpretation, source, and epistemic modality; the deterministic solver proves only that ledger, never that the natural-language formalization was correct.
3. L9 or the text specialist proposes one or more assignments with an explicit constraint-to-step map.
4. A deterministic checker evaluates every hard constraint and searches for a counterexample or alternate solution.
5. L10 checks premise coverage, unresolved terms, aliases, quantifiers, negation, and interpretation ambiguity, then returns `verifiedUnique`, `verifiedMultiple`, `inconsistentPremises`, or `unresolved`; only the first may be presented as a unique answer. Mutation tests must catch `not`, `exactly one`, `unless`, `immediately`, and reversed-order mistranslations.

**Long-text extraction and transformation**

1. Ingestion/Adapter and L8 establish structural blocks and stable raw-byte spans; L3 only budgets already selected spans.
2. L8 retrieves exact raw spans before dense paraphrase candidates. Every normalized artifact binds its raw parent, normalization recipe/version, and a reversible byte-offset map; citations always resolve back to the raw span.
3. The specialist emits span-bound facts; no uncited extracted fact enters the join.
4. L7 deduplicates, preserves conflicting versions, and checks temporal/entity scope.
5. L10 performs claim-to-source coverage and transformation-loss checks before presentation.

**Strongly inducing subjective prompts**

1. L6 identifies presuppositions and requested stance.
2. L5 supplies user/host preferences without converting them into facts.
3. L9 produces at least a fact-grounded reading and a plausible alternative perspective when material.
4. L10 checks that uncertainty and disputed assumptions survive compression.
5. L12 presents a direct answer while distinguishing fact, inference, and judgment.

**Lateral puzzles and “sea-turtle soup” questions**

1. L6/L7 preserve every clue's speech act, source, and epistemic modality. Only propositions explicitly established as world ground truth become immutable constraints; observations, reports, beliefs, and narrative conventions remain typed hypotheses.
2. L9 maintains a small discriminative hypothesis portfolio rather than one story.
3. Each follow-up question is selected by deterministic partition quality, worst-case hypothesis elimination, and answerability—not model probability or theatrical novelty.
4. Contradicted hypotheses are retired with receipts; a solved hypothesis must explain all fixed clues, and multiple admissible hypotheses may never be presented as a unique answer.

**Overthinking and local loops**

1. Every iteration must cite a new progress witness.
2. Repeated canonical state digests terminate as `cycle_detected`.
3. No new required evidence, reduced conflict, fixed verifier failure, or safer resource state means `no_progress`.
4. Budget exhaustion never promotes the “last answer.” The system answers with verified coverage, asks one necessary question, or abstains.

## 3. Main/Sub-Agent Portfolio and Core AI Production Target

### 3.1 Agent roles

The selected main Agent owns no Qinao authority. It is the primary proposal generator for a terminal-answer branch. The host chooses Qwen3.5-4B or AFM before exact context compilation through a signed, certified profile. The user choice is an input to that profile; it is not an environment-variable route and cannot be changed by an old coordinator.

Qwen3.5-4B and AFM may serve as the main terminal-answer Provider only when their exact capability profile supports the requested task. AFM is no longer restricted to sidecar work: it may be the user-selected main Agent, but remains system FoundationModels execution and never exposes convertible weights.

MiniCPM5-1B is a bounded text specialist for extraction, constraint normalization, critique, compact transformation, and other certified tasks. MiniCPM-V 4.6 is a bounded visual specialist for image/video observations. Their outputs are internal proposals and cannot directly become visible terminal output or state truth.

Granite 97M is not an Agent. It implements the existing `BASMemory.BASEmbeddingProvider` seam, which is the sole production L8 embedding seam, for conditional dense retrieval. The homonymous `BASRuntimeCore.BASEmbeddingProvider` declaration is compatibility-only and must be adapted to or removed behind an explicit reachability gate before production; it may not create a second capability/model identity. Granite does not critique, delegate, select evidence, or generate a user response.

### 3.2 Delegation rules

Delegation exists only on a pre-terminal branch whose frozen `BASProviderBranchPolicy` rule permits output role `.internalProposal`. A main-model invocation acting in that internal role may emit a typed `DelegationProposal` specifying purpose, required inputs, expected output schema, BudgetLease reference, deadline, and causal parents. The unique `.turnStep/.terminalAnswerCandidate` branch is `answerOnly`, exposes no delegation/tool/effect/continuation schema, and therefore cannot delegate.

L5/L6/L7/L9 semantic decisions plus the installed branch policy and execution-plan owner determine whether the proposed work is authorized; the Turn Runtime only checks graph membership, causal readiness, and receipts. L3 compiles a fresh minimal required-input projection for that exact Provider step—never the entire parent capsule. Evidence, OCR, visual observations, and prior model proposals enter an inert, escaped data channel with explicit authority labels and cannot introduce system instructions, tool schemas, capabilities, or output policy. Before terminal-source pin, K1 may reserve resources and K3 may allocate a separately authorized specialist branch. The adapter then materializes the exact request; any required W5 dormant fence completes; only a fresh K3 claim permit can reach K2's at-most-once supervised invocation. After terminal-source pin, no ordinary specialist branch may be allocated; only a purpose `.verifierProposal` branch with output role `.internalProposal`, preauthorized by buffered policy and permitted by the exact K3 addendum state, may follow. A returned specialist artifact enters L7/L9/L10 like any other untrusted proposal.

There is no majority vote for truth. Conflicting outputs remain separate until evidence, authority, deterministic constraints, and L10 verification resolve them. Model confidence is never authority.

### 3.3 Core AI conversion and packaging

All workspace/host-managed Provider weights outside Qinao SDK and intended for local production are converted by the project into Core AI artifacts. The conversion program reuses Apple primitives and tools first:

- Apple `coreai-models` reference implementations where architecture-compatible;
- `coreai-torch` export and Core AI AOT compilation;
- `coreai-opt` compression and calibration;
- Core AI runtime specialization, cache, and state APIs;
- custom authoring, lowerings, and Core AI custom Metal kernels only for missing model-specific operations.

The project must not rebuild PyTorch, SQLite, tokenizers, attention kernels, or runtime facilities already supplied and verified by the chosen stack. Rust is preferred for existing deterministic fusion/canonical hot logic behind narrow C ABIs; SQL owns indexed durability within the established stores; C/C++ is limited to required runtime bridges; Metal is limited to measured kernels unavailable or materially inadequate in public Core AI mechanisms.

Large model assets are signed, content-addressed downloadable packages rather than blindly app-bundled blobs. Identity has three non-circular levels:

- `ModelMaterialManifestArtifactID` is the sole Core AI realization/evolution of the master's canonical `bundleDigest`, not a second identity. For Core AI, every profile, plan, fallback edge, cache key, lease, and receipt uses that one Artifact ID/digest; any old separately computed `bundleDigest` is migration input only and must be converted or rejected before activation;
- a precomputable `SpecializationKey` binds the exact material and selected-variant digest, immutable source URL, device architecture, OS/runtime, `SpecializationOptions`, and cache namespace. A later `CacheHandleReceipt` carries cache policy, opaque bookmark, creation state, and invalidation state; the bookmark is only a fallible locator and never enters the key/hash;
- `CertifiedBackendProfile` references the material-manifest digest and separately binds exact SKU, OS build/runtime, plan/cohort, evidence references, thresholds, verdict, and revocation/erasure compatibility. The material manifest never references that profile or a verdict.

Every profile/plan binds an exact selected variant digest, `sourceSpecialization | AOT` path, and `SpecializationOptions`. An AOT miss may use the same portable `.aimodel` only when the frozen pre-allocation plan contains a separately certified source-specialization arm with its own exact evidence; otherwise the result is unavailable. It never reuses AOT evidence for a different path or silently switches after allocation. The existing owners execute one fail-closed install transaction—no new manager or store:

```text
disk-space reservation for retained old + temporary download + new source/AOT + worst cache/specialization scratch + margin
→ temporary download
→ package Merkle root + signature + license verification
→ K1 HeavyPhase lease + specialization and smoke-test receipt
→ single active-pointer compare-and-swap
→ bounded certified rollback retention
→ old asset/cache cleanup only after zero reader leases
```

`provider.package-boundary` owns only private bytes, immutable content directories, reader leases, cache/bookmark mechanism, and the pointer CAS. The pointer resolves the exact digest already selected by `model.manifest-invocation` and `execution.plan-provider-router`; it never selects a model/profile. K2 pins the immutable URL, material/variant digest, `SpecializationKey`, options, and current `CacheHandleReceipt` for the Attempt, never loads through a content-changing alias, and a stale/missing bookmark, purged cache, moved/deleted source, or OS-invalidated specialization may only rebuild the same frozen material arm or return unavailable. Pointer swap affects new readers; it cannot invalidate or retarget an in-flight reader.

Security monotonicity remains with existing sovereign owners: L14 decides exact material admission/revocation; `sovereign.k4-durable-lifecycle` records the signed minimum material-authorization epoch and revocation in its helper-private `synchronous=FULL` lifecycle, anchors the exact K3 source root, and recovers through its existing monotonic-root/query protocol. Admission, claim, chunk, and adoption revalidate generation and that floor. Rollback retention keeps inert bytes only; use of older material requires a new higher deployment/authorization epoch, an exact current certification/release join, and never lowers the security floor. If this mapping cannot be proven without a new write-eligibility root, CreateGate and an Owner Ledger amendment are mandatory.

Background Assets may download and report installation only. Specialization/smoke is a K1 HeavyPhase and runs in foreground or under a separately proven iOS 27 continued-processing inference entitlement; otherwise it defers. Crash, cancellation, ENOSPC, corrupted chunk, signature mismatch, specialization failure, pointer-CAS loss, cache purge, OS update, source move/delete, bookmark invalidation, cleanup failure, and revocation during use are fault-injected; none may expose partial material or silently reactivate an older epoch. The package's signed envelope directly covers `ModelMaterialManifestArtifactID`; verification recomputes that ID and every referenced resource root before install. Its canonical tagged/versioned payload binds:

```text
source weight digest
license and provenance
QualityIdentity + supported generation-semantics contract
config + RoPE + adapters/LoRA + certified fallback graph digest
tokenizer/template digest
conversion source/toolchain digest
precision and calibration corpus digest
function graph and custom-op digest
input/output names, dtypes, shapes, and dynamic bounds
platform + staticMaxContext + prefill/decode/verify bucket + batch/K + mask/position geometry
StateABI, ProcessorABI, and cache-scope version
backend/runtime build identity
portable .aimodel resource Merkle root + sorted auxiliary-resource roots
sorted AOT variants: architecture/platform/minimum-OS/toolchain/options + byte digest + auxiliary-resource roots
```

Generic “first output value” behavior is forbidden in production. Every Core AI function has exact named tensors, dtypes, shapes, state count/layout, and bounded dynamic dimensions. Bridges prove contiguity or perform an explicit ledgered copy.

`ProcessorABI` is role-specific. Granite fixes 384 dimensions, CLS pooling, L2 normalization, tokenizer, and static sequence buckets; a model, pooling, normalization, or ABI change rebuilds the vector index, and mixed embeddings are forbidden. MiniCPM-V fixes orientation, color space, resize/crop/normalization, resolution buckets, frame sampling, and vision-encoder/projector/decoder digests; image and video are separate certified profiles. Visual ingestion requests permission only in user context, strips EXIF/location unless explicitly authorized, and discloses raw pixels only to the exact visual profile. The text-only main Agent receives a typed `VisualObservationArtifact`, not raw pixels.

The recorded int8/full-causal Qwen path is a fidelity anchor, not a final compression decision. A sensitivity-guided `coreai-opt` search may evaluate mixed 4/8-bit palettization, group sizes such as 8/32, and selective 8-bit embedding/head retention. Every candidate is a new QualityIdentity and reruns numeric, long-sequence, end-task, memory, energy, thermal, cancellation, and recovery gates; an Apple reference Qwen recipe is a platform control, not replacement product evidence.

### 3.4 SDK boundary

Qinao SDK declares model-neutral value contracts and deterministic adoption logic. It does not import concrete Qwen, MiniCPM, Granite, MLX, Core AI, or FoundationModels implementations and does not package model weights. External Provider packages depend inward on Qinao contracts.

AFM uses a FoundationModels Provider package. Qwen, MiniCPM, and Granite use external Core AI Provider packages. Production Qwen/MiniCPM/Granite execution has exactly one raw Core AI Provider session/cache owner. A FoundationModels `LanguageModelExecutor` surface is either non-authoritative demonstration code or a stateless facade over that same executor; it may not own a second KV, prefix, cancellation, retry, or result truth.

Cross-model change—Qwen to AFM, AFM to Qwen, or either to another lineage—always creates a new Attempt, recompiles context, and obtains explicit host/user consent when policy requires it. It is never a mid-turn or silent fallback.

## 4. Independent Context Windows and Typed Collaboration

Qinao supports many independent logical context windows without pretending the device can host many independent 4B runtimes.

### 4.1 ContextCapsule

`ContextCapsule` is a strictly tagged value contract, never one optional all-fields bag. The `attemptFrame` variant exists at WorkUnit admission and contains only:

```text
TurnOperationRef + AttemptRef
WorkspaceReadSnapshot root + canonical generation-vector Artifact ID
task purpose + expected output schema
constraint/evidence/artifact references
BudgetLease Artifact reference
CapabilityGrant + capability attenuation + disclosure/visibility compartment
```

The `providerStep` variant may be constructed only from a reopened K3 allocation receipt and contains:

```text
one canonical BASProviderExecutionRef (root/branch/Attempt/lease derive only from it)
step rule + output role + Provider policy/binding IDs
exact model/profile/BASExecutionPlan identity
either R5 reservoir + grounding-request references
or R6 CompiledContextDescriptor + authorized minimal context sections
latest committed K3 budget-use receipt required by the exact policy state
the inherited attemptFrame reference + attenuated CapabilityGrant
```

The variants use an exhaustive presence matrix: no future ID is guessed, no loose `BASTurnBranchRef` or epoch tuple is copied beside its canonical parent, and an R5 grounder cannot carry an R6 descriptor. Every input and output validates producer scope, intended consumer scope, branch/step identity, snapshot/generation currentness, visibility compartment, and the canonical generation-vector epochs before use. ContextCapsules do not copy lease ceilings, cumulative counters, or a mutable “remaining budget.” A bounded display/diagnostic projection may be derived from the referenced K3 state but is never authority. ContextCapsules also do not contain mutable shared prompts, ambient credentials, database handles, tool handles, another Agent's private scratch state, or raw chain-of-thought.

Logical windows may reuse the same immutable model weights and compiled functions. Their KV/state, prefix identity, prompt history, generation, RNG/sampler state, grammar state, cancellation, budgets, and artifacts remain isolated. Cross-model KV sharing is forbidden. Same-model prefix reuse is allowed only through the exact cache-scope contract and never because two prompts “look similar.”

### 4.2 Task decomposition

The canonical task graph is:

```text
Mission
└─ Objective
   ├─ WorkUnit
   │  ├─ constraints and evidence requirements
   │  └─ Attempt
   │     ├─ candidate solution branches
   │     ├─ verification and outcome
   │     └─ SolutionArtifact
   └─ WorkUnit (bounded repeat)
```

Every node has one purpose, bounded inputs, explicit parents, completion predicates, a BudgetLease reference, and terminal status. Large tasks split into independent WorkUnits only where the join semantics are known. A join binds the exact task-graph root, expected child heads/generations, each child's current terminal `AttemptRef`, and the completion predicate. An immutable result from a superseded child Attempt cannot satisfy the join. A required failed/unresolved child blocks or remands the parent while already completed siblings remain independently valid. Quorum expresses completeness only; it never turns model majority into truth. A child cannot inherit broader authority than its parent.

### 4.3 Collaboration and timing

Only typed immutable artifacts cross Agent boundaries. The main terminal-answer prefill freezes its ContextCapsule. A late specialist artifact cannot be injected into an active decode stream. Before terminal-source pin, it may enter only a separately authorized branch already permitted by policy. After pin, only the exact buffered post-pin verifier exception may run after the source's completed terminal seal; every other late artifact is fenced to a new Attempt. Prefix or suffix cache mechanics may reduce the cost of an otherwise authorized rebuild when exact scope permits, but never authorize a branch, retry, route change, or Attempt.

Low latency comes from:

- shared read-only weights and compiled Core AI specialization;
- parallel independent retrieval or proposal branches under one admitted wave;
- exact prefix/cache reuse within one identity;
- small typed artifacts instead of transcript replay;
- pre-tokenized compiled sections and deterministic joins;
- one local HeavyPhase owner, preventing destructive accelerator thrash.

Low latency does not justify shared mutable KV, context leakage, hidden Agent calls, unverified early adoption, or concurrent 4B trunks.

## 5. Receipt-Driven Bounded RSI

RSI is a bounded receipt-driven improvement protocol shared by the four existing ControlRings. It is not recursive self-modification, a manager, a super-Agent, a fifth ring, or another scheduler.

```text
Observe → Diagnose → Propose → Simulate/Compare
→ Authorize → Act → Verify → Consolidate
```

Each iteration is immutable and binds its parent digest, Attempt/snapshot/epoch vector, exact ring, declared edge, BudgetLease Artifact ID, prior committed budget-use receipt when applicable, deadline, capability, fixed obligation set, and progress witness. It never carries a caller-computed mutable remaining value. The four modes are:

| Ring | Improvement scope | May not change |
|---|---|---|
| ΩR Resource | defer, checkpoint, evict, resume, or request pre-allocation selection of a certified compatible physical plan | semantic answer, risk, policy, model identity; any route change after allocation |
| ΩG Grounding | request bounded evidence, repair coverage, surface conflict | silently select truth or mutate a finished turn |
| ΩD Deliberation | create/revise a bounded candidate or critique branch | commit truth, call a model directly, loop without progress |
| ΩE Effect/Evolution | reconcile an existing saga or produce shadow evolution evidence | replay an indeterminate effect or self-promote a version |

Progress uses a ring- and edge-specific lexicographic potential over frozen root obligations. A new material conflict/counterexample may extend that set only through an L7/L10 verification receipt: the extension advances an append-only obligation generation, never deletes/weakens an earlier obligation, and never replenishes any budget. Evidence coverage counts only once per canonical claim and only above its required authority; only a verifier receipt may close a constraint. The governed canonicalization factory under the existing `runtime.semantic-dag` contract computes each cycle digest from obligation generation, deduped coverage, conflicts, counterexamples, and semantic state; it sorts exchangeable sets and excludes time, iteration/random IDs, random seeds, prose wording, and irrelevant artifact IDs. K3 reopens the witness inputs and equality-checks the digest instead of trusting caller bytes. Progress in one ring cannot replenish another ring's iteration, token, time, or effect budget. Valid progress is one or more of:

- increased coverage of a required evidence claim;
- fewer unresolved constraints or material conflicts;
- repair of a reproducible verifier counterexample;
- a safer resource state or successful compatible checkpoint;
- monotonic advancement of an already authorized effect/recovery saga.

Longer prose, a different random seed, self-reported confidence, repeated state digest, or a cosmetically revised answer is not progress.

Only a terminal payload whose pair is `converged + convergedVerified` and whose committed K3 budget-use receipt is present may feed authoritative downstream adoption. `cycle_detected`, `no_progress`, `budget_exhausted`, `degraded_with_coverage`, `needs_confirmation`, and `indeterminate_needs_reconciliation` remain typed non-authoritative outcomes. L10/L11/L14 may nevertheless authorize a user-visible report containing only an independently verified subset plus an explicit unresolved-scope manifest; it does not adopt the unresolved remainder as fact. A one-pass task that was verified without entering a ControlRing needs its normal verification receipt, not a fabricated RSI receipt.

Self-repair may rebuild projections, indexes, caches, compiled specialization, or replayable material from authoritative events. It may emit quarantine evidence or a quarantine request, but only the existing signed profile/certification authority decides quarantine or promotion. Self-evolution is shadow/offline and uses only consented, purpose-limited, redacted artifacts; raw user content, raw CoT, credentials, and undeclared Provider derivatives are never exported as an improvement corpus. It may propose future policy, prompt, conversion, model, or component changes, but cannot rewrite running code, weights, schema, security policy, authority mappings, current LayerCores, or its own certification status.

## 6. StateLake Memory and Context Compilation

### 6.1 One truth and rebuildable horizons

K3's one `synchronous=FULL` EventLog/control nucleus remains the durable command, ordering, and recovery truth. It does not own the semantic meaning of those commands. One encrypted content-addressed Artifact owner stores canonical content once **within an authorized sharing domain**, not once globally. Content identity binds bytes plus authority scope, visibility compartment, key epoch, and erasure domain; physical deduplication is allowed only when every reference shares one explicit erase-together fate. Public/explicitly shared content with independent deletion fate uses a different erasure domain/DEK even when bytes match. Independent provenance retains an independent wrapped reference so deletion and existence cannot leak across compartments. Current/day/week/month/archive views are rebuildable projections over the same event history, not separately writable memories.

Persisting canonical raw content as an encrypted content-addressed artifact is an explicit approved change from the earlier ephemeral-content-cache posture. The EventLog stores metadata and the artifact reference; cold replay must not depend on an actor cache. Erasure requires scoped cryptographic key destruction plus deletion or proven unreachability of every live blob, backup, quarantine copy, projection, cache, and Provider derivative. A receipt distinguishes provenance/reference detachment from cryptographic destruction of underlying bytes and may claim the latter only after the final erase-together reference closes. “Retired” counts only when recovery is cryptographically impossible and a post-erasure rescan closes every obligation. A Provider profile that cannot establish its retention and purge boundary may not receive data whose policy requires physical erasure.

Every fact uses one bitemporal interval:

```text
validTime: when the fact applies in the represented world
transactionTime: when Qinao learned or changed its record
```

`validAt(worldTime, snapshotHWM)` constrains both the valid-time interval and the transaction-time high-water mark, so a later correction cannot leak into an earlier snapshot. A correction explicitly names `targetFactArtifactID` and proves the same stable `claimKey`/slot, matching authority scope, and correction permission; its replacement value may differ. Only that edge may close the target interval. Ordinary contradiction remains co-visible in the `ConflictManifest`; a lower-authority proposal cannot supersede a higher-authority fact. Retraction (“the earlier claim was never true”) is distinct from valid-time cessation (“it stopped being true later”). Corrections append supersession, cessation, or retraction and never edit history in place.

### 6.2 Structured memory skeleton

Durable task memory preserves:

```text
Mission → Objective → WorkUnit
        → constraints / evidence / solution / verification / outcome
```

It also preserves stable user-authorized preferences, task continuity, source provenance, confidence calibration evidence, conflicts, corrections, and outcome receipts. It does not store raw CoT or infer a durable preference from one dismissed next-question card.

### 6.3 Linguistic graph

The memory graph is sparse and evidence-linked, not a full duplicate of the text:

```text
UTF-8 span
→ lemma and morphology
→ syntax
→ predicate and arguments
→ entity and coreference
→ temporal and causal relations
→ discourse and dialogue act
→ modality, negation, and epistemic status
→ evidence, conflict, and authority links
```

Stable annotation identity is normalized text artifact ID + UTF-8 byte range + annotation kind, and the normalized artifact binds the raw parent, normalization recipe/version, and reversible byte-offset map. Presented citations always resolve to raw bytes. Tokenizer indices are model-specific projections and cannot be stable memory identity.

### 6.4 Multi-lane retrieval

Retrieval proceeds in this order:

1. compile hard eligibility into the physical partition using workspace/window/Attempt/sensitivity/authority/deletion scope;
2. SQL/metadata filtering;
3. exact grep, FTS5, and BM25 retrieval;
4. temporal/episode retrieval;
5. entity/relation retrieval;
6. conditional Granite dense retrieval only when lexical/structural coverage is insufficient or semantic paraphrase is required;
7. lane-local canonical dedupe, source caps, and candidate receipts;
8. bounded cross-lane fusion plus a coverage-preserving reservoir that cannot discard the sole candidate for a required claim or material contradiction;
9. optional small-model grounding proposals over the bounded fused set;
10. L7 final hard-eligibility revalidation, conflict preservation, coverage, diversity, and State Market.

Granite and the grounding model never see a broader corpus than the hard eligibility partition. Granite is the pure L8 embedding mechanism under a K1 reservation, K2 supervision, and usage receipts; it is not a K3 generative branch. A MiniCPM grounder uses the existing `.groundingProposal/.internalProposal` allocate/materialize/claim path. A grounding request binds the exact sentence, minimal structural context, qualifier/negation/coreference closure, and an omission flag; missing or ambiguous closure forces `unknown`. Dense similarity or a grounding label cannot override authority, freshness, deletion, confidentiality, exact contradiction, deterministic constraints, or token cost. A small-model label is an untrusted proposal; L7 validates its exact inputs and L10 may verify the resulting claim map. The State Market uses a versioned deterministic objective and tie-break over relevance, authority, freshness, utility, diversity, source concentration, conflict coverage, and token cost only after hard eligibility has passed. Existing FTS, vector, temporal, entity, NLI, and Rust fusion mechanisms are extended behind current owners; no second retrieval engine is created.

### 6.5 Context is compiled, not concatenated

The Context Budget Allocator gives each required section an explicit byte/token budget and priority. The State Compiler:

- includes the task contract, hard constraints, exact high-authority evidence, material conflicts, selected history, tool schema only when authorized, and output/verification contract;
- tokenizes canonical sections once for the selected model/tokenizer identity;
- emits exact section digests, offsets, provenance, authority labels, and an omission ledger;
- renders evidence/model output as escaped inert data distinct from system instructions and tool/output schemas;
- distinguishes full prefill, same-Attempt suffix continuation, exact prefix-cache reuse, and full rebuild;
- never truncates a hard constraint, conflict qualifier, negation, source span, or output schema silently.

Omitted material remains inspectable in the omission ledger. Any model/tokenizer/template/StateABI or cross-model change recompiles the context.

## 7. Apple Silicon and Core AI Execution

### 7.1 Healthy full-blood use

“Full-blood” means the exact selected quality identity and task contract run through the best verified plan under memory, energy, latency, thermal, and recovery constraints. It does not mean saturating every compute unit or refusing to checkpoint.

The process has one authoritative local HeavyPhase owner. Independent CPU retrieval and lightweight work may overlap when K1 proves headroom. Two local model trunks may not compete because multiple Agents are logically active.

Thermal or memory pressure may:

- defer a specialist branch;
- serialize phases;
- checkpoint and resume;
- evict rebuildable cache or specialization;
- before K3 allocation, request selection of a pre-certified same-quality, same-StateABI compatible plan;
- after allocation but before claim, defer or continue that allocation to its first claim without changing plan, Provider, request, or call identity;
- while the same claimed invocation is demonstrably live, join, pause, or continue that invocation only; after owner/process loss, handoff, or `sent_or_unknown`, query/reconcile/seal only and never recreate a call permit or physical call;
- stop admitting new heavy work.

Pressure may not silently change model, quantization, context, sampling, tool contract, or answer quality identity.

iOS lifecycle callbacks, background launches, and termination notifications are resource hints, never correctness boundaries. Before claim the runtime may defer or checkpoint when the exact profile permits. After claim, only the same live invocation may pause/resume; owner/process loss follows the query/reconcile/terminalize rule above. The existing background-task owner may request bounded time, but no keepalive, `willTerminate`, or background callback is required for safety.

### 7.2 Core AI function portfolio

A certified Qwen Core AI package may expose separate embedding, trunk, LM-head, prefill, decode, optional native MTP, and state-management functions. The first `Qwen3.5-4B/textOnly` profile exposes no vision and no native MTP until those exact functions are certified. The current multi-asset chain remains one physical Provider invocation with one K3 branch and one terminal observation; its internal asset stages do not become new authority branches.

For iOS, `platform + staticMaxContext + prefill/decode/verify bucket + batch/K + attention-mask/position geometry` is part of asset identity, execution-profile identity, and StateABI. An over-limit request is recompiled into certified chunks/buckets or rejected; it never dynamically expands mutable geometry. Every mutable Core AI session is per Attempt and wrapped by an actor or noncopyable single-driver lease. Shared compiled immutable functions are reusable, but KV/state, `MutableViews`, counters, cancellation fences, and checkpoints are not.

Any function-stage fault, cancellation, timeout, or unknown completion poisons the whole mutable Provider-state lease. It is rebuilt from the last certified checkpoint; partially advanced `MutableViews` are never treated as valid. Checkpoint resume is allowed only when the exact profile proves an atomic bounded snapshot/restore protocol. Release tests inject faults at every function boundary and race `step/prefill/reset/cancel/restore`, eight windows, and late completions.

MiniCPM5 loads on demand for admitted text-specialist work. MiniCPM-V loads only for an admitted visual WorkUnit and exact image/video ProcessorABI. Granite may remain warm only when its measured footprint/energy and expected reuse fit K1 policy. AFM remains system-managed, but its latency, cancellation, availability, and semantic capability still enter the Qinao plan and receipts.

An AFM Attempt owns an independent `LanguageModelSession`, frozen transcript, and empty tool set. From prewarm/request until terminal completion or observed cancellation quiescence, it holds an opaque local-heavy lease; Qinao does not start another local Core AI heavy phase concurrently and receipts record placement as observed/unknown rather than claiming an execution unit. An OS/system-model update creates a new cohort. Historical replay consumes the recorded AFM output artifact instead of rerunning AFM. If the certified platform profile cannot prove the required no-durable-derivative or purge semantics, AFM is ineligible for data requiring physical erasure.

Placement is empirical per phase. A Qwen body may favor Neural Engine while a vocabulary head favors GPU; Granite or vision may have different profiles. Production claims require runtime/energy evidence, not a `.neuralEngine` preference or architecture label.

Future Apple Silicon is admitted by an exact observed capability and certified evidence profile. No production branch assumes a future chip name, core count, accelerator behavior, memory cap, or entitlement from marketing identity alone.

### 7.3 Cache and continuation identities

`PromptPrefixCache` and same-Attempt `ContinuationCheckpoint` are distinct:

- prefix cache proves exact reusable input prefix under model/tokenizer/template/StateABI/authority/snapshot/epoch identity;
- continuation checkpoint additionally freezes accepted token history, target state, pending speculative state, RNG/sampler/grammar state, cancellation fence, and active Attempt identity.

They cannot be substituted for one another. A checkpoint from an obsolete Attempt cannot seed a new Attempt even if its prompt digest matches.

### 7.4 Decode routing

Before K3 allocation, the Decode Router may choose only a certified plan whose frozen internal strategy set contains:

- plain target decode;
- prompt lookup whose proposed tokens are target-verified;
- native Qwen MTP whose tokens and termination are target-verified;
- deterministic collapse to certified plain target decode on the same logical target checkpoint.

After fresh claim, this is not a route, Provider, plan, branch, materialized-request, or physical-call replacement. It is an internal same-invocation strategy collapse already authorized by the frozen plan. Speculation never advances authoritative target state before acceptance. Failed speculative scratch is disposable. Prompt lookup and MTP are enabled by measured accepted-token goodput and disabled with hysteresis when they lose.

### 7.5 Performance contract

Thermally cold resident 40 accepted token/s and sustained 30 accepted token/s remain workload-qualified certification targets, not unconditional completion gates or promises. A claim must name device/SKU, OS and runtime, exact model/profile digest, context/output buckets, sampling, cache/residency/thermal state, timer, percentile, power conditions, device/run count, and exclusions.

Certification uses at least two physical devices and a 1,800-second sustained run per exact profile. It reports P10/P50/P95 accepted decode rate, end-to-end goodput, time to first releasable token, energy, RSS/physical footprint, thermal trajectory, MTP acceptance, cancellation/recovery, failures, and identity parity. Structural W6 completion may legitimately deny the 40/30 marketing claim while accepting the architecture.

## 8. NextQuestionProjection

Qinao may anticipate the user's most useful next question, but it does so as a small L12 presentation projection—not a new Agent, router, store, market, notification system, or durable preference learner.

The projection considers zero to five process-local transient candidates drawn only from:

- the finalized answer and its existing artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification;
- an already authorized unresolved horizon thread.

It scores relevance, utility, grounding, authority, freshness, continuity, answerability, cognitive cost, risk, novelty, and diversity with a versioned deterministic objective, tie-break, and minimum winning margin. It never trusts model-reported confidence. Hard policy, privacy, confirmation, and unresolved-conflict gates run before scoring. A close tie, weak grounding, low utility, or uncertain authorization yields abstention.

At most one compact in-app card appears, only after the answer has ended, the input is blank, no confirmation is pending, and the deterministic margin passes. At render time a single compare-and-swap must still match the same spool/release, `ContextWorkspaceRef`, Attempt/window/session, visibility compartment, and current authority/policy/deletion epochs. Focus, input, generation, release, or epoch change discards the pool. Candidate text and scores never enter Artifact Mesh, EventLog, analytics, logs, or telemetry. The card performs no new tool call, network call, retrieval, Agent invocation, memory write, or speculative external work before a tap; it supports Dynamic Type and VoiceOver and does not use notifications, Siri, Spotlight, or App Intents.

A tap creates a new Input Event and new Attempt under normal admission. Dismissal or non-click is ephemeral UI state and cannot become a durable negative preference. The objective is user usefulness, not click-through rate.

## 9. Canonical Fourteen-Layer End-to-End Flow

The exact semantic mapping remains:

| Layer | Authority in this addendum |
|---|---|
| L1 Wick Life | life/resource policy and lease requirements |
| L2 Brain Tissue | model/neural requirement and execution-plan interpretation |
| L3 Folded Lung | context budget, compilation, binding, and fingerprint |
| L4 World Prior | versioned world claims and domain assumptions |
| L5 Host Constitution | user/host policy, preferences, persona, disclosure constraints |
| L6 Situation | normalized intent, task frame, current situation, risk hints |
| L7 Mirror Blade / Grounding | StateRequirementPlan, hard eligibility, fusion, coverage, conflicts, State Market |
| L8 Hippocampal Memory | snapshots, projections, lane retrieval candidates |
| L9 Kunlun / Dream | candidate portfolio, alternatives, counterfactuals, selection |
| L10 Tribunal | exact constraints, critique, claim support, convergence and output verification |
| L11 Risk | risk classification, confirmation, disclosure, RiskPermit |
| L12 Soft Hand | response spool, presentation, verified release, NextQuestionProjection |
| L13 Evolution | prepare/commit/reconcile/evolution proposals |
| L14 Sovereign | admission, exact authorization, revocation, and terminal seal |

Input Normalizer remains Adapter/IO and cannot become L15.

### 9.1 Typical response path

```text
Input Event
→ Input Normalizer
→ L14 admission preflight
→ Artifact Mesh put of the immutable TurnOperation root
→ same K3 transaction: active Attempt head + zero-spend BudgetLease row
→ TurnOperationRef + active Attempt/ContextWorkspace identity
→ L1 life/resource policy + L5 constitution + L6 situation
→ L4 prior + L7 StateRequirementPlan and hard semantic eligibility predicate
→ K3/L8 snapshot open + materialized hard physical eligibility partition
→ L8 SQL/exact/FTS/BM25/temporal/entity lanes inside that partition
→ conditional Granite dense: K1 phase reservation → K2 embedding mechanism → usage receipt
→ L7 lane-local dedupe/source caps → bounded fusion + coverage reservoir
→ optional MiniCPM grounding: R5 reservoir-bound plan → K1 reserve → committed K3 use
  → .groundingProposal/.internalProposal allocate/materialize/claim → K2 → grounding proposal
→ L7 final hard-eligibility revalidation, conflict/coverage and deterministic State Market
→ bounded preterminal ΩG/ΩD evidence/candidate remands; any accepted change re-enters L7 before context compile
→ host-selected certified model capability admission
→ L2 exact neural requirement + eligible plan template
→ L3 context budget + State Compiler + CompiledContextDescriptor
→ L2 freeze exact BASExecutionPlan bound to that descriptor
→ K1 heavy-resource reservation
→ committed K3 budget-use authorization
→ K3 typed Provider branch allocation + allocation reopen A
→ exact materialized Provider request + materialization reopen M
→ terminal answer-only source pin
→ isolated/remote only: dormant W5 prepare/anchor/arm fence
→ incremental only: L11 provisional eligibility → L14 bounded stream grant → K4 one-shot provisionalStream claim
→ incremental mode only: K3 zero-byte logical visibility row (authorizes zero bytes)
→ fresh K3 claim permit
→ K2 external Provider at-most-once prefill/decode supervision
   ├─ incremental only: reconstruct/reopen ProviderVisibilityReceipt before any stream permit
   └─ each releasable chunk: L10 receipt → K3 batch permit → K4 anchor → K3 arm → Adapter/IO sink under L12 provisional semantics
→ Provider/executor terminal result
→ isolated/remote supervisor observation + attestation when required
→ K3 terminal event-head seal
→ L9 candidate portfolio/selection
→ L12 exact non-visible presentation spool
→ L10 exact-output verification and convergence
→ L11 final risk/confirmation decision
→ L14 exact release authorization
→ K3 opens/reopens policy-selected visibility (buffered Vrow/V now; incremental exact V already exists)
→ BASExactReleasePreparationPayload + throughVisibility chain
→ Artifact Mesh put of complete self-ID-free pre-publication manifest
→ K3 reopens spool/preparation/manifest/visibility and installs non-usable prepared row
→ publication journal reserve
→ outer composition proves reservation; K3 revalidates its tuple/epochs and issues publication permit
→ K4 claim + boundary anchor → K3 arm
→ Adapter/IO BASResponseReleaseCoordinator once-only sink under L12 release semantics
→ publication journal finalization
→ K3 closes only its publication-boundary row
→ optional L12 NextQuestionProjection
```

Prefill routing distinguishes full prefill, same-Attempt suffix continuation, exact prefix cache, and full rebuild. Decode planning distinguishes plain, prompt lookup, native MTP, and same-invocation strategy collapse. Both choices are frozen before branch allocation; neither router owns model identity, truth, authorization, or post-claim route replacement.

The diagram shows the incremental pre-claim visibility row explicitly, but that row alone authorizes zero bytes. Nothing may occur between its commit and the fresh Provider claim; its immutable receipt is reconstructed only afterward and before the first stream permit. Buffered mode omits that row before claim and opens visibility only after terminal seal, the complete authorized verifier suffix, exact spool, and passed L10 exact-output verification. Ordinary ΩG/ΩD evidence or candidate remands end before terminal-source pin. After pin, only pure deterministic checks and the exact preauthorized buffered `.verifierProposal/.internalProposal` suffix are legal; a need for new evidence, a new candidate, or recompiled context creates a new Attempt. The independent publication journal alone owns reservation/finalization; K3 installs and later closes only its own boundary row, never opens the journal, and K3/K4 may not infer sink success. The 2026-07-17 K3 addendum's exact allocate/materialize/pin/fence/claim/seal/visibility ordering governs whenever this high-level diagram is less specific.

Recovery never means “call the branch again.” An unclaimed allocation may continue to its first claim. A live claimed invocation may only be joined or continued under its existing call identity. After owner/process loss, handoff, or a possible send, recovery is query/reconcile/seal-only; it cannot recreate a call permit, request, publication, or Provider invocation.

### 9.2 Tool, effect, and state path

```text
Provider proposal
→ L10 semantic/exact verification
→ L11 risk and confirmation
→ L13 prepare intent
→ K3 EventLog + outbox prepare/handed_to_zone_c
→ L14 exact effect authorization
→ K4 durable issue/reserve
→ Zone C dispatch_pending
→ K4 capability claim
→ Zone C dispatch_ready
→ K3 pending effect permit
→ K4 boundary anchor
→ K3 arm
→ Zone C consumes permit/anchor/arm once as dispatch_boundary_armed
→ Zone C external call/reconcile and terminal/indeterminate receipt + child signature attestation
→ L13 receipt interpretation + StateCommitIntent
→ K3 invisible staging
→ L14 terminal-seal decision
→ K4 terminal-seal signature
→ K3 activation or append
```

Models never receive Zone-C call capability. A terminal-answer branch exposes no tool/effect schema. Response and effect branches remain siblings with independent grants and terminal truth. The post-seal K4 operation is a terminal-seal signature, not a second boundary anchor. An indeterminate external effect cannot cause the response or effect to be regenerated and dispatched again.

### 9.3 Collaboration boundaries

Deep cooperation occurs through explicit artifacts and receipts:

- L8 produces candidates; L7 decides eligibility/fusion/coverage;
- L3 compiles context; it does not retrieve or choose truth;
- K2 executes a model plan; L9/L10/L11/L14 decide whether its proposal is selected, verified, safe, and authorized;
- K3 persists facts and fences; it does not decide their meaning;
- L13 prepares/interprets state/effects; K3 stages, K4 authorizes/anchors, Zone C dispatches, L14 seals;
- NextQuestionProjection consumes only finalized authorized artifacts and cannot mutate the completed Attempt.

## 10. Validation, Promotion, Migration, and Completion

### 10.1 Anti-vacuity gates

Every documented gate must prove it actually exercised the intended candidate:

- missing named files, directories, targets, fixtures, scripts, manifests, or globs are fatal;
- `rg` exit 2 is an infrastructure failure, never “no match”; named-file gates assert file existence first;
- focused-test wrappers discover the target and assert matched test count greater than zero before execution;
- candidate manifests are required, schema-valid, rooted in the candidate tree, and non-empty when a CreateGate is expected to evaluate candidates;
- SwiftPM/Xcode target membership is checked, not inferred from a filesystem path;
- baseline tests use only baseline APIs; later-wave APIs cannot make an intended RED test uncompilable;
- CI executes each checker and its own unit/adversarial tests with pinned prerequisites;
- every gate records exact tree, toolchain, command, candidate/test/glob counts, exit code, and relevant device identity;
- zero candidates, zero tests, or zero matched files is a failure unless a separately typed and reviewed `notApplicable` contract proves why;
- mutation tests rename/remove a named file, add a forbidden owner, corrupt a manifest, break a filter, and invert a predicate to prove that the gate fails closed.

These rules close the known “armed but never fired” candidate checker, zero-match Swift filter, missing-file `rg`, nonexistent target, and empty glob classes. A green command without non-vacuity evidence is not a gate receipt.

### 10.2 Validation domains

The integrated candidate must close all of these domains:

1. **Authority/ownership:** exact `14 / 4 / 4 / 7`, owner-ledger parity, no duplicate writer/router/scheduler/store, value-only Provider boundary.
2. **Contracts:** governed schema/version/canonicalization, task/context/Agent artifacts, exact Core AI function/StateABI/ProcessorABI manifests, backward fixtures only for real historical wire versions.
3. **Core AI conversion/assets:** source/license lock, portable resource identity, compression search, host parity, cohort AOT, atomic install/update/rollback/revocation, device fidelity, placement evidence, task quality, memory, energy, thermal, cancellation, recovery.
4. **Agent isolation:** exact Provider-step capsule identity, minimum disclosure, inert data/instruction separation, branch/capability attenuation, no direct calls, no cross-window state/KV leak, no raw CoT exchange.
5. **Reasoning:** raw-span-to-AST coverage and mutation oracles, long-text reversible spans, subjective perspective preservation, lateral epistemic modalities, cycle/no-progress termination.
6. **Retrieval/context:** hard physical eligibility before ranking, pre-grounding dedupe/fusion/reservoir, exact/FTS/BM25/dense parity, qualifier closure, conflict/coverage, omission ledger, tokenizer/model/index rebuild rules.
7. **Memory/privacy:** scoped artifact identity, cold replay, bitemporal as-of correction, deletion epoch/tombstone, cryptographic key destruction, blob/backup/quarantine/projection/cache/Provider-derivative rescan closure.
8. **RSI:** ring-specific potentials, canonical visited digests, fixed obligations, BudgetLease/K3-use accounting, adoption only for `converged + convergedVerified` with the committed use receipt, shadow-only consented/redacted evolution.
9. **Effects/recovery:** failure injection at every durable boundary, no duplicate external call/publication, honest indeterminate state, independent publication-journal reserve/finalize recovery, K3/K4/Zone-C restart recovery.
10. **Silicon/release:** two-device identity, fixed context geometry, poison-on-partial-stage-fault, Release single-driver races, load/prefill/decode/cache routes, one HeavyPhase owner including AFM opaque leases, footprint, UI responsiveness, power/thermal run, exact Release-tree seal.

Next-question tests additionally prove zero-to-five transient candidates, one-card maximum, deterministic abstention, render-time CAS, no pre-tap work/write or candidate telemetry, no cross-window disclosure, no durable dismissal learning, accessibility, and tap-as-new-input semantics.

The crash matrix must include publication-journal corruption/restart/lost reply/indeterminate sink; K3 database corruption, quarantine, cold reopen, and monotonic-floor rollback; every Core AI function boundary and partial `MutableViews` mutation; asset download/specialization/active-pointer/reader/revocation boundaries plus OS-update invalidation, cache purge, stale bookmark, and source move/delete; AFM cancellation quiescence; and iOS suspension/termination before and after claim. Every expected failure is fail-closed and proves that no second Provider call, external effect, byte release, or authority writer was created.

The cross-boundary simulation oracle is:

| Fault window | Only legal closure |
|---|---|
| eligibility or admission denies | zero payload query, model load, cache lookup, materialization, or external call |
| allocated but not claimed | same allocation may reach its first claim, or closes unused |
| claimed and live | join/continue the same physical invocation only |
| claimed and owner/process/completion unknown | query/reconcile/seal; never create another call permit |
| Core AI stage partially mutated state | poison the whole lease and rebuild from the last certified checkpoint |
| response sink succeeded but reply was lost | publication-journal lookup/finalization only; K3/K4 do not re-arm or resend |
| Zone C is indeterminate | reconcile the same saga; never regenerate or redispatch the effect |
| policy/deletion/revocation epoch changes | block new use and adoption, close or quarantine the exact in-flight identity, and complete purge obligations without fallback |
| window/focus changes before next-question render | discard the transient candidate pool with zero durable trace |

### 10.3 Promotion is a projection of existing certification

The following lifecycle is a readable projection of the existing `runtime.certification` / `CertifiedBackendProfile` authority through E4. It ends in immutable evidence and is not a deployment state machine, ModelPromotionStore, or registry:

```text
absent
→ conversionSpike        # E1/E2 mechanism evidence
→ hostParity             # bounded host oracle evidence
→ deviceShadow           # E3, non-authoritative device evidence
→ certifiedCandidate     # E4 complete profile evidence
```

Canary and full production are two separate immutable joins, never mutable certification transitions:

```text
exact immutable E4 verdict
+ sealed canary Release manifest/tree/cohort under production.cutover
→ controlled canary deployment → immutable E5 verdict

exact immutable E5 verdict
+ separately sealed full Release manifest/tree under production.cutover
→ one full production-authoritative route
```

A new source weight, tokenizer/template, conversion toolchain, quantization/calibration, function graph, custom operation, StateABI/ProcessorABI/geometry, OS/runtime cohort, or material execution plan creates a new identity and returns to the appropriate unproven evidence grade.

Quarantine/retraction creates new immutable evidence and prevents the affected identity from satisfying a future join. It cannot rewrite an old verdict or mutate an already sealed Release tree. An urgent runtime stop uses existing authority only: `L14 decision → K3 RevocationFenceReceipt → K4 revoke`, and ingress, queue, chunk, claim, and seal boundaries revalidate the exact generation/epochs so no new use or adoption escapes. Runtime rollback then deploys another separately certified and sealed tree through `production.cutover`; it never selects a hidden in-process route or silently restores MLX.

The Core AI gate order is:

```text
source/license lock
→ reference oracle
→ export and op inventory
→ uncompressed numeric baseline
→ sensitivity-guided compression/calibration identities
→ host parity
→ portable resource verification + optional exact-cohort AOT
→ install/update/rollback/revocation fault matrix
→ physical-device function/state fidelity
→ phase placement profile
→ end-task quality
→ memory/energy/thermal
→ cancellation/recovery/fault injection → immutable E4 verdict
→ sealed canary cohort + E5 evidence
→ separately sealed full release
```

Public Apple references and common conversion components are proven first. Then Granite establishes the smallest embedding path, MiniCPM5 establishes specialist text generation, Qwen3.5 is productionized against the existing evidence, and MiniCPM-V adds the multimodal path. This order is a research dependency order, not permission to activate a later wave early. AFM enters through the same Qinao capability/adoption/release contracts without a weight conversion stage.

### 10.4 Existing W0–W6 roadmap remains the only roadmap

This addendum does not create W7 or a parallel “Agent project.” Its work is placed into the existing convergence waves:

| Wave | Addendum responsibilities |
|---|---|
| W0 | freeze owners/writers and legacy bypasses; repair non-vacuous gates/CI; converge iOS 27 floors; perform and independently verify the K4 public-framework/entitlement/lifecycle/IPC/helper-private `WAL + FULL` platform spike; atomically merge this addendum into the seven controlled documents and map or reject every recovery lifecycle/floor authority |
| W1 | immutable model-neutral Agent, ContextCapsule, reasoning, Provider-asset identity/reference, retrieval, memory, RSI, semantic-DAG, and NextQuestion value contracts only; no concrete `BASStateABI`, execution behavior, or production activation |
| W2 | one K3 `FULL` nucleus, canonical task/Attempt roots, branch control, encrypted content owner, memory/erasure convergence, plus crash/corruption/quarantine/cold-reopen and monotonic-floor closure; production model allocation still disabled |
| W3 | snapshot projections, SQL/exact/FTS/BM25/temporal/entity/dense retrieval, grounding, State Market, context compiler, structured reasoning fixtures; Provider paths remain shadow-only |
| W4 | external Core AI/AFM Provider packages, execution plans, concrete `BASStateABI`/ProcessorABI, K1/K2/K3 handoff, and prefill/decode/cache mechanisms; the unique physical owner/claim/actuation seam and planned production R5→R6-context handoff become authoritative under existing owners, with the current incumbent MLX baseline as the only production caller if required; new Core AI/AFM candidates remain shadow/device-validation only—no authoritative semantic executor, canary, or Core AI model-release cutover |
| W5 | implement durable K4, Provider egress, Zone C, independent publication journal, effect/publication recovery, and erasure mechanisms; prove them with non-zero fixtures and fault injection while production publication remains disabled; retire only direct/synthetic effect paths whose replacement is already closed; K3 nucleus corruption recovery was already a W2 gate |
| W6 | integrate the authoritative semantic-DAG executor and complete replay manifest; activate the W5 publication path only after that manifest exists; obtain E4, deploy the sealed canary cohort, obtain E5, then join E5 with a separately sealed full Core AI Release tree; retire the legacy response/production route, complete multi-device certification, and optionally earn the 40/30 claim |

Offline conversion spikes may start earlier when they do not change production authority. Production wiring cannot cross the listed W4/W6 gates.

The K4 spike is a hard W0 predecessor. It must identify and prove the exact public framework, extension point, entitlement, lifecycle, generated protocol/IPC shape, signing/install behavior, and helper-private SQLite `synchronous=FULL` feasibility. If it fails, the architecture returns for review; release mode may not silently collapse K4 into an in-process substitute.

### 10.5 Baseline and branch semantics

The implementation base for a wave is the then-current, explicitly recorded candidate-tree commit after all predecessor-wave commits and receipts, not a branch name or worktree directory. At this document's implementation snapshot, `codex/qinao-w0` pointed to `43060b810` and the implementation-bearing `codex/qinao-w1` commit `9bc71c98f` was eleven commits ahead; this documentation commit does not redefine that implementation snapshot. In-flight staged or untracked changes are not a baseline and cannot enter certification evidence.

Before each wave:

1. record candidate tree, predecessor receipts, toolchain, Owner Ledger digest, and controlled-plan digests;
2. materialize the exact tree in a clean disposable location;
3. run the non-vacuous owner/create/shape/iOS-floor gates and their tests;
4. deny implementation if controlled documents or authority counts disagree;
5. bind every later build, device receipt, and release seal to that exact tree.

### 10.6 Completion criteria

This addendum is implemented only when:

- the architecture still has exactly `14 / 4 / 4 / 7` and no duplicate authority;
- Qinao SDK is model-neutral and all concrete Provider packages remain external;
- Qwen, MiniCPM5, MiniCPM-V, and Granite local production assets have exact certified Core AI identities, or their unavailable roles fail closed without weakening the rest of the system;
- AFM obeys the same proposal/adoption/Attempt boundary;
- independent context windows pass isolation, recovery, cache, and eight-window stress;
- structured reasoning and RSI gates reject unsupported certainty and non-progress loops;
- StateLake, encrypted artifacts, projections, context compilation, and erasure close from cold replay;
- tools, publication, memory commit, and model outputs cannot bypass L10/L11/L13/L14 and K3/K4/Zone-C boundaries;
- the exact profile earns immutable E4/E5 evidence and only the exact E5-verdict + separately sealed Release-tree join reaches production cutover, with rollback/revocation evidence;
- all anti-vacuity and fault-injection tests prove their own failure sensitivity.

Success may honestly end in `promote`, `deny`, `quarantine`, or `model unavailable`. The architecture can be complete while the 40/30 performance claim remains denied. Performance evidence never waives quality, security, state, or recovery evidence.

## Prohibited Interpretations

This design must not be interpreted as permission to:

- call the current Core AI Qwen experiment production-ready;
- treat the recorded 10 token/s chain as evidence for 40/30;
- force every Core AI phase onto ANE or infer actual placement from a preference;
- use an independent Metal neural trunk/head/KV/cache while describing the route as Core AI-only;
- migrate an allowlisted Core ML microhead without role-specific Pareto evidence, or use it as a portfolio fallback;
- copy AFM weights, convert them, or treat FoundationModels as Qinao-owned state;
- let the main model spawn sub-Agents or let sub-Agents call one another;
- persist/share raw CoT, mutable prompt buffers, cross-model KV, or ambient tool handles;
- turn Granite, `NextQuestionProjection`, RSI, Input Normalizer, Silicon Capability Fabric, or Zone C into a new semantic layer or authority;
- create a ModelPromotionStore, AgentRegistry, ContextStore, MemoryLedger duplicate, RSIManager, second State Market, or hidden/global scheduler inside K3;
- allow self-repair to alter authoritative facts or self-evolution to promote code/weights/policy;
- silently fall back from a selected Qwen Attempt to AFM/MLX or from AFM to Qwen;
- use thermal pressure to lower model quality identity;
- claim erasure while a content key/blob, projection, cache, Provider derivative, or reachable backup remains;
- globally deduplicate private content across visibility, key, authority, or erasure domains;
- treat a certification evidence grade as permission to mutate or select the deployed production tree;
- accept a gate that matched zero candidates, tests, fixtures, or source files.

## Source Grounding and Companion Documents

Normative and committed repository evidence used by this addendum:

- [`2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`](./2026-07-14-iphone-air-future-apple-silicon-architecture-design.md)
- [`2026-07-17-k3-budget-provider-contract-addendum-design.md`](./2026-07-17-k3-budget-provider-contract-addendum-design.md)
- [`qinao-owner-ledger-v1.json`](./qinao-owner-ledger-v1.json)
- [`COREAI_CONVERSION_NEXT_STEPS.md`](../../../BehavioralAISubstrate/Docs/COREAI_CONVERSION_NEXT_STEPS.md)
- [`COREAI_RUNCERT_BACKLOG.md`](../../../BehavioralAISubstrate/Docs/COREAI_RUNCERT_BACKLOG.md)
- [`2026-07-15-iphone-air-architecture-convergence-master.md`](../plans/2026-07-15-iphone-air-architecture-convergence-master.md)
- [`2026-07-15-iphone-air-contracts-layercell.md`](../plans/2026-07-15-iphone-air-contracts-layercell.md)
- [`2026-07-15-iphone-air-semantic-statelake-context.md`](../plans/2026-07-15-iphone-air-semantic-statelake-context.md)
- [`2026-07-15-iphone-air-silicon-execution-spine.md`](../plans/2026-07-15-iphone-air-silicon-execution-spine.md)
- [`2026-07-15-iphone-air-sovereign-release-effects.md`](../plans/2026-07-15-iphone-air-sovereign-release-effects.md)
- [`2026-07-15-iphone-air-runtime-replay-certification.md`](../plans/2026-07-15-iphone-air-runtime-replay-certification.md)

The following remain in-flight W0 companions rather than committed baseline or normative evidence until independently verified and committed:

- `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md`
- `docs/superpowers/evidence/qinao-k4-platform-spike/`

External Apple platform facts already catalogued in Section 40 of the 2026-07-14 master design remain applicable. Additional portfolio and conversion-tooling facts introduced by this addendum are grounded by:

- [Apple Core AI](https://developer.apple.com/documentation/coreai)
- [Apple Core AI Models](https://github.com/apple/coreai-models)
- [Apple Core AI ahead-of-time compilation](https://developer.apple.com/documentation/coreai/compiling-core-ai-models-ahead-of-time)
- [Apple Core AI specialization and caching](https://developer.apple.com/documentation/coreai/managing-model-specialization-and-caching)
- [Apple coreai-torch](https://github.com/apple/coreai-torch)
- [Apple coreai-torch v0.4.1 compatibility note](https://github.com/apple/coreai-torch/releases/tag/v0.4.1)
- [Apple coreai-optimization](https://github.com/apple/coreai-optimization)
- [Apple LanguageModelExecutor](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutor)
- [Qwen3.5-4B model card](https://huggingface.co/Qwen/Qwen3.5-4B)
- [MiniCPM5-1B model card](https://huggingface.co/openbmb/MiniCPM5-1B)
- [MiniCPM-V 4.6 model card](https://huggingface.co/openbmb/MiniCPM-V-4.6)
- [Granite Embedding 97M Multilingual R2 model card](https://huggingface.co/ibm-granite/granite-embedding-97m-multilingual-r2)

These sources inform conversion and capability hypotheses; only repository-bound device and certification receipts may promote production behavior.
