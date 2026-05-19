// SPDX:internal
//
// BASLayerNormKernel.metal — chapter 七百三 第五刀 / M2175
//
// Forward + backward LayerNorm in Metal Shading Language。
// Replaces the BASMPSGraphLayerNormKernel.swift MPSGraph-backed
// path with direct MTLComputePipelineState kernels that hosts
// can dispatch without the MPSGraph overhead。
//
// ## Kernel surface
//
//   - `layer_norm_forward`           — naive forward over (N, D)
//   - `layer_norm_forward_stable`    — Welford accumulator
//                                       (numerically stable for
//                                        large D)
//   - `layer_norm_backward`          — gradient w.r.t input
//   - `layer_norm_affine_forward`    — γ * normalized + β
//   - `layer_norm_affine_backward`   — gradient incl。 γ, β
//
// All kernels operate row-by-row;each threadgroup handles one
// row of the (N, D) input tensor。 Caller dispatches with
// gridSize = MTLSize(width: 1, height: N, depth: 1) and
// threadgroupSize sized to D (clamped to maxTotalThreadsPerThreadgroup)。

#include <metal_stdlib>
using namespace metal;

// MARK: - layer_norm_forward (naive, no affine)
//
// Computes y = (x - mean(x)) / sqrt(var(x) + eps) row-wise。
// `x` and `out` are (N, D) row-major float32 arrays。 `eps` is
// a small constant to avoid div-by-zero。
kernel void layer_norm_forward(
    device const float *x      [[buffer(0)]],
    device       float *out    [[buffer(1)]],
    constant     uint  &D      [[buffer(2)]],
    constant     float &eps    [[buffer(3)]],
    uint                row    [[threadgroup_position_in_grid]])
{
    // Pass 1: compute mean
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        sum += x[row * D + d];
    }
    float mean = sum / float(D);

    // Pass 2: compute variance
    float var_acc = 0.0;
    for (uint d = 0; d < D; ++d) {
        float diff = x[row * D + d] - mean;
        var_acc += diff * diff;
    }
    float variance = var_acc / float(D);
    float inv_std = rsqrt(variance + eps);

    // Pass 3: write normalized
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] =
            (x[row * D + d] - mean) * inv_std;
    }
}

// MARK: - layer_norm_forward_stable (Welford)
//
// Welford's online algorithm — single pass over D, numerically
// stable for large D where the naive sum-of-squares accumulator
// loses precision。
kernel void layer_norm_forward_stable(
    device const float *x      [[buffer(0)]],
    device       float *out    [[buffer(1)]],
    constant     uint  &D      [[buffer(2)]],
    constant     float &eps    [[buffer(3)]],
    uint                row    [[threadgroup_position_in_grid]])
{
    float mean = 0.0;
    float m2   = 0.0;
    for (uint d = 0; d < D; ++d) {
        float xv    = x[row * D + d];
        float delta = xv - mean;
        mean       += delta / float(d + 1);
        float delta2 = xv - mean;
        m2         += delta * delta2;
    }
    float variance = m2 / float(D);
    float inv_std = rsqrt(variance + eps);
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] =
            (x[row * D + d] - mean) * inv_std;
    }
}

// MARK: - layer_norm_affine_forward
//
// y = γ * (x - mean) / sqrt(var + eps) + β
//
// γ, β are per-dimension parameters of length D shared across
// all rows。
kernel void layer_norm_affine_forward(
    device const float *x      [[buffer(0)]],
    device const float *gamma  [[buffer(1)]],
    device const float *beta   [[buffer(2)]],
    device       float *out    [[buffer(3)]],
    constant     uint  &D      [[buffer(4)]],
    constant     float &eps    [[buffer(5)]],
    uint                row    [[threadgroup_position_in_grid]])
{
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        sum += x[row * D + d];
    }
    float mean = sum / float(D);
    float var_acc = 0.0;
    for (uint d = 0; d < D; ++d) {
        float diff = x[row * D + d] - mean;
        var_acc += diff * diff;
    }
    float variance = var_acc / float(D);
    float inv_std = rsqrt(variance + eps);
    for (uint d = 0; d < D; ++d) {
        float normalized =
            (x[row * D + d] - mean) * inv_std;
        out[row * D + d] =
            gamma[d] * normalized + beta[d];
    }
}

