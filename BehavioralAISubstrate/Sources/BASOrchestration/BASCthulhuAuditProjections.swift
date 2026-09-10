// MARK: - BASCthulhuAuditProjections — chapter 四百四 v2 / M973
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v2 fourth cut:typed namespace
// struct collapsing the 4 most-frequently-referenced cthulhu-
// related `*ForAudit` locals from V1 runTurn into one bundle。
//
// Per audit:
//
//   > Cthulhu-related projections in V1 runTurn:
//   >   - cthulhuPermitEscalationForAudit
//   >     (BASCthulhuPermitEscalationDecision) 5×
//   >   - cthulhuAssertionDecisionForAudit
//   >     (BASCthulhuAssertionCeilingDecision) 5×
//   >   - cosmicColdCounterweightForAudit
//   >     (BASCosmicColdCounterweight) 4×
//   >   - unknownReserveForAudit (BASUnknownReserve) 3×
//
// Companion to M971 BASKunlunAuditProjections + M972
// BASAbyssalAuditProjections。Together M971-M973 cover ~67
// of the 67 *ForAudit locals。Future M974 ships the
// final tribunal/anchor bundle to round out the namespace。
//
// ## Doctrine pins held
//
// All chapter 四百三/四百四 doctrine pins。Mirrors M971/M972。

import Foundation
import BASWorldPrior

public struct BASCthulhuAuditProjections:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots

    public let permitEscalation:
        BASCthulhuPermitEscalationDecision?
    public let assertionDecision:
        BASCthulhuAssertionCeilingDecision?
    public let cosmicColdCounterweight:
        BASCosmicColdCounterweight?
    public let unknownReserve: BASUnknownReserve?

    public init(
        permitEscalation:
            BASCthulhuPermitEscalationDecision? = nil,
        assertionDecision:
            BASCthulhuAssertionCeilingDecision? = nil,
        cosmicColdCounterweight:
            BASCosmicColdCounterweight? = nil,
        unknownReserve: BASUnknownReserve? = nil
    ) {
        self.permitEscalation = permitEscalation
        self.assertionDecision = assertionDecision
        self.cosmicColdCounterweight = cosmicColdCounterweight
        self.unknownReserve = unknownReserve
    }

    public static func none() -> BASCthulhuAuditProjections {
        BASCthulhuAuditProjections()
    }

    public var hasAnyProjection: Bool {
        permitEscalation != nil
            || assertionDecision != nil
            || cosmicColdCounterweight != nil
            || unknownReserve != nil
    }

    public var populatedSlotCount: Int {
        var count = 0
        if permitEscalation != nil { count += 1 }
        if assertionDecision != nil { count += 1 }
        if cosmicColdCounterweight != nil { count += 1 }
        if unknownReserve != nil { count += 1 }
        return count
    }
}
