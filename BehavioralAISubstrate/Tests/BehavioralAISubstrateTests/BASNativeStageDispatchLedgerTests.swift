// MARK: - BASNativeStageDispatchLedgerTests
// chapter 四百三十六 / M1120-M1121

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASNativeStageDispatchLedgerTests:
    XCTestCase
{

    // MARK: - Empty + sentinels

    func testEmptyLedgerHasZeroExecutions() {
        let l = BASNativeStageDispatchLedger.empty
        XCTAssertEqual(l.executionCount, 0)
        XCTAssertEqual(l.honoredAssignmentCount, 0)
        XCTAssertEqual(l.unhonoredAssignmentCount, 0)
        XCTAssertEqual(l.totalDurationMs, 0)
    }

    // MARK: - Record aggregates

    func testRecordHonoredCountedCorrectly() {
        let assignment = makeAssignment(
            backing: .mlxArray)
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-h-risk-l11",
            assignment: assignment,
            durationMs: 5,
            sequenceIndex: 0,
            honoredAssignment: true)
        let l = BASNativeStageDispatchLedger.empty
            .appending(r)
        XCTAssertEqual(l.executionCount, 1)
        XCTAssertEqual(l.honoredAssignmentCount, 1)
        XCTAssertEqual(l.unhonoredAssignmentCount, 0)
        XCTAssertEqual(l.totalDurationMs, 5)
    }

    func testRecordUnhonoredCountedCorrectly() {
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-x",
            assignment: nil,
            durationMs: 3,
            sequenceIndex: 0,
            honoredAssignment: false)
        let l = BASNativeStageDispatchLedger.empty
            .appending(r)
        XCTAssertEqual(l.executionCount, 1)
        XCTAssertEqual(l.honoredAssignmentCount, 0)
        XCTAssertEqual(l.unhonoredAssignmentCount, 1)
        XCTAssertEqual(l.totalDurationMs, 3)
    }

    func testMixedHonoredAndUnhonored() {
        let r1 = BASNativeStageExecutionRecord(
            stageRawValue: "stage-a",
            assignment: makeAssignment(
                backing: .mlxArray),
            durationMs: 2,
            sequenceIndex: 0,
            honoredAssignment: true)
        let r2 = BASNativeStageExecutionRecord(
            stageRawValue: "stage-b",
            assignment: nil,
            durationMs: 4,
            sequenceIndex: 1,
            honoredAssignment: false)
        let r3 = BASNativeStageExecutionRecord(
            stageRawValue: "stage-c",
            assignment: makeAssignment(
                backing: .mlMultiArray),
            durationMs: 1,
            sequenceIndex: 2,
            honoredAssignment: true)
        let l = BASNativeStageDispatchLedger.empty
            .appending(r1)
            .appending(r2)
            .appending(r3)
        XCTAssertEqual(l.executionCount, 3)
        XCTAssertEqual(l.honoredAssignmentCount, 2,
            "r1 + r3 honored (mlx + ml multi)")
        XCTAssertEqual(l.unhonoredAssignmentCount, 1,
            "r2 fell through (no assignment)")
        XCTAssertEqual(l.totalDurationMs, 7)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let assignment = makeAssignment(
            backing: .metalBuffer)
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-attention",
            assignment: assignment,
            durationMs: 12,
            sequenceIndex: 0,
            honoredAssignment: true)
        let original = BASNativeStageDispatchLedger.empty
            .appending(r)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASNativeStageDispatchLedger.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testEqualLedgersAreEqual() {
        let l1 = BASNativeStageDispatchLedger.empty
        let l2 = BASNativeStageDispatchLedger.empty
        XCTAssertEqual(l1, l2)
    }

    // MARK: - Helpers

    private func makeAssignment(
        backing: BASTensorBackingKind
    ) -> BASStageAcceleratorAssignment {
        let key: BASKernelKey?
        if backing == .cpuBytes {
            key = nil
        } else {
            key = BASKernelKey(
                operation: .matMul,
                dataType: .float16,
                backingKind: backing)
        }
        return BASStageAcceleratorAssignment(
            selectedBackingKind: backing,
            selectedKernelKey: key,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
    }
}

// MARK: - executePlanWithAssignments end-to-end

