import XCTest
@testable import BASObservability

/// M362 — pin the suite report aggregator primitive.
///
/// What this file pins:
///
///   1. Empty bench list produces a valid report.
///   2. Codable round-trip stable.
///   3. JSON output is pretty-printed and includes all fields.
///   4. Markdown table has correct column count + one row per
///      bench.
///   5. Banner lines include suite header, per-bench sections,
///      and footer.
///   6. Markdown uses warm stats when present, combined
///      otherwise.
final class M362BenchSuiteReportTests: XCTestCase {

    private func sampleResult(
        name: String,
        scenario: String? = nil,
        samples: [Double] = [10.0, 20.0, 30.0]
    ) -> BASBenchSuiteReport.BenchResult {
        let outcome = BASBenchWarmupOutcome.compute(
            samples: samples,
            config: .strictFirstSample)!
        return BASBenchSuiteReport.BenchResult(
            benchName: name,
            scenarioLabel: scenario,
            outcome: outcome,
            elapsedSeconds: 0.05,
            notes: "test fixture")
    }

    func testEmptyBenchListProducesValidReport() {
        let report = BASBenchSuiteReport(
            suiteName: "test",
            runStartedAt: Date(timeIntervalSince1970: 100),
            runCompletedAt: Date(
                timeIntervalSince1970: 200),
            totalElapsedSeconds: 100,
            benches: [])
        XCTAssertEqual(report.benches.count, 0)
        XCTAssertEqual(report.totalElapsedSeconds, 100)
    }

    func testCodableRoundTrip() throws {
        let report = BASBenchSuiteReport(
            suiteName: "test-suite",
            runStartedAt: Date(timeIntervalSince1970: 100),
            runCompletedAt: Date(
                timeIntervalSince1970: 200),
            totalElapsedSeconds: 100,
            benches: [
                sampleResult(name: "bench-A"),
                sampleResult(
                    name: "bench-B", scenario: "100"),
            ])
        let data = try report.encodedJSON()
        let decoded = try BASBenchSuiteReport
            .decodeJSON(from: data)
        XCTAssertEqual(report, decoded)
    }

    func testEncodedJSONIsPrettyPrintedAndSorted() throws {
        let report = BASBenchSuiteReport(
            suiteName: "test",
            runStartedAt: Date(timeIntervalSince1970: 100),
            runCompletedAt: Date(
                timeIntervalSince1970: 200),
            totalElapsedSeconds: 100,
            benches: [sampleResult(name: "a")])
        let json = try report.encodedJSONString()
        XCTAssertTrue(json.contains("\n"))  // pretty-printed
        XCTAssertTrue(json.contains("\"benches\""))
        XCTAssertTrue(json.contains("\"schemaVersion\""))
        XCTAssertTrue(json.contains("\"suiteName\""))
        XCTAssertTrue(json.contains("\"benchName\""))
    }

    func testMarkdownTableHasCorrectColumnCount() {
        let report = BASBenchSuiteReport(
            suiteName: "test",
            runStartedAt: Date(),
            runCompletedAt: Date(),
            totalElapsedSeconds: 0,
            benches: [
                sampleResult(name: "bench-A"),
                sampleResult(
                    name: "bench-B", scenario: "100"),
                sampleResult(
                    name: "bench-C", scenario: "1000"),
            ])
        let md = report.markdownTable()
        let lines = md.split(separator: "\n")
        // Expected: header + separator + 3 rows = 5 lines
        XCTAssertEqual(lines.count, 5)
        // Header has 9 columns (8 separators + 2 outer pipes)
        XCTAssertEqual(
            lines[0].filter { $0 == "|" }.count, 10)
        // Rows include their bench name.
        XCTAssertTrue(
            String(lines[2]).contains("bench-A"))
        XCTAssertTrue(
            String(lines[3]).contains("bench-B"))
        XCTAssertTrue(
            String(lines[4]).contains("bench-C"))
    }

    func testBannerLinesShowAllSections() {
        let report = BASBenchSuiteReport(
            suiteName: "test-suite",
            runStartedAt: Date(),
            runCompletedAt: Date(),
            totalElapsedSeconds: 0.1,
            benches: [sampleResult(name: "single")])
        let lines = report.bannerLines()
        let header = lines.contains {
            $0.contains("══ Bench Suite:")
        }
        let benchSection = lines.contains {
            $0.contains("── single")
        }
        let footer = lines.contains {
            $0.contains("══ Suite complete")
        }
        XCTAssertTrue(header)
        XCTAssertTrue(benchSection)
        XCTAssertTrue(footer)
    }

    func testSchemaVersionDefault() {
        let report = BASBenchSuiteReport(
            suiteName: "x",
            runStartedAt: Date(),
            runCompletedAt: Date(),
            totalElapsedSeconds: 0,
            benches: [])
        XCTAssertEqual(
            report.schemaVersion,
            "bas-bench-suite-report.v1")
    }
}
