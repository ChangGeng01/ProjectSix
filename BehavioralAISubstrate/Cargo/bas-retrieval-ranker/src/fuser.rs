// SPDX:internal
//
// fuser.rs — chapter 七百三 第三刀 / M2173
//
// Multi-signal rank-fusion combinator。 Ports the rank-fuse logic
// from Swift's BASOrchestration retrieval path where multiple
// signals (embedding sim + recency + governance status + etc。)
// combine into one final rank for each candidate。
//
// Two canonical strategies:
//   - Weighted linear:  Σᵢ (wᵢ × scoreᵢ)
//   - Reciprocal Rank Fusion (RRF):  Σᵢ 1 / (k + rankᵢ)
//
// Each strategy returns scores in [0, ∞) (linear) or a small
// positive range (RRF)。 Callers then use `topk` to pick the
// final ranking。

use std::collections::BTreeMap;

/// One candidate's per-signal scores。 The signal index aligns
/// with the weight vector passed to `weighted_linear_fuse`。
#[derive(Clone, Debug)]
pub struct SignalScores<'a> {
    pub candidate_id: &'a str,
    pub scores: Vec<f64>,
}

/// Weighted linear fusion — Σᵢ (wᵢ × scoreᵢ)。 Returns
/// (candidate_id, fused_score) pairs in input order。
pub fn weighted_linear_fuse<'a>(
    candidates: &'a [SignalScores<'a>],
    weights: &[f64],
) -> Vec<(&'a str, f64)> {
    candidates.iter().map(|c| {
        let mut s = 0.0;
        for (i, sc) in c.scores.iter().enumerate() {
            if let Some(w) = weights.get(i) {
                s += w * sc;
            }
        }
        (c.candidate_id, s)
    }).collect()
}

/// Reciprocal Rank Fusion — given multiple ranked lists of
/// candidate_ids,assign each candidate Σᵢ 1 / (k + rankᵢ)。
/// `k` is the RRF smoothing constant (typically 60)。
pub fn reciprocal_rank_fuse(
    rankings: &[&[&str]], k: f64,
) -> Vec<(String, f64)> {
    let mut scores: BTreeMap<String, f64> = BTreeMap::new();
    for ranked in rankings {
        for (rank, candidate) in ranked.iter().enumerate() {
            let s = 1.0 / (k + (rank as f64) + 1.0);
            *scores.entry((*candidate).to_string())
                .or_insert(0.0) += s;
        }
    }
    let mut out: Vec<(String, f64)> =
        scores.into_iter().collect();
    // Sort descending by fused score; ties broken by id
    // ascending (stable, deterministic)。
    out.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
          .unwrap_or(std::cmp::Ordering::Equal)
          .then_with(|| a.0.cmp(&b.0))
    });
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn linear_simple_two_signal() {
        let candidates = vec![
            SignalScores { candidate_id: "a",
                scores: vec![0.8, 0.2] },
            SignalScores { candidate_id: "b",
                scores: vec![0.4, 0.9] },
        ];
        let weights = [0.5, 0.5];
        let fused = weighted_linear_fuse(
            &candidates, &weights);
        assert_eq!(fused.len(), 2);
        assert!(approx_eq(fused[0].1, 0.5, 1e-9));
        assert!(approx_eq(fused[1].1, 0.65, 1e-9));
    }

    #[test]
    fn linear_handles_short_weights() {
        let candidates = vec![
            SignalScores { candidate_id: "a",
                scores: vec![1.0, 1.0, 1.0] },
        ];
        // Only 1 weight provided — extras ignored
        let weights = [0.5];
        let fused = weighted_linear_fuse(
            &candidates, &weights);
        assert!(approx_eq(fused[0].1, 0.5, 1e-9));
    }

    #[test]
    fn linear_handles_empty_candidates() {
        let candidates: Vec<SignalScores> = Vec::new();
        let fused = weighted_linear_fuse(
            &candidates, &[1.0]);
        assert!(fused.is_empty());
    }

    #[test]
    fn rrf_basic() {
        let r1 = ["a", "b", "c"];
        let r2 = ["c", "a", "b"];
        let fused = reciprocal_rank_fuse(
            &[&r1, &r2], 60.0);
        assert_eq!(fused.len(), 3);
        // a: 1/61 + 1/62; c: 1/61 + 1/63; b: 1/62 + 1/63
        // a > c > b
        let a_score = 1.0 / 61.0 + 1.0 / 62.0;
        let c_score = 1.0 / 61.0 + 1.0 / 63.0;
        let b_score = 1.0 / 62.0 + 1.0 / 63.0;
        assert!(a_score > c_score);
        assert!(c_score > b_score);
        assert_eq!(fused[0].0, "a");
        assert_eq!(fused[1].0, "c");
        assert_eq!(fused[2].0, "b");
    }

    #[test]
    fn rrf_empty_rankings() {
        let fused = reciprocal_rank_fuse(&[], 60.0);
        assert!(fused.is_empty());
    }

    #[test]
    fn rrf_handles_single_list() {
        let r = ["x", "y"];
        let fused = reciprocal_rank_fuse(&[&r], 60.0);
        assert_eq!(fused.len(), 2);
        assert_eq!(fused[0].0, "x");
        assert_eq!(fused[1].0, "y");
    }

    #[test]
    fn rrf_tie_broken_by_id() {
        // Both candidates appear at rank 0 in two distinct
        // lists → same fused score → tie broken by id asc。
        let r1 = ["b"];
        let r2 = ["a"];
        let fused = reciprocal_rank_fuse(
            &[&r1, &r2], 60.0);
        // Each has score 1/61; order by id asc means a first。
        assert_eq!(fused[0].0, "a");
        assert_eq!(fused[1].0, "b");
    }
}
