// BASChapter1044ThermalDepthFloorTests.swift
// BehavioralAISubstrateTests
//
// Unit tests for the dormant thermal-depth-floor pure helper
// (ADR-018 P3, chapter 1044). Verifies the floor triggers only on the
// genuinely-hot levels (`.hot`, `.critical`), passes through the cool
// levels (`.nominal`, `.warm`), and is monotonic toward less
// deliberation (it never raises `maxLoops`).
//

import XCTest
import BASRuntimeCore
@testable import BASHostKit

final class BASChapter1044ThermalDepthFloorTests: XCTestCase {
    func testHotThermalFloorsToOne() {
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(4, thermalLevel: .hot),
            1
        )
    }

    func testCriticalThermalFloorsToOne() {
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(4, thermalLevel: .critical),
            1
        )
    }

    func testNominalPassthrough() {
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(4, thermalLevel: .nominal),
            4
        )
    }

    func testWarmPassthrough() {
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(4, thermalLevel: .warm),
            4
        )
    }

    func testFloorNeverRaises() {
        // Monotonic toward less deliberation: a budget already at the floor
        // is unaffected, and the hot path never returns a value greater than
        // the input.
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(1, thermalLevel: .nominal),
            1
        )
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(1, thermalLevel: .hot),
            1
        )
        // Below the floor stays below the floor (never raised up to 1).
        XCTAssertEqual(
            BASDeliberationThermalFloor.flooredMaxLoops(0, thermalLevel: .hot),
            0
        )
    }
}
