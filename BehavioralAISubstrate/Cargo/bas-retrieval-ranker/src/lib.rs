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

pub mod activations;      // chapter 七百十一 第一刀 — GELU + SiLU
pub mod cosine;
pub mod decay;
pub mod forget_cascade;   // chapter 七百十三 第一刀 — forget-cascade filter
pub mod fuser;
pub mod layer_norm;       // chapter 七百九 第二刀 — LayerNorm
pub mod ledger;           // chapter 七百十二 第一刀 — batched seal + verify
pub mod matmul;           // chapter 七百八 第一刀 — cache-blocked + SIMD matmul
pub mod provenance;       // chapter 七百十三 第二刀 — attestation-tier filter
pub mod simd;             // chapter 七百五 第二刀 — SIMD-accelerated math
pub mod softmax;          // chapter 七百九 第一刀 — numerically-stable softmax
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

// MARK: - chapter 七百十二 第二刀 Ledger C ABI
//
// Per architectural matrix「Rust owns ledger/replay +
// integrity hash」 — these collapse N Swift→Rust FFI calls
// into 1 batch call for the audit-ledger hot path。

/// One-shot pure seal: SHA256(canonical) → 32-byte out。
/// Matches Swift `Data(SHA256.hash(data: canonical))` exactly。
/// Returns 0 on success,-1 on null pointer。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_ledger_seal(
    canonical: *const u8, canonical_len: usize,
    out_32: *mut u8,
) -> i32 {
    if out_32.is_null() { return -1; }
    let can_slice: &[u8] = if canonical_len == 0 {
        &[]
    } else if canonical.is_null() {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(
                canonical, canonical_len)
        }
    };
    let digest = ledger::ledger_seal_pure(can_slice);
    unsafe {
        core::ptr::copy_nonoverlapping(
            digest.as_ptr(), out_32, 32);
    }
    0
}

/// Batch seal — for each of N records,compute its
/// SHA256(canonical) into the corresponding 32-byte slot of
/// `out_self_hashes`。 Inputs:
///
///   - `initial_32`         : 32-byte prior anchor (unused for
///                            pure seal but kept for parity with
///                            verify_chain ABI)
///   - `canonicals_buf`     : N records as a flat buffer of
///                            length-prefixed payloads
///                            (u32_be size + bytes per record)
///   - `canonicals_buf_len` : total byte length of the flat buf
///   - `n`                  : number of records
///   - `out_self_hashes`    : caller-owned N*32 byte buffer
///
/// Returns:
///   - 0 on success
///   - -1 on null pointer
///   - -2 on truncated `canonicals_buf` (size prefixes don't
///         consume exactly the buffer length)
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_ledger_seal_batch(
    initial_32: *const u8,
    canonicals_buf: *const u8,
    canonicals_buf_len: usize,
    n: usize,
    out_self_hashes_n_x_32: *mut u8,
) -> i32 {
    if initial_32.is_null() { return -1; }
    if n == 0 {
        // No records to seal — every pointer can be null。
        return 0;
    }
    if canonicals_buf.is_null() || canonicals_buf_len == 0
        || out_self_hashes_n_x_32.is_null()
    {
        return -1;
    }
    let buf = unsafe {
        core::slice::from_raw_parts(
            canonicals_buf, canonicals_buf_len)
    };
    let canonicals = match decode_length_prefixed(buf, n) {
        Some(v) => v,
        None => return -2,
    };
    let mut initial = [0u8; 32];
    initial.copy_from_slice(unsafe {
        core::slice::from_raw_parts(initial_32, 32)
    });
    let mut out = vec![[0u8; 32]; n];
    ledger::seal_batch_pure(
        &initial, &canonicals, &mut out);
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(
            out_self_hashes_n_x_32, n * 32)
    };
    for (i, h) in out.iter().enumerate() {
        out_slice[i * 32..(i + 1) * 32]
            .copy_from_slice(h);
    }
    0
}

