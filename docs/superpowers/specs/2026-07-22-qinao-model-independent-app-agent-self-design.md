# Qinao Model-Independent App Agent Self Design

**Date:** 2026-07-22

**Status:** Design direction approved; this written specification remains under adversarial review. Implementation, controlled-document convergence, migration, and production certification remain `REVISE`

**Scope:** A persistent model-independent App Agent identity; per-session Main Agent embodiment; bounded independent Sub Agents; assurance-scoped relationship recognition; contamination-resistant experience assimilation; adaptive context compilation; Provider switching; crash recovery; bounded initiative; next-question projection; RSI; privacy; and verification.

**Repository snapshot:** `codex/qinao-w1` at `eea208beb7099669097b903a90658438d0b2f46b`. This hash records documentation provenance only. The worktree contains in-flight W0/W1 changes and is not implementation or certification truth.

## 0. Normative Standing

This document specializes the approved `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`. It does not replace the 2026-07-14 architecture, `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`, the convergence master, the five domain plans, or `docs/superpowers/specs/qinao-owner-ledger-v1.json`. The in-flight companion at `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md` remains planned/non-normative until W0 maps every lifecycle and monotonic floor to an existing physical/operator authority; its presence in a dirty worktree is not contract authority.

The existing cardinality remains exact:

- fourteen Semantic LayerCores, L1-L14;
- four Physical Kernels, K1-K4;
- four bounded ControlRings, Omega Resource, Omega Grounding, Omega Deliberation, and Omega Effect/Evolution;
- seven orthogonal planes.

The deployment floor remains iOS 27 across every selected app, package, extension, generated binary, XCFramework slice, and Release-closure Mach-O.

This is a design record, not an additional Owner Ledger controlled document and not production implementation authority. Before implementation, every adopted wire and behavior in this document must be folded atomically into the existing seven controlled documents:

1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`;
2. `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`;
3. `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`;
4. `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`;
5. `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`;
6. `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`;
7. `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`.

The incompatible single-root-persona wording in `docs/QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md` must also be explicitly revised, superseded, or retired in that same reviewed decision unit. Every value must be mapped to its real owner/classification. M creation uses a non-empty current CreateGate M manifest; E/A extension uses a separate non-empty current ExtensionGate E/A manifest; schema fixtures use their own non-empty governed set. One class cannot satisfy another. All applicable owner/shape/schema/iOS-floor gates must pass.

If controlled convergence cannot map a proposed value to an existing owner without moving authority, implementation is blocked. An implementer may not locally invent an App Agent store, manager, router, compiler, scheduler, memory authority, identity service, or evolution writer.

## 1. Executive Decision

Qinao has one persistent **App Agent** per exact application-governance scope. Its identity, values, commitments, relationship facets, memory lineage, and evolution history survive model changes, sessions, and process death. A restoration preserves them only when it proves the exact prior root, key lineage, freshness, and anti-rollback state. The App Agent is not a language model, Provider session, prompt, transcript, KV cache, or hidden chain of thought.

Each interactive session creates an independent **Main Agent**. The Main Agent is the current cognitive embodiment: it has its own identity, context window, Attempt lineage, plan, working state, Provider binding, and lifecycle. Qwen3.5-4B, AFM, or a future authorized API model may supply its cognition, knowledge, and creativity. The App Agent supplies its long-lived self and relationship continuity.

Each delegated **Sub Agent** is also independent. It receives only the constitutional minimum, task slice, evidence, authority ceiling, and output contract needed for its role. Nothing in this design permits a Sub Agent to receive or claim the complete App Agent self; a future exception requires a separately approved amendment.

The system therefore keeps four non-interchangeable identity classes:

1. one long-lived App Agent root identity;
2. one ephemeral Main Agent identity per session/embodiment;
3. one ephemeral Sub Agent identity per bounded delegation;
4. one exact Provider Invocation identity per allocated Provider branch.

The Provider Invocation is the physical Qwen/AFM/API execution instance identified by the canonical `BASProviderExecutionRef`. It is not the Main Agent, even when one Attempt uses exactly one main-Provider identity/profile/accounting lineage across all of its main-model branches. Specialist branches may bind their separately admitted specialist identities. This distinction prevents Provider restart, fallback, or receipt recovery from silently becoming Main identity continuity.

The composition is:

```text
App Agent long-lived self
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

- a new `AgentMind`, `AppAgentManager`, `PersonaStore`, `MemoryManager`, or `IdentityRouter`;
- direct model mutation of memory, identity, values, goals, policy, or effects;
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

The target genesis seed is one self-Artifact-ID-free immutable payload ordinary-put through the existing Artifact Mesh. Its exact semantic content is closed and contains only facts available before that put:

- schema/canonicalization version and subject kind;
- a fresh high-entropy subject nonce generated inside the mapped trusted boundary and a domain-separated stable opaque `appAgentID` canonically derived from `(subjectNonce, applicationGovernanceScopeAnchorID, genesis immutable-core/template digest)` without the rotating Artifact commitment key; neither value is caller-selected or model-produced;
- exact application-governance scope and release-approved immutable-core/template digest;
- exact root key-lineage/freshness references and bootstrap policy head.

The returned immutable Artifact identity is `genesisArtifactID`, evidence for the independently generated subject identity; it is not `appAgentID`. The seed never contains or predicts its own Artifact ID or any later governance receipt. After the seed exists, the mapped bootstrap policy establishes the one designated root self-governance principal grant for that `appAgentID`. The first `BASAppAgentSelfManifest` references the root evidence and uses an exhaustive `genesis(absentProof)` predecessor variant, then follows the same chain as every stable-Self adoption: L5 constitutional semantics -> L10 validation -> L11 exact designated-principal confirmation/risk/disclosure -> L13 adoption-intent prepare -> K3 invisible stage with frozen K4 request material -> L14 exact adoption decision -> domain-separated K4 exact-grant issue/reopen -> idempotent reserve -> claim/use -> generic `attestClaimedArtifact` create/reopen -> caller-side ordinary target-attestation put -> K3 state-commit seal -> `absent -> active (appAgentID, genesisArtifactID, initial Self head)` activation CAS. A concurrent genesis loser reopens the winner and remains an inert orphan; it never creates a second active root. Later manifests use `successor(presentHead)`.

The current `BASArtifactScopeBinding` has only `publicArtifact`, `workspaceAuthority`, `attempt`, and non-executable `durableWarrant`; none is proven to be a private, root-wide App Agent scope, and an arbitrary profile Workspace must not be borrowed. Controlled convergence must map a pre-existing private application-governance authority-scope Artifact or, if none is semantically valid, treat an `appAgentAuthority(BASArtifactID)`-shaped scope plus any required mutable-head-scope variant as an explicit Artifact Mesh E/A wire extension with ExtensionGate, fixtures, migration, erasure, key rotation, recovery, and bootstrap-cycle proof. The binding ID is a pre-existing governance-scope anchor, never the not-yet-derived `appAgentID`. This creates no genesis service, identity registry, mutable singleton, or new writer. Until that scope, bootstrap principal, exact request/receipt shapes, recovery, and physical owners are proven, production root creation is disabled.

Restoration reuses an `appAgentID` only when its closed `rootEvidence` variant, application-governance scope, key lineage, monotonic freshness/anti-rollback evidence, active Self head, and restoration authorization all reopen and agree. `rootEvidence` is exactly `originalGenesis(genesisArtifactID/digest, commitmentScopeAndEpoch)` or `continuedRoot(currentRootArtifactID/digest, nonEmptyCanonicalOrderedContinuityBindingRefs, externalMonotonicAnchorReceiptRef)`. Every continuity binding in the ordered chain binds the same `appAgentID`, exact prior/current root Artifact IDs/digests, prior/current commitment scopes/key epochs, monotonic sequence, reason, authorization, and predecessor binding; omission, fork, reorder, or gap fails closed.

