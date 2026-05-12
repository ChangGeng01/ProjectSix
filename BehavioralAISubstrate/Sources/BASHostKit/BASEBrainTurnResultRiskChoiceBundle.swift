// MARK: - BASEBrainTurnResultRiskChoiceBundle
// chapter 五百二十九 / M1493 — typed risk/choice cluster
//                              packaging surface
//
// Aggregates the 4 risk/choice-decision fields of
// `BASEBrainTurnResult` into one typed input surface。
// 6th cluster bundle in the BASEBrainTurnResult fold
// arc。
//
// ## Why this exists
//
// 4 of the remaining ~22 args on BASEBrainTurnResult
// form a cohesive L11/L12 risk-evaluation cluster:
//
//   1. triScores — L10 tri-self self-evaluation scores
//   2. mergedChoice — L10 winning candidate after merge
//   3. riskCard — L11 risk classification (REQUIRED)
//   4. actionPermit — L12 action permit (REQUIRED)
//
// triScores and mergedChoice represent the candidate-
// selection chain output;riskCard and actionPermit
// represent the risk-vetting + action-permission chain
// output。 All 4 are emitted per turn and are required
// (non-optional)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 4
//     risk/choice fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 74 → 75
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1492 → M1493

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed-surface bundle packaging the 4 risk/choice
/// fields of `BASEBrainTurnResult`。 All 4 fields are
/// REQUIRED (non-optional)。
public struct BASEBrainTurnResultRiskChoiceBundle:
    Codable, Equatable, Sendable
{

    // MARK: - 4 risk/choice fields

    /// L10 tri-self self-evaluation scores (required)。
    public let triScores: [BASTriSelfScore]

    /// L10 merged winning candidate (required)。
    public let mergedChoice: BASMergedChoice

    /// L11 risk classification card (required)。
    public let riskCard: BASRiskCard

    /// L12 action permit (required)。
    public let actionPermit: BASActionPermit

    // MARK: - Construction

    public init(
        triScores: [BASTriSelfScore],
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) {
        self.triScores = triScores
        self.mergedChoice = mergedChoice
        self.riskCard = riskCard
        self.actionPermit = actionPermit
    }

    // MARK: - Coverage queries

    /// All 4 risk/choice fields are non-optional,so
    /// count is always 4 (or 3 if triScores is empty)。
    public var populatedFieldCount: Int {
        // triScores can be empty array — count only
        // when non-empty for symmetry with sibling
        // bundles。
        return 3 + (triScores.isEmpty ? 0 : 1)
    }

    /// Field count invariant — 4 risk/choice fields。
    public static let riskChoiceFieldCount: Int = 4
}
