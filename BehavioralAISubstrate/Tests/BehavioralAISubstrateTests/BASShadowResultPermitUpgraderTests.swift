// MARK: - BASShadowResultPermitUpgraderTests — chapter 三百五九 / M846
//
// Test coverage for G7 deliverable: typed permit-upgrade
// decision helper that closes the loop on M845
// BASConstitutionalSoftCautionEvaluator → actual permit
// escalation。
//
// Tests verify:
//   - Skipped result → .noChange
//   - shifted=false → .noChange
//   - shifted=true with nil postPermitMode → .noChange
//   - shifted=true with empty postPermitMode → .noChange
//   - shifted=true with unknown rawValue → .noChange
//   - shifted=true with target == current mode → .noChange
//   - shifted=true with valid different mode → .escalate
//   - Reason codes merged correctly (shadow codes + anchor +
//     transition tag)
//   - apply() helper returns currentPermit on .noChange
//   - apply() helper invokes enforcer on .escalate
//   - End-to-end: M845 evaluator output → upgrader decision

import XCTest
@testable import BASEvaluation
@testable import BASHostKit
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASShadowResultPermitUpgraderTests: XCTestCase {

    // MARK: - Fixtures

    private func makePermit(
        mode: BASActionPermitMode = .answer,
        reasonCodes: [String] = ["risk.low"]
    ) -> BASActionPermit {
        BASActionPermit(
            mode: mode,
            stackedModes: [],
            reasonCodes: reasonCodes,
            allowedDomains: [],
            assertionCeiling: "standard",
            toolScope: "bounded",
            memoryScope: "standard",
            requireMirror: false,
            requireCompare: false,
            requireSecondCheck: false,
            outputLengthCap: 220,
            tonePolicy: "grounded_clear",
            templatePolicy: "direct_answer")
    }

    private func makeShadowResult(
        shifted: Bool = true,
        postPermitMode: String? = "draft_only",
        reasonCodes: [String] = []
    ) -> BASShadowEvaluationResult {
        BASShadowEvaluationResult(
            postPermitMode: postPermitMode,
            postAuditCodeCount: nil,
            shifted: shifted,
            reasonCodes: reasonCodes,
            evaluatorVersion: "test-evaluator-v1")
    }

    // MARK: - .noChange cases

    func testSkippedResultReturnsNoChange() {
        let permit = makePermit()
        let result = BASShadowEvaluationResult.skipped()
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        XCTAssertEqual(decision, .noChange,
            ".skipped sentinel must produce .noChange")
    }

    func testShiftedFalseReturnsNoChange() {
        let permit = makePermit()
        let result = makeShadowResult(
            shifted: false,
            postPermitMode: "draft_only")
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        XCTAssertEqual(decision, .noChange,
            "shifted=false must produce .noChange even " +
            "when postPermitMode is set (defensive)")
    }

    func testNilPostPermitModeReturnsNoChange() {
        let permit = makePermit()
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: nil)
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        XCTAssertEqual(decision, .noChange,
            "nil postPermitMode → no target → .noChange")
    }

    func testUnknownPostPermitModeReturnsNoChange() {
        let permit = makePermit()
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: "made_up_unknown_mode")
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        XCTAssertEqual(decision, .noChange,
            "Unknown rawValue must NOT escalate (defensive " +
            "against future enum drift)")
    }

    func testTargetEqualsCurrentReturnsNoChange() {
        let permit = makePermit(mode: .draftOnly)
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: "draft_only")
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        XCTAssertEqual(decision, .noChange,
            "Already-at-target → no escalation needed")
    }

    // MARK: - .escalate cases

    func testValidEscalationProducesEscalateDecision() throws {
        let permit = makePermit(mode: .answer)
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: "draft_only",
            reasonCodes: [
                "constitution.softCaution:uncertain"
            ])
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        switch decision {
        case .noChange:
            XCTFail("Expected .escalate")
        case .escalate(let targetMode, let reasonCodes):
            XCTAssertEqual(targetMode, .draftOnly)
            // Original shadow reasonCode preserved
            XCTAssertTrue(
                reasonCodes.contains(
                    "constitution.softCaution:uncertain"))
            // Anchor code added
            XCTAssertTrue(
                reasonCodes.contains(
                    BASShadowResultPermitUpgrader
                        .escalationAnchorCode))
            // Transition tag with from/to modes
            XCTAssertTrue(
                reasonCodes.contains(
                    "permit.escalated:shadow:" +
                    "draft_only:from:answer"))
        }
    }

    func testEscalationFromCompareToBlock() {
        let permit = makePermit(mode: .compare)
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: "block",
            reasonCodes: ["evaluator:hard-block-v1"])
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        switch decision {
        case .escalate(let targetMode, let reasonCodes):
            XCTAssertEqual(targetMode, .block)
            XCTAssertTrue(
                reasonCodes.contains(
                    "permit.escalated:shadow:" +
                    "block:from:compare"))
        case .noChange:
            XCTFail("Expected .escalate to .block")
        }
    }

    // MARK: - apply() convenience

    func testApplyReturnsCurrentOnNoChange() {
        let permit = makePermit(mode: .answer)
        let result = makeShadowResult(shifted: false)
        var enforcerCalls = 0
        let upgraded = BASShadowResultPermitUpgrader
            .apply(
                currentPermit: permit,
                shadowResult: result,
                enforcer: { _, from, _ in
                    enforcerCalls += 1
                    return from
                })
        XCTAssertEqual(upgraded, permit)
        XCTAssertEqual(enforcerCalls, 0,
            "apply() must NOT call enforcer on .noChange")
    }

    func testApplyInvokesEnforcerOnEscalate() throws {
        let permit = makePermit(mode: .answer)
        let result = makeShadowResult(
            shifted: true,
            postPermitMode: "draft_only",
            reasonCodes: ["constitution.softCaution:abc"])
        var capturedTarget: BASActionPermitMode?
        var capturedReasonCode: String?
        _ = BASShadowResultPermitUpgrader.apply(
            currentPermit: permit,
            shadowResult: result,
            enforcer: { target, from, code in
                capturedTarget = target
                capturedReasonCode = code
                return BASActionPermit(
                    mode: target,
                    stackedModes: [],
                    reasonCodes: from.reasonCodes + [code])
            })
        XCTAssertEqual(capturedTarget, .draftOnly)
        let code = try XCTUnwrap(capturedReasonCode)
        XCTAssertTrue(
            code.contains(
                "constitution.softCaution:abc"),
            "Joined reason codes must include shadow's " +
            "evaluator code")
        XCTAssertTrue(
            code.contains("permit.escalated:shadow.match"))
    }

    // MARK: - Doctrine pin: stateless + deterministic

    func testDecideIsDeterministic() {
        let permit = makePermit()
        let result = makeShadowResult(
            shifted: true, postPermitMode: "compare")
        let d1 = BASShadowResultPermitUpgrader.decide(
            currentPermit: permit, shadowResult: result)
        let d2 = BASShadowResultPermitUpgrader.decide(
            currentPermit: permit, shadowResult: result)
        XCTAssertEqual(d1, d2,
            "decide() must be deterministic — same input " +
            "always produces same output")
    }

    // MARK: - End-to-end with M845 evaluator

    /// **Architectural pin** — M845 evaluator + M846 upgrader
    /// compose end-to-end into a working post-LLM permit-upgrade
    /// pipeline。This test runs both stages and verifies the
    /// upgrade decision matches expectations。
    func testEndToEndWithSoftCautionEvaluator() async {
        let evaluator =
            BASConstitutionalSoftCautionEvaluator(
                softCautionPatterns: ["i'm uncertain"])
        let result = await evaluator.evaluate(
            prompt: "what is 2+2",
            body: "I'm uncertain but probably 4",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        // Evaluator produced shifted=true + draft_only
        XCTAssertTrue(result.shifted)
        XCTAssertEqual(result.postPermitMode, "draft_only")

        let permit = makePermit(mode: .answer)
        let decision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: result)
        switch decision {
        case .escalate(let targetMode, let reasonCodes):
            XCTAssertEqual(targetMode, .draftOnly,
                "End-to-end M845 → M846 must yield " +
                ".draftOnly escalation")
            XCTAssertTrue(
                reasonCodes.contains(
                    "constitution.softCaution:i'm uncertain"))
        case .noChange:
            XCTFail("Expected escalation")
        }
    }

    // MARK: - Constants pins

    func testEscalationReasonCodePrefixPin() {
        XCTAssertEqual(
            BASShadowResultPermitUpgrader
                .escalationReasonCodePrefix,
            "permit.escalated:shadow",
            "Reason code prefix pin: bumping requires " +
            "explicit migration of audit walkers")
    }

    func testEscalationAnchorCodePin() {
        XCTAssertEqual(
            BASShadowResultPermitUpgrader
                .escalationAnchorCode,
            "permit.escalated:shadow.match",
            "Audit anchor pin (chapter 八十七 raw value " +
            "stability)")
    }
}
