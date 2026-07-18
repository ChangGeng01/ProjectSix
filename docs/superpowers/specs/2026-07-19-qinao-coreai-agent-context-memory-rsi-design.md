# Qinao Core AI Agent, Context, Memory, and RSI Architecture Addendum

**Date:** 2026-07-19

**Status:** Design decisions approved; implementation and production certification remain `REVISE`; user written-spec review pending

**Scope:** Model-neutral Agent composition, Core AI production target, independent context windows, structured reasoning, bounded RSI, semantic memory/context compilation, Apple Silicon execution, anticipatory next-question projection, and validation/promotion rules

**Repository snapshot:** `codex/qinao-w1` at `9bc71c98f8986d04cec3c7d3733535039543f3a2`. This hash is provenance, not a permanent implementation base. The worktree also contains in-flight W0/W1 candidate changes that are not implementation truth until independently verified and committed.

**Normative precedence:** This addendum supersedes only conflicting target-state wording in the 2026-07-14 architecture design and the 2026-07-15 domain plans concerning the final local production backend, the approved main/sub-Agent portfolio, independent context windows, RSI interpretation, and `NextQuestionProjection`. The 2026-07-17 K3 budget and Provider contract addendum remains authoritative for exact K3 budget, allocation, claim, lineage, and recovery protocols. Every unchanged authority, durability, security, effect, erasure, and `14 / 4 / 4 / 7` rule in the 2026-07-14 design remains in force.

This is a normative design addendum, not an eighth Owner Ledger controlled document. Until the seven controlled documents, implementation gates, and release evidence are reconciled atomically with this decision, this document does not directly authorize a new production owner or a production cutover.

## Executive Decision

Qinao remains a model-neutral deterministic application substrate. It owns protocols, state, authority, planning, verification, audit, recovery, and host integration. Every language or vision model remains outside Qinao SDK behind constrained value-only Provider and Proposal interfaces. No model may directly mutate authoritative state, execute a tool, issue a capability, publish bytes, or promote its own output.

The target local production backend for workspace- or host-managed model weights is now **certified Core AI**, not a permanently MLX-backed default. This changes the target backend decision, not present-tense repository truth:

- before E4/E5 certification and the sealed W6 cutover, MLX/Metal remains the current execution baseline, quality oracle, migration bridge, and shadow comparator;
- Core AI remains non-authoritative until the exact model/profile passes all quality, StateABI, memory, energy, thermal, cancellation, recovery, and release gates;
- after the sealed Core AI-only production cutover, MLX may remain only in a non-Release lab or a separately sealed non-authoritative shadow build/cohort; production Release source, link, factory, and reachability gates reject every MLX Provider/runtime path;
- a failed Core AI candidate yields `deny`, `unavailable`, `quarantine`, or an explicit newly authorized model change—not weaker gates or a hidden backend change.

Core AI-only does not mean ANE-only. A certified Core AI execution plan may use CPU, GPU, Neural Engine, or custom Metal kernels according to measured phase-specific evidence. OS placement requests are not treated as physical-placement receipts.

The approved model portfolio is:

| Role | Approved model family | Production representation | Authority status |
|---|---|---|---|
| selectable main Agent | Qwen3.5-4B | self-converted, signed, certified Core AI assets | external Provider; proposal-only |
| selectable main Agent | Apple Foundation Model (AFM) | system FoundationModels Provider | external Provider; proposal-only; not a conversion target |
| text specialist | MiniCPM5-1B | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| vision specialist | MiniCPM-V 4.6 | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| retrieval embedding mechanism | Granite Embedding 97M multilingual r2 | self-converted, signed, certified Core AI assets | L8 embedding Provider mechanism; not an Agent |

The current intended host default is Qwen3.5-4B. AFM is an explicit user-selectable alternative when its exact device, locale, language, availability, and task-capability profile is certified. This preference is host policy, not an SDK constant.

Names alone never identify production material. Every workspace/host-managed Core AI asset use binds exact source digest, tokenizer/template, conversion recipe, quantization, function graph, custom operation set, StateABI, toolchain, OS/runtime cohort, and certified execution profile.

