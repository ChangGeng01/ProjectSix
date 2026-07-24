# Qinao Artifact Mesh W1 Task 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the incumbent `artifact.mesh` implementation, prove its owner-private SQLite/Keychain durability and physical crash recovery, and expose one production assembly seam without creating a new owner, expanding its historical M/Create evidence, or claiming W1 admission from candidate-local work.

**Architecture:** The incumbent three M paths remain the only Artifact Mesh creation paths. One internal anchor port/record, one Keychain adapter, one Qinao mechanism factory, and one host call seam are the exact four W1 E/A slices; a separately installable iOS lab app and predecessor-derived verification tools exercise the production mechanism without entering the shipping graph. Work is deliberately split into Task-0 candidate-local code/preflight and a later final-W1-`Pw` physical proof. After the first candidate tree passes completely, Task 10 alone proposes the indexed `artifact.mesh / converging → implemented` owner-row transition and reruns the full Phase-A gates over that new tree; only its post-transition handoff unlocks later W1 compilation. The second phase runs only through the bootstrap-owned `ProtectedAdmissionClient` and its external physical-gate broker, revalidates the already-indexed proposal, and makes it authoritative only through W1 admission. Artifact Mesh emits no candidate admission leaf and owns no proposal, lease, custody, runner, evidence-assembly, import, ref, or finalization authority.

**Tech Stack:** Swift 6, SwiftPM, XCTest, Crypto/CryptoKit, Security.framework Keychain, SQLite3 in persistent WAL mode with `synchronous=FULL`, Xcode 27, iOS 27, XcodeGen, structured `xcrun devicectl`, Python 3 standard-library `unittest`, canonical JSON, Git object/index verification, and the bootstrap-owned protected admission/physical-broker/custody capabilities.

## Global Constraints

- Approved dynamic-graph non-delta pin: commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- Start Phase A from the exact finalized admitted-W0 seal. Start Phase B from the exact immutable final W1 `Pw`; neither phase accepts a caller-supplied wave.
- Import, without redeclaration, the bootstrap-owned opaque `ExternalPhysicalGateBinding`, `PayloadProposalReceiptV1`, `EvaluationLease`, `AuthenticatedGateResultBundle`, `ImportedCommit`, `AdmittedWaveV1`, and `ProtectedAdmissionClient`. If the active bootstrap does not expose their signed service binding and exact client surface, stop at `BLOCKED_EXTERNAL_BOOTSTRAP`; no repository helper may emulate them.
- Phase A starts only after `ProtectedAdmissionClient.reopen_admitted_predecessor()` returns a service-envelope-verified finalized W0 whose seal equals clean `HEAD`. An unsigned path, cached JSON, candidate parser result, or caller assertion is not an admitted predecessor.
- The deployment floor is iOS 27.0. `BehavioralAISubstrate/Package.swift`, `QinaoRuntimeSDK/Package.swift`, `SampleHost/Package.swift`, the lab project, and every archive command must retain that floor.
- Repair, but never extend or resubmit, the historical M/Create set:
  - `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`
- Preserve the four historical evidence files as retrospective evidence. Never rename them to original/atomic CreateGate proof and never add a new path to any of their candidate sets.
- Add exactly four, and only four, W1 `ea_extensions` slices under incumbent owner `artifact.mesh`: AnchorPort `E`, KeychainAnchor `A`, Qinao factory `A`, and sovereign-host call seam `A`.
- `BASArtifactMeshAnchorPort` and its record are internal owner-private mechanisms. They are not public governed payloads, do not enter `BASEBrainSchemaGovernanceRegistry`, and cannot be used by another owner.
- The Keychain adapter is the only shipping anchor writer. No production initializer accepts an injected anchor, fake anchor, alternate store, route, release profile, policy, or fallback.
- The anchor stores no raw commitment key. It uses service `com.qinao.artifact-mesh.anchor.v1`, `kSecUseDataProtectionKeychain = true`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrSynchronizable = false`, and the app's nonshared Keychain access group. Its generic-password composite primary key uses service plus a state-bearing account (and the fixed access-group/synchronizable dimensions); CAS atomically matches the old account and updates both account and data. `kSecAttrGeneric` is neither uniqueness nor CAS authority.
- The database, WAL, and SHM use `completeUntilFirstUserAuthentication`; every SQLite connection sets and queries `SQLITE_FCNTL_PERSIST_WAL = 1`, then uses WAL plus `synchronous=FULL`. One mesh occupies one dedicated directory, and quarantine is an atomic same-parent directory rename with a durable, idempotently recoverable intent. A returned put receipt is not K3-referenceable until the exact Keychain pending record, SQLite commit/checkpoint, and Keychain promotion have completed.
- Keychain/protected-data unavailability is typed unavailable. It is never interpreted as anchor absence or permission to create.
- A committed anchor with missing/mismatched database family, a present database with missing committed anchor, an identity/key/schema/head/floor rollback, and ambiguous partial presence quarantine the exact DB/WAL/SHM family together; they never auto-create either side.
- The lab is an independent signed iOS app. `SampleHost/Package.swift` excludes the whole `ArtifactMeshDeviceLab` directory. Production reachability must prove the lab product, compile condition, probe symbols, and fault hooks absent from every selected shipping archive.
- Candidate-local fixture/unit/device work produces no admission, no gate-result leaf, no protected-ref mutation, no `Cw`, and no `Sw`. Task 10 is the sole exception for Ledger bytes: only after a complete passing candidate preflight may it commit the exact proposed `artifact.mesh / converging → implemented` owner-row delta, then it must rerun the complete Phase-A gates. That indexed proposal is non-authoritative before W1 admission; every other Ledger/status mutation is forbidden.
- Every Python RED that introduces a module first writes the smallest
  importable stub at the final path with the final callable/CLI surface.
  Every operation raises the task's exact
  `artifact-mesh.*.unimplemented` diagnostic; tests must be discovered and
  fail on that diagnostic, never on import, fixture, or path absence. GREEN
  replaces the stub in place, and no stub is committed.
- Every Swift RED is non-vacuous. If its test names a new production type,
  the same RED step writes a minimal compileable fail-closed stub at the final
  source path with the final declaration/signature surface and no working
  behavior; behavior entrypoints throw a task-local `.unimplemented`.
  `run_nonempty_swift_filter.py` must successfully compile/list and execute
  the intended suite, and RED must be an asserted semantic failure rather
  than import, type-check, linker, or list failure. GREEN replaces the stub
  in place and removes `.unimplemented`; no stub is ever committed.
- Every serialized nonfinal outcome uses Bootstrap's closed
  `AdmissionTerminalError`. A bare `BLOCKED_*` name below denotes the terminal
  class only; emission also requires its registry-closed reason code, while
  only `pendingAdmission` carries null.
- Phase B first obtains separate user authorization and calls `ProtectedAdmissionClient.pin_payload_and_issue_lease(payload_oid:)`; only the externally pinned proposal receipt and signed lease can select toolchain, release profile, shipping archive, lab archive, signing identity, device policy, custody, producer, attester, and evidence broker. Production rejects every `QINAO_*` selector and every CLI device/team/toolchain/archive/custody/evidence-client selector.
- Phase B binds the exact final W1 `Pw` commit/tree, selected shipping archive, lab archive, physical device/boot/container, E/A manifest, 40 matrix rows, and external raw-evidence reopen. If the real reboot-before-first-unlock observation is unexercisable, the row remains unexecuted and the exact terminal is `BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY`.
- Raw archives, provisioning profiles, CMS/signing chains, device identifiers, container copies, Keychain observations, and physical traces never enter Git. They live only in an encrypted ephemeral root whose key is supplied out of band by the external broker; after external reopen and independent verification, key destruction and verified no-residue cleanup are mandatory and crash-recoverable.
- Only `ProtectedAdmissionClient.assemble_import_and_finalize(lease:gate_results:)` may validate the authenticated results, construct/import/reopen `Cw` and `Sw`, create the import receipt and intent, perform protected-ref CAS, and finalize admission. Candidate code, the device controller, the protected runner, and Artifact Mesh evidence code cannot supply a leaf or any commit/ref bytes.
- Use only the generic E/A API:

```bash
python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json \
  --payload-commit "$PAYLOAD_COMMIT" \
  --payload-tree "$PAYLOAD_TREE"
```

  It has no `--wave`.

## Approved Dynamic Graph Artifact-Mesh Non-Delta

The graph amendment adds no Artifact-Mesh schema, owner, field, store,
handoff, admission leaf, or special recovery route. Graph contracts,
bindings, roots, cursors, and receipts use the incumbent ordinary
put/read/reopen, durability, quarantine, and crash-recovery mechanisms exactly
like every other authorized artifact.

The Task-0 owner transition remains exactly
`artifact.mesh / converging → implemented`, with the same three historical
M/Create paths and four E/A slices. Phase A/Phase B boundaries, physical
proof, handoff, admission ownership, and migration disposition are unchanged.
No graph term may expand the M/Create set or make Artifact Mesh a scheduler,
graph writer, context compiler, retry authority, or control ring.

During Task 10, the exact owner-row comparison and generic E/A checker must
also prove that no graph-specific Artifact-Mesh owner/schema/field/handoff was
introduced. This is a negative closure assertion inside the existing checks,
not a new gate or manifest.

### Exact Artifact-Mesh task insertion

No Task 1-9 implementation surface changes. Task 10 adds only negative
closure tests to the incumbent generic checker/test path; Tasks 11-13 consume
the same final-W1 payload and physical proof. This plan consumes the
reconstruction master's Artifact-Mesh/W1 placement without reordering W1 or
creating a graph handoff; it returns only its incumbent Task-0 handoff.

Add to `scripts/test_check_qinao_ea_extensions.py`:

```text
test_artifact_mesh_graph_amendment_has_no_schema_delta
test_artifact_mesh_graph_amendment_has_no_owner_delta
test_artifact_mesh_graph_amendment_has_no_field_or_handoff_delta
test_graph_values_use_ordinary_put_read_reopen
test_graph_terms_cannot_expand_artifact_mesh_create_set
```

Each negative fixture changes exactly one dimension. The accepted fixture
must still show the three historical M/Create paths, four E/A slices, exact
`artifact.mesh / converging → implemented` proposal, unchanged Phase A/B
handoff, and ordinary storage/reopen classification.

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_ea_extensions
```

Expected: positive discovery and all tests pass. No new Artifact Mesh path,
schema field, owner row, manifest type, recovery route, or graph-specific
store is permitted.

## Execution-Root Guard

Run this before every task and after every context/session restart:

```bash
test "$PWD" = /Users/changgeng/.codex/worktrees/e4d7/Project06
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
```

Expected: one canonical JSON line with exact keys `candidate_lineage,head_commit,head_tree,schema_version`, `candidate_lineage = "reparentedProgram"`, and `schema_version = 1`. A source/forensic worktree, the prebootstrap preparation lineage, audited tip ancestry, wrong fixed forensic ref, missing/excess preparation refs, a preparation-ref suffix/OID mismatch, repository root mismatch, or dirty task boundary exits 2 before a byte changes.

After that permanent guard passes, require the predecessor-provided interfaces:

```bash
test -f docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md
test -f scripts/check_qinao_ea_extensions.py
test -f scripts/check_qinao_wave_admission.py
```

At Phase A entry, the bootstrap-authenticated runner—not a candidate shell—does exactly:

```text
admittedW0 =
  ProtectedAdmissionClient.reopen_admitted_predecessor()
require admittedW0.envelope verifies under the active B0 ServiceBinding
require admittedW0.derived_wave == W0
require admittedW0.finalized_attestation_digest reopens and verifies
require admittedW0.seal_commit_oid == git.revParse("HEAD")
require admittedW0.seal_tree_oid == git.revParse("HEAD^{tree}")
require git.revParse(admittedW0.seal_commit_oid + "^{tree}")
        == admittedW0.seal_tree_oid
```

Expected: the protected client returns one authenticated finalized `AdmittedWaveV1`. Missing service binding/envelope is `BLOCKED_EXTERNAL_BOOTSTRAP`; missing host objects is `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`; any identity mismatch is the existing predecessor/admission-integrity block. `/private/tmp/qinao-admission/W0/admitted-wave-v1.json` is no longer an authority input.

## File and Responsibility Map

### Incumbent M paths: repair only

- Modify `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`
  - preserve the governed public Artifact identity/CAS shape;
  - document and enforce that a successful store receipt means physical referenceability, not merely a SQLite step.
- Modify `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`
  - add the singleton store metadata, owner-private recovery lifecycle, and recovery lease schema in the incumbent SQL path.
- Modify `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
  - enforce create-versus-reopen, FULL durability, two-phase anchor promotion, roots/floors, digest reopen, quarantine, lease recovery, lost-reply behavior, and exact lab-only fault barriers.

### Exact four E/A paths

- Create `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift`
  - one internal canonical anchor record/state machine and internal CAS port.
- Create `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift`
  - sole shipping Security.framework adapter and system-security client.
- Create `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift`
  - mechanism-only production configuration and factory.
- Modify `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
  - exact factory call and returned store handle; no route/profile/policy choice.

### Swift tests and necessary consumers

- Modify `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`
- Create `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift`
- Create `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoArtifactMeshAssemblyTests.swift`
- Modify `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift`
- Modify `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift`
- Modify `QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift`

The last three files only adapt incumbent callers to the required mechanism configuration; they add no owner or E/A slice.

### E/A evidence and physical verification

- Create `docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json`
- Modify `SampleHost/Package.swift`
- Create `SampleHost/ArtifactMeshDeviceLab/project.yml`
- Create generated `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj`
- Create generated shared scheme `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme`
- Create generated shared scheme `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme`
- Create `SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLabApp.swift`
- Create `SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLab.entitlements`
- Create `SampleHost/ArtifactMeshDeviceLab/CASContender/ArtifactMeshCASContenderApp.swift`
- Create `SampleHost/ArtifactMeshDeviceLab/Protocol/ArtifactMeshRecoveryProtocol.swift`
- Create `SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshRecoveryProbe.swift`
- Create `SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshFaultBootstrap.swift`
- Create `docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json`
- Create `scripts/run_artifact_mesh_device_recovery.py`
- Create `scripts/check_artifact_mesh_device_recovery.py`
- Create `scripts/test_check_artifact_mesh_device_recovery.py`

No device result, handoff result, archive, or raw trace is checked in. Phase A writes only non-authoritative compilation/preflight handoff bytes under `/private/tmp/qinao-artifact-mesh-w1-task0/`; its sole persistent governance delta is Task 10's one-file proposed owner-row transition. Phase B gives its raw broker output only to `ProtectedAdmissionClient.run_active_gates`; Artifact Mesh does not create or hand a privacy-clean admission leaf to any candidate evidence builder.

## Frozen Cross-Task Interfaces

The internal persistence interface is exactly:

```swift
protocol BASArtifactMeshAnchorPort: Sendable {
    func load() throws -> BASArtifactMeshAnchorLoad
    func compareAndSwap(
        expectedDigest: Data?,
        replacement: BASArtifactMeshAnchorRecord
    ) throws
}

enum BASArtifactMeshAnchorLoad: Sendable, Equatable {
    case absent
    case present(
        record: BASArtifactMeshAnchorRecord,
        canonicalBytes: Data,
        digest: Data
    )
}
```

The public mechanism-only factory is exactly:

```swift
public static func makeArtifactMeshStore(
    configuration: QinaoArtifactMeshConfiguration
) throws -> BASArtifactSQLiteStore
```

The sovereign host call seam is exactly one required argument:

```swift
artifactMeshConfiguration: QinaoArtifactMeshConfiguration
```

and `QinaoSovereignHost` exposes exactly one store handle:

```swift
public let artifactMesh: BASArtifactSQLiteStore
```

The admission and physical-gate surface is imported exactly from Bootstrap:

```text
ProtectedAdmissionClient.reopen_admitted_predecessor()
  -> AdmittedWaveV1
ProtectedAdmissionClient.pin_payload_and_issue_lease(
  payload_oid: str
) -> (PayloadProposalReceiptV1, EvaluationLease)
ProtectedAdmissionClient.run_active_gates(
  lease: EvaluationLease
) -> AuthenticatedGateResultBundle
ProtectedAdmissionClient.assemble_import_and_finalize(
  lease: EvaluationLease,
  gate_results: AuthenticatedGateResultBundle
) -> AdmittedWaveV1
```

`ExternalPhysicalGateBinding` and all receipt/envelope fields are opaque imports carried by the signed lease. This plan neither mirrors their schemas nor adds a wrapper authority. `run_active_gates` owns the controller-side external physical-broker phase; `assemble_import_and_finalize` exclusively owns output validation, Cw/Sw construction/import/reopen, intent, CAS, and final attestation.

The physical protocol operations, in frozen order, are:

```text
genesisReserve
genesisSQLiteCommit
genesisAnchorPromote
reopen
ordinaryPutAnchorPending
ordinaryPutSQLiteCommit
walShmCheckpoint
ordinaryPutAnchorFloorPromote
k3ReferenceCommit
quarantineInstall
recoveryLeaseAcquire
recoveryFloorUpdate
recoveryComplete
```

The exact terminal set is:

```text
resume
promote
clearPending
queryReconcile
quarantine
denyUnavailable
recoveryComplete
```

---

## Phase A — Admitted-W0 Input, Candidate-Local Task-0 Code and Preflight

### Task 1: Freeze the Exact Four-Slice E/A Manifest

**Files:**
- Create: `docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json`
- Test: `scripts/test_check_qinao_ea_extensions.py` from the admitted predecessor

**Interfaces:**
- Consumes: generic `qinao-extension-slice-v1` checker/schema, exact admitted W0 payload lineage, corrected historical `artifact.mesh = converging` Ledger preimage, iOS-27 floor, Section 11.2, and the four historical evidence paths.
- Produces: one non-empty, payload-index-bound W1 manifest with exactly four singular slices. It produces no M candidate and no gate result.

Every literal prerequisite ending
`qinao-owner-ledger-v1.json#artifact.mesh=converging` is a predecessor-bound
historical prerequisite ID. The generic checker resolves it against the
authenticated admitted-W0 Ledger preimage and carries that preimage digest
into the slice; it never requires the final W1 payload's current owner row to
remain `converging`. Task 10's later proposed `implemented` postimage
therefore cannot invalidate, rewrite, or reinterpret these four manifest
rows.

- [ ] **Step 1: Write the manifest and first let the checker reject missing implementation paths**

Create this exact JSON:

```json
{
  "schema_version": 1,
  "manifest_id": "qinao.artifact-mesh.w1.task0.v1",
  "manifest_kind": "ea_extensions",
  "workWave": "W1",
  "slices": [
    {
      "sliceID": "artifact-mesh.anchor-port-record.w1.v1",
      "existingOwnerID": "artifact.mesh",
      "classification": "E",
      "introductionWave": "W1",
      "workWave": "W1",
      "path": "BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift",
      "symbol": "BASArtifactMeshAnchorPort",
      "responsibilityID": "owner-private-anchor-record-and-cas-port",
      "wireChange": false,
      "prerequisiteIDs": [
        "BehavioralAISubstrate/Package.swift#iOS-27.0",
        "docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md#11.2",
        "docs/superpowers/specs/qinao-owner-ledger-v1.json#artifact.mesh=converging",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json",
        "docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json"
      ],
      "currentFixtureIDs": [
        "BehavioralAISubstrateTests.BASArtifactMeshKeychainAnchorTests.testAnchorRecordCanonicalRoundTrip"
      ],
      "backwardFixture": {
        "disposition": "notApplicable",
        "fixtureIDs": [],
        "historyProofID": "artifact-mesh-retrospective-create-correction-v1"
      },
      "futureFixtureIDs": [
        "BehavioralAISubstrateTests.BASArtifactMeshKeychainAnchorTests.testFutureAnchorRecordVersionFailsClosed"
      ],
      "storageProofRuleID": "artifact-mesh-anchor-keychain-cas-v1",
      "replayProofRuleID": "artifact-mesh-anchor-canonical-reopen-v1",
      "recoveryProofRuleID": "artifact-mesh-two-phase-floor-recovery-v1",
      "ownerBefore": "artifact.mesh",
      "ownerAfter": "artifact.mesh"
    },
    {
      "sliceID": "artifact-mesh.keychain-anchor.w1.v1",
      "existingOwnerID": "artifact.mesh",
      "classification": "A",
      "introductionWave": "W1",
      "workWave": "W1",
      "path": "BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift",
      "symbol": "BASArtifactMeshKeychainAnchor",
      "responsibilityID": "sole-shipping-keychain-anchor-adapter",
      "wireChange": false,
      "prerequisiteIDs": [
        "BehavioralAISubstrate/Package.swift#iOS-27.0",
        "docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md#11.2",
        "docs/superpowers/specs/qinao-owner-ledger-v1.json#artifact.mesh=converging",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json",
        "docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json"
      ],
      "currentFixtureIDs": [
        "BehavioralAISubstrateTests.BASArtifactMeshKeychainAnchorTests.testProductionSecurityQueryIsExact"
      ],
      "backwardFixture": {
        "disposition": "notApplicable",
        "fixtureIDs": [],
        "historyProofID": "artifact-mesh-retrospective-create-correction-v1"
      },
      "futureFixtureIDs": [
        "BehavioralAISubstrateTests.BASArtifactMeshKeychainAnchorTests.testMalformedOrFutureKeychainBytesFailClosed"
      ],
      "storageProofRuleID": "artifact-mesh-keychain-security-attributes-v1",
      "replayProofRuleID": "artifact-mesh-keychain-load-digest-v1",
      "recoveryProofRuleID": "artifact-mesh-keychain-unavailable-is-not-absent-v1",
      "ownerBefore": "artifact.mesh",
      "ownerAfter": "artifact.mesh"
    },
    {
      "sliceID": "artifact-mesh.qinao-assembly.w1.v1",
      "existingOwnerID": "artifact.mesh",
      "classification": "A",
      "introductionWave": "W1",
      "workWave": "W1",
      "path": "QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift",
      "symbol": "QinaoDefaults.makeArtifactMeshStore",
      "responsibilityID": "mechanism-only-production-store-factory",
      "wireChange": false,
      "prerequisiteIDs": [
        "QinaoRuntimeSDK/Package.swift#iOS-27.0",
        "docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md#11.2",
        "docs/superpowers/specs/qinao-owner-ledger-v1.json#artifact.mesh=converging",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json",
        "docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json"
      ],
      "currentFixtureIDs": [
        "QinaoRuntimeSDKTests.QinaoArtifactMeshAssemblyTests.testFactoryBuildsOnlyProductionStore"
      ],
      "backwardFixture": {
        "disposition": "notApplicable",
        "fixtureIDs": [],
        "historyProofID": "artifact-mesh-retrospective-create-correction-v1"
      },
      "futureFixtureIDs": [
        "QinaoRuntimeSDKTests.QinaoArtifactMeshAssemblyTests.testUnknownProtectionVersionFailsClosed"
      ],
      "storageProofRuleID": "artifact-mesh-qinao-production-factory-v1",
      "replayProofRuleID": "artifact-mesh-qinao-factory-reopen-v1",
      "recoveryProofRuleID": "artifact-mesh-qinao-factory-no-fallback-v1",
      "ownerBefore": "artifact.mesh",
      "ownerAfter": "artifact.mesh"
    },
    {
      "sliceID": "artifact-mesh.sovereign-host-call-seam.w1.v1",
      "existingOwnerID": "artifact.mesh",
      "classification": "A",
      "introductionWave": "W1",
      "workWave": "W1",
      "path": "QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift",
      "symbol": "QinaoDefaults.makeSovereignHost",
      "responsibilityID": "single-host-process-artifact-mesh-call-seam",
      "wireChange": false,
      "prerequisiteIDs": [
        "QinaoRuntimeSDK/Package.swift#iOS-27.0",
        "docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md#11.2",
        "docs/superpowers/specs/qinao-owner-ledger-v1.json#artifact.mesh=converging",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json",
        "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json",
        "docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json"
      ],
      "currentFixtureIDs": [
        "QinaoRuntimeSDKTests.QinaoArtifactMeshAssemblyTests.testSovereignHostOwnsExactFactoryStore"
      ],
      "backwardFixture": {
        "disposition": "notApplicable",
        "fixtureIDs": [],
        "historyProofID": "artifact-mesh-retrospective-create-correction-v1"
      },
      "futureFixtureIDs": [
        "QinaoRuntimeSDKTests.QinaoArtifactMeshAssemblyTests.testHostHasNoAnchorRouteOrProfileChoice"
      ],
      "storageProofRuleID": "artifact-mesh-host-single-store-reachability-v1",
      "replayProofRuleID": "artifact-mesh-host-reopen-same-store-v1",
      "recoveryProofRuleID": "artifact-mesh-host-no-injected-anchor-v1",
      "ownerBefore": "artifact.mesh",
      "ownerAfter": "artifact.mesh"
    }
  ]
}
```

- [ ] **Step 2: Run the RED checker**

```bash
python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
```

Expected: non-zero with all four missing implementation seams reported; it must report `slices=4`, not zero.

- [ ] **Step 3: Prove the M evidence was not expanded or relabeled**

```bash
python3 - <<'PY'
import json, pathlib
root = pathlib.Path(".")
paths = [
 "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json",
 "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json",
 "docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json",
]
expected = {
 "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
 "BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql",
 "BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift",
}
actual = {json.loads((root / p).read_text())["candidate_path"] for p in paths}
if actual != expected:
    raise SystemExit(f"historical M set drift: {sorted(actual)}")
correction = json.loads((root / "docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json").read_text())
if correction["status"] != "historical_non_atomicity_disclosed_forward_gate_required":
    raise SystemExit("retrospective correction was relabeled")
if {x["candidate_path"] for x in correction["paths"]} != expected:
    raise SystemExit("retrospective correction path set drift")
print("artifact-mesh-history: PASS m_paths=3 retrospective=true")
PY
```

Expected: `artifact-mesh-history: PASS m_paths=3 retrospective=true`.

