import XCTest
import BASMemory
import QinaoLoop
import QinaoHost
import QinaoAppleFoundation

/// M198 — L13 evolution furnace driven by a real Apple FoundationModels
/// body.
///
/// ## What this proves
///
/// Existing `QinaoFurnace` tests use hand-crafted candidates. M198
/// closes the last "real-LLM through layer X" gap: a real
/// `LanguageModelSession` body is wrapped as a
/// `QinaoFurnace.ExperienceCandidate`, run through the full
/// shadow-trial state machine (`submit` → `observe` → `finalize`),
/// and produces an `EvolutionSeal` (or, on the failure path, a
/// `RetractionOrder`).
///
/// This is the L13 (Evolution Furnace) end of invariant #3:
/// "private host experience never enters base weights without
/// going through shadow-trial governance". M198 pins that the
/// gate accepts real-model output as the candidate's `summary`
/// and produces a verifiable seal.
///
/// Two tests, both env-gated:
///
/// 1. testRealLLMBodyAsCandidatePassesShadowTrialAndIsSealed —
///    happy path. Real body → submit → observe one effect →
///    finalize(.passed) → seal returned via `seal(forCandidate:)`.
/// 2. testRealLLMBodyFinalizedAsFailedTriggersRetraction —
///    rejection path. Real body + same submit/observe →
///    finalize(.failed) → retraction returned.
final class QinaoAppleFoundationFurnaceChainTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple FM " +
                "body flowing through L13 evolution furnace")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+")
    }

    private func generateRealLLMBody() async throws -> String {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "fur-c1",
            title: "Furnace seed",
            prompt:
                "Reply with one short sentence describing a " +
                "useful productivity habit.",
            role: .scout,
            expectedBenefit: 0.7, expectedCost: 0.2,
            reversibility: 0.9, confidence: 0.8)
        let drafts = try await loop.generateCandidates(
            sessionID: "fur.real.1", seeds: [seed])
        XCTAssertEqual(drafts.count, 1)
        return drafts[0].body
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeCandidate(
        id: String,
        summary: String
    ) -> QinaoFurnace.ExperienceCandidate {
        QinaoFurnace.ExperienceCandidate(
            candidateID: id,
            sourceRefs: ["session.fur.real.1#turn.1"],
            candidateType: .workflow,
            summary: summary,
            stabilitySignal: 0.8,
            contaminationRisk: 0.1,
            hostScope: "host.test",
            sovereignScope: "sovereign.test")
    }

    // MARK: - 1. Pass-path: submit → observe → finalize → seal

    func testRealLLMBodyAsCandidatePassesShadowTrialAndIsSealed()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody()
        XCTAssertFalse(body.isEmpty)

        let furnace = QinaoFurnace()
        let candidate = makeCandidate(
            id: "cand.real.1", summary: body)

        // Submit — opens a pending trial.
        let openRecord = try await furnace.submit(
            candidate: candidate,
            sessionID: "sess.fur.real.1",
            turnID: "turn.fur.real.1",
            trialScope: "qinao.m198.workflow")
        XCTAssertEqual(
            openRecord.candidateRef, "cand.real.1",
            "trial record must reference the submitted candidate")
        XCTAssertEqual(
            openRecord.completionState, "pending",
            "newly-submitted trial state must be 'pending'")

        // Observe one effect — advances state to observing.
        _ = try await furnace.observe(
            trialID: openRecord.trialID,
            effect: "host accepted the suggested workflow once",
            sessionID: "sess.fur.real.1",
            turnID: "turn.fur.real.1")

        // Finalize as passed → seal.
        let finalized = try await furnace.finalize(
            trialID: openRecord.trialID,
            outcome: .passed,
            promotionRecommendation: "promote to host workflow set",
            sessionID: "sess.fur.real.1",
            turnID: "turn.fur.real.1")
        XCTAssertEqual(
            finalized.completionState, "passed",
            "finalized.completionState must be 'passed' after " +
            "finalize(.passed)")

        // Seal must exist for this candidate.
        let seal = await furnace.seal(for: "cand.real.1")
        XCTAssertNotNil(
            seal,
            "passed shadow trial MUST produce a seal for the " +
            "candidate; got nil. Body: '\(body.prefix(60))'")

        // Retraction MUST NOT exist for a passed candidate.
        let retraction = await furnace.retraction(
            for: "cand.real.1")
        XCTAssertNil(
            retraction,
            "passed candidate MUST NOT also have a retraction; " +
            "would be contradictory dual state")
    }

    // MARK: - 2. Fail-path: finalize(.failed) → retraction

    func testRealLLMBodyFinalizedAsFailedTriggersRetraction()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody()
        XCTAssertFalse(body.isEmpty)

        let furnace = QinaoFurnace()
        let candidate = makeCandidate(
            id: "cand.real.fail.1", summary: body)

        let openRecord = try await furnace.submit(
            candidate: candidate,
            sessionID: "sess.fur.real.fail.1",
            turnID: "turn.fur.real.fail.1",
            trialScope: "qinao.m198.workflow")

        _ = try await furnace.observe(
            trialID: openRecord.trialID,
            effect: "first observation",
            sessionID: "sess.fur.real.fail.1",
            turnID: "turn.fur.real.fail.1")
        _ = try await furnace.reportFail(
            trialID: openRecord.trialID,
            reason: "host disengaged twice",
            sessionID: "sess.fur.real.fail.1",
            turnID: "turn.fur.real.fail.1")

        let finalized = try await furnace.finalize(
            trialID: openRecord.trialID,
            outcome: .failed,
            sessionID: "sess.fur.real.fail.1",
            turnID: "turn.fur.real.fail.1")
        XCTAssertEqual(
            finalized.completionState, "failed",
            "finalized.completionState must be 'failed' after " +
            "finalize(.failed)")

        // Retraction must exist; seal exists but in `.denied`
        // approval state (recording WHY the candidate was
        // rejected). Both records are part of the audit chain — a
        // candidate without a seal entry would be missing its
        // governance reason.
        let retraction = await furnace.retraction(
            for: "cand.real.fail.1")
        XCTAssertNotNil(
            retraction,
            "failed shadow trial MUST queue a retraction " +
            "(invariant #3: cleaning up a private-experience " +
            "candidate that didn't pass)")
        let seal = await furnace.seal(
            for: "cand.real.fail.1")
        XCTAssertNotNil(
            seal,
            "even on the failed path the seal record exists — " +
            "with approvalState 'denied' — to keep the audit " +
            "chain complete")
        XCTAssertEqual(
            seal?.approvalState, "denied",
            "failed-trial seal MUST be in `denied` state — " +
            "if it appears as approved/promoted, governance is " +
            "broken. Got: \(String(describing: seal?.approvalState))")
    }
}