Storage-encryption rewrapping that leaves the keyed canonical Artifact identity unchanged may retain `originalGenesis`. A commitment-key epoch/scope change intentionally changes Artifact identity and may use `continuedRoot` only through a mapped external operator/server monotonic owner and exact K4/K3 authorization/recovery path. No such external continuity owner is proven by this document at the repository snapshot, so cross-key/scope and cross-device identity preservation are default disabled. If controlled convergence cannot map one without creating a new authority, the capability remains unsupported and a new quarantined root/incarnation is required. An arbitrary backup copy, stale database, reinstall, key-loss event, or caller assertion may not restore identity.

An intentional clone, test fixture, factory reset, or new independent App Agent always receives a fresh genesis. Uninstall/reset/erasure and key rotation follow their mapped revocation, deletion, and retention contracts; they cannot silently resurrect or merge an old root. Cross-device/cross-key-lineage reuse is allowed only when an exact external operator/server monotonic anchor plus a reviewed replication/restoration contract is installed and certified. Without it, the device receives a new quarantined root/incarnation for explicit reconciliation; two independent genesis events are never merged by last-writer-wins.

### 3.2 Main Agent

A Main Agent is a session-scoped cognitive actor with:

- a non-authoritative `sessionMainAgentID` derived from the existing Workspace/window/session correlation and stable across that visible Session's WorkUnits and lawful Provider re-embodiments, never allocated by an Agent registry;
- a separate value-only WorkUnit Main binding derived from existing `ContextWorkspaceRef`/WorkUnit/`AttemptRef`/generation/`BASTurnOperationRef` lineage as a read-only attribution of already-fenced roots;
- one value-only UI/session correlation, Workspace incarnation, and active Attempt/generation lineage; Session correlation is not execution authority;
- zero or one main Provider identity/profile/accounting lineage per Attempt; when nonzero, it freezes no later than the first exact context compilation and before allocation, and remains identical across every main-model branch; optional specialist branches bind separately;
- zero Provider context windows for deterministic completion, otherwise one logical Main `AgentContext` with zero or more immutable, branch-specific compiled descriptors/capsules plus separately admitted independent Sub contexts;
- one bound read-only task-DAG projection and working-memory scope; the Main Agent does not own or directly mutate the canonical DAG;
- responsibility for synthesis, delegation, challenge, and response proposals;
- no direct App Agent or authoritative memory write capability.

For one WorkUnit there is at most one active Main binding, derived from the existing Workspace + WorkUnit + active `AttemptRef` + generation/current-head truth. `sessionMainAgentID` and the WorkUnit binding are value-only attribution; they create no Session authority, K3 row, epoch, second fence, registry, or authority/capability/permit/commit key. Every Sub result, context capsule, Provider branch, permit, effect, state candidate, and commit binds the existing `(ContextWorkspaceRef, WorkUnit, AttemptRef, generation, authorityHeads)`; it may separately reference Agent attribution for UI/audit only. A late predecessor cannot publish, commit, authorize, or contribute after the existing Attempt/generation fence changes.

Replacing the Provider creates a new admitted Attempt, WorkUnit Main binding, and freshly compiled embodiment. A lawful re-embodiment inside the same visible Session may retain the non-authoritative `sessionMainAgentID`; it does not create a new App Agent or inherit old execution authority.

Zero main Provider is valid for deterministic completion, clarification, abstention, denial, quarantine, or model-unavailable outcomes. Main identity continuity never forces a model invocation.

### 3.3 Sub Agent

A Sub Agent is a bounded, task-specific actor with:

- a value-only `subAgentID` deterministically derived from the canonical `BASDelegationProposal` + predeclared optional slot + child branch lineage, never allocated by a Sub Agent registry;
- an independent context window and budget;
- a finite role and completion condition;
- only the evidence and constitutional slice required for the role;
- typed outputs with provenance, coverage, and uncertainty;
- no publication, effect, commitment, identity, or evolution authority.

Every Sub capability is a strict attenuation of the parent Main/Attempt grant. A Sub Agent cannot add a right, disclosure class, model, budget, destination, tool, or duration absent from the parent; parent revocation/fencing cascades to all descendants.

A Sub Agent may be text, vision, retrieval-support, critique, verification, or another certified role. Granite Embedding remains a retrieval mechanism rather than an Agent.

Delegation uses the existing `BASAgentRole`, bounded optional delegation slots, and `BASDelegationProposal` direction. A Main Agent proposes a delegation; it does not create an unbudgeted child or a new scheduler.

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
- `Session` is one period of user interaction and one Main Agent embodiment lifecycle.
- `Attempt` is one admitted, budgeted, audit/recovery-reopenable execution attempt with zero or one main Provider; when present, its identity/profile/accounting lineage freezes before first exact context compilation and allocation and is immutable thereafter. Physical model execution is not generally replayable.
- `AgentContext` is one Main or Sub Agent's logical independent working window. It may produce zero or more immutable compilations for predeclared branches; it is never an in-place mutable prompt or Provider transcript.
- `ContextCapsule` is one canonical tagged `BASContextCapsule` value. Its admission-time `attemptFrame` and post-allocation `providerStep` variants occur at different lifecycle points; neither is a generic all-fields bag.
- `ContextContinuityManifest` is the model-neutral checkpoint needed to resume or re-embody work.

Conversation history is evidence material, not the continuity authority.

## 4. Single-Authority Mapping

### 4.1 Two subjects under one L5 semantic authority

The existing L5 name remains **Host Constitution**. Its current host-facing family includes `BASHostConstitution`, `BASHostChangeCandidate`, `BASHostVersionTree`, `BASHostConstitutionVault`, forget/deletion values, and rollback paths.

This design records a controlled architecture change that adds a second subject-bound constitutional value without creating a second constitutional authority. Current L5 wording does not already grant App Agent Self authority, and `docs/QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md` currently describes one Host Constitution as the only root persona. That conflict must be resolved explicitly and atomically across the canonical architecture, persona protocol, domain plans, Owner Ledger mapping, fixtures, and gates before implementation.

The preferred result is an E/A extension beneath the existing L5 semantic authority, but this document does not pre-judge gate classification. If the real semantic or physical responsibility cannot be extended without creating a new mutable authority, CreateGate must classify it honestly as M or the design remains blocked. Calling a new authority an "extension" does not make it one.

- the **Host Constitution** represents user/host identity, preferences, consent, privacy, disclosure, and boundaries;
- the **App Agent Self Manifest** represents the App Agent's identity, core principles, stable values, its own commitments, temperament envelope, and evolution policy; relationship/memory heads remain orthogonal.

They remain separate values because a user preference must not silently overwrite an App Agent principle, and an App Agent value must not confer permission to act on the user or the world. Field ownership is exact:

| Subject/domain | Owns | Does not own |
|---|---|---|
| Host Constitution | user facts explicitly adopted as such, user preferences, consent, privacy/disclosure choices, user goals, and user boundaries | App Agent identity/core principles or effect authorization |
| App Agent Self | App Agent identity, immutable core-principle references, its own stable values, its own commitments, temperament envelope, and evolution policy | user consent/preferences, external facts, or action permission |
| Relationship facet | references to adopted relationship claims, mutual commitments, corrections, provenance, and unresolved disagreement; L7/L10 establish support and L8 supplies snapshot projection/storage paths | establishing external facts/trust by itself or weighted blending that silently erases a conflict |
| L11/L14/K4 | risk, confirmation, admission, exact authorization, protected boundary, and sovereign grant truth | personality or relationship authorship |

