import XCTest
@testable import BASOrgan

/// The Universal Draft Layer "brain": `BASAcceptanceProfiler` (online per-source×purpose EMA, immutable-update)
/// + `BASDecodeLanePolicy.source(for:profiler:)` (greedy-only, pick-one, hit-floor fallback). Pins the routing
/// doctrine: free-form never speculates; cross-turn is the cold-start default; warm picks the higher-acceptance
/// source; a source below the hit floor falls back to plain AR (不要亏).
final class BASDraftSourceRouterTests: XCTestCase {

    private let SA = BASDraftSourceChoice.suffixAutomatonID
    private let PL = BASDraftSourceChoice.promptLookupID

    // MARK: - Profiler

    func testColdProfiler() {
        let p = BASAcceptanceProfiler()
        XCTAssertNil(p.stat(SA, .factual))
        XCTAssertEqual(p.recommendedK(sourceID: SA, purpose: .factual, cap: 4), 4, "cold → full cap")
        XCTAssertTrue(p.worthSpeculating(sourceID: SA, purpose: .factual, minHitRate: 0.05), "cold → try it")
    }

    func testObservingIsImmutableAndFoldsEMA() throws {
        let p0 = BASAcceptanceProfiler()
        let p1 = p0.observing(sourceID: SA, purpose: .factual, accepted: 6, proposed: 8, rounds: 2) // acc/round 3, hit .75
        XCTAssertNil(p0.stat(SA, .factual), "original profiler is unchanged (immutability)")
        let s1 = try XCTUnwrap(p1.stat(SA, .factual))
        XCTAssertEqual(s1.emaAccepted, 3.0, accuracy: 1e-9)
        XCTAssertEqual(s1.emaHitRate, 0.75, accuracy: 1e-9)
        let p2 = p1.observing(sourceID: SA, purpose: .factual, accepted: 1, proposed: 10, rounds: 1) // acc 1, hit .1
        let s2 = try XCTUnwrap(p2.stat(SA, .factual))
        XCTAssertEqual(s2.emaAccepted, 2.2, accuracy: 1e-9, "0.6*3 + 0.4*1")
        XCTAssertEqual(s2.emaHitRate, 0.49, accuracy: 1e-9, "0.6*.75 + 0.4*.1")
        XCTAssertEqual(s2.observations, 2)
    }

    func testZeroRoundsIsNoOp() {
        let p = BASAcceptanceProfiler().observing(sourceID: SA, purpose: .factual, accepted: 5, proposed: 5, rounds: 4)
        XCTAssertEqual(p.observing(sourceID: SA, purpose: .factual, accepted: 0, proposed: 0, rounds: 0), p)
    }

    func testRecommendedKRamp() {
        let p = BASAcceptanceProfiler().observing(sourceID: SA, purpose: .factual, accepted: 3, proposed: 4, rounds: 1)
        XCTAssertEqual(p.recommendedK(sourceID: SA, purpose: .factual, cap: 8), 4, "round(3)+1, capped 8")
    }

    // MARK: - Router

    func testFreeFormNeverSpeculates() {
        let p = BASAcceptanceProfiler()
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .creative, profiler: p), .none)
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .scoutDefault, profiler: p), .none)
    }

    func testColdPrefersCrossTurn() {
        let p = BASAcceptanceProfiler()
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .factual, profiler: p), .suffixAutomaton)
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .deterministic, profiler: p), .suffixAutomaton)
    }

    func testWarmPicksHigherAcceptance() {
        var p = BASAcceptanceProfiler()
        p = p.observing(sourceID: SA, purpose: .factual, accepted: 1, proposed: 4, rounds: 1)
        p = p.observing(sourceID: PL, purpose: .factual, accepted: 3, proposed: 4, rounds: 1)
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .factual, profiler: p), .promptLookup)

        var q = BASAcceptanceProfiler()
        q = q.observing(sourceID: SA, purpose: .factual, accepted: 3, proposed: 4, rounds: 1)
        q = q.observing(sourceID: PL, purpose: .factual, accepted: 1, proposed: 4, rounds: 1)
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .factual, profiler: q), .suffixAutomaton)
    }

    func testBelowHitFloorFallsBack() {
        let p = BASAcceptanceProfiler().observing(sourceID: SA, purpose: .factual, accepted: 1, proposed: 100, rounds: 1)
        XCTAssertEqual(BASDecodeLanePolicy.source(for: .factual, profiler: p), .none,
            "chosen source below the hit floor → fall back to plain AR (不要亏)")
    }

    // MARK: - acceleratedChoice (the respondAccelerated gate — byte-safety must never invert)

    func testAcceleratedChoiceGreedyGate() {
        let cold = BASAcceptanceProfiler()
        // Non-greedy temperature → .none regardless of purpose/profiler (argmax-equality accept is temp-0 only).
        XCTAssertEqual(BASDecodeLanePolicy.acceleratedChoice(temperature: 0.7, purpose: .factual, profiler: cold), .none)
        XCTAssertEqual(BASDecodeLanePolicy.acceleratedChoice(temperature: 0.1, purpose: .deterministic, profiler: cold), .none)
        // temp == 0 → delegates to source(for:profiler:)
        XCTAssertEqual(BASDecodeLanePolicy.acceleratedChoice(temperature: 0, purpose: .factual, profiler: cold), .suffixAutomaton)
        XCTAssertEqual(BASDecodeLanePolicy.acceleratedChoice(temperature: 0, purpose: .creative, profiler: cold), .none)
    }
}