// MARK: - layer_norm_backward
//
// Given upstream gradient dy and the original input x + mean +
// inv_std saved from the forward pass, compute dx:
//
//   dx = (1/D) * inv_std * (
//          D * dy - sum(dy) - normalized * sum(dy * normalized))
//
// Saves mean + inv_std externally so the backward kernel
// doesn't recompute them (host-side workspace allocator owns
// these auxiliaries)。
kernel void layer_norm_backward(
    device const float *x       [[buffer(0)]],
    device const float *dy      [[buffer(1)]],
    device const float *mean    [[buffer(2)]],
    device const float *inv_std [[buffer(3)]],
    device       float *dx      [[buffer(4)]],
    constant     uint  &D       [[buffer(5)]],
    uint                row     [[threadgroup_position_in_grid]])
{
    float row_mean    = mean[row];
    float row_invstd  = inv_std[row];

    float sum_dy = 0.0;
    float sum_dy_norm = 0.0;
    for (uint d = 0; d < D; ++d) {
        float normalized =
            (x[row * D + d] - row_mean) * row_invstd;
        sum_dy      += dy[row * D + d];
        sum_dy_norm += dy[row * D + d] * normalized;
    }
    float scale = 1.0 / float(D);
    for (uint d = 0; d < D; ++d) {
        float normalized =
            (x[row * D + d] - row_mean) * row_invstd;
        dx[row * D + d] = scale * row_invstd * (
            float(D) * dy[row * D + d]
            - sum_dy
            - normalized * sum_dy_norm);
    }
}

// MARK: - layer_norm_affine_backward
//
// Computes dx + dγ + dβ for the affine LayerNorm。
//
//   dβ_d = Σ_n dy_{n,d}
//   dγ_d = Σ_n dy_{n,d} * normalized_{n,d}
//   dx   = γ-scaled version of the plain dx formula
kernel void layer_norm_affine_backward(
    device const float *x         [[buffer(0)]],
    device const float *dy        [[buffer(1)]],
    device const float *gamma     [[buffer(2)]],
    device const float *mean      [[buffer(3)]],
    device const float *inv_std   [[buffer(4)]],
    device       float *dx        [[buffer(5)]],
    device       float *dgamma    [[buffer(6)]],
    device       float *dbeta     [[buffer(7)]],
    constant     uint  &D         [[buffer(8)]],
    uint                row       [[threadgroup_position_in_grid]])
{
    float row_mean   = mean[row];
    float row_invstd = inv_std[row];
    float sum_dy_g     = 0.0;
    float sum_dy_g_norm = 0.0;
    // Accumulate per-row scaled sums。
    for (uint d = 0; d < D; ++d) {
        float normalized =
            (x[row * D + d] - row_mean) * row_invstd;
        float dy_v = dy[row * D + d];
        float dy_scaled = dy_v * gamma[d];
        sum_dy_g      += dy_scaled;
        sum_dy_g_norm += dy_scaled * normalized;
    }
    float scale = 1.0 / float(D);
    for (uint d = 0; d < D; ++d) {
        float normalized =
            (x[row * D + d] - row_mean) * row_invstd;
        float dy_v = dy[row * D + d];
        float dy_scaled = dy_v * gamma[d];
        dx[row * D + d] = scale * row_invstd * (
            float(D) * dy_scaled
            - sum_dy_g
            - normalized * sum_dy_g_norm);
        // Atomic-free dγ / dβ accumulation:caller writes one
        // (row, d) at a time;a reduction pass elsewhere finalizes。
        // Here we just write the per-row contribution to the
        // workspace buffer。
        dgamma[row * D + d] = dy_v * normalized;
        dbeta[row * D + d]  = dy_v;
    }
}

// MARK: - Notes on dispatch shape
//
// Threadgroup-per-row keeps each row's mean/var accumulation
// strictly local — no cross-row reductions needed。 For D > the
// device's maxTotalThreadsPerThreadgroup (often 1024), a
// hierarchical reduction would split D across multiple
// threadgroups per row + a second-pass kernel to combine。
// V1 (this commit) targets D ≤ 1024 which covers the substrate's
// typical attention head + FFN hidden sizes。
