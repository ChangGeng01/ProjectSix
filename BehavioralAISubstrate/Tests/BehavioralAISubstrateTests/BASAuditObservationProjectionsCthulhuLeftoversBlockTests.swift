// MARK: - BASAuditObservationProjectionsCthulhuLeftovers
//         BlockTests
// chapter 五百二十二 / M1465 — 8th typed input block tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsCthulhuLeftoversBlockTests:
    XCTestCase
{

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsCthulhuLeftoversBlock()
        XCTAssertEqual(block.populatedFieldCount, 0)
        XCTAssertFalse(block.hasFullLeftoverCoverage)
        XCTAssertTrue(block.hasNoLeftoverCoverage)
    }

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .empty,
            BASAuditObservationProjectionsCthulhuLeftoversBlock())
    }

    func testReasonCodesNonEmptyCountsAsPopulated() {
        let withCodes =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes:
                    ["code-1"],
                cthulhuPermitEscalationReasonCodes:
                    ["code-2"])
        XCTAssertEqual(
            withCodes.populatedFieldCount, 2)
    }

    func testHasFullLeftoverCoverageRequiresAllSix() {
        let some =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes:
                    ["a"])
        XCTAssertFalse(
            some.hasFullLeftoverCoverage)
    }

    func testLeftoverFieldCountPinnedToSix() {
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .leftoverFieldCount,
            6,
            "Cthulhu leftover field count must match" +
            " BASAuditObservationProjections" +
            " corresponding field count")
    }

    func testEquatableValueEquality() {
        let b1 =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes:
                    ["a"])
        let b2 =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes:
                    ["a"])
        XCTAssertEqual(b1, b2)
        let b3 =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes:
                    ["b"])
        XCTAssertNotEqual(b1, b3)
    }
}
