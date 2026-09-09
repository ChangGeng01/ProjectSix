# iPhone Air Contracts and LayerCell Reuse-First Implementation Plan

> **Forward development status (2026-08-29):** Superseded by [Qinao single-developer Git and lightweight PR design](../specs/2026-08-29-qinao-single-developer-git-and-lightweight-pr-design.md). External authority closure was never completed, and no historical authority is retroactively claimed. The single developer selected ordinary Git plus lightweight PR review; former source-admission, controlled-document, signer/trust-root, controller/CAS, authority-receipt, registry, and quorum gates are retired for forward development. Historical facts and hashes remain evidence; a historical non-authority limitation remains a forward gate only when the superseding design explicitly restates it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the shared architecture IDs, keyed Artifact Mesh, attenuated capability semantics, and LayerCell membranes without creating a second layer, budget, kill, capability, actor, envelope, or receipt authority.

**Architecture:** This plan applies Section 4.4 of the controlled current design at `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`, reconciled with the `659e46576` audit snapshot and the machine OwnerLedger. Existing owners are modified in place; adapters translate only at real module boundaries. The only new production owner is the allowlisted keyed Artifact Mesh, while LayerCell remains a membrane over the existing `BASLayerActor`/mesh path and capability consumption remains inside `BASSovereignTokenAuthority`.

**Tech Stack:** Swift 6, Foundation, swift-crypto, SQLite3, SwiftPM, XCTest, XcodeGen, existing canonical-byte and schema-generation infrastructure.

## Global Constraints

- Section 4.4 of the controlled current design is authoritative: exact-name absence never proves a missing owner. Historical design commits are provenance, not an alternate policy source.
- Classify every task as R (reuse), E (extend), A (adapter only), or M (missing). Incomplete production-Create proof defaults to E/A.
- Task 0's iOS-27 floor gate and Task 0A's machine `OwnerLedger`/`CreateGate` are hard prerequisites for every later production edit. A production `Create` is forbidden until the gate proves one semantic responsibility, one authority symbol, one mutable-state/storage owner tuple, one exact allowlisted path, and one complete eight-part Create Proof. Tests, fixtures, schemas, migrations, and scripts are non-authoritative and cannot be used to manufacture an `M` classification.
- `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json` is the sole machine-readable ownership inventory and `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py` is the sole OwnerLedger/CreateGate verifier for this plan. The ledger records semantic responsibility rather than filename spelling; aliases, adapters, compatibility projections, and generated schemas point back to an existing ledger entry and never receive their own authority row.
- `BASSemanticLayerID` is a typealias/projection of `BASCognitiveLayer`; it is never another 14-case enum.
- K1–K4 extend `BASMotherboardKernel`; legacy raw values and Codable bytes remain unchanged.
- New result, frame, permit, bundle, and card shapes reuse `BASResult`, `BASFrameEnvelope`, `BASPermit`, `BASBundle`, and `BASCard` from `BASLowEntropyPrimitives.swift`/`BASBundle.swift`.
- Use `BASSovereignCanonicalBytes.lengthPrefixed`; never hash/sign JSON, dictionary iteration, set iteration, or delimiter-joined fields.
- A domain payload never contains its own `BASArtifactID`, digest, storage locator, or signature. Only an ordinary child attestation payload may contain proof bytes.
- Every self-ID-free value independently ordinary-put through Artifact Mesh conforms to `BASSchemaVersioned`, visibly carries `schemaVersion`, defaults new construction to `currentSchemaVersion`, is encoded/reopened only through the one `BASGovernedArtifactPayloadCodec`, and has exactly one `BASEBrainSchemaGovernanceRegistry` entry. Existing bare-`Codable` values are extended in place before their first ordinary put; embedding a value under one governed parent is the only alternative. Transient requests/ports, embedded entries/enums, SQL rows with one numbered migration, and return-only projections are not separately registered. Missing/unknown versions fail before reducer or mechanism work.
- Attestations use the same `BASArtifactStorePort.put` path and ordinary `BASArtifactStoreReceipt`; there is no `putAttestation`, attestation store, or second identity function.
- New cross-plan references use `BASArtifactID`; raw string references are allowed only in legacy-wire adapters.
- Semantic read versions live only in the canonical ordered `[BASLaneWatermark]` field of the referenced `BASStateReadSnapshot` Artifact Mesh payload. No other payload—including lane results, joins, audit/shadow observations, or replay manifests—may declare a watermark field/vector; those values carry only `semanticSnapshotArtifactID` plus their lane/source IDs and reopen the snapshot when version proof is required. Artifact Mesh records point at that snapshot with `snapshotRootArtifactID`; they never define `BASArtifactReadVersion` or copy lane watermarks into a second vector.
- `BASCapabilityGrant` is an unsigned canonical payload. Its Artifact Mesh envelope supplies identity and its child attestation supplies the signature.
- Capability-grant mint/issue/reserve/claim/spend stay in the existing `BASSovereignTokenAuthority`. `issueCapability` and `claimCapability` return ordinary `BASArtifactStoreReceipt` values; the latter points at the one stored `BASCapabilityUseReceipt` payload, so issuance and claim never invent a second receipt type. That K4 capability ceiling is distinct from semantic-budget consumption: only K3 `claimBudgetUse` may advance `BASBudgetLeasePayload` counters.
- LayerCell invokes only the existing `BASLayerActor` mechanism path. Its ingress and egress membranes are pure, deterministic value transformations; the one actor-mechanism call is the only await/mechanism crossing. It owns no actor registry, scheduler, retry truth, cache, persistence, ranking, budget deduction, kill advancement, effect, or authorization state.
- Collaboration ceilings extend `BASLayerSlice`; kill generations extend `BASLayerKillSwitchState`. `BASLayerSlice` may attenuate and display a ceiling but cannot spend it. One self-ID-free `BASBudgetLeasePayload` is installed with the turn root, and only the same K3 writer behind `BASBudgetLeaseControlPort` may claim cumulative use and emit `BASBudgetUseReceipt`; no `BASLayerBudget`, budget actor/store/map, `RSIManager`, or `BASKillEpoch` owner is introduced.
- Swift actors, `AsyncStream`, `ContinuousClock`/existing monotonic time, Crypto, SQLite transactions/WAL, and existing secure-delete/file-protection helpers remain the mechanism owners.
- Preserve existing public initializers and Codable raw values with additive defaults and explicit decode defaults.

## W0–W6 Delivery Placement

- **W0 — owner/write freeze:** execute Task 0 and Task 0A; the iOS-27 floor and shared OwnerLedger/CreateGate must pass before any production edit.
- **W1 — contracts / TurnOperation / Provider inversion:** execute Tasks 1–5 for this plan's contract, Artifact Mesh, capability, and pure LayerCell subset. Task 2A owns only the canonical TurnOperation/branch/observation/boundary value contracts and extends the existing turn owner; concrete Provider package inversion stays in the sibling Silicon W1 plan and is never re-owned here.
- **W2 — K3 + memory + erasure**, **W3 — StateLake + context**, **W4 — silicon**, **W5 — K4 / release / Zone C**, and **W6 — runtime / certification** contain no implementation step from this file; downstream plans consume the W0/W1 gates in that exact order.

`R0`–`R6` are reserved exclusively for retrieval subwaves. This contracts plan never uses an `R` label as a delivery-wave alias or for owner, release, runtime, or certification sequencing.

---

### Task 0: Lock the Owned iOS 27 Deployment Floor

**Reuse Decision**

- **Class:** E; the manifests and XcodeGen project are the existing deployment owners.
- **Existing unique owner:** `BehavioralAISubstrate/Package.swift`, `SampleHost/Package.swift`, `QinaoRuntimeSDK/Package.swift`, and `BehavioralAISubstrate/DeviceTestApp/project.yml`.
- **Missing invariant:** all owned build surfaces must agree on iOS `27.0` and reject a release-selectable in-process K4 fallback.
- **Why Create is allowed:** only a verification script is new; it owns no runtime state or platform policy.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/SampleHost/Package.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/Package.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/project.yml`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/check-ios27-floor.sh`

**Interfaces:**
- Consumes: owned SwiftPM platform declarations and XcodeGen deployment settings.
- Produces: an executable check returning zero only when every owned iOS floor is at least `27.0`.

- [ ] **Step 1: Write the failing deployment-floor check**

Create an executable shell script that runs these exact searches and exits nonzero for any stale owner:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-/Users/changgeng/Project/Project06/Project06}"

for manifest in BehavioralAISubstrate/Package.swift SampleHost/Package.swift QinaoRuntimeSDK/Package.swift; do
  rg -q '\.iOS\("27\.0"\)' "$ROOT/$manifest" || {
    echo "FAIL: $manifest does not declare .iOS(\"27.0\")" >&2
    exit 1
  }
done

rg -q 'iOS: "27\.0"' "$ROOT/BehavioralAISubstrate/DeviceTestApp/project.yml"
rg -q 'IPHONEOS_DEPLOYMENT_TARGET: "27\.0"' "$ROOT/BehavioralAISubstrate/DeviceTestApp/project.yml"

if rg 'IPHONEOS_DEPLOYMENT_TARGET = (1[0-9]|2[0-6])\.' \
  "$ROOT/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj"; then
  echo 'FAIL: generated project contains a pre-iOS-27 deployment target' >&2
  exit 1
fi

if rg -n 'release.*(inProcessK4|legacyK4)|(inProcessK4|legacyK4).*release' \
  "$ROOT/BehavioralAISubstrate" "$ROOT/SampleHost" "$ROOT/QinaoRuntimeSDK" \
  --glob '*.swift'; then
  echo 'FAIL: release-selectable in-process K4 fallback found' >&2
  exit 1
fi
```

Run:

```bash
bash /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/check-ios27-floor.sh
```

Expected: FAIL naming the current iOS 18 manifests/settings.

- [ ] **Step 2: Raise only the owned deployment declarations**

Replace each owned `.iOS(.v18)` with `.iOS("27.0")`, update the SampleHost iOS-18 comment, set both XcodeGen values to `27.0`, and regenerate:

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp
xcodegen generate
```

Expected: `project.pbxproj` is regenerated with no pre-27 iOS target.

- [ ] **Step 3: Verify the floor and focused baseline**

```bash
bash /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/check-ios27-floor.sh
swift package --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate dump-package >/dev/null
swift package --package-path /Users/changgeng/Project/Project06/Project06/SampleHost dump-package >/dev/null
swift package --package-path /Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK dump-package >/dev/null
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASNamingMatrixTests|BASSovereignTokenAuthorityTests'
```

Expected: all commands PASS.

- [ ] **Step 4: Commit**

```bash
git add BehavioralAISubstrate/Package.swift SampleHost/Package.swift QinaoRuntimeSDK/Package.swift \
  BehavioralAISubstrate/DeviceTestApp/project.yml \
  BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj \
  BehavioralAISubstrate/scripts/check-ios27-floor.sh
git commit -m "build: require ios 27"
```

### Task 0A: Verify and Extend the Machine OwnerLedger and CreateGate

This planning revision already installs the audit/build assets; implementation must verify and extend them before Tasks 1–5 and creates no runtime owner.

**Reuse Decision**

- **Class:** A; the master plan's R/E/A/M and eight-part Create Proof rules remain the policy owner.
- **Existing unique owner:** the current source symbols named below remain their respective runtime authorities; this task merely makes that inventory executable.
- **Existing audit owner:** `qinao-owner-ledger-v1.json` is the only machine-readable inventory and `scripts/check_qinao_owner_ledger.py` is its only verifier/CreateGate.
- **Missing implementation invariant:** every candidate tree must keep the installed ledger/checker/tests green and submit one exact candidate manifest per approved production `M` path.
- **Why extension is allowed:** the JSON ledger, Python verifier, and verifier tests are build/audit artifacts with no production target membership, mutable runtime state, storage API, or runtime decision surface.

**Files:**
- Modify/verify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify/verify: `/Users/changgeng/Project/Project06/Project06/scripts/check_qinao_owner_ledger.py`
- Modify/verify: `/Users/changgeng/Project/Project06/Project06/scripts/test_check_qinao_owner_ledger.py`

**Interfaces:**
- Consumes: Task 0's passing iOS-27 gate, the approved design path, current source paths/symbols, and each task's R/E/A/M/Create-Proof declaration.
- Produces: `python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json" [--candidate-manifest <path>]...`, where the option is repeatable and exits zero only when the canonical ledger passes and every proposed production Create is an approved, exact-path, non-duplicate `M` with all eight proof fields.

- [ ] **Step 1: Run the installed verifier suite RED against every planned schema extension**

Pin the installed snake-case schema; do not introduce a camel-case alternate ledger:

```json
{
  "schema_version": 1,
  "ledger_id": "qinao-owner-ledger-v1",
  "minimum_ios": "27.0",
  "architecture_spec": "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md",
  "architecture": {
    "semantic_layers": ["L1", "L2", "...", "L14"],
    "physical_kernels": ["K1", "K2", "K3", "K4"],
    "control_rings": ["omega_resource", "omega_grounding", "omega_deliberation", "omega_effect_evolution"],
    "planes": ["semantic_authority", "kernel_ownership", "execution_dag", "control_ring", "data", "adapter_io", "observe_replay"]
  },
  "implementation_work_packages": [{"id": "W0", "name": "baseline_owner_ledger_and_write_freeze", "exit_gate": "..."}],
  "retrieval_waves": [{"id": "R0", "name": "compiled_pre_physical_eligibility"}],
  "controlled_documents": [{"path": "...", "required_terms": ["..."]}],
  "create_allowlist": ["artifact.mesh"],
  "create_permissions": [
    {
      "owner_id": "artifact.mesh",
      "authority_symbol": "BASArtifactStorePort",
      "create_proof_task": "contracts-layercell:Task 2",
      "allowed_paths": [
        "BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift",
        "BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift"
      ]
    }
  ],
  "owners": [
    {
      "owner_id": "identity.semantic-layers",
      "domain": "L1-L14 stable semantic identity",
      "classification": "E",
      "work_package": "W1",
      "authority_owner": "BASCognitiveLayer",
      "mutable_state_owner": "none",
      "storage_owner": "BASCognitiveLayer Codable raw values",
      "recovery_owner": "legacy wire adapters into BASCognitiveLayer",
      "single_writer_required": false,
      "status": "converging",
      "evidence_paths": ["BehavioralAISubstrate/Sources/BASRuntimeCore/BASObservationReconciliationCore.swift"],
      "allowed_projections": [],
      "current_conflicts": [],
      "forbidden": ["second fourteen-case semantic enum"],
      "retirement_gate": "all production identities use BASCognitiveLayer"
    }
  ]
}
```

