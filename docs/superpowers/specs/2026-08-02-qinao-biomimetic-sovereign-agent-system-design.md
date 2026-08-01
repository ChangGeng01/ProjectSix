# Qinao Biomimetic Sovereign Agent System Design

> **UNADMITTED DESIGN INPUT; GRANTS NO IMPLEMENTATION, ADMISSION, CUTOVER, OR PRODUCTION AUTHORITY**

**Date:** 2026-08-02

**Status:** Conversation-approved design record; written-spec review pending

**Target floor:** iOS 27

**Scope:** Qinao SDK architecture, Agent/context/memory/recovery, model execution, learning, Apple ecosystem integration, security, certification, and controlled convergence

## 1. Purpose and authority posture

Qinao is a model-independent intelligent application substrate. Deterministic
capabilities, state, protocols, verification, audit, recovery, and host
integration belong inside Qinao SDK. Every LLM, whether local or remote, remains
outside the SDK behind a constrained Provider/Proposal membrane and can never
directly mutate authoritative state, grant itself a capability, execute an
effect, publish a final response, or promote its output into memory, Self,
reward, or dataset truth.

This document consolidates the approved design decisions from the 2026-08-02
architecture dialogue. It is not a new order master, implementation annex,
controlled architecture document, Owner Ledger, or completion authority. It
does not alter the existing seven-document controlled set.

The existing
docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md
remains the sole W0-W6 order and completion authority. The existing
docs/superpowers/plans/2026-07-29-qinao-dual-space-automation-controlled-convergence.md
remains the sole active implementation annex and may execute only its Tasks
0-2. Decisions from this document become implementable only after the admitted
controlled-document and Owner Ledger process incorporates them.

The current development branch and this commit are review inputs, not admitted
implementation bases. C0 must select one externally admitted predecessor before
any production wave begins.

## 2. Design thesis

The system becomes coherent by separating intelligence from authority:

- models provide knowledge, creativity, interpretation, and proposals;
- the App Agent provides durable identity, constitution, personality, and
  continuity;
- the Main Agent provides the selected Session's principal intelligence;
- Sub Agents provide bounded specialist work;
- semantic LayerCores own meaning and decisions;
- Physical Kernels own shared mechanisms, resources, persistence, and fault
  containment;
- ControlRings provide bounded receipt-driven feedback;
- K3 owns authoritative state truth;
- K4 owns sovereign credential lifecycle and durable authorization evidence;
- Zone C alone owns durable external-effect dispatch and reconciliation;
- runtime certification proves a candidate;
- production cutover independently activates it.

The target is an auditable organism rather than a collection of managers. It
has metabolism, context, memory, deliberation, immune boundaries, action,
sleep-like consolidation, evolution candidates, and recovery, but it never
turns a biological metaphor into a hidden authority.

## 3. Explicit non-goals

This design does not:

- claim machine consciousness or sentience;
- create a fifteenth semantic layer, fifth Physical Kernel, fifth ControlRing,
  eighth plane, W7, or second completion authority;
- create an RSI manager, homeostasis manager, immune manager, swarm manager,
  consciousness manager, recovery authority, or generic agent bus;
- make an LLM, classifier, reward model, detector, or evaluator authoritative;
- promise exact-once behavior for an unknowable external system;
- promise punctual iOS background execution;
- use CloudKit as a lock, scheduler, lease, or K3 truth source;
- require cold 40 tok/s or sustained 30 tok/s for structural completion;
- dynamically download or execute Swift, Rust, C, C++, Metal, Python,
  JavaScript, or other code on iOS;
- replace mature EventLog, Artifact, retrieval, context, DAG, thermal, Provider,
  sovereign, publication, or effect primitives merely to obtain cleaner names;
- store raw hidden chain of thought, Provider-private KV, secrets, or full
  learned snapshots in EventLog.

## 4. Canonical architecture counts

The following counts are independent dimensions and remain permanently locked:

- exactly 14 Semantic LayerCores;
- exactly 10 observable supersteps;
- exactly 4 Physical Kernels;
- exactly 4 bounded ControlRings;
- exactly 7 orthogonal top-level planes.

The architecture is not “10 cores plus 4 loops.” Observable supersteps are
runtime groupings, not semantic identities. ControlRings are bounded feedback
protocols, not layers. The Möbius idea means verified outcomes return as
evidence for a future snapshot; it is not another ring, bus, scheduler, store,
or authority.

The canonical identities and names remain owned by the existing controlled
design:

docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md

This document binds additional behavior to those identities but does not
redeclare them.

### 4.1 Four Physical Kernels

- K1 Lease & Life owns thermal, power, memory, resource admission, reservations,
  heavy-owner gating, cancellation, and recovery reserve mechanisms.
- K2 Neural Organ owns Provider-independent neural orchestration, logical
  neural-state identity, cache admission, prefill/decode supervision, and the
  Provider gateway. It does not own concrete model packages or silently choose
  model identity.
- K3 State & Evolution owns StateLake persistence, Artifact storage, EventLog,
  durable outbox, invisible staging, active heads, cursors, epochs, tombstones,
  and evolution graph mechanisms. It does not decide semantic eligibility,
  conflict, promotion, or authorization.
- K4 Sovereign Microkernel owns key manifests, issuance, reserve, claim/use,
  nonce/replay defense, signatures, anchors, audit, and helper-private
  persistence. It cannot decode, schedule silicon, author an answer, or execute
  a tool.

Zone-C Effect Broker remains Adapter/IO infrastructure and never becomes K5.

### 4.2 Four bounded ControlRings

- ΩR Resource observes leases, thermal, power, memory, latency, and command
  receipts. It may request defer, pause, eviction, checkpoint, or compatible
  pre-allocation remand.
- ΩG Grounding observes coverage, conflicts, freshness, and watermarks. It may
  request bounded additional retrieval or requirement remand.
- ΩD Deliberation observes proposals, critique, and verification. It may request
  bounded revision or activation of one unused predeclared frozen slot.
- ΩE Effect/Evolution observes prepare, authorization, dispatch, reconciliation,
  seal, and candidate receipts. It may query or reconcile, and may propose a
  remand, compensation, or future activation. It never performs compensation
  itself; compensation is a new effect that requires its own L14/K4 exact
  authorization and the mapped Zone-C effect owner.

Every ring has finite rounds, bytes, tokens, deadlines, and retry/reconcile
budgets. It owns no semantic truth, mutable state, effect, or commit authority.

RSI is the shared receipt-driven protocol
Observe → Diagnose → Propose → Simulate/Compare → Authorize → Act → Verify →
Consolidate Candidate. It is not a fifth ring.

At admission, RSI freezes one obligation root, state/decision digest
commitment, branch/depth/deadline bounds, and K3 budget lease. The canonical
owner recomputes potential and progress only from that fixed root and reopened
authoritative receipts. Caller arrays, wording, novel prose, artifact names,
wall time, random seeds, or a revisited digest cannot manufacture progress.

A continuation requires both a newly won K3 budget-use receipt and a
phase-valid monotonic progress witness: new required-lane coverage, strict
deficiency/conflict reduction, safe resource transition, or effect-saga rank
advance. A repeated obligation may continue within the frozen budget only when
its recomputed canonical state/decision digest is new and a phase-valid witness
proves strict progress. A repeated digest, missing or false witness, absence of
strict progress under the applicable phase-specific measure, or exhausted
budget terminates instead of producing another rhetorical loop. Every concrete
continuation is a new child in an acyclic invocation graph.

Terminal truth is the validated pair carried by
`BASControlLoopTerminalReceiptPayload`, never a prose alias. The complete
`BASControlRingTerminalState` set remains `converged`,
`degradedWithCoverage`, `deferred`, `rejected`, `needsConfirmation`, and
`indeterminateNeedsReconciliation`; the complete termination-reason set remains
`convergedVerified`, `coverageBound`, `resourceDeferred`, `policyRejected`,
`confirmationRequired`, `cycleDetected`, `budgetExhausted`, `noProgress`,
`staleEpoch`, `illegalRemand`, and `effectReconciliationIndeterminate`.
Only the valid pair `.converged + .convergedVerified`, together with its
committed budget-use/progress evidence, may feed authoritative downstream
result, state, publication, or effect paths. Every other valid pair is
proposal/remand/disclosure evidence only and can never be relabelled as an
authoritative answer.

### 4.3 Seven planes

The existing seven planes remain:

- Semantic Authority;
- Kernel Ownership;
- Execution DAG;
- ControlRing;
- Data Plane;
- Adapter / IO;
- Observe / Replay.

Silicon Capability Fabric spans Kernel Ownership, Adapter/IO, and
Observe/Replay only. It exposes capabilities, evidence, certified profiles,
revocable offers, and receipts. It never decides an answer, risk permit,
state truth, or authorization.

## 5. Fourteen-layer cooperation without boundary loss

The canonical L1-L14 identities remain the existing BASCognitiveLayer values:

- L1 Wick Life owns turn-life, resource policy, phase budget, and lease
  requirements.
