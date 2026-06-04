// MARK: - BASAgentFabricMultiRoundLoop — Agent Fabric multi-round AUTHORITATIVE loop (arc ③)
//
// Iterates the Agent Fabric to convergence and produces a final AUTHORITATIVE feed-forward input.
// Builds DIRECTLY on the existing safe scaffold `BASAgentFabricAuthoritativeProjection` (pure,
// deterministic, mode-gated, additive-only): each round dispatches the fabric, projects the
// merge-accepted deltas, and (if not converged) threads that projection into the NEXT round's input
// via an injectable `refine` closure. The converged `finalProjection` is what the host folds into the
// next turn's `userInput` (via `enrichedRequest`) — which the sovereign verdict then gates like any
// input. The loop NEVER applies the projection itself and touches NO runTurn / verdict / coordinator
// code (不变量 #2 神经不掌权; 红线 7 — input-class only).
//
// SAFE BY CONSTRUCTION:
//   • OPT-IN / byte-equal-off — `mode != .authoritative` returns inert BEFORE any dispatch (zero
//     side effects), mirroring the projection's own gate + `deliberationLoopEnabled`.
//   • DETERMINISTIC — `dispatch` (pure dispatcher + pure merge) + the projection digest
//     (SHA256 sortedKeys) are deterministic; `nowNanos` is PINNED via config (never `Date()` in the
//     loop); the per-round turnID is a pure function of base+index; the loop is sequential `await`.
//   • BOUNDED — converges on a digest fixpoint, stops on a nil projection (no accepted deltas), and
//     is hard-capped at `maxRounds` (terminates even on a digest 2-cycle).
//
// Testable: the `dispatch` closure is an injectable seam, so tests drive a deterministic stub fabric
// (not live LLM seats). A live-fabric convenience overload binds it to a real `BASAgentFabricRuntime`.

import Foundation
import BASMemory

/// Injectable per-round fabric dispatch (a real runtime's `dispatchTurn`, or a deterministic test stub).
public typealias BASFabricDispatch =
    @Sendable (BASAgentTurnInput) async -> BASAgentTurnResult

public struct BASAgentFabricMultiRoundConfig: Sendable, Equatable {
    /// Hard budget cap on rounds (>= 1). Guarantees termination even under a digest oscillation.
    public let maxRounds: Int
    /// Base turn ID; each round runs as `"\(baseTurnID)#r\(index)"`.
    public let baseTurnID: String
    /// PINNED recency timestamp stamped onto every round's input — never `Date()` inside the loop, so
    /// the recency tie-break stays replay-stable.
    public let nowNanos: Int64

    public init(maxRounds: Int, baseTurnID: String, nowNanos: Int64 = 0) {
        self.maxRounds = Swift.max(1, maxRounds)
        self.baseTurnID = baseTurnID
        self.nowNanos = nowNanos
    }
}

public struct BASAgentFabricMultiRoundResult: Sendable, Equatable {
    /// Number of fabric dispatches actually run (0 when inert; otherwise 1...maxRounds, monotonic).
    public let roundsRun: Int
    /// True iff the loop stopped on a digest fixpoint (a stable authoritative conclusion set).
    public let converged: Bool
    /// The converged authoritative feed-forward input — or nil (byte-equal-off / no accepted deltas).
    public let finalProjection: BASAgentFabricAuthoritativeInput?
    /// Per-round projection digests, in order (for audit / replay identity).
    public let perRoundDigests: [String]
    /// Why the loop stopped: "mode-inert" | "nil-projection" | "digest-fixpoint" | "digest-cycle" |
    /// "budget-cap".
    public let stopReason: String

    public init(
        roundsRun: Int,
        converged: Bool,
        finalProjection: BASAgentFabricAuthoritativeInput?,
        perRoundDigests: [String],
        stopReason: String
    ) {
        self.roundsRun = roundsRun
        self.converged = converged
        self.finalProjection = finalProjection
        self.perRoundDigests = perRoundDigests
        self.stopReason = stopReason
    }

    /// The inert (byte-equal-off) result: no dispatch ran, no feed-forward produced.
    static let inert = BASAgentFabricMultiRoundResult(
        roundsRun: 0, converged: false, finalProjection: nil,
        perRoundDigests: [], stopReason: "mode-inert")
}

public enum BASAgentFabricMultiRoundLoop {