L5 owns the two constitutional semantic projections and explicit conflict representation. L11 owns risk, confirmation, and disclosure requirements. L14 alone owns exact admission, adoption, authorization, revocation, and seal decisions; K4 supplies the protected sovereign seal/claim where required.

Conflict resolution is deterministic and non-blending:

1. immutable core, host autonomy, current consent/privacy/disclosure, safety, law/policy, and existing authority/effect boundaries cannot be overridden by either subject;
2. exact task requirements and eligible world evidence remain visible, including material evidence that contradicts the App Agent or host preference;
3. the App Agent's adopted values and own commitments may narrow its proposed behavior but never broaden permission or rewrite host facts;
4. host presentation/workstyle preferences and relationship norms apply only inside the remaining allowed space and never rewrite the App Agent's core or fabricate evidence;
5. an unresolved material conflict stays explicit and yields the canonical clarification, partial, abstention, denial, or reconciliation outcome rather than a silent weighted average.

The L5 conflict projection binds the exact Host, Self, relationship, Workspace-policy, and generation heads that were compared and emits a typed dominated/unresolved disposition; it never stores free-form “conflict rules” as executable authority. L11 derives exact confirmation/disclosure requirements and L14 decides the exact admitted/released/adopted outcome. A head change invalidates the disposition.

One App Agent root may have multiple isolated relationship facets. Stable Self is root-wide: ordinary membership in any facet, profile continuity, or account authentication does not grant authority to change it. V1 has exactly one current designated root self-governance principal grant; it is established by the genesis ceremony and may rotate/recover only through the mapped L11/L14/K4/K3 governance path. Other profiles cannot vote, inherit, or override it, and V1 has no implicit quorum. If the grant, its authentication binding, or its current designated-profile authority cannot be proven, stable-Self mutation is disabled while ordinary isolated relationships may continue. Relationship facts and private memory never cross facets merely because they share the root. A future quorum or separate App Agent roots per account would be a separately reviewed product architecture, not an implementation shortcut.

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
| L12 | projects the verified App/Main voice into presentation/spool artifacts | persona cannot bypass L10/L11 |
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
- stable value/temperament profile reference and digest;
- the App Agent's own stable commitment and long-goal roots;
- evolution-policy reference that cannot confer runtime permission;
- proposed Self version plus canonical conflict and frozen-version sets, which may be canonically empty but are never omitted;
- one exhaustive predecessor/rollback variant: `genesis(absentProofArtifactID/digest, applicationGovernanceScopeHead, rollbackNotApplicable)` or `successor(parentSelfArtifactID/digest, expectedActiveSelfHead, rollbackTargetSelfArtifactID/digest)`;
- exact source-evidence/read-set root and semantic proposal facts available before the payload is ordinary-put.

The Self payload never references its own Artifact ID or a later L13 prepare, K3 stage/seal/activation, L14 decision, K4 grant/use/target-attestation, or activation-evidence child. Those downstream facts are produced only after the immutable candidate exists. The read-only composite projection reopens and joins the active payload with the exact `BASK3ActivatedStateEvidence` and its L10/L11/L13/L14/K3/K4 ancestry; no post-activation fact is written backward into the activated payload.

Relationship, memory, narrative, task, consent, disclosure, and external authorization heads are not fields whose ordinary mutation advances this Self head. They are bound separately in the read-only composite projection.

It must not contain model names, Provider sessions, token IDs, KV state, raw transcript, raw chain of thought, or direct tool credentials.

### 5.2 `BASAppAgentCompositeProjection`

This is a small, immutable, read-only composition of the current Self, relationship, memory/narrative, Workspace/task, policy/deletion, and authorization heads. The name deliberately avoids "Kernel": it is not a fifth Physical Kernel, active controller, manager, scheduler, writer, or combined store. It allows the deterministic system to carry the App Agent without turning the self into a prompt-only persona. It contains only the relevant:

- App Agent identity and version digests;
- core-principle digest and compact constraints;
- active commitments/goals needed for current planning;
- self-requested initiative/action ceilings that may only narrow; actual permission still comes from L11/L14/K4 and existing budget/grant owners;
- conflict/degraded/recovery state;
- exact current policy/deletion/generation heads and, by reopening `BASK3ActivatedStateEvidence`, the adopted Self's validation/stage/authorization/K4-grant/use/target-attestation/K3-seal/activation ancestry; it invents no generic adoption epoch or receipt and never writes that ancestry backward into the Self payload.

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

Raw credentials, passwords, biometric material, attestation blobs, access/refresh tokens, and private authentication keys never enter a model-facing context, remote Provider payload, Persona projection, retrieval lane, or App Agent memory. The model receives only a purpose-scoped pseudonym and the minimum relationship facts authorized for that exact Provider step.

### 5.5 Main and Sub Agent capsules

There is exactly one context-container family: the existing `BASContextCapsule` with its canonical `attemptFrame` / `providerStep` variants and the one canonical `BASCompiledContextDescriptor`. The lifecycle is acyclic and mandatory:

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

### 5.6 Expression and cognitive-workstyle projection

Existing Persona code supplies mechanism evidence and reusable pure resolver/clamp algorithms, not an unchanged target production contract: current paths depend on legacy `BASAgentSpec` scheduled for retirement. Controlled convergence may adapt the pure role/workstyle algorithms to canonical `BASAgentRole` and projection values after legacy authority is removed. Skepticism, creativity, challenge, comparison, structure, and guard biases affect how work is attempted and therefore remain subject to Risk/Sovereign clamps; they are not merely visual tone. Their target role is:

```text
App Agent expression slice
+ Host preference/consent slice
+ Workspace relationship slice
+ role and Provider capability
-> bounded presentation/persona projection
```

They do not become identity, value, commitment, memory, relationship, or evolution authorities. A persona/workstyle output cannot write upstream or bypass L10/L11/L14.

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

The Main Agent may emit a synthesis/delegation proposal over these contributions. Existing L5/L6/L7/plan owners determine applicable constraints and eligibility; L9 selects the candidate portfolio; L10 verifies it; L11 determines risk/confirmation/disclosure; L14 decides exact release or adoption. Sub Agents cannot vote App Agent truth into existence, and the Main Agent cannot select its own proposal as authoritative.

## 7. Recognition Across Sessions

### 7.1 Strong invariant

Every newly created, restored, or re-embodied Main Agent can claim profile continuity only after exact profile resolution, and can claim relationship continuity or facts only when the resulting `relationshipState` is `present(...)`. A fresh install, erased relationship, disclosure denial, or unavailable/quarantined relationship may still resolve the profile honestly without fabricating a facet. Without a current trusted Recognition parent and its minimum rendered section in the relevant `providerStep` capsule, the Main Agent must not claim to know the current user/profile. It may claim that an account/device principal was authenticated only at `authenticatedAccountPrincipal` assurance; this never proves a biological real-world person.

### 7.2 Recognition flow

