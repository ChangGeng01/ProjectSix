# Qinao Core AI Agent, Context, Memory, and RSI Architecture Addendum

**Date:** 2026-07-19

**Status:** Design decisions approved; implementation and production certification remain `REVISE`; user written-spec review pending

**Scope:** Model-neutral Agent composition, persistent ConversationWorkspace and crash-safe WorkUnit continuity, independent bounded context windows, structured reasoning and information sufficiency, bounded RSI, semantic memory/context compilation, human/Provider adaptive execution, local Core AI/system AFM/optional remote API containment, anticipatory next-question projection, and validation/promotion rules

**Repository snapshot:** `codex/qinao-w1` at `26ccf7f218028cc08dd2c59ff82994feaa9768dc`. This hash is documentation provenance, not a permanent implementation base and not a certification claim. The implementation baseline recorded in Section 10.5 remains a separately named predecessor commit. The worktree also contains in-flight W0/W1 candidate changes that are not implementation truth until independently verified and committed.

**Normative precedence:** This addendum supersedes only conflicting target-state wording in the 2026-07-14 architecture design and the 2026-07-15 domain plans concerning the final local production backend, the approved main/sub-Agent portfolio, independent context windows, RSI interpretation, Provider-adaptive execution, optional remote-model participation, and `NextQuestionProjection`. The 2026-07-17 K3 budget and Provider contract addendum remains authoritative for exact K3 budget, allocation, claim, lineage, and recovery protocols except for six explicitly approved controlled amendments in this revision: strict-quiescent inherited-budget rebase, finite Provider recovery-action boundaries, same-boot `.inProcessCertified` owner-loss terminal closure through a private K3 proof, PCC pre-entry terminal proof through a monotonic private `pccRespondEntered` marker, no downward `maxCost` credit in v1, and profile/lease-derived numeric token-observation bounds instead of a semantic global `262,144` cap. None of those amendments is implementation authority until W0 atomically revises the K3 addendum, controlled masters/domain plans, registry/fixtures, and non-vacuous gates. The 2026-07-14 master's durable remote-egress, disclosure, publication, and effect boundaries remain authoritative and are specialized here rather than replaced. Every unchanged authority, durability, security, effect, erasure, and `14 / 4 / 4 / 7` rule in the 2026-07-14 design remains in force.

This is a normative design addendum, not an eighth Owner Ledger controlled document. Before W1, W0 must atomically merge every adopted decision into the architecture master, convergence master, and five domain plans—the seven controlled documents—regenerate the Owner Ledger provenance/digests/required terms, and run the non-empty owner/create/shape/iOS-floor gates. Until that seven-document convergence and its independent receipts exist, this document does not directly authorize a new production owner or a production cutover. The in-flight corruption-recovery companion remains non-normative unless each proposed lifecycle and monotonic floor is mapped to an existing physical/operator authority; anything that would decide write eligibility outside those roots must pass CreateGate and an Owner Ledger amendment first.

## Executive Decision

Qinao remains a model-neutral deterministic application substrate. It owns protocols, state, authority, planning, verification, audit, recovery, and host integration. Every language or vision model remains outside Qinao SDK behind constrained value-only Provider and Proposal interfaces. No model may directly mutate authoritative state, execute a tool, issue a capability, publish bytes, or promote its own output.

Provider-neutral includes four evidence/profile variants under that same contract. These are not replacements for the already frozen `BASProviderContainmentClass` wire:

| Execution class | Examples | Additional evidence/boundary |
|---|---|---|
| workspace/host-managed local | Qwen, MiniCPM, Granite Core AI packages | exact material, tokenizer/ProcessorABI, StateABI, static geometry, device/OS profile, local resource certification |
| system-managed local | on-device AFM through exact `SystemLanguageModel` cohort | opaque OS/runtime cohort, capability/availability, locale, schema, safety, cancellation, retention, and observed-resource profile |
| system-managed remote opaque | Apple PCC through `PrivateCloudComputeLanguageModel` | exact visible OS/device/entitlement/capability/quota/context/reasoning cohort plus an explicit absence matrix for platform-hidden destination, account/region, model snapshot, tokenizer, request-byte, query/cancel/purge, retention-control, and price fields |
| custom remote exact | a future user-enabled API or self-hosted endpoint | exact destination/protocol/model cohort, region/account, retention/training/deletion posture, cost/quota/rate limits, query/idempotency semantics, L11 disclosure, and durable L14/K3/K4 egress authorization |

The profile variant and containment class are orthogonal but constrained. An in-process local implementation may be `.inProcessCertified`; a local helper/extension is `.isolatedExtension`; every network-crossing implementation, including `PrivateCloudComputeLanguageModel` or a custom server `LanguageModel` reached through FoundationModels, is `.remote`. Each exact descriptor freezes one existing containment value. Local `.inProcessCertified` terminal seals require the existing paired egress-evidence IDs to be nil/nil; `.isolatedExtension` and `.remote` require nonnil/nonnil evidence exactly as the convergence master specifies. FoundationModels is an API surface, not evidence that execution stayed on device.

Remote execution is disabled by default. A Workspace may explicitly authorize named remote Provider profiles, cohorts/regions/accounts when observable, allowed disclosure classes, purposes, and monetary/network budgets. A system-managed opaque profile such as PCC is eligible only when the Workspace explicitly accepts that exact opaque disclosure class and the task does not require an unavailable exact region/account/model/retention-control/purge/price/query proof. Only an installed signed admission/pre-allocation policy may automatically choose among those already explicitly authorized identities for permitted work; profile/cohort/region/policy drift is ineligible until reauthorized. Local-to-remote, remote-to-local, or remote-to-remote change is never a silent fallback and never reuses a compiled context, token sequence, Provider session, or Attempt.

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
| selectable main Agent | Apple on-device Foundation Model (AFM) | system `SystemLanguageModel` Provider | external Provider; proposal-only; not a conversion target |
| text specialist | MiniCPM5-1B | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| vision specialist | MiniCPM-V 4.6 | self-converted, signed, certified Core AI assets | external sub-Agent Provider; proposal-only |
| retrieval embedding mechanism | Granite Embedding 97M multilingual r2 | self-converted, signed, certified Core AI assets | L8 embedding Provider mechanism; not an Agent |
| future selectable main or specialist | exact remote API model/profile selected by the user/host | authenticated remote Provider package outside Qinao SDK | proposal-only; default disabled; no profile is approved merely by this row |

The current intended host default is `Qwen3.5-4B/textOnly`. The family name does not inherit the upstream VLM or MTP capabilities: vision is false and native MTP is false until the exact signed tensors, functions, StateABI, acceptance verifier, and rollback path are separately certified. A future full-vision Qwen profile is a different candidate. AFM is an explicit user-selectable alternative when its exact device, locale, language, availability, and task-capability profile is certified. A future remote model is eligible only after its exact Provider profile and disclosure posture are authorized; opening an API globally does not make every endpoint or model eligible. These preferences are host/Workspace policy, not SDK constants.

Names alone never identify production material. Every workspace/host-managed Core AI asset use binds exact source digest, tokenizer/template, conversion recipe, quantization, function graph, custom operation set, StateABI, toolchain, OS/runtime cohort, and certified execution profile.

That full material tuple applies to workspace/host-managed Core AI Provider assets. AFM weights and internal StateABI are opaque: an AFM use instead binds the exact OS/runtime cohort, FoundationModels capability and availability profile, locale/language, input/output schema, safety/tool contract, and Qinao request/profile identities. AFM has no KV, prefix, continuation, or StateABI compatibility with Qwen or another host-managed model.

A custom remote Provider identity instead binds the Provider; canonical scheme, host, effective port, path, query, method, protocol, TLS trust, and a v1 no-redirect policy; authenticated account/region class; API/protocol revision; exact model snapshot/revision when available; tokenizer/accounting contract; input/output/template/tool-proposal schema; retention/training/deletion policy evidence; price/quota/rate-limit contract; server cache/session semantics; result-query/idempotency behavior; and the Qinao request/profile identities. A floating alias such as `latest` cannot inherit stable production certification. The v1 transport rejects every automatic redirect, including same-origin redirects, before forwarding authorization or body bytes; a later redirect feature would require a finite sealed exact-target set and a fresh exact disclosure/egress proof for each target.

A system-managed remote opaque identity instead binds only the fields that the platform publicly exposes and Qinao can equality-check, together with explicit `unknown/unavailable` presence states for every hidden field. Those unknowns are eligibility constraints, not guessed values. PCC never inherits the custom-API promise that Qinao can pin a physical endpoint, region/account, request bytes, exact model snapshot, server request ID, result query, cancellation acknowledgement, purge operation, or price revision. Platform privacy statements remain certification evidence for a limited profile; they are not application-owned per-request purge or terminal-query receipts.

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
- a separate-target `BASChatCompletionsOrganAdapter` plus SSE parser that proves a remote transport seam, but currently lacks the governed materialization, credential, capability, token-accounting, disclosure, cost/rate, terminal-observation, and durable egress contracts required for production;
- FTS, vector, temporal, entity, retrieval-fusion, memory, and replay mechanisms;
- FoundationModels integration, sovereign authorization, publication, effect, and audit foundations.

Several existing adaptive-looking values are mechanism evidence, not target authority. `BASContextCompiler` still budgets characters; `BASModelCapabilityManifest`, MLX/AFM descriptors, Qwen MTP, and Core AI sessions expose incomparable context limits; `BASAdaptiveRuntimeCore` mixes user-facing tone with device conditions; `BASDeviceRouting` contains unverified physical-placement heuristics; `BASAcceptanceProfiler` is a local decode statistic; and `BASRoutingOrganAdapter` can re-invoke a secondary Provider without a new Attempt or recompilation. The target extends or retires those paths behind the existing owners; it does not bless their current behavior or create a second adaptive controller.

The most recent Core AI evidence supports only a candidate mechanism, not production:

- full-causal KV plus int8 is the current fidelity-supported candidate recipe in the recorded T=32 comparison; stale int4/windowed claims are not ship evidence and this is not general task-quality proof;
- one iPhone Air probe demonstrated the fused-state GDN mechanism and top-5 agreement for its recorded T=32 chain case against the MLX golden path; it is not broad full-chain parity evidence;
- the large vocabulary head exceeded the tested ANE width and therefore used a GPU-stage split;
- the sequential multi-asset chain was roughly 10 token/s in the recorded experiment, not 40/30;
- the approximately 4.2 GB figure is a candidate file/package total, not a resident-memory claim; multi-asset residency, specialization/cache peak, install/update peak disk use, and the active hard-cap plan remain open;
- repository Qwen/Core AI probes that produced `.aimodel` material with `coreai-torch 0.4.0` are historical mechanism evidence only: Apple's v0.4.1 compatibility note says 0.4.0 artifacts fail to load/specialize from OS 27 beta 2 onward. Each affected OS/runtime profile's `knownIssueSetDigest` must canonically bind the applicable official issue identifier when published, status, source revision, and local deny override; profile admission therefore rejects those assets. An exact compatible 0.4.1-or-newer coreai-torch/coreai-core/Xcode/Metal toolchain must reconvert/AOT and rerun numeric, StateABI, device, cache, thermal, and recovery certification;
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

The addendum's design labels converge into exact existing owners as follows; a name in the first column is not permission to create an independent authority:

| Canonical value or design label | Exact authority owner / producer | Persistence and controlled task |
|---|---|---|
| `BASAgentRole`, `BASDelegationProposal`, `BASContextCapsule` | `runtime.turn-operation` composes references; existing L5/L6/L7/L9 and plan owners authorize their contents | immutable value contracts in Contracts Task 2A; ordinary Artifact references only; no Agent registry |
| `ContextContinuityManifest` | `state.snapshot-contracts` owns the schema/value; Artifact Mesh stores immutable bytes | W1 Contracts/Semantic convergence; K3 never interprets its semantics |
| Information Sufficiency candidate/final outcome | existing L10 semantic verifier produces the candidate; existing L14 authorizes the exact final presentation | embedded receipt/value under existing semantic/snapshot contracts; no sufficiency manager or writer |
| `ContinuationPolicy`, `WorkUnitRecoveryCursor` | existing L11/L14 risk/admission authority produces the exact continuation decision from user/host policy; `runtime.turn-operation` only binds its reference, and the manifest carries a value-only recovery projection | no recovery policy writer; K3 boundary rows, journals, budgets, and active head remain authoritative; no Session/Recovery manager |
| `HumanFitProjection` | existing L5/L6 LayerCells produce a transient epistemically labelled projection | embedded in the exact context/plan input; durable preference remains under its existing memory/consent owner |
| `ProviderExecutionVector` | `execution.plan-provider-router` derives an ephemeral comparison projection from signed evidence | never independently persisted or registered |
| `CertifiedContextGeometry` | canonical subvalue of the exact certified profile under existing `runtime.certification` / model-profile ownership | referenced by plan/context receipts; no duplicate cap table |
| `CertifiedOperatingEnvelope` | existing `runtime.certification` evidence referenced by `execution.plan-provider-router` | references the canonical context-geometry identity and adds operating regimes/edges only |
| `BASContextAccountingRequest` / `BASContextAccountingReceipt` | the existing L3 context owner produces the pure canonical request; the exact external Provider package produces the immutable receipt through `provider.package-boundary` | L3 only consumes/reopens the receipt; no model import or async Provider call inside `BASContextCompiler` |
| `BASAttemptRebaseReceipt` | `state.k3-control-nucleus` owns the atomic predecessor-use/visited-state/successor-lease binding | same active-head CAS binds the K4 rebase reservation, fresh successor grant, Attempt/generation, same boot, non-extended deadline, and reduced ceilings; no second budget or challenge writer |
| `BASAttemptRebaseGrantReservationReceipt` | existing `sovereign.k4-durable-lifecycle` owns the signed reserved-but-inactive grant projection and its helper-private row | E/A extension of the one K4 grant/warrant ledger; Artifact Mesh stores immutable receipt bytes, but only K4 status/activation is authority |
| `ProviderRecoveryActionRef` plus recovery-action boundary rows | `state.k3-control-nucleus` owns ordinal/prepare/pending/arm/handoff/terminal truth; existing L14/K4 and Provider materializer own authorization/anchor and exact action bytes | E/A extension of the existing Provider-egress boundary; never a proposal branch or retry writer |
| `BASSpecializationKey`, `BASCacheHandleReceipt` | `provider.package-boundary` owns private realization bytes/receipt mechanism; `cache.scope` owns physical cache admission | Silicon Tasks 1/3/7; never model-selection or semantic authority |
| `PrefillPhysicalStateKey`, `ContinuationCheckpointKey`, `TargetContinuationCheckpoint` | existing plan/cache/Provider execution owners | reused by the readable `PromptPrefixCache` / `ContinuationCheckpoint` labels below; no new cache/checkpoint family |

Authority-M production creation continues to require the existing non-empty candidate manifest, exact planned path, controlled-task Create Proof, and Owner Ledger/CreateGate pass. An E/A schema or wire extension beneath an existing owner instead requires a separate non-empty ExtensionGate manifest binding the exact owner, existing path, symbol, version, canonicalization, current/backward/future fixtures, storage/replay/recovery proof, and proof that authority did not move. CreateGate accepts only M candidates; ExtensionGate accepts only E/A extensions. CI reports current-wave `m_creates`, `ea_extensions`, and `schema_fixtures` separately, and a historical receipt cannot make an empty current wave pass. A typed `notApplicable` may prove that one class is intentionally empty, but cannot satisfy another class. If the controlled convergence chooses a different existing owner for a value, all seven documents and the ledger must change atomically; an implementation may not choose locally.

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

### 2.4 Information Sufficiency Gate

“Provider returned tokens” and “the answer is ready” are separate facts. Information sufficiency is a typed composition of existing L7 requirements/coverage, L10 verification, L11 risk/confirmation, and L14 release authority. It is not an `InformationSufficiencyManager`, a second verifier, or a fifteenth layer.

For the exact task contract, the gate reopens the required-claim set, evidence/authority/freshness coverage, unresolved conflicts, deterministic-check results, tool/retrieval possibilities, user-confirmation requirements, output contract, and current epochs. Preflight runs after L7 evidence/coverage closure and before context compile/terminal-source pin, so its remands can create ordinary bounded children. Finalization is entered only after every Provider branch feeding the candidate is terminal-sealed. A claimed/live or `sent_or_unknown` branch remains entirely in the K3 query/reconcile/seal protocol and produces no final sufficiency outcome; `remandTool` can never stand in for recovery of that same branch. A new evidence need discovered after terminal-source pin creates a new Attempt under the existing K3 rule rather than a late child.

The gate has a preflight and a finalization phase but one closed public outcome vocabulary. Preflight may return one of the two non-visible remands. Otherwise it produces a typed presentation candidate, L12 binds exact bytes, and L14 makes the exact current release/denial decision. Finalization reopens that L14 decision receipt and current epochs before returning one of the five visible outcomes. A candidate that was `ready` before L14 is not `readyVerified`, and an epoch/revocation/deletion/disclosure race forces recomputation rather than publishing a stale outcome.

