import XCTest
@testable import QinaoSeats

/// M313 — pin that `QinaoSampleHost --phase-dispatch-demo`'s
/// `PhaseDispatchDemo.run()` helper composes M312 (9-seat council
/// via `QinaoDefaults.makeStandardWithAdapters`) + M309
/// (`dispatchByPhase`) end-to-end.
///
/// `QinaoSampleHost` is an executable target so tests can't import
/// the demo helper directly. These tests instead pin the
/// **substrate contract** the demo depends on (mirroring the
/// M298 `QinaoSampleHostUnifiedLocatorTests` pattern), so any
/// breaking shape change in M309 / M312 surfaces here as a
/// Qinao-side test failure.
///
/// What this file pins:
///
///   1. `QinaoAgentConcurrencyPhase` exposes exactly 3 cases in
///      raw-value form (perception / cognition / landing) — demo
///      banner relies on this set.
///   2. The 9-seat partition published in
///      `QinaoAgentConcurrencyPhase.seatsInPhase` equals
///      `QinaoSeat.allCases` (M312's 9-seat factory matches
///      M309's phase partition).
///   3. Phase raw values are `"perception"` / `"cognition"` /
///      `"landing"` — the demo banner grep-matches these.
///   4. `seatsInPhase` is partition-disjoint (no seat in two
///      phases).
final class QinaoSampleHostPhaseDispatchTests: XCTestCase {

    /// 1. 3 phases — banner has 3 lines.
    func testPhaseEnumHasThreeCases() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.allCases.count, 3)
    }

    /// 2. 9-seat partition matches `QinaoSeat.allCases` so M312's
    ///    9-seat factory + M309's phase partition compose.
    func testPartitionUnionEqualsAllSeats() {
        var union: Set<QinaoSeat> = []
        for phase in QinaoAgentConcurrencyPhase.allCases {
            union.formUnion(phase.seatsInPhase)
        }
        XCTAssertEqual(union, Set(QinaoSeat.allCases))
    }

    /// 3. Banner grep keys: phase raw values stable.
    func testPhaseRawValuesMatchBannerKeys() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.perception.rawValue,
            "perception")
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.cognition.rawValue,
            "cognition")
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.landing.rawValue,
            "landing")
    }

    /// 4. Partition is disjoint — no seat lands in two phases.
    func testPartitionIsDisjoint() {
        var pairs: [(QinaoAgentConcurrencyPhase, Set<QinaoSeat>)] = []
        for phase in QinaoAgentConcurrencyPhase.allCases {
            pairs.append((phase, phase.seatsInPhase))
        }
        for i in 0..<pairs.count {
            for j in (i + 1)..<pairs.count {
                let overlap =
                    pairs[i].1.intersection(pairs[j].1)
                XCTAssertTrue(
                    overlap.isEmpty,
                    "phases \(pairs[i].0) and \(pairs[j].0) " +
                    "share seats \(overlap) — partition must " +
                    "be disjoint")
            }
        }
    }
}
