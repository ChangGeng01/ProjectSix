// MARK: - BASMambaSSMTurnObservation — typed per-turn SSM-operator telemetry
//
// Phase 1 of "Mamba/SSM as a core per-turn operator": a host-callable probe that runs the
// CPU-deterministic selective-scan (`BASSSMScanCPUReference`) over the composite per-turn input
// (`BASMambaTurnSignalBuilder`) and emits a typed observation. OBSERVATION-ONLY + OPT-IN: a nil sink
// (or all-empty sources) ⇒ no run ⇒ byte-equal (红线 7) — mirrors `BASMetalMambaObservationProjection`.
// The value path is CPU + sync (no GPU, no async, no CoreML), so it is fully deterministic.

import Foundation
import BASOrchestration
import BASMetalSubstrate

public struct BASMambaSSMTurnObservation:
    Codable, Equatable, Hashable, Sendable
{
    public let sessionID: String
    public let turnID: String
    public let affectCount: Int
    public let historyCount: Int
    public let candidateCount: Int
    /// Temporal caution signal in [0, 1] derived from the scan output (see `ssmCaution(...)`).
    public let ssmCaution: Double
    /// Raw max-abs of the scan output (pre-normalization), for audit.
    public let finalMagnitude: Double
    /// OPT-IN GPU-shadow telemetry: the CPU-vs-GPU selective-scan MAE for this turn's inputs (see
    /// `BASMambaGPUShadowParity`), or nil when the GPU shadow wasn't run / Metal is unavailable.
    /// OBSERVATION-ONLY — never on a value path; the authoritative ssmCaution above is always
    /// CPU-derived. Optional ⇒ Codable-backward-compatible (absent key decodes to nil).
    public let gpuShadowMAE: Double?

    public init(
        sessionID: String,
        turnID: String,
        affectCount: Int,
        historyCount: Int,
        candidateCount: Int,
        ssmCaution: Double,
        finalMagnitude: Double,
        gpuShadowMAE: Double? = nil
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.affectCount = affectCount
        self.historyCount = historyCount
        self.candidateCount = candidateCount
        self.ssmCaution = ssmCaution
        self.finalMagnitude = finalMagnitude
        self.gpuShadowMAE = gpuShadowMAE
    }
}

public enum BASMambaSSMTurnObservationProjection {

    /// Caution-scale reference, CALIBRATED FROM MEASURED scan magnitudes (pinned by
    /// `BASSSMCautionCalibrationTests`). The original value was the all-ones analytic steady state
    /// (C·(ΔB)/(1−e^{ΔA}) ≈ 0.063), but the actual per-turn scan never approaches it: measured
    /// max-abs(y) spans ~0.003 (a minimal turn) to ~0.046 (all three sources saturated at their 8-row
    /// caps), and a genuinely high-pressure turn (manipulative + irreversible + low-confidence) sits
    /// near ~0.013. The analytic 0.063 sat ABOVE that entire realistic range, leaving the operator
    /// near-inert (a high-pressure turn normalized to only ~0.20, and even a saturated turn to ~0.74).
    /// This reference (0.025) puts a high-pressure turn near ~0.50, a mid turn near ~0.35, benign turns
    /// near ~0.12, and the saturated extreme at the 1.0 cap — so the caution DISCRIMINATES
    /// proportionally to temporal pressure. The SAFETY proofs (raise-only, monotonic, byte-equal-off,
    /// verdict-gated) are independent of this magnitude — it only scales the bounded raise within
    /// [0, BASSSMCautionInput.ssmCautionRiskIncrement].
    static let cautionReferenceMagnitude: Double = 0.025

    /// Deterministic reducer: the temporal magnitude (max-abs over the scan output) normalized to
    /// [0, 1] by the reference. Pure + bounded.
    public static func ssmCaution(fromScanOutput y: [Float]) -> Double {
        var maxAbs: Float = 0
        for v in y where v.isFinite { maxAbs = Swift.max(maxAbs, abs(v)) }
        let normalized = Double(maxAbs) / cautionReferenceMagnitude
        return Swift.min(1.0, Swift.max(0.0, normalized))
    }

    static func rawMagnitude(_ y: [Float]) -> Double {
        var maxAbs: Float = 0
        for v in y where v.isFinite { maxAbs = Swift.max(maxAbs, abs(v)) }
        return Double(maxAbs)
    }

    public static func project(
        sessionID: String,
        turnID: String,
        input: BASMambaTurnScanInput,
        scanOutput y: [Float]
    ) -> BASMambaSSMTurnObservation {
        BASMambaSSMTurnObservation(
            sessionID: sessionID,
            turnID: turnID,
            affectCount: input.affectCount,
            historyCount: input.historyCount,
            candidateCount: input.candidateCount,
            ssmCaution: ssmCaution(fromScanOutput: y),
            finalMagnitude: rawMagnitude(y))
    }

    /// Host-callable per-turn SSM operator probe. nil `sink` OR all-empty sources ⇒ no run ⇒ returns
    /// nil (byte-equal, 红线 7). SYNC + CPU-deterministic (`BASSSMScanCPUReference`) — no GPU/async.
    @discardableResult
    public static func runShadowIfEnabled(
        sessionID: String,
        turnID: String,
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath],
        sink: (@Sendable (BASMambaSSMTurnObservation) -> Void)? = nil
    ) -> BASMambaSSMTurnObservation? {
        guard let sink else { return nil }
        guard let input = BASMambaTurnSignalBuilder.scanInput(
            affectLayers: affectLayers, turnHistory: turnHistory, candidates: candidates)
        else { return nil }
        guard let y = try? BASSSMScanCPUReference.scan(
            x: input.x, delta: input.delta, A: input.a, B: input.b, C: input.c, shape: input.shape)
        else { return nil }
        let observation = project(
            sessionID: sessionID, turnID: turnID, input: input, scanOutput: y)
        sink(observation)
        return observation
    }
}
