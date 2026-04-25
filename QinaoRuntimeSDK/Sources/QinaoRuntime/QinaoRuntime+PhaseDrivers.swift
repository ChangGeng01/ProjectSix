import Foundation

// M171b — type-erased phase drivers.
//
// M171 extracted the sendSession body into 9 phase methods on
// the QinaoRuntime actor and an 11-line driver. The phase
// ordering became compile-checked, but the driver was still
// imperative — each phase named explicitly. The senior review's
// item 13 final form ("data-driven dispatch, phases
// independently testable") needed one more step: a uniform
// phase contract.
//
// M171b ships that contract. Each phase is wrapped in a
// `PhaseDriver`-conforming value type. The `phaseDrivers`
// array is the ordered registry; the dispatcher loops over it
// and asks each phase to run, stopping at the first non-nil
// `TurnOutcome` (Phase 8 severity halt or Phase 9 terminal
// healthy return).
//
// Why type-erased instead of a closed `enum Phase` discriminant:
// the array form mirrors M172's `observationLayers` so the
// senior review's "新增层 = 新文件 + 注册一行" pattern applies
// to phases too. Adding a hypothetical "PHASE 10 audit-export"
// is one new struct + one entry in `phaseDrivers`.

extension QinaoRuntime {

    /// One phase of the sendSession pipeline. Each conformer
    /// runs the corresponding phase method on the runtime,
    /// optionally returning a `TurnOutcome` to terminate the
    /// pipeline (Phase 8 severity halt; Phase 9 healthy
    /// return).
    package protocol PhaseDriver: Sendable {
        /// Stable ID for telemetry / metric labels.
        var phaseID: String { get }

        /// Execute this phase. Throws on hard failures (Phase 0
        /// validation, Phase 2 audit append, Phase 8a parity,
        /// Phase 8b coverage halt). Returns non-nil when the
        /// pipeline should terminate at this phase with the
        /// returned outcome.
        func run(
            state: inout QinaoRuntime.TurnState,
            runtime: isolated QinaoRuntime,
            claimToCleanup: inout (sessionID: String, turnID: String)?
        ) async throws -> TurnOutcome?
    }

    /// Ordered phase registry. The dispatcher in
    /// `sendSessionBody` iterates this list, stopping at the
    /// first non-nil `TurnOutcome`.
    package static let phaseDrivers: [any PhaseDriver] = [
        Phase0PreflightDriver(),
        Phase0ClaimDriver(),
        Phase1RouteBudgetDriver(),
        Phase2AuditDriver(),
        Phase3AutoStreamDriver(),
        Phase4CoverageReconciliationDriver(),
        Phase5SovereignFrameDriver(),
        Phase6SurfaceDecisionDriver(),
        Phase7RenderFrameDriver(),
        Phase8HaltGatesDriver(),
        Phase9HealthyReturnDriver(),
    ]
}

// MARK: - Phase 0 — Preflight (validation + canonical IDs)

package struct Phase0PreflightDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P0.preflight"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        try runtime.runPhase0Preflight(
            state: &state, claimToCleanup: &claimToCleanup)
        return nil
    }
}

// MARK: - Phase 0b — Atomic halt-and-claim

package struct Phase0ClaimDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P0.claim"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        try await runtime.phase0Claim(
            state: state, claimToCleanup: &claimToCleanup)
        return nil
    }
}

// MARK: - Phase 1 — Route budget

package struct Phase1RouteBudgetDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P1.budget"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase1RouteBudget(state: &state)
        return nil
    }
}

// MARK: - Phase 2 — Audit

package struct Phase2AuditDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P2.audit"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        try await runtime.runPhase2Audit(
            state: &state, claimToCleanup: &claimToCleanup)
        return nil
    }
}

// MARK: - Phase 3 — Auto-stream layers

package struct Phase3AutoStreamDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P3.layers"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase3AutoStream(state: &state)
        return nil
    }
}

// MARK: - Phase 4 — Coverage reconciliation

package struct Phase4CoverageReconciliationDriver:
    QinaoRuntime.PhaseDriver
{
    package let phaseID = "P4.coverage"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase4CoverageReconciliation(
            state: &state)
        return nil
    }
}

// MARK: - Phase 5 — Sovereign frame

package struct Phase5SovereignFrameDriver:
    QinaoRuntime.PhaseDriver
{
    package let phaseID = "P5.sovereign"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase5SovereignFrame(state: &state)
        return nil
    }
}

// MARK: - Phase 6 — Surface decision (sync)

package struct Phase6SurfaceDecisionDriver:
    QinaoRuntime.PhaseDriver
{
    package let phaseID = "P6.surface"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        runtime.runPhase6SurfaceDecision(state: &state)
        return nil
    }
}

// MARK: - Phase 7 — Render frame

package struct Phase7RenderFrameDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P7.render"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase7RenderFrame(state: &state)
        return nil
    }
}

// MARK: - Phase 8 — Halt gates (may return outcome)

package struct Phase8HaltGatesDriver: QinaoRuntime.PhaseDriver {
    package let phaseID = "P8.halt"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        try await runtime.runPhase8HaltGates(state: &state)
    }
}

// MARK: - Phase 9 — Healthy return (terminal)

package struct Phase9HealthyReturnDriver: QinaoRuntime.PhaseDriver
{
    package let phaseID = "P9.healthy"
    package init() {}
    package func run(
        state: inout QinaoRuntime.TurnState,
        runtime: isolated QinaoRuntime,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> QinaoRuntime.TurnOutcome? {
        await runtime.runPhase9HealthyReturn(state: &state)
    }
}
