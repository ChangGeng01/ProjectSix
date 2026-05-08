// MARK: - BASAbyssalAuditProjections — chapter 四百四 v2 / M972
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v2 third cut:typed namespace
// struct collapsing the 4 most-frequently-referenced abyssal-
// related `*ForAudit` locals from V1 runTurn into one bundle。
//
// Per audit:
//
//   > Abyssal-related projections in V1 runTurn:
//   >   - abyssalPressureForAudit (BASAbyssalPressure) 7×
//   >   - humanAnchorSignalForAudit (BASHumanAnchorSignal) 7×
//   >   - narrativeDistortionForAudit (BASNarrativeDistortion) 4×
//   >   - anomalyTraceForAudit (BASAnomalyTrace) 3×
//
// Companion to M971 BASKunlunAuditProjections。Together they
// cover ~50 of the 67 *ForAudit locals。Future commits add
// BASCthulhuAuditProjections + BASTribunalAuditProjections to
// cover the remaining ~17。
//
// ## What this ships
//
//   - `BASAbyssalAuditProjections` value type with 4 typed
//     slots (abyssalPressure / humanAnchorSignal /
//     narrativeDistortion / anomalyTraceRef)
//   - `none()` factory + accessors mirroring M971 pattern
//
// ## Doctrine pins held
//
// All chapter 四百三/四百四 doctrine pins。Mirrors M971。

import Foundation

public struct BASAbyssalAuditProjections:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots

    public let abyssalPressure: BASAbyssalPressure?
    public let humanAnchorSignal: BASHumanAnchorSignal?
    public let narrativeDistortion: BASNarrativeDistortion?
    public let anomalyTraceRef: String?

    public init(
        abyssalPressure: BASAbyssalPressure? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        narrativeDistortion: BASNarrativeDistortion? = nil,
        anomalyTraceRef: String? = nil
    ) {
        self.abyssalPressure = abyssalPressure
        self.humanAnchorSignal = humanAnchorSignal
        self.narrativeDistortion = narrativeDistortion
        self.anomalyTraceRef = anomalyTraceRef
    }

    public static func none() -> BASAbyssalAuditProjections {
        BASAbyssalAuditProjections()
    }

    public var hasAnyProjection: Bool {
        abyssalPressure != nil
            || humanAnchorSignal != nil
            || narrativeDistortion != nil
            || anomalyTraceRef != nil
    }

    public var populatedSlotCount: Int {
        var count = 0
        if abyssalPressure != nil { count += 1 }
        if humanAnchorSignal != nil { count += 1 }
        if narrativeDistortion != nil { count += 1 }
        if anomalyTraceRef != nil { count += 1 }
        return count
    }
}
