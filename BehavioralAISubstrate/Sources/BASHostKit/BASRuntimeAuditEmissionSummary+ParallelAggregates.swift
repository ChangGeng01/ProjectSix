// MARK: - BASRuntimeAuditEmissionSummary+ParallelAggregates — chapter 四百十六 / M1035
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十六 second cut:typed aggregate
// accessors over the M1034 `parallelDispatchSummaries` slot。
// Future audit dashboards grep these aggregates instead of
// re-iterating the array inline。
//
// ## Why this exists (system entropy framing)
//
// M1034 ships the typed slot but consumers wanting "how many
// groups actually fired any work?" or "what's the total
// fan-out cost?" would each iterate inline → scattered
// "parallel-summary aggregation entropy"。
//
// ## What this ships (M1035)
//
//   - `.nonEmptyParallelGroupCount: Int` (groups with
//     cardinalityActual > 0)
//   - `.parallelDispatchTotalDurationMs: Int` (sum of all
//     group sumStageDurationMs)
//   - `.parallelDispatchMaxDurationMs: Int` (max across all
//     groups' maxStageDurationMs;dominates wall-clock)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十五/四百十六 doctrine pins
//   - chapter 一百八十五 — typed accessors
//   - chapter 二百一一 — single source-of-truth for aggregate
//     logic
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASRuntimeAuditEmissionSummary {

    /// Number of parallel groups with at least one stage
    /// record observed (cardinalityActual > 0)。
    public var nonEmptyParallelGroupCount: Int {
        parallelDispatchSummaries
            .filter { $0.cardinalityActual > 0 }.count
    }

    /// Total duration across all groups' sum-of-stage
    /// durations (cost accounting)。
    public var parallelDispatchTotalDurationMs: Int {
        parallelDispatchSummaries
            .reduce(0) { $0 + $1.sumStageDurationMs }
    }

    /// Max-of-max across all groups' max stage duration
    /// (dominant fan-out wall-clock contributor)。 Returns
    /// 0 when no groups have records。
    public var parallelDispatchMaxDurationMs: Int {
        parallelDispatchSummaries
            .map { $0.maxStageDurationMs }.max() ?? 0
    }
}
