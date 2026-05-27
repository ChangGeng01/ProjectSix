// MARK: - BASMLPowerClockServiceTests
// REAL tests for the L8 power-clock service deriving
// cognitive budget from device state + risk hint。
// Ninth active ML-touched layer in the cognitive cascade。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASPolicy

#if !os(iOS)  // ch 1022 source-gate
final class BASMLPowerClockServiceTests: XCTestCase {

    // MARK: - Helpers

    private func device(
        battery: Double = 0.8,
        thermal: BASThermalLevel = .nominal,
        memoryMB: Int = 2048,
        cpuLoad: Double = 0.2,
        foreground: BASForegroundState = .foreground,
        npu: Bool = true
    ) -> BASDeviceState {
        return BASDeviceState(
            batteryLevel: battery,
            thermalLevel: thermal,
            memoryFreeMB: memoryMB,
            networkState: .online,
            foregroundState: foreground,
            cpuLoad: cpuLoad,
            gpuLoad: 0.1,
            npuAvailable: npu,
            latencyBudgetMs: 1500)
    }

    // MARK: - Tier derivation

    func testCriticalBatteryYieldsLockdown() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(battery: 0.05),
            riskHint: nil)
        XCTAssertEqual(tier, .lockdown)
    }

    func testCriticalThermalYieldsLockdown() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(thermal: .critical),
            riskHint: nil)
        XCTAssertEqual(tier, .lockdown)
    }

    func testLowBatteryYieldsThrottle() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(battery: 0.15),
            riskHint: nil)
        XCTAssertEqual(tier, .throttle)
    }

    func testHotThermalYieldsThrottle() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(thermal: .hot),
            riskHint: nil)
        XCTAssertEqual(tier, .throttle)
    }

    func testLowMemoryYieldsThrottle() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(memoryMB: 200),
            riskHint: nil)
        XCTAssertEqual(tier, .throttle)
    }

    func testHighCPULoadYieldsThrottle() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(cpuLoad: 0.9),
            riskHint: nil)
        XCTAssertEqual(tier, .throttle)
    }

    func testBackgroundYieldsThrottle() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(foreground: .background),
            riskHint: nil)
        XCTAssertEqual(tier, .throttle)
    }

    func testHealthyDeviceWithHighRiskYieldsDeepLoop() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(),
            riskHint: .high)
        XCTAssertEqual(tier, .deepLoop)
    }

    func testHealthyDeviceWithExtremeRiskYieldsDeepLoop() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(),
            riskHint: .extreme)
        XCTAssertEqual(tier, .deepLoop)
    }

    func testHealthyDeviceWithLowRiskYieldsEngage() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(),
            riskHint: .low)
        XCTAssertEqual(tier, .engage)
    }

    func testNilRiskOnHealthyDeviceYieldsEngage() {
        let tier = BASMLPowerClockService.tier(
            deviceState: device(),
            riskHint: nil)
        XCTAssertEqual(tier, .engage)
    }

    // MARK: - Conservative-wins precedence

    func testCriticalBeatsHighRisk() {
        // Critical thermal must lockdown even on extreme
        // risk — never burn the device。
        let tier = BASMLPowerClockService.tier(
            deviceState: device(thermal: .critical),
            riskHint: .extreme)
        XCTAssertEqual(tier, .lockdown,
            "Critical thermal must win over high risk")
    }

    // MARK: - Bounds per tier

    func testLockdownBoundsAreMinimal() {
        let (loops, cands, tokens, depth) =
            BASMLPowerClockService.bounds(for: .lockdown)
        XCTAssertEqual(loops, 1)
        XCTAssertEqual(cands, 1)
        XCTAssertEqual(tokens, 60)
        XCTAssertEqual(depth, 1)
    }

    func testDeepLoopBoundsAreMaximal() {
        let (loops, cands, tokens, depth) =
            BASMLPowerClockService.bounds(for: .deepLoop)
        XCTAssertEqual(loops, 5)
        XCTAssertEqual(cands, 5)
        XCTAssertEqual(tokens, 360)
        XCTAssertEqual(depth, 4)
    }

    // MARK: - Device route

    func testCriticalThermalRoutesToScoutCPU() {
        let route = BASMLPowerClockService.deviceRoute(
            deviceState: device(thermal: .critical),
            tier: .lockdown)
        XCTAssertEqual(route, .scoutCPU)
    }

    func testHealthyDeviceWithNPURoutesToCoreNPU() {
        let route = BASMLPowerClockService.deviceRoute(
            deviceState: device(npu: true),
            tier: .engage)
        XCTAssertEqual(route, .coreNPU)
    }

    func testHealthyDeviceWithoutNPURoutesToHybrid() {
        let route = BASMLPowerClockService.deviceRoute(
            deviceState: device(npu: false),
            tier: .engage)
        XCTAssertEqual(route, .hybridLocal)
    }

    func testWarmThermalRoutesToScoutGPU() {
        let route = BASMLPowerClockService.deviceRoute(
            deviceState: device(thermal: .warm),
            tier: .engage)
        XCTAssertEqual(route, .scoutGPU)
    }

    // MARK: - Thermal guard echo

    func testThermalGuardEchoesDeviceThermal() {
        XCTAssertEqual(
            BASMLPowerClockService.thermalGuardLevel(
                for: .nominal), .nominal)
        XCTAssertEqual(
            BASMLPowerClockService.thermalGuardLevel(
                for: .warm), .watch)
        XCTAssertEqual(
            BASMLPowerClockService.thermalGuardLevel(
                for: .hot), .throttle)
        XCTAssertEqual(
            BASMLPowerClockService.thermalGuardLevel(
                for: .critical), .emergency)
    }

    // MARK: - Maintenance scheduling

    func testMaintenanceAllowedOnFullyHealthyBackgroundDevice() {
        let service = BASMLPowerClockService()
        let allowed = service.scheduleMaintenance(
            deviceState: device(
                battery: 0.8,
                thermal: .nominal,
                foreground: .background),
            budget: BASBudgetFrame(
                runMode: .engage,
                maxLoops: 3,
                maxCandidates: 3,
                maxDecodeTokens: 240,
                retrievalDepth: 3,
                precisionProfile: .protected,
                deviceRoute: .coreNPU,
                thermalGuardLevel: .nominal,
                maintenanceAllowed: false))
        XCTAssertTrue(allowed)
    }

    func testMaintenanceBlockedOnForegroundDevice() {
        let service = BASMLPowerClockService()
        let allowed = service.scheduleMaintenance(
            deviceState: device(
                battery: 0.8,
                foreground: .foreground),
            budget: BASBudgetFrame(
                runMode: .engage,
                maxLoops: 3,
                maxCandidates: 3,
                maxDecodeTokens: 240,
                retrievalDepth: 3,
                precisionProfile: .protected,
                deviceRoute: .coreNPU,
                thermalGuardLevel: .nominal,
                maintenanceAllowed: false))
        XCTAssertFalse(allowed)
    }

    // MARK: - planBudget end-to-end

    func testPlanBudgetForHealthyDeviceIsEngage() {
        let service = BASMLPowerClockService()
        let budget = service.planBudget(
            deviceState: device(),
            taskPing: "test",
            riskHint: .low)
        XCTAssertEqual(budget.runMode, .engage)
        XCTAssertEqual(budget.maxLoops,
            BASMLPowerClockService.BudgetTiers
                .engageMaxLoops)
    }

    func testPlanBudgetForCriticalDeviceIsLockdown() {
        let service = BASMLPowerClockService()
        let budget = service.planBudget(
            deviceState: device(battery: 0.05),
            taskPing: "test",
            riskHint: nil)
        XCTAssertEqual(budget.runMode, .lockdown)
        XCTAssertEqual(budget.maxLoops,
            BASMLPowerClockService.BudgetTiers
                .lockdownMaxLoops)
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeUsesL8DerivedBudget() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello",
            deviceState: BASCognitiveBrain
                .defaultDeviceState)
        // The cascade ran through the L8 power-clock。
        // The resulting budgetFrame should reflect a
        // valid maxLoops。
        XCTAssertGreaterThan(
            result.budgetFrame.maxLoops, 0)
    }
}
#endif
