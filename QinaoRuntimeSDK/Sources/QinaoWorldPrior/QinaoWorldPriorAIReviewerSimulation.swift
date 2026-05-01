import Foundation

// 六十六.1 — typed AFM-driven first-pass reviewer simulation.
//
// ## Why this exists
//
// 五十八 ship 了 `BASWorldPriorAIDraftHelper` (AI 起草
// candidate). 六十一 ship 了 reviewer onboarding bundle +
// `BASWorldPriorReviewerBatch` (sessions → markdown for
// human reviewer). 但 host operator 把 candidate 送给真
// expert 之前，**没有 typed 工具让 AFM 先跑一遍 checklist**——
// 帮筛掉明显 doctrine 违规 + 给 expert 节省时间。
//
// 六十六.1 ships AFM-driven first-pass reviewer simulation.
// AFM 读 candidate + 跑 [REVIEWER_CHECKLIST.md](../../../docs/REVIEWER_CHECKLIST.md)
// 6 项；输出 typed report；**advisory 永远 `.illustrative`**——
// Doctrine A 物理 typed-pin。
//
// ## Doctrine
//
// - **Advisory only.** AI review NEVER produces
//   `.domainExpertReviewed`. Even if AFM says "approve",
//   the produced envelope stays at the original provenance
//   (typically `.illustrative`).
// - **Pure helpers.** prompt builder + parser, no organ
//   endpoint dependency. Mirrors M289 / M287 pattern.
// - **6 typed checklist items.** Match
//   REVIEWER_CHECKLIST.md A.1-A.4 + D + E.
// - **Parser fail-closed.** Malformed reply returns nil;
//   caller decides retry / fall back to manual.

// MARK: - Typed checklist

public enum BASWorldPriorReviewChecklistItem:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// templateID 命名 `tmpl-<域>-<名>` + 唯一
    case templateIDFormat
    /// description ≥ 30 字 + 说人话
    case descriptionLength
    /// perturbKindsCovered 覆盖典型反事实失败模式
    case perturbKindsCovered
    /// branchEvidenceRungs 与文献等级匹配
    case evidenceRungsAlignment
    /// 跨模板 / 跨域一致性
    case crossTemplateConsistency
    /// 无明显文化盲点 / 偏见
    case noBiasOrCulturalBlindspot
}

// MARK: - Typed report shape

public struct BASWorldPriorAIChecklistResult:
    Sendable, Equatable, Hashable, Codable
{
    public let item: BASWorldPriorReviewChecklistItem
    public let pass: Bool
    public let comment: String

    public init(
        item: BASWorldPriorReviewChecklistItem,
        pass: Bool,
        comment: String
    ) {
        self.item = item
        self.pass = pass
        self.comment = comment
    }
}

public enum BASWorldPriorAIRecommendation:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// AFM 觉得这条值得 expert approve。
    /// **不等于 approved**——expert 必审才升级 provenance。
    case approveSuggested
    /// AFM 觉得这条该 reject。
    case rejectSuggested
    /// AFM 拿不定，expert 必看。
    case needsExpertJudgment
}

public struct BASWorldPriorAIReviewReport:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let checklistResults: [
        BASWorldPriorAIChecklistResult
    ]
    public let overallRecommendation:
        BASWorldPriorAIRecommendation
    public let justification: String

    public init(
        templateID: String,
        checklistResults: [
            BASWorldPriorAIChecklistResult
        ],
        overallRecommendation:
            BASWorldPriorAIRecommendation,
        justification: String
    ) {
        self.templateID = templateID
        self.checklistResults = checklistResults
        self.overallRecommendation =
            overallRecommendation
        self.justification = justification
    }

    /// Convenience — passing rate of checklist.
    public var passRate: Double {
        guard !checklistResults.isEmpty else { return 0 }
        let passed = checklistResults.filter(\.pass).count
        return Double(passed)
            / Double(checklistResults.count)
    }
}

/// **Doctrine A pinned**: an AI advisory NEVER promotes
/// envelope provenance. The advisory carries the AFM report
/// alongside the envelope; envelope provenance stays
/// whatever the caller passed in (typically `.illustrative`).
public struct BASWorldPriorAIReviewAdvisory:
    Sendable, Equatable, Hashable, Codable
{
    public let report: BASWorldPriorAIReviewReport
    public let envelope: BASWorldPriorTemplateEnvelope

    public init(
        report: BASWorldPriorAIReviewReport,
        envelope: BASWorldPriorTemplateEnvelope
    ) {
        self.report = report
        self.envelope = envelope
    }

    /// **Doctrine A typed pin**: producedEnvelope is
    /// envelope unchanged. AI advisory never promotes
    /// provenance.
    public var producedEnvelope:
        BASWorldPriorTemplateEnvelope
    {
        envelope
    }
}

// MARK: - Helper

public enum BASWorldPriorAIReviewerSimulation {