final class BASNativeStageExecutorWithAssignmentsTests:
    XCTestCase
{

    // MARK: - Empty plan + empty assignments

    func testEmptyPlanProducesEmptyLedgers() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan()
        let assignments =
            BASTurnRuntimePlanAssignmentLedger
                .empty(turnID: "t1")
        let request = makeRequest()
        let result = await executor
            .executePlanWithAssignments(
                plan,
                request: request,
                assignments: assignments,
                routedExecutor: { _, _, _ in 0 },
                fallbackExecutor: { _, _ in 0 })
        XCTAssertEqual(
            result.stageLedger.records.count, 0)
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 0)
    }

    // MARK: - Plan with no assignments → all fall through

    func testPlanWithNoAssignmentsAllFallThrough() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB)
        ])
        let assignments =
            BASTurnRuntimePlanAssignmentLedger
                .empty(turnID: "t1")
        let result = await executor
            .executePlanWithAssignments(
                plan,
                request: makeRequest(),
                assignments: assignments,
                routedExecutor: { _, _, _ in
                    XCTFail(
                        "routed executor must NOT fire" +
                        " when no assignments registered")
                    return 0
                },
                fallbackExecutor: { _, _ in 0 })
        XCTAssertEqual(
            result.stageLedger.records.count, 2)
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 2)
        XCTAssertEqual(
            result.dispatchLedger.honoredAssignmentCount,
            0,
            "no assignments → 0 honored")
        XCTAssertEqual(
            result.dispatchLedger
                .unhonoredAssignmentCount, 2,
            "all 2 stages fell through to fallback")
    }

    // MARK: - Plan with full assignments → all honored

    func testPlanWithFullAssignmentsAllHonored() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB)
        ])
        let assignments = makeFullAssignmentLedger(
            stages: [.stageA, .stageB],
            backing: .mlxArray)
        let result = await executor
            .executePlanWithAssignments(
                plan,
                request: makeRequest(),
                assignments: assignments,
                routedExecutor: { stage, assignment, _ in
                    XCTAssertEqual(
                        assignment.selectedBackingKind,
                        .mlxArray,
                        "executor receives the typed" +
                        " assignment for stage \(stage)")
                    return 0
                },
                fallbackExecutor: { _, _ in
                    XCTFail(
                        "fallback must NOT fire when" +
                        " all stages have assignments")
                    return 0
                })
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 2)
        XCTAssertEqual(
            result.dispatchLedger.honoredAssignmentCount,
            2,
            "all 2 stages honored their assignments")
        XCTAssertEqual(
            result.dispatchLedger
                .unhonoredAssignmentCount, 0)
    }

    // MARK: - Mixed plan + partial assignments

    func testMixedPlanHonorsAvailableAssignments() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB),
            .sequential(.stageC)
        ])
        // Only stageB has an assignment
        let assignments = makeFullAssignmentLedger(
            stages: [.stageB],
            backing: .mlMultiArray)
        let routedFiredCounter = AsyncCounter()
        let fallbackFiredCounter = AsyncCounter()
        let result = await executor
            .executePlanWithAssignments(
                plan,
                request: makeRequest(),
                assignments: assignments,
                routedExecutor: { stage, _, _ in
                    XCTAssertEqual(stage, .stageB,
                        "routed executor only fires" +
                        " for stageB")
                    await routedFiredCounter.increment()
                    return 0
                },
                fallbackExecutor: { stage, _ in
                    XCTAssertNotEqual(stage, .stageB,
                        "fallback only fires for" +
                        " non-assigned stages")
                    await fallbackFiredCounter
                        .increment()
                    return 0
                })
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 3)
        XCTAssertEqual(
            result.dispatchLedger.honoredAssignmentCount,
            1)
        XCTAssertEqual(
            result.dispatchLedger
                .unhonoredAssignmentCount, 2)
        let routedCount = await routedFiredCounter.value
        let fallbackCount = await fallbackFiredCounter
            .value
        XCTAssertEqual(routedCount, 1,
            "routed executor fires exactly once")
        XCTAssertEqual(fallbackCount, 2,
            "fallback fires exactly twice")
    }

    // MARK: - Sequence index ordering preserved

    func testSequenceIndexOrderingPreserved() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB),
            .sequential(.stageC)
        ])
        let result = await executor
            .executePlanWithAssignments(
                plan,
                request: makeRequest(),
                assignments:
                    BASTurnRuntimePlanAssignmentLedger
                        .empty(turnID: "t1"),
                routedExecutor: { _, _, _ in 0 },
                fallbackExecutor: { _, _ in 0 })
        let indices = result.dispatchLedger.records
            .map { $0.sequenceIndex }
        XCTAssertEqual(indices, [0, 1, 2],
            "sequence indices must increment 0..N-1")
    }

    // MARK: - Helpers

    private func makeRequest() -> BASEBrainTurnRequest {
        return BASEBrainTurnRequest(
            userInput: "stub",
            deviceState: BASDeviceState(
                batteryLevel: 0.5,
                thermalLevel: .nominal,
                memoryFreeMB: 1024,
                networkState: .online,
                foregroundState: .foreground,
                cpuLoad: 0.1,
                gpuLoad: 0.0,
                npuAvailable: false,
                latencyBudgetMs: 100),
            hostID: "test.host",
            recordedAt: Date(timeIntervalSince1970: 1000))
    }

    private func makeFullAssignmentLedger(
        stages: [BASTurnRuntimeStage],
        backing: BASTensorBackingKind
    ) -> BASTurnRuntimePlanAssignmentLedger {
        var ledger =
            BASTurnRuntimePlanAssignmentLedger
                .empty(turnID: "t1")
        for (i, stage) in stages.enumerated() {
            let key: BASKernelKey?
            if backing == .cpuBytes {
                key = nil
            } else {
                key = BASKernelKey(
                    operation: .matMul,
                    dataType: .float16,
                    backingKind: backing)
            }
            let assignment =
                BASStageAcceleratorAssignment(
                    selectedBackingKind: backing,
                    selectedKernelKey: key,
                    costScore: 1.0,
                    thermalSnapshot: .nominal,
                    assignmentRationale: .aneSupported)
            let hint = BASStageAcceleratorHint(
                operation: .matMul,
                preferredDataType: .float16,
                batchSize: 1,
                sequenceLength: 1,
                latencyBudgetMs: 5)
            let record =
                BASTurnRuntimeStageAssignmentRecord(
                    stageRawValue: stage.rawValue,
                    hint: hint,
                    assignment: assignment,
                    sequenceIndex: i)
            ledger = ledger.appending(record)
        }
        return ledger
    }
}

// MARK: - Async counter helper

private actor AsyncCounter {
    private(set) var value: Int = 0
    func increment() {
        value += 1
    }
}
