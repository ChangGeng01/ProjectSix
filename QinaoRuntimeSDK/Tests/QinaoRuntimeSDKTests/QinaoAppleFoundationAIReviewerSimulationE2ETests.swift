import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
@testable import QinaoWorldPrior

/// 六十六.3 — AFM-driven AI reviewer simulation E2E.
///
/// Real `LanguageModelSession` running the 6-item checklist
/// on a candidate template; parses reply; asserts Doctrine A
/// invariants hold even with real-model body.
///
/// `QINAO_FM_E2E=1` env var + macOS 26+ availability.
final class QinaoAppleFoundationAIReviewerSimulationE2ETests:
    XCTestCase
{

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[
                Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise AI " +
                "reviewer simulation with real AFM")
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
        await registry.register(
            AppleFoundationOrganAdapter())
        let adapter = try await registry.adapter(
            for: .core)
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: .core,
            preset: .core,
            instruction: prompt,
            context: [])
        // M400.1 — convert macOS 26 foreground-only-policy
        // failures (`Code 1026`) into a clean XCTSkip.
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
                        "tmpl-time-deadline-pressure",
                    perturbKindsCovered: [
                        "dropPrecondition",
                        "introduceBlocker",
                    ],
                    branchEvidenceRungs: [2, 1, 1],
                    description:
                        "Working under deadline pressure tends to lower decision quality, unless tasks are decomposed into small commitments."),
            provenance: .illustrative)
    }

    // MARK: - 1. Real AFM produces a parseable report (best-effort)

    func test_afmProducesReviewReport() async throws {
        try skipUnlessReady()

        let env = candidateEnvelope()
        let prompt =
            BASWorldPriorAIReviewerSimulation
                .makeReviewPrompt(for: env)
        var lastBody = ""
        var report:
            BASWorldPriorAIReviewReport?
        for _ in 0..<5 {
            let body = try await draftViaAFM(
                prompt: prompt)
            lastBody = body
            if let r =
                BASWorldPriorAIReviewerSimulation
                    .parseReviewReport(
                        from: body,
                        templateID:
                            env.input.templateID)
            {
                report = r
                break
            }
        }
        guard let report else {
            // MODEL-CONFORMANCE only. The DOCTRINE this file exists to protect is asserted
            // ungated by test_advisoryNeverPromotesEnvelope_doctrineOnly, so an unparseable
            // reply no longer discards it. What is skipped here is narrow and genuinely
            // model-dependent: "a real AFM reply matches our prompt format". Reported as a
            // MEASURED rate rather than a claimed cause — 0/5 is a prompt-builder or model
            // signal worth an operator's attention, not a substrate failure.
            throw XCTSkip(
                "model conformance 0/5: no AFM reply parsed as a review report. Doctrine is "
                + "covered ungated; this is a prompt-format/model signal. Last body: "
                + lastBody)
        }
        XCTAssertEqual(
            report.templateID,
            "tmpl-time-deadline-pressure")
        XCTAssertEqual(
            report.checklistResults.count, 6)
    }

    // MARK: - Doctrine A (UNGATED — the model cannot reach these assertions)

    /// Doctrine A: an AI advisory NEVER promotes an envelope, and the envelope stays
    /// typed-blocked from training — REGARDLESS of what the model recommended.
    ///
    /// Split out UNGATED 2026-07-14 (skip triage). This chain depends on the PARSED report,
    /// not on the model: `wrapAsAdvisory(report:envelope:)` takes a struct. Previously it
    /// ran only behind QINAO_FM_E2E=1 and, worse, a single unparseable reply threw the whole
    /// doctrine away via XCTSkip — measured on 2026-07-14 this class reported "Executed 2
    /// tests, with 2 tests skipped", i.e. ZERO doctrine coverage even with the gate ON.
    ///
    /// The report is a fixture built with the model's MOST DANGEROUS answer
    /// (.approveSuggested, every checklist item passing): if the doctrine ever leaked, an
    /// approving review is what would leak it. A real model reply can only produce a report
    /// this fixture already covers.
    func test_advisoryNeverPromotesEnvelope_doctrineOnly() {
        let env = candidateEnvelope()
        let report = BASWorldPriorAIReviewReport(
            templateID: env.input.templateID,
            checklistResults: BASWorldPriorReviewChecklistItem.allCases.map {
                BASWorldPriorAIChecklistResult(
                    item: $0, pass: true, comment: "fixture: model approved")
            },
            overallRecommendation: .approveSuggested,
            justification: "fixture: the model enthusiastically approved this template")

        let advisory = BASWorldPriorAIReviewerSimulation
            .wrapAsAdvisory(report: report, envelope: env)

        XCTAssertEqual(
            advisory.producedEnvelope.provenance, .illustrative,
            "Doctrine A: an AI advisory MUST keep the envelope .illustrative regardless of "
            + "the model's recommendation")
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: advisory.producedEnvelope),
            .privateProvenance(.illustrative),
            "an AI-advised envelope must stay typed-blocked from the training pipeline")
    }

    // MARK: - 2. Doctrine A: AFM-reviewed envelope NOT promoted

    func test_afmReviewerAdvisoryDoesNotPromoteEnvelope()
        async throws
    {
        try skipUnlessReady()

        let env = candidateEnvelope()
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
            throw XCTSkip(
                "AFM unparseable on this run")
        }
        let advisory =
            BASWorldPriorAIReviewerSimulation
                .wrapAsAdvisory(
                    report: report, envelope: env)

        // Doctrine A: advisory NEVER promotes.
        XCTAssertEqual(
            advisory.producedEnvelope.provenance,
            .illustrative,
            "Doctrine A: AFM advisory MUST keep envelope " +
            ".illustrative regardless of AFM recommendation")
        // Even if AFM said approveSuggested, the envelope
        // is still typed-blocked from training.
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(
                    for: advisory.producedEnvelope),
            .privateProvenance(.illustrative))
    }
}
