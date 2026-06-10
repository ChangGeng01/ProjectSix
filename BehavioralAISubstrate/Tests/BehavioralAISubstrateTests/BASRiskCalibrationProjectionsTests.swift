// MARK: - BASRiskCalibrationProjectionsTests
// chapter 四百四 v4 / M978

import Foundation
import XCTest
@testable import BASOrchestration
@testable import BASPolicy

final class BASRiskCalibrationProjectionsTests: XCTestCase {

    func testInitDefaultsAllSlotsNil() {
        let p = BASRiskCalibrationProjections()
        XCTAssertNil(p.riskCard)
        XCTAssertNil(p.decisionPackage)
        XCTAssertNil(p.permitBinding)
    }

    func testNoneFactory() {
        let p = BASRiskCalibrationProjections.none()
        XCTAssertFalse(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 0)
    }

    func testCodableRoundTripEmpty() throws {
        let p = BASRiskCalibrationProjections()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(p)
        let decoded = try JSONDecoder().decode(
            BASRiskCalibrationProjections.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testEqualForSameInputs() {
        let a = BASRiskCalibrationProjections()
        let b = BASRiskCalibrationProjections()
        XCTAssertEqual(a, b,
            "M978:M892 byte-stable equality")
    }

    func testThreeSlotShape() {
        let p = BASRiskCalibrationProjections()
        let _: BASRiskCard? = p.riskCard
        let _: BASRiskDecisionPackage? = p.decisionPackage
        let _: BASRiskPermitBinding? = p.permitBinding
        // Compile-time proof only — the typed binding above IS the contract (a conformance/type change fails compilation, not a runtime assertion). M824 doctrine: no XCTAssertTrue(true) tautology.
    }
}
