// MARK: - BASChapter778CrossLanguagePerfHarness
// chapter 七百七十八 / M2541-M2545
//
// 5-axis perf measurement framework + first end-to-end measurement
// on the flipped bas-red-team-bench Rust path (chapter 七百七十七
// production flip)。
//
// Captures the FULL Swift-to-Rust wire-format round-trip cost (not
// just the Rust internal scan time) so the「real consumer cost」 is
// what gets reported。 The Rust-internal microbenchmarks in
// Cargo/bas-red-team-bench/src/lib.rs reported 1.5 ms/batch;this
// harness measures the additional Swift-side encode/decode + FFI
// traversal that production callers actually pay。

import XCTest
@testable import BASOrchestration

/// 5-axis perf scorecard for one Rust route。 Captured for the
/// arc's flip-decision audit trail。
public struct BASCrossLanguagePerfReport {
    public let crateName: String
    public let workload: String
    public let iterations: Int
    public let v1SwiftNs: UInt64
    public let v2RustNs: UInt64

    /// Speedup ratio (V1 / V2)。 >1.0 = Rust faster。
    public var speedupRatio: Double {
        if v2RustNs == 0 { return 0 }
        return Double(v1SwiftNs) / Double(v2RustNs)
    }

    /// Per-iteration cost in nanoseconds。
    public var v1PerIterNs: UInt64 { v1SwiftNs / UInt64(iterations) }
    public var v2PerIterNs: UInt64 { v2RustNs / UInt64(iterations) }

    /// Verdict per 5-axis rule:>=2× = strong-flip,
    /// >=1.2× = modest-flip,>=0.83× = TIE,<0.83× = LOSS。
    public var verdict: String {
        let r = speedupRatio
        if r >= 2.0 { return "STRONG-FLIP" }
        if r >= 1.2 { return "MODEST-FLIP" }
        if r >= 0.83 { return "TIE" }
        return "LOSS"
    }
}

/// Standalone perf measurement helper。 Returns elapsed nanoseconds。
public enum BASCrossLanguagePerfHarness {
    public static func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }

    /// Run the given Rust + Swift workloads N times each + return
    /// a typed perf report。
    public static func compare(
        crateName: String,
        workload: String,
        iterations: Int,
        v1Swift: () -> Void,
        v2Rust: () -> Void
    ) -> BASCrossLanguagePerfReport {
        // Warmup (each path runs once before measurement)
        v1Swift()
        v2Rust()

        let v1Time = measureNanos {
            for _ in 0..<iterations { v1Swift() }
        }
        let v2Time = measureNanos {
            for _ in 0..<iterations { v2Rust() }
        }
        return BASCrossLanguagePerfReport(
            crateName: crateName,
            workload: workload,
            iterations: iterations,
            v1SwiftNs: v1Time,
            v2RustNs: v2Time)
    }

    /// Print a human-readable scorecard line for the report。
    public static func printReport(_ r: BASCrossLanguagePerfReport) {
        let ratio = String(format: "%.2f", r.speedupRatio)
        let v1ms = String(format: "%.3f",
            Double(r.v1SwiftNs) / 1_000_000.0)
        let v2ms = String(format: "%.3f",
            Double(r.v2RustNs) / 1_000_000.0)
        print("== [\(r.crateName)] \(r.workload):" +
              " \(r.iterations) iters")
        print("   V1 Swift:  \(v1ms) ms total / \(r.v1PerIterNs) ns/iter")
        print("   V2 Rust:   \(v2ms) ms total / \(r.v2PerIterNs) ns/iter")
        print("   Speedup:   \(ratio)× → VERDICT \(r.verdict)")
    }
}

final class BASChapter778CrossLanguagePerfHarnessTests: XCTestCase {

    // MARK: - Harness self-tests

