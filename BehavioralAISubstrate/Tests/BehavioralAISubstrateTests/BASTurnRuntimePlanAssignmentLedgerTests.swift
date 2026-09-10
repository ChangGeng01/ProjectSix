// MARK: - BASTurnRuntimePlanAssignmentLedgerTests
// chapter 四百三十五 / M1117

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASTurnRuntimePlanAssignmentLedgerTests:
    XCTestCase
{

    // MARK: - Empty + unwired

    func testEmptyLedgerHasZeroRecords() {
        let l = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "turn-1")
        XCTAssertEqual(l.recordCount, 0)
        XCTAssertEqual(l.acceleratedRecordCount, 0)
        XCTAssertEqual(l.uniqueStageCount, 0)
        XCTAssertEqual(l.turnID, "turn-1")
    }

    func testUnwiredSentinelHasEmptyTurnID() {
        let l = BASTurnRuntimePlanAssignmentLedger
            .unwired
        XCTAssertEqual(l.turnID, "")
        XCTAssertEqual(l.recordCount, 0)
    }

    // MARK: - appending(_:)

    func testAppendingProducesNewLedgerWithRecord() {
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float16,
            backingKind: .mlxArray)
        let assignment =
            BASStageAcceleratorAssignment(
                selectedBackingKind: .mlxArray,
                selectedKernelKey: key,
                costScore: 0.5,
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
                stageRawValue: "stage-h-risk-l11",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0)
        let base = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t1")
        let updated = base.appending(record)
        XCTAssertEqual(base.recordCount, 0,
            "appending must not mutate base")
        XCTAssertEqual(updated.recordCount, 1)
        XCTAssertEqual(
            updated.acceleratedRecordCount, 1,
            "mlxArray backing counts as accelerated")
    }

    // MARK: - acceleratedRecordCount

    func testCPUBackingNotAccelerated() {
        let assignment =
            BASStageAcceleratorAssignment(
                selectedBackingKind: .cpuBytes,
                selectedKernelKey: nil,
                costScore: 50.0,
                thermalSnapshot: .critical,
                assignmentRationale:
                    .cpuNoKernelRegistered)
        let hint = BASStageAcceleratorHint(
            operation: .softmax,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 100)
        let record =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-x",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0)
        let l = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t1")
            .appending(record)
        XCTAssertEqual(l.recordCount, 1)
        XCTAssertEqual(l.acceleratedRecordCount, 0,
            "CPU backing does not count as accelerated")
    }

    // MARK: - uniqueStageCount

    func testUniqueStageCountDeduplicates() {
        let assignment =
            BASStageAcceleratorAssignment(
                selectedBackingKind: .cpuBytes,
                selectedKernelKey: nil,
                costScore: 1.0,
                thermalSnapshot: .nominal,
                assignmentRationale:
                    .cpuNoKernelRegistered)
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1)
        let r1 =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-a",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0)
        let r2 =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-a",  // dup
                hint: hint,
                assignment: assignment,
                sequenceIndex: 1)
        let r3 =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-b",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 2)
        let l = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t1")
            .appending(r1)
            .appending(r2)
            .appending(r3)
        XCTAssertEqual(l.recordCount, 3)
        XCTAssertEqual(l.uniqueStageCount, 2,
            "stage-a + stage-b = 2 unique stages")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let assignment =
            BASStageAcceleratorAssignment(
                selectedBackingKind: .mlMultiArray,
                selectedKernelKey: BASKernelKey(
                    operation: .attention,
                    dataType: .float16,
                    backingKind: .mlMultiArray),
                costScore: 0.42,
                thermalSnapshot: .fair,
                assignmentRationale: .aneSupported)
        let hint = BASStageAcceleratorHint(
            operation: .attention,
            preferredDataType: .float16,
            batchSize: 8,
            sequenceLength: 256,
            latencyBudgetMs: 5)
        let record =
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: "stage-attention",
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0)
        let original =
            BASTurnRuntimePlanAssignmentLedger
                .empty(turnID: "t-codable")
                .appending(record)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASTurnRuntimePlanAssignmentLedger.self,
                from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equality + determinism

    func testEqualLedgersAreEqual() {
        let l1 = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-1")
        let l2 = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-1")
        XCTAssertEqual(l1, l2)
    }
}