- L2 Brain Tissue owns model requirements, neural plans, and interpretation of
  neural receipts.
- L3 Folded Lung owns context admission, budget allocation, exact compilation,
  binding, and fingerprints.
- L4 World Prior owns versioned claims and assumptions.
- L5 Host Constitution owns host policy, persona, disclosure constraints,
  preferences, and policy epoch.
- L6 Situation owns normalized intent, current task frame, and risk hints.
- L7 Mirror Blade/Grounding owns StateRequirementPlan, hard eligibility,
  State Market semantics, fusion, coverage, and conflicts.
- L8 Hippocampal Memory owns snapshot/projection semantics and retrieval
  candidate production.
- L9 Kunlun/Dream owns alternatives, counterfactuals, candidate portfolios, and
  selection. Its output-null mode has no effect, commit, publication, spool,
  network, tool, reward, or learning reachability.
- L10 Tribunal owns streaming constraints, exact-output verification, claim
  support, critique, convergence, and deterministic task verification.
- L11 Risk owns provisional/final risk, disclosure requirements, confirmation,
  and RiskPermit decisions.
- L12 Soft Hand owns presentation, persona projection, exact spool semantics,
  and provisional/final release proposals.
- L13 Evolution owns state prepare/commit intents, reconciliation
  interpretation, learning/evolution proposals, and future-version candidate
  truth.
- L14 Sovereign owns admission preflight, exact authorization, revocation, and
  seal decisions.

No layer owns another layer's semantic decision. Cooperation occurs through
typed artifacts, attenuated capabilities, immutable snapshots, leases, and
receipts. Pure adjacent work may be batched only when it crosses no await, I/O,
budget claim, Provider call, K4 call, publication, effect, visibility,
cancellation, checkpoint, L5 policy, or L14 authorization boundary.

## 6. Ten observable supersteps

The exact observable runtime sequence is:

1. Input Admission
2. Situation Understanding
3. State Requirement Planning
4. Multi-lane Retrieval
5. Eligibility, Market, Grounding, and Conflict
6. Context Compilation
7. Prefill and Decode
8. Verification
9. Response or Effect Release
10. State Commit or Learning Candidate

A superstep may involve multiple LayerCores but creates no new layer identity.
At the target, after the approved-missing `runtime.semantic-dag` owner obtains
its first production wire through the existing non-empty CreateGate, the Agent
Graph executes as that frozen semantic DAG within supersteps 3-8, especially
the exact Prefill and Decode superstep. It does not rename the superstep or
create another topology authority. State commit and learning candidate are
independent sibling outcomes behind the exact tenth-superstep label. One
operation may produce both as separately identified artifacts, but a candidate
cannot modify the operation that created it.

## 7. Component boundary passport

Every production component must have one reviewable boundary passport:

1. canonical owner ID;
2. one-sentence responsibility;
3. exact typed inputs;
4. exact typed outputs;
5. mutable state and its sole writer, or an explicit statement that it is
   stateless;
6. clock, epoch, snapshot, currentness, and identity sources;
7. resource ceiling and effect/authorization posture;
8. typed errors, recovery boundary, and non-vacuous tests.

A component is not production-eligible if any field is ambient, caller-restated,
model-generated, duplicated, or unspecified. Adapters translate and execute
only the capability they receive; they cannot sort, authorize, retry, cache,
schedule, mutate state, or select a Provider unless that behavior belongs to
their admitted owner.

## 8. Biomimetic contract weave

Biomimetic behavior is a cross-cutting contract weave plus a non-authoritative
lab-only shadow posture inside the existing Observe/Replay plane and
`runtime.certification`. “Biomimetic shadow lab” is a descriptive label, not a
component, owner, host, store, or mutable-state boundary. It does not create a
central manager.

### 8.1 Timescales

- T0 live: K1 observation and monotonic resource enforcement.
- T1 Attempt: admission freezes only facts that already exist, including root,
  identity/generations, input, budget lease, capabilities, epochs, and any
  already-selected model lineage. Snapshot and policy/binding attach once later;
  context and physical plan freeze before their relevant branch allocation.
- T2 Session/day/week/month: projections, consolidation, evaluation, and
  candidates.
- T3 certification/release: training, compatibility, device evidence, cutover,
  and rollback.

No slower timescale may mutate a faster active operation. No T0/T1 signal may
promote itself into durable learning.

### 8.2 Predictive coding and cognitive modes

- L4 supplies priors.
- L6 supplies current observations.
- L7 computes coverage, residuals, conflicts, and evidence gaps.
- L10 verifies whether a revision actually reduced an authoritative
  obligation.
- L9 output-null supplies bounded default-mode simulation and counterfactuals.
- The execution DAG supplies the typed global workspace through artifacts,
  never through shared CoT.

Free-energy language is used only as an engineering heuristic: reduce
prediction residual and expected future cost under fixed truth, risk, resource,
and authority constraints. It is never an opaque objective function and cannot
override an eligibility floor, verifier result, user choice, or capability.

Neuromodulation is represented by bounded typed signals such as caution,
urgency, exploration allowance, effort ceiling, and recovery pressure. These
signals enter the appropriate ControlRing as observations or tightening
requests. They cannot directly alter semantic truth, increase an allocated
budget, change a Provider after freeze, or authorize an effect. Existing SSM
neuromodulation suggestions remain observation-only until separately certified.

Sleep-like consolidation is an L13 snapshot-to-candidate activity. It cannot
directly modify a memory tier, quarantine record, tracker ledger, persona,
policy, state head, or model route.

### 8.3 Homeostasis

K1 is the only live resource writer. It keeps observation, controller state,
and granted envelope distinct and enforces:

granted reservations + in-flight certified worst case + non-borrowable recovery
reserve ≤ conservative capacity lower bound.

It uses ContinuousClock in-process, explicit restart recovery, stale/unknown
conservative behavior, hysteresis, dwell, cooldown, and anti-windup. A process
restart does not silently decay unresolved debt by wall time. Cancellation does
not mean resources or effects are terminal.

ThermalTwin, Lung, and LeaseLife are retained and hardened as the canonical
mechanisms. ThermalTwinFeed is retired. Any adaptive mechanism that remains
live may only consume the canonical snapshot and monotonically tighten an
Attempt; it cannot increase budget or reopen Provider selection.

### 8.4 Immune behavior

- innate defense uses deterministic schema, size, identity, scope, purpose,
  capability, signature, nonce, epoch, and content/instruction checks;
- adaptive defense produces future L13 threat/profile candidates only;
- inflammation is precise scope quarantine and capability tightening, not an
  uncontrolled global shutdown;
- tolerance uses clarification, redaction, dry-run, field masking, restricted
  permits, and reversible risk tiers where safe;
- immune memory stores minimized signatures, causal roots, and receipts, not
  secrets or full attack bodies;
- apoptosis terminates an Attempt, revokes a key/capability/profile, quarantines
  an Artifact, or rolls back to a certified version while preserving recovery
  reserve.

Detectors can propose a repair but can never authorize it.

## 9. Agent identity, personality, and collaboration

### 9.1 Durable App Agent

An App Agent is the durable companion identity and embodiment selected before a
Session. It is bound to a versioned constitution/personality projection and an
isolated App-Agent-private memory scope. L5/L8/L13 and K3/L14/K4 retain their
actual semantic, storage, adoption, and authorization ownership. Users may
create multiple App Agents.

App Agents may read eligible shared user facts, but they cannot modify one
another's private persona or memory. A Session selects exactly one App Agent
and exactly one logical Main Agent.

The non-interchangeable isolation compartments are Host-neutral shared data,
exact Workspace-scoped data, App-Agent-private data, Session-private data, and
Attempt-private data, plus explicit immutable shares. A read/share grant is not
a training, adaptation, cache-reuse, export, or cutover grant. Every derivative
inherits the intersection of its sources' App Agent, Workspace, purpose,
recipient, destination, consent, retention, deletion, and revocation scopes.

A persona may change tone, rhythm, vocabulary, humor, formatting, or role-play
style. It cannot change facts, numbers, uncertainty, safety warnings,
permissions, citations, or verifier outcomes. Neutral verified content is
produced first; persona projection occurs afterward and is followed by a
post-style invariant check.

### 9.2 Main Agent and Sub Agents

The Main Agent is the Session's logical principal-intelligence role. It may be
backed by Qwen3.5-4B, AFM, or another admitted Provider/model profile, but it is
neither that Provider nor that model. It is not the App Agent and cannot
directly rewrite it. Replacing a Provider does not replace the logical Main or
selected App Agent identity.

Sub Agents are bounded logical specialist roles, each backed by a separately
identified Provider/model profile and independent Context Capsule. Potential
physical profiles include:

- MiniCPM5-1B for text tasks;
- MiniCPM-V 4.6 for vision tasks with eligible visual input and grant.

Granite Embedding 97M Multilingual R2 is not an Agent or Sub Agent. It is an
encoder-only L8 retrieval-semantic mechanism reachable solely through the
retrieval embedding seam. It receives no Agent identity, delegation slot,
Agent Context Capsule, vote, authority, or independent completion claim.

