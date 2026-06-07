# ADR-024 — One Verdict Kernel (eliminate the two-authorities anti-pattern)

> **Status: ACCEPTED — Step 1 LANDED (ch1044 底层架构).** The foundational fix for
> the divergence ADR-022/023 surfaced. ADR-023 *reconciles* two verdict
> implementations; this ADR removes the reason they can drift at all — it factors
> the engine's verdict logic into ONE pure, synchronous **rule kernel**
> (`BASSovereignVerdictEngine.evaluateLevel`) that every verdict authority can
> share. Step 1 (extract the kernel, byte-equal) has landed.

## 1. The real problem (architectural, not tactical)

There are **two implementations of the verdict logic**:
- the coordinator's hand-rolled `computeVerdictDecision` (sync, inline, the
  production path), and
- the engine's BR-001..BR-012 `BASSovereignVerdictEngine.evaluate` (async, the
  "principled" path the SDK signs warrants with).

The ADR-022 §8 sweep measured them diverging **~46%** on adversarial turns. ADR-023
plans to *reconcile* them (R1–R4). But reconciliation alone is a band-aid: **two
implementations of the same rules WILL drift again** — every future rule change
must be mirrored in both, forever. That is the two-sources-of-truth anti-pattern.

## 2. The fix: one kernel, thin adapters

Factor the verdict RULES into a single pure function and let every authority be a
thin adapter over it:

```
                ┌───────────────────────────────────────────┐
                │  evaluateLevel(context) -> LevelDecision    │   ← THE kernel
                │  (hard rules + level + evidence upgrade;    │     pure · sync ·
                │   no IDs, no clock, no ledger)              │     deterministic
                └───────────────────────────────────────────┘
                   ▲                 ▲                    ▲
   engine.evaluate │   coordinator   │   parity shadow   │
   (+IDs/clock/    │   adapter       │   (sync, no        │
    ledger append) │   (rich → ctx)  │    ledger)         │
```

With ONE rule implementation, **accidental drift is impossible by construction**.
Any residual shadow divergence is then attributable ONLY to the *projection* (the
lossy rich→primitive mapping), which is a known, separately-governed concern —
not silent rule drift.

## 3. Step 1 — LANDED: extract the kernel (byte-equal)

`BASSovereignVerdictEngine.evaluate(_:)` was split:
- **`public func evaluateLevel(_ context) -> LevelDecision`** — the pure sync
  kernel: Stage-1 hard rules + (routed/Swift) level + the evidence-insufficient
  upgrade + reason codes + revoked permissions. **No verdict/audit IDs, no
  `now()`, no ledger append.** Deterministic.
- **`evaluate(_:) async throws`** now = `let d = evaluateLevel(context)` + build
  the signed `BASSovereignVerdict` + audit entry (the IDs/clock) + the async
  ledger append (the BR-012 fail-closed). **Byte-equal** — verified by all **41
  engine tests** (`BASSovereignVerdictEngine` 24 / `BASObservationReconciliation`
  15 / `Chapter753Flip` 2) + the 14 parity-shadow tests, 0 failures.

This change is purely structural: `evaluate`'s output is unchanged. It introduces
the single source of truth without yet rewiring any consumer.

## 4. Steps 2–4 (the unification path — future, gated)

- **Step 2 — decide the kernel's canonical rules (= ADR-023 R1–R4).** The kernel's
  rules must be the *agreed* rules. ADR-023's reconciliation is exactly "what the
  kernel should compute" (e.g. R1: missing-lineage → `shadowLock`, not
  `deadStop`). Land R1–R4 *into the kernel*.
- **Step 3 — the coordinator adopts the kernel.** Replace `computeVerdictDecision`
  with a thin adapter: rich frames → `VerdictContext` → `evaluateLevel`. This
  CHANGES the production verdict to the kernel's (≈46% of adversarial turns today),
  so it is gated on Step 2 + the full-grid sweep reaching `coordinatorLaxer == 0`,
  behind an opt-in flag with a byte-equal-off escape, per ADR-014. The legacy
  hand-rolled lattice is deleted only once the adapter is proven.
- **Step 4 — the parity shadow uses the kernel directly.** `shadowVerify` can call
  `evaluateLevel` (sync) instead of `verifier.verify` → `engine.evaluate` (async,
  which today builds a throwaway ledger + appends per check). This makes the
  shadow fully side-effect-free and cheaper. Small, safe; do after Step 1 settles.

## 5. Why this is the elegant end state

- **One source of truth** for the most safety-critical logic (the verdict).
- **Drift becomes impossible**, not merely patched — Step 2's reconciliation is
  permanent because there is one place for the rules to live.
- **Defense-in-depth, if wanted, becomes INTENTIONAL** (an explicit extra check
  layered on the kernel) rather than the current *accidental* divergence.
