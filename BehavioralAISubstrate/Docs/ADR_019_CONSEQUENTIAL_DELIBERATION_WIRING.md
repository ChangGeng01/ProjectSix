# ADR-019 — Consequential Deliberation Wiring

> **Status: DESIGN (not implemented).** Companion to ADR-018. Defines how to
> make the deliberation loop (ADR-018 P1) actually change a decision, safely,
> after the ch1039 deep audit proved it is decision-inert in practice.
> Implementation is a future focused session — parts of it are sovereign-gated.

## 1. Context — what the deep audit established

ADR-018 P1 shipped a deliberation loop that is **safe** (byte-equal when the
opt-in flag is off), **mechanically correct**, and **well-tested**, but whose
refinement is **decision-inert in practice** (ADR-018 §7.4):

- **Selection path is clamped.** The loop's only effect is a uniform,
  non-accumulating +0.05 `confidence` bump on surviving candidates. Selection
  consumes confidence only via `egoScore`, which clamps at `confidenceCeiling`
  = 0.64; default candidates are already ≥0.64 → the bump is clipped → net
  `mergedScore` delta = 0. A uniform shift also can't move an argmax / ranking
  / the `scoreGap` agency threshold. **Selection never changes.**
- **Risk path is wired but sub-threshold.** The +0.05 DOES propagate to
  `confidenceFloor` (= `min` over candidates of `confidence − penalties`,
  `buildUncertaintyLedger`), which `calibrateRisk` consumes
  (`if confidenceFloor < 0.55 { riskIncrement += 0.03 }`,
  `EBrainHostRuntime+RiskService.swift:671`; and `supportLevel`, `:302`). But
  for default values the floor (~0.27) is far below the 0.55 gate, so the risk
  **outcome** is unchanged. Pinned by `testActivatesAndRefinesViaRealHost
  RuntimePath`: `on.confidenceFloor == off.confidenceFloor + 0.05` AND
  `on.riskLevel == off.riskLevel`.
- **Per-pass work is hollow.** Each `runDeliberationPass` re-runs an identical
  deterministic `iterate` then applies the +0.05 once, so the frame **saturates
  after pass 2** (idempotent). A budget of 3/4/5 produces byte-identical output.

**Two consumers already exist** (`confidenceFloor → :671`, `evidenceDebt →
:677`, `stabilityScore → supportLevel :302`). So the gap is **NOT a missing
consumer** — it is (a) the loop does no substantive per-pass work, and (b) its
token +0.05 on the wrong-for-selection signal is sub-threshold for risk.

## 2. Problem

Make a deliberation signal change a real decision, subject to:
- **红线 7 / ADR-014:** byte-equal when the opt-in flag is off.
- **Guardrail safety:** must not silently weaken the calibration ceiling
  (overconfidence) or the auto-merge friction (autonomy) — those are
  sovereign-relevant.
- **No fatigued core-logic surgery:** selection/risk/agency are the substrate's
  highest-stakes paths; changes need careful design + sovereign review.

## 3. Options considered

| # | Option | Verdict |
|---|---|---|
| A | Relax `egoScore` `confidenceCeiling` under the flag so the bump survives into selection | 🔴 touches a calibration/humility guardrail (overconfidence); sovereign-adjacent |
| B | Differential bias (reinforce only the surviving leader / weight by evidence) to move `scoreGap`/argmax | ⚠️ still clipped by the 0.64 ceiling unless combined with A; "which to favour" is a value choice |
| C | **Substantive per-pass refinement** feeding the EXISTING risk consumers (`confidenceFloor`/`evidenceDebt`/`stability`) | ✅ chosen — no new consumer, no guardrail relaxation in the safe direction |
| D | Wire loop-convergence into the agency-reservation (relax auto-merge friction) | 🔴 sovereign — changes when the host acts autonomously (ADR-018 P4 territory) |
| E | Render-only (explanation mentions deliberation) | marginal — changes output text, not the decision |

## 4. Decision — substantive refinement → existing risk consumers, safe-direction first

**Core decision:** the loop becomes consequential by doing **real per-pass work
that resolves (or fails to resolve) uncertainty**, surfaced through the signals
risk ALREADY consumes — NOT by a token confidence bump and NOT (initially) by
relaxing any guardrail.

- **The real lift is substantive per-pass refinement.** Today every pass is
  identical. A consequential pass must actually change the uncertainty picture:
  e.g. relax/tighten candidate constraints, re-query memory for the
  `requiredEvidence` driving `evidenceDebt`, or explore a new candidate. Each
  pass should move `evidenceDebt` ↓ / `confidenceFloor` ↑ **only when it
  genuinely resolves something** — otherwise leave them (so failure-to-resolve
  is itself a signal). This is a real reasoning-capability addition, not a
  scoring tweak.
- **Safe direction (P1.5a, no sovereign gate):** deliberation that does NOT
  resolve — runs to budget with `confidenceFloor` still low / `evidenceDebt`
  still high — feeds **more caution** through the existing `:671`/`:677`
  increments. This is safety-positive (genuine uncertainty → act carefully) and
  needs no guardrail relaxation. The wiring already fires; the loop simply makes
  the signal *honest* (a converged loop earns its lower caution; a stuck loop
  keeps it high).
- **Dangerous direction (P1.5b, SOVEREIGN-GATED):** deliberation that DOES
  resolve → higher floor / lower debt → LESS caution (`:671` stops firing) or,
  via option A/D, a different selected candidate / relaxed auto-merge. This lets
  deliberation reduce safety friction and can be "trained bad," so it is gated
  exactly like ADR-018 P4: L14 sovereign veto, a bounded per-turn cap
  (±0.05-class), replay-determinism, high-confidence-auto / low-confidence-human.

## 5. Red-line proofs (for the future implementation)

