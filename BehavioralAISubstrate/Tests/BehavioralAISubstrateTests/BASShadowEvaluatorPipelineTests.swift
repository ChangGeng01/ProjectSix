import XCTest
@testable import BASEvaluation

/// chapter 二百六十 / M754 — `BASShadowEvaluatorPipeline`
/// composition primitive coverage.
///
/// The pipeline composes multiple `BASShadowEvaluating`
/// conformers concurrently and merges their results per a typed
/// strategy. This suite verifies:
///
///   1. Empty evaluator list → `.skipped`
///   2. All-skipped evaluators → `.skipped`
///   3. anyShifted strategy: any one shifted → merged shifted
///   4. allShifted strategy: all shifted → merged shifted
///   5. majorityShifted strategy: >50% shifted → merged shifted
///   6. Auto-derived evaluatorVersion includes inner versions
///   7. Pipeline conforms to `BASShadowEvaluating` (drop-in)
///   8. Reason codes record per-evaluator detail
final class BASShadowEvaluatorPipelineTests: XCTestCase {

    // MARK: - Mock evaluators

    private struct AlwaysSkipped: BASShadowEvaluating {
        let evaluatorVersion: String
        init(version: String = "skipped-v1") {
            self.evaluatorVersion = version
        }
        func evaluate(
            prompt: String, body: String,
            prePermitMode: String,
            sessionRef: String, turnRef: String
        ) async -> BASShadowEvaluationResult {
            BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }
    }

    private struct AlwaysShifted: BASShadowEvaluating {
        let evaluatorVersion: String
        init(version: String = "shifted-v1") {
            self.evaluatorVersion = version
        }
        func evaluate(
            prompt: String, body: String,
            prePermitMode: String,
            sessionRef: String, turnRef: String
        ) async -> BASShadowEvaluationResult {
            BASShadowEvaluationResult(
                postPermitMode: "block",
                postAuditCodeCount: 5,
                shifted: true,
                reasonCodes: ["always-shifted"],
                evaluatorVersion: evaluatorVersion)
        }
    }

    private struct NeverShifted: BASShadowEvaluating {
        let evaluatorVersion: String
        init(version: String = "calm-v1") {
            self.evaluatorVersion = version
        }
        func evaluate(
            prompt: String, body: String,
            prePermitMode: String,
            sessionRef: String, turnRef: String
        ) async -> BASShadowEvaluationResult {
            BASShadowEvaluationResult(
                postPermitMode: "answer",
                postAuditCodeCount: 2,
                shifted: false,
                reasonCodes: ["calm"],
                evaluatorVersion: evaluatorVersion)
        }
    }

    // MARK: - 1. Empty evaluator list → skipped

