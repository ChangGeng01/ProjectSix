# ADR-018 — 循环算法 + 进化学习回路 底层架构(统一 Deliberation-Budget Loop)

- **Status**: IN PROGRESS — NO LONGER "design only". P1 LANDED (ch 1039, substrate code CHANGED — see §7.2-§7.4; async-engine `buildCoordinator` threading still blocked by toolchain SIGBUS, §7.3) + P1 made decision-consequential (ch 1040-1042 via ADR-019/020) + P2 Commit 1 LANDED dormant (ch 1043, §10). Original design accepted 2026-05-29; implementation status tracked in §7.2-§7.4 + §10.
- **Date**: 2026-05-29
- **Chapters**: design for ch 1039+ (P1) through ch 1043+ (P5); P6 aspiration
- **Supersedes / relates**: ADR-014 (OPT-IN doctrine), red-line 7 (additive byte-equal), ch 1025.11 (thermal-aware cooldown data), SCAFFOLD_VS_WIRED.md
- **Scope discipline**: measure-before-core-change — this ADR is the *measurement + design*; implementation is future per-phase cascades.

---

## 1. Context

User mandate (架构思考模式): 「全面加入循环算法 + 全面进化算法底层架构 + 整体逻辑 + 最极致最优雅」, then 「再次研究 最细节 最饥渴」, then 「5 大点火点各做可行性 spike」.

Investigation: **3 layered Explore agents (full L0-L14 scan) + 5 ignition-point feasibility spikes.**

**Decisive finding:** the BAS substrate's iterative-loop / evolution capability is **not "missing" — it is "interface fully reserved, engine never ignited."** Every cross-turn feedback path, convergence telemetry field, Rust trial algorithm, and 6-state evolution lifecycle EXISTS as a data structure or pure algorithm — but the decision logic **never queries them**. This is the same class as `fabric .observationOnly` and ANE `consultedByExecutorInProduction=false`: reserved interface, behavior pending. Ignition = closing the scaffold↔wire gap, NOT rewriting the architecture.

---

## 2. Verified ground truth — 「无循环」 locked by three proofs

The cognitive flow `runTurn()` runs L0→L14 as a **single linear forward pass**:

1. **Loop site is single-call**: `EBrainRuntimeCoordinator+RunTurn.swift:172` — `var thoughtFrame = loopService.iterate(...)` called ONCE, followed by 3 backfills (`:177-197`). No `for`/`while`/`repeat` around the cognitive cascade.
2. **loopCount derives, never accumulates**: `EBrainRuntimeCoordinator+Trace.swift:53` — `let loopCount = max(1, thoughtFrame.stepIndex)`. `BASMLLoopService.iterate` hardcodes `stepIndex: 0` (`BASMLLoopService.swift:293`).
3. **The substrate's own test pins it**: `BASEBrainSchemaCoreTests.swift:1743` — `#expect(result.runtimeTrace.loopCount == 1)`.

**Nuance (verified):** the *injected* `BASHostRuntimeEBrainLoopService.iterate` (`EBrainHostRuntime+LoopService.swift:115-116`) ALREADY computes `appliedLoopCount = min(budget.maxLoops, desiredLoopCount())` and sets `stepIndex` from it — so the *budget→loop-count* machinery is half-wired; what is missing is the `repeat/while` that actually *re-enters* the cascade. Only `BASMLLoopService` hardcodes 0.

---

## 3. Full 14-layer latent loop/evolution map (~40 points)

