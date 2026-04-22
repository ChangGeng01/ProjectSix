# Qinao Runtime SDK · 绮脑运行时 SDK

> The carrying protocol between a human host and a second brain.

Qinao is a runtime for building applications that think *on behalf of* a
human host without ever pretending to *be* the human host. The SDK
sits in a deliberate position:

```
Human Host  ───►  Qinao SDK  ───►  Second Brain  ───►  Neural Network
```

Four layers, four update frequencies, four different accountability
stories. The SDK is the contract surface that makes the other three
layers safe to compose.

---

## Three invariants

Each invariant is an **interface contract**, not an advertisement. The
SDK will refuse at the boundary if any one is violated.

### 1 · Wake before you answer — 先醒再答

Every `QinaoSessionRequest` is arbitrated by the lifecycle kernel before
generation begins. The brain can refuse to wake, wake partially, wake
for a bounded budget, or wake in maintenance-only mode. A request does
not reach the candidate pipeline until the kernel has issued a run
lease with a thermal guard, a budget frame, and a maintenance window.

### 2 · The network never rules — 神经不直接掌权

A neural network can produce *intent* — a draft, a tool invocation, a
write-memory proposal. It can never produce *permission*. Every
side-effecting call the SDK executes must carry a three-signature
bundle:

| Signature               | Source                | Meaning                                    |
| ----------------------- | --------------------- | ------------------------------------------ |
| ActionPermit            | Risk gate (`QinaoRisk`) | "the risk shape is acceptable"            |
| SovereignWarrant        | Sovereign control plane (`QinaoSovereign`) | "the control plane authorises this intent" |
| SnapshotContinuityProof | Snapshot ark          | "the world this action commits into is the world the permit was issued against" |

Any call missing any of the three is refused at `QinaoRuntime.execute`
— it never reaches the substrate. Digest-mismatch, session-mismatch,
and TTL-expired signatures are all refused.

### 3 · Host secrets stay out of base weights — 宿主私有经验不进基础权重

Host experience has three legal landing zones:

1. **Host constitution** — typed, versioned, deletable, rollback-able.
2. **Session memory** — hot / warm / cold tiers with per-scope cascade
   delete and governance-gated admission.
3. **Update tickets** — shadow-previewed, sovereign-adjudicated, and
   — only after approval — released for offline distillation.

The neural network's base weights are never updated from inside a
session. Deletion is real deletion; rollback is real rollback.

---

## Five integrity properties

The invariants compose into five independently-auditable properties. A
demo for each lives under
`Tests/QinaoRuntimeSDKTests/PropertyDemos/*` and runs in CI.

| Property                      | What is demonstrated                                   |
| ----------------------------- | ------------------------------------------------------ |
| **Wake and sleep — 会醒会停** | The lifecycle kernel can reach every state from dormant through deep-loop through clean reboot, including the lockdown path. |
| **World and host — 懂世界也懂宿主** | World priors (causal templates, domain bridges, counterfactual seeds) compose with the typed host constitution. Host overrides follow the bedrock rule: host cannot rewrite a world axiom, only demote or reject. |
| **Think, not spin — 会想不自转** | The dream loop plus the internal tribunal produce a candidate frontier, a compare panel, and — when any candidate crosses the critique threshold — a guardian branch. Determinism is contract-pinned. |
| **Protect, not take over — 会保护不接管** | The risk gate returns a four-way decision (allow / delay / replace / block) with stable reason codes; the soft-hand surfaces render the decision without performing it. The host is the only actor who can commit. |
| **Grow, not wildly — 会成长不乱长** | Host changes flow through submit → preview → approve → commit; rejection, freeze, rollback, and cascade delete are all first-class. Projection parity is proven by a round-trip equality test. |

---

## Seven public modules

