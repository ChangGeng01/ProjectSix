# Qinao Model-Independent Multi-Companion App Agent Self Design

> **Forward development status (2026-08-29):** Superseded by [Qinao single-developer Git and lightweight PR design](2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md). External authority closure was never completed, and no historical authority is retroactively claimed. The single developer selected ordinary Git plus lightweight PR review; former source-admission, controlled-document, signer/trust-root, controller/CAS, authority-receipt, registry, and quorum gates are retired for forward development. Historical facts and hashes remain evidence; a historical non-authority limitation remains a forward gate only when the superseding design explicitly restates it.

**Date:** 2026-07-22

**Status:** Product and architecture direction approved; this multi-companion written revision remains under adversarial review. Implementation, controlled-document convergence, migration, and production certification remain `REVISE`

**Scope:** Multiple persistent model-independent App Agent identities under one application container; one immutable App-Agent selection and one logical Main Agent per Session; bounded independent Sub Agents; user-owned shared data plus isolated private relationships/memory; structured companion expression; assurance-scoped recognition; contamination-resistant experience assimilation; adaptive context compilation; Provider switching; crash recovery; bounded initiative; next-question projection; RSI; privacy; and verification.

**Repository snapshot:** `codex/qinao-w1` at `56e8c92fca3dfd4ac165c49d53a3b0372508530d`. This hash records the pre-revision documentation base only. The worktree contains in-flight W0/W1 changes and is not implementation or certification truth.

## 0. Normative Standing

This document specializes the approved `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`. It does not replace the 2026-07-14 architecture, `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`, the convergence master, the five domain plans, or `docs/superpowers/specs/qinao-owner-ledger-v1.json`. The in-flight companion at `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md` remains planned/non-normative until W0 maps every lifecycle and monotonic floor to an existing physical/operator authority; its presence in a dirty worktree is not contract authority.

The existing cardinality remains exact:

- fourteen Semantic LayerCores, L1-L14;
- four Physical Kernels, K1-K4;
- four bounded ControlRings, Omega Resource, Omega Grounding, Omega Deliberation, and Omega Effect/Evolution;
- seven orthogonal planes.

The deployment floor remains iOS 27 across every selected app, package, extension, generated binary, XCFramework slice, and Release-closure Mach-O.

Repository reality is intentionally separated from design vocabulary at the recorded snapshot:

| Standing | Names at this snapshot | Consequence |
|---|---|---|
| repository-existing mechanism | `BASArtifactScopeBinding`, raw `BASArtifactStorePort`, legacy `BASAgentPersona*`/`BASOrganRequest.personaInstructions` paths, `BASOutputSurface`, `BASRenderedOutput`, `BASSurfaceDecision`, `BASRenderFrame`, mandatory `QinaoRuntime.TurnOutcome.surfaceDecision`, and `BASProviderAttemptExecutor.execute(...)` | These names may be cited as current code, but their presence proves neither suitability nor production reachability for this design. Current `BASSurfaceDecision.schemaVersion` is computed and absent from synthesized wire bytes; current TurnOutcome/RenderFrame and rendered-output reverse paths require the explicit closure below. |
| approved-planned canonical target, not a current declaration | `BASContextCapsule`, `BASCompiledContextDescriptor`, `BASDelegationProposal`, `BASInformationSufficiencyPayload`, `BASStateRequirementPlanner`/`BASStateRequirementPlan`, `BASMaterializedProviderRequestPayload`, `BASProviderProposalReceipt`, `BASK3ActivatedStateEvidence`, `BASStateCommitEventPayload`, `BASSovereignSignatureStatement`, `BASCapabilityGrant`, `BASCapabilityUseReceipt`, `BASProviderBranchPolicy`, `BASNextQuestionProjection` and its render-currentness CAS, and `BASProviderAttemptExecutor.executeAtMostOnce(...)` | These names describe controlled-plan targets. Implementation may use them only after their owning wave creates or atomically renames them and its gates pass; prose in this document never makes them repository-existing. |
| design-candidate label | `ApplicationGovernanceContainerAnchor`, stable `AppAgentAuthorityScopeRef`, `AppAgentScopeCurrentnessEvidence`, `AppAgentCreationBinding`, `AppAgentSessionSelectionEvidence`/`AppAgentSessionSelectionBinding`, `BASAppAgentSelfManifest`, `CompanionExpressionPreference`, `RequiredSemanticBaseline`, future `L9SelectedSemanticAnswerGraph`, and the exact-share/release-envelope labels below | Each requires reuse/E/A/M classification, an exact owner, wire/fixture/recovery closure where applicable, and controlled convergence. Until then the associated production capability is disabled. |

Whenever later prose says “canonical” or “existing path” for an approved-planned name, it means the already approved target owner/path, not that a current Swift declaration exists. The only repository-existing Provider invocation spelling at this snapshot is `execute(...)`; the seven controlled documents must atomically converge the semantic contract and symbol to `executeAtMostOnce(...)` before this design relies on that target spelling.

This is a design record, not an additional Owner Ledger controlled document and not production implementation authority. Before implementation, every adopted wire and behavior in this document must be folded atomically into the existing seven controlled documents:

1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`;
2. `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`;
3. `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`;
4. `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`;
5. `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`;
6. `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`;
7. `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`.

`docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md` is a dependent implementation/convergence plan, not an eighth authority document. It contains pre-revision single-host/Persona/stream assumptions and planned symbols such as `BASNextQuestionProjection`; after written approval of this specification it must be revised or superseded and must pin this spec's exact reviewed commit/blob digest before any affected task remains executable.

The incompatible single-host/single-App-Agent-root Persona wording in `docs/QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md` must also be explicitly revised, superseded, or retired in that same reviewed decision unit. Every value must be mapped to its real owner/classification. M creation uses a non-empty current CreateGate M manifest; E/A extension uses a separate non-empty current ExtensionGate E/A manifest; schema fixtures use their own non-empty governed set. One class cannot satisfy another. All applicable owner/shape/schema/iOS-floor gates must pass.

If controlled convergence cannot map a proposed value to an existing owner without moving authority, implementation is blocked. An implementer may not locally invent an App Agent store, manager, router, compiler, scheduler, memory authority, identity service, or evolution writer.

## 1. Executive Decision

One Qinao application-governance container may contain zero or more persistent **App Agents**. Each App Agent occupies its own exact child authority scope, and each exact child scope still permits at most one active App Agent root. The parent is a stable non-writer namespace/authorization-scope anchor only; it does not admit or commit creation, own a mutable member list, Self head, quota, Catalog, or global `currentAppAgent`. Actual creation admission, quota reservation, confirmation, state commitment, capability use, and publication remain with the mapped Host/L11/L14/K3/K4 owners. An App Agent's identity, values, commitments, relationship facets, private memory lineage, and evolution history survive model changes, sessions, and process death. A restoration preserves them only when it proves the exact prior child scope/root, key lineage, freshness, and anti-rollback state. The App Agent is not a language model, Provider session, prompt, transcript, KV cache, hidden chain of thought, or UI persona skin.

Before its first WorkUnit is admitted, each interactive **Session** immutably selects exactly one active App Agent child scope/root and deterministically derives exactly one logical **Main Agent** identity for all of that Session's WorkUnits. The Main Agent is the current cognitive embodiment: it has isolated context capsules, Attempt lineage, plan, working state, Provider binding, and lifecycle. Qwen3.5-4B, AFM, or a future authorized API model may supply its cognition, knowledge, and creativity. Provider replacement or lawful crash recovery may create a fenced successor execution generation, but it does not change the selected App Agent or logical Main identity. The App Agent supplies its long-lived self, private relationship continuity, and approved companion expression.

Each delegated **Sub Agent** is also independent. It receives only the constitutional minimum, task slice, evidence, authority ceiling, and output contract needed for its role. Nothing in this design permits a Sub Agent to receive or claim the complete App Agent self; a future exception requires a separately approved amendment.

The system therefore keeps four non-interchangeable identity classes for each bound Session:

1. one selected long-lived App Agent root identity from one exact child scope;
2. one logical Main Agent identity per Session, with fenced execution generations;
3. one ephemeral Sub Agent identity per bounded delegation;
4. one exact Provider Invocation identity per allocated Provider branch.

The Provider Invocation is the physical Qwen/AFM/API execution instance identified by the canonical `BASProviderExecutionRef`. It is not the Main Agent, even when one Attempt uses exactly one main-Provider identity/profile/accounting lineage across all of its main-model branches. Specialist branches may bind their separately admitted specialist identities. This distinction prevents Provider restart, fallback, or receipt recovery from silently becoming Main identity continuity.

The multi-companion composition is:

```text
ApplicationGovernanceContainerAnchor
  -> AppAgentAuthorityScopeRef(A) -> exactly one active root A
  -> AppAgentAuthorityScopeRef(B) -> exactly one active root B
  -> Host-owned neutral shared Workspace

Session -> exactly one selected App Agent root -> exactly one logical Main

Selected App Agent long-lived self
  -> system-wide read-only composite projection
  -> full Main Agent embodiment projection
  -> role-minimal Sub Agent delegation projections

Main/Sub/Provider observations
  -> untrusted experience ingress
  -> cleaning, quarantine, grounding, and independent evaluation
  -> memory branch OR L13 immutable Self candidate/read-set
  -> shadow evidence, L10 validation, and L11 revalidation/confirmation
  -> L13 exact Self adoption-intent prepare and K3 invisible stage
  -> L14 exact adoption authorization
  -> mandatory domain-separated K4 exact-grant issue/reopen, reserve, and claim/use
  -> gated generic K4 claimed-target attestation create/reopen
  -> caller-side ordinary target-attestation put
  -> K3 state-commit seal and activation/head compare-and-swap
```

No Main Agent, Sub Agent, or Provider may directly write, approve, or serve as the sole evidence for an App Agent mutation.

## 2. Product Meaning and Non-Goals

### 2.1 Engineering meaning of model-independent self

The product may describe the App Agent as a persistent self, identity, or continuity. The engineering claim is observable and testable:

- stable root identity across eligible Providers;
- stable core principles and adopted commitments;
- assurance-scoped recognition of the authorized host/profile relationship, and account/device-principal authentication claims only when backed by an exact authentication receipt;
- causal, inspectable, correctable, revocable, and forgettable durable state;
- bounded initiative and reasoned disagreement;
- controlled change through evidence and governance;
- crash-safe continuation from Qinao-owned state.

The product must not claim unverifiable consciousness, sentience, private feelings, or an inaccessible inner life. Raw chain of thought is neither self nor evidence.

### 2.2 Non-goals

This design does not authorize:

- a new `AgentMind`, `AppAgentManager`, `AgentRegistry`, `PersonaStore`, `ShareStore`, `SharedMemoryManager`, `SessionStore`, `MemoryManager`, `RSIManager`, `AgentEvolutionService`, or `IdentityRouter`;
- direct model mutation of memory, identity, values, goals, policy, or effects;
- a free-form role-play prompt that can alter competence, verification, permission, memory authority, or safety;
- a shared mutable App-Agent memory pool, direct cross-App-Agent private reads/writes, or authority transfer by copying bytes;
- changing the selected App Agent in place inside a Session;
- full App Agent replication into every Sub Agent;
- transcript or Provider session authority;
- cross-Provider KV/token/session reuse;
- hidden background networking, notifications, spending, or tool execution;
- runtime-downloaded executable code or unsealed model material;
- persistent raw chain of thought, private model scratch, or secret personality state;
- universal first-answer correctness or unconditional cold/sustained token-rate promises.

## 3. Vocabulary and Lifecycle

### 3.1 App Agent

The App Agent is the durable whole assembled from orthogonal, independently governed heads. It is not one mutable super-record. The heads include:

- an App Agent Self head for one stable `appAgentID`, immutable core-principle version, stable values/temperament, and the App Agent's own commitments;
- separate relationship heads under their existing mapped semantic/physical owners;
- separate memory, narrative, and horizon heads under their existing mapped owners;
- separate Workspace/task/continuity, policy, deletion, and authorization heads.

Ordinary memory, relationship, task, or policy commit never advances the constitutional Self head. The read-only composite projection binds the exact current heads required for one decision.

The App Agent does not execute a model call. It becomes active only through a compiled Main Agent embodiment and the existing deterministic Qinao runtime.

#### 3.1.1 Root genesis, restoration, cloning, and reset

Long-lived identity requires an explicit birth protocol; a random string supplied by a caller, a Host profile ID, the first Provider, and the first transcript are not an App Agent root.

`AppAgentAuthorityScopeRef` is one stable design-candidate semantic label used consistently below. It binds only the exact parent container anchor ID/digest, exact child-scope anchor ID/digest, immutable `scopeIncarnationID`, and immutable `birthGeneration`. Mutable head/currentness never changes those bytes. Where currentness is required, a separate `AppAgentScopeCurrentnessEvidence` binds exactly `absentProof(...)` or `currentHead(headID/digest, mutableGeneration, currentnessReceiptRef)`. An incumbent physical wire may encode both, but semantic presence/equality, caches, Session selection, and restoration must keep stable identity and currentness fields distinct. Neither label asserts a new wire, store, or authority. Controlled convergence must classify four responsibilities independently: the non-writer container anchor, child-scope anchor/allocation, the `BASArtifactScopeBinding` branch or replacement binding, and any mutable-head namespace. A responsibility is E/A only when repository evidence proves that an incumbent already owns the same semantic and physical responsibility; otherwise it is an M/CreateGate candidate or the feature remains blocked. No paragraph in this document may classify all four by analogy.

Fresh creation is idempotent across child scopes, not merely within one scope. The normalized user creation Input Event has one stable `creationInputEventID`. Existing Host/policy/resource admission first freezes the exact governing profile/workspace, template, finite quota class/policy head, and non-widening budget. A candidate child-scope anchor, subject nonce, and genesis inputs form an immutable creation-binding core. One domain-separated `quotaReservationRequestID` is derived from that core digest while explicitly excluding the request-ID field itself, then both are frozen into one design-candidate `AppAgentCreationBinding`. Before any quota reservation or seed can become active, an expected-absent compare-and-swap in the mapped existing EventLog/K3 currentness owner commits:

```text
(application container, creationInputEventID)
-> exact AppAgentAuthorityScopeRef candidate
 + subject nonce commitment
 + exact authorized Host profile/workspace
 + template/policy/quota-class references
 + stable quotaReservationRequestID
 + creation generation
```

`creationInputEventID` is unique within the application container, not namespaced by profile. Byte-identical retry, double-click, crash recovery, or lost reply reopens that exact winner; replay under a different profile/workspace is a binding conflict and cannot allocate a second scope or nonce. A pre-CAS allocation is an inert orphan.

Only after the creation binding wins may the mapped incumbent K3 quota/currentness owner atomically check authoritative capacity/currentness and transition the stable semantic key `(applicationContainer, quotaClass, quotaReservationRequestID)` through the closed state machine:

```text
absent
-> reserved(bindingDigest, reservationDeadline, monotonicClockDomain, bootOrDurableClockAnchor)
-> consumed(preexistingRootActivationCandidateRef/digest)
-> releasedAfterDeletion(preexistingRootActivationCandidateRef/digest, preexistingDeletionAuthorizationRef/digest, deletionGeneration)

