// MARK: - BASRMSNormKernel — chapter 四百三十一 / M1099
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E close-out entry。 Second
// reference kernel:CPU-only Float32 RMS normalization。
//
// ## Why this exists (system entropy framing)
//
// Modern transformer blocks (Gemma 3,Llama 3,Qwen 2) use
// RMSNorm instead of LayerNorm — no mean centering,only
// RMS scaling。 The substrate kernel registry needs a
// reference implementation under
// `(rmsNorm, float32, cpuBytes)` so:
//   1. The dispatch contract is proven for normalization
//      kernels (1 input + 1 weight tensor → 1 output)
//   2. Future MPSGraph / MLX / CoreML rmsNorm kernels can
//      register under the same key + replace the CPU
//      reference at hot-path
//
// ## What this ships (M1099)
//
//   - `BASRMSNormKernel` conforming to `BASMetalKernel`
//     - `key = (rmsNorm, float32, cpuBytes)`
//     - 2 inputs:`x: (batch × hidden)` + `weight:
//       (hidden)` — both Float32 cpuBytes
//     - 1 output:`y: (batch × hidden)` — Float32 cpuBytes
//     - Formula:`y[b, h] = (x[b, h] / rms_b) * weight[h]`
//       where `rms_b = sqrt(mean(x[b, :]^2) + eps)`
//     - `eps` is a public stored property (default 1e-6,
//       matching Gemma / Llama defaults)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (eps is a
//     typed init param,not a hard-coded literal in the
//     compute loop)
//   - chapter 二百一一 — single source-of-truth (one
//     rms-norm kernel)
//   - chapter 三百九二 — replay-determinism (scalar IEEE
//     arithmetic + sequential reduction)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — hint-only

import Foundation

/// CPU-only Float32 RMS normalization reference kernel。
/// Registered under `(rmsNorm, float32, cpuBytes)`。
public struct BASRMSNormKernel: BASMetalKernel {

    public let key: BASKernelKey = BASKernelKey(
        operation: .rmsNorm,
        dataType: .float32,
        backingKind: .cpuBytes)

    /// Numerical-stability epsilon added inside the
    /// sqrt。 Default 1e-6 matches Gemma 3 / Llama 3
    /// transformer blocks。
    public let epsilon: Float

    public init(epsilon: Float = BASNormEpsilon.rmsNorm) {
        self.epsilon = epsilon
    }

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        guard inputs.descriptors.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects 2 inputs " +
                "(x, weight);got " +
                "\(inputs.descriptors.count)")
        }
        let descX = inputs.descriptors[0]
        let descW = inputs.descriptors[1]
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        guard descX.shape.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects rank-2 x;" +
                " got rank \(descX.shape.count)")
        }
        guard descW.shape.count == 1 else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm expects rank-1 weight;" +
                " got rank \(descW.shape.count)")
        }
        let batch = descX.shape[0]
        let hidden = descX.shape[1]
        guard descW.shape[0] == hidden else {
            throw BASKernelError.shapeMismatch(
                reason: "rmsNorm weight axis " +
                "(\(descW.shape[0])) must equal x hidden " +
                "axis (\(hidden))")
        }

        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        let xFloats = inputs.payloads[0]
            .toFloat32Array(elementCount: batch * hidden)
        let wFloats = inputs.payloads[1]
            .toFloat32Array(elementCount: hidden)
        var yFloats: [Float] = Array(
            repeating: 0, count: batch * hidden)

        for b in 0..<batch {
            // Compute mean of squares for this batch row
            var sumSquares: Float = 0
            for h in 0..<hidden {
                let v = xFloats[b * hidden + h]
                sumSquares += v * v
            }
            let meanSquares = sumSquares / Float(hidden)
            let rms = (meanSquares + epsilon)
                .squareRoot()
            // Apply normalization + per-feature weight
            for h in 0..<hidden {
                let v = xFloats[b * hidden + h]
                yFloats[b * hidden + h] =
                    (v / rms) * wFloats[h]
            }
        }

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        let outDesc = BASTensorDescriptor.contiguous(
            shape: [batch, hidden],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [yFloats.toFloat32Data()],
            executionNanos: elapsed)
    }
}
