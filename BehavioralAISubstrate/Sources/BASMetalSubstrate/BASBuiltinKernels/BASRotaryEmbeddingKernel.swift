// MARK: - BASRotaryEmbeddingKernel — chapter 四百三十一 / M1099
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E close-out entry。 Third
// reference kernel:CPU-only Float32 rotary positional
// embedding (RoPE)。
//
// ## Why this exists (system entropy framing)
//
// Modern transformer attention (Gemma 3,Llama 3,Qwen 2)
// applies rotary positional embeddings to Q + K
// projections — pairs of features rotated by sin/cos of
// position-frequency products。 The substrate kernel
// registry needs a reference implementation under
// `(rotaryEmbedding, float32, cpuBytes)` so:
//   1. The dispatch contract is proven for embedding
//      kernels (1 input + 2 sin/cos position tables → 1
//      output)
//   2. Future MPSGraph / MLX rotary kernels can register
//      under the same key
//
// ## What this ships (M1099)
//
//   - `BASRotaryEmbeddingKernel` conforming to
//     `BASMetalKernel`
//     - `key = (rotaryEmbedding, float32, cpuBytes)`
//     - 3 inputs:
//         x: (seqLen × headDim)
//         cosTable: (seqLen × headDim/2)
//         sinTable: (seqLen × headDim/2)
//     - 1 output:y: (seqLen × headDim)
//     - Per pair `(x[2i], x[2i+1])`:
//         y[2i]   =  x[2i]   * cos[i] - x[2i+1] * sin[i]
//         y[2i+1] =  x[2i]   * sin[i] + x[2i+1] * cos[i]
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (no inline
//     constants beyond IEEE 0/1 in the rotation formula)
//   - chapter 二百一一 — single source-of-truth (one
//     rotary kernel under one key)
//   - chapter 三百九二 — replay-determinism (scalar IEEE
//     arithmetic per (i, j) pair;no parallel reduction)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — hint-only

import Foundation

/// CPU-only Float32 rotary positional embedding reference
/// kernel。 Registered under
/// `(rotaryEmbedding, float32, cpuBytes)`。
public struct BASRotaryEmbeddingKernel: BASMetalKernel {

    public let key: BASKernelKey = BASKernelKey(
        operation: .rotaryEmbedding,
        dataType: .float32,
        backingKind: .cpuBytes)

    public init() {}

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        guard inputs.descriptors.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding expects 3 " +
                "inputs (x, cos, sin);got " +
                "\(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        let descCos = inputs.descriptors[1]
        let descSin = inputs.descriptors[2]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descX.shape.count == 2,
              descCos.shape.count == 2,
              descSin.shape.count == 2
        else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding expects rank-2 " +
                "inputs;got x=\(descX.shape.count) " +
                "cos=\(descCos.shape.count) " +
                "sin=\(descSin.shape.count)")
        }
        let seqLen = descX.shape[0]
        let headDim = descX.shape[1]
        guard headDim % 2 == 0 else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding headDim must be " +
                "even;got \(headDim)")
        }
        let halfDim = headDim / 2
        guard descCos.shape == [seqLen, halfDim],
              descSin.shape == [seqLen, halfDim]
        else {
            throw BASKernelError.shapeMismatch(
                reason: "rotaryEmbedding cos/sin must be " +
                "[\(seqLen), \(halfDim)];got " +
                "cos=\(descCos.shape) " +
                "sin=\(descSin.shape)")
        }

        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let xFloats = inputs.payloads[0]
            .toFloat32Array(elementCount: seqLen * headDim)
        let cosFloats = inputs.payloads[1]
            .toFloat32Array(
                elementCount: seqLen * halfDim)
        let sinFloats = inputs.payloads[2]
            .toFloat32Array(
                elementCount: seqLen * halfDim)
        var yFloats: [Float] = Array(
            repeating: 0, count: seqLen * headDim)

        for s in 0..<seqLen {
            for i in 0..<halfDim {
                let xEven = xFloats[s * headDim + 2 * i]
                let xOdd = xFloats[s * headDim + 2 * i + 1]
                let cosIJ = cosFloats[s * halfDim + i]
                let sinIJ = sinFloats[s * halfDim + i]
                yFloats[s * headDim + 2 * i] =
                    xEven * cosIJ - xOdd * sinIJ
                yFloats[s * headDim + 2 * i + 1] =
                    xEven * sinIJ + xOdd * cosIJ
            }
        }

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [seqLen, headDim],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [yFloats.toFloat32Data()],
            executionNanos: elapsed)
    }
}
