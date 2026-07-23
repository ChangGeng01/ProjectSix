# Qinao Convergence Correction and Clean Candidate Reconstruction Design

**Date:** 2026-07-23

**Status:** Design approved in conversation; written record pending user review. This document is non-authoritative. Controlled-document convergence, implementation, migration, platform proof, certification, and production cutover remain `REVISE`.

**Scope:** Minimal corrections required after three adversarial review cycles over the canonical `14 / 4 / 4 / 7` architecture, StateLake retrieval order, Provider egress, App Agent/Main/Sub boundaries, context and memory isolation, interruption recovery, NextQuestion, cautious Web search, learning/RSI, Apple-silicon execution, and the current dirty W0/W1 candidate tree.

**Repository base:** `codex/qinao-w1` at `20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0`. Before this document was written, the worktree contained 145 dirty paths, including 31 paths with worktree bytes differing from the candidate index and 6 untracked paths. Those bytes are evidence to inspect, not implementation or certification truth.

## 0. Normative Standing

This document specializes and corrects proposed target wording, but it does not directly amend:

1. `2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`;
2. `2026-07-17-k3-budget-provider-contract-addendum-design.md`;
3. `2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`;
4. `2026-07-22-qinao-model-independent-app-agent-self-design.md`;
5. `2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`;
6. the convergence master and five domain plans; or
7. `qinao-owner-ledger-v1.json`.

It is not an eighth controlled authority document, a new roadmap, a new architecture axis, or permission to create a production type. The Owner-Ledger-controlled set remains exactly seven documents: the 2026-07-14 architecture, the convergence master, and the five domain plans. The 2026-07-17, 2026-07-19, 2026-07-22, and 2026-07-23 designs are four governing addenda outside that seven-entry array. Every adopted correction must update the affected governing addenda, all affected members of the seven-document controlled set, and the Owner Ledger atomically; inclusion here does not reclassify an addendum or change the controlled-document cardinality.

`qinao-authority-corruption-recovery-v1.md` currently self-declares normative status while remaining outside the governed 7+4 document sets. Controlled convergence must demote it to a non-authoritative companion and fold every adopted requirement into the already governed owner/domain documents and their ledger rows; it cannot become a fifth governing addendum, eighth controlled document, or fifth recovery owner by implication. Until that atomic status/reference/digest change lands, the contradiction keeps recovery progression `REVISE` and no production path may rely on the standalone draft as implementation or completion authority.

This correction proposes exactly two new immutable value-contract families for controlled convergence: (1) `BASContentIntakeProfilePayload` plus `BASContentIntakeReceiptPayload` at the existing Adapter/Input-Normalizer-to-`semantics.layercell` ingress boundary, and (2) `BASAuthorizedInputEffectPredecessorPayload` for explicit normalized-user or deterministic-Host-policy effect causality as already required by the 2026-07-14 authority. Both use ordinary Artifact Mesh storage and existing owners; neither creates mutable state or a new owner. `ArchitectureClosureReport` is a generated, non-authoritative verification projection and is not a runtime contract, owner, ledger, or second source of truth.

The following cardinalities remain exact:

- fourteen Semantic LayerCores, L1-L14;
- four Physical Kernels, K1-K4;
- four bounded ControlRings, Omega Resource, Omega Grounding, Omega Deliberation, and Omega Effect/Evolution;
- seven orthogonal planes;
- the existing Owner Ledger owner/create/controlled-document counts unless an independently reviewed atomic amendment deliberately changes them.

No correction below creates another LayerCore, Kernel, ControlRing, plane, compiler, State Market, scheduler, EventLog, K3 WAL, K4 ledger, publication journal, Zone-C reducer, model registry, memory truth, release mouth, promotion mouth, or retry truth.

## 1. Decision Summary

Three adversarial cycles produced one converged decision:

> Preserve the existing authority spine, correct the order and meaning of its phases, freeze legacy paths that can contaminate identity or memory, reconstruct one clean candidate tree from the current work without reimplementing it, and resume W0-W6 only from non-vacuous evidence bound to that clean tree.

The system does not become safer or faster by adding more managers. It becomes safer and faster by:

- doing hard eligibility before touching state bytes;
- using progressive retrieval instead of indiscriminate fan-out;
- making grounding a proposal followed by deterministic validation;
- selecting a Provider/profile before exact context compilation;
- compiling once for that exact Provider/tokenizer/accounting contract;
- allowing at most one physical call per K3-allocated Provider branch / `BASProviderExecutionRef`;
- preserving one host-local V1 HeavyPhase while overlapping only admitted lightweight work;
- keeping personality presentation separate from cognition and initiative;
- recovering durable logical work rather than volatile stacks, transcripts, or KV;
- turning every learning signal into an inert candidate before adoption; and
- refusing to call a dirty or unindexed tree “verified.”

## 2. Fixed Invariants

### 2.1 Semantic and physical boundaries

1. LayerCores decide semantic facts, requirements, proposals, verification, risk, evolution, and authorization within their existing domains.
2. Kernels own physical mechanisms and receipts. A semantic LayerCore may consume K1 resource observations; it does not probe thermal or memory hardware itself.
3. ControlRings observe typed state and receipts, request bounded remand, and terminate under finite budgets. They do not own truth, storage, effects, release, scheduling, or promotion.
4. Planes are orthogonal views, not serial stages or additional owners.
5. The minimum deployment target is iOS 27. No package, generated project, build script, XCFramework slice, test host, or release artifact may silently retain an iOS 18/earlier floor or weaken the iOS 27 gate.

### 2.2 Single-writer truth

- Artifact Mesh owns immutable content identity, ordinary put, reopen, and CAS storage.
- K3 owns the sole authoritative control nucleus: EventLog, Attempt/head, budget use, Provider branch rows, outbox, invisible state staging, active state, boundary rows, projector watermarks, tombstones, and deletion epochs.
- K4 owns capability issue/use, claims, anchors, and governed attestations.
- Zone C owns external-effect dispatch, acknowledgement, indeterminate, and reconciliation state.
- The publication journal owns publication reservation and finalization.
- StateLake stores and indexes are rebuildable projections, not a second state truth.
- K3 owns the sole semantic-snapshot currentness attachment/head. Semantic snapshots are immutable ordinary-put Artifacts with `headUpdate: nil`; Artifact Mesh heads do not become semantic currentness. Existing Artifact-head purposes `.attemptRoot` and `.semanticSnapshot` are retired from production currentness or retained only as explicitly non-authoritative compatibility projections with zero write/read authority.
- The publication domain and `BASResponseReleaseCoordinator` own once-only sink handoff, reconciliation decisions, and the sole public `finalizedPublicationRecord(for:)` query/reconcile API. `BASPublicationJournalSQLiteStorage` owns only reservation/finalization/indeterminate rows and its coordinator-private lookup implementation; it does not own a public view or handoff decision.

### 2.3 Provider and Agent limits

- Every model is outside Qinao SDK behind value-only Provider/Proposal contracts.
- A stronger API model may receive a different eligible context and execution profile; it never receives greater semantic or effect authority.
- One application container may hold multiple App Agent roots. Their Self, relationship, and private-memory lineages remain isolated; user-owned shared data crosses roots only through an exact, purpose-limited, read-only release that the recipient cannot mutate, delete, or re-share.
- One Session selects exactly one App Agent root and one logical Main identity.
- Provider replacement creates a new execution generation/Attempt but does not replace the selected App Agent or logical Main.
- Qwen, AFM, and any future local or API model are Main cognition Provider candidates, not Main identities. Switching among them creates a successor Attempt under the same logical Main unless the Session itself is explicitly replaced.
- Sub Agents receive independent, minimum-necessary capsules and return typed proposals. They cannot call one another, publish directly, or write App Agent state.
- Each K3-allocated typed-purpose Provider branch / `BASProviderExecutionRef` invokes at most one physical Provider once. One Attempt may contain only its policy-bounded causal sequence of grounding, specialist/tool-continuation, terminal-answer, and verifier branches; a route candidate is not an invocation permission.
- An App Agent is an engineering identity made from governed Self, values, commitments, relationship continuity, expression, and initiative limits. It is not a model, prompt, transcript, KV cache, persona skin, or claim of unverifiable consciousness, sentience, or private feelings.

### 2.4 Recovery and learning limits

- Unknown external state is query/reconcile-only and is never blindly replayed.
- A durable checkpoint restores task graph, receipts, committed heads, unresolved obligations, and currentness. It does not serialize a Swift stack, actor mailbox, Provider session, raw transcript, hidden reasoning, mutable KV, or one-shot permit.
- Model output, retrieved text, repetition, consensus, reward, or apparent fluency cannot self-promote into memory, Self, policy, authority, or training truth.
- Self-repair may rebuild projections, indexes, caches, and immutable derived artifacts. Self-evolution remains proposal-only until independently evaluated and adopted through the existing owner path.

### 2.5 Closure without hidden authority

Every owner has exactly one closed recovery profile, recorded in its existing Owner Card and the derived closure report. The profile is a closed product, because a publication/effect owner may have both durable authoritative rows and a possibly-started external boundary:

```text
stateFacet = stateless | ephemeralDrop | rebuildableProjection | durableStore
boundaryFacet = none | externalEffect
```

- State facet `stateless` proves the owner is a pure schema/value/compiler/validator authority with no mutable state, projection head, durable bytes, recovery sidecar, or possible-start execution responsibility. It normally pairs with `none`; a reachable external boundary means the responsibility mapping is wrong rather than permission to hide an effect in a pure owner.
- State facet `ephemeralDrop` carries no recovery sidecar, WAL, key, floor, lease, or quarantine store. Process/owner loss invalidates the state and requires fresh admission from owner-proved durable inputs.
- State facet `rebuildableProjection` carries only exact source owner/head/watermark, schema, and deterministic rebuild/currentness rules. It cannot claim an independent anti-rollback floor or truth.
- State facet `durableStore` names its owner-private schema, atomicity, durability, protection, key custody, external monotonic anchor/floor, lease, DB/WAL/SHM quarantine, reopen, corruption, and recovery protocol. The anchor's physical location, writer, atomic update order, and loss behavior are explicit and independent of the damaged bytes; absent a real anchor, rollback protection remains unsupported rather than inferred from a signature.
- Boundary facet `externalEffect` is mandatory whenever that owner can cross a Provider, network, tool, publication sink, disclosure, trainer, deployment, or other possible-start boundary. It carries idempotency identity, possible-start boundary, authenticated query/reconcile protocol, and unknown-state disposition; it never blindly replays. `none` is legal only when production reachability proves no such boundary.

These are presence rules, not new runtime types or owners. Pure `state.context-compiler`/`state.snapshot-contracts` responsibilities are `stateless + none`; Artifact Mesh is `durableStore + none`; Zone C and publication are `durableStore + externalEffect`; process-local admission/cache owners may be `ephemeralDrop + none`. K3, K4, Zone C, publication, and every other durable owner retain disjoint owner-private facts.
- Production reachability is part of authority. A type, fixture, test, or document is not an implementation when every production entry point bypasses it, and a legacy writer is not retired while any shipping composition can construct or call it.
- A generated `ArchitectureClosureReport` must make omissions visible, but it cannot bless them. Its inputs are the Owner Ledger, controlled-document digests, an exact production-entrypoint/reachability manifest independently derived from the complete frozen build graph, test manifests, and release evidence; changing the report without changing those inputs changes no authority.

## 3. Canonical End-to-End Flow

The following is the one normative target composition. Title-case labels are phases inside existing owners, not permission to create same-named runtime objects.

```text
Input Event
→ Adapter / Input Normalizer
→ select and equality-reopen exactly one input-bearing Section 6.4 AdmissionSubjectCurrentness variant
  (`idleWorkspaceProjection` has no Input Event and is excluded here):
     activeSession: AppAgentSessionSelectionEvidence + ContextWorkspaceRef
       + selected AppAgentAuthorityScopeRef/root + sessionMainAgentID
       + exact WorkUnit Main binding under currentAuthorityHeads
     OR preRootSetupPreview: exact creation Input Event + authorized Host profile + Workspace incarnation
       + normalizedProposalDigest + setup WorkUnit/Attempt/generation + Host policy/consent/deletion vector
     OR existingRootStudioPreview: exact App-Agent scope/root/currentness + authorized Host profile
       + Workspace incarnation + expression head + normalizedProposalDigest
       + Studio WorkUnit/Attempt/generation + Host policy/consent/deletion vector
→ L14 admission preflight
→ ordinary-put self-ID-free BASBudgetLeasePayload
→ ordinary-put immutable TurnOperation payload containing only its frozen admission-time wire:
     workspace/incarnation IDs + AttemptRef + generation vector + inputArtifactID
     + exact budgetLeaseArtifactID + ordered already-selected model/profile lineage when already fixed,
       otherwise the canonical empty list
     + policy/deletion/restoration/runtime-schema epochs
→ transient reference composition equality-joins that payload ref with the exact selected
     AdmissionSubjectCurrentness variant; variant-only fields are neither fabricated nor copied into
     or owned by BASTurnOperationPayload
→ same K3 transaction: reopen the lease, install TurnOperationRef + active Attempt head
     + initial BudgetLease row with zero cumulative use
→ freeze and ordinary-put/reopen WorkspaceReadSnapshot + currentness vector
→ K3 one-time absent→exact CAS attaches semanticSnapshotArtifactID to the TurnOperation head;
     a different existing attachment fails closed
→ ordinary-put/reopen the WorkUnit-admission attemptFrame over that exact snapshot/currentness evidence
→ L1 consumes K1 resource receipts and decides resource/life policy
→ L5 constitution + exact confirmed preferences
→ L6 situation classification + risk hints
→ minimum HumanFitProjection with explicit epistemic status and no durable inference promotion
→ L4 versioned prior + L7 StateRequirementPlan + EligibilityPredicate
→ R0 compile/freeze the physically eligible partition and lane watermarks
→ L8 lowers the exact L7 requirement/eligibility contract into one immutable,
     ordinary-put/reopened LaneQuery per opened lane, bound to the sealed snapshot/watermark/currentness
→ R1 mandatory SQL/metadata + exact/authorized grep + FTS5/BM25
→ conditional R2 temporal/episode
→ conditional R3 entity/relation
→ conditional R4 dense semantic:
     K1 phase reserve → K2 exact embedding mechanism → usage receipt
→ L8 accepts only immutable, ordinary-put/reopened LaneResult values bound to the same
     WorkspaceReadSnapshot, lane query/watermark, scope, purpose, authority, policy,
     deletion, restoration, and currentness vector; late or mismatched results are inert
→ when any Provider branch will be used: host/provider capability admission
     + attach the one frozen Provider branch policy and BASSiliconExecutionBinding
       (selected release-kind profile when Provider generation is planned,
        plus admitted grounding/verifier profiles)
       to the TurnOperation head
→ R5 lane-local dedupe + source/correlation caps + bounded Rust RRF
     + coverage-preserving reservoir
→ when small-model grounding is required:
     materialize/ordinary-put/reopen exact grounding BASExecutionPlan PlanG
       over semantic snapshot + requirement plan + bounded reservoir/proposal inputs
     → complete value-only route preflight and select one exact Provider descriptor
     → ordinary-put/reopen BASPersistedOrganDescriptorPayload PDG for that selected descriptor
     → profile-specific K1 reserve (Section 10.1) → committed K3 budget use
     → K3 allocates one typed .groundingProposal/.internalProposal branch bound to PlanG + PDG
     → reconstruct/ordinary-put/reopen allocation receipt A
     → compile/ordinary-put/reopen the purpose-minimal providerStep ContextCapsule
          from reopened A + PlanG + exact R5 inputs
     → exact request materializer reopens A/PlanG/PDG, separately validates the capsule
          as derivation input, and ordinary-puts/reopens M with exact parents [A, PlanG, PDG]
     → `.inProcessCertified`: fresh K3 claim Q → K2 consumes Q and executes once
       OR `.isolatedExtension` / `.remote`: after equality-reopening A/M, continue Section 5
          through Q + arm handoff + one physical transport execution,
          without reallocating or rematerializing
     → complete Section 5.1
     → only a completed A/C/S/P/R lineage (+ O/At for isolated/remote) exposes grounding to R6;
       other terminal outcomes contribute typed absence/coverage deficit, never proposal bytes
→ exact deterministic solvers/validators may contribute immutable internal evidence
→ R6 deterministic grounding validation
     + full hard-eligibility/currentness revalidation
     + conflict resolution
     + final State Market and CoverageVector
→ BASInformationSufficiencyPayload preflight
     + at most one bounded preterminal evidence/candidate remand re-enters L7 under the same currentness/budget fence
→ closed execution-source/release-kind branch:
     `activeSession + providerBacked + finalPublication`:
       revalidate the frozen selected primary Provider/profile/capability binding
       → L2 exact neural/Provider requirement + eligible answer plan template/CertifiedOperatingEnvelope
       → L3 bounded context candidate
       → accounting mode:
            deterministicTokenSpans: exact certified tokenizer runs once
            OR opaqueRuntimeExactCount: local/system counting API
               → BASContextAccountingReceipt → L3 equality reopen; no token IDs/boundaries
            OR certifiedConservativeUpperBound: local certified bound; no token IDs/boundaries
       → sole BASContextCompiler.compileExact finalization
       → ordinary-put/reopen immutable BASCompiledContextDescriptor D
       → ordinary-put/reopen exact answer BASExecutionPlan PlanM bound to D
       → complete value-only route preflight and ordinary-put/reopen selected
            BASPersistedOrganDescriptorPayload PDM
       → profile-specific K1 reserve (Section 10.1) → committed K3 budget use
       → K3 allocates exactly one `.turnStep/.terminalAnswerCandidate`, answerOnly branch
       → K3 allocation binds PlanM + PDM; reconstruct/ordinary-put/reopen allocation receipt A
       → compile/ordinary-put/reopen answer-purpose providerStep ContextCapsule from A + D + PlanM
       → exact request materializer reopens A/PlanM/PDM, separately validates the capsule,
            and ordinary-puts/reopens M with exact parents [A, PlanM, PDM]
       → K3 pre-claim CAS pins that branch as the sole Provider terminal-answer source
       → reconstruct/ordinary-put/reopen terminal source T from that exact pin
       → `.inProcessCertified`: fresh K3 claim Q → K2 consumes Q and executes once
         OR `.isolatedExtension` / `.remote`: equality-reopen A/M/T and continue Section 5
            from L11/L14 disclosure authorization through physical execution,
            without reallocating, rematerializing, or repinning
       → complete Section 5.1
       → only completed A/C/S/P/R lineage (+ O/At for isolated/remote) may continue
       → target verification → L9 candidate selection
       → equality-confirm the already pinned Provider terminal-answer source
       → Section 4.1
     `(preRootSetupPreview | existingRootStudioPreview) + deterministicInternal + nonAnswerMiniRelease`:
       prove the exact controlled fixed/deterministic preview source + Required Semantic Baseline
       → L9 mini-candidate → complete buffered L12/L10/exact-L11/L14 mini-release
       → never construct Provider branch/T/Vrow/V/Y/preparation/final-publication permit
     preview + providerBacked + nonAnswerMiniRelease:
       fail closed with zero allocation until the separate policy/binding/source-wire amendment is adopted
     internalOnly:
       retain immutable internal evidence with zero visible release
```

Before a model-originated tool or external effect can enter Section 4.2, its proposal must come from one bounded, pre-terminal-pin `.turnStep/.internalProposal` branch under the same TurnOperation, snapshot, branch policy, execution binding, budget, and currentness fence. It follows the same `Plan → selected persisted descriptor → K1 reserve/K3 use → A → purpose-minimal capsule → M → claim/one physical call → A/C/S/P/R` lineage as every other Provider proposal. Its exact existing `BASEffectCausalPredecessorPayload` retains the model/compensation contract:

```text
.providerProposal(exact completed internalProposal branch + R)
| .priorTerminalEffectReceipt(exact prior governed effect receipt)
```

A tool/search effect directly requested by normalized user input or triggered by an already-authorized deterministic Host policy must not invoke a model merely to restate that cause and must not overload the model-proposal payload. It ordinary-puts/reopens the separate governed `BASAuthorizedInputEffectPredecessorPayload` required by the 2026-07-14 authority. Its value contains exactly `{schemaVersion, turnOperationRef, effectRequestArtifactID, trigger, effectIntentPlanArtifactID, effectIntentPlanDigest, admissionSubjectRef, contextWorkspaceRef, appAgentRootRef, sessionIncarnationID, snapshotRef, currentnessVector, budgetUseReceiptID, policyEpoch, deletionEpoch}` where `trigger` is exactly `.normalizedUserInput(InputEventID, canonicalNormalizedInputDigest) | .deterministicHostPolicy(policyID, policyVersion, triggerEventID, triggerDigest)`. The deterministic L9 plan freezes one effect kind, purpose-minimal destination/query/request, disclosure projection, budget/idempotency class, and expected reconciliation semantics; it contains no effect branch, ordinal, boundary-instance, or predicted K3 allocation.

`BASStatePreparePayload` and `BASStateEffectOutboxPayload` move to one catalogued vNext whose nested `effectSourceRef` is exactly `.modelOrCompensation(contractID, version, BASEffectCausalPredecessorArtifactID) | .authorizedInput(contractID, version, BASAuthorizedInputEffectPredecessorArtifactID)`. That reference is not a standalone payload family. L13 may place one non-authoritative candidate `TurnBranchRef.effect[n]` and its canonical instance-zero projection in those two self-ID-free values only so the caller can ordinary-put/reopen both Artifacts before K3, as the Sovereign authority requires; neither the source payload nor L9 contains them.

In one K3 nucleus transaction, `prepareAndEnqueue` reopens and byte-checks the already-durable prepare/outbox Artifacts and named source, validates root/request/currentness/budget, deduplicates the same source/request identity, recomputes the sole next monotonic non-reused effect ordinal and canonical boundary instance from K3 state, accepts the candidate only when it equals that recomputation and expected head, and atomically installs the exact prepare/outbox Artifact IDs plus `{effectSourceRef, effectBranchRef, effectBoundaryInstanceID}`. A mismatched optimistic candidate returns a typed no-write conflict; its orphan Artifacts are harmless and the caller may rematerialize against the new head. A lost-reply same-artifact replay returns the byte-identical installed row; two concurrent distinct intents may initially carry the same candidate, but only one wins and the loser cannot create a gap, reuse, or second counter. K3 authors no non-K3 Artifact and there is no row referring to an Artifact that was not already reopened. Zone C still receives only outbox/request IDs after the prepared row exists and never copies either causal payload. The v1 model-originated path remains decodable and migrates byte-identically to the first variant; no v1 row may be reinterpreted as user/Host origin.

Every model-proposed effect uses `.providerProposal`. The authorized-input payload is value-only and Provider-free; L10/L11 independently verify the exact input/policy cause and may deny or require confirmation. It grants no direct dispatch, state, publication, memory, or follow-on authority and still traverses the complete L13/K3/L14/K4/Zone-C path below. After a durable effect result, any further reasoning uses a fresh policy-authorized `.turnStep/.internalProposal` branch whose capsule binds that exact receipt; if it proposes another effect, that new effect again uses `.providerProposal` bound to the fresh completed proposal. A later direct deterministic effect requires a fresh current `BASAuthorizedInputEffectPredecessorPayload`; an old user/Host trigger cannot authorize a resend. `.priorTerminalEffectReceipt` is reserved for separately authorized compensation: it reopens the same-root lower terminal effect receipt plus the current compensation attestation, rejects cycles across both causal payload families and every nested source variant, performs zero Provider-proposal lookup, and lets K3 alone allocate the fresh higher effect ordinal before the existing Omega Effect/Evolution and Zone-C saga proceeds. No path appends a receipt to an old transcript, resumes an old branch, hides a resend as compensation, or creates a tool/effect owner.

The snapshot, branch policy, execution binding, compiled-context descriptor, every Provider branch/permit/receipt, terminal prefix, presentation envelope, effect/state intent, and release evidence equality-bind the same selected admission-subject/currentness variant plus applicable execution-source/release-kind extensions. A guest/unknown Recognition result does not replace App-Agent selection evidence or create an anonymous active-Session bypass.

A purely deterministic, non-visible WorkUnit with no Provider grounder skips Provider capability admission and the execution binding entirely. If the controlled binding does not already encode an optional primary profile, a grounder-only/zero-main combination remains disabled; this document does not invent that wire variant. Every user-visible V1 answer freezes one selected primary profile in the unique root binding before any Provider branch executes.

`systemManaged` is a Provider-profile variant, not a containment class. Its descriptor independently binds exactly one controlled containment class: `.inProcessCertified`, `.isolatedExtension`, or `.remote`. On-device AFM and a system-managed remote/PCC profile therefore do not share a route merely because both are system managed.

The controlled wire retains `.isolatedExtension` for compatibility and future proof, so Sections 3-5 still define its complete fence and terminal evidence. Under V1, Section 10.1 makes Provider/model execution on that containment class production-unreachable: every eligible V1 Provider branch is `.inProcessCertified` or `.remote`, while the Enhanced Security extension remains a narrow K4/security mechanism rather than a Provider. Dormant wire completeness is not execution authorization.

### 3.1 Admission precedes retrieval

The architecture must not interpret the earlier shorthand as:

```text
retrieve broadly → inspect private candidates → decide eligibility
```

R0 must compile workspace, App-Agent scope, compartment, Attempt, purpose, authority, sensitivity, consent, policy, deletion, restoration, and currentness predicates into the physical query or authorized materialization before SQL rows, FTS postings, vectors, graph edges, caches, or Provider bytes are touched.

An empty eligible partition is a valid zero-result. It is not permission to widen scope.

### 3.2 Progressive retrieval is coverage-driven

- R1 is mandatory whenever state is required.
- R2 and R3 open only when the requirement plan needs temporal or relation structure.
- R4 opens only for an explicit semantic requirement, unresolved ambiguity, or measured coverage deficit.
- Required lanes cannot be skipped to save latency.
- Optional lanes open only when a versioned marginal-value bound exceeds their token, latency, memory, energy, and privacy cost.
- Independent eligible lanes may overlap, but none may outrun R0 or publish before R6.

“grep” means an in-process bounded literal/regex scan over already authorized bytes. It does not mean spawning a shell on iOS.

### 3.3 Grounding and State Market

The small grounding model is a proposal producer. It may suggest entailment, contradiction, spans, reranking, or coverage. It cannot change eligibility, authority, deletion state, truth, or memory status. L8 owns snapshot-bound lane-query/result candidate production; L7 owns requirements and the global eligibility predicate, while R0-R6 are ordered phases inside those existing owners rather than replacement LayerCores.

State selection is hierarchical, not one seductive weighted score:

1. hard eligibility, deletion, consent, currentness, and minimum-authority gates;
2. preservation of mandatory requirements, conflicts, corrections, and contradictory evidence;
3. grounding validation and source independence;
4. Pareto comparison over relevance, freshness, utility, diversity, token cost, latency, memory, and energy;
5. deterministic stable tie-break and an auditable selection receipt.

Authority is never traded away for relevance, freshness, or lower token cost. The only final State Market occurs after grounding validation and full R6 revalidation. R5 may compute non-authoritative candidate utility to bound work, but it is not another State Market.

### 3.4 Context and model ordering

Provider/model/profile admission precedes exact context compilation because local Qwen, system AFM, and remote APIs have different tokenizers, context accounting, geometry, disclosure, cache, cost, and recovery contracts.

The governing App-Agent addendum and Owner-Ledger-controlled publication wire currently conflict: the former permits zero-Provider deterministic terminal-answer completion, while K3's sole terminal-source pin and `BASPublicationBoundaryPermit` root every visible answer in a Provider-egress branch plus Provider-specific source, visibility, through-visibility, manifest, permit, and replay evidence. This convergence takes the minimal safe V1: K3 remains the only terminal-source CAS/pin owner; the publication owner consumes that immutable evidence and never selects a source; and a zero-Provider deterministic terminal-answer result remains internal evidence or a non-visible internal outcome. A user-visible answer continues to require the already controlled pinned Provider terminal branch. This does not fabricate a model Attempt for internal work and does not create a second source authority.

