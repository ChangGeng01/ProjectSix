# Qinao Dual-Space Automation Controlled Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically reconcile the approved Work Space, Automation Space,
fine-grained interaction evidence, 72-hour governed retention, independent
Agent contexts, interruption recovery, model/user adaptation, and Apple
ecosystem boundaries into Qinao's existing seven controlled documents and
Owner Ledger, with non-vacuous gates and implementation-ready domain-task
payloads, without creating a second store, scheduler, event log, compiler,
Agent authority, wave plan, or completion authority.

**Architecture:** The existing 2026-07-15 convergence master remains the only
W0-W6 order and completion authority. Only Tasks 0-2 of this document are
executable: C0 selects an externally admitted committed predecessor; W0 makes
admission non-vacuous and atomically writes the adopted delta into the seven
controlled documents and Owner Ledger. Sections 3-10 are exact transplant
payloads for those controlled documents, not independently executable tasks.
Once Task 2 passes, this file is a non-authoritative traceability annex and all
production work executes only from the updated master/domain plans. Work Space
and Automation Space remain product projections over the same
Event/Artifact/Task/receipt authorities.

**Tech Stack:** Swift 6, Swift Package Manager, SQLite, Rust, Core AI, Foundation Models, App Intents, BackgroundTasks, WidgetKit where a real target exists, CloudKit only behind the manual governed profile, Python 3 standard-library gate tooling, Git candidate-tree admission, Xcode 27, iOS 27.

## Global Constraints

- This plan does not create an eighth controlled architecture document, a sixth domain plan, `W7`, or a parallel completion authority.
- The exact controlled set remains seven documents:
  1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`
  2. `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`
  3. `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`
  4. `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`
  5. `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`
  6. `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`
  7. `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`
- The approved decision source is `docs/superpowers/specs/2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md` at commit `c4e6cf23f`, SHA-256 `50338e28492cd8dc7a81f28a07a871d70f02020af56549cb1384b9431bd5fcf6`. Execution must rederive and pin its full commit, tree, blob, byte length, and SHA-256 before use.
- `docs/superpowers/specs/2026-07-26-qinao-mobius-sovereign-swarm-recovery-design.md` in the separate clean candidate is an unadmitted design input, not an authority. Only decisions independently present in the approved 2026-07-29 source or atomically admitted into the controlled set may be used.
- `generated_from_head = 6703354b6` in the Owner Ledger is the historical Create audit baseline; the W0 hazard baseline is `43060b810`; the approved design's observed repository snapshot is `d36707346`. They are different facts and must never be refreshed or conflated.
- The implementation base is not this authoring worktree and is not whichever dirty W1 tree looks newest. Task 0 must select one exact externally admitted predecessor and preserve every unselected byte.
- Owner Ledger cardinality remains `29 owners / 14 M allowlist entries / 14 create permissions / 7 controlled documents`. This delta requires no new `M` owner.
- If a planned `M` owner such as `runtime.semantic-dag` or `state.snapshot-contracts` is absent on the selected predecessor, its first production wire must use that owner's already-approved, non-empty CreateGate candidate in the same atomic wave. If it already exists, this delta uses a non-empty ExtensionGate or AdapterGate slice. A prose claim, zero-candidate run, or stale historical receipt never substitutes.
- Exactly fourteen semantic LayerCores, ten observable supersteps, four
  Physical Kernels, four bounded ControlRings, and seven orthogonal planes
  remain canonical. The ten supersteps are observability groupings, not layer
  identities. The Möbius loop is causal evidence flow through the canonical
  structure, not a fifth ring, eighth plane, scheduler, bus, or authority.
  The supersteps are exactly: Input Admission; Situation Understanding; State
  Requirement Planning; Multi-lane Retrieval; Eligibility, Market, Grounding,
  and Conflict; Context Compilation; Prefill and Decode; Verification;
  Response or Effect Release; State Commit or Learning Candidate.
- `BASSQLiteEventLogStorage` remains the sole production K3 writer/transaction owner. `BASArtifactSQLiteStore` remains the Artifact Mesh storage path. `BASContextCompiler` remains the sole context compiler. `AppleBGTaskSchedulerBridge` remains the sole Apple background adapter.
- `BASK3ControlNucleusStorage` remains the one class-bound K3 storage seam.
  Automation, retention, projector-cursor, and checkpoint methods extend that
  seam; no independently injectable automation/checkpoint state port is
  permitted. Production composition must inject the exact same
  `BASSQLiteEventLogStorage` actor instance through every K3 facet.
- Artifact encryption and erasure decisions remain owned by
  `state.memory-content-erasure`. Keychain and CryptoKit are custody and AEAD
  mechanisms only; they do not become policy, state, or deletion authorities.
- No production `AutomationManager`, `AutomationStore`, `AutomationScheduler`, `AutomationEventLog`, `SkillRegistry`, `RunRegistry`, `AutomationAgent`, `AnalyticsDB`, Agent registry, mutable cross-context KV, or second recovery store may be introduced.
- Models and Agents emit proposals only. They cannot mutate authoritative state, grant themselves capabilities, activate a definition, publish a final response, execute an effect, or promote their output into memory, Self, reward, or dataset truth.
- One Session selects exactly one App Agent and one logical Main Agent. Sub Agents and Providers receive independent, purpose-limited Context Capsules. Raw hidden reasoning, Provider-private KV, mutable prompt state, and secrets never cross identities.
- Recovery reuses the one `ContextContinuityManifest`, its nested
  `WorkUnitRecoveryCursor`, the existing L11/L14 `ContinuationPolicy`, and the
  existing `RecoveryDisposition` matrix. Automation may reference these
  values but may not declare a second recovery cursor, policy, manager, or
  mutable boundary snapshot.
- EventLog is content-free: bounded structured facts, blinded digests, references, epochs, causal slots, and receipts only. Raw text/audio/image/file/tool/model bytes may enter only the mapped encrypted content-addressed Artifact path after the relevant decision gate passes.
- R2 is exactly a minimum encrypted 72-hour eligible-learning window, never an authorization to learn. Deletion, consent withdrawal, secret detection, and privacy/security reclassification override the minimum immediately. Every R2 admission has a finite purpose-specific maximum.
- Scheduled execution remains disabled until the pure recurrence evaluator, one K3 logical-fire cursor CAS, ordinary L14 admission, and device-affinity fencing all have admitted owners and passing fault tests. CloudKit replication is never a scheduling lease or lock.
- Apple ingress and read adapters are non-authoritative. Every semantic
  external Apple mutation, including CloudKit save/delete/subscription
  operations, must traverse the one K3/K4/publication/Zone-C mouth.
  BackgroundTasks registration and scheduling-opportunity lifecycle, Apple
  reads, and foreground permission UI are separately classified call graphs;
  none may mutate Qinao semantic state. Unsupported public APIs remain
  unavailable.
- The current repository has no formal production App/Extension/Watch target. `BehavioralAISubstrate/DeviceTestApp` is a lab host only. This plan may prove contracts and lab integration there; it must not claim App Store readiness or enable a production Apple surface without a separately admitted real target and release evidence.
- Cold 40 tok/s and sustained 30 tok/s are measured optimization targets under a declared device/model/thermal protocol, not unconditional structural completion gates.
- Every task follows RED -> verify meaningful failure -> GREEN -> focused verification -> cumulative verification -> commit. A test filter that discovers or executes zero tests is a failure.
- Every negative source gate first proves its exact input paths and scan set exist and are non-empty, then distinguishes scanner status `0` (match), `1` (no match), and `2+` (tool/gate error).
- Every wave bundle binds a reviewed exact path-list blob. The staged index
  diff must equal that list in both directions. Workers stage with
  `git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w1-paths.txt`
  (using the corresponding exact file for that slice); broad directory staging is
  forbidden.
- No step may edit an unrelated dirty path, import a directory wholesale, regenerate reviewed evidence, or overwrite another worktree.

---

## Execution Status and Stop Conditions

This convergence plan is **BLOCKED before Task 0D** until an operator/reviewer
selects and signs the exact committed predecessor. Planning, publication, and
read-only verification are allowed before that point; production edits are
not. Tasks 3-10 cannot be executed from this file under any status.

The following capabilities remain disabled until their named stop condition clears:

| Capability | Stop condition |
|---|---|
| Durable R2 raw-content capture | encrypted Artifact content, erasure-domain custody, EventLog migration, WAL/checkpoint/backup deletion closure, and operator/security disposition pass |
| General scheduled execution | recurrence owner map, logical-fire CAS, L14 admission, device-affinity fencing, duplicate/offline/DST tests pass |
| Real local notifications or APNs | W5 publication/effect mouth and sole broker-authorized Apple mutation caller pass |
| Calendar/Reminders writes | W5 effect permit, exact confirmation, Zone-C dispatch, and reconciliation pass |
| CloudKit | private/shared manual profile, exact subscription, K3 state serialization, deletion/conflict/recovery proof pass |
| Watch/Handoff/Live Activity | real signed targets and lifecycle evidence exist; initial Watch profile stays read/capture/request-review only |
| HealthKit/HomeKit/high-sensitivity profiles | separate product, privacy, security, legal/entitlement review passes |
| Multi-device active automation execution | a separately approved linearizable lease/idempotency authority exists |

---

## Repository Reality and Reuse Map

### Existing authorities to extend

| Responsibility | Exact incumbent |
|---|---|
| Event values/storage protocol | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift` |
| Sole production K3/EventLog writer | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` |
| Artifact identity/store port | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift` |
| Artifact SQLite store/schema | `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`; `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql` |
| Content/atom migration inputs | `BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift`; `BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift` |
| Deletion/retraction inputs | `BehavioralAISubstrate/Sources/BASMemory/BASMemoryForgetCascadeRunner.swift`; `BASRetractionFurnace.swift`; `BASHostConstitutionDeletionManifestStore.swift`; SQL `015` and `022` |
| Exact/FTS/dense/vector lanes | `BASMemoryUsageTracker+ReplayAuditFTS.swift`; `BASRAGRetriever.swift`; `BASVectorIndex.swift`; `BASSQLiteVectorIndexStorage.swift`; `BASRoutedVectorIndexStorage.swift`; `BASVectorReranker.swift` |
| Rust ranking primitive | `BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/fuser.rs` |
| Sole context compiler | `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift` |
| Duplicate context path to retire | `BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift` |
| Existing Agent-role vocabulary | `BehavioralAISubstrate/Sources/BASMemory/BASAgentFabricEnums.swift` |
| Host/runtime callers | `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`; `BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift` |
| Projection mechanisms | `BehavioralAISubstrate/Sources/BASHostKit/BASEventLogProjectors.swift`; `BehavioralAISubstrate/Sources/BASMemory/ProjectionCore.swift` |
| Task/workflow migration inputs | `BehavioralAISubstrate/Sources/BASOrchestration/OrchestrationCore.swift`; `BASAppleLifecycleKit/AppleTaskGraphLifecycleCore.swift`; `AppleEvolutionCheckpointWriterCore.swift` |
| Apple entry-envelope path | `BehavioralAISubstrate/Sources/BASOrchestration/OrchestrationCore.swift` and its incumbent `BASEntryIntentEnvelope`/`BASEntryIntentBridgeBuilder` declarations |
| Sole Apple background adapter | `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleBGTaskSchedulerBridge.swift` |
| Duplicate background adapter to retire | `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoBGMaintenanceBridge.swift` |
| Apple lab host | `BehavioralAISubstrate/DeviceTestApp/project.yml`; `Resources/Info.plist`; `Resources/BASDeviceTestApp.entitlements` |
| Model capability/invocation | `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift`; `BASLLMInvocationContract.swift` |
| Core AI/AFM mechanisms | `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift`; `AppleFoundationOrganAdapter.swift`; `AppleFoundationOrganAdapter+Streaming.swift` |
| Existing BG bridge tests | `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleBGTaskSchedulerBridgeTests.swift` |

### Planned owner files reused after admission

These files are already named by the controlled plan set. Their absence on a selected predecessor means “run the original owner's CreateGate,” not “invent a substitute”:

- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`
- `BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift`
- `BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift`
- `BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift`
- `BehavioralAISubstrate/Sources/BASMemory/SQL/028_response_publication.sql`
- `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift`
- `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift`
- `BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql`
- `BehavioralAISubstrate/Sources/BASSovereignClient/BASSovereignEnhancedSecurityClient.swift`

### New extension/adaptation files fixed by this plan

Subject to Task 2's atomic controlled-document mapping:

- `BehavioralAISubstrate/Sources/BASMemory/BASSpaceProjectionCore.swift`
- `BehavioralAISubstrate/Sources/BASMemory/BASInteractionExperienceCore.swift`
- `BehavioralAISubstrate/Sources/BASOrchestration/BASInteractionSignalNormalizer.swift`
- `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceIngressAdapter.swift`
- `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceSnapshot.swift`
- `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleReadGateway.swift`
- `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleCloudKitManualProfile.swift`
- `BehavioralAISubstrate/Sources/BASEffectBroker/ZoneCAppleEffectExecutor.swift`

These are components inside existing owners. They do not create new authority cards.

**Test-path convention:** Unless a task gives a different full path, every bare
Swift filename in a `Create tests` list is joined to the exact directory
`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/`. Device lab tests use
the separately stated
`BehavioralAISubstrate/DeviceTestApp/Tests/AppleSystemSurfaces/` prefix. This is
a path abbreviation only; gate manifests contain full normalized paths and
reject an absent file or zero discovered suite.

---

## Required Placement in the Controlled Master

The following rows are transplant destinations. They do not create executable
waves or exits in this annex.

| Existing master wave | Delta to transplant into its owning domain tasks | Existing master exit extended with |
|---|---|---|
| C0/W0 prelude | select/pin one predecessor and approved design source | signed non-self-referential admission receipt; clean isolated worktree |
| W0 | gate/CI/floor repair; seven-document and Owner Ledger reconciliation | non-vacuous Create/Extension/Fixture checks; no production behavior |
| W1 | immutable Space, automation, interaction, retention, Agent/context, Apple boundary values | fixtures and single-declaration tests; zero writer/effect behavior |
| W2 | Artifact content/erasure closure; one K3 schema/transaction path; 72-hour disposition | crash/reopen, CAS, deletion, invalidation, no-second-writer proof |
| W3 | lane/snapshot/Space/analytics/read projections; exact context compilation; shadow | deterministic replay/rebuild; no authoritative projection write |
| W4 | local/API model profile, execution binding, context geometry, resource accounting | model identity isolation and deterministic fallback receipts |
| W5 | attenuated inspection, publication, K4 use, sole Zone-C Apple mutation | one mutation caller; uncertain boundary reconciles |
| W6 | automation Task Graph execution, checkpoint/recovery, Apple lab surfaces, replay/certification/cutover | disabled-by-default feature matrix and full evidence closure |

---

## Task 0: Select and Pin the Only Convergence Predecessor

**Files:**

- Read: the current repository and all candidate worktree metadata.
- Create externally, never commit: `qinao-dual-space-source-selection-v1.json` with mode `0600`.
- Create after admission: one isolated `codex/` execution worktree.
- Do not modify production or controlled documents in this task.

**Interfaces:**

`QinaoDualSpaceSourceSelectionV1` must bind:

```text
schemaVersion
repositoryIdentity
selectedHEAD
selectedTree
approvedDesign = {path, commit, tree, blob, byteLength, sha256}
candidateComparisons[]
reviewerPrincipal
reviewerRole
issuedAt
expiresAt
nonce
signatureAlgorithm
signature
```

Canonical signed bytes are RFC 8785 JSON with the `signature` member omitted,
UTF-8 encoded, then SHA-256 digested and Ed25519-signed. The one external
admission trust root maps key fingerprints to disjoint
`source-selector`, `root-admission-signer`,
`design-edge-admission-signer`, `wave-bundle-reviewer`,
`wave-admission-signer`, `k4-evidence-signer`, and
`runtime-chain-signer` roles. A trust root contains public verification
material only and is never passed as a signing credential.

The independently reviewed external verifier checks repository identity,
approved-design tuple, reviewer role, signature, expiry, nonce uniqueness,
and selected commit/tree equality. It then asks only the protected
`root-admission-signer` provider to sign
`QinaoRootAdmissionReceiptV1`, which binds the selection blob, trust-root and
external-verifier executable digests, verified selector signer/role,
verified HEAD/tree, verification time, outcome, root signer/role, issue/expiry,
nonce, algorithm, and signature. This signed root receipt—not an unsigned
verification JSON—is the predecessor-chain root.

The record may select a reviewed committed W1 candidate, the current committed
convergence line, or another exact committed predecessor. It may not select
“latest,” a worktree directory, an index tree, an uncommitted aggregate, or a
mixed path set. If reviewed path-level inputs must be combined, an external
admission transaction first creates and reviews one new commit; only that
commit/tree may then be signed.

- [ ] **Step 0A: Recompute design and repository identities**

  Run:

  ```bash
  git rev-parse HEAD HEAD^{tree}
  git rev-parse c4e6cf23f^{commit} c4e6cf23f^{tree}
  DESIGN_BLOB=$(git rev-parse 'c4e6cf23f:docs/superpowers/specs/2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md')
  git cat-file -s "$DESIGN_BLOB"
  git cat-file blob "$DESIGN_BLOB" | shasum -a 256
  git status --porcelain=v2
  ```

  Expected: the design digest is exactly the Global Constraints value; any mismatch blocks.

- [ ] **Step 0B: Compare candidate trees without importing them**

  Record exact commit/tree and read-only path-status summaries for the current
  convergence branch, the reviewed W1 candidate, and any operator-supplied
  alternative. Dirty bytes are review context only and cannot be selected.
  Explicitly distinguish:

  - selected committed bytes;
  - staged bytes;
  - unstaged bytes;
  - untracked bytes;
  - candidate-only deleted/replaced documents;
  - changes to the seven controlled documents, Owner Ledger, checker, CI, and production source.

  Do not resolve conflicts by timestamps or filenames. A candidate with
  selected staged/unstaged/untracked bytes must first be externally committed
  and reviewed as a new candidate before Step 0C.

- [ ] **Step 0C: Obtain independent selection**

  The operator/reviewer signs exactly one
  `QinaoDualSpaceSourceSelectionV1`. The execution environment supplies the
  independently reviewed `qinao-external-admission-verifier`, its expected
  SHA-256, public trust root, protected role-scoped signing provider, signed
  selection path, and external mode-`0600` root-receipt path. Verifier,
  provider, selection, trust root, and receipt paths are outside the
  repository; the receipt is distinct and initially absent:

  ```bash
  test -x "$QINAO_EXTERNAL_ADMISSION_VERIFIER"
  test "$(shasum -a 256 "$QINAO_EXTERNAL_ADMISSION_VERIFIER" | cut -d ' ' -f 1)" = \
    "$QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256"
  test -x "$QINAO_ROOT_ADMISSION_SIGNING_PROVIDER"
  test "$(shasum -a 256 "$QINAO_ROOT_ADMISSION_SIGNING_PROVIDER" | cut -d ' ' -f 1)" = \
    "$QINAO_ROOT_ADMISSION_SIGNING_PROVIDER_SHA256"
  test ! -e "$QINAO_ROOT_ADMISSION_RECEIPT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" verify-source-selection \
    --selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --repository "$PWD" \
    --signing-provider "$QINAO_ROOT_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_ROOT_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_ROOT_ADMISSION_RECEIPT"
  ```

  If any input/verifier/receipt is missing or verification does not return
  `accepted`, report `BLOCKED_SOURCE_SELECTION` and stop. Do not convert this
  into a coder choice.

- [ ] **Step 0D: Create the isolated execution branch/worktree**

  From the selected commit only. Read the verified values from the external
  signed root receipt, compare them with both the signed selection and Git,
  then create the
  worktree:

  ```bash
  test -n "$QINAO_EXECUTION_WORKTREE"
  QINAO_SELECTED_COMMIT=$(python3 -c \
    'import json,sys; print(json.load(open(sys.argv[1]))["verifiedHEAD"])' \
    "$QINAO_ROOT_ADMISSION_RECEIPT")
  QINAO_SELECTED_TREE=$(python3 -c \
    'import json,sys; print(json.load(open(sys.argv[1]))["verifiedTree"])' \
    "$QINAO_ROOT_ADMISSION_RECEIPT")
  test "$(git rev-parse "$QINAO_SELECTED_COMMIT^{commit}")" = \
    "$QINAO_SELECTED_COMMIT"
  test "$(git rev-parse "$QINAO_SELECTED_COMMIT^{tree}")" = \
    "$QINAO_SELECTED_TREE"
  git worktree add "$QINAO_EXECUTION_WORKTREE" \
    -b codex/qinao-dual-space-controlled-convergence \
    "$QINAO_SELECTED_COMMIT"
  test "$(git -C "$QINAO_EXECUTION_WORKTREE" rev-parse HEAD)" = \
    "$QINAO_SELECTED_COMMIT"
  test "$(git -C "$QINAO_EXECUTION_WORKTREE" rev-parse HEAD^{tree})" = \
    "$QINAO_SELECTED_TREE"
  git -C "$QINAO_EXECUTION_WORKTREE" status --short --branch
  test -z "$(git -C "$QINAO_EXECUTION_WORKTREE" status --porcelain)"
  ```

  Expected: clean worktree; branch base equals the signed selection.

- [ ] **Step 0E: Commit the approved design source as an admitted single-purpose edge if absent**

  If and only if the selected predecessor does not already contain the exact
  approved design blob, import that one exact file and no other
  authoring-worktree byte. Stage it, compute its candidate tree, and ask the
  same external verifier to issue a signed
  `QinaoDesignEdgeAdmissionReceiptV1` whose base tree is
  `QINAO_SELECTED_TREE` and whose only changed path/blob is the approved
  design. Its frozen schema binds repository, signed root-receipt digest,
  base/candidate trees, the single path/blob/byte-length/SHA-256 tuple,
  verifier/tool digests, outcome, signer/role, issue/expiry, nonce, algorithm,
  and signature. Only `design-edge-admission-signer` may sign it. If the
  predecessor already contains the exact blob, record `alreadyPresent`; the
  signed root admission receipt is the predecessor receipt.

- [ ] **Step 0F: Commit**

  Commit only the admitted design edge when Step 0E required it:

  ```bash
  git add docs/superpowers/specs/2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md
  QINAO_DESIGN_EDGE_TREE=$(git write-tree)
  test -x "$QINAO_DESIGN_EDGE_ADMISSION_SIGNING_PROVIDER"
  test "$(shasum -a 256 "$QINAO_DESIGN_EDGE_ADMISSION_SIGNING_PROVIDER" | cut -d ' ' -f 1)" = \
    "$QINAO_DESIGN_EDGE_ADMISSION_SIGNING_PROVIDER_SHA256"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-design-edge \
    --selection "$QINAO_SOURCE_SELECTION" \
    --root-receipt "$QINAO_ROOT_ADMISSION_RECEIPT" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_DESIGN_EDGE_TREE" \
    --signing-provider "$QINAO_DESIGN_EDGE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_DESIGN_EDGE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_DESIGN_EDGE_ADMISSION_RECEIPT"
  test "$(git write-tree)" = "$QINAO_DESIGN_EDGE_TREE"
  git diff --cached --check
  git commit -m "docs(qinao): admit dual-space automation design"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_DESIGN_EDGE_TREE"
  test -z "$(git status --porcelain)"
  ```

  No commit is created for an `alreadyPresent` outcome. The W0 gates slice
  receives `QINAO_DESIGN_EDGE_ADMISSION_RECEIPT` as its previous receipt when
  the edge was created, otherwise `QINAO_ROOT_ADMISSION_RECEIPT`.

---

## Task 1: Make W0 Gates Non-Vacuous and Continuous

**Files:**

- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Create or import only after byte review: `scripts/run_nonempty_swift_filter.py`
- Create or import only after byte review: `scripts/test_run_nonempty_swift_filter.py`
- Create or import only after byte review: `scripts/run_qinao_wave_admission.py`
- Create or import only after byte review: `scripts/test_run_qinao_wave_admission.py`
- Create or import only after byte review: `scripts/test_test_workflow_owner_ledger.py`
- Create or import only after byte review: `scripts/test_qinao_plan_remediation.py`
- Create or import only after byte review:
  `scripts/run_qinao_k4_ios27_platform_spike.py`
- Create or import only after byte review:
  `scripts/test_run_qinao_k4_ios27_platform_spike.py`
- Modify: `.github/workflows/test.yml`
- Create or import only after byte review:
  `.github/workflows/qinao-wave-admission.yml`
- Modify: `BehavioralAISubstrate/scripts/check-ios27-floor.sh`
- Modify: `BehavioralAISubstrate/scripts/build-rust-xcframework.sh`
- Modify: tests that pin the iOS floor checker on the admitted predecessor.
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w0-create-disposition.json`
  - `docs/superpowers/evidence/qinao-dual-space-w0-extension-disposition.json`
  - `docs/superpowers/evidence/qinao-dual-space-w0-adapter-disposition.json`
  - `docs/superpowers/evidence/qinao-dual-space-w0-fixture-disposition.json`
  - `docs/superpowers/evidence/qinao-dual-space-w0-gates-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w0-gates-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w0-controlled-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w0-controlled-wave-bundle.json`
