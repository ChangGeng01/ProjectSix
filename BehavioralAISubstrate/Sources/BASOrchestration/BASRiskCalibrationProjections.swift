// MARK: - BASRiskCalibrationProjections
// chapter 四百四 v4 / M978 — 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v4 first cut:fifth typed
// audit-projection namespace (after M971 kunlun + M972 abyssal
// + M973 cthulhu + M975 tribunal)。Collapses the remaining
// risk-calibration related projections from V1 runTurn into
// one bundle。
//
// Per audit:
//
//   > Risk-calibration related projections in V1 runTurn:
//   >   - boundRiskCardForAudit (BASRiskCard) 5×
//   >   - riskDecisionPackageForAudit
//   >     (BASRiskDecisionPackage) 4×
//   >   - selectedRiskBindingForAudit
//   >     (BASRiskPermitBinding) 3×
//
// Together M971+M972+M973+M975+M978 cover the 5 most-
// concentrated audit-projection clusters in V1 runTurn。
// Remaining ~5-8 *ForAudit locals are stage-specific and
// don't cluster naturally — V2 actor stages handle them
// inline。
//
// ## What this ships
//
//   - `BASRiskCalibrationProjections` value type (Sendable +
//     Equatable + Codable) with 3 typed slots
//   - `none()` factory + accessors mirroring M971-M975
//
// ## Doctrine pins held
//
// All chapter 四百三/四百四 doctrine pins。

import Foundation
import BASPolicy

public struct BASRiskCalibrationProjections:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots

    public let riskCard: BASRiskCard?
    public let decisionPackage: BASRiskDecisionPackage?
    public let permitBinding: BASRiskPermitBinding?

    public init(
        riskCard: BASRiskCard? = nil,
        decisionPackage: BASRiskDecisionPackage? = nil,
        permitBinding: BASRiskPermitBinding? = nil
    ) {
        self.riskCard = riskCard
        self.decisionPackage = decisionPackage
        self.permitBinding = permitBinding
    }

    public static func none()
        -> BASRiskCalibrationProjections
    {
        BASRiskCalibrationProjections()
    }

    public var hasAnyProjection: Bool {
        riskCard != nil
            || decisionPackage != nil
            || permitBinding != nil
    }

    public var populatedSlotCount: Int {
        var count = 0
        if riskCard != nil { count += 1 }
        if decisionPackage != nil { count += 1 }
        if permitBinding != nil { count += 1 }
        return count
    }
}
