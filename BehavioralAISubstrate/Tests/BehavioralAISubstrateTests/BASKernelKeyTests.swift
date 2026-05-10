// MARK: - BASKernelKeyTests — chapter 四百三十一 / M1098

import XCTest
@testable import BASMetalSubstrate

final class BASKernelKeyTests: XCTestCase {

    // MARK: - Direct init persists fields

    func testDirectInit() {
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .metalBuffer)
        XCTAssertEqual(key.operation, .matMul)
        XCTAssertEqual(key.dataType, .float32)
        XCTAssertEqual(key.backingKind, .metalBuffer)
    }

    // MARK: - Wire-form identifier byte-stable

    func testWireFormIdentifier() {
        let key = BASKernelKey(
            operation: .rmsNorm,
            dataType: .float16,
            backingKind: .mlxArray)
        XCTAssertEqual(
            key.wireFormIdentifier,
            "rms-norm|float16|mlx-array")
    }

    // MARK: - Equality + hashability for dictionary key

    func testEqualKeysHashEqual() {
        let k1 = BASKernelKey(
            operation: .softmax,
            dataType: .float32,
            backingKind: .cpuBytes)
        let k2 = BASKernelKey(
            operation: .softmax,
            dataType: .float32,
            backingKind: .cpuBytes)
        XCTAssertEqual(k1, k2)
        XCTAssertEqual(k1.hashValue, k2.hashValue)
    }

    func testDifferentBackingsHashDifferent() {
        let k1 = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .metalBuffer)
        let k2 = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .mlxArray)
        XCTAssertNotEqual(k1, k2)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASKernelKey(
            operation: .attention,
            dataType: .float16,
            backingKind: .metalBuffer)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(BASKernelKey.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCodableSortedKeysByteStable() throws {
        let key = BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let e1 = try encoder.encode(key)
        let e2 = try encoder.encode(key)
        XCTAssertEqual(e1, e2,
            "sortedKeys must produce byte-stable JSON " +
            "(chapter 三百九二)")
    }
}