| Outcome | Phase | Meaning | Legal next step |
|---|---|---|---|
| `readyVerified` | final | all mandatory predicates plus the exact current L14 release decision are verified | prepare/publish only the receipt-bound complete response |
| `remandRetrieval` | preflight | a bounded retrieval operation can materially close a named gap | create one authorized ΩG child with fixed missing claims/budget |
| `remandTool` | preflight | an authorized deterministic/tool observation can materially close a named gap | prepare a separate tool/effect sibling through normal L11/L13/L14 authority; never give the model a tool capability |
| `needsClarification` | final | a user-controlled variable or ambiguous interpretation blocks safe resolution | release the one receipt-bound, answerable, highest-value clarification; the reply is a new Input Event |
| `partialVerified` | final | a policy-approved subset is verified but named obligations remain unresolved | release the receipt-bound included/excluded coverage and residual risk; never imply full completion |
| `abstain` | final | no permitted bounded action can establish sufficient support | release only the receipt-bound precise missing evidence/ability without fabricating an answer |
| `denied` | final | the current policy, privacy, authority, safety, deletion, revocation, or L14 decision forbids the requested operation/disclosure | release only an exact separately authorized denial explanation, or zero bytes if none is authorized |

The governed representation is one self-ID-free, versioned, phase-tagged `BASInformationSufficiencyPayload` under `state.snapshot-contracts`, with an exhaustive presence matrix rather than optional-field ambiguity. Every variant binds the exact `TurnOperationRef`, WorkUnit/Attempt, Workspace snapshot root/HWM, generation vector, task/output-contract digest, policy/deletion/revocation/disclosure epochs, and predecessor payload when one exists:

| Payload phase | Required references | Forbidden references |
|---|---|---|
| `preflightRemand` | L7 requirement/coverage/conflict roots, exact missing-predicate set, selected retrieval-or-tool action digest, fixed child budget/lease reference | presentation spool, release class, L14 decision, publication identity |
| `presentationCandidate` | L7 coverage, L10 semantic/exact verification, L11 risk/confirmation, exact L12 spool digest and presentation/disclosure class, included/excluded coverage | final L14 decision, publication permit/finalization |
| `finalOutcome.release` | exact predecessor candidate ID, byte-identical candidate spool digest/class/coverage, current L14 release receipt, current epoch vector, one of `readyVerified` / `needsClarification` / `partialVerified` / `abstain` | recomputed/substituted spool, wider disclosure class, new evidence or remand |
| `finalOutcome.denied` | exact predecessor candidate ID, current L14 denial receipt and epoch vector, plus either a separately authorized exact denial-spool digest/class or an explicit zero-byte marker | candidate spool release, reuse of candidate class for denial text, new evidence or remand |

L10 produces only the semantic candidate; L14 maps that exact candidate to the final release or denial. A release outcome must reproduce the candidate spool byte-for-byte. A denied outcome instead binds an independently authorized exact denial spool or zero bytes and makes the candidate spool unusable; it never claims those two spools are identical. Finalization is a reopen/equality check, not another model or presentation pass. Mutation of any Attempt, snapshot, generation, applicable spool byte/class/coverage, receipt, or epoch makes the payload unusable and forces a fresh candidate under the ordinary Attempt rules. This freezes one replayable contract without creating a sufficiency writer, manager, or fifteenth layer.

The guards are deterministic and mutually exclusive. A current L14 denial dominates every visible candidate. Otherwise complete verified coverage wins `readyVerified`; before finalization, actionable retrieval/tool gaps win one remand using the existing L7 action ordering and canonical digest tie-break; absent such an action, a material user-controlled ambiguity wins `needsClarification`; a nonempty independently verified and policy-authorized subset wins `partialVerified`; otherwise the result is `abstain`. If both retrieval and tool observations are eligible, only the predeclared StateRequirementPlan/State Market ordering may choose; whichever loses remains an unspent candidate. `denied` never leaks a partial result. `partialVerified` requires an unresolved-scope manifest. A remand names the exact missing predicates and consumes an existing ring/lease budget; it cannot reopen a terminal invocation, replenish budget, or repeat an unchanged query. Technical Provider success, model self-confidence, majority vote, time pressure, user impatience, or exhausted budget cannot upgrade any outcome.

### 2.5 Repeated challenge and correction

User challenge is evidence that the current explanation or interpretation may be wrong, not proof of a replacement fact. The response ladder is bounded and monotonic:

The first material challenge freezes a stable dispute-episode `logicalInvocationKey` from the stable claim key, challenged proposition/interpretation revision, originating WorkUnit, and obligation generation. Source and verifier roots are deliberately excluded from that identity because they evolve during a valid investigation. A `DisputeEpisodeEntry` inside `ContextContinuityManifest` references the initial challenge, fixed round/lane cap, consumed discriminator lanes, latest predecessor-linked progress witness, current evidence/verifier roots, and terminal status. Each step is an ordinary bounded RSI invocation whose `BASControlLoopProgressWitnessPayload` and committed `BASBudgetUseReceipt` record the consumed lane and round in K3. New sources or an independent verifier advance the same episode; only an authoritative supersession of the claim/proposition starts a new one. Crash or replacement Attempt reopens the same episode, inherited budget-use receipt, and visited-state commitment rather than resetting them. L10 interprets resolution; K3 only orders, equality-checks, and spends the existing lease. There is no `ChallengeManager`, dispute store, or replenishable challenge budget.

1. the first material challenge reopens the exact sources, assumptions, interpretation, and verifier receipt and answers from that evidence rather than repeating prose;
2. a repeated unresolved challenge requests an independent verifier, deterministic checker, alternate formalization, or fresh source lane when one is authorized and can discriminate the issue;
3. if the same claim remains disputed after those steps, Qinao freezes adoption of the disputed portion, returns `needsClarification`, `partialVerified`, or `abstain`, and may emit a purpose-limited, consented, redacted incident/lesson candidate for L13 shadow evaluation; it does not keep arguing, silently rewrite authority, or create an unbounded self-dialogue.

An authoritative user correction such as “that is not what I meant” immediately supersedes the affected current-intent/preference hypothesis. Existing L5/L6 semantics produce the typed correction/retraction decision under the same stable claim key; K3 only persists and orders its Artifact reference, advances the already-authorized generation/fence transition, and requires a fresh Attempt/compile. History remains replayable; the wrong inference is not erased in place or allowed to train itself into stronger confidence.

## 3. Main/Sub-Agent Portfolio and Core AI Production Target

### 3.1 Agent roles

The selected main Agent owns no Qinao authority. It is the primary proposal generator for a terminal-answer branch. The host chooses Qwen3.5-4B or AFM before exact context compilation through a signed, certified profile. The user choice is an input to that profile; it is not an environment-variable route and cannot be changed by an old coordinator.

Qwen3.5-4B and AFM may serve as the main terminal-answer Provider only when their exact capability profile supports the requested task. AFM is no longer restricted to sidecar work: it may be the user-selected main Agent, but remains system FoundationModels execution and never exposes convertible weights.

MiniCPM5-1B is a bounded text specialist for extraction, constraint normalization, critique, compact transformation, and other certified tasks. MiniCPM-V 4.6 is a bounded visual specialist for image/video observations. Their outputs are internal proposals and cannot directly become visible terminal output or state truth.

Granite 97M is not an Agent. It implements the existing `BASMemory.BASEmbeddingProvider` seam, which is the sole production L8 embedding seam, for conditional dense retrieval. The homonymous `BASRuntimeCore.BASEmbeddingProvider` declaration is compatibility-only and must be adapted to or removed behind an explicit reachability gate before production; it may not create a second capability/model identity. Granite does not critique, delegate, select evidence, or generate a user response.

### 3.2 Delegation rules

Delegation exists only on a pre-terminal branch whose frozen `BASProviderBranchPolicy` rule permits output role `.internalProposal`. A main-model invocation acting in that internal role may emit a typed `BASDelegationProposal` specifying purpose, required inputs, expected output schema, BudgetLease reference, deadline, and causal parents. The unique `.turnStep/.terminalAnswerCandidate` branch is `answerOnly`, exposes no delegation/tool/effect/continuation schema, and therefore cannot delegate.

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
- a precomputable `BASSpecializationKey` binds the exact material and selected-variant digest, immutable source URL, device architecture, OS/runtime, `SpecializationOptions`, and cache namespace. A later `BASCacheHandleReceipt` carries cache policy, opaque bookmark, creation state, and invalidation state; the bookmark is only a fallible locator and never enters the key/hash;
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

`provider.package-boundary` owns only private bytes, immutable content directories, reader leases, cache/bookmark mechanism, and the pointer CAS. The pointer resolves the exact digest already selected by `model.manifest-invocation` and `execution.plan-provider-router`; it never selects a model/profile. K2 pins the immutable URL, material/variant digest, `BASSpecializationKey`, options, and current `BASCacheHandleReceipt` for the Attempt, never loads through a content-changing alias, and a stale/missing bookmark, purged cache, moved/deleted source, or OS-invalidated specialization may only rebuild the same frozen material arm or return unavailable. Pointer swap affects new readers; it cannot invalidate or retarget an in-flight reader.

Security monotonicity remains with existing sovereign owners: L14 decides exact material admission/revocation; K3 first persists the exact `RevocationFenceReceipt`/source-root transition under `state.k3-control-nucleus`; only then does `sovereign.k4-durable-lifecycle` record the signed minimum material-authorization epoch and revoke in its helper-private `synchronous=FULL` lifecycle, anchor that exact K3 source root, and recover through its existing monotonic-root/query protocol. Admission, claim, chunk, and adoption revalidate generation and that floor. Rollback retention keeps inert bytes only; use of older material requires a new higher deployment/authorization epoch, an exact current certification/release join, and never lowers the security floor. If this mapping cannot be proven without a new write-eligibility root, CreateGate and an Owner Ledger amendment are mandatory.

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

Provider-neutral does not mean reducing every runtime to OpenAI Chat Completions or an untyped JSON bag. The common contract carries task/modality/language capability, exact request and response schemas, context accounting, streaming/cancellation semantics, proposal role, terminal observation, and containment. Tagged profile variants add the evidence that differs by execution class:

```text
ProviderCapabilityProfile
├─ common task / language / modality / schema / stream / cancellation contract
├─ LocalOperatingEnvelope
│  └─ material + tokenizer/ProcessorABI + StateABI + static geometry + device/OS evidence
├─ SystemOpaqueEnvelope
│  └─ AFM OS/runtime cohort + availability + locale + opaque-session contract
├─ SystemManagedRemoteOpaqueEnvelope
│  └─ PCC visible OS/device/entitlement + capability/quota/context/reasoning cohort
│     + platform privacy posture + exhaustive unavailable-field matrix
└─ RemoteOperatingEnvelope
   └─ custom exact destination/protocol/model cohort + region/account
      + disclosure/retention/training/deletion + price/quota/rate-limit
      + server cache/session + query/idempotency evidence
```

These are embedded, versioned values under the existing descriptor/profile/execution-plan authorities, not a new Provider registry. `SystemManagedRemoteOpaqueEnvelope` is a sibling of, not a weakened instance of, the custom exact `RemoteOperatingEnvelope`; its presence matrix makes every platform-hidden field explicit and hard-gates scopes that require one. A protocol-specific Provider materializer produces the final physical request bytes before ordinary-put of `BASMaterializedProviderRequestPayload` M. The execution adapter reopens those exact bytes and may construct only runtime objects or controlled transport framing whose authenticated body is byte-equal to M; it cannot parse and reserialize a second semantic request. FoundationModels/Core AI object APIs that cannot consume literal bytes must prove a canonical field-by-field equality mapping from M and reject any unsupported field. For a system-managed object API that does not expose physical request bytes, M freezes the complete canonical field/value request and the adapter proves field-by-field equality without claiming byte visibility it lacks. Adapters may not rank models, infer consent, choose fallback, rematerialize context, reinterpret tool authority, or promote their response.

On-device AFM uses a FoundationModels `SystemLanguageModel` Provider package. `PrivateCloudComputeLanguageModel` and a custom server `LanguageModel` are remote Providers and must not inherit AFM's local containment. Qwen, MiniCPM, and Granite use external Core AI Provider packages. Production Qwen/MiniCPM/Granite execution has exactly one raw Core AI Provider session/cache owner. A FoundationModels `LanguageModelExecutor` surface is either non-authoritative demonstration code or a stateless facade over that same executor; it may not own a second KV, prefix, cancellation, retry, or result truth.

The existing `BASChatCompletionsOrganAdapter` and SSE extension are retained only as transport/codec mechanisms behind the governed path until migrated. Production must remove raw/Codable secret headers from `Endpoint`; replace static token defaults and character estimates with the selected profile's accounting plus supervisor-observed usage; distinguish authentication, policy, rate-limit, input, server, transport, cancellation, and terminal-shape failures; require a valid terminal event/finish reason rather than treating EOF or skipped malformed SSE as success; truthfully align descriptor capabilities with the implemented transport; translate every frozen tool-proposal/structured-output/sampling field exactly or reject the profile instead of dropping it. Response ID, returned model cohort, input/cache/visible-output/private-reasoning usage split when exposed, finish/safety status, request correlation, and Provider-native receipts live in the governed terminal-result Artifact; private-reasoning counts never authorize access to reasoning text. The frozen 1.0.0 `BASProviderObservedReceipt` references that Artifact through `terminalResultArtifactID` and retains only its already declared IDs/counts/state. No adapter extension may widen that wire. Its `.unlimited` capacity and the legacy “caller is responsible for redaction” posture are not production contracts.

Credentials remain host/OS-secret-store capability material. Governed descriptors/profiles may bind only a nonsecret account/credential-slot policy identity; `BASContextCapsule`, Artifacts, cache keys, logs, traces, and model inputs contain neither a live credential handle nor secret bytes. Host composition injects one nonserializable resolver into the trusted transport membrane and attenuates every resolution by exact purpose, verb, destination, account slot, and request/operation identity:

- generation send resolves only after the fresh `BASProviderFreshRemoteCallPermit` is consumed and permits exactly that request;
- query/reconcile resolves only from the exact historical `sent_or_unknown` row plus the current one-use recovery-action authorization and cannot issue a generation request;
- best-effort cancel resolves only for the exact already-handed-off operation and its one-use recovery-action authorization and cannot imply that disclosure or cost did not occur;
- purge resolves only inside the exact `state.memory-content-erasure` / `effect.zone-c-saga` destination, deletion epoch, retained derivative, and owner-ack/rescan closure.

The resolver is local-only. OAuth refresh, token exchange, or any other network work is a separately materialized and governed egress operation, never an implicit side effect of resolution. Replay, models, ordinary adapters, and unrelated Provider operations receive no ambient resolver. Raw keys and authorization headers are never Codable, persisted in the model profile, exposed to the model, forwarded across a redirect, or returned in error text.

The canonical conversation, task, and memory remain Qinao state. A Provider-side thread/session ID, response chain, prompt cache, or stored conversation is a disposable, profile-scoped optimization only when its retention, deletion, Workspace, account, region, model, template, and policy epochs are exact. It cannot become continuity truth. Any dereference must bind the stable remote reference plus the exact digest/scope of every server-resident prefix it can expose; L11/L14 authorize the effective input `new request bytes + server-resident prefix`, not merely the newly sent suffix. If equality, scope, retention, or purge cannot be proven, that optimization is disabled. A cache/session miss rebuilds from authorized Qinao artifacts; it never broadens disclosure or retrieves a Provider history by “latest.” A profile that cannot prove the required purge/retention boundary is ineligible for data whose policy requires it.

Remote model output, including a vendor-native function/tool call, remains a typed untrusted Proposal. The terminal-answer branch exposes no tool/effect capability. Any proposed tool work becomes a separately authorized sibling through the existing L11/L13/L14 and K3/K4/Zone-C path; the API Provider cannot execute or retry it on Qinao's behalf. If a governed tool result must return to a model before terminal-source pin, it enters a newly allocated, newly materialized, fresh-claimed `.internalProposal` Provider branch with exact causal references; it never resumes the old vendor thread or terminal-answer branch. After terminal-source pin, such a need creates a new Attempt.

Remote disclosure follows the master's existing durable egress protocol exactly: `A/M/[T] → L11/L14 exact governed destination/payload/purpose/disclosure decision → K4 one-shot authorization claim/use receipt → K3 egress prepare → K4 boundary anchor → K3 arm → fresh K3 Provider claim → beginProviderEgressHandoff(claim, arm) → armed-to-sent_or_unknown CAS → immediate Provider call`. For a custom remote adapter, “destination/payload” means the exact physical endpoint tuple and body bytes, and automatic redirects are disabled. For PCC, it means the exact logical Apple PCC service/API operation, signed opaque profile/cohort, and canonical complete field/value request; physical endpoint/TLS/redirect/account/region/request-byte facts remain explicitly unavailable and are neither authorized as guessed values nor equality-checked by app transport. The K4 authorization claim and later boundary anchor are distinct operations. Only the fresh CAS winner receives the consuming `BASProviderFreshRemoteCallPermit`; a lost handoff reply is non-callable. After `sent_or_unknown`, cancellation, timeout, disconnect, or lost response is query/reconcile/seal-only. Provider idempotency or response-query keys may identify that same call but never authorize redispatch. If the Provider cannot establish terminal truth, the branch remains nonpublishable. Any later user-visible work is a separately admitted WorkUnit/root and may call only as an explicitly authorized distinct operation, never as replay/retry/replacement of that unresolved request.