- Create only when an original absent `M` owner is first wired: its already-approved non-empty CreateGate manifest; do not manufacture a dual-space `M`.

**Required CLI:**

```text
check_qinao_owner_ledger.py
  --root PATH
  --ledger PATH
  --source-selection PATH
  --trust-root PATH
  --base-tree GIT_TREE
  --candidate-tree GIT_TREE
  --wave W0_TO_W6
  --create-manifest-or-disposition PATH
  --extension-manifest-or-disposition PATH
  --adapter-manifest-or-disposition PATH
  --fixture-set-or-disposition PATH
```

Every argument is mandatory. A category with changes carries a non-empty current
manifest. A category with no changes carries a typed, signed
`notApplicable` disposition bound to the approved design, exact wave,
base tree, reviewed path/blob map, and production-diff root. It does not embed
the candidate tree that contains it. W0 changes governance/tooling
only, so its four category inputs are honest `notApplicable` records; it must
not fabricate an E/A/fixture candidate. A later first production wire under an
absent `M` carries that owner's already-approved current Create manifest;
extensions, adapters, and fixtures use their own categories.

The checker derives the production path/symbol/schema diff from the two Git
trees. For each category, the derived set and manifest set must be equal in
both directions. Omitted, extra, stale, cross-wave, wrong-base, wrong
path/blob/diff root, or wrong-class rows fail. The signed root admission
receipt binds the root commit/tree; the verified predecessor-receipt chain binds the
current base. Every wave admission receipt binds the previous admitted
receipt, all four manifest/disposition blobs, the candidate tree, tool
identities, and exact wave.

`run_qinao_wave_admission.py` never signs or admits its own candidate. Its
exact modes are:

```text
report
  --root PATH
  --bundle PATH
  --source-selection PATH
  --trust-root PATH
  --previous-receipt PATH
  --candidate-tree GIT_TREE
  [--external-prerequisite NAME=PATH]...
  --unsigned-report PATH

verify-receipt
  --root PATH
  --bundle PATH
  --source-selection PATH
  --trust-root PATH
  --previous-receipt PATH
  --candidate-tree GIT_TREE
  [--external-prerequisite NAME=PATH]...
  --receipt PATH
```

`report` writes a canonical unsigned `QinaoWaveCandidateReportV1` outside the
repository. The independently pinned external verifier's `admit-wave` command
must independently rederive the base/index/candidate tree, bundle and tool
blobs, exact path-list/diff, categories, prerequisites, and predecessor; it
does not trust the candidate report as authority. Only then may it ask the
protected `wave-admission-signer` provider for a schema-scoped signature,
assemble the signed `QinaoWaveAdmissionReceiptV1`, and write the external
mode-`0600` receipt. The repository runner's `verify-receipt` mode then
verifies the final bytes and exact candidate bindings. A trust root never
signs, and neither repository code nor ordinary PR CI receives signing
credentials.

Every signing provider exposes only its fixed schema/role operation, accepts
requests only through the pinned external verifier identity, and independently
checks the request digest/role envelope before using its protected key. It is
not a general `sign(bytes)` executable and cannot be called directly by a
candidate workflow or repository script.

```text
qinao-external-admission-verifier admit-wave
  --report PATH
  --bundle PATH
  --source-selection PATH
  --previous-receipt PATH
  --repository PATH
  --candidate-tree GIT_TREE
  --trust-root PATH
  [--external-prerequisite NAME=PATH]...
  --signing-provider PATH
  --signing-provider-sha256 HEX
  --receipt PATH
```

The bundle binds the previous receipt, base commit/tree, reviewed path-list
blob, four current category blobs, approved design blob, exact wave, and tool
blob identities. Its frozen `externalPrerequisites[]` member is a
lexicographically name-sorted array of
`{name, schema, blobDigest, requiredOutcome}`. An empty array is explicit.
Every non-empty entry is supplied as one repeatable
`--external-prerequisite NAME=PATH` argument to bundle review, `report`,
external `admit-wave`, and `verify-receipt`; duplicate names, missing or
additional arguments, and order-normalization ambiguity fail.

Before a bundle enters a path list, an independent reviewer approves its
external mode-`0600` unsigned bytes and the external verifier obtains only a
`wave-bundle-reviewer` signature. Its exact interface also accepts the same
repeatable optional prerequisite:

```text
qinao-external-admission-verifier review-wave-bundle
  --unsigned-bundle PATH
  --path-list PATH
  --source-selection PATH
  --previous-receipt PATH
  --repository PATH
  --trust-root PATH
  [--external-prerequisite NAME=PATH]...
  --signing-provider PATH
  --signing-provider-sha256 HEX
  --output PATH
```

The following is the executable empty-prerequisite case:

```bash
"$QINAO_EXTERNAL_ADMISSION_VERIFIER" review-wave-bundle \
  --unsigned-bundle "$QINAO_UNSIGNED_WAVE_BUNDLE" \
  --path-list "$QINAO_CURRENT_WAVE_PATH_LIST" \
  --source-selection "$QINAO_SOURCE_SELECTION" \
  --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
  --repository "$PWD" \
  --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
  --signing-provider "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER" \
  --signing-provider-sha256 "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER_SHA256" \
  --output "$QINAO_CURRENT_WAVE_BUNDLE"
```

The external verifier rederives every referenced blob and base before asking
the provider to sign. The output bundle never embeds its own blob or candidate
tree. `wave-bundle-reviewer` cannot sign an admission receipt, and
`wave-admission-signer` cannot sign a bundle.

External prerequisite paths are never repository paths or candidate bytes.
They must be pairwise-distinct, outside the worktree, regular files with mode
`0600`, and already exist. Before accepting their digests, every one of the
four commands opens the bytes itself and validates the declared schema,
signature, trusted role, repository identity, issue/expiry, outcome, and
schema-specific linkage. A digest claim copied into a bundle is not proof.
For `runtime-receipt-chain`, schema-specific linkage means independently
verifying the `runtime-chain-signer` signature, receipts 01 through 06 in
ordinal order, every receipt's predecessor/candidate-tree continuity, and the
chain's expected head tree. The chain embeds all six complete canonical signed
`QinaoWaveAdmissionReceiptV1` objects plus the digest of each canonical object;
a digest-only entry or an external path hidden inside the chain is invalid.
Thus every consumer can reverify all six admission signatures from the one
external chain input. The repository runner and external verifier each
perform this validation; neither trusts the other's report.

`QinaoWaveBundleV1` additionally binds `repositoryIdentity`, `waveSliceID`,
`sequenceOrdinal`, `requiredPredecessorReceiptBlob`,
`requiredPredecessorCandidateTree`, evidence-prerequisite blobs/statuses,
signer/role, issue/expiry, nonce, signature algorithm, and signature.
`QinaoWaveAdmissionReceiptV1` binds the verified
bundle/selection/trust-root/external-verifier/repository-runner tool blobs,
base commit/tree, candidate tree, production diff root, path-list root,
category roots/counts, evidence- and external-prerequisite normalized
names/schema/digests/statuses, slice/ordinal, previous receipt, outcome,
signer/role, time, nonce, and signature. Bundles require the
`wave-bundle-reviewer` role; receipts require
`wave-admission-signer`. Both use the same RFC 8785 + SHA-256 + Ed25519
convention as Task 0.

The chain is exact:

```text
signed root admission receipt.selectedTree
-> optional signed design-edge candidateTree
-> previous admission candidateTree
   == current HEAD^{tree}
   == next bundle baseTree
-> next admitted candidateTree
```

The root admission receipt anchors only the root; it is not reused as the
immediate predecessor of every later wave. Every bundle/receipt signature,
trusted role, repository, expiry, nonce, previous receipt, base tree,
candidate tree, path-list blob, category blob, evidence prerequisite, and
slice ordinal is verified. A commit is accepted only when its resulting
`HEAD^{tree}` equals the admitted candidate tree exactly.

This avoids an impossible hash cycle: committed manifests, dispositions,
path lists, and bundles bind the base plus exact intended path/blob/diff roots,
but never embed the tree that contains themselves. The repository runner
computes the unsigned candidate report from the staged index; the external
verifier independently recomputes it, obtains the role-scoped signature, and
writes the signed `QinaoWaveAdmissionReceiptV1` to the external mode-`0600`
`--receipt` path. The repository runner then verifies but cannot sign it.
Admission reports, receipts, and final receipt chains are never staged into
the tree they describe or attest. The next bundle binds the prior external
receipt blob/digest and its candidate tree.
The execution coordinator requires the unsigned-report, current-receipt, and
previous-receipt paths to be outside the repository, mode `0600`, pairwise
distinct, and (for new outputs) initially absent. Every slice receives fresh
report and receipt paths. Only after
post-commit tree equality succeeds may it promote
`QINAO_CURRENT_ADMISSION_RECEIPT` to the next slice's
`QINAO_PREVIOUS_ADMISSION_RECEIPT`; reuse or overwrite fails.

- [ ] **Step 1A: Write failing checker tests**

  Add mutation cases proving failure for:

  - missing/empty ExtensionGate manifest;
  - missing/empty AdapterGate manifest;
  - missing/empty fixture set;
  - extension to an unknown owner or path;
  - `A` adapter claiming writer/effect authority;
  - an `E/A` candidate passed only through CreateGate;
  - `M` first-wire with zero candidates;
  - stale historical receipt substituted for current extension;
  - missing anchored file or empty glob;
  - tool error represented as “no match”;
  - malformed/duplicate candidate rows;
  - production diff omitted from a manifest;
  - extra manifest row absent from the production diff;
  - stale base/path-blob roots, receipt candidate tree, or cross-wave manifest reuse;
  - root admission receipt not bound to the signed selection/base tree;
  - invalid/unknown signature, wrong role/trust root/repository, expired
    receipt, or replayed nonce;
  - repository runner attempting to sign, a trust root passed as signing
    material, wrong-role provider, blind-signing provider, changed external
    verifier digest, or an unprotected PR job requesting admission;
  - predecessor candidate tree not equal to current `HEAD^{tree}` and bundle
    base tree;
  - commit tree different from the admitted candidate tree;
  - reordered/duplicate/skipped wave-slice ordinal;
  - stale, disabled, mismatched, or unsigned required evidence prerequisite;
  - missing, in-repository, wrong-mode, duplicate-name, extra, or
    digest-mismatched external prerequisite;
  - wrong external-prerequisite schema, signer role, signature, expiry,
    outcome, receipt ordinal/continuity, or expected head tree;
  - a valid but foreign runtime chain swapped beside another valid receipt 06
    or Apple admission receipt;
  - Owner Ledger count drift;
  - a second automation store/scheduler/event log/compiler;
  - direct Apple mutation outside `ZoneCAppleEffectExecutor`.

  Run:

  ```bash
  python3 -m unittest scripts.test_check_qinao_owner_ledger
  ```

  Expected: new tests fail because the CLI and validations do not yet exist.

- [ ] **Step 1B: Implement ExtensionGate and FixtureGate in the same checker**

  Reuse the existing candidate-tree/blob reader and Swift lexical scanner. Do not create an independent authority checker. Emit counts and exact owner/path/symbol classifications in the receipt.

  Run the same unittest command; expected PASS.

- [ ] **Step 1C: Make Swift filters prove discovery and execution**

  `run_nonempty_swift_filter.py` must:

  - accept only a closed `SuiteA|SuiteB|SuiteC`-shaped alternation for this plan;
  - derive the complete expected suite set from the filter;
  - if `--require-suite` is supplied, require its set to equal the derived set;
  - run `swift test list` for the exact package;
  - require every derived suite to be listed;
  - execute the requested filter;
  - parse the result and require at least one executed test from every derived suite;
  - distinguish build failure, discovery failure, zero execution, and test failure.

  Add positive and mutation tests, then run:

  ```bash
  python3 -m unittest scripts.test_run_nonempty_swift_filter
  ```

- [ ] **Step 1D: Repair every documented negative scan**

  In the convergence master and gate scripts, replace unsafe
  `if rg FORBIDDEN_TOKEN EXACT_PATHS; then exit 1; fi` patterns with:

  1. exact path existence/non-empty assertion;
  2. an explicit scanner invocation;
  3. status classification `0/1/2+`;
  4. a positive mutation test that plants the forbidden token.

  Never use `rg -L` as “files without match.”

- [ ] **Step 1E: Close the iOS 27 floor over source, scripts, and binaries**

  Write RED tests proving the current `IPHONEOS_DEPLOYMENT_TARGET="18.0"` and vendored `LC_BUILD_VERSION minos 18.0` are detected.

  The floor gate must inspect:

  - the exact first-party shipping manifests
    `BehavioralAISubstrate/Package.swift`,
    `QinaoRuntimeSDK/Package.swift`, and `SampleHost/Package.swift`;
  - `BehavioralAISubstrate/DeviceTestApp/project.yml`;
  - build/export scripts including `BehavioralAISubstrate/scripts/build-rust-xcframework.sh`;
  - resolved Xcode build settings and each built product's `MinimumOSVersion`;
  - every vendored or freshly built `.xcframework` Mach-O slice through `otool -l`/`vtool`;
  - simulator and device archives independently.

  Vendored third-party source manifests are not rewritten to iOS 27; the gate
  verifies that each pinned dependency resolves inside the iOS 27 first-party
  host. Entitlements do not declare deployment targets and are not scanned as
  if they did.

  Rebuild the Rust XCFramework with iOS 27 minimum before replacing vendored bytes. Do not merely edit the script.

  Run:

  ```bash
  BehavioralAISubstrate/scripts/check-ios27-floor.sh
  ```

  Expected: PASS only when declarations and binary load commands are iOS 27 or higher.

- [ ] **Step 1F: Add candidate-tree wave admission**

  `run_qinao_wave_admission.py` stages no files and trusts no worktree scan. It
  consumes the signed root/previous receipt plus one current reviewed wave
  bundle, resolves the base commit/tree, accepts the candidate index/tree from
  Git, invokes the unified checker, and emits only one canonical unsigned
  candidate report. It rejects a dirty unstaged production path, index/tree
  drift, index-diff/path-list mismatch, a missing category, or a path-list/
  manifest blob not named by the bundle. `verify-receipt` checks a receipt
  issued by the external verifier; no repository code imports a private key,
  calls a generic signing primitive, or marks itself admitted.
  Report creation uses exclusive-create semantics with mode `0600`, rejects a
  repository-contained, symlink, or reused output, and fsyncs the complete
  canonical bytes before the external verifier reads them.

  Add standard-library mutation tests for every binding and set-equality rule.

- [ ] **Step 1G: Add dedicated CI admission jobs**

  Both workflows use full Git history. `test.yml` always runs the checker/unit
  suites and unsigned report path so the tools cannot disappear; it is
  verify-only and has no signing provider. `qinao-wave-admission.yml` is
  manual/protected by the `qinao-admission` environment and required
  reviewers, never runs on untrusted pull-request code, receives the pinned
  external verifier and role-scoped provider, runs the current candidate
  bundle, and never hard-codes W0 manifests for a later wave:

  ```bash
  python3 -m unittest \
    scripts.test_check_qinao_owner_ledger \
    scripts.test_run_nonempty_swift_filter \
    scripts.test_run_qinao_wave_admission \
    scripts.test_run_qinao_k4_ios27_platform_spike \
    scripts.test_qinao_plan_remediation \
    scripts.test_test_workflow_owner_ledger
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$GITHUB_WORKSPACE" \
    --bundle "$QINAO_CURRENT_WAVE_BUNDLE" \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$(git rev-parse HEAD^{tree})" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle "$QINAO_CURRENT_WAVE_BUNDLE" \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$GITHUB_WORKSPACE" \
    --candidate-tree "$(git rev-parse HEAD^{tree})" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$GITHUB_WORKSPACE" \
    --bundle "$QINAO_CURRENT_WAVE_BUNDLE" \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$(git rev-parse HEAD^{tree})" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  BehavioralAISubstrate/scripts/check-ios27-floor.sh
  ```

  `test.yml` stops after the `report` call. Only the protected workflow
  executes the external `admit-wave` and subsequent `verify-receipt` calls.
  The W0 gates and W0 controlled-document slices are admitted from the
  already-pinned external operator environment, never by the workflow bytes
  they are creating. The protected workflow becomes admission-eligible only
  after the W0 gates commit, an independent reviewer pins that committed
  workflow blob, and the external verifier checks that blob before every
  later run.

  The workflow meta-test must fail if any command, required argument, full
  history setting, ordering dependency, candidate-tree argument, post-commit
  `HEAD^{tree}` equality, clean assertion, or test module disappears. Every W1-W6
  task transplanted by Task 2 includes the same actual candidate-tree runner
  before its commit and records the resulting receipt.

