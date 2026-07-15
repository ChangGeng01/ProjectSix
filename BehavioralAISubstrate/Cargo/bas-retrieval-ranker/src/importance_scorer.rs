// SPDX:internal
//
// importance_scorer.rs — chapter 七百二十三 第一刀 / M2286
//
// Rust port of Swift `BASMemoryImportanceScorer.scoreAll`。
// Mirrors the Sources/BASMemory/BASMemoryImportanceScorer.swift
// formula byte-for-byte (modulo platform libm)。
//
// ## Algorithm
//
// 1. Bucket records by atomID。
// 2. For each (atomID, currentTier) pair compute:
//      recency   = exp(-age * ln(2) / halfLifeSeconds)
//                  clamped to [0, 1],age in seconds
//      frequency = log10(1 + count) / log10(1 + saturation)
//                  clamped to [0, 1]
//      helped    = (helped_count + 0.5*unknown_count) / total
//                  defaults to 0.5 on empty records
//      tierDecay = constant per tier (hot=1.0, warm=0.7, cold=0.4)
//      total     = pow((rec+ε)(freq+ε)(help+ε)(tier+ε), 0.25)
//                  clamped to [0, 1] (ε = 0.0001)
//    Recommended tier:
//      promote (one step up) if total ≥ promoteThreshold
//      demote (one step down) if total ≤ demoteThreshold
//      hold (current) otherwise
// 3. Sort scores by atomID ascending (stable across Rust + Swift)。
//
// ## Byte-equality strategy
//
// Both Swift and Rust call the platform libm (`exp` / `log10` /
// `pow`)。 On Apple Silicon both reach the same Accelerate
// implementation,producing bit-identical f64 outputs。 Test
// fixture (chapter 七百二十三 第二刀) pins the exact f64 bits
// for 100/1K/10K atom × record cells; if a libm change breaks
// byte-equality the test fails and we surface the divergence
// instead of silently propagating it。
//
// ## Why Rust port at all
//
// Plan-agent honest estimate:scoreAll is already O(N+M) (bucket
// then score)。 Rust port wins primarily by:
//   1. Eliminating the Swift HashMap allocator overhead per
//      insert (~20-30ns)
//   2. Tight FP loops compile to better-vectorized code than
//      Swift's protocol-dispatch fallbacks
// Expected speedup:2-4× at large N (NOT the 10-20× the original
// architectural matrix suggested)。 Chapter 七百二十三 第三刀
// will measure and decide whether to flip default。

use std::collections::HashMap;

/// Match Swift `BASMemoryTier`。 Discriminant values pinned so
/// the C ABI wire format can use the same integers。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Tier {
    Cold = 0,
    Warm = 1,
    Hot = 2,
}

impl Tier {
    pub fn from_u8(value: u8) -> Option<Tier> {
        match value {
            0 => Some(Tier::Cold),
            1 => Some(Tier::Warm),
            2 => Some(Tier::Hot),
            _ => None,
        }
    }

    pub fn as_u8(self) -> u8 {
        self as u8
    }

    /// One step up (cold→warm→hot,saturating at hot)。
    pub fn promote(self) -> Tier {
        match self {
            Tier::Cold => Tier::Warm,
            Tier::Warm => Tier::Hot,
            Tier::Hot => Tier::Hot,
        }
    }

    /// One step down (hot→warm→cold,saturating at cold)。
    pub fn demote(self) -> Tier {
        match self {
            Tier::Hot => Tier::Warm,
            Tier::Warm => Tier::Cold,
            Tier::Cold => Tier::Cold,
        }
    }
}

/// Match Swift `BASMemoryUsageRecord.helpedFlag` cases。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum HelpedFlag {
    NotHelped = 0,
    Helped = 1,
    Unknown = 2,
}

impl HelpedFlag {
    pub fn from_u8(value: u8) -> Option<HelpedFlag> {
        match value {
            0 => Some(HelpedFlag::NotHelped),
            1 => Some(HelpedFlag::Helped),
            2 => Some(HelpedFlag::Unknown),
            _ => None,
        }
    }
}

