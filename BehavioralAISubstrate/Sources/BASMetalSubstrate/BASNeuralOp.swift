// MARK: - BASNeuralOp — chapter 四百三十一 / M1097
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle entry。 Typed
// vocabulary of neural primitives that the substrate
// understands at the capability + kernel-registry level。
//
// ## Why this exists (system entropy framing)
//
// Today the substrate has zero typed vocabulary for
// "what neural operation is this kernel"。 BASMLXAdapter
// dispatches inference via untyped `MLXModel.generate(...)`
// — there's no shared language for "matrix multiply" /
// "RMSNorm" / "rotary embedding" / "SSM scan"。 Without
// this language,BASANECapability cannot describe what
// ops the device supports + the kernel registry cannot
// type-key its kernel lookup table。
//
// `BASNeuralOp` is a discriminated enum covering the
// neural ops shipped + planned across substrate kernels。
// Pinned set; new ops require an explicit doctrine entry。
//
// ## What this ships (M1097)
//
//   - `BASNeuralOp` enum (8 cases) covering matmul,
//     conv2d,attention,layerNorm,rmsNorm,softmax,
//     rotaryEmbedding,ssmScan
//   - `String` rawvalues for byte-stable Codable
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 No raw
//     `Int` op codes — typed enum throughout。
//   - chapter 二百一一 — single source-of-truth。 Capability
//     probe + kernel registry both consume this enum。
//   - chapter 三百九二 — replay-determinism。 String
//     rawvalues stable across processes。
//   - ADR-014 OPT-IN — purely additive。
//   - ADR-016 — chapter 四百三十一 v1。

import Foundation

/// Discriminated vocabulary of neural primitives that the
/// substrate understands at the capability + kernel-
/// registry level。 Pinned set — additions require an
/// explicit doctrine entry under the chapter 四百三十一
/// follow-up cycle。
public enum BASNeuralOp:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Dense matrix multiply (`A · B`)。 Most-common LLM
    /// hot-path op。 Maps to `MPSMatrixMultiplication` /
    /// `MPSGraph.matrixMultiplication` / MLX `matmul`。
    case matMul = "mat-mul"

    /// 2D convolution。 Maps to `MPSCNNConvolution` /
    /// CoreML `Conv2D` layer。 Vision-only at substrate
    /// layer (LLMs use matmul instead)。
    case conv2D = "conv-2d"

    /// Scaled dot-product attention (Q · Kᵀ → softmax →
    /// · V)。 Maps to fused `MPSGraph.scaledDotProduct`
    /// where available,decomposed otherwise。
    case attention = "attention"

    /// Standard layer normalization (mean + variance
    /// across feature axis)。 Maps to MLX `layerNorm` or
    /// MPSGraph `meanOf:` / `varianceOf:` composition。
    case layerNorm = "layer-norm"

    /// Root-mean-square normalization (no mean centering,
    /// only RMS scaling)。 Used by Gemma / Llama / Qwen
    /// transformer blocks instead of LayerNorm。 Maps to
    /// MLX `rmsNorm` or composed MPSGraph rsqrt + scale。
    case rmsNorm = "rms-norm"

    /// Numerically-stable softmax (max-subtraction +
    /// exp + normalize)。 Maps to MPSGraph `softmaxWith:`。
    case softmax = "softmax"

    /// Rotary positional embedding (per-token sin/cos
    /// rotation applied to Q + K projections)。 Used by
    /// Gemma / Llama / Qwen attention。 Composed of
    /// elementwise sin/cos/multiply on MPSGraph。
    case rotaryEmbedding = "rotary-embedding"

    /// State-space model selective scan (Mamba / SSM
    /// `s4d` step)。 Composed of cumulative-product +
    /// selective gating on MPSGraph。 Reserved for the
    /// Mamba SSM training pipeline (G8 — chapter 四百三十二
    /// future work)。
    case ssmScan = "ssm-scan"
}
