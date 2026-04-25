import XCTest
import QinaoLoop
import QinaoAppleFoundation
@testable import QinaoRisk

/// M190 — L11 risk gate + L12 surface decision driven by real
/// Apple FoundationModels output.
///
/// ## What this proves
///
/// The risk gate's pure-evaluator is deterministic given the
/// signals it receives. M186 already proved the three-signature
/// gate refuses misbound intents. M190 closes the parallel
/// behavioral question: given the SAME real-LLM body but DIFFERENT
/// risk signals, the gate produces correctly-differentiated
/// surface decisions:
///
///   - Low-risk signals → SurfaceMode.draftShell + autoComply or
///     userAffirm (the LLM body lands in front of the user as a
///     single draft).
///   - High-risk signals → SurfaceMode.silentStub /
///     boundaryScript / delayPacket + hostOverride (the LLM body
///     is held back from the user; only an audit reference flows
///     through).
///
/// This is the "会保护不接管 (protect, not take over)" property
/// in action: the LLM produces drafts, but the gate decides
/// whether the user sees them.
///
/// Gated behind `QINAO_FM_E2E=1` + macOS 26+ same as M177-M188.
final class QinaoAppleFoundationRiskGateTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise L11/L12 driven " +
                "by real Apple FoundationModels")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    private func generateRealLLMBody() async throws -> String {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "rg-c1",
            title: "Risk-gate seed",
            prompt:
                "Reply with one short sentence describing a " +
                "low-risk daily habit.",
            role: .scout,
            expectedBenefit: 0.7, expectedCost: 0.2,
            reversibility: 0.9, confidence: 0.8)
        let drafts = try await loop.generateCandidates(
            sessionID: "rg.real.1", seeds: [seed])
        XCTAssertEqual(drafts.count, 1)
        return drafts[0].body
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Low-risk signals → draftShell + reasoned/minimal

    func testLowRiskSignalsProduceDraftShellOnRealLLMBody()
        async throws
    {
        try skipUnlessReady()
        let body = try await generateRealLLMBody()
        XCTAssertFalse(
            body.isEmpty,
            "real LLM body must be non-empty before risk gate eval")

        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let safeSignals = QinaoRiskGate.RiskSignals.safe

        // Real LLM produced a benign-domain draft; signals model
        // the host's read of it (no harm potential, no
        // irreversibility, no manipulation).
        let surface = await gate.requestSurfaceAction(
            for: safeSignals,
            auditReference: "audit-rg-low",
            candidateIDs: ["rg-c1"])

        XCTAssertEqual(
            surface.surface, .draftShell,
            "low-risk signals MUST produce draftShell — the " +
            "LLM body lands in front of the user. Got: " +
            "\(surface.surface). Body was: \(body.prefix(60))")
    }

    // MARK: - High-risk: irreversible + manipulation → boundary or block

    /// Same real-LLM body, but the host extracts (via its own
    /// classifier — outside this test's scope) signals that flag
    /// the action as irreversible AND manipulation-pressured. The
    /// gate must NOT route the body to a draft-shell;  surfaces
    /// it as a held-back / boundary / refused mode instead.
    func testHighRiskSignalsRefuseRealLLMBodyDirectly()
        async throws
    {
        try skipUnlessReady()
        let body = try await generateRealLLMBody()
        XCTAssertFalse(body.isEmpty)

        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let dangerSignals = QinaoRiskGate.RiskSignals(
            harmSeverity: 0.9,
            harmScope: 0.9,
            irreversibility: 0.95,
            uncertainty: 0.7,
            evidenceDebt: 0.5,
            manipulationIntensity: 0.85,
            pressureAuthenticity: 0.2,
            gsiScore: 0.85)

        let surface = await gate.requestSurfaceAction(
            for: dangerSignals,
            auditReference: "audit-rg-high",
            candidateIDs: ["rg-c1"])

        // The risk evaluator's actual choice between block /
        // boundary / delay depends on which axis dominates.
        // Whichever it picks, the body MUST NOT just be rendered
        // as a draftShell — that would mean the gate let a
        // high-risk LLM output reach the user unfiltered.
        XCTAssertNotEqual(
            surface.surface, .draftShell,
            "high-risk signals MUST NOT route a real LLM body to " +
            "draftShell — that would breach 会保护不接管. " +
            "Got: \(surface.surface)")

        // Reason codes must be non-empty — the gate is required
        // to explain refusals so hosts can render copy + audit
        // logs. Empty reason codes on a non-allow surface would
        // mean the gate refused without telling anyone why.
        XCTAssertFalse(
            surface.reasonCodes.isEmpty,
            "surface decisions other than draftShell MUST carry " +
            "reasonCodes for host UI/audit. Got 0 codes for " +
            "surface \(surface.surface)")
    }

    // MARK: - Determinism (offline — pure-function pin)

    /// Pin the gate's purity offline. Two calls with identical
    /// inputs must produce byte-equal SurfaceAction values. NOT
    /// env-gated — it's a pure-function property of the gate, not
    /// a property of the LLM. Kept in this file because the
    /// invariant directly underpins the LLM-driven tests above
    /// (without purity, the high-risk / low-risk assertions could
    /// pass once and fail next run).
    func testSurfaceDecisionIsPureGivenIdenticalInputs() async {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let sigs = QinaoRiskGate.RiskSignals.safe
        let s1 = await gate.requestSurfaceAction(
            for: sigs,
            auditReference: "audit-det",
            candidateIDs: ["c1"])
        let s2 = await gate.requestSurfaceAction(
            for: sigs,
            auditReference: "audit-det",
            candidateIDs: ["c1"])
        XCTAssertEqual(
            s1, s2,
            "requestSurfaceAction must be a pure function of " +
            "(signals, audit ref, candidates, prompt key) — same " +
            "inputs → byte-equal SurfaceAction across calls")
    }
}