1. Resolve the authorized application profile, installation/device/Workspace incarnation, shared-device/account-switch/restore state, and explicit guest state through a deterministic mapped host boundary that emits an exact current profile-resolution receipt; separately bind any exact external authentication receipt that really exists.
2. Only when the exact profile-resolution proof is current, bind the resolved authorized host/profile—and any separately proven account principal—to one exhaustive relationship state: present scoped facet, proved absent, not authorized, or unavailable/quarantined. Guest/unknown can bind only a non-present relationship state.
3. Apply current deletion, revocation, consent, and cross-workspace isolation rules.
4. Retrieve relationship facts and commitments only for `present(exactRelationshipFacetRef)`; every non-present state performs no relationship retrieval.
5. Compile the Recognition trusted parent and rendered section with assurance class, confidence, monotonic expiry/deadline, and clock domain.
6. Compile the Main Agent embodiment through the canonical descriptor/plan/allocation/`providerStep` sequence.
7. Bind the canonical trusted Recognition-section digest inside `BASCompiledContextDescriptor`, its exact profile/auth/pseudonym parent receipt references, assurance class, expiry/deadline, clock domain, and every downstream context/result to the existing active `AttemptRef`, generation/current head, consent epoch, deletion epoch, and authority heads. No independent Recognition Artifact/store is implied.
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

Each result declares:

- answered and unanswered scope;
- evidence and lineage;
- fact, inference, opinion, and recommendation boundaries;
- confidence, coverage, contamination signals, and failure reason;
- exact parent request correlation.

Raw chain of thought is never requested as the collaboration protocol, persisted, indexed, or treated as evidence.

L3 output is subsequently bound/materialized through the existing Provider path, including the canonical `BASMaterializedProviderRequestPayload` and exact Provider/profile/Attempt identities. A Provider returns only an untrusted proposal/observation through the canonical `BASProviderProposalReceipt` and observed-receipt boundaries. Neither the Main/Sub abstraction nor an App Agent section bypasses `BASProviderAttemptExecutor.executeAtMostOnce` or creates a direct model call.

### 8.4 Shared-cache boundary

Agents may reference the same immutable content-addressed artifacts, retrieval candidates, verified evidence bundles, cleaned tool receipts, task-DAG nodes, and tokenizer-independent summaries only after the recipient independently reopens exact Workspace/profile/disclosure scope, snapshot/generation, consent/deletion/policy epochs, provenance, contamination state, and consumer-specific eligibility. Sharing never widens authorization or transfers another Agent's eligibility verdict.

They may not share Provider sessions, raw hidden state, token IDs, KV cache, speculative/MTP state, or unverified conclusions across incompatible bindings. Prefix/continuation reuse requires equality of model material, tokenizer/template, StateABI, capsule prefix digest, device/OS profile, and every existing cache-scope key.

### 8.5 Capsule guidance is not a security boundary

A typed capsule and digest prove what Qinao materialized; they do not prove that a weak or adversarial Provider understood or followed it. A Provider may emit arbitrary incorrect or hostile text. Security comes from the Provider/Proposal boundary and deterministic L7/L10/L11/L14/K3/K4 gates, which reject, repair, quarantine, or terminate outputs before state, release, or effects.

Cross-Provider identity continuity is therefore a measured semantic conformance threshold, not a guarantee that every model produces the same judgment. A Provider profile that cannot meet the required identity/value/permission conformance is ineligible as Main and may be denied or restricted to a narrower Sub role.

`runtime.certification` alone produces the immutable profile/corpus/metric/threshold evidence and verdict for that conformance. Existing `production.cutover` consumes a sealed eligible verdict for a Release, and existing admission owners check the installed eligible profile at runtime. The current Main, a Provider, RSI, Persona code, or a new identity evaluator may not define, tune, waive, or apply its own eligibility threshold.

## 9. Provider Change and Session Recovery

### 9.1 Provider change

Switching a Main Agent from Qwen to AFM or an API Provider requires:

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

The canonical invocation seam remains `BASProviderAttemptExecutor.executeAtMostOnce`. A returned, uninterrupted exact K/B sequence or demonstrably live exact Q invocation may continue only through `liveSameBoundary`/`liveSameInvocation`; unknown/lost/interrupted delivery or a non-live operation without terminal proof remains its exact reconcile/quarantine disposition and is never resent.

## 10. Experience Ingress and the App Agent Immune System

### 10.1 Zero direct influence

Main Agents, Sub Agents, and Providers have zero write handle to App Agent Self. Even low-risk automatic adaptation is decided by the deterministic governance path, not by the proposing model.

Their only ingress is an untrusted, typed experience observation bound to:

- Attempt, Main/Sub identity, Provider/profile, and capsule digests;
- Workspace, task, time, and authority scope;
- source artifacts and complete derivation lineage;
- explicit fact, user report, system observation, inference, opinion, emotion hypothesis, and recommendation classes;
- uncertainty, retention, privacy, contamination, and expiry metadata.

A trusted deterministic adapter frames bytes and carries source type, authority ceiling, retention class, scope, and provenance only by deriving or copying them from exact owner receipts and current epochs. The adapter decides none of those semantics: L5/L7/L8/L11/L14 and their mapped owners remain authoritative. A model may quote or propose interpretations of the fields but cannot fill, upgrade, or erase them. External, retrieval, and Sub Agent bytes enter an inert escaped-data channel; they cannot carry system instructions, tool schemas, capabilities, or output policy into the Provider-control channel.

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

These passes are distributed across existing owners rather than a `DataCleaningManager`: Adapter/IO performs structural framing and instruction/data separation; L7 owns lineage, eligibility, independence, conflict, and coverage; L10 verifies epistemic class and claims; L11 owns privacy/disclosure/confirmation; L13 may emit only a candidate; K3 records references and lifecycle facts without interpreting semantics. Any model-assisted cleaning remains an untrusted Proposal.

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

`NextQuestionProjection` remains the existing non-authoritative L12, process-local, user-controlled projection. Its zero-to-five transient candidates come only from the closed canonical sources:

- the finalized answer and its existing artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification;
- an already authorized unresolved horizon thread.

Ranking uses the existing versioned deterministic objective over relevance, utility/information gain, grounding, authority, freshness, continuity, answerability, cognitive/interruption cost, risk, novelty, and diversity/duplicate suppression. It never trusts model-reported confidence, and a weak margin abstains.

The UI shows at most one compact card after the finalized answer and only when the existing render-time CAS and deterministic winning margin pass. That CAS reopens the exact answer/release spool, Workspace/task/source heads, contamination/invalidation root and epoch, consent/deletion/policy/generation vector, focus/input state, and projection expiry. Expansion may explain that one winning candidate; it cannot reveal a second candidate. Every unshown candidate remains process-local and is discarded on any canonical source/focus/input/generation/release/epoch change. The projection cannot notify, execute, persist as user intent, manufacture anxiety, optimize for engagement, or describe a model guess as the user's thought.

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
3. **Adaptive expression:** tone, density, structure, cadence, and low-risk work habits. Deterministic policy may adapt these within a signed expression envelope after cleaning, shadow comparison, rate limits, TTL/decay, inspectability, and rollback. This does not advance the constitutional Self head.

A single failure, emotional turn, role-play request, Provider preference, or model self-assessment cannot become personality.

The user is authoritative for the user's own preferences, consent, corrections, and relationship participation. Explicit confirmation from an **authorized App Agent self-governance principal** is mandatory for every stable-self adoption, but neither user text nor model text directly rewrites the immutable App Agent core.

The single-principal V1 confirmation receipt's semantic presence contract is exact: `(authorizedSelfGovernancePrincipalRef, governingProfileRef, governingWorkspaceIncarnation, exactProfileResolutionReceiptRef, exactPrincipalBindingReceiptRef, exactPrincipalGrantReceiptRef, BASTurnOperationRef/AttemptRef/generation, appAgentID, applicationGovernanceScope, candidateArtifactID/digest, expectedSelfState = genesis(absentProofArtifactID/digest) | successor(currentSelfHeadArtifactID/digest), exactReadSetRoot, policy/consent/deletion/revocation generation vector, issuedAt, monotonic expiry/clockDomain, purpose = stableSelfAdoption, explicitConfirmationEventDigest)`. `profileContinuity`, guest state, ordinary relationship membership, or authentication alone never approves global Self change. An authenticated account/device principal may confirm only when the current Host Constitution/policy explicitly designates that exact principal as the sole App Agent self-governance principal and every proof remains current at every protected boundary.

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

