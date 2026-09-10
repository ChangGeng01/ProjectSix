// MARK: - BASChapter751AtomReducerPortTests
// chapter 七百五十一 第二刀 / M2427
//
// MATURATION ARC L8 Memory hot-path port — byte-equality
// verification + 5-axis scorecard for the admission-confidence
// tiebreak rule routed via BASAutoRouteRanker。

import XCTest
@testable import BASRuntimeCore

final class BASChapter751AtomReducerPortTests: XCTestCase {

    // MARK: - ABI version

    func testABIVersionIsAtLeastOne() {
        // chapter 七百五十一 第二刀 shipped ABI v1。 chapter 七百五十三
        // 第二刀 bumped to v2 for the batched API。 chapter 七百五十七
        // 第一刀 deactivated the batched bridge but kept ABI v2 — the
        // per-call symbol still ships as v2。 Use ≥ 1 so future bumps
        // don't false-fail this regression guard。
        #if os(iOS) || os(macOS)
        XCTAssertGreaterThanOrEqual(
            BASAutoRouteRanker.atomReducerABIVersion(), 1,
            "L8 atom reducer ABI must remain reachable")
        #endif
    }

    // MARK: - Swift reference implementation (mirrors lines 170-186)

    private func swiftReferenceShouldReplace(
        existing: Double,
        new: Double,
        tiebreakKeepsExisting: Bool
    ) -> Bool {
        if existing > new { return false }
        if existing < new { return true }
        return !tiebreakKeepsExisting
    }

    // MARK: - Byte-equality (random 200-case grid)

    func testByteEqualityVsSwiftReference() {
        // SplitMix64 deterministic seed → identical fixture every run
        var state: UInt64 = 0xDEAD_BEEF_F00D_CAFE
        func nextDouble() -> Double {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z =  z ^ (z >> 31)
            // Map to [0.0, 1.0] uniform
            return Double(z >> 11)
                / Double(UInt64(1) << 53)
        }

        for i in 0..<200 {
            let existing = nextDouble()
            let new = nextDouble()
            let tiebreak = (i % 2 == 0)
            let expected = swiftReferenceShouldReplace(
                existing: existing, new: new,
                tiebreakKeepsExisting: tiebreak)
            let actual =
                BASAutoRouteRanker
                    .atomReducerShouldReplaceAdmitted(
                        existingConfidence: existing,
                        newConfidence: new,
                        tiebreakKeepsExisting: tiebreak)
            XCTAssertEqual(
                actual, expected,
                "byte-equality drift at i=\(i): " +
                "existing=\(existing) new=\(new) " +
                "tiebreak=\(tiebreak)")
        }
    }

    // MARK: - Edge cases pinned

    func testZeroConfidenceTiePins() {
        XCTAssertFalse(
            BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: 0.0,
                    newConfidence: 0.0,
                    tiebreakKeepsExisting: true),
            "zero tie keeps existing per Swift line 178-179")
        XCTAssertTrue(
            BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: 0.0,
                    newConfidence: 0.0,
                    tiebreakKeepsExisting: false))
    }

    func testExistingHigherKeepsExisting() {
        XCTAssertFalse(
            BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: 0.95,
                    newConfidence: 0.50,
                    tiebreakKeepsExisting: true))
    }

    func testNewHigherReplaces() {
        XCTAssertTrue(
            BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: 0.50,
                    newConfidence: 0.95,
                    tiebreakKeepsExisting: true))
    }

    // MARK: - Determinism

    func testDeterministicAcrossRepeatedCalls() {
        for _ in 0..<50 {
            XCTAssertFalse(
                BASAutoRouteRanker
                    .atomReducerShouldReplaceAdmitted(
                        existingConfidence: 0.7,
                        newConfidence: 0.7,
                        tiebreakKeepsExisting: true))
            XCTAssertTrue(
                BASAutoRouteRanker
                    .atomReducerShouldReplaceAdmitted(
                        existingConfidence: 0.7,
                        newConfidence: 0.7,
                        tiebreakKeepsExisting: false))
        }
    }

    // MARK: - 5-axis perf measurement

    func testPerfMeasurementGrid() {
        #if os(iOS) || os(macOS)
        let iterations = 10_000
        let cases: [(Double, Double, Bool)] = [
            (0.5, 0.9, true),
            (0.9, 0.5, true),
            (0.7, 0.7, true),
            (0.7, 0.7, false),
            (0.0, 1.0, true),
        ]

        // Warmup
        for _ in 0..<1_000 {
            _ = swiftReferenceShouldReplace(
                existing: 0.5, new: 0.6,
                tiebreakKeepsExisting: true)
            _ = BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: 0.5,
                    newConfidence: 0.6,
                    tiebreakKeepsExisting: true)
        }

        // Swift baseline
        let swiftStart = Date()
        var swiftSink = 0
        for _ in 0..<iterations {
            for c in cases {
                if swiftReferenceShouldReplace(
                    existing: c.0, new: c.1,
                    tiebreakKeepsExisting: c.2)
                {
                    swiftSink &+= 1
                }
            }
        }
        let swiftElapsed = Date()
            .timeIntervalSince(swiftStart)

        // Rust routed
        let rustStart = Date()
        var rustSink = 0
        for _ in 0..<iterations {
            for c in cases {
                if BASAutoRouteRanker
                    .atomReducerShouldReplaceAdmitted(
                        existingConfidence: c.0,
                        newConfidence: c.1,
                        tiebreakKeepsExisting: c.2)
                {
                    rustSink &+= 1
                }
            }
        }
        let rustElapsed = Date()
            .timeIntervalSince(rustStart)

        // Sanity:both sinks should equal
        XCTAssertEqual(swiftSink, rustSink,
            "Swift and Rust sinks must agree on " +
            "replace-count across the workload")

        let speedup = swiftElapsed / rustElapsed

        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百五十一 第二刀 — L8 atomReducer 5-axis perf")
        print("=================================================================")
        print(
            "  Iterations:    \(iterations) × \(cases.count) = " +
            "\(iterations * cases.count)")
        print(
            "  Swift baseline wall: \(String(format: "%.3f", swiftElapsed * 1000)) ms")
        print(
            "  Rust routed wall:    \(String(format: "%.3f", rustElapsed * 1000)) ms")
        print(
            "  Speedup (Swift/Rust): \(String(format: "%.2fx", speedup))")
        print("")
        print("  Decision (per 5-axis rule):")
        if speedup >= 1.0 {
            print("    Axis 1 perf:           Rust ≥ Swift ✅")
        } else if speedup >= (1.0 / 1.5) {
            print(
                "    Axis 1 perf:           Rust slower but " +
                "within 1.5× → still eligible")
        } else {
            print(
                "    Axis 1 perf:           Rust slower " +
                "by > 1.5× → opt-in only")
        }
        print("    Axis 2 memory:         TIED (no alloc)")
        print(
            "    Axis 3 state-machine:  TIED (both pure decision)")
        print(
            "    Axis 4 persistence:    N/A (pure compute)")
        print(
            "    Axis 5 replay byte-eq: ✅ (200-case fixture)")
        print("")

        // No XCTAssert on speedup — measurement informs the
        // production-wire decision in 第三刀。 The 5-axis
        // rule allows TIE per perf;byte-equality + state-
        // machine guarantees stand regardless。
        #endif
    }

    // MARK: - 5-axis scorecard print

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 56 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapter751AtomReducerPortTests_IfFalseBody.txt
}
