// MARK: - BASRoadmapDoctrineTests — chapter 四百二十三 / M1062

import XCTest
@testable import BASRuntimeCore

final class BASRoadmapDoctrineTests: XCTestCase {

    // MARK: - 3 phase cases

    func testThreeRoadmapPhases() {
        XCTAssertEqual(
            BASRoadmapPhase.allCases.count, 3)
    }

    func testRawValuesPinned() {
        let raws = BASRoadmapPhase.allCases
            .map { $0.rawValue }
        XCTAssertEqual(
            Set(raws),
            Set([
                "phase-1-memory-event-sourcing",
                "phase-2-runtime-rewrite",
                "adr-018-production-pending"
            ]))
    }

    // MARK: - Roadmap tag pinned

    func testRoadmapTagPinned() {
        XCTAssertEqual(
            BASRoadmapDoctrine.roadmapTag,
            "next-next-gen-architecture-sweep")
    }

    // MARK: - Phase 1 shipped

    func testPhase1Shipped() {
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .phase1MemoryEventSourcing),
            .shipped)
    }

    // MARK: - Phase 2 shipped

    func testPhase2Shipped() {
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .phase2RuntimeRewrite),
            .shipped)
    }

    // MARK: - ADR-018 shipped after M1076 full ratification

    func testADR018ShippedAfterM1076() {
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .adr018ProductionPending),
            .shipped,
            "M1076 full ratification flips ADR-018 phase " +
            "from .pending to .shipped")
    }

    // MARK: - shippedPhases / pendingPhases

    func testAllThreePhasesShippedAfterM1076() {
        XCTAssertEqual(
            BASRoadmapDoctrine.shippedPhases().count, 3,
            "M1076 ratification:all 3 phases shipped")
        XCTAssertTrue(
            BASRoadmapDoctrine.shippedPhases()
                .contains(.phase1MemoryEventSourcing))
        XCTAssertTrue(
            BASRoadmapDoctrine.shippedPhases()
                .contains(.phase2RuntimeRewrite))
        XCTAssertTrue(
            BASRoadmapDoctrine.shippedPhases()
                .contains(.adr018ProductionPending))
    }

    func testPendingPhasesIsEmptyAfterM1076() {
        XCTAssertTrue(
            BASRoadmapDoctrine.pendingPhases().isEmpty,
            "M1076 full ratification:all 3 phases shipped")
    }

    // MARK: - Overall progress

    func testOverallProgressIs100Percent() {
        XCTAssertEqual(
            BASRoadmapDoctrine.overallProgressPercent, 100,
            "M1076 ratification:3 of 3 phases shipped → 100%")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesPhases() throws {
        for phase in BASRoadmapPhase.allCases {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(
                BASRoadmapPhase.self, from: data)
            XCTAssertEqual(decoded, phase)
        }
    }

    // MARK: - Status equality semantics

    func testPartiallyShippedStatusEquality() {
        let a = BASRoadmapPhaseStatus
            .partiallyShipped(percent: 50)
        let b = BASRoadmapPhaseStatus
            .partiallyShipped(percent: 50)
        let c = BASRoadmapPhaseStatus
            .partiallyShipped(percent: 75)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Cross-check against existing Phase 2 doctrine

    func testRoadmapPhase2ShippedMatchesPhase2DoctrineCount() {
        // Phase 2 doctrine has 23+ chapters shipped — the
        // roadmap reflects that as .shipped status。
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .phase2RuntimeRewrite),
            .shipped)
        XCTAssertGreaterThanOrEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count, 23,
            "Phase 2 includes at least 23 chapters " +
            "post-M1066+M1069+M1073 self-extensions")
    }

    func testRoadmapADR018ShippedMatchesADR018Doctrine() {
        // M1076 full ratification:0 pending items,phase
        // is .shipped。
        XCTAssertFalse(
            BASADR018PendingDoctrine.hasPendingWork,
            "M1076:no pending work")
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .adr018ProductionPending),
            .shipped,
            "Roadmap reflects ADR-018 fully shipped")
    }
}
