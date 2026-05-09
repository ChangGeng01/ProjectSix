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

    // MARK: - ADR-018 pending

    func testADR018Pending() {
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .adr018ProductionPending),
            .pending)
    }

    // MARK: - shippedPhases / pendingPhases

    func testShippedPhasesIsTwo() {
        XCTAssertEqual(
            BASRoadmapDoctrine.shippedPhases().count, 2)
        XCTAssertTrue(
            BASRoadmapDoctrine.shippedPhases()
                .contains(.phase1MemoryEventSourcing))
        XCTAssertTrue(
            BASRoadmapDoctrine.shippedPhases()
                .contains(.phase2RuntimeRewrite))
    }

    func testPendingPhasesIsOneADR018() {
        XCTAssertEqual(
            BASRoadmapDoctrine.pendingPhases(),
            [.adr018ProductionPending])
    }

    // MARK: - Overall progress

    func testOverallProgressIs66Percent() {
        XCTAssertEqual(
            BASRoadmapDoctrine.overallProgressPercent, 66,
            "2 of 3 phases shipped → 66%")
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
        // Phase 2 doctrine has 19 chapters shipped — the
        // roadmap reflects that as .shipped status
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .phase2RuntimeRewrite),
            .shipped)
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count, 19)
    }

    func testRoadmapADR018PendingMatchesADR018Doctrine() {
        // ADR-018 doctrine has 4 pending items — roadmap
        // reflects this as overall .pending phase
        XCTAssertTrue(
            BASADR018PendingDoctrine.hasPendingWork)
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .adr018ProductionPending),
            .pending)
    }
}
