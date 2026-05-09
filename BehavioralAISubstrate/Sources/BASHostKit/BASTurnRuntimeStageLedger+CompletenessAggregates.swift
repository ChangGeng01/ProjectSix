// MARK: - BASTurnRuntimeStageLedger+CompletenessAggregates — chapter 四百十七 / M1039
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十七 second cut:typed
// completeness + average-duration accessors on
// `BASTurnRuntimeStageLedger`。 Future audit dashboards grep
// `.isComplete` to filter partial ledgers and
// `.averageStageDurationMs` for performance trending。
//
// ## Why this exists (system entropy framing)
//
// M1003 ships the basic aggregate accessors (totalDurationMs
// / completedStageCount / etc.)。 M1038 ships validation。
// But there's no typed accessor for "did the ledger cover
// all 18 canonical stages?" or "what's the average stage
// duration?"。 Future dashboards would each rederive these
// inline → scattered "ledger-completeness aggregation
// entropy"。
//
// ## What this ships (M1039)
//
//   - `.isComplete: Bool` — every M1000 stage has at least
//     one record
//   - `.missingStages: [BASTurnRuntimeStage]` — stages with
//     zero records,returned in M1000 allCases order
//   - `.averageStageDurationMs: Int` — total duration / record
//     count,or 0 when empty
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十七 doctrine pins
//   - chapter 一百八十五 — typed accessors
//   - chapter 二百一一 — single source-of-truth for
//     completeness aggregation
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimeStageLedger {

    /// `true` when every M1000 canonical stage has at least
    /// one record in the ledger。
    public var isComplete: Bool {
        let recordedStages = Set(records.map { $0.stage })
        return BASTurnRuntimeStage.allCases.allSatisfy {
            recordedStages.contains($0)
        }
    }

    /// Stages with zero records,returned in M1000 allCases
    /// order。 Empty when the ledger is complete。
    public var missingStages: [BASTurnRuntimeStage] {
        let recordedStages = Set(records.map { $0.stage })
        return BASTurnRuntimeStage.allCases.filter {
            !recordedStages.contains($0)
        }
    }

    /// Average stage duration in millis (totalDurationMs
    /// / record count),or 0 when the ledger is empty。
    public var averageStageDurationMs: Int {
        guard records.count > 0 else { return 0 }
        return totalDurationMs / records.count
    }
}
