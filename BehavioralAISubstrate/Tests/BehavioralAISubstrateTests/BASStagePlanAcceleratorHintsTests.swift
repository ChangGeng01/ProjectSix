// MARK: - BASStagePlanAcceleratorHintsTests
// chapter 四百三十三 / M1105

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASStagePlanAcceleratorHintsTests:
    XCTestCase
{

    // MARK: - Empty sidecar

    func testEmptySidecarHasZeroHints() {
        let sidecar = BASStagePlanAcceleratorHints.empty
        XCTAssertTrue(sidecar.isEmpty)
        XCTAssertEqual(sidecar.stageCount, 0)
    }

    // MARK: - Direct init

    func testDirectInitPersistsHints() {
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 5)
        let sidecar = BASStagePlanAcceleratorHints([
            .stageM1: hint
        ])
        XCTAssertEqual(sidecar.stageCount, 1)
        XCTAssertEqual(
            sidecar.hint(for: .stageM1), hint)
    }

    // MARK: - Lookup nil for missing stage

    func testLookupReturnsNilForMissingStage() {
        let sidecar = BASStagePlanAcceleratorHints.empty
        XCTAssertNil(
            sidecar.hint(for: .stageA),
            "lookup must return nil when no hint is" +
            " registered")
    }

    // MARK: - Immutable update

    func testWithStageAddsHint() {
        let hint = BASStageAcceleratorHint(
            operation: .attention,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 64,
            latencyBudgetMs: 10)
        let base = BASStagePlanAcceleratorHints.empty
        let updated = base.with(
            stage: .stageH, hint: hint)
        XCTAssertTrue(base.isEmpty,
            "base unchanged (immutable update)")
        XCTAssertEqual(updated.stageCount, 1)
        XCTAssertEqual(
            updated.hint(for: .stageH), hint)
    }

    func testWithStageReplacesHint() {
        let h1 = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let h2 = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float32,
            batchSize: 4,
            sequenceLength: 1,
            latencyBudgetMs: 5)
        let s1 = BASStagePlanAcceleratorHints.empty
            .with(stage: .stageM1, hint: h1)
        let s2 = s1.with(stage: .stageM1, hint: h2)
        XCTAssertEqual(s2.stageCount, 1,
            "still one slot for the stage")
        XCTAssertEqual(
            s2.hint(for: .stageM1), h2,
            "later registration replaces earlier")
    }

    func testWithoutRemovesHint() {
        let hint = BASStageAcceleratorHint(
            operation: .softmax,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let s1 = BASStagePlanAcceleratorHints.empty
            .with(stage: .stageH, hint: hint)
        let s2 = s1.without(stage: .stageH)
        XCTAssertTrue(s2.isEmpty)
    }

    // MARK: - Plan coverage

    func testCoversAllStagesEmptyPlan() {
        let sidecar = BASStagePlanAcceleratorHints.empty
        let emptyPlan = BASTurnRuntimeStagePlan()
        XCTAssertTrue(
            sidecar.coversAllStages(in: emptyPlan),
            "empty plan trivially covered by empty sidecar")
    }

    func testCoversAllStagesSequentialPlan() {
        let hint = BASStageAcceleratorHint(
            operation: .softmax,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let sidecar = BASStagePlanAcceleratorHints([
            .stageA: hint
        ])
        let plan = BASTurnRuntimeStagePlan(
            steps: [.sequential(.stageA)])
        XCTAssertTrue(
            sidecar.coversAllStages(in: plan))
    }

    func testCoversAllStagesFailsWhenStageMissingHint() {
        let hint = BASStageAcceleratorHint(
            operation: .softmax,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let sidecar = BASStagePlanAcceleratorHints([
            .stageA: hint
        ])
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB)
        ])
        XCTAssertFalse(
            sidecar.coversAllStages(in: plan),
            "stageB has no hint → coverage fails")
    }

    func testStagesMissingHintsIsDeterministic() {
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageC),
            .sequential(.stageA),
            .sequential(.stageB)
        ])
        let sidecar = BASStagePlanAcceleratorHints.empty
        let missing1 = sidecar
            .stagesMissingHints(in: plan)
        let missing2 = sidecar
            .stagesMissingHints(in: plan)
        XCTAssertEqual(missing1, missing2,
            "missing-hints list must be deterministic" +
            " (sorted by rawvalue per chapter 三百九二)")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let hint = BASStageAcceleratorHint(
            operation: .rmsNorm,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 2)
        let original = BASStagePlanAcceleratorHints([
            .stageH: hint
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASStagePlanAcceleratorHints.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testEqualSidecarsAreEqual() {
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let s1 = BASStagePlanAcceleratorHints([
            .stageA: hint
        ])
        let s2 = BASStagePlanAcceleratorHints([
            .stageA: hint
        ])
        XCTAssertEqual(s1, s2)
    }
}