Query and cancel are external boundaries in their own right. V1 derives at most one `ProviderRecoveryActionRef(.cancel, 0)` and at most one `ProviderRecoveryActionRef(.terminalQuery, 0)` beneath the original `providerEgressBranchRef`, in that order when both are applicable. Each action has exact materialized bytes, a fresh L14/K4 one-shot grant, K3 prepare/pending, K4 boundary anchor, K3 arm/handoff/terminal rows, a BudgetUse receipt, and an authenticated terminal observation. It does not join or replenish the generation A/M/T/Q/C/S/P/R proposal lineage. A lost or inconclusive recovery-action response is not retried; it leaves the original operation indeterminate and the WorkUnit nonpublishable. A future profile may define a different finite recovery sequence only through a new signed profile/schema version and the same ExtensionGate/fault matrix. Purge is never a recovery resolver shortcut: it is the existing erasure/Zone-C saga and closes only after deletion-epoch equality, owner acknowledgement, and rescan.

Remote terminal mapping is execution-class-specific. A custom transport's `URLSessionTask` evidence is not evidence about PCC, whose physical transport is outside the App:

| Execution class and observation | Canonical state |
|---|---|
| either class: local deny/failure before the handoff CAS | zero send; close the unused path under its existing pre-claim rule |
| custom exact transport: resolver/local membrane failure after handoff CAS, with trusted same-owner proof that `taskCreated == false` | existing terminal `failed` state with nil proposal/result IDs; zero-byte `BASProviderObservedReceipt` plus governed attestation/private-row reason `postCASPreTransportLocalFailure`; no frozen receipt widening and no retry |
| custom exact transport: task created, or task creation cannot be proved false | retain `sent_or_unknown`; query/reconcile/seal only |
| custom exact transport: complete authenticated, request-correlated Provider/HTTP error | terminal `failed`; never retry that branch |
| PCC: trusted same-owner membrane proves that FoundationModels `respond(...)` was never entered and no request field could have been disclosed | existing terminal `failed` state with nil proposal/result IDs; zero-byte `BASProviderObservedReceipt`, its required attestation, and the exact governed private reason `postCASPrePCCRespondLocalFailure`; no retry |
| PCC: the monotonic `pccRespondEntered` marker committed, its commit reply is unknown, the original owner was lost, or `respond(...)` entry otherwise cannot be proved false | retain `sent_or_unknown`; an App-level absence of `URLSessionTask` is irrelevant |
| PCC: FoundationModels throws `networkFailure`, `serviceUnavailable`, cancellation, or another platform error after/possibly after entry without authenticated same-operation terminal evidence | retain `sent_or_unknown`; the error does not prove nondisclosure or nonexecution |
| either class: timeout, disconnect, malformed/truncated stream, or EOF without exact terminal evidence after handoff | retain `sent_or_unknown`; query/reconcile/seal only |
| either class: cancel requested without exact authenticated terminal acknowledgement | retain `sent_or_unknown`; cancellation intent is not terminal truth |
| either class: exact authenticated cancellation or terminal result recovered by a supported same-operation query | submit that observation to the one existing terminal-seal CAS |
| either class: query unsupported, unavailable, or inconclusive | remain indeterminate/quarantined and nonpublishable; zero resend |

`pccRespondEntered` is a monotonic private field on the existing K3 Provider-egress boundary row, not a public receipt or new writer. The sole PCC membrane advances it through a package-private one-way K3 port immediately before invoking `respond(...)`; only that same live owner may use a definitely absent marker plus a synchronous local return to prove the pre-entry failure. A committed marker, lost marker reply, crash, suspension, or owner loss is conservatively “entry possible.” The port cannot clear the marker, create a call permit, or seal a result. This E/A extension must be included in the controlled K3 amendment and its before/at/after-entry crash fixtures.

Before custom remote allocation/egress, the frozen price revision and conservative maximum input, output, reasoning, tool, cache, and request units consume the authorized `maxCost` through the existing K3 `BASBudgetLeasePayload`/use conservation and K4 aggregate-warrant ceiling. V1 does not settle that authority ledger downward: authenticated lower Provider usage is retained as observation/billing evidence but cannot manufacture an unimplemented negative K3 use or K4 credit. `sent_or_unknown` or missing usage therefore also retains the conservative maximum. A future refund/credit feature requires an independently reviewed idempotent K3/K4 settlement protocol and crash matrix; it cannot appear in an adapter or second CostManager. A system-managed no-token-price PCC profile still binds quota/reasoning usage and any applicable platform/account limits rather than inventing a price revision.

Comparing eligible candidates before first selection is not a Provider change. Once an exact Provider/model/profile/accounting lineage is selected and context compilation begins, Qwen-to-AFM, local-to-remote, remote-to-local, remote-to-remote, or any lineage change requires a new Attempt and recompilation for the destination contract. Before allocation, a same-lineage certified plan/geometry candidate may replace another only by discarding the unclaimed compiled candidate and revalidating every input; after allocation neither route nor request may change. Remote auto-selection is permitted only at admission/pre-allocation by an installed signed policy over profiles, cohorts, regions, purposes, disclosure classes, and budgets the user/Workspace already explicitly authorized. Any affected profile/cohort/region/policy change creates a new Attempt. `BASRoutingOrganAdapter`-style catch-and-call-secondary behavior is a compatibility/lab mechanism, not a production fallback authority.

## 4. Independent Context Windows and Typed Collaboration

Qinao supports many independent logical context windows without pretending the device can host many independent 4B runtimes.

### 4.1 BASContextCapsule

`BASContextCapsule` is a strictly tagged value contract, never one optional all-fields bag. The `attemptFrame` variant exists at WorkUnit admission and contains only:

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

Only typed immutable artifacts cross Agent boundaries. The main terminal-answer prefill freezes its `BASContextCapsule`. A late specialist artifact cannot be injected into an active decode stream. Before terminal-source pin, it may enter only a separately authorized branch already permitted by policy. After pin, only the exact buffered post-pin verifier exception may run after the source's completed terminal seal; every other late artifact is fenced to a new Attempt. Prefix or suffix cache mechanics may reduce the cost of an otherwise authorized rebuild when exact scope permits, but never authorize a branch, retry, route change, or Attempt.

Low latency comes from:

- shared read-only weights and compiled Core AI specialization;
- parallel independent retrieval or proposal branches under one admitted wave;
- exact prefix/cache reuse within one identity;
- small typed artifacts instead of transcript replay;
- pre-tokenized compiled sections and deterministic joins;
- one local HeavyPhase owner, preventing destructive accelerator thrash.

Low latency does not justify shared mutable KV, context leakage, hidden Agent calls, unverified early adoption, or concurrent 4B trunks.

### 4.4 Persistent ConversationWorkspace, bounded Attempts

The user may keep one visible conversation/workspace indefinitely. Qinao does not require a new visible session merely because a model window, KV/SSM state, process, OS cohort, or task Attempt must rotate. `ContextWorkspaceRef` is the stable authorized workspace identity; each Mission/Objective/WorkUnit executes through bounded Attempts and independent Provider-step contexts beneath it.

The durable continuity source is K3 EventLog plus governed Artifacts, never a Provider transcript or “largest prompt so far.” A value-only `ContextContinuityManifest` under the exact `state.snapshot-contracts` owner references, rather than copies, the exact workspace/snapshot/Attempt roots and preserves:

```text
Mission / Objective / WorkUnit graph and current completion predicates
hard constraints and user corrections
verified decisions, evidence, provenance, conflicts, and unresolved obligations
external-effect / publication / Provider sent-or-unknown state
stable user-authorized preferences and disclosure constraints
omission/coverage manifest and historical episode ranges
source Attempt, snapshot HWM, generation vector, policy/deletion epochs
optional latest committed budget-use receipt (nil only with K3 zero-use proof) and ControlRing visited-state commitment
terminal semantic heads plus exact nonterminal Provider/effect/visibility/publication boundary references
WorkUnit recovery policy/deadline and optional same-Attempt continuation-checkpoint identity
```

It excludes raw CoT, hidden mutable prompts, model self-confidence, secrets, ambient handles, unverified summaries, and Provider-private KV/session state. The manifest is not a context store or mutable “memory object”; it is a governed snapshot-bound value whose referents remain authoritative under their existing owners. Artifact Mesh ordinary-puts its immutable payload; L10 owns semantic coverage verification; `state.k3-control-nucleus` alone owns active-head/rebase mutation and only reopens, equality-checks, and CASes receipt identities—it never interprets continuity semantics.

Internal rotation may be requested when the selected Provider geometry cannot safely fit mandatory content plus output/verification reserve, a model/tokenizer/template/cohort changes identity, a correction or deletion advances an epoch, a WorkUnit boundary is reached, a continuation checkpoint is invalid, or measured quality/recovery policy requires rebuilding. Rotation is never permission to omit a hard obligation or switch Provider silently.

### 4.5 Atomic context rebase

Context rebase is an atomic K3 head transition, not “summarize the chat and hope.” Its canonical state sequence is:

```text
ACTIVE(n)
→ rebase_requested
→ freeze new semantic/external work; keep Attempt(n) current for recovery only
→ every Provider/recovery-action/effect/visibility/publication boundary terminal or proved never possible-start
→ source snapshot + ContextContinuityManifest sealed
→ target Provider/context candidate compiled for Attempt(n+1)
→ L10 mandatory coverage and conflict closure receipt sealed
→ K3 commits one private rebase_pending row and source root for the exact request/old head,
  predecessor/successor Attempt+generation, remaining ceilings, rights, same boot, and non-extended deadline
→ K4 idempotently reserves a fresh, inactive Attempt(n+1) grant from the same authorization basis/warrant
  and returns one signed BASAttemptRebaseGrantReservationReceipt
→ one K3 BEGIN IMMEDIATE active-head CAS reopens every frozen input, the K4 reservation,
  and predecessor budget/visited state
  → installs Attempt(n+1) root/head + non-widening inherited lease + BASAttemptRebaseReceipt
  → makes Attempt(n+1) ACTIVE and fences Attempt(n) from adoption
→ K4 idempotently activates that exact grant only from the winning rebase receipt/covered K3 root
```

The existing L10 verifier requires 100% preservation of the task root, current user instruction/corrections, hard constraints, open obligations, material conflicts, authority/provenance references, risk/confirmation state, deletion/policy epochs, and every external call/publication/effect state that could forbid replay. Optional detail may be represented through exact source references plus an omission ledger; an opaque free-text summary cannot satisfy a mandatory slot.

Before the final CAS, the old Attempt remains the sole active head. `rebase_requested` is only a projection of its current head plus boundary rows: it freezes new semantic branches, Provider allocation, visibility, publication, state commit, and effect dispatch while preserving the exact query/cancel/reconcile/seal/finalize paths for already prepared operations. The candidate has no usable capability; its later K4 reservation is inactive. If any old boundary is `sent_or_unknown`, `visible_or_unknown`, dispatched/armed, publication-indeterminate, or otherwise nonterminal, the CAS is illegal. If the finite recovery plan cannot establish terminal truth, the WorkUnit ends semantically `unresolved` with the exact `indeterminate_needs_reconciliation` coverage/reason rather than activating a successor; unrelated WorkUnits in the same Workspace remain runnable.

The rebase request binds an idempotency request ID and expected old head. K3 first commits a private `rebase_pending` row under the still-active predecessor. That row freezes the exact candidate inputs, predecessor and proposed successor Attempt/generation, current `bootSessionID`, old active head, current epochs, rights subset, checked remaining ceiling vector, and a successor `monotonicDeadlineNanos` no later than the predecessor lease, current policy, or durable warrant deadline. It authorizes no semantic work. K4 then uses the same request ID to atomically reserve, against the original durable authorization basis/warrant rather than by delegating or reusing the predecessor grant, a distinct Attempt-scoped `authorizationGrantArtifactID`.

That K4 transaction commits its helper-private reserved-inactive row before returning a self-ID-free signed `BASAttemptRebaseGrantReservationReceipt`. The receipt binds the rebase request ID; exact predecessor/successor Attempt and generation; expected old active head; `rebase_pending` source watermark/root and K4 covering watermark/root; authorization-basis/warrant and predecessor/fresh-grant Artifact IDs; canonical rights subset and reduced ceiling vector; boot session; monotonic deadline; key/warrant/policy/deletion/revocation epochs; and the K4 ledger request/result digest. Artifact Mesh stores the immutable signed projection, while the K4 row remains status authority. This integrity covering root is not a `BASBoundaryAnchorReceipt`, does not set recovery `X`, and authorizes no external/visibility boundary. Repeating the same canonical request returns byte-identical receipt bytes; the same request ID with changed bytes is corruption. The reservation is non-consumable until the winning K3 rebase receipt is covered and K4 activates it; validation, claim, boundary anchoring, or capability resolution against it must fail closed.

Inside the one active-head `BEGIN IMMEDIATE` CAS, K3 reopens and byte-equality-checks the manifest, L10 coverage receipt, source snapshot/HWM and event head, current active head, generation vector, policy/deletion/revocation epochs, every old boundary terminal receipt, predecessor lease/private budget row, optional latest `BASBudgetUseReceipt`, predecessor visited-state commitment, private `rebase_pending` row, fresh grant Artifact, and signed `BASAttemptRebaseGrantReservationReceipt`; it verifies the receipt signature and equality of every K3-owned binding without treating its status projection as K3 authority. The use receipt is nil only when K3 proves lease revision/cumulative use/visited updates are all still zero; otherwise it must equal the private row's latest committed receipt. The transaction checked-subtracts each predecessor cumulative counter from its ceiling; creates `BASAttemptRebaseReceipt` with exhaustive zero-use/used variants and the reservation-receipt/new-grant/Attempt/generation/boot/deadline bindings; installs a successor lease whose token/byte/branch/remand/hop/cost ceilings are each no greater than the corresponding remainder, whose rights are a subset, whose grant is that fresh inactive grant, whose boot equals the current predecessor boot, and whose deadline is not extended; installs its zero-local-use K3 row with the inherited visited-state commitment; installs the new root/head; and advances the generation fence. The successor is authoritative but cannot spend, allocate, or cross any protected boundary until K4 idempotently reopens its own row plus both signed receipts and activates that exact reserved grant from the covered winning root.

Successor cumulative use is local to that reduced lease; total lineage use is the checked sum proved by the rebase-receipt chain. “Zero new spend” means no new allowance and no lost history, not copying an exhausted original ceiling. The predecessor grant is never reused across an Attempt. A crash before the head CAS leaves the old head authoritative and recovery may submit only the byte-identical reservation/CAS request. A crash after the head CAS reopens the one new head and idempotently finishes K4 activation; it never issues another grant. A CAS loser or abandoned pre-CAS reservation may be closed only by the same idempotency request plus a K4-verifiable covered K3 proof that another rebase receipt won or the expected head/epoch changed. Without that proof it remains non-consumable and counts against the warrant until its original non-extended deadline expires.

K4 activation has exactly three derived outcomes from one idempotency request. A healthy K4 may atomically revalidate the exact reservation, winning receipt/covered root, key/revoke/policy/warrant epochs, same boot, deadline, rights, and ceilings and move only that reservation into the existing usable issued/reserved grant state. If revocation, expiry, or another sovereign denial wins, K4 must first durably commit a signed, monotonic denial fence bound to the activation request, reservation receipt, winning rebase receipt/root, grant, boot/deadline, and current epochs; only that fence makes `terminalDenied` irreversible. If the activation reply is lost, K4 is unavailable, or ledger integrity is quarantined and neither usable status nor that denial fence can be proved, the only honest projection is `activationPending`: Attempt(n+1) remains authoritative but non-runnable, and Runtime may submit only the byte-identical activation/status request after the same K4 ledger and monotonic floors are operator-approved and recovered. It cannot report terminal denial, roll back Attempt(n), mint/replace/widen a grant, or run work while status is unknown. `activationPending` is a read-only recovery projection over the existing K3/K4 rows, not a new writer or public state authority.

A proven `terminalDenied` follows the existing denial/await-user path; integrity-unavailable `activationPending` is quarantined, while a healthy exact-status lookup is `reconcileSameOperation`. A device reboot invalidates the monotonic boot domain and must eventually deny/expire that reservation when K4 can prove its ledger; v1 forbids same-WorkUnit cross-boot rebase and requires an explicitly confirmed, separately admitted WorkUnit with fresh authority. Every same-WorkUnit reference to a “new Attempt” elsewhere in this addendum is subordinate to this strict rebase protocol. No state permits two active Attempts or two usable successor grants.

