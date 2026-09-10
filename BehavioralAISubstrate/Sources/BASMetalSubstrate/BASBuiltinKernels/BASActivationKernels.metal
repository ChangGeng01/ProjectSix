// SPDX:internal
//
// BASActivationKernels.metal — chapter 七百三 第五刀 / M2175
//
// Element-wise activation functions in MSL。 Each kernel
// processes one element per thread (one-dimensional dispatch);
// inputs + outputs are flat float32 arrays of the same length。
//
// ## Kernel surface
//
//   - relu / relu_backward
//   - leaky_relu / leaky_relu_backward
//   - gelu_exact / gelu_exact_backward
//   - gelu_tanh_approx / gelu_tanh_approx_backward
//   - silu / silu_backward
//   - swish (= silu, alias)
//   - sigmoid / sigmoid_backward
//   - tanh_act / tanh_backward
//
// ## Dispatch shape
//
//   gridSize = MTLSize(width: N, height: 1, depth: 1)
//   threadgroupSize = MTLSize(width: tg, height: 1, depth: 1)
//   where N = total elements and `tg` is chosen by the host based
//   on device.maxTotalThreadsPerThreadgroup (typically 512–1024)。

#include <metal_stdlib>
using namespace metal;

constant float SQRT_2_OVER_PI = 0.7978845608028654; // sqrt(2/π)
constant float GELU_TANH_COEFF = 0.044715;          // empirical

// MSL stdlib doesn't expose erf() directly — provide a high-
// accuracy Abramowitz & Stegun 7.1.26 approximation (max error
// ~1.5e-7 over all reals)。 Used by gelu_exact below。
inline float bas_erf_approx(float x) {
    float t = 1.0f / (1.0f + 0.3275911f * fabs(x));
    float y = 1.0f - (
        ((((1.061405429f * t - 1.453152027f) * t)
            + 1.421413741f) * t - 0.284496736f) * t
        + 0.254829592f) * t * exp(-x * x);
    return x < 0.0f ? -y : y;
}

// MARK: - ReLU

kernel void relu(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    out[gid] = max(0.0f, x[gid]);
}

kernel void relu_backward(
    device const float *x      [[buffer(0)]],
    device const float *dy     [[buffer(1)]],
    device       float *dx     [[buffer(2)]],
    uint                gid    [[thread_position_in_grid]])
{
    dx[gid] = x[gid] > 0.0 ? dy[gid] : 0.0;
}

// MARK: - Leaky ReLU

kernel void leaky_relu(
    device const float *x        [[buffer(0)]],
    device       float *out      [[buffer(1)]],
    constant     float &slope    [[buffer(2)]],
    uint                gid      [[thread_position_in_grid]])
{
    float v = x[gid];
    out[gid] = v > 0.0 ? v : slope * v;
}

kernel void leaky_relu_backward(
    device const float *x      [[buffer(0)]],
    device const float *dy     [[buffer(1)]],
    device       float *dx     [[buffer(2)]],
    constant     float &slope  [[buffer(3)]],
    uint                gid    [[thread_position_in_grid]])
{
    dx[gid] = x[gid] > 0.0 ? dy[gid] : slope * dy[gid];
}

// MARK: - GELU (exact via erf)

kernel void gelu_exact(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    float v = x[gid];
    // 0.5 * x * (1 + bas_erf_approx(x / sqrt(2)))
    out[gid] = 0.5 * v * (1.0 + bas_erf_approx(v * 0.7071067811865475));
}

kernel void gelu_exact_backward(
    device const float *x   [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    uint                gid [[thread_position_in_grid]])
{
    float v = x[gid];
    // Derivative of exact GELU:
    //   GELU'(x) = Φ(x) + x * φ(x)
    // where Φ is the standard normal CDF and φ the PDF。
    float cdf =
        0.5 * (1.0 + bas_erf_approx(v * 0.7071067811865475));
    float pdf =
        0.3989422804014327 * exp(-0.5 * v * v); // 1/sqrt(2π)
    dx[gid] = dy[gid] * (cdf + v * pdf);
}

// MARK: - GELU (tanh approximation)
//
// Same formula HF + many transformer impls use:
//   0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x^3)))

kernel void gelu_tanh_approx(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    float v  = x[gid];
    float v3 = v * v * v;
    float inner = SQRT_2_OVER_PI * (v + GELU_TANH_COEFF * v3);
    out[gid] = 0.5 * v * (1.0 + tanh(inner));
}

kernel void gelu_tanh_approx_backward(
    device const float *x   [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    uint                gid [[thread_position_in_grid]])
{
    float v  = x[gid];
    float v2 = v * v;
    float v3 = v2 * v;
    float inner =
        SQRT_2_OVER_PI * (v + GELU_TANH_COEFF * v3);
    float t = tanh(inner);
    float sech2 = 1.0 - t * t;
    float d_inner =
        SQRT_2_OVER_PI *
            (1.0 + 3.0 * GELU_TANH_COEFF * v2);
    float gprime = 0.5 * (1.0 + t)
        + 0.5 * v * sech2 * d_inner;
    dx[gid] = dy[gid] * gprime;
}

// MARK: - SiLU / Swish

kernel void silu(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    float v = x[gid];
    out[gid] = v / (1.0 + exp(-v));
}

kernel void silu_backward(
    device const float *x   [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    uint                gid [[thread_position_in_grid]])
{
    float v = x[gid];
    float sig = 1.0 / (1.0 + exp(-v));
    // d/dx SiLU(x) = sig + x * sig * (1 - sig)
    dx[gid] = dy[gid] * (sig + v * sig * (1.0 - sig));
}

// MARK: - Sigmoid

kernel void sigmoid_act(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    out[gid] = 1.0 / (1.0 + exp(-x[gid]));
}

kernel void sigmoid_backward(
    device const float *out [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    uint                gid [[thread_position_in_grid]])
{
    float s = out[gid];
    dx[gid] = dy[gid] * s * (1.0 - s);
}

// MARK: - Tanh

kernel void tanh_act(
    device const float *x   [[buffer(0)]],
    device       float *out [[buffer(1)]],
    uint                gid [[thread_position_in_grid]])
{
    out[gid] = tanh(x[gid]);
}

kernel void tanh_backward(
    device const float *out [[buffer(0)]],
    device const float *dy  [[buffer(1)]],
    device       float *dx  [[buffer(2)]],
    uint                gid [[thread_position_in_grid]])
{
    float t = out[gid];
    dx[gid] = dy[gid] * (1.0 - t * t);
}
