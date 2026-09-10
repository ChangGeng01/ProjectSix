import XCTest
@testable import QinaoSeats

/// M292.6c — loop-bound reader protocol + seat contract tests.
///
/// Doctrine pinned:
/// - Each reader protocol returns a typed readout
/// - Loop-bound seat constructs M292.6b inner seat from readout
/// - Same readout shape → same verdict (loop-bound = configurable)
/// - Reader throws → seat throws → registry records as failure
/// - Readouts clamp inputs to valid ranges
final class QinaoLoopBoundReadersTests: XCTestCase {

    // MARK: - Stub readers

    struct StubMemoryReader: QinaoMemoryStateReader {
        let readout: QinaoMemoryReadout
        func readMemoryState(
            sessionID: String
        ) async throws -> QinaoMemoryReadout { readout }
    }

    struct ThrowingMemoryReader: QinaoMemoryStateReader {
        struct ReaderError: Error, Equatable {}
        func readMemoryState(
            sessionID: String
        ) async throws -> QinaoMemoryReadout {
            throw ReaderError()
        }
    }

    struct StubHostAlignmentReader: QinaoHostAlignmentStateReader {
        let readout: QinaoHostAlignmentReadout
        func readHostAlignmentState(
            sessionID: String
        ) async throws -> QinaoHostAlignmentReadout { readout }
    }

    struct StubEvolutionReader: QinaoEvolutionShadowStateReader {
        let readout: QinaoEvolutionShadowReadout
        func readEvolutionShadowState(
            sessionID: String
        ) async throws -> QinaoEvolutionShadowReadout { readout }
    }

    // MARK: - Memory loop-bound seat

    func test_memoryLoopBound_continuityBreakTrumps() async throws
    {
        let reader = StubMemoryReader(
            readout: QinaoMemoryReadout(
                memoryPressure: 0.1,
                conflictClusterCount: 0,
                continuityAtRisk: true))
        let seat = QinaoMemoryLoopBoundSeat(reader: reader)
        let v = try await seat.contribute(snapshotID: "s1")
        XCTAssertEqual(v.seat, .memory)
        XCTAssertGreaterThanOrEqual(v.urgency, 0.7)
        XCTAssertTrue(
            v.reasonCodes.contains("continuity-break"))
    }

    func test_memoryLoopBound_matchesConfigurableForSameSignals()
        async throws
    {
        let signals = QinaoMemoryReadout(
            memoryPressure: 0.6,
            conflictClusterCount: 4,
            continuityAtRisk: false)
        let reader = StubMemoryReader(readout: signals)
        let loopBound = QinaoMemoryLoopBoundSeat(reader: reader)
        let configurable = QinaoMemoryDefaultSeat(
            memoryPressure: signals.memoryPressure,
            conflictClusterCount: signals.conflictClusterCount,
            continuityAtRisk: signals.continuityAtRisk)
        let lbVerdict = try await loopBound.contribute(
            snapshotID: "s1")
        let cfgVerdict = try await configurable.contribute(
            snapshotID: "s1")
        XCTAssertEqual(lbVerdict, cfgVerdict)
    }

    func test_memoryLoopBound_throwingReaderEntersFailures()
        async
    {
        let reader = ThrowingMemoryReader()
        let seat = QinaoMemoryLoopBoundSeat(reader: reader)
        let registry = QinaoSeatRegistry()
        await registry.register(seat)
        let board = await registry.dispatch(snapshotID: "s1")
        XCTAssertEqual(board.verdicts.count, 0)
        XCTAssertNotNil(board.failures[.memory])
    }

    // MARK: - HostAlignment loop-bound seat