A future visible deterministic terminal-answer/final-publication source is not authorized here. It would require a separate atomic controlled amendment covering K3's discriminated source state/currentness and every Provider-specific source-receipt, visibility, branch-chain, manifest, permit, replay, migration, fixture, injection, and crash field—not merely renaming `terminalAnswerSourceProviderEgressBranchRef` or adding an Artifact alternative. This restriction does not prohibit the separately controlled `nonAnswerMiniRelease` used by deterministic Studio/NextQuestion projections.

The sole `BASContextCompiler` must:

1. reserve output, verification, and required continuation space first;
2. retain constitutional constraints, unresolved hard requirements, corrections, conflicts, and current effect state;
3. include the minimum App Agent Self/expression/relationship projection authorized for that Provider;
4. include exact task graph and current working state;
5. include selected evidence with span/provenance/coverage;
6. add optional history and examples last;
7. emit dropped/omitted coverage explicitly; and
8. produce a Provider-specific immutable descriptor/capsule and cache fingerprint.

There is no global `maxContextTokens`, truncation ratio, or character-to-token authority. Deterministic-token-span profiles tokenize exactly once. An `opaqueRuntimeExactCount` profile reopens only a local/system counting receipt, and a `certifiedConservativeUpperBound` profile carries only its certified bound; both expose byte/section spans and never fabricate token IDs or boundaries. A remote/PCC/custom endpoint receives no content merely to count before Section 5 egress authorization: it must use a certified local tokenizer when available or the conservative-bound mode. Core AI, AFM, and API profiles retain their own certified geometry, accounting, and reserve contracts.

### 3.5 Prefill and decode

“Prefill Router” and “Decode Router” remain logical phase labels under the selected execution plan. They do not become independent owners.

The selected plan may choose only pre-certified nodes:

- full prefill;
- exact suffix continuation;
- exact prefix-cache reuse;
- canonical context rebuild;
- plain target decode;
- prompt lookup with target verification;
- native MTP with target verification; or
- deterministic collapse to the same target/branch when speculative scratch becomes ineligible.

Changing Provider, model material, tokenizer, template, StateABI, App Agent scope, Workspace, Attempt, policy, deletion epoch, restoration epoch, or disclosure profile requires a cache miss and a new compilation. Mutable KV or Provider sessions never cross those boundaries.

## 4. Terminal Paths Are Not One Generic Commit Gate

### 4.1 Final response

```text
L9-selected immutable candidate C0 from the already K3-pinned, terminal-sealed Section 3/5 source
→ prove bufferedUntilVerified mode and zero visible source bytes
→ build/reopen terminal-prefix X
→ L12 non-visible exact ResponseSpool Sp0 + PresentationContract
     + semantic-conservation manifest + immutable PresentationReleaseEnvelope Env0/digest
→ execute the complete preauthorized verifier suffix
     + each .verifierProposal/.internalProposal branch performs exact plan
       → materialize/ordinary-put/reopen exact verifier BASExecutionPlan PlanV
          over the pinned terminal source + authorized verifier prerequisites
       → complete value-only route preflight and ordinary-put/reopen selected
          BASPersistedOrganDescriptorPayload PDV
       → profile-specific K1 reserve (Section 10.1) → committed K3 use
       → K3 typed allocation bound to PlanV + PDV → reconstruct/ordinary-put/reopen A
       → compile/ordinary-put/reopen the verifier-purpose providerStep ContextCapsule
          from A + PlanV + exact candidate/verifier context
       → exact request materializer reopens A/PlanV/PDV, separately validates the capsule,
          and ordinary-puts/reopens M with exact parents [A, PlanV, PDV]
       → `.inProcessCertified`: fresh K3 claim Q
         → K2 consumes Q and executes once
         OR `.isolatedExtension` / `.remote`: equality-reopen A/M and continue Section 5
            through Q + arm handoff + one physical execution, without reallocating or rematerializing
       → complete Section 5.1
       → completed branches contribute full A/C/S/P/R entries to K3-ordered post-pin history
       → failed/cancelled/indeterminate branches contribute only exact K3 terminal history
         and no entry/P/R
     + every allocated verifier ordinal must be terminal-resolved before L10;
       pending/unknown blocks; a failed required verifier makes C0 non-releasable rather than fabricating P/R
→ L10 exact-envelope/output verification of C0/Sp0
→ exact-pass branch only: ordinary-put/reopen exact-output-verification Artifact Everify0
     over Sp0 + exact verifier contract/constraint, with display coverage absent in buffered V1;
     validation reaches and equality-checks X transitively through Sp0, never as an Everify field/parent
→ L11 exact-envelope risk/privacy/confirmation/disclosure decision for C0/Sp0/Everify0
→ Information Sufficiency presentation candidate for that immutable semantic disposition
→ L14 exact release decision after reopening/equality-checking the L11 receipt
→ final Information Sufficiency outcome reopens C0/Sp0/Everify0 + exact L14 receipt
     + terminal branch heads/current epochs
→ closed release branch:
     exactRelease:
       L10 exact-verified + L11 exact-allow + L14 released
       + final outcome matches C0's already-frozen semantic disposition
       → select authorized envelope Env* = Env0 and exact-output-verification Everify* = Everify0
       → only readyVerified may be unqualified terminalComplete
     replacementRequired:
       any remand/redaction/confirmation/change to clarification/partial/abstain/denial,
       or any non-exact-allow/failed final check
       → permanently mark C0/Sp0/Env0/[Everify0 if present] nonpublishable
       → either stop with an exact zero-byte terminal marker where the contract permits
         OR separately admit a policy-authorized successor L9 candidate C1 with its own Sp1/Env1/Everify1:
            equality-reopen the same X only when the pinned source cut and all currentness remain exact;
            otherwise admit a successor Attempt/source and construct X1;
            then complete the full verifier/L10/L11/L14/final-sufficiency path
       → finalOutcome.denied must bind the exact L14 denial receipt;
         a visible denial uses only a separately authorized denial Env1, never Env0/Sp0
→ if and only if authorized Env* + Everify* exist:
     derive rootCompletedVerifierEntries as exactly every completed policy-authorized post-pin
       verifier ordinal before the one visibility-close head, including closed history from any
       abandoned same-root presentation candidate; all other allocated ordinals have exact
       failed/cancelled/indeterminate history and none remains pending
     → orderedVerifierR = rootCompletedVerifierEntries.map(R)
     K3 installs/reopens the exact buffered-visibility row Vrow bound to terminal-source T
       + source terminal seal S + orderedVerifierR + Everify*
     → reconstruct/ordinary-put/reopen visibility receipt V from Vrow
     → build/reopen through-visibility chain Y from exact policy ID + execution-binding ID
        + byte-identical terminal-prefix entries + T + Everify* + V + rootCompletedVerifierEntries;
        validator reopens X side-by-side but X is not a direct Y field/parent
→ ordinary-put/reopen the complete controlled self-ID-free BASExactReleasePreparationPayload:
     TurnOperation + pinned terminal-answer source branch + final-publication branch
     + terminal ProviderExecutionRef
     + T + V + X/Y chain IDs + Sp + Everify + exact L11 risk permit
     + exact release grant + destination
→ construct the one BASProviderReleaseEvidenceReference {X, Y, Sp, preparation}
→ ordinary-put/reopen complete pre-publication manifest carrying that exact four-ID reference;
     preparation contains no future manifest ID, boundary identity, idempotency key, or later receipt
→ K3 prepared row
→ publication-journal reserve
→ Artifact Mesh ordinary-put/reopen immutable BASPublicationBoundaryPermit
→ K3 validates the permit and advances prepared → publication_permit_pending
→ K4 claimAndAnchorBoundary internally ordinary-puts U + H before its CAS,
     atomically records exact BASCapabilityUseReceipt U + BASBoundaryAnchorReceipt H,
     and returns the ordinary BASArtifactStoreReceipt identifying H
→ caller takes receipt.body.artifactID, reopens H, then reopens/equality-checks the U ID named by H;
     caller ordinary-puts neither receipt again
→ K3 arm CAS → reconstruct/ordinary-put/reopen exact boundary-arm receipt
→ the sole CAS winner queries the exact sink identity with the derived idempotency key:
     matching BASExactReleaseSinkReceiptPayload exists
       → verify its exact root/branch/instance/permit/anchor/arm/envelope tuple; call count stays zero
     no matching receipt exists
       → call the sole Adapter/IO sink exactly once with the byte-identical authorized envelope
       → ordinary-put/reopen exact BASExactReleaseSinkReceiptPayload
     unqueryable/contradictory/unknown
       → no release/retry; publication remains indeterminate/query-reconcile-only
→ publication journal appends linked finalized-with-nonnull U/H/arm/sink evidence | indeterminate evidence
→ K3 closes/finalizes only its own boundary row from the exact sink receipt, or preserves its own
     indeterminate/query-reconcile state without reading the journal or accepting a generic observation
```

For the envelope that is actually released, its digest must equal its own L12-buffered, L10-verified, L11-exact-allowed, and L14-authorized envelope digests. The complete surface payload, subject/currentness, locked spans, accessibility, alternatives, cues, and interaction metadata are covered, with no post-authorization decoration or byte substitution. A replacement or denial envelope has a new presentation lineage and can never borrow the abandoned candidate's spool, Everify, Vrow/V, Y, or authorization. It may equality-reopen immutable source prefix X only when the exact pinned source cut and all currentness remain unchanged; changed evidence/source/Attempt requires a new X. At same-root closure, old completed verifier entries remain mandatory structural history in `rootCompletedVerifierEntries`, but they do not verify or authorize the replacement candidate; that candidate still satisfies its own complete verifier contract and L10/L11/L14 path.

Any L10 failure or any L11/L14/final-sufficiency result other than the exact release required by the already-frozen semantic disposition jumps directly to `replacementRequired`; the old envelope never continues linearly. Confirmation, redaction, clarification, partial, abstention, and denial are content decisions, not post-verification transformations.

After anchor uncertainty, arm issuance, or any possible sink crossing, recovery is query/reconcile/finalize-only. It never creates a sibling permit, re-arms, or blindly calls the sink again.

Only a durable `terminalComplete` response may drive answer-complete UI, post-answer NextQuestion, or answer-derived learning/memory candidates. Idle-workspace NextQuestion uses its separate non-answer mini-release in Section 7 and is not response-driven. V1 production visibility is exactly `bufferedUntilVerified`; every provisional/incremental Vrow, visibility receipt, stream permit, and visible batch remains unreachable migration evidence.

A future incremental protocol is a separate controlled amendment, not an alternate reading of this flow. Before any activation it must freeze an L9-selected semantic-answer graph reference/digest and batch policy before the surface-realization Provider call, run every bounded batch through complete L12/L10/L11/L14 `released` evidence, bind claim/qualifier-complete prefixes, preserve `partialAuthorizedPrefix | terminalComplete` disposition across crash/history/copy/share, and close all K3/K4/Adapter replay and currentness cases. This document does not authorize that topology.

### 4.2 Tool or external effect

```text
closed effectSourceRef:
     modelOrCompensation:
       reopen exact BASEffectCausalPredecessorPayload, whose inner source is exactly:
         modelOriginated:
           L9-selected tool proposal from a completed internalProposal lineage
           → .providerProposal
         OR separatelyAuthorizedCompensation:
           exact prior terminal effect receipt + current compensation authorization
           → .priorTerminalEffectReceipt; perform zero Provider lookup
     OR authorizedInputOrPolicy:
       L9 deterministically derives one exact EffectIntentPlan from the normalized
       Input Event or signed deterministic Host-policy trigger
       → reopen exact BASAuthorizedInputEffectPredecessorPayload
       → perform zero Provider lookup/invocation
→ L10 verification
→ L11 risk/confirmation/disclosure
→ L13 causal preparation and read set
→ K3 atomically validates source/request/currentness/budget, deduplicates replay,
   recomputes/accepts the sole next effect branch/ordinal/instance candidate,
   and installs the already ordinary-put prepare/outbox Artifact references
→ L14 exact authorization
→ K4 issue/reserve
→ K3 handoff
→ Zone C dispatch_pending
→ K4 claim/use
→ Zone C dispatch_ready
→ Artifact Mesh ordinary-put/reopen immutable BASEffectBoundaryPermit
→ K3 validates/binds it and advances handed_to_zone_c → effect_permit_pending
→ K4 anchor
→ K3 arm
→ Zone C atomically consumes the exact permit + anchor + arm once
→ dispatch_ready → dispatch_boundary_armed
→ only the Zone-C CAS winner calls the adapter once, or query/reconciles
→ ordinary-put/reopen exact governed terminal effect receipt
→ K3 closure bound to the predecessor, request, ordinal, permit, anchor, arm,
     adapter identity/idempotency key, observation, result, and disposition
```

A state change following the effect must then traverse the state-commit suffix below, and its `StateCommitIntent` binds that exact terminal effect receipt ID and outcome. Further model reasoning is a fresh policy-authorized `.turnStep/.internalProposal` branch whose purpose-minimal capsule binds the receipt; a later model-originated effect binds the fresh completed proposal, a later direct input/policy effect requires a fresh `BASAuthorizedInputEffectPredecessorPayload`, and compensation alone uses `.priorTerminalEffectReceipt` inside the model/compensation family. An unknown dispatch/result never creates a resend capability, successor branch, compensation authorization, or fabricated failure/success evidence.

### 4.3 Internal state candidate

```text
L9-selected internal state candidate
→ L10 exact validation
→ L11 risk/confirmation/disclosure revalidation
→ L13 StatePrepareIntent + exact read set
→ K3 prepareAndEnqueue: nonoptional prepared state + canonically present/absent outbox
→ when an effect is required: continue only the already-prepared same effect branch at the
     Section 4.2 post-prepare suffix beginning with L14 exact authorization;
     do not rerun L9-L13/prepare or replace its request/outbox/ordinal
     → execute/reconcile that exact suffix to a governed terminal receipt
→ L13 StateCommitIntent bound to the preparation + exact effect/no-effect disposition
→ K3 appendAndStage canonical event + invisible stage
     + freeze the complete mapped K4 request material: grant value/digest,
       issue/use/attestation stable request IDs, bound subject, purpose,
       policy/consent/deletion/key epochs, deadlines/recoveryNotAfter,
       and proof-free signed context; L14 can authorize only these exact bytes
→ L14 terminal authorization
→ K4 issue/reopen exact capability grant → reserve → claim/use
→ take returned ordinary BASArtifactStoreReceipt.body.artifactID
     → reopen/validate K4's sole stored BASCapabilityUseReceipt; caller does not put it again
→ K4 signer produces the generic attestation value bound to the staged commit + use receipt
→ caller ordinary-puts/reopens BASArtifactAttestationPayload
→ K3 reopens/binds the attestation + use receipt and seals the staged commit
→ K3 expected-parent/current-read-set activation CAS
→ rebuildable StateLake projection update
```

Known pure internal state may omit Zone C and carries an absent outbox, but it may not omit L10/L11, L13 prepare and commit intents, K3 prepare and stage, L14, K4 grant-reserve-claim/use, caller-owned attestation put, K3 seal, or K3 activation. K4 never writes or “terminal-seals” K3 state. A partial, cancelled, failed, or indeterminate target never activates success.

For Self/RSI/learning adoption, the immutable candidate/read set and required shadow/holdout evidence already exist before L10. Only the exact independently eligible outcome may enter this common runtime-state suffix; claimed-target attestation recovery reopens the same use/target identity and never signs or activates a substitute.

## 5. Provider Egress Permit Correction

The immutable permit payload and the mutable K3 boundary row are different objects with different owners.

The corrected order is:

```text
ordinary-put/reopen the exact branch BASExecutionPlan Plan
→ complete value-only route preflight; no Provider branch or materialized request exists yet
→ ordinary-put/reopen BASPersistedOrganDescriptorPayload PD for the selected Provider descriptor
→ profile-specific K1 reserve → committed K3 BASBudgetUseReceipt
→ K3 allocates the exact typed branch bound to Plan + PD + budget-use receipt
→ reconstruct/ordinary-put/reopen Provider allocation receipt A
→ compile/ordinary-put/reopen the allocation-bound purpose-minimal providerStep ContextCapsule
   from A + exact Plan + branch context
→ exact request materializer reopens A + Plan + PD, separately validates the
   purpose-minimal capsule as derivation input, and ordinary-puts/reopens M
   with exact ordered parents [A, Plan, PD]
→ answer branch only: K3 pre-claim CAS pins exactly this branch as the sole terminal-answer source
→ reconstruct/ordinary-put/reopen terminal source T from that exact pin
→ L11/L14 exact remote-disclosure authorization
→ remote only: the existing credential-slot store returns content-free,
   exact-version metadata for CredentialAuthorizationBinding without returning secret bytes
→ K4 one-shot use receipt exact-binds M + PD + that authorization binding
→ Artifact Mesh ordinary-put/reopen immutable ProviderEgressBoundaryPermit payload
   containing the same nested authorization binding, but no secret/header bytes
→ K3 transaction validates A/M/[T]/permit/use/currentness and installs pending row
→ K4 anchors the committed K3 source root
→ anchor receipt ordinary-put/reopen
→ K3 arms the exact pending row
→ reconstruct/ordinary-put/reopen exact boundary-arm receipt B
→ fresh K3 claim Q
→ beginProviderEgressHandoff consumes Q + B and marks sent_or_unknown
→ noncopyable remote-call permit uses K4/Q+B as the sole one-shot consumption truth,
   resolves the exact bound secret version once, injects only the authorized authentication bytes,
   and is consumed immediately by executeAtMostOnce
→ on successful bounded terminal result: complete Section 5.1
```

Artifact Mesh creates/reopens the immutable permit Artifact. K3 alone owns allocation/claim/seal and pending/armed/sent/terminal mutable rows; it does not materialize M. K4 alone owns the use/anchor facts. The transport owns no journal, retry map, or recovery truth. A Section 3 caller that already holds exact reopened A/M (and T for an answer branch) enters this sequence at L11/L14; it equality-reopens that prefix and never allocates, materializes, or pins it again.

The allocation-bound `providerStep` capsule is a mandatory, separately validated derivation input, but the frozen `BASMaterializedProviderRequestPayload` gains no capsule field or fourth parent: its value remains exactly execution ref + execution-plan ID + selected persisted-Provider-descriptor ID + request bytes, and its ordered outer parents remain exactly `[A, BASExecutionPlan, BASPersistedOrganDescriptorPayload]`. For a remote descriptor, `request bytes` means the exact canonical nonsecret request template only. PD freezes the actual destination, `credentialSlotID`, authentication scheme, and one closed injection point; raw secret and authorization-header bytes are excluded from M and every persisted digest.

The nested content-free `CredentialAuthorizationBinding` is an extension of the existing Provider-egress permit/use/anchor contract, not a new owner or standalone credential payload family. It contains exactly `{credentialSlotID, credentialPersistentRefDigest, credentialKeyVersionID, rotationEpoch, authenticationScheme, injectionPoint, nonsecretRequestDigest, actualDestination, resolverPolicyEpoch}`. L14 authorizes the slot/scheme/destination/template and currentness policy; after that authorization the existing credential-slot store performs a read-only metadata lookup of one current permitted version/persistent reference without reading or returning the secret. K4 use, the immutable permit, the pending/armed K3 row, anchor, arm, claim, and remote O/At all equality-bind the same fields. K4's existing one-shot capability/use plus Q+B claim/handoff remain the only mutable consumption truth; the credential store gains no lease, journal, retry bit, or authority. If no existing governed credential-slot owner can supply and re-resolve exact version metadata, the remote profile remains blocked rather than creating one here. Rotation, revocation, deletion, or policy-epoch change after binding denies pre-start execution and can never substitute a newer key into that branch.

Only after the exact boundary permit is anchored/armed/claimed and `beginProviderEgressHandoff` has consumed Q+B may the noncopyable transport resolve that exact persistent reference/version once, form the physical request, and make the one call. The physical view combines the exact M template with exactly the frozen authentication injection and nothing else. All non-authentication bytes and the actual destination remain byte-equal to M/PD; the transport may add no default header, query item, body transform, redirect destination, compression, or credential from another slot unless that transformation is already canonicalized in M/PD. The secret view is zeroized after call or pre-call denial and is never persisted, logged, echoed, returned, copied into O/At, or recoverable from the content-free binding. A crash before handoff may continue only inside the same K4/K3 operation with the same live permit and exact unrevoked version metadata. A resolution mismatch after handoff may produce only an authenticated known-not-started denial; a crash after resolution starts or during the atomic resolve/inject/call boundary but before authenticated O/At remains `sent_or_unknown`, is query/reconcile-only, and never resolves again to resend. Remote O/At bind the actual persistent-ref digest/version, scheme, injection point, nonsecret request digest, and destination without secret-derived bytes.

### 5.1 Canonical Provider completion suffix

Every containment class uses one completion suffix after its one physical invocation:

```text
successful bounded execution result
→ ordinary-put/reopen proposal P + terminal result
→ isolatedExtension/remote only: authenticated observation O + attestation At
→ reconstruct/ordinary-put/reopen claim receipt C from the exact K3 claim row/Q
→ K3 terminal event-head seal Srow:
     local completed binds proposal P with arm/observation exactly nil/nil
     isolatedExtension/remote completed exact-binds boundary-arm receipt B + O,
       and freezes K3-selected At + installed trust-manifest identity/snapshot
→ reconstruct/ordinary-put/reopen seal receipt S from Srow with those exact/transitive bindings
→ ordinary-put/reopen canonical BASProviderProposalReceipt R whose value/ordered parents bind exactly M/P/S
→ validator reconstructs/equality-checks A/C and forms complete A/C/S/P/R lineage
   (+ O/At when required)
```

`A/C/S/P/R` denotes allocation, claim, seal, proposal, and generic Provider-proposal receipt; A/C are reconstructed lineage members, not extra fields or parents copied into R. Non-completed outcomes have a closed suffix too:

- an observed current-owner local failed/cancelled/indeterminate, or the narrowly allowed same-boot owner-loss case with exact physical-quiescence proof, reconstructs C, terminal-seals Srow, and reconstructs S with proposal nil and arm/observation nil/nil;
- unobserved local owner/boot loss remains unsealed unresolved/quarantined with no recall until an exact separately allowed recovery proof exists;
- authenticated isolated/remote failed/cancelled/indeterminate first ordinary-puts/reopens the exact O/At pair with proposal nil, then reconstructs C, terminal-seals Srow with the exact B/O pair while freezing K3-selected At + installed trust-manifest identity/snapshot, and reconstructs S with those transitive bindings; and
- isolated/remote failed/cancelled/indeterminate without authenticated O/At, plus `sent_or_unknown`, remain unsealed query/reconcile-only.

Every non-completed branch creates no P or R and no lineage entry. A live, pending, unsealed, unknown, missing-receipt, or lineage-mismatched branch is not proposal evidence consumable by R6, L9, L10, or Information Sufficiency.

Section 5 never closes visibility. Under V1, buffered visibility can open only in Section 4.1 after terminal-prefix X, spool, the complete terminal-resolved verifier suffix, L10/L11, L14, and final Information Sufficiency evidence all agree. Incremental fields remain production-unreachable as described there.

Controlled convergence must revise older wording that says K3 “creates the permit” so it says K3 validates the immutable permit and installs its unique pending row.

## 6. App Agent, Persona, Memory, and Context Corrections

### 6.1 Legacy Persona disposition

Current production source accepts free `personaInstructions`, freezes them into MLX session state, and mixes presentation with cognitive axes. In `BASAgentPersonaSDK`, the LOW tier skips the post-composition resolved-Persona forbidden-pattern scan even though input-overlay scanning still runs. That mechanism is not the target App Agent Self or Companion Expression system.

Before App Agent cutover:

- non-empty free Persona injection is fail-closed in the shipping authoritative graph;
- legacy Persona remains test/lab/Studio compatibility only, or neutral presentation-only after an exact retirement proof;
- skepticism, challenge, creativity, routing, retrieval depth, verification, tool use, and risk behavior are removed from the expression tier;
- every visible style transform starts from a verified Required Semantic Baseline;
- code, shell, SQL, JSON, URLs, citations, quotes, numbers, units, dates, negation, uncertainty, warnings, refusals, authorizations, and tool payloads are locked spans;
- post-render equivalence failure returns the unstyled verified answer.

User-approved silly, shy, terse, playful, “嘿嘿”, emoji, or avatar cues affect only presentation. Character never means incompetence.

### 6.2 Initiative is not expression

Adaptive expression may control presentation cadence, sentence rhythm, density, sectioning, examples, and bounded ornaments. It cannot control whether the App Agent initiates work.

Every proactive inspection, draft, notification, network operation, spend, durable commitment, or external effect remains bounded by the approved-design product-level `InitiativeLease` projection once its mapped owner is activated, plus the normal authority path. It is not asserted as a current production declaration. “Initiative cadence” in the expression tier must be corrected to “presentation cadence.”

### 6.3 Query self-population is not governed memory

The existing L8 path can append a query frame to a future retrieval snapshot and label a durable form `.governed`. That path must be source-gated out of the production authoritative graph before StateLake/App Agent memory cutover.

At this snapshot, `BASL8RoutedMemoryService` itself defaults `selfPopulate` to false, but the standard `BASCognitiveBrain.resolveMemoryService` routed-memory construction passes true. Durable `.governed` admission additionally depends on persistence/admit and drain; the unsafe route is reachable even though not every query necessarily becomes durable.

Permitted interim disposition:

- disabled by default;
- test/lab only; or
- explicitly non-authoritative, session-local, disposable scratch with no durable admission, no authority label, no cross-Agent reuse, and no influence on Self or user profile.

Only a cleaned Experience observation may propose a memory candidate. Retrieval, repetition, embedding, model consensus, or repeated display cannot raise authority.

### 6.4 Session and Provider continuity

The current in-process session dictionary is a cache, not durable Session truth. Forwarding a raw `sessionID` into the existing MLX pool would create false continuity and may preserve stale Persona/KV under an insufficient identity.

The safe target is acyclic and composes three orthogonal closed axes:

```text
AdmissionSubjectCurrentness
= activeSession {
    AppAgentSessionSelectionEvidence + ContextWorkspaceRef
    + selected AppAgentRoot/AppAgentAuthorityScopeRef + logical sessionMainAgentID
    + WorkUnit + AttemptRef + execution generation
    + currentAuthorityHeads {Self, expression, relationship, policy, consent, deletion, restoration}
  }
| preRootSetupPreview {
    creationInputEventID + authorizedHostProfileRef + workspaceIncarnationID
    + normalizedProposalDigest + setup WorkUnit/AttemptRef/generation
    + current Host policy/consent/deletion vector
  }
| existingRootStudioPreview {
    AppAgentAuthorityScopeRef/root/currentness + authorizedHostProfileRef + workspaceIncarnationID
    + currentExpressionHead + normalizedProposalDigest + Studio WorkUnit/AttemptRef/generation
    + current Host policy/consent/deletion vector
  }
| idleWorkspaceProjection {
    AppAgentSessionSelectionEvidence + ContextWorkspaceRef
    + selected AppAgentRoot/AppAgentAuthorityScopeRef + logical sessionMainAgentID
    + current authority heads + Workspace snapshot/task-graph roots + exact qualifying source item
    + focus/current-view/empty-input state + source epochs + objective/schema version
    + recomputation time + expiry
    + WorkUnit/Attempt/generation tagged existing only when the source already has them, otherwise absent
  }

ExecutionSourceExtension
= providerBacked {TurnOperation root + Provider/profile/material identity + providerStep ContextCapsule + compiled-context descriptor where applicable}
| deterministicInternal {TurnOperation root present; Provider execution fields canonically absent}
| deterministicProjectionNoTurnOperation {
    no new TurnOperation/WorkUnit/Attempt/Provider; exact existing source refs tagged present/absent
  }

ReleaseKindExtension
= internalOnly
| finalPublication
| nonAnswerMiniRelease {exact mini-release subject + source variant required}
```

