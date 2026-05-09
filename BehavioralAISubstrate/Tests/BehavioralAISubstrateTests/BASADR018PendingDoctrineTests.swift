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

    // MARK: - 3 items pending after M1071 ratification

    func testThreeItemsPendingAfterM1071Ratification() {
        // M1071 partial ratification:permitEscalationFold
        // shipped via BASPermitEscalationFoldExecutor
        // (chapter 四百二十五 / M1070)。 Other 3 still
        // pending。
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .parallelDispatchDriver),
            .pending)
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

    // MARK: - pendingItems() returns 3 after M1071

    func testPendingItemsReturnsThreeAfterM1071() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.pendingItems().count,
            3,
            "M1071 ratification:permitEscalationFold " +
            "shipped → 3 items pending")
        XCTAssertFalse(
            BASADR018PendingDoctrine.pendingItems()
                .contains(.permitEscalationFold))
    }

    // MARK: - hasPendingWork still true (3 of 4 remain)

    func testHasPendingWorkTrueAfterM1071() {
        XCTAssertTrue(
            BASADR018PendingDoctrine.hasPendingWork,
            "3 of 4 items still pending after M1071")
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
