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
pub mod hex;              // chapter 七百十九 第一刀 — lookup-table hex encoder
pub mod hex_decode;       // chapter 七百二十一 第一刀 — lookup-table hex decoder
pub mod importance_scorer; // chapter 七百二十三 第一刀 — memory importance scorer
pub mod aggregations;      // chapter 七百二十五 第一刀 — tracker aggregations
pub mod quantize;          // chapter 七百二十六 第一刀 — int8 quantization
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

// MARK: - chapter 七百十三 第四刀 Forget cascade C ABI

/// Forget-cascade partition。 Both id buffers use the same
/// length-prefixed-utf8 wire format as the ledger ABI:
/// concatenation of `[u32_be len][bytes]` records。
///
/// Inputs:
///   - `record_ids_buf` / `record_ids_buf_len` : N record IDs
///   - `target_ids_buf` / `target_ids_buf_len` : M target IDs
///   - `n_records` / `n_targets` : exact record counts
///   - `out_kept_indices`   : caller-owned `usize`/uintptr_t
///                            buffer of length ≥ n_records
///   - `out_removed_indices`: caller-owned buffer of length
///                            ≥ n_records
///   - `out_kept_count`     : *uintptr_t output:actual kept N
///   - `out_removed_count`  : *uintptr_t output:actual removed N
///
/// Returns:
///   0       — success
///   -1      — null pointer
///   -2      — truncated buffer
#[no_mangle]
pub unsafe extern "C" fn
bas_ranker_forget_cascade_filter(
    record_ids_buf: *const u8,
    record_ids_buf_len: usize,
    n_records: usize,
    target_ids_buf: *const u8,
    target_ids_buf_len: usize,
    n_targets: usize,
    out_kept_indices: *mut usize,
    out_removed_indices: *mut usize,
    out_kept_count: *mut usize,
    out_removed_count: *mut usize,
) -> i32 {
    if out_kept_count.is_null()
        || out_removed_count.is_null()
    {
        return -1;
    }
    // Decode record IDs。 Empty record set is valid (no-op)。
    let record_slice: &[u8] = if n_records == 0 {
        &[]
    } else if record_ids_buf.is_null()
        || record_ids_buf_len == 0
        || out_kept_indices.is_null()
        || out_removed_indices.is_null()
    {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(
                record_ids_buf, record_ids_buf_len)
        }
    };
    let records: Vec<&str> = if n_records == 0 {
        Vec::new()
    } else {
        match decode_length_prefixed(
            record_slice, n_records)
        {
            Some(v) => v.into_iter().map(|b| {
                std::str::from_utf8(b).unwrap_or("")
            }).collect(),
            None => return -2,
        }
    };
    // Decode target IDs。 Empty target set is valid (no-op)。
    let target_slice: &[u8] = if n_targets == 0 {
        &[]
    } else if target_ids_buf.is_null()
        || target_ids_buf_len == 0
    {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(
                target_ids_buf, target_ids_buf_len)
        }
    };
    let targets: Vec<&str> = if n_targets == 0 {
        Vec::new()
    } else {
        match decode_length_prefixed(
            target_slice, n_targets)
        {
            Some(v) => v.into_iter().map(|b| {
                std::str::from_utf8(b).unwrap_or("")
            }).collect(),
            None => return -2,
        }
    };
    let (kept, removed) =
        forget_cascade::forget_cascade_filter_ids(
            &records, &targets);
    if !out_kept_indices.is_null() {
        let kept_slice = unsafe {
            core::slice::from_raw_parts_mut(
                out_kept_indices, kept.len())
        };
        kept_slice.copy_from_slice(&kept);
    }
    if !out_removed_indices.is_null() {
        let rem_slice = unsafe {
            core::slice::from_raw_parts_mut(
                out_removed_indices, removed.len())
        };
        rem_slice.copy_from_slice(&removed);
    }
    unsafe {
        *out_kept_count = kept.len();
        *out_removed_count = removed.len();
    }
    0
}

// MARK: - chapter 七百二十一 第一刀 Hex decoder C ABI

