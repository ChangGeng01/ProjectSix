// MARK: - BASStageAcceleratorHintTests — chapter 四百三十二 / M1102

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASStageAcceleratorHintTests: XCTestCase {

    // MARK: - Preference enum

    func testPreferenceRawValues() {
        XCTAssertEqual(
            BASStageAcceleratorPreference.lowestLatency
                .rawValue,
            "lowest-latency")
        XCTAssertEqual(
            BASStageAcceleratorPreference.lowestEnergy
                .rawValue,
            "lowest-energy")
        XCTAssertEqual(
            BASStageAcceleratorPreference.balanced
                .rawValue,
            "balanced")
        XCTAssertEqual(
            BASStageAcceleratorPreference.allCases.count,
            3)
    }

    // MARK: - Direct init persists fields

    func testDirectInitPersistsAllFields() {
        let hint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 4,
            sequenceLength: 128,
            latencyBudgetMs: 8.0,
            preference: .lowestLatency)
        XCTAssertEqual(hint.operation, .matMul)
        XCTAssertEqual(
            hint.preferredDataType, .float16)
        XCTAssertEqual(hint.batchSize, 4)
        XCTAssertEqual(hint.sequenceLength, 128)
        XCTAssertEqual(hint.latencyBudgetMs, 8.0)
        XCTAssertEqual(
            hint.preference, .lowestLatency)
    }

    // MARK: - Default preference is .balanced

    func testDefaultPreferenceIsBalanced() {
        let hint = BASStageAcceleratorHint(
            operation: .softmax,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 100)
        XCTAssertEqual(hint.preference, .balanced)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASStageAcceleratorHint(
            operation: .attention,
            preferredDataType: .float16,
            batchSize: 8,
            sequenceLength: 256,
            latencyBudgetMs: 5.0,
            preference: .lowestEnergy)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASStageAcceleratorHint.self,
                from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equality + hashability

    func testEqualHintsAreEqual() {
        let h1 = BASStageAcceleratorHint(
            operation: .rmsNorm,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1.0)
        let h2 = BASStageAcceleratorHint(
            operation: .rmsNorm,
            preferredDataType: .float32,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 1.0)
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.hashValue, h2.hashValue)
    }
}
