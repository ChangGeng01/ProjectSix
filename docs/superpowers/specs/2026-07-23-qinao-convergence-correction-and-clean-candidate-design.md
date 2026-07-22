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
- preserving one local heavy phase while overlapping only admitted lightweight work;
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
→ R1 mandatory SQL/metadata + exact/authorized grep + FTS5/BM25
→ conditional R2 temporal/episode
→ conditional R3 entity/relation
→ conditional R4 dense semantic:
     K1 phase reserve → K2 exact embedding mechanism → usage receipt
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

The snapshot, branch policy, execution binding, compiled-context descriptor, every Provider branch/permit/receipt, terminal prefix, presentation envelope, effect/state intent, and release evidence equality-bind the same selected admission-subject/currentness variant plus applicable execution-source/release-kind extensions. A guest/unknown Recognition result does not replace App-Agent selection evidence or create an anonymous active-Session bypass.

A purely deterministic, non-visible WorkUnit with no Provider grounder skips Provider capability admission and the execution binding entirely. If the controlled binding does not already encode an optional primary profile, a grounder-only/zero-main combination remains disabled; this document does not invent that wire variant. Every user-visible V1 answer freezes one selected primary profile in the unique root binding before any Provider branch executes.

`systemManaged` is a Provider-profile variant, not a containment class. Its descriptor independently binds exactly one controlled containment class: `.inProcessCertified`, `.isolatedExtension`, or `.remote`. On-device AFM and a system-managed remote/PCC profile therefore do not share a route merely because both are system managed.

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

The small grounding model is a proposal producer. It may suggest entailment, contradiction, spans, reranking, or coverage. It cannot change eligibility, authority, deletion state, truth, or memory status.

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
L9 tool proposal
→ L10 verification
→ L11 risk/confirmation/disclosure
→ L13 causal preparation and read set
→ K3 outbox prepare/enqueue
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
→ terminal receipt
→ K3 closure
```

A state change following the effect must then traverse the state-commit suffix below. An unknown dispatch/result never creates a resend capability.

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
→ K4 one-shot use receipt
→ Artifact Mesh ordinary-put/reopen immutable ProviderEgressBoundaryPermit payload
→ K3 transaction validates A/M/[T]/permit/use/currentness and installs pending row
→ K4 anchors the committed K3 source root
→ anchor receipt ordinary-put/reopen
→ K3 arms the exact pending row
→ reconstruct/ordinary-put/reopen exact boundary-arm receipt B
→ fresh K3 claim Q
→ beginProviderEgressHandoff consumes Q + B and marks sent_or_unknown
→ noncopyable remote-call permit is consumed immediately by executeAtMostOnce
→ on successful bounded terminal result: complete Section 5.1
```

Artifact Mesh creates/reopens the immutable permit Artifact. K3 alone owns allocation/claim/seal and pending/armed/sent/terminal mutable rows; it does not materialize M. K4 alone owns the use/anchor facts. The transport owns no journal, retry map, or recovery truth. A Section 3 caller that already holds exact reopened A/M (and T for an answer branch) enters this sequence at L11/L14; it equality-reopens that prefix and never allocates, materializes, or pins it again.

The allocation-bound `providerStep` capsule is a mandatory, separately validated derivation input, but the frozen `BASMaterializedProviderRequestPayload` gains no capsule field or fourth parent: its value remains exactly execution ref + execution-plan ID + selected persisted-Provider-descriptor ID + request bytes, and its ordered outer parents remain exactly `[A, BASExecutionPlan, BASPersistedOrganDescriptorPayload]`.

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

### 6.7 Independent contexts and shared cache

- Main and every Sub receive independent immutable capsules.
- Sub outputs return as typed, attributed Artifacts with coverage and currentness; they do not append to Main transcript directly.
- Shared immutable source Artifacts may be referenced when each consumer independently passes eligibility.
- Mutable prompt buffers, KV, sampler state, tool handles, credentials, scratch, and Provider sessions are never shared.
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

