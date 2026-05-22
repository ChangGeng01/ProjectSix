// SPDX:internal
//
// forget_cascade.rs — chapter 七百十三 第一刀 / M2236
//
// Per architectural matrix「Rust:Memory engine + forget
// cascade」 — substrate-side pure-value executor for the
// L8 forget cascade, ported from Swift `BASMemoryForgetCascadeRunner`。
//
// ## What it does
//
// Given:
//   - `record_ids[N]`         : current memory-field record IDs
//   - `target_ids[M]`         : cascade rootTargets ∪ dependentRefs
//
// Returns:
//   - `kept_indices[]`        : indices into record_ids that should
//                               be retained (target_ids ∌ record)
//   - `removed_indices[]`     : indices that should be deleted
//                               (target_ids ∋ record), in insertion
//                               order
//
// ## Why indices,not records
//
// Memory records carry many fields beyond `memoryID`。 Serializing
// them across FFI would pay Codable cost twice。 Index-only ABI
// lets Swift do the actual record-array partition on its side,
// using the indices Rust returns。 Hot path stays pure-string-
// hashing in Rust。
//
// ## Determinism
//
// The kept/removed orderings preserve the input record-ID
// ordering — that's the audit-replay invariant from the Swift
// runner。 Set lookup is O(1) average via HashSet,linear scan
// over records is O(N)。 Total complexity O(N + M)。

use std::collections::HashSet;

/// Pure-value partition: walk `record_ids` once,classify each
/// by whether it appears in `target_ids`,return the two index
/// lists in input order。
pub fn forget_cascade_filter_ids(
    record_ids: &[&str],
    target_ids: &[&str],
) -> (Vec<usize>, Vec<usize>) {
    // Build target set。 If empty,nothing is removed → kept =
    // 0..N,removed = []。
    let target_set: HashSet<&str> = target_ids
        .iter().copied().collect();
    let mut kept: Vec<usize> = Vec::with_capacity(
        record_ids.len());
    let mut removed: Vec<usize> = Vec::new();
    for (i, id) in record_ids.iter().enumerate() {
        if target_set.contains(id) {
            removed.push(i);
        } else {
            kept.push(i);
        }
    }
    (kept, removed)
}

/// Variant operating on borrowed `String` slices (avoids the
/// `&str` borrow dance when callers already own `Vec<String>`)。
pub fn forget_cascade_filter_strings(
    record_ids: &[String],
    target_ids: &[String],
) -> (Vec<usize>, Vec<usize>) {
    let target_set: HashSet<&str> = target_ids
        .iter().map(|s| s.as_str()).collect();
    let mut kept: Vec<usize> = Vec::with_capacity(
        record_ids.len());
    let mut removed: Vec<usize> = Vec::new();
    for (i, id) in record_ids.iter().enumerate() {
        if target_set.contains(id.as_str()) {
            removed.push(i);
        } else {
            kept.push(i);
        }
    }
    (kept, removed)
}

/// chapter 八百八十五 / M3115 — batched rayon variant for
/// chapter 881 Trigger A experiment。 Processes N cascades in
/// parallel via rayon::par_iter,returning one (kept,removed)
/// tuple per cascade in input order。
///
/// HYPOTHESIS being tested: if batching N cascades amortizes the
/// per-cascade HashSet rebuild cost across multiple workers,Rust
/// might finally beat Swift's native Set<String> per-cascade win
/// established in chapter 881。
///
/// Empty input (no cascades) → empty output。 Each cascade is
/// processed independently — no cross-cascade state sharing。
pub fn forget_cascade_filter_batch_rayon(
    cascades: &[(Vec<String>, Vec<String>)],
) -> Vec<(Vec<usize>, Vec<usize>)> {
    use rayon::prelude::*;
    cascades.par_iter()
        .map(|(records, targets)| {
            forget_cascade_filter_strings(records, targets)
        })
        .collect()
}

