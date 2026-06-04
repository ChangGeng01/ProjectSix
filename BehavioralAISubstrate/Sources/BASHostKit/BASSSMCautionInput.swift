// MARK: - BASSSMCautionInput
// chapter 一百八十六 / ADR-019 P1.5b — the SSM operator as an AUTHORITATIVE, raise-caution-only L11 INPUT
//
// Phase 2 of "Mamba/SSM as a core per-turn operator". Mirrors `BASDeliberationCaution` (ADR-019 P1.5a):
// a bounded, one-shot, caution-INCREASING increment added to the FINAL bound `totalRisk` (post-binding,
// in `runTurn`) when the opt-in SSM operator runs on a genuinely-uncertain turn. The increment is SCALED
// by the CPU-deterministic `ssmCaution ∈ [0,1]` computed from all three live per-turn sources
// (`BASMambaTurnSignalBuilder` → `BASSSMScanCPUReference.scan`, sync + pure-Swift — NO GPU/async/CoreML
// on the value path, so ch883 holds and the result stays byte-deterministic).
//
// SAFETY (load-bearing):
//   • RAISE-ONLY by construction — `raisedTotalRisk(c, s) ≥ c` for all s ≥ 0, == c exactly when s == 0.
//     A pre-render caution REDUCTION is architecturally impossible (verdict-after-render, ADR-019 P1.5b);
//     this only ever RAISES, so it is in the safe direction.
//   • 不变量 #2 (神经不掌权) — the raised risk flows as an INPUT the sovereign verdict GATES downstream;
//     this writes only `boundRiskCard`, never a verdict / permit / commit token, and can never DOWNGRADE.
//   • 红线 7 / ADR-014 — the operator is flag-gated OFF by default (`ssmCautionOperatorEnabled = false`),
//     so it is never invoked and the turn is byte-equal to before. `cautionScalar`/`observation` return
//     nil when all three sources are empty (clean per-turn no-op).

import Foundation
import BASOrchestration
import BASMetalSubstrate

enum BASSSMCautionInput {

    /// Maximum bounded caution added to the FINAL bound `totalRisk` when the opt-in SSM operator runs on
    /// a genuinely-uncertain turn — the FULL increment is reached only at `ssmCaution == 1` and is scaled
    /// down linearly by the [0,1] signal. Sized to mirror `BASDeliberationCaution`'s one-band increment.
    /// One-shot, bounded, caution-only.
    static let ssmCautionRiskIncrement = 0.06

    /// The full per-turn SSM operator observation (which carries `ssmCaution ∈ [0,1]`), or nil when all
    /// three sources are empty (clean no-op) OR the CPU scan fails. The SINGLE compute + determinism
    /// surface the seam uses — it both RAISES risk (via `ssmCaution`) and feeds the opt-in observation
    /// sink, so the authoritative scalar and the emitted scalar are identical by construction. Reuses the
    /// exact Phase-1 pipeline (`BASMambaTurnSignalBuilder` → sync CPU scan → `…Projection.project`).
    static func observation(
        sessionID: String,
        turnID: String,
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath]
    ) -> BASMambaSSMTurnObservation? {
        guard let input = BASMambaTurnSignalBuilder.scanInput(
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        guard let y = try? BASSSMScanCPUReference.scan(
            x: input.x, delta: input.delta, A: input.a, B: input.b, C: input.c, shape: input.shape)
        else { return nil }
        return BASMambaSSMTurnObservationProjection.project(
            sessionID: sessionID, turnID: turnID, input: input, scanOutput: y)
    }

    /// The CPU-deterministic SSM caution scalar ∈ [0,1] for this turn's three live sources, or nil when
    /// all three sources are empty / the scan fails. Defined in terms of `observation` so the unit-tested
    /// scalar is byte-identical to the scalar the seam uses to raise risk (no drift).
    static func cautionScalar(
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath]
    ) -> Double? {
        observation(
            sessionID: "", turnID: "",
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)?.ssmCaution
    }

    /// Monotonic raise-only projection: raise `current` by the increment SCALED by `ssmCaution`, capped at
    /// 1. `raisedTotalRisk(c, s) ≥ c` for every s ≥ 0, and == c exactly when s == 0 — the safe-direction
    /// proof the seam's safety rests on. A non-finite / out-of-range `ssmCaution` is clamped to [0,1]
    /// first (NaN → 0 → no raise), so a degenerate scan can never LOWER risk.
    static func raisedTotalRisk(_ current: Double, ssmCaution: Double) -> Double {
        let s = ssmCaution.isNaN ? 0 : min(1.0, max(0.0, ssmCaution))
        return min(1.0, current + ssmCautionRiskIncrement * s)
    }
}