- [ ] **Step 1H: Verify and commit**

  Run:

  ```bash
  python3 -m unittest \
    scripts.test_check_qinao_owner_ledger \
    scripts.test_run_nonempty_swift_filter \
    scripts.test_run_qinao_wave_admission \
    scripts.test_run_qinao_k4_ios27_platform_spike \
    scripts.test_qinao_plan_remediation \
    scripts.test_test_workflow_owner_ledger
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w0-gates-paths.txt
  QINAO_W0_CANDIDATE_TREE=$(git write-tree)
  test ! -e "$QINAO_UNSIGNED_ADMISSION_REPORT"
  test ! -e "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-gates-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W0_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-gates-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W0_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-gates-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W0_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  git diff --check
  ```

  Expected: the receipt binds the staged candidate tree and W0 bundle. Only
  after that succeeds, commit and prove the post-commit worktree is clean:

  ```bash
  test "$(git write-tree)" = "$QINAO_W0_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "build(qinao): make authority and floor gates non-vacuous"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W0_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Task 2: Atomically Reconcile the Seven Controlled Documents and Owner Ledger

**Files:**

- Modify exactly the seven controlled documents listed in Global Constraints.
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Regenerate only as a labeled non-authoritative mirror after the controlled
  source changes:
  `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md`
- Regenerate only as a labeled non-authoritative mirror after the controlled
  source changes:
  `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`
- Treat as immutable decision input: `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`
- Modify the mandatory `scripts/test_qinao_plan_remediation.py` imported in
  Task 1.
- Add/update other semantic plan tests already owned by the convergence toolchain.
- Create/update the four W0 signed dispositions and
  `docs/superpowers/evidence/qinao-dual-space-w0-controlled-wave-bundle.json`
  from Task 1.
- Create evidence only, not a new authority:
  `docs/superpowers/evidence/qinao-k4-ios27-platform-spike.json`.

**Owner mapping to freeze:**

| Candidate | Class | Existing owner |
|---|---|---|
| Work/Automation Space projection values | E | `state.snapshot-contracts` |
| Automation definition/version/DAG values | E or original first-wire M | `runtime.semantic-dag` |
| trigger/run/cursor/invalidation K3 rows | E | `state.k3-control-nucleus` |
| Automation run/recovery projection | E | `runtime.replay-manifest` |
| attenuated Automation inspection | E | `sovereign.k4-durable-lifecycle` using the incumbent capability grant |
| interaction/experience/retention values | E | `state.snapshot-contracts`; erasure behavior under `state.memory-content-erasure` |
| canonical model capability/profile values | E | `model.manifest-invocation` in `BASOrgan`; memory owns only a read projection of its reference |
| user experience profile projection | E | `state.snapshot-contracts` |
| interaction normalization profile/policy | E | L5 Host Constitution under `semantics.layercell`; L6 normalizer consumes it |
| Apple surface ingress | A | `semantics.layercell` adapter; all policy values remain in L5 Host Constitution |
| Apple read gateway | A | `state.snapshot-contracts` read/lane ports |
| Apple mutation executor | A | `effect.zone-c-saga` |
| Automation runtime methods | E | `runtime.semantic-executor` in the incumbent `BASTurnRuntimeEngine` |

`QinaoK4IOS27PlatformSpikeV1` is a signed evidence schema, not an owner. Its
canonical fields are: schema/repository/design identities; Xcode/SDK/OS build;
signed physical-device profile digest; exact framework/API and availability;
target/extension/process model; signing and entitlement inventory; SQLite
open/WAL/file-protection constraints; transport/XPC feasibility; launch,
interruption, termination, reconnect, and key-access observations; test/result
bundle digests; exact supported profile digest; status
`supportedExactProfile|disabledMissingTarget|disabledMissingEntitlement|
disabledMissingDeviceProof`; signer/role; issue/expiry; nonce; signature.
It uses the common RFC 8785/Ed25519 envelope. W5's bundle must bind this exact
blob, `supportedExactProfile`, profile digest, and unexpired signature; the
wave runner mutation-tests stale, disabled, wrong-profile, unsigned, or
wrong-device evidence.

**Concrete production path/symbol mapping:**

| Path | Symbol or facet | Owner/class |
|---|---|---|
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift` | Space, retention request/receipt, K3 automation/checkpoint request/receipt values | `state.snapshot-contracts` E, or its original approved M first wire |
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift` | automation definition/DAG/run/reducer/recurrence/checkpoint values | `runtime.semantic-dag` E, or its original approved M first wire |
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | extensions of `BASK3ControlNucleusStorage`; sole transaction implementation | `state.k3-control-nucleus` E |
| `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift` and `SQL/025_artifact_erasure_domains_v1.sql` | encrypted content body and erasure-domain persistence | `state.memory-content-erasure` E |
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift` | `BASErasureDomainKeyCustody`, `BASArtifactContentAEAD`, and their request/authorization/receipt values | `state.memory-content-erasure` E |
| `BehavioralAISubstrate/Sources/BASMemory/BASArtifactErasureDomainCrypto.swift` | sole `BASKeychainErasureDomainKeyCustody` and `BASCryptoKitArtifactContentAEAD` production mechanisms | `state.memory-content-erasure` A |
| `BehavioralAISubstrate/Sources/BASMemory/HostConstitutionCore.swift` | `BASInteractionNormalizationProfile` and policy decisions | `semantics.layercell` E |
| `BehavioralAISubstrate/Sources/BASOrchestration/BASInteractionSignalNormalizer.swift` | bounded L6 normalization adapter, no policy thresholds | `semantics.layercell` A |
| `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift` | canonical model/material/profile facts | `model.manifest-invocation` E |
| `BehavioralAISubstrate/Sources/BASMemory/BASSpaceProjectionCore.swift` | Work/Automation/model/user read projections | `state.snapshot-contracts` E |
| `BehavioralAISubstrate/Sources/BASMemory/BASInteractionExperienceCore.swift` | eligibility/lineage projection over admitted evidence | `state.snapshot-contracts` E |
| `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift` | sole `BASContextCompiler` packing/budget/render/fingerprint behavior | `state.context-compiler` E |
| `BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift`, `ScopedContextCore.swift`, and `BASHostKit/EBrainTurnContextCompiler.swift` | input-only delegates to the sole compiler | `state.context-compiler` A |
| `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift` and `BASExecutionPlanElector.swift` | admitted execution plan and pre-Attempt election | `execution.plan-provider-router` E |
| `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift`, `AppleFoundationOrganAdapter.swift`, and `AppleFoundationOrganAdapter+Streaming.swift` | Core AI/AFM Provider mechanisms | `provider.package-boundary` A |
| `BehavioralAISubstrate/Sources/BASRuntimeCore/BASAutomationRecurrenceEvaluator.swift` | pure proposal-only recurrence evaluation | `runtime.semantic-dag` E |
| `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift` | governed automation operation seam and behavior | `runtime.semantic-executor` E |
| `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceIngressAdapter.swift` | platform-to-entry adapter only | `semantics.layercell` A |
| `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleReadGateway.swift` | authorized Apple read adapter only | `state.snapshot-contracts` A |
| `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceSnapshot.swift` and `AppleCloudKitManualProfile.swift` | minimized surface snapshot/manual-profile contract only | `platform.ios27` A |
| `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleBGTaskSchedulerBridge.swift` | sole system scheduling-opportunity adapter | `platform.ios27` E |
| `BehavioralAISubstrate/Sources/BASEffectBroker/ZoneCAppleEffectExecutor.swift` | semantic external Apple mutations | `effect.zone-c-saga` A |
| the eight exact DeviceTest files `QinaoAppEntities.swift`, `QinaoNavigationIntents.swift`, `QinaoCaptureDraftIntent.swift`, `QinaoReadOnlyIntents.swift`, `QinaoAppShortcuts.swift`, `QinaoIntentDependencies.swift`, `QinaoLabNavigationRouter.swift`, and `QinaoLabSpaceViews.swift` under `DeviceTestApp/Sources/App/AppleSystemSurfaces/` | lab host integration only; no production authority | `platform.ios27` A |

- [ ] **Step 2A: Freeze candidate-label to concrete-symbol mappings**

  The approved design's candidate labels map exactly once:

  | Design candidate | Concrete Swift symbol |
  |---|---|
  | `AutomationSpaceProjection` | `BASAutomationSpaceProjection` |
  | `InteractionExperienceEnvelope` | `BASInteractionExperienceEnvelope` |
  | `ModelRuntimeProfileProjection` | `BASModelRuntimeProfileProjection` |
  | `UserExperienceProfileProjection` | `BASUserExperienceProfileProjection` |
  | stable Workspace identity | reuse the already planned `ContextWorkspaceRef` |
  | visible long-lived conversation/workspace | reuse the already planned `ConversationWorkspace` projection semantics |

  No unprefixed mirror type, `BASWorkspaceRef`, or second Workspace identity is permitted.

- [ ] **Step 2B: Write semantic RED tests before prose edits**

  Tests must fail unless all seven documents:

  - name one Work Space and one Automation Space as projections;
  - forbid the duplicate store/scheduler/event-log/compiler/Agent classes;
  - preserve 14/4/4/7;
  - use W0-W6 only;
  - map every new candidate to the table above;
  - distinguish R2 minimum from learning authorization;
  - keep recurrence, real notification, CloudKit, Watch mutation, and HealthKit-general paths disabled by default;
  - bind the Apple mutation path to one Zone-C caller;
  - require independent App/Main/Sub/Provider contexts and zero raw CoT;
  - require non-empty Create/Extension/Fixture gates and non-zero test execution.

  Also add regressions for the previously verified document defects:

  - whole-sentence recovery wording replacement, not the corrupt substring replacement;
  - Swift-aware model-name scanning, not bare comment/string regex;
  - one agreed Provider executor name and guarantee across master/K3 addendum;
  - no phantom per-step materialization field in `BASSiliconExecutionBinding`;
  - no dangling `materializationContractArtifactID`;
  - canonical RSI terminal-set spelling;
  - `BASContextCompiler` explicitly owns “State Compiler” and “Context Budget Allocator” prose;
  - `knownIssueSetDigest`, not `knownIssueSet`;
  - no nonexistent test target/path/filter/glob;
  - no unconditional 40/30 completion promise.
  - K3 corruption detection/reopen/recovery has a mapped domain-owner incident
    path and cannot fall through to a shared recovery registry;
  - W5 K4-dependent work is blocked by an exact iOS 27 platform/process/
    entitlement feasibility receipt rather than a prose claim.
  - the Sovereign facade-freeze suite lives in
    `Tests/QinaoRuntimeSDKTests/`, is discovered nonzero, and W0 fixtures call
    only APIs present at the W0 predecessor;
  - migration fixtures preserve the incumbent exact `migrationTestIDs` and
    `governedObjects` cardinalities; a `1.0.0`-only type gets no fictional
    backward fixture;
  - the LayerCore scan derives and asserts a nonempty real file set rather than
    relying on a permanently empty `*LayerCore.swift` glob;
  - the K3 RED test contains no lane-adapter/`failedResult` fragment from a
    later task;
  - W4 defines/adopts `HardCapDerivationSource` before any consumer, and no W4
    exit requires W5 publication-spool behavior;
  - publication-recovery tests use an injected same-publication crash seam,
    not two unrelated external `runTurn` calls;
  - every referenced repository path is resolved and asserted from the root,
    including `BehavioralAISubstrate/Tools/mamba3_statelake.py`;
  - `build-rust-xcframework.sh`, its comment, package floors, and every binary
    slice all agree on iOS 27.

- [ ] **Step 2C: Reconcile the canonical architecture**

  Update the exact sections:

  - §4.3-4.5 repository/reuse/Create doctrine;
  - §7-11 placement and 14/4/4/7;
  - §14.4 Workspace/Task Graph;
  - §15.8 and §16 projections/context;
  - §27 and §30 Apple/Zone-C;
  - §32 privacy/replay;
  - §35-39 dispositions/acceptance;
  - §42 validation.

  Rationale remains in the approved 2026-07-29 record; the canonical file carries only adopted architecture and invariants.

- [ ] **Step 2D: Reconcile master and five domain plans**

  Place the delta exactly as follows:

  - master: Global Constraints, capability ledger, owner graph, W0-W6 matrix, migration, acceptance, verification;
  - contracts: iOS 27 floor, unified gates, Space/Automation refs, inspection/Apple permits, fixtures;
  - StateLake/context: immutable envelopes, K3 rows, R2/erasure, interaction lanes, independent contexts, projections/replay;
  - silicon: Rust floor, model profiles/bindings, background/resource accounting, Provider/context isolation;
  - sovereign/effects: direct-mutation freeze, surface publication, grants, activation/invalidation, sole Apple Zone-C executor, release evidence;
  - runtime/replay: automation DAG/lifecycle, observation/replay, zero-effect dry-run, Apple capability ledger, disabled-by-default cutover.

  Put the K4 platform spike in the W0 prerequisite section, before any
  K4-dependent production slice. On the installed iOS 27 SDK and a signed
  physical-device profile, record the exact available framework/API,
  extension/process model, entitlements, SQLite/open-file constraints, XPC or
  other transport feasibility, signing identity class, and lifecycle
  behavior. The signed result is `supportedExactProfile` or a typed
  `disabledMissingTarget`, `disabledMissingEntitlement`, or
  `disabledMissingDeviceProof`; it may not infer an “Enhanced Security helper
  extension” from desktop/macOS concepts. Unsupported means the affected W5
  profile remains disabled—never that an in-process substitute silently
  becomes K4.

  After XcodeBuildMCP verifies the signed physical-device defaults, collect and
  sign the spike. `$QINAO_K4_SPIKE_UNSIGNED_OUTPUT` is a fresh external
  mode-`0600` path; only the minimized signed evidence file enters Git:

  ```bash
  python3 scripts/run_qinao_k4_ios27_platform_spike.py \
    --root "$PWD" \
    --device-profile "$QINAO_IOS27_DEVICE_PROFILE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --xcode-developer-dir "$(xcode-select -p)" \
    --unsigned-output "$QINAO_K4_SPIKE_UNSIGNED_OUTPUT"
  test -x "$QINAO_K4_EVIDENCE_SIGNING_PROVIDER"
  test "$(shasum -a 256 "$QINAO_K4_EVIDENCE_SIGNING_PROVIDER" | cut -d ' ' -f 1)" = \
    "$QINAO_K4_EVIDENCE_SIGNING_PROVIDER_SHA256"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" sign-evidence \
    --schema QinaoK4IOS27PlatformSpikeV1 \
    --input "$QINAO_K4_SPIKE_UNSIGNED_OUTPUT" \
    --repository "$PWD" \
    --device-profile "$QINAO_IOS27_DEVICE_PROFILE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_K4_EVIDENCE_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_K4_EVIDENCE_SIGNING_PROVIDER_SHA256" \
    --output docs/superpowers/evidence/qinao-k4-ios27-platform-spike.json
  python3 scripts/run_qinao_k4_ios27_platform_spike.py \
    --verify docs/superpowers/evidence/qinao-k4-ios27-platform-spike.json \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT"
  ```

  The collector invokes only documented installed-SDK inspection and the
  explicit device probe matrix; it cannot infer entitlement or process
  support from symbol presence. The external verifier independently reopens
  the device profile and evidence rather than blindly signing the collector
  output; the provider key must carry only `k4-evidence-signer`. Its mutation
  tests cover simulator input,
  unsigned/wrong-device evidence, stale expiry, missing lifecycle observation,
  impossible entitlement claims, and altered result-bundle digest.

  Do not copy whole sections across plans; each responsibility has one owner and cross-references the others.

- [ ] **Step 2E: Reconcile the K3 and recovery addenda**

  Resolve the executor-name conflict in favor of the exact
  `BASProviderAttemptExecutor.executeAtMostOnce` symbol. The seven controlled
  documents, checker terms, tests, and call-graph gates change atomically.
  Exactly-once terminal outcome semantics come from idempotency plus
  reconciliation, not from a misleading `executeExactlyOnce` method name.

  Keep materialization in the existing materialized-request/execution-plan artifact path. Do not add a fifth reference to the four-reference `BASProviderStepTemplate` binding. Remove or define every dangling materialization artifact reference through the existing template mechanism.

  Recovery authority remains mapped to domain owners; no shared recovery registry/store is introduced.

  In the same documentation commit, deterministically regenerate both addenda
  from the already updated controlled sources and label their first section
  `NON-AUTHORITATIVE GENERATED MIRROR`. They are never edited as normative
  inputs. A parity test compares their generated bytes and fails if either
  mirror contains a production requirement, symbol shape, owner, wave, or exit
  criterion absent from the seven controlled documents.

- [ ] **Step 2F: Update Owner Ledger without count drift**

  Add exact `E/A` path and symbol allowlists, wave, fixtures, dependencies, forbidden-authority notes, and exit gates for this delta. Preserve historical provenance fields.

  If an original planned `M` owner is absent on the admitted predecessor, bind its original non-empty Create candidate and this extension in the same wave manifest; do not reclassify the extension as a new `M`.

  Add slice-scoped total-coverage tests. For each admitted slice `s`, derive
  `Δs` from its exact base tree → candidate tree production
  path/symbol/schema diff. Derive `Ls` only from Owner Ledger delta rows whose
  `admissionRefs` bind this approved-design digest and that exact
  `waveSliceID`, plus that slice's retirement rows. Require `Δs == Ls` in both
  directions. Historical unchanged M/E/A rows are excluded from this delta
  equation and instead pass the independent full-Ledger cardinality,
  schema/signature, path-existence, owner-uniqueness, and no-drift checks.

  W0 validates the complete planned owner map and zero production delta; it
  does not pretend future W1-W6 path lists already exist. Each later wave
  proves its actual `Δs == Ls` during admission, and final W6 certification
  compares the accumulated union of all admitted `Δs` values with the
  accumulated design-bound Ledger/retirement rows. Every modified incumbent
  path references its machine-checkable existing owner row; every
  removed/unreachable authority has one retirement row. Unmapped, multiply
  mapped, wildcard-only, prose-only, stale, or design-unbound delta rows fail.

- [ ] **Step 2G: Run all W0 gates**

  Run:

  ```bash
  python3 -m unittest \
    scripts.test_check_qinao_owner_ledger \
    scripts.test_qinao_plan_remediation \
    scripts.test_run_nonempty_swift_filter \
    scripts.test_run_qinao_wave_admission \
    scripts.test_run_qinao_k4_ios27_platform_spike \
    scripts.test_test_workflow_owner_ledger
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w0-controlled-paths.txt
  QINAO_W0_CONTROLLED_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-controlled-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W0_CONTROLLED_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-controlled-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W0_CONTROLLED_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w0-controlled-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W0_CONTROLLED_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  git diff --check
  ```

  Expected: owner count unchanged, the production diff is empty, all four
  signed dispositions are current and their path/blob roots equal the staged
  candidate; no production source edits exist, and the external admission
  receipt binds its tree and names the exact seven
  controlled-document/ledger delta.

- [ ] **Step 2H: Commit the atomic controlled convergence**

  ```bash
  test "$(git write-tree)" = "$QINAO_W0_CONTROLLED_TREE"
  git diff --cached --check
  git commit -m "docs(qinao): converge dual-space automation authority"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W0_CONTROLLED_TREE"
  test -z "$(git status --porcelain)"
  ```

  This commit must contain the entire controlled-document/ledger/gate-manifest reconciliation and no production Swift/SQL/Rust change.
  After this commit, Sections 3-10 below are a read-only transplant annex.
  Their checklists, manifests, commands, receipts, and exit assertions must
  exist in the owning seven documents before any production edit begins.

---

## Controlled Domain-Plan Payload W1: Freeze Dual-Space, Automation, Interaction, and Context Values

**Files:**

- Create through the original owner admission if absent, otherwise modify:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift`
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASAgentFabricEnums.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/HostConstitutionCore.swift`
- Modify only to freeze typed, content-free event payload/profile values:
  `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Create tests:
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASDualSpaceContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationDefinitionContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASInteractionEvidenceContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASRetentionContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticTurnDAGTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAgentContextIsolationContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASDualSpaceAntiDuplicationTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationLifecycleValidatorTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationRunContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationRecurrenceContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationCheckpointContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASAutomationInspectionContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASInteractionNormalizationProfileTests.swift`
- Add W1 non-empty Extension/Fixture manifests under `docs/superpowers/evidence/` using the exact names assigned by the reconciled master.
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w1-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w1-wave-bundle.json`

**Interfaces to freeze:**

```swift
public enum BASSpaceKind: String, Codable, Sendable, CaseIterable {
    case work
    case automation
}

public struct BASAutomationRef: Codable, Sendable, Hashable {
    public let workspaceRef: ContextWorkspaceRef
    public let automationID: String
}

public struct BASAutomationVersionRef: Codable, Sendable, Hashable {
    public let automationRef: BASAutomationRef
    public let versionID: String
    public let definitionArtifactID: BASArtifactID
    public let definitionDigest: String
}

public enum BASAutomationOwnershipMode: Codable, Sendable, Equatable {
    case hostNeutral
    case appAgentBound(appAgentScopeID: String)
    case explicitShare(shareArtifactID: BASArtifactID)
}

public enum BASAutomationDefinitionState: String, Codable, Sendable, CaseIterable {
    case draft, candidate, validating, rejected, quarantined, shadow
    case awaitingApproval, approved, superseded, retiring, retired
}

public enum BASAutomationOperationalState: String, Codable, Sendable, CaseIterable {
    case disabled, enabled, paused, quarantined, retiring, retired
}

public struct BASAutomationPositiveBackfillCount:
    Codable, Sendable, Equatable {
    public let rawValue: UInt16
    public init(validating rawValue: UInt16) throws
}

public struct BASAutomationPositiveConcurrency:
    Codable, Sendable, Equatable {
    public let rawValue: UInt8
    public init(validating rawValue: UInt8) throws
}

public enum BASAutomationMissedRunPolicy: Codable, Sendable, Equatable {
    case skip
    case runLatest
    case boundedBackfill(maximumCount: BASAutomationPositiveBackfillCount)
}

public enum BASAutomationOverlapPolicy: Codable, Sendable, Equatable {
    case skipWhileRunning
    case queueOne
    case boundedParallel(maximumConcurrentRuns: BASAutomationPositiveConcurrency)
}

public enum BASAutomationDefinitionLifecycle {
    public static func validateTransition(
        from: BASAutomationDefinitionState?,
        to: BASAutomationDefinitionState
    ) throws
}

public enum BASAutomationOperationalLifecycle {
    public static func validateTransition(
        from: BASAutomationOperationalState?,
        to: BASAutomationOperationalState
    ) throws
}

public struct BASAutomationDefinitionVersion: Codable, Sendable, Equatable {
    public let ref: BASAutomationVersionRef
    public let ownershipMode: BASAutomationOwnershipMode
    public let purposeID: String
    public let triggerArtifactID: BASArtifactID
    public let taskGraphTemplateArtifactID: BASArtifactID
    public let capabilityRequirementDigest: String
    public let dataScopeDigest: String
    public let effectRequirementDigest: String
    public let budgetDigest: String
    public let retentionPolicyDigest: String
    public let policyDigest: String
    public let fixtureSetDigest: String
}

public enum BASInteractionEvidenceClass: String, Codable, Sendable, CaseIterable {
    case experienceSource
    case derivedOutcomeFeature
    case governanceControl
    case auditProof
    case projectionOnly
}

public enum BASRetentionClass: String, Codable, Sendable, CaseIterable {
    case neverPersist
    case ephemeral
    case eligibleLearning72Hours
    case userDurable
    case auditProof
}

public struct BASRetentionAdmissionRequest: Codable, Sendable, Equatable {
    public let envelope: BASInteractionExperienceEnvelope
    public let idempotencyKey: String
    public let expectedHead: BASEventLogHead
    public let requestedAtTrustedWallMs: Int64
    public let sameBootMonotonicStartNs: UInt64?
    public let requestedMaximumRetainUntilMs: Int64
    public let consentEpoch: UInt64
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let erasureDomainID: String
}

public struct BASRetentionAdmissionReceipt: Codable, Sendable, Equatable {
    public let retentionAdmissionID: String
    public let committedHead: BASEventLogHead
    public let trustedWallStartMs: Int64
    public let sameBootMonotonicStartNs: UInt64?
    public let minimumRetainUntilMs: Int64
    public let maximumRetainUntilMs: Int64
    public let purposeID: String
    public let consentEpoch: UInt64
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let erasureDomainID: String
}

public struct BASInteractionExperienceEnvelope: Codable, Sendable, Equatable {
    public let eventID: String
    public let evidenceClass: BASInteractionEvidenceClass
    public let workspaceRef: ContextWorkspaceRef
    public let appAgentScopeID: String?
    public let causalParentEventID: String?
    public let contentArtifactID: BASArtifactID?
    public let contentDigest: String?
    public let retentionClass: BASRetentionClass
    public let retentionAdmissionID: String?
    public let purposeID: String
    public let provenanceDigest: String
    public let integrityDigest: String
}

public enum BASAutomationRunState: String, Codable, Sendable, CaseIterable {
    case observed, admitted, denied, allocated, executing
    case waitingForConfirmation, waitingForNetwork, waitingForModel
    case waitingForTool, checkpointed, cancelRequested, reconciling, degraded
    case succeeded, failed, cancelled, quarantined, indeterminate
}

