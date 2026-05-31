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