/// One usage event for an atom。 Mirrors Swift
/// `BASMemoryUsageRecord` minus fields the scorer doesn't read
/// (record_id,session_ref,turn_ref,permit_mode) — keeping the
/// wire format compact。
#[derive(Debug, Clone)]
pub struct UsageRecord {
    pub atom_id: String,
    /// Unix epoch milliseconds (Swift TimeInterval × 1000)。 i64
    /// keeps full precision for the substrate's typical date
    /// range (1970 - 2200+)。
    pub retrieved_at_ms: i64,
    pub helped_flag: HelpedFlag,
}

/// Scorer tunables — mirror Swift `BASMemoryImportanceScorer`
/// fields。 Defaults match `defaultPromoteThreshold` /
/// `defaultDemoteThreshold` etc。
#[derive(Debug, Clone, Copy)]
pub struct Tunables {
    pub promote_threshold: f64,
    pub demote_threshold: f64,
    pub recency_half_life_seconds: f64,
    pub frequency_saturation: f64,
    pub tier_decay_hot: f64,
    pub tier_decay_warm: f64,
    pub tier_decay_cold: f64,
}

impl Default for Tunables {
    fn default() -> Self {
        Self {
            promote_threshold: 0.65,
            demote_threshold: 0.20,
            recency_half_life_seconds: 86_400.0,
            frequency_saturation: 50.0,
            tier_decay_hot: 1.0,
            tier_decay_warm: 0.7,
            tier_decay_cold: 0.4,
        }
    }
}

/// One scored atom — mirrors Swift `BASMemoryImportanceScore`。
#[derive(Debug, Clone, PartialEq)]
pub struct ImportanceScore {
    pub atom_id: String,
    pub current_tier: Tier,
    pub recency_component: f64,
    pub frequency_component: f64,
    pub helped_component: f64,
    pub tier_decay_component: f64,
    pub total_score: f64,
    pub recommended_tier: Tier,
    pub record_count: usize,
    /// Pass-through of the `now` timestamp the caller provided。
    /// Stored on each score so chained reports keep a coherent
    /// time anchor。
    pub computed_at_ms: i64,
}

/// Port of Swift `scoreAll`。 Buckets records,scores each
/// (atomID,tier) pair,returns scores sorted by atomID
/// ascending (stable across implementations)。
pub fn score_all(
    atom_tiers: &[(String, Tier)],
    records: &[UsageRecord],
    now_ms: i64,
    tunables: &Tunables,
) -> Vec<ImportanceScore> {
    // Bucket records by atom_id under one pass。
    let mut bucket: HashMap<&str, Vec<&UsageRecord>> =
        HashMap::with_capacity(atom_tiers.len());
    for r in records {
        bucket
            .entry(r.atom_id.as_str())
            .or_insert_with(Vec::new)
            .push(r);
    }

    let mut scores: Vec<ImportanceScore> =
        Vec::with_capacity(atom_tiers.len());
    let empty: Vec<&UsageRecord> = Vec::new();
    for (atom_id, current_tier) in atom_tiers {
        let atom_records: &Vec<&UsageRecord> =
            bucket.get(atom_id.as_str()).unwrap_or(&empty);
        scores.push(score_one(
            atom_id,
            *current_tier,
            atom_records,
            now_ms,
            tunables));
    }
    // Stable order by atom_id ascending — matches Swift
    // `scores.sort { $0.atomID < $1.atomID }`。
    scores.sort_by(|a, b| a.atom_id.cmp(&b.atom_id));
    scores
}

