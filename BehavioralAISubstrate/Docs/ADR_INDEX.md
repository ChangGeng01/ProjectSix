# ADR Index — where every `ADR-NNN` reference resolves

> **Purpose (ch 1044 查缺补漏):** the code + docs reference 8 distinct ADR
> numbers, but only 5 have standalone `Docs/ADR_NNN*.md` files. This index maps
> EVERY referenced ADR to where its doctrine actually lives, so a reader who hits
> an `ADR-NNN` comment never has to hunt for a missing file. Built by grepping all
> `ADR-NNN` tokens across `Sources/` + `Docs/` (complete set, not a sample).

## The complete reference set (12 ADRs — 11 active + ADR-013 ghost)

| ADR | Topic | Defining location | Kind |
|---|---|---|---|
| **ADR-006** | Risk-calibration **timing** doctrine: threshold replacements accepted **between turns / between deploys only**, never mid-turn | **`Docs/ADR_006_RISK_CALIBRATION_TIMING.md`** (charter, ch 1044) + inline `BASRiskCalibrationGate.swift:13-18` | behavioral |
| **ADR-012** | Risk-calibration **payload** doctrine: the "Hybrid offline-pipeline" — operator-authored + L14-signed bundle; "NOT mutated per-turn", "NOT auto-derived" (不变量 #2 神经不掌权); ±0.25-clamped deltas; one audit entry per replacement | **`Docs/ADR_012_HYBRID_RISK_CALIBRATION_PIPELINE.md`** (charter, ch 1044) + inline `BASRiskCalibrationBundle.swift:7-48` | behavioral |
| **ADR-013** | **GHOST — not an active doctrine.** The sole reference (`Sources/BASRuntimeCore/BASHostStorageOptions.swift:3`) is a *historical chapter note* ("chapter 三百〇二 was ADR-013 + ADR-014 doctrine"), not a live contract. No charter needed; do not hunt for a missing ADR-013 file. | historical note only |
| **ADR-014** | **OPT-IN doctrine** (behavioral): default-OFF + byte-equal-when-off (红线 7); the canonical opt-in shapes + contract | **`Docs/ADR_014_OPT_IN_DOCTRINE.md`** (retroactive charter, ch 1044) | behavioral |
| **ADR-016** | **Milestone-advance convention** (process, NOT behavioral): monotonic `M####` advance stamped in file headers; substrate-completion marker | **`Docs/ADR_016_MILESTONE_ADVANCE_CONVENTION.md`** (retroactive charter, ch 1044) | process |
| **ADR-018** | Iterative loop + evolution底层架构 (the deliberation-budget loop; P1-P5 roadmap) | **`Docs/ADR_018_ITERATIVE_LOOP_AND_EVOLUTION.md`** | behavioral |
| **ADR-019** | Consequential deliberation wiring (reversibility-tilt, P1.5a caution, clamp-domination §9, P1.5b closure §14) | **`Docs/ADR_019_CONSEQUENTIAL_DELIBERATION_WIRING.md`** | behavioral |
| **ADR-020** | Evidence-resolution + two-phase verdict (Step-4 floored withholding, provisional verdict, §9 floor correction) | **`Docs/ADR_020_EVIDENCE_RESOLUTION_AND_TWO_PHASE_VERDICT.md`** | behavioral |
| **ADR-021** | Unified Evolution Architecture (统一进化算法底层架构): the two-loop model (inner per-turn + outer cross-turn) as ONE pattern (carrier/fold/sink) + the single safe/gated/closed axis. DESIGN-only — unifies verified machinery, builds nothing. §5.1-§5.3 feasibility findings: O0/O1 NO-GO (premature/clamp-dominated); prereq-(a) clamp-free ratchet DESIGNABLE; prereq-(b) outcome channel INFEASIBLE → the deepest wall is OUTCOME-BLINDNESS (substrate is not a self-improving learner) | **`Docs/ADR_021_UNIFIED_EVOLUTION_ARCHITECTURE.md`** | behavioral (design synthesis) |
| **ADR-022** | Sovereign verdict **parity shadow gate** (#3 / audit DEFER-2): wire `BASSovereignTurnVerifier` alongside `buildSovereignVerdict` **dormant-first** (project settled turn state → engine → compare levels; observe+log drift, NEVER halt, byte-equal-off). Invariant `coordinatorLevel >= engineLevel`; `coordinatorLaxer` = halt signal. Phase 2 (`coordinatorLaxer`→actual halt) deferred until Phase-1 parity evidence. DESIGN-only | **`Docs/ADR_022_SOVEREIGN_VERDICT_PARITY_SHADOW_GATE.md`** | behavioral (design) |
| **ADR-023** | **Verdict-authority reconciliation** (Phase-2 prerequisite): the ADR-022 §8 full-grid sweep measured ~46% coordinator-vs-engine divergence; ADR-023 maps the taxonomy (**83% = missing-lineage over-escalated to `deadStop`** via the verifier's `policyBundleTampered` conflation) + a phased **R1–R4** reconciliation (R1 = give the engine a real BR-006 *missing-lineage ≠ tampering* → `shadowLock`, sovereign), each gated by the full-grid sweep; `coordinatorLaxer == 0` unlocks Phase-2. DESIGN-only | **`Docs/ADR_023_VERDICT_AUTHORITY_RECONCILIATION.md`** | behavioral (design) |
| **ADR-024** | **One verdict kernel** (eliminate the two-authorities anti-pattern at its root): factor the engine's verdict logic into ONE pure sync `evaluateLevel(context)→LevelDecision` kernel (no IDs/clock/ledger) that every authority shares → rule-drift impossible by construction. **Step 1 LANDED byte-equal** (`BASSovereignVerdictEngine.evaluateLevel`, gated by 41 engine tests); Steps 2–4 (kernel adopts ADR-023's reconciled rules → coordinator adapter → shadow uses kernel) gated/future. Supplies the *mechanism* that makes ADR-023's reconciliation permanent | **`Docs/ADR_024_ONE_VERDICT_KERNEL.md`** | behavioral |

## Related contracts that are NOT numbered ADRs
- **红线 7** (additive byte-equal safety invariant) — stated in `ADR_014_OPT_IN_DOCTRINE.md` §4 + `L8_ARC_SEAL.md`.
- **不变量 #1/#2/#3** (先醒再答 / 神经不掌权 / 私有经验不进权重) — defined in `L8_ARC_SEAL.md:553-558`; #2 + NEVER-EFFECTIVE-SAME-TURN are structurally enforced (`BASSharedStateGraph.swift`, turn-phase ordering).

## Outstanding (honest)
- **ADR-006 + ADR-012 now have standalone charters** (ch1044 N12 — DONE):
  `Docs/ADR_006_RISK_CALIBRATION_TIMING.md` + `Docs/ADR_012_HYBRID_RISK_
  CALIBRATION_PIPELINE.md`. Every referenced ADR now resolves to a doc (013 is
  the documented ghost). No outstanding ADR-doc gap remains.
- See `Docs/ARCHITECTURE_AUDIT_ch1044.md` MED-5 / N12 for the original finding.