/// Verify an N-entry chain。 For each i in 0..N,recomputes
/// SHA256(canonicals[i]) and compares to
/// expected_self_hashes[i * 32..(i+1) * 32]。
///
/// Inputs (same layout as `bas_ranker_ledger_seal_batch`):
///
///   - `initial_32`         : 32-byte prior anchor
///   - `canonicals_buf`     : N records, length-prefixed
///   - `canonicals_buf_len` : flat-buffer byte length
///   - `expected_self_hashes_n_x_32` : N*32 expected digests
///   - `n`                  : number of records
///   - `out_tip_32`         : 32-byte tip-hash output on success
///
/// Returns:
///   - 0       on full chain valid (tip written to out_tip)
///   - 1 + i   if record i's selfHash mismatches
///             (1 << 30 maps i too large to distinguish from
///             -1/-2 — callers should treat any positive
///             return as fail-at-index = return - 1)
///   - -1      on null pointer
///   - -2      on truncated canonicals_buf
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_ledger_verify_chain(
    initial_32: *const u8,
    canonicals_buf: *const u8,
    canonicals_buf_len: usize,
    expected_self_hashes_n_x_32: *const u8,
    n: usize,
    out_tip_32: *mut u8,
) -> i32 {
    if initial_32.is_null() || out_tip_32.is_null() {
        return -1;
    }
    if n == 0 {
        // Empty chain — tip = initial。 Array pointers may be
        // null since they're unused。
        let init_slice = unsafe {
            core::slice::from_raw_parts(initial_32, 32)
        };
        unsafe {
            core::ptr::copy_nonoverlapping(
                init_slice.as_ptr(), out_tip_32, 32);
        }
        return 0;
    }
    if canonicals_buf.is_null() || canonicals_buf_len == 0
        || expected_self_hashes_n_x_32.is_null()
    {
        return -1;
    }
    let buf = unsafe {
        core::slice::from_raw_parts(
            canonicals_buf, canonicals_buf_len)
    };
    let canonicals = match decode_length_prefixed(buf, n) {
        Some(v) => v,
        None => return -2,
    };
    let expected_flat = unsafe {
        core::slice::from_raw_parts(
            expected_self_hashes_n_x_32, n * 32)
    };
    let mut expected: Vec<[u8; 32]> =
        Vec::with_capacity(n);
    for i in 0..n {
        let mut h = [0u8; 32];
        h.copy_from_slice(
            &expected_flat[i * 32..(i + 1) * 32]);
        expected.push(h);
    }
    let mut initial = [0u8; 32];
    initial.copy_from_slice(unsafe {
        core::slice::from_raw_parts(initial_32, 32)
    });
    match ledger::verify_chain_pure(
        &initial, &canonicals, &expected)
    {
        ledger::ChainVerifyOutcome::Ok { tip_hash } => {
            unsafe {
                core::ptr::copy_nonoverlapping(
                    tip_hash.as_ptr(), out_tip_32, 32);
            }
            0
        }
        ledger::ChainVerifyOutcome::SelfHashMismatch {
            index } => (index as i32) + 1,
    }
}

/// Helper:decode a length-prefixed flat buffer into `n` slice
/// references。 Returns None if the size prefixes don't consume
/// exactly `buf.len()` bytes for `n` records。
fn decode_length_prefixed<'a>(
    buf: &'a [u8], n: usize,
) -> Option<Vec<&'a [u8]>> {
    let mut out: Vec<&'a [u8]> = Vec::with_capacity(n);
    let mut offset: usize = 0;
    for _ in 0..n {
        if offset + 4 > buf.len() { return None; }
        let len_be: [u8; 4] = buf[offset..offset + 4]
            .try_into().ok()?;
        let payload_len = u32::from_be_bytes(len_be)
            as usize;
        offset += 4;
        if offset + payload_len > buf.len() {
            return None;
        }
        out.push(&buf[offset..offset + payload_len]);
        offset += payload_len;
    }
    if offset != buf.len() { return None; }
    Some(out)
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