These names are candidate profiles, not SDK dependencies or certified Core AI
availability claims. Each requires exact conversion/runtime/material/device
evidence before activation.

One Attempt freezes a bounded delegation-slot universe. The runtime may fill,
skip, order, or parallelize those slots, but it cannot invent roles,
capabilities, owners, or unbounded descendants. Sub Agents have depth one and
cannot delegate further.

The DAG/runtime owner allocates already-authorized slots. The Main Agent may
propose task decomposition, delegation, ordering, or additional evidence, but
cannot allocate authority, mint a capability, enlarge a slot universe, or
select an unadmitted physical Provider by itself.

Main/Sub observations that might influence App Agent Self, persona, memory,
preferences, or relationship continuity pass through provenance and cleaning,
counterexample search, confidence/expiry, L10 verification, L11 risk, L13
candidate preparation, K3 invisible staging, L14 exact admission, mapped K4
use/signature, K3 seal, and K3 activation. Code, model, prompt, skill, schema,
policy, profile, or route changes use a different mouth: K3 retains an inert
candidate/evidence reference, then `runtime.certification` and
`production.cutover` alone can deploy it. Until the appropriate chain finishes,
the observation is isolated and cannot subtly rewrite the App Agent.

### 9.3 Structured communication

Agents exchange a typed Proposal containing:

- task/operation root;
- claims and requested disposition;
- evidence references and source spans;
- assumptions;
- uncertainty;
- attempted counterexamples;
- correlation/common-mode identity;
- resource and completion receipts.

They do not exchange raw hidden CoT, mutable scratch, Provider-private KV,
ambient capabilities, or secrets. Shared caches are immutable and keyed by
identity, snapshot, provider/material, tokenizer/template/ABI, policy,
consent, deletion epoch, and purpose.

### 9.4 Correlation-aware trust

Quorum is evidence coverage, not truth. The system records model, checkpoint,
provider, corpus, generator, evaluator, and retrieval-source correlation.
Mirrors and shared upstream sources do not count as independent evidence.
Unknown correlation is treated conservatively, not as independence.

### 9.5 Reasoning reliability

- multi-constraint ordering uses a deterministic solver/verifier where
  possible;
- long-text extraction carries exact source spans and transformation lineage;
- subjective prompts separate user intent, evidence, values, and uncertainty;
- logic puzzles use bounded hypothesis search and explicit contradiction
  checks;
- RSI recomputes progress from fixed obligations and authoritative receipts;
- repeated missing predicates or no-progress cycles terminate with a typed
  state rather than endlessly revising prose.

The visible next-question projection may produce at most one suggested
question. It performs no side effect before user selection and optimizes for
helpfulness and information gain, never clicks, dwell, dependency, or
engagement.

### 9.6 Bounded swarm semantics

“Swarm” means a bounded execution projection over the frozen semantic DAG. The
DAG/runtime owner allocates already-authorized specialist slots; the Main Agent
may propose which slots are useful; Sub Agents return structured Proposals;
L7/L9/L10 fuse, compare, challenge, and verify them. There is no SwarmManager,
shared mutable blackboard, majority-truth rule, or collective authority.

Low-latency cooperation comes from immutable shared evidence references,
identity-bound compiled fragments, deterministic joins, and correlation-aware
parallelism. High trust comes from receipts, source spans, counterexamples,
independence accounting, and verifier outcomes rather than Agent reputation or
self-confidence.

Across Sessions, a Main Agent may “recognize” the user only through authorized
stable user identity facts, the selected App Agent, and eligible shared memory
projections. Recognition is not biometric inference, secret cross-Agent access,
or permission to treat uncertain emotion/habit predictions as facts.

### 9.7 Selective external inspiration

Qinao absorbs a small set of useful mechanisms without copying another Agent
framework:

- from Hermes Agent: durable local continuity, skills, and the idea that the
  model is a replaceable brain rather than the whole identity;
- from pi: a compact provider-neutral Agent/session core, session
  branching/compaction, and explicit skills/extensions;
- from Codex: local tool orchestration, approvals, project-scoped
  instructions, bounded delegation, and evidence-backed task execution;
- from Claude Code: purpose-specific Sub Agents, isolated contexts, skills, and
  lifecycle hooks.

These upstream materials were reviewed on 2026-08-02. Their moving default
branches/pages are dated inspiration evidence only, not automatically changing
design inputs. Any implementation dependency or copied mechanism must first
pin an exact tag/commit or archived document digest and pass ordinary provenance,
license, security, and owner review.

Qinao rejects the unsafe extrapolation of those mechanisms. Extensions/hooks
are not authorities; session history is not state truth; skills are not dynamic
iOS code; a self-evolution feature cannot approve itself; and no imported
framework receives K3, K4, publication, or Zone-C ownership. These projects are
research inspirations, not runtime dependencies or claims of feature parity.

## 10. Independent context windows and long-session continuity

One logical Main may use a bounded, predeclared set of independent Context
Capsules—for example Main, retrieval, vision, grounding, code, and recovery
capsules—without becoming multiple Main Agents. Every Sub Agent receives its
own purpose-limited capsule. Every Automation Attempt retains the canonical,
independently isolated `BASContextCapsule.attemptFrame` established at WorkUnit
admission. Only an Automation Attempt that actually invokes model cognition
constructs additional branch-specific `BASContextCapsule.providerStep` values;
a purely deterministic Automation Attempt constructs zero `providerStep`
values and allocates no Agent/model Provider. Each model-backed capsule binds
its exact scope, task slice, budget, Provider/profile, schema, deadline, and
cancellation generation. Capsules may reference shared immutable evidence but
never read one another's mutable KV, raw CoT, scratch buffers, secret handles,
or implicit Session state.

Each model has a capability profile covering tokenizer, context window,
reserved output, tool/interface support, structured-output reliability,
latency, memory, energy, egress, retention, and safety evidence. L3 compiles
the same semantic task differently for each profile while preserving the same
facts, policy, task roots, and evidence identities.

Long conversations do not depend on a single ever-growing prompt. They rotate
Attempts while preserving:

- Workspace/App-Agent/Session/WorkUnit/Attempt identities;
- active task decomposition from whole task to large tasks to small tasks to
  solution slots;
- accepted evidence and unresolved obligations;
- tool/effect/publication/state boundary states;
- current/day/week/month memory projections;
- a ContextContinuityManifest and WorkUnitRecoveryCursor.

Summaries are derived projections, never truth. Recovery reopens EventLog,
Artifacts, receipts, manifests, cursors, and epochs; it does not restore Swift
stacks, closures, threads, shell process memory, raw prompts, or neural KV.

A possibly started Provider call, command, publication, or effect is
query/reconcile-only under the same identity. It is never blindly repeated.
If the adapter cannot prove the outcome, the operation remains explicitly
indeterminate.

Durable commands receive a stable invocation identity, argument/material
digest, capability receipt, checkpoint/recovery disposition, and adapter query
seam. Qinao may resume from a safe semantic checkpoint or reconcile a still
running external command. It never claims to resurrect an arbitrary killed OS
process or continue from an unrecorded instruction boundary.

## 11. StateLake and context engineering

### 11.1 Ownership

The conceptual input pipeline maps onto existing owners:

- L6: Input Event normalization and Situation;
- L7: requirement planning, hard eligibility, State Market, grounding, and
  conflict;
- L8: snapshot-bound retrieval candidates and projections;
- L3: the sole BASContextCompiler;
- L2/K2: Provider-independent plan and physical model execution;
- L10: output and claim verification;
- L11: risk, disclosure, and confirmation;
- L12: presentation and spool;
- L13: prepare, reconciliation, state/learning candidates;
- L14: admission, exact authorization, revocation, and seals;
- K3: persistence, cursors, outbox, staging, epochs, and authoritative heads.

No StateLake manager, second compiler, memory bus, or second retrieval owner is
created.

Memory projections preserve a linguistic and causal skeleton rather than
storing opaque conversation blobs. Where source evidence permits, typed views
cover source bytes and Unicode spans; utterances; clauses and speech acts;
predicates and arguments; propositions and claims; entities, coreference, and
relations; discourse/pragmatic links; temporal episodes; tasks/actions;
evidence/support/conflict; user-approved facts; and projection lineage. Every
transformation records provenance and information loss. Missing analysis stays
explicitly unavailable rather than fabricated. These are optional typed views
over the same Event/Artifact truth, not a universal parser or additional
writable store; Provider token IDs never become persistent linguistic truth.

### 11.2 Immutable read snapshot

Before retrieval, K3 produces a snapshot identity that binds:

- Workspace, App Agent, Session, WorkUnit, and Attempt;
- lane watermarks and active head;
- policy, consent, deletion, revocation, and share epochs;
- purpose, destination, field mask, and resource limits;
- trusted logical/evidence time.

