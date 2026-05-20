// MARK: - BASChapter739RiskPlaneBridgeTests
// chapter 七百三十九 第二刀 / M2367
//
// LAYER-MIGRATION ARC — verifies the C ABI + Swift bridge
// for the L11 Wind Gate Rust state-machine port lands
// cleanly:
//
//   - bas_permit_policy_risk_band_to_next_mode FFI roundtrip
//   - bas_permit_policy_effective_threshold FFI roundtrip
//   - bas_permit_policy_monotonic_version_compare FFI
//     roundtrip
//
// Wire encoding pinned per the Rust risk_plane.rs +
// bas_rust_memory_tracker.h header verbatim:
//   RiskBand:    0=Low 1=Medium 2=High 3=Critical
//   RiskClimate: 0=Calm 1=Watchful 2=Elevated 3=Crisis
//   ActionPermitMode:
//     0=Answer 1=Mirror 2=Compare 3=Delay
//     4=DraftOnly 5=LocalOnly 6=Block 7=Replace 8=Escalate
//
// ## What this knife verifies
//
// FFI plumbing works at the wire level。 Chapter 七百三十九
// 第三刀 builds a 100-random-sequence byte-equality test
// against a parallel Swift in-line classifier。 5-axis
// comparison decision lands at 第四刀。

import XCTest
@testable import BASRuntimeCore

final class BASChapter739RiskPlaneBridgeTests: XCTestCase {

    // MARK: - Classifier roundtrip

    func testCriticalBandCrisisClimateBlocks() {
        #if os(iOS) || os(macOS)
        // band=3 (Critical), climate=3 (Crisis), current=0 (Answer)
        // → expect 6 (Block)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 3, climate: 3, currentMode: 0),
            6)
        #endif
    }

    func testCriticalBandCalmEscalates() {
        #if os(iOS) || os(macOS)
        // band=3, climate=0 (Calm), current=0 → 8 (Escalate)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 3, climate: 0, currentMode: 0),
            8)
        #endif
    }

    func testHighBandCrisisReplaces() {
        #if os(iOS) || os(macOS)
        // band=2 (High), climate=3 (Crisis), current=0
        // → 7 (Replace)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 2, climate: 3, currentMode: 0),
            7)
        #endif
    }

    func testHighBandWatchfulDelays() {
        #if os(iOS) || os(macOS)
        // band=2, climate=1 (Watchful), current=0 → 3 (Delay)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 2, climate: 1, currentMode: 0),
            3)
        #endif
    }

    func testHighBandCalmDrafts() {
        #if os(iOS) || os(macOS)
        // band=2, climate=0, current=0 → 4 (DraftOnly)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 2, climate: 0, currentMode: 0),
            4)
        #endif
    }

    func testMediumBandCrisisCompares() {
        #if os(iOS) || os(macOS)
        // band=1, climate=3, current=0 → 2 (Compare)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 1, climate: 3, currentMode: 0),
            2)
        #endif
    }

    func testMediumBandWatchfulMirrors() {
        #if os(iOS) || os(macOS)
        // band=1, climate=1, current=0 → 1 (Mirror)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 1, climate: 1, currentMode: 0),
            1)
        #endif
    }

    func testMediumBandCalmKeepsCurrent() {
        #if os(iOS) || os(macOS)
        // band=1, climate=0, current=4 (DraftOnly) → 4
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 1, climate: 0, currentMode: 4),
            4)
        #endif
    }

    func testLowBandKeepsCurrentInAnyClimate() {
        #if os(iOS) || os(macOS)
        for climate in Int32(0)...Int32(3) {
            for current in Int32(0)...Int32(8) {
                XCTAssertEqual(
                    BASAutoRouteRanker.riskPlaneTransition(
                        band: 0,
                        climate: climate,
                        currentMode: current),
                    current,
                    "Low band band=0 climate=\(climate) "
                    + "current=\(current) must keep current")
            }
        }
        #endif
    }

    func testOutOfRangeInputsReturnNil() {
        #if os(iOS) || os(macOS)
        // band=-1 fault
        XCTAssertNil(
            BASAutoRouteRanker.riskPlaneTransition(
                band: -1, climate: 0, currentMode: 0))
        // band=4 fault (Critical is max)
        XCTAssertNil(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 4, climate: 0, currentMode: 0))
        // climate=4 fault
        XCTAssertNil(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 0, climate: 4, currentMode: 0))
        // current=9 fault (Escalate is max)
        XCTAssertNil(
            BASAutoRouteRanker.riskPlaneTransition(
                band: 0, climate: 0, currentMode: 9))
        #endif
    }

    // MARK: - Effective threshold

    func testEffectiveThresholdClampsLow() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneEffectiveThreshold(
                base: 0.1, delta: -0.5),
            0.0)
        #endif
    }

    func testEffectiveThresholdClampsHigh() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneEffectiveThreshold(
                base: 0.8, delta: 0.5),
            1.0)
        #endif
    }

    func testEffectiveThresholdPassesInRange() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneEffectiveThreshold(
                base: 0.5, delta: 0.1),
            0.6, accuracy: 1e-9)
        #endif
    }

    func testEffectiveThresholdNanReturnsZero() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.riskPlaneEffectiveThreshold(
                base: .nan, delta: 0.5),
            0.0)
        #endif
    }

    // MARK: - Monotonic version compare

    func testMonotonicVersionProposedGreater() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "v1.0.0", proposed: "v2.0.0"),
            true)
        #endif
    }

    func testMonotonicVersionProposedEqualRejected() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "v1.0.0", proposed: "v1.0.0"),
            false)
        #endif
    }

    func testMonotonicVersionProposedLesserRejected() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "v2.0.0", proposed: "v1.0.0"),
            false)
        #endif
    }

    func testMonotonicVersionEmptyCurrentReturnsNil() {
        #if os(iOS) || os(macOS)
        XCTAssertNil(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "", proposed: "v1.0.0"))
        #endif
    }

    func testMonotonicVersionEmptyProposedReturnsNil() {
        #if os(iOS) || os(macOS)
        XCTAssertNil(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "v1.0.0", proposed: ""))
        #endif
    }

    func testMonotonicVersionUnicodeStringsWork() {
        #if os(iOS) || os(macOS)
        // String compare on UTF-8 — "v1.0.0" < "v1.0.1" so
        // proposed > current。 Also tests that the byte-
        // pointer path doesn't mangle ASCII。
        XCTAssertEqual(
            BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: "v1.0.0", proposed: "v1.0.1"),
            true)
        #endif
    }
}
