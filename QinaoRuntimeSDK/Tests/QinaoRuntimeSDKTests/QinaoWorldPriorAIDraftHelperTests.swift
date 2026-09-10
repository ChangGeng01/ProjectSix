import XCTest
@testable import QinaoWorldPrior

/// 五十八.2 — AI draft helper contract tests.
///
/// Doctrine pinned:
/// - `makeDraftPrompt` produces stable, parseable prompt
/// - Parser reads structured reply into typed Input
/// - Parser fails closed on malformed reply
/// - Wrapped envelope is **always `.illustrative`** regardless
///   of LLM-provided provenance hints (Doctrine A)
/// - Wrapped session is at `.draft` stage (no skipping)
final class QinaoWorldPriorAIDraftHelperTests: XCTestCase {

    // MARK: - Prompt builder

    func test_promptIncludesDomainAndTheme() {
        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "boundary",
                theme: "saying-no-without-guilt")
        XCTAssertTrue(
            prompt.contains("DOMAIN: boundary"))
        XCTAssertTrue(
            prompt.contains(
                "THEME: saying-no-without-guilt"))
        // Prompt enforces the format the parser expects.
        XCTAssertTrue(prompt.contains("TEMPLATE_ID:"))
        XCTAssertTrue(prompt.contains("DESCRIPTION:"))
        XCTAssertTrue(prompt.contains("PERTURB_KINDS:"))
        XCTAssertTrue(prompt.contains("EVIDENCE_RUNGS:"))
    }

    func test_promptIncludesReferenceWhenProvided() {
        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "time",
                theme: "deadline-pressure",
                referenceID: "tmpl-time-pressure")
        XCTAssertTrue(
            prompt.contains(
                "STYLE_REFERENCE: tmpl-time-pressure"))
    }

    func test_promptOmitsReferenceWhenNil() {
        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "time",
                theme: "deadline-pressure")
        XCTAssertFalse(
            prompt.contains("STYLE_REFERENCE:"))
    }

    // MARK: - Parser: well-formed reply

    func test_parseWellFormedReply() throws {
        let reply = """
            TEMPLATE_ID: tmpl-boundary-saying-no
            DESCRIPTION: Saying no respectfully preserves long-term \
            relational trust.
            PERTURB_KINDS: dropPrecondition, introduceBlocker
            EVIDENCE_RUNGS: 2, 1, 1
            """
        let input = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.parseDraft(
                from: reply))
        XCTAssertEqual(
            input.templateID, "tmpl-boundary-saying-no")
        XCTAssertEqual(
            input.perturbKindsCovered,
            ["dropPrecondition", "introduceBlocker"])
        XCTAssertEqual(
            input.branchEvidenceRungs, [2, 1, 1])
        XCTAssertTrue(
            input.description.contains("Saying no"))
    }

    // MARK: - Parser: malformed replies fail closed

    func test_parseMissingFieldsReturnsNil() {
        // Missing PERTURB_KINDS.
        let reply = """
            TEMPLATE_ID: tmpl-x-y
            DESCRIPTION: A valid description with enough length.
            EVIDENCE_RUNGS: 2, 1
            """
        XCTAssertNil(
            BASWorldPriorAIDraftHelper.parseDraft(
                from: reply))
    }

    func test_parseEmptyPerturbKindsReturnsNil() {
        let reply = """
            TEMPLATE_ID: tmpl-x-y
            DESCRIPTION: A valid description with enough length.
            PERTURB_KINDS:
            EVIDENCE_RUNGS: 2, 1
            """
        XCTAssertNil(
            BASWorldPriorAIDraftHelper.parseDraft(
                from: reply))
    }

    func test_parseGarbageReplyReturnsNil() {
        XCTAssertNil(
            BASWorldPriorAIDraftHelper.parseDraft(
                from:
                    "I cannot fulfill this request, sorry."))
    }

    // MARK: - Wrap as draft

    func test_wrapAsDraftAlwaysIllustrativeAtDraftStage() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-test-wrap",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1],
            description:
                "Wrap test description ≥ 30 chars long.")
        let wrapped = BASWorldPriorAIDraftHelper.wrapAsDraft(
            input)
        XCTAssertNotNil(wrapped)
        XCTAssertEqual(
            wrapped?.envelope.provenance, .illustrative,
            "Doctrine A: AI-drafted content MUST be " +
            ".illustrative regardless of LLM hints")
        XCTAssertEqual(
            wrapped?.session.currentStage, .draft,
            "AI drafts must start at .draft, no skipping")
        XCTAssertEqual(
            wrapped?.session.history.count, 0)
        XCTAssertEqual(
            wrapped?.session.templateID, "tmpl-test-wrap")
    }

    func test_wrapInvalidInputReturnsNil() {
        // M295.0 acceptance failure → wrap returns nil.
        let badInput = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-x-y",
            perturbKindsCovered: [], // empty - rejected
            branchEvidenceRungs: [2, 1],
            description: "Description ≥ 30 chars long here.")
        XCTAssertNil(
            BASWorldPriorAIDraftHelper.wrapAsDraft(
                badInput))
    }

    // MARK: - Doctrine A end-to-end

    func test_aiDraftedEnvelopeBlockedFromTraining()
        throws
    {
        // Even with a perfectly-shaped LLM reply, the wrapped
        // envelope MUST be typed-blocked from training.
        let reply = """
            TEMPLATE_ID: tmpl-decision-default-bias
            DESCRIPTION: Default options shape decisions \
            unless deliberate.
            PERTURB_KINDS: dropPrecondition
            EVIDENCE_RUNGS: 2, 1
            """
        let input = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.parseDraft(
                from: reply))
        let wrapped = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.wrapAsDraft(input))
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: wrapped.envelope),
            .privateProvenance(.illustrative),
            "AI-drafted envelope must be typed-blocked from " +
            "training (Doctrine A)")
    }
}