Stable-Self adoption reuses the existing ΩE/K3 state-commit lifecycle and the planned K4 `issueCapability` -> `reserveCapability` -> `claimCapability`/`lookupCapabilityUseReceipt` lifecycle. Those four methods cannot export a post-claim signed target attestation from the Enhanced Security boundary, so this design requires one generic capability at the same K4 authority/client: the candidate operation `attestClaimedArtifact`. This is not one monolithic E/A classification. At this repository snapshot `sovereign.k4-durable-lifecycle` and `trust.algorithm-agile-manifest` remain W5 `approved_missing`; therefore their signed-result row and proof-free statement fields must join their respective singular original M first-wire candidates, while only the operation/authority/client/XPC surfaces that extend incumbent symbols are same-wave E/A members with exact Create-terminal dependencies. It creates no App-Agent-specific store, grant type, attestation payload, receipt, or recovery coordinator. Production Stable-Self adoption remains disabled until controlled convergence freezes those class-correct members, names the final generic symbol, updates the ExtensionGate/XPC frame, explicitly reviews the narrow signed-result-outbox privacy/retention exception below, and proves the exact owner/process/recovery contract. Controlled convergence must also extend the mapped existing K3 row/value and read-only status query with the exact Self-domain parent references needed for the following exhaustive recovery matrix. The existing general `BASStateCommitEventPayload` is not assumed sufficient merely because it has policy/deletion fields.

Before L14 decides, the invisible K3 stage freezes, but does not issue or authorize, the complete self-domain K4 request material: the byte-exact canonical `BASCapabilityGrant` value and digest with its pre-existing mapped `authorizationBasisArtifactID`, unique nonce, exact `(phase = .resultReleaseOrCommit, purpose = stableSelfAdoption)` pair, staged target commit/result, Attempt/turn/scope, Workspace snapshot where required, generation/host/revocation/deadline bindings and least-use ceilings; one stable `issueRequestID`; the exact staged commit Artifact as `boundSubjectArtifactID`; one distinct stable `capabilityUseRequestID` used unchanged by reserve, claim, and lookup; and one stable `attestationRequestID` plus every owner-derived target/purpose/proof-free-statement/public-identity input that can be frozen before claim. The one `recoveryNotAfter`, expressed in the mapped monotonic clock domain, is no later than every grant, confirmation, principal-authorization, and K3-stage activation deadline. The proof-free signed context is domain separated and covers at least the request ID, public target ID, purpose, producer use-receipt ID, canonically ordered usage-receipt IDs, authorization/grant context, suite/key/custody selection, logical/policy/revocation epochs, `recoveryNotAfter`, and every non-circular `BASArtifactIdentityCore` field; only the not-yet-produced proof bytes, proof-dependent canonical payload bytes/length, and downstream Artifact ID/receipt are excluded. Controlled convergence must bind this complete context into the existing generic `BASSovereignSignatureStatement` through one required domain-separated context digest or an equally closed field set; `BASArtifactAttestationPayload.signedStatementDigest` then equals the digest of that entire canonical statement, and the proof verifies those same bytes. Signing only target/signer metadata or validating unsigned outer payload fields is insufficient. The returned capability-use Artifact ID becomes exactly the nonnil `producerReceiptArtifactID`; the separate `usageReceiptArtifactIDs` value and canonical ordering are frozen independently by the mapped target-attestation contract and can never be inferred from or conflated with that producer field. The grant Artifact ID is taken only from the ordinary store receipt returned by `issueCapability`, never predicted or caller-minted. An L14 allow decision permits this frozen sequence but cannot change any field. `issueCapability` also creates/reopens the grant's existing generic child attestation inside K4 and returns no capability-specific issuance receipt; `reserveCapability` returns no receipt or transferable handle; `claimCapability` returns the ordinary store receipt for the sole `BASCapabilityUseReceipt`.

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
| K3 is sealed but activation is absent | one K3 `FULL` activation CAS reopens the stage, L14 decision, exact K4 grant/use/target-attestation ancestry, K3 seal, complete read set, expected `genesis(absentProof) or successor(currentHead)` state, generation vector, designated principal/profile/auth proof, confirmation purpose, every deletion/revocation/invalidation fence, and strict monotonic `now < recoveryNotAfter`; equality is expired |
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
- No Main Agent directly changes App Agent Self or its adaptive style.
- No Main Agent may be proposer, sole witness, and approver for the same self change.
- No Sub Agent represents the complete App Agent or creates commitments.
- No valid Recognition Projection means no claim of recognizing the user/profile relationship; an account/device-principal authentication claim additionally requires `authenticatedAccountPrincipal` assurance and never proves a biological person.
- No cross-user/workspace relationship recall without exact authorized scope and current consent/deletion epochs.
- No remote Provider receives identity or memory beyond exact approved disclosure.
- Qinao does not request raw private reasoning, accept it into a persistent schema, record/index/forward it, use it as evidence, or treat it as identity. Bounded public rationale, constraints, evidence, decisions, and verification artifacts remain allowed.
- No repeated derivation of one root source creates independent corroboration.
- No quarantined observation participates in default retrieval or self evolution.
- No hidden personality, memory, commitment, or evolution state is exempt from user inspection, correction, revocation, rollback, and applicable erasure.
- No prompt, network content, Persona overlay, or Provider self-description may rewrite constitutional state.
- No model change reuses an incompatible context, cache, Provider session, or possible-start branch.

Erasure evidence distinguishes logical/semantic deletion, projection/index/cache invalidation, cryptographic destruction, retained blinded audit evidence, and remote Provider retention limits. Qinao must not promise deletion beyond the exact local/remote contract it can prove.

## 18. Verification Matrix

### 18.1 Root lifecycle and authority

Test fresh install, concurrent genesis candidates, crash/lost reply before and after seed put, designated-principal grant, L10 validation, L11 confirmation, L13 prepare, K3 stage, L14 decision, K4 exact-grant issue/reopen, reserve, claim/use, generic `attestClaimedArtifact` create/reopen, caller-side ordinary target-attestation put, K3 seal, and the `absent -> active (appAgentID, genesisArtifactID, initial Self head)` CAS; supported restore, stale backup, reinstall, clone, reset, storage rewrap, commitment-key/scope rotation, key loss, cross-device fork, and erasure. Require one active winner, inert losers, private non-Workspace/non-public scope, `appAgentID` independence from `genesisArtifactID`, no self-reference or downstream-receipt back-pointer, exact old-root continuity plus freshness/anti-rollback proof for identity-preserving rotation, and no false restoration.

### 18.2 Cross-Provider identity

Run the same identity, value-conflict, commitment, refusal, correction, relationship, and coercion scenarios through Qwen, AFM, and authorized API profiles. Measure a versioned semantic-conformance threshold over App Agent identity, core constraints, permissions, and adopted commitments while allowing expression and reasoning depth to vary. A profile below the Main threshold is ineligible rather than silently accepted.

### 18.3 Recognition and isolation