The complete legacy causal production reachability must retire or isolate, not merely the fresh heuristic extractor: `BASKnowledgeGraph` schema/storage reads and reload, sequence/co-occurrence extractor, builder preload/composition, convenience fold, and graph-aware reducer mouths are all fenced. Persisted legacy `.causes` rows migrate only to typed untrusted association/historical evidence or quarantine; they cannot enter L4 world claims, L5/L6 user state, or any authoritative reducer. Today, user-state influence is indirect and conditional, including cycles containing `.delays` affecting `complexityAddictionScore`, rather than every `.causes` edge directly writing state. Temporal order, association, execution dependency, claim support, and world causation remain distinct typed concepts.

RSI uses the existing bounded ControlRings and owner paths. It may improve decomposition, retrieval strategy, verification coverage, context allocation, cache plans, and candidate policies. It may not create a fifth ring, hidden scheduler, direct self-modifying code path, direct weight update, direct memory write, or authority expansion.

Only the exact encoded terminal pair `converged + converged-verified` (Swift reason case `.convergedVerified`) together with its current committed K3 budget-use receipt may become authoritative downstream input. Equivalent-state repetition with the same strategy, a repeated canonical digest, unmet fixed obligation, cycle/no-progress, budget exhaustion, cancellation, uncertainty, degraded coverage, or reconciliation-required output remains non-adoptable; none resets an obligation generation or any token/time/branch/remand/effect budget.

The immutable RSI wire decision is to preserve the repository's existing hyphenated encodings with no production migration. In particular, Swift `needsConfirmation` encodes as `needs-confirmation`; the related frozen values include `degraded-with-coverage`, `indeterminate-needs-reconciliation`, `cycle-detected`, `budget-exhausted`, and `no-progress`. Contracts text, remediation tests, and all current/backward/future fixtures must be corrected away from underscore aliases; this correction adds no state.

## 10. Apple-Silicon and Provider Execution Policy

### 10.1 Healthy device objective

The optimization objective is verified completed-task utility under latency, memory, energy, thermal, privacy, recovery, and quality constraints. It is not maximum raw decode speed or keeping every Apple engine busy.

- once W4 creates and activates `resource.process-memory-ledger`, exactly one K1-owned process-wide local HeavyPhase lease is a hard invariant, and neither the owner nor lease is claimed as current production code;
- every Provider branch takes only its containment/profile-specific K1 reserve before committed K3 use: an accelerator-heavy `.inProcessCertified` branch—including opaque-local AFM execution—takes the sole local HeavyPhase lease; an `.isolatedExtension` branch takes its certified extension/IPC/memory envelope and also the same sole HeavyPhase lease if it performs local accelerator-heavy work; a `.remote` branch takes bounded network/Provider/cost/rate reserves and holds no local HeavyPhase while waiting;
- remote wait and admitted lightweight CPU/SQL overlap are therefore not a second local HeavyPhase;
- admitted lightweight SQL/Rust/CPU preparation may overlap only when the MemoryLedger and thermal profile allow it;
- independent logical contexts do not imply multiple resident 4B trunks;
- Qwen may remain resident during an admitted interactive turn;
- Granite-class embedding may remain resident only if exact evidence beats load/eviction cost;
- MiniCPM text loads only when expected verified utility exceeds specialization/residency/switch cost;
- MiniCPM-V loads only for an admitted visual task;
- AFM remains a system-managed Provider and is never a conversion target;
- Core ML microheads remain allowlisted when measured Pareto evidence beats migration; “Core AI target” does not require knowingly slower conversion;
- Metal/C/C++ stay behind Provider/upstream/custom-op seams; Rust owns existing deterministic hot logic behind a narrow ABI; SQL owns indexed durability under its mapped writers; Swift owns host orchestration and Apple lifecycle.

The intended portfolio remains model-neutral:

| Role | Candidate | Production condition |
|---|---|---|
| Main cognition Provider candidate | Qwen3.5-4B text profile | separately packaged, converted, signed, full-chain certified Core AI profile; native MTP and vision remain false until independently certified |
| Main cognition Provider candidate | on-device AFM | system-managed FoundationModels profile with exact availability/accounting/quality/recovery evidence; never a conversion target |
| text Sub | MiniCPM5-1B | independently converted and certified, loaded only for an admitted specialist task |
| vision Sub | MiniCPM-V 4.6 | independently converted and certified ProcessorABI/profile, loaded only for admitted visual work |
| retrieval mechanism | Granite Embedding 97M Multilingual R2 | encoder-only proposal mechanism, not an Agent and never a truth/eligibility owner |
| future Main or specialist | exact API model/profile | default disabled until destination, model, disclosure, credential, cost, retention, purge/query, recovery, and release evidence pass |

