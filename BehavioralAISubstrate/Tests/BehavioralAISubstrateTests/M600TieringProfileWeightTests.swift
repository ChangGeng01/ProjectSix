import XCTest
@testable import BASMemory

/// **M600 chapter 一百七十一 — composite heat weight anti-drift tests**.
///
/// Pin the 3 heuristic weights extracted from
/// `BASMemoryTieringProfile.swift` (chapter 一百六十六 §166.5 backlog
/// item 4 of 6):
/// - `compositeHeatRecencyWeight = 0.55` (dominant)
/// - `compositeHeatAccessWeight = 0.35` (secondary)
/// - `compositeHeatStalenessPenaltyWeight = 0.10` (penalty)
///
/// Doctrine: recency dominates → access boosts → staleness
/// penalizes. Tier ordering: recency > access > staleness.
final class M600TieringProfileWeightTests: XCTestCase {

    /// Pin individual weight values.
    func testWeightValuesPinned() {
        XCTAssertEqual(
            BASMemoryTieringProfile.compositeHeatRecencyWeight,
            0.55)
        XCTAssertEqual(
            BASMemoryTieringProfile.compositeHeatAccessWeight,
            0.35)
        XCTAssertEqual(
            BASMemoryTieringProfile
                .compositeHeatStalenessPenaltyWeight,
            0.10)
    }

    /// Pin doctrine ordering: recency (0.55) > access (0.35) >
    /// staleness penalty (0.10). Recency dominates (substrate
    /// memory is recency-biased); access boosts (repeated probes
    /// = relevance); staleness penalizes (drifted atoms cooler).
    /// Regression guard against accidental weight inversion.
    func testWeightOrderingPinned() {
        XCTAssertGreaterThan(
            BASMemoryTieringProfile.compositeHeatRecencyWeight,
            BASMemoryTieringProfile.compositeHeatAccessWeight,
            """
            Recency (0.55) must dominate access (0.35).
            Doctrine: substrate memory is inherently recency-biased.
            """)
        XCTAssertGreaterThan(
            BASMemoryTieringProfile.compositeHeatAccessWeight,
            BASMemoryTieringProfile
                .compositeHeatStalenessPenaltyWeight,
            """
            Access weight (0.35) must dominate staleness penalty
            (0.10). Doctrine: positive boosts > negative penalties
            in magnitude.
            """)
    }

    /// **NEW doctrine layer (extends fraction-family from chapter
    /// 一百七十)**: weights MUST sum to exactly 1.0. This pins
    /// doctrine intent that the formula is a normalized weighted
    /// blend (probabilistic-style weights). If anyone changes
    /// any weight without rebalancing the others, this test
    /// surfaces the doctrine question.
    ///
    /// Sum-to-one is a stronger doctrine pin than fraction-family:
    /// it forces a constraint across all 3 constants jointly.
    func testWeightsSumToOne() {
        let sum = BASMemoryTieringProfile
            .compositeHeatRecencyWeight
            + BASMemoryTieringProfile
                .compositeHeatAccessWeight
            + BASMemoryTieringProfile
                .compositeHeatStalenessPenaltyWeight
        XCTAssertEqual(
            sum, 1.0, accuracy: 0.001,
            """
            Composite heat weights must sum to exactly 1.0
            (probabilistic-style normalized blend). Currently
            sums to \(sum). If you intentionally re-weight,
            update this test AND verify the formula still
            produces a [0, 1]-bounded score under all input
            combinations.
            """)
    }

    /// Pin: all weights in [0, 1] sanity bound.
    func testWeightsInValidRange() {
        let weights = [
            BASMemoryTieringProfile.compositeHeatRecencyWeight,
            BASMemoryTieringProfile.compositeHeatAccessWeight,
            BASMemoryTieringProfile
                .compositeHeatStalenessPenaltyWeight,
        ]
        for w in weights {
            XCTAssertGreaterThanOrEqual(w, 0.0)
            XCTAssertLessThanOrEqual(w, 1.0)
        }
    }

    /// Behavioral pin: extreme inputs produce expected composite
    /// heat. Verifies formula correctness given the constants.
    func testBehavioralFormulaCorrectness() {
        // Max recency, max access, no staleness → near 1.0
        let hot = BASMemoryTieringProfile(
            atomID: "hot",
            currentTier: .hot,
            recencyScore: 1.0,
            accessFrequency: 1.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date())
        // 0.55*1 + 0.35*1 - 0.10*0 = 0.90
        XCTAssertEqual(
            hot.compositeHeat, 0.90, accuracy: 0.001)

        // No recency, no access, max staleness → 0
        let cold = BASMemoryTieringProfile(
            atomID: "cold",
            currentTier: .cold,
            recencyScore: 0.0,
            accessFrequency: 0.0,
            sensitivityDrift: 0.0,
            worldContextStaleness: 1.0,
            observedAt: Date())
        // 0 + 0 - 0.10 → clamped to 0
        XCTAssertEqual(cold.compositeHeat, 0.0)
    }
}
