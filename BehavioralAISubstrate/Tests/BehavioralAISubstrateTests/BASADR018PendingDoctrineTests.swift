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

    // MARK: - 2 items pending after M1073 ratification

    func testTwoItemsPendingAfterM1073Ratification() {
        // M1071:permitEscalationFold shipped (M1070)。
        // M1073:parallelDispatchDriver shipped (M1072)。
        // Other 2 still pending。
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .stressSweepHarness),
            .pending)
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .nativeStageRewrites),
            .pending)
    }

    // MARK: - permitEscalationFold shipped at M1070

    func testPermitEscalationFoldShippedAtM1070() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .permitEscalationFold),
            .shipped(
                mNumber: 1070,
                chapterTag: "chapter 四百二十五"))
    }

    // MARK: - parallelDispatchDriver shipped at M1072

    func testParallelDispatchDriverShippedAtM1072() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .parallelDispatchDriver),
            .shipped(
                mNumber: 1072,
                chapterTag: "chapter 四百二十五"))
    }

    // MARK: - pendingItems() returns 2 after M1073

    func testPendingItemsReturnsTwoAfterM1073() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.pendingItems().count,
            2,
            "M1073 ratification:permitEscalationFold + " +
            "parallelDispatchDriver shipped → 2 items pending")
        XCTAssertFalse(
            BASADR018PendingDoctrine.pendingItems()
                .contains(.permitEscalationFold))
        XCTAssertFalse(
            BASADR018PendingDoctrine.pendingItems()
                .contains(.parallelDispatchDriver))
    }

    // MARK: - hasPendingWork still true (2 of 4 remain)

    func testHasPendingWorkTrueAfterM1073() {
        XCTAssertTrue(
            BASADR018PendingDoctrine.hasPendingWork,
            "2 of 4 items still pending after M1073")
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