fn score_one(
    atom_id: &str,
    current_tier: Tier,
    records: &[&UsageRecord],
    now_ms: i64,
    tunables: &Tunables,
) -> ImportanceScore {
    let recency = recency_component(
        records, now_ms, tunables.recency_half_life_seconds);
    let frequency = frequency_component(
        records, tunables.frequency_saturation);
    let helped = helped_component(records);
    let tier_decay = tier_decay_component(
        current_tier, tunables);

    // pow((rec+ε)(freq+ε)(help+ε)(tier+ε), 0.25)
    let epsilon = 0.0001f64;
    let product =
        (recency + epsilon)
        * (frequency + epsilon)
        * (helped + epsilon)
        * (tier_decay + epsilon);
    let raw = product.powf(0.25);
    let geometric_total = clamp(raw, 0.0, 1.0);

    // audit blindspot-③ HIGH: mirror of the Swift BASMemoryImportanceScorer fix. A brand-new atom has
    // NO usage records, so recency/frequency are 0 and the geometric mean collapses to ~0.001
    // (near-MIN) despite the +ε — a fresh atom was recommended for DEMOTION on arrival, before it
    // could ever be used. With zero usage the importance is UNKNOWN, so a no-history atom STAYS in its
    // current tier and reports a neutral 0.5 total. Kept byte-identical to the Swift side (the
    // BASChapter723 byte-parity suite pins Swift == Rust — re-greens once the SHA-pinned
    // BASRustMemoryTracker.xcframework is rebuilt from this source).
    let has_history = !records.is_empty();
    let total = if has_history { geometric_total } else { 0.5 };
    let recommended = if has_history {
        recommended_tier(current_tier, geometric_total, tunables)
    } else {
        current_tier
    };

    ImportanceScore {
        atom_id: atom_id.to_string(),
        current_tier,
        recency_component: recency,
        frequency_component: frequency,
        helped_component: helped,
        tier_decay_component: tier_decay,
        total_score: total,
        recommended_tier: recommended,
        record_count: records.len(),
        computed_at_ms: now_ms,
    }
}

fn recency_component(
    records: &[&UsageRecord],
    now_ms: i64,
    half_life_seconds: f64,
) -> f64 {
    if records.is_empty() {
        return 0.0;
    }
    let most_recent_ms = records
        .iter()
        .map(|r| r.retrieved_at_ms)
        .max()
        .unwrap();
    // age in seconds (matches Swift `timeIntervalSince(:_)` which
    // returns TimeInterval = seconds as Double)
    let age_seconds = ((now_ms - most_recent_ms) as f64) / 1000.0;
    let age_seconds = age_seconds.max(0.0);
    let half_life = half_life_seconds.max(1.0);
    let ln2 = (2.0f64).ln();
    let decayed = (-age_seconds * ln2 / half_life).exp();
    clamp(decayed, 0.0, 1.0)
}

fn frequency_component(
    records: &[&UsageRecord],
    saturation: f64,
) -> f64 {
    let count = records.len() as f64;
    if count <= 0.0 {
        return 0.0;
    }
    let saturation = saturation.max(1.0);
    let raw = (1.0 + count).log10() / (1.0 + saturation).log10();
    clamp(raw, 0.0, 1.0)
}

fn helped_component(records: &[&UsageRecord]) -> f64 {
    if records.is_empty() {
        return 0.5;
    }
    let mut helped = 0.0f64;
    let mut not_helped = 0.0f64;
    let mut unknown = 0.0f64;
    for r in records {
        match r.helped_flag {
            HelpedFlag::Helped => helped += 1.0,
            HelpedFlag::NotHelped => not_helped += 1.0,
            HelpedFlag::Unknown => unknown += 1.0,
        }
    }
    let weighted = helped + 0.5 * unknown;
    let total = helped + not_helped + unknown;
    if total <= 0.0 {
        return 0.5;
    }
    clamp(weighted / total, 0.0, 1.0)
}

fn tier_decay_component(
    tier: Tier,
    tunables: &Tunables,
) -> f64 {
    match tier {
        Tier::Hot => tunables.tier_decay_hot,
        Tier::Warm => tunables.tier_decay_warm,
        Tier::Cold => tunables.tier_decay_cold,
    }
}

fn recommended_tier(
    current: Tier,
    total: f64,
    tunables: &Tunables,
) -> Tier {
    if total >= tunables.promote_threshold {
        current.promote()
    } else if total <= tunables.demote_threshold {
        current.demote()
    } else {
        current
    }
}

