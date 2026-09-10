// MARK: - BASTensorDescriptorTests — chapter 四百三十一 / M1096

import XCTest
@testable import BASMetalSubstrate

final class BASTensorDescriptorTests: XCTestCase {

    // MARK: - Backing kind

    func testBackingKindRawValuesByteStable() {
        XCTAssertEqual(
            BASTensorBackingKind.mlxArray.rawValue,
            "mlx-array")
        XCTAssertEqual(
            BASTensorBackingKind.mlMultiArray.rawValue,
            "ml-multi-array")
        XCTAssertEqual(
            BASTensorBackingKind.metalBuffer.rawValue,
            "metal-buffer")
        XCTAssertEqual(
            BASTensorBackingKind.cpuBytes.rawValue,
            "cpu-bytes")
    }

    func testBackingKindAllCasesIs4() {
        XCTAssertEqual(
            BASTensorBackingKind.allCases.count, 4,
            "4 backing kinds at M1096")
    }

    // MARK: - Direct init

    func testDirectInitPersistsAllFields() {
        let descriptor = BASTensorDescriptor(
            shape: [2, 3],
            strides: [12, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        XCTAssertEqual(descriptor.shape, [2, 3])
        XCTAssertEqual(descriptor.strides, [12, 4])
        XCTAssertEqual(descriptor.dataType, .float32)
        XCTAssertEqual(
            descriptor.backingKind, .cpuBytes)
        XCTAssertEqual(
            descriptor.rankTag, "rank-2")
    }

    // MARK: - Element + byte counts

    func testElementCountMatrix() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [3, 4],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        XCTAssertEqual(descriptor.elementCount, 12)
        XCTAssertEqual(descriptor.byteCount, 12 * 4)
    }

    func testElementCountVector() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [10],
            dataType: .uint8,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        XCTAssertEqual(descriptor.elementCount, 10)
        XCTAssertEqual(descriptor.byteCount, 10)
    }

    func testElementCountScalarIsOne() {
        let descriptor = BASTensorDescriptor(
            shape: [],
            strides: [],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _0D.rankTag)
        XCTAssertEqual(descriptor.elementCount, 1)
        XCTAssertEqual(descriptor.byteCount, 4)
    }

    func testRank() {
        let m = BASTensorDescriptor.contiguous(
            shape: [4, 5, 6, 7],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _4D.rankTag)
        XCTAssertEqual(m.rank, 4)
    }

    // MARK: - Default strides (row-major contiguous)

    func testDefaultStridesRowMajor2D() {
        let strides = BASTensorDescriptor.defaultStrides(
            shape: [2, 3],
            byteWidth: 4)
        // Last axis stride = byteWidth (= 4)
        // Preceding axis = next axis stride × next axis size
        // = 4 × 3 = 12
        XCTAssertEqual(strides, [12, 4])
    }

    func testDefaultStridesRowMajor3D() {
        let strides = BASTensorDescriptor.defaultStrides(
            shape: [2, 3, 4],
            byteWidth: 4)
        // Axis 2 = 4
        // Axis 1 = 4 × 4 = 16
        // Axis 0 = 16 × 3 = 48
        XCTAssertEqual(strides, [48, 16, 4])
    }

    func testDefaultStridesEmpty() {
        XCTAssertTrue(
            BASTensorDescriptor.defaultStrides(
                shape: [], byteWidth: 4).isEmpty)
    }

    // MARK: - Codable round-trip (chapter 三百九二)

    func testDescriptorCodableRoundTrip() throws {
        let original = BASTensorDescriptor.contiguous(
            shape: [2, 3, 4],
            dataType: .float16,
            backingKind: .mlxArray,
            rankTag: _3D.rankTag)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASTensorDescriptor.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCodableSortedKeysByteStable() throws {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [3, 3],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded1 = try encoder.encode(descriptor)
        let encoded2 = try encoder.encode(descriptor)
        XCTAssertEqual(encoded1, encoded2,
            "sortedKeys must produce byte-stable JSON " +
            "across encode calls (chapter 三百九二)")
    }
}
