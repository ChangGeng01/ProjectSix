// MARK: - bas-world-prior — L4 World Prior typed surface + pure fns
// chapter 七百七十一 / M2506-M2510 — DEEPER LAYER-MIGRATION ARC
//
// Rust-side types + pure-fn surface for the L4 World Prior data,
// companion to the 4 SQL schemas landed at chapter 七百七十:
//   - 016_world_priors_axioms
//   - 017_world_priors_templates
//   - 018_world_priors_bridges
//   - 019_world_priors_domains
//
// SQLite I/O stays Swift。 Rust owns:
//   - Typed Axiom / Template / Bridge / Domain structs (mirror SQL rows)
//   - EvidenceLevel + Reversibility + DomainStatus enums
//   - evidence-propagation pure fn (weakest-link semantics)
//   - reversibility/latency aggregate lookup pure fn

#![allow(clippy::missing_safety_doc)]

// MARK: - EvidenceLevel enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum EvidenceLevel {
    Anecdotal     = 0,
    Observed      = 1,
    PeerReviewed  = 2,
    Mechanistic   = 3,
}

impl EvidenceLevel {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Anecdotal),
            1 => Some(Self::Observed),
            2 => Some(Self::PeerReviewed),
            3 => Some(Self::Mechanistic),
            _ => None,
        }
    }
    pub const ALL: [EvidenceLevel; 4] = [
        EvidenceLevel::Anecdotal, EvidenceLevel::Observed,
        EvidenceLevel::PeerReviewed, EvidenceLevel::Mechanistic,
    ];

    /// SQL string raw value (matches the schema CHECK constraints)。
    pub const fn sql_raw(self) -> &'static str {
        match self {
            EvidenceLevel::Anecdotal    => "anecdotal",
            EvidenceLevel::Observed     => "observed",
            EvidenceLevel::PeerReviewed => "peer_reviewed",
            EvidenceLevel::Mechanistic  => "mechanistic",
        }
    }

    /// Numeric weight for evidence propagation。 Higher = stronger。
    pub const fn weight(self) -> f64 {
        match self {
            EvidenceLevel::Anecdotal    => 0.25,
            EvidenceLevel::Observed     => 0.5,
            EvidenceLevel::PeerReviewed => 0.75,
            EvidenceLevel::Mechanistic  => 1.0,
        }
    }
}

// MARK: - Reversibility enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum Reversibility {
    Irreversible = 0,
    Hard         = 1,
    Medium       = 2,
    Easy         = 3,
}

impl Reversibility {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Irreversible),
            1 => Some(Self::Hard),
            2 => Some(Self::Medium),
            3 => Some(Self::Easy),
            _ => None,
        }
    }
    pub const ALL: [Reversibility; 4] = [
        Reversibility::Irreversible, Reversibility::Hard,
        Reversibility::Medium, Reversibility::Easy,
    ];

    /// Risk score [0, 1] — higher = riskier。
    pub const fn risk_score(self) -> f64 {
        match self {
            Reversibility::Irreversible => 1.0,
            Reversibility::Hard         => 0.75,
            Reversibility::Medium       => 0.4,
            Reversibility::Easy         => 0.1,
        }
    }
}

// MARK: - DomainStatus enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum DomainStatus {
    Active  = 0,
    Sunset  = 1,
    Pending = 2,
}

impl DomainStatus {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Active),
            1 => Some(Self::Sunset),
            2 => Some(Self::Pending),
            _ => None,
        }
    }
    pub const fn sql_raw(self) -> &'static str {
        match self {
            DomainStatus::Active  => "active",
            DomainStatus::Sunset  => "sunset",
            DomainStatus::Pending => "pending",
        }
    }
}

// MARK: - Typed row mirrors

