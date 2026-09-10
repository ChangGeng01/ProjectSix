// MARK: - BASChapter739RiskPlaneByteEqualityTests
// chapter 七百三十九 第三刀 / M2368
//
// LAYER-MIGRATION ARC byte-equality gate。 Verifies the
// Rust risk_plane classifier produces BIT-IDENTICAL output
// to a parallel Swift implementation across:
//
//   1. EXHAUSTIVE space:every (band × climate × current)
//      cross product — 4 × 4 × 9 = 144 cells
//   2. RANDOM space:1000 (band, climate, current) tuples
//      drawn from a deterministic PRNG (no flakiness)
//
// Chapter 七百十六 byte-equality discipline applied to the
// L11 state-machine port。 Pre-requisite for chapter 七百三十九
// 第四刀 default-flip decision (5-axis comparison Axis 5)。
//
// ## Parallel Swift classifier (the byte-equality baseline)
//
// `parallelSwiftClassifier(band:climate:current:)` mirrors
// the Rust risk_band_to_next_mode match cascade verbatim。
// Same decision rules,same encoding。 If outputs diverge,
// either Rust drifted from the spec OR Swift drifted —
// whoever changed must update the OTHER side。
//
// ## Why both EXHAUSTIVE + RANDOM
//
// Exhaustive proves no decision cell is missed (chapter 392
// replay-determinism)。 Random catches accidental input-
// dependent state (e.g. memoization on band that breaks
// climate-dependent transitions)。

import XCTest
@testable import BASRuntimeCore

