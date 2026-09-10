import Foundation

// 五十八.2 — typed AI-drafting helper for L4 candidate templates.
//
// ## Why this exists
//
// `BASWorldPriorStarterCurriculum` (M296.x) ship 了 50 条
// AI-drafted illustrative starter templates。它们都是 **手写
// 的 in-source content**——repo 已 ship 50 条，要再加更多需要
// 复制现有 case 风格手写。
//
// `BASWorldPriorAIDraftHelper` ship typed scaffolding for
// **AFM-assisted drafting**：让真模型起草 candidate templates
// 给 host / domain expert 审。**Doctrine A 不被违反**：
// AI-drafted candidate **provenance 永远 `.illustrative`**——
// 等 expert 走 typed authoring track 的 `.approveDomain` 才
// 升级到 `.domainExpertReviewed`。AFM 起草，人审。
//
// ## Doctrine
//
// - **AFM never produces `.domainExpertReviewed` content.** AI
//   起草的 candidate envelope 一律 `.illustrative`，typed-blocked
//   from training filter (M295.2)。
// - **Pure helpers.** This file has no organ-endpoint
//   dependency, no async surface, no LLM call. The TDD path is
//   "given prompt text, given LLM reply text, what
//   `BASWorldPriorTemplateAcceptance.Input`?"
// - **Mirrors M289 `QinaoLoop+TriSelfFromLLM` pattern** —
//   prompt builder + parser are pure deterministic helpers;
//   wiring through an organ endpoint is host territory.
// - **Parser fail-closed.** When LLM output can't be parsed
//   into a valid Input shape, parser returns nil; caller
//   decides whether to retry / re-prompt / hand-author.

public enum BASWorldPriorAIDraftHelper {

    /// Build a draft prompt for AFM. Asks the model to draft
    /// one candidate template in a structured line-oriented
    /// format the parser reads back.
    ///
    /// `domain` and `theme` shape the request; `referenceID`
    /// is included as a stylistic anchor (e.g., a known good
    /// starter template ID).
    public static func makeDraftPrompt(
        domain: String,
        theme: String,
        referenceID: String? = nil
    ) -> String {
        var lines: [String] = [
            """
            You are drafting one candidate causal template for an L4 \
            world prior curriculum. The template will be reviewed by \
            a human domain expert before being used. Reply in this \
            exact line-oriented format so the parser can read it:
            """,
            "",
            "TEMPLATE_ID: tmpl-\(domain)-<short-name>",
            "DESCRIPTION: <30+ char human-readable summary>",
            "PERTURB_KINDS: <comma-separated, ≥ 1 of: " +
                "dropPrecondition, introduceBlocker, " +
                "crossDomain, weakenEvidence, " +
                "amplifyContradiction>",
            "EVIDENCE_RUNGS: <comma-separated integers in 0..4>",
            "",
            "DOMAIN: \(domain)",
            "THEME: \(theme)",
        ]
        if let referenceID {
            lines.append(
                "STYLE_REFERENCE: \(referenceID)")
        }
        lines.append("")
        lines.append(
            "Draft one template now in the format above.")
        return lines.joined(separator: "\n")
    }

    /// Parse AFM reply into a typed Input. Returns nil if any
    /// required field is missing or unparseable.
    public static func parseDraft(
        from reply: String
    ) -> BASWorldPriorTemplateAcceptance.Input? {
        let lines = reply.components(separatedBy: "\n")
        var templateID: String?
        var description: String?
        var perturbKinds: Set<String>?
        var evidenceRungs: [Int]?

        for line in lines {
            let trimmed = line.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if let v = extract(
                "TEMPLATE_ID:", from: trimmed)
            {
                templateID = v
            } else if let v = extract(
                "DESCRIPTION:", from: trimmed)
            {
                description = v
            } else if let v = extract(
                "PERTURB_KINDS:", from: trimmed)
            {
                let parts = v.split(separator: ",")
                    .map {
                        String($0).trimmingCharacters(
                            in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                perturbKinds = Set(parts)
            } else if let v = extract(
                "EVIDENCE_RUNGS:", from: trimmed)
            {
                let parts = v.split(separator: ",")
                    .compactMap {
                        Int(
                            String($0).trimmingCharacters(
                                in: .whitespacesAndNewlines))
                    }
                evidenceRungs = parts
            }
        }

        guard
            let templateID,
            let description,
            let perturbKinds,
            !perturbKinds.isEmpty,
            let evidenceRungs,
            !evidenceRungs.isEmpty
        else {
            return nil
        }
        return BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: perturbKinds,
            branchEvidenceRungs: evidenceRungs,
            description: description)
    }

    /// Wrap a parsed AI draft into a `.illustrative` envelope +
    /// fresh `.draft` authoring session. Doctrine: AI drafts
    /// always start `.illustrative` / `.draft` regardless of
    /// what the LLM thinks the provenance should be.
    ///
    /// Returns nil if the input fails M295.0 acceptance.
    public static func wrapAsDraft(
        _ input: BASWorldPriorTemplateAcceptance.Input
    ) -> (
        envelope: BASWorldPriorTemplateEnvelope,
        session: BASWorldPriorTemplateAuthoringSession
    )? {
        guard
            BASWorldPriorTemplateAcceptance
                .isAcceptable(input)
        else {
            return nil
        }
        let envelope = BASWorldPriorTemplateEnvelope(
            input: input,
            provenance: .illustrative)
        let session = BASWorldPriorTemplateAuthoringSession(
            templateID: input.templateID,
            currentStage: .draft,
            history: [])
        return (envelope, session)
    }

    // MARK: - Private helpers

    private static func extract(
        _ prefix: String, from line: String
    ) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let value = line
            .dropFirst(prefix.count)
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : String(value)
    }
}