A claimed Provider invocation may only join/continue that same demonstrably live invocation or query/reconcile/seal its exact terminal state while the old Attempt remains current. `sent_or_unknown` is never erased by rebase. Provider/model change, invalid checkpoint, correction, deletion, or process loss can create a successor only after all predecessor boundaries are terminal. A later user request may create an independent WorkUnit with a distinct, explicitly authorized operation, but cannot disguise a resend or replacement of an unresolved effect. Token IDs, KV/SSM, sampler state, proposal state, call permits, recovery permits, spool cursors, and unresolved effect authority are never transplanted.

### 4.6 Process/session interruption and command continuation

A visible “session” is a UI projection over `ConversationWorkspace`; it is not execution truth. iOS suspension, process termination, crash, device reboot, scene destruction, model unload, or Provider-session loss may destroy threads, actors, in-memory prompts, KV, and runtime objects. Qinao guarantees **logical restartability at the next authorized execution opportunity**, not uninterrupted compute or resurrection of a Swift stack. UIKit/scene restoration may reopen the same Workspace and window, while K3/EventLog, governed Artifacts, K4, Zone C, and the independent publication journal reconstruct the command's authoritative progress.

```text
App/scene execution opportunity
→ cold-open K3/K4/Zone-C/publication integrity and monotonic floors
→ treat restored UI Workspace/window references only as lookup hints
→ reopen authoritative Workspace → WorkUnit → active Attempt heads and exact receipts
→ verify ContextContinuityManifest mandatory recovery coverage and current epochs
→ derive one RecoveryDisposition
→ restoreCompleted | resumeSameAttempt | reconcileSameOperation
   | rebuildAfterTerminal | awaitUser | quarantine
→ ordinary claims/receipts advance the selected path; no special recovery authority
```

Each WorkUnit binds a tagged `ContinuationPolicy` decision produced by existing L11/L14 risk/admission authority from the current user/host policy: `automaticWhenSafe`, `foregroundOnly`, `confirmationAfterInterruption`, or `neverAutomatic`, plus deadline, maximum interruption age, user-presence requirement, and permitted execution class. `runtime.turn-operation` freezes only that receipt/reference and cannot invent or widen resume policy. Pure local preparation defaults to `automaticWhenSafe`; a not-yet-handed-off remote disclosure, chargeable call, publication, or irreversible effect must revalidate L11/L14 and its original policy before crossing the boundary. A boundary already possibly crossed is reconciled, never reauthorized as a resend. Background/continued-processing APIs are execution opportunities only; expiration requests cooperative checkpoint/cancellation, and their absence or interruption cannot become correctness state.

`WorkUnitRecoveryCursor` is a self-ID-free convenience projection inside `ContextContinuityManifest`. It references the active task graph/head, last committed semantic Artifact heads, open obligations, snapshot/generation/epochs, optional latest budget-use receipt plus visited-state commitment, every nonterminal boundary identity, the `ContinuationPolicy`, and an optional exact same-Attempt `TargetContinuationCheckpoint`. It copies no mutable counter or boundary state. Policy is evaluated before the recovery matrix and controls mutation, not read-only integrity lookup:

- `automaticWhenSafe` may enter the matrix at any permitted execution opportunity;
- `foregroundOnly` may enter it only in an eligible foreground opportunity with current required user presence;
- `confirmationAfterInterruption` yields `awaitUser` until a new affirmative Input Event and the existing L11/L14 confirmation/authorization path bind the exact WorkUnit/Attempt, recovery-cursor digest, interruption episode, current epochs, requested disposition, expiry, and one use;
- `neverAutomatic` performs no recovery mutation from relaunch/background alone. A new explicit Input Event must pass ordinary admission and either produce an exact one-use manual continuation authorization for this cursor or admit a separately identified WorkUnit; it never silently rewrites the frozen policy.

An absent, stale, denied, mismatched, or already consumed confirmation/manual authorization yields `awaitUser`, even when the receipt matrix would otherwise say `safePreclaim`. A disallowed execution class, expired deadline/interruption age, or missing user presence likewise performs no mutation and waits for the exact eligible foreground/Input Event. This deferral is not a second durable state machine.

On an eligible cold open, the existing Turn Runtime reopens the referenced authorities and classifies every branch/boundary by an exhaustive receipt-presence matrix. In this matrix `A/M` are allocation/materialization, `D` is the K3 dormant pending permit, `K` is the K4 boundary anchor, `B` is the K3 arm, `Q` is the one Provider claim, `CP` is a checkpoint, `O/S` are authenticated observation/terminal seal, `P` is the exact prepared spool, and `Jr/Jf` are publication reserve/finalization. `sameLiveOwner` means positive liveness for the exact original task/owner epoch **and** equal current boot, generation/policy/deletion/revocation epochs, and unexpired deadlines. `boundaryUninterrupted` additionally means the same executor can positively prove that no iOS suspension, background-expiration handoff, cancellation/interruption episode, actor/task replacement, or execution-opportunity break occurred after the receipt returned; inability to prove continuity is interruption. `X` is conservative possible-start: it becomes true when a K4 anchor committed **or its result is unknown**, and remains true after an arm, claim/handoff, or physical external/visibility call. It does not wait for evidence that the physical call began. “Returned” below means the exact receipt reached that live owner, not merely that lookup later found it; a committed result recovered only by lookup after a lost reply is still unknown-delivery and is reconcile-only. A returned receipt does not survive a later boundary interruption as arm/call authority. Likewise, a K4 lookup proving `K` absent does not erase a prior lost anchor-request reply: safe first issuance requires proof from the same uninterrupted owner that the anchor request was never issued at all.

| Exact mutually exclusive presence and proof | Per-boundary class | Only legal step |
|---|---|---|
| integrity, monotonic-floor, required Artifact, presence-shape, or equality proof fails | `quarantined` | touch no checkpoint/model/external boundary; produce only an authorized incident projection |
| committed pure-step inputs and epochs are current in the same boot, no `A/D/K/B/Q/X`, and this recovery worker won the existing K3 resumer CAS | `safePreclaim` | discard volatile output and deterministically recompute the same pure step without new budget allowance |
| unfinished pure work or Provider/recovery-action/stream work before any dormant permit belongs to an earlier boot, `D/K/B/Q/X/O/S=nil`, and no authenticated cross-boot recovery exception applies | `staleBoot` | mutate no old-boot state; preserve progress and await admission of a separately confirmed independent WorkUnit |
| Provider `A!=nil`, `D/K/B/Q/X=nil`, `sameLiveOwner`; `M` is either nil or the one exact reopened materialization | `safePreclaim` | if `M=nil`, deterministically materialize/ordinary-put/reopen it once from `A`; then local continues to the unique first claim and isolated/remote only to the exact first pending-permit/anchor sequence; either may instead close unused |
| Provider/recovery-action/stream `D!=nil`, `K` is proved absent, the same uninterrupted owner proves no anchor request was ever issued and no reply was lost, `B/Q=nil`, `X=false`, `sameLiveOwner` | `safePreclaim` | issue the unique first anchor request and continue only its returned-receipt sequence, or close unused; create no new identity |
| same-boot Provider/recovery-action/stream has `K` proved absent after an anchor request/result/reply was lost or submission is uncertain, and `sameLiveOwner` still holds | `reconcileOnly` | query-close/reconcile that dormant identity only; never submit or arm the anchor request again |
| either same-boot Provider preclaim shape, no anchor request/reply was lost, but owner/currentness/deadline fails while `K` is proved absent | `closedUnused` | close/query-close the old tuple when the existing owner permits; no claim, re-arm, deadline extension, or external call |
| Provider/recovery-action/stream `K` or `B` committed and its exact receipt returned to `sameLiveOwner`, `boundaryUninterrupted` holds, `Q=nil`, `O/S=nil`, and no receipt/result is unknown | `liveSameBoundary` | continue only the already in-flight returned-receipt sequence to its next unique transition; never reconstruct/re-arm or create another permit/instance |
| same-boot Provider/recovery-action/stream has a still-live original owner and `Q/O/S=nil`; either (a) an exact `K/B` receipt was originally returned with no unknown reply and either currentness/deadline or `boundaryUninterrupted` fails, or (b) `K` is now proved absent while `X` retains prior request uncertainty and currentness/deadline fails; and an exact same-operation status/reconcile protocol exists | `reconcileOnly` | query/reconcile/finalize that identity only; suspension, deadline/epoch failure, or another interruption consumed continuation authority, so never arm, claim, call, or treat resumption as uninterrupted |
| the same known-result, same-boot, still-live-owner shape has no authenticated same-operation recovery protocol | `quarantined` | preserve possible-start state; never arm, claim, call, or treat resumption as uninterrupted |
| same-boot Provider/recovery-action/stream has a still-live original owner, `K` or `B` is committed only after an originally unknown result/reply/delivery or its current status remains unknown, `Q/O/S=nil`, and an exact same-operation status/reconcile protocol exists | `reconcileOnly` | query/reconcile/finalize that identity only; the original owner may not arm, claim, or call after recovering a lost reply, regardless of later currentness/deadline |
| same-boot Provider/recovery-action/stream has a still-live original owner, `K` or `B` is committed only after an originally unknown result/reply/delivery or its current status remains unknown, `Q/O/S=nil`, and no authenticated same-operation recovery protocol exists | `quarantined` | preserve possible-start state; never arm, call, or create a successor external allocation |
| Provider/recovery-action/stream has old-boot `D/K/B/X` or retained anchor-request uncertainty with `Q/O/S=nil` | `staleBoot` | permit integrity/status lookup only as a read-only projection; perform no old-boot close/reconcile/arm/call mutation, preserve the tuple, and await a separately confirmed independent WorkUnit |
| same-boot Provider/recovery-action/stream `K/B/X` is known, `Q/O/S=nil`, the original owner is lost, and an exact same-operation query/finalize/reconcile protocol exists | `reconcileOnly` | query/reconcile that identity only; never arm, call, resend, redispatch, append, or restore `CP` |
| same-boot Provider/recovery-action/stream `K/B/X` is known, `Q/O/S=nil`, the original owner is lost, and no authenticated same-operation recovery protocol exists | `quarantined` | preserve the possible-start state and expose incident/await-user status; zero successor external allocation |
| local `Q!=nil`, `O/S=nil`, no `K/B/X`, `sameLiveOwner`, and the exact physical invocation is demonstrably live | `liveSameInvocation` | join/continue that exact physical invocation; use `CP` only if its complete identity matches |
| local `Q!=nil`, `O/S=nil`, same boot but original owner is fenced/dead, and the exact signed `.inProcessCertified` private proof applies | `reconcileOnly` | use the controlled private K3 owner-loss transition to seal only that existing local event head as terminal `failed`; zero Provider calls and zero public observation/attestation |
| same-boot `.inProcessCertified` local `Q!=nil`, `O/S=nil`, owner lost, but the private proof does not apply | `quarantined` | infer no terminal fact and allocate no successor Provider operation |
| claimed local invocation with `O/S=nil` is from an earlier boot | `quarantined` | no local cross-boot seal, `CP` restore, same-WorkUnit rebase, or successor Provider allocation |
| isolated/remote `Q!=nil`, `O/S=nil`, `sameLiveOwner`, and the exact physical invocation is demonstrably live | `liveSameInvocation` | join/continue only that exact invocation; create no second call permit |
| same-boot Provider `Q!=nil`, `O/S=nil`, the original owner remains live, but bound currentness/deadline fails or the exact invocation is no longer demonstrably live, and an exact same-operation cancellation/quiescence/query/terminal protocol exists | `reconcileOnly` | use only that existing invocation's policy-permitted cancellation, quiescence, query, or terminalization path; mint no call permit, adopt no now-ineligible output, and restore no `CP` |
| the same claimed, same-boot, still-live-owner shape has no exact same-operation cancellation/quiescence/query/terminal protocol | `quarantined` | request no replacement call and infer no terminal fact; retain the unresolved identity for incident/user policy |
| same-boot AFM `Q!=nil`, `O/S=nil`, owner lost, and exact terminal/cancellation-quiescence or authenticated same-operation recovery evidence exists | `reconcileOnly` | seal/query/reconcile that operation only; never create a generation permit or restore `CP` in another process |
| isolated/remote, including system-managed remote, `Q!=nil`, `O/S=nil`, owner lost, and authenticated same-operation recovery evidence exists | `reconcileOnly` | query/reconcile that operation only; never create a generation permit or restore `CP` in another process |
| same-boot AFM or any isolated/remote/system-managed-remote `Q!=nil`, `O/S=nil`, owner lost, and no exact terminal/quiescence or authenticated same-operation recovery evidence exists | `quarantined` | do not infer silence from App death; retain unresolved truth and require a separately confirmed independent WorkUnit for later work |
| `O!=nil`, `S=nil`, observation origin is `immediateReturn`, observation boot equals claim/arm boot, and current same-boot epochs hold | `reconcileOnly` | reopen the exact observation/attestation and perform only the existing K3 seal CAS; zero Provider calls |
| `O!=nil`, `S=nil`, origin is `authenticatedQueryRecovery`, its attestation binds the original isolated/remote tuple plus current recovery boot, and current generation/policy/deletion/revocation epochs hold | `reconcileOnly` | perform only the existing cross-boot query-recovery seal exception; mint no permit and rewrite no historical boot |
| `O!=nil`, `S=nil`, origin and attestation shape are otherwise valid, but current generation/policy/deletion/revocation epochs fail | `quarantined` | retain only policy-permitted audit/erasure evidence; adopt no proposal/result, perform no terminal seal under stale authority, and issue no Provider call |
| `O!=nil`, `S=nil`, but an `immediateReturn` observation crosses boot or either origin/attestation shape is invalid | `quarantined` | no terminal mutation or adoption |
| `S` is terminal, current boot still matches, and no later visibility/publication/effect boundary is open | `terminal` | continue deterministic gates or become same-boot strict-rebase eligible |
| `S` is terminal from an earlier boot and the complete WorkUnit, including publication/effect K3 closures, is already terminal | `terminalReadOnly` | restore the completed response/audit projection only; perform no K3 mutation |
| `S` is terminal from an earlier boot but downstream K3 work is unfinished | `quarantined` | do not mutate the old boot; await an explicitly confirmed independent WorkUnit |
| `P!=nil`, `Jr=nil`, no `D/K/B/X`, `sameLiveOwner` | `safePreclaim` | reserve only the same publication identity and continue its once-only path |
| `P!=nil`, `Jr=nil`, no `D/K/B/X`, same boot and exact original owner/epochs remain current, but the publication deadline expired | `closedUnused` | create no journal reserve or sink call; retain or erase the immutable prepared spool only through its existing Artifact retention/erasure owner |
| `P!=nil`, `Jr=nil`, no `D/K/B/X`, same boot and exact original owner remains live, but generation/policy/deletion/revocation currentness fails | `quarantined` | create no journal reserve or sink call; permit only the existing erasure/incident path and never adopt the prepared bytes under changed authority |
| `P!=nil`, `Jr=nil`, no `D/K/B/X`, same boot and the exact original owner is lost | `quarantined` | create no journal reserve or sink call; preserve only policy-permitted audit/erasure evidence and require a separately confirmed independent WorkUnit for later visible work |
| `P!=nil`, `Jr=nil`, no `D/K/B/X`, and the prepared publication belongs to an earlier boot | `staleBoot` | preserve it read-only, perform no old-boot close/reserve/sink mutation, and await a separately confirmed independent WorkUnit |
| `Jr!=nil`, `K` proved absent, no anchor request was ever issued or lost, no `B/X`, `sameLiveOwner` | `safePreclaim` | continue only that exact journal plus its unique first dormant permit/anchor sequence; no second publication identity |
| publication `Jr!=nil`, `K` proved absent after anchor submission/result/reply became uncertain, `Jf=nil`, `sameLiveOwner` | `reconcileOnly` | journal lookup/query-close only; never submit the anchor or invoke the sink |
| publication `Jr!=nil`, `K` proved absent, `Jf=nil`, the same-boot original owner remains live, but currentness/deadline fails | `reconcileOnly` | journal lookup/query-close only; never submit the anchor or invoke the sink |
| publication `Jr!=nil`, `Jf=nil`, and either its owner/boot was lost, `K/B` committed, or current `K/B` status remains unknown | `reconcileOnly` | journal lookup/finalize/close only; never invoke the sink |
| `Jf!=nil`, K3 publication close exists | `terminalReadOnly` | restore finalized bytes; execute no sink call, including after reboot |
| `Jf!=nil`, K3 publication close is absent, same boot/current owner permits closure | `reconcileOnly` | install only the existing K3 close from the exact finalization record; no sink call |
| `Jf!=nil`, K3 publication close is absent, same boot, but owner/current epochs do not permit closure | `quarantined` | retain the finalization for policy-permitted audit/erasure only; perform no K3 close or sink call |
| `Jf!=nil`, K3 publication close is absent after reboot | `quarantined` | keep the finalization auditable but perform no cross-boot K3 close |
| Zone-C pending, `K` proved absent, no anchor request was ever issued or lost, no `B/X`, `sameLiveOwner` | `safePreclaim` | continue only the same saga's unique first permit/anchor sequence, or close unused |
| Zone-C pending, `K` proved absent after anchor submission/result/reply became uncertain, `sameLiveOwner` | `reconcileOnly` | query-close/reconcile the same saga identity only; never submit the anchor or dispatch |
| Zone-C pending has `K` proved absent, the same-boot original owner remains live, but currentness/deadline fails | `reconcileOnly` | query-close/reconcile the same saga identity only; never submit the anchor or dispatch |
| terminal effect receipt is nil, and either the Zone-C owner/boot was lost, `K/B` committed, or current `K/B` status remains unknown | `reconcileOnly` | query/reconcile that exact saga; never redispatch |
| terminal effect receipt and its K3 seal/activation both exist | `terminalReadOnly` | reopen the completed result for read-only audit/projection; zero effect calls |
| terminal effect receipt exists but K3 seal/activation is absent, same boot/current owner permits closure | `reconcileOnly` | install only the existing K3 closure/activation from that receipt; zero effect calls |
| terminal effect receipt exists but K3 seal/activation is absent, same boot, and owner/current epochs do not permit closure | `quarantined` | retain only policy-permitted audit/erasure evidence; perform no K3 closure/activation or effect call |
| terminal effect receipt exists but K3 seal/activation is absent after reboot | `quarantined` | perform no cross-boot closure/activation; await operator/user recovery policy |

