// MARK: - BASChapter881ForgetCascadeDeclineAuditTests
// chapter 八百八十一 / M3090 — Gap 3 DECLINE-WITH-TRIGGER audit
//
// User's gap-3 observation: 「Forget/tombstone 还半成品。 SQL
// tombstone schema 有,forget cascade runner 有,Rust filter 有;
// 但 Rust forget 路径默认还是关的,因为之前 perf 证明小批量 FFI
// 不划算。」
//
// Chapter 881 knife 1 (`BASChapter881ForgetCascadeBaselineTests`)
// captured LIVE measurement at the full production grid on Mac
// mini (2026-05-23):
//
//   records ∈ {10, 100, 1K, 10K} × targets ∈ {1, 10, 100, 1K} ×
//   hit ∈ {10%, 50%, 100%}
//
// Result: Swift Set<String> partition won EVERY measured shape
// by 2-3×。 The user's framing 「小批量 FFI 不划算」 was correct,
// but the measurement shows the gap is NOT just at small batches
// — it persists at the largest production size (10K records ×
// 1K targets,Swift 1.79ms vs Rust 4.62ms = Swift 2.58× faster)。
//
// Root cause: string FFI dominates。 Each call must:
//   1. Length-prefix encode N record IDs as UTF-8 in Swift
//   2. Copy bytes across the C ABI
//   3. Re-decode strings + own them in Rust
//   4. Build a HashSet<String> from owned Strings
//   5. Filter + return index arrays
//   6. Swift materializes records by index
//
// Versus Swift's native Set<String> which:
//   1. Hash IDs in-place (no copy,no encode)
//   2. Linear scan with set-contains
//
// Per 「亏的不要硬上」 discipline + chapter 870 pattern,this
// audit chapter PINS the decline (matches chapter 874/875
// RoPE/RMSNorm decline-pending-consumer pattern)。

import XCTest
@testable import BASMemory

final class BASChapter881ForgetCascadeDeclineAuditTests:
    XCTestCase
{

    /// PIN: the production default for `useRoutedFilter` is
    /// `false` (Swift path)。 If a future chapter flips this
    /// without re-running the chapter 881 baseline + getting
    /// a different measurement,this test will fail。 Forces
    /// the chapter that wants to flip to:
    ///   (a) Re-run BASChapter881ForgetCascadeBaselineTests
    ///       (flip skip off,capture fresh numbers)
    ///   (b) If Rust now wins,update this test + cite the new
    ///       measurement
    ///   (c) If Rust still loses,document why the flip is
    ///       being attempted anyway (very high bar per
    ///       「亏的不要硬上」)
    func testProductionDefaultIsSwift() {
        XCTAssertFalse(
            BASMemoryForgetCascadeRunner.useRoutedFilter,
            "useRoutedFilter must default false — chapter " +
            "881 measurement showed Swift Set wins 2-3× at " +
            "every production size。 If you flip this,re-run " +
            "BASChapter881ForgetCascadeBaselineTests + update " +
            "this audit test。")
    }

    /// PIN: the measurement data + verdict + root cause are
    /// documented adjacent to the field declaration。 Test
    /// loads the runner file + checks the chapter 881 decline
    /// citation is present。 If a future chapter rewrites the
    /// doc-string and drops the chapter 881 citation,this
    /// test will fail。
    func testRunnerDocCitesChapter881Decline() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASMemory")
            .appendingPathComponent(
                "BASMemoryForgetCascadeRunner.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains("chapter 八百八十一"),
            "Runner doc-string must cite chapter 881 decline " +
            "(was dropped by later chapter?)")
        XCTAssertTrue(
            content.contains("DECLINE-WITH-TRIGGER"),
            "Runner doc-string must label the decline " +
            "explicitly (DECLINE-WITH-TRIGGER pattern)")
        // Allow line-break tolerance in the doc-string by
        // checking for both halves separately + the verdict
        // numeric (2.58×) which is hard to break。
        XCTAssertTrue(
            content.contains("Swift won")
                && content.contains("EVERY shape"),
            "Runner doc-string must cite the measurement " +
            "verdict (Swift wins all measured shapes)")
        XCTAssertTrue(
            content.contains("2.58×")
                || content.contains("by 2-3×"),
            "Runner doc-string must cite the numeric " +
            "measurement (Swift 2.58× faster at largest size)")
    }

    /// Trigger conditions for future re-evaluation。 If any
    /// chapter wants to revisit the decline,it must address
    /// at least ONE of these triggers + re-run the baseline
    /// + get a different verdict。
    func testTriggerConditionsDocumented() {
        let triggers: [String] = [
            "Trigger A: NEW batched-cascade C ABI that amortizes " +
                "string-FFI hop across N cascades in a single call",
            "Trigger B: SWITCH ID encoding from String to numeric " +
                "(UInt64) — removes UTF-8 encode/decode work",
            "Trigger C: Production forget volumes exceed 100K " +
                "records × 10K targets in a single call (10× " +
                "above measured grid)",
            "Trigger D: New Swift release degrades Set<String> " +
                "perf by ≥3× (would close the current 2-3× gap)",
        ]
        XCTAssertEqual(triggers.count, 4,
            "4 trigger conditions documented for future " +
            "re-evaluation of the chapter 881 decline")
        let labels = ["A", "B", "C", "D"]
        for (i, t) in triggers.enumerated() {
            let prefix = "Trigger " + labels[i] + ":"
            XCTAssertTrue(
                t.hasPrefix(prefix),
                "Trigger \(i+1) should start with " + prefix)
        }
    }

    /// PIN: the byte-equality test from chapter 717 must
    /// stay PASSING — if a future chapter breaks the Rust
    /// path's correctness,we need the byte-eq test to catch
    /// it BEFORE the chapter 881 decline can be lifted。
    /// (Sanity reference test — the byte-eq class itself
    /// exercises both paths;this audit confirms the file
    /// exists。)
    func testByteEqualityTestFileExists() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "BASChapter717ForgetCascadeByteEqualityTests" +
                ".swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "BASChapter717ForgetCascadeByteEqualityTests must " +
            "stay present — proves both paths produce " +
            "byte-equal output regardless of which is the " +
            "default")
    }
}
