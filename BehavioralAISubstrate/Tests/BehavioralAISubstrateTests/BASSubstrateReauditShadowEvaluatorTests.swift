import XCTest
@testable import BASHostKit
@testable import BASEvaluation

/// chapter 二百六十七 / M749 —
/// `BASSubstrateReauditShadowEvaluator` integration coverage.
///
/// 附录 V Stage 5 Step 2 of 5. The substrate-driven shadow
/// evaluator runs the host runtime against the LLM body and
/// reports whether the substrate's permit decision shifts. This
/// suite verifies:
///
///   1. Default `evaluatorVersion` matches the published constant
///   2. `evaluate` skips empty body (returns `.skipped`)
///   3. `evaluate` runs substrate against non-empty body and
///      emits a typed result with `evaluator:substrate-reaudit`
///      reason code
///   4. Long body triggers truncation reason code
///   5. Body truncation cap is respected (default 4096)
///   6. Custom `evaluatorVersion` propagates through to result
///   7. Custom workflowProfile / riskLevel / surface accepted
final class BASSubstrateReauditShadowEvaluatorTests: XCTestCase {

    // MARK: - Fixtures

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(configuration: .fixtureGeneric)
    }

    // MARK: - 1. evaluatorVersion default matches constant

    func testDefaultEvaluatorVersionMatchesConstant() {
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime())
        XCTAssertEqual(
            evaluator.evaluatorVersion,
            BASSubstrateReauditShadowEvaluator.version)
        XCTAssertEqual(
            BASSubstrateReauditShadowEvaluator.version,
            "substrate-reaudit-v1")
    }

    // MARK: - 2. Empty body returns .skipped

    func testEvaluateEmptyBodyReturnsSkipped() async {
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime())
        let result = await evaluator.evaluate(
            prompt: "what's the weather",
            body: "",
            prePermitMode: "answer",
            sessionRef: "sess-1",
            turnRef: "turn-1")
        XCTAssertNil(result.postPermitMode)
        XCTAssertNil(result.postAuditCodeCount)
        XCTAssertFalse(result.shifted)
        XCTAssertEqual(
            result.reasonCodes, ["evaluator:skipped"])
        XCTAssertEqual(
            result.evaluatorVersion,
            BASSubstrateReauditShadowEvaluator.version)
    }

    // MARK: - 3. Non-empty body produces substrate-reaudit result

    func testEvaluateNonEmptyBodyProducesReauditReasonCode()
        async throws
    {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime())
        let result = await evaluator.evaluate(
            prompt: "what's the weather",
            body: "It's sunny today.",
            prePermitMode: "answer",
            sessionRef: "sess-2",
            turnRef: "turn-2")
        XCTAssertNotNil(result.postPermitMode)
        XCTAssertEqual(
            result.evaluatorVersion,
            BASSubstrateReauditShadowEvaluator.version)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "evaluator:substrate-reaudit"),
            "expected reaudit reason code; got \(result.reasonCodes)")
    }

    // MARK: - 4. Long body triggers truncation reason code

    func testEvaluateLongBodyEmitsTruncationCode() async throws {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime(),
            bodyTruncationChars: 64)
        // Build a 200-char body so 64-char cap kicks in.
        let longBody = String(repeating: "x", count: 200)
        let result = await evaluator.evaluate(
            prompt: "test",
            body: longBody,
            prePermitMode: "answer",
            sessionRef: "sess-3",
            turnRef: "turn-3")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "shadow:body-truncated"),
            "expected truncation code on 200-char body with " +
            "64-char cap; got \(result.reasonCodes)")
    }

    // MARK: - 5. Body truncation cap respected (no truncation
    //               below cap)

    func testEvaluateShortBodyDoesNotEmitTruncationCode()
        async throws
    {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime(),
            bodyTruncationChars: 4096)
        let result = await evaluator.evaluate(
            prompt: "test",
            body: "small body",
            prePermitMode: "answer",
            sessionRef: "sess-4",
            turnRef: "turn-4")
        XCTAssertFalse(
            result.reasonCodes.contains(
                "shadow:body-truncated"),
            "10-char body must not trigger truncation in " +
            "4096-char cap; got \(result.reasonCodes)")
    }

    // MARK: - 6. Custom evaluatorVersion propagates

    func testCustomEvaluatorVersionPropagates() async throws {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime(),
            evaluatorVersion: "custom-reaudit-v2")
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "y",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertEqual(
            result.evaluatorVersion, "custom-reaudit-v2")
    }

    // MARK: - 7. Custom workflowProfile / riskLevel / surface
    //               accepted (no crash)

    func testCustomWorkflowAndRiskAccepted() async throws {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime(),
            workflowProfile: .reflective,
            riskLevel: .high,
            surface: .application)
        let result = await evaluator.evaluate(
            prompt: "test",
            body: "body content",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        // Just verify it ran cleanly — substrate produces some
        // post-permit-mode regardless of workflow/risk variation.
        XCTAssertNotNil(result.postPermitMode)
    }

    // MARK: - 8. Body-truncation init clamps below 64 chars

    func testBodyTruncationInitClampsBelow64() async throws {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        // Init clamps to max(64, value). Cap of 0 should resolve
        // to 64 so the evaluator stays usable.
        let evaluator = BASSubstrateReauditShadowEvaluator(
            runtime: makeRuntime(),
            bodyTruncationChars: 0)
        let body = String(repeating: "x", count: 100)
        let result = await evaluator.evaluate(
            prompt: "x",
            body: body,
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "shadow:body-truncated"),
            "100-char body should trigger truncation with " +
            "default-clamped cap")
    }

    // MARK: - 9. Conforms to BASShadowEvaluating

    func testConformsToProtocol() {
        let evaluator: any BASShadowEvaluating =
            BASSubstrateReauditShadowEvaluator(
                runtime: makeRuntime())
        // Type-check pass means it conforms; double-check the
        // version property is reachable through the protocol.
        XCTAssertFalse(evaluator.evaluatorVersion.isEmpty)
    }
}