final class BASChapter739RiskPlaneByteEqualityTests:
    XCTestCase
{

    // MARK: - Parallel Swift classifier (byte-equality baseline)

    /// Swift mirror of Rust risk_band_to_next_mode match
    /// cascade。 SINGLE SOURCE OF TRUTH for the Swift side —
    /// any future production caller should consume this。
    ///
    /// Encoding:
    ///   band:    0=Low 1=Medium 2=High 3=Critical
    ///   climate: 0=Calm 1=Watchful 2=Elevated 3=Crisis
    ///   current: 0-8 ActionPermitMode
    ///
    /// Returns:next ActionPermitMode (0-8) or nil if any
    /// input out of range。
    private func parallelSwiftClassifier(
        band: Int32,
        climate: Int32,
        current: Int32
    ) -> Int32? {
        guard band >= 0, band <= 3,
              climate >= 0, climate <= 3,
              current >= 0, current <= 8
        else { return nil }
        switch (band, climate) {
        // Critical band: shut or escalate per climate
        case (3, 3):  return 6  // Block
        case (3, _):  return 8  // Escalate
        // High band: substitute / defer / draft
        case (2, 3), (2, 2):  return 7  // Replace
        case (2, 1):          return 3  // Delay
        case (2, 0):          return 4  // DraftOnly
        // Medium band: comparison / mirror / pass
        case (1, 3), (1, 2):  return 2  // Compare
        case (1, 1):          return 1  // Mirror
        case (1, 0):          return current
        // Low band: no L11 intervention
        case (0, _):          return current
        default:              return nil
        }
    }

    // MARK: - Exhaustive byte-equality across all cells

    func testExhaustiveByteEqualityAllOneHundredFortyFourCells() {
        #if os(iOS) || os(macOS)
        // 4 bands × 4 climates × 9 modes = 144 cells
        var cellsChecked = 0
        for band in Int32(0)...Int32(3) {
            for climate in Int32(0)...Int32(3) {
                for current in Int32(0)...Int32(8) {
                    let rust =
                        BASAutoRouteRanker
                            .riskPlaneTransition(
                                band: band,
                                climate: climate,
                                currentMode: current)
                    let swift = parallelSwiftClassifier(
                        band: band,
                        climate: climate,
                        current: current)
                    XCTAssertEqual(
                        rust, swift,
                        "band=\(band) climate=\(climate) "
                        + "current=\(current): "
                        + "Rust=\(String(describing: rust as Int32?? ?? -1)) "
                        + "Swift=\(String(describing: swift as Int32?? ?? -1))")
                    cellsChecked += 1
                }
            }
        }
        XCTAssertEqual(cellsChecked, 144,
            "expected to check 144 cells (4×4×9)")
        #endif
    }

    // MARK: - Random byte-equality across 1000 sequences

    /// Splitmix64-style deterministic PRNG。 Chapter 392
    /// replay-determinism:byte-equality test must be
    /// reproducible across runs。
    private struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func nextInt(in range: ClosedRange<Int32>)
            -> Int32
        {
            let span = UInt64(range.upperBound
                - range.lowerBound + 1)
            return range.lowerBound + Int32(next() % span)
        }
    }

    func testRandomByteEqualityOneThousandSequences() {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0x7339_BA5_BAD_DECAF)
        for i in 0..<1000 {
            let band = prng.nextInt(in: 0...3)
            let climate = prng.nextInt(in: 0...3)
            let current = prng.nextInt(in: 0...8)
            let rust = BASAutoRouteRanker.riskPlaneTransition(
                band: band,
                climate: climate,
                currentMode: current)
            let swift = parallelSwiftClassifier(
                band: band, climate: climate, current: current)
            XCTAssertEqual(
                rust, swift,
                "seq \(i) band=\(band) climate=\(climate) "
                + "current=\(current): mismatch")
        }
        #endif
    }

    // MARK: - Random byte-equality with out-of-range fuzz

    func testRandomByteEqualityWithOutOfRangeInputs() {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xDEAD_BEEF_BAD_F00D)
        for i in 0..<500 {
            // Allow a wider range — 1/3 of inputs land
            // out of range to fuzz the fault path。
            let band = prng.nextInt(in: -1...4)
            let climate = prng.nextInt(in: -1...4)
            let current = prng.nextInt(in: -1...9)
            let rust = BASAutoRouteRanker.riskPlaneTransition(
                band: band,
                climate: climate,
                currentMode: current)
            let swift = parallelSwiftClassifier(
                band: band, climate: climate, current: current)
            XCTAssertEqual(
                rust, swift,
                "fuzz \(i) band=\(band) climate=\(climate) "
                + "current=\(current): mismatch")
        }
        #endif
    }

    // MARK: - Effective threshold byte-equality

    /// Swift mirror of Rust effective_threshold。
    private func parallelSwiftEffectiveThreshold(
        base: Double, delta: Double
    ) -> Double {
        let sum = base + delta
        if sum.isNaN { return 0 }
        if sum < 0 { return 0 }
        if sum > 1 { return 1 }
        return sum
    }

    func testEffectiveThresholdByteEqualityGrid() {
        #if os(iOS) || os(macOS)
        let bases: [Double] = [
            0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0, .nan]
        let deltas: [Double] = [
            -1.0, -0.5, -0.1, 0.0, 0.1, 0.5, 1.0, .nan]
        for b in bases {
            for d in deltas {
                let rust = BASAutoRouteRanker
                    .riskPlaneEffectiveThreshold(
                        base: b, delta: d)
                let swift = parallelSwiftEffectiveThreshold(
                    base: b, delta: d)
                XCTAssertEqual(
                    rust, swift, accuracy: 1e-15,
                    "base=\(b) delta=\(d):"
                    + " Rust=\(rust) Swift=\(swift)")
            }
        }
        #endif
    }

    // MARK: - Monotonic version compare byte-equality

    /// Swift mirror of Rust monotonic_version_compare。
    private func parallelSwiftMonotonicVersionCompare(
        current: String, proposed: String
    ) -> Bool? {
        // deep-audit blindspot-③ mirror (2026-07-11): NUMERIC component compare, not lexicographic
        // `>` (which claimed v9 > v10, ACCEPTING A DOWNGRADE). Unparseable ⇒ nil (fail-closed).
        func parse(_ v: String) -> [UInt64]? {
            let body = v.hasPrefix("v") ? String(v.dropFirst()) : v
            if body.isEmpty { return nil }
            var out: [UInt64] = []
            for part in body.split(separator: ".", omittingEmptySubsequences: false) {
                guard let n = UInt64(part) else { return nil }
                out.append(n)
            }
            return out
        }
        if current.isEmpty || proposed.isEmpty { return nil }
        guard let c = parse(current), let p = parse(proposed) else { return nil }
        return lexNumericGreater(p, c)
    }

    /// element-wise then by length — mirrors Rust `Vec<u64>` ordering.
    private func lexNumericGreater(_ a: [UInt64], _ b: [UInt64]) -> Bool {
        for i in 0..<min(a.count, b.count) {
            if a[i] != b[i] { return a[i] > b[i] }
        }
        return a.count > b.count
    }

    func testMonotonicVersionByteEqualityGrid() {
        #if os(iOS) || os(macOS)
        let pairs: [(String, String)] = [
            ("v1.0.0", "v2.0.0"),    // greater
            ("v1.0.0", "v1.0.0"),    // equal
            ("v2.0.0", "v1.0.0"),    // lesser
            ("v1.0.0", "v1.0.1"),    // greater
            ("v0.0.1", "v9.9.9"),    // greater
            ("", "v1.0.0"),          // fault
            ("v1.0.0", ""),          // fault
            ("baseline", "v1.0.0"),  // greater (v > b ASCII)
            ("a", "b"),              // greater
            ("z", "a"),              // lesser
        ]
        for (current, proposed) in pairs {
            let rust = BASAutoRouteRanker
                .riskPlaneMonotonicVersionCompare(
                    current: current, proposed: proposed)
            let swift =
                parallelSwiftMonotonicVersionCompare(
                    current: current, proposed: proposed)
            XCTAssertEqual(
                rust, swift,
                "(\(current), \(proposed)): mismatch")
        }
        #endif
    }

    // gaps-reconciliation runtimecore-b LOW #9 (2026-07-11): pins the documented nil contract on
    // empty input. HONEST SCOPE (corrected by the reversal run): the old force-unwrap never
    // crashed on THIS toolchain (empty-singleton pointer is non-nil; Rust returns -1 for zero-len)
    // — these teeth pin the CONTRACT, and the guard removes a latent, documented-nullable UB
    // dependence, not a live trap. This test passes with or without the guard by design.
    func testEmptyVersionStringsReturnNilNotTrap() {
        #if os(iOS) || os(macOS)
        XCTAssertNil(BASAutoRouteRanker.riskPlaneMonotonicVersionCompare(
            current: "", proposed: "v1.0.0"), "empty current ⇒ nil (documented fault contract)")
        XCTAssertNil(BASAutoRouteRanker.riskPlaneMonotonicVersionCompare(
            current: "v1.0.0", proposed: ""), "empty proposed ⇒ nil")
        XCTAssertNil(BASAutoRouteRanker.riskPlaneMonotonicVersionCompare(
            current: "", proposed: ""), "both empty ⇒ nil")
        // non-empty still flows through FFI (sanity that the guard did not over-block)
        XCTAssertEqual(BASAutoRouteRanker.riskPlaneMonotonicVersionCompare(
            current: "v1.0.0", proposed: "v2.0.0"), true)
        #endif
    }
}
