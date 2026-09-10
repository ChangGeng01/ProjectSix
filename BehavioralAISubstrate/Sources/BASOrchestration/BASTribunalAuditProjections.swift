// MARK: - BASTribunalAuditProjections — chapter 四百四 v3 / M975
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v3 first cut:fourth typed
// audit-projection namespace bundle (after M971 kunlun + M972
// abyssal + M973 cthulhu)。Collapses 3 most-frequently-
// referenced tribunal-related projections from V1 runTurn
// into one bundle。
//
// Per audit:
//
//   > Tribunal-related projections:
//   >   - triScoresForAudit ([BASTriSelfScore]) 4×
//   >   - mergedChoiceForAudit (BASMergedChoice) 5×
//   >   - arbitrationFrameForAudit (BASArbitrationFrame) 3×
//
// Together M971+M972+M973+M975 cover ~70+ of V1 runTurn's
// audit-projection locals。
//
// ## What this ships
//
//   - `BASTribunalAuditProjections` value type (Sendable +
//     Equatable + Codable) with 3 typed slots
//   - `none()` factory + accessors mirroring M971-M973
//
// ## Doctrine pins held
//
// All chapter 四百三/四百四 doctrine pins。

import Foundation

public struct BASTribunalAuditProjections:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots

    public let triScores: [BASTriSelfScore]
    public let mergedChoice: BASMergedChoice?
    public let arbitrationFrame: BASArbitrationFrame?

    public init(
        triScores: [BASTriSelfScore] = [],
        mergedChoice: BASMergedChoice? = nil,
        arbitrationFrame: BASArbitrationFrame? = nil
    ) {
        self.triScores = triScores
        self.mergedChoice = mergedChoice
        self.arbitrationFrame = arbitrationFrame
    }

    public static func none() -> BASTribunalAuditProjections {
        BASTribunalAuditProjections()
    }

    public var hasAnyProjection: Bool {
        !triScores.isEmpty
            || mergedChoice != nil
            || arbitrationFrame != nil
    }

    public var populatedSlotCount: Int {
        var count = 0
        if !triScores.isEmpty { count += 1 }
        if mergedChoice != nil { count += 1 }
        if arbitrationFrame != nil { count += 1 }
        return count
    }

    /// Number of tri-self scores in the bundle (0 when empty)。
    public var triScoreCount: Int {
        triScores.count
    }
}
