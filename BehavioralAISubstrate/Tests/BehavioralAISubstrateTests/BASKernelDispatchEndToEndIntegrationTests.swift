// MARK: - BASKernelDispatchEndToEndIntegrationTests
// chapter 四百七十四 / M1274 — END-TO-END HOT PATH INTEGRATION
//
// First test in the substrate that wires the FULL hot-path
// chain end-to-end:
//
//   BASStageAcceleratorHint (caller's typed compute hint)
//     ↓
//   BASHardwareAwareScheduler.assign(...) (chooses backing
//     + kernel key per hint + capability + thermal)
//     ↓
//   BASTurnRuntimePlanAssignmentLedger (carries per-stage
//     assignment for the turn)
//     ↓
//   BASNativeStageExecutor.executePlanWithAssignments(
//     ..., routedExecutor: makeRoutedExecutor(...))
//     ↓
//   BASKernelRegistryDispatchExecutor.makeRoutedExecutor
//     (M1273 — dispatches through registry when key
//     present + kernel registered + inputs buildable)
//     ↓
//   BASMetalKernelRegistry.dispatch(key:, inputs:)
//     (calls the kernel's evaluate(inputs:))
//
// Before M1274 no test exercised this full chain。 M1272
// closed the ANE live-binding gap;M1273 wired the
// registry-dispatch executor;M1274 PROVES they compose
// end-to-end + the scheduler's `selectedKernelKey` actually
// drives dispatch routing。
//
// ## What the test asserts
//
//   - 4-stage plan walks all 4 stages
//   - Each stage's hint is matched by a registered kernel
//   - All 4 dispatches produce `.dispatched` outcome
//   - Stage ledger reports 4 completed stage records
//   - Dispatch ledger reports 4 assignment-honored
//     entries (assignments propagated through executor)
//   - Replay determinism — repeat run produces identical
//     outcome sequence (chapter 三百九二)

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

private actor IntegrationOutcomeBox {
    private(set) var outcomes:
        [(BASTurnRuntimeStage,
          BASKernelRegistryDispatchOutcome)] = []
    func append(
        stage: BASTurnRuntimeStage,
        outcome: BASKernelRegistryDispatchOutcome
    ) {
        outcomes.append((stage, outcome))
    }
}

private struct IntegrationEchoKernel: BASMetalKernel {
    let key: BASKernelKey
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 100)
    }
}

@Sendable
private func makeIntegrationRequest() -> BASEBrainTurnRequest
{
    BASEBrainTurnRequest(
        userInput: "integration",
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
        hostID: "test.integration",
        recordedAt: Date(timeIntervalSince1970: 2000))
}