The actual file contains the complete arrays and OwnerCards; ellipses above are explanatory only and are forbidden in the real ledger. Keep the installed granular rows for Artifact Mesh, K3, memory/erasure, snapshot contracts/planner/coordinator/market, process memory, StateABI, spool/publication, K4, trust, Zone C, TurnOperation, semantic executor/DAG, replay manifest, certification, Provider boundary, iOS 27, and cutover. `create_allowlist` and `create_permissions` must equal the set of `classification == "M"` owners exactly; every production path is normalized, workspace-relative, globally unique, and UTF-8 sorted within its permission.

- [ ] **Step 2: Write the failing machine CreateGate**

`scripts/check_qinao_owner_ledger.py` bounded-decodes the ledger and every optional candidate manifest with duplicate-key rejection and enforces all of the following. Task 0's separate floor scanner runs immediately before it; the two tools remain separate so neither becomes a second policy source:

1. `schema_version == 1`, `ledger_id == "qinao-owner-ledger-v1"`, `minimum_ios == "27.0"`, the design path and seven controlled documents are exact, and duplicate JSON keys or placeholders reject.
2. The exact ordered identities are L1–L14, K1–K4, four named ControlRings, and seven named orthogonal planes. Work packages are the master plan's exact W0–W6 meanings; retrieval waves are the exact R0–R6 meanings and cannot trade namespaces.
3. Every OwnerCard has non-empty authority/mutable/storage/recovery/evidence/retirement fields, explicit `single_writer_required`, declared R/E/A/M, W package, status, non-empty forbidden rules, valid conflict disposition, and only non-authoritative/non-mutable/rebuildable projections.
4. `create_allowlist` and `create_permissions` cover exactly all `M` owners. Each permission has one authority symbol, one Create-Proof task, and one or more globally unique normalized exact paths.
5. A candidate manifest has the exact shape below. It passes only when its owner is already `M`, path/symbol/task exactly equal the installed permission, and all eight proof fields are non-empty and placeholder-free. Any `R/E/A` incumbent proposed as `M` reports that incumbent authority and fails.
6. Neither ledger nor gate is included in a production target or allowed to emit Swift/SQL/runtime configuration.

```json
{
  "schema_version": 1,
  "owner_id": "artifact.mesh",
  "classification": "M",
  "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
  "authority_symbol": "BASArtifactStorePort",
  "create_proof_task": "contracts-layercell:Task 2",
  "create_proof": {
    "repository_search": "exact bounded search evidence",
    "public_primitive": "system/upstream mechanism assessment",
    "missing_invariant": "one precise absent invariant",
    "extension_insufficient": "why R/E/A/composition cannot close it",
    "single_owner": "authority/state/storage/failure boundary",
    "dependency_direction": "inward dependency and no-second-truth proof",
    "compatibility_retirement": "bounded migration and retirement gate",
    "verification": "mutation/crash/replay/duplicate-authority tests"
  }
}
```

Run:

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
cd "$ROOT"
python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
```

Expected: the canonical-ledger invocation and verifier suite pass; the suite proves an allowlisted exact candidate passes while duplicate identities, missing owners, stale allowlist rows, wrong paths, incomplete proof, and `R/E/A → M` escalation fail.

- [ ] **Step 3: Make every production Create consume the gate**

Before the RED step of Tasks 1–5, run the base gate. For Task 2, run it once per candidate manifest for all three exact workspace-relative production paths: `BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`, `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`, and `BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`. Each manifest names owner `artifact.mesh`, classification `M`, authority symbol `BASArtifactStorePort`, task `contracts-layercell:Task 2`, the exact candidate path, and all eight proof fields; no manifest may abbreviate the path to package-relative `Sources/...`. Tests are non-production and need no `M` candidate. Tasks 1, 3, and 4 are E/A and submit no production-`M` candidate. A later domain plan may extend one granular OwnerCard/permission only in the same reviewed change as its Create Proof; the gate fails stale permissions, bundled responsibilities, duplicate paths, or symbol/task/path drift.

- [ ] **Step 4: Commit the prerequisite gate**

```bash
git add docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py
git commit -m "test: gate production owner creation"
```

### Task 1: Extend Canonical Architecture Identity Owners

**Reuse Decision**

- **Class:** E.
- **Existing unique owner:** `BASCognitiveLayer` in `BASObservationReconciliationCore.swift`; `BASMotherboardKernel`/`BASMotherboardPlane` in `BASMotherboardArchitecture.swift`; compatibility views in `BASMotherboardLayerMapping.swift` and `BASNamingMatrix.swift`.
- **Missing invariant:** stable K1–K4 projection, four control-ring IDs, seven top-level views, and explicit three-plane compatibility mapping.
- **Why Create is allowed:** no production file is created; only a focused test file is new.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASObservationReconciliationCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardArchitecture.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASNamingMatrix.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardLayerMapping.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticArchitectureIDTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNamingMatrixTests.swift`

**Interfaces:**
- Consumes: `BASCognitiveLayer`, `BASMotherboardKernel`, `BASMotherboardPlane`, `BASMotherboardLayer14`.
- Produces: `typealias BASSemanticLayerID`, `typealias BASPhysicalKernelID`, `BASMotherboardKernel.architectureID`, `BASControlRingID`, `BASTopLevelPlaneID`, and total legacy projections.

- [ ] **Step 1: Write alias, projection, and cardinality tests**

```swift
import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASSemanticArchitectureIDTests: XCTestCase {
    func testSemanticLayerIDIsTheExistingType() {
        let semantic: BASSemanticLayerID = .dreamLoop
        let existing: BASCognitiveLayer = semantic
        XCTAssertEqual(existing.rawValue, "L9")
        XCTAssertEqual(BASSemanticLayerID.allCases.count, 14)
    }

    func testPhysicalKernelIDIsAProjectionOnMotherboardKernel() {
        let kernel: BASPhysicalKernelID = .leaseAndLife
        XCTAssertEqual(kernel.architectureID, "K1")
        XCTAssertEqual(BASMotherboardKernel.neuralOrganRuntime.architectureID, "K2")
        XCTAssertEqual(BASMotherboardKernel.stateAndEvolutionGraph.architectureID, "K3")
        XCTAssertEqual(BASMotherboardKernel.sovereignMicrokernel.architectureID, "K4")
        XCTAssertEqual(BASMotherboardKernel.allCases.count, 4)
    }

    func testMissingTaxonomiesAndLegacyPlaneProjectionAreTotal() {
        XCTAssertEqual(BASControlRingID.allCases.count, 4)
        XCTAssertEqual(BASTopLevelPlaneID.allCases.count, 7)
        let projected = Set(BASMotherboardPlane.allCases.flatMap(\.topLevelViewIDs))
        XCTAssertEqual(projected, Set(BASTopLevelPlaneID.allCases))
    }

    func testL9AliasesResolveToExistingDreamLoopCase() {
        for alias in ["L9", "Kunlun", "Dream"] {
            XCTAssertEqual(BASNamingMatrix.layerID(resolving: alias), .dreamLoop)
        }
    }
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticArchitectureIDTests|BASNamingMatrixTests'
```

Expected: compile failures for the aliases/projections and missing ring/view enums.

- [ ] **Step 3: Extend the existing owners in place**

Add these declarations to their existing owner files; do not add `BASSemanticArchitectureIDs.swift`:

```swift
// BASObservationReconciliationCore.swift
public typealias BASSemanticLayerID = BASCognitiveLayer

// BASMotherboardArchitecture.swift
public typealias BASPhysicalKernelID = BASMotherboardKernel

public extension BASMotherboardKernel {
    var architectureID: String {
        switch self {
        case .leaseAndLife: return "K1"
        case .neuralOrganRuntime: return "K2"
        case .stateAndEvolutionGraph: return "K3"
        case .sovereignMicrokernel: return "K4"
        }
    }
}

public enum BASControlRingID: String, Codable, Sendable, Hashable, CaseIterable {
    case resource = "ΩR"
    case grounding = "ΩG"
    case deliberation = "ΩD"
    case effectEvolution = "ΩE"
}

public enum BASTopLevelPlaneID: String, Codable, Sendable, Hashable, CaseIterable {
    case semanticAuthority = "semantic-authority"
    case kernelOwnership = "kernel-ownership"
    case executionDAG = "execution-dag"
    case controlRing = "control-ring"
    case data = "data"
    case adapterIO = "adapter-io"
    case observeReplay = "observe-replay"
}

public extension BASMotherboardPlane {
    var topLevelViewIDs: [BASTopLevelPlaneID] {
        switch self {
        case .sovereign: return [.semanticAuthority, .controlRing, .observeReplay]
        case .state: return [.data]
        case .compute: return [.kernelOwnership, .executionDAG, .adapterIO]
        }
    }
}
```

Add exhaustive `BASCognitiveLayer` projections to/from both legacy layer enums and the exact L9 aliases to `BASNamingMatrix`. Do not change any existing raw value or `primaryKernel` return value.

- [ ] **Step 4: Run identity regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASSemanticArchitectureIDTests|BASNamingMatrixTests|BASMotherboardLayerMappingTests|BASFourteenLayerReconciliationTests|BASLayerKillSwitchIDTests'
```

Expected: PASS; 14/4/4/7 is proven without a second layer or kernel enum.

- [ ] **Step 5: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASObservationReconciliationCore.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardArchitecture.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASNamingMatrix.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASMotherboardLayerMapping.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSemanticArchitectureIDTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASNamingMatrixTests.swift
git commit -m "feat: extend canonical architecture identities"
```

### Task 2: Add the Missing Keyed Artifact Mesh Owner

**Reuse Decision**

- **Class:** M.
- **Existing unique owner candidates searched:** `BASSovereignCanonicalBytes`, `BASCanonicalBytesBridge`, `BASResult`/`BASFrameEnvelope`/`BASBundle`, `BASEventLogStorage`, `BASSQLiteEventLogStorage`, and current BASMemory SQLite stores.
- **Missing invariant:** no current owner supplies keyed content identity separated from storage, immutable DAG records, compare-and-swap heads, and ordinary child attestations through one put path.
- **Why Create is allowed:** keyed Artifact Mesh identity/CAS/store is explicitly allowlisted by Section 4.4. The new owner composes existing canonical, Crypto, SQLite, file-protection, secure-delete, and schema-generation primitives rather than replacing them.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`

**Interfaces:**
- Consumes: `BASSovereignCanonicalBytes.lengthPrefixed`, swift-crypto HMAC-SHA256, `BASResult`, `BASBundle`, SQLite transactions/WAL, generated `ArtifactMeshV1Schema`.
- Produces: `BASArtifactID`, identity/storage/attestation records, `BASArtifactStorePort`, and a durable SQLite implementation.

**Production Create Proof — `BASArtifactMeshCore.swift`**

1. Repository search candidates are the canonical-byte bridge, low-entropy wrappers, event log, and SQLite stores; none owns keyed DAG identity or CAS heads.
2. Public primitives searched are swift-crypto HMAC/SHA-256 and Foundation `Data`; they provide cryptography, not the domain identity boundary.
3. Missing invariant: one serialization of identity-only fields creates a scope-keyed ID while storage locators, signatures, and receipts remain outside identity.
4. `BASFrameEnvelope` cannot provide keyed identity/CAS, and extending `BASEventLog` would incorrectly make DAG identity depend on event sequence.
5. `BASArtifactMesh` is the pure identity authority; only a `BASArtifactStorePort` implementation owns mutable heads; store errors fail closed.
6. Dependency direction is `BASRuntimeCore -> Crypto` and `BASMemory -> BASRuntimeCore`; no core-to-memory edge is added.
7. There is no old Artifact Mesh path. Legacy raw references are frozen behind explicit adapters and all new references use `BASArtifactID`.
8. Golden-vector, self-reference, relocation, attestation-put, duplicate-ID, tamper, CAS, and duplicate-authority tests enforce the boundary.

**Production Create Proof — `BASArtifactSQLiteStore.swift`**

1. Candidates are `BASSQLiteEventLogStorage`, user-state/graph/vector stores, and `BASSQLiteSecureDelete`; none stores immutable keyed DAG nodes with named CAS heads.
2. SQLite transactions, constraints, WAL, checkpoint/backup, and the existing file-protection/secure-delete policy are reused unchanged.
3. Missing invariant: atomically insert one immutable identity/storage record and optionally compare-and-swap one mutable head.
4. Extending the event log would create a second meaning for its sequence/hash truth and cannot model independent content-addressed reads.
5. The actor owns one SQLite connection and head transaction state; commitment keys come from an injected epoch resolver; corruption/reopen failures never recreate an empty store.
6. The adapter depends inward on `BASArtifactStorePort`; RuntimeCore never imports SQLite or BASMemory.
7. Migration `024_artifact_mesh_v1.sql` is additive; existing stores remain owners of their data and are not dual-written.
8. Reopen, rollback, concurrent CAS, wrong-key epoch, payload corruption, duplicate identical put, conflicting duplicate put, and target-index tests cover crash/replay/duplicate ownership.

**Production Create Proof — `024_artifact_mesh_v1.sql`**

1. Repository search covers all current BASMemory SQL migrations and generated-schema tests; none defines the immutable Artifact Mesh node/head/attestation-target schema.
2. SQLite DDL and the existing migration generator are reused; neither supplies this domain schema or its ownership binding.
3. Missing invariant: one additive, versioned schema whose constraints back the exact Artifact Mesh identity/storage/head transaction owned by `BASArtifactSQLiteStore`.
4. Appending these statements to an unrelated store migration would transfer schema ownership and make rollback/version detection ambiguous; a separately numbered additive migration is required.
5. The SQL file has no authority symbol, runtime API, connection, or mutable owner of its own. Its ledger row, sole consumer, migration execution, recovery, and deletion policy are all the same `BASArtifactStorePort`/`BASArtifactSQLiteStore` owner family.
6. Dependency direction remains `BASMemory -> BASRuntimeCore`; generated `ArtifactMeshV1Schema` is consumed only by `BASArtifactSQLiteStore` and no core module loads SQL resources.
7. Existing migrations and stores remain untouched; migration 024 is forward-additive and rollback refuses partial/unknown schema rather than recreating an empty store.
8. Schema generation, fresh/reopen migration, constraint, rollback, tamper, duplicate put, CAS, and target-index tests cover the file. Its candidate manifest uses this exact eight-field proof and exact workspace-relative path.

- [ ] **Step 1: Write RED identity and ordinary-attestation tests**

```swift
import Crypto
import Foundation
import XCTest
@testable import BASRuntimeCore

