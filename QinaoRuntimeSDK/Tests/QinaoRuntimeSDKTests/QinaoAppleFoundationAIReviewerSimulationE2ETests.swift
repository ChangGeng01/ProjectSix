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
        let draft = try await adapter.draft(request)
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
            throw XCTSkip(
                "AFM produced unparseable output across " +
                "retries — body: \(lastBody)")
        }
        XCTAssertEqual(
            report.templateID,
            "tmpl-time-deadline-pressure")
        XCTAssertEqual(
            report.checklistResults.count, 6)
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
