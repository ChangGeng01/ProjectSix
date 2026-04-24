# Qinao Runtime SDK — Developer Guide

> Consolidated reference for anyone writing production code
> against the Qinao Runtime SDK. Covers the whitepaper's three
> invariants, the 14-layer cognitive architecture, the
> `sendSession` main-chain flow, the value types that appear on
> the public API, and the testing recipes shipped post-M155.

---

## 1. Three invariants (the brand floor)

Every Qinao SDK call path upholds three hard invariants. Any
code change that would violate them is rejected.

### Invariant #1 — 先醒再答 (Wake before answer)

Every turn starts with **L1 PowerClock** arbitrating "should we
be awake, and how deep?" before **L2 neural organ** generates
anything. The `sendSession` flow enforces this: the L1 routed
budget is computed in Phase 1, before the L14 audit in Phase 2,
before any layer starts emitting observations.

Code path: `QinaoRuntime.prepareBudgetForTurn(_:)` →
`QinaoLifecycle.applyLiveThermalGuardLevel(to:)`.

### Invariant #2 — 神经不直接掌权 (Neurons do not rule)

Every tool side-effect requires three signatures:

1. **`QinaoRiskGate.ActionPermit`** — L11 risk gate approval.
2. **`QinaoSovereignControlPlane.Warrant`** — L14 sovereign
   warrant.
3. **`SnapshotContinuityProof`** — L14-issued proof that the
   session's snapshot chain is intact.

If any of the three is missing, expired, or bound to a different
intent digest, `QinaoRuntime.execute(toolName:payload:intent:
signatures:)` refuses to call the host-supplied executor.

### Invariant #3 — 宿主私有经验不进权重 (Host-private experience
  does not enter weights)

The **L13 shadow-trial pipeline** records proposed learning
artifacts (memory writes / host changes / rule candidates) in
the L14 audit ledger but **cannot auto-commit**. Every commit
requires an explicit `QinaoHost.approve(candidateID:)` call on
the host-side candidate pipeline.

Pinned by M151 tests: a passing shadow trial leaves the host's
`activeVersion` unchanged and the deterministic adapter's
traceID byte-equal before/after.

---

## 2. 14-layer per-turn auto-stream matrix

Every healthy `sendSession` call emits observation summaries for
a subset of these 14 layers into the L14 audit ledger. The
subset is determined by which `TurnInputs` fields the caller
populates.

| Layer | Gate                                   | Source type                      | Milestone |
|-------|----------------------------------------|----------------------------------|-----------|
| L14   | Always                                 | (internal — L14 audit)           | M9        |
| L3    | Unconditional                          | synthesized from observations    | M122      |
| L5    | Unconditional                          | `QinaoHost.currentConstitution()`| M122      |
| L1    | `lifecycle` + `plannedBudget`          | `BASBudgetFrame`                 | M121      |
| L6    | `contextFrame`                         | `BASContextFrame`                | M134      |
| L7    | `decomposeFrame`                       | `BASDecomposeFrame`              | M135      |
| L8    | `memoryBundle`                         | `BASMemoryBundle`                | M136      |
| L4    | `thoughtFrame`                         | `BASThoughtFrame`                | M139      |
| L10   | `thoughtFrame`                         | `BASThoughtFrame`                | M137      |
| L11   | `thoughtFrame`                         | `BASThoughtFrame`                | M137      |
| L12   | `thoughtFrame` + `renderedOutput`      | both                             | M141      |
| L13   | `updateTickets`                        | `[BASUpdateTicket]`              | M138      |
| L2    | `neuralOrganMap`                       | `BASNeuralOrganMap`              | M140      |
| L9    | `candidateFrontier`                    | `BASCandidateFrontier`           | M142      |

Pattern: one `TurnInputs` field per layer gate. Passing a non-nil
field activates that layer's per-turn observation summary.

---

## 3. `sendSession` flow — 10 phases

`QinaoRuntime.sendSession(_ inputs: TurnInputs)` runs the
following phases in order. Phase markers are in the source (M153
phase-map refactor).

| Phase | Purpose                                          |
|-------|--------------------------------------------------|
| 0     | Pre-flight halt check                            |
| 1     | Lifecycle-routed budget (M70)                    |
| 2     | L14 sovereign audit (M9 `auditTurn`)             |
| 3     | L1..L13 auto-stream observation summaries        |
| 4     | Coverage reconciliation (M45 cross-layer verdict)|
| 5     | Sovereign frame aggregator (M123 + M144 + M147)  |
| 6     | Single surface-decision compute (M131 dedup)     |
| 7     | Render frame aggregator (M127 + M144 + M148)     |
| 8     | Halt branches — fail-closed on parity / coverage / severity |
| 9     | Healthy return: lifecycle record + TurnOutcome   |

Phase 3 uses the private `AutoInjectPipeline` struct (M154) to
collapse 14 per-layer inject blocks into uniform one-line calls.

---

