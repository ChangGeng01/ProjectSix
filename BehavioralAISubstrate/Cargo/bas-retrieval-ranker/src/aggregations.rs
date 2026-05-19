// SPDX:internal
//
// aggregations.rs — chapter 七百二十五 第一刀 / M2296
//
// Rust port of BASMemoryUsageTracker in-memory aggregation hot
// paths。 Tier A from chapter 七百十七 audit。
//
// Public surface:
//   - usage_count_for_atom(records, atom_id) -> usize
//   - recent_records_for_atom(records, atom_id, limit) -> Vec<&Record>
//   - distinct_atom_ids(records) -> Vec<String>
//
// Plan-agent honest reality check (mirrors chapter 七百二十三
// importance_scorer outcome):
//   - These are O(N) linear scans on the record list。 Swift's
//     `inMemory.values.filter { ... }` does the same thing。
//   - The Rust port wins ONLY if the FFI overhead (serialize +
//     parse) is lower than the Swift filter wall time。
//   - At small N (~100 records) the FFI overhead will likely
//     dominate → Rust LOSES。 Chapter 七百二十三 第三刀 confirmed
//     this pattern for importance_scorer at 100/1K/10K cells。
//   - At very large N (≥10K records) Rust MAY win because
//     tight iteration + branch-predictor-friendly loops compile
//     better than Swift's protocol-dispatch filter chain。
//
// The chapter ships the capability + measurement + honest
// decision (per chapter 七百十七 pattern)。

use crate::importance_scorer::UsageRecord;

/// Count records whose `atom_id` matches。 Mirrors Swift
/// `usageCount(forAtomID:)`。
pub fn usage_count_for_atom(
    records: &[UsageRecord],
    atom_id: &str,
) -> usize {
    records
        .iter()
        .filter(|r| r.atom_id == atom_id)
        .count()
}

/// Return up to `limit` most-recent records for `atom_id`,
/// sorted descending by `retrieved_at_ms`。 Mirrors Swift
/// `recentRecords(forAtomID:limit:)`。 Empty input or limit
/// 0 returns empty vec。
pub fn recent_records_for_atom<'a>(
    records: &'a [UsageRecord],
    atom_id: &str,
    limit: usize,
) -> Vec<&'a UsageRecord> {
    if limit == 0 { return Vec::new(); }
    let mut matched: Vec<&UsageRecord> = records
        .iter()
        .filter(|r| r.atom_id == atom_id)
        .collect();
    // Sort descending by retrieved_at_ms。 Stable sort preserves
    // insertion order on ties so Rust + Swift produce same
    // output for byte-equality test。
    matched.sort_by(|a, b|
        b.retrieved_at_ms.cmp(&a.retrieved_at_ms));
    matched.into_iter().take(limit).collect()
}

/// Distinct `atom_id` values。 Mirrors Swift
/// `Set(inMemory.values.map { $0.atomID })`。 Stable order:
/// sorted ascending by `atom_id` for deterministic comparison。
pub fn distinct_atom_ids(
    records: &[UsageRecord],
) -> Vec<String> {
    let mut seen: std::collections::BTreeSet<String> =
        std::collections::BTreeSet::new();
    for r in records {
        seen.insert(r.atom_id.clone());
    }
    seen.into_iter().collect()
}

/// All records sorted ascending by `retrieved_at_ms`,
/// stable on ties。 Mirrors Swift `allRecords()` which uses
/// `sorted { $0.retrievedAt < $1.retrievedAt }`。
pub fn all_records_sorted<'a>(
    records: &'a [UsageRecord],
) -> Vec<&'a UsageRecord> {
    let mut all: Vec<&UsageRecord> =
        records.iter().collect();
    all.sort_by(|a, b|
        a.retrieved_at_ms.cmp(&b.retrieved_at_ms));
    all
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::importance_scorer::HelpedFlag;

    fn rec(atom: &str, t: i64) -> UsageRecord {
        UsageRecord {
            atom_id: atom.to_string(),
            retrieved_at_ms: t,
            helped_flag: HelpedFlag::Helped,
        }
    }

    #[test]
    fn usage_count_filters_by_atom() {
        let recs = vec![
            rec("a", 1), rec("b", 2), rec("a", 3),
            rec("c", 4), rec("a", 5),
        ];
        assert_eq!(usage_count_for_atom(&recs, "a"), 3);
        assert_eq!(usage_count_for_atom(&recs, "b"), 1);
        assert_eq!(usage_count_for_atom(&recs, "z"), 0);
    }

    #[test]
    fn usage_count_empty_returns_zero() {
        let recs: Vec<UsageRecord> = vec![];
        assert_eq!(usage_count_for_atom(&recs, "a"), 0);
    }

    #[test]
    fn recent_records_sorted_descending() {
        let recs = vec![
            rec("a", 100), rec("a", 300), rec("a", 200),
            rec("b", 999),
        ];
        let r = recent_records_for_atom(&recs, "a", 10);
        assert_eq!(r.len(), 3);
        assert_eq!(r[0].retrieved_at_ms, 300);
        assert_eq!(r[1].retrieved_at_ms, 200);
        assert_eq!(r[2].retrieved_at_ms, 100);
    }

    #[test]
    fn recent_records_respects_limit() {
        let recs = vec![
            rec("a", 1), rec("a", 2), rec("a", 3),
            rec("a", 4), rec("a", 5),
        ];
        let r = recent_records_for_atom(&recs, "a", 3);
        assert_eq!(r.len(), 3);
        assert_eq!(r[0].retrieved_at_ms, 5);
        assert_eq!(r[1].retrieved_at_ms, 4);
        assert_eq!(r[2].retrieved_at_ms, 3);
    }

    #[test]
    fn recent_records_zero_limit_returns_empty() {
        let recs = vec![rec("a", 1)];
        let r = recent_records_for_atom(&recs, "a", 0);
        assert!(r.is_empty());
    }

    #[test]
    fn distinct_atom_ids_returns_sorted_unique() {
        let recs = vec![
            rec("zeta", 1), rec("alpha", 2), rec("mu", 3),
            rec("alpha", 4), rec("zeta", 5),
        ];
        let d = distinct_atom_ids(&recs);
        assert_eq!(d, vec!["alpha", "mu", "zeta"]);
    }

    #[test]
    fn distinct_atom_ids_empty_input() {
        let recs: Vec<UsageRecord> = vec![];
        let d = distinct_atom_ids(&recs);
        assert!(d.is_empty());
    }

    #[test]
    fn all_records_sorted_ascending_by_time() {
        let recs = vec![
            rec("a", 300), rec("b", 100), rec("c", 200),
        ];
        let s = all_records_sorted(&recs);
        assert_eq!(s.len(), 3);
        assert_eq!(s[0].retrieved_at_ms, 100);
        assert_eq!(s[1].retrieved_at_ms, 200);
        assert_eq!(s[2].retrieved_at_ms, 300);
    }
}
