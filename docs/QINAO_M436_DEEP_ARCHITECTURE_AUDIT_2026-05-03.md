# M436 Deep Architecture Audit — 14-Layer Reconciliation Closure

**Date**: 2026-05-03
**Chapter**: 一百四 (M436)
**Trigger**: User instruction "deep review 底层 架构 缺陷 bug 打通闭环 14层 全 运转 极致" — strict architectural audit + close-the-loop on every layer.

## Audit findings (pre-M436 state)

A general-purpose code-review agent surveyed the substrate and quantified per-layer health:

| Severity | Count | Description |
|---|---|---|
| **CRITICAL** | 1 | `BASObservationReconciliationVerdictEngine.evaluate(...)` was a public library function invoked **only from tests**. Production `runTurn` never called it. The audit ledger therefore had **zero visibility** into "did all expected layers participate this turn." |
| **HIGH** | 1 | 7 of 12 cognitive observation bundles emitted **zero** `signalRefs` codes despite being derived per turn. Layers L1 / L2 / L3 / L5 / L6 / L7 / L12 were "running but unread" — audit walkers had no way to grep "did this layer participate." |
| MEDIUM | 1 | L8 hippocampal bundle was also silent (different from the L1-L7/L12 group only by happenstance). |
| **总评** | — | **36% extreme** (5/14 layers load-bearing through the audit ledger) / **57% running but not maxed** (8/14 layers derived but never read). |

The "极致" (load-bearing through audit) layers pre-M436 were:
- L9 dreamLoop (M299 frontier code)
- L10 triSelfTribunal (M300 tribunal code)
- L11 riskClimate (already in audit reasonCodes)
- L13 evolutionFurnace (M305 lifecycle code)
- L14 sovereign (the ledger itself)

## Patch shape

Two surgical patches lift the % from 36 → ≈100:

### Patch A — `EBrainRuntimeCoordinator.swift`

1. **New L3 `coverageSummary` projection** in `BASObservationCoverageProjections.swift`. Pre-M436 the L3 `BASThoughtFoldObservationBundle` was the *only* cognitive bundle without a `.coverageSummary` projection — the verdict engine therefore systematically emitted a spurious `.missingLayer(.thoughtFold)` finding even on healthy turns. The new projection lands a `.thoughtFold`-tagged summary so L3 can participate.

2. **New static helper `deriveLayerReconciliationReport(...)`** that composes a `BASObservationReconciliationReport` from all 13 cognitive bundles in scope (L1 through L13) and runs `BASObservationReconciliationVerdictEngine.evaluate(...)` against it.

   The L9 candidate-observation bundle is constructed by the materialization compiler with non-canonical keys (`turnID = "l9.turn.step-N"`, `sessionID = decomposeRef`) — different from the canonical `derivedTurnID` / `derivedSessionID` pair the rest of the substrate uses. The helper normalizes the L9 summary's keys so `BASObservationReconciliationReport.appending` accepts it (otherwise the append silently no-ops on key mismatch and L9 is never observed).

3. **Wired into `runTurn`** at the audit-build seam — the helper is called just before `buildSovereignAuditEntry`, and both the verdict and the report are fed into the audit-entry builder.

### Patch B — `EBrainRuntimeCoordinator+SovereignCommit.swift`

`buildSovereignAuditEntry` gained 9 new optional parameters:

- `layerReconciliationVerdict` + `layerReconciliationReport` — emit:
  - `reconciliation.severity:<clean|advisory|halt>`
  - `reconciliation.findings:<count>`
  - `reconciliation.observed:<sorted+layer+rawValues>`
  - `reconciliation.missing:<layer>` (one per missing-layer finding)
  - `reconciliation.partial:<layer>` (one per missing-core-coverage finding)
  - `reconciliation.overspend:<observed>:<ceiling>` (when budget overrun)

- 7 silent-bundle parameters (`presenceObservationBundle`, `decompositionObservationBundle`, `softHandObservationBundle`, `leaseLifeObservationBundle`, `hostConstitutionObservationBundle`, `thoughtFoldObservationBundle`, `neuralOrganObservationBundle`) + L8 `hippocampalMemoryObservationBundle` — each emits:
  - `<layer>.coverage:<full|partial|empty>` (one per turn)
  - `<layer>.observations:<N>` (one per turn)

