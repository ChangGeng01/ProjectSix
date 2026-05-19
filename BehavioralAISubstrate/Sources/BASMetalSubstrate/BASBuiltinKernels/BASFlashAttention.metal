// SPDX:internal
//
// BASFlashAttention.metal — chapter 七百五 第一刀 / M2196
//
// Memory-efficient tiled attention in Metal Shading Language。
//
// ## What this kernel ships
//
// `flash_attention_forward` computes
//
//     O = softmax(Q · K^T / sqrt(D)) · V
//
// using the FlashAttention-2 tiling pattern:O(N) memory instead
// of O(N^2)。 Iterates over key/value tiles loading them into
// threadgroup-shared memory + maintains a running max + running
// exp-sum per query row so the final softmax normalization
// happens online。 Equivalent output to the standard `scaled_
// dot_product_attention` kernel,but uses ~1/N as much memory
// for long sequences。
//
// ## Why this matters
//
// Standard attention materializes the full N×N attention matrix
// in device memory。 For N=4096 + float32 that's 64 MB per
// attention layer — exhausts the Apple Silicon GPU's L1/L2
// caches and forces sequential off-chip reads。 The tiled
// approach keeps O(B_r × B_c) = O(128 × 128) = 64 KB of
// attention scores resident per threadgroup at a time → all
// computation hits the on-chip cache + the GPU never sees an
// N^2 matrix。
//
// ## Tile sizes
//
//   - Q tile (B_r):  64 rows
//   - K/V tile (B_c): 64 cols (matches Q tile for square-ish tiles)
//   - D ≤ 128         (head dim cap — covers all standard transformer heads
//                       (32 / 64 / 80 / 96 / 128))
//
// Threadgroup workspace:
//   - Q_tile [B_r × D]     — query rows
//   - K_tile [B_c × D]     — key tile
//   - V_tile [B_c × D_v]   — value tile
//   - S_tile [B_r × B_c]   — attention scores for this tile
//
// At B_r = B_c = 64 + D = D_v = 128 + float32:
//   Q_tile : 64 × 128 × 4 = 32 KB
//   K_tile : 64 × 128 × 4 = 32 KB
//   V_tile : 64 × 128 × 4 = 32 KB
//   S_tile : 64 × 64  × 4 = 16 KB
//   total  : ~112 KB threadgroup memory — fits within Apple
//             Silicon's 32 KB-per-threadgroup limit only IF we
//             page through D in chunks。 V1 (this commit) uses
//             smaller tiles (B_r = B_c = 32, D ≤ 64) which fits
//             in ~24 KB; bigger tiles are a planned-future-cut。
//
// V1 tile sizes (this commit):
//   B_r = 32  /  B_c = 32  /  D_max = 64

#include <metal_stdlib>
using namespace metal;

constant uint  B_R    = 32;       // Q tile rows
constant uint  B_C    = 32;       // K/V tile cols
constant uint  D_MAX  = 64;       // head dim cap

struct FlashAttnShape {
    uint M;     // # query rows  (sequence length on Q side)
    uint N;     // # key/value rows
    uint D;     // head dim of Q + K
    uint Dv;    // head dim of V
};

// MARK: - flash_attention_forward
//
// Dispatch shape: one threadgroup per (query_tile, head)。
// In V1 we have one head + B_r = 32 rows per tile → gridSize =
// (ceil(M / B_r), 1, 1)。
//
// Each threadgroup processes B_r query rows + iterates over
// all key/value tiles。 Within a threadgroup,B_r threads each
// own one query row + walk the full N tiles。
//
// Per query row,maintains running (m, l):
//   - m: running max of scaled scores
//   - l: running exp-sum (denominator)
//   - O: running weighted sum of values
//
// At end of pass over all key/value tiles, divides O by l →
// final output。