- [ ] **Step 4: Commit the manifest alone**

```bash
git add docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json
git commit -m "docs(qinao): freeze artifact mesh W1 extensions"
```

Expected: one path, no production source.

---

### Task 2: Add the Internal Canonical Anchor Port and Record

**Files:**
- Create: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift`
- Create: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift`

**Interfaces:**
- Consumes: Foundation `Data`, Crypto `SHA256`, and owner-private primitive fields only.
- Produces: internal `BASArtifactMeshAnchorRecord`, `BASArtifactMeshAnchorLoad`, `BASArtifactMeshAnchorPort`, canonical bytes/digest, pending/commit transition validation, and an in-test memory port unavailable to production factory code.

- [ ] **Step 1: Write RED record tests**

Add these test names and assertions:

```swift
import Crypto
import Foundation
import Security
import XCTest
@testable import BASMemory

final class BASArtifactMeshKeychainAnchorTests: XCTestCase {
  func testAnchorRecordCanonicalRoundTrip() throws {
    let record = try Fixtures.committed(generation: 7)
    let bytes = try record.canonicalBytes()
    XCTAssertEqual(
        try BASArtifactMeshAnchorRecord(canonicalBytes: bytes),
        record)
    XCTAssertEqual(
        try record.digest(),
        Data(SHA256.hash(data: bytes)))
  }

  func testFutureAnchorRecordVersionFailsClosed() throws {
    let bytes = Data(
        #"{"schemaVersion":2}"#.utf8)
    XCTAssertThrowsError(
        try BASArtifactMeshAnchorRecord(canonicalBytes: bytes))
  }

  func testTransitionValidatorAcceptsOnlyExactPendingAndPromotion()
      throws
  {
    let g7 = try Fixtures.committed(generation: 7)
    let pending = try g7.addingPending(
        Fixtures.pending(from: g7, generation: 8))
    XCTAssertNoThrow(
        try BASArtifactMeshAnchorRecord.validateTransition(
            from: g7, to: pending))
    let promoted = try pending.promotingPending()
    XCTAssertNoThrow(
        try BASArtifactMeshAnchorRecord.validateTransition(
            from: pending, to: promoted))
    XCTAssertThrowsError(
        try BASArtifactMeshAnchorRecord.validateTransition(
            from: g7, to: try Fixtures.committed(generation: 9)))
  }
}
```

Put this deterministic support in the same test file; it supplies every field
and contains no random/defaulted evidence:

```swift
private enum Fixtures {
    static let containerID = "com.qinao.tests"
    static let storeRole = "primary"
    static let storeIdentity = UUID(uuidString:
      "00000000-0000-0000-0000-000000000201")!
    static let accessGroup = "TEAMID.com.qinao.artifact-mesh-device-lab"

    static func digest(_ label: String) -> String {
        SHA256.hash(data: Data(label.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    static func floor(
        generation: UInt64,
        previousCommittedDigest: String
    ) -> BASArtifactMeshAnchorFloor {
        BASArtifactMeshAnchorFloor(
            generation: generation,
            schemaVersion: 2,
            commitmentKeyID: "artifact-mesh-test-key",
            commitmentKeyEpoch: 1,
            recordCount: generation + 1,
            recordRoot: digest("record-root-\(generation)"),
            casHeadRoot: digest("cas-head-root-\(generation)"),
            casRevisionFloor: generation,
            ordinaryPutFloor: generation,
            recoveryFloor: generation,
            previousCommittedDigest: previousCommittedDigest)
    }

    static func committed(
        generation: UInt64
    ) throws -> BASArtifactMeshAnchorRecord {
        BASArtifactMeshAnchorRecord(
            applicationContainerID: containerID,
            storeRole: storeRole,
            storeIdentity: storeIdentity,
            committed: floor(
              generation: generation,
              previousCommittedDigest: generation == 0
                ? String(repeating: "0", count: 64)
                : digest("prior-anchor-\(generation - 1)")),
            pending: nil)
    }

    static func pending(
        from current: BASArtifactMeshAnchorRecord,
        generation: UInt64
    ) throws -> BASArtifactMeshPendingTransaction {
        let previous = try current.digest()
            .map { String(format: "%02x", $0) }.joined()
        return BASArtifactMeshPendingTransaction(
            kind: .floorAdvance,
            transactionID: UUID(uuidString:
              "00000000-0000-0000-0000-000000000202")!,
            createRequestID: nil,
            proposed: floor(
              generation: generation,
              previousCommittedDigest: previous),
            expectedPreviousDigest: previous,
            expectedDatabaseAbsent: false)
    }
}
```

In the same uncommitted RED edit, create
`BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift` as
the smallest compileable stub. Declare the exact types, stored fields,
initializers, and method signatures consumed by the tests and frozen in Step
3, including a temporary
`BASArtifactMeshAnchorRecordError.unimplemented`. Initializers may only
retain their arguments; every canonicalization, digest, transition, pending,
or promotion operation throws `.unimplemented`. The stub performs no I/O,
hashing, defaulting, or transition acceptance and must not be staged.

- [ ] **Step 2: Run RED**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
```

Expected: SwiftPM's list phase succeeds and discovers every named test; the
suite executes and exits non-zero because the stub reports
`.unimplemented`. A compile/list failure, zero discovery, or failure caused
by a missing symbol is invalid RED.

- [ ] **Step 3: Implement the exact internal record**

Replace the Step-1 stub in place, remove `.unimplemented`, and implement these
exact internal types:

```swift
import Crypto
import Foundation

enum BASArtifactMeshAnchorRecordError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(UInt64)
    case nonCanonicalEncoding
    case invalidField(String)
    case invalidTransition(String)
    case noPendingTransaction
}

struct BASArtifactMeshAnchorFloor: Codable, Sendable, Equatable {
    let generation: UInt64
    let schemaVersion: UInt64
    let commitmentKeyID: String
    let commitmentKeyEpoch: UInt64
    let recordCount: UInt64
    let recordRoot: String
    let casHeadRoot: String
    let casRevisionFloor: UInt64
    let ordinaryPutFloor: UInt64
    let recoveryFloor: UInt64
    let previousCommittedDigest: String
}

struct BASArtifactMeshPendingTransaction:
    Codable, Sendable, Equatable
{
    enum Kind: String, Codable, Sendable {
        case genesis
        case floorAdvance
    }

    let kind: Kind
    let transactionID: UUID
    let createRequestID: UUID?
    let proposed: BASArtifactMeshAnchorFloor
    let expectedPreviousDigest: String
    let expectedDatabaseAbsent: Bool
}

struct BASArtifactMeshAnchorRecord: Codable, Sendable, Equatable {
    static let currentSchemaVersion: UInt64 = 1
    static let currentProtectionVersion: UInt64 = 1

    let schemaVersion: UInt64
    let applicationContainerID: String
    let storeRole: String
    let storeIdentity: UUID
    let protectionVersion: UInt64
    let committed: BASArtifactMeshAnchorFloor?
    let pending: BASArtifactMeshPendingTransaction?

    init(
        schemaVersion: UInt64 = Self.currentSchemaVersion,
        applicationContainerID: String,
        storeRole: String,
        storeIdentity: UUID,
        protectionVersion: UInt64 = Self.currentProtectionVersion,
        committed: BASArtifactMeshAnchorFloor?,
        pending: BASArtifactMeshPendingTransaction?
    ) {
        self.schemaVersion = schemaVersion
        self.applicationContainerID = applicationContainerID
        self.storeRole = storeRole
        self.storeIdentity = storeIdentity
        self.protectionVersion = protectionVersion
        self.committed = committed
        self.pending = pending
    }

    func canonicalBytes() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    init(canonicalBytes: Data) throws {
        let decoded = try JSONDecoder().decode(Self.self, from: canonicalBytes)
        try decoded.validate()
        guard try decoded.canonicalBytes() == canonicalBytes else {
            throw BASArtifactMeshAnchorRecordError.nonCanonicalEncoding
        }
        self = decoded
    }

    func digest() throws -> Data {
        Data(SHA256.hash(data: try canonicalBytes()))
    }
}

enum BASArtifactMeshAnchorLoad: Sendable, Equatable {
    case absent
    case present(
        record: BASArtifactMeshAnchorRecord,
        canonicalBytes: Data,
        digest: Data
    )
}

protocol BASArtifactMeshAnchorPort: Sendable {
    func load() throws -> BASArtifactMeshAnchorLoad
    func compareAndSwap(
        expectedDigest: Data?,
        replacement: BASArtifactMeshAnchorRecord
    ) throws
}
```

Implement `validate()` with all of these exact predicates:

```text
schemaVersion == 1
protectionVersion == 1
applicationContainerID and storeRole are non-empty NFC strings without control characters
recordRoot/casHeadRoot/previousCommittedDigest/expectedPreviousDigest are 64 lowercase hex
committed == nil iff pending.kind == genesis
genesis has generation 0, createRequestID present, expectedDatabaseAbsent true
floorAdvance has committed present, createRequestID absent, expectedDatabaseAbsent false
genesis pending has proposed.generation == 0 and expectedPreviousDigest == 64 zeroes
floorAdvance pending has proposed.generation == committed.generation + 1 without overflow
floorAdvance pending.expectedPreviousDigest equals lowercase hex digest of the committed-only record
schema/key/protection/container/role/storeIdentity never change within one transition
recordCount, casRevisionFloor, ordinaryPutFloor, and recoveryFloor never decrease
```

Use this implementation immediately below the type declarations:

```swift
private func artifactMeshHex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

private func artifactMeshIsLowerHex64(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy {
          ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
      }
}

private func artifactMeshValidName(_ value: String) -> Bool {
    !value.isEmpty
      && value == value.precomposedStringWithCanonicalMapping
      && value.unicodeScalars.allSatisfy {
          !CharacterSet.controlCharacters.contains($0)
      }
}

extension BASArtifactMeshAnchorRecord {
    private func validateFloor(
        _ floor: BASArtifactMeshAnchorFloor
    ) throws {
        guard floor.schemaVersion == 2 else {
            throw BASArtifactMeshAnchorRecordError.invalidField(
              "storage schema version")
        }
        guard artifactMeshValidName(floor.commitmentKeyID),
              floor.commitmentKeyEpoch > 0 else {
            throw BASArtifactMeshAnchorRecordError.invalidField(
              "commitment key")
        }
        for (name, value) in [
            ("recordRoot", floor.recordRoot),
            ("casHeadRoot", floor.casHeadRoot),
            ("previousCommittedDigest",
             floor.previousCommittedDigest),
        ] where !artifactMeshIsLowerHex64(value) {
            throw BASArtifactMeshAnchorRecordError.invalidField(name)
        }
    }

    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw BASArtifactMeshAnchorRecordError
              .unsupportedSchemaVersion(schemaVersion)
        }
        guard protectionVersion == Self.currentProtectionVersion else {
            throw BASArtifactMeshAnchorRecordError.invalidField(
              "protectionVersion")
        }
        guard artifactMeshValidName(applicationContainerID),
              artifactMeshValidName(storeRole) else {
            throw BASArtifactMeshAnchorRecordError.invalidField(
              "container-or-role")
        }
        if let committed { try validateFloor(committed) }
        if let pending { try validateFloor(pending.proposed) }

        switch (committed, pending) {
        case (nil, .some(let value)):
            guard value.kind == .genesis,
                  value.createRequestID != nil,
                  value.expectedDatabaseAbsent,
                  value.proposed.generation == 0,
                  value.expectedPreviousDigest
                    == String(repeating: "0", count: 64),
                  value.proposed.previousCommittedDigest
                    == value.expectedPreviousDigest else {
                throw BASArtifactMeshAnchorRecordError.invalidField(
                  "genesis")
            }

        case (.some(_), nil):
            break

        case (.some(let old), .some(let value)):
            let (next, overflow) =
              old.generation.addingReportingOverflow(1)
            let committedOnly = BASArtifactMeshAnchorRecord(
                applicationContainerID: applicationContainerID,
                storeRole: storeRole,
                storeIdentity: storeIdentity,
                committed: old,
                pending: nil)
            let previous = artifactMeshHex(
              try committedOnly.digest())
            guard value.kind == .floorAdvance,
                  value.createRequestID == nil,
                  !value.expectedDatabaseAbsent,
                  !overflow,
                  value.proposed.generation == next,
                  value.expectedPreviousDigest == previous,
                  value.proposed.previousCommittedDigest == previous,
                  value.proposed.schemaVersion == old.schemaVersion,
                  value.proposed.commitmentKeyID
                    == old.commitmentKeyID,
                  value.proposed.commitmentKeyEpoch
                    == old.commitmentKeyEpoch,
                  value.proposed.recordCount >= old.recordCount,
                  value.proposed.casRevisionFloor
                    >= old.casRevisionFloor,
                  value.proposed.ordinaryPutFloor
                    >= old.ordinaryPutFloor,
                  value.proposed.recoveryFloor
                    >= old.recoveryFloor else {
                throw BASArtifactMeshAnchorRecordError.invalidField(
                  "floorAdvance")
            }

        case (nil, nil):
            throw BASArtifactMeshAnchorRecordError.invalidField(
              "empty-anchor")
        }
    }

    static func validateTransition(
        from old: Self?,
        to new: Self
    ) throws {
        try new.validate()
        guard let old else {
            guard new.committed == nil,
                  new.pending?.kind == .genesis else {
                throw BASArtifactMeshAnchorRecordError
                  .invalidTransition("first record is not genesis")
            }
            return
        }
        try old.validate()
        guard old.schemaVersion == new.schemaVersion,
              old.applicationContainerID
                == new.applicationContainerID,
              old.storeRole == new.storeRole,
              old.storeIdentity == new.storeIdentity,
              old.protectionVersion == new.protectionVersion else {
            throw BASArtifactMeshAnchorRecordError
              .invalidTransition("identity changed")
        }
        switch (old.committed, old.pending,
                new.committed, new.pending) {
        case (.some(let committed), nil,
              .some(let same), .some(_)):
            guard committed == same else {
                throw BASArtifactMeshAnchorRecordError
                  .invalidTransition("pending rewrote committed floor")
            }
        case (nil, .some(let pending), .some(let promoted), nil):
            guard pending.kind == .genesis,
                  pending.proposed == promoted else {
                throw BASArtifactMeshAnchorRecordError
                  .invalidTransition("bad genesis promotion")
            }
        case (.some(let committed), .some(let pending),
              .some(let promoted), nil):
            guard promoted == pending.proposed
                    || promoted == committed else {
                throw BASArtifactMeshAnchorRecordError
                  .invalidTransition("bad floor promotion/clear")
            }
        default:
            throw BASArtifactMeshAnchorRecordError
              .invalidTransition("unsupported transition")
        }
    }

    func addingPending(
        _ value: BASArtifactMeshPendingTransaction
    ) throws -> Self {
        guard pending == nil else {
            throw BASArtifactMeshAnchorRecordError
              .invalidTransition("pending already exists")
        }
        let replacement = Self(
            applicationContainerID: applicationContainerID,
            storeRole: storeRole,
            storeIdentity: storeIdentity,
            protectionVersion: protectionVersion,
            committed: committed,
            pending: value)
        try Self.validateTransition(from: self, to: replacement)
        return replacement
    }

    func promotingPending() throws -> Self {
        guard let pending else {
            throw BASArtifactMeshAnchorRecordError.noPendingTransaction
        }
        let replacement = Self(
            applicationContainerID: applicationContainerID,
            storeRole: storeRole,
            storeIdentity: storeIdentity,
            protectionVersion: protectionVersion,
            committed: pending.proposed,
            pending: nil)
        try Self.validateTransition(from: self, to: replacement)
        return replacement
    }
}
```

`validateTransition(from:to:)`, `addingPending(_:)`, and
`promotingPending()` therefore permit only:

```text
absent -> genesisPending(g=0)
committed(g) -> committed(g)+pending(g+1)
committed(g)+pending(g+1) -> committed(g+1)
committed(g)+pending(g+1) -> byte-identical committed(g) only after SQLite proves no transaction
```

Task 0 exposes no genesis-reset method because the mapped trust/operator authorization is not supplied here. An expired or withdrawn genesis therefore remains blocked with its pending record preserved; the generic transition validator cannot erase it.

- [ ] **Step 4: Run GREEN**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
```

Expected: `BASArtifactMeshKeychainAnchorTests` executes at least 3 tests with 0 failures.

- [ ] **Step 5: Commit the internal record/port**

```bash
git add \
  BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift
git commit -m "feat(artifact-mesh): add owner-private anchor record"
```

Expected: exactly two paths.

---


### Task 3: Implement the Sole Shipping Keychain Anchor

**Files:**
- Create: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift`
- Physical cross-process proof: the two separately signed DeviceLab app processes specified in Task 7 and driven by Task 9; no production helper target is added.

**Interfaces:**
- Consumes: `BASArtifactMeshAnchorPort` and canonical anchor bytes.
- Produces: internal final `BASArtifactMeshKeychainAnchor`, exact Security query construction, typed unavailable/corrupt/conflict errors, and no public or injectable shipping writer.

- [ ] **Step 1: Write RED Security-query and failure-semantics tests**

Add:

```swift
func testProductionSecurityQueryIsExact() throws {
    let security = RecordingSecurityClient(items: [])
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertEqual(try anchor.load(), .absent)
    XCTAssertEqual(security.lastScope?.service,
                   "com.qinao.artifact-mesh.anchor.v1")
    XCTAssertEqual(security.lastScope?.accessible,
                   "after-first-unlock-this-device-only")
    XCTAssertEqual(security.lastScope?.synchronizable, false)
    XCTAssertEqual(
      security.lastScope?.useDataProtectionKeychain, true)
    XCTAssertEqual(security.lastScope?.accessGroup,
                   "TEAMID.com.qinao.artifact-mesh-device-lab")
}

func testInteractionNotAllowedIsUnavailableNotAbsent() throws {
    let security = RecordingSecurityClient(
        copyStatus: errSecInteractionNotAllowed)
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertThrowsError(try anchor.load()) {
        XCTAssertEqual(
            $0 as? BASArtifactMeshKeychainAnchor.Error,
            .protectedDataUnavailable)
    }
}

