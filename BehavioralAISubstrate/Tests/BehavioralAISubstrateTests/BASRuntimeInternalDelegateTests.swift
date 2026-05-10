// MARK: - BASRuntimeInternalDelegateTests — chapter 四百二十七 / M1080

import XCTest
@testable import BASHostKit
@testable import BASPolicy
@testable import BASRuntimeCore

@Sendable
private func makeStubRequest() -> BASEBrainTurnRequest {
    BASEBrainTurnRequest(
        userInput: "stub-radical",
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

final class BASRuntimeInternalDelegateTests: XCTestCase {

    // MARK: - Default init wires identity executors

    func testDefaultInitWiresIdentityExecutors() async {
        let delegate = BASRuntimeInternalDelegate()
        // Identity-default executors compose without crashing
        let ledger = await delegate.runScaffolded(
            request: makeStubRequest())
        // Canonical plan has 18 stages
        XCTAssertEqual(ledger.stageCount, 18,
            "delegate's runScaffolded must walk all 18 " +
            "canonical stages via M1075 native executor")
    }

    // MARK: - Scaffolded run produces complete ledger

    func testRunScaffoldedProducesCompleteLedger() async {
        let delegate = BASRuntimeInternalDelegate()
        let ledger = await delegate.runScaffolded(
            request: makeStubRequest())
        XCTAssertTrue(ledger.isComplete,
            "ledger must cover all 18 canonical stages")
        XCTAssertEqual(ledger.failedStageCount, 0)
    }

    // MARK: - Coherence query verifies plan-ledger alignment

    func testCoherenceQueryAlignsWithCanonicalPlan() async {
        let delegate = BASRuntimeInternalDelegate()
        let ledger = await delegate.runScaffolded(
            request: makeStubRequest())
        let coherence = await delegate.coherence(
            with: ledger)
        XCTAssertTrue(coherence.isFullyCoherent,
            "delegate's canonical plan + executed ledger" +
            " must be coherent")
    }

    // MARK: - Determinism — same request → same ledger structure

    func testRunScaffoldedIsDeterministic() async {
        let d1 = BASRuntimeInternalDelegate()
        let d2 = BASRuntimeInternalDelegate()
        let l1 = await d1.runScaffolded(
            request: makeStubRequest())
        let l2 = await d2.runScaffolded(
            request: makeStubRequest())
        // Stage order matches between runs (durations may
        // vary by wall-clock)
        XCTAssertEqual(
            l1.records.map { $0.stage },
            l2.records.map { $0.stage })
    }

    // MARK: - Custom executor overrides accepted

    func testCustomExecutorOverridesAccepted() async {
        // Override permit fold executor with explicit
        // identity instance to verify the override path
        // compiles + runs without crashing
        let customFold = BASPermitEscalationFoldExecutor
            .identity()
        let delegate = BASRuntimeInternalDelegate(
            permitFoldExecutor: customFold)
        let ledger = await delegate.runScaffolded(
            request: makeStubRequest())
        XCTAssertEqual(ledger.stageCount, 18)
    }

    // MARK: - Custom plan accepted

    func testCustomPlanAccepted() async {
        // Use a 2-stage plan instead of canonical 18
        let customPlan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB)
        ])
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: customPlan)
        let ledger = await delegate.runScaffolded(
            request: makeStubRequest())
        XCTAssertEqual(ledger.stageCount, 2,
            "custom plan with 2 stages produces 2-record" +
            " ledger")
    }

    // MARK: - 4 REAL executors all reachable via delegate

    func testAllFourRealExecutorsReachable() async {
        let delegate = BASRuntimeInternalDelegate()
        // Verify all 4 executor accessors compile + return
        // typed actors
        let _: BASPermitEscalationFoldExecutor =
            await delegate.permitFoldExecutor
        let _: BASParallelStageDispatchExecutor =
            await delegate.parallelDispatchExecutor
        let _: BASStressSweepHarness =
            await delegate.stressSweepHarness
        let _: BASNativeStageExecutor =
            await delegate.nativeStageExecutor
        XCTAssertTrue(true,
            "delegate exposes all 4 REAL executor types " +
            "shipped at chapter 四百二十五-四百二十六")
    }
}
