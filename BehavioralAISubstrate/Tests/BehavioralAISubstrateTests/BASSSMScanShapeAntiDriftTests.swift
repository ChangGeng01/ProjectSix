// MARK: - BASSSMScanShapeAntiDriftTests
// chapter 六百七十七 / M2087 第三刀 — anti-drift PROOF tests
//                                    for the typed Swift
//                                    shape struct mirror
//                                    of MSL SSMScanShape

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanShapeAntiDriftTests: XCTestCase {
    typealias S = BASSSMScanShape

    // MARK: - Memory layout invariants (CRITICAL for MSL upload)

    func testStructSizeIsExactlyTwelveBytes() {
        // 3 UInt32 fields × 4 bytes = 12 bytes。 Any
        // padding would silently corrupt buffer(6) reads
        // in the MSL kernel。
        XCTAssertEqual(
            MemoryLayout<S>.size, 12,
            "BASSSMScanShape MUST be exactly 12 bytes " +
            "to match MSL SSMScanShape layout — any " +
            "padding/alignment surprise will corrupt " +
            "buffer(6) reads in the SSMScan kernel")
    }

    func testStructStrideIsExactlyTwelveBytes() {
        XCTAssertEqual(MemoryLayout<S>.stride, 12)
    }

    func testStructAlignmentIsFourBytes() {
        XCTAssertEqual(MemoryLayout<S>.alignment, 4)
    }

    // MARK: - Field-type pins (must be UInt32 to match MSL `uint`)

    func testFieldBIsUInt32() {
        let shape = S(B: 7, L: 11, D: 13)
        XCTAssertTrue(type(of: shape.B) == UInt32.self)
    }

    func testFieldLIsUInt32() {
        let shape = S(B: 7, L: 11, D: 13)
        XCTAssertTrue(type(of: shape.L) == UInt32.self)
    }

    func testFieldDIsUInt32() {
        let shape = S(B: 7, L: 11, D: 13)
        XCTAssertTrue(type(of: shape.D) == UInt32.self)
    }

    // MARK: - Constructor + validation

    func testCanConstructWithPositiveDimensions() {
        let shape = S(B: 2, L: 4, D: 8)
        XCTAssertEqual(shape.B, 2)
        XCTAssertEqual(shape.L, 4)
        XCTAssertEqual(shape.D, 8)
    }

    func testValidatedFactorySucceedsOnPositive() throws {
        let shape = try S.validated(B: 1, L: 1, D: 1)
        XCTAssertEqual(shape.B, 1)
        XCTAssertEqual(shape.L, 1)
        XCTAssertEqual(shape.D, 1)
    }

    func testValidatedFactoryThrowsOnZeroB() {
        XCTAssertThrowsError(
            try S.validated(B: 0, L: 2, D: 3))
    }

    func testValidatedFactoryThrowsOnZeroL() {
        XCTAssertThrowsError(
            try S.validated(B: 2, L: 0, D: 3))
    }

    func testValidatedFactoryThrowsOnZeroD() {
        XCTAssertThrowsError(
            try S.validated(B: 2, L: 3, D: 0))
    }

    func testValidatedFactoryErrorCarriesDimensions() {
        do {
            _ = try S.validated(B: 0, L: 5, D: 7)
            XCTFail("expected throw")
        } catch let error as BASSSMScanShapeError {
            XCTAssertEqual(
                error,
                .zeroDimension(B: 0, L: 5, D: 7))
        } catch {
            XCTFail("wrong error type")
        }
    }

    // MARK: - Derived metrics

    func testElementCountIsProduct() {
        let shape = S(B: 2, L: 3, D: 5)
        XCTAssertEqual(shape.elementCount, 30)
    }

    func testBytesPerElementIsFour() {
        // Float32 = 4 bytes per element。 If this ever
        // changes (e.g. float16 variant lands),the
        // payloadByteCount math must update。
        XCTAssertEqual(S.bytesPerElement, 4)
    }

    func testPayloadByteCountIsCorrect() {
        // (B=2, L=3, D=5) × 4 bytes = 120 bytes
        let shape = S(B: 2, L: 3, D: 5)
        XCTAssertEqual(shape.payloadByteCount, 120)
    }

    func testABufferByteCountIsCorrect() {
        // D=5 × 4 bytes = 20 bytes
        let shape = S(B: 2, L: 3, D: 5)
        XCTAssertEqual(shape.aBufferByteCount, 20)
    }

    // MARK: - Linear index helper (matches MSL ((b*L)+t)*D+d)

    func testLinearIndexAtOrigin() {
        let shape = S(B: 2, L: 3, D: 5)
        XCTAssertEqual(
            shape.linearIndex(b: 0, t: 0, d: 0), 0)
    }

    func testLinearIndexAtLastElement() {
        // (B=2, L=3, D=5) last element at (1, 2, 4) →
        // ((1 * 3) + 2) * 5 + 4 = 29
        let shape = S(B: 2, L: 3, D: 5)
        XCTAssertEqual(
            shape.linearIndex(b: 1, t: 2, d: 4), 29)
        // Total elements = 30,so max index = 29 = 30-1
        XCTAssertEqual(
            shape.linearIndex(b: 1, t: 2, d: 4),
            shape.elementCount - 1)
    }

    func testLinearIndexFormulaMatchesMSLRowMajor() {
        let shape = S(B: 3, L: 7, D: 11)
        for b in 0..<Int(shape.B) {
            for t in 0..<Int(shape.L) {
                for d in 0..<Int(shape.D) {
                    let swift = shape.linearIndex(
                        b: b, t: t, d: d)
                    // MSL formula: ((b * L) + t) * D + d
                    let msl = ((b * Int(shape.L)) + t) *
                        Int(shape.D) + d
                    XCTAssertEqual(swift, msl)
                }
            }
        }
    }

    // MARK: - Equatable / Hashable / Codable

    func testEquality() {
        let a = S(B: 1, L: 2, D: 3)
        let b = S(B: 1, L: 2, D: 3)
        XCTAssertEqual(a, b)
    }

    func testInequalityOnDifferentB() {
        let a = S(B: 1, L: 2, D: 3)
        let b = S(B: 2, L: 2, D: 3)
        XCTAssertNotEqual(a, b)
    }

    func testHashableConsistentWithEquality() {
        let a = S(B: 5, L: 10, D: 20)
        let b = S(B: 5, L: 10, D: 20)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testCodableRoundTrip() throws {
        let original = S(B: 7, L: 13, D: 19)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            S.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Error type Codable

    func testErrorCodableRoundTrip() throws {
        let error: BASSSMScanShapeError =
            .zeroDimension(B: 0, L: 5, D: 7)
        let data = try JSONEncoder().encode(error)
        let decoded = try JSONDecoder().decode(
            BASSSMScanShapeError.self, from: data)
        XCTAssertEqual(error, decoded)
    }
}
