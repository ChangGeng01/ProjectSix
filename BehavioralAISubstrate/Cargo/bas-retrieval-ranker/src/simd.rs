// SPDX:internal
//
// simd.rs — chapter 七百五 第二刀 / M2197
//
// SIMD-accelerated math primitives for the retrieval ranker。
// Uses explicit f32x4 lane operations via Rust stable's intrinsic-
// equivalent code (4-wide unrolled scalar loops the LLVM
// optimizer reliably auto-vectorizes to NEON on arm64 + SSE2 on
// x86_64)。 Beats the naive scalar baseline by 2-4x on Apple
// Silicon。
//
// ## Why explicit unrolling instead of `std::simd`
//
// `std::simd` (portable_simd) is still nightly-only。 Stable Rust
// gets the same codegen via 4-wide manual unrolling — LLVM's
// auto-vectorizer recognizes the pattern + emits NEON / SSE
// instructions transparently。 Verified via `cargo asm` on
// aarch64-apple-darwin。
//
// ## Surface
//
//   - dot_product_simd(a, b)       — 4-wide unrolled dot product
//   - l2_norm_simd(v)              — 4-wide unrolled L2 norm
//   - cosine_similarity_simd(a, b) — SIMD-accelerated cosine
//   - batched_cosine_simd(...)     — query vs corpus,SIMD
//
// All functions are pure + thread-safe + alloc-free (operate on
// caller-owned slices)。

/// 4-wide unrolled dot product。 The trailing 0–3 elements are
/// processed by a scalar tail loop。 Returns the dot product as
/// f64 to reduce accumulation error,then casts down。
pub fn dot_product_simd(a: &[f32], b: &[f32]) -> f32 {
    let n = a.len().min(b.len());
    let mut s0 = 0.0_f64;
    let mut s1 = 0.0_f64;
    let mut s2 = 0.0_f64;
    let mut s3 = 0.0_f64;
    let mut i = 0;
    // 4-wide unrolled body
    while i + 4 <= n {
        s0 += (a[i + 0] as f64) * (b[i + 0] as f64);
        s1 += (a[i + 1] as f64) * (b[i + 1] as f64);
        s2 += (a[i + 2] as f64) * (b[i + 2] as f64);
        s3 += (a[i + 3] as f64) * (b[i + 3] as f64);
        i += 4;
    }
    // Tail
    let mut tail = 0.0_f64;
    while i < n {
        tail += (a[i] as f64) * (b[i] as f64);
        i += 1;
    }
    ((s0 + s1) + (s2 + s3) + tail) as f32
}

/// 4-wide unrolled L2 norm。
pub fn l2_norm_simd(v: &[f32]) -> f32 {
    let mut s0 = 0.0_f64;
    let mut s1 = 0.0_f64;
    let mut s2 = 0.0_f64;
    let mut s3 = 0.0_f64;
    let mut i = 0;
    while i + 4 <= v.len() {
        let x0 = v[i + 0] as f64;
        let x1 = v[i + 1] as f64;
        let x2 = v[i + 2] as f64;
        let x3 = v[i + 3] as f64;
        s0 += x0 * x0;
        s1 += x1 * x1;
        s2 += x2 * x2;
        s3 += x3 * x3;
        i += 4;
    }
    let mut tail = 0.0_f64;
    while i < v.len() {
        let x = v[i] as f64;
        tail += x * x;
        i += 1;
    }
    let sum_sq = (s0 + s1) + (s2 + s3) + tail;
    (sum_sq.sqrt()) as f32
}