    func testEmptyPipelineReturnsSkipped() async {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [])
        let result = await pipeline.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertNil(result.postPermitMode)
        XCTAssertFalse(result.shifted)
    }

    // MARK: - 2. All skipped → pipeline skipped

    func testAllSkippedPipelineReturnsSkipped() async {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysSkipped(),
                AlwaysSkipped(version: "skipped-v2")
            ])
        let result = await pipeline.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertNil(result.postPermitMode)
        XCTAssertFalse(result.shifted)
    }

    // MARK: - 3. anyShifted: any one shifted

    func testAnyShiftedAnyEvaluatorShifted() async {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [
                NeverShifted(),
                AlwaysShifted(),
                NeverShifted(version: "calm-v2")
            ],
            mergeStrategy: .anyShifted)
        let result = await pipeline.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(result.shifted)
        XCTAssertEqual(result.postAuditCodeCount, 9)  // 5+2+2
    }

    // MARK: - 4. allShifted: only when all shifted

    func testAllShiftedRequiresAllToShift() async {
        // Mixed → not all shifted → false
        let mixed = BASShadowEvaluatorPipeline(
            evaluators: [AlwaysShifted(), NeverShifted()],
            mergeStrategy: .allShifted)
        let mixedResult = await mixed.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(mixedResult.shifted)

        // All shifted → true
        let allOn = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(),
                AlwaysShifted(version: "shifted-v2")
            ],
            mergeStrategy: .allShifted)
        let allOnResult = await allOn.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(allOnResult.shifted)
    }

    // MARK: - 5. majorityShifted: strictly > 50%

    func testMajorityShiftedRequiresMoreThanHalf() async {
        // 1 of 3 shifted → not majority
        let oneOfThree = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(),
                NeverShifted(),
                NeverShifted(version: "calm-v2")
            ],
            mergeStrategy: .majorityShifted)
        let r1 = await oneOfThree.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(r1.shifted)

        // 2 of 3 shifted → majority
        let twoOfThree = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(),
                AlwaysShifted(version: "shifted-v2"),
                NeverShifted()
            ],
            mergeStrategy: .majorityShifted)
        let r2 = await twoOfThree.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(r2.shifted)

        // 1 of 2 shifted → tie, NOT strictly majority
        let oneOfTwo = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(),
                NeverShifted()
            ],
            mergeStrategy: .majorityShifted)
        let r3 = await oneOfTwo.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(r3.shifted)
    }

    // MARK: - 6. Auto-derived evaluatorVersion

    func testAutoDerivedEvaluatorVersionIncludesInner() {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(version: "v1-impl-A"),
                NeverShifted(version: "v2-impl-B")
            ],
            mergeStrategy: .anyShifted)
        XCTAssertEqual(
            pipeline.evaluatorVersion,
            "pipeline:any-shifted:[v1-impl-A+v2-impl-B]")
    }

    // MARK: - 7. Pipeline conforms to BASShadowEvaluating

    func testPipelineConformsToProtocol() {
        let pipeline: any BASShadowEvaluating =
            BASShadowEvaluatorPipeline(
                evaluators: [AlwaysShifted()])
        XCTAssertFalse(pipeline.evaluatorVersion.isEmpty)
    }

    // MARK: - 8. Reason codes record per-evaluator detail

    func testReasonCodesRecordPerEvaluatorDetail() async {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysShifted(version: "first-v1"),
                NeverShifted(version: "second-v1")
            ])
        let result = await pipeline.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        // Should contain per-evaluator detail with index + version
        XCTAssertTrue(
            result.reasonCodes.contains(where: {
                $0.contains("pipeline:evaluator:0:first-v1") &&
                $0.contains("shifted=true")
            }),
            "expected per-evaluator detail for evaluator 0; " +
            "got \(result.reasonCodes)")
        XCTAssertTrue(
            result.reasonCodes.contains(where: {
                $0.contains("pipeline:evaluator:1:second-v1") &&
                $0.contains("shifted=false")
            }))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "pipeline:strategy:any-shifted"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "pipeline:non-skipped-count:2"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "pipeline:shifted-count:1"))
        XCTAssertTrue(
            result.reasonCodes.contains(
                "pipeline:merged-shifted:true"))
    }

    // MARK: - 9. Custom evaluatorVersion override

    func testCustomEvaluatorVersionOverride() {
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [AlwaysShifted()],
            evaluatorVersion: "custom-pipeline-v9")
        XCTAssertEqual(
            pipeline.evaluatorVersion, "custom-pipeline-v9")
    }

    // MARK: - 10. Mixed skipped + shifted: only non-skipped count

    func testMixedSkippedAndShifted() async {
        // 1 skipped + 1 shifted + 1 not shifted = 2 non-skipped
        // anyShifted → true
        let pipeline = BASShadowEvaluatorPipeline(
            evaluators: [
                AlwaysSkipped(),
                AlwaysShifted(),
                NeverShifted()
            ],
            mergeStrategy: .anyShifted)
        let result = await pipeline.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(result.shifted)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "pipeline:non-skipped-count:2"),
            "skipped evaluators excluded from non-skipped count; " +
            "got \(result.reasonCodes)")
    }

    // MARK: - 11. MergeStrategy enum exhaustiveness

    func testMergeStrategyEnumExhaustive() {
        let cases = BASShadowEvaluatorMergeStrategy.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertEqual(
            BASShadowEvaluatorMergeStrategy(
                rawValue: "any-shifted"), .anyShifted)
        XCTAssertEqual(
            BASShadowEvaluatorMergeStrategy(
                rawValue: "all-shifted"), .allShifted)
        XCTAssertEqual(
            BASShadowEvaluatorMergeStrategy(
                rawValue: "majority-shifted"), .majorityShifted)
    }
}
