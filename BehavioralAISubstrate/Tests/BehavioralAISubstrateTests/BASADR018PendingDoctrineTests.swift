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

    // MARK: - ALL 4 items shipped after M1076 full ratification

    func testAllFourItemsShippedAfterM1076Ratification() {
        for item in BASADR018PendingItem.allCases {
            switch BASADR018PendingDoctrine.status(of: item) {
            case .shipped:
                continue
            case .pending:
                XCTFail(
                    "\(item.rawValue) must be .shipped " +
                    "after M1076 full ratification")
            }
        }
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

    // MARK: - stressSweepHarness shipped at M1074

    func testStressSweepHarnessShippedAtM1074() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .stressSweepHarness),
            .shipped(
                mNumber: 1074,
                chapterTag: "chapter 四百二十六"))
    }

    // MARK: - nativeStageRewrites shipped at M1075

    func testNativeStageRewritesShippedAtM1075() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.status(
                of: .nativeStageRewrites),
            .shipped(
                mNumber: 1075,
                chapterTag: "chapter 四百二十六"))
    }

    // MARK: - pendingItems() returns empty after M1076

    func testPendingItemsReturnsEmptyAfterM1076() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.pendingItems().count,
            0,
            "M1076 FULL ratification:all 4 items shipped" +
            " → 0 items pending")
    }

    // MARK: - hasPendingWork now false

    func testHasPendingWorkFalseAfterM1076() {
        XCTAssertFalse(
            BASADR018PendingDoctrine.hasPendingWork,
            "ALL 4 ADR-018 items shipped after M1076")
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