```
          QinaoRuntime
                │
      ┌─────────┼──────────┬──────────┐
      ▼         ▼          ▼          ▼
   QinaoHost QinaoMemory QinaoLoop  QinaoRisk
      │         │          │          │
      └────┬────┴──────────┴──────────┘
           ▼
      QinaoSovereign
           │
           ▼
        QinaoUI
```

| Module           | Role                                                         |
| ---------------- | ------------------------------------------------------------ |
| `QinaoRuntime`   | Session lifecycle, three-signature gate, tool execution.     |
| `QinaoHost`      | Host constitution: submit / preview / approve / reject / rollback / freeze / thaw. |
| `QinaoMemory`    | Session memory: admit / recall / forget across hot·warm·cold tiers. |
| `QinaoLoop`      | Candidate frontier, compare panel, guardian branch.          |
| `QinaoRisk`      | Risk signals → four-way assessment with stable reason codes. |
| `QinaoSovereign` | Control plane: rollback plan, warrant issuance, session halt. |
| `QinaoUI`        | Five soft-hand SwiftUI surfaces (compare panel · draft shell · delay packet · boundary script · silent stub). |

Every public type in every module is `Sendable`. Every public error is
typed and carries stable reason codes. Nothing in a module's public
surface names the internal machinery that implements it.

---

## Minimal use

```swift
import QinaoRuntime
import QinaoSovereign
import QinaoHost
import QinaoMemory
import QinaoLoop
import QinaoRisk

// 1. Bootstrap the control plane — the Configuration only carries
// plain value types (Data, TimeInterval, @Sendable () -> Date).
let config = QinaoSovereignControlPlane.Configuration(
    signingSecret: mySigningSecret,
    warrantTTLSeconds: 30,
    now: { Date() })
let (sovereign, substrate) = QinaoSovereignControlPlane.bootstrap(
    configuration: config)

// 2. Compose the risk gate and loop.
let risk = QinaoRiskGate(permitTTLSeconds: 30,
                         defaultDelaySeconds: 60,
                         now: { Date() })
let loop = QinaoLoop()

// 3. Submit candidates; read the frontier and guardian branch.
try await loop.submit(sessionID: "s1", candidates: [
    QinaoLoop.CandidateInput(
        candidateID: "c1", title: "Take a walk",
        actionSummary: "step outside for 10 minutes",
        expectedBenefit: 0.8, expectedCost: 0.1,
        reversibility: 0.95, confidence: 0.7)
])
let frontier = try await loop.candidateFrontier(sessionID: "s1")

// 4. When a candidate is chosen, collect the three signatures.
let permit = try await risk.requestActionPermit(for: intent)
let warrant = try await sovereign.issueWarrant(for: intent)
let proof = try sovereign.continuityProof(for: intent)

// 5. Execute through the gate — missing or mismatched signatures
// are refused at the boundary.
try await runtime.execute(
    toolName: "calendar.add_event",
    payload: payload,
    intent: intent,
    signatures: .init(permit: permit, warrant: warrant, proof: proof))
```

---

## Contract discipline

- Every public type is a `struct` or `actor`; no exposed classes.
- Every public function is either pure, async, or `throws` with a
  typed error enum.
- Every public error carries stable reason codes suitable for host UI
  copy keys.
- The SDK forbids — by CI scripts — the leakage of internal
  vocabulary into the public API, the README, or trace output.

See `HONESTY_BOARD.md` for the live ledger of what every promise on
this page is currently backed by in code, tests, and CI.

---

## Milestone ledger — what backs each promise today

Every row below names the runtime file and test suite that proves the
promise. All listed tests are part of the default `swift test` run on
`QinaoRuntimeSDK` and are kept green on every push.

