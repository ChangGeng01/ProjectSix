import Foundation
import BASRuntimeCore

// Context-IR step 3 (2026-07-12) — the turn-level context compiler.
//
// Before this, per-stage admission values were pulled from the routed budget frame at
// scattered call sites inside the stage functions (the L1 budget CONCEPT existed — M1419's
// routedBudget fold — but every stage self-served from it). The compiler makes admission a
// single pass: runTurn compiles ONE BASTurnContextPlan right after the budget fold, and the
// stages consume their declared sections. The authority is mechanical, not aspirational:
// BASRunTurnFrameBudgetTests.testContextPlanIsTheOnlyBudgetAuthorityAfterCompile reds any raw
// routedBudget consumption downstream of the compile.
//
// HONEST SCOPE: derivation is the IDENTITY over the routed budget (byte-parity by
// construction — every planned value equals the frame value it mirrors; pinned by
// BASTurnContextCompilerTests). The plan is where future admission POLICY goes (e.g.
// thermal-tiered audit verbosity, surprise-gated retrieval depth) — one declared decision
// point instead of new scattered reads. `routedBudget` rides along whole for the service
// signatures that take the frame wholesale; narrowing those into per-stage admissions is
// incremental follow-up work.
//
// The plan needs NO persistence: it is a pure function of the persisted budget frame, so
// replay recompiles it from the record.

/// The compiled per-turn admission plan — what each stage may consume, decided once.
struct BASTurnContextPlan {
    /// L9-L10 deliberation admissions.
    struct DeliberateAdmission {
        let maxLoops: Int
    }

    /// L11 risk admissions (binding retry cap + the mode escalation gates key off).
    struct RiskAdmission {
        let maxLoops: Int
        let runMode: BASEBrainRunMode
    }

    /// The routed budget frame, carried whole for service signatures that take the frame
    /// wholesale (transitional — see header).
    let routedBudget: BASBudgetFrame
    let deliberate: DeliberateAdmission
    let risk: RiskAdmission
}

/// The single compilation point. Pure function — same routed budget ⇒ same plan.
enum BASTurnContextCompiler {
    static func compile(routedBudget: BASBudgetFrame) -> BASTurnContextPlan {
        BASTurnContextPlan(
            routedBudget: routedBudget,
            deliberate: .init(maxLoops: routedBudget.maxLoops),
            risk: .init(maxLoops: routedBudget.maxLoops, runMode: routedBudget.runMode))
    }
}
