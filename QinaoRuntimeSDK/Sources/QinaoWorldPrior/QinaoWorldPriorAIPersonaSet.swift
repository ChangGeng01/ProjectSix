import Foundation

// 六十六.2 — typed AI persona set for multi-perspective
// review simulation.
//
// ## Why this exists
//
// 五个 starter domain (relationship-conflict / decision-
// uncertainty / time-pressure / boundary-negotiation /
// cross-domain-analogy) each ideally needs its own real
// domain expert. While waiting for real reviewers (W1-W2),
// AFM 可以 simulate 5 个 persona — each prompted to think
// like the corresponding domain expert — to give a
// **multi-perspective preview**: 5 视角同看一条 candidate，
// 哪条跨域稳 / 哪条狭。
//
// 六十六.2 ships the typed persona set + prompt builders.
// Persona reviews are **always `.illustrative`**——AI
// review never produces `.domainExpertReviewed`. Used as:
//
// 1. **Worked-examples generator** — extend
//    [REVIEWER_SAMPLES.md](../../../docs/REVIEWER_SAMPLES.md)
//    from 5 hand-written examples to 50+ AFM-generated
// 2. **Host-side preview** before sending to real expert
// 3. **Training onboarding** — show real reviewer the
//    multi-domain take so they're prepared
//
// ## Doctrine
//
// - **5 persona enum, 5 domain mapping.** Cardinality typed.
// - **Each persona has a stable system-prompt prefix.**
//   Reproducible AFM behavior across runs.
// - **Persona review never promotes provenance.** Same
//   Doctrine A pin as `BASWorldPriorAIReviewerSimulation`.

public enum BASWorldPriorAIPersona:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 婚恋治疗师 / 家庭咨询师 — relationship conflict.
    case relationshipTherapist
    /// 决策科学家 / 行为经济学家 — decision uncertainty.
    case decisionScientist
    /// 时间管理研究者 / 认知心理学家 — time pressure.
    case timeResearcher
    /// Assertiveness coach / OD 顾问 — boundary negotiation.
    case boundaryCoach
    /// 认知语言学家 / 教育研究者 — cross-domain analogy.
    case cognitiveLinguist
}

public extension BASWorldPriorAIPersona {
    /// The starter-curriculum domain string this persona
    /// canonically reviews (matches `tmpl-<domain>-...`).
    var canonicalDomain: String {
        switch self {
        case .relationshipTherapist:
            return "relationship"
        case .decisionScientist:
            return "decision"
        case .timeResearcher:
            return "time"
        case .boundaryCoach:
            return "boundary"
        case .cognitiveLinguist:
            return "analogy"
        }
    }

    /// Short human-readable description.
    var domainLabel: String {
        switch self {
        case .relationshipTherapist:
            return "relationship conflict"
        case .decisionScientist:
            return "decision uncertainty"
        case .timeResearcher:
            return "time pressure"
        case .boundaryCoach:
            return "boundary negotiation"
        case .cognitiveLinguist:
            return "cross-domain analogy"
        }
    }

    /// Stable system-prompt prefix that conditions AFM to
    /// answer from this persona.
    var personaPrompt: String {
        switch self {
        case .relationshipTherapist:
            return """
                You are reviewing as a couples therapist with \
                10+ years of clinical practice. You care about \
                long-term relational trust, attachment dynamics, \
                and repair after conflict.
                """
        case .decisionScientist:
            return """
                You are reviewing as a decision scientist trained \
                in behavioral economics and judgment under \
                uncertainty. You care about default biases, \
                base-rate neglect, and frame effects.
                """
        case .timeResearcher:
            return """
                You are reviewing as a cognitive psychologist \
                specializing in time perception and cognitive \
                load under time pressure. You care about \
                working-memory effects and prospect-shifting.
                """
        case .boundaryCoach:
            return """
                You are reviewing as an assertiveness coach / \
                organizational-development consultant. You care \
                about clear boundary articulation, declining \
                without aggression, and post-decline relational repair.
                """
        case .cognitiveLinguist:
            return """
                You are reviewing as a cognitive linguist working \
                on conceptual metaphor + cross-domain mapping \
                (Lakoff / Fauconnier tradition). You care about \
                analogy fidelity, source-target mismatch, and \
                metaphor coherence.
                """
        }
    }
}

// MARK: - Per-persona review

