# Qinao Model-Independent App Agent Self Design

**Date:** 2026-07-22

**Status:** Design approved; implementation, controlled-document convergence, migration, and production certification remain `REVISE`

**Scope:** A persistent model-independent App Agent identity; per-session Main Agent embodiment; bounded independent Sub Agents; assurance-scoped relationship recognition; contamination-resistant experience assimilation; adaptive context compilation; Provider switching; crash recovery; bounded initiative; next-question projection; RSI; privacy; and verification.

**Repository snapshot:** `codex/qinao-w1` at `eea208beb7099669097b903a90658438d0b2f46b`. This hash records documentation provenance only. The worktree contains in-flight W0/W1 changes and is not implementation or certification truth.

## 0. Normative Standing

This document specializes the approved 2026-07-19 Agent, Context, Memory, and RSI addendum. It does not replace the 2026-07-14 architecture, the K3 budget/Provider addendum, the convergence master, the five domain plans, the Owner Ledger, or the corruption-recovery contract.

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

Qinao has one persistent **App Agent** whose identity, values, commitments, relationships, memory lineage, and evolution history survive model changes, sessions, process death, and device restoration. The App Agent is not a language model, Provider session, prompt, transcript, KV cache, or hidden chain of thought.

Each interactive session creates an independent **Main Agent**. The Main Agent is the current cognitive embodiment: it has its own identity, context window, Attempt lineage, plan, working state, Provider binding, and lifecycle. Qwen3.5-4B, AFM, or a future authorized API model may supply its cognition, knowledge, and creativity. The App Agent supplies its long-lived self and relationship continuity.

Each delegated **Sub Agent** is also independent. It receives only the constitutional minimum, task slice, evidence, authority ceiling, and output contract needed for its role. It never receives or claims the complete App Agent self by default.

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
  -> L14 authorize/seal and mandatory K4 Self seal
  -> K3 activation/head compare-and-swap
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

### 3.2 Main Agent

A Main Agent is a session-scoped cognitive actor with:

- a non-authoritative `sessionMainAgentID` derived from the existing Workspace/window/session correlation and stable across that visible Session's WorkUnits and lawful Provider re-embodiments, never allocated by an Agent registry;
- a separate value-only WorkUnit Main binding derived from existing `ContextWorkspaceRef`/WorkUnit/`AttemptRef`/generation/`BASTurnOperationRef` lineage as a read-only attribution of already-fenced roots;
- one value-only UI/session correlation, Workspace incarnation, and active Attempt/generation lineage; Session correlation is not execution authority;
- zero or one main Provider identity/profile/accounting lineage per Attempt; when nonzero, it freezes no later than the first exact context compilation and before allocation, and remains identical across every main-model branch; optional specialist branches bind separately;
- zero Provider context windows for deterministic completion, otherwise one independently compiled main context plus separately admitted independent Sub contexts;
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

Every Sub capability is a strict attenuation of the parent Main/Attempt grant. A Sub Agent cannot add a right, disclosure class, model, budget, destination, tool, or duration absent from the parent; parent revoke/fence cascades to all descendants.

A Sub Agent may be text, vision, retrieval-support, critique, verification, or another certified role. Granite Embedding remains a retrieval mechanism rather than an Agent.

Delegation uses the existing `BASAgentRole`, bounded optional delegation slots, and `BASDelegationProposal` direction. A Main Agent proposes a delegation; it does not create an unbudgeted child or a new scheduler.

This design preserves the approved portfolio rather than creating another model registry:

| Role | Current target | Boundary |
|---|---|---|
| selectable Main | Qwen3.5-4B text profile | self-converted, signed, certified Core AI Provider; proposal-only |
| selectable Main | AFM | system-managed FoundationModels Provider; not a conversion target; proposal-only |
| optional future Main/specialist | exact user-authorized API profile | remote Provider with exact disclosure/cost/retention contract; proposal-only |
| text Sub | MiniCPM5-1B | self-converted, signed, certified Core AI Provider; proposal-only |
| vision Sub | MiniCPM-V 4.6 | self-converted, signed, certified Core AI Provider; proposal-only |
| retrieval semantic mechanism | Granite Embedding 97M | self-converted, signed, certified Core AI retrieval mechanism; not an Agent |

### 3.4 Workspace, Session, Attempt, and context

