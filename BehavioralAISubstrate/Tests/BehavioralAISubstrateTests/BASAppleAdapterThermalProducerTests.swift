import XCTest
@testable import BASAppleAdapters
import BASRuntimeCore

/// audit x-arch MED-1 — the two thermal-BLIND adapter producers.
///
/// Both fed a NON-thermal value into `BASDeviceProfile.thermalState`: producer A
/// (AppleInspectionBridge) fed `environmentClass.rawValue`; producer B
/// (AppleAdaptiveRuntimeAdapter) stuffed the `isLowPowerMode` POWER flag in as
/// "low_power". Post-#15 both classify `.nonThermalNominal`, so an overheating
/// device routed through either always read nominal — structurally thermal-blind.
/// Each now carries an OPTIONAL real reading (`thermalStateRaw`); when a real
/// "serious" reading is supplied it flows through and classifies as heat.
/// (Host wiring from live ProcessInfo + the device escalation cert stay device-gated.)
final class BASAppleAdapterThermalProducerTests: XCTestCase {

    private func classify(_ raw: String) -> BASThermalClassification {
        BASThermalClassification.classify(raw)
    }
    private func budget() -> BASAdaptiveRuntimeBudget {
        BASAdaptiveRuntimeBudget(contextBudget: 420, outputCharacterBudget: 240,
                                 timeBudgetMs: 9000, toolCallBudget: 2, retrievalItemBudget: 4)
    }
    private func inspectionProfile(thermal: String?) -> BASDeviceProfile {
        BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRuntimeContextSourceInput(
                primaryTraceKind: nil, runtimeGear: .balanced,
                environmentClass: .lowPower, deviceClass: .balancedPhone,
                riskLevel: .low, budget: budget(), thermalStateRaw: thermal)
        ).deviceProfile
    }
    private func adaptiveProfile(thermal: String?, lowPower: Bool) -> BASDeviceProfile {
        BASAppleAdaptiveRuntimeAdapter.substrateDeviceProfile(
            for: BASAppleAdaptiveMatrixRequest(
                executionTierID: "balancedGemma", preferredProviderID: "foundationModels",
                allowFallbacks: true, isSimulator: false, physicalMemoryGB: 7,
                isLowPowerModeEnabled: lowPower, preferredLanguages: ["en"],
                thermalStateRaw: thermal))
    }

    // MARK: Producer A — AppleInspectionBridge

    func testInspectionBridgeCarriesRealThermalReading() {
        // A real "serious" reading must flow through and classify as heat — the
        // exact thing the old environmentClass.rawValue feed could never do.
        XCTAssertEqual(classify(inspectionProfile(thermal: "serious").thermalState), .thermal(.serious))
        XCTAssertTrue(BASThermalClassification.classify(
            inspectionProfile(thermal: "critical").thermalState).shouldDowngradeForHeat)
    }
    func testInspectionBridgeAbsentThermalIsHonestNominal() {
        // No reading ⇒ honest "unknown" ⇒ nominal (no false downgrade), and NOT
        // the environmentClass value ("lowPower") that used to be mislabeled.
        let profile = inspectionProfile(thermal: nil)
        XCTAssertEqual(classify(profile.thermalState), .nonThermalNominal("unknown"))
        XCTAssertTrue(profile.lowPowerMode, "environmentClass still drives lowPowerMode")
    }

    // MARK: Producer B — AppleAdaptiveRuntimeAdapter

    func testAdaptiveAdapterCarriesRealThermalReading() {
        XCTAssertEqual(classify(adaptiveProfile(thermal: "serious", lowPower: false).thermalState),
                       .thermal(.serious))
    }
    func testAdaptiveAdapterHotDeviceNotInLowPowerNoLongerReadsNominal() {
        // The category error: a HOT device NOT in low-power used to report "nominal".
        // Now a real hot reading flows even with lowPower=false.
        let profile = adaptiveProfile(thermal: "critical", lowPower: false)
        XCTAssertEqual(classify(profile.thermalState), .thermal(.critical))
        XCTAssertFalse(profile.lowPowerMode, "the power flag still drives lowPowerMode, not thermal")
    }
    func testAdaptiveAdapterAbsentThermalIsHonestNominal() {
        XCTAssertEqual(classify(adaptiveProfile(thermal: nil, lowPower: true).thermalState),
                       .nonThermalNominal("unknown"))
    }
}
