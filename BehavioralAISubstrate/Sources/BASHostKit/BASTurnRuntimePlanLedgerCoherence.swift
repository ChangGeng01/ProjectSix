// MARK: - BASTurnRuntimePlanLedgerCoherence — chapter 四百十八 / M1043
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十八 second cut:typed value
// type pairing an M1006 plan with an M1003 ledger,plus a
// `.coherenceIssues()` method comparing them via M1042's
// typed issue cases。 Future V1↔V2 stress harnesses + native
// V2 stage drivers consume this to detect drift between
// declared plan and observed execution。
//
// ## Why this exists (system entropy framing)
//
// M1042 ships the typed issue enum but not the comparison
// logic itself。 Without a typed comparison primitive,future
// callers would rederive "are these two ordered stage lists
// the same?" inline → scattered "comparison-logic entropy"。
//
// `BASTurnRuntimePlanLedgerCoherence` ships the typed pair
// and the comparison method as one source-of-truth (chapter
// 二百一一)。
//
// ## What this ships (M1043)
//
//   - `BASTurnRuntimePlanLedgerCoherence` Sendable Equatable
//     value type with `plan + ledger` slots
//   - `.coherenceIssues()` method returning typed
//     `[BASTurnRuntimePlanLedgerCoherenceIssue]`
//   - `.isFullyCoherent: Bool` accessor
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十七/四百十八 doctrine pins
//   - chapter 一百八十五 — typed comparison
//   - chapter 二百一一 — single source-of-truth for
//     comparison logic
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed value type pairing an M1006 stage plan with an
/// M1003 stage ledger,with a typed `.coherenceIssues()`
/// method comparing them。
public struct BASTurnRuntimePlanLedgerCoherence:
    Sendable, Equatable, Codable
{

    // MARK: - Storage

    public let plan: BASTurnRuntimeStagePlan
    public let ledger: BASTurnRuntimeStageLedger

    // MARK: - Init

    public init(
        plan: BASTurnRuntimeStagePlan,
        ledger: BASTurnRuntimeStageLedger
    ) {
        self.plan = plan
        self.ledger = ledger
    }

    // MARK: - Comparison

    /// Return the typed list of coherence issues comparing
    /// `plan` against `ledger`。 Empty list = fully coherent
    /// (plan and ledger contain identical stages in identical
    /// order)。 Pure;same input → same list (chapter 三百九二)。
    public func coherenceIssues()
        -> [BASTurnRuntimePlanLedgerCoherenceIssue]
    {
        var issues:
            [BASTurnRuntimePlanLedgerCoherenceIssue] = []

        let planStages = plan.orderedStages
        let ledgerStages = ledger.records.map { $0.stage }

        let planSet = Set(planStages)
        let ledgerSet = Set(ledgerStages)

        // Pass 1:plan-but-not-ledger
        let missingFromLedger = planStages.filter {
            !ledgerSet.contains($0)
        }
        if !missingFromLedger.isEmpty {
            issues.append(
                .planStagesNotInLedger(missingFromLedger))
        }

        // Pass 2:ledger-but-not-plan
        let extraInLedger = ledgerStages.filter {
            !planSet.contains($0)
        }
        if !extraInLedger.isEmpty {
            issues.append(
                .ledgerStagesNotInPlan(extraInLedger))
        }

        // Pass 3:order-mismatch (only when both contain
        // exactly the same stages but in different order)
        if planSet == ledgerSet
            && planStages != ledgerStages
        {
            issues.append(
                .orderMismatch(
                    planOrder: planStages,
                    ledgerOrder: ledgerStages))
        }

        return issues
    }

    /// `true` when the plan and ledger contain identical
    /// stages in identical order。
    public var isFullyCoherent: Bool {
        coherenceIssues().isEmpty
    }
}
