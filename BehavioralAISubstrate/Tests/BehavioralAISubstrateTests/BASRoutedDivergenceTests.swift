import XCTest
@testable import BASSovereign

/// 可解释性② pin — the Swift/Rust verdict-divergence tripwire. The Rust derive computes the
/// hard-bit cap itself, so a Swift hits-floor EXCEEDING the routed level = the two derivations
/// disagree (corruption/marshalling drift/vendor bump) — previously absorbed by a SILENT max().
final class BASRoutedDivergenceTests: XCTestCase {

    func testAgreementReportsNoDivergence() {
        let (level, d) = BASSovereignVerdictEngine.applyHitsFloor(
            routed: .toolCut, floors: [.throttle, .toolCut])
        XCTAssertEqual(level, .toolCut)
        XCTAssertNil(d, "floor ≤ routed is normal operation, not divergence")
    }

    func testSwiftFloorAboveRoutedTripsTheWire() {
        let (level, d) = BASSovereignVerdictEngine.applyHitsFloor(
            routed: .throttle, floors: [.quarantine])
        XCTAssertEqual(level, .quarantine, "fail-safe: the Swift floor must still WIN")
        XCTAssertEqual(d, .init(rustLevel: .throttle, swiftFloor: .quarantine),
                       "…but the disagreement must be RECORDED, not absorbed")
    }

    func testEmptyFloorsNoDivergence() {
        let (level, d) = BASSovereignVerdictEngine.applyHitsFloor(routed: .pass, floors: [])
        XCTAssertEqual(level, .pass)
        XCTAssertNil(d)
    }
}
