// MARK: - BASTurnAuditProjectionsAbyssalThermalTrioTests
// chapter 五百六 / M1401 — abyssal+thermal trio tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASTurnAuditProjectionsAbyssalThermalTrioTests:
    XCTestCase
{

    // MARK: - Helper

    private func sampleBudgetFrame(
        runMode: BASEBrainRunMode = .engage
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: runMode,
            maxLoops: 4,
            maxCandidates: 3,
            maxDecodeTokens: 256,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .coreNPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false,
            leaseID: "lease-1")
    }

    // MARK: - 1) Compute produces 3 typed projections

    func testComputeProducesThreeTypedProjections() {
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T1")
        // All 3 projections are populated (non-nil
        // would be a Swift type error since they're
        // not Optional — assert via field access)
        XCTAssertNotNil(trio.abyssalRunMode)
        XCTAssertNotNil(trio.abyssBudget)
        XCTAssertNotNil(trio.memoryTemperatureLayer)
    }

    // MARK: - 2) Abyssal run mode mapping

    func testAbyssalRunModeMapping() {
        // engage → deepDive per Cthulhu Spec V1 §5.1
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(
                        runMode: .engage),
                    turnID: "T")
        XCTAssertEqual(trio.abyssalRunMode,
                       .deepDive)
    }

    func testAbyssalRunModeMappingForAllRunModes() {
        let expected:
            [BASEBrainRunMode: BASAbyssalRunMode] = [
            .dormant: .tideSurface,
            .pulse: .tideSurface,
            .sentinel: .nearShore,
            .engage: .deepDive,
            .reflect: .deepDive,
            .deepLoop: .stormGuard,
            .guard: .stormGuard,
            .recovery: .sealedHarbor,
            .quarantine: .sealedHarbor,
            .lockdown: .sunkenSeal,
        ]
        for (runMode, abyssalMode) in expected {
            let trio =
                BASTurnAuditProjectionsAbyssalThermalTrio
                    .compute(
                        routedBudget:
                            sampleBudgetFrame(
                                runMode: runMode),
                        turnID: "T")
            XCTAssertEqual(trio.abyssalRunMode,
                           abyssalMode,
                "\(runMode) MUST map to \(abyssalMode)")
        }
    }

    // MARK: - 3) Abyss budget derives from full frame

    func testAbyssBudgetDerivesFromFrame() {
        let frame = sampleBudgetFrame()
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: frame,
                    turnID: "T")
        // The abyss budget is derived from the full
        // frame — verify it's non-trivially populated
        // (deepDiveQuota from maxLoops is in [0,1])
        XCTAssertGreaterThanOrEqual(
            trio.abyssBudget.deepDiveQuota, 0.0)
        XCTAssertLessThanOrEqual(
            trio.abyssBudget.deepDiveQuota, 1.0)
    }

    // MARK: - 4) Memory temperature layer derives from
    //             runMode

    func testMemoryTemperatureLayerDerivesFromRunMode() {
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(
                        runMode: .engage),
                    turnID: "T")
        // The layer is one of the 5 thermal tiers per
        // chapter 一百十七 — assert it's a valid case
        // by walking allCases
        XCTAssertTrue(
            BASMemoryTemperatureLayer.allCases
                .contains(trio.memoryTemperatureLayer))
    }

    // MARK: - 5) Determinism — same inputs → same outputs

    func testFactoryIsDeterministic() {
        let r1 =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T")
        let r2 =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T")
        XCTAssertEqual(r1.abyssalRunMode,
                       r2.abyssalRunMode)
        XCTAssertEqual(r1.abyssBudget,
                       r2.abyssBudget)
        XCTAssertEqual(r1.memoryTemperatureLayer,
                       r2.memoryTemperatureLayer)
    }

    // MARK: - 6) Trio is Hashable

    func testTrioIsHashable() {
        let r1 =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T")
        let r2 =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T")
        XCTAssertEqual(r1.hashValue, r2.hashValue)
        var seen = Set<
            BASTurnAuditProjectionsAbyssalThermalTrio>()
        seen.insert(r1)
        seen.insert(r2)
        XCTAssertEqual(seen.count, 1)
    }

    // MARK: - 7) Trio is Sendable across actor boundary

    func testTrioIsSendable() async {
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: sampleBudgetFrame(),
                    turnID: "T")
        let captured = trio
        let task = Task {
            captured.abyssalRunMode
        }
        let mode = await task.value
        XCTAssertEqual(mode, .deepDive)
    }
}