When present, the immutable TurnOperation root binds only its frozen admission-time facts and never predicts a later snapshot, Provider, binding, branch, or descriptor; `providerBacked` and `deterministicInternal` point one-way to it and the selected admission subject. `deterministicProjectionNoTurnOperation` proves the root and execution fields absent rather than fabricating them. Release kind does not itself decide execution source: a generated Studio preview may eventually use `providerBacked + nonAnswerMiniRelease` only after a separate atomic amendment freezes a legal ProviderBranchPolicy purpose/rule/role, execution binding, exact Provider-lineage mini-release source, migrations, fixtures, and reachability; until then that combination is disabled and Studio is limited to fixed/deterministic preview assets. NextQuestion is always `deterministicProjectionNoTurnOperation + nonAnswerMiniRelease`: it may reference an already released answer or authorized Workspace source, but never allocates a new Provider branch. Under V1, `finalPublication` requires `activeSession + providerBacked`; every preview subject is non-answer-only, and `internalOnly` proves no visible release.

Missing or mismatched required evidence in the selected subject variant is fail-closed; fields belonging only to another variant must be absent rather than fabricated. For `activeSession`, missing or mismatched selection evidence, Workspace, authority scope/root, logical Main, WorkUnit, Attempt, generation, or current authority head admits zero WorkUnits. In `.providerBacked`, Provider/profile/material/accounting/context mismatch requires authorized fresh compilation and, where identity changed, a successor Attempt; it never reuses the old capsule. Only missing Recognition/profile-relationship evidence lowers the separate assurance result to guest/unknown, and only an explicit L11 contract may request confirmation. None of these cases permits lookup by a caller-chosen string alone.

`activeSession` remains production-dark until one controlled slice makes the App-Agent root and Session selection executable rather than aspirational:

1. the normalized creation Input Event freezes `creationInputEventID`, candidate child scope, subject-nonce commitment, Host profile/Workspace, template/policy/quota class, and stable quota request; the incumbent K3 currentness owner wins one expected-absent `AppAgentCreationBinding` CAS keyed by `(applicationContainer, creationInputEventID)`;
2. only that winner may drive the same incumbent K3 quota row from `absent → reserved(...)`; deadline/clock/boot anchor and every release trigger are preexisting frozen inputs, and every terminal state is absorbing;
3. only after reservation may the immutable self-ID-free genesis payload, exact first Self/adoption inputs, and non-operative `preexistingRootActivationCandidate` be ordinary-put/reopened; none embeds or predicts its later K3 activation/currentness receipt. Before root activation, that exact candidate must complete L5 constitutional evaluation → L10 validation → L11 designated-principal/risk/disclosure confirmation → L13 intent and K3 invisible stage → L14 exact authorization → K4 issue/reserve/claim/use plus generic attestation → caller ordinary-put/reopen → K3 equality seal;
4. only the exact K3-sealed candidate from step 3 may enter one K3 `FULL` transaction that atomically commits root `absent → active(appAgentID, genesisArtifactID, initialSelfHead)` and reservation `reserved → consumed(preexistingRootActivationCandidate)`; authorized deletion atomically installs root/Session/share ineligibility and `consumed → releasedAfterDeletion` before asynchronous purge. Root reopen proves exact scope/incarnation, active heads, policy/consent/deletion/restoration epochs, and no fence;
5. Session construction creates `ContextWorkspaceRef` first, then wins one expected-absent `AppAgentSessionSelectionBinding` CAS keyed by `(applicationContainer, sessionCreationInputEventID)` over a fresh immutable `sessionIncarnationID`, selected active root/scope, profile/Workspace, and selection-time eligibility; `AppAgentSessionSelectionEvidence` reopens that winner, and only its digest may derive `sessionMainAgentID`;
6. there is no prior or successor Session-selection generation. Selecting another App Agent requires a new Session-creation Input Event, fresh `sessionIncarnationID`, new `ContextWorkspaceRef`, new logical Main, predecessor fencing, and—only when explicitly authorized—an ordinary read-only handoff release; no Self, private memory, transcript, KV, Provider session, tool handle, credential, or one-shot permit moves implicitly; and
7. every shipping constructor and endpoint is source/reachability-gated against caller-chosen `appAgentID`, `mainAgentID`, `sessionID`, or `personaID` strings that are not derived from reopened selection evidence.

If any incumbent owner, atomic boundary, binding, quota, seed, bootstrap principal, recovery rule, or Create/Extension classification cannot be proven without a new mutable owner, creation/selection remains blocked. Before all seven gates pass, production `activeSession` admits zero WorkUnits. Only the explicitly bounded `preRootSetupPreview`, deterministic `existingRootStudioPreview`, and guest/unknown modes described here may remain reachable; no preview can be relabeled as an active Session.

Interruption recovery preserves the existing `state.snapshot-contracts`-owned `ContextContinuityManifest`; it does not invent a second continuity vocabulary or owner. The manifest references the latest owner-proved committed cut, task graph and WorkUnit/Attempt dispositions, exact branch/effect/publication cursors, unresolved obligations, current authority heads and epochs, context/cache invalidation decisions, and the existing `WorkUnitRecoveryCursor` with its exact L11/L14-produced `ContinuationPolicy`: `automaticWhenSafe | foregroundOnly | confirmationAfterInterruption | neverAutomatic`. It does not store a second per-node resume union. After policy evaluation, the existing exhaustive receipt-presence matrix derives exactly one existing `RecoveryDisposition`: `restoreCompleted | resumeSameAttempt | reconcileSameOperation | rebuildAfterTerminal | awaitUser | quarantine`. The manifest copies no mutable counter, boundary state, retry bit, transcript, KV, actor mailbox, credential, raw stack, or one-shot permit. K3 validates referenced receipts/currentness but does not interpret or own continuity semantics. Recovery must prove both no duplicate boundary crossing and no lost owner-proved committed progress; MLX/AFM/API session state is only discardable mechanism cache.

### 6.5 Provider fallback

The legacy executor that iterates a list of Providers inside one call is incompatible with the target authoritative path.

Target behavior:

1. pre-allocation planning may rank a finite eligible Provider set and freeze a bounded branch policy/DAG, but ranking invokes nothing;
2. K3 binds one exact Provider/profile and typed purpose to each allocated branch / `BASProviderExecutionRef`;
3. `executeAtMostOnce` invokes that exact branch zero or one physical time;
4. rejection, unavailability, cancellation, or unknown outcome terminalizes or query/reconciles that branch; a possible prior call can never be wrapped as a replacement ordinal;
5. an Attempt may advance only to a preauthorized causal successor branch after the predecessor has the required known disposition; changing the selected main Provider/model/profile requires a separately admitted successor Attempt and fresh context compilation, while pre-bound grounder/specialist/verifier branches retain their own exact profiles;
6. no Provider result, cache, transcript, session, KV, state, budget, ordinal, execution reference, or egress permit is transplanted between branches or Attempts.

Legacy multi-Provider execution may remain only in an explicitly non-authoritative shadow/test adapter until retired.

At this snapshot, the repository-existing seam is `BASProviderAttemptExecutor.execute(providers:...)`, whose loop may invoke multiple list entries. `executeAtMostOnce` is an approved-planned atomic rename/contract target, not a current declaration.

### 6.6 Recognition

Every Main may recognize only an exact authorized profile relationship supported by current receipts. The closed assurance outcomes remain:

- profile continuity;
- authenticated account/device principal; or
- guest/unknown.

No plain `hostID`, model assertion, face guess, conversation similarity, style match, or restored transcript proves a person. Until exact profile-resolution and principal-binding owners are mapped and implemented, visible recognition remains disabled and the honest result is guest/unknown.

The only honest completion union is:

```text
guestOnlyMechanicallyEnforced
| governedRecognitionEnabled
```

`governedRecognitionEnabled` requires mapped profile-resolution and pseudonym/principal-binding owners, current signed receipts, reboot/currentness/deletion tests, and production reachability. `guestOnlyMechanicallyEnforced` makes relationship-specific rendering and recognition claims unreachable. A prose fallback to “guest” while relationship rendering remains callable satisfies neither branch.

### 6.7 Independent contexts and shared cache

- Main and every Sub receive independent immutable capsules.
- Sub outputs return as typed, attributed Artifacts with coverage and currentness; they do not append to Main transcript directly.
- Shared immutable source Artifacts may be referenced when each consumer independently passes eligibility.
- Mutable prompt buffers, KV, sampler state, tool handles, credentials, scratch, and Provider sessions are never shared.
- Agent-to-Agent envelopes use a low-entropy canonical schema with typed fields, correlation/source labels, and minimum-necessary evidence. Whenever policy requires an independence claim, a frozen communication profile supplies exact size and timing buckets; failure to satisfy that profile denies the independence claim. There is no peer channel, free-form hidden field, shared scratchpad, shared mutable cache, or unclassified timing/length side channel that can smuggle instructions or create correlated “independent” consensus.
- Specialist agreement is discounted or rejected when models, prompts, evidence ancestry, caches, retrieval sources, or tool results are correlated. A separately scoped deterministic validator or independently admitted verifier must check any decision whose policy requires independence.
- Every Main/Sub tool and network capability is least-privilege, purpose-bound, and absent by default. These constraints extend the existing Main/Sub and Provider owners; they do not create an Agent broker.
- Cache keys bind the complete selected admission-subject variant, execution-source extension, and release-kind extension above and, only for `.providerBacked`, the complete Provider/model/material/profile, ContextCapsule, tokenizer/template, StateABI, context ABI, and visibility/disclosure fields. Any applicable field mismatch is a miss; absent discriminant fields must remain absent, and no “mostly same Session” reuse exists.
- A late Sub result after cancellation or currentness change is inert evidence only.

### 6.8 Task hierarchy and memory horizons

One overall undertaking decomposes without adding stores or schedulers:

```text
Mission
→ finite Objectives
→ bounded WorkUnits
→ one or more fenced Attempts
→ verified Solution/Outcome Artifacts
```

Independent WorkUnits may advance concurrently when their read sets, budgets, and effects do not conflict. Logical concurrency never bypasses the one-local-HeavyPhase rule or creates more than one Main identity for a Session.

The frozen memory-horizon vocabulary is `current | day | week | month | archival`; `archival` is the long-term-memory projection requested by the product. These are immutable, purpose-scoped projections over one bitemporal event truth and the single selected content-disposition branch, not five writable stores. Durable content bytes exist only when the signed raw-content Decision Gate authorizes their exact class; otherwise the projections use typed structure, digests, minimum source-span metadata, and ephemeral materialization. A durable horizon manifest binds one closed source-subject/scope variant: App-Agent-private requires its authority root/scope, while neutral Host/user/shared-Workspace/project/task/purpose data binds its actual owner/scope and must not fabricate an App-Agent root. It also binds bitemporal/EventLog ranges and root/head, provenance, coverage/omissions, schema/calendar policy, policy/deletion/invalidation epochs, rebuild lineage, visibility/purpose scope, and expiry—not a transient Provider, ContextCapsule, Attempt, or execution generation. Each retrieval/consumption into an App-Agent WorkUnit or Provider context then equality-binds the current Section 6.4 admission-subject variant, execution-source extension, release-kind extension, and any exact read-only share/release; failed currentness/eligibility makes that consumption unavailable without invalidating unrelated long-horizon source truth. A long Session does not continuously stuff its full transcript into every Provider context.

### 6.9 Human and model adaptation

HumanFit and execution adaptation remain separate:

- explicit user preferences may affect allowed presentation and declared Provider choice;
- inferred mood, fatigue, uncertainty, or conversational style remains a transient, low-confidence hypothesis and cannot change truth, authority, safety, verification, disclosure, or durable identity;
- repeated behavior may create a confirmation candidate, never a hidden durable psychological profile;
- device state, latency, memory, thermal pressure, cost, rate limits, and model capability select only among already certified execution profiles;
- model strength does not change authority; and
- no single global comfort score may jointly mutate tone, context, retrieval, tools, thinking depth, and Provider routing.

### 6.10 Cautious Web Search

Interactive Web search is not a privileged truth lane. The outbound query, destination, account/credential context, and any disclosed user text form a disclosure-bearing external effect and traverse the complete Section 4.2 path: L9 proposal, L10/L11 decision, L13 causal preparation/read set, K3 outbox prepare/enqueue, L14 authorization, K4/Zone-C fencing and dispatch, receipt, and reconciliation. Search is issued only when the user explicitly requests it, local evidence is insufficient, or freshness/source attribution is required; query minimization removes unrelated private state, secrets, hidden instructions, and unnecessary identity.

Returned pages, snippets, metadata, scripts, and attachments are source-bound untrusted claims, never commands. Before they may influence an answer, they pass bounded fetch/parsing, active-content suppression, prompt-injection and instruction/data separation, source identity and publication-time capture, claim-to-span provenance, freshness/currentness checks, and R6 contradiction/grounding validation. Material claims seek primary evidence and, when independence matters, genuinely independent corroboration rather than syndicated copies. Citations bind the exact claim, source, retrieval time, and supporting span.

Search output cannot execute a tool, alter routing or policy, expand its own retrieval scope, enter governed memory, become training truth, or supply durable App-Agent/Self state directly. It may only produce eligible evidence or a cleaned candidate through the normal admission path. Network failure, robots/access denial, ambiguous freshness, source conflict, or suspected injection yields bounded partial evidence, clarification, abstention, or denial—not silent trust or repeated uncontrolled browsing.

### 6.11 Universal content and attachment intake

All local files, share-sheet items, pasted rich content, camera/import results, Web attachments, tool outputs, and future API attachments enter through one immutable value-contract family before semantic parsing or retrieval:

```text
BASContentIntakeProfilePayload
→ bounded parser/decoder/containment execution under Adapter / Input Normalizer
→ BASContentIntakeReceiptPayload
→ ordinary-put/reopen in Artifact Mesh
→ eligible child/source-span Artifacts may enter L7/L8 under normal currentness
```

The profile freezes accepted UTType/MIME/extension/magic/signature combinations; parser and containment identities/versions; limits for raw and decoded bytes, decompression ratio, nesting, archive entries, pages, pixels, frames, duration, CPU/time, memory, and child count; active-content and external-reference policy; metadata/privacy policy; encoding/Unicode policy; and the exact fail-closed disposition vocabulary.

The receipt binds one closed source identity—`governedSourceArtifactID` or `ephemeralInputEventID + normalizedInputDigest`, never zero or both—plus the profile, detected/declared type agreement, raw/decoded sizes, decompression/nesting/entry/page/pixel/frame/duration observations, parser/containment identity, EXIF/location stripping, OCR and child lineage, source spans, encoding normalization, controls/confusables, taint/provenance, active content, scripts/macros/forms/embedded files, external references, zip/path traversal, symlink/hardlink findings, partial coverage, omissions, warnings, and one terminal disposition: `accepted | acceptedPartial | quarantined | unsupported | limitExceeded | malformed | denied`. Missing or failed parsing is typed unavailable/quarantined, never false empty.

The profile and receipt are content-free control values and embed no raw or decoded document bytes. They may reference an already governed user-owned source or ephemeral materialization. Creating a new durable raw source, decoded child, OCR body, cold-replay body, or parser cache still requires the current signed Decision Gate for that exact class and purpose; absent that gate, only digests, bounded span coordinates, typed observations, and ephemeral bytes exist.

PDF/Office scripts, macros, forms, embedded files, archive members, external references, OCR text, and document instructions remain untrusted data. Content cannot introduce a system instruction, Provider/tool capability, network permission, policy, authority, memory status, or executable effect. Every child retains exact parent/span/taint lineage and is independently revalidated at consumption.

This is one first-governed immutable contract family reused by existing ingress, semantic, Web, vision, and tool-result paths. Its class is an E/A extension only if controlled convergence proves all four existing responsibilities without moving authority: the existing ingress-contract/schema owner defines the pure value shape; `production.cutover` freezes the exact release-selected profile Artifact ID; the already shipping Host input Adapter/IO mechanism consumes that profile and emits the receipt without choosing policy; and L14/current Host policy decides whether that exact event may proceed. The caller, parser, model, and content cannot select or widen the profile.

That mapping requires a candidate-index-bound, non-empty `ea_extensions` manifest in every applicable implementation wave, each containing that wave's exact set of singular `ExtensionSlice` records, plus separate schema-fixture closure. Each slice names exactly one existing owner, one existing path/symbol seam, exactly one classification `E` or `A`, `introductionWave`, `workWave`, prerequisite receipt/digest set, and the exact responsibility it extends: schema/value shape; `production.cutover` profile selection; Host Adapter/IO parser/containment mechanism; Host receipt production; or L14/current-policy authorization. Two payloads may share one schema envelope only when the same proven schema owner already owns both; responsibilities owned by different incumbents or waves can never be merged into one slice or envelope. W1 may freeze only its schema/value slices; Host/mechanism/L14 and W6 `production.cutover` slices land only in their owning waves, and no later-wave slice may satisfy an earlier gate or consumer. Exact current canonical round-trip, missing-version rejection, future-version rejection, canonical-codec parity, and parent/source-lineage mutations are mandatory. Because this is a first authoritative wire, a backward fixture or migration is forbidden unless controlled evidence names a real prior authoritative wire/version. The family submits no M/CreateGate candidate manifest. Production intake remains dark/typed `unsupported` until every required slice across all owning waves and the final release-selected profile reachability pass. If any wave's exact slice set/cardinality or incumbent responsibility cannot be proven, that content category remains blocked; this document does not authorize a new intake owner.

Artifact Mesh stores the immutable values and existing domain owners decide later eligibility. There is no `AttachmentManager`, parser authority, file store, attachment scheduler, mutable profile registry, or second content truth.

## 7. NextQuestion Idle-Workspace Correction

The approved-planned process-local `BASNextQuestionProjection` remains the sole target mechanism; it is absent from current production declarations. No `QuestionPredictor`, engagement manager, notification scheduler, or thought detector is added. Its currently approved-planned original wire is answer/release-parented, so idle mode remains disabled until one same-owner discriminated source amendment, migration, fixtures, rendering tests, and currentness tests land; prose alone cannot omit required parents.

It supports two non-authoritative trigger modes:

### 7.1 Post-answer

The current design remains: recompute only after an exact `terminalComplete` answer, empty input, no unresolved confirmation, and current release/Session/AppAgent/Main bindings.

Its closed canonical candidate sources remain byte-for-byte in meaning:

- the finalized answer and its existing Artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification; or
- an already authorized unresolved horizon thread.

### 7.2 Idle workspace

Opening or resuming a Session may recompute a process-local suggestion only after exact Session selection evidence and a current authorized Workspace snapshot exist. This recomputation is not an Input Event and is not durable user intent.

The amended source is a closed union: `.postAnswer` retains the existing exact answer/release/source parents; `.idleWorkspace` instead binds `AppAgentSessionSelectionEvidence`, `ContextWorkspaceRef`, selected App-Agent authority scope/root, logical Main, current authority heads, Workspace snapshot/task-graph roots, exact qualifying source-item ID, focus/current-view and empty-input state, source epochs, objective/schema version, recomputation time, and expiry. WorkUnit, Attempt, execution generation, Provider/profile/material, and ContextCapsule parents are tagged present only when those objects already exist for the qualifying source; otherwise they are canonically absent. Idle recomputation creates none of them. The variants cannot substitute parents or migrate into one another. Until this union is controlled, only `.postAnswer` exists.

Both NextQuestion source variants use `deterministicProjectionNoTurnOperation + nonAnswerMiniRelease`. They may read exact already-authorized source Artifacts, but candidate generation/ranking itself allocates no Provider branch and cannot borrow a prior Provider execution as a new call. Only the later explicit user tap creates a new Input Event that may admit Provider-backed work.

`.idleWorkspace` candidates may come only from:

- a user-authored unfinished WorkUnit or objective;
- an already authorized unresolved horizon thread;
- a verified missing constraint that the user can answer;
- a previously deferred explicit user request.

It may not infer a hidden desire, fabricate anxiety, derive a protected trait, mine another App Agent's private history, or manufacture work merely to increase engagement.

### 7.3 Shared rules

Both source variants use one non-answer card path:

```text
current source variant
→ zero-to-five bounded candidates
→ closed candidate branch:
     zero candidates OR failed grounding/threshold/margin
       → no winner projection, no mini-release, no card
     one-to-five passing candidates
       → deterministic frozen winner projection + Required Semantic Baseline
       → L9-selected mini-candidate
       → buffered L12 / L10 / L11 / L14 mini-release
       → exact render-currentness CAS
       → at most one visible card
```

This mini-release never creates `terminalComplete`, `BASPublicationBoundaryPermit`, answer-complete UI, or a terminal-answer/final-publication exception. A semantic-null fixed chrome asset may only reveal the exact winner through that mini-release; the complete semantic question must then be visible before a separate explicit tap can submit it. Hidden-winner submission, loser substitution, and one-tap reveal-and-submit are forbidden.

- zero to five internal candidates;
- at most one visible card;
- weak score/margin or incomplete grounding produces zero cards;
- complete visible semantic question before submission;
- label as a suggestion, never “the question in your mind”;
- exact expiry and currentness CAS;
- immutable objective ID, candidate-set digest, per-candidate feature/score-component vector, winner digest, threshold and margin evidence, duplicate-suppression key/window, expiry, and render-CAS generation;
- any typing, focus change, App Agent/Session/Main change, epoch change, deletion, revocation, or source-head change discards the pool;
- only an explicit tap creates a new Input Event;
- view, ignore, timeout, or dismissal is not automatically a durable preference or negative reward;
- NextQuestion never notifies. An unrelated proactive feature requires its own InitiativeLease and release path and cannot treat this projection as notification authority.

## 8. Reasoning and Information-Sufficiency Closure

No new solver owner is introduced. Existing requirement, DAG, verification, and certification owners receive deterministic fixtures and typed evidence.

Information sufficiency is a hard deterministic gate implemented by the one phase-tagged `BASInformationSufficiencyPayload`, with the closed outcomes `readyVerified`, `remandRetrieval`, `remandTool`, `needsClarification`, `partialVerified`, `abstain`, and `denied`. After R6 and before Main context compilation, preflight reopens the exact requirement, coverage, conflict, snapshot/currentness, and budget parents. It may spend at most one already-authorized bounded preterminal remand; that remand re-enters L7/R0-R6 and must produce a new parent-complete preflight rather than mutating the old result.

After all contributing Provider branches are terminal-sealed and deterministic evidence is immutably frozen, each intended visible disposition—answer, clarification, scoped partial, abstention, or denial—must first be its own L9-selected candidate and immutable L12 envelope. L10/L11 evaluate but never rewrite it; L14 authorizes or denies that exact candidate, then final sufficiency reopens the exact candidate, L14 receipt, branch heads, and current epochs. Any requested transformation or non-exact allow permanently rejects that envelope and requires the bounded successor-candidate path in Section 4.1; denial may instead close with the exact zero-byte marker. Only `readyVerified` may become an unqualified `terminalComplete`, and a zero-terminal-Provider terminal-answer outcome remains internal/non-visible under V1. Model confidence, eloquence, consensus, repeated challenge, or exhausted budget can never upgrade an outcome, change its phase, or substitute a parent.

The first checked-in reasoning suite must include:

1. multi-constraint ordering with unique, multiple, and impossible solutions;
2. UTF-8 long-text extraction with exact source spans, coverage, conflict, and unsupported-summary rejection;
3. practical resource/time/location/dependency planning, including a “wash car / what to bring” fixture whose required objects and ordering are explicit;
4. underdetermined lateral/turtle-soup cases requiring the highest-information clarification rather than invented certainty;
5. strongly leading subjective prompts preserving uncertainty and alternatives;
6. repeated user challenge that preserves the original dispute/budget lineage and changes strategy instead of restating;
7. loop-inducing prompts that terminate under progress/budget rules;
8. code, calculation, SQL, and tool tasks with independent execution/validation where authorized;
9. missing-information cases that produce clarification, scoped partial result, abstention, or denial rather than a forced answer; and
10. model-switch cases proving no old Persona, transcript, KV, or Provider session crosses the new Attempt.

One-shot correctness remains an aspiration measured by these suites, never an unconditional product guarantee.

## 9. Learning, RSI, and Causal Safety

Every authoritative K3 event group and every terminal or interruption outcome—completed, failed, refused, cancelled, crashed, abstained, or zero-output—must ordinary-put/reopen exactly one immutable, scope-bound, provably content-free typed Experience Envelope (typed structure, digests, minimum span metadata, and content-reference facts only) or one explicit typed ineligible receipt explaining why no Experience may enter the learning lane. Silent omission is forbidden; this preserves failure/cancellation evidence without granting it truth or success authority. Any later durable raw/content bytes require the separate Decision Gate below, live in separate encrypted purpose-bound Artifacts, and are associated only by governed downstream digest/reference lineage without changing the Experience bytes.

The governed learning path remains:

```text
authoritative outcome/event group
→ validate the minimum ingress scope/provenance/currentness required to frame one record
→ closed ingress record:
     ordinary-put/reopen immutable Experience Envelope → continue
     OR ordinary-put/reopen explicit ineligible receipt → terminal; no learning candidate
→ for Experience only: every downstream derivation binds that exact reopened Experience Artifact ID
→ contamination and privacy cleaning
→ reopen the current signed raw-content Decision Gate for the exact content class/purpose
   ├─ authorized: permit only minimized/encrypted content materialization within that exact disposition;
      no dataset or candidate exists yet
   └─ absent/denied/stale: provably content-free typed receipts/features only;
      no dataset/candidate exists yet, and durable raw/content materialization,
      export, trainer input, and cold replay remain disabled
→ typed reward/evidence vector + attribution/credit status
→ candidate dataset / Evidence-B / runtime-state / Policy-A / model / code / policy generation
→ offline replay, counterfactual analysis, holdout/OPE, and shadow evidence as applicable
→ closed target-specific terminal path:
     authoritative runtime-state target
       → exact candidate/read set + rollback → complete Section 4.3
     inert evidence/data/job/dataset Artifact
       → incumbent owner/schema validation + bounded canonicalization
       → Artifact Mesh ordinary-put/reopen immutable bytes
       → after required Extension/Create convergence, K3 retains only mapped
          semantic lifecycle/currentness/reference/deletion-fence facts
       → every retrieval/evaluation/export/trainer/protected use reauthorizes
          current purpose/policy/consent/deletion epochs
     non-runtime Policy-A/model/code/schema/policy target
       → K3 retains only an inert candidate/evidence reference
       → runtime.certification E0-E4
       → production.cutover creates a separately sealed canary Release/deployment
       → runtime.certification E5 from delayed field evidence
       → production.cutover creates a different, separately sealed full Release
     missing mapped owner/path
       → deny; neither K3 reference storage nor prose creates adoption authority
→ monitored independent result becomes a new source event; no output certifies itself
```

Every durable Experience/dataset candidate passes the inherited cleaning sequence before use: source normalization; provenance/authority classification; privacy, consent, and scope enforcement; contamination and prompt-injection isolation; dedupe/ancestry and split-leakage control; outcome/label and missingness validation; and final currentness/deletion/purpose eligibility. The authorized raw-content and content-free branches never substitute for one another. Cleaning may lower or reject authority. It can never manufacture it.

Section 3 replaces only the online turn ordering; it does not compress or bypass the learning contract. The immutable learning order is:

```text
causal-root grouping
→ split assignment
→ within-split derivation
→ evaluator/reward computation behind the evaluator firewall
→ hard-veto filtering, then Pareto comparison
→ protected holdout under one-shot access and an explicit information budget
→ shadow/canary evidence under a frozen policy epoch and temporal cohort
→ delayed field evidence and drift check
→ separately sealed adoption or rejection
```

