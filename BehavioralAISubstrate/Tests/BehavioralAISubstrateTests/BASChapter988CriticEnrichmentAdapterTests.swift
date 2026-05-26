// MARK: - BASChapter988CriticEnrichmentAdapterTests
// chapter 九百八十八 / M3645 — Cross-Module Integration Arc ch6
//
// Closes ch 982.5 META-REVIEW cross-module Gap 4:
// BASCriticSeat consumed `superegoActiveLevel: Double` manually
// — the fabric Critic was orthogonal to the L10 三我庭's live
// BASMLTriSelfService。 Two parallel critique computations,no
// path connecting them。
//
// Tests pin:
//   1. Empty triScores leaves base input unchanged (no-op)
//   2. Monotonic raise — base level cannot be lowered
//   3. Average superego across non-vetoed candidates
//   4. All-vetoed scenario forces 1.0 (worst-case honesty)
//   5. Defensive clamp for out-of-range scores
//   6. Candidates passed through unchanged
//   7. Determinism

import XCTest
@testable import BASOrchestration
@testable import BASMemory

final class BASChapter988CriticEnrichmentAdapterTests: XCTestCase {

    // MARK: - Empty case

    func testEmptyTriScores_LeavesBaseUnchanged() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.6)
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: [],
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.6,
            accuracy: 0.001,
            "ch 988 Gap 4: empty triScores MUST leave base " +
            "unchanged (no signal,no change)")
    }

    // MARK: - Monotonic raise

    func testCRITICAL_MonotonicRaise_LowerTriCannotLowerBase() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.9)
        let lowScores = [
            triScore(id: "c.1", superego: 0.2),
            triScore(id: "c.2", superego: 0.1),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: lowScores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.9,
            accuracy: 0.001,
            "ch 988 CRITICAL Gap 4: lower tri scores MUST NOT " +
            "lower base superegoActiveLevel (ch 967 monotonic)")
    }

    func testMonotonicRaise_HigherTriRaisesBase() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.3)
        let highScores = [
            triScore(id: "c.1", superego: 0.8),
            triScore(id: "c.2", superego: 0.9),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: highScores,
                baseCriticInput: base)
        // Avg = 0.85
        XCTAssertEqual(enriched.superegoActiveLevel, 0.85,
            accuracy: 0.001,
            "ch 988 Gap 4: higher tri scores MUST raise base " +
            "to the non-vetoed average")
    }

    // MARK: - Veto handling

    func testVetoed_ExcludedFromAverage() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.0)
        let scores = [
            triScore(id: "c.1", superego: 0.5, veto: false),
            triScore(id: "c.2", superego: 0.7, veto: false),
            triScore(id: "c.3", superego: 0.1, veto: true),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        // Avg of non-vetoed (0.5 + 0.7) / 2 = 0.6
        XCTAssertEqual(enriched.superegoActiveLevel, 0.6,
            accuracy: 0.001,
            "ch 988 Gap 4: vetoed candidates MUST be excluded " +
            "from superego average (their score is not " +
            "informative about general concern)")
    }

    func testCRITICAL_AllVetoed_ForcesMaximumConcern() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.3)
        let scores = [
            triScore(id: "c.1", superego: 0.5, veto: true),
            triScore(id: "c.2", superego: 0.7, veto: true),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 1.0,
            accuracy: 0.001,
            "ch 988 CRITICAL Gap 4: all-vetoed prior turn MUST " +
            "force MAXIMUM superegoActiveLevel — worst-case " +
            "honesty per ch 967 monotonic raise")
    }

    // MARK: - Defensive clamp

    func testDefensiveClamp_OutOfRangeScores() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.0)
        // Caller might supply ill-formed scores
        let scores = [
            triScore(id: "c.1", superego: 2.0),  // > 1.0
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        XCTAssertLessThanOrEqual(
            enriched.superegoActiveLevel, 1.0,
            "ch 988 Gap 4: out-of-range tri score MUST clamp " +
            "at 1.0 (defense at adapter boundary)")
    }

    // MARK: - Candidate passthrough

    func testCandidates_PassedThroughUnchanged() {
        let candidates = [
            BASCriticCandidate(
                candidateID: "c.1",
                title: "test",
                expectedBenefit: 0.5,
                expectedCost: 0.3,
                reversibility: 0.7),
        ]
        let base = BASCriticSeatInput(
            candidates: candidates,
            superegoActiveLevel: 0.0)
        let scores = [
            triScore(id: "c.1", superego: 0.5),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.candidates.count, 1)
        XCTAssertEqual(enriched.candidates[0].candidateID, "c.1")
    }

    // MARK: - Determinism

    func testAdapter_IsDeterministic() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.3)
        let scores = [
            triScore(id: "c.1", superego: 0.6),
            triScore(id: "c.2", superego: 0.5),
        ]
        let e1 = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores, baseCriticInput: base)
        let e2 = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores, baseCriticInput: base)
        XCTAssertEqual(
            e1.superegoActiveLevel,
            e2.superegoActiveLevel,
            "ch 988: enrichment MUST be deterministic")
    }

    // MARK: - Helpers

    private func triScore(
        id: String,
        superego: Double,
        veto: Bool = false
    ) -> BASTriSelfScore {
        BASTriSelfScore(
            candidateID: id,
            idScore: 0.5,
            egoScore: 0.5,
            superegoScore: superego,
            mergedScore: 0.5,
            veto: veto)
    }
}
