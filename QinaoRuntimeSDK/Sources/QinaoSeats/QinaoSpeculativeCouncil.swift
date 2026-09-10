import Foundation

// 六十五.5 — speculative parallelism wrapper for council turns.
//
// deep-audit DORMANT (2026-07-13): test-only scaffolding — NO production consumer. Live council
// turns run via QinaoLoopSeats' `runCouncilTurn`; this discard-on-veto speculative wrapper is
// constructed only by tests. Honestly marked dormant per pin-boundary-defer-interface; TRIGGER
// = the first host adopting the propose/dispose seat fabric onto the sovereign spine. See
// QinaoSeatFabricDormancyBoundaryTests.
//
// ## Why this exists
//
// Manifesto v4 五.5 says "投机并行 — 在前哨还没完全结束
// 时，就可以投机预热下游"。Existing council mechanisms
// (e.g., `runCouncilTurn` in QinaoLoopSeats) run seats in
// parallel. But the **discard-on-veto** semantics —
// speculatively run cognition seats while sovereign sentinel
// checks legality, then discard if sovereign vetoes — wasn't
// typed.
//
// 六十五.5 ships `QinaoSpeculativeCouncil` — a generic
// wrapper that takes any async council runner + a veto
// predicate, runs them concurrently, and returns a typed
// outcome (.committed or .vetoed).
//
// **Module-independent** — lives in QinaoSeats (dep-free)
// so callers in QinaoLoopSeats / QinaoDefaults / hosts can
// all use it. Generic over the council result type.
//
// ## Doctrine
//
// - **Speculation never bypasses commit gate.** Even
//   `.committed` results still need
//   `QinaoAgentCommitGate.canCommit` for any side effects.
// - **Veto is fail-closed.** Veto fires → `.vetoed`,
//   speculative work discarded.
// - **Both branches typed.**

public enum QinaoSpeculativeOutcome<Result: Sendable>:
    Sendable
{
    /// Speculation completed; result ready for downstream
    /// consumption (typically followed by commit gate
    /// check elsewhere).
    case committed(Result)

    /// Veto signal arrived; speculative result discarded.
    case vetoed(reason: String)
}

public enum QinaoSpeculativeCouncil {

    /// Run a council mechanism speculatively. Caller
    /// supplies (a) the council runner closure and (b) a
    /// veto predicate. Both run concurrently. If veto fires
    /// FIRST (or while council is still running),
    /// `.vetoed` is returned and the council Task is
    /// **cancelled** so it stops doing speculative work.
    /// If council finishes first, veto is still checked;
    /// veto wins → `.vetoed`, council result discarded.
    ///
    /// **Real cancellation semantics**: cooperative — the
    /// council closure must honor `Task.checkCancellation()`
    /// or its `await`s must be cancellation-aware to
    /// actually stop early. If the closure is uncancellable
    /// (pure CPU loop without checks), it will run to
    /// completion regardless; this is Swift's standard
    /// cooperative cancellation model.
    public static func runSpeculatively<Result: Sendable>(
        council: @Sendable @escaping () async -> Result,
        veto: @Sendable @escaping () async -> (
            isVeto: Bool, reason: String
        )
    ) async -> QinaoSpeculativeOutcome<Result> {
        let councilTask = Task<Result, Never> {
            await council()
        }
        let v = await veto()
        if v.isVeto {
            // Cancel the speculative work (cooperative).
            councilTask.cancel()
            // Drain the result so the task doesn't outlive
            // this scope (await it, but discard).
            _ = await councilTask.value
            return .vetoed(reason: v.reason)
        }
        let r = await councilTask.value
        return .committed(r)
    }

    /// Convenience overload using a boolean veto + default
    /// reason string.
    public static func runSpeculatively<Result: Sendable>(
        council: @Sendable @escaping () async -> Result,
        sovereignVeto:
            @Sendable @escaping () async -> Bool,
        vetoReason: String = "sovereign-veto"
    ) async -> QinaoSpeculativeOutcome<Result> {
        await runSpeculatively(
            council: council,
            veto: {
                let isVeto = await sovereignVeto()
                return (isVeto, vetoReason)
            })
    }
}
