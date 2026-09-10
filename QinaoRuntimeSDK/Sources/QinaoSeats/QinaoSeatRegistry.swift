import Foundation

// M292.2 — seat protocol + registry + parallel dispatch.
//
// M292.1 named the 9 seats and the verdict shape but didn't say
// how a host registers a seat or how multiple seats run together.
// M292.2 adds the smallest possible coordination surface:
//
// - `QinaoSeatProtocol`: minimal protocol — `var seat` + async
//   `contribute(snapshotID:)`. Inputs stay thin in this slice; M292.3+
//   will widen `contribute` once the shared object bus shape lands.
// - `QinaoSeatRegistry`: actor that holds registered seats keyed by
//   `QinaoSeat`. Last-write-wins on duplicate registration (caller
//   that registers a fresh implementation always wins; doctrinally
//   it lets hosts swap a seat live without having to clear first).
// - `dispatch(snapshotID:)`: kicks off every registered seat in
//   parallel via a task group, collects verdicts (or per-seat
//   failures), returns a `SeatBoard` ordered by seat raw-value asc
//   for deterministic audit.
// - `SeatBoard`: typed board carrying verdicts + per-seat failure
//   reasons. `isFullyAttended` true iff no seat failed.
//
// Doctrine
//
// - **Single brain, many seats** — the registry holds one
//   instance per seat name. Two `Scout` impls can't co-register;
//   the second wins (consistent with "the council has one voice
//   per role").
// - **Parallel by default** — every dispatch fans out via task
//   group. Seats are independent contributors; serial execution
//   would defeat the manifest v2 第八节 promise of投机并行.
// - **Failures don't poison the board** — one seat throwing
//   doesn't abort the others. The board records which seats
//   succeeded vs. failed; downstream merge logic decides whether
//   a partial board is enough.
// - **Deterministic ordering** — verdicts come out in seat
//   raw-value ASC so audit walkers see stable output regardless
//   of which seat finished first.

/// Minimal seat protocol. Each implementer holds the `seat` it
/// represents and provides `contribute(snapshotID:)` that returns
/// a `SeatVerdict`. The thin `snapshotID` parameter is M292.2's
/// placeholder for what becomes a typed shared-bus snapshot in
/// M292.3+.
public protocol QinaoSeatProtocol: Sendable {
    /// Which seat this implementer represents.
    var seat: QinaoSeat { get }

    /// Read the turn snapshot identified by `snapshotID` and return
    /// this seat's verdict. Throws to indicate the seat couldn't
    /// reach a verdict (e.g. data missing, dependency unavailable);
    /// the registry records the throw as a per-seat failure rather
    /// than aborting the dispatch.
    func contribute(
        snapshotID: String
    ) async throws -> SeatVerdict
}

/// Typed dispatch board carrying verdicts + failure reasons.
public struct SeatBoard:
    Sendable, Equatable, Hashable, Codable
{
    /// Verdicts in seat raw-value ASC order. May be empty.
    public let verdicts: [SeatVerdict]

    /// Per-seat error string for seats whose `contribute` threw.
    /// Keys are exactly the seats that failed; if a seat is in
    /// `failures` it is *not* in `verdicts`.
    public let failures: [QinaoSeat: String]

    public init(
        verdicts: [SeatVerdict],
        failures: [QinaoSeat: String] = [:]
    ) {
        self.verdicts = verdicts
        self.failures = failures
    }

    /// True iff every registered seat returned a verdict.
    public var isFullyAttended: Bool { failures.isEmpty }

    /// Lookup a seat's verdict on this board.
    public func verdict(for seat: QinaoSeat) -> SeatVerdict? {
        verdicts.first { $0.seat == seat }
    }
}

/// Registry + parallel dispatcher for seats. Actor-isolated so
/// concurrent registers / dispatches stay safe; seat
/// `contribute` calls run in their own concurrency contexts via
/// the task group.
public actor QinaoSeatRegistry {

    private var seats: [QinaoSeat: any QinaoSeatProtocol] = [:]

    public init() {}

    /// Register (or replace) a seat. Last-write-wins on duplicate
    /// `seat` values: a fresh implementation supersedes the
    /// previous one. Hosts that want a clean slate first should
    /// call `clear()`.
    public func register(_ seat: any QinaoSeatProtocol) {
        seats[seat.seat] = seat
    }

    /// Remove all registered seats. Used by hosts that want a
    /// clean slate (tests, lifecycle resets).
    public func clear() {
        seats.removeAll()
    }

    /// Snapshot of currently-registered seat names, ASC order.
    public func registeredSeats() -> [QinaoSeat] {
        seats.keys.sorted { $0.rawValue < $1.rawValue }
    }

    /// **M309-internal** — snapshot of registered seat impls.
    /// Used by `dispatchByPhase` (defined in
    /// `QinaoSeatPhaseDispatch.swift`) to filter seats by their
    /// concurrency phase without exposing the private storage.
    /// Not part of the public surface.
    internal func registeredSeatImpls() -> [any QinaoSeatProtocol] {
        seats.values.map { $0 }
    }

    /// Dispatch every registered seat in parallel for one turn.
    /// Returns a `SeatBoard` with verdicts in seat raw-value ASC
    /// order. Seats whose `contribute` throws are recorded in
    /// `failures` instead of aborting the dispatch.
    public func dispatch(
        snapshotID: String
    ) async -> SeatBoard {
        let registered = seats.values.map { $0 }
        if registered.isEmpty {
            return SeatBoard(verdicts: [])
        }
        // Snapshot of (seat, result) — must be Sendable to cross
        // task-group boundaries.
        struct Outcome: Sendable {
            let seat: QinaoSeat
            let verdict: SeatVerdict?
            let errorDescription: String?
        }
        let outcomes: [Outcome] = await withTaskGroup(
            of: Outcome.self
        ) { group in
            for impl in registered {
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
