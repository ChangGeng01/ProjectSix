// ch1053 / v1.0 §12.2 — proofs for BASSovereigntyMetrics (the sovereignty-metric battery).

import XCTest
import Foundation
@testable import BASOrchestration

final class BASSovereigntyMetricsTests: XCTestCase {

    // rate(): denominator-0-safe, clamped, correct division.
    func testRate() {
        XCTAssertEqual(BASSovereigntyMetricsCompute.rate(0, of: 0), 0)
        XCTAssertEqual(BASSovereigntyMetricsCompute.rate(5, of: 0), 0, "div-by-zero → 0")
        XCTAssertEqual(BASSovereigntyMetricsCompute.rate(1, of: 4), 0.25, accuracy: 1e-9)
        XCTAssertEqual(BASSovereigntyMetricsCompute.rate(9, of: 4), 1.0, "clamped to 1")
    }

    // Empty counts → the safe extreme: completeness/purity = 1, bad-rates = 0, isClean.
    func testEmptyCountsAreClean() {
        let m = BASSovereigntyMetricsCompute.compute(BASSovereigntyCounts())
        XCTAssertEqual(m.lineageCutCompleteness, 1.0, "nothing to cut → complete")
        XCTAssertEqual(m.rollbackPurity, 1.0, "nothing to roll back → pure")
        XCTAssertEqual(m.unauthorizedCommitRate, 0)
        XCTAssertEqual(m.oldSealLeakageRate, 0)
        XCTAssertEqual(m.deletedObjectResurfaceRate, 0)
        XCTAssertTrue(m.isClean)
    }

    // A dirty population computes each rate correctly and is NOT clean.
    func testDirtyCounts() {
        let m = BASSovereigntyMetricsCompute.compute(BASSovereigntyCounts(
            unauthorizedCommits: 1, totalCommitAttempts: 10,
            sovereignSaves: 3, harmfulAttempts: 4,
            lineageDescendantsSevered: 3, lineageDescendantsExpected: 4,
            cleanRollbacks: 1, totalRollbacks: 2,
            oldSealLeaks: 0, oldSealAccessAttempts: 5,
            deletedResurfaced: 2, deletedTotal: 8))
        XCTAssertEqual(m.unauthorizedCommitRate, 0.1, accuracy: 1e-9)
        XCTAssertEqual(m.sovereignSaveRate, 0.75, accuracy: 1e-9)
        XCTAssertEqual(m.lineageCutCompleteness, 0.75, accuracy: 1e-9)
        XCTAssertEqual(m.rollbackPurity, 0.5, accuracy: 1e-9)
        XCTAssertEqual(m.oldSealLeakageRate, 0.0)
        XCTAssertEqual(m.deletedObjectResurfaceRate, 0.25, accuracy: 1e-9)
        XCTAssertFalse(m.isClean, "an unauthorized commit + incomplete cut + impure rollback ≠ clean")
    }

    // A fully-clean population (everything at its safe extreme) is isClean.
    func testFullyCleanPopulation() {
        let m = BASSovereigntyMetricsCompute.compute(BASSovereigntyCounts(
            unauthorizedCommits: 0, totalCommitAttempts: 100,
            sovereignSaves: 5, harmfulAttempts: 5,
            lineageDescendantsSevered: 7, lineageDescendantsExpected: 7,
            cleanRollbacks: 3, totalRollbacks: 3,
            oldSealLeaks: 0, oldSealAccessAttempts: 20,
            deletedResurfaced: 0, deletedTotal: 12))
        XCTAssertTrue(m.isClean)
        XCTAssertEqual(m.sovereignSaveRate, 1.0)
    }

    // Codable round-trip (host-persisted metric snapshot).
    func testRoundTrip() throws {
        let m = BASSovereigntyMetricsCompute.compute(BASSovereigntyCounts(
            unauthorizedCommits: 1, totalCommitAttempts: 3, deletedResurfaced: 1, deletedTotal: 2))
        let back = try JSONDecoder().decode(
            BASSovereigntyMetrics.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(back, m)
    }
}