| Layer cluster | latent points | Truth | Representative evidence |
|---|---|---|---|
| **L0-L6 front-end** | ~30 | "reservoir, no pump" — all write-once | L5 `boundaryVeil` ratchet (add-only, never relaxes); L5 `valueAxes.updateThreshold=0.75` never queried; L6 `confidence`/`volatility`/`windowDecay` written once, never recomputed (`EBrainL6SituationFieldCore.swift`) |
| **L7-L11 reasoning** | ~11 | single-pass + write-then-frozen | L8 memory has **no temporal decay** (`halfLifeHours` computed once); L8 `promotionState` one-directional (candidate→admitted→frozen, never reverses); L10 veto has no negotiation (`compensable` always false); L11 evidence-debt is penalize-only (never repaid); risk escalation never self-activates stacked modes |
| **L12-L14 + cross-layer evolution** | the big ones | algorithms real, feedback unwired | `ShadowTrialStateMachineCore.swift` + `bas-shadow-trial` (Rust) + `bas-dream-loop` (Rust) are real algorithms with feedback UNWIRED; `BASEvolutionLifecycle` 6-state machine is observation-only; `BASFeedbackEvent` field exists but dead-ends at the audit sink |

**Interpretation:** L0-L6 hold the reservoirs (state fields) with no pumps (update logic). L7-L11 have one half-wired loop (L9 candidate frontier). L12-L14 hold the highest-leverage unwired machinery (real Rust trial/score algorithms + a lifecycle state machine), where ignition is purely a *wiring* problem.

---

## 4. Five ignition points — feasibility matrix (spike-verified)

