import Foundation
import BASRuntimeCore
import BASMemory

/// observe→DISPOSE (biomimetic-brain-efficiency) — the LAST loop-closing piece: translate the effort plan the
/// allocator computes into the EXISTING runtime work-sizing knobs, so the surprise-gated tier decision actually
/// CHANGES compute (the whole point — avoided compute on low-demand turns, more breadth on high-demand ones).
///
/// The cleanest real consumer that already sizes work is `BASAgentRouter`: its `EffortPreference` (`.deep`)
/// pulls extra `.coldSeat` agents awake ("effort.deep-cold-wake"), so a deeper plan wakes MORE agents = more
/// compute, and a `.shallow`/`.standard` plan keeps the roster lean. This maps `BASEffortLevel → EffortPreference`
/// and builds the router context, so a host drives the agent roster from the plan instead of a hardcoded default.
///
/// The plan's finer dials (`budget.candidateCount` for L9, `criticStrength` for L10, `memoryDepth` for L8,
/// `toolVerificationStrength`) ride on `plan.budget` directly — a consumer that sizes those reads them off the
/// plan. This type owns the one translation that connects to existing routing machinery; the host's `route(...)`
/// call site is the adoption seam (same pattern as `adjudicatingOrgan` / `plan(for:surprise:)`).
public enum BASEffortBudgetConsumer {

    /// Map the APPLIED effort level to the agent router's 3-level effort preference. `.deep`/`.max` ⇒ `.deep`
    /// (wake cold seats — more agents); `.fast` ⇒ `.shallow` (lean roster); `.balanced`/`.auto`/`.guarded` ⇒
    /// `.standard` (guarded's safety comes from the risk dials + risk band, not from extra agent breadth).
    public static func agentRouterEffort(
        for level: BASEffortLevel
    ) -> BASAgentRouterContext.EffortPreference {
        switch level {
        case .fast:                    return .shallow
        case .deep, .max:              return .deep
        case .balanced, .auto, .guarded: return .standard
        }
    }

    /// Build a router context from the plan (its APPLIED level) plus the turn's risk band / intent. This is what
    /// a host passes to `BASAgentRouter.route(allSpecs:context:)` so the surprise-gated tier actually sizes the
    /// woken agent roster.
    public static func routerContext(
        for plan: BASEffortPlan,
        riskBand: BASAgentRouterContext.RiskBand,
        intentLayers: [Int] = [],
        requestedAgentIDs: [String] = []
    ) -> BASAgentRouterContext {
        BASAgentRouterContext(
            riskBand: riskBand,
            effortPreference: agentRouterEffort(for: plan.applied),
            intentLayers: intentLayers,
            requestedAgentIDs: requestedAgentIDs)
    }
}
