// SPDX:internal
//
// bas-dream-loop — chapter 七百四十八 第一刀 / M2411
//
// LAYER-MIGRATION ARC L9 Dream Loop batch-scoring kernel。
// Per user directive 「candidate simulation、future
// projection、batch scoring 适合 Rust/Metal。」
//
// Hot path:given a query Float32 vector + a corpus of N
// candidate Float32 vectors,compute a score for each
// candidate (cosine similarity + benefit-cost trade) and
// return the top-K scoring indices。 Mirror of chapter
// 七百十五 batched-cosine SIMD pattern,extended with the
// L9 benefit/cost trade-off math。
//
// ## Score formula (mirror of Swift BASDreamLoopRunner)
//
//   raw_cosine[i] = dot(query, cand[i]) /
//                   (norm(query) * norm(cand[i]))
//   benefit_cost[i] = expected_benefit[i] -
//                     expected_cost[i]
//   composite[i] = 0.6 * raw_cosine[i] + 0.4 * benefit_cost[i]
//
// Top-K returned as the K indices with the highest composite
// score (descending),no allocation other than the output
// Vec<i32>。

#![forbid(unsafe_op_in_unsafe_fn)]

use std::os::raw::c_char;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_dream_loop_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Score formula

/// Mirror of Swift BASDreamLoopRunner composite score
/// weights。 0.6 cosine + 0.4 benefit-cost。
pub const COSINE_WEIGHT: f64 = 0.6;
pub const BENEFIT_COST_WEIGHT: f64 = 0.4;

fn cosine_similarity(
    query: &[f32], candidate: &[f32],
) -> f32 {
    let mut dot: f32 = 0.0;
    let mut qn: f32 = 0.0;
    let mut cn: f32 = 0.0;
    for i in 0..query.len().min(candidate.len()) {
        dot += query[i] * candidate[i];
        qn += query[i] * query[i];
        cn += candidate[i] * candidate[i];
    }
    if qn == 0.0 || cn == 0.0 { return 0.0; }
    dot / (qn.sqrt() * cn.sqrt())
}

/// Score one candidate against the query。 Pure function。
pub fn score_candidate(
    query: &[f32],
    candidate: &[f32],
    expected_benefit: f64,
    expected_cost: f64,
) -> f64 {
    let cos = cosine_similarity(query, candidate) as f64;
    let bc = expected_benefit - expected_cost;
    COSINE_WEIGHT * cos + BENEFIT_COST_WEIGHT * bc
}

/// Batch-score N candidates against the query。 Returns the
/// top-K candidate INDICES (descending by composite score)。
/// O(N + K log K) for stable selection。
pub fn batch_score_top_k(
    query: &[f32],
    candidates: &[Vec<f32>],
    benefits: &[f64],
    costs: &[f64],
    k: usize,
) -> Vec<i32> {
    let n = candidates.len().min(benefits.len())
        .min(costs.len());
    let mut scores: Vec<(i32, f64)> = (0..n).map(|i| {
        let s = score_candidate(
            query, &candidates[i],
            benefits[i], costs[i]);
        (i as i32, s)
    }).collect();
    // Sort descending by score;stable to keep
    // earlier indices on ties
    scores.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let limit = k.min(scores.len());
    scores.into_iter().take(limit)
        .map(|(idx, _)| idx)
        .collect()
}

// MARK: - C ABI

