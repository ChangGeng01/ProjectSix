// MARK: - BASTurnRuntimeStageLedger+Validation — chapter 四百十七 / M1038
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十七 entry:typed validation
// surface for `BASTurnRuntimeStageLedger` (M1003) — mirrors
// the M1007 validation pattern for `BASTurnRuntimeStagePlan`。
// Future audit consumers grep validation issues to detect
// malformed ledgers before attempting to derive summaries。
//
// ## Why this exists (system entropy framing)
//
// `BASTurnRuntimeStageLedger` ships the typed shape but says
// nothing about what makes a ledger VALID。 Future consumers
// (audit dashboards / V1↔V2 stress harnesses) would each
// rederive "is this ledger well-formed?" inline → scattered
// "ledger-validation entropy"。
//
// `BASTurnRuntimeStageLedgerValidationIssue` ships the typed
// failure cases。 `validate()` returns the typed list (empty
// = valid)。
//
// ## What this ships (M1038)
//
//   - `BASTurnRuntimeStageLedgerValidationIssue` typed enum
//     (3 cases:
//       .duplicateStageRecords([BASTurnRuntimeStage]),
//       .negativeDurationRecord(BASTurnRuntimeStage),
//       .recordsExceedingPlanCount(Int))
//   - `BASTurnRuntimeStageLedger.validate()` returning typed
//     issue list
//   - `.isWellFormed: Bool` accessor
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十六 doctrine pins
//   - chapter 一百八十五 — typed enum
//   - chapter 二百一一 — single source-of-truth for
//     validation rules
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the failure modes a stage ledger can
/// have。 Audit consumers grep these to filter malformed
/// ledgers。
public enum BASTurnRuntimeStageLedgerValidationIssue:
    Equatable, Hashable, Sendable, Codable
{
    /// One or more stages appear in more than one record。
    case duplicateStageRecords([BASTurnRuntimeStage])
    /// One record reports a negative duration value (init
    /// clamps to 0,but post-decoding may have lost the
    /// invariant)。
    case negativeDurationRecord(BASTurnRuntimeStage)
    /// Total record count exceeds the canonical 18 stages
    /// of the M1006 plan (impossible for a clean run)。
    case recordsExceedingPlanCount(Int)
}

extension BASTurnRuntimeStageLedger {

    // MARK: - Validation

    /// Return the typed list of issues with this ledger,
    /// empty if well-formed。 Pure;same ledger → same list
    /// (chapter 三百九二)。
    public func validate()
        -> [BASTurnRuntimeStageLedgerValidationIssue]
    {
        var issues:
            [BASTurnRuntimeStageLedgerValidationIssue] = []

        // Pass 1:duplicate-stage check。
        var counts: [BASTurnRuntimeStage: Int] = [:]
        for record in records {
            counts[record.stage, default: 0] += 1
        }
        let duplicates = BASTurnRuntimeStage.allCases
            .filter { (counts[$0] ?? 0) > 1 }
        if !duplicates.isEmpty {
            issues.append(
                .duplicateStageRecords(duplicates))
        }

        // Pass 2:negative duration check (via canonical
        // count;init clamps but Codable-decoded values may
        // bypass)。
        for record in records where record.durationMs < 0 {
            issues.append(
                .negativeDurationRecord(record.stage))
        }

        // Pass 3:plan-count overflow。
        let canonicalStageCount =
            BASTurnRuntimeStage.allCases.count
        if records.count > canonicalStageCount {
            issues.append(
                .recordsExceedingPlanCount(records.count))
        }

        return issues
    }

    /// `true` when the ledger has zero validation issues。
    public var isWellFormed: Bool {
        validate().isEmpty
    }
}