The rows are mutually exclusive after first partitioning by boundary kind and boot relation, then equality-checking presence, possible-start, terminal, owner liveness, currentness, observation origin, and closure presence; an anchor with `Q=nil` is still possible-start and is never conflated with an unanchored dormant permit. Provider recovery actions use the Provider rows under their own finite ordinals. The WorkUnit aggregate is deterministic across those independently classified boundaries: any `quarantined` class yields `quarantine`; otherwise any `reconcileOnly` yields `reconcileSameOperation`; otherwise a fully completed graph containing only `terminal/terminalReadOnly/closedUnused` yields `restoreCompleted`; otherwise any `staleBoot`, expired confirmation/user-presence, interrupted visible prefix, missing mandatory context, changed Provider/account/region/disclosure/cost/effect identity, or unfinished earlier-boot graph yields `awaitUser`; otherwise an unfinished same-boot graph with only `terminal/terminalReadOnly/closedUnused` predecessors creates or revalidates the exact strict rebase request and yields `rebuildAfterTerminal`; otherwise any `safePreclaim/liveSameBoundary/liveSameInvocation` yields `resumeSameAttempt`. Aggregate precedence resolves different boundaries, not overlapping predicates. A pending confirmation is restored as pending; it is never answered on the user's behalf. Two windows or recovery workers race through the same existing K3 CAS/claim and at most one wins.

A `TargetContinuationCheckpoint` may resume only inside the same demonstrably live physical invocation and Attempt, with exact material/profile/QualityIdentity, StateABI/ProcessorABI, accepted-token-history digest, pending token, RNG/sampler/grammar state, position geometry, cancellation fence, visible-prefix fence, boot/owner epochs, and integrity proof. It is never a process-restart checkpoint.

Same-boot owner-loss closure for `.inProcessCertified` is an explicitly controlled K3 amendment, not an invented observation. Its package-private K3 command requires the exact local claim; equal current boot; an irreversibly fenced/dead original owner epoch; the allocation-bound signed containment profile proving that no physical invocation can survive that owner; nil `K/B/X/O/S`; no visibility, publication, effect, or other external boundary; and current Attempt/generation/policy/deletion/revocation facts. K3 records that predicate/result in the historical K3 row/source head and advances that existing local Provider event head to terminal `failed`. The public failed seal retains nil proposal/result and the already required nil/nil boundary-arm/observed-receipt pair; it creates no `BASProviderObservedReceipt`, attestation Artifact, call permit, or public wire field. This path is unavailable to AFM, isolated, remote, system-managed, cross-boot, anchored, visible, or merely liveness-unknown execution.

A local proposal or terminal-result Artifact ordinary-put before `sealProviderEventHead` is not a competing terminal truth: the current Artifact Store can read only a known Artifact ID and has no general claim-parent lookup, while the K3 claim row does not persist those prospective IDs. Until the one normal K3 terminal-seal transaction commits its historical row, such bytes are unreachable orphans and cannot be supplied by `ContextContinuityManifest`, a caller, or recovery to defeat the owner-loss predicate. If that K3 transaction committed, its row already freezes the canonical seal receipt bytes and `S` is idempotently reconstructible through the historical-put path; it is no longer the `S=nil` owner-loss state. Thus the two outcomes linearize on the K3 event-head CAS: normal seal row won, or fenced owner-loss failed seal won, never both. A future discoverable pre-seal tuple would require a separately reviewed K3 pending-row amendment and crash matrix rather than treating orphan Artifacts as authority.

AFM, an isolated extension, or another system-managed profile cannot infer quiescence from App-process death; it needs exact terminal/cancellation-quiescence or authenticated same-operation query evidence, otherwise the branch is quarantined and no successor Provider allocation is legal. Device reboot after a claimed local invocation is also quarantine/await-user: the only cross-boot mutation remains the existing isolated/remote `authenticatedQueryRecovery` terminal seal, so local `CP` cannot be revived or sealed from the new boot. A future local cross-boot closure requires another explicit K3 amendment. Previously verified visible chunks remain auditable and are marked interrupted; a separately confirmed independent WorkUnit may emit a new complete or partial response, but never pretend to byte-continue or retry the unresolved invocation.

Recovery never serializes raw CoT, Swift stacks/continuations, tasks, actor mailboxes, mutable prompts, credentials, capabilities, one-use permits, Provider thread/session IDs, or volatile model tails. A deterministic local step interrupted before commit discards orphan output and recomputes from committed inputs without replenishing budget. A committed K3 terminal-seal row reconstructs its normal `S` without another Provider call; proposal/result Artifacts without that row are unreachable orphans, not an alternate completion. A prepared publication is resumed only through its original journal identity; an armed/unknown sink is lookup/finalize-only. An armed/unknown effect is Zone-C reconcile-only. Policy/deletion/revocation checks happen before touching checkpoint bytes or reacquiring a model.

### 4.7 Historical review without an unbounded prompt

An explicit request to review past dialogue creates a HistoricalReview WorkUnit against a frozen snapshot of the current Workspace. V1 returns `denied` or `notApplicable` for cross-Workspace historical joins because the governed snapshot, visibility, erasure, and Attempt contracts each bind one Workspace. Identity similarity or a broad grant cannot widen them in place. A future federated design may fan out separately admitted/granted/snapshotted child WorkUnits per Workspace, join only authorized typed child Artifacts, and revalidate every source Workspace's policy/deletion epoch at release; it may not create a multi-Workspace store or snapshot owner.

L6 identifies the review question; L7 declares episode/range/claim coverage; L8 retrieves exact event ranges and raw-span-linked artifacts; L3 compiles bounded episode capsules; L9 synthesizes; L10 verifies temporal order, quotations, corrections, conflicts, and coverage; L11/L14 enforce disclosure; and L12 renders the result. For large histories, the WorkUnit fans out independent episode capsules and a `JoinArtifact` proves included/excluded ranges, current supersession state, unresolved obligations, and source coverage. No sub-Agent receives the full transcript merely because the UI displays one long conversation.

Historical replay uses recorded Provider proposal/receipt artifacts and authoritative events. It does not rerun AFM or a remote model, reopen a server-side thread as truth, or regenerate an old answer under a newer model. The user may request exact prior text, but model context receives only the minimum authorized spans needed for that review.

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

Only a terminal payload whose pair is `converged + convergedVerified` and whose committed K3 budget-use receipt is present may feed authoritative downstream adoption. Every other canonical terminal state/reason pair remains non-authoritative; this includes `cycle_detected`, `no_progress`, `budget_exhausted`, `degraded_with_coverage`, `needs-confirmation`, and `indeterminate_needs_reconciliation`. Swift case `needsConfirmation` has the existing canonical encoded spelling `needs-confirmation`; this addendum does not silently migrate that frozen wire or add a seventh state. L10/L11/L14 may nevertheless authorize a user-visible report containing only an independently verified subset plus an explicit unresolved-scope manifest; it does not adopt the unresolved remainder as fact. A one-pass task that was verified without entering a ControlRing needs its normal verification receipt, not a fabricated RSI receipt.

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

`BASContextCompiler` in `ContextCompilerCore.swift` remains the sole L3 context-packing owner. “Context Budget Allocator” and “State Compiler” name two phases of its existing `compile` path and planned same-owner `compileExact` extension, not new types, files, schedulers, stores, or authorities; semantic, scoped, and turn compilers supply typed projections only. Its context-budget allocation phase gives each required section an explicit byte/token budget and priority, and its State Compiler phase:

- includes the task contract, hard constraints, exact high-authority evidence, material conflicts, selected history, tool schema only when authorized, and output/verification contract;
- tokenizes canonical sections once for the selected model/tokenizer identity;
- emits exact section digests, offsets, provenance, authority labels, and an omission ledger;
- renders evidence/model output as escaped inert data distinct from system instructions and tool/output schemas;
- distinguishes full prefill, same-Attempt suffix continuation, exact prefix-cache reuse, and full rebuild;
- never truncates a hard constraint, conflict qualifier, negation, source span, or output schema silently.

Omitted material remains inspectable in the omission ledger. Any model/tokenizer/template/StateABI or cross-model change recompiles the context.

### 6.6 Per-Provider adaptive context geometry

There is no authoritative global `maxContextTokens`, and a model family name does not determine a safe window. Upstream architecture ceiling, converted/exported static geometry, device/OS-certified working range, phase-specific cache/MTP bounds, live resource admission, output reserve, and task-required coverage answer different questions. The current Qwen manifest's upstream-scale number, MLX/AFM descriptor defaults, MTP stream bound, and Core AI session `maxSeq` must not compete as interchangeable routing truth.

A versioned `CertifiedContextGeometry` has exactly one canonical byte representation inside the signed certified Provider profile; it is not an independent registry or authority. Material descriptors, plan templates, execution plans, context descriptors, and receipts carry only its Artifact ID/digest plus equality-checked projections required for their own proof:

```text
capTopology: sharedTotal | splitInputOutput | encoderOnly
accountingProof: deterministicTokenSpans | opaqueRuntimeExactCount | certifiedConservativeUpperBound
model material / remote cohort + tokenizer OR opaque-accounting-contract digest
template / tool-protocol / schema digests
reasoning mode/custom-value digest + private reasoning reserve contract
ProcessorABI / StateABI / mask / position geometry
certified static total/input/output buckets or remote caps
certified usable prompt bands and generation/verification reserve policy
fixed template/tool/schema overhead and modality-token geometry
independent tool/schema/modality/request-byte limits
prefill/decode/verify/MTP phase bounds and legal transitions
device/OS/specialization or remote endpoint/account cohort
quality/latency/memory/energy/reliability evidence range
```

L7 first expresses semantic requirements in claim/span/artifact terms independent of tokenizer. L2 reopens the selected binding/template/profile and enumerates only certified geometries for that exact Provider step. L1/K1 filter against the signed local resource or remote cost/network/rate admission envelope without selecting semantic truth or a Provider. L3 uses certified segment upper bounds to form a canonical candidate. A deterministic tokenizer/processor yields reproducible token IDs and spans. An opaque runtime such as AFM may yield an exact whole-request count without exposing token IDs/spans, but that async/throwing Provider mechanism never runs inside pure L3. An opaque remote contract instead uses a locally proven tokenizer or certified conservative bound; Qinao never discloses content merely to count it before egress authorization. The execution plan freezes both orthogonal dimensions, every cap, accounting contract, reasoning mode, and reserve before K3 allocation/claim.

Opaque exact accounting is a bounded two-pass value protocol, not a ContextManager. Pure L3 emits a self-ID-free `BASContextAccountingRequest` over the canonical complete candidate—exact instruction/transcript/prompt/tool/schema/output-contract bytes and section digests—using certified upper bounds. The external Provider package calls only its local/system accounting API and returns an immutable `BASContextAccountingReceipt` binding request digest, Provider/profile/cohort, geometry ID, accounting-contract digest, exact total and available split counts, reasoning mode, current capability epoch, and success/failure. L3 reopens that receipt and either emits the final descriptor or deterministically removes optional sections/reissues one bounded candidate; mandatory overflow or any accounting failure makes the profile pre-claim ineligible. The materializer/session rechecks the exact request, tools, schema, output and private-reasoning reserves, profile/cohort, and current epoch immediately before claim. No receipt may contain content, token IDs the Provider did not expose, or a mutable session handle.

AFM adds a tagged `AFMAccountingShape` so “exact total” cannot double-count instructions or omit transcript/tool/schema state. The first production profile supports only `freshAttemptSession`: one exact `LanguageModelSession` construction recipe, exact instructions, an empty Provider transcript, one complete Qinao-compiled prompt, the exact empty-or-present tool/schema/output contract, visible-output/private-reasoning/protocol reserves, `contextSize`, and a certified ordered vector of the concrete `tokenCount(for:)` overload calls plus checked aggregation recipe. Qinao conversation history appears once inside the compiled prompt, not again as a Provider transcript. A future `liveSameAttemptSession` shape must bind the demonstrably live session-context digest, existing transcript-usage receipt, next prompt, tools/schema, exact overload vector, and non-overlap proof; it is a new certified profile and is never valid after process loss or across Attempts. The materializer reconstructs the same shape field-for-field before execution; missing overload support, throwing count, non-additive ambiguity, or mismatch is pre-claim ineligibility.

For a selected geometry, `inputAccounted` always includes mandatory and optional prompt content plus every input-side template/tool/schema/modality/protocol unit and its certified margin. The cap topology selects exactly one conservation proof:

```text
sharedTotal:
  requiredTotal = inputAccounted + visibleGenerationReserve + privateReasoningReserve
                + sameInvocationOutputProtocolReserve + sharedSafetyMargin
  require requiredTotal <= totalCap
  optionalInputBudget = totalCap - mandatoryInputAccounted
                      - visibleGenerationReserve - privateReasoningReserve
                      - sameInvocationOutputProtocolReserve
                      - sharedSafetyMargin

splitInputOutput:
  require mandatoryInputAccounted + inputSafetyMargin <= inputCap
  optionalInputBudget = inputCap - mandatoryInputAccounted - inputSafetyMargin
  require visibleGenerationReserve + privateReasoningReserve
          + sameInvocationOutputProtocolReserve
          + outputSafetyMargin <= outputCap
  // unused output capacity cannot pay for input, or vice versa

encoderOnly:
  require visibleGenerationReserve == 0
       && privateReasoningReserve == 0
       && sameInvocationOutputProtocolReserve == 0
       && mandatoryEncoderAccounted + encoderSafetyMargin <= encoderCap
  optionalEncoderBudget = encoderCap - mandatoryEncoderAccounted - encoderSafetyMargin
```

Tool count, schema complexity/bytes, modality count/geometry, attachment bytes, request bytes, and any Provider-specific per-field limit are separate hard predicates and must each pass; spare capacity in another dimension cannot compensate. `Accounted` means reproducible exact tokens under `deterministicTokenSpans`, exact whole-request/runtime counts under `opaqueRuntimeExactCount`, or the certified conservative upper bound under `certifiedConservativeUpperBound`. `privateReasoningReserve` is capacity only: Provider-private reasoning text is never requested, shared between Agents, persisted, or treated as evidence. A separate verifier branch owns its own `CertifiedContextGeometry` and BudgetLease; its tokens are not subtracted from the main Provider's window. Same-invocation protocol reserve covers only grammar/protocol material that the selected Provider contract explicitly counts in that same invocation.

The default is the smallest currently admissible certified bucket/cap profile that satisfies all mandatory content and reserves. A larger profile is selected only when additional evidence/context provides a measured, task-relevant verified-utility gain that justifies TTFT, state memory, energy, thermal, remote cost, privacy, and switching costs. The system never chooses the theoretical maximum merely because it exists. Live pressure filters or defers among already certified profiles before allocation; it cannot invent an intermediate window or shrink the frozen context after claim.

`BASContextCompiler.compileExact` must derive every limit by reopening `execution binding → plan template → certified profile/material or remote cohort`; a caller-supplied bare integer such as `totalContextTokenLimit` is never authority. Under `deterministicTokenSpans` it emits the reproducible token plus byte/section-span map. Under either opaque mode it emits exact byte/section spans plus a reopened accounting receipt or certified per-span upper bounds; it never invents token IDs or token boundaries. Every mode emits section fingerprints, the topology-specific conservation proof, visible-output/private-reasoning/protocol reserve accounting, profile/geometry identity, omission ledger, and `BASContextBudgetReceipt`. “Exact” describes equality to the selected accounting contract, not fictional visibility into an opaque tokenizer. The plan reopens and equality-checks those values before execution.