| Promise | Backed by |
| --- | --- |
| **Wake before you answer — L1 lifecycle** | `QinaoRuntime` session bootstrap + `QinaoBGMaintenanceBridge` platform wake-up (`QinaoBGMaintenanceBridgeTests`, `QinaoRuntimeGateTests`) |
| **Three-signature gate on every side-effect** | `QinaoRuntime.execute` (`QinaoRuntimeGateTests`) |
| **Second-authority audit on every turn** | `QinaoRuntime.sendSession` main-path audit (`QinaoRuntimeSessionTests`) |
| **Pre-halted session refuses to run** | `QinaoRuntime.sendSession` pre-flight (`QinaoRuntimeSessionTests.testPreHaltedSessionRefusesBeforeAuditing`) |
| **Fail-closed on parity mismatch** | `QinaoRuntime.sendSession` parity branch (`QinaoRuntimeSessionTests.testLaxerParityFailsClosedAndMarksHalted`) |
| **Severity-driven auto-halt (rollback / deadStop)** | `QinaoRuntime.sendSession` severity branch (`QinaoRuntimeSessionTests.testDeadStopSeverityAutoHalts`) |
| **Host decides on quarantine severity** | `QinaoRuntime.sendSession` no-autohalt branch (`QinaoRuntimeSessionTests.testQuarantineSeverityDoesNotAutoHalt`) |
| **Coverage reading on every turn** | `QinaoRuntime.sendSession` records a structured `CoverageReading` before any halt branch; queryable via `sovereign.coverageReading(sessionID:turnID:)` (`QinaoRuntimeCoverageTests.testCleanTurnRecordsCoverageAndIsQueryable`) |
| **Budget-ceiling breach halts fail-closed** | `TurnError.coverageHalt` + `reason = "coverage-halt"` when clamped per-turn cost exceeds ceiling (`QinaoRuntimeCoverageTests.testLowBudgetCeilingTripsCoverageHalt`) |
| **Halt path preserves coverage audit row** | Coverage computed before parity / severity branches so the ledger retains a reading on fail-closed exits (`QinaoRuntimeCoverageTests.testDeadStopHaltPathStillCarriesCoverage`) |
| **Expected-layer expansion is auditable** | Caller-specified `expectedCoverageLayerIDs` surfaces silent layers as `.missingLayer` findings (`QinaoRuntimeCoverageTests.testAdditionalExpectedLayersProduceMissingFindings`) |
| **Cross-session isolation** | Coverage / halt / audit state is keyed per `(sessionID, turnID)` and does not leak across sessions (`QinaoRuntimeCrossSessionTests`) |
| **World priors fold into the risk gate** | `QinaoRiskGate.requestActionPermit(…worldContext:worldEndpoint:)` (`QinaoRiskWorldPriorTests`) |
| **Unknown world-template is a typed error** | `RiskError.unknownWorldTemplate` (`QinaoRiskWorldPriorTests`) |
| **Informed consent forces `.replace`** | `QinaoRiskGate` consent branch (`QinaoRiskWorldPriorTests`) |
| **Low-evidence irreversible forces `.delay`** | `QinaoRiskGate` evidence branch (`QinaoRiskWorldPriorTests`) |
| **Host secrets stay out of base weights** | `QinaoLearningExportBundle` triple gate: scrubbed + privacySafe + sovereignSafe (`QinaoLearningExportTests`) |
| **Host constitution: submit / preview / approve / rollback** | `QinaoHost` candidate pipeline + projection parity (`QinaoHostTests`, `WorldAndHostDemo.testHostCandidateFlowsSubmitPreviewApproveRollback`) |
| **Cascade delete across memory tiers** | `QinaoMemory.forget(sensitivity:)` cascade (`WorldAndHostDemo.testSensitivityCascadeForgetIsTyped`) |
| **Candidate frontier + compare panel + guardian branch** | `QinaoLoop` (`QinaoLoopTests`, `ThinkNotSpinDemo`) |
| **Control plane: rollback / halt / release** | `QinaoSovereignControlPlane` (`QinaoSovereignTests`) |
| **Five soft-hand surfaces (answer / compare / delay / block / replace)** | `QinaoUI` (`QinaoUITests`) |

---

## License

© Qinao · All rights reserved.
