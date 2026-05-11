// MARK: - BASMambaBenchmarkExpansionTests
// chapter 四百七十一 / M1262 PROOF tests
//
// Verifies harness expansion (chapter 471) — Mamba
// selective-scan benchmark path is functional + emits
// real measurements。 Assertions are STRUCTURE-only;
// hardware-varying µs values are emitted to test logs。

import XCTest
@testable import BASMetalSubstrate

final class BASMambaBenchmarkExpansionTests: XCTestCase
{

    func testHarnessRunMambaProducesSensibleReport()
        async throws
    {
        let harness = BASMetalBenchmarkHarness()
        let report = try await harness.runMambaScan(
            batch: 1, hiddenDim: 4, stateDim: 4,
            sequenceLength: 16,
            warmupIterations: 1,
            timedIterations: 3)
        XCTAssertEqual(
            report.cpuMicrosecondsSamples.count, 3)
        for sample in report.cpuMicrosecondsSamples {
            XCTAssertGreaterThanOrEqual(sample, 0)
            XCTAssertFalse(sample.isNaN)
        }
        XCTAssertGreaterThan(
            report.cpuMicrosecondsMean, 0)
        print("\n# Mamba scan benchmark (chapter 471):")
        print(report.summary)
    }

    func testHarnessHandlesLargerMambaShape() async throws
    {
        let harness = BASMetalBenchmarkHarness()
        let report = try await harness.runMambaScan(
            batch: 1, hiddenDim: 8, stateDim: 8,
            sequenceLength: 32,
            warmupIterations: 1,
            timedIterations: 2)
        XCTAssertGreaterThan(
            report.cpuMicrosecondsMean, 0)
        // Don't assert specific speedup;hardware varies
    }
}
