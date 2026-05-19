// SPDX:internal
//
// bas-retrieval-ranker — chapter 七百三 第三刀 / M2173
//
// Rust port of retrieval-side substrate logic:
//   - cosine similarity (vector + scalar)
//   - score-decay policies (exponential, linear, step)
//   - rank-fuse combinator (multi-signal ranking)
//   - top-K selection with stable tie-breaking
//
// Previously scattered across Sources/BASMemory/CognitionCore
// .swift, BASOrchestration/EBrainNeuralMaterializationCore
// .swift, ObservabilityCore.swift, and projection layers。

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod activations; // chapter 七百十一 第一刀 — GELU + SiLU (scalar + SIMD)
pub mod cosine;
pub mod decay;
pub mod fuser;
pub mod layer_norm; // chapter 七百九 第二刀 — LayerNorm (welford + SIMD)
pub mod matmul;     // chapter 七百八 第一刀 — cache-blocked + SIMD matmul
pub mod simd;       // chapter 七百五 第二刀 — SIMD-accelerated math
pub mod softmax;    // chapter 七百九 第一刀 — numerically-stable softmax
pub mod topk;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_ranker_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - C ABI surface — chapter 七百四 第三刀

/// Compute cosine similarity between two equal-length float
/// vectors。 Returns the similarity via `*out_score`。
///
/// Returns:
///   - 0  on success
///   - -1 on null pointer or zero-length input
///   - -2 on length mismatch (a_len != b_len)
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_cosine_similarity(
    a: *const f32,
    a_len: usize,
    b: *const f32,
    b_len: usize,
    out_score: *mut f32,
) -> i32 {
    if a.is_null() || b.is_null() || out_score.is_null() {
        return -1;
    }
    if a_len == 0 {
        return -1;
    }
    if a_len != b_len {
        return -2;
    }
    // SAFETY: caller guarantees `a` and `b` point to `a_len` /
    // `b_len` valid float32 readable slots, and `out_score`
    // points to one writable float32。
    let a_slice = unsafe {
        core::slice::from_raw_parts(a, a_len)
    };
    let b_slice = unsafe {
        core::slice::from_raw_parts(b, b_len)
    };
    let score = cosine::cosine_similarity(a_slice, b_slice);
    unsafe { *out_score = score; }
    0
}

/// Compute L2 norm of a float vector → `*out_norm`。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_l2_norm(
    v: *const f32,
    v_len: usize,
    out_norm: *mut f32,
) -> i32 {
    if v.is_null() || out_norm.is_null() || v_len == 0 {
        return -1;
    }
    let s = unsafe { core::slice::from_raw_parts(v, v_len) };
    unsafe { *out_norm = cosine::l2_norm(s); }
    0
}

/// SIMD-accelerated cosine similarity — chapter 七百五 第二刀。
/// Same surface as `bas_ranker_cosine_similarity` but routes
/// through the 4-wide unrolled implementation that LLVM
/// auto-vectorizes to NEON on aarch64 + SSE2 on x86_64。
/// Faster than the scalar baseline for vectors of length ≥ 8。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_cosine_similarity_simd(
    a: *const f32,
    a_len: usize,
    b: *const f32,
    b_len: usize,
    out_score: *mut f32,
) -> i32 {
    if a.is_null() || b.is_null() || out_score.is_null() {
        return -1;
    }
    if a_len == 0 { return -1; }
    if a_len != b_len { return -2; }
    let a_slice = unsafe {
        core::slice::from_raw_parts(a, a_len)
    };
    let b_slice = unsafe {
        core::slice::from_raw_parts(b, b_len)
    };
    let s = simd::cosine_similarity_simd(a_slice, b_slice);
    unsafe { *out_score = s; }
    0
}

/// SIMD-accelerated L2 norm — chapter 七百五 第二刀。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_l2_norm_simd(
    v: *const f32,
    v_len: usize,
    out_norm: *mut f32,
) -> i32 {
    if v.is_null() || out_norm.is_null() || v_len == 0 {
        return -1;
    }
    let s = unsafe { core::slice::from_raw_parts(v, v_len) };
    unsafe { *out_norm = simd::l2_norm_simd(s); }
    0
}

// MARK: - chapter 七百八 第一刀 MatMul C ABI

/// MatMul naive O(MNK) — reference / oracle path。 Returns 0 on
/// success,-1 on null pointer,-2 on shape mismatch。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_matmul_naive(
    a: *const f32, a_len: usize,
    b: *const f32, b_len: usize,
    c: *mut f32, c_len: usize,
    m: usize, n: usize, k: usize,
) -> i32 {
    if a.is_null() || b.is_null() || c.is_null() {
        return -1;
    }
    if a_len != m * k || b_len != k * n || c_len != m * n {
        return -2;
    }
    let a_slice = unsafe {
        core::slice::from_raw_parts(a, a_len)
    };
    let b_slice = unsafe {
        core::slice::from_raw_parts(b, b_len)
    };
    let c_slice = unsafe {
        core::slice::from_raw_parts_mut(c, c_len)
    };
    matmul::matmul_naive(
        a_slice, b_slice, c_slice, m, n, k);
    0
}

