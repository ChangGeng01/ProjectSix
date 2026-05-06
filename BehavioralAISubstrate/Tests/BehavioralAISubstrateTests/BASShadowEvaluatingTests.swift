import XCTest
@testable import BASEvaluation

/// chapter 二百六十六 / M748 — `BASShadowEvaluating` protocol +
/// `BASShadowEvaluationResult` typed value coverage.
///
/// 附录 V Stage 5 Step 1 of 5. The protocol is the abstract
/// contract; conformers in chapters 二百六十七+ ship the real
/// implementations. This suite verifies:
///
///   1. Schema version pinned + Codable round-trip stable
///   2. `.skipped` sentinel has expected shape
///   3. ReasonCodes trim + filter empties
///   4. evaluatorVersion trimmed
///   5. postPermitMode trimmed (or nil-preserved)
///   6. NoOp conformer always returns `.skipped`
final class BASShadowEvaluatingTests: XCTestCase {

    // MARK: - 1. Schema version pinned

    func testSchemaVersionPinned() {
        XCTAssertEqual(
            BASShadowEvaluationResult.currentSchemaVersion,
            "1.0.0")
    }

    // MARK: - 2. .skipped sentinel shape

    func testSkippedSentinelShape() {
        let s = BASShadowEvaluationResult.skipped(
            evaluatorVersion: "test-v1")
        XCTAssertNil(s.postPermitMode)
        XCTAssertNil(s.postAuditCodeCount)
        XCTAssertFalse(s.shifted)
        XCTAssertEqual(
            s.reasonCodes, ["evaluator:skipped"])
        XCTAssertEqual(s.evaluatorVersion, "test-v1")
    }

    // MARK: - 3. ReasonCodes trim + filter empties

    func testReasonCodesTrimAndFilter() {
        let r = BASShadowEvaluationResult(
            shifted: true,
            reasonCodes: [
                "  shifted:block  ",
                "",
                "evidence:body-too-long",
                "  "
            ],
            evaluatorVersion: "v1")
        XCTAssertEqual(
            r.reasonCodes,
            ["shifted:block", "evidence:body-too-long"])
    }

    // MARK: - 4. evaluatorVersion trimmed

    func testEvaluatorVersionTrimmed() {
        let r = BASShadowEvaluationResult(
            evaluatorVersion: "  trimmed-v1  ")
        XCTAssertEqual(r.evaluatorVersion, "trimmed-v1")
    }

    // MARK: - 5. postPermitMode trimmed when present

    func testPostPermitModeTrimmedWhenPresent() {
        let r = BASShadowEvaluationResult(
            postPermitMode: "  block  ",
            shifted: true,
            evaluatorVersion: "v1")
        XCTAssertEqual(r.postPermitMode, "block")

        let nilR = BASShadowEvaluationResult(
            postPermitMode: nil,
            evaluatorVersion: "v1")
        XCTAssertNil(nilR.postPermitMode)
    }

    // MARK: - 6. Codable round-trip preserves all fields

    func testCodableRoundTripPreservesAllFields() throws {
        let original = BASShadowEvaluationResult(
            postPermitMode: "block",
            postAuditCodeCount: 42,
            shifted: true,
            reasonCodes: ["a", "b", "c"],
            evaluatorVersion: "ml-head-shadow-v0.1",
            evaluatedAt:
                Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(
            BASShadowEvaluationResult.self, from: data)
        XCTAssertEqual(restored, original)
    }

    // MARK: - 7. NoOp evaluator always returns .skipped

    func testNoOpAlwaysReturnsSkipped() async {
        let evaluator = BASNoOpShadowEvaluator()
        let result = await evaluator.evaluate(
            prompt: "any prompt",
            body: "any body",
            prePermitMode: "answer",
            sessionRef: "sess",
            turnRef: "turn")
        XCTAssertNil(result.postPermitMode)
        XCTAssertNil(result.postAuditCodeCount)
        XCTAssertFalse(result.shifted)
        XCTAssertEqual(
            result.reasonCodes, ["evaluator:skipped"])
        XCTAssertEqual(result.evaluatorVersion, "noop-v1")
    }

    // MARK: - 8. NoOp evaluatorVersion override

    func testNoOpAcceptsCustomVersion() async {
        let evaluator = BASNoOpShadowEvaluator(
            evaluatorVersion: "custom-v2")
        let result = await evaluator.evaluate(
            prompt: "x",
            body: "y",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertEqual(result.evaluatorVersion, "custom-v2")
    }

    // MARK: - 9. NoOp returns identical result for any input

    func testNoOpDeterministicAcrossInputs() async {
        let evaluator = BASNoOpShadowEvaluator()
        let r1 = await evaluator.evaluate(
            prompt: "A", body: "B",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        let r2 = await evaluator.evaluate(
            prompt: "X", body: "Y",
            prePermitMode: "block",
            sessionRef: "s2", turnRef: "t2")
        // Equatable-equal modulo evaluatedAt
        XCTAssertEqual(r1.postPermitMode, r2.postPermitMode)
        XCTAssertEqual(
            r1.postAuditCodeCount, r2.postAuditCodeCount)
        XCTAssertEqual(r1.shifted, r2.shifted)
        XCTAssertEqual(r1.reasonCodes, r2.reasonCodes)
        XCTAssertEqual(
            r1.evaluatorVersion, r2.evaluatorVersion)
    }

    // MARK: - 10. Default Sendable + Hashable conformance

    func testHashableSetMembership() {
        let r1 = BASShadowEvaluationResult.skipped(
            evaluatorVersion: "v1")
        let r2 = BASShadowEvaluationResult.skipped(
            evaluatorVersion: "v2")
        let r3 = BASShadowEvaluationResult.skipped(
            evaluatorVersion: "v1",
            evaluatedAt: r1.evaluatedAt)
        var set = Set<BASShadowEvaluationResult>()
        set.insert(r1)
        set.insert(r2)
        set.insert(r3)
        // r1 != r3 only if evaluatedAt differs; using identical
        // evaluatedAt → r1 == r3.
        XCTAssertEqual(set.count, 2)
    }
}