- **flag OFF → byte-equal.** The loop doesn't run; no refinement signal is
  produced; `confidenceFloor`/`evidenceDebt` are exactly today's. Identity sweep
  + `loopCount==1` pin hold.
- **P1.5a safe direction is monotonic-toward-caution.** A test must show: a
  crafted non-resolving deliberation (floor parked just under 0.55) keeps the
  `:671` increment, while the same turn with the loop off is unchanged — i.e.
  the loop can only ADD caution, never remove it, in P1.5a.
- **P1.5b is sovereign-bounded.** nil/withheld sovereign → identity; veto
  blocks; the caution-REDUCING delta is capped and replay-deterministic; a
  test must show the sovereign veto path neutralizes it.
- **No silent guardrail change.** P1.5a must NOT alter `egoScore`'s
  `confidenceCeiling` or the auto-merge `scoreGap` threshold; only P1.5b may,
  and only under the sovereign gate.

## 6. Phasing

| Phase | Scope | Risk | Gate |
|---|---|---|---|
| **P1.5a** | Substantive per-pass refinement (evidence re-query / constraint relax) + safe-direction wiring (non-resolution → existing caution increments) | MED (touches risk-signal production, not the gates) | opt-in flag; byte-equal-off |
| **P1.5b** | Resolution → reduced caution / changed selection (option A/B/D) | HIGH (weakens a guardrail) | L14 sovereign + caps + replay-determinism + human-in-loop |

Ship P1.5a first — it makes the loop consequential in the SAFE direction with no
guardrail risk, and it is the honest realization of "deliberation that can't
resolve → be careful." P1.5b is the dangerous half and waits for the sovereign
machinery (it shares the ADR-018 P4 gate).

## 7. Honest boundary

- This is **design, not implementation.** The hard part — substantive per-pass
  refinement that genuinely resolves uncertainty — is a real reasoning
  capability, not a scoring tweak; it deserves a fresh focused session with
  TDD + full sweep + (for P1.5b) sovereign review.
- The current ch1039 loop stays as-is (safe, opt-in, decision-inert in
  practice, honestly documented in ADR-018 §7.4 + SCAFFOLD_VS_WIRED). Nothing
  here is shipped yet.
- **This unblocks P2 too.** ADR-018 P2 (ShadowTrial cross-turn feedback) would
  hit the same wall — its feedback would be computed but unconsumed — unless a
  consequential-wiring path like this exists. P1.5a's "produce a real signal →
  feed an existing consumer (safe direction)" pattern is the template P2's
  feedback should follow.

## 8. Critical files (for implementation — NOT touched by this ADR)

- `Sources/BASHostKit/BASDeliberationBias.swift` (today's token bias — to be
  replaced/augmented by substantive refinement)
- `Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift` (the loop, ~:254-277)
- `Sources/BASOrchestration/EBrainNeuralMaterializationCore.swift`
  (`buildUncertaintyLedger` confidenceFloor, `buildEvidenceDebts`,
  `buildConvergenceCertificate` stabilityScore — the signals)
- `Sources/BASHostKit/EBrainHostRuntime+RiskService.swift` (`:671` confidenceFloor
  gate, `:677` evidenceDebt gate, `:302` supportLevel — the existing consumers)
- `Sources/BASHostKit/EBrainHostRuntime+TriSelfService.swift` (`egoScore` ceiling
  `:42`, `scoreGap` agency threshold `:351` — P1.5b only, sovereign-gated)

## 9. Architectural root cause — the substrate is clamp-dominated (ch1040)

Scoping a *clean* P1.5a implementation surfaced WHY the loop resists becoming
consequential, and it is not a loop defect — it is a pervasive substrate
property. **The substrate clamps small perturbations at every decision seam**
(a deliberate stability/safety feature — it resists small manipulations):

- **Selection:** `egoScore` clamps candidate confidence at `confidenceCeiling`
  (0.64); default candidates are already ≥0.64 → confidence above it is ignored.
- **Risk:** `calibrateRisk` gates on thresholds (`confidenceFloor < 0.55`,
  `maxDebt >= 0.5`) → a sub-threshold nudge changes nothing.
- **Candidate set:** `proposePaths` returns `…prefix(maxCandidates)` AND
  `normalizeThoughtFrame` re-clamps to `maxCandidates` → a surfaced extra
  candidate is dropped at TWO points.

So a deliberation signal that moves a value by a *small* amount (the ±0.05-class
bias, a single re-query, one widened candidate) is **structurally damped** — it
cannot cross any clamp/threshold, so no decision changes. Every P1.5a mechanism
tried (confidence bias, risk-caution, frontier-widening) dies on a clamp.

**This is the real constraint:** a consequential deliberation effect must be
EITHER (a) a **threshold-crossing** perturbation — large enough to flip a gate
(e.g. move `confidenceFloor` across 0.55, a ~0.28 swing — semantically extreme
and itself risky), OR (b) a **clamp/threshold change** (raise the egoScore
ceiling, relax the candidate prefix, lower a risk gate — all guardrails →
sovereign-gated, P1.5b). **There is no small, clean, safe consequential slice:
the architecture forbids it on purpose.**

**Honest implication for execution:** the right consequential-wiring is NOT a
bias tweak — it is either (i) a *substantive* refinement that genuinely resolves
enough evidence to legitimately move a signal a real (threshold-crossing)
amount, or (ii) a deliberate, bounded, sovereign-gated change to a specific
clamp/threshold (P1.5b). Both are careful focused-session work. Rushing a
clamp-fighting hack would produce an **inert** (sub-threshold) feature — the
ch1039 cosmetic failure repeated — or an **unsafe** (clamp-breaking) one. The
ch1040 work therefore stops at this finding rather than ship either.
