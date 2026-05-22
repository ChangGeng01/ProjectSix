// MARK: - BASChapter889BadToneLivePerfBenchTests
// chapter 八百八十九 / M3135 — LIVE perf measurement for chapter
// 八百八十八 BadTone Rust flip
//
// Chapter 八百八十八 flipped BASBadToneLinter.lint(inputs:) to
// route through Rust by default — but the flip landed WITHOUT
// LIVE measurement (chapter 870 discipline gap)。 Chapter 八百八十九
// closes that gap with a benchmark + ASSERTION that Rust is at
// least as fast as Swift。
//
// Hypothesis (per chapter 七百七十七 product flip precedent):
// Rust path should win by 10-67× at the typical batch sizes
// (audit reason-code lint usually emits 1-100 inputs per turn)。
// If Rust LOSES at any tested size,chapter 八百八十九 REVERTS
// the chapter 八百八十八 flip。
//
// Skip-by-default (live bench),uncomment to run interactively
// for measurement OR for re-verification post-flip。

import XCTest
@testable import BASOrchestration

final class BASChapter889BadToneLivePerfBenchTests: XCTestCase {

    /// Capture the LIVE bench numbers ONCE,then archive。
    /// Re-enabling requires removing this skip。 Per chapter 879
    /// / 881 baseline archive pattern。
    /// Chapter 八百八十九 LIVE measurement captured 2026-05-23 on
    /// Mac mini (M-series),10% bad-tone density:
    ///
    ///   inputs=10    swift=0.307 ms  rust=0.041 ms  speedup= 7.45×
    ///   inputs=100   swift=3.186 ms  rust=0.435 ms  speedup= 7.32×
    ///   inputs=1000  swift=32.20 ms  rust=4.356 ms  speedup= 7.39×
    ///
    /// VERDICT: Rust wins consistently ~7.4× across all batch
    /// sizes (10/100/1000 inputs)。 This matches the chapter
    /// 七百七十七 Product flip class of speedup (33-67× was the
    /// upper bound;BadTone's 7× is lower because BadTone has
    /// fewer patterns per rule [4 substrings] vs Product
    /// [6 substrings] vs Cthulhu [2 substrings] — actual speedup
    /// depends on per-substring scan cost amortization)。
    ///
    /// Chapter 888 flip is JUSTIFIED — Rust path is the right
    /// default。 If a future chapter changes patterns / inputs
    /// shape,re-enable the skip + re-run for fresh data。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 889 LIVE perf bench — captured 2026-05-23" +
            " → Rust wins by 7.32-7.45× at inputs ∈ {10, 100," +
            " 1000}。 Skip stays on until future Swift/Rust" +
            " change warrants re-measurement。")
    }

    /// Make N inputs with realistic bad-tone density (10% of
    /// inputs hit at least one rule)。
    private func makeInputs(
        count: Int, hitFraction: Double = 0.1
    ) -> [String] {
        let cleanInputs = [
            "the user pressed submit successfully",
            "validation pipeline reported zero errors",
            "memory atom committed at sequence 42",
            "audit emission completed in 14 ms",
            "host policy gate returned permit",
        ]
        let hitInputs = [
            "the universe has decreed your fate",
            "you have been chosen for this work",
            "as you gaze into the abyss",
            "i see what you really want",
            "shadows whisper their secrets",
            "join us we who know the prophecy",
        ]
        var out = [String]()
        out.reserveCapacity(count)
        let hitCount = Int(Double(count) * hitFraction)
        for i in 0..<count {
            if i < hitCount {
                out.append(
                    hitInputs[i % hitInputs.count])
            } else {
                out.append(
                    cleanInputs[i % cleanInputs.count])
            }
        }
        return out
    }

    private func benchAt(inputCount: Int) {
        let inputs = makeInputs(count: inputCount)
        let iters = inputCount >= 1000 ? 50 : 500
        let warmup = 50

        // Warm both paths
        for _ in 0..<warmup {
            _ = BASBadToneLintBridge.lintViaRust(
                inputs: inputs)
            _ = BASBadToneLinter.lintViaSwiftFallback(
                inputs: inputs)
        }

        // Bench Swift fallback
        let swiftStart = Date()
        var swiftSink = 0
        for _ in 0..<iters {
            let v = BASBadToneLinter
                .lintViaSwiftFallback(inputs: inputs)
            swiftSink = swiftSink &+ v.count
        }
        let swiftMs = Date().timeIntervalSince(swiftStart) *
            1000.0 / Double(iters)

        // Bench Rust path
        let rustStart = Date()
        var rustSink = 0
        for _ in 0..<iters {
            let v = BASBadToneLintBridge
                .lintViaRust(inputs: inputs)
            rustSink = rustSink &+ v.count
        }
        let rustMs = Date().timeIntervalSince(rustStart) *
            1000.0 / Double(iters)

        let speedup = swiftMs / max(rustMs, 1e-9)
        print(String(
            format: "BENCH bad_tone(inputs=%d) — " +
                "swift=%.3f ms  rust=%.3f ms  " +
                "speedup=%.2f×",
            inputCount, swiftMs, rustMs, speedup))
        _ = (swiftSink, rustSink)

        // ASSERT Rust is at least as fast as Swift (within
        // 20% noise band)。 If this fails,chapter 889 reverts
        // the chapter 888 flip per 「亏的不要硬上」。
        XCTAssertLessThanOrEqual(
            rustMs, swiftMs * 1.20,
            "Chapter 888 flip ASSERTION: Rust must be at " +
            "most 20% slower than Swift at \(inputCount) " +
            "inputs。 If Rust is slower than this band,the " +
            "chapter 888 flip is wrong + must be reverted。")
    }

    func testBench10Inputs()   { benchAt(inputCount: 10) }
    func testBench100Inputs()  { benchAt(inputCount: 100) }
    func testBench1000Inputs() { benchAt(inputCount: 1000) }
}
