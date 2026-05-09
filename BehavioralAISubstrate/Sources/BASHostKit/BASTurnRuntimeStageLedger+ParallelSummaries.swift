// MARK: - BASTurnRuntimeStageLedger+ParallelSummaries — chapter 四百十五 / M1032
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十五 third cut:typed extension
// deriving all 4 parallel-group summaries from an M1003
// `BASTurnRuntimeStageLedger`。 Future V2 actor's `.complete`
// envelope payload calls this once per turn to populate the
// per-group fan-out metrics。
//
// ## Why this exists (system entropy framing)
//
// M1030 + M1031 ship the per-group summary type and its
// from-records factory。 But future V2 actor stages would
// each iterate over `BASTurnRuntimeStageParallelGroup
// .allCases` inline to derive the 4 summaries → scattered
// "all-groups iteration entropy"。
//
// `BASTurnRuntimeStageLedger.parallelDispatchSummaries()`
// ships the typed extension as one source-of-truth (chapter
// 二百一一)。 Returns one summary per parallel group in a
// canonical order anchored by `BASTurnRuntimeStageParallel
// Group.allCases`。
//
// ## What this ships (M1032)
//
//   - `BASTurnRuntimeStageLedger.parallelDispatchSummaries
//     ()` returning `[BASParallelStageDispatchSummary]`
//     of length 4 (one per parallel group case)
//   - Pure;same ledger → same summaries (chapter 三百九二)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十五 doctrine pins
//   - chapter 一百八十五 — typed extension
//   - chapter 二百一一 — single source-of-truth for all-groups
//     iteration
//   - chapter 三百九二 — deterministic order via allCases
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimeStageLedger {

    /// Derive one `BASParallelStageDispatchSummary` per
    /// parallel group from this ledger's records。 Returns
    /// 4 summaries in `BASTurnRuntimeStageParallelGroup
    /// .allCases` order。 Pure;same ledger → same summaries
    /// (chapter 三百九二)。
    public func parallelDispatchSummaries()
        -> [BASParallelStageDispatchSummary]
    {
        BASTurnRuntimeStageParallelGroup.allCases.map {
            group in
            BASParallelStageDispatchSummary.from(
                records: records, group: group)
        }
    }
}