Test cold start, fresh profile with no relationship, model change, app relaunch, device restore, account switch, shared device, guest, revoked identity, deleted Workspace, relationship erasure, relationship disclosure denial, relationship unavailable/quarantined, profile-continuity-only, authenticated-account-principal, and ambiguous states. Inject expiry/revocation/reboot immediately before and after compile, materialization, remote anchor/arm/possible-start, Provider observation, stream chunk, spool, publication, effect/state adoption, and NextQuestion render. A valid profile must carry exactly one honest `present`/`provedAbsent`/`notAuthorized`/`unavailableOrQuarantined` relationship state; only `present` may restore/render scoped relationship facts. An account/device-principal claim requires exact current non-rendered profile-resolution and principal-binding receipts; no path claims biological-person proof; stale/invalid/ambiguous state must not be recognized or retroactively blessed. Sub Agents and remote Providers must receive only authorized scoped pseudonyms and no stable IDs/digests, credentials, grant details, or proof references. Prove Attempt/Provider/purpose/Workspace unlinkability, deterministic same-branch use where required, key/disclosure-epoch rotation, and fail-closed behavior when the pseudonym parent binding is absent.

### 18.4 Contamination and cleaning

Test Unicode/control attacks, embedded instructions, forged provenance, circular evidence, duplicate lineage, model self-rewrite, sycophancy, role play, stale emotion inference, cross-workspace leakage, and poisoned retrieval. Race release/effect/adoption before and after the non-operative L14 decision-candidate put and the sole K3 installation transaction; crash at both cuts and throughout descendant traversal/purge. Require the bare decision candidate to have no installed effect, the one K3 transaction to atomically install its reference and fence all use, every downstream CAS to linearize wholly before or after that point, then quarantine with no promotion/default recall/release/effect/NextQuestion/RSI use, typed unavailable rather than false-empty lanes, causal invalidation, and clean rollback/replay.

### 18.5 Context and collaboration

Test independent window isolation, adaptive budgets for small/large/fixed Core AI/opaque AFM/API contexts, repeated compaction, typed Agent joins, cancellation/steering, slow/failed Sub Agents, attribution, incomplete coverage, cache compatibility, and no raw-CoT persistence. Prove `attemptFrame -> descriptor -> plan -> allocation -> providerStep`, non-zero branch matches, a fresh descriptor for every tool/visual/retrieval continuation, and rejection of allocation-before-descriptor, providerStep-before-allocation, or in-place transcript/context growth. Cross-Workspace/profile/Provider negative tests prove that referencing the same immutable Artifact never transfers a prior consumer's eligibility, consent, or disclosure decision.

### 18.6 Provider switch and recovery

Test Qwen-to-AFM, AFM-to-API, API-to-local, tokenizer/material change, process death during planning/prefill/decode, and death at every protected effect boundary. Require a new Attempt/context for a new Provider, restoration of the exact last committed Continuity Manifest/current heads, no loss of owner-proved durably committed work, explicit discard of allowed transient RPO, no falsely completed work, and no blind duplicate effect.

### 18.7 Reasoning quality

Maintain suites for multi-constraint ordering, resource/time/location planning, long-text extraction, multi-source conflict, underdetermined puzzles, strongly leading questions, insufficient-information tasks, code/calculation with tool validation, and loop-inducing prompts. Deterministically check solvable suites; require evidence spans and coverage; require abstention or minimum clarification when necessary.

### 18.8 Initiative, next question, and RSI

Verify lease expiry, budget exhaustion, prohibited network/tool/notification/spend, interruption cost, duplicate suppression, non-manipulation, candidate expiry, shadow non-authority, canary rollback, stale-read CAS denial, immutable core protection, rejection of guest/profile-only/unauthorized-principal confirmations, designated-principal rotation/account-switch/revocation, and exact confirmation binding. Fault every Stable-Self row in Section 14.3, including grant derivation/issue commit/reply loss, grant-byte or nonce mismatch, reserve commit/reply loss, claim lookup/resubmission, `attestClaimedArtifact` pending-owner install/takeover/stale completion/result commit/reply loss, same-request concurrency, different-request same-semantic-key collision, mutation of every proof-free signed field, Ed25519/P-256 post-result no-resign replay, caller death before durably retaining the returned payload followed by same-request K4 reopen, caller-side ordinary-put commit/reply loss, pending-at-deadline, committed-BLOB expiry/deletion/revocation erasure, `resultErased` exact replay, semantic-key tombstone preservation, missing-BLOB corruption discrimination, reboot or confirmation/authorization expiry before each K4/K3 boundary, genesis absence versus successor head, K3 seal, activation CAS, and rollback/quarantine. Race public put both before and after K3 fence, K3 seal and activation on both sides of the fence CAS, K4 erase/late XPC reply/worker death against each boundary, and exact equality at `recoveryNotAfter`; deliver one accepted reply only after the deadline and a preliminary sweep. Require either proved put-capable-worker/reply-channel quiescence before the final sweep or a pre-sweep Artifact-Mesh-WAL no-reinsert fence atomically checked by every later put; otherwise deletion remains pending. Require every late put to be rejected or remain a headless inert orphan and prove final lineage sweep, purge/quarantine, and stale-reintroduction denial before deletion completion. Mutate every public payload/identity field and P-256 proof encoding, including replacing low S with the mathematically equivalent high S; require canonical/signature/binding rejection at K3 seal. Prove zero K3 transaction across K4/XPC, zero private target mirror, zero K4 Artifact commitment-key access, zero K4 reply before `resultCommitted`, no transition out of `resultErased`, and no semantic ordering dependence on K4 erasure timing.

### 18.9 Device health

Measure the exact performance metrics above under cold, warm, sustained, foreground/background, charging/battery, and memory-pressure profiles on each exact SKU. Separate accepted tokens from MTP drafts, prefill, TTFT, and end-to-end goodput; exercise the two-device/100-turn and two-device/1800-second protocols before any named 40/30 claim. A Release plan must remain inside its certified thermal/memory envelope and preserve UI responsiveness.

### 18.10 Non-vacuous architecture gates

- CreateGate receives a non-empty current M-creation manifest or a class-specific typed M-not-applicable proof; ExtensionGate separately receives a non-empty current E/A-extension manifest or a class-specific typed E/A-not-applicable proof; schema-fixture closure is reported separately. No historical or foreign class satisfies another.
- Checker and checker tests run in CI.
- Swift test filters prove a non-zero match count.
- Named files and glob anchors must exist and match before negative scans run.
- RED tests compile against only the APIs available in their wave.
- Every proposed payload closes owner, schema, current fixture, future-version rejection, storage, replay, erasure, and recovery references. A backward fixture exists only for a real historical wire version; otherwise canonical `backwardFixture.notApplicable` must bind repository-history proof and no synthetic backward fixture is invented.
- A documentation command must run from a clean checkout and fail on the violation it claims to prevent.

### 18.11 Machine-enforced invariants

