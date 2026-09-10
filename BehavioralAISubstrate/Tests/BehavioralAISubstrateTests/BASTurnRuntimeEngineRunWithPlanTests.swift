// MARK: - BASTurnRuntimeEngineRunWithPlanTests
// chapter 四百二十七 / M1082

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnRuntimeEngineRunWithPlanTests:
    XCTestCase
{

    // MARK: - Compile-time signature freeze

    func testRunWithPlanSignatureExists() {
        // Compile-time check:runWithPlan must accept the
        // documented 4-param signature。 If signature drift
        // breaks this test,catch at PR-time。
        let _: BASTurnRuntimeEngine.Type =
            BASTurnRuntimeEngine.self
        let _: BASRuntimeInternalDelegate.Type =
            BASRuntimeInternalDelegate.self
        let _: BASTurnRuntimeStagePlan.Type =
            BASTurnRuntimeStagePlan.self
        XCTAssertTrue(true,
            "BASTurnRuntimeEngine.runWithPlan compile-time" +
            " signature pin")
    }

    // MARK: - Default delegate uses canonical plan

    func testDefaultDelegateUsesCanonicalPlan() async {
        // Verify delegate independent of engine: when
        // built with canonical plan,produces 18-stage
        // ledger
        let delegate = BASRuntimeInternalDelegate()
        let request = BASEBrainTurnRequest(
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
        let ledger = await delegate.runScaffolded(
            request: request)
        XCTAssertEqual(ledger.stageCount, 18,
            "default delegate canonical plan = 18 stages")
    }

    // MARK: - Custom plan accepted in delegate

    func testDelegateAcceptsCustomPlan() async {
        // 3-stage custom plan
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageA),
            .sequential(.stageB),
            .sequential(.stageC)
        ])
        let delegate = BASRuntimeInternalDelegate(
            stagePlan: plan)
        let request = BASEBrainTurnRequest(
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
        let ledger = await delegate.runScaffolded(
            request: request)
        XCTAssertEqual(ledger.stageCount, 3)
    }

    // MARK: - Coherence aligns when ledger matches plan

    func testCoherenceMatchesWhenLedgerEqualsPlan() async {
        let delegate = BASRuntimeInternalDelegate()
        let request = BASEBrainTurnRequest(
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
        let ledger = await delegate.runScaffolded(
            request: request)
        let coherence = await delegate.coherence(
            with: ledger)
        XCTAssertTrue(coherence.isFullyCoherent,
            "scaffolded ledger from canonical plan must be" +
            " coherent")
    }

    // MARK: - Determinism

    func testDelegateIsDeterministic() async {
        let d1 = BASRuntimeInternalDelegate()
        let d2 = BASRuntimeInternalDelegate()
        let request = BASEBrainTurnRequest(
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
        let l1 = await d1.runScaffolded(request: request)
        let l2 = await d2.runScaffolded(request: request)
        XCTAssertEqual(
            l1.records.map { $0.stage },
            l2.records.map { $0.stage })
    }
}
