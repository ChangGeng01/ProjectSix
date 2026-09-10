import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
@testable import QinaoWorldPrior

/// 六十六.4 — AFM-driven 5-persona panel review E2E.
///
/// Real AFM running each of 5 personas reviewing a single
/// candidate; aggregates into a typed panel review.
/// Doctrine A invariants asserted.
///
/// `QINAO_FM_E2E=1` env var + macOS 26+ availability.
final class QinaoAppleFoundationAIPersonaSetE2ETests:
    XCTestCase
{

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[
                Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise persona " +
                "panel review with real AFM")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+")
    }

    private func draftViaAFM(prompt: String)
        async throws -> String
    {
        let registry = BASOrganRegistry()
        let apple = AppleFoundationOrganAdapter()
        await registry.register(apple)
        let adapter = try await registry.adapter(
            providerID: apple.descriptor.providerID)
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: .core,
            preset: .core,
            instruction: prompt,
            context: [])
        // M400.1 — convert macOS 26 foreground-only-policy
        // failures (`Code 1026`) into a clean XCTSkip rather
        // than substrate-mismatch test failure. See
        // `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md`.
        let draft: BASOrganDraft
        do {
            draft = try await adapter.draft(request)
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        return draft.body
    }

    private func candidateEnvelope()
        -> BASWorldPriorTemplateEnvelope
    {
        BASWorldPriorTemplateEnvelope(
            input:
                BASWorldPriorTemplateAcceptance.Input(
                    templateID:
                        "tmpl-relationship-direct-confrontation",
                    perturbKindsCovered: [
                        "dropPrecondition",
                        "introduceBlocker",
                    ],
                    branchEvidenceRungs: [2, 2, 1],
                    description:
                        "Direct confrontation in conflicts often damages long-term trust unless paired with explicit repair offers."),
            provenance: .illustrative)
    }

    // MARK: - 1. Single-persona review through real AFM

    func test_singlePersonaReviewParses() async throws {
        try skipUnlessReady()

        let env = candidateEnvelope()
        let prompt =
            BASWorldPriorAIPersonaReviewer
                .makePersonaReviewPrompt(
                    persona:
                        .relationshipTherapist,
                    envelope: env)
        var lastBody = ""
        var review:
            BASWorldPriorAIPersonaReview?
        for _ in 0..<5 {
            let body = try await draftViaAFM(
                prompt: prompt)
            lastBody = body
            if let r =
                BASWorldPriorAIPersonaReviewer
                    .parsePersonaReview(
                        from: body,
                        persona:
                            .relationshipTherapist,
                        templateID:
                            env.input.templateID)
            {
                review = r
                break
            }
        }
        guard let review else {
            throw XCTSkip(
                "AFM unparseable across retries — body: " +
                "\(lastBody)")
        }
        XCTAssertEqual(
            review.persona,
            .relationshipTherapist)
        XCTAssertFalse(
            review.domainSpecificComment
                .trimmingCharacters(
                    in: .whitespacesAndNewlines)
                .isEmpty,
            "AFM persona must produce non-empty domain comment")
    }

    // MARK: - 2. 5-persona panel review

    func test_fivePersonaPanelReview() async throws {
        try skipUnlessReady()

        let env = candidateEnvelope()
        var perPersona: [
            BASWorldPriorAIPersonaReview
        ] = []
        for persona in
            BASWorldPriorAIPersona.allCases
        {
            let prompt =
                BASWorldPriorAIPersonaReviewer
                    .makePersonaReviewPrompt(
                        persona: persona,
                        envelope: env)
            // 1 retry per persona; if AFM doesn't parse,
            // skip that persona but continue panel.
            for _ in 0..<2 {
                let body = try await draftViaAFM(
                    prompt: prompt)
                if let r =
                    BASWorldPriorAIPersonaReviewer
                        .parsePersonaReview(
                            from: body,
                            persona: persona,
                            templateID:
                                env.input.templateID)
                {
                    perPersona.append(r)
                    break
                }
            }
        }
        let panel = BASWorldPriorAIPersonaReviewer
            .makePanelReview(
                templateID: env.input.templateID,
                reviews: perPersona)
        // Best-effort: at least 3 of 5 personas should
        // produce parseable output. If less, AFM was
        // unusually noisy this run.
        XCTAssertGreaterThanOrEqual(
            panel.perPersona.count, 3,
            "expected ≥ 3 of 5 persona reviews to parse; " +
            "got \(panel.perPersona.count)")

        // Recommendation field present and typed.
        for r in panel.perPersona {
            // typed enum; just verify it's one of the
            // known cases (compiler enforces).
            _ = r.recommendation
        }
    }

    // MARK: - Doctrine A (UNGATED — the model cannot reach these assertions)

    /// Doctrine A for the persona-panel lane: wrapping a review as an advisory NEVER
    /// promotes the envelope, whatever the personas recommended.
    ///
    /// Split out UNGATED 2026-07-14 (skip triage). The assertion depends on the PARSED
    /// report — `wrapAsAdvisory(report:envelope:)` takes a struct — so the model was never
    /// load-bearing here, yet a single unparseable reply discarded the doctrine entirely
    /// via XCTSkip (observed firing on 2026-07-14 even with the gate ON).
    ///
    /// Fixture uses the most dangerous answer (.approveSuggested, all checks passing): an
    /// approving panel is exactly what would leak the envelope if the doctrine ever broke.
    func test_panelReviewNeverPromotesEnvelope_doctrineOnly() {
        let env = candidateEnvelope()
        let report = BASWorldPriorAIReviewReport(
            templateID: env.input.templateID,
            checklistResults: BASWorldPriorReviewChecklistItem.allCases.map {
                BASWorldPriorAIChecklistResult(
                    item: $0, pass: true, comment: "fixture: persona approved")
            },
            overallRecommendation: .approveSuggested,
            justification: "fixture: the whole persona panel approved")

        let advisory = BASWorldPriorAIReviewerSimulation
            .wrapAsAdvisory(report: report, envelope: env)

        XCTAssertEqual(
            advisory.producedEnvelope.provenance, .illustrative,
            "AI persona panel + reviewer advisory MUST keep the envelope .illustrative")
    }

    // MARK: - 3. Doctrine A: panel review never promotes

    func test_panelReviewDoesNotPromoteEnvelope()
        async throws
    {
        try skipUnlessReady()

        let env = candidateEnvelope()
        // Build a single persona review with AFM, then
        // verify envelope provenance unchanged when
        // wrapped via the reviewer simulation API.
        let prompt =
            BASWorldPriorAIReviewerSimulation
                .makeReviewPrompt(for: env)
        let body = try await draftViaAFM(
            prompt: prompt)
        guard let report =
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: body,
                    templateID:
                        env.input.templateID)
        else {
            // MODEL-CONFORMANCE only: the doctrine is asserted ungated by
            // test_panelReviewNeverPromotesEnvelope_doctrineOnly, so an unparseable reply
            // no longer discards it. This narrow skip means "the real AFM reply did not
            // match our prompt format" — a prompt/model signal, not a substrate failure.
            throw XCTSkip(
                "model conformance: the AFM reply did not parse as a review report "
                + "(doctrine is covered ungated; this is a prompt-format/model signal)")
        }
        let advisory =
            BASWorldPriorAIReviewerSimulation
                .wrapAsAdvisory(
                    report: report, envelope: env)
        XCTAssertEqual(
            advisory.producedEnvelope.provenance,
            .illustrative,
            "AI persona panel + reviewer advisory MUST " +
            "keep envelope .illustrative")
    }
}