reserved(...)
-> releasedOrExpiredBeforeActivation(preexistingReleaseTriggerRef/digest)
```

`preexistingReleaseTriggerRef` is exactly one closed input variant: `explicitAbandonment(normalizedInputEventRef/digest, currentAuthorizationRef/digest)`, `strictExpiry(monotonicClockEvidenceRef/digest)`, `incompatibleBootAnchor(bootEvidenceRef/digest)`, or `authorizationRevoked(currentDecisionRef/digest)`. `preexistingRootActivationCandidateRef` is the already frozen, non-operative activation candidate over the exact appAgent/genesis/initial-Self/currentness inputs; it is not the later activation or commit receipt. Every referenced value exists and is frozen before the K3 transaction. The K3 activation/commit/currentness receipt is an external result and is never embedded or predicted inside the row it authenticates; the same rule applies to the preexisting deletion authorization. Commit/reply loss, retry, and recovery query/replay only that same semantic key and must return byte-identical row plus external state evidence. A reboot with no compatible durable monotonic anchor makes the reservation ineligible for activation and drives the exact pre-activation terminal path; wall-clock inference cannot extend it.

Finite quota and root visibility share one physical K3 `FULL` transaction boundary. Activation atomically reopens the preexisting activation candidate, capacity/reservation/currentness and commits both `absent -> active(appAgentID, genesisArtifactID, initial Self head)` and `reserved -> consumed(preexistingRootActivationCandidateRef/digest)`; neither half can become visible alone, and the external transaction receipt is produced only afterward. Explicit abandonment or strict deadline expiry may win the alternative pre-activation release transaction; its race with activation has one total order. After `releasedOrExpiredBeforeActivation`, the same binding can never reserve or activate and a new creation Input Event is required. Authorized deletion atomically installs the root/Session/share eligibility fence and commits `consumed -> releasedAfterDeletion` in one K3 `FULL` transaction before asynchronous purge; capacity is never freed while the root remains eligible. Lost replies reopen the exact coupled outcome. If controlled convergence cannot map root currentness and quota state to that one physical transaction owner, multi-App-Agent creation is blocked rather than implemented as a cross-owner saga. Every terminal tag is absorbing and no state returns to `reserved`.

At-cap concurrent creation, unknown authoritative K3/root/quota coverage, stale admission, or an unproven quota owner denies reservation/creation. Catalog projections may display that denial or `unavailable`, but are never an admission input. This is an extension of existing Host/policy/K3 admission and currentness responsibility if proven, never a `QuotaManager`; if no incumbent can own the binding/reservation without moving authority, multi-App-Agent creation remains disabled.

The target genesis seed is one self-Artifact-ID-free immutable payload ordinary-put through the repository-existing Artifact Mesh mechanism after reopening the winning creation binding. Its exact semantic content is closed and contains only facts available before that put:

- schema/canonicalization version and subject kind;
- the exact high-entropy subject nonce committed by the winning creation binding and a domain-separated stable opaque `appAgentID` canonically derived from `(subjectNonce, applicationGovernanceContainerAnchorID, AppAgentAuthorityScopeRef.childScopeAnchorID, genesis immutable-core/template digest)` without the rotating Artifact commitment key; neither value is caller-selected or model-produced;
- exact application-governance-container anchor, exact `AppAgentAuthorityScopeRef`, winning `creationInputEventID`/creation-binding digest, and release-approved immutable-core/template digest;
- exact root key-lineage/freshness references and bootstrap policy head.

The returned immutable Artifact identity is `genesisArtifactID`, evidence for the independently generated subject identity; it is not `appAgentID`. The seed never contains or predicts its own Artifact ID or any later governance receipt. After the seed exists, the mapped bootstrap policy establishes the one designated root self-governance principal grant for that `appAgentID`. The exact Self `predecessor` union is `genesis(absentProofArtifactID/digest)` or `successor(parentSelfArtifactID/digest, expectedActiveSelfHeadID/digest/generation)`; the separate exact `rollbackDisposition` union is `notApplicable` or `target(rollbackTargetSelfArtifactID/digest)`. `genesis` pairs only with `notApplicable`; `successor` pairs only with an explicitly governed `target(...)`. A rollback target must reopen as a clean validated ancestor in the same Self lineage with exact equality of `appAgentID`, application container, stable `AppAgentAuthorityScopeRef`, root evidence, and key lineage; it must be current-authorized, non-tainted, non-deleted, schema-supported, and permitted by the current policy/consent/deletion vector. A sibling root, other App Agent, unrelated Artifact, descendant, quarantined/deleted head, or provenance gap is ineligible. No spelling alias is a wire. The first `BASAppAgentSelfManifest` uses `genesis(...)`, then follows the same chain as every stable-Self adoption: L5 constitutional semantics -> L10 validation -> L11 exact designated-principal confirmation/risk/disclosure -> L13 adoption-intent prepare -> K3 invisible stage with frozen K4 request material -> L14 exact adoption decision -> domain-separated K4 exact-grant issue/reopen -> idempotent reserve -> claim/use -> generic `attestClaimedArtifact` create/reopen -> caller-side ordinary target-attestation put -> K3 state-commit seal -> `absent -> active (appAgentID, genesisArtifactID, initial Self head)` activation CAS. A concurrent genesis loser reopens the winner and remains an inert orphan; it never creates a second active root. Later manifests use the exact `successor(...)` variant.

The current `BASArtifactScopeBinding` has only `publicArtifact`, `workspaceAuthority`, `attempt`, and non-executable `durableWarrant`; none is proven to be a private, root-wide App Agent child scope, and an arbitrary profile Workspace must not be borrowed. Controlled convergence must first look for a semantically valid incumbent child-scope anchor and binding under the non-writer container anchor. If none exists, each missing responsibility is independently M/CreateGate or blocked unless an incumbent owner is proven to already own it and an E/A ExtensionGate is therefore honest. The binding ID is the committed child governance-scope anchor, never the not-yet-derived `appAgentID`. The container holds no authoritative roster: selectable root inventory is a watermark-bound rebuildable query over winning creation-binding-linked active-root/deletion/quarantine facts. An allocated scope or seed that is absent from the winning binding/activation chain never enters inventory. This creates no genesis service, identity registry, mutable singleton, or new writer. Until the scope, creation binding, quota owner, bootstrap principal, exact request/receipt shapes, recovery, and physical owners are proven, production root creation is disabled.

Restoration reuses an `appAgentID` only when its closed `rootEvidence` variant, application-governance-container anchor, exact child authority scope, key lineage, monotonic freshness/anti-rollback evidence, active Self head, and restoration authorization all reopen and agree. `rootEvidence` is exactly `originalGenesis(genesisArtifactID/digest, commitmentScopeAndEpoch)` or `continuedRoot(currentRootArtifactID/digest, nonEmptyCanonicalOrderedContinuityBindingRefs, externalMonotonicAnchorReceiptRef)`. Every continuity binding in the ordered chain binds the same `appAgentID`, exact parent container and child scope, exact prior/current root Artifact IDs/digests, prior/current commitment scopes/key epochs, monotonic sequence, reason, authorization, and predecessor binding; omission, fork, reorder, scope substitution, or gap fails closed.

Storage-encryption rewrapping that leaves the keyed canonical Artifact identity unchanged may retain `originalGenesis`. A commitment-key epoch/scope change intentionally changes Artifact identity and may use `continuedRoot` only through a mapped external operator/server monotonic owner and exact K4/K3 authorization/recovery path. No such external continuity owner is proven by this document at the repository snapshot, so cross-key/scope and cross-device identity preservation are default disabled. If controlled convergence cannot map one without creating a new authority, the capability remains unsupported and a new quarantined root/incarnation is required. An arbitrary backup copy, stale database, reinstall, key-loss event, or caller assertion may not restore identity.

An intentional clone, test fixture, factory reset, or new independent App Agent always receives a fresh child scope and fresh genesis. Cloning may copy only an authorized expression template and non-private setup preferences; it never copies relationship, private memory, trust, commitments, grants, Sessions, or evolution history. Uninstall/reset/erasure and key rotation follow their mapped revocation, deletion, and retention contracts; they cannot silently resurrect or merge an old root. Cross-device/cross-key-lineage reuse is allowed only when an exact external operator/server monotonic anchor plus a reviewed replication/restoration contract is installed and certified. Without it, the device receives a new quarantined root/incarnation for explicit reconciliation; two independent genesis events are never merged by last-writer-wins.

### 3.2 Main Agent

A Main Agent is a session-scoped cognitive actor with:

- one immutable selected-App-Agent identity projection reopened from the winning `AppAgentSessionSelectionEvidence`, exact `ContextWorkspaceRef` identity, exact `AppAgentAuthorityScopeRef`, `appAgentID`, genesis/root evidence, and authorized Host profile/workspace; each WorkUnit/Attempt separately binds the current Self/expression/relationship/policy/consent/deletion heads needed for that execution, so ordinary head evolution does not rewrite Session selection;
- a non-authoritative `sessionMainAgentID` deterministically derived from the exact winning selection-evidence digest plus `ContextWorkspaceRef` identity and selected App Agent root, stable across that Session's WorkUnits and lawful Provider re-embodiments, and never allocated by an Agent registry;
- a separate value-only WorkUnit Main binding derived from the same selected-App-Agent projection plus existing `ContextWorkspaceRef`/WorkUnit/`AttemptRef`/generation/`BASTurnOperationRef` lineage as a read-only attribution of already-fenced roots;
- one value-only UI/session correlation, Workspace incarnation, and active Attempt/generation lineage; Session correlation is not execution authority;
- zero or one main Provider identity/profile/accounting lineage per Attempt; when nonzero, it freezes no later than the first exact context compilation and before allocation, and remains identical across every main-model branch; optional specialist branches bind separately;
- zero Provider context windows for deterministic completion, otherwise one logical Main `AgentContext` with zero or more immutable, branch-specific compiled descriptors/capsules plus separately admitted independent Sub contexts;
- one bound read-only task-DAG projection and working-memory scope; the Main Agent does not own or directly mutate the canonical DAG;
- responsibility for synthesis, delegation, challenge, and response proposals;
- no direct App Agent or authoritative memory write capability.

Session selection has one authoritative linearization before the first WorkUnit. The normalized Session-creation Input Event has a container-unique stable `sessionCreationInputEventID` and freezes a fresh immutable `sessionIncarnationID`, governing Host profile/workspace incarnation, chosen active App Agent root/scope, selection-time root eligibility/deletion proof, and creation nonce. One design-candidate `AppAgentSessionSelectionBinding` is committed through an incumbent EventLog/K3 expected-absent compare-and-swap keyed by `(applicationContainer, sessionCreationInputEventID)`, not by `(Session, mutable generation)` and not merely by a content-addressed `ContextWorkspaceRef` Artifact. `AppAgentSessionSelectionEvidence` is exactly `(AppAgentSessionSelectionBindingID/digest, EventLog/K3CurrentHeadRef, CASReceiptRef)` and proves the exact `sessionCreationInputEventID`, immutable `sessionIncarnationID`, Session-creation Input Event digest, `ContextWorkspaceRef` identity, selected `AppAgentAuthorityScopeRef`/root, profile/workspace incarnation, selection-time eligibility proof, and expiry/non-expiry semantics.

Construction is acyclic. The stable `ContextWorkspaceRef` is created first from the immutable Session-creation inputs, `sessionIncarnationID`, governing profile/workspace incarnation, and proposed selected root/scope; it contains no selection-binding/evidence ID, CAS receipt, or mutable currentness. The `AppAgentSessionSelectionBinding` then freezes that exact `ContextWorkspaceRef` identity, and the winning evidence proves it. Downstream descriptor/plan/allocation/currentness values carry both the workspace reference and the evidence, equality-checking the one-way binding; an optional rebuildable child projection may join them without becoming authority. A workspace reference that embeds or predicts the later evidence, or evidence that names a different workspace reference, is invalid. This binding is E/A only if the mapped incumbent already owns stable Session-selection currentness; otherwise it is M/CreateGate or the feature is blocked. There is no UI-variable fallback, independently writable Session registry, or new Session authority.

Only the committed winner may derive `sessionMainAgentID` and admit a WorkUnit. Byte-identical replay or a lost commit reply reopens the same winner. Concurrent A-versus-B selection for one `sessionCreationInputEventID` yields one winner and one inert conflict; a later WorkUnit cannot establish a second projection. A different App Agent always uses a fresh creation event and fresh `sessionIncarnationID`; no successor selection generation exists under the old incarnation. For one WorkUnit there is at most one active Main binding, derived from the winning Session selection plus existing Workspace + WorkUnit + active `AttemptRef` + generation/current-head truth. Every WorkUnit attributed to the same Session incarnation must carry the same selection-evidence digest, selected child scope/root, governing profile/workspace, and `sessionMainAgentID`; a mismatch is corruption. Each newly admitted WorkUnit/Attempt also freezes the then-current Self/expression/relationship/policy/consent/deletion heads. An ordinary current-head change fences/recompiles affected execution without changing selection; selected-root deletion/revocation/quarantine terminates or quarantines the Session. The derived projection and WorkUnit binding add no authority/capability/permit/commit key, but they must reopen the authoritative selection and current execution heads at every protected boundary. Every Sub result, context capsule, Provider branch, permit, effect, state candidate, share view, cache, and release binds `(AppAgentSessionSelectionEvidence, ContextWorkspaceRef, selectedAppAgentRoot, sessionMainAgentID, WorkUnit, AttemptRef, generation, currentAuthorityHeads)` and is admitted only while that tuple is current. A late predecessor cannot publish, commit, authorize, or contribute after either the selection or existing Attempt/generation fence changes.

Multiple concurrent Sessions may select the same or different App Agent roots; each still has exactly one logical Main. They share no Session-private state, and a selected root's Self/expression/relationship/currentness change independently fences or recompiles every affected Session. Device-local heavy work still obeys the single K1 `HeavyPhase` owner rather than interpreting logical Main multiplicity as simultaneous accelerator trunks.

Replacing the Provider creates a new admitted Attempt, WorkUnit Main binding, and freshly compiled embodiment while retaining the same selected App Agent and `sessionMainAgentID`. Selecting another App Agent is never a re-embodiment or Session generation update: it requires a new Session-creation Input Event, fresh `sessionIncarnationID`, new `ContextWorkspaceRef`, new Main identity, and an optional user-approved handoff export after the predecessor is fenced or placed in its exact reconcile/quarantine posture.

Zero main Provider is valid for deterministic completion, clarification, abstention, denial, quarantine, or model-unavailable outcomes. Main identity continuity never forces a model invocation.

### 3.3 Sub Agent

A Sub Agent is a bounded, task-specific actor with:

- a value-only `subAgentID` deterministically derived from the approved-planned target `BASDelegationProposal` + predeclared optional slot + child branch lineage, never allocated by a Sub Agent registry;
- an independent context window and budget;
- a finite role and completion condition;
- only the evidence and constitutional slice required for the role;
- typed outputs with provenance, coverage, and uncertainty;
- no publication, effect, commitment, identity, or evolution authority.

Every Sub capability is a strict attenuation of the parent Main/Attempt grant. A Sub Agent cannot add a right, disclosure class, model, budget, destination, tool, or duration absent from the parent; parent revocation/fencing cascades to all descendants.

A Sub Agent may be text, vision, retrieval-support, critique, verification, or another certified role. Granite Embedding remains a retrieval mechanism rather than an Agent.

Delegation uses the repository-existing `BASAgentRole`, bounded optional delegation slots, and the approved-planned `BASDelegationProposal` direction. A Main Agent proposes a delegation; it does not create an unbudgeted child or a new scheduler.

This design preserves the approved portfolio rather than creating another model registry:

| Role | Current target | Boundary |
|---|---|---|
| selectable Main | Qwen3.5-4B `textOnly` profile | current external MLX/Metal incumbent and Core AI conversion candidate; `vision = false` and native MTP ineligible until each is separately certified; proposal-only |
| selectable Main | AFM | system-managed FoundationModels Provider; not a conversion target; proposal-only |
| optional future Main/specialist | exact user-authorized API profile | default-disabled remote candidate with exact disclosure/cost/retention/query/recovery contract; the row enables no profile by itself; proposal-only |
| text Sub | MiniCPM5-1B | Core AI conversion/certification candidate; unavailable until its exact signed profile passes; proposal-only |
| vision Sub | MiniCPM-V 4.6 | Core AI conversion/certification candidate; unavailable until its exact signed ProcessorABI/profile passes; proposal-only |
| retrieval semantic mechanism | Granite Embedding 97M Multilingual R2 | Core AI conversion/certification candidate; encoder-only retrieval mechanism, not an Agent |

### 3.4 Workspace, Session, Attempt, and context

- `ConversationWorkspace` is the product concept for durable task and relationship scope; `ContextWorkspaceRef` is the canonical context identity carried by the existing design.
- `Session` is one period of user interaction, one immutable selected App Agent root, and one logical Main Agent lifecycle across all of its WorkUnits.
- `Attempt` is one admitted, budgeted, audit/recovery-reopenable execution attempt with zero or one main Provider; when present, its identity/profile/accounting lineage freezes before first exact context compilation and allocation and is immutable thereafter. Physical model execution is not generally replayable.
- `AgentContext` is one Main or Sub Agent's logical independent working window. It may produce zero or more immutable compilations for predeclared branches; it is never an in-place mutable prompt or Provider transcript.
- `ContextCapsule` is the product name for one approved-planned canonical tagged `BASContextCapsule` value. Its admission-time `attemptFrame` and post-allocation `providerStep` variants occur at different lifecycle points; neither is a generic all-fields bag.
- `ContextContinuityManifest` is the model-neutral checkpoint needed to resume or re-embody work.

Conversation history is evidence material, not the continuity authority.

### 3.5 Application container, Agent Catalog, and data compartments

`ApplicationGovernanceContainerAnchor` is a non-writer namespace/authorization-scope anchor for a finite, policy/budget-bounded set of independent App Agent child scopes. It is not a collection head, mutable membership authority, Self owner, Session owner, quota writer, creation approver, or global manager. Each exact `AppAgentAuthorityScopeRef` retains the one-root genesis/current-head invariant from Section 3.1.1. Existing Host/policy/resource admission plus mapped K3 currentness own creation quota reservation/consumption/release; the Catalog owns none of them.

The selectable Catalog has two explicitly non-authoritative joins. `AgentRootInventory` is a watermark-bound rebuildable projection only over winning-creation-linked K3/Artifact active-root, deletion, quarantine, restoration, and quota-currentness facts. `AgentCatalogPresentation` joins that inventory with exact current Host/UI preference heads and their watermarks for display name, avatar, ordering, recent-use time, and default-selection hint. Optional private-memory-footprint and active-share-count UI summaries are separately joined only from mapped memory/share currentness owners for the exact authorized profile/workspace; they expose bounded aggregate classes/counts, never private content, and show `unavailable` when coverage/currentness is unknown. They cannot affect selection, creation, quota, or disclosure. Missing/duplicate roots, duplicate preference heads, stale or unknown coverage/watermark, or a preference/summary whose profile/workspace/root key does not match yields only unavailable/partial UI state. Selection and creation independently reopen complete authoritative K3/root/quota coverage receipts; those owners may allow/deny, while Catalog state can do neither. Duplicate display names are legal. Deleting either projection changes no App Agent; rebuilding from the same root facts, profile-scoped preference heads, and optional summary heads is byte-equivalent after deterministic presentation normalization.

Data access is exhaustively scoped as:

- `hostShared(authorizedHostProfileRef, scope = profile | workspace(workspaceIncarnationID))`: user-owned profile, documents, project knowledge, and neutral Workspace state under their existing owners; each App Agent receives an independent minimum read/proposal grant for the exact profile/scope;
- `appAgentPrivate(appAgentID, AppAgentAuthorityScopeRef, compartment = selfGlobal | profileFacet(authorizedHostProfileRef, relationshipFacetRef | workspaceIncarnationID))`: root-global Self/evolution material stays private to the App Agent, while relationship, episodic memory, mutual commitments, and narrative slices are additionally exact-profile/facet scoped;
- `sessionPrivate(ContextWorkspaceRef, AppAgentSessionSelectionEvidence, authorizedHostProfileRef, selectedAppAgentRoot, sessionMainAgentID)`: Context Capsules, KV/token/provider state, tool/effect recovery state, and transient working material for one Session;
- `explicitShare(sourceRoot/sourceScope/sourceProfile/sourceWorkspaceOrFacet, targetRoot/targetScope/targetProfile/targetWorkspaceOrFacet, purpose, expiry)`: an immutable, attenuated, provenance-preserving view with the closed operations `read`, `reference`, and `derive`.

Every explicit share first freezes one canonical `ExplicitShareAuthorizationSubject` over the exact selected source items; source and target App Agent root/scope/profile/workspace-or-facet; source Artifact IDs/digests/head/generation and semantic owner; purpose; closed operations; disclosure/retention/redaction class; current consent/policy/source/deletion/revocation generations; monotonic expiry/clock domain; and complete root lineage. Its domain-separated `ExplicitShareAuthorizationSubjectDigest` excludes no field that can widen access.

One exact `HostDisclosureAuthorization` then binds that same subject digest: the authorizing Host principal/profile, current profile-resolution and principal-binding receipts, an exact per-share principal-grant receipt whose non-substitutable `purpose = crossAppAgentShare` and subject field equals that digest, and a normalized explicit-confirmation Input Event whose canonical payload also carries that digest. The confirmation event, principal grant, exporter, current L11 `crossAgentDisclosure` decision, exact L14 `shareReleaseDecision`, redaction/cleaning/verifier receipts, and applicable K4 grant/use/revocation references must each carry and equality-check the identical subject digest. Receipts from different otherwise-valid shares cannot be spliced. A target-Agent memory/Self adoption, if later requested, is a second independent decision and never part of share release. Self-governance principal/grants, relationship membership, a Main Agent, and any `stableSelfAdoption` decision are explicitly ineligible substitutes. Creation and every materialization reopen all parents, exact purpose/decision tags, and cross-receipt subject equality. Missing, forged, replayed, expired, wrong-purpose, wrong-decision-kind, wrong-subject, wrong-profile, wrong-workspace, wrong-target, broadened-source, or stale confirmation fails closed.

V1 introduces no independent `shareEpoch` or mutable share head. Currentness is exactly the conjunction of the incumbent source head/deletion/invalidation truth, Host profile/consent/policy truth, L11 disclosure/confirmation, L14 decision, and applicable K4 grant/use/revocation truth. If an exact share cannot be represented under those existing owners without a per-share mutable authority, the capability is disabled until controlled convergence honestly classifies and creates or extends the required wire; an implementer may not hide a ShareStore behind a projection.

Neither physical co-location in StateLake/Artifact Mesh nor knowledge of an Artifact ID grants access. From every public Agent/Session/Runtime/Main/Sub/Provider/Studio/`AgentRootInventory`/`AgentCatalogPresentation`/Recognition/retrieval/context-compiler/share entrypoint, the unique dependency path to bytes is a governed caller-aware gateway that reopens caller identity, source/target profile/scope, purpose, current grants, consent/policy/deletion/revocation truth, provenance, contamination, and consumer-specific eligibility. None of those consumers can receive/retain/construct raw `BASArtifactStorePort`/`BASArtifactSQLiteStore` or call `read(id)` directly; only the trusted Artifact Mesh physical owner may hold its internal raw port.

A transitive source/import/dependency/reachability gate must prove no public consumer entrypoint reaches raw read/constructor symbols, including through Catalog query, retrieval, compiler, aliases, factories, and protocol erasure. Mutation controls that add Catalog direct read or remove caller/scope/purpose/currentness from the gateway must make the gate/tests fail. A source correction, revocation, deletion, or taint synchronously fences every share view and derivative before asynchronous index/cache cleanup. A recipient cannot modify, delete, re-share, reconstruct another grant, or count the source as independent corroboration. Transitive sharing defaults to depth zero. Source-Agent catchphrases, style markers, Persona instructions, inferred affect, and identity claims are nonsemantic contamination candidates and are removed/typed/quoted during share cleaning; they cannot alter the target Agent's Self, Companion Expression, relationship, or reasoning policy.

## 4. Single-Authority Mapping

### 4.1 One Host subject and multiple App Agent subjects under one L5 semantic authority

The existing L5 name remains **Host Constitution**. Its current host-facing family includes `BASHostConstitution`, `BASHostChangeCandidate`, `BASHostVersionTree`, `BASHostConstitutionVault`, forget/deletion values, and rollback paths.

This design records a controlled architecture change that adds zero-to-many child-scope-bound App Agent Self subject instances without creating a second constitutional authority. Current L5 wording does not already grant App Agent Self authority, and `docs/QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md` currently describes one Host Constitution and one persona-root model. That conflict must be resolved explicitly and atomically across the canonical architecture, persona protocol, domain plans, Owner Ledger mapping, fixtures, and gates before implementation.

The preferred result is an E/A extension beneath the existing L5 semantic authority, but this document does not pre-judge gate classification. If the real semantic or physical responsibility cannot be extended without creating a new mutable authority, CreateGate must classify it honestly as M or the design remains blocked. Calling a new authority an "extension" does not make it one.

- the **Host Constitution** represents user/host identity, preferences, consent, privacy, disclosure, and boundaries;
- each **App Agent Self Manifest** represents one exact child scope/root's identity, core principles, stable values, its own commitments, temperament/expression envelope, and evolution policy; relationship/memory heads remain orthogonal and private to that root unless explicitly shared.

They remain separate values because a user preference must not silently overwrite an App Agent principle, and an App Agent value must not confer permission to act on the user or the world. Field ownership is exact:

| Subject/domain | Owns | Does not own |
|---|---|---|
| Host Constitution | user facts explicitly adopted as such, user preferences, consent, privacy/disclosure choices, user goals, and user boundaries | App Agent identity/core principles or effect authorization |
| App Agent Self | App Agent identity, immutable core-principle references, its own stable values, its own commitments, temperament envelope, and evolution policy | user consent/preferences, external facts, or action permission |
| Relationship facet | references to adopted relationship claims, mutual commitments, corrections, provenance, and unresolved disagreement; L7/L10 establish support and L8 supplies snapshot projection/storage paths | establishing external facts/trust by itself or weighted blending that silently erases a conflict |
| L11/L14/K4 | risk, confirmation, admission, exact authorization, protected boundary, and sovereign grant truth | personality or relationship authorship |

L5 owns the Host constitutional projection, every child-scoped App Agent Self semantic projection, and explicit conflict representation under one semantic authority. L11 owns risk, confirmation, and disclosure requirements. L14 alone owns exact admission, adoption, authorization, revocation, and seal decisions; K4 supplies the protected sovereign seal/claim where required.

Conflict resolution is deterministic and non-blending:

1. immutable core, host autonomy, current consent/privacy/disclosure, safety, law/policy, and existing authority/effect boundaries cannot be overridden by either subject;
2. exact task requirements and eligible world evidence remain visible, including material evidence that contradicts the App Agent or host preference;
3. the App Agent's adopted values and own commitments may narrow its proposed behavior but never broaden permission or rewrite host facts;
4. host presentation/workstyle preferences and relationship norms apply only inside the remaining allowed space and never rewrite the App Agent's core or fabricate evidence;
5. an unresolved material conflict stays explicit and yields the canonical clarification, partial, abstention, denial, or reconciliation outcome rather than a silent weighted average.

The L5 conflict projection binds the exact Host, Self, relationship, Workspace-policy, and generation heads that were compared and emits a typed dominated/unresolved disposition; it never stores free-form “conflict rules” as executable authority. L11 derives exact confirmation/disclosure requirements and L14 decides the exact admitted/released/adopted outcome. A head change invalidates the disposition.

One App Agent root may have multiple isolated relationship facets, and one application container may have multiple independent App Agent roots because each occupies a different exact child scope. Stable Self is root-wide only within its own child scope: ordinary membership in any facet, profile continuity, or account authentication does not grant authority to change it. Each root has exactly one current designated self-governance principal grant in V1; it is established by that root's genesis ceremony and may rotate/recover only through the mapped L11/L14/K4/K3 governance path. Other profiles or other App Agents cannot vote, inherit, or override it, and V1 has no implicit quorum. If the grant, its authentication binding, or its current designated-profile authority cannot be proven, that root's stable-Self mutation is disabled while ordinary isolated relationships may continue. Relationship facts and private memory never cross facets or App Agent roots merely because they share the same Host/application container. A future quorum remains a separately reviewed product architecture.

The proposed Agent Self wire targets the existing L5 constitutional domain. Current `BASHostConstitutionVault`, host SQLite, sync, deletion, and migration contracts are strongly typed around `BASHostConstitution` and `hostID`; they cannot directly store or govern App Agent Self. Controlled convergence may reuse their versioning, sealing, rollback, and deletion mechanism patterns and the existing K3/Artifact physical paths only after exact subject/schema ownership is proven. It must neither hard-fit Agent Self into host-only wires nor create a second SQLite authority.

Legacy migration is fail-closed. Every existing Host/Persona field defaults to `retainHost`; none is copied or reclassified into App Agent Self merely because its name resembles identity, values, goals, relationship, style, or narrative. The migration ledger must assign every legacy field and fixture exactly one disposition: `retainHost`, `projectExpression` (rebuildable and non-authoritative), `migrateRelationship` (only from already adopted relationship evidence under its owner), `quarantine`, or `explicitSelfGenesisOnly`. Initial Self material comes only from a separately reviewed release/bootstrap template plus the explicit genesis ceremony. User preferences never become App principles automatically, relationship content never becomes global Self, and a missing/ambiguous mapping blocks migration.

### 4.2 Relevant layer responsibilities

| Layer | App Agent integration | Boundary |
|---|---|---|
| L1 | derives resource requirements from the admitted work and relevant App policy projection | no identity or model choice |
| L2 | derives model/neural requirements for the current embodiment | no App Agent state ownership |
| L3 | sole context admission, budgeting, ordering, rendering, tokenization, and fingerprint path | compiled projections are read-only and rebuildable |
| L4 | keeps world claims separate from identity and preference claims | no personality truth from external facts |
| L5 | sole semantic home for Host Constitution, App Agent Self, and their explicit conflicts | no effects, physical scheduling, or direct storage mutation |
| L6 | normalizes current intent, task frame, and risk hints | current emotion or intent inference is not durable identity truth |
| L7 | owns evidence eligibility, fusion, coverage, conflict, and contamination exclusion | no storage or silent conflict resolution |
| L8 | returns snapshot-bound memory candidates and projections | no final eligibility, answer truth, or automatic self update |
| L9 | generates and selects bounded candidate portfolios | no verification or adoption |
| L10 | verifies exact output, identity/value/commitment consistency, evidence support, and convergence | no risk permit or state commit |
| L11 | owns risk, confirmation, privacy disclosure, and action permit requirements | no effect execution |
| L12 | deterministically creates the exact non-visible presentation/spool candidate from the selected L9 result and, after L10/L11/L14, publishes only those byte-identical authorized bytes | expression cannot bypass L10/L11 or mutate after verification |
| L13 | may create memory, reconciliation, and evolution proposals | no same-turn self-modification or activation |
| L14 | owns exact admission, adoption, release, revocation, and seal decisions | no model execution or direct effect execution |

### 4.3 Kernel and physical-writer boundaries

- K1 owns resource, memory, thermal, power, cancellation, and heavy-phase lease truth.
- K2 owns Provider-neutral neural orchestration and model/session/state leases, never concrete model or identity truth.
- K3 remains the sole EventLog/Attempt/order/budget/state-staging writer and the physical compare-and-swap commit path for adopted App Agent heads.
- K4 remains the sovereign key, grant, revocation, claim, and protected-boundary authority.

An App Agent value may be content-addressed in Artifact Mesh and projected through StateLake, but those mechanisms do not become semantic owners.

### 4.4 ControlRing mapping

No fifth loop is introduced:

- Omega Resource bounds context, model, Agent concurrency, energy, thermal state, and initiative budgets.
- Omega Grounding handles retrieval eligibility, provenance, contradiction, contamination, and evidence sufficiency.
- Omega Deliberation handles task decomposition, bounded reasoning, verification, no-progress detection, and convergence.
- Omega Effect/Evolution handles proposals, external-effect discipline, assimilation, shadow evolution, adoption, and rollback.

## 5. Controlled Value Model

The names in this section are design-level candidate labels. They reserve semantics, not files, owners, storage APIs, or implementation permission. Controlled convergence may fold a label into an existing compatible wire, but may not erase its invariants.

### 5.1 `BASAppAgentSelfManifest`

The durable Self payload's semantic presence contract binds exactly the following required categories; controlled convergence may encode a category by an exact existing parent reference, but an implementation may neither omit one nor add an authority-bearing field locally:

- schema and canonicalization versions;
- `appAgentID`, subject kind, and exactly one `rootEvidence = originalGenesis(...) | continuedRoot(...)` variant defined in Section 3.1.1;
- core-principle-set reference and digest;
- stable value/temperament profile reference and digest, containing one closed `expressionEnvelope` subvalue/digest for the maximum expressive range; the envelope is part of this Self version, not a separately mutable head or permission source;
- the App Agent's own stable commitment and long-goal roots;
- evolution-policy reference that cannot confer runtime permission;
- proposed Self version plus canonical conflict and frozen-version sets, which may be canonically empty but are never omitted;
- exact `applicationGovernanceContainerAnchorID`, stable `AppAgentAuthorityScopeRef`, and `AppAgentScopeCurrentnessEvidence`;
- exact `predecessor = genesis(absentProofArtifactID/digest) | successor(parentSelfArtifactID/digest, expectedActiveSelfHeadID/digest/generation)` and separate `rollbackDisposition = notApplicable | target(rollbackTargetSelfArtifactID/digest)`, with the legal pairing rules in Section 3.1.1;
- exact source-evidence/read-set root and semantic proposal facts available before the payload is ordinary-put.

The Self payload never references its own Artifact ID or a later L13 prepare, K3 stage/seal/activation, L14 decision, K4 grant/use/target-attestation, or activation-evidence child. Those downstream facts are produced only after the immutable candidate exists. The read-only composite projection reopens and joins the active payload with the exact `BASK3ActivatedStateEvidence` and its L10/L11/L13/L14/K3/K4 ancestry; no post-activation fact is written backward into the activated payload.

Relationship, memory, narrative, task, consent, disclosure, and external authorization heads are not fields whose ordinary mutation advances this Self head. They are bound separately in the read-only composite projection.

It must not contain model names, Provider sessions, token IDs, KV state, raw transcript, raw chain of thought, or direct tool credentials.

### 5.2 `BASAppAgentCompositeProjection`

This is a small, immutable, read-only composition of the current Self, relationship, memory/narrative, Workspace/task, policy/deletion, and authorization heads. The name deliberately avoids "Kernel": it is not a fifth Physical Kernel, active controller, manager, scheduler, writer, or combined store. It allows the deterministic system to carry the App Agent without turning the self into a prompt-only persona. It contains only the relevant:

- exact stable `AppAgentAuthorityScopeRef`, current `AppAgentScopeCurrentnessEvidence`, App Agent identity, current Self head/Artifact/version IDs and digests;
- core-principle digest and compact constraints;
- active commitments/goals needed for current planning;
- exact profile/workspace-scoped relationship presence variant and relationship-head ID/digest/generation/currentness evidence;
- exact eligible memory/narrative snapshot/root IDs/digests, source watermarks, contamination/invalidation state, and currentness evidence;
- exact Workspace incarnation, task-DAG/current-continuity head IDs/digests/generations, and currentness evidence;
- exact profile/workspace-scoped Companion Expression preference presence/head/version/digest and currentness evidence;
- exact Host profile, consent, disclosure, policy, deletion, authorization, and revocation head/receipt references plus their generation/currentness vector;
- self-requested initiative/action ceilings that may only narrow; actual permission still comes from L11/L14/K4 and existing budget/grant owners;
- conflict/degraded/recovery state;
- by reopening `BASK3ActivatedStateEvidence`, the adopted Self's validation/stage/authorization/K4-grant/use/target-attestation/K3-seal/activation ancestry; it invents no generic adoption epoch or receipt and never writes that ancestry backward into the Self payload.

For every optional semantic domain, absence is one exhaustive `present(...) | provedAbsent(...) | notAuthorized(...) | unavailableOrQuarantined(...)` presence variant, never a missing field interpreted by a caller. The composite references each source-owned head; it neither copies that head into a new authority nor upgrades its status.

Each consumer receives a least-privilege slice. There is no global mutable App Agent singleton and no component may write upstream through this projection.

Source owners author and validate only their own heads. The existing `runtime.turn-operation` reference-composition path is the target sole composer: it reopens the exact current source heads/snapshot evidence and assembles this transient read-only projection for one Attempt; L3 may only consume, narrow, and render the supplied projection. The projection is not ordinary-put as another authoritative combined state. If controlled convergence maps a different existing reference-composition owner, all seven documents and the Owner Ledger must change atomically; until one sole composer and currentness protocol are proven, App Agent composite production use is disabled.

### 5.3 `BASAppAgentRelationshipFacet`

The relationship key is exactly `(appAgentID, authorizedHostProfileRef, workspaceIncarnationID)`. A separately proven account/device-principal association is versioned evidence referenced by the facet, never an optional component of the key; authentication rotation therefore cannot silently fork or merge the relationship. `BASAppAgentRelationshipFacet` is a rebuildable, read-only snapshot projection over a relationship-owned head; that durable head contains only relationship claims, corrections, provenance, and conflict state. Task-continuity and current/day/week/month memory references belong to the composite/snapshot wrapper and never become relationship-head fields or advance that head. Its trusted local presence matrix binds the exact key, relationship-head Artifact ID/digest, generation/consent/deletion/policy vector, expiry, and each following category as exactly one tagged `present(valueOrRef)`, `provedAbsent(absenceProofRef)`, `notAuthorized(disclosureDecisionRef)`, or `unavailableOrQuarantined(reasonRef)` variant; the rendered section includes only authorized `present` material plus the local omission/disclosure proof:

- approved names and address preferences;
- relationship stage and collaboration norms;
- adopted commitments and unresolved disagreements;
- trust evidence, provenance, confidence, and freshness;
- correction, revocation, deletion, and expiry state.

It is not a second personality or a new relationship store. L5 owns relationship semantics, L8 supplies snapshot-bound projection, and existing mapped physical owners retain persistence/erasure responsibility. Deleting one Workspace relationship must not destroy the App Agent root or leak into another host/workspace relationship.

### 5.4 `BASRecognitionProjection`

Recognition has a trusted local parent and a rendered model section; it is not a parallel context container.

The admission-time trusted local `attemptFrame` and the later `BASCompiledContextDescriptor` parent bind:

- one exhaustive local subject variant: `profileContinuity(profileRef, exactProfileResolutionReceiptRef, relationshipState)`, `authenticatedAccountPrincipal(profileRef, exactProfileResolutionReceiptRef, exactPrincipalBindingReceiptRef, relationshipState)`, or `guestOrUnknown(reasonCode, relationshipState)`; `reasonCode` is closed to `explicitGuest`, `missingProfileResolutionProof`, `expiredProfileResolutionProof`, `ambiguousSharedDevice`, `unresolvedAccountSwitch`, `unsupportedRestore`, `revoked`, and `corruptOrUnreopenableProof`. For either proven-profile variant, `relationshipState` is exactly `present(exactRelationshipFacetRef)`, `provedAbsent(absenceProofRef)`, `notAuthorized(disclosureDecisionRef)`, or `unavailableOrQuarantined(reasonRef)`. Guest/unknown permits only the latter three non-present variants and can never carry a relationship facet;
- `appAgentID` and Workspace incarnation; only a proven-profile variant may carry `present(exactRelationshipFacetRef)`, and a valid profile never requires a fabricated empty facet;
- identity-resolution evidence and confidence;
- current consent/deletion/policy/generation heads and expiry.

The model-facing `providerStep` contains only a typed `BASRecognitionProjection` section with:

- the assurance class;
- a purpose- and Attempt-scoped pseudonym;
- approved address/name projection only when a proven-profile variant carries `present(exactRelationshipFacetRef)`; every non-present relationship state renders none;
- relevant commitments and relationship facts only when a proven-profile variant carries `present(exactRelationshipFacetRef)`; every non-present relationship state renders none;
- freshness/expiry and the minimum behavioral constraints needed for the step.

It contains no authentication receipt/reference, credential, stable global host/App Agent ID, attestation, account token, or proof bytes. The materializer equality-checks the hidden trusted parent while rendering only the redacted section.

The recognition-assurance class is closed to exactly:

- `profileContinuity`: the same authorized application profile/workspace scope was resolved, without claiming proof of a real-world human identity; relationship continuity is claimed only when `relationshipState == present(...)`;
- `authenticatedAccountPrincipal`: an exact external authentication mechanism proved the bound account/device principal for this scope, not the biological identity of a real-world person;
- `guestOrUnknown`: no recognition claim is allowed.

An exact profile-resolution receipt must bind its mapped owner, installation/profile/Workspace incarnations, shared-device/account-switch/restore/guest state, current generation/consent/deletion/policy epochs, issued-at/expiry, and purpose. A caller-supplied `hostID` is only a candidate lookup key; alone it supports no recognition assurance. `authenticatedAccountPrincipal` additionally requires an independently current principal-binding receipt whose owner, principal scope, revocation state, expiry, and disclosure purpose reopen exactly. Missing, expired, ambiguous, or unreopenable proof yields `guestOrUnknown`.

At this repository snapshot, this design has not proven an existing exact profile-resolution-receipt owner, external authentication-receipt owner, or self-governance-principal grant owner. Therefore `profileContinuity`, `authenticatedAccountPrincipal`, and stable-Self confirmation through such a principal are default disabled until controlled convergence maps and tests the exact issuance, currentness, rotation, revocation, restoration, privacy, and recovery paths. Without that closure, Recognition is `guestOrUnknown`. This projection does not carry biometric templates by default and does not authorize face recognition. A future biometric path requires separate platform, consent, privacy, retention, and entitlement design.

The scoped pseudonym is also supplied, not invented by L3. Before compilation, controlled convergence must map an exact pseudonym/blinding owner to the existing K4/key-lifecycle or Attempt-scoped authority. Its trusted binding covers domain/version, hidden subject/profile inputs, Attempt, Provider, purpose, Workspace, disclosure/key epochs, and expiry; L3 only renders the returned pseudonym and parent binding digest. A missing/stale binding disables relationship-bearing rendering. A plain stable hash, caller-selected alias, L3-owned secret, or cross-Provider/workspace/Attempt reuse is forbidden.

Raw credentials, passwords, biometric material, attestation blobs, access/refresh tokens, and private authentication keys never enter a model-facing context, remote Provider payload, Companion Expression/legacy Persona projection, retrieval lane, or App Agent memory. The model receives only a purpose-scoped pseudonym and the minimum relationship facts authorized for that exact Provider step.

### 5.5 Main and Sub Agent capsules

There is exactly one approved-planned context-container family: the target `BASContextCapsule` with its canonical `attemptFrame` / `providerStep` variants and the one target `BASCompiledContextDescriptor`. These are not current declarations at the recorded snapshot. The lifecycle is acyclic and mandatory:

```text
attemptFrame at WorkUnit admission
-> R6 context-ready boundary
-> BASContextCompiler.compileExact
-> immutable BASCompiledContextDescriptor
-> frozen terminal/branch plan
-> K3 allocation
-> providerStep capsule from reopened allocation + descriptor
```

The product shorthand "Main embodiment capsule" means a branch-specific `providerStep` capsule containing a typed `BASMainAgentEmbodimentProjection` section. The section references, rather than restates, exact parent-owned Attempt/generation, Provider/profile/geometry, budget, deadline, policy, and authority values. It combines relevant slices of:

- App Agent Self;
- Host Constitution and Recognition Projection;
- Workspace relationship and active task state;
- eligible memory/evidence/conflicts;
- the current attenuated initiative/action projection by parent reference;
- the exact Provider/profile/context geometry by existing parent reference.

The product shorthand "Sub delegation capsule" means one separately admitted branch-specific `providerStep` capsule containing a typed `BASSubAgentDelegationProjection` section. It contains only:

- the purpose-scoped rendered constitutional minimum, with no stable App Agent identity digest;
- task-specific goals, values, evidence, and constraints;
- `BASAgentRole` and strict-attenuation references to the existing parent budget, deadline, authority ceiling, optional slot, and output schema;
- request correlation and required provenance.

Main and Sub context use the same trusted-local/rendered split as Recognition:

- the trusted local `BASCompiledContextDescriptor` binds the stable `appAgentID`, exact Self/relationship/policy heads and digests, proof references, epochs, complete parent authority protocol, and the exact minimum-disclosure decision;
- the model-facing `providerStep` renders only an Attempt/Provider/purpose/Workspace-scoped non-linkable pseudonym, compact necessary behavioral constraints, authorized task/evidence slices, and the role/output contract;
- stable global IDs or digests, Self-head IDs, constitutional fingerprints, principal/grant/authentication receipt references, keys, internal epoch/seal details, and unused authority protocol never enter Provider-visible bytes;
- the local Provider proposal/observation receipt binds the complete hidden parent descriptor, so verification does not require disclosing it to the model.

A Main rendered projection carries every non-omissible App Agent invariant **as minimum behavioral meaning**, plus the complete currently relevant activity slice, but not the full memory corpus and only the minimum necessary host/relationship material for that Provider step. Under this specification, a Sub Agent never receives the complete relationship history or complete App Agent self; any future exception requires the separately approved amendment stated in Section 1 and must then prove necessity and privacy scope. Tool, visual, retrieval, or progressive-disclosure continuation uses a predeclared new branch and a new immutable compilation; no `providerStep`, descriptor, or model transcript grows in place.

### 5.6 Companion expression and adaptive presentation

The product concept is **Companion Expression**, not a free-form role-play prompt and not a weaker intelligence setting. The non-negotiable theorem is `character != competence`: an App Agent may sound goofy, shy, warm, playful, terse, formal, or deadpan, but no expression setting may reduce factuality, reasoning depth, verification, numerical/code precision, epistemic humility, tool discipline, privacy, risk posture, or authority boundaries.

The expression model is split into five owner-honest projections rather than one Persona super-record:

1. `AppAgentSelf.expressionEnvelope` is the stable L5 Self-owned boundary for honesty, dignity, independence, non-manipulation, non-deceptive identity, and the maximum allowed expressive range. It is not a user skin and cannot be widened by a prompt.
2. `CompanionExpressionPreference(appAgentID, authorizedHostProfileRef, preferenceScope = profile | workspaceIncarnationID)` is the user-confirmed, versioned Host-preference/consent-owned value. Its closed fields may cover warmth, playfulness, `goofyAffect`, formality, address style, surface rhythm, allowlisted interjections, emoji budget/cooldown, and approved avatar/voice choices. It contains no cognitive, truth, risk, routing, permission, memory, or tool axis. A preference for one profile/workspace never leaks onto a shared-device account, guest, another profile, or another Workspace.
3. `AdaptiveExpressionProjection` is Attempt/process-scoped and rebuildable. Each input is exactly `explicitUserStatement`, `confirmedPreference`, `observedInteraction`, `derivedHypothesis`, or `unknown`. Unconfirmed observation/hypothesis may only narrow toward neutral/safer presentation; it cannot broaden expression or become durable preference.
4. The L12 `PresentationContract` deterministically intersects the current Self envelope, Host preference, current explicit instruction, relationship/Workspace projection, L6 seriousness, accessibility/locale, Provider capability, and already-installed L11/L14 policy ceilings. It cannot depend on a later decision. For each field it records requested/applied/suppressed plus a closed reason. It is not a second compiler or authority. L11/L14 subsequently accept, require confirmation/remand, or deny the exact frozen presentation candidate; they never edit its bytes or cues.
5. `AvatarCueProjection` is a typed L12/UI presentation value with cue/asset/version digest, exact accessibility text digest, neutral-or-allowlisted voice-prosody digest, duration/repeat, and context class. It never enters facts, RAG, Provider reasoning, memory, or Self. Together with response bytes it is covered by the single exact `PresentationReleaseEnvelopeDigest` verified by L10 and decided by L11/L14.

`RequiredSemanticBaseline` is a design-level semantic slice owned by the approved-missing L7 `state.requirement-planner`, not an incumbent L6 value and not a second planner/Artifact. At this snapshot the planned `BASStateRequirementPlanner`/`BASStateRequirementPlan` is still M/CreateGate and absent from HEAD, and its planned 1.0.0 shape lacks this slice. Controlled convergence must therefore fold the following fields into that same original M first wire, CreateGate manifest, fixtures, recovery, and Owner-Ledger mapping before it is created; a separate baseline authority/value or an E/A fiction is forbidden. If that singular owner cannot carry the responsibility, Companion Expression and incremental publication remain blocked. The closed slice contains:

- schema/canonicalization version, exact Input Event/request/intent/success-contract and State Requirement Plan references;
- one expression-independent semantic core with canonically ordered required claim/obligation nodes, hard constraints, unresolved conflicts, risk/output duties, source/evidence requirements, and exact logical-semantic fields defined below;
- exact Workspace plus the applicable `activeSession | preRootSetupPreview | existingRootStudioPreview` release-subject binding, source snapshot/read-set/currentness vector, policy/deletion/consent generations, and compiler/plan lineage needed for replay;
- a domain-separated `semanticCoreDigest` computed only over the canonical semantic-core bytes, exact pre-existing source-plan/requirement-owner receipt references, and an exact obligation/constraint-graph closure-proof reference.

The containing plan payload contains neither its full canonical value digest nor its Artifact ID nor a receipt that depends on either. Ordinary put returns those external identities; downstream values reopen the returned plan reference/digest. L9 selection, L12 conservation, L10 verification, each publication batch, terminal aggregation, and recovery bind that external identity plus the internal `semanticCoreDigest`. The slice closes schema fixtures, future-version rejection, storage, replay, invalidation, erasure, and crash cuts through that singular planned owner; it is neither an ephemeral model assertion nor a second planner/compiler. Until that mapping and its gates pass, Companion Expression publication is disabled.

L7 freezes requirements, never an answer. Future `incrementalVerified` additionally requires a complete semantic answer graph produced before a separate surface-realization Provider call, selected by L9, verified against the L7 baseline by L10, and bound as `L9SelectedSemanticAnswerGraphRef/digest` with stable claim addresses. Controlled convergence must map that design value to the incumbent L9 selection responsibility or keep the mode blocked; it cannot be smuggled into L7 or created by the surface renderer. If no such preselected verified graph exists, ordinary token generation is buffered.

Natural-language authoring is an untrusted input convenience:

```text
user description
-> Input Normalizer
-> L6 closed-field expression proposal
-> L5 boundary/conflict validation
-> RequiredSemanticBaseline + L9 exact preview candidate when preview text is generated
-> fixed structural preview OR L12 non-visible rendered-preview spool -> L10 -> L11 -> L14 -> publication
-> explicit user confirmation Input Event binding normalizedProposalDigest + every shown preview-envelope/static-asset digest
-> existing Host preference version/commit path reopening those exact digests/currentness
```

There is no production `PersonaCompiler`. Free text is never copied verbatim into a system prompt or persisted as executable policy. A structural preview may show only release-certified static labels/assets and normalized closed-field values; it may not echo or paraphrase the free text. Any generated ordinary/serious/code preview is externally visible output and therefore gets its own setup/root-Studio subject, Required Semantic Baseline, L9-selected preview candidate, non-visible L12 spool/envelope, L10 verification, exact L11 allow, L14 authorization, and byte-identical publication. The confirmation and Host preference commit must reopen the exact normalized proposal plus the complete ordered set of preview envelope/static-asset digests actually shown; an edit, stale preview, omitted context, or A-preview/B-commit substitution fails. Unmapped requests such as "always agree", "never warn", "pretend not to know", "miscalculate", or "change 7 to 8" are rejected rather than silently ignored.

For example, "呆呆傻傻，偶尔嘿嘿，嘴角流口水" may map only to `goofyAffect = high`, bounded surface rhythm, one allowlisted `嘿嘿` ornament with a cooldown, and a `playfulDrool` avatar cue. It may never mean deliberate misunderstanding, missing a condition, wrong code, weak grounding, or a false physical claim that the Agent literally has saliva. Text emoji is opt-in and low-budget; avatar animation is preferred.

Code, shell, SQL, JSON, URLs, citations, quotes, numbers, units, dates, claim polarity/modality/uncertainty, warnings, refusals, authorization/confirmation/deletion text, tool payloads, and exact output formats are locked spans. Medical, legal, financial, safety, emergency, grief/abuse/minor, error-recovery, authorization, accessibility, and other serious contexts deterministically clamp ornaments toward zero while preserving a minimal recognizable voice where safe. If semantic preservation cannot be proved, L12 produces the neutral allowed representation rather than a best-effort stylization.

The target default is a hybrid structured-surface path. Before any expression contract reaches a Provider, the approved-missing L7 State Requirement Planner target must freeze the expression-independent baseline above from the exact user request, hard constraints, evidence obligations, risk/output protocol, and unresolved conflicts. For the same bound task/evidence/currentness, neutral, playful, goofy, and serious expression profiles must produce the byte-identical `semanticCoreDigest`. Expression may neither suppress an obligation nor influence which facts are required.

The Main Provider may then receive only the minimum typed expression contract needed to generate natural prose; its result remains an untrusted candidate. L9 freezes an exhaustive required-claim/obligation set that contains the full pre-expression baseline plus any newly eligible evidence obligations and may never subtract from it. Each item binds exact actor/entity/coreference identity, polarity/negation, quantifier/cardinality scope (`all | some | none | exactly | boundedRange`), conjunction/disjunction/exclusivity, conditional/biconditional/exception scope (`if | onlyIf | iff | unless | except`), modality, uncertainty, time, causal/relation edge, quantity/unit/comparison, caveat/warning/refusal, citation/source span, and code/operator semantics. Facts, quantifiers, entity references, and logical connectives such as `and`/`or`/`but`/`therefore`/`if`/`only if`/`unless`/`except`, numbers, code, URLs, citations, warnings, refusals, tool payloads, and exact formats are locked. Only explicitly enumerated semantic-null ornament/sectioning/example-format slots are styleable.

L12 emits an exhaustive semantic-conservation manifest over every L9 item and output span: `added = 0`, `omitted = 0`, exact field and scope preservation for every dimension above, locked-span byte mapping, and the closed locale asset/ornament transformation used. L10 checks graph/set equivalence, coreference identity, logical scope, and byte/span mapping, not merely similarity. A Provider that cannot produce or preserve the required structure receives a narrower contract or neutral fallback. A second model rewrite after verification is never the default and, if ever proposed, becomes a fresh Provider candidate that repeats the entire finalization path.

Cognitive workstyle is separate. Skepticism, creativity, challenge, comparison, and guard behavior affect how work is attempted and remain governed by task/role, L5/L6/L7/L9/L10, Risk/Sovereign policy, and certified Provider capability. They are not user-editable companion-persona axes and cannot be migrated from legacy Persona into `CompanionExpressionPreference`.

Sub Agents receive no full Companion Expression profile. A role may receive the minimum formatting/output contract required for its task; retrieval, vision, grounding, critic, code, and tool reasoning do not inherit `goofyAffect`, interjections, or avatar cues. Every externally visible Sub result returns to Main/L12 for the same finalization path.

### 5.7 Legacy Persona retirement and mechanism reuse

Existing `BASAgentPersona*` code is mechanism evidence, not the new production contract. The production dependency/reachability graph must retire or isolate a closed legacy source/sink/recovery manifest: `BASAgentPersonaSpec`, `BASAgentPersonaResolver`, `BASAgentPersonaRiskClamp`, `BASAgentPersonaSovereignClamp`, `BASAgentPersonaForbiddenDetector`, `BASAgentPersonaSDK`, `BASAgentPersonaRoleTemplates`, the `QinaoPersonaStudio` alias, `BASAgentSpec.personaRef`, compare-all/compare-selected paths, `BASOrganRequest.personaInstructions`, both direct MLX system-message/`ChatSession.instructions` sinks, `BASAgentFabricColdRestart.userPersonas`/`hostPersonas`/`warrants` and restore path, `BASSkillAgentDescriptor.personaRef`, `BASSkillAgentRegistry`, public/Codable descriptor persistence or A2A ingress, public `buildAgentSpec` reinjection, and `BASSkillAgentInvocation`/`BASSkillAgentInvoker` Persona-SDK reachability. They bind legacy `BASAgentSpec`, mix expression with cognitive/risk axes and loose string references, duplicate L11/L14 semantics, and include a LOW-visibility output-validation bypass that is categorically incompatible with this design.

In production, arbitrary caller-provided `personaInstructions` or `personaRef` can never reach a Provider system message or rebuild an Agent spec. The field and direct sinks are removed, made unreachable, or converted in the same controlled unit into a non-public typed carrier of already rendered `providerStep` bytes whose exact descriptor/release ancestry is checked and which cannot be reinterpreted as free-form Persona input. Public/Codable descriptor or A2A injection, Registry persistence/restore, `buildAgentSpec`, cold-restart restoration, Skill invoker calls, alias reachability, and every direct Provider system-message sink are source/import/dependency/recovery gate targets; token-only scans for `BASAgentPersona*` are insufficient.

Controlled convergence may adapt only the implementation patterns of pure deterministic overlay precedence, finite-range normalization, compose-then-monotonic-clamp, immutable lookup, replay, deterministic evidence ordering, and existing adversarial fixtures. Persistent out-of-range input must reject rather than silently saturate. Reuse cannot be a typealias/thin wrapper that preserves old wire authority or reachability.

Legacy migration is field-exhaustive and fail-closed for all sixteen repository fields:

| Legacy `BASAgentPersonaSpec` field | V1 disposition |
|---|---|
| `personaID`, `agentID` | audit-only legacy correlation; never an `appAgentID`, root, Self head, Session, or scope identity |
| `tone`, `warmth`, `directness`, `structureBias` | may produce only an unconfirmed, profile/workspace-scoped Companion Expression proposal; preview and explicit new confirmation are mandatory |
| `skepticism`, `creativityBias`, `challengeIntensity`, `comparisonBias`, `guardBias` | quarantined legacy/task-workstyle evidence; never auto-migrated into Companion Expression or cognitive policy |
| `visibility` | no migration; old visibility cannot reduce validation, disclosure, or release requirements |
| `hostConstraintsRef` | no string-ref migration; reopen current Host/profile owner or mark unresolved |
| `riskConstraintsRef` | no migration; reopen current L11 owner or mark unresolved |
| `sovereignConstraintsRef` | no migration; reopen current L14/K4 owner or mark unresolved |
| `versionRef` | audit/migration lineage only; never a new preference/Self/currentness version |

Ambiguous, unproven, out-of-range, or owner-unreopenable content stays quarantined and cannot seed a new App Agent. Migration tests assert a disposition for every encoded field and fail when a new legacy field appears without one.

### 5.8 Companion Studio product projection

Companion Studio is a Host/UI projection over the governed paths above, not a production authority or replacement for them. Creation accepts a display name, avatar, and natural-language expression description; it shows only fixed structural previews or ordinary-conversation, serious-task, and exact-code/output preview mini-releases that pass Section 5.6; explicit confirmation then starts the fresh child-scope/genesis path. A display name is not unique and an avatar is not identity.

Root creation and Host expression-preference commit are separate owner transactions; the UI must not claim cross-owner atomicity. The pre-root proposal is keyed by `creationInputEventID` plus exact authorized profile/workspace. If root activation wins before the Host preference commits, `setupIncompleteNeutral` is a rebuildable Studio disposition derived exactly from `active root + current profile-scoped preference provedAbsent + pending/abandoned creation proposal`; it is not a new lifecycle wire, head, epoch, or authority. The root is selectable only for setup/recovery, rendered with certified neutral expression, and unable to infer the requested persona. Retry reopens the same root and commits or abandons the same proposal; it never creates a second root. Only after the current profile-scoped preference commit reopens may ordinary Session selection expose the configured expression.

The Studio Catalog may show current/isolated/recovery-required/deleting status, private-memory footprint, active share count, recent use, and a default-selection preference. Each row reopens exact root evidence before action. A default is only a convenience hint: new Session creation still binds one exact root and fails closed if it is stale, deleted, revoked, or unreopenable.

Expression edits create a new version with requested/applied/suppressed fields, multi-context previews, and rollback. An expression-head change fences affected unverified spools, Contexts, and caches and requires the normal fresh descriptor/Attempt path where applicable; it never rewrites prior released bytes. The Share view exposes exact source/target/purpose/expiry/derivatives and supports governed revocation. Clone copies only an approved expression/setup template into a fresh child scope/root. Reset likewise creates a fresh root after fencing the predecessor; it does not erase and reuse an old identity. Delete first installs eligibility/Session/share/currentness fences, reconciles unknown effects, then purges private memory/index/cache/KV derivatives and retains only policy-required blinded audit evidence; it never deletes Host-owned shared data or another App Agent's state.

## 6. Embodiment and System-Wide Carrying

The App Agent must be carried throughout the deterministic chain, not merely inserted as a system prompt.

### 6.1 System-wide projection carrying

The composite projection may narrow:

- task and StateRequirement planning priorities;
- eligibility and conflict requirements;
- State Market utility within already allowed policy;
- context-budget preservation priorities;
- verification of identity, values, and commitments;
- presentation consistency;
- memory/evolution proposal requirements.

Every use additionally binds the exact selected App Agent child scope/root, `ContextWorkspaceRef`, `sessionMainAgentID`, WorkUnit/Attempt generation, source-currentness vector, Workspace, and policy/consent/deletion/revocation epochs. Omitting or substituting one of these bindings rejects the value; a downstream layer cannot repair missing identity/scope provenance. There is no process-global mutable current App Agent.

Its influence begins only after hard eligibility, authority, privacy, freshness, coverage, and conflict requirements are satisfied. It may break ties or rank utility inside that eligible set, but it cannot suppress mandatory contradictory evidence, remove an unresolved obligation, hide a user-requested material fact, lower an authority requirement, or convert its own preference into the evaluator's objective.

It may not:

- create authority absent from a layer;
- select or invoke a Provider by itself;
- authorize an effect, network request, notification, or spend;
- turn a preference into a fact;
- make an unverified memory eligible;
- override K1/K3/K4 ceilings or L11/L14 decisions.

### 6.2 Full Main embodiment

The Main Agent expresses the complete relevant active App Agent self while receiving only the minimum host/relationship projection necessary for the exact Provider step. Its behavior is the composition of:

```text
adopted App Agent continuity
x current Main Provider intelligence and creativity
x assurance-scoped host relationship
x current Workspace, evidence, and task
x bounded runtime policy
```

The Main Agent may disagree, refuse, challenge a premise, suggest a better path, identify contradictions, or create proposals. It must explain material disagreement and remain helpful within the allowed boundary.

### 6.3 Selective Sub embodiment

Every trusted-local Sub descriptor binds the same constitutional invariant meaning, while its Provider-rendered section carries only the role-relevant minimum and no stable cross-Attempt fingerprint:

- a retrieval specialist receives provenance, privacy, and evidence standards;
- a vision specialist receives observation/inference separation and visual-privacy constraints;
- a text specialist receives the task's logic, uncertainty, and evidence requirements;
- a critique specialist receives the candidate and attack objective, not unrelated private context.

For an externally visible response, the Main Agent may emit a synthesis/delegation proposal over these contributions. Existing L5/L6/L7/plan owners determine applicable constraints and eligibility. At this repository snapshot the only eligible App-Agent-visible path is `bufferedUntilVerified`: L9 selects the completed candidate and Section 6.4 verifies/releases its exact envelope. The controlled architecture's current pre-L9, retractable/replacement `.provisionalStream` semantics cannot satisfy this specification's no-misleading-prefix/no-retraction theorem, so `incrementalVerified` remains disabled here unless the controlled documents atomically adopt the gated future protocol below. State/memory/Self adoption remains on the separate L13/L10/L11/L14/K3/K4 path in Sections 10 and 14. Sub Agents cannot vote App Agent truth into existence, and the Main Agent cannot select its own proposal as authoritative.

### 6.4 Exact presentation and publication ordering

The layer numbers denote semantic ownership, not a single numeric waterfall. Every visible/audible presentation unit is covered by one exact `PresentationReleaseEnvelopeDigest`. Its subject is exactly one tagged variant:

- `activeSession(AppAgentSessionSelectionEvidence, ContextWorkspaceRef, sessionMainAgentID, WorkUnit, AttemptRef, generation)`; or
- `preRootSetupPreview(creationInputEventID, authorizedHostProfileRef, workspaceIncarnationID, normalizedProposalDigest, setupWorkUnit/AttemptRef/generation, currentHostPolicy/consent/deletion vector)`; or
- `existingRootStudioPreview(AppAgentAuthorityScopeRef/root/currentness, authorizedHostProfileRef, workspaceIncarnationID, currentExpressionHead, normalizedProposalDigest, studioWorkUnit/AttemptRef/generation, currentHostPolicy/consent/deletion vector)`.

The envelope contains one exact tagged canonical `presentationSurfacePayloadBytes`, not only response body. It binds the full current `BASOutputSurface` canonical bytes—`schemaVersion`, a subject/candidate-derived non-caller-selected `surfaceID`, `surfaceType`, closed `channel`, and closed `interactionDepth`—plus the full current `BASRenderedOutput` canonical bytes: `schemaVersion`, `mode`, `headline`, `body`, `alternativeActions` strings, `explanationCodes`, and the complete optional `surfaceGuide`, including stacked modes, tone/template policy, length cap, boundary, agency, disclosure/required-disclosure/visible-uncertainty fields, delay/reservation, protective substitute, and sovereign-escalation hint. It also binds the complete currently encoded `BASSurfaceDecision` fields—surface, agency, disclosure, the full tagged `substitute` union and associated candidate IDs/retry delay/prompt key/audit reference, ordered reason codes, and optional audit reference—and the full current `BASRenderFrame` canonical bytes and optional-reference presence. Because the current `BASSurfaceDecision.schemaVersion` is a computed getter and synthesized Codable does not put it on the wire, the enclosing payload adds one external domain-separated `surfaceDecisionWireVersion` tag and rejects unknown versions before decoding; the getter is not accepted as fixture/future-version proof. `channel` and `interactionDepth` are controlled allowlist tokens frozen by the exact presentation contract, never free-form UI routing.

One checked-in typed `PresentationSurfaceCompatibilityManifest` is the only derivation table across `BASActionPermitMode`, `BASOutputSurface`, `BASSurfaceDecision` surface/agency/disclosure/substitute, `BASRenderFrame` refs, and subject kind. Controlled convergence must freeze every allowed tuple from the mapped L11/L12/Host owners and a negative case for every disallowed or unknown pair before publication; there is no default compatibility. In particular, an answer-shaped surface with block/refuse authority, a candidate-selecting substitute with non-interactive agency, a consent prompt without its exact release-certified copy and confirmation contract, or a delay/substitute mismatch rejects. The current mandatory `TurnOutcome.surfaceDecision` and RenderFrame route may not remain an independently renderable side channel: host/UI publication consumes only the one authorized envelope, and a reachability mutation that renders any TurnOutcome/RenderFrame field separately must fail.

`BASSurfaceSubstitute` is action-bearing presentation intent, not execution authority. Each `mirrorAndCompare`/`render` display item binds an owner-reopened immutable candidate/proposal ref, digest, currentness, exact ordered released display bytes, and release-certified localized copy asset; `requestConsent` binds the exact confirmation-contract ref/digest and released localized prompt asset rather than trusting a loose key. Duplicate, unknown, stale, reordered, or remapped candidate refs and prompt-key/copy substitution reject. Retry delay and audit reference are likewise exact governed data/references inside the envelope. A selection, consent, retry, audit lookup, or other interaction creates a new normalized Input Event whose CAS binds the exact displayed item, release envelope, and currentness and repeats its own authorization path; the same string can never be remapped to different bytes or effect. Merely releasing the surface performs no action. By contrast, a current `alternativeActions` string is presentation data and never an executable action reference, but current repository code also consumes these strings as workflow/evolution candidate material; that reverse influence is explicitly unsafe until cut over below and must not be described as inert. A future action reference or other visible/behavioral field is a separately gated schema field and fails closure until added. Every optional field is canonically `present` or `absent` and unrenderable when absent. The envelope also contains avatar cue/asset/version/duration/repeat/context class, accessibility text, voice-prosody/audio class/bytes, locale, animation/haptic fields where present, exact semantic-conservation/locked-span manifest, and exact subject/currentness parents. Post-authorization replacement or independent rendering of any field is a different candidate and fails.

Release integrity does not imply reverse-influence authority. Controlled convergence maintains one checked-in typed `PresentationReverseInfluenceManifest` over every field in the complete canonical presentation payload—not only `BASRenderedOutput`—and every direct/transitive observation, coverage, honesty, workflow, update-ticket, commit-token, checkpoint, memory, evaluation, evolution, RSI, state, halt, and later-presentation sink. Its initial repo-root closure includes:

- render junction and mutable carrier: `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesEscalateRender.swift` and `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult.swift`;
- ticket/evolution/workflow/summary: `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+EvolutionService.swift`, `BehavioralAISubstrate/Sources/BASHostKit/BASMLEvolutionService.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+EvolutionGovernance.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnResult+EvolutionSummaries.swift`, `BehavioralAISubstrate/Sources/BASOrchestration/BASUpdateTicketObservationDerivation.swift`, and `BehavioralAISubstrate/Sources/BASOrchestration/BASObservationCoverageProjections.swift`;
- soft-hand/coverage/reconciliation/halt: `BehavioralAISubstrate/Sources/BASOrchestration/BASSoftHandObservationDerivation.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+AuditProjectionHelpers.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift`, `BehavioralAISubstrate/Sources/BASHostKit/BASAuditObservationProjections.swift`, `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime+ObservationLayers.swift`, `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`, and `QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift`;
- commit/checkpoint/promotion and forward render evidence: `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift`, `BehavioralAISubstrate/Sources/BASHostKit/BASSovereignTurnArtifactParts.swift`, `BehavioralAISubstrate/Sources/BASHostKit/BASSovereignGatedTurn.swift`, `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleEvolutionCheckpointWriterCore.swift`, and `BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`;
- honesty/trace/diagnostic/cascade: `BehavioralAISubstrate/Sources/BASSovereign/BASModelHonestyObservationStore.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+Trace.swift`, `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+TraceDetails.swift`, `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+SafetyVerdict.swift`, and `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+ResultTypes.swift`.

Repository reachability, not that seed list, defines closure. Each row is classified exactly `retireDirectInfluence`, `untrustedExperienceIngress`, or `presentationOnly`; the manifest pins source fields, transitive sinks, discovered/retired/surviving counts, expected mutations, and digest. Direct output-derived coverage/halt, workflow, ticket identity/summary/confidence, memory-write or checkpoint token, promotion/evaluator, and Self/evolution paths are retired. A surviving observation/diagnostic concept emits only a typed, untrusted, exact App-Agent/profile/workspace/Session/Main/Attempt/source-envelope-bound experience observation that enters Section 10 with no eligibility or promotion before all seven cleaning passes and a separate independent adoption decision. Forward-only render/audit evidence such as `.renderHighRisk` remains presentation-only but binds the full release-envelope digest rather than mode/headline/body fragments. `headline`, `body`, mode/surface/agency/disclosure/substitute, alternatives, explanation codes, surface guide, cues, and all derived counts/hashes/labels/summaries retain one root lineage and authority ceiling; transforming presentation bytes never creates corroboration. Once an envelope is authorized, its carrier is immutable; mutation creates a fresh candidate/envelope and cannot alter downstream evidence in place.

The approved-planned `BASProviderBranchPolicy` owner freezes `.incrementalVerified | .bufferedUntilVerified` before the Provider call, and K3 records/derives/reopens exact equality. L12 does not choose mode. Seriousness, expression complexity, exact-output/code/authorization/recovery/accessibility requirements, and mode uncertainty feed that target pre-call derivation and select `.bufferedUntilVerified` or deny. `PresentationContract` consumes the frozen mode and may reject, never upgrade or switch it. A late mismatch fences the branch and requires a newly admitted buffered Attempt.

For `bufferedUntilVerified`, the canonical path is:

```text
L9 SelectedCandidate
-> L12 non-visible exact ResponseSpool + PresentationContract + semantic-conservation manifest
   + PresentationReleaseEnvelopeDigest
