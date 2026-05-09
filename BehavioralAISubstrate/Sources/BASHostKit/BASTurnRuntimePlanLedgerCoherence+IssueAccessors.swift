// MARK: - BASTurnRuntimePlanLedgerCoherence+IssueAccessors — chapter 四百十九 / M1048
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十九 third cut:typed accessors
// `.coherenceIssueCount` + `.firstIssue` over the M1043
// coherence pair。 Future audit dashboards consume these
// directly without re-running the comparison。
//
// ## Why this exists (system entropy framing)
//
// M1043 ships `.coherenceIssues()` returning the typed list。
// But callers wanting just the count or just the first issue
// would each call `.coherenceIssues()` then post-process →
// repeated comparison work + scattered "issue-derivation
// entropy"。
//
// `.coherenceIssueCount` and `.firstIssue` ship the typed
// accessors so callers don't pay the comparison cost twice。
//
// ## What this ships (M1048)
//
//   - `BASTurnRuntimePlanLedgerCoherence
//     .coherenceIssueCount: Int` accessor
//   - `BASTurnRuntimePlanLedgerCoherence
//     .firstIssue: BASTurnRuntimePlanLedgerCoherenceIssue?`
//     accessor (nil when fully coherent)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十八/四百十九 doctrine pins
//   - chapter 一百八十五 — typed accessors
//   - chapter 二百一一 — single source-of-truth for issue
//     derivation
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimePlanLedgerCoherence {

    /// Number of coherence issues found by comparing plan
    /// against ledger。 Same input → same count (chapter
    /// 三百九二)。
    public var coherenceIssueCount: Int {
        coherenceIssues().count
    }

    /// First coherence issue,or nil when fully coherent。
    /// Useful for audit dashboards that surface a single
    /// "primary issue" view。
    public var firstIssue:
        BASTurnRuntimePlanLedgerCoherenceIssue?
    {
        coherenceIssues().first
    }
}
