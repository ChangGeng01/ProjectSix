import XCTest
@testable import QinaoLoopSeats
@testable import QinaoLoop
import QinaoSeats

/// M292.6d — adapter reader contract tests.
///
/// Doctrine pinned:
/// - Memory adapter synthesizes pressure from harmony-voice
/// - HostAlignment adapter synthesizes from guardian-voice +
///   boundary-conflict reason code
/// - EvolutionShadow adapter honestly returns zero readout
///   (no public API exposes ticket lifecycle)
/// - Adapters compose with M292.6c loop-bound seats
/// - `adapterBoundSeats(loop:)` registers all 3
final class QinaoLoopReaderAdaptersTests: XCTestCase {

    private func makeInput(
        _ id: String,
        manipulationRisk: Double = 0,
        boundaryConflict: Double = 0,
        emotionalBias: Double = 0,
        evidenceGap: Double = 0,
        confidence: Double = 0.5,
        reversibility: Double = 0.5
    ) -> QinaoLoop.CandidateInput {
        QinaoLoop.CandidateInput(
            candidateID: id,
            title: "title-\(id)",
            actionSummary: "summary-\(id)",
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: reversibility,
            confidence: confidence,
            evidenceGap: evidenceGap,
            manipulationRisk: manipulationRisk,
            emotionalBias: emotionalBias,
            boundaryConflict: boundaryConflict,
            worldPriorClaim: nil)
    }

    // MARK: - Memory adapter

    func test_memoryAdapter_lowPressureReadout() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1", confidence: 0.95)])
        let reader = QinaoLoopMemoryAdapterReader(loop: loop)
        let r = try await reader.readMemoryState(
            sessionID: "s1")
        XCTAssertLessThan(r.memoryPressure, 0.5)
        XCTAssertFalse(r.continuityAtRisk)
    }

    func test_memoryAdapter_highRegretFlagsContinuityRisk()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    emotionalBias: 0.95,
                    reversibility: 0.05),
            ])
        let reader = QinaoLoopMemoryAdapterReader(loop: loop)
        let r = try await reader.readMemoryState(
            sessionID: "s1")
        // High emotion + low reversibility → harmony concern
        // ≥ 0.7 → continuity at risk.
        XCTAssertGreaterThanOrEqual(r.memoryPressure, 0.7)
        XCTAssertTrue(r.continuityAtRisk)
    }

    // MARK: - HostAlignment adapter

    func test_hostAlignmentAdapter_lowAlignmentReadout()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1")])
        let reader =
            QinaoLoopHostAlignmentAdapterReader(loop: loop)
        let r = try await reader.readHostAlignmentState(
            sessionID: "s1")
        XCTAssertEqual(r.boundaryViolationCount, 0)
        XCTAssertEqual(
            r.valueAxisConflict, 0, accuracy: 1e-6)
        XCTAssertFalse(r.consentScopeBreach)
    }

    func test_hostAlignmentAdapter_boundaryConflictCounted()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.6,
                    boundaryConflict: 0.7),
            ])
        let reader =
            QinaoLoopHostAlignmentAdapterReader(loop: loop)
        let r = try await reader.readHostAlignmentState(
            sessionID: "s1")
        // boundary-conflict reason code fires when boundaryConflict > 0.5
        XCTAssertEqual(r.boundaryViolationCount, 1)
        XCTAssertGreaterThan(r.valueAxisConflict, 0)
    }

    // MARK: - EvolutionShadow adapter

    func test_evolutionShadowAdapter_alwaysZero() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1")])
        let reader =
            QinaoLoopEvolutionShadowAdapterReader(loop: loop)
        let r = try await reader.readEvolutionShadowState(
            sessionID: "s1")
        // Doctrine: honest zero, no fake signal.
        XCTAssertEqual(r.pendingTicketCount, 0)
        XCTAssertEqual(r.recentRejectionRate, 0)
        XCTAssertEqual(r.shadowTrialFailureRate, 0)
    }

    // MARK: - Composition with loop-bound seats

    func test_loopBoundSeatsWithAdapters_composeViaRegistry()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.6,
                    boundaryConflict: 0.5,
                    emotionalBias: 0.5,
                    reversibility: 0.3),
            ])
        let registry = await QinaoSeatRegistry
            .adapterBoundSeats(loop: loop)
        let registered = await registry.registeredSeats()
        XCTAssertEqual(
            registered,
            [.evolutionShadow, .hostAlignment, .memory])
        let board = await registry.dispatch(
            snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 3)
        XCTAssertTrue(board.isFullyAttended)
    }

    // MARK: - Combined with standard 6 seats = full 9-seat council

    func test_combineStandardWithAdapter_yieldsFullNineSeats()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1")])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        // Add the 3 adapter-bound to fill the council.
        await registry.register(
            QinaoMemoryLoopBoundSeat(
                reader: QinaoLoopMemoryAdapterReader(
                    loop: loop)))
        await registry.register(
            QinaoHostAlignmentLoopBoundSeat(
                reader:
                    QinaoLoopHostAlignmentAdapterReader(
                        loop: loop)))
        await registry.register(
            QinaoEvolutionShadowLoopBoundSeat(
                reader:
                    QinaoLoopEvolutionShadowAdapterReader(
                        loop: loop)))
        let registered = await registry.registeredSeats()
        XCTAssertEqual(registered.count, 9)
        XCTAssertEqual(
            Set(registered),
            Set(QinaoSeat.allCases),
            "all 9 seats should be registered")
        let board = await registry.dispatch(
            snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 9)
    }
}