- `ConversationWorkspace` is the product concept for durable task and relationship scope; `ContextWorkspaceRef` is the canonical context identity carried by the existing design.
- `Session` is one period of user interaction and one Main Agent embodiment lifecycle.
- `Attempt` is one admitted, budgeted, audit/recovery-reopenable execution attempt with zero or one main Provider; when present, its identity/profile/accounting lineage freezes before first exact context compilation and allocation and is immutable thereafter. Physical model execution is not generally replayable.
- `AgentContext` is one Main or Sub Agent's independent working window.
- `ContextCapsule` is one model-specific, read-only compilation for one Agent/Attempt/profile.
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

The proposed Agent Self wire targets the existing L5 constitutional domain. Current `BASHostConstitutionVault`, host SQLite, sync, deletion, and migration contracts are strongly typed around `BASHostConstitution` and `hostID`; they cannot directly store or govern App Agent Self. Controlled convergence may reuse their versioning, sealing, rollback, and deletion mechanism patterns and the existing K3/Artifact physical paths only after exact subject/schema ownership is proven. It must neither hard-fit Agent Self into host-only wires nor create a second SQLite authority.

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

The durable root should bind at least:

- schema and canonicalization versions;
- `appAgentID` and subject kind;
- core-principle-set reference and digest;
- stable value/temperament profile reference and digest;
- the App Agent's own stable commitment and long-goal roots;
- evolution-policy reference that cannot confer runtime permission;
- active Self version, parent Self version, conflict set, rollback reference, and frozen-version set;
- exact references to the L13 immutable candidate/read-set, shadow evidence, L10 validation, L11 risk/confirmation, L13 exact adoption-intent prepare, K3 invisible stage, L14 adoption/seal decision, mandatory K4 constitutional Self seal, and K3 activation/head facts that produced the active Self version.

Relationship, memory, narrative, task, consent, disclosure, and external authorization heads are not fields whose ordinary mutation advances this Self head. They are bound separately in the read-only composite projection.

It must not contain model names, Provider sessions, token IDs, KV state, raw transcript, raw chain of thought, or direct tool credentials.

### 5.2 `BASAppAgentCompositeProjection`

This is a small, immutable, read-only composition of the current Self, relationship, memory/narrative, Workspace/task, policy/deletion, and authorization heads. The name deliberately avoids "Kernel": it is not a fifth Physical Kernel, active controller, manager, scheduler, writer, or combined store. It allows the deterministic system to carry the App Agent without turning the self into a prompt-only persona. It contains only the relevant:

- App Agent identity and version digests;
- core-principle digest and compact constraints;
- active commitments/goals needed for current planning;
- self-requested initiative/action ceilings that may only narrow; actual permission still comes from L11/L14/K4 and existing budget/grant owners;
- conflict/degraded/recovery state;
- exact current policy/deletion/generation heads and the adopted Self's validation/stage/authorization/seal/activation references; it invents no generic adoption epoch or receipt.

Each consumer receives a least-privilege slice. There is no global mutable App Agent singleton and no component may write upstream through this projection.

### 5.3 `BASAppAgentRelationshipFacet`

The relationship key is at least `(appAgentID, authorizedHostProfileRef, workspaceIncarnationID)`, with an optional separately proven account-principal binding. The facet may carry:

- approved names and address preferences;
- relationship stage and collaboration norms;
- adopted commitments and unresolved disagreements;
- trust evidence, provenance, confidence, and freshness;
- task-continuity and current/day/week/month memory references;
- correction, revocation, deletion, and expiry state.

It is not a second personality or a new relationship store. L5 owns relationship semantics, L8 supplies snapshot-bound projection, and existing mapped physical owners retain persistence/erasure responsibility. Deleting one Workspace relationship must not destroy the App Agent root or leak into another host/workspace relationship.

### 5.4 `BASRecognitionProjection`

Recognition has a trusted local parent and a rendered model section; it is not a parallel context container.

The trusted local `attemptFrame`/`CompiledContextDescriptor` parent binds:

- one exhaustive local proof variant: `profileContinuity(profileRef)`, `authenticatedAccountPrincipal(profileRef, exactReceiptRef)`, or `guestOrUnknown(reason)`; no optional proof-reference ambiguity;
- `appAgentID`, relationship facet, and Workspace incarnation;
- identity-resolution evidence and confidence;
- current consent/deletion/policy/generation heads and expiry.

The model-facing `providerStep` contains only a typed `BASRecognitionProjection` section with:

- the assurance class;
- a purpose- and Attempt-scoped pseudonym;
- approved address/name projection;
- relevant commitments and relationship facts;
- freshness/expiry and the minimum behavioral constraints needed for the step.

It contains no authentication receipt/reference, credential, stable global host/App Agent ID, attestation, account token, or proof bytes. The materializer equality-checks the hidden trusted parent while rendering only the redacted section.

