// MARK: - BASNeuralOpTests — chapter 四百三十一 / M1097

import XCTest
@testable import BASMetalSubstrate

final class BASNeuralOpTests: XCTestCase {

    // MARK: - Pinned vocabulary size

    func testEightOpsShipped() {
        XCTAssertEqual(BASNeuralOp.allCases.count, 8,
            "M1097 ships 8 neural ops:matMul/conv2D/" +
            "attention/layerNorm/rmsNorm/softmax/" +
            "rotaryEmbedding/ssmScan")
    }

    // MARK: - Raw values byte-stable

    func testRawValuesByteStable() {
        XCTAssertEqual(BASNeuralOp.matMul.rawValue,
            "mat-mul")
        XCTAssertEqual(BASNeuralOp.conv2D.rawValue,
            "conv-2d")
        XCTAssertEqual(BASNeuralOp.attention.rawValue,
            "attention")
        XCTAssertEqual(BASNeuralOp.layerNorm.rawValue,
            "layer-norm")
        XCTAssertEqual(BASNeuralOp.rmsNorm.rawValue,
            "rms-norm")
        XCTAssertEqual(BASNeuralOp.softmax.rawValue,
            "softmax")
        XCTAssertEqual(BASNeuralOp.rotaryEmbedding.rawValue,
            "rotary-embedding")
        XCTAssertEqual(BASNeuralOp.ssmScan.rawValue,
            "ssm-scan")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for op in BASNeuralOp.allCases {
            let encoded = try encoder.encode(op)
            let decoded = try JSONDecoder()
                .decode(BASNeuralOp.self, from: encoded)
            XCTAssertEqual(decoded, op)
        }
    }

    // MARK: - Set membership for capability

    func testHashableForSetMembership() {
        let opSet: Set<BASNeuralOp> = [
            .matMul, .attention, .rmsNorm]
        XCTAssertTrue(opSet.contains(.matMul))
        XCTAssertFalse(opSet.contains(.ssmScan))
        XCTAssertEqual(opSet.count, 3)
    }
}
