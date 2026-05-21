// MARK: - BASChapter527ParallelRunReconciliationDoctrineTests
// chapter 五百二十七 / M1487 — milestone tests

import XCTest
@testable import BASRuntimeCore

final class BASChapter527ParallelRunReconciliationDoctrineTests:
    XCTestCase
{

    func testShipRecordPins() {
        let r = BASChapter527ParallelRunReconciliationDoctrine
            .chapter527ShipRecord
        XCTAssertEqual(
            r.driftChapterTag, "chapter 五百二十六")
        XCTAssertEqual(
            r.reconciliationStartMNumber, 1485)
        XCTAssertEqual(
            r.reconciliationEndMNumber, 1488)
        XCTAssertEqual(r.bundleCountUnified, 4)
        XCTAssertEqual(r.totalFieldCount, 30)
        XCTAssertTrue(
            r.postReconciliationFullSuitePasses)
    }

    func testValidatedMitigationsHasFiveStrategies() {
        let r = BASChapter527ParallelRunReconciliationDoctrine
            .chapter527ShipRecord
        XCTAssertEqual(
            r.validatedMitigations.count, 5)
    }

    func testCodableRoundTrip() throws {
        let original =
            BASChapter527ParallelRunReconciliationDoctrine
                .chapter527ShipRecord
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASChapter527ParallelRunReconciliationDoctrine
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