Names are portfolio policy, not SDK constants. At this snapshot the self-converted Core AI candidates are targets rather than completed production conversions.

### 10.2 Full-blood quality

Quantization, pruning, distillation, alternate expert topology, substitute MTP tensors, or a smaller model are separate material/profile identities. They may be promoted only after quality and recovery certification. They are never silent thermal fallbacks.

Within one exact profile, pressure may disable disposable prompt-lookup/MTP scratch and continue on the same target if that collapse is pre-certified. A different Provider or model requires a new Attempt.

### 10.3 Performance claims

Cold 40 and sustained 30 remain optional claim tiers. They bind the complete canonical certification protocol rather than only a threshold:

- cold 40 requires two distinct physical devices and exactly 100 preregistered workload turns per device/cohort; before every measured turn ambient is `22 ± 2 °C`, Low Power Mode is off, declared power/screen/radio/background-load conditions hold, no undeclared active cooling is used, and public thermal state is continuously `nominal` for at least 300 seconds; model/runtime residency, specialization/cache state, full-prefill class, prompt/context/output buckets, sampling/RNG/termination, timer, inter-turn interval, failures, and exclusions are preregistered; each device must achieve thermally-cold resident target-verified accepted-decode p10 at least 40 tok/s and pass identity, memory, error, and thermal gates;
- sustained 30 requires two distinct physical devices, one uninterrupted 1800-second continuous-arrival run per device with no inserted cooldown or relaunch, fixed/reported arrival, prompt/prefill/output, model/cache, power/ambient, and timer conditions, and last-quarter accepted-decode p10 at least 30 tok/s on each device without positive memory slope or hidden output-length, quality, retrieval-coverage, or safety reduction;
- only target-verified accepted tokens enter either numerator; proposed/rejected draft tokens, prompt-lookup hits, avoided calls, prefill, TTFT, verification/release, and end-to-end goodput remain separately reported;
- an unrequested claim is `.notRequested` and cannot block structural architecture completion;
- a failed requested claim denies only that claim-bearing profile/release;
- current roughly 10 tok/s Core AI multi-asset evidence and incomplete conversions prove neither target.

For the current `cold40` certification harness, two physical devices is an exact cardinality, not “at least two”; the older Runtime/architecture wording must converge to that same exact-two, exactly-100-per-device contract before a claim can be requested. A future larger cohort changes the harness identity and requires a reviewed protocol revision.

## 11. K4 and Wave Discipline

The current K4 platform spike is preliminary compile/metadata/local-development-signing shape evidence only. Production progression remains blocked until the selected release toolchain/profile can prove:

- intended Enhanced Security capability and entitlement identity;
- signed host and helper archive;
- physical installation and launch;
- unique helper/monitor identity;
- exact direct and asynchronous XPC replies;
- timeout, cancellation, and zero-pending closure;
- candidate-tree and artifact digest binding; and
- no simulator, unsigned, preliminary, symlinked, or stale proof substitution.

Work inside W0 that improves inventories, documents, checkers, fixtures, and candidate hygiene may continue while external signing/profile evidence is unavailable. W1-W6 do not gain completion or production authority from that parallel W0 work.

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
- record candidate-tree identity and toolchain.

#### C1 — Design correction only

- reconcile the canonical pipeline;
- correct Provider permit Artifact versus K3 row wording;
- correct 7/14 pure/known-result “direct commit” wording so direct means no external-effect wait,
  never omission of L13 StatePrepareIntent or K3 prepare with an absent outbox;
- correct L1 consumption versus K1 observation wording;
- correct initiative versus presentation cadence;
- add the same-owner, source-discriminated idle-workspace NextQuestion rules while retaining the existing post-answer variant;
- keep fixed/deterministic Studio previews reachable through non-answer mini-release, but keep Provider-backed generated Studio preview disabled until a separate legal policy-purpose/role/binding/source-wire amendment exists;
- restrict zero-Provider deterministic terminal-answer/final-publication completion to internal/non-visible outcomes and preserve the current K3-pinned, Provider-specific visible publication wire;
- freeze V1 production visibility to `bufferedUntilVerified`; keep incremental/provisional rows, receipts, permits, and batches unreachable pending a separate wire amendment;
- resolve signed raw-content Decision Gate wording;
- preserve the existing hyphenated RSI wires—especially `needs-confirmation`—and correct Contracts/tests/fixtures plus `BASContextCompiler` binding language;
- add no production source.