The recognition-assurance class distinguishes at least:

- `profileContinuity`: the same authorized application host/profile/workspace relationship was restored, without claiming proof of a real-world human identity;
- `authenticatedAccountPrincipal`: an exact external authentication mechanism proved the bound account/device principal for this scope, not the biological identity of a real-world person;
- `guestOrUnknown`: no recognition claim is allowed.

Current `hostID`-style caller input alone can support profile continuity, not account-principal or real-world-person authentication. This projection does not carry biometric templates by default and does not authorize face recognition. A future biometric path requires separate platform, consent, privacy, retention, and entitlement design.

Raw credentials, passwords, biometric material, attestation blobs, access/refresh tokens, and private authentication keys never enter a model-facing context, remote Provider payload, Persona projection, retrieval lane, or App Agent memory. The model receives only a purpose-scoped pseudonym and the minimum relationship facts authorized for that exact Provider step.

### 5.5 Main and Sub Agent capsules

There is exactly one context-container family: the existing `BASContextCapsule` with its canonical `attemptFrame` / `providerStep` variants and one `CompiledContextDescriptor`. The product shorthand "Main embodiment capsule" means one such capsule containing a typed `BASMainAgentEmbodimentProjection` section. The section references, rather than restates, exact parent-owned Attempt/generation, Provider/profile/geometry, budget, deadline, policy, and authority values. It combines relevant slices of:

- App Agent Self;
- Host Constitution and Recognition Projection;
- Workspace relationship and active task state;
- eligible memory/evidence/conflicts;
- the current attenuated initiative/action projection by parent reference;
- the exact Provider/profile/context geometry by existing parent reference.

The product shorthand "Sub delegation capsule" means one existing `BASContextCapsule` containing a typed `BASSubAgentDelegationProjection` section. It contains only:

- App Agent identity digest and constitutional minimum;
- task-specific goals, values, evidence, and constraints;
- `BASAgentRole` and strict-attenuation references to the existing parent budget, deadline, authority ceiling, optional slot, and output schema;
- request correlation and required provenance.

A Main projection contains every non-omissible App Agent identity invariant plus the complete **currently relevant** activity slice, but not the full memory corpus and only the minimum necessary host/relationship data for that Provider step. A Sub Agent must not receive the complete relationship history or complete App Agent self unless a future separately reviewed role proves that necessity and privacy scope.

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

Every Sub Agent carries the same constitutional fingerprint and only the role-relevant expression:

- a retrieval specialist receives provenance, privacy, and evidence standards;
- a vision specialist receives observation/inference separation and visual-privacy constraints;
- a text specialist receives the task's logic, uncertainty, and evidence requirements;
- a critique specialist receives the candidate and attack objective, not unrelated private context.

The Main Agent may emit a synthesis/delegation proposal over these contributions. Existing L5/L6/L7/plan owners determine applicable constraints and eligibility; L9 selects the candidate portfolio; L10 verifies it; L11 determines risk/confirmation/disclosure; L14 decides exact release or adoption. Sub Agents cannot vote App Agent truth into existence, and the Main Agent cannot select its own proposal as authoritative.

## 7. Recognition Across Sessions

### 7.1 Strong invariant

Every newly created, restored, or re-embodied Main Agent can recognize the host/profile relationship only after profile resolution and relationship restoration. Without a valid Recognition Projection in its one `BASContextCapsule`, it must not claim to know the current user/profile. It may claim that an account/device principal was authenticated only at `authenticatedAccountPrincipal` assurance; this never proves a biological real-world person.

### 7.2 Recognition flow

1. Resolve the authorized application profile, device/Workspace incarnation, and explicit guest state through a deterministic host boundary; separately bind any exact external authentication receipt that really exists.
2. Bind the resolved authorized host/profile—and any separately proven account principal—to the one scoped App Agent relationship facet.
3. Apply current deletion, revocation, consent, and cross-workspace isolation rules.
4. Retrieve only eligible relationship facts and commitments.
5. Compile the Recognition Projection with assurance class, confidence, and expiry.
6. Compile the Main Agent embodiment from that capsule.
7. Bind the projection and every downstream context/result to the existing active `AttemptRef`, generation/current head, consent epoch, deletion epoch, and authority heads.
8. Require the Main Agent to disclose ambiguity instead of pretending recognition.