public struct BASAutomationRunReduction: Sendable, Equatable {
    public let nextState: BASAutomationRunState
    public let canonicalEventPayloadBytes: Data
}

public enum BASAutomationRunReducer {
    public static func validate(
        current: BASAutomationRunState,
        transition: BASAutomationRunTransition
    ) throws

    public static func apply(
        current: BASAutomationRunState,
        transition: BASAutomationRunTransition
    ) throws -> BASAutomationRunReduction
}

// Freeze exact Codable shapes and coding keys in W1:
// BASAutomationRunRequest, BASAutomationResumeRequest,
// BASAutomationRunOutcome, BASAutomationRunEvent,
// BASAutomationRunTransition, BASAutomationRecurrenceRequest,
// BASAutomationLogicalFireProposal, BASAutomationCheckpointPayload,
// BASAutomationInspectionRequest,
// BASAutomationInspectionOperation, BASExperienceExposureContract,
// BASAutomationCheckpointInstallRequest/Receipt,
// BASAutomationCheckpointReopenRequest/Receipt,
// BASRetentionDispositionRequest/Receipt,
// BASProjectorCursorAdvanceRequest/Receipt,
// BASProjectorCursorSnapshotRequest/Snapshot.
```

The W1 fixtures freeze these required field sets, not only type names:

| Value | Required canonical fields |
|---|---|
| `BASAutomationRunRequest` | Automation/version, logical-fire, Workspace/App-Agent, WorkUnit/Attempt/branch identities; semantic-DAG Artifact; expected K3 head/row version; device affinity; admission/capability-use receipts; budget; invalidation/policy/consent/deletion/revocation epochs; idempotency key |
| `BASAutomationResumeRequest` | prior run/Attempt, checkpoint Artifact, `ContextContinuityManifest` Artifact and `WorkUnitRecoveryCursor` digest, fresh normalized Input Event, expected K3 head/row version, current device and all currentness epochs |
| `BASAutomationRunEvent` / `BASAutomationRunTransition` | precommit transition identity, run/Attempt, from/to state, causal event, canonical reason, guard/source receipt refs, predecessor/expected K3 head, expected row version, currentness epochs, and idempotency key; never the head or row version produced by this append |
| `BASAutomationRunOutcome` | final state, terminal or indeterminate reason, state/publication/effect/reconciliation receipt refs, final K3 head, remaining budget, replay root |
| `BASAutomationRecurrenceRequest` | immutable version, calendar, time-zone mode/identity, schedule anchor, closed evaluation interval, missed-run policy, maximum proposal count |
| `BASAutomationLogicalFireProposal` | deterministic logical-fire identity, local components, fold ordinal, resolved UTC instant, schedule/version digest, proposal reason; no execution grant |
| `BASAutomationCheckpointPayload` | Workspace/Automation/version/WorkUnit/Attempt/branch, semantic DAG and completed-node receipt references, `contextContinuityManifestArtifactID`, `workUnitRecoveryCursorDigest`, K3 predecessor head/epochs, remaining budget/rights references, and checkpoint generation; it copies no mutable child-boundary state |
| existing `ContextContinuityManifest` / nested `WorkUnitRecoveryCursor` | exact immutable continuity/recovery projection already owned by `state.snapshot-contracts`; the cursor references nonterminal boundary identities and the existing `ContinuationPolicy` decision but copies no mutable counter or boundary state |
| `BASAutomationCheckpointInstallRequest` / `Receipt` | run/version/checkpoint Artifact/continuity-manifest Artifact/cursor digest; expected head/row version and all currentness epochs; idempotency key / committed head, new row version, canonical checkpoint digest and post-state root |
| `BASAutomationCheckpointReopenRequest` / `Receipt` | run/checkpoint/continuity-manifest/generation, expected currentness and lookup identity / exact stored install receipt, reopened payload/manifest/cursor digests, referenced-owner receipt currentness, and compatibility result |
| `BASRetentionDispositionRequest` / `Receipt` | retention admission identity, expected head/row version, exact disposition and authorization Artifact, all epochs, idempotency / committed head, terminal or finite next window, post-state digest |
| `BASProjectorCursorAdvanceRequest` / `Receipt` | projector/lane identity, prior snapshot/cursor, next `semanticSnapshotArtifactID`, expected head/row version, epochs, idempotency / committed head, row version and canonical cursor digest |
| `BASProjectorCursorSnapshotRequest` / `Snapshot` | projector/lane plus currentness scope / current cursor, semantic snapshot Artifact, K3 head/row version and epochs |
| `BASAutomationInspectionRequest` | caller/Main/App-Agent, source Workspace/Automation, operation, purpose/destination, capability-use receipt Artifact, semantic snapshot Artifact, field mask, row/byte/token/time limits, and capability/policy/consent/deletion/revocation/share epochs |
| `BASExperienceExposureContract` | candidate action set, selected action, behavior-policy ID/digest, propensity or deterministic marker, exposure/cohort/time, generator/evaluator/root/shared-training correlation classes, outcome window, censoring/missingness, independent outcome-source contract |

The definition lifecycle allowed edges are exactly:
`draft→candidate`; `candidate→validating|rejected|quarantined`;
`validating→shadow|rejected|quarantined`;
`shadow→awaitingApproval|rejected|quarantined`;
`awaitingApproval→approved|rejected|quarantined`;
`approved→superseded|quarantined|retiring`;
`superseded|rejected|quarantined→retiring`; `retiring→retired`.
The operational edges are exactly: `disabled→enabled`; `enabled↔paused`;
`disabled|enabled|paused→quarantined|retiring`; `quarantined→retiring`;
`retiring→retired`. No implicit self/back edge exists and `retired` is
terminal.

`BASAutomationRunReducer.validate` and
`BASAutomationRunReducer.apply` freeze the run families exactly:
`observed→admitted|denied`; `admitted→allocated`;
`allocated→executing`; `executing→waiting*|checkpointed|cancelRequested|
reconciling|degraded|terminal`; `waiting*→executing|checkpointed|
cancelRequested|reconciling|degraded|terminal`;
`checkpointed→executing|waiting*|cancelRequested|reconciling`;
`cancelRequested→cancelled|reconciling`;
`reconciling→executing|succeeded|failed|quarantined|indeterminate`;
any nonterminal may enter `degraded` or a guarded terminal, while terminal
states have no outgoing edge. Each edge consumes
`BASAutomationRunTransition`, validates the design §4.7 guard family, and
returns a new immutable run state plus canonical precommit event payload
bytes. It cannot construct K3 receipt bytes.

The controlled-document fixture must freeze exact coding keys and enum wire
bytes. Initializers validate non-empty normalized IDs, strict digests, finite
bounds, and all cross-field invariants. Zero cannot construct either positive
count wrapper. `eligibleLearning72Hours` requires a content reference plus a
precommit `BASRetentionAdmissionRequest` containing the complete typed,
head-free `BASInteractionExperienceEnvelope`. That envelope must already
contain a non-empty `retentionAdmissionID`,
`.eligibleLearning72Hours`, and the governed content Artifact reference; its
purpose and event identity are not duplicated as independent request fields.
The sole K3 transaction computes and stores canonical
`BASRetentionAdmissionReceipt` bytes after the commit head exists; the final
interaction envelope references only `retentionAdmissionID`.
`retentionAdmissionID` is independently allocated before append and is bound
to the envelope's `eventID + idempotencyKey + expectedHead`; it is never
derived from the postcommit receipt bytes, receipt digest, or committed head.
K3 canonicalizes the complete request, atomically appends that envelope and
writes the retention row, then constructs the receipt with the resulting
committed head. A lost reply with byte-identical complete request bytes
returns that receipt; same admission ID with any changed envelope/request byte
is corruption. No precommit payload embeds or predicts its own committed
head. Other retention classes cannot carry that admission identity.

`BASInteractionNormalizationProfile` is frozen in
`BASMemory/HostConstitutionCore.swift` with the exact aggregation thresholds,
content limits, and never-drop semantic classes. The future L6
`BASInteractionSignalNormalizer` consumes this value; it owns no threshold,
policy, consent, or retention decisions.

The initial profile is exact: submit/save/approve/reject/undo/redo,
permission, effect, automation, deletion, correction, and terminal boundaries
each emit their own semantic event; edit transactions flush at save/submit,
undo/redo, focus loss, two seconds idle, 64 raw changes, or 16 KiB normalized
delta metadata; noncritical diagnostics cap at 32 per actor/surface/second and
overflow produces one bounded aggregate/drop receipt; authorization, effect,
deletion, correction, and terminal events are never dropped; structured
EventLog metadata caps at 4 KiB and larger authorized content becomes an
Artifact reference. Raw pointer/touch/key/render observations remain
process-local R1.

W1 also freezes the complete run reducer transition table, recurrence request
and proposal, checkpoint Artifact payload, references to the existing
`ContextContinuityManifest`/`WorkUnitRecoveryCursor`/`ContinuationPolicy`,
inspection request and operation, and validating initializers. It adds no
scheduler, queue, state
writer, checkpoint installer, inspection behavior, Provider call, or Apple
surface.

`BASContextCapsule` is declared exactly once in `BASLowEntropyPrimitives.swift`; `BASDelegationProposal` is declared in `BASAgentFabricEnums.swift` and uses the existing `BASAgentRole`. No new App/Main/Sub role enum is added.

### Payload 3A — Write failing value and wire tests

  Assert:

  - exactly two `BASSpaceKind` cases;
  - ownership cannot follow ambient Session selection;
  - immutable version fields are content/digest references only;
  - illegal lifecycle back-edges are rejected;
  - `retired` is terminal;
  - `enabled` is operational state, not definition state;
  - `boundedBackfill(0)` and `boundedParallel(0)` fail;
  - the precommit R2 request carries the complete typed envelope and only its
    predecessor/expected EventLog head, never the head produced by its append;
  - the K3 receipt is the only R2 value containing the resulting committed
    head and exact
    72-hour minimum; maximum is strictly later;
  - R0/R1/R4 cannot carry content eligible for learning;
  - EventLog payload contains references/digests only;
  - one `BASContextCapsule`, one `BASAgentRole`, one `BASDelegationProposal`;
  - no duplicate forbidden component names under production `Sources/`.

  Run through the non-empty filter:

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASDualSpaceContractTests|BASAutomationDefinitionContractTests|BASInteractionEvidenceContractTests|BASRetentionContractTests|BASSemanticTurnDAGTests|BASAgentContextIsolationContractTests|BASDualSpaceAntiDuplicationTests|BASAutomationLifecycleValidatorTests|BASAutomationRunContractTests|BASAutomationRecurrenceContractTests|BASAutomationCheckpointContractTests|BASAutomationInspectionContractTests|BASInteractionNormalizationProfileTests'
  ```

  Expected: meaningful compile/test failures for missing contracts.

### Payload 3B — Implement low-entropy values only

  Add exact values, validation, Codable fixtures, and no storage/runtime behavior. Keep target dependency direction legal: RuntimeCore cannot import BASMemory; cross-target composition uses `BASArtifactID` references.

### Payload 3C — Freeze the semantic DAG without a scheduler

  `BASSemanticTurnDAG.swift` owns immutable node, typed edge, alternative, delegation, join, and terminal-closure values. It must not own:

  - a queue;
  - a clock;
  - a thread/task pool;
  - a mutable registry;
  - a Provider call;
  - a state/effect write.

  Add exhaustive optional-branch closure fixtures, including denied, unavailable, cancelled, degraded-with-coverage, and indeterminate outcomes.

### Payload 3D — Prove fixtures and authority admission

  Stage only the exact W1 files, write the candidate tree, and run the actual
  `run_qinao_wave_admission.py` W1 bundle with non-empty Extension/Fixture
  inputs and the original Create manifest only if the admitted predecessor
  lacks a first-wire owner. Record the receipt before commit.

### Payload 3E — Verify and commit

  Run focused tests plus:

  ```bash
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w1-paths.txt
  QINAO_W1_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w1-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W1_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w1-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W1_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w1-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W1_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  git diff --check
  test "$(git write-tree)" = "$QINAO_W1_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): freeze dual-space automation contracts"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W1_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payload W2: Build Encrypted Content, Erasure Closure, and the One K3 Automation Transaction Path

**Entry prerequisite:** The security/operator disposition for encrypted durable content, erasure-domain key custody, backup posture, and honest unresolved deletion terminals must be recorded. Without it, transplant and run only the W2 contract-test slice; leave durable R2 admission and all production content writes disabled.

**Files:**

- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
- Create: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactErasureDomainCrypto.swift`
- Keep immutable: `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`
- Create: `BehavioralAISubstrate/Sources/BASMemory/SQL/025_artifact_erasure_domains_v1.sql`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLogBinaryCodec.swift`
- Create: `BehavioralAISubstrate/Sources/BASOrchestration/BASInteractionSignalNormalizer.swift`
- Create: `scripts/check_eventlog_typed_payloads.py`
- Create: `scripts/test_check_eventlog_typed_payloads.py`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASEventSourcedMemoryAtomStore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASMemoryForgetCascadeRunner.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASRetractionFurnace.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASHostConstitutionDeletionManifestStore.swift`
- Modify only as migration inputs: `BehavioralAISubstrate/Sources/BASMemory/SQL/015_host_constitution_deletion_manifest.sql`; `SQL/022_retraction_orders.sql`
- Create tests:
  - `BASArtifactErasureDomainTests.swift`
  - `BASMemoryContentAuthorityMigrationTests.swift`
  - `BASMemoryErasureClosureTests.swift`
  - `BASEventLogSemanticSnapshotTests.swift`
  - `BASAutomationK3LifecycleTests.swift`
  - `BASAutomationInvalidationRaceTests.swift`
  - `BASRetentionDispositionTests.swift`
  - `BASK3CrashRecoveryTests.swift`
  - `BASK3CorruptionRecoveryTests.swift`
  - `BASK3SingleWriterArchitectureTests.swift`
  - `BASK3SharedStorageIdentityTests.swift`
  - `BASAutomationCheckpointStorageTests.swift`
  - `BASInteractionSignalNormalizerTests.swift`
  - `BASEventLogTypedPayloadMigrationTests.swift`
  - `BASArtifactLegacyPlaintextMigrationTests.swift`
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w2-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w2-wave-bundle.json`

**Encryption and key-custody interfaces:**

```swift
public struct BASErasureDomainKeyReference: Codable, Sendable, Hashable {
    public let custodyProfileID: String
    public let keyReferenceID: String
    public let erasureDomainID: String
    public let generation: UInt64
}

public protocol BASErasureDomainKeyCustody: AnyObject, Sendable {
    func createKeyReference(
        for request: BASErasureDomainKeyCreateRequest
    ) async throws -> BASErasureDomainKeyReference

    func openKeyHandle(
        for reference: BASErasureDomainKeyReference,
        authorization: BASErasureDomainKeyUseAuthorization
    ) async throws -> BASErasureDomainKeyHandle

    func revokeKeyReference(
        _ reference: BASErasureDomainKeyReference,
        authorization: BASErasureDomainKeyRevocationAuthorization
    ) async throws -> BASErasureDomainKeyRevocationReceipt
}

public protocol BASArtifactContentAEAD: Sendable {
    func seal(
        plaintext: Data,
        key: BASErasureDomainKeyHandle,
        authenticatedMetadata: Data
    ) throws -> BASSealedArtifactContent

    func open(
        sealed: BASSealedArtifactContent,
        key: BASErasureDomainKeyHandle,
        authenticatedMetadata: Data
    ) throws -> Data
}

public struct BASSealedArtifactContent: Codable, Sendable, Equatable {
    public let profileID: String
    public let cipherSuiteID: String
    public let nonce: Data
    public let ciphertext: Data
    public let authenticationTag: Data
    public let keyReference: BASErasureDomainKeyReference
    public let plaintextDigest: String
    public let erasureDomainID: String
}

public struct BASAuthorizedArtifactRead: Sendable {
    public let record: BASArtifactMeshRecord
    public let plaintext: Data
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let authorizationDigest: String
}

public enum BASArtifactAuthorizedReadError: Error, Sendable, Equatable {
    case authorizedOpenUnavailable
    case authorizationInvalid
    case currentnessMismatch
    case keyUnavailableOrRevoked
    case ciphertextAuthenticationFailed
}

// Modify this incumbent declaration in place; retain these existing methods.
public protocol BASArtifactStorePort: AnyObject, Sendable {
    func put(
        identityCore: BASArtifactIdentityCore,
        headUpdate: BASArtifactHeadCAS?
    ) async throws -> BASArtifactStoreReceipt

    func read(
        _ artifactID: BASArtifactID
    ) async throws -> BASArtifactMeshRecord

    func head(
        _ key: BASArtifactHeadKey
    ) async throws -> BASArtifactHead?

    func attestationArtifactIDs(
        targeting artifactID: BASArtifactID
    ) async throws -> BASBundle<BASArtifactID>

    func readAuthorized(
        _ artifactID: BASArtifactID,
        authorization: BASErasureDomainKeyUseAuthorization
    ) async throws -> BASAuthorizedArtifactRead
}
```

The remaining custody values are frozen as follows:

| Value | Required canonical fields/invariant |
|---|---|
| `BASErasureDomainKeyCreateRequest` | erasure domain, custody profile, Artifact scope/classification, purpose, policy/consent/deletion/revocation epochs, idempotency key, creation expiry |
| `BASErasureDomainKeyUseAuthorization` | existing `BASCapabilityGrant`, `BASCapabilityUseReceipt`, generic attestation, and caller-authentication receipt Artifact IDs; exact Artifact identity/scope, operation/resource, erasure domain, purpose/audience/destination, semantic snapshot, field/row/byte/token/time limits, required key generation, all currentness epochs, monotonic/wall expiry |
| `BASErasureDomainKeyHandle` | opaque in-memory custody token plus exact key-reference identity/generation; non-`Codable`, non-`Hashable`, non-loggable, non-exportable, no public raw-key accessor |
| `BASErasureDomainKeyRevocationAuthorization` | key reference/domain/generation, deletion or revocation authority Artifact, expected epochs, reason, idempotency key |
| `BASErasureDomainKeyRevocationReceipt` | key reference/domain/generation, terminal revoked/already-revoked/indeterminate status, custody evidence digest, committed deletion/revocation epoch, no key bytes |

`BASErasureDomainKeyHandle` is non-`Codable`, non-loggable, non-exportable, and
has no public raw-key accessor. The production custody mechanism is
exactly `BASKeychainErasureDomainKeyCustody`; the production AEAD mechanism is
exactly `BASCryptoKitArtifactContentAEAD`. `BASArtifactSQLiteStore` receives
the one custody actor and AEAD implementation through the frozen ports; a
composition test proves the custody object identity with `===` across create,
open, and revoke. Keychain/CryptoKit are mechanisms, while
`state.memory-content-erasure` alone owns classification, key lifecycle,
revocation, deletion outcome, and policy. Signing, ledger commitment, Provider,
and Artifact-content keys are separate profiles and may never be reused.

`BASArtifactSQLiteStore` is the sole canonical AAD factory. AAD bytes are the
RFC-8949 deterministic-CBOR encoding of the complete Artifact identity
preimage, sealed-content profile/cipher, key-reference identity/generation,
and governing epochs. Callers cannot provide arbitrary AAD. Seal/open recompute
the same bytes; a missing, reordered, widened, or stale field fails before
plaintext release.

The Artifact identity preimage is frozen as canonical bytes over
`schemaVersion + scope + contentClassification + erasureDomainID +
plaintextDigest + purpose + governing epochs`; therefore identical plaintext
in different erasure domains cannot share a row, body, or key fate.

`readAuthorized` extends the same class-bound `BASArtifactStorePort`; it is not
a second store, read authority, or K4 RPC. `BASArtifactSQLiteStore` reopens and
validates the incumbent grant/use-receipt/attestation graph, caller
authentication, subject, scope, operation/resource, purpose, audience,
destination, snapshot, limits, expiry, revocation, and epochs before it asks
the same custody actor for a handle and invokes the same AEAD mechanism. The
authorization value is a transient adapter over those already authoritative
receipts and cannot mint or widen them. Bare `read(_:)` may expose governed
metadata and sealed bytes but rejects plaintext access for encrypted content.
Lost-reply recovery uses only the incumbent
`lookupCapabilityUseReceipt`; there is no domain-specific capability or
Artifact-open authority.

The protocol requirement has one fail-closed default implementation returning
the typed `authorizedOpenUnavailable` error so existing read-only/test
conformers remain source-compatible without gaining plaintext access.
`BASArtifactSQLiteStore` is the only production override; composition and
dispatch tests prove the authorized reader reaches that override and never
the default or bare `read(_:)`.

**One K3 seam:**

The four values `BASAutomationK3TransitionRequest`,
`BASAutomationK3TransitionReceipt`, `BASAutomationK3SnapshotRequest`, and
`BASAutomationK3Snapshot` are declared in
`BASSemanticStateLakeContracts.swift`, together with the checkpoint,
retention-disposition, and projector-cursor request/receipt values frozen in
W1. The existing declaration of
`BASK3ControlNucleusStorage: AnyObject, Sendable` is extended in place with:

```swift
func transactAutomation(
    _ request: BASAutomationK3TransitionRequest
) async throws -> BASAutomationK3TransitionReceipt

func snapshotAutomation(
    _ request: BASAutomationK3SnapshotRequest
) async throws -> BASAutomationK3Snapshot

func installAutomationCheckpoint(
    _ request: BASAutomationCheckpointInstallRequest
) async throws -> BASAutomationCheckpointInstallReceipt

func reopenAutomationCheckpoint(
    _ request: BASAutomationCheckpointReopenRequest
) async throws -> BASAutomationCheckpointReopenReceipt

func admitRetention(
    _ request: BASRetentionAdmissionRequest
) async throws -> BASRetentionAdmissionReceipt

func applyRetentionDisposition(
    _ request: BASRetentionDispositionRequest
) async throws -> BASRetentionDispositionReceipt

func advanceProjectorCursor(
    _ request: BASProjectorCursorAdvanceRequest
) async throws -> BASProjectorCursorAdvanceReceipt