/// Decode `n_hex_chars` of hex ASCII input (`hex`) into the
/// caller-owned `out` buffer of size `n_hex_chars / 2` bytes。
///
/// Returns:
///   - bytes-written count (≥ 0) on success
///   - -1 on null pointer
///   - -2 on odd hex_len
///   - -3 on non-hex character
///   - -4 on out_len < n_hex_chars / 2
///
/// ~40-60× faster than Swift's
/// `[UInt8](hex.chunks().map { UInt8($0, radix: 16)! })` per
/// chapter 七百二十一 第二刀 measurement。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_hex_to_bytes(
    hex: *const u8, n_hex_chars: usize,
    out: *mut u8, out_len: usize,
) -> i64 {
    if out.is_null() { return -1; }
    if n_hex_chars == 0 {
        return 0;
    }
    if hex.is_null() { return -1; }
    if n_hex_chars % 2 != 0 { return -2; }
    let need = n_hex_chars / 2;
    if out_len < need { return -4; }
    let hex_slice = unsafe {
        core::slice::from_raw_parts(hex, n_hex_chars)
    };
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out, need)
    };
    match hex_decode::bytes_from_hex_into(
        hex_slice, out_slice)
    {
        Some(n) => n as i64,
        None => {
            // Distinguish content vs length error
            for i in 0..n_hex_chars {
                let v = hex_slice[i];
                if !((b'0'..=b'9').contains(&v)
                    || (b'a'..=b'f').contains(&v)
                    || (b'A'..=b'F').contains(&v))
                {
                    return -3;
                }
            }
            -4
        }
    }
}

// MARK: - chapter 七百十九 第一刀 Hex encoder C ABI

/// Encode `n` input bytes as lowercase hex ASCII into a
/// caller-owned `out` buffer of size `2 * n`。 Returns 0 on
/// success,-1 on null pointer,-2 on `out_len != 2 * n`。
///
/// Output is pure ASCII `[0-9a-f]`,no NUL terminator,no
/// allocation。 ~25× faster than Swift's
/// `String(format: "%02x", byte)` loop per chapter 七百十九
/// 第二刀 measurement。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_bytes_to_hex_lower(
    bytes: *const u8, n: usize,
    out: *mut u8, out_len: usize,
) -> i32 {
    if out.is_null() { return -1; }
    if n == 0 {
        return if out_len == 0 { 0 } else { -2 };
    }
    if bytes.is_null() { return -1; }
    if out_len != n * 2 { return -2; }
    let in_slice = unsafe {
        core::slice::from_raw_parts(bytes, n)
    };
    let out_slice = unsafe {
        core::slice::from_raw_parts_mut(out, out_len)
    };
    hex::bytes_to_hex_lower_into(in_slice, out_slice);
    0
}

// MARK: - chapter 七百二十三 第二刀 Importance scorer C ABI
//
// Wire format (BIG-ENDIAN length prefixes — matches the chapter
// 七百二十二 BPE tokenizer wire format precedent):
//
//   records_buf:
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [i64 retrieved_at_ms]
//       [u8 helped_flag]   (0=NotHelped, 1=Helped, 2=Unknown)
//
//   tiers_buf:
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [u8 current_tier] (0=Cold, 1=Warm, 2=Hot)
//
//   tunables_buf:
//     7 × f64 little-endian (host byte order — both Swift and
//     Rust on aarch64 are little-endian)。 Order:
//       promote_threshold,demote_threshold,
//       recency_half_life_seconds,frequency_saturation,
//       tier_decay_hot,tier_decay_warm,tier_decay_cold
//
//   out_scores_buf (caller-allocated):
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [u8 current_tier]
//       [f64 recency][f64 frequency][f64 helped][f64 tier_decay]
//       [f64 total_score]
//       [u8 recommended_tier]
//       [u32 record_count]
//       [i64 computed_at_ms]
//
// Two-phase like BPE encode:first call with `out_capacity=0`
// returns the required size,then caller reallocs + retries。

/// Compute importance scores for `atom_tiers`,scored against
/// `records`。 Output is a length-prefixed serialized byte
/// buffer。
///
/// Returns:
///   ≥ 0 = number of OUTPUT BYTES needed (first-pass discovery
///         OR successful fill)
///   -1  = null pointer
///   -2  = malformed inputs (length-prefix underrun OR invalid
///         enum discriminant)
///
/// # Safety
/// Caller provides readable buffers of declared length。 If
/// `out_capacity > 0`,out_scores_buf must point to ≥
/// out_capacity writable bytes。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_importance_score_all(
    records_buf: *const u8,
    records_len: usize,
    tiers_buf: *const u8,
    tiers_len: usize,
    tunables_buf: *const u8,
    tunables_len: usize,
    now_ms: i64,
    out_scores_buf: *mut u8,
    out_capacity: usize,
) -> i64 {
    // Permit null buffers only when corresponding length is 0
    if (records_buf.is_null() && records_len > 0)
        || (tiers_buf.is_null() && tiers_len > 0)
        || tunables_buf.is_null()
        || tunables_len < 7 * 8
    {
        return -1;
    }
    if out_capacity > 0 && out_scores_buf.is_null() {
        return -1;
    }
    let records_slice = if records_len == 0 {
        &[][..]
    } else {
        unsafe {
            core::slice::from_raw_parts(records_buf, records_len)
        }
    };
    let tiers_slice = if tiers_len == 0 {
        &[][..]
    } else {
        unsafe {
            core::slice::from_raw_parts(tiers_buf, tiers_len)
        }
    };
    let tunables_slice = unsafe {
        core::slice::from_raw_parts(tunables_buf, tunables_len)
    };

    let records = match parse_records(records_slice) {
        Some(r) => r,
        None => return -2,
    };
    let tiers = match parse_tiers(tiers_slice) {
        Some(t) => t,
        None => return -2,
    };
    let tunables = parse_tunables(tunables_slice);

    let scores = importance_scorer::score_all(
        &tiers, &records, now_ms, &tunables);
    let serialized = serialize_scores(&scores);

    let needed = serialized.len();
    if out_capacity > 0 && needed > 0 {
        let copy_n = core::cmp::min(needed, out_capacity);
        let dst = unsafe {
            core::slice::from_raw_parts_mut(
                out_scores_buf, copy_n)
        };
        dst.copy_from_slice(&serialized[..copy_n]);
    }
    needed as i64
}

