import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
@testable import QinaoWorldPrior

/// 六十.1 — Path B end-to-end demo with real Apple Foundation
/// Models inference.
///
/// ## Why this exists
///
/// 五十八 ship 了 typed scaffolding for Path B：
/// `BASWorldPriorAIDraftHelper` (prompt builder + parser),
/// `BASWorldPriorTemplateAuthoringSession` (7-stage state
/// machine), `BASWorldPriorProductionCurriculum` (registry),
/// `BASWorldPriorTrainingExporter` (JSONL pipe). Five 件 typed-
/// pinned but从未真模型驱动跑过端到端。
///
/// 六十.1 是 **first real-AFM-driven Path B walkthrough**：真
/// AFM 起草 candidate，host 自审，模拟 expert approval，最终
/// envelope 走到 production curriculum 入 training pipe。
///
/// ## Doctrine pinned end-to-end
///
/// 1. **AI-drafted candidate is `.illustrative`** regardless of
///    real LLM body content (Doctrine A typed-pinned)
/// 2. **AI-drafted envelope typed-blocked from training** (M295.2
///    filter, even when the body comes from real AFM)
/// 3. **Only after `.approveDomain` does provenance hit
///    `.domainExpertReviewed`** — and the simulated `expertSign`
///    transition is the only way
/// 4. **Post-approval envelope passes training filter** — it's
///    the whole point of Path B
/// 5. **JSONL export pipe works end-to-end on real-LLM-drafted
///    content** (provided the LLM produced parseable output)
///
/// ## Gating
///
/// `QINAO_FM_E2E=1` env var + macOS 26+ / iOS 26+ availability.
///
/// ```
/// QINAO_FM_E2E=1 swift test --filter \
///   QinaoAppleFoundationPathBE2ETests
/// ```
final class QinaoAppleFoundationPathBE2ETests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[
                Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise Path B " +
                "with real AFM")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ " +
            "/ visionOS 26+")
    }

    private func makeAFMRegistry() async -> BASOrganRegistry {
        let registry = BASOrganRegistry()
        await registry.register(
            AppleFoundationOrganAdapter())
        return registry
    }

    /// Drive AFM with a Path B draft prompt and return the raw
    /// LLM body. Used as the input to the parser.
    private func draftViaAFM(
        prompt: String
    ) async throws -> String {
        let registry = await makeAFMRegistry()
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

    /// Try drafting + parsing up to N times. AFM is stochastic
    /// — sometimes the first reply doesn't match the format.
    /// `nil` after all attempts means parser-incompatible
    /// outputs (still a real signal worth recording).
    private func draftAndParseWithRetries(
        prompt: String,
        attempts: Int = 3
    ) async throws
        -> (
            body: String,
            input:
                BASWorldPriorTemplateAcceptance.Input?
        )
    {
        var lastBody = ""
        for _ in 0..<attempts {
            let body = try await draftViaAFM(prompt: prompt)
            lastBody = body
            if let parsed = BASWorldPriorAIDraftHelper
                .parseDraft(from: body)
            {
                return (body, parsed)
            }
        }
        return (lastBody, nil)
    }

    // MARK: - Test 1: AI-drafted envelope is .illustrative

    func test_aiDraftedEnvelopeAlwaysIllustrative()
        async throws
    {
        try skipUnlessReady()

        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "boundary",
                theme: "saying-no-without-guilt")
        let result = try await draftAndParseWithRetries(
            prompt: prompt)

        // If parser failed, surface the body so we can see
        // what AFM produced — but don't fail the suite (this
        // tests doctrine, not LLM compliance).
        guard let input = result.input else {
            throw XCTSkip(
                "AFM produced unparseable output across " +
                "retries — body was: \(result.body)")
        }

        let wrapped = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.wrapAsDraft(input))

        // Doctrine A: AI-drafted envelope MUST be illustrative
        // regardless of LLM body content.
        XCTAssertEqual(
            wrapped.envelope.provenance, .illustrative,
            "AI-drafted envelope must be .illustrative even " +
            "when body comes from real AFM")
        XCTAssertEqual(
            wrapped.session.currentStage, .draft,
            "AI drafts start at .draft")
    }

    // MARK: - Test 2: AI-drafted envelope blocked from training

    func test_aiDraftedEnvelopeBlockedFromTraining()
        async throws
    {
        try skipUnlessReady()

        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "decision",
                theme: "default-choice-bias")
        let result = try await draftAndParseWithRetries(
            prompt: prompt)
        guard let input = result.input else {
            throw XCTSkip(
                "AFM unparseable — body: \(result.body)")
        }
        let wrapped = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.wrapAsDraft(input))

        // Real AFM body, but envelope still typed-blocked.
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: wrapped.envelope),
            .privateProvenance(.illustrative),
            "AI-drafted envelope must be typed-blocked from " +
            "training even with real AFM body")
    }

    // MARK: - Test 3: Full Path B walkthrough end-to-end

    func test_fullPathBWalkthroughEndToEnd() async throws {
        try skipUnlessReady()

        // Step 1 — AFM drafts candidate.
        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "time",
                theme: "deadline-pressure-decision-quality")
        let result = try await draftAndParseWithRetries(
            prompt: prompt)
        guard let input = result.input else {
            throw XCTSkip(
                "AFM unparseable — body: \(result.body)")
        }

        // Step 2 — Wrap as draft.
        let wrapped = try XCTUnwrap(
            BASWorldPriorAIDraftHelper.wrapAsDraft(input))
        var session = wrapped.session
        XCTAssertEqual(session.currentStage, .draft)

        // Step 3 — Host self-accept (.draft → .hostReviewed).
        session = try XCTUnwrap(
            session.applying(.hostAccept))
        XCTAssertEqual(
            session.currentStage, .hostReviewed)

        // Step 4 — Submit for peer review
        // (.hostReviewed → .peerReview).
        session = try XCTUnwrap(
            session.applying(.submitForPeerReview))
        XCTAssertEqual(
            session.currentStage, .peerReview)

        // Step 5 — Simulated expert approves
        // (.peerReview → .domainApproved). In real Path B,
        // this transition only happens after a human expert
        // signs off out-of-band — here we simulate that
        // approval to demonstrate the typed lifecycle.
        session = try XCTUnwrap(
            session.applying(.approveDomain))
        XCTAssertEqual(
            session.currentStage, .domainApproved)
        XCTAssertEqual(
            session.attainedProvenance,
            .domainExpertReviewed)

        // Step 6 — Wrap final envelope at production
        // provenance.
        let productionEnvelope =
            BASWorldPriorTemplateEnvelope(
                input: input,
                provenance: .domainExpertReviewed)

        // Step 7 — Build attestation, verify valid.
        let attestation =
            BASWorldPriorTemplateAttestation(
                envelope: productionEnvelope,
                authoringSession: session)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation),
            "envelope ↔ session attestation must hold after " +
            "full Path B walkthrough")

        // Step 8 — Register into production curriculum.
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: productionEnvelope,
                authoringSession: session)
        XCTAssertTrue(entry.isProductionGrade)
        let curriculum = try XCTUnwrap(
            BASWorldPriorProductionCurriculum.empty
                .registering(entry))
        XCTAssertEqual(curriculum.entries.count, 1)

        // Step 9 — Production envelope passes training filter
        // (the whole point of Path B).
        XCTAssertNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: productionEnvelope),
            "post-approval envelope MUST pass training filter")

        // Step 10 — Export to JSONL.
        let exportResult =
            BASWorldPriorTrainingExporter.export(
                curriculum.productionEnvelopes)
        XCTAssertEqual(
            exportResult.report.exportedCount, 1)
        XCTAssertFalse(
            exportResult.jsonl.isEmpty,
            "JSONL export must be non-empty after walkthrough")

        // Step 11 — JSONL line decodes back to a valid Pair.
        let line = exportResult.jsonl
        let pair = try JSONDecoder().decode(
            BASWorldPriorTrainingExporter.Pair.self,
            from: Data(line.utf8))
        XCTAssertEqual(
            pair.templateID, input.templateID)
        XCTAssertEqual(
            pair.provenance, "domainExpertReviewed")
    }

    // MARK: - Test 4: AFM body is recorded in the draft

    /// Smoke test that the real AFM body is what gets parsed
    /// — not some cached / fixture body.
    func test_realAFMBodyDrivesParser() async throws {
        try skipUnlessReady()

        let prompt = BASWorldPriorAIDraftHelper
            .makeDraftPrompt(
                domain: "relationship",
                theme: "active-listening-during-conflict")
        let body = try await draftViaAFM(prompt: prompt)
        XCTAssertFalse(
            body.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            "real AFM body must be non-empty")
        // The body should contain at least one of the field
        // markers we asked for in the prompt — otherwise AFM
        // didn't engage with the prompt at all.
        let markers = [
            "TEMPLATE_ID",
            "DESCRIPTION",
            "PERTURB_KINDS",
            "EVIDENCE_RUNGS",
        ]
        let hits = markers.filter {
            body.contains($0)
        }
        XCTAssertGreaterThanOrEqual(
            hits.count, 1,
            "AFM must engage with at least one prompt " +
            "marker — body was: \(body)")
    }
}
