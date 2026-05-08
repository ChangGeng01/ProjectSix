// MARK: - BASCoreMLOperatorWhitelistTests — chapter 四百 / M923

import XCTest
@testable import BASRuntimeCore

final class BASCoreMLOperatorWhitelistTests: XCTestCase {

    func testWhitelistVersionPinned() {
        XCTAssertEqual(
            BASCoreMLOperatorWhitelist.whitelistVersion,
            "M923.1.0.0")
    }

    func testANESafeListContainsCommonOperators() {
        let names = BASCoreMLOperatorWhitelist
            .aneSafeOperatorNames
        XCTAssertTrue(names.contains("MatMul"))
        XCTAssertTrue(names.contains("Convolution"))
        XCTAssertTrue(names.contains("LayerNormalization"))
        XCTAssertTrue(names.contains("RMSNorm"))
        XCTAssertTrue(names.contains("GELU"))
        XCTAssertTrue(names.contains("SiLU"))
    }

    func testMambaRiskyListContainsScanOperators() {
        let names = BASCoreMLOperatorWhitelist
            .mambaRiskyOperatorNames
        XCTAssertTrue(names.contains("CumulativeSum"))
        XCTAssertTrue(names.contains("CumulativeProduct"))
        XCTAssertTrue(names.contains("ParallelScan"))
        XCTAssertTrue(names.contains("Scan"))
    }

    func testCheckCompliantModelHasNoIssues() {
        let usage = ["MatMul", "Convolution", "RMSNorm",
                     "GELU", "Embedding", "Reshape"]
        let result = BASCoreMLOperatorWhitelist.check(
            operatorsUsed: usage)
        XCTAssertTrue(result.isFullyCompliant)
        XCTAssertEqual(result.unsupportedOperators, [])
        XCTAssertEqual(result.mambaRiskyOperators, [])
    }

    func testCheckMambaModelFlagsScan() {
        // Typical Mamba ops + selective scan
        let usage = ["MatMul", "RMSNorm", "GELU",
                     "Convolution", "ParallelScan",
                     "CumulativeSum"]
        let result = BASCoreMLOperatorWhitelist.check(
            operatorsUsed: usage)
        XCTAssertFalse(result.isFullyCompliant)
        XCTAssertEqual(result.unsupportedOperators, [])
        XCTAssertEqual(
            Set(result.mambaRiskyOperators),
            ["ParallelScan", "CumulativeSum"])
    }

    func testCheckUnknownOperatorFlaggedUnsupported() {
        let usage = ["MatMul", "TotallyMadeUpOperator"]
        let result = BASCoreMLOperatorWhitelist.check(
            operatorsUsed: usage)
        XCTAssertFalse(result.isFullyCompliant)
        XCTAssertEqual(
            result.unsupportedOperators,
            ["TotallyMadeUpOperator"])
    }

    func testCheckDeduplicatesInput() {
        let usage = ["MatMul", "MatMul", "MatMul",
                     "GELU", "GELU"]
        let result = BASCoreMLOperatorWhitelist.check(
            operatorsUsed: usage)
        XCTAssertEqual(
            Set(result.operatorsUsed),
            ["MatMul", "GELU"])
    }

    func testAllKnownIsUnion() {
        let allKnown = Set(BASCoreMLOperatorWhitelist
            .allKnownOperators.map(\.name))
        let safe = BASCoreMLOperatorWhitelist
            .aneSafeOperatorNames
        let risky = BASCoreMLOperatorWhitelist
            .mambaRiskyOperatorNames
        XCTAssertEqual(allKnown, safe.union(risky))
    }

    func testCodableRoundTripOfComplianceCheck() throws {
        let check = BASCoreMLOperatorComplianceCheck(
            operatorsUsed: ["MatMul", "Scan"],
            unsupportedOperators: [],
            mambaRiskyOperators: ["Scan"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(check)
        let decoded = try decoder.decode(
            BASCoreMLOperatorComplianceCheck.self,
            from: data)
        XCTAssertEqual(decoded, check)
    }
}