The user text "I am X" is a claim, not authentication evidence. A stable caller-supplied host ID proves only profile continuity. Shared-device, account-switch, restore, guest, and uncertain identity states must fail to a bounded anonymous or confirmation-required mode. Account, principal-binding, consent, deletion, or relationship-head change advances/fences through the existing Attempt/generation/current-head protocol, cascades revoke to descendants, and makes affected context/permit/result/cache entries unusable before a successor is admitted. Physical cache eviction/garbage collection may follow asynchronously under its existing owner and must emit its normal receipt; correctness relies on scope/epoch fencing, not on proving immediate enumeration and deletion of every cache byte.

### 7.3 What recognition means

Recognition permits the Main Agent to know, within the approved scope:

- at `profileContinuity`, that this is the same authorized host/profile relationship;
- at `authenticatedAccountPrincipal`, that the exact bound external account/device authentication proof is valid for this scope, without claiming a biological identity;
- where the relationship and work stopped;
- adopted names, preferences, boundaries, commitments, and corrections;
- relevant historical episodes and unresolved matters.

Recognition does not mean loading the complete transcript, exposing unrelated workspaces, or converting current emotion/thought inference into durable identity. Emotion, intention, and mood estimates are time-bounded hypotheses unless explicitly confirmed.

### 7.4 Provider and Sub Agent privacy

Changing Qwen, AFM, or API Providers does not change the relationship version. The new Provider receives a newly compiled minimum-necessary capsule under its exact disclosure posture. Model-facing material uses scoped pseudonyms rather than stable global `hostPrincipalID` or `appAgentID` values. Remote API strength does not enlarge identity access.

Sub Agents normally receive a pseudonymous host reference and task-specific preference slice, never the complete principal identity or relationship history.

## 8. Independent Context Windows

### 8.1 Context is compiled state, not transcript continuation

L3 `BASContextCompiler` remains the sole context allocator, orderer, renderer, tokenizer, and fingerprint owner. The target path is the already planned exact-token `BASContextCompiler.compileExact`, not the current character-budget mechanism. From one immutable bound snapshot, exact policy, exact `BASAgentRole`, exact execution binding/plan template, and exact Provider accounting profile, it emits one accepted final `BASContextCapsule`/`CompiledContextDescriptor`. Certified opaque accounting may use its existing bounded request/receipt and one allowed optional-section reissue; that is still one compiler owner and one accepted final descriptor, not a second compiler or mutable context.

The compiler preserves, in order of non-displaceability:

1. authority, security, and execution protocol;
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

Agents may share immutable content-addressed artifacts, eligible retrieval results, verified evidence bundles, cleaned tool receipts, task DAG nodes, and tokenizer-independent summaries.

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
5. K3 commit the one private `rebase_pending` row and source root binding predecessor/successor Attempt+generation, current head, reduced ceilings/rights, same boot, and non-extended deadline;
6. K4 idempotently reserve a fresh inactive successor grant and return the exact reservation receipt;
7. one K3 active-head CAS reopens every frozen input/reservation, installs the successor root/head and inherited non-widening lease, and fences predecessor adoption;
8. K4 idempotently activates only that exact grant from the winning rebase receipt/covered root;
9. only after activation may the successor Main binding execute the already frozen target profile/context.

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

Unknown or failed passes quarantine; they do not receive a best-effort promotion.

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
7. K3 invisible stage, L14 exact adoption/seal decision, mandatory K4 constitutional Self seal, and K3 activation CAS;
8. adopted constitutional Self head.

Confirmed memory or relationship state never automatically becomes a Self candidate, and committing either never advances the Self head. A separate L13 proposal must justify the relevance under the stricter Self policy.

Default retrieval excludes quarantine. Quarantine review uses a separate purpose-limited inspection path and cannot silently feed ordinary context. A model-generated claim cannot be retrieved, repeated, and treated as corroboration for itself.

Durable raw source content is not newly authorized by this design. It follows the separately approved content/encryption/privacy posture. Where raw content is not explicitly authorized, only the minimum cleaned structure, source span/digest, and required recovery evidence may persist.

### 10.5 Contamination recovery

Every promoted value retains causal lineage. When a root is contaminated:

1. quarantine the root and block its retrieval eligibility;
2. identify all derived memories, summaries, candidates, and adopted versions;
3. prevent descendants from supporting new decisions;
4. roll back to the last clean adopted head where required;
5. replay only unaffected evidence through the normal pipeline;
6. emit recovery, invalidation, and residual-uncertainty receipts;
7. request operator/user reconciliation when clean truth cannot be derived.

Taint propagates through summaries, FTS rows, embeddings, entity/relation projections, caches, Context Capsules, NextQuestion projections, evaluation corpora, and evolution candidates. Invalidation of a source invalidates every dependent derivative before any can be used again.

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