Every derived item carries causal-root ancestry, split, temporal cohort, policy epoch, evaluator identity/version, reward-feature identities, all-clean-ancestor proof, and one stage-tagged holdout disposition. Pre-access items carry exactly `notYetAccessed(protectedPolicyID)` or `notApplicable`; only post-access evaluation/adoption manifests may carry `accessed(exactHoldoutReceiptID)`. No immutable item predicts a future receipt. Descendant generation cannot precede split assignment; evaluator/model/cache/source ancestry correlation cannot masquerade as independent evidence. A hard safety/privacy/authority veto is never averaged away. Drift, correction, deletion, contamination, evaluator invalidation, or policy-epoch change synchronously makes affected candidates ineligible and requires bounded rebaseline before reuse.

The App-Agent cleaning ladder remains complete: normalization; provenance/authority; privacy/consent/scope; injection/instruction-data isolation; dedupe/ancestry/split leakage; outcome/label/missingness; and final currentness/deletion/purpose. A correction, taint, deletion, or policy invalidation enters one K3-owned epoch/head invalidation CAS that synchronously fences every later consumer. Its exact fanout covers active Attempts and Provider branches, pending release/publication/effect/state paths, FTS, dense, temporal, entity/relation, cache, compiled context, NextQuestion, evaluation, RSI, dataset/Evidence-B, runtime-state, Policy-A, and model/code/schema/policy candidates. Each non-K3 owner retains its own terminal/query/reconcile/deny transition; K3 does not rewrite another owner's rows, and a possibly crossed external boundary is never “undone” by taint. Already canaried/adopted non-runtime targets trigger the existing `production.cutover` exposure fence plus target-specific revoke/rollback/rebaseline path before further exposure. Projection cleanup/rebuild may finish asynchronously, but all reads and boundary advances check the invalidation epoch first; during the gap consumers receive typed `unavailable | quarantined | rebuilding`, not stale bytes or false empty results.

The complete legacy causal production reachability must retire or isolate, not merely the fresh heuristic extractor: `BASKnowledgeGraph` schema/storage reads and reload, sequence/co-occurrence extractor, builder preload/composition, convenience fold, and graph-aware reducer mouths are all fenced. Persisted legacy `.causes` rows migrate only to typed untrusted association/historical evidence or quarantine; they cannot enter L4 world claims, L5/L6 user state, or any authoritative reducer. Today, user-state influence is indirect and conditional, including cycles containing `.delays` affecting `complexityAddictionScore`, rather than every `.causes` edge directly writing state. Temporal order, association, execution dependency, claim support, and world causation remain distinct typed concepts.

The production retirement manifest must cover the exact 12-row closed set from governed-learning §4.12, with stable IDs:

```text
learning-legacy.distillation-bank
learning-legacy.apple-intervention-bandit
learning-legacy.qinao-learning-exporter
learning-legacy.update-ticket-lifecycle
learning-legacy.evolution-lifecycle
learning-legacy.training-data-exporter
learning-legacy.training-example-sublimator
learning-legacy.evolution-governance-bundles
learning-legacy.retraction-furnace
learning-legacy.memory-sleep-consolidation
learning-legacy.qwen-mlx-default-seams
learning-legacy.samplehost-learning-export
```

Each row binds the exact §4.12 source-row digest, canonical symbols, source paths, shipping constructors/call sites derived from the production graph, disposition, mapped target owner, and positive/negative terminal set. Cardinality and ID equality are exactly 12; a missing/extra ID, removed row, unclassified alias/factory, or newly detected shipping call fails. Every row has one mutation that deletes its coverage and one that adds a shipping construction/call. In particular, the set reaches `BASUpdateTicketLifecycleCoordinator` approve/distill and HostKit construction, `BASMemorySleepConsolidationPass` writes, `BASTrainingDataExporter`, and hard-coded evolution safety booleans. Each item is retired, source-gated, or reduced to a value-only client of the mapped learning/adoption owner; no legacy coordinator retains an independent promotion, export, write, approval, distillation, or adoption mouth.

RSI uses the existing bounded ControlRings and owner paths. It may improve decomposition, retrieval strategy, verification coverage, context allocation, cache plans, and candidate policies. It may not create a fifth ring, hidden scheduler, direct self-modifying code path, direct weight update, direct memory write, or authority expansion.

Only the exact encoded terminal pair `converged + converged-verified` (Swift reason case `.convergedVerified`) together with its current committed K3 budget-use receipt may become authoritative downstream input. Equivalent-state repetition with the same strategy, a repeated canonical digest, unmet fixed obligation, cycle/no-progress, budget exhaustion, cancellation, uncertainty, degraded coverage, or reconciliation-required output remains non-adoptable; none resets an obligation generation or any token/time/branch/remand/effect budget.

The immutable RSI wire decision is to preserve the repository's existing hyphenated encodings with no production migration. In particular, Swift `needsConfirmation` encodes as `needs-confirmation`; the related frozen values include `degraded-with-coverage`, `indeterminate-needs-reconciliation`, `cycle-detected`, `budget-exhausted`, and `no-progress`. Contracts text, remediation tests, and all current/backward/future fixtures must be corrected away from underscore aliases; this correction adds no state.

## 10. Apple-Silicon and Provider Execution Policy

### 10.1 Healthy device objective

The optimization objective is verified completed-task utility under latency, memory, energy, thermal, privacy, recovery, and quality constraints. It is not maximum raw decode speed or keeping every Apple engine busy.

- once W4 creates and activates `resource.process-memory-ledger`, exactly one K1-owned host-process local HeavyPhase lease is a hard invariant, and neither the owner nor lease is claimed as current production code;
- every Provider branch takes only its containment/profile-specific K1 reserve before committed K3 use: an accelerator-heavy `.inProcessCertified` branch—including opaque-local AFM execution—takes the sole host HeavyPhase lease; under V1 an `.isolatedExtension` branch is K4/security/IPC-narrow and is forbidden from Core AI, AFM, MLX, vision, embedding, or other accelerator-heavy execution; a `.remote` branch takes bounded network/Provider/cost/rate reserves and holds no local HeavyPhase while waiting;
- remote wait and admitted lightweight CPU/SQL overlap are therefore not a second local HeavyPhase;
- admitted lightweight SQL/Rust/CPU preparation may overlap only when the MemoryLedger and thermal profile allow it;
- independent logical contexts do not imply multiple resident 4B trunks;
- Qwen may remain resident during an admitted interactive turn;
- Granite-class embedding may remain resident only if exact evidence beats load/eviction cost;
- MiniCPM text loads only when expected verified utility exceeds specialization/residency/switch cost;
- MiniCPM-V loads only for an admitted visual task;
- AFM remains a system-managed Provider and is never a conversion target;
- Core ML microheads remain allowlisted when measured Pareto evidence beats migration; “Core AI target” does not require knowingly slower conversion;
- Metal/C/C++ stay behind Provider/upstream/custom-op seams; Rust owns existing deterministic hot logic behind a narrow ABI; SQL owns indexed durability under its mapped writers; Swift owns host orchestration and Apple lifecycle;
- the legacy `BASStateLakeReader` neural-tensor reader is renamed to a neural-state/tensor-cache reader; “StateLake” is reserved for semantic StateLake. Any compatibility alias is deprecated, non-authoritative, and absent from new production composition.

The intended portfolio remains model-neutral:

| Role | Candidate | Production condition |
|---|---|---|
| Main cognition Provider candidate | Qwen3.5-4B text profile | separately packaged and evaluated candidate; a converted/signed Core AI profile becomes eligible only after full-chain same-cohort certification; native MTP and vision remain false until independently certified |
| Main cognition Provider candidate | on-device AFM | system-managed FoundationModels profile with exact availability/accounting/quality/recovery evidence; never a conversion target |
| text Sub | MiniCPM5-1B | independently converted and certified, loaded only for an admitted specialist task |
| vision Sub | MiniCPM-V 4.6 | independently converted and certified ProcessorABI/profile, loaded only for admitted visual work |
| retrieval mechanism | Granite Embedding 97M Multilingual R2 | encoder-only proposal mechanism, not an Agent and never a truth/eligibility owner |
| future Main or specialist | exact API model/profile | default disabled until destination, model, disclosure, credential, cost, retention, purge/query, recovery, and release evidence pass |

Names are portfolio policy, not SDK constants. Core AI is a preferred candidate execution technology, not a preselected winner. The already certified MLX profile remains the incumbent wherever its certification applies until a same-model-material, same-workload/cohort comparison proves a Core AI profile Pareto-superior or policy-preferred across quality, TTFT, accepted decode, end-to-end completion, resident and peak memory, energy, thermal behavior, cancellation, crash recovery, and packaging. If neither profile is certified, there is no production winner. Qwen, MiniCPM, and Granite conversions are evidence-gated portfolio candidates rather than mandatory product components before their own E4/E5 closure; AFM is never converted, and measured Core ML microheads remain valid when they win.

`AppleFoundationOrganAdapter` is production-unreachable while it reports a hard-coded `.certified`, a fixed 4096 context, `.unlimited` budget, or character-derived token estimates. An AFM profile becomes eligible only from exact public `SystemLanguageModel.availability`, OS/device/model cohort, declared `contextSize`/token-count observations exposed by the selected SDK, capability/currentness evidence, and full cancellation/recovery tests. Unknown or unavailable observations fail closed; they are not replaced by optimistic constants.

### 10.2 Full-blood quality

Quantization, pruning, distillation, alternate expert topology, substitute MTP tensors, or a smaller model are separate material/profile identities. They may be promoted only after quality and recovery certification. They are never silent thermal fallbacks.

Within one exact profile, pressure may disable disposable prompt-lookup/MTP scratch and continue on the same target if that collapse is pre-certified. A different Provider or model requires a new Attempt.

### 10.3 Performance claims

Cold 40 and sustained 30 remain optional claim tiers. They bind the complete canonical certification protocol rather than only a threshold:

- cold 40 uses exactly two distinct physical devices and exactly two independent 50-turn replicate blocks per device, therefore exactly 100 preregistered workload turns per device/cohort. Each block has a distinct verifier-generated run ID and fresh declared process/profile setup. Before every measured turn ambient is `22 ± 2 °C`, Low Power Mode is off, declared power/screen/radio/background-load conditions hold, no undeclared active cooling is used, and public thermal state is continuously `nominal` for at least 300 seconds; model/runtime residency, specialization/cache state, full-prefill class, prompt/context/output buckets, sampling/RNG/termination, timer, inter-turn interval, failures, and exclusions are preregistered. Every 50-turn block on every device must independently achieve thermally-cold resident target-verified accepted-decode p10 at least 40 tok/s and pass identity, memory, error, and thermal gates; averaging across blocks or devices cannot rescue a failure;
- sustained 30 uses exactly two distinct physical devices and exactly two independent uninterrupted 1800-second continuous-arrival runs per device. Runs have distinct verifier-generated run IDs; between runs the device is rebooted, returned through the same preregistered ambient/thermal preparation, and given a fresh declared process/profile setup. Within a run there is no inserted cooldown or relaunch. Fixed/reported arrival, prompt/prefill/output, model/cache, power/ambient, and timer conditions apply, and every run on every device must independently achieve last-quarter accepted-decode p10 at least 30 tok/s without positive memory slope or hidden output-length, quality, retrieval-coverage, or safety reduction; averaging cannot rescue a failed run;
- only target-verified accepted tokens enter either numerator; proposed/rejected draft tokens, prompt-lookup hits, avoided calls, prefill, TTFT, verification/release, and end-to-end goodput remain separately reported;
- claim acceptance is the deterministic intersection of all required replicate terminals. Exclusion rules and every allowed equipment/setup failure are preregistered; a missing, shortened, duplicate-ID, selectively excluded, or failed required replicate denies the claim;
- an unrequested claim is `.notRequested` and cannot block structural architecture completion;
- a failed requested claim denies only that claim-bearing profile/release;
- current roughly 10 tok/s Core AI multi-asset evidence and incomplete conversions prove neither performance tier nor production superiority.

The production verifier derives every aggregate from raw bound traces; caller-precomputed `p10`, rate, memory slope, pass Boolean, or reduced sample vector is rejected. For cold40, each of the 50 scheduled turns contributes exactly one canonical rational accepted-decode rate: target-verified accepted token count divided by monotonic nanoseconds from the first decode step through final target-token acceptance, including draft proposal/per-step verification stalls but excluding prefill and post-decode output verification/release. No turn may be dropped; an allowed equipment/setup invalidation invalidates the entire replicate. For sustained30, run start fixes exact one-second half-open bins, and the last quarter is exactly `[1_350 s, 1_800 s)`, yielding exactly 450 bins; each bin contributes target-verified accepted tokens divided by exactly `1_000_000_000` ns.

For any population of N rates, p10 is nearest-rank `sortedAscending[ceil(0.10 × N)]` with one-based indexing: the fifth of 50 cold turns and the forty-fifth of 450 sustained bins. Rates remain integer rational pairs, sort/threshold comparisons use checked cross multiplication without floating-point rounding, and display decimals are non-authoritative. Boundary-straddling tokens belong to the bin containing their verifier timestamp; no interpolation or partial-bin substitution is permitted.

The sustained memory population is independently exact. For an in-host V1 local profile, the schema freezes `task_info(mach_task_self_, TASK_VM_INFO, …).phys_footprint` as the sole metric, unsigned bytes as the unit, the built collector's source/binary digest and `TASK_VM_INFO` ABI/count, and exactly one read in each of the same 450 last-quarter bins. Its target phase is the bin midpoint; the recorded sample is the first successful call whose actual monotonic timestamp is at or after that midpoint and before the bin's exclusive end. A missing/failed/early/late/duplicate read, returned count too small for `phys_footprint`, metric/ABI/collector substitution, unit conversion, interpolation, or post-hoc reduction denies the run. Each raw row is exactly `{binIndex, targetMidpointNanos, actualMonotonicNanos, physFootprintBytes, taskVMInfoCount, collectorDigest}`.

The exact least-squares sign uses all 450 raw pairs `x_i = actualMonotonicNanos - runStartNanos`, `y_i = physFootprintBytes`: checked wide-integer `slopeNumerator = 450 × Σ(x_i y_i) - Σx_i × Σy_i` must be `≤ 0`, while `slopeDenominator = 450 × Σ(x_i²) - (Σx_i)²` must be positive; no floating point or fitted subset is accepted. This metric certifies only the measured host process. A system-managed/out-of-process Provider cannot inherit the claim from host `phys_footprint`; without a public, profile-certified, raw attributable footprint metric for that execution domain, its sustained-memory gate and therefore its sustained-30 claim remain blocked.

Before either claim can be requested, the architecture, Runtime, Silicon, master, schemas, fixtures, and checkers must atomically converge both protocols: cold is exactly two devices × two 50-turn blocks and sustained is exactly two devices × two 1800-second runs. Existing caller-aggregate acceptance and one-sustained-run-per-device wording are explicitly superseded; a future larger cohort or different replicate/sample protocol changes the harness identity and requires a reviewed revision.

The measurement chain binds the exact shipping archive, Mach-O/CDHash, model packages, code signatures, provisioning profiles, entitlements—including any increased-memory-limit entitlement—device identifiers/OS/build, verifier-generated run IDs, ambient sensor identity/calibration/procedure, power and radio conditions, declared process/profile setup, and raw monotonic traces. The acceptance rule above replaces discretionary post-hoc confidence selection: every exact replicate must pass under preregistered exclusions. Simulator, development-only, altered-entitlement, selectively cooled, shortened, duplicate-ID, exclusion-drifted, caller-reduced, or harness-only results are labeled as such and cannot certify the shipping profile.

### 10.4 Foreground fairness without another scheduler

The existing K1 resource-admission owner that will own `resource.process-memory-ledger` also owns a bounded admission discipline; `BASBreathScheduler` remains background maintenance and is not a foreground fairness authority. Its original W4 M/CreateGate first wire must freeze one nested, versioned foreground-admission contract and one owner receipt with exact fields and checked units: queue capacity; closed priority enum and total order; per-class monotonic aging thresholds; service-window duration; minimum and maximum service quanta per Session/window; queued byte/token caps; deadline policy; cancellation generation/owner; maximum prefill tokens/time per quantum; maximum decode tokens/time per quantum; maximum model-residency wait; maximum KV-prepare wait; maximum wired-memory-grant wait; a sorted exact-set `additionalDownstreamWaitBounds` array of `{stageID, maximumWaitNanos, evidenceRef}` for every other graph-discovered acquisition stage; cooperative-yield evidence; and one monotonic owner-issued `enqueueOrdinal`. The canonical comparator is total and stable: aged effective priority first, then earliest monotonic deadline, then lowest enqueue ordinal; no hash, wall clock, task scheduling order, caller value, or random tie-break may intervene. Signed build/profile values fill every field; callers cannot choose them.

The schema freezes dimensionally checked, overflow-trapping feasibility equations: `queueCapacity >= 1`; every minimum is nonnegative; every maximum is at least its minimum; the sum of simultaneously guaranteed minima fits the service-window capacity; all queue byte/token maxima fit the certified memory reserve; and aging reaches the highest service-eligible class before the independent release-policy cap `maximumCertifiedForegroundAdmissionDelayNanos`. The deadline policy supplies finite per-class monotonic relative deadlines plus canonical `minimumRelativeDeadlineNanos` and `maximumRelativeDeadlineNanos`; “no deadline” is one schema-fixed finite policy sentinel, not infinity. Within each service window a continuously pending Session still owed its minimum quantum is eligible ahead of every Session already at its minimum; the canonical aged-priority/deadline/enqueue-ordinal comparator orders the resulting owed-minimum pool and then the ordinary eligible pool. No Session may exceed its maximum. Arrival, cancellation, or requeue preserves original age/deadline/enqueue ordinal for the same WorkUnit and cannot reset another Session's owed minimum.

`maximumQueueTraversalNanos` is a receipt-carried derived quantity, never a caller/profile input. The runtime and independent evaluator compute the same checked unsigned-integer recurrence:

```text
A = checkedSum(all priority-promotion agingThresholdNanos)
D = maximumRelativeDeadlineNanos - minimumRelativeDeadlineNanos
U = maximumPrefillTimePerQuantumNanos + maximumDecodeTimePerQuantumNanos
m = maximum(perSessionMinimumServiceQuantaPerWindow)
maximumQueueTraversalNanos =
    max(A, D)
  + serviceWindowDurationNanos
  + (queueCapacity - 1) * m * U
```

After `max(A,D)`, the waiting WorkUnit has highest aged priority and a deadline no later than any subsequently arriving WorkUnit; bounded capacity leaves at most `queueCapacity - 1` distinct WorkUnits ahead. The added service window covers arrival immediately after the current window's floor allocation, and the final product covers every older owed-minimum quantum before the target under the floor-first rule. Continuous arrivals cannot enter ahead after dominance, cancellation can only remove work, and any state/cycle that violates these facts is unbounded and makes the profile ineligible. The one residual already-running non-yielding quantum is accounted separately as `maximumNonYieldingPrefillDecodeQuantumNanos = U`, not hidden in traversal.

The exact conservative admission bound is `maximumQueueTraversalNanos + maximumModelResidencyWaitNanos + maximumKVPrepareWaitNanos + maximumWiredMemoryGrantWaitNanos + Σ(additionalDownstreamWaitBounds.maximumWaitNanos) + maximumNonYieldingPrefillDecodeQuantumNanos`; it must be no greater than the release-policy cap under checked arithmetic. An independent reference evaluator derives `A/D/U/m`, recomputes traversal and this `maximumAdmissionDelay` from the raw frozen fields plus the production-graph exact stage set, exhaustively checks the finite queue/arrival/cancellation transition system against the formula, and byte-compares both values with the runtime receipt. A supplied traversal value, missing threshold/deadline/quota/stage, wrong dominance or ahead-work term, cancellation reset, double-counted/omitted wait, overflow, reachable no-service cycle, or merely finite but policy-excessive value fails.

“Admitted/served” terminalizes only when the Session receives its first physical prefill/decode execution quantum after every downstream model/KV/wired-memory/resource acquisition. Every shipping wait between queue selection and that quantum is discovered by the production graph and appears exactly once in the same sum; an unresolved, unbounded, or unlisted `WiredMemoryManager` or equivalent downstream wait makes the profile ineligible and cannot be hidden behind an earlier admission-success receipt. The W4 deterministic reference model exhaustively explores every queue state, equal-key tie, arrival/cancellation class, and downstream-acquisition terminal up to the exact finite bound; physical tests prove first-quantum, yield, timeout, and cancellation receipts. The discipline schedules already authorized work only and cannot change semantic priority, Provider identity, budgets, or release authority. Controlled convergence must revise the current “no waiter, queue, timer, or hysteresis” wording to forbid second, unbounded, durable, or authority-bearing maps while permitting this one owner-private bounded queue and monotonic deadlines. No new scheduler actor, durable timer truth, waiter map, or fairness database is created.

### 10.5 Buffered V1 has one invocation and one byte lineage

Shipping `streamBody`, `streamDraft`, raw/unbounded `AsyncThrowingStream`, and “stream once, then call `generate` again for the canonical result” paths are lab/test-only and production-unreachable. V1 performs one physical Provider invocation into the bounded non-visible spool, terminal-seals and verifies that exact result, and releases byte-identical authorized bytes. Cancellation must await the profile-certified physical-quiescence proof before a known cancelled seal, or preserve the exact unresolved/unknown disposition; dropping a Swift Task is not proof that the Provider stopped.

### 10.6 Remote profiles and secrets

Remote Provider execution remains unreachable from shipping composition until W5 closes the exact destination/model/disclosure/credential/cost/retention/query/purge/recovery path. A shipping `Endpoint` cannot serialize raw authorization headers or secrets, and SampleHost/application arguments cannot accept `--api-key`. Configuration and remote M carry only the nonsecret destination/authentication scheme/injection point, credential-slot identifier, and canonical request template. After exact disclosure authorization, the existing credential-slot store may return read-only content-free metadata for one exact current persistent reference/version frozen into the existing permit/use/anchor contract; it returns no secret and creates no lease. Only after that boundary permit is armed/claimed and handoff consumes Q+B may the transport resolve that exact secret version once into nonpersistent request memory and immediately invoke, with K4/Q+B as the sole consumption truth. It never logs, persists, echoes, returns, substitutes, or reuses that secret, and authenticated O/At prove the actual nonsecret binding.

### 10.7 Cross-process heavy work is V2

A Swift `static` actor or dictionary is process-local and cannot coordinate a host and extension. V1 therefore keeps all local accelerator-heavy work in the host as required by Section 10.1. Any future cross-process heavy execution requires a separate reviewed host-owned XPC arbiter with aggregate-footprint accounting, authenticated leases, bounded renewal, fail-closed lease loss, crash/currentness tests, and no extension-side scheduling truth. That V2 amendment cannot be inferred from `BASProcessMemoryLedger.processShared`.

## 11. K4 and Wave Discipline

The current K4 platform spike is preliminary compile/metadata/local-development-signing shape evidence only. Production progression remains blocked until the selected release toolchain/profile can prove:

- intended Enhanced Security capability and entitlement identity;
- the actual `.xcarchive`/IPA and its candidate-index/build-manifest identity;
- signed host and helper Mach-O files, CodeDirectory/CDHash, embedded provisioning profiles, code-signing chains, and decoded entitlements;
- structured `devicectl` installation, launch, process discovery, request/reply, container copy, and uninstall/reopen evidence on the bound physical device;
- an unpredictable challenge generated inside the production verifier only after archive and device selection, delivered by the verifier during that live run, and echoed/bound by the host/helper response and raw structured trace so copied, synthetic, offline, caller-supplied, or stale evidence cannot pass;
- unique helper/monitor identity;
- exact direct and asynchronous XPC replies;
- timeout, cancellation, and zero-pending closure;
- candidate-tree and artifact digest binding; and
- no simulator, unsigned, preliminary, symlinked, or stale proof substitution.

The production validator must parse and cross-check those physical artifacts and itself drive the live `devicectl` sequence in production mode. It accepts no caller-supplied challenge, success Boolean, or pre-recorded trace; raw structured command outputs, selected archive/device identities, response challenge, and copied container trace are captured and digest-bound by that same run. Raw CMS/profile/device-identity/trace bytes remain in the encrypted external evidence bundle defined in C2; Git receives only its privacy-clean signed root/coverage/verifier projection. Production recheck must reopen and revalidate the raw bundle under a short-lived authorized grant, so neither a projection alone nor an unavailable external bundle can satisfy the gate. A source file, JSON/plist fixture, expected marker, or hand-written log can test the validator but can never satisfy production-proof mode. Its negative suite must prove that the current synthetic fixture pattern, offline challenge, replayed trace, wrong archive/device response, redacted-projection-only input, and external-root mismatch are rejected.

The current checker does not yet implement that verifier and is known to accept a staged synthetic marker bundle as production proof. Controlled convergence must first make production mode unconditionally fail closed while the live verifier is absent; the existing synthetic bundle may remain only behind an explicitly fixture-only unit-test mode that cannot emit or satisfy a production receipt.

The convergence plan's proposed root-owned `/Library/Application Support/Qinao/ExecutionGate`, `/Library/PrivilegedHelperTools/com.qinao.execution-gate`, daemon/worker identities, sandbox/compile/toolchain brokers, service/trust registries, Git service, and Python closure are not repository-implemented prerequisites and must not be assumed by W0-W6. The default proof path is a repository-owned deterministic producer plus an independent real-archive/device verifier. Retaining an external ExecutionGate would require its own versioned source, build, signing, installer, bootstrap/update/revoke/recovery design, threat model, CI, and test vectors before any dependency is permitted.

Work inside W0 that improves inventories, documents, checkers, fixtures, and candidate hygiene may continue while external signing/profile evidence is unavailable. W1-W6 do not gain completion or production authority from that parallel W0 work.

### 11.1 Authority recovery stays with each owner

The recovery companion's lifecycle records, external floors, approvals, and lease/CAS wording apply only to a profile's `durableStore` state facet and must be mapped into each existing domain owner rather than left as implied shared infrastructure. An accompanying `externalEffect` boundary facet remains mandatory and independently query/reconcile-only wherever that same owner can cross a possible-start boundary; choosing `durableStore` never erases it:

- each repaired database carries an owner-private append-only recovery lifecycle plus a named external monotonic anchor/floor outside the bytes being repaired; the anchor's mapped physical store, protection, sole writer, update-before/after ordering, and recovery/loss behavior are part of the same owner contract;
- operator approval may use only the planned `trust.algorithm-agile-manifest`/K4 verification path after those `approved_missing` owners are lawfully created and the exact recovery purpose, operator-principal evidence, candidate/store/floor binding, expiry, and key custody are frozen. The repaired domain cannot approve itself. K4-ledger recovery additionally requires a verifier root and monotonic anchor whose custody and currentness do not depend on that damaged K4 ledger;
- a durable recovery lease is an owner-private CAS row with exact holder/generation/expiry and crash reopening; it is not a cross-domain RecoveryLease owner;
- quarantine preserves the exact database/WAL/SHM set and prohibits auto-create or empty-bootstrap when an existing store identity/floor says data must exist; and
- recovery completes only after schema/integrity/currentness checks, external-anchor comparison, owner-specific replay, and a new verified lifecycle record.

At this snapshot K4 and the trust manifest are both `approved_missing`, so every operator-approved reactivation path remains blocked/query-only; prose cannot substitute a signer or trust root. If the original trust first wire cannot close a non-circular K4 self-recovery verifier without another owner, K4 reactivation stays blocked. There is no `RecoveryAuthority`, `RecoveryRegistry`, global recovery database, global incident-record store, new signer, or fifth kernel. “Operator incident record” means the same mapped domain owner's verified owner-private recovery record.

### 11.2 Artifact Mesh physical durability and corruption recovery

`artifact.mesh` must close the same physical contract before it can remain `implemented`:

1. distinguish first create from reopen using an external store identity and anti-rollback floor; an expected existing store cannot silently `SQLITE_OPEN_CREATE` an empty database;
2. quarantine the exact database, WAL, and SHM bytes together on corruption or identity/floor mismatch;
3. bind schema version, commitment-key epoch, record count/root, CAS head, and ordinary-put floor to the owner-private recovery lifecycle;
4. use `synchronous=FULL` or independently prove an equivalent durability contract for “Artifact bytes durable before K3 reference commit” under power-loss/crash cuts;
5. verify every reopened payload digest and canonical ID before exposing it;
6. ensure semantic snapshots use immutable ordinary put with `headUpdate: nil`; K3 alone attaches their currentness; and
7. pass first-create, reopen, WAL/SHM loss, torn write, stale copy, wrong key epoch, rollback, put-before-K3-reference, lost reply, and concurrent-CAS tests.

The W1 physical target is not an abstract test floor. Existing `BASArtifactMeshCore.swift` retains only its already governed public Artifact identity/CAS contract. New `BASArtifactMeshAnchorPort.swift` contains an internal, non-public, owner-private persistence record binding application container/store role, random store identity, generation, schema version, commitment-key ID/epoch, record count/root, CAS-head root/revision floor, ordinary-put floor, previous committed digest, optional pending transaction ID/state, and protection version. That record is not a public wire/value-contract family, does not enter `BASEBrainSchemaGovernanceRegistry`, and cannot be consumed outside `artifact.mesh`. `BASArtifactMeshKeychainAnchor.swift` is the only shipping adapter. It stores one record with `kSecUseDataProtectionKeychain = true`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrSynchronizable = false`, a nonshared application Keychain access group, domain-separated service `com.qinao.artifact-mesh.anchor.v1`, and an account derived canonically from application container plus store role. The SQLite database/WAL/SHM use `completeUntilFirstUserAuthentication`; no raw commitment key appears in the anchor. Production reachability proves one host-process assembly/store instance and zero extension/raw-port construction paths; that instance is the sole serialized anchor writer. Existing sovereign-signing Keychain code may supply reviewed mechanism patterns only; it is not the Artifact Mesh owner or signer.

First create has an explicit genesis state machine. Only authenticated `anchor absent + database/WAL/SHM absent + authorized create request` may write `genesisPending(g = 0, createRequestID, storeIdentity, schema/key/protection tuple, expectedDatabaseAbsent)`. Only that exact reservation may then use `SQLITE_OPEN_CREATE`, install the schema plus matching store metadata/transaction ID under `synchronous=FULL`, and promote the anchor to `committed(g = 0)`. Protected-data/Keychain unavailability such as `errSecInteractionNotAllowed` is typed unavailable and never collapsed to absent/create.

A crash with `genesisPending + database family absent` may only resume the byte-identical authorized create request against that reserved identity; it is not the committed-anchor/database-loss case. `genesisPending + exact complete g=0 database metadata` finishes promotion idempotently. A partial/mismatched database family quarantines it. An expired/withdrawn genesis may erase the pending anchor only through an explicit operator-authorized reset after proving DB/WAL/SHM all absent and that no committed generation has ever existed; it cannot bootstrap a new identity silently. Once the anchor is `committed`, reopen requires the exact database family and opens without CREATE; committed-anchor loss with database present, database loss with committed anchor present, wrong application container/store role/key epoch, rollback, or ambiguous partial presence quarantines and never manufactures either side.

After genesis, every floor-advancing put/head transaction is serialized and two-phase across the independent stores: (1) Keychain changes `committed(g)` to `committed(g) + pending(g+1, transactionID, proposed roots/floors, expectedPreviousDigest)`; (2) one SQLite `BEGIN IMMEDIATE` transaction writes the payload/head plus the same generation/transaction ID/roots, commits under `synchronous=FULL`, and completes the required WAL durability/checkpoint contract before the Artifact can be referenced by K3; (3) Keychain atomically promotes that exact pending record to `committed(g+1)`. A bounded group commit may cover multiple canonically ordered puts to amortize Keychain cost, but none of their receipts becomes K3-referenceable until the same anchor promotion commits. Recovery may clear a non-genesis pending record only when the database proves the exact unchanged `g` state and absence of its transaction; it must finish promotion when the database proves the exact committed `g+1` state. Any other combination quarantines. Keychain deletion/loss is not recoverable from the database, and a test double, in-memory anchor, caller-supplied floor, or signed JSON cannot satisfy production implementation evidence.

The production composition is explicit in `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift` and its call from `QinaoSovereignHostAssembly.swift`; no caller may inject a shipping anchor port. This assembly only constructs the required `artifact.mesh` physical mechanism and exposes no runtime-route/profile/policy choice, toggle, fallback, or alternate store, so W6 `production.cutover` retains all route authority.

Physical recovery evidence comes from a separately signed/installable iOS lab app, not a SwiftPM library target. `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj`, its shared `ArtifactMeshDeviceLab` scheme, `App/ArtifactMeshDeviceLabApp.swift`, `App/ArtifactMeshDeviceLab.entitlements`, and `Probe/ArtifactMeshRecoveryProbe.swift` define one app product with bundle ID `com.qinao.artifact-mesh-device-lab`, an application identifier, one nonshared Keychain access group, default data-protection entitlement/profile, the ordinary provisioned iOS app sandbox, and lab-only compile condition `QINAO_ARTIFACT_MESH_DEVICE_LAB`. `SampleHost/Package.swift` excludes the whole directory, and selected-release checks prove the lab bundle, condition, symbols, and fault hooks absent from the shipping archive.

`scripts/run_artifact_mesh_device_recovery.py` is the sole controller. It builds and signs the exact lab archive, parses Mach-O/CDHash/profile/entitlements, installs it, generates a fresh scenario challenge, and drives structured `devicectl` install/launch/force-terminate/container-copy/uninstall plus explicit operator-recorded protected-data lock/unlock checkpoints. The app/controller protocol is a closed challenge-bound tagged product, not an open string: `cut = before(operation) | after(operation)` where `operation` is exactly `genesisReserve | genesisSQLiteCommit | genesisAnchorPromote | reopen | ordinaryPutAnchorPending | ordinaryPutSQLiteCommit | walShmCheckpoint | ordinaryPutAnchorFloorPromote | k3ReferenceCommit | quarantineInstall | recoveryLeaseAcquire | recoveryFloorUpdate | recoveryComplete`.

`docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json` is a candidate-index-bound verification matrix, not runtime authority. Its closed schema gives every row exactly `{scenarioID, initialState, cut, mandatoryFaultAction, faultTiming, expectedReopenDisposition, expectedStoreIdentity, expectedGeneration, expectedRecordRoot, expectedCASHead, expectedOrdinaryPutFloor, expectedRecoveryFloor}`. `faultTiming` is exactly `none | whileProcessAlive | atDurableCommitBeforeReply | beforeRecoveryOpen | afterRebootBeforeFirstUnlock`. It contains the exact 26-row cross-product of all thirteen operations with both cuts, `mandatoryFaultAction = none`, and `faultTiming = none`, plus exactly fourteen required fault rows—one each for `deleteDatabase | deleteWAL | deleteSHM | replacePartialFamily | replaceStaleFamily | substituteWrongKeyEpoch | regressAnchorFloor | deleteKeychainAnchor | dropSQLiteReply | dropK3Reply | raceSecondCAS | corruptQuarantineMember | expireRecoveryLease | protectedDataUnavailable`—at their schema-fixed legal initial state/cut, for exact cardinality 40.

The timing map is exact: `dropSQLiteReply` and `dropK3Reply` are only `atDurableCommitBeforeReply`; the mechanism proves the commit, suppresses delivery, and reaches a live kill barrier before caller observation. `raceSecondCAS` is only `whileProcessAlive` and requires two independently identified live contenders plus one exact winner/loser outcome before the barrier. Every file/family/key/floor/corruption/lease action is only `beforeRecoveryOpen`. After the crash victim is proven dead, the controller relaunches the same signed lab app into a challenge-bound, one-shot fault-bootstrap entry point that is structurally unable to construct or open the production store; that entry point alone has the app-container and nonshared-Keychain entitlement needed to perform the exact mutation, emits a mutation receipt bound to before/after physical digests, and blocks. The controller proves that bootstrap PID alive, force-terminates it, proves it dead, and only then performs the ordinary recovery relaunch. The macOS/controller process never claims direct access to the iOS app's nonshared Keychain item. No action can substitute another timing. Every row uses a fresh challenge/run ID and has an exact terminal `resume | promote | clearPending | queryReconcile | quarantine | denyUnavailable | recoveryComplete`; the controller cannot downgrade a required fault to `none`. `quarantineInstall` always moves the DB/WAL/SHM family together.

`protectedDataUnavailable` is only `afterRebootBeforeFirstUnlock`, never an ordinary lock-screen checkpoint. The chosen production classes—Keychain `AfterFirstUnlockThisDeviceOnly` and files `completeUntilFirstUserAuthentication`—normally remain available after the first unlock of a boot, so a passing row requires a schema-frozen real-device sequence: stage the challenge, physically reboot, prove a changed boot identity and that first unlock has not occurred, then make a controlled challenge-bound launch/open observation before unlock. A pre-implementation `devicectl`/iOS-27 feasibility spike must prove that the selected signed app can be launched or otherwise independently observed in that state and emits a separate content-free `ArtifactMeshProtectedDataFeasibilityReceipt` with exact status `exercisable | blockedPlatformUnexercisable`. That receipt is gate evidence, not a matrix row or `expectedReopenDisposition`. If status is blocked, the existing 40-row `protectedDataUnavailable` row keeps its expected terminal `denyUnavailable` but remains explicitly unexecuted, so the physical recovery gate remains blocked; neither `blockedPlatformUnexercisable` nor a normal lock/unlock trace can be substituted for the row's terminal, and a different protection class requires a reviewed product-contract revision rather than a test-only success.

At each ordinary barrier the app records the scenario/cut digest and blocks without a normal-exit path. The controller first executes/proves any exact live or commit-before-reply action, proves the bound PID still alive at the barrier, force-terminates it, proves that PID dead and absence of an app-authored normal-terminal marker, runs the exact `beforeRecoveryOpen` bootstrap sequence when required, then relaunches the normal recovery entry point. The separate reboot-before-first-unlock path follows its own frozen phases and can only yield the required unavailable observation or the explicit blocked result above. The production trace must therefore express first create/reopen, pending anchor, SQLite FULL commit, WAL/SHM checkpoint, anchor/floor promotion, ordinary-put-before-K3-reference, quarantine, recovery lease, recovery floor update, and recovery completion before and after real process death, plus every fault above. A voluntary app exit, helper opening the production store, controller-written Keychain mutation, wrong fault timing, ordinary-lock substitution, skipped/duplicated/reordered/cross-scenario/reused cut, matrix cardinality other than 40, omitted/substituted fault, caller-written success, lost challenge, wrong PID/archive/device/container/boot identity, or non-live trace fails.

Candidate-index/archive/device-bound output is checked by `scripts/check_artifact_mesh_device_recovery.py`; its unit suite uses fixtures, but device-evidence mode requires that live app/controller trace and exact phase cardinalities. Until the production store path, structurally separate lab app, and physical evidence pass, a unit-test fake cannot move the ledger row out of `converging`.

Until the production-reachable SQLite store satisfies these points, the M-owner ledger status must be exactly `converging`, with the open durability/recovery conflicts and evidence paths recorded. Recovery remains inside `artifact.mesh`; this is not a new recovery component.

### 11.3 Binary rollback and schema compatibility

“Deploy the previous binary” is not a valid recovery statement after an incompatible store migration. The preferred release sequence is expand/contract: first ship a bridge release that can canonically read and write every old/new row and operation without losing N-only fields or semantics, then migrate under N only after exact `N → bridge/predecessor → N` replay and re-upgrade parity are certified. Otherwise the exact predecessor must prove canonical read/write round-trip and operation semantics over every post-N store/row, including preservation of unknown/new rows, or recovery must use a fenced snapshot/restore plus restoration epoch while preserving and replaying every authorized post-snapshot write. Mere open/read success is insufficient. Without one of those proofs, rollback is explicitly roll-forward-only and the UI/operator runbook must say so.

## 12. Clean Candidate Reconstruction

The approved reconstruction approach preserves existing useful work and avoids a giant mixed commit.

### 12.1 Preserve, do not destroy

Before reconstruction:

1. record HEAD, branch, worktree path, index tree, status, staged diff, unstaged diff, and untracked inventory;
2. preserve the dirty tree as forensic/source material;
3. do not reset, checkout-overwrite, delete, or normalize user work;
4. record which bytes came from HEAD, index, worktree, and untracked files; and
5. treat every prior “fixed” claim as unverified until its exact candidate bytes pass.

### 12.2 Reconstruction batches

These are candidate-reconstruction batches, not new architecture waves.

#### C0 — Clean base

- materialize a clean worktree from `20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0` or a later explicitly approved immutable base;
- verify zero dirty paths before import;
- record candidate-tree identity and toolchain; and
- before any `preW0` self-hosting, create the separately reviewed bootstrap commit containing only the immutable minimal `.github/workflows/qinao-wave-admission.yml`, `scripts/check_qinao_wave_admission.py`, verifier V0, every domain-gate module/contract that can be required from preW0 through W6, their unit/mutation corpora, and required pinned helper bytes; then complete the external admission-bootstrap ceremony in Section 12.2 by establishing the protected canonical ref policy, exact bundle digests, pinned third-party Action SHAs, repository/OIDC identity, and signed bootstrap attestation outside the candidate being judged.

#### C1 — Design correction only

- reconcile the canonical pipeline;
- insert L8 snapshot-bound lane-query/result production between L7/R0 eligibility and R1-R4 mechanisms, while retaining one final R6 Market;
- make the bounded `.turnStep/.internalProposal` → `BASEffectCausalPredecessorPayload` → governed effect-receipt continuation executable without a tool/effect owner, and add the separately typed `BASAuthorizedInputEffectPredecessorPayload` plus vNext `StatePrepareIntent.effectSourceRef`/K3 outbox reference required for explicit user/Host origin rather than overloading the model payload;
- correct Provider permit Artifact versus K3 row wording, and version the existing remote Provider descriptor/materialized-request/permit, K4 use/anchor, K3 pending/arm, and O/At contracts needed to bind the content-free credential version without adding a credential lease owner;
- correct 7/14 pure/known-result “direct commit” wording so direct means no external-effect wait,
  never omission of L13 StatePrepareIntent or K3 prepare with an absent outbox;
- correct L1 consumption versus K1 observation wording;
- correct initiative versus presentation cadence;
- add the same-owner, source-discriminated idle-workspace NextQuestion rules while retaining the existing post-answer variant;
- keep fixed/deterministic Studio previews reachable through non-answer mini-release, but keep Provider-backed generated Studio preview disabled until a separate legal policy-purpose/role/binding/source-wire amendment exists;
- restrict zero-Provider deterministic terminal-answer/final-publication completion to internal/non-visible outcomes and preserve the current K3-pinned, Provider-specific visible publication wire;
- freeze V1 production visibility to `bufferedUntilVerified`; keep incremental/provisional rows, receipts, permits, and batches unreachable pending a separate wire amendment;
- resolve signed raw-content Decision Gate wording;
- add the `BASContentIntakeProfilePayload` / `BASContentIntakeReceiptPayload` family under existing ingress; together with the authorized-input predecessor above these are the exact two new immutable value-contract families;
- freeze the complete learning partial order: causal-root grouping → split assignment → within-split derivation → evaluator/reward computation behind the firewall → hard-veto filtering → Pareto comparison → one-shot budgeted protected holdout → frozen-epoch/cohort shadow/canary → delayed field evidence/drift check → separately sealed adoption or rejection, with stage-tagged pre/post-holdout lineage and no future receipt reference;
- freeze the one K3 taint/correction/deletion/policy invalidation CAS and its closed eligibility fanout across active Attempts/Provider branches, pending release/publication/effect/state paths, every StateLake/cache/context/NextQuestion/evaluation/RSI projection, every learning candidate class, and already exposed non-runtime targets through the incumbent `production.cutover` fence/revoke/rollback/rebaseline path;
- freeze purpose-minimal Main/Sub envelopes, no peer calls/shared scratchpad, correlation-bucket evidence, and the rule that correlated Agent proposals never count as independent consensus;
- make root genesis/currentness, Session-selection CAS, `ContextContinuityManifest`, guest-only Recognition, and raw-string source gates explicit prerequisites rather than assumed declarations;
- correct semantic-snapshot currentness to K3-only, publication handoff ownership to the coordinator, neural `BASStateLakeReader` naming, and owner-private recovery wording;
- treat the standalone recovery draft as non-authoritative until folded into governed owner documents;
- preserve the existing hyphenated RSI wires—especially `needs-confirmation`—and correct Contracts/tests/fixtures plus `BASContextCompiler` binding language;
- add no production source.

#### C2 — Gate and provenance closure

- import owner/review/K4/W0 checker sources and tests as one coherent candidate/proposed-next slice, while the bootstrap/prior-admitted active gate modules independently judge this wave and candidate code cannot self-activate;
- import the exact review source and closure evidence;
- make every repository-resident proof projection one regular stage-0 mode-100644 evidence-candidate-index blob whose worktree bytes match, while keeping privacy-sensitive raw platform/device evidence in the governed encrypted external bundle below;
- atomically migrate the two current schema-v1 ledgers to the controlled schema-v2 target while preserving their exact 74 independently reproduced `QRM-*` plus 39 source-identified review identities, yielding exactly 113 closure children; schema, parser, runner constants, fixtures, receipts, tests, and candidate-tree bindings move together;
- adopt the target closed tagged disposition union `confirmed | duplicateOf | notReproduced | supersededBy`; every one of the 113 findings, regardless of disposition, binds non-empty regression and negative-mutation terminal sets, positive exact discovery/execution cardinality, the exact pre-evidence payload commit/tree/build identity, and its disposition-specific independent proof;
- require every confirmed/superseded true defect to bind its exact adopted repair bytes and owner evidence, with no unresolved known true defect crossing W1; a passing aggregate count without all 113 child receipts is not closure;
- keep `reported_external_count = 45` as `unverified_external_identity` outside `findings[]`, non-counting and without synthetic IDs; if an immutable itemized source is later supplied, its admission requires an atomic reviewed ledger/schema/runner/cardinality/receipt/test migration before any “all 45” claim;
- keep the 39-test remediation suite, the 39-source review ledger, the 74-QRM ledger, and the unverified external count as distinct evidence objects rather than conflating their numbers;
- add one new catalog row for `BASAuthorizedInputEffectPredecessorPayload` and new-version rows—not same-version edits—for `StatePrepareIntent`, the K3 effect outbox/prepare reference, and every remote-credential-affected existing contract named in Section 5: `BASPersistedOrganDescriptorPayload`, `BASMaterializedProviderRequestPayload`, `BASProviderEgressBoundaryPermit`, `BASCapabilityUseReceipt`, the K3 Provider-boundary row, `BASBoundaryAnchorReceipt`, `BASBoundaryArmReceipt`, and remote O/At. C1/C2 first resolve their existing canonical `contract_id` values from the Owner Ledger/registry; each vNext retains that ID and changes only `version`, while the authorized-input family receives one new stable ID. V1 remains decodable, future versions fail closed, and no raw-secret endpoint row is automatically converted into a credential slot;
- require exact non-empty E/A slices in the incumbent owners' own work packages: `semantics.layercell` derives/validates authorized-input causality, `artifact.mesh` supplies ordinary immutable storage, `state.k3-control-nucleus` owns the vNext source ref/outbox and Provider-boundary rows, `execution.plan-provider-router` owns descriptor/materialization shape, `sovereign.k4-durable-lifecycle` owns use/anchor facts, `effect.zone-c-saga` retains outbox-only dispatch/reconciliation, and `provider.package-boundary` owns transport injection/O/At. These slices all activate no later than the first applicable effect/remote cutover and create no owner;
- add current/canonical-round-trip, v1-backward, future-version, cross-family/type-tag substitution, source-artifact mismatch, two concurrent authorized-input intents, same-source replay, caller-predicted/gapped/reused ordinal/branch/instance, raw-secret-v1 quarantine, credential-version rotation/revocation, non-auth-byte mutation, and crash-boundary fixtures for those rows; the authorized-input gate proves exact trigger/plan/root/currentness/budget equality plus K3-only allocation/deduplication, and the remote gate proves exact M/PD/permit/use/anchor/arm/O/At binding;
- add the checked-in schemas `docs/superpowers/specs/qinao-production-reachability-v1.schema.json`, `docs/superpowers/specs/qinao-architecture-closure-report-v1.schema.json`, `docs/superpowers/specs/qinao-v2-quarantine-v1.schema.json`, and `docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json`;
- add `scripts/generate_qinao_production_reachability.py`, `scripts/check_qinao_production_reachability.py`, and `scripts/test_check_qinao_production_reachability.py`;
- add `scripts/generate_qinao_architecture_closure.py`, `scripts/check_qinao_architecture_closure.py`, and `scripts/test_check_qinao_architecture_closure.py`;
- bind and re-run—but do not modify in the same payload—the bootstrap-pinned `scripts/check_qinao_wave_admission.py`, its test/mutation corpus, and least-privilege `.github/workflows/qinao-wave-admission.yml`; any proposed upgrade follows the Vn/Vn+1 next-wave rule below; and
- run mutation tests proving zero candidates/tests/files; a deleted manifest/contract row; an unmanifested private/package/internal/public factory or entry point; a new alias/callback/protocol-erased/reflection/dynamic call; a conditional-compilation, scheme/configuration/SDK/architecture/feature-flag change; a vendored symbol newly linked into shipping; a selected remote dependency with missing/drifted `Package.resolved`; a generator that overwrites expected output before comparison; a caller-supplied/current-wave downgrade; a missing, reordered, forged, non-contiguous, or multi-file admission seal; a future contract declared/activated early; an active-through-wave contract missing; an inert schema prelude made reachable; introduction/activation wave or status drift; any declared/active expected-set mismatch; or a shrunk/renamed scan root cannot pass.

Persistent evidence uses one non-circular payload/evidence boundary. The immediate payload commit `Pw` contains all source, authority, schema, checker, test, fixture, and build-input bytes but no result that claims `Pw`'s enclosing tree. Gates execute against exactly `Pw`. Its single-child evidence commit `Cw` may change only the schema-frozen evidence allowlist—113 closure children/ledgers, privacy-clean gate/device attestations, privacy-clean selected-release projections, reachability/closure projections, external-bundle roots/coverage receipts, and their one evidence manifest—and every such leaf binds `Pw`'s existing commit/tree/build identity. The manifest in `Cw` lists every repository evidence leaf's indexed blob digest but not its own digest; the later wave-seal receipt binds the complete already-existing `Cw` tree. Verification against `Cw` proves `Cw = Pw + evidence-only diff`, reopens every repository leaf from the index, reruns deterministic checkers in compare-only mode without rewriting expected outputs, and proves shipping/source/authority bytes equal `Pw`. A leaf claiming `Cw` itself, an evidence commit containing source/authority/test changes, a missing/extra leaf, or a checker that overwrites evidence before comparison fails.

Raw release archives/Mach-O and CMS/signing chains, model packages, unredacted build plans, link maps, symbol/index stores, entitlements/provisioning profiles, device identifiers, container copies, `devicectl` output, and privacy-bearing physical traces never enter Git. This is the closed external-evidence class enum; an unknown/unclassified large, proprietary, path-bearing, credential-bearing, or identity-bearing class fails rather than defaulting into Git. Those classes may enter only the bootstrap-pinned `wave_admission_v1.build_evidence_storage_profile`, whose exact fields freeze provider/repository identity and region/endpoint class without credentials, client-side AEAD/chunking/content-address algorithm, KMS/key-custody principal and epoch, no-replace/versioning semantics, write principal, short-lived purpose-bound read-grant issuer, retention/destruction policy, audit/transparency root, bounded multipart crash/resume identity, and reopen/availability checks. Credentials remain external to repository bytes.

The verifier writes one encrypted immutable bundle under that profile; its creation manifest freezes bundle Merkle root, per-class coverage/cardinality, Pw/build/archive/device pseudonymous bindings, verifier/challenge identity, encryption/key-custody class, access purpose, retention policy/deadline, and one stable destruction-obligation ID—never a predicted future receipt. `Cw` stores only the privacy-clean signed attestation, root, coverage map, obligation ID, and verifier receipt. Before the deadline, authoritative recheck must obtain an independently authorized short-lived read grant, reopen the exact external bytes, recompute the root and every semantic check, avoid serializing raw identifiers into logs, and destroy temporary plaintext; unavailable, expired, root-mismatched, under-covered, or projection-only evidence fails.

At retention expiry the external service emits a separate append-only `EvidenceDestructionReceipt` that references the obligation ID, bundle root, exact object versions, key epoch, deletion results, and cryptographic key-erasure proof. It never rewrites the immutable creation manifest or historical admission attestation. After expiry/destruction, raw recheck and every certification depending on that bundle are explicitly invalid and require fresh evidence; the retained privacy-clean historical attestation proves only that the then-valid admission occurred, not perpetual production certification.

This profile is proposed proof storage, not assumed existing infrastructure and not a Qinao runtime owner or authority. C2 may reuse the controlled convergence plan's §6322 external-artifact/CMS mechanism only after a platform spike proves every field above against the actual provider; until then K4 and every physical-device gate requiring raw evidence remain blocked, while unrelated content-free gates may proceed. Thus no receipt hashes a tree containing itself and no privacy-sensitive proof is forced into the repository, while any positive physical-proof claim still binds a fully re-openable raw root.

Those four schemas constrain disposable build-time verification evidence only. They are not production wire/value-contract families, mutable owners, runtime policy inputs, or additions to the Owner Ledger.

The production-reachability generator is not fed a caller-selected source list. Its checked-in schema freezes these package roots exactly: `BehavioralAISubstrate/Package.swift`, `QinaoRuntimeSDK/Package.swift`, and `SampleHost/Package.swift`, then adds every Xcode project/workspace, XcodeGen source, configuration file, scheme, target, and product named by the Owner-Ledger `production.cutover` profiles. In the current tree that inventory must classify `BehavioralAISubstrate/DeviceTestApp/project.yml` and `BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj` explicitly; if BASDeviceTest is a shipping profile it is a mandatory graph root, and if it is lab-only the selected archive/link graph must prove that structural exclusion. The future ArtifactMeshDeviceLab project is likewise explicitly lab-classified rather than omitted by path. Every discovered `project.yml`, `.xcodeproj`, and `.xcworkspace` under a governed root is mapped to an authority-selected shipping profile or an exact archive/lab/evidence exclusion receipt; an unclassified project is failure.

The generator digest-binds every resolved project/package manifest/source root. For generated Xcode projects it regenerates into a temporary directory and proves canonical semantic equality with the indexed `.pbxproj`; neither the generator nor stale checked-in project may hide a target. A remote dependency reachable only from documentation/plugin/developer targets must be proved nonshipping by the authority-selected build graph; if any required shipping release resolves a remote dependency, a candidate-index-bound `Package.resolved` is mandatory, and its current absence fails rather than silently floating.

Each Git-resident selected-release projection freezes the privacy-clean canonical fields: Xcode/Swift toolchain, authority profile ID/version and exact scheme/product build target, configuration, SDK, architecture, deployment target, active compilation conditions/feature flags, package-resolution digest, normalized entitlement-key set/digests, archive/Mach-O/CDHash identities, and per-class external bundle roots/coverage. Raw archive/model/entitlement/profile/build-plan/link-map/index-store bytes remain external. The verifier reopens those bytes and deterministically traverses products, targets, declared source directories, transitive dependencies, private/package/internal/public constructors and factories, shipping Host compositions, and release entry points, then analyzes the exact release build's Swift AST/SIL/index and linked-symbol closure. Protocol erasure, generics, callbacks, ObjC selectors, reflection, dynamic lookup, or another indirect edge is either conservatively expanded to every compatible target or fails closed when unresolved.

Shipping status derives only from selected archive/product reachability and the transitive linked-symbol closure, never from a `Vendor/`, test-looking, or other directory name. A vendored Crypto/MLX/Transformers symbol linked into a shipping target remains shipping-reachable; a policy may exempt reviewed third-party internals from Qinao owner classification, but cannot erase them or their Qinao call boundary from the graph. Evidence, fixture, benchmark, and lab-only products are nonshipping only when the frozen release graph proves no archive path to them. The generator writes to a temporary path, canonicalizes, and byte-compares with the candidate-index manifest; it never overwrites the expected file before checking. A missing/renamed root or release graph, an unexpected package/product/target, an unclassified conditional compilation or indirect edge, or any difference between the independently derived actual entrypoint set and the indexed manifest fails before report generation.

Controlled-contract completeness is a separate cumulative, wave-aware exact-set gate. C1 specifies the authority delta, but the indivisible C1+C2 payload is what atomically moves the existing `docs/superpowers/specs/qinao-owner-ledger-v1.json` closed `schema_version` from 1 to 2 together with the exact-field constants, parser, and tests in `scripts/check_qinao_owner_ledger.py` / `scripts/test_check_qinao_owner_ledger.py`; no intermediate C1-only tree is admissible. The stable path/`ledger_id` remain the sole Owner Ledger. Schema v2 adds exactly four machine sections without creating another authority: `governing_addenda_v1`, `controlled_contract_catalog_v1`, `shipping_release_profiles_v1`, and `wave_admission_v1`.

The existing `controlled_documents` array remains exact-cardinality seven; each row gains stable `document_id` and candidate-byte `sha256` fields while retaining its exact path/required/forbidden terms. `governing_addenda_v1` has exact cardinality four and rows exactly `{document_id, path, sha256}` for the 2026-07-17, 2026-07-19, 2026-07-22, and governed-learning 2026-07-23 addenda. Across the two arrays, document IDs and paths are unique and the class cardinalities remain 7+4; the non-authoritative correction and recovery companion cannot enter either array. This gives every one of the eleven documents a candidate-index-bound digest slot without pretending the four addenda belong to `controlled_documents`.

Each canonical, uniquely sorted `controlled_contract_catalog_v1` row contains exactly `contract_id`, `version`, `owner_id`, `declaration_path`, `declaration_symbol`, `registry_id`, `status`, `introduction_wave`, `activation_wave`, `schema_only_prelude_allowed`, and non-empty `authority_refs`; its row ID is the canonical pair `(contract_id, version)`, not another field. Wave values are exactly `preW0 | W0 | W1 | W2 | W3 | W4 | W5 | W6`, except that `activation_wave` may additionally be `never`. Contract lifecycle status is deliberately separate from an owner's implementation-health status and is exactly `planned | approved_missing | declared_inert | active | retired`.

Each authority ref is exactly one `{document_id, required_term_id}` pair. Each of the eleven mapped documents contains exactly one canonical single-line comment with closed JSON grammar `<!-- qinao-contract-catalog-refs-v1:[{"contract_id":"…","version":"…","required_term_id":"…"}] -->`; entries are lexicographically sorted and duplicate-free. Each named term appears exactly once in the same document as the exact anchor `<!-- qinao-required-term-v1:<required_term_id> -->`, where the ID matches `[a-z0-9][a-z0-9._-]{0,127}`. The containing candidate-index path supplies `document_id` through the immutable 7+4 map. The checker therefore forms exact quadruples `(contract_id, version, document_id, required_term_id)` from both sides, proves set/cardinality equality, proves every anchor unique and present, and proves the union of referenced row IDs equals the complete Owner-Ledger catalog.

The catalog at the `preW0` seal freezes every baseline row field except `status`. Any declaration path/symbol, registry ID, owner, schema-prelude flag, introduction/activation wave, or authority-ref change requires a new `(contract_id, version)` row and preserves the old row; an authority-ref set can never be silently expanded or shrunk in place. Status follows only the acyclic closed transitions: `planned → approved_missing` at a controlled planning seal no later than introduction; `planned | approved_missing → declared_inert` exactly at introduction when a prelude is allowed, introduction precedes activation, exact declaration/registry evidence passes, and production reachability is empty; `planned | approved_missing → active` exactly when introduction equals activation and the complete active evidence passes; `declared_inert → active` exactly at activation; and `active → retired`. Baseline rows may start at the stage proven by `preW0`, retired rows remain declared/decodable but production-unreachable, and no other transition edge, two-hop-in-one-seal sequence, or skip is legal. An `approved_missing` row whose introduction deadline has arrived does not satisfy `actualDeclared == expectedIntroducedThrough(W)` and blocks rather than laundering missing implementation as introduction. Every transition occurs at the checker-derived wave and binds its controlled amendment/gate receipt. Thus simultaneous catalog/comment/source shrinkage cannot redefine expected identity or reachability.

The actual declared set is independently derived from `BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`'s `BASEBrainSchemaGovernanceRegistry` plus the release-condition-aware declaration scan for every governed/versioned payload, receipt, permit, manifest, and owner wire. `shipping_release_profiles_v1` is owned only by the existing `production.cutover` row; every canonical row freezes `profile_id`, `version`, lifecycle `status`, `introduction_wave`, `activation_wave`, project/workspace path, an exact non-empty sorted `build_targets` array of `{scheme, product}`, configuration, SDK, architecture set, deployment target, compilation conditions, feature flags, entitlement-template paths, and package-resolution roots.

The `preW0` seal freezes the then-present baseline profile ID/version set and every row's non-status bytes. Rows are append-only; deletion, activation delay, path/product/configuration narrowing, or in-place replacement fails. Status follows only `planned → approved_missing`, `planned | approved_missing → active` exactly at the frozen activation wave with complete build/reachability evidence, and `active → retired`; baseline rows may start at their proven stage, every transition is checked against the prior canonical seal and derived wave, and a changed build-selection field requires a new version row while the old row remains. A later unique profile/version row can be appended only with a controlled `production.cutover` amendment; it never alters the frozen baseline set's rows. For each `profile_id` required active through derived wave `W`, exactly one version is active; a future family whose activation is after `W` has exactly zero active versions. Activating a replacement version and retiring its previously active version occur atomically in the same `Sw`. A fully retired family may have zero active versions only when the same controlled `production.cutover` amendment proves the family is no longer required and every former shipping entry point is removed or covered by another active profile; otherwise a gap, two active versions, or retirement without a simultaneously active replacement fails. The reachability generator obtains the authoritative active profile set only from these rows and scans the union of every active shipping product. A selected-release record is output evidence for one required profile/build and cannot choose, omit, narrow, delay, or override any selection input.

Both append-only tables use one explicit absent-row protocol after `preW0`; insertion is not silently treated as a lifecycle transition. At derived wave `W`, a new unique key must be covered by the wave's controlled amendment and may enter only as: `absent → planned` when its immutable `introduction_wave > W`; `absent → approved_missing` when `introduction_wave = W < activation_wave` (or, for a contract row, activation is `never`), noting that this state cannot satisfy a due declaration/active requirement; or `absent → active` when `introduction_wave = activation_wave = W` and all declaration/registry/reachability/build, authority-reference, and active-gate evidence already passes. A contract row alone may instead enter `declared_inert` when `introduction_wave = W < activation_wave`, `schema_only_prelude_allowed = true`, its exact declaration/registry evidence passes, and production reachability is empty. `retired` is never an insertion state. A row whose introduction is earlier than `W`, an illegal initial status, an absent-to-status skip outside these predicates, or a same-wave active insertion without the full active gate set fails. Once inserted, every non-status byte is immutable and only the table-specific transition graph above applies. Contract versions may coexist only when their controlled authority refs explicitly require multi-version production reachability; otherwise replacement activation and prior-version retirement are one seal operation just as for a release profile.

At the checker-derived wave `W`, `actualDeclared == expectedIntroducedThrough(W)` and the union `actualProductionReachable == expectedActiveThrough(W)`, including catalogued baseline-existing contracts and excluding only rows whose legal `active → retired` transition has occurred. A schema-only prelude is legal only at or after its frozen introduction wave, remains inert and shipping-unreachable, and cannot count as active. Later planned/approved-missing contracts remain listed in the full ArchitectureClosureReport with their future wave/status but are not required to exist early. A future contract appearing early, an active-through-W contract missing, an introduced declaration unregistered, an inert prelude becoming reachable, wave/status drift, extra/duplicate ID/type, an authority-selected shipping profile/product omitted, or a contract appearing only in the report fails. Reachability manifests, selected-release records, and ArchitectureClosureReport carry no owner, policy, expected-contract, supplied-wave/status, profile-selection, or completion decisions.

`W` is never a CLI argument, environment value, caller branch/worktree name, candidate-manifest field, or caller assertion. The immutable wave order comes from the Owner Ledger's existing exact `implementation_work_packages` sequence `W0…W6`. Before `preW0`, a two-operator repository-administration ceremony establishes a bootstrap commit/bundle outside the candidate under review: an immutable minimal admission runner, verifier V0 plus mutation corpus, a complete stable gate catalog whose rows are exactly `{gate_id, gate_contract_digest, bootstrap_module_bundle_digest, bootstrap_corpus_digest}`, every corresponding through-W6 domain-gate executable module and positive/negative/mutation corpus whether first required now or in a later wave, third-party Actions pinned by full commit SHA, canonical repository/OIDC/workflow identities, protected ref `refs/heads/qinao-admitted`, expected branch-protection policy digest, and a signed Git-host/OIDC bootstrap attestation in the provider's authenticated attestation/transparency store. The catalog covers every gate that can be required through W6 and supplies its fail-closed executable module from genesis; no later gate depends on a not-yet-admitted proposal for first activation. Candidate bytes cannot create, replace, or sign that root.

`wave_admission_v1` must byte-match that external bootstrap attestation and freezes the canonical repository identity/ref, bootstrap commit/verifier/runner/action digests, bootstrap gate catalog, the bootstrap commit as the canonical ref's exact initial OID, exact order `preW0,W0…W6`, expected protection-policy digest, exact `required_gates_by_wave` whose uniquely sorted entries are `{gate_id, gate_contract_digest}` and must match the catalog, the closed `build_evidence_storage_profile` above, and literal `force_updates_forbidden = true` / `deletion_forbidden = true`; after `preW0`, every field is immutable. The fixed runner treats `Pw/Cw/Sw`, including every checker/test/workflow byte in them, only as untrusted data or a proposed-next module. It loads the active verifier and every active domain-gate module exclusively from the prior finalized admission tuple—or the bootstrap bundle for `preW0`—and independently executes those modules over `Pw`.

The activation function is closed and has no mutable-ledger or same-wave fallback:

```text
activeVerifier(preW0) = bootstrap.verifierV0
activeVerifier(W) = predecessor.proposedNextVerifier ?? predecessor.activeVerifier
activeGateModule(g, preW0) = bootstrap.activeGateModules[g]
activeGateModule(g, W) = predecessor.proposedNextGateModules[g] ?? predecessor.activeGateModules[g]
```

Here `W` in the latter two equations is exactly `W0…W6`, and `predecessor` means the prior tuple `canonical ref + Sw receipt + valid finalized external admission attestation`, never a bare commit, current Owner Ledger row, candidate manifest, or current `Pw` executable. A verifier/workflow/domain-checker change inside `Pw` cannot judge its own wave. A proposed verifier Vn+1 or proposed gate module Gn+1 must pass the currently active verifier's packaging/signature checks, the immutable gate-contract corpus, the complete positive/negative/mutation corpus, and old/new differential execution. It may be recorded only as a proposed-next digest and becomes loadable only for the next wave after both `canonical ref = Sw` and Sw's external admission attestation are valid. Gate contracts/corpora and the minimal v1 runner/action/root cannot be weakened or replaced during `preW0…W6`; a semantic contract change or suspected compromise blocks admission. Recovery requires a separately governed append-only `admission_epoch_v2` with a new protected ref and dual-operator transition attestation from the last valid v1 seal—an amendment this document does not authorize—never in-place v1 mutation.

Authoritative admission mode takes no repository/ref/policy/verifier/wave value from the candidate, resolves the protected ref and current admission attestation fresh, verifies live repository/workflow/OIDC identity and branch-protection state, then derives the highest contiguous seal from canonical ancestry. An offline/local run may report only `preflight`, never `admitted`.

Regular stage-0 seal receipts live only at `docs/superpowers/evidence/qinao-wave-admission/preW0.json` and then `W0.json…W6.json`. A receipt contains exactly `schema_version`, `receipt_id`, `admitted_wave`, `predecessor_wave`, `predecessor_receipt_blob_digest`, `predecessor_seal_commit_oid`, `predecessor_admission_attestation_digest`, `predecessor_admission_chain_digest`, `payload_commit_oid`, `payload_tree_oid`, `evidence_candidate_commit_oid`, `evidence_candidate_tree_oid`, `authority_bundle_digest`, `owner_ledger_digest`, `controlled_contract_catalog_digest`, sorted exact-set `selected_release_build_identities` entries `{profile_id, profile_version, scheme, product, build_identity, output_projection_digest, external_bundle_root}`, sorted complete-catalog `active_gate_module_bundles` entries `{gate_id, gate_contract_digest, module_bundle_digest, corpus_digest}`, sorted zero-or-more `proposed_next_gate_module_bundles` entries `{gate_id, gate_contract_digest, module_bundle_digest, corpus_digest}`, sorted exact-set `gate_receipts` entries `{gate_id, gate_contract_digest, active_module_bundle_digest, input_payload_commit_oid, input_payload_tree_oid, result, evidence_blob_digest}`, `active_verifier_bundle_digest`, nullable `proposed_next_verifier_bundle_digest`, `gate_result`, and `created_at`. The selected-release identity set/cardinality equals the union of every `build_targets` entry in every Owner-Ledger profile active at the derived wave.

Every active-module entry must byte-equal the activation function above; every proposal names a catalogued gate, preserves its immutable contract/corpus digests, and has the active-verifier differential receipt required above. Each `gate_receipts` set/cardinality equals independently loaded `required_gates_by_wave[derived_wave]`; its contract digest matches that required row, its active-module digest matches `active_gate_module_bundles`, both input OIDs equal the receipt's exact `Pw`, and `result` is exactly `passed`. `gate_result` is exactly `passed`; an opaque digest, correct gate ID with a substituted contract/module, or result over any tree other than `Pw` is insufficient. The `preW0` receipt alone uses null predecessor receipt/seal/attestation fields, a 64-zero predecessor-chain digest, and bootstrap-derived active verifier/module entries while binding the clean C1/C2 payload/evidence pair before C3/K4 close W0. Every later receipt binds the exact prior receipt/seal/admission attestation, recomputed predecessor-chain digest, and the predecessor-derived active verifier/module map.

Admission is a non-circular payload/evidence/seal-plus-CAS protocol. First, the canonical active verifier invokes the canonical predecessor-derived active module for each exact required gate over clean payload commit/tree `Pw`, which descends from the current protected seal—or the bootstrap initial OID for `preW0`. Candidate checker/tests may run as diagnostics and proposed-next inputs, but their outputs cannot supply an authoritative current-wave result. The exact one-parent evidence child `Cw` then passes evidence-only/index/compare checks. Only then may `Sw` be created with exactly one parent, `Cw`; `Sw` differs from `Cw` by exactly the one new receipt at that wave's fixed path, and the receipt binds both existing `Pw` and `Cw` commit/tree OIDs. The same rule seals `preW0`.

Immediately before update, the protected runner obtains a fresh authenticated live-protection observation and compares it with the frozen expected policy. It creates an external immutable `AdmissionIntent` whose idempotency key is the canonical digest of repository/ref, derived wave, prior OID, `Sw` OID, receipt blob digest, active-verifier digest, and live-policy observation. It then performs one ordinary fast-forward compare-and-swap whose expected old OID is the prior canonical seal and whose new OID is `Sw`. After CAS, the Git host/OIDC issuer finalizes that same intent as an external signed admission attestation containing repository/ref, derived wave, run/subject, runner/workflow/action/active-verifier digests, live protection-policy digest, prior/new OIDs, receipt blob digest, CAS transaction/result, intent ID, and timestamp. Only the tuple `canonical ref = Sw + valid finalized admission attestation` is admitted.

Finalization is crash-recoverable and no-replace. On retry, the runner first queries the canonical ref, immutable intent, and authenticated Git-host CAS audit. If `ref = prior` and audit proves no CAS occurred, it retries the same intent while its observation is fresh; if that observation expired, it may create one immutable superseding intent that names `predecessorIntentID`, keeps repository/wave/prior/Sw/receipt/verifier bytes identical, binds a fresh observation, and marks the old intent superseded. An unknown/possibly-started CAS must be resolved from the host audit before supersession. If `ref = Sw` and audit proves the same intent's successful transaction, recovery may only idempotently publish the byte-identical missing attestation; an existing identical attestation returns it. Any other ref, transaction, intent lineage, or attestation quarantines admission for operator reconciliation. While `ref = Sw` lacks its valid finalized attestation, the ref is `pendingAdmission`: no next-wave derivation or verifier activation is legal, but deterministic finalize recovery remains allowed. A competing successor loses the CAS; a missing/stale/mismatched live observation or unrecoverable attestation leaves admission explicitly fail-closed for operator reconciliation and never silently advances authority.

The checked-in selected-release projection set stored in `Cw` is generated for receipt-bound `Pw`: it has exactly one output per active Owner-Ledger `{profile_id, version, scheme, product}` build target, and each output receives the same `derived_wave` plus `predecessor_admission_chain_digest` only from that checker result. The set is exact-cardinality/byte-compared and cannot supply either field or omit a target. `Sw` recheck reads both receipt-bound trees, proves `Cw = Pw + evidence-only diff`, revalidates every projection/evidence leaf against `Pw`, proves `Sw = Cw + one receipt`, proves the protected ref equals `Sw`, and verifies the external admission attestation. The through-admission digest is never written into `Pw`, `Cw`, or `Sw`: after attestation the checker computes `SHA256("qinao-wave-admission-chain-v1\\0" || predecessorDigest || "\\0" || SwOID || "\\0" || receiptBlobSHA256 || "\\0" || admissionAttestationSHA256)` over lowercase ASCII hex and emits it only as the next candidate's `predecessor_admission_chain_digest`. This closes evidence, seal, and post-CAS attestation self-reference with one canonical preimage.

Only after deriving the successor from the protected ref does the active verifier inventory every blob changed since that seal and require exact coverage by the wave's controlled required-term refs plus its non-empty M/E/A/evidence manifests; those manifests state the already-derived `workWave` and cannot select it. Missing/ambiguous ancestry, a non-contiguous chain, receipt rewriting, an extra parent/seal byte, incomplete gate-ID set, candidate-self-selected verifier, uncovered/cross-wave change, stale/CAS-losing fork, missing live attestation, or an attempt after W6 fails closed. Production reachability and ArchitectureClosureReport consume the verified result, not an input `W`. The schema, local receipts, external attestations, and protected-ref history are non-authoritative release evidence: they prove satisfaction/order but cannot add a work package, owner, contract, status, exception, profile, or route.

#### C3 — W0 source freezes

- import only verified W0 production safety changes and their discovered tests;
- freeze free Persona injection, unsafe memory self-population, same-call Provider fallback, synthetic execution success, raw/unbounded public streaming and stream-then-regenerate, direct effects, raw-string Session/App-Agent continuity, false AFM certification/accounting, argv/raw-header secrets, old causal self-promotion, and every named split-brain path;
- generate and check one transitive production-reachability manifest covering every legacy learning mechanism in governed-learning §4.12, including `BASUpdateTicketLifecycleCoordinator`, its HostKit construction, `BASMemorySleepConsolidationPass`, `BASTrainingDataExporter`, and evolution-governance hard-coded safety decisions;
- freeze direct promotion/export/write/distill/adopt mouths, not merely their newest call sites;
- gate the complete causal-root→split→within-split→evaluator-firewall→hard-veto→Pareto→protected-holdout→cohort/canary→delayed-field/drift→separately-sealed-adoption order, stage-tagged holdout lineage, one K3 invalidation CAS with the complete runtime-boundary/projection/learning/exposure fanout, and typed Main/Sub communication/correlation rules with positive and per-field negative fixtures;
- preserve compatibility only behind explicit test/lab/shadow seams;
- recapture append-only W0 receipts against the exact clean candidate index.

#### C4 — K4 platform proof

- first repair `scripts/check_k4_platform_proof.py` and `scripts/test_check_k4_platform_proof.py` under RED/GREEN tests so production mode rejects marker-shaped source, fixture, JSON/plist, copied log, caller nonce/challenge, offline trace, wrong archive/device, and the external ExecutionGate fiction;
- run `python3 -m unittest -v scripts.test_check_k4_platform_proof` with a non-zero discovered-test assertion before importing any proof; the direct-file invocation is not authoritative because its current package import fails;
- make the production verifier generate its unpredictable challenge only after binding the actual archive and physical device, drive the live structured `devicectl` sequence itself, and digest-bind its raw outputs and response challenge before proof import;
- import only approved proof bytes produced from the actual signed archive by the selected release toolchain/profile/device run, including Mach-O/CDHash, embedded-profile/entitlement, structured `devicectl`, and fresh verifier-challenge-bound device traces;
- production proof remains absent rather than copying the preliminary blocked spike;
- reject the synthetic fixture proof mode and the unimplemented external ExecutionGate prerequisite;
- close W0 only when both `qinao-silicon-w0-open-set-v1` and `qinao-runtime-w0-open-set-v1` have their required successor and the K4 gate passes.

#### C5 — Resume W1-W6

- begin W1 with an explicit Artifact Mesh Task 0 before any downstream W1 consumer: repair the existing M/CreateGate allowlisted `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`, `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`, and `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`; do not extend or resubmit that three-path M manifest;
- add exactly four singular W1 E/A ExtensionSlices under the existing `artifact.mesh` owner with classification fixed by this authority text rather than chosen by the manifest: internal port/record in `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift` is `E`; sole shipping adapter in `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift` is `A`; mechanism-only factory in `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift` is `A`; and the exact factory-call seam in `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift` is `A`. Task 0 submits its own payload-index-bound, non-empty `ea_extensions` manifest with exact cardinality four. Each slice freezes `introductionWave = W1`, `workWave = W1`, its one path/symbol, and prerequisites consisting of the corrected `converging` ledger/evidence digests, iOS-27 floor, and Section 11.2 contract. Historical creation evidence is bound honestly as `docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json`, `artifact-mesh--schema.json`, `artifact-mesh--sqlite-store.json`, and `docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json`; these retrospective receipts/correction are not relabeled original atomic CreateGate evidence. The assembly slices cannot select release routes/profiles/policy and therefore do not borrow W6 `production.cutover`;
- modify `SampleHost/Package.swift` to exclude the entire `ArtifactMeshDeviceLab` directory, then add the independent installable iOS app project/scheme, App/entitlements/Probe files, and closed phase protocol named in Section 11.2; add the exact 40-row `docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json`, `scripts/run_artifact_mesh_device_recovery.py`, `scripts/check_artifact_mesh_device_recovery.py`, and `scripts/test_check_artifact_mesh_device_recovery.py` as verification mechanisms with no runtime authority or Owner-Ledger row. The controller must archive the lab app with `xcodebuild archive -project SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj -scheme ArtifactMeshDeviceLab -destination generic/platform=iOS`, then drive the real device; selected-release reachability must prove the lab product, compile condition, and fault hooks absent from the shipping archive;
- close the Section 11.2 state-machine/crash contract in `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`, `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift`, and `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoArtifactMeshAssemblyTests.swift`; run `python3 scripts/run_nonempty_swift_filter.py --package-path BehavioralAISubstrate --filter BASArtifactStoreTests --require-suite BASArtifactStoreTests`, `python3 scripts/run_nonempty_swift_filter.py --package-path BehavioralAISubstrate --filter BASArtifactMeshKeychainAnchorTests --require-suite BASArtifactMeshKeychainAnchorTests`, `python3 scripts/run_nonempty_swift_filter.py --package-path QinaoRuntimeSDK --filter QinaoArtifactMeshAssemblyTests --require-suite QinaoArtifactMeshAssemblyTests`, and `python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery`; then require the archive/device-bound production recovery probe rather than its fixture mode;
- the controlled ledger transition is explicit: C1/C2 correct the false `implemented` claim to `converging`; only a passing Task-0 candidate may move `artifact.mesh` from `converging` back to `implemented`. No other W1 task may compile against, claim crash safety from, or consume the repaired store before that receipt;
- after Task 0, execute the existing owner-led work-package order;
- each wave starts from the current protected seal and uses the exact clean `Pw → evidence-only Cw → receipt-only Sw → canonical-ref CAS` lineage;
- executable gates/build/device runs bind `Pw`; persistent receipts/projections in `Cw` bind `Pw`; the sole `Sw` receipt binds both, and no evidence leaf claims its own enclosing tree;
- a later wave never supplies an API or behavior required for an earlier wave to compile or pass;
- each durable owner's recovery contract closes in its owning wave before downstream references can claim crash safety; and
- release certification proves expand/contract or the exact declared roll-forward-only disposition before any binary rollback claim.

### 12.3 Rejected reconstruction modes

- one giant commit containing all staged, unstaged, and untracked bytes;
- marking the current worktree clean merely by staging everything;
- using a filesystem proof not present in the candidate index;
- copying checker outputs without their exact source/test/fixture bytes;
- claiming the reported 45 findings equal another reproduced set without a stable identity map;
- rewriting historical receipts or logs to match current behavior;
- using branch names or worktree directory names as candidate identity; or
- rebuilding existing valid mechanisms from scratch instead of importing and verifying their exact changes.

## 13. Governing-Addendum and Controlled-Document Delta Map

Atomic authority convergence must apply at least these deltas across the four governing addenda and the exact seven Owner-Ledger-controlled documents in one reviewed unit. The table also names companion/domain corrections that must be folded into those authorities; no row changes either set's membership:

| Document/domain | Required correction |
|---|---|
| 2026-07-23 learning design | Replace only online turn shorthand with Section 3; preserve the full causal-root→split→within-split order, evaluator firewall, hard veto/Pareto, protected holdout, policy epochs/cohorts, all-clean ancestry, drift invalidation, and taint fanout; require Experience-or-explicit-ineligible evidence and a transitive §4.12 legacy-mouth retirement manifest; change initiative cadence to presentation cadence; preserve hyphenated RSI wires; keep Web/attachment material inside contamination cleaning; state that V1 visibility is buffered-only |
| 2026-07-14 architecture design | Distinguish Artifact Mesh permit creation from K3 row installation; insert L8 snapshot-bound LaneQuery/LaneResult production without creating a second Market; make K3 the sole semantic-snapshot currentness head; preserve the bounded model `BASEffectCausalPredecessorPayload` path and fulfill its explicit-host/user requirement with the separate typed `BASAuthorizedInputEffectPredecessorPayload` plus vNext StatePrepare/outbox source ref; add the universal intake family; correct publication handoff ownership and neural StateLake naming; retain nonoptional L13/K3 prepare; freeze V1 buffered-only |
| 2026-07-17 K3 addendum | Preserve A→M, ordinary-put permit → K3 prepare → K4 anchor → K3 arm → fresh Q/handoff, exact R and Vrow→V→Y wires; add the vNext two-family effect-source ref and exact effect-receipt/currentness/taint-invalidation CAS bindings; version the remote M/PD/permit/pending/arm bindings for content-free exact credential-version identity; keep semantic snapshot attachment K3-only and incremental structures unreachable |
| 2026-07-19 Agent/context design | Bind State Compiler/Context Budget Allocator to the sole `BASContextCompiler`; retain signed raw-content Decision Gate precedence; preserve and extend the existing `state.snapshot-contracts`-owned, references-only `ContextContinuityManifest`; add adversarial Agent-envelope/correlation rules, model-context adaptation, and Content Intake consumption; preserve hyphenated RSI wires and complete Information Sufficiency/currentness tuples |
| 2026-07-22 App Agent design | Make root genesis/reopen/currentness, creation/quota activation, Session-selection CAS, switch/handoff, deletion fences, and raw-string source gates executable; add idle NextQuestion source and complete score/digest/duplicate/expiry/render evidence; retain deterministic Studio limits; freeze the Recognition completion union and exact cleaning/taint fanout; restrict deterministic final publication and incremental visibility |
| `qinao-authority-corruption-recovery-v1.md` companion | Remove standalone normative authority; fold exact owner-private lifecycle/floor/approval/lease/quarantine rules into the existing domain documents and Owner Ledger. Keep operator reactivation blocked until the planned K4/trust first wires prove a non-circular recovery purpose, principal, key/floor custody, and verifier path; forbid a global registry/database/signer/manager |
| Contracts plan | Freeze the exact two new immutable families—intake profile/receipt and authorized-input effect predecessor—plus vNext StatePrepare/outbox source ref; freeze continuity/model-effect-predecessor values, remote credential-binding vNext rows, currentness ownership, existing hyphenated RSI spellings, owner-private recovery schemas, buffered-only reachability, current/backward/future/mutation fixtures, and exact reuse/create classifications; create no mutable owner |
| Semantic plan | Enforce L7 requirements → R0 → L8 snapshot-bound LaneQuery/LaneResult → R1-R4 → R5 → one R6 Market; query read-only/no self-pop; K3-only semantic currentness; Web/attachment untrusted handling; taint fanout; one context compiler |
| Silicon plan | Enforce one physical call per branch, bounded Attempt DAG, `executeAtMostOnce`, Provider-specific compilation/cache scope, host-only accelerator-heavy V1, foreground fairness under existing K1 admission, honest AFM capability/accounting, evidence-selected Core AI, nonsecret remote M plus exact credential-version binding/post-handoff resolution, neural-reader rename, and one-invocation buffered output |
| Sovereign plan | Preserve exact buffered publication/effect/state/Web paths, both separately typed internalProposal/model and authorized-input causality paths through one vNext StatePrepare/outbox source ref, nonoptional state prepare→stage→seal→activate, K3 source pin, coordinator-owned sink handoff, and permit/row separation; version K4 use/anchor and K3 arm bindings for remote credential identity; add owner-private recovery and actual K4 archive/device proof; reject incremental and deterministic-publication bypasses |
| Runtime plan | Add root/Session activation, continuity recovery, reasoning/Information Sufficiency, intake, NextQuestion evidence, recognition union, §4.12 legacy reachability, stream retirement, schema-compatible rollback, Artifact Mesh crash recovery, actual K4 proof, and conditional 40/30 chain-of-custody/replicate cases |
| Cautious Web-search reuse | Reuse mapped L7/L8 evidence admission, the separate authorized-input effect predecessor for explicit deterministic search, the intake profile/receipt family for returned content, `effect.zone-c-saga`, and one certified Adapter profile; add query disclosure, untrusted return, injection, citation span/time, cancellation, unknown dispatch, and crash fixtures; create no search or attachment owner |
| Convergence master | Order indivisible C1/C2, then C3/K4 before W1; require Artifact Mesh W1 Task 0 before any other W1 consumer; require root/Session and legacy-mouth gates; freeze the three-commit `Pw → Cw → Sw` plus protected canonical-ref CAS/admission-attestation protocol, external verifier bootstrap/N+1 upgrade, no-caller-wave rule, and payload-versus-private-evidence boundary; make rollback mode explicit |
| Owner Ledger | Update digests/required terms and exact reuse/extension classifications; correct semantic currentness and publication wording; add owner-private recovery facts without a new owner; downgrade Artifact Mesh until physical recovery/durability closes; record both new immutable families and every named vNext effect/remote-credential contract under existing owners/Artifact Mesh; add the closed 4-addendum digest map, `controlled_contract_catalog_v1`, append-only `shipping_release_profiles_v1`, and externally anchored `wave_admission_v1` while keeping controlled-document and owner cardinalities unchanged |

The separate `2026-07-19` CoreAI/Agent controlled-document convergence plan remains a spec-pinned, non-authoritative execution artifact—not a fifth governing addendum or eighth controlled document. Its required sequence is `spec-only authoritative convergence → revise and pin the non-authoritative plan to the exact adopted digests → W0 atomic merge`. Before it can drive work, that revision must reverse its unconditional durable-raw-content row at line 6837 and every dependent task/test: content-free is the default, encrypted content materialization requires the current signed exact-purpose Decision Gate, and required-term plus negative-reachability checks reject unconditional persistence.

No single prose edit is sufficient. Tests, fixtures, checkers, Owner Ledger required terms, and document digests must move with the controlled correction.

The build must generate `ArchitectureClosureReport` through the C2 generator from authoritative inputs plus the independently derived production graph, never hand-edit it. For every controlled contract and production capability it maps: immutable contract/schema, authority owner, mutable writer, storage owner, recovery owner/rule, production constructors/entry points, allowed and forbidden reachability, positive/non-vacuous tests, mutation/crash terminals, release gate, and current status with source digests. The generator may copy owner/status/policy only from the Owner Ledger and controlled documents; the reachability manifest cannot supply those decisions. A missing field, unknown production entry point, manifest/actual exact-set or cardinality mismatch, unclassified writer, unbound recovery path, or claimed-implemented capability with no passing production reachability fails the checker. The report itself is a disposable projection and cannot change status, authorize a path, or amend the Owner Ledger.

## 14. Verification and Fault Matrix

### 14.1 Candidate integrity

Before any positive claim:

- `git status --short` is empty at each evaluated payload/evidence/seal tree;
- payload-index/worktree source/authority/checker/test/fixture bytes and evidence-index/worktree proof bytes are equal at their declared boundary;
- every evidence leaf is indexed in `Cw`, binds exact `Pw`, and is transitively closed by the sole receipt in `Sw`; no leaf claims the tree containing itself;
- no proof path is a symlink, executable mode, non-stage-zero entry, ignored file, or external unbound directory;
- authoritative wave admission resolves the protected canonical ref fresh, uniquely derives either its exact seal recheck or one immediate successor, and admits only a successful fast-forward compare-and-swap;
- governing-addendum, controlled-document, Owner Ledger, catalog, release-profile, and `Pw` digests match;
- the generated ArchitectureClosureReport in `Cw` binds those same `Pw` digests and enumerates every authority-selected shipping constructor/entry point; and
- release archive, model packages, signatures/profiles/entitlements, device evidence, `Pw`, `Cw`, and `Sw` bind the one declared build/evidence/seal lineage.

### 14.2 Required static gates

The clean candidate must run these local diagnostic/preflight commands from the convergence master, including:

```text
check_xcode27_toolchain
check-ios27-floor
check_qinao_owner_ledger + unit suite
run_nonempty_swift_filter + unit suite
check_w0_expected_open_set + unit suite
check_qinao_review_candidate + unit suite
test_qinao_review_closure
test_qinao_plan_remediation
check_k4_platform_proof + unit suite
python3 scripts/check_artifact_mesh_device_recovery.py
python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery
python3 scripts/check_qinao_wave_admission.py --mode preflight
python3 scripts/test_check_qinao_wave_admission.py -v
python3 scripts/generate_qinao_production_reachability.py
python3 scripts/check_qinao_production_reachability.py
python3 scripts/test_check_qinao_production_reachability.py -v
python3 scripts/generate_qinao_architecture_closure.py
python3 scripts/check_qinao_architecture_closure.py
python3 scripts/test_check_qinao_architecture_closure.py -v
```

Every command must report non-zero candidates/tests/files where applicable. Exit 1 or 2 is failure, not “no match.” These candidate-tree commands remain untrusted preflight even when they pass. Local preflight can never claim admission; the protected bootstrap-pinned `.github/workflows/qinao-wave-admission.yml` runner invokes the predecessor-derived active verifier and active domain-gate modules over the exact `Pw`, and only those receipts plus its successful canonical-ref CAS admit the wave.

Every classification-`M` first production create must pass the Owner-Ledger checker with a payload-index-bound, non-empty `--candidate-manifest`; running only ledger shape/iOS-floor mode is not a CreateGate. Every E/A production extension/adaptation submits a payload-index-bound, non-empty `ea_extensions` manifest for its checker-derived implementation wave, with the exact singular ExtensionSlice set/cardinality, one incumbent owner/path/symbol and one `E | A` classification per slice, frozen `introductionWave`/`workWave`/prerequisites, and no multi-owner/cross-wave envelope. A manifest cannot supply `W`, and a later manifest cannot satisfy an earlier wave. The intake family uses one such manifest in each applicable owner wave and submits no M/CreateGate candidate; its separate schema-fixture gate also passes. Artifact Mesh Task 0 independently requires exactly four W1 slices. Architecture-closure generation likewise requires a non-empty Owner-Ledger contract catalog with exact reciprocal 7+4 document references, every active `production.cutover` release profile/product, the verified predecessor-wave result, and non-empty independently derived production-entrypoint/reachability manifests; zero entries, absent manifests, exact-set/cardinality mismatch, renamed/missing scan roots, or an unindexed input are hard failures before any report is emitted.

### 14.3 Architecture mutations

Tests must fail for at least:

- active-Session WorkUnit admission without exact selection evidence/Workspace/App-Agent scope/root/Main/current-head composition, a `BASTurnOperationPayload` containing fields outside its frozen admission-time wire, or a TurnOperation whose BudgetLease is absent, mismatched, or not installed at zero cumulative use in the same K3 transaction;
- root creation without exact seed/quota/consent/deletion evidence and root-currentness CAS; reopening or selecting a stale/deleting root; Session selection with a missing/substituted expected-absent `(applicationContainer, sessionCreationInputEventID)` CAS, a reused `sessionIncarnationID`, or a second winner for the same creation event; switching roots while retaining private state/cache/KV/credential/permit; or any shipping raw-string Session/App-Agent/Main/Persona lookup bypass;
- a pre-root, Studio, or idle subject fabricating active-Session parents; idle projection creating a TurnOperation/WorkUnit/Attempt/Provider; NextQuestion allocating a Provider; or Provider-backed Studio mini-release becoming reachable before its exact same-owner source wire is controlled;
- a Workspace snapshot not ordinary-put/reopened and attached exactly once to the TurnOperation head before downstream policy/binding/allocation, or an absent/different attachment being silently overwritten;
- retrieval before R0;
- any deviation from `L7/R0 → L8 LaneQuery → R1-R4 → L8 LaneResult → R5 → R6`; a LaneQuery or LaneResult not bound to the exact sealed snapshot/watermark/currentness vector; L8 mutating truth or selecting the final Market; or a late lane result entering R5/R6;
- any state byte touched under an ineligible scope;
- final Market before grounding/conflict;
- small-model proposal increasing authority;
- a production Provider allocation or execution occurring before the frozen branch policy/execution binding, ordinary-put/reopened branch plan, value-only selected `BASPersistedOrganDescriptorPayload`, containment-specific K1 reserve, or committed K3 use; an allocation using a predicted/placeholder plan/descriptor ID or substituting `BASCompiledContextDescriptor` for the persisted Provider descriptor; violation of `K3 allocate → A → allocation-bound purpose-minimal providerStep capsule → materializer M → claim`; K3 pretending to author M; or the capsule being added as an M field/fourth parent beyond exact `[A, BASExecutionPlan, BASPersistedOrganDescriptorPayload]`;
- a remote wait holding the local HeavyPhase lease, or two local accelerator-heavy branches overlapping across host/extension processes;
- a grounder or verifier on `.isolatedExtension` / `.remote` bypassing its complete Section 5 egress fence, or any auxiliary branch using a permit from another branch;
- any grounder, verifier, or terminal candidate consumed before complete A/C/S/P/R lineage and required isolated/remote O/At evidence are reopened and terminal; a local completed Srow/S whose arm/observation are not nil/nil; an isolated/remote completed Srow/S that does not exact-bind B+O and freeze K3-selected At/trust snapshot; or an R whose exact value/parents are not M/P/S while A/C remain reconstructed validator evidence;
- an observed/current-owner local non-completed branch (or exact allowed same-boot physical-quiescence recovery) lacking C/S, an unobserved local owner/boot-loss branch fabricating a seal instead of remaining unresolved/quarantined, an authenticated isolated/remote failed/cancelled/indeterminate branch lacking B+O/At+C/S or whose Srow/S fails to exact-bind B+O and freeze K3-selected At/trust snapshot, any non-completed branch fabricating P/R, or unauthenticated isolated/remote outcome/`sent_or_unknown` being sealed instead of query/reconciled;
- duplicate State Market or Context Compiler;
- Provider selection after tokenization;
- a second physical invocation or Provider substitution on one allocated branch / `BASProviderExecutionRef`, or a branch outside the frozen policy-bounded Attempt DAG;
- cache/context/result reuse after any selection-evidence, Workspace, App-Agent authority scope/root, Main, WorkUnit, Attempt, execution-generation, Self/expression/relationship/policy/consent/deletion/restoration head, Provider/profile/material, tokenizer/template, ABI, visibility, or disclosure mutation;
- direct model/tool/UI write to K3;
- an internal state candidate reaching L13/K3 stage without exact L10 validation and L11 risk/confirmation/disclosure revalidation; re-running L9-L13/prepare or replacing request/outbox/ordinal after an effect prepare; stage/L14/K4 substitution of any frozen grant digest, stable request ID, bound subject, purpose, epoch, deadline/recoveryNotAfter, or signed context; bypassing K4 grant/reserve/claim/use; treating K4 as the K3 seal owner; omitting the caller ordinary-put/reopen of the exact generic attestation; or activating without K3 reopening the attestation/use and winning the expected-parent/read-set CAS;
- K3 authoring or recreating `BASProviderEgressBoundaryPermit` or any other non-K3-owned Artifact payload, or writing K4/Zone-C rows; the only production historical-put exceptions remain the addendum-fixed K3 receipt factory and the existing shared `BASBoundaryArmReceipt` factory, each restricted to its allowlisted kinds and row-pinned epoch;
- a Zone-C adapter call before the `dispatch_ready → dispatch_boundary_armed` CAS has atomically consumed the exact permit, anchor, and arm, or by anything except that CAS winner;
- unknown effect resend;
- a model-produced tool/effect proposal without one completed `.turnStep/.internalProposal` A/C/S/P/R lineage; a direct input/Host-policy effect that overloads `BASEffectCausalPredecessorPayload`, lacks its separate `BASAuthorizedInputEffectPredecessorPayload`, or lacks exactly one normalized Input Event/signed deterministic trigger plus deterministic L9 plan/currentness/budget lineage; a direct effect that performs a Provider lookup, bypasses L10/L11/L13/K3/L14/K4/Zone-C, or replays one source to obtain a second allocation; any branch/ordinal/instance in the authorized-input source/L9 plan, or a prepare/outbox candidate treated as authority instead of K3-recomputed optimistic input; prepare/outbox not ordinary-put/reopened before K3; a K3 row referencing a missing Artifact; concurrent intents both winning, or any duplicate/gapped/reused/mismatched ordinal/instance; a vNext `effectSourceRef` with zero/two family members, wrong contract/version/type tag/artifact, or a v1 model source reinterpreted as authorized input; a `BASEffectCausalPredecessorPayload` with zero/two inner predecessors, a substituted predecessor, or a cycle across either causal family and `.providerProposal | .priorTerminalEffectReceipt`; continuation without a fresh branch after the exact terminal receipt, effect-derived state omitting that source ref/receipt/outcome, or compensation reusing an ordinal/permit;
- provisional, partial, or interrupted bytes being treated as answer-complete, a `.postAnswer` NextQuestion source, answer-derived memory, adopted truth, success reward, or Self/RSI authority; the interruption must still emit its typed, scope-bound, untrusted Experience Envelope or explicit ineligible receipt so failure data is not erased;
- any authoritative K3 event group or completed/failed/refused/cancelled/crashed/abstained/zero-output terminal producing zero or more than one Experience-or-explicit-ineligible record, or substituting one outcome's record for another;
- any reward/credit, dataset, Evidence-B, runtime-state, Policy-A, model, code, schema, or policy candidate derived without its exact reopened Experience parent, or after an ineligible receipt terminalized ingress;
- throughSuffix differing from exactly the R entries of completed preauthorized verifier branches, any failed/cancelled/indeterminate verifier fabricating P/R, any allocated verifier ordinal remaining unresolved, or a failed required verifier allowing the old candidate to continue;
- a buffered Vrow used as if it were visibility receipt V, V not reconstructed/ordinary-put/reopened, or Y built without the exact passed-output-verification E + V + terminal-prefix/suffix entries;
- any provisional/incremental Vrow, visibility receipt, stream permit, or visible batch reachable in V1;
- any mismatch among the L12 buffered, L10 verified, L11 allowed, L14 authorized, and actually released PresentationReleaseEnvelope digests, or any post-authorization field/byte decoration;
- publication preparation omitting or substituting the pinned source branch, terminal execution, T/V/X/Y/Sp/Everify, L11 risk permit, exact grant, destination, or four-ID release-evidence reference; caller re-put of K4-owned U/H; a finalized record missing/substituting capability-use U, anchor H, arm, or exact sink receipt; K3 reading the publication journal; or recovery recalling a sink after possible crossing;
- any L10 failure or L11/L14/final-sufficiency non-exact-allow transforming or releasing the old spool/envelope, a replacement/denial candidate borrowing old Sp/E/V/Y/authorization, or reuse of X after its pinned source/currentness changed;
- post-answer and idle NextQuestion source-parent substitution, an idle candidate outside its closed source enum, zero/weak candidates constructing a winner or mini-release, or any NextQuestion-triggered notification;
- a NextQuestion winner lacking objective, candidate-set/winner digests, score components, threshold/margin, duplicate-suppression, expiry, or render-CAS generation, or a duplicate/expired/stale card becoming visible;
- any zero-Provider or deterministic-only Artifact reaching the terminal-answer/final-publication `BASPublicationBoundaryPermit` path under V1; the separately governed NextQuestion mini-release is not final publication;
- free Persona modifying cognition, verification, or authority;
- query/retrieval self-populating governed memory;
- App Agent A touching B-private state without an exact current authorized read-only share view, or reaching the raw private lineage behind that view;
- a recipient mutating, deleting, or re-sharing a valid read-only shared release;
- a cached or previously resolved shared release remaining readable after revocation, deletion, restoration, policy, purpose, or recipient-scope epoch changes;
- model change retaining old KV/transcript/persona;
- interruption recovery from a transcript/KV/raw stack/actor mailbox, blind continuation of an unresolved boundary, duplicate execution across the continuity cursor, or loss of owner-proved committed work;
- peer/sub-agent free-form or shared-scratch communication, typed-field smuggling, unbucketed timing/length coordination where the policy requires independence, correlated evidence counted as independent consensus, or a tool/network capability outside the Agent capsule;
- Web content acting as an instruction, entering governed memory directly, or supporting a material claim without source/time/span binding;
- any file/attachment/tool/Web content bypassing the exact intake profile/receipt; a caller/parser/model choosing a profile; a schema, profile-selection/currentness authorization, parser mechanism, or receipt-producer mapping missing; an empty/wrong-class E/A `ea_extensions` manifest in any applicable wave, a missing/extra ExtensionSlice, a slice naming zero/multiple owners or seams, two incumbent owners/waves merged into one envelope, a wrong/missing `introductionWave`/`workWave`/prerequisite, a later-wave slice satisfying an earlier consumer, production reachability before all slices and final cutover profile pass, or intake appearing in an M/CreateGate candidate manifest; a receipt with zero/both source-identity variants; type/magic disagreement, archive traversal/link, active content, external reference, decompression/page/pixel/frame/time limit, Unicode/control/confusable, OCR-child, provenance/taint, or partial parse being reported as clean/empty; or content granting instruction/capability/policy/memory authority;
- any durable raw/content-byte materialization—including an Experience raw-content attachment, memory-horizon content, dataset/export/trainer bytes, or cold replay—without the current signed Decision Gate for that exact content class/purpose, or substitution between the authorized raw-content and mandatory content-free Experience-Envelope branches;
- any controlled document still requiring unconditional durable raw-content persistence, or a checker that does not reject that wording;
- repeated challenge resetting budget or dispute lineage;
- Information Sufficiency bypass, phase/parent substitution, a second remand, or any upgrade to `readyVerified` without its exact evidence and L14 receipt;
- any RSI terminal pair other than exact encoded `converged + converged-verified` becoming authoritative, a missing/stale/substituted committed K3 budget-use receipt, repeated digest/false progress witness, obligation-generation rollback, budget reset, or an underscore spelling alias replacing the frozen hyphenated wire;
- any fresh or persisted legacy `.causes` schema row, storage read/reload, extractor result, builder preload/composition, convenience fold, or graph-reducer input reaching L4 world claims, L5/L6 user state, or an authoritative reducer under any migration; independent causal evidence must author a new typed claim while every legacy row remains association/historical/quarantine; and
- any governed learning derivation before causal-root grouping/split assignment, within-split work crossing ancestry, evaluator/reward computation outside its firewall or without exact identity, a hard veto averaged/scalarized away, Pareto dimensions collapsed so one score compensates a vetoed dimension, protected holdout touched before prior stages or beyond its one-shot information budget, shadow/canary evidence without the frozen policy epoch/temporal cohort, adoption before delayed field/drift evidence or without a separately sealed cutover decision, or reuse after drift/taint/correction/deletion without K3 invalidation and rebaseline;
- a correction/taint/deletion/policy epoch whose K3 CAS fails to fence an active Attempt/Provider branch, release/publication/effect/state advance, FTS/dense/temporal/entity/relation/cache/context/NextQuestion/evaluation/RSI consumer, learning candidate, or already exposed non-runtime target before asynchronous cleanup; a foreign-owner row rewritten by K3; or a possibly crossed boundary treated as undone;
- a §4.12 retirement manifest whose ID set/cardinality differs from the exact 12 IDs in Section 9, a deleted coverage row, an unclassified alias/factory/new shipping call, or any production construction/call path to those legacy learning mouths—especially `BASUpdateTicketLifecycleCoordinator`, HostKit lifecycle wiring, `BASMemorySleepConsolidationPass`, `BASTrainingDataExporter`, or hard-coded evolution safety decisions—that can independently write/export/promote/distill/adopt;
- semantic snapshot currentness in an Artifact Mesh head or snapshot `headUpdate`, production authority through `.attemptRoot`/`.semanticSnapshot` Artifact-head purposes, publication-journal ownership of sink handoff, or new semantic use of the neural-tensor `BASStateLakeReader` name;
- raw `streamBody`/`streamDraft` or unbounded stream in shipping composition, stream-then-regenerate, visible bytes before the buffered release path, or cancellation sealed without certified Provider quiescence;
- an `.isolatedExtension` performing accelerator-heavy V1 work, two host HeavyPhase leases, a process-local actor claimed as cross-process arbitration, or a future cross-process lease loss that does not fail closed;
- AFM production eligibility from a hard-coded certification/context/budget/character estimate, Core AI selected without same-cohort Pareto evidence, or an uncertified Qwen/MiniCPM/Granite conversion treated as mandatory;
- remote execution before W5; secret-bearing Codable endpoint/header/M state; command-line API keys; credential metadata/version selection before L14; secret resolution before the exact permit is armed/claimed and Q+B handoff is consumed; a missing/substituted/revoked slot/persistent-ref/version/rotation/auth-scheme/injection-point/request/destination binding; a credential-store lease/journal/retry owner; non-authentication byte mutation or redirect after M; key rotation silently changing branch identity; secret persistence/logging/copy/reuse; or a post-resolution-start crash being retried instead of query/reconciled;
- a foreground-admission contract or receipt missing/substituting queue capacity, priority enum/order, aging thresholds, service window, per-Session minimum/maximum quanta, queued byte/token caps, deadline policy, cancellation generation/owner, maximum prefill/decode token/time quantum, maximum model-residency/KV-prepare/wired-memory waits, the exact additional-downstream-wait stage set/evidence, cooperative-yield evidence, monotonic owner-issued `enqueueOrdinal`, or signed build/profile source; a comparator not exactly aged-priority→earliest-deadline→lowest-enqueue-ordinal; equal-key starvation; infeasible floor/cap/window/memory units; a graph wait omitted/double-counted; checked-arithmetic overflow; a non-finite or merely finite-but-policy-excessive `maximumAdmissionDelay`; runtime/reference-evaluator mismatch; queue state/arrival/cancellation class not explored through that bound; success before first physical quantum; an unresolved/unbounded downstream `WiredMemoryManager`/model/KV/resource wait; wait beyond the bound; duplicate owner-private queue; or second scheduler supplying fairness;
- a `stateless` facet with any mutable/projection/durable state or possible-start responsibility; assigning a durable floor/lease/quarantine sidecar to an `ephemeralDrop` or `rebuildableProjection` state facet; omitting discard/re-admit or source/head/watermark rebuild behavior; selecting `boundaryFacet = none` while a Provider/network/tool/publication/disclosure/trainer/deployment possible-start path is reachable; letting a `durableStore` facet erase its owner's required `externalEffect` query/reconcile facet; recovery using a global registry/database/signer/manager; auto-creating an expected existing durable store; failing to quarantine DB/WAL/SHM together; accepting a stale floor/key epoch; a repaired K4 ledger approving itself; or returning recovered before the profile-correct owner-private lifecycle/currentness proof;
- Artifact Mesh claiming implemented while put-before-K3-reference durability, first-create/reopen identity, rollback/key/schema/head floors, digest reopen, corruption, WAL/SHM, lost-reply, and concurrent-CAS tests are incomplete; any new anchor/assembly path entering the old M manifest, an absent/empty/not-exactly-four Task-0 E/A manifest, a missing/wrong-owner/cross-wave E/A slice, retrospective evidence relabeled original atomic creation proof, assembly route/profile/policy choice, or `ArtifactMeshDeviceLab`/probe path entering the shipping graph; a lab “target” without an installable signed app/project/shared scheme/bundle/entitlements, any of the exact thirteen operations or fourteen fault actions missing, either before/after cut absent, matrix cardinality other than 40, downgraded/substituted/wrong-timing fault, drop-reply without durable commit+suppress+kill-before-observation, CAS race without two live contenders and exact winner/loser, voluntary app exit, PID not proven alive-before/dead-after controller force-termination, a `beforeRecoveryOpen` helper that constructs/opens the store or is not force-killed before normal reopen, controller access claimed to a nonshared iOS Keychain item, ordinary lock substituted for reboot-before-first-unlock, missing/unchanged boot identity, an unexercisable protected-data row labeled pass, a missing/reordered/reused phase or challenge, wrong archive/device/container, fault hook in shipping, or fixture/caller-written success accepted as device evidence; a test-double/in-memory/caller-supplied anchor, wrong Keychain service/account/accessibility/synchronizable setting, protected-data/Keychain unavailability treated as absence/create, injectable or second shipping writer, extension-process raw-store path, CREATE without exact `genesisPending`, genesis-only crash quarantined instead of byte-identically resumed, pending genesis silently replaced/erased, committed anchor/database presence mismatch silently recreated, K3 reference before the two-phase anchor commit, or any crash-state combination other than exact genesis-resume/reset, clear-pending, finalize, or quarantine passing production evidence;
- K4 production proof from only source/text/JSON/plist/log markers, synthetic fixture acceptance, a caller-supplied/offline/replayed challenge or trace, missing archive/Mach-O/CDHash/profile/entitlement/candidate/physical-device/verifier-challenge binding, wrong archive/device response, privacy-sensitive raw CMS/profile/device/trace bytes committed to Git, a projection accepted without authorized external-bundle reopen, external-root/coverage/encryption/custody/access/retention/destruction drift, a creation manifest predicting a destruction receipt or being rewritten after destruction, certification surviving raw-evidence expiry/erasure, an unproved/candidate-selected build-evidence storage profile, or dependency on the unimplemented external ExecutionGate;
- binary rollback whose bridge/predecessor cannot canonically read and write every post-N row and ordinary operation; drops or rewrites an N-only/unknown field or row; fails byte/semantic parity under `N → bridge/predecessor write → N` re-upgrade replay; uses mere open/read success as compatibility; or whose fenced snapshot restore omits, reorders, duplicates, or cannot replay every authorized post-snapshot write instead of declaring roll-forward-only;
- Recognition marked complete without exactly `guestOnlyMechanicallyEnforced` or `governedRecognitionEnabled`; relationship-specific output remaining reachable in guest-only mode; or the governed branch accepting an unmapped, missing, stale, expired, revoked, reboot-invalid, replayed, wrong-profile/Workspace/root/purpose principal/profile-resolution receipt, a caller `hostID`, model assertion, face/style/conversation guess, or an ambiguous relationship-state variant;
- a hand-edited ArchitectureClosureReport; a report missing any owner/storage/recovery/entrypoint/test/status field; a zero-production-entrypoint implementation claim; an unmanifested private/package/internal/public factory/entrypoint, callback/protocol/reflection edge, conditional-build path, or shipping alias/call; deletion of any manifest/contract row; a shrunk, renamed, missing, or caller-selected package/Xcode/XcodeGen/workspace root; an unclassified `project.yml`/`.xcodeproj`/`.xcworkspace`; a stale generated project; omission/narrowing/substitution of any authority-selected profile/product/configuration/condition/entitlement or selected-release identity; an actual/manifest entrypoint or per-wave declared/active contract exact-set/cardinality mismatch; a future contract early, active contract missing, inert prelude reachable, illegal insertion/lifecycle transition/wave drift, two active versions of one required release profile, a required-profile gap, or retirement without a valid same-seal replacement/removal proof; a same-version owner/path/symbol/registry/schema/ref rewrite; a vendored linked symbol erased by path classification; expected output overwritten before comparison; owner/status/policy/expected contract/wave/profile selection supplied by a reachability manifest, selected-release record, or report; a missing/duplicate/noncanonical reciprocal catalog-reference block/term anchor, wrong 7+4 document class/digest, or simultaneous catalog/document/source shrinkage; an evidence leaf claiming its own enclosing tree, a `Cw` non-evidence byte, missing/extra evidence leaf, or `Sw` that does not bind the exact `Pw/Cw` pair; a caller CLI/environment/branch/manifest wave; selection of an earlier wave; a missing/reordered/replaced/forged/non-contiguous predecessor receipt; incomplete/extra/substituted per-wave gate-contract set; same-wave candidate verifier/workflow/domain-checker use; correct gate ID with wrong contract/module/corpus/input-`Pw` digest; active verifier/module derived from current mutable bytes rather than the prior finalized tuple; a proposed module active in its own wave; an unpinned Action; failed old/new differential corpus; or Vn+1/Gn+1 activation before finalized prior admission; a seal with other than one parent or whose diff is not exactly its one fixed new receipt; a stale protected ref, wrong repository/workflow/OIDC/protection/bootstrap digest, force/deletion update, losing CAS, old-fork/parallel successor, repeated/skipped wave, or local preflight labeled admitted; a post-CAS crash treated as permanent success/failure instead of querying the same intent/audit, a replacement intent/attestation, `pendingAdmission` admitting a next wave, or ref/intent/CAS/attestation mismatch not quarantined; a changed path outside the uniquely derived work package; `derived_wave` or predecessor-chain digest not byte-equal to checker output; or the report/receipt itself being treated as authority;
- any of the seven V2 feature IDs or 21 rule IDs missing/extra; a predicate lacking its execution receipt; a matching or unclassified graph delta reachable from a shipping product/entry point; a forbidden symbol/field/product/entrypoint omitted; a matching source outside a frozen lab target/root; any token/AST/SIL/link/dataflow predicate mutation, renamed non-keyword alias, protocol/callback/reflection/indirect path, compilation-condition change, widened lab allowlist, or production link that does not fail;
- a cold-40 campaign with other than two devices × two distinct 50-turn blocks, a sustained-30 campaign with other than two devices × two distinct 1800-second runs, caller-precomputed/reduced p10/rate/slope/pass input, a quantile convention/rank/precision/rounding change, a sample straddling the fifth-of-50 or forty-fifth-of-450 rank, an off-by-one last-quarter/bin boundary, missing/duplicate/out-of-order timestamp or raw sample, memory metric/unit/collector/ABI/count/phase substitution, a non-midpoint-window or multiple memory read, host `phys_footprint` used to certify an out-of-process Provider, a fitted subset or floating-point slope, overflow accepted rather than denial, duplicate verifier run IDs, archive/CDHash/profile/entitlement mismatch, harness/shipping substitution, missing/tampered ambient sensor/procedure, shortened or selectively cooled run, exclusion drift, averaging rescue, or any required replicate failure; and
- unrequested 40/30 becoming a completion gate.

### 14.4 Crash cuts

Inject process death at:

- before and after every K3 transaction;
- after Artifact put before K3 reference;
- after K3 commit before reply;
- before/after K4 issue, claim, anchor, or attestation;
- before/after Zone-C possible start and acknowledgement;
- before/after publication reserve, sink, and finalization;
- before/after Provider credential-version metadata lookup, permit/anchor/arm, claim, handoff, exact-secret resolution start, authentication injection, physical invocation, authenticated observation, and seal—including the post-resolution/pre-call and post-call/pre-observation cuts;
- during context rebuild, Provider switch, cache restore, and Sub-Agent join;
- before/after every state prepare, optional outbox dispatch/receipt, append-and-stage, K4 use/attestation, seal, and activation CAS;
- before/after trainer reservation/submission, unknown start/result, query/reconciliation, checkpoint, cancellation, and late-result arrival after a fence;
- before/after certification E0-E4 close, separately sealed canary Release/deployment, field-result ingestion, E5 verdict, separately sealed full Release, exposure fence, and rollback;
- before/after root genesis/currentness and Session-selection/switch CAS;
- during intake decode/archive expansion/OCR/child publication and taint invalidation fanout;
- before/after Artifact Mesh first create/reopen, WAL/SHM checkpoint, ordinary put durability, K3 reference, quarantine, recovery lease, floor update, and recovery completion, realized on physical devices by the exact thirteen-operation/twenty-six-cut protocol in Section 11.2;
- before/after continuity checkpoint, process death, owner reopen, cursor classification, projection rebuild, and successor Attempt admission; and
- before/after schema bridge migration, predecessor-binary reopen, fenced restore, restoration-epoch install, and roll-forward recovery.

Every cut must reopen to one exact terminal, query/reconcile, denied, quarantined, or pending state without double call, false completion, authority inflation, or lost committed work.

## 15. Current Baseline Truth

At the time of this design record:

- the owner-ledger checker fails because a production source differs from its candidate-index blob;
- the review-candidate checker reports 23 missing or byte-drifted candidate inputs;
- the K4 production checker fails because the approved proof directory does not exist;
- the K4 preliminary status remains `overall_gate = blocked`;
- `scripts/test_qinao_review_closure.py` currently runs 24 tests successfully and validates the existing 39 source-block IDs; the separate remediation suite runs 39 tests with two failures: canonical RSI wire spelling and exact `BASContextCompiler` binding text;
- both current evidence ledgers are schema v1, and the 39-review ledger is not in the candidate index; the controlled target migrates 74 QRM plus 39 admitted review identities to schema v2 and 113 closure children, while the reported external count 45 remains `unverified_external_identity`, outside `findings[]`, and non-counting until an exact itemized-source migration exists;
- zero-Provider deterministic terminal-answer completion wording conflicts with the current Provider-specific terminal-answer publication field; this convergence keeps it internal/non-visible and does not authorize a wire amendment;
- App Agent Self/selection, RecognitionProjection, ContextCapsule, InformationSufficiencyPayload, NextQuestionProjection, and `ContextContinuityManifest` target declarations are absent from production sources;
- production adapters still accept caller-chosen App-Agent/Main/Session/Persona strings and key process-local MLX state from them; root genesis/currentness and Session-selection CAS are therefore not production-complete;
- `BASContextCompiler` still budgets characters;
- `BASProviderExecutionRef` exists, but `executeAtMostOnce` is approved-planned rather than current; production still exposes the legacy `execute(providers:)` list loop;
- `InitiativeLease`, `BASProcessMemoryLedger`, and the local HeavyPhase owner/lease are approved-planned and absent from current production declarations;
- the planned `BASProcessMemoryLedger.processShared` actor is process-local and cannot enforce one HeavyPhase across a host and extension;
- public streaming endpoints still expose raw/unbounded streams and a stream-then-second-generation pattern, so buffered one-invocation V1 is not closed;
- `AppleFoundationOrganAdapter` still reports optimistic fixed certification/context/budget/token estimates rather than exact public runtime observations;
- remote endpoint values can still carry raw URL/header secrets and SampleHost accepts command-line API-key material;
- the current learning graph still has production-reachable ticket lifecycle approve/distill, sleep-consolidation write, raw EventLog export, and hard-coded evolution-safety mouths outside the proposed governed plane;
- the controlled CoreAI/Agent convergence plan still contains unconditional durable raw-content wording that contradicts the signed Decision Gate;
- the standalone corruption-recovery draft is governance-orphaned, and the production Artifact SQLite store still permits create-on-open with `synchronous=NORMAL` without the required external identity/floor and DB/WAL/SHM recovery proof;
- the K4 checker can validate synthetic source/fixture/log-shaped evidence and has not yet proven actual archive/Mach-O/profile/entitlement/verifier-challenge-bound physical-device evidence;
- `BASStateLakeReader` still names a neural-tensor cache path, while semantic StateLake currentness wording still admits an Artifact Mesh head;
- Qinao SDK still publishes opt-in concrete AFM/MLX products, and the opt-in QinaoMLX factory defaults to Gemma;
- Qwen/Core AI evidence is experimental, MiniCPM/Granite conversions are incomplete, and the recorded multi-asset chain is not 40/30 evidence;
- the Owner Ledger candidate reports only `artifact.mesh` and `platform.ios27` as implemented, although Artifact Mesh physical durability/recovery is not closed; core W1-W6 owners remain planned, approved-missing, converging, reopened, or relocation candidates.

These facts do not mean the repository contains no useful implementation. They mean partial foundations, experiments, and dirty candidates cannot be represented as the completed architecture.

## 16. Completion Criteria

This correction design is incorporated only when:

1. all adopted authority wording is reconciled into the four governing addenda, exact seven-document controlled set, and Owner Ledger without membership drift; the recovery companion is non-authoritative or fully folded into those existing authorities; only afterward is the non-authoritative CoreAI/Agent convergence plan revised and digest-pinned before W0 merge;
2. the canonical flow is identical across master, domain plans, tests, and diagrams, including `L7/R0 → L8 LaneQuery → R1-R4 → L8 LaneResult → R5 → R6` and one final State Market;
3. permit Artifact creation, K3 boundary rows and semantic-snapshot currentness, coordinator sink handoff, publication-journal rows, and neural-state naming are unambiguous everywhere;
4. root genesis/reopen/currentness, creation/quota activation, Session-selection/switch CAS, deletion fences, and raw-string source gates are production-executable before `activeSession` admits any WorkUnit;
5. interruption recovery from `ContextContinuityManifest` proves no duplicate boundary and no lost owner-proved committed progress without restoring volatile Provider/process state;
6. Recognition closes as exactly `guestOnlyMechanicallyEnforced` or `governedRecognitionEnabled`, with relationship-specific rendering unreachable in the former and exact mapped/current profile-resolution, principal-binding, relationship-state, purpose, expiry/revocation/reboot receipts required in the latter;
7. legacy Persona, self-pop memory, same-call Provider fallback, raw public streaming/stream-then-regenerate, false Session continuity, optimistic AFM claims, remote-secret paths, and legacy causal/learning mouths are production-unreachable;
8. post-answer/idle NextQuestion retain their closed source union and complete objective/candidate/score/winner/duplicate/expiry/render evidence, produce no card on weak evidence, and remain explicit-tap-only, non-notifying, and non-engagement-optimizing;
9. reasoning fixtures have deterministic or minimum-clarification oracles, and phase-tagged Information Sufficiency cannot be bypassed or upgraded;
10. the vNext effect-source ref contains exactly one typed family: `BASEffectCausalPredecessorPayload` with exactly `.providerProposal | .priorTerminalEffectReceipt`, or the separate branch/ordinal-free `BASAuthorizedInputEffectPredecessorPayload`; caller-owned prepare/outbox Artifacts may carry only an optimistic candidate, and K3 alone atomically reopens them, deduplicates, recomputes/accepts the next monotonic effect branch/ordinal/instance, and installs their existing IDs; model proposals have one physical Provider call per branch, normalized-input/deterministic-policy effects need no model but still traverse every risk/causal/commit/authorization/boundary gate, v1 model rows migrate only to the model family, and all variants end in one governed terminal receipt with fresh continuation branches and higher-ordinal compensation;
11. the one E/A content-intake profile/receipt family maps schema, profile selection, L14/current authorization, parser/containment mechanism, Host receipt production, and storage to proven incumbents; passes each owning wave's exact non-empty set of singular owner/path/responsibility/dependency ExtensionSlices rather than M/CreateGate; remains production-dark until every slice and final cutover profile pass; and fails closed on type, bounds, active-content, archive, external-reference, encoding, provenance, taint, and partial-parse hazards without creating an owner;
12. each of the 113 admitted ledger findings has its schema-v2 identity, disposition, regression/mutation terminals, positive discovery/execution, exact `Pw` payload identity, and indexed privacy-clean proof leaf in evidence-only `Cw`, with zero unresolved known true findings crossing W1; the 45 headline remains unverified/non-counting until itemized controlled admission;
13. the exact `Pw → evidence-only Cw → receipt-only Sw` lineage passes owner, review, remediation, iOS-27-floor, W0, concrete production-reachability, ArchitectureClosureReport, and K4 gates through the bootstrap/prior-admission-derived active verifier and active domain modules over exact `Pw`, with contract/module/corpus/input/result-bound receipts and without empty matches, self-hashing evidence, candidate-selected/current-wave gate code, or manifest self-attestation; only fresh external admission attestation plus successful protected-ref CAS completes it;
14. K4 proof binds the actual signed archive/Mach-O/CDHash/profile/entitlement/`Pw` and a fresh verifier-generated challenge from a verifier-driven physical-device run; sensitive raw bytes remain in an unexpired encrypted re-openable external bundle while Git carries only its privacy-clean signed projection, and expiry/destruction invalidates dependent certification; synthetic/offline/caller-supplied/projection-only proof and the unimplemented ExecutionGate cannot pass;
15. W1 begins with the exact Artifact Mesh Task 0 and non-empty store suite before any consumer, then W1-W6 execute in dependency order from exact clean trees; no later wave supplies an earlier API, behavior, or test fixture;
16. local/API Providers have equal authority ceilings and separate exact execution/disclosure profiles; Core AI/AFM/MLX/Core ML choices remain evidence-selected; remote M is an exact nonsecret template, the permit/use/anchor chain binds one content-free persistent-ref/version record without a credential-store lease, and only the post-handoff K4/Q+B one-shot transport resolves/injects that exact secret before an O/At-bound call;
17. V1 keeps all accelerator-heavy work in the host under one HeavyPhase lease and implements the exact finite-delay foreground-admission contract/receipt—including every graph-discovered model/KV/wired-memory/downstream wait exactly once—inside the existing K1 resource-admission owner, without a second scheduler or false cross-process actor;
18. context, cache, memory, App Agent, Session, Provider, release kind, Agent capsules, and read-only shared releases cannot cross-contaminate or survive an invalidating epoch; correlated Agent evidence cannot masquerade as independent;
19. cautious Web search proves minimum disclosure, intake/untrusted-source isolation, claim/span/time citation binding, and no direct command or memory path;
20. crash recovery never blindly resends an unknown external operation, and every owner satisfies one closed recovery profile whose state facet is exactly pure/stateless, ephemeral discard/re-admit, deterministic projection rebuild, or protected owner-private durable lifecycle/floor/lease/quarantine, while every reachable possible-start boundary additionally requires the orthogonal authenticated external-effect query/reconcile facet—without a shared recovery authority;
21. Artifact Mesh proves its exact four W1 E/A slices without expanding the historical M manifest, sole production Keychain anchor/host assembly, exact two-phase floor state machine, first-create/reopen identity, FULL-equivalent put-before-K3-reference durability, digest reopen, DB/WAL/SHM quarantine, schema/key/head/floor anti-rollback, lost-reply, corruption, CAS recovery, exact 13-operation/14-fault/40-row physical-device matrix with controller-proven crash-victim and fault-bootstrap death, app-entitled `beforeRecoveryOpen` mutations, and real reboot-before-first-unlock unavailability evidence—or remains explicitly blocked—and zero test-double/lab-target shipping reachability before `implemented`;
22. every terminal/interruption emits one Experience Envelope or explicit ineligible receipt; durable raw/content use requires the current exact signed Decision Gate, and no controlled plan retains unconditional raw persistence;
23. learning preserves the complete causal-root→split→within-split→evaluator-firewall→hard-veto→Pareto→protected-holdout→cohort/canary→delayed-field/drift→separately-sealed-adoption order, all-clean ancestry, and the K3 invalidation fanout across active boundaries, projections, candidates, and cutover exposure; learning/RSI cannot adopt itself;
24. V1 production visibility is exactly `bufferedUntilVerified`, performs one Provider invocation into one byte lineage, and keeps incremental/provisional structures unreachable;
25. zero-Provider/deterministic-only results remain unable to reach terminal-answer/final publication; the NextQuestion mini-release grants no such authority;
26. publication preparation/release evidence/sink receipts preserve exact owners and crash recovery never recalls a sink after possible crossing;
27. every binary rollback proves canonical read/write semantics for every post-N row/operation, N-only/unknown-field preservation, `N → bridge/predecessor write → N` parity, and exact authorized post-snapshot-write replay where restore is used; otherwise the release is explicitly roll-forward-only;
28. every append-only authority-selected shipping profile's package/Xcode/XcodeGen/AST/SIL/link graph and checked-in manifest are exact-set/cardinality equal, every new catalog/profile row follows the closed absent-row protocol, and each required active profile family has exactly one active version; the externally bootstrapped active verifier plus complete through-W6 gate-module catalog, non-circular `Pw/Cw/Sw` chain, predecessor-only module activation, fresh live-protection observation, protected canonical-ref CAS, and post-CAS attestation uniquely derive/serialize the wave without caller input; the immutable-identity Owner-Ledger contract catalog is reciprocally and exactly referenced by all eleven authority texts; each derived wave's independently declared/active contract sets equal its introduced/active-through catalog; and the generated ArchitectureClosureReport is complete, digest-bound, non-authoritative, and fails on every missing owner/storage/recovery/entrypoint/reachability/test/status mapping;
29. the exact seven-feature/21-rule V2 quarantine manifest proves every predicate executed, zero shipping reachability, structural lab confinement, unclassified-delta denial, and per-predicate direct/alias/indirect production-link mutation failure; and
30. 40/30 remains optional, exact-protocol, workload-qualified, shipping-archive/entitlement-bound evidence whose verifier derives exact rational populations, ranks, last-quarter bins, frozen-phase `TASK_VM_INFO.phys_footprint` samples, and wide-integer slopes from raw traces—blocking any out-of-process profile without an attributable public metric—and whose two-device replicate intersections all pass rather than a universal promise.

## 17. Prohibited Interpretations

This design does not authorize anyone to:

- treat the current dirty worktree as a verified candidate;
- commit every staged/untracked file as one closure unit without provenance review;
- add another architecture axis, manager, scheduler, store, compiler, Market, ring, or plane;
- implement the shorthand phase labels as new singleton routers;
- query broadly and filter private state afterward;
- let a lane mechanism bypass L8 snapshot-bound query/result contracts or let Artifact Mesh own semantic currentness;
- weight authority against relevance or token cost;
- let a grounding model decide truth or eligibility;
- call a second Provider on the same allocated branch / `BASProviderExecutionRef`, or allocate a branch outside the frozen Attempt policy DAG;
- forward a raw session string into an old KV pool and call it durable continuity;
- admit active-Session work before root/session currentness exists, or restore continuity from a transcript, KV, raw stack, or actor mailbox;
- treat Persona prompts as App Agent Self;
- infer initiative permission from expression preferences;
- write retrieved or generated content directly into governed memory;
- parse an attachment without the frozen intake contract, execute document content, or treat parser failure as an empty trustworthy document;
- treat an API teacher, model consensus, or user engagement as ground truth;
- count correlated Main/Sub proposals as independent or add an Agent broker/shared scratchpad;
- embed Hermes, Pi, Codex, Claude, or another desktop/CLI agent runtime as iPhone authority or recovery truth rather than selectively reimplementing reviewed mechanisms behind Qinao contracts;
- restore a raw stack, Task, actor mailbox, credential, one-shot permit, or mutable Provider state;
- resume an unknown tool, payment, disclosure, publication, or remote call automatically;
- force an explicit user or deterministic Host-policy tool/search request through a model merely to manufacture causality, bypass the complete effect boundary for a Provider-free request, continue a tool chain without a fresh branch and exact prior effect receipt, or hide a resend as compensation;
- let a legacy learning coordinator/exporter/consolidator retain a direct production write, promotion, distillation, export, or adoption mouth;
- make durable raw content the default or let encryption substitute for the signed exact-purpose Decision Gate;
- create a RecoveryManager/Registry/DB/signer, silently create an expected existing store, or call Artifact Mesh implemented before physical recovery/durability proof;
- accept marker-shaped synthetic K4 evidence or depend on an unimplemented root-owned ExecutionGate;
- perform accelerator-heavy V1 work in the isolated extension or call a process-local actor cross-process coordination;
- expose raw/unbounded public streaming, regenerate after streaming, hard-code AFM certification/accounting, serialize/log secrets, or accept API keys on argv;
- force every learned component onto Core AI when measured Core ML evidence is superior;
- interpret Core AI as ANE-only;
- trade full-blood quality for a hidden thermal fallback;
- deploy an incompatible predecessor binary as “rollback,” or let a derived ArchitectureClosureReport grant authority;
- claim current iPhone Air cold 40 or sustained 30 without the exact protocol; or
- call W0/W1-W6 complete while K4, candidate-index, or non-vacuity gates fail.

### 17.1 Explicit V2 quarantine

The V2 quarantine schema fixes exactly seven stable feature IDs:

| Feature ID | Quarantined capability | Exact rule-ID set |
|---|---|---|
| `v2.incremental-visible-streaming` | incremental/provisional visible streaming | `v2q.stream.public-async-sequence`, `v2q.stream.preterminal-release`, `v2q.stream.visible-dataflow` |
| `v2.cross-device-root-merge` | cross-device App-Agent-root merge or external root anchor | `v2q.root.remote-writer`, `v2q.root.merge-cas`, `v2q.root.external-anchor` |
| `v2.cross-process-heavy` | accelerator-heavy isolated-extension execution and cross-process HeavyPhase arbitration | `v2q.heavy.extension-link`, `v2q.heavy.extension-call`, `v2q.heavy.cross-process-lease` |
| `v2.federated-dp-learning` | federated learning or differential-privacy training | `v2q.fldp.learning-egress`, `v2q.fldp.model-delta`, `v2q.fldp.privacy-accountant` |
| `v2.realtime-voice-barge-in` | real-time voice and barge-in | `v2q.voice.audio-capture-link`, `v2q.voice.partial-transcript-flow`, `v2q.voice.barge-in-cancel` |
| `v2.provider-backed-question-studio` | Provider-backed automatic Question Studio | `v2q.studio.provider-purpose`, `v2q.studio.automatic-trigger`, `v2q.studio.preview-provider-flow` |
| `v2.optimistic-context-rebase` | optimistic context rebase across changed currentness | `v2q.rebase.epoch-mismatch-reuse`, `v2q.rebase.optimistic-cas-bypass`, `v2q.rebase.stale-cache-flow` |

`qinao-v2-quarantine-v1.schema.json` freezes rule-set version 1 and the exact 21 rule IDs above. Each rule contains machine-readable, versioned predicates rather than a prose keyword: exact case-sensitive token/enum/declaration seeds where applicable; Swift AST declaration kinds, attributes, conformances, imports and target/module edges; resolved callee/protocol-erasure/callback sets; SIL source/sink roles and forbidden dataflow; conditional-compilation conditions; structural lab-only target/source roots; and the conservative unresolved-edge disposition. The streaming rules trace Provider/spool/partial values to any visible sink before terminal verification; heavy rules reject accelerator framework links/calls from extension products; the other rule families similarly bind their frozen authority source/sink roles. An unresolved alias, selector, reflection edge, callback, or dynamic call fails closed or expands to every compatible target—it cannot become a nonmatch by renaming.

`docs/superpowers/evidence/qinao-v2-quarantine-v1.json` is a candidate-index-bound generated projection consumed by the production-reachability checker, not an authority. For every row it contains exact arrays `ruleIDs`, `predicateExecutionReceipts`, `forbiddenShippingProducts`, `forbiddenShippingSymbols`, `forbiddenShippingFields`, `forbiddenShippingEntryPoints`, `allowedLabProducts`, `allowedLabTargets`, `detectedSourceBytes`, `shippingReachabilityPaths`, `labReachabilityPaths`, and one stable mutation ID per predicate class. The scanner derives those arrays from the complete C2 AST/SIL/link graph and rules; the manifest cannot omit or hand-classify a discovered item. The feature-ID set/cardinality is exactly seven, rule-ID cardinality exactly 21, every allowed-lab set is explicit and wildcard-free, and shipping reachability is empty. Matching V2 source is structurally legal only inside an exact schema-frozen lab target/root. Every new or changed public/reachable symbol, field, target, link, or unresolved indirect edge relative to the candidate base must map to an existing governed capability or one quarantine rule; an unclassified delta fails. When matching source bytes exist, at least one positive path terminates in an allowlisted lab/test product while every shipping path remains absent; when none exist, source/reachability arrays are explicitly empty but every rule still emits a non-empty execution receipt.

Mutation coverage is per rule, not one representative per feature: each of the 21 token/AST/SIL/link/dataflow predicate classes is independently introduced and linked toward shipping, and each gate must fail. Additional mutations rename a matching declaration to a non-keyword alias, route it through protocol erasure/callback/reflection/indirect factory, delete a row/item/receipt, add an unclassified public graph delta, widen an allowed-lab target/root, change a compilation condition, or substitute a smaller graph root; each also fails. Every capability still requires a separate controlled design, owner/reuse analysis, wire and migration plan, crash/recovery matrix, and release certification before leaving quarantine; inert migration vocabulary gains no partial production authority.

## 18. Final Decision

Qinao keeps the same deep architecture. The correction is a convergence operation, not a redesign:

- one authority spine;
- one clean candidate tree;
- one canonical `L7/R0 → L8 LaneQuery → R1-R4 → L8 LaneResult → R5 → R6` retrieval order;
- one Provider-specific context compilation;
- one physical invocation per allocated Provider branch, with only a policy-bounded causal branch sequence inside each Attempt;
- one host-local HeavyPhase in V1;
- one complete branch-specific release/effect/state closure;
- exactly two new immutable contract families—universal Content Intake and authorized-input effect predecessor—with no new mutable owner, plus only catalogued vNext revisions of affected existing wires;
- owner-private recovery plus physically durable Artifact Mesh, never a recovery super-owner;
- one append-only Owner-Ledger contract catalog and one non-circular, authority-ordered wave-admission chain with no caller-selected wave;
- independently scoped App-Agent roots governed by one contamination-resistant identity/learning path;
- a derived ArchitectureClosureReport that exposes omissions without becoming authority; and
- evidence before every completion or performance claim.

The next authorized action after user review is to write a detailed clean-candidate reconstruction and controlled-convergence implementation plan. No production implementation begins merely because this non-authoritative design record exists.
