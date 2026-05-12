// MARK: - BASAuditObservationProjectionsCthulhuLeftoversBlock
// chapter 五百二十二 / M1465 — 8th typed input block
//
// Aggregates the 6 remaining Cthulhu + surface-alias
// leftover fields that feed `BASAuditObservation
// Projections`。 8th and FINAL block in the chapter 511-
// 522 typed input block series:
//
//   - M1421 KunlunInputs (18 trio/hexa fields)
//   - M1423 CthulhuInputs (8 trio/penta fields)
//   - M1433 ObservationBundles (11 cognitive bundles)
//   - M1441 KunlunProtocolBlock (9 protocol fields)
//   - M1445 CthulhuAggregatesBlock (7 L1-L7 aggregates)
//   - M1449 ClosureBlock (7 closure-themed fields)
//   - M1461 KunlunAuditSchemasBlock (3 M424 schemas)
//   - M1465 (this file) CthulhuLeftoversBlock (6
//     leftover Cthulhu + L12 surface aliases)
//
// ## Why this exists
//
// Post-M1463 V1 monolith fold,6 residual fields remain
// as named args at the projections call site:
//
//   1. ontologyShiftMark (M495 chapter 一百二十七
//      Cthulhu leftover)
//   2. narrativeDistortionMap (M495 chapter 一百二十七
//      Cthulhu leftover)
//   3. cthulhuAssertionCeilingReasonCodes (M445
//      assertion ceiling decision reason codes)
//   4. cthulhuPermitEscalationReasonCodes (M446 permit
//      escalation decision reason codes)
//   5. cthulhuSurfaceAlias (M502 chapter 一百二十八 L12
//      surface alias)
//   6. kunlunSurfaceAlias (M502 chapter 一百二十八 L12
//      surface alias)
//
// All 6 are "leftover" Cthulhu/surface fields not
// absorbed by the prior 7 blocks。 Packaging them into
// ONE typed input block achieves 100% V1 call-site
// packaging coverage (no named args remaining)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 6
//     leftover fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 67 → 68
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1464 → M1465

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface block packaging the 6 leftover Cthulhu
/// + L12 surface alias fields that feed audit
/// projections。 8th and final block,achieves 100% V1
/// call-site packaging coverage when used。
public struct BASAuditObservationProjectionsCthulhuLeftoversBlock:
    Equatable, Hashable, Sendable
{

    // MARK: - 6 leftover fields

    /// M495 (chapter 一百二十七) Cthulhu leftover:
    /// ontology shift mark schema。
    public let ontologyShiftMark: BASOntologyShiftMark?

    /// M495 (chapter 一百二十七) Cthulhu leftover:
    /// narrative distortion map。
    public let narrativeDistortionMap:
        BASNarrativeDistortionMap?

    /// M445 Cthulhu assertion-ceiling-gate decision
    /// reason codes (non-optional array,default [])。
    public let cthulhuAssertionCeilingReasonCodes:
        [String]

    /// M446 Cthulhu permit-escalation decision reason
    /// codes (non-optional array,default [])。
    public let cthulhuPermitEscalationReasonCodes:
        [String]

    /// M502 (chapter 一百二十八) L12 Cthulhu surface
    /// alias。
    public let cthulhuSurfaceAlias:
        BASCthulhuSurfaceAlias?

    /// M502 (chapter 一百二十八) L12 Kunlun surface
    /// alias。
    public let kunlunSurfaceAlias:
        BASKunlunSurfaceAlias?

    // MARK: - Construction

    public init(
        ontologyShiftMark:
            BASOntologyShiftMark? = nil,
        narrativeDistortionMap:
            BASNarrativeDistortionMap? = nil,
        cthulhuAssertionCeilingReasonCodes: [String] = [],
        cthulhuPermitEscalationReasonCodes: [String] = [],
        cthulhuSurfaceAlias:
            BASCthulhuSurfaceAlias? = nil,
        kunlunSurfaceAlias:
            BASKunlunSurfaceAlias? = nil
    ) {
        self.ontologyShiftMark = ontologyShiftMark
        self.narrativeDistortionMap =
            narrativeDistortionMap
        self.cthulhuAssertionCeilingReasonCodes =
            cthulhuAssertionCeilingReasonCodes
        self.cthulhuPermitEscalationReasonCodes =
            cthulhuPermitEscalationReasonCodes
        self.cthulhuSurfaceAlias = cthulhuSurfaceAlias
        self.kunlunSurfaceAlias = kunlunSurfaceAlias
    }

    // MARK: - Coverage queries

    /// Count of fields that are non-nil + 1 each for
    /// non-empty reason code arrays。 0-6。
    public var populatedFieldCount: Int {
        var n = 0
        if ontologyShiftMark != nil { n += 1 }
        if narrativeDistortionMap != nil { n += 1 }
        if !cthulhuAssertionCeilingReasonCodes
            .isEmpty
        {
            n += 1
        }
        if !cthulhuPermitEscalationReasonCodes
            .isEmpty
        {
            n += 1
        }
        if cthulhuSurfaceAlias != nil { n += 1 }
        if kunlunSurfaceAlias != nil { n += 1 }
        return n
    }

    /// `true` when all 6 leftover fields populated。
    public var hasFullLeftoverCoverage: Bool {
        populatedFieldCount == 6
    }

    /// `true` when ZERO leftover fields populated。
    public var hasNoLeftoverCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton。
    public static let empty =
        BASAuditObservationProjectionsCthulhuLeftoversBlock()

    /// Field count invariant — 6 leftover fields。
    public static let leftoverFieldCount: Int = 6
}
