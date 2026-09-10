# Qinao Manifesto v6 — Self-Evolution Without Drift

> The system can update itself.
> But the shape of how it updates itself does not.

**Status**: target doctrine spec, additive on top of v1–v5. Authored
2026-05-02 (M345) after M341 supplied the regression-gate leg of the
v5 triple for the L13 self-evolution candidate. v6 makes a substantive
runtime promise; v5 was the framing axis that made this authoring
permissible.

**Source of authority**: implementation-grounded — every claim is
bound to a typed primitive, a measurement, and a regression gate
(per v5 doctrine triple).

---

## §1 The promise

The substrate carries a self-evolution lifecycle (L13, the evolution
furnace). It owns the path from `proposed` → `candidateRegistered`
→ `shadowTrialing` → `trialFinalized` → `promoted`, and from
`promoted` → `retracted` (the only post-promotion exit), plus
explicit `withdraw` and `fail` paths that lead to terminal stages.

**v6 promises**: the *shape* of this lifecycle — the 8 stages, the
7 actions, the 11 transition edges, the terminal/non-terminal
partition — is a typed contract that cannot drift silently. Any
change to that shape (additive or destructive) requires a same-PR
update of the canonical fingerprint and an explicit doctrine review.

The system is allowed to evolve. The *shape* of evolution is not
allowed to evolve without consent.

---

## §2 The triple

| Leg | Primitive |
|---|---|
| Typed pin | `BASEvolutionLifecycleStage` (8 cases) + `BASEvolutionLifecycleAction` (7 cases) + `BASEvolutionLifecyclePolicy.validTransitions(from:)` |
| Measurement | M333 `EvolutionLoopDemo` traverses promotion + retraction + trial-failure + early-withdrawal paths in one demo run |
| Regression gate | M341 `BASEvolutionLifecycleStructuralFingerprint` with SHA-256 hash `9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5` and `detectDrift(live:pinned:)` typed reports |

A future PR that:
- Adds a stage: must extend `stageRawValues` in `canonical` + update
  the matrix + recompute the hash → all in the same PR.
- Removes a transition: same as above.
- Re-routes an edge (e.g., make `withdraw` reachable from
  `.promoted`): same as above. The drift detector fires before
  the test that exercises the new edge ever runs.

There is no silent path.

---

## §3 What v6 enforces

1. **Promotion is non-terminal.** `BASEvolutionLifecycleStage
   .promoted.isTerminal == false`; only `.retracted`, `.rejected`,
   `.withdrawn` are terminal. v6 pins this so a "once promoted,
   forever live" mistake cannot land.
2. **Retraction is the only post-promotion exit.** From `.promoted`
   only `.retract` is a valid action. `.withdraw` is rejected by
   policy. M341's `testPromotedHasOnlyRetractEdge` pins this
   structurally.
3. **Terminal stages have empty edge sets.** No escape from
   `.fullyDistilled` / `.retracted` / `.rejected` / `.withdrawn`.
   M341's `testTerminalStagesHaveEmptyEdges` pins this.
4. **History is un-erasable.** `BASEvolutionLifecycleSession.has
   ReachedPromotion` returns true after retraction (a retracted
   ticket once reached promotion). The structural pin includes the
   `hasReachedPromotion` invariant by virtue of the edge to
   `.retracted` originating from `.promoted` only.
5. **Lifecycle audit signal refs are doctrine-bound.** M305 ships
   `lifecycle.tickets:N` / `lifecycle.terminal:N` /
   `lifecycle.promoted:N` / `lifecycle.stages:<stages>` audit
   reasons; these become a stable telemetry contract for downstream
   consumers.

---

## §4 What v6 does NOT promise

- **Not behavioural quality.** v6 does not promise that the
  evolution candidates produced are *good*. Quality is the M326
  AI persona panel + M327 advisory + EB-2 domain-expert review
  territory.
- **Not training cycle convergence.** v6 does not promise that an
  evolution cycle terminates in a fixed number of stages. The
  promotion gate (`BASEvolutionPromotionGate`) is allowed to deny
  arbitrarily many candidates.
- **Not v3-typed-motherboard schema invariance.** v6 pins the
  *lifecycle structural shape*, not every field that lives inside
  `BASUpdateTicket`. Adding a field to UpdateTicket without changing
  the lifecycle stage/action/edge set does not require a v6
  fingerprint update.
- **Not external trained-weight provenance.** That's v1 invariant
  #3 territory, strengthened by M343 — see footnote in
  `QINAO_MANIFESTO_V5_DOCTRINE.md` §5.
- **Not unbounded retraction counts.** v6 does not promise that
  retraction is always available — host-level constraints (M11
  host constitution boundaries) may forbid retraction in specific
  domains.

---

## §5 How v6 composes with prior axes

| Axis | Composition |
|---|---|
| v1 #3 (host secrets stay out of base weights) | v6 reinforces by pinning the lifecycle that gates evolution → distillation. A retracted ticket cannot quietly slip back into the `.promoted` state and into distillation eligibility. |
| v2 (14 living net) | v6 lives at L13 (evolution furnace). The structural fingerprint is the L13 layer's promise; other layers' invariants are unchanged. |
| v3 (typed motherboard) | v6 IS a typed motherboard claim — the fingerprint is itself a typed schema. |
| v4 (agent fabric) | v6 is orthogonal — no seat in the 9-seat fabric exclusively owns the lifecycle; the lifecycle is a substrate primitive. |
| v5 (performance is doctrine) | v6 satisfies the v5 triple in full. v5 §4 prohibits authoring without a regression gate; M341 provides it. |

v6 does not weaken any v1–v5 invariant. It strengthens v1 #3 by
preventing a class of "lifecycle drift → unintended re-promotion"
mistakes.

---

## §6 What can falsify v6

The doctrine fails if any of the following becomes true:

1. The live `BASEvolutionLifecyclePolicy.validTransitions` returns
   a different table than the canonical fingerprint (without same-PR
   canonical update). M341's `testLiveFingerprintEqualsCanonical`
   fires.
2. A stage that should be terminal (per the partition) gains an
   edge. M341's `testTerminalStagesHaveEmptyEdges` fires.
3. `.promoted` gains a `.withdraw` edge or loses its `.retract`
   edge. M341's `testPromotedHasOnlyRetractEdge` fires.
4. The SHA-256 implementation in
   `BASEvolutionLifecycleStructuralFingerprintHasher` produces
   different hashes for the same input. M341's
   `testHashIsStableAcrossInvocations` fires.

Each is a CI-time falsification — v6 cannot survive a green test
suite that contradicts it.

---

## §7 Authoring boundary

This is v6, not v7 or v∞. Future axes that want to make claims
*about* L13 self-evolution must:

- Either inherit from v6 (adding ceiling claims like "evolution cycle
  must terminate in N stages") which requires its own measurement
  primitive + regression gate.
- Or operate at a different layer (v7 multi-instance distribution
  is one such — concerns multi-host audit ledger convergence,
  orthogonal to L13).

---

*Authored 2026-05-02 as M345 — direction "剩下的 一次性 解决" of the
内部加强完善 batch closure. v6 is the first manifesto axis to be
authored that satisfies the v5 triple from the moment of authoring
(typed pin via M341 / measurement via M333 / regression gate via
M341 drift detector). Future axes follow the same rule.*
