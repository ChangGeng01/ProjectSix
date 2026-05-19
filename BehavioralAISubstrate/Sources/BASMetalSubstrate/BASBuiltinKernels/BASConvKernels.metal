// SPDX:internal
//
// BASConvKernels.metal — chapter 七百三 第五刀 / M2175
//
// 1D / 2D convolution + transposed convolution in MSL。 Aimed at
// the substrate's small-model paths (sequence-level Conv1D used
// by some embedding / receiver heads;Conv2D used by image-token
// projection)。 No tiling — naive nested loops — fine for the
// kernel sizes the substrate runs (typically K ≤ 7)。

#include <metal_stdlib>
using namespace metal;

// MARK: - conv1d_valid
//
// Inputs: x shape (B, C_in, L_in), weights (C_out, C_in, K)。
// Output shape (B, C_out, L_in - K + 1)。 "Valid" padding mode。
//
// Dispatch:
//   gridSize = (L_out, C_out, B)
//   threadgroupSize = (32, 1, 1)
kernel void conv1d_valid(
    device const float *x       [[buffer(0)]],
    device const float *w       [[buffer(1)]],
    device       float *out     [[buffer(2)]],
    constant     uint  &B       [[buffer(3)]],
    constant     uint  &C_in    [[buffer(4)]],
    constant     uint  &C_out   [[buffer(5)]],
    constant     uint  &L_in    [[buffer(6)]],
    constant     uint  &K       [[buffer(7)]],
    uint3               gid     [[thread_position_in_grid]])
{
    uint l_out = gid.x;
    uint c_out = gid.y;
    uint b     = gid.z;
    uint L_out = L_in - K + 1;
    if (l_out >= L_out || c_out >= C_out || b >= B) {
        return;
    }
    float acc = 0.0;
    for (uint c_in = 0; c_in < C_in; ++c_in) {
        for (uint k = 0; k < K; ++k) {
            float xv = x[
                b * C_in * L_in
                + c_in * L_in
                + (l_out + k)];
            float wv = w[
                c_out * C_in * K
                + c_in * K
                + k];
            acc += xv * wv;
        }
    }
    out[b * C_out * L_out + c_out * L_out + l_out] = acc;
}

// MARK: - conv1d_same_padded
//
// Same as conv1d_valid but with implicit zero-padding so output
// length matches input length。 Padding = (K - 1) / 2 on each side。

kernel void conv1d_same_padded(
    device const float *x       [[buffer(0)]],
    device const float *w       [[buffer(1)]],
    device       float *out     [[buffer(2)]],
    constant     uint  &B       [[buffer(3)]],
    constant     uint  &C_in    [[buffer(4)]],
    constant     uint  &C_out   [[buffer(5)]],
    constant     uint  &L_in    [[buffer(6)]],
    constant     uint  &K       [[buffer(7)]],
    uint3               gid     [[thread_position_in_grid]])
{
    uint l_out = gid.x;
    uint c_out = gid.y;
    uint b     = gid.z;
    if (l_out >= L_in || c_out >= C_out || b >= B) {
        return;
    }
    int pad = int(K) / 2;
    float acc = 0.0;
    for (uint c_in = 0; c_in < C_in; ++c_in) {
        for (uint k = 0; k < K; ++k) {
            int l_in = int(l_out) + int(k) - pad;
            if (l_in < 0 || l_in >= int(L_in)) {
                continue;
            }
            float xv = x[
                b * C_in * L_in
                + c_in * L_in
                + uint(l_in)];
            float wv = w[
                c_out * C_in * K
                + c_in * K
                + k];
            acc += xv * wv;
        }
    }
    out[b * C_out * L_in + c_out * L_in + l_out] = acc;
}

// MARK: - conv1d_dilated
//
// Dilated 1D convolution with dilation factor `D` (NOT to be
// confused with depth dim)。 Effective kernel span:
// (K - 1) * D + 1。