func testDomainPayloadHasNoSelfIdentityOrProof() throws {
    let core = fixtureIdentityCore(payload: Data("payload".utf8))
    let encoded = try JSONEncoder().encode(core)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let topLevelKeys = Set(object.keys)
    XCTAssertFalse(topLevelKeys.contains("artifactID"))
    XCTAssertFalse(topLevelKeys.contains("payloadRef"))
    XCTAssertFalse(topLevelKeys.contains("signature"))
    XCTAssertFalse(topLevelKeys.contains("turnID"))
    XCTAssertFalse(topLevelKeys.contains("branchID"))
}

func testAttestationUsesTheOrdinaryPutPath() async throws {
    let store = try makeArtifactStore()
    let target = try await store.put(identityCore: fixtureIdentityCore(), headUpdate: nil)
    let attestation = fixtureAttestationPayload(targetArtifactID: target.body.artifactID)
    let attestationCore = try fixtureIdentityCore(kind: "artifact-attestation", payload: canonicalBytes(attestation))
    let child = try await store.put(identityCore: attestationCore, headUpdate: nil)
    let indexed = try await store.attestationArtifactIDs(targeting: target.body.artifactID)
    XCTAssertEqual(indexed.items, [child.body.artifactID])
}

func testRelocationCannotChangeIdentity() throws {
    let id = try BASArtifactMesh.artifactID(for: fixtureIdentityCore(), commitmentKey: fixtureKey(), commitmentKeyEpoch: 7)
    XCTAssertEqual(fixtureStorage(id: id, payloadRef: "random-a").artifactID, id)
    XCTAssertEqual(fixtureStorage(id: id, payloadRef: "random-b").artifactID, id)
}
```

Add store tests that mutate each identity field, corrupt payload bytes, race two identical head expectations, reopen the database, and use a missing key epoch. Add fixed canonical vectors for all four `BASArtifactScopeBinding` tags; reject a `public` tag carrying an ID, a non-public tag without exactly one ID, synthesized-enum encodings, and any attempt-scoped `BASArtifactIdentityCore` containing raw `turnID`/`branchID` keys.

- [ ] **Step 2: Run RED**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASArtifactMeshTests|BASArtifactStoreTests'
```

Expected: compile failure because the allowlisted owner does not exist.

- [ ] **Step 3: Add the minimal identity and port contracts**

`BASArtifactMeshCore.swift` defines these exact responsibilities:

```swift
public struct BASArtifactID: Codable, Sendable, Hashable {
    public let integrityAlgorithm: String
    public let commitmentKeyEpoch: UInt64
    public let commitmentHex: String

    public init(
        integrityAlgorithm: String,
        commitmentKeyEpoch: UInt64,
        commitmentHex: String
    ) {
        self.integrityAlgorithm = integrityAlgorithm
        self.commitmentKeyEpoch = commitmentKeyEpoch
        self.commitmentHex = commitmentHex
    }

    public var storageScalar: String {
        get throws {
            try validateStorageFields()
            let bytes = BASSovereignCanonicalBytes.lengthPrefixed([
                "bas-artifact-id-storage-v1",
                integrityAlgorithm,
                String(commitmentKeyEpoch),
                commitmentHex
            ])
            return bytes.base64EncodedString()
        }
    }

    public init(storageScalar: String) throws {
        guard !storageScalar.isEmpty,
              storageScalar.utf8.count <= 4_096,
              let bytes = Data(base64Encoded: storageScalar),
              bytes.count <= 3_072 else {
            throw BASArtifactIDStorageScalarError.invalidBase64OrLength
        }
        guard bytes.base64EncodedString() == storageScalar else {
            throw BASArtifactIDStorageScalarError.nonCanonicalBase64
        }
        let fields = try Self.decodeBoundedLengthPrefixedFields(bytes)
        guard fields.count == 4 else {
            throw BASArtifactIDStorageScalarError.invalidFieldCount
        }
        guard fields[0] == "bas-artifact-id-storage-v1" else {
            throw BASArtifactIDStorageScalarError.unsupportedVersion
        }
        guard !fields[2].isEmpty,
              let epoch = UInt64(fields[2]),
              fields[2] == String(epoch) else {
            throw BASArtifactIDStorageScalarError.invalidEpoch
        }
        self.integrityAlgorithm = fields[1]
        self.commitmentKeyEpoch = epoch
        self.commitmentHex = fields[3]
        try validateStorageFields()
    }
}

public enum BASArtifactIDStorageScalarError: Error, Sendable, Equatable {
    case invalidBase64OrLength
    case nonCanonicalBase64
    case malformedLengthPrefix
    case invalidFieldCount
    case unsupportedVersion
    case invalidAlgorithm
    case invalidEpoch
    case invalidCommitment
}

public enum BASArtifactScopeBinding: Codable, Sendable, Hashable {
    case publicArtifact
    case workspaceAuthority(BASArtifactID)
    case attempt(BASArtifactID)
    case durableWarrant(BASArtifactID)
}

public struct BASArtifactIdentityCore: Codable, Sendable, Hashable {
    public let canonicalizationVersion: String
    public let schemaID: String
    public let schemaVersion: String
    public let kind: String
    public let parentArtifactIDs: [BASArtifactID]
    public let producerLayerID: BASSemanticLayerID
    public let scopeBinding: BASArtifactScopeBinding
    public let logicalEpoch: UInt64
    public let createdLogicalTime: UInt64
    public let canonicalPayloadBytes: Data
    public let payloadLength: UInt64
    public let confidentialityLabel: String
    public let provenanceArtifactIDs: [BASArtifactID]
    public let snapshotRootArtifactID: BASArtifactID?
}

public struct BASArtifactStorageEnvelope: Codable, Sendable, Hashable {
    public let artifactID: BASArtifactID
    public let payloadRef: String
    public let storedLength: UInt64
    public let storageEncoding: String?
    public let compression: String?
    public let encryptionKeyID: String?
    public let encryptionMetadata: [BASArtifactStorageMetadataEntry]
}

public struct BASArtifactAttestationPayload: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let targetArtifactID: BASArtifactID
    public let attestationPurpose: String
    public let producerReceiptArtifactID: BASArtifactID?
    public let usageReceiptArtifactIDs: [BASArtifactID]
    public let proofSuite: String
    public let keyID: String
    public let keyEpoch: UInt64
    public let custodyClass: String
    public let signedStatementDigest: String
    public let proofBytes: Data
    public let logicalTime: UInt64
    public let policyEpoch: UInt64
}

public struct BASArtifactStoreReceiptBody: Codable, Sendable, Hashable {
    public let artifactID: BASArtifactID
    public let storage: BASArtifactStorageEnvelope
    public let head: BASArtifactHead?
}

public typealias BASArtifactStoreReceipt = BASResult<BASArtifactStoreReceiptBody>

public enum BASArtifactMutableHeadScope: Codable, Sendable, Hashable {
    case workspaceAuthority(BASArtifactID)
    case attempt(BASArtifactID)
}

public enum BASArtifactHeadPurpose: String, Codable, Sendable, Hashable {
    case workspaceRoot
    case attemptRoot
    case semanticSnapshot
    case projectionCheckpoint
}

public struct BASArtifactHeadKey: Codable, Sendable, Hashable {
    public let scope: BASArtifactMutableHeadScope
    public let purpose: BASArtifactHeadPurpose
}

public struct BASArtifactHead: Codable, Sendable, Hashable {
    public let key: BASArtifactHeadKey
    public let artifactID: BASArtifactID
    public let revision: UInt64
}

public struct BASArtifactHeadCAS: Codable, Sendable, Hashable {
    public let key: BASArtifactHeadKey
    public let expected: BASArtifactHead?
    public let replacementArtifactID: BASArtifactID
}

public protocol BASArtifactStorePort: AnyObject, Sendable {
    func put(identityCore: BASArtifactIdentityCore, headUpdate: BASArtifactHeadCAS?) async throws -> BASArtifactStoreReceipt
    func read(_ artifactID: BASArtifactID) async throws -> BASArtifactMeshRecord
    func head(_ key: BASArtifactHeadKey) async throws -> BASArtifactHead?
    func attestationArtifactIDs(targeting artifactID: BASArtifactID) async throws -> BASBundle<BASArtifactID>
}

public enum BASGovernedArtifactPayloadCodecError: Error, Sendable, Equatable {
    case nonCurrentWrite(typeName: String, found: String, expected: String)
    case unsupportedRead(typeName: String, found: String, expected: String)
}

public enum BASGovernedArtifactPayloadCodec {
    public static func canonicalBytes<T: BASSchemaVersioned>(
        for value: T
    ) throws -> Data

    public static func decodeCurrent<T: BASSchemaVersioned>(
        _ type: T.Type,
        from canonicalBytes: Data
    ) throws -> T
}
```

`BASGovernedArtifactPayloadCodec` is part of the one Artifact Mesh owner, not a second serializer or schema registry. `canonicalBytes(for:)` first requires `value.schemaVersion == T.currentSchemaVersion`, then delegates to the same deterministic canonical payload encoder/validator used by `BASArtifactMesh.canonicalIdentityBytes`; `decodeCurrent` bounded-decodes that exact wire representation, requires a present version equal to `T.currentSchemaVersion`, and returns no value on mismatch. Callers cannot supply an accepted-version set, decoder closure, migration map, or alternate JSON configuration. A later backward version is accepted only by extending this owner with an explicit typed migration plus the existing registry's fixture IDs. Every governed type exposes an explicit public initializer whose first parameter is `schemaVersion: String = Self.currentSchemaVersion`; the compile fixture constructs it from another target. Direct `JSONDecoder` use for a governed Artifact payload, synthesized internal memberwise construction across targets, and checking `schemaVersion` only after reducer access are source-gate failures.

`BASArtifactStorePort` is deliberately class-bound. Every production conformer is the one actor/class store object, and test conformers use actors/classes as well. This makes same-store composition claims testable with real object identity across canonical put, same-store reopen, runtime audit-bundle persistence, replay, and effect resolution. A value conformer, a fresh existential box, `as AnyObject` boxing of an unconstrained protocol, or two byte-equivalent store instances cannot satisfy an exact same-store gate.

Implement `validateStorageFields()` and `decodeBoundedLengthPrefixedFields(_:)` as private `BASArtifactID` helpers in the same file. The decoder walks UTF-8 bytes once, accepts one to four ASCII decimal length digits with no leading zero except `0`, requires the colon and exact declared byte count, rejects non-UTF-8 fields, caps each field at 1,024 bytes and the field count at five before the exact-four check, and rejects trailing/truncated bytes. `integrityAlgorithm` is 1–64 lowercase ASCII letters/digits/hyphens; `commitmentHex` is 2–512 lowercase ASCII hex characters with even length. `storageScalar` is standard padded Foundation Base64 of the existing injective `BASSovereignCanonicalBytes.lengthPrefixed` four-field frame. It never uses delimiter splitting, JSON, `description`, reflection, a digest, or a second ID/codec owner.

Add a fixed-vector round trip to `BASArtifactMeshTests`: the ID `hmac-sha256` / epoch `7` / commitment `0123456789abcdef` repeated four times encodes exactly as `MjY6YmFzLWFydGlmYWN0LWlkLXN0b3JhZ2UtdjExMTpobWFjLXNoYTI1NjE6NzY0OjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=` and `try BASArtifactID(storageScalar:)` returns the original value. Add an exact 16-case malformed table covering empty, overlong, invalid Base64, noncanonical Base64, leading-zero length, truncation, trailing bytes, missing/extra field, wrong version, invalid algorithm, noncanonical/overflow epoch, odd/uppercase/nonhex commitment; every case throws.

Also define hashable metadata entries, `BASArtifactMeshRecord`, `BASCanonicalPayloadValidator`, typed errors, and `BASArtifactMesh.canonicalIdentityBytes/artifactID/verify`. The displayed `BASArtifactHeadKey`/head/CAS shapes are exact: mutable heads can exist only in a typed workspace-authority or Attempt scope and one of the four reviewed purposes; `.public`, durable-warrant, raw string, empty ID, and caller-defined purpose namespaces are impossible. CAS requires `expected == nil` only for revision-zero creation; otherwise key/revision/artifact must equal the current row, replacement revision is exactly current + 1, and the replacement Artifact scope must equal the key scope. The sole legacy string adapter bounded-decodes one canonical length-prefixed key, reconstructs the typed value, and round-trips byte equality before calling this port; no production API accepts the string. Add alternate-encoding, wrong Attempt/workspace scope, cross-scope replacement, revision overflow/stale CAS, purpose collision, and legacy-round-trip mutation tests.

`BASArtifactScopeBinding` uses an explicit canonical tag plus zero-or-one Artifact-ID field, not synthesized enum encoding: the tags are exactly `public`, `workspace-authority`, `attempt`, and `durable-warrant`; `public` carries no ID and every other tag carries exactly one nonempty `BASArtifactID`. A workspace authority artifact establishes the protected workspace scope, an Attempt reference artifact transitively binds the workspace/window/session/task/Attempt generations, and attempt-scoped identities use only `.attempt(attemptRefArtifactID)` rather than copying editable `turnID`/`branchID` strings. Domain payloads that need turn or external-boundary identity carry the canonical `BASTurnOperationRef`/`BASTurnBranchRef` and must prove that root resolves to the same Attempt. Durable-warrant scope is accepted only for non-executable warrant/audit artifacts, never as a shortcut around Attempt closure. The identity encoder validates payload length and schema, preserves semantic parent/provenance order, frames once with `lengthPrefixed`, and computes HMAC-SHA256. When a semantic read version applies, `snapshotRootArtifactID` binds the one snapshot artifact whose payload owns the canonical ordered `[BASLaneWatermark]`; identity encoding never copies those watermarks. It never encodes a dictionary/set or any storage/proof/receipt field.