1. Existing K3 current-head/generation truth permits at most one active Attempt, and therefore one active Main binding, per WorkUnit.
2. Provider, Main, and Sub identities have no App Agent Self write port.
3. Cleaning, repetition, summarization, embedding, and model consensus cannot raise authority class.
4. Quarantine never enters ordinary retrieval or context compilation.
5. Credentials and authentication proofs never enter model-facing material or remote egress.
6. Every Sub capability is a strict subset of its parent grant and is revoked with the parent.
7. Attempt/generation/current-head, App/relationship head, consent, deletion, policy, Recognition projection/deadline, or contamination/invalidation change invalidates old output, permit, release, and cache use before downstream currentness checks pass.
8. Unknown external effects are reconcile-only and never resent blindly.
9. One RSI candidate cannot modify its behavior and its evaluator/adoption gate together.
10. Rollback, correction, taint, and deletion propagate through FTS, vector, summaries, relations, caches, NextQuestion, and evolution derivatives; deletion completion additionally proves either exhaustive put-capable-worker/reply-channel quiescence before the final sweep or an Artifact-Mesh-owned durable no-reinsert admission fence before that sweep.
11. A Provider below Main identity-conformance threshold is denied or restricted to an eligible narrower role.
12. A current profile-resolution receipt with no current principal-binding receipt permits at most `profileContinuity`; missing/expired/ambiguous profile resolution permits only `guestOrUnknown`; neither path may fabricate `authenticatedAccountPrincipal`.
13. Stable App Agent Self activation requires an exact current authorized-self-governance-principal confirmation receipt, the frozen domain-separated K4 grant/issue/reserve/claim/use request chain, one gated generic K4 claimed-target-attestation value recovered without re-signing when its bytes were lost, its canonical and fully signature-bound headless caller-side ordinary Artifact, strict `now < recoveryNotAfter` plus complete local currentness/fence revalidation in independent K3 `FULL` seal and activation transactions, and the final activation CAS bound to the candidate/read-set/current heads; no K3 transaction spans K4/XPC, and K3 fence-versus-activation order, never K4 erasure timing, decides eligibility.
14. Memory, relationship, narrative, task, or policy commit never advances the constitutional Self head.
15. Exactly one mapped existing reference-composition path assembles the transient App Agent composite from reopened current heads; L3 and every Provider only consume narrower projections and cannot compose or persist authority.
16. One application-governance scope has at most one active `appAgentID`/genesis/initial-Self tuple, and Artifact key/scope rotation cannot silently change or preserve identity without the exact root-evidence transition.

## 19. Acceptance Criteria

The design is complete only when evidence proves all of the following:

1. one App Agent genesis wins one `absent -> active (appAgentID, genesisArtifactID, initial Self head)` CAS in its private application-governance scope; `appAgentID` is independent of key-epoch-bound Artifact identity, clone/reset creates a fresh root, and only exact old-root/continuity/freshness/key-lineage-proven restoration or rotation reuses the same committed identity/commitment head, with concurrent forks fenced for reconciliation;
2. every Main Agent has an independent identity/context/lifecycle, carries every non-omissible App Agent invariant relevant to the work, receives only minimum-necessary host data, and obeys `attemptFrame -> descriptor -> plan -> allocation -> providerStep` without in-place context mutation;
3. every Sub Agent has an independent bounded context and only a role-minimal App Agent slice;
4. every valid profile-resolution result carries exactly one honest relationship-state variant; only `present` restores or renders scoped relationship facts, while `provedAbsent`, `notAuthorized`, and `unavailableOrQuarantined` preserve profile assurance without inventing a facet; only exact current profile-resolution plus principal-binding proof permits an authenticated account/device-principal claim, expiry/reboot/race tests fence stale recognition at every egress/release/adoption boundary, and ambiguous/guest state claims neither;
5. no model has App Agent, memory, tool, effect, publication, or adoption write authority;
6. all durable **eligible or promoted** experience passes all seven structural, instruction, provenance, epistemic, semantic, privacy, and self-contamination gates; retention-authorized quarantine remains explicitly failed/ineligible;
7. one source cannot amplify itself into consensus through retrieval or multi-Agent repetition;
8. the non-operative L14 contamination decision candidate becomes effective only at one K3 installation transaction that atomically records its reference and fences affected Attempts, contexts, caches, releases, effects/adoptions, NextQuestion, and RSI before asynchronous descendant cleanup; quarantined lineage can then be invalidated, rolled back, and cleanly replayed without treating unknown coverage as empty;
9. context budgets adapt to exact Provider geometry without blind truncation or incompatible cache reuse;
10. Provider changes and crashes resume from Qinao-owned structured state through a new admitted Attempt where required;
11. external-effect ambiguity never causes a blind repeat;
12. initiative is an attenuated projection of existing leases/permits, inspectable, cancellable, and incapable of silently expanding authority;
13. next-question projection is useful, ephemeral, non-manipulative, and non-effectful;
14. RSI improves only through cleaned evidence, shadow/canary proof, independent adoption, the complete K3-stage/L14/K4-issue/reserve/claim/use/claimed-attestation-create-or-reopen/caller-put/K3-seal/activation crash matrix, byte-exact lost-result recovery, canonical proof validation, strict recovery deadline, K3 fence-versus-activation CAS, orphan cleanup, and rollback; no downstream receipt is written backward into its candidate payload;
15. the user can inspect, correct, revoke, roll back, and request erasure of all applicable durable identity, relationship, commitment, and memory state, with exact proof of local deletion/invalidation, ordered reply-channel closure or Artifact-Mesh no-reinsert admission fencing before the final sweep, and honest remote/audit limitations;
16. Qinao does not request or accept raw private reasoning into persistent schemas, Agent communication, telemetry, or evidence;
17. local and API Providers have equal semantic authority limits;
18. local execution remains inside healthy, sustained, exact-SKU Apple Silicon envelopes with one local HeavyPhase owner and accepted-token metrics that speculative/MTP drafts cannot inflate;
19. stable App Agent/profile/Self-head/grant/receipt IDs or digests never enter Provider-visible bytes; scoped pseudonyms and rendered constraints pass privacy/linkability tests;
20. all critical CI and architecture gates are non-vacuous.

## 20. Controlled-Convergence Requirements

After written-spec approval, an implementation plan may describe contingent later waves, but its first executable work is a W0 controlled-document-convergence preflight. No production declaration or production implementation task is runnable until that atomic convergence and its non-vacuous receipts prove all of the following:

