# ADR Index — where every `ADR-NNN` reference resolves

> **Purpose (ch 1044 查缺补漏):** the code + docs reference 8 distinct ADR
> numbers, but only 5 have standalone `Docs/ADR_NNN*.md` files. This index maps
> EVERY referenced ADR to where its doctrine actually lives, so a reader who hits
> an `ADR-NNN` comment never has to hunt for a missing file. Built by grepping all
> `ADR-NNN` tokens across `Sources/` + `Docs/` (complete set, not a sample).

## The complete reference set (8 ADRs)

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

## Related contracts that are NOT numbered ADRs
- **红线 7** (additive byte-equal safety invariant) — stated in `ADR_014_OPT_IN_DOCTRINE.md` §4 + `L8_ARC_SEAL.md`.
- **不变量 #1/#2/#3** (先醒再答 / 神经不掌权 / 私有经验不进权重) — defined in `L8_ARC_SEAL.md:553-558`; #2 + NEVER-EFFECTIVE-SAME-TURN are structurally enforced (`BASSharedStateGraph.swift`, turn-phase ordering).

## Outstanding (honest)
- **ADR-006 + ADR-012 now have standalone charters** (ch1044 N12 — DONE):
  `Docs/ADR_006_RISK_CALIBRATION_TIMING.md` + `Docs/ADR_012_HYBRID_RISK_
  CALIBRATION_PIPELINE.md`. Every referenced ADR now resolves to a doc (013 is
  the documented ghost). No outstanding ADR-doc gap remains.
- See `Docs/ARCHITECTURE_AUDIT_ch1044.md` MED-5 / N12 for the original finding.
