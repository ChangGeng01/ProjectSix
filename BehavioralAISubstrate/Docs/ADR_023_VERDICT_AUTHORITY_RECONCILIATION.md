# ADR-023 — Reconciling the Two Verdict Authorities (Phase-2 prerequisite)

> **Status: DESIGN (ch1044 全面优化).** The ADR-022 §8 full-grid sweep proved the
> coordinator's `computeVerdictDecision` and the engine's `BASSovereignVerdictEngine`
> diverge on ~46% of adversarial turns (886/1920 `coordinatorLaxer`). Phase-2
> (auto-halt on `.coordinatorLaxer`) cannot be enabled until they agree. This ADR
> designs the reconciliation, grounded in the measured divergence taxonomy. It is
> design-only; every step touches the sovereign safety spine and must land as its
> own gated change with the full-grid sweep as the acceptance gate.

## 1. The measured divergence taxonomy (hard data, not estimate)

`testParityFullGridSurfacesEveryCoordinatorLaxer` (1920 combos) after the
ADR-022 §8 projection fix. `coordinatorLaxer` = 886. By **(coordinator→engine)**
level pair:

| coord → engine | count | class |
|---|---|---|
| memoryFreeze → deadStop | 276 | A |
| shadowLock → deadStop | 228 | A |
| quarantine → deadStop | 184 | A |
| throttle → toolCut | 64 | C |
| toolCut → deadStop | 48 | A |
| shadowLock → toolCut | 32 | A |
| memoryFreeze → quarantine | 12 | B |
| pass → throttle | 10 | C |
| throttle → shadowLock | 10 | D |
| pass → shadowLock | 10 | C |
| throttle → quarantine | 8 | B |
| shadowLock → quarantine | 4 | B |

By dominant **condition**: `lineageMissing` **736 (83%)**, `elevatedMode` 90,
`brakeElevated` 50, `highRisk` 10.

**Benign turns (lineage present, `.engage`, no brake, low/medium risk): 0 laxer.**
The divergence is entirely in the adversarial region.

## 2. Root cause per class

- **Class A — missing-lineage over-escalation (≈83%, the dominant cause).** The
  verifier's `makeContext` (`BASSovereignTurnVerifier.swift`) sets
  `policyBundleTampered: obs.policyLineageMissing`. The engine has **no BR-006
  "missing-lineage" observation distinct from tampering**, so a turn that merely
  LACKS policy provenance is fed to the engine as ACTIVE policy-bundle TAMPERING →
  `deadStop`. The coordinator (BR-006) treats the same condition as `shadowLock`
  (lock writes, recoverable). Two different severities for the same fact.
- **Class B — elevated runMode (quarantine/recovery/guard).** The engine escalates
  these modes (via the runtime-instability soft signal + hard flags) above the
  coordinator's lattice (`recovery→shadowLock`, `quarantine→quarantine`,
  `guard→throttle`).
- **Class C — brake elevated but not lockdown.** The coordinator raises on a brake
  ONLY at `.lockdown`; the engine raises on ANY elevation (`.caution/.guard/
  .quarantine`) through `deriveRuntimeInstabilitySignal`. So `coord=pass/throttle`,
  `engine=throttle/toolCut`.
- **Class D — high-risk soft-signal.** With realistic scalars, the engine's
  soft-signal stage nudges a high-risk turn one band above the coordinator's
  `throttle` (≈10 cases). The smallest class.

## 3. Reconciliation decisions (the policy calls)

Each class is a *severity-policy* question. The discipline: **converge without
making either authority laxer on a genuine threat.** Where one side is
demonstrably over- or under-escalating relative to the agreed semantics, fix that
side.

