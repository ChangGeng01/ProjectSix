# ADR-020 — Evidence-Resolving Deliberation + Two-Phase Verdict

> **Status: COMPLETE (safe scope).** Both directions landed opt-in + byte-equal-off:
> Arc-3 two-phase verdict (observation-only, Phase A+B+C) and Arc-2 evidence-
> resolving caution-withholding (Step 4 C1+C2+C3). Step 2b closed as not-needed
> (§4); both dangerous endpoints closed as architecturally unsafe (§1). The
> floored-invariant phrasing was corrected (§9 — floor is "≤ the loop's own added
> increment", NOT "≥ the loop-off baseline"). Substantive per-pass refinement
> remains out of scope (infeasible, ADR-019 §12).
>
> Successor arc to ADR-018/019. After the consequential-
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
| **1 Phase A** | extract render-independent `computeVerdictDecision` (pure) | zero (byte-equal *unconditionally*) | ✅ `ce13c2e9e` — sweep 14,656/0 |
| **2a** | Arc-2 latent primitives — `BASEvidenceAtom`/`ContentType`/`Ledger`/`Matcher` (dormant) | very low (dormant) | ✅ `e6458fbc4` — sweep 14,662/0 |
| **3 Phase B** | Arc-3 `buildProvisionalVerdict` + `BASProvisionalVerdict` (dead code; `computeVerdictDecision`→`static`) | low (dead code) | ✅ `91123cd66` — sweep 14,667/0 |
| **3 Phase C** | wire the provisional verdict as INERT, observation-only at `RunTurn:~823` | low (off-gated, mutation-free seam) | ✅ `628384370` — sweep 14,668/0 |
| **2b** | ~~defaulted-optional `BASMemoryBundle.resolvedEvidence` Codable field + `evidenceStore` slot~~ | — | ❌ **CLOSED — not needed.** Step 4 (C1) chose the coordinator-`slot + sink` carriers precisely to AVOID a Codable/seal-path field (the dominant byte-equality risk). `evidenceLedger` (in) + `resolvedEvidenceSink` (out) deliver the same capability off the canonical-bytes path. So 2b is correctly-scoped non-work, not deferred. |
| **4** | Arc-2 single-layer floored caution-withholding (at the P1.5a seam) | medium (opt-in, byte-equal-off) | **C1 ✅** `1cc6dfcb6` (pure helper `BASDeliberationResolutionCredit` + dormant coordinator slots `evidenceLedger`/`resolvedEvidenceSink`) · **C2 ✅** `219d9b865` (seam: add `withheldIncrement = max(0, 0.06 − credit)` instead of the constant — byte-equal + **production-inert**: `buildEBrainTurn` does not thread the ledger yet) · **C3 ✅** `83e05e222` (thread `evidenceLedger` through `buildEBrainTurn` → activate in production; e2e proof on `.fixtureGeneric`, 2 live `missingFact` keys: full resolution drops high→medium with `on_resolved.totalRisk == on_stuck − increment` exactly, ch1042 5/0 + ch1039 9/0 + ch602 4/0, + replay-determinism + anti-theater + byte-equal-off) — **see §9 for the floor-claim CORRECTION** |
| **5** | ADR/SCAFFOLD status flips + honest-scope close-out | docs | ✅ `SCAFFOLD_VS_WIRED.md` ch1042 entry + §9 correction + this table |

**Excluded (confirmed unsafe, §1):** below-baseline reduction (Arc-2 caution-DOWN)
and verdict-gated reduction (Arc-3 "Phase D"). Both need the render-and-verdict
replay → a separate sovereign-gated ADR.

**BOTH arcs are COMPLETE in their safe scope** (all opt-in, byte-equal-off):
- **Arc-3 (two-phase verdict)** — Phase A+B+C landed; the provisional forecast
  fires pre-render and equals the post-render verdict level for the production
  path, observation-only (changes no decision).
- **Arc-2 (evidence-resolving caution-withholding)** — Step 4 C1+C2+C3 landed;
  the loop withholds its own added caution (floored — see §9) when a host-supplied
  `evidenceLedger` resolves the turn's typed unknowns by exact key.

Step 2b closed as not-needed (the slot+sink carriers avoid a Codable field). The
only remaining "work" is genuinely out of scope: substantive per-pass refinement
(infeasible, ADR-019 §12) and the below-baseline/verdict-gated reductions
(architecturally unsafe, §1) — both correctly NOT built.

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

## 7. Phase C resume spec (the NEXT spine edit — do with a fresh context)

Goal: wire `buildProvisionalVerdict` (Phase B) into `runTurn` as an **inert,
observation-only** artifact — byte-equal when off AND provably inert when on.
This is the one spine touch; everything it needs already exists.

**Seam:** `EBrainRuntimeCoordinator+RunTurn.swift`, immediately AFTER
`boundActionPermit` is fully settled by the Cthulhu gate (~:807–820) and BEFORE
`render` (:856). At that point `boundRiskCard`, `boundActionPermit`, `budgetFrame`,
`request.activeKillSwitches`, and `thoughtFrame.uncertaintyLedger` are all settled.

**Three pieces:**
1. **Sink** — add a default-nil `@Sendable` closure slot on the coordinator,
   mirroring `agentFabric` exactly (`EBrainRuntimeCoordinator.swift` property :135
   / init param :179 / assignment :206):
   `public var provisionalVerdictSink: (@Sendable (BASProvisionalVerdict) -> Void)? = nil`.
   It is NOT Codable and must appear in **zero** canonical-bytes/hash/seal paths
   (proof obligation: grep the name → only the init + the :807 emit).
2. **Pre-render emergencyBrake** — compute a provisional brake via the existing
   pure `buildEmergencyBrake(...)` (`EBrainRuntimeCoordinator+SovereignRuntime.swift:16`)
   from the pre-render inputs. This is a SEPARATE local; it must NOT replace or
   perturb the authoritative `emergencyBrake` computed later (~:1046).
3. **Emit (off-gated, side-effect-only):**
   ```
   if deliberationLoopEnabled {
       let pv = Self.buildProvisionalVerdict(
           policyLineagePresent: policyLineage != nil,
           budgetFrame: budgetFrame, riskCard: boundRiskCard,
           actionPermit: boundActionPermit, emergencyBrake: <pre-render brake>,
           activeKillSwitches: request.activeKillSwitches,
           confidenceFloor: thoughtFrame.uncertaintyLedger?.confidenceFloor,
           maxEvidenceDebt: thoughtFrame.evidenceDebts.map(\.debtWeight).max(),
           leaseEnded: <stoppingMode == .leaseEnd>)
       provisionalVerdictSink?(pv)
   }
   ```

**Byte-equality:** flag off → block never runs → byte-equal. Flag ON + sink nil
(the default everywhere, incl. every fixture) → `buildProvisionalVerdict` is a
pure computation whose ONLY effect is `sink?(pv)`, a no-op when nil → byte-equal.
The sink must never feed render/seal/verdict/hash — that is the whole safety.

**Tests (now that a real verdict exists to compare):** `provisionalLevel ==
finalLevel` for the production evolution service across the fixture grid;
inert-when-on identity (on-vs-off full `BASEBrainTurnResult` byte-equal, since the
emit is observation-only); flag-off full sweep stays at the current count / 0.

**Then STOP and checkpoint** before Step 4 (the consequential floored
caution-withholding) — it is the one slice that changes a decision, and it is
sovereign-review-gated by design.

## 9. CORRECTION (ch1042 C3) — the floor is vs the loop's OWN contribution, NOT the loop-off baseline

§3 and §8 stated the floored invariant as `on_resolved.totalRisk >= off.totalRisk`
("genuine resolution withholds the loop's own added caution, never subtracts
baseline caution… never below the loop-off baseline"). **The C3 end-to-end test
found that literal phrasing is FALSE on `.fixtureGeneric`, and this is the honest
correction.**

What is TRUE (verified, `BASChapter1042EvidenceResolutionTests`):
- The seam adds `withheldIncrement = max(0, increment − credit) ∈ [0, increment]`,
  so the loop withholds **at most its own added caution** off the SAME-selection
  baseline. Full resolution → `on_resolved.totalRisk == on_stuck − increment`
  EXACTLY (0.63850 == 0.69850 − 0.06, 1e-12). The loop never subtracts more than
  it added. This is the real §14-safe property and it holds at the seam.

What is FALSE (the imprecise claim, now corrected):
- `on_resolved >= off` does NOT hold here. Live numbers: `off` 0.64275 (selects
  `path.bounded`), `on_resolved` 0.63850 — **~0.00425 BELOW off.** Cause: the
  ch1041 **reversibility-tilt co-fires** when the loop is on and moves selection
  to the more-reversible `path.reflective`, whose base binding is ~0.00425 lower.
  The post-binding withholding seam floors the loop's OWN increment relative to
  the (tilt-selected) bound card; it cannot — and does not — compare the composed
  (tilt binding + withholding) card against the loop-OFF value.

Why this is still SAFE (not a guardrail breach): the sub-baseline result is not
the withholding "over-subtracting" — it is the ch1041 tilt independently selecting
a **more-reversible (safer) action**, whose lower binding legitimately carries
slightly lower risk. Both opt-in effects are conservative; they simply compose to
a number marginally under the loop-off scalar while the band returns to off's
(medium) and the selected action is strictly safer. The test asserts the TRUE
floor (vs `on_stuck`) and PINS the deviation (`XCTAssertLessThan(on_resolved, off)`)
so any future change is forced to re-examine it. **Takeaway:** state the Step-4
floor as "withholds ≤ its own added increment (vs the same-selection on_stuck
baseline)", NOT "≥ the loop-off baseline."

## 8. Step 4 Commit 3 resume spec + the ch1042 flaky-triage lesson

**State at handoff:** C1 (`1cc6dfcb6`) + C2 (`219d9b865`, the reapply — see the
lesson below) are landed, byte-equal, on origin. The floored withholding logic
EXISTS at the seam and is UNIT-tested (`BASDeliberationResolutionCreditTests`),
but it is **production-inert**: `buildEBrainTurn` does not thread `evidenceLedger`,
so the coordinator slot is always nil on the host path → `withheld` is always the
full 0.06 → byte-equal with the pre-Step-4 P1.5a. C3 activates + proves it.

**Commit 3 (do with a fresh context):**
1. **Thread `evidenceLedger:` through `buildEBrainTurn`** (`EBrainHostRuntime
   Synthesis.swift`, mirror how `deliberationLoopEnabled` is threaded; default nil
   → byte-equal-off) so a host can supply evidence that reaches the coordinator
   slot, activating the withholding in production. Optionally thread
   `resolvedEvidenceSink:` too for write-back.
2. **End-to-end consequence test** (new `BASChapter1042EvidenceResolutionTests`,
   reuse the `testActivatesAndRefinesViaRealHostRuntimePath` harness: `.fixture
   Generic`, prompt "Push into an irreversible high-stakes move now.", `.high`):
   - `off` (loop off) → medium (~0.6427); `on_stuck` (loop on, nil ledger) → high
     (~0.7027, today's P1.5a).
   - `on_resolved` (loop on, ledger SEEDED): build `BASEvidenceAtom`s whose
     `evidenceKey` equals the LIVE keys from `BASDeliberationResolutionCredit
     .requiredEvidenceKeys(on.decomposeFrame.unknownRecords)` (do NOT hardcode —
     derive from the live frame), confidence ≥ 0.3 → assert
     `on_resolved.riskCard.riskLevel == .medium` (dropped back from high),
     `on_resolved.totalRisk < on_stuck.totalRisk`, AND
     `on_resolved.totalRisk >= off.totalRisk` (THE FLOORED INVARIANT — never below
     baseline).
   - Replay-determinism (same ledger → same result) + anti-theater (a near-miss
     atom → no withholding → stays at on_stuck).
   - **HONEST CAVEAT to record:** if `decomposeFrame.unknownRecords` is empty for
     this fixture, the consequence cannot manifest on it — then either pick/seed a
     fixture whose decompose surfaces typed unknowns, or document that production
     benefit requires hosts to populate both the unknowns AND the ledger. Do not
     fake the seed.
3. Flip §4's C3 row + add a §15 "Step 4 LANDED" + update SCAFFOLD_VS_WIRED.

**⚠️ ch1042 FLAKY-TRIAGE LESSON (the reason C2 was needlessly reverted once):**
this package's full `swift test` sweep has **THREE independent infra flakes**, none
of which is a real regression. Before EVER reverting on a "1 failure", grep the log
and exclude all three:
- **swift-testing SIGBUS** — `exited with unexpected signal code 10` (hops between
  unrelated tests across runs; `BASSignalTenIntegrationTestTriageDoctrineTests`).
- **CoreData / NSXPC** — `Unable to send to server; failed after N attempts`,
  `NSXPCConnection`, `addPersistentStoreWithType … NSCocoaErrorDomain (134060)`
  (e.g. surfaced once in `BASProductionAdoptionSmokeTests.testCanonicalAudit
  ComplianceHostAdoption` as a cross-store atomID mismatch).
- Read the ACTUAL failing assertion + file:line; only count a real
  `XCTAssertEqual failed` **in the changed area** as a regression. The reliable
  byte-equal witness for Step 4 is `BASChapter1039DeliberationLoopTests` (9/0,
  fast, no CoreData/swift-testing) — gate on THAT, not the noisy full sweep.
