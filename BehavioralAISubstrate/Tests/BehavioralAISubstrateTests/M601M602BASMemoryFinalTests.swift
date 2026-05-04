import XCTest
@testable import BASMemory

/// **M601 chapter 一百七十二 — final BASMemory backlog tests**.
///
/// Pin remaining 2 categories from chapter 一百六十六 §166.5 backlog
/// (5 of 6 + 6 of 6 — closes backlog completely):
/// - M601: BASReactionWeights seed defaults (6 values)
/// - M602: BASShadowTrialObservationBudget cost budget (6 values, sum-to-one)
final class M601M602BASMemoryFinalTests: XCTestCase {

    // MARK: - M601 BASReactionWeights seed defaults

    /// Pin individual seed values.
    func testReactionWeightSeedsPinned() {
        XCTAssertEqual(
            BASReactionWeights.defaultBriefLanguageSeed, 0.50)
        XCTAssertEqual(
            BASReactionWeights.defaultWarmDirectToneSeed, 0.54)
        XCTAssertEqual(
            BASReactionWeights.defaultLowCognitiveLoadSeed, 0.50)
        XCTAssertEqual(
            BASReactionWeights
                .defaultInterruptiveActionBiasSeed, 0.44)
        XCTAssertEqual(
            BASReactionWeights.defaultBoundaryNamingBiasSeed, 0.46)
        XCTAssertEqual(
            BASReactionWeights.defaultTradeoffClarityBiasSeed, 0.50)
    }

    /// Pin: all seeds in [0, 1] sanity bound (anti-magic-number
    /// chapter 一百十三 doctrine).
    func testReactionWeightSeedsInValidRange() {
        let seeds = [
            BASReactionWeights.defaultBriefLanguageSeed,
            BASReactionWeights.defaultWarmDirectToneSeed,
            BASReactionWeights.defaultLowCognitiveLoadSeed,
            BASReactionWeights
                .defaultInterruptiveActionBiasSeed,
            BASReactionWeights.defaultBoundaryNamingBiasSeed,
            BASReactionWeights.defaultTradeoffClarityBiasSeed,
        ]
        for s in seeds {
            XCTAssertGreaterThanOrEqual(s, 0.0)
            XCTAssertLessThanOrEqual(s, 1.0)
        }
    }

    /// Pin doctrine: seeds 0.50-centered (neutral baseline) with
    /// axis-specific deviations. Specifically: interruptive action
    /// + boundary naming MUST be < 0.50 (substrate defaults to
    /// non-interruptive + implicit boundaries).
    func testReactionWeightSeedDoctrine() {
        // Substrate defaults to non-interruptive (< 0.50)
        XCTAssertLessThan(
            BASReactionWeights
                .defaultInterruptiveActionBiasSeed,
            0.50,
            """
            Substrate defaults to non-interruptive. The
            interruptiveActionBias seed must be < 0.50
            (slight bias against interrupting).
            """)
        // Substrate defaults to implicit boundaries (< 0.50)
        XCTAssertLessThan(
            BASReactionWeights.defaultBoundaryNamingBiasSeed,
            0.50,
            """
            Substrate defaults to implicit boundaries. The
            boundaryNamingBias seed must be < 0.50.
            """)
    }

    /// Behavioral: `defaults(for:)` produces the seeded values.
    func testDefaultsConstructorMatchesSeeds() {
        let weights = BASReactionWeights.defaults(for: "any")
        XCTAssertEqual(
            weights.briefLanguage,
            BASReactionWeights.defaultBriefLanguageSeed)
        XCTAssertEqual(
            weights.warmDirectTone,
            BASReactionWeights.defaultWarmDirectToneSeed)
        XCTAssertEqual(
            weights.lowCognitiveLoad,
            BASReactionWeights.defaultLowCognitiveLoadSeed)
        XCTAssertEqual(
            weights.interruptiveActionBias,
            BASReactionWeights
                .defaultInterruptiveActionBiasSeed)
        XCTAssertEqual(
            weights.boundaryNamingBias,
            BASReactionWeights.defaultBoundaryNamingBiasSeed)
        XCTAssertEqual(
            weights.tradeoffClarityBias,
            BASReactionWeights.defaultTradeoffClarityBiasSeed)
    }

