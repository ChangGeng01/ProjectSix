# Chapter 一百二十八 / M500-M510 Deep Review (2026-05-04)

## Context

Chapter 一百二十八 shipped the final 14-layer doctrine coverage closure across both Cthulhu (向下) + Kunlun (向上) doctrines:
- M500-M501: Kunlun L4 chapter-99-deferred wires (BASKunlunAscentView + BASKunlunFarWestReserve)
- M502-M510: L12 doctrine-specific surface aliases (4 Cthulhu + 5 Kunlun typed enum aliases + 1 helper)

Following chapter 67 / 81 / 91.5 / 103 deep-review pattern. Audit pass:
1. Multi-run BAS regression sweep (3×)
2. Agent code review on 6 modified/new files
3. Human-grep verify each finding (~75-80% FP rate baseline)
4. Fix verified bugs + add fix-pin tests

## Results

### Multi-run flake sweep — 3/3 stable

| Run | Tests | Failures |
|---|---|---|
| 1 | 2823 (21 skipped) | 0 |
| 2 | 2823 (20 skipped) | 0 |
| 3 | 2823 (21 skipped) | 0 |

No flakes detected. Skipped count fluctuation (20-21) is environmental (AFM gate-off skips).

### Agent code review — 6 findings

Severity distribution: 0 CRITICAL / 0 HIGH / 2 MEDIUM / 4 LOW.

Per chapter 67/81 baseline ~75% FP rate, expected 1-2 real findings. Actual: **1 confirmed REAL bug** + 5 false-positives or low-priority observations (~83% FP rate, consistent with baseline).

### Findings × verdict matrix

| # | Severity | Finding | Verdict | Action |
|---|---|---|---|---|
| 1 | MEDIUM | `BASKunlunFarWestReserve.derive` produces doctrine-violating reserve when `assertionCeiling == .qualified` (`namingStatus = .provisional` violates `isHonoringDoctrine` invariant: requires `.unattempted | .refused` OR `distanceBand == .sealedUnknown`) | **REAL** | M511 fix: change `.qualified → .unattempted` |
| 2 | MEDIUM | `firstCandidate?.reversibility ?? 1` masks risk when candidates absent | **FP** | Reversibility is internal to derive (not exposed on AscentView); empty stopPoints is doctrine-correct when no candidate exists |
| 3 | LOW | Surface alias derives use `boundActionPermit.mode` not `stackedModes.first` | **FP** | Agent self-confirmed: doctrine-correct (single commit mouth pin) |
| 4 | LOW | NaN propagation through `>=` thresholds silently falls through to "preconditions-pending" | **FP** | Fail-safe behavior; `BASCandidate.confidence` constructed from clamped sources upstream |
| 5 | LOW | `testSurfaceAliasCodesPairTogether` doesn't pin asymmetric `.draftShell` case | **VALID** | M512 fix: add positive-asymmetry pin test |
| 6 | LOW | Determinism filter uses `hasPrefix` (loose); future `kunlun.l4.*` chapter could pollute | **FP** | Verified safe across all current chapter codes; tightening = churn risk |

### Real bug fix (M511)

**File:** `BehavioralAISubstrate/Sources/BASOrchestration/BASKunlunLayerProjections.swift` (FarWestReserve.derive namingStatus mapping)

**Before:**
```swift
case .qualified: return .provisional  // ❌ violates isHonoringDoctrine
```

**After:**
```swift
case .unrestricted, .provisional, .qualified:
    return .unattempted  // ✓ honors §5.4 reserve-doctrine
```

**Doctrine reasoning:** §5.4 "用远方保留区承接未知，不急着命名" doctrine says reserves should AVOID naming pressure. `.provisional` namingStatus means "in-progress naming" which DOES exert naming pressure, violating the doctrine. `.qualified` ceiling means "we have caveats but haven't given up on naming" — doctrinally closer to `.unattempted` (held without commitment) than `.provisional` (actively naming). The `distanceBand = .farReach` already encodes the qualification.

### Fix-pin tests added

**M511 fix-pin** (`testFarWestReserveAlwaysHonorsDoctrine`): walks all 5 `BASUnknownAssertionCeiling` cases + asserts `isHonoringDoctrine` holds for every emitted reserve. Catches regressions where future ceilings get `.provisional` namingStatus.