- The kernel is pure + sync, so the shadow (and a future inline cross-check) need
  no async/ledger — the comparison is cheap and side-effect-free.

## 6. Red-line / discipline

- **Step 1 is byte-equal** (41 engine tests). It changes no verdict.
- **Step 3 is the only behavior-changing step** and is the most dangerous (it
  swaps the production verdict authority). It stays CLOSED until Step 2's
  reconciliation lands and the full-grid sweep is clean, and even then ships
  opt-in / byte-equal-off / sweep-gated. No verdict authority is swapped on a hunch.
- Touches `BASSovereign` (the safety spine) — every step is a reviewed sovereign
  change with the engine + sweep tests as the gate.

## 7. Honest scope

- **Landed:** Step 1 — the `evaluateLevel` kernel + `LevelDecision`, byte-equal.
- **Designed (this ADR):** the one-kernel architecture + Steps 2–4.
- **Not done (deliberately):** Steps 2–4 — Step 2 is ADR-023's reconciliation;
  Step 3 (coordinator adoption) is the behavior-changing, sweep-gated step that
  actually removes the duplication; Step 4 is the shadow simplification.
- Relationship: ADR-024 supplies the *mechanism* (one kernel) that makes ADR-023's
  *content* (the agreed rules) permanent. Neither touches #2 (Ed25519, DEFER-1).

## REFRAME (post-ch1044) — Steps 2–3 are SUPERSEDED; Step 4 is an optional, deferred tidy

Re-examined against ADR-023 §8's FINAL reframe **and the actual code**, Steps 2–3 do not survive — for
two independent reasons:

1. **Overtaken by the keep-both ruling.** Step 2 was "land ADR-023 R1–R4 into the kernel." But R1 was
   implemented, **REVERTED**, and operator-ruled **KEEP BOTH**: the engine's strict verdict (e.g.
   missing-lineage → `deadStop`) is a deliberate INDEPENDENT BACKSTOP; the coordinator's recoverable
   verdict (→ `shadowLock`) is the production path. ADR-023's FINAL reframe established that **100% of the
   886 divergences are intentional engine strictness** and ABANDONED engine-parity-as-a-halt-gate. There
   are no "agreed reconciled rules" left to land — the two authorities are MEANT to differ.

2. **Infeasible by construction (input-granularity mismatch).** Step 3 was "the coordinator adopts the
   kernel" (rich frames → `VerdictContext` → `evaluateLevel`). But `computeVerdictDecision` reasons over
   RICH domain frames (`riskCard.riskLevel`, `actionPermit.mode`, `emergencyBrake.brakeLevel`,
   `budgetFrame.runMode`, kill-switches) while `evaluateLevel` reasons over PROJECTED primitives
   (BR-001..012 booleans + soft-signal scalars). The rich→primitive projection is **lossy by nature** —
   that lossiness IS the ~46% divergence (§2). So `evaluateLevel(project(richframes)) ≠
   computeVerdictDecision(richframes)`: the coordinator cannot adopt the kernel byte-equally (it would
   CHANGE the production verdict to the engine's stricter one — exactly what keep-both forbids), and a
   "coordinator profile" taking rich frames would not share the engine's kernel at all — it would merely
   relocate `computeVerdictDecision` into `BASSovereign` for zero benefit and real risk.

**The achievable end-state is already in place** — drift is handled on BOTH sides WITHOUT a single shared
kernel:
- **Engine side:** ONE kernel (`evaluateLevel`, Step 1) is the single source for every engine-side
  consumer (the parity shadow, warrant signing). No engine-side drift.
- **Coordinator side:** `BASCoordinatorConsistencyCheck` (shipped, ADR-023 §8) re-derives the
  coordinator's verdict from its OWN settled state and flags a stored verdict laxer than its own rules —
  the real coordinator-regression detector (NOT engine-parity).

**Step 4 (shadow uses `evaluateLevel` sync) is the only residual**, and the original draft undersold it as
"small/safe." The shadow report holds a FULL `BASSovereignVerdict`, so a clean sync path needs the verdict
CONSTRUCTION factored out of the async `evaluate` (the IDs/clock part separated from the ledger append).
The shadow consumes only level + reasonCodes (both already from `evaluateLevel`), so the gain
(side-effect-free, no throwaway ledger) is real but MODEST. **Deferred** — touching the safety-critical
verdict engine for a modest non-safety observability gain is not worth the churn (亏的不要上); revisit
only if the shadow's ledger side-effects become a measured problem.

**Net:** Step 1 stands and is load-bearing. Steps 2–3 are CLOSED (superseded by the keep-both architecture
+ the input-granularity reality). Step 4 is an optional, deferred tidy. The "two-authorities anti-pattern"
this ADR set out to remove turned out, on rigorous analysis, to be the INTENDED production-path +
independent-backstop design — not an accident to unify away.