func testMalformedOrFutureKeychainBytesFailClosed() throws {
    let security = RecordingSecurityClient(
        items: [Fixtures.malformedSecurityItem(
          value: Data(#"{"schemaVersion":2}"#.utf8))])
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertThrowsError(try anchor.load())
}

func testCompareAndSwapRejectsDigestRace() throws {
    let initial = try Fixtures.committed(generation: 1)
    let security = RecordingSecurityClient(
        items: [try Fixtures.securityItem(for: initial)])
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertThrowsError(
        try anchor.compareAndSwap(
            expectedDigest: Data(repeating: 0, count: 32),
            replacement: try Fixtures.committed(generation: 2)))
}

func testSecondIndependentAnchorInstanceCannotReuseOldDigest() throws {
    let initial = try Fixtures.committed(generation: 1)
    let replacement = try Fixtures.committed(generation: 2)
    let security = RecordingSecurityClient(
        items: [try Fixtures.securityItem(for: initial)])
    let first = try Fixtures.keychainAnchor(security: security)
    let second = try Fixtures.keychainAnchor(security: security)
    let expected = try initial.digest()
    try first.compareAndSwap(
        expectedDigest: expected,
        replacement: replacement)
    XCTAssertThrowsError(
        try second.compareAndSwap(
            expectedDigest: expected,
            replacement: try Fixtures.committed(generation: 3))) {
        XCTAssertEqual(
            $0 as? BASArtifactMeshKeychainAnchor.Error,
            .compareAndSwapConflict)
    }
}

func testExactOldAccountItemNotFoundMapsToCASConflict() throws {
    let initial = try Fixtures.committed(generation: 1)
    let security = RecordingSecurityClient(
        items: [try Fixtures.securityItem(for: initial)])
    security.updateStatus = errSecItemNotFound
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertThrowsError(
        try anchor.compareAndSwap(
          expectedDigest: try initial.digest(),
          replacement: try Fixtures.committed(generation: 2))) {
        XCTAssertEqual(
          $0 as? BASArtifactMeshKeychainAnchor.Error,
          .compareAndSwapConflict)
    }
}

func testCopyRejectsTwoAccountsForOneStableSlot() throws {
    let security = RecordingSecurityClient(
        items: [
          try Fixtures.securityItem(
            for: Fixtures.committed(generation: 1)),
          try Fixtures.securityItem(
            for: Fixtures.committed(generation: 2)),
        ])
    let anchor = try Fixtures.keychainAnchor(security: security)
    XCTAssertThrowsError(try anchor.load()) {
        XCTAssertEqual(
            $0 as? BASArtifactMeshKeychainAnchor.Error,
            .itemCorrupt)
    }
}
```

The mandatory test named
`testTwoIndependentProcessesHaveExactlyOneCASWinner` is a DeviceLab physical
test specified in Tasks 7–9: two separately signed lab applications import the
same production `BASArtifactMeshKeychainAnchor`, share only one challenge-
scoped lab Keychain access group, publish distinct process identities, and
require exactly one `winner` and one `compareAndSwapConflict`. An in-process
thread/task pair cannot satisfy it.

In the same uncommitted RED edit, create
`BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift`
as the smallest compileable stub. Declare the exact scope, security-item,
security-client, anchor, initializer, and method signatures consumed by these
tests and frozen in Step 3. Add temporary
`BASArtifactMeshKeychainAnchor.Error.unimplemented`; `load` and
`compareAndSwap` throw it without issuing a Security call. The Task-2 anchor
record suite must still compile and remain green. Do not stage the stub.

- [ ] **Step 2: Run RED**

Run the non-empty BAS filter from Task 2.

Expected: SwiftPM successfully lists and executes the expanded suite. The
Task-2 record tests remain green and the new Security/CAS tests fail
semantically on `.unimplemented`; compile/list failure or zero discovery is
invalid RED.

- [ ] **Step 3: Implement exact Keychain behavior**

Replace the Step-1 stub in place, remove `.unimplemented`, and use these
internal declarations:

```swift
import Crypto
import Foundation
import BASRuntimeCore
#if canImport(Security)
import Security
#endif

struct BASArtifactMeshKeychainScope: Sendable, Equatable {
    let service: String
    let stableAccountPrefix: String
    let accessGroup: String
    let accessible: String
    let synchronizable: Bool
    let useDataProtectionKeychain: Bool
}

struct BASArtifactMeshSecurityItem: Sendable, Equatable {
    let account: String
    let value: Data
}

enum BASArtifactMeshSecurityCopyResult: Sendable, Equatable {
    case items([BASArtifactMeshSecurityItem])
    case status(Int32)
}

protocol BASArtifactMeshSecurityClient: Sendable {
    func copy(
        scope: BASArtifactMeshKeychainScope
    ) -> BASArtifactMeshSecurityCopyResult
    func add(
        scope: BASArtifactMeshKeychainScope,
        account: String,
        value: Data
    ) -> Int32
    func update(
        scope: BASArtifactMeshKeychainScope,
        expectedAccount: String,
        replacementAccount: String,
        value: Data
    ) -> Int32
}

final class BASArtifactMeshKeychainAnchor:
    BASArtifactMeshAnchorPort, @unchecked Sendable
{
    enum Error: Swift.Error, Sendable, Equatable {
        case platformUnavailable
        case protectedDataUnavailable
        case itemCorrupt
        case compareAndSwapConflict
        case invalidConfiguration(String)
        case osStatus(Int32)
    }

    static let service = "com.qinao.artifact-mesh.anchor.v1"

    private let scope: BASArtifactMeshKeychainScope
    private let security: any BASArtifactMeshSecurityClient

    private init(
        scope: BASArtifactMeshKeychainScope,
        security: any BASArtifactMeshSecurityClient
    ) {
        self.scope = scope
        self.security = security
    }
}
```

Append this complete deterministic test adapter and factory to
`BASArtifactMeshKeychainAnchorTests.swift`:

```swift
private final class RecordingSecurityClient:
    BASArtifactMeshSecurityClient, @unchecked Sendable
{
    private let lock = NSLock()
    private var items: [BASArtifactMeshSecurityItem]
    private let copyStatus: Int32?
    private(set) var lastScope: BASArtifactMeshKeychainScope?
    private(set) var lastExpectedAccount: String?
    private(set) var lastReplacementAccount: String?
    var addStatus: Int32 = errSecSuccess
    var updateStatus: Int32 = errSecSuccess

    init(
        items: [BASArtifactMeshSecurityItem] = [],
        copyStatus: Int32? = nil
    ) {
        self.items = items
        self.copyStatus = copyStatus
    }

    func copy(
        scope: BASArtifactMeshKeychainScope
    ) -> BASArtifactMeshSecurityCopyResult {
        lock.lock()
        defer { lock.unlock() }
        lastScope = scope
        if let copyStatus { return .status(copyStatus) }
        return .items(items.filter {
          $0.account.hasPrefix(scope.stableAccountPrefix)
        })
    }

    func add(
        scope: BASArtifactMeshKeychainScope,
        account: String,
        value: Data
    ) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        lastScope = scope
        if items.contains(where: { $0.account == account }) {
            return errSecDuplicateItem
        }
        if addStatus == errSecSuccess {
            items.append(.init(account: account, value: value))
        }
        return addStatus
    }

    func update(
        scope: BASArtifactMeshKeychainScope,
        expectedAccount: String,
        replacementAccount: String,
        value: Data
    ) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        lastScope = scope
        lastExpectedAccount = expectedAccount
        lastReplacementAccount = replacementAccount
        guard let index = items.firstIndex(where: {
          $0.account == expectedAccount
        }) else {
            return errSecItemNotFound
        }
        if updateStatus == errSecSuccess {
            items[index] = .init(
              account: replacementAccount, value: value)
        }
        return updateStatus
    }
}

private extension Fixtures {
    static var stableAccountPrefix: String {
        let slotBytes =
          BASSovereignCanonicalBytes.lengthPrefixed([
            "qinao-artifact-mesh-anchor-account-v1",
            containerID.precomposedStringWithCanonicalMapping,
            storeRole.precomposedStringWithCanonicalMapping,
          ])
        let slot = SHA256.hash(data: slotBytes)
          .map { String(format: "%02x", $0) }.joined()
        return "qinao-v1:\(slot):"
    }

    static func securityItem(
        for record: BASArtifactMeshAnchorRecord
    ) throws -> BASArtifactMeshSecurityItem {
        let digest = try record.digest().map {
          String(format: "%02x", $0)
        }.joined()
        return .init(
          account:
            "\(stableAccountPrefix)g\(record.generation):d\(digest)",
          value: try record.canonicalBytes())
    }

    static func malformedSecurityItem(
        value: Data
    ) -> BASArtifactMeshSecurityItem {
        .init(
          account: "\(stableAccountPrefix)g1:d" +
            String(repeating: "0", count: 64),
          value: value)
    }

    static func keychainAnchor(
        security: RecordingSecurityClient
    ) throws -> BASArtifactMeshKeychainAnchor {
        try BASArtifactMeshKeychainAnchor(
            applicationContainerID: containerID,
            storeRole: storeRole,
            accessGroup: accessGroup,
            security: security)
    }
}
```

Derive the stable slot prefix exactly as lowercase hex SHA-256 over:

```swift
let slotBytes = BASSovereignCanonicalBytes.lengthPrefixed([
    "qinao-artifact-mesh-anchor-account-v1",
    applicationContainerID.precomposedStringWithCanonicalMapping,
    storeRole.precomposedStringWithCanonicalMapping
])
let slot = SHA256.hash(data: slotBytes)
  .map { String(format: "%02x", $0) }.joined()
let stableAccountPrefix = "qinao-v1:\(slot):"
```

For a present record, derive its primary-key account exactly as:

```swift
func stateAccount(
    prefix: String,
    record: BASArtifactMeshAnchorRecord
) throws -> String {
    let digest = try record.digest().map {
      String(format: "%02x", $0)
    }.joined()
    return "\(prefix)g\(record.generation):d\(digest)"
}
```

The old account therefore binds both the current generation and the expected
canonical-record digest. The one absence-reservation account is exactly
`"\(stableAccountPrefix)reservation"`. It is used only to make concurrent
`expectedDigest == nil` creation single-winner: `SecItemAdd` first claims that
one composite key, then an exact-account `SecItemUpdate` atomically promotes
the reservation to the state account. A crash between those operations is
recovered by decoding the reserved value and idempotently promoting it; it is
never treated as absence.

Apple's Security documentation for
[`kSecClassGenericPassword`](https://developer.apple.com/documentation/security/ksecclassgenericpassword)
defines the generic-password attributes, including service and account, that
form its composite primary key, and duplicate adds fail. Apple's
[`SecItemUpdate`](https://developer.apple.com/documentation/security/secitemupdate%28_%3A_%3A%29)
applies changes to items selected by the query. This plan therefore uses an
exact old primary-key account in the query and changes account plus data in one
`SecItemUpdate`; `kSecAttrGeneric` is merely a user-defined attribute and is
not used for selection, uniqueness, or CAS.

The system client's fixed scope dictionary is exactly:

```swift
[
  kSecClass as String: kSecClassGenericPassword,
  kSecAttrService as String: scope.service,
  kSecAttrAccessGroup as String: scope.accessGroup,
  kSecAttrSynchronizable as String: false,
  kSecUseDataProtectionKeychain as String: true
]
```

`add` additionally sets the exact account,
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, and `kSecValueData`.
`copy` omits account, requests attributes plus data with
`kSecMatchLimitAll`, filters only accounts having the exact stable prefix, and
fails corrupt on more than one item. `update` adds the expected account to its
query and atomically changes both `kSecAttrAccount` and `kSecValueData`.
`errSecItemNotFound` from that update is a CAS conflict, not absence.
`errSecInteractionNotAllowed` and `errSecNotAvailable` are typed
`.protectedDataUnavailable`; every other non-success status is `.osStatus`.

Use this complete mechanism below the declarations:

```swift
#if canImport(Security)
private struct BASSystemArtifactMeshSecurityClient:
    BASArtifactMeshSecurityClient
{
    private func scopeQuery(
        _ scope: BASArtifactMeshKeychainScope
    ) -> [String: Any] {
        [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: scope.service,
          kSecAttrAccessGroup as String: scope.accessGroup,
          kSecAttrSynchronizable as String: false,
          kSecUseDataProtectionKeychain as String: true,
        ]
    }

    func copy(
        scope: BASArtifactMeshKeychainScope
    ) -> BASArtifactMeshSecurityCopyResult {
        var attributes = scopeQuery(scope)
        attributes[kSecReturnData as String] = true
        attributes[kSecReturnAttributes as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitAll
        var value: CFTypeRef?
        let status = SecItemCopyMatching(
          attributes as CFDictionary, &value)
        if status == errSecItemNotFound {
            return .items([])
        }
        guard status == errSecSuccess else {
            return .status(status)
        }
        let rows: [[String: Any]]
        if let row = value as? [String: Any] {
            rows = [row]
        } else if let values = value as? [[String: Any]] {
            rows = values
        } else {
            return .status(errSecDecode)
        }
        var items: [BASArtifactMeshSecurityItem] = []
        for row in rows {
            guard let account =
                    row[kSecAttrAccount as String] as? String,
                  let data = row[kSecValueData as String] as? Data else {
                return .status(errSecDecode)
            }
            if account.hasPrefix(scope.stableAccountPrefix) {
                items.append(.init(account: account, value: data))
            }
        }
        return .items(items)
    }

    func add(
        scope: BASArtifactMeshKeychainScope,
        account: String,
        value: Data
    ) -> Int32 {
        var attributes = scopeQuery(scope)
        attributes[kSecAttrAccount as String] = account
        attributes[kSecAttrAccessible as String] =
          kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecValueData as String] = value
        return SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(
        scope: BASArtifactMeshKeychainScope,
        expectedAccount: String,
        replacementAccount: String,
        value: Data
    ) -> Int32 {
        var query = scopeQuery(scope)
        query[kSecAttrAccount as String] = expectedAccount
        return SecItemUpdate(
          query as CFDictionary,
          [
            kSecAttrAccount as String: replacementAccount,
            kSecValueData as String: value,
          ] as CFDictionary)
    }
}
#endif

extension BASArtifactMeshKeychainAnchor {
    convenience init(
        applicationContainerID: String,
        storeRole: String,
        accessGroup: String
    ) throws {
#if canImport(Security)
        try self.init(
          applicationContainerID: applicationContainerID,
          storeRole: storeRole,
          accessGroup: accessGroup,
          security: BASSystemArtifactMeshSecurityClient())
#else
        throw Error.platformUnavailable
#endif
    }

    convenience init(
        applicationContainerID: String,
        storeRole: String,
        accessGroup: String,
        security: any BASArtifactMeshSecurityClient
    ) throws {
        for (name, value) in [
            ("applicationContainerID", applicationContainerID),
            ("storeRole", storeRole),
            ("accessGroup", accessGroup),
        ] {
            guard !value.isEmpty,
                  value == value.precomposedStringWithCanonicalMapping,
                  value.unicodeScalars.allSatisfy({
                    !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw Error.invalidConfiguration(name)
            }
        }
        let slotBytes =
          BASSovereignCanonicalBytes.lengthPrefixed([
            "qinao-artifact-mesh-anchor-account-v1",
            applicationContainerID
              .precomposedStringWithCanonicalMapping,
            storeRole.precomposedStringWithCanonicalMapping,
          ])
        let slot = SHA256.hash(data: slotBytes)
          .map { String(format: "%02x", $0) }.joined()
        let scope = BASArtifactMeshKeychainScope(
            service: Self.service,
            stableAccountPrefix: "qinao-v1:\(slot):",
            accessGroup: accessGroup,
            accessible:
              "after-first-unlock-this-device-only",
            synchronizable: false,
            useDataProtectionKeychain: true)
        self.init(scope: scope, security: security)
    }

    private func mapStatus(_ status: Int32) throws {
#if canImport(Security)
        if status == errSecInteractionNotAllowed
            || status == errSecNotAvailable {
            throw Error.protectedDataUnavailable
        }
        if status == errSecDuplicateItem
            || status == errSecItemNotFound {
            throw Error.compareAndSwapConflict
        }
#endif
        throw Error.osStatus(status)
    }

    private var reservationAccount: String {
        "\(scope.stableAccountPrefix)reservation"
    }

    private func stateAccount(
        for record: BASArtifactMeshAnchorRecord
    ) throws -> String {
        let digest = try record.digest().map {
          String(format: "%02x", $0)
        }.joined()
        return "\(scope.stableAccountPrefix)" +
          "g\(record.generation):d\(digest)"
    }

    private func decode(
        _ item: BASArtifactMeshSecurityItem
    ) throws -> BASArtifactMeshAnchorLoad {
        do {
            let record = try BASArtifactMeshAnchorRecord(
              canonicalBytes: item.value)
            let digest = try record.digest()
            guard item.account == stateAccount(for: record) else {
                throw Error.itemCorrupt
            }
            return .present(
              record: record,
              canonicalBytes: item.value,
              digest: digest)
        } catch let error as Error {
            throw error
        } catch {
            throw Error.itemCorrupt
        }
    }

    private func loadOnce(
        recoverReservation: Bool
    ) throws -> BASArtifactMeshAnchorLoad {
        switch security.copy(scope: scope) {
        case .items(let items):
            if items.isEmpty { return .absent }
            guard items.count == 1, let item = items.first else {
                throw Error.itemCorrupt
            }
            guard item.account == reservationAccount else {
                return try decode(item)
            }
            guard recoverReservation else {
                throw Error.itemCorrupt
            }
            let record: BASArtifactMeshAnchorRecord
            do {
                record = try BASArtifactMeshAnchorRecord(
                  canonicalBytes: item.value)
            } catch {
                throw Error.itemCorrupt
            }
            let replacementAccount = try stateAccount(for: record)
            let status = security.update(
              scope: scope,
              expectedAccount: reservationAccount,
              replacementAccount: replacementAccount,
              value: item.value)
#if canImport(Security)
            if status == errSecSuccess {
                return try decode(.init(
                  account: replacementAccount,
                  value: item.value))
            }
            if status == errSecItemNotFound {
                return try loadOnce(recoverReservation: false)
            }
#else
            if status == 0 {
                return try decode(.init(
                  account: replacementAccount,
                  value: item.value))
            }
#endif
            try mapStatus(status)
            preconditionFailure("mapStatus always throws")
        case .status(let status):
            try mapStatus(status)
            preconditionFailure("mapStatus always throws")
        }
    }

    private func constantTimeEqual(
        _ lhs: Data,
        _ rhs: Data
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }

    func load() throws -> BASArtifactMeshAnchorLoad {
        try loadOnce(recoverReservation: true)
    }

    func compareAndSwap(
        expectedDigest: Data?,
        replacement: BASArtifactMeshAnchorRecord
    ) throws {
        let current = try loadOnce(recoverReservation: true)
        let replacementBytes = try replacement.canonicalBytes()
        let replacementAccount = try stateAccount(for: replacement)
        switch (current, expectedDigest) {
        case (.absent, nil):
            try BASArtifactMeshAnchorRecord.validateTransition(
              from: nil, to: replacement)
            let addStatus = security.add(
              scope: scope,
              account: reservationAccount,
              value: replacementBytes)
#if canImport(Security)
            guard addStatus == errSecSuccess else {
                try mapStatus(addStatus)
                return
            }
#else
            guard addStatus == 0 else {
                try mapStatus(addStatus)
                return
            }
#endif
            let promoteStatus = security.update(
              scope: scope,
              expectedAccount: reservationAccount,
              replacementAccount: replacementAccount,
              value: replacementBytes)
#if canImport(Security)
            if promoteStatus == errSecItemNotFound {
                let reread =
                  try loadOnce(recoverReservation: true)
                if case .present(let record, _, _) = reread,
                   record == replacement {
                    return
                }
                throw Error.compareAndSwapConflict
            }
            guard promoteStatus == errSecSuccess else {
                try mapStatus(promoteStatus)
                return
            }
#else
            guard promoteStatus == 0 else {
                try mapStatus(promoteStatus)
                return
            }
#endif
        case (.present(let record, _, let digest),
              .some(let expected))
          where constantTimeEqual(digest, expected):
            try BASArtifactMeshAnchorRecord.validateTransition(
              from: record, to: replacement)
            let status = security.update(
              scope: scope,
              expectedAccount: try stateAccount(for: record),
              replacementAccount: replacementAccount,
              value: replacementBytes)
#if canImport(Security)
            guard status == errSecSuccess else {
                try mapStatus(status)
                return
            }
#else
            guard status == 0 else {
                try mapStatus(status)
                return
            }
#endif
        default:
            throw Error.compareAndSwapConflict
        }
    }
}
```

`NSLock` may remain inside a recording test client, but correctness never
depends on a process-local lock. For present state, `compareAndSwap` reloads
current bytes, verifies that canonical bytes, generation, digest, and state
account agree, validates the transition, and calls one `SecItemUpdate` whose
query contains the exact old state account while its update dictionary changes
account and data together. A stale contender receives `errSecItemNotFound` and
maps it to `.compareAndSwapConflict`. For absence, the stable reservation
primary key makes `SecItemAdd` single-winner; reservation recovery is
idempotent. The mechanism never delete-and-adds a present state.

In the same source file, expose only under the existing lab compilation
condition:

```swift
#if QINAO_ARTIFACT_MESH_DEVICE_LAB
public enum BASArtifactMeshKeychainCASLabOutcome:
    String, Sendable, Codable
{
    case winner
    case compareAndSwapConflict
}

public enum BASArtifactMeshKeychainCASLabProbe {
    public static func seed(
        applicationContainerID: String,
        storeRole: String,
        accessGroup: String,
        challenge: String
    ) throws -> Data

    public static func contend(
        applicationContainerID: String,
        storeRole: String,
        accessGroup: String,
        challenge: String,
        contenderID: String,
        expectedDigest: Data
    ) throws -> BASArtifactMeshKeychainCASLabOutcome
}
#endif
```

`seed` derives one canonical committed g=1 record from the challenge, performs
the production anchor's absence CAS, and returns its digest. `contend` derives
a distinct canonical g=2 replacement from
`challenge + "\0" + contenderID`, calls the same production
`compareAndSwap`, returns `winner` only on success, and maps only
`.compareAndSwapConflict` to the loser outcome. It performs no direct Security
call. Source and selected-archive scans require this entire public lab probe
and both symbol names absent unless
`QINAO_ARTIFACT_MESH_DEVICE_LAB` is active.

- [ ] **Step 4: Run GREEN and a source-boundary scan**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
python3 - <<'PY'
from pathlib import Path
p = Path("BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift")
s = p.read_text()
required = [
 "kSecUseDataProtectionKeychain",
 "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
 "kSecAttrSynchronizable",
 "kSecAttrAccount",
 "kSecMatchLimitAll",
 "SecItemUpdate",
 "expectedAccount",
 "replacementAccount",
 "com.qinao.artifact-mesh.anchor.v1",
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit(f"keychain source missing {missing}")
if "kSecAttrGeneric" in s:
    raise SystemExit("kSecAttrGeneric cannot provide uniqueness or CAS")
print("artifact-mesh-keychain-source: PASS required=8")
PY
```

Expected: all tests pass and source gate prints `required=8`. The package
tests prove exact-account stale-update behavior using independent anchor
instances; the mandatory two-OS-process Security.framework race is the signed
DeviceLab `raceSecondCAS` row in Tasks 7–9 and cannot be replaced by this
in-process suite.

- [ ] **Step 5: Commit**

```bash
git add \
  BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift
git commit -m "feat(artifact-mesh): add sole Keychain anchor"
```

Expected: exactly two paths.

---

### Task 4: Repair SQLite Genesis, Reopen, Metadata, and Quarantine

**Files:**
- Modify: `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
- Modify: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`

**Interfaces:**
- Consumes: the anchor port/record and incumbent `BASArtifactStorePort`.
- Produces: schema version 2 in the incumbent SQL path, explicit `.createAuthorized`/`.reopenRequired` production open intent, genesis reservation, database metadata, committed reopen, family quarantine, and a successful-receipt invariant with no public Artifact wire-shape change.

- [ ] **Step 1: Write RED first-create/reopen/family tests**

Add exact tests to `BASArtifactStoreTests`:

```swift
func testCreateRequiresGenesisReservationBeforeSQLiteCreate() throws {
    let url = try Self.temporaryDatabaseURL()
    let anchor = TestAnchorPort(initial: .absent)
    let intent = BASArtifactMeshOpenIntent.createAuthorized(
        createRequestID: UUID(uuidString:
            "00000000-0000-0000-0000-000000000101")!)
    _ = try Self.makeProductionStore(
        at: url, anchor: anchor, intent: intent)
    XCTAssertEqual(
        anchor.transitions.map(\.kind),
        [.genesisPending, .committed])
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
}

func testReopenNeverUsesSQLiteOpenCreate() throws {
    let fixture = try Self.makeCommittedFixture(generation: 0)
    try FileManager.default.removeItem(at: fixture.databaseURL)
    XCTAssertThrowsError(
        try Self.makeProductionStore(
            at: fixture.databaseURL,
            anchor: fixture.anchor,
            intent: .reopenRequired(
                expectedStoreIdentity: fixture.storeIdentity)))
    XCTAssertFalse(
        FileManager.default.fileExists(
            atPath: fixture.databaseURL.path))
}

func testGenesisPendingWithoutDatabaseResumesSameRequestAndIdentity()
    throws
{
    let fixture = try Self.makeGenesisPendingFixture()
    let reopened = try Self.makeProductionStore(
        at: fixture.databaseURL,
        anchor: fixture.anchor,
        intent: .createAuthorized(
            createRequestID: fixture.createRequestID))
    XCTAssertEqual(
        try reopened._testStoreIdentity(), fixture.storeIdentity)
}

func testCommittedAnchorDatabaseMismatchQuarantinesWholeFamily()
    throws
{
    let fixture = try Self.makeCommittedFixture(generation: 1)
    try Data("stale".utf8).write(
        to: URL(fileURLWithPath: fixture.databaseURL.path + "-wal"))
    try Self.replaceMetadataStoreIdentity(
        at: fixture.databaseURL, with: UUID())
    XCTAssertThrowsError(try Self.reopen(fixture))
    XCTAssertFalse(
        FileManager.default.fileExists(
            atPath: fixture.databaseURL.path))
    XCTAssertEqual(
        try Self.quarantinedFamilyMembers(fixture.directoryURL),
        ["artifacts.sqlite", "artifacts.sqlite-shm", "artifacts.sqlite-wal"])
}

func testProtectedDataUnavailableNeverCreates() throws {
    let url = try Self.temporaryDatabaseURL()
    let anchor = TestAnchorPort(error: .protectedDataUnavailable)
    XCTAssertThrowsError(
        try Self.makeProductionStore(
            at: url, anchor: anchor,
            intent: .createAuthorized(createRequestID: UUID())))
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
}

func testEveryConnectionPersistsWALAndSidecarsSurviveLastClose()
    throws
{
    let fixture = try Self.makeCommittedFixture(generation: 1)
    XCTAssertEqual(
      try fixture.store._testPersistWALSetting(), 1)
    try fixture.store._testClose()
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: fixture.databaseURL.path + "-wal"))
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: fixture.databaseURL.path + "-shm"))
}

func testQuarantineCrashCutsResumeOneDirectoryRename() throws {
    for cut in [
      QuarantineCrashCut.afterIntentFsync,
      .afterDirectoryRenameBeforeParentFsync,
    ] {
        let fixture = try Self.makeCommittedFixture(generation: 1)
        try Self.corruptMetadata(fixture)
        try Self.injectQuarantineCrash(cut)
        XCTAssertThrowsError(try Self.reopen(fixture))
        try Self.clearQuarantineCrash()
        XCTAssertThrowsError(try Self.reopen(fixture))
        XCTAssertTrue(try Self.hasOneCompleteQuarantine(fixture))
        XCTAssertFalse(try Self.hasSplitFamily(fixture))
    }
}
```

Every fixture stores `artifacts.sqlite`, `artifacts.sqlite-wal`, and
`artifacts.sqlite-shm` inside one dedicated mesh directory that contains no
unrelated application file. The sidecar test closes the final connection
before inspecting them. The quarantine test injects unit-only crash cuts; it
does not add a fifteenth physical matrix fault.

- [ ] **Step 2: Run RED**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
```

Expected: existing tests discover; new tests fail because production open intent and metadata are absent.

- [ ] **Step 3: Replace the SQL resource with the exact schema-v2 objects**

Keep `artifact_mesh_records`, `artifact_mesh_heads`, and
`artifact_mesh_head_artifact_idx`. Replace the v1 attestation projection and
index with the already-authorized schema-v2 purpose projection:

```sql
CREATE TABLE artifact_mesh_attestation_targets (
    attestation_artifact_id TEXT PRIMARY KEY NOT NULL,
    target_artifact_id TEXT NOT NULL,
    attestation_purpose TEXT NOT NULL
        CHECK (
            typeof(attestation_purpose) = 'text'
            AND length(CAST(attestation_purpose AS BLOB))
                BETWEEN 1 AND 128
            AND instr(attestation_purpose, char(0)) = 0
        ),
    FOREIGN KEY (attestation_artifact_id)
        REFERENCES artifact_mesh_records(artifact_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (target_artifact_id)
        REFERENCES artifact_mesh_records(artifact_id)
        ON DELETE RESTRICT
);

CREATE INDEX artifact_mesh_attestation_target_idx
    ON artifact_mesh_attestation_targets(
        target_artifact_id,
        attestation_purpose,
        attestation_artifact_id
    );
```

Then add the three owner-private physical/recovery tables:

```sql
CREATE TABLE artifact_mesh_store_metadata (
    singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
    store_identity TEXT NOT NULL,
    generation TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    schema_version TEXT NOT NULL,
    commitment_key_id TEXT NOT NULL,
    commitment_key_epoch TEXT NOT NULL,
    record_count TEXT NOT NULL,
    record_root TEXT NOT NULL,
    cas_head_root TEXT NOT NULL,
    cas_revision_floor TEXT NOT NULL,
    ordinary_put_floor TEXT NOT NULL,
    recovery_floor TEXT NOT NULL,
    previous_committed_digest TEXT NOT NULL,
    protection_version TEXT NOT NULL
);

CREATE TABLE artifact_mesh_recovery_lifecycle (
    ordinal INTEGER PRIMARY KEY AUTOINCREMENT,
    recovery_id TEXT NOT NULL UNIQUE,
    store_identity TEXT NOT NULL,
    generation TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN (
        'quarantined', 'lease-acquired', 'floor-updated', 'completed'
    )),
    database_digest TEXT,
    wal_digest TEXT,
    shm_digest TEXT,
    previous_lifecycle_digest TEXT NOT NULL,
    lifecycle_digest TEXT NOT NULL UNIQUE
);

CREATE TABLE artifact_mesh_recovery_lease (
    singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
    recovery_id TEXT NOT NULL,
    holder_id TEXT NOT NULL,
    generation TEXT NOT NULL,
    monotonic_expiry_nanos TEXT NOT NULL,
    lease_digest TEXT NOT NULL
);
```

Set `BASArtifactSQLiteStore.schemaVersion = 2`, update exact schema-shape
validation to six tables/two indexes, and update
`ArtifactMeshV1Schema.statementCount` from 5 to 8. Every new attestation put
derives `attestation_purpose` from the already decoded
`BASArtifactAttestationPayload`; no caller supplies it. Keep the resource
filename and M evidence unchanged.

The existing public target-only query remains wire-compatible in Task 0 but
is bounded to `LIMIT 9`, returns at most eight verified children, and throws
`StorageError.attestationResultOverflow` on a ninth. Task 0 does not add the
later purpose-aware public overload; it only lands the one owner-private v2
projection that the authorized W1 contract slice will consume.

- [ ] **Step 4: Freeze the no-silent-adoption migration posture**

Add these RED tests before changing open code:

```swift
func testFreshV2ProjectionStoresCanonicalAttestationPurpose()
    async throws
{
    let fixture = try Self.makeCommittedFixture(generation: 0)
    let payload = try Self.attestationPayload(
      purpose: "provider-supervisor-observation-v1")
    _ = try await fixture.store.put(
      identityCore: Self.core(
        kind: "artifact-attestation",
        payload: payload),
      headUpdate: nil)
    XCTAssertEqual(
      try Self.projectedAttestationPurposes(
        at: fixture.databaseURL),
      ["provider-supervisor-observation-v1"])
}

func testAnchorlessV1FamilyIsQuarantinedNotSilentlyAdopted()
    throws
{
    let fixture = try Self.makeExactV1FamilyWithoutAnchor()
    XCTAssertThrowsError(
      try Self.makeProductionStore(
        at: fixture.databaseURL,
        anchor: fixture.anchor,
        intent: .reopenRequired(
          expectedStoreIdentity: fixture.storeIdentity)))
    XCTAssertTrue(try Self.hasQuarantinedFamily(fixture))
}
```

Do not run the old v1→v2 shadow migration from an `anchor absent + database
present` production state: Section 11.2's later physical contract makes that
silent adoption unsafe. Fresh authorized create installs v2 directly. An
existing anchorless v1 family is quarantined and this release is explicitly
roll-forward-only until a separately authorized bridge can mint a
non-circular external floor; Task 0 provides no such authority. Record that
disposition as exact value
`anchorlessV1QuarantineRollForwardOnly` in
`ArtifactMeshW1Task0HandoffV1` and the operator-visible
production gate. This resolves the existing v2 projection requirement
without inventing an anchor-adoption/reset API.

- [ ] **Step 5: Add explicit open intent and private initializers**

Add this internal BASMemory state:

```swift
enum BASArtifactMeshOpenIntent: Sendable, Equatable {
    case createAuthorized(createRequestID: UUID)
    case reopenRequired(expectedStoreIdentity: UUID)
}
```

The two public shipping entry points avoid exporting that owner-private state:

```swift
public static func openProductionForAuthorizedCreate(
    databaseURL: URL,
    applicationContainerID: String,
    storeRole: String,
    applicationKeychainAccessGroup: String,
    createRequestID: UUID,
    activeCommitmentKeyID: String,
    activeCommitmentKeyEpoch: UInt64,
    commitmentKeyResolver: @escaping BASArtifactCommitmentKeyResolver
) throws -> BASArtifactSQLiteStore

public static func openProductionForReopen(
    databaseURL: URL,
    applicationContainerID: String,
    storeRole: String,
    applicationKeychainAccessGroup: String,
    expectedStoreIdentity: UUID,
    activeCommitmentKeyID: String,
    activeCommitmentKeyEpoch: UInt64,
    commitmentKeyResolver: @escaping BASArtifactCommitmentKeyResolver
) throws -> BASArtifactSQLiteStore
```

Replace the incumbent public auto-creating initializer. Keep no public overload that accepts only `databaseURL`/key inputs or silently adds `SQLITE_OPEN_CREATE`; migrate the existing unit helper to the internal initializer below.

It constructs `BASArtifactMeshKeychainAnchor` itself. The only anchor-accepting initializer is `internal` and carries an explicit `testOnlyAnchor:` label:

```swift
internal init(
    databaseURL: URL,
    applicationContainerID: String,
    storeRole: String,
    openIntent: BASArtifactMeshOpenIntent,
    activeCommitmentKeyID: String,
    activeCommitmentKeyEpoch: UInt64,
    commitmentKeyResolver: @escaping BASArtifactCommitmentKeyResolver,
    testOnlyAnchor: any BASArtifactMeshAnchorPort
) throws
```

No public initializer accepts `BASArtifactMeshAnchorPort`.

- [ ] **Step 6: Implement the exact open state table**

Before any `sqlite3_open_v2`, require `databaseURL.lastPathComponent ==
"artifacts.sqlite"`, require its parent to be the dedicated mesh directory,
recover any durable quarantine intent, inspect DB/WAL/SHM presence, and load
the anchor. Unknown directory members, symlinks, hard-link count other than
one, or both live and quarantine directories are corruption. Route exactly:

| Anchor | Family | Intent | Action |
|---|---|---|---|
| absent | all absent | createAuthorized | CAS `genesisPending(g=0)`, then CREATE |
| absent | any present | either | quarantine present family; fail |
| absent | all absent | reopenRequired | fail without CREATE |
| unavailable | any | either | typed unavailable; no file mutation |
| genesisPending | all absent | same create request | resume exact identity; CREATE |
| genesisPending | exact complete g=0 metadata | same create request | promote idempotently |
| genesisPending | partial/mismatch | either | quarantine family; preserve pending; fail |
| committed | exact family | matching reopenRequired | open without CREATE and verify |
| committed | exact family | createAuthorized | reopen and verify; never create |
| committed | missing/partial/mismatch | either | quarantine present family; fail |

`openSQLite(create: false)` uses:

```swift
SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
```

and `openSQLite(create: true)` alone adds `SQLITE_OPEN_CREATE`. Immediately
after **every** successful connection open—including create, reopen, read-only
integrity, recovery, quarantine inspection, and test helpers—set and query:

```c
int persist = 1;
require(sqlite3_file_control(
  handle, "main", SQLITE_FCNTL_PERSIST_WAL, &persist) == SQLITE_OK);
persist = -1;
require(sqlite3_file_control(
  handle, "main", SQLITE_FCNTL_PERSIST_WAL, &persist) == SQLITE_OK);
require(persist == 1);
```

Only then run integrity/schema work and set and verify:

```sql
PRAGMA journal_mode=WAL;
PRAGMA synchronous=FULL;
PRAGMA foreign_keys=ON;
PRAGMA wal_autocheckpoint=0;
```

SQLite's official
[`SQLITE_FCNTL_PERSIST_WAL`](https://sqlite.org/c3ref/c_fcntl_begin_atomic_write.html#sqlitefcntlpersistwal)
contract states that WAL and shared-memory files are normally deleted when the
last connection closes, while value `1` makes them persist and value `-1`
queries the setting. Consequently a successful open with unsupported,
`SQLITE_NOTFOUND`, or queried-not-1 persistence is a typed
`StorageError.persistentWALUnavailable`; it cannot expose the store or silently
relax the exact-family invariant.

First create performs one `BEGIN IMMEDIATE`, installs schema, writes the exact
g=0 singleton metadata with the same transaction/store identity, sets
`user_version=2`, commits, then executes
`sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_FULL,
&logFrames, &checkpointedFrames)` and requires `SQLITE_OK` plus
`logFrames == checkpointedFrames`. It applies file protection to DB/WAL/SHM,
then promotes the exact pending anchor. Reopen performs no DDL, verifies
schema and every metadata/anchor field, recomputes roots/counts, verifies all
payload IDs/digests, and only then exposes the actor.

Production open also requires `BASSQLiteFileProtection.isEnabled == true`; a `BAS_FILE_PROTECTION=0` environment or any non-nil protection application error throws the new typed `StorageError.fileProtectionUnavailable(String)` before returning a store. The internal test-only initializer may exercise the existing kill-switch solely in a test that proves the production factory rejects it.

- [ ] **Step 7: Implement exact quarantine behavior**

Add one private method:

```swift
private static func quarantineFamily(
    meshDirectoryURL: URL,
    reasonCode: String,
    challengeID: UUID
) throws -> URL
```

It derives the nonexistent same-parent target:

```text
artifact-mesh-quarantine-LOWERCASE_CHALLENGE_UUID
```

Before renaming, it create-once writes
`.qinao-quarantine-intent-v1.json` inside the live mesh directory with exact
keys
`schema_version,challenge_id,reason_code,source_basename,target_basename,members`,
where `members` is the sorted exact DB/WAL/SHM presence/digest set. It uses
`O_CREAT|O_EXCL|O_NOFOLLOW`, mode 0600, full write, `fsync(file)`, then
`fsync(meshDirectory)`. It then performs one same-volume
`renameat(sourceDirectory, targetDirectory)`—never three member moves—and
`fsync(parentDirectory)`. The target receives
`completeUntilFirstUserAuthentication`; no replacement database is written.

Recovery before every open is total and idempotent:

| Source | Target | Durable intent | Action |
|---|---|---|---|
| present | absent | valid in source | resume exact directory rename, fsync parent |
| absent | present | valid in target | verify exact members/digests; finalized quarantine |
| present | absent | no intent | normal open-state table |
| absent | absent | expected intent known | fail closed; no recreation |
| present | present | any | fail corruption; never merge |
| either | either | malformed/mismatched intent | fail corruption |

The two unit-only cuts are immediately after intent-directory fsync and
immediately after rename before parent fsync. Reopen must converge to exactly
one complete target directory with no split family. The owner-private lifecycle
row is written only when the damaged database can be opened read-only and
integrity-safe enough to append without changing damaged bytes; otherwise the
durable intent plus later externally verified recovery record is the evidence.
Never copy, truncate, delete, or individually rename a DB/WAL/SHM member.

- [ ] **Step 8: Preserve the public M wire shape while strengthening receipt semantics**

In `BASArtifactMeshCore.swift`, do not add/remove fields or cases. Add this protocol comment and a validation helper used by the store before returning:

```swift
/// A successful `put` receipt is referenceable only after the owning store's
/// physical durability boundary has committed. Implementations must not emit
/// success after only an in-memory or database-local write.
public protocol BASArtifactStorePort: AnyObject, Sendable {
    // existing methods remain byte-for-byte shape compatible
}

public enum BASArtifactStoreReceiptValidation {
    public static func requireReferenceable(
        _ receipt: BASArtifactStoreReceipt
    ) throws {
        guard receipt.success, receipt.body != nil else {
            throw BASArtifactMeshError.malformedRecord(
                "store success requires a receipt body")
        }
    }
}
```

The helper changes no serialized payload and does not expose anchor state.

- [ ] **Step 9: Run GREEN**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
```

Expected: both suites are non-empty with 0 failures; first-create/reopen tests observe `synchronous=2` (`FULL`) and no unexpected file recreation.

- [ ] **Step 10: Commit the incumbent M repair**

```bash
git add \
  BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql \
  BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift
git commit -m "fix(artifact-mesh): enforce genesis and reopen identity"
```

Expected: exactly the three historical M paths plus their existing test path. No owner-create evidence file changes.

---

### Task 5: Close Floor-Advancing Put, CAS, Recovery, and Lost-Reply Semantics

**Files:**
- Modify: `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
- Modify: `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`

**Interfaces:**
- Consumes: committed anchor g, singleton SQLite metadata, incumbent put/head API.
- Produces: serialized pending g+1, FULL SQLite commit/checkpoint, exact promotion, deterministic roots/floors, digest reopen, clear-pending/promote/quarantine recovery, recovery lease/floor lifecycle, and lab-only fault barriers.

- [ ] **Step 1: Write RED transaction-cut tests**

Add:

```swift
func testPutReceiptAppearsOnlyAfterAnchorPromotion() async throws {
    let fixture = try Self.makeCommittedFixture(generation: 0)
    fixture.anchor.pauseBeforePromotion = true
    let task = Task {
        try await fixture.store.put(
            identityCore: Self.core(), headUpdate: nil)
    }
    await fixture.anchor.waitUntilPromotionRequested()
    XCTAssertFalse(task.isCancelled)
    XCTAssertEqual(fixture.anchor.currentGeneration, 0)
    fixture.anchor.resumePromotion()
    let receipt = try await task.value
    XCTAssertTrue(receipt.success)
    XCTAssertEqual(fixture.anchor.currentGeneration, 1)
}

func testPendingWithoutSQLiteCommitClearsToExactCommittedFloor()
    throws
{
    let fixture = try Self.makePendingWithoutSQLiteFixture(generation: 4)
    _ = try Self.reopen(fixture)
    XCTAssertEqual(fixture.anchor.currentGeneration, 4)
    XCTAssertNil(fixture.anchor.currentPending)
}

func testPendingWithExactSQLiteCommitPromotesIdempotently() throws {
    let fixture = try Self.makeSQLiteCommittedPendingFixture(
        generation: 5)
    _ = try Self.reopen(fixture)
    XCTAssertEqual(fixture.anchor.currentGeneration, 6)
    XCTAssertNil(fixture.anchor.currentPending)
}

func testPendingMismatchQuarantinesInsteadOfGuessing() throws {
    let fixture = try Self.makeSQLiteCommittedPendingFixture(
        generation: 5)
    try Self.regressOrdinaryPutFloor(at: fixture.databaseURL)
    XCTAssertThrowsError(try Self.reopen(fixture))
    XCTAssertTrue(try Self.hasQuarantinedFamily(fixture))
}

func testConcurrentCASHasOneWinnerAndOneTypedLoser() async throws {
    let fixture = try Self.makeCommittedFixture(generation: 1)
    let outcomes = await Self.runTwoCASContenders(fixture)
    XCTAssertEqual(outcomes.successCount, 1)
    XCTAssertEqual(outcomes.headConflictCount, 1)
}

func testEveryReopenedPayloadDigestIsVerified() async throws {
    let fixture = try await Self.makeFixtureWithOnePut()
    try Self.flipOneRecordByte(at: fixture.databaseURL)
    XCTAssertThrowsError(try Self.reopen(fixture))
}

func testK3ReferenceHookCannotRunBeforePromotion() async throws {
    let fixture = try Self.makeCommittedFixture(generation: 0)
    let trace = try await fixture.store._testPutThenReference(
        identityCore: Self.core())
    XCTAssertEqual(trace, [
        .anchorPending, .sqliteCommitted, .walCheckpointed,
        .anchorPromoted, .k3ReferenceCommitted
    ])
}

func testRetiredAttemptAndSemanticHeadsHaveZeroWriteReadAuthority()
    async throws
{
    let fixture = try Self.makeCommittedFixture(generation: 0)
    for purpose in [
        BASArtifactHeadPurpose.attemptRoot,
        BASArtifactHeadPurpose.semanticSnapshot,
    ] {
        let cas = try Self.headCAS(purpose: purpose)
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.store.put(
                identityCore: Self.core(), headUpdate: cas)
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await fixture.store.head(cas.key)
        }
    }
    let receipt = try await fixture.store.put(
        identityCore: Self.core(kind: "semantic-snapshot"),
        headUpdate: nil)
    XCTAssertTrue(receipt.success)
}
```

Also add one table-driven test for wrong key epoch, schema rollback, record-count/root rollback, CAS-head root/revision rollback, ordinary-put floor rollback, recovery-floor rollback, missing WAL, missing SHM, stale family, torn metadata, lost SQLite reply, lost K3 reply, corrupt quarantine member, expired recovery lease, and duplicate recovery completion.

- [ ] **Step 2: Run RED**

Run the non-empty `BASArtifactStoreTests` command.

Expected: new tests fail because pending/floor recovery and lab barriers are absent.

- [ ] **Step 3: Implement deterministic metadata derivation**

Inside the same `BEGIN IMMEDIATE` transaction derive:

```text
recordCount = decimal COUNT(*) of artifact_mesh_records
recordRoot = SHA256(length-prefixed sorted rows of artifact_id + SHA256(record_bytes))
casHeadRoot = SHA256(length-prefixed sorted rows of scope_tag + scope_artifact_id + purpose + artifact_id + revision)
casRevisionFloor = maximum parsed revision, or 0 for no heads
ordinaryPutFloor = checked previous + number of newly inserted Artifact records
recoveryFloor = unchanged during normal put
previousCommittedDigest = lowercase hex of the prior committed-only anchor bytes
```

Every decimal uses canonical unsigned base-10 with no sign or leading zero except `"0"`. Every query has an explicit `ORDER BY` and bounded text/blob reads. A duplicate idempotent put that inserts no row does not advance `ordinaryPutFloor`; a head-only CAS advances generation but not ordinary-put floor.

- [ ] **Step 4: Implement the exact normal transaction**

Refactor `put` to:

```text
1. load and equality-verify committed anchor g against SQLite metadata g
2. precompute transaction ID and proposed deterministic floor g+1
3. Keychain CAS committed(g) -> committed(g)+pending(g+1)
4. BEGIN IMMEDIATE
5. write/verify Artifact, attestation index, optional head CAS
6. write singleton metadata g+1 with same transaction ID and derived roots/floors
7. COMMIT under synchronous=FULL
8. sqlite3_wal_checkpoint_v2(SQLITE_CHECKPOINT_FULL); require SQLITE_OK and zero uncheckpointed frames
9. reapply file protection to DB/WAL/SHM and surface any error
10. Keychain CAS pending(g+1) -> committed(g+1)
11. validate successful receipt and return it
```

If steps 4-7 fail, rollback and clear pending only after a read transaction proves exact unchanged g and absence of the transaction ID. If step 8, 9, or 10 fails, preserve pending and fail; reopen deterministically promotes or quarantines. Never return a receipt before step 10.

Before beginning a transaction, reject `headUpdate.key.purpose` equal to `.attemptRoot` or `.semanticSnapshot` with `StorageError.retiredHeadPurpose`. `head(_:)` rejects those same purposes. Keep the enum cases and SQL vocabulary decodable for non-authoritative compatibility, but grant them zero new write/read authority. A semantic snapshot remains an immutable ordinary put with `headUpdate: nil`; only K3 may attach currentness.

- [ ] **Step 5: Implement exact reopen reconciliation**

On reopen:

```text
anchor committed(g), database g exact -> verify and open
anchor committed(g)+pending(g+1), database exact g/no transaction -> clear pending
anchor committed(g)+pending(g+1), database exact g+1/same transaction/roots -> checkpoint and promote
genesisPending, database absent -> resume identical authorized genesis
genesisPending, exact g=0 same transaction -> checkpoint and promote
every other combination -> quarantine and fail
```

Verify every record's canonical payload, `BASArtifactID`, commitment-key epoch, HMAC, attestation target, head target, scope, record count/root, head root/revision, and all floors before exposing reads.

- [ ] **Step 6: Implement owner-private recovery lifecycle and lease**

Add internal methods used only by normal recovery and lab proof:

```swift
func beginRecovery(
    recoveryID: UUID,
    holderID: UUID,
    generation: UInt64,
    monotonicExpiryNanos: UInt64
) throws

func advanceRecoveryFloor(
    recoveryID: UUID,
    expectedFloor: UInt64
) throws

func completeRecovery(
    recoveryID: UUID,
    expectedLifecycleDigest: String
) throws
```

Each method uses `BEGIN IMMEDIATE`, exact expected generation/digest, append-only lifecycle digest chaining, and one singleton lease CAS. An expired lease can be replaced only by a new holder that proves expiry against monotonic time and appends a new `lease-acquired` lifecycle row. Completion deletes the exact lease after appending `completed`; a duplicate completion or wrong holder/generation fails.

- [ ] **Step 7: Add lab-only fault barriers without shipping reachability**

Inside `BASArtifactSQLiteStore.swift`, and only under:

```swift
#if QINAO_ARTIFACT_MESH_DEVICE_LAB
```

add:

```swift
public enum BASArtifactMeshLabFault:
    String, Codable, Sendable
{
    case dropSQLiteReply
    case dropK3Reply
    case raceSecondCAS
}

public struct BASArtifactMeshLabBarrier: Sendable {
    public let operation: String
    public let cut: String
    public let transactionID: UUID?
    public let durableCommitObserved: Bool
}
```

The lab callback is set only by an explicit lab-only static install method
compiled under the same condition. `dropSQLiteReply` suppresses delivery after
step 8 and blocks at a live barrier. `dropK3Reply` blocks only after the exact
K3-reference probe commit. `raceSecondCAS` does **not** start two tasks inside
one process: it pauses one identified contender at the exact ready barrier,
after which each of the two separately signed DeviceLab application processes
performs the production Keychain CAS. The controller records distinct PIDs
plus exact winner/loser before blocking. No production build contains the
enum, install method, callback storage, or symbols.

- [ ] **Step 8: Run GREEN twice from clean processes**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
```

Expected: both runs execute the same non-zero test count with 0 failures; no database or Keychain fixture survives into the second run.

- [ ] **Step 9: Commit**

```bash
git add \
  BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift
git commit -m "feat(artifact-mesh): close durable floor recovery"
```

Expected: exactly two paths.

---

### Task 6: Add the Qinao Mechanism Factory and Exact Host Call Seam

**Files:**
- Create: `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift`
- Create: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoArtifactMeshAssemblyTests.swift`
- Modify: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift`
- Modify: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift`
- Modify: `QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift`

**Interfaces:**
- Consumes: `BASArtifactSQLiteStore.openProductionForAuthorizedCreate` and `BASArtifactSQLiteStore.openProductionForReopen`.
- Produces: immutable mechanism configuration, exactly one production store factory, one required sovereign-host argument, and one stored handle. It cannot select Provider routes, profiles, release policy, or alternate persistence.

- [ ] **Step 1: Write RED assembly tests**

Create:

```swift
import Foundation
import XCTest
@testable import QinaoDefaults

final class QinaoArtifactMeshAssemblyTests: XCTestCase {
    private enum UnusedResolverError: Error {
        case called
    }

    func testFactoryBuildsOnlyProductionStore() throws {
        let source = try String(
            contentsOfFile:
              "Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift")
        XCTAssertEqual(
            source.components(
              separatedBy:
                ".openProductionForAuthorizedCreate(").count - 1,
            1)
        XCTAssertEqual(
            source.components(
              separatedBy:
                ".openProductionForReopen(").count - 1,
            1)
        XCTAssertFalse(source.contains("testOnlyAnchor:"))
        XCTAssertFalse(source.contains("BASArtifactSQLiteStore("))
    }

    func testUnknownProtectionVersionFailsClosed() throws {
        let configuration = QinaoArtifactMeshConfiguration(
            databaseURL: URL(fileURLWithPath: "/dev/null"),
            applicationContainerID: "com.qinao.tests",
            storeRole: "primary",
            applicationKeychainAccessGroup:
              "TEAMID.com.qinao.tests",
            openIntent: .createAuthorized(
              createRequestID: UUID(uuidString:
                "00000000-0000-0000-0000-000000000601")!),
            activeCommitmentKeyID: "artifact-mesh-test-key",
            activeCommitmentKeyEpoch: 1,
            protectionVersion: 2,
            commitmentKeyResolver: { _ in
                throw UnusedResolverError.called
            })
        XCTAssertThrowsError(
            try QinaoDefaults.makeArtifactMeshStore(
                configuration: configuration)) {
            XCTAssertEqual(
              $0 as? QinaoArtifactMeshAssemblyError,
              .unsupportedProtectionVersion(2))
        }
    }

    func testSovereignHostOwnsExactFactoryStore() throws {
        let source = try String(
            contentsOfFile:
              "Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift")
        XCTAssertEqual(
            source.components(
              separatedBy:
                "makeArtifactMeshStore(").count - 1,
            1)
        XCTAssertTrue(source.contains(
            "artifactMesh: artifactMesh"))
    }

    func testHostHasNoAnchorRouteOrProfileChoice() throws {
        let source = try String(
            contentsOfFile:
              "Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift")
        for forbidden in [
            "BASArtifactMeshAnchorPort",
            "route", "releaseProfile", "policy", "fallback",
            "inMemory", "alternateStore"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }
}
```

The package unit test proves the one-call factory shape without pretending an unentitled macOS process can exercise the app's nonshared Keychain group. The signed DeviceLab and Phase-B physical proof execute the production factory. No in-memory anchor is represented as production evidence.

In the same uncommitted RED edit, create
`QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift` as a
minimal compileable stub with the final public configuration/open-intent,
initializer, error, and `QinaoDefaults.makeArtifactMeshStore` signatures
shown in Step 3. The configuration retains only its explicit arguments; add a
temporary `QinaoArtifactMeshAssemblyError.unimplemented`, and make the
factory throw it without opening a store. Do not add either production-open
call string or modify the host/callers yet. Do not stage the stub.

- [ ] **Step 2: Run RED**

```bash
set +e
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoArtifactMeshAssemblyTests \
  --require-suite QinaoArtifactMeshAssemblyTests
assembly_status=$?
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoSovereignHostAssemblyTests \
  --require-suite QinaoSovereignHostAssemblyTests
host_status=$?
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoEffectFacadeFreezeTests \
  --require-suite QinaoEffectFacadeFreezeTests
facade_status=$?
set -e
test "$assembly_status" -ne 0
test "$host_status" -eq 0
test "$facade_status" -eq 0
```

Expected: all three list phases are non-empty. The new assembly suite
executes and fails on the stub/source-shape assertions, while both incumbent
baseline suites remain green. A compile/list/link failure, a zero-match
filter, or an incumbent-suite failure is invalid RED.

- [ ] **Step 3: Implement the exact configuration and factory**

Replace the Step-1 stub in place, remove `.unimplemented`, and implement:

```swift
import Foundation
import BASMemory
import BASRuntimeCore

public enum QinaoArtifactMeshOpenIntent: Sendable, Equatable {
    case createAuthorized(createRequestID: UUID)
    case reopenRequired(expectedStoreIdentity: UUID)
}

public struct QinaoArtifactMeshConfiguration: Sendable {
    public let databaseURL: URL
    public let applicationContainerID: String
    public let storeRole: String
    public let applicationKeychainAccessGroup: String
    public let openIntent: QinaoArtifactMeshOpenIntent
    public let activeCommitmentKeyID: String
    public let activeCommitmentKeyEpoch: UInt64
    public let protectionVersion: UInt64
    public let commitmentKeyResolver: BASArtifactCommitmentKeyResolver

    public init(
        databaseURL: URL,
        applicationContainerID: String,
        storeRole: String,
        applicationKeychainAccessGroup: String,
        openIntent: QinaoArtifactMeshOpenIntent,
        activeCommitmentKeyID: String,
        activeCommitmentKeyEpoch: UInt64,
        protectionVersion: UInt64 = 1,
        commitmentKeyResolver:
          @escaping BASArtifactCommitmentKeyResolver
    ) {
        self.databaseURL = databaseURL
        self.applicationContainerID = applicationContainerID
        self.storeRole = storeRole
        self.applicationKeychainAccessGroup =
          applicationKeychainAccessGroup
        self.openIntent = openIntent
        self.activeCommitmentKeyID = activeCommitmentKeyID
        self.activeCommitmentKeyEpoch = activeCommitmentKeyEpoch
        self.protectionVersion = protectionVersion
        self.commitmentKeyResolver = commitmentKeyResolver
    }
}

extension QinaoDefaults {
    public static func makeArtifactMeshStore(
        configuration: QinaoArtifactMeshConfiguration
    ) throws -> BASArtifactSQLiteStore {
        guard configuration.protectionVersion == 1 else {
            throw QinaoArtifactMeshAssemblyError
              .unsupportedProtectionVersion(
                configuration.protectionVersion)
        }
        switch configuration.openIntent {
        case .createAuthorized(let createRequestID):
            return try BASArtifactSQLiteStore
              .openProductionForAuthorizedCreate(
                databaseURL: configuration.databaseURL,
                applicationContainerID:
                  configuration.applicationContainerID,
                storeRole: configuration.storeRole,
                applicationKeychainAccessGroup:
                  configuration.applicationKeychainAccessGroup,
                createRequestID: createRequestID,
                activeCommitmentKeyID:
                  configuration.activeCommitmentKeyID,
                activeCommitmentKeyEpoch:
                  configuration.activeCommitmentKeyEpoch,
                commitmentKeyResolver:
                  configuration.commitmentKeyResolver)
        case .reopenRequired(let expectedStoreIdentity):
            return try BASArtifactSQLiteStore
              .openProductionForReopen(
                databaseURL: configuration.databaseURL,
                applicationContainerID:
                  configuration.applicationContainerID,
                storeRole: configuration.storeRole,
                applicationKeychainAccessGroup:
                  configuration.applicationKeychainAccessGroup,
                expectedStoreIdentity: expectedStoreIdentity,
                activeCommitmentKeyID:
                  configuration.activeCommitmentKeyID,
                activeCommitmentKeyEpoch:
                  configuration.activeCommitmentKeyEpoch,
                commitmentKeyResolver:
                  configuration.commitmentKeyResolver)
        }
    }
}
```

Define only `.unsupportedProtectionVersion(UInt64)` in `QinaoArtifactMeshAssemblyError`. Do not add optional stores, factory protocols, route enums, or injected anchors.

- [ ] **Step 4: Wire the required sovereign-host seam**

Add required parameter:

```swift
artifactMeshConfiguration: QinaoArtifactMeshConfiguration
```

at `makeSovereignHost`. Construct:

```swift
let artifactMesh = try makeArtifactMeshStore(
    configuration: artifactMeshConfiguration)
```

before Runtime construction, add `public let artifactMesh: BASArtifactSQLiteStore` to `QinaoSovereignHost`, and return that exact instance. Update the three incumbent callers with explicit temporary/test or app-support configuration. No caller passes an anchor.

- [ ] **Step 5: Run GREEN plus incumbent seam tests**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoArtifactMeshAssemblyTests \
  --require-suite QinaoArtifactMeshAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoSovereignHostAssemblyTests \
  --require-suite QinaoSovereignHostAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoEffectFacadeFreezeTests \
  --require-suite QinaoEffectFacadeFreezeTests
```

Expected: all three suites non-empty and green. The façade freeze remains unchanged except required mechanism configuration.

- [ ] **Step 6: Commit**

```bash
git add \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift \
  QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoArtifactMeshAssemblyTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift \
  QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift
git commit -m "feat(qinao): assemble the production Artifact Mesh"
```

Expected: exactly six paths, containing the two assembly E/A seams and necessary callers/tests.

---

### Task 7: Create the Structurally Separate Installable Device Lab

**Files:**
- Modify: `SampleHost/Package.swift`
- Create: `SampleHost/ArtifactMeshDeviceLab/project.yml`
- Create: `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj`
- Create: `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme`
- Create: `SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme`
- Create: `SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLabApp.swift`
- Create: `SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLab.entitlements`
- Create: `SampleHost/ArtifactMeshDeviceLab/CASContender/ArtifactMeshCASContenderApp.swift`
- Create: `SampleHost/ArtifactMeshDeviceLab/Protocol/ArtifactMeshRecoveryProtocol.swift`
- Create: `SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshRecoveryProbe.swift`
- Create: `SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshFaultBootstrap.swift`

**Interfaces:**
- Consumes: Qinao mechanism factory, lab-only fault barriers, two ordinary iOS app sandboxes, and one challenge-scoped lab-only Keychain access group shared solely by those two signed lab applications.
- Produces: two signed/installable lab-only application products and two shared schemes, one closed challenge protocol, a normal store/recovery probe, a minimal second-process CAS contender, and a structurally separate one-shot mutation bootstrap. The entire directory and both products are excluded from SwiftPM and every shipping profile.

- [ ] **Step 1: Exclude the whole directory before creating it**

Change only the SampleHost target exclusion list:

```swift
exclude: [
    "Package.swift",
    "Tests",
    "ArtifactMeshDeviceLab"
],
```

Run:

```bash
cd SampleHost
xcodebuild test \
  -scheme SampleHost \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
cd ..
```

Expected: existing SampleHost tests pass and no unhandled-file warning names `ArtifactMeshDeviceLab`.

- [ ] **Step 2: Write the exact XcodeGen source**

Create:

```yaml
name: ArtifactMeshDeviceLab
options:
  bundleIdPrefix: com.qinao
  deploymentTarget:
    iOS: "27.0"
  createIntermediateGroups: true
packages:
  BehavioralAISubstrate:
    path: ../../BehavioralAISubstrate
  QinaoRuntimeSDK:
    path: ../../QinaoRuntimeSDK
targets:
  ArtifactMeshDeviceLab:
    type: application
    platform: iOS
    deploymentTarget: "27.0"
    sources:
      - path: App
      - path: Protocol
      - path: Probe
    dependencies:
      - package: BehavioralAISubstrate
        product: BASMemory
      - package: BehavioralAISubstrate
        product: BASRuntimeCore
      - package: QinaoRuntimeSDK
        product: QinaoDefaults
    entitlements:
      path: App/ArtifactMeshDeviceLab.entitlements
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.qinao.artifact-mesh-device-lab
        PRODUCT_NAME: ArtifactMeshDeviceLab
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Qinao Artifact Mesh Lab
        INFOPLIST_KEY_QinaoKeychainAccessGroup: "$(AppIdentifierPrefix)com.qinao.artifact-mesh-cas-lab-shared"
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) QINAO_ARTIFACT_MESH_DEVICE_LAB"
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "1,2"
        SUPPORTS_MACCATALYST: NO
        IPHONEOS_DEPLOYMENT_TARGET: "27.0"
  ArtifactMeshCASContenderLab:
    type: application
    platform: iOS
    deploymentTarget: "27.0"
    sources:
      - path: CASContender
      - path: Protocol
    dependencies:
      - package: BehavioralAISubstrate
        product: BASMemory
      - package: BehavioralAISubstrate
        product: BASRuntimeCore
      - package: QinaoRuntimeSDK
        product: QinaoDefaults
    entitlements:
      path: App/ArtifactMeshDeviceLab.entitlements
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.qinao.artifact-mesh-cas-contender-lab
        PRODUCT_NAME: ArtifactMeshCASContenderLab
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Qinao CAS Contender
        INFOPLIST_KEY_QinaoKeychainAccessGroup: "$(AppIdentifierPrefix)com.qinao.artifact-mesh-cas-lab-shared"
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) QINAO_ARTIFACT_MESH_DEVICE_LAB"
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "1,2"
        SUPPORTS_MACCATALYST: NO
        IPHONEOS_DEPLOYMENT_TARGET: "27.0"
schemes:
  ArtifactMeshDeviceLab:
    shared: true
    build:
      targets:
        ArtifactMeshDeviceLab: all
    run:
      config: Debug
    archive:
      config: Release
  ArtifactMeshCASContenderLab:
    shared: true
    build:
      targets:
        ArtifactMeshCASContenderLab: all
    run:
      config: Debug
    archive:
      config: Release
```

Generate and verify both required real project artifacts:

```bash
xcodegen generate \
  --spec SampleHost/ArtifactMeshDeviceLab/project.yml \
  --project SampleHost/ArtifactMeshDeviceLab
test -s SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj
test -s SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme
test -s SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme
```

Expected: XcodeGen succeeds and all three generated files are non-empty. Commit
the pbxproj and both generated shared schemes; `project.yml` is the reviewable
source but never substitutes for real generated project artifacts.

- [ ] **Step 3: Add exact entitlements**

Create:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.default-data-protection</key>
  <string>NSFileProtectionCompleteUntilFirstUserAuthentication</string>
  <key>keychain-access-groups</key>
  <array>
    <string>$(AppIdentifierPrefix)com.qinao.artifact-mesh-cas-lab-shared</string>
  </array>
</dict>
</plist>
```

There is no app group, app extension, Network Extension, Enhanced Security
helper, or background execution entitlement. The Keychain group is shared only
between the two lab-only application products so the physical
`raceSecondCAS` row can use two operating-system processes. The production
application retains its nonshared Keychain group, and archive reachability
must prove the lab shared group absent from every shipping product.

- [ ] **Step 3A: Add the minimal second-process CAS contender**

`CASContender/ArtifactMeshCASContenderApp.swift` is a separate application
process. It imports `BASMemory`, parses only these exact launch arguments, and
calls only `BASArtifactMeshKeychainCASLabProbe.contend`:

```text
--challenge LOWERCASE_64_HEX
--contender-id a|b
--expected-digest LOWERCASE_64_HEX
--result-file Library/Application Support/QinaoArtifactMeshLab/CAS/RESULT.json
```

Its complete authority-bearing call is:

```swift
let outcome = try BASArtifactMeshKeychainCASLabProbe.contend(
    applicationContainerID: "qinao-artifact-mesh-cas-process-v1",
    storeRole: "race-\(challenge)",
    accessGroup: try exactInfoPlistAccessGroup(),
    challenge: challenge,
    contenderID: contenderID,
    expectedDigest: try Data(exactLowercaseHex: expectedDigest))
```

Before that call it validates exact argument count, lowercase challenge/digest
length 64, contender ID in `{a,b}`, a relative normalized result path beneath
the fixed CAS directory, and exact Info.plist access group
`AppIdentifierPrefix + com.qinao.artifact-mesh-cas-lab-shared`. It writes one
canonical JSON event with exact keys
`schema_version,challenge,contender_id,pid,outcome`, where `pid = getpid()` and
`outcome` is the returned enum raw value, using an atomic file replacement and
`completeUntilFirstUserAuthentication`; then it reaches a live kill barrier.
Every parse, protection, write, or probe error writes no winner and exits
nonzero. It contains no direct `SecItem*`, SQLite, store, Cw/Sw, network, or
evidence-client call.

The primary `ArtifactMeshRecoveryProbe` gains a matching `cas-seed` mode that
calls only `BASArtifactMeshKeychainCASLabProbe.seed` with the same
container/role/access-group/challenge tuple, emits the expected digest, and
stops at a live barrier. Its `cas-contender-a` mode uses the same `contend`
call, so the race is between the primary app PID and companion app PID—not two
Swift tasks.

- [ ] **Step 4: Implement the closed protocol**

Create these exact types in `Protocol/ArtifactMeshRecoveryProtocol.swift`:

```swift
import Foundation

enum ArtifactMeshOperation: String, Codable, CaseIterable {
    case genesisReserve
    case genesisSQLiteCommit
    case genesisAnchorPromote
    case reopen
    case ordinaryPutAnchorPending
    case ordinaryPutSQLiteCommit
    case walShmCheckpoint
    case ordinaryPutAnchorFloorPromote
    case k3ReferenceCommit
    case quarantineInstall
    case recoveryLeaseAcquire
    case recoveryFloorUpdate
    case recoveryComplete
}

enum ArtifactMeshCut: Codable, Equatable {
    case before(ArtifactMeshOperation)
    case after(ArtifactMeshOperation)
}

enum ArtifactMeshFaultAction: String, Codable, CaseIterable {
    case none
    case deleteDatabase
    case deleteWAL
    case deleteSHM
    case replacePartialFamily
    case replaceStaleFamily
    case substituteWrongKeyEpoch
    case regressAnchorFloor
    case deleteKeychainAnchor
    case dropSQLiteReply
    case dropK3Reply
    case raceSecondCAS
    case corruptQuarantineMember
    case expireRecoveryLease
    case protectedDataUnavailable
}

enum ArtifactMeshFaultTiming: String, Codable {
    case none
    case whileProcessAlive
    case atDurableCommitBeforeReply
    case beforeRecoveryOpen
    case afterRebootBeforeFirstUnlock
}

enum ArtifactMeshTerminal: String, Codable {
    case resume
    case promote
    case clearPending
    case queryReconcile
    case quarantine
    case denyUnavailable
    case recoveryComplete
}

enum ArtifactMeshProbePhase: String, Codable {
    case challengeAccepted
    case operationBefore
    case operationDurablyCommitted
    case operationAfter
    case liveKillBarrier
    case mutationBefore
    case mutationAfter
    case mutationKillBarrier
    case recoveryOpen
    case terminal
}

struct ArtifactMeshProbeCommand: Codable {
    let schemaVersion: UInt64
    let runID: UUID
    let scenarioID: String
    let challenge: String
    let mode: String
    let cut: ArtifactMeshCut
    let faultAction: ArtifactMeshFaultAction
    let faultTiming: ArtifactMeshFaultTiming
    let expectedPayloadCommit: String
    let expectedPayloadTree: String
}

struct ArtifactMeshProbeEvent: Codable {
    let schemaVersion: UInt64
    let ordinal: UInt64
    let runID: UUID
    let scenarioID: String
    let challengeDigest: String
    let phase: ArtifactMeshProbePhase
    let processID: Int32
    let bootIdentityDigest: String
    let containerIdentityDigest: String
    let archiveCDHash: String
    let operation: ArtifactMeshOperation?
    let cut: ArtifactMeshCut?
    let faultAction: ArtifactMeshFaultAction
    let transactionID: UUID?
    let storeIdentity: UUID?
    let generation: UInt64?
    let recordRoot: String?
    let casHeadRoot: String?
    let ordinaryPutFloor: UInt64?
    let recoveryFloor: UInt64?
    let terminal: ArtifactMeshTerminal?
    let previousEventDigest: String
    let eventDigest: String
}
```

Implement explicit tagged `Codable` for `ArtifactMeshCut`; the two canonical
goldens are `{"operation":"genesisReserve","tag":"before"}` and
`{"operation":"genesisReserve","tag":"after"}`. The operation value must be
one exact `ArtifactMeshOperation.rawValue`; reject extra/missing/future tags.
`schemaVersion` is exactly 1. Events are canonical sorted-key JSON lines with
SHA-256 chain; no event accepts a caller-written success Boolean.

- [ ] **Step 5: Implement normal and fault-bootstrap app entry**

`ArtifactMeshDeviceLabApp.swift` parses exactly:

```text
--qinao-artifact-mesh-mode normal|fault-bootstrap
--command-file CONTAINER_RELATIVE_REGULAR_FILE
```

It rejects absolute paths, `..`, symlinks, duplicate flags, unknown flags, and command files outside `Library/Application Support/QinaoArtifactMeshLab/Commands`. For `normal`, call `ArtifactMeshRecoveryProbe.run(command:)`; for `fault-bootstrap`, call only `ArtifactMeshFaultBootstrap.run(command:)`. Both paths end at an unbounded `DispatchSemaphore(value: 0).wait()` after writing a kill barrier; there is no normal-exit success path.

- [ ] **Step 6: Implement the normal probe**

`ArtifactMeshRecoveryProbe.swift` imports `BASMemory`, `BASRuntimeCore`, `Crypto`, and `QinaoDefaults`. It:

1. canonical-decodes the command;
2. binds app bundle, CDHash supplied through signed build metadata, PID, boot identity, app-container resource identifier, payload commit/tree, run ID, scenario, and challenge digest;
3. constructs `QinaoArtifactMeshConfiguration` with the canonical application-support container URL resource identifier, scenario-specific store role, the nonshared group read from signed `QinaoKeychainAccessGroup` Info.plist build metadata, and the scenario's exact create/reopen intent;
4. installs a lab fault callback only when the closed command requests one of the three live faults;
5. executes operations in the frozen order up to the requested cut;
6. writes each chained event with `.completeFileProtectionUntilFirstUserAuthentication`;
7. blocks at `liveKillBarrier` while the store and process remain alive.

The `k3ReferenceCommit` operation is a lab-only content-free referenceability observation after the returned production store receipt; it creates no K3 owner row and cannot be consumed as K3 authority. For recovery launch the probe opens through the same Qinao production factory, observes the actual terminal, emits it once, and blocks. It never deletes/mutates a store family or Keychain item directly.

- [ ] **Step 7: Implement the structurally restricted fault bootstrap**

`ArtifactMeshFaultBootstrap.swift` imports only:

```swift
import CryptoKit
import Foundation
import Security
```

It must contain no `BASMemory`, `BASRuntimeCore`, `QinaoDefaults`, `BASArtifactSQLiteStore`, SQLite open, or store-factory symbol. It canonical-decodes only `mode = fault-bootstrap` commands whose timing is `beforeRecoveryOpen`; performs exactly the named file-family, anchor-byte, floor-byte, key-epoch-byte, quarantine-member, or lease-expiry mutation; records before/after physical digests; emits `mutationKillBarrier`; and blocks. It never constructs or opens the production store.

File mutations use file descriptors with `O_NOFOLLOW`, same-container canonical descendants, regular-file checks, and atomic rename. Keychain mutation uses the app's own exact service/account/access group; the controller never reads or writes that Keychain item.

- [ ] **Step 8: Build the exact archive shape without claiming device proof**

```bash
xcodebuild archive \
  -project SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj \
  -scheme ArtifactMeshDeviceLab \
  -destination 'generic/platform=iOS' \
  -archivePath /private/tmp/qinao-artifact-mesh-w1-task0/lab-shape.xcarchive \
  'OTHER_SWIFT_FLAGS=$(inherited) -DQINAO_ARTIFACT_MESH_DEVICE_LAB' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
xcodebuild archive \
  -project SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj \
  -scheme ArtifactMeshCASContenderLab \
  -destination 'generic/platform=iOS' \
  -archivePath /private/tmp/qinao-artifact-mesh-w1-task0/cas-contender-shape.xcarchive \
  'OTHER_SWIFT_FLAGS=$(inherited) -DQINAO_ARTIFACT_MESH_DEVICE_LAB' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Expected: both archives succeed as unsigned shape evidence only. They are not
physical or production proof.

- [ ] **Step 9: Prove structural exclusion and commit**

```bash
python3 - <<'PY'
from pathlib import Path
pkg = Path("SampleHost/Package.swift").read_text()
if '"ArtifactMeshDeviceLab"' not in pkg:
    raise SystemExit("SampleHost does not exclude whole lab directory")
fault = Path("SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshFaultBootstrap.swift").read_text()
for token in ("BASMemory", "BASRuntimeCore", "QinaoDefaults",
              "BASArtifactSQLiteStore", "sqlite3_open"):
    if token in fault:
        raise SystemExit(f"fault bootstrap can open store via {token}")
pbx = Path("SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj").read_text()
scheme = Path("SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme").read_text()
cas_scheme = Path("SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme").read_text()
if "IPHONEOS_DEPLOYMENT_TARGET = 27.0" not in pbx:
    raise SystemExit("lab iOS floor drift")
if "ArtifactMeshDeviceLab" not in scheme:
    raise SystemExit("shared scheme drift")
if "ArtifactMeshCASContenderLab" not in cas_scheme:
    raise SystemExit("CAS contender shared scheme drift")
print("artifact-mesh-lab-shape: PASS products=2 shared_schemes=2")
PY
git add \
  SampleHost/Package.swift \
  SampleHost/ArtifactMeshDeviceLab/project.yml \
  SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj \
  SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme \
  SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme \
  SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLabApp.swift \
  SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLab.entitlements \
  SampleHost/ArtifactMeshDeviceLab/CASContender/ArtifactMeshCASContenderApp.swift \
  SampleHost/ArtifactMeshDeviceLab/Protocol/ArtifactMeshRecoveryProtocol.swift \
  SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshRecoveryProbe.swift \
  SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshFaultBootstrap.swift
git commit -m "test(artifact-mesh): add isolated iOS recovery lab"
```

Expected: two real lab-only app products, two shared schemes, iOS 27.0, and
exactly eleven committed paths.

---

### Task 8: Freeze and Validate the Exact 40-Row Recovery Matrix

**Files:**
- Create: `docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json`
- Create: `scripts/check_artifact_mesh_device_recovery.py`
- Create: `scripts/test_check_artifact_mesh_device_recovery.py`

**Interfaces:**
- Consumes: the closed operations/fault/timing/terminal vocabularies.
- Produces: a candidate-index-bound matrix checker with exactly 26 no-fault rows plus exactly 14 named fault rows. It cannot accept a reduced/substituted/caller-passed matrix.

- [ ] **Step 1: Write RED checker tests**

The unit module contains one positive exact-matrix fixture and these mutations:

```text
delete each of 13 before rows
delete each of 13 after rows
swap before/after
duplicate scenarioID
delete each of 14 fault actions
add a fifteenth fault row
replace required fault with none
move dropSQLiteReply or dropK3Reply off atDurableCommitBeforeReply
move raceSecondCAS off whileProcessAlive
move a family/key/floor/corruption/lease fault off beforeRecoveryOpen
move protectedDataUnavailable off afterRebootBeforeFirstUnlock
change protectedDataUnavailable terminal from denyUnavailable
accept blockedPlatformUnexercisable as a matrix terminal
change cardinality from 40
add unknown field
change payload commit/tree binding
accept caller success Boolean
accept normal process exit in place of kill barrier
accept one CAS contender or no winner/loser
accept fault bootstrap that opened the store
accept unchanged boot identity for protectedDataUnavailable
```

Each mutation must produce one stable diagnostic and non-zero exit.

In the same uncommitted RED edit, create
`scripts/check_artifact_mesh_device_recovery.py` as an importable stub with
the final parser/checker/canonical-matrix callable and CLI signatures used by
the tests. Every entrypoint raises
`ArtifactMeshDeviceRecoveryError("artifact-mesh.matrix.unimplemented")`.
The positive and mutation fixtures remain embedded in the test module at
this step; absence of the checked-in matrix is not the RED reason. Do not
stage the stub.

- [ ] **Step 2: Run RED**

```bash
python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery
```

Expected: every named case is discovered and fails only on
`artifact-mesh.matrix.unimplemented`. Import failure, missing checked-in
matrix, empty discovery, or an arbitrary exception is invalid RED.

- [ ] **Step 3: Freeze exact checker constants**

Replace the Step-1 stub in place and define:

```python
OPERATIONS = (
    "genesisReserve",
    "genesisSQLiteCommit",
    "genesisAnchorPromote",
    "reopen",
    "ordinaryPutAnchorPending",
    "ordinaryPutSQLiteCommit",
    "walShmCheckpoint",
    "ordinaryPutAnchorFloorPromote",
    "k3ReferenceCommit",
    "quarantineInstall",
    "recoveryLeaseAcquire",
    "recoveryFloorUpdate",
    "recoveryComplete",
)

FAULT_TIMING = {
    "deleteDatabase": "beforeRecoveryOpen",
    "deleteWAL": "beforeRecoveryOpen",
    "deleteSHM": "beforeRecoveryOpen",
    "replacePartialFamily": "beforeRecoveryOpen",
    "replaceStaleFamily": "beforeRecoveryOpen",
    "substituteWrongKeyEpoch": "beforeRecoveryOpen",
    "regressAnchorFloor": "beforeRecoveryOpen",
    "deleteKeychainAnchor": "beforeRecoveryOpen",
    "dropSQLiteReply": "atDurableCommitBeforeReply",
    "dropK3Reply": "atDurableCommitBeforeReply",
    "raceSecondCAS": "whileProcessAlive",
    "corruptQuarantineMember": "beforeRecoveryOpen",
    "expireRecoveryLease": "beforeRecoveryOpen",
    "protectedDataUnavailable": "afterRebootBeforeFirstUnlock",
}

FAULT_TERMINAL = {
    "deleteDatabase": "quarantine",
    "deleteWAL": "quarantine",
    "deleteSHM": "quarantine",
    "replacePartialFamily": "quarantine",
    "replaceStaleFamily": "quarantine",
    "substituteWrongKeyEpoch": "quarantine",
    "regressAnchorFloor": "quarantine",
    "deleteKeychainAnchor": "quarantine",
    "dropSQLiteReply": "promote",
    "dropK3Reply": "queryReconcile",
    "raceSecondCAS": "queryReconcile",
    "corruptQuarantineMember": "quarantine",
    "expireRecoveryLease": "recoveryComplete",
    "protectedDataUnavailable": "denyUnavailable",
}

TERMINALS = {
    "resume", "promote", "clearPending", "queryReconcile",
    "quarantine", "denyUnavailable", "recoveryComplete",
}
```

The exact row key set is:

```python
ROW_KEYS = {
    "scenarioID", "initialState", "cut", "mandatoryFaultAction",
    "faultTiming", "expectedReopenDisposition",
    "expectedStoreIdentity", "expectedGeneration",
    "expectedRecordRoot", "expectedCASHead",
    "expectedOrdinaryPutFloor", "expectedRecoveryFloor",
}
```

- [ ] **Step 4: Create all 26 no-fault rows**

The checked-in matrix outer keys are exactly:

```json
{
  "schema_version": 1,
  "matrix_id": "qinao-artifact-mesh-device-recovery-matrix-v1",
  "operations": [],
  "rows": []
}
```

`operations` is exactly `OPERATIONS`. Add one row for every operation with `cut = {"tag":"before","operation":"SAME_OPERATION"}` and one with `tag = after`; IDs use `nofault.OPERATION.before` and `nofault.OPERATION.after`; `mandatoryFaultAction = none`; `faultTiming = none`.

Freeze the expected terminal pair by operation:

| Operation | before | after |
|---|---|---|
| `genesisReserve` | `resume` | `resume` |
| `genesisSQLiteCommit` | `resume` | `promote` |
| `genesisAnchorPromote` | `promote` | `resume` |
| `reopen` | `resume` | `resume` |
| `ordinaryPutAnchorPending` | `resume` | `clearPending` |
| `ordinaryPutSQLiteCommit` | `clearPending` | `promote` |
| `walShmCheckpoint` | `promote` | `promote` |
| `ordinaryPutAnchorFloorPromote` | `promote` | `resume` |
| `k3ReferenceCommit` | `queryReconcile` | `queryReconcile` |
| `quarantineInstall` | `quarantine` | `quarantine` |
| `recoveryLeaseAcquire` | `recoveryComplete` | `recoveryComplete` |
| `recoveryFloorUpdate` | `recoveryComplete` | `recoveryComplete` |
| `recoveryComplete` | `recoveryComplete` | `recoveryComplete` |

Use these exact expected references:

```text
expectedStoreIdentity = "$derived.storeIdentity"
expectedRecordRoot = "$derived.recordRoot"
expectedCASHead = "$derived.casHead"
```

The checker derives those three referenced values from the deterministic command, commitment-key material held by the lab process, and raw pre-cut bytes; it does not read an app-supplied expected value. `expectedGeneration`, `expectedOrdinaryPutFloor`, and `expectedRecoveryFloor` use the exact mapping in Step 6.

- [ ] **Step 5: Add exactly the 14 fault rows**

Use this exact table; every ID uses `fault.ACTION`:

| Action | Initial state | Cut | Timing | Terminal |
|---|---|---|---|---|
| `deleteDatabase` | `committedG1` | after `reopen` | `beforeRecoveryOpen` | `quarantine` |
| `deleteWAL` | `walCheckpointedG1` | after `walShmCheckpoint` | `beforeRecoveryOpen` | `quarantine` |
| `deleteSHM` | `walCheckpointedG1` | after `walShmCheckpoint` | `beforeRecoveryOpen` | `quarantine` |
| `replacePartialFamily` | `walCheckpointedG1` | after `walShmCheckpoint` | `beforeRecoveryOpen` | `quarantine` |
| `replaceStaleFamily` | `committedG1` | after `ordinaryPutAnchorFloorPromote` | `beforeRecoveryOpen` | `quarantine` |
| `substituteWrongKeyEpoch` | `committedG0` | after `genesisAnchorPromote` | `beforeRecoveryOpen` | `quarantine` |
| `regressAnchorFloor` | `committedG1` | after `ordinaryPutAnchorFloorPromote` | `beforeRecoveryOpen` | `quarantine` |
| `deleteKeychainAnchor` | `committedG0` | after `genesisAnchorPromote` | `beforeRecoveryOpen` | `quarantine` |
| `dropSQLiteReply` | `committedPendingG1` | after `ordinaryPutSQLiteCommit` | `atDurableCommitBeforeReply` | `promote` |
| `dropK3Reply` | `k3CommittedG1` | after `k3ReferenceCommit` | `atDurableCommitBeforeReply` | `queryReconcile` |
| `raceSecondCAS` | `committedG0` | before `ordinaryPutSQLiteCommit` | `whileProcessAlive` | `queryReconcile` |
| `corruptQuarantineMember` | `quarantinedG1` | after `quarantineInstall` | `beforeRecoveryOpen` | `quarantine` |
| `expireRecoveryLease` | `recoveryLeaseG1` | after `recoveryLeaseAcquire` | `beforeRecoveryOpen` | `recoveryComplete` |
| `protectedDataUnavailable` | `committedG1` | before `reopen` | `afterRebootBeforeFirstUnlock` | `denyUnavailable` |

Every fault row uses the same exact expected-reference vocabulary as no-fault rows. The protected-data row remains in the 40-row file even when feasibility is blocked.

- [ ] **Step 6: Implement closed matrix validation**

Freeze the numeric expected state with this code; `expected_matrix()` serializes this mapping into the checked-in `rows` array and the checker independently requires byte-for-byte structural equality:

```python
NO_FAULT_EXPECTED = {
    "genesisReserve": {
        "before": ("fresh", "resume", 0, 0, 0),
        "after": ("genesisPending", "resume", 0, 0, 0),
    },
    "genesisSQLiteCommit": {
        "before": ("genesisPending", "resume", 0, 0, 0),
        "after": ("sqliteCommittedG0", "promote", 0, 0, 0),
    },
    "genesisAnchorPromote": {
        "before": ("sqliteCommittedG0", "promote", 0, 0, 0),
        "after": ("committedG0", "resume", 0, 0, 0),
    },
    "reopen": {
        "before": ("committedG0", "resume", 0, 0, 0),
        "after": ("committedG0", "resume", 0, 0, 0),
    },
    "ordinaryPutAnchorPending": {
        "before": ("committedG0", "resume", 0, 0, 0),
        "after": ("committedPendingG1", "clearPending", 0, 0, 0),
    },
    "ordinaryPutSQLiteCommit": {
        "before": ("committedPendingG1", "clearPending", 0, 0, 0),
        "after": ("sqliteCommittedG1", "promote", 1, 1, 0),
    },
    "walShmCheckpoint": {
        "before": ("sqliteCommittedG1", "promote", 1, 1, 0),
        "after": ("walCheckpointedG1", "promote", 1, 1, 0),
    },
    "ordinaryPutAnchorFloorPromote": {
        "before": ("walCheckpointedG1", "promote", 1, 1, 0),
        "after": ("committedG1", "resume", 1, 1, 0),
    },
    "k3ReferenceCommit": {
        "before": ("committedG1", "queryReconcile", 1, 1, 0),
        "after": ("k3CommittedG1", "queryReconcile", 1, 1, 0),
    },
    "quarantineInstall": {
        "before": ("corruptCommittedG1", "quarantine", 1, 1, 0),
        "after": ("quarantinedG1", "quarantine", 1, 1, 0),
    },
    "recoveryLeaseAcquire": {
        "before": ("quarantinedG1", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryLeaseG1", "recoveryComplete", 2, 1, 1),
    },
    "recoveryFloorUpdate": {
        "before": ("recoveryLeaseG1", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryFloorG2", "recoveryComplete", 2, 1, 1),
    },
    "recoveryComplete": {
        "before": ("recoveryFloorG2", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryCompleteG2", "recoveryComplete", 2, 1, 1),
    },
}

FAULT_EXPECTED_STATE = {
    "deleteDatabase": (1, 1, 0),
    "deleteWAL": (1, 1, 0),
    "deleteSHM": (1, 1, 0),
    "replacePartialFamily": (1, 1, 0),
    "replaceStaleFamily": (1, 1, 0),
    "substituteWrongKeyEpoch": (0, 0, 0),
    "regressAnchorFloor": (1, 1, 0),
    "deleteKeychainAnchor": (0, 0, 0),
    "dropSQLiteReply": (1, 1, 0),
    "dropK3Reply": (1, 1, 0),
    "raceSecondCAS": (1, 1, 0),
    "corruptQuarantineMember": (1, 1, 0),
    "expireRecoveryLease": (2, 1, 1),
    "protectedDataUnavailable": (1, 1, 0),
}

FAULT_SETUP = {
    "deleteDatabase": ("committedG1", "after", "reopen"),
    "deleteWAL": ("walCheckpointedG1", "after", "walShmCheckpoint"),
    "deleteSHM": ("walCheckpointedG1", "after", "walShmCheckpoint"),
    "replacePartialFamily":
        ("walCheckpointedG1", "after", "walShmCheckpoint"),
    "replaceStaleFamily":
        ("committedG1", "after", "ordinaryPutAnchorFloorPromote"),
    "substituteWrongKeyEpoch":
        ("committedG0", "after", "genesisAnchorPromote"),
    "regressAnchorFloor":
        ("committedG1", "after", "ordinaryPutAnchorFloorPromote"),
    "deleteKeychainAnchor":
        ("committedG0", "after", "genesisAnchorPromote"),
    "dropSQLiteReply":
        ("committedPendingG1", "after", "ordinaryPutSQLiteCommit"),
    "dropK3Reply":
        ("k3CommittedG1", "after", "k3ReferenceCommit"),
    "raceSecondCAS":
        ("committedG0", "before", "ordinaryPutSQLiteCommit"),
    "corruptQuarantineMember":
        ("quarantinedG1", "after", "quarantineInstall"),
    "expireRecoveryLease":
        ("recoveryLeaseG1", "after", "recoveryLeaseAcquire"),
    "protectedDataUnavailable":
        ("committedG1", "before", "reopen"),
}

def expected_row(
    scenario_id, initial_state, cut_tag, operation, fault,
    timing, terminal, generation, put_floor, recovery_floor,
):
    return {
        "scenarioID": scenario_id,
        "initialState": initial_state,
        "cut": {"tag": cut_tag, "operation": operation},
        "mandatoryFaultAction": fault,
        "faultTiming": timing,
        "expectedReopenDisposition": terminal,
        "expectedStoreIdentity": "$derived.storeIdentity",
        "expectedGeneration": generation,
        "expectedRecordRoot": "$derived.recordRoot",
        "expectedCASHead": "$derived.casHead",
        "expectedOrdinaryPutFloor": put_floor,
        "expectedRecoveryFloor": recovery_floor,
    }

def expected_rows():
    rows = []
    for operation in OPERATIONS:
        for cut_tag in ("before", "after"):
            initial, terminal, generation, put_floor, recovery_floor = (
                NO_FAULT_EXPECTED[operation][cut_tag]
            )
            rows.append(expected_row(
                f"nofault.{operation}.{cut_tag}",
                initial, cut_tag, operation, "none", "none", terminal,
                generation, put_floor, recovery_floor,
            ))
    for fault in FAULT_TIMING:
        initial, cut_tag, operation = FAULT_SETUP[fault]
        generation, put_floor, recovery_floor = (
            FAULT_EXPECTED_STATE[fault]
        )
        rows.append(expected_row(
            f"fault.{fault}", initial, cut_tag, operation, fault,
            FAULT_TIMING[fault], FAULT_TERMINAL[fault],
            generation, put_floor, recovery_floor,
        ))
    if len(rows) != 40:
        raise AssertionError(f"expected 40 rows, got {len(rows)}")
    return rows
```

Each numeric tuple is `(expectedGeneration, expectedOrdinaryPutFloor, expectedRecoveryFloor)`. The first three symbolic expected fields are always the exact `$derived.*` strings above. `expected_matrix()` iterates `OPERATIONS` and literal cut order `before,after`, then iterates fault actions in `FAULT_TIMING` insertion order; no JSON file order can select or omit a row.

`validate_matrix(document)` must:

1. reject non-canonical JSON, symlinks, non-regular files, duplicate JSON keys, unknown outer/row/cut keys, booleans where integers are expected, and future schema versions;
2. require `operations == list(OPERATIONS)`;
3. require exactly 40 unique `scenarioID` rows;
4. require exact no-fault set `{operation} × {before,after}`;
5. require exact fault set `FAULT_TIMING.keys()`;
6. compare each timing/terminal to `FAULT_TIMING`/`FAULT_TERMINAL`;
7. enforce scenario setup/cut table from Step 5;
8. require symbolic expected references exactly where declared and canonical unsigned integers elsewhere;
9. verify the matrix blob is a stage-0 regular blob in `payload_tree_oid`;
10. reject any `success`, `passed`, `wave`, owner/status, admission, receipt, result, or device identity field.

The CLI is exactly:

```text
check_artifact_mesh_device_recovery.py
  --root REPOSITORY_ROOT
  --matrix CHECKED_IN_MATRIX
  --payload-commit PAYLOAD_COMMIT_OID
  --payload-tree PAYLOAD_TREE_OID
  [--device-trace EXTERNAL_REOPENED_TRACE]
  [--archive-attestation EXTERNAL_REOPENED_ARCHIVE_ATTESTATION]
  [--external-reopen-receipt EXTERNAL_RECEIPT]
  [--production-reachability TEMPORARY_ACTUAL_MANIFEST]
```

With no evidence options it validates schema/index only and prints `mode=matrix`; this cannot claim device proof. With any evidence option, all four evidence options are mandatory and it prints `mode=device` only after complete validation.

- [ ] **Step 7: Run GREEN and commit**

```bash
python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery
python3 scripts/check_artifact_mesh_device_recovery.py \
  --root . \
  --matrix docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
git add \
  docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json \
  scripts/check_artifact_mesh_device_recovery.py \
  scripts/test_check_artifact_mesh_device_recovery.py
git commit -m "test(artifact-mesh): freeze physical recovery matrix"
```

Expected:

```text
artifact-mesh-device-recovery: PASS mode=matrix rows=40 no_fault=26 faults=14
```

and one commit with exactly three paths.

---

### Task 9: Implement the Real Device Controller and Evidence Reopen Contract

**Files:**
- Create: `scripts/run_artifact_mesh_device_recovery.py`
- Modify: `scripts/check_artifact_mesh_device_recovery.py`
- Modify: `scripts/test_check_artifact_mesh_device_recovery.py`

**Interfaces:**
- Consumes in candidate-preflight mode: exact matrix, signed lab project, caller-selected preflight-only device/team, and candidate payload identity.
- Consumes in production only through `ProtectedAdmissionClient.run_active_gates(lease:)`: the bootstrap-owned opaque `ExternalPhysicalGateBinding`, signed `EvaluationLease`, controller-side broker, selected toolchain/profile/archives/device policy, and encrypted custody capability.
- Produces: a non-authoritative preflight disposition in Phase A, or broker-authenticated raw events consumed by the active B0 gate in Phase B. It never creates an admission leaf, `Cw`, `Sw`, receipt child, intent, protected-ref mutation, or success field in Git.

The candidate-preflight CLI is exactly:

```text
run_artifact_mesh_device_recovery.py
  --root REPOSITORY_ROOT
  --matrix CHECKED_IN_MATRIX
  --payload-commit PAYLOAD_COMMIT_OID
  --payload-tree PAYLOAD_TREE_OID
  --device DEVICE_UDID
  --development-team DEVELOPMENT_TEAM_ID
  --output-directory ABSOLUTE_PATH_OUTSIDE_REPOSITORY
  --mode candidate-preflight
```

The production executable surface is separately exact:

```text
run_artifact_mesh_device_recovery.py
  --mode production
  --lease-fd 3
  --physical-broker-fd 4
  --custody-fd 5
```

FDs 3/4/5 are inherited only from the authenticated protected runner. The
controller validates that they are already-open non-path capabilities and that
the service-envelope-verified lease binds the current payload and active gate.
Production rejects `--root`, `--matrix`, `--payload-*`, `--device`,
`--development-team`, `--output-directory`,
`--selected-shipping-archive`, `--bootstrap`, `--evidence-client`,
toolchain/profile/custody selectors, and every `QINAO_*` environment variable.
It derives all corresponding values from the signed lease and its opaque
`ExternalPhysicalGateBinding`; this plan does not mirror that binding's fields.
Candidate-preflight rejects FDs 3/4/5 and every production-only argument and
cannot produce an external reopen receipt.

Exit codes are closed: `0 = all 40 rows exercisable`, `20 = only protectedDataUnavailable blockedPlatformUnexercisable after all other 39 rows passed`, `21 = signing/profile unavailable before execution`, `22 = physical device unavailable before execution`, `1 = evidence/behavior failure`, and `2 = CLI/root/schema misuse`. Candidate-preflight records 0/20/21/22 as an honest non-authoritative `preflight-disposition-v1.json` outside Git, but Task 10 may propose status and emit a handoff only for 0; codes 20/21/22 stop without either, and codes 1/2 fail. Production also accepts only 0.

- [ ] **Step 1: Write RED controller tests with a recording command runner**

Add tests that require:

```text
root guard called and reparentedProgram returned
payload commit/tree exists and tree belongs to commit
matrix checked before archive
exact xcodebuild archive project/scheme/destination
signed app extracted from exact archive
codesign/provisioning/CDHash/entitlement checks precede install
40 fresh run IDs and 40 fresh challenges
every ordinary crash victim proven alive before SIGKILL and dead afterward
no app-authored normal terminal before kill
beforeRecoveryOpen launches only fault-bootstrap, proves it alive, SIGKILLs it, proves it dead, then launches normal recovery
drop-reply verifies durable commit event before a suppressed reply and kill
CAS race verifies two live contender IDs and one winner/one loser
container copy uses appDataContainer and exact bundle ID
controller never executes security/Keychain mutation
protected row requires changed boot identity and pre-first-unlock observation
blocked feasibility leaves protected row unexecuted
production accepts only lease/broker/custody capability FDs
production rejects every selector CLI and QINAO_* environment key
candidate-preflight rejects production-only arguments
raw output path inside repository is rejected
external reopen bytes must equal uploaded bytes
unknown devicectl JSON shape fails
voluntary app exit fails
uninstall/cleanup failure is recorded and makes production fail
two distinct signed app PIDs race one Keychain state and produce one winner/one conflict
production tool executable/version/SDK/archive/profile facts equal the signed binding
encrypted workspace key destruction and no-residue verification are mandatory
crash recovery destroys orphaned workspace keys before retry
```

The recording runner returns structured JSON fixtures with real `devicectl` field paths captured from Xcode 27 help/shape fixtures; prose stdout is never parsed.

In the same uncommitted RED edit, create
`scripts/run_artifact_mesh_device_recovery.py` as the smallest importable
stub with the final controller callable, argument parser, and `main` surface
consumed by the new tests. Every operation raises
`ArtifactMeshDeviceRecoveryRunnerError("artifact-mesh.device-runner.unimplemented")`;
it executes no command and opens no capability or output path. Do not stage
the stub.

- [ ] **Step 2: Run RED**

```bash
python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery
```

Expected: checker tests remain green; every named controller test is
discovered and fails only on
`artifact-mesh.device-runner.unimplemented`. Import failure, missing runner,
or zero discovery is invalid RED.

- [ ] **Step 3: Implement sanitized command execution**

Replace the Step-1 stub in place and add:

```python
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
from collections.abc import Sequence
from dataclasses import dataclass

def reject_production_selector_environment(
    environment: dict[str, str],
) -> None:
    exact = {
        "DEVELOPER_DIR", "TOOLCHAINS", "SDKROOT",
        "XCODE_XCCONFIG_FILE", "DEVELOPMENT_TEAM",
        "CODE_SIGN_IDENTITY", "PROVISIONING_PROFILE",
        "PROVISIONING_PROFILE_SPECIFIER",
    }
    forbidden = sorted(
        key for key in environment
        if key in exact or key.startswith("QINAO_")
    )
    if forbidden:
        raise RuntimeError(
          f"production selector environment forbidden: {forbidden}")

@dataclass(frozen=True)
class CommandResult:
    argv: Sequence[str]
    returncode: int
    json_path: Path | None
    log_path: Path
    stdout_sha256: str
    stderr_sha256: str

class CommandRunner:
    def __init__(
        self,
        *,
        allowed_tools: frozenset[Path],
        developer_dir: Path,
        isolated_home: Path,
        isolated_tmp: Path,
    ) -> None:
        resolved = frozenset(path.resolve(strict=True)
                             for path in allowed_tools)
        if not resolved or any(not path.is_absolute()
                               for path in resolved):
            raise RuntimeError("bound tools must be absolute")
        self._allowed_tools = resolved
        self._developer_dir = developer_dir.resolve(strict=True)
        self._isolated_home = isolated_home.resolve(strict=True)
        self._isolated_tmp = isolated_tmp.resolve(strict=True)

    def _environment(self) -> dict[str, str]:
        # Start empty. Never copy os.environ into a production child.
        return {
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "DEVELOPER_DIR": str(self._developer_dir),
            "HOME": str(self._isolated_home),
            "TMPDIR": str(self._isolated_tmp) + "/",
            "LANG": "C",
            "LC_ALL": "C",
            "NSUnbufferedIO": "YES",
        }

    @staticmethod
    def _write_log(
        path: Path,
        completed: subprocess.CompletedProcess[bytes],
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(
          b"stdout\n" + completed.stdout
          + b"\nstderr\n" + completed.stderr)
        path.chmod(0o600)

    def _run(
        self,
        argv: Sequence[str],
        *,
        json_path: Path | None,
        log_path: Path,
    ) -> tuple[subprocess.CompletedProcess[bytes], CommandResult]:
        command = tuple(argv)
        if not command or any(not value for value in command):
            raise RuntimeError("empty command/argument")
        executable = Path(command[0])
        if (
            not executable.is_absolute()
            or executable.resolve(strict=True)
                not in self._allowed_tools
        ):
            raise RuntimeError("executable is not lease-bound")
        if json_path is not None:
            json_path.parent.mkdir(parents=True, exist_ok=True)
            json_path.unlink(missing_ok=True)
        completed = subprocess.run(
            command,
            shell=False,
            check=False,
            capture_output=True,
            timeout=300,
            env=self._environment(),
        )
        self._write_log(log_path, completed)
        result = CommandResult(
            argv=command,
            returncode=completed.returncode,
            json_path=json_path,
            log_path=log_path,
            stdout_sha256=hashlib.sha256(
              completed.stdout).hexdigest(),
            stderr_sha256=hashlib.sha256(
              completed.stderr).hexdigest(),
        )
        if completed.returncode != 0:
            raise RuntimeError(
              f"command failed rc={completed.returncode}")
        return completed, result

    def run_json(
        self,
        argv: Sequence[str],
        *,
        json_path: Path,
        log_path: Path,
    ) -> tuple[dict[str, object], CommandResult]:
        _, result = self._run(
          argv, json_path=json_path, log_path=log_path)
        metadata = json_path.lstat()
        if (
            not stat.S_ISREG(metadata.st_mode)
            or json_path.is_symlink()
        ):
            raise RuntimeError("JSON output is not a regular file")

        def unique_object(
            pairs: list[tuple[str, object]],
        ) -> dict[str, object]:
            value: dict[str, object] = {}
            for key, item in pairs:
                if key in value:
                    raise RuntimeError(
                      f"duplicate JSON key: {key}")
                value[key] = item
            return value

        decoded = json.loads(
          json_path.read_bytes(),
          object_pairs_hook=unique_object)
        if not isinstance(decoded, dict):
            raise RuntimeError("JSON root is not an object")
        return decoded, result

    def run_bytes(
        self,
        argv: Sequence[str],
        *,
        log_path: Path,
    ) -> tuple[bytes, CommandResult]:
        completed, result = self._run(
          argv, json_path=None, log_path=log_path)
        return completed.stdout, result
```

Every `devicectl` caller supplies its exact `--json-output` pair to
`run_json`. The caller additionally validates the command-specific closed
field shape and all paths against the already validated output root. Any
non-zero exit, absent JSON, duplicate JSON key, unknown required shape, or
path escape fails.

The protected broker constructs `allowed_tools`, `developer_dir`, isolated
HOME, and isolated TMPDIR only from the service-envelope-verified lease and
opaque `ExternalPhysicalGateBinding`. The set contains exact absolute
`xcodebuild`, `xcrun`, `codesign`, `security`, `dwarfdump`, `otool`, and `nm`
paths; production commands never rely on PATH lookup. Before any archive or
device effect, the controller reruns the binding-prescribed
`xcodebuild -version`, SDK path/version, executable digest/mode, and selected
archive/profile checks and compares their observations to the lease. It rejects
inherited `DEVELOPER_DIR`, `TOOLCHAINS`, `SDKROOT`,
`XCODE_XCCONFIG_FILE`, signing/build selector variables, proxy variables,
dynamic-loader variables, Python variables, Git variables, and every
`QINAO_*`; none can reach a child because `_environment` starts empty.
Production calls
`reject_production_selector_environment(dict(os.environ))` before parsing a
lease or touching the device, while the protected runner itself launches the
controller with a fixed empty-derived environment.

- [ ] **Step 4: Bind and inspect the exact lab archive**

Candidate-preflight resolves its explicit preflight-only values. Production
receives the corresponding `BOUND_*` values only from the lease/broker and
runs the absolute lease-bound executable twice:

```text
BOUND_XCODEBUILD archive
-project SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj
-scheme ArtifactMeshDeviceLab
-destination generic/platform=iOS
-archivePath ENCRYPTED_WORKSPACE/ArtifactMeshDeviceLab.xcarchive
DEVELOPMENT_TEAM=BOUND_PUBLIC_TEAM_ID
CODE_SIGN_STYLE=Automatic
OTHER_SWIFT_FLAGS=$(inherited) -DQINAO_ARTIFACT_MESH_DEVICE_LAB

BOUND_XCODEBUILD archive
-project SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj
-scheme ArtifactMeshCASContenderLab
-destination generic/platform=iOS
-archivePath ENCRYPTED_WORKSPACE/ArtifactMeshCASContenderLab.xcarchive
DEVELOPMENT_TEAM=BOUND_PUBLIC_TEAM_ID
CODE_SIGN_STYLE=Automatic
OTHER_SWIFT_FLAGS=$(inherited) -DQINAO_ARTIFACT_MESH_DEVICE_LAB
```

Do not add `-allowProvisioningUpdates`; signing/profile availability is an external prerequisite, not an implicit network mutation.

Require exactly one app in each archive:

```text
Products/Applications/ArtifactMeshDeviceLab.app
Products/Applications/ArtifactMeshCASContenderLab.app
```

Capture and cross-check:

```text
codesign --verify --deep --strict --verbose=4 LAB_APP
codesign -d --entitlements :- LAB_APP
codesign -dvvv LAB_APP
security cms -D -i LAB_APP/embedded.mobileprovision
dwarfdump --uuid LAB_APP/ArtifactMeshDeviceLab
otool -L LAB_APP/ArtifactMeshDeviceLab
nm -gjU LAB_APP/ArtifactMeshDeviceLab
```

The controller passes
`OTHER_SWIFT_FLAGS=$(inherited) -DQINAO_ARTIFACT_MESH_DEVICE_LAB` as one
`xcodebuild` argument so the condition reaches local-package Swift targets as
well as both app targets; an app-target-only setting is not proof. Require
bundle IDs `com.qinao.artifact-mesh-device-lab` and
`com.qinao.artifact-mesh-cas-contender-lab`, iOS minimum 27.0, matching
Team/application identifiers, exactly the same one lab-only Keychain group,
default data protection, and absence of app groups/extensions/background
entitlements. The primary image contains the store fault sentinel and CAS lab
probe; the contender image contains the CAS lab probe but no SQLite/store
factory/fault-bootstrap symbol. The selected shipping archive contains neither
lab product, lab Keychain group, compile condition, probe, nor fault symbol.

- [ ] **Step 5: Drive each ordinary row through real process death**

For every matrix row except `protectedDataUnavailable`:

1. generate `runID = uuid4()` and `challenge = secrets.token_hex(32)`;
2. create a scenario-specific command and store role so prior Keychain state cannot satisfy it;
3. install the exact app:

```text
xcrun devicectl device install app
--device DEVICE_UDID
LAB_APP
--json-output INSTALL_JSON
```

4. copy the canonical command:

```text
xcrun devicectl device copy to
--device DEVICE_UDID
--source COMMAND_JSON
--destination Library/Application Support/QinaoArtifactMeshLab/Commands/RUN_ID.json
--domain-type appDataContainer
--domain-identifier com.qinao.artifact-mesh-device-lab
--json-output COPY_COMMAND_JSON
```

5. launch normal mode:

```text
xcrun devicectl device process launch
--device DEVICE_UDID
com.qinao.artifact-mesh-device-lab
--qinao-artifact-mesh-mode normal
--command-file Library/Application Support/QinaoArtifactMeshLab/Commands/RUN_ID.json
--json-output LAUNCH_JSON
```

6. read the PID from structured JSON, query `device info processes`, copy the event directory from the app data container, and verify the exact challenge-bound live barrier;
7. for a live/drop-reply/CAS action, require its exact pre-kill events;
8. prove PID alive, then run:

```text
xcrun devicectl device process terminate
--device DEVICE_UDID
--pid PROCESS_ID
--kill
--json-output KILL_JSON
```

9. query processes until the exact PID is absent; fail if an app normal-terminal event preceded death;
10. for `beforeRecoveryOpen`, launch `fault-bootstrap`, require mutation before/after digests and kill barrier, prove its distinct PID alive, SIGKILL it, and prove it dead;
11. relaunch normal recovery, copy trace, require exactly one expected terminal, prove the recovery PID's identity, kill it after the terminal barrier, and prove it dead.

For `raceSecondCAS`, first install both exact signed apps. The primary app
executes `cas-seed` and returns the challenge-bound expected digest. The
controller then launches the primary app in `cas-contender-a` mode and the
companion bundle in its sole contender mode without waiting for either
terminal. It proves two distinct PIDs are simultaneously alive, copies results
from their distinct app data containers, verifies the same challenge/expected
digest and contender IDs `{a,b}`, and requires the outcome multiset exactly
`{winner, compareAndSwapConflict}`. It then kills and proves both PIDs dead.
Reusing one PID, two Swift tasks, sequential contenders, two winners, two
losers, or direct controller `SecItem*` use fails.

Both apps are uninstalled after the race; the primary app is uninstalled after
every other scenario. A fresh challenge-specific Keychain account makes
uninstall-related persistence unable to cross-contaminate rows. Cleanup
failure is evidence and blocks production.

- [ ] **Step 6: Implement the protected-data feasibility and row**

Before executing that row, construct one content-free receipt from runtime-derived values:

```python
receipt = {
    "schema_version": 1,
    "receipt_kind": "ArtifactMeshProtectedDataFeasibilityReceipt",
    "payload_commit_oid": payload_commit_oid,
    "payload_tree_oid": payload_tree_oid,
    "archive_cdhash": archive_cdhash,
    "device_identity_digest": device_identity_digest,
    "staged_boot_identity_digest": staged_boot_identity_digest,
    "observed_boot_identity_digest": observed_boot_identity_digest,
    "status": feasibility_status,
}
```

or status `blockedPlatformUnexercisable`. The operator stages the challenge, physically reboots the bound device, and the controller independently proves boot identity changed. It may execute the row only if it can launch or independently observe the signed app before first unlock and obtain typed `denyUnavailable`. An ordinary lock, same boot identity, post-first-unlock run, or caller declaration cannot pass.

When status is blocked, leave `fault.protectedDataUnavailable` absent from executed rows, do not synthesize a terminal, and finish candidate-preflight with the blocked disposition. Production mode exits non-zero with `BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY reason=PROTECTED_DATA_UNAVAILABLE`.

- [ ] **Step 7: Build the raw bundle and enforce external put/reopen in production**

The manifest lists SHA-256/length for every archive inspection, structured
devicectl JSON/log, command, trace, copied container member, matrix blob,
source payload OID/tree, selected shipping archive observation, and feasibility
receipt.

Candidate-preflight creates a challenge-scoped encrypted ephemeral workspace
outside the repository/common Git directory, writes only through a root
directory descriptor with `openat`/`O_NOFOLLOW`, and destroys its workspace key
after emitting the privacy-clean disposition. `--output-directory` names only
the parent for this non-authoritative encrypted workspace; it never names a
production custody root.

Production obtains an already-open encrypted workspace/custody capability on
FD 5 from the external physical broker. The workspace key is held by that
broker, is never present in argv/environment/manifest/repository/plaintext
files, and cannot be exported by the controller. All controller paths are
relative to the capability root; absolute paths, symlinks, hard links, path
escapes, pre-existing files, and caller-provided roots fail.

The external broker performs the bootstrap-owned custody operations behind
that capability:

```text
put immutable physical_device_trace under lease/evaluation identity
reopen that exact immutable object into a second encrypted capability
verify service envelopes and byte-identical SHA-256/length
stream reopened bytes to the active B0 gate
destroy both workspace keys
close capabilities
verify no readable local residue
emit privacy-clean custody/destruction receipt into
AuthenticatedGateResultBundle
```

Those are operations of the opaque `ExternalPhysicalGateBinding`, not a new
Artifact Mesh evidence-client API. There is no `--evidence-client`, bootstrap
path, provider, endpoint, profile, credential, raw key, or custody selector.
The controller sees only capabilities and content bytes. A repository script,
copied local binary, local tar reopen, caller digest, or unavailable external
object cannot substitute.

Crash recovery is service-owned and create-once: before retrying an evaluation,
the broker reopens its lease/evaluation workspace journal, destroys every
orphaned key, verifies the corresponding encrypted roots are unreadable and
removed, and only then issues fresh capabilities. A crash after external put
reopens the same immutable object; it never reuploads from remembered local
paths. Missing destruction/no-residue evidence blocks the gate and prevents an
`AuthenticatedGateResultBundle`.

- [ ] **Step 8: Extend device-mode checker validation**

Device mode must independently require:

```text
40 unique commands/run IDs/challenges
40 exact rows, unless the one protected row is explicitly blocked (which is a failing production terminal)
one archive/device/container/boot binding
per-row event digest continuity and exact ordinal/phase order
alive-before/dead-after for crash victim and any fault bootstrap
no normal terminal before victim death
fault bootstrap contains no store-open event
dropSQLiteReply has durable SQLite commit, suppressed delivery, then live kill barrier
dropK3Reply has durable K3 commit, suppressed delivery, then live kill barrier
raceSecondCAS has two simultaneously live distinct app PIDs and one winner/one conflict
every SQLite connection proves PERSIST_WAL=1 and final-close sidecars persist
quarantine performs one durable dedicated-directory rename and crash-cut recovery never splits the family
actual terminal/floors/roots equal matrix-resolved expectations
selected shipping archive contains no lab bundle/condition/probe/fault symbol
production reachability classifies ArtifactMeshDeviceLab as lab-only and shipping paths empty
external put/reopen receipts bind exact raw bundle and signed lease
workspace-key destruction and no-readable-residue receipt are verified
```

The checker parses no caller Boolean and never trusts a controller summary without reopening raw leaf events.

- [ ] **Step 9: Run GREEN**

```bash
python3 -m unittest -v scripts.test_check_artifact_mesh_device_recovery
python3 scripts/check_artifact_mesh_device_recovery.py \
  --root . \
  --matrix docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
```

Expected: all controller/checker mutation tests pass; matrix-only output remains exactly `rows=40 no_fault=26 faults=14`.

- [ ] **Step 10: Commit**

```bash
git add \
  scripts/run_artifact_mesh_device_recovery.py \
  scripts/check_artifact_mesh_device_recovery.py \
  scripts/test_check_artifact_mesh_device_recovery.py
git commit -m "test(artifact-mesh): drive physical crash recovery"
```

Expected: exactly three paths.

---

### Task 10: Close Phase A, Propose the Owner-Row Transition, and Emit the Non-Authoritative Handoff

**Files:**
- Verify only: all Task 1-9 files and the admitted-W0 Ledger preimage
- Modify exactly once after the first full pass: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Create outside Git: `/private/tmp/qinao-artifact-mesh-w1-task0/unit-preflight-receipt-v1.json`
- Create outside Git: `/private/tmp/qinao-artifact-mesh-w1-task0/handoff-v1.json`
- Create outside Git: `/private/tmp/qinao-artifact-mesh-w1-task0/device-preflight/`

**Interfaces:**
- Consumes: service-envelope-verified `AdmittedWaveV1` returned by `ProtectedAdmissionClient.reopen_admitted_predecessor()` and all Phase-A commits.
- Produces: one exact one-file candidate proposal changing only the unique
  `artifact.mesh` owner row's `status` from `converging` to `implemented`,
  followed by `ArtifactMeshW1Task0HandoffV1`. The handoff unlocks later W1
  compilation only; neither the commit nor the handoff admits W1, makes the
  proposal authoritative, or substitutes for final-W1-`Pw` proof.

- [ ] **Step 1: Require a clean reparented-program root and reverify admitted W0 independently**

Run the Execution-Root Guard command from the plan header with
`--require-clean`, then have the protected runner call
`ProtectedAdmissionClient.reopen_admitted_predecessor()` again and verify the
active B0 service envelope. The only two read-only shell projections it
exposes are the authenticated seal OID as `ADMITTED_W0_SEAL` and the
authenticated admission-chain digest as `ADMITTED_W0_CHAIN_DIGEST`. Then
require:

```bash
test "$(git cat-file -t "$ADMITTED_W0_SEAL")" = commit
git merge-base --is-ancestor "$ADMITTED_W0_SEAL" HEAD
```

Expected: root lineage is `reparentedProgram`; the service-envelope-verified
final W0 seal is the Phase-A base and is an ancestor of the Phase-A tip.
`ADMITTED_W0_CHAIN_DIGEST` must byte-equal
`admittedW0.admission_chain_digest` and match 64 lowercase hex. Unsigned
`/private/tmp` admitted-wave JSON is not read.

- [ ] **Step 2: Run all exact non-empty unit gates**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_artifact_mesh_device_recovery
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoArtifactMeshAssemblyTests \
  --require-suite QinaoArtifactMeshAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoSovereignHostAssemblyTests \
  --require-suite QinaoSovereignHostAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoEffectFacadeFreezeTests \
  --require-suite QinaoEffectFacadeFreezeTests
```

Expected: every suite has positive discovery/execution counts and 0 failures.

- [ ] **Step 3: Run the realized E/A gate over the exact Phase-A tip**

```bash
PHASE_A_COMMIT="$(git rev-parse HEAD)"
PHASE_A_TREE="$(git rev-parse HEAD^{tree})"
python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json \
  --payload-commit "$PHASE_A_COMMIT" \
  --payload-tree "$PHASE_A_TREE"
```

Expected:

```text
qinao-extension-slices: PASS mode=realized manifests=1 slices=4 wave=W1
```

The checker derives W1 from predecessor/payload lineage; no caller passes it.

- [ ] **Step 4: Prove the historical M set and `converging` preimage were not rewritten**

Rerun Task 1's M-history check, then:

```bash
test -z "$(git diff --name-only "$ADMITTED_W0_SEAL"..HEAD -- \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json \
  docs/superpowers/evidence/qinao-owner-corrections/artifact-mesh-retrospective-create-correction-v1.json \
  docs/superpowers/specs/qinao-owner-ledger-v1.json)"
```

Expected: empty diff for historical evidence and Ledger. Parse the indexed
Ledger, require exactly one owner row with `owner_id = artifact.mesh`, require
its implementation-health `status = converging`, and compute its canonical
sorted-key/no-whitespace SHA-256 as `ARTIFACT_MESH_PRE_ROW_SHA256`. The
contract-lifecycle catalog is a separate namespace and is not inspected as
an owner-health substitute.

- [ ] **Step 5: Require a passing candidate-local physical preflight before any status proposal**

Require non-empty environment values:

```bash
test -n "$PREFLIGHT_DEVICE_ID"
test -n "$PREFLIGHT_DEVELOPMENT_TEAM"
```

Then run:

```bash
set +e
python3 scripts/run_artifact_mesh_device_recovery.py \
  --root . \
  --matrix docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json \
  --payload-commit "$PHASE_A_COMMIT" \
  --payload-tree "$PHASE_A_TREE" \
  --device "$PREFLIGHT_DEVICE_ID" \
  --development-team "$PREFLIGHT_DEVELOPMENT_TEAM" \
  --output-directory /private/tmp/qinao-artifact-mesh-w1-task0/device-preflight \
  --mode candidate-preflight
DEVICE_PREFLIGHT_RC=$?
set -e
case "$DEVICE_PREFLIGHT_RC" in
  0) ;;
  20|21|22) exit "$DEVICE_PREFLIGHT_RC" ;;
  *) exit "$DEVICE_PREFLIGHT_RC" ;;
