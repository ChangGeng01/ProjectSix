// MARK: - BASTensorShapeTests — chapter 四百三十一 / M1096

import XCTest
@testable import BASMetalSubstrate

final class BASTensorShapeTests: XCTestCase {

    // MARK: - Rank values

    func testRank0Is0() {
        XCTAssertEqual(_0D.rank, 0)
    }

    func testRank1Is1() {
        XCTAssertEqual(_1D.rank, 1)
    }

    func testRank2Is2() {
        XCTAssertEqual(_2D.rank, 2)
    }

    func testRank3Is3() {
        XCTAssertEqual(_3D.rank, 3)
    }

    func testRank4Is4() {
        XCTAssertEqual(_4D.rank, 4)
    }

    func testNDimRankIsMinus1() {
        XCTAssertEqual(_NDim.rank, -1)
    }

    // MARK: - Rank tags byte-stable for replay

    func testRankTagsAreStable() {
        XCTAssertEqual(_0D.rankTag, "rank-0")
        XCTAssertEqual(_1D.rankTag, "rank-1")
        XCTAssertEqual(_2D.rankTag, "rank-2")
        XCTAssertEqual(_3D.rankTag, "rank-3")
        XCTAssertEqual(_4D.rankTag, "rank-4")
        XCTAssertEqual(_NDim.rankTag, "rank-dynamic")
    }

    // MARK: - Scalar evidence

    func testFloat32Scalar() {
        XCTAssertEqual(Float.dataType, .float32)
        XCTAssertEqual(Float.byteWidth, 4)
    }

    func testInt32Scalar() {
        XCTAssertEqual(Int32.dataType, .int32)
        XCTAssertEqual(Int32.byteWidth, 4)
    }

    func testUInt8Scalar() {
        XCTAssertEqual(UInt8.dataType, .uint8)
        XCTAssertEqual(UInt8.byteWidth, 1)
    }

    func testBoolScalar() {
        XCTAssertEqual(Bool.dataType, .bool)
        XCTAssertEqual(Bool.byteWidth, 1)
    }

    #if arch(arm64)
    func testFloat16ScalarOnARM64() {
        XCTAssertEqual(Float16.dataType, .float16)
        XCTAssertEqual(Float16.byteWidth, 2)
    }
    #endif

    // MARK: - DataType enum

    func testDataTypeRawValuesByteStable() {
        XCTAssertEqual(
            BASTensorDataType.float16.rawValue, "float16")
        XCTAssertEqual(
            BASTensorDataType.float32.rawValue, "float32")
        XCTAssertEqual(
            BASTensorDataType.int32.rawValue, "int32")
        XCTAssertEqual(
            BASTensorDataType.uint8.rawValue, "uint8")
        XCTAssertEqual(
            BASTensorDataType.bool.rawValue, "bool")
    }

    func testDataTypeByteWidthMatchesScalar() {
        XCTAssertEqual(
            BASTensorDataType.float16.byteWidth, 2)
        XCTAssertEqual(
            BASTensorDataType.float32.byteWidth,
            Float.byteWidth)
        XCTAssertEqual(
            BASTensorDataType.int32.byteWidth,
            Int32.byteWidth)
        XCTAssertEqual(
            BASTensorDataType.uint8.byteWidth,
            UInt8.byteWidth)
        XCTAssertEqual(
            BASTensorDataType.bool.byteWidth,
            Bool.byteWidth)
    }

    func testDataTypeAllCasesIs5() {
        XCTAssertEqual(
            BASTensorDataType.allCases.count, 5,
            "5 dtypes shipped at M1096:" +
            " float16/float32/int32/uint8/bool")
    }

    // MARK: - Codable round-trip (chapter 三百九二)

    func testDataTypeCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for dtype in BASTensorDataType.allCases {
            let encoded = try encoder.encode(dtype)
            let decoded = try JSONDecoder()
                .decode(
                    BASTensorDataType.self, from: encoded)
            XCTAssertEqual(decoded, dtype)
        }
    }
}
