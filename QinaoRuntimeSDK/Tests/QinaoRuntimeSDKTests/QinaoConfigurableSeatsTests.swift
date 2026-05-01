import XCTest
@testable import QinaoSeats

/// M292.6b — host-configurable advisory seat contract tests.
///
/// Doctrine pinned:
/// - Memory: continuity-break trumps everything (urgency ≥ 0.7);
///   conflict cluster threshold pinned at ≥ 3
/// - HostAlignment: consent-scope-breach trumps (urgency ≥ 0.8);
///   boundary violations contribute additively up to 0.4
/// - EvolutionShadow: urgency = max(rejection rate, trial failure
///   rate); pending-tickets threshold pinned at ≥ 10
/// - All clamp inputs to valid ranges
final class QinaoConfigurableSeatsTests: XCTestCase {

    // MARK: - Memory

    func test_memory_clean_returnsZero() async throws {
        let m = QinaoMemoryDefaultSeat(
            memoryPressure: 0,
            conflictClusterCount: 0,
            continuityAtRisk: false)
        let v = try await m.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .memory)
        XCTAssertEqual(v.urgency, 0, accuracy: 1e-9)
        XCTAssertTrue(v.reasonCodes.contains("clean"))
    }

    func test_memory_continuityBreakTrumps() async throws {
        let m = QinaoMemoryDefaultSeat(
            memoryPressure: 0.1,
            conflictClusterCount: 0,
            continuityAtRisk: true)
        let v = try await m.contribute(snapshotID: "s1")
        // Continuity break forces urgency to at least 0.7.
        XCTAssertGreaterThanOrEqual(v.urgency, 0.7)
        XCTAssertTrue(
            v.reasonCodes.contains("continuity-break"))
    }

    func test_memory_pressureSignal() async throws {
        let m = QinaoMemoryDefaultSeat(
            memoryPressure: 0.6,
            conflictClusterCount: 0,
            continuityAtRisk: false)
        let v = try await m.contribute(snapshotID: "s1")
        XCTAssertEqual(v.urgency, 0.6, accuracy: 1e-9)
        XCTAssertTrue(
            v.reasonCodes.contains("memory-pressure-high"))
    }

    func test_memory_conflictClusterThreshold() async throws {
        let m = QinaoMemoryDefaultSeat(
            memoryPressure: 0.1,
            conflictClusterCount: 4,
            continuityAtRisk: false)
        let v = try await m.contribute(snapshotID: "s1")
        XCTAssertTrue(
            v.reasonCodes.contains("conflict-clusters:4"))
    }

    func test_memory_clampsInputs() async throws {
        let m = QinaoMemoryDefaultSeat(
            memoryPressure: 1.5,
            conflictClusterCount: -2,
            continuityAtRisk: false)
        XCTAssertEqual(m.memoryPressure, 1.0, accuracy: 1e-9)
        XCTAssertEqual(m.conflictClusterCount, 0)
    }

    // MARK: - HostAlignment

    func test_hostAlignment_aligned_returnsZero() async throws {
        let h = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount: 0,
            valueAxisConflict: 0,
            consentScopeBreach: false)
        let v = try await h.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .hostAlignment)
        XCTAssertEqual(v.urgency, 0, accuracy: 1e-9)
        XCTAssertTrue(v.reasonCodes.contains("aligned"))
    }

    func test_hostAlignment_consentScopeBreachTrumps()
        async throws
    {
        let h = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount: 0,
            valueAxisConflict: 0,
            consentScopeBreach: true)
        let v = try await h.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.8)
        XCTAssertTrue(
            v.reasonCodes.contains("consent-scope-breach"))
    }

    func test_hostAlignment_boundaryViolationsContributeAdditively()
        async throws
    {
        let h = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount: 3,
            valueAxisConflict: 0.2,
            consentScopeBreach: false)
        let v = try await h.contribute(snapshotID: "s1")
        // 0.2 (value) + 0.4 (3 violations capped) = 0.6.
        XCTAssertEqual(v.urgency, 0.6, accuracy: 1e-9)
        XCTAssertTrue(
            v.reasonCodes.contains("boundary-violations:3"))
    }

    func test_hostAlignment_clampsInputs() async throws {
        let h = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount: -1,
            valueAxisConflict: 1.5,
            consentScopeBreach: false)
        XCTAssertEqual(h.boundaryViolationCount, 0)
        XCTAssertEqual(
            h.valueAxisConflict, 1.0, accuracy: 1e-9)
    }

    // MARK: - EvolutionShadow

    func test_evolutionShadow_clean_returnsZero() async throws {
        let e = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: 0,
            recentRejectionRate: 0,
            shadowTrialFailureRate: 0)
        let v = try await e.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .evolutionShadow)
        XCTAssertEqual(v.urgency, 0, accuracy: 1e-9)
        XCTAssertTrue(v.reasonCodes.contains("clean"))
    }

    func test_evolutionShadow_urgencyIsMaxOfFailureRates()
        async throws
    {
        let e = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: 5,
            recentRejectionRate: 0.6,
            shadowTrialFailureRate: 0.3)
        let v = try await e.contribute(snapshotID: "s1")
        XCTAssertEqual(v.urgency, 0.6, accuracy: 1e-9)
        XCTAssertTrue(
            v.reasonCodes.contains("rejection-rate-high"))
    }

    func test_evolutionShadow_shadowTrialFailureCode()
        async throws
    {
        let e = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: 2,
            recentRejectionRate: 0.1,
            shadowTrialFailureRate: 0.7)
        let v = try await e.contribute(snapshotID: "s1")
        XCTAssertTrue(
            v.reasonCodes.contains(
                "shadow-trial-failure-high"))
    }

    func test_evolutionShadow_pendingTicketsThreshold()
        async throws
    {
        let e = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: 12,
            recentRejectionRate: 0,
            shadowTrialFailureRate: 0)
        let v = try await e.contribute(snapshotID: "s1")
        XCTAssertTrue(
            v.reasonCodes.contains(
                "pending-tickets-many:12"))
    }

    func test_evolutionShadow_clampsInputs() async throws {
        let e = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: -5,
            recentRejectionRate: 1.5,
            shadowTrialFailureRate: -0.3)
        XCTAssertEqual(e.pendingTicketCount, 0)
        XCTAssertEqual(
            e.recentRejectionRate, 1.0, accuracy: 1e-9)
        XCTAssertEqual(
            e.shadowTrialFailureRate, 0, accuracy: 1e-9)
    }

    // MARK: - Composition into registry

    func test_threeAdvisorySeatsComposeIntoRegistry()
        async throws
    {
        let registry = QinaoSeatRegistry()
        await registry.register(QinaoMemoryDefaultSeat(
            memoryPressure: 0.3,
            conflictClusterCount: 1,
            continuityAtRisk: false))
        await registry.register(
            QinaoHostAlignmentDefaultSeat(
                boundaryViolationCount: 1,
                valueAxisConflict: 0.4,
                consentScopeBreach: false))
        await registry.register(
            QinaoEvolutionShadowDefaultSeat(
                pendingTicketCount: 5,
                recentRejectionRate: 0.2,
                shadowTrialFailureRate: 0.1))
        let board = await registry.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 3)
        XCTAssertTrue(board.isFullyAttended)
        // ASC raw values: evolutionShadow / hostAlignment / memory.
        XCTAssertEqual(
            board.verdicts.map(\.seat),
            [.evolutionShadow, .hostAlignment, .memory])
    }
}
