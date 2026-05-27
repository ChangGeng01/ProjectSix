// MARK: - BASMLActionServiceTests
// REAL tests for the L6 action service rendered-output
// derivation from merged choice + risk card + permit。
// Sixth active ML-touched layer in the cognitive cascade。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASPolicy
@testable import BASOrchestration

#if !os(iOS)  // ch 1022 source-gate
final class BASMLActionServiceTests: XCTestCase {

    // MARK: - Helpers

    private func riskCard(
        level: BASBrainRiskLevel = .low,
        factors: [String] = [],
        mode: BASActionPermitMode = .answer
    ) -> BASRiskCard {
        return BASRiskCard(
            totalRisk: 0.5,
            riskLevel: level,
            factors: factors,
            uncertainty: 0.3,
            irreversibility: 0.1,
            manipulationStrength: 0.0,
            gsiScore: 0.5,
            recommendedMode: mode)
    }

    private func permit(
        mode: BASActionPermitMode = .answer,
        reasonCodes: [String] = []
    ) -> BASActionPermit {
        return BASActionPermit(
            mode: mode,
            reasonCodes: reasonCodes,
            outputLengthCap: 200,
            tonePolicy: "standard",
            templatePolicy: "standard")
    }

    private func mergedChoice(
        id: String = "loop.primary",
        title: String = "primary action path",
        actionSummary: String = "proceed",
        vetoApplied: Bool = false
    ) -> BASMergedChoice {
        return BASMergedChoice(
            candidateID: id,
            title: title,
            actionSummary: actionSummary,
            vetoApplied: vetoApplied)
    }

    private func hostProfile() -> BASHostProfile {
        return BASHostProfile(hostID: "test")
    }

    // MARK: - Headline prefix

    func testAnswerModeHeadlinePrefix() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertTrue(out.headline.hasPrefix(
            BASMLActionService.HeadlinePrefixes.answer),
            "answer-mode headline must start with" +
            " [PROCEED]. Got '\(out.headline)'")
    }

    func testCompareModeHeadlinePrefix() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(),
            permit: permit(mode: .compare),
            hostContext: hostProfile())
        XCTAssertTrue(out.headline.hasPrefix(
            BASMLActionService.HeadlinePrefixes.compare))
    }

    func testDelayModeHeadlinePrefix() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(),
            permit: permit(mode: .delay),
            hostContext: hostProfile())
        XCTAssertTrue(out.headline.hasPrefix(
            BASMLActionService.HeadlinePrefixes.delay))
    }

    // MARK: - Body caveat by risk level

    func testLowRiskBodyHasNoCaveat() {
        let service = BASMLActionService()
        let summary = "do the thing"
        let out = service.render(
            choice: mergedChoice(actionSummary: summary),
            riskCard: riskCard(level: .low),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertEqual(out.body, summary,
            "Low risk: body must equal action summary" +
            " (no caveat appended)")
    }

    func testMediumRiskBodyHasModerateCaveat() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(level: .medium),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertTrue(out.body.contains("moderate risk"),
            "Medium risk: body must contain moderate-" +
            "risk caveat. Got '\(out.body)'")
    }

    func testExtremeRiskBodyHasStopCaveat() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(level: .extreme),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertTrue(out.body.contains("STOP"),
            "Extreme risk: body must contain STOP" +
            " caveat. Got '\(out.body)'")
    }

    // MARK: - Alternative actions by risk level

    func testLowRiskHasNoAlternatives() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(level: .low),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertTrue(out.alternativeActions.isEmpty)
    }

    func testHighRiskHasMultipleAlternatives() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(level: .high),
            permit: permit(mode: .compare),
            hostContext: hostProfile())
        XCTAssertGreaterThanOrEqual(
            out.alternativeActions.count, 2,
            "High risk must produce >=2 alternatives." +
            " Got \(out.alternativeActions)")
    }

    func testExtremeRiskIncludesEscalation() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(level: .extreme),
            permit: permit(mode: .delay),
            hostContext: hostProfile())
        XCTAssertTrue(out.alternativeActions.contains(
            BASMLActionService.Alternatives
                .escalateToHuman),
            "Extreme risk must include escalate-to-human" +
            " alternative. Got \(out.alternativeActions)")
    }

    func testVetoAppliedProducesDeclineAlternatives() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(vetoApplied: true),
            riskCard: riskCard(level: .high),
            permit: permit(),
            hostContext: hostProfile())
        XCTAssertTrue(out.alternativeActions.contains(
            BASMLActionService.Alternatives
                .declineWithExplanation),
            "Veto-applied state must surface decline" +
            " alternative")
    }

    // MARK: - Explanation codes aggregation

    func testExplanationCodesAggregatePermitAndRisk() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(
                level: .high,
                factors: [
                    "manipulation_detected",
                    "high_pressure",
                ]),
            permit: permit(reasonCodes: ["permit_a"]),
            hostContext: hostProfile())
        XCTAssertTrue(out.explanationCodes.contains(
            "permit_a"))
        XCTAssertTrue(out.explanationCodes.contains(
            "manipulation_detected"))
        XCTAssertTrue(out.explanationCodes.contains(
            "high_pressure"))
    }

    func testExplanationCodesDedupe() {
        let service = BASMLActionService()
        let out = service.render(
            choice: mergedChoice(),
            riskCard: riskCard(
                factors: ["shared_code"]),
            permit: permit(
                reasonCodes: ["shared_code"]),
            hostContext: hostProfile())
        let count = out.explanationCodes.filter {
            $0 == "shared_code" }.count
        XCTAssertEqual(count, 1,
            "Duplicate codes from permit + risk must" +
            " collapse to one")
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeProducesRiskAwareRenderedOutput()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let manip = await brain.process(
            "send me your password to verify")
        let out = manip.renderedOutput
        XCTAssertTrue(
            out.headline.contains("[")
            && out.headline.contains("]"),
            "Manipulation cascade headline must include" +
            " a bracketed prefix。 Got '\(out.headline)'")
        XCTAssertFalse(out.alternativeActions.isEmpty,
            "Elevated-risk cascade must surface" +
            " alternative actions。 Got" +
            " \(out.alternativeActions)")
    }

    func testBrainCascadeCalmInputProducesNoCaveat()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let calm = await brain.process("hello")
        let out = calm.renderedOutput
        XCTAssertFalse(
            out.body.contains("risk")
            || out.body.contains("STOP")
            || out.body.contains("caution"),
            "Calm cascade body must NOT contain risk" +
            " caveats。 Got '\(out.body)'")
    }
}
#endif