// Internal wire-format parsers --------------------------------

fn read_u32_be(buf: &[u8], pos: usize) -> Option<u32> {
    if pos + 4 > buf.len() { return None; }
    Some(u32::from_be_bytes([
        buf[pos], buf[pos+1], buf[pos+2], buf[pos+3]]))
}

fn read_i64_be(buf: &[u8], pos: usize) -> Option<i64> {
    if pos + 8 > buf.len() { return None; }
    Some(i64::from_be_bytes([
        buf[pos],   buf[pos+1], buf[pos+2], buf[pos+3],
        buf[pos+4], buf[pos+5], buf[pos+6], buf[pos+7]]))
}

fn read_f64_le(buf: &[u8], pos: usize) -> Option<f64> {
    if pos + 8 > buf.len() { return None; }
    Some(f64::from_le_bytes([
        buf[pos],   buf[pos+1], buf[pos+2], buf[pos+3],
        buf[pos+4], buf[pos+5], buf[pos+6], buf[pos+7]]))
}

fn parse_records(
    buf: &[u8],
) -> Option<Vec<importance_scorer::UsageRecord>> {
    if buf.is_empty() { return Some(Vec::new()); }
    let count = read_u32_be(buf, 0)? as usize;
    let mut pos = 4;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        let id_len = read_u32_be(buf, pos)? as usize;
        pos += 4;
        if pos + id_len > buf.len() { return None; }
        let atom_id = core::str::from_utf8(
            &buf[pos..pos + id_len]).ok()?.to_string();
        pos += id_len;
        let retrieved = read_i64_be(buf, pos)?;
        pos += 8;
        if pos + 1 > buf.len() { return None; }
        let flag = importance_scorer::HelpedFlag
            ::from_u8(buf[pos])?;
        pos += 1;
        out.push(importance_scorer::UsageRecord {
            atom_id,
            retrieved_at_ms: retrieved,
            helped_flag: flag,
        });
    }
    Some(out)
}

fn parse_tiers(
    buf: &[u8],
) -> Option<Vec<(String, importance_scorer::Tier)>> {
    if buf.is_empty() { return Some(Vec::new()); }
    let count = read_u32_be(buf, 0)? as usize;
    let mut pos = 4;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        let id_len = read_u32_be(buf, pos)? as usize;
        pos += 4;
        if pos + id_len > buf.len() { return None; }
        let atom_id = core::str::from_utf8(
            &buf[pos..pos + id_len]).ok()?.to_string();
        pos += id_len;
        if pos + 1 > buf.len() { return None; }
        let tier = importance_scorer::Tier
            ::from_u8(buf[pos])?;
        pos += 1;
        out.push((atom_id, tier));
    }
    Some(out)
}

fn parse_tunables(buf: &[u8]) -> importance_scorer::Tunables {
    importance_scorer::Tunables {
        promote_threshold:        read_f64_le(buf,  0).unwrap_or(0.65),
        demote_threshold:         read_f64_le(buf,  8).unwrap_or(0.20),
        recency_half_life_seconds: read_f64_le(buf, 16).unwrap_or(86400.0),
        frequency_saturation:     read_f64_le(buf, 24).unwrap_or(50.0),
        tier_decay_hot:           read_f64_le(buf, 32).unwrap_or(1.0),
        tier_decay_warm:          read_f64_le(buf, 40).unwrap_or(0.7),
        tier_decay_cold:          read_f64_le(buf, 48).unwrap_or(0.4),
    }
}