    /// Build a prompt asking AFM to review a candidate
    /// against the 6-item checklist.
    public static func makeReviewPrompt(
        for envelope: BASWorldPriorTemplateEnvelope
    ) -> String {
        let input = envelope.input
        let kinds = input.perturbKindsCovered
            .sorted().joined(separator: ", ")
        let rungs = input.branchEvidenceRungs
            .map(String.init).joined(separator: ", ")
        return """
            You are reviewing one L4 causal-template candidate \
            for an AI second brain. Run the 6-item checklist \
            below and return ONLY the structured format \
            specified at the end.

            CANDIDATE
            - templateID: \(input.templateID)
            - description: \(input.description)
            - perturb kinds: \(kinds)
            - branch evidence rungs: \(rungs)

            CHECKLIST
            1. templateID follows `tmpl-<domain>-<name>` and is non-empty
            2. description ≥ 30 chars and reads as human language
            3. perturb kinds cover typical counterfactual failure modes
            4. branch evidence rungs match literature support level
            5. cross-template / cross-domain consistent (no obvious dup)
            6. no obvious cultural blindspot / bias

            REPLY FORMAT (LINE-ORIENTED, EXACT)
            CHECK_1: PASS | FAIL — short comment
            CHECK_2: PASS | FAIL — short comment
            CHECK_3: PASS | FAIL — short comment
            CHECK_4: PASS | FAIL — short comment
            CHECK_5: PASS | FAIL — short comment
            CHECK_6: PASS | FAIL — short comment
            RECOMMENDATION: approveSuggested | rejectSuggested | needsExpertJudgment
            JUSTIFICATION: <one short sentence on why>
            """
    }

    /// Parse AFM reply into a typed report. Returns nil if
    /// any required field is missing or unparseable.
    public static func parseReviewReport(
        from reply: String,
        templateID: String
    ) -> BASWorldPriorAIReviewReport? {
        let lines = reply.components(separatedBy: "\n")
        var checks: [
            BASWorldPriorAIChecklistResult
        ] = []
        var rec: BASWorldPriorAIRecommendation?
        var justification: String?

        let mapping: [
            (Int, BASWorldPriorReviewChecklistItem)
        ] = [
            (1, .templateIDFormat),
            (2, .descriptionLength),
            (3, .perturbKindsCovered),
            (4, .evidenceRungsAlignment),
            (5, .crossTemplateConsistency),
            (6, .noBiasOrCulturalBlindspot),
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(
                in: .whitespacesAndNewlines)
            for (index, item) in mapping {
                let prefix = "CHECK_\(index):"
                if trimmed.hasPrefix(prefix) {
                    let body = String(
                        trimmed.dropFirst(
                            prefix.count)
                    ).trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    let passed = body.uppercased()
                        .hasPrefix("PASS")
                    let comment = extractComment(
                        afterPassFail: body)
                    checks.append(
                        BASWorldPriorAIChecklistResult(
                            item: item,
                            pass: passed,
                            comment: comment))
                }
            }
            if let v = extractAfterPrefix(
                "RECOMMENDATION:",
                from: trimmed)
            {
                rec = parseRecommendation(v)
            }
            if let v = extractAfterPrefix(
                "JUSTIFICATION:",
                from: trimmed)
            {
                justification = v
            }
        }

        guard checks.count == 6,
              let rec,
              let justification,
              !justification.isEmpty
        else { return nil }

        return BASWorldPriorAIReviewReport(
            templateID: templateID,
            checklistResults: checks,
            overallRecommendation: rec,
            justification: justification)
    }

    /// Wrap a parsed report into an advisory. Doctrine A
    /// pin: envelope provenance unchanged. AI advisory
    /// never promotes.
    public static func wrapAsAdvisory(
        report: BASWorldPriorAIReviewReport,
        envelope: BASWorldPriorTemplateEnvelope
    ) -> BASWorldPriorAIReviewAdvisory {
        BASWorldPriorAIReviewAdvisory(
            report: report, envelope: envelope)
    }

    // MARK: - Private

    private static func extractAfterPrefix(
        _ prefix: String, from line: String
    ) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let v = line.dropFirst(prefix.count)
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : String(v)
    }

    private static func extractComment(
        afterPassFail body: String
    ) -> String {
        // body starts with PASS or FAIL; comment is what
        // follows after `—` or `-` (allow ASCII or unicode).
        let separators: Set<Character> = ["—", "-", "–"]
        if let dashIndex = body.firstIndex(where: {
            separators.contains($0)
        }) {
            let after = body[
                body.index(after: dashIndex)...
            ]
            return String(after).trimmingCharacters(
                in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func parseRecommendation(
        _ s: String
    ) -> BASWorldPriorAIRecommendation? {
        let lower = s.lowercased()
        if lower.contains("approve") {
            return .approveSuggested
        }
        if lower.contains("reject") {
            return .rejectSuggested
        }
        if lower.contains("expert")
            || lower.contains("judg")
        {
            return .needsExpertJudgment
        }
        return nil
    }
}