/// Batch-score top-K candidates via C ABI。
///
/// Inputs:
///   query_ptr/query_dim:        Float32 query vector
///   candidates_flat_ptr:         Float32 candidates,
///                                row-major,N rows of dim
///                                elements each
///   candidate_count:             N
///   benefits_ptr/costs_ptr:      f64 arrays of length N
///   k:                           top-K to return
///   out_indices_ptr/out_cap:     output i32 buffer (caller-
///                                allocated,must hold ≥ K)
///
/// Returns:number of indices written (min(K, N)) or
///         -1 on null pointer / bad shape
#[no_mangle]
pub unsafe extern "C" fn bas_dream_loop_batch_score(
    query_ptr: *const f32, query_dim: i32,
    candidates_flat_ptr: *const f32,
    candidate_count: i32,
    benefits_ptr: *const f64,
    costs_ptr: *const f64,
    k: i32,
    out_indices_ptr: *mut i32,
    out_capacity: i32,
) -> i32 {
    if query_ptr.is_null()
        || candidates_flat_ptr.is_null()
        || benefits_ptr.is_null()
        || costs_ptr.is_null()
        || out_indices_ptr.is_null()
        || query_dim <= 0
        || candidate_count < 0
        || k < 0
        || out_capacity < k
    {
        return -1;
    }
    let n = candidate_count as usize;
    let dim = query_dim as usize;
    // SAFETY: caller pins all ptr/len pairs per FFI contract
    let query_slice = unsafe {
        std::slice::from_raw_parts(query_ptr, dim)
    };
    let cands_flat = unsafe {
        std::slice::from_raw_parts(
            candidates_flat_ptr, n * dim)
    };
    let benefits = unsafe {
        std::slice::from_raw_parts(benefits_ptr, n)
    };
    let costs = unsafe {
        std::slice::from_raw_parts(costs_ptr, n)
    };
    // Materialize per-candidate slices
    let candidates: Vec<Vec<f32>> = (0..n).map(|i| {
        cands_flat[i * dim..(i + 1) * dim].to_vec()
    }).collect();
    let result = batch_score_top_k(
        query_slice, &candidates,
        benefits, costs, k as usize);
    let count = result.len() as i32;
    // SAFETY: out_indices_ptr has capacity ≥ k per the
    // check above + the result has at most k elements
    unsafe {
        for (i, idx) in result.iter().enumerate() {
            *out_indices_ptr.add(i) = *idx;
        }
    }
    count
}

// MARK: - L9 dominance ordering (chapter 八百三十五 / M2826)
//
// Companion to batch_score_top_k: given a flat array of per-
// candidate dominance scores, return the indices sorted in
// DESCENDING order (highest score first)。 This mirrors the
// Swift `buildCandidateFrontier.dominanceOrder` computation
// pattern in BASHostKit (EBrainRuntimeCoordinator+Candidates.swift)
// which sorts candidates by `candidateDominanceScore` and emits
// the resulting candidateID list。
//
// Why a separate primitive (not part of batch_score):
//   - `batch_score_top_k` returns top-K (truncated)
//   - `dominance_order_indices` returns ALL N indices sorted
//     (full frontier ordering,not truncated)
//   - Swift host code needs the full ordering for frontier
//     composition (dominance order + reversible filter + guard
//     filter all derive from the same input scores)
//
// Determinism:stable sort on (-score, index) so ties resolve
// by input order (matches Swift `.sorted { lhs, rhs in score(lhs)
// > score(rhs) }` behavior for equal-score pairs)。

/// Sort indices [0, n) by `scores[i]` descending, stable on
/// ties。 Pure-fn, no allocation beyond the output Vec。
pub fn dominance_order_indices(scores: &[f32]) -> Vec<i32> {
    let n = scores.len();
    let mut indices: Vec<i32> = (0..n as i32).collect();
    indices.sort_by(|&a, &b| {
        // Descending by score; NaN sorts last (treated as -inf)
        let sa = scores[a as usize];
        let sb = scores[b as usize];
        match sb.partial_cmp(&sa) {
            Some(o) => o,
            None => {
                // Handle NaN:non-NaN < NaN (push NaN to end)
                if sa.is_nan() && !sb.is_nan() {
                    std::cmp::Ordering::Greater
                } else if !sa.is_nan() && sb.is_nan() {
                    std::cmp::Ordering::Less
                } else {
                    std::cmp::Ordering::Equal
                }
            }
        }
    });
    indices
}

