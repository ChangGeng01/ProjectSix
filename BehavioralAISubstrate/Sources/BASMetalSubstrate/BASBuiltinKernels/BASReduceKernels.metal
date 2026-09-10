// SPDX:internal
//
// BASReduceKernels.metal — chapter 七百三 第五刀 / M2175
//
// Reduce kernels — sum / max / min / mean / argmax over a
// chosen axis of a 2D tensor (N, D)。 V1: axis-1 reductions
// (per-row);per-column would mirror with transposed indexing。
//
// All kernels operate one row per threadgroup。

#include <metal_stdlib>
using namespace metal;

// MARK: - row_sum

kernel void row_sum(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float s = 0.0;
    for (uint d = 0; d < D; ++d) {
        s += x[row * D + d];
    }
    out[row] = s;
}

// MARK: - row_mean

kernel void row_mean(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float s = 0.0;
    for (uint d = 0; d < D; ++d) {
        s += x[row * D + d];
    }
    out[row] = s / float(D);
}

// MARK: - row_max

kernel void row_max(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float m = -INFINITY;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        if (v > m) { m = v; }
    }
    out[row] = m;
}

// MARK: - row_min

kernel void row_min(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float m = INFINITY;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        if (v < m) { m = v; }
    }
    out[row] = m;
}

// MARK: - row_argmax

kernel void row_argmax(
    device const float *x   [[buffer(0)]],
    device       uint  *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    uint best_idx = 0;
    float best_val = -INFINITY;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        if (v > best_val) {
            best_val = v;
            best_idx = d;
        }
    }
    out[row] = best_idx;
}

// MARK: - row_l2_norm

kernel void row_l2_norm(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float sum_sq = 0.0;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        sum_sq += v * v;
    }
    out[row] = sqrt(sum_sq);
}

// MARK: - row_normalize_l2
//
// Writes y = x / |x|_2 row-wise。 Zero-norm rows produce zeros。

kernel void row_normalize_l2(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float sum_sq = 0.0;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        sum_sq += v * v;
    }
    if (sum_sq <= 0.0) {
        for (uint d = 0; d < D; ++d) {
            out[row * D + d] = 0.0;
        }
        return;
    }
    float inv_norm = rsqrt(sum_sq);
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] = x[row * D + d] * inv_norm;
    }
}

// MARK: - pairwise_cosine
//
// Output[i, j] = cosine_similarity(A[i, :], B[j, :])
//
// Dispatch: (M, N, 1) where A is M×D and B is N×D。

kernel void pairwise_cosine(
    device const float *A   [[buffer(0)]],
    device const float *B   [[buffer(1)]],
    device       float *out [[buffer(2)]],
    constant     uint  &M   [[buffer(3)]],
    constant     uint  &N   [[buffer(4)]],
    constant     uint  &D   [[buffer(5)]],
    uint2               gid [[thread_position_in_grid]])
{
    uint i = gid.x;
    uint j = gid.y;
    if (i >= M || j >= N) { return; }
    float dot = 0.0;
    float na  = 0.0;
    float nb  = 0.0;
    for (uint d = 0; d < D; ++d) {
        float a = A[i * D + d];
        float b = B[j * D + d];
        dot += a * b;
        na  += a * a;
        nb  += b * b;
    }
    if (na == 0.0 || nb == 0.0) {
        out[i * N + j] = 0.0;
    } else {
        out[i * N + j] = dot / sqrt(na * nb);
    }
}
