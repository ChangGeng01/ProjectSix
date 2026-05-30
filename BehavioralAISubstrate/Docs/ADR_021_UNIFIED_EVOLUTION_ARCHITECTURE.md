# ADR-021 — Unified Evolution Architecture (统一进化算法底层架构)

## 0. Status / lineage / scope

- **Status: ACCEPTED (DESIGN — not implementation).** Writing this down does NOT
  mean any new capability exists. It UNIFIES already-verified machinery into one
  coherent theory and proposes **NO new code** + reopens **NO closed wall**.
- **Date:** 2026-05-31 · **Chapters:** ch 1044 synthesis (design for future arcs).
- **Lineage:** successor synthesis to **ADR-018** (which designed the INNER
  per-turn deliberation loop). Consumes **ADR-019/020** consequential-wiring +
  closed-wall findings. Treats **ADR-006/012** (`Docs/ADR_006_*`, `Docs/ADR_012_*`)
  as the ONE sanctioned threshold-mutation gate.
- **Scope discipline (measure-before-core-change):** every slice this ADR maps is
  opt-in / default-OFF / byte-equal-by-construction / dormant-first (ADR-014). The
  user-confirmed deliverable for the chapter that introduced this ADR was **the
  design document only** — not even the safe O0 refactor was built.
- All `file:line` anchors were grep-verified at HEAD `77da024e2`.

---

## 1. Context — the gap ADR-018 §5 left open

ADR-018 §5 elegantly unified the **INNER** levers (thermal + calibration-drift +
uncertainty → one `deliberation_budget`; dream-loop tally → candidate bias) and
shipped it opt-in (**P1 LANDED**). But it **explicitly punted the OUTER loop**:
> "The evolution points (2 / 4 / 5) are the **slower outer learning loop** that
> feeds back into `deliberation_budget` and the candidate bias — they are not in
> the hot per-turn loop." (ADR-018 §5)

That outer loop was never given an architecture. Yet since ADR-018, **two
outer-loop instances landed ad-hoc** — ShadowTrial N→N+1 (ADR-018 §10) and
evidence-resolution withholding (ADR-020 §4) — both using ONE un-named idiom (a
host-held carrier slot-IN + a pure fold + an `@Sendable` sink-OUT, all default-nil
→ byte-equal). **The gap this ADR fills: working instances exist, but the theory
was never written.** ADR-021 supplies it.

---

## 2. The two-loop unified model (整体逻辑)

One architecture, two nested loops over the same stateless coordinator:

- **INNER (per-turn, hot, LANDED — ADR-018 §5):**
  `deliberation_budget = f(thermal, drift, uncertainty)`;
  `repeat { iterate(biased_costs) } while pass < budget`
  (the loop in `EBrainRuntimeCoordinator+RunTurn.swift`, gated by
  `deliberationLoopEnabled`).
- **OUTER (cross-turn, slow — the architecture this ADR names):**
  `outcome(turn N) → fold into a host-held EXPERIENCE CARRIER → re-inject at turn
  N+1 → bias that turn's budget + candidate costs + caution.`

The coordinator stays a **value-type `struct`** (`EBrainRuntimeCoordinator.swift:20`,
confirmed) with **no cross-turn state** — ALL evolution state is **host-held** and
re-injected each turn. The loops compose cleanly because **the outer loop only
ever tunes the inner loop's INPUTS** (budget / candidate costs / caution) — it
never touches the safety spine and never auto-mutates policy (§3, §4).

### 2.1 The single outer-loop skeleton (the one pattern)

```
                  ┌──────── OUTER LOOP (cross-turn, host-held) ────────┐
                  │                                                    │
 turn N: runTurn ─┤                                                    │
   │  INNER LOOP  │   result.<sink-OUT>  ──►  HOST: persist + fold     │
   │  (ADR-018):  │        (@Sendable,            (experience          │
   │  repeat{     │         default nil)           carrier)            │
   │    iterate(  │                                    │               │
   │     biased)  │                                    ▼               │
   │  } while     │   coordinator.<slot-IN> ◄──  HOST: re-inject       │
   │  pass<budget │        (default nil →           (turn N-1's        │
   │              │         identity → byte-equal)   folded state)     │
   │              │            │                                       │
   │              │            ▼                                       │
   └─ biased ◄──── pure fold(carrier) → budget · costs · caution bias  │
                  │                                                    │
                  └────────────────────────────────────────────────────┘
  NEVER-EFFECTIVE-SAME-TURN by construction: a slot-IN only ever holds turn N-1's
  state — the turn-start read happens far upstream of where turn N's own outcome
  is built, so a turn can never evolve on its own result (ADR-018 §10).
```

