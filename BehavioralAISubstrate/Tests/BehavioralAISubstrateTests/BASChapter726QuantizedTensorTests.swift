// MARK: - BASChapter726QuantizedTensorTests
// chapter 七百二十六 第四刀 / M2304
//
// Anti-drift suite for BASQuantizedTensor typed wrapper。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter726QuantizedTensorTests: XCTestCase {

    func testInitFromFloatValuesQuantizesAndStoresShape() {
        #if os(iOS) || os(macOS)
        let values: [Float] = [0.1, 0.2, 0.3, 0.4]
        let t = BASQuantizedTensor(
            floatValues: values, shape: [4])
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.shape, [4])
        XCTAssertEqual(t!.count, 4)
        XCTAssertEqual(t!.data.count, 4)
        #endif
    }

    func testInitRejectsShapeMismatch() {
        #if os(iOS) || os(macOS)
        // 4 values but shape says [3]
        let mismatched = BASQuantizedTensor(
            floatValues: [1, 2, 3, 4],
            shape: [3])
        XCTAssertNil(mismatched)
        // Direct init with mismatch throws
        let q: [Int8] = [1, 2, 3]
        XCTAssertThrowsError(
            try BASQuantizedTensor(
                shape: [5],
                quantized: q,
                scale: 1.0))
        #endif
    }

    func testRoundTripDequantizePreservesValues() {
        #if os(iOS) || os(macOS)
        let values: [Float] = (0..<10).map {
            Float($0) / 10.0
        }
        let t = BASQuantizedTensor(
            floatValues: values, shape: [10])!
        let back = t.dequantizeToFloat32()!
        XCTAssertEqual(back.count, values.count)
        for i in 0..<values.count {
            XCTAssertEqual(
                back[i], values[i], accuracy: 0.005)
        }
        #endif
    }

    func test2DShapeRoundTrips() {
        #if os(iOS) || os(macOS)
        // 3×4 matrix
        let values: [Float] = (0..<12).map {
            Float($0) / 12.0 - 0.5
        }
        let t = BASQuantizedTensor(
            floatValues: values, shape: [3, 4])!
        XCTAssertEqual(t.shape, [3, 4])
        XCTAssertEqual(t.count, 12)
        let back = t.dequantizeToFloat32()!
        XCTAssertEqual(back.count, 12)
        #endif
    }

    func testCodableRoundTrip() throws {
        #if os(iOS) || os(macOS)
        let values: [Float] = [0.5, -0.3, 0.8, -0.1, 0.2]
        let t = BASQuantizedTensor(
            floatValues: values, shape: [5])!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try encoder.encode(t)
        let back = try JSONDecoder().decode(
            BASQuantizedTensor.self, from: json)
        XCTAssertEqual(t, back)
        // Dequantizes to same values
        let recovered = back.dequantizeToFloat32()!
        for i in 0..<values.count {
            XCTAssertEqual(
                recovered[i], values[i], accuracy: 0.01)
        }
        #endif
    }

    func testMemoryShrinkRatioCloseToFour() {
        #if os(iOS) || os(macOS)
        let values = [Float](repeating: 0.5, count: 1024)
        let t = BASQuantizedTensor(
            floatValues: values, shape: [1024])!
        XCTAssertGreaterThan(t.memoryShrinkRatio, 3.9)
        XCTAssertLessThan(t.memoryShrinkRatio, 4.0)
        XCTAssertEqual(
            t.float32EquivalentByteSize, 4096)
        #endif
    }

    func testToInt8ArrayReturnsOriginalBuffer() throws {
        #if os(iOS) || os(macOS)
        let q: [Int8] = [10, -20, 30, -40, 50]
        let t = try BASQuantizedTensor(
            shape: [5],
            quantized: q,
            scale: 0.1)
        XCTAssertEqual(t.toInt8Array(), q)
        #endif
    }
}