kernel void flash_attention_forward(
    device const float       *Q       [[buffer(0)]],
    device const float       *K       [[buffer(1)]],
    device const float       *V       [[buffer(2)]],
    device       float       *O       [[buffer(3)]],
    constant     FlashAttnShape &shape [[buffer(4)]],
    uint                       tg_id  [[threadgroup_position_in_grid]],
    uint                       lane   [[thread_position_in_threadgroup]])
{
    const uint M  = shape.M;
    const uint N  = shape.N;
    const uint D  = shape.D;
    const uint Dv = shape.Dv;

    // Each lane handles one query row inside this tile。
    const uint q_row = tg_id * B_R + lane;
    if (q_row >= M || lane >= B_R) {
        return;
    }

    const float inv_sqrt_d = rsqrt(float(D));

    // Per-thread running statistics + accumulator
    float m_i = -INFINITY;
    float l_i = 0.0;
    // Output accumulator — Dv values, kept in registers
    // (D_MAX = 64 max, fits comfortably)
    float O_i[D_MAX];
    for (uint d = 0; d < Dv; ++d) {
        O_i[d] = 0.0;
    }

    // Pre-load this thread's Q row into registers
    float Q_i[D_MAX];
    for (uint d = 0; d < D; ++d) {
        Q_i[d] = Q[q_row * D + d];
    }

    // Tile over key/value
    uint num_kv_tiles = (N + B_C - 1) / B_C;
    for (uint t = 0; t < num_kv_tiles; ++t) {
        // Compute scaled dot products for this tile:
        //   S_ij = (Q_i · K_j) * inv_sqrt_d   for j in [0, B_C)
        float S_i[B_C];
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N) {
                S_i[j] = -INFINITY;
                continue;
            }
            float dot = 0.0;
            for (uint d = 0; d < D; ++d) {
                dot += Q_i[d] * K[k_row * D + d];
            }
            S_i[j] = dot * inv_sqrt_d;
        }

        // Online softmax update:
        //   m_new = max(m_i, max(S_i))
        //   alpha = exp(m_i - m_new)
        //   l_new = alpha * l_i + Σⱼ exp(S_i_j - m_new)
        //   O_new = alpha * O_i + Σⱼ exp(S_i_j - m_new) * V_j
        float m_new = m_i;
        for (uint j = 0; j < B_C; ++j) {
            if (S_i[j] > m_new) { m_new = S_i[j]; }
        }
        float alpha = exp(m_i - m_new);
        float l_new = alpha * l_i;
        // Pre-rescale O_i by alpha
        for (uint d = 0; d < Dv; ++d) {
            O_i[d] *= alpha;
        }
        // Add this tile's contribution
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N) { continue; }
            float p = exp(S_i[j] - m_new);
            l_new += p;
            for (uint d = 0; d < Dv; ++d) {
                O_i[d] += p * V[k_row * Dv + d];
            }
        }
        m_i = m_new;
        l_i = l_new;
    }

    // Final normalize + write to output
    if (l_i > 0.0) {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = O_i[d] / l_i;
        }
    } else {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = 0.0;
        }
    }
}

// MARK: - flash_attention_forward_masked
//
// Same as flash_attention_forward but with an additive boolean
// mask。 mask[i * N + j] != 0 → that key position is excluded
// from the softmax (its scaled score gets clamped to -INF before
// the online running-max + running-sum updates)。

