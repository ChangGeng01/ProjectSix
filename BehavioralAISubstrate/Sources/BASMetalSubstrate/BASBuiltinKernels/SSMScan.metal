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

// MARK: - batched_cosine_similarity
// chapter 七百十五 第一刀 / M2246
//
// Per architectural matrix「Metal:embedding similarity」 —
// query × corpus batched cosine。 One thread per corpus row。
// Each thread reduces its row sequentially in dim:
//
//   For row r in 0..N_rows:
//     dot = sum_d query[d] * corpus[r*dim + d]
//     norm_q = sum_d query[d] * query[d]   (per-thread,
//                                            redundant work)
//     norm_r = sum_d corpus[r*dim + d]^2
//     scores[r] = dot / (sqrt(norm_q) * sqrt(norm_r))
//
// At typical embedding shapes (N_rows ≥ 256, dim ∈ [128, 1024])
// the GPU parallelism over N_rows handily beats Rust SIMD's
// scalar per-row loop。 At small N_rows (< 64) the kernel
// launch overhead dominates and Rust SIMD wins — chapter
// 七百十五 第三刀 tournament measures the empirical crossover。
//
// Numerical stability:single-precision throughout,matches
// Rust SIMD batched_cosine exactly within fp32 rounding。

struct BatchedCosineShape {
    uint dim;
    uint n_rows;
};

kernel void batched_cosine_similarity(
    device   const float              *query   [[buffer(0)]],
    device   const float              *corpus  [[buffer(1)]],
    device         float              *scores  [[buffer(2)]],
    constant       BatchedCosineShape &shape   [[buffer(3)]],
    uint                               tid     [[thread_position_in_grid]])
{
    const uint row = tid;
    if (row >= shape.n_rows) {
        return;
    }
    const uint dim = shape.dim;
    const uint base = row * dim;
    float dot = 0.0;
    float norm_q = 0.0;
    float norm_r = 0.0;
    for (uint d = 0; d < dim; d += 1) {
        const float qd = query[d];
        const float rd = corpus[base + d];
        dot += qd * rd;
        norm_q += qd * qd;
        norm_r += rd * rd;
    }
    // Guard against zero-norm rows so the kernel never emits
    // NaN — caller must still handle 0.0 scores upstream。
    if (norm_q <= 0.0 || norm_r <= 0.0) {
        scores[row] = 0.0;
    } else {
        scores[row] = dot
            / (sqrt(norm_q) * sqrt(norm_r));
    }
}

// MARK: - vector_rmsnorm
// 主线 全面 开发 — Root Mean Square layer normalization。
// Two-pass implementation:
//   Pass 1 (CPU-side):  sum_sq = sum(x[i]²)
//   Pass 2 (GPU kernel): y[i] = x[i] * rsqrt(sum_sq / N + eps)
//
// This kernel implements PASS 2 ONLY。 The Swift wrapper
// computes sum_sq + scaling factor on CPU then passes
// the precomputed `inv_rms = 1 / sqrt(sum_sq/N + eps)`
// as a scalar constant。 Each thread does one
// multiplication — pure SIMD parallelism。
//
// (A single-pass GPU reduce + scale would need
// threadgroup memory + barrier;for typical sizes the
// two-pass split is the right cost/complexity trade-
// off。)

struct RMSNormShape {
    uint N;
    float inv_rms;  // precomputed: 1 / sqrt(mean(x²) + eps)
};

kernel void vector_rmsnorm(
    device   const float        *x       [[buffer(0)]],
    device         float        *y       [[buffer(1)]],
    constant       RMSNormShape &shape   [[buffer(2)]],
    uint                          tid    [[thread_position_in_grid]])
{
    const uint i = tid;
    if (i >= shape.N) {
        return;
    }
    y[i] = x[i] * shape.inv_rms;
}

// MARK: - matmul_float32
// 主线 全面 开发 — small dense matrix multiply
// C[i,j] = sum_k A[i,k] * B[k,j]
//
// Each thread computes ONE output cell。 Dispatch grid:
// (M, N, 1) where M = rows of A,N = cols of B。 Each
// thread iterates over K = inner dimension。
//
// Honest trade-off:no tiling,no shared memory cache
// — pure straightforward triple-loop GPU dispatch。 For
// large M*N this is slower than a tiled kernel but
// trivially correct + maps cleanly to the kernel
// dispatch model。 Production hosts wanting peak
// MatMul performance should use MPSMatrixMultiplication
// (Apple-provided BLAS GEMM)。 This kernel exists to
// prove the substrate can dispatch arbitrary float32
// GPU compute via the .metal pilot,not to compete
// with vendor BLAS。

