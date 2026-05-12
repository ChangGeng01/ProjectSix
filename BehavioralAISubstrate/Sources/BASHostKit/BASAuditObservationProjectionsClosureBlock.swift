// MARK: - BASAuditObservationProjectionsClosureBlock
// chapter 五百十八 / M1449 — 6th typed input block for
//                            audit projections
//
// Aggregates the 7 closure-themed fields that feed
// `BASAuditObservationProjections`。 6th sibling of the
// chapter 511-517 typed input block series:
//   - M1421 KunlunInputs (18 trio/hexa fields)
//   - M1423 CthulhuInputs (8 trio/penta fields)
//   - M1433 ObservationBundles (11 cognitive bundles)
//   - M1441 KunlunProtocolBlock (9 protocol fields)
//   - M1445 CthulhuAggregatesBlock (7 L1-L7 aggregate
//     fields)
//   - M1449 (this file) ClosureBlock (7 closure /
//     reconciliation / reserve fields)
//
// ## Why this exists
//
// Post-M1447 V1 monolith fold,the residual ~13 named
// args at the projections call site include a 7-field
// cluster of closure-themed fields:
//
//   1. candidateObservationBundle (thoughtArtifact)
//   2. tribunalObservationBundle (thoughtFrame closure)
//   3. unknownReserve (reserve aggregate)
//   4. forbiddenAggregate (forbidden knowledge reserve)
//   5. layerReconciliationVerdict (M436 verdict)
//   6. layerReconciliationReport (M436 report)
//   7. escalationSuppressionCodes (M417 suppression
//      codes,non-optional array with default [])
//
// These 7 fields share a closure/reconciliation theme:
//   - 2 thoughtArtifact bundles (candidate + tribunal)
//     close the per-candidate observation chain
//   - 2 reserve fields (unknown + forbidden) close the
//     L7 reserve aggregation
//   - 2 reconciliation outputs (verdict + report) close
//     the L14 layer reconciliation
//   - 1 suppression code list closes the M417 escalation
//     suppression chain
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 7
//     closure fields accessed via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 63 → 64
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1448 → M1449

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// Typed-surface block packaging the 7 closure-themed
/// fields that feed audit projections。 6 optional + 1
/// non-optional array (escalationSuppressionCodes has
/// default [])。
public struct BASAuditObservationProjectionsClosureBlock:
    Equatable, Sendable
{

    // MARK: - 7 closure-themed fields

    /// L7 thoughtArtifact:candidate observation bundle。
    public let candidateObservationBundle:
        BASCandidateObservationBundle?

    /// L7/L11 thoughtArtifact:tribunal observation
    /// bundle。
    public let tribunalObservationBundle:
        BASTribunalObservationBundle?

    /// L7 reserve aggregate:unknown reserve。
    public let unknownReserve: BASUnknownReserve?

    /// L7 reserve aggregate:forbidden knowledge
    /// aggregate。
    public let forbiddenAggregate:
        BASForbiddenKnowledgeCandidate.Aggregate?

    /// L14 reconciliation:layer reconciliation verdict
    /// from M436 reconciliation engine。
    public let layerReconciliationVerdict:
        BASObservationReconciliationVerdict?

    /// L14 reconciliation:layer reconciliation report
    /// from M436 reconciliation engine。
    public let layerReconciliationReport:
        BASObservationReconciliationReport?

    /// L11 escalation suppression codes from M417
    /// suppression chain。 Non-optional array,defaults
    /// to []。
    public let escalationSuppressionCodes: [String]

    // MARK: - Construction

    public init(
        candidateObservationBundle:
            BASCandidateObservationBundle? = nil,
        tribunalObservationBundle:
            BASTribunalObservationBundle? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        forbiddenAggregate:
            BASForbiddenKnowledgeCandidate.Aggregate? = nil,
        layerReconciliationVerdict:
            BASObservationReconciliationVerdict? = nil,
        layerReconciliationReport:
            BASObservationReconciliationReport? = nil,
        escalationSuppressionCodes: [String] = []
    ) {
        self.candidateObservationBundle =
            candidateObservationBundle
        self.tribunalObservationBundle =
            tribunalObservationBundle
        self.unknownReserve = unknownReserve
        self.forbiddenAggregate = forbiddenAggregate
        self.layerReconciliationVerdict =
            layerReconciliationVerdict
        self.layerReconciliationReport =
            layerReconciliationReport
        self.escalationSuppressionCodes =
            escalationSuppressionCodes
    }

    // MARK: - Coverage queries

    /// Count of fields that are non-nil + 1 if
    /// escalationSuppressionCodes has any entries。 0-7。
    public var populatedFieldCount: Int {
        var n = 0
        if candidateObservationBundle != nil { n += 1 }
        if tribunalObservationBundle != nil { n += 1 }
        if unknownReserve != nil { n += 1 }
        if forbiddenAggregate != nil { n += 1 }
        if layerReconciliationVerdict != nil { n += 1 }
        if layerReconciliationReport != nil { n += 1 }
        if !escalationSuppressionCodes.isEmpty { n += 1 }
        return n
    }

    /// `true` when all 7 closure fields populated。
    public var hasFullClosureCoverage: Bool {
        populatedFieldCount == 7
    }

    /// `true` when ZERO closure fields populated。
    public var hasNoClosureCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton for tests + minimal-
    /// projection hosts。
    public static let empty =
        BASAuditObservationProjectionsClosureBlock()

    /// Field count invariant — 7 closure fields。
    public static let closureFieldCount: Int = 7
}