- **Class A (recommend: fix the ENGINE side — distinguish missing-lineage from
  tampering).** "No provenance" is not "corruption". `deadStop` (irrecoverable
  session kill) for every provenance-less turn is operationally untenable and
  semantically wrong; `shadowLock` (lock writes, recoverable) is the proportionate
  response, and is what BR-006 + the coordinator already do. **Recommended:** give
  the engine a real BR-006 — a `policyLineageMissing` hard-observation mapped to a
  `shadowLock`-tier escalation — and reserve `policyBundleTampered`/`deadStop` for
  an ACTUAL tamper signal (signature-invalid / checksum-broken, which the engine
  already models). This resolves ≈83% and makes the engine *more correct*, not
  laxer on real tampering. **This is a sovereign change to `BASSovereign`** and
  must be reviewed as such (it lowers the engine's verdict for a specific,
  well-justified condition).
- **Class C (recommend: fix the COORDINATOR side — stricter).** A non-lockdown
  brake elevation IS a meaningful instability signal; the coordinator ignoring
  everything below `.lockdown` is the laxer, less-defensible side. **Recommended:**
  the coordinator raises a proportionate level (e.g. `throttle`) on
  `.guard/.quarantine` brakes. Safe direction (coordinator → stricter).
- **Class B (decide, then align).** Elevated-mode escalation: pick the canonical
  per-mode verdict (likely the stricter engine values) and make the coordinator
  lattice match. Safe direction.
- **Class D (minor, align last).** Reconcile the high-risk soft-signal band so the
  two agree at `throttle` (or both at the higher band) for high/extreme risk.

## 4. The mechanism + safety discipline

- The fixes touch the **sovereign safety spine** — `BASSovereignTurnVerifier.makeContext`
  / `BASSovereignVerdictEngine` BR rules (Class A) and the coordinator's
  `computeVerdictDecision` lattice (Classes B/C). None are casual edits.
- **No-laxer-on-threat invariant:** every change is checked so it never lowers a
  verdict for a condition that is a genuine threat. Class A lowers missing-lineage
  from `deadStop`→`shadowLock` — justified because missing-lineage ≠ tampering and
  the tamper path (signature/checksum) keeps its `deadStop`.
- **The full-grid sweep is the gate.** After each R-step, re-run
  `testParityFullGridSurfacesEveryCoordinatorLaxer`: `coordinatorLaxer` must drop
  monotonically toward 0, and the benign region must stay at 0.

## 5. Phased reconciliation plan

| step | target | expected laxer reduction | side |
|---|---|---|---|
| **R1** | Class A — engine BR-006 (missing-lineage ≠ tampering) | −≈736 (83%) | BASSovereign (sovereign) |
| **R2** | Class C — coordinator raises on non-lockdown brakes | −≈84 | coordinator lattice |
| **R3** | Class B — align elevated-mode verdicts | −≈24 | coordinator lattice |
| **R4** | Class D — align high-risk soft band | −≈10 | engine/coordinator |

After R1–R4 the full-grid sweep should reach **0 `coordinatorLaxer`** (or only a
small, explicitly-intended residual). That is the §6 evidence that unlocks Phase-2.

## 6. Acceptance → Phase-2

When the full-grid sweep is `coordinatorLaxer == 0` (benign already 0) AND a real
multi-turn run (the on-device `BAS_SHADOW_PARITY=enabled` path) corroborates it,
**Phase-2 becomes designable** as a separate ADR: flip `.coordinatorLaxer` to a
live halt, because by then a `.coordinatorLaxer` would signal a TRUE coordinator
laxness (not an unreconciled-semantics artifact).

## 7. Honest scope

- **This ADR:** design only — no code. It maps the reconciliation from measured
  data; it builds nothing and reopens no closed wall.
- **R1** is the high-leverage, clearly-correct fix (resolves 83%) but is a
  **sovereign change** to the verdict engine — it needs its own focused, reviewed
  implementation with the sweep as the gate.
- **R2–R4** adjust the coordinator lattice / engine soft band; smaller, also
  gated.
- **Phase-2 (the halt) stays CLOSED** until R1–R4 land and the sweep is clean.
- This does not touch #2 (Ed25519 commit gate) — a separate sovereign arc.