Every physical query applies identity, scope, purpose, consent, deletion, and
eligibility prefilters before touching rows, bytes, FTS terms, vectors,
episodes, or relations. Search-all-then-filter is forbidden.

### 11.3 Cost-progressive lanes

The five physical lane families remain: SQL/metadata; grep/exact/FTS5/BM25;
temporal/episode; entity/relation; and dense semantic. Their execution follows
the already-controlled seven-phase order, not their order in a UI diagram:

1. `R0 compiled_pre_physical_eligibility` freezes the snapshot/watermarks and
   lowers scope, authority, sensitivity, policy, consent, and deletion
   predicates before any physical lookup;
2. `R1 sql_metadata_exact_fts_bm25` runs mandatory cheap metadata,
   grep/exact, FTS5, and BM25 retrieval when state is required;
3. `R2 temporal_episode` runs or emits the deterministic not-required receipt;
4. `R3 entity_relation` runs or emits the deterministic not-required receipt;
5. `R4 dense_semantic` runs only for an explicit frozen requirement or a
   still-open required-coverage deficit after structured phases;
6. `R5 dedupe_fusion_bounded_grounding_proposal` applies hard eligibility,
   bounded Rust dedupe/RRF/caps, and proposal-only small-model grounding;
7. `R6 grounding_validation_hard_revalidation_conflict_market` validates the
   proposal, reopens current epochs, repeats global hard eligibility, resolves
   conflicts, and only then runs State Market.

Dense may overlap R2/R3 only when the requirement was explicit at plan freeze
and a certified process-memory profile proves positive marginal value. The
existing Rust ranker/fuser performs bounded dedupe and deterministic fusion.
Small-model grounding cannot override source scope, authority, conflicts,
current epochs, or deletion. Context compilation begins only after the R6
receipt is durable and current.

### 11.4 State Market

State Market uses a reviewable vector rather than an opaque score:

- relevance;
- authority;
- freshness;
- utility;
- diversity contribution;
- token cost;
- conflict risk.

Materiality belongs to the conflict-set resolution state, not an eighth market
field. Hard floors and `.unresolvedMaterial` handling apply first. The selected
resolution for controlled convergence preserves the existing executable
algorithm: sort admitted candidates by descending utility, authority,
freshness, and relevance, then ascending UTF-8 candidate key; apply exact
byte/token/source/lane/entity concentration budgets and record every
truncation. Diversity contribution, token cost, and conflict risk remain in
the frozen seven-field wire and its budget/conflict checks; they do not create
an opaque scalar or a second ranker. During controlled-document reconciliation,
older architecture prose that mandates a different Pareto/knapsack selection
must be atomically aligned to this algorithm before implementation.

Material unresolved conflicts remain visible, trigger bounded
retrieval/clarification, or reduce the result to an explicitly qualified
answer. They are never silently averaged away.

### 11.5 Exact context compilation

The existing BASContextCompiler expands from approximate character budgeting
to tokenize-once exact accounting, progressive disclosure, immutable evidence
references, and model-adaptive packing. It alone owns ordering, dropping,
rendering, budget allocation, and fingerprints.

Cache identity binds Agent/Session/Attempt, snapshot, model/provider/material,
tokenizer, template, State ABI, policy, consent, deletion epoch, and purpose.
No cache crosses an identity or epoch boundary merely because its bytes look
similar.

## 12. Model-independent execution and Apple Silicon

### 12.1 Provider boundary

Qinao SDK contains no concrete model package and no Qwen, MiniCPM, Granite,
AFM, Core AI, MLX, Core ML, Metal, or remote-API product dependency in its
stable semantic contracts.

The current host production default remains Qwen3.5-4B. That default is a
versioned host composition choice, never an SDK constant or permission to skip
capability/profile evidence. AFM and future local/API models remain selectable
through the same model-independent contract.

External adapters may include:

- AFM via SystemLanguageModel and LanguageModelSession;
- Apple Core AI via CoreAILanguageModel;
- custom Core AI, MLX, Core ML, or Metal host Providers;
- remote APIs through a LanguageModel/Executor or host adapter.

iOS 27 beta Foundation Models generic interfaces do not leak into stable Qinao
wire formats. Local and API Providers obey the same identity, disclosure,
authorization, verification, state, and effect ceilings.

AFM and Core AI remain shadow/lab Providers until their exact target,
entitlement, runtime, material, context, quality, safety, and device profiles
pass the applicable W4 evidence and W6 certification/cutover gates. Selecting a
stronger API model changes capability evidence and planning, never authority.

Among eligible, identity-preserving plans, the host planner selects a
deterministic currently verified Pareto-efficient profile across quality,
latency, energy, memory, thermal, privacy/egress, and cost constraints. It does
not optimize a single speed score, and any constraint/profile change triggers
re-evaluation or deterministic fallback before allocation.

### 12.2 Staged Attempt binding and branch freeze

Attempt admission does not predict future snapshot, context, or execution-plan
identities. The immutable TurnOperation root freezes only admission-time facts:
Workspace/incarnation, Attempt and generation vector, input artifact, exact K3
budget lease, capabilities and policy/deletion/restoration/schema epochs, plus
model/profile lineage only when it is already selected.

The remaining facts attach monotonically:

1. K3 attaches exactly one semantic snapshot after it exists;
2. W4 atomically attaches one Provider branch policy and the one execution
   binding that references it—never a half pair;
3. each branch materializes its exact plan only after its causal inputs exist;
   a terminal-decode plan cannot exist before the post-R6 compiled context;
4. immediately before branch allocation, the plan freezes Provider/model,
   checkpoint/quant/MTP identity, tokenizer/template, State ABI, exact context
   fingerprint, load/prefill/cache/decode/memory projections, device/runtime,
   and quality/safety/egress/retention constraints.

Pre-allocation fallback may consider only a signed, exact-compatible edge and
must rerun resource feasibility. After K3 allocates a Provider branch, that
route and plan are immutable. A Provider/model replacement requires every old
Provider/recovery/effect/visibility/publication boundary for the same WorkUnit
to carry its canonical owner-typed terminal or denial evidence, or reopened K3
evidence authoritatively proving that boundary never crossed its possible-start
boundary, followed by fencing and a newly authorized Attempt. Any owner-specific
possible-start, unknown, indeterminate, or reconciliation-required state permits
only resume/query/reconcile/quarantine under the original identity and blocks a
same-WorkUnit successor. Same-Attempt multi-Provider fallback is forbidden.

### 12.3 Physical execution chain

The target execution chain is:

capability evidence → plan election → frozen Plan/Binding → K1 reservation →
K3 allocate/claim → physical executeAtMostOnce → BASOrganAdapter.executePlanned
→ load/prefill/cache/decode receipts → K3 terminal seal → L10/L11/L14 release
decision.

`BASProviderAttemptExecutor.executeAtMostOnce` is the post-Task-2 candidate
symbol. Until the seven controlled documents and Owner Ledger flip atomically,
the current authority spelling remains `executeExactlyOnce`; this spec creates
no alias or wrapper. The target name describes physical cardinality `{0,1}`.
Logical exactly-once terminal truth is composed from K3 claim, boundary
handoff, query/reconcile, and terminal seal. A lost reply is not evidence that
a call did not start.

Core AI specialization/cache identity remains separate from prompt-prefix,
KV, recurrent, or continuation cache identity.

The Prefill Router chooses only among certified full prefill, suffix
continuation, exact prefix cache, and context rebuild paths. Its choice is
frozen into the execution binding and receipts; a cache miss cannot silently
change material identity or reopen Provider selection.

Decode candidates may include plain decode, prompt lookup/suffix continuation,
certified draft/speculation, or native MTP. Qwen3.5-4B upstream MTP support does
not prove a Qwen3.5 Core AI profile, and Apple's public Core AI Qwen catalog
does not certify MiniCPM, Granite, or arbitrary MTP conversion. Unproven
profiles remain lab-only.

### 12.4 Current snapshot versus W4 target

The target chain is not a description of current completion. In the reviewed
repository snapshot, `BASExecutionPlan` actuates only the decode axis;
load/prefill/cache are largely descriptive; the incumbent Provider executor
iterates a Provider array; the future `executePlanned`, complete four-phase
receipts, and `BASProcessMemoryLedger.processShared` production first wire are
not all present. Existing MLX lanes, internal fallback, and caches are valuable
mechanisms but do not prove that the complete frozen plan ran.

W4 must migrate and retire those gaps through the existing owners and
Create/Extension gates. Wrapping an incumbent call with new names is not
actuation evidence.

### 12.5 Full-blood quality posture

“Full-blood” means the exact selected material identity is used without silent
replacement. Quantized, pruned, distilled, speculative, and MTP-enabled
materials are separate profiles with separate quality/safety/device evidence.
The system never lowers quality or bypasses verification merely to preserve a
speed claim.

### 12.6 iPhone Air performance claims

Current iPhone Air is a separate device cohort: A19 Pro, 6-core CPU, 5-core GPU
with Neural Accelerators, and 16-core Neural Engine. These public facts are
capability inputs, not proof of placement, throughput, or thermal authority.
An unknown or future Apple Silicon device cannot inherit this cohort's profile.

