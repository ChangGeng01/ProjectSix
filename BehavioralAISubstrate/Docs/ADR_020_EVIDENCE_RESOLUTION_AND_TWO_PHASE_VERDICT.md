# ADR-020 — Evidence-Resolving Deliberation + Two-Phase Verdict

> **Status: IN PROGRESS.** Successor arc to ADR-018/019. After the consequential-
> wiring arc landed the SAFE levers (reversibility-tilt §13, caution-up §11) and
> closed the dangerous one (P1.5b caution-reduction, §14 — architecturally
> incompatible), the user selected BOTH remaining build directions:
> (2) a knowledge-retrieval capability so the loop's passes GENUINELY resolve
> uncertainty, and (3) a two-phase verdict (a pre-render gate distinct from the
> post-render audit). Two independent adversarial architect passes (Opus) produced
> code-grounded plans; this ADR is their synthesis + the execution record.

## 1. The convergent finding (both passes, independently)

**The dangerous endpoint stays closed.** Both plans independently concluded that
deliberation driving caution *below the loop-off baseline* — the true P1.5b /
"resolve → less caution than a no-loop turn" goal — remains **architecturally
unsafe** on the current pipeline:

- Arc-2 pass: "earning the reduction with real evidence does NOT lift the §14
  blocker — the blocker is structural (verdict-after-render), not justificatory."
- Arc-3 pass: even a *faithful pre-render forecast* of the verdict does not help,
  because the AUTHORITATIVE verdict at `RunTurn:1052` still reads the
  already-reduced card; the forecast is a prediction, not an authoritative veto.

So a real below-baseline reduction would require a **render-and-verdict replay**
(re-run `:856–1052` on the un-reduced card when the post-render verdict vetoes) —
MED-HIGH spine blast radius, replay-determinism-sensitive, sovereign-gated. **It
is deferred as its own future ADR, NOT built here.**

## 2. The §14 correction (Arc-3 pass — important)

ADR-019 §14 framed the blocker as "the verdict needs the render." That is
**imprecise.** Tracing every input of `buildSovereignVerdict`
(`EBrainRuntimeCoordinator+SovereignVerdict.swift`): the escalation *level* is a
pure function of `(policyLineage, budgetFrame.runMode, riskCard.riskLevel,
actionPermit.mode, emergencyBrake.*, request.activeKillSwitches,
needsProtectedWriteLane)`. **Six of seven are settled by `RunTurn:807` — before
render (:856).** Only `needsProtectedWriteLane` (via `updateTickets`) is
render-derived, and even it is dominated by `actionPermit.mode`. The trace/fold
arguments contribute only IDs and quarantine/rollback *ref strings* to the
output — never the level.

**Corrected statement:** the verdict's level is *mostly render-independent*; the
real circularity for a *reduction* is "**a reduction at the card poisons the
authoritative verdict's own `riskLevel` input**," not "the verdict needs the
render." This is why a faithful pre-render provisional verdict IS buildable (it
reproduces the level from pre-render inputs) yet still cannot safely *gate a
reduction* (the authoritative verdict downstream sees the reduced card anyway).

## 3. The SAFE scope (what this ADR builds)

### Arc 2 — Evidence-resolving deliberation (knowledge-retrieval)
Make the loop's passes GENUINELY resolve uncertainty, consequentially + safely:
- **Matchable memory:** store evidence *content* immutably (new `BASEvidenceAtom`
  type + a defaulted-optional `BASMemoryBundle.resolvedEvidence`), never touching
  the existing signal-count atoms.
- **Typed-key retrieval (anti-"theater"):** match a turn's `requiredEvidence`
  against stored evidence by an EXACT normalized key derived from the
  *already-structured* `unknownSet` fields (`missingFacts/Roles/Constraints`,
  `unresolvedPermissions`) — NOT fuzzy prose. No accidental resolution; replayable.
