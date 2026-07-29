# Qinao Dual-Space Automation, Apple Ecosystem, and Governed Interaction Intelligence Design

**Date:** 2026-07-29

**Status:** Product and architecture decisions approved section by section. This written record, controlled-document convergence, implementation, migration, entitlement proof, device validation, certification, and production cutover remain `REVISE`.

**Scope:** A user-facing Work Space and modular Automation Space; governed AI-authored skills and scheduled work; fine-grained interaction evidence; a deletion-aware minimum 72-hour eligible-learning window; model- and user-adaptive analytics; App Agent/Main/Sub Agent collaboration; Apple ecosystem integration; crash and session recovery; exact placement in the existing fourteen Semantic LayerCores, four Physical Kernels, four bounded ControlRings, and seven orthogonal planes.

**Repository snapshot:** `codex/qinao-w1` at `d367073460f158606955d75f203411f357bc4c34`. The hash records the clean committed base used for this design record. The separate W1 worktree contains in-flight changes and is not modified or treated as implementation or certification truth.

## 0. Normative Standing

This document specializes but does not replace:

1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`;
2. `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`;
3. `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`;
4. `docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md`;
5. `docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`;
6. `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`;
7. the 2026-07-15 convergence master and its Contracts, Silicon, Runtime, Semantic, and Sovereign domain plans;
8. `docs/superpowers/specs/qinao-owner-ledger-v1.json`.

This is one non-competing design record, not an eighth controlled authority document and not an implementation plan. A sentence here cannot create a production owner, writer, store, scheduler, registry, manager, compiler, gateway, agent identity, semantic layer, Physical Kernel, ControlRing, top-level plane, executable schema, entitlement, or certification claim.

Before implementation, every adopted invariant, value contract, lifecycle, code disposition, test, and gate in this document MUST be reconciled atomically into the existing seven controlled documents and the Owner Ledger through the applicable ExtensionGate or CreateGate. If the existing owner set cannot honestly absorb a proposed responsibility, the capability remains disabled until a separately reviewed architecture decision changes the controlled set.

The exact architecture cardinalities remain:

- fourteen Semantic LayerCores, `L1...L14`;
- four Physical Kernels, `K1...K4`;
- four bounded ControlRings, Omega Resource, Omega Grounding, Omega Deliberation, and Omega Effect/Evolution;
- seven orthogonal top-level planes.

The deployment floor remains iOS 27 for every selected app, package, extension, generated binary, XCFramework slice, and Release-closure Mach-O. API availability is not capability proof. Each framework, entitlement, extension process, model path, converter, custom operation, and cross-device flow requires exact build, signing, install, lifecycle, fault, and device evidence.

### 0.1 Requirement language

`MUST`, `MUST NOT`, `SHOULD`, and `MAY` are normative within this approved design record. A design-candidate label describes required semantics only. It is not permission to add a type with the same name.

### 0.2 User-approved retention decision

For ordinary data that is explicitly consented, eligible for learning, and not secret or high sensitivity, Qinao adopts a minimum encrypted retention window of 72 hours.

That minimum is subordinate to four immediate overrides:

1. the user requests deletion;
2. the user withdraws the applicable consent;
3. secret detection identifies a credential, key, token, one-time code, or equivalent material;
4. a privacy or security reclassification requires quarantine, key revocation, or early purge.

The 72-hour window does not itself authorize learning, export, durable memory, cross-Agent sharing, Provider disclosure, or retention beyond the applicable maximum. Expiry of the window does not automatically train a model. It triggers a governed disposition.

### 0.3 Chosen architectural approach

The approved approach is:

- one Qinao authority system;
- two user-facing Space projections;
- one model-independent execution and state path;
- Apple system surfaces as thin adapters;
- no second automation subsystem.

The rejected alternatives are:

- a peer Automation database, scheduler, execution engine, or learning authority;
- Apple Shortcuts or CloudKit as Qinao's control plane;
- model- or App-Agent-owned state mutation;
- ambient collection of every OS interaction;
- dynamically downloaded executable code as an AI-authored iOS skill.

### 0.4 Requirement trace

| Approved requirement | Owning section |
|---|---|
| One Work Space and one modular Automation Space | Sections 1 and 3 |
| Workspace Agent can safely inspect all user-owned Automation scopes | Section 3.4 |
| AI creates skills and time/event-triggered tasks | Section 4 |
| Fine-grained, normalized user interaction evidence | Section 5 |
| Minimum 72-hour eligible-learning window with immediate overrides | Sections 0.2 and 6 |
| Closed-loop analytics that adapt to both model and user | Section 7 |
| Persistent App Agent with one Main per Session and isolated Sub Agents | Section 8 |
| Multiple independent context windows and interruption recovery | Section 9 |
| Maximum lawful Apple ecosystem integration | Section 10 |
| Exact fourteen-layer fit, four kernels, four rings, and seven planes | Section 11 |
| Dynamic graph, RSI, swarm, recovery, effects, and learning use existing owners | Sections 8, 9, 11, and 14 |
| Möbius-style full-loop cooperation with causal trace and bounded remand | Section 1.1 |
| No duplicate wheel and one controlled implementation authority | Sections 14-16 |

## 1. Executive Decision

Qinao presents two clear product spaces over one governed substrate:

1. **Work Space** is the human-facing project, task, relationship, document, and interactive-session view.
2. **Automation Space** is the modular view of approved automation definitions, skill versions, triggers, permissions, runs, checkpoints, outcomes, and learning controls.

These Spaces are not peer stores or peer authorities. Both are projections over the same Workspace-bound Task Graph, K3 EventLog and state nucleus, Artifact Mesh, capability and risk decisions, effect receipts, and replay evidence.

The common reasoning front half is:

```text
Apple / UI / API Input
→ Input Normalizer
→ L14 admission preflight
→ L6 situation and intent
→ L7 state requirements and hard eligibility
→ L8 snapshot-bound retrieval
→ L7 State Market and conflict/coverage closure
→ L3 exact context compilation
→ L2/K2 Provider execution
→ L9 candidate selection
```

The selected candidate then enters exactly one already governed branch:

```text
Response/publication:
  L12 exact spool
  → L10 exact-output verification
  → L11 risk/disclosure/confirmation
  → L14 release authorization
  → L12 release preparation
  → canonical K3/K4/publication-journal/sink protocol

Runtime-state adoption without an external effect:
  L10 verification
  → L11 revalidation
  → L13 exact prepare/read-set
  → K3 invisible stage
  → L14 exact terminal authorization/seal
  → K4 exact seal/use
  → K3 activation or append

External effect:
  L10 verification
  → L11 risk/confirmation
  → L13 exact effect prepare
  → K3 EventLog/outbox prepare
  → L14 exact effect authorization
  → K4 issue/reserve
  → canonical K3/K4/Zone-C boundary protocol and external observation
  → L13 receipt interpretation + StateCommitIntent
  → K3 invisible stage
  → L14 terminal seal
  → K4 terminal signature
  → K3 activation or append

Non-runtime skill/prompt/schema/code/model/policy candidate:
  immutable inert evidence reference
  → runtime.certification
  → production.cutover canary/release/rollback
