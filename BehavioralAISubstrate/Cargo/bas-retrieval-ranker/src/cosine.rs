// SPDX:internal
//
// cosine.rs — chapter 七百三 第三刀 / M2173
//
// Cosine similarity primitives ported from Swift's BASCognitiveBrain
// .cosineSimilarity surface。 Pure functions,no shared state,no
// allocator pressure (operates on caller-owned slices)。

/// Compute the L2 norm of a vector。 Returns 0 for an empty vector。
pub fn l2_norm(v: &[f32]) -> f32 {
    let mut sum_sq = 0.0_f32;
    for x in v {
        sum_sq += x * x;
    }
    sum_sq.sqrt()
}

/// Compute the dot product of two equal-length vectors。 Returns 0
/// if lengths differ。
pub fn dot(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() {
        return 0.0;
    }
    let mut s = 0.0_f32;
    for i in 0..a.len() {
        s += a[i] * b[i];
    }
    s
}

/// Cosine similarity in [-1, 1]。 Returns 0 if either vector is
/// zero-norm or lengths differ。
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let na = l2_norm(a);
    let nb = l2_norm(b);
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    dot(a, b) / (na * nb)
}

/// Cosine distance = 1 - cosine_similarity。 Bounded in [0, 2]。
pub fn cosine_distance(a: &[f32], b: &[f32]) -> f32 {
    1.0 - cosine_similarity(a, b)
}

/// Batched cosine — pairwise similarity of `query` against each
/// row of `corpus`。 Each row of `corpus` is `dim`-long, packed
/// row-major。 Returns one f32 per corpus row。
pub fn batched_cosine(
    query: &[f32], corpus: &[f32], dim: usize,
) -> Vec<f32> {
    if dim == 0 || corpus.is_empty() || query.len() != dim {
        return Vec::new();
    }
    let rows = corpus.len() / dim;
    let mut out = Vec::with_capacity(rows);
    let q_norm = l2_norm(query);
    if q_norm == 0.0 {
        out.resize(rows, 0.0);
        return out;
    }
    for r in 0..rows {
        let start = r * dim;
        let row = &corpus[start..start + dim];
        let rn = l2_norm(row);
        if rn == 0.0 {
            out.push(0.0);
            continue;
        }
        let mut s = 0.0_f32;
        for i in 0..dim {
            s += query[i] * row[i];
        }
        out.push(s / (q_norm * rn));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn l2_norm_basic() {
        assert!(approx_eq(l2_norm(&[3.0, 4.0]), 5.0, 1e-6));
        assert_eq!(l2_norm(&[]), 0.0);
        assert_eq!(l2_norm(&[0.0, 0.0]), 0.0);
    }

    #[test]
    fn dot_basic() {
        assert!(approx_eq(dot(&[1.0, 2.0, 3.0],
                              &[4.0, 5.0, 6.0]), 32.0, 1e-6));
    }

    #[test]
    fn dot_mismatched_lengths_returns_zero() {
        assert_eq!(dot(&[1.0, 2.0], &[1.0]), 0.0);
    }

    #[test]
    fn cosine_self_equals_one() {
        let v = [1.0_f32, 2.0, 3.0, 4.0];
        assert!(approx_eq(
            cosine_similarity(&v, &v), 1.0, 1e-6));
    }

    #[test]
    fn cosine_orthogonal_equals_zero() {
        let a = [1.0_f32, 0.0];
        let b = [0.0_f32, 1.0];
        assert!(approx_eq(
            cosine_similarity(&a, &b), 0.0, 1e-6));
    }

    #[test]
    fn cosine_opposite_equals_minus_one() {
        let a = [1.0_f32, 0.0];
        let b = [-1.0_f32, 0.0];
        assert!(approx_eq(
            cosine_similarity(&a, &b), -1.0, 1e-6));
    }

    #[test]
    fn cosine_zero_vector_returns_zero() {
        let a = [0.0_f32, 0.0];
        let b = [1.0_f32, 2.0];
        assert_eq!(cosine_similarity(&a, &b), 0.0);
    }

    #[test]
    fn cosine_mismatched_lengths_returns_zero() {
        assert_eq!(
            cosine_similarity(&[1.0_f32], &[1.0, 2.0]), 0.0);
    }

    #[test]
    fn cosine_distance_complement() {
        let a = [1.0_f32, 0.0];
        let b = [1.0_f32, 0.0];
        assert!(approx_eq(
            cosine_distance(&a, &b), 0.0, 1e-6));
        let c = [0.0_f32, 1.0];
        assert!(approx_eq(
            cosine_distance(&a, &c), 1.0, 1e-6));
    }

    #[test]
    fn batched_cosine_shape() {
        // 3 rows of dim 2
        let corpus = [
            1.0_f32, 0.0,  // row 0
            0.0,     1.0,  // row 1
            1.0,     1.0,  // row 2
        ];
        let query = [1.0_f32, 0.0];
        let scores = batched_cosine(&query, &corpus, 2);
        assert_eq!(scores.len(), 3);
        assert!(approx_eq(scores[0], 1.0, 1e-6));
        assert!(approx_eq(scores[1], 0.0, 1e-6));
        // row 2 is [1,1] normalized → [1/sqrt(2), 1/sqrt(2)],
        // dot with [1,0] = 1/sqrt(2) ≈ 0.7071
        assert!(approx_eq(scores[2], 0.7071068, 1e-5));
    }

    #[test]
    fn batched_cosine_empty_corpus() {
        let scores = batched_cosine(&[1.0_f32], &[], 1);
        assert!(scores.is_empty());
    }

    #[test]
    fn batched_cosine_zero_norm_query() {
        let corpus = [1.0_f32, 0.0, 0.0, 1.0];
        let scores = batched_cosine(
            &[0.0_f32, 0.0], &corpus, 2);
        assert_eq!(scores.len(), 2);
        assert_eq!(scores[0], 0.0);
        assert_eq!(scores[1], 0.0);
    }

    #[test]
    fn batched_cosine_handles_zero_row() {
        let corpus = [0.0_f32, 0.0, 1.0, 1.0];
        let scores = batched_cosine(
            &[1.0_f32, 0.0], &corpus, 2);
        assert_eq!(scores.len(), 2);
        assert_eq!(scores[0], 0.0); // zero-norm row
        // row 1 = [1,1] → cosine with [1,0] = 1/sqrt(2)
        assert!(approx_eq(scores[1], 0.7071068, 1e-5));
    }
}
