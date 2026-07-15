import XCTest
@testable import BASRuntimeCore

/// audit x-arch MED-1 (mega-audit #15 follow-up) — the SECOND thermal consumer.
///
/// `BASDeviceState.init(profile:)` used a substring `switch` whose
/// `default → .nominal` read an overheating device as COOL on any unrecognized
/// `thermalState` string (fail-OPEN — the exact class #15 fixed, but #15 patched
/// only the route-advisor consumer at RuntimeCore.swift:420). It now routes on
/// the canonical `BASThermalClassification.routingSeverity`, which fails CLOSED
/// on garbage while leaving every recognized/known-non-thermal string unchanged.
final class BASDeviceStateThermalFailClosedTests: XCTestCase {

    private func level(forThermalState raw: String) -> BASThermalLevel {
        let profile = BASDeviceProfile(
            modelName: "test", memoryMB: 4096, batteryLevel: 0.5,
            lowPowerMode: false, thermalState: raw)
        return BASDeviceState(profile: profile, memoryFreeMB: 1024).thermalLevel
    }

    /// THE FIX: a genuinely-unrecognized string must FAIL CLOSED, never .nominal.
    func testUnrecognizedThermalStateFailsClosed() {
        XCTAssertEqual(level(forThermalState: "garbage"), .hot,
            "an unrecognized thermalState must fail CLOSED (.hot), never fail-open .nominal")
        XCTAssertNotEqual(level(forThermalState: "wat"), .nominal,
            "no unrecognized string may read as cool (that was the fail-open bug)")
    }

    /// Recognized thermal vocabularies still map correctly (no regression).
    func testRecognizedThermalStatesUnchanged() {
        XCTAssertEqual(level(forThermalState: "critical"), .critical)
        XCTAssertEqual(level(forThermalState: "serious"), .hot)
        XCTAssertEqual(level(forThermalState: "hot"), .hot)
        XCTAssertEqual(level(forThermalState: "fair"), .warm)
        XCTAssertEqual(level(forThermalState: "warm"), .warm)
        XCTAssertEqual(level(forThermalState: "nominal"), .nominal)
    }

    /// Known NON-thermal producer strings carry no heat signal ⇒ nominal (no
    /// false downgrade). These must NOT be swept into the fail-closed bucket.
    func testKnownNonThermalStringsStayNominal() {
        for s in ["low_power", "lowPower", "simulator", "normal", "memoryConstrained", ""] {
            XCTAssertEqual(level(forThermalState: s), .nominal,
                "known non-thermal producer string \"\(s)\" must read nominal, not fail-closed")
        }
    }
}