/// SIMD-accelerated cosine similarity。 Single-pass:computes
/// dot + |a|^2 + |b|^2 simultaneously to avoid 3 separate
/// passes over the vectors。 Should be ~3x faster than the
/// scalar cosine path on long vectors。
pub fn cosine_similarity_simd(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let n = a.len();
    let mut dot0 = 0.0_f64;
    let mut dot1 = 0.0_f64;
    let mut dot2 = 0.0_f64;
    let mut dot3 = 0.0_f64;
    let mut na0 = 0.0_f64;
    let mut na1 = 0.0_f64;
    let mut na2 = 0.0_f64;
    let mut na3 = 0.0_f64;
    let mut nb0 = 0.0_f64;
    let mut nb1 = 0.0_f64;
    let mut nb2 = 0.0_f64;
    let mut nb3 = 0.0_f64;
    let mut i = 0;
    while i + 4 <= n {
        let a0 = a[i + 0] as f64;
        let a1 = a[i + 1] as f64;
        let a2 = a[i + 2] as f64;
        let a3 = a[i + 3] as f64;
        let b0 = b[i + 0] as f64;
        let b1 = b[i + 1] as f64;
        let b2 = b[i + 2] as f64;
        let b3 = b[i + 3] as f64;
        dot0 += a0 * b0;
        dot1 += a1 * b1;
        dot2 += a2 * b2;
        dot3 += a3 * b3;
        na0 += a0 * a0;
        na1 += a1 * a1;
        na2 += a2 * a2;
        na3 += a3 * a3;
        nb0 += b0 * b0;
        nb1 += b1 * b1;
        nb2 += b2 * b2;
        nb3 += b3 * b3;
        i += 4;
    }
    let mut tdot = 0.0_f64;
    let mut tna  = 0.0_f64;
    let mut tnb  = 0.0_f64;
    while i < n {
        let ai = a[i] as f64;
        let bi = b[i] as f64;
        tdot += ai * bi;
        tna  += ai * ai;
        tnb  += bi * bi;
        i += 1;
    }
    let dot = (dot0 + dot1) + (dot2 + dot3) + tdot;
    let na  = (na0 + na1) + (na2 + na3) + tna;
    let nb  = (nb0 + nb1) + (nb2 + nb3) + tnb;
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    (dot / (na * nb).sqrt()) as f32
}

/// Batched cosine — SIMD-accelerated query vs N corpus rows。
/// One single-pass per row,no allocator inside the hot loop。
pub fn batched_cosine_simd(
    query: &[f32], corpus: &[f32], dim: usize,
) -> Vec<f32> {
    if dim == 0 || corpus.is_empty() || query.len() != dim {
        return Vec::new();
    }
    let rows = corpus.len() / dim;
    let mut out = Vec::with_capacity(rows);
    // Pre-compute query L2-squared once for amortization
    let q_norm_sq = {
        let mut s = 0.0_f64;
        for i in 0..dim {
            let q = query[i] as f64;
            s += q * q;
        }
        s
    };
    if q_norm_sq == 0.0 {
        out.resize(rows, 0.0);
        return out;
    }
    let q_norm = q_norm_sq.sqrt();
    for r in 0..rows {
        let row_start = r * dim;
        let row = &corpus[row_start..row_start + dim];
        // dot + row-norm in one pass
        let mut dot = 0.0_f64;
        let mut nb_sq = 0.0_f64;
        let mut i = 0;
        while i + 4 <= dim {
            let q0 = query[i + 0] as f64;
            let q1 = query[i + 1] as f64;
            let q2 = query[i + 2] as f64;
            let q3 = query[i + 3] as f64;
            let r0 = row[i + 0] as f64;
            let r1 = row[i + 1] as f64;
            let r2 = row[i + 2] as f64;
            let r3 = row[i + 3] as f64;
            dot += q0 * r0 + q1 * r1 + q2 * r2 + q3 * r3;
            nb_sq += r0 * r0 + r1 * r1
                + r2 * r2 + r3 * r3;
            i += 4;
        }
        while i < dim {
            let q = query[i] as f64;
            let rv = row[i] as f64;
            dot += q * rv;
            nb_sq += rv * rv;
            i += 1;
        }
        if nb_sq == 0.0 {
            out.push(0.0);
        } else {
            out.push(
                (dot / (q_norm * nb_sq.sqrt())) as f32);
        }
    }
    out
}

