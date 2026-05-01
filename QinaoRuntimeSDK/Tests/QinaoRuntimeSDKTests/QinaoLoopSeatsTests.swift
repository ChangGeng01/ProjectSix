import XCTest
@testable import QinaoLoopSeats
@testable import QinaoLoop
import QinaoSeats

/// M292.3 — default seat implementation contract tests.
///
/// Doctrine pinned by these tests:
/// - Empty session → urgency 0 + a "no-..." reason code (silence
///   is informative, not a throw)
/// - Scout reads top-of-frontier critique strength
/// - Critic mirrors `vetoExplain` (no veto → urgency 0)
/// - Risk reports max guardian concern across candidates
/// - All three default seats compose with the M292.2 dispatch
///   pipeline (registry → SeatBoard)
final class QinaoLoopSeatsTests: XCTestCase {

    // MARK: - Helpers

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

    // MARK: - Scout default

    func test_scout_emptyFrontier_throwsNoCandidatesYet() async throws
    {
        let loop = QinaoLoop()
        let scout = QinaoScoutDefaultSeat(loop: loop)
        do {
            _ = try await scout.contribute(
                snapshotID: "never-submitted")
            XCTFail("expected sessionUnknown")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "never-submitted")
        }
    }

    func test_scout_singleCandidateFrontier_reportsCritiqueStrength()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.6,
                    boundaryConflict: 0.5)
            ])
        let scout = QinaoScoutDefaultSeat(loop: loop)
        let v = try await scout.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .scout)
        XCTAssertGreaterThan(v.urgency, 0)
        XCTAssertTrue(v.note.contains("c1"))
    }

    func test_scout_multiCandidate_includesMultiCandidateCode()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput("c1", manipulationRisk: 0.7),
                makeInput("c2", manipulationRisk: 0.4),
            ])
        let scout = QinaoScoutDefaultSeat(loop: loop)
        let v = try await scout.contribute(snapshotID: "s1")
        XCTAssertTrue(v.reasonCodes.contains("multi-candidate"))
    }

    // MARK: - Critic default

    func test_critic_noVeto_returnsZeroUrgencyWithNoVetoCode()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                // All concerns low → no voice ≥ 0.7 → no veto.
                makeInput(
                    "c1",
                    manipulationRisk: 0.1,
                    confidence: 0.9)
            ])
        let critic = QinaoCriticDefaultSeat(loop: loop)
        let v = try await critic.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .critic)
        XCTAssertEqual(v.urgency, 0, accuracy: 1e-9)
        XCTAssertTrue(v.reasonCodes.contains("no-veto"))
    }

    func test_critic_highPressure_reportsVetoUrgency() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
                makeInput("safer", confidence: 0.9),
            ])
        let critic = QinaoCriticDefaultSeat(loop: loop)
        let v = try await critic.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.7)
        // The voice tag must appear in reason codes.
        XCTAssertTrue(
            v.reasonCodes.contains { $0.hasPrefix("voice:") })
    }

    // MARK: - Risk default

    func test_risk_lowConcern_reportsLowUrgency() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1", confidence: 0.9)])
        let risk = QinaoRiskDefaultSeat(loop: loop)
        let v = try await risk.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .risk)
        XCTAssertLessThan(v.urgency, 0.5)
    }

    func test_risk_highManipulation_audible() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.9,
                    boundaryConflict: 0.6),
            ])
        let risk = QinaoRiskDefaultSeat(loop: loop)
        let v = try await risk.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.4)
        // Either guardian-audible or guardian-veto-tier must fire.
        XCTAssertTrue(
            v.reasonCodes.contains("guardian-audible")
            || v.reasonCodes.contains("guardian-veto-tier"))
    }

    // MARK: - Composition with M292.2 registry

    func test_threeDefaultSeats_inRegistryDispatch_allSucceed()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.8,
                    boundaryConflict: 0.5,
                    emotionalBias: 0.6,
                    reversibility: 0.2),
            ])
        let registry = QinaoSeatRegistry()
        await registry.register(
            QinaoScoutDefaultSeat(loop: loop))
        await registry.register(
            QinaoCriticDefaultSeat(loop: loop))
        await registry.register(
            QinaoRiskDefaultSeat(loop: loop))

        let board = await registry.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 3)
        XCTAssertTrue(board.isFullyAttended)

        // Verdicts come back in seat raw-value ASC: critic, risk, scout.
        XCTAssertEqual(
            board.verdicts.map(\.seat),
            [.critic, .risk, .scout])
    }

    func test_unknownSession_seatThrowEnterFailures() async {
        let loop = QinaoLoop()
        let registry = QinaoSeatRegistry()
        await registry.register(
            QinaoScoutDefaultSeat(loop: loop))
        await registry.register(
            QinaoCriticDefaultSeat(loop: loop))

        let board = await registry.dispatch(
            snapshotID: "never-submitted")
        XCTAssertFalse(board.isFullyAttended)
        XCTAssertEqual(board.failures.count, 2)
    }

    // MARK: - Sovereign Sentinel (M292.5)

    func test_sentinel_clean_returnsZeroWithCleanCode() async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1", confidence: 0.9)])
        let sentinel = QinaoSovereignSentinelDefaultSeat(loop: loop)
        let v = try await sentinel.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .sovereignSentinel)
        XCTAssertLessThan(v.urgency, 0.7)
        XCTAssertTrue(v.reasonCodes.contains("clean"))
    }

    func test_sentinel_vetoTier_reportsHighUrgency() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
                makeInput("safer", confidence: 0.8),
            ])
        let sentinel = QinaoSovereignSentinelDefaultSeat(loop: loop)
        let v = try await sentinel.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.7)
        XCTAssertTrue(
            v.reasonCodes.contains("veto-tier-reached"))
    }

    func test_sentinel_allSaturated_reportsSaturationCode()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.9,
                    boundaryConflict: 0.7,
                    emotionalBias: 0.9,
                    reversibility: 0.1),
                makeInput(
                    "c2",
                    manipulationRisk: 0.9,
                    boundaryConflict: 0.7,
                    emotionalBias: 0.9,
                    reversibility: 0.1),
            ])
        let sentinel = QinaoSovereignSentinelDefaultSeat(loop: loop)
        let v = try await sentinel.contribute(snapshotID: "s1")
        XCTAssertTrue(v.reasonCodes.contains("voice-saturation"))
    }

    // MARK: - Standard factory (M292.5)

    func test_standardLoopSeats_registersSixDefaults() async throws
    {
        let loop = QinaoLoop()
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let registered = await registry.registeredSeats()
        XCTAssertEqual(
            registered,
            [
                .critic, .planner, .risk, .scout,
                .sovereignSentinel, .surface,
            ])
    }

    func test_standardLoopSeats_dispatchProducesSixVerdicts()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1",
                    manipulationRisk: 0.6,
                    boundaryConflict: 0.4,
                    emotionalBias: 0.5,
                    reversibility: 0.3),
            ])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let board = await registry.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 6)
        XCTAssertTrue(board.isFullyAttended)
        XCTAssertEqual(
            board.verdicts.map(\.seat),
            [
                .critic, .planner, .risk, .scout,
                .sovereignSentinel, .surface,
            ])
    }

    // MARK: - Planner default (M292.6a)

    func test_planner_singleCandidate_returnsZeroSpread()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1")])
        let planner = QinaoPlannerDefaultSeat(loop: loop)
        let v = try await planner.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .planner)
        XCTAssertEqual(v.urgency, 0, accuracy: 1e-9)
        XCTAssertTrue(
            v.reasonCodes.contains("single-candidate"))
    }

    func test_planner_multipleCandidates_reportsSpread()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "c1", confidence: 0.95),  // likely high score
                makeInput(
                    "c2",
                    manipulationRisk: 0.9,
                    boundaryConflict: 0.7,
                    emotionalBias: 0.8,
                    reversibility: 0.1),  // likely low score
            ])
        let planner = QinaoPlannerDefaultSeat(loop: loop)
        let v = try await planner.contribute(snapshotID: "s1")
        XCTAssertGreaterThan(v.urgency, 0)
        XCTAssertTrue(
            v.reasonCodes.contains("candidate-count:2"))
    }

    // MARK: - Surface default (M292.6a)

    func test_surface_emptyFrontier_throwsSessionUnknown()
        async throws
    {
        let loop = QinaoLoop()
        let surface = QinaoSurfaceDefaultSeat(loop: loop)
        do {
            _ = try await surface.contribute(
                snapshotID: "never-submitted")
            XCTFail("expected sessionUnknown")
        } catch QinaoLoop.LoopError.sessionUnknown {
            // OK — empty frontier reachable only via existing
            // session; unknown session throws first.
        }
    }

    func test_surface_singleCandidate_recommendsDraft()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [makeInput("c1", confidence: 0.9)])
        let surface = QinaoSurfaceDefaultSeat(loop: loop)
        let v = try await surface.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .surface)
        XCTAssertTrue(v.reasonCodes.contains("mode:draft"))
    }

    func test_surface_multiCandidateNoVeto_recommendsCompare()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput("c1", confidence: 0.9),
                makeInput("c2", confidence: 0.85),
            ])
        let surface = QinaoSurfaceDefaultSeat(loop: loop)
        let v = try await surface.contribute(snapshotID: "s1")
        XCTAssertTrue(v.reasonCodes.contains("mode:compare"))
        XCTAssertTrue(
            v.reasonCodes.contains("multi-candidate"))
    }

    func test_surface_vetoTier_recommendsBoundary() async throws {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
            ])
        let surface = QinaoSurfaceDefaultSeat(loop: loop)
        let v = try await surface.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.7)
        XCTAssertTrue(v.reasonCodes.contains("mode:boundary"))
        XCTAssertTrue(
            v.reasonCodes.contains("veto-tier-reached"))
    }

    func test_standardLoopSeats_mergeProducesCanonicalView()
        async throws
    {
        let loop = QinaoLoop()
        try await loop.submit(
            sessionID: "s1",
            candidates: [
                makeInput(
                    "ultimatum",
                    manipulationRisk: 0.85,
                    boundaryConflict: 0.6,
                    emotionalBias: 0.85,
                    reversibility: 0.15),
            ])
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        let board = await registry.dispatch(snapshotID: "s1")
        let merged = board.merge()
        XCTAssertGreaterThan(merged.consensusUrgency, 0)
        XCTAssertNotNil(merged.loudestSeat)
    }
}
