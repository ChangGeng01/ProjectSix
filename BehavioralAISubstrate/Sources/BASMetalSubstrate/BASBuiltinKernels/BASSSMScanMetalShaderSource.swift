// MARK: - BASSSMScanMetalShaderSource
// chapter 六百七十七 / M2086 第二刀 — Swift-side mirror
//                                    of SSMScan.metal MSL
//                                    source as a String
//                                    constant for runtime
//                                    compilation via
//                                    MTLDevice.makeLibrary
//                                    (source:options:)
//
// ## Why this exists
//
// Swift Package Manager does not auto-compile .metal files
// into .metallib binaries (that requires an Xcode build
// step via xcrun metal + xcrun metallib)。 To ship the
// chapter 六百七十七 / M2085 real Metal compute shader
// inside an SPM package,we mirror the .metal source as a
// Swift String constant + compile it at runtime via the
// runtime Metal library compiler。
//
// SSMScan.metal remains the CANONICAL human-readable
// reference + the file Xcode opens with syntax
// highlighting + the source-of-truth for future Xcode-
// build integration (when the substrate moves to an
// Xcode-built target)。 This Swift mirror is what
// actually runs at test/production time。
//
// ## Anti-drift discipline
//
// Anti-drift PROOF tests at BASSSMScanMetalShaderSource
// AntiDriftTests (M2086 第二刀,sibling test file) verify:
//   1. The Swift `float32SourceMSL` constant is non-empty
//      and well-formed MSL (kernel signature + buffer
//      bindings present)
//   2. The kernel function name matches what the runtime
//      will look up via `library.makeFunction(name:)`
//   3. The MSL string contains the recurrence math the
//      doctrine claims (exp + A_bar + B_bar variable
//      names + the recurrence step)
//
// Tighter "byte-equal source string vs. .metal file
// content" check is deferred — SPM cannot ship .metal as
// a Bundle resource without target opt-in。 The current
// PROOF level (well-formed MSL + kernel name + math
// markers) is sufficient for chapter 677 ship。

import Foundation

/// Canonical Swift-side mirror of `SSMScan.metal` MSL
/// source code。 Compiled at runtime via
/// `MTLDevice.makeLibrary(source: float32SourceMSL,
/// options: nil)` to produce a `MTLFunction` for kernel
/// dispatch。
///
/// Mirrors the chapter 六百七十七 / M2085 第一刀 .metal
/// file exactly — any future edit to either side must
/// land in BOTH commits + bump the M-number。
public enum BASSSMScanMetalShaderSource {

    /// Name of the MSL kernel function。 Used by
    /// `MTLLibrary.makeFunction(name:)` at runtime to
    /// look up the compiled function。
    public static let float32KernelName: String =
        "ssm_scan_float32"

    /// MSL kernel source code for the float32 variant of
    /// the selective state-space scan。 Compiled at
    /// runtime to populate the `MTLLibrary`。
    public static let float32SourceMSL: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct SSMScanShape {
        uint B;
        uint L;
        uint D;
    };

    kernel void ssm_scan_float32(
        device   const float        *x      [[buffer(0)]],
        device   const float        *delta  [[buffer(1)]],
        device   const float        *A      [[buffer(2)]],
        device   const float        *B      [[buffer(3)]],
        device   const float        *C      [[buffer(4)]],
        device         float        *y      [[buffer(5)]],
        constant       SSMScanShape &shape  [[buffer(6)]],
        uint2                        tid    [[thread_position_in_grid]])
    {
        const uint b = tid.x;
        const uint d = tid.y;

        if (b >= shape.B || d >= shape.D) {
            return;
        }

        const uint L = shape.L;
        const uint D = shape.D;
        const float A_d = A[d];

        float h = 0.0f;

        for (uint t = 0; t < L; t++) {
            const uint idx = ((b * L) + t) * D + d;
            const float x_t     = x[idx];
            const float delta_t = delta[idx];
            const float B_t     = B[idx];
            const float C_t     = C[idx];

            const float A_bar = exp(delta_t * A_d);
            const float B_bar = delta_t * B_t;

            h = A_bar * h + B_bar * x_t;

            y[idx] = C_t * h;
        }
    }
    """

    /// MSL source line count (used by anti-drift PROOF
    /// tests to detect accidental truncation)。
    public static var float32SourceLineCount: Int {
        return float32SourceMSL
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }

    /// Reference to the .metal file path (relative to
    /// the BASMetalSubstrate module)。 Used by
    /// documentation tools + future Xcode-build
    /// integration to locate the canonical file。
    public static let canonicalMetalFilePath: String =
        "Sources/BASMetalSubstrate/BASBuiltinKernels/SSMScan.metal"

    /// Math marker strings the MSL source MUST contain
    /// (used by anti-drift PROOF tests to assert the
    /// recurrence math is present + correct)。
    public static let requiredMSLMarkers: [String] = [
        "kernel void ssm_scan_float32",
        "buffer(0)", "buffer(1)", "buffer(2)",
        "buffer(3)", "buffer(4)", "buffer(5)",
        "buffer(6)",
        "struct SSMScanShape",
        "float A_bar = exp(delta_t * A_d)",
        "float B_bar = delta_t * B_t",
        "h = A_bar * h + B_bar * x_t",
        "y[idx] = C_t * h"
    ]

    /// Returns true iff every required MSL marker
    /// appears in `float32SourceMSL`。 Anti-drift PROOF
    /// tests assert this to ensure no part of the
    /// recurrence math is silently dropped。
    public static var allRequiredMarkersPresent: Bool {
        return requiredMSLMarkers.allSatisfy {
            float32SourceMSL.contains($0)
        }
    }
}