## 4. Public value types

### `TurnInputs` (M152)

One parameter to `sendSession`. See
`docs/QINAO_API_MIGRATION_GUIDE.md` for the full field map.

### `TurnOutcome`

Returned by healthy + auto-halt paths. Fields:

- `audit: AuditReport` — severity / parity / reasonCodes /
  auditRef.
- `coverage: CoverageReading` — M45 cross-layer verdict.
- `sessionHalted: Bool` — `true` on rollback/deadStop severity
  paths that return rather than throw.
- `routedBudget: BASBudgetFrame?` — the live-thermal routed
  budget this turn ran under.
- `turnRecorded: BASLeaseLifeCoordinator.TurnRecorded?` —
  lifecycle accumulator advance (healthy path only).
- `surfaceDecision: BASSurfaceDecision` — non-optional since
  M145. Maps directly to `QinaoUI.ComponentID` via
  `.surface.rawValue`.
- `residue: TurnResidue?` — the M124 cross-surface integrity
  bundle (coverage + observation bundle + sovereign frame +
  render frame).

### `TurnResidue` (M124 + M131)

Four parallel per-turn storages bundled into one value. Every
healthy `sendSession` outcome carries a complete residue.

- `coverageReading: CoverageReading?`
- `observationBundle: BASObservationReconciliationReport?` —
  deduplicated per-layer coverage summaries.
- `sovereignFrame: BASSovereignFrame?` — L14 §5.1 aggregator,
  all 13 optional ref fields have production paths.
- `renderFrame: BASRenderFrame?` — L12 render aggregator, all
  12 optional ref fields have production paths.

Check integrity via `sovereign.verifyTurnResidue(residue)` (pure,
O(findings), safe to call every frame) or
`sovereign.verifyTurnResidueStrong(residue)` (adds ledger
chain-integrity check, I/O-bound, use at session boundaries).

### `ChainBreakRecoveryPolicy` (M133 + M143)

Four whitepaper L14 §5 recovery actions:

```swift
.haltOnly
.quarantineAffectedSessions(reason: String)
.rotateSegmentOnBreak(reason: String)
.rollbackToLastClean(reason: String, hostVersionID: String)
```

Invoke via
`sovereign.autoHealChainIntegrity(policy:affectedSessionIDs:)` →
returns structured `ChainBreakRecoveryOutcome` with action tag +
halted session list + rotated segment IDs + rollback plan IDs.

### `SurfaceRetryPolicy` (M126)

Configurable retry windows for delay-packet severities.

```swift
SurfaceRetryPolicy(
    throttleSeconds: 30,
    shadowLockSeconds: 60,
    toolCutSeconds: 120,
    memoryFreezeSeconds: 180,
    quarantineSeconds: 300)
```

Retry window stretches with thermal pressure
(nominal 1.0× / watch 1.25× / throttle 1.5× / emergency 2.0×).

---

## 5. Testing recipes

### Minimal test body (post-M155)

```swift
func testMyThing() async throws {
    let fx = await QinaoTestFixture.make()
    let obs = fx.observations(turnID: "turn.1")
    let outcome = try await fx.runtime.sendSession(
        .init(observations: obs, coordinatorSeverity: .pass))
    XCTAssertFalse(outcome.sessionHalted)
}
```

### Custom fixture

```swift
let fx = await QinaoTestFixture.make(
    hostID: "host.specialcase",
    activeVersion: "host.v3",
    withLifecycle: true,
    renderFrameCapacity: 16)
```

### Wiring a specific layer

```swift
let outcome = try await fx.runtime.sendSession(
    .init(observations: obs, coordinatorSeverity: .pass)
        .with { inputs in
            inputs.contextFrame = BASContextFrame(...)
            inputs.decomposeFrame = BASDecomposeFrame(...)
            inputs.thoughtFrame = BASThoughtFrame(...)
        })
```

### Verifying cross-surface integrity

```swift
let residue = try XCTUnwrap(outcome.residue)
let verification = await fx.sovereign
    .verifyTurnResidue(residue)
XCTAssertTrue(verification.isValid)
XCTAssertTrue(verification.findings.isEmpty)
```

### Stronger verification (chain integrity)

```swift
let verification = await fx.sovereign
    .verifyTurnResidueStrong(residue)  // I/O-bound
// .findings now includes .chainIntegrityBroken if chain breaks.
```

### Self-heal policy

```swift
let outcome = await fx.sovereign
    .autoHealChainIntegrity(
        policy: .rollbackToLastClean(
            reason: "suspected-corruption",
            hostVersionID: "host.v1"),
        affectedSessionIDs: ["sess.live"])
// outcome.rollbackPlanIDs: [String] — plan IDs cached in the
// coordinator's planCache. Host must explicitly execute them.
```

---

## 6. Extension points

### Adding a new observation layer

(Example: hypothetical L15)

