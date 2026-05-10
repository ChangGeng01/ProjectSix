// MARK: - BASBuiltinKernelsTests — chapter 四百三十一 / M1099

import XCTest
@testable import BASMetalSubstrate

final class BASBuiltinKernelsTests: XCTestCase {

    // MARK: - BASMatMulKernel

    func testMatMulKey() {
        let kernel = BASMatMulKernel()
        XCTAssertEqual(kernel.key.operation, .matMul)
        XCTAssertEqual(kernel.key.dataType, .float32)
        XCTAssertEqual(kernel.key.backingKind, .cpuBytes)
    }

    /// 2x2 · 2x2 sanity:
    ///   A = [[1, 2], [3, 4]]
    ///   B = [[5, 6], [7, 8]]
    ///   C = [[19, 22], [43, 50]]
    func testMatMul2x2() async throws {
        let A: [Float] = [1, 2, 3, 4]
        let B: [Float] = [5, 6, 7, 8]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                A.toFloat32Data(),
                B.toFloat32Data()
            ])
        let outputs = try await BASMatMulKernel()
            .evaluate(inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [2, 2])
        let cFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 4)
        XCTAssertEqual(cFloats, [19, 22, 43, 50])
    }

    /// 3x2 · 2x4 → 3x4 rectangular sanity check
    func testMatMul3x2By2x4() async throws {
        let A: [Float] = [1, 2,
                          3, 4,
                          5, 6]
        let B: [Float] = [7, 8, 9, 10,
                          11, 12, 13, 14]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [3, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2, 4],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                A.toFloat32Data(),
                B.toFloat32Data()
            ])
        let outputs = try await BASMatMulKernel()
            .evaluate(inputs: inputs)
        XCTAssertEqual(
            outputs.descriptors[0].shape, [3, 4])
        let cFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 12)
        // Row 0: [29, 32, 35, 38]
        XCTAssertEqual(cFloats[0], 29)
        XCTAssertEqual(cFloats[1], 32)
        XCTAssertEqual(cFloats[2], 35)
        XCTAssertEqual(cFloats[3], 38)
        // Row 2:
        //   C[2][0] = 5*7  + 6*11 = 35 + 66 = 101
        //   C[2][3] = 5*10 + 6*14 = 50 + 84 = 134
        XCTAssertEqual(cFloats[8], 101)
        XCTAssertEqual(cFloats[11], 134)
    }

    func testMatMulRejectsRankMismatch() async {
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [4],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [4],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag)
            ],
            payloads: [
                Data(count: 16),
                Data(count: 16)
            ])
        do {
            _ = try await BASMatMulKernel()
                .evaluate(inputs: inputs)
            XCTFail("expected throw")
        } catch let err as BASKernelError {
            switch err {
            case .shapeMismatch: break
            default:
                XCTFail("expected shapeMismatch, got \(err)")
            }
        } catch {
            XCTFail("expected BASKernelError")
        }
    }

    func testMatMulRejectsDtypeMismatch() async {
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .int32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .int32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                Data(count: 16),
                Data(count: 16)
            ])
        do {
            _ = try await BASMatMulKernel()
                .evaluate(inputs: inputs)
            XCTFail("expected throw")
        } catch let err as BASKernelError {
            switch err {
            case .dataTypeMismatch: break
            default:
                XCTFail("expected dataTypeMismatch")
            }
        } catch {
            XCTFail("expected BASKernelError")
        }
    }

    // MARK: - BASRMSNormKernel

    func testRMSNormKey() {
        let kernel = BASRMSNormKernel()
        XCTAssertEqual(kernel.key.operation, .rmsNorm)
        XCTAssertEqual(kernel.key.dataType, .float32)
        XCTAssertEqual(kernel.key.backingKind, .cpuBytes)
    }

    /// Basic RMS sanity: x = [3, 4], weight = [1, 1] →
    /// rms = sqrt((9 + 16) / 2) = sqrt(12.5) ≈ 3.5355
    /// y[0] = 3 / 3.5355 ≈ 0.8485
    /// y[1] = 4 / 3.5355 ≈ 1.1314
    func testRMSNormBasic() async throws {
        let x: [Float] = [3, 4]
        let weight: [Float] = [1, 1]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag)
            ],
            payloads: [
                x.toFloat32Data(),
                weight.toFloat32Data()
            ])
        let outputs = try await BASRMSNormKernel(
            epsilon: 0).evaluate(inputs: inputs)
        let yFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 2)
        XCTAssertEqual(
            yFloats[0], 3 / Float(12.5).squareRoot(),
            accuracy: 1e-5)
        XCTAssertEqual(
            yFloats[1], 4 / Float(12.5).squareRoot(),
            accuracy: 1e-5)
    }

    func testRMSNormAppliesWeight() async throws {
        let x: [Float] = [3, 4]
        let weight: [Float] = [2, 0.5]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag)
            ],
            payloads: [
                x.toFloat32Data(),
                weight.toFloat32Data()
            ])
        let outputs = try await BASRMSNormKernel(
            epsilon: 0).evaluate(inputs: inputs)
        let yFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 2)
        let rms = Float(12.5).squareRoot()
        XCTAssertEqual(
            yFloats[0], (3 / rms) * 2, accuracy: 1e-5)
        XCTAssertEqual(
            yFloats[1], (4 / rms) * 0.5, accuracy: 1e-5)
    }

    func testRMSNormRejectsAxisMismatch() async {
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 4],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [3],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _1D.rankTag)
            ],
            payloads: [
                Data(count: 16),
                Data(count: 12)
            ])
        do {
            _ = try await BASRMSNormKernel()
                .evaluate(inputs: inputs)
            XCTFail("expected throw")
        } catch let err as BASKernelError {
            switch err {
            case .shapeMismatch: break
            default: XCTFail("expected shapeMismatch")
            }
        } catch {
            XCTFail("expected BASKernelError")
        }
    }

    // MARK: - BASRotaryEmbeddingKernel

    func testRotaryEmbeddingKey() {
        let kernel = BASRotaryEmbeddingKernel()
        XCTAssertEqual(
            kernel.key.operation, .rotaryEmbedding)
        XCTAssertEqual(kernel.key.dataType, .float32)
        XCTAssertEqual(kernel.key.backingKind, .cpuBytes)
    }

    /// Rotation by 0:cos = 1, sin = 0 →
    /// y[2i]   = x[2i]   * 1 - x[2i+1] * 0 = x[2i]
    /// y[2i+1] = x[2i]   * 0 + x[2i+1] * 1 = x[2i+1]
    /// (identity rotation)
    func testRotaryEmbeddingZeroIsIdentity() async throws {
        let x: [Float] = [1, 2, 3, 4]  // 1 token, headDim=4
        let cos: [Float] = [1, 1]      // halfDim=2
        let sin: [Float] = [0, 0]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 4],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                x.toFloat32Data(),
                cos.toFloat32Data(),
                sin.toFloat32Data()
            ])
        let outputs = try await BASRotaryEmbeddingKernel()
            .evaluate(inputs: inputs)
        let yFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 4)
        XCTAssertEqual(yFloats, x)
    }

    /// 90-degree rotation:cos=0, sin=1 →
    /// y[2i]   = x[2i]   * 0 - x[2i+1] * 1 = -x[2i+1]
    /// y[2i+1] = x[2i]   * 1 + x[2i+1] * 0 =  x[2i]
    func testRotaryEmbedding90Degrees() async throws {
        let x: [Float] = [1, 2]  // 1 token, headDim=2
        let cos: [Float] = [0]
        let sin: [Float] = [1]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 1],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 1],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                x.toFloat32Data(),
                cos.toFloat32Data(),
                sin.toFloat32Data()
            ])
        let outputs = try await BASRotaryEmbeddingKernel()
            .evaluate(inputs: inputs)
        let yFloats = outputs.payloads[0]
            .toFloat32Array(elementCount: 2)
        XCTAssertEqual(yFloats[0], -2)
        XCTAssertEqual(yFloats[1], 1)
    }

    func testRotaryRejectsOddHeadDim() async {
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [1, 3],  // odd headDim
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 1],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [1, 1],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                Data(count: 12),
                Data(count: 4),
                Data(count: 4)
            ])
        do {
            _ = try await BASRotaryEmbeddingKernel()
                .evaluate(inputs: inputs)
            XCTFail("expected throw")
        } catch let err as BASKernelError {
            switch err {
            case .shapeMismatch: break
            default: XCTFail("expected shapeMismatch")
            }
        } catch {
            XCTFail("expected BASKernelError")
        }
    }

    // MARK: - End-to-end via registry

    func testThreeKernelsRegisterAndDispatchEndToEnd()
        async throws
    {
        let registry = BASMetalKernelRegistry()
        await registry.register(BASMatMulKernel())
        await registry.register(BASRMSNormKernel())
        await registry.register(BASRotaryEmbeddingKernel())
        let count = await registry.kernelCount
        XCTAssertEqual(count, 3,
            "all 3 reference kernels register")

        // Dispatch matMul end-to-end through the registry
        let result = try await registry.dispatch(
            key: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .cpuBytes),
            inputs: BASKernelInputs(
                descriptors: [
                    BASTensorDescriptor.contiguous(
                        shape: [2, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag),
                    BASTensorDescriptor.contiguous(
                        shape: [2, 2],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: _2D.rankTag)
                ],
                payloads: [
                    [Float(1), 2, 3, 4].toFloat32Data(),
                    [Float(5), 6, 7, 8].toFloat32Data()
                ]))
        XCTAssertEqual(result.routedKey.operation, .matMul)
        let outFloats = result.outputs.payloads[0]
            .toFloat32Array(elementCount: 4)
        XCTAssertEqual(outFloats, [19, 22, 43, 50])
    }

    // MARK: - Replay determinism

    func testMatMulIsBitExact() async throws {
        let A: [Float] = [0.1, 0.2, 0.3, 0.4]
        let B: [Float] = [0.5, 0.6, 0.7, 0.8]
        let inputs = BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [2, 2],
                    dataType: .float32,
                    backingKind: .cpuBytes,
                    rankTag: _2D.rankTag)
            ],
            payloads: [
                A.toFloat32Data(),
                B.toFloat32Data()
            ])
        let r1 = try await BASMatMulKernel()
            .evaluate(inputs: inputs)
        let r2 = try await BASMatMulKernel()
            .evaluate(inputs: inputs)
        XCTAssertEqual(r1.payloads, r2.payloads,
            "scalar IEEE matmul must be bit-exact across" +
            " calls (chapter 三百九二)")
    }
}

// MARK: - Local Float32 ↔ Data helpers

/// Tests need the same Float32 ↔ Data helpers the kernels
/// use。 The kernel module makes these `internal extension`s
/// of `Data` + `[Float]`,so the test target picks them up
/// via @testable import BASMetalSubstrate。
