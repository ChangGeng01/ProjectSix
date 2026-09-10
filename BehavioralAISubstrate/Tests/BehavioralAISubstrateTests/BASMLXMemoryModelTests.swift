import XCTest
@testable import BASMLXAdapter

/// Pins the single-source-of-truth values + the resident→peak invariant. These assert the EXACT values the
/// budget/governor delegated away, so a future edit that changes a number surfaces here.
final class BASMLXMemoryModelTests: XCTestCase {
    private let mib = 1024 * 1024
    private let gib = 1024 * 1024 * 1024

    func testCanonicalConstantsMatchTodaysValues() {
        XCTAssertEqual(BASMLXMemoryModel.measuredIPhoneAirActiveHardCapBytes, 3_376 * mib)
        XCTAssertEqual(BASMLXMemoryModel.defaultSpeculativeFitBudgetBytes, 3_000 * mib)
        XCTAssertEqual(BASMLXMemoryModel.dualResidencyCacheFloorBytes, 768 * mib)
        XCTAssertEqual(BASMLXMemoryModel.defaultCacheLimitBytes, 512 * mib)
        XCTAssertEqual(BASMLXMemoryModel.highWaterRatio, 0.9)
        XCTAssertEqual(BASMLXMemoryModel.lowWaterRatio, 0.8)
        XCTAssertEqual(BASMLXMemoryModel.unknownResidentFallbackBytes, 2 * gib)
    }

    func testResidentAndPeakTablesMatchTodaysValues() {
        // Resident column (was approxResidentBytes).
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.gemma4.e4b.it.4bit"), 2_700 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.gemma4.e2b.it.4bit"), 1_500 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.gemma3.4b.it.4bit"), 3_000 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.llama3_2.3b.it.4bit"), 1_800 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.llama3_2.1b.it.4bit"), 700 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.qwen2_5.3b.it.4bit"), 1_800 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.qwen2_5.1_5b.it.4bit"), 1_000 * mib)
        XCTAssertEqual(BASMLXMemoryModel.approxResidentBytes(forProviderID: "mlx.unknown.model"), 2 * gib,
            "unmapped → conservative 2 GB fallback")
        // Peak column (was estimatedPeakFootprintBytes).
        XCTAssertEqual(BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: "mlx.gemma4.e4b.it.4bit"), 4_314 * mib)
        XCTAssertEqual(BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: "mlx.gemma4.e2b.it.4bit"), 3_114 * mib)
        XCTAssertEqual(BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: "mlx.llama3_2.3b.it.4bit"), 2_969 * mib)
        XCTAssertNil(BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: "mlx.gemma3.4b.it.4bit"),
            "gemma3.4b has a resident estimate but no measured peak → nil")
        XCTAssertNil(BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: "mlx.unknown.model"))
    }

    func testGemma3nOverheadInvariantHolds() {
        // The documented 1614 MB Gemma-3n overhead is ENFORCED, not just commented: it must equal the
        // measured e2b resident→peak gap, so the two columns can't silently drift apart.
        let e2b = BASMLXMemoryModel.estimate(forProviderID: "mlx.gemma4.e2b.it.4bit")!
        XCTAssertEqual(e2b.peakBytes! - e2b.residentBytes, BASMLXMemoryModel.gemma3nRuntimeOverheadBytes,
            "e2b (peak − resident) must equal the named Gemma-3n overhead")
        XCTAssertEqual(BASMLXMemoryModel.gemma3nRuntimeOverheadBytes, 1_614 * mib)
    }

    func testGovernorDefaultWatermarksDeriveFromFitBudget() {
        // Pins the governor↔budget link: a future fit-budget change auto-tracks the watermarks (no desync).
        let cfg = BASSpeculationMemoryGovernor.Configuration.fromFitBudget()
        let expectedHigh = UInt64((Double(BASMLXMemoryModel.defaultSpeculativeFitBudgetBytes)
            * BASMLXMemoryModel.highWaterRatio).rounded(.down))
        XCTAssertEqual(cfg.highWaterBytes, expectedHigh)
        let expectedLow = UInt64((Double(cfg.highWaterBytes)
            * BASMLXMemoryModel.lowWaterRatio).rounded(.down))
        XCTAssertEqual(cfg.lowWaterBytes, expectedLow)
    }
}