That full material tuple applies to workspace/host-managed Core AI Provider assets. AFM weights and internal StateABI are opaque: an AFM use instead binds the exact OS/runtime cohort, FoundationModels capability and availability profile, locale/language, input/output schema, safety/tool contract, and Qinao request/profile identities. AFM has no KV, prefix, continuation, or StateABI compatibility with Qwen or another host-managed model.

For workspace/host-managed learned microheads, this addendum also supersedes the old target allowance for a separate Core ML production microhead lane: after the sealed cutover they are certified Core AI assets or absent. Core ML may remain only for unrelated platform/application mechanisms outside this Provider portfolio, never as a hidden learned-model fallback.

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
- the multi-asset residency and approximately 4.2 GB asset footprint do not yet close the active hard-cap plan;
- sustained power/thermal benefit, two-device evidence, representative quality, cancellation, recovery, and release certification remain open.

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

1. L6 normalizes entities, variables, domains, quantifiers, negation, and the question target.
2. L7 creates the exact ConstraintLedger and rejects ambiguous aliases or hidden domain assumptions.
3. L9 or the text specialist proposes one or more assignments with an explicit constraint-to-step map.
4. A deterministic checker evaluates every hard constraint and searches for a counterexample or alternate solution.
5. L10 returns `verifiedUnique`, `verifiedMultiple`, `inconsistentPremises`, or `unresolved`; only the first may be presented as a unique answer.

**Long-text extraction and transformation**

1. L3 partitions by structure and token budget without losing stable byte offsets.
2. L8 retrieves exact spans before dense paraphrase candidates.
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

1. Facts stated by the user are immutable constraints; unstated narrative conventions remain hypotheses.
2. L9 maintains a small discriminative hypothesis portfolio rather than one story.
3. Each follow-up question is selected for expected information gain and answerability, not theatrical novelty.
4. Contradicted hypotheses are retired with receipts; a solved hypothesis must explain all fixed clues.

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

Granite 97M is not an Agent. It implements the existing L8 embedding Provider seam for conditional dense retrieval. It does not critique, delegate, select evidence, or generate a user response.

### 3.2 Delegation rules

Delegation exists only on a pre-terminal branch whose frozen `BASProviderBranchPolicy` rule permits output role `.internalProposal`. A main-model invocation acting in that internal role may emit a typed `DelegationProposal` specifying purpose, required inputs, expected output schema, BudgetLease reference, deadline, and causal parents. The unique `.turnStep/.terminalAnswerCandidate` branch is `answerOnly`, exposes no delegation/tool/effect/continuation schema, and therefore cannot delegate.

L5/L6/L7/L9 semantic decisions plus the installed branch policy and execution-plan owner determine whether the proposed work is authorized; the Turn Runtime only checks graph membership, causal readiness, and receipts. Before terminal-source pin, K1 may reserve resources and K3 may allocate a separately authorized specialist branch. The adapter then materializes the exact request; any required W5 dormant fence completes; only a fresh K3 claim permit can reach K2's at-most-once supervised invocation. After terminal-source pin, no ordinary specialist branch may be allocated; only a purpose `.verifierProposal` branch with output role `.internalProposal`, preauthorized by buffered policy and permitted by the exact K3 addendum state, may follow. A returned specialist artifact enters L7/L9/L10 like any other untrusted proposal.

There is no majority vote for truth. Conflicting outputs remain separate until evidence, authority, deterministic constraints, and L10 verification resolve them. Model confidence is never authority.

### 3.3 Core AI conversion and packaging

All workspace/host-managed Provider weights outside Qinao SDK and intended for local production are converted by the project into Core AI artifacts. The conversion program reuses Apple primitives and tools first:

- Apple `coreai-models` reference implementations where architecture-compatible;
- `coreai-torch` export and Core AI AOT compilation;
- `coreai-opt` compression and calibration;
- Core AI runtime specialization, cache, and state APIs;
- custom authoring, lowerings, and Core AI custom Metal kernels only for missing model-specific operations.