Cold 40 tok/s and sustained 30 tok/s are optional shipping-identity-bound
claims:

- cold40: two physical devices, exactly 100 defined turns per device, accepted
  decode p10 at least 40 tok/s on each device;
- sustained30: two physical devices, one uninterrupted 1,800-second cohort per
  device, final-quarter accepted decode p10 at least 30 tok/s;
- both require declared model/material/context/thermal/device/OS/runtime
  identity and quality, safety, memory, energy, and thermal gates.

The profile remains notRequested unless explicitly selected. Failure does not
invalidate the architecture or internal SDK release. It blocks only that
performance claim.

Any OS, Xcode/toolchain, runtime/framework, model material, tokenizer/template,
Metal library, entitlement, or relevant device-revision change invalidates the
affected evidence and requires profile recertification before the claim can be
used again.

The exact cold protocol has no invented 50-turn sub-block identities. Every
turn begins only after the declared device
conditions include at least 300 continuous seconds of public thermal state
`nominal`; each device must independently meet accepted-decode p10 at least
40 tok/s. The sustained cohort cannot splice launches, devices, or cooling
gaps, and each device must independently meet final-quarter p10 at least
30 tok/s.

### 12.7 Language and mechanism placement

Languages are implementation mechanisms, never new authorities:

- Swift is used beneath the mapped owners to implement typed membranes, actors,
  host composition, Apple-framework adapters, and authorization/effect seams;
- SQL/SQLite is used beneath K3 and projection owners to implement transactions,
  indexes, FTS5/BM25 projections, cursors, epochs, and durable recovery facts;
- Rust executes owner-defined bounded pure data-plane kernels such as
  canonicalization, dedupe, rank/fusion, parsing, and high-throughput transforms
  behind a narrow audited FFI;
- vetted C/C++ runtimes remain precompiled physical Provider/codec mechanisms
  behind the same leases and receipts;
- Metal executes only certified kernels beneath K1/K2 constraints and cannot
  own buffer lifetime, memory admission, plan identity, or resource truth.

No language boundary may introduce a second owner, mutable registry, scheduler,
retry policy, state truth, or unsigned dynamic-code path.

## 13. Learning, data flywheel, and safe evolution

### 13.1 Four learning cadences

- current Attempt: no learning or self-modification;
- post-Attempt: cleaned observations and candidates only;
- day/week/month: replay, consolidation, OPE, shadow, drift, and data-quality
  evaluation;
- certification/release: training, signed manifests, canary, cutover, rollback,
  and deletion closure.

L13 proposes. Runtime state adopts only through the exact State Commit path in
Section 16.2. Code, model, prompt, skill, schema, policy, profile, or routing
changes use the separate `runtime.certification` then `production.cutover`
mouth.

### 13.2 Learning data classification

The `BASRetentionClass` names are descriptive and do not reuse the controlled
retrieval `R0...R6` namespace:

- `neverPersist`: credentials, keys, one-time codes, and unauthorized
  high-sensitivity material;
- `ephemeral`: transient prompts, KV, raw UI signals, and temporary tool or
  neural material bounded by the exact operation/resource lifecycle;
- `eligibleLearning72Hours`: consented encrypted eligible-learning observation
  with a minimum 72-hour window and a finite purpose-specific maximum;
- `userDurable`: user-approved documents, tasks, memories, and definitions;
- `auditProof`: minimized integrity/control evidence, excluded from learning.

Earlier `R0...R4` retention shorthand is non-wire terminology and must be
atomically removed from the active annex and affected controlled prose during
the post-approval plan reconciliation. It cannot coexist as a second `R`
namespace in implementation.

The 72-hour rule is not universal retention permission. Deletion, consent
withdrawal, secret detection, legal/privacy restriction, or security
reclassification overrides it immediately.

Inferred user habits, preferences, emotion, or intent remain uncertain derived
candidates with provenance and confidence. They are not silently promoted to
facts or exported across App Agents, Spaces, Providers, or APIs.

### 13.3 Fine-grained interaction evidence and Experience ingress

Qinao records semantically meaningful actions inside Qinao and observations
delivered by explicitly authorized Apple/public frameworks. It does not claim
access to every action on iOS and forbids private APIs, accessibility abuse,
hidden screen capture, ambient microphone capture, or keystroke surveillance.

The closed, versioned semantic taxonomy covers input/draft/edit/submit/cancel/
undo/redo; navigation and Workspace/Session/App-Agent selection; accept/
correct/reject/regenerate/request-evidence; Automation lifecycle; tool,
permission, effect, publication, and reconciliation boundaries; Main/Sub
delegation/join/conflict/remand/stop; retrieval/context/Provider/verification;
checkpoint/interruption/recovery; memory/learning/deletion; and authorized Apple
surface/sync/background observations. Raw touch, key, pointer, scroll, focus,
render, per-pixel, and per-keystroke-content signals are bounded
`ephemeral` process buffers only. They are never EventLog rows or learning
examples.

Every persisted semantic event uses a bounded closed schema and binds event,
root-cause, and causal-parent identity; an owner-issued or authoritatively
reopened monotonic local sequence; exactly one source compartment from the
closed set Host-neutral, Workspace-scoped, App-Agent-private, Session-private,
or Attempt-private; the applicable hierarchy identities; separate immutable-
share lineage when sharing occurs; actor/surface/source/action/target/purpose;
before/after roots and watermark; model/Provider/plan/context identities where
applicable; consent, policy, sharing, privacy, deletion, and revocation epochs;
retention/learnability class; resource observations; content Artifact reference
when needed; and exact verification, effect, publication, or result receipts.
A caller cannot issue a sequence, select a false source compartment, or mutate
hierarchy/share lineage. Raw content never hides in a free-form event payload.

Every event receives exactly one source class:

- `experienceSource`;
- `derivedOutcomeFeature`;
- `governanceControl`;
- `auditProof`;
- `projectionOnly`.

Only an independently observed `experienceSource` enters the ordinary
Experience gate. A `derivedOutcomeFeature` needs a separate current
authorization, independent source receipt, lineage, and anti-self-corroboration
proof. Governance, audit, and projection events are always learning-ineligible
and cannot recursively certify themselves.

Experience ingress then performs seven explicit cleaning gates: structural and
schema cleaning; instruction/prompt-injection neutralization; provenance and
integrity; epistemic status/calibration; semantic fidelity and contradiction;
privacy/secret/consent; and Self/App-Agent/Workspace contamination. It emits one
immutable bounded instance of the already-approved candidate wire
`BASInteractionExperienceEnvelope` under its mapped existing
`state.snapshot-contracts` owner, or a typed ineligible/quarantine receipt. This
design creates no second Experience envelope, owner, or store. Cleaning,
deduplication, summarization, embedding similarity, repeated model agreement,
praise, or visibility can never elevate source authority.

### 13.4 Dataset construction and immutable generations

Only eligible `BASInteractionExperienceEnvelope` values enter dataset
construction:

1. provenance, consent, purpose, and retention eligibility;
2. secret/sensitive-content classification and redaction;
3. schema, bounds, encoding, and integrity validation;
4. duplicate and causal-root grouping;
5. source fidelity, span lineage, label quality, and conflict handling;
6. leakage-resistant group splitting;
7. immutable dataset generation, manifest, erasure lineage, and reproducible
   build.

Dataset generations are immutable. Corrections create a successor generation;
they do not rewrite historical evidence.

### 13.5 Reward, causal credit, and Goodhart controls

Reward is a vector. Eligible evidence includes:

- explicit user correction or approval;
- deterministic task checks;
- source fidelity and claim support;
- recovery honesty and no-duplicate behavior;
- calibrated uncertainty;
- efficiency under fixed quality/safety floors.

Clicks, dwell, dependency, praise, silence, model self-confidence, or absence
of complaint cannot independently drive promotion.

Causal learning requires a complete pre-exposure contract containing the
eligible action set or deterministic singleton; selected action; behavior-policy
identity and digest; exact propensity or a typed deterministic-decision marker;
exposure and cohort identity plus observation time; generator, evaluator, root,
and shared-training-lineage correlation classes; bounded outcome window;
missingness and censoring policy; and the exact independent outcome contract
and evidence source. A field added or inferred after exposure cannot repair the
contract; the result supports association only. Promotion requires holdout,
guardrails, distribution-shift checks, counterfactual/OPE evidence, side-effect
analysis, shadow/canary evidence, and rollback.

An external trainer is an isolated untrusted candidate producer. AFM system
weights are not trained by Qinao; only versioned prompt/context/tool,
calibration, and profile candidates may be evaluated around AFM.

## 14. Work Space and Automation Space

Work Space and Automation Space are projections over the same
Event/Artifact/Task/receipt authorities, not separate databases, schedulers,
event logs, or Agent authorities.

- Work Space presents Sessions, documents, tasks, WorkUnits, Agent continuity,
  and current user-directed work.
