// MARK: - BASAuditObservationProjectionsClosureBlockTests
// chapter 五百十八 / M1449 — 6th typed input block tests
//
// PROOF tests for the 7-closure-field block:
//   1. Empty block has zero populated count
//   2. .empty matches default init
//   3. populatedFieldCount counts correctly
//   4. escalationSuppressionCodes non-empty counts
//   5. hasFullClosureCoverage threshold (== 7)
//   6. hasNoClosureCoverage threshold (== 0)
//   7. closureFieldCount pinned to 7 (anti-drift)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsClosureBlockTests:
    XCTestCase
{

    // MARK: - 1) Empty block has zero populated count

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsClosureBlock()
        XCTAssertEqual(block.populatedFieldCount, 0)
        XCTAssertFalse(block.hasFullClosureCoverage)
        XCTAssertTrue(block.hasNoClosureCoverage)
    }

    // MARK: - 2) .empty matches default init

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASAuditObservationProjectionsClosureBlock
                .empty,
            BASAuditObservationProjectionsClosureBlock())
    }

    // MARK: - 3) populatedFieldCount counts correctly

    func testPopulatedFieldCountCounts() {
        let oneArray = BASAuditObservationProjectionsClosureBlock(
            escalationSuppressionCodes: ["esc-1"])
        XCTAssertEqual(oneArray.populatedFieldCount, 1)
    }

    // MARK: - 4) escalationSuppressionCodes non-empty counts

    func testSuppressionCodesNonEmptyCountsAsPopulated() {
        let empty = BASAuditObservationProjectionsClosureBlock(
            escalationSuppressionCodes: [])
        XCTAssertEqual(empty.populatedFieldCount, 0)
        let withCodes = BASAuditObservationProjectionsClosureBlock(
            escalationSuppressionCodes: ["a", "b"])
        XCTAssertEqual(withCodes.populatedFieldCount, 1)
    }

    // MARK: - 5) hasFullClosureCoverage threshold

    func testHasFullClosureCoverageRequiresAllSeven() {
        let some = BASAuditObservationProjectionsClosureBlock(
            escalationSuppressionCodes: ["esc-1"])
        XCTAssertFalse(some.hasFullClosureCoverage)
    }

    // MARK: - 6) hasNoClosureCoverage threshold

    func testHasNoClosureCoverageThreshold() {
        let none = BASAuditObservationProjectionsClosureBlock()
        XCTAssertTrue(none.hasNoClosureCoverage)
        let withCodes = BASAuditObservationProjectionsClosureBlock(
            escalationSuppressionCodes: ["esc-1"])
        XCTAssertFalse(withCodes.hasNoClosureCoverage)
    }

    // MARK: - 7) closureFieldCount pinned to 7

    /// Anti-drift PROOF。
    func testClosureFieldCountPinnedToSeven() {
        XCTAssertEqual(
            BASAuditObservationProjectionsClosureBlock
                .closureFieldCount,
            7,
            "Closure field count must match" +
            " BASAuditObservationProjections" +
            " closure-source field count")
    }
}