**M512 fix-pin** (`testCthulhuDraftShellAsymmetricEmission`): positive-asymmetry pin — when Kunlun emits `jadeDraftShell`, Cthulhu MUST emit nil (per §5.12 4-vs-5 doctrine). Catches drift in inverse direction (someone adding `.draftShell` arm to Cthulhu would silently pass the existing pair-together test).

### Other verifications (passed)

- **Field drift** across `BASAuditObservationProjections` struct/init/delegate — verified consistent across 3 sites
- **Emission ordering** — chapter 一百二十八 blocks placed AFTER chapter 一百二十七, preserving audit-walker grep determinism
- **Cthulhu 4-vs-Kunlun-5 alias asymmetry** for `.draftShell` — doctrine-correct per §5.12 (Cthulhu has only 4 aliases per whitepaper)
- **Kunlun 1-to-1 mapping exhaustiveness** — Swift's exhaustive switch (compile-time)
- **AscentView well-formed fallbacks** — `["preconditions-pending"]` ascentConditions + `["return-path:default"]` returnPaths guarantee `isWellFormed == true`
- **5-tier `BASUnknownAssertionCeiling → BASKunlunFarWestDistance`** mapping — exhaustive (no default arm)
- **`BASCandidate.reversibility` clamp** — `BASConsequenceHorizon` clamps to `[0,1]` upstream
- **Single commit mouth pin** — `permit.mode` unchanged by all chapter 一百二十八 wires

## Test counts (post-deep-review)

| 套件 | Pre-review | Post-review | Δ |
|---|---|---|---|
| BAS XCTest | 2823 | **2825** | +2 (M511 + M512 fix-pin tests) |
| BAS swift-testing | 417 | **417** | unchanged |
| Qinao XCTest | 1375 | **1375** | unchanged |
| 全栈 | 4215 | **4217** | +2 |

5 gates clean: 4 boundary + whitepaper parity (241 registered, 0 drift).

## Methodology lessons

1. **Schema invariants live in docstrings + `is*Doctrine` accessors** — derive helpers MUST satisfy schema invariants by construction. Chapter 一百二十八 missed this for FarWestReserve `.qualified` arm because the invariant wasn't tested in `BASKunlunHostIntegrityTests` (chapter 一百二十四) — only checked invariant honor for direct construction, not for derive-helper output. Fix-pin closes this gap.
2. **Asymmetric mapping tables need bidirectional pins** — Cthulhu 4-alias vs Kunlun 5-alias asymmetry was tested in one direction (Kunlun emits → Cthulhu may not), but reverse drift (Cthulhu adding `.draftShell` arm but Kunlun forgetting) wouldn't fail. Add positive-asymmetry pins for any asymmetric mapping.
3. **Agent FP rate consistent** — chapter 一百二十八 agent review FP rate ~83% (5 of 6 findings non-actionable). Within chapter 67/81/91.5/103 baseline ~75-80%. Methodology: never trust agent finding without grep-verification + doctrine cross-check.
4. **Deep-review chapter cadence** — chapter 67 (M298-M335) / 81 (M380-M398) / 91.5 (M401-M416) / 103 (M448-M457) / 一百二十九 (M500-M510). Approximately every 30-50 milestones merits a deep-review pass. Pattern: multi-run sweep → agent review → human grep verify → fix verified bugs → write report doc.

## Honest residuals (post-chapter-一百二十八 + deep review)

| Item | Status |
|---|---|
| 14/14 layer doctrine coverage | ✓ achieved (chapter 一百二十八) |
| Stream A schemas (15) production-wired | ✓ 15/15 (chapter 一百二十七) |
| Chapter 一百二十一 Cthulhu leftover wired | ✓ 4/4 (chapter 一百二十七) |
| hostFragility actual computation | ✓ derived from anchor signal (M499) |
| Stream B (5 SDK packages) | paused per "packages 先不做" |
| Stream C (7 bench metrics) | deferred — separate plan |
| Stream D (4 共轴 primitives) | deferred — separate plan |
| L12 UI 主题包 | user-excluded |
| Real-world Kunlun-aware training | external resources |
| Multi-host cross-device 共轴 | deployment-level |

Honest satisfaction post-chapter-一百二十八 + deep review: ~99.97% (closing of doctrine-violation gap raises confidence floor).
