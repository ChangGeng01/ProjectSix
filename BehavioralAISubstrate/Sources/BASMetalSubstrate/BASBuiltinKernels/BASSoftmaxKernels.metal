// SPDX:internal
//
// BASSoftmaxKernels.metal — chapter 七百三 第五刀 / M2175
//
// Softmax + log-softmax + masked variants in MSL。 Three styles:
//
//   - naive_softmax            — direct exp / sum (numerically
//                                 risky for large logits)
//   - softmax_max_subtracted   — exp(x - max(x)) / sum;the
//                                 standard numerically-stable
//                                 form used by attention etc。
//   - softmax_masked           — applies an additive boolean
//                                 mask before max-subtract
//                                 (positions where mask=1 set
//                                  the logit to -INF)
//   - log_softmax              — log of softmax, computed
//                                 stably as logits - max -
//                                 log(sum(exp(logits - max)))
//
// Each kernel operates row-wise over an (N, D) row-major
// float32 buffer。 Dispatch:gridSize = (1, N, 1)。

#include <metal_stdlib>
using namespace metal;

// MARK: - naive_softmax

kernel void naive_softmax(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        sum += exp(x[row * D + d]);
    }
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] = exp(x[row * D + d]) / sum;
    }
}

// MARK: - softmax_max_subtracted

kernel void softmax_max_subtracted(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    constant     uint  &D   [[buffer(2)]],
    uint                row [[threadgroup_position_in_grid]])
{
    // Pass 1: find max
    float m = -INFINITY;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        if (v > m) { m = v; }
    }
    // Pass 2: exp-sum and write numerators
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        float v = exp(x[row * D + d] - m);
        out[row * D + d] = v;
        sum += v;
    }
    // Pass 3: normalize
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] /= sum;
    }
}

// MARK: - softmax_masked
//
// mask[i] != 0 means "this position is masked" — its logit
// becomes -INF before max-subtract。 Useful for attention where
// some positions are excluded (e.g。 causal mask)。

kernel void softmax_masked(
    device const float *x    [[buffer(0)]],
    device const uchar *mask [[buffer(1)]],
    device       float *out  [[buffer(2)]],
    constant     uint  &D    [[buffer(3)]],
    uint                row  [[threadgroup_position_in_grid]])
{
    float m = -INFINITY;
    for (uint d = 0; d < D; ++d) {
        if (mask[row * D + d] != 0) { continue; }
        float v = x[row * D + d];
        if (v > m) { m = v; }
    }
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        if (mask[row * D + d] != 0) {
            out[row * D + d] = 0.0;
            continue;
        }
        float v = exp(x[row * D + d] - m);
        out[row * D + d] = v;
        sum += v;
    }
    if (sum > 0.0) {
        for (uint d = 0; d < D; ++d) {
            out[row * D + d] /= sum;
        }
    }
}

// MARK: - log_softmax

kernel void log_softmax(
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
    float sum_exp = 0.0;
    for (uint d = 0; d < D; ++d) {
        sum_exp += exp(x[row * D + d] - m);
    }
    float log_sum = m + log(sum_exp);
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] = x[row * D + d] - log_sum;
    }
}

// MARK: - softmax_temperature
//
// Same as max-subtracted softmax but with a temperature factor:
//   y_i = exp((x_i - max(x)) / T) / Σⱼ exp((x_j - max(x)) / T)
//
// Used by sampling paths that need to widen / sharpen the
// distribution。 T → 0 collapses toward arg-max; T → ∞ flattens
// toward uniform。

kernel void softmax_temperature(
    device const float *x          [[buffer(0)]],
    device       float *out        [[buffer(1)]],
    constant     uint  &D          [[buffer(2)]],
    constant     float &temperature [[buffer(3)]],
    uint                row        [[threadgroup_position_in_grid]])
{
    float m = -INFINITY;
    for (uint d = 0; d < D; ++d) {
        float v = x[row * D + d];
        if (v > m) { m = v; }
    }
    float inv_T = 1.0 / temperature;
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        float v = exp((x[row * D + d] - m) * inv_T);
        out[row * D + d] = v;
        sum += v;
    }
    for (uint d = 0; d < D; ++d) {
        out[row * D + d] /= sum;
    }
}

// MARK: - softmax_backward
//
// Given upstream gradient dy and the softmax output y, compute
// dx using the formula:
//   dx_i = y_i * (dy_i - Σⱼ y_j * dy_j)

kernel void softmax_backward(
    device const float *y   [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    constant     uint  &D   [[buffer(3)]],
    uint                row [[threadgroup_position_in_grid]])
{
    float sum = 0.0;
    for (uint d = 0; d < D; ++d) {
        sum += y[row * D + d] * dy[row * D + d];
    }
    for (uint d = 0; d < D; ++d) {
        dx[row * D + d] =
            y[row * D + d] * (dy[row * D + d] - sum);
    }
}
