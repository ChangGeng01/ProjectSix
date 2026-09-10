// MARK: - BASParallelStageDispatchSummary+FromRecords — chapter 四百十五 / M1031
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十五 second cut:typed factory
// `.from(records:group:)` deriving a parallel-group summary
// from M1003 `[BASTurnRuntimeStageRecord]`。 Future V2 actor
// stages call this after each fan-out completes to populate
// the audit envelope payload。
//
// ## Why this exists (system entropy framing)
//
// M1030 ships the typed summary value type but no factory
// that produces it from raw stage records。 Without this
// factory,every consumer would rederive max/sum/count
// inline → scattered "summary-derivation entropy"。
//
// `.from(records:group:)` ships the pure-function factory:
//
//   - filters records to those belonging to the group's
//     canonical member stages
//   - computes cardinality / max / sum from the filtered
//     subset
//   - returns the typed summary
//
// ## What this ships (M1031)
//
//   - `BASParallelStageDispatchSummary.from(records:group:)`
//     static factory
//   - Pure;same input → same summary (chapter 三百九二)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十四/四百十五 doctrine pins
//   - chapter 一百八十五 — typed factory
//   - chapter 二百一一 — single source-of-truth for derivation
//     logic
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASParallelStageDispatchSummary {

    /// Derive a typed summary from a list of stage records,
    /// filtered to those belonging to `group`'s canonical
    /// member stages。 Pure;same input → same summary。
    public static func from(
        records: [BASTurnRuntimeStageRecord],
        group: BASTurnRuntimeStageParallelGroup
    ) -> BASParallelStageDispatchSummary {
        let memberStages = Set(group.canonicalMemberStages)
        let groupRecords = records.filter {
            memberStages.contains($0.stage)
        }
        let cardinality = groupRecords.count
        let maxDuration = groupRecords
            .map { $0.durationMs }.max() ?? 0
        let sumDuration = groupRecords
            .reduce(0) { $0 + $1.durationMs }
        return BASParallelStageDispatchSummary(
            group: group,
            cardinalityActual: cardinality,
            maxStageDurationMs: maxDuration,
            sumStageDurationMs: sumDuration)
    }
}