1. Define the layer type in `BASRuntimeCore/
   BASObservationReconciliationCore.swift` — add
   `case myLayer = "L15"` to `BASCognitiveLayer`.
2. Ship a `BAS<X>ObservationBundle` + `.derive(...)` helper in
   `BASOrchestration`.
3. Add a `coverageSummary` computed property on the bundle
   following the pattern in
   `BASObservationCoverageProjections.swift`.
4. Add an optional field to `QinaoRuntime.TurnInputs` (e.g.
   `myLayerSource: MyLayerSource?`).
5. Add an `if let x = inputs.myLayerSource` block in Phase 3
   that derives the bundle and calls
   `pipeline.inject(bundle.coverageSummary, "L15")`.
6. Write a test — copy
   `QinaoRuntimeL4AutoStreamTests.swift` as template.

### Adding a new sovereign frame / render frame ref

1. The aggregator's optional field already exists in BAS
   (these were M117/M119 shipped).
2. In Phase 5 (sovereign frame) or Phase 7 (render frame) of
   `sendSession`, add a `let myRef: String?` computed from the
   relevant input or source.
3. Pass it into the frame's init.
4. Write a test asserting the ref is populated/nil per source
   gate.

### Adding a new self-heal action

1. Extend `ChainBreakRecoveryPolicy` enum with the new case.
2. Extend `ChainBreakRecoveryOutcome` with any new structured
   output field.
3. Add a case in `runRecoveryActions(policy:...)` that performs
   the action and records outputs.
4. Write a test (see
   `QinaoRuntimeM143RollbackPolicyTests.swift` as template).

---

## 7. Honesty board — current state

The SDK is **architecturally complete within the whitepaper
scope** but has explicit gaps outside it. See `docs/
BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md` for per-milestone detail.

### What's at production quality

- All 14 L1-L14 layers stream per-turn observation summaries
  into the L14 audit ledger.
- All 4 L14 §5 sovereign actions (halt/quarantine/rotate/
  rollback) are shipped.
- `BASSovereignFrame` fields 13/13 populated when sources are
  passed.
- `BASRenderFrame` fields 12/12 populated when sources are
  passed.
- Invariant #3 hard-pinned at lifecycle seam.
- 596 tests across QinaoRuntimeSDK, 1434 tests across
  BehavioralAISubstrate, all boundary gates green.

### What's explicitly scope-out

- **Real-device thermal** — iOS BGTaskScheduler.shared wakeup
  timing on physical hardware. M149 pins the structure via
  `.system()` factory + platform-gated compile paths; the
  empirical "does iOS wake us at the requested time" tail is
  iOS integration-test territory.
- **True model differentiation for L2 Scout/Core** — M150 pins
  the preset contract + digest shape; actually differentiated
  outputs from two separate models is CoreML / MLX / Apple
  FoundationModels infrastructure.
- **Multi-tenancy / observability (OTel) / compliance
  (SOC2 / HIPAA / GDPR)** — not in whitepaper scope.
- **Real distillation pipeline** — M151 proves the safety
  fence; actual gradient-based or knowledge-distillation
  training is ML infrastructure.

### What is "shadow-fixed" but not real-proofed

- **Synthetic refs as `"prefix.session.turn"` strings** — they
  collide if `sessionID` has dots. Production would want UUID or
  HMAC-derived refs. Currently "cheap and works", not
  "hardened".
- **invariant #3 pin at BAS coordinator layer** — not OS layer,
  not model-weight layer. A rogue actor writing directly to
  memory could bypass. Testing surface assumption; not
  cryptographic guarantee.

---

## 8. Key files

| File                                                                 | Purpose                                |
|----------------------------------------------------------------------|----------------------------------------|
| `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`            | `sendSession` main path, phase 0-9   |
| `QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift`        | L14 control plane + TurnResidue verify |
| `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoLifecycle.swift`          | L1 lease-life bridge                   |
| `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/Shared/QinaoTestFixture.swift` | Shared test fixture factory         |
| `docs/QINAO_API_MIGRATION_GUIDE.md`                                  | Per-milestone API break history        |
| `docs/BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md`                          | Per-milestone technical detail         |
| `docs/EBRAIN_13L_COMPLETION_MATRIX.md`                               | Per-layer completion tracking          |
| `docs/QINAO_HONESTY_BOARD.md`                                        | Scope-aware completeness tracking      |

---

## 9. Session-boundary operator checklist

Hosts running a Qinao-backed service should schedule these at
session boundaries (not every turn):

- [ ] `sovereign.verifyTurnResidueStrong(residue)` on the last
      turn — catches any chain integrity break before writing
      session-close metadata.
- [ ] `sovereign.autoHealChainIntegrity(policy: .rotate...)` if
      the session was long (segment rotation bounds replay
      cost).
- [ ] Export session's observation bundles via
      `sovereign.observationBundles(forSession:)` if they need
      archival.

These are orthogonal to the per-turn flow. The per-turn flow is
fail-closed self-contained.