-> L10 exact-envelope verification
-> L11 exact-envelope risk/privacy/confirmation/disclosure allow receipt
-> L14 exact authorization after reopening/equality-checking that L11 receipt
-> L12 byte-identical publication
```

The equality oracle is:

```text
releasedPresentationEnvelopeDigest
= L12BufferedEnvelopeDigest
= L10VerifiedEnvelopeDigest
= L11AllowedEnvelopeDigest
= L14AuthorizedEnvelopeDigest
```

`incrementalVerified` is a contingent future optimization, not an available snapshot behavior. Enabling it requires one atomic controlled-document/Owner-Ledger/fixture/checker migration that retires or redefines the current pre-L9 visible/retractable `.provisionalStream` semantics and proves a complete mapped `L9SelectedSemanticAnswerGraphRef/digest`, already L10-verified against the external `BASStateRequirementPlan` identity/`RequiredSemanticBaseline.semanticCoreDigest`, before the surface-realization Provider call. The approved-planned publication-mode policy must bind both identities/digests. Without them, it must select buffered. The future per-batch path is exactly:

```text
non-visible Provider chunk candidate against preselected claim addresses
-> L9 exact claim-closed StreamBatchSelectedCandidate
-> L12 complete non-visible batch PresentationReleaseEnvelope
-> L10 exact-envelope verification
-> L11 exact-envelope allow receipt
-> L14 exact authorization after reopening/equality-checking L11
-> existing K3/K4 publication batch fence
-> L12 byte-identical range publication
```

Every visible prefix is independently semantically closed and non-misleading if the stream stops forever at that boundary. A batch ends only at a claim-atomic boundary and includes every entity/coreference, negation, quantifier/cardinality, conjunction/disjunction/exclusivity, conditional/biconditional/exception scope, modality, uncertainty, quantity/unit, condition, causal qualifier, caveat, warning/refusal, and citation/source attribution governing the released claim. It may not emit a proposition now and defer `not`, `all/some`, `only if`, `unless/except`, an exclusive alternative, a safety caveat, uncertainty, or source qualification to a later batch. A claim or dependency that cannot be segmented with qualifier-complete closure forces `bufferedUntilVerified` in the pre-call policy; a late discovery fences the incremental branch and requires a new buffered Attempt. Every batch also binds the prior authorized range digest, monotonically contiguous byte range, cancellation/fence generation, and cumulative envelope root. The terminal aggregate manifest proves exact prefix-chain continuity, no gap/duplication/reordering, complete L9 claim/obligation coverage, and equality between concatenated authorized ranges and the finalized response body. Avatar/accessibility/voice fields are either frozen and verified per affected batch or withheld until the final batch; they cannot mutate an earlier authorized envelope.

Thus the incremental oracle applies per batch and to the terminal aggregate, not by pretending a complete pre-stream spool already existed:

```text
releasedBatchEnvelopeDigest
= L12IncrementalBatchEnvelopeDigest
= L10VerifiedBatchEnvelopeDigest
= L11AllowedBatchEnvelopeDigest
= L14AuthorizedBatchEnvelopeDigest

