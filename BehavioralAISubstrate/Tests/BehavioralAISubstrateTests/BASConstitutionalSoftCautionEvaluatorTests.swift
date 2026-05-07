// MARK: - BASConstitutionalSoftCautionEvaluatorTests
// chapter 三百五八 / M845
//
// Test coverage for G3 Layer 2 wire-up via BASShadowEvaluating
// conformer。Closes the deferred-from-M843 G3 L2 work item per
// the M840 Cognitive OS roadmap。
//
// Tests verify:
//   - Empty patterns → skipped
//   - Empty body → skipped
//   - Clean body (no pattern match) → skipped
//   - Match → shifted=true + draft_only postPermitMode +
//     constitution.softCaution:<pattern> + match anchor +
//     evaluator version reason codes
//   - Case-insensitive match
//   - First-match-wins
//   - Whitespace-only patterns skipped at construction
//   - Whitespace-trimmed patterns at construction
//   - Result is BASShadowEvaluating-protocol-conformant
//   - **rawValue alignment pin**: escalateToPermitMode constant
//     matches BASActionPermitMode.draftOnly.rawValue exactly
//     (catches any drift on either side)

import XCTest
@testable import BASEvaluation
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASConstitutionalSoftCautionEvaluatorTests:
    XCTestCase
{
    // MARK: - Empty / no-op cases

    func testEmptyPatternsReturnsSkipped() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: [])
        let result = await eval.evaluate(
            prompt: "p", body: "any body",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(result.shifted)
        XCTAssertNil(result.postPermitMode)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "evaluator:skipped"))
    }

    func testEmptyBodyReturnsSkipped() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["caution"])
        let result = await eval.evaluate(
            prompt: "p", body: "",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(result.shifted)
        XCTAssertNil(result.postPermitMode)
    }

    func testWhitespaceOnlyBodyReturnsSkipped() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["caution"])
        let result = await eval.evaluate(
            prompt: "p", body: "   \n\t   ",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(result.shifted)
    }

    func testCleanBodyReturnsSkipped() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: [
                "low confidence", "i'm not certain"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "The answer is definitively 42.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(result.shifted)
        XCTAssertNil(result.postPermitMode)
    }

    // MARK: - Match cases

    func testMatchProducesShiftedTrue() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["i'm not sure"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "Hmm, I'm not sure but probably 42",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(result.shifted,
            "Match must produce shifted=true so caller " +
            "knows to escalate the permit")
    }

    func testMatchEmitsDraftOnlyPostPermitMode() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["uncertain"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "The result seems uncertain",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertEqual(
            result.postPermitMode,
            BASConstitutionalSoftCautionEvaluator
                .escalateToPermitMode,
            "Match must escalate permit mode to draft_only")
    }

    func testMatchEmbedsTypedReasonCodes() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["might be wrong"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "I think the answer might be wrong here",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "constitution.softCaution:might be wrong"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                BASConstitutionalSoftCautionEvaluator
                    .matchAnchorCode))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "evaluator:" +
                BASConstitutionalSoftCautionEvaluator
                    .defaultVersion))
    }

    func testCaseInsensitiveMatch() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["UNCERTAIN"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "I'm Uncertain about this",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(result.shifted)
    }

    func testFirstMatchWinsOnMultiplePatterns() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["alpha", "beta"])
        let result = await eval.evaluate(
            prompt: "p",
            body: "alpha beta gamma",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "constitution.softCaution:alpha"),
            "First matching pattern in array order wins")
        XCTAssertFalse(
            result.reasonCodes.contains(
                "constitution.softCaution:beta"),
            "Subsequent patterns NOT also reported")
    }

    // MARK: - Construction defensiveness

    func testWhitespaceOnlyPatternsDroppedAtConstruction() {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["", "  ", "\t", "valid"])
        XCTAssertEqual(
            eval.softCautionPatterns, ["valid"],
            "Whitespace-only patterns must be filtered at " +
            "construction (defensive against config typos)")
    }

    func testWhitespaceTrimmedAtConstruction() {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["  trimmed  "])
        XCTAssertEqual(
            eval.softCautionPatterns, ["trimmed"])
    }

    func testCustomVersionTagPropagates() async {
        let eval = BASConstitutionalSoftCautionEvaluator(
            softCautionPatterns: ["x"],
            evaluatorVersion: "custom-v2")
        let result = await eval.evaluate(
            prompt: "p", body: "x match",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertEqual(
            result.evaluatorVersion, "custom-v2")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "evaluator:custom-v2"))
    }

    // MARK: - Doctrine alignment pins

    /// **Critical pin**: the evaluator's `escalateToPermitMode`
    /// constant ("draft_only") MUST equal
    /// `BASActionPermitMode.draftOnly.rawValue`。If either side
    /// drifts (e.g. someone renames the enum case rawValue),
    /// this test catches it。BASEvaluation module doesn't import
    /// BASPolicy at runtime,but the test target imports both,
    /// so the alignment can be pinned here。
    func testRawValueAlignmentWithBASActionPermitMode() {
        XCTAssertEqual(
            BASConstitutionalSoftCautionEvaluator
                .escalateToPermitMode,
            BASActionPermitMode.draftOnly.rawValue,
            "Soft-caution evaluator's draft_only rawValue " +
            "constant MUST match BASActionPermitMode.draftOnly. " +
            "rawValue exactly。Drift on either side breaks " +
            "post-LLM permit-upgrade wiring。")
    }

    func testDefaultVersionTagStable() {
        XCTAssertEqual(
            BASConstitutionalSoftCautionEvaluator
                .defaultVersion,
            "constitutional-softCaution-v1",
            "Default version tag pin: bumping requires " +
            "explicit migration of audit walkers that grep " +
            "evaluator:constitutional-softCaution-v1")
    }

    func testMatchAnchorCodeStable() {
        XCTAssertEqual(
            BASConstitutionalSoftCautionEvaluator
                .matchAnchorCode,
            "constitution.softCaution.match",
            "Match anchor code pin (chapter 八十七 raw " +
            "value stability doctrine)")
    }

    // MARK: - Protocol conformance pin

    /// Compile-time pin: the evaluator IS a BASShadowEvaluating
    /// conformer。If protocol gains a method,this fails to
    /// compile until the conformer adds it。
    func testConformsToBASShadowEvaluatingProtocol() {
        let eval: any BASShadowEvaluating =
            BASConstitutionalSoftCautionEvaluator(
                softCautionPatterns: [])
        XCTAssertEqual(
            eval.evaluatorVersion,
            BASConstitutionalSoftCautionEvaluator
                .defaultVersion)
    }
}