/// Cache-blocked MatMul — wins over naive for medium-large
/// matrices due to L1 cache locality。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_matmul_blocked(
    a: *const f32, a_len: usize,
    b: *const f32, b_len: usize,
    c: *mut f32, c_len: usize,
    m: usize, n: usize, k: usize,
) -> i32 {
    if a.is_null() || b.is_null() || c.is_null() {
        return -1;
    }
    if a_len != m * k || b_len != k * n || c_len != m * n {
        return -2;
    }
    let a_slice = unsafe {
        core::slice::from_raw_parts(a, a_len)
    };
    let b_slice = unsafe {
        core::slice::from_raw_parts(b, b_len)
    };
    let c_slice = unsafe {
        core::slice::from_raw_parts_mut(c, c_len)
    };
    matmul::matmul_blocked(
        a_slice, b_slice, c_slice, m, n, k);
    0
}

// MARK: - chapter 七百九 第一刀 Softmax C ABI

/// Numerically-stable softmax (scalar)。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_softmax(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_slice = unsafe {
        core::slice::from_raw_parts(x, n)
    };
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    softmax::softmax_stable(x_slice, out_slice);
    0
}

/// SIMD-accelerated stable softmax。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_softmax_simd(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_slice = unsafe {
        core::slice::from_raw_parts(x, n)
    };
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    softmax::softmax_stable_simd(x_slice, out_slice);
    0
}

// MARK: - chapter 七百九 第二刀 LayerNorm C ABI

/// LayerNorm naive — two-pass mean + variance。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_layer_norm(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
    eps: f32,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    layer_norm::layer_norm_naive(x_s, o_s, eps);
    0
}

/// LayerNorm Welford — single-pass numerically stable。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_layer_norm_welford(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
    eps: f32,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    layer_norm::layer_norm_welford(x_s, o_s, eps);
    0
}

/// LayerNorm affine + SIMD: y = γ(x-μ)/√(σ²+ε) + β。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_layer_norm_affine_simd(
    x: *const f32, x_len: usize,
    gamma: *const f32, gamma_len: usize,
    beta: *const f32, beta_len: usize,
    out: *mut f32, out_len: usize,
    eps: f32,
) -> i32 {
    if x.is_null() || gamma.is_null()
        || beta.is_null() || out.is_null()
    { return -1; }
    if x_len == 0 || x_len != out_len
        || x_len != gamma_len || x_len != beta_len
    { return -2; }
    let x_s = unsafe {
        core::slice::from_raw_parts(x, x_len)
    };
    let g_s = unsafe {
        core::slice::from_raw_parts(gamma, gamma_len)
    };
    let b_s = unsafe {
        core::slice::from_raw_parts(beta, beta_len)
    };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, out_len)
    };
    layer_norm::layer_norm_affine_simd(
        x_s, g_s, b_s, o_s, eps);
    0
}

/// Row-wise softmax over (rows × cols) matrix。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_softmax_rowwise_simd(
    x: *const f32, x_len: usize,
    out: *mut f32, out_len: usize,
    rows: usize, cols: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    let expected = rows * cols;
    if x_len != expected || out_len != expected
        || rows == 0 || cols == 0
    {
        return -2;
    }
    let x_slice = unsafe {
        core::slice::from_raw_parts(x, x_len)
    };
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out, out_len)
    };
    softmax::softmax_rowwise_simd(
        x_slice, out_slice, rows, cols);
    0
}

/// Cache-blocked + SIMD-unrolled MatMul — fastest CPU path。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_matmul_simd_blocked(
    a: *const f32, a_len: usize,
    b: *const f32, b_len: usize,
    c: *mut f32, c_len: usize,
    m: usize, n: usize, k: usize,
) -> i32 {
    if a.is_null() || b.is_null() || c.is_null() {
        return -1;
    }
    if a_len != m * k || b_len != k * n || c_len != m * n {
        return -2;
    }
    let a_slice = unsafe {
        core::slice::from_raw_parts(a, a_len)
    };
    let b_slice = unsafe {
        core::slice::from_raw_parts(b, b_len)
    };
    let c_slice = unsafe {
        core::slice::from_raw_parts_mut(c, c_len)
    };
    matmul::matmul_simd_blocked(
        a_slice, b_slice, c_slice, m, n, k);
    0
}

// MARK: - chapter 七百十一 第一/二刀 Activation C ABI

/// GELU exact: y = 0.5*x*(1 + erf(x/√2))。 Matches
/// torch.nn.functional.gelu。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_gelu_exact(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::gelu_exact(x_s, o_s);
    0
}

/// GELU exact SIMD 4-wide unrolled。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_gelu_exact_simd(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::gelu_exact_simd(x_s, o_s);
    0
}

/// GELU tanh approximation: matches
/// torch.nn.functional.gelu(approximate="tanh")。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_gelu_tanh_approx(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::gelu_tanh_approx(x_s, o_s);
    0
}

/// GELU tanh-approx SIMD 4-wide unrolled。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_gelu_tanh_approx_simd(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::gelu_tanh_approx_simd(x_s, o_s);
    0
}