esac
```

Expected only:

```text
artifact-mesh-device-recovery: PREFLIGHT rows=40 disposition=exercisable
```

The controller writes canonical `preflight-disposition-v1.json` with
`disposition = exercisable` and the exact pretransition
`PHASE_A_COMMIT/PHASE_A_TREE`. Exit 20, 21, or 22 remains its honest typed
signing/device/platform block, but it stops Task 10 immediately and produces
no status proposal and no handoff. No blocked disposition can be carried
forward as permission.

- [ ] **Step 6: Commit the sole reviewed candidate owner-row transition**

Record:

```bash
PRETRANSITION_COMMIT="$PHASE_A_COMMIT"
PRETRANSITION_TREE="$PHASE_A_TREE"
```

Edit only `docs/superpowers/specs/qinao-owner-ledger-v1.json`. Before staging,
run this semantic exact-delta check:

```bash
python3 - <<'PY'
import copy, hashlib, json, pathlib, subprocess

path = "docs/superpowers/specs/qinao-owner-ledger-v1.json"
before = json.loads(subprocess.check_output(
    ["git", "show", f"HEAD:{path}"], text=True
))
after = json.loads(pathlib.Path(path).read_text())

def unique_artifact_row(document):
    rows = [
        row for row in document["owners"]
        if row.get("owner_id") == "artifact.mesh"
    ]
    if len(rows) != 1:
        raise SystemExit("artifact.mesh owner row must be unique")
    return rows[0]