The project must not rebuild PyTorch, SQLite, tokenizers, attention kernels, or runtime facilities already supplied and verified by the chosen stack. Rust is preferred for existing deterministic fusion/canonical hot logic behind narrow C ABIs; SQL owns indexed durability within the established stores; C/C++ is limited to required runtime bridges; Metal is limited to measured kernels unavailable or materially inadequate in public Core AI mechanisms.

Large model assets are signed, architecture-specific, downloadable packages rather than blindly app-bundled blobs. A model asset manifest binds:

```text
source weight digest
license and provenance
tokenizer/template digest
conversion source/toolchain digest
precision and calibration corpus digest
function graph and custom-op digest
input/output names, dtypes, shapes, and dynamic bounds
StateABI and cache-scope version
supported device/OS/runtime cohorts
quality, memory, energy, thermal, and recovery evidence profile
revocation and erasure policy
```

Generic “first output value” behavior is forbidden in production. Every Core AI function has exact named tensors, dtypes, shapes, state count/layout, and bounded dynamic dimensions. Bridges prove contiguity or perform an explicit ledgered copy.

### 3.4 SDK boundary

Qinao SDK declares model-neutral value contracts and deterministic adoption logic. It does not import concrete Qwen, MiniCPM, Granite, MLX, Core AI, or FoundationModels implementations and does not package model weights. External Provider packages depend inward on Qinao contracts.

AFM uses a FoundationModels Provider package. Qwen, MiniCPM, and Granite use external Core AI Provider packages. A Core AI model may be surfaced through compatible system executor facilities where useful, but that does not move the model or FoundationModels runtime into Qinao SDK.

Cross-model change—Qwen to AFM, AFM to Qwen, or either to another lineage—always creates a new Attempt, recompiles context, and obtains explicit host/user consent when policy requires it. It is never a mid-turn or silent fallback.

## 4. Independent Context Windows and Typed Collaboration

Qinao supports many independent logical context windows without pretending the device can host many independent 4B runtimes.

### 4.1 ContextCapsule

Each admitted WorkUnit Attempt and exact Provider step receives an immutable `ContextCapsule` containing only:

```text
TurnOperationRef + AttemptRef
workspace/window/session generations and epoch vector
task purpose and expected output schema
authorized compiled context sections
constraint/evidence/artifact references
model/profile/plan identity
BudgetLease Artifact reference + latest committed K3 budget-use receipt reference
capability attenuation and disclosure class
```

ContextCapsules do not copy lease ceilings, cumulative counters, or a mutable “remaining budget.” A bounded display/diagnostic projection may be derived from the referenced K3 state but is never authority. ContextCapsules also do not contain mutable shared prompts, ambient credentials, database handles, tool handles, another Agent's private scratch state, or raw chain-of-thought.

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

Every node has one purpose, bounded inputs, explicit parents, completion predicates, a BudgetLease reference, and terminal status. Large tasks split into independent WorkUnits only where the join semantics are known. A child cannot inherit broader authority than its parent. A failed child cannot poison unrelated completed siblings.

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

Each iteration is immutable and binds its parent digest, Attempt/snapshot/epoch vector, exact ring, declared edge, BudgetLease Artifact ID, prior committed budget-use receipt when applicable, deadline, capability, and progress witness. It never carries a caller-computed mutable remaining value. The four modes are:

| Ring | Improvement scope | May not change |
|---|---|---|
| ΩR Resource | defer, checkpoint, evict, resume, or request pre-allocation selection of a certified compatible physical plan | semantic answer, risk, policy, model identity; any route change after allocation |
| ΩG Grounding | request bounded evidence, repair coverage, surface conflict | silently select truth or mutate a finished turn |
| ΩD Deliberation | create/revise a bounded candidate or critique branch | commit truth, call a model directly, loop without progress |
| ΩE Effect/Evolution | reconcile an existing saga or produce shadow evolution evidence | replay an indeterminate effect or self-promote a version |

Valid progress is one or more of:

- increased coverage of a required evidence claim;
- fewer unresolved constraints or material conflicts;
- repair of a reproducible verifier counterexample;
- a safer resource state or successful compatible checkpoint;
- monotonic advancement of an already authorized effect/recovery saga.

