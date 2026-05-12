// MARK: - BASEBrainTurnResultAuditProjectionForwardBundle
// chapter 五百二十六 / M1481 — typed audit-projection-
//                              forwarded cluster
//                              packaging surface
//
// Aggregates the 7 audit-projection-forwarded fields of
// `BASEBrainTurnResult` into one typed input surface。
// 3rd cluster bundle in the BASEBrainTurnResult fold
// (chapter 524 evolution + chapter 525 sovereign)。
//
// ## Why this exists
//
// `BASEBrainTurnResult.init(...)` takes ~52 named args。
// 7 form a tight cluster of typed schema projections
// forwarded from the audit projections / V1 helper
// outputs:
//
//   1. kunlunAxisAlignment (M578 chapter 一百五十三 —
//      L6 axis alignment forwarded for downstream
//      observability)
//   2. humanAnchorSignal (M578 — L5 anchor signal)
//   3. abyssalPressure (M578 — L1 pressure aggregate)
//   4. unknownReserve (M578 — L7 reserve)
//   5. kunlunHeavenGatePermit (M581 chapter 一百五十六 —
//      L9 tianmen permit construction from line 335)
//   6. kunlunRiverOriginTrace (M581 — L5 river origin
//      trace from line 1901)
//   7. yaochiSanctumEntry (M581 — L8 yaochi sanctum
//      entry from line 267)
//
// All 7 are typed schema-mode projections wired so
// downstream observability / bench code can read REAL
// substrate-emitted records instead of synthesizing
// them from runtime tuples。 V1 monolith forwards each
// from a projections.xxxField access OR an earlier
// runTurn-scope local。
//
// This typed bundle:
//   - Packs the 7 fields into ONE typed surface
//   - Adds a 3-bundle convenience init on BASEBrain
//     TurnResult (M1482) that accepts evolution +
//     sovereign + auditProjectionForward bundles
//   - V1 splice (M1483) collapses 7 named args → 1
//     auditProjectionForward arg at the call site
//
// PUBLIC API preserved:the existing 52-arg
// `BASEBrainTurnResult.init(...)` remains unchanged。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only — old init kept
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 7
//     forwarded fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 71 → 72
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1480 → M1481

import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore
import BASWorldPrior

/// Typed-surface bundle packaging the 7 audit-
/// projection-forwarded fields of `BASEBrainTurnResult`。
/// Pure value-type carrier — no derive calls,no IO。
public struct BASEBrainTurnResultAuditProjectionForwardBundle:
    Equatable, Sendable
{

    // MARK: - 7 audit-projection-forwarded fields

    /// M578 (chapter 一百五十三) L6 axis alignment
    /// forwarded for downstream observability。
    public let kunlunAxisAlignment: BASAxisAlignment?

    /// M578 L5 anchor signal forwarded。
    public let humanAnchorSignal: BASHumanAnchorSignal?

    /// M578 L1 pressure aggregate forwarded。
    public let abyssalPressure: BASAbyssalPressure?

    /// M578 L7 reserve forwarded。
    public let unknownReserve: BASUnknownReserve?

    /// M581 (chapter 一百五十六) L9 tianmen permit
    /// construction forwarded。
    public let kunlunHeavenGatePermit:
        BASHeavenGatePermit?

    /// M581 L5 river origin trace forwarded。
    public let kunlunRiverOriginTrace:
        BASRiverOriginTrace?

    /// M581 L8 yaochi sanctum entry forwarded。
    public let yaochiSanctumEntry:
        BASYaochiSanctumEntry?

    // MARK: - Construction

    public init(
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        kunlunHeavenGatePermit: BASHeavenGatePermit? = nil,
        kunlunRiverOriginTrace:
            BASRiverOriginTrace? = nil,
        yaochiSanctumEntry:
            BASYaochiSanctumEntry? = nil
    ) {
        self.kunlunAxisAlignment = kunlunAxisAlignment
        self.humanAnchorSignal = humanAnchorSignal
        self.abyssalPressure = abyssalPressure
        self.unknownReserve = unknownReserve
        self.kunlunHeavenGatePermit =
            kunlunHeavenGatePermit
        self.kunlunRiverOriginTrace =
            kunlunRiverOriginTrace
        self.yaochiSanctumEntry = yaochiSanctumEntry
    }

    // MARK: - Coverage queries

    /// Count of non-nil fields (0-7)。 Useful for
    /// "how many typed projections did this turn
    /// forward?" audits。
    public var populatedFieldCount: Int {
        var n = 0
        if kunlunAxisAlignment != nil { n += 1 }
        if humanAnchorSignal != nil { n += 1 }
        if abyssalPressure != nil { n += 1 }
        if unknownReserve != nil { n += 1 }
        if kunlunHeavenGatePermit != nil { n += 1 }
        if kunlunRiverOriginTrace != nil { n += 1 }
        if yaochiSanctumEntry != nil { n += 1 }
        return n
    }

    /// `true` when all 7 fields populated (full schema-
    /// mode forwarding)。
    public var hasFullForwardCoverage: Bool {
        populatedFieldCount == 7
    }

    /// `true` when ZERO fields populated (cold turn
    /// from schema-mode forwarding perspective)。
    public var hasNoForwardCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton。
    public static let empty =
        BASEBrainTurnResultAuditProjectionForwardBundle()

    /// Field count invariant — 7 forwarded schema
    /// fields。
    public static let forwardFieldCount: Int = 7
}
