// MARK: - BASADR018PendingDoctrineTests — chapter 四百二十一 / M1056

import XCTest
@testable import BASRuntimeCore

final class BASADR018PendingDoctrineTests: XCTestCase {

    // MARK: - 4 cases present

    func testFourPendingItemCases() {
        XCTAssertEqual(
            BASADR018PendingItem.allCases.count, 4)
    }

    func testRawValuesPinned() {
        let raws = BASADR018PendingItem.allCases
            .map { $0.rawValue }
        XCTAssertEqual(
            Set(raws),
            Set([
                "parallel-dispatch-driver",
                "stress-sweep-harness",
                "permit-escalation-fold",
                "native-stage-rewrites"
            ]))
    }

    // MARK: - ADR identifier pinned

    func testADRIdentifierPinned() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.adrIdentifier,
            "ADR-018-pending")
        XCTAssertEqual(
            BASADR018PendingDoctrine.adrIdentifier,
            BASPhase2EntropyClosureDoctrine
                .productionRoadmapADR,
            "must match Phase 2 close-out reference")
    }

    // MARK: - All 4 items are pending today

    func testAllFourItemsArePendingToday() {
        for item in BASADR018PendingItem.allCases {
            XCTAssertEqual(
                BASADR018PendingDoctrine.status(of: item),
                .pending,
                "\(item.rawValue) must be .pending until " +
                "ADR-018 ratification ships it")
        }
    }

    // MARK: - pendingItems() returns all 4

    func testPendingItemsReturnsAllFour() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.pendingItems().count,
            4)
    }

    // MARK: - hasPendingWork true

    func testHasPendingWorkTrueToday() {
        XCTAssertTrue(
            BASADR018PendingDoctrine.hasPendingWork)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesItems() throws {
        for item in BASADR018PendingItem.allCases {
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(
                BASADR018PendingItem.self, from: data)
            XCTAssertEqual(decoded, item)
        }
    }

    // MARK: - Status equality semantics

    func testPendingStatusEquality() {
        let a = BASADR018PendingItemStatus.pending
        let b = BASADR018PendingItemStatus.pending
        XCTAssertEqual(a, b)
    }

    func testShippedStatusEqualityRequiresMatchingFields() {
        let a = BASADR018PendingItemStatus.shipped(
            mNumber: 2000, chapterTag: "chapter 四百三十")
        let b = BASADR018PendingItemStatus.shipped(
            mNumber: 2000, chapterTag: "chapter 四百三十")
        XCTAssertEqual(a, b)
        let c = BASADR018PendingItemStatus.shipped(
            mNumber: 2001, chapterTag: "chapter 四百三十")
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Determinism

    func testStatusIsDeterministic() {
        for item in BASADR018PendingItem.allCases {
            XCTAssertEqual(
                BASADR018PendingDoctrine.status(of: item),
                BASADR018PendingDoctrine.status(of: item))
        }
    }
}
