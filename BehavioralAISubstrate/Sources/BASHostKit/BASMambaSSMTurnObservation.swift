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

    public init(
        sessionID: String,
        turnID: String,
        affectCount: Int,
        historyCount: Int,
        candidateCount: Int,
        ssmCaution: Double,
        finalMagnitude: Double
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.affectCount = affectCount
        self.historyCount = historyCount
        self.candidateCount = candidateCount
        self.ssmCaution = ssmCaution
        self.finalMagnitude = finalMagnitude
    }
}

public enum BASMambaSSMTurnObservationProjection {

    /// Provisional caution calibration: the approximate steady-state |y| for an all-ones input given
    /// the fixed scan constants (Δ=0.1, A=-1, B=0.2, C=0.3): C·(ΔB)/(1−e^{ΔA}) ≈ 0.3·0.02/0.095 ≈ 0.063.
    /// Used to normalize the raw magnitude into a useful [0,1] span. CALIBRATION IS PROVISIONAL —
    /// tuning the caution scale is explicitly a later phase (the safety proofs do not depend on it).
    static let cautionReferenceMagnitude: Double = 0.063

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
