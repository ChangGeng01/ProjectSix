// MARK: - BASAuditObservationProjectionsKunlunAuditSchemas
//         BlockTests
// chapter 五百二十一 / M1461 — 7th typed input block tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsKunlunAuditSchemasBlockTests:
    XCTestCase
{

    func testEmptyBlockHasZeroPopulatedCount() {
        let block =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        XCTAssertEqual(block.populatedFieldCount, 0)
        XCTAssertFalse(
            block.hasFullAuditSchemaCoverage)
        XCTAssertTrue(
            block.hasNoAuditSchemaCoverage)
    }

    func testEmptyMatchesDefaultInit() {
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .empty,
            BASAuditObservationProjectionsKunlunAuditSchemasBlock())
    }

    func testAuditSchemaFieldCountPinnedToThree() {
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .auditSchemaFieldCount,
            3,
            "M424 Kunlun audit schema field count must" +
            " match BASAuditObservationProjections" +
            " corresponding field count")
    }

    func testEquatableValueEquality() {
        let b1 =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        let b2 =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        XCTAssertEqual(b1, b2)
    }

    func testHashableConformance() {
        let block =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        var set: Set<
            BASAuditObservationProjectionsKunlunAuditSchemasBlock>
            = []
        set.insert(block)
        set.insert(block)
        XCTAssertEqual(set.count, 1)
    }
}