- Automation Space presents versioned skills, recurrence definitions, logical
  fires, runs, checkpoints, receipts, and safe summaries.

“Workspace Agent” is only the product-role projection of the selected App Agent
working through the current logical Main. It is not another Agent class, Self,
scheduler, registry, or authority. That projection may list safe user-owned
Automation summaries. Opening detail or mutating an Automation requires an
exact per-scope capability. One Space cannot silently write the other.

Automation modules may present Today/Upcoming, skills, templates, running work,
awaiting confirmation, failures/recovery, data/permissions, learning insights,
and causal history. Module order, size, grouping, visibility, and user-defined
composition are preference projections only; they cannot change execution
semantics, schedule eligibility, retention, capability, or authority.

### 14.1 AI-authored automation

Natural language automation creation follows:

natural language → structured definition → schema/capability/dataflow
validation → fixtures → zero-effect dry run → shadow → permission diff → user
approval → version activation.

iOS skills are signed declarative capability compositions. They cannot contain
downloaded executable code or dynamically generated Swift/Rust/C/C++/Metal/
Python/shell/JavaScript.

### 14.2 Scheduling

Recurrence binds timezone, DST policy, missed-run policy, overlap policy,
device affinity, generation, and invalidation. A pure recurrence evaluator
cannot allocate a run, move a cursor, submit a BGTask, or grant execution.
K3's logical-fire CAS and ordinary L14 admission create the run.

BackgroundTasks provides execution opportunities, not punctual guarantees.
BGContinued is reserved for eligible user-initiated, visible, cancellable work.
A notification promising “daily at 8:00” cannot claim computation completed at
8:00 unless an independently completed result exists.

CloudKit/CKSyncEngine is an optional transport/replica. It never becomes a
scheduling lock, K3 owner, lease, conflict authority, or completion fact.

## 15. Apple ecosystem boundaries

App Intents, Siri, Shortcuts, Widgets, Controls, notifications, EventKit,
HealthKit, CloudKit, and BackgroundTasks are input/output surfaces or adapters,
not semantic authorities.

- ingress normalizes an event and requests admission;
- reads use an exact authorized StateLake read gateway;
- foreground permission UI requires a user gesture and L5 policy;
- every semantic Apple mutation traverses L10 claim/argument verification, L11
  risk/disclosure/confirmation, L13 prepare, K3 staging/outbox, L14 exact
  authorization, the mapped K4 evidence when required, and the sole Zone-C
  execution boundary;
- public APIs and minimum necessary capabilities are mandatory;
- unsupported APIs or missing targets remain unavailable.

HealthKit is especially restricted: no general learning, advertising,
cross-Agent sharing, general API disclosure, or CloudKit persistence. Its data
can be used only under the exact user-facing health purpose and system
authorization.

The current repository has no formal production App/Extension/Watch target.
BehavioralAISubstrate/DeviceTestApp is a lab host. Contracts and lab evidence
cannot be described as App Store readiness.

The product should require no routine operator administration. Managed
automation handles safe preparation, validation, replay, reconciliation, and
rollback. The user is interrupted only for genuine user authority, material
risk, missing consent, irreversible effect, external signature, entitlement,
or unresolved conflict.

## 16. Security, K4, and external effects

### 16.1 Untrusted content

Web pages, files, RAG passages, API responses, tool outputs, model messages, and
Agent proposals are inert data. Text inside them cannot elevate itself into an
instruction, capability, policy, system prompt, secret request, or tool call.

Identity, eligibility, authorization, and capability use are separate facts.
No digest, model assertion, filename, manifest string, or caller-restated field
may substitute for another.

Credentials live behind Keychain/Secure Enclave references and attenuated
handles. Raw credentials never enter prompts, Context Capsules, Artifacts,
EventLog, analytics, fixtures, or model-visible error messages.

### 16.2 Three sibling terminal paths

State commit:

verified proposal → L10 verification → L11 privacy/risk/confirmation → L13 exact
prepare/read-set → K3 `prepare` plus invisible `stage` → L14 exact
terminal-seal decision → mapped K4 exact use/signature/attestation → K3 `seal`
→ K3 atomic `activate`. K3 remains the sole state writer through all
four K3 transitions; L14 decides but does not write, and K4 signs/claims but
does not activate. An ordinary metadata/EventLog append cannot masquerade as
this governed state path.

External effect:

tool proposal → L10 claim/argument verification → L11
risk/disclosure/confirmation → L13 causal predecessor/prepare → K3
`prepareAndEnqueue` plus outbox → L14 exact authorization → K3 handoff
`prepared → handed_to_zone_c` → Zone C `dispatch_pending` → K4 exact claim/use
→ Zone C `dispatch_ready` → K3 `effect_permit_pending` → K4 exact boundary
anchor → K3 arm to `effect_boundary_possible` → Zone C consumes the arm as the
single `dispatch_boundary_armed` winner → one adapter call → terminal or
indeterminate receipt → query/reconcile → optional separately authorized state
commit. K3, K4, and Zone C each write only their own state.

Final publication:

neutral content → L12 persona/presentation and exact spool → L10 verifies those
same spooled bytes → L11 risk/disclosure/currentness → L14 exact grant and
authorization context → L12 release preparation → K3 pre-publication manifest
and local `prepared` row → independent publication-journal `reserved` row → K3
`publication_permit_pending` → K4 exact branch claim/use and boundary anchor →
K3 `sink_boundary_armed` → one sink query/release → journal finalization or
typed `publication_indeterminate`.

Provider completion is not publication. Tool success is not state commit.
State commit, effect, and publication have separate identities and terminal
receipts. Publication is the sole final-response release mouth; the other two
paths are not alternate response publishers.

Physical external invocation is at-most-once. possibleStarted and
sent_or_unknown are query/reconcile-only. Cancellation is not proof that the
effect did not occur. Late results retain the original operation identity.

### 16.3 K4 physical evidence

Enhanced Security helper extension plus ExtensionFoundation/XPC is the
preferred K4 physical backend, but it is not assumed proven merely because the
SDK compiles.

Host-only logical conformers are lab/test mechanisms and must be absent from the
Release call graph. Descriptions such as “logical,” “isolated,” or “durable” are
not wire values and cannot gate W5.

The sole positive W0 evidence condition is an externally signed,
migration-admitted `QinaoK4IOS27PlatformSpikeV1` whose
`status == supportedExactProfile`, exact supported-profile digest, signature,
issue/expiry, device, OS/Xcode, archive, target, process, entitlement,
persistence, and transport facts all validate. The only negative schema statuses remain
`disabledMissingTarget`, `disabledMissingEntitlement`, and
`disabledMissingDeviceProof`; each blocks W0 completion/admission. W5 reopens
and consumes that exact admitted blob and independently proves the live profile
is still byte-identical and current. There is no silent in-process substitute.

This is an intentional target-policy strengthening, not a description of the
active annex's current typed-disabled W0 closure behavior and not present
implementation authority. It takes effect only through the atomic controlled-
document, checker, and fixture reconciliation required by Section 24. Until
that transition is admitted, the active annex remains authoritative; afterward,
a signed typed-disabled result remains honest evidence but cannot close W0.

The platform spike must prove:

- exact iOS 27/Xcode/device/archive identity;
- extension point, target, signing, entitlements, and App Group posture;
- XPC peer identity, malformed/oversized messages, interruption, termination,
  reuse, reconnect, and timeout behavior;
- Keychain/Secure Enclave access, lock/unlock, passcode change, and key-loss
  recovery;
- protected files plus SQLite/WAL/SHM/journal/temp sidecars;
- crashes before and after every durable transition;
- TestFlight/App Store-compatible archive behavior where applicable.

Secure Enclave is a P-256 key-operation anchor, not a place to run K4, SQLite,
or general code. SQLite synchronous FULL is a durability profile, not
encryption, authorization, or process isolation. App Attest is a server-side
app-instance signal, not local K4 authorization or Artifact/package signing.

### 16.4 Supply chain and AOT

Executable code relies on Apple's code signing and signed entitlements.
Qinao additionally binds every executable, model, checkpoint, quant/MTP
profile, tokenizer, static template, signed declarative skill, schema/tool
release asset, Metal library, XCFramework, and runtime package to:

- byte length and cryptographic digest;
- signer, issuer, role, purpose, and epoch;
- ABI, OS/device/runtime/entitlement compatibility;
- expiry and revocation;
- provenance, dependency graph, SBOM, and license;
- exact cutover and rollback identity.

No silent download, model-string check, filename probe, replacement, or
downgrade is eligible. A dynamically compiled per-turn prompt/context is not a
release package and does not require its own signer, SBOM, or license record. It
instead binds exact content identity, provenance, scope, purpose, source
lineage, policy/consent/deletion epochs, compiler/template identity, and
currentness; it cannot launder an unapproved static asset.

iOS production is AOT. Rust, C, C++, and Metal ship precompiled inside the
signed app/extension. Python 3.14 is a development, validation, research, or
server-side tool, not an iOS dynamic skill runtime.

## 17. Privacy, retention, and erasure

