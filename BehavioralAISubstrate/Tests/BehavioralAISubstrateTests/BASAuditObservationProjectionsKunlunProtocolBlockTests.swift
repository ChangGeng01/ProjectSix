// MARK: - BASAuditObservationProjectionsKunlunProtocolBlock
//         Tests
// chapter 五百十六 / M1441 — 4th typed input block tests
//
// PROOF tests for the 9-Kunlun-protocol-field block:
//   1. Empty block has zero populated count
//   2. .empty matches default init
//   3. populatedFieldCount counts up correctly
//   4. hasFullProtocolCoverage threshold (== 9)
//   5. hasNoProtocolCoverage threshold (== 0)
//   6. protocolFieldCount pinned to 9 (anti-drift)
//   7. Equatable conformance value equality

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsKunlunProtocolBlockTests:
    XCTestCase
{

    // MARK: - 1) Empty block has zero populated count

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsKunlunProtocolBlock()
        XCTAssertEqual(block.populatedFieldCount, 0)
        XCTAssertFalse(block.hasFullProtocolCoverage)
        XCTAssertTrue(block.hasNoProtocolCoverage)
    }

    // MARK: - 2) .empty matches default init

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .empty,
            BASAuditObservationProjectionsKunlunProtocolBlock())
    }

    // MARK: - 3) populatedFieldCount counts correctly

    func testPopulatedFieldCountCounts() {
        let one =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                yaochiSanctumClass: .boundary)
        XCTAssertEqual(one.populatedFieldCount, 1)
        let two =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                yaochiSanctumClass: .boundary,
                tianmenGateClass: .public)
        XCTAssertEqual(two.populatedFieldCount, 2)
        let three =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                jadeCanonObjectClass: .actionPermit,
                yaochiSanctumClass: .boundary,
                tianmenGateClass: .public)
        XCTAssertEqual(three.populatedFieldCount, 3)
    }

    // MARK: - 4) hasFullProtocolCoverage threshold

    func testHasFullProtocolCoverageRequiresAllNine() {
        // 2-of-9 must NOT be considered full
        let two =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                yaochiSanctumClass: .boundary,
                tianmenGateClass: .public)
        XCTAssertFalse(two.hasFullProtocolCoverage)
    }

    // MARK: - 5) hasNoProtocolCoverage threshold

    func testHasNoProtocolCoverageThreshold() {
        let none =
            BASAuditObservationProjectionsKunlunProtocolBlock()
        XCTAssertTrue(none.hasNoProtocolCoverage)
        let one =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                yaochiSanctumClass: .boundary)
        XCTAssertFalse(one.hasNoProtocolCoverage)
    }

    // MARK: - 6) protocolFieldCount pinned to 9

    /// Anti-drift PROOF: this constant pins the surface
    /// size。 If a future chapter adds a 10th protocol
    /// field,this constant moves AND the block gains a
    /// matching field,or audit emission silently loses
    /// coverage。
    func testProtocolFieldCountPinnedToNine() {
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .protocolFieldCount,
            9,
            "Kunlun protocol field count must match" +
            " BASAuditObservationProjections" +
            " Kunlun-protocol-source field count")
    }

    // MARK: - 7) Equatable value equality

    func testEquatableValueEquality() {
        let b1 =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                jadeCanonObjectClass: .actionPermit,
                yaochiSanctumClass: .boundary)
        let b2 =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                jadeCanonObjectClass: .actionPermit,
                yaochiSanctumClass: .boundary)
        XCTAssertEqual(b1, b2)
        let b3 =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                jadeCanonObjectClass: .actionPermit)
        XCTAssertNotEqual(b1, b3)
    }
}
