import XCTest
@testable import BASEvaluation

/// chapter 二百六十八 / M756 — ML-backed shadow evaluator
/// scaffolding coverage.
///
/// 附录 V Stage 5 Step 4 of 5. The real ML model requires real
/// bench data (Stage 3 user-action). This file ships the
/// **typed contract + deterministic rules-based default** that
/// hosts wire today + replace with CoreML-backed conformers
/// once an `.mlpackage` exists.
///
/// Suite verifies:
///
///   1. `BASRulesBasedBodyFeatureClassifier` produces expected
///      scores for forbidden-substring / unsafe-length / safe-
///      short / baseline branches
///   2. Init parameters clamp to safe ranges (NaN → 0; empty
///      forbidden substrings filtered)
///   3. `BASMLBackedShadowEvaluator` integrates classifier +
///      threshold; emits typed reason codes
///   4. Empty body → `.skipped`
///   5. Probability ≥ threshold → shifted = true + postPermitMode
///      = "block"
///   6. Probability < threshold → shifted = false + postPermitMode
///      = nil
///   7. Auto-derived evaluatorVersion includes classifier version
///   8. Conforms to `BASShadowEvaluating` (drop-in)
final class BASMLBackedShadowEvaluatorTests: XCTestCase {

    // MARK: - Rules-based classifier branches

    func testClassifierForbiddenSubstring() async {
        let c = BASRulesBasedBodyFeatureClassifier(
            forbiddenSubstrings: ["FORBIDDEN"])
        let prob = await c.classifyBlockedProbability(
            prompt: "x",
            body: "this body contains FORBIDDEN content")
        XCTAssertEqual(
            prob,
            BASRulesBasedBodyFeatureClassifier
                .defaultForbiddenSubstringScore)
    }

    func testClassifierUnsafeLength() async {
        let c = BASRulesBasedBodyFeatureClassifier(
            unsafeLengthThreshold: 100)
        let longBody = String(repeating: "x", count: 200)
        let prob = await c.classifyBlockedProbability(
            prompt: "x", body: longBody)
        XCTAssertEqual(
            prob,
            BASRulesBasedBodyFeatureClassifier
                .defaultUnsafeLengthScore)
    }

    func testClassifierSafeShort() async {
        let c = BASRulesBasedBodyFeatureClassifier(
            safeMinLength: 10)
        let prob = await c.classifyBlockedProbability(
            prompt: "x",
            body: "ok")  // 2 chars, below 10
        XCTAssertEqual(
            prob,
            BASRulesBasedBodyFeatureClassifier
                .defaultSafeShortScore)
    }

    func testClassifierBaselineFallback() async {
        let c = BASRulesBasedBodyFeatureClassifier()
        let prob = await c.classifyBlockedProbability(
            prompt: "x",
            body: "normal body content here")
        XCTAssertEqual(
            prob,
            BASRulesBasedBodyFeatureClassifier
                .defaultBaselineScore)
    }

    // MARK: - Init parameter clamping

    func testClassifierClampsScoresAndFilters() {
        let c = BASRulesBasedBodyFeatureClassifier(
            unsafeLengthScore: 5.0,  // clamp to 1.0
            forbiddenSubstrings: [
                "  valid  ",
                "",
                "  ",
                "another"
            ],
            forbiddenSubstringScore: -2.0,  // clamp to 0.0
            baselineScore: .nan)  // → 0.0
        XCTAssertEqual(c.unsafeLengthScore, 1.0)
        XCTAssertEqual(c.forbiddenSubstringScore, 0.0)
        XCTAssertEqual(c.baselineScore, 0.0)
        // Empty + whitespace-only forbidden substrings filtered;
        // valid ones trimmed.
        XCTAssertEqual(c.forbiddenSubstrings, ["valid", "another"])
    }

    func testClassifierUnsafeLengthThresholdMinimumOne() {
        let c = BASRulesBasedBodyFeatureClassifier(
            unsafeLengthThreshold: 0)
        XCTAssertEqual(c.unsafeLengthThreshold, 1)
    }

    // MARK: - Evaluator: empty body → skipped

    func testEvaluatorEmptyBodyReturnsSkipped() async {
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: BASRulesBasedBodyFeatureClassifier())
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertNil(result.postPermitMode)
        XCTAssertFalse(result.shifted)
    }

    // MARK: - Evaluator: probability ≥ threshold → shifted

    func testEvaluatorAboveThresholdShifts() async {
        let classifier = BASRulesBasedBodyFeatureClassifier(
            forbiddenSubstrings: ["BAD"])
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: classifier,
            blockedProbabilityThreshold: 0.5)
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "this body has BAD content",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertTrue(result.shifted)
        XCTAssertEqual(result.postPermitMode, "block")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "ml-backed:shifted:from-answer:to-block"))
    }

    // MARK: - Evaluator: probability < threshold → not shifted

    func testEvaluatorBelowThresholdDoesNotShift() async {
        let classifier = BASRulesBasedBodyFeatureClassifier()
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: classifier,
            blockedProbabilityThreshold: 0.5)
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "perfectly safe body",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        // Default baseline 0.30 < threshold 0.5
        XCTAssertFalse(result.shifted)
        XCTAssertNil(result.postPermitMode)
    }

    // MARK: - Reason codes typed

    func testReasonCodesIncludeProbabilityAndThreshold() async {
        let classifier = BASRulesBasedBodyFeatureClassifier()
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: classifier,
            blockedProbabilityThreshold: 0.5)
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "normal body",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertTrue(
            result.reasonCodes.contains(where: {
                $0.hasPrefix("ml-backed:probability:")
            }))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "ml-backed:threshold:0.500"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "ml-backed:classifier:rules-v1"))
    }

    // MARK: - Auto-derived evaluatorVersion

    func testAutoDerivedEvaluatorVersion() {
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: BASRulesBasedBodyFeatureClassifier(
                classifierVersion: "v3-test"))
        XCTAssertEqual(
            evaluator.evaluatorVersion,
            "ml-backed:v3-test")
    }

    // MARK: - Custom evaluatorVersion override

    func testCustomEvaluatorVersionOverride() {
        let evaluator = BASMLBackedShadowEvaluator(
            classifier: BASRulesBasedBodyFeatureClassifier(),
            evaluatorVersion: "custom-ml-v9")
        XCTAssertEqual(
            evaluator.evaluatorVersion, "custom-ml-v9")
    }

    // MARK: - Conforms to BASShadowEvaluating

    func testEvaluatorConformsToProtocol() {
        let evaluator: any BASShadowEvaluating =
            BASMLBackedShadowEvaluator(
                classifier:
                    BASRulesBasedBodyFeatureClassifier())
        XCTAssertFalse(evaluator.evaluatorVersion.isEmpty)
    }

    // MARK: - Threshold clamping

    func testThresholdClampsToZeroToOne() {
        let c = BASRulesBasedBodyFeatureClassifier()
        let high = BASMLBackedShadowEvaluator(
            classifier: c,
            blockedProbabilityThreshold: 5.0)
        XCTAssertEqual(high.blockedProbabilityThreshold, 1.0)
        let low = BASMLBackedShadowEvaluator(
            classifier: c,
            blockedProbabilityThreshold: -3.0)
        XCTAssertEqual(low.blockedProbabilityThreshold, 0.0)
        let nan = BASMLBackedShadowEvaluator(
            classifier: c,
            blockedProbabilityThreshold: .nan)
        XCTAssertEqual(nan.blockedProbabilityThreshold, 0.0)
    }
}
