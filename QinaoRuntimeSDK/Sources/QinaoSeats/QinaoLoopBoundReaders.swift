import Foundation

// M292.6c — typed reader protocols for loop-bound versions of
// Memory / HostAlignment / EvolutionShadow seats.
//
// ## Why this exists
//
// M292.6b shipped three host-configurable advisory seats (Memory
// / HostAlignment / EvolutionShadow). The "blocked-on-substrate-
// adapter-seam" remark from 30.8 was that *loop-bound* versions
// of these seats need substrate APIs that the QinaoLoop / BAS
// layer doesn't yet expose.
//
// M292.6c flips the dependency: instead of waiting for substrate
// to expose the data, define **typed reader protocols** that
// hosts implement against their own substrate adapters, and ship
// **loop-bound seat versions** that take those readers at
// construction. Hosts that already have memory / host /
// evolution data hook in via the protocols.
//
// This is the standard "host-supplies-the-adapter" pattern: the
// seat doesn't know where the data comes from; the host bridges
// substrate to the typed readout.
//
// ## Doctrine
//
// - **Reader protocols are pure shape contracts.** No I/O policy,
//   no error handling beyond `async`. Implementations decide
//   how to fetch (cache / live read / mock).
// - **Readout structs are pure values.** Codable for audit /
//   debugging; constructed by the host's reader and consumed
//   by the seat.
// - **Loop-bound seats reuse M292.6b synthesis logic.** Same
//   doctrine for continuity-break / consent-scope-breach /
//   failure-rate-max — but driven by live readouts instead of
//   construct-time signals.

// MARK: - Memory readout + reader

public struct QinaoMemoryReadout:
    Sendable, Equatable, Hashable, Codable
{
    public let memoryPressure: Double
    public let conflictClusterCount: Int
    public let continuityAtRisk: Bool

    public init(
        memoryPressure: Double,
        conflictClusterCount: Int,
        continuityAtRisk: Bool
    ) {
        self.memoryPressure = min(max(memoryPressure, 0), 1)
        self.conflictClusterCount = max(conflictClusterCount, 0)
        self.continuityAtRisk = continuityAtRisk
    }
}

public protocol QinaoMemoryStateReader: Sendable {
    func readMemoryState(
        sessionID: String
    ) async throws -> QinaoMemoryReadout
}

public struct QinaoMemoryLoopBoundSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .memory
    private let reader: any QinaoMemoryStateReader

    public init(reader: any QinaoMemoryStateReader) {
        self.reader = reader
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let r = try await reader.readMemoryState(
            sessionID: snapshotID)
        // Reuse M292.6b synthesis logic via the configurable
        // seat — same doctrine, live data path.
        let inner = QinaoMemoryDefaultSeat(
            memoryPressure: r.memoryPressure,
            conflictClusterCount: r.conflictClusterCount,
            continuityAtRisk: r.continuityAtRisk)
        return try await inner.contribute(
            snapshotID: snapshotID)
    }
}

// MARK: - HostAlignment readout + reader

public struct QinaoHostAlignmentReadout:
    Sendable, Equatable, Hashable, Codable
{
    public let boundaryViolationCount: Int
    public let valueAxisConflict: Double
    public let consentScopeBreach: Bool

    public init(
        boundaryViolationCount: Int,
        valueAxisConflict: Double,
        consentScopeBreach: Bool
    ) {
        self.boundaryViolationCount =
            max(boundaryViolationCount, 0)
        self.valueAxisConflict =
            min(max(valueAxisConflict, 0), 1)
        self.consentScopeBreach = consentScopeBreach
    }
}

public protocol QinaoHostAlignmentStateReader: Sendable {
    func readHostAlignmentState(
        sessionID: String
    ) async throws -> QinaoHostAlignmentReadout
}

public struct QinaoHostAlignmentLoopBoundSeat:
    QinaoSeatProtocol
{
    public let seat: QinaoSeat = .hostAlignment
    private let reader: any QinaoHostAlignmentStateReader

    public init(reader: any QinaoHostAlignmentStateReader) {
        self.reader = reader
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let r = try await reader.readHostAlignmentState(
            sessionID: snapshotID)
        let inner = QinaoHostAlignmentDefaultSeat(
            boundaryViolationCount: r.boundaryViolationCount,
            valueAxisConflict: r.valueAxisConflict,
            consentScopeBreach: r.consentScopeBreach)
        return try await inner.contribute(
            snapshotID: snapshotID)
    }
}

// MARK: - EvolutionShadow readout + reader

public struct QinaoEvolutionShadowReadout:
    Sendable, Equatable, Hashable, Codable
{
    public let pendingTicketCount: Int
    public let recentRejectionRate: Double
    public let shadowTrialFailureRate: Double

    public init(
        pendingTicketCount: Int,
        recentRejectionRate: Double,
        shadowTrialFailureRate: Double
    ) {
        self.pendingTicketCount = max(pendingTicketCount, 0)
        self.recentRejectionRate =
            min(max(recentRejectionRate, 0), 1)
        self.shadowTrialFailureRate =
            min(max(shadowTrialFailureRate, 0), 1)
    }
}

public protocol QinaoEvolutionShadowStateReader: Sendable {
    func readEvolutionShadowState(
        sessionID: String
    ) async throws -> QinaoEvolutionShadowReadout
}

public struct QinaoEvolutionShadowLoopBoundSeat:
    QinaoSeatProtocol
{
    public let seat: QinaoSeat = .evolutionShadow
    private let reader: any QinaoEvolutionShadowStateReader

    public init(reader: any QinaoEvolutionShadowStateReader) {
        self.reader = reader
    }

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        let r = try await reader.readEvolutionShadowState(
            sessionID: snapshotID)
        let inner = QinaoEvolutionShadowDefaultSeat(
            pendingTicketCount: r.pendingTicketCount,
            recentRejectionRate: r.recentRejectionRate,
            shadowTrialFailureRate: r.shadowTrialFailureRate)
        return try await inner.contribute(
            snapshotID: snapshotID)
    }
}
