import XCTest
@testable import QinaoWorldPrior

/// 六十六.2 — AI persona set unit tests (no AFM).
final class QinaoWorldPriorAIPersonaSetTests: XCTestCase {

    private func goodInput(
        templateID: String = "tmpl-relationship-test"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Persona set test description ≥ 30 chars.")
    }

    private func envelope(
        templateID: String = "tmpl-relationship-test"
    ) -> BASWorldPriorTemplateEnvelope {
        BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: templateID),
            provenance: .illustrative)
    }

    // MARK: - Cardinality

    func test_fivePersona() {
        XCTAssertEqual(
            BASWorldPriorAIPersona.allCases.count, 5)
    }

    // MARK: - Domain mapping

    func test_canonicalDomainsMatchStarterCurriculum() {
        XCTAssertEqual(
            BASWorldPriorAIPersona
                .relationshipTherapist
                .canonicalDomain,
            "relationship")
        XCTAssertEqual(
            BASWorldPriorAIPersona.decisionScientist
                .canonicalDomain,
            "decision")
        XCTAssertEqual(
            BASWorldPriorAIPersona.timeResearcher
                .canonicalDomain,
            "time")
        XCTAssertEqual(
            BASWorldPriorAIPersona.boundaryCoach
                .canonicalDomain,
            "boundary")
        XCTAssertEqual(
            BASWorldPriorAIPersona.cognitiveLinguist
                .canonicalDomain,
            "analogy")
    }

    func test_personaPromptsNonEmpty() {
        for persona in
            BASWorldPriorAIPersona.allCases
        {
            XCTAssertFalse(
                persona.personaPrompt
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    .isEmpty)
        }
    }

    func test_personaLabelsDistinct() {
        let labels = BASWorldPriorAIPersona.allCases
            .map(\.domainLabel)
        XCTAssertEqual(Set(labels).count, 5)
    }

    // MARK: - Prompt construction

    func test_promptIncludesPersonaAndCandidate() {
        let env = envelope()
        let p =
            BASWorldPriorAIPersonaReviewer
                .makePersonaReviewPrompt(
                    persona:
                        .relationshipTherapist,
                    envelope: env)
        XCTAssertTrue(
            p.contains("couples therapist"))
        XCTAssertTrue(
            p.contains("tmpl-relationship-test"))
        XCTAssertTrue(
            p.contains("RECOMMENDATION:"))
        XCTAssertTrue(
            p.contains("DOMAIN_COMMENT:"))
        XCTAssertTrue(
            p.contains("CITED_CONCEPTS:"))
    }

    func test_promptDeterministic() {
        let env = envelope()
        let p1 = BASWorldPriorAIPersonaReviewer
            .makePersonaReviewPrompt(
                persona: .decisionScientist,
                envelope: env)
        let p2 = BASWorldPriorAIPersonaReviewer
            .makePersonaReviewPrompt(
                persona: .decisionScientist,
                envelope: env)
        XCTAssertEqual(p1, p2)
    }

    // MARK: - Parser: well-formed

    func test_parseWellFormed() throws {
        let reply = """
            RECOMMENDATION: approveSuggested
            DOMAIN_COMMENT: Captures the trust-repair dynamic well.
            CITED_CONCEPTS: Gottman 5:1 ratio, repair attempts
            """
        let review = try XCTUnwrap(
            BASWorldPriorAIPersonaReviewer
                .parsePersonaReview(
                    from: reply,
                    persona: .relationshipTherapist,
                    templateID: "tmpl-relationship-test"))
        XCTAssertEqual(
            review.persona,
            .relationshipTherapist)
        XCTAssertEqual(
            review.recommendation,
            .approveSuggested)
        XCTAssertTrue(
            review.domainSpecificComment
                .contains("trust-repair"))
        XCTAssertEqual(
            review.citedConcepts.count, 2)
    }

    // MARK: - Parser: malformed

    func test_parseMissingRecommendationReturnsNil() {
        let reply = """
            DOMAIN_COMMENT: short.
            CITED_CONCEPTS: x
            """
        XCTAssertNil(
            BASWorldPriorAIPersonaReviewer
                .parsePersonaReview(
                    from: reply,
                    persona: .timeResearcher,
                    templateID: "tmpl-time-x"))
    }

    func test_parseMissingDomainCommentReturnsNil() {
        let reply = """
            RECOMMENDATION: approveSuggested
            CITED_CONCEPTS: x
            """
        XCTAssertNil(
            BASWorldPriorAIPersonaReviewer
                .parsePersonaReview(
                    from: reply,
                    persona: .timeResearcher,
                    templateID: "tmpl-time-x"))
    }

    func test_parseEmptyConceptsAcceptable() throws {
        let reply = """
            RECOMMENDATION: rejectSuggested
            DOMAIN_COMMENT: Misses the key dimension.
            CITED_CONCEPTS:
            """
        let review = try XCTUnwrap(
            BASWorldPriorAIPersonaReviewer
                .parsePersonaReview(
                    from: reply,
                    persona: .boundaryCoach,
                    templateID: "tmpl-boundary-x"))
        XCTAssertEqual(
            review.citedConcepts, [])
    }

    // MARK: - Panel review aggregation

    func test_panelReviewCounts() {
        let reviews: [
            BASWorldPriorAIPersonaReview
        ] = [
            BASWorldPriorAIPersonaReview(
                persona: .relationshipTherapist,
                templateID: "tmpl-x-y",
                recommendation: .approveSuggested,
                domainSpecificComment: "ok",
                citedConcepts: []),
            BASWorldPriorAIPersonaReview(
                persona: .decisionScientist,
                templateID: "tmpl-x-y",
                recommendation: .approveSuggested,
                domainSpecificComment: "ok",
                citedConcepts: []),
            BASWorldPriorAIPersonaReview(
                persona: .timeResearcher,
                templateID: "tmpl-x-y",
                recommendation: .rejectSuggested,
                domainSpecificComment: "no",
                citedConcepts: []),
        ]
        let panel = BASWorldPriorAIPersonaReviewer
            .makePanelReview(
                templateID: "tmpl-x-y",
                reviews: reviews)
        XCTAssertEqual(panel.approveSuggestedCount, 2)
        XCTAssertEqual(panel.rejectSuggestedCount, 1)
        XCTAssertFalse(panel.allApproveSuggested)
    }

    func test_panelAllApproveSuggested() {
        let reviews =
            BASWorldPriorAIPersona.allCases.map {
                BASWorldPriorAIPersonaReview(
                    persona: $0,
                    templateID: "tmpl-x-y",
                    recommendation:
                        .approveSuggested,
                    domainSpecificComment: "ok",
                    citedConcepts: [])
            }
        let panel = BASWorldPriorAIPersonaReviewer
            .makePanelReview(
                templateID: "tmpl-x-y",
                reviews: reviews)
        XCTAssertTrue(panel.allApproveSuggested)
        XCTAssertEqual(
            panel.approveSuggestedCount, 5)
    }

    // MARK: - Codable

    func test_personaCodable() throws {
        for p in BASWorldPriorAIPersona.allCases {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorAIPersona.self, from: data)
            XCTAssertEqual(decoded, p)
        }
    }

    func test_panelCodable() throws {
        let panel =
            BASWorldPriorAIPersonaPanelReview(
                templateID: "tmpl-x-y",
                perPersona: [])
        let data = try JSONEncoder().encode(panel)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorAIPersonaPanelReview.self,
            from: data)
        XCTAssertEqual(decoded, panel)
    }
}
