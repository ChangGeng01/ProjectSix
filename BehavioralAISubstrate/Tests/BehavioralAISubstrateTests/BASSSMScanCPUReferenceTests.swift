// MARK: - BASSSMScanCPUReferenceTests
// chapter 六百七十八 / M2090 第二刀 — PROOF tests for the
//                                    pure-Swift CPU reference
//                                    implementation of the
//                                    SSM scan kernel。
//
// These tests prove the CPU reference produces the
// mathematically expected output for trivial fixtures。
// Cross-validation between CPU + GPU lands at chapter
// 六百八十 / M2097-M2100。

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanCPUReferenceTests: XCTestCase {

    typealias Ref = BASSSMScanCPUReference

    // MARK: - Zero-delta ⇒ zero output

    /// delta=0 ⇒ A_bar=1, B_bar=0 ⇒ h stays 0 ⇒ y=0。
    func testZeroDeltaProducesZeroOutput() throws {
        let shape = BASSSMScanShape(B: 2, L: 5, D: 3)
        let n = shape.elementCount

        let y = try Ref.scan(
            x: [Float](repeating: 1.0, count: n),
            delta: [Float](repeating: 0.0, count: n),
            A: [Float](repeating: -1.0, count: 3),
            B: [Float](repeating: 1.0, count: n),
            C: [Float](repeating: 1.0, count: n),
            shape: shape)

        XCTAssertEqual(y.count, n)
        for v in y {
            XCTAssertEqual(v, 0.0, accuracy: 1e-6)
        }
    }

    // MARK: - Single time step

    /// L=1, A=0, delta=1, B=C=1, x=2.5。 Expected:
    ///   A_bar = exp(0) = 1
    ///   B_bar = 1 * 1 = 1
    ///   h_0 = 1*0 + 1*2.5 = 2.5
    ///   y_0 = 1 * 2.5 = 2.5
    func testSingleStepIdentityScan() throws {
        let shape = BASSSMScanShape(B: 1, L: 1, D: 1)
        let y = try Ref.scan(
            x: [2.5],
            delta: [1.0],
            A: [0.0],
            B: [1.0],
            C: [1.0],
            shape: shape)
        XCTAssertEqual(y.count, 1)
        XCTAssertEqual(y[0], 2.5, accuracy: 1e-5)
    }

    // MARK: - Two time steps with decay

    /// L=2, A=-1, delta=1, B=1, C=1, x=[1, 0]。 Expected:
    ///   t=0: A_bar=exp(-1), B_bar=1
    ///        h_0 = exp(-1)*0 + 1*1 = 1
    ///        y_0 = 1 * 1 = 1
    ///   t=1: A_bar=exp(-1), B_bar=1
    ///        h_1 = exp(-1)*1 + 1*0 = exp(-1) ≈ 0.3679
    ///        y_1 = 1 * exp(-1) ≈ 0.3679
    func testTwoStepDecay() throws {
        let shape = BASSSMScanShape(B: 1, L: 2, D: 1)
        let y = try Ref.scan(
            x: [1.0, 0.0],
            delta: [1.0, 1.0],
            A: [-1.0],
            B: [1.0, 1.0],
            C: [1.0, 1.0],
            shape: shape)
        XCTAssertEqual(y.count, 2)
        XCTAssertEqual(y[0], 1.0, accuracy: 1e-5)
        XCTAssertEqual(
            y[1], expf(-1.0), accuracy: 1e-5)
    }

    // MARK: - Three time steps with C multiplier

    /// L=3, A=0, delta=1, B=1, C=[2,2,2], x=[1,1,1]。
    /// Each step:A_bar=1, B_bar=1
    ///   h_0 = 1
    ///   h_1 = 1*1 + 1*1 = 2
    ///   h_2 = 1*2 + 1*1 = 3
    /// y = 2*h:[2, 4, 6]
    func testThreeStepAccumulationWithCMultiplier() throws {
        let shape = BASSSMScanShape(B: 1, L: 3, D: 1)
        let y = try Ref.scan(
            x: [1.0, 1.0, 1.0],
            delta: [1.0, 1.0, 1.0],
            A: [0.0],
            B: [1.0, 1.0, 1.0],
            C: [2.0, 2.0, 2.0],
            shape: shape)
        XCTAssertEqual(y.count, 3)
        XCTAssertEqual(y[0], 2.0, accuracy: 1e-5)
        XCTAssertEqual(y[1], 4.0, accuracy: 1e-5)
        XCTAssertEqual(y[2], 6.0, accuracy: 1e-5)
    }

    // MARK: - Batched independence

    /// Two batches with different inputs must produce
    /// independent outputs (no cross-batch contamination)。
    func testBatchedIndependence() throws {
        let shape = BASSSMScanShape(B: 2, L: 1, D: 1)
        let y = try Ref.scan(
            x: [1.0, 7.0],      // batch 0: x=1, batch 1: x=7
            delta: [1.0, 1.0],
            A: [0.0],
            B: [1.0, 1.0],
            C: [1.0, 1.0],
            shape: shape)
        XCTAssertEqual(y.count, 2)
        XCTAssertEqual(y[0], 1.0, accuracy: 1e-5)
        XCTAssertEqual(y[1], 7.0, accuracy: 1e-5)
    }

    // MARK: - Channel independence

    /// Two channels with different A coefficients
    /// produce independent outputs。
    func testChannelIndependence() throws {
        let shape = BASSSMScanShape(B: 1, L: 1, D: 2)
        let y = try Ref.scan(
            x: [1.0, 1.0],
            delta: [1.0, 1.0],
            A: [0.0, -1.0],      // channel 0: A=0, channel 1: A=-1
            B: [1.0, 1.0],
            C: [1.0, 1.0],
            shape: shape)
        XCTAssertEqual(y.count, 2)
        // Both channels produce same y on L=1 (initial h=0
        // means A doesn't affect h_0)
        XCTAssertEqual(y[0], 1.0, accuracy: 1e-5)
        XCTAssertEqual(y[1], 1.0, accuracy: 1e-5)
    }

    // MARK: - Data overload round-trip

    func testDataOverloadReturnsConsistentBytes() throws {
        let shape = BASSSMScanShape(B: 1, L: 2, D: 1)
        let xArr: [Float] = [1.0, 1.0]
        let dArr: [Float] = [1.0, 1.0]
        let aArr: [Float] = [0.0]
        let bArr: [Float] = [1.0, 1.0]
        let cArr: [Float] = [1.0, 1.0]

        let yArr = try Ref.scan(
            x: xArr, delta: dArr, A: aArr, B: bArr, C: cArr,
            shape: shape)

        let xData = floatsToData(xArr)
        let dData = floatsToData(dArr)
        let aData = floatsToData(aArr)
        let bData = floatsToData(bArr)
        let cData = floatsToData(cArr)

        let yData = try Ref.scan(
            xData: xData,
            deltaData: dData,
            aData: aData,
            bData: bData,
            cData: cData,
            shape: shape)

        let yFromData = dataToFloats(yData)
        XCTAssertEqual(yFromData.count, yArr.count)
        for i in 0..<yArr.count {
            XCTAssertEqual(
                yFromData[i], yArr[i], accuracy: 1e-6)
        }
    }

    // MARK: - Validation errors

    func testThrowsOnXLengthMismatch() {
        let shape = BASSSMScanShape(B: 1, L: 3, D: 1)
        XCTAssertThrowsError(try Ref.scan(
            x: [1.0, 2.0],          // length=2,expected 3
            delta: [1.0, 1.0, 1.0],
            A: [0.0],
            B: [1.0, 1.0, 1.0],
            C: [1.0, 1.0, 1.0],
            shape: shape))
    }

    func testThrowsOnALengthMismatch() {
        let shape = BASSSMScanShape(B: 1, L: 1, D: 3)
        XCTAssertThrowsError(try Ref.scan(
            x: [1.0, 1.0, 1.0],
            delta: [1.0, 1.0, 1.0],
            A: [0.0, 0.0],          // length=2,expected 3
            B: [1.0, 1.0, 1.0],
            C: [1.0, 1.0, 1.0],
            shape: shape))
    }

    func testErrorCarriesDetails() {
        let shape = BASSSMScanShape(B: 1, L: 3, D: 1)
        do {
            _ = try Ref.scan(
                x: [1.0, 2.0],          // wrong
                delta: [1.0, 1.0, 1.0],
                A: [0.0],
                B: [1.0, 1.0, 1.0],
                C: [1.0, 1.0, 1.0],
                shape: shape)
            XCTFail("expected throw")
        } catch let BASSSMScanCPUReferenceError
            .payloadCountMismatch(name, expected, actual)
        {
            XCTAssertEqual(name, "x")
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 2)
        } catch {
            XCTFail("wrong error:\(error)")
        }
    }

    // MARK: - Determinism

    /// Same inputs ⇒ bit-stable byte-equal output across
    /// repeated calls。
    func testDeterminismAcrossRepeatedCalls() throws {
        let shape = BASSSMScanShape(B: 2, L: 7, D: 5)
        let n = shape.elementCount
        let x = (0..<n).map { Float($0) * 0.01 }
        let delta = (0..<n).map { Float($0) * 0.001 }
        let A = (0..<5).map { -Float($0 + 1) * 0.1 }
        let B = (0..<n).map { Float($0) * 0.02 }
        let C = (0..<n).map { Float($0) * 0.03 }

        let y1 = try Ref.scan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        let y2 = try Ref.scan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        XCTAssertEqual(y1, y2,
            "byte-equal repeat output required")
    }

    // MARK: - Helpers

    private func floatsToData(_ floats: [Float]) -> Data {
        return floats.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }

    private func dataToFloats(_ data: Data) -> [Float] {
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [Float] in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr[0..<count])
        }
    }
}