```

Receipts and projections are emitted by their mapped owners. Learning eligibility consumes those authoritative source events and receipts afterward; it is never another branch shortcut.

Automation work uses the same chain. Off-turn execution changes the trigger and continuation policy, not the authority model.

### 1.1 Möbius-style closed-loop doctrine

“Möbius” describes continuity of evidence across the whole system, not a new plane, owner, infinite reasoning loop, or shortcut across component boundaries:

```text
Input
→ governed state/context
→ plan and execution
→ verification and bounded release/effect
→ outcome observation and reconciliation
→ immutable causal trace
→ learning/evolution candidate
→ certification and separately authorized adoption
→ changed state for a future Input
```

The outside product experience and inside learning/evolution path therefore meet on one provenance-preserving trace, while every transition still crosses its exact semantic, kernel, risk, authorization, commit, and effect boundary. ControlRings may remand only from receipts, with finite branch/time/token/effect budgets and a terminal stop reason. A loop cannot certify its own evidence, replenish its own budget, erase its failed attempts, or turn an observation into authority.

## 2. Repository Reality and Required Dispositions

This design separates current code, approved-planned targets, and new design-candidate semantics.

| Area | Repository reality at the recorded snapshot | Design disposition |
|---|---|---|
| Work Space | `ConversationWorkspace`, `ContextWorkspaceRef`, Workspace-bound continuity, and Session projection semantics exist in the specializing designs; legacy host DTOs remain narrower | Reuse and converge the canonical Workspace identity; do not promote legacy prompt/workflow DTOs into a new authority |
| Automation Space | No first-class `AutomationSpace` production authority exists; trigger, schedule, skill, Attempt, receipt, checkpoint, and recovery semantics are distributed across existing owners | Add a derived product projection and, only if required, one low-entropy routing reference under an existing owner; no store, writer, or scheduler |
| Event evidence | `BASEventLogEntry`/`BASEventLogStorage` cover user, session, tool, audit, and internal events; raw input is represented by digest rather than raw text | Extend the one K3/EventLog path with purpose-, scope-, retention-, learnability-, and lineage-bound fields through controlled convergence |
| Event retention | `BASEventLogRetentionPolicy` expresses maximum-age pruning and has 24-hour and 7-day presets; it does not express a deletion-aware minimum window | Strangle maximum-age-only semantics into purpose-bound minimum/maximum disposition; never reinterpret `maxAgeSec` as a minimum |
| Raw content | Event-sourced memory persists content digests while raw content is cache-like; the governed-learning durable-content decision gate remains unsigned | Keep durable content materialization disabled until the operator/security decision and encryption/erasure closure pass; this product decision alone is insufficient |
| Learning | Governed learning design defines evidence envelopes, cleaning, datasets, evaluation, and rollback but remains unimplemented and non-authoritative | Reuse its pipeline; this design adds no `LearningStore`, training pool, exporter transport, or promotion mouth |
| Skill agents | `BASSkillCapability`, bounded skill descriptors, domain constraints, and proposal-only agent concepts exist | Extend under their owners; AI-authored skills are immutable declarative artifacts and proposals, never direct executable authority |
| Task and recovery | Workflow/checkpoint primitives exist; the dynamic semantic Task Graph and complete interruption protocol remain approved-planned | Use the existing `runtime.semantic-dag`/executor path when its wave passes; do not add an Automation workflow engine |
| Apple background | `AppleBGTaskSchedulerBridge` exists for opportunistic refresh/processing and also contains continued-processing support; foreground after-turn remains the primary consolidation path, while the continued-processing source still carries an inaccurate “GUARANTEED-start” comment | Reuse refresh/processing as wake adapters only; isolate continued processing to foreground user-initiated work; correct/freeze the guarantee doctrine; no correctness, exact-time, schedule, or keepalive claim |
| Apple system surfaces | No active App Intents, App Shortcuts, Spotlight, WidgetKit, Controls, ActivityKit, UserNotifications, CloudKit, WatchConnectivity, HealthKit, EventKit, or HomeKit production integration is proven | Add thin adapters in staged waves after exact target/entitlement evidence; current capability remains `missing` or `approved-missing` |
| Apple effects | Production effect execution is fail-closed until the W5 broker and durable effect protocol exist | Read/open/capture-draft surfaces may precede W5; all real external writes remain disabled |
| Cross-device sync | No governed CloudKit replication protocol exists | Treat CloudKit as optional transport/replica only after identity, conflict, deletion-epoch, and recovery protocols pass |
| Analytics | Existing event, metrics, FTS, vector, temporal, and replay mechanisms exist under multiple current owners and convergence paths | Build rebuildable projections; no AnalyticsDB, behavior truth store, or telemetry-to-learning bypass |

### 2.1 Design-candidate labels

The following names are explanatory labels, not declarations:

- `AutomationSpaceProjection`;
- `AutomationDefinition`;
- `AutomationDefinitionVersion`;
- `AutomationTriggerEvent`;
- `AutomationRunProjection`;
- `AuthorizedAutomationInspection`;
- `InteractionExperienceEnvelope`;
- `ModelRuntimeProfileProjection`;
- `UserExperienceProfileProjection`;
- `RetentionDisposition`;
- `AppleSurfaceIngressAdapter`;
- `AppleReadGateway`;
- `ZoneCAppleEffectExecutor`.

Controlled convergence MAY choose different symbols. Every adopted value requires a mapped owner, bounded wire, fixture, validation, recovery, and compatibility disposition.

## 3. Space Identity and Authority Boundaries

### 3.1 Work Space

Work Space reuses the canonical Workspace and context identities. It presents:

- projects, missions, objectives, WorkUnits, documents, and solution artifacts;
- one selected App Agent per interactive Session;
- one logical Main Agent per Session;
- bounded Sub Agent delegations;
- active, warm, and cold context-window projections;
- current, daily, weekly, and monthly memory views;
- user-visible task continuity, checkpoints, and outcomes.

The current/day/week/month views are rebuildable projections over authoritative events and artifacts. They are not four memory stores.

A Session is a UI and continuity projection over a Workspace. Closing a Session does not cancel or erase a durable WorkUnit unless an authorized cancellation event says so.

### 3.2 Automation Space

Automation Space presents:

- immutable automation definitions and the one active version reference;
- skill candidates, approved versions, tests, and provenance;
- time, event, state, Apple-surface, and future API triggers;
- model, tool, data, disclosure, and effect requirements;
- next eligible run, current runs, waiting states, checkpoints, and recovery;
- outcome, effect, publication, and reconciliation receipts;
- data purpose, retention, deletion, revocation, and learning status;
- modular UI views and user layout preferences.

Automation Space MUST be completely rebuildable from existing K3/EventLog, Artifact Mesh, Task Graph, policy, and receipt authorities. It owns no mutable truth.

The product has one top-level Automation Space. It may contain user-defined modules, collections, and multiple logical Automation scopes across the user's Workspaces. Those views do not become peer authorities or separate stores.

There is no production `AutomationManager`, `AutomationStore`, `AutomationScheduler`, `AutomationEventLog`, `SkillRegistry`, `RunRegistry`, `AutomationAgent`, or Automation-specific WAL.

### 3.3 Automation ownership modes

Every automation version binds exactly one explicit ownership mode:

1. `host-neutral`: it may use only Host-neutral and exact Workspace-authorized data; it cannot read any App Agent private Self or relationship memory.
2. `app-agent-bound`: it binds one exact App Agent scope/root and cannot follow whichever App Agent happens to be selected later.
3. `explicit-share`: it consumes an immutable, purpose-limited, provenance-preserving share artifact and cannot mutate or silently declassify its source.

An automation may not infer identity from the currently visible Session, UI tab, last-used Provider, or ambient singleton.

### 3.4 Workspace Agent meaning

“Workspace Agent” is a product-role projection of the selected App Agent working through the current Main Agent. It is not a new durable Agent class, mutable Self, scheduler, or authority.

The Workspace Agent may list the safe Host-level summary of every Automation scope the user owns, including scopes outside the currently visible Work Space. Opening details then requires an exact per-scope read decision. Host-wide discoverability never reveals another App Agent's private fields or grants execution rights.

The Workspace Agent may inspect Automation Space only through an attenuated read capability that binds:

- caller Agent and selected App Agent scope;
- source Workspace and Automation reference;
- purpose and destination;
- field/redaction mask;
- row, byte, token, and time budget;
- capability, policy, consent, deletion, revocation, and share epochs;
- snapshot watermark and expiry.

Its default inspection vocabulary is closed:

- list;
- get safe summary;
- get status;
- get minimized receipts;
- explain failure.

It does not include run, retry, cancel, pause, edit, delete, grant, share, or export. Any such user request becomes a fresh normalized Input Event and follows ordinary admission.

### 3.5 Read membrane

Known Artifact identity, shared database placement, co-location, or possession of an index hit does not confer read authority.

All Agent-facing reads pass through the one generic caller-aware Artifact/state read membrane. The consumer receives a bounded projection, never a retained raw-store port. The membrane performs currentness checks before and after materialization and rejects stale epochs, wrong callers, wrong destinations, unauthorized fields, exhausted budgets, and re-share laundering.

## 4. Automation Definition and Skill Lifecycle

### 4.1 Immutable definition version

Each automation version binds at least:

- stable automation identity and immutable version identity;
- ownership mode and Workspace binding;
- declared purpose;
- typed trigger specification;
- typed input and output schemas;
- Workflow/Task Graph template reference;
- skill, tool, model-capability, and Provider-profile requirements;
- data sources, scopes, field masks, and sensitivity ceilings;
- effect, disclosure, and confirmation requirements;
- latency, token, memory, energy, network, and monetary budgets;
- overlap, missed-run, retry, reconciliation, and recovery policies;
- continuation policy and user-presence requirements;
- output delivery and notification policy;
- retention, learning, deletion, consent, and revocation bindings;
- immutable content, schema, test, and policy digests.

K3 owns only the mapped active-version CAS and run lifecycle rows under its existing owner. Artifact Mesh stores immutable definition bodies and evidence. The projection does not maintain a mutable catalog.

### 4.2 Definition and operational state machines

These lifecycles apply only to an Automation Definition that controlled convergence honestly maps to an existing runtime-state target. They do not deploy a new skill, prompt package, schema, executable, model, or policy.

The immutable definition-version lifecycle is:

```text
draft → candidate
candidate → validating | rejected | quarantined
validating → shadow | rejected | quarantined
shadow → awaitingApproval | rejected | quarantined
awaitingApproval → approved | rejected | quarantined
approved → superseded | quarantined | retiring
superseded | rejected | quarantined → retiring
retiring → retired
```

`retired` is terminal. Definition bytes are immutable in every state: remediation always creates a new `draft` with a new version identity; it never moves a rejected, quarantined, superseded, retiring, or retired version backward.

An approved immutable version is not intrinsically “active.” A separate mapped K3 active-version CAS selects at most one approved version for the Automation identity.

Operational scheduling state is separate:

```text
disabled → enabled
enabled ↔ paused
disabled | enabled | paused → quarantined | retiring
quarantined → retiring
retiring → retired
```

Pause and resume are exact CAS operations over the same still-approved active version and current policy, permission, consent, deletion, and revocation epochs. Resume requires a fresh normalized Input Event, revalidation, authorization, and receipt; it never mutates the immutable definition or revives an invalid version. Recovery from quarantine requires a new approved version and a new activation decision, not `quarantined → paused`.

The active-reference invariant is atomic and admission-visible: if the selected version becomes `superseded`, `quarantined`, `retiring`, or `retired`, or if operational state independently enters `quarantined` or `retiring`, the same mapped K3 transaction/CAS MUST either replace it with another already-approved version or clear the active reference, set the operational state to `disabled` or `quarantined`, and fence the logical-fire cursor and every future or unclaimed run. No observer or admission path may see `enabled` pointing to a non-approved version. A stale transaction that cannot prove the expected version, definition state, operational state, cursor, and governing epochs fails closed.

A security/prompt-injection quarantine, consent or capability revocation, deletion fence, or equivalent unsafe invalidation also atomically advances an `executionInvalidationEpoch` and, through the existing K3 EventLog/state-row path, commits dispositions whose attempt-set coverage includes every nonterminal Attempt bound to the older epoch; this is not a best-effort scan or a new registry. Pre-boundary Attempts become `cancelRequested`. An Attempt whose Provider, publication, effect, commit, or other external boundary may already have crossed becomes `reconciling`. No Attempt becomes terminal merely because cancellation was requested.

Materialization, Provider allocation/claim, publication preparation/release, effect preparation/dispatch, and every state commit MUST reopen and equality-check the exact invalidation epoch immediately before their boundary. A stale Attempt cannot cross another boundary even if it was already `allocated`, `executing`, waiting, or checkpointed when invalidation occurred. Ordinary supersede or retirement may let an already-running Attempt finish only under an explicit pre-bound continuation policy and current epochs; quarantine, deletion, and revocation never use that exception.

`executionInvalidationEpoch` is a design-candidate low-entropy value, not a new ledger or owner. Controlled convergence must reuse or extend the mapped K3 generation/epoch mechanism and freeze its comparison rules before this name can enter production.

Selecting an approved version requires exact validation, shadow evidence, current policy, applicable user confirmation, L13 prepare/read-set, K3 invisible staging, L14 exact authorization/seal, K4 exact use/signature where required, and K3 activation. No model or Agent may jump from draft, candidate, failed validation, or quarantine directly into the active-version CAS.

### 4.3 AI-authored automation recipe and skill-package pipeline

The common proposal front half is:

```text
Natural-language request
→ structured proposal
→ deterministic canonicalization
→ schema validation
→ capability and data-flow analysis
→ injection and provenance checks
→ bounded fixture execution
→ dry-run / shadow comparison
→ user-visible semantic and permission diff
→ exact approval
```

It then branches by semantic target:

```text
Automation recipe using only already released schemas/skills/capabilities:
  → immutable Automation Definition candidate
  → Section 4.2 runtime-state adoption

New reusable skill/prompt/schema/package:
  → immutable inert candidate/evidence Artifact
  → runtime.certification
  → production.cutover canary and sealed release
  → only a released package identity may be referenced by a later
    Automation Definition version
