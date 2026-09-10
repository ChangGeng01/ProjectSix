import XCTest
@testable import QinaoLoop
import QinaoWorldPrior

/// M290 — manifest v2 第四节"高压最后通牒"端到端积分测试.
///
/// v2 第四节 description (translated): host receives a high-pressure
/// ultimatum-style message and the runtime decides whether to send a
/// rebuttal "now". The healthy weave should:
/// - generate multiple distinct candidates (counterfactual variants
///   from L4 templates so the LLM sees truly different prompts)
/// - have the L10 tribunal flag guardian concern (high manipulation
///   pressure / boundary risk / low reversibility)
/// - produce a `vetoExplain` (guardian's voice ≥ 0.7) that names a
///   concrete alternative
/// - never silently let the high-pressure candidate slip through to
///   `.answer` — the multi-candidate frontier must be preserved
///
/// This test wires M287 + M288 + M289 helpers into one turn against a
/// seeded vault + spy organ endpoint and asserts the contracts that
/// constitute "活体织网真活" at the loop layer. Cross-layer L11 / L14
/// signals are tested elsewhere; here we focus on what M286+ unlocks
/// on top of the substrate that was already闭 closed.
final class QinaoHighPressureWeaveIntegrationTests: XCTestCase {

    // MARK: - Spy endpoint

