// MARK: - BASTurnRuntimePlanLedgerCoherence+Canonical — chapter 四百十八 / M1044
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十八 third cut:typed factory
// `.canonicalCoherence(ledger:)` building a coherence pair
// that compares an executed ledger against the canonical
// M1006 plan。 The most useful production case — drift
// detection against the substrate-pinned reference plan。
//
// ## Why this exists (system entropy framing)
//
// M1043 ships `BASTurnRuntimePlanLedgerCoherence(plan:ledger:)`
// taking arbitrary plan and ledger。 But the most common
// production case is "compare ledger against the canonical
// plan" — every audit consumer would each call
// `.canonical()` themselves and pair → scattered "canonical-
// pairing entropy"。
//
// `.canonicalCoherence(ledger:)` ships the typed factory
// as one source-of-truth (chapter 二百一一)。
//
// ## What this ships (M1044)
//
//   - `BASTurnRuntimePlanLedgerCoherence.canonicalCoherence(
//      ledger:)` static factory using `BASTurnRuntimeStagePlan
//      .canonical()`
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十七/四百十八 doctrine pins
//   - chapter 一百八十五 — typed factory
//   - chapter 二百一一 — single source-of-truth for canonical-
//     pair construction
//   - chapter 三百九二 — deterministic (canonical plan +
//     deterministic comparison)
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimePlanLedgerCoherence {

    /// Build a coherence pair comparing the given ledger
    /// against the canonical M1006 plan。 Same ledger →
    /// same coherence pair (chapter 三百九二)。
    public static func canonicalCoherence(
        ledger: BASTurnRuntimeStageLedger
    ) -> BASTurnRuntimePlanLedgerCoherence {
        BASTurnRuntimePlanLedgerCoherence(
            plan: BASTurnRuntimeStagePlan.canonical(),
            ledger: ledger)
    }
}