/// C ABI:dominance order indices。 Caller supplies `scores`
/// (length n) and an output buffer (length ≥ n)。 Writes the
/// descending-sorted indices to `out_indices`,returns n
/// (number written) or -1 on bad input。
///
/// # Safety
///
/// `scores_ptr` MUST point to a readable Float32 buffer of
/// length ≥ `n`。 `out_indices_ptr` MUST point to a writable
/// Int32 buffer of length ≥ `n`。 Pointer-len pairs are pinned
/// by the FFI contract,not validated here。
#[no_mangle]
pub unsafe extern "C" fn bas_dream_loop_dominance_order(
    scores_ptr: *const f32,
    n: i32,
    out_indices_ptr: *mut i32,
    out_capacity: i32,
) -> i32 {
    if scores_ptr.is_null()
        || out_indices_ptr.is_null()
        || n < 0
        || out_capacity < n
    {
        return -1;
    }
    let len = n as usize;
    let scores = unsafe {
        std::slice::from_raw_parts(scores_ptr, len)
    };
    let result = dominance_order_indices(scores);
    unsafe {
        for (i, idx) in result.iter().enumerate() {
            *out_indices_ptr.add(i) = *idx;
        }
    }
    n
}

// MARK: - Dominance order indices (f64 — chapter 八百四十七)
//
// Same as `dominance_order_indices` but accepts `f64` scores
// to eliminate the Float32 narrowing risk identified by the
// post-八百四十六 strict review。 Swift's `Double` ≡ f64;passing
// the Double directly avoids the precision-loss edge case where
// two distinct Doubles round to the same Float32 and tie under
// the routed path while the V1 Swift `.sorted` would compare
// the full-precision Doubles and order them differently。
//
// Determinism:stable sort on (-score, index),NaN sorts to end。

/// Sort indices [0, n) by `scores[i]` (f64) descending, stable
/// on ties。 Pure-fn, no allocation beyond the output Vec。
pub fn dominance_order_indices_f64(
    scores: &[f64],
) -> Vec<i32> {
    let n = scores.len();
    let mut indices: Vec<i32> = (0..n as i32).collect();
    indices.sort_by(|&a, &b| {
        let sa = scores[a as usize];
        let sb = scores[b as usize];
        match sb.partial_cmp(&sa) {
            Some(o) => o,
            None => {
                // NaN handling mirrors the f32 path
                if sa.is_nan() && !sb.is_nan() {
                    std::cmp::Ordering::Greater
                } else if !sa.is_nan() && sb.is_nan() {
                    std::cmp::Ordering::Less
                } else {
                    std::cmp::Ordering::Equal
                }
            }
        }
    });
    indices
}

/// C ABI:f64-input dominance order indices。
///
/// # Safety
///
/// `scores_ptr` MUST point to a readable Float64 buffer of length
/// ≥ `n`。 `out_indices_ptr` MUST point to a writable Int32 buffer
/// of length ≥ `n`。
#[no_mangle]
pub unsafe extern "C" fn bas_dream_loop_dominance_order_f64(
    scores_ptr: *const f64,
    n: i32,
    out_indices_ptr: *mut i32,
    out_capacity: i32,
) -> i32 {
    if scores_ptr.is_null()
        || out_indices_ptr.is_null()
        || n < 0
        || out_capacity < n
    {
        return -1;
    }
    let len = n as usize;
    let scores = unsafe {
        std::slice::from_raw_parts(scores_ptr, len)
    };
    let result = dominance_order_indices_f64(scores);
    unsafe {
        for (i, idx) in result.iter().enumerate() {
            *out_indices_ptr.add(i) = *idx;
        }
    }
    n
}