fn clamp(value: f64, lo: f64, hi: f64) -> f64 {
    if value.is_nan() {
        return lo;
    }
    value.min(hi).max(lo)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mk_record(
        atom: &str, t_ms: i64, helped: HelpedFlag
    ) -> UsageRecord {
        UsageRecord {
            atom_id: atom.to_string(),
            retrieved_at_ms: t_ms,
            helped_flag: helped,
        }
    }

    #[test]
    fn empty_records_produce_neutral_helped() {
        let r: &[&UsageRecord] = &[];
        assert_eq!(helped_component(r), 0.5);
    }

    #[test]
    fn empty_records_produce_zero_recency() {
        let r: &[&UsageRecord] = &[];
        assert_eq!(
            recency_component(r, 1000, 86400.0),
            0.0);
    }

    #[test]
    fn frequency_saturates_at_one() {
        // count = saturation → raw = log10(1+count)/log10(1+sat) = 1
        let recs: Vec<UsageRecord> = (0..50)
            .map(|i| mk_record("a", i * 1000, HelpedFlag::Helped))
            .collect();
        let refs: Vec<&UsageRecord> = recs.iter().collect();
        let f = frequency_component(&refs, 50.0);
        assert!(
            (f - 1.0).abs() < 1e-12,
            "expected ~1.0 got {}", f);
    }

    #[test]
    fn helped_all_yes_returns_one() {
        let recs = vec![
            mk_record("a", 0, HelpedFlag::Helped),
            mk_record("a", 1, HelpedFlag::Helped),
            mk_record("a", 2, HelpedFlag::Helped),
        ];
        let refs: Vec<&UsageRecord> = recs.iter().collect();
        assert_eq!(helped_component(&refs), 1.0);
    }

    #[test]
    fn helped_all_no_returns_zero() {
        let recs = vec![
            mk_record("a", 0, HelpedFlag::NotHelped),
            mk_record("a", 1, HelpedFlag::NotHelped),
        ];
        let refs: Vec<&UsageRecord> = recs.iter().collect();
        assert_eq!(helped_component(&refs), 0.0);
    }

    #[test]
    fn helped_mixed_unknowns_weighted_half() {
        // 2 helped + 2 unknowns: (2 + 0.5*2) / 4 = 0.75
        let recs = vec![
            mk_record("a", 0, HelpedFlag::Helped),
            mk_record("a", 1, HelpedFlag::Helped),
            mk_record("a", 2, HelpedFlag::Unknown),
            mk_record("a", 3, HelpedFlag::Unknown),
        ];
        let refs: Vec<&UsageRecord> = recs.iter().collect();
        let h = helped_component(&refs);
        assert!(
            (h - 0.75).abs() < 1e-12,
            "expected 0.75 got {}", h);
    }

    #[test]
    fn recency_half_life_decays_correctly() {
        // age = halfLife → decayed = exp(-ln 2) = 0.5
        let half = 86400.0;
        let now = 86_400_000i64; // 1 day later in ms
        let rec = mk_record(
            "a", 0, HelpedFlag::Helped); // retrieved at t=0
        let refs: Vec<&UsageRecord> = vec![&rec];
        let r = recency_component(&refs, now, half);
        assert!(
            (r - 0.5).abs() < 1e-9,
            "expected 0.5 at one half-life,got {}", r);
    }

    #[test]
    fn tier_decay_hot_warm_cold() {
        let t = Tunables::default();
        assert_eq!(
            tier_decay_component(Tier::Hot, &t), 1.0);
        assert_eq!(
            tier_decay_component(Tier::Warm, &t), 0.7);
        assert_eq!(
            tier_decay_component(Tier::Cold, &t), 0.4);
    }

    #[test]
    fn tier_promote_saturates_at_hot() {
        assert_eq!(Tier::Cold.promote(), Tier::Warm);
        assert_eq!(Tier::Warm.promote(), Tier::Hot);
        assert_eq!(Tier::Hot.promote(), Tier::Hot);
    }

    #[test]
    fn tier_demote_saturates_at_cold() {
        assert_eq!(Tier::Hot.demote(), Tier::Warm);
        assert_eq!(Tier::Warm.demote(), Tier::Cold);
        assert_eq!(Tier::Cold.demote(), Tier::Cold);
    }

    #[test]
    fn recommended_promote_at_threshold() {
        let t = Tunables::default();
        // total = 0.65 (exactly) should promote
        assert_eq!(
            recommended_tier(Tier::Warm, 0.65, &t),
            Tier::Hot);
        assert_eq!(
            recommended_tier(Tier::Warm, 0.70, &t),
            Tier::Hot);
    }

    #[test]
    fn recommended_demote_at_threshold() {
        let t = Tunables::default();
        // total = 0.20 (exactly) should demote
        assert_eq!(
            recommended_tier(Tier::Warm, 0.20, &t),
            Tier::Cold);
        assert_eq!(
            recommended_tier(Tier::Warm, 0.10, &t),
            Tier::Cold);
    }

    #[test]
    fn recommended_hold_between_thresholds() {
        let t = Tunables::default();
        assert_eq!(
            recommended_tier(Tier::Warm, 0.50, &t),
            Tier::Warm);
    }

    #[test]
    fn score_all_returns_sorted_by_atom_id() {
        let recs = vec![
            mk_record("zeta", 1000, HelpedFlag::Helped),
            mk_record("alpha", 2000, HelpedFlag::Helped),
            mk_record("mu", 3000, HelpedFlag::Helped),
        ];
        let tiers = vec![
            ("zeta".to_string(), Tier::Warm),
            ("alpha".to_string(), Tier::Cold),
            ("mu".to_string(), Tier::Hot),
        ];
        let scores = score_all(
            &tiers, &recs, 10_000, &Tunables::default());
        assert_eq!(scores.len(), 3);
        assert_eq!(scores[0].atom_id, "alpha");
        assert_eq!(scores[1].atom_id, "mu");
        assert_eq!(scores[2].atom_id, "zeta");
    }

    #[test]
    fn score_all_handles_unbucketed_atoms() {
        // An atom in atomTiers with NO records should still
        // appear in the output with zero recency / zero
        // frequency。
        let recs = vec![
            mk_record("alpha", 1000, HelpedFlag::Helped),
        ];
        let tiers = vec![
            ("alpha".to_string(), Tier::Warm),
            ("beta".to_string(), Tier::Cold),
        ];
        let scores = score_all(
            &tiers, &recs, 5000, &Tunables::default());
        assert_eq!(scores.len(), 2);
        let beta = scores
            .iter()
            .find(|s| s.atom_id == "beta")
            .unwrap();
        assert_eq!(beta.record_count, 0);
        assert_eq!(beta.recency_component, 0.0);
        assert_eq!(beta.frequency_component, 0.0);
        // helped defaults to 0.5 for empty records
        assert_eq!(beta.helped_component, 0.5);
    }

    #[test]
    fn no_history_atom_stays_not_demoted() {
        // audit blindspot-③ HIGH: a WARM atom with NO usage records must NOT be demoted to Cold on
        // arrival (Cold would stay Cold regardless, so a Warm atom is the discriminating case). Its
        // importance is unknown ⇒ it stays Warm and reports a neutral 0.5 total. Reversal (geometric
        // mean ~0.007 → demote) reds: recommended_tier would be Cold and total ~0.0077.
        let recs: Vec<UsageRecord> = vec![];
        let tiers = vec![("fresh".to_string(), Tier::Warm)];
        let scores = score_all(&tiers, &recs, 5000, &Tunables::default());
        let fresh = &scores[0];
        assert_eq!(fresh.record_count, 0);
        assert_eq!(fresh.total_score, 0.5,
            "a no-history atom must score neutral, not near-min");
        assert_eq!(fresh.recommended_tier, Tier::Warm,
            "a no-history warm atom must STAY warm, not be demoted to cold on arrival");
    }

    #[test]
    fn score_total_is_clamped_to_unit_interval() {
        let recs = vec![
            mk_record("hot", 5000, HelpedFlag::Helped),
            mk_record("hot", 5500, HelpedFlag::Helped),
        ];
        let tiers = vec![
            ("hot".to_string(), Tier::Hot)];
        let scores = score_all(
            &tiers, &recs, 6000, &Tunables::default());
        let s = &scores[0];
        assert!(
            s.total_score >= 0.0 && s.total_score <= 1.0,
            "total = {} out of [0,1]", s.total_score);
    }

    #[test]
    fn score_all_computed_at_propagates() {
        let recs = vec![];
        let tiers = vec![
            ("a".to_string(), Tier::Warm)];
        let scores = score_all(
            &tiers, &recs, 12345, &Tunables::default());
        assert_eq!(scores[0].computed_at_ms, 12345);
    }

    #[test]
    fn nan_inputs_clamped_to_lower_bound() {
        // clamp() must guard against NaN propagation。
        assert_eq!(clamp(f64::NAN, 0.0, 1.0), 0.0);
    }
}