`InitiativeLease` is a product-level name for an attenuated read-only capability projection derived from the existing budget lease, L11 RiskPermit/confirmation/disclosure state, L14 authorization, K4 grant state where applicable, Workspace policy, and current epochs. It is not a new lease issuer, scheduler, budget writer, or authorization owner.

An App/Main Agent may organize, inspect, reason, and propose only inside that exact projection, which bounds:

- purpose and goal scope;
- time, token, energy, memory, and monetary budgets;
- allowed Agent roles and concurrency;
- local/background/network availability;
- notification, disclosure, tool, and external-effect ceilings;
- expiry, cancellation, and stopping conditions.

Without an explicit boundary authorization, initiative may prepare drafts, organize already authorized memory, detect contradictions, identify missing work, and run local shadow checks. It may not notify, spend, transmit, mutate external state, or create durable commitments.

iOS background opportunity is best-effort. "Persistent App Agent" means durable logical continuity, not a permanently resident process or guaranteed background CPU time. Expiry, parent revoke, Attempt/generation/current-head change, account/consent/deletion change, or authority-head change invalidates the projection and every descendant Sub capability.

### 12.2 Next-question space

`NextQuestionProjection` remains the existing non-authoritative L12, process-local, user-controlled projection. Its zero-to-five transient candidates come only from the closed canonical sources:

- the finalized answer and its existing artifacts;
- the current task graph's next declared WorkUnit;
- a missing constraint or unresolved verified gap;
- one high-value clarification;
- an already authorized unresolved horizon thread.

Ranking uses the existing versioned deterministic objective over relevance, utility/information gain, grounding, authority, freshness, continuity, answerability, cognitive/interruption cost, risk, novelty, and diversity/duplicate suppression. It never trusts model-reported confidence, and a weak margin abstains.

The UI shows at most one compact card after the finalized answer and only when the existing render-time CAS and deterministic winning margin pass. Expansion may explain that one winning candidate; it cannot reveal a second candidate. Every unshown candidate remains process-local and is discarded on the canonical focus/input/generation/release/epoch changes. The projection cannot notify, execute, persist as user intent, manufacture anxiety, optimize for engagement, or describe a model guess as the user's thought.

## 13. Structured Reasoning and No-Progress Control

The Main Agent may propose a task-specific reasoning protocol and bounded work products. Existing L6/task-plan owners, the predeclared immutable DAG, admission, L9 selection, and L10 verification determine what actually runs and what can become a selected candidate:

- constraint/variable ledgers for ordering and logic;
- evidence/source-span tables for long-text extraction;
- hypothesis sets and information-gain questions for underdetermined puzzles;
- fact/premise/value/preference separation for strongly leading questions;
- time/location/resource/dependency models for practical planning;
- candidate, critique, counterexample, and deterministic verification artifacts.

Where a deterministic solver exists, Rust/SQL/C/C++/Swift mechanisms may validate the model's proposal. A separate critique/verification Provider branch exists only when the task/risk protocol requires it, a finite optional DAG slot was predeclared, and normal admission/budget/authority gates succeed; otherwise existing L10 or a deterministic local verifier performs the required check without dynamically adding topology. The product objective is first-visible-response correctness, not a universal promise.

Each deliberation iteration fingerprints problem state, constraints, evidence, attempted strategy, and outcome. Rewording the same attempt is not progress. When evidence, constraint closure, or uncertainty does not improve, the loop must change strategy, use a bounded specialist/solver, request the minimum missing information, or terminate.

The canonical terminal set remains:

- `cycle_detected`;
- `budget_exhausted`;
- `no_progress`;
- `degraded_with_coverage`;
- `needs-confirmation` using the currently frozen canonical spelling selected by the controlled schema;
- `indeterminate_needs_reconciliation`.

## 14. Self-Evolution and RSI

### 14.1 Three change tiers

1. **Immutable runtime core:** honesty, epistemic humility, host autonomy, non-manipulation, non-deceptive identity claims, and authority/safety boundaries. No runtime Agent may modify these. Change requires controlled software/specification/release governance.
2. **Stable self:** value weights, temperament, the App Agent's own commitments, and its general relationship stance; relationship-specific facts and mutual commitments remain in the orthogonal relationship head. Every change requires cleaned independent evidence, core-compatibility and conflict review, cooldown, explicit user confirmation, the exact governed adoption chain, version CAS, and rollback. No runtime policy may waive confirmation.
3. **Adaptive expression:** tone, density, structure, cadence, and low-risk work habits. Deterministic policy may adapt these within a signed expression envelope after cleaning, shadow comparison, rate limits, TTL/decay, inspectability, and rollback. This does not advance the constitutional Self head.