/// Sequential batched variant — same shape as
/// `forget_cascade_filter_batch_rayon` but no rayon。 Comparison
/// baseline to isolate rayon overhead from batching gain。
pub fn forget_cascade_filter_batch_sequential(
    cascades: &[(Vec<String>, Vec<String>)],
) -> Vec<(Vec<usize>, Vec<usize>)> {
    cascades.iter()
        .map(|(records, targets)| {
            forget_cascade_filter_strings(records, targets)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Instant;

    /// chapter 八百八十五 / M3115 — batched-cascade Trigger A
    /// experiment。 Measures whether batching N cascades via
    /// rayon amortizes the per-cascade HashSet rebuild enough
    /// to beat Swift's measured 1.5μs per-cascade win at small
    /// shapes (from chapter 881 baseline)。
    ///
    /// Uses #[ignore] so it doesn't run by default — invoke via
    /// `cargo test forget_cascade::tests::bench_batched_vs_per_call
    /// --release -- --ignored --nocapture` to capture data。
    #[test]
    #[ignore]
    fn bench_batched_vs_per_call() {
        let record_count = 100;
        let target_count = 10;
        let make_cascade = || {
            let records: Vec<String> = (0..record_count)
                .map(|i| format!("rec-{}", i))
                .collect();
            let targets: Vec<String> = (0..target_count)
                .map(|i| format!("rec-{}", (i * 7) % record_count))
                .collect();
            (records, targets)
        };
        let batch_sizes = [1usize, 4, 16, 64, 256, 1024];
        let iters = 1000usize;
        println!(
            "\n=== chapter 八百八十五 batched-cascade rayon \
             experiment ===");
        println!(
            "Per-cascade shape: {} records × {} targets",
            record_count, target_count);
        println!(
            "Iterations per batch size: {}", iters);
        for &batch in &batch_sizes {
            let cascades: Vec<_> =
                (0..batch).map(|_| make_cascade()).collect();
            // Warm
            for _ in 0..50 {
                let _ = forget_cascade_filter_batch_rayon(
                    &cascades);
            }
            // Sequential per-call baseline
            let t0 = Instant::now();
            for _ in 0..iters {
                let _ = forget_cascade_filter_batch_sequential(
                    &cascades);
            }
            let seq_ns = t0.elapsed().as_nanos() / iters as u128;
            let seq_per_cascade = seq_ns / batch as u128;
            // Rayon batched
            let t1 = Instant::now();
            for _ in 0..iters {
                let _ = forget_cascade_filter_batch_rayon(
                    &cascades);
            }
            let rayon_ns = t1.elapsed().as_nanos() / iters as u128;
            let rayon_per_cascade = rayon_ns / batch as u128;
            println!(
                "  batch={:5} sequential={:8}ns rayon={:8}ns  \
                 per-cascade seq={:7}ns rayon={:7}ns  \
                 speedup={:.2}×",
                batch, seq_ns, rayon_ns,
                seq_per_cascade, rayon_per_cascade,
                seq_ns as f64 / rayon_ns.max(1) as f64);
        }
    }

    /// Byte-equality:rayon batched MUST produce identical
    /// (kept,removed) per cascade as the sequential batched
    /// variant (order-preserved per cascade since rayon's
    /// collect preserves index)。
    #[test]
    fn batched_rayon_byte_equal_to_sequential() {
        let make_cascade = |seed: usize| {
            let records: Vec<String> = (0..50)
                .map(|i| format!("rec-{}-{}", seed, i))
                .collect();
            let targets: Vec<String> = (0..10)
                .map(|i| format!("rec-{}-{}",
                    seed, (i * 5) % 50))
                .collect();
            (records, targets)
        };
        let cascades: Vec<_> = (0..16)
            .map(make_cascade).collect();
        let seq = forget_cascade_filter_batch_sequential(
            &cascades);
        let par = forget_cascade_filter_batch_rayon(&cascades);
        assert_eq!(seq.len(), par.len());
        for (i, (s, p)) in seq.iter().zip(par.iter())
            .enumerate()
        {
            assert_eq!(s.0, p.0,
                "cascade {} kept indices differ", i);
            assert_eq!(s.1, p.1,
                "cascade {} removed indices differ", i);
        }
    }

    #[test]
    fn empty_targets_keeps_everything() {
        let records = ["a", "b", "c"];
        let targets: [&str; 0] = [];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![0, 1, 2]);
        assert!(removed.is_empty());
    }

    #[test]
    fn empty_records_returns_empty_both() {
        let records: [&str; 0] = [];
        let targets = ["a", "b"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert!(kept.is_empty());
        assert!(removed.is_empty());
    }

    #[test]
    fn single_match_partitions_correctly() {
        let records = ["a", "b", "c"];
        let targets = ["b"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![0, 2]);
        assert_eq!(removed, vec![1]);
    }

    #[test]
    fn multi_match_preserves_insertion_order() {
        let records = ["a", "b", "c", "d", "e"];
        let targets = ["d", "b"]; // out-of-order in cascade
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        // kept = [a, c, e] → indices 0, 2, 4
        assert_eq!(kept, vec![0, 2, 4]);
        // removed should still be in RECORD order (1, 3) not
        // target order (3, 1)
        assert_eq!(removed, vec![1, 3]);
    }

    #[test]
    fn full_remove() {
        let records = ["x", "y", "z"];
        let targets = ["z", "y", "x"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert!(kept.is_empty());
        assert_eq!(removed, vec![0, 1, 2]);
    }

    #[test]
    fn target_not_in_records_is_noop() {
        let records = ["a", "b"];
        let targets = ["nonexistent", "ghost"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![0, 1]);
        assert!(removed.is_empty());
    }

    #[test]
    fn duplicate_records_treated_as_distinct_indices() {
        // Records can have repeat IDs (defensive — Swift side
        // dedups but Rust accepts arbitrary input)。 Every match
        // is removed。
        let records = ["a", "a", "b", "a"];
        let targets = ["a"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![2]);
        assert_eq!(removed, vec![0, 1, 3]);
    }

    #[test]
    fn duplicate_targets_idempotent() {
        let records = ["a", "b", "c"];
        let targets = ["b", "b", "b"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![0, 2]);
        assert_eq!(removed, vec![1]);
    }

    #[test]
    fn filter_strings_matches_filter_ids() {
        let records_str: Vec<String> = vec![
            "a".into(), "b".into(), "c".into()];
        let targets_str: Vec<String> = vec!["b".into()];
        let (kept, removed) = forget_cascade_filter_strings(
            &records_str, &targets_str);
        assert_eq!(kept, vec![0, 2]);
        assert_eq!(removed, vec![1]);
    }

    #[test]
    fn large_set_performance_sanity() {
        // 10_000 records, 100 targets, all hit → linear scan
        // completes well under typical test timeout。
        let records: Vec<String> = (0..10_000)
            .map(|i| format!("id-{}", i)).collect();
        let targets: Vec<String> = (5_000..5_100)
            .map(|i| format!("id-{}", i)).collect();
        let (kept, removed) = forget_cascade_filter_strings(
            &records, &targets);
        assert_eq!(kept.len(), 9_900);
        assert_eq!(removed.len(), 100);
        assert_eq!(removed[0], 5_000);
        assert_eq!(removed[99], 5_099);
    }

    #[test]
    fn unicode_ids_match_byte_for_byte() {
        let records = ["普通-id", "中文-id-2", "ascii-id"];
        let targets = ["中文-id-2"];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![0, 2]);
        assert_eq!(removed, vec![1]);
    }

    #[test]
    fn empty_string_id_is_valid() {
        let records = ["", "a", ""];
        let targets = [""];
        let (kept, removed) =
            forget_cascade_filter_ids(&records, &targets);
        assert_eq!(kept, vec![1]);
        assert_eq!(removed, vec![0, 2]);
    }
}
