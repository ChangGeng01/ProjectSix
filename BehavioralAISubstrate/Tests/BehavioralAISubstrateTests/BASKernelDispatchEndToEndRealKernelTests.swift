// MARK: - BASKernelDispatchEndToEndRealKernelTests
// chapter 四百七十五 / M1278 — closes EchoKernel placeholder
//
// Sibling of M1274 BASKernelDispatchEndToEndIntegrationTests
// — same full-chain composition test,but uses REAL
// BASMPSGraphMatMulKernel instead of EchoKernel。
//
// Before M1278:end-to-end chain proven with EchoKernel
// stub (which echoes inputs to outputs)。 After M1278:
// end-to-end chain proven with REAL GPU dispatch through
// MPSMatrixMultiplication, with NUMERICAL CORRECTNESS
// asserted at the executor's output boundary。
//
// This closes the chapter 474 M1274 plannedFutureCut item:
//   "chapter 478+: write input builders for canonical
//    stages so MPSGraph kernels see real tensors (replace
//    EchoKernel test fixtures with production kernels)"
//
// shipped early (chapter 475)。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

private actor RealKernelOutcomeBox {
    private(set) var outcomes:
        [BASKernelRegistryDispatchOutcome] = []
    private(set) var results: [Data] = []
    func append(
        outcome: BASKernelRegistryDispatchOutcome
    ) {
        outcomes.append(outcome)
    }
    func appendResult(_ data: Data) {
        results.append(data)
    }
}

@Sendable
private func makeRealKernelRequest()
    -> BASEBrainTurnRequest
{
    BASEBrainTurnRequest(
        userInput: "real-kernel",
        deviceState: BASDeviceState(
            batteryLevel: 0.9,
            thermalLevel: .nominal,
            memoryFreeMB: 4096,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.1,
            gpuLoad: 0.1,
            npuAvailable: true,
            latencyBudgetMs: 50),
        hostID: "test.real-kernel",
        recordedAt: Date(timeIntervalSince1970: 3000))
}

final class BASKernelDispatchEndToEndRealKernelTests:
    XCTestCase
{

    func testFullChainDispatchesRealMPSGraphMatMul()
        async throws
    {
        // Construct real MPSGraph kernel
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip(
                "Metal unavailable — full real-kernel" +
                " end-to-end test skipped")
        }

        // Register the real kernel
        let registry = BASMetalKernelRegistry()
        await registry.register(kernel)

        // Build scheduler bound to registry
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)

        // Use nominalAppleSilicon capability so the
        // scheduler picks the metalBuffer-backed kernel
        let capability = BASANECapability
            .nominalAppleSilicon()

        // Build hint + assignment
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 50,
            preference: .balanced)
        let assignment = await scheduler.assign(
            hint: hint,
            capability: capability,
            thermal: .nominal)
        XCTAssertNotNil(
            assignment.selectedKernelKey,
            "scheduler must pick the registered" +
            " matMul kernel key")

        // Build the assignment ledger
        var ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "real-kernel-turn")
        ledger = ledger.appending(
            BASTurnRuntimeStageAssignmentRecord(
                stageRawValue:
                    BASTurnRuntimeStage.stageA.rawValue,
                hint: hint,
                assignment: assignment,
                sequenceIndex: 0))

        // Build the routed executor:dispatches the real
        // matMul through the registry。 Input builder
        // produces 2×2 inputs。 Output handler captures
        // the result Data for numerical assertion below。
        let box = RealKernelOutcomeBox()
        let routed = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return BASCanonicalKernelInputBuilders
                        .matMul(
                            a: [1, 2, 3, 4],
                            b: [5, 6, 7, 8],
                            M: 2, K: 2, N: 2)
                },
                outcomeHandler: { _, outcome in
                    await box.append(outcome: outcome)
                },
                fallback: { _, _, _ in
                    XCTFail(
                        "fallback must not fire when" +
                        " kernel is registered + key" +
                        " is set + inputs are valid")
                    return ()
                })

        // Execute plan
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA)
        ])

        let (_, dispatchLedger) = await executor
            .executePlanWithAssignments(
                plan,
                request: makeRealKernelRequest(),
                assignments: ledger,
                routedExecutor: { stage,
                                  assignment,
                                  request in
                    let result = await routed(
                        stage, assignment, request)
                    if let r = result as?
                        BASKernelDispatchResult
                    {
                        await box.appendResult(
                            r.outputs.payloads[0])
                    }
                    return result
                },
                fallbackExecutor: { _, _ in () })

        // Assert outcome was .dispatched
        let outcomes = await box.outcomes
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0], .dispatched)

        // Assert dispatch ledger honored 1 assignment
        XCTAssertEqual(
            dispatchLedger.honoredAssignmentCount, 1)

        // Assert numerical correctness:result must equal
        // [[19,22],[43,50]] flattened = [19, 22, 43, 50]
        let results = await box.results
        XCTAssertEqual(results.count, 1,
            "exactly 1 kernel output payload expected")
        let output = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                results[0], elementCount: 4)
        let expected: [Float] = [19, 22, 43, 50]
        for (idx, v) in output.enumerated() {
            XCTAssertEqual(
                v, expected[idx], accuracy: 1e-5,
                "stage matMul output[\(idx)] = \(v);" +
                " expected \(expected[idx])")
        }
    }
}