public struct BASWorldPriorAIPersonaReview:
    Sendable, Equatable, Hashable, Codable
{
    public let persona: BASWorldPriorAIPersona
    public let templateID: String
    public let recommendation:
        BASWorldPriorAIRecommendation
    public let domainSpecificComment: String
    public let citedConcepts: [String]

    public init(
        persona: BASWorldPriorAIPersona,
        templateID: String,
        recommendation:
            BASWorldPriorAIRecommendation,
        domainSpecificComment: String,
        citedConcepts: [String]
    ) {
        self.persona = persona
        self.templateID = templateID
        self.recommendation = recommendation
        self.domainSpecificComment =
            domainSpecificComment
        self.citedConcepts = citedConcepts
    }
}

// MARK: - Multi-persona aggregate

public struct BASWorldPriorAIPersonaPanelReview:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let perPersona: [
        BASWorldPriorAIPersonaReview
    ]

    public init(
        templateID: String,
        perPersona: [
            BASWorldPriorAIPersonaReview
        ]
    ) {
        self.templateID = templateID
        self.perPersona = perPersona
    }

    /// Convenience — count of persona that suggested approve.
    public var approveSuggestedCount: Int {
        perPersona.filter {
            $0.recommendation == .approveSuggested
        }.count
    }

    public var rejectSuggestedCount: Int {
        perPersona.filter {
            $0.recommendation == .rejectSuggested
        }.count
    }

    /// Returns true iff all reviewing persona suggested approve.
    public var allApproveSuggested: Bool {
        !perPersona.isEmpty
            && approveSuggestedCount
                == perPersona.count
    }
}

// MARK: - Helper

public enum BASWorldPriorAIPersonaReviewer {

    /// Build a prompt for one persona reviewing one
    /// candidate.
    public static func makePersonaReviewPrompt(
        persona: BASWorldPriorAIPersona,
        envelope: BASWorldPriorTemplateEnvelope
    ) -> String {
        let input = envelope.input
        return """
            \(persona.personaPrompt)

            REVIEW THIS CANDIDATE
            - templateID: \(input.templateID)
            - description: \(input.description)

            Answer in this exact format:

            RECOMMENDATION: approveSuggested | rejectSuggested | needsExpertJudgment
            DOMAIN_COMMENT: <one or two sentences from your domain expertise>
            CITED_CONCEPTS: <comma-separated list of 1-3 concepts you applied; can be empty>
            """
    }

    /// Parse AFM reply into a typed persona review.
    /// Returns nil if any required field is missing.
    public static func parsePersonaReview(
        from reply: String,
        persona: BASWorldPriorAIPersona,
        templateID: String
    ) -> BASWorldPriorAIPersonaReview? {
        let lines = reply.components(separatedBy: "\n")
        var rec: BASWorldPriorAIRecommendation?
        var domainComment: String?
        var concepts: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if let v = extractAfterPrefix(
                "RECOMMENDATION:",
                from: trimmed)
            {
                rec = parseRecommendation(v)
            } else if let v = extractAfterPrefix(
                "DOMAIN_COMMENT:",
                from: trimmed)
            {
                domainComment = v
            } else if let v = extractAfterPrefix(
                "CITED_CONCEPTS:",
                from: trimmed)
            {
                concepts = v.split(separator: ",")
                    .map {
                        String($0)
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
            }
        }

        guard let rec,
              let domainComment,
              !domainComment.isEmpty
        else { return nil }

        return BASWorldPriorAIPersonaReview(
            persona: persona,
            templateID: templateID,
            recommendation: rec,
            domainSpecificComment: domainComment,
            citedConcepts: concepts)
    }

    /// Aggregate per-persona reviews into a panel review.
    public static func makePanelReview(
        templateID: String,
        reviews: [
            BASWorldPriorAIPersonaReview
        ]
    ) -> BASWorldPriorAIPersonaPanelReview {
        BASWorldPriorAIPersonaPanelReview(
            templateID: templateID,
            perPersona: reviews)
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

    /// Reject-over-approve precedence — same robustness
    /// pattern as `BASWorldPriorAIReviewerSimulation.parseRecommendation`.
    /// AFM saying "reject because not approve-worthy" must
    /// classify as reject, not approve.
    private static func parseRecommendation(
        _ s: String
    ) -> BASWorldPriorAIRecommendation? {
        let lower = s.lowercased()
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