before_row = unique_artifact_row(before)
after_row = unique_artifact_row(after)
if before_row.get("status") != "converging":
    raise SystemExit("artifact.mesh preimage must be converging")
if after_row.get("status") != "implemented":
    raise SystemExit("artifact.mesh postimage must be implemented")

normalized = copy.deepcopy(after)
unique_artifact_row(normalized)["status"] = "converging"
if normalized != before:
    raise SystemExit("owner Ledger delta exceeds artifact.mesh status")

canonical = lambda value: json.dumps(
    value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
).encode()
print("artifact-mesh-owner-transition: PASS "
      f"pre={hashlib.sha256(canonical(before_row)).hexdigest()} "
      f"post={hashlib.sha256(canonical(after_row)).hexdigest()}")
PY
python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger \
  scripts.test_qinao_owner_ledger_v2
git add docs/superpowers/specs/qinao-owner-ledger-v1.json
test "$(git diff --cached --name-only)" = \
  docs/superpowers/specs/qinao-owner-ledger-v1.json
git diff --cached --check
git commit -m "docs(qinao): propose artifact mesh implemented status"
```

Require the new commit to have exactly one parent equal
`PRETRANSITION_COMMIT`, an exact one-path diff, and no mode change. Record:

```bash
STATUS_TRANSITION_COMMIT="$(git rev-parse HEAD)"
PHASE_A_COMMIT="$STATUS_TRANSITION_COMMIT"
PHASE_A_TREE="$(git rev-parse HEAD^{tree})"
test "$(git rev-parse HEAD^)" = "$PRETRANSITION_COMMIT"
test "$(git diff-tree --no-commit-id --name-only -r HEAD)" = \
  docs/superpowers/specs/qinao-owner-ledger-v1.json