#### C2 — Gate and provenance closure

- import owner/review/K4/W0 checkers and tests as one coherent slice;
- import the exact review source and closure evidence;
- make every referenced proof one regular stage-0 mode-100644 candidate-index blob whose worktree bytes match;
- atomically migrate the two current schema-v1 ledgers to the controlled schema-v2 target while preserving their exact 74 independently reproduced `QRM-*` plus 39 source-identified review identities, yielding exactly 113 closure children; schema, parser, runner constants, fixtures, receipts, tests, and candidate-tree bindings move together;
- adopt the target closed tagged disposition union `confirmed | duplicateOf | notReproduced | supersededBy`; every one of the 113 findings, regardless of disposition, binds non-empty regression and negative-mutation terminal sets, positive exact discovery/execution cardinality, candidate-tree identity, and its disposition-specific independent proof;
- require every confirmed/superseded true defect to bind its exact adopted repair bytes and owner evidence, with no unresolved known true defect crossing W1; a passing aggregate count without all 113 child receipts is not closure;
- keep `reported_external_count = 45` as `unverified_external_identity` outside `findings[]`, non-counting and without synthetic IDs; if an immutable itemized source is later supplied, its admission requires an atomic reviewed ledger/schema/runner/cardinality/receipt/test migration before any “all 45” claim;
- keep the 39-test remediation suite, the 39-source review ledger, the 74-QRM ledger, and the unverified external count as distinct evidence objects rather than conflating their numbers;
- run mutation tests proving zero candidates/tests/files cannot pass.

#### C3 — W0 source freezes

- import only verified W0 production safety changes and their discovered tests;
- freeze free Persona injection, unsafe memory self-population, same-call Provider fallback, synthetic execution success, direct effects, old causal self-promotion, and every named split-brain path;
- preserve compatibility only behind explicit test/lab/shadow seams;
- recapture append-only W0 receipts against the exact clean candidate index.

#### C4 — K4 platform proof

- import only approved proof bytes produced by the selected release toolchain/profile/device run;
- production proof remains absent rather than copying the preliminary blocked spike;
- close W0 only when both `qinao-silicon-w0-open-set-v1` and `qinao-runtime-w0-open-set-v1` have their required successor and the K4 gate passes.

#### C5 — Resume W1-W6

- execute the existing owner-led work-package order;
- each wave starts from a clean, unchanged, indexed candidate tree;
- each gate binds the same tree, build, receipts, device evidence, and controlled-document digests;
- a later wave never supplies an API or behavior required for an earlier wave to compile or pass.

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

Atomic convergence must apply at least these deltas across the four governing addenda and the exact seven Owner-Ledger-controlled documents in one reviewed unit. A table row does not change either set's membership:

| Document/domain | Required correction |
|---|---|
| 2026-07-23 learning design | Replace the shorthand pipeline with Section 3; remove post-retrieval Eligibility and pre-grounding final Market; expand terminal branches; require every authoritative terminal/interruption to emit Experience-or-explicit-ineligible evidence; change initiative cadence to presentation cadence; preserve hyphenated RSI wires; keep Web-derived material inside contamination cleaning; state that V1 visibility is buffered-only |
| 2026-07-14 architecture design | Distinguish Artifact Mesh permit payload creation from K3 pending-row installation; retain R0-R6 as canonical; correct pure/known-result “direct commit” to retain nonoptional L13/K3 prepare with absent outbox; freeze V1 to buffered-only and require any future incremental semantic graph/batch policy before surface realization |
| 2026-07-17 K3 addendum | Preserve A→M, ordinary-put permit → K3 prepare → K4 anchor → K3 arm → fresh Q/handoff, exact R and Vrow→V→Y wires; make incremental structures production-unreachable in V1 |
| 2026-07-19 Agent/context design | Bind State Compiler/Context Budget Allocator phases explicitly to the sole `BASContextCompiler`; retain signed raw-content Decision Gate precedence; preserve existing hyphenated RSI wires; freeze complete Information Sufficiency/currentness tuples, buffered-only V1, and unsafe-legacy retirement |
| 2026-07-22 App Agent design | Add the controlled idle-workspace NextQuestion source variant, closed source enum, parents, no-notification rule, and tests without changing post-answer sources or creating user intent; retain fixed/deterministic Studio preview mini-release while disabling Provider-backed generated preview pending its separate legal policy/binding/source-wire amendment; retain recognition and InitiativeLease boundaries; restrict zero-Provider terminal-answer/final-publication completion to internal/non-visible outcomes and visibility to buffered-only under V1 |
| Contracts plan | Freeze value shapes, existing hyphenated RSI spellings, buffered-only production reachability, fixtures, and exact owner reuse/create classifications |
| Semantic plan | Enforce R0-R6, query read-only behavior, no self-pop, Web-source untrusted-claim/R6 handling, coverage fixtures, and one context compiler |
| Silicon plan | Enforce one physical call per allocated Provider branch / `BASProviderExecutionRef`, a policy-bounded branch sequence per Attempt, `executeAtMostOnce`, Provider-specific compilation/cache scope, buffered-only V1 selection, and one local heavy phase |
| Sovereign plan | Preserve exact buffered publication/effect/state/Web-search terminal paths, nonoptional state prepare→stage→seal→activate even with nil outbox, K3 terminal-source pin, Provider-specific release evidence, and permit/row separation; reject incremental reachability and every zero-Provider publication bypass in V1 |
| Runtime plan | Add reasoning, Information Sufficiency, NextQuestion source-variant/no-notification, Experience-or-explicit-ineligible outcome coverage, buffered-only and zero-Provider negative reachability, retirement, recovery, certification, and conditional 40/30 cases; converge cold40 to the exact-two-device/exactly-100-turn harness |
| Cautious Web-search reuse | Reuse mapped L7/L8 evidence admission plus `effect.zone-c-saga` and one certified Adapter profile; add query-disclosure, untrusted-return, injection, citation-span/time, cancellation, unknown-dispatch, and crash fixtures; create no search truth/store/scheduler/effect owner |
| Convergence master | Order C1/C2/C3/K4 closure before W1; require all gates against one clean candidate tree |
| Owner Ledger | Update provenance/digests/required terms and exact reuse/extension classifications for the mapped semantic-evidence and `effect.zone-c-saga`/Adapter responsibilities; do not change owner cardinality by implication |

No single prose edit is sufficient. Tests, fixtures, checkers, Owner Ledger required terms, and document digests must move with the controlled correction.

## 14. Verification and Fault Matrix

### 14.1 Candidate integrity

Before any positive claim:

- `git status --short` is empty in the candidate tree;
- candidate-index and worktree file sets are equal for every governed input;
- source, receipt, log, fixture, checker, and test bytes are indexed and digest-bound;
- no proof path is a symlink, executable mode, non-stage-zero entry, ignored file, or external unbound directory;
- governing-addendum, controlled-document, and Owner Ledger digests match the exact candidate tree.

### 14.2 Required static gates

