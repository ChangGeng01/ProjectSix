import XCTest
import BASEvaluation
import BASHostKit
@testable import SampleHost

/// chapter 二百六十九 / M750 — protocol-driven post-LLM observer
/// integration coverage.
///
/// 附录 V Stage 5 Step 3 of 5. Pre-chapter 二百六十九 the bench
/// loop's `observePostLLM(...)` was hardcoded substrate-reaudit.
/// Post-chapter 二百六十九 the new `observePostLLMViaEvaluator(_:...)`
/// accepts any `BASShadowEvaluating` conformer — substrate-driven
/// (chapter 二百六十七), no-op (chapter 二百六十六), ML-backed
/// (chapter 二百六十八+), or host-supplied experiment variants.
///
/// This suite verifies:
///
///   1. Skipped path (empty body) doesn't invoke evaluator + does
///      not increment the counter
///   2. Skipped path (llmSkipped=true) doesn't invoke evaluator
///   3. Non-skip path invokes evaluator + applies counter when
///      shifted
///   4. Non-skip path with shifted=false does NOT increment counter
///   5. `from(_:prePermitMode:)` translation handles `.skipped`
///   6. `from(_:prePermitMode:)` translation propagates fields
///   7. NoOp evaluator wires correctly (always returns .skipped)
@MainActor
final class SampleHostBenchPostLLMObserverShadowEvaluatorTests:
    XCTestCase
{
    // MARK: - Recording mock evaluator

    private final class RecordingEvaluator: BASShadowEvaluating,
        @unchecked Sendable
    {
        let evaluatorVersion: String
        private(set) nonisolated(unsafe) var calls = 0
        nonisolated(unsafe) var nextResult:
            BASShadowEvaluationResult

        init(
            evaluatorVersion: String = "recording-v1",
            nextResult: BASShadowEvaluationResult = .skipped(
                evaluatorVersion: "recording-v1")
        ) {
            self.evaluatorVersion = evaluatorVersion
            self.nextResult = nextResult
        }

        func evaluate(
            prompt: String,
            body: String,
            prePermitMode: String,
            sessionRef: String,
            turnRef: String
        ) async -> BASShadowEvaluationResult {
            calls += 1
            return nextResult
        }
    }

    // MARK: - 1. Empty body skips eval + counter unchanged

    func testEmptyBodySkipsEvaluatorAndCounter() async {
        let model = SampleHostModel()
        let evaluator = RecordingEvaluator()
        let baseline = model.hybridBenchPostLLMShifted

        let observation = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "what's the weather",
            firstBody: "",
            fallbackBody: nil,
            llmSkipped: false,
            prePermitMode: "answer",
            generation: model.hybridBenchGeneration)

        XCTAssertEqual(evaluator.calls, 0)
        XCTAssertEqual(
            observation.postLLMPermitMode, nil)
        XCTAssertEqual(observation.postLLMShifted, nil)
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted, baseline)
    }

    // MARK: - 2. llmSkipped path skips eval + counter unchanged

    func testLLMSkippedPathSkipsEvaluator() async {
        let model = SampleHostModel()
        let evaluator = RecordingEvaluator()
        let baseline = model.hybridBenchPostLLMShifted

        let observation = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "x",
            firstBody: "non-empty body",
            fallbackBody: nil,
            llmSkipped: true,  // ← key: substrate skipped LLM
            prePermitMode: "delay",
            generation: model.hybridBenchGeneration)

        XCTAssertEqual(evaluator.calls, 0)
        XCTAssertEqual(
            observation.postLLMPermitMode, nil)
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted, baseline)
    }

    // MARK: - 3. Non-skip path invokes evaluator + applies counter

    func testShiftedResultIncrementsCounter() async {
        let model = SampleHostModel()
        let evaluator = RecordingEvaluator(
            nextResult: BASShadowEvaluationResult(
                postPermitMode: "block",
                postAuditCodeCount: 7,
                shifted: true,
                reasonCodes: [
                    "evaluator:substrate-reaudit",
                    "shadow:permit-shifted:" +
                    "from-answer:to-block"
                ],
                evaluatorVersion: "recording-v1"))
        let baseline = model.hybridBenchPostLLMShifted

        let observation = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "test",
            firstBody: "this body should have been blocked",
            fallbackBody: nil,
            llmSkipped: false,
            prePermitMode: "answer",
            generation: model.hybridBenchGeneration)

        XCTAssertEqual(evaluator.calls, 1)
        XCTAssertEqual(
            observation.postLLMPermitMode, "block")
        XCTAssertEqual(observation.postLLMAuditCount, 7)
        XCTAssertEqual(observation.postLLMShifted, true)
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted,
            baseline + 1)
    }

    // MARK: - 4. Non-shifted result does NOT increment counter

    func testNonShiftedResultDoesNotIncrementCounter()
        async
    {
        let model = SampleHostModel()
        let evaluator = RecordingEvaluator(
            nextResult: BASShadowEvaluationResult(
                postPermitMode: "answer",
                postAuditCodeCount: 3,
                shifted: false,  // ← key
                reasonCodes: ["evaluator:substrate-reaudit"],
                evaluatorVersion: "recording-v1"))
        let baseline = model.hybridBenchPostLLMShifted

        let observation = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "test",
            firstBody: "fine body",
            fallbackBody: nil,
            llmSkipped: false,
            prePermitMode: "answer",
            generation: model.hybridBenchGeneration)

        XCTAssertEqual(evaluator.calls, 1)
        XCTAssertEqual(observation.postLLMShifted, false)
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted, baseline)
    }

    // MARK: - 5. .from(_:) translation handles skipped

    func testFromTranslationHandlesSkipped() {
        let skipped = BASShadowEvaluationResult.skipped(
            evaluatorVersion: "v1")
        let observation =
            SampleHostBenchPostLLMObservation.from(
                skipped, prePermitMode: "answer")
        XCTAssertNil(observation.postLLMPermitMode)
        XCTAssertNil(observation.postLLMAuditCount)
        XCTAssertNil(observation.postLLMShifted)
    }

    // MARK: - 6. .from(_:) propagates non-skip fields

    func testFromTranslationPropagatesFields() {
        let result = BASShadowEvaluationResult(
            postPermitMode: "delay",
            postAuditCodeCount: 5,
            shifted: true,
            reasonCodes: ["x"],
            evaluatorVersion: "v1")
        let observation =
            SampleHostBenchPostLLMObservation.from(
                result, prePermitMode: "answer")
        XCTAssertEqual(observation.postLLMPermitMode, "delay")
        XCTAssertEqual(observation.postLLMAuditCount, 5)
        XCTAssertEqual(observation.postLLMShifted, true)
    }

    // MARK: - 7. NoOp evaluator wires correctly

    func testNoOpEvaluatorReturnsSkipped() async {
        let model = SampleHostModel()
        let evaluator = BASNoOpShadowEvaluator()
        let baseline = model.hybridBenchPostLLMShifted

        let observation = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "test",
            firstBody: "body",
            fallbackBody: nil,
            llmSkipped: false,
            prePermitMode: "answer",
            generation: model.hybridBenchGeneration)

        // NoOp returns .skipped → observation.postLLMPermitMode
        // is nil (translation maps .skipped result → .skipped
        // observation).
        XCTAssertNil(observation.postLLMPermitMode)
        XCTAssertNil(observation.postLLMShifted)
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted, baseline)
    }

    // MARK: - 8. Stale generation drops counter increment

    /// Observability-only: counter increments are gated on
    /// `applyIfActive(generation)`. Stale generations (e.g.
    /// post-cancel) must not pollute the new bench's counter.
    func testStaleGenerationDoesNotIncrementCounter() async {
        let model = SampleHostModel()
        let evaluator = RecordingEvaluator(
            nextResult: BASShadowEvaluationResult(
                postPermitMode: "block",
                postAuditCodeCount: 2,
                shifted: true,
                reasonCodes: [],
                evaluatorVersion: "v1"))
        let baseline = model.hybridBenchPostLLMShifted
        let staleGen = model.hybridBenchGeneration - 1

        _ = await model.observePostLLMViaEvaluator(
            evaluator: evaluator,
            prompt: "test",
            firstBody: "shifted body",
            fallbackBody: nil,
            llmSkipped: false,
            prePermitMode: "answer",
            generation: staleGen)

        // Counter NOT incremented (applyIfActive blocks stale).
        XCTAssertEqual(
            model.hybridBenchPostLLMShifted, baseline)
    }
}