### 2.2 The four scattered mechanisms are ONE pattern (the unification)

Each is the SAME triple — `(enable-flag, slot-IN carrier, @Sendable sink-OUT)`
defaulting to `(false, nil, nil)` → identity → byte-equal — closed by a pure fold.
They differ ONLY in payload + fold function (verified: the triples co-exist on the
coordinator):

| Mechanism | enable-flag / slot-IN / sink-OUT | pure fold | status |
|---|---|---|---|
| ShadowTrial N→N+1 | `shadowTrialFeedbackEnabled` (`EBrainRuntimeCoordinator.swift:191`) / `pendingTrialLedgerIn` (`:200`) / `resolvedTrialSink` (`:210`) | `BASShadowTrialFeedbackLedger.evaluate(_:using:)` (`BASShadowTrialFeedbackLedger.swift:100`; identity-on-terminal `:106`) | **LANDED** (ADR-018 §10) |
| Evidence resolution | `deliberationLoopEnabled` / `evidenceLedger` (`:171`) / `resolvedEvidenceSink` (`:180`) | `BASDeliberationResolutionCredit` (ADR-020 §4) | **LANDED** |
| Dream-loop tally | *(proposed)* `candidateTypeSuccessTally` | `score_candidate` (`Cargo/bas-dream-loop/src/lib.rs`, pure; Swift `BASAutoRouteRanker.dreamLoopBatchScore:3058`, **0 prod callers**) | **DORMANT** (O1) |
| Lifecycle transitions | *(proposed)* `BASEvolutionLifecycleSession` carrier+sink | `session.applying(_:)` (immutable) | **observation-only** (O2) |

**Claim:** the outer loop is ONE pattern instanced four ways — exactly as ADR-018
§5 unified the inner levers into one budget. (The ADR-020 two-phase provisional
verdict is the same pattern degenerate to a read-only sink-only forecast.)

---

## 3. Outer-loop elegance principles (extends ADR-018 §5's three)

ADR-018 §5 gave: (1) reuse telemetry, build no new structures; (2) opt-in gate =
red-line preserved by construction; (3) unified, not isolated. For a LEARNING loop
ADR-021 adds:

4. **Empty experience = identity.** A nil carrier folds to the no-op bias →
   byte-equal — the exact mechanism the two landed instances already use. Learning
   that has learned nothing changes nothing.
