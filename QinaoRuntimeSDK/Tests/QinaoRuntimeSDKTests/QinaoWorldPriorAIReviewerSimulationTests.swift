import XCTest
@testable import QinaoWorldPrior

/// 六十六.1 — AI reviewer simulation unit tests (no AFM).
final class QinaoWorldPriorAIReviewerSimulationTests:
    XCTestCase
{

    private func goodInput(
        templateID: String = "tmpl-test-rev"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Reviewer simulation test description ≥ 30 chars.")
    }

    private func envelope(
        provenance: BASWorldPriorTemplateProvenance =
            .illustrative
    ) -> BASWorldPriorTemplateEnvelope {
        BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: provenance)
    }

    // MARK: - Cardinality

    func test_sixChecklistItems() {
        XCTAssertEqual(
            BASWorldPriorReviewChecklistItem
                .allCases.count, 6)
    }

    func test_threeRecommendations() {
        XCTAssertEqual(
            BASWorldPriorAIRecommendation
                .allCases.count, 3)
    }

    // MARK: - Prompt

    func test_promptIncludesTemplateFields() {
        let p =
            BASWorldPriorAIReviewerSimulation
                .makeReviewPrompt(for: envelope())
        XCTAssertTrue(
            p.contains("tmpl-test-rev"))
        XCTAssertTrue(
            p.contains(
                "Reviewer simulation test description"))
        XCTAssertTrue(
            p.contains("dropPrecondition"))
        XCTAssertTrue(
            p.contains("CHECK_1"))
        XCTAssertTrue(
            p.contains("RECOMMENDATION:"))
        XCTAssertTrue(
            p.contains("JUSTIFICATION:"))
    }

    func test_promptDeterministic() {
        let p1 =
            BASWorldPriorAIReviewerSimulation
                .makeReviewPrompt(for: envelope())
        let p2 =
            BASWorldPriorAIReviewerSimulation
                .makeReviewPrompt(for: envelope())
        XCTAssertEqual(p1, p2)
    }

    // MARK: - Parser: well-formed

    func test_parseWellFormedReply() throws {
        let reply = """
            CHECK_1: PASS — id format ok
            CHECK_2: PASS — description adequate
            CHECK_3: FAIL — only one perturb kind
            CHECK_4: PASS — rungs match literature
            CHECK_5: PASS — no overlap
            CHECK_6: PASS — no bias detected
            RECOMMENDATION: needsExpertJudgment
            JUSTIFICATION: Description is fine but perturb coverage thin.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-test-rev"))
        XCTAssertEqual(
            report.templateID, "tmpl-test-rev")
        XCTAssertEqual(
            report.checklistResults.count, 6)
        XCTAssertEqual(
            report.overallRecommendation,
            .needsExpertJudgment)
        XCTAssertTrue(
            report.justification.contains(
                "perturb coverage thin"))
        let pass = report.checklistResults.filter(
            \.pass).count
        XCTAssertEqual(pass, 5)
        XCTAssertEqual(
            report.passRate, 5.0/6.0,
            accuracy: 1e-6)
    }

    // MARK: - Parser: malformed → nil

    func test_parseMissingChecksReturnsNil() {
        let reply = """
            CHECK_1: PASS — ok
            CHECK_2: PASS — ok
            RECOMMENDATION: approveSuggested
            JUSTIFICATION: looks ok.
            """
        XCTAssertNil(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-test-rev"))
    }

    func test_parseMissingRecommendationReturnsNil() {
        let reply = """
            CHECK_1: PASS — ok
            CHECK_2: PASS — ok
            CHECK_3: PASS — ok
            CHECK_4: PASS — ok
            CHECK_5: PASS — ok
            CHECK_6: PASS — ok
            JUSTIFICATION: ok.
            """
        XCTAssertNil(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-test-rev"))
    }

    // MARK: - Doctrine A: advisory does NOT promote provenance

    func test_advisoryWrapNeverPromotes() throws {
        let reply = """
            CHECK_1: PASS — ok
            CHECK_2: PASS — ok
            CHECK_3: PASS — ok
            CHECK_4: PASS — ok
            CHECK_5: PASS — ok
            CHECK_6: PASS — ok
            RECOMMENDATION: approveSuggested
            JUSTIFICATION: AFM thinks this is good.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-test-rev"))
        let env = envelope(provenance: .illustrative)
        let advisory =
            BASWorldPriorAIReviewerSimulation
                .wrapAsAdvisory(
                    report: report,
                    envelope: env)
        // Doctrine A: producedEnvelope provenance unchanged.
        XCTAssertEqual(
            advisory.producedEnvelope.provenance,
            .illustrative,
            "AI advisory NEVER promotes envelope provenance")
        // Even though AFM said approveSuggested, produced
        // envelope still typed-blocked from training.
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(
                    for: advisory.producedEnvelope),
            .privateProvenance(.illustrative),
            "Doctrine A: AI-reviewed envelope still blocked from training")
    }

    func test_advisoryPreservesNonIllustrativeEnvelope() throws {
        // If caller passed already-domainExpertReviewed
        // envelope (e.g., during an audit pass), advisory
        // does NOT downgrade either.
        let reply = """
            CHECK_1: PASS — ok
            CHECK_2: PASS — ok
            CHECK_3: PASS — ok
            CHECK_4: PASS — ok
            CHECK_5: PASS — ok
            CHECK_6: PASS — ok
            RECOMMENDATION: rejectSuggested
            JUSTIFICATION: AFM disagrees.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-test-rev"))
        let env = envelope(
            provenance: .domainExpertReviewed)
        let advisory =
            BASWorldPriorAIReviewerSimulation
                .wrapAsAdvisory(
                    report: report, envelope: env)
        // Provenance preserved (not promoted, not demoted).
        XCTAssertEqual(
            advisory.producedEnvelope.provenance,
            .domainExpertReviewed)
    }

    // MARK: - Codable

    func test_reportCodableRoundTrip() throws {
        let report = BASWorldPriorAIReviewReport(
            templateID: "tmpl-x-y",
            checklistResults: [
                BASWorldPriorAIChecklistResult(
                    item: .templateIDFormat,
                    pass: true,
                    comment: "ok"),
            ],
            overallRecommendation:
                .approveSuggested,
            justification: "test")
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorAIReviewReport.self,
            from: data)
        XCTAssertEqual(decoded, report)
    }

    func test_advisoryCodableRoundTrip() throws {
        let report = BASWorldPriorAIReviewReport(
            templateID: "tmpl-x-y",
            checklistResults: [],
            overallRecommendation:
                .needsExpertJudgment,
            justification: "test")
        let advisory =
            BASWorldPriorAIReviewerSimulation
                .wrapAsAdvisory(
                    report: report,
                    envelope: envelope())
        let data = try JSONEncoder().encode(advisory)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorAIReviewAdvisory.self,
            from: data)
        XCTAssertEqual(decoded, advisory)
    }
}
