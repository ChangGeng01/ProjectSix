// MARK: - BASRoutedBudgetFactoryTests
// chapter 五百十 / M1419 — routed budget factory tests

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASRoutedBudgetFactoryTests: XCTestCase {

    private func samplePlannedBudget(
        runMode: BASEBrainRunMode = .engage
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: runMode,
            maxLoops: 4,
            maxCandidates: 3,
            maxDecodeTokens: 256,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .coreNPU,  // overridden by factory
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false,  // overridden
            leaseID: "lease-1",
            maintenanceClass: .light,
            wakeIntentID: "wake-1",
            allowedHeads: ["h1", "h2"],
            policyBundleVersion: "pv-1",
            policyDecisionIDs: ["d-1", "d-2"])
    }

    // MARK: - 1) Factory routes deviceRoute correctly

    func testFactoryOverridesDeviceRoute() {
        let planned = samplePlannedBudget()
        let routed = BASRoutedBudgetFactory
            .routedBudget(
                plannedBudget: planned,
                deviceRoute: .scoutGPU,
                maintenanceAllowed: true)
        XCTAssertEqual(routed.deviceRoute, .scoutGPU,
            "factory MUST use passed-in deviceRoute" +
            " (not plannedBudget.deviceRoute)")
    }

    // MARK: - 2) Factory routes maintenanceAllowed

    func testFactoryOverridesMaintenanceAllowed() {
        let planned = samplePlannedBudget()
        let routed = BASRoutedBudgetFactory
            .routedBudget(
                plannedBudget: planned,
                deviceRoute: .scoutCPU,
                maintenanceAllowed: true)
        XCTAssertTrue(routed.maintenanceAllowed,
            "factory MUST use passed-in maintenance" +
            "Allowed")
    }

    // MARK: - 3) All other 16 fields threaded verbatim

    func testAllOtherFieldsThreadedVerbatim() {
        let planned = samplePlannedBudget()
        let routed = BASRoutedBudgetFactory
            .routedBudget(
                plannedBudget: planned,
                deviceRoute: .scoutGPU,
                maintenanceAllowed: true)
        XCTAssertEqual(routed.schemaVersion,
                       planned.schemaVersion)
        XCTAssertEqual(routed.runMode, planned.runMode)
        XCTAssertEqual(routed.maxLoops,
                       planned.maxLoops)
        XCTAssertEqual(routed.maxCandidates,
                       planned.maxCandidates)
        XCTAssertEqual(routed.maxDecodeTokens,
                       planned.maxDecodeTokens)
        XCTAssertEqual(routed.retrievalDepth,
                       planned.retrievalDepth)
        XCTAssertEqual(routed.precisionProfile,
                       planned.precisionProfile)
        XCTAssertEqual(routed.thermalGuardLevel,
                       planned.thermalGuardLevel)
        XCTAssertEqual(routed.leaseID,
                       planned.leaseID)
        XCTAssertEqual(routed.leaseExpiresAt,
                       planned.leaseExpiresAt)
        XCTAssertEqual(routed.maintenanceClass,
                       planned.maintenanceClass)
        XCTAssertEqual(routed.wakeIntentID,
                       planned.wakeIntentID)
        XCTAssertEqual(routed.allowedHeads,
                       planned.allowedHeads)
        XCTAssertEqual(routed.policyBundleVersion,
                       planned.policyBundleVersion)
        XCTAssertEqual(routed.policyDecisionIDs,
                       planned.policyDecisionIDs)
    }

    // MARK: - 4) Determinism

    func testFactoryIsDeterministic() {
        let planned = samplePlannedBudget()
        let r1 = BASRoutedBudgetFactory.routedBudget(
            plannedBudget: planned,
            deviceRoute: .scoutGPU,
            maintenanceAllowed: false)
        let r2 = BASRoutedBudgetFactory.routedBudget(
            plannedBudget: planned,
            deviceRoute: .scoutGPU,
            maintenanceAllowed: false)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 5) Different deviceRoutes produce different
    //             routedBudgets

    func testDifferentDeviceRoutesYieldDifferentBudgets() {
        let planned = samplePlannedBudget()
        let cpu = BASRoutedBudgetFactory.routedBudget(
            plannedBudget: planned,
            deviceRoute: .scoutCPU,
            maintenanceAllowed: false)
        let npu = BASRoutedBudgetFactory.routedBudget(
            plannedBudget: planned,
            deviceRoute: .coreNPU,
            maintenanceAllowed: false)
        XCTAssertNotEqual(cpu, npu)
    }
}
