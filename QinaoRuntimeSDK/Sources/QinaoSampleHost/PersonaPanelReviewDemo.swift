import Foundation
import BASOrgan
import BASAppleAdapters
import BASRuntimeCore
import QinaoLoop
import QinaoWorldPrior

/// M326 — AI persona panel review demo.
///
/// Runs `BASWorldPriorAIPersonaReviewer` against a representative
/// sample of `BASWorldPriorStarterCurriculum.allTemplates` (Path
/// A 50 illustrative entries) using Apple Foundation Models on
/// device. For each (template × persona) pair we send the
/// persona-conditioned prompt, parse the structured AFM reply
/// into `BASWorldPriorAIPersonaReview`, and aggregate into
/// `BASWorldPriorAIPersonaPanelReview`.
///
/// This is the M295.1 AI advisory pre-review path the white
/// paper §54 describes. **Doctrine A pin: persona panel
/// consensus does NOT promote envelope provenance.** Reviews
/// stay `.illustrative` regardless of outcome — the typed
/// pipeline (`BASWorldPriorTrainingPipelineFilter`) physically
/// blocks promotion to `.domainExpertReviewed` without a real
/// human domain expert sign-off.
///
/// ## Usage
///
/// ```bash
/// QINAO_AFM_PANEL_REVIEW=1 \
///   swift run QinaoSampleHost --persona-panel-review
/// QINAO_AFM_PANEL_REVIEW=1 QINAO_PANEL_COUNT=10 \
///   swift run QinaoSampleHost --persona-panel-review
/// ```
///
/// `QINAO_PANEL_COUNT` selects how many starter templates to
/// review; default 5 (one per domain). Max 50 (full curriculum
/// run takes several minutes).
public struct PersonaPanelReviewDemo {

    public struct PersonaCallRecord: Sendable, Equatable {
        public let templateID: String
        public let persona: String
        public let recommendation: String
        public let domainComment: String
        public let citedConcepts: [String]
        public let parseSucceeded: Bool

        public init(
            templateID: String,
            persona: String,
            recommendation: String,
            domainComment: String,
            citedConcepts: [String],
            parseSucceeded: Bool
        ) {
            self.templateID = templateID
            self.persona = persona
            self.recommendation = recommendation
            self.domainComment = domainComment
            self.citedConcepts = citedConcepts
            self.parseSucceeded = parseSucceeded
        }
    }

    public struct TemplateOutcome: Sendable, Equatable {
        public let templateID: String
        public let perPersona: [PersonaCallRecord]
        public let approveSuggestedCount: Int
        public let rejectSuggestedCount: Int
        public let needsExpertJudgmentCount: Int

        public init(
            templateID: String,
            perPersona: [PersonaCallRecord],
            approveSuggestedCount: Int,
            rejectSuggestedCount: Int,
            needsExpertJudgmentCount: Int
        ) {
            self.templateID = templateID
            self.perPersona = perPersona
            self.approveSuggestedCount = approveSuggestedCount
            self.rejectSuggestedCount = rejectSuggestedCount
            self.needsExpertJudgmentCount = needsExpertJudgmentCount
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let totalTemplates: Int
        public let totalCalls: Int
        public let parseSuccessCount: Int
        public let elapsedSeconds: Double
        public let outcomes: [TemplateOutcome]

        public init(
            totalTemplates: Int,
            totalCalls: Int,
            parseSuccessCount: Int,
            elapsedSeconds: Double,
            outcomes: [TemplateOutcome]
        ) {
            self.totalTemplates = totalTemplates
            self.totalCalls = totalCalls
            self.parseSuccessCount = parseSuccessCount
            self.elapsedSeconds = elapsedSeconds
            self.outcomes = outcomes
        }
    }