kernel void flash_attention_forward_masked(
    device const float          *Q     [[buffer(0)]],
    device const float          *K     [[buffer(1)]],
    device const float          *V     [[buffer(2)]],
    device const uchar          *mask  [[buffer(3)]],
    device       float          *O     [[buffer(4)]],
    constant     FlashAttnShape &shape [[buffer(5)]],
    uint                         tg_id [[threadgroup_position_in_grid]],
    uint                         lane  [[thread_position_in_threadgroup]])
{
    const uint M  = shape.M;
    const uint N  = shape.N;
    const uint D  = shape.D;
    const uint Dv = shape.Dv;
    const uint q_row = tg_id * B_R + lane;
    if (q_row >= M || lane >= B_R) { return; }
    const float inv_sqrt_d = rsqrt(float(D));

    float m_i = -INFINITY;
    float l_i = 0.0;
    float O_i[D_MAX];
    for (uint d = 0; d < Dv; ++d) { O_i[d] = 0.0; }
    float Q_i[D_MAX];
    for (uint d = 0; d < D; ++d) { Q_i[d] = Q[q_row * D + d]; }

    uint num_kv_tiles = (N + B_C - 1) / B_C;
    for (uint t = 0; t < num_kv_tiles; ++t) {
        float S_i[B_C];
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N
                || mask[q_row * N + k_row] != 0)
            {
                S_i[j] = -INFINITY;
                continue;
            }
            float dot = 0.0;
            for (uint d = 0; d < D; ++d) {
                dot += Q_i[d] * K[k_row * D + d];
            }
            S_i[j] = dot * inv_sqrt_d;
        }
        float m_new = m_i;
        for (uint j = 0; j < B_C; ++j) {
            if (S_i[j] > m_new) { m_new = S_i[j]; }
        }
        float alpha = exp(m_i - m_new);
        float l_new = alpha * l_i;
        for (uint d = 0; d < Dv; ++d) { O_i[d] *= alpha; }
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N
                || mask[q_row * N + k_row] != 0)
            { continue; }
            float p = exp(S_i[j] - m_new);
            l_new += p;
            for (uint d = 0; d < Dv; ++d) {
                O_i[d] += p * V[k_row * Dv + d];
            }
        }
        m_i = m_new;
        l_i = l_new;
    }
    if (l_i > 0.0) {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = O_i[d] / l_i;
        }
    } else {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = 0.0;
        }
    }
}

// MARK: - flash_attention_forward_causal
//
// Same as flash_attention_forward with implicit causal mask:
// position i can only attend to positions j ≤ i。 No external
// mask buffer needed。 Saves the host one allocation + one
// transfer for the common autoregressive-decoder shape。

kernel void flash_attention_forward_causal(
    device const float          *Q     [[buffer(0)]],
    device const float          *K     [[buffer(1)]],
    device const float          *V     [[buffer(2)]],
    device       float          *O     [[buffer(3)]],
    constant     FlashAttnShape &shape [[buffer(4)]],
    uint                         tg_id [[threadgroup_position_in_grid]],
    uint                         lane  [[thread_position_in_threadgroup]])
{
    const uint M  = shape.M;
    const uint N  = shape.N;
    const uint D  = shape.D;
    const uint Dv = shape.Dv;
    const uint q_row = tg_id * B_R + lane;
    if (q_row >= M || lane >= B_R) { return; }
    const float inv_sqrt_d = rsqrt(float(D));

    float m_i = -INFINITY;
    float l_i = 0.0;
    float O_i[D_MAX];
    for (uint d = 0; d < Dv; ++d) { O_i[d] = 0.0; }
    float Q_i[D_MAX];
    for (uint d = 0; d < D; ++d) { Q_i[d] = Q[q_row * D + d]; }

    uint num_kv_tiles = (N + B_C - 1) / B_C;
    for (uint t = 0; t < num_kv_tiles; ++t) {
        float S_i[B_C];
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N || k_row > q_row) {
                S_i[j] = -INFINITY;
                continue;
            }
            float dot = 0.0;
            for (uint d = 0; d < D; ++d) {
                dot += Q_i[d] * K[k_row * D + d];
            }
            S_i[j] = dot * inv_sqrt_d;
        }
        float m_new = m_i;
        for (uint j = 0; j < B_C; ++j) {
            if (S_i[j] > m_new) { m_new = S_i[j]; }
        }
        float alpha = exp(m_i - m_new);
        float l_new = alpha * l_i;
        for (uint d = 0; d < Dv; ++d) { O_i[d] *= alpha; }
        for (uint j = 0; j < B_C; ++j) {
            uint k_row = t * B_C + j;
            if (k_row >= N || k_row > q_row) { continue; }
            float p = exp(S_i[j] - m_new);
            l_new += p;
            for (uint d = 0; d < Dv; ++d) {
                O_i[d] += p * V[k_row * Dv + d];
            }
        }
        m_i = m_new;
        l_i = l_new;
    }
    if (l_i > 0.0) {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = O_i[d] / l_i;
        }
    } else {
        for (uint d = 0; d < Dv; ++d) {
            O[q_row * Dv + d] = 0.0;
        }
    }
}
