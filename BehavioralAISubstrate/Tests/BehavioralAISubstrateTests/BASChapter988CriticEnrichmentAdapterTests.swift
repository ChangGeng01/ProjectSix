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
        // None vetoed → fraction = 0 → adapter would NOT raise
        // base; verify base is preserved (not lowered)。
        let lowScores = [
            triScore(id: "c.1", superego: 0.2, veto: false),
            triScore(id: "c.2", superego: 0.1, veto: false),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: lowScores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.9,
            accuracy: 0.001,
            "ch 988 CRITICAL Gap 4: lower tri-derived concern " +
            "MUST NOT lower base superegoActiveLevel (ch 967 " +
            "monotonic raise — base 0.9 + tri-fraction 0 → stays 0.9)")
    }

    /// chapter 九百九十一.5 META-REVIEW GAP-7 (Reviewer 2):
    /// "equal stays equal" mutation-safety pin。 If
    /// `max(a, b)` were mutated to `max(a, b - epsilon)` no
    /// existing test caught it。 This pins exactness。
    func testCRITICAL_EqualBaseAndFraction_OutputExactlyEqual() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.5)
        // 1 vetoed / 2 = 0.5 — equal to base
        let scores = [
            triScore(id: "c.1", veto: false),
            triScore(id: "c.2", veto: true),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.5,
            accuracy: 0.001,
            "ch 991.5 GAP-7: base == fraction-vetoed → output " +
            "MUST be exactly equal (mutation-safety pin)")
    }

    // chapter 九百九十一.5 META-REVIEW HIGH-1 fix:semantic
    // inversion of superegoScore caught at Round 9。 The pre-fix
    // adapter averaged non-vetoed superego scores and used the
    // AVG as `superegoActiveLevel` — but superegoScore=safety,
    // not concern,so avg=0.85 of two safe candidates produced
    // strict critic next turn (inverted)。 Fix uses fraction-
    // vetoed instead。 Tests below are updated for the corrected
    // semantic — high-safety candidates produce LOW concern,
    // any veto in the population raises concern。

    func testCRITICAL_HighSafetyCandidatesProduceLowConcern() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.0)
        // Two SAFE candidates (high superego = high reversibility)
        // → 0 vetoed / 2 total = 0 concern。 Adapter MUST NOT
        // raise strictness when prior turn was all safe。
        let safeScores = [
            triScore(id: "c.1", superego: 0.8, veto: false),
            triScore(id: "c.2", superego: 0.9, veto: false),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: safeScores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.0,
            accuracy: 0.001,
            "ch 991.5 HIGH-1 CRITICAL: safe candidates (HIGH " +
            "superegoScore,none vetoed) MUST produce LOW " +
            "concern。 Pre-fix bug:adapter averaged safety " +
            "scores and called the result strictness — inverted。")
    }

    func testFractionVetoed_HalfVetoedRaisesToHalf() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.0)
        let scores = [
            triScore(id: "c.1", superego: 0.5, veto: false),
            triScore(id: "c.2", superego: 0.7, veto: false),
            triScore(id: "c.3", superego: 0.1, veto: true),
            triScore(id: "c.4", superego: 0.15, veto: true),
        ]
        // 2 vetoed / 4 total = 0.5 fraction
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores,
                baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 0.5,
            accuracy: 0.001,
            "ch 991.5 HIGH-1: fraction-vetoed MUST drive " +
            "concern signal (2/4 = 0.5)")
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
        superego: Double = 0.5,
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