In the same change that first creates `BASArtifactMeshCore.swift`, append that exact workspace-relative path to `artifact.mesh.evidence_paths` and update only its status from `approved_missing` to `converging`; append each later created allowlisted path to the same evidence list in its creation change. Keep classification `M`, authority symbol, permission, work package, and all other cards byte-stable during this first transition. The created path, evidence update, and lifecycle transition are one review unit. Run the OwnerLedger checker immediately; it must reject an absent path, an unchanged `approved_missing`, an early `implemented`, a created path absent from evidence, or any unapproved path.

- [ ] **Step 4: Add the SQLite adapter and migration**

`BASArtifactSQLiteStore` is an actor conforming to `BASArtifactStorePort`. Every Artifact-ID TEXT bind uses `try artifactID.storageScalar`; every read uses `try BASArtifactID(storageScalar:)`; no local encoder/parser remains. In one transaction it inserts immutable identity/storage bytes, updates the attestation target query index when `kind == "artifact-attestation"`, and optionally performs the head CAS. It generates protected random `payloadRef` values, revalidates canonical payload and keyed identity on every read, treats byte-identical duplicate puts as idempotent, and treats same-ID/different-bytes as corruption. Consume generated `ArtifactMeshV1Schema.allStatementsSQL`; do not use `Bundle.module` or add `.process("SQL")`.

- [ ] **Step 5: Run canonical/store regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASArtifactMeshTests|BASArtifactStoreTests|BASSovereignCanonicalBytesInjectivityTests|BASCanonicalBytesRustParityTests|BASChapter890CanonicalEncodingBaselineTests'
```

Expected: PASS; attestation uses `put`, relocation preserves ID, identity mutation changes ID, and corruption/CAS races fail closed.

- [ ] **Step 5A: Seal the M-owner lifecycle only after every gate is green**

After all three allowlisted production paths exist, all three are recorded in `artifact.mesh.evidence_paths`, Step 5 passes, and `artifact.mesh.current_conflicts` remains exactly empty, change `artifact.mesh.status` from `converging` to `implemented`, then run. No M owner may reach `implemented` with a `merge`, `freeze`, `retire`, or `retain` entry still in `current_conflicts`; a proven harmless compatibility view belongs in `allowed_projections`, while a resolved conflict is removed only in the same review unit as its named freeze/retirement evidence.

```bash
python3 scripts/check_qinao_owner_ledger.py --root "$PWD" \
  --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/test_check_qinao_owner_ledger.py -v
```

Expected: PASS. If any production path or focused gate is missing, leave the row `converging`; never claim `implemented` to silence a failure.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift \
  BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift \
  BehavioralAISubstrate/Sources/BASMemory/SQL/024_artifact_mesh_v1.sql \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactMeshTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift \
  docs/superpowers/specs/qinao-owner-ledger-v1.json
git commit -m "feat: add keyed artifact mesh owner"
```

### Task 2A: Extend the Existing Turn Contracts with One Operation Root and Typed Branches

**Reuse Decision**

- **Class:** E; the selected K3 EventLog/Attempt owner alone installs the durable operation root/head, allocates typed branches, and owns checkpoint/terminal receipt lineage. `BASTurnRuntimeEngine` only composes references and may hold one transient unsealed Provider-event-tail CAS that is dropped on crash; Artifact Mesh remains the immutable identity owner.
- **Existing unique owner:** `BASTurnRuntimeEngine.swift`, `BASEventLog.swift`, and the low-entropy value-contract file already shared by BAS and Qinao.
- **Missing invariant:** current `turnID`, `branchID`, `operationID`, stream ID, publication ID, and effect ID values do not prove one parent operation or typed branch lineage.
- **Why no M Create is allowed:** extend `BASLowEntropyPrimitives.swift`, `BASEventLog.swift`, and `BASTurnRuntimeEngine.swift` in place; only a focused test file is new. Do not add an operation registry, branch ledger, retry owner, or second Artifact-ID codec.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationRefTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

**Interfaces and ownership:**

- `BASTurnOperationPayload` is an unsigned, self-ID-free Artifact Mesh payload containing only admission-time facts: workspace/incarnation, Attempt reference, generation vector, input artifact ID, one exact `budgetLeaseArtifactID`, optional already-selected model/profile lineage, policy/deletion epochs, and restoration/schema epoch. It contains no future snapshot, execution binding, branch, receipt, storage locator, self digest, or signature. The referenced self-ID-free `BASBudgetLeasePayload` binds the same Attempt/generation/grant/policy/deletion/boot session plus finite nonnegative token, byte, branch, remand, hop, cost, and monotonic-deadline ceilings; no caller may restate those ceilings after admission.
- `BASTurnOperationRef` contains the ordinary Artifact Mesh ID returned when that payload is stored. It cannot be initialized from an arbitrary UUID/string in production.
- `BASTurnBranchKind` is exactly `providerEgress`, `provisionalStream`, `finalPublication`, or `effect`; `BASTurnBranchRef` is the canonical tuple `(turnOperationRef, kind, ordinal)`. Stream/final require ordinal zero; Provider-egress/effect ordinals are monotonically allocated, stable, and never reused under that root.
- The same W1 low-entropy owner declares—once—`BASProviderStepPurpose` (`groundingProposal|turnStep|verifierProposal`), `BASProviderOutputRole` (`internalProposal|terminalAnswerCandidate`), `BASProviderVisibilityMode` (`incrementalVerified|bufferedUntilVerified`), and `BASProviderExecutionRef`. The ref is exactly `(turnOperationRef, providerEgressBranchRef, attemptRef, leaseID, providerExecutionID, acceptanceGeneration, requestSequence)` and validates that the branch parent matches and kind is `.providerEgress`. Allocation, claim, lineage, proposal identity, and recovery use the canonical sequence-zero base. The same owner supplies the sole checked `withRequestSequence(_:)` and `canonicalSequenceZeroBase()` operations: every event uses that same ref type with the other six fields byte-equal to the base, and validators return to zero only through this API. No event-specific execution identity/ref/codec is allowed. These values must exist before K3 W2; silicon W4, semantic, runtime, sovereign, and Qinao only consume them and cannot redeclare near-equivalent enums/refs.
- W1 also declares one unsigned, self-ID-free `BASProviderBranchPolicy` Artifact Mesh payload as the value contract for the existing `execution.plan-provider-router` owner. Its canonical ordered `BASProviderBranchStepRule` values bind a stable `stepRuleID`, one purpose, canonical allowed output roles, maximum instances, ordered required causal-receipt schema/count rules, `answerOnly`, and `mayRunAfterTerminalPin`; the policy additionally binds total maximum branch count, one `BASProviderVisibilityMode`, and maximum preauthorized verifier branches. W2 implements the K3 command/storage semantics and can reopen this low-entropy type without importing W4 silicon types, but it cannot allocate a production Provider branch while either the policy or execution binding is absent. In W4 the ordinary Artifact Mesh `put` returns `providerBranchPolicyArtifactID`; K3 installs that ID in the same monotonic head attachment as the one execution-binding root only after equality-checking that the binding references it. `BASSiliconExecutionBinding` maps each `stepRuleID` to signed model/profile/plan/budget templates and references this one policy artifact; it may not copy or redefine purpose/output/causality/count/visibility authority. W3 may prove the semantic R5/R6 contract with a deterministic test/shadow conformer, but production grounder allocation and the production R5→R6→context cutover begin only after this W4 attachment.
- The operation root, cross-process Provider observation, and generic K3→K4→K3 boundary evidence are also W1 persisted contracts. They are declared here before W2 and contain no K3/K4 implementation, SQLite row, sink, retry, or release policy:

```swift
public struct BASTurnOperationPayload: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let workspaceAuthorityArtifactID: BASArtifactID
    public let workspaceIncarnationArtifactID: BASArtifactID
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let inputArtifactID: BASArtifactID
    public let budgetLeaseArtifactID: BASArtifactID
    public let orderedSelectedModelProfileLineageArtifactIDs: [BASArtifactID]
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let restorationEpoch: UInt64
    public let runtimeSchemaEpoch: UInt64
}

public enum BASProviderObservedTerminalState: String, Codable, Sendable, Hashable {
    case completed, failed, cancelled, indeterminate
}

public struct BASProviderObservedReceipt: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let providerExecutionRef: BASProviderExecutionRef
    public let selectedProviderDescriptorArtifactID: BASArtifactID
    public let materializedRequestArtifactID: BASArtifactID
    public let acceptedTerminalEventRef: BASProviderExecutionRef
    public let acceptedTerminalEventHeadDigest: String
    public let monotonicStart: UInt64
    public let monotonicEnd: UInt64
    public let cancellationObserved: Bool
    public let observedByteCount: UInt64
    public let observedTokenCount: UInt64
    public let terminalProposalArtifactID: BASArtifactID?
    public let terminalResultArtifactID: BASArtifactID?
    public let echoedProviderReceipt: String?
    public let terminalState: BASProviderObservedTerminalState
}

public struct BASBoundaryAnchorRequest: Codable, Sendable, Equatable, Hashable {
    public let permitArtifactID: BASArtifactID
    public let boundaryInstanceID: String
    public let turnOperationRef: BASTurnOperationRef
    public let turnBranchRef: BASTurnBranchRef
    public let authorizationGrantArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID?
    public let sourceWatermark: UInt64
    public let sourceRootArtifactID: BASArtifactID
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
    public let requestID: String
}

public struct BASBoundaryAnchorReceipt: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let permitArtifactID: BASArtifactID
    public let boundaryInstanceID: String
    public let turnOperationRef: BASTurnOperationRef
    public let turnBranchRef: BASTurnBranchRef
    public let authorizationGrantArtifactID: BASArtifactID
    public let capabilityUseReceiptArtifactID: BASArtifactID
    public let sourceWatermark: UInt64
    public let sourceRootArtifactID: BASArtifactID
    public let coveringWatermark: UInt64
    public let coveringRootArtifactID: BASArtifactID
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
    public let monotonicArmDeadline: UInt64
}

public struct BASBoundaryArmReceipt: BASSchemaVersioned, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let permitArtifactID: BASArtifactID
    public let anchorReceiptArtifactID: BASArtifactID
    public let boundaryInstanceID: String
    public let turnOperationRef: BASTurnOperationRef
    public let turnBranchRef: BASTurnBranchRef
    public let boundaryOwnerEpoch: UInt64
    public let bootSessionID: String
    public let monotonicCallHandoffDeadline: UInt64
}

public protocol BASSovereignBoundaryAnchoring: Sendable {
    func claimAndAnchorBoundary(
        _ request: BASBoundaryAnchorRequest
    ) async throws -> BASArtifactStoreReceipt

    func anchorClaimedBoundary(
        _ request: BASBoundaryAnchorRequest
    ) async throws -> BASArtifactStoreReceipt
}
```

  Each persisted struct has the explicit public default-version initializer required by `BASGovernedArtifactPayloadCodec`; the stored-shape block omits only those mechanical assignments. `BASTurnOperationPayload` permits an empty ordered model/profile lineage when selection has not happened at admission; when entries are present they are nonempty, unique, canonical, complete, and preserve selection order. It also requires exact workspace/incarnation/Attempt/generation/lease/epoch equality at admission. `BASProviderObservedReceipt` validates stable-field equality between the accepted event ref and sequence-zero base, positive bounded event sequence, monotonic/count/digest bounds, and state-specific presence: completed requires terminal proposal/result; failed/cancelled/indeterminate cannot fabricate success evidence. Boundary receipts bind one exact root/branch/permit/instance/owner/boot tuple and are ordinary-put through the same codec. `BASSovereignBoundaryAnchoring` is a low-entropy port only: W2 tests inject a deterministic no-authority conformer; W5 Task 3 supplies the sole durable K4 implementation. No W2 source imports a W5 concrete K4 type.
- The same W1 value owner declares one persisted, self-ID-free lineage vocabulary rather than letting runtime, silicon, or sovereign invent different “complete chain” shapes:

```swift
public struct BASProviderBranchLineageEntry: Codable, Sendable, Hashable {
    public let providerEgressBranchRef: BASTurnBranchRef
    public let stepRuleID: String
    public let providerExecutionRef: BASProviderExecutionRef
    public let executionPlanArtifactID: BASArtifactID
    public let allocationReceiptArtifactID: BASArtifactID
    public let claimReceiptArtifactID: BASArtifactID
    public let eventHeadSealReceiptArtifactID: BASArtifactID
    public let proposalArtifactID: BASArtifactID
    public let proposalReceiptArtifactID: BASArtifactID
    public let orderedCausalReceiptArtifactIDs: [BASArtifactID]
}

public enum BASProviderBranchChainCut: String, Codable, Sendable, Hashable {
    case terminalPrefix
    case throughVisibility
}

public struct BASProviderBranchChainPayload: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let providerBranchPolicyArtifactID: BASArtifactID
    public let executionBindingArtifactID: BASArtifactID
    public let cut: BASProviderBranchChainCut
    public let orderedEntries: [BASProviderBranchLineageEntry]
    public let terminalAnswerSourceBranchRef: BASTurnBranchRef
    public let terminalSourceReceiptArtifactID: BASArtifactID
    public let orderedVisibilityEvidenceArtifactIDs: [BASArtifactID]
    public let providerVisibilityReceiptArtifactID: BASArtifactID?
}
```

  Every entry has an explicit validating initializer and represents one actually claimed/sealed proposal branch, not a display projection. It exact-checks one root, `.providerEgress`, strict K3 ordinal order, one installed policy/binding, policy `stepRuleID`, complete execution-ref equality, plan membership, allocation/claim/seal/proposal receipts, and causal receipts. `.terminalPrefix` ends exactly at the pinned terminal source and requires empty visibility evidence plus nil visibility receipt; this is the only chain artifact any spool may reference. In buffered mode the spool and prefix precede visibility. In incremental mode K3 opens visibility from frozen pre-call policy evidence, the already-claimed terminal call then seals, and the later spool still references a `.terminalPrefix` cut that deliberately excludes visibility. `.throughVisibility` contains that exact prefix, then every policy-authorized post-pin verifier entry in K3 order, and requires the exact ordered incremental-policy or buffered verifier/L10 evidence plus the winning `BASProviderVisibilityReceipt`. It is created only after both the terminal prefix and visibility evidence exist, irrespective of their chronological order. Ordinary Artifact Mesh `put` supplies each chain artifact's ID; the payload has no chain ID, self digest, storage locator, or mutable head. Register `BASProviderBranchPolicy` and `BASProviderBranchChainPayload` exactly once in the existing schema-governance registry. Silicon produces entries/terminal-prefix evidence, sovereign release closes through visibility, and runtime/result/replay only consume these canonical payloads.

  The Silicon W1 provider-contract extension canonicalizes the existing `BASOrganDescriptor`, including its exact `BASProviderContainmentClass`, without changing that existing adapter wire type. In the same BASOrgan owner file it declares one governed persisted parent, `BASPersistedOrganDescriptorPayload`, whose only domain field is `descriptor: BASOrganDescriptor`. After W4 value-only routing selects one descriptor, Silicon ordinary-puts that parent through `BASGovernedArtifactPayloadCodec` and supplies its opaque Artifact ID as `selectedProviderDescriptorArtifactID` to `BASProviderBranchAllocationRequest`. K3 does not import or parse BASOrgan: it binds that exact parent ID into the allocation row, `BASProviderBranchAllocationReceipt`, and `BASProviderExecutionClaimReceipt`. `BASPlannedOrganRequest` and the sole executor reopen the governed parent, then canonical-compare its embedded descriptor to the selected adapter; a caller-restated provider ID/class has no authority. Replay reaches the same parent through the lineage entry's allocation/claim receipt references, so no descriptor field is added to `BASProviderExecutionRef`, `BASSiliconExecutionBinding`, or the shared lineage shape. The embedded descriptor is not separately registered.

  Extend the existing `BASProviderEventHeadSealRequest` and `BASProviderEventHeadSealReceipt` with exactly two paired optional Artifact IDs: `providerEgressBoundaryArmReceiptArtifactID` and `providerObservedReceiptArtifactID`; do not add either ID to `BASProviderBranchLineageEntry` or `orderedCausalReceiptArtifactIDs`. W1 declares the self-ID-free `BASProviderObservedReceipt` in this same cross-target low-entropy owner, and the model-neutral Qinao supervisor ordinary-puts it; K3 never imports Qinao. Silicon's sole `BASProviderAttemptExecutor` derives containment from the receipt-bound descriptor before invocation: `inProcessCertified` requires both IDs nil, while `isolatedExtension` and `remote` require both exact nonnil IDs and full plan/payload/destination equality. K3 keeps `BASSiliconExecutionBinding` and that descriptor opaque. Its W5 package-only same-owner `BASK3ProviderEgressHandoffPort.beginProviderEgressHandoff(...)` view moves only the matching arm row `egress_boundary_armed → sent_or_unknown` and returns a callable outcome only to the fresh winner; the six-method public control port remains unchanged. For a successful isolated/remote result, `sealProviderEventHead` requires request/receipt evidence-ID equality, reopens the supervisor-authored terminal observation plus its own arm→permit/anchor/handoff rows, and atomically closes `sent_or_unknown → terminal_or_indeterminate` in the same transaction that stores both IDs and the terminal event-head seal/receipt. It exact-checks only K3-owned root/branch/canonical sequence-zero execution claim, the terminal event ref's stable-field/sequence relation, Attempt/generation and policy/deletion epochs/grant/use facts. Replay separately reopens the receipt-bound descriptor/plan and enforces containment/provider/plan/payload/destination equality again. The lineage entry already owns the unique seal-receipt reference, so replay reaches the complete boundary proof without a second lineage vocabulary or manifest boundary-evidence array. A branch left `sent_or_unknown`, missing a remote result, or lacking required evidence cannot seal or enter either chain cut; query-only reconciliation may supply the same authenticated terminal observation to this seal CAS but never resend.
- The selected K3 owner installs the root reference in the same transaction that advances the Attempt head. Its one `BASTurnOperationHead` later compare-and-sets `semanticSnapshotArtifactID` from absent to exactly one value, then in W4 jointly compare-and-sets `providerBranchPolicyArtifactID` plus `executionBindingArtifactID` from both absent to both present after proving the binding references that exact policy. A half-installed pair, conflicting second value, wrong Attempt/generation/epoch, or late branch fails closed.
- K3 alone allocates each next `providerEgress[requestOrdinal]` and binds a typed purpose (`groundingProposal`, `turnStep`, or `verifierProposal`), output role (`internalProposal` or `terminalAnswerCandidate`), exact prerequisite/causal artifact IDs, plan/binding, the opaque selected Provider-descriptor Artifact ID, budget, and one `ProviderExecutionRef` containing that exact branch ref. Provider preflight, descriptor ordinary-put, Pareto routing, and signed route fallback finish before allocation. Once K3 returns an allocation, recovery may claim/continue that same unclaimed branch or reopen it; it cannot discard the ordinal, provider descriptor, or route. The branch receives at most one physical call. A tool/RSI continuation requires the exact prior proposal plus durable effect/result receipt; grounding and verifier branches require their frozen phase inputs. Concurrent/reused ordinals, a caller-minted branch, missing causality, provider/containment substitution, or a second claim/call on one branch fail closed. Every Provider result remains proposal-only. K3 compare-and-sets one `terminalAnswerSourceBranchRef` before its answer-mode call; only that source may attach ordinal-zero provisional stream and feed L10/spool/final. Its contract is answer-only and carries no tool/effect schema/capability; any emitted tool proposal fails the branch and cannot reopen allocation. After pin, only a preauthorized verifier/internal branch bound to the source may run before visibility; after visibility, no further Provider branch or sibling replacement is legal.
- Declare one `BASProviderBranchControlPort` in the existing EventLog contract owner—never a new registry/actor/store—with exactly these typed commands/lookups: `allocateProviderBranch(BASProviderBranchAllocationRequest) -> BASProviderBranchAllocationReceipt`, `claimProviderExecution(BASProviderExecutionClaimRequest) -> BASProviderExecutionClaimReceipt`, `sealProviderEventHead(BASProviderEventHeadSealRequest) -> BASProviderEventHeadSealReceipt`, `designateTerminalSource(BASProviderTerminalSourceRequest) -> BASProviderTerminalSourceReceipt`, `openProviderVisibilityGate(BASProviderVisibilityRequest) -> BASProviderVisibilityReceipt`, and `providerBranchState(turnOperationRef:branchRef:)`. The allocation request deliberately contains **no ordinal**; it binds the active Attempt/generation/epochs, installed provider-branch policy artifact, one policy `stepRuleID`, exact execution-plan/root proof, `selectedProviderDescriptorArtifactID`, requested output role, exact ordered causal artifact IDs, budgets/deadline, and expected current head. K3 reopens the immutable policy, validates every rule/count/edge/visibility field, treats the descriptor ID as opaque route identity, and returns the sole next `BASTurnBranchRef`; callers do not restate authoritative purpose/limits/provider/containment. The allocation and claim receipts repeat the exact K3-bound descriptor ID for equality, not as a second selectable field. Later requests bind that exact branch and complete branch-bound `ProviderExecutionRef`; every receipt binds the resulting K3 EventLog source head. Only the selected `BASSQLiteEventLogStorage` implements the port in W2. Semantic, silicon, runtime, and sovereign code receive this one injected port and may not keep a local ordinal, descriptor selection, policy copy, claim set, terminal-source flag, visibility flag, or retry truth.
- The five independently ordinary-put K3 Provider receipts—`BASProviderBranchAllocationReceipt`, `BASProviderExecutionClaimReceipt`, `BASProviderEventHeadSealReceipt`, `BASProviderTerminalSourceReceipt`, and `BASProviderVisibilityReceipt`—are self-ID-free `BASSchemaVersioned` structs with `currentSchemaVersion = "1.0.0"`, a stored `schemaVersion`, and explicit public default-version initializers. Requests/state projections remain transient and unregistered. K3 creates each receipt only from its committed row/root; every caller reaches it by the ordinary store receipt Artifact ID and reopens through `BASGovernedArtifactPayloadCodec`. The five exact registry object IDs are the Swift basenames, each with `.current`, `.backward_v1`, and `.future_rejection` fixtures; no receipt ID may point at a bare-Codable projection or SQL row encoding.
- Declare `BASBudgetLeaseControlPort` beside the existing EventLog contracts as a narrow command/query view over the **same** K3 owner, never a budget owner itself. It has exactly `claimBudgetUse(BASBudgetUseRequest) -> BASBudgetUseClaimOutcome` and `budgetLeaseState(turnOperationRef:) -> BASBudgetLeaseState`. `BASBudgetUseRequest` binds the installed lease ID, root, exact already-stored loop-envelope **and** loop-invocation Artifact IDs, parent invocation/use-receipt IDs when present, ring, declared edge/depth, candidate state/decision digest, typed progress-witness Artifact ID when required, active Attempt/generation/policy/deletion/boot epochs, idempotency request ID, expected lease revision, finite nonnegative deltas, and deadline. `BASBudgetUseClaimOutcome` is exactly a newly won or idempotently recovered self-ID-free `BASBudgetUseReceipt`, or a typed terminal `BASControlLoopTerminalReceiptPayload`; it never returns a caller-editable remaining counter. The receipt binds prior/new cumulative counters, request/envelope/invocation/lease/root, revision, witness/digest decision, and K3 source head. K3 is the only authority that can prove use; an ordinary Artifact Mesh copy of either receipt is replay evidence only after the K3 row/root is reopened and equality-checked. The W1 in-memory conformer proves the contract, W2's one `BASSQLiteEventLogStorage` implements both this port and `BASProviderBranchControlPort`, and no local `BASLayerSlice`/Runtime/Qinao/Provider counter can spend or recover a lease.
- `BASProviderVisibilityMode` is exactly `incrementalVerified` or `bufferedUntilVerified` and is frozen only in `BASProviderBranchPolicy`; the execution binding merely references that policy artifact ID. The visibility request for the first mode binds the terminal-source receipt plus pre-call/incremental deterministic-verifier policy receipt; the second binds the terminal source/head plus every required verifier-proposal receipt and L10 acceptance receipt. Neither accepts a terminal head alone. The single winning visibility receipt closes all Provider-branch allocation, while actual UI/network bytes still require the sovereign stream/publication boundary permits.
- Legacy `turnID`, `branchID`, `stableStreamOperationID`, `stablePublicationOperationID`, and effect `operationID` are bounded compatibility encodings of the exact root/branch tuple. The sole codecs are `BASTurnOperationRef.canonicalLegacyProjection()` / `BASTurnOperationRef.init(validatingCanonicalLegacyProjection:)` and `BASTurnBranchRef.canonicalLegacyProjection()` / `BASTurnBranchRef.init(validatingCanonicalLegacyProjection:)`, declared with the canonical refs in `BASLowEntropyPrimitives.swift`. Their injective, versioned, length-prefixed bytes include the exact Artifact-ID storage scalar and, for a branch, its parent/kind/canonical unsigned ordinal; bounded decode rejects noncanonical encodings, unknown versions/kinds, overflow, trailing bytes, nonzero stream/final ordinals, or a mismatched expected parent. No plan or adapter may add another branch codec, concatenate delimiters, or call `description`. Decode must recover and equality-check the parent and kind/ordinal; a free UUID/string is not accepted as authority and creates no retry/idempotency domain.
- Each branch retains a distinct grant, budget, state machine, receipt, and terminal/indeterminate truth. The common root is identity/recovery join only; it never becomes a fourth mutable reducer.

- [ ] **Step 1: Write RED identity, derivation, and single-head tests**

Prove one active root per Attempt head with exactly one installed zero-spend budget lease; deterministic distinct Provider/stream/final/effect branch references; rejection of nonzero stream/final ordinals; canonical sequence-zero execution base plus same-type checked event-sequence derivation and stable-field mismatch/second-ref rejection; K3-only monotonic Provider/effect ordinal allocation through the one `BASProviderBranchControlPort`; exactly one claim/call per Provider branch; concurrent budget-use CAS has one winner, exact replay returns the same receipt, and changed request/root/lease/invocation/digest/witness/edge/depth/delta/revision/epoch/deadline fails without spend or mechanism work; selected-descriptor Artifact-ID equality across allocation row/receipts/claim and rejection of caller-restated provider/containment substitution; typed purpose and causal-predecessor validation for grounding, tool/RSI continuation, and verifier proposal branches; exactly one terminal-answer source and one visibility transition allowed to reach verifier/spool/final; exact claim lookup after reconstructed handles; mutation of every `BASProviderBranchPolicy` field changes canonical bytes and invalid/duplicate step rules fail bounded decode; both persisted policy/chain payloads have exactly one governance-registry entry; lineage-entry mutation/missing-receipt/root/order tests; missing/foreign/malformed `BASProviderObservedReceipt`, local-nil versus isolated/remote-nonnil seal-arm evidence, fresh-winner-only handoff, full arm→permit/anchor mutation rejection, and atomic remote-observation-plus-seal success finalization; `sent_or_unknown`/lost-result rejection from both chain cuts; terminal-prefix versus through-visibility fixed vectors and illegal future-receipt/cut rejection; fixed-vector round trips and malformed rejection for both exact canonical legacy codecs; same-transaction Attempt-head plus budget-lease installation; one-time snapshot attachment; atomic all-or-nothing policy+binding attachment; rejection of allocation while either member is absent/mismatched; mismatch/ABA/late-result rejection; and zero separately minted stream/publication/effect roots.

- [ ] **Step 2: Extend the value and K3/runtime owners in place**