Provider-specific accounting remains explicit:

- on-device AFM binds the exact `SystemLanguageModel`/OS cohort, `AFMAccountingShape`, `contextSize`, concrete `tokenCount(for:)` overload vector, and checked aggregation recipe available from FoundationModels; a documentation default or one device probe is not a permanent limit. The initial fresh-session shape counts each instruction/prompt/schema/tool/output/reasoning/protocol component exactly once and carries no separate Provider transcript. `async`/throwing failure, unavailability, overlap ambiguity, or cohort change is pre-claim ineligibility. Unless the API exposes reproducible token boundaries, AFM uses `opaqueRuntimeExactCount` with exact byte/section spans rather than claiming tokenizer/token-span identity.
- Qwen and MiniCPM local profiles use only converted Core AI/legacy-baseline geometries that passed device certification. Upstream 262K/131K-scale model-card ceilings do not imply iPhone capacity.
- MiniCPM-V counts the exact processor-produced visual tokens plus text under an image- or video-specific `ProcessorABI`; image count is not token count and critical fidelity cannot be silently downsampled.
- Granite uses `encoderOnly` sequence geometry and structural chunks with reversible raw-span mapping. It has no generation reserve and its encoder ceiling is not a main-Agent conversation window.
- A custom remote API profile binds the Provider's exact tokenizer or opaque accounting contract, endpoint/model cohort, input/output/reasoning/tool/schema/modality/request-byte caps, and terminal usage-observation semantics. If exact local client tokenization is unavailable, a certified conservative bound selects/materializes the request and supervisor observation or attestation records actual usage; a Provider-native usage object never self-promotes to authority and observation cannot retroactively authorize an over-limit or over-budget call. A PCC opaque profile binds its visible context/quota/reasoning surface and reserves conservatively; moderate/deep/custom reasoning remain ineligible until their exact profile has a certified upper-bound contract. Optimistic character division is forbidden.

Every main/sub-Agent Provider step receives its own minimal compilation. A specialist does not receive a proportionally shrunken copy of the main prompt. Cache identity includes the exact Provider/model or endpoint cohort, tokenizer digest **or** opaque-accounting-contract digest, template, tool protocol, reasoning-mode digest, context bucket/cap topology/accounting proof, ProcessorABI/StateABI, position/mask geometry, Workspace/snapshot/visibility/erasure scope, and relevant OS/account/region/policy epochs. Tokens, local KV/SSM, AFM transcript state, remote server-session state, and prefix caches are never portable across incompatible identities.

K3/artifact decoders may impose checked-arithmetic and byte-size anti-DoS bounds, but a fixed value such as `262,144` cannot be the semantic context ceiling for every future Provider. This is an explicit controlled amendment to the frozen K3 addendum, not an interpretation layered around its current validator. Numeric token observations are accepted only when they fit the exact certified profile/geometry, materialized request, BudgetLease/grant, and decoder-size-derived safe integer bound. A larger profile therefore requires its own sealed evidence and lease; it does not silently widen any existing profile. Until the K3 schema/validator, registry fixtures, and mutation gates are revised atomically, any profile exceeding the current hard validator bound remains ineligible.

If mandatory content cannot fit any eligible geometry, L3 does not truncate it. The legal sequence is provenance-preserving compaction/retrieval projection, decomposition into WorkUnits with known join semantics, mark the Provider/profile ineligible, request an explicitly authorized Provider change, or return the applicable `needsClarification`, `partialVerified`, `abstain`, or `denied` sufficiency outcome.

## 7. Provider-Adaptive Apple Silicon, AFM, and Remote Execution

### 7.1 Healthy full-blood use

“Full-blood” means the exact selected quality identity and task contract run through the best verified plan under memory, energy, latency, thermal, and recovery constraints. It does not mean saturating every compute unit or refusing to checkpoint.

The process has one authoritative local HeavyPhase owner. Independent CPU retrieval and lightweight work may overlap when K1 proves headroom. Two local model trunks may not compete because multiple Agents are logically active.

Thermal or memory pressure may:

- defer a specialist branch;
- serialize phases;
- checkpoint and resume;
- evict rebuildable cache or specialization;
- before K3 allocation, request selection of a pre-certified same-quality, same-StateABI compatible plan;
- after allocation but before claim, defer or continue that allocation to its first claim without changing plan, Provider, request, or call identity only while the Attempt, generation, policy/deletion/revocation and owner/boot epochs, request, and any dormant pending-permit/anchor deadline remain current; an expired unanchored tuple closes unused and may reach a same-boot successor only through strict rebase after every predecessor boundary is terminal; an anchored or unknown-anchor tuple is reconcile-only and is never re-armed;
- while the same claimed invocation is demonstrably live, join, pause, or continue that invocation only; after owner/process loss, handoff, or `sent_or_unknown`, query/reconcile/seal only and never recreate a call permit or physical call;
- stop admitting new heavy work.

Pressure may not silently change model, quantization, context, sampling, tool contract, or answer quality identity.

iOS lifecycle callbacks, background launches, and termination notifications are resource hints, never correctness boundaries. Before claim the runtime may defer or checkpoint when the exact profile permits. After claim, only the same live invocation may pause/resume; owner/process loss follows the query/reconcile/terminalize rule above. The existing background-task owner may request bounded time, but no keepalive, `willTerminate`, or background callback is required for safety.

### 7.2 Core AI function portfolio

A certified Qwen Core AI package may expose separate embedding, trunk, LM-head, prefill, decode, optional native MTP, and state-management functions. The first `Qwen3.5-4B/textOnly` profile exposes no vision and no native MTP until those exact functions are certified. The current multi-asset chain remains one physical Provider invocation with one K3 branch and one terminal observation; its internal asset stages do not become new authority branches.

For iOS, `platform + staticMaxContext + prefill/decode/verify bucket + batch/K + attention-mask/position geometry` is part of asset identity, execution-profile identity, and StateABI. An over-limit request is recompiled into certified chunks/buckets or rejected; it never dynamically expands mutable geometry. Every mutable Core AI session is per Attempt and wrapped by an actor or noncopyable single-driver lease. Shared compiled immutable functions are reusable, but KV/state, `MutableViews`, counters, cancellation fences, and checkpoints are not.

Any function-stage fault, cancellation, timeout, or unknown completion poisons the whole mutable Provider-state lease; partially advanced `MutableViews` are never treated as valid. Rebuild from the last certified checkpoint is legal only inside the same demonstrably live `executeAtMostOnce` invocation under its still-consumed fresh claim and when the exact profile proves an atomic bounded snapshot/restore protocol. If executor/owner/process/completion is unknown, recovery is query/reconcile/seal-only and cannot use a checkpoint to start another physical Provider call. Release tests inject faults at every function boundary and race `step/prefill/reset/cancel/restore`, eight windows, and late completions.

MiniCPM5 loads on demand for admitted text-specialist work. MiniCPM-V loads only for an admitted visual WorkUnit and exact image/video ProcessorABI. Granite may remain warm only when its measured footprint/energy and expected reuse fit K1 policy. AFM remains system-managed, but its latency, cancellation, availability, and semantic capability still enter the Qinao plan and receipts.

An AFM Attempt owns an independent `LanguageModelSession`. The first production `freshAttemptSession` profile has an empty Provider transcript and tool set; Qinao history appears exactly once in the compiled prompt under the certified `AFMAccountingShape`. From prewarm/request until terminal completion or observed cancellation quiescence, it holds an opaque local-heavy lease; Qinao does not start another local Core AI heavy phase concurrently and receipts record placement as observed/unknown rather than claiming an execution unit. An OS/system-model update creates a new cohort. Historical replay consumes the recorded AFM output artifact instead of rerunning AFM. If the certified platform profile cannot prove the required no-durable-derivative or purge semantics, AFM is ineligible for data requiring physical erasure.

Placement is empirical per phase. A Qwen body may favor Neural Engine while a vocabulary head favors GPU; Granite or vision may have different profiles. Production claims require runtime/energy evidence, not a `.neuralEngine` preference or architecture label.

Future Apple Silicon is admitted by an exact observed capability and certified evidence profile. No production branch assumes a future chip name, core count, accelerator behavior, memory cap, or entitlement from marketing identity alone.

### 7.3 Cache and continuation identities

The readable labels `PromptPrefixCache` and same-Attempt `ContinuationCheckpoint` reuse the master's canonical `PrefillPhysicalStateKey`, `ContinuationCheckpointKey`, and `TargetContinuationCheckpoint`; they do not declare a new cache/checkpoint family. They are distinct:

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

Local/system-device performance certification uses at least two physical devices and a 1,800-second sustained run per exact local profile. It reports P10/P50/P95 accepted decode rate, end-to-end goodput, time to first releasable token, energy, RSS/physical footprint, thermal trajectory, MTP acceptance, cancellation/recovery, failures, and identity parity. Remote profiles instead use multiple independently identified endpoint/account/time cohorts and do not fabricate local-device or thermal claims. Structural W6 completion may legitimately deny the 40/30 marketing claim while accepting the architecture.

### 7.6 Dual-axis adaptation

Qinao adapts both to the person and to the exact Provider execution profile, but those axes remain separate until the frozen plan joins them:

```text
HumanFitProjection
  expression / language / pace / explanation depth / interaction preference

ProviderExecutionVector
  capability / context / template / backend / cache / decode / verification
  / latency / memory / thermal / energy / network / cost / recovery

hard semantic, privacy, authority, quality, and resource-safety gates
→ robust Pareto join
→ one frozen BASExecutionPlan + L12 presentation contract
```

`HumanFitProjection` and `ProviderExecutionVector` are bounded values interpreted by the existing L5/L6/L2/L3/plan owners, not persisted managers, registries, or new decision authorities. There is no global comfort score. User emotion or habit cannot change truth, risk, disclosure, tool/effect authority, mandatory evidence, verifier floor, model material, or safety level. Model/runtime telemetry cannot write a user preference. L12 presentation choices cannot select a physical Provider route, and K1 resource signals cannot choose tone or persona.

The feasible set first satisfies authority, privacy, quality floor, mandatory coverage, memory/thermal safety, StateABI/ProcessorABI, cost/disclosure authorization, and recovery legality. Only explicit route preferences—local/cloud, named Provider, network use, cost, or latency—may enter Provider-plan comparison. Tone, pace, explanation depth, formatting, and other HumanFit fields shape only the L12 presentation contract and never route a Provider; required language/schema remains a capability hard gate, not a personality preference. Inside those boundaries the plan may compare verified task success, permitted route-preference fit, time to first releasable output, completion latency, UI responsiveness, accepted/released goodput, energy or remote cost per completed task, thermal slope, memory headroom, cache locality, failure/rebuild risk, and switching cost.

### 7.7 Human adaptation without a hidden psychological profile

Human-facing signals retain an explicit epistemic status:

```text
explicitUserStatement
observedInteraction
derivedHypothesis
confirmedPreference
unknown
```

“Thought” means a belief, goal, value, or intention the user expressed; Qinao never claims mind reading. Emotion, frustration, urgency, confusion, expertise, or cognitive load inferred from wording is a low-confidence L6 current-situation hypothesis, not a diagnosis. It is process/Attempt scoped with short expiry and is not durable by default. A Provider's label or confidence cannot promote it.

Low-impact reversible presentation changes—such as answer-first structure, shorter paragraphs, more steps, slower pacing, less jargon, or a neutral/gentle tone—may use clear current-turn evidence without repeatedly interrupting the user. Cross-task/Workspace persistence, sensitive-trait use, remote disclosure, a change from the installed/explicit Provider selection, stronger persuasion, an external action, or a high-impact policy change requires an explicit existing preference or confirmation. The precedence below applies only inside the already satisfied authority/privacy/safety gates:

```text
current explicit instruction
> current-task explicit preference
> confirmed Workspace preference
> transient hypothesis
> neutral safe default
```

Only a direct user statement such as “always answer in Chinese and lead with the result,” or a system proposal the user explicitly confirms, may become a durable L5 preference. Repeated behavior may create a confirmation proposal but cannot self-confirm. A durable preference binds purpose, Workspace/scope, sensitivity, provenance span, valid/transaction time, expiry when applicable, consent receipt, allowed/denied uses, correction target, and deletion epoch. A single dismissal, click, dwell time, next-question-card action, response length, or emotional moment cannot be promoted.

The objective excludes click-through, conversation duration, dependency, compliance, emotional arousal, purchase, notification engagement, or retention proxies. Vulnerability, loneliness, anxiety, anger, or confusion cannot trigger urgency, scarcity, flattery, stronger persuasion, notification, remote disclosure, or a lower verification bar. Protected or highly sensitive traits are not inferred for personalization; when the user explicitly supplies sensitive information and the task needs it, purpose, disclosure, retention, and deletion constraints still apply.

L3 includes only the minimum typed human-fit projection needed by that Provider step. Main and sub-Agents do not receive a complete user profile. A user correction immediately supersedes the transient interpretation, fences affected compiled contexts/caches/Provider derivatives through existing generations, and falls back to neutral/clarify after repeated misreading rather than guessing harder.

### 7.8 Per-Provider certified operating envelope

Each exact `QualityIdentity × material or opaque/remote cohort × tokenizer/processor/accounting contract × canonical context-geometry identity × device/OS or endpoint/account cohort` carries a `CertifiedOperatingEnvelope` embedded in the existing signed profile/plan evidence. The `CertifiedContextGeometry` subvalue in the profile is the sole cap/accounting/geometry truth; the operating envelope references its exact identity and never copies editable caps or prompt bands:

```text
supported task / language / modality classes
canonical CertifiedContextGeometry identity
prefill / decode / MTP / prompt-lookup finite states and legal edges
prompt template / tool-proposal / structured-output compliance
resident/transient memory or remote quota/rate/cost envelope
cold / warm / cache-hit operating regimes keyed by canonical geometry bands
quality, calibration, accepted-token, latency, energy, thermal, and reliability curves
cancellation / checkpoint / query / rebuild / purge legality
minimum evidence count, confidence bounds, freshness, dwell, cooldown, and rollback rules
```

Any cap/band repeated in a diagnostic or selection projection is derive-and-equality-check display data from that canonical subvalue. A mismatch makes the profile ineligible; no last-writer or “more recent table” rule exists.

The runtime selects only nodes and edges already present in that finite certified graph; it does not perform an unconstrained online parameter search. Qwen evidence is not inherited by AFM or a remote model. Cold short-context data is not averaged into a hot long-context claim. A quantization, template, tokenizer, ProcessorABI/StateABI, geometry, toolchain, OS, endpoint, region, account, retention policy, or model-cohort change invalidates the affected envelope even if the marketing model name is unchanged.

AFM contributes only observable/contracted opaque-session evidence. A remote API contributes network, price, quota, rate-limit, terminal-query, retention, and disclosure evidence rather than local thermal/KV claims. A small specialist is selected for a certified role, not merely because it is cheap or fast. User-selected Provider preference is a plan input; if that exact profile cannot satisfy the task, Qinao reports ineligibility and requests an authorized alternative instead of silently choosing one.

### 7.9 Fast, Attempt, and evidence cadences

These cadences are uses of the existing four ControlRings, not three new rings or an `AdaptiveManager`:

| Cadence | Decision boundary | May adapt | May not adapt |
|---|---|---|---|
| fast | token/chunk/safe checkpoint inside one claimed invocation | disable a losing preauthorized MTP/prompt-lookup lane, backpressure, release disposable cache, or safely pause the same invocation when the exact profile permits | Provider, tokenizer/template, context, mandatory evidence, QualityIdentity, tool/disclosure contract |
| Attempt | candidate comparison before first selection; thereafter only same-lineage pre-allocation plan/geometry replacement, or a new WorkUnit/Attempt | exact Provider/profile at initial selection, context bucket, prefill/decode path, specialist DAG, verification ladder, concurrency, remote cost/network envelope | change selected Provider/model/profile lineage after context compile starts, mutate an allocated/claimed route, create a second physical call, transplant state across Providers |
| evidence | sealed turns, session/day/week, certification/version epoch | produce candidate calibration evidence for future certification, form user-preference confirmation proposals, shadow compare, propose a future profile/version | persist an unconfirmed preference, edit running code/weights/schema/policy, self-promote, use raw unconsented user data |

Every reversible automatic selection uses separated degrade/recover thresholds, a deadband, minimum sample count and confidence bound, minimum dwell, cooldown after failure, transition-rate limit, incumbent bias, and an explicit switching cost for recompilation, prefill, cache miss, network, money, and thermal shock. Thresholds remain in the signed envelope. Current dwell/cooldown/transition count/incumbent state is a deterministic read-only projection of existing K3 EventLog plus plan/usage receipts scoped by exact profile × phase × device or endpoint cohort; missing history means the installed incumbent wins. User explicit selection may override soft incumbent bias only in a new Attempt and never overrides eligibility, disclosure, budget, revocation, or safety cooldown. Emergency resource paths are monotonic: stop optional mechanisms, pause/defer, checkpoint when certified, or deny new work. They cannot hide a model/quality/context/verification downgrade.