func snapshotProjectorCursor(
    _ request: BASProjectorCursorSnapshotRequest
) async throws -> BASProjectorCursorSnapshot
```

There is no `BASK3AutomationStatePort`, checkpoint store, retention store, or
secondary injectable protocol. `BASSQLiteEventLogStorage` remains the only
production `BASK3ControlNucleusStorage` conformer. A composition test compares
object identity with `===` and proves EventLog, automation, retention,
projector-cursor, and checkpoint facets receive the exact same actor instance.

On the admitted W1 predecessor its schema moves from v2 to one combined v3 K3
migration and adds tables inside the same database/transaction domain:

```text
qinao_automation_active_version
qinao_automation_run
qinao_automation_logical_fire_cursor
qinao_automation_invalidation
qinao_retention_disposition
qinao_projector_cursor
```

Every transition request binds the canonical precommit transition/event
payload, expected EventLog head, expected row version, exact
Automation/version/operational states, invalidation epoch,
policy/consent/deletion/revocation epochs, and idempotency key. Only the sole
K3 transaction may construct `BASAutomationK3TransitionReceipt`, after its
append/CAS succeeds; that receipt alone carries `committedHead`, new row
version, canonical transition/event digest, and complete post-state/root
digests. Coding-key and byte fixtures reject any committed head, new row
version, or receipt digest inside the event payload whose append produces
them. No table is a new database or writer.

If Task 0 selects a predecessor whose K3 schema is already above v2, execution
stops for a controlled migration-number reconciliation; the worker must not
silently renumber, rewrite an applied migration, or create a parallel schema
authority.

### Payload 4A — Write RED tests for Artifact content authority

  Prove:

  - R2/R3 content uses a non-nil erasure-domain key reference;
  - authorized open requires the same scope, purpose, current epochs, and
    unrevoked key generation;
  - encrypted plaintext cannot be obtained through bare `read(_:)`;
    `readAuthorized` rejects a wrong grant/use receipt, caller, operation,
    audience/destination, snapshot, limit, expiry, or attestation;
  - EventLog receives only blinded Artifact identity and classification;
  - identical plaintext in different erasure domains cannot silently share a deletable body/key fate;
  - secret detection before write yields zero durable bytes;
  - post-write secret detection fences reads before asynchronous cleanup;
  - key revocation plus body/WAL/index cleanup has an honest closure receipt;
  - legacy plaintext rows migrate to SQL `025` ciphertext or remain
    `indeterminateBlocked` and unreadable;
  - signing/commitment keys cannot satisfy the content-key profile;
  - `.completed` from the existing value-only forget cascade is insufficient without physical-owner evidence.

### Payload 4B — Write RED tests for K3 invariants and races

  Cover:

  - active version selects at most one approved immutable version;
  - invalidating a selected version atomically replaces or clears it and disables/quarantines operation;
  - no observer can see `enabled` pointing at a non-approved version;
  - invalidation advances one epoch and covers every nonterminal Attempt;
  - a stale allocated/executing/waiting/checkpointed Attempt fails before materialization, Provider claim, publication, effect, and commit;
  - ordinary safe supersede may continue only when its pre-bound continuation policy and all epochs remain current;
  - quarantine, deletion, and revocation never use that exception;
  - logical-fire duplicate bytes return the prior disposition;
  - same event/idempotency identity with different bytes is corruption;
  - crash before commit has no visible partial row; crash after commit reopens the exact receipt;
  - checksum/schema/page/open corruption fences the K3 profile query-only,
    emits a minimized operator incident through its mapped domain owner, and
    never creates/falls back to a shared recovery registry/store;
  - authenticated restore/rebuild either reproduces the exact last admitted
    head/root or remains `indeterminateBlocked`;
  - two concurrent writers cannot both win.
  - every production K3 facet shares one object identity;
  - checkpoint install/reopen uses expected-head, expected-row-version, and
    invalidation/currentness CAS.

### Payload 4C — Extend Artifact Mesh under one content authority

  Add erasure-domain, encryption-key reference, content classification, purpose,
  and governing epoch metadata to the existing Artifact storage envelope.
  Preserve SQL `024` byte-for-byte and add the forward-only SQL `025`
  migration. Preserve content-address validation and head CAS.

  The implementation must use the admitted cryptographic/key-custody owner. Do not place raw keys in SQLite, EventLog, logs, fixtures, App Groups, or model contexts.

  SQL `025` creates the v2 encrypted-body/key-reference schema, migrates every
  legacy v1 plaintext row transactionally, and records a typed fence for rows
  that cannot be classified, encrypted, or verified. No read path falls back
  to the v1 plaintext column after migration. Tests cover fresh database,
  legacy migration, interrupted migration/reopen, authorized decrypt, wrong
  domain/purpose/epoch, tampered AEAD bytes, and revoked key.

### Payload 4D — Migrate atom content to Artifact references

  Introduce a one-way migration:

  1. read legacy atom content;
  2. classify and reject/quarantine secrets or unknown sensitivity;
  3. write encrypted Artifact content;
  4. verify reopened digest and scope;
  5. commit the K3 reference/tombstone atomically;
  6. destroy or make legacy content provably unreachable;
  7. rebuild indexes from authorized references.

  Migration failure leaves the legacy item fenced and typed `indeterminateBlocked`; it never silently falls back to dual authority.

### Payload 4E — Implement K3 schema v3 and transitions

  Put schema creation/migration and all automation rows in `BASSQLiteEventLogStorage.swift`. Use one `BEGIN IMMEDIATE` transaction for row CAS, EventLog append, cursor update, invalidation dispositions, and post-state receipt material.

  Alternate EventLog implementations may remain test/read adapters but cannot advertise production automation-write authority.

  Implement checkpoint install/reopen on the same transaction seam before W6
  runtime behavior exists. The checkpoint payload is an Artifact reference;
  K3 stores only its identity, the opaque
  `contextContinuityManifestArtifactID`, cursor digest, expected head/row
  version, generation, invalidation/currentness epochs, and canonical receipt
  bytes. K3 neither copies nor interprets recovery policy or mutable child-
  boundary state.

### Payload 4E.1 — Normalize and fence EventLog payloads before R2 capture

  Implement the W1-frozen `BASInteractionNormalizationProfile` in the L6
  adapter before any R2 producer is enabled. `scripts/check_eventlog_typed_payloads.py`
  lexically enumerates every production `BASEventLogEntry` constructor and
  append caller from the candidate tree; its committed manifest must equal the
  derived set in both directions.

  Migrate each producer to a registered bounded payload kind whose canonical
  bytes contain only structured facts, digests, refs, epochs, and causal slots.
  At the storage append boundary, reject any new free-form `payloadJson`
  generation even if a producer bypasses the normalizer. Historical rows are
  decoded through a versioned typed migrator or fenced query-only with an
  explicit corruption/incompatibility result. W3 may project the normalized
  evidence but must not be the first place that enforces content freedom.

### Payload 4F — Implement R2 clock and disposition

  R2 admission computes:

  ```text
  minimumRetainUntilMs = trustedStart + 72 * 60 * 60 * 1000
  maximumRetainUntilMs > minimumRetainUntilMs
  ```

  Clock rollback/reboot ambiguity chooses the conservative later bound. At minimum expiry, one governed disposition wins: purge, promote to explicit R3, finite authorized extension, governed dataset inclusion, or finite quarantine. Time passage alone chooses none of them.

### Payload 4G — Implement deletion closure

  The synchronous transaction advances deletion/invalidation epochs and fences source plus known descendants before cleanup. Asynchronous owners then prove:

  - Artifact body/key fate;
  - EventLog eligible-range/checkpoint fate;
  - SQLite WAL/SHM/freelist fate;
  - atom/index/vector/cache/projection fate;
  - dataset/training/evaluation/export/canary lineage fate;
  - backup and external-destination fate.

  Terminal results are exactly `completed`, `residualExternalCopies`, or `indeterminateBlocked`. Only `completed` may claim complete erasure.

### Payload 4H — Run focused and crash tests

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASArtifactErasureDomainTests|BASMemoryContentAuthorityMigrationTests|BASMemoryErasureClosureTests|BASEventLogSemanticSnapshotTests|BASAutomationK3LifecycleTests|BASAutomationInvalidationRaceTests|BASRetentionDispositionTests|BASK3CrashRecoveryTests|BASK3CorruptionRecoveryTests|BASK3SingleWriterArchitectureTests|BASK3SharedStorageIdentityTests|BASAutomationCheckpointStorageTests|BASInteractionSignalNormalizerTests|BASEventLogTypedPayloadMigrationTests|BASArtifactLegacyPlaintextMigrationTests'
  python3 -m unittest scripts.test_check_eventlog_typed_payloads
  ```

### Payload 4I — Admit candidate tree and commit

  ```bash
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w2-paths.txt
  QINAO_W2_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w2-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W2_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w2-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W2_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w2-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W2_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  test "$(git write-tree)" = "$QINAO_W2_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): extend K3 for governed automation and retention"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W2_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payload W3: Build Retrieval, State Market, Space, and Analytics Projections

**Files:**

- Create through original admission if absent, otherwise modify:
  - `BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift`
- Create:
  - `BehavioralAISubstrate/Sources/BASMemory/BASSpaceProjectionCore.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASInteractionExperienceCore.swift`
- Modify:
  - `BehavioralAISubstrate/Sources/BASMemory/BASMemoryUsageTracker+ReplayAuditFTS.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASRAGRetriever.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASVectorIndex.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASSQLiteVectorIndexStorage.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASRoutedVectorIndexStorage.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASVectorReranker.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASEventLogProjectors.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/ProjectionCore.swift`
  - `BehavioralAISubstrate/Cargo/bas-retrieval-ranker/src/fuser.rs` only if a reviewed deterministic ranking change is necessary.
- Create tests:
  - `BASStateRequirementPlannerTests.swift`
  - `BASSemanticSnapshotCoordinatorTests.swift`
  - `BASSemanticStateLaneAdapterTests.swift`
  - `BASSemanticStateMarketTests.swift`
  - `BASWorkSpaceProjectionTests.swift`
  - `BASAutomationSpaceProjectionTests.swift`
  - `BASModelRuntimeProfileProjectionTests.swift`
  - `BASUserExperienceProfileProjectionTests.swift`
  - `BASInteractionExperienceGateTests.swift`
  - `BASProjectionReplayDeterminismTests.swift`
  - `BASSemanticStateShadowIntegrationTests.swift`
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w3-state-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w3-state-wave-bundle.json`

**Projection interfaces:**

```swift
public enum BASProjectionHorizon: String, Codable, Sendable, CaseIterable {
    case current, day, week, month
}

public struct BASWorkSpaceProjectionRequest: Codable, Sendable, Equatable {
    public let callerAgentID: String
    public let selectedAppAgentScopeID: String
    public let callerAuthenticationReceiptArtifactID: BASArtifactID
    public let workspaceRef: ContextWorkspaceRef
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let purposeID: String
    public let destinationID: String
    public let fieldMaskDigest: String
    public let horizon: BASProjectionHorizon
    public let rowLimit: UInt32
    public let byteLimit: UInt64
    public let tokenLimit: UInt32
    public let expiresAtMs: Int64
    public let capabilityEpoch: UInt64
    public let policyEpoch: UInt64
    public let consentEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let shareEpoch: UInt64
}

public struct BASAutomationSpaceProjectionRequest: Codable, Sendable, Equatable {
    public let callerAgentID: String
    public let callerAppAgentScopeID: String
    public let callerAuthenticationReceiptArtifactID: BASArtifactID
    public let sourceWorkspaceRef: ContextWorkspaceRef?
    public let automationRef: BASAutomationRef?
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let purposeID: String
    public let destinationID: String
    public let fieldMaskDigest: String
    public let rowLimit: UInt32
    public let byteLimit: UInt64
    public let tokenLimit: UInt32
    public let expiresAtMs: Int64
    public let capabilityEpoch: UInt64
    public let policyEpoch: UInt64
    public let consentEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let shareEpoch: UInt64
}

internal enum BASSpaceProjector {
    public static func work(
        snapshot: BASStateReadSnapshot,
        request: BASWorkSpaceProjectionRequest
    ) throws -> BASWorkSpaceProjection

    public static func automation(
        snapshot: BASStateReadSnapshot,
        request: BASAutomationSpaceProjectionRequest
    ) throws -> BASAutomationSpaceProjection
}

public struct BASSpaceProjectionCurrentness: Sendable, Equatable {
    public let capabilityEpoch: UInt64
    public let policyEpoch: UInt64
    public let consentEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let shareEpoch: UInt64
}

public struct BASSpaceProjectionCurrentnessQuery: Sendable, Equatable {
    public let callerAgentID: String
    public let appAgentScopeID: String
    public let workspaceRef: ContextWorkspaceRef
    public let automationRef: BASAutomationRef?
    public let purposeID: String
    public let destinationID: String
}

public struct BASAuthorizedSpaceProjectionReader: Sendable {
    public typealias ReadCurrentness =
        @Sendable (BASSpaceProjectionCurrentnessQuery) async throws
        -> BASSpaceProjectionCurrentness

    package init(
        artifactStore: any BASArtifactStorePort,
        readCurrentness: @escaping ReadCurrentness
    )

    public func projectWork(
        _ request: BASWorkSpaceProjectionRequest
    ) async throws -> BASWorkSpaceProjection

    public func projectAutomation(
        _ request: BASAutomationSpaceProjectionRequest
    ) async throws -> BASAutomationSpaceProjection
}
```

`semanticSnapshotArtifactID` reopens the canonical
`BASStateReadSnapshot`, whose lane-watermark vector is the only snapshot
currentness boundary; a single-session `BASEventLogHead` is not accepted.
The public authorized reader reopens and verifies the exact capability-use
receipt, caller-authentication receipt, snapshot Artifact, caller/App-Agent
scope, purpose, destination,
field mask, all row/byte/token/time limits, and every currentness epoch before
and after projection through the same Artifact store and currentness reader.
It must construct the bounded transient
`BASErasureDomainKeyUseAuthorization` from those incumbent receipts and call
`BASArtifactStorePort.readAuthorized`; calling bare `read(_:)` for snapshot
plaintext is a compile/source-gate failure.
Production visibility keeps `BASSpaceProjector` internal; a source/call-graph
test proves every production projection call enters
`BASAuthorizedSpaceProjectionReader` and no `@testable` or wrapper escape
reaches the raw projector. Only the authorized reader may call it.
Projectors are pure, rebuildable, and have no writer/store/grant port.

### Payload 5A — Write RED tests for requirement planning and snapshot barriers

  Prove the planner emits only bounded typed lane requests and the coordinator:

  - captures exact per-lane high-water marks;
  - fails closed on stale or incomparable watermarks;
  - applies eligibility before scoring;
  - scores relevance, authority, freshness, utility, diversity, and token cost;
  - reports conflicts and coverage gaps;
  - never treats an index hit as read authority;
  - returns deterministic results for the same snapshot.

### Payload 5B — Normalize exact/FTS/dense/temporal/entity lanes

  Reuse existing retrievers and indexes as rebuildable mechanisms. Add scope, purpose, caller, field-mask, snapshot, deletion, revocation, and share-epoch checks at the generic read membrane.

  Rust RRF may rank only already eligible candidates. It cannot admit, authorize, resolve truth, or hide coverage gaps.

### Payload 5C — Project normalized interaction evidence

  Consume only the W2-admitted, content-free semantic event kinds. Raw
  touch/key/pointer/scroll/focus/render signals remain process-local R1 and
  never enter projection, EventLog, or learning examples. The W3 exit reruns
  the append-boundary and producer-manifest gates; W3 cannot weaken, defer, or
  duplicate the W2 normalizer or L5 profile.

### Payload 5D — Implement Work Space projection

  Rebuild projects, missions, WorkUnits, document/artifact summaries, selected App/Main identity refs, active/warm/cold context refs, checkpoints, and current/day/week/month views from one snapshot.

  The four horizons are query parameters, not tables or stores.

### Payload 5E — Implement Automation Space projection

  Rebuild immutable definitions, active version, operational state, next eligible proposal, current/waiting runs, checkpoints, outcomes, receipts, retention/deletion status, and module-layout preferences.

  The Host-wide summary may list safe summaries for all user-owned Automation scopes. Detail requires an exact per-scope attenuated read. Projection code cannot run, retry, cancel, pause, edit, delete, grant, share, or export.

### Payload 5F — Implement model/user analytics as orthogonal projections

  `BASModelRuntimeProfileProjection` consumes a canonical profile reference
  from `BASOrgan/BASModelCapabilityManifest.swift` and adds only observed
  latency, memory, energy, thermal, quality, failure, and fallback evidence.
  It cannot redeclare model/material/profile truth in BASMemory.

  `BASUserExperienceProfileProjection` contains consented interaction preferences, accessibility needs, correction patterns, explicit feedback, and task outcomes. It excludes engagement/dependence objectives, silence-as-consent, HealthKit/general-sensitive data, hidden reasoning, and another App Agent's private scope.

  Neither projection selects a model or mutates user/App-Agent state.

### Payload 5G — Implement the experience gate

  Every `experienceSource` either yields a bounded eligible envelope or an
  explicit ineligible receipt after structural, injection, epistemic, semantic,
  privacy/secret, and cross-App-Agent contamination cleaning.
  `derivedOutcomeFeature` is ineligible by default and needs its own independent
  source, lineage, current authorization, and anti-self-corroboration rule.
  `governanceControl`, `auditProof`, and `projectionOnly` never produce ordinary
  learning examples.

  Causal or off-policy use additionally requires a pre-exposure
  `BASExperienceExposureContract` frozen in W1. Its canonical bytes bind:

  - candidate action set, including a singleton set when no choice existed;
  - selected action and behavior-policy ID/digest;
  - logged propensity or an explicit deterministic-policy marker;
  - exposure/cohort/time identity;
  - generator, evaluator, root-model, and shared-training correlation classes;
  - outcome window, censoring/missingness rules, and independent outcome-source
    contract.

  If any required pre-exposure field is missing, late-filled, or
  self-evaluated without an independent source, the event remains diagnostic
  only and is excluded from reward, ranking, training, and policy improvement.

### Payload 5H — Shadow and replay

  Run new projectors beside incumbent paths, compare deterministic roots, inject malformed payloads, and fail closed instead of silently skipping corrupt rows. Do not cut over reads in W3.

### Payload 5I — Verify Swift and Rust

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASStateRequirementPlannerTests|BASSemanticSnapshotCoordinatorTests|BASSemanticStateLaneAdapterTests|BASSemanticStateMarketTests|BASWorkSpaceProjectionTests|BASAutomationSpaceProjectionTests|BASModelRuntimeProfileProjectionTests|BASUserExperienceProfileProjectionTests|BASInteractionExperienceGateTests|BASProjectionReplayDeterminismTests|BASSemanticStateShadowIntegrationTests'
  cargo test --manifest-path BehavioralAISubstrate/Cargo/Cargo.toml \
    -p bas-retrieval-ranker fuser::tests::rrf_basic -- --exact
  ```

### Payload 5J — Admit candidate tree and commit

  ```bash
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w3-state-paths.txt
  QINAO_W3_STATE_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-state-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W3_STATE_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-state-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W3_STATE_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-state-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W3_STATE_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  test "$(git write-tree)" = "$QINAO_W3_STATE_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): add dual-space state projections"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W3_STATE_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payloads W3/W4: Compile Independent Contexts, Then Adapt Execution to Each Model

**Files:**

**W3 context-ownership slice:**

- Modify: `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift`
- Modify to remove duplicate packing/render authority: `BehavioralAISubstrate/Sources/BASOrchestration/CognitionKernelCore.swift`
- Modify to become input-only delegates:
  - `BehavioralAISubstrate/Sources/BASOrchestration/SemanticCompilerCore.swift`
  - `BehavioralAISubstrate/Sources/BASOrchestration/ScopedContextCore.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/EBrainTurnContextCompiler.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASAgentFabricEnums.swift`
- Create tests:
  - `BASExactContextCompilerOwnershipTests.swift`
  - `BASContextCompilerDelegateByteIdentityTests.swift`
  - `BASDelegationCapsuleIsolationTests.swift`
  - `BASAppAgentEmbodimentIsolationTests.swift`
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w3-context-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w3-context-wave-bundle.json`

**W4 Provider/model-adaptation slice, admitted only after the W3 slice:**

- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASLLMInvocationContract.swift`
- Modify after its original W4 admission: `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift`
- Modify: `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlanElector.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/AppleFoundationOrganAdapter.swift`
- Modify: `BehavioralAISubstrate/Sources/BASAppleAdapters/AppleFoundationOrganAdapter+Streaming.swift`
- Modify runtime caller: `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Create tests:
  - `BASIndependentContextWindowStressTests.swift`
  - `BASModelAdaptiveContextGeometryTests.swift`
  - `BASLocalAPIProviderParityTests.swift`
  - `BASProviderKVIsolationTests.swift`
  - `BASProviderFallbackDeterminismTests.swift`
  - `BASContextInterruptionManifestTests.swift`
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w4-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w4-wave-bundle.json`

**Compiler interface:**

```swift
public protocol BASTokenCounting: Sendable {
    func tokenCount(forUTF8 bytes: [UInt8]) async throws -> Int
}

public enum BASContextCompiler {
    public static func compileExact(
        _ request: BASExactContextCompilationRequest,
        tokenizer: any BASTokenCounting
    ) async throws -> BASExactCompiledContext
}
```

`BASExactContextCompilationRequest` binds caller Agent identity, selected App Agent, Main/Sub/Provider identity, Context Capsule, model/material/profile, Task/Attempt/branch, snapshot roots, purpose/rights, stable prefix candidates, volatile suffix candidates, maximum input tokens, reserved output tokens, memory/energy/time budgets, and all currentness epochs.

`BASExactCompiledContext` binds retained/dropped blocks with reasons, exact token accounting, stable-prefix/suffix fingerprints, snapshot roots, source/authority coverage, disclosure plan, and a continuity manifest. It never contains a shared KV handle.

### Payload 6A (W3) — Write RED tests for the single compiler

  Tests fail if:

  - any second production type/function performs packing, drop, render, or fingerprint ownership;
  - character count is accepted as exact token accounting;
  - the compiler exceeds `maximumInputTokens - reservedOutputTokens`;
  - a block crosses Agent/App-Agent/Provider/purpose/epoch scope;
  - stable-prefix identity changes without its fingerprint changing;
  - a dropped required-authority block is omitted without a coverage failure;
  - hidden reasoning or Provider KV becomes a context block.