fn serialize_scores(
    scores: &[importance_scorer::ImportanceScore],
) -> Vec<u8> {
    // Estimate capacity: 4 (count) + per-score: 4 + atom_len + 1
    // + 5 × 8 + 1 + 4 + 8 = ~70 + atom_len。 Reserve 80 per score
    // to amortize growth。
    let mut out: Vec<u8> = Vec::with_capacity(
        4 + scores.len() * 80);
    out.extend_from_slice(
        &(scores.len() as u32).to_be_bytes());
    for s in scores {
        let id_bytes = s.atom_id.as_bytes();
        out.extend_from_slice(
            &(id_bytes.len() as u32).to_be_bytes());
        out.extend_from_slice(id_bytes);
        out.push(s.current_tier.as_u8());
        out.extend_from_slice(
            &s.recency_component.to_le_bytes());
        out.extend_from_slice(
            &s.frequency_component.to_le_bytes());
        out.extend_from_slice(
            &s.helped_component.to_le_bytes());
        out.extend_from_slice(
            &s.tier_decay_component.to_le_bytes());
        out.extend_from_slice(
            &s.total_score.to_le_bytes());
        out.push(s.recommended_tier.as_u8());
        out.extend_from_slice(
            &(s.record_count as u32).to_be_bytes());
        out.extend_from_slice(
            &s.computed_at_ms.to_be_bytes());
    }
    out
}

// MARK: - chapter 七百二十五 第二刀 Aggregation C ABI
//
// Reuses the chapter 七百二十三 records wire format (BIG-ENDIAN
// length prefixes)。 Mirrors `usage_count_for_atom`'s O(N) scan
// over the same record list shape:
//
//   records_buf:
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [i64 retrieved_at_ms]
//       [u8 helped_flag]

/// Count records whose `atom_id` matches the caller-supplied
/// `atom_id`。
///
/// Returns:
///   ≥ 0 = matching record count
///   -1  = null pointer (with non-zero length)
///   -2  = malformed records wire format
///
/// # Safety
/// Caller provides readable buffers of declared lengths。
#[no_mangle]
pub unsafe extern "C" fn bas_ranker_usage_count_for_atom(
    records_buf: *const u8,
    records_len: usize,
    atom_id_buf: *const u8,
    atom_id_len: usize,
) -> i64 {
    if records_buf.is_null() && records_len > 0 {
        return -1;
    }
    if atom_id_buf.is_null() && atom_id_len > 0 {
        return -1;
    }
    let records_slice = if records_len == 0 {
        &[][..]
    } else {
        unsafe {
            core::slice::from_raw_parts(
                records_buf, records_len)
        }
    };
    let atom_id_slice = if atom_id_len == 0 {
        &[][..]
    } else {
        unsafe {
            core::slice::from_raw_parts(
                atom_id_buf, atom_id_len)
        }
    };
    let records = match parse_records(records_slice) {
        Some(r) => r,
        None => return -2,
    };
    let atom_id = match core::str::from_utf8(atom_id_slice) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    aggregations::usage_count_for_atom(
        &records, atom_id) as i64
}

// MARK: - chapter 七百十三 第四刀 Provenance filter C ABI

/// Provenance gate for one envelope。 Hash hex strings passed
/// in as raw bytes (caller guarantees UTF-8)。
///
/// Inputs:
///   - `training_corpus_hash_hex` / len  : training-corpus hash
///   - `trained_weights_hash_hex` / len  : trained-weights hash
///   - `tier_ordinal`                    : 0..=3
///                                         (0=Illustrative,
///                                          3=DomainExpertReviewed)
///   - `has_signature_ref`               : 0 or 1
///   - `has_issued_at`                   : 0 or 1
///
/// Returns:
///   ≥ 0 — rejection code (see provenance::rejection_code)
///         0 = permitted,1-7 = typed rejection variants
///   -1  — null pointer or bad ordinal
#[no_mangle]
pub unsafe extern "C" fn
bas_ranker_provenance_rejection_code(
    training_corpus_hash_hex: *const u8,
    training_corpus_hash_hex_len: usize,
    trained_weights_hash_hex: *const u8,
    trained_weights_hash_hex_len: usize,
    tier_ordinal: i32,
    has_signature_ref: i32,
    has_issued_at: i32,
) -> i32 {
    if training_corpus_hash_hex.is_null()
        || trained_weights_hash_hex.is_null()
    {
        return -1;
    }
    let tier = match provenance::Tier::from_ordinal(
        tier_ordinal)
    {
        Some(t) => t,
        None => return -1,
    };
    let tc_bytes = unsafe {
        core::slice::from_raw_parts(
            training_corpus_hash_hex,
            training_corpus_hash_hex_len)
    };
    let tw_bytes = unsafe {
        core::slice::from_raw_parts(
            trained_weights_hash_hex,
            trained_weights_hash_hex_len)
    };
    let tc_str = match std::str::from_utf8(tc_bytes) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let tw_str = match std::str::from_utf8(tw_bytes) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let p = provenance::Provenance {
        training_corpus_hash_hex: tc_str,
        trained_weights_hash_hex: tw_str,
        tier,
        has_attestation_signature_ref: has_signature_ref != 0,
        has_attestation_issued_at: has_issued_at != 0,
    };
    let r = provenance::rejection_reason(&p);
    provenance::rejection_code(r.as_ref())
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