| # | Ignition point | Verdict | ~LOC | Red-line compliance | Minimal honest ignition |
|---|---|---|---|---|---|
| **1** | `bas-dream-loop` outcome → next-candidate scoring | ✅ **clean-1-chapter** | ~40 | empty-history = identity (turn-1 byte-equal) | Rust kernel untouched (pure stateless `score_candidate`); add `candidateTypeSuccessTally` actor field on `BASCognitiveBrain`; modulate `costs[]` BEFORE the FFI call in `BASAutoRouteRanker.dreamLoopBatchScore`; empty tally → `cost × 1.0` = identity |
| **2** | ShadowTrial transition history → trial feedback loop | ⚠️ **needs-infra** | ~150 | respects NEVER-EFFECTIVE-SAME-TURN (turn N+1 evaluates turn N's trial) | `ShadowTrialStateMachineCore.swift` + `bas-shadow-trial` Rust transition() are READY; missing = cross-turn persistence (ledger replay on coordinator init) + `evaluatePendingTrials(stopReason:riskCard:)` trigger at turn N+1 start |
| **3** | calibration `.drifting` → corrective deliberation loop | ✅ **clean** | ~30 | `.stable` = identity (already true) | `desiredLoopCount()` ALREADY returns 3 when drifting (`EBrainHostRuntime+LoopService.swift:115`); missing = budget normalization syncing `maxLoops` up to `desiredLoopCount`. Unify with thermal into one deliberation budget |
| **4** | `BASFeedbackEvent` → policy/threshold mutation | 🔴 **needs-infra + sovereign-gate** | ~250 | nil-feedback = identity | **DANGEROUS: a user can train the system badly.** All policy is static-const; needs a new mutable threshold holder + an L14 sovereign gate (`BASSovereignDomainScope` — 「nuclear button, not control panel」) + ±0.05 per-event cap + high-confidence-auto / low-confidence-human-review |
| **5** | L13 host version-tree → branch / shadow-trial / merge | 🔴 **major-arc (2-3 sessions)** | 600-900 | L5 sovereign-adjacent — highest stakes | `parentVersionID` already exists (M110); but branch registration + trial-merge promotion + multi-trial isolation + device-sync CRDT span 3 modules (BASMemory ← BASOrchestration ← BASSovereign) |

---

## 5. Core decision — Unified Deliberation-Budget Loop (最极致最优雅)

**Key insight:** ignition points 1 & 3, together with the L9 frontier loop, share **one convergence skeleton**. They are NOT five isolated loops — they are **one unified deliberation loop**:

```
deliberation_budget = f(thermal_tier, calibration_drift, uncertainty)
    # 点3 + ch1025.11 thermal data + existing maxLoops/desiredLoopCount machinery

repeat:
    thoughtFrame = loopService.iterate(priorFrame, biased_costs)
        # 点1: dream-loop success-tally biases candidate costs
    if converged(convergenceCertificate.stoppingMode
                 / uncertaintyLedger.confidenceFloor
                 / max(evidenceDebts.debtWeight)):     # existing telemetry — ZERO new fields
        break
while loopCount < deliberation_budget
```

The evolution points (2 / 4 / 5) are the **slower outer learning loop** that feeds back into `deliberation_budget` and the candidate bias — they are not in the hot per-turn loop.

### The three elegance principles

1. **Reuse telemetry, build no new structures.** `BASConvergenceStoppingMode`, `uncertaintyLedger.confidenceFloor`, `evidenceDebts.debtWeight`, `candidateFrontier.frontierWidth`, `maxLoops`, `desiredLoopCount()` ALL already exist. Ignition is wiring, not invention.
2. **Opt-in gate = red-line preserved by construction.** `budget == 1` / empty tally / `.stable` calibration / `nil` feedback → every path degrades to today's byte-equal behavior. The `BASStressSweepCanonical60Driver` identity sweep + the `loopCount == 1` test stay green unmodified.
3. **Unified, not isolated.** thermal (ch1025.11: `serious` needs ≥180s recovery) + drift + uncertainty jointly decide "how deep to think"; dream-loop outcome decides "which candidate to favor". One budget, one bias — not five bolt-ons.

---

## 6. Phased roadmap (for future per-chapter execution)

| Phase | Chapter | Scope | Verdict | ~LOC | Risk | Red-line proof |
|---|---|---|---|---|---|---|
| **P1** | ch 1039 | Unified deliberation loop: `repeat/while` in runTurn + 点3 drift/thermal→maxLoops + 点1 dream-loop tally | ✅ clean | ~110 | MED (runTurn hot path) | budget=1 → identity sweep + `loopCount==1` green unchanged; maxLoops=3 → loopCount ≤ 3, frontierWidth non-decreasing |
| **P2** | ch 1040 | 点2 ShadowTrial evaluator + ledger replay (N→N+1 trial closure) | ⚠️ needs-infra | ~150 | MED (NEVER-SAME-TURN intact) | feedbackEvent path unchanged → identity sweep; trial transitions across 2 turns |
| **P3** | ch 1041 | opt-in flag + loop/trial telemetry into trace + thermal-gated depth on-device proof | ✅ clean | ~60 | Low | flag OFF → identity; `serious` thermal → maxLoops==1 |
| **P4** | ch 1042 | 点4 feedback→policy (single scalar threshold) + L14 sovereign gate | 🔴 sovereign-gate | ~250 | HIGH (can train-bad) | nil-feedback = identity; sovereign veto blocks; ±0.05 cap; replay-deterministic |
| **P5** | ch 1043+ | 点5 version-tree branch / shadow-trial / merge | 🔴 major-arc | 600-900 | HIGH (highest-stakes cross-module) | multi-session; each step sovereign-gated + reversible + device-sync |
| **P6** | aspiration | population / fitness / selection / crossover GA (zero GA machinery exists today) | far-future | — | — | multi-session; ADR records the route only |

**Ship order: P1 (most elegant start) → P2 → P3 → P4 → P5.** P1 is the true 「最极致最优雅」 starting point: minimal code, reuses all existing telemetry, zero red-line risk, device-verifiable.

---

## 7. Critical files (for implementation — NOT touched by this ADR)

- `Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift` (`:172-197` host the loop; `:214-219` move artifact-materialization inside the loop; `:62` `planBudget` already wired)
- `Sources/BASHostKit/EBrainServiceContracts.swift` (`:269-293` `BASLoopServicing` — add `priorCandidateIDs: [String] = []`)
- `Sources/BASHostKit/BASMLLoopService.swift` (`:151` proposePaths / `:274` iterate / `:293` stepIndex / `:370` shouldOfferCautious — relaxation + stepIndex)
- `Sources/BASHostKit/EBrainRuntimeCoordinator+Normalization.swift` (add `loopConverged()` + drift→maxLoops sync)
- `Sources/BASHostKit/EBrainHostRuntime+LoopService.swift` (`:115-116` `desiredLoopCount`/`appliedLoopCount` already half-wired)
- `Sources/BASMemory/ShadowTrialStateMachineCore.swift` + `Cargo/bas-shadow-trial/src/lib.rs` (P2 evaluator — ready, unwired feedback)
- `Sources/BASRuntimeCore/BASAutoRouteRanker.swift` (`dreamLoopBatchScore` — P1 点1 cost modulation) + `Cargo/bas-dream-loop/src/lib.rs` (pure kernel, untouched)
- `Sources/BASMemory/HostConstitutionCore.swift` (`:465` version tree, `parentVersionID` M110 — P5)

### 7.1 Implementation ground-truth (ch 1039 fresh verification, 2026-05-29)

Re-reading the live hot path during the ch 1039 P1 attempt refined four
estimates above. Recorded append-only — the original §6/§7 verdicts stand as
the design record; this is the executable detail.

1. **Loop body is `:172-221`, not `:172-197`.** The convergence predicate
   (`loopConverged`) needs the *materialized* telemetry —
   `candidateFrontier` / `uncertaintyLedger` / `evidenceDebts` /
   `convergenceCertificate` are filled by `materializeThoughtArtifacts`
   (`:204-221`), AFTER `normalizeThoughtFrame` (`:198`). So the `repeat` must
   wrap `iterate → 3 backfills → normalize → organMap → materialize`
   (`:172-221`). `materializePublicProjection` (`:222-238`), world-prior
   (`:250`), and tri-self (`:254-280`) stay OUTSIDE the loop — they run once on
   the converged frame.

2. **`iterate()` takes no prior frame → the contract change is a prerequisite,
   not an optional refinement.** `loopService.iterate(decomposeFrame:
   memoryBundle:budget:)` (call site `:172-176`;
   `EBrainHostRuntime+LoopService.swift:110-145`) is a pure function of its
   inputs and returns `stepIndex: appliedLoopCount` analytically in ONE pass —
   `appliedLoopCount = min(budget.maxLoops, desiredLoopCount())`. Calling it
   twice with identical inputs yields an identical frame, so a `repeat` without
   forward-fed state is a no-op repetition. A *meaningful* P1 loop REQUIRES the
   `BASLoopServicing` contract gain a `priorCandidateIDs: [String] = []` (or
   prior-frame) parameter, wired through BOTH `BASMLLoopService` and
   `EBrainHostRuntime+LoopService`. This makes P1 a **shared-contract +
   hot-path** change across 4-5 files, blast radius **MED-HIGH** — best executed
   at the start of a fresh focused session, NOT the tail of a long cascade.

3. **Default byte-equality mechanism is the `while` guard.** With
   `routedBudget.maxLoops == 1` (today's default) the guard
   `deliberationPass < maxLoops` is `1 < 1 == false` → body runs exactly once →
   byte-equal with pre-P1. The red-line test
   `BASEBrainSchemaCoreTests.swift` `loopCount == 1` uses `riskHint: .high`
   (→ `desiredLoopCount == 3`) and stays green ONLY because
   `appliedLoopCount = min(maxLoops=1, 3) == 1`. Therefore **P1 must NOT raise
   the production-default budget** — `点3 drift/thermal → maxLoops` must itself
   sit behind the opt-in flag (pulling part of P3's flag ahead of P1), else this
   pinned test breaks.

4. **1-hour test motivates a thermal-gated budget floor.** The ch 1039 1-hour
   all-parts run measured thermal == `serious` for all 20 iterations (consistent
   with the 10-hour data, ch 1025.11). So the deliberation-budget function must
   floor depth under thermal pressure: `serious → maxLoops == 1` (no extra
   deliberation when the device is already hot). This is the safest first slice
   of 点3 and is directly evidence-backed.

### 7.2 P1 core LANDED — opt-in deliberation loop (ch 1039)

The ch 1039 follow-up landed the running loop itself (not just the §7.1
plumbing). Status: **IMPLEMENTED, opt-in, default OFF.**

Done:
- `BASEBrainRuntimeCoordinator.deliberationLoopEnabled: Bool = false` — the
  OPT-IN gate (ADR-014 + 红线 7), same doctrine as the `agentFabric` slot.
- `runTurn` extracts `runDeliberationPass(priorCandidateIDs:)` (the `:172-221`
  iterate → backfill → normalize → materialize cycle, returning frame +
  findings + artifacts) and, when enabled, runs `min(maxLoops, stepIndex)`
  refinement passes — each carrying the prior pass's candidate IDs forward —
  halting early on a terminal stop (maxLoopsReached / blocked / replaced /
  guardTakeover). The non-terminal converged states (candidateStable /
  riskConverged / uncertaintyBelowThreshold) do NOT stop it; it refines up to
  the requested budget.
- Tests: `BASChapter1039DeliberationLoopTests` — off = 1 pass, on = N passes,
  terminal early-exit, maxLoops-bound (over-budget stepIndex clamps to a
  terminal stop).

Verified byte-equal: full sweep **14,652 tests / 0 failures** with the flag
OFF — incl. the `loopCount==1` pin, ×2 `stepIndex==maxLoops`, and the
canonical identity + byte-equality-proof sweeps. (A flaky `swiftpm-testing-
helper` SIGBUS on an unrelated swift-testing test, `exposesDefaultDescriptors
ForBuiltInProviders`, exits the runner non-zero but passes in isolation — not
a regression.)

Deferred (still ADR-018 scope):
- 点3 THERMAL → maxLoops floor: drift → MORE loops is already partly wired via
  `desiredLoopCount()` (returns 3 when calibration is unstable); thermal →
  FEWER is not yet wired.
- Production activation: `makeWithDefaults` keeps the flag OFF and uses
  `BASMLLoopService` (stepIndex → 1), so the loop is dormant in production until
  explicitly opted in with a multi-loop service + budget. **The engine can now
  FIRE (opt-in) — before ch 1039 it structurally could not.**

### 7.3 P1 activation + real-engine refinement LANDED (ch 1039)

The harden+activate follow-up made the loop usable through the real
production host path, not just a test double:

- **Shared bias** — `BASDeliberationBias.reinforce(_:priorCandidateIDs:)`
  single-sources the persistence bias; BOTH `BASMLLoopService` and
  `BASHostRuntimeEBrainLoopService` now apply it. (Key finding before
  this: only `BASMLLoopService` refined, and it never loops —
  stepIndex → 1; the host service loops but IGNORED `priorCandidateIDs`,
  so the loop ran inert. No single service both looped AND refined.)
- **Activation** — `buildEBrainTurn(…, deliberationLoopEnabled:)`
  (→ `makeEBrainTurn` → coordinator), default false. A host opts in per
  the same defaulted-param doctrine as `agentFabric`; the sync /
  `.v1ByteEqual` path is wired. (The async-engine `buildCoordinator`
  path is a noted follow-up.)
- **Real-engine proof** — `testActivatesAndRefinesViaRealHostRuntimePath`:
  a high-risk turn through `BASHostRuntime` carries `loopCount > 1`, and
  with the loop ON the refinement SURVIVES the full projection pipeline
  (`on.candidates ≠ off.candidates`). The default
  `materializePublicProjection` returns `candidates: nil`, so the loop's
  refined candidates are preserved to the output. The loop now produces
  an observable, useful effect with the production-capable service.

Verified byte-equal: full sweep **14,653 / 0 failures** with the flag
OFF — the `BASMLLoopService` refactor is behaviour-identical (its tests
pass in-suite).

Still deferred: 点3 thermal → fewer loops (largely emergent — the power
clock's throttle reduces `maxLoops` under thermal pressure, which the
loop already honors via `min(maxLoops, stepIndex)`); async-engine
`buildCoordinator` threading; flipping the flag ON by default in any
host (a deliberate behaviour-change decision, not yet taken).

**Async-engine threading — attempted ch 1039, reverted (toolchain
blocker).** Threading the flag through `buildEBrainTurnWithRuntimeMode`
→ `buildCoordinator` is trivial and byte-equal-off, BUT its only
faithful activation test is an `async XCTest` that calls
`runtime.startSession(...)` — which deterministically crashes the
XCTest process with `signal code 10` (SIGBUS) on the current toolchain
(macOS 26 SDK + async-XCTest bridging), a PRE-EXISTING documented issue
(`BASSignalTenIntegrationTestTriageDoctrine`, 12 known such tests). Per
the discipline "do not ship behaviour-capable code that cannot be
verified", the threading was reverted rather than shipped untested.
Re-attempt once the toolchain SIGBUS is resolved (Xcode rollback/upgrade
per the doctrine's recovery paths). The sync host path
(`buildEBrainTurn`, the `.v1ByteEqual` default) is fully activated +
tested, so this is a completeness gap on a non-default path, not a hole
in the core deliverable.

### 7.4 Deep-audit finding — the loop is currently DECISION-INERT (ch 1039)

A deep adversarial audit (4 round-1 + 3 round-2 agents, each reading the
live code; one ran a mutation test) found that P1's loop is SAFE
(byte-equal off, full sweep 14,653 / 0) and mechanically correct, BUT
its refinement is **decision-inert** — when enabled it changes **no**
selected candidate, risk level, action permit, or rendered output. Two
structural reasons, both traced to exact code:

1. **Uniform bias.** The loop reinforces ALL surviving candidates by the
   same +0.05 (`priorCandidateIDs` = every prior candidate ID, so
   `BASDeliberationBias.reinforce` bumps every match). A uniform additive
   shift cannot move an argmax, a ranking (`candidateDominanceScore`), or
   the `scoreGap` agency-reservation threshold — selection is invariant.
2. **Clamped out of the deciding score.** Candidate confidence feeds
   selection only through `egoScore`
   (`EBrainHostRuntime+TriSelfService.swift`), which clamps confidence at
   `confidenceCeiling` (0.64). The default `proposePaths` confidences are
   already at/above 0.64, so the +0.05 is clipped → net `mergedScore`
   delta = 0. So **selection** is unchanged.

**Correction (deeper grounding, empirically confirmed ch1039).** The
round-2 "decision-inert" claim was over-stated for the RISK path. The
+0.05 is NOT fully write-only: `buildUncertaintyLedger` computes
`confidenceFloor = min over candidates of (confidence − penalties)`, so
the uniform +0.05 raises `confidenceFloor` by +0.05 — and `calibrateRisk`
DOES consume it (`if ledger.confidenceFloor < 0.55 { riskIncrement +=
0.03 }`, RiskService `:671`; and `supportLevel`, `:302`). The
integration test now pins both halves: `on.confidenceFloor ==
off.confidenceFloor + 0.05` (the signal changes), AND `on.riskLevel ==
off.riskLevel` (it stays sub-threshold — default floor ≈0.27 vs the 0.55
gate — so the risk OUTCOME is unchanged). Accurate status: the loop is
**telemetry-consequential but sub-threshold → decision-inert *in
practice* for default candidate values.** Near a threshold (a base floor
in [0.50, 0.55)) the same +0.05 WOULD flip the `:671` risk increment —
so the wiring already exists; it is the loop's *effect size + signal
choice* that is inert, not the consumer.

Combined with the non-accumulating saturation (pass N≥2 is byte-identical
to pass 2 — the loop is idempotent once candidate IDs stabilize), a
budget of 3/4/5 delivers nothing beyond pass 2 except wasted recompute.

**Honest status correction:** P1 landed the loop INFRASTRUCTURE — safe,
opt-in, mechanically correct, real-pipeline-verified — but the refinement
is **NOT yet consequential**. Earlier ch1039 framing ("produces an
observable, useful effect") overclaimed: the effect is observable (a
confidence number + derived reported metrics) but useless (no decision
reads it). This is scaffold at the decision level, disclosed here per
honest-mode. The loop is dormant in production (default OFF), so this is
not a production defect — but activating it today accomplishes nothing
consequential.

To make it consequential (focused-session follow-ups, NOT fatigued-tail
changes):
- **Differential bias** — reinforce selectively (e.g., only the surviving
  leader, or weight by persistence/evidence) so it can widen/narrow
  `scoreGap` or flip the argmax, rather than a uniform shift.
- **Clamp-aware / consumer wiring** — relax or bypass the egoScore
  `confidenceCeiling` clamp for the bias, OR wire a decision
  (selection/risk) to consume the loop's confidence delta.
- **Early-exit on convergence** — `if newFrame == priorFrame { break }`
  (BASThoughtFrame is Equatable) to stop the saturated wasted passes;
  changes the pass-count pin `testRunsBudgetedPassesWhenEnabled`.

---

## 8. Consequences

**Positive:**
- Turns ~40 latent reserved interfaces into a coherent, phased ignition plan grounded in verified code.
- P1 delivers real iterative deliberation (bounded, pure, opt-in) at ~110 LOC reusing existing telemetry — high ROI, low risk.
- Unifies thermal (ch1025.11) + drift + uncertainty into one deliberation budget rather than scattered ad-hoc gates.

**Negative / risks:**
- runTurn is the hot path; P1's main lift is wrapping `:172-221` (iterate → backfill → normalize → materialize) in the deliberation loop PLUS a shared `BASLoopServicing` contract change to forward prior-candidate state (see §7.1) — 4-5 files, MED-HIGH; must preserve byte-equality at budget=1.
- P4 (policy mutation) is genuinely dangerous (user can degrade safety) — gated behind L14 sovereign + caps; must not ship without it.
- P5 (version branching) is a 2-3 session cross-module arc — not to be attempted piecemeal.

**Honest boundary:** This ADR is **design, not implementation**. Writing it down does NOT mean the capability exists. Each phase is a future cascade (red-line proof + 3-agent review + device/swift verify). "最极致最优雅" = P1's unified loop reusing existing telemetry; GA (P6) is explicitly far-future aspiration.

---

## 9. Verification of THIS ADR (doc-only)

- Internal consistency + every `file:line` accurate against verified ground truth (Section 2-7 cross-checked via grep 2026-05-29).
- `SCAFFOLD_VS_WIRED.md` append keeps `BASChapter1005ScaffoldInventoryPin` structural test green (append-only, required substrings preserved).
- Zero code change → zero build/test/device regression risk.

---

## 10. P2 (ShadowTrial N→N+1 feedback) — implementation status + resume spec (ch 1043)

A fresh adversarial architect pass (Opus, code-grounded) CORRECTED §6/§7's stale
"machinery READY, just wire it" framing:

- **§6/§7 mechanism was wrong.** "ledger replay on coordinator init" has NO home:
  `BASEBrainRuntimeCoordinator` is an immutable value-type `struct` with no
  per-turn init. The correct mechanism is the **ch1042 carrier pattern** — a
  coordinator slot-IN (last turn's pending trials) + a `@Sendable` sink-OUT
  (this turn's evaluated trials), both default-nil → off the Codable/seal path →
  byte-equal. The OUT half already exists (`result.shadowTrialRecords`).
- **Two disjoint ShadowTrial worlds exist** (the ADR conflated them): World A =
  the real lifecycle state machine (`ShadowTrialStateMachineCore.swift`,
  `BASShadowTrialCoordinator` actor) — fully DEFINED, NEVER instantiated in
  production. World B = the inline ad-hoc `BASShadowTrialRecord` construction in
  `EBrainRuntimeCoordinator+EvolutionGovernance.swift:~144-167` — this is what
  runTurn actually does, and it can birth a trial `"passed"`/`"failed"`
  same-turn. P2 adds a PARALLEL prior-turn evaluator; it does NOT touch World B
  (that unification is a separate, higher-byte-risk refactor).
- **NEVER-EFFECTIVE-SAME-TURN** (`BASEvolutionShadowSeat.swift:9` doctrine) is
  preserved by construction: the slot-IN only ever holds turn N−1's records, so
  evaluating it at turn-start cannot touch turn N's own (not-yet-built) trial.

### P2 Commit 1 — LANDED (ch 1043, `74f31dedf`), DORMANT + byte-equal

`BASShadowTrialFeedbackLedger` (new, BASMemory): immutable Codable carrier +
pure `evaluate(_:using:)` that advances a prior-turn pending trial ONE step by
faithfully delegating to `BASShadowTrialStateMachineCore.transition` (verified
total against the real machine; terminal records unchanged; anti-theater — no
silent advance on unknown states). 3 default-OFF coordinator slots
(`shadowTrialFeedbackEnabled`/`pendingTrialLedgerIn`/`resolvedTrialSink`)
mirroring ch1042, threaded through `buildEBrainTurn`/`makeEBrainTurn`. 0 refs in
runTurn → dormant. Tests `BASChapter1043ShadowTrialFeedbackTests` 7/0; byte-equal
witness `BASChapter1039` 9/0; init-pin `BASChapter602` 4/0.

### P2 Commit 2 — RESUME SPEC (the opt-in N→N+1 trigger — a runTurn SPINE edit; do with a FRESH context)

In `EBrainRuntimeCoordinator+RunTurn.swift`, insert a guarded block at
**turn-start** (after `derivedTurnID` is available, ~:116-120, and BEFORE
`buildEvolutionGovernanceArtifacts` ~:960) — this placement is what guarantees
NEVER-SAME-TURN:
```
if shadowTrialFeedbackEnabled, let pending = pendingTrialLedgerIn,
   let sink = resolvedTrialSink, !pending.pendingTrials.isEmpty {
    let evaluated = pending.pendingTrials.map { BASShadowTrialFeedbackLedger.evaluate($0) }
    sink(evaluated)                  // OUT only — gates nothing
}
```
**OBSERVATION-ONLY** (mirrors `provisionalVerdictSink`): the evaluated outcome
feeds the sink ONLY — NOT render, seals, `buildSovereignVerdict`, governance, or
any canonical-bytes/hash path. Three independent off-switches (flag false / nil
carrier / nil sink, all default) → block never runs → byte-equal. The host closes
the cycle: persist `result.shadowTrialRecords.filter(\.isPending)` after turn N,
feed as `pendingTrialLedgerIn` on turn N+1 (the coordinator stays immutable; the
host or a thin host-loop helper owns persist-and-reinject — the genuine
"needs-infra" delta). Tests: the 2-turn transition (trial born turn N, closed
turn N+1, two distinct turns); NEVER-SAME-TURN guard (nil carrier → empty sink);
byte-equal-off (each off-switch); replay-determinism. Gate on fast filters
(ADR-020 §8), not the noisy full sweep.

### P2 Commit 3 — tests/docs/telemetry (optional trace telemetry behind the flag; flip SCAFFOLD ShadowTrial scaffold→opt-in-wired; flip this §10 status).

### P2 honest boundary (what it does NOT do)
Observation-only (closing a trial changes nothing the host sees unless it acts on
the sink); does NOT touch World B's same-turn construction; does NOT touch
`BASFeedbackEvent` (stays an advisory dead-end ticket — that's P4); no
sovereign-audit-chain durability (carrier is in-memory host-persistable); the
coordinator stays immutable (cross-turn state is host-held). ~125 production LOC
total (the ADR's ~150 estimate was accurate; only the *mechanism* + file names
were wrong).