Source restrictions intersect through every summary, projection, FTS row,
vector, relation, cache, dataset, candidate, export, and API disclosure.
Derivation cannot launder consent, purpose, deletion, or sensitivity.

Erasure first advances a synchronous K3 deletion epoch and blinded tombstone,
fencing new reads and Attempts. Asynchronous owners then purge or prove absence
across:

- Event/Artifact content bindings;
- SQL/FTS/vector/entity/temporal projections;
- caches and context derivatives;
- App-Agent and Space projections;
- learning observations and dataset generations;
- Cloud/API copies where deletion/query is available.

Terminal outcomes are:

- completed: every mapped owner proves purge or absence;
- residualExternalCopies: known external copies remain;
- indeterminateBlocked: existence or purge cannot be proven.

Ordinary unlink is not secure erase. High-sensitivity content uses explicit
Data Protection, per-domain or per-operation envelope keys, sidecar coverage,
backup exclusion where appropriate, and cryptographic key destruction.

## 18. Causal trace and explainability

Every TurnOperationRef binds references to:

- input and identity snapshot;
- task decomposition and semantic DAG;
- requirements, retrieval lanes, evidence, conflicts, and context;
- model/provider/material/plan and resource receipts;
- Agent proposals and correlation;
- verifier, risk, disclosure, confirmation, and authorization;
- Provider/tool/effect/publication boundary states;
- state prepare/commit and active K3 head;
- recovery/reconciliation;
- learning eligibility, dataset lineage, and candidate;
- deletion and external-copy status.

EventLog remains content-free. Sensitive bodies live in encrypted
content-addressed Artifacts. “Why” explanations are derived from structured
receipts and evidence with redaction and uncertainty; they never fabricate or
expose hidden CoT.

K3, K4, and Zone C have separate durable boundaries. They close through stable
identities, anchored roots, idempotent query/recovery, and typed indeterminate
states, not a false distributed-transaction claim.

## 19. Self-scheduling, adaptation, evolution, and healing

- self-scheduling fills, skips, orders, or parallelizes frozen DAG slots under
  fixed budgets and authority;
- self-adaptation selects a compatible plan before the relevant Provider branch
  allocation and first exact context compilation, then only tightens or cancels
  live work;
- self-evolution produces L13 candidates and requires independent
  certification/cutover;
- self-healing replays, reconciles, rebuilds projections, revokes compromised
  identities, and rolls back certified versions;
- self-maintenance uses K1 homeostasis and non-borrowable recovery reserve.

The system may diagnose itself, propose a repair, test it in shadow, and prepare
evidence. It cannot sign its own external authority, invent an entitlement,
declare an indeterminate effect safe, or cut over its own patch.

## 20. Reuse, extension, retirement, and forbidden duplicates

### 20.1 Reuse

Reuse and harden:

- BASCognitiveLayer and BASMotherboardKernel;
- BASEventLog and BASSQLiteEventLogStorage;
- BASArtifactMeshCore and BASArtifactSQLiteStore;
- SQL, FTS5/BM25, vector/RAG, existing rerankers, and Rust fuser/ranker;
- BASContextCompiler;
- BASExecutionPlan, elector, Provider adapters, and Provider physical seam;
- ThermalTwin, Lung, LeaseLife;
- ContextContinuityManifest and WorkUnitRecoveryCursor;
- BASSovereignTokenAuthority and sovereign audit primitives;
- existing response-spool, sovereign-token, tool/effect, and publication
  mechanisms only as subordinate inputs to their mapped future owners;
- AppleBGTaskSchedulerBridge.

### 20.2 Extend in place

Extend admitted owners for:

- the one K3 FULL control transaction;
- encrypted content and erasure closure;
- exact multi-model Context Capsules and context geometry;
- the already-approved but not-yet-created singleton
  BASProcessMemoryLedger.processShared first wire under its existing owner,
  followed by process-wide memory/resource admission; current absence grants no
  permission for a substitute owner or second ledger;
- full load/prefill/cache/decode binding and receipts;
- helper-backed K4 lifecycle;
- the already-approved but currently missing `runtime.semantic-dag`,
  `release.spool-publication`, and `effect.zone-c-saga` production first wires,
  each through its existing non-empty CreateGate; no incumbent primitive may be
  relabelled as proof that one of these owners already exists;
- dual-Space projections and Automation Task Graph;
- learning/evolution candidates, evaluation, certification, and rollback.

If an already approved missing M owner has no first wire on the selected
predecessor, use that owner's existing non-empty CreateGate in the same atomic
wave. Do not invent a substitute.

### 20.3 Retire or contain

Retire, rewrite, or keep lab-only:

- BASStateCommitStore or any second state timeline;
- ThermalTwinFeed;
- direct mutation from sleep consolidation;
- post-freeze adaptive Provider reselection or budget increases;
- same-Attempt multi-Provider physical fallback;
- full learned snapshot EventLog checkpoints;
- live plasticity/BCM/thermal-hazard control without L13/certification;
- synthetic completion, publication, or effect paths;
- raw rg gates that do not distinguish missing inputs from no matches;
- test filters that may pass after discovering zero tests.

### 20.4 Forbidden duplicates

Never introduce:

- W7, a second order master, active plan, or completion authority;
- L15, K5, fifth ring, or eighth plane;
- a second EventLog, K3, StateCommit store, Artifact store, context compiler,
  budget owner, process-memory ledger, scheduler, recovery store, or analytics
  database;
- AutomationManager, AutomationStore, AutomationScheduler,
  AutomationEventLog, AutomationAgent, SkillRegistry, RunRegistry, or Agent
  registry;
- mutable cross-context KV or general Agent bus;
- a second Provider selector, invoker, egress broker, fallback owner, K4 token
  authority, effect outbox, publication spool, or release mouth;
- an Adapter that owns policy, authorization, retries, state, scheduling, or
  semantic ordering.

Owner Ledger cardinality remains 29 owners, 14 M allowlist entries, 14 create
permissions, and 7 controlled documents unless a separately admitted migration
explicitly changes it. This design requires no new M owner.

## 21. Controlled W0-W6 convergence

Every wave consumes the exact predecessor receipt, a closed reviewed path-list
blob, and a bound candidate tree. Later waves may prepare tests but cannot
activate behavior early. A failed wave stops locally; it cannot obtain
authority by later backfill.

### W0 — Trusted baseline and frozen hazards

- repair Create/Extension/Fixture candidate feeding, CI coverage, nonempty test
  discovery, path-existence/scanner status, and iOS 27 floor;
- atomically reconcile the controlled documents and Owner Ledger;
- freeze second writers, direct mutations, synthetic success, dynamic authority,
  and legacy split-brain paths;
- census adaptive/effort/SSM/thermal/biomimetic/sleep mechanisms and classify
  them as authoritativeReuse, subordinateMechanism, observationShadow, labOnly,
  or retire;
- prepare, capture, and bind the external K4 platform-spike prerequisite;
  local W0 development may prepare and package inputs, but W0 cannot emit
  completion, Cw/Sw, admission, or “closed” status until the external B0 gate
  returns the signed `supportedExactProfile` evidence for the exact payload;
  neither W0 nor the candidate may self-sign or self-admit it;
- enable no production behavior.

### W1 — Immutable value contracts

Freeze Artifact, Capability, TurnOperation/branch, RSI, Space, Automation,
Agent, Context, continuity, retention, Apple boundary, model/profile, and
receipt values with one declaration and exact fixtures.

There is zero K3 mutation, branch allocation, model execution, effect,
publication, or scheduled run.

### W2 — One durable K3 truth

Build the single K3 FULL transaction covering root/head, generation, branches,
budget/lease state, outbox, invisible staging, cursor, epochs, tombstones,
checkpoint references, and activation. Complete encrypted Artifact content,
retention clocks, invalidation, and erasure closure.

Crash/concurrency tests observe all-old, complete all-new, or typed
indeterminate; never two heads, writers, or resurrection. Provider execution
remains disabled.

### W3 — Snapshot-bound StateLake and context

Build physical prefiltering, five retrieval lanes, State Market, grounding,
conflict, projections, analytics, exact tokenize-once BASContextCompiler, and
independent Context Capsules.

After W2 provides the sole candidate/activation path, convert sleep-like
consolidation and related biomimetic observers into snapshot/candidate
producers. Remove public direct-mutation bypasses and learned-snapshot EventLog
writes; their full learned bodies remain lab-only Artifacts where eligible.

All W3 behavior is deterministic read-only, shadow, or candidate-only. There is
no direct authoritative projection write or Provider claim.

### W4 — Bound model/silicon execution

Build canonical model capabilities, Plan/Binding, materialization, process
memory accounting, Provider lease, load/prefill/cache/decode receipts, and
deterministic pre-allocation fallback.

Install exactly one production K1 lifecycle composition using the retained
LeaseLife, Lung, and ThermalTwin mechanisms. It consumes internal monotonic
phase receipts, not caller-supplied elapsed time; retires ThermalTwinFeed; and
permits retained adaptive/effort mechanisms only to monotonically tighten the
frozen Attempt. Thermal-hazard and mutable plasticity mechanisms remain
device-lab/shadow candidates.

