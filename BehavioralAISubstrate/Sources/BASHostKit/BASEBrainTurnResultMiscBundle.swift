// MARK: - BASEBrainTurnResultMiscBundle
// chapter 五百三十 / M1497 — typed misc cluster
//                            packaging surface
//
// Aggregates the 4 remaining "miscellaneous" output
// fields of `BASEBrainTurnResult` into one typed input
// surface。 7th cluster bundle in the BASEBrainTurnResult
// fold arc。
//
// ## Why this exists
//
// 4 of the remaining ~18 args on BASEBrainTurnResult
// form a "post-decision output" cluster — fields that
// represent the substrate's externally-visible outputs
// from a turn:
//
//   1. riskDecisionPackage — L11 typed risk-decision
//      package (optional)
//   2. hostGateValue — L13 host-gate computed value
//      (Double,REQUIRED)
//   3. renderedOutput — L12 final rendered output
//      (REQUIRED)
//   4. updateTickets — L13 update tickets emitted this
//      turn (REQUIRED)
//
// These 4 are what the HOST sees as turn output:the
// risk-decision summary,the host-gate score,the
// rendered content,and the update tickets。 Packaging
// them into a typed surface makes the host-facing
// boundary clearer。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 4 misc
//     fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 75 → 76
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1496 → M1497

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed-surface bundle packaging the 4 miscellaneous
/// output fields of `BASEBrainTurnResult`。 3 required
/// (hostGateValue + renderedOutput + updateTickets) +
/// 1 optional (riskDecisionPackage)。
public struct BASEBrainTurnResultMiscBundle:
    Codable, Equatable, Sendable
{

    // MARK: - 4 miscellaneous output fields

    /// L11 typed risk-decision package (optional)。
    public let riskDecisionPackage:
        BASRiskDecisionPackage?

    /// L13 host-gate computed value (required)。
    public let hostGateValue: Double

    /// L12 final rendered output (required)。
    public let renderedOutput: BASRenderedOutput

    /// L13 update tickets emitted this turn (required)。
    public let updateTickets: [BASUpdateTicket]

    // MARK: - Construction

    public init(
        riskDecisionPackage:
            BASRiskDecisionPackage? = nil,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket]
    ) {
        self.riskDecisionPackage = riskDecisionPackage
        self.hostGateValue = hostGateValue
        self.renderedOutput = renderedOutput
        self.updateTickets = updateTickets
    }

    // MARK: - Coverage queries

    /// Count of populated fields (2-4)。 hostGateValue +
    /// renderedOutput always populated (Double + struct
    /// required);riskDecisionPackage and updateTickets
    /// can be nil/empty。
    public var populatedFieldCount: Int {
        var n = 2  // hostGateValue + renderedOutput always
        if riskDecisionPackage != nil { n += 1 }
        if !updateTickets.isEmpty { n += 1 }
        return n
    }

    /// Field count invariant — 4 misc output fields。
    public static let miscFieldCount: Int = 4
}
