// MARK: - BASTurnRuntimeStageLedger — chapter 四百八 / M1003
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百八 second cut:typed aggregator
// holding a sequence of `BASTurnRuntimeStageRecord` (M1002)
// for one turn。 V2 actor's `.complete` envelope payload
// summarizes via the aggregate accessors。
//
// ## What this ships
//
//   - `BASTurnRuntimeStageLedger` value type wrapping
//     `[BASTurnRuntimeStageRecord]` with typed accessors
//   - Immutable update via `appending(record:)`
//   - Aggregate accessors (matching the M966 ledger pattern):
//     totalDurationMs / completedStageCount /
//     skippedStageCount / failedStageCount
//
// ## Doctrine pins held
//
// All chapter 四百三/四/五/六/七/八 doctrine pins。

import Foundation

/// Typed audit trail of stage records for one turn。
public struct BASTurnRuntimeStageLedger:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    /// Per-stage records in execution order。 V2 actor
    /// appends records as stages run。
    public let records: [BASTurnRuntimeStageRecord]

    // MARK: - Init

    public init(
        records: [BASTurnRuntimeStageRecord] = []
    ) {
        self.records = records
    }

    /// Empty ledger factory (matching M966 pattern)。
    public static func empty() -> BASTurnRuntimeStageLedger {
        BASTurnRuntimeStageLedger()
    }

    // MARK: - Immutable update

    /// Return a new ledger with `record` appended。 Pure。
    public func appending(
        record: BASTurnRuntimeStageRecord
    ) -> BASTurnRuntimeStageLedger {
        BASTurnRuntimeStageLedger(
            records: records + [record])
    }

    // MARK: - Aggregate accessors

    /// Total millis across all records。
    public var totalDurationMs: Int {
        records.reduce(0) { $0 + $1.durationMs }
    }

    /// Number of stages with `.completed` status。
    public var completedStageCount: Int {
        records.filter { $0.didComplete }.count
    }

    /// Number of stages with `.skipped` status。
    public var skippedStageCount: Int {
        records.filter { $0.didSkip }.count
    }

    /// Number of stages with `.failed` status。 V2 actor
    /// surfaces this in `.complete` envelope payload so audit
    /// consumers can grep failed turns。
    public var failedStageCount: Int {
        records.filter { $0.didFail }.count
    }

    /// `true` when at least one stage failed。
    public var hasAnyFailure: Bool {
        failedStageCount > 0
    }

    /// Total record count。
    public var stageCount: Int { records.count }
}