Longer prose, a different random seed, self-reported confidence, repeated state digest, or a cosmetically revised answer is not progress.

Only a terminal payload whose pair is `converged + convergedVerified` and whose committed K3 budget-use receipt is present may feed authoritative downstream adoption. `cycle_detected`, `no_progress`, `budget_exhausted`, `degraded_with_coverage`, `needs_confirmation`, and `indeterminate_needs_reconciliation` remain typed non-authoritative outcomes.

Self-repair may rebuild projections, indexes, caches, compiled specialization, or replayable material from authoritative events. It may emit quarantine evidence or a quarantine request, but only the existing signed profile/certification authority decides quarantine or promotion. Self-evolution is shadow/offline: it may propose future policy, prompt, conversion, model, or component changes, but cannot rewrite running code, weights, schema, security policy, authority mappings, current LayerCores, or its own certification status.

## 6. StateLake Memory and Context Compilation

### 6.1 One truth and rebuildable horizons

K3's one `synchronous=FULL` EventLog/control nucleus remains the durable command, ordering, and recovery truth. It does not own the semantic meaning of those commands. One encrypted content-addressed Artifact owner stores canonical content exactly once. Current/day/week/month/archive views are rebuildable projections over the same event history, not separately writable memories.

Persisting canonical raw content as an encrypted content-addressed artifact is an explicit approved change from the earlier ephemeral-content-cache posture. The EventLog stores metadata and the artifact reference; cold replay must not depend on an actor cache. Erasure destroys or retires the key/blob and closes every projection, cache, Provider derivative, backup obligation, and rescan before completion is reported.

Every fact uses one bitemporal interval:

```text
validTime: when the fact applies in the represented world
transactionTime: when Qinao learned or changed its record
```

Corrections append supersession or retraction. They do not edit history in place.

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

Stable annotation identity is normalized text artifact ID + UTF-8 byte range + annotation kind. Tokenizer indices are model-specific projections and cannot be stable memory identity.

### 6.4 Multi-lane retrieval

Retrieval proceeds in this order:

1. compile hard eligibility into the physical partition using workspace/window/Attempt/sensitivity/authority/deletion scope;
2. SQL/metadata filtering;
3. exact grep, FTS5, and BM25 retrieval;
4. temporal/episode retrieval;
5. entity/relation retrieval;
6. conditional Granite dense retrieval only when lexical/structural coverage is insufficient or semantic paraphrase is required;
7. optional small-model grounding proposals from the existing certified Core AI NLI/microhead seam or a task-bounded MiniCPM5 branch, with exact entailment/contradiction/unknown schemas and source-span parents;
8. lane-local dedupe, source caps, and candidate receipts;
9. L7 cross-lane eligibility, fusion, grounding, conflict preservation, coverage, diversity, and final State Market.

Granite and the grounding model never see a broader corpus than the hard eligibility partition. Dense similarity or a grounding label cannot override authority, freshness, deletion, confidentiality, exact contradiction, deterministic constraints, or token cost. A small-model label is an untrusted proposal; L7 validates its exact inputs and L10 may verify the resulting claim map. The final State Market balances relevance, authority, freshness, utility, diversity, source concentration, conflict coverage, and token cost only after hard eligibility has passed. Existing FTS, vector, temporal, entity, NLI, and Rust fusion mechanisms are extended behind current owners; no second retrieval engine is created.

### 6.5 Context is compiled, not concatenated

The Context Budget Allocator gives each required section an explicit byte/token budget and priority. The State Compiler:

- includes the task contract, hard constraints, exact high-authority evidence, material conflicts, selected history, tool schema only when authorized, and output/verification contract;
- tokenizes canonical sections once for the selected model/tokenizer identity;
- emits exact section digests, offsets, provenance, authority labels, and an omission ledger;
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
- after allocation, defer, checkpoint, cancel, or recover the exact branch without changing its plan, Provider, materialized request, or call identity;
- stop admitting new heavy work.

