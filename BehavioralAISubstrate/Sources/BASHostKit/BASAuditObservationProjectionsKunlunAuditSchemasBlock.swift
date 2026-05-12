// MARK: - BASAuditObservationProjectionsKunlunAuditSchemasBlock
// chapter 五百二十一 / M1461 — 7th typed input block
//
// Aggregates the 3 M424 (chapter 一百二十四) Kunlun audit
// schemas that feed `BASAuditObservationProjections`。
// 7th sibling in the chapter 511-520 typed input block
// series:
//
//   - M1421 KunlunInputs (18 trio/hexa fields)
//   - M1423 CthulhuInputs (8 trio/penta fields)
//   - M1433 ObservationBundles (11 cognitive bundles)
//   - M1441 KunlunProtocolBlock (9 protocol fields)
//   - M1445 CthulhuAggregatesBlock (7 L1-L7 aggregates)
//   - M1449 ClosureBlock (7 closure-themed fields)
//   - M1461 (this file) KunlunAuditSchemasBlock (3
//     M424 Kunlun audit schemas)
//
// ## Why this exists
//
// Post-M1451 V1 monolith fold,3 cohesive Kunlun audit
// schemas remain as named args at the projections call
// site:
//
//   1. kunlunAxisView (M424 — L6 axis-view audit
//      schema)
//   2. kunlunTianmenWarrant (M424 — L9 tianmen-warrant
//      audit schema)
//   3. kunlunGateDenialWrit (M424 — L9 gate-denial-writ
//      audit schema)
//
// All 3 are from chapter 一百二十四 (M424) — the same
// chapter introduced these typed audit schemas as the
// post-verdict audit emission surface for the Kunlun
// gate path。 Packaging them into ONE typed input block
// reduces the V1 call-site arg count by 3。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 3 M424
//     Kunlun audit schemas via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 66 → 67
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1460 → M1461

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface block packaging the 3 M424 Kunlun
/// audit schemas that feed audit projections。 All 3
/// fields optional — hosts skipping the Kunlun audit
/// path leave fields nil。
public struct BASAuditObservationProjectionsKunlunAuditSchemasBlock:
    Codable, Equatable, Hashable, Sendable
{

    // MARK: - 3 M424 Kunlun audit schemas

    /// L6 axis view audit schema (M424 chapter 一百
    /// 二十四)。
    public let kunlunAxisView: BASKunlunAxisView?

    /// L9 tianmen warrant audit schema (M424)。
    public let kunlunTianmenWarrant:
        BASKunlunTianmenWarrant?

    /// L9 gate denial writ audit schema (M424)。
    public let kunlunGateDenialWrit:
        BASKunlunGateDenialWrit?

    // MARK: - Construction

    public init(
        kunlunAxisView: BASKunlunAxisView? = nil,
        kunlunTianmenWarrant:
            BASKunlunTianmenWarrant? = nil,
        kunlunGateDenialWrit:
            BASKunlunGateDenialWrit? = nil
    ) {
        self.kunlunAxisView = kunlunAxisView
        self.kunlunTianmenWarrant =
            kunlunTianmenWarrant
        self.kunlunGateDenialWrit =
            kunlunGateDenialWrit
    }

    // MARK: - Coverage queries

    /// Count of fields that are non-nil。 0-3。
    public var populatedFieldCount: Int {
        var n = 0
        if kunlunAxisView != nil { n += 1 }
        if kunlunTianmenWarrant != nil { n += 1 }
        if kunlunGateDenialWrit != nil { n += 1 }
        return n
    }

    /// `true` when all 3 audit schemas populated。
    public var hasFullAuditSchemaCoverage: Bool {
        populatedFieldCount == 3
    }

    /// `true` when ZERO audit schemas populated。
    public var hasNoAuditSchemaCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton for tests + minimal-
    /// projection hosts。
    public static let empty =
        BASAuditObservationProjectionsKunlunAuditSchemasBlock()

    /// Field count invariant — 3 M424 Kunlun audit
    /// schemas。
    public static let auditSchemaFieldCount: Int = 3
}
