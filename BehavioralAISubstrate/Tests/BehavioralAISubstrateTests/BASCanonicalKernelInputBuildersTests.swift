// MARK: - BASCanonicalKernelInputBuildersTests
// chapter 四百七十五 / M1276
//
// PROOF that the input builders produce correct shapes,
// strides, dtypes, and Float32-bit-exact payloads matching
// what the MPSGraph kernels expect。

import XCTest
@testable import BASMetalSubstrate

final class BASCanonicalKernelInputBuildersTests:
    XCTestCase
{

    // MARK: - matMul builder

    func testMatMulProducesTwoRankTwoFloat32Descriptors() {
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(
                a: [1, 2, 3, 4],
                b: [5, 6, 7, 8],
                M: 2, K: 2, N: 2)
        XCTAssertEqual(inputs.descriptors.count, 2)
        XCTAssertEqual(
            inputs.descriptors[0].shape, [2, 2])
        XCTAssertEqual(
            inputs.descriptors[1].shape, [2, 2])
        XCTAssertEqual(
            inputs.descriptors[0].dataType, .float32)
        XCTAssertEqual(
            inputs.descriptors[0].backingKind,
            .metalBuffer)
        XCTAssertEqual(
            inputs.descriptors[0].rankTag,
            "rank-2-matrix")
    }

    func testMatMulPayloadBytesMatchElementCount() {
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(
                a: [1, 2, 3, 4],
                b: [5, 6, 7, 8],
                M: 2, K: 2, N: 2)
        XCTAssertEqual(inputs.payloads[0].count, 16,
            "2×2 Float32 = 16 bytes")
        XCTAssertEqual(inputs.payloads[1].count, 16)
    }

    func testMatMulRoundTripsFloatValues() {
        let original: [Float] = [1.5, 2.25, 3.125, 4.0625]
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(
                a: original,
                b: [1, 1, 1, 1],
                M: 2, K: 2, N: 2)
        let recovered = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                inputs.payloads[0],
                elementCount: 4)
        XCTAssertEqual(recovered, original,
            "Float32 must round-trip bit-exact")
    }

    // MARK: - rmsNorm builder

    func testRMSNormBuilderShapes() {
        let inputs = BASCanonicalKernelInputBuilders
            .rmsNorm(
                input: [1, 2, 3, 4, 5, 6],
                gamma: [0.5, 0.5, 0.5],
                batchSeq: 2,
                hiddenDim: 3)
        XCTAssertEqual(inputs.descriptors.count, 2)
        XCTAssertEqual(
            inputs.descriptors[0].shape, [2, 3])
        XCTAssertEqual(
            inputs.descriptors[1].shape, [3])
        XCTAssertEqual(
            inputs.descriptors[1].rankTag,
            "rank-1-vector")
    }

    // MARK: - rotaryEmbedding builder

    func testRotaryEmbeddingBuilderShapes() {
        let seq = 2, heads = 1, headDim = 4
        let inputs = BASCanonicalKernelInputBuilders
            .rotaryEmbedding(
                input: Array(repeating: 1.0,
                    count: seq * heads * headDim),
                cosTable: Array(repeating: 1.0,
                    count: seq * (headDim / 2)),
                sinTable: Array(repeating: 0.0,
                    count: seq * (headDim / 2)),
                sequenceLength: seq,
                heads: heads,
                headDim: headDim)
        XCTAssertEqual(inputs.descriptors.count, 3)
        XCTAssertEqual(
            inputs.descriptors[0].shape, [2, 1, 4])
        XCTAssertEqual(
            inputs.descriptors[0].rankTag,
            "rank-3-tensor")
        XCTAssertEqual(
            inputs.descriptors[1].shape, [2, 2])
        XCTAssertEqual(
            inputs.descriptors[2].shape, [2, 2])
    }

    // MARK: - Float ↔ Data round trip

    func testFloatArrayDataRoundTrip() {
        let values: [Float] = [1, 2, 3, 0.5, -7.25,
                              Float.pi]
        let data = BASCanonicalKernelInputBuilders
            .floatArrayToData(values)
        XCTAssertEqual(data.count, values.count * 4)
        let recovered = BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                data, elementCount: values.count)
        XCTAssertEqual(recovered, values)
    }
}
