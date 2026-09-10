// MARK: - BASStageAcceleratorAssignmentTests
// chapter 四百三十二 / M1102

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASStageAcceleratorAssignmentTests:
    XCTestCase
{

    // MARK: - Rationale enum

    func testRationaleRawValues() {
        XCTAssertEqual(
            BASAssignmentRationale.aneSupported.rawValue,
            "ane-supported")
        XCTAssertEqual(
            BASAssignmentRationale
                .gpuFallbackAneUnsupported.rawValue,
            "gpu-fallback-ane-unsupported")
        XCTAssertEqual(
            BASAssignmentRationale.thermalDowngrade
                .rawValue,
            "thermal-downgrade")
        XCTAssertEqual(
            BASAssignmentRationale.cpuLatencyBudgetMiss
                .rawValue,
            "cpu-latency-budget-miss")
        XCTAssertEqual(
            BASAssignmentRationale.cpuNoKernelRegistered
                .rawValue,
            "cpu-no-kernel-registered")
        XCTAssertEqual(
            BASAssignmentRationale.allCases.count, 5)
    }

    // MARK: - Direct init persists fields

    func testDirectInitPersistsAllFields() {
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float16,
            backingKind: .mlxArray)
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .mlxArray,
            selectedKernelKey: key,
            costScore: 1.5,
            thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
        XCTAssertEqual(
            assignment.selectedBackingKind, .mlxArray)
        XCTAssertEqual(
            assignment.selectedKernelKey, key)
        XCTAssertEqual(assignment.costScore, 1.5)
        XCTAssertEqual(
            assignment.thermalSnapshot, .nominal)
        XCTAssertEqual(
            assignment.assignmentRationale,
            .aneSupported)
    }

    // MARK: - CPU fallback has nil kernel key

    func testCPUFallbackHasNilKey() {
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .cpuBytes,
            selectedKernelKey: nil,
            costScore: 50.0,
            thermalSnapshot: .critical,
            assignmentRationale:
                .cpuNoKernelRegistered)
        XCTAssertNil(assignment.selectedKernelKey)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .mlMultiArray,
            selectedKernelKey: BASKernelKey(
                operation: .attention,
                dataType: .float16,
                backingKind: .mlMultiArray),
            costScore: 0.42,
            thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(assignment)
        let decoded = try JSONDecoder()
            .decode(
                BASStageAcceleratorAssignment.self,
                from: encoded)
        XCTAssertEqual(decoded, assignment)
    }

    // MARK: - Equality + hashability for cache keys

    func testEqualAssignmentsAreEqual() {
        let a1 = BASStageAcceleratorAssignment(
            selectedBackingKind: .cpuBytes,
            selectedKernelKey: nil,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale:
                .cpuNoKernelRegistered)
        let a2 = BASStageAcceleratorAssignment(
            selectedBackingKind: .cpuBytes,
            selectedKernelKey: nil,
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale:
                .cpuNoKernelRegistered)
        XCTAssertEqual(a1, a2)
        XCTAssertEqual(a1.hashValue, a2.hashValue)
    }
}