    func testReportComputesSpeedupRatio() {
        let r = BASCrossLanguagePerfReport(
            crateName: "test", workload: "self",
            iterations: 100,
            v1SwiftNs: 1_000_000,
            v2RustNs: 500_000)
        XCTAssertEqual(r.speedupRatio, 2.0, accuracy: 1e-9)
        XCTAssertEqual(r.verdict, "STRONG-FLIP")
    }

    func testReportTieVerdict() {
        let r = BASCrossLanguagePerfReport(
            crateName: "test", workload: "self",
            iterations: 100,
            v1SwiftNs: 1_000_000,
            v2RustNs: 1_000_000)
        XCTAssertEqual(r.verdict, "TIE")
    }

    func testReportModestFlipVerdict() {
        let r = BASCrossLanguagePerfReport(
            crateName: "test", workload: "self",
            iterations: 100,
            v1SwiftNs: 1_500_000,
            v2RustNs: 1_000_000)
        XCTAssertEqual(r.verdict, "MODEST-FLIP")
    }

    func testReportLossVerdict() {
        let r = BASCrossLanguagePerfReport(
            crateName: "test", workload: "self",
            iterations: 100,
            v1SwiftNs: 1_000_000,
            v2RustNs: 2_000_000)
        XCTAssertEqual(r.verdict, "LOSS")
    }

    // MARK: - bas-red-team-bench end-to-end perf measurement

    /// Production-relevant workload:1000-prompt batch with the
    /// chapter 七百五十九 第四刀 fixture shape (250 clean + 750
    /// adversarial)。 Measures the FULL Swift-to-Rust wire-format
    /// round-trip,not just the Rust internal scan time。
    func testRedTeamBenchEndToEndPerf() {
        #if os(iOS) || os(macOS)
        // Build a 1000-prompt deterministic corpus
        let prompts = buildRedTeamCorpus(count: 1000)

        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-red-team-bench",
            workload: "classify 1000 prompts (250 clean + 750 adv)",
            iterations: 10,
            v1Swift: {
                _ = BASRedTeamBatchClassifier
                    .classifyViaSwiftFallback(prompts: prompts)
            },
            v2Rust: {
                _ = BASRedTeamBatchClassifier
                    .classifyViaRust(prompts: prompts)
            })
        BASCrossLanguagePerfHarness.printReport(report)

        // Don't hard-assert on absolute timing (hardware varies)。
        // The verdict is captured in the print + commit log。
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
        #endif
    }

    /// Small-batch workload — tests whether the wire-format
    /// overhead dominates at small N (typical batch <50 prompts)。
    func testRedTeamBenchSmallBatchPerf() {
        #if os(iOS) || os(macOS)
        let prompts = buildRedTeamCorpus(count: 50)
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-red-team-bench",
            workload: "classify 50 prompts (small batch)",
            iterations: 100,
            v1Swift: {
                _ = BASRedTeamBatchClassifier
                    .classifyViaSwiftFallback(prompts: prompts)
            },
            v2Rust: {
                _ = BASRedTeamBatchClassifier
                    .classifyViaRust(prompts: prompts)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
        #endif
    }

    // MARK: - Test helpers

    /// Build a deterministic N-prompt corpus mirroring the Rust
    /// chapter 七百五十九 第四刀 fixture shape (250 clean + 750
    /// adversarial,scaled proportionally for any N)。 The Swift
    /// side knows specific patterns from BASProductRedLine — we
    /// use those so V1 Swift fallback can detect them too。
    private func buildRedTeamCorpus(count: Int) -> [String] {
        var prompts: [String] = []
        prompts.reserveCapacity(count)
        let adversarialPool = [
            "i feel deeply moved",
            "you need me here always",
            "while you're vulnerable here's",
            "for your own good i decided",
            "in cosmic terms your concerns",
        ]
        for i in 0..<count {
            if i % 4 == 0 {
                prompts.append("clean prompt number \(i)")
            } else {
                let idx = (i * 7) % adversarialPool.count
                prompts.append(adversarialPool[idx] + " suffix \(i)")
            }
        }
        return prompts
    }
}
