// MARK: - BASAffectLayerProjection
// chapter 一百八十六 / ADR-019 P1.5b — materialize TYPED affect on the value path
//
// Typed `BASAffectLayer` is NOT produced on the authoritative runtime turn path: it lives only on the
// whitepaper-literal AUDIT shape `BASCognitiveDissectionFrame` (never constructed per-turn). The
// authoritative runtime frame `BASDecomposeFrame` instead carries the typed L7 PRESSURE signal
// (`pressureVectors: [BASPressureVector]`, each with [0,1] `strength` / `authenticity` + a `kind`).
// This projection MATERIALIZES typed affect from that real per-turn signal — one `BASAffectLayer` per
// pressure vector, in frame order — so the SSM caution operator can consume affect as one of its three
// live sources (the "materialize typed affect first" path).
//
// DETERMINISTIC + BOUNDED + PROVISIONAL: every output field is a pure, [0,1]-bounded transform of a real
// runtime field (and `BASAffectLayer.init` re-clamps). The feature SEMANTICS (the volatility /
// spilloverRisk derivations) are PROVISIONAL — the SSM operator's scope is safe-direction + deterministic,
// NOT a calibrated affect model (calibration is deferred, mirroring `cautionReferenceMagnitude`). Used
// ONLY inside the flag-gated SSM seam, so flag-off is byte-equal (红线 7 / ADR-014): this projection never
// runs unless `ssmCautionOperatorEnabled` short-circuits true first.

import Foundation
import BASOrchestration

enum BASAffectLayerProjection {

    /// Materialize typed affect layers from the authoritative runtime frame's typed pressure vectors.
    /// One `BASAffectLayer` per `BASPressureVector`, in frame order (deterministic). Empty pressure →
    /// empty affect (the SSM builder then zero-pads the affect block). Pure + bounded.
    ///   • tone          = pressure kind label                (real categorical signal)
    ///   • intensity     = strength                           (the pressure's literal [0,1] magnitude)
    ///   • volatility    = 1 − authenticity                   (manufactured / inauthentic pressure reads
    ///                                                          as volatile; bounded since authenticity ∈ [0,1])
    ///   • spilloverRisk = strength × (1 − authenticity)      (intense + inauthentic pressure spills over)
    static func project(from frame: BASDecomposeFrame) -> [BASAffectLayer] {
        frame.pressureVectors.map { vector in
            let volatility = 1.0 - vector.authenticity
            return BASAffectLayer(
                tone: vector.kind.rawValue,
                intensity: vector.strength,
                volatility: volatility,
                spilloverRisk: vector.strength * volatility)
        }
    }
}