    func test_hostAlignmentLoopBound_consentBreachTrumps()
        async throws
    {
        let reader = StubHostAlignmentReader(
            readout: QinaoHostAlignmentReadout(
                boundaryViolationCount: 0,
                valueAxisConflict: 0.1,
                consentScopeBreach: true))
        let seat = QinaoHostAlignmentLoopBoundSeat(
            reader: reader)
        let v = try await seat.contribute(snapshotID: "s1")
        XCTAssertGreaterThanOrEqual(v.urgency, 0.8)
        XCTAssertTrue(
            v.reasonCodes.contains("consent-scope-breach"))
    }

    func test_hostAlignmentLoopBound_matchesConfigurable()
        async throws
    {
        let signals = QinaoHostAlignmentReadout(
            boundaryViolationCount: 2,
            valueAxisConflict: 0.5,
            consentScopeBreach: false)
        let reader = StubHostAlignmentReader(readout: signals)
        let lb = QinaoHostAlignmentLoopBoundSeat(reader: reader)
        let cfg = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount:
                signals.boundaryViolationCount,
            valueAxisConflict: signals.valueAxisConflict,
            consentScopeBreach: signals.consentScopeBreach)
        let lbV = try await lb.contribute(snapshotID: "s1")
        let cfgV = try await cfg.contribute(snapshotID: "s1")
        XCTAssertEqual(lbV, cfgV)
    }

    // MARK: - EvolutionShadow loop-bound seat

    func test_evolutionShadowLoopBound_failureRateUrgency()
        async throws
    {
        let reader = StubEvolutionReader(
            readout: QinaoEvolutionShadowReadout(
                pendingTicketCount: 5,
                recentRejectionRate: 0.7,
                shadowTrialFailureRate: 0.3))
        let seat = QinaoEvolutionShadowLoopBoundSeat(
            reader: reader)
        let v = try await seat.contribute(snapshotID: "s1")
        XCTAssertEqual(v.urgency, 0.7, accuracy: 1e-9)
        XCTAssertTrue(
            v.reasonCodes.contains("rejection-rate-high"))
    }

    func test_evolutionShadowLoopBound_matchesConfigurable()
        async throws
    {
        let signals = QinaoEvolutionShadowReadout(
            pendingTicketCount: 12,
            recentRejectionRate: 0.4,
            shadowTrialFailureRate: 0.6)
        let reader = StubEvolutionReader(readout: signals)
        let lb = QinaoEvolutionShadowLoopBoundSeat(
            reader: reader)
        let cfg = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: signals.pendingTicketCount,
            recentRejectionRate: signals.recentRejectionRate,
            shadowTrialFailureRate:
                signals.shadowTrialFailureRate)
        let lbV = try await lb.contribute(snapshotID: "s1")
        let cfgV = try await cfg.contribute(snapshotID: "s1")
        XCTAssertEqual(lbV, cfgV)
    }

    // MARK: - Readouts clamp inputs

    func test_memoryReadoutClamps() {
        let r = QinaoMemoryReadout(
            memoryPressure: 1.5,
            conflictClusterCount: -3,
            continuityAtRisk: false)
        XCTAssertEqual(r.memoryPressure, 1.0, accuracy: 1e-9)
        XCTAssertEqual(r.conflictClusterCount, 0)
    }

    func test_hostAlignmentReadoutClamps() {
        let r = QinaoHostAlignmentReadout(
            boundaryViolationCount: -1,
            valueAxisConflict: 2.0,
            consentScopeBreach: false)
        XCTAssertEqual(r.boundaryViolationCount, 0)
        XCTAssertEqual(r.valueAxisConflict, 1.0, accuracy: 1e-9)
    }

    func test_evolutionShadowReadoutClamps() {
        let r = QinaoEvolutionShadowReadout(
            pendingTicketCount: -5,
            recentRejectionRate: 1.5,
            shadowTrialFailureRate: -0.3)
        XCTAssertEqual(r.pendingTicketCount, 0)
        XCTAssertEqual(
            r.recentRejectionRate, 1.0, accuracy: 1e-9)
        XCTAssertEqual(
            r.shadowTrialFailureRate, 0, accuracy: 1e-9)
    }
}
