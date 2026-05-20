// MARK: - bas-integrity-sentinel — typed Rust port of GSI sentinel
// chapter 七百六十 第一刀 / M2451 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of BASSovereignIntegritySentinel.swift (165 LOC)。
// Mirrors the Swift typed API:
//
//   - `ArtifactKind` enum (4 cases) — maps each kind to its BR-bit
//   - `ArtifactClaim` struct (id, claimed_hash, kind)
//   - `ScanRequest` struct (claims + observed_self_mutation)
//   - `ScanReport` struct (failed IDs + failed kinds set + self-mutation
//     flag forwarded)
//   - `scan_artifacts` pure fn — verifies claims against trusted
//     fingerprints,produces structured ScanReport
//
// Compared to bas-sovereign-c-abi::bas_sovereign_integrity_scan
// (which collapses output to a 4-bit hard_bits bitfield),this
// crate retains the FULL structured report so Rust consumers can:
//
//   - Log specific failed artifact IDs (audit log granularity)
//   - Distinguish「kind X failed」 vs「kind X passed AND
//     observed_self_mutation also tripped BR-007」
//   - Compose multiple scan results (e.g. boot scan + per-turn
//     scan) without losing ID-level granularity
//
// Discipline pins
// ---------------
//
//  1. BTreeMap (not HashMap) for trusted fingerprints — deterministic
//     iteration order across runs。 The chapter 392 replay-determinism
//     invariant requires that two scans of the same input set produce
//     byte-identical reports including failed_ids ordering。
//
//  2. Conservative unknown-artifact semantics:if a claim id is not
//     in trusted,the claim FAILS。 The sentinel cannot vouch for
//     what it has no ground truth for (mirrors Swift line 162-163)。
//
//  3. Case-insensitive hash comparison:both sides lowercased
//     before compare (mirrors Swift line 138 + 163)。
//
//  4. observed_self_mutation OR's into BR-007 (runtime image)
//     even if all runtime-image claims pass (mirrors Swift line 117)。

#![allow(clippy::missing_safety_doc)]

use std::collections::{BTreeMap, BTreeSet};

// MARK: - ArtifactKind enum

/// Which integrity column a failed artifact rolls up into。 The
/// mapping is fixed by `BR-01..BR-07` of the L14 sovereign spec。
///
/// Wire encoding (knife 三 C ABI):u8 with discriminant values
/// matching the chapter 七百五十八 `BAS_ARTIFACT_KIND_*` constants
/// (so wire formats stay consistent across the two sibling crates)。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum ArtifactKind {
    /// Model weights / policy bundles whose signatures must match。
    /// Failure → BR-001 (`artifact_signature_invalid`)。
    ModelOrPolicyArtifact = 0,
    /// The L14 sovereign policy bundle specifically。
    /// Failure → BR-006 (`policy_bundle_tampered`)。
    SovereignPolicyBundle = 1,
    /// ThoughtFold / recovery cache。
    /// Failure → BR-002 (`thought_fold_checksum_broken`)。
    ThoughtFoldOrCache = 2,
    /// Executable image / runtime。
    /// Failure → BR-007 (`unauthorized_self_mutation`)。
    RuntimeImage = 3,
}

impl ArtifactKind {
    /// Convert u8 discriminant to ArtifactKind。 Returns None for
    /// out-of-range values (4..255) — used by the C ABI wire-
    /// format parser to reject unknown kinds rather than silently
    /// promoting them to a default。
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::ModelOrPolicyArtifact),
            1 => Some(Self::SovereignPolicyBundle),
            2 => Some(Self::ThoughtFoldOrCache),
            3 => Some(Self::RuntimeImage),
            _ => None,
        }
    }

    /// All 4 discriminants in their canonical enum order。 Used by
    /// tests + the scorecard to assert cardinality。
    pub const ALL: [ArtifactKind; 4] = [
        ArtifactKind::ModelOrPolicyArtifact,
        ArtifactKind::SovereignPolicyBundle,
        ArtifactKind::ThoughtFoldOrCache,
        ArtifactKind::RuntimeImage,
    ];
}

// MARK: - ArtifactClaim

