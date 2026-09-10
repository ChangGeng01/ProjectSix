import Foundation
import QinaoSeats
import QinaoLoop

// M292.7 — minimal runtime wire between QinaoLoop and the seat
// council. Hosts that have already submitted candidates to a
// session call `runCouncilTurn(loop:registry:sessionID:)` to fire
// every registered seat in parallel and receive a merged board.
//
// This is deliberately thin: no state, no caching, no automatic
// resubmission. The wire's job is composition — `submit + dispatch
// + merge` becomes one async call. Richer hooks (auto-dispatch on
// every loop turn, verdict feedback into the next round) are
// future milestones.
//
// Doctrine
//
// - **One council per turn.** Caller decides when the council
//   fires; this function doesn't tail-recurse or watch state.
// - **Merge always runs.** The returned `MergedSeatBoard` is
//   M292.4's canonical view; hosts wanting raw verdicts read
//   `.board.verdicts`.
// - **No new failure mode.** Whatever the registry's `dispatch`
//   does, this wrapper preserves verbatim. Failed seats land in
//   `.board.failures`; merge skips them.

/// Run the council on an already-populated session: dispatch
/// every registered seat in parallel, then merge the resulting
/// board into a canonical view.
///
/// - Parameters:
///   - loop: the `QinaoLoop` carrying the session state. Not
///     used directly here — seats reach it via the references
///     they captured at construction. Passed for API symmetry
///     and future-proofing (callers that want to compose
///     `submit + dispatch` in one site).
///   - registry: the seat registry to dispatch. Typically
///     `QinaoSeatRegistry.standardLoopSeats(loop:)` from M292.5.
///   - sessionID: session whose state seats should read.
///     Forwarded to `registry.dispatch(snapshotID:)`.
/// - Returns: `MergedSeatBoard` with `.board` carrying raw
///   verdicts + failures and `.consensusUrgency / .loudestSeat /
///   .dissent / .silentSeats` carrying canonical merge.
public func runCouncilTurn(
    loop: QinaoLoop,
    registry: QinaoSeatRegistry,
    sessionID: String
) async -> MergedSeatBoard {
    _ = loop // captured but not directly read; kept for symmetry.
    let board = await registry.dispatch(snapshotID: sessionID)
    return board.merge()
}

// MARK: - M292.9 — typed council session abstraction

/// Bundle of `(loop, sessionID, registry)` so multi-turn hosts
/// don't re-pass the same trio on every call. Lightweight value
/// type — no state of its own; every method delegates to the
/// underlying loop / registry.
///
/// Doctrine
///
/// - **Sendable, immutable.** `QinaoCouncilSession` is a value
///   type; rebinding the struct does not affect the underlying
///   loop / registry actors.
/// - **No hidden caching.** Each `dispatch()` runs the council
///   live; nothing is memoised. Callers who want memoisation
///   wire it themselves outside the session.
/// - **Errors surface from underlying methods.** Submit / generate
///   throw their normal errors; dispatch never throws.
public struct QinaoCouncilSession: Sendable {

    public let loop: QinaoLoop
    public let sessionID: String
    public let registry: QinaoSeatRegistry

    public init(
        loop: QinaoLoop,
        sessionID: String,
        registry: QinaoSeatRegistry
    ) {
        self.loop = loop
        self.sessionID = sessionID
        self.registry = registry
    }

    /// Dispatch the council on the current session state.
    public func dispatch() async -> MergedSeatBoard {
        await runCouncilTurn(
            loop: loop,
            registry: registry,
            sessionID: sessionID)
    }

    /// Submit `candidates` to the session, then dispatch the
    /// council. Throws whatever `loop.submit(...)` throws.
    public func submit(
        _ candidates: [QinaoLoop.CandidateInput]
    ) async throws -> MergedSeatBoard {
        try await loop.submitAndRunCouncil(
            sessionID: sessionID,
            candidates: candidates,
            registry: registry)
    }

    /// Generate candidates from organ-driven seeds, then dispatch
    /// the council. Throws whatever
    /// `loop.generateCandidates(...)` throws.
    public func generateCandidates(
        seeds: [QinaoLoop.CandidateSeed]
    ) async throws -> (
        candidates: [QinaoLoop.GeneratedCandidate],
        merged: MergedSeatBoard
    ) {
        try await loop.generateCandidatesAndRunCouncil(
            sessionID: sessionID,
            seeds: seeds,
            registry: registry)
    }
}

// MARK: - M292.8 — auto-dispatch convenience (submit + council)

public extension QinaoLoop {

    /// M292.8 — submit candidates, then immediately run the
    /// council on the resulting session. One call replaces three
    /// (`submit` + `dispatch` + `merge`). Throws whatever
    /// `submit(sessionID:candidates:)` throws (validation /
    /// duplicate IDs / etc.); the council itself never throws —
    /// failures land in the returned `MergedSeatBoard.board.failures`.
    func submitAndRunCouncil(
        sessionID: String,
        candidates: [CandidateInput],
        registry: QinaoSeatRegistry
    ) async throws -> MergedSeatBoard {
        try await submit(
            sessionID: sessionID, candidates: candidates)
        return await runCouncilTurn(
            loop: self,
            registry: registry,
            sessionID: sessionID)
    }

    /// M292.8 — generate candidates from organ-driven seeds, then
    /// immediately run the council. Throws whatever
    /// `generateCandidates(sessionID:seeds:)` throws.
    func generateCandidatesAndRunCouncil(
        sessionID: String,
        seeds: [CandidateSeed],
        registry: QinaoSeatRegistry
    ) async throws -> (
        candidates: [GeneratedCandidate],
        merged: MergedSeatBoard
    ) {
        let cands = try await generateCandidates(
            sessionID: sessionID, seeds: seeds)
        let merged = await runCouncilTurn(
            loop: self,
            registry: registry,
            sessionID: sessionID)
        return (cands, merged)
    }
}
