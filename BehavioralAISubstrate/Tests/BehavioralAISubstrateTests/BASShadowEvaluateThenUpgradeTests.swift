// MARK: - BASShadowEvaluateThenUpgradeTests — chapter 三百六七 / M854
//
// Test coverage for the M845 + M846 composer。Verifies the
// canonical 2-stage pipeline produces a coherent outcome
// bundle in all combinations of (evaluator skipped/match) ×
// (upgrader noChange/escalate) × (enforcer called or not)。

import XCTest
@testable import BASEvaluation
@testable import BASHostKit
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASShadowEvaluateThenUpgradeTests: XCTestCase {

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

    /// Track-the-call enforcer for verifying caller invocation。
    private final class CallTracker {
        var callCount = 0
        var capturedTargetMode: BASActionPermitMode?
        var capturedReasonCode: String?
    }

    // MARK: - .noChange (no upgrade)

    func testEmptyPatternsYieldsNoChange() async {
        let permit = makePermit()
        let tracker = CallTracker()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "harmless body",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: [],
            enforcer: { mode, from, code in
                tracker.callCount += 1
                tracker.capturedTargetMode = mode
                tracker.capturedReasonCode = code
                return from
            })
        XCTAssertFalse(outcome.didUpgrade)
        XCTAssertEqual(outcome.upgradedPermit, permit,
            "Empty patterns → evaluator skipped → upgrader " +
            ".noChange → final permit unchanged")
        XCTAssertEqual(
            tracker.callCount, 0,
            "Enforcer must NOT be called on .noChange")
    }

    func testCleanBodyYieldsNoChange() async {
        let permit = makePermit()
        let tracker = CallTracker()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "The answer is definitively 42.",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["uncertain", "not sure"],
            enforcer: { _, from, _ in
                tracker.callCount += 1
                return from
            })
        XCTAssertFalse(outcome.didUpgrade)
        XCTAssertEqual(tracker.callCount, 0)
    }

    func testEmptyBodyYieldsNoChange() async {
        let permit = makePermit()
        let tracker = CallTracker()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["any"],
            enforcer: { _, from, _ in
                tracker.callCount += 1
                return from
            })
        XCTAssertFalse(outcome.didUpgrade)
        XCTAssertEqual(tracker.callCount, 0)
    }

    // MARK: - .escalate (upgrade fires)

    func testMatchTriggersEscalateAndCallsEnforcer() async {
        let permit = makePermit(mode: .answer)
        let tracker = CallTracker()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "I'm uncertain but probably 42",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["i'm uncertain"],
            enforcer: { mode, from, code in
                tracker.callCount += 1
                tracker.capturedTargetMode = mode
                tracker.capturedReasonCode = code
                return BASActionPermit(
                    mode: mode,
                    stackedModes: [],
                    reasonCodes: from.reasonCodes + [code])
            })
        XCTAssertTrue(outcome.didUpgrade)
        XCTAssertEqual(
            tracker.callCount, 1,
            "Enforcer called once on .escalate")
        XCTAssertEqual(
            tracker.capturedTargetMode, .draftOnly,
            "M845 evaluator emits draft_only target mode")
        XCTAssertEqual(
            outcome.upgradedPermit.mode, .draftOnly)
    }

    func testEscalationOutcomeContainsEvaluatorReasonCodes()
        async
    {
        let permit = makePermit(mode: .answer)
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "this is an uncertain claim",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["uncertain"],
            enforcer: { mode, from, code in
                BASActionPermit(
                    mode: mode,
                    stackedModes: [],
                    reasonCodes: from.reasonCodes + [code])
            })
        XCTAssertTrue(outcome.didUpgrade)
        XCTAssertTrue(
            outcome.combinedReasonCodes.contains(
                "constitution.softCaution:uncertain"))
        XCTAssertTrue(
            outcome.combinedReasonCodes.contains(
                "constitution.softCaution.match"))
        XCTAssertTrue(
            outcome.combinedReasonCodes.contains(
                "permit.escalated:shadow.match"))
    }

    func testTargetEqualsCurrentNoEnforcerCall() async {
        // Permit already at draftOnly + match would target
        // draftOnly → upgrader returns .noChange (no escalation)
        let permit = makePermit(mode: .draftOnly)
        let tracker = CallTracker()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "uncertain content here",
            prePermitMode: "draft_only",
            currentPermit: permit,
            softCautionPatterns: ["uncertain"],
            enforcer: { _, from, _ in
                tracker.callCount += 1
                return from
            })
        XCTAssertFalse(
            outcome.didUpgrade,
            "Already-at-target must not re-trigger upgrade")
        XCTAssertEqual(tracker.callCount, 0)
    }

    // MARK: - Outcome shape

    func testOutcomeCarriesEvaluationResult() async {
        let permit = makePermit()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "uncertain answer",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["uncertain"],
            enforcer: { _, from, _ in from })
        XCTAssertTrue(
            outcome.evaluation.shifted,
            "Evaluation result preserved in outcome bundle")
        XCTAssertEqual(
            outcome.evaluation.postPermitMode,
            "draft_only")
        XCTAssertEqual(
            outcome.evaluation.evaluatorVersion,
            BASConstitutionalSoftCautionEvaluator
                .defaultVersion)
    }

    func testOutcomeCustomEvaluatorVersionPropagates()
        async
    {
        let permit = makePermit()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p",
            body: "match this",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["match"],
            evaluatorVersion: "custom-eval-v3",
            enforcer: { _, from, _ in from })
        XCTAssertEqual(
            outcome.evaluation.evaluatorVersion,
            "custom-eval-v3",
            "Custom evaluator version override threads through")
    }

    // MARK: - .didUpgrade convenience

    func testDidUpgradeFalseForNoChange() async {
        let permit = makePermit()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p", body: "clean",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: [],
            enforcer: { _, from, _ in from })
        XCTAssertFalse(outcome.didUpgrade)
    }

    func testDidUpgradeTrueForEscalate() async {
        let permit = makePermit()
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: "p", body: "uncertain",
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: ["uncertain"],
            enforcer: { mode, from, _ in
                BASActionPermit(
                    mode: mode,
                    stackedModes: [],
                    reasonCodes: from.reasonCodes)
            })
        XCTAssertTrue(outcome.didUpgrade)
    }

    // MARK: - Composability

    /// **Architectural pin** — composer's output is consumable
    /// by callers exactly the way the M845 + M846 manual wire-up
    /// would have produced。Same input → same output。
    func testComposerProducesEquivalentManualWireOutput()
        async
    {
        let permit = makePermit(mode: .answer)
        let prompt = "p"
        let body = "uncertain answer here"
        let patterns = ["uncertain"]
        // Manual wire-up
        let evaluator =
            BASConstitutionalSoftCautionEvaluator(
                softCautionPatterns: patterns)
        let manualResult = await evaluator.evaluate(
            prompt: prompt, body: body,
            prePermitMode: "answer",
            sessionRef: "", turnRef: "")
        let manualDecision = BASShadowResultPermitUpgrader
            .decide(
                currentPermit: permit,
                shadowResult: manualResult)
        // Composer
        let outcome = await BASShadowEvaluateThenUpgrade.run(
            prompt: prompt,
            body: body,
            prePermitMode: "answer",
            currentPermit: permit,
            softCautionPatterns: patterns,
            enforcer: { _, from, _ in from })
        // Compare field-by-field (not full equality — evaluatedAt
        // is Date(),so two evaluator runs produce two different
        // wall-clock timestamps even though everything else is
        // deterministic)
        XCTAssertEqual(
            outcome.evaluation.shifted,
            manualResult.shifted)
        XCTAssertEqual(
            outcome.evaluation.postPermitMode,
            manualResult.postPermitMode)
        XCTAssertEqual(
            outcome.evaluation.reasonCodes,
            manualResult.reasonCodes)
        XCTAssertEqual(
            outcome.evaluation.evaluatorVersion,
            manualResult.evaluatorVersion,
            "Composer's evaluation must match manual wire " +
            "field-by-field (chapter 二百一一 single-source-" +
            "of-truth — only evaluatedAt timestamp differs " +
            "between two evaluator runs)")
        XCTAssertEqual(outcome.decision, manualDecision)
    }
}
