// MARK: - BASNativeStageExecutorTests — chapter 四百二十六 / M1075

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

@Sendable
private func makeStubRequest() -> BASEBrainTurnRequest {
    BASEBrainTurnRequest(
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

final class BASNativeStageExecutorTests: XCTestCase {

    // MARK: - Single-stage executor produces typed record

    func testExecuteStageProducesTypedRecord() async {
        let executor = BASNativeStageExecutor()
        let record = await executor.executeStage(
            .stageA,
            request: makeStubRequest(),
            executor: { stage, _ in
                XCTAssertEqual(stage, .stageA)
                return "stage-a-output"
            })
        XCTAssertEqual(record.stage, .stageA)
        XCTAssertEqual(record.status, .completed)
        XCTAssertGreaterThanOrEqual(record.durationMs, 0)
    }

    // MARK: - executePlan walks all 18 stages

    func testExecutePlanWalksAllCanonicalStages() async {
        let executor = BASNativeStageExecutor()
        let counter = AsyncCounter()
        let ledger = await executor.executePlan(
            BASTurnRuntimeStagePlan.canonical(),
            request: makeStubRequest(),
            executor: { _, _ in
                await counter.increment()
                return 0
            })
        // 16 plan steps containing 18 stages total
        XCTAssertEqual(ledger.stageCount, 18)
        let invocations = await counter.value
        XCTAssertEqual(invocations, 18)
    }

    // MARK: - executePlan ledger matches canonical order

    func testExecutePlanLedgerStagesMatchCanonicalOrder() async {
        let executor = BASNativeStageExecutor()
        let plan = BASTurnRuntimeStagePlan.canonical()
        let ledger = await executor.executePlan(
            plan,
            request: makeStubRequest(),
            executor: { _, _ in 0 })
        let recordedStages = ledger.records.map { $0.stage }
        XCTAssertEqual(
            recordedStages, plan.orderedStages,
            "ledger stage order must match plan canonical " +
            "order")
    }

    // MARK: - executePlan ledger is fully complete

    func testExecutePlanProducesCompleteLedger() async {
        let executor = BASNativeStageExecutor()
        let ledger = await executor.executePlan(
            BASTurnRuntimeStagePlan.canonical(),
            request: makeStubRequest(),
            executor: { _, _ in 0 })
        XCTAssertTrue(ledger.isComplete)
        XCTAssertEqual(ledger.failedStageCount, 0)
    }

    // MARK: - Plan-ledger coherence holds

    func testExecutedPlanIsCoherentWithCanonical() async {
        let executor = BASNativeStageExecutor()
        let ledger = await executor.executePlan(
            BASTurnRuntimeStagePlan.canonical(),
            request: makeStubRequest(),
            executor: { _, _ in 0 })
        let coherence = BASTurnRuntimePlanLedgerCoherence
            .canonicalCoherence(ledger: ledger)
        XCTAssertTrue(coherence.isFullyCoherent,
            "executor walking the canonical plan must " +
            "produce a coherent ledger")
    }

    // MARK: - Determinism — sequential walker produces
    // same canonical-order ledger

    func testExecutePlanIsDeterministic() async {
        let executor = BASNativeStageExecutor()
        let l1 = await executor.executePlan(
            BASTurnRuntimeStagePlan.canonical(),
            request: makeStubRequest(),
            executor: { _, _ in 0 })
        let l2 = await executor.executePlan(
            BASTurnRuntimeStagePlan.canonical(),
            request: makeStubRequest(),
            executor: { _, _ in 0 })
        // Stage order matches between runs (durations may
        // vary)
        let stages1 = l1.records.map { $0.stage }
        let stages2 = l2.records.map { $0.stage }
        XCTAssertEqual(stages1, stages2)
    }
}

private actor AsyncCounter {
    private(set) var value: Int = 0
    func increment() {
        value += 1
    }
}