Store the immutable turn payload and referenced `BASBudgetLeasePayload` through ordinary Artifact Mesh before the K3 transaction; an orphan is harmless and has no spend authority. In `BASLowEntropyPrimitives.swift`, declare the canonical root/branch plus Provider purpose/output-role/visibility/ref/policy/lineage values, the bounded budget lease/use request/receipt/state/outcome values, `BASProviderObservedReceipt`, the generic boundary request/receipts/port, and the sole canonical legacy codecs above. Register `BASTurnOperationPayload`, `BASBudgetLeasePayload`, `BASBudgetUseReceipt`, `BASProviderBranchPolicy`, `BASProviderBranchChainPayload`, `BASProviderObservedReceipt`, `BASProviderBranchAllocationReceipt`, `BASProviderExecutionClaimReceipt`, `BASProviderEventHeadSealReceipt`, `BASProviderTerminalSourceReceipt`, `BASProviderVisibilityReceipt`, `BASBoundaryAnchorReceipt`, and `BASBoundaryArmReceipt` once each in the existing schema-governance registry; every ordinary put/reopen uses `BASGovernedArtifactPayloadCodec`. The K3 transaction reopens/equality-checks the lease and admission facts, installs the returned root plus zero-spend lease row, and advances the Attempt head atomically. The semantic snapshot later attaches once; W4 attaches `providerBranchPolicyArtifactID` and `executionBindingArtifactID` together in one all-or-nothing CAS and emits one source-head-bound transition receipt. In `BASEventLog.swift`, declare the budget-use and Provider allocation/claim/seal/terminal-source/visibility request and governed receipt values and extend `BASEventLogStorage` with the narrow `BASBudgetLeaseControlPort` and six-method `BASProviderBranchControlPort`; its W1 in-memory conformer proves semantics, while W2 adds the sole SQLite implementation inside the existing K3 `FULL` transaction and fails every production allocation until the joint W4 attachment exists. `BASTurnRuntimeEngine.TurnOperation` exposes the root and consumes port receipts; it cannot derive a production Provider ordinal, spend an envelope-local budget, or mint UUID/string operation authority locally.

- [ ] **Step 3: Run the focused and ownership regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASTurnOperationRefTests|BASTurnOperationOwnershipTests|BASEventLogStorageTests|BASEBrainSchemaGovernanceRegistryTests'
```

Expected: PASS; every egress/stream/final/effect identity decodes to the one Attempt root, while each branch preserves separate authority and terminal truth.

- [ ] **Step 4: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLog.swift \
  BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASTurnOperationRefTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift
git commit -m "feat: root turn branches in one operation"
```

### Task 3: Extend the Existing Sovereign Authority with Canonical Capability Grants

**Reuse Decision**

- **Class:** E.
- **Existing unique owner:** credential payloads in `BASRuntimeCore/EBrainControlPlaneCore.swift` and mutable mint/redeem/revoke state in `BASSovereign/BASSovereignTokenAuthority.swift`.
- **Missing invariant:** an unsigned, phase-aware, attenuating grant payload whose Artifact Mesh ID is identity, plus atomic reserve/claim/spend against that ID.
- **Why Create is allowed:** no production file is created. `BASCapabilityGrant` and the stored `BASCapabilityUseReceipt` fact are the materially distinct canonical payloads permitted by Section 4.4. Issuance and claim reuse the ordinary Artifact Mesh store receipt; only tests are new.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCapabilityGrantAttenuationTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignTokenAuthorityTests.swift`

**Interfaces:**
- Consumes: `BASArtifactID`, `BASArtifactStorePort`, ordinary Artifact Mesh `put(identityCore:headUpdate:)`, `BASArtifactStoreReceipt`, and current TokenAuthority signing/revocation state.
- Produces: canonical `BASCapabilityGrant`, the one self-ID-free `BASCapabilityUseReceipt` payload, pure attenuation rules, and the exact TokenAuthority methods `issueCapability`, `reserveCapability`, `claimCapability`, and `lookupCapabilityUseReceipt` consumed by the Sovereign release/effects plan.

- [ ] **Step 1: Write RED attenuation, identity, and single-consumption tests**

```swift
import Foundation
import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

func testGrantPayloadHasNoSelfIDOrSignature() throws {
    let bytes = try JSONEncoder().encode(fixtureGrant())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let topLevelKeys = Set(object.keys)
    XCTAssertFalse(topLevelKeys.contains("grantArtifactID"))
    XCTAssertFalse(topLevelKeys.contains("grantDigest"))
    XCTAssertFalse(topLevelKeys.contains("signature"))
    XCTAssertFalse(topLevelKeys.contains("signatureEnvelope"))
    XCTAssertFalse(topLevelKeys.contains("payloadRef"))
    XCTAssertFalse(topLevelKeys.contains("turnID"))
    XCTAssertFalse(topLevelKeys.contains("branchID"))
    XCTAssertFalse(topLevelKeys.contains("operationID"))
}

func testUseReceiptPayloadHasNoSelfIdentityDigestOrSignature() throws {
    let labels = Set(Mirror(reflecting: fixtureCapabilityUseReceipt()).children.compactMap(\.label))
    XCTAssertTrue(labels.isDisjoint(with: Set([
        "artifactID", "useReceiptArtifactID", "receiptArtifactID",
        "useReceiptDigest", "receiptDigest", "signature",
    ])))
}

func testChildCannotBroadenParent() {
    let parent = fixtureGrant(audiences: ["l3"], maxBytes: 1_024)
    let child = fixtureGrant(
        audiences: ["l3", "l8"],
        maxBytes: 2_048,
        authorizationBasisArtifactID: fixtureArtifactID("parent"))
    XCTAssertThrowsError(try BASCapabilityGrantRules.validateAttenuation(child: child, parent: parent))
}

func testReleaseGrantBindsExactResultArtifact() {
    let grant = fixtureReleaseGrant(resultArtifactID: fixtureArtifactID("result-a"))
    let denied = BASCapabilityGrantRules.evaluateBoundSubject(
        grant: grant,
        subject: fixtureReleaseSubject(resultArtifactID: fixtureArtifactID("result-b")),
        state: fixtureValidationState())
    XCTAssertEqual(denied.decision, .deny)
}

func testEffectGrantRejectsWrongTypedBranchParentOrKind() {
    let grant = fixtureEffectGrant(
        turnOperationRef: fixtureTurnOperationRef("a"),
        turnBranchRef: fixtureBranch(root: "a", kind: .effect, ordinal: 2))
    let wrongRoot = fixtureEffectSubject(
        turnOperationRef: fixtureTurnOperationRef("b"),
        turnBranchRef: fixtureBranch(root: "b", kind: .effect, ordinal: 2))
    XCTAssertEqual(
        BASCapabilityGrantRules.evaluateBoundSubject(
            grant: grant, subject: wrongRoot, state: fixtureValidationState()).decision,
        .deny)
}

func testConcurrentIdenticalClaimsConvergeOnOneStoredUseReceipt() async throws {
    let fixture = makeAuthorityFixture()
    let issued = try await fixture.authority.issueCapability(
        fixtureGrant(),
        requestID: "issue-1")
    let grantArtifactID = issued.body.artifactID
    let subjectArtifactID = fixtureSubjectArtifactID()
    try await fixture.authority.reserveCapability(
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: subjectArtifactID,
        requestID: "claim-1")
    let successes = await concurrentClaims(
        authority: fixture.authority,
        grantArtifactID: grantArtifactID,
        boundSubjectArtifactID: subjectArtifactID,
        requestID: "claim-1")
    let receiptIDs = Set(successes.map { $0.body.artifactID })
    XCTAssertEqual(receiptIDs.count, 1)
    let receiptID = try XCTUnwrap(receiptIDs.first)
    let stored = try await fixture.artifactStore.read(receiptID)
    let useReceipt = try decodeCapabilityUseReceipt(stored)
    XCTAssertEqual(useReceipt.terminalState, .spent)
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASCapabilityGrantAttenuationTests|BASSovereignTokenAuthorityTests'
```

Expected: compile failure for the missing canonical payload and authority methods.

- [ ] **Step 3: Add canonical payloads to the existing RuntimeCore credential owner**

Add the following shapes to `EBrainControlPlaneCore.swift`; do not create `BASCapabilityGrantCore.swift`:

```swift
public enum BASCapabilityPhase: String, Codable, Sendable, Hashable {
    case queryOrGeneration
    case resultReleaseOrCommit
    case effect
}

public struct BASCapabilityGrant: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let issuer: String
    public let subject: String
    public let audiences: [String]
    public let operation: String
    public let resource: String
    public let requestDigest: String
    public let inputDigest: String
    public let phase: BASCapabilityPhase
    public let neuralExecutionContractDigest: String?
    public let outputSchemaDigest: String
    public let outputConstraintsDigest: String
    public let projectionPolicyDigest: String
    public let resultArtifactID: BASArtifactID?
    public let effectRequestDigest: String?
    public let purpose: String
    public let scopeBinding: BASArtifactScopeBinding
    public let turnOperationRef: BASTurnOperationRef?
    public let turnBranchRef: BASTurnBranchRef?
    public let workspaceReadSnapshotArtifactID: BASArtifactID?
    public let generationVectorArtifactID: BASArtifactID
    public let logicalEpoch: UInt64
    public let bootSessionID: String?
    public let durableWarrantEpoch: UInt64?
    public let notBeforeLogicalTime: UInt64
    public let monotonicDeadlineNanos: UInt64?
    public let durableExpiryWallClockMillis: UInt64?
    public let maxUses: UInt32
    public let maxFanout: UInt32
    public let maxBoundaryInstances: UInt32
    public let maxBytes: UInt64
    public let maxTokens: UInt64
    public let maxCostMicrounits: UInt64
    public let authorizationBasisArtifactID: BASArtifactID
    public let revocationGeneration: UInt64
    public let nonce: String
}

public enum BASCapabilityUseTerminalState: String, Codable, Sendable, Hashable { case spent }

public struct BASCapabilityUseReceipt: BASSchemaVersioned, Codable, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"
    public let schemaVersion: String
    public let grantArtifactID: BASArtifactID
    public let boundSubjectArtifactID: BASArtifactID
    public let requestID: String
    public let requestBindingDigest: String
    public let useOrdinal: UInt32
    public let remainingUses: UInt32
    public let remainingBytes: UInt64
    public let remainingCostMicrounits: UInt64
    public let terminalState: BASCapabilityUseTerminalState
}
```

Define `BASCapabilityValidationState`, `BASCapabilityValidationDecision`, and pure `BASCapabilityGrantRules`; do not define a capability-specific issuance result, claim result, reservation permit, request envelope, template, or authority. Canonical grant bytes include every field, normalize audiences into unique raw-UTF8 order, and require exactly one lifetime form. An executable grant requires `.attempt(attemptRefArtifactID)`, the exact `turnOperationRef`, its reopened/equality-checked Attempt lineage, the exact generation-vector artifact, and the workspace snapshot whenever state-dependent. `turnBranchRef` is required for Provider, stream, publication, and effect boundary authority and must have the same root and expected kind; a purely internal semantic invocation leaves it nil and is instead bound by exact request/input/output artifacts. A durable-warrant-scoped payload has no executable turn/branch reference and may only authorize K4 to derive a narrower Attempt grant. Query/generation binds request/input/output/projection; release/commit binds exact `resultArtifactID`; effect binds the exact effect digest and typed effect `turnBranchRef`. Legacy `operationID`/`turnID`/`branchID` values are derived wire projections outside the canonical grant and are decoded back to the typed values before use. Neither canonical payload contains its own artifact ID, self digest, signature, store locator, or mutable counter. `authorizationBasisArtifactID` is lineage, not holder-driven delegation. `BASCapabilityUseReceipt` may reference the consumed grant and bound subject, but its own Artifact Mesh ID exists only in the enclosing store record/receipt.

- [ ] **Step 4: Extend only `BASSovereignTokenAuthority` with mutable use state**

Make the existing actor the sole implementation of these operations:

```swift
public func issueCapability(
    _ grant: BASCapabilityGrant,
    requestID: String
) async throws -> BASArtifactStoreReceipt

