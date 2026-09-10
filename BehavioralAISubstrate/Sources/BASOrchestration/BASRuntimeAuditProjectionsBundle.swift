// MARK: - BASRuntimeAuditProjectionsBundle
// chapter 四百四 v3 / M976 — 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v3 second cut:typed
// aggregator bundling the 4 audit-projection namespaces
// (M971 kunlun + M972 abyssal + M973 cthulhu + M975 tribunal)
// into ONE Sendable Equatable value type that V2 actor stages
// pass as ONE arg through the audit emission pipeline。
//
// Per audit + M971-M975 ledger:
//
//   > V2 actor stages currently would thread 4 separate audit-
//   > projection bundles through to the .complete envelope's
//   > payload assembly。Aggregator collapses to 1 arg。
//
// ## What this ships
//
//   - `BASRuntimeAuditProjectionsBundle` value type holding
//     the 4 namespace projections (kunlun / abyssal / cthulhu
//     / tribunal)
//   - `none()` factory producing all-empty projections (used
//     by V2 actor's early stages before derives fire)
//   - `with(...)` family — one method per slot,returns fresh
//     bundle (immutable accumulator pattern matching M961
//     BASTurnFrameBuilder)
//   - `populatedSlotCount` aggregate accessor (sums per-
//     namespace counts)
//
// Note:`BASCthulhuAuditProjections` is Equatable + Sendable
// only (not Codable);this aggregator drops Codable too to
// match the weakest link。 Hosts that need JSON serialization
// build a custom payload from the populated kunlun + abyssal
// + tribunal bundles directly。
//
// ## Doctrine pins held
//
// All chapter 四百三/四百四 doctrine pins。

import Foundation

/// Typed aggregator of the 4 audit-projection namespace
/// bundles。V2 actor stages pass this as one arg through
/// the audit emission pipeline instead of threading 4
/// separate values。
public struct BASRuntimeAuditProjectionsBundle:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots (1 per namespace)

    public let kunlun: BASKunlunAuditProjections
    public let abyssal: BASAbyssalAuditProjections
    public let cthulhu: BASCthulhuAuditProjections
    public let tribunal: BASTribunalAuditProjections
    /// chapter 四百四 v4 / M979 — 5th namespace slot:risk
    /// calibration projections (BASRiskCard / decisionPackage
    /// / permitBinding) per M978。
    public let riskCalibration:
        BASRiskCalibrationProjections

    // MARK: - Init

    public init(
        kunlun: BASKunlunAuditProjections = .none(),
        abyssal: BASAbyssalAuditProjections = .none(),
        cthulhu: BASCthulhuAuditProjections = .none(),
        tribunal: BASTribunalAuditProjections = .none(),
        riskCalibration: BASRiskCalibrationProjections
            = .none()
    ) {
        self.kunlun = kunlun
        self.abyssal = abyssal
        self.cthulhu = cthulhu
        self.tribunal = tribunal
        self.riskCalibration = riskCalibration
    }

    /// All-empty bundle for V2 actor early stages。
    public static func none()
        -> BASRuntimeAuditProjectionsBundle
    {
        BASRuntimeAuditProjectionsBundle()
    }

    // MARK: - Immutable updates

    public func with(
        kunlun: BASKunlunAuditProjections
    ) -> BASRuntimeAuditProjectionsBundle {
        BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: riskCalibration)
    }

    public func with(
        abyssal: BASAbyssalAuditProjections
    ) -> BASRuntimeAuditProjectionsBundle {
        BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: riskCalibration)
    }

    public func with(
        cthulhu: BASCthulhuAuditProjections
    ) -> BASRuntimeAuditProjectionsBundle {
        BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: riskCalibration)
    }

    public func with(
        tribunal: BASTribunalAuditProjections
    ) -> BASRuntimeAuditProjectionsBundle {
        BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: riskCalibration)
    }

    /// chapter 四百四 v4 / M979 — `with(riskCalibration:)` for
    /// the 5th namespace。
    public func with(
        riskCalibration: BASRiskCalibrationProjections
    ) -> BASRuntimeAuditProjectionsBundle {
        BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: riskCalibration)
    }

    // MARK: - Aggregate accessors

    /// Total populated slots across all 5 namespaces (sum of
    /// per-namespace `populatedSlotCount`)。
    public var populatedSlotCount: Int {
        kunlun.populatedSlotCount
            + abyssal.populatedSlotCount
            + cthulhu.populatedSlotCount
            + tribunal.populatedSlotCount
            + riskCalibration.populatedSlotCount
    }

    /// `true` when any of the 5 namespaces has at least one
    /// populated slot。
    public var hasAnyProjection: Bool {
        kunlun.hasAnyProjection
            || abyssal.hasAnyProjection
            || cthulhu.hasAnyProjection
            || tribunal.hasAnyProjection
            || riskCalibration.hasAnyProjection
    }
}