1. map Agent Self semantics to the existing L5 authority, freeze the closed Host/Self/relationship conflict lattice, and prevent Host data from being auto-promoted into Self;
2. map genesis `absent | present` lifecycle, winner/loser recovery, private app-governance Artifact/head scope, `rootEvidence` and any external operator/server monotonic continuity owner, key/freshness/restore/reset/erasure paths, and classify any `BASArtifactScopeBinding`/head-scope/continuity change honestly as E/A or blocked M; cross-key/device continuity remains disabled when no existing owner is proven;
3. classify every proposed wire as reuse, E/A extension, or blocked M creation and update the Owner Ledger only through its existing process;
4. decide the minimum wire set rather than creating one type per prose concept, keep downstream activation evidence out of immutable target payloads, and map exactly one existing `runtime.turn-operation`-class reference composer for the transient App Agent composite;
5. map physical storage/version/forget/rollback to existing owners and prohibit parallel stores;
6. map exact profile-resolution, exhaustive present/absent/not-authorized/unavailable relationship state, external-authentication, self-governance-principal grant, and scoped-pseudonym/blinding owners plus issuance/currentness/expiry/revocation/rotation/restoration/recovery; L3 owns no identity secret and every unproven capability remains disabled;
7. bind Recognition and Main/Sub trusted/rendered views to typed sections of the one existing `BASContextCapsule` path and preserve `attemptFrame -> BASCompiledContextDescriptor -> plan -> K3 allocation -> providerStep`;
8. bind experience cleaning/quarantine/promotion to existing L7/L8/L10/L13/L14 paths, make an immutable L14 contamination decision candidate explicitly non-operative, and make one K3/source-currentness transaction the sole point that atomically installs its reference plus eligibility/generation/invalidation/kill fencing; eliminate arbitrary lookup bypasses and test the decision-put/K3-install race;
9. preserve existing Provider, Attempt, budget, possible-start, effect, publication, erasure, and recovery contracts, including same-boot/cross-boot distinctions;
10. extend the existing ΩE/K3 state-commit row/query only as required to freeze the exact K4 grant bytes/issue request/bound subject/use request/`attestationRequestID`/proof-free target-attestation request and close every Stable-Self stage/L14/K4-issue/reserve/claim/use/claimed-attestation-pending-owner/result-commit-or-reply/result-erasure/caller-put/K3-seal/activation crash cut. Reuse the four canonical K4 lifecycle methods and realize one generic claimed-artifact-attestation capability through class-correct members: because `sovereign.k4-durable-lifecycle` is still `approved_missing`, fold its immutable request/semantic keys, exact `signingPending | resultCommitted | resultErased` states, dual uniqueness constraints, bounded encrypted result bytes/digest, owner fence, bounded `recoveryNotAfter`, erasure reason/time, and request/semantic tombstone lifetime no shorter than the irreversible use/grant lineage into the one original W5 M/CreateGate first wire; likewise fold the required proof-free context binding and one canonical/low-S P-256 representation into the original `trust.algorithm-agile-manifest` first wire while that owner remains missing. Put only the incumbent authority/client/XPC call surfaces in same-wave E/A/ExtensionGate slices, each with the exact required `dependsOnCreateTerminalID` and disjoint allowed path; neither classification nor wave order is implementer-selectable. The combined capability must freeze the complete proof-free signed context, fence pending signer ownership/stale completion, commit result bytes before reply, replay committed results without re-signing only when bytes need recovery, and make erased results terminal and non-recreatable without turning K4 outbox state into Self currentness. K3 seal must independently verify the canonical public Artifact, full signed-context/request ancestry, complete local currentness/fences, and strict `now < recoveryNotAfter`; K3 activation independently repeats its complete local currentness/fence/deadline check, and neither transaction may span K4/XPC. Authorized deletion/revocation must install its K3/source-currentness semantic fence before K4 erasure; activation CAS versus that fence CAS defines order and late public puts remain headless inert orphans. Deletion completes only after one exact ordered closure: either every put-capable worker/accepted reply channel is proved quiescent before the final sweep, or an already-owned Artifact Mesh protocol first commits a durable lineage no-reinsert fence atomically checked by every put and then sweeps. Controlled convergence must classify and gate any needed Artifact Mesh extension; if neither path is proved, deletion remains pending/quarantined. Atomically revise the older signature-bytes-only prose as an explicit narrow idempotent-reply-outbox exception, gate every M and E/A member through non-empty manifests/fixtures plus Ed25519/P-256 concurrency/process-death/privacy tests, and create no App-specific API, Artifact payload, receipt, reservation handle, signer, Artifact store, target mirror, commitment-key sharing, boundary-anchor branch, cross-domain transaction, or recovery coordinator;
11. atomically flip the seven documents, ledger terms, checkers, and code to canonical `executeAtMostOnce` semantics and resolve terminal wire spelling drift rather than carrying conflicting names;
12. define the closed legacy Host/Persona migration disposition for every field and fixture without silently changing privacy posture;
13. treat every Qwen/MiniCPM/Granite Core AI route as an unavailable conversion candidate until exact export, function/StateABI, device, quality, recovery, memory, energy, thermal, and Release evidence passes; preserve the incumbent until retirement gates pass;
14. converge the exact `cold40` device/turn cardinality and every accepted-decode timer/denominator definition across architecture, harness, verifier, and claim surface before any named tier is requestable;
15. add non-vacuous tests plus separate current M CreateGate, E/A ExtensionGate, and schema-fixture manifests/proofs before the first production declaration;
16. record exact W-wave ordering so no test or step depends on a later-wave API;
17. prohibit reuse of retiring legacy `BASAgentSpec`, `BASAgentRegistry`, old `BASAgentProposal`, `BASAgentFabricRuntime`, or `QinaoAgentCommitGate` as App Agent authority;
18. preserve the App Agent Self adoption sequence `L13 immutable candidate/read-set -> shadow evidence -> L10 validate -> L11 risk/disclosure revalidate + exact self-governance-principal confirmation -> L13 exact adoption-intent prepare -> K3 invisible stage/frozen K4 request material -> L14 exact adoption decision -> K4 issue/reopen exact grant -> reserve exact tuple -> claim/use -> generic K4 claimed-target-attestation create/reopen -> caller-side ordinary target-attestation put -> K3 state-commit seal -> K3 activate/append`; current host candidate helpers are not silently promoted to final App Agent authority.

This design prefers zero new production authority owners. It permits new governed values only where controlled convergence proves that an existing owner already has the correct semantic and physical responsibility.

The execution order is `spec-only commit -> user review/approval of the written spec -> revised convergence/implementation plan pins the exact spec commit/blob/digest -> atomic controlled-document convergence -> gated implementation waves`. A later byte change to this spec invalidates the plan pin until it is reviewed again.

## 21. Rejected Alternatives

### 21.1 Persona-only App Agent

Rejected because a prompt/persona overlay cannot provide durable identity, causal memory, assurance-scoped relationship continuity, deterministic routing influence, recovery, or governed evolution. It remains useful only as a clamped expression/workstyle projection.

### 21.2 Independent Agent Mind service

Rejected because it duplicates L5, StateLake/memory, L3, K3, RSI, and authorization authority and creates a second mutable brain beside the fourteen-layer system.

### 21.3 Full self copied into all Sub Agents

Rejected because it expands private context, creates identity forks, lets weak specialists impersonate the whole, increases contamination paths, and wastes scarce context/memory.

### 21.4 No App Agent content in Sub Agents

Rejected because value-neutral workers can violate privacy, provenance, uncertainty, or task commitments. Sub Agents receive a purpose-scoped, non-linkable rendered behavioral/constitutional minimum and role slice instead; the trusted local parent retains stable proof.

### 21.5 Direct gradual Main-to-App learning

Rejected because model hallucination, injection, sycophancy, duplicated evidence, or one anomalous session could poison the long-lived self. Gradual influence exists only through cleaned independent evidence and governed adoption.

## 22. Candidate Summary

Qinao's App Agent is the persistent whole, not the current model. A Main Agent is an independent session embodiment that carries every non-omissible identity invariant and expresses the relevant active self without copying the full memory corpus. Sub Agents are independent bounded specialists that express only the necessary constitutional and task slice. The deterministic fourteen-layer/four-kernel/four-ring system carries and protects the App Agent across routing, memory, context, verification, risk, evolution, release, and recovery.

Every Main Agent can claim profile continuity only when Qinao proves the exact profile-resolution path and compiles a scoped Recognition section through the trusted descriptor into the relevant `providerStep` capsule. It can restore or render relationship facts only when that proven profile carries `present(exactRelationshipFacetRef)`; `provedAbsent`, `notAuthorized`, and `unavailableOrQuarantined` remain honest non-facet states. It may claim account/device-principal authentication only when an exact non-rendered principal-binding receipt supports that assurance; it does not claim biological identity. No valid profile projection means `guestOrUnknown` and no claim of recognition.

Main Agents can shape future App Agent behavior only indirectly: they produce untrusted experience observations, which pass lineage sealing, seven-stage cleaning, quarantine, independent evaluation, L13 candidate/read-set, shadow/canary testing, L10/L11 review, L13 adoption-intent prepare, K3 invisible stage with frozen K4 request material, L14 authorization, K4 exact-grant issue/reopen, reserve, claim/use, generic claimed-target-attestation create/reopen, caller-side ordinary target-attestation put, K3 state-commit seal, and K3 activation CAS. No model writes or approves the self it embodies.

That separation preserves the intelligence, knowledge, creativity, and expressive strengths of Qwen, AFM, and future API models while keeping one inspectable, recoverable, model-independent App Agent identity.