Local acceptance EMA, remote rate headers, latency samples, user reactions, and model self-reports are observations, never selection authority. Evidence cadence may propose future certification evidence but cannot edit a signed envelope online. For automatic replacement, only an installed signed node inside the same sealed Release envelope may replace the incumbent when its conservative evidence dominates under the hard gates. An explicit user selection may choose any installed signed eligible profile in a new Attempt, still subject to every authority, quality, disclosure, budget, revocation, and safety-cooldown gate. An undeployed profile remains an E4/E5/promotion proposal. Shadow branches have independent context/state and no visibility, commit, tool, disclosure-expansion, publication, or effect capability. Canary activation belongs to a future signed epoch and cannot change an in-flight Attempt.

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
→ same K3 transaction: active Attempt head + initial BudgetLease row with zero cumulative use
→ TurnOperationRef + active Attempt/ContextWorkspace identity
→ L1 life/resource policy + L5 constitution/confirmed preference + L6 current situation
→ minimum HumanFitProjection with explicit epistemic status; no durable inference promotion
→ L4 prior + L7 StateRequirementPlan and hard semantic eligibility predicate
→ K3/L8 snapshot open + materialized hard physical eligibility partition
→ L8 SQL/exact/FTS/BM25/temporal/entity lanes inside that partition
→ conditional Granite dense: K1 phase reservation → K2 embedding mechanism → usage receipt
→ L7 lane-local dedupe/source caps → bounded fusion + coverage reservoir
→ optional MiniCPM grounding: R5 reservoir-bound plan → K1 reserve → committed K3 use
  → .groundingProposal/.internalProposal allocate/materialize/claim → K2 → grounding proposal
→ L7 final hard-eligibility revalidation, conflict/coverage and deterministic State Market
→ Information Sufficiency preflight; bounded preterminal ΩG/ΩD evidence/candidate remands re-enter L7 before context compile
→ user/host-selected certified Provider capability admission (local Core AI / AFM / authorized remote)
→ L2 exact neural/Provider requirement + eligible plan template/CertifiedOperatingEnvelope
→ L3 bounded context candidate; opaque mode only: external BASContextAccountingReceipt → L3 equality reopen
→ L3 BASContextCompiler finalization (context-budget allocation + State Compiler phase)
→ CompiledContextDescriptor
→ L2 freeze exact BASExecutionPlan bound to that descriptor
→ K1 heavy-resource reservation
→ committed K3 budget-use authorization
→ K3 typed Provider branch allocation + allocation reopen A
→ exact materialized Provider request + materialization reopen M
→ terminal answer-only source pin
→ isolated/custom-remote: L11 disclosure + L14 exact physical destination/payload authorization
→ PCC only: L11 disclosure + L14 exact logical service/profile/canonical-field authorization
  (platform-hidden physical destination/request facts remain explicit unavailable fields)
  → K4 one-shot authorization claim/use receipt → K3 egress prepare → K4 boundary anchor → K3 arm
→ incremental only: L11 provisional eligibility → L14 bounded stream grant → K4 one-shot provisionalStream claim
→ incremental mode only: K3 zero-byte logical visibility row (authorizes zero bytes)
→ fresh K3 claim permit
→ isolated/remote only: beginProviderEgressHandoff(claim, arm)
  → K3 armed-to-sent_or_unknown CAS → fresh BASProviderFreshRemoteCallPermit
→ K2 external Provider at-most-once prefill/decode supervision (remote permit consumed immediately when applicable)
   ├─ incremental only: reconstruct/reopen ProviderVisibilityReceipt before any stream permit
   └─ each releasable chunk: L10 receipt → K3 batch permit → K4 anchor → K3 arm → Adapter/IO sink under L12 provisional semantics
→ Provider/executor terminal result
→ isolated/remote supervisor observation + attestation when required
→ K3 terminal event-head seal
→ L9 candidate portfolio/selection
→ L12 exact non-visible presentation spool
→ L10 exact-output verification and convergence
→ L11 final risk/confirmation decision
→ Information Sufficiency presentation candidate (not yet a final outcome)
→ L14 exact release/denial authorization for that exact spool and current epochs
→ final Information Sufficiency outcome reopens the L14 receipt; only readyVerified may be unqualified complete
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

Recovery never means “call the branch again.” An unclaimed allocation may continue to its first claim only while its Attempt/generation/policy/deletion/revocation and owner/boot epochs plus any dormant pending-permit/anchor deadline remain valid; otherwise an unanchored tuple closes unused, while an anchored/unknown-anchor tuple is reconcile-only. A same-boot successor exists only through strict rebase after every predecessor boundary is terminal; an earlier-boot unfinished graph requires a separately confirmed independent WorkUnit. A live claimed invocation may only be joined or continued under its existing call identity. After an external handoff or possible send, recovery is query/reconcile/seal-only. After local process loss, only the exact same-boot `.inProcessCertified` private K3 proof may terminalize the dead local invocation; logical work then rebuilds through strict rebase and inherited budget rather than recreating the old call permit, appending to a partial publication, or transplanting runtime state.

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
- L5/L6 produce only authorized preferences and epistemically labelled current-situation projections; they do not rewrite facts, risk, or physical routing;
- L3 compiles the exact per-Provider context; it does not retrieve, choose truth, accept a caller-invented token limit, or select a Provider;
- K2 executes a model plan; L9/L10/L11/L14 decide whether its proposal is selected, verified, safe, and authorized;
- K1/ΩR may filter, defer, pause, or request a pre-allocation certified plan; resource telemetry cannot change tone, disclosure, Provider, context, or QualityIdentity after allocation;
- K3 persists facts and fences; it does not decide their meaning;
- L13 prepares/interprets state/effects; K3 stages, K4 authorizes/anchors, Zone C dispatches, L14 seals;
- a remote adapter receives only the exact redacted materialized bytes and one-use egress capability; server session/cache and returned tool calls remain non-authoritative;
- NextQuestionProjection consumes only finalized authorized artifacts and cannot mutate the completed Attempt.

## 10. Validation, Promotion, Migration, and Completion

### 10.1 Anti-vacuity gates

Every documented gate must prove it actually exercised the intended candidate:

- missing named files, directories, targets, fixtures, scripts, manifests, or globs are fatal;
- `rg` exit 2 is an infrastructure failure, never “no match”; named-file gates assert file existence first;
- focused-test wrappers discover the target and assert matched test count greater than zero before execution;
- authority-M candidate manifests and E/A extension manifests are independently schema-valid, rooted in the current candidate tree, and non-empty whenever their respective CreateGate or ExtensionGate is expected to evaluate candidates;
- SwiftPM/Xcode target membership is checked, not inferred from a filesystem path;
- baseline tests use only baseline APIs; later-wave APIs cannot make an intended RED test uncompilable;
- CI executes each checker and its own unit/adversarial tests with pinned prerequisites;
- every gate records exact tree, toolchain, command, current-wave `m_creates` / `ea_extensions` / `schema_fixtures`, candidate/test/glob counts, exit code, and relevant device identity;
- zero candidates, zero tests, or zero matched files is a failure unless a separately typed and reviewed `notApplicable` contract proves why;
- mutation tests rename/remove a named file, add a forbidden owner, corrupt a manifest, break a filter, and invert a predicate to prove that the gate fails closed.

These rules close the known “armed but never fired” candidate checker, M-versus-E/A gate confusion, zero-match Swift filter, missing-file `rg`, nonexistent target, and empty glob classes. A green command without non-vacuity evidence is not a gate receipt.

### 10.2 Validation domains

The integrated candidate must close all of these domains:

1. **Authority/ownership:** exact `14 / 4 / 4 / 7`, owner-ledger parity, no duplicate writer/router/scheduler/store, value-only Provider boundary.
2. **Contracts:** governed schema/version/canonicalization, task/context/Agent artifacts, ContextContinuityManifest/rebase/recovery values, the exact phase-tagged Information Sufficiency payload, embedded context/operating envelopes, exact Core AI function/StateABI/ProcessorABI manifests, exact versus system-managed-opaque remote profile variants, backward fixtures only for real historical wire versions.
3. **Core AI and Provider realization:** source/license lock, portable local material identity, compression search, host parity, cohort AOT, atomic install/update/rollback/revocation, AFM opaque-cohort behavior, remote endpoint/model/account/policy identity, device or endpoint fidelity, task quality, memory/network/cost, energy/thermal where applicable, cancellation, terminal query, and recovery.
4. **Agent/Provider isolation:** exact Provider-step capsule identity, minimum disclosure, inert data/instruction separation, branch/capability attenuation, no direct calls, no cross-window state/KV/server-session leak, no raw CoT exchange, no credential/model exposure, and remote egress only through the one-use fence.
5. **Reasoning/sufficiency:** raw-span-to-AST coverage and mutation oracles, long-text reversible spans, subjective perspective preservation, lateral epistemic modalities, seven exhaustive sufficiency outcomes, bounded repeated-challenge escalation, and cycle/no-progress termination.
6. **Retrieval/context/continuity:** hard physical eligibility before ranking, pre-grounding dedupe/fusion/reservoir, exact/FTS/BM25/dense parity, qualifier closure, conflict/coverage, omission ledger, pure-L3/external-receipt Provider accounting, mandatory-overflow fail-closed behavior, non-widening inherited-budget atomic rebase, same-Workspace historical range joins, process/session cold recovery, and tokenizer/model/index rebuild rules.
7. **Memory/human adaptation/privacy:** scoped artifact identity, cold replay, bitemporal as-of correction, explicit-vs-inferred preference states, current-instruction precedence, no behavior-only durable promotion, correction/retraction fences, anti-manipulation objectives, remote disclosure/retention/training/region scope, deletion epoch/tombstone, cryptographic key destruction, and blob/backup/quarantine/projection/cache/Provider-derivative rescan closure.
8. **RSI:** ring-specific potentials, canonical visited digests, fixed obligations, BudgetLease/K3-use accounting, adoption only for `converged + convergedVerified` with the committed use receipt, shadow-only consented/redacted evolution.
9. **Effects/egress/recovery:** failure injection at every durable boundary, no duplicate remote Provider/recovery-action/effect/publication call, exact disclosure and credential non-persistence, honest `sent_or_unknown`/indeterminate state, independent publication-journal reserve/finalize recovery, and K3/K4/Zone-C cold restart recovery without a SessionManager.
10. **Adaptive execution/release:** two-device local identity plus exact remote/system cohorts, fixed context geometry, Provider-specific operating envelopes, anti-thrashing thresholds/dwell/cooldown, poison-on-partial-stage-fault, Release single-driver races, load/prefill/decode/cache routes, one local HeavyPhase owner including AFM opaque leases, footprint, UI responsiveness, network/cost/rate behavior, power/thermal run where applicable, and exact Release-tree seal.

Next-question tests additionally prove zero-to-five transient candidates, one-card maximum, deterministic abstention, render-time CAS, no pre-tap work/write or candidate telemetry, no cross-window disclosure, no durable dismissal learning, accessibility, and tap-as-new-input semantics.

Continuity tests keep one visible Workspace across repeated internal rotations, suspension, SIGKILL, crash, device reboot, scene destruction, model unload, K4/helper restart, crash before/after K3 `rebase_pending`, K4 successor-grant reservation/receipt put, the active-head CAS, and K4 grant activation, model/tokenizer changes, corrections/deletions, unavailable checkpoints, and eight simultaneous logical windows. They fault every Artifact put and K3/K4/Zone-C/publication commit/reply boundary; race two rebase/recovery workers/windows, reservation expiry/closure, post-CAS pre-activation revocation/expiry/quarantine/recovery, cancellation, deletion, model update, late predecessor results, and user input; mutation-test every mandatory continuity/recovery slot, checkpoint identity, reservation-receipt signature, source/covering root, grant, Attempt/generation, boot/deadline, rights, ceiling, and epoch; exhaust `automaticWhenSafe`, `foregroundOnly`, `confirmationAfterInterruption`, and `neverAutomatic` with missing/stale/mismatched/replayed one-use confirmations and foreground/background opportunities; prove there is never more than one active Attempt, usable successor grant, or resumer; prove inherited budget/round/visited state never resets; prove grant/boot/deadline/rights/ceiling attenuation and that CAS losers remain non-consumable until proven close or original expiry; prove activation-unknown remains pending, a durable denial never rolls the head back or mints a replacement, and recovered K4 status cannot activate after a denial fence; race normal local terminal-seal commit against owner fencing, prove its K3 event-head CAS has one winner, prove a committed seal reconstructs `S`, and prove orphan proposal/result puts cannot change the failed-seal outcome; prove old Provider/KV/token/cache/session/grant identities cannot seed the new Attempt; prove unresolved predecessor boundaries yield zero successor external allocations; and verify same-Workspace HistoricalReview joins cover the exact requested event ranges. Cross-boot rebase and cross-Workspace review requests must fail closed in v1.

Context/adaptation tests cover each profile's `bucket-1 / bucket / bucket+1`, exact conservation of prompt + overhead + modality + visible-output/private-reasoning/protocol reserve, different tokenizers over identical text, forged caller limits, required-content oversubscription, vision processor geometry, encoder-only Granite chunks, AFM accounting failure/cohort change, PCC reasoning modes and unavailable fields, remote server-usage observation, over-262K certified-profile fixtures, and every cache/geometry/accounting-receipt mutation. User-adaptation tests prove one behavior/dismissal cannot persist, current instructions override old preferences, inferred emotion remains transient/unknown, sensitive traits do not drive personalization, corrections fence all affected derivatives, and engagement proxies never influence the plan.

Control tests exercise degrade/recover threshold separation, deadband, minimum samples, dwell, cooldown, transition caps, switching cost, incumbent bias, stale evidence, OS/model/account/policy changes, hot/cold and short/long context partitions, and emergency monotonicity. They prove no local statistic, model confidence, remote rate header, or user reaction can independently route, lower quality, promote a profile, or create a new authority.

Remote tests exercise live-credential/secret nonserialization; a local-only resolver; device-lock/deletion/rotation/cancellation/task-creation races; exact custom `postCASPreTransportLocalFailure` proof; exact PCC `postCASPrePCCRespondLocalFailure` proof and faults before, during/lost-reply-at, and after `pccRespondEntered`; FoundationModels errors before/after possible `respond(...)` entry; purpose attenuation and finite ordinals for send/one cancel/one terminal query; Zone-C-only purge; exact redacted payload and effective server-prefix equality; custom-transport denial of every redirect including same-origin/cross-origin/HTTPS-to-HTTP; PCC logical-service equality plus physical-field unavailability/scope ineligibility; consent/purpose/destination and policy/deletion epoch races; exact-versus-PCC-opaque presence matrices; 401/403/404/409/413/429/5xx/transport distinctions; malformed/truncated SSE; EOF without terminal evidence; usage/model/reasoning/finish-reason mismatch; conservative non-refundable max-cost use and crash-held cost; rate/quota/cost exhaustion; server cache/session scope; purge failure; lost response; result query; concurrent permit consumption; and local↔remote attempts. Replay and ordinary Provider code resolve zero credentials, fresh send resolves exactly once, and authorized query/cancel/purge cannot issue generation. No custom case may send without the exact authorization/permit, redirect, resend, disclose a broader payload, execute a returned tool call, or publish an unsealed proposal; no PCC case may infer nondisclosure from absence of an App transport task, downgrade a post/unknown-entry error to `failed`, or claim observation/control of hidden physical transport fields.

The crash matrix must include publication-journal corruption/restart/lost reply/indeterminate sink; K3 database corruption, quarantine, cold reopen, and monotonic-floor rollback; every Core AI function boundary, checkpoint seal, and partial `MutableViews` mutation; asset download/specialization/active-pointer/reader/revocation boundaries plus OS-update invalidation, cache purge, stale bookmark, and source move/delete; AFM cancellation quiescence, App-death with a deliberately late system completion, and lack of cross-process query evidence; owner/boot loss after `A` before `M`, after `M` before pending permit, before K4 anchor, after anchor/arm with a returned receipt, after anchor/arm with a lost reply while the owner remains live, after observation, after orphan local proposal/result puts before the K3 seal row, after committed K3 seal row before receipt put, and after publication/effect finalization but before K3 closure; and iOS suspension/termination/device reboot before and after allocation, claim, handoff, terminal observation, spool, publication reserve, sink, effect dispatch, K3 rebase prepare, K4 rebase reservation, active-head CAS, and grant activation. It proves raw CoT, thread stacks, credentials, Provider session IDs, and call permits were never serialized; orphan volatile tails are discarded; every Provider/recovery/effect/publication physical boundary count is at most one; local public owner-loss seals retain nil/nil egress evidence; every cross-boot mutation is either the existing authenticated isolated/remote query-recovery seal or rejected; and no second authority writer was created.

The cross-boundary simulation oracle is:

| Fault window | Only legal closure |
|---|---|
| eligibility or admission denies | zero payload query, model load, cache lookup, materialization, or external call |
| allocated but not claimed, no K4 anchor/unknown anchor result, same original owner/boot, and all bound epochs/deadlines current | same allocation may reach its first claim, or closes unused |
| unanchored pending permit in the same boot, no anchor request/reply was lost, but owner/deadline/currentness changed | close/query-close unused; never claim against, extend, or re-arm the old tuple |
| pure, allocated, materialized, or unanchored-pending work belongs to an earlier boot and no possible-start/authenticated cross-boot recovery evidence exists | preserve it read-only and await a separately confirmed independent WorkUnit; perform no old-boot close mutation |
| K4 anchor/arm exact receipt returned to the same live owner, no reply is unknown, and no suspension/interruption occurred afterward | continue only that boundary-uninterrupted returned-receipt sequence; never reconstruct/re-arm or create a second identity |
| K4 anchor/arm exact receipt returned, but suspension or another execution interruption occurred before its next transition | same boot: authenticated query/reconcile/finalize only, or quarantine when that protocol is unavailable; after reboot: only the old-boot read-only/await-independent-admission row applies; the returned receipt no longer carries arm/claim/call continuation authority |
| K4 anchor/arm result, reply, or delivery is unknown while the original owner/boot remains live | query/reconcile/finalize only; a lookup-recovered receipt never restores arm/claim/call authority |
| K4 anchor/arm is known but the original owner was lost in the same boot | same-operation query/reconcile/finalize when authenticated; otherwise quarantine; never arm or call |
| unclaimed `D/K/B/X` or anchor-request uncertainty belongs to an earlier boot | integrity/status lookup may project read-only evidence only; preserve old-boot state and await separately confirmed independent admission, with no close/reconcile/arm/call mutation |
| claimed and live | join/continue the same physical invocation only |
| claimed and owner/process/completion unknown | query/reconcile/seal; never create another call permit or restore a checkpoint into a new process |
| normal local K3 terminal-seal row committed but its receipt Artifact put/reply was lost | reconstruct the exact normal `S` from the historical row; no Provider call and no owner-loss failed seal |
| local proposal/result Artifacts exist without a committed K3 terminal-seal row | treat them as unreachable orphans; they cannot compete with the event-head CAS or authorize completion |
| same-boot claimed `.inProcessCertified` invocation has no committed terminal seal, and its signed containment proof says owner loss implies physical quiescence with no K4/external/visibility boundary possible | use only the private K3 owner-loss predicate to seal existing terminal `failed` with nil proposal/result and nil/nil public arm/observation evidence, then strict inherited-budget rebase; never create an attestation or generalize this to AFM/isolated/system-managed execution |
| device reboot after claimed local invocation, or AFM/isolated/system-managed owner loss without exact terminal/quiescence/query proof | quarantine or supported same-operation reconciliation only; no local cross-boot seal, checkpoint resurrection, or successor Provider allocation |
| remote egress pending, K4 proves the anchor absent, and the same live owner proves no anchor request was ever issued | while owner/boot/Attempt/epochs remain current, issue only the unique first byte-identical anchor request; if stale in the same boot, close unused; after reboot preserve read-only and await independent admission; send zero bytes |
| K4 proves an anchor absent only after its submission/result/reply became uncertain | same boot: query-close/reconcile only; earlier boot: preserve read-only/await independent admission; never submit the anchor again |
| remote handoff crossed and reply/terminal event is missing | retain `sent_or_unknown`; query/reconcile that exact request when supported, never redispatch or publish partial bytes as terminal truth |
| Core AI stage partially mutated state | poison the whole lease; restore/rebuild from a certified checkpoint only inside that same demonstrably live `executeAtMostOnce` invocation, otherwise query/reconcile/seal without another physical call |
| response sink succeeded but reply was lost | publication-journal lookup/finalization only; K3/K4 do not re-arm or resend |
| publication/effect terminal record exists after reboot but its K3 close/activation is absent | quarantine/read-only incident projection; current K3 performs no cross-boot close/activation |
| Zone C is indeterminate | reconcile the same saga; never regenerate or redispatch the effect |
| rebase grant reserved but active-head CAS is absent | replay only the same request; close reservation only from a covered conflicting-head/winner proof, otherwise retain it non-consumable until original expiry |
| active-head rebase CAS won but K4 activation reply/status is missing or K4 integrity is quarantined | keep the successor non-runnable as `activationPending`; after exact ledger/floor recovery query or replay only the same activation request; never report denial, roll back, or issue another grant |
| K4 durably committed the reservation-bound activation denial fence | preserve terminal denial irreversibly; never activate that grant or roll the K3 head back |
| device reboot before rebase completes | invalidate the reservation/monotonic domain and forbid same-WorkUnit rebase; later work is a separately confirmed independent WorkUnit |
| policy/deletion/revocation epoch changes | block new use and adoption, close or quarantine the exact in-flight identity, and complete purge obligations without fallback |
| confirmation/user-presence expired or a visible prefix was interrupted | restore exact progress and await a new Input Event; never silently continue an irreversible or user-visible boundary |
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

A remote Provider likewise skips local weight conversion but not certification or release. A custom remote profile's exact endpoint/model/account/region/policy cohort must pass capability, tokenizer/accounting, task quality, schema/tool-proposal, latency/rate/cost, disclosure, retention/training/deletion, credential, cancellation, terminal-query, malformed-stream, lost-response, and durable-egress gates. A system-managed opaque profile instead proves every platform-visible field, explicit absence for every hidden one, task-scope ineligibility wherever a missing proof is mandatory, and the exact logical-service egress/privacy/quota/context/reasoning behavior it does expose; it never fabricates endpoint/account/region/price/query evidence. Remote support may be structurally complete while every remote profile remains disabled; local release does not require enabling a cloud model. Enabling one later is a separately sealed profile/Release-tree decision, not an app-wide switch.

### 10.4 Existing W0–W6 roadmap remains the only roadmap

This addendum does not create W7 or a parallel “Agent project.” Its work is placed into the existing convergence waves:

| Wave | Addendum responsibilities |
|---|---|
| W0 | freeze owners/writers and legacy bypasses; repair non-vacuous gates/CI; converge iOS 27 floors; perform and independently verify the K4 public-framework/entitlement/lifecycle/IPC/helper-private `WAL + FULL` platform spike; atomically merge this addendum into the seven controlled documents and map or reject every recovery lifecycle/floor authority |
| W1 | immutable model-neutral Agent, `BASContextCapsule`/continuity/rebase, sufficiency, human-fit, embedded context/operating envelope, local/system/remote Provider identity/reference, retrieval, memory, RSI, semantic-DAG, and NextQuestion value contracts only; no concrete `BASStateABI`, execution behavior, secret, network call, or production activation |
| W2 | one K3 `FULL` nucleus, canonical Workspace/task/Attempt roots and atomic active-head rebase, branch control, preference correction/consent/deletion generations, encrypted content owner, memory/erasure convergence, plus K3 corruption/source-root/revocation-fence monotonicity, quarantine, and cold-reopen closure; production model allocation still disabled and durable K4 remains W5 |
| W3 | snapshot/historical projections, SQL/exact/FTS/BM25/temporal/entity/dense retrieval, grounding, State Market, exact per-Provider context compiler, structured reasoning/sufficiency/adaptation fixtures; Provider paths remain shadow-only |
| W4 | external Core AI/AFM Provider packages, execution plans and certified operating envelopes, concrete `BASStateABI`/ProcessorABI, K1/K2/K3 handoff, and prefill/decode/cache mechanisms; the unique physical owner/claim/actuation seam and planned production R5→R6-context handoff become authoritative under existing owners, with the current incumbent MLX baseline as the only production caller if required; new Core AI/AFM candidates remain shadow/device-validation only—no authoritative semantic executor, canary, or Core AI model-release cutover |
| W5 | implement durable K4, isolated/remote Provider egress, credential-handle transport, Zone C, independent publication journal, effect/publication recovery, and erasure mechanisms; migrate the existing Chat Completions/SSE mechanism behind exact materialization/observation without enabling a remote profile; prove all paths with non-zero fixtures and fault injection while production publication remains disabled; retire only direct/synthetic effect paths whose replacement is already closed; K3 nucleus corruption recovery was already a W2 gate |
| W6 | integrate the authoritative semantic-DAG executor and complete replay manifest; activate the W5 publication path only after that manifest exists; for every profile proposed for production—Core AI, on-device `SystemLanguageModel`, PCC, or other remote—obtain its own equivalent E4, sealed canary/cohort evidence, E5, and separately sealed Release-tree/cohort join; retire only the corresponding legacy route, complete applicable device/endpoint certification, and optionally earn the local 40/30 claim. Structurally complete remote support may still have zero enabled profiles |

Offline conversion spikes may start earlier when they do not change production authority. Production wiring cannot cross the listed W4/W6 gates.

The K4 spike is a hard W0 predecessor. It must identify and prove the exact public framework, extension point, entitlement, lifecycle, generated protocol/IPC shape, signing/install behavior, and helper-private SQLite `synchronous=FULL` feasibility. If it fails, the architecture returns for review; release mode may not silently collapse K4 into an in-process substitute.

### 10.5 Baseline and branch semantics

The implementation base for a wave is the then-current, explicitly recorded candidate-tree commit after all predecessor-wave commits and receipts, not a branch name or worktree directory. At this document's implementation snapshot, `codex/qinao-w0` pointed to `43060b810` and the implementation-bearing `codex/qinao-w1` commit `9bc71c98f` was eleven commits ahead; this documentation commit does not redefine that implementation snapshot. In-flight staged or untracked changes are not a baseline and cannot enter certification evidence.

The existing controlled-document convergence plan was generated from the older `a82a7bb0…` addendum state and is stale for the decisions in this revision. It must not execute or merge controlled documents until, after user approval of this written specification, a new plan pins the exact approved specification commit/blob/digest, updates every generated-from range and review candidate, and mutation-tests that any subsequent specification-byte change invalidates the gate. A branch name, an earlier green receipt, or a historical non-empty candidate count cannot satisfy that pin.

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
- on-device AFM obeys the same proposal/adoption/Attempt boundary and any production `SystemLanguageModel` profile has independent E4/E5 plus a sealed OS/model/cohort Release join;
- optional remote support obeys the same proposal/adoption/Attempt boundary and remains default disabled; a custom API cannot send until its exact destination/model/account/disclosure/credential/egress/rate/quota/cost/session/retention/purge/query/recovery profile is sealed, while PCC cannot send until its system-managed opaque presence matrix, explicit Workspace acceptance, limited eligible scope, reasoning/context/quota contract, and own E4/E5/Release join are sealed; no profile may claim evidence for a platform-hidden field and no remote profile is required to be enabled;
- one visible ConversationWorkspace survives bounded Attempt rotation, suspension, process death, device reboot, and scene restoration while strict-quiescent inherited-budget rebase, same-Workspace historical review, independent context windows, isolation, recovery, cache, and eight-window stress pass;
- structured reasoning, seven-state information sufficiency, repeated-challenge handling, and RSI gates reject unsupported certainty and non-progress loops;
- human adaptation preserves explicit/inferred separation, correction, consent, anti-manipulation, minimum disclosure, and no behavior-only preference promotion;
- every exact local/system/remote Provider profile uses its own context and operating envelope, with anti-thrashing and no global context/comfort score or post-allocation mutation;
- StateLake, encrypted artifacts, projections, context compilation, and erasure close from cold replay;
- an interrupted command deterministically restores completed progress, continues only a provably live same invocation, reconciles a possibly crossed boundary, rebuilds only after terminal closure, awaits the user when authorization changed, or quarantines; it never depends on a serialized process/session stack;
- tools, publication, memory commit, and model outputs cannot bypass L10/L11/L13/L14 and K3/K4/Zone-C boundaries;
- each exact profile that reaches production earns immutable E4/E5 evidence and only that profile's exact E5 verdict plus separately sealed Release-tree/cohort join reaches cutover, with rollback/revocation evidence;
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
- serialize a Swift stack/continuation, Task, actor mailbox, one-use permit, credential, Provider session, or volatile model tail as a resumable “session”; UI/scene restoration may point to a Workspace only;
- use one global `maxContextTokens`, a caller-provided token limit, or an upstream model-card ceiling as device/API execution authority;
- truncate a hard constraint, conflict, correction, source span, output/verification reserve, or unresolved external-call state to make a Provider fit;
- treat a Provider transcript, AFM session, remote thread/response chain, prompt cache, or generated summary as ConversationWorkspace/K3 continuity truth;
- maintain two active Attempts during context rebase or transplant token/KV/SSM/sampler/proposal/call state across an Attempt or Provider boundary;
- activate a successor Attempt while any predecessor Provider/recovery/effect/visibility/publication boundary is nonterminal, or reset its budget/round/visited lineage during rebase;
- turn Granite, `NextQuestionProjection`, RSI, Input Normalizer, Silicon Capability Fabric, or Zone C into a new semantic layer or authority;
- create a ModelPromotionStore, AgentRegistry, ContextStore, MemoryLedger duplicate, RSIManager, AdaptiveManager, per-model autonomous controller, second State Market, or hidden/global scheduler inside K3;
- allow self-repair to alter authoritative facts or self-evolution to promote code/weights/policy;
- silently fall back from a selected Qwen Attempt to AFM/MLX/remote, from AFM to local/remote, or between remote Providers;
- treat remote API enablement as app-wide consent, treat Provider-default training/secondary-use terms as user consent, send data outside the exact Workspace/purpose/disclosure/region/account class, persist raw API keys/authorization headers, or let a returned tool call execute directly;
- describe PCC as an exact custom endpoint, guess any platform-hidden destination/account/region/model/query/purge/price field, or use an opaque profile for a task that requires that proof;
- follow any automatic redirect in a v1 host-controlled custom transport, including a same-origin redirect; claim PCC's platform-hidden redirect behavior is app-observed; or perform an implicit network credential refresh;
- automatically resend after a remote handoff, disconnect, timeout, malformed/truncated stream, EOF without terminal evidence, or lost response; those states are query/reconcile or explicit-new-Attempt only;
- let a remote server session/cache own memory continuity, or claim erasure when the Provider cannot prove its retained derivative/purge boundary;
- auto-resume a chargeable disclosure, publication, irreversible effect, expired confirmation, or interrupted visible response merely because the App relaunched;
- join historical state across Workspaces in v1 or widen a single-Workspace snapshot/visibility/erasure contract in place;
- infer a durable emotion, personality, protected trait, or preference from one or repeated unconfirmed behaviors, or optimize for engagement/dependency/compliance;
- let low power, thermal state, rate headers, price, model confidence, or local acceptance EMA directly change user tone, semantic truth, verification, disclosure, or Provider route;
- use thermal pressure to lower model quality identity;
- claim erasure while a content key/blob, projection, cache, Provider derivative, or reachable backup remains;
- globally deduplicate private content across visibility, key, authority, or erasure domains;
- treat a certification evidence grade as permission to mutate or select the deployed production tree;
- accept a gate that matched zero candidates, tests, fixtures, or source files;
- let a historical M candidate satisfy a current-wave E/A extension gate, or implement a downward cost refund without a governed K3/K4 credit protocol.

## Source Grounding and Companion Documents

Repository baselines and candidate normative companions used by this addendum are listed below. A path is not proof that its current worktree bytes are committed: committed baselines bind their exact commit/digest, while all in-flight edits remain candidates until reviewed, committed, and sealed by the controlled convergence gate.

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
- [Apple Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels)
- [Apple SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Apple PrivateCloudComputeLanguageModel](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel)
- [Apple Private Cloud Compute language model session](https://developer.apple.com/videos/play/wwdc2026/319/)
- [Apple LanguageModel protocol](https://developer.apple.com/documentation/foundationmodels/languagemodel)
- [Apple FoundationModels context-window management](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)
- [Apple TN3193: Managing the on-device foundation model context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
- [Apple SystemLanguageModel contextSize](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize)
- [Apple SystemLanguageModel tokenCount(for:)](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/tokencount%28for%3A%29)
- [Apple BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)
- [Apple Background Task expirationHandler](https://developer.apple.com/documentation/backgroundtasks/bgtask/expirationhandler)
- [Apple UI state restoration across launches](https://developer.apple.com/documentation/uikit/preserving-your-app-s-ui-across-launches)
- [Apple iOS and iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- [Qwen3.5-4B model card](https://huggingface.co/Qwen/Qwen3.5-4B)
- [MiniCPM5-1B model card](https://huggingface.co/openbmb/MiniCPM5-1B)
- [MiniCPM-V 4.6 model card](https://huggingface.co/openbmb/MiniCPM-V-4.6)
- [Granite Embedding 97M Multilingual R2 model card](https://huggingface.co/ibm-granite/granite-embedding-97m-multilingual-r2)

These sources inform architecture ceilings, conversion mechanisms, platform/API behavior, and capability hypotheses. A model card's advertised context length is not a local-device or remote-account operating limit. Only the exact repository-bound local device/cohort evidence or remote Provider/profile/egress evidence required above may promote production behavior.
