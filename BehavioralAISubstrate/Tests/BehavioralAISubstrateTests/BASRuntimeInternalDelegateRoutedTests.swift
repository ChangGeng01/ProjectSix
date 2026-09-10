// MARK: - BASRuntimeInternalDelegateRoutedTests
// chapter 四百三十七 / M1125-M1126

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASRuntimeInternalDelegateRoutedTests:
    XCTestCase
{

    // MARK: - Empty assignments → all fall through

    func testRunScaffoldedWithEmptyAssignmentsAllFallThrough()
        async
    {
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: BASTurnRuntimeStagePlan(steps: [
                .sequential(.stageA),
                .sequential(.stageB)
            ]))
        let result = await delegate
            .runScaffoldedWithAssignments(
                request: makeRequest(),
                assignments:
                    BASTurnRuntimePlanAssignmentLedger
                        .empty(turnID: "t1"),
                routedExecutor: { _, _, _ in
                    XCTFail(
                        "routed executor must NOT fire" +
                        " when assignments empty")
                    return 0
                },
                fallbackExecutor: { _, _ in 0 })
        XCTAssertEqual(
            result.stageLedger.records.count, 2)
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 2)
        XCTAssertEqual(
            result.dispatchLedger
                .honoredAssignmentCount, 0)
        XCTAssertEqual(
            result.dispatchLedger
                .unhonoredAssignmentCount, 2)
    }

    // MARK: - All assignments → all honored

    func testRunScaffoldedWithFullAssignmentsAllHonored()
        async
    {
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: BASTurnRuntimeStagePlan(steps: [
                .sequential(.stageA),
                .sequential(.stageB)
            ]))
        let assignments = makeAssignmentLedger(
            stages: [.stageA, .stageB])
        let result = await delegate
            .runScaffoldedWithAssignments(
                request: makeRequest(),
                assignments: assignments,
                routedExecutor: { _, assignment, _ in
                    XCTAssertEqual(
                        assignment.selectedBackingKind,
                        .mlxArray)
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
            result.dispatchLedger
                .honoredAssignmentCount, 2)
        XCTAssertEqual(
            result.dispatchLedger
                .unhonoredAssignmentCount, 0)
    }

    // MARK: - Default closures

    func testDefaultClosuresAreNoOp() async {
        // Both routedExecutor and fallbackExecutor have
        // defaults returning 0 — exercise the path
        // without explicit closures
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: BASTurnRuntimeStagePlan(steps: [
                .sequential(.stageA)
            ]))
        let result = await delegate
            .runScaffoldedWithAssignments(
                request: makeRequest(),
                assignments:
                    BASTurnRuntimePlanAssignmentLedger
                        .empty(turnID: "t1"))
        XCTAssertEqual(
            result.stageLedger.records.count, 1)
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 1)
    }

    // MARK: - Stage ledger has one record per stage

    func testStageLedgerHasOneRecordPerStage() async {
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: BASTurnRuntimeStagePlan(steps: [
                .sequential(.stageA),
                .sequential(.stageB),
                .sequential(.stageC)
            ]))
        let result = await delegate
            .runScaffoldedWithAssignments(
                request: makeRequest(),
                assignments:
                    BASTurnRuntimePlanAssignmentLedger
                        .empty(turnID: "t1"))
        XCTAssertEqual(
            result.stageLedger.records.count, 3)
    }

    // MARK: - Default delegate stagePlan canonical

    func testDefaultDelegateUsesCanonicalPlanByDefault()
        async
    {
        let delegate = BASRuntimeInternalDelegate()
        let result = await delegate
            .runScaffoldedWithAssignments(
                request: makeRequest(),
                assignments:
                    BASTurnRuntimePlanAssignmentLedger
                        .empty(turnID: "t1"))
        // Canonical plan ships 18 stages
        XCTAssertEqual(
            result.stageLedger.stageCount, 18)
        XCTAssertEqual(
            result.dispatchLedger.executionCount, 18)
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

    private func makeAssignmentLedger(
        stages: [BASTurnRuntimeStage]
    ) -> BASTurnRuntimePlanAssignmentLedger {
        var ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t1")
        for (i, stage) in stages.enumerated() {
            let assignment =
                BASStageAcceleratorAssignment(
                    selectedBackingKind: .mlxArray,
                    selectedKernelKey: BASKernelKey(
                        operation: .matMul,
                        dataType: .float16,
                        backingKind: .mlxArray),
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