The clean candidate must run the authoritative commands from the convergence master, including:

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
```

Every command must report non-zero candidates/tests/files where applicable. Exit 1 or 2 is failure, not “no match.”

### 14.3 Architecture mutations

Tests must fail for at least:

- active-Session WorkUnit admission without exact selection evidence/Workspace/App-Agent scope/root/Main/current-head composition, a `BASTurnOperationPayload` containing fields outside its frozen admission-time wire, or a TurnOperation whose BudgetLease is absent, mismatched, or not installed at zero cumulative use in the same K3 transaction;
- a pre-root, Studio, or idle subject fabricating active-Session parents; idle projection creating a TurnOperation/WorkUnit/Attempt/Provider; NextQuestion allocating a Provider; or Provider-backed Studio mini-release becoming reachable before its exact same-owner source wire is controlled;
- a Workspace snapshot not ordinary-put/reopened and attached exactly once to the TurnOperation head before downstream policy/binding/allocation, or an absent/different attachment being silently overwritten;
- retrieval before R0;
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
- any zero-Provider or deterministic-only Artifact reaching the terminal-answer/final-publication `BASPublicationBoundaryPermit` path under V1; the separately governed NextQuestion mini-release is not final publication;
- free Persona modifying cognition, verification, or authority;
- query/retrieval self-populating governed memory;
- App Agent A touching B-private state without an exact current authorized read-only share view, or reaching the raw private lineage behind that view;
- a recipient mutating, deleting, or re-sharing a valid read-only shared release;
- a cached or previously resolved shared release remaining readable after revocation, deletion, restoration, policy, purpose, or recipient-scope epoch changes;
- model change retaining old KV/transcript/persona;
- Web content acting as an instruction, entering governed memory directly, or supporting a material claim without source/time/span binding;
- any durable raw/content-byte materialization—including Experience, memory-horizon, dataset, export, trainer input, or cold replay—without the current signed Decision Gate for that exact content class/purpose, or substitution between the authorized raw-content and content-free branches;
- repeated challenge resetting budget or dispute lineage;
- Information Sufficiency bypass, phase/parent substitution, a second remand, or any upgrade to `readyVerified` without its exact evidence and L14 receipt;
- any RSI terminal pair other than exact encoded `converged + converged-verified` becoming authoritative, a missing/stale/substituted committed K3 budget-use receipt, repeated digest/false progress witness, obligation-generation rollback, budget reset, or an underscore spelling alias replacing the frozen hyphenated wire;
- any fresh or persisted legacy `.causes` schema row, storage read/reload, extractor result, builder preload/composition, convenience fold, or graph-reducer input reaching L4 world claims, L5/L6 user state, or an authoritative reducer under any migration; independent causal evidence must author a new typed claim while every legacy row remains association/historical/quarantine; and
- unrequested 40/30 becoming a completion gate.

### 14.4 Crash cuts

Inject process death at:

- before and after every K3 transaction;
- after Artifact put before K3 reference;
- after K3 commit before reply;
- before/after K4 issue, claim, anchor, or attestation;
- before/after Zone-C possible start and acknowledgement;
- before/after publication reserve, sink, and finalization;
- before/after Provider claim, handoff, invocation, observation, and seal;
- during context rebuild, Provider switch, cache restore, and Sub-Agent join;
- before/after every state prepare, optional outbox dispatch/receipt, append-and-stage, K4 use/attestation, seal, and activation CAS;
- before/after trainer reservation/submission, unknown start/result, query/reconciliation, checkpoint, cancellation, and late-result arrival after a fence; and
- before/after certification E0-E4 close, separately sealed canary Release/deployment, field-result ingestion, E5 verdict, separately sealed full Release, exposure fence, and rollback.

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
- App Agent Self/selection, RecognitionProjection, ContextCapsule, InformationSufficiencyPayload, NextQuestionProjection, and ContinuityManifest target declarations are absent from production sources;
- `BASContextCompiler` still budgets characters;
- `BASProviderExecutionRef` exists, but `executeAtMostOnce` is approved-planned rather than current; production still exposes the legacy `execute(providers:)` list loop;
- `InitiativeLease`, `BASProcessMemoryLedger`, and the local HeavyPhase owner/lease are approved-planned and absent from current production declarations;
- Qinao SDK still publishes opt-in concrete AFM/MLX products, and the opt-in QinaoMLX factory defaults to Gemma;
- Qwen/Core AI evidence is experimental, MiniCPM/Granite conversions are incomplete, and the recorded multi-asset chain is not 40/30 evidence;
- the Owner Ledger candidate reports only `artifact.mesh` and `platform.ios27` as implemented, with core W1-W6 owners still planned, approved-missing, converging, reopened, or relocation candidates.

These facts do not mean the repository contains no useful implementation. They mean partial foundations, experiments, and dirty candidates cannot be represented as the completed architecture.

## 16. Completion Criteria

This correction design is incorporated only when:

1. all adopted wording is reconciled into the four governing addenda, exact seven-document controlled set, and Owner Ledger without membership drift;
2. the canonical flow is identical across master, domain plans, tests, and diagrams;
3. permit Artifact creation and K3 boundary-row ownership are unambiguous everywhere;
4. legacy Persona, self-pop memory, same-call Provider fallback, false Session continuity, and legacy causal promotion are production-unreachable;
5. post-answer/idle NextQuestion retain their exact closed source union, deterministically produce no winner/card on zero or weak candidates, remain process-local, explicit-tap-only, non-notifying, and non-engagement-optimizing;
6. reasoning fixtures have deterministic or minimum-clarification oracles, and the phase-tagged Information Sufficiency preflight/final gate cannot be bypassed or upgraded;
7. each of the 113 admitted ledger findings has its schema-v2 identity, tagged disposition, non-empty regression/mutation terminals, positive exact discovery/execution, candidate-tree binding, and disposition-specific proof, with zero unresolved known true findings crossing W1; the 45 headline remains unverified/non-counting until an exact itemized-source controlled migration;
8. the clean candidate tree passes owner, review, remediation, iOS-27-floor, W0, and K4 gates without empty matches;
9. the K4 release/profile/device proof passes before W0 closes;
10. W1-W6 execute in dependency order from exact clean trees;
11. local/API Providers have equal authority ceilings and separate exact execution/disclosure profiles;
12. context, cache, memory, App Agent, Session, Provider, release-kind, and read-only shared-release scopes cannot cross-contaminate or survive an invalidating epoch, and preview/idle subject variants never fabricate active-Session or TurnOperation parents;
13. cautious Web search proves minimum disclosure, untrusted-source isolation, claim/span/time citation binding, and no direct command or memory path;
14. crash recovery never blindly resends an unknown external operation;
15. every terminal/interruption emits one Experience Envelope or explicit ineligible receipt, durable raw/content use requires the current exact signed Decision Gate, and learning/RSI cannot directly adopt its own output;
16. V1 production visibility is exactly `bufferedUntilVerified`; incremental/provisional structures remain unreachable until a separate controlled semantic-graph/batch-policy amendment;
17. zero-Provider/deterministic-only results remain unable to reach terminal-answer/final publication under V1; the non-answer NextQuestion mini-release grants no such authority, and any future final-publication change is a separate controlled design;
18. publication preparation/release evidence/sink receipts preserve exact owners and crash recovery never recalls a sink after possible crossing; and
19. 40/30 remains optional, exact-protocol, workload-qualified, device-certified evidence rather than a universal promise.

## 17. Prohibited Interpretations

This design does not authorize anyone to:

- treat the current dirty worktree as a verified candidate;
- commit every staged/untracked file as one closure unit without provenance review;
- add another architecture axis, manager, scheduler, store, compiler, Market, ring, or plane;
- implement the shorthand phase labels as new singleton routers;
- query broadly and filter private state afterward;
- weight authority against relevance or token cost;
- let a grounding model decide truth or eligibility;
- call a second Provider on the same allocated branch / `BASProviderExecutionRef`, or allocate a branch outside the frozen Attempt policy DAG;
- forward a raw session string into an old KV pool and call it durable continuity;
- treat Persona prompts as App Agent Self;
- infer initiative permission from expression preferences;
- write retrieved or generated content directly into governed memory;
- treat an API teacher, model consensus, or user engagement as ground truth;
- embed Hermes, Pi, Codex, Claude, or another desktop/CLI agent runtime as iPhone authority or recovery truth rather than selectively reimplementing reviewed mechanisms behind Qinao contracts;
- restore a raw stack, Task, actor mailbox, credential, one-shot permit, or mutable Provider state;
- resume an unknown tool, payment, disclosure, publication, or remote call automatically;
- force every learned component onto Core AI when measured Core ML evidence is superior;
- interpret Core AI as ANE-only;
- trade full-blood quality for a hidden thermal fallback;
- claim current iPhone Air cold 40 or sustained 30 without the exact protocol; or
- call W0/W1-W6 complete while K4, candidate-index, or non-vacuity gates fail.

## 18. Final Decision

Qinao keeps the same deep architecture. The correction is a convergence operation, not a redesign:

- one authority spine;
- one clean candidate tree;
- one canonical R0-R6 retrieval order;
- one Provider-specific context compilation;
- one physical invocation per allocated Provider branch, with only a policy-bounded causal branch sequence inside each Attempt;
- one local heavy phase;
- one complete branch-specific release/effect/state closure;
- independently scoped App-Agent roots governed by one contamination-resistant identity/learning path; and
- evidence before every completion or performance claim.

The next authorized action after user review is to write a detailed clean-candidate reconstruction and controlled-convergence implementation plan. No production implementation begins merely because this non-authoritative design record exists.