/// A single claim presented to the sentinel for verification。
/// The sentinel owns the ground truth (registered fingerprint) and
/// compares it to `claimed_hash`。 Field order + names mirror the
/// Swift struct exactly so the wire format can be derived from
/// either side。
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ArtifactClaim {
    /// Artifact identifier (e.g。 "model.weights"、"policy.bundle")。
    pub id: String,
    /// Hex SHA-256 hash (case-insensitive on compare)。
    pub claimed_hash: String,
    /// Which BR-bit a failed claim of this kind rolls up into。
    pub kind: ArtifactKind,
}

impl ArtifactClaim {
    pub fn new(id: impl Into<String>, claimed_hash: impl Into<String>, kind: ArtifactKind) -> Self {
        Self {
            id: id.into(),
            claimed_hash: claimed_hash.into(),
            kind,
        }
    }
}

// MARK: - ScanRequest

/// A batch of claims + the out-of-band self-mutation flag。
/// Mirrors `BASSovereignIntegritySentinel.ScanRequest`。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanRequest {
    /// All artifacts the runtime wants verified this turn。
    pub claims: Vec<ArtifactClaim>,
    /// Out-of-band signal that something outside the fingerprint
    /// store has been observed self-mutating。 The integrity
    /// sentinel itself cannot detect all forms of self-mutation
    /// (e.g。 a runtime patch applied by a compromised loader);
    /// the runtime supplies this bit based on its own attestation。
    pub observed_self_mutation: bool,
}

impl ScanRequest {
    pub fn new(claims: Vec<ArtifactClaim>, observed_self_mutation: bool) -> Self {
        Self {
            claims,
            observed_self_mutation,
        }
    }
}

// MARK: - ScanReport

/// Structured output of a scan。 Mirrors Swift's
/// `BASSovereignIntegritySentinel.ScanReport`。
///
/// Ordering pins
/// -------------
///
///  - `failed_ids` preserves INSERTION ORDER (the order in which
///    claims failed during the scan loop)。 Mirrors Swift's
///    `var failedIDs: [String] = []` accumulator。 Test fixtures
///    can rely on this for byte-equality compare with the Swift
///    reference output。
///
///  - `failed_kinds` uses `BTreeSet<ArtifactKind>` — DETERMINISTIC
///    ordering by enum discriminant。 Swift uses `Set<ArtifactKind>`
///    which is unordered;the Rust port pins ordering to remove
///    that nondeterminism from the byte-equality grid。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanReport {
    /// IDs of all claims that failed verification (insertion order)。
    pub failed_artifact_ids: Vec<String>,
    /// Set of kinds that had ≥1 failed claim (BTreeSet for
    /// deterministic discriminant-order iteration)。
    pub failed_kinds: BTreeSet<ArtifactKind>,
    /// Forwarded from `ScanRequest.observed_self_mutation`。
    pub observed_self_mutation: bool,
}

impl ScanReport {
    /// Empty report (no failures,no self-mutation)。 The「clean
    /// boot」 sentinel default。
    pub fn clean() -> Self {
        Self {
            failed_artifact_ids: Vec::new(),
            failed_kinds: BTreeSet::new(),
            observed_self_mutation: false,
        }
    }

    /// True when this report contains any failure signal
    /// (failed claims OR observed self-mutation)。 Convenience
    /// for callers that want a single「is there a problem」 check。
    pub fn has_any_failure(&self) -> bool {
        !self.failed_artifact_ids.is_empty()
            || !self.failed_kinds.is_empty()
            || self.observed_self_mutation
    }

    /// Project the structured report onto the 4-bit hard_bits
    /// bitfield used by `bas_sovereign_integrity_scan` in
    /// bas-sovereign-c-abi。 Bit positions match
    /// `BAS_HARD_BIT_BR_001 / BR_002 / BR_006 / BR_007`。
    pub fn as_hard_bits(&self) -> u16 {
        let mut bits: u16 = 0;
        if self.failed_kinds.contains(&ArtifactKind::ModelOrPolicyArtifact) {
            bits |= 0x0001; // BR-001
        }
        if self.failed_kinds.contains(&ArtifactKind::ThoughtFoldOrCache) {
            bits |= 0x0002; // BR-002
        }
        if self.failed_kinds.contains(&ArtifactKind::SovereignPolicyBundle) {
            bits |= 0x0020; // BR-006
        }
        if self.failed_kinds.contains(&ArtifactKind::RuntimeImage)
            || self.observed_self_mutation
        {
            bits |= 0x0040; // BR-007 (image OR observed-self-mutation)
        }
        bits
    }
}

// MARK: - scan_artifacts pure fn (knife 二 / M2452)

