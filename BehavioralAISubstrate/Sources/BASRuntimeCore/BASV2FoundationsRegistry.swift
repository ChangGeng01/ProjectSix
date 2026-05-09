// MARK: - BASV2FoundationsRegistry — chapter 四百二十一 / M1054
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十一 entry:typed registry
// aggregating the 12 V2 FOUNDATION milestones shipped across
// chapters 四百九-四百二十。 Audit consumers grep this single
// registry to enumerate "what V2 typed scaffolding exists?"
// without traversing 12 separate chapter doctrines。
//
// ## Why this exists (system entropy framing)
//
// Chapters 四百九-四百二十 each ship a 4-cut V2 FOUNDATION
// milestone (12 foundations total)。 But there's no single
// registry where a consumer can ask "what V2 foundations
// exist?" — they'd have to enumerate 12 chapter doctrines
// individually → "foundations enumeration entropy"。
//
// `BASV2FoundationsRegistry` ships the typed enum with one
// case per milestone,plus convenience accessors:
//   - foundationCount (12)
//   - mNumberRanges (the M-range each foundation occupies)
//   - chapterTags (the chapter each foundation closes out)
//
// ## What this ships (M1054)
//
//   - `BASV2Foundation` typed enum (12 cases,one per
//     milestone)
//   - CaseIterable + Codable + Hashable + Sendable
//   - `.chapterTag` / `.mNumberLast` accessors per case
//   - `BASV2FoundationsRegistry` namespace with aggregate
//     accessors
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百二十 doctrine pins
//   - chapter 一百八十五 — typed enum
//   - chapter 二百一一 — single source-of-truth for V2
//     foundations registry
//   - chapter 三百九二 — same enum every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the 12 V2 FOUNDATION milestones shipped
/// across chapters 四百九-四百二十。
public enum BASV2Foundation:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case stagePlan = "stage-plan"                              // 四百九 / M1009
    case permitFoldInput = "permit-fold-input"                 // 四百十 / M1013
    case stressSweepInput = "stress-sweep-input"               // 四百十一 / M1017
    case stressSweepPlan = "stress-sweep-plan"                 // 四百十二 / M1021
    case stressSweepVerdict = "stress-sweep-verdict"           // 四百十三 / M1025
    case parallelDispatch = "parallel-dispatch"                // 四百十四 / M1029
    case parallelDispatchSummary = "parallel-dispatch-summary" // 四百十五 / M1033
    case parallelSummaryEnvelope = "parallel-summary-envelope" // 四百十六 / M1037
    case stageLedgerValidation = "stage-ledger-validation"     // 四百十七 / M1041
    case planLedgerCoherence = "plan-ledger-coherence"         // 四百十八 / M1045
    case coherenceEnvelope = "coherence-envelope"              // 四百十九 / M1049
    case summaryDigest = "summary-digest"                      // 四百二十 / M1053
}

extension BASV2Foundation {

    /// chapter tag of the chapter that closes out this
    /// foundation。
    public var chapterTag: String {
        switch self {
        case .stagePlan:               return "chapter 四百九"
        case .permitFoldInput:         return "chapter 四百十"
        case .stressSweepInput:        return "chapter 四百十一"
        case .stressSweepPlan:         return "chapter 四百十二"
        case .stressSweepVerdict:      return "chapter 四百十三"
        case .parallelDispatch:        return "chapter 四百十四"
        case .parallelDispatchSummary: return "chapter 四百十五"
        case .parallelSummaryEnvelope: return "chapter 四百十六"
        case .stageLedgerValidation:   return "chapter 四百十七"
        case .planLedgerCoherence:     return "chapter 四百十八"
        case .coherenceEnvelope:       return "chapter 四百十九"
        case .summaryDigest:           return "chapter 四百二十"
        }
    }

    /// M-number of the close-out cut for this foundation。
    public var mNumberClosingCut: Int {
        switch self {
        case .stagePlan:               return 1009
        case .permitFoldInput:         return 1013
        case .stressSweepInput:        return 1017
        case .stressSweepPlan:         return 1021
        case .stressSweepVerdict:      return 1025
        case .parallelDispatch:        return 1029
        case .parallelDispatchSummary: return 1033
        case .parallelSummaryEnvelope: return 1037
        case .stageLedgerValidation:   return 1041
        case .planLedgerCoherence:     return 1045
        case .coherenceEnvelope:       return 1049
        case .summaryDigest:           return 1053
        }
    }
}

/// Namespace aggregating queries over the V2 foundations
/// registry。
public enum BASV2FoundationsRegistry {

    /// Total number of V2 FOUNDATION milestones shipped
    /// across chapters 四百九-四百二十。
    public static let foundationCount: Int = 12

    /// All chapter tags closing out V2 foundations,in
    /// allCases order。
    public static var allChapterTags: [String] {
        BASV2Foundation.allCases.map { $0.chapterTag }
    }

    /// All M-numbers closing out V2 foundations,in
    /// allCases order。
    public static var allClosingMNumbers: [Int] {
        BASV2Foundation.allCases.map {
            $0.mNumberClosingCut
        }
    }
}