```

This commit is a candidate proposal only. A failed or interrupted subsequent
rerun cannot unlock another W1 task and cannot be admitted.

- [ ] **Step 7: Rerun the complete Phase-A gate set over the post-transition tree**

Rerun every command from Steps 2 and 3 with the new
`PHASE_A_COMMIT/PHASE_A_TREE`. Then delete and recreate the candidate-preflight
output directory and rerun Step 5 against those new OIDs. The only accepted
result remains:

```text
artifact-mesh-device-recovery: PREFLIGHT rows=40 disposition=exercisable
```

Reparse the current indexed Ledger. Require the unique `artifact.mesh` owner
row to equal the Step-6 postimage byte-for-byte after canonicalization and
compute `ARTIFACT_MESH_POST_ROW_SHA256`. Compute:

```text
artifact_mesh_status_transition_sha256 =
  SHA256(
    "qinao-artifact-mesh-owner-status-transition-v1\0"
    || ARTIFACT_MESH_PRE_ROW_SHA256 || "\0"
    || ARTIFACT_MESH_POST_ROW_SHA256 || "\0"
    || PRETRANSITION_COMMIT || "\0"
    || STATUS_TRANSITION_COMMIT || "\0"
    || PRETRANSITION_TREE || "\0"
    || PHASE_A_TREE || "\0"
  )
