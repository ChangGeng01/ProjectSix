// SPDX-License-Identifier: Apache-2.0
// M561-M565 (chapter 一百四十一 / Appendix R) — Naked vs Substrate
// output comparator for assumption-debt empirical smoke test.
//
// ## Why this exists
//
// User audit assumption #1 ("14 层架构必要") was supported by
// chapter 一百三十六 measuring substrate audit-code count (142
// codes/turn vs 0 naked) but did NOT compare actual output text.
// Output-text quality comparison was Q.2.2 full deferred.
//
// Chapter 一百四十一 / Appendix R closes that deferral with a
// real-machine smoke test:
//   1. naked AFM path: prompt → AppleFoundationOrganAdapter → text
//   2. naked Gemma 4 E2B path: prompt → substrate MLX endpoint → text
//   3. substrate path: prompt → BASHostRuntime decision + audit
//
// For each path, count red-line violations in the output text using
// existing 5 lint helpers. Report side-by-side comparison.
//
// ## Limitations (honest disclosure)
//
// - Naked emits text; substrate emits audit + decision (cross-modal
//   comparison). Where substrate produces output text via L9
//   candidate body, that's the substrate "output" we lint;
//   otherwise we report substrate as "no comparable output text".
// - Smoke test scope: 5 prompts illustrative, not statistical
// - LLM availability gates: AFM requires macOS 26+ + Apple
//   Intelligence; Gemma 4 E2B requires MLX dependency + weights
//   cache. Either path may graceful-skip with diagnostic.
//
// ## DAG discipline
//
// Imports `Foundation` only. Library target so XCTest can
// `@testable import QinaoLoop`. Existing 5 BAS lint helpers are
// imported by callers (sample-host) since they live in BAS layers
// and we don't want to pull BAS deps into QinaoLoop.

import Foundation

/// Side-by-side comparison record for a single prompt.
public struct QinaoNakedVsSubstrateComparison:
    Sendable, Equatable
{
    public let prompt: String
    /// Naked AFM response text. nil when AFM unavailable.
    public let nakedAFMResponse: String?
    /// Naked Gemma 4 E2B response text. nil when MLX/Gemma
    /// unavailable.
    public let nakedGemmaResponse: String?
    /// Substrate's reason-code count from audit emission.
    public let substrateAuditCodeCount: Int
    /// Substrate's final permit mode (e.g. "answer", "compare",
    /// "block").
    public let substratePermitMode: String
    /// Substrate's L9 candidate body text if available, else nil.
    public let substrateOutputBody: String?
    /// Red-line violation count in naked AFM output text. Only
    /// meaningful when nakedAFMResponse != nil.
    public let nakedAFMRedLineCount: Int
    /// Red-line violation count in naked Gemma output text. Only
    /// meaningful when nakedGemmaResponse != nil.
    public let nakedGemmaRedLineCount: Int
    /// Red-line violation count in substrate output body. Only
    /// meaningful when substrateOutputBody != nil.
    public let substrateRedLineCount: Int

    public init(
        prompt: String,
        nakedAFMResponse: String?,
        nakedGemmaResponse: String?,
        substrateAuditCodeCount: Int,
        substratePermitMode: String,
        substrateOutputBody: String?,
        nakedAFMRedLineCount: Int,
        nakedGemmaRedLineCount: Int,
        substrateRedLineCount: Int
    ) {
        self.prompt = prompt
        self.nakedAFMResponse = nakedAFMResponse
        self.nakedGemmaResponse = nakedGemmaResponse
        self.substrateAuditCodeCount = substrateAuditCodeCount
        self.substratePermitMode = substratePermitMode
        self.substrateOutputBody = substrateOutputBody
        self.nakedAFMRedLineCount = nakedAFMRedLineCount
        self.nakedGemmaRedLineCount = nakedGemmaRedLineCount
        self.substrateRedLineCount = substrateRedLineCount
    }
}

/// Aggregate red-line violation summary across N comparisons.
public struct QinaoComparatorAggregate: Sendable, Equatable {
    public let totalPrompts: Int
    public let nakedAFMTotalViolations: Int
    public let nakedGemmaTotalViolations: Int
    public let substrateTotalViolations: Int
    public let nakedAFMAvailableCount: Int
    public let nakedGemmaAvailableCount: Int
    public let substrateOutputAvailableCount: Int