/// SiLU (Swish): y = x * σ(x)。 Matches
/// torch.nn.functional.silu。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_silu(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::silu(x_s, o_s);
    0
}

/// SiLU SIMD 4-wide unrolled。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_silu_simd(
    x: *const f32, n: usize,
    out: *mut f32, out_n: usize,
) -> i32 {
    if x.is_null() || out.is_null() { return -1; }
    if n == 0 || n != out_n { return -2; }
    let x_s = unsafe { core::slice::from_raw_parts(x, n) };
    let o_s = unsafe {
        core::slice::from_raw_parts_mut(out, n)
    };
    activations::silu_simd(x_s, o_s);
    0
}

/// SIMD-accelerated batched cosine — chapter 七百五 第二刀。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_batched_cosine_simd(
    query: *const f32,
    query_len: usize,
    corpus: *const f32,
    corpus_total_len: usize,
    dim: usize,
    out_scores: *mut f32,
) -> i32 {
    if query.is_null() || corpus.is_null()
        || out_scores.is_null()
    { return -1; }
    if dim == 0 || query_len != dim { return -1; }
    if corpus_total_len % dim != 0 { return -1; }
    let rows = corpus_total_len / dim;
    let q = unsafe {
        core::slice::from_raw_parts(query, query_len)
    };
    let c = unsafe {
        core::slice::from_raw_parts(corpus, corpus_total_len)
    };
    let scores = simd::batched_cosine_simd(q, c, dim);
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out_scores, rows)
    };
    for (i, s) in scores.iter().enumerate() {
        out_slice[i] = *s;
    }
    0
}

/// Batched cosine — query × corpus (rows × dim row-major) →
/// `out_scores` (length `corpus_rows`)。 Returns -1 on null
/// pointer or invalid shapes, otherwise 0。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_batched_cosine(
    query: *const f32,
    query_len: usize,
    corpus: *const f32,
    corpus_total_len: usize,
    dim: usize,
    out_scores: *mut f32,
) -> i32 {
    if query.is_null() || corpus.is_null()
        || out_scores.is_null()
    {
        return -1;
    }
    if dim == 0 || query_len != dim {
        return -1;
    }
    if corpus_total_len % dim != 0 {
        return -1;
    }
    let rows = corpus_total_len / dim;
    let query_slice = unsafe {
        core::slice::from_raw_parts(query, query_len)
    };
    let corpus_slice = unsafe {
        core::slice::from_raw_parts(corpus, corpus_total_len)
    };
    let scores =
        cosine::batched_cosine(query_slice, corpus_slice, dim);
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out_scores, rows)
    };
    for (i, s) in scores.iter().enumerate() {
        out_slice[i] = *s;
    }
    0
}

#[cfg(test)]
mod ffi_tests {
    use super::*;

    #[test]
    fn ffi_cosine_self_equals_one() {
        let v = [1.0_f32, 2.0, 3.0, 4.0];
        let mut score: f32 = 0.0;
        let rc = unsafe {
            bas_ranker_cosine_similarity(
                v.as_ptr(), v.len(),
                v.as_ptr(), v.len(),
                &mut score)
        };
        assert_eq!(rc, 0);
        assert!((score - 1.0).abs() < 1e-6);
    }

    #[test]
    fn ffi_cosine_null_returns_minus_one() {
        let v = [1.0_f32];
        let mut score: f32 = 0.0;
        let rc = unsafe {
            bas_ranker_cosine_similarity(
                core::ptr::null(), 1,
                v.as_ptr(), 1,
                &mut score)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn ffi_cosine_mismatched_lengths() {
        let a = [1.0_f32, 2.0];
        let b = [1.0_f32];
        let mut score: f32 = 0.0;
        let rc = unsafe {
            bas_ranker_cosine_similarity(
                a.as_ptr(), a.len(),
                b.as_ptr(), b.len(),
                &mut score)
        };
        assert_eq!(rc, -2);
    }

    #[test]
    fn ffi_l2_norm() {
        let v = [3.0_f32, 4.0];
        let mut n: f32 = 0.0;
        let rc = unsafe {
            bas_ranker_l2_norm(v.as_ptr(), 2, &mut n)
        };
        assert_eq!(rc, 0);
        assert!((n - 5.0).abs() < 1e-6);
    }

    #[test]
    fn ffi_batched_cosine_shape() {
        let q = [1.0_f32, 0.0];
        // 3 rows of dim 2: [1,0], [0,1], [1,1]
        let corpus = [
            1.0_f32, 0.0,
            0.0, 1.0,
            1.0, 1.0,
        ];
        let mut scores = vec![0.0_f32; 3];
        let rc = unsafe {
            bas_ranker_batched_cosine(
                q.as_ptr(), q.len(),
                corpus.as_ptr(), corpus.len(),
                2,
                scores.as_mut_ptr())
        };
        assert_eq!(rc, 0);
        assert!((scores[0] - 1.0).abs() < 1e-6);
        assert!(scores[1].abs() < 1e-6);
        assert!((scores[2] - 0.7071068).abs() < 1e-5);
    }
}