Pressure may not silently change model, quantization, context, sampling, tool contract, or answer quality identity.

### 7.2 Core AI function portfolio

A certified Qwen Core AI package may expose separate embedding, trunk, LM-head, prefill, decode, native MTP, and state-management functions. The current multi-asset chain remains one physical Provider invocation with one K3 branch and one terminal observation; its internal asset stages do not become new authority branches.

MiniCPM5 loads on demand for admitted text-specialist work. MiniCPM-V loads only for an admitted visual WorkUnit. Granite may remain warm only when its measured footprint/energy and expected reuse fit K1 policy. AFM remains system-managed, but its latency, cancellation, availability, and semantic capability still enter the Qinao plan and receipts.

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

The projection considers three to five internal candidates drawn only from:

- the finalized answer and its existing artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification;
- an already authorized unresolved horizon thread.

It scores relevance, utility, grounding, authority, freshness, continuity, answerability, cognitive cost, risk, novelty, and diversity. Hard policy, privacy, confirmation, and unresolved-conflict gates run before scoring. A close tie, weak grounding, low utility, or uncertain authorization yields abstention.

At most one compact in-app card appears, only after the answer has ended, the input is blank, no confirmation is pending, and confidence is high. It performs no new tool call, network call, retrieval, Agent invocation, memory write, or speculative external work before a tap. It does not use notifications, Siri, Spotlight, or App Intents.

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
→ TurnOperationRef + active Attempt/ContextWorkspace identity
→ L1 life/resource policy + L5 constitution + L6 situation
→ L4 prior + L7 StateRequirementPlan and hard semantic eligibility predicate
→ K3/L8 snapshot open + materialized hard physical eligibility partition
→ L8 SQL/exact/FTS/BM25/temporal/entity/dense lanes inside that partition
→ L7 post-retrieval hard-eligibility revalidation, dedupe, grounding, conflict and State Market
→ host-selected certified model capability admission
→ L3 context budget + State Compiler
→ K1 heavy-resource reservation
→ K3 typed Provider branch allocation
→ exact materialized Provider request
→ terminal answer-only source pin
→ isolated/remote only: dormant W5 prepare/anchor/arm fence
→ incremental mode only: K3 zero-byte logical visibility row
→ fresh K3 claim permit
→ K2 external Provider at-most-once prefill/decode supervision
→ L9 candidate portfolio/selection
→ bounded ΩG/ΩD remands when justified
→ L12 exact presentation spool
→ L10 exact-output verification and convergence
→ L11 final risk/confirmation decision
→ L14 exact release authorization
→ K3/K4 publication fence and L12 final response
→ optional L12 NextQuestionProjection
```

Prefill routing distinguishes full prefill, same-Attempt suffix continuation, exact prefix cache, and full rebuild. Decode planning distinguishes plain, prompt lookup, native MTP, and same-invocation strategy collapse. Both choices are frozen before branch allocation; neither router owns model identity, truth, authorization, or post-claim route replacement.

The diagram shows the incremental pre-claim visibility row explicitly. Buffered mode omits that row before claim and opens visibility only after terminal seal, the complete authorized verifier suffix, exact spool, and passed L10 exact-output verification. The 2026-07-17 K3 addendum's exact allocate/materialize/pin/fence/claim/seal/visibility ordering governs whenever this high-level diagram is less specific.

### 9.2 Tool, effect, and state path

```text
Provider proposal
→ L10 semantic/exact verification
→ L11 risk and confirmation
→ L13 prepare intent
→ K3 EventLog + outbox prepare
→ L14 exact effect authorization
→ K4 capability claim/anchor
→ K3 arm
→ Zone C durable boundary dispatch/reconcile under the approved idempotency and indeterminate-effect protocol
→ L13 receipt interpretation + StateCommitIntent
→ K3 invisible staging
→ L14 terminal seal
→ K4 attestation/anchor
→ K3 activation or append
```

Models never receive Zone-C call capability. A terminal-answer branch exposes no tool/effect schema. Response and effect branches remain siblings with independent grants and terminal truth. An indeterminate external effect cannot cause the response or effect to be regenerated and dispatched again.

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
2. **Contracts:** governed schema/version/canonicalization, task/context/Agent artifacts, exact Core AI function/StateABI manifests, backward fixtures only for real historical wire versions.
3. **Core AI conversion:** source lock, oracle parity, op inventory, compression, host parity, AOT, device fidelity, placement evidence, task quality, memory, energy, thermal, cancellation, recovery.
4. **Agent isolation:** ContextCapsule scope, branch/capability attenuation, no direct calls, no cross-window state or KV leak, no raw CoT exchange.
5. **Reasoning:** structured oracles for constraints, long-text spans, subjective perspective preservation, lateral hypotheses, cycle/no-progress termination.
6. **Retrieval/context:** hard physical eligibility before ranking, exact/FTS/BM25/dense parity, conflict/coverage, omission ledger, tokenizer/model rebuild rules.
7. **Memory/privacy:** cold replay, bitemporal correction, deletion epoch/tombstone, artifact key/blob purge, projection/cache/Provider derivative rescan closure.
8. **RSI:** progress witnesses, visited digests, BudgetLease/K3-use accounting, adoption only for `converged + convergedVerified` with the committed use receipt, shadow-only evolution.
9. **Effects/recovery:** failure injection at every durable boundary, no duplicate external call/publication, honest indeterminate state, K3/K4/Zone-C restart recovery.
10. **Silicon/release:** two-device identity, load/prefill/decode/cache routes, one HeavyPhase owner, footprint, UI responsiveness, power/thermal run, exact Release-tree seal.

Next-question tests additionally prove one-card maximum, deterministic abstention, no pre-tap work/write, no cross-window disclosure, no durable dismissal learning, and tap-as-new-input semantics.

### 10.3 Promotion is a projection of existing certification

The following lifecycle is a readable projection of the existing `runtime.certification` / `CertifiedBackendProfile` authority and E0–E5 evidence grades. It is not a new ModelPromotionStore or registry:

```text
absent
→ conversionSpike        # E1/E2 mechanism evidence
→ hostParity             # bounded host oracle evidence
→ deviceShadow           # E3, non-authoritative device evidence
→ certifiedCandidate     # E4 complete profile evidence
→ canary                 # E5 controlled production canary
→ production             # sealed Release/cutover receipt also required
```

At any point, evidence may quarantine, demote, or retract the profile. A new source weight, tokenizer/template, conversion toolchain, quantization/calibration, function graph, custom operation, StateABI, OS/runtime cohort, or material execution plan creates a new identity and returns to the appropriate unproven state.

Quarantine or demotion is enacted through the existing signed profile/release authority. It cannot mutate an already sealed Release tree, reactivate a retired path inside that tree, or silently restore MLX as production fallback.

The Core AI gate order is:

```text
source/license lock
→ reference oracle
→ export and op inventory
→ uncompressed numeric baseline
→ compression/calibration
→ host parity
→ AOT compilation
→ physical-device function/state fidelity
→ phase placement profile
→ end-task quality
→ memory/energy/thermal
→ cancellation/recovery/fault injection
→ canary and sealed release
```

Public Apple references and common conversion components are proven first. Then Granite establishes the smallest embedding path, MiniCPM5 establishes specialist text generation, Qwen3.5 is productionized against the existing evidence, and MiniCPM-V adds the multimodal path. This order is a research dependency order, not permission to activate a later wave early. AFM enters through the same Qinao capability/adoption/release contracts without a weight conversion stage.

### 10.4 Existing W0–W6 roadmap remains the only roadmap

This addendum does not create W7 or a parallel “Agent project.” Its work is placed into the existing convergence waves:

| Wave | Addendum responsibilities |
|---|---|
| W0 | freeze owners/writers and legacy bypasses; repair non-vacuous gates/CI; converge iOS 27 floors; perform and independently verify the K4 public-framework/entitlement/lifecycle/IPC/helper-private `WAL + FULL` platform spike |
| W1 | immutable model-neutral Agent, ContextCapsule, reasoning, Provider-asset identity/reference, retrieval, memory, RSI, semantic-DAG, and NextQuestion value contracts only; no concrete `BASStateABI`, execution behavior, or production activation |
| W2 | one K3 `FULL` nucleus, canonical task/Attempt roots, branch control, encrypted content owner, memory/erasure convergence; production model allocation still disabled |
| W3 | snapshot projections, SQL/exact/FTS/BM25/temporal/entity/dense retrieval, grounding, State Market, context compiler, structured reasoning fixtures; Provider paths remain shadow-only |
| W4 | external Core AI/AFM Provider packages, execution plans, concrete `BASStateABI`, K1/K2/K3 handoff, and prefill/decode/cache mechanisms through test, shadow, and device-validation seams; no authoritative semantic executor, canary, or production cutover |
| W5 | durable K4, Provider egress, Zone C, publication/effect/recovery, erasure closure, and direct/legacy path retirement |
| W6 | authoritative semantic-DAG executor integration, replay, full E4 certification, shadow-to-E5-canary promotion, sealed Core AI production cutover, legacy production retirement, multi-device certification and optional 40/30 claim |

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
- the exact Release tree reaches E4, E5 canary, and a sealed production cutover with rollback/revocation evidence;
- all anti-vacuity and fault-injection tests prove their own failure sensitivity.

Success may honestly end in `promote`, `deny`, `quarantine`, or `model unavailable`. The architecture can be complete while the 40/30 performance claim remains denied. Performance evidence never waives quality, security, state, or recovery evidence.

## Prohibited Interpretations

This design must not be interpreted as permission to:

- call the current Core AI Qwen experiment production-ready;
- treat the recorded 10 token/s chain as evidence for 40/30;
- force every Core AI phase onto ANE or infer actual placement from a preference;
- copy AFM weights, convert them, or treat FoundationModels as Qinao-owned state;
- let the main model spawn sub-Agents or let sub-Agents call one another;
- persist/share raw CoT, mutable prompt buffers, cross-model KV, or ambient tool handles;
- turn Granite, `NextQuestionProjection`, RSI, Input Normalizer, Silicon Capability Fabric, or Zone C into a new semantic layer or authority;
- create a ModelPromotionStore, AgentRegistry, ContextStore, MemoryLedger duplicate, RSIManager, second State Market, or hidden/global scheduler inside K3;
- allow self-repair to alter authoritative facts or self-evolution to promote code/weights/policy;
- silently fall back from a selected Qwen Attempt to AFM/MLX or from AFM to Qwen;
- use thermal pressure to lower model quality identity;
- claim erasure while a content key/blob, projection, cache, Provider derivative, or reachable backup remains;
- accept a gate that matched zero candidates, tests, fixtures, or source files.

## Source Grounding and Companion Documents

Normative and committed repository evidence used by this addendum:

- [`2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`](./2026-07-14-iphone-air-future-apple-silicon-architecture-design.md)
- [`2026-07-17-k3-budget-provider-contract-addendum-design.md`](./2026-07-17-k3-budget-provider-contract-addendum-design.md)
- [`qinao-owner-ledger-v1.json`](./qinao-owner-ledger-v1.json)
- [`COREAI_CONVERSION_NEXT_STEPS.md`](../../../BehavioralAISubstrate/Docs/COREAI_CONVERSION_NEXT_STEPS.md)
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
- [Apple coreai-torch](https://github.com/apple/coreai-torch)
- [Apple coreai-optimization](https://github.com/apple/coreai-optimization)
- [Apple LanguageModelExecutor](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutor)
- [Qwen3.5-4B model card](https://huggingface.co/Qwen/Qwen3.5-4B)
- [MiniCPM5-1B model card](https://huggingface.co/openbmb/MiniCPM5-1B)
- [MiniCPM-V 4.6 model card](https://huggingface.co/openbmb/MiniCPM-V-4.6)
- [Granite Embedding 97M Multilingual R2 model card](https://huggingface.co/ibm-granite/granite-embedding-97m-multilingual-r2)

These sources inform conversion and capability hypotheses; only repository-bound device and certification receipts may promote production behavior.
