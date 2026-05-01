import XCTest
@testable import QinaoLoopSeats
@testable import QinaoLoop
import QinaoSeats

/// M292.7 — minimal runtime wire integration tests: council fires
/// after a turn submission and produces a meaningful merged view.
///
/// Doctrine pinned:
/// - High-pressure v2 第四节 candidate → council `consensusUrgency`
///   ≥ 0.4 (the council is genuinely worried)
/// - High-pressure → loudest seat is one of {risk, surface,
///   sovereignSentinel, critic} (any of the protective seats)
/// - Low-pressure candidate → consensus < 0.4 (council quiet)
/// - All 6 default seats contribute (no failures on a healthy
///   submission)
final class QinaoLoopSeatsRuntimeTests: XCTestCase {

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

    // MARK: - High-pressure council fires

    func test_highPressure_councilSpeaksLoudly() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "weave-001",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
                makeInput(
                    "alt-cool-off",
                    manipulationRisk: 0.2,
                    confidence: 0.8,
                    reversibility: 0.7),
            ])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let merged = await runCouncilTurn(
            loop: loop,
            registry: registry,
            sessionID: "weave-001")

        XCTAssertEqual(merged.board.verdicts.count, 6)
        XCTAssertTrue(merged.board.isFullyAttended)
        // Council consensus must register concern.
        XCTAssertGreaterThanOrEqual(
            merged.consensusUrgency, 0.4,
            "high-pressure scenario must not pass quietly")
        // Loudest seat should be one of the protective seats.
        let protectiveSeats: Set<QinaoSeat> = [
            .critic, .risk, .surface, .sovereignSentinel,
        ]
        let loudest = merged.loudestSeat
        XCTAssertNotNil(loudest)
        XCTAssertTrue(
            protectiveSeats.contains(loudest!),
            "loudest seat \(loudest!) must be protective")
    }

    // MARK: - Low-pressure council quiet

    func test_lowPressure_councilQuiet() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "calm-001",
            candidates: [
                makeInput(
                    "easy-affirm",
                    manipulationRisk: 0.05,
                    confidence: 0.95,
                    reversibility: 0.9),
            ])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let merged = await runCouncilTurn(
            loop: loop,
            registry: registry,
            sessionID: "calm-001")

        XCTAssertEqual(merged.board.verdicts.count, 6)
        XCTAssertTrue(merged.board.isFullyAttended)
        XCTAssertLessThan(
            merged.consensusUrgency, 0.4,
            "low-pressure scenario must not panic the council")
    }

    // MARK: - Unknown session: failures isolated

    func test_unknownSession_allSeatsFail() async {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let merged = await runCouncilTurn(
            loop: loop,
            registry: registry,
            sessionID: "never-submitted")
        XCTAssertEqual(merged.board.verdicts.count, 0)
        XCTAssertEqual(merged.board.failures.count, 6)
        // Every default seat should fail on a missing session.
        XCTAssertFalse(merged.board.isFullyAttended)
    }

    // MARK: - M292.8 — submitAndRunCouncil

    func test_submitAndRunCouncil_combinesSubmitWithDispatch()
        async throws
    {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let merged = try await loop.submitAndRunCouncil(
            sessionID: "auto-1",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
            ],
            registry: registry)
        XCTAssertEqual(merged.board.verdicts.count, 6)
        XCTAssertTrue(merged.board.isFullyAttended)
        XCTAssertGreaterThanOrEqual(
            merged.consensusUrgency, 0.4)
    }

    func test_submitAndRunCouncil_propagatesSubmitErrors()
        async
    {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        do {
            _ = try await loop.submitAndRunCouncil(
                sessionID: "auto-2",
                candidates: [], // empty triggers validation throw
                registry: registry)
            XCTFail("expected throw on empty candidates")
        } catch {
            // OK — submit's empty-batch validation fired.
        }
    }

    // MARK: - M292.9 — QinaoCouncilSession

    func test_councilSession_submitAndDispatch() async throws {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let session = QinaoCouncilSession(
            loop: loop,
            sessionID: "session-1",
            registry: registry)
        let merged = try await session.submit([
            makeInput(
                "ultimatum",
                manipulationRisk: 0.85,
                boundaryConflict: 0.6,
                emotionalBias: 0.85,
                reversibility: 0.15),
        ])
        XCTAssertEqual(merged.board.verdicts.count, 6)
        XCTAssertGreaterThanOrEqual(
            merged.consensusUrgency, 0.4)
    }

    func test_councilSession_dispatchOnExistingSession()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "preset",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.7,
                    boundaryConflict: 0.5,
                    emotionalBias: 0.6,
                    reversibility: 0.3),
            ])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let session = QinaoCouncilSession(
            loop: loop,
            sessionID: "preset",
            registry: registry)
        let merged = await session.dispatch()
        XCTAssertEqual(merged.board.verdicts.count, 6)
        XCTAssertTrue(merged.board.isFullyAttended)
    }

    func test_councilSession_dispatchOnUnknownSession_failures()
        async
    {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let session = QinaoCouncilSession(
            loop: loop,
            sessionID: "missing",
            registry: registry)
        let merged = await session.dispatch()
        XCTAssertEqual(merged.board.failures.count, 6)
        XCTAssertFalse(merged.board.isFullyAttended)
    }
}