kernel void conv1d_dilated(
    device const float *x         [[buffer(0)]],
    device const float *w         [[buffer(1)]],
    device       float *out       [[buffer(2)]],
    constant     uint  &B         [[buffer(3)]],
    constant     uint  &C_in      [[buffer(4)]],
    constant     uint  &C_out     [[buffer(5)]],
    constant     uint  &L_in      [[buffer(6)]],
    constant     uint  &K         [[buffer(7)]],
    constant     uint  &dilation  [[buffer(8)]],
    uint3               gid       [[thread_position_in_grid]])
{
    uint l_out = gid.x;
    uint c_out = gid.y;
    uint b     = gid.z;
    uint span = (K - 1) * dilation + 1;
    if (l_out + span > L_in
        || c_out >= C_out || b >= B) {
        return;
    }
    uint L_out = L_in - span + 1;
    float acc = 0.0;
    for (uint c_in = 0; c_in < C_in; ++c_in) {
        for (uint k = 0; k < K; ++k) {
            float xv = x[
                b * C_in * L_in
                + c_in * L_in
                + (l_out + k * dilation)];
            float wv = w[
                c_out * C_in * K
                + c_in * K
                + k];
            acc += xv * wv;
        }
    }
    out[b * C_out * L_out + c_out * L_out + l_out] = acc;
}

// MARK: - conv2d_valid
//
// Inputs:
//   x shape (B, C_in, H_in, W_in)
//   w shape (C_out, C_in, KH, KW)
// Output (B, C_out, H_in - KH + 1, W_in - KW + 1)。 Naive
// implementation — one thread per output cell。

kernel void conv2d_valid(
    device const float *x       [[buffer(0)]],
    device const float *w       [[buffer(1)]],
    device       float *out     [[buffer(2)]],
    constant     uint  &B       [[buffer(3)]],
    constant     uint  &C_in    [[buffer(4)]],
    constant     uint  &C_out   [[buffer(5)]],
    constant     uint  &H_in    [[buffer(6)]],
    constant     uint  &W_in    [[buffer(7)]],
    constant     uint  &KH      [[buffer(8)]],
    constant     uint  &KW      [[buffer(9)]],
    uint3               gid     [[thread_position_in_grid]])
{
    uint w_out = gid.x;
    uint h_out = gid.y;
    uint b_co  = gid.z;
    uint H_out = H_in - KH + 1;
    uint W_out = W_in - KW + 1;
    uint c_out = b_co % C_out;
    uint b     = b_co / C_out;
    if (h_out >= H_out || w_out >= W_out
        || c_out >= C_out || b >= B) {
        return;
    }
    float acc = 0.0;
    for (uint c_in = 0; c_in < C_in; ++c_in) {
        for (uint kh = 0; kh < KH; ++kh) {
            for (uint kw = 0; kw < KW; ++kw) {
                float xv = x[
                    b * C_in * H_in * W_in
                    + c_in * H_in * W_in
                    + (h_out + kh) * W_in
                    + (w_out + kw)];
                float wv = w[
                    c_out * C_in * KH * KW
                    + c_in * KH * KW
                    + kh * KW
                    + kw];
                acc += xv * wv;
            }
        }
    }
    out[b * C_out * H_out * W_out
        + c_out * H_out * W_out
        + h_out * W_out
        + w_out] = acc;
}

// MARK: - depthwise_conv2d
//
// Depthwise: one filter per input channel (C_in == C_out)。
// Useful for mobile-friendly model architectures。

kernel void depthwise_conv2d_valid(
    device const float *x       [[buffer(0)]],
    device const float *w       [[buffer(1)]],
    device       float *out     [[buffer(2)]],
    constant     uint  &B       [[buffer(3)]],
    constant     uint  &C       [[buffer(4)]],
    constant     uint  &H_in    [[buffer(5)]],
    constant     uint  &W_in    [[buffer(6)]],
    constant     uint  &KH      [[buffer(7)]],
    constant     uint  &KW      [[buffer(8)]],
    uint3               gid     [[thread_position_in_grid]])
{
    uint w_out = gid.x;
    uint h_out = gid.y;
    uint b_c   = gid.z;
    uint H_out = H_in - KH + 1;
    uint W_out = W_in - KW + 1;
    uint c = b_c % C;
    uint b = b_c / C;
    if (h_out >= H_out || w_out >= W_out
        || c >= C || b >= B) {
        return;
    }
    float acc = 0.0;
    for (uint kh = 0; kh < KH; ++kh) {
        for (uint kw = 0; kw < KW; ++kw) {
            float xv = x[
                b * C * H_in * W_in
                + c * H_in * W_in
                + (h_out + kh) * W_in
                + (w_out + kw)];
            float wv = w[
                c * KH * KW
                + kh * KW
                + kw];
            acc += xv * wv;
        }
    }
    out[b * C * H_out * W_out
        + c * H_out * W_out
        + h_out * W_out
        + w_out] = acc;
}