5. **Bias DELIBERATION/SELECTION, never auto-derive POLICY (不变量 #2 神经不掌权).**
   The fold may tune budget, candidate ordering/cost, and caution-UP only. Any
   THRESHOLD / policy change MUST route through the sanctioned ADR-006/012 gate
   (`BASRiskCalibrationGate.replace`, `…Gate.swift:153`; operator-authored +
   L14-warranted `sovereignWarrantRef` `:209` + ±0.25-clamped, between-deploy). The
   outer loop NEVER auto-mutates policy. P4 is the forbidden inverse (ADR-018 §12).
6. **Replay-determinism via explicit input.** The carrier is an explicit
   coordinator input, not hidden state; same carrier + same request → same turn.
7. **Host owns the cycle; coordinator stays stateless.** Cross-turn state lives in
   the host (no per-turn coordinator init — ADR-018 §10's correction). This is what
   makes NEVER-EFFECTIVE-SAME-TURN *structural* rather than a runtime check.

---

## 4. The safe / gated / closed axis (the core 整体逻辑)

**Generating principle (最极致最优雅):** *an evolution effect is **FREE** (no gate)
iff it can only ratchet caution UP or pick a safer action; **GATED** iff it could
relax a guardrail; **CLOSED** iff relaxing that guardrail is unsafe-by-construction
(no safe gate exists).* The safe surface and the forbidden surface come from ONE
axis — **"does it monotonically increase conservatism?"** — not two unrelated
lists. Caution is a one-way ratchet here (ADR-019 §14: verdict-after-render makes
reduction structurally unsafe); this axis is the formal statement of that
asymmetry. The boundary IS the architecture.

### 4.1 Every mechanism mapped onto the single axis

| Mechanism | Direction | Verdict | Why (file:line / ADR) |
|---|---|---|---|
| Deliberation depth (inner budget) | more thinking | **SAFE** | depth only; `deliberationLoopEnabled` opt-in (ADR-018 P1) |
| Thermal floor on budget | fewer passes when hot | **SAFE** | only LOWERS maxLoops — `BASDeliberationThermalFloor.flooredMaxLoops` (`…ThermalFloor.swift:55`) (ADR-018 §11) |
| Reversibility-tilt (selection) | safer action | **SAFE** | strictly-more-reversible only — `applyReversibilityTilt` (`EBrainHostRuntime+TriSelfService.swift:41`) (ADR-019 §13) |
| P1.5a caution-up | caution ↑ on uncertainty | **SAFE** | monotonic-toward-caution, post-binding (ADR-019 §11) |
| Evidence-resolution withholding | withholds loop's OWN added caution | **SAFE** | floored to ≤ own increment (ADR-020 §9) |
| ShadowTrial N→N+1 | observation-only | **SAFE** | sink-only, gates nothing (ADR-018 §10) |
| Dream-loop candidate-cost bias | candidate ordering | **SAFE** | empty tally = ×1.0 identity; ordering ≠ threshold (ADR-018 §4) |
| Lifecycle forward transitions | observation-only | **SAFE** | typed audit view, no decision coupling |
| Memory-decay pump (halfLife / aging) | demote/age memory | **SAFE-if-conservative** | aging REDUCES trust; the dormant logic exists (`MemoryGovernanceCore.swift:387-407` `slowRetireDays`/`ageInDays`→`.aging`/retire) but the LIVE atom `promotionState` is only mapped FORWARD (`BASMLMemoryService.swift:131,162`) — O3 is a *wiring* of dormant logic to the live atom |
| Promotion-DEMOTION pump (→ `.retired`) | lower a memory's standing | **SAFE-if-conservative** | reduces influence only; lifecycle vocabulary `promoted → retracted` already typed (`BASEvolutionLifecycle.swift:28-37`), observation-only today |
| Evidence-debt REPAYMENT | lower accrued debt | **GATED** | debt-down = caution-down → the sanctioned reduction path (ADR-020 §1), not free |
| Risk-threshold mutation (P4) | relax a band cutoff | **CLOSED** | unsafe-by-construction; inverse of ADR-006/012 (ADR-018 §12) |
| Caution-reduction below baseline (P1.5b) | less caution than no-loop | **CLOSED** | verdict-after-render circularity (ADR-019 §14, ADR-020 §1) |
| `valueAxes.updateThreshold` auto-tune | move a humility gate | **CLOSED/GATED** | it IS a guardrail (`EBrainHostRuntime+RiskService.swift:578,591`); operator+L14 only |
| `boundaryVeil` relaxation | remove a confirm / hard-no-go | **CLOSED** | add-only ratchet by design (`HostConstitutionCore.swift:90` `restrictedMemoryDomains`) |
| Version-tree merge-promotion (P5.3) | swap active constitution | **GATED (sovereign)** | gate-safeable but huge blast radius; `merging()` is LWW-unsafe-as-arbiter (ADR-018 §13) |
| Substantive per-pass refinement | resolve real evidence | **INFEASIBLE** | deterministic loop + signal-count memory (ADR-019 §12) |

### 4.2 Reading the axis
SAFE → opt-in carrier slices (§5 ladder). SAFE-if-conservative → same, with a
proof the pump only ever lowers trust/influence. GATED → wait for sovereign
machinery (token + L14 + caps + rollback). CLOSED → never built; ADR-021 proposes
no code for these. INFEASIBLE → needs a capability the substrate lacks.

---

## 5. Phased ignition map (each default-OFF / byte-equal / dormant-first)

| Phase | Slice | Axis | First-commit shape |
|---|---|---|---|
| **O0** | Name the pattern — a `BASExperienceCarrier` idiom over the existing slot-IN/sink-OUT pairs (refactor-only) | SAFE | unify the 2 landed carriers under one name; 0 behavior change |
| **O1** | Dream-loop tally: `candidateTypeSuccessTally` carrier+sink, fold via `score_candidate`, bias `costs[]` BEFORE the FFI in `dreamLoopBatchScore` (`BASAutoRouteRanker.swift:3058`); empty tally = ×1.0 | SAFE | the ADR-018 §4 "clean-1-chapter ~40 LOC" slice, as an outer-loop instance |
| **O2** | Lifecycle wiring: emit `BASEvolutionLifecycleSession` transitions to an observation-only sink | SAFE | mirrors ShadowTrial §10 Commit-2 |
| **O3** | Memory-decay pump: connect the dormant `MemoryGovernanceCore` aging/retire logic to the live atom via a carrier — conservative demotion only, never promotes | SAFE-if-conservative | lights the L8 "reservoir, no pump" |
| **O4** | Promotion-DEMOTION pump: cross-turn conservative write of `.retired` on the live atom, via carrier | SAFE-if-conservative | one-directional toward LESS influence |
| **O5** | Evidence-debt repayment | **GATED** | debt-down = caution-down — sanctioned reduction path, NOT built here |
| **O6** | Version-tree branch/merge (= P5) | **GATED (sovereign, multi-session)** | ADR-018 §13 deferred arc; token + signature-verify (not LWW) + rollback |
| **—** | P4 · P1.5b · below-baseline · substantive-refinement | **CLOSED / INFEASIBLE** | proposed: NOTHING (the walls) |

**Ship order:** O0 (name it) → O1 (dream-loop, the elegant start) → O2 → O3 → O4;
**STOP at the SAFE/GATED boundary.** O5/O6 await sovereign machinery + review; the
CLOSED rows are never built.

### 5.1 Implementation-feasibility re-study (ch1044) — the SAFE ladder is NOT cleanly buildable as drafted

Two adversarial implementation studies (Opus, code-grounded) examined O0 + O1 to
START "全面开发." Both reached HONEST NO-GO — sharpening this design:

- **O0 (name the carrier pattern) → DON'T-BUILD as code.** The two landed carriers
  share only the *plumbing* triple; their FOLDS and CONSUMPTION SEAMS genuinely
  differ — evidence's fold (`BASDeliberationResolutionCredit`) is a free-function
  pipeline over the frame that MUTATES `boundRiskCard` (`+RunTurn.swift:473-483`),
  while ShadowTrial's fold is a `map` of a carrier method feeding a sink that
  GATES NOTHING (`:138-141`). A unifying protocol is either **vacuous** (a marker
  enforcing nothing both types don't already satisfy) or **behavior-changing**
  (can't byte-equally relocate the evidence fold onto the carrier). Two instances
  is not a pattern (rule-of-three unmet); `BASExperience*` is already a taken name
  (`BASExperienceCandidate(Type)`). **§2.2's table already IS the O0 artifact.**
  Codifying "same shape" would amplify the §8 risk it warns against (same shape ≠
  same safety). Verdict: the doc IS the deliverable; revisit a shared type only at
  a genuine third instance.

- **O1 (dream-loop success-tally) → NO-GO; the ADR-018 "~40 LOC clean" estimate is
  WRONG three independent ways** (like the P4 "feasible" + P5 "600-900 LOC"
  estimates were wrong): (1) **dead target** — `dreamLoopBatchScore`
  (`BASAutoRouteRanker.swift:3058`) has 0 production callers; biasing its `costs[]`
  changes nothing (the live decision is `mergeChoice`'s `mergedScore`, not the
  batch-scorer). (2) **clamp-dominated** — even if wired, a cost/confidence nudge
  dies on the 0.64 `egoScore` ceiling (ADR-019 §9: "there is no small, clean, safe
  consequential slice; the architecture forbids it on purpose"). Only the
  reversibility-tilt survived, precisely because it is NOT confidence/cost and acts
  on a near-tie at selection. (3) **no learning signal** — there is NO realized
  per-candidate-type outcome ("path.direct succeeded/failed") anywhere in the turn
  result; the only feedback channel is the opaque, prod-nil, L14-gated
  `BASFeedbackEvent` (ADR-018 §4 point 4). A tally with nothing to learn from is
  decoration — the same INFEASIBILITY wall as substantive per-pass refinement
  (ADR-019 §12).

### 5.2 The deeper finding (the honest answer to "全面开发")

The SAFE-surface ladder O1-O4 is **not** a set of clean ~40-LOC opt-in slices. The
two walls that defeat O1 — **clamp-domination** (no small perturbation reaches a
decision; ADR-019 §9) and **no realized-outcome feedback channel** (the substrate
is a deterministic single-shot pipeline; ADR-019 §12) — are **architecture-wide**,
not O1-specific. They equally constrain O3/O4 (a memory-decay/demotion pump needs
a "this memory proved wrong" signal that doesn't exist) and O5 (gated anyway). So
the honest conclusion of "认真研究 仔细想想 全面开发":

> **"全面开发" of the evolution OUTER loop is NOT available as safe code today —**
> not for lack of effort or session-depth, but because the substrate is
> structurally clamp-dominated and has no realized-outcome feedback channel into
> selection/memory. The ONLY consequential evolution lever that has ever survived
> the clamps is the reversibility-tilt (ADR-019 §13) — and it survived by being a
> selection-time near-tie break on a clamp-free axis, NOT a learned bias. Any
> genuine outer-loop learning requires FIRST building (a) a clamp-free selection
> injection point AND (b) a realized-outcome signal the substrate does not produce
> — each a MED-HIGH arc, not a "clean slice."

This is itself the most valuable output of the study: it converts the ADR-021
ignition ladder from "4 clean SAFE slices ready to build" into the truthful
"4 slices each blocked on one of two architecture-wide prerequisites (a clamp-free
injection point; a realized-outcome channel) — design only, build NONE until those
prerequisites are themselves designed + sovereign-reviewed." **No code was written
this chapter; the honest finding is the deliverable** (the same posture as the P4
NO-GO + P5 deferral).

---

## 6. Red-line proofs (outer-loop discipline, per slice)

- **Default-OFF byte-equal:** flag false / carrier nil → identity fold → no-op sink
  → byte-equal. Witnesses: `BASChapter1039DeliberationLoopTests` (the on/off
  byte-equal witness), `BASChapter602…` init-pin.
- **NEVER-EFFECTIVE-SAME-TURN structural:** turn-start carrier read vs the
  downstream outcome fill (ADR-018 §10 ordering).
- **Replay-determinism:** explicit-input carrier + pure fold.
- **Monotonic-conservatism test** for each SAFE slice (the ADR-019 §5 template:
  prove the effect can only ratchet caution up / pick a strictly-safer action).
- **Gate on fast filters, not the noisy full sweep** (ADR-020 §8 — the 3 infra
  flakes are catalogued in `Docs/KNOWN_TEST_FLAKES.md`).

---

## 7. Honest scope

- **Already real:** the INNER loop (ADR-018 P1) + TWO outer-loop instances
  (ShadowTrial §10, evidence withholding ADR-020 §4) + the safe consequential
  levers (reversibility-tilt ADR-019 §13, P1.5a ADR-019 §11) + the observation-only
  two-phase verdict (ADR-020).
- **What ADR-021 newly UNIFIES (the only net-new — theory, not code):** (a) the
  two-loop model as ONE architecture; (b) the outer loop as ONE pattern
  (carrier+fold+sink) instanced four ways; (c) the safe/gated/closed axis from a
  single ratchet-up principle; (d) the named ignition ladder O0-O6.
- **Genuinely unbuilt + why:** O1-O4 are SAFE-but-unbuilt (dormant machinery
  awaiting carrier wiring — design, not shipped). O5/O6 are GATED (sovereign token
  + L14 + caps + rollback; multi-session). P4 / P1.5b / below-baseline are CLOSED
  (unsafe-by-construction — ADR-018 §12, ADR-019 §14, ADR-020 §1);
  substantive-refinement is INFEASIBLE (ADR-019 §12). **ADR-021 proposes building
  NONE of the dangerous parts.**

---

## 8. Consequences

**Positive:** names the load-bearing idiom so future evolution work is a recognized
pattern, not a re-invention; gives the outer loop the architecture ADR-018 §5
punted; makes the safe/forbidden boundary one derivable principle; identifies 4
dormant reservoirs (O1-O4) as SAFE opt-in slices.

**Negative / risks:** the outer loop touches the hot turn-start seam (each slice
MED until proven byte-equal-off); the GATED arcs carry real blast radius; **the
uniform pattern must not tempt wiring a CLOSED row "because it's the same shape" —
the §4 axis is the guard** (same shape ≠ same safety; direction is what matters).

**Honest boundary:** this is DESIGN, not implementation; dormant-first; no closed
wall reopened.

---

## 9. Verification of THIS ADR (doc-only)

- Every `file:line` cross-checked against HEAD `77da024e2` (grep-verified
  2026-05-31): the carrier triple on the coordinator (`:147/:171/:180/:191/:200/
  :210`), `dreamLoopBatchScore` 0 prod callers (`:3058`), the ADR-006/012 gate
  (`BASRiskCalibrationGate.swift:153,:209`), the demotion refinements
  (`MemoryGovernanceCore.swift:387-407`, `BASMLMemoryService.swift:131,162`,
  `BASEvolutionLifecycle.swift:28-37`), the guardrail anchors
  (`EBrainHostRuntime+RiskService.swift:578,591`, `HostConstitutionCore.swift:90`).
- Zero code change → zero build/test/device regression risk.
- Append-only (new file + one `ADR_INDEX.md` row) → keeps
  `BASChapter1005ScaffoldInventoryPin` + `BASChapter1010ScaffoldClosureArcSeal`
  pins green.
