# Engineering Health Debt Log

**Created**: 2026-05-04 (chapter 一百三十二)
**Trigger**: User audit identified honesty board's systematic blind spot — doctrine purity audited extensively, engineering hygiene never audited.

## Why this file exists

`docs/QINAO_HONESTY_BOARD.md` rigorously self-audits **doctrine compliance** (red lines, invariants, schema parity, audit emission shape). It has 0 grep matches for terms like "god file", "5347", "5K 行", "800 line", "CI/CD", "runbook", "telemetry". This is a culture bias — the project audits what it values (doctrine) and is silent on what it doesn't visibly value (basic engineering hygiene).

This file is the corrective. It tracks **engineering health debt**: structural and operational shortcomings that are independent of doctrine correctness. Items here are NOT bugs (the code works); they are debts that compound interest on every future change.

This is NOT a fix list. Most items here are not surgical — they are weeks-to-months of work and may be the wrong priority for a pre-production codebase with 0 users. The point is **visibility**.

---

## Section A — Structural debt (codebase shape)

### A.1 God-file concentration — 4 first-party files over 5,000 lines (verified 2026-05-04)

| File | Lines | Type | Comment |
|---|---|---|---|
| `QinaoRuntimeSDK/Sources/QinaoSampleHost/main.swift` | 5,687 | source | demo runner accreted via `--*-demo` mode flags across 30+ chapters |
| `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift` | 5,626 | test | the largest single test file is bigger than most production source |
| `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift` | 5,347 | source | L2/L3/L9/L10 cognition plane definitions piled together |
| `Before/App/Services/BeforeAppModel.swift` | 5,201 | source | pre-substrate app model never decomposed |
| `BehavioralAISubstrate/Sources/BASHostKit/HostKitCore.swift` | 4,770 | source | host kit aggregator |