    // MARK: - M602 BASShadowTrialObservationBudget signal costs

    /// Pin individual cost values.
    func testSignalCostsPinned() {
        XCTAssertEqual(
            BASShadowTrialObservationBudget.ticketIssuedCost,
            0.10)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.trialRunCost, 0.40)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.parityVerifiedCost,
            0.20)
        XCTAssertEqual(
            BASShadowTrialObservationBudget
                .regressionDetectedCost, 0.20)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.promotionVoteCost,
            0.05)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.quarantineVoteCost,
            0.05)
    }

    /// Pin doctrine ordering:
    /// trialRun (0.40, most expensive — sandboxed pass)
    ///   > parity == regression (0.20 each — mid-tier checks)
    ///   > ticketIssued (0.10 — cheap metadata)
    ///   > votes (0.05 each — cheapest, just recording)
    func testSignalCostOrderingPinned() {
        XCTAssertGreaterThan(
            BASShadowTrialObservationBudget.trialRunCost,
            BASShadowTrialObservationBudget.parityVerifiedCost,
            """
            trialRun must be most expensive — runs sandboxed
            pass over reference corpus.
            """)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.parityVerifiedCost,
            BASShadowTrialObservationBudget
                .regressionDetectedCost,
            """
            parity + regression are mid-tier checks of equal cost.
            """)
        XCTAssertGreaterThan(
            BASShadowTrialObservationBudget.parityVerifiedCost,
            BASShadowTrialObservationBudget.ticketIssuedCost,
            """
            mid-tier checks > cheap metadata
            """)
        XCTAssertGreaterThan(
            BASShadowTrialObservationBudget.ticketIssuedCost,
            BASShadowTrialObservationBudget.promotionVoteCost,
            """
            ticket issuance > vote recording
            """)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.promotionVoteCost,
            BASShadowTrialObservationBudget.quarantineVoteCost,
            """
            both vote types are equal cost (just signal recording).
            """)
    }

    /// **Doctrine layer 6 (chapter 一百七十一)**: signal costs
    /// MUST sum to exactly 1.0 (normalized cost budget).
    /// If any cost changes without rebalancing, this test
    /// fails and surfaces the doctrine question.
    func testSignalCostsSumToOne() {
        let sum = BASShadowTrialObservationBudget.ticketIssuedCost
            + BASShadowTrialObservationBudget.trialRunCost
            + BASShadowTrialObservationBudget.parityVerifiedCost
            + BASShadowTrialObservationBudget
                .regressionDetectedCost
            + BASShadowTrialObservationBudget.promotionVoteCost
            + BASShadowTrialObservationBudget.quarantineVoteCost
        XCTAssertEqual(
            sum, 1.0, accuracy: 0.001,
            """
            Signal costs must sum to exactly 1.0 (normalized
            cost budget). Currently sums to \(sum). If you
            intentionally re-weight, update this test AND verify
            the budget is still semantically a probability
            distribution.
            """)
    }

    /// Behavioral: `signalCost` dictionary contains all 6 named
    /// values + each maps to expected static constant.
    func testSignalCostDictionaryMatchesConstants() {
        let dict = BASShadowTrialObservationBudget.signalCost
        XCTAssertEqual(dict.count, 6)
        XCTAssertEqual(
            dict[.ticketIssued],
            BASShadowTrialObservationBudget.ticketIssuedCost)
        XCTAssertEqual(
            dict[.trialRun],
            BASShadowTrialObservationBudget.trialRunCost)
        XCTAssertEqual(
            dict[.parityVerified],
            BASShadowTrialObservationBudget.parityVerifiedCost)
        XCTAssertEqual(
            dict[.regressionDetected],
            BASShadowTrialObservationBudget
                .regressionDetectedCost)
        XCTAssertEqual(
            dict[.promotionVote],
            BASShadowTrialObservationBudget.promotionVoteCost)
        XCTAssertEqual(
            dict[.quarantineVote],
            BASShadowTrialObservationBudget.quarantineVoteCost)
    }
}