// MARK: - Unused c_char import suppression
const _: *const c_char = std::ptr::null();

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    fn make_candidates(n: usize, dim: usize) -> Vec<Vec<f32>> {
        (0..n).map(|i| {
            (0..dim).map(|j| {
                ((i * dim + j) as f32) * 0.01
            }).collect()
        }).collect()
    }

    #[test]
    fn cosine_identical_vectors_yields_one() {
        let a: Vec<f32> = vec![1.0, 2.0, 3.0];
        let b: Vec<f32> = vec![1.0, 2.0, 3.0];
        assert!((cosine_similarity(&a, &b) - 1.0).abs()
            < 1e-6);
    }

    // MARK: - dominance_order_indices tests (chapter 八百三十五)

    #[test]
    fn dominance_order_empty_yields_empty() {
        let result = dominance_order_indices(&[]);
        assert_eq!(result, Vec::<i32>::new());
    }

    #[test]
    fn dominance_order_descending_by_score() {
        let scores = [0.3_f32, 0.9, 0.1, 0.7];
        let result = dominance_order_indices(&scores);
        // 0.9 (idx 1), 0.7 (idx 3), 0.3 (idx 0), 0.1 (idx 2)
        assert_eq!(result, vec![1, 3, 0, 2]);
    }

    #[test]
    fn dominance_order_stable_on_ties() {
        // Ties resolve by input order (stable sort)。 Indices
        // 0, 1, 2 all have score 0.5;they stay in 0, 1, 2 order
        let scores = [0.5_f32, 0.5, 0.5, 0.9];
        let result = dominance_order_indices(&scores);
        assert_eq!(result, vec![3, 0, 1, 2]);
    }

    #[test]
    fn dominance_order_pushes_nan_to_end() {
        let scores = [0.5_f32, f32::NAN, 0.9, f32::NAN];
        let result = dominance_order_indices(&scores);
        // 0.9 (idx 2), 0.5 (idx 0), then NaNs (idx 1, 3 stable)
        assert_eq!(result, vec![2, 0, 1, 3]);
    }

    #[test]
    fn dominance_order_single_element() {
        let scores = [0.42_f32];
        let result = dominance_order_indices(&scores);
        assert_eq!(result, vec![0]);
    }

    #[test]
    fn dominance_order_already_sorted_descending_stays() {
        let scores = [1.0_f32, 0.8, 0.6, 0.4, 0.2];
        let result = dominance_order_indices(&scores);
        assert_eq!(result, vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn dominance_order_ascending_input_reverses() {
        let scores = [0.1_f32, 0.2, 0.3, 0.4, 0.5];
        let result = dominance_order_indices(&scores);
        assert_eq!(result, vec![4, 3, 2, 1, 0]);
    }

    #[test]
    fn dominance_order_c_abi_writes_correct_indices() {
        let scores = vec![0.3_f32, 0.9, 0.1, 0.7];
        let mut out = vec![-1_i32; 4];
        let written = unsafe {
            bas_dream_loop_dominance_order(
                scores.as_ptr(),
                scores.len() as i32,
                out.as_mut_ptr(),
                out.len() as i32)
        };
        assert_eq!(written, 4);
        assert_eq!(out, vec![1, 3, 0, 2]);
    }

    #[test]
    fn dominance_order_c_abi_rejects_too_small_capacity() {
        let scores = vec![0.5_f32; 4];
        let mut out = vec![-1_i32; 2];  // cap < n
        let result = unsafe {
            bas_dream_loop_dominance_order(
                scores.as_ptr(),
                scores.len() as i32,
                out.as_mut_ptr(),
                out.len() as i32)
        };
        assert_eq!(result, -1);
    }

    #[test]
    fn dominance_order_c_abi_rejects_null_ptr() {
        let mut out = vec![-1_i32; 4];
        let result = unsafe {
            bas_dream_loop_dominance_order(
                std::ptr::null(),
                4,
                out.as_mut_ptr(),
                out.len() as i32)
        };
        assert_eq!(result, -1);
    }

    // MARK: - dominance_order_indices_f64 tests (chapter 八百四十七)

    #[test]
    fn dominance_order_f64_empty_yields_empty() {
        let result = dominance_order_indices_f64(&[]);
        assert!(result.is_empty());
    }

    #[test]
    fn dominance_order_f64_descending() {
        let scores = vec![0.1_f64, 0.9, 0.3, 0.7, 0.5];
        let result = dominance_order_indices_f64(&scores);
        assert_eq!(result, vec![1, 3, 4, 2, 0]);
    }

    #[test]
    fn dominance_order_f64_stable_on_ties() {
        let scores = vec![0.5_f64, 0.5, 0.5];
        let result = dominance_order_indices_f64(&scores);
        assert_eq!(result, vec![0, 1, 2]);
    }

    #[test]
    fn dominance_order_f64_pushes_nan_to_end() {
        let scores = vec![0.5_f64, f64::NAN, 0.9, 0.1];
        let result = dominance_order_indices_f64(&scores);
        assert_eq!(&result[..3], &[2_i32, 0, 3]);
        assert_eq!(result[3], 1);
    }

    #[test]
    fn dominance_order_f64_distinguishes_sub_float32_ulp_doubles() {
        // The whole point of the f64 path:two Doubles that
        // round to the same Float32 (and would tie under the
        // f32 path) must be ordered correctly under f64。
        let a = 0.1_f64;
        let b = a + f64::EPSILON;
        // Both round to the same Float32:
        assert_eq!(a as f32, b as f32);
        // But they differ as Doubles → f64 path must order them
        let scores = vec![a, b]; // b > a as Double
        let result = dominance_order_indices_f64(&scores);
        assert_eq!(result, vec![1, 0],
            "Index 1 (larger Double) must come first under f64 path");
    }

    #[test]
    fn dominance_order_f64_c_abi_writes_correct_indices() {
        let scores: Vec<f64> = vec![0.1, 0.9, 0.3, 0.7, 0.5];
        let mut out = vec![-1_i32; 5];
        let written = unsafe {
            bas_dream_loop_dominance_order_f64(
                scores.as_ptr(),
                5,
                out.as_mut_ptr(),
                out.len() as i32)
        };
        assert_eq!(written, 5);
        assert_eq!(out, vec![1, 3, 4, 2, 0]);
    }

    #[test]
    fn dominance_order_f64_c_abi_rejects_null_ptr() {
        let mut out = vec![-1_i32; 4];
        let result = unsafe {
            bas_dream_loop_dominance_order_f64(
                std::ptr::null(),
                4,
                out.as_mut_ptr(),
                out.len() as i32)
        };
        assert_eq!(result, -1);
    }

    #[test]
    fn dominance_order_f64_c_abi_rejects_too_small_capacity() {
        let scores: Vec<f64> = vec![0.1, 0.9];
        let mut out = vec![-1_i32; 1];  // capacity < n
        let result = unsafe {
            bas_dream_loop_dominance_order_f64(
                scores.as_ptr(),
                2,
                out.as_mut_ptr(),
                1)
        };
        assert_eq!(result, -1);
    }

    #[test]
    fn cosine_orthogonal_yields_zero() {
        let a: Vec<f32> = vec![1.0, 0.0];
        let b: Vec<f32> = vec![0.0, 1.0];
        assert!(cosine_similarity(&a, &b).abs() < 1e-6);
    }

    #[test]
    fn score_combines_cosine_and_benefit_cost() {
        let q: Vec<f32> = vec![1.0, 0.0];
        let c: Vec<f32> = vec![1.0, 0.0];
        let s = score_candidate(&q, &c, 1.0, 0.5);
        // 0.6 * 1.0 + 0.4 * 0.5 = 0.8
        assert!((s - 0.8).abs() < 1e-9);
    }

    #[test]
    fn batch_top_k_returns_k_indices() {
        let q: Vec<f32> = vec![1.0, 0.0, 0.0];
        let cands = make_candidates(10, 3);
        let benefits = vec![0.5; 10];
        let costs = vec![0.1; 10];
        let top = batch_score_top_k(
            &q, &cands, &benefits, &costs, 3);
        assert_eq!(top.len(), 3);
    }

    #[test]
    fn batch_top_k_descending_by_score() {
        // Construct candidates where index 5 best matches
        // the query
        let q: Vec<f32> = vec![1.0, 0.0, 0.0];
        let mut cands = make_candidates(10, 3);
        cands[5] = vec![1.0, 0.0, 0.0];  // perfect match
        let mut benefits = vec![0.5; 10];
        benefits[5] = 0.9;  // also higher benefit
        let costs = vec![0.1; 10];
        let top = batch_score_top_k(
            &q, &cands, &benefits, &costs, 3);
        assert_eq!(top[0], 5,
            "index 5 should top the list");
    }

    #[test]
    fn batch_top_k_clamps_to_n() {
        let q: Vec<f32> = vec![1.0];
        let cands = make_candidates(3, 1);
        let benefits = vec![0.5; 3];
        let costs = vec![0.1; 3];
        let top = batch_score_top_k(
            &q, &cands, &benefits, &costs, 10);
        // Only 3 candidates so top is bounded by N
        assert_eq!(top.len(), 3);
    }

    #[test]
    fn batch_top_k_zero_corpus_returns_empty() {
        let q: Vec<f32> = vec![1.0];
        let cands: Vec<Vec<f32>> = vec![];
        let benefits: Vec<f64> = vec![];
        let costs: Vec<f64> = vec![];
        let top = batch_score_top_k(
            &q, &cands, &benefits, &costs, 5);
        assert!(top.is_empty());
    }

    #[test]
    fn batch_top_k_determinism() {
        let q: Vec<f32> = vec![1.0, 0.0, 0.0];
        let cands = make_candidates(20, 3);
        let benefits = vec![0.5; 20];
        let costs = vec![0.1; 20];
        let a = batch_score_top_k(
            &q, &cands, &benefits, &costs, 5);
        let b = batch_score_top_k(
            &q, &cands, &benefits, &costs, 5);
        assert_eq!(a, b);
    }

    // MARK: - C ABI

    #[test]
    fn c_abi_batch_score_basic() {
        let query: Vec<f32> = vec![1.0, 0.0, 0.0];
        let cands_flat: Vec<f32> = vec![
            1.0, 0.0, 0.0,  // idx 0 — perfect match
            0.0, 1.0, 0.0,  // idx 1 — orthogonal
            0.5, 0.5, 0.0,  // idx 2 — partial
        ];
        let benefits: Vec<f64> = vec![0.5, 0.5, 0.5];
        let costs: Vec<f64> = vec![0.1, 0.1, 0.1];
        let mut out = vec![-1_i32; 3];
        let written = unsafe {
            bas_dream_loop_batch_score(
                query.as_ptr(), 3,
                cands_flat.as_ptr(), 3,
                benefits.as_ptr(),
                costs.as_ptr(),
                3,
                out.as_mut_ptr(), 3)
        };
        assert_eq!(written, 3);
        // Index 0 (perfect cosine match) should top
        assert_eq!(out[0], 0);
    }

    #[test]
    fn c_abi_null_returns_fault() {
        let benefits: Vec<f64> = vec![];
        let costs: Vec<f64> = vec![];
        let mut out: Vec<i32> = vec![0; 3];
        let rc = unsafe {
            bas_dream_loop_batch_score(
                std::ptr::null(), 3,
                std::ptr::null(), 0,
                benefits.as_ptr(),
                costs.as_ptr(),
                3,
                out.as_mut_ptr(), 3)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn c_abi_capacity_below_k_returns_fault() {
        let query: Vec<f32> = vec![1.0];
        let cands: Vec<f32> = vec![1.0];
        let benefits: Vec<f64> = vec![0.5];
        let costs: Vec<f64> = vec![0.1];
        let mut out: Vec<i32> = vec![0; 1];
        let rc = unsafe {
            bas_dream_loop_batch_score(
                query.as_ptr(), 1,
                cands.as_ptr(), 1,
                benefits.as_ptr(),
                costs.as_ptr(),
                3,  // k = 3 but capacity = 1
                out.as_mut_ptr(), 1)
        };
        assert_eq!(rc, -1);
    }
}
