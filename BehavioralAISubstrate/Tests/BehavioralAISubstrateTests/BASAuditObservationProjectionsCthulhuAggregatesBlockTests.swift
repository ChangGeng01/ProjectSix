// MARK: - BASAuditObservationProjectionsCthulhu
//         AggregatesBlockTests
// chapter 五百十七 / M1445 — 5th typed input block tests
//
// PROOF tests for the 7-L1-L7-Cthulhu-aggregate field
// block:
//   1. Empty block has zero populated count
//   2. .empty matches default init
//   3. populatedFieldCount counts up correctly
//   4. abyssalBranches non-empty counts toward populated
//   5. hasFullCthulhuCoverage threshold (== 7)
//   6. hasNoCthulhuCoverage threshold (== 0)
//   7. aggregateFieldCount pinned to 7 (anti-drift)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsCthulhuAggregatesBlockTests:
    XCTestCase
{

    // MARK: - 1) Empty block has zero populated count

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsCthulhuAggregatesBlock()
        XCTAssertEqual(block.populatedFieldCount, 0)
        XCTAssertFalse(block.hasFullCthulhuCoverage)
        XCTAssertTrue(block.hasNoCthulhuCoverage)
    }

    // MARK: - 2) .empty matches default init

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .empty,
            BASAuditObservationProjectionsCthulhuAggregatesBlock())
    }

    // MARK: - 3) populatedFieldCount counts correctly

    func testPopulatedFieldCountCountsUp() {
        let some = BASAuditObservationProjectionsCthulhuAggregatesBlock(
            abyssalBranches: [
                BASAbyssalBranch(
                    branchID: "b-1",
                    sourceCandidateRef: "c-a",
                    triggerReasons: ["unknown-load>0.8"],
                    unknownLoad: 0.9,
                    manipulationLoad: 0.1,
                    ontologyDistortion: 0.2,
                    protectivePathRefs: ["alt-1"],
                    requiredClosureConditions:
                        ["sovereign-review-passed"]),
            ])
        XCTAssertEqual(some.populatedFieldCount, 1)
    }

    // MARK: - 4) abyssalBranches non-empty counts

    func testAbyssalBranchesNonEmptyCountsAsPopulated() {
        let empty =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                abyssalBranches: [])
        XCTAssertEqual(empty.populatedFieldCount, 0)
        // Non-empty array contributes
        let withBranch =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                abyssalBranches: [
                    BASAbyssalBranch(
                        branchID: "b",
                        sourceCandidateRef: "c",
                        triggerReasons: ["r"],
                        unknownLoad: 0.5,
                        manipulationLoad: 0.1,
                        ontologyDistortion: 0.2,
                        protectivePathRefs: [],
                        requiredClosureConditions: []),
                ])
        XCTAssertEqual(
            withBranch.populatedFieldCount, 1)
    }

    // MARK: - 5) hasFullCthulhuCoverage threshold

    func testHasFullCthulhuCoverageRequiresAllSeven() {
        let one =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                abyssalBranches: [
                    BASAbyssalBranch(
                        branchID: "b",
                        sourceCandidateRef: "c",
                        triggerReasons: ["r"],
                        unknownLoad: 0.5,
                        manipulationLoad: 0.1,
                        ontologyDistortion: 0.2,
                        protectivePathRefs: [],
                        requiredClosureConditions: []),
                ])
        XCTAssertFalse(one.hasFullCthulhuCoverage)
    }

    // MARK: - 6) hasNoCthulhuCoverage threshold

    func testHasNoCthulhuCoverageThreshold() {
        let none =
            BASAuditObservationProjectionsCthulhuAggregatesBlock()
        XCTAssertTrue(none.hasNoCthulhuCoverage)
    }

    // MARK: - 7) aggregateFieldCount pinned to 7

    /// Anti-drift PROOF。 If a future chapter adds an
    /// 8th L1-L7 aggregate field,this constant moves
    /// AND the block gains a matching field,or audit
    /// emission silently loses coverage。
    func testAggregateFieldCountPinnedToSeven() {
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .aggregateFieldCount,
            7,
            "L1-L7 Cthulhu aggregate field count must" +
            " match BASAuditObservationProjections" +
            " corresponding field count")
    }
}
