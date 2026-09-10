import Foundation

// M292.6b — host-configurable default seats for Memory /
// HostAlignment / EvolutionShadow.
//
// ## Why this exists (and why it's not blocked-on-substrate)
//
// 30.8 / 32.5 deferred Memory / HostAlignment / EvolutionShadow
// default seats as "blocked on substrate adapter seams" — meaning
// the loop doesn't currently expose memory adapter / host
// constitution reader / update-ticket lifecycle reader, so a
// loop-bound default seat couldn't read those signals.
//
// **The block is real for *loop-bound* seats**, but not for
// **host-configurable** advisory seats. Hosts that already have
// memory pressure / host alignment / evolution ticket data in
// their own state can pass those signals into the seat at init
// and get a typed council verdict back. The seat doesn't need to
// reach into substrate — the host pushes signals in.
//
// This is a deliberate doctrinal split:
//
// - **Loop-bound default seats** (M292.3 + M292.6a, in
//   QinaoLoopSeats target) — every contribute call reads live
//   loop state at dispatch time. New default seats here need new
//   loop-exposed APIs.
// - **Host-configurable advisory seats** (this file, in
//   QinaoSeats target, zero-dep) — host instantiates the seat
//   with whatever signals it has and registers it. New
//   configurable seats here only need typed signal definitions.
//
// Hosts that wire substrate adapters can still write loop-bound
// versions later — last-write-wins on the registry lets a
// substrate-driven Memory seat cleanly replace a configurable
// one.

// MARK: - Memory (时间席)

/// Memory seat: host-configurable advisory verdict on episodic
/// memory pressure. Host populates `memoryPressure` (e.g. derived
/// from cache pressure / cold-tier promotion rate),
/// `conflictClusterCount` (M73 cluster count), and
/// `continuityAtRisk` (whether the host suspects a continuity
/// anchor break).
///
/// Doctrine: continuity-break trumps everything — sets urgency to
/// at least 0.7 regardless of other signals. The council should
/// see a memory continuity break as veto-tier on its own.
public struct QinaoMemoryDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .memory

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

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        var urgency = memoryPressure
        if continuityAtRisk {
            urgency = max(urgency, 0.7)
        }
        var codes: [String] = []
        if continuityAtRisk {
            codes.append("continuity-break")
        }
        if conflictClusterCount >= 3 {
            codes.append(
                "conflict-clusters:\(conflictClusterCount)")
        }
        if memoryPressure >= 0.5 {
            codes.append("memory-pressure-high")
        } else if memoryPressure >= 0.2 {
            codes.append("memory-pressure-moderate")
        }
        if codes.isEmpty {
            codes.append("clean")
        }
        return SeatVerdict(
            seat: .memory,
            urgency: urgency,
            reasonCodes: codes,
            note: "snapshot:\(snapshotID)")
    }
}

// MARK: - HostAlignment (宿主对齐席)

/// HostAlignment seat: host-configurable advisory verdict on
/// candidate alignment with host constitution. Host populates
/// `boundaryViolationCount` (count of candidates that touch
/// declared boundaries), `valueAxisConflict` (max [0,1] disagreement
/// across the host's value axes), and `consentScopeBreach`
/// (whether any candidate would expand consented scope).
///
/// Doctrine: consent-scope-breach trumps — host scope expansion
/// without consent is veto-tier. Boundary violations and value-axis
/// disagreement compound but don't auto-veto.
public struct QinaoHostAlignmentDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .hostAlignment

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

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        var urgency = valueAxisConflict
        if boundaryViolationCount >= 1 {
            // Boundary violation contributes additively up to 0.4.
            let boundaryWeight = min(
                Double(boundaryViolationCount) * 0.2, 0.4)
            urgency = min(urgency + boundaryWeight, 1)
        }
        if consentScopeBreach {
            urgency = max(urgency, 0.8)
        }
        var codes: [String] = []
        if consentScopeBreach {
            codes.append("consent-scope-breach")
        }
        if boundaryViolationCount >= 1 {
            codes.append(
                "boundary-violations:\(boundaryViolationCount)")
        }
        if valueAxisConflict >= 0.5 {
            codes.append("value-axis-conflict-high")
        } else if valueAxisConflict >= 0.2 {
            codes.append("value-axis-conflict-moderate")
        }
        if codes.isEmpty {
            codes.append("aligned")
        }
        return SeatVerdict(
            seat: .hostAlignment,
            urgency: urgency,
            reasonCodes: codes,
            note: "snapshot:\(snapshotID)")
    }
}

// MARK: - EvolutionShadow (影子席)

/// EvolutionShadow seat: host-configurable advisory verdict on
/// pending update tickets. Host populates `pendingTicketCount`
/// (M261 lifecycle entries in non-terminal state),
/// `recentRejectionRate` (fraction of recent tickets ending in
/// rejection [0,1]), and `shadowTrialFailureRate` (fraction of
/// recent shadow trials that failed [0,1]).
///
/// Doctrine: high recent rejection / shadow-trial failure rates
/// are warnings that the evolution pipeline is producing bad
/// candidates — sentinel-relevant signal.
public struct QinaoEvolutionShadowDefaultSeat: QinaoSeatProtocol {
    public let seat: QinaoSeat = .evolutionShadow

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

    public func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict {
        // Urgency = max of the two failure-rate signals.
        let urgency = max(
            recentRejectionRate, shadowTrialFailureRate)
        var codes: [String] = []
        if recentRejectionRate >= 0.5 {
            codes.append("rejection-rate-high")
        }
        if shadowTrialFailureRate >= 0.5 {
            codes.append("shadow-trial-failure-high")
        }
        if pendingTicketCount >= 10 {
            codes.append(
                "pending-tickets-many:\(pendingTicketCount)")
        }
        if codes.isEmpty {
            codes.append("clean")
        }
        return SeatVerdict(
            seat: .evolutionShadow,
            urgency: urgency,
            reasonCodes: codes,
            note: "snapshot:\(snapshotID)")
    }
}
