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
    /// against the 6-item checklist. **Tightened format
    /// (六十八)**: explicit "no preamble", "no markdown",
    /// "fill in this template verbatim" — improves AFM
    /// compliance on the line-oriented format.
    public static func makeReviewPrompt(
        for envelope: BASWorldPriorTemplateEnvelope
    ) -> String {
        let input = envelope.input
        let kinds = input.perturbKindsCovered
            .sorted().joined(separator: ", ")
        let rungs = input.branchEvidenceRungs
            .map(String.init).joined(separator: ", ")
        return """
            Review this L4 causal-template candidate. Reply \
            using ONLY the template below. No preamble. No \
            markdown. Replace `<...>` placeholders only.

            CANDIDATE
            - templateID: \(input.templateID)
            - description: \(input.description)
            - perturb kinds: \(kinds)
            - branch evidence rungs: \(rungs)

            REPLY (fill in exactly):
            CHECK_1: <PASS or FAIL> - <comment>
            CHECK_2: <PASS or FAIL> - <comment>
            CHECK_3: <PASS or FAIL> - <comment>
            CHECK_4: <PASS or FAIL> - <comment>
            CHECK_5: <PASS or FAIL> - <comment>
            CHECK_6: <PASS or FAIL> - <comment>
            RECOMMENDATION: <approveSuggested or rejectSuggested or needsExpertJudgment>
            JUSTIFICATION: <one short sentence>

            CHECKLIST KEY:
            1. templateID follows `tmpl-<domain>-<name>`
            2. description ≥ 30 chars + human-readable
            3. perturb kinds cover counterfactual failure modes
            4. branch evidence rungs match literature support
            5. cross-template / cross-domain consistent
            6. no cultural blindspot or bias
            """
    }

    /// Parse AFM reply into a typed report. Returns nil if
    /// any required field is missing or unparseable.
    ///
    /// **Robustness** (六十八.1):
    /// - Tolerates duplicate `CHECK_n` lines — last-write-wins
    ///   (AFM occasionally echoes the prompt format then
    ///   provides the actual answer)
    /// - Word-boundary PASS/FAIL detection — `PASSAT` wouldn't
    ///   parse as PASS (prefix check uses regex word boundary)
    /// - Em-dash / en-dash / ASCII hyphen / colon all work
    ///   as separator; em-dash preferred if present
    /// - Reject takes priority over approve when both words
    ///   appear in recommendation line (defensive: "reject
    ///   because not approve-worthy" should classify as reject)
    public static func parseReviewReport(
        from reply: String,
        templateID: String
    ) -> BASWorldPriorAIReviewReport? {
        // Preprocess: strip markdown fences (```...```) if
        // AFM wrapped the reply in them. Also strip leading
        // prose like "Here's my review:" — parser iterates
        // all lines anyway, but stripping fences is safer.
        let preprocessed = stripMarkdownFences(reply)
        let lines = preprocessed.components(
            separatedBy: "\n")
        // Use dictionary keyed on index to dedupe (last-write-wins).
        var checksByIndex: [
            Int: BASWorldPriorAIChecklistResult
        ] = [:]
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
                    let passed = isPassToken(body)
                    let comment = extractComment(
                        afterPassFail: body)
                    // last-write-wins.
                    checksByIndex[index] =
                        BASWorldPriorAIChecklistResult(
                            item: item,
                            pass: passed,
                            comment: comment)
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

        // Reconstruct check list in canonical order.
        let checks = mapping.compactMap { (index, _) in
            checksByIndex[index]
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

    /// Strip markdown code fences from AFM reply. AFM
    /// sometimes wraps structured output in ```text ... ```
    /// fences. Returns the body between fences if present;
    /// otherwise the original reply.
    private static func stripMarkdownFences(
        _ reply: String
    ) -> String {
        let lines = reply.components(separatedBy: "\n")
        var inside = false
        var collected: [String] = []
        var sawFence = false
        for line in lines {
            let trimmed = line.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                if inside {
                    inside = false
                    sawFence = true
                    break
                } else {
                    inside = true
                    sawFence = true
                    continue
                }
            }
            if inside {
                collected.append(line)
            }
        }
        if sawFence && !collected.isEmpty {
            return collected.joined(separator: "\n")
        }
        return reply
    }

    /// Word-boundary PASS detection. Avoids `PASSAT` ⇒ PASS
    /// false positive. Returns true iff body's first word
    /// (uppercased) is exactly "PASS".
    private static func isPassToken(_ body: String) -> Bool {
        let upper = body.uppercased()
        // First non-whitespace token.
        let firstWord = upper.split(
            whereSeparator: {
                $0.isWhitespace
                    || $0 == ":" || $0 == "—"
                    || $0 == "-" || $0 == "–"
                    || $0 == ","
            }
        ).first.map(String.init) ?? ""
        return firstWord == "PASS"
    }

    private static func extractComment(
        afterPassFail body: String
    ) -> String {
        // body starts with PASS or FAIL; comment is what
        // follows after the FIRST separator. Em-dash takes
        // priority over ASCII hyphen — typical AFM-output
        // pattern is "PASS — short note", but ASCII fallback
        // is needed since some AFM responses use plain `-`.
        // Order: em-dash → en-dash → colon → ASCII hyphen.
        let priority: [Character] = ["—", "–", ":", "-"]
        for sep in priority {
            if let idx = body.firstIndex(of: sep) {
                let after = body[
                    body.index(after: idx)...
                ]
                let comment = String(after)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines)
                if !comment.isEmpty {
                    return comment
                }
            }
        }
        return ""
    }

    private static func parseRecommendation(
        _ s: String
    ) -> BASWorldPriorAIRecommendation? {
        let lower = s.lowercased()
        // **Order matters**: reject before approve to
        // defend against AFM saying "reject because not
        // approve-worthy" — would mis-classify as approve
        // under naive substring order. Reject takes
        // priority. expert/judgment last.
        if lower.contains("reject") {
            return .rejectSuggested
        }
        if lower.contains("approve") {
            return .approveSuggested
        }
        if lower.contains("expert")
            || lower.contains("judg")
        {
            return .needsExpertJudgment
        }
        return nil
    }
}