### Payload 6B (W3) — Implement exact tokenize-once accounting

  Normalize and tokenize each retained candidate once for the selected model tokenizer. Cache only by exact model/material/tokenizer/content/scope/currentness fingerprint. A cache hit grants no read authority and must reopen current epochs.

  Remove or delegate duplicate packing behavior in `CognitionKernelCore.swift`
  to the sole compiler. `SemanticCompilerCore.swift`,
  `ScopedContextCore.swift`, and `EBrainTurnContextCompiler.swift` may only
  project typed inputs and invoke `BASContextCompiler.compileExact` exactly
  once. Source-ownership tests reject local sorting, dropping, rendering,
  token budgeting, packing, or fingerprint logic; byte-identity tests prove
  every wrapper returns the compiler's exact bytes and receipt.

### Payload 6C (W3) — Bind Main/Sub/Provider isolation and admit the W3 slice

  One Session has one frozen Main identity. Each Sub Agent receives a role-minimal `BASContextCapsule` and returns a typed `BASDelegationProposal`/receipt. It cannot see sibling KV, broader memory, another App Agent's Self, or the Main's hidden reasoning.

  Main may synthesize only from verified typed results and source receipts. Majority vote cannot outrank authority or evidence.

  Multiple persistent App Agents may exist, but the Session's K3 selection binds
  exactly one. Each App Agent has a separate Self/relationship/preference scope.
  Another App Agent may read only an exact immutable share and cannot mutate,
  declassify, train on, cache-reuse, export, or cut over from the source without
  separately compatible grants.

  User-selectable persona presets affect only companion expression, approved
  values, relationship continuity, and presentation structure. A “呆呆的”
  voice may alter wording or ornament, but never facts, constraints, risk,
  citations, tool parameters, state, permissions, verification, or audit.
  Provider replacement does not replace the App Agent or logical Main identity.

  Admit and commit this W3 context slice before touching any W4 model/provider
  file:

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASExactContextCompilerOwnershipTests|BASContextCompilerDelegateByteIdentityTests|BASDelegationCapsuleIsolationTests|BASAppAgentEmbodimentIsolationTests'
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w3-context-paths.txt
  QINAO_W3_CONTEXT_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-context-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W3_CONTEXT_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-context-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W3_CONTEXT_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w3-context-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W3_CONTEXT_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  test "$(git write-tree)" = "$QINAO_W3_CONTEXT_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): converge sole context compilation"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W3_CONTEXT_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

### Payload 6D (W4) — Adapt context geometry to local and API models

  Model profiles express:

  - maximum context and output;
  - tokenizer/material identity;
  - streaming/cancellation/tool/vision capabilities;
  - prefix-cache, suffix-continuation, prompt-lookup, MTP, and fallback support;
  - local/API transport and privacy eligibility;
  - measured latency/memory/energy/thermal/quality evidence;
  - unsupported and degraded modes.

  Qwen 3.5 4B and AFM are peer Main-provider choices behind the same contract.
  Qwen 3.5 4B is the initial user-visible default preference, not an
  unconditional execution choice: explicit user selection, exact material
  availability, current device measurements, privacy/quality/resource
  eligibility, and admission still decide the plan. MiniCPM/Granite
  specialist roles are profile/delegation facts, not new authoritative Agent
  roles. Future API models use the same schema and stronger capability
  measurements; they do not receive wider state authority by being more
  capable.

### Payload 6E (W4) — Elect an admitted Pareto path

  `BASExecutionPlanElector` chooses only among fully compatible, already
  verified plans under quality, latency, memory, energy, thermal, network,
  monetary, and privacy budgets. Election freezes the selected Provider/model/
  material/profile before the first exact context compilation and before
  branch or Provider-attempt allocation.

  An unavailable or failed Provider ends the current Attempt with a typed
  disposition. A fallback never swaps Qwen/AFM/API/model material inside that
  Attempt; it creates a successor Attempt with fresh admission, currentness,
  capability-use, profile, context compilation, budget, and lineage receipts.
  The successor records why the prior path became ineligible while preserving
  only immutable Task and source lineage.

  MTP is enabled only when the exact loaded model material and provider implementation prove compatibility; model marketing/name matching is insufficient.

### Payload 6F (W4) — Stress independent windows and interruption manifests

  Run at least eight logical windows with different model context limits and concurrent Sub-Agent branches. Verify:

  - no KV/context/cache identity crossing;
  - bounded memory and fair resource admission;
  - independent cancellation;
  - deterministic snapshot roots;
  - interruption produces a continuity manifest, not a serialized live stack;
  - resume recompiles against current state.

  Reuse the already controlled `BASNextQuestionProjection` path: it is computed
  only after final authorization, is transient and non-learning, performs no
  retrieval/model/tool/effect work before a tap, and a tap starts a distinct
  Attempt through current admission rather than mutating the completed Attempt.

### Payload 6G (W4) — Admit the W4 candidate tree and commit

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASIndependentContextWindowStressTests|BASModelAdaptiveContextGeometryTests|BASLocalAPIProviderParityTests|BASProviderKVIsolationTests|BASProviderFallbackDeterminismTests|BASContextInterruptionManifestTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w4-paths.txt
  QINAO_W4_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w4-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W4_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w4-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W4_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w4-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W4_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  git diff --check
  test "$(git write-tree)" = "$QINAO_W4_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): compile isolated model-adaptive contexts"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W4_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payload W5: Add Attenuated Inspection, Publication, K4 Use, and the Sole Apple Mutation Port

**Entry prerequisites:** The original `sovereign.k4-durable-lifecycle`, `release.spool-publication`, and `effect.zone-c-saga` owners must exist and pass their own CreateGate/platform proof. If any is absent or K4 process/entitlement feasibility remains unproven, this payload stays blocked; no in-process substitute is allowed.

The W5 wave bundle names the exact unexpired
`QinaoK4IOS27PlatformSpikeV1` blob, `supportedExactProfile`, and matching
profile digest. `run_qinao_wave_admission.py` verifies them before any W5
candidate diff; disabled/stale/mismatched evidence blocks the K4-dependent
slice.

**Files:**

- Modify after original admission:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASResponsePublicationContracts.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/SQL/028_response_publication.sql`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASResponseReleaseCoordinator.swift`
  - `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift`
  - `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignLedgerStorage.swift`
  - `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBroker.swift`
  - `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift`
  - `BehavioralAISubstrate/Sources/BASEffectBroker/SQL/001_effect_saga_v1.sql`
  - `BehavioralAISubstrate/Sources/BASSovereignClient/BASSovereignEnhancedSecurityClient.swift`
- Create:
  - `BehavioralAISubstrate/Sources/BASEffectBroker/ZoneCAppleEffectExecutor.swift`
- Modify projection/read callers:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASSpaceProjectionCore.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift`
- Create tests:
  - `BASAutomationInspectionPermitTests.swift`
  - `BASAutomationInspectionCurrentnessTests.swift`
  - `BASResponsePublicationAutomationTests.swift`
  - `BASEffectBrokerAppleBoundaryTests.swift`
  - `BASZoneCAppleEffectExecutorTests.swift`
  - `BASAppleMutationSingleCallerTests.swift`
  - `BASAppleEffectCrashReconciliationTests.swift`
- Create:
  - `docs/superpowers/evidence/qinao-dual-space-w5-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w5-wave-bundle.json`

**Inspection interface:**

The exact values were frozen in W1. W5 implements their behavior; this
reference copy must remain byte-identical to the W1 fixture:

```swift
public struct BASAutomationInspectionRequest: Codable, Sendable, Equatable {
    public let callerAgentID: String
    public let selectedAppAgentScopeID: String
    public let sourceWorkspaceRef: ContextWorkspaceRef
    public let automationRef: BASAutomationRef?
    public let purposeID: String
    public let destinationID: String
    public let operation: BASAutomationInspectionOperation
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let semanticSnapshotArtifactID: BASArtifactID
    public let fieldMaskDigest: String
    public let rowLimit: UInt32
    public let byteLimit: UInt64
    public let tokenLimit: UInt32
    public let expiresAtMs: Int64
    public let capabilityEpoch: UInt64
    public let policyEpoch: UInt64
    public let consentEpoch: UInt64
    public let deletionEpoch: UInt64
    public let revocationEpoch: UInt64
    public let shareEpoch: UInt64
}

public enum BASAutomationInspectionOperation: String, Codable, Sendable, CaseIterable {
    case list
    case getSafeSummary
    case getStatus
    case getMinimizedReceipts
    case explainFailure
}
```

No mutation operation exists in this enum.
The request and operation values live in
`BASLowEntropyPrimitives.swift`; K4 reuses the existing
`BASCapabilityGrant` and capability-use lifecycle rather than defining an
inspection-specific grant.

**Apple effect interface:**

```swift
public struct ZoneCAppleEffectExecutor: BASEffectAdapter {
    public let profile: BASEffectAdapterProfile

    public func dispatch(
        invocation: BASToolInvocation,
        idempotencyKey: String
    ) async throws -> BASEffectProviderObservation

    public func query(
        idempotencyKey: String
    ) async throws -> BASEffectProviderObservation?

    public func compensate(
        invocation: BASToolInvocation,
        priorResult: BASToolResult,
        idempotencyKey: String
    ) async throws -> BASEffectProviderObservation
}
```

This is the existing `BASEffectAdapter` seam, not a parallel Apple-effect
protocol. `BASEffectBroker` may call it only after reopening the exact K3
outbox claim, K4 permit/use, L13 prepare, L14 authorization, boundary
anchor/arm, operation-group identity, parameters digest, currentness epochs,
and idempotency key. The executor is not injected into UI, App Intents, ingress,
read adapters, models, or projections.

### Payload 7A — Write RED tests for the inspection membrane

  Prove:

  - Host-level listing reveals only safe user-owned scope summaries;
  - opening details requires an exact per-scope grant;
  - wrong caller, App Agent, destination, purpose, field mask, budget, snapshot, or epoch fails;
  - currentness is checked before and after materialization;
  - an A→B read share does not authorize B learning, embedding/cache retrieval, model selection, export, re-share, or cutover;
  - derived grants are the intersection of source grants;
  - there is no run/retry/cancel/pause/edit/delete/grant/share/export operation.

### Payload 7B — Extend the incumbent capability grant

  Add only the fields needed to bind the request above and its signed/issued use. The Workspace Agent remains a product projection of selected App Agent plus Main; it does not receive a durable global identity or mutation port.

### Payload 7C — Write RED tests for the classified Apple call graph

  Scan active Swift source, excluding comments/strings through the admitted
  Swift-aware scanner. The gate classifies calls instead of treating every
  Apple side effect as one semantic mutation category:

  | API class | Only admitted leaf | Only admitted caller path |
  |---|---|---|
  | direct regular and continued-processing `BGTaskScheduler.register` | `AppleBGTaskSchedulerBridge.registerLaunchHandler` and `.registerContinuedLaunchHandler` | `BASDeviceTestApp.init`, before launch completion; no runner or view may register |
  | package regular-processing `BGTaskScheduler.submit`/cancel opportunity | direct leaves `.submitProcessingRequest` / `.cancelProcessingRequest`, reached only through `.register(_:)` / `.cancel(id:)` | `BASTurnRuntimeEngine.requestBackgroundOpportunity(_:)` after reopening K3/L14 admission; this wave activates it only in the lab target and never as a domain-effect shortcut |
  | package continued-processing submit/cancel opportunity | `.submitContinuedProcessing`; cancellation reuses `.cancel(id:)` → `.cancelProcessingRequest(id:)` with the exact accepted concrete identifier | the same governed runtime seam; production activation remains disabled without a real signed target profile |
  | lab synthetic continued-processing submission | `AppleBGTaskSchedulerBridge.submitContinuedProcessing` | `BASEnduranceAppRunner.submitContinuedProcessingProbe(_:)` only in the debug/lab target after a foreground user gesture, with zero production semantic work |
  | EventKit, notification scheduling/removal, CloudKit save/delete/subscription, and other semantic external mutations | `ZoneCAppleEffectExecutor.dispatch/query/compensate` | `BASEffectBroker` after K3/K4/L13/L14 boundary proof |
  | Apple read APIs | `AppleReadGateway.read` | `BASAuthorizedSpaceProjectionReader` or the exact authorized StateLake read caller |
  | notification permission UI | `QinaoLabSpaceViews.requestNotificationPermissionFromUserGesture` | its explicit foreground Button action plus reopened L5 policy; never model/background initiated |

  Architecture fixtures allowlist exact path, symbol, and immediate caller for
  each row, and reject any extra edge. Positive mutations planted in ingress,
  read gateway, App Intent, Widget, Cloud callback, projection, or an
  unauthorized BG caller all fail. The gate does not incorrectly require
  BackgroundTasks registration/submission or foreground permission prompts to
  pass through the semantic Zone-C effect executor.

### Payload 7D — Implement the broker-to-Zone-C boundary

  Flow:

  ```text
  L13 exact effect prepare
  -> K3 outbox prepare
  -> L14/K4 exact authorization/use
  -> K3/K4 boundary anchor and arm
  -> one Zone-C claim winner
  -> ZoneCAppleEffectExecutor.dispatch
  -> terminal or indeterminate observation
  -> L13 interpretation
  -> StateCommitIntent
  -> K3 stage, L14/K4 terminal seal, K3 activation
  ```

  The executor owns no policy, retry authority, independent store, or semantic state. A lost reply or possibly crossed boundary enters reconciliation for the same operation identity.

### Payload 7E — Add publication protection

  Automation outputs follow the same exact-spool/pre-publication/currentness barrier as interactive responses. A run cannot publish twice, publish after invalidation/deletion, or treat Provider completion as final user-visible release.

### Payload 7F — Fault-inject every boundary

  Inject before/after K3 prepare, K4 issue/use, anchor, arm, public API call, callback, observation persistence, publication, and terminal state commit. Every case ends in one legal terminal or typed indeterminate state with no duplicate external mutation or publication.

### Payload 7G — Admit candidate tree and commit

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASAutomationInspectionPermitTests|BASAutomationInspectionCurrentnessTests|BASResponsePublicationAutomationTests|BASEffectBrokerAppleBoundaryTests|BASZoneCAppleEffectExecutorTests|BASAppleMutationSingleCallerTests|BASAppleEffectCrashReconciliationTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w5-paths.txt
  QINAO_W5_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w5-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W5_CANDIDATE_TREE" \
    --unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_UNSIGNED_ADMISSION_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w5-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W5_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w5-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W5_CANDIDATE_TREE" \
    --receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"
  git diff --check
  test "$(git write-tree)" = "$QINAO_W5_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): govern automation inspection and Apple effects"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W5_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payload W6 Runtime: Compose Automation Execution, Recurrence Admission, and Interruption Recovery

**Files:**

- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift`
- Create under the same `runtime.semantic-dag` owner:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASAutomationRecurrenceEvaluator.swift`
- Modify: `BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Modify: `BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
- Modify replay/checkpoint paths:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventReplayRunner.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASEventLogReplayBundle.swift`
  - `BehavioralAISubstrate/Sources/BASOrchestration/BASAuditReplayEngine.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift`
- Retire production reachability of old authorities:
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentRegistry.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentRouter.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentFabricRuntime.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentTurnDispatcher.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentRoundTable.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASAgentLeaseManager.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraph.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASSharedStateGraphSQLiteStorage.swift`
  - all `BehavioralAISubstrate/Sources/BASHostKit/BASAgentFabric*.swift`
    pipeline/multi-round-loop callers
  - `BehavioralAISubstrate/Sources/BASJournalCLI/`
  - `QinaoRuntimeSDK/Sources/QinaoSeats/QinaoSpeculativeCouncil.swift`
  - `QinaoRuntimeSDK/Sources/QinaoSeats/QinaoStateGraphBus.swift`
  - old Provider routers/callers named by the controlled retirement manifest,
    including `BehavioralAISubstrate/Sources/BASOrgan/BASProviderRouting.swift`
    and SampleHost dispatch paths
- Create tests:
  - `BASAutomationRunReducerTests.swift`
  - `BASAutomationRecurrenceEvaluatorTests.swift`
  - `BASAutomationLogicalFireCASTests.swift`
  - `BASAutomationDeviceAffinityTests.swift`
  - `BASAutomationOverlapTests.swift`
  - `BASAutomationCheckpointRecoveryTests.swift`
  - `BASAutomationBoundaryRecoveryTests.swift`
  - `BASAutomationCancellationTests.swift`
  - `BASAutomationDryRunZeroEffectTests.swift`
  - `BASAutomationRuntimeIntegrationTests.swift`
  - `BASLegacyAgentAuthorityRetirementTests.swift`
- Create externally with mode `0600`, pairwise distinct, never commit into a
  tree they describe or attest:
  - `$QINAO_W6_UNSIGNED_REPORT_01` through
    `$QINAO_W6_UNSIGNED_REPORT_06`
  - `$QINAO_W6_RECEIPT_01` through `$QINAO_W6_RECEIPT_06`
  - `$QINAO_W6_RUNTIME_RECEIPT_CHAIN`
- Create each governed path list and reviewer-signed bundle only for its exact
  slice, after the prior receipt/commit exists:
  - `docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-wave-bundle.json`

**Runtime composition seam:**

```swift
public enum BASAutomationRecurrenceEvaluator {
    public static func nextLogicalFires(
        _ request: BASAutomationRecurrenceRequest
    ) throws -> [BASAutomationLogicalFireProposal]
}

extension BASTurnRuntimeEngine {
    public func runAutomation(
        _ request: BASAutomationRunRequest
    ) async -> BASAutomationRunOutcome

    public func resumeAutomation(
        _ request: BASAutomationResumeRequest
    ) async -> BASAutomationRunOutcome