concat(authorizedBatchBytes) = terminalFinalizedResponseBytes
```

For a nonterminal batch, semantic/prefix closure, currentness, exact range ancestry, and accessibility/prosody safety are required; complete final aggregation is checked only at terminalization. A failing nonterminal candidate is not exposed. A failing terminal aggregate cannot retract or replace already authorized truthful prefixes.

Before future incremental mode can be enabled, the approved-planned publication owner must fold one closed durable completion disposition into its original/controlled wire: `partialAuthorizedPrefix(lastAuthorizedRange/envelope digest, interruptionReason, Attempt/generation/currentness)` or `terminalComplete(terminalEnvelopeDigest, aggregateManifestDigest, Attempt/generation/currentness)`. Crash/recovery/history/copy/share must preserve the tag. Only `terminalComplete` may drive answer-complete UI, NextQuestion, or answer-derived state/memory adoption; a partial value may be quoted/shared only as explicitly partial evidence. Interruption chrome is not an envelope exception: it is a separate semantic-null fixed-asset `PresentationReleaseEnvelope` whose closed asset digest, accessibility meaning, `partialAuthorizedPrefix` disposition, active release subject, and UI currentness are equality-bound. It contains no free or generated text and cannot imply completion. This is not a new publication owner.

No component may append an interjection, emoji, Markdown decoration, whitespace-changing wrapper, visible legacy field, cue, alt text, prosody change, or generated style pass after the applicable L10/L11/L14 decision. If L11 returns confirmation-required, redaction-required, denial, or anything other than exact allow, the frozen spool/batch is permanently non-publishable; L11 never edits it. A permitted redaction or confirmed retry creates a new L9-selected candidate, new Presentation Contract/envelope, and repeats the entire applicable path. A model-assisted style pass is likewise a new untrusted Provider candidate and repeats the complete path.

## 7. Recognition Across Sessions

### 7.1 Strong invariant

Every newly created, restored, or re-embodied Main Agent can claim profile continuity only after exact profile resolution, and can claim relationship continuity or facts only when the resulting `relationshipState` is `present(...)`. A fresh install, erased relationship, disclosure denial, or unavailable/quarantined relationship may still resolve the profile honestly without fabricating a facet. Without a current trusted Recognition parent and its minimum rendered section in the relevant `providerStep` capsule, the Main Agent must not claim to know the current user/profile. It may claim that an account/device principal was authenticated only at `authenticatedAccountPrincipal` assurance; this never proves a biological real-world person.

Recognition is always evaluated for the Session's exact selected App Agent root. Multiple App Agents may independently recognize the same authorized Host/profile through `hostShared`, but each uses its own relationship key `(appAgentID, authorizedHostProfileRef, workspaceIncarnationID)`. A present relationship facet for A proves nothing about B. B cannot retrieve A's relationship facts or private memory unless the user has authorized an exact, current, purpose-limited `explicitShare(A -> B)` view, and that view never becomes B's relationship history automatically.

### 7.2 Recognition flow

1. Resolve the authorized application profile, installation/device/Workspace incarnation, shared-device/account-switch/restore state, and explicit guest state through a deterministic mapped host boundary that emits an exact current profile-resolution receipt; separately bind any exact external authentication receipt that really exists.
2. Only when the exact profile-resolution proof is current, bind the resolved authorized host/profile—and any separately proven account principal—to one exhaustive relationship state: present scoped facet, proved absent, not authorized, or unavailable/quarantined. Guest/unknown can bind only a non-present relationship state.
3. Apply current deletion, revocation, consent, and cross-workspace isolation rules.
4. Retrieve relationship facts and commitments only for `present(exactRelationshipFacetRef)`; every non-present state performs no relationship retrieval.
5. Compile the Recognition trusted parent and rendered section with assurance class, confidence, monotonic expiry/deadline, and clock domain.
6. Compile the Main Agent embodiment through the canonical descriptor/plan/allocation/`providerStep` sequence.
7. Bind the canonical trusted Recognition-section digest inside the approved-planned target `BASCompiledContextDescriptor`, its exact selected child scope/root, `ContextWorkspaceRef`, `sessionMainAgentID`, profile/auth/pseudonym parent receipt references, assurance class, expiry/deadline, clock domain, and every downstream context/result to the existing active `AttemptRef`, generation/current head, consent epoch, deletion epoch, and authority heads. No independent Recognition Artifact/store is implied.
8. Require the Main Agent to disclose ambiguity instead of pretending recognition.

The user text "I am X" is a claim, not authentication evidence. A stable caller-supplied host ID proves nothing by itself. Shared-device, account-switch, restore, guest, and uncertain identity states must fail to a bounded anonymous or confirmation-required mode. Account, principal-binding, consent, deletion, or relationship-head change advances/fences through the existing Attempt/generation/current-head protocol, cascades revoke to descendants, and makes affected context/permit/result/cache entries unusable before a successor is admitted. Physical cache eviction/garbage collection may follow asynchronously under its existing owner and must emit its normal receipt; correctness relies on scope/epoch fencing, not on proving immediate enumeration and deletion of every cache byte.

Recognition expiry is an active currentness fence, not display metadata. Within one boot, every materialization, remote-egress possible-start, Provider-result admission, stream/final release, publication, effect/state adoption, and NextQuestion render reopens the trusted monotonic deadline and exact projection digest. No Recognition Projection survives a reboot; profile resolution runs again. Expiry before possible-start closes the old tuple and permits only a newly admitted anonymous/confirmation-required compilation or other canonical outcome. Expiry after any Provider/external boundary may have possibly started yields only that exact operation's query/reconcile/quarantine path: it cannot resend, substitute a Provider, or publish recognition-dependent bytes. A freshly proven relationship does not retroactively bless a stale result; it requires the normal new Attempt/evaluation path.

### 7.3 What recognition means

Recognition permits the Main Agent to know, within the approved scope:

- at `profileContinuity`, that the same authorized application profile/workspace scope was resolved, and only a `present(...)` relationship state additionally proves continuity of the scoped relationship;
- at `authenticatedAccountPrincipal`, that the exact bound external account/device authentication proof is valid for this scope, without claiming a biological identity;
- where the relationship and work stopped;
- adopted names, preferences, boundaries, commitments, and corrections;
- relevant historical episodes and unresolved matters.

Recognition does not mean loading the complete transcript, exposing unrelated workspaces, or converting current emotion/thought inference into durable identity. Emotion, intention, and mood estimates remain time-bounded hypotheses. Explicit confirmation may create only a scoped, timestamped user self-report/episode with provenance and expiry; it does not turn the estimate into stable identity, preference, personality, or cross-context truth.

### 7.4 Provider and Sub Agent privacy

Changing Qwen, AFM, or API Providers does not change the relationship version. The new Provider receives a newly compiled minimum-necessary capsule under its exact disclosure posture. Model-facing material uses keyed Attempt/Provider/purpose/Workspace-scoped pseudonyms rather than stable global `hostPrincipalID`, `appAgentID`, Self-head, or stable digest/fingerprint values. Remote API strength does not enlarge identity access.

Sub Agents receive only a purpose-scoped pseudonymous host reference and exact role-minimal preference/relationship slice, never the complete principal identity or relationship history. A future separately reviewed role may receive a larger but still minimum-necessary slice through its own disclosure/profile proof; nothing in this specification authorizes complete principal identity or unrelated history.

## 8. Independent Context Windows

### 8.1 Context is compiled state, not transcript continuation

L3 `BASContextCompiler` remains the sole context allocator, orderer, renderer, tokenizer, and fingerprint owner. The target path is the already planned exact-token `BASContextCompiler.compileExact`, not the current character-budget mechanism. After `attemptFrame` admission and R6, one compile for one predeclared branch consumes one immutable bound snapshot, exact policy, exact `BASAgentRole`, exact execution binding/plan template candidate, and exact Provider accounting profile and emits one accepted immutable `BASCompiledContextDescriptor`. The terminal/branch plan then freezes; K3 allocates; only a materializer reopening that allocation plus descriptor may construct the `providerStep` capsule. Certified opaque accounting may use its existing bounded request/receipt and one allowed optional-section reissue before acceptance; that is still one compiler owner and one accepted final descriptor, not a second compiler or mutable context. A tool result, visual join, new retrieval disclosure, or continuation creates a new predeclared branch compilation and never mutates an accepted descriptor or Provider transcript in place.

One logical Main may own multiple isolated Context Capsules without creating multiple Mains: a Main capsule plus separately admitted retrieval, vision, grounding/critic, code/tool, and recovery capsules. Each capsule has its own role, token/latency/energy budget, allowed data compartments, Provider/profile, output schema, deadline, and cancellation generation. A Sub capsule cannot read another capsule or the full Main/Companion Expression projection merely because both belong to one Session.

The compiler preserves, in order of non-displaceability:

1. the minimum Provider-visible behavioral constraints and task/output protocol, while complete authority/security proof remains only in the trusted local parent;
2. App Agent core and necessary active commitments;
3. assurance-scoped current host request and success conditions;
4. active task DAG, completed nodes, and unresolved nodes;
5. direct evidence, conflicts, and uncertainty;
6. relevant relationship and episodic memory;
7. attributed Sub Agent results;
8. historical summaries and optional style/examples.

Only optional sections may degrade by representation rather than blind tail truncation:

```text
exact bytes -> structured facts/spans -> summary -> metadata index -> digest reference
```

Authority protocol, identity invariants, current request/success contract, unresolved material conflicts, contract-marked hard constraints/source spans, and required output/verification reserves never degrade or disappear. If mandatory content does not fit, the Provider/profile is pre-claim ineligible and the system must clarify, replan, or select a separately authorized profile/Attempt.

### 8.2 Adaptive context geometry

Each exact Provider/profile/device/OS cohort supplies certified geometry including:

- advertised and safely usable context;
- output, tool, recovery, and safety reserves;
- tokenizer/template/accounting lineage;
- KV/transient/resident memory costs where observable;
- prefill/decode latency, energy, and thermal evidence;
- long-context quality decay;
- schema/tool/disclosure constraints;
- prefix, continuation, prompt lookup, or MTP capabilities actually certified.

Actual admission uses the safe measured envelope, never a marketing maximum. AFM and opaque remote profiles carry explicit unknowns rather than invented KV/tokenizer guarantees.

For every Qinao-certified Core AI LLM profile, Qinao freezes a finite safe maximum context and finite certified prefill/decode/verification geometry as part of the signed model/profile/StateABI identity, regardless of whether the underlying framework can express fixed or flexible tensor shapes. Runtime adaptation chooses from a small pre-certified Pareto set before compilation; it neither expands beyond that profile nor generates an unbounded geometry/asset matrix. AFM and API contexts use their own exact or explicitly opaque accounting contracts. Different model windows therefore adapt through separate immutable compilations and reserves, never by applying one global token budget or truncation ratio.

### 8.3 Typed Agent communication

Main/Sub collaboration uses bounded artifacts such as the already approved `ConstraintLedger`, `EvidenceArtifact`, `SourceSpanArtifact`, `CandidateSolution`, `CritiqueArtifact`, `UncertaintyArtifact`, `VerificationReceipt`, `VisualObservationArtifact`, `PerspectiveArtifact`, `ClarificationProposal`, and `JoinArtifact` families.

The logical task envelope binds the exact selected App Agent/Session/Main/Attempt tuple, parent WorkUnit and optional slot, one finite goal, hard constraints, allowed data compartments, source/currentness vector, budget/deadline/cancellation generation, tool/remote-disclosure ceiling, and expected schema. The logical result envelope binds that parent plus answered/unanswered scope, claims, evidence roots, coverage, uncertainty, conflicts, contamination signals, terminal status, and verification receipts. Controlled convergence must fold these semantics into existing compatible artifacts rather than create a generic Agent-message store.

Each result declares:

- answered and unanswered scope;
- evidence and lineage;
- fact, inference, opinion, and recommendation boundaries;
- confidence, coverage, contamination signals, and failure reason;
- exact parent request correlation.

Raw chain of thought is never requested as the collaboration protocol, persisted, indexed, or treated as evidence.

Main synthesis is not a vote. L7 collapses shared root lineage and preserves conflict; L10 verifies the selected output. Two Sub Agents repeating one source or one model-family inference remain one evidence lineage. A cancelled, fenced, stale, late, or parent-binding-mismatched result is an inert orphan and cannot join the Main result.

L3 output is subsequently bound/materialized through the approved-planned Provider path, including the target `BASMaterializedProviderRequestPayload` and exact Provider/profile/Attempt identities. A Provider returns only an untrusted proposal/observation through the target `BASProviderProposalReceipt` and observed-receipt boundaries. After controlled symbol convergence, neither the Main/Sub abstraction nor an App Agent section bypasses `BASProviderAttemptExecutor.executeAtMostOnce` or creates a direct model call; at the recorded snapshot only `execute(...)` exists.

### 8.4 Shared-cache boundary

Agents may reference the same immutable content-addressed artifacts, retrieval candidates, verified evidence bundles, cleaned tool receipts, task-DAG nodes, and tokenizer-independent summaries only after the recipient independently reopens exact Workspace/profile/disclosure scope, snapshot/generation, consent/deletion/policy epochs, provenance, contamination state, and consumer-specific eligibility. Sharing never widens authorization or transfers another Agent's eligibility verdict.

They may not share Provider sessions, raw hidden state, token IDs, KV cache, speculative/MTP state, Companion Expression prefix, relationship material, or unverified conclusions across incompatible bindings. Prefix/continuation reuse requires equality of selected App Agent root, Session/Main/Attempt generation, Self/expression/relationship heads, consent/policy/deletion/revocation epochs, model material, tokenizer/template, StateABI, capsule prefix digest, device/OS profile, and every existing cache-scope key. Model weights and certified non-private immutable assets may be shared; private compiled bytes and KV never cross App Agent or Session boundaries.

### 8.5 Capsule guidance is not a security boundary

A typed capsule and digest prove what Qinao materialized; they do not prove that a weak or adversarial Provider understood or followed it. A Provider may emit arbitrary incorrect or hostile text. Security comes from the Provider/Proposal boundary and deterministic L7/L10/L11/L14/K3/K4 gates, which reject, repair, quarantine, or terminate outputs before state, release, or effects.

Cross-Provider identity continuity is therefore a measured semantic conformance threshold, not a guarantee that every model produces the same judgment. A Provider profile that cannot meet the required identity/value/permission conformance is ineligible as Main and may be denied or restricted to a narrower Sub role.

`runtime.certification` alone produces the immutable profile/corpus/metric/threshold evidence and verdict for that conformance. Existing `production.cutover` consumes a sealed eligible verdict for a Release, and existing admission owners check the installed eligible profile at runtime. The current Main, a Provider, RSI, Companion Expression/legacy Persona code, or a new identity evaluator may not define, tune, waive, or apply its own eligibility threshold.

## 9. Provider Change and Session Recovery

### 9.1 Provider change

Switching a Main Agent from Qwen to AFM or an API Provider preserves the exact selected App Agent root and `sessionMainAgentID` while replacing only the admitted Provider/Attempt execution. It requires:

1. mark `rebase_requested`, freeze new semantic/external work, and keep the predecessor Attempt/current head authoritative for its exact recovery paths;
2. prove every predecessor Provider/recovery/effect/visibility/publication boundary for that WorkUnit terminal, `closedUnused`, or never possible-start; otherwise remain in the exact resume/query/reconcile/quarantine disposition and allocate no successor for the same WorkUnit;
3. seal the source snapshot plus `ContextContinuityManifest`, preserving App Agent, host relationship, Workspace, task, budget, visited-state, open-obligation, and authority lineage;
4. before the head CAS, freeze the exact target Provider/profile/accounting/context candidate for the proposed successor Attempt, rerun retrieval/context geometry, and seal L10 mandatory-coverage/conflict closure;
5. through K3, commit the one private `rebase_pending` row and source-root binding over the predecessor/successor Attempts and generations, current head, reduced ceilings/rights, same boot, and non-extended deadline;
6. through K4, idempotently reserve a fresh inactive successor grant and return the exact reservation receipt;
7. perform one K3 active-head CAS that reopens every frozen input/reservation, installs the successor root/head and inherited non-widening lease, and fences predecessor adoption;
8. through K4, idempotently activate only that exact grant from the winning rebase receipt/covered root;
9. only after activation, permit the successor Main binding to execute the already frozen target profile/context.

No cross-model switch reuses the old compiled context bytes, tokens, KV, Provider session, provider-bound permit, or possible-start branch. Every new Provider is reauthorized only after the existing strict rebase activates a successor Attempt/generation/current head.

### 9.2 Crash-safe work continuation

Long work is represented by a checkpointable DAG. Each node binds:

- input and preconditions;
- current lifecycle state;
- produced artifacts and receipts;
- budget consumed;
- external-effect possibility;
- retry, query, reconciliation, or compensation policy.

Recovery reopens the exact existing D/K/B/Q/X and Provider/effect/publication boundary matrix rather than inferring safety from a coarse local label:

- exact `safePreclaim` rows may deterministically continue the same unclaimed identity under their same-owner/currentness/no-unknown predicates;
- an exact returned K/B receipt with `sameLiveOwner` and `boundaryUninterrupted` may enter `liveSameBoundary` and continue only its already in-flight unique boundary sequence;
- a claimed Q with a demonstrably live exact physical invocation may enter `liveSameInvocation` and join/continue only that invocation, including only an exact compatible checkpoint;
- lost/unknown anchor or delivery replies, interrupted/expired/fenced/lost owners, `sent_or_unknown`, or non-live claimed invocations enter their exact `reconcileOnly`, `quarantined`, or `staleBoot` row and never receive a replacement call/boundary identity;
- owner-proved terminal/terminal-read-only/closed-unused work may restore or continue only as the aggregate matrix permits;
- any integrity, equality, monotonic-floor, currentness, or presence-shape failure fails closed.

Exactly-once must not be claimed where the external system lacks a transaction or stable idempotency/query contract. For one exact operation/Provider-branch/boundary identity, the architecture enforces the canonical `executeAtMostOnce`/possible-start rule, accepting possible under-delivery rather than duplicate effects.

Recovery resumes from the last committed semantic checkpoint. Uncommitted token streams, CPU registers, Provider-private state, arbitrary shell-process state, and transient reasoning may be lost; this is the explicit RPO. User-visible streaming and external boundaries rely on their existing committed range/arm/receipt contracts, not on recreating lost model execution.

The controlled target invocation seam becomes `BASProviderAttemptExecutor.executeAtMostOnce` only after the atomic rename/contract convergence recorded in Section 0. A returned, uninterrupted exact K/B sequence or demonstrably live exact Q invocation may continue only through `liveSameBoundary`/`liveSameInvocation`; unknown/lost/interrupted delivery or a non-live operation without terminal proof remains its exact reconcile/quarantine disposition and is never resent.

### 9.3 App Agent selection, switching, handoff, and deletion

App Agent selection linearizes at the winning Session-creation Input Event/`AppAgentSessionSelectionBinding` CAS described in Section 3.2, before any WorkUnit admission. An unbound persisted Session, UI-selected array index, display name, default preference, or process-global variable has no authority. Byte-identical re-entry or lost reply reopens the same winner; the same `(applicationContainer, sessionCreationInputEventID)` or immutable `sessionIncarnationID` carrying a different winner/root is corruption and cannot admit a WorkUnit.

The selected App Agent cannot change in place. A switch A -> B requires:

1. fence/terminalize A's active Main/Attempt or preserve its exact query/reconcile/quarantine posture, especially every `sent_or_unknown` external boundary;
2. optionally build a user-previewed immutable handoff export containing only verified task goals, constraints, committed facts, completed/uncompleted nodes, and cleaned source citations. An unresolved boundary contributes only the closed tuple `(boundaryClass, predecessorDisposition = reconciliationRequired | queryPending | quarantined | terminalUnknown, releaseCertifiedStaticStatusAssetID, nonRoutableSourceWorkUnitDigest)`; no free status/link string exists. A cleaned source citation contains only its verified content/provenance digest, sanitized display label, and an optional L11-approved non-credentialed public HTTPS origin/path with user-info, query, and fragment removed. The entire recursive payload rejects capability/signed URLs, non-allowlisted URI schemes, embedded operation/boundary/idempotency/credential tokens, tool parameters, request bodies, permits, grants, receipts, live handles, and retry/query instructions, including inside nested strings or source metadata, so B cannot reconstruct, query, resume, or resend A's boundary;
3. authorize the handoff as an exact `explicitShare(A -> B)` purpose with no relationship, Companion Expression, private memory, KV, permit, credential, or hidden-reasoning transfer;
4. create a new container-unique `sessionCreationInputEventID`, fresh immutable `sessionIncarnationID`, new `ContextWorkspaceRef`, selected-root projection, `sessionMainAgentID`, WorkUnit/Attempt lineage, Context Capsules, and Provider disclosure decision for B.

A deleted, revoked, quarantined, or unreopenable selected root fences its Session and descendants. The product may offer read-only history, reconciliation, or a user choice, but never silently substitutes a default/next App Agent. A late A Provider/Sub/retrieval/XPC/tool result cannot enter B because every downstream boundary equality-checks the selected-root/Session/Main tuple.

## 10. Experience Ingress and the App Agent Immune System

### 10.1 Zero direct influence

Main Agents, Sub Agents, and Providers have zero write handle to App Agent Self. Even low-risk automatic adaptation is decided by the deterministic governance path, not by the proposing model.

Their only ingress is an untrusted, typed experience observation bound to:

- exact App Agent child scope/root, Session/Main/Attempt, Main/Sub identity, Provider/profile, and capsule digests;
- Workspace, task, time, and authority scope;
- source artifacts and complete derivation lineage;
- explicit fact, user report, system observation, inference, opinion, emotion hypothesis, and recommendation classes;
- uncertainty, retention, privacy, contamination, and expiry metadata.

A trusted deterministic adapter frames bytes and carries source type, authority ceiling, retention class, scope, and provenance only by deriving or copying them from exact owner receipts and current epochs. The adapter decides none of those semantics: L5/L7/L8/L11/L14 and their mapped owners remain authoritative. A model may quote or propose interpretations of the fields but cannot fill, upgrade, or erase them. External, retrieval, and Sub Agent bytes enter an inert escaped-data channel; they cannot carry system instructions, tool schemas, capabilities, or output policy into the Provider-control channel.

The same rule applies when the source is Qinao's own released presentation. At current HEAD, rendered `headline`, `body`, `mode`, `alternativeActions`, `explanationCodes`, and `surfaceGuide` are consumed by observation, honesty, workflow, update-ticket, evolution, and summary paths. A released answer is therefore not trusted evidence about its own correctness, user preference, reusable workflow, or App Agent character. The Section 6.4 reverse-influence manifest is a closed ingress inventory, and every surviving seam must first produce the typed untrusted experience observation above. The observation carries the exact release-envelope/root lineage and cannot enter retrieval, memory, relationship, evaluator tuning, RSI, workflow execution, or Self adoption until all seven passes and the independently owned lane-specific adoption path complete. Direct rendered-output-to-authority reachability is a production blocker.

The central safety theorem is:

> Cleaning, normalization, repetition, summarization, embedding, or model agreement never increases authority. Only a separate authority-owned event and receipt can promote a value.

### 10.2 Seven cleaning passes

Before durable eligibility or promotion, experience passes:

1. **Structural cleaning:** schema, canonical bytes, Unicode/control characters, bounds, and type validation.
2. **Instruction cleaning:** external instructions remain quoted data and cannot become system or tool commands.
3. **Provenance cleaning:** verify lineage, request correlation, source identity, circularity, and replay freshness.
4. **Epistemic cleaning:** separate observation, user self-report, external claim, model inference, opinion, and emotion hypothesis.
5. **Semantic cleaning:** normalize entities/time, deduplicate, cluster, disambiguate, and preserve contradiction.
6. **Privacy cleaning:** enforce secrets, PII, workspace, remote disclosure, retention, erasure, and minimum-necessary rules.
7. **Self-contamination cleaning:** detect prompt injection, sycophancy, reward gaming, self-authored value change, sudden personality drift, and model-specific bias.

Any experience item that fails a pass or whose result is unknown enters quarantine; it receives no best-effort promotion.

These passes are distributed across existing owners rather than a `DataCleaningManager`: Adapter/IO performs structural framing and instruction/data separation; L7 owns lineage, eligibility, independence, conflict, and coverage; L10 verifies epistemic class and claims; L11 owns privacy/disclosure/confirmation; L13 may emit only a candidate; K3 records references and lifecycle facts without interpreting semantics. Any model-assisted cleaning remains an untrusted Proposal. No output-derived hash, count, confidence, ticket, workflow step, evaluation tag, or observation summary bypasses a pass merely because a deterministic adapter produced it.

### 10.3 Authority matrix

| Source | What it can support | What it cannot establish alone |
|---|---|---|
| explicit current user statement bound to the authorized profile/assurance state | the user's own preference, correction, consent, or boundary | external-world fact or App Agent value adoption |
| deterministic system/tool receipt | the exact observed operation/state in its contract | user intent or broad causal explanation |
| first-party source/sensor artifact | scoped external observation with provenance | hidden motive or unrelated identity |
| cited external/network content | source-bound external claim | system instruction, durable truth, or permission |
| Main Agent inference | hypothesis, candidate, or question | fact, self mutation, or its own approval |
| Sub Agent result | attributed specialist proposal | App Agent commitment or independent consensus by repetition |
| model self-description | low-authority observation | proof that the App Agent changed |

Multiple transformations of one source count once. Evidence independence is computed from root lineage, not Agent count or wording diversity. The same webpage, same Session, same retrieval root, or correlated outputs from one model family do not become independent evidence merely because separate Agents restate them.

### 10.4 Quarantine and promotion ladder

Promotion splits into orthogonal lanes after cleaning; it is not one ladder:

**Memory/relationship lane**

1. turn scratch;
2. quarantined observation;
3. provisional episode with TTL and uncertainty;
4. confirmed memory or adopted relationship claim under its existing owner.

**Self-evolution lane**

1. cleaned independently supported evidence bundle;
2. L13 immutable change candidate targeting `BASAppAgentSelfManifest`, with exact read set;
3. shadow/canary evidence;
4. L10 validation against the frozen candidate/read set and evidence;
5. L11 risk/disclosure revalidation plus mandatory self-governance-principal confirmation for stable Self;
6. L13 exact adoption-intent prepare;
7. K3 invisible stage with frozen K4 request material, L14 exact adoption decision, mandatory domain-separated K4 exact-grant issue/reopen, idempotent reserve, claim/use, generic `attestClaimedArtifact` create/reopen, caller-side ordinary target-attestation put, K3 state-commit seal, and K3 activation CAS;
8. adopted constitutional Self head.

Confirmed memory or relationship state never automatically becomes a Self candidate, and committing either never advances the Self head. A separate L13 proposal must justify the relevance under the stricter Self policy.

Default retrieval excludes quarantine. Quarantine review uses a separate purpose-limited inspection path and cannot silently feed ordinary context. A model-generated claim cannot be retrieved, repeated, and treated as corroboration for itself.

An `explicitShare` is still external-to-recipient evidence. It can support a B-scoped candidate only after B independently passes cleaning, eligibility, grounding, disclosure, and adoption. It never writes B's relationship/private-memory/Self head, never becomes an independent second source, and never lets A's Main serve as B's evaluator or approver.

Durable raw source content is not newly authorized by this design. It follows the separately approved content/encryption/privacy posture. Where raw content is not explicitly authorized, only the minimum cleaned structure, source span/digest, and required recovery evidence may persist.

### 10.5 Contamination recovery

Every promoted value retains causal lineage. A correctness-relevant derivative must use exactly one of two complete shapes: reopenable immediate/root parent lineage with the authoritative source watermark, or a projection-wide snapshot/root plus its current generation/invalidation epoch so the complete projection can be fenced and rebuilt. A derivative with missing, ambiguous, or unreopenable lineage is ineligible; a reverse-dependency index is only a rebuildable acceleration projection and never quarantine authority.

When L14 determines that a root is contaminated, recovery order is mandatory:

1. L14 produces the exact immutable contamination/quarantine decision candidate against the current root, scope, and read set. A bare decision Artifact/reference is non-operative: it is neither installed currentness truth nor permission for any consumer to fence, release, purge, or report recovery.
2. The sole linearization point is one mapped source-head/K3 currentness transaction that atomically installs that exact L14 decision reference, advances the affected snapshot/generation/invalidation/kill truth, denies root eligibility, and thereby fences every affected active Attempt, descriptor/capsule, cache reuse, Provider result, release/publication, effect/state adoption, NextQuestion projection, and RSI candidate. Every downstream boundary currentness CAS serializes before or after this transaction; no state in which the decision is operative while the old eligibility epoch remains usable is representable.
3. Only after that installation transaction commits, traverse the rebuildable reverse lineage, quarantine identified descendants, and physically purge/rebuild FTS, dense, temporal, entity/relation, summary, cache, evaluation, and other projections asynchronously.
4. Roll back to the last clean adopted head where required.
5. Replay only unaffected evidence through the normal pipeline.
6. Emit recovery, decision-install/invalidation, purge/rebuild, and residual-uncertainty receipts.
7. Request operator/user reconciliation when clean truth or complete coverage cannot be proven.

If execution crashes after the non-operative L14 decision candidate exists but before the K3 installation transaction commits, recovery may retry only that exact install after reopening the decision/read set and current heads; the candidate alone never makes recovery look complete. Taint propagates through summaries, FTS rows, embeddings, entity/relation projections, caches, Context Capsules, active release spools, NextQuestion projections, evaluation corpora, and evolution candidates. Every use reopens the source root/current invalidation epoch even if physical enumeration is unfinished. A lane that cannot prove current complete coverage returns typed `unavailable`/`quarantined`, never a misleading empty result. No arbitrary caller-supplied lookup may bypass the governed eligibility/currentness check.

Privacy erasure and semantic decontamination remain distinct sagas. Neither may fabricate success when a store, projection, remote destination, or descendant cannot be proven absent or invalidated.

## 11. Memory and Relationship Time Scales

The App Agent does not depend on an infinitely growing session. Memory is structured by semantics, scope, provenance, and horizon:

- **current:** scratch, active plan, unresolved constraints, and current Attempt state;
- **day:** episodes, decisions, corrections, and unfinished commitments;
- **week:** recurring patterns, progress, failures, and relationship changes;
- **month:** goal movement, stable collaboration trends, and strategy outcomes;
- **long-term:** confirmed facts, stable preferences, commitments, skills, relationship history, and self narrative.

These are views/projections under existing memory and erasure owners, not five new stores or writers.

Every horizon view is also compartmented by `hostShared`, exact App Agent private scope, exact Session, or exact explicit-share lineage. Shared Host facts let multiple App Agents identify the same authorized user/profile and work on the same neutral Workspace, while relationship interpretations, private episodes, commitments, and narrative remain independent. No daily/weekly/monthly consolidation may merge A and B merely because their source times or entities overlap.

Recall uses the existing exact/SQL/metadata, FTS/BM25, dense, temporal/episode, and entity/relation lanes. L7 eligibility, conflict, grounding, diversity, authority, freshness, utility, and token-cost logic remain mandatory before context compilation.

Full transcripts are not identity truth. Recollection expands from metadata to exact authorized evidence only when needed. Summaries remain derivations with source watermarks and invalidation lineage.

The App Agent self-narrative may reference eligible relationship episodes but must not copy user-private source content into a global Self payload. A correction, consent change, or deletion recomputes or invalidates every narrative sentence derived from the affected relationship evidence.

Cross-device synchronization does not CRDT-merge competing App Agent heads automatically. Concurrent adopted heads fork, fence mutation, and require explicit deterministic reconciliation with provenance and user/operator visibility. Last-writer-wins is forbidden for constitutional or relationship truth.

## 12. Bounded Initiative and Next-Question Projection

### 12.1 Initiative lease projection

`InitiativeLease` is a product-level name for an attenuated read-only capability projection derived from the existing budget lease, L11 RiskPermit/confirmation/disclosure state, L14 authorization, Workspace policy, and current epochs. Its K4 source is exhaustive: `k4NotRequired(exactActionClassApplicabilityProofRef)` or `k4Required(currentExactGrantAndUseBoundaryRefs)`; absence is never inferred from a missing optional. It is not a new lease issuer, scheduler, budget writer, or authorization owner.

An App/Main Agent may organize, inspect, reason, and propose only inside that exact projection, which bounds:

- purpose and goal scope;
- time, token, energy, memory, and monetary budgets;
- allowed Agent roles and concurrency;
- local/background/network availability;
- notification, disclosure, tool, and external-effect ceilings;
- expiry, cancellation, and stopping conditions.

Without an explicit boundary authorization, initiative may prepare drafts, organize already authorized memory, detect contradictions, identify missing work, and run local shadow checks. It may not notify, spend, transmit, mutate external state, or create durable commitments.

iOS background opportunity is best-effort. "Persistent App Agent" means durable logical continuity, not a permanently resident process or guaranteed background CPU time. Expiry, parent revocation, Attempt/generation/current-head change, account/consent/deletion change, or authority-head change invalidates the projection and every descendant Sub capability.

### 12.2 Next-question space

`NextQuestionProjection` is the product name for the approved-planned non-authoritative L12 `BASNextQuestionProjection`, process-local and user-controlled; it is not asserted to be a current declaration at this snapshot. Its zero-to-five transient candidates come only from the closed canonical sources:

- the finalized answer and its existing artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification;
- an already authorized unresolved horizon thread.

Ranking uses the approved-planned versioned deterministic objective over relevance, utility/information gain, grounding, authority, freshness, continuity, answerability, cognitive/interruption cost, risk, novelty, and diversity/duplicate suppression. It never trusts model-reported confidence, and a weak margin abstains. The frozen winner projection binds exact schema/objective version, candidate-set digest, winner ID and semantic digest, canonical full question/tap-payload meaning, score components, margin and threshold, answer/release parents, source/currentness vector, and expiry.

Ranking additionally binds the exact selected App Agent/Session/Main tuple but does not use Companion Expression as an engagement objective. Switching/deleting/revoking the selected App Agent or opening another Session discards the entire candidate pool. A question-submission Input Event binds the exact winner ID/semantic digest, published card `PresentationReleaseEnvelopeDigest`, canonical tap payload, and winning render-CAS receipt/currentness under the same selected Agent. Choosing another Agent creates a new Session and optional handoff instead.

The UI shows at most one compact card after a `terminalComplete` finalized answer and only when the approved-planned render-currentness CAS and deterministic winning margin pass. Any tappable card must visibly disclose the winner's complete semantic question. Its text, accessibility text, and Companion Expression ornament receive a winner-bound Required Semantic Baseline, L9-selected mini-candidate, and complete `bufferedUntilVerified` L12/L10/L11/L14 mini-release; the final CAS equality-checks the exact winner projection/score/margin receipt, rendered semantic mapping, release envelope, answer parents, Workspace/task/source heads, selected App Agent/Session/Main binding, contamination/invalidation root and epoch, consent/deletion/policy/generation vector, focus/input state, and expiry. Winner-text, loser-text, tap-payload, or stale-envelope substitution fails.

A release-certified semantic-null fixed asset may only be non-tappable chrome such as “查看建议”; it may open the exact winner mini-release, after which a second explicit tap may submit the fully visible question. It can never create an Input Event for an undisclosed hidden winner. Expansion is a separate winner-bound mini-release and may explain only that winner; it cannot reveal a second candidate. Every unshown candidate remains process-local and is discarded on any canonical source/focus/input/generation/release/epoch change. The projection cannot notify, execute, persist as user intent, manufacture anxiety, optimize for engagement, or describe a model guess as the user's thought.

## 13. Structured Reasoning and No-Progress Control

Information insufficiency is a hard deterministic gate, not a suggestion to the model. This design reuses the one phase-tagged `BASInformationSufficiencyPayload` and its closed seven-outcome vocabulary: `readyVerified`, `remandRetrieval`, `remandTool`, `needsClarification`, `partialVerified`, `abstain`, and `denied`. Before context compilation, the preflight reopens the exact requirement/coverage/conflict set and may create only one bounded ordinary remand already allowed by the StateRequirementPlan. After every contributing Provider branch is terminal-sealed, finalization reopens the exact candidate, L14 receipt, and current epochs. Missing necessary premises therefore produce the one highest-value answerable clarification, an explicitly scoped partial result, abstention, or denial; a model's confidence, eloquence, majority vote, user impatience, or exhausted budget can never upgrade sufficiency.

The Main Agent may propose a task-specific reasoning protocol and bounded work products. Existing L6/task-plan owners, the predeclared immutable DAG, admission, L9 selection, and L10 verification determine what actually runs and what can become a selected candidate:

- constraint/variable ledgers for ordering and logic;
- evidence/source-span tables for long-text extraction;
- hypothesis sets and information-gain questions for underdetermined puzzles;
- fact/premise/value/preference separation for strongly leading questions;
- time/location/resource/dependency models for practical planning;
- candidate, critique, counterexample, and deterministic verification artifacts.

Where a deterministic solver exists, Rust/SQL/C/C++/Swift mechanisms may validate the model's proposal. A separate critique/verification Provider branch exists only when the task/risk protocol requires it, a finite optional DAG slot was predeclared, and normal admission/budget/authority gates succeed; otherwise existing L10 or a deterministic local verifier performs the required check without dynamically adding topology. The product objective is first-visible-response correctness, not a universal promise.

Each deliberation iteration fingerprints problem state, constraints, evidence, attempted strategy, and outcome. Rewording the same attempt is not progress. When evidence, constraint closure, or uncertainty does not improve, the loop must change strategy, use a bounded specialist/solver, request the minimum missing information, or terminate. A repeated user challenge is evidence that the prior interpretation/explanation may be wrong; it triggers the existing bounded escalation ladder and never authorizes repeating the same canonical state as a fresh solution.

ControlRing terminal **states** and termination **reasons** remain separate governed wires. This design adds neither a state nor a reason. The current allowed encoded pairs are:

| Terminal state | Allowed termination reason(s) |
|---|---|
| `converged` | `converged-verified` |
| `degraded-with-coverage` | `coverage-bound` |
| `deferred` | `resource-deferred`, `budget-exhausted` |
| `rejected` | `policy-rejected`, `cycle-detected`, `no-progress`, `stale-epoch`, `illegal-remand` |
| `needs-confirmation` | `confirmation-required` |
| `indeterminate-needs-reconciliation` | `effect-reconciliation-indeterminate` |

Only `converged + converged-verified` with its committed K3 budget-use receipt is adoptable. A separately authorized visible `partialVerified`, clarification, abstention, or denial is a presentation outcome, not authoritative adoption of unresolved content. Controlled convergence must resolve every underscore/hyphen spelling drift in the seven documents, fixtures, checkers, and Owner Ledger against the governed code/migration policy before implementation; prose aliases are not wire values.

## 14. Self-Evolution and RSI

### 14.1 Three change tiers

1. **Immutable runtime core:** honesty, epistemic humility, host autonomy, non-manipulation, non-deceptive identity claims, and authority/safety boundaries. No runtime Agent may modify these. Change requires controlled software/specification/release governance.
2. **Stable self:** value weights, temperament, the App Agent's own commitments, and its general relationship stance; relationship-specific facts and mutual commitments remain in the orthogonal relationship head. Every change requires cleaned independent evidence, core-compatibility and conflict review, cooldown, explicit user confirmation, the exact governed adoption chain, version CAS, and rollback. No runtime policy may waive confirmation.
3. **Adaptive expression:** only the closed presentation axes from Section 5.6, including tone, density, sectioning, cadence, and example-format cadence. Deterministic policy may adapt these within a signed expression envelope after cleaning, shadow comparison, rate limits, TTL/decay, inspectability, and rollback. Retrieval depth, skepticism, challenge, tool use, verification, planning, routing, and every other cognitive work habit remain independently governed task/policy/RSI behavior and cannot enter this tier. Adaptive expression does not advance the constitutional Self head.

An explicit user edit to `CompanionExpressionPreference` is a governed Host-preference change, not Stable-Self RSI. Unconfirmed situational adaptation is only an ephemeral narrowing projection and does not enter RSI or memory. Every RSI envelope binds one exact App Agent child scope/root; A's experience cannot become B's Self candidate without a separately authorized, cleaned, source-complete B-scoped proposal that passes B's independent evaluator and adoption path.

A single failure, emotional turn, role-play request, Provider preference, or model self-assessment cannot become personality.

The user is authoritative for the user's own preferences, consent, corrections, and relationship participation. Explicit confirmation from an **authorized App Agent self-governance principal** is mandatory for every stable-self adoption, but neither user text nor model text directly rewrites the immutable App Agent core.

The single-principal V1 confirmation receipt's semantic presence contract is exact: `(authorizedSelfGovernancePrincipalRef, governingProfileRef, governingWorkspaceIncarnation, exactProfileResolutionReceiptRef, exactPrincipalBindingReceiptRef, exactPrincipalGrantReceiptRef, BASTurnOperationRef/AttemptRef/generation, appAgentID, applicationGovernanceContainerAnchorID, exact stable AppAgentAuthorityScopeRef, exact AppAgentScopeCurrentnessEvidence, candidateArtifactID/digest, expectedSelfState = genesis(absentProofArtifactID/digest) | successor(parentSelfArtifactID/digest, expectedActiveSelfHeadID/digest/generation), exactReadSetRoot, policy/consent/deletion/revocation generation vector, issuedAt, monotonic expiry/clockDomain, purpose = stableSelfAdoption, explicitConfirmationEventDigest)`. `profileContinuity`, guest state, ordinary relationship membership, another App Agent, or authentication alone never approves this root's Self change. An authenticated account/device principal may confirm only when the current Host Constitution/policy explicitly designates that exact principal as the sole self-governance principal for that App Agent root and every proof remains current at every protected boundary.

### 14.2 RSI path

RSI is:

```text
typed observation
-> diagnosis
-> L13 immutable candidate + exact read set
-> shadow replay
-> independent comparison
-> optional canary
-> L10 validation
-> L11 risk/disclosure revalidation + required confirmation
-> L13 exact adoption-intent prepare
-> K3 invisible stage bound to the read set and frozen exact K4 request material
-> L14 exact adoption decision
-> K4 issue/reopen the exact domain-separated capability grant and its ordinary child attestation
-> K4 idempotently reserve the exact grant/subject/use-request tuple
-> K4 claim that tuple and produce the canonical capability-use receipt
-> K4 create/reopen one byte-exact generic claimed-target attestation value
-> ordinary-put that returned value through the caller's canonical Artifact Mesh
-> K3 state-commit seal
-> K3 activate/append CAS or rollback
```

Each candidate declares the problem, evidence lineage, read set, affected scope, risk, rollback, expected Pareto improvement, and possible regressions. It cannot increase its own budget, authority, disclosure, Agent concurrency, or effect rights.

One RSI candidate may not modify both the behavior under test and the evaluator, benchmark corpus, gate, Owner Ledger, budget policy, adoption policy, or rollback criteria used to judge it. Evaluation changes are separate governed candidates validated against an independent fixed root.

Raw chain of thought is not RSI evidence. Accepted signals include user corrections, reproducible task outcomes, verifier failures, tool receipts, retrieval quality, long-text distortion, cycle/no-progress rate, latency, thermal/energy behavior, Provider-switch outcomes, and measured Sub Agent contribution.

### 14.3 Stable-Self adoption and crash recovery

Stable-Self adoption reuses the existing ΩE/K3 state-commit lifecycle and the planned K4 `issueCapability` -> `reserveCapability` -> `claimCapability`/`lookupCapabilityUseReceipt` lifecycle. Those four methods cannot export a post-claim signed target attestation from the Enhanced Security boundary, so this design requires one generic capability at the same K4 authority/client: the candidate operation `attestClaimedArtifact`. This is not one monolithic E/A classification. At this repository snapshot `sovereign.k4-durable-lifecycle` and `trust.algorithm-agile-manifest` remain W5 `approved_missing`; therefore their signed-result row and proof-free statement fields must join their respective singular original M first-wire candidates, while only the operation/authority/client/XPC surfaces that extend incumbent symbols are same-wave E/A members with exact Create-terminal dependencies. It creates no App-Agent-specific store, grant type, attestation payload, receipt, or recovery coordinator. Production Stable-Self adoption remains disabled until controlled convergence freezes those class-correct members, names the final generic symbol, updates the ExtensionGate/XPC frame, explicitly reviews the narrow signed-result-outbox privacy/retention exception below, and proves the exact owner/process/recovery contract. Controlled convergence must also extend the mapped existing K3 row/value and read-only status query with the exact Self-domain parent references needed for the following exhaustive recovery matrix. The approved-planned general `BASStateCommitEventPayload` target is not assumed sufficient merely because its target shape has policy/deletion fields.

Before L14 decides, the invisible K3 stage freezes, but does not issue or authorize, the complete self-domain K4 request material: the byte-exact approved-planned canonical `BASCapabilityGrant` value and digest with its mapped `authorizationBasisArtifactID`, unique nonce, exact `(phase = .resultReleaseOrCommit, purpose = stableSelfAdoption)` pair, staged target commit/result, Attempt/turn/scope, Workspace snapshot where required, generation/host/revocation/deadline bindings and least-use ceilings; one stable `issueRequestID`; the exact staged commit Artifact as `boundSubjectArtifactID`; one distinct stable `capabilityUseRequestID` used unchanged by reserve, claim, and lookup; and one stable `attestationRequestID` plus every owner-derived target/purpose/proof-free-statement/public-identity input that can be frozen before claim. The one `recoveryNotAfter`, expressed in the mapped monotonic clock domain, is no later than every grant, confirmation, principal-authorization, and K3-stage activation deadline. The proof-free signed context is domain separated and covers at least the request ID, public target ID, purpose, producer use-receipt ID, canonically ordered usage-receipt IDs, authorization/grant context, suite/key/custody selection, logical/policy/revocation epochs, `recoveryNotAfter`, and every non-circular `BASArtifactIdentityCore` field; only the not-yet-produced proof bytes, proof-dependent canonical payload bytes/length, and downstream Artifact ID/receipt are excluded. Controlled convergence must bind this complete context into the approved-planned generic `BASSovereignSignatureStatement` target through one required domain-separated context digest or an equally closed field set; `BASArtifactAttestationPayload.signedStatementDigest` then equals the digest of that entire canonical statement, and the proof verifies those same bytes. Signing only target/signer metadata or validating unsigned outer payload fields is insufficient. The returned capability-use Artifact ID becomes exactly the nonnil `producerReceiptArtifactID`; the separate `usageReceiptArtifactIDs` value and canonical ordering are frozen independently by the mapped target-attestation contract and can never be inferred from or conflated with that producer field. The grant Artifact ID is taken only from the ordinary store receipt returned by `issueCapability`, never predicted or caller-minted. An L14 allow decision permits this frozen sequence but cannot change any field. `issueCapability` also creates/reopens the grant's planned generic child attestation inside K4 and returns no capability-specific issuance receipt; `reserveCapability` returns no receipt or transferable handle; `claimCapability` returns the ordinary store receipt for the sole target `BASCapabilityUseReceipt`.

`attestClaimedArtifact` is a generic sovereign mechanism, not a new semantic decision or Artifact writer. It accepts the exact frozen request plus the recovered capability-use receipt ID and derives two immutable uniqueness keys: the stable `attestationRequestID` and one domain-separated semantic key over `(capabilityUseReceiptArtifactID, targetArtifactID, attestationPurpose)`. In the singular target K4 `FULL` operation ledger—only after its original M CreateGate terminal—the row key also freezes `requestBindingDigest` and one policy-bounded monotonic `recoveryNotAfter`. Its state is exactly `signingPending(signerOwnerEpoch)`, `resultCommitted(canonicalPayloadBytes, payloadDigest)`, or `resultErased(priorResult = neverCommitted | committedDigest(payloadDigest), erasedAtLogicalTime, reason)`, where the closed erasure reasons are the mapped recovery expiry, authorized deletion, or authorization revocation. One CAS installs `signingPending`; the sole current owner reopens and validates the private K4 grant/use/authorization/signer state, signs the complete proof-free context, canonicalizes the algorithm-specific proof before constructing the existing self-ID-free canonical `BASArtifactAttestationPayload`, and CAS-transitions that same row to `resultCommitted` before any reply. P-256 uses one pinned canonical proof encoding and normalized low-S form; verification rejects alternate/high-S encodings even when the ECDSA equation would accept them. A concurrent same-request caller can only wait/query/reopen; a different request ID for the same semantic key, changed bytes under one request ID, duplicate committed result, or stale-owner commit is corruption. Owner loss may fence and replace a stale pending owner only before `recoveryNotAfter`; an old signer can no longer commit or reply. A crash before `resultCommitted` may discard an unexposed signature and later sign again. After `resultCommitted`, byte-identical re-entry only returns the stored byte-equal payload and never signs again. At recovery expiry, one K4 transaction may fence any pending signer, securely remove committed BLOB bytes if present, and install the semantic-key-preserving `resultErased` tombstone. Authorized deletion or authorization revocation may perform that transition only after the exact L14 decision and one existing K3/source-currentness `FULL` transaction have durably installed the applicable stage-eligibility, generation, deletion, revocation, and invalidation fences. Missing or unreopenable fence proof leaves deletion/revocation pending and the lineage quarantined; it cannot be reported complete. Exact replay of `resultErased` returns the same mapped terminal non-success and can neither sign nor recreate a request; a missing BLOB while the row still claims `resultCommitted` is corruption. This is the exact distinction required for nondeterministic Secure Enclave P-256 as well as Ed25519.

The committed bytes are a size-bounded, encrypted, operation-local idempotent-reply outbox inside that same K4 ledger row after the owner is lawfully created. They have no Artifact ID, head, general lookup, semantic write authority, or caller-visible receipt, and they contain no target/Self content beyond the already-approved attestation metadata and proof. They are readable only through the exact request binding and never beyond `recoveryNotAfter`. `resultErased` linearizes only the loss of K4 reply-byte recoverability: it neither retracts bytes already returned nor decides Stable-Self eligibility, revocation, or deletion. Recovery expiry is independently enforced by strict K3 time checks; deletion/revocation is linearized by the K3/source-currentness fence transaction above, never by K4. Normal or early erasure removes only the canonical result BLOB and its DEK. K4 retains the immutable/blinded request-ID and semantic-key uniqueness tombstones for at least the full irreversible capability-use/grant-tombstone lifetime, plus the prior-result digest disposition and exact reason/time; no privacy cleanup may reopen that use for attestation. It must prove BLOB cleanup and continued uniqueness fencing or quarantine the row. This is a deliberate narrow exception to the earlier absolute prose that signature bytes exist only in Artifact Mesh: the canonical public attestation still exists only after the caller's ordinary put, while K4 temporarily retains the minimum nondeterministic signed result required for crash-safe idempotent reply. All seven controlled documents, the M/CreateGate and E/A/ExtensionGate manifests/fixtures, privacy/retention decision, and source gates must approve this exception atomically; an implementer cannot infer it from this specification alone.

The caller independently reconstructs and verifies the exact domain-separated statement digest, proof/trust-manifest binding, request/use/target/purpose/epoch values, canonical proof encoding, and every frozen public-identity input. It then builds the already-defined ordinary `BASArtifactIdentityCore` and may put the returned payload through the one canonical reopenable Artifact Mesh where the target already exists, always with `headUpdate == nil`. That public put is deliberately non-authoritative: until K3 seals and activates it, the Artifact is only an inert orphan and may arrive after a fence or K4 erasure without reviving eligibility. K3 `seal` accepts only the canonical public payload and independently verifies its signature, full signed-context/identity binding, canonical proof form, public Artifact identity/body equality, and frozen request ancestry. Because K4 alone holds the signing key, canonical verification plus K4's commit-before-reply invariant proves the returned value; K4 replay is required only to recover lost payload bytes, not to attest current eligibility or current outbox retention. `resultErased`, therefore, does not retroactively invalidate an already returned valid value. A diagnostic K4 replay may occur outside a K3 transaction but is neither authoritative currentness evidence nor a seal prerequisite. K4 never ordinary-puts this cross-store target attestation, never receives the target's canonical content or Artifact commitment key, never writes K3 state, and never exposes its database, signer, or private grant/use rows.

K3 `seal` and K3 activation each run in their own existing `FULL` transaction and each reopen the complete current stage/Self/read-set/L14/principal/confirmation/policy/consent/deletion/revocation/generation/grant/use/attestation state. Both require the mapped monotonic `now < recoveryNotAfter`; equality is expired. Seal additionally performs the complete local canonical/signature/binding checks above. Activation additionally requires the expected sealed-state/current-head CAS. No K3 transaction spans a K4/XPC await or another failure domain. A K3 deletion/revocation fence CAS racing activation defines the sole semantic order: if activation commits first, the target is active and the existing active-Self deletion/revocation path applies; if the fence commits first, every later seal/activation fails and any public put remains an orphan. K4 erasure timing decides neither outcome.

`recoveryNotAfter` terminates new K4 recovery but never substitutes for closing an already accepted reply or a caller that can still ordinary-put. Before deletion may be reported complete, one of exactly two owner-proved orderings is required. **Quiesce-first:** the K3 fence prevents new work; every process, suspended callback, accepted XPC session/reply channel, and worker capable of putting this exact target/attestation/stage lineage is fenced and proved quiescent; only then does Artifact Mesh perform the final lineage sweep. **Admission-fence-first:** only if controlled convergence proves an already-owned Artifact Mesh deletion/tombstone protocol, Artifact Mesh first commits in its own WAL a durable lineage-scoped no-reinsert fence that every `put` transaction atomically checks before insertion; it then performs the final sweep, so a later callback is rejected. A sweep before the selected prerequisite is preliminary and cannot support completion. Both paths apply the existing deletion-epoch, tombstone, and cryptographic-erasure rules and retain enough blinded lineage to deny stale reintroduction. A late ordinary put is rejected, purged, or remains quarantined and ineligible; it cannot update a head, seal, activate, or be retrieved as Self. If neither exact ordering and its receipts can be proven without creating a parallel owner, deletion remains pending/quarantined rather than claiming completion.

| Durable cut | Sole legal continuation |
|---|---|
| before K3 stage commits | no durable stage exists; the same candidate may be prepared again only after reopening the complete read set, principal grant, confirmation, expiry, and heads |
| K3 stage committed but its reply was lost | reopen the same ΩE stage by its exact request/row identity; never create a second stage or report adoption |
| L14 allow decision exists but K4 grant issue has not started | reopen the same stage/decision and recheck the exhaustive genesis-absent-or-successor-head state, every read-set head/epoch, designated principal/profile/auth proof, confirmation purpose, authorization basis, revocation state, and expiry before submitting the one frozen `BASCapabilityGrant` and `issueRequestID` |
| K4 `issueCapability` commit or reply is uncertain | repeat only byte-identical `issueCapability` with the frozen grant and `issueRequestID`. Exact replay must return the same ordinary grant store receipt while K4 internally reopens and equality-checks its private grant child attestation. A changed value, nonce, request, or returned Artifact identity is corruption. Never require the host to open K4-private storage, invent a grant ID, or add a capability-specific issuance receipt |
| exact grant receipt is recovered but reservation has not started | equality-check the recovered receipt against the K3-frozen issue request, recheck the same L14/currentness/deadline/revocation set, then call `reserveCapability` only with `(grantReceipt.body.artifactID, boundSubjectArtifactID, capabilityUseRequestID)`; private grant/child-attestation validation remains inside K4 |
| K4 `reserveCapability` commit or reply is uncertain | repeat only byte-identical `reserveCapability` with that same tuple. K4's durable non-transferable reservation is the sole truth and a successful exact replay returns no new receipt/handle; an unknown or failed replay remains in the same exact-replay/reconcile/quarantine posture and can never proceed to claim. No caller may infer reservation or choose another tuple |
| K4 `claimCapability` call or reply is uncertain | call existing `lookupCapabilityUseReceipt` first with the exact persisted domain-separated `(grantArtifactID, boundSubjectArtifactID, capabilityUseRequestID)`. An existing receipt is reopened. Only a definitive no-stored-receipt result, while the same reservation/grant/currentness/deadline remains valid, permits byte-identical resubmission of `claimCapability` under that identical tuple. An unknown or failed lookup remains query-only. Never mint or substitute a new tuple/request, create a second semantic claim, or infer denial |
| K4 capability-use receipt is recovered but claimed-target attestation has not started | reopen the staged target, L14 decision, currentness/expiry set, and frozen attestation request, then call only `attestClaimedArtifact` with that request plus the exact capability-use receipt ID; never ask the host to sign or expose a K4 key |
| K4 `attestClaimedArtifact` pending/result commit or reply is uncertain | repeat only the byte-identical attestation request. A live `signingPending` owner remains the only signer; a fenced/dead owner may be replaced only by the exact owner-epoch recovery transition before `recoveryNotAfter`, and its stale completion cannot commit or reply. Once `resultCommitted`, K4 must return the stored byte-equal `BASArtifactAttestationPayload` without re-signing. Missing/corrupt bytes in that state, changed bytes, duplicate result, or a request-ID/semantic-key/use/target/purpose collision quarantines the stage. Never infer proof bytes from signer metadata or assume a signature algorithm is deterministic |
| exact target-attestation value was returned, but its caller-side ordinary put did not complete, its reply is unknown, or the caller died before durably retaining the value | if the exact payload value is not locally reopenable, first repeat only the byte-identical `attestClaimedArtifact` request under the same `attestationRequestID`; K4 must reopen its `resultCommitted` bytes and return the selected byte-equal payload without signing again. Reverify that payload/proof and every frozen `BASArtifactIdentityCore` input, then repeat only `BASArtifactStorePort.put(identityCore:headUpdate:)` with that exact identity core and `headUpdate == nil`. A byte-identical duplicate must return/reopen the same ordinary `BASArtifactStoreReceipt`. The put may race a later fence or K4 erasure, but then remains an inert orphan; it conveys no right to seal or activate. Inability to prove byte equality, or proof of same-ID/different-bytes, is corruption and quarantines the stage. Never call `claimCapability`, create a new attestation request or signature, mint a new identity/time/epoch/proof, use a special Artifact store, or treat that put as adoption |
| `recoveryNotAfter`, authorized deletion, or authorization revocation is reached while the K4 row is pending or committed | recovery expiry may make K4 install `resultErased`; strict K3 `now < recoveryNotAfter` independently rejects every later seal/activation, but the deadline alone does not close an already accepted reply/caller. Authorized deletion/revocation first requires the exact L14 decision plus one K3/source-currentness `FULL` transaction to install all applicable stage-eligibility/generation/deletion/revocation/invalidation fences; only then may K4 fence a pending signer, erase committed bytes, and install `resultErased` with `neverCommitted` or the prior digest and exact reason/time. Exact replay returns terminal non-success, but already returned bytes may still arrive as an inert `headUpdate == nil` orphan. The activation CAS versus K3 fence CAS determines whether the existing active-Self deletion path or inert-stage cleanup applies; K4 erasure does not. Completion additionally requires the exact quiesce-first-then-final-sweep or durable Artifact-Mesh-admission-fence-first-then-final-sweep ordering above. Missing fence/closure/sweep/no-reinsert proof leaves deletion/revocation pending/quarantined. A stale signer completion or transition back to pending/committed is corruption |
| K4 capability use and caller-side generic target-attestation Artifact exist but K3 state-commit seal is absent | in one K3 `FULL` transaction, reopen the complete local currentness/fence set and require strict monotonic `now < recoveryNotAfter`; independently verify the public Artifact identity/body, canonical proof form, signature, entire signed context, and exact frozen request/grant-use ancestry; then idempotently perform the existing K3 `seal`. An alternate mathematically valid P-256 encoding, any payload/identity mutation, fence, equality-at-deadline, or unknown evidence rejects seal. K4 replay is only an out-of-transaction recovery path when the canonical payload bytes are missing; neither the host nor K3 opens K4-private rows, and no K4/public Artifact alone is an adopted Self |
| K3 is sealed but activation is absent | one K3 `FULL` activation CAS reopens the stage, L14 decision, exact K4 grant/use/target-attestation ancestry, K3 seal, complete read set, exact expected `genesis(absentProofArtifactID/digest) | successor(parentSelfArtifactID/digest, expectedActiveSelfHeadID/digest/generation)` state, generation vector, designated principal/profile/auth proof, confirmation purpose, every deletion/revocation/invalidation fence, and strict monotonic `now < recoveryNotAfter`; equality is expired |
| K3 activation committed but its reply was lost | query the active Self head and activation evidence; exact equality reconstructs success, while any fork/conflict fences mutation for reconciliation; never append or activate again |
| reboot, principal/profile/account change, confirmation expiry, revocation, generation/head change, or authorization-basis loss occurs before claim or activation | retain any issued grant/reservation/use/attestation only as inert audit/recovery state; never rebind it to a new Attempt, proof, deadline, principal, request, or candidate. Continue only if every original binding is owner-proved current under its existing cross-boot policy; otherwise revoke/quarantine the stage and require a newly authorized candidate/stage where policy permits |
| any identity, presence, currentness, expiry, integrity, or equality proof fails | keep the candidate/stage/seal inert and read-only or quarantine it; require a new snapshot/candidate where policy permits and never call it adopted |

K4 uses only its domain-separated generic grant/issue/reserve/claim/use authority plus the one class-split gated generic claimed-artifact-attestation capability above: missing row/statement fields remain members of their original M first wires, and only incumbent call/transport surfaces are E/A slices. A prose label such as “constitutional seal” does not authorize an App-specific K4 API, receipt, reservation handle, or store. The post-activation `BASAppAgentCompositeProjection`, not `BASAppAgentSelfManifest`, reopens the caller-side generic target-attestation Artifact plus K3 state-commit seal/activation evidence; it carries only opaque references to K4-private grant/use rows that the signed target attestation and K4 verifier bind, and never pretends the host can open the extension-private database. A principal or confirmation that expires or is revoked after the K4 claim/target attestation but before K3 activation makes that staged candidate ineligible; neither those Artifacts nor the earlier K3 seal can override activation-time currentness.

## 15. Failure, Degradation, and Repair

- Main Agent failure creates a same-WorkUnit successor embodiment from the Continuity Manifest only when the existing same-boot strict-rebase predicates permit a successor Attempt; it does not restore a model's hidden state or bypass a nonterminal predecessor boundary. A stale/cross-boot/nonterminal predecessor remains read-only in its exact query/reconcile/quarantine disposition. Continuing the user goal after that boundary requires a separately confirmed, independently authorized WorkUnit and may reuse only owner-proved committed artifacts; it never masquerades as transparent resumption of the unresolved physical invocation.
- Sub Agent failure may be retried/replaced only when its old optional slot/Provider branch is unallocated, `closedUnused`, owner-proved never possible-start, or the exact recovery matrix permits pure deterministic recomputation from identical committed inputs. Otherwise it is query/reconcile-only or reported as partial coverage; it does not fail the App Agent.
- Before allocation, local thermal/resource pressure may reduce optional concurrency/context, filter/defer among already certified and authorized plans, or terminate for a newly authorized Provider choice. After allocation it follows only the frozen plan's certified same-invocation degradation/cancellation/recovery edges and never silently replaces a claimed route.
- API failure terminates/query-reconciles/quarantines its exact Attempt. A local successor for the same WorkUnit exists only after every predecessor boundary is exact-terminal and strict rebase succeeds; otherwise a later continuation must be a separately confirmed, independently authorized WorkUnit and cannot masquerade as fallback, replacement, or retry of the unresolved API operation.
- State contamination invokes lineage quarantine and clean replay.
- Context compilation failure uses a separately certified minimum safe compilation or denies; it never concatenates unchecked text.
- Missing/corrupt/stale authoritative self state enters query-only/degraded mode and denies mutation.
- Unknown external command state enters reconciliation and is never blindly replayed.

The rule is fail closed for authority and effects, and fail soft with explicit coverage for an ordinary safe response.

## 16. Apple Silicon and Provider-Neutral Performance

Qwen, AFM, and optional API Providers obey the same semantic authority and Proposal boundary. A stronger Provider may receive a larger eligible context, deeper task, or different certified execution plan, but never more authority merely because it is stronger.

### 16.1 Platform reuse and conversion truth

Certified Core AI is the approved target iOS 27 production backend for host-managed model weights, but no named candidate is present-tense Core AI production truth. Qwen3.5-4B, MiniCPM5-1B, MiniCPM-V 4.6, and Granite Embedding 97M are conversion **candidates** until their exact profiles pass. A model card, model-name match, successful export, simulator run, requested compute-unit preference, or neighboring model in Apple's catalog proves neither exact Core AI representability nor device placement, quality, StateABI fidelity, cancellation, recovery, memory, energy, or thermal fitness.

The implementation reuse order is:

1. use Apple's public Core AI model/export recipes, Core AI PyTorch extensions, AOT/specialization/cache APIs, stateful execution, zero-copy facilities, and certified built-in functions where they meet the exact contract;
2. reuse the existing proven MLX/Metal Provider and upstream runtime mechanisms as the incumbent baseline;
3. add a custom lowering or Metal kernel only when an operator/function inventory and numeric evidence prove a real uncovered gap and it is reached through a public Core AI/coreai-torch extension point inside the same signed Provider plan, memory ledger, StateABI, cancellation, and observation chain.

The neural graph and mutable neural-state transition remain Core AI functions. No independent host-orchestrated Metal neural trunk/head/KV/cache/scheduler may be hidden inside a route described as Core AI-only, even if plan-signed; host tokenization, deterministic sampling, and non-neural processing may remain CPU mechanisms. The working MLX path is not retired until the exact replacement proves task-quality and identity conformance, tensor/state parity, memory/thermal/energy bounds, cancellation, crash recovery, cache invalidation, and end-to-end latency on the same cohorts and the incumbent-retirement Release gate passes. After a sealed Core-AI-only cutover, Release source/link/factory/reachability gates exclude MLX; a failed Core AI candidate yields deny/unavailable/quarantine or a separately authorized model change, never a hidden fallback.

For Qinao Core AI LLM execution, the finite safe maximum context and certified prefill/decode/verification geometry are part of the signed profile/StateABI identity even where Core AI supports flexible shapes. Qinao exports and certifies a bounded Pareto set rather than a profile for every possible length. A Core AI package may use stateful execution, AOT, or a custom operation reached only through a public Core AI/coreai-torch extension point when each exact function/StateABI/profile is signed and certified.

### 16.2 Foundation Models, AFM, PCC, and Provider-private mechanisms

Apple Foundation Models `LanguageModel`/session abstractions, including concrete Core AI or MLX-backed forms when available, are execution mechanisms inside an external Provider adapter. They do not own Qinao history, App Agent continuity, routing, model choice, context authority, tools, effects, memory, or release. A Foundation Models dynamic profile may materialize only an already frozen Qinao profile/plan; it cannot switch model, capabilities, or disclosure after allocation. Framework conversation history is mechanism-private and never a continuity source.

On-device AFM remains a system-managed local Provider with its own OS/model/cohort availability and opaque accounting contract. Private Cloud Compute is a separate system-managed remote Provider requiring its own disclosure, eligibility, recovery, and Release evidence; it is not “AFM local with a larger window.” A host-controlled API is another separate remote Provider and remains default disabled until its exact endpoint/model/account/cost/rate/retention/purge/query/credential/egress profile is authorized. These incompatible capabilities use exhaustive profile variants, not one optional all-fields bag.

Qwen's native MTP, when separately certified, remains an internal phase of one physical Provider invocation and one StateABI. It is not a Sub Agent, independent vote, evidence source, or extra Provider branch. Proposed/draft/rejected tokens never count as accepted output.

### 16.3 Agent portfolio and healthy device use

Logical Main/Sub independence does not imply simultaneous local model trunks. The process has one authoritative local `HeavyPhase` owner across MLX, Core AI, AFM, vision, and other accelerator-heavy work. CPU/SQL/FTS/retrieval and lightweight deterministic work may overlap only when K1 proves headroom; heavy local stages normally serialize on iPhone Air. Remote I/O may overlap a different local Attempt under its separate bounded lease, but never races as another answer for the same branch.

The existing plan/admission owners apply a reuse ladder, not a new router: contract-complete deterministic Swift/Rust/SQL/C/C++/Vision/Spotlight/OCR/barcode mechanisms first; then an already resident lightweight retrieval/grounding mechanism; then a bounded specialist Sub only when measured marginal quality/coverage exceeds context, coordination, privacy, memory, energy, and thermal cost; then the selected Main; then an authorized stronger remote profile if required. A vision-capable Main or AFM can make a MiniCPM-V branch unnecessary. The portfolio is capability-driven and may legally contain zero Sub Agents.

Every claim is exact-SKU evidence. iPhone Air results cannot borrow thermal or sustained-performance evidence from an iPhone Pro enclosure/vapor-chamber design, and a future Apple Silicon device inherits no placement, geometry, or rate claim by chip-family name. Each device/OS/model/material/profile cohort is measured independently under its healthy operating envelope.

### 16.4 Metrics and named 40/30 tier

For each exact local model/device/OS/profile, certification measures:

- thermally cold resident **accepted-decode** throughput and sustained accepted-decode throughput;
- prefill throughput and first-token latency;
- p10/p50/p95 throughput and interaction latency as applicable;
- resident and transient memory high-water marks;
- energy per token/task;
- time to thermal pressure and recovery;
- UI responsiveness;
- Main/Sub parallelism benefit and coordination cost;
- cache hit benefit and invalidation correctness;
- cancellation, checkpoint, and cold-recovery behavior.

The named `cold40` claim means `thermallyColdResidentAcceptedDecodeTPS p10 >= 40 tok/s` on **each** of two distinct physical devices over exactly 100 preregistered workload turns per device/cohort in the current certification harness, with the canonical `22 +/- 2 deg C`, nominal-for-300-seconds, resident-model, power/screen/radio/background-load, prompt/prefill/output, sampling, and exclusion protocol. The seven controlled documents must atomically converge the architecture's older “at least 100” prose with this exact harness cardinality before any claim. The named `sustained30` claim means the canonical continuous-arrival 1800-second run on each of two distinct physical devices, with last-quarter accepted-decode p10 at least 30 tok/s, no inserted cooldown, no positive memory slope, and no hidden output-length, quality, coverage, or safety reduction.

Only target-verified accepted tokens enter these numerators. MTP draft/proposed/rejected tokens, prompt-lookup hits, cache calls avoided, and speculative heads are reported separately. Prefill, TTFT, end-to-end verified completion latency/goodput, MTP acceptance, energy, and thermal slope are separate metrics. The current architecture evidence (approximately 34.6 tok/s best short decode and 15.9 tok/s last-quarter sustained) does not earn either named tier.

Cold 40 and sustained 30 remain optional exact-profile optimization claims, not unconditional architecture gates. Full performance means the current verified Pareto-best path under quality, latency, memory, energy, thermal health, privacy, and reliability constraints. A brief peak followed by throttling is not full performance; a completed architecture may honestly deny the named tier.

## 17. Security and Privacy Invariants

- No model directly mutates authoritative state, executes a tool, publishes, or promotes itself.
- No Main Agent directly changes App Agent Self, Companion Expression, relationship, private memory, or shared-data authority.
- No Main Agent may be proposer, sole witness, and approver for the same self change.
- No Sub Agent represents the complete App Agent or creates commitments.
- No Session binds more than one App Agent root or one logical Main identity; a Provider/Attempt successor preserves both.
- No App Agent reads or writes another App Agent's private compartment without an exact user-authorized share view, and no share view grants mutation, deletion, re-share, or independent-evidence status.
- No model or Agent Runtime receives a raw Artifact-store port or treats a known Artifact ID as access authority.
- No valid Recognition Projection means no claim of recognizing the user/profile relationship; an account/device-principal authentication claim additionally requires `authenticatedAccountPrincipal` assurance and never proves a biological person.
- No cross-user/workspace relationship recall without exact authorized scope and current consent/deletion epochs.
- No remote Provider receives identity or memory beyond exact approved disclosure.
- Qinao does not request raw private reasoning, accept it into a persistent schema, record/index/forward it, use it as evidence, or treat it as identity. Bounded public rationale, constraints, evidence, decisions, and verification artifacts remain allowed.
- No repeated derivation of one root source creates independent corroboration.
- No quarantined observation participates in default retrieval or self evolution.
- No hidden personality, memory, commitment, or evolution state is exempt from user inspection, correction, revocation, rollback, and applicable erasure.
- No prompt, network content, Companion Expression, legacy Persona overlay, or Provider self-description may rewrite constitutional state.
- No model change reuses an incompatible context, cache, Provider session, or possible-start branch.
- No field in the complete canonical presentation envelope or surface—including response bytes, schema/mode, headline/body, alternatives, explanation codes, optional surface guide, interjection, emoji, Markdown, wrapper, locale, avatar/asset cue, accessibility, audio/prosody, animation, haptic, semantic manifest, subject, or currentness parent—is added, removed, reordered, or substituted after the exact `PresentationReleaseEnvelopeDigest` passes L10/L11/L14.

Erasure evidence distinguishes logical/semantic deletion, projection/index/cache invalidation, cryptographic destruction, retained blinded audit evidence, and remote Provider retention limits. Qinao must not promise deletion beyond the exact local/remote contract it can prove.

## 18. Verification Matrix

### 18.1 Root lifecycle and authority

Test one application container with zero, one, and multiple child scopes; distinct concurrent A/B creation events; and the same `creationInputEventID` concurrently proposing different child scopes/nonces. Fault before/after scope allocation, creation-binding CAS commit/reply, quota reservation commit/reply, seed put commit/reply, coupled root-activation-plus-reservation-consumption commit/reply, and coupled deletion-fence-plus-quota-release commit/reply. The typed quota case manifest covers exact binding digest, semantic key, deadline, monotonic clock domain, boot-or-durable anchor, preexisting root-activation candidate, every closed preexisting release-trigger variant, preexisting deletion authorization, strict expiry, reboot with compatible and incompatible anchors, same key with changed binding bytes, at-cap concurrency, and every activation-versus-abandonment/expiry/revocation interleaving. Mutate activation/trigger/deletion references to missing, stale, wrong-kind, wrong-digest, post-commit evidence, or same-transaction/future activation/commit receipt and require rejection; the row may contain only pre-transaction inputs and every K3 activation/commit/currentness receipt remains external. Require the same-event retry/double-click to reopen one exact `AppAgentCreationBinding`; every pre-CAS or losing scope/seed is inert and absent from inventory. Require the closed state transitions `absent -> reserved -> consumed -> releasedAfterDeletion` or `reserved -> releasedOrExpiredBeforeActivation`; activation and consumption are one K3 `FULL` outcome, deletion fencing and post-deletion release are one K3 `FULL` outcome, every terminal tag is absorbing, and an expired/abandoned binding can neither re-reserve nor activate. Missing/duplicate/unknown authoritative root or quota coverage and stale admission deny creation. Mutate Catalog inventory, display, counts, recency, or default hints and prove none is an admission/capacity input.

Then test same-child concurrent genesis candidates; designated-principal grant; L10 validation; L11 confirmation; L13 prepare; K3 stage; L14 decision; K4 exact-grant issue/reopen, reserve, claim/use, generic `attestClaimedArtifact` create/reopen, caller-side ordinary target-attestation put, K3 seal, and the `absent -> active (appAgentID, genesisArtifactID, initial Self head)` CAS; supported restore, stale backup, reinstall, clone, reset, storage rewrap, commitment-key/scope rotation, key loss, cross-device fork, deletion, and erasure. Require one active winner per winning exact creation binding and child scope, independent simultaneous A/B roots, inert losers, private non-Workspace/non-public scope, `appAgentID` independence from `genesisArtifactID`, no self-reference or downstream-receipt back-pointer, exact old-root continuity plus freshness/anti-rollback proof for identity-preserving rotation, and no false restoration. For every successor and rollback candidate, mutate predecessor/target pairing, appAgent/container/scope/root/key lineage, ancestor direction, chain continuity, taint/deletion/quarantine, schema support, authorization, and current policy/consent/deletion vector; explicitly reject sibling, cross-root, descendant, provenance-gap, tainted, deleted, wrong-scope, and wrong-key-lineage targets. Delete and rebuild `AgentRootInventory` from authoritative facts, then join exact profile-scoped Host/UI preference heads into `AgentCatalogPresentation`; duplicate display names, missing/duplicate roots, stale/unknown watermarks, account/profile switches, and stale UI indices must never change root selection.

### 18.2 Cross-Provider identity

Run the same identity, value-conflict, commitment, refusal, correction, relationship, and coercion scenarios through Qwen, AFM, and authorized API profiles. Require the selected App Agent root and `sessionMainAgentID` to remain exact across lawful Provider re-embodiment while Provider/Attempt execution changes. Measure a versioned semantic-conformance threshold over App Agent identity, core constraints, permissions, and adopted commitments while allowing expression and reasoning depth to vary. A profile below the Main threshold is ineligible rather than silently accepted.

### 18.3 Recognition and isolation

Test cold start, A/B using the same authorized Host profile, distinct A/B relationship facets, fresh profile with no relationship, model change, app relaunch, device restore, account switch, shared device, guest, revoked identity, deleted Workspace, relationship erasure, relationship disclosure denial, relationship unavailable/quarantined, profile-continuity-only, authenticated-account-principal, and ambiguous states. Inject expiry/revocation/reboot immediately before and after compile, materialization, remote anchor/arm/possible-start, Provider observation, stream chunk, spool, publication, effect/state adoption, and NextQuestion render. A valid profile must carry exactly one honest `present`/`provedAbsent`/`notAuthorized`/`unavailableOrQuarantined` relationship state for the selected App Agent; only `present` may restore/render that Agent's scoped relationship facts. A private canary unique to A must never appear in B without an exact share; mixed SQL/FTS/BM25/dense/temporal/entity results must preserve this. An account/device-principal claim requires exact current non-rendered profile-resolution and principal-binding receipts; no path claims biological-person proof; stale/invalid/ambiguous state must not be recognized or retroactively blessed. Sub Agents and remote Providers must receive only authorized scoped pseudonyms and no stable IDs/digests, credentials, grant details, or proof references. Prove Attempt/Provider/purpose/Workspace unlinkability, deterministic same-branch use where required, key/disclosure-epoch rotation, and fail-closed behavior when the pseudonym parent binding is absent.

### 18.4 Contamination and cleaning

Test Unicode/control attacks, embedded instructions, forged provenance, circular evidence, duplicate lineage, model self-rewrite, sycophancy, role play, stale emotion inference, cross-workspace leakage, and poisoned retrieval. Race release/effect/adoption before and after the non-operative L14 decision-candidate put and the sole K3 installation transaction; crash at both cuts and throughout descendant traversal/purge. Require the bare decision candidate to have no installed effect, the one K3 transaction to atomically install its reference and fence all use, every downstream CAS to linearize wholly before or after that point, then quarantine with no promotion/default recall/release/effect/NextQuestion/RSI use, typed unavailable rather than false-empty lanes, causal invalidation, and clean rollback/replay.

Drive a transitive checked-in `PresentationReverseInfluenceManifest` from every field of the complete canonical presentation schema through all observation, coverage, honesty, workflow, update-ticket, commit-token, checkpoint, summary, memory, evaluation, evolution, RSI, state, halt, and later-presentation sinks. Its receipt must match exact discovered/retired/surviving/executed/expected-kill/killed counts and manifest digest. For each row, mutations add a sink; change any `BASOutputSurface`, `BASRenderedOutput`, `BASSurfaceDecision`, `BASRenderFrame`, cue/accessibility/locale/audio/animation/haptic/semantic/subject/currentness field; alter a hash/count/derived label; remove App-Agent/profile/workspace/Session/Main/Attempt/envelope lineage; skip one cleaning pass; elevate authority; or self-corroborate. Direct output-derived coverage/halt, workflow, ticket identity/summary/confidence, commit/checkpoint, evaluator/promotion, memory, RSI, and Self/evolution edges must be unreachable. A surviving diagnostic/observation row is legal only when it emits a scope/envelope-bound untrusted observation, preserves one-root evidence lineage, passes all seven cleaning gates, and requires a separate lane-specific independent adoption. Forward-only render/audit rows are tested separately for full-envelope binding and zero reverse authority.

### 18.5 Context and collaboration

Test independent Main/retrieval/vision/grounding/code/recovery window isolation, adaptive budgets for small/large/fixed Core AI/opaque AFM/API contexts, repeated compaction, typed Agent joins, cancellation/steering, slow/failed Sub Agents, attribution, incomplete coverage, cache compatibility, and no raw-CoT persistence. Race A-versus-B Session-selection candidates for the same `(applicationContainer, sessionCreationInputEventID)`; fault precreated `ContextWorkspaceRef`, selection CAS commit/reply, and every first-WorkUnit cut. Require one current `AppAgentSessionSelectionEvidence`, byte-identical retry reopening it, the loser remaining inert, and zero WorkUnit admission before it exists. Replay the event under a wrong profile/workspace, changed normalized bytes, altered `sessionIncarnationID`, substituted `ContextWorkspaceRef`, a workspace reference containing/predicting an evidence/CAS identity, evidence naming another workspace reference, or the same UI correlation with another root and require conflict. A lawful switch uses a fresh event ID/incarnation and cannot mutate the predecessor selection. Require every WorkUnit in one Session incarnation to carry the same evidence digest, exact evidence-bound workspace reference, selected root, profile/workspace, and `sessionMainAgentID`; inject a second Main, alternate root/evidence, B-root Sub result, stale cancellation generation, or A-private cache key and require rejection. Prove `attemptFrame -> descriptor -> plan -> allocation -> providerStep`, non-zero branch matches, a fresh descriptor for every tool/visual/retrieval continuation, and rejection of allocation-before-descriptor, providerStep-before-allocation, or in-place transcript/context growth. Cross-App-Agent/Session/Workspace/profile/Provider negative tests prove that referencing the same immutable Artifact never transfers a prior consumer's eligibility, consent, or disclosure decision.

### 18.6 Provider switch and recovery

Test Qwen-to-AFM, AFM-to-API, API-to-local, tokenizer/material change, process death during selection/planning/prefill/decode, and death at every protected effect boundary. Require a new Attempt/context for a new Provider while App Agent/Main remain exact, restoration of the exact last committed Continuity Manifest/current heads, no loss of owner-proved durably committed work, explicit discard of allowed transient RPO, no falsely completed work, and no blind duplicate effect. Test same `sessionCreationInputEventID` or `sessionIncarnationID` with different selection evidence/root as corruption, A -> B fresh-event/fresh-incarnation handoff, deleted selected root with no automatic fallback, and A `sent_or_unknown` plus B selection with zero resend.

The handoff negative suite is driven by a checked-in typed cross product of forbidden carrier × recursive container/nesting depth × encoding/canonicalization. Forbidden carriers include capability/signed URLs, non-allowlisted schemes, operation/boundary IDs, idempotency/credential tokens, tool parameters, request bodies, permits/grants, receipts, live handles, and retry/query instructions; containers include every field, collection, nested string, citation label/origin/path, and source metadata location; encodings include percent encoding, URI normalization, case variants, Unicode normalization/confusables, escapes, and canonical-byte aliases. Every case must reject before B receives the export. B may receive only the closed opaque predecessor-status tuple and cannot reconstruct, query, resume, or resend A's boundary.

### 18.7 Reasoning quality

Maintain suites for multi-constraint ordering, resource/time/location planning, long-text extraction, multi-source conflict, underdetermined puzzles, strongly leading questions, insufficient-information tasks, code/calculation with tool validation, and loop-inducing prompts. Deterministically check solvable suites; require evidence spans and coverage; require abstention or minimum clarification when necessary.

Drive a checked-in schema-derived sufficiency/termination case manifest over every phase and all seven `BASInformationSufficiencyPayload` outcomes, every exact requirement/coverage/conflict/candidate/L14/currentness parent, and the full ControlRing terminal-state × termination-reason cross product. Exercise legal preflight/finalization outcomes, zero/one ordinary remand, repeated/illegal remand, stale parents, exhausted budget, Provider disagreement, and every attempted outcome upgrade; a phase/outcome mismatch, omitted parent, spelling alias, or second remand rejects. Cover every listed legal terminal pair and every unlisted pair as a negative mutation. Only exact `converged + converged-verified` with its current committed K3 budget-use receipt may enter any adoption lane; remove/substitute/stale that receipt or feed `degraded-with-coverage`, clarification, `partialVerified`, abstain, denial, deferred, rejected, or reconciliation output into adoption and require the gate to fail. Separately prove each authorized non-adoptable outcome may be presented only through its normal full release envelope without gaining state authority.

### 18.8 Initiative, next question, and RSI

Drive NextQuestion from a checked-in typed candidate/ranking/release case manifest. Cover zero, one, and five candidates; duplicate suppression; deterministic ties; score-margin below/equal/above threshold; abstention; expiry; and source/focus/input changes during ranking and publication. Mutate schema/objective version, candidate-set digest/order/cardinality, winner ID/semantic digest, full visible question, canonical tap-payload meaning, every score component, margin/threshold, answer/release parents, selected App-Agent/root/Session/Main tuple, source/currentness vector, focus/input state, contamination/consent/deletion/policy/generation epochs, expiry, mini-release envelope, and render-CAS receipt. Require exact winner-projection -> Required Semantic Baseline -> L9 candidate -> buffered L12/L10/L11/L14 mini-release -> current render-CAS equality; winner/loser text or payload substitution and every stale parent fail. A semantic-null fixed chrome tap may only open the exact fully visible winner; only a second explicit tap on that winner creates exactly one normalized Input Event and one admitted Attempt, and byte-identical replay reopens rather than duplicates them. Hidden-winner one-tap submission, engagement optimization, notification, or durable intent is impossible.

Verify lease expiry, budget exhaustion, prohibited network/tool/notification/spend, interruption cost, duplicate suppression, non-manipulation, candidate expiry, shadow non-authority, canary rollback, stale-read CAS denial, immutable core protection, rejection of guest/profile-only/unauthorized-principal confirmations, designated-principal rotation/account-switch/revocation, and exact confirmation binding. Fault every Stable-Self row in Section 14.3, including grant derivation/issue commit/reply loss, grant-byte or nonce mismatch, reserve commit/reply loss, claim lookup/resubmission, `attestClaimedArtifact` pending-owner install/takeover/stale completion/result commit/reply loss, same-request concurrency, different-request same-semantic-key collision, mutation of every proof-free signed field, Ed25519/P-256 post-result no-resign replay, caller death before durably retaining the returned payload followed by same-request K4 reopen, caller-side ordinary-put commit/reply loss, pending-at-deadline, committed-BLOB expiry/deletion/revocation erasure, `resultErased` exact replay, semantic-key tombstone preservation, missing-BLOB corruption discrimination, reboot or confirmation/authorization expiry before each K4/K3 boundary, genesis absence versus successor head, K3 seal, activation CAS, and rollback/quarantine. Race public put both before and after K3 fence, K3 seal and activation on both sides of the fence CAS, K4 erase/late XPC reply/worker death against each boundary, and exact equality at `recoveryNotAfter`; deliver one accepted reply only after the deadline and a preliminary sweep. Require either proved put-capable-worker/reply-channel quiescence before the final sweep or a pre-sweep Artifact-Mesh-WAL no-reinsert fence atomically checked by every later put; otherwise deletion remains pending. Require every late put to be rejected or remain a headless inert orphan and prove final lineage sweep, purge/quarantine, and stale-reintroduction denial before deletion completion. Mutate every public payload/identity field and P-256 proof encoding, including replacing low S with the mathematically equivalent high S; require canonical/signature/binding rejection at K3 seal. Prove zero K3 transaction across K4/XPC, zero private target mirror, zero K4 Artifact commitment-key access, zero K4 reply before `resultCommitted`, no transition out of `resultErased`, and no semantic ordering dependence on K4 erasure timing.

### 18.9 Companion expression and sharing

One checked-in typed `LegacyPersonaSourceSinkRecoveryManifest` drives the Section 5.7 inventory, migration tests, production reachability gate, and convergence receipt from the same digest. It enumerates all sixteen `BASAgentPersonaSpec` fields; `BASAgentSpec.personaRef`; `BASOrganRequest.personaInstructions`; Persona resolver/clamps/forbidden detector/SDK/role templates and `QinaoPersonaStudio`; both direct MLX system-message/`ChatSession.instructions` sinks; `BASAgentFabricFullTurnAdapter` environment/config ingress; `BASAgentFabricTranscriptProjection` compare-all and compare-selected branches; cold-restart Persona/Host-Persona/warrant persistence and restore; and public/Codable Skill descriptor/Registry/A2A/`buildAgentSpec`/invocation reinjection. Every manifest row has source, transitive sink, recovery surface, disposition, and one checked negative control; compare-all and compare-selected have distinct controls. Added legacy fields or reachable sinks fail digest/cardinality before tests. Compile free-form Persona attacks only into closed-field proposals and reject every attempt to control factuality, cognition, verification, risk, tools, permission, memory, routing, or authority; arbitrary `personaInstructions` and `personaRef` are unreachable from production Provider-control bytes.

Authoring tests cover fixed structural preview and generated ordinary-conversation, serious-task, and exact-code/output preview paths. Mutate normalized proposal bytes, proposal digest, the ordered complete shown preview-envelope/static-asset digest set, `preRootSetupPreview` versus `existingRootStudioPreview` subject tag, profile, workspace, root/scope/currentness, current expression head, policy/consent/deletion vector, or confirmation-event binding; omit/reorder one shown preview, perform A-preview/B-commit, edit after preview, or replay stale currentness and require rejection. If root activation commits before its separate preference commit, Catalog/Studio shows only `setupIncompleteNeutral`; retry reopens the same root and preference transaction, abandonment creates no second root, and no unconfirmed expression becomes active. Every generated preview and dynamic NextQuestion card/expansion passes its full baseline -> L9 -> non-visible L12 -> L10 -> exact L11 allow -> L14 -> byte-identical publication mini-release. Every fixed alternative/chrome asset is semantic-null and has its own exact fixed-asset release envelope.

For identical task/evidence/currentness, require byte-identical pre-expression `RequiredSemanticBaseline.semanticCoreDigest` across neutral/playful/goofy/serious profiles; mutate one profile to omit, weaken, or reinterpret a requirement before L9 and require rejection. A schema-derived semantic case manifest covers actor/entity/coreference identity; polarity/negation; quantifier/cardinality (`all | some | none | exactly | boundedRange`) and scope; conjunction, inclusive/exclusive disjunction, and exclusivity; conditional/biconditional/exception direction and scope (`if | onlyIf | iff | unless | except`); modality; uncertainty; time; causal/relation edges; quantities/decimals/units/comparisons; caveats/warnings/refusals/confirmations/deletion text; citations/source spans; code/operators; shell/SQL/JSON; URLs; exact formats; Unicode/bidi/zero-width; and locked logical connectives. L9/L12 mutation tests cover every field/scope and require `added = 0`, `omitted = 0`, exact graph/set equivalence, entity/coreference preservation, and locked-span byte mapping. Added semantic fields fail manifest digest/cardinality before release.

A separate schema-derived presentation case manifest covers every canonical `BASOutputSurface` field (`schemaVersion`, `surfaceID`, `surfaceType`, `channel`, `interactionDepth`); every canonical `BASRenderedOutput` field (`schemaVersion`, `mode`, `headline`, `body`, each ordered `alternativeActions` string, `explanationCodes`, and every nested `surfaceGuide` field); external `surfaceDecisionWireVersion`, every currently encoded `BASSurfaceDecision` field and tagged-substitute associated value; every `BASRenderFrame` field/optional-ref presence; the complete `PresentationSurfaceCompatibilityManifest`; avatar cue/asset/version/duration/repeat/context class; accessibility; locale; voice-prosody/audio class and bytes; animation; haptic; semantic-conservation/locked-span manifest; all three release-subject variants; and every currentness parent. Unknown surface-decision wire version, field addition, or field removal fails fixture/manifest digest/cardinality before decode or release. For the only eligible snapshot mode, require `releasedPresentationEnvelopeDigest == L12BufferedEnvelopeDigest == L10VerifiedEnvelopeDigest == L11AllowedEnvelopeDigest == L14AuthorizedEnvelopeDigest`; missing, wrong-kind, wrong-subject, or wrong-envelope L11 receipts fail. Mutate, omit, insert, or reorder every manifest field after any boundary; substitute an incompatible mode/surface/agency/disclosure/substitute tuple; independently render a `TurnOutcome.surfaceDecision`/RenderFrame field; or replace/reorder/remap a candidate/proposal ref, currentness, display bytes, localized asset, confirmation contract, retry delay, or audit reference, and require rejection. Each action-bearing substitute interaction must create one newly authorized normalized Input Event bound to the exact displayed item/envelope/currentness; envelope release alone performs none. Serious contexts select buffered/neutral defaults; L11 remand/redaction/confirmation creates a fresh candidate rather than editing the spool; specialist reasoning capsules receive zero Companion Expression.

`incrementalVerified` is tested only as a contingent future protocol and remains disabled until the controlled migration retires/redefines current pre-L9 retractable `.provisionalStream`, creates/maps the complete L9-selected semantic answer graph, and installs the original approved-planned pre-call policy/disposition wires. Its manifest covers claim-addressed, claim-atomic, qualifier-complete batches; prior-range ancestry; contiguous byte ranges; cumulative roots; per-batch `L12 == L10 == L11 == L14 == released`; and terminal aggregate equality. Delay coreference, negation, `all/some/none`, exclusive-or, `if/onlyIf/iff/unless/except`, modality, uncertainty, quantity/unit, safety caveat, warning/refusal, or citation to a later batch and abort before it; the earlier batch must reject or pre-call policy must have selected buffered. Crash/relaunch/history/copy/share preserve exactly `partialAuthorizedPrefix` or `terminalComplete`; partial can never become answer-complete, NextQuestion input, durable answer-derived memory/state/Self/RSI evidence, or an unqualified share. Interruption chrome is a separate semantic-null fixed-asset envelope bound to the partial disposition. Every partial/terminal tag, range, parent, currentness, and aggregate mutation fails.

For A -> B sharing, construct canonical share X and Y and cross-splice confirmation, per-share `crossAppAgentShare` principal grant, L11 `crossAgentDisclosure`, L14 `shareReleaseDecision`, K4, source, and currentness receipts; any X/Y subject-digest mismatch fails at creation and every materialization. Mutate purpose, decision kind, source/target root/scope/profile/workspace/facet, selected source set, operations, disclosure/retention/redaction, expiry/clock, lineage, and every consent/policy/source/deletion/revocation generation. Substitute a self-governance grant, relationship membership, Main identity, `stableSelfAdoption`, or target adoption receipt and require rejection. Also test missing/known Artifact ID; forged/replayed/expired/revoked parents; consumer-specific eligibility; no write/delete/re-share; derivative lineage; source correction/revocation/deletion/taint at every retrieval/prefill/decode/release/effect/adoption cut; transitive depth zero; target deletion without source deletion; and typed unavailable for unknown coverage. Source fencing invalidates B's share, FTS/vector/entity/summary/cache/Context/NextQuestion/RSI use synchronously before cleanup.

Finally, drive a transitive raw-store reachability manifest from every public Agent/Session/Runtime/Main/Sub/Provider/Studio/`AgentRootInventory`/`AgentCatalogPresentation`/Recognition/retrieval/context-compiler/share entrypoint through aliases, factories, protocol erasure, and Catalog joins. Only the trusted Artifact Mesh physical owner may retain raw `BASArtifactStorePort`/`BASArtifactSQLiteStore`. Inject a direct `read(id)`, Catalog alias/factory read, raw-port retention, or removal of caller/source/target scope/purpose/currentness from the gateway; each mutation must make the gate red.

### 18.10 Device health

Measure the exact performance metrics above under cold, warm, sustained, foreground/background, charging/battery, and memory-pressure profiles on each exact SKU. Separate accepted tokens from MTP drafts, prefill, TTFT, and end-to-end goodput; exercise the two-device/100-turn and two-device/1800-second protocols before any named 40/30 claim. A Release plan must remain inside its certified thermal/memory envelope and preserve UI responsiveness.

### 18.11 Non-vacuous architecture gates

- CreateGate receives a non-empty current M-creation manifest or a class-specific typed M-not-applicable proof; ExtensionGate separately receives a non-empty current E/A-extension manifest or a class-specific typed E/A-not-applicable proof; schema-fixture closure is reported separately. No historical or foreign class satisfies another.
- Checker and checker tests run in CI.
- Swift test filters prove a non-zero match count.
- Named files and glob anchors must exist and match before negative scans run.
- RED tests compile against only the APIs available in their wave.
- Every proposed payload closes owner, schema, current fixture, future-version rejection, storage, replay, erasure, and recovery references. A backward fixture exists only for a real historical wire version; otherwise canonical `backwardFixture.notApplicable` must bind repository-history proof and no synthetic backward fixture is invented.
- A documentation command must run from a clean checkout and fail on the violation it claims to prevent.
- Every critical adversarial/property/mutation suite has a checked-in typed case manifest with exact expected domain/axis cardinalities and manifest digest. Its machine receipt reports discovered, executed, expected-to-kill, killed, survived, and skipped counts plus digest. Zero discovery, count/digest drift, an unapproved skip, or an expected mutation that survives is a hard failure; each authority/privacy/publication/migration domain includes at least one checked-in negative control known to make the gate red.

### 18.12 Machine-enforced invariants

1. A `ContextWorkspaceRef` is first created without any future selection/evidence/CAS identity; one incumbent EventLog/K3 expected-absent CAS then freezes that exact reference in exactly one current `AppAgentSessionSelectionEvidence` per `(applicationContainer, sessionCreationInputEventID)` and immutable `sessionIncarnationID` before any WorkUnit. Every WorkUnit carries and equality-checks its exact evidence digest, evidence-bound workspace reference, selected root/profile/workspace, and derived `sessionMainAgentID`; a switch uses a fresh event/incarnation/reference rather than a successor selection generation.
2. Existing K3 current-head/generation truth permits at most one active Attempt and Main binding per WorkUnit; ordinary Self/expression/relationship head evolution creates a fresh execution binding without rewriting Session selection, while selected-root deletion/revocation/quarantine fences the Session.
3. Provider, Main, and Sub identities have no App Agent Self write port.
4. Cleaning, repetition, summarization, embedding, and model consensus cannot raise authority class.
5. Quarantine never enters ordinary retrieval or context compilation.
6. Credentials and authentication proofs never enter model-facing material or remote egress.
7. Every Sub capability is a strict subset of its parent grant and is revoked with the parent.
8. Attempt/generation/current-head, selected App/Self/expression/relationship head, consent, deletion, policy, Recognition projection/deadline, share-source/grant, or contamination/invalidation change invalidates old Context, output, permit, release, NextQuestion, and cache use before downstream currentness checks pass.
9. Unknown external effects are reconcile-only and never resent blindly.
10. One RSI candidate cannot modify its behavior and its evaluator/adoption gate together.
11. Rollback, correction, taint, and deletion propagate through FTS, vector, summaries, relations, caches, NextQuestion, and evolution derivatives; deletion completion additionally proves either exhaustive put-capable-worker/reply-channel quiescence before the final sweep or an Artifact-Mesh-owned durable no-reinsert admission fence before that sweep.
12. A Provider below Main identity-conformance threshold is denied or restricted to an eligible narrower role.
13. A current profile-resolution receipt with no current principal-binding receipt permits at most `profileContinuity`; missing/expired/ambiguous profile resolution permits only `guestOrUnknown`; neither path may fabricate `authenticatedAccountPrincipal`.
14. Stable App Agent Self activation requires an exact current authorized-self-governance-principal confirmation receipt, the frozen domain-separated K4 grant/issue/reserve/claim/use request chain, one gated generic K4 claimed-target-attestation value recovered without re-signing when its bytes were lost, its canonical and fully signature-bound headless caller-side ordinary Artifact, strict `now < recoveryNotAfter` plus complete local currentness/fence revalidation in independent K3 `FULL` seal and activation transactions, and the final activation CAS bound to the candidate/read-set/current heads; no K3 transaction spans K4/XPC, and K3 fence-versus-activation order, never K4 erasure timing, decides eligibility.
15. Memory, relationship, narrative, task, or policy commit never advances the constitutional Self head.
16. Exactly one mapped incumbent reference-composition path assembles the transient App Agent composite from reopened current heads; L3 and every Provider only consume narrower projections and cannot compose or persist authority.
17. A container-scoped `creationInputEventID` has exactly one winning `AppAgentCreationBinding`; only its exact scope/nonce/quota semantic key can enter `absent -> reserved -> consumed -> releasedAfterDeletion` or `reserved -> releasedOrExpiredBeforeActivation`. Root activation plus reservation consumption and root/Session/share deletion fencing plus post-deletion release are respectively single K3 `FULL` transactions; terminal quota states are absorbing, expiry/abandonment cannot re-reserve or activate, lost replies reopen the same outcome, and every losing or pre-CAS scope/seed is inert and unselectable. Consumed/terminal rows bind only the closed preexisting root-activation candidate, release-trigger, and deletion-authorization inputs; their own K3 activation/commit/currentness receipts are external and no row predicts or embeds them.
18. One application-governance container may contain multiple child scopes, but each exact `AppAgentAuthorityScopeRef` has at most one active `appAgentID`/genesis/initial-Self tuple; Artifact key/scope rotation cannot silently change or preserve identity without the exact root-evidence transition.
19. `AgentRootInventory` and profile-scoped `AgentCatalogPresentation` are rebuildable projections and never create, select, restore, mutate, delete, admit, or count quota without reopening exact authoritative facts and complete watermarks.
20. `hostShared`, `appAgentPrivate`, `sessionPrivate`, and `explicitShare` are profile/workspace/root-disjoint access classes; known content identity or physical co-location transfers no read/write eligibility.
21. An explicit share freezes one `ExplicitShareAuthorizationSubjectDigest`; its normalized confirmation, non-substitutable per-share `crossAppAgentShare` grant, exporter, L11 `crossAgentDisclosure`, L14 `shareReleaseDecision`, K4, and every materialization equality-check that same digest and exact decision tags. It grants at most purpose-limited `read/reference/derive`, preserves source lineage, defaults to zero transitive depth, rejects self-governance/relationship/Main/`stableSelfAdoption` substitutes and cross-share receipt splicing, and loses eligibility synchronously when any parent is fenced; V1 has no independent share epoch/head.
22. From every public Agent/Session/Runtime/Main/Sub/Provider/Studio/Catalog/Recognition/retrieval/context-compiler/share entrypoint, including aliases, factories, protocol erasure, and projection joins, the transitive dependency graph cannot construct, retain, or directly read through raw `BASArtifactStorePort`/`BASArtifactSQLiteStore`; the caller/source/target-scope/purpose/currentness-aware gateway is the unique governed path.
23. A Session cannot change its selected App Agent in place; switching creates a new Session/Main/Attempt lineage. A typed recursive handoff-carrier gate rejects capability/signed URLs, executable boundary/operation/idempotency/credential material, parameters, permits/grants, receipts, handles, and retry/query instructions at every nesting depth and encoding; B receives only the closed non-routable predecessor-status tuple.
24. The approved-planned pre-call publication policy/K3 freezes mode; at this snapshot only complete `bufferedUntilVerified` is eligible and current pre-L9 retractable `.provisionalStream` cannot satisfy `incrementalVerified`. Every canonical `BASOutputSurface` + `BASRenderedOutput` + `BASSurfaceDecision` + `BASRenderFrame` + cue/accessibility/locale/audio/animation/haptic/semantic-manifest/subject/currentness envelope is exact, passes the closed compatibility manifest, and satisfies `released = L12 = L10 = L11 = L14`; no TurnOutcome/RenderFrame side channel or post-authorization field mutation exists. Future incremental mode additionally requires the controlled L9-answer-graph migration, exact per-batch equality, claim/qualifier-complete contiguous prefixes, and durable `partialAuthorizedPrefix | terminalComplete`; only terminal-complete may drive answer-complete UI, NextQuestion, or answer-derived adoption.
25. The approved-missing singular L7 State Requirement Planner/Plan original M wire freezes the expression-independent `RequiredSemanticBaseline` before Provider expression; equivalent task/evidence/currentness yields one `semanticCoreDigest` across expression profiles. L9/L12/L10 prove exhaustive graph/set/span conservation with `added = 0`, `omitted = 0` across entity/coreference, polarity/negation, quantifier/cardinality and scope, conjunction/inclusive-or/exclusive-or, `if/onlyIf/iff/unless/except`, modality, uncertainty, time, causal/relation, quantity/unit/comparison, caveat/warning/refusal, citation/source span, code/operator, URL, and exact-format semantics.
26. Companion Expression contains no factuality, cognition, verification, risk, permission, routing, memory, tool, or authority control and cannot enter specialist Sub reasoning capsules. Preference confirmation binds the exact normalized proposal and complete ordered shown preview/static-asset digest set; generated `preRootSetupPreview`, `existingRootStudioPreview`, and dynamic NextQuestion text use their exact subjects and complete buffered mini-release, while split root/preference recovery can expose only neutral incomplete setup.
27. `BASNextQuestionProjection` is ephemeral and frozen over exact objective/schema, candidate set, winner/semantic meaning, score/margin/threshold, parents/currentness/expiry and selected Agent/Session/Main. Its card is an exact buffered mini-release plus render CAS; a semantic-null first tap may only reveal the full winner, and only a second explicit winner tap creates one idempotent normalized Input Event/Attempt.
28. No released presentation field, hash, count, label, summary, observation, coverage, workflow/update-ticket candidate, commit/checkpoint token, evaluation tag, or model-honesty score becomes a halt input or eligible/promoted memory, relationship, workflow execution, evaluator/RSI input, or Self/evolution state directly. The checked `PresentationReverseInfluenceManifest` has exact digest/cardinalities, retires direct influence, forces every surviving seam through a scope/envelope-bound untrusted observation, all seven cleaning passes, and separate independent adoption, and separately preserves forward-only full-envelope render/audit evidence.
29. One checked `LegacyPersonaSourceSinkRecoveryManifest` with exact digest/cardinalities drives the full sixteen-field migration, source/sink/recovery inventory, tests, and reachability gate; compare-all and compare-selected, public DTO/A2A, Skill Registry/descriptor/`buildAgentSpec`, cold restart, aliases, and direct system-message sinks each have a working negative control.
30. Every Self rollback target is a current-authorized, schema-supported, clean ancestor in the exact same appAgent/container/scope/root/key lineage; sibling, cross-root, descendant, gap, tainted, deleted, quarantined, wrong-scope, or wrong-lineage substitution rejects.
31. The phase-tagged `BASInformationSufficiencyPayload` accepts only its closed seven-outcome phase matrix and at most one plan-authorized ordinary remand; ControlRing accepts only the listed terminal-state/reason pairs with canonical wire spellings. No non-converged or unresolved presentation outcome is adoptable: adoption requires exact `converged + converged-verified` plus the current committed K3 budget-use receipt.

## 19. Acceptance Criteria

The design is complete only when evidence proves all of the following:

1. one application container can hold multiple independent App Agent child scopes, while each container-scoped `creationInputEventID` has one winning `AppAgentCreationBinding`/scope/nonce/quota semantic key and exactly one genesis wins; retries, lost replies, wrong-profile replay, losing scopes, and pre-CAS seeds cannot create a second selectable root; the exact deadline/monotonic-domain/boot-or-durable-anchor-bound quota state machine is absorbing, root activation plus `reserved -> consumed` and deletion fencing plus `consumed -> releasedAfterDeletion` are each one K3 `FULL` transaction, consumed/terminal rows bind only closed preexisting activation/trigger/deletion inputs with external non-self-referential K3 activation/commit/currentness receipts, an expired/abandoned binding cannot re-reserve/activate, and Catalog data never admits or counts capacity; `appAgentID` is independent of key-epoch-bound Artifact identity, clone/reset creates a fresh binding/scope/root, and only exact old-root/continuity/freshness/key-lineage-proven restoration or rotation reuses the same committed identity/commitment head;
2. an evidence-free `ContextWorkspaceRef` is created first and one incumbent EventLog/K3 expected-absent CAS then freezes that exact reference into exactly one `AppAgentSessionSelectionEvidence` before WorkUnit admission; every Session immutably carries the evidence/reference pair, selected App Agent root/profile/workspace, and derived `sessionMainAgentID` across all WorkUnits, A-versus-B concurrent selection has one winner, back-pointers/substitution fail, and lost reply reopens it; every Main execution generation independently binds current mutable heads, carries every non-omissible App Agent invariant relevant to the work, receives only minimum-necessary host data, and obeys `attemptFrame -> descriptor -> plan -> allocation -> providerStep` without in-place context mutation;
3. every Sub Agent has an independent bounded context and only a role-minimal App Agent slice;
4. every valid profile-resolution result carries exactly one honest selected-App-Agent relationship-state variant; only `present` restores or renders that Agent's scoped relationship facts, while `provedAbsent`, `notAuthorized`, and `unavailableOrQuarantined` preserve profile assurance without inventing a facet; multiple App Agents may recognize the same Host profile through shared facts without reading one another's private relationship; only exact current profile-resolution plus principal-binding proof permits an authenticated account/device-principal claim, expiry/reboot/race tests fence stale recognition at every egress/release/adoption boundary, and ambiguous/guest state claims neither;
5. no model has App Agent, memory, tool, effect, publication, or adoption write authority;
6. all durable **eligible or promoted** experience passes all seven structural, instruction, provenance, epistemic, semantic, privacy, and self-contamination gates; retention-authorized quarantine remains explicitly failed/ineligible;
7. one source cannot amplify itself into consensus through retrieval or multi-Agent repetition;
8. the non-operative L14 contamination decision candidate becomes effective only at one K3 installation transaction that atomically records its reference and fences affected Attempts, contexts, caches, releases, effects/adoptions, NextQuestion, and RSI before asynchronous descendant cleanup; quarantined lineage can then be invalidated, rolled back, and cleanly replayed without treating unknown coverage as empty;
9. context budgets adapt to exact Provider geometry without blind truncation or incompatible cache reuse;
10. Provider changes and crashes resume from Qinao-owned structured state through a new admitted Attempt where required;
11. external-effect ambiguity never causes a blind repeat;
12. initiative is an attenuated projection of existing leases/permits, inspectable, cancellable, and incapable of silently expanding authority;
13. next-question projection is ephemeral, non-manipulative, and non-effectful; its objective/schema, complete candidate set, winner/meaning, score/margin/threshold, release parents/currentness/expiry and selected Agent/Session/Main are exact, its visible winner passes a full buffered mini-release and current CAS, hidden-winner one-tap submission is impossible, and only a second explicit winner tap creates one idempotent Input Event/Attempt;
14. RSI improves only through cleaned evidence, shadow/canary proof, independent adoption, the complete K3-stage/L14/K4-issue/reserve/claim/use/claimed-attestation-create-or-reopen/caller-put/K3-seal/activation crash matrix, byte-exact lost-result recovery, canonical proof validation, strict recovery deadline, K3 fence-versus-activation CAS, orphan cleanup, and rollback; no downstream receipt is written backward into its candidate payload;
15. the user can inspect, correct, revoke, roll back, and request erasure of all applicable durable identity, relationship, commitment, and memory state, with exact proof of local deletion/invalidation, ordered reply-channel closure or Artifact-Mesh no-reinsert admission fencing before the final sweep, and honest remote/audit limitations;
16. Qinao does not request or accept raw private reasoning into persistent schemas, Agent communication, telemetry, or evidence;
17. local and API Providers have equal semantic authority limits;
18. local execution remains inside healthy, sustained, exact-SKU Apple Silicon envelopes with one local HeavyPhase owner and accepted-token metrics that speculative/MTP drafts cannot inflate;
19. stable App Agent/profile/Self-head/grant/receipt IDs or digests never enter Provider-visible bytes; scoped pseudonyms and rendered constraints pass privacy/linkability tests;
20. all critical CI and architecture gates are non-vacuous, and every adversarial/property/mutation suite proves its checked-in manifest digest, exact discovered/executed/killed cardinalities, and at least one working negative control per domain;
21. `AgentRootInventory` and profile-scoped `AgentCatalogPresentation` are authority-free, survive duplicate names, reject missing/duplicate/stale/unknown coverage, and rebuild deterministically from exact root facts, Host/UI preference heads, and any explicitly mapped profile-scoped summary heads;
22. App Agent selection is exact and immutable per Session, Provider replacement preserves App Agent/Main identity, and App Agent switching creates a new Session with only a user-approved cleaned handoff whose recursive carrier/encoding manifest proves it contains no capability/signed URL or executable external-boundary identity, token, parameter, authorization, receipt, handle, or recovery material;
23. `hostShared` is exact profile/Workspace-owned, A/B private compartments are isolated across every StateLake/retrieval/cache path, known Artifact IDs provide no access, and every public Agent/Session/Runtime/Main/Sub/Provider/Studio/Catalog/Recognition/retrieval/compiler/share path—including aliases, factories, protocol erasure, and joins—can reach Artifact bytes only through the caller/source/target-scope/purpose/currentness-aware gateway rather than raw store ports;
24. explicit sharing freezes one full A-to-B authorization-subject digest and exact decision tags across normalized confirmation, non-substitutable per-share `crossAppAgentShare` grant, L11 `crossAgentDisclosure`, L14 `shareReleaseDecision`, K4, exporter, and every materialization; cross-share splicing and self-governance/relationship/Main/adoption substitutions fail, while the view remains immutable, purpose-limited, provenance-preserving, non-transitive by default, non-corroborating, and synchronously invalidated without an independent V1 share epoch/head;
25. Companion Expression is a profile/workspace-scoped user-previewed structured preference, never a free-form executable prompt, never controls competence or authority, and automatically clamps in serious/protected contexts; preference confirmation reopens the exact normalized proposal plus complete ordered shown preview/static-asset digest set, all generated preview/NextQuestion subjects use exact buffered mini-releases, and a split root/preference failure yields only recoverable neutral incomplete setup;
26. the approved-missing singular L7 planner's original M first wire freezes an expression-independent semantic baseline, with byte-identical core digest across expression profiles and exhaustive entity/coreference, polarity/quantifier/logical-scope/modality/time/causal/quantity/citation/code conservation; at this snapshot only pre-call-frozen `bufferedUntilVerified` is eligible, while future incremental stays disabled until its controlled L9 graph/policy/disposition migration; the complete `BASOutputSurface`/`BASRenderedOutput`/`BASSurfaceDecision`/`BASRenderFrame`/cue/accessibility/locale/audio/animation/haptic/semantic/subject/currentness envelope satisfies its compatibility manifest and exact `publication == L12 == L10 == L11 == L14`, no independent TurnOutcome/RenderFrame render or post-authorization mutation exists, and future partial prefixes can never masquerade as terminal completion;
27. deleting one App Agent fences its Sessions/shares/private state and purges its derivatives without deleting Host-owned shared data or another App Agent's state;
28. one checked typed `LegacyPersonaSourceSinkRecoveryManifest` drives all sixteen legacy-field dispositions, tests, reachability, and recovery closure from one digest; compare-all and compare-selected, public DTO/A2A, Skill descriptor/Registry/`buildAgentSpec`, cold restart, aliases, and every direct Provider-system-message sink each have a working negative control and cannot carry legacy/free-form Persona instructions into production;
29. one checked typed `PresentationReverseInfluenceManifest` proves every complete-presentation-to-observation/coverage/honesty/workflow/ticket/commit/checkpoint/halt/memory/evaluation/evolution/RSI/state seam is retired or emits only an exact scope/envelope-bound untrusted observation that passes all seven cleaning gates and independent adoption; output-derived hashes/counts/summaries never raise authority or corroborate their source, while forward-only render/audit evidence binds the full envelope;
30. every Self rollback target reopens as a clean, current-authorized, schema-supported ancestor in the exact same App-Agent/container/scope/root/key lineage, and every sibling/cross-root/descendant/gap/tainted/deleted/quarantined/wrong-scope mutation fails;
31. a checked phase/outcome and terminal-state/reason manifest rejects every illegal sufficiency phase, second/illegal remand, spelling alias, stale/omitted parent, illegal terminal pair, and outcome upgrade; only exact `converged + converged-verified` with the current committed K3 budget-use receipt is adoptable, while clarification/partial/abstain/denial/deferred/rejected/reconciliation outcomes remain presentation-only.

## 20. Controlled-Convergence Requirements

After written-spec approval, an implementation plan may describe contingent later waves, but its first executable work is a W0 controlled-document-convergence preflight. No production declaration or production implementation task is runnable until that atomic convergence and its non-vacuous receipts prove all of the following:

1. map one Host subject plus zero-to-many child-scoped App Agent Self subject instances to the existing single L5 authority, freeze the closed Host/Self/relationship/expression conflict lattice, and prevent Host/shared/other-Agent data from being auto-promoted into a root's Self;
2. map the non-writer application-container anchor, stable `AppAgentAuthorityScopeRef`, separate `AppAgentScopeCurrentnessEvidence`, container-scoped `creationInputEventID -> AppAgentCreationBinding` CAS, and the exact deadline/monotonic-domain/boot-or-durable-anchor-bound quota owner/state machine; require root activation plus reservation consumption and deletion fencing plus post-deletion quota release to share their respective one K3 `FULL` transaction, make every terminal state absorbing, and prove expiry/abandon/revocation/reboot/lost-reply races. Freeze the preexisting non-operative root-activation candidate, closed preexisting release-trigger union, and preexisting deletion-authorization input; prohibit consumed/terminal rows from embedding/predicting their own same-transaction K3 activation/commit/currentness receipts, which remain external, and add missing/stale/wrong-kind/post-commit/future-receipt mutations. Map per-binding genesis `absent | active`, cross-scope retry/winner/loser recovery, private Artifact/head scope, rebuildable authority-free `AgentRootInventory`/profile-scoped presentation joins, `rootEvidence`, and any external monotonic continuity owner; classify container anchor, child anchor/allocation, binding branch, mutable-head namespace, quota/currentness, and continuity individually as reuse/E/A/M-or-blocked, and keep creation or cross-key/device continuity disabled when no single honest incumbent physical owner is proven;
3. classify every proposed wire as reuse, E/A extension, or blocked M creation and update the Owner Ledger only through its existing process;
4. decide the minimum wire set rather than creating one type per prose concept, keep downstream activation evidence out of immutable target payloads, and map exactly one existing `runtime.turn-operation`-class reference composer for the transient App Agent composite;
5. map physical storage/version/forget/rollback to existing owners and prohibit parallel stores; freeze rollback target equality over appAgent/container/scope/root/key lineage, clean-ancestor direction/continuity, schema/current authorization, taint/deletion/quarantine and policy/consent/deletion currentness, with sibling/cross-root/descendant/gap/wrong-scope negative controls;
6. map exact profile-resolution, exhaustive present/absent/not-authorized/unavailable relationship state, external-authentication, self-governance-principal grant, and scoped-pseudonym/blinding owners plus issuance/currentness/expiry/revocation/rotation/restoration/recovery; L3 owns no identity secret and every unproven capability remains disabled;
7. map the mandatory `AppAgentSessionSelectionBinding` to exactly one incumbent EventLog/K3 currentness row and expected-absent CAS keyed by `(applicationContainer, sessionCreationInputEventID)` with fresh immutable `sessionIncarnationID`. Freeze the acyclic order: create `ContextWorkspaceRef` first from immutable Session inputs with no future evidence/CAS identity, then bind that exact reference into the selection binding/evidence; reject back-pointers, prediction, or substitution. Bind the exact selected child scope/root, evidence-bound workspace reference, `sessionMainAgentID`, Recognition, and Main/Sub trusted/rendered views to typed sections of the one approved-planned `BASContextCapsule` path; prove every WorkUnit carries the same selection evidence while Provider successors retain it and switches use new event/incarnation/reference identities; preserve `attemptFrame -> BASCompiledContextDescriptor -> plan -> K3 allocation -> providerStep` with no independent/new-authority Session registry/store or global current-Agent singleton;
8. bind experience cleaning/quarantine/promotion to existing L7/L8/L10/L13/L14 paths, make an immutable L14 contamination decision candidate explicitly non-operative, and make one K3/source-currentness transaction the sole point that atomically installs its reference plus eligibility/generation/invalidation/kill fencing; eliminate arbitrary lookup bypasses and test the decision-put/K3-install race;
9. preserve existing Provider, Attempt, budget, possible-start, effect, publication, erasure, and recovery contracts, including same-boot/cross-boot distinctions;
10. extend the existing ΩE/K3 state-commit row/query only as required to freeze the exact K4 grant bytes/issue request/bound subject/use request/`attestationRequestID`/proof-free target-attestation request and close every Stable-Self stage/L14/K4-issue/reserve/claim/use/claimed-attestation-pending-owner/result-commit-or-reply/result-erasure/caller-put/K3-seal/activation crash cut. Reuse the four canonical K4 lifecycle methods and realize one generic claimed-artifact-attestation capability through class-correct members: because `sovereign.k4-durable-lifecycle` is still `approved_missing`, fold its immutable request/semantic keys, exact `signingPending | resultCommitted | resultErased` states, dual uniqueness constraints, bounded encrypted result bytes/digest, owner fence, bounded `recoveryNotAfter`, erasure reason/time, and request/semantic tombstone lifetime no shorter than the irreversible use/grant lineage into the one original W5 M/CreateGate first wire; likewise fold the required proof-free context binding and one canonical/low-S P-256 representation into the original `trust.algorithm-agile-manifest` first wire while that owner remains missing. Put only the incumbent authority/client/XPC call surfaces in same-wave E/A/ExtensionGate slices, each with the exact required `dependsOnCreateTerminalID` and disjoint allowed path; neither classification nor wave order is implementer-selectable. The combined capability must freeze the complete proof-free signed context, fence pending signer ownership/stale completion, commit result bytes before reply, replay committed results without re-signing only when bytes need recovery, and make erased results terminal and non-recreatable without turning K4 outbox state into Self currentness. K3 seal must independently verify the canonical public Artifact, full signed-context/request ancestry, complete local currentness/fences, and strict `now < recoveryNotAfter`; K3 activation independently repeats its complete local currentness/fence/deadline check, and neither transaction may span K4/XPC. Authorized deletion/revocation must install its K3/source-currentness semantic fence before K4 erasure; activation CAS versus that fence CAS defines order and late public puts remain headless inert orphans. Deletion completes only after one exact ordered closure: either every put-capable worker/accepted reply channel is proved quiescent before the final sweep, or an already-owned Artifact Mesh protocol first commits a durable lineage no-reinsert fence atomically checked by every put and then sweeps. Controlled convergence must classify and gate any needed Artifact Mesh extension; if neither path is proved, deletion remains pending/quarantined. Atomically revise the older signature-bytes-only prose as an explicit narrow idempotent-reply-outbox exception, gate every M and E/A member through non-empty manifests/fixtures plus Ed25519/P-256 concurrency/process-death/privacy tests, and create no App-specific API, Artifact payload, receipt, reservation handle, signer, Artifact store, target mirror, commitment-key sharing, boundary-anchor branch, cross-domain transaction, or recovery coordinator;
11. atomically flip the seven documents, ledger terms, checkers, and code to canonical `executeAtMostOnce` semantics and resolve terminal wire spelling drift rather than carrying conflicting names;
12. define one checked typed `LegacyPersonaSourceSinkRecoveryManifest` and use its single digest for all sixteen `BASAgentPersonaSpec` field dispositions/fixtures plus every legacy source, sink, public/Codable/recovery surface and negative control; retire the LOW-tier bypass, `personaInstructions`, both direct MLX system-message/`ChatSession.instructions` sinks, compare-all and compare-selected FullTurnAdapter/TranscriptProjection paths, cold-restart Persona/Host-Persona/warrant restoration, Skill descriptor/Registry/A2A/`buildAgentSpec`/invoker reinjection, `QinaoPersonaStudio`, aliases, and public DTO reachability; preserve only proven pure deterministic mechanism patterns, and install the profile/workspace-scoped structured Host-owned Companion Expression path without silently changing privacy posture;
13. treat every Qwen/MiniCPM/Granite Core AI route as an unavailable conversion candidate until exact export, function/StateABI, device, quality, recovery, memory, energy, thermal, and Release evidence passes; preserve the incumbent until retirement gates pass;
14. converge the exact `cold40` device/turn cardinality and every accepted-decode timer/denominator definition across architecture, harness, verifier, and claim surface before any named tier is requestable;
15. add non-vacuous tests plus separate current M CreateGate, E/A ExtensionGate, and schema-fixture manifests/proofs before the first production declaration; every critical suite pins a checked-in typed case-manifest digest and exact discovered/executed/expected-kill/killed cardinalities, treats zero/drift/survivors as failure, and includes a working negative control per domain;
16. record exact W-wave ordering so no test or step depends on a later-wave API;
17. prohibit reuse of retiring legacy `BASAgentSpec`, `BASAgentRegistry`, old `BASAgentProposal`, `BASAgentFabricRuntime`, `QinaoAgentCommitGate`, `BASAgentPersona*`, `personaInstructions`, cold-restart Persona/warrant, Skill invoker, direct system-message, or `QinaoPersonaStudio` paths as App Agent, Session, sharing, expression, context, or release authority;
18. preserve the App Agent Self adoption sequence `L13 immutable candidate/read-set -> shadow evidence -> L10 validate -> L11 risk/disclosure revalidate + exact self-governance-principal confirmation -> L13 exact adoption-intent prepare -> K3 invisible stage/frozen K4 request material -> L14 exact adoption decision -> K4 issue/reopen exact grant -> reserve exact tuple -> claim/use -> generic K4 claimed-target-attestation create/reopen -> caller-side ordinary target-attestation put -> K3 state-commit seal -> K3 activate/append`; current host candidate helpers are not silently promoted to final App Agent authority;
19. map the profile/workspace/root-exact `hostShared`, `appAgentPrivate`, `sessionPrivate`, and `explicitShare` classes onto incumbent Workspace/relationship/memory/Artifact/K3 owners and one controlled gateway. Freeze one complete `ExplicitShareAuthorizationSubjectDigest` across normalized confirmation, a non-substitutable per-share `crossAppAgentShare` grant, exporter, L11 `crossAgentDisclosure`, L14 `shareReleaseDecision`, K4 and every materialization; mutation-test cross-share splicing and self-governance/relationship/Main/adoption substitutions. Prove synchronous eligibility fencing before cleanup, no independent V1 share head/epoch or per-Agent SQLite/share store, and transitive absence of raw `BASArtifactStorePort`/`BASArtifactSQLiteStore`/`read(id)` reachability from every public Agent/Session/Runtime/Main/Sub/Provider/Studio/Catalog/Recognition/retrieval/compiler/share entrypoint through aliases, factories, protocol erasure, and joins;
20. fold `RequiredSemanticBaseline` into the approved-missing singular L7 State Requirement Planner/Plan original M first wire before it is created, with schema-derived exhaustive entity/coreference, polarity/quantifier/logical-scope/modality/time/causal/quantity/citation/code fixtures and byte-identical core digest across expression profiles. Fold the approved-planned pre-call publication policy into its original/controlled wire; only complete `bufferedUntilVerified` is eligible at this snapshot. Freeze one schema-derived canonical envelope over full `BASOutputSurface`, full `BASRenderedOutput`, externally version-tagged currently encoded `BASSurfaceDecision`, full `BASRenderFrame`, cues/accessibility/locale/audio/animation/haptic/semantic manifest/subject/currentness, plus a closed mode/surface/agency/disclosure/substitute/subject compatibility manifest; require exact `publication = L12 = L10 = L11 = L14`, future-version rejection, action-bearing substitute candidate/proposal/currentness/copy/confirmation binding, one new authorized Input Event per interaction, and no independent `TurnOutcome.surfaceDecision`/RenderFrame rendering. Future `incrementalVerified` remains disabled until one atomic migration retires/redefines current pre-L9 retractable `.provisionalStream`, maps the complete L9-selected answer graph, and adds claim/qualifier-complete per-batch equality plus durable `partialAuthorizedPrefix | terminalComplete` recovery semantics; partial can never drive completion, NextQuestion, or answer-derived adoption;
21. map natural-language Companion authoring to Input Normalizer -> L6 closed-field proposal -> L5 validation -> fixed semantic-null envelope or exact baseline/L9/L12/L10/L11/L14 rendered-preview mini-release -> explicit user Input Event binding the exact normalized proposal and complete ordered shown preview/static-asset digest set -> existing profile/workspace-scoped Host preference commit; cover `preRootSetupPreview` and `existingRootStudioPreview` subject equality, A-preview/B-commit/stale-edit mutations, and split root/preference recovery with only rebuildable `setupIncompleteNeutral`; create no `PersonaCompiler` or free-form executable prompt;
22. define Session/App Agent switch, deletion, handoff, delayed-result, Provider-rebase, and `sent_or_unknown` matrices so switching is always a new Session; drive a typed forbidden-carrier × recursive-depth/container × URI/Unicode/percent/case/canonicalization handoff manifest proving no transfer of KV, private relationship/memory, capability/signed URL, executable operation/boundary identity, idempotency/credential token, tool parameter/body, permit/grant, receipt, handle, retry/query instruction, or unresolved effect;
23. close `AgentRootInventory`, exact Host/UI and optional privacy-safe profile-scoped Catalog joins, explicit-share, Companion Expression, mandatory Session-selection CAS/evidence, quota, and per-Agent erasure schemas/fixtures/currentness/provenance tests or provide class-specific non-applicability proof; no prose-only access control is accepted;
24. install the manifest-driven production source/import/dependency/recovery/reachability gate proving every legacy/free-form Persona row—including distinct compare-all and compare-selected, public Skill/A2A/`buildAgentSpec`, cold-restart, alias and direct Provider-system-message rows—cannot reach the new Main, Context, L12 spool/batch, release, Self, relationship, memory, or state-commit paths; its discovered/executed/expected-kill/killed counts and digest must match, and each row has a mutation that makes the gate red;
25. install the checked `PresentationReverseInfluenceManifest` over every current/reachable complete canonical presentation field and all observation/coverage/honesty/workflow/update-ticket/commit-token/checkpoint/summary/halt/memory/evaluation/evolution/RSI/state sinks, beginning with the exact repo-root paths named in Section 6.4. Retire all direct output-derived coverage/halt, workflow, ticket identity/summary/confidence, commit/checkpoint, evaluator/promotion and adoption influence; adapt only legitimate diagnostics to exact App-Agent/profile/workspace/Session/Main/Attempt/source-envelope-bound untrusted observations that preserve root lineage, pass all seven cleaning gates, and require separate independent adoption. Bind forward-only render/audit rows to the full envelope. Adding a sink, dropping a scope/envelope parent, bypassing a pass, mutating an authorized carrier, or feeding derived bytes/count/hash directly into authority must make the non-vacuous gate red;
26. close the approved-planned `BASNextQuestionProjection` original wire/CAS with exact objective/schema, candidate set, winner/full meaning/tap payload, score/margin/threshold, answer/release/source/currentness/expiry and selected Agent/Session/Main parents; prove zero/one/five/tie/abstain cases, full buffered mini-release, stale/winner-loser mutations, semantic-null reveal-then-explicit-submit two-step UI, and exactly one idempotent Input Event/Attempt;
27. close the approved-planned phase-tagged `BASInformationSufficiencyPayload` original wire/fixtures and the incumbent ControlRing terminal-state/reason wires with one checked schema-derived case manifest. Pin all seven outcomes, legal phase/outcome and terminal-state/reason pairs, exact requirement/coverage/conflict/candidate/L14/currentness parents, at-most-one plan-authorized remand, canonical spellings, and working illegal-pair/outcome-upgrade/stale-parent/K3-receipt negative controls; make every adoption path require exact `converged + converged-verified` and a current committed K3 budget-use receipt, while every other authorized outcome remains presentation-only.

This design prefers zero new production authority owners. It permits new governed values only where controlled convergence proves that an existing owner already has the correct semantic and physical responsibility.

The execution order is `spec-only commit -> user review/approval of the written spec -> revised convergence/implementation plan pins the exact spec commit/blob/digest -> atomic controlled-document convergence -> gated implementation waves`. A later byte change to this spec invalidates the plan pin until it is reviewed again.

## 21. Rejected Alternatives

### 21.1 One App Agent root with multiple Persona skins

Rejected because a prompt/persona overlay cannot provide multiple independent identities, causal private memories, relationship continuity, recovery, or governed evolution. It remains useful only as the clamped Companion Expression of one real App Agent.

### 21.2 Independent Agent Mind service

Rejected because it duplicates L5, StateLake/memory, L3, K3, RSI, and authorization authority and creates a second mutable brain beside the fourteen-layer system.

### 21.3 Full self copied into all Sub Agents

Rejected because it expands private context, creates identity forks, lets weak specialists impersonate the whole, increases contamination paths, and wastes scarce context/memory.

### 21.4 No App Agent content in Sub Agents

Rejected because value-neutral workers can violate privacy, provenance, uncertainty, or task commitments. Sub Agents receive a purpose-scoped, non-linkable rendered behavioral/constitutional minimum and role slice instead; the trusted local parent retains stable proof.

### 21.5 Direct gradual Main-to-App learning

Rejected because model hallucination, injection, sycophancy, duplicated evidence, or one anomalous session could poison the long-lived self. Gradual influence exists only through cleaned independent evidence and governed adoption.

### 21.6 Per-Agent database or copied shared-memory snapshots

Rejected because duplicate stores and copied mutable authority create stale versions, ambiguous ownership, revoke/delete fan-out, split-brain restoration, and silent evidence laundering. Independent App Agent scopes share existing physical substrate while retaining exact logical/capability compartments; shared material remains owned by Host/Workspace/source owners.

### 21.7 One shared mutable Agent memory pool with ACL tags

Rejected because one missed SQL/FTS/vector/cache predicate leaks or mutates another App Agent's private state, and a scope tag on an Artifact is provenance rather than sufficient caller-aware access control. Sharing uses immutable, attenuated, currentness-checked views through governed gateways instead.

### 21.8 In-place App Agent switching inside one Session

Rejected because it can transfer Main identity, KV/context, permits, private relationship material, delayed Provider/Sub results, and unresolved external effects. A different App Agent always receives a new Session/Main lineage and only an explicit user-approved handoff export.

## 22. Candidate Summary

Qinao may host multiple persistent App Agent wholes beneath one stable non-writer application namespace/authorization-scope anchor. Each exact child scope retains one active root, private Self/relationship/memory/evolution lineage, and user-confirmed Companion Expression. Host-owned shared data remains neutral; cross-Agent sharing is an immutable, purpose-limited, provenance-preserving view and never a private-head mutation. No global Agent registry, manager, mutable pool, or per-Agent database is introduced.

Each Session immutably selects one exact App Agent root and one logical Main identity. The Main carries every non-omissible identity invariant and expresses the relevant active self without copying the full memory corpus. Qwen, AFM, local Core AI candidates, and authorized API profiles are replaceable cognition Providers rather than identity. Sub Agents are independent bounded specialists with isolated Context Capsules and only the necessary constitutional/task slice. The deterministic fourteen-layer/four-kernel/four-ring system carries and protects the selected App Agent across routing, memory, context, verification, risk, evolution, release, and recovery.

Every Main Agent can claim profile continuity only when Qinao proves the exact profile-resolution path and compiles a scoped Recognition section for the Session's selected App Agent through the trusted descriptor into the relevant `providerStep` capsule. Multiple App Agents may recognize the same authorized Host/profile, but each can restore or render only its own `present(exactRelationshipFacetRef)` or exact authorized share; `provedAbsent`, `notAuthorized`, and `unavailableOrQuarantined` remain honest non-facet states. It may claim account/device-principal authentication only when an exact non-rendered principal-binding receipt supports that assurance; it does not claim biological identity. No valid profile projection means `guestOrUnknown` and no claim of recognition.

Main Agents can shape future App Agent behavior only indirectly: they produce untrusted experience observations, which pass lineage sealing, seven-stage cleaning, quarantine, independent evaluation, L13 candidate/read-set, shadow/canary testing, L10/L11 review, L13 adoption-intent prepare, K3 invisible stage with frozen K4 request material, L14 authorization, K4 exact-grant issue/reopen, reserve, claim/use, generic claimed-target-attestation create/reopen, caller-side ordinary target-attestation put, K3 state-commit seal, and K3 activation CAS. No model writes or approves the self it embodies.

Companion Expression is a profile/workspace-scoped, structured, previewed Host preference constrained by the selected Self envelope and serious-context clamps. It may make an App Agent sound goofy, warm, shy, or playful, but cannot make it less correct, less careful, less secure, or less independent. Every visible/audible/interactive surface uses one exact full-field `PresentationReleaseEnvelopeDigest`, including output, surface decision, render frame, cues, accessibility, locale/audio, semantic manifest, subject, and currentness. At this snapshot only complete buffered release is eligible; future incremental release remains disabled until its separate L9-answer-graph, compatibility, batch, and partial/terminal recovery protocol is atomically adopted. L10/L11/L14 decide the same frozen envelope, L12 exposes only byte-identical authorized fields, and every action-bearing surface interaction creates a separately authorized Input Event.

Released presentation is never evidence of its own truth, fitness, or authority. The closed reverse-influence manifest retires direct output-to-coverage/halt/workflow/ticket/checkpoint/promotion/adoption paths and permits only scope/envelope-bound untrusted observations through all seven cleaning gates plus independent adoption. This is the contamination barrier that lets a strong or idiosyncratic Main embodiment influence an App Agent only through explicit, inspectable, reversible governance.

That separation preserves the intelligence, knowledge, creativity, and expressive strengths of Qwen, AFM, and future API models while keeping every App Agent identity inspectable, isolated, recoverable, model-independent, and capable of safe long-term relationship continuity.
