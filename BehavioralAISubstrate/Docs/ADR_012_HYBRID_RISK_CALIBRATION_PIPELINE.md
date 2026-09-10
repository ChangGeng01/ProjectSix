# ADR-012 — Hybrid Offline-Pipeline Risk-Calibration Doctrine (retroactive charter)

> **Status: ACCEPTED (retroactive charter, ch 1044).** Shipped chapter 二百六十一
> / M744 as "Hybrid offline-pipeline doctrine"; referenced across
> `BASPolicy/BASRiskCalibration*.swift` + `BASEvaluation/BASShadowEvaluating.swift`
> but had no standalone doc (ch1044 严查 item N12). Records the doctrine the code
> already enforces; introduces no behavior. Companion to ADR-006 (timing) +
> 不变量 #2/#3.

## 1. The doctrine (one sentence)
**Risk-band thresholds are tuned by an OPERATOR-AUTHORED, L14-SOVEREIGN-WARRANTED,
clamped, monotonically-versioned calibration bundle produced OFFLINE — the
substrate never auto-derives or self-tunes its own risk policy.**

## 2. The typed payload (`BASRiskCalibrationBundle`)
`Sources/BASPolicy/BASRiskCalibrationBundle.swift` — the bundle the operator
authors carries:
- **Per-stratum threshold deltas** for the risk-band cutoffs (medium/high/extreme),
  each constrained to **`[-0.25, +0.25]`** — `maximumAbsoluteDelta = 0.25` (`:79`).
- **An L14 sovereign warrant ref** — `sovereignWarrantRef`, which the gate
  requires be non-empty (`isWellFormed`).
- **A monotonic `bundleVersion`** — anti-replay.
- **Generalized stratum keys** (不变量 #3 私有经验不进权重: keys are generalized,
  not raw private experience).

## 3. The hard constraints (verbatim from the doctrine, `BASRiskCalibrationBundle.swift:31-44`)
- **NOT mutated per-turn.** ADR-012 forbids mid-turn replacement. (= ADR-006.)
- **NOT auto-derived.** ADR-012 forbids auto-deploy — inputs come from operator
  review of the offline `aggregate_risk_stratum.py` output, not from the runtime.
- **NOT host-specific.** ADR-012 forbids per-host tuning.
- **不变量 #2 神经不掌权:** the bundle is operator-authored + L14-signed; the
  substrate's L11 doesn't auto-derive it.

## 4. The gate (`BASRiskCalibrationGate`)
`Sources/BASPolicy/BASRiskCalibrationGate.swift` — `replace(_:)`:
- validates `proposed.isWellFormed` (version + non-empty `sovereignWarrantRef`) —
  rejects otherwise (`:156`);
- enforces monotonic version (anti-replay-replacement);
- emits ONE typed audit entry per replacement (`risk-calibration:warrant:<ref>`,
  `:209`).
Prompts are stripped before aggregation (`BASShadowEvaluating.swift:187`,
"aggregator strips prompts per ADR-012").

## 5. Why this exists / its relationship to the closed P4
This is the substrate's **sanctioned** way to change a risk threshold — and it is
deliberately the OPPOSITE of P4 (ADR-018 §12, CLOSED NO-GO). P4 would have let
per-turn USER FEEDBACK mutate a threshold (auto-derived, per-turn, per-host) —
breaching every one of §3's constraints + 不变量 #2. The audit's decisive P4
finding was precisely that "the substrate already does threshold mutation safely
via ADR-012, whose doctrine forbids exactly what P4 asks." Threshold change =
operator + L14 + offline + clamped + between-deploy, never live feedback.

## 6. Reference
Inline: `BASRiskCalibrationBundle.swift:7-48`, `BASRiskCalibrationGate.swift:1-39,156,209`,
`BASRiskCalibrationStratumSubModel.swift:42`, `BASShadowEvaluating.swift:187`.
Index: `Docs/ADR_INDEX.md`. Finding: `Docs/ARCHITECTURE_AUDIT_ch1044.md` N12.
Related: ADR-006 (timing), ADR-018 §12 (P4 closure), 不变量 #2/#3 (`L8_ARC_SEAL.md`).
