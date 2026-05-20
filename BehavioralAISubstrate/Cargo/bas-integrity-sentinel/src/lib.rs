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
//
// Knife 一 ships ONLY the types + scaffolding。 Knife 二 fleshes
// out the scan_artifacts function。 We provide a stub here that
// returns `ScanReport::clean()` so the crate compiles + tests can
// import the symbol;the real logic lands at knife 二。

/// Pure-fn verifier:given a `ScanRequest` + trusted fingerprint
/// map,produces a `ScanReport`。
///
/// **NOTE (knife 一 stub)**:returns an empty clean report for
/// now。 Knife 二 / M2452 ships the real claim-walking logic
/// mirroring the Swift `scan(_:)` method。
///
/// Fingerprint map ordering:caller passes a `BTreeMap` so the
/// scan loop iterates in deterministic id-string order when
/// reading expected hashes。 (HashMap would still produce the same
/// ScanReport because the loop iterates over `request.claims`,
/// not over the trusted map,but BTreeMap signals the intent that
/// the trusted set is deterministically-ordered storage。)
pub fn scan_artifacts(
    _request: &ScanRequest,
    _trusted: &BTreeMap<String, String>,
) -> ScanReport {
    // Knife 二 placeholder — real implementation lands at M2452。
    ScanReport::clean()
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

    #[test]
    fn test_scan_artifacts_knife_one_stub_returns_clean() {
        // Knife 一 stub:always returns clean。 Knife 二 will
        // replace this with the real walk + this test will be
        // rewritten to verify failure detection。
        let req = ScanRequest::new(Vec::new(), false);
        let trusted: BTreeMap<String, String> = BTreeMap::new();
        let report = scan_artifacts(&req, &trusted);
        assert_eq!(report, ScanReport::clean());
    }
}
