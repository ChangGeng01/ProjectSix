# ADR Index — where every `ADR-NNN` reference resolves

> **Purpose (ch 1044 查缺补漏):** the code + docs reference 8 distinct ADR
> numbers, but only 5 have standalone `Docs/ADR_NNN*.md` files. This index maps
> EVERY referenced ADR to where its doctrine actually lives, so a reader who hits
> an `ADR-NNN` comment never has to hunt for a missing file. Built by grepping all
> `ADR-NNN` tokens across `Sources/` + `Docs/` (complete set, not a sample).

## The complete reference set (8 ADRs)

| ADR | Topic | Defining location | Kind |
|---|---|---|---|
| **ADR-006** | Risk-calibration **timing** doctrine: threshold replacements accepted **between turns / between deploys only**, never mid-turn | **Inline** in `Sources/BASPolicy/BASRiskCalibrationGate.swift:36`, `BASRiskCalibrationBundle.swift:44`, `BASRiskCalibrationStratumSubModel.swift:42` | behavioral (inline-documented) |
| **ADR-012** | Risk-calibration **payload** doctrine: the "Hybrid offline-pipeline" — operator-authored + L14-signed bundle; "NOT mutated per-turn", "NOT auto-derived" (不变量 #2 神经不掌权); ±0.25-clamped deltas; one audit entry per replacement | **Inline** in `Sources/BASPolicy/BASRiskCalibrationBundle.swift:7,31-44`, `BASRiskCalibrationGate.swift:26-39,198`; shipped ch 261 / M744 | behavioral (inline-documented) |
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
- **ADR-006 + ADR-012 have no standalone charter** — their doctrine is real but
  lives only as inline comments in `BASPolicy/BASRiskCalibration*.swift`. Promoting
  them to standalone `Docs/ADR_006*.md` / `Docs/ADR_012*.md` is a small future
  doc task (not done here — the inline text is accurate + sufficient for now, and
  this index makes it findable). Recorded so it isn't lost.
- See `Docs/ARCHITECTURE_AUDIT_ch1044.md` MED-5 for the original finding.
