import Foundation

// M309 — make `QinaoAgentConcurrencyPhase` load-bearing.
//
// ## Why this exists
//
// Pre-M309 `QinaoAgentFabricDoctrine.swift` shipped 4 typed
// reference enums (`QinaoAgentLatencyCondition` /
// `QinaoAgentConcurrencyPhase` / `QinaoAgentSwarmPart` /
// `QinaoAgentMantra`) plus the `QinaoSeat.concurrencyPhase`
// extension. The 3-phase partition (perception / cognition /
// landing) was typed-pinned but never USED by the dispatcher —
// `QinaoSeatRegistry.dispatch(snapshotID:)` runs ALL registered
// seats fully in parallel without phase ordering.
//
// M309 ships an **additive** runtime path so hosts that want
// the doctrine's 3-phase concurrency model can opt into it
// without changing existing parallel-dispatch callers:
//
//   - `seatsByPhase()` — partition currently-registered seats
//     by their phase. Pure observation; no side effect.
//   - `dispatchByPhase(snapshotID:)` — phases run sequentially
//     (perception → cognition → landing); seats within each
//     phase still run in parallel via task group. Returns a
//     dict so audit consumers see which phase produced what.
//
// The legacy `dispatch(snapshotID:)` method is unchanged —
// hosts that want flat parallel keep it; hosts that want
// doctrinal phase ordering call the new path.
//
// ## Doctrine
//
// - **Additive only.** No breaking change to `dispatch`.
// - **Phase order is fixed.** Perception always runs first,
//   then cognition, then landing — matches manifesto v4 第
//   §4 三阶段并发 description.
// - **Empty phases skip cleanly.** A phase with no registered
//   seats produces an empty SeatBoard for that phase, never
//   a missing entry — auditors can grep by phase
//   unconditionally.
// - **Phase failures isolate.** A throwing seat in cognition
//   doesn't abort landing — same per-seat failure isolation
//   as `dispatch`.

public extension QinaoSeatRegistry {

    /// Snapshot of currently-registered seats grouped by their
    /// concurrency phase. The returned dictionary always
    /// contains entries for all 3 phases (perception /
    /// cognition / landing); a phase with no registered seats
    /// maps to an empty array. Seat order within each phase is
    /// raw-value ASC for deterministic audit output.
    func seatsByPhase() -> [QinaoAgentConcurrencyPhase: [QinaoSeat]] {
        let registered = self.registeredSeatsForPhasePartition()
        var result: [QinaoAgentConcurrencyPhase: [QinaoSeat]] = [:]
        for phase in QinaoAgentConcurrencyPhase.allCases {
            let inPhase = registered.filter {
                phase.seatsInPhase.contains($0)
            }.sorted { $0.rawValue < $1.rawValue }
            result[phase] = inPhase
        }
        return result
    }

    /// Phase-ordered dispatch. Runs perception phase to
    /// completion (all its seats in parallel), then cognition,
    /// then landing. Each phase produces its own `SeatBoard`
    /// keyed by phase. Seats whose `contribute` throws land in
    /// the per-phase `failures` map exactly as in flat
    /// `dispatch`.
    ///
    /// Hosts use this when they want manifesto v4's "perception
    /// (fast) → cognition (deep) → landing (collect)" semantics
    /// — e.g., to short-circuit landing when perception is
    /// already terminal, or to audit phase-level latency.
    func dispatchByPhase(
        snapshotID: String
    ) async -> [QinaoAgentConcurrencyPhase: SeatBoard] {
        var result: [QinaoAgentConcurrencyPhase: SeatBoard] = [:]
        for phase in QinaoAgentConcurrencyPhase.allCases {
            let board = await dispatch(
                snapshotID: snapshotID,
                phase: phase)
            result[phase] = board
        }
        return result
    }

    /// Internal helper: dispatch only the seats whose
    /// `concurrencyPhase` matches the requested phase. Same
    /// task-group + per-seat failure isolation pattern as
    /// `dispatch(snapshotID:)`.
    private func dispatch(
        snapshotID: String,
        phase: QinaoAgentConcurrencyPhase
    ) async -> SeatBoard {
        let phaseSeats = self
            .registeredSeatImpls()
            .filter { phase.seatsInPhase.contains($0.seat) }
        if phaseSeats.isEmpty {
            return SeatBoard(verdicts: [])
        }
        struct Outcome: Sendable {
            let seat: QinaoSeat
            let verdict: SeatVerdict?
            let errorDescription: String?
        }
        let outcomes: [Outcome] = await withTaskGroup(
            of: Outcome.self
        ) { group in
            for impl in phaseSeats {
                group.addTask {
                    do {
                        let v = try await impl.contribute(
                            snapshotID: snapshotID)
                        return Outcome(
                            seat: impl.seat,
                            verdict: v,
                            errorDescription: nil)
                    } catch {
                        return Outcome(
                            seat: impl.seat,
                            verdict: nil,
                            errorDescription: "\(error)")
                    }
                }
            }
            var collected: [Outcome] = []
            for await o in group { collected.append(o) }
            return collected
        }
        let sorted = outcomes.sorted {
            $0.seat.rawValue < $1.seat.rawValue
        }
        var verdicts: [SeatVerdict] = []
        var failures: [QinaoSeat: String] = [:]
        for o in sorted {
            if let v = o.verdict {
                verdicts.append(v)
            } else if let msg = o.errorDescription {
                failures[o.seat] = msg
            }
        }
        return SeatBoard(verdicts: verdicts, failures: failures)
    }
}

// MARK: - Internal accessors

private extension QinaoSeatRegistry {
    /// M309-internal: snapshot of registered seat names without
    /// running dispatch. Public surface stays
    /// `registeredSeats()`; this private helper exists so
    /// `seatsByPhase()` can be a pure derivation.
    func registeredSeatsForPhasePartition() -> [QinaoSeat] {
        registeredSeats()
    }
}