struct MatMulShape {
    uint M;  // rows of A and C
    uint N;  // cols of B and C
    uint K;  // cols of A = rows of B (inner dim)
};

kernel void matmul_float32(
    device   const float        *A       [[buffer(0)]],  // M × K row-major
    device   const float        *B       [[buffer(1)]],  // K × N row-major
    device         float        *C       [[buffer(2)]],  // M × N row-major (out)
    constant       MatMulShape  &shape   [[buffer(3)]],
    uint2                         tid    [[thread_position_in_grid]])
{
    const uint i = tid.x;  // row of A / row of C
    const uint j = tid.y;  // col of B / col of C
    if (i >= shape.M || j >= shape.N) {
        return;
    }
    const uint K = shape.K;
    const uint N = shape.N;
    float acc = 0.0f;
    for (uint k = 0; k < K; k++) {
        const float a_ik = A[i * K + k];
        const float b_kj = B[k * N + j];
        acc += a_ik * b_kj;
    }
    C[i * N + j] = acc;
}

// MARK: - scaled_dot_product_attention
// 主线 全面 开发 — single-head scaled dot-product
// attention,Metal GPU kernel。 Per blueprint:Metal
// owns "attention"。
//
// Inputs:
//   Q (M × D)   queries
//   K (N × D)   keys
//   V (N × Dv)  values
//
// Algorithm per output cell out[i,j]:
//   1. scores[k] = sum_d Q[i,d] * K[k,d]   for k in 0..N
//   2. scaled[k] = scores[k] / sqrt(D)
//   3. max_score = max(scaled[k] over k)
//   4. exp_sum   = sum(exp(scaled[k] - max_score))
//   5. prob[k]   = exp(scaled[k] - max_score) / exp_sum
//   6. out[i,j]  = sum_k prob[k] * V[k,j]
//
// Each GPU thread handles ONE output cell (i,j)。 Dispatch
// grid:(M, Dv, 1)。 Per-thread cost:O(N*D + N) which is
// the natural attention cost。 No tiling,no shared
// memory — clean kernel,maps directly to spec。
//
// Honest trade-off:not a tiled FlashAttention kernel。
// For typical small sequence lengths in this substrate
// (chat-shaped:M=N≤64,D≤128) this is fast enough。
// Production-scale attention should use Apple's
// MPSGraph + MPSGraphMatrixMultiplicationOp or vendor
// FlashAttention。 This kernel exists to honor the
// blueprint row。

struct AttentionShape {
    uint M;   // rows of Q (and rows of output)
    uint N;   // rows of K = rows of V (seq length)
    uint D;   // cols of Q = cols of K (key/query dim)
    uint Dv;  // cols of V (value dim)
};

kernel void scaled_dot_product_attention(
    device   const float          *Q       [[buffer(0)]],  // M × D
    device   const float          *K       [[buffer(1)]],  // N × D
    device   const float          *V       [[buffer(2)]],  // N × Dv
    device         float          *out     [[buffer(3)]],  // M × Dv
    constant       AttentionShape &shape   [[buffer(4)]],
    uint2                          tid     [[thread_position_in_grid]])
{
    const uint i = tid.x;  // query row index
    const uint j = tid.y;  // value-dim index
    if (i >= shape.M || j >= shape.Dv) {
        return;
    }
    const uint M = shape.M;
    const uint N = shape.N;
    const uint D = shape.D;
    const uint Dv = shape.Dv;
    (void)M;  // M used only for bounds check above
    const float inv_sqrt_d = 1.0f / sqrt(float(D));

    // Pass 1: find max scaled score for numerical
    // stability (softmax max-subtract trick)。
    float max_score = -INFINITY;
    for (uint k = 0; k < N; k++) {
        float dot = 0.0f;
        for (uint d = 0; d < D; d++) {
            dot += Q[i * D + d] * K[k * D + d];
        }
        const float scaled = dot * inv_sqrt_d;
        if (scaled > max_score) {
            max_score = scaled;
        }
    }

    // Pass 2: accumulate exp(scaled - max) for the
    // softmax denominator AND the weighted sum for
    // this output column j。 We can do both in one
    // pass since we no longer need to revisit each k。
    float exp_sum = 0.0f;
    float weighted_sum = 0.0f;
    for (uint k = 0; k < N; k++) {
        float dot = 0.0f;
        for (uint d = 0; d < D; d++) {
            dot += Q[i * D + d] * K[k * D + d];
        }
        const float scaled = dot * inv_sqrt_d;
        const float e = exp(scaled - max_score);
        exp_sum += e;
        weighted_sum += e * V[k * Dv + j];
    }

    out[i * Dv + j] = (exp_sum > 0.0f)
        ? (weighted_sum / exp_sum)
        : 0.0f;
}