public func reserveCapability(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws

public func claimCapability(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws -> BASArtifactStoreReceipt

public func lookupCapabilityUseReceipt(
    grantArtifactID: BASArtifactID,
    boundSubjectArtifactID: BASArtifactID,
    requestID: String
) async throws -> BASArtifactStoreReceipt?
```

`issueCapability` validates/canonicalizes the supplied nonce-bearing grant, stores the unsigned grant, and stores its Ed25519 child attestation; both use the actor's injected Artifact Mesh port and the exact ordinary `put(identityCore:headUpdate:)` path. The returned `BASArtifactStoreReceipt.body.artifactID` is the grant ID; there is no `BASCapabilityGrantIssuanceReceipt`. `reserveCapability` holds a non-transferable actor-owned reservation after reopening the bound subject artifact and validating every grant binding; it returns no receipt. `claimCapability` revalidates every binding/epoch/deadline/revocation field, atomically transitions that reservation to spent, stores the sole canonical `BASCapabilityUseReceipt` payload with ordinary `put`, and returns that ordinary store receipt. `lookupCapabilityUseReceipt` recovers the same store receipt after a lost reply. The Sovereign release/effects plan may make the reservation/spend state durable, but must not rename these methods or create another issuance/claim receipt. Preserve current commit-token/warrant methods byte-for-byte and add any Artifact Mesh dependency through an additive initializer overload.

- [ ] **Step 5: Run capability and legacy sovereign regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASCapabilityGrantAttenuationTests|BASSovereignTokenAuthorityTests|BASSovereignDeterministicCommitTokenTests|BASSovereignCommitTokenEd25519Tests'
```

Expected: PASS; identical retries converge on one stored use-receipt artifact, a conflicting claim cannot spend again, and existing credentials remain compatible.

- [ ] **Step 6: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift \
  BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCapabilityGrantAttenuationTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSovereignTokenAuthorityTests.swift
git commit -m "feat: extend sovereign authority with capability grants"
```

### Task 4: Extend the Existing Layer Actor Mesh with LayerCell Membranes

**Reuse Decision**

- **Class:** E for membranes/collaboration payloads; A for `BASLayerActorMechanismAdapter`.
- **Existing unique owner:** `BASLayerActor`, `BASLayerReferenceActor`, `BASLayerCascadeRunner`, `BAS14LayerMeshMap/Assembler`, `BASLayerSlice`, and `BASLayerKillSwitchState`.
- **Missing invariant:** pure ingress/core/egress validation, bounded join/remand payloads, and the self-ID-free control-loop envelope/witness/terminal values that let the existing K3 budget owner govern RSI without a fifth ring or manager.
- **Why Create is allowed:** no production file is created. LayerCell, adapter, collaboration payloads, budget fields, and kill generation extend their current owners in place; only tests are new.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerActor.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerSliceAndMLHead.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerKillSwitchID.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerCascadeRunner.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLayerCellMembraneTests.swift`

**Interfaces:**
- Consumes: an existing `BASLayerActor`, immutable membrane context projected by outer composition from the exact existing Artifact Mesh/TokenAuthority owners, `BASLayerSlice`, and `BASLayerKillSwitchState`; RuntimeCore does not import BASSovereign, persist output, mint/claim capability, or introduce a LayerCell-specific mechanism/capability protocol.
- Produces: pure `BASSemanticLayerCore`, low-entropy LayerCell ingress/egress aliases, a stateless one-call actor adapter, and self-ID-free join/remand plus `BASControlLoopEnvelopePayload`, `BASControlLoopProgressWitnessPayload`, and `BASControlLoopTerminalReceiptPayload` values. Outer composition alone attaches the already-stored output and capability-use receipt artifact IDs by calling a pure egress projector; none of these values spends a lease or schedules work.

- [ ] **Step 1: Write RED membrane and no-second-owner tests**

```swift
func testStaleKillGenerationStopsBeforeCoreAndActor() async {
    let core = CountingLayerCore()
    let actor = CountingLayerActor()
    let composition = fixtureOuterComposition(
        cell: BASLayerCell(core: core, actor: actor)
    )
    await XCTAssertThrowsErrorAsync {
        try await composition.process(staleIngress(), context: currentMembraneContext())
    }
    let coreCallCount = await core.callCount
    let actorCallCount = await actor.callCount
    XCTAssertEqual(coreCallCount, 0)
    XCTAssertEqual(actorCallCount, 0)
}

func testCoreRequestReachesExistingActorExactlyOnce() async throws {
    let actor = CountingLayerActor()
    let result = try await fixtureOuterComposition(
        cell: BASLayerCell(core: InvokingLayerCore(), actor: actor)
    ).process(validIngress(), context: currentMembraneContext())
    let actorCallCount = await actor.callCount
    XCTAssertTrue(result.success)
    XCTAssertEqual(actorCallCount, 1)
    XCTAssertNotNil(result.body.capabilityUseReceiptArtifactID)
}

func testRemandSliceIsProjectionAndExactLoopEvidenceIsReferenced() throws {
    let remand = fixtureRemand(
        remainingBudget: fixtureLayerSlice(),
        budgetLeaseArtifactID: fixtureBudgetLeaseArtifactID(),
        priorBudgetUseReceiptArtifactID: fixtureBudgetUseReceiptArtifactID(),
        progressWitnessArtifactID: fixtureProgressWitnessArtifactID(),
        controlLoopEnvelopeArtifactID: fixtureLoopEnvelopeArtifactID()
    )
    let data = try JSONEncoder().encode(remand)
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
    XCTAssertTrue([
        "remainingBudget", "budgetLeaseArtifactID",
        "priorBudgetUseReceiptArtifactID", "progressWitnessArtifactID",
        "controlLoopEnvelopeArtifactID",
    ].allSatisfy(keys.contains))
    XCTAssertTrue(keys.isDisjoint(with: [
        "remandID", "artifactID", "currentBudgetUseReceiptArtifactID",
        "spentTokens", "spentBytes", "mutableVisitedDigests",
    ]))
    XCTAssertEqual(remand.remainingBudget.layerID, .l7)
}

func testLayerCellIsAStatelessPureMembraneWithOneMechanismCrossing() throws {
    let source = try sourceSlice(
        path: "Sources/BASRuntimeCore/BASLayerActor.swift",
        from: "public struct BASLayerCell<",
        through: "// END BASLayerCell"
    )
    for forbidden in [
        "private var", "actorRegistry", "scheduler", "retry",
        "cache", "SQLite", "FileManager", "URLSession", "rank(",
        "advanceKill", "attenuated(", "validateCapability", "mint",
    ] {
        XCTAssertFalse(source.contains(forbidden), forbidden)
    }
    XCTAssertEqual(source.components(separatedBy: "mechanism.invoke(").count - 1, 1)
    XCTAssertEqual(source.components(separatedBy: "await").count - 1, 1)
}
```

Add the bounded `// BEGIN BASLayerCell` / `// END BASLayerCell` source markers used by this test. Add a source-boundary assertion that no `BASLayerBudget`, `BASKillEpoch`, new actor registry, second mechanism protocol, second layer identity enum, or second physical-kernel identity enum exists. The source slice must contain only immutable dependencies and pure value validation/projection; it may not own policy, authorization, storage, scheduling, retry, cache, rank, budget, kill, effect, or mutable mechanism state.

- [ ] **Step 2: Run RED**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter BASLayerCellMembraneTests
```

Expected: compile failure for the missing membrane extensions.

- [ ] **Step 3: Extend budget and kill owners first**

Add `bytesAllowance`, `costMicrounitsAllowance`, `branchAllowance`, `remandRoundAllowance`, and `hopAllowance` to `BASLayerSlice`, all with source-compatible initializer/decode defaults. Add a pure `attenuated(...) throws -> BASLayerSlice`; this value owner alone derives a narrower child ceiling, but the returned slice is only an equality-checked display/planning projection. It never reserves, spends, recovers, or proves remaining budget; those facts come only from `BASBudgetLeaseControlPort` and `BASBudgetUseReceipt`.

Add `monotonicGeneration`, `activationSequence`, `authority`, and `signatureAttestationArtifactID: BASArtifactID?` to `BASLayerKillSwitchState`, also with additive defaults. LayerCell compares this state directly; do not introduce `BASLayerBudget` or `BASKillEpoch`.

- [ ] **Step 4: Add LayerCell as low-entropy aliases on the actor owner**

Make `BASLayerActorInput`/`BASLayerActorOutput` conditionally `Equatable`/`Hashable`, then add:

```swift
public protocol BASSemanticLayerCore: Sendable {
    associatedtype Input: Codable & Sendable & Hashable
    associatedtype Output: Codable & Sendable & Hashable
    static var layerID: BASSemanticLayerID { get }
    func evaluate(_ input: Input) throws -> BASLayerCoreDecision<Output>
    func resume(_ actorOutput: BASLayerActorOutput, input: Input) throws -> Output
}

public enum BASLayerCoreDecision<Output: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    case emit(Output)
    case invoke(BASLayerActorInput)
    case remand(BASRemandArtifact)
    case refuse(BASRefusalArtifact)
}

public struct BASLayerCellIngressBody<Input: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    public let inputArtifactID: BASArtifactID
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let payload: Input
    public let grantArtifactID: BASArtifactID
    public let turnOperationRef: BASTurnOperationRef
    public let causalTurnBranchRef: BASTurnBranchRef?
    public let logicalEpoch: UInt64
    public let snapshotRootArtifactID: BASArtifactID
    public let killGeneration: UInt64
    public let revocationGeneration: UInt64
    public let monotonicDeadlineNanos: UInt64
    public let budget: BASLayerSlice
}

public typealias BASLayerCellIngress<Input: Codable & Sendable & Hashable> =
    BASFrameEnvelope<BASLayerCellIngressBody<Input>>

public struct BASLayerCellEgressBody<Output: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    public let output: Output?
    public let outputArtifactID: BASArtifactID?
    public let capabilityUseReceiptArtifactID: BASArtifactID?
    public let orderedParentArtifactIDs: [BASArtifactID]
    public let terminalState: BASControlRingTerminalState
}

public typealias BASLayerCellEgress<Output: Codable & Sendable & Hashable> =
    BASResult<BASLayerCellEgressBody<Output>>

public struct BASLayerActorMechanismAdapter<Actor: BASLayerActor>: Sendable {
    public let actor: Actor
    public func invoke(
        _ request: BASLayerActorInput,
        turnOperationRef: BASTurnOperationRef
    ) async throws -> BASLayerActorOutput {
        let legacyTurnID = try turnOperationRef.canonicalLegacyProjection()
        guard request.turnID == legacyTurnID else {
            throw BASLayerActorError.internalFailure(layerID: request.layerID, message: "actor input identity mismatch")
        }
        let output = try await actor.process(input: request)
        guard output.layerID == request.layerID, output.turnID == legacyTurnID else {
            throw BASLayerActorError.internalFailure(layerID: request.layerID, message: "actor identity mismatch")
        }
        return output
    }
}
```

`BASLayerCell<Core, Actor>` is a stateless pure membrane: it stores only immutable `Core` and `BASLayerActorMechanismAdapter` values, transforms ingress/core/egress deterministically, and crosses `await` exactly once at `mechanism.invoke`. The ingress carries the canonical turn root and, only when one exists, a typed causal external-boundary branch whose parent is equality-checked; its Artifact-Mesh input/parents remain the semantic-DAG identity. Existing actor `turnID` is a compatibility projection constructed by the membrane from `turnOperationRef.canonicalLegacyProjection()` and equality-checked on both sides of the one actor call; callers and the semantic core cannot supply it as independent authority. No raw `branchID` enters LayerCell. It owns no policy result, mutable collection, clock, actor registry, scheduler, retry, cache, persistence, ranking, budget subtraction, kill advancement, effect, authorization, grant, reservation, or receipt state. Its surface is a pure `prepare` validation/evaluation, a `revalidateAndInvoke` method whose sole side effect is that one adapter call, a pure `resume`, and a pure `makeEgress` projector. Outer production composition calls the existing TokenAuthority reserve immediately before `revalidateAndInvoke`, then calls the existing claim and ordinary Artifact Mesh output `put` immediately afterward; it supplies the two resulting receipt artifact IDs to `makeEgress`. LayerCell exact-compares those immutable inputs but may not call, wrap, retry, cache, or reinterpret either owner. It never calls another layer or mechanism actor and never invents a LayerCell-specific port, actor, store, or authority.

- [ ] **Step 5: Add self-ID-free collaboration and bounded-RSI payloads to the existing cascade owner**

Add `BASCollaborationVerb`, `BASControlRingTerminalState`, `BASJoinArtifact`, `BASRemandArtifact`, and `BASRefusalArtifact` to `BASLayerCascadeRunner.swift`. `BASControlRingTerminalState` is exactly `converged`, `degradedWithCoverage`, `deferred`, `rejected`, `needsConfirmation`, or `indeterminateNeedsReconciliation`. Join/remand use `BASArtifactID` for parent/input/conflict/evidence references; their `BASLayerSlice` is only a display projection and they additionally reference the exact installed lease, prior use receipt, progress witness, and loop envelope Artifact IDs. They contain no join/remand ID, self digest, spend counter, or mutable resolution set. Represent cancellation as `typealias BASCancellationSignal = BASFrameEnvelope<BASCancellationBody>` and backpressure as `typealias BASBackpressureReceipt = BASResult<BASBackpressureBody>`.

In that same existing cascade/value owner, add these ordinary Artifact Mesh payloads without a new file, actor, port, store, scheduler, or manager:

- `BASControlLoopEnvelopePayload`: exact `BASTurnOperationRef`, Attempt/generation vector, one `BASControlRingID`, a bounded deterministic **non-authoritative** `logicalInvocationKey`, optional parent-invocation Artifact ID, semantic snapshot Artifact ID, capability-grant and `BASBudgetLeasePayload` Artifact IDs, optional prior `BASBudgetUseReceipt` and required-for-child progress-witness Artifact IDs, visited state/decision digest-set commitment, declared remand edge, depth/branch bounds, monotonic deadline, and policy/deletion/boot epochs. It carries no current invocation/self Artifact ID, current receipt, remaining counter, terminal state, or executable closure. Construction is strictly envelope put → invocation put referencing the returned envelope ID → K3 budget-use claim binding both IDs → mechanism → node/terminal receipt; placeholder identity, mutation, and backfill are forbidden.
- `BASControlLoopProgressWitnessPayload`: exact phase-specific kind (`newRequiredLaneCoverage`, `strictDeficiencyReduction`, `strictConflictReduction`, `resourceSafeTransition`, or `effectSagaRankAdvance`), prior/current evidence Artifact IDs, prior/current canonical measures, and verifier receipt. Its validating initializer requires a strict monotonic improvement under the selected kind; prose novelty, sampling variation, and a new Artifact ID are not progress.
- `BASControlLoopTerminalReceiptPayload`: root/invocation/envelope, current budget-use receipt, terminal state, exact termination reason (`convergedVerified`, `coverageBound`, `resourceDeferred`, `policyRejected`, `confirmationRequired`, `cycleDetected`, `budgetExhausted`, `noProgress`, `staleEpoch`, `illegalRemand`, or `effectReconciliationIndeterminate`), final state/decision digest, and ordered evidence IDs. The initializer validates allowed state/reason pairs. Only `converged + convergedVerified` is adoptable; all other pairs are proposal/remand/disclosure evidence only.

Register all three once in the existing schema-governance registry. Runtime may create a new immutable child invocation only after reopening a newly won/recovered K3 budget-use receipt and a phase-valid witness; the concrete invocation graph remains a DAG even when ring **types** alternate. A repeated digest, A↔B backlink, missing/false witness, exhausted claim, stale epoch, illegal edge/depth/branch/deadline, or post-effect attempt to regenerate becomes a terminal receipt and reaches zero LayerCell, Provider, K4, state, effect, or release calls.

- [ ] **Step 6: Run LayerCell and legacy mesh regressions**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate \
  --filter 'BASLayerCellMembraneTests|BASLayerActorTests|BASLayerReferenceActorTests|BASLayerCascadeRunnerTests|BAS14LayerMeshMapTests|BAS14LayerMeshAssemblerTests|BASLayerKillSwitchIDTests'
```

Expected: PASS; stale input reaches neither core nor actor, the only mechanism call is the existing actor path, loop values round-trip without self identity/counters, invalid state/reason pairs and false witnesses fail, and no non-`convergedVerified` receipt can be projected as adoptable.