/// Pure-fn verifier:given a `ScanRequest` + trusted fingerprint
/// map,produces a `ScanReport`。 Mirrors the Swift
/// `BASSovereignIntegritySentinel.scan(_:)` method line-for-line。
///
/// Behavior:
///   1. Iterate over `request.claims` in INSERTION ORDER
///      (preserves Swift's `failedIDs` ordering)
///   2. For each claim:
///      a. Look up `trusted[claim.id]`
///      b. UNKNOWN id (no entry) → claim FAILS (conservative
///         per Swift line 162-163 + Swift fail-when-trusted-nil)
///      c. KNOWN id → compare `claim.claimed_hash` to the
///         stored hash CASE-INSENSITIVELY (both sides lowercased
///         before compare,defensive vs Swift's pre-lowercased
///         storage assumption)
///   3. Forward `observed_self_mutation` from the request to the
///      report verbatim (Swift line 172)
///
/// Fingerprint map type:`BTreeMap<String, String>` provides
/// deterministic id-string iteration order。 Used here mainly as
/// the recommended caller-side storage type — the scan loop
/// iterates over `request.claims` (not over the trusted map) so
/// the report's `failed_artifact_ids` ordering depends on claim
/// order,not trusted-map order。
///
/// Output ordering pins:
///   - `failed_artifact_ids` = insertion order of failed claims
///   - `failed_kinds` = ascending discriminant order (BTreeSet)
///   - `observed_self_mutation` = pass-through
///
/// Pure function:no I/O,no shared state,no panics on any input。
/// chapter 七百六十 第二刀 / M2452。
pub fn scan_artifacts(
    request: &ScanRequest,
    trusted: &BTreeMap<String, String>,
) -> ScanReport {
    let mut failed_ids: Vec<String> = Vec::new();
    let mut failed_kinds: BTreeSet<ArtifactKind> = BTreeSet::new();

    for claim in &request.claims {
        let claimed_lower = claim.claimed_hash.to_ascii_lowercase();
        let matches = match trusted.get(&claim.id) {
            Some(expected) => expected.to_ascii_lowercase() == claimed_lower,
            None => false, // unknown artifact → conservative fail
        };
        if !matches {
            failed_ids.push(claim.id.clone());
            failed_kinds.insert(claim.kind);
        }
    }

    ScanReport {
        failed_artifact_ids: failed_ids,
        failed_kinds,
        observed_self_mutation: request.observed_self_mutation,
    }
}

/// Convenience builder:produce a trusted-fingerprint `BTreeMap`
/// from `(id, hash)` pairs。 Stores values already-lowercased so
/// repeated scans don't pay the lowercase cost twice。
///
/// Mirrors the Swift `registerFingerprints(_ pairs: [String:String])`
/// bulk-load method。 Useful for test fixtures + bootstrap from a
/// signed manifest。
pub fn build_trusted_fingerprints<I, S1, S2>(pairs: I) -> BTreeMap<String, String>
where
    I: IntoIterator<Item = (S1, S2)>,
    S1: Into<String>,
    S2: AsRef<str>,
{
    let mut map = BTreeMap::new();
    for (id, hash) in pairs {
        map.insert(id.into(), hash.as_ref().to_ascii_lowercase());
    }
    map
}

// MARK: - ABI version