```

Any failed unit, E/A, Ledger-row, or device check leaves Task 10 incomplete;
there is no handoff and no consumer unlock.

- [ ] **Step 8: Emit the post-transition unit receipt and handoff outside Git**

Create `unit-preflight-receipt-v1.json` from this exact object:

```python
unit_receipt = {
    "schema_version": 1,
    "payload_commit_oid": phase_a_commit,
    "payload_tree_oid": phase_a_tree,
    "swift_suites": swift_suite_receipts,
    "python_module": "scripts.test_check_artifact_mesh_device_recovery",
    "python_discovered": python_discovered,
    "python_failures": 0,
    "ea_slice_count": 4,
    "matrix_row_count": 40,
}
```

`swift_suite_receipts` is an exact five-row array in the order
`BASArtifactStoreTests`, `BASArtifactMeshKeychainAnchorTests`,
`QinaoArtifactMeshAssemblyTests`, `QinaoSovereignHostAssemblyTests`,
`QinaoEffectFacadeFreezeTests`; each row has exact keys
`suite,discovered,executed,failures`, positive parsed discovery/execution
counts, and `failures = 0`.

Every lower-case value below has one derivation and no caller/default seam:

| Value | Exact derivation |
|---|---|
| `admitted_w0_chain_digest` | `ADMITTED_W0_CHAIN_DIGEST` from Step 1's service-envelope-verified `admittedW0` |
| `pretransition_commit/tree` | Step 6's frozen `PRETRANSITION_COMMIT/TREE` |
| `status_transition_commit` | Step 6's exact one-parent/one-path commit |
| `phase_a_commit/tree` | fresh post-transition `git rev-parse HEAD` / `HEAD^{tree}` used by the Step-7 rerun |
| `swift_suite_receipts`, `python_discovered` | parsed only from Step 7's post-transition executions, never Step 2's earlier run |
| `ea_manifest_blob_sha256` | raw SHA-256 of the E/A manifest blob reopened from `PHASE_A_TREE` |
| `device_preflight_disposition` | Step 7's canonical final preflight postimage; it must equal `exercisable` and bind `PHASE_A_COMMIT/TREE` |
| `historical_create_evidence_set_digest` | the domain-separated digest below over the four raw blobs reopened from `PHASE_A_TREE` |
| `artifact_mesh_post_row_sha256` | Step 7's canonical unique owner-row postimage |
| `artifact_mesh_status_transition_sha256` | the Step-7 pre/post row+commit+tree digest |

After canonicalizing and writing `unit-preflight-receipt-v1.json`, reopen its
raw bytes, closed-parse the object, and only then derive
`unit_preflight_receipt_sha256`. No lower-case value may be copied from an
older `/private/tmp` run.

Create `handoff-v1.json` from this exact `ArtifactMeshW1Task0HandoffV1` object:

```python
handoff = {
    "schema_version": 1,
    "admitted_w0_chain_digest": admitted_w0_chain_digest,
    "pretransition_task0_commit_oid": pretransition_commit,
    "pretransition_task0_tree_oid": pretransition_tree,
    "status_transition_commit_oid": status_transition_commit,
    "task0_code_tree_oid": phase_a_tree,
    "ea_manifest_blob_sha256": ea_manifest_blob_sha256,
    "unit_preflight_receipt_sha256": unit_preflight_receipt_sha256,
    "device_preflight_disposition": "exercisable",
    "migration_disposition":
        "anchorlessV1QuarantineRollForwardOnly",
    "historical_create_evidence_set_digest":
        historical_create_evidence_set_digest,
    "artifact_mesh_owner_row_sha256":
        artifact_mesh_post_row_sha256,
    "artifact_mesh_status_transition_sha256":
        artifact_mesh_status_transition_sha256,
    "status_transition_from": "converging",
    "status_transition_to": "implemented",
}
```

No blocked device disposition is serializable in a handoff. Compute the
historical digest as:

```text
SHA256(
  "qinao-artifact-mesh-historical-create-evidence-set-v1\0"
  || for each of the four historical paths in UTF-8 byte order:
       path || "\0" || SHA256(raw blob reopened from PHASE_A_TREE) || "\0"
)
```

Canonicalize with sorted keys, no insignificant whitespace, UTF-8, and
exactly one terminal LF. Reread both files and
verify every OID/digest against Git and finalized W0 inputs. In particular,
`task0_code_tree_oid` and the unit receipt both bind the post-transition,
post-rerun tree; neither may bind `PRETRANSITION_TREE`.

- [ ] **Step 9: Prove the handoff is non-authoritative and leave clean**

```bash
test -z "$(git status --porcelain=v1)"
test -z "$(git ls-files | rg \
  'artifact-mesh-w1-task0/(handoff|unit-preflight)|device-preflight' || true)"
git log -1 --format='%H %T'
```

Expected: clean tree; no result file in Git; `HEAD` is exactly the
one-path status-proposal commit; its tree equals the handoff's
`task0_code_tree_oid`. Hand the two temporary paths to the W1 orchestrator.
Do not create `Cw`, `Sw`, or an admission receipt. The proposal is not
authoritative until final-W1-`Pw` B0 validation and W1 admission.

---

## Phase B — Final W1 `Pw` Physical Proof and Reachability Rebind

Phase B begins only after every other authorized W1 owner task has completed
and the W1 orchestrator has frozen one immutable final `Pw`. After separate
user authorization, `ProtectedAdmissionClient.pin_payload_and_issue_lease`
externally pins that exact OID and returns the signed proposal receipt/lease;
only then may `run_active_gates` enter the physical broker. No prebuilt `Cw`,
`Sw`, seal, candidate leaf, or admission result may launch or authorize
evaluation. Only
`ProtectedAdmissionClient.assemble_import_and_finalize` may consume the
authenticated bundle, construct/import Cw/Sw, create intent, perform
protected-ref CAS, and finalize attestation. Phase B edits no source, matrix,
test, checker, manifest, Ledger, or status byte. The final `Pw` already
contains Task 10's proposed `artifact.mesh = implemented` owner row; Phase B
can only revalidate that exact row and its predecessor-bound transition.

Phase B opaque values are service handles, not local checkpoints. After any
process/session restart, rerun the permanent root/clean-tree guard, freshly
derive exact `PW_COMMIT/PW_TREE`, then inspect the authenticated current
admission before assuming the old ref. If it is still exact admitted W0, call
`pin_payload_and_issue_lease(payload_oid: PW_COMMIT)` again: Bootstrap's
repository/predecessor/payload idempotency key must return the original
proposal receipt and original opaque lease/evaluation, after which
`run_active_gates(lease: lease)` performs only query/resume and returns the
byte-identical terminal bundle. If it is already an authenticated admitted W1
whose payload is exact `PW_COMMIT/PW_TREE` and whose seal/CAS/final attestation
all verify, adopt that byte-identical `admittedW1` and perform no repin or
finalize. Every other state raises
`AdmissionTerminalError(terminal = quarantinedAdmission,
reason_code = IDENTITY_MISMATCH)`. This never creates a new
lease, repeats a physical effect, or trusts a serialized candidate cache.

### Task 11: Enter the Exact Final W1 Payload Without Trusting the Candidate

**Files:**
- Read through protected service: `AdmittedWaveV1`, `PayloadProposalReceiptV1`, `EvaluationLease`
- Read outside Git as non-authoritative drift hint only: `/private/tmp/qinao-artifact-mesh-w1-task0/handoff-v1.json`
- Verify only: final W1 payload tree

**Interfaces:**
- Consumes: separate user authorization, clean final W1 payload OID, bootstrap-owned `ProtectedAdmissionClient`, and finalized admitted W0.
- Produces: externally pinned proposal receipt plus signed `EvaluationLease` for the active predecessor gate. It does not accept a caller ref, wave, device, team, toolchain, archive, custody, producer, attester, or candidate-generated admission state.

- [ ] **Step 1: Require the permanent reparented-program root**

Run exactly:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage reparentedProgram \
  --require-clean
```

Expected: one canonical JSON line with exact keys `candidate_lineage,head_commit,head_tree,schema_version`; lineage is `reparentedProgram`, schema version is integer 1, and the two OID values byte-match fresh `git rev-parse HEAD` / `git rev-parse HEAD^{tree}` reads. Any mismatch exits 2. The current working directory must equal that exact root.

- [ ] **Step 2: Pin final `Pw`, issue the signed lease, and verify predecessor**

The protected runner freezes:

```bash
PW_COMMIT="$(git rev-parse HEAD)"
PW_TREE="$(git rev-parse HEAD^{tree})"
test "$(git rev-parse "$PW_COMMIT^{tree}")" = "$PW_TREE"
```

After a separate explicit user authorization makes that exact object set
available to the external service, call only:

```text
admittedW0 =
  ProtectedAdmissionClient.reopen_admitted_predecessor()
(proposalReceipt, lease) =
  ProtectedAdmissionClient.pin_payload_and_issue_lease(
    payload_oid: PW_COMMIT
  )
```

The protected runner verifies both service envelopes under active B0, then
requires the receipt/lease payload commit/tree equal `PW_COMMIT/PW_TREE`, the
service-owned immutable content-addressed proposal ref reopens those exact
objects from the host, the predecessor equals `admittedW0.seal_commit_oid`,
`git merge-base --is-ancestor admittedW0.seal_commit_oid PW_COMMIT` succeeds,
the service-derived wave is W1, and the complete B0-derived W1 gate set
contains exactly one `qinao.artifact-mesh-device-recovery` entry plus its
opaque `ExternalPhysicalGateBinding`. The lease must contain no caller
selector. For Step 3 only, the protected runner exports
`ADMITTED_W0_CHAIN_DIGEST` from the verified
`admittedW0.admission_chain_digest`; it accepts no caller or temporary-file
value.

Missing host objects or unavailable external pinning is exactly
`BLOCKED_PAYLOAD_OBJECT_AVAILABILITY`; absent/incomplete service bindings are
`BLOCKED_EXTERNAL_BOOTSTRAP`. A candidate-local ref, payload JSON, cached
lease, unsigned `/private/tmp` object, or caller wave cannot substitute.

- [ ] **Step 3: Verify Phase-A bytes survived exactly**

Run:

```bash
python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess

def canonical_json_bytes(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode() + b"\n"

handoff_path = pathlib.Path(
    "/private/tmp/qinao-artifact-mesh-w1-task0/handoff-v1.json"
)
handoff_bytes = handoff_path.read_bytes()
handoff = json.loads(handoff_bytes)
if handoff_bytes != canonical_json_bytes(handoff):
    raise SystemExit("Task-0 handoff is not canonical JSON plus one LF")
expected_handoff_keys = {
    "schema_version",
    "admitted_w0_chain_digest",
    "pretransition_task0_commit_oid",
    "pretransition_task0_tree_oid",
    "status_transition_commit_oid",
    "task0_code_tree_oid",
    "ea_manifest_blob_sha256",
    "unit_preflight_receipt_sha256",
    "device_preflight_disposition",
    "migration_disposition",
    "historical_create_evidence_set_digest",
    "artifact_mesh_owner_row_sha256",
    "artifact_mesh_status_transition_sha256",
    "status_transition_from",
    "status_transition_to",
}
if not isinstance(handoff, dict) or set(handoff) != expected_handoff_keys:
    raise SystemExit("Task-0 handoff field set drift")
if (
    type(handoff["schema_version"]) is not int
    or handoff["schema_version"] != 1
):
    raise SystemExit("Task-0 handoff schema drift")
if handoff["device_preflight_disposition"] != "exercisable":
    raise SystemExit("blocked Task-0 handoff is forbidden")
if (
    handoff["migration_disposition"]
    != "anchorlessV1QuarantineRollForwardOnly"
):
    raise SystemExit("Task-0 migration disposition drift")
if (
    handoff["status_transition_from"],
    handoff["status_transition_to"],
) != ("converging", "implemented"):
    raise SystemExit("Task-0 status tuple drift")
admitted_w0_chain_digest = os.environ.get("ADMITTED_W0_CHAIN_DIGEST", "")
if (
    len(admitted_w0_chain_digest) != 64
    or any(c not in "0123456789abcdef" for c in admitted_w0_chain_digest)
    or admitted_w0_chain_digest != handoff["admitted_w0_chain_digest"]
):
    raise SystemExit("Task-0 admitted-W0 chain binding drift")
phase_a_tree = handoff["task0_code_tree_oid"]
pretransition_commit = handoff["pretransition_task0_commit_oid"]
pretransition_tree = handoff["pretransition_task0_tree_oid"]
transition_commit = handoff["status_transition_commit_oid"]
final_tree = subprocess.check_output(
    ["git", "rev-parse", "HEAD^{tree}"], text=True
).strip()

if subprocess.check_output(
    ["git", "rev-parse", f"{transition_commit}^{{tree}}"], text=True
).strip() != phase_a_tree:
    raise SystemExit("status-transition commit/tree mismatch")
parents = subprocess.check_output(
    ["git", "show", "-s", "--format=%P", transition_commit], text=True
).strip().split()
if len(parents) != 1 or parents[0] != pretransition_commit:
    raise SystemExit("status-transition commit must have one parent")
if subprocess.check_output(
    ["git", "rev-parse", f"{pretransition_commit}^{{tree}}"], text=True
).strip() != pretransition_tree:
    raise SystemExit("status-transition preimage tree mismatch")
changed = subprocess.check_output([
    "git", "diff-tree", "--no-commit-id", "--name-only", "-r",
    transition_commit,
], text=True).splitlines()
ledger_path = "docs/superpowers/specs/qinao-owner-ledger-v1.json"
if changed != [ledger_path]:
    raise SystemExit(f"status-transition path drift: {changed}")
if subprocess.run(
    ["git", "merge-base", "--is-ancestor", transition_commit, "HEAD"]
).returncode != 0:
    raise SystemExit("status-transition commit is not final-Pw ancestry")

def ledger_at(tree):
    return json.loads(subprocess.check_output(
        ["git", "show", f"{tree}:{ledger_path}"], text=True
    ))

def artifact_row(document):
    rows = [
        row for row in document["owners"]
        if row.get("owner_id") == "artifact.mesh"
    ]
    if len(rows) != 1:
        raise SystemExit("artifact.mesh owner row must be unique")
    return rows[0]

canonical = lambda value: json.dumps(
    value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
).encode()
pre_row = artifact_row(ledger_at(pretransition_tree))
post_row = artifact_row(ledger_at(phase_a_tree))
final_row = artifact_row(ledger_at(final_tree))
if pre_row.get("status") != handoff["status_transition_from"]:
    raise SystemExit("artifact.mesh status preimage drift")
if post_row.get("status") != handoff["status_transition_to"]:
    raise SystemExit("artifact.mesh status postimage drift")
if post_row != final_row:
    raise SystemExit("artifact.mesh owner row changed after Task 10")
pre_sha = hashlib.sha256(canonical(pre_row)).hexdigest()
post_sha = hashlib.sha256(canonical(post_row)).hexdigest()
if post_sha != handoff["artifact_mesh_owner_row_sha256"]:
    raise SystemExit("artifact.mesh owner-row digest drift")
transition_material = (
    b"qinao-artifact-mesh-owner-status-transition-v1\0"
    + pre_sha.encode() + b"\0"
    + post_sha.encode() + b"\0"
    + pretransition_commit.encode() + b"\0"
    + transition_commit.encode() + b"\0"
    + pretransition_tree.encode() + b"\0"
    + phase_a_tree.encode() + b"\0"
)
if (
    hashlib.sha256(transition_material).hexdigest()
    != handoff["artifact_mesh_status_transition_sha256"]
):
    raise SystemExit("artifact.mesh status-transition digest drift")

unit_path = pathlib.Path(
    "/private/tmp/qinao-artifact-mesh-w1-task0/"
    "unit-preflight-receipt-v1.json"
)
unit_bytes = unit_path.read_bytes()
if (
    hashlib.sha256(unit_bytes).hexdigest()
    != handoff["unit_preflight_receipt_sha256"]
):
    raise SystemExit("Task-0 unit-receipt digest drift")
unit = json.loads(unit_bytes)
if unit_bytes != canonical_json_bytes(unit):
    raise SystemExit("Task-0 unit receipt is not canonical JSON plus one LF")
if not isinstance(unit, dict) or set(unit) != {
    "schema_version",
    "payload_commit_oid",
    "payload_tree_oid",
    "swift_suites",
    "python_module",
    "python_discovered",
    "python_failures",
    "ea_slice_count",
    "matrix_row_count",
}:
    raise SystemExit("Task-0 unit-receipt field set drift")
if (
    type(unit["schema_version"]) is not int
    or unit["schema_version"] != 1
    or unit["payload_commit_oid"] != transition_commit
    or unit["payload_tree_oid"] != phase_a_tree
    or unit["python_module"]
       != "scripts.test_check_artifact_mesh_device_recovery"
    or type(unit["python_discovered"]) is not int
    or unit["python_discovered"] < 1
    or type(unit["python_failures"]) is not int
    or unit["python_failures"] != 0
    or type(unit["ea_slice_count"]) is not int
    or unit["ea_slice_count"] != 4
    or type(unit["matrix_row_count"]) is not int
    or unit["matrix_row_count"] != 40
):
    raise SystemExit("Task-0 unit-receipt scalar drift")
expected_suites = (
    "BASArtifactStoreTests",
    "BASArtifactMeshKeychainAnchorTests",
    "QinaoArtifactMeshAssemblyTests",
    "QinaoSovereignHostAssemblyTests",
    "QinaoEffectFacadeFreezeTests",
)
suite_rows = unit["swift_suites"]
if (
    not isinstance(suite_rows, list)
    or any(not isinstance(row, dict) for row in suite_rows)
    or tuple(row.get("suite") for row in suite_rows) != expected_suites
):
    raise SystemExit("Task-0 unit-receipt suite order drift")
for row in suite_rows:
    if set(row) != {"suite", "discovered", "executed", "failures"}:
        raise SystemExit("Task-0 suite-receipt field drift")
    if (
        type(row["discovered"]) is not int
        or type(row["executed"]) is not int
        or row["discovered"] < 1
        or row["executed"] != row["discovered"]
        or type(row["failures"]) is not int
        or row["failures"] != 0
    ):
        raise SystemExit("Task-0 suite-receipt count drift")

historical_paths = (
    "docs/superpowers/evidence/qinao-owner-corrections/"
    "artifact-mesh-retrospective-create-correction-v1.json",
    "docs/superpowers/evidence/qinao-owner-create/"
    "artifact-mesh--core.json",
    "docs/superpowers/evidence/qinao-owner-create/"
    "artifact-mesh--schema.json",
    "docs/superpowers/evidence/qinao-owner-create/"
    "artifact-mesh--sqlite-store.json",
)
historical_material = bytearray(
    b"qinao-artifact-mesh-historical-create-evidence-set-v1\0"
)
for path in sorted(historical_paths, key=lambda value: value.encode()):
    phase_bytes = subprocess.check_output(
        ["git", "show", f"{phase_a_tree}:{path}"]
    )
    final_bytes = subprocess.check_output(
        ["git", "show", f"{final_tree}:{path}"]
    )
    if phase_bytes != final_bytes:
        raise SystemExit(f"historical Artifact evidence drift: {path}")
    historical_material.extend(path.encode())
    historical_material.extend(b"\0")
    historical_material.extend(hashlib.sha256(phase_bytes).hexdigest().encode())
    historical_material.extend(b"\0")
if (
    hashlib.sha256(historical_material).hexdigest()
    != handoff["historical_create_evidence_set_digest"]
):
    raise SystemExit("historical Artifact evidence-set digest drift")

paths = (
 "BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift",
 "BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql",
 "BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshAnchorPort.swift",
 "BehavioralAISubstrate/Sources/BASMemory/BASArtifactMeshKeychainAnchor.swift",
 "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
 "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift",
 "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshKeychainAnchorTests.swift",
 "QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift",
 "QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoSovereignHostAssembly.swift",
 "QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift",
 "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoArtifactMeshAssemblyTests.swift",
 "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoSovereignHostAssemblyTests.swift",
 "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift",
 "SampleHost/Package.swift",
 "SampleHost/ArtifactMeshDeviceLab/project.yml",
 "SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/project.pbxproj",
 "SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshDeviceLab.xcscheme",
 "SampleHost/ArtifactMeshDeviceLab/ArtifactMeshDeviceLab.xcodeproj/xcshareddata/xcschemes/ArtifactMeshCASContenderLab.xcscheme",
 "SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLabApp.swift",
 "SampleHost/ArtifactMeshDeviceLab/App/ArtifactMeshDeviceLab.entitlements",
 "SampleHost/ArtifactMeshDeviceLab/CASContender/ArtifactMeshCASContenderApp.swift",
 "SampleHost/ArtifactMeshDeviceLab/Protocol/ArtifactMeshRecoveryProtocol.swift",
 "SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshRecoveryProbe.swift",
 "SampleHost/ArtifactMeshDeviceLab/Probe/ArtifactMeshFaultBootstrap.swift",
 "docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json",
 "docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json",
 "scripts/run_artifact_mesh_device_recovery.py",
 "scripts/check_artifact_mesh_device_recovery.py",
 "scripts/test_check_artifact_mesh_device_recovery.py",
)
def entry(tree, path):
    raw = subprocess.check_output(
        ["git", "ls-tree", tree, "--", path], text=True
    ).strip()
    if not raw:
        raise SystemExit(f"missing Task-0 path: {path}")
    return raw.split("\t", 1)[0]
drift = [p for p in paths if entry(phase_a_tree, p) != entry(final_tree, p)]
if drift:
    raise SystemExit(
      "BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY "
      f"reason=TASK0_DRIFT paths={drift}")
manifest = subprocess.check_output([
    "git", "show",
    f"{final_tree}:docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json",
])
if hashlib.sha256(manifest).hexdigest() != handoff["ea_manifest_blob_sha256"]:
    raise SystemExit("Task-0 E/A manifest digest drift")
print(f"artifact-mesh-task0-drift: PASS paths={len(paths)}")
PY
```

Other W1 tasks may add unrelated bytes and may lawfully change their own
Ledger/catalog rows, but may not rewrite an Artifact Mesh Task-0 path or the
canonical `artifact.mesh` owner row. The 29-path mechanism comparison and
the separate row-level transition proof are both mandatory. Require the
exact historical evidence-set digest from Phase A when the active gate parses
the predecessor-bound prerequisites.

Expected: `artifact-mesh-task0-drift: PASS paths=29` after the row-level proof
also passes; otherwise use the
existing terminal `BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY` with
`reason=TASK0_DRIFT`. This plan adds no child-only blocked terminal.

---

### Task 12: Run the Predecessor-Derived Production Gate Over Final W1 `Pw`

**Files:**
- Verify only: final W1 `Pw`
- Consume through protected service: signed `EvaluationLease`, opaque `ExternalPhysicalGateBinding`, controller-side physical broker, encrypted custody capabilities
- Receive through protected service: `AuthenticatedGateResultBundle`

**Interfaces:**
- Consumes: final W1 `Pw`, service-envelope-verified proposal receipt/lease, active B0 `qinao.artifact-mesh-device-recovery` module, and bootstrap-selected external physical broker.
- Produces: bootstrap-owned `AuthenticatedGateResultBundle` bound to final W1 `Pw`, exact active gate/output contract, and externally reopened evidence. Candidate scripts are untrusted parity tools and produce no leaf.

- [ ] **Step 1: Run all unit suites from the final payload**

Run the five non-empty Swift suite commands from Task 10 Step 2 plus the
Python module and realized E/A command from Step 3, substituting final
`PW_COMMIT` and `PW_TREE`.

Expected: all tests non-empty/green; realized E/A manifest has exactly four W1 slices.

- [ ] **Step 2: Enter the protected production broker**

The protected runner rejects any `QINAO_*` environment key and any
device/team/toolchain/archive/profile/custody selector, verifies the proposal
receipt and lease again, then calls exactly:

```text
gateResults =
  ProtectedAdmissionClient.run_active_gates(lease: lease)
```

Inside that bootstrap-owned operation, the active B0 module derives production
reachability from the final payload and signed binding, opens the selected
shipping archive and two signed lab archives, and launches the controller with
only:

```text
--mode production
--lease-fd 3
--physical-broker-fd 4
--custody-fd 5
```

No Artifact plan code can construct `gateResults`, pass selectors to the
broker, or read the raw device identity/custody key.

- [ ] **Step 3: Require the brokered physical result**

Expected from `run_active_gates` only on full success:

```text
artifact-mesh-device-recovery: PASS mode=production rows=40 no_fault=26 faults=14 external_reopen=verified
```

If the real reboot-before-first-unlock row is unexercisable, stop with:

```text
BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY reason=PROTECTED_DATA_UNAVAILABLE
```

Do not substitute ordinary lock/unlock, a content-free feasibility status, or 39 rows.

- [ ] **Step 4: Require the active predecessor module, not candidate parity, to pass**

The active B0 `qinao.owner-ledger` module first derives W1 from the
authenticated admitted-W0 predecessor and final `PW_COMMIT/PW_TREE`. It
requires the predecessor's unique `artifact.mesh` owner row to be
`converging`, the final payload's unique row to byte-match the Task-10
canonical `implemented` postimage, the transition to be the sole allowed
mutation of that owner row, and Task 10's transition commit to be final-`Pw`
ancestry. Other W1 owner/catalog lifecycle deltas remain independently
validated. Candidate Ledger checkers and the temporary handoff cannot satisfy
this active gate.

The protected runner invokes B0 catalog gate `qinao.artifact-mesh-device-recovery` / module `artifact_mesh_device_recovery`, whose frozen primitives require:

```text
swiftpm_filter_nonempty:
  BASArtifactStoreTests
  BASArtifactMeshKeychainAnchorTests
  QinaoArtifactMeshAssemblyTests
  QinaoSovereignHostAssemblyTests
  QinaoEffectFacadeFreezeTests
canonical_json_exact_set:
  exact final-Pw-indexed 40-row matrix
physical_evidence_external_root:
  final-Pw/archive/device/challenge-bound reopened raw evidence
```

The broker may run `scripts/check_artifact_mesh_device_recovery.py` over the
read-only reopened encrypted capability before key destruction, but that
candidate result is parity/diagnostic only. The active module independently
parses the reopened raw events, requires exact two-process CAS evidence,
persistent-WAL/atomic-quarantine evidence, production reachability, external
put/reopen, key destruction, no-residue receipt, and the independently
derived operator-visible projection
`migration_disposition = anchorlessV1QuarantineRollForwardOnly`. Missing or
substituted disposition fails the frozen B0 corpus. Candidate parity and the
temporary handoff alone cannot create or supplement
`AuthenticatedGateResultBundle`.

If Task 12 is entered in a new process, first execute the Phase-B re-entry
contract. Its admitted-W0 branch recovers the original authenticated `lease`
and Step 2 resumes that existing evaluation; its already-admitted-W1 branch
skips the rest of Task 12. If Task 13 is entered in a new process, execute the
same oracle before finalization. Unknown effect state remains blocked for
Bootstrap reconciliation and is never replayed.

- [ ] **Step 5: Recheck clean tree and immutable final payload**

```bash
test -z "$(git status --porcelain=v1)"
test "$(git rev-parse HEAD)" = "$PW_COMMIT"
test "$(git rev-parse HEAD^{tree})" = "$PW_TREE"
```

Expected: no tracked/untracked mutation and exact final W1 payload unchanged.

---

### Task 13: Finalize Only Through the Bootstrap-Owned Protected Service

**Files:**
- Create in candidate/runner: nothing
- Receive through protected service: finalized `AdmittedWaveV1`
- Service-owned only: W1 `Cw`, W1 `Sw`, import receipts, intent, protected-ref CAS, final attestation

**Interfaces:**
- Consumes: signed `EvaluationLease` and service-envelope-verified `AuthenticatedGateResultBundle` returned by `ProtectedAdmissionClient.run_active_gates`.
- Produces: finalized `AdmittedWaveV1` through the single bootstrap-owned protected service operation. Artifact Mesh produces no candidate leaf and cannot reveal raw physical evidence.

- [ ] **Step 1: Verify the opaque authenticated result bundle**

On process/session re-entry, execute the Phase-B recovery oracle first. If
current admission is exact W0, obtain the service's original receipt/lease
through idempotent `pin_payload_and_issue_lease` and query/resume the original
evaluation through `run_active_gates`; only those byte-identical opaque values
may enter this task. If current admission is already exact W1 for
`PW_COMMIT/PW_TREE`, bind `admittedW1` to that authenticated byte-identical
result and skip Steps 1-2. Any other state raises
`AdmissionTerminalError(terminal = quarantinedAdmission,
reason_code = IDENTITY_MISMATCH)`.

The protected runner verifies the bundle's bootstrap service envelope and
requires its opaque commitments to bind the same lease/evaluation, final
`PW_COMMIT/PW_TREE`, active B0 gate set/output contract, exact five non-empty
Swift suites, four E/A slices, exact 40/26/14 matrix, two-process Keychain CAS,
selected shipping/lab archive observations, production reachability, external
put/reopen, the exact operator-visible
`anchorlessV1QuarantineRollForwardOnly` migration disposition, and custody
destruction/no-residue receipt. Raw device/team/serial,
paths, provisioning/CMS bytes, Keychain bytes, container bytes, boot identity,
challenges, traces, credentials, and custody keys remain outside Git and
outside the bundle.

`AuthenticatedGateResultBundle` is a Bootstrap opaque import. This plan does
not restate its field schema, allow candidate supplementation, or serialize a
lookalike JSON result.

- [ ] **Step 2: Ask the protected service to assemble, import, and finalize**

Execute this step only for the recovery oracle's admitted-W0 branch.

Call exactly:

```text
admittedW1 =
  ProtectedAdmissionClient.assemble_import_and_finalize(
    lease: lease,
    gate_results: gateResults
  )
```

The external service alone validates the exact output set, derives every Cw
leaf from the authenticated bundle and B0 output contracts, constructs
deterministic Cw/Sw bytes, imports and host-reopens every object, signs the
`ImportedCommit` receipts, persists the object-import receipt, creates the
immutable intent, performs protected-ref CAS, and finalizes the service
attestation. Candidate code, the controller, Artifact Mesh, the protected
runner, and any W1 evidence builder supply no leaf, path, blob, tree, commit
metadata, OID, ref, receipt child, intent, or CAS value.

- [ ] **Step 3: Reopen final admission or stop at the exact block**

Require `admittedW1` to verify under the active B0 service binding, derive W1,
name the exact prior admitted-W0 seal, and carry a final seal whose admitted
topology binds the same immutable `Pw` and authenticated bundle. Reopen it
again through `ProtectedAdmissionClient.reopen_admitted_predecessor()` before
the next wave; the two authenticated results must be byte-identical.
Only this finalized admission makes the already-indexed
`artifact.mesh = implemented` proposal authoritative. The service does not
rewrite `Pw`, the Ledger, or the owner row while assembling `Cw/Sw` or
finalizing the seal.

No authenticated passing bundle or admission is emitted on failure. The exact
`BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY` reason map is: missing row →
`MATRIX_ROW_MISSING`; wrong timing/terminal → `TIMING_OR_TERMINAL_MISMATCH`;
fixture substitution → `FIXTURE_SUBSTITUTION`; raw reopen failure →
`RAW_REOPEN_FAILED`; shipping reachability violation →
`SHIPPING_REACHABILITY_VIOLATION`; candidate-module-only pass →
`CANDIDATE_MODULE_ONLY_PROOF`; custody cleanup failure →
`CUSTODY_CLEANUP_UNVERIFIED`; protected-data unexercisability →
`PROTECTED_DATA_UNAVAILABLE`. Missing service capability is
`BLOCKED_EXTERNAL_BOOTSTRAP` with its matching closed registry reason; missing
pinned payload objects is `BLOCKED_PAYLOAD_OBJECT_AVAILABILITY` with
`PAYLOAD_OBJECT_NOT_HOST_REOPENED`.

---

## End-to-End Command Summary

Phase A, after each implementation commit:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_artifact_mesh_device_recovery
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactStoreTests \
  --require-suite BASArtifactStoreTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path BehavioralAISubstrate \
  --filter BASArtifactMeshKeychainAnchorTests \
  --require-suite BASArtifactMeshKeychainAnchorTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoArtifactMeshAssemblyTests \
  --require-suite QinaoArtifactMeshAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoSovereignHostAssemblyTests \
  --require-suite QinaoSovereignHostAssemblyTests
python3 scripts/run_nonempty_swift_filter.py \
  --package-path QinaoRuntimeSDK \
  --filter QinaoEffectFacadeFreezeTests \
  --require-suite QinaoEffectFacadeFreezeTests
python3 scripts/check_qinao_ea_extensions.py \
  --root . \
  --manifest docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json \
  --payload-commit "$(git rev-parse HEAD)" \
  --payload-tree "$(git rev-parse HEAD^{tree})"
git diff --check
```

Task 10 runs the candidate physical preflight once before the one-file status
proposal and then reruns this complete command set plus the physical preflight
over the post-transition tree. Only the second full pass produces the unit
receipt and handoff.

Phase B repeats those commands over final W1 `Pw`, then obtains the signed
proposal receipt/lease, calls the protected broker for production reachability,
all 40 physical rows and byte-identical external reopen, and gives the returned
authenticated bundle only to
`ProtectedAdmissionClient.assemble_import_and_finalize`.

## Plan Self-Review

- [x] **Scope:** Only Artifact Mesh W1 Task 0 and its necessary callers/tests/lab/gates are covered; no other W1 domain task is implemented.
- [x] **M honesty:** The three historical M paths are repaired in place; the M manifest/evidence set is neither expanded nor relabeled.
- [x] **E/A exactness:** The manifest has exactly four singular W1 slices, incumbent owner `artifact.mesh`, correct E/A classes, exact paths/symbols, and no caller wave.
- [x] **Boundary:** Anchor record/port is internal owner-private state; Keychain adapter is sole shipping writer; Qinao assembly is mechanism-only; host has one store instance.
- [x] **Durability:** Genesis, reopen, FULL, per-connection persistent WAL/SHM, pending/commit/promotion, roots/floors, digest reopen, K3 ordering, cross-process primary-key CAS, atomic directory quarantine, crash cuts, lease, and recovery terminals are explicit.
- [x] **Physical proof:** The lab has two real signed app products/shared schemes for a true two-process CAS race; protocol is closed; normal/fault entry paths are separate; crash victims and fault bootstrap are force-killed and identity-proven.
- [x] **Matrix:** 13 operations × two cuts = 26 no-fault rows plus exactly 14 named/timed fault rows = 40.
- [x] **Protected data:** Reboot-before-first-unlock remains a real row and blocks production when unexercisable.
- [x] **Shipping exclusion:** Whole lab directory is excluded from SampleHost SwiftPM; source graph and selected archive must both prove no product/condition/probe/hook shipping reachability.
- [x] **Two phases:** A fully passing Phase A alone proposes the one-field
  `artifact.mesh` owner-row transition, reruns all gates over its postimage,
  and emits a non-authoritative handoff; Phase B rebinds physical proof to
  final W1 `Pw`, permits no post-`Pw` Ledger mutation, and makes the proposal
  authoritative only through admission.
- [x] **Admission discipline:** Candidate scripts emit no leaf; the bootstrap-owned client alone returns `AuthenticatedGateResultBundle` and alone constructs/imports/reopens Cw/Sw, creates intent, performs CAS, and finalizes.
- [x] **Raw evidence:** Physical/raw/private bytes remain in broker-provided encrypted ephemeral custody, are byte-identically reopened, then undergo verified key destruction/no-residue cleanup with crash recovery.
- [x] **Recovery authority:** No recovery super-owner, second registry, signer, route, profile, policy, or fallback is created.
- [x] **Unspecified-work scan:** No implementation step delegates behavior to an unspecified future task; all external authority uses the exact Bootstrap-owned `ProtectedAdmissionClient` surface and opaque signed imports.
- [x] **Type consistency:** Anchor, Qinao factory, operation/fault/timing/terminal, matrix, controller, handoff, and gate-result names are consistent across tasks.