- [ ] **Step 7: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerActor.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerSliceAndMLHead.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerKillSwitchID.swift \
  BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerCascadeRunner.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLayerCellMembraneTests.swift
git commit -m "feat: extend layer actor mesh with membranes"
```

### Task 5: Close Schema, Purity, and Anti-Duplication Gates

**Reuse Decision**

- **Class:** E/R.
- **Existing unique owner:** `EBrainSchemaGovernanceRegistry`, package target graph, existing actor/canonical/sovereign test suites.
- **Missing invariant:** one executable gate proving the new persisted contracts are governed and no parallel owners slipped in.
- **Why Create is allowed:** only tests and a source-analysis script are new; both are verification assets with no runtime authority.

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArchitectureContractClosureTests.swift`
- Create: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/scripts/check-layercore-purity.sh`

**Interfaces:**
- Consumes: persisted schema versions and source/package dependency graph.
- Produces: a deterministic closure test and shell gate for purity and duplicate-authority rejection, plus one private cycle-free `pinnedEntry` registry helper for an explicitly allowlisted governed type whose owner cannot be imported into BASAdmin without either a package cycle or a forbidden downward dependency from governance into a leaf execution/effect target.

- [ ] **Step 1: Register only persisted payloads and write closure tests**

```swift
func testReuseFirstContractSetIsClosed() {
    let semantic: BASSemanticLayerID = .sovereign
    let cognitive: BASCognitiveLayer = semantic
    XCTAssertEqual(cognitive.rawValue, "L14")
    XCTAssertEqual(BASMotherboardKernel.allCases.map(\.architectureID).sorted(), ["K1", "K2", "K3", "K4"])
    XCTAssertEqual(BASArtifactMeshRecord.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASArtifactAttestationPayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASCapabilityGrant.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASCapabilityUseReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASBudgetLeasePayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASBudgetUseReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderBranchPolicy.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderBranchChainPayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASTurnOperationPayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderObservedReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderBranchAllocationReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderExecutionClaimReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderEventHeadSealReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderTerminalSourceReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASProviderVisibilityReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASBoundaryAnchorReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASBoundaryArmReceipt.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASControlLoopEnvelopePayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASControlLoopProgressWitnessPayload.currentSchemaVersion, "1.0.0")
    XCTAssertEqual(BASControlLoopTerminalReceiptPayload.currentSchemaVersion, "1.0.0")
}
```

Register `BASArtifactMeshRecord`, `BASArtifactAttestationPayload`, `BASCapabilityGrant`, `BASCapabilityUseReceipt`, `BASTurnOperationPayload`, `BASBudgetLeasePayload`, `BASBudgetUseReceipt`, `BASProviderBranchPolicy`, `BASProviderBranchChainPayload`, `BASProviderObservedReceipt`, `BASProviderBranchAllocationReceipt`, `BASProviderExecutionClaimReceipt`, `BASProviderEventHeadSealReceipt`, `BASProviderTerminalSourceReceipt`, `BASProviderVisibilityReceipt`, `BASBoundaryAnchorReceipt`, `BASBoundaryArmReceipt`, `BASJoinArtifact`, `BASRemandArtifact`, `BASRefusalArtifact`, `BASControlLoopEnvelopePayload`, `BASControlLoopProgressWitnessPayload`, and `BASControlLoopTerminalReceiptPayload`. Do not register in-memory request, state/outcome, context, lineage entry, adapter, reservation, port, or generic wrapper aliases. Every listed payload uses `BASGovernedArtifactPayloadCodec`; the exact object ID is its Swift type basename and the exact test IDs are `schema.<Type>.current`, `schema.<Type>.backward_v1`, and `schema.<Type>.future_rejection`.

Keep the existing generic `entry(_:versionedType:tests:learnability:)` for schema types already visible to BASAdmin. Add exactly one private overload with a deliberately different name:

```swift
private static func pinnedEntry(
    _ objectID: String,
    currentVersion: String,
    tests: [String],
    learnability: BASLearnabilityClass = .semiLearnable
) -> BASSchemaGovernanceEntry
```

`pinnedEntry` constructs the same `BASSchemaGovernanceEntry` but accepts no metatype. It is legal only when importing the owner target would either create a package cycle (for example, a BASHostKit-owned payload while BASHostKit already depends on BASAdmin) or invert the dependency rule by making BASAdmin import a leaf execution/effect target such as `BASOrgan` or `BASEffectBroker`; convenience and compile time alone are insufficient. Every use requires an owner-target parity test that compares the registered version to `OwnerType.currentSchemaVersion`, exact-one object-ID and test-ID assertions, current/backward fixture decode through `BASGovernedArtifactPayloadCodec`, unknown-version rejection, and a `swift package dump-package` cycle/direction gate. It is never a substitute for adding `BASSchemaVersioned`, never accepts a runtime-selected version, and cannot create a second registry. Add a registry source test with one reviewed object-ID allowlist covering only the cross-plan pinned types, including `BASPersistedOrganDescriptorPayload` and `BASPersistedToolResultPayload` plus the Runtime plan's explicitly enumerated persisted result/audit payloads; RuntimeCore-visible dispatch/effect receipts use normal metatype entries. The source test rejects any unlisted call and a second string-only helper.

- [ ] **Step 2: Add the executable purity and anti-duplication script**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-/Users/changgeng/Project/Project06/Project06}"
PACKAGE="$ROOT/BehavioralAISubstrate"
SRC="$PACKAGE/Sources"

cd "$ROOT"
python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
swift package --package-path "$PACKAGE" dump-package >/dev/null

if rg -n 'import (SQLite3|Security|CoreML|MLX|Metal|SwiftUI)|URLSession|FileManager|Keychain' \
  "$SRC" --glob '*LayerCore.swift'; then
  echo 'FAIL: pure LayerCore references mechanism/I-O APIs' >&2
  exit 1
fi

if rg -n 'public (struct|enum|actor|class) (BASSemanticLayerID|BASPhysicalKernelID|BASLayerBudget|BASKillEpoch|BASArtifactAttestationRecord|BASLayerIdentity|BASKernelIdentity)|actor BASLayerCell|protocol BASLayerCellMechanism|BASLayerActorRegistry|BASArtifactReadVersion|func putAttestation|BASCapabilityValidationPort|validateAndConsume' \
  "$SRC" --glob '*.swift'; then
  echo 'FAIL: duplicate identity/architecture/budget/kill/attestation owner found' >&2
  exit 1
fi

for duplicate in \
  BASRuntimeCore/BASSemanticArchitectureIDs.swift \
  BASRuntimeCore/BASArtifactStorePort.swift \
  BASRuntimeCore/BASCapabilityGrantCore.swift \
  BASRuntimeCore/BASLayerCellCore.swift \
  BASRuntimeCore/BASCollaborationArtifacts.swift \
  BASRuntimeCore/BASLayerActorMechanismAdapter.swift; do
  if [[ -e "$SRC/$duplicate" ]]; then
    echo "FAIL: parallel production facade exists: $duplicate" >&2
    exit 1
  fi
done

rg -q 'typealias BASSemanticLayerID = BASCognitiveLayer' \
  "$SRC/BASRuntimeCore/BASObservationReconciliationCore.swift"
rg -q 'typealias BASPhysicalKernelID = BASMotherboardKernel' \
  "$SRC/BASRuntimeCore/BASMotherboardArchitecture.swift"
rg -q 'typealias BASArtifactStoreReceipt = BASResult' \
  "$SRC/BASRuntimeCore/BASArtifactMeshCore.swift"
rg -q 'public struct BASCapabilityUseReceipt' \
  "$SRC/BASRuntimeCore/EBrainControlPlaneCore.swift"
if rg -n 'BASCapabilityGrantIssuanceReceipt|BASCapabilityClaimReceipt|issueCapabilityGrant|claimAndSpendCapabilityUse' \
  "$SRC" --glob '*.swift'; then
  echo 'FAIL: capability-specific issuance/claim receipt or drifted authority API found' >&2
  exit 1
fi
rg -q 'public typealias BASLayerCellIngress' "$SRC/BASRuntimeCore/BASLayerActor.swift"
rg -q 'BASFrameEnvelope<BASLayerCellIngressBody' "$SRC/BASRuntimeCore/BASLayerActor.swift"
rg -q 'public protocol BASBudgetLeaseControlPort' "$SRC/BASRuntimeCore/BASEventLog.swift"
for symbol in \
  BASBudgetLeasePayload \
  BASBudgetUseReceipt \
  BASControlLoopEnvelopePayload \
  BASControlLoopProgressWitnessPayload \
  BASControlLoopTerminalReceiptPayload; do
  test "$(rg -n "^public (struct|enum) ${symbol}\\b" "$SRC" --glob '*.swift' | wc -l | tr -d ' ')" = "1"
done
if rg -n 'RSIManager|ControlLoopManager|BudgetLeaseManager|actor BASBudgetLease|class BASBudgetLease|private var .*loopRemainingBudget|var .*controlLoopVisited.*Set' \
  "$SRC" --glob '*.swift'; then
  echo 'FAIL: parallel RSI/budget mutable owner found' >&2
  exit 1
fi
test "$(rg -n '^public typealias BASSemanticLayerID = BASCognitiveLayer$' \
  "$SRC/BASRuntimeCore/BASObservationReconciliationCore.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -n '^public typealias BASPhysicalKernelID = BASMotherboardKernel$' \
  "$SRC/BASRuntimeCore/BASMotherboardArchitecture.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -n '^public protocol BASArtifactStorePort: AnyObject, Sendable' "$SRC" --glob '*.swift' | wc -l | tr -d ' ')" = "1"

LAYERCELL_SOURCE="$(sed -n '/\/\/ BEGIN BASLayerCell$/,/\/\/ END BASLayerCell$/p' \
  "$SRC/BASRuntimeCore/BASLayerActor.swift")"
[[ -n "$LAYERCELL_SOURCE" ]]
test "$(rg -o 'await mechanism\.invoke\(' <<<"$LAYERCELL_SOURCE" | wc -l | tr -d ' ')" = "1"
if rg -n 'private var|actorRegistry|scheduler|retry|cache|SQLite|FileManager|URLSession|\.put\(|reserveCapability|claimCapability|mint|rank\(|advanceKill|attenuated\(' \
  <<<"$LAYERCELL_SOURCE"; then
  echo 'FAIL: LayerCell is not a stateless pure membrane' >&2
  exit 1
fi
```

- [ ] **Step 3: Run closure three times**

```bash
ROOT=/Users/changgeng/Project/Project06/Project06
cd "$ROOT"
python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
for run in 1 2 3; do
  bash "$ROOT/BehavioralAISubstrate/scripts/check-layercore-purity.sh" "$ROOT" || exit 1
  swift test --package-path "$ROOT/BehavioralAISubstrate" \
    --filter 'BASArchitectureContractClosureTests|BASEBrainSchemaGovernanceRegistryTests|BASSemanticArchitectureIDTests|BASArtifactMeshTests|BASArtifactStoreTests|BASCapabilityGrantAttenuationTests|BASTurnOperationRefTests|BASLayerCellMembraneTests' || exit 1
done
```

Expected: the exact shared OwnerLedger/CreateGate and three consecutive closure runs PASS; the source gate finds one canonical identity alias per dimension, one Artifact Mesh port, and a stateless LayerCell membrane with exactly one existing actor-mechanism crossing.

- [ ] **Step 4: Commit**

```bash
git add BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift \
  BehavioralAISubstrate/scripts/check-layercore-purity.sh \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArchitectureContractClosureTests.swift
git commit -m "test: enforce reuse-first contract closure"
```

## Completion Gate

Implementation is complete only when all of the following are true:

- Every package and device target has an owned iOS `27.0` deployment floor, the iOS-27 source/package/project gate passes, and no target or fixture lowers it through an inherited or alternate setting.
- Before every RED step and again at closure, the sole machine gate passes with the exact command `python3 scripts/check_qinao_owner_ledger.py --root "$ROOT" --ledger "$ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"`. The ledger and validator have no production target membership and no second ledger/CreateGate exists.
- Every production Create matches one existing ledger `M` row, its exact allowlisted path, and all eight Create-Proof fields. An existing `R/E/A` responsibility cannot become `M` through a renamed file, wrapper, alias, adapter, or compatibility projection.
- The single `artifact.mesh` M row allowlists exactly the co-owned RuntimeCore contract, BASMemory SQLite adapter, and migration-024 workspace-relative paths. All three candidate manifests pass independently; package-relative `Sources/...`, an unlisted sidecar/schema, or treating the migration as an owner is rejected.
- `BASCognitiveLayer`/`BASSemanticLayerID` remain the one 14-layer identity owner, `BASMotherboardKernel`/`BASPhysicalKernelID` remain the one four-kernel identity owner, and the existing layer actor, collaboration budget, kill generation, capability, Artifact Mesh, canonical-framing, event-order, and context owners each remain unique. No second identity enum, registry, actor, protocol, persistence path, or policy owner exists.
- LayerCell is a stateless pure membrane over immutable ingress/core/egress values. It owns no policy, authorization, persistence, cache, scheduling, retry, ranking, budget, kill, effect, receipt, or mutable mechanism state; its sole await/mechanism crossing delegates exactly once to the existing `BASLayerActor` through `BASLayerActorMechanismAdapter`.
- One `BASBudgetLeasePayload` is bound into `BASTurnOperationPayload`; `BASLayerSlice` is an equality-checked ceiling projection only. `BASBudgetLeaseControlPort` has exactly claim/state operations and is implemented by the same K3 storage as the EventLog/Provider port. Concurrent or recovered use returns one byte-equal `BASBudgetUseReceipt`; no envelope, layer, Runtime, Qinao, or Provider counter can spend.
- The three self-ID-free bounded-RSI payloads are schema-registered exactly once. A child envelope requires a prior use receipt, new digest, valid phase-specific progress witness, legal edge, and stricter depth/branch/deadline evidence. Invalid/repeated/cyclic/exhausted/stale paths produce only typed terminal evidence, and only `converged + convergedVerified` is adoptable. No fifth ring, `RSIManager`, loop scheduler/store, or mutable visited-set owner exists.