Every emission is conditional on the bundle being non-nil (legacy / test callers that don't plumb the bundle simply elide the code).

### Doctrine pin: audit-only emission

Critical guarantee: M436 emits **metadata only**. None of the new codes:
- escalate the sovereign verdict (`verdict.verdictLevel` is unchanged)
- mutate the action permit (`actionPermit.mode` is unchanged)
- change hash chain semantics (signature simply digests a longer ordered list)
- introduce decision-influence

The reconciliation verdict is purely an audit-walker observability gain. If the verdict says `.advisory` because some layer missed core coverage, the substrate's existing risk + permit + sovereign-verdict synthesis path remains the sole decision-maker.

## Tests pinning the wires

`M436LayerReconciliationConsumptionTests.swift` (7 tests, all pass):

1. `testReconciliationSeverityIsEmitted` — pin one severity code per turn from the canonical clean/advisory/halt set.
2. `testReconciliationFindingsCountIsEmitted` — pin one parseable integer count code per turn.
3. `testReconciliationObservedListsCognitiveLayers` — pin all **13 cognitive layers** observed on a healthy fixture turn (L1 through L13). This is the "极致" gauge: 13/13 means every cognitive layer participates in the reconciliation report.
4. `testSevenSilentBundlesNowEmitCoverageCodes` — pin 8 layers (L1/L2/L3/L5/L6/L7/L8/L12) all emit one `<layer>.coverage:<status>` + one `<layer>.observations:<N>` code each.
5. `testLegacyCodesStillPresentAlongsideM436Codes` — pin backward-compat: M298 risk/permit/fold + M299 frontier + M300 tribunal codes all still appear.
6. `testReconciliationIsAuditOnlyNoVerdictEscalation` — doctrine pin: reconciliation never escalates verdict to `.rollback` / `.deadStop`.
7. `testReconciliationCodesAreDeterministic` — pin determinism across two identical fixture runs.

## Test baseline

| Suite | Pre-M436 | Post-M436 | Δ |
|---|---|---|---|
| BAS XCTest | 2461 | **2468** | +7 (M436 test file) |
| BAS swift-testing | 417 | **417** | unchanged |
| Qinao XCTest gate-off | 1375 | **1375** | unchanged |
| 全栈 | 3853 | **3860** | +7 |

0 failures / 4/4 boundary checks clean.

## "极致" measurement (post-M436)

| Layer | Pre-M436 audit-walker visibility | Post-M436 |
|---|---|---|
| L1 leaseLife | 0 codes | `leaseLife.coverage:` + `leaseLife.observations:` + `reconciliation.observed:L1` |
| L2 neuralOrgan | 0 | `neuralOrgan.coverage:` + `neuralOrgan.observations:` + `reconciliation.observed:L2` |
| L3 thoughtFold | 0 | `thoughtFold.coverage:` + `thoughtFold.observations:` + `reconciliation.observed:L3` |
| L4 worldPrior | already via `worldPrior.*` (M59) | **+** `reconciliation.observed:L4` |
| L5 hostConstitution | 0 | `hostConstitution.coverage:` + `hostConstitution.observations:` + `reconciliation.observed:L5` |
| L6 presenceEye | 0 | `presence.coverage:` + `presence.observations:` + `reconciliation.observed:L6` |
| L7 mirrorBlade | 0 | `decomposition.coverage:` + `decomposition.observations:` + `reconciliation.observed:L7` |
| L8 hippocampalWell | 0 | `hippocampal.coverage:` + `hippocampal.observations:` + `reconciliation.observed:L8` |
| L9 dreamLoop | `frontier.*` (M299) | **+** `reconciliation.observed:L9` |
| L10 triSelfTribunal | `tribunal.*` (M300) | **+** `reconciliation.observed:L10` |
| L11 riskClimate | `risk:` (M298) | **+** `reconciliation.observed:L11` |
| L12 gentleHand | 0 | `softHand.coverage:` + `softHand.observations:` + `reconciliation.observed:L12` |
| L13 evolutionFurnace | `lifecycle.*` (M305) | **+** `reconciliation.observed:L13` |
| L14 sovereign | the ledger itself | the ledger itself |

Pre-M436 "极致" rate: 5/14 = **36%**.
Post-M436 "极致" rate: 14/14 = **100%**.
Pre-M436 "running but unread" rate: 8/14 = 57%.
Post-M436 "running but unread" rate: 0/14 = **0%**.

Plus a meta-layer reconciliation verdict (`reconciliation.severity:` / `.findings:` / `.observed:` / `.missing:` / `.partial:` / `.overspend:`) that aggregates the per-layer signals into a single audit-walker grep target.

## Red lines / invariants regression

| Red line / invariant | M436 |
|---|---|
| #1 先醒再答 | ✓ (no L1 wake / breath path changes) |
| #2 神经不掌权 | ✓ (verdict / permit synthesis unchanged) |
| #3 私有经验不进权重 | ✓ (no L13 / L8 / L5 writes) |
| audit hash chain | ✓ (signalRefs is additive metadata, signature digests longer list deterministically) |
| 单提交口 | ✓ (single permit / single warrant unchanged) |
| Cthulhu 红线 7 (watcher hint) | ✓ (no decision influence from new codes) |
| Cthulhu 红线 8 (anchor wins) | ✓ (no escalation path mutation) |
| Cthulhu 红线 9 (seals have audit ref) | ✓ (audit-only emission) |
| Cthulhu 红线 10 (主品牌不默认恐怖) | ✓ (BAS-internal reason codes only) |
| Kunlun 8 红线 | ✓ (no Kunlun decision-path mutation) |
| 4 boundary checks | maintained green |

## Status

- M436 ships in chapter 一百四
- CRITICAL #1 closed: reconciliation verdict engine now invoked from production runTurn
- HIGH #2 closed: 8 silent observation bundles now emit typed audit reasonCodes
- L3 thoughtFold gap closed: new coverageSummary projection completes the 14-layer matrix
- 7 new tests pin the wiring + doctrine + backward-compat
- "极致" rate: 36% → 100%
- Doctrine: audit-only emission, zero decision influence

The audit identified a structurally important gap: a verdict library that production never invoked. M436 is the surgical close — small, additive, well-tested, and respects every existing red line.