    package func requestBackgroundOpportunity(
        _ request: BASGovernedBackgroundOpportunityRequest
    ) async -> BASBackgroundOpportunityReceipt
}
```

The recurrence evaluator is pure, bounded, deterministic, and clock-input driven. It cannot commit a cursor, allocate a WorkUnit, schedule a BGTask, or grant execution. `runAutomation` and `resumeAutomation` reuse the existing turn operation, semantic DAG, Provider, state, publication, effect, and receipt paths.

Both methods and their package-scoped
`BASGovernedAutomationOperationDependencies` seam live in
`BASTurnRuntimeEngine.swift`, where the incumbent engine state is available.
No cross-file extension reaches `private` engine members, no new engine object
is created, and the dependency bundle contains the same class-bound K3
instance, Artifact ports, sole context compiler, publication/effect ports, and
ordinary turn admission seam already used by interactive work.
`BASGovernedBackgroundOpportunityRequest` binds run/Attempt, exact K3/L14
admission receipt, purpose, `regularProcessing|continuedProcessing`,
`submit|cancel`, signed target-capability-profile digest, the exact registered
identifier family and concrete identifier, requested resource class, expiry,
and all currentness epochs. In the W6 lab profile, regular-processing
identifiers must equal `bas.sleep.consolidation` and continued-processing
submit identifiers must be concrete members of
`com.changgeng.basdevicetest.consolidation.*`; no production profile is
inferred from those lab values. Cancel must bind the exact previously accepted
platform request identity. A target/profile/kind/operation/identifier mismatch
fails closed before touching `BGTaskScheduler`.
`BASBackgroundOpportunityReceipt` records accepted/rejected/unavailable,
platform request identity, observation time, and the explicit fact that
acceptance proves no start/completion timing.

Before behavior is added, preserve the controlled W6 receipt order exactly:

1. Runtime Task 2 observation-value-only prelude.
2. Semantic Task 8 audit-value/schema-only prelude, including the first
   governed `BASRuntimeAuditProjectionsBundle` `1.0.0`; no behavior or `put`.
3. Runtime Task 1B freezes the sole `BASSameRunAuditOutcome` and final
   `BASTurnRuntimeAuditEnvelope` `1.0.0`.
4. Semantic Task 8 adds coordinator outcome behavior.
5. Runtime Tasks 2/3/4/5 populate the already frozen values.
6. Runtime Task 7 performs the authoritative engine same-run outcome cutover.

The external chain's schema discriminator is exactly
`QinaoW6RuntimeReceiptChainV1`; both `sign-runtime-chain` and
`verify-runtime-chain` reject any other value. It binds six ordered entries
with exact slice IDs and sequence ordinals:

1. `w6.runtime.observation-values`, `sequenceOrdinal = 1`;
2. `w6.semantic.audit-schema`, `sequenceOrdinal = 2`;
3. `w6.runtime.audit-envelope-freeze`, `sequenceOrdinal = 3`;
4. `w6.semantic.coordinator-behavior`, `sequenceOrdinal = 4`;
5. `w6.runtime.integration-population`, `sequenceOrdinal = 5`;
6. `w6.runtime.engine-cutover`, `sequenceOrdinal = 6`.

Each entry binds its own signed wave-admission receipt blob, base/candidate
trees, required predecessor receipt, path-list/category blobs, and frozen
schema digests. More precisely, each entry contains the complete canonical
signed `QinaoWaveAdmissionReceiptV1` object as `receipt`, plus
`receiptDigest = SHA256(RFC8785(receipt))`; the digest, embedded object,
sequence fields, and signed fields must agree. `sign-runtime-chain` opens,
canonicalizes, signature-verifies, and embeds the six supplied receipt files;
it never emits digest-only entries. Each slice runs admission before its
commit; the next slice's base is the previous candidate tree. The sixth bundle
binds and verifies the first five receipts plus its own expected
slice/schema/path roots. After its commit tree equals receipt six, the pinned
external verifier independently verifies all six receipts and asks only the protected
`runtime-chain-signer` provider to sign the six-entry
`$QINAO_W6_RUNTIME_RECEIPT_CHAIN`. The following Apple bundle uses receipt 06
as its immediate predecessor and additionally binds the verified chain digest.
The chain verifies the exact `1.0.0`
`BASRuntimeAuditProjectionsBundle`, `BASSameRunAuditOutcome`, and
`BASTurnRuntimeAuditEnvelope` schema digests. No later slice may reorder,
skip, refreeze, or silently widen those wire values. W3-state/W3-context and
the W6 runtime/Apple/certification macro slices use the same
`waveSliceID`/`sequenceOrdinal` predecessor rule. The Apple lab slice is W6
ordinal 7 and final certification is W6 ordinal 8.

### Payload 8A — Verify the W1-frozen run reducer contracts

  Re-run the W1 wire fixture for the exact state inventory:

  ```text
  observed, admitted, denied, allocated, executing,
  waitingForConfirmation, waitingForNetwork, waitingForModel, waitingForTool,
  checkpointed, cancelRequested, reconciling, degraded,
  succeeded, failed, cancelled, quarantined, indeterminate
  ```

  `denied`, `succeeded`, `failed`, `cancelled`, `quarantined`, and
  `indeterminate` are terminal. Context compilation is an
  Artifact/subreceipt, not a reducer state. Illegal transitions and any
  terminal outgoing edge fail. W6 implements the frozen reducer; it does not
  add, remove, rename, or recode a state.

### Payload 8B — Implement pure recurrence evaluation

  Cover fixed and follow-device time zones, exact calendars, DST gaps/folds, travel, clock correction, shutdown/offline windows, `skip`, `runLatest`, and bounded backfill.

  The result is a proposal only. General scheduled execution remains feature-disabled until Payload 8C and all device-affinity tests pass.

### Payload 8C — Claim each logical fire through K3 then L14

  The bound execution device/authority domain performs expected-cursor CAS once. The winning cursor disposition still grants no execution; ordinary L14 admission must create the WorkUnit/Attempt.

  V1 binds each Automation version to the one admitted local device identity.
  Concurrent duplicate delivery returns the prior disposition and any other or
  offline device cannot win. Affinity transfer returns
  `disabledMissingOwner`; no lease, move, expiry, or multi-device active
  execution algorithm is implemented until a separate controlled design and
  non-empty CreateGate admit a linearizable owner.

### Payload 8D — Implement overlap and bounded concurrency

  Enforce `skipWhileRunning`, `queueOne`, and `boundedParallel(n)` through K3 rows and ordinary resource admission. No in-memory queue becomes recovery truth.

### Payload 8E — Implement checkpoint and resume

  A checkpoint contains immutable references to:

  - Workspace/Automation/version/WorkUnit/Attempt/branch;
  - semantic DAG and completed node receipts;
  - K3 head and invalidation/policy/consent/deletion/revocation epochs;
  - exact context/snapshot/material/profile refs;
  - remaining budget and rights;
  - one `contextContinuityManifestArtifactID` and its nested
    `WorkUnitRecoveryCursor` digest.

  `ContextContinuityManifest` remains the `state.snapshot-contracts` value
  from the controlled 2026-07-19 design. Its cursor references each
  nonterminal Provider/effect/publication boundary owner and the existing
  L11/L14 `ContinuationPolicy` receipt; the automation checkpoint does not
  copy those mutable states or invent a recovery policy. Resume reopens the
  manifest and each owner receipt, then applies the existing
  `RecoveryDisposition` matrix.

  Resume reopens all references and currentness, reconciles any possibly crossed boundary, and recompiles context. It never restores a Swift task stack, closure, thread, raw prompt, shared KV, or ambient handle.

### Payload 8F — Implement cancellation, steering, and reconciliation

  Pre-boundary cancellation closes only after every child acknowledges and no boundary may have crossed. Otherwise it enters `reconciling`; only authenticated terminal evidence may decide continuation or a terminal result. A successor is a new Attempt after the prior Attempt becomes terminal.

  User steering is a new normalized Input Event with its own identity,
  currentness, purpose, and causal links. It requests cancellation or
  supersession of affected branches, waits for their legal terminal or
  reconciliation state, and then allocates a successor Attempt. It never edits
  the old prompt, hidden reasoning, Provider Attempt, checkpoint, or committed
  event bytes in place.

### Payload 8G — Prove zero-effect recipe validation

  AI-authored automation recipes use structured proposal, canonicalization, schema/capability/data-flow/injection checks, bounded fixtures, dry-run, shadow comparison, user-visible semantic/permission diff, and approval.

  Pre-approval runs use synthetic/recorded inputs and inert effect simulators. The receipt must prove zero production K3 mutation, zero Zone-C dispatch, zero network/Apple mutation, and zero final publication. A new skill/prompt/schema/package goes through runtime certification and production cutover, never runtime-state activation.

### Payload 8H — Retire old Agent authority reachability

  Task 2 must transplant the complete canonical incumbent-retirement manifest
  from the controlled 2026-07-19 Agent/context design into the Runtime plan;
  this annex's file hints are not a shorter substitute. Existing Agent Fabric,
  Journal/Council, shared-state graph/store, lease, state bus, HostKit
  pipeline/multi-round loop, Device runner, and legacy Provider-routing types
  may remain only as migration/test fixtures. Source, link image, factory,
  dependency-injection, construction graph, and call-graph tests prove no
  authoritative runtime, state write, Provider selection, effect,
  publication, or recovery path reaches any manifest member before cutover.

### Payload 8I — Admit and commit all six W6 runtime slices

  Do not aggregate these slices. For every slice, first run the owning
  controlled task's RED/GREEN filter and the cumulative compilable suite; the
  shown filters are the minimum non-zero discovery set.

  **Slice 01 — observation values**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASTurnRuntimeAuditEnvelopeTests|BASEBrainSchemaGovernanceRegistryTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-paths.txt
  QINAO_W6_TREE_01=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W6_TREE_01" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_01"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_01" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_01" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_01"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-01-observation-values-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W6_TREE_01" \
    --receipt "$QINAO_W6_RECEIPT_01"
  test "$(git write-tree)" = "$QINAO_W6_TREE_01"
  git diff --cached --check
  git commit -m "feat(qinao): declare runtime observation values"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_01"
  test -z "$(git status --porcelain)"
  ```

  **Slice 02 — audit projection schema**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASRuntimeAuditProjectionsBundleCodableDoctrineTests|BASEBrainSchemaGovernanceRegistryTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-paths.txt
  QINAO_W6_TREE_02=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_01" \
    --candidate-tree "$QINAO_W6_TREE_02" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_02"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_02" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_01" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_02" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_02"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-02-audit-schema-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_01" \
    --candidate-tree "$QINAO_W6_TREE_02" \
    --receipt "$QINAO_W6_RECEIPT_02"
  test "$(git write-tree)" = "$QINAO_W6_TREE_02"
  git diff --cached --check
  git commit -m "feat(qinao): freeze audit projection schema"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_02"
  test -z "$(git status --porcelain)"
  ```

  **Slice 03 — same-run outcome and final envelope freeze**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASTurnRuntimeAuditEnvelopeTests|BASEventLogEntryTurnEnvelopeTests|BASEBrainSchemaGovernanceRegistryTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-paths.txt
  QINAO_W6_TREE_03=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_02" \
    --candidate-tree "$QINAO_W6_TREE_03" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_03"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_03" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_02" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_03" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_03"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-03-audit-envelope-freeze-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_02" \
    --candidate-tree "$QINAO_W6_TREE_03" \
    --receipt "$QINAO_W6_RECEIPT_03"
  test "$(git write-tree)" = "$QINAO_W6_TREE_03"
  git diff --cached --check
  git commit -m "feat(qinao): freeze same-run audit envelope"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_03"
  test -z "$(git status --porcelain)"
  ```

  **Slice 04 — coordinator outcome behavior**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASSemanticStateShadowIntegrationTests|BASSemanticStateAntiDuplicationTests|BASRuntimeAuditProjectionsBundleCodableDoctrineTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-paths.txt
  QINAO_W6_TREE_04=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_03" \
    --candidate-tree "$QINAO_W6_TREE_04" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_04"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_04" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_03" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_04" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_04"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-04-coordinator-behavior-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_03" \
    --candidate-tree "$QINAO_W6_TREE_04" \
    --receipt "$QINAO_W6_RECEIPT_04"
  test "$(git write-tree)" = "$QINAO_W6_TREE_04"
  git diff --cached --check
  git commit -m "feat(qinao): add coordinator audit outcome"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_04"
  test -z "$(git status --porcelain)"
  ```

  **Slice 05 — runtime integration and automation population**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASAutomationRunReducerTests|BASAutomationRecurrenceEvaluatorTests|BASAutomationLogicalFireCASTests|BASAutomationDeviceAffinityTests|BASAutomationOverlapTests|BASAutomationCheckpointRecoveryTests|BASAutomationBoundaryRecoveryTests|BASAutomationCancellationTests|BASAutomationDryRunZeroEffectTests|BASAutomationRuntimeIntegrationTests|BASSemanticDAGShadowParityTests|BASEBrainTurnResultReplayHarnessTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-paths.txt
  QINAO_W6_TREE_05=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_04" \
    --candidate-tree "$QINAO_W6_TREE_05" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_05"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_05" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_04" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_05" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_05"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-05-integration-population-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_04" \
    --candidate-tree "$QINAO_W6_TREE_05" \
    --receipt "$QINAO_W6_RECEIPT_05"
  test "$(git write-tree)" = "$QINAO_W6_TREE_05"
  git diff --cached --check
  git commit -m "feat(qinao): populate governed runtime integration"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_05"
  test -z "$(git status --porcelain)"
  ```

  **Slice 06 — authoritative engine cutover**

  ```bash
  python3 scripts/run_nonempty_swift_filter.py \
    --package-path BehavioralAISubstrate \
    --filter 'BASTurnRuntimeEngineTests|BASSemanticDAGShadowParityTests|BASLegacyAgentAuthorityRetirementTests|BASAutomationRuntimeIntegrationTests'
  swift test --package-path BehavioralAISubstrate
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-paths.txt
  QINAO_W6_TREE_06=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_05" \
    --candidate-tree "$QINAO_W6_TREE_06" \
    --unsigned-report "$QINAO_W6_UNSIGNED_REPORT_06"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_UNSIGNED_REPORT_06" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_05" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_TREE_06" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_RECEIPT_06"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-06-engine-cutover-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_05" \
    --candidate-tree "$QINAO_W6_TREE_06" \
    --receipt "$QINAO_W6_RECEIPT_06"
  test "$(git write-tree)" = "$QINAO_W6_TREE_06"
  git diff --cached --check
  git commit -m "feat(qinao): cut over engine-owned same-run outcome"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_TREE_06"
  test -z "$(git status --porcelain)"
  ```

  Only after all six commits pass, build and verify the external chain:

  ```bash
  test ! -e "$QINAO_W6_RUNTIME_RECEIPT_CHAIN"
  test -x "$QINAO_RUNTIME_CHAIN_SIGNING_PROVIDER"
  test "$(shasum -a 256 "$QINAO_RUNTIME_CHAIN_SIGNING_PROVIDER" | cut -d ' ' -f 1)" = \
    "$QINAO_RUNTIME_CHAIN_SIGNING_PROVIDER_SHA256"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" sign-runtime-chain \
    --receipt-01 "$QINAO_W6_RECEIPT_01" \
    --receipt-02 "$QINAO_W6_RECEIPT_02" \
    --receipt-03 "$QINAO_W6_RECEIPT_03" \
    --receipt-04 "$QINAO_W6_RECEIPT_04" \
    --receipt-05 "$QINAO_W6_RECEIPT_05" \
    --receipt-06 "$QINAO_W6_RECEIPT_06" \
    --repository "$PWD" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --signing-provider "$QINAO_RUNTIME_CHAIN_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_RUNTIME_CHAIN_SIGNING_PROVIDER_SHA256" \
    --output "$QINAO_W6_RUNTIME_RECEIPT_CHAIN"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" verify-runtime-chain \
    --chain "$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --repository "$PWD" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --expected-head-tree "$QINAO_W6_TREE_06"
  ```

---

## Controlled Domain-Plan Payload W6 Apple Lab: Prove System Surfaces and Keep Unproven Profiles Disabled

**Repository truth:** `BehavioralAISubstrate/DeviceTestApp` is the only active Xcode host. It is explicitly a lab/test host. `Archive/Legacy/Before*` is not production evidence and must not be revived.

**Files for the admitted lab slice:**

- Modify:
  - `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleBGTaskSchedulerBridge.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleBGTaskSchedulerBridgeTests.swift`
  - `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoBGMaintenanceBridge.swift`
  - `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoBGMaintenanceBridgeTests.swift`
  - `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoRuntimeM149BGIntegrationTests.swift`
  - `BehavioralAISubstrate/DeviceTestApp/project.yml`
  - `BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj`
  - `BehavioralAISubstrate/DeviceTestApp/Resources/Info.plist`
  - `BehavioralAISubstrate/DeviceTestApp/Resources/BASDeviceTestApp.entitlements`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/BASDeviceTestApp.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift`
- Create:
  - `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceIngressAdapter.swift`
  - `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleSurfaceSnapshot.swift`
  - `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleReadGateway.swift`
  - `BehavioralAISubstrate/Sources/BASAppleLifecycleKit/AppleCloudKitManualProfile.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleSurfaceIngressAdapterTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleSurfaceSnapshotTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleSurfaceArchitectureGateTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleReadGatewayTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/AppleCloudKitManualProfileContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASWatchInitialProfileContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHealthKitPrivacyProfileContractTests.swift`
  - `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNotificationObservationContractTests.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoAppEntities.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoNavigationIntents.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoCaptureDraftIntent.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoReadOnlyIntents.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoAppShortcuts.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoIntentDependencies.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoLabNavigationRouter.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Sources/App/AppleSystemSurfaces/QinaoLabSpaceViews.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Tests/AppleSystemSurfaces/QinaoAppIntentContractTests.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Tests/AppleSystemSurfaces/QinaoAppIntentIngressTests.swift`
  - `BehavioralAISubstrate/DeviceTestApp/Tests/AppleSystemSurfaces/QinaoAppIntentLockedStateTests.swift`
  - `scripts/assert_qinao_ios27_device_profile.py`
  - `scripts/test_assert_qinao_ios27_device_profile.py`
  - `scripts/assert_xcode_test_evidence.py`
  - `scripts/test_assert_xcode_test_evidence.py`
  - `docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-w6-apple-lab-build-receipt.json`
  - `docs/superpowers/evidence/qinao-w6-apple-device-lifecycle-receipt.json`
  - `docs/superpowers/evidence/qinao-w6-apple-privacy-entitlement-inventory.json`
  - `docs/superpowers/evidence/qinao-w6-apple-xcode-evidence-manifest.json`
- Create externally with mode `0600`, never commit:
  - `$QINAO_W6_APPLE_UNSIGNED_WAVE_BUNDLE`
  - `$QINAO_W6_APPLE_UNSIGNED_REPORT`
  - `$QINAO_W6_APPLE_ADMISSION_RECEIPT`
- Create only after the complete privacy-manifest review proves it is needed
  and all four manifest sections are accurate:
  `BehavioralAISubstrate/DeviceTestApp/Resources/PrivacyInfo.xcprivacy`.

**Do not create in this lab slice:**

- a production Widget/Control/Live Activity target;
- a Watch target;
- CloudKit containers/subscriptions;
- APNs environment;
- EventKit/HealthKit/HomeKit write entitlements;
- an App Group carrying raw state;
- guessed `PrivacyInfo.xcprivacy` reason codes.

### Payload 9A — Correct and freeze BackgroundTasks doctrine

  Replace every “GUARANTEED-start” statement with the accurate bounded, cancellable, user-initiated continued-processing semantics. Continued processing is not recurrence, exact scheduling, or correctness authority.

  Update to the iOS 27 API shape proven by the installed SDK, including async
  submission where required. Preserve the incumbent regular-processing
  identifier `bas.sleep.consolidation`; it is not a continued-processing
  wildcard and must not be renamed or silently removed. In
  `BASDeviceTestApp.init`, before launch completion, register both the regular
  launch handler for `bas.sleep.consolidation` and the exact continued-
  processing lab identifier family produced for bundle
  `com.changgeng.basdevicetest` and context `consolidation`. The exact
  `BGTaskSchedulerPermittedIdentifiers` set in both `project.yml` and the
  checked-in `Resources/Info.plist` is:

  1. `bas.sleep.consolidation`;
  2. `com.changgeng.basdevicetest.consolidation.*`.

  The exact `UIBackgroundModes` array in both `project.yml` and the checked-in
  `Resources/Info.plist` is `[processing]`; no other background mode is added
  by this slice. The architecture test proves set/array equality, not mere
  membership, and proves that project source, checked-in plist, generated
  project settings, and built `Info.plist` agree for both keys. Missing
  `processing` makes regular `BGProcessingTaskRequest` submission
  `disabledMissingConfiguration`; a permitted identifier alone is
  insufficient. Remove the late
  continued-processing registration at `BASEnduranceAppRunner.swift`. The
  package-level submit/cancel path may be requested only by the exact package-
  scoped `BASTurnRuntimeEngine.requestBackgroundOpportunity(_:)` seam after it
  reopens the K3/L14 admission receipt; this wave activates only the signed
  lab profile, while a production profile remains disabled. A
  `BASEnduranceAppRunner.submitContinuedProcessingProbe(_:)` call is permitted
  only in the lab/debug target, after an explicit foreground user gesture,
  with synthetic input, zero semantic state/effect/publication, and a
  `labOnly` receipt; it cannot become production evidence. If registration,
  Info value, generated identifier, or bundle ID differs, the capability is
  `disabledMissingConfiguration`.

  `preferGPU` remains false until the exact continued-processing GPU entitlement is present and archive-verified.

### Payload 9B — Retire the duplicate direct BG scheduler path

  Choose the compatibility-disabled path: remove direct BackgroundTasks calls
  from `QinaoBGMaintenanceBridge`; `.system()` returns the explicit unavailable
  adapter/`false` result. QinaoRuntimeSDK gains no new
  `BASAppleLifecycleKit` product dependency and does not pretend delegation
  exists. `AppleBGTaskSchedulerBridge` remains the sole admitted adapter in
  BehavioralAISubstrate.

  Static tests prove exactly one active production BackgroundTasks caller.

### Payload 9C — Write RED tests for thin ingress, read gateways, and snapshots

  `AppleSurfaceIngressAdapter` may parse/minimize/validate platform values and build the incumbent `BASEntryIntentEnvelope`. It cannot rank, authorize, persist, retry, schedule semantic work, call a Provider, or execute an effect.

  All surface policy decisions come from the exact L5 Host Constitution value
  or its signed decision reference. No `AppleSurfaceIngressPolicy` type/file
  exists. `AppleReadGateway` accepts only an authorized typed read request,
  reopens its grant and current epochs, minimizes the result, and returns a
  signed snapshot/reference. It owns no cache, projection, policy, write,
  CloudKit callback, Provider, or effect port.

  `AppleSurfaceSnapshot` contains only signed, minimized, purpose-specific fields suitable for a separate/locked process. It cannot contain raw K3/memory/Artifact/Provider ports, private App Agent Self, prompt bytes, secrets, or unrestricted receipts.

### Payload 9D — Implement the initial App Intent lab surface

  Implement:

  - open Work Space;
  - open Automation Space;
  - open task-continuation view and submit a normalized continuation request;
  - capture a draft;
  - inspect automation status;
  - show the transient next-question projection.

  The exact lab matrix is:

  | Intent | `supportedModes` | `allowedExecutionTargets` | `authenticationPolicy` / locked invocation | `isDiscoverable` | Cancellable/undoable |
  |---|---|---|---|---|---|
  | open Work Space | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |
  | open Automation Space | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |
  | continue task | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |
  | capture draft | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |
  | inspect automation status | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |
  | show next question | `.foreground(.immediate)` | `[.main]` | `.requiresLocalDeviceAuthentication`; locked rejects/requests unlock | `true` | no/no |

  Every Intent explicitly sets the installed iOS 27 equivalents of
  `supportedModes`, `allowedExecutionTargets = [.main]`,
  `authenticationPolicy`, `isDiscoverable`, and cancellation/undo
  conformance. The initial six conform to neither `CancellableIntent` nor
  `UndoableIntent`; a later controlled slice may add either only with an exact
  handler/inverse contract and tests. Do not use deprecated
  `openAppWhenRun`; there is no App Intent extension target in this slice.

  Because every Intent executes in `.main`,
  `QinaoLabNavigationRouter` consumes one in-process normalized navigation
  request and routes to real in-app Work/Automation/task-continuation views.
  This slice defines no URL scheme, `onOpenURL`, or deep-link parser. Before the W6
  runtime payload passes, continuation is foreground navigation plus Input
  Event only. After it passes, continuation still requires the ordinary
  governed resume path; an Intent implementation never restores or owns
  execution.

### Payload 9E — Prove notification observation and Widget posture without creating targets

  Architecture gates must keep the current stage at:

  - in-app preview or pure fixtures only;
  - notification permission request only from an explicit foreground user
    action after L5 policy;
  - read-only status projection;
  - zero `UNUserNotificationCenter.add`;
  - zero APNs token egress;
  - zero remote send.

  Freeze observation terms exactly: `requestCommitted`,
  `localSchedulingAccepted`, `apnsAccepted`, `foregroundCallback`,
  `userAction`, `notificationCenterSnapshot`, `cancelled`, `expired`, and
  `unknown`. Scheduling or APNs acceptance is never evidence of delivery,
  presentation, or user action. Widget/Control/Live Activity remain
  `disabledMissingTarget`; do not describe an extension preview.

  A formal Widget/Control target can be planned only after a real product App target is admitted. Do not add dead source paths that no target compiles.

### Payload 9F — Add disabled contract tests for CloudKit

  `AppleCloudKitManualProfile.swift` is a production-neutral contract only.
  Through fakes/protocol fixtures, freeze:

  - database scope exactly private/shared;
  - `automaticallySync == false`;
  - one exact non-optional broker-provisioned subscription ID;
  - one engine per database;
  - send/pending changes callable only from the live Zone-C claim;
  - fetch callable only from `AppleReadGateway`;
  - delegate batches reopen outbox/permit/currentness/invalidation/boundary;
  - opaque state serialization and pending identities persist through K3/Artifact references;
  - retry/cancel ambiguity enters reconciliation;
  - public database and HealthKit-origin data are rejected.

  Do not instantiate a production `CKSyncEngine` or add an iCloud container in
  the lab target. The capability remains
  `disabledMissingTarget`, `disabledMissingEntitlement`, or
  `disabledMissingDeviceProof`; a passing fake/manual-profile contract cannot
  self-certify production CloudKit.

### Payload 9G — Freeze Watch/Handoff and HealthKit exclusions

  Static fixtures reject:

  - importing archived Watch code;
  - Watch direct confirm/reject/effect/state write;
  - durable Watch queue, `transferUserInfo`, application-context, or file transfer in the initial profile;
  - broad Handoff content/KV transfer;
  - HealthKit-origin or health-derived data entering general analytics, general learning, general API Providers, CloudKit/iCloud, or cross-App-Agent sharing.

  Initial Watch request fixtures bind request identity, Workspace/App-Agent
  scope, expiry, deletion/revocation epochs, phone-side dedupe, and an
  acknowledgement. The bounded phone receipt is exactly
  `accepted|denied|status`, contains the request identity and terminal K3
  receipt reference, and `accepted` may be sent only after the iPhone
  completes `L13 prepare → K3 invisible stage → L14/K4 seal → K3 activation`.
  The Watch shows “not saved” until that phone ack arrives;
  offline loss is explicit and nonrecoverable. When a real target eventually
  exists, semantics are redacted status, process-local R1 capture over
  immediate reachability, and open-pending-review on a foreground unlocked
  iPhone.

  Health read fixtures distinguish `unknown/no-authorized-samples`, bind the
  earliest authorized date, and fail every write closed. No empty result is
  interpreted as “healthy” or “zero,” and the profile remains disabled.
  Handoff may carry only a Workspace/Task recovery reference; no content,
  prompt, KV, grant, or state payload crosses it.

### Payload 9H — Regenerate, build, and test the lab host

  Update `project.yml` source membership for the eight production lab files and
  three exact test files, then run:

  ```bash
  cd BehavioralAISubstrate/DeviceTestApp
  xcodegen generate
  git diff -- BASDeviceTest.xcodeproj/project.pbxproj
  xcodebuild -list -project BASDeviceTest.xcodeproj
  python3 ../../scripts/assert_qinao_ios27_device_profile.py \
    --profile "$QINAO_IOS27_DEVICE_PROFILE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --destination "$QINAO_IOS27_DESTINATION" \
    --minimum-os 27.0
  xcodebuild build-for-testing \
    -project BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "$QINAO_IOS27_DESTINATION" \
    -derivedDataPath "$QINAO_DERIVED_DATA_PATH"
  xcodebuild test-without-building \
    -project BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "$QINAO_IOS27_DESTINATION" \
    -derivedDataPath "$QINAO_DERIVED_DATA_PATH" \
    -enumerate-tests \
    -test-enumeration-style hierarchical \
    -test-enumeration-format json \
    -test-enumeration-output-path "$QINAO_TEST_ENUMERATION_PATH"
  python3 ../../scripts/assert_xcode_test_evidence.py \
    --enumeration "$QINAO_TEST_ENUMERATION_PATH" \
    --require-suite QinaoAppIntentContractTests \
    --require-suite QinaoAppIntentIngressTests \
    --require-suite QinaoAppIntentLockedStateTests
  xcodebuild test-without-building \
    -project BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "$QINAO_IOS27_DESTINATION" \
    -derivedDataPath "$QINAO_DERIVED_DATA_PATH" \
    -only-testing:BASDeviceTests/QinaoAppIntentContractTests \
    -only-testing:BASDeviceTests/QinaoAppIntentIngressTests \
    -only-testing:BASDeviceTests/QinaoAppIntentLockedStateTests \
    -resultBundlePath "$QINAO_XCRESULT_PATH"
  xcrun xcresulttool get test-results summary \
    --path "$QINAO_XCRESULT_PATH" \
    --compact > "$QINAO_XCRESULT_SUMMARY_PATH"
  QINAO_BUILT_APP="$QINAO_DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/BASDeviceTestApp.app"
  test -d "$QINAO_BUILT_APP"
  test -e "$QINAO_BUILT_APP/Metadata.appintents"
  plutil -extract MinimumOSVersion raw \
    "$QINAO_BUILT_APP/Info.plist"
  python3 -c \
    'import plistlib,sys; p=plistlib.load(open(sys.argv[1],"rb")); assert p.get("UIBackgroundModes")==["processing"]' \
    Resources/Info.plist
  python3 -c \
    'import plistlib,sys; p=plistlib.load(open(sys.argv[1],"rb")); assert p.get("UIBackgroundModes")==["processing"]' \
    "$QINAO_BUILT_APP/Info.plist"
  codesign -d --entitlements :- "$QINAO_BUILT_APP" \
    > "$QINAO_BUILT_ENTITLEMENTS_PATH"
  python3 ../../scripts/assert_xcode_test_evidence.py \
    --summary "$QINAO_XCRESULT_SUMMARY_PATH" \
    --built-app "$QINAO_BUILT_APP" \
    --metadata "$QINAO_BUILT_APP/Metadata.appintents" \
    --info "$QINAO_BUILT_APP/Info.plist" \
    --entitlements "$QINAO_BUILT_ENTITLEMENTS_PATH" \
    --minimum-os 27.0 \
    --require-background-mode processing \
    --require-suite QinaoAppIntentContractTests \
    --require-suite QinaoAppIntentIngressTests \
    --require-suite QinaoAppIntentLockedStateTests
  ```

  The signed device profile must identify a physical, non-simulator iPhone on
  iOS 27 and bind the destination, device-class/build, expiry, nonce, and
  signer; its device identifier stays outside Git. All evidence paths are
  unique and preflighted absent. Before the first build/test, verify active
  Xcode project/scheme/device defaults through XcodeBuildMCP. Review and commit
  the generated project diff; `project.yml` alone is not target membership or
  compile evidence.

  Required device/lab evidence:

  - build settings and deployment target;
  - compiled App Intent metadata;
  - all three named device suites discovered and nonzero;
  - actual Info/entitlements from the built product;
  - locked/unlocked behavior;
  - foreground in-process navigation behavior;
  - cancellation/expiration;
  - zero direct mutation paths;
  - no zero-test suite.

### Payload 9I — Derive the lab privacy and entitlement inventory

  Review all privacy-manifest dimensions: collected-data types and purposes,
  tracking boolean, tracking domains, and accessed API categories with exact
  Apple-listed reason codes. Create or modify
  `DeviceTestApp/Resources/PrivacyInfo.xcprivacy` only from that complete
  review; add target membership and verify the file in the built bundle. Do
  not infer reason codes from prose.

  When the signed lab archive profile is available, return to the repository
  root and run:

  ```bash
  xcodebuild archive \
    -project BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$QINAO_DERIVED_DATA_PATH" \
    -archivePath "$QINAO_ARCHIVE_PATH"
  test -d "$QINAO_ARCHIVE_PATH/Products/Applications/BASDeviceTestApp.app"
  ```

  Inspect that archive's built privacy manifest, `Info.plist`, and signed
  entitlements and bind their digests in the lab inventory. Xcode 27 exposes no
  standalone command-line privacy-report generator in this environment, so
  this plan does not claim an Organizer Privacy Report from `build-for-testing`.
  If a reviewed Organizer/export report is later supplied, bind it as
  additional lab evidence; absence keeps the profile `labOnly`, never
  production-ready.

  Record an exact inventory for continued-processing GPU, App Group, APNs and
  `UIBackgroundModes`, CloudKit/iCloud, EventKit usage strings, HealthKit,
  HomeKit, and Live Activity. The admitted lab posture is: the exact two-entry
  BackgroundTasks Info set (`bas.sleep.consolidation` plus the continued-
  processing wildcard), exact `UIBackgroundModes == [processing]`, and the
  already existing increased-memory entitlement only; GPU, App Group, APNs,
  iCloud/CloudKit, EventKit,
  HealthKit, HomeKit, and Live Activity remain absent/false unless separately
  proved by a later controlled profile. The artifact is named a lab
  privacy/entitlement inventory and states `not production release evidence`.

  Locked-device App Intent behavior and continued-processing
  launch/expiration/cancellation are recorded in the signed
  `qinao-w6-apple-device-lifecycle-receipt.json` from a physical device. Fakes,
  a simulator, or unit tests cannot fill those fields. A missing or failed
  observation yields `disabledMissingDeviceProof` for that capability while
  leaving unrelated lab contracts valid.

### Payload 9J — Admit candidate tree and commit

  The Apple wave bundle binds the exact path-list, Xcode evidence-manifest,
  build receipt, xcresult and enumeration digests, compiled App Intents
  metadata digest, built Info/entitlement digests, privacy/entitlement
  inventory, exact `[processing]` built-background-mode proof,
  device-lifecycle receipt, K4 status where applicable, and optional
  built privacy-manifest/archive digests. It names
  `$QINAO_W6_RECEIPT_06` as the immediate predecessor. Its sole
  `externalPrerequisites[]` row is named `runtime-receipt-chain`, declares
  schema `QinaoW6RuntimeReceiptChainV1`, binds the verified
  `$QINAO_W6_RUNTIME_RECEIPT_CHAIN` digest, and requires outcome `accepted`.
  All four consuming commands additionally require byte-level cross-object
  continuity: the chain's entry 06 embedded receipt and digest equal the
  canonical bytes and SHA-256 of `--previous-receipt
  "$QINAO_W6_RECEIPT_06"`; the chain head candidate tree equals that receipt's
  candidate tree; and that same tree equals the Apple bundle base tree/current
  `HEAD^{tree}`. A different internally valid W6 chain fails.
  Missing physical lifecycle proof may
  produce an explicit disabled capability row, but never an `enabled` row.

  ```bash
  python3 -m unittest \
    scripts.test_assert_qinao_ios27_device_profile \
    scripts.test_assert_xcode_test_evidence
  swift test --package-path BehavioralAISubstrate
  swift test --package-path QinaoRuntimeSDK
  BehavioralAISubstrate/scripts/check-ios27-floor.sh
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" review-wave-bundle \
    --unsigned-bundle "$QINAO_W6_APPLE_UNSIGNED_WAVE_BUNDLE" \
    --path-list docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-paths.txt \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_06" \
    --repository "$PWD" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --signing-provider "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER_SHA256" \
    --output docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-wave-bundle.json
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-paths.txt
  QINAO_W6_APPLE_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_06" \
    --candidate-tree "$QINAO_W6_APPLE_CANDIDATE_TREE" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --unsigned-report "$QINAO_W6_APPLE_UNSIGNED_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_APPLE_UNSIGNED_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_RECEIPT_06" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_APPLE_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-apple-lab-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_RECEIPT_06" \
    --candidate-tree "$QINAO_W6_APPLE_CANDIDATE_TREE" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT"
  git diff --check
  test "$(git write-tree)" = "$QINAO_W6_APPLE_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "feat(qinao): prove governed Apple lab surfaces"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_APPLE_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