/// ABI version pin for the bas-integrity-sentinel crate。 Bumped
/// when the structured-report wire format changes (new field
/// added,existing field semantics change,enum discriminants
/// renumbered)。
pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_integrity_sentinel_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests (knife 一 scaffold)

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned_at_v1() {
        assert_eq!(bas_integrity_sentinel_abi_version(), 1);
    }

    #[test]
    fn test_artifact_kind_all_4_present() {
        assert_eq!(ArtifactKind::ALL.len(), 4,
            "knife 一 corpus must define exactly 4 ArtifactKind \
             variants (mirrors Swift BASSovereignIntegritySentinel \
             .ArtifactKind.allCases)");
    }

    #[test]
    fn test_artifact_kind_discriminants_pinned() {
        // Wire-format discriminants MUST match the chapter 七百五十八
        // BAS_ARTIFACT_KIND_* constants exactly。
        assert_eq!(ArtifactKind::ModelOrPolicyArtifact as u8, 0);
        assert_eq!(ArtifactKind::SovereignPolicyBundle as u8, 1);
        assert_eq!(ArtifactKind::ThoughtFoldOrCache as u8, 2);
        assert_eq!(ArtifactKind::RuntimeImage as u8, 3);
    }

    #[test]
    fn test_artifact_kind_from_u8_round_trip() {
        for &k in &ArtifactKind::ALL {
            let u = k as u8;
            assert_eq!(ArtifactKind::from_u8(u), Some(k));
        }
        // Out-of-range values must return None。
        assert_eq!(ArtifactKind::from_u8(4), None);
        assert_eq!(ArtifactKind::from_u8(255), None);
    }

    #[test]
    fn test_artifact_claim_new() {
        let c = ArtifactClaim::new(
            "model.weights",
            "deadbeef",
            ArtifactKind::ModelOrPolicyArtifact);
        assert_eq!(c.id, "model.weights");
        assert_eq!(c.claimed_hash, "deadbeef");
        assert_eq!(c.kind, ArtifactKind::ModelOrPolicyArtifact);
    }

    #[test]
    fn test_scan_request_construction() {
        let claims = vec![
            ArtifactClaim::new(
                "a", "0", ArtifactKind::ModelOrPolicyArtifact),
        ];
        let req = ScanRequest::new(claims.clone(), false);
        assert_eq!(req.claims, claims);
        assert!(!req.observed_self_mutation);
    }

    #[test]
    fn test_scan_report_clean() {
        let r = ScanReport::clean();
        assert!(r.failed_artifact_ids.is_empty());
        assert!(r.failed_kinds.is_empty());
        assert!(!r.observed_self_mutation);
        assert!(!r.has_any_failure());
        assert_eq!(r.as_hard_bits(), 0);
    }

    #[test]
    fn test_scan_report_has_any_failure_id_only() {
        let mut r = ScanReport::clean();
        r.failed_artifact_ids.push("x".to_string());
        assert!(r.has_any_failure());
    }

    #[test]
    fn test_scan_report_has_any_failure_kind_only() {
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::RuntimeImage);
        assert!(r.has_any_failure());
    }

    #[test]
    fn test_scan_report_has_any_failure_self_mutation_only() {
        let mut r = ScanReport::clean();
        r.observed_self_mutation = true;
        assert!(r.has_any_failure());
    }

    #[test]
    fn test_scan_report_as_hard_bits_each_kind() {
        // BR-001 bit
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::ModelOrPolicyArtifact);
        assert_eq!(r.as_hard_bits(), 0x0001);

        // BR-002 bit
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::ThoughtFoldOrCache);
        assert_eq!(r.as_hard_bits(), 0x0002);

        // BR-006 bit
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::SovereignPolicyBundle);
        assert_eq!(r.as_hard_bits(), 0x0020);

        // BR-007 bit via runtime image
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::RuntimeImage);
        assert_eq!(r.as_hard_bits(), 0x0040);

        // BR-007 bit via observed self-mutation alone (no kind failed)
        let mut r = ScanReport::clean();
        r.observed_self_mutation = true;
        assert_eq!(r.as_hard_bits(), 0x0040);
    }

    #[test]
    fn test_scan_report_as_hard_bits_combined() {
        // All 4 kinds failed + self-mutation → all 4 bits lit。
        let mut r = ScanReport::clean();
        for &k in &ArtifactKind::ALL {
            r.failed_kinds.insert(k);
        }
        r.observed_self_mutation = true;
        let bits = r.as_hard_bits();
        assert_eq!(bits & 0x0001, 0x0001, "BR-001 lit");
        assert_eq!(bits & 0x0002, 0x0002, "BR-002 lit");
        assert_eq!(bits & 0x0020, 0x0020, "BR-006 lit");
        assert_eq!(bits & 0x0040, 0x0040, "BR-007 lit");
    }

    #[test]
    fn test_scan_report_failed_kinds_btreeset_ordering() {
        // Insert kinds in REVERSE discriminant order;BTreeSet
        // iteration must surface them in ASCENDING discriminant order。
        let mut r = ScanReport::clean();
        r.failed_kinds.insert(ArtifactKind::RuntimeImage);          // 3
        r.failed_kinds.insert(ArtifactKind::ModelOrPolicyArtifact); // 0
        r.failed_kinds.insert(ArtifactKind::ThoughtFoldOrCache);    // 2
        r.failed_kinds.insert(ArtifactKind::SovereignPolicyBundle); // 1

        let ordered: Vec<ArtifactKind> = r.failed_kinds.iter().copied().collect();
        assert_eq!(ordered, vec![
            ArtifactKind::ModelOrPolicyArtifact, // discriminant 0
            ArtifactKind::SovereignPolicyBundle, // discriminant 1
            ArtifactKind::ThoughtFoldOrCache,    // discriminant 2
            ArtifactKind::RuntimeImage,          // discriminant 3
        ]);
    }

    // MARK: - scan_artifacts knife 二 / M2452 tests

    #[test]
    fn test_scan_empty_claims_empty_trusted_returns_clean() {
        let req = ScanRequest::new(Vec::new(), false);
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report, ScanReport::clean());
    }

    #[test]
    fn test_scan_empty_claims_with_self_mutation_forwards_flag() {
        let req = ScanRequest::new(Vec::new(), true);
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let report = scan_artifacts(&req, &trusted);
        assert!(report.observed_self_mutation,
            "observed_self_mutation must pass through to report");
        assert!(report.failed_artifact_ids.is_empty());
        assert!(report.failed_kinds.is_empty());
    }

    #[test]
    fn test_scan_known_artifact_matching_hash_passes() {
        let trusted = build_trusted_fingerprints(vec![
            ("model.weights", "deadbeef"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "model.weights",
                "deadbeef",
                ArtifactKind::ModelOrPolicyArtifact),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert!(report.failed_artifact_ids.is_empty(),
            "matching hash → no failures");
        assert!(report.failed_kinds.is_empty());
    }

    #[test]
    fn test_scan_known_artifact_mismatched_hash_fails() {
        let trusted = build_trusted_fingerprints(vec![
            ("model.weights", "deadbeef"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "model.weights",
                "cafef00d",  // ≠ trusted "deadbeef"
                ArtifactKind::ModelOrPolicyArtifact),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report.failed_artifact_ids,
            vec!["model.weights".to_string()]);
        assert!(report.failed_kinds.contains(
            &ArtifactKind::ModelOrPolicyArtifact));
        assert_eq!(report.as_hard_bits(), 0x0001,
            "BR-001 bit lit on model-artifact failure");
    }

    #[test]
    fn test_scan_unknown_artifact_fails_conservatively() {
        // Per Swift line 162-163:unknown artifact (no entry in
        // trusted) MUST count as a failure。 The sentinel cannot
        // vouch for what it has no ground truth for。
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "mystery.artifact",
                "deadbeef",
                ArtifactKind::SovereignPolicyBundle),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report.failed_artifact_ids,
            vec!["mystery.artifact".to_string()]);
        assert!(report.failed_kinds.contains(
            &ArtifactKind::SovereignPolicyBundle));
        assert_eq!(report.as_hard_bits(), 0x0020,
            "BR-006 bit lit on policy-bundle failure");
    }

    #[test]
    fn test_scan_case_insensitive_hash_compare_uppercase_claim() {
        // Trusted stored lowercase;claim hash UPPERCASE;match。
        let trusted = build_trusted_fingerprints(vec![
            ("policy.bundle", "abcdef0123456789"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "policy.bundle",
                "ABCDEF0123456789",
                ArtifactKind::SovereignPolicyBundle),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert!(report.failed_artifact_ids.is_empty(),
            "uppercase claim must match lowercase trusted");
    }

    #[test]
    fn test_scan_case_insensitive_hash_compare_uppercase_trusted() {
        // Defensive:trusted stored mixed-case;claim hash lowercase;
        // match。 build_trusted_fingerprints already lowercases on
        // insertion,but scan_artifacts must defensively lowercase
        // both sides too。
        let mut trusted: BTreeMap<String, String> = BTreeMap::new();
        trusted.insert(
            "thought.fold".to_string(),
            "ABCDEF0123456789".to_string()); // NOT lowercased
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "thought.fold",
                "abcdef0123456789",
                ArtifactKind::ThoughtFoldOrCache),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert!(report.failed_artifact_ids.is_empty(),
            "defensive both-sides-lowercase compare must match");
    }

    #[test]
    fn test_scan_observed_self_mutation_alone_lights_br_007() {
        // No failed kinds,but self-mutation flag set → BR-007 lit。
        let trusted = build_trusted_fingerprints(vec![
            ("runtime.image", "abc"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "runtime.image",
                "abc",
                ArtifactKind::RuntimeImage),
        ], true);
        let report = scan_artifacts(&req, &trusted);
        assert!(report.failed_artifact_ids.is_empty(),
            "runtime image claim must pass (matches trusted)");
        assert!(report.failed_kinds.is_empty(),
            "no kind failed,but self_mutation still flips BR-007");
        assert!(report.observed_self_mutation);
        assert_eq!(report.as_hard_bits(), 0x0040,
            "BR-007 lit via observed_self_mutation alone");
    }

    #[test]
    fn test_scan_failed_ids_preserve_claim_insertion_order() {
        // Claims iterated in insertion order;failedIDs accumulated
        // in same order。 Verify ordering by failing claims at
        // positions 0,2,3 in a 4-claim batch。
        let trusted = build_trusted_fingerprints(vec![
            ("a", "match_a"),
            ("b", "match_b"),
            ("c", "match_c"),
            ("d", "match_d"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "a", "WRONG", ArtifactKind::ModelOrPolicyArtifact), // FAIL[0]
            ArtifactClaim::new(
                "b", "match_b", ArtifactKind::ModelOrPolicyArtifact),
            ArtifactClaim::new(
                "c", "WRONG", ArtifactKind::ThoughtFoldOrCache), // FAIL[2]
            ArtifactClaim::new(
                "d", "WRONG", ArtifactKind::RuntimeImage), // FAIL[3]
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report.failed_artifact_ids,
            vec!["a".to_string(), "c".to_string(), "d".to_string()],
            "failed_ids preserves claim insertion order");
    }

    #[test]
    fn test_scan_failed_kinds_deduped_in_set() {
        // 3 claims of the same kind fail → failed_kinds set has 1 entry。
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "a", "0", ArtifactKind::ModelOrPolicyArtifact),
            ArtifactClaim::new(
                "b", "0", ArtifactKind::ModelOrPolicyArtifact),
            ArtifactClaim::new(
                "c", "0", ArtifactKind::ModelOrPolicyArtifact),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report.failed_artifact_ids.len(), 3);
        assert_eq!(report.failed_kinds.len(), 1,
            "BTreeSet dedupes repeated kind");
    }

    #[test]
    fn test_scan_all_4_kinds_failed_combined_hard_bits() {
        // One claim of each kind,all unknown → all 4 BR bits lit。
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "a", "x", ArtifactKind::ModelOrPolicyArtifact),
            ArtifactClaim::new(
                "b", "x", ArtifactKind::SovereignPolicyBundle),
            ArtifactClaim::new(
                "c", "x", ArtifactKind::ThoughtFoldOrCache),
            ArtifactClaim::new(
                "d", "x", ArtifactKind::RuntimeImage),
        ], false);
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report.failed_artifact_ids.len(), 4);
        assert_eq!(report.failed_kinds.len(), 4);
        assert_eq!(report.as_hard_bits(),
            0x0001 | 0x0002 | 0x0020 | 0x0040);
    }

    #[test]
    fn test_build_trusted_fingerprints_lowercases_on_insert() {
        let trusted = build_trusted_fingerprints(vec![
            ("id1", "DEADBEEF"),
            ("id2", "MixedCASE"),
        ]);
        assert_eq!(trusted.get("id1"), Some(&"deadbeef".to_string()));
        assert_eq!(trusted.get("id2"), Some(&"mixedcase".to_string()));
    }

    #[test]
    fn test_scan_self_mutation_does_not_promote_passed_image_to_id_failure() {
        // Self-mutation flag lights BR-007 but does NOT add the
        // runtime.image claim to failed_artifact_ids when that
        // claim itself passed verification。 Per Swift behavior:
        // failed_ids = ID-level failures only;BR-007 bit = OR
        // of kind-failure + self-mutation。
        let trusted = build_trusted_fingerprints(vec![
            ("runtime.image", "good_hash"),
        ]);
        let req = ScanRequest::new(vec![
            ArtifactClaim::new(
                "runtime.image",
                "good_hash",
                ArtifactKind::RuntimeImage),
        ], true);
        let report = scan_artifacts(&req, &trusted);
        assert!(report.failed_artifact_ids.is_empty(),
            "passing claim must NOT appear in failed_artifact_ids");
        assert!(!report.failed_kinds.contains(&ArtifactKind::RuntimeImage),
            "passing claim must NOT appear in failed_kinds");
        assert!(report.observed_self_mutation);
        assert_eq!(report.as_hard_bits(), 0x0040,
            "BR-007 lit only via observed_self_mutation");
    }
}
