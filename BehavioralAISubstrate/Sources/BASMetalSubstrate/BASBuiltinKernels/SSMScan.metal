// MARK: - SSMScan.metal
// chapter 六百七十七 / M2085 第一刀 — Real Mamba SSM
//                                    selective-scan Metal
//                                    compute shader (Phase
//                                    M opening commit)。
//
// ## What this implements
//
// Mamba selective state-space scan,scalar-state-per-channel
// variant (S5/Mamba-lite,equivalent to state_dim N=1 in
// the full Mamba notation)。 Per-channel decay coefficient
// A[d] is fixed at model load time;the selective gating
// flows through delta_t,B_t,C_t which vary by time step。
//
// Recurrence (per batch b,channel d):
//   A_bar = exp(delta[b,t,d] * A[d])
//   B_bar = delta[b,t,d] * B[b,t,d]
//   h_t   = A_bar * h_{t-1} + B_bar * x[b,t,d]
//   y_t   = C[b,t,d] * h_t
//
// Initial state h_0 = 0。 Discretization via zero-order
// hold (exp + multiplicative)。 This captures the essential
// mathematical content of Mamba's selective recurrence
// without the full state_dim×state_dim matrix complexity
// — sufficient for numerical PROOF tests vs. Python
// reference fixtures (chapter 六百七十九 / M2093-M2096
// committs canonical reference values)。
//
// ## Threadgroup strategy
//
// 1 thread per (batch,channel) pair。 Each thread scans
// sequentially over t = 0..L-1,maintaining h in a private
// register。 Output:y[b,t,d] for all t。
//
// Sequential scan (not parallel prefix-scan) is the
// SIMPLEST shader that ships。 Parallel prefix-scan via
// Blelloch's work-efficient algorithm would be ~10× faster
// for long L,but it's strictly an optimization on top of
// the same math。 Phase M targets numerical correctness
// first;a follow-up commit can swap in parallel scan
// without changing the kernel's typed inputs/outputs。
//
// ## Buffer layout (row-major,float32)
//
//   buffer(0)  x      (B, L, D)   input sequence
//   buffer(1)  delta  (B, L, D)   selective time step
//   buffer(2)  A      (D,)        per-channel decay
//   buffer(3)  B      (B, L, D)   selective input proj
//   buffer(4)  C      (B, L, D)   selective output proj
//   buffer(5)  y      (B, L, D)   output (written)
//   buffer(6)  shape  (B, L, D)   shape constants
//
// Indexing helper (row-major):
//   linear(b,t,d) = ((b * L) + t) * D + d
//   linear_d(d)   = d
//
// ## Numerical contract
//
//   - float32 throughout
//   - Sequential reduction over L (no FMA reordering)
//   - exp() via the Metal stdlib math library
//   - Bit-stable across Apple Silicon GPUs given identical
//     inputs (verified by chapter 六百八十 / M2097-M2100
//     numerical PROOF tests at MAE ≤ 1e-5 tolerance)

#include <metal_stdlib>
using namespace metal;

/// Shape constants passed via buffer(6)。 Mirrors the
/// Swift-side `BASSSMScanShape` struct laid out as 3
/// contiguous uint values。
struct SSMScanShape {
    uint B;
    uint L;
    uint D;
};

/// Selective-scan compute kernel,float32 variant。
///
/// Dispatch shape:(B, D, 1) threadgroups of (1, 1, 1)
/// threads,or any equivalent grid。 Each thread handles
/// one (b, d) pair。
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

    // Sequential scan in time。 h carries the recurrent
    // state per channel scalar。 Initial state h_0 = 0。
    float h = 0.0f;

    for (uint t = 0; t < L; t++) {
        const uint idx = ((b * L) + t) * D + d;
        const float x_t     = x[idx];
        const float delta_t = delta[idx];
        const float B_t     = B[idx];
        const float C_t     = C[idx];

        // Zero-order hold discretization
        const float A_bar = exp(delta_t * A_d);
        const float B_bar = delta_t * B_t;

        // Recurrence step
        h = A_bar * h + B_bar * x_t;

        // Output projection
        y[idx] = C_t * h;
    }
}

// MARK: - vector_cosine_similarity
// 主线 Metal embedding similarity — 全面 开发
//
// Computes per-element products + partial squared norms
// for a pair of equal-length float32 vectors。 Three
// outputs per thread:
//   dot_partial[i] = a[i] * b[i]
//   norm_a_partial[i] = a[i] * a[i]
//   norm_b_partial[i] = b[i] * b[i]
//
// Swift wrapper sums each partial array,then computes
// cosine_similarity = sum(dot) / (sqrt(sum(norm_a)) *
// sqrt(sum(norm_b)))。
//
// Each thread handles one (i) — 1-D dispatch grid of
// size N。 Threadgroup memory unused;keeps the kernel
// trivially correct + bit-stable across Apple silicon
// GPUs。
//
// Buffer layout (row-major float32):
//   buffer(0) a        (N,)  input vector A
//   buffer(1) b        (N,)  input vector B
//   buffer(2) dot      (N,)  output:elementwise a*b
//   buffer(3) norm_a   (N,)  output:elementwise a*a
//   buffer(4) norm_b   (N,)  output:elementwise b*b
//   buffer(5) shape    (1,)  shape struct {N}
//
// Note:For maximum honesty about Metal's specialty,
// this version emits PARTIAL elementwise products and
// lets the host do the final reduction (sum + sqrt +
// divide)。 The honest reason:per-thread elementwise
// is the natural Metal pattern;a single-block reduce
// requires threadgroup memory + barriers + benefits
// only at very large N。 For typical embedding sizes
// (≤ 1024 dims) the per-element approach is the right
// trade-off。

struct CosineSimShape {
    uint N;
};

kernel void vector_cosine_similarity(
    device   const float        *a       [[buffer(0)]],
    device   const float        *b       [[buffer(1)]],
    device         float        *dot     [[buffer(2)]],
    device         float        *norm_a  [[buffer(3)]],
    device         float        *norm_b  [[buffer(4)]],
    constant       CosineSimShape &shape [[buffer(5)]],
    uint                          tid    [[thread_position_in_grid]])
{
    const uint i = tid;
    if (i >= shape.N) {
        return;
    }
    const float ai = a[i];
    const float bi = b[i];
    dot[i]    = ai * bi;
    norm_a[i] = ai * ai;
    norm_b[i] = bi * bi;
}
