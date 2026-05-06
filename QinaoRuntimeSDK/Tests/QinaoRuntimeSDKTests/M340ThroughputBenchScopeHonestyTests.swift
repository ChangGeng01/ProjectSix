import XCTest
import Foundation

/// M340 — pin that the throughput bench scope disclaimer cannot be
/// silently weakened.
///
/// ## Why this exists
///
/// M334 ships `ThroughputBenchDemo` (in `QinaoSampleHost`, an
/// executable target) which emits sub-millisecond latency numbers
/// (p50 ~0.001 ms in smoke tests). Those numbers look impressive
/// but they are NOT what a real session would experience — they
/// measure substrate state-machine cycle latency only, not Apple
/// Foundation Models inference + audit ledger I/O + actor hops
/// across runtime layers.
///
/// The scope disclaimer (`ThroughputBenchDemo.scopeStatement`) is
/// the canonical machine-readable warning. The banner emits it at
/// the top of every `--throughput-bench` run.
///
/// `QinaoSampleHost` is an executable target so we cannot
/// `@testable import` it directly. Instead this test locates the
/// `ThroughputBenchDemo.swift` source file via the package layout
/// and asserts the disclaimer text contains the canonical phrases.
/// If a future refactor weakens any phrase here, this test fails
/// and the PR author has to explain why in the same change.
final class M340ThroughputBenchScopeHonestyTests: XCTestCase {

    /// Locate `ThroughputBenchDemo.swift` from the test bundle's
    /// own URL by walking up to the package root.
    private func loadDemoSource() throws -> String {
        let testFileURL = URL(
            fileURLWithPath: #filePath)
        // .../Tests/QinaoRuntimeSDKTests/M340*.swift
        // → .../Tests/QinaoRuntimeSDKTests/
        // → .../Tests/
        // → .../ (package root)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let demoURL = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("QinaoSampleHost")
            .appendingPathComponent(
                "ThroughputBenchDemo.swift")
        return try String(
            contentsOf: demoURL, encoding: .utf8)
    }

    /// Extract the contents of the `scopeStatement` string literal
    /// by isolating the lines between `let scopeStatement: String =`
    /// and the trailing `"`.
    private func extractScopeStatement(
        from source: String
    ) throws -> String {
        // Find the declaration. The pinned shape is a multi-line
        // string concatenation; we just grep for the content lines
        // that contain `scope` keywords.
        let needle = "scopeStatement"
        guard source.contains(needle) else {
            XCTFail(
                "ThroughputBenchDemo.swift no longer declares " +
                "scopeStatement — M340 disclaimer pin lost. " +
                "Restore the canonical disclaimer or update " +
                "this test in the same PR.")
            return ""
        }
        // Lower-case full source — disclaimer phrases must be
        // present somewhere in the file. We don't try to parse
        // Swift string literal precisely (#filePath-driven test
        // is simple by design); we just check the canonical
        // phrases appear in the source.
        return source.lowercased()
    }

    func testScopeStatementContainsRegressionAlarmDisclaimer()
        throws
    {
        let source = try loadDemoSource()
        let lower = try extractScopeStatement(from: source)

        XCTAssertTrue(
            lower.contains("regression alarm"),
            "scope disclaimer must say \"regression alarm\" " +
            "explicitly somewhere in ThroughputBenchDemo.swift.")

        XCTAssertTrue(
            lower.contains("not an sla"),
            "scope disclaimer must say \"not an sla\" " +
            "explicitly somewhere in ThroughputBenchDemo.swift.")
    }

    func testScopeStatementListsExclusions() throws {
        let source = try loadDemoSource()
        let lower = try extractScopeStatement(from: source)

        XCTAssertTrue(
            lower.contains("model inference"),
            "scope disclaimer must call out that model inference " +
            "is NOT measured.")

        XCTAssertTrue(
            lower.contains("audit-ledger") ||
            lower.contains("audit ledger"),
            "scope disclaimer must call out that audit ledger " +
            "I/O is NOT measured.")

        XCTAssertTrue(
            lower.contains("actor hops"),
            "scope disclaimer must call out that actor hops are " +
            "NOT measured.")
    }

    func testScopeStatementWarnsAgainstQuoting() throws {
        let source = try loadDemoSource()
        let lower = try extractScopeStatement(from: source)

        XCTAssertTrue(
            lower.contains("do not quote") ||
            lower.contains("don't quote") ||
            lower.contains("not be quoted") ||
            lower.contains("not for"),
            "scope disclaimer must warn against quoting these " +
            "numbers as customer-facing latency.")
    }

    func testMainBannerEmitsScopeStatement() throws {
        // Phase Alpha (chapter 二百八十九 / M776) extracted
        // `runThroughputBench` from `main.swift` to
        // `SampleHostDemoExtensions.swift`. Test now scans all
        // .swift files under the QinaoSampleHost source directory
        // for the disclaimer reference — file-org-change-safe.
        let testFileURL = URL(
            fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("QinaoSampleHost")

        let fm = FileManager.default
        let urls =
            try fm.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "swift" }

        var found = false
        for url in urls {
            let source = try String(
                contentsOf: url, encoding: .utf8)
            if source.contains(
                "ThroughputBenchDemo.scopeStatement")
            {
                found = true
                break
            }
        }

        XCTAssertTrue(
            found,
            "QinaoSampleHost source must emit " +
            "ThroughputBenchDemo.scopeStatement somewhere in " +
            "the runThroughputBench banner so every " +
            "`--throughput-bench` run shows the disclaimer at " +
            "the top of stdout.")
    }
}