```

K3 may retain the non-runtime candidate's mapped inert evidence/lifecycle references. It MUST NOT stage or activate a skill, prompt, schema, code, model, or policy through runtime-state commit. `runtime.certification` and `production.cutover` remain the sole adoption/deployment mouths for those targets.

Every pre-approval fixture, dry run, and shadow run has zero production side effects. It uses synthetic or explicitly recorded inputs, inert effect simulators, and recorded/synthetic receipts; it cannot dispatch through Zone C, call a network or Apple mutation API, spend a production capability, mutate production K3 state, publish user-visible output as final, or enqueue later work. The verification receipt MUST prove a production Effect Broker dispatch count of zero. A scenario that cannot be simulated safely remains unvalidated and cannot activate.

An AI-authored recipe or skill candidate declares:

- bounded typed inputs and outputs;
- the closed set of existing tools or operations it may propose;
- readable, forbidden, and proposal-only domains;
- resource and time ceilings;
- stopping and escalation conditions;
- deterministic fixtures and expected invariants;
- privacy, retention, and learnability posture;
- recovery and rollback behavior.

On iOS, a generated skill is a declarative Task Graph, query, rule, prompt, schema, or constrained composition of already signed capabilities. Qinao MUST NOT download and dynamically execute arbitrary generated Swift, Rust, C, C++, Metal, shell, Python, JavaScript, or native code. New executable code enters only through the ordinary reviewed, built, signed, and shipped application process.

### 4.4 Trigger normalization

Permitted trigger classes include:

- calendar/time schedule;
- authorized in-app event;
- authorized state predicate;
- explicit user action;
- App Intent, Shortcut, Widget, Control, or notification action;
- authorized external API or webhook in a future remote profile;
- Agent recommendation that creates a candidate trigger only.

Daily news and daily market briefs are ordinary time-triggered definitions, not special schedulers or Agents. They require source/freshness coverage and citation verification. A market brief grants no trading, payment, or financial-effect capability.

Every source is normalized into one trigger event contract with:

- source identity and attestation class;
- logical fire identity and idempotency key;
- wall and monotonic observations where available;
- time zone, calendar, locale, and daylight-saving interpretation;
- automation/version identity;
- current policy and authorization references;
- trigger payload digest and sensitivity;
- causal parent and source watermark.

### 4.5 Time and missed-run semantics

Each schedule explicitly chooses:

- fixed source time zone;
- follow-current-device time zone;
- or an exact calendar/time-zone rule.

It also chooses one missed-run policy:

- `skip`;
- `run-latest`;
- `bounded-backfill`.

Travel, daylight-saving changes, clock correction, device shutdown, offline periods, and cross-device duplicates cannot be left to implicit `Date` comparison.

No current production owner is proven for general automation recurrence, logical-fire cursor advancement, missed-run expansion, or cross-device fire deduplication. `BASBreathScheduler` is a maintenance-window mechanism and MUST NOT be repurposed as that authority.

V1 scheduled execution is device-affine. Each enabled automation binds one exact execution device/authority domain; only that domain may calculate and claim a logical fire. Other devices may display synchronized definitions and status or submit a request to transfer execution affinity, but they cannot fire the automation.

Controlled convergence MUST classify and map the following before a time trigger is executable:

1. L5 freezes the canonical schedule, time-zone, calendar, missed-run, and overlap policy.
2. A pure recurrence evaluator under the already planned `runtime.semantic-dag` owner computes a bounded next-logical-fire proposal. If that owner cannot honestly absorb the pure evaluator, the capability remains disabled pending a reviewed owner decision.
3. The K3 for the bound execution authority domain performs expected-cursor CAS, commits the normalized trigger disposition, and prevents the same logical fire from winning twice inside that domain.
4. L14 performs ordinary WorkUnit admission for each winning fire; the cursor itself grants no execution authority.
5. Apple/remote wake adapters only present observations and execution opportunities.

Until this mapping, schema, fault matrix, and non-vacuous gates pass, schedule creation may be previewed but scheduled execution and backfill are disabled.

Moving execution affinity is an explicit governed operation that fences the old domain, proves its lease expired or was revoked, reconciles every in-flight fire, and installs the new domain before enabling it. If an offline old device cannot be fenced, transfer waits for a trusted finite lease expiry or remains disabled.

Multi-device active execution is a future capability. It requires a separately approved linearizable execution lease or remote idempotency arbiter with one winning authorization domain. Eventual CloudKit replication and conflict merging are never a lock and cannot satisfy this requirement.

### 4.6 Scheduling and wake sources

The existing semantic policy/admission owners decide whether a scheduled WorkUnit is eligible. K3 durably preserves the exact schedule/run references and committed dispositions; the Task Graph represents only the already authorized work topology. An Apple or remote mechanism provides an execution opportunity and owns no eligibility truth.

Wake sources include:

- foreground event;
- existing `AppleBGTaskSchedulerBridge`;
- local notification interaction;
- App Intent, Shortcut, Widget, or Control;
- APNs or a future governed remote scheduler;
- next foreground reconciliation.

No BGTask, notification, APNs delivery, or network callback is treated as guaranteed or exactly timed. A “daily 08:00” product may schedule a user-facing notification for 08:00, but it cannot claim that a full background retrieval and model run will complete at that instant solely through BGTask.

### 4.7 Run lifecycle

Every admitted run is a normal Workspace-bound WorkUnit/Attempt. The following is a state inventory, not a claim that every run advances linearly through every row:

```text
observed | admitted | denied | allocated | executing
waitingForConfirmation | waitingForNetwork | waitingForModel | waitingForTool
checkpointed | cancelRequested | reconciling | degraded
succeeded | failed | cancelled | quarantined | indeterminate
```

`denied`, `succeeded`, `failed`, `cancelled`, `quarantined`, and `indeterminate` are terminal. Context compilation is an immutable Artifact/subreceipt required by `allocated → executing`, not a reducer state. The state inventory and transition table therefore use no separate `contextCompiled` state.

The legal transition families are:

| From | To | Required guard |
|---|---|---|
| observed | admitted or denied | normalized trigger identity, exact version, current epochs, ordinary L14 admission |
| admitted | allocated | K3 logical-fire/run CAS wins once and the exact lease/graph roots are installed |
| allocated | executing | exact current context-Artifact/subreceipt, capability, budget, model/profile, and active-version bindings |
| executing | a waiting state | safe checkpoint; no unrecorded live call or possibly crossed effect boundary |
| waiting | executing | awaited fact is current and the same Attempt remains legal; otherwise move the current Attempt toward a legal terminal before independently admitting any successor |
| executing or waiting | checkpointed | complete mandatory recovery manifest and committed budget/effect/publication state |
| checkpointed | executing, a waiting state, cancelRequested, or reconciling | Section 9 recovery/currentness/reconciliation passes; never restore hidden KV blindly |
| any pre-boundary nonterminal state | cancelRequested | K3 records the request and fences future claims |
| cancelRequested | cancelled | every live child acknowledges terminal cancellation and no external boundary may have been crossed |
| cancelRequested | reconciling | an effect, Provider, publication, or external-write boundary may have been crossed or cannot be disproven |
| effect/provider/publication boundary possible | reconciling | only the exact prior operation may be queried/reconciled; ordinary cancel cannot rewrite external truth |
| reconciling | executing | authenticated terminal evidence proves the prior boundary did not produce the effect and continuation remains authorized |
| reconciling | succeeded, failed, quarantined, or indeterminate | exact terminal/reconciliation receipt |
| any nonterminal state | degraded | independently verified bounded subset plus omission/unresolved manifest; no implicit success |
| any state | terminal state | mapped terminal receipt and no unclosed child/boundary; terminal states have no outgoing transition |

Each transition uses the mapped K3 expected-state/expected-head CAS and emits its canonical event and receipt. A lost reply reopens the same transition identity. UI status is a projection and cannot advance the reducer.

`denied` is the terminal disposition of an observed trigger that never allocates a run. A successor Attempt is not a state of the current reducer: when identity, model/profile, policy, authorization, or recovery rules require a successor, the current Attempt first closes in one legal terminal state with its exact receipt; a separately authorized Attempt with a new identity then begins at `observed`/`admitted`.

### 4.8 Overlap and deduplication

Each definition chooses exactly one overlap policy:

- `skip`;
- `coalesce` as the safe default;
- `queue-one`;
- `bounded-parallel` with an explicit small ceiling.

The run identity binds automation, immutable version, execution-authority domain, normalized trigger identity, and logical fire sequence. Inside the one bound domain, process restart, repeated APNs, and lost replies cannot create a second authorized effect. Cross-device active firing remains disabled until the future linearizable lease/arbiter gate proves one winning authorization domain.

Qinao guarantees no duplicate local handoff through its K3/K4/Zone-C protocol and makes no global exactly-once claim about an external service. Unknown external outcomes are queried, reconciled, compensated when authorized, or reported indeterminate; they are never blindly resent.

### 4.9 Self-improvement boundary

RSI, learning, Main Agents, Sub Agents, and outcome analysis may create a new automation or skill candidate. They cannot mutate the active version in place, replenish their own budget, extend their own authority, or activate their proposal.

Every adoption is a new version with an explicit diff, independent evidence, bounded shadow/canary evaluation, and rollback target.

### 4.10 Modular Automation Space

The initial module vocabulary is:

- Today and Upcoming;
- Automations;
- Skill Library;
- Templates;
- Running;
- Awaiting Confirmation;
- Failure and Recovery;
- Data and Permissions;
- Learning Insights;
- History and Causal Trace.

Module order, size, grouping, and visibility are user preferences. Layout state cannot change execution semantics, authority, schedule eligibility, or retention.

## 5. Fine-Grained Interaction Evidence

### 5.1 Collection boundary

Qinao records semantically meaningful actions inside Qinao and data delivered by explicitly authorized Apple/public frameworks. It does not claim access to every action elsewhere on iOS and does not use private APIs, accessibility abuse, hidden screen capture, ambient microphone collection, or keystroke surveillance.

### 5.2 Event taxonomy

The normalized evidence taxonomy includes:

- input, draft, edit, submit, cancel, undo, redo;
- open, close, navigate, Workspace switch, Session switch, App Agent selection;
- accept, correct, reject, regenerate, request-evidence;
- create, edit, approve, pause, resume, retire, delete automation;
- tool request, grant, denial, invocation, observation, reconciliation, effect result;
- Main/Sub delegation, join, conflict, remand, stop;
- retrieval, context compile, Provider route, fallback, cancellation, verification;
- checkpoint, interruption, recovery, rebase, rollback;
- memory candidate, promotion, correction, forget, deletion;
- learning eligibility, quarantine, dataset inclusion, evaluation, activation, rollback;
- Apple surface, notification, sync, permission, and external-data observations.

Raw per-keystroke content and per-pixel touch trails are not default semantic evidence. Dwell time, notification opens, session length, praise, silence, or emotional attachment cannot directly become reward.

#### 5.2.1 Signal normalization and granularity

Raw UI/OS signals and persisted semantic events are different classes:

- raw touch, key, pointer, scroll, focus, and render signals are R1-only process buffers, never EventLog rows and never learning examples;
- the wire action vocabulary is a closed, versioned enum with a bounded schema for each case; free-form `payloadJson` is not the target contract;
- one stable input/action root and monotonic local sequence bind every coalesced transaction;
- byte-identical reuse of an event identity returns the prior disposition; the same identity with different canonical bytes is corruption;
- undo/redo references the exact target transaction or delta digest;
- larger content uses an authorized Artifact reference rather than an oversized event field.

The initial normalization profile is:

- an explicit submit, save, approve, reject, undo, redo, permission decision, tool/effect boundary, automation transition, or deletion request always creates its own semantic event and is never rate-coalesced;
- continuous draft/edit signals coalesce into one content-free edit transaction and flush on explicit save/submit, undo/redo, focus loss, two seconds of inactivity, 64 raw changes, or 16 KiB of normalized delta metadata, whichever occurs first;
- route/open/close events are emitted only for a committed lifecycle or route transition, not every render; repeated delivery of the same transition identity is idempotent;
- noncritical diagnostic events are capped at 32 per actor/surface/second; overflow emits one bounded aggregate/drop receipt and cannot drop an authorization, effect, deletion, correction, or terminal event;
- EventLog structured metadata is capped at 4 KiB per event under the initial profile; content or larger evidence is an Artifact.

Changing those constants is a versioned policy/profile change with replay, privacy, performance, and migration evidence. Until a closed schema and normalization profile replace unrestricted payloads, new fine-grained diagnostic persistence remains disabled.

Default posture by class is:

- navigation and content-free edit diagnostics: R1 and non-learnable;
- submitted/saved user content: an explicit R2 or R3 content policy, with separate learning consent;
- authorization, permission, deletion, effect-control, integrity, and governance transitions: R4 and non-learnable;
- terminal task/effect outcomes: only a separately derived bounded outcome feature may be considered under Section 6.

#### 5.2.2 Closed learning-source classification

Every event receives exactly one source class:

1. `experienceSource` — an independently observed user/task/environment event that may enter eligibility.
2. `derivedOutcomeFeature` — a bounded feature derived from independent terminal evidence; ineligible by default and usable only under an explicit purpose-specific rule.
3. `governanceControl` — eligibility, quarantine, dataset inclusion, evaluation, adoption, rollback, permission, or policy lifecycle.
4. `auditProof` — authorization, denial, integrity, deletion, effect-control, and signature evidence.
5. `projectionOnly` — UI, dashboard, cache, metric, or rebuilt view.

Only `experienceSource` may enter the ordinary Experience-envelope gate. A `derivedOutcomeFeature` requires its own current authorization, independent source receipt, lineage, and anti-self-corroboration check. Governance, audit, and projection classes are always learning-ineligible. Therefore a learning-eligibility event cannot recursively create another eligible learning event or certify itself.

### 5.3 Event identity and causal-learning contract

Every persisted semantic event binds:

- event identity, root-cause identity, and causal parent;
- Workspace, Session, selected App Agent, logical Main, Sub Agent, and Provider invocation as applicable;
- Mission, Objective, WorkUnit, Attempt, Automation, definition version, branch, and graph epoch;
- actor, surface, source, action, target, and declared purpose;
- before/after state digests and source watermark;
- model, Provider, execution plan, context descriptor, and policy identities;
- consent, capability, deletion, revocation, sharing, and privacy epochs;
- privacy, sensitivity, retention, and learnability classes;
- latency, token, memory, thermal, energy, network, and cost observations;
- content Artifact reference, result, verification, effect, and publication receipts;
- confidence and epistemic status where semantically applicable.

No event copies a broader authority merely for convenience. References are reopened and equality-checked by the owning boundary.

An ordinary interaction event is not automatically a causal-learning envelope. Before an action is exposed, a causal/OPE-eligible decision contract additionally freezes:

- the complete eligible action set or deterministic singleton;
- selected action;
- behavior-policy identity and digest;
- exact propensity, or a typed deterministic-decision marker when propensity is not meaningful;
- exposure/cohort identity and observation time;
- generator, evaluator, root, and shared-training-lineage correlation classes;
- bounded delayed-outcome window;
- missingness/censoring policy;
- exact outcome contract and independent evidence source.

The later outcome references that pre-exposure contract. If any mandatory field was not committed before exposure, the event may support diagnostic association only; it is ineligible for causal credit, off-policy evaluation, or claims that one model/automation caused improvement.

### 5.4 Content separation

EventLog stores bounded structured facts, digests, and references. Raw text, audio, image, file, tool result, and large model output bytes belong only in the mapped encrypted content-addressed Artifact path after its decision gate passes.

Provider-private KV/session state, hidden chain of thought, credentials, ambient handles, and mutable prompt objects are not durable memory or learning content.

Secret detection occurs before durable content materialization when possible. If detection follows a write, the purge and key-revocation path wins over the 72-hour minimum.

## 6. Retention, Erasure, and Learning

### 6.1 Retention classes

The approved semantic classes are:

1. **R0 Never Persist** — credentials, keys, tokens, one-time codes, unauthorized high-sensitivity material.
2. **R1 Ephemeral** — KV cache, transient prompts, temporary tool materialization, intermediate neural state; bounded by the exact task/resource lifecycle.
3. **R2 72-Hour Eligible-Learning Window** — ordinary consented data that independently passes privacy and learnability gates.
4. **R3 User Durable** — user-selected documents, tasks, memories, automation definitions, and other content retained under an explicit product purpose.
5. **R4 Audit Proof** — minimized authorization, denial, deletion, effect-control, and integrity evidence; always non-learnable. A separately derived, privacy-safe outcome feature may cite an effect receipt without turning the control proof itself into training data.

R2 admission is one explicit K3 disposition at ingestion, not a later analytics relabel. It binds source-occurrence evidence, the first committed authorized durable-content reference, and the K3 commit that begins the retention window. Data that remains R1 cannot be retroactively converted into an R2 example merely to restart or extend the clock.

An implementation contract needs:

- `retentionStartCommit` bound to the K3 R2-admission commit;
- trusted wall-clock evidence plus same-boot monotonic evidence when available;
- `minimumRetainUntil = retentionStart + exactly 72 hours`;
- a mandatory purpose-specific `maximumRetainUntil`;
- early-erasure conditions;
- purpose, consent, policy, deletion, revocation, and key epochs;
- final disposition and terminal receipt.

A wall-clock rollback or reboot ambiguity cannot shorten the minimum. Recovery uses anchored clock evidence and chooses the conservative later bound until it can prove the elapsed interval. A single TTL or `maxAgeSec` cannot encode these semantics.

### 6.2 Seventy-two-hour disposition

At or after the R2 minimum window, the owning governance path chooses exactly one:

- purge raw content and retain only authorized minimized typed features;
- promote exact content to R3 after explicit memory/document policy;
- extend retention for an already authorized purpose within its maximum;
- include a cleaned immutable example in a governed dataset generation;
- quarantine pending privacy, provenance, conflict, or deletion resolution.

Time passage cannot itself select training, promotion, export, or sharing.

Every retention extension is a new purpose-bound authorization with a finite expiry no later than the applicable mandatory maximum. Quarantine has a hard deadline and ends in purge, a newly authorized finite disposition, or a typed unresolved terminal state; it cannot become an indefinite hidden R3 store.

### 6.3 Pruning

Event/history compaction is sequence- and checkpoint-based. It requires:

- a sealed lossless checkpoint for all mandatory recovery facts;
- exact high-water marks;
- retention authorization;
- proof that no surviving index, projection, cache, dataset, Provider replica, or effect workflow requires the bytes;
- a deletion/revocation currentness check.

Wall-clock deletion of one event class while dependent admission, effect, or correction history survives is forbidden.

The target EventLog schema is content-free and bounded. Deletable user bytes live behind an erasure-domain key in the mapped Artifact path; the event retains only the minimum blinded reference, classification, causal slot, and non-content proof required for replay. Selective erasure does not edit an append-only row in place:

1. K3 commits the deletion epoch and a blinded superseding tombstone;
2. reads, learning, export, and new materialization are fenced;
3. the erasure-domain key and content bodies are destroyed or made provably unreachable;
4. projections and indexes rebuild without the deleted material;
5. a sealed checkpoint preserves the mandatory causal/integrity boundary;
6. eligible old EventLog ranges, sidecars, WAL pages, snapshots, and backups are pruned only under the checkpoint/retention protocol.

Current free-form event payloads and timestamp-range-only pruning do not prove this capability. Controlled convergence MUST inventory EventLog rows, integrity sidecars, WAL/SHM, checkpoints, backups, Artifact bodies/keys, and every index/cache/projection. Any legacy event generation that contains deletable or secret bytes in structural fields requires a sealed migration/rewrite into the bounded content-free generation followed by cryptographic erasure of the old database material. Until that erasure mouth and migration prove closure, durable R2 content capture remains disabled.

### 6.4 Erasure

Erasure follows:

```text
deletion request
→ K3 deletion-epoch advance and synchronous source read/use fence
→ lineage closure over every descendant
→ synchronously mark every unused descendant ineligible and fence use
→ cancel in-flight training/evaluation/export/adoption where still cancellable
→ classify already trained, released, exported, or externally copied descendants
→ local content/key/EventLog-range/index/cache/checkpoint/backup cleanup
→ external destination purge/query or typed inability evidence
→ complete rescan and projection rebuild
→ one honest terminal disposition
```

The synchronous descendant fence precedes asynchronous physical cleanup. It covers dataset generations, splits, training jobs, optimizer/checkpoint state, embeddings, synthetic derivatives, adapters, model candidates, evaluation reports, exports, canaries, release candidates, and every other lineage descendant. No fenced descendant may train, evaluate, export, select a model/profile, enter cutover, or serve inference.

Terminal dispositions are closed:

- `completed`: every required owner proved purge, absence, cryptographic erasure, or an allowed minimized non-content tombstone; only this case emits a completed deletion proof;
- `residualExternalCopies`: a destination is known to retain data or cannot perform required purge; it emits a scoped unresolved receipt and blocks completion;
- `indeterminateBlocked`: closure, remote state, backup state, or trained-weight disposition cannot be established; it emits an incident/unresolved receipt and blocks completion.

A minimized tombstone proves the deletion request, epoch, fenced scope, and terminal disposition. It never falsely proves that an unresolved external copy or trained derivative disappeared.

Cross-device sync carries deletion epochs and cannot resurrect data from an old replica.

If exact unlearning or removal cannot be proven for a training path, data requiring that guarantee is ineligible for that path. Discovery of an affected trained/released candidate after the fact forces quarantine, cutover rollback when possible, blocked reuse, and an incident disposition; it cannot be relabeled as successful erasure.

### 6.5 Learning eligibility

The learning path is:

```text
authoritative source event and terminal receipts
→ eligibility and purpose
→ consent and scope
→ provenance and integrity
→ structural cleaning
→ prompt-injection cleaning
→ epistemic and semantic cleaning
→ privacy and secret cleaning
→ App-Agent/Workspace contamination cleaning
→ immutable experience envelope
→ immutable dataset generation
→ evaluation and causal credit
→ shadow/canary
→ governed candidate adoption
```

Every event first receives the closed Section 5.2.2 source classification. Every `experienceSource` yields either an eligible bounded envelope or an explicit ineligible receipt. The other four classes do not recursively enter the ordinary gate. UI code, exporters, analytics, crash logs, model responses, and Providers cannot write around this path.

### 6.6 Reward evidence

Permitted reward components include:

- explicit user correction;
- verified task completion;
- deterministic constraint and logic checks;
- source-faithful extraction;
- effect result proven by receipt;
- recovery continuity and unresolved-state honesty;
- calibrated uncertainty;
- latency, energy, memory, and cost within the declared quality contract.

Forbidden optimization objectives include:

- engagement or time spent;
- dependence or emotional capture;
- compliance for its own sake;
- opening frequency or streaks;
- silence as consent;
- a model's self-confidence;
- unverified praise.

### 6.7 No self-training shortcut

A Main/Sub/Provider output is an untrusted proposal. It cannot become App Agent Self, memory, fact, reward, dataset truth, or a production model merely because it was generated or user-visible.

Learning changes produce a new candidate whose target determines the only legal adoption path:

- **Authoritative runtime-state target:** L10 verifies, L11 revalidates privacy/risk/confirmation, L13 prepares the exact candidate/read-set, K3 invisibly stages, L14 authorizes the exact terminal seal, K4 signs/claims the exact use, and K3 activates or appends.
- **Inert evidence/data/job artifact:** the incumbent schema owner validates bounded canonical bytes, Artifact Mesh stores/reopens them, and K3 retains only already mapped lifecycle/currentness/deletion-fence references. Every later evaluation, export, trainer, or protected use is separately authorized.
- **Non-runtime skill, prompt, schema, code, model, or policy target:** K3 retains only an inert candidate/evidence reference. `runtime.certification` and `production.cutover` are the sole canary, release, full-cutover, and rollback mouths. Runtime-state commit cannot deploy it.

The target classes cannot be combined into one state machine or substituted for one another.

## 7. Analytics That Understand Models and Users

### 7.1 Projection-only analytics

All dashboards, statistics, profiles, and insights are rebuildable projections over governed events, receipts, artifacts, and snapshots. There is no separate mutable user-behavior truth or AnalyticsDB.

SQL/metadata is the first path. FTS5/BM25 handles exact lexical retrieval. Dense retrieval is conditional. Temporal/episode and entity/relation projections preserve continuity. A small grounding model returns proposals only.

### 7.2 Model Runtime Profile

The model profile projection measures by exact model/profile/runtime/device/OS cohort:

- declared and effective context capacity;
- tokenizer and exact/conservative accounting contract;
- prefill, prefix cache, suffix continuation, and rebuild behavior;
- KV/state ABI and cache compatibility;
- plain decode, prompt lookup, MTP, and fallback eligibility;
- cold, warm, and sustained accepted decode;
- first-token and end-to-end latency;
- memory, thermal, energy, network, and monetary cost;
- tool, vision, long-text, extraction, logic, grounding, and recovery quality;
- failure, cancellation, timeout, indeterminate, and fallback modes.

The projection cannot select a semantic answer or silently change model identity. L2 chooses a certified plan; K2 executes it.

### 7.3 User Experience Profile

The user profile projection may represent:

- user-confirmed answer length, structure, language, and presentation preferences;
- recurring task families and work rhythms;
- notification windows and interruption tolerance;
- confirmation preferences within policy limits;
- recurring corrections and error sensitivities;
- stable goals and explicitly approved habits;
- evidence source, confidence, counterexamples, expiry, and last confirmation.

Emotion is a transient, low-confidence interaction hint unless the user explicitly records a durable preference. It cannot become a psychiatric label, cross-Agent embedding, reward objective, or hidden permanent trait.

### 7.4 Model and user adaptation are orthogonal

A stronger API model receives no broader data, capability, memory, or authority than a local model. A local model receives no weaker correctness or safety contract because it is smaller.

Context size, tokenizer, tool support, modality, latency, privacy, cost, network, and thermal state are Provider/profile facts. User style, purpose, task, and confirmation preferences are user/Workspace facts. The planner adapts both dimensions without merging them.

### 7.5 Causal analysis

Analytics binds exact definition, model, context, retrieval, verifier, effect, and outcome identities. It distinguishes correlation from intervention.

Where safe, shadow/canary comparison, matched cohorts, explicit estimands, and counterfactual evaluation support causal credit. A model or automation cannot claim improvement from a single favorable anecdote, changed population, or engagement proxy.

## 8. App Agent, Main Agent, Sub Agent, and Automation Collaboration

### 8.1 Identity classes

The non-interchangeable identities are:

- Host;
- Workspace;
- persistent App Agent;
- interactive Session;
- logical Main Agent;
- bounded Sub Agent;
- Provider Invocation;
- Automation WorkUnit/Attempt.

One Session selects exactly one App Agent and one logical Main. An Automation Attempt need not keep a Session alive, but it binds its exact ownership mode and cannot borrow the current UI selection.

### 8.2 App Agent embodiment

The Context Compiler combines a bounded projection of:

- selected App Agent Self;
- exact Workspace and task contract;
- Session continuity;
- current high-authority state;
- tool/output schema;
- applicable policy and confirmation state.

The App Agent influences companion expression, approved values, relationship continuity, and user-confirmed interaction preferences. It does not control factual truth, permissions, effect execution, state commitment, verification, or audit.

Qwen3.5-4B, AFM, and future local/API Providers are replaceable cognitive mechanisms. Replacing the Provider does not replace the selected App Agent or logical Main identity.

### 8.3 Model observations are proposals

Main and Sub Agents may submit:

- experience proposals;
- memory candidates;
- preference candidates;
- relationship observations;
- Self-evolution proposals;
- automation/skill patches.

They cannot write App Agent Self or authoritative memory directly. Cleaning, counterexample search, confidence/expiry, shadow/canary, L10/L11/L13/L14, K3/K4, and cutover remain mandatory.

### 8.4 Isolation compartments

The design preserves:

- Host-neutral shared data;
- exact Workspace-scoped data;
- App-Agent-private data;
- Session-private data;
- Attempt-private data;
- explicit immutable shares.

Other App Agents may consume an exact authorized share but cannot modify the source or use a derivative to declassify or overwrite the source scope.

A read/share grant is not a training grant. Dataset inclusion, adaptation, embedding, cache reuse, model/profile selection, export, certification, and cutover each require an explicit compatible purpose and consumer grant.

Every derived artifact inherits the intersection of all source restrictions across App Agent, Workspace, purpose, recipient, destination, privacy, retention, deletion, and revocation scope. Embeddings, synthetic examples, datasets, adapters, optimizer/checkpoint state, model candidates, compiled caches, and evaluation reports remain same-App-Agent-only by default. Derivation cannot broaden the intersection or remove taint.

Model/profile selection and retrieval MUST reject an adapter, checkpoint, embedding, cache, or candidate whose lineage includes another App Agent's private data unless the exact separate training/use grant authorizes that recipient and purpose. Export and production cutover repeat the same negative check.

Deleting App Agent A's private source fences and disposes every A-derived candidate and cache without deleting independent Host-shared or App Agent B data. An explicit A→B read share alone does not make A's data eligible for B's dataset, adapter, model selection, export, or cutover.

### 8.5 Independent contexts

Each Main, Sub, and Automation Attempt receives its own `ContextCapsule` semantics:

- exact task slice;
- required evidence and state references;
- allowed capabilities and tools;
- token, byte, branch, time, energy, and effect budgets;
- stopping and escalation conditions;
- output and verification contract.

Agents do not share mutable KV cache or hidden reasoning. They exchange immutable evidence references, structured summaries, proposals, confidence, assumptions, conflicts, counterexamples, unresolved conditions, receipts, and digests.

A prefix cache is reusable only when model, tokenizer, template, State ABI, policy, scope, context bytes, and generation bindings are exactly compatible.

### 8.6 Typed Agent communication

A Sub Agent result binds:

- task and attempt identity;
- claim/result schema;
- evidence references;
- fact/inference/recommendation status;
- confidence and calibration basis;
- assumptions, conflicts, and counterexamples;
- unresolved prerequisites;
- resource use and stop reason;
- requested next capability, if any;
- result digest.

Main joins use evidence authority, coverage, conflict, and verifier receipts rather than majority vote.

### 8.7 External content is inert

Web pages, messages, files, retrieved skills, tool results, external Agent messages, and model-produced arguments are untrusted data. They remain escaped and separate from system instructions, capability descriptions, and tool schemas.

Prompt-injection detection, provenance, purpose, scope, sensitivity, currentness, and grounding precede context inclusion. Data cannot grant authority.

## 9. Context Windows, Interruption, and Recovery

### 9.1 Multiple logical context windows

Qinao supports multiple independent logical context windows over one Workspace:

- current interactive Main;
- each Sub Agent;
- each Automation Attempt;
- historical/episode review;
- Apple Intent micro-context;
- recovery/reconciliation context.

Residency may be active, warm, or cold, but identity and recovery are artifact- and receipt-based, never inferred from a live model session.

### 9.2 Context is compiled

`BASContextCompiler` remains the sole L3 packing owner. “Context Budget Allocator” and “State Compiler” are phases of that owner.

Each compilation:

- binds one snapshot and generation;
- preserves task root, hard constraints, material conflicts, corrections, authority, risk, deletion, effect, and publication state;
- assigns explicit section budgets;
- records provenance, offsets, omission ledger, and exact digest;
- tokenizes once for the selected tokenizer or uses a certified conservative bound;
- distinguishes full prefill, same-Attempt continuation, exact prefix reuse, and rebuild.

Model, tokenizer, profile, policy, scope, State ABI, generation, or material evidence change forces a legal recompile.

### 9.3 Checkpoint and recovery

Durable recovery is:

```text
checkpoint
→ reopen exact WorkUnit/Attempt and graph epoch
→ verify current policy, permission, deletion, revocation, and model/profile
→ reconcile every possibly crossed Provider/publication/effect boundary
→ calculate remaining lease and continuation policy
→ compile a new context
→ lawful same-Attempt continuation, or terminally close the current Attempt and independently admit a successor
```

Qinao does not deserialize hidden reasoning or blindly continue stale KV. A possibly executed remote call or irreversible effect is query/reconcile-only.

### 9.4 User steering

A user follow-up, cancel, correction, or priority change is a new uniquely identified Input Event. K3 performs expected-head and idempotency checks after the semantic owners decide whether it targets the current Attempt, requests cancellation/rebase, becomes deferred work, or creates an independent WorkUnit.

Repeated delivery of byte-identical input returns the prior committed disposition. Reuse of an event ID with different bytes is corruption.

## 10. Apple Ecosystem Integration

### 10.1 Thin-adapter rule

Apple integration has three non-interchangeable adapter classes:

```text
Apple system surface ingress
→ AppleSurfaceIngressAdapter
→ BASEntryIntentEnvelope / existing host route
→ ordinary Qinao admission and governed branch

