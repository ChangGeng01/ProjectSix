// MARK: - BASRuntimeAuditEmissionSummary+CoherenceBoolean — chapter 四百十九 / M1047
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十九 second cut:typed derived
// Bool accessor `.planLedgerIsCoherent` companion to the
// M1046 typed Int count。 Future audit dashboards filter by
// the Bool view when only "is this turn coherent or not?"
// matters。
//
// ## Why this exists (system entropy framing)
//
// M1046 ships the issue count Int。 But "is this turn
// coherent?" Bool is a strict view over the count == 0
// predicate。 Without the typed accessor,every audit
// consumer would write the predicate inline → scattered
// "coherence-predicate entropy"。
//
// ## What this ships (M1047)
//
//   - `BASRuntimeAuditEmissionSummary.planLedgerIsCoherent:
//     Bool` derived accessor (count == 0)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十八/四百十九 doctrine pins
//   - chapter 一百八十五 — typed accessor
//   - chapter 二百一一 — single source-of-truth for coherence
//     predicate
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASRuntimeAuditEmissionSummary {

    /// `true` when the plan-ledger coherence issue count
    /// is zero。 Convenience predicate for audit consumers
    /// filtering turns by coherence。
    public var planLedgerIsCoherent: Bool {
        planLedgerCoherenceIssueCount == 0
    }
}
