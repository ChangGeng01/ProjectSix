// MARK: - BASTypedObservabilitySinkCatalogueDoctrineTests
// chapter 五百四十 / M1538 — anti-drift PROOF tests for
//                            the unified typed catalogue
//                            doctrine of all 3
//                            observability sinks

import XCTest
@testable import BASRuntimeCore

final class BASTypedObservabilitySinkCatalogueDoctrineTests:
    XCTestCase
{

    // MARK: - Count invariants

    func testSinkCountIsThree() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .sinkCount,
            3,
            "3 typed observability sinks shipped to " +
            "date (chapters 536+537+539)")
    }

    func testEntriesArrayLengthMatchesSinkCount() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .entries.count,
            BASTypedObservabilitySinkCatalogueDoctrine
                .sinkCount)
    }

    func testSinkIDCaseCountIsThree() {
        XCTAssertEqual(
            BASTypedObservabilitySinkID
                .allCases.count,
            3)
    }

    // MARK: - Total path coverage

    func testTotalCoveredPathCountIsEight() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .totalCoveredPathCount,
            8,
            "2 + 4 + 2 = 8 silent-swallow paths covered")
    }

    func testExpectedTotalCoveredPathCountPinned() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .expectedTotalCoveredPathCount,
            8)
    }

    // MARK: - Consistency invariant

    func testCatalogueIsConsistentInvariantHolds() {
        XCTAssertTrue(
            BASTypedObservabilitySinkCatalogueDoctrine
                .catalogueIsConsistent,
            "catalogueIsConsistent must hold:" +
            " entries.count == sinkCount AND" +
            " totalCoveredPathCount == expectedTotal" +
            "CoveredPathCount")
    }

    // MARK: - M-number range

    func testFirstChapterMNumberIs1521() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .firstChapterMNumber,
            1521,
            "Arc opens at chapter 536 / M1521")
    }

    func testLastChapterMNumberIs1536() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .lastChapterMNumber,
            1536,
            "Arc closes at chapter 539 / M1536")
    }

    // MARK: - Per-sink lookups

    func testHostStorageInitialAtomAdmitEntry() {
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .hostStorageInitialAtomAdmit)!
        XCTAssertEqual(entry.typeName,
            "BASHostStorageInitialAtomAdmitFailureLog")
        XCTAssertEqual(entry.originChapter,
            "chapter 五百三十六")
        XCTAssertEqual(entry.mNumberFirst, 1521)
        XCTAssertEqual(entry.mNumberLast, 1524)
        XCTAssertEqual(entry.coveredPathCount, 2)
    }

    func testTurnRuntimeEngineObservationEntry() {
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .turnRuntimeEngineObservation)!
        XCTAssertEqual(entry.typeName,
            "BASTurnRuntimeEngineObservationFailureLog")
        XCTAssertEqual(entry.originChapter,
            "chapter 五百三十七")
        XCTAssertEqual(entry.mNumberFirst, 1525)
        XCTAssertEqual(entry.mNumberLast, 1528)
        XCTAssertEqual(entry.coveredPathCount, 4)
    }

    func testAuditEmissionEntry() {
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .auditEmission)!
        XCTAssertEqual(entry.typeName,
            "BASAuditEmissionFailureLog")
        XCTAssertEqual(entry.originChapter,
            "chapter 五百三十九")
        XCTAssertEqual(entry.mNumberFirst, 1533)
        XCTAssertEqual(entry.mNumberLast, 1536)
        XCTAssertEqual(entry.coveredPathCount, 2)
    }

    // MARK: - Chronological order

    func testEntriesAreInChronologicalMNumberOrder() {
        let entries =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entries
        for i in 1..<entries.count {
            XCTAssertGreaterThan(
                entries[i].mNumberFirst,
                entries[i - 1].mNumberLast,
                "Entries must be chronologically " +
                "ordered with non-overlapping M ranges")
        }
    }

    // MARK: - Codable round-trip

    func testEntryIsCodableRoundTrip() throws {
        let original =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entries[0]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTypedObservabilitySinkCatalogueEntry.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Unique sink IDs

    func testEntryIDsAreUnique() {
        let ids = BASTypedObservabilitySinkCatalogueDoctrine
            .entries.map { $0.id }
        XCTAssertEqual(
            Set(ids).count,
            ids.count,
            "All catalogue entries must have unique " +
            "sink IDs")
    }
}