Authorized Apple read
→ caller-aware AppleReadGateway
→ minimized typed observation
→ normalized Event/Artifact path

Authorized Apple mutation
→ K3 outbox + L14/K4 + boundary arm
→ ZoneCAppleEffectExecutor
→ public Apple framework call
→ terminal/indeterminate receipt and canonical state saga
```

`AppleSurfaceIngressAdapter` may parse, validate platform types, minimize fields, and translate results. It may not rank, authorize, persist, retry, schedule semantic work, mutate state, execute an external effect, or become a recovery owner.

`AppleReadGateway` is an Adapter/IO implementation behind the existing caller-aware read membrane, not a second capability gateway. It may call only an explicitly mapped public read API after current framework and Qinao read authorization. It returns a bounded observation and owns no cache, semantic interpretation, or write authority.

`ZoneCAppleEffectExecutor` is the sole mutation caller and is callable only by the fresh Zone-C CAS winner holding the exact broker/permit/anchor/arm chain. It owns no policy or independent retry. CloudKit save/delete and subscription mutation are external disclosure/effect profiles of this same broker path, not a separate sync mouth; CloudKit fetch/change observations enter through the authorized read/ingress path.

### 10.2 Initial App Intent surface

The safe initial actions are:

- open Work Space;
- open Automation Space;
- open a task-continuation view and submit a normalized continuation request;
- capture a draft;
- inspect automation status;
- show the next-question projection.

Before the semantic Task Graph/executor and Section 9 recovery path are implemented, “task continuation” is a foreground deep link plus Input Event only. It cannot resume a Provider call, allocate a successor Attempt, or execute work from an App Intents extension. True execution continuation is enabled only in the later Task Graph/recovery delivery stage.

After W5 Effect Broker and exact confirmation paths pass, controlled convergence may add:

- run an already approved automation;
- pause or resume an automation;
- confirm or reject an exact pending action;
- undo an explicitly reversible action.

The first entity surface is deliberately narrow:

- Workspace summary;
- Automation summary;
- Task summary.

It exposes stable identity, display name, and safe status only. Prompt bytes, private memory, App Agent Self, effect parameters, secrets, and unrestricted receipts are not App Entity fields.

Every Intent MUST declare an explicit execution/security matrix; platform defaults are not accepted:

| Intent class | Allowed execution target/mode | Authentication and Qinao guard | Effect posture |
|---|---|---|---|
| Open Work/Automation Space | Main app, foreground/deep link | normal app unlock/privacy projection | no state or external effect |
| Open task continuation / request continuation | Main app, foreground only | exact task identity and fresh normalized user event | request only until Task Graph/recovery ships |
| Capture draft | Main app, foreground only | unlocked device; LocalAuthentication when sensitivity policy requires; canonical verified L13 → K3 stage → L14/K4 seal → K3 activation path | no external effect and no final submission |
| Inspect status / next question | Main app or explicitly selected extension/widget target; read-only mode only | attenuated read capability; locked surfaces receive a redacted snapshot | no mutation |
| Run approved automation | Main app, foreground, unlocked, user-present | exact active version, pending-action digest, fresh L11/L14/K4 use, current epochs, W5 broker | disabled before W5; broker only |
| Pause/resume scheduling | Main app, foreground, unlocked | fresh Input Event, current-version/epoch checks, exact operational-state CAS and receipt | internal governed state only |
| Confirm/reject pending action | Main app, foreground, unlocked | exact pending-action digest; LocalAuthentication for policy-selected risk; fresh L11/L14/K4 decision | only the confirmed broker operation may proceed |
| Undo | Main app, foreground, unlocked | exact reversible receipt and current state; fresh authorization | mapped compensation/reversal only; never blind inverse |

Sensitive or mutation-bearing Intents MUST explicitly restrict `allowedExecutionTargets`, foreground/background support, discoverability, locked-device behavior, and authentication. A Widget, Control, Siri phrase, App Entity ownership hint, or `OwnershipProvidingEntity` result does not substitute for Qinao's fresh Input Event, exact pending digest, risk decision, capability use, Effect Broker, or LocalAuthentication requirement.

### 10.3 iOS 27 App Intents posture

Subject to exact SDK/build evidence, Qinao SHOULD use the current App Intents mechanisms for discovery, stable entity identity, cancellation, undo, and bounded execution. For security-relevant Intents, explicit target/mode/authentication configuration is a MUST:

- Siri, Shortcuts, Spotlight, widgets, Controls, and Apple Intelligence discovery;
- explicit foreground/background mode support;
- cancellation and cleanup;
- reversible actions;
- execution-target restriction;
- stable cross-device entity identity;
- ownership-sensitive confirmation;
- bounded long-running intents where the system supports them.

Long-running intent support is still bounded, cancellable execution opportunity. It is not a daemon, exact scheduler, or correctness authority.

### 10.4 Widget, Control, and Live Activity

Widgets, Controls, and Live Activities read only signed, minimized, purpose-specific snapshots suitable for their separate process and lock-screen exposure.

Permitted initial content includes:

- safe current task status;
- upcoming automation;
- waiting-for-confirmation count;
- safe recent outcome;
- bounded progress.

Interactions invoke an App Intent. Extensions do not open raw K3, memory, Artifact Mesh, or Provider state. An App Group, if used, contains only the narrowed shared snapshot and validation material.

### 10.5 Notifications

Notifications may represent:

- scheduled reminder;
- automation completion;
- waiting confirmation;
- failure/recovery state;
- user-requested important update.

Lock-screen content is minimized according to privacy class. The closed observation vocabulary is:

- request committed;
- local system scheduling accepted;
- APNs request accepted by the service, when applicable;
- foreground notification callback observed;
- user notification action observed;
- currently listed in Notification Center at a queried instant;
- cancelled, expired, or unknown.

Scheduling or APNs acceptance never implies device delivery or presentation. Absence from a later Notification Center snapshot does not prove non-delivery or user viewing. Local and remote delivery are not guaranteed.

### 10.6 Calendar, Reminders, Contacts, and productivity data

Read flows require exact framework permission and Qinao capability scope. Write/delete flows require:

- current user/framework authorization;
- L10 verification and exact L11 risk/confirmation;
- L13 exact effect prepare;
- K3 EventLog/outbox prepare;
- L14 exact effect authorization and K4 durable issue/reserve;
- the canonical K3/K4 boundary-permit/anchor/arm path;
- sole Zone-C executor dispatch;
- terminal or indeterminate observation receipt;
- L13 receipt interpretation and StateCommitIntent;
- K3 invisible staging, L14/K4 terminal seal/signature, and K3 activation when authoritative state changes.

Calendar access requests the narrowest available level. Contact materialization uses field masks and never copies an entire address book into a general model context.

Apple frameworks with no suitable public read/write API remain unavailable. Qinao does not simulate support with UI automation or private APIs.

### 10.7 HealthKit and other high-sensitivity domains

HealthKit is a separate highest-sensitivity integration profile:

- per-data-type read and write authorization;
- limited-history authorization support;
- purpose-bound materialization;
- HealthKit-origin and health-derived data MUST NOT enter general-model training, general behavior analytics, the general User Experience Profile, a general remote/API Provider, CloudKit/iCloud, or cross-App-Agent sharing;
- use is limited to an explicit health/fitness function or separately eligible consented health research profile after product, privacy, security, legal, and Apple-policy review;
- disclosure to a third party requires explicit consent and an approved health/fitness destination and purpose; a generally capable API model is not eligible merely because it can process the data;
- visible user controls and deletion posture;
- exact effect receipt for writes.

For reads, HealthKit intentionally does not let the app distinguish read denial from the absence of authorized samples. Qinao records `unknown/no-authorized-samples`, never “denied” or “no health data,” unless the framework exposes a positive state. A limited-history earliest-authorized date bounds every query. Write/share authorization is checked separately and fails closed on denial or indeterminate authorization.

Home, location, photos, microphone, camera, speech, and similarly sensitive domains require their own capability, entitlement, purpose-string, minimization, lifecycle, and review gates.

System pickers are preferred over broad library access. Recording and capture require an obvious foreground state unless an exact public framework and user-approved product purpose explicitly permit otherwise.

### 10.8 Additional public-framework profiles

Maximum lawful ecosystem coverage is organized as separately gated profiles:

- WeatherKit, MapKit, and Core Location for purpose-bound weather/place/location observations;
- Files, Photos, Vision, AVFoundation, Camera, and Speech through system pickers or visible capture;
- MusicKit and MediaPlayer for user-authorized media discovery/control;
- HomeKit/Matter, CoreBluetooth, and Nearby Interaction as high-risk device/effect profiles;
- PassKit, Wallet, payment, and identity surfaces as separately reviewed high-risk proposals with explicit user presence; no autonomous purchase or credential extraction;
- FamilyControls/DeviceActivity only for an entitled, eligible product purpose and never as a general behavior-surveillance channel;
- Share, compose, document, and App Intent surfaces where Mail, Messages, Notes, or another Apple app exposes no general public database API.

Each profile begins disabled and receives its own public-API, product-eligibility, entitlement, purpose, minimization, effect, recovery, privacy, and App Review evidence. Lack of a public API is a real unavailable capability, not an invitation to automate another app's UI.

### 10.9 CloudKit and cross-device continuity

CloudKit is an optional authenticated replication and transport mechanism. `CKSyncEngine` is only one possible implementation profile and is not eligible by default. Neither is a replacement for Qinao state objects or K3 authority.

Every CloudKit record save/delete, share/subscription mutation, or upload is a remote disclosure/effect. It follows the same L11 disclosure/currentness decision, L13 prepare, K3 outbox, L14/K4 authorization, Zone-C single-winner dispatch, terminal/indeterminate observation, and reconciliation protocol as other Apple external writes. A framework callback or sync engine cannot write Qinao state directly. Fetches and change notifications become minimized typed observations and ordinary Input Events before K3 state changes.

If `CKSyncEngine` is selected, all of the following are hard admission gates:

- one engine instance is a non-authoritative Adapter/IO mechanism behind two disjoint ports: only the Zone-C executor can invoke its send/pending-change port, only `AppleReadGateway` can invoke its fetch port, and delegate events can only emit typed ingress;
- `database.databaseScope` is exactly `private` or `shared`; `public` is unsupported for `CKSyncEngine` and must use governed lower-level `CKDatabase`/`CKOperation` requests or remain disabled;
- `Configuration.automaticallySync` is explicitly `false` and asserted at initialization and in tests; the default automatic send/fetch scheduler is forbidden;
- the exact non-optional `subscriptionID` identifies a subscription that the broker path has already created and verified; automatic subscription discovery or creation is forbidden;
- adding pending database/record changes and invoking `sendChanges` occurs only inside the one live Zone-C outbox claim; each delegate batch reopens the exact outbox identity, disclosure/currentness decision, permit, invalidation epoch, and operation-group/boundary identity before it returns bytes;
- `fetchChanges` is invoked only by `AppleReadGateway` under a current caller-aware read decision; automatic notification-driven fetching cannot bypass normal ingress;
- framework recoverable retry, batching, and callbacks remain children of the same boundary instance and cannot create a fresh claim, refresh authority, or widen the batch; permit expiry/revocation calls `cancelOperations`, then treats any possibly crossed request as `reconciling` rather than assuming cancellation erased remote truth;
- the most recent opaque `stateSerialization`, pending-change identities, server tokens, and exact subscription identity are persisted by the mapped K3 state/Artifact path through typed events; the adapter, delegate, App Group, and framework callback own no private file or recovery truth;
- at most one configured engine exists for each production database, and initialization from serialized state cannot start I/O before every gate above passes.

If the selected public SDK cannot prove those controls—or if a framework version can still autonomously mutate, retry, subscribe, or send outside the live claim—Qinao MUST NOT use `CKSyncEngine`. It uses explicitly governed `CKDatabase`/`CKOperation` requests with the same outbox/boundary identities, or leaves Cloud sync disabled. Framework convenience never weakens the authority boundary.

Only a reviewed subset may sync:

- Workspace and automation definitions;
- user-selected documents and artifacts;
- explicitly syncable App Agent state;
- deletion, revocation, policy, and share epochs;
- minimized run summaries and recovery references.

HealthKit-origin or health-derived information, R0/R1 material, credentials, Provider secrets, hidden reasoning, and data whose scope or deletion fate cannot be preserved MUST NOT enter CloudKit/iCloud.

The replication protocol must define device identity, immutable change envelopes, causal/version ordering, conflict resolution, account change, offline behavior, server-change tokens, deletion precedence, egress currentness, terminal/indeterminate recovery, and replay. CloudKit's eventual record convergence is not a linearizable automation lease, lock, or logical-fire arbiter. Until the complete protocol and W5 path pass, Cloud sync remains disabled.

### 10.10 Handoff, Watch, and multi-device surfaces

Handoff transfers a safe Workspace/Task recovery reference, not live KV or broad memory.

Watch and complication support require a restored active target, signing, lifecycle, WatchConnectivity, reachability, and privacy proof. Initial Watch functions are limited to redacted status, a bounded capture proposal, and a request to open the exact pending-action digest for review on the unlocked foreground iPhone. They cannot directly confirm, reject, activate, mutate Qinao authority, or dispatch an effect. The current archived legacy target is not production evidence.

The initial capture proposal is R1, process-local, expiry-bounded, and visibly “not saved” until the phone acknowledges canonical persistence. The Watch writes no local durable queue, App Group truth, or Qinao state. It may use only an immediate reachable WatchConnectivity message; background/durable `transferUserInfo`, application-context, file-transfer, or equivalent queued delivery is forbidden in this initial profile. When the phone is reachable, the Watch sends a minimized typed request binding a unique capture-request identity, exact Workspace/App-Agent target, scope, expiry, and last-observed deletion/revocation epochs. The phone treats it as untrusted ingress, reopens the current epochs, rejects stale or replayed requests, deduplicates repeated delivery, and alone runs the normal capture-draft `L13 prepare → K3 invisible stage → L14/K4 seal → K3 activation` path. The Watch receives only a bounded accepted/denied/status receipt. If the phone is unreachable or the request expires, the proposal is not recoverable and the UI directs the user to continue on iPhone. A durable offline Watch queue is a future separately owned and reviewed capability with explicit deletion, replay, reachability, and recovery semantics.

Any future Watch-side confirmation is a separate reviewed capability class, not an extension of the initial surface. It must independently prove wrist/device authentication, lock-state and user-presence semantics, offline/replay behavior, exact target and pending-action digest binding, a narrowly enumerated low-risk ceiling, and a fresh Qinao authorization path. Until that proof passes, all confirmation remains on the main-app path in Section 10.2.

### 10.11 Background execution

The existing BGTask bridge remains the only Apple background scheduling adapter. `BGAppRefreshTask`/`BGProcessingTask` opportunities may support bounded prefetch, index maintenance, checkpoint/compaction preparation, and eligible local maintenance.

The current bridge also contains a continued-processing path. `BGContinuedProcessingTask` is restricted to a foreground user-initiated operation that the system may start immediately when possible, queue, cancel, expire, or terminate. It is not a recurrence wake, exact schedule, guaranteed start, or correctness boundary. The existing source comment that describes it as “GUARANTEED-start” is inaccurate doctrine and MUST be corrected and regression-frozen before this path is reused.

Absence, denial, expiration, or late execution of any background task cannot make state incorrect. Expiration requests cooperative checkpoint/cancellation. A requested-time/best-effort reminder uses notifications and, where justified, a governed remote service; Qinao never calls that exact execution or invents a keepalive loop.

### 10.12 Apple security primitives

The design reuses:

- Keychain for secrets and Provider credentials;
- CryptoKit and the existing canonical/signature paths;
- Secure Enclave only where the exact supported key/algorithm and custody evidence exist;
- LocalAuthentication for policy-selected high-risk confirmation;
- Data Protection classes by sensitivity;
- App Groups only for minimized extension snapshots.

Every entitlement, purpose string, App Group, iCloud container, extension point, background identifier, and privacy manifest entry is in the capability ledger and CI/release closure. Simulator success is not entitlement or device-lifecycle proof.

### 10.13 Platform evidence

The Apple integration design is grounded in:

- <https://developer.apple.com/documentation/appintents>;
- <https://developer.apple.com/documentation/appintents/appintent/allowedexecutiontargets>;
- <https://developer.apple.com/documentation/updates/appintents>;
- <https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities>;
- <https://developer.apple.com/documentation/backgroundtasks/refreshing-and-maintaining-your-app-using-background-tasks>;
- <https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask>;
- <https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/queue>;
- <https://developer.apple.com/documentation/usernotifications>;
- <https://developer.apple.com/documentation/cloudkit>;
- <https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5>;
- <https://developer.apple.com/documentation/cloudkit/cksyncengineconfiguration/automaticallysync>;
- <https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/subscriptionid>;
- <https://developer.apple.com/documentation/cloudkit/cksyncengineconfiguration/stateserialization>;
- <https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/database>;
- <https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui>;
- <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>;
- <https://developer.apple.com/documentation/healthkit/protecting-user-privacy>;
- <https://developer.apple.com/app-store/review/guidelines/>.

Documentation evidence informs the design but does not replace compilation, entitlement, signing, install, runtime, fault, privacy, or App Review eligibility evidence.
Where Apple marks an iOS 27-era API as beta or otherwise subject to change, its spelling, availability, execution behavior, and entitlement posture remain provisional until the final selected SDK compiles and the real signed target passes the capability ledger. A beta documentation statement never creates production authority.

## 11. Exact Placement in the Existing Architecture

### 11.1 Fourteen Semantic LayerCores

| Layer | Dual-Space/automation responsibility | Explicit non-responsibility |
|---|---|---|
| **L1 Wick Life** | Turn/run life, phase and resource requirements, automation budget semantics | Thermal/memory mechanism, schedule truth, prompt interpretation |
| **L2 Brain Tissue** | Model capability requirement, Qwen/AFM/API execution-plan decision, neural result interpretation | Model bytes, KV ownership, silent Provider identity changes |
| **L3 Folded Lung** | Unique context admission, budget allocation, state compilation, binding and fingerprint | Retrieval truth, second context compiler, direct Provider or file I/O |
| **L4 World Prior** | Time-qualified world/domain claims for news, market, calendar, and other tasks | Timeless treatment of stale data, final ranking |
| **L5 Host Constitution** | User preference, companion expression, consent, retention, disclosure, notification, and automation policy | External effect, hardware scheduling, state mutation |
| **L6 Situation** | Normalized user/Apple/API/automation intent, current task frame, risk hints | Final risk permit, authoritative evidence selection |
| **L7 Mirror Blade / Grounding** | State requirements, physical prefilter requirements, hard eligibility, conflict, coverage, diversity, State Market | L8 storage, silent conflict resolution, model-label authority |
| **L8 Hippocampal Memory** | Snapshot-bound SQL/metadata, exact/FTS/BM25, dense, temporal/episode, entity/relation candidates and Space projections | Final eligibility, answer truth, second event or analytics store |
| **L9 Kunlun / Dream** | Main/Sub/automation candidate portfolio, alternatives, counterfactuals, selection | Verification, effect, commit, unbounded self-dialogue |
| **L10 Tribunal** | Grounding, constraint, extraction, output, convergence, automation result, and claim-support verification | Risk permit, state commit, self-certifying model output |
| **L11 Risk** | Privacy, disclosure, confirmation, final risk, Provider/API/Apple-data egress eligibility | Effect execution, weakening L14 |
| **L12 Soft Hand** | Response spool, UI, notification, Siri, Widget, Control, and companion-expression projection | Letting provisional output drive state/effects, bypassing L10 |
| **L13 Evolution** | Memory, Self, automation, skill, learning, reconciliation, and next-version proposals | Same-turn self-modification, activation |
| **L14 Sovereign** | Input/run admission, exact authorization, revocation, adoption/effect/publication seal | Model execution, scheduling, answer generation, direct effect |

### 11.2 Ten observable supersteps

The product may present ten understandable runtime phases:

1. Input Admission;
2. Situation Understanding;
3. State Requirement Planning;
4. Multi-lane Retrieval;
5. Eligibility, Market, Grounding, and Conflict;
6. Context Compilation;
7. Prefill and Decode;
8. Verification;
9. Response or Effect Release;
10. State Commit or Learning Candidate.

These are observability groupings, not a second layer identity. A pure superstep may fuse compatible computation only under the canonical rules and still emits one artifact/subreceipt per affected L1-L14 semantic owner.

### 11.3 Original pipeline terminology

The approved mapping is:

- Input Event/Input Normalizer → Adapter/IO before L6;
- Intent Router → L6;
- risk hint → L6, final risk/authorization → L11/L14;
- State Requirement Planner → L7;
- multi-lane retrieval → L8;
- Eligibility Gate, State Market, conflict/coverage → L7, with L10 verification;
- Context Budget Allocator and State Compiler → two phases of the one L3 compiler;
- Prefill/Decode Router → L2 decision and K2 mechanism;
- Output Verifier → L10;
- final-response projection → L12;
- Tool Runtime → L10/L11 verification and risk, L13 prepare, K3 EventLog/outbox, L14/K4 authorization, then the canonical K3/K4/Zone-C boundary protocol;
- State Commit Gate → for runtime state, L13 proposal/read-set, K3 invisible stage, L14/K4 terminal authorization/seal, then K3 activation; an effect first completes its receipt/reconciliation branch;
- StateLake append/update → K3 mechanism.

There is no semantic L15 after commit.

### 11.4 Four Physical Kernels

- **K1 Lease & Life** owns thermal/power/memory observations, process-wide MemoryLedger, resource reservation, heavy-owner admission, cancellation, and checkpoint signals.
- **K2 Neural Organ** owns Provider-independent orchestration, model/runtime package leases, state/cache admission, prefill/decode supervision, and Provider gateway mechanism.
- **K3 State & Evolution** owns the one SemanticStateLake storage/index path, EventLog, Artifact storage references, active-version/run rows, outbox, invisible staging, projector cursors, deletion epochs, and evolution graph under mapped contracts.
- **K4 Sovereign Microkernel** owns key manifests, issuance/reserve/claim/use, nonce/replay defense, signature, anchor, and helper-private audit persistence.

Zone-C Effect Broker remains Adapter/IO infrastructure, not K5.

### 11.5 Four bounded ControlRings

- **Omega Resource** may request defer, pause, eviction, checkpoint, or compatible remand from resource receipts.
- **Omega Grounding** may request bounded extra retrieval, partial join, or requirements remand from coverage/conflict/freshness receipts.
- **Omega Deliberation** may request bounded candidate revision, Sub Agent branch, critique, or counterexample search.
- **Omega Effect/Evolution** may request query, reconcile, compensate, quarantine, or next-version activation.

Each ring has exact budget, deadline, repeated-state detection, progress witness, and terminal receipt. A ring owns no truth, state, authorization, schedule, effect, or budget replenishment.

### 11.6 Seven orthogonal planes

- Semantic Authority contains L1-L14.
- Kernel Ownership contains K1-K4.
- Execution DAG contains Work Space and Automation WorkUnits/Attempts.
- ControlRing contains bounded receipt-driven remands.
- Data Plane contains events, artifacts, snapshots, indexes, logs, and ledgers.
- Adapter/IO contains Apple, Provider, storage, network, and Zone-C bridges.
- Observe/Replay contains Space projections, analytics, causal traces, certification, and deterministic replay.

Work Space, Automation Space, App Agent, swarm, learning, and Apple ecosystem integration do not add planes.

## 12. Failure, Safety, and Recovery Matrix

| Failure | Required behavior |
|---|---|
| App or process killed | Reopen durable WorkUnit/Attempt/checkpoint; revalidate policy and context; do not rely on live Session/KV |
| Session switched or closed | Keep durable work under its exact Workspace/App-Agent ownership; UI selection cannot retarget it |
| Model unavailable | Follow only a pre-certified fallback before allocation or create a new authorized Attempt; never silently change identity |
| API/network timeout after possible send | Mark sent-or-unknown and reconcile/query; no blind resend |
| Apple effect result unknown | Preserve indeterminate receipt, query when supported, request user/operator resolution |
| BGTask denied/expired | Checkpoint/cancel cooperatively; resume from another legitimate wake; correctness unchanged |
| Duplicate trigger | Return prior disposition or coalesce according to the bound policy |
| Cross-device concurrent edit | Deterministic version/CAS conflict; no last-writer-wins on authority, permission, or deletion |
| Deletion during run | Advance deletion fence, stop new reads/disclosures, cancel or quarantine affected branches, rescan |
| Consent or capability revoked | Currentness check fails before materialization/effect/commit; staged candidate cannot activate |
| Prompt injection in external data | Treat as inert data, quarantine or minimize, never grant capability |
| Skill candidate requests new capability | Stop at awaiting approval; new capability has its own exact grant and version |
| Analytics/index unavailable | Report unavailable/partial, never “no data” or inferred absence |
| Small model grounding uncertain | Return unknown; cannot override deterministic facts or hard eligibility |
| User correction conflicts with memory | Preserve correction/supersession chain and material conflict until verified |
| Cloud replica is stale | Deletion/revocation/current policy epochs win; old bytes cannot become current |

## 13. Security and Privacy Invariants

1. Disclosure is not authorization.
2. Read capability is not run or mutation capability.
3. Known identity is not access.
4. One App Agent cannot mutate another App Agent's private state.
5. A derivative remains tainted by its source scope and privacy class.
6. A model never owns state, permission, memory, Self, schedule, effect, or release.
7. A Provider cannot widen its data because it is more capable or remote.
8. Tool and Apple-framework outputs are evidence, not instructions.
9. Exact user deletion and consent withdrawal override the 72-hour minimum.
10. Audit, grant, deletion, permission, and effect-control events are non-learnable.
11. UI, metrics, logs, crash reports, export bundles, and caches are not learning bypasses.
12. No user-visible “complete Apple integration” claim precedes actual target, entitlement, signing, install, runtime, and privacy evidence.
13. No general user surveillance or private API is permitted.
14. No irreversible or indeterminate effect is automatically replayed.

## 14. Prohibited New Wheels

Controlled convergence MUST reject:

- a second EventLog, control WAL, integrity chain, or event sequence;
- `AutomationDB`, `AutomationManager`, `AutomationScheduler`, `AutomationRegistry`, or separate workflow engine;
- `LearningStore`, `TrainingPool`, mutable dataset truth, or exporter-owned egress journal;
- a second SemanticStateLake, snapshot ledger, watermark truth, or retrieval engine;
- a second Context Compiler, State Compiler, Context Manager, or Tool Catalog authority;
- a second consent, retention, deletion, permission, or data-cleaning manager;
- a fifth Physical Kernel or ControlRing;
- an Apple ingress adapter or read gateway that mutates EventKit, HealthKit, HomeKit, network, or tool state; any Apple mutation outside the broker-authorized `ZoneCAppleEffectExecutor`; or CloudKit transport used as an effect/authority shortcut;
- a Widget/App Group replica of raw K3, memory, or App Agent Self;
- dynamically downloaded executable skill code;
- an Agent-owned scheduler, graph topology, mutable Self, or direct state writer;
- ambient sharing of private data, KV, hidden reasoning, or raw store ports;
- a performance promise that turns cold-40/sustained-30 research targets into unconditional completion gates.

## 15. Controlled-Document Reconciliation

No standalone Automation implementation plan or Apple implementation plan may compete with the convergence master. After written review of this record, adopted changes are assigned to the seven controlled documents and the separate Owner Ledger as follows:

| Controlled artifact / authority input | Required reconciliation |
|---|---|
| Canonical 2026-07-14 architecture | Space projection classification, 72-hour retention semantics, Automation/Apple placement, exact 14/4/4/7 mapping, non-rebuild invariants |
| Convergence master | Capability-ledger rows, wave dependencies, entry/exit gates, K4/Effect-Broker/entitlement prerequisites, final certification |
| Contracts plan | Low-entropy refs and immutable payload shapes only after reuse/E/A/M classification; fixtures and compatibility |
| Silicon plan | Model capability profiles, context geometry, local/API execution, caching/prefill/decode/MTP evidence, resource accounting |
| Runtime/replay plan | Automation Task Graph/run lifecycle, trigger idempotency, checkpoints, interruption/recovery, projection/replay |
| Semantic StateLake/context plan | Interaction envelope, scope-first lanes, Space projections, analytics projections, exact context compilation |
| Sovereign release/effects plan | Authorized inspection membrane, disclosure, Apple/API egress, confirmation, K4 use, Zone-C effect, deletion and reconciliation |
| Owner Ledger | Existing-owner extension/adaptation rows and path allowlists; no count change by prose |

The master remains the only wave-order and completion authority. Domain plans own their mapped task detail. This record owns rationale only.

## 16. Implementation Preconditions

Implementation is blocked until:

1. this design record receives written review;
2. every adopted candidate label receives reuse/E/A/M classification and exact owner;
3. controlled documents are atomically reconciled without contradictory symbols or counts;
4. every authority-introducing `M` production candidate uses the Owner Ledger CreateGate with a non-empty current candidate manifest; every `E/A` change uses its separate non-empty current ExtensionGate manifest; every schema/current/backward/future fixture uses its own non-empty governed fixture set; none of the three classes substitutes for another;
5. the checker and its complete test suite run in CI;
6. W0/W1 in-flight changes are reconciled without overwriting or bypassing their receipts;
7. K4 platform/process/entitlement feasibility is proven before extension-dependent security claims;
8. W5 Effect Broker exists before any Apple/API external write;
9. durable encrypted content, content-free EventLog migration, selective erasure/checkpoint semantics, descendant fencing, and honest unresolved deletion terminals receive the required operator/security disposition;
10. the recurrence evaluator, logical-fire cursor CAS, L14 admission, and wake-adapter mapping have one approved owner path; until then scheduled execution is disabled;
11. every App Intent has an explicit execution-target/mode/authentication/permit matrix, and every Apple target and entitlement has exact build/sign/install/lifecycle evidence;
12. the continued-processing guarantee doctrine is corrected and frozen before reuse;
13. HealthKit/general-learning/API/iCloud hard exclusions and framework-specific unknown-read semantics are certified;
14. remote scheduling and CloudKit replication have independent fault and deletion proofs;
15. no task filter, path glob, or negative scan can pass vacuously.

## 17. Verification Strategy

### 17.1 Gate construction rules

Every gate:

- asserts each anchored path exists before scanning it;
- fails on tool error separately from “no match”;
- rejects zero matched tests for a required filter;
- uses a non-empty current CreateGate manifest for `M`, a separate non-empty current ExtensionGate manifest for `E/A`, and a separate non-empty governed fixture set for schema/shape compatibility;
- proves both positive and negative behavior;
- runs in CI with its own tests;
- records the exact command, source tree, tool version, result, and receipt.

`rg -L` is not used as “files without match.” Missing files, renamed targets, empty globs, and zero-test Swift filters are explicit failures.

### 17.2 Static architecture gates

- exactly fourteen canonical semantic layer identities;
- exactly four kernel identities;
- exactly four ring identities;
- exactly seven plane identities;
- no new production authority owner without a reviewed non-empty gate;
- no second scheduler/store/writer/compiler/event log;
- no Apple ingress/read adapter mutation and no Apple effect call outside the sole broker-authorized Zone-C executor path;
- no `CKSyncEngine` for a public database, with `automaticallySync == true`, nil/unverified `subscriptionID`, adapter-private state serialization, or delegate batch lacking an exact live outbox/permit/boundary binding;
- no Stage 4 projection target calling `UNUserNotificationCenter.add`, registering or sending APNs work, or otherwise scheduling a real notification;
- no extension target below iOS 27;
- no raw content in EventLog payloads;
- no cross-App-Agent private read, write, train, query, retrieve, model-select, cache-reuse, export, or cutover path without its exact separate grant;
- no HealthKit-origin or health-derived data in general learning, general analytics, general API Providers, or CloudKit/iCloud;
- no AnalyticsDB or learning-export bypass.

### 17.3 Contract tests

- Work Space and Automation Space projections rebuild from the same authoritative snapshot;
- inspection permits list/get/status/receipt and reject run/edit/delete/re-share;
- ownership modes do not follow ambient Session selection;
- stale policy/deletion/revocation/share epochs fail before and after materialization;
- an AI-authored Automation recipe cannot win the active-version CAS before fixtures, zero-effect shadow, approval, K3 stage, L14/K4 seal, and K3 activation;
- an AI-authored skill/prompt/schema/package cannot use runtime-state activation and becomes referenceable only after runtime certification and production cutover;
- every pre-approval fixture/dry-run/shadow proves zero Zone-C dispatch, zero real Apple/network mutation, and zero production-state mutation;
- version/operational invalidation atomically replaces or clears the active reference, disables or quarantines operation, fences the logical-fire cursor, advances the invalidation epoch, covers every nonterminal Attempt, and never exposes `enabled` with a non-approved version;
- an already allocated, executing, waiting, or checkpointed Attempt with a stale invalidation epoch fails before materialization, Provider claim, publication, effect, and commit; quarantine/revocation cancels a proven pre-boundary Attempt and reconciles a possibly crossed boundary;
- rejected, quarantined, superseded, retiring, and retired immutable versions cannot be edited or moved backward; remediation creates a new version identity;
- the run reducer accepts only the Section 4.7 state set; `observed → denied` is terminal, context compilation is a bound Artifact/subreceipt, `cancelRequested` either closes as `cancelled` or enters reconciliation when a boundary cannot be disproven, and a successor starts as a separate Attempt only after the current Attempt terminates;
- trigger duplicates return the same disposition;
- time-triggered execution remains disabled until the recurrence evaluator, K3 logical-fire CAS, L14 admission, and wake-adapter mapping pass;
- V1 rejects fire claims outside the bound execution device/authority domain; concurrent offline devices cannot each obtain an execution right, and multi-device active execution remains disabled without a proven linearizable lease/arbiter;
- time-zone, daylight-saving, travel, shutdown, and missed-run policies are deterministic;
- overlap policies enforce their exact bounds;
- raw UI signals never enter EventLog; edit/navigation coalescing, caps, idempotency, and critical-event non-dropping match the exact normalization profile;
- R2 starts from the committed R2 admission, enforces exactly 72 hours under clock rollback/reboot, has a mandatory maximum, and still yields to all four early-erasure overrides;
- retention extension/quarantine cannot become indefinite;
- R0 secrets never reach durable learning content;
- governance/audit/projection events cannot recursively create experience envelopes;
- a causal/OPE envelope without a pre-exposure action set, behavior policy, propensity/deterministic marker, outcome window, and correlation classes is rejected;
- current/day/week/month views are projections, not separate stores;
- model/user profiles are rebuildable and non-authoritative.

### 17.4 Fault and recovery tests

Inject failure before and after:

- trigger acceptance;
- K3 run allocation;
- invalidation-epoch advance while the Attempt is allocated, executing, waiting, or checkpointed and immediately before each materialization/Provider/publication/effect/commit boundary;
- context compilation;
- Provider allocation, claim, handoff, and observation;
- K3/K4 egress prepare/anchor/arm;
- Zone-C dispatch and acknowledgement;
- checkpoint store/reopen;
- automation version stage/activation;
- deletion epoch advance, synchronous descendant fencing, every local purge owner, trained derivative, external-copy response, rescan, and each honest deletion terminal;
- Cloud replication send/receive/conflict, `CKSyncEngine` delegate batch, permit expiry, cancellation, retry, state-update persistence, and crash/reopen;
- BGTask expiration;
- extension process termination.

Every case ends in one legal terminal or typed indeterminate state with no duplicate effect, state activation, publication, or Provider call.

### 17.5 Agent and learning tests

- one Session has exactly one selected App Agent and logical Main;
- Sub Agents receive role-minimal Context Capsules;
- hidden reasoning/KV never crosses Agent or Provider identity;
- source authority beats majority vote;
- injection and self-contamination examples quarantine;
- model output alone cannot become memory, Self, reward, or dataset truth;
- explicit corrections preserve provenance and supersession;
- engagement, dependence, silence, and emotional capture cannot enter reward;
- an A→B read share does not authorize B dataset inclusion, embedding/cache retrieval, adapter/model selection, export, or cutover;
- derived grants equal the intersection of all source grants and cannot be widened by derivation;
- deleting App Agent A fences all A-derived candidates without deleting independent Host-shared or App Agent B data;
- deletion removes, fences, rolls back, or honestly blocks every affected dataset/adaptation lineage;
- RSI terminates under repeated-state, no-progress, branch, token, time, and effect bounds.

### 17.6 Apple integration tests

For each enabled surface:

- App Intent parses to the same canonical Input Event/entry envelope as the app;
- every Intent's actual `allowedExecutionTargets`, mode, locked-device behavior, authentication, and Qinao permit match the Section 10.2 matrix; no platform default silently widens them;
- Widget/Control/Live Activity receives only the approved minimized snapshot;
- extension process cannot access raw state ports;
- ordinary explicit permission denial/revocation fails closed;
- HealthKit empty reads remain `unknown/no-authorized-samples`, limited-history reads obey the earliest-authorized date, and write/share denial fails closed without inferring a hidden read decision;
- sensitive/destructive actions require the exact confirmation path;
- BGTask denial/expiration leaves correctness unchanged, and continued processing is foreground-user-initiated, cancellable/terminable, and never a schedule or guaranteed start;
- notification delivery/presentation is not inferred from local scheduling, APNs acceptance, or a later Notification Center snapshot;
- Stage 4 notification work is limited to in-app/extension preview, permission UX, and read-only status projection; it performs zero local scheduling, APNs token egress, or remote send;
- real local notification scheduling and APNs remote send remain disabled until the W5 canonical publication/effect mouth is present, with exactly one broker-authorized mutation caller and reconciliation path;
- Handoff and Watch transfer only bounded references; initial Watch actions cannot confirm/reject a pending action or dispatch an effect and may only request foreground iPhone review;
- Watch capture remains an unsaved process-local R1 proposal until the iPhone canonical path acknowledges it; stale, duplicate, offline, expiry, deletion, and revocation cases cannot create a direct Watch mutation or durable hidden queue;
- Cloud stale replicas cannot revive deleted or revoked data;
- CloudKit rejects HealthKit-origin/health-derived data and every other forbidden class;
- every CloudKit save/delete/share/subscription mutation traverses L11/L13/K3/L14/K4/Zone-C with disclosure, currentness, outbox, single-winner dispatch, and reconciliation evidence; callbacks and sync engines cannot write Qinao state directly;
- `CKSyncEngine` initializes only for private/shared scope, with manual sync, one exact broker-provisioned subscription, K3-held state serialization, and one production engine per database; public-scope, default-auto, recoverable retry, permit-expiry, batch, cancellation, crash/reopen, and callback tests prove fail-closed behavior and no autonomous second boundary;
- a `CKSyncEngine` delegate returns no send batch without reopening the exact live claim/currentness/invalidation tuple, fetches only through `AppleReadGateway`, and converts uncertain cancellation or retry into reconciliation;
- only the broker-authorized `ZoneCAppleEffectExecutor` calls mutation APIs; ingress and read adapters cannot;
- signing, entitlements, purpose strings, App Groups, containers, and privacy manifests match Release closure.

### 17.7 Performance and quality

Measure:

- added median/p95/p99 latency per semantic layer and superstep;
- Space projection rebuild latency;
- trigger-to-admission latency;
- context compile and tokenize-once cost;
- inspection first-result latency;
- Apple Intent and extension cold-start cost;
- energy, memory, and thermal impact;
- accepted decode and end-to-end task quality by exact profile;
- recovery time and duplicate-prevention evidence.

Cold 40 tok/s and sustained 30 tok/s remain measured target gates under their declared protocol, not unconditional structural completion criteria.

## 18. Staged Product Delivery

The dependency-safe product order is:

1. reconcile contracts, owners, projections, retention semantics, and gates;
2. ship Work/Automation Space read-only projections and user controls;
3. ship App Intents for open/deep-link/continuation-request/capture/status/next-question, with no execution continuation before Stage 6;
4. ship safe Widget/Control and notification previews/projections: in-app or extension preview, permission UX, and read-only status only; do not call `UNUserNotificationCenter.add`, egress an APNs token, send remotely, or schedule a real notification;
5. ship governed AI-authored declarative skill candidates and local dry-run/shadow;
6. ship Task Graph automation execution and interruption recovery after its runtime owner exists;
7. ship effectful Calendar/Reminders, real local-notification scheduling, APNs remote send, and equivalent connectors only after W5 supplies the canonical publication/effect mouth and its unique broker-authorized caller;
8. ship CloudKit replication only after cross-device deletion/conflict proof;
9. restore Watch/Handoff/Live Activity only with real targets and lifecycle evidence;
10. enable HealthKit/Home/high-sensitivity domains only through separate product/security review;
11. enable future API models and remote scheduling without changing authority or privacy contracts;
12. enable governed learning/adaptation only after dataset, deletion, certification, canary, and rollback closure.

Each stage can remain useful if every later stage is disabled.

## 19. Exit Criteria

This design is ready to enter implementation planning only when:

- its approved decisions are represented once without contradicting the controlled set;
- no required responsibility is owned by a projection, adapter, model, or UI;
- all candidate values have exact owner/classification;
- Apple capability claims distinguish current, approved-missing, deferred, and proven;
- the 72-hour rule and early-erasure overrides have executable semantics;
- Work/Automation read and mutation paths are separated;
- App Agent/Main/Sub/Provider identities and scopes are non-interchangeable;
- automation, learning, effects, and recovery share the one Task/Event/Artifact/receipt path;
- no gate is vacuous;
- the convergence master remains the unique completion authority.