final class BASKernelDispatchEndToEndIntegrationTests:
    XCTestCase
{

    /// 4 stages × 4 ops。 Maps each plan stage to the
    /// neural op the integration test routes through。
    /// Order matters — assignments are looked up by stage
    /// raw value。
    private static let stagesByOp:
        [(stage: BASTurnRuntimeStage, op: BASNeuralOp)] = [
        (.stageA, .matMul),
        (.stageC, .rmsNorm),
        (.stageJ, .attention),
        (.stageK, .rotaryEmbedding)
    ]

    /// Build the registry pre-populated with one echo
    /// kernel per integration op + dtype + metalBuffer
    /// backing。 The scheduler checks for kernels under
    /// .mlxArray / .mlMultiArray / .metalBuffer (NOT
    /// .cpuBytes — the latter is always the CPU fallback
    /// candidate)。 Registering under .metalBuffer makes
    /// the scheduler add it as a candidate and return a
    /// non-nil selectedKernelKey。
    private func makeIntegrationRegistry() async
        -> BASMetalKernelRegistry
    {
        let registry = BASMetalKernelRegistry()
        for entry in Self.stagesByOp {
            let key = BASKernelKey(
                operation: entry.op,
                dataType: .float32,
                backingKind: .metalBuffer)
            await registry.register(
                IntegrationEchoKernel(key: key))
        }
        return registry
    }

    /// Build per-stage hints with consistent budgets。
    private func makeHint(
        op: BASNeuralOp
    ) -> BASStageAcceleratorHint {
        return BASStageAcceleratorHint(
            operation: op,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 50,
            preference: .balanced)
    }

    /// Build a 4-stage plan as 4 sequential steps。
    /// Matches the sequential-baseline pattern used by
    /// BASNativeStageExecutorTests so dispatch ledger
    /// records line up one-to-one with stages。
    private func make4StagePlan()
        -> BASTurnRuntimeStagePlan
    {
        let steps: [BASTurnRuntimeStageStep] = [
            .sequential(.stageA),
            .sequential(.stageC),
            .sequential(.stageJ),
            .sequential(.stageK)
        ]
        return BASTurnRuntimeStagePlan(steps: steps)
    }

    // MARK: - Full chain test

    func testFullKernelDispatchChainRoutesEveryStage()
        async throws
    {
        // 1. Registry with 4 kernels
        let registry = await makeIntegrationRegistry()
        let kernelCount = await registry.kernelCount
        XCTAssertEqual(
            kernelCount, 4,
            "registry must have 4 registered kernels")

        // 2. Scheduler bound to registry
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)

        // 3. Capability — use nominalAppleSilicon so the
        // scheduler sees all 4 integration ops as
        // supported。 Conservative capability has empty
        // supportedOps + applies opPenalty=1000 which
        // would push the scheduler to .cpuBytes (no key
        // assigned) instead of picking the metalBuffer
        // kernel we registered。 nominalAppleSilicon
        // gives opSupported=true so the +1000 penalty
        // drops and metalBuffer wins。
        let capability = BASANECapability
            .nominalAppleSilicon()

        // 4. Build assignments via scheduler
        var assignmentLedger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "integration-turn")
        var index = 0
        for entry in Self.stagesByOp {
            let hint = makeHint(op: entry.op)
            let assignment = await scheduler.assign(
                hint: hint,
                capability: capability,
                thermal: .nominal)
            let record = BASTurnRuntimeStageAssignmentRecord(
                stageRawValue: entry.stage.rawValue,
                hint: hint,
                assignment: assignment,
                sequenceIndex: index)
            assignmentLedger = assignmentLedger
                .appending(record)
            index += 1
        }
        XCTAssertEqual(
            assignmentLedger.recordCount, 4,
            "ledger must hold 4 stage assignments")
        // Every assignment must have a non-nil
        // selectedKernelKey (registered for cpu backing)
        for record in assignmentLedger.records {
            XCTAssertNotNil(
                record.assignment.selectedKernelKey,
                "stage \(record.stageRawValue) must" +
                " carry a kernel key when registry has" +
                " a matching kernel registered")
        }

        // 5. Build the routed-executor closure
        let box = IntegrationOutcomeBox()
        let routedExecutor = BASKernelRegistryDispatchExecutor
            .makeRoutedExecutor(
                registry: registry,
                inputBuilder: { _, _, _ in
                    return BASKernelInputs.empty
                },
                outcomeHandler: { stage, outcome in
                    await box.append(
                        stage: stage,
                        outcome: outcome)
                },
                fallback: { _, _, _ in
                    XCTFail(
                        "fallback must not fire when" +
                        " every assignment is honored")
                    return ()
                })

        // 6. Execute the plan
        let executor = BASNativeStageExecutor()
        let plan = make4StagePlan()
        let (stageLedger, dispatchLedger) = await executor
            .executePlanWithAssignments(
                plan,
                request: makeIntegrationRequest(),
                assignments: assignmentLedger,
                routedExecutor: routedExecutor,
                fallbackExecutor: { _, _ in
                    XCTFail(
                        "fallbackExecutor must not fire")
                    return ()
                })

        // 7. Assert stage ledger
        XCTAssertEqual(
            stageLedger.stageCount, 4,
            "stage ledger must record 4 stages")

        // 8. Assert dispatch ledger
        XCTAssertEqual(
            dispatchLedger.executionCount, 4,
            "dispatch ledger must record 4 entries")
        XCTAssertEqual(
            dispatchLedger.honoredAssignmentCount, 4,
            "each entry must honor its assignment")
        XCTAssertEqual(
            dispatchLedger.unhonoredAssignmentCount, 0,
            "no entry should fall back to default" +
            " executor when every stage has an" +
            " assignment in the ledger")

        // 9. Assert all 4 outcomes were .dispatched
        let outcomes = await box.outcomes
        XCTAssertEqual(
            outcomes.count, 4,
            "outcome handler must fire 4 times")
        for (_, outcome) in outcomes {
            XCTAssertEqual(
                outcome, .dispatched,
                "every stage must take dispatched path")
        }
    }

    // MARK: - Determinism

    func testFullChainIsReplayDeterministic() async throws {
        // chapter 三百九二 — repeat the full chain with
        // identical inputs,assert outcome sequence is
        // identical。
        let registry = await makeIntegrationRegistry()
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let capability = BASANECapability
            .nominalAppleSilicon()

        var firstRun: [BASKernelRegistryDispatchOutcome] = []
        var secondRun: [BASKernelRegistryDispatchOutcome] = []

        for run in 0..<2 {
            var ledger = BASTurnRuntimePlanAssignmentLedger
                .empty(turnID: "replay-\(run)")
            var idx = 0
            for entry in Self.stagesByOp {
                let hint = makeHint(op: entry.op)
                let a = await scheduler.assign(
                    hint: hint,
                    capability: capability,
                    thermal: .nominal)
                ledger = ledger.appending(
                    BASTurnRuntimeStageAssignmentRecord(
                        stageRawValue:
                            entry.stage.rawValue,
                        hint: hint,
                        assignment: a,
                        sequenceIndex: idx))
                idx += 1
            }
            let box = IntegrationOutcomeBox()
            let routed = BASKernelRegistryDispatchExecutor
                .makeRoutedExecutor(
                    registry: registry,
                    inputBuilder: { _, _, _ in
                        return BASKernelInputs.empty
                    },
                    outcomeHandler: { _, o in
                        await box.append(
                            stage: .stageA, outcome: o)
                    },
                    fallback: { _, _, _ in () })
            let executor = BASNativeStageExecutor()
            _ = await executor
                .executePlanWithAssignments(
                    make4StagePlan(),
                    request: makeIntegrationRequest(),
                    assignments: ledger,
                    routedExecutor: routed,
                    fallbackExecutor: { _, _ in () })
            let captured = await box.outcomes
                .map { $0.1 }
            if run == 0 {
                firstRun = captured
            } else {
                secondRun = captured
            }
        }
        XCTAssertEqual(
            firstRun, secondRun,
            "Replay-determinism — same inputs must" +
            " produce identical outcome sequence")
        XCTAssertEqual(firstRun.count, 4)
    }

    // MARK: - Scheduler picks no kernel when registry empty

    func testSchedulerNoKernelWhenRegistryEmpty() async {
        let emptyRegistry = BASMetalKernelRegistry()
        let scheduler = BASHardwareAwareScheduler(
            registry: emptyRegistry)
        let assignment = await scheduler.assign(
            hint: makeHint(op: .matMul),
            capability: BASANECapability.conservative(
                thermalSnapshot: .nominal),
            thermal: .nominal)
        XCTAssertNil(
            assignment.selectedKernelKey,
            "empty registry → no kernel chosen")
        XCTAssertEqual(
            assignment.assignmentRationale,
            .cpuNoKernelRegistered)
    }
}
