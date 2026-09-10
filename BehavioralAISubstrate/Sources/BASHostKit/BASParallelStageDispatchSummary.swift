// MARK: - BASParallelStageDispatchSummary — chapter 四百十五 / M1030
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十五 entry:typed value type
// summarizing one parallel-group fan-out's execution
// metrics (cardinality + max stage duration + sum stage
// duration)。 Future V2 actor's `.complete` envelope payload
// surfaces these summaries for audit consumers grepping
// fan-out performance。
//
// ## Why this exists (system entropy framing)
//
// M1003 `BASTurnRuntimeStageLedger` records per-stage
// duration as `[BASTurnRuntimeStageRecord]`。 But there's no
// typed primitive aggregating per-parallel-group execution
// metrics (max-of-N stage durations,sum-of-N,etc.)。
// Without typed summaries,future audit consumers would each
// rederive these aggregates inline → scattered "parallel-
// group summary entropy"。
//
// `BASParallelStageDispatchSummary` ships the typed value:
//
//   - group identifier
//   - cardinalityActual (count of stage records observed)
//   - maxStageDurationMs (slowest stage in the group;
//     dominates fan-out wall-clock)
//   - sumStageDurationMs (total stage duration across the
//     fan-out;useful for cost accounting)
//
// ## What this ships (M1030)
//
//   - `BASParallelStageDispatchSummary` Codable Sendable
//     Equatable value type with 4 typed slots
//   - `.empty(group:)` factory (cardinality 0, both durations 0)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十四 doctrine pins
//   - chapter 一百八十五 — typed summary
//   - chapter 二百一一 — single source-of-truth for parallel-
//     group summary shape
//   - chapter 三百九二 — same input → same summary every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed summary of one parallel-group fan-out's execution
/// metrics。 Future V2 actor's `.complete` envelope payload
/// surfaces these for audit consumers。
public struct BASParallelStageDispatchSummary:
    Codable, Equatable, Hashable, Sendable
{

    // MARK: - Storage

    /// The parallel group this summary describes。
    public let group: BASTurnRuntimeStageParallelGroup

    /// Number of stage records observed for this group
    /// (≤ `group.canonicalFanOutCount` for stage-level
    /// fan-outs)。 Clamped to non-negative。
    public let cardinalityActual: Int

    /// Slowest stage duration in the group (millis)。
    /// Dominates fan-out wall-clock。 Clamped non-negative。
    public let maxStageDurationMs: Int

    /// Sum of all stage durations in the group (millis)。
    /// Useful for cost accounting。 Clamped non-negative。
    public let sumStageDurationMs: Int

    // MARK: - Init

    public init(
        group: BASTurnRuntimeStageParallelGroup,
        cardinalityActual: Int = 0,
        maxStageDurationMs: Int = 0,
        sumStageDurationMs: Int = 0
    ) {
        self.group = group
        self.cardinalityActual =
            max(0, cardinalityActual)
        self.maxStageDurationMs =
            max(0, maxStageDurationMs)
        self.sumStageDurationMs =
            max(0, sumStageDurationMs)
    }

    // MARK: - Convenience factories

    /// Empty summary with cardinality 0 and both durations
    /// 0。 Used as the default placeholder when no records
    /// are available for a group。
    public static func empty(
        group: BASTurnRuntimeStageParallelGroup
    ) -> BASParallelStageDispatchSummary {
        BASParallelStageDispatchSummary(
            group: group,
            cardinalityActual: 0,
            maxStageDurationMs: 0,
            sumStageDurationMs: 0)
    }
}
