// MARK: - BASTensorTests — chapter 四百三十一 / M1096

import XCTest
@testable import BASMetalSubstrate

final class BASTensorTests: XCTestCase {

    // MARK: - CPU bytes factory

    func testCPUFactoryRoundTrip() {
        let bytes = Data([1, 2, 3, 4, 5, 6, 7, 8,
                          9, 10, 11, 12, 13, 14, 15, 16])
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let tensor: BASTensor<Float, _2D> = .cpu(
            bytes,
            descriptor: descriptor)
        XCTAssertEqual(tensor.cpuBytesIfAvailable, bytes)
        XCTAssertEqual(tensor.elementCount, 4)
        XCTAssertEqual(tensor.byteCount, 16)
        XCTAssertEqual(
            tensor.descriptor.rankTag, "rank-2")
    }

    // MARK: - Backing kind dispatch

    func testCPUBackingKind() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [4],
            dataType: .uint8,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let tensor: BASTensor<UInt8, _1D> = .cpu(
            Data([1, 2, 3, 4]),
            descriptor: descriptor)
        XCTAssertEqual(
            tensor.wrappedValue.kind, .cpuBytes)
    }

    func testMLXBackingKind() {
        let opaque = NSObject() // stand-in for MLXArray
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .mlxArray,
            rankTag: _2D.rankTag)
        let tensor: BASTensor<Float, _2D> = .mlx(
            opaque, descriptor: descriptor)
        XCTAssertEqual(
            tensor.wrappedValue.kind, .mlxArray)
        if case .mlxArray(let h) = tensor.wrappedValue {
            XCTAssertTrue(h === opaque)
        } else {
            XCTFail("expected mlxArray backing")
        }
    }

    func testCoreMLBackingKind() {
        let opaque = NSObject() // stand-in for MLMultiArray
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [3, 3],
            dataType: .float32,
            backingKind: .mlMultiArray,
            rankTag: _2D.rankTag)
        let tensor: BASTensor<Float, _2D> = .coreML(
            opaque, descriptor: descriptor)
        XCTAssertEqual(
            tensor.wrappedValue.kind, .mlMultiArray)
    }

    func testMetalBackingKind() {
        let opaque = NSObject() // stand-in for MTLBuffer
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [4, 4],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        let tensor: BASTensor<Float, _2D> = .metal(
            opaque, descriptor: descriptor)
        XCTAssertEqual(
            tensor.wrappedValue.kind, .metalBuffer)
    }

    // MARK: - cpuBytesIfAvailable returns nil for non-CPU

    func testCpuBytesIfAvailableNilForOpaqueBackings() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [2, 2],
            dataType: .float32,
            backingKind: .mlxArray,
            rankTag: _2D.rankTag)
        let tensor: BASTensor<Float, _2D> = .mlx(
            NSObject(), descriptor: descriptor)
        XCTAssertNil(tensor.cpuBytesIfAvailable)
    }

    // MARK: - Phantom rank evidence

    func testRank1Tensor() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [10],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let tensor: BASTensor<Float, _1D> = .cpu(
            Data(count: 40),
            descriptor: descriptor)
        XCTAssertEqual(tensor.descriptor.rank, 1)
    }

    func testRank4Tensor() {
        // batch=1, channels=3, h=2, w=2
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [1, 3, 2, 2],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _4D.rankTag)
        let tensor: BASTensor<Float, _4D> = .cpu(
            Data(count: 12 * 4),
            descriptor: descriptor)
        XCTAssertEqual(tensor.elementCount, 12)
        XCTAssertEqual(tensor.descriptor.rank, 4)
    }

    // MARK: - Different scalar types

    func testInt32Tensor() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [4],
            dataType: .int32,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let tensor: BASTensor<Int32, _1D> = .cpu(
            Data(count: 16),
            descriptor: descriptor)
        XCTAssertEqual(tensor.byteCount, 16)
    }

    func testUInt8Tensor() {
        let descriptor = BASTensorDescriptor.contiguous(
            shape: [256],
            dataType: .uint8,
            backingKind: .cpuBytes,
            rankTag: _1D.rankTag)
        let tensor: BASTensor<UInt8, _1D> = .cpu(
            Data(repeating: 0, count: 256),
            descriptor: descriptor)
        XCTAssertEqual(tensor.byteCount, 256)
    }

    // MARK: - Determinism

    func testDescriptorDeterministic() {
        let d1 = BASTensorDescriptor.contiguous(
            shape: [2, 3],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let d2 = BASTensorDescriptor.contiguous(
            shape: [2, 3],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        XCTAssertEqual(d1, d2)
    }
}
