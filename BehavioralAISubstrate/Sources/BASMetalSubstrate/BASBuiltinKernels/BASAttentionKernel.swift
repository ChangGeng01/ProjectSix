// MARK: - BASAttentionKernel — chapter 四百五十三 / M1189
// 系统熵 reduction
//
// **POST-SWEEP REAL EXECUTION** chapter — fourth real
// substrate kernel + CPU reference for scaled dot-
// product attention。 Sibling for chapter 453's
// MPSGraph GPU implementation under same key family。
//
// ## What this ships (M1189 — CPU baseline)
//
//   - `BASAttentionKernel` conforming to
//     `BASMetalKernel` (struct,Sendable)
//   - `key = (attention, float32, cpuBytes)`
//   - 3 inputs:
//       Q: (seqQ × dim)
//       K: (seqK × dim)
//       V: (seqK × dim)
//   - 1 output:y: (seqQ × dim)
//   - Formula:
//       scores = Q · K^T / sqrt(dim)        // (seqQ × seqK)
//       attn   = softmax(scores, axis=-1)   // row-wise softmax
//       y      = attn · V                   // (seqQ × dim)
//   - Single-head (multihead = batched single-head;
//     ship multihead variant after the single-head
//     pattern proves out)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed errors + typed key;
//     softmax scale is derived from dim (sqrt(dim))
//   - chapter 二百一一 — one attention CPU kernel under
//     typed key;GPU sibling under different backing-
//     kind key
//   - chapter 三百九二 — replay-determinism (scalar
//     IEEE arithmetic;deterministic softmax via
//     max-shift for numerical stability)
//   - ADR-014 OPT-IN — additive
//   - 红线 7 — observation/computation only

import Foundation

/// CPU-only Float32 single-head scaled dot-product
/// attention。 Registered under
/// `(attention, float32, cpuBytes)`。
public struct BASAttentionKernel: BASMetalKernel {

    public let key: BASKernelKey = BASKernelKey(
        operation: .attention,
        dataType: .float32,
        backingKind: .cpuBytes)

    public init() {}

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        guard inputs.descriptors.count == 3 else {
            throw BASKernelError.shapeMismatch(
                reason: "attention expects 3 inputs" +
                " (Q,K,V);got" +
                " \(inputs.descriptors.count)")
        }
        let descQ = inputs.descriptors[0]
        let descK = inputs.descriptors[1]
        let descV = inputs.descriptors[2]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descQ.shape.count == 2,
              descK.shape.count == 2,
              descV.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "attention expects rank-2" +
                " Q/K/V")
        }
        let seqQ = descQ.shape[0]
        let dim = descQ.shape[1]
        let seqK = descK.shape[0]
        let dimK = descK.shape[1]
        let seqV = descV.shape[0]
        let dimV = descV.shape[1]
        guard dim == dimK else {
            throw BASKernelError.shapeMismatch(
                reason: "Q.dim (\(dim)) must equal" +
                " K.dim (\(dimK))")
        }
        guard seqK == seqV else {
            throw BASKernelError.shapeMismatch(
                reason: "K.seqK (\(seqK)) must equal" +
                " V.seqV (\(seqV))")
        }
        guard dim == dimV else {
            throw BASKernelError.shapeMismatch(
                reason: "Q.dim (\(dim)) must equal" +
                " V.dim (\(dimV))" +
                " for single-head attention")
        }
        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let qFloats = inputs.payloads[0]
            .toFloat32Array(elementCount: seqQ * dim)
        let kFloats = inputs.payloads[1]
            .toFloat32Array(elementCount: seqK * dim)
        let vFloats = inputs.payloads[2]
            .toFloat32Array(elementCount: seqK * dim)

        let scale: Float = 1.0 / sqrtf(Float(dim))

        // Compute scores[i, j] = (Q[i, :] · K[j, :]) * scale
        // shape (seqQ, seqK)
        var scores: [Float] = Array(
            repeating: 0, count: seqQ * seqK)
        for i in 0..<seqQ {
            for j in 0..<seqK {
                var dot: Float = 0
                for d in 0..<dim {
                    dot += qFloats[i * dim + d]
                        * kFloats[j * dim + d]
                }
                scores[i * seqK + j] = dot * scale
            }
        }

        // Row-wise softmax with max-shift for numerical
        // stability (chapter 三百九二 replay-
        // determinism — same input → same output bytes)
        var attn: [Float] = Array(
            repeating: 0, count: seqQ * seqK)
        for i in 0..<seqQ {
            // Find row max for stability shift
            var rowMax: Float = -.infinity
            for j in 0..<seqK {
                let s = scores[i * seqK + j]
                if s > rowMax { rowMax = s }
            }
            // exp(s - max) + sum
            var rowSum: Float = 0
            for j in 0..<seqK {
                let e = expf(
                    scores[i * seqK + j] - rowMax)
                attn[i * seqK + j] = e
                rowSum += e
            }
            // Normalize
            for j in 0..<seqK {
                attn[i * seqK + j] /= rowSum
            }
        }

        // y[i, d] = sum_j(attn[i, j] * V[j, d])
        // shape (seqQ, dim)
        var y: [Float] = Array(
            repeating: 0, count: seqQ * dim)
        for i in 0..<seqQ {
            for d in 0..<dim {
                var acc: Float = 0
                for j in 0..<seqK {
                    acc += attn[i * seqK + j]
                        * vFloats[j * dim + d]
                }
                y[i * dim + d] = acc
            }
        }

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [seqQ, dim],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [y.toFloat32Data()],
            executionNanos: elapsed)
    }
}
