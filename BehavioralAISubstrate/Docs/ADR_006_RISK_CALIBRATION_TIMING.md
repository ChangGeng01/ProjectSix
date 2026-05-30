# ADR-006 — Risk-Calibration Timing Doctrine (retroactive charter)

> **Status: ACCEPTED (retroactive charter, ch 1044).** ADR-006 governs *when* a
> risk-calibration bundle may replace the active one. It is referenced in
> `BASPolicy/BASRiskCalibration{Gate,Bundle,StratumSubModel}.swift` but had no
> standalone doc (ch1044 严查 item N12). This file records the doctrine the code
> already enforces; it introduces no behavior. Companion to ADR-012 (the
> *payload* doctrine) and 不变量 #2 (神经不掌权).

## 1. The doctrine (one sentence)
**A risk-calibration bundle (the per-stratum threshold deltas that tune the
risk-band cutoffs) may be replaced ONLY between turns / between deploys — NEVER
mid-turn.**

## 2. What it means in code
- `BASRiskCalibrationGate.replace(_:)` (`Sources/BASPolicy/BASRiskCalibrationGate.swift`)
  is the ONLY mutation seam. Its header (`:13`): *"gate accepts replacements
  **between** turns,"* not during one.
- The active bundle is read-only within a turn: `runTurn` consumes the resolved
  thresholds but never swaps the bundle mid-pipeline.
- **Monotonic version enforcement** (`:17`, validated via `isWellFormed` + a
  version check) defends against accidental replay-replacement — an older or
  equal-version bundle is rejected.

## 3. Why
A turn's risk decision must be made against ONE stable threshold set. Allowing a
mid-turn swap would make the same turn's risk-band resolution depend on *when*
within the turn the bundle changed — destroying replay-determinism and opening a
race where a turn could be re-graded mid-flight. Between-turns-only keeps each
turn's calibration atomic + replayable.

## 4. Relationship to ADR-012 and the invariants
ADR-006 (timing: *when*) + ADR-012 (payload: *what* — operator-authored,
L14-warranted, ±0.25-clamped) together implement **不变量 #2 神经不掌权**: the
substrate never auto-derives or hot-swaps its own risk policy; a human operator
authors the bundle offline and an L14 warrant signs it, applied only at a turn
boundary. Contrast P4 (ADR-018 §12, CLOSED NO-GO): per-turn feedback→threshold
mutation is the precise INVERSE of ADR-006/012 and is forbidden.

## 5. Reference
Inline doctrine: `BASRiskCalibrationGate.swift:13-18`,
`BASRiskCalibrationBundle.swift:44`, `BASRiskCalibrationStratumSubModel.swift:42`.
Index: `Docs/ADR_INDEX.md`. Finding: `Docs/ARCHITECTURE_AUDIT_ch1044.md` N12.
