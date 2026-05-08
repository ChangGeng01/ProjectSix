// MARK: - BASMambaModelArchitectureSpecTests — chapter 四百 / M921

import XCTest
@testable import BASRuntimeCore

final class BASMambaModelArchitectureSpecTests: XCTestCase {

    func testDefaultsAreSmallSize() {
        let spec = BASMambaModelArchitectureSpec()
        XCTAssertEqual(spec.dModel, 768)
        XCTAssertEqual(spec.nLayers, 24)
        XCTAssertEqual(spec.dState, 16)
        XCTAssertEqual(spec.dConv, 4)
        XCTAssertEqual(spec.expand, 2)
        XCTAssertEqual(spec.vocabSize, 64)
        XCTAssertEqual(spec.maxSequenceLength, 2048)
    }

    func testSmallPreset() {
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .small, tag: "test-tag")
        XCTAssertEqual(spec.dModel, 768)
        XCTAssertEqual(spec.nLayers, 24)
        XCTAssertEqual(spec.tag, "test-tag")
    }

    func testBasePreset() {
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .base)
        XCTAssertEqual(spec.dModel, 1024)
        XCTAssertEqual(spec.nLayers, 48)
    }

    func testLargePreset() {
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .large)
        XCTAssertEqual(spec.dModel, 1536)
        XCTAssertEqual(spec.nLayers, 48)
    }

    func testXLargePreset() {
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .xlarge)
        XCTAssertEqual(spec.dModel, 2048)
        XCTAssertEqual(spec.nLayers, 48)
    }

    func testSizeClassesPinned() {
        XCTAssertEqual(
            BASMambaModelSizeClass.allCases.count, 4)
    }

    func testParameterCountEstimateForSmallIsInBallpark() {
        // Mamba-130M is the small preset → estimated count
        // should be in the 130M-150M ballpark (paper formula
        // approximation ± 10%)
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .small)
        let count = spec.estimatedParameterCount
        XCTAssertGreaterThan(count, 80_000_000,
            "Small Mamba should be > 80M params")
        XCTAssertLessThan(count, 200_000_000,
            "Small Mamba should be < 200M params")
    }

    func testParameterCountScalesUpWithSize() {
        let small = BASMambaModelArchitectureSpec
            .preset(for: .small)
            .estimatedParameterCount
        let xlarge = BASMambaModelArchitectureSpec
            .preset(for: .xlarge)
            .estimatedParameterCount
        XCTAssertGreaterThan(xlarge, small * 5,
            "xlarge should be much larger than small")
    }

    func testCodableRoundTrip() throws {
        let spec = BASMambaModelArchitectureSpec.preset(
            for: .base, tag: "roundtrip-test")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(spec)
        let decoded = try decoder.decode(
            BASMambaModelArchitectureSpec.self, from: data)
        XCTAssertEqual(decoded, spec)
    }
}
