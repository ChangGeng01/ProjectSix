// MARK: - BASThermalAwareKernelSelectionPolicyTests
// chapter 五百 / M1378 — thermal-aware policy tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASThermalAwareKernelSelectionPolicyTests:
    XCTestCase
{

    // MARK: - 1) Routing preference enum has 3 cases

    func testRoutingPreferenceHasThreeCases() {
        let cases = BASKernelRoutingPreference.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.aneNative))
        XCTAssertTrue(cases.contains(.gpuMPSGraph))
        XCTAssertTrue(cases.contains(.cpuStub))
    }

    // MARK: - 2) Rule 1: critical thermal → CPU stub

    func testCriticalThermalAlwaysRoutesToCPU() {
        for op in BASNeuralOp.allCases {
            for priority in BASAcceleratorPriority
                .allCases
            {
                let routing =
                    BASThermalAwareKernelSelectionPolicy
                    .preferredRouting(
                        for: op,
                        thermalState: .critical,
                        anePriority: priority)
                XCTAssertEqual(routing, .cpuStub,
                    "rule 1: thermal=.critical MUST" +
                    " route any op + priority to .cpuStub" +
                    " (got \(routing) for op \(op) +" +
                    " priority \(priority))")
            }
        }
    }

    // MARK: - 3) Rule 2: fallback-required op → CPU stub

    func testSSMScanAlwaysRoutesToCPUStub() {
        // ssmScan is the only .fallbackRequired op
        for thermalState in
            BASCapabilityThermalSnapshot.allCases
        {
            if thermalState == .critical { continue }
            for priority in BASAcceleratorPriority
                .allCases
            {
                let routing =
                    BASThermalAwareKernelSelectionPolicy
                    .preferredRouting(
                        for: .ssmScan,
                        thermalState: thermalState,
                        anePriority: priority)
                XCTAssertEqual(routing, .cpuStub,
                    "rule 2: ssmScan (fallback-required" +
                    " tier) MUST route to .cpuStub" +
                    " regardless of thermal/priority")
            }
        }
    }

    // MARK: - 4) Rule 3: cpuOnly priority → CPU stub

    func testCPUOnlyPriorityRoutesToCPU() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .matMul,
                thermalState: .nominal,
                anePriority: .cpuOnly)
        XCTAssertEqual(routing, .cpuStub)
    }

    // MARK: - 5) Rule 4: gpuOnly priority → GPU

    func testGPUOnlyPriorityRoutesToGPU() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .matMul,
                thermalState: .nominal,
                anePriority: .gpuOnly)
        XCTAssertEqual(routing, .gpuMPSGraph)
    }

    // MARK: - 6) Rule 5: serious thermal + ANE-native → GPU

    func testSeriousThermalForANEOpRoutesToGPU() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .matMul, // ANE-native
                thermalState: .serious,
                anePriority: .aneFirst)
        XCTAssertEqual(routing, .gpuMPSGraph,
            "rule 5: serious thermal + ANE-native op" +
            " MUST fall back to GPU (ANE dispatch" +
            " overhead exceeds savings)")
    }

    // MARK: - 7) Rule 6: ANE-native + aneFirst → ANE

    func testANENativeAtNominalThermalRoutesToANE() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .matMul, // ANE-native
                thermalState: .nominal,
                anePriority: .aneFirst)
        XCTAssertEqual(routing, .aneNative)

        let attentionRouting =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .attention, // ANE-native
                thermalState: .nominal,
                anePriority: .aneFirst)
        XCTAssertEqual(attentionRouting, .aneNative)
    }

    // MARK: - 8) Rule 7: default → GPU MPSGraph

    func testMPSGraphNativeOpRoutesToGPU() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .rmsNorm, // mpsgraph-native
                thermalState: .nominal,
                anePriority: .aneFirst)
        XCTAssertEqual(routing, .gpuMPSGraph,
            "rule 7: mpsgraph-native op routes to GPU" +
            " regardless of priority")
    }

    // MARK: - 9) Fair thermal preserves rule 6

    func testFairThermalPreservesANERouting() {
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: .matMul,
                thermalState: .fair,
                anePriority: .aneFirst)
        XCTAssertEqual(routing, .aneNative,
            "fair thermal is NOT serious;ANE routing" +
            " preserved for ANE-native ops")
    }

    // MARK: - 10) HONEST scope flag pinned

    func testConsultedByExecutorIsFalse() {
        XCTAssertFalse(
            BASThermalAwareKernelSelectionPolicy
                .consultedByExecutorInProduction)
    }

    // MARK: - 11) Documentation table is non-empty

    func testDocumentationTableIsComplete() {
        let docs =
            BASThermalAwareKernelSelectionPolicy
                .decisionRulesDocumentation
        XCTAssertEqual(docs.count, 7,
            "all 7 decision rules MUST be documented")
        for doc in docs {
            XCTAssertFalse(doc.isEmpty)
        }
    }

    // MARK: - 12) Determinism

    func testPolicyIsDeterministic() {
        for op in BASNeuralOp.allCases {
            let r1 = BASThermalAwareKernelSelectionPolicy
                .preferredRouting(
                    for: op,
                    thermalState: .nominal,
                    anePriority: .aneFirst)
            let r2 = BASThermalAwareKernelSelectionPolicy
                .preferredRouting(
                    for: op,
                    thermalState: .nominal,
                    anePriority: .aneFirst)
            XCTAssertEqual(r1, r2)
        }
    }
}