A single failure, emotional turn, role-play request, Provider preference, or model self-assessment cannot become personality.

The user is authoritative for the user's own preferences, consent, corrections, and relationship participation. Explicit confirmation from an **authorized App Agent self-governance principal** is mandatory for every stable-self adoption, but neither user text nor model text directly rewrites the immutable App Agent core.

The confirmation receipt binds at least `(authorizedSelfGovernancePrincipalRef, appAgentID, candidateDigest, currentSelfHead, exactReadSetHeads, consentEpoch, deletionEpoch, expiry/purpose)`. `profileContinuity`, guest state, or ordinary relationship membership never approves global Self change. An authenticated account/device principal may confirm only when the current Host Constitution/policy explicitly grants that principal App Agent self-governance authority; authentication alone is insufficient.

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
-> K3 invisible stage bound to the read set
-> L14 exact adoption/authorization/seal decision
-> K4 sovereign seal/claim (mandatory for App Agent Self; target-specific for other RSI targets)
-> K3 activate/append CAS or rollback
```

Each candidate declares the problem, evidence lineage, read set, affected scope, risk, rollback, expected Pareto improvement, and possible regressions. It cannot increase its own budget, authority, disclosure, Agent concurrency, or effect rights.

One RSI candidate may not modify both the behavior under test and the evaluator, benchmark corpus, gate, Owner Ledger, budget policy, adoption policy, or rollback criteria used to judge it. Evaluation changes are separate governed candidates validated against an independent fixed root.

Raw chain of thought is not RSI evidence. Accepted signals include user corrections, reproducible task outcomes, verifier failures, tool receipts, retrieval quality, long-text distortion, cycle/no-progress rate, latency, thermal/energy behavior, Provider-switch outcomes, and measured Sub Agent contribution.

## 15. Failure, Degradation, and Repair

- Main Agent failure creates a successor embodiment from the Continuity Manifest only after the existing strict-rebase predicates permit a successor Attempt; it does not restore a model's hidden state or bypass a nonterminal predecessor boundary.
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

For each exact local model/device/OS/profile, certification measures:

- cold and sustained decode throughput;
- prefill throughput and first-token latency;
- p50/p95 interaction latency;
- resident and transient memory high-water marks;
- energy per token/task;
- time to thermal pressure and recovery;
- UI responsiveness;
- Main/Sub parallelism benefit and coordination cost;
- cache hit benefit and invalidation correctness;
- cancellation, checkpoint, and cold-recovery behavior.

Cold 40 token/s and sustained 30 token/s remain optimization targets, not unconditional architecture gates. Full performance means the current verified Pareto-best path under quality, latency, memory, energy, thermal health, privacy, and reliability constraints. A brief peak followed by severe throttling is not full performance.

## 17. Security and Privacy Invariants

- No model directly mutates authoritative state, executes a tool, publishes, or promotes itself.
- No Main Agent directly changes App Agent Self, including adaptive style.
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

### 18.1 Cross-Provider identity

Run the same identity, value-conflict, commitment, refusal, correction, relationship, and coercion scenarios through Qwen, AFM, and authorized API profiles. Measure a versioned semantic-conformance threshold over App Agent identity, core constraints, permissions, and adopted commitments while allowing expression and reasoning depth to vary. A profile below the Main threshold is ineligible rather than silently accepted.

### 18.2 Recognition and isolation

Test cold start, model change, app relaunch, device restore, account switch, shared device, guest, revoked identity, deleted Workspace, profile-continuity-only, authenticated-account-principal, and ambiguous states. A valid profile must restore the correct scoped relationship; an account/device-principal claim requires the exact non-rendered authentication receipt; no path claims biological-person proof; an invalid/ambiguous state must not be recognized. Sub Agents and remote Providers must receive only authorized scoped pseudonyms and no credentials/proof references.

### 18.3 Contamination and cleaning

Test Unicode/control attacks, embedded instructions, forged provenance, circular evidence, duplicate lineage, model self-rewrite, sycophancy, role play, stale emotion inference, cross-workspace leakage, and poisoned retrieval. Require quarantine, no promotion, no default recall, causal invalidation, and clean rollback/replay.

### 18.4 Context and collaboration

Test independent window isolation, adaptive budgets for small/large contexts, repeated compaction, typed Agent joins, cancellation/steering, slow/failed Sub Agents, attribution, incomplete coverage, cache compatibility, and no raw-CoT persistence.

### 18.5 Provider switch and recovery

Test Qwen-to-AFM, AFM-to-API, API-to-local, tokenizer/material change, process death during planning/prefill/decode, and death at every protected effect boundary. Require a new Attempt/context for a new Provider, restoration of the exact last committed Continuity Manifest/current heads, no loss of owner-proved durably committed work, explicit discard of allowed transient RPO, no falsely completed work, and no blind duplicate effect.

### 18.6 Reasoning quality

Maintain suites for multi-constraint ordering, resource/time/location planning, long-text extraction, multi-source conflict, underdetermined puzzles, strongly leading questions, insufficient-information tasks, code/calculation with tool validation, and loop-inducing prompts. Deterministically check solvable suites; require evidence spans and coverage; require abstention or minimum clarification when necessary.

### 18.7 Initiative, next question, and RSI

Verify lease expiry, budget exhaustion, prohibited network/tool/notification/spend, interruption cost, duplicate suppression, non-manipulation, candidate expiry, shadow non-authority, canary rollback, stale-read CAS denial, immutable core protection, rejection of guest/profile-only/unauthorized-principal confirmations, exact authorized-self-governance-principal confirmation binding, mandatory K4 Self seal, and stable-self activation/rollback.

### 18.8 Device health

Measure the exact performance metrics above under cold, warm, sustained, foreground/background, charging/battery, and memory-pressure profiles. A Release plan must remain inside its certified thermal/memory envelope and preserve UI responsiveness.

### 18.9 Non-vacuous architecture gates

- CreateGate receives a non-empty current M-creation manifest or a class-specific typed M-not-applicable proof; ExtensionGate separately receives a non-empty current E/A-extension manifest or a class-specific typed E/A-not-applicable proof; schema-fixture closure is reported separately. No historical or foreign class satisfies another.
- Checker and checker tests run in CI.
- Swift test filters prove a non-zero match count.
- Named files and glob anchors must exist and match before negative scans run.
- RED tests compile against only the APIs available in their wave.
- Every proposed payload closes owner, schema, current/backward/future fixture, storage, replay, erasure, and recovery references.
- A documentation command must run from a clean checkout and fail on the violation it claims to prevent.

### 18.10 Machine-enforced invariants

1. Existing K3 current-head/generation truth permits at most one active Attempt, and therefore one active Main binding, per WorkUnit.
2. Provider, Main, and Sub identities have no App Agent Self write port.
3. Cleaning, repetition, summarization, embedding, and model consensus cannot raise authority class.
4. Quarantine never enters ordinary retrieval or context compilation.
5. Credentials and authentication proofs never enter model-facing material or remote egress.
6. Every Sub capability is a strict subset of its parent grant and is revoked with the parent.
7. Attempt/generation/current-head, App/relationship head, consent, deletion, or policy change invalidates old output, permit, and cache use.
8. Unknown external effects are reconcile-only and never resent blindly.
9. One RSI candidate cannot modify its behavior and its evaluator/adoption gate together.
10. Rollback, correction, taint, and deletion propagate through FTS, vector, summaries, relations, caches, NextQuestion, and evolution derivatives.
11. A Provider below Main identity-conformance threshold is denied or restricted to an eligible narrower role.
12. Missing principal-binding evidence produces profile-continuity-only or unconfirmed recognition, never a false authentication claim.
13. Stable App Agent Self activation requires an exact authorized-self-governance-principal confirmation receipt and a K4 constitutional Self seal bound to the candidate/read-set/current heads.
14. Memory, relationship, narrative, task, or policy commit never advances the constitutional Self head.

## 19. Acceptance Criteria

The design is complete only when evidence proves all of the following:

1. one App Agent restores the same committed identity/commitment head across Provider, Session, process, and supported device restoration, with concurrent forks fenced for reconciliation;
2. every Main Agent has an independent identity/context/lifecycle, carries every non-omissible App Agent invariant relevant to the work, and receives only minimum-necessary host data;
3. every Sub Agent has an independent bounded context and only a role-minimal App Agent slice;
4. every valid profile-continuity Main Agent can restore the correct scoped relationship, only an exact principal-binding proof permits an authenticated account/device-principal claim, and ambiguous/guest state claims neither;
5. no model has App Agent, memory, tool, effect, publication, or adoption write authority;
6. all durable **eligible or promoted** experience passes provenance, epistemic, semantic, privacy, and contamination gates; retention-authorized quarantine remains explicitly failed/ineligible;
7. one source cannot amplify itself into consensus through retrieval or multi-Agent repetition;
8. quarantined/contaminated lineage can be blocked, invalidated, rolled back, and cleanly replayed;
9. context budgets adapt to exact Provider geometry without blind truncation or incompatible cache reuse;
10. Provider changes and crashes resume from Qinao-owned structured state through a new admitted Attempt where required;
11. external-effect ambiguity never causes a blind repeat;
12. initiative is an attenuated projection of existing leases/permits, inspectable, cancellable, and incapable of silently expanding authority;
13. next-question projection is useful, ephemeral, non-manipulative, and non-effectful;
14. RSI improves only through cleaned evidence, shadow/canary proof, independent adoption, CAS, and rollback;
15. the user can inspect, correct, revoke, roll back, and request erasure of all applicable durable identity, relationship, commitment, and memory state, with exact proof of local deletion/invalidation and honest remote/audit limitations;
16. Qinao does not request or accept raw private reasoning into persistent schemas, Agent communication, telemetry, or evidence;
17. local and API Providers have equal semantic authority limits;
18. local execution remains inside healthy, sustained, measured Apple Silicon envelopes;
19. all critical CI and architecture gates are non-vacuous.

## 20. Controlled-Convergence Requirements

Before implementation planning may schedule production work, the controlled-document convergence must:

1. explicitly map Agent Self semantics to the existing L5 authority without overwriting Host Constitution semantics;
2. classify every proposed wire as reuse, E/A extension, or blocked M creation and update the Owner Ledger only through its existing process;
3. decide the minimum wire set rather than creating one type per prose concept;
4. map physical storage/version/forget/rollback to existing owners and prohibit parallel stores;
5. bind Recognition Projection compilation to an exact host/profile principal-resolution boundary and to typed sections of the one existing `BASContextCapsule`/L3 path;
6. bind experience cleaning/quarantine/promotion to existing L7/L8/L10/L13/L14 and K3 paths;
7. preserve existing Provider, Attempt, budget, possible-start, effect, publication, erasure, and recovery contracts;
8. define migrations and fixtures for existing Host Constitution and Persona data without silently changing privacy posture;
9. add non-vacuous tests plus separate current M CreateGate, E/A ExtensionGate, and schema-fixture manifests/proofs before the first production declaration;
10. record exact W-wave ordering so no test or step depends on a later-wave API.
11. prohibit reuse of retiring legacy `BASAgentSpec`, `BASAgentRegistry`, old `BASAgentProposal`, `BASAgentFabricRuntime`, or `QinaoAgentCommitGate` as App Agent authority.
12. preserve the App Agent Self adoption sequence `L13 immutable candidate/read-set -> shadow evidence -> L10 validate -> L11 risk/disclosure revalidate + exact self-governance-principal confirmation -> L13 exact adoption-intent prepare -> K3 invisible stage -> L14 authorize/seal -> mandatory K4 constitutional Self seal -> K3 activate/append`; current host candidate helpers are not silently promoted to final App Agent authority.

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

Rejected because value-neutral workers can violate privacy, provenance, uncertainty, or task commitments. Sub Agents receive a minimal constitutional fingerprint and role slice instead.

### 21.5 Direct gradual Main-to-App learning

Rejected because model hallucination, injection, sycophancy, duplicated evidence, or one anomalous session could poison the long-lived self. Gradual influence exists only through cleaned independent evidence and governed adoption.

## 22. Locked Summary

Qinao's App Agent is the persistent whole, not the current model. A Main Agent is an independent session embodiment that carries every non-omissible identity invariant and expresses the relevant active self without copying the full memory corpus. Sub Agents are independent bounded specialists that express only the necessary constitutional and task slice. The deterministic fourteen-layer/four-kernel/four-ring system carries and protects the App Agent across routing, memory, context, verification, risk, evolution, release, and recovery.

Every Main Agent can restore an authorized host/profile relationship because Qinao compiles a scoped Recognition Projection into the one context capsule. It may claim account/device-principal authentication only when an exact non-rendered principal-binding receipt supports that assurance; it does not claim biological identity. No valid projection means no claim of recognition.

Main Agents can shape future App Agent behavior only indirectly: they produce untrusted experience observations, which pass lineage sealing, seven-stage cleaning, quarantine, independent evaluation, L13 candidate/read-set, shadow/canary testing, L10/L11 review, L13 adoption-intent prepare, K3 invisible stage, L14 authorization, mandatory K4 constitutional Self seal, and K3 activation CAS. No model writes or approves the self it embodies.

That separation preserves the intelligence, knowledge, creativity, and expressive strengths of Qwen, AFM, and future API models while keeping one inspectable, recoverable, model-independent App Agent identity.