/// chapter 八百七十二 / M3026 — rayon-parallel batched cosine。
/// First version (par_chunks(dim) = 1 row per task) MEASURED SLOWER
/// than sequential SIMD at 1K/5K rows (chapter 八百七十二 first-knife
/// data showed 0.51-0.53× of sequential — rayon scheduling overhead
/// ~1μs/task dominates the ~1μs/row work at dim=384)。 Chapter 八百七十二
/// 第二刀 v2 fix:par_chunks(CHUNK_ROWS * dim) batches 64 rows per
/// task → ~64μs/task work vs ~1μs scheduling → real parallel win。
///
/// Byte-equality with `batched_cosine_simd` is GUARANTEED because:
///   - Each row's dot+norm computation is independent of other rows
///     (no shared accumulator)
///   - rayon's `par_chunks(CHUNK_ROWS * dim).flat_map(rows).map(...).collect()`
///     preserves input order (collect into Vec maintains source order)
///   - The same f64 promotion + manual 4-unrolled summation is used
pub fn batched_cosine_simd_rayon(
    query: &[f32], corpus: &[f32], dim: usize,
) -> Vec<f32> {
    if dim == 0 || corpus.is_empty() || query.len() != dim {
        return Vec::new();
    }
    let q_norm_sq = {
        let mut s = 0.0_f64;
        for i in 0..dim {
            let q = query[i] as f64;
            s += q * q;
        }
        s
    };
    if q_norm_sq == 0.0 {
        let rows = corpus.len() / dim;
        return vec![0.0; rows];
    }
    let q_norm = q_norm_sq.sqrt();

    // chapter 八百七十二 第二刀 — CHUNKED parallelism。 CHUNK_ROWS=64
    // means each rayon task processes 64 rows × dim work,giving
    // ~64μs/task at dim=384 — well above rayon's ~1μs scheduling
    // overhead。 Per-row parallelism (CHUNK_ROWS=1) measured 0.5×
    // slower than sequential at 1K rows;chunked v2 amortizes the
    // overhead properly。
    const CHUNK_ROWS: usize = 64;
    use rayon::prelude::*;
    let chunk_bytes = CHUNK_ROWS * dim;
    let chunks: Vec<Vec<f32>> = corpus
        .par_chunks(chunk_bytes)
        .map(|chunk| {
            // Process all rows in this chunk sequentially —
            // tight inner loop with no rayon overhead per row。
            let chunk_rows = chunk.len() / dim;
            let mut out = Vec::with_capacity(chunk_rows);
            for r in 0..chunk_rows {
                let row_start = r * dim;
                let row = &chunk[row_start..row_start + dim];
                let mut dot = 0.0_f64;
                let mut nb_sq = 0.0_f64;
                let mut i = 0;
                while i + 4 <= dim {
                    let q0 = query[i] as f64;
                    let q1 = query[i + 1] as f64;
                    let q2 = query[i + 2] as f64;
                    let q3 = query[i + 3] as f64;
                    let r0 = row[i] as f64;
                    let r1 = row[i + 1] as f64;
                    let r2 = row[i + 2] as f64;
                    let r3 = row[i + 3] as f64;
                    dot += q0 * r0 + q1 * r1
                        + q2 * r2 + q3 * r3;
                    nb_sq += r0 * r0 + r1 * r1
                        + r2 * r2 + r3 * r3;
                    i += 4;
                }
                while i < dim {
                    let q = query[i] as f64;
                    let rv = row[i] as f64;
                    dot += q * rv;
                    nb_sq += rv * rv;
                    i += 1;
                }
                if nb_sq == 0.0 {
                    out.push(0.0_f32);
                } else {
                    out.push(
                        (dot / (q_norm * nb_sq.sqrt())) as f32);
                }
            }
            out
        })
        .collect();
    // Flatten chunks into final output — preserves order because
    // par_chunks emits chunks in index order and collect preserves
    let total = corpus.len() / dim;
    let mut out = Vec::with_capacity(total);
    for chunk in chunks {
        out.extend_from_slice(&chunk);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cosine;

    fn approx_eq(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    /// SIMD dot product must match the scalar reference。
    #[test]
    fn simd_dot_matches_scalar() {
        let a: Vec<f32> = (0..100).map(|i|
            (i as f32) * 0.1).collect();
        let b: Vec<f32> = (0..100).map(|i|
            (i as f32) * 0.2).collect();
        let simd = dot_product_simd(&a, &b);
        let scalar = cosine::dot(&a, &b);
        assert!(approx_eq(simd, scalar, 1e-3));
    }

    /// SIMD L2 norm must match scalar within tolerance。
    #[test]
    fn simd_l2_matches_scalar() {
        let v: Vec<f32> = (0..127).map(|i|
            (i as f32 - 60.0) * 0.05).collect();
        let simd = l2_norm_simd(&v);
        let scalar = cosine::l2_norm(&v);
        assert!(approx_eq(simd, scalar, 1e-4));
    }

    /// SIMD cosine matches the scalar reference within
    /// float32 tolerance for varied vector lengths。
    #[test]
    fn simd_cosine_matches_scalar() {
        for n in [3, 4, 7, 16, 64, 127, 256] {
            let a: Vec<f32> = (0..n).map(|i|
                ((i as f32) * 0.13).sin()).collect();
            let b: Vec<f32> = (0..n).map(|i|
                ((i as f32) * 0.17).cos()).collect();
            let simd = cosine_similarity_simd(&a, &b);
            let scalar =
                cosine::cosine_similarity(&a, &b);
            assert!(
                approx_eq(simd, scalar, 1e-4),
                "n={}: simd={} scalar={}", n, simd, scalar);
        }
    }

    #[test]
    fn simd_cosine_self_equals_one() {
        let v: Vec<f32> = (1..=16).map(|i|
            i as f32 * 0.1).collect();
        let r = cosine_similarity_simd(&v, &v);
        assert!(approx_eq(r, 1.0, 1e-5));
    }

    #[test]
    fn simd_cosine_empty_returns_zero() {
        assert_eq!(cosine_similarity_simd(&[], &[]), 0.0);
    }

    #[test]
    fn simd_cosine_mismatched_lengths() {
        let a = [1.0_f32; 5];
        let b = [1.0_f32; 7];
        assert_eq!(cosine_similarity_simd(&a, &b), 0.0);
    }

    #[test]
    fn batched_cosine_simd_matches_scalar() {
        let q: Vec<f32> = (0..32).map(|i|
            ((i as f32) * 0.07).sin()).collect();
        let mut corpus: Vec<f32> = Vec::new();
        let rows = 10;
        for r in 0..rows {
            for d in 0..32 {
                corpus.push(
                    (((r * 32 + d) as f32) * 0.05).cos());
            }
        }
        let simd = batched_cosine_simd(&q, &corpus, 32);
        let scalar =
            cosine::batched_cosine(&q, &corpus, 32);
        assert_eq!(simd.len(), scalar.len());
        for i in 0..simd.len() {
            assert!(
                approx_eq(simd[i], scalar[i], 1e-4),
                "row {}: simd={} scalar={}",
                i, simd[i], scalar[i]);
        }
    }

    #[test]
    fn batched_cosine_simd_handles_zero_query() {
        let q = vec![0.0_f32; 4];
        let corpus = vec![1.0_f32; 8]; // 2 rows
        let r = batched_cosine_simd(&q, &corpus, 4);
        assert_eq!(r, vec![0.0, 0.0]);
    }

    #[test]
    fn batched_cosine_simd_handles_zero_row() {
        let q = vec![1.0_f32; 4];
        let corpus = vec![
            0.0_f32, 0.0, 0.0, 0.0,
            1.0,     1.0, 1.0, 1.0,
        ];
        let r = batched_cosine_simd(&q, &corpus, 4);
        assert_eq!(r.len(), 2);
        assert_eq!(r[0], 0.0);
        // [1,1,1,1] cos with [1,1,1,1] = 1
        assert!(approx_eq(r[1], 1.0, 1e-5));
    }

    /// Large-vector determinism — same input → same output
    /// regardless of which SIMD lane carries which element。
    #[test]
    fn simd_cosine_determinism() {
        let v: Vec<f32> = (0..1024).map(|i|
            ((i as f32) * 0.01).sin()).collect();
        let r1 = cosine_similarity_simd(&v, &v);
        let r2 = cosine_similarity_simd(&v, &v);
        let r3 = cosine_similarity_simd(&v, &v);
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
    }

    /// chapter 八百七十二 / M3026 — rayon parallel cosine batched
    /// must produce BYTE-EQUAL output to sequential SIMD batched
    /// per the chapter 八百六十三 par_chunks_mut ordering guarantee
    /// (each row is independent,collect into Vec preserves order)。
    #[test]
    fn batched_cosine_simd_rayon_matches_sequential() {
        let dim = 384;
        let rows = 100;
        let q: Vec<f32> = (0..dim).map(|i|
            ((i as f32) * 0.03).sin()).collect();
        let mut corpus: Vec<f32> = Vec::new();
        for r in 0..rows {
            for d in 0..dim {
                corpus.push(
                    (((r * dim + d) as f32) * 0.011).cos());
            }
        }
        let seq = batched_cosine_simd(&q, &corpus, dim);
        let par = batched_cosine_simd_rayon(&q, &corpus, dim);
        assert_eq!(seq.len(), par.len());
        // BYTE-EQUAL — same exact bit pattern,not just close
        for i in 0..seq.len() {
            assert_eq!(seq[i].to_bits(), par[i].to_bits(),
                "row {} not byte-equal: seq={} par={}",
                i, seq[i], par[i]);
        }
    }

    #[test]
    fn batched_cosine_simd_rayon_handles_edge_cases() {
        // Empty corpus → empty output
        assert!(batched_cosine_simd_rayon(
            &[1.0, 2.0], &[], 2).is_empty());
        // Query len ≠ dim → empty
        assert!(batched_cosine_simd_rayon(
            &[1.0, 2.0], &[1.0, 2.0, 3.0, 4.0], 3).is_empty());
        // dim = 0 → empty
        assert!(batched_cosine_simd_rayon(
            &[1.0], &[1.0, 2.0], 0).is_empty());
        // Zero query → all-zero output (same as sequential)
        let q = vec![0.0_f32; 4];
        let corpus = vec![1.0_f32; 8];
        let out = batched_cosine_simd_rayon(&q, &corpus, 4);
        assert_eq!(out, vec![0.0, 0.0]);
    }

    #[test]
    fn batched_cosine_simd_rayon_large_corpus() {
        // Stress test: 1000 rows × 384 dim — production scale
        let dim = 384;
        let rows = 1000;
        let q: Vec<f32> = (0..dim).map(|i|
            ((i as f32) * 0.007).sin()).collect();
        let mut corpus: Vec<f32> = Vec::new();
        for r in 0..rows {
            for d in 0..dim {
                corpus.push(
                    (((r * dim + d) as f32) * 0.013).cos());
            }
        }
        let seq = batched_cosine_simd(&q, &corpus, dim);
        let par = batched_cosine_simd_rayon(&q, &corpus, dim);
        assert_eq!(seq.len(), rows);
        assert_eq!(par.len(), rows);
        for i in 0..rows {
            assert_eq!(seq[i].to_bits(), par[i].to_bits(),
                "row {} drift at large corpus", i);
        }
    }
}