    /// Pick `count` representative templates — one per starter
    /// domain first, then fill remaining slots from
    /// `allTemplates` in order.
    public static func selectTemplates(
        count: Int
    ) -> [BASWorldPriorTemplateAcceptance.Input] {
        let all = BASWorldPriorStarterCurriculum.allTemplates
        let domains = [
            "relationship", "decision", "time",
            "boundary", "analogy",
        ]
        var picked: [BASWorldPriorTemplateAcceptance.Input] = []
        var pickedIDs: Set<String> = []
        // Round-robin domain coverage: first pass picks 1 per
        // domain, second pass picks 2 per domain, etc., until
        // `count` is reached. Uses `tmpl-<domain>-` prefix
        // match so e.g. `tmpl-decision-time-horizon` doesn't
        // accidentally satisfy the "time" domain query.
        outer: while picked.count < count {
            var addedThisPass = 0
            for domain in domains {
                let candidates = all.filter {
                    $0.templateID.hasPrefix(
                        "tmpl-\(domain)-")
                        && !pickedIDs.contains(
                            $0.templateID)
                }
                if let pick = candidates.first {
                    picked.append(pick)
                    pickedIDs.insert(pick.templateID)
                    addedThisPass += 1
                    if picked.count >= count { break outer }
                }
            }
            if addedThisPass == 0 { break }
        }
        return Array(picked.prefix(count))
    }

    /// Run the panel against a sample of starter templates via
    /// real Apple Foundation Models.
    public static func run(
        count: Int = 5
    ) async throws -> Outcome {
        let templates = selectTemplates(count: count)
        let adapter = AppleFoundationOrganAdapter()

        let started = ContinuousClock().now
        var outcomes: [TemplateOutcome] = []
        var totalCalls = 0
        var parseSuccess = 0

        for template in templates {
            let envelope = BASWorldPriorTemplateEnvelope(
                input: template,
                provenance: .illustrative)
            var perPersona: [PersonaCallRecord] = []
            for persona in BASWorldPriorAIPersona.allCases {
                let prompt =
                    BASWorldPriorAIPersonaReviewer
                        .makePersonaReviewPrompt(
                            persona: persona,
                            envelope: envelope)
                let request = BASOrganRequest(
                    requestID: UUID().uuidString,
                    role: .core,
                    preset: .core,
                    instruction: prompt,
                    context: [])
                totalCalls += 1
                do {
                    let draft = try await adapter.draft(
                        request)
                    let parsed =
                        BASWorldPriorAIPersonaReviewer
                            .parsePersonaReview(
                                from: draft.body,
                                persona: persona,
                                templateID: template.templateID)
                    if let parsed {
                        parseSuccess += 1
                        perPersona.append(
                            PersonaCallRecord(
                                templateID: template.templateID,
                                persona: persona.rawValue,
                                recommendation:
                                    parsed.recommendation
                                        .rawValue,
                                domainComment:
                                    parsed
                                        .domainSpecificComment,
                                citedConcepts:
                                    parsed.citedConcepts,
                                parseSucceeded: true))
                    } else {
                        perPersona.append(
                            PersonaCallRecord(
                                templateID: template.templateID,
                                persona: persona.rawValue,
                                recommendation: "PARSE_FAILED",
                                domainComment: String(
                                    draft.body.prefix(160)),
                                citedConcepts: [],
                                parseSucceeded: false))
                    }
                } catch {
                    perPersona.append(
                        PersonaCallRecord(
                            templateID: template.templateID,
                            persona: persona.rawValue,
                            recommendation: "ERROR",
                            domainComment: "\(error)",
                            citedConcepts: [],
                            parseSucceeded: false))
                }
            }
            let approve = perPersona.filter {
                $0.recommendation == "approveSuggested"
            }.count
            let reject = perPersona.filter {
                $0.recommendation == "rejectSuggested"
            }.count
            let needs = perPersona.filter {
                $0.recommendation == "needsExpertJudgment"
            }.count
            outcomes.append(
                TemplateOutcome(
                    templateID: template.templateID,
                    perPersona: perPersona,
                    approveSuggestedCount: approve,
                    rejectSuggestedCount: reject,
                    needsExpertJudgmentCount: needs))
        }
        let elapsed = ContinuousClock().now - started
        let elapsedSeconds = elapsed.toMilliseconds() / 1000.0

        return Outcome(
            totalTemplates: templates.count,
            totalCalls: totalCalls,
            parseSuccessCount: parseSuccess,
            elapsedSeconds: elapsedSeconds,
            outcomes: outcomes)
    }
}

private extension Duration {
    func toMilliseconds() -> Double {
        let comps = self.components
        return Double(comps.seconds) * 1000.0
            + Double(comps.attoseconds) / 1.0e15
    }
}
