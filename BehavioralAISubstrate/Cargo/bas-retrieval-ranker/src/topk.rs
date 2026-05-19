// SPDX:internal
//
// topk.rs — chapter 七百三 第三刀 / M2173
//
// Top-K selection with stable tie-breaking。 Replaces ad-hoc
// `sorted(by:).prefix(k)` Swift snippets in retrieval paths
// with a single deterministic primitive。

use std::cmp::Ordering;

/// Pick the top `k` candidates by descending score。 Ties are
/// broken by ascending `candidate_id` (lexicographic) so replay
/// determinism holds across runs。
pub fn top_k_by_score<'a>(
    scored: &'a [(&'a str, f64)], k: usize,
) -> Vec<(&'a str, f64)> {
    let mut sorted: Vec<(&'a str, f64)> = scored.to_vec();
    sorted.sort_by(|a, b| {
        b.1.partial_cmp(&a.1).unwrap_or(Ordering::Equal)
            .then_with(|| a.0.cmp(b.0))
    });
    sorted.truncate(k);
    sorted
}

/// Same as `top_k_by_score` but reusing owned String ids
/// (matches the RRF output shape from `fuser::reciprocal_rank_fuse`)。
pub fn top_k_owned(
    scored: &[(String, f64)], k: usize,
) -> Vec<(String, f64)> {
    let mut sorted: Vec<(String, f64)> = scored.to_vec();
    sorted.sort_by(|a, b| {
        b.1.partial_cmp(&a.1).unwrap_or(Ordering::Equal)
            .then_with(|| a.0.cmp(&b.0))
    });
    sorted.truncate(k);
    sorted
}

/// Partition into (top-K, rest)。 Useful for retrieval paths
/// that want to keep the rejected candidates around for audit。
pub fn partition_top_k<'a>(
    scored: &'a [(&'a str, f64)], k: usize,
) -> (Vec<(&'a str, f64)>, Vec<(&'a str, f64)>) {
    let mut sorted: Vec<(&'a str, f64)> = scored.to_vec();
    sorted.sort_by(|a, b| {
        b.1.partial_cmp(&a.1).unwrap_or(Ordering::Equal)
            .then_with(|| a.0.cmp(b.0))
    });
    let len = sorted.len();
    let k = k.min(len);
    let rest = sorted.split_off(k);
    (sorted, rest)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn top_k_descending_score() {
        let scored = [
            ("a", 0.5_f64),
            ("b", 0.9),
            ("c", 0.7),
            ("d", 0.1),
        ];
        let top = top_k_by_score(&scored, 2);
        assert_eq!(top.len(), 2);
        assert_eq!(top[0].0, "b");
        assert_eq!(top[1].0, "c");
    }

    #[test]
    fn top_k_handles_k_larger_than_input() {
        let scored = [("a", 0.5_f64), ("b", 0.7)];
        let top = top_k_by_score(&scored, 100);
        assert_eq!(top.len(), 2);
    }

    #[test]
    fn top_k_zero_returns_empty() {
        let scored = [("a", 0.5_f64), ("b", 0.7)];
        let top = top_k_by_score(&scored, 0);
        assert!(top.is_empty());
    }

    #[test]
    fn ties_broken_by_id_ascending() {
        let scored = [
            ("zebra", 0.5_f64),
            ("apple", 0.5),
            ("mango", 0.5),
        ];
        let top = top_k_by_score(&scored, 3);
        assert_eq!(top[0].0, "apple");
        assert_eq!(top[1].0, "mango");
        assert_eq!(top[2].0, "zebra");
    }

    #[test]
    fn partition_top_k_split() {
        let scored = [
            ("a", 0.5_f64),
            ("b", 0.9),
            ("c", 0.7),
            ("d", 0.1),
        ];
        let (top, rest) = partition_top_k(&scored, 2);
        assert_eq!(top.len(), 2);
        assert_eq!(rest.len(), 2);
        assert_eq!(top[0].0, "b");
        assert_eq!(top[1].0, "c");
        // rest sorted descending too — a (0.5) then d (0.1)
        assert_eq!(rest[0].0, "a");
        assert_eq!(rest[1].0, "d");
    }

    #[test]
    fn top_k_owned_matches_borrowed() {
        let scored_borrowed = [
            ("a", 0.5_f64), ("b", 0.9), ("c", 0.7)];
        let scored_owned: Vec<(String, f64)> =
            scored_borrowed.iter()
            .map(|(s, v)| (s.to_string(), *v))
            .collect();
        let top_b = top_k_by_score(
            &scored_borrowed, 2);
        let top_o = top_k_owned(&scored_owned, 2);
        assert_eq!(top_b.len(), 2);
        assert_eq!(top_o.len(), 2);
        assert_eq!(top_b[0].0, top_o[0].0.as_str());
        assert_eq!(top_b[1].0, top_o[1].0.as_str());
    }

    #[test]
    fn partition_handles_k_larger_than_input() {
        let scored = [("a", 0.5_f64)];
        let (top, rest) = partition_top_k(&scored, 100);
        assert_eq!(top.len(), 1);
        assert!(rest.is_empty());
    }

    #[test]
    fn partition_k_zero() {
        let scored = [("a", 0.5_f64), ("b", 0.7)];
        let (top, rest) = partition_top_k(&scored, 0);
        assert!(top.is_empty());
        assert_eq!(rest.len(), 2);
    }
}
