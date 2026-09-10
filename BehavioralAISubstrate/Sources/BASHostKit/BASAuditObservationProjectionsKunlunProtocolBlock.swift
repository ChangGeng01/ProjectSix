// MARK: - BASAuditObservationProjectionsKunlunProtocolBlock
// chapter 五百十六 / M1441 — 4th typed input block for
//                            audit projections
//
// Aggregates the 9 Kunlun-protocol-verification fields
// that feed `BASAuditObservationProjections`。 4th sibling
// of the chapter 511-514 input block series:
//   - M1421 KunlunInputs (18 trio/hexa fields)
//   - M1423 CthulhuInputs (8 trio/penta fields)
//   - M1433 ObservationBundles (11 cognitive bundles)
//   - M1441 (this file) KunlunProtocolBlock (9 protocol
//     verification fields)
//
// ## Why this exists
//
// Post-M1437 V1 monolith fold, the residual 22+ named
// args at the projections call site (EBrainRuntime
// Coordinator.swift:2035) include a tight cluster of 9
// Kunlun-protocol-verification fields:
//
//   1. kunlunAxisAlignment (M402)
//   2. jadeCanonVerification (M404)
//   3. jadeCanonObjectClass (M405)
//   4. riverOriginLineage (M405)
//   5. yaochiAccess (M408)
//   6. yaochiSanctumClass (M408)
//   7. tianmenReadiness (M409)
//   8. tianmenGateClass (M409)
//   9. tianmenPassState (M409)
//
// These 9 fields are derived from the Kunlun protocol
// verification path (axis check + jade canon seal +
// river origin trace + yaochi sanctum access + tianmen
// gate readiness)。 Packaging them into ONE typed input
// block reduces the V1 call-site arg count by 9。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 9
//     protocol fields accessed via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 61 → 62
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1440 → M1441

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface block packaging the 9 Kunlun-protocol
/// -verification fields that feed audit projections。
/// All fields optional — hosts skipping a Kunlun
/// protocol path (e.g. heavily-redirected turn that
/// never touches yaochi) leave fields nil。
public struct BASAuditObservationProjectionsKunlunProtocolBlock:
    Codable, Equatable, Sendable
{

    // MARK: - 9 Kunlun-protocol-verification fields

    /// L6 axis alignment from M402 axis-protocol。
    public let kunlunAxisAlignment: BASAxisAlignment?

    /// L3 jade canon verification from M404 protocol。
    public let jadeCanonVerification:
        BASKunlunJadeCanonProtocol.Verification?

    /// L3 jade canon object class (M405)。
    public let jadeCanonObjectClass:
        BASJadeCanonObjectClass?

    /// L5 river origin lineage report from M405 protocol。
    public let riverOriginLineage:
        BASKunlunRiverOriginProtocol.LineageReport?

    /// L8 yaochi access decision from M408 protocol。
    public let yaochiAccess:
        BASKunlunYaochiProtocol.AccessDecision?

    /// L8 yaochi sanctum class (M408)。
    public let yaochiSanctumClass:
        BASYaochiSanctumClass?

    /// L9 tianmen heaven-gate readiness from M409
    /// protocol。
    public let tianmenReadiness:
        BASKunlunHeavenGateProtocol.Readiness?

    /// L9 tianmen heaven-gate class (M409)。
    public let tianmenGateClass: BASKunlunGateClass?

    /// L9 tianmen heaven-gate pass state (M409)。
    public let tianmenPassState: BASKunlunGateState?

    // MARK: - Construction

    public init(
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        jadeCanonVerification:
            BASKunlunJadeCanonProtocol.Verification? = nil,
        jadeCanonObjectClass:
            BASJadeCanonObjectClass? = nil,
        riverOriginLineage:
            BASKunlunRiverOriginProtocol.LineageReport? = nil,
        yaochiAccess:
            BASKunlunYaochiProtocol.AccessDecision? = nil,
        yaochiSanctumClass: BASYaochiSanctumClass? = nil,
        tianmenReadiness:
            BASKunlunHeavenGateProtocol.Readiness? = nil,
        tianmenGateClass: BASKunlunGateClass? = nil,
        tianmenPassState: BASKunlunGateState? = nil
    ) {
        self.kunlunAxisAlignment = kunlunAxisAlignment
        self.jadeCanonVerification = jadeCanonVerification
        self.jadeCanonObjectClass = jadeCanonObjectClass
        self.riverOriginLineage = riverOriginLineage
        self.yaochiAccess = yaochiAccess
        self.yaochiSanctumClass = yaochiSanctumClass
        self.tianmenReadiness = tianmenReadiness
        self.tianmenGateClass = tianmenGateClass
        self.tianmenPassState = tianmenPassState
    }

    // MARK: - Coverage queries

    /// Count of fields that are non-nil。 0-9。
    public var populatedFieldCount: Int {
        var n = 0
        if kunlunAxisAlignment != nil { n += 1 }
        if jadeCanonVerification != nil { n += 1 }
        if jadeCanonObjectClass != nil { n += 1 }
        if riverOriginLineage != nil { n += 1 }
        if yaochiAccess != nil { n += 1 }
        if yaochiSanctumClass != nil { n += 1 }
        if tianmenReadiness != nil { n += 1 }
        if tianmenGateClass != nil { n += 1 }
        if tianmenPassState != nil { n += 1 }
        return n
    }

    /// `true` when all 9 protocol fields populated —
    /// host walked the full Kunlun protocol chain on
    /// this turn。
    public var hasFullProtocolCoverage: Bool {
        populatedFieldCount == 9
    }

    /// `true` when ZERO protocol fields populated —
    /// host bypassed the Kunlun protocol path entirely
    /// (e.g. shadow-locked turn,quarantine path)。
    public var hasNoProtocolCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton for tests + hosts
    /// emitting minimal projections。
    public static let empty =
        BASAuditObservationProjectionsKunlunProtocolBlock()

    /// Field count invariant — 9 Kunlun protocol fields。
    /// If a future chapter adds a 10th protocol field
    /// (e.g. a new layer's verification record),this
    /// constant moves AND the block gains a matching
    /// field,or audit emission silently loses
    /// coverage。 PROOF test pins this。
    public static let protocolFieldCount: Int = 9
}