    public init(
        totalPrompts: Int,
        nakedAFMTotalViolations: Int,
        nakedGemmaTotalViolations: Int,
        substrateTotalViolations: Int,
        nakedAFMAvailableCount: Int,
        nakedGemmaAvailableCount: Int,
        substrateOutputAvailableCount: Int
    ) {
        self.totalPrompts = totalPrompts
        self.nakedAFMTotalViolations = nakedAFMTotalViolations
        self.nakedGemmaTotalViolations =
            nakedGemmaTotalViolations
        self.substrateTotalViolations = substrateTotalViolations
        self.nakedAFMAvailableCount = nakedAFMAvailableCount
        self.nakedGemmaAvailableCount =
            nakedGemmaAvailableCount
        self.substrateOutputAvailableCount =
            substrateOutputAvailableCount
    }

    public static func aggregate(
        comparisons: [QinaoNakedVsSubstrateComparison]
    ) -> QinaoComparatorAggregate {
        var afmViolations = 0
        var gemmaViolations = 0
        var substrateViolations = 0
        var afmAvail = 0
        var gemmaAvail = 0
        var substrateAvail = 0
        for c in comparisons {
            if c.nakedAFMResponse != nil {
                afmAvail += 1
                afmViolations += c.nakedAFMRedLineCount
            }
            if c.nakedGemmaResponse != nil {
                gemmaAvail += 1
                gemmaViolations += c.nakedGemmaRedLineCount
            }
            if c.substrateOutputBody != nil {
                substrateAvail += 1
                substrateViolations +=
                    c.substrateRedLineCount
            }
        }
        return QinaoComparatorAggregate(
            totalPrompts: comparisons.count,
            nakedAFMTotalViolations: afmViolations,
            nakedGemmaTotalViolations: gemmaViolations,
            substrateTotalViolations: substrateViolations,
            nakedAFMAvailableCount: afmAvail,
            nakedGemmaAvailableCount: gemmaAvail,
            substrateOutputAvailableCount: substrateAvail)
    }
}

/// Comparator namespace. Pure-function helpers; running paths is
/// caller's responsibility (sample-host orchestrates AFM + MLX +
/// substrate calls then constructs comparisons).
public enum QinaoNakedVsSubstrateComparator {
    /// Build a comparison from raw inputs. Lint counting happens
    /// in caller via 5 lint helpers (BASBadToneLinter / etc) since
    /// QinaoLoop library doesn't have BAS deps.
    public static func makeComparison(
        prompt: String,
        nakedAFMResponse: String?,
        nakedGemmaResponse: String?,
        substrateAuditCodeCount: Int,
        substratePermitMode: String,
        substrateOutputBody: String?,
        nakedAFMRedLineCount: Int,
        nakedGemmaRedLineCount: Int,
        substrateRedLineCount: Int
    ) -> QinaoNakedVsSubstrateComparison {
        QinaoNakedVsSubstrateComparison(
            prompt: prompt,
            nakedAFMResponse: nakedAFMResponse,
            nakedGemmaResponse: nakedGemmaResponse,
            substrateAuditCodeCount: substrateAuditCodeCount,
            substratePermitMode: substratePermitMode,
            substrateOutputBody: substrateOutputBody,
            nakedAFMRedLineCount: nakedAFMRedLineCount,
            nakedGemmaRedLineCount: nakedGemmaRedLineCount,
            substrateRedLineCount: substrateRedLineCount)
    }

    /// Format a comparison as ASCII table row for sample-host
    /// stdout. Stable shape for cross-run reproducibility.
    public static func formatRow(
        _ c: QinaoNakedVsSubstrateComparison
    ) -> String {
        let promptPreview = String(c.prompt.prefix(60))
        let afm = c.nakedAFMResponse != nil
            ? "✓ (\(c.nakedAFMRedLineCount) RLs)"
            : "skip"
        let gemma = c.nakedGemmaResponse != nil
            ? "✓ (\(c.nakedGemmaRedLineCount) RLs)"
            : "skip"
        let substrate = c.substrateOutputBody != nil
            ? "✓ (\(c.substrateRedLineCount) RLs, \(c.substrateAuditCodeCount) codes, permit:\(c.substratePermitMode))"
            : "no body (\(c.substrateAuditCodeCount) codes, permit:\(c.substratePermitMode))"
        return """
              prompt: \(promptPreview)...
              naked AFM:    \(afm)
              naked Gemma:  \(gemma)
              substrate:    \(substrate)
            """
    }
}
