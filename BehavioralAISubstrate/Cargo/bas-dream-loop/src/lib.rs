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