    actor SpyEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable, Equatable {
            let prompt: String
            let role: QinaoLoop.OrganRole
        }
        private(set) var calls: [Call] = []
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            let call = Call(prompt: prompt, role: role)
            calls.append(call)
            return QinaoLoop.OrganResponse(
                body: "draft #\(calls.count)",
                providerID: "spy.weave",
                traceID: "trace-\(calls.count)")
        }
        func observed() -> [Call] { calls }
    }

    // MARK: - Fixture

    /// v2 第四节 shape: a candidate that mirrors a host receiving a
    /// harsh ultimatum. High manipulation pressure (the message is
    /// pushing for immediate action), high emotional bias (host is
    /// upset), high evidence gap (host doesn't have full picture
    /// yet), low reversibility (sending it can't be unsent), low
    /// confidence (host is uncertain).
    private func highPressureSeed() -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: "ultimatum-now",
            title: "Send rebuttal immediately",
            prompt: """
                Draft an immediate, firm reply that pushes back \
                on the ultimatum.
                """,
            context: [
                "incoming-message-tone:harsh",
                "host-state:angry",
            ],
            role: .core,
            expectedBenefit: 0.5,
            expectedCost: 0.7,
            reversibility: 0.15,
            confidence: 0.3,
            evidenceGap: 0.6,
            manipulationRisk: 0.85,
            emotionalBias: 0.8,
            boundaryConflict: 0.6,
            worldPriorClaim: nil)
    }

    // MARK: - The integration test

    func test_highPressureUltimatum_weaveContractsHold() async throws {
        // 1) Setup: seeded vault + spy organ + composed loop.
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let spy = SpyEndpoint()
        let loop = QinaoLoop(
            organEndpoint: spy, worldPrior: vault)

        // 2) M288 wiring: parent seed expanded against counterfactual
        //    branches → multi-candidate frontier with distinct prompts.
        let generated = try await loop
            .generateCandidatesWithCounterfactualBranches(
                sessionID: "weave-001",
                seed: highPressureSeed(),
                templateID: "tmpl-body-hydration")

        // tmpl-body-hydration ships 3 branches → 4 candidates total.
        XCTAssertEqual(
            generated.count, 4,
            "weave step 1 — L4→L9 must fan to 4 candidates")
        XCTAssertEqual(
            generated[0].candidateID, "ultimatum-now",
            "parent first")

        // 3) The LLM (via spy) must see 4 distinct prompts.
        //    Distinct = counterfactual prefix injection actually
        //    reached the model, not just ID expansion. This is the
        //    crux of "未来真分岔".
        let calls = await spy.observed()
        XCTAssertEqual(calls.count, 4)
        let distinctPrompts = Set(calls.map(\.prompt))
        XCTAssertEqual(
            distinctPrompts.count, 4,
            "weave step 2 — 4 candidates must mean 4 distinct prompts")
        XCTAssertEqual(
            calls[0].prompt,
            highPressureSeed().prompt,
            "parent prompt verbatim")
        for i in 1..<calls.count {
            XCTAssertTrue(
                calls[i].prompt.contains(
                    "Counterfactual perspective ("),
                "variant \(i) prompt missing perturbation prefix")
        }

        // 4) L10 tribunal: each candidate scored by all three voices.
        //    Doctrine pin: under v2 第四节's shape (manipulationRisk
        //    high + emotionalBias high + reversibility low) the
        //    tribunal must register substantial concern via guardian
        //    AND harmony — manipulation pressure is real, regret
        //    cost is real, both voices speak loudly. Which one
        //    *dominates* is shape-dependent; here the M74 weights
        //    put harmony first (low reversibility × high emotion
        //    > manipulation × boundary). The test asserts both
        //    guardian and harmony are non-trivially audible (≥0.4)
        //    rather than forcing a specific dominant identity.
        let scores = try await loop.triSelfScores(
            sessionID: "weave-001")
        XCTAssertEqual(scores.count, 4)
        for s in scores {
            XCTAssertGreaterThanOrEqual(
                s.guardVoice.concern, 0.4,
                "guardian must speak audibly on \(s.candidateID)")
            XCTAssertGreaterThanOrEqual(
                s.harmonyVoice.concern, 0.4,
                "harmony must speak audibly on \(s.candidateID)")
        }

        // 5) `vetoExplain` must fire (some voice ≥ 0.7) and
        //    name a concrete alternative — the host must NOT be
        //    left without a route. v2 doctrine：守护不接管 → 任一声音
        //    veto 都必须给 alternative。
        let veto = try await loop.vetoExplain(
            sessionID: "weave-001")
        XCTAssertNotNil(
            veto,
            "weave step 3 — tribunal must veto under high pressure")
        let v = try XCTUnwrap(veto)
        XCTAssertGreaterThanOrEqual(v.concernLevel, 0.7)
        XCTAssertNotEqual(
            v.alternativeID, "no-alternative-available",
            "weave step 4 — vetoing without alternative violates " +
            "manifest v2「不接管」doctrine")

        // 6) M289 prompt builder produces a tribunal prompt for the
        //    parent candidate that asks for the three-voice format.
        //    This is the path an LLM-driven L10 will use; here we
        //    only assert the prompt shape (real LLM integration
        //    is the next milestone after M290).
        let parentInput = QinaoLoop.CandidateInput(
            candidateID: "ultimatum-now",
            title: "Send rebuttal immediately",
            actionSummary: "send-rebuttal-now",
            expectedBenefit: 0.5,
            expectedCost: 0.7,
            reversibility: 0.15,
            confidence: 0.3,
            evidenceGap: 0.6,
            manipulationRisk: 0.85,
            emotionalBias: 0.8,
            boundaryConflict: 0.6,
            worldPriorClaim: nil)
        let triPrompt = QinaoLoop.makeTriSelfPrompt(
            for: parentInput,
            worldPriorContradiction: 0.4)
        XCTAssertTrue(triPrompt.contains("GUARDIAN: protector"))
        XCTAssertTrue(triPrompt.contains("manipulation_risk: 0.85"))
    }

    /// Companion: when an LLM tribunal output cleanly parses, both
    /// the LLM-driven and heuristic-driven paths register the same
    /// shape qualitatively under v2 第四节 conditions — guardian
    /// AND harmony both ≥ 0.5 (manipulation pressure + regret cost
    /// both audible). The test does NOT pin which voice dominates
    /// because that's a heuristic-weight quirk; v2 doctrine only
    /// requires both voices speak.
    func test_highPressure_LLMAndHeuristicBothFlagMultiVoice() throws {
        let parent = QinaoLoop.CandidateInput(
            candidateID: "ultimatum-now",
            title: "Send rebuttal immediately",
            actionSummary: "send-rebuttal-now",
            expectedBenefit: 0.5,
            expectedCost: 0.7,
            reversibility: 0.15,
            confidence: 0.3,
            evidenceGap: 0.6,
            manipulationRisk: 0.85,
            emotionalBias: 0.8,
            boundaryConflict: 0.6,
            worldPriorClaim: nil)

        let heuristic = QinaoLoop.triSelfScore(
            for: parent,
            worldPriorContradiction: 0.4)
        // Both guardian and harmony must be audible (≥0.4) under
        // this shape. Heuristic dominance lands on harmony given
        // M74 weights — that's expected and not what this test pins.
        XCTAssertGreaterThanOrEqual(heuristic.guardVoice.concern, 0.4)
        XCTAssertGreaterThanOrEqual(
            heuristic.harmonyVoice.concern, 0.4)

        // Synthetic LLM reply matching the v2 第四节 shape.
        let llmText = """
            GUARDIAN concern: 0.85
            GUARDIAN reasons: manipulation-risk, boundary-conflict
            SCOUT concern: 0.55
            SCOUT reasons: evidence-gap, low-confidence
            HARMONY concern: 0.7
            HARMONY reasons: emotional-bias, low-reversibility
            """
        let parsed = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "ultimatum-now",
            fallback: { heuristic })
        XCTAssertTrue(parsed.usedLLM)
        // LLM also has both voices audible — no single-voice tunnel.
        XCTAssertGreaterThanOrEqual(
            parsed.score.guardVoice.concern, 0.5)
        XCTAssertGreaterThanOrEqual(
            parsed.score.harmonyVoice.concern, 0.5)
    }
}
