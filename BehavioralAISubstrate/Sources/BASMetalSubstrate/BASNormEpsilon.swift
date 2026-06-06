// MARK: - BASNormEpsilon — single source-of-truth for
// normalization-kernel numerical-stability epsilons。
//
// RMSNorm and LayerNorm use DIFFERENT epsilon conventions:
//
//   - RMSNorm  → 1e-6  (Gemma 3 / Llama 3 / Qwen 2 / Mamba
//                       transformer-block default)
//   - LayerNorm → 1e-5 (PyTorch / TensorFlow default)
//
// These two values differ by an order of magnitude and were
// previously hard-coded as bare literals across the CPU
// reference kernel, the MPSGraph GPU kernels, and the
// linear-algebra dispatcher — three+ sites for each value,
// trivially cross-wired。 Routing every epsilon literal
// through this enum makes the convention explicit and removes
// the magic-number drift surface (chapter 一百八十五
// anti-magic-number;chapter 二百一一 single-source-of-truth)。
//
// The stored values are IDENTICAL to the literals they
// replace — this is a byte-equal dedup, not a numeric change。
public enum BASNormEpsilon {

    /// RMSNorm numerical-stability epsilon added inside the
    /// sqrt。 1e-6 matches Gemma 3 / Llama 3 / Qwen 2 / Mamba
    /// transformer-block defaults。
    public static let rmsNorm: Float = 1e-6

    /// LayerNorm numerical-stability epsilon added to the
    /// variance before the sqrt。 1e-5 matches PyTorch /
    /// TensorFlow defaults。
    public static let layerNorm: Float = 1e-5
}