- **Consequence (SAFE direction only):** a resolved item shrinks a candidate's
  `requiredEvidence` → `evidenceDebt` drops below the 0.5 gate + the `delayRight`
  agency reservation (−0.05) no longer forms → `courtSignals.riskIncrement` falls
  → the bound card can step DOWN a band. **Hard-floored at the loop-off baseline**
  (`final_totalRisk = max(off_baseline, loop_adjusted)`): genuine resolution
  *withholds the loop's own added caution*, never subtracts baseline caution. So
  "caution only ratchets up vs baseline" (§14 invariant) holds, no sovereign gate
  needed, and it is consequential (resolved-vs-stuck land in different bands).
- A second lever the pass surfaced: emptying the *selected* candidate's
  `requiredEvidence` removes the `delayRight` agency reservation (−0.05) via a
  different mechanism than the debt gate — both flow through `courtSignals`.

### Arc 3 — Two-phase verdict (pre-render provisional signal)
Build a faithful pre-render provisional verdict as an **inert, opt-in,
observation-only** artifact (NOT a gate on any reduction — see §1):
- Reuse the extracted render-independent level core (Phase A) to compute a
  `BASProvisionalVerdict` from pre-render-settled inputs + a conservative
  `provisionalNeedsReview` proxy.
- Wire it behind `deliberationLoopEnabled` at `RunTurn:807` so it **mutates
  nothing the render/seals/verdict/hashes read** — emitted only to a nil-default
  handler / a brand-new reserved-key observation. Byte-equal off AND inert when on.
- Honest contract: `provisionalLevel == finalLevel` for the production evolution
  service; a conservative lower-or-equal bound otherwise.

## 4. Sequenced execution (safest-first; each step byte-equal-off + TDD)

| Step | Slice | Risk | Status |
|---|---|---|---|
| **1** | **Phase A** — extract render-independent `computeVerdictDecision` (pure) | **zero** (byte-equal *unconditionally*) | **see §5** |
| 2 | Arc-2 latent plumbing — `BASEvidenceAtom`/`Ledger`/`Matcher`/`Storing` + defaulted-optional fields + coordinator slot (dormant) | very low (dormant) | pending |
| 3 | Arc-3 Phase B/C — `buildProvisionalVerdict` + inert observation-only wiring at `:807` | low (one off-gated, mutation-free seam) | pending |
| 4 | Arc-2 retrieval → write-back → floored caution-withholding | medium (opt-in, byte-equal-off) | **checkpoint with sovereign before starting** |
| 5 | Borderline fixture + ADR/SCAFFOLD status flips | docs | pending |

**Excluded (confirmed unsafe, §1):** below-baseline reduction (Arc-2 caution-DOWN)
and verdict-gated reduction (Arc-3 "Phase D"). Both need the render-and-verdict
replay → a separate sovereign-gated ADR.

## 5. Phase A — verdict-decision extraction (LANDING)

`EBrainRuntimeCoordinator+SovereignVerdict.swift`: the `raise(...)` escalation
lattice is extracted into `computeVerdictDecision(...) -> BASSovereignVerdict
Decision`, a pure function of the render-independent value objects + the
caller-derived `needsProtectedWriteLane` bool + opaque `quarantineSources`/
`rollbackSource` ref strings. `buildSovereignVerdict` now derives those three,
calls the core, then does the unchanged `userStubMode` + ID/expiry/ordering
assembly. Behavior-preserving extract → **byte-equal unconditionally** (no flag);
the full sweep is the proof.

## 6. Red-line (红线 7) + test strategy

- **Phase A:** byte-equal *unconditionally* → full `swift test` sweep unchanged at
  14,656 / 0 IS the proof (no flag, no fixture needed).
- **Later opt-in steps:** flag-off → branch skipped → byte-equal sweep; plus a
  flag-ON-but-empty-store / inert-observation identity test proving the new paths
  are purely additive on top of the existing opt-in behavior; plus replay-
  determinism (exact-key matching is deterministic) and an anti-"theater" test
  (a near-miss prose pair must NOT match).
- The `loopCount==1` pin + canonical identity + byte-equality-proof sweeps stay
  green at every step.
