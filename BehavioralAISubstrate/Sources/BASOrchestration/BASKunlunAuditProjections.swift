// MARK: - BASKunlunAuditProjections — chapter 四百四 v2 / M971
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 v2 second cut: typed namespace
// struct collapsing the 5 most-frequently-referenced kunlun-
// related `*ForAudit` locals from V1 runTurn into one bundle。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit (M952 close-out):
//
//   > Audit-projection entropy: 67 distinct *ForAudit /
//   > *ForGate locals。Top 5 kunlun-related by frequency:
//   >   - kunlunHeavenGateForAudit (BASHeavenGatePermit) 7×
//   >   - kunlunAxisForAudit (BASAxisAlignment) 6×
//   >   - kunlunHeavenGateReadinessForAudit 6×
//   >   - kunlunJadeSealForAudit 5×
//   >   - kunlunRiverTraceForAudit 5×
//
// `BASKunlunAuditProjections` is a Sendable Equatable Codable
// namespace bundle of the 5 kunlun audit projections。V2 actor
// stages (and V1 callers that adopt it) construct one bundle
// per turn instead of holding 5 separate locals。Audit emission
// reads from the bundle's typed slots,not from scattered
// var-locals。
//
// ## What this ships
//
//   - `BASKunlunAuditProjections` value type with 5 typed
//     fields (heavenGate / axisAlignment / readinessRef /
//     jadeSealRef / riverTraceRef)
//   - Convenience init with all 5 args
//   - `none()` factory producing empty/default projections
//     for tests + early-stage callers
//   - Equatable + Codable conformance for replay-determinism
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — bundle is observation plumbing
//   - 红线 7 hint-only — bundle is audit data,not decisions
//   - chapter 一百八十五 anti-magic-number — typed fields,no
//     stringly-typed audit refs
//   - chapter 二百一一 single-source-of-truth — ONE bundle for
//     5 kunlun projections;V2 stages read from this surface
//   - chapter 三百九二 replay-determinism — Equatable + Codable
//     + value semantics
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed namespace bundle of the 5 most-frequently-referenced
/// kunlun-related audit projections。V2 actor stages (+ V1
/// adopters) build one per turn instead of holding 5 separate
/// var-locals。
public struct BASKunlunAuditProjections:
    Codable, Equatable, Sendable
{

    // MARK: - Typed slots

    /// Heaven gate permit projection at audit time。Optional
    /// because not every turn admits through the gate。
    public let heavenGate: BASHeavenGatePermit?

    /// Kunlun axis alignment projection。
    public let axisAlignment: BASAxisAlignment?

    /// Stable ref to the heaven-gate readiness assessment。
    /// Held as ref-string per chapter 一百八十五 anti-magic-
    /// number doctrine (the readiness type may evolve;ref
    /// stays grep-able)。
    public let readinessRef: String?

    /// Stable ref to the jade canon seal applied this turn。
    public let jadeSealRef: String?

    /// Stable ref to the river-origin trace projection。
    public let riverTraceRef: String?

    // MARK: - Init

    public init(
        heavenGate: BASHeavenGatePermit? = nil,
        axisAlignment: BASAxisAlignment? = nil,
        readinessRef: String? = nil,
        jadeSealRef: String? = nil,
        riverTraceRef: String? = nil
    ) {
        self.heavenGate = heavenGate
        self.axisAlignment = axisAlignment
        self.readinessRef = readinessRef
        self.jadeSealRef = jadeSealRef
        self.riverTraceRef = riverTraceRef
    }

    // MARK: - Convenience factories

    /// Empty projections (all slots nil)。Used by early-stage
    /// callers + tests when the kunlun derives haven't fired yet。
    public static func none() -> BASKunlunAuditProjections {
        BASKunlunAuditProjections()
    }

    // MARK: - Convenience accessors

    /// `true` when at least one projection slot is populated。
    /// Used by audit emission to skip empty bundles。
    public var hasAnyProjection: Bool {
        heavenGate != nil
            || axisAlignment != nil
            || readinessRef != nil
            || jadeSealRef != nil
            || riverTraceRef != nil
    }

    /// Number of populated projection slots (0-5)。
    public var populatedSlotCount: Int {
        var count = 0
        if heavenGate != nil { count += 1 }
        if axisAlignment != nil { count += 1 }
        if readinessRef != nil { count += 1 }
        if jadeSealRef != nil { count += 1 }
        if riverTraceRef != nil { count += 1 }
        return count
    }
}