---

## Controlled Domain-Plan Payload W6 Certification: Replay, Quality, Performance, Privacy, and Disabled-by-Default Cutover

**Files:**

- Modify after original admission:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift`
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventReplayRunner.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASEventLogReplayBundle.swift`
  - `BehavioralAISubstrate/Sources/BASOrchestration/BASAuditReplayEngine.swift`
  - `BehavioralAISubstrate/Sources/BASHostKit/BASEBrainTurnResultReplayHarness.swift`
  - `BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift`
  - `BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh`
- Create/update the exact W6 certification and cutover evidence paths assigned by the reconciled master, including:
  - `docs/superpowers/evidence/qinao-dual-space-w6-certification-paths.txt`
  - `docs/superpowers/evidence/qinao-dual-space-w6-certification-wave-bundle.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-certification-report.json`
  - `docs/superpowers/evidence/qinao-dual-space-w6-independent-review-receipt.json`
- Create externally with mode `0600`, never commit:
  - `$QINAO_W6_CERT_UNSIGNED_WAVE_BUNDLE`
  - `$QINAO_W6_CERT_UNSIGNED_REPORT`
  - `$QINAO_W6_CERT_ADMISSION_RECEIPT`
- Create tests:
  - `BASDualSpaceEndToEndTests.swift`
  - `BASAutomationReplayCertificationTests.swift`
  - `BASAutomationFaultMatrixTests.swift`
  - `BASInteractionLearningDeletionTests.swift`
  - `BASAppleCapabilityCutoverTests.swift`
  - `BASArchitectureCardinalityTests.swift`
  - `BASAuthoritativeEntrypointTests.swift`
  - `BASDualSpacePerformanceProtocolTests.swift`

### Payload 10A — Build the closed replay manifest

  Bind exact roots for:

  - input/trigger event;
  - Workspace/Automation/version;
  - WorkUnit/Attempt/semantic DAG;
  - Agent/Main/Sub/Provider identities and Context Capsules;
  - K3 heads/cursors/invalidation/retention/deletion epochs;
  - snapshot/lane/market/context;
  - model/material/profile/execution plan;
  - Provider/tool/effect/publication receipts;
  - checkpoint/recovery/reconciliation;
  - learning eligibility/dataset/deletion lineage;
  - Apple surface and capability posture.

  Replay must reproduce the same deterministic state/projection roots or return a typed incompatibility/corruption result.

### Payload 10B — Execute the complete fault matrix

  Inject failure before/after:

  - trigger normalization;
  - active-version and logical-fire CAS;
  - run allocation;
  - invalidation while allocated/executing/waiting/checkpointed;
  - content write/key issue;
  - context compile;
  - Provider allocation/claim/handoff/observation;
  - checkpoint store/reopen;
  - K3/K4 prepare/anchor/arm;
  - Zone-C call/ack;
  - publication prepare/release;
  - deletion epoch, descendant fencing, every purge owner, rescan;
  - Cloud fake send/fetch/conflict/cancel/retry;
  - BG expiration;
  - process and extension termination.

  Assert no duplicate Provider call, state activation, external effect, or publication.

### Payload 10C — Run adversarial reasoning and data-quality suites

  Include:

  - multi-constraint ordering;
  - source-faithful long-text extraction;
  - strongly leading subjective prompts;
  - logic puzzles and bounded hypothesis search;
  - repeated-state/overthinking loops;
  - conflicting sources with authority precedence;
  - prompt/tool/retrieval injection;
  - model self-contamination;
  - cross-App-Agent laundering;
  - deletion after dataset/training/canary creation.

  RSI terminates under repeated-state, no-progress, branch, token, time, and effect bounds. “Needs more evidence” is a valid typed result; fabricated certainty is not.

### Payload 10D — Measure performance under a preregistered protocol

  Record exact:

  - iPhone model, silicon, OS, build, battery state, ambient/device temperature;
  - model/material/tokenizer/quantization/context/output;
  - cold/warm definition and run count;
  - prefill, first-token, accepted decode, end-to-end task latency;
  - p50/p95/p99;
  - memory high-water, energy, and thermal state;
  - quality/constraint/source-faithfulness score;
  - enabled cache/prompt-lookup/MTP/fallback path.

  Cold 40 tok/s and sustained 30 tok/s are reported as met/not-met against this protocol. A miss blocks only the performance target/cutover profile it governs; it does not falsify structural completion or invite benchmark cheating.

### Payload 10E — Prove cardinality and authoritative entrypoints

  Static and runtime evidence must show:

  - 14 semantic layers;
  - exactly the ten named observable supersteps, each mapped back to its
    affected L1-L14 owners and never treated as a second layer identity;
  - 4 kernels;
  - 4 rings;
  - 7 planes;
  - one K3 writer;
  - one Artifact content authority;
  - one context compiler;
  - one semantic Task Graph/execution path;
  - one publication mouth;
  - one Zone-C effect caller;
  - one Apple background adapter;
  - zero legacy Agent/runtime authoritative reachability;
  - zero Automation/Analytics parallel stores.

### Payload 10F — Produce a capability-by-capability cutover matrix

  Every capability is one of:

  - `enabled`;
  - `shadow`;
  - `labOnly`;
  - `disabledMissingOwner`;
  - `disabledMissingTarget`;
  - `disabledMissingConfiguration`;
  - `disabledMissingEntitlement`;
  - `disabledMissingDeviceProof`;
  - `disabledPrivacyOrSecurity`;
  - `disabledPerformance`;
  - `retired`.

  No global “everything enabled” flag exists. Work/Automation read-only projections may cut over independently from recurrence, effects, CloudKit, Watch, or learning.

  “Full evidence closure” means every `enabled` profile has complete
  authority, replay, fault, privacy, security, target, entitlement, device,
  performance, release, and rollback evidence; every `labOnly` profile has the
  same closure inside its declared lab boundary plus an explicit
  `not production release evidence` receipt; every disabled profile names the
  exact missing owner, target, entitlement, device, privacy, security, or
  performance fact. A disabled capability is not an incomplete global exit.

### Payload 10G — Run full cumulative verification

  Run:

  ```bash
  python3 -m unittest discover -s scripts -p 'test_*.py'
  swift test --package-path BehavioralAISubstrate
  swift test --package-path QinaoRuntimeSDK
  swift test --package-path SampleHost
  cargo test --manifest-path BehavioralAISubstrate/Cargo/Cargo.toml --workspace
  BehavioralAISubstrate/scripts/check-ios27-floor.sh
  BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh
  git diff --check
  ```

  Run the admitted Xcode iOS 27 lab/device matrix separately and attach its exact result bundle/receipt. A simulator-only pass cannot enable entitlement- or lifecycle-dependent capabilities.

### Payload 10H — Independent review

  Request separate reviews for:

  - authority/duplication;
  - privacy/retention/deletion;
  - Agent/context isolation;
  - Apple API/target/entitlement/release posture;
  - crash/recovery/idempotency;
  - performance methodology.

  Every accepted finding receives a regression or mutation test before
  closure, then Payload 10G and the affected device/lab suite run again. The
  signed independent-review receipt and all final device/result-bundle digests
  must exist before final staging.

### Payload 10I — Commit certification evidence

  Only after device evidence, independent reviews, finding fixes, and all
  reruns are complete, stage the exact path list, admit that final tree, and
  commit immediately. The certification bundle names
  `$QINAO_W6_APPLE_ADMISSION_RECEIPT` as its immediate predecessor and binds
  the Apple evidence roots. It also directly reopens the runtime chain through
  the same sole `externalPrerequisites[]` row
  (`runtime-receipt-chain`, `QinaoW6RuntimeReceiptChainV1`, exact digest,
  `accepted`) rather than trusting a copied digest. At all four stages, the
  canonical chain digest must equal the runtime-chain prerequisite digest
  signed into `--previous-receipt
  "$QINAO_W6_APPLE_ADMISSION_RECEIPT"`; the chain entry 06 receipt digest must
  equal that Apple receipt's signed immediate-predecessor digest; the chain
  head candidate tree must equal the Apple receipt base tree; and the Apple
  receipt candidate tree must equal the certification bundle base tree/current
  `HEAD^{tree}`. A valid chain from another run cannot be substituted:

  ```bash
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" review-wave-bundle \
    --unsigned-bundle "$QINAO_W6_CERT_UNSIGNED_WAVE_BUNDLE" \
    --path-list docs/superpowers/evidence/qinao-dual-space-w6-certification-paths.txt \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --signing-provider "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_BUNDLE_REVIEW_SIGNING_PROVIDER_SHA256" \
    --output docs/superpowers/evidence/qinao-dual-space-w6-certification-wave-bundle.json
  git add --pathspec-from-file=docs/superpowers/evidence/qinao-dual-space-w6-certification-paths.txt
  QINAO_W6_CERT_CANDIDATE_TREE=$(git write-tree)
  python3 scripts/run_qinao_wave_admission.py report \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-certification-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W6_CERT_CANDIDATE_TREE" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --unsigned-report "$QINAO_W6_CERT_UNSIGNED_REPORT"
  "$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave \
    --report "$QINAO_W6_CERT_UNSIGNED_REPORT" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-certification-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --previous-receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT" \
    --repository "$PWD" \
    --candidate-tree "$QINAO_W6_CERT_CANDIDATE_TREE" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" \
    --signing-provider-sha256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256" \
    --receipt "$QINAO_W6_CERT_ADMISSION_RECEIPT"
  python3 scripts/run_qinao_wave_admission.py verify-receipt \
    --root "$PWD" \
    --bundle docs/superpowers/evidence/qinao-dual-space-w6-certification-wave-bundle.json \
    --source-selection "$QINAO_SOURCE_SELECTION" \
    --trust-root "$QINAO_ADMISSION_TRUST_ROOT" \
    --previous-receipt "$QINAO_W6_APPLE_ADMISSION_RECEIPT" \
    --candidate-tree "$QINAO_W6_CERT_CANDIDATE_TREE" \
    --external-prerequisite "runtime-receipt-chain=$QINAO_W6_RUNTIME_RECEIPT_CHAIN" \
    --receipt "$QINAO_W6_CERT_ADMISSION_RECEIPT"
  test "$(git write-tree)" = "$QINAO_W6_CERT_CANDIDATE_TREE"
  git diff --cached --check
  git commit -m "test(qinao): certify dual-space automation convergence"
  test "$(git rev-parse HEAD^{tree})" = "$QINAO_W6_CERT_CANDIDATE_TREE"
  test -z "$(git status --porcelain)"
  ```

  Raw device logs, account paths, provisioning identities, UDIDs, certificates, profiles, prompts, user content, and secrets stay outside Git.

---

## Required Assertions to Transplant into the Master and Domain Exit Gates

The annex does not declare completion. Task 2 must transplant the following
assertions into the owning master/domain exits; only those controlled exits may
mark the delta complete:

- one externally admitted predecessor and approved design source are pinned;
- the seven controlled documents and Owner Ledger agree without count drift;
- Create, Extension, Fixture, path, scanner, test-discovery, iOS-floor, and CI gates are non-vacuous;
- Work Space and Automation Space rebuild from the same authoritative snapshot and own no mutable truth;
- fine-grained evidence is normalized, purpose-bound, and content-separated;
- R2 enforces exactly 72 hours plus immediate overrides and a finite maximum;
- deletion fences synchronously and ends honestly across content, indexes, caches, datasets, models, exports, backups, and external copies;
- App Agent, Main, Sub, and Provider identities have isolated contexts and no shared hidden reasoning/KV;
- local and API models use one model-independent capability/profile/execution contract;
- automation definitions, logical fires, runs, checkpoints, recovery, effects, publication, and learning use the existing Event/Artifact/Task/receipt path;
- recurrence cannot execute without the pure evaluator + K3 CAS + L14 + device-affinity closure;
- Apple ingress/read/BG/permission/effect boundaries are distinct and only
  Zone C performs semantic external Apple mutation;
- the lab App Intent surface is real and tested, while absent production targets remain honestly disabled;
- CloudKit, notifications, Watch, and high-sensitivity profiles cannot activate ahead of their exact gates;
- 14/4/4/7 and single-authority invariants pass static and runtime proof;
- measured performance and quality are reported without turning 40/30 into an impossible unconditional gate;
- every enabled capability has replay, fault, privacy, security, release, and
  rollback evidence; every lab-only or disabled capability has its exact scope
  or missing-fact receipt.
