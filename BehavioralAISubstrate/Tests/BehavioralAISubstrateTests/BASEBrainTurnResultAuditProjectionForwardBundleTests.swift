// MARK: - BASEBrainTurnResultAuditProjectionForwardBundleTests
// chapter 五百二十六 / M1481 — 3rd cluster bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultAuditProjectionForwardBundleTests:
    XCTestCase
{

    func testEmptyBundleHasZeroPopulatedCount() {
        let bundle =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        XCTAssertEqual(bundle.populatedFieldCount, 0)
        XCTAssertFalse(bundle.hasFullForwardCoverage)
        XCTAssertTrue(bundle.hasNoForwardCoverage)
    }

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASEBrainTurnResultAuditProjectionForwardBundle
                .empty,
            BASEBrainTurnResultAuditProjectionForwardBundle())
    }

    func testForwardFieldCountPinnedToSeven() {
        XCTAssertEqual(
            BASEBrainTurnResultAuditProjectionForwardBundle
                .forwardFieldCount,
            7,
            "7 audit-projection-forwarded fields:" +
            " kunlunAxisAlignment + humanAnchorSignal" +
            " + abyssalPressure + unknownReserve +" +
            " kunlunHeavenGatePermit +" +
            " kunlunRiverOriginTrace +" +
            " yaochiSanctumEntry")
    }

    func testEquatableValueEquality() {
        let b1 =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        let b2 =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        XCTAssertEqual(b1, b2)
    }

    func testIsCold() {
        let none =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        XCTAssertTrue(none.hasNoForwardCoverage)
        XCTAssertFalse(none.hasFullForwardCoverage)
    }
}