    /// Run the multi-round authoritative loop with an injectable dispatch (the core entry point).
    /// Returns `.inert` (no dispatch, no feed-forward) unless `mode == .authoritative` — byte-equal-off.
    public static func run(
        mode: BASAgentFabricMode,
        initialInput: BASAgentTurnInput,
        config: BASAgentFabricMultiRoundConfig,
        dispatch: BASFabricDispatch,
        refine: @Sendable (BASAgentTurnInput, BASAgentFabricAuthoritativeInput)
            -> BASAgentTurnInput = { input, _ in input }
    ) async -> BASAgentFabricMultiRoundResult {
        guard mode == .authoritative else { return .inert }

        var current = initialInput
        var digests: [String] = []
        var lastDigest: String?
        var rounds = 0
        var finalProjection: BASAgentFabricAuthoritativeInput?

        while rounds < config.maxRounds {
            let roundTurnID = "\(config.baseTurnID)#r\(rounds)"
            let roundInput = stamped(current, turnID: roundTurnID, nowNanos: config.nowNanos)
            rounds += 1

            let result = await dispatch(roundInput)
            guard let projection = BASAgentFabricAuthoritativeProjection.project(
                fabricResult: result, mode: .authoritative, sourceTurnID: roundTurnID)
            else {
                // No accepted deltas this round → nothing more to feed forward.
                return BASAgentFabricMultiRoundResult(
                    roundsRun: rounds, converged: false, finalProjection: finalProjection,
                    perRoundDigests: digests, stopReason: "nil-projection")
            }

            // Convergence checks (against PRIOR rounds, before recording this one):
            //   • 1-step fixpoint — equals the immediately-previous round → a single stable answer.
            //   • multi-step cycle — the digest reappeared earlier in the run → the loop is oscillating
            //     among a finite conclusion set; stop CLEANLY here instead of burning the budget. Not a
            //     single fixpoint, so `converged: false` (bounded + stable, but no unique answer).
            let isFixpoint = lastDigest.map { projection.digest == $0 } ?? false
            let isCycle = !isFixpoint && digests.contains(projection.digest)
            digests.append(projection.digest)
            finalProjection = projection

            if isFixpoint {
                return BASAgentFabricMultiRoundResult(
                    roundsRun: rounds, converged: true, finalProjection: projection,
                    perRoundDigests: digests, stopReason: "digest-fixpoint")
            }
            if isCycle {
                return BASAgentFabricMultiRoundResult(
                    roundsRun: rounds, converged: false, finalProjection: projection,
                    perRoundDigests: digests, stopReason: "digest-cycle")
            }
            lastDigest = projection.digest
            current = refine(roundInput, projection)
        }

        // Budget cap reached without a fixpoint (terminates even on oscillation).
        return BASAgentFabricMultiRoundResult(
            roundsRun: rounds, converged: false, finalProjection: finalProjection,
            perRoundDigests: digests, stopReason: "budget-cap")
    }

    /// Convenience overload bound to a real `BASAgentFabricRuntime`. Wires the roster's
    /// Single-Writer-Per-Domain claims ONCE before round 0, then dispatches via `runtime.dispatchTurn`.
    /// Returns `.inert` unless `runtime.mode == .authoritative` (byte-equal-off).
    public static func run(
        runtime: BASAgentFabricRuntime,
        initialInput: BASAgentTurnInput,
        config: BASAgentFabricMultiRoundConfig,
        refine: @Sendable (BASAgentTurnInput, BASAgentFabricAuthoritativeInput)
            -> BASAgentTurnInput = { input, _ in input }
    ) async -> BASAgentFabricMultiRoundResult {
        guard runtime.mode == .authoritative else { return .inert }
        // Close the auto-claim race before the first dispatch (idempotent). On overlap it throws;
        // we surface that as inert rather than a partial loop (fail-closed).
        do { try await runtime.wireRosterToGraph() } catch { return .inert }
        return await run(
            mode: runtime.mode,
            initialInput: initialInput,
            config: config,
            dispatch: { await runtime.dispatchTurn(input: $0) },
            refine: refine)
    }

    // MARK: - helpers

    /// Re-stamp an input with a per-round turnID + the pinned nowNanos (all other fields preserved).
    private static func stamped(
        _ input: BASAgentTurnInput, turnID: String, nowNanos: Int64
    ) -> BASAgentTurnInput {
        BASAgentTurnInput(
            turnID: turnID,
            scout: input.scout,
            plannerCandidates: input.plannerCandidates,
            risk: input.risk,
            surface: input.surface,
            memory: input.memory,
            critic: input.critic,
            hostAlignment: input.hostAlignment,
            sovereignSentinel: input.sovereignSentinel,
            evolutionShadow: input.evolutionShadow,
            priorityContext: input.priorityContext,
            nowNanos: nowNanos)
    }
}
