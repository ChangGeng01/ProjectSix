// MARK: - BASTurnRuntimePlanLedgerCoherenceIssue — chapter 四百十八 / M1042
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十八 entry:typed enum naming
// the failure modes when comparing an M1006
// `BASTurnRuntimeStagePlan` against an M1003
// `BASTurnRuntimeStageLedger`。 Future native V2 stages emit
// these to surface plan↔ledger drift to audit consumers。
//
// ## Why this exists (system entropy framing)
//
// M1006 ships the typed plan;M1003 ships the typed ledger。
// But there's no typed primitive describing the differences
// between "what was supposed to run" and "what actually ran"。
// Future stress harnesses + audit dashboards would each
// rederive the comparison logic inline → scattered "plan-
// ledger comparison entropy"。
//
// `BASTurnRuntimePlanLedgerCoherenceIssue` ships the typed
// enum naming all failure cases the comparison can produce。
//
// ## What this ships (M1042)
//
//   - `BASTurnRuntimePlanLedgerCoherenceIssue` typed enum
//     (3 cases):
//       .planStagesNotInLedger([BASTurnRuntimeStage])
//       .ledgerStagesNotInPlan([BASTurnRuntimeStage])
//       .orderMismatch(planOrder:ledgerOrder:)
//   - Equatable + Hashable + Sendable
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十七 doctrine pins
//   - chapter 一百八十五 — typed enum
//   - chapter 二百一一 — single source-of-truth for
//     comparison failure cases
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the failure modes when comparing a
/// plan against an executed ledger。
public enum BASTurnRuntimePlanLedgerCoherenceIssue:
    Equatable, Hashable, Sendable, Codable
{
    /// One or more stages in the plan have no records in
    /// the ledger。 Associated value is the missing stages
    /// in plan order。
    case planStagesNotInLedger([BASTurnRuntimeStage])
    /// One or more stages in the ledger have no entries
    /// in the plan。 Associated value is the extra stages
    /// in ledger order。
    case ledgerStagesNotInPlan([BASTurnRuntimeStage])
    /// The plan and ledger contain the same stages but
    /// the order differs。 Associated values are the two
    /// orderings。
    case orderMismatch(
        planOrder: [BASTurnRuntimeStage],
        ledgerOrder: [BASTurnRuntimeStage])
}
