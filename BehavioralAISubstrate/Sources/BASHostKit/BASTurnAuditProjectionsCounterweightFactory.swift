// MARK: - BASTurnAuditProjectionsCounterweightFactory
// chapter 五百十 / M1417 — cosmic-cold counterweight fold
//
// Folds the inline 13-line BASCosmicColdCounterweight
// construction at coordinator line 1336-1348 into a
// typed factory call。 The 4 Self.* helper functions
// (dignityBiasFromRisk + agencyFloorFromCandidates +
// antiFatalismFromRisk + antiPaternalismFromPermit)
// continue to live on EBrainRuntimeCoordinator as
// fileprivate;the factory takes the precomputed values
// as inputs to keep the helpers' visibility unchanged。
//
// HONEST SCOPE — chapter 五百十:
// =============================================================
// Pure-function factory — preserves the exact same
// construction order + clamping semantics as the inline
// V1 monolith。 V1 byte-equality preserved (factory
// produces an identical BASCosmicColdCounterweight given
// the same inputs)。 Stress-sweep dual mode canonical60
// regression-guards the splice。

import Foundation
import BASOrchestration

/// Typed pure-function factory for the per-turn cosmic-
/// cold counterweight construction at chapter 一百十八
/// M450 coordinator seam。
public enum BASTurnAuditProjectionsCounterweightFactory
{

    /// Construct a BASCosmicColdCounterweight from
    /// precomputed bias / floor / counterweight values。
    /// The 4 input doubles are clamped to [0, 1] inside
    /// the BASCosmicColdCounterweight init per chapter
    /// 一百八十七 doctrine — this factory passes them
    /// through。
    public static func compute(
        sessionID: String,
        dignityBias: Double,
        agencyFloor: Double,
        antiFatalism: Double,
        antiPaternalism: Double
    ) -> BASCosmicColdCounterweight {
        return BASCosmicColdCounterweight(
            counterweightID:
                "cosmic-cold-\(sessionID)",
            dignityBias: dignityBias,
            agencyFloor: agencyFloor,
            antiFatalism: antiFatalism,
            antiPaternalism: antiPaternalism)
    }
}