**51 first-party non-test source files exceed 800 lines** (the project's own `coding-style.md` states "200-400 typical, 800 max"). 12 source files over 1,500 lines. 8 source files over 3,000 lines.

**Why this is a debt, not just a smell**:
- New contributors (and future-me) can't load a 5,347-line file into working memory
- Decomposition without tests is dangerous; large files have low test-per-LoC ratios
- Merge conflicts compound exponentially with file size
- Build incrementality breaks down — a one-line change to `EBrainCognitionPlaneCore.swift` recompiles 5,347 lines

**Status**: NOT YET ADDRESSED. No chapter has touched file decomposition. `coding-style.md` rule is documented but unenforced.

---

### A.2 BASHostKit god module — 123 first-party inbound imports (verified 2026-05-04)

```
grep -rln "import BASHostKit" --include="*.swift" (excluding Vendor + .claude/) → 123
grep -rln "import BASSovereign" → ~80 (for comparison)
grep -rln "import BASOrchestration" → ~70 (for comparison)
```

`BASHostKit` is the most-imported module in the codebase. It functions as the central hub that every other layer imports through, contradicting the layered architecture's premise that each layer is a leaf-like module.

**Why this is a debt**:
- Star-topology coupling — change in `BASHostKit` triggers rebuild of 123 files
- The 14-layer story implies layered dependencies, but practical dependency graph is hub-and-spoke around `BASHostKit`
- Future per-layer extraction (e.g. for SDK packaging) requires breaking this hub first

**Status**: NOT YET ADDRESSED. `BASHostKit` continues to grow each chapter.

---

### A.3 Single-implementation Servicing protocols — 15+ matches (verified 2026-05-04)

```
grep -rln "Servicing\|Service.*protocol" BehavioralAISubstrate/Sources → 15
```

Confirmed example: `BASVitalMonitorServicing` — protocol declared in `EBrainServiceContracts.swift` + referenced in `HostKitCore.swift` + tests. **Zero production implementations** beyond the protocol declaration itself.

**Why this is a debt**:
- Protocol-as-documentation is anti-pattern (textbook signal of "abstraction without polymorphism")
- Each unused protocol is dead surface area future maintainers must understand or refactor away
- Type-checker overhead with no runtime benefit

**Status**: NOT YET ADDRESSED. No chapter has audited service-protocol redundancy.

---

### A.4 14-layer narrative inflation

The white-paper / honesty-board narrative says BAS is a "14-layer cognitive architecture" with each layer load-bearing. Empirical reality:

- 5-6 layers are load-bearing in `runTurn()` decision flow (L1 budget / L11 permit / L12 surface / L13 lifecycle / L14 verdict)
- ~9 layers are **observation/audit emission only** — they emit reason codes that no decision consumes
- **0 mutation tests exist** that would catch silent layer regression to no-op (verified: `grep mutation test|breakL5|disableLayer` → 0 matches)

**Why this is a debt**:
- Layers with no consumers can silently degrade to no-ops; nothing catches it
- Documentation overhead compounds (every chapter explains 14 layers; only 5-6 actually matter)
- Onboarding cost — new contributors believe all 14 layers are equally critical

**Status**: NOT YET ACKNOWLEDGED. honesty board treats all 14 layers as doctrine-equal.

---

## Section B — Operational debt (deployment + monitoring)

### B.1 No CI/CD pipeline (verified 2026-05-04)

```
ls .github/workflows/ → No such file or directory
ls .gitlab-ci.yml → No such file or directory
ls .circleci/ → No such file or directory
```

Modifications are validated by manual `swift test` runs. No automated test gating on PR. No automated 5-gate boundary check. No automated bench-suite regression detection.

The 5 gates (`scripts/check_*`) and bench-suite (`scripts/run_bench_suite.sh`) exist but are **author-discipline-enforced, not CI-enforced**. Future contributors will not know to run them.

**Status**: NOT YET ADDRESSED.

---

### B.2 No version tags / release process (verified 2026-05-04)

```
git tag → empty
```

No SemVer. No CHANGELOG-to-version mapping. Honesty board chapter numbers are the only versioning. There is no "v1.0.0" to roll back to.

**Status**: NOT YET ADDRESSED.

---

### B.3 No production telemetry sink (verified 2026-05-04)

```
grep -rln "TelemetrySink\|MetricsSink" BehavioralAISubstrate/Sources → 0
```

The 14-layer audit emission produces structured `signalRefs` reason codes per turn, but there is no aggregator, no sink, no dashboard. In production, audit codes would write to nowhere.

**Status**: NOT YET ADDRESSED.

---

### B.4 No runbook / on-call doc (verified 2026-05-04)

```
ls docs/RUNBOOK.md docs/ONCALL.md → No such file or directory
```

When something breaks in production, there is no document describing how to investigate or roll back.

**Status**: NOT YET ADDRESSED.

---

### B.5 No CONTRIBUTING.md / SECURITY.md / API_STABILITY.md

```
ls CONTRIBUTING.md SECURITY.md API_STABILITY.md → No such file or directory
```

External contributor entry path: undocumented. Public-vs-internal API boundary: undocumented (everything public-by-default).

**Status**: NOT YET ADDRESSED.

---

### B.6 Zero production users

honesty board acknowledges this; included here for completeness. Every doctrine pin is the author auditing themselves against themselves. External adversarial pressure: 0.

**Status**: ACKNOWLEDGED in honesty board.

---

## Section C — Per-layer engineering capability gaps

### C.1 No per-layer SLO / budget (verified 2026-05-04)

```
grep "perLayer\|layerBudget" BehavioralAISubstrate/Sources → 0 matches
```

`BASBudgetFrame` is per-turn global budget. There is no mechanism preventing one layer (e.g. L9 dream loop) from consuming the entire turn's budget while starving other layers.

**Status**: NOT YET ADDRESSED.

---

### C.2 No per-layer kill switch (verified 2026-05-04)

`BASKillSwitchID` enum: 3 cases (`forceGuardMode` / `disableFastPath` / `requireReviewedWrites`). All global. No granular "disable L9 dream-loop while keeping rest of system" capability.

**Status**: NOT YET ADDRESSED.

---

### C.3 No per-layer error boundary

Single layer panic propagates to entire turn. No layer-level fallback or graceful degradation.

**Status**: NOT YET ADDRESSED.

---

### C.4 No per-layer latency attribution (verified 2026-05-04)

```
grep "perLayerLatency\|layerLatency" → 0 matches
```

End-to-end p50 ~228ms / p95 ~260ms (chapter 一百十二 bench). Unknown which layer contributes which fraction. Optimization without measurement is guess-work.

**Status**: NOT YET ADDRESSED.

---

### C.5 No mutation tests / layer-integrity tests (verified 2026-05-04)

```
grep "mutation test\|breakL5\|removeLayer\|disableLayer" → 0 matches
```

This is the most damning gap. The 14-layer architecture claim **has no test that would fail if a layer silently became a no-op**. Layers could degrade to dead code and the test suite would stay green.

**Status**: NOT YET ADDRESSED.

---

## Section D — Production-wire deferrals (acknowledged in honesty board but not aggregated)

### D.1 M386 ForbiddenLifecycleGate — "0 production callers"

Source comment self-disclosure:
```swift
// BehavioralAISubstrate/Sources/BASHostKit/BASUpdateTicketLifecycleForbiddenGate.swift
// zero production callers — the most explicit "deferred" item in chapter 八十七
```

```swift
// BehavioralAISubstrate/Sources/BASHostKit/BASUpdateTicketLifecycleForbiddenZoneGate.swift
// 0 production callers — the gate sat in BASOrchestration as a callable helper without a wire.
```

These are typed primitives waiting for production callers. The **schema-only-trap pattern** (chapter 一百十八 doctrine) acknowledges the risk in narrative form but doesn't aggregate the open count.

**Status**: PARTIALLY ADDRESSED (chapter 一百二十 wired ForbiddenZoneGate; ForbiddenLifecycleGate remains 0 production callers).

---

### D.2 BASVitalMonitorServicing — protocol with 0 runtime implementations (verified 2026-05-04)

```
grep -rln "BASVitalMonitorServicing" → only protocol decl + tests + Before typealias
```

**Status**: NOT YET ADDRESSED.

---

### D.3 NaN guards on sensor conversions (chapter 一百二十九 deep review finding #4)

Threshold compares (`>=` / `<`) silently fall through on NaN inputs. Current behavior is "fail-safe to default" but undocumented. Audit walker can't distinguish corrupt input from clean default.

**Status**: ACKNOWLEDGED in chapter 一百二十九 deep review report.

---

### D.4 audit-projection vs load-bearing metadata distinction

Audit signalRefs include both informative reason codes AND decision-influencing reason codes; nothing in the type system distinguishes them. A future change could accidentally make an "informative" code load-bearing (or vice versa) and audit walker grep would silently misclassify.

**Status**: HONEST-DEFERRED in honesty board.

---

## Priority assessment (honest)

The honesty board's `~99.97%` satisfaction figure is doctrine-purity-only. **Engineering-health honest satisfaction is closer to ~30%**:

| Domain | Honest score |
|---|---|
| Doctrine compliance | ~99.97% (audited extensively) |
| Schema parity | ~100% (gated) |
| 14-layer audit emission | ~95% (chapter 一百二十八 closure) |
| **Code organization (file size, module shape)** | **~30%** (5+ god files, 51 source files >800 lines, 1 god module) |
| **Operational readiness (CI/runbook/telemetry/SemVer)** | **~5%** (no CI, no version tags, no telemetry, no runbook) |
| **Test depth (mutation/per-layer/integration)** | **~40%** (24 ObservationBundle assertions exist; 0 mutation tests) |
| **External validation** | **0%** (0 users, 0 third-party audit, 0 issue tracker) |

A weighted aggregate puts true honest satisfaction in the **40-60% range**, not 99.97%. The gap between these two numbers is the size of the blind spot.

## What this file is NOT

- Not a fix list. These items are deferred to multi-chapter (lineage graph) / external (CI infra / users) / weeks-of-engineering scope.
- Not a doctrine document. Doctrine lives in honesty board + manifesto v1-v8.
- Not a self-flagellation log. The point is making the debt **visible** so future scope decisions are informed.

## When to update

- When a god file is decomposed: remove its row from A.1
- When CI is set up: mark B.1 ADDRESSED with date
- When a per-layer SLO is added: mark C.1 ADDRESSED
- When a new structural debt is identified: add it with verified evidence (grep count + file path + line numbers)

This file should **shrink over time**. If it grows, that means engineering health is regressing faster than addressed.
