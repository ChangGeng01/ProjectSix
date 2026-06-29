import Foundation
import BASOrgan
import BASRuntimeCore

/// observe→DISPOSE (biomimetic-brain-efficiency) — the host-side PLUMBING that feeds the three real governance
/// signals into `BASEffortAllocator` to produce a per-turn `BASEffortPlan`. This is the seam the
/// `BASAdjudicationGate` doc pointed at: ε finally reaches a real consumer here (the effort/tier allocator),
/// alongside the stakes estimator and the thermal headroom.
///
/// Decoupling: this takes the predictive-coding ε as a raw `runningMSE: Double?` rather than importing the
/// BASMetalSubstrate observation type — a host that runs `BASBiomimeticTurnObserver` extracts
/// `observation.predictive?.runningMSE` and passes it in. Stakes and thermal are produced END-TO-END here
/// (BASStakesEstimator + ProcessInfo), with both injectable for tests.
///
/// All inputs are real today; the two honest follow-ups are (1) driving the turn observer live so `runningMSE`
/// reflects the actual on-chat prediction error every turn, and (2) consuming `plan.budget` to size L9/L10
/// work. The DECISION (signals → plan) is what this builds.
public enum BASEffortGovernor {

    /// Cold-start surprise when no ε signal is available yet (no predictive-coding MSE). Neutral 0.5 —
    /// coverage-first, mirroring the stakes estimator's "unknown ⇒ engage" bias — so a high-stakes turn still
    /// earns a deep tier on stakes alone before ε comes online, instead of collapsing to reflex (demand=0).
    public static let unknownSurprise = 0.5

    /// Resolve the effort plan for a live turn from real signals.
    ///
    /// - request: the L2 turn (its `.instruction` / `.context` drive the stakes estimate).
    /// - requested: caller's effort request; `.auto` (default) ⇒ the allocator chooses from demand.
    /// - runningMSE: the latest predictive-coding running MSE (ε). `nil` ⇒ `unknownSurprise` (cold start).
    /// - surpriseScale: the MSE→surprise knee (see `BASEffortSignals`).
    /// - thermalState / estimateStakes: injectable producers (default: live `ProcessInfo` + `BASStakesEstimator`).
    public static func plan(
        for request: BASOrganRequest,
        requested: BASEffortLevel = .auto,
        runningMSE: Double? = nil,
        surpriseScale: Double = BASEffortSignals.defaultSurpriseScale,
        thermalState: @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        estimateStakes: @Sendable (String, [String]) -> Double = BASStakesEstimator.estimate
    ) -> BASEffortPlan {
        let stakes = estimateStakes(request.instruction, request.context)
        let headroom = BASEffortSignals.headroom(for: thermalState())
        let surprise = runningMSE.map { BASEffortSignals.surprise(fromMSE: $0, scale: surpriseScale) }
            ?? unknownSurprise
        return BASEffortAllocator.resolve(
            requested: requested, surprise: surprise, stakes: stakes, headroom: headroom)
    }

    /// LIVE end-to-end path: drive the per-session surprise probe with this turn (semantic prediction error ε),
    /// then resolve the plan. This closes the real-ε loop — embed → predictive coding → surprise → allocator —
    /// so the effort tier reflects the ACTUAL per-turn novelty, not a host-supplied / cold-start ε. A host holds
    /// one `BASTurnSurpriseProbe` per session and calls this each turn before generation.
    public static func plan(
        for request: BASOrganRequest,
        surprise probe: BASTurnSurpriseProbe,
        requested: BASEffortLevel = .auto,
        surpriseScale: Double = BASEffortSignals.defaultSurpriseScale,
        thermalState: @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        estimateStakes: @Sendable (String, [String]) -> Double = BASStakesEstimator.estimate
    ) async -> BASEffortPlan {
        let mse = await probe.observe(turn: request.instruction)
        return plan(for: request, requested: requested, runningMSE: mse, surpriseScale: surpriseScale,
                    thermalState: thermalState, estimateStakes: estimateStakes)
    }
}