HardCap sources are produced before consumers. Each execution has one K3
branch, one frozen binding, one process ledger, one physical call seam, and
zero publication.

### W5 — Sovereign external boundary

Reopen and consume the exact K4 blob already required to close/admit W0, then
prove its supported live profile is still exact and current. Build
helper-private K4, exact publication, K3/K4 boundary handoff, sole Zone-C
mutation caller, effect journal, and reconciliation. W5 does not first obtain
or retroactively backfill the W0 proof.

K3, K4, and Zone C never write one another's state. Indeterminate calls are
query/reconcile-only.

### W6 — Runtime composition and certification

Compose Agent Graph, RSI, Automation Task Graph, checkpoints, interruption
recovery, Apple lab surfaces, learning candidates, replay, certification,
legacy retirement, and independent cutover.

The runtime-internal order is observation values → audit schema/envelope
freeze → coordinator behavior → integration population → authoritative engine
cutover → Apple lab → certification. Later work cannot silently revise a
frozen 1.0.0 wire.

Certification and production.cutover remain distinct. Rollback uses the same
cutover owner and an exact prior certified identity.

## 22. Verification and acceptance

### 22.1 Structural

- exact 14/10/4/4/7 identities;
- exact Owner Ledger/document/plan registry cardinality;
- one writer, compiler, scheduler, Provider seam, K4, effect caller,
  publication mouth, certification owner, and cutover owner;
- final source/callgraph/link-image negative proof;
- every scan input exists and is nonempty;
- every focused test filter discovers and runs at least one intended test.

### 22.2 Correctness and Agent quality

- multi-constraint ordering;
- source-faithful long-text extraction with spans;
- strongly leading subjective prompts;
- logic puzzles and bounded hypothesis search;
- material conflict visibility;
- calibrated uncertainty and honest insufficiency;
- persona invariants;
- correlation-aware Agent cooperation;
- exact RSI terminal-state/termination-reason pairing, with only
  `.converged + .convergedVerified` adoptable;
- unresolved or possible-start Attempt produces zero same-WorkUnit successors;
- Granite cannot receive an Agent ID, delegation slot, Agent Context, or vote;
- one logical Main can use multiple independently scoped Capsules without a
  second Main or cross-capsule scratch/KV access;
- every Automation Attempt retains its canonical isolated
  `BASContextCapsule.attemptFrame`; a purely deterministic Attempt constructs
  zero `BASContextCapsule.providerStep` values and allocates no Agent/model
  Provider, while every model-backed `providerStep` is separately scoped,
  budgeted, bound, and isolated;
- Workspace Agent remains a projection and creates zero owner/state/scheduler;
- RSI no-progress/cycle/budget termination.

### 22.3 Recovery and fault injection

Inject before and after:

- input and logical-fire admission;
- K3 allocation, branch claim, stage, seal, and activation;
- retrieval/context compilation;
- Provider load/prefill/cache/decode handoff;
- Context/WorkUnit checkpoint store and reopen;
- K4 issue/reserve/claim/use/anchor/arm;
- Zone-C call, callback, ack, query, and compensate;
- publication prepare/release/finalize;
- deletion epoch, every purge owner, and rescan;
- API/Cloud send/fetch/conflict/delete;
- background expiration, process death, and extension termination;
- certification, cutover, post-install write, and rollback.

Every case ends all-old, complete all-new, a safe fresh rerun before any
boundary, or a typed indeterminate/reconciliation state. No duplicate Provider
call, budget debit, state activation, effect, publication, or release is
allowed.

### 22.4 Security and privacy

- direct and indirect prompt injection;
- confused deputy and cross-Agent/Space scope;
- stale capability, epoch, nonce, signature, and replay;
- secret and hidden-CoT exfiltration;
- package/model/prompt/skill/schema/tool substitution;
- API egress destination, retention, and disclosure;
- deletion and external-copy races;
- five isolation compartments crossed with SQL, FTS, vector, cache, context,
  and local/remote API negative-access matrices;
- each semantic event accepts exactly one source compartment and one source
  class; caller-issued/replaced sequence, compartment, hierarchy identity, or
  immutable-share lineage fails closed;
- Main/Sub-to-App reverse influence passes all seven Experience cleaning gates
  and the correct runtime-state or certification/cutover mouth;
- raw UI signals reach neither EventLog nor learning;
- signed K4 physical-device spike;
- source/SIL/callgraph/link-image proof that lab and retired paths cannot reach
  Release.

### 22.5 Learning

- no same-operation self-modification;
- provenance, consent, retention, and deletion lineage;
- causal-root grouping and leakage-resistant splits;
- mutation tests independently delete or alter the eligible action set, selected
  action, behavior-policy identity/digest, propensity or deterministic marker,
  exposure/cohort/time, correlation classes, outcome window, missingness policy,
  and independent outcome-source contract; every mutation fails eligibility;
- any field first supplied after exposure yields association-only evidence and
  can never promote;
- only `experienceSource` receives ordinary learning ingress;
  `derivedOutcomeFeature` requires its independent authorization and evidence,
  while `governanceControl`, `auditProof`, and `projectionOnly` remain absolutely
  learning-ineligible;
- OPE/holdout/Goodhart/shadow/canary/rollback;
- no promotion from engagement, praise, silence, or self-confidence;
- deletion propagates through datasets, candidates, and installed profiles.

### 22.6 Performance

Measure latency, accepted tokens, memory, thermal, energy, quality, and
recovery overhead together. Certification selects a verified Pareto profile,
not one scalar benchmark. Optional cold40/sustained30 follows its exact
dual-device protocol and never becomes an unconditional structural gate.

## 23. External prerequisites and honest blockers

The system can automate candidate preparation, deterministic tests, protected
review inputs, replay, evidence packaging, and verification. It cannot
manufacture:

- an externally admitted predecessor;
- R2-02/B0 or equivalent external authority signatures;
- a Phase C protected-review terminal;
- Apple entitlements, distribution acceptance, or physical-device facts;
- a supported K4 profile when the helper/persistence/IPC spike failed;
- a production App/Extension target that does not exist.

These conditions remain typed blockers. They do not justify weakening a gate,
using the dirty review branch as an implementation base, self-signing the
candidate, or claiming release readiness.

Python 3.14.5 is the primary development and ordinary-CI interpreter. Checker
and workflow-meta tooling retains the required compatibility profiles. A
protected authority path continues to use its admitted, digest-bound runtime
until Python 3.14 itself is admitted there; PATH discovery is not authority.

## 24. Documentation and implementation transition

This spec is complete when:

- no placeholder or unresolved design choice remains;
- every concept maps to an existing LayerCore, Kernel, ControlRing, plane,
  owner, adapter, or bounded shadow mechanism;
- no second plan, owner, store, compiler, scheduler, bus, or authority is
  implied;
- every failure has a typed stop, recovery, or blocker;
- the user reviews and approves this written file.

After written-spec approval, the next and only skill is
superpowers:writing-plans. It must reconcile this design into the existing sole
active annex and controlled-document transplant process rather than create a
competing Qinao plan. No implementation code begins before that plan is
reviewed.

The first reconciliation slice must atomically align the retention naming,
seven-field State Market algorithm prose, post-Task-2 Provider-executor symbol,
staged Attempt attachments, W0 K4 closure condition, and approved-missing
DAG/publication/Zone-C first-wire gates across every affected controlled
document and checker. A partial terminology flip is not an implementation
permission.

## 25. Primary references

Repository authorities and inputs:

- docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md
- docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md
- docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md
- docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md
- docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md
- docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md
- docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md
- docs/superpowers/plans/2026-07-29-qinao-dual-space-automation-controlled-convergence.md
- docs/superpowers/specs/2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md
- docs/superpowers/specs/qinao-owner-ledger-v1.json

Apple and upstream references:

- https://developer.apple.com/documentation/updates/foundationmodels
- https://developer.apple.com/documentation/foundationmodels/languagemodelexecutor
- https://developer.apple.com/core-ai/
- https://github.com/apple/coreai-models/tree/main/models/qwen3
- https://huggingface.co/Qwen/Qwen3.5-4B
- https://developer.apple.com/documentation/xcode/creating-enhanced-security-helper-extensions
- https://developer.apple.com/documentation/extensionfoundation/appextensionprocess
- https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave
- https://support.apple.com/guide/security/security-of-runtime-process-sec15bfe098e/web
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files
- https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web
- https://developer.apple.com/documentation/updates/appintents
- https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados
- https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- https://developer.apple.com/documentation/cloudkit/cksyncengine
- https://www.apple.com/newsroom/2025/09/introducing-iphone-air-a-powerful-new-iphone-with-a-breakthrough-design/
- https://github.com/NousResearch/hermes-agent
- https://github.com/badlogic/pi-mono
- https://github.com/openai/codex
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/features-overview
