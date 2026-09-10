// MARK: - BASV2Foundation+CustomStringConvertible — chapter 四百二十三 / M1063
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十三 second cut:typed
// `CustomStringConvertible` conformance on `BASV2Foundation`
// providing a human-readable per-case rendering for debug
// logs + audit dashboards。
//
// ## Why this exists (system entropy framing)
//
// `BASV2Foundation.rawValue` returns the kebab-case slug
// (e.g. "stage-plan")。 But debug logs + dashboards want
// human-readable labels (e.g. "V2 Stage Plan Foundation
// (chapter 四百九 / M1009)")。 Without a typed
// CustomStringConvertible conformance,every consumer
// would format these strings inline → scattered "label
// formatting entropy"。
//
// ## What this ships (M1063)
//
//   - `BASV2Foundation: CustomStringConvertible` conformance
//     producing "V2 <human-name> Foundation (chapter <tag>
//     / M<m-number>)"
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百二十二 doctrine pins
//   - chapter 一百八十五 — typed conformance,not raw string
//   - chapter 二百一一 — single source-of-truth for human
//     label formatting
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASV2Foundation: CustomStringConvertible {

    /// Human-readable rendering pinned per chapter 一百八十五。
    /// Format: "V2 <name> Foundation (<chapterTag> / M<m>)"
    public var description: String {
        "V2 \(humanName) Foundation " +
        "(\(chapterTag) / M\(mNumberClosingCut))"
    }

    /// Human-readable name component used in `description`。
    /// Pinned per case — bumping these raw labels requires
    /// audit migration per chapter 一百八十五。
    public var humanName: String {
        switch self {
        case .stagePlan:
            return "Stage Plan"
        case .permitFoldInput:
            return "Permit Fold Input"
        case .stressSweepInput:
            return "Stress Sweep Input"
        case .stressSweepPlan:
            return "Stress Sweep Plan"
        case .stressSweepVerdict:
            return "Stress Sweep Verdict"
        case .parallelDispatch:
            return "Parallel Dispatch"
        case .parallelDispatchSummary:
            return "Parallel Dispatch Summary"
        case .parallelSummaryEnvelope:
            return "Parallel Summary Envelope"
        case .stageLedgerValidation:
            return "Stage Ledger Validation"
        case .planLedgerCoherence:
            return "Plan Ledger Coherence"
        case .coherenceEnvelope:
            return "Coherence Envelope"
        case .summaryDigest:
            return "Summary Digest"
        }
    }
}