#[derive(Debug, Clone, PartialEq)]
pub struct Axiom {
    pub axiom_id: String,
    pub domain: String,
    pub statement: String,
    pub evidence_level: EvidenceLevel,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Template {
    pub template_id: String,
    pub domain: String,
    pub preconditions_json: Option<String>,
    pub effect: String,
    pub reversibility: Reversibility,
    pub latency_ms: i64,
    pub evidence_level: EvidenceLevel,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Bridge {
    pub bridge_id: String,
    pub source_domain: String,
    pub target_domain: String,
    pub analogy: String,
    pub template_pairings_json: Option<String>,
    pub evidence_level: EvidenceLevel,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Domain {
    pub domain: String,
    pub horizon_id: String,
    pub status: DomainStatus,
}

// MARK: - Evidence propagation pure fn

/// Weakest-link evidence propagation:given a set of evidence levels
/// (one per traversed axiom + template + bridge),the aggregate
/// evidence level is the MINIMUM。
///
/// Empty input → Anecdotal (weakest)。 Mirrors Swift
/// `BASWorldPriorRiskAssessment.evidencePropagation(across:)`。
pub fn propagate_evidence(levels: &[EvidenceLevel]) -> EvidenceLevel {
    let mut min = EvidenceLevel::Mechanistic;
    if levels.is_empty() {
        return EvidenceLevel::Anecdotal;
    }
    for &l in levels {
        if (l as u8) < (min as u8) {
            min = l;
        }
    }
    min
}

/// Average latency_ms across a set of templates。 Used by the
/// reversibility/latency lookup query (BASWorldPriorRiskAssessment
/// reversibility/latency aggregation)。
///
/// Empty input → 0。
pub fn aggregate_latency_ms(latencies: &[i64]) -> i64 {
    if latencies.is_empty() { return 0; }
    let sum: i64 = latencies.iter().sum();
    sum / (latencies.len() as i64)
}

/// Worst-case reversibility:given a set,the aggregate is the
/// MOST DANGEROUS (lowest discriminant — Irreversible = 0 = worst)。
pub fn worst_reversibility(values: &[Reversibility]) -> Reversibility {
    let mut worst = Reversibility::Easy;
    if values.is_empty() {
        return Reversibility::Easy;
    }
    for &v in values {
        if (v as u8) < (worst as u8) {
            worst = v;
        }
    }
    worst
}

// MARK: - C ABI exports

/// C ABI:propagate evidence。 Accepts a u8 array of levels +
/// length;returns the aggregate level (u8 discriminant)。
/// -1 if any byte is out of range。
///
/// # Safety
///
/// Caller MUST ensure `levels` points to `len` readable bytes。
#[no_mangle]
pub unsafe extern "C" fn bas_world_prior_propagate_evidence(
    levels: *const u8,
    len: i32,
) -> i32 {
    if len < 0 { return -1; }
    if len == 0 { return EvidenceLevel::Anecdotal as i32; }
    if levels.is_null() { return -1; }
    let slice = core::slice::from_raw_parts(levels, len as usize);
    let mut buf: Vec<EvidenceLevel> = Vec::with_capacity(slice.len());
    for &b in slice {
        match EvidenceLevel::from_u8(b) {
            Some(l) => buf.push(l),
            None => return -1,
        }
    }
    propagate_evidence(&buf) as i32
}

/// C ABI:aggregate latency_ms。 Accepts a pointer to i64 array
/// + length;returns the mean。 -1 on null input with non-zero len。
#[no_mangle]
pub unsafe extern "C" fn bas_world_prior_aggregate_latency(
    latencies: *const i64,
    len: i32,
) -> i64 {
    if len < 0 { return -1; }
    if len == 0 { return 0; }
    if latencies.is_null() { return -1; }
    let slice = core::slice::from_raw_parts(latencies, len as usize);
    aggregate_latency_ms(slice)
}

/// C ABI:worst-case reversibility。 Accepts u8 array of
/// Reversibility discriminants;returns the worst (lowest
/// discriminant)。 -1 on invalid input。
#[no_mangle]
pub unsafe extern "C" fn bas_world_prior_worst_reversibility(
    values: *const u8,
    len: i32,
) -> i32 {
    if len < 0 { return -1; }
    if len == 0 { return Reversibility::Easy as i32; }
    if values.is_null() { return -1; }
    let slice = core::slice::from_raw_parts(values, len as usize);
    let mut buf: Vec<Reversibility> = Vec::with_capacity(slice.len());
    for &b in slice {
        match Reversibility::from_u8(b) {
            Some(r) => buf.push(r),
            None => return -1,
        }
    }
    worst_reversibility(&buf) as i32
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_world_prior_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned() {
        assert_eq!(bas_world_prior_abi_version(), 1);
    }

    // MARK: EvidenceLevel

    #[test]
    fn test_evidence_level_cardinality_and_discriminants() {
        assert_eq!(EvidenceLevel::ALL.len(), 4);
        assert_eq!(EvidenceLevel::Anecdotal as u8, 0);
        assert_eq!(EvidenceLevel::Observed as u8, 1);
        assert_eq!(EvidenceLevel::PeerReviewed as u8, 2);
        assert_eq!(EvidenceLevel::Mechanistic as u8, 3);
    }

    #[test]
    fn test_evidence_level_sql_raw_strings() {
        assert_eq!(EvidenceLevel::Anecdotal.sql_raw(), "anecdotal");
        assert_eq!(EvidenceLevel::Observed.sql_raw(), "observed");
        assert_eq!(EvidenceLevel::PeerReviewed.sql_raw(), "peer_reviewed");
        assert_eq!(EvidenceLevel::Mechanistic.sql_raw(), "mechanistic");
    }

    #[test]
    fn test_evidence_level_weights_monotonic() {
        assert!(EvidenceLevel::Anecdotal.weight()
            < EvidenceLevel::Observed.weight());
        assert!(EvidenceLevel::Observed.weight()
            < EvidenceLevel::PeerReviewed.weight());
        assert!(EvidenceLevel::PeerReviewed.weight()
            < EvidenceLevel::Mechanistic.weight());
    }

    #[test]
    fn test_evidence_level_from_u8_round_trip() {
        for &l in &EvidenceLevel::ALL {
            assert_eq!(EvidenceLevel::from_u8(l as u8), Some(l));
        }
        assert_eq!(EvidenceLevel::from_u8(4), None);
    }

    // MARK: Reversibility

    #[test]
    fn test_reversibility_cardinality_and_discriminants() {
        assert_eq!(Reversibility::ALL.len(), 4);
        assert_eq!(Reversibility::Irreversible as u8, 0);
        assert_eq!(Reversibility::Easy as u8, 3);
    }

    #[test]
    fn test_reversibility_risk_score_descending() {
        // Lower discriminant = worse outcome = higher risk score
        assert!(Reversibility::Irreversible.risk_score()
            > Reversibility::Hard.risk_score());
        assert!(Reversibility::Hard.risk_score()
            > Reversibility::Medium.risk_score());
        assert!(Reversibility::Medium.risk_score()
            > Reversibility::Easy.risk_score());
    }

    // MARK: DomainStatus

    #[test]
    fn test_domain_status_sql_raw_strings() {
        assert_eq!(DomainStatus::Active.sql_raw(), "active");
        assert_eq!(DomainStatus::Sunset.sql_raw(), "sunset");
        assert_eq!(DomainStatus::Pending.sql_raw(), "pending");
    }

    // MARK: propagate_evidence

    #[test]
    fn test_propagate_evidence_empty_yields_anecdotal() {
        assert_eq!(propagate_evidence(&[]),
            EvidenceLevel::Anecdotal);
    }

    #[test]
    fn test_propagate_evidence_single_yields_self() {
        assert_eq!(
            propagate_evidence(&[EvidenceLevel::Mechanistic]),
            EvidenceLevel::Mechanistic);
    }

    #[test]
    fn test_propagate_evidence_weakest_wins() {
        let levels = vec![
            EvidenceLevel::Mechanistic,
            EvidenceLevel::Anecdotal,
            EvidenceLevel::PeerReviewed,
        ];
        assert_eq!(propagate_evidence(&levels),
            EvidenceLevel::Anecdotal);
    }

    // MARK: aggregate_latency_ms

    #[test]
    fn test_aggregate_latency_empty_yields_zero() {
        assert_eq!(aggregate_latency_ms(&[]), 0);
    }

    #[test]
    fn test_aggregate_latency_mean_computed() {
        assert_eq!(aggregate_latency_ms(&[100, 200, 300]), 200);
    }

    // MARK: worst_reversibility

    #[test]
    fn test_worst_reversibility_empty_yields_easy() {
        assert_eq!(worst_reversibility(&[]),
            Reversibility::Easy);
    }

    #[test]
    fn test_worst_reversibility_irreversible_dominates() {
        let values = vec![
            Reversibility::Easy,
            Reversibility::Hard,
            Reversibility::Irreversible,
            Reversibility::Medium,
        ];
        assert_eq!(worst_reversibility(&values),
            Reversibility::Irreversible);
    }

    // MARK: C ABI

    #[test]
    fn test_c_abi_propagate_evidence_empty() {
        unsafe {
            assert_eq!(
                bas_world_prior_propagate_evidence(
                    core::ptr::null(), 0),
                EvidenceLevel::Anecdotal as i32);
        }
    }

    #[test]
    fn test_c_abi_propagate_evidence_invalid_byte() {
        let bad: [u8; 1] = [99];
        unsafe {
            assert_eq!(
                bas_world_prior_propagate_evidence(
                    bad.as_ptr(), 1),
                -1);
        }
    }

    #[test]
    fn test_c_abi_aggregate_latency() {
        let nums: [i64; 3] = [100, 200, 300];
        unsafe {
            assert_eq!(
                bas_world_prior_aggregate_latency(
                    nums.as_ptr(), 3),
                200);
        }
    }

    #[test]
    fn test_c_abi_worst_reversibility() {
        let vals: [u8; 3] = [3, 0, 2]; // Easy, Irreversible, Medium
        unsafe {
            assert_eq!(
                bas_world_prior_worst_reversibility(
                    vals.as_ptr(), 3),
                Reversibility::Irreversible as i32);
        }
    }
}
