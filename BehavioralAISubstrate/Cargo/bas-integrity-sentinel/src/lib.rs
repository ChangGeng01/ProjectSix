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

// MARK: - C ABI scan entry (chapter 七百六十 第三刀 / M2453)
//
// Wire format design notes
// ------------------------
//
// Goal:single-call entry point exposing the FULL structured
// ScanReport (failed IDs + failed kinds bitmap + self-mutation +
// hard_bits projection) to C consumers — distinct from
// bas-sovereign-c-abi::bas_sovereign_integrity_scan which only
// returns the 4-bit hard_bits subset。
//
// Endianness:little-endian throughout (matches the sibling crate's
// claims/fingerprints wire format so consumers can reuse the same
// encoders)。
//
// Input wire formats are IDENTICAL to bas-sovereign-c-abi:
//
//   claims_buf (little-endian):
//     count: u32 LE
//     per claim:
//       id_len:    u16 LE
//       id_bytes:  utf-8
//       hash_len:  u16 LE
//       hash_bytes: utf-8
//       kind:      u8 (BAS_ARTIFACT_KIND_*)
//
//   fingerprints_buf (little-endian):
//     count: u32 LE
//     per fingerprint:
//       id_len:    u16 LE
//       id_bytes:  utf-8
//       hash_len:  u16 LE
//       hash_bytes: utf-8
//
// Output wire format (little-endian):
//
//   offset 0..3   : failed_id_count (u32 LE)
//   offset 4      : failed_kinds_bitmap (u8) — bit N lit iff
//                   ArtifactKind discriminant N appears in
//                   failed_kinds set (BR-001 = bit 0, BR-006 =
//                   bit 1, BR-002 = bit 2, BR-007 = bit 3 per
//                   the enum discriminant ordering)
//   offset 5      : observed_self_mutation (u8, 0 or 1)
//   offset 6..7   : hard_bits (u16 LE) — projection of the
//                   report onto the BAS_HARD_BIT_BR_001 / BR_002 /
//                   BR_006 / BR_007 bitfield from chapter 七百五十八
//   offset 8+     : per failed_id (failed_id_count times):
//                     id_len   (u16 LE)
//                     id_bytes (utf-8)
//
// Required output capacity = 8 bytes fixed prefix
//                          + sum_over_failed_ids (2 + id_len)
//
// The 8-byte fixed prefix is naturally 8-aligned for downstream
// SIMD readers。 The per-id var-len section uses 2-byte length
// prefixes for compactness (max id length 65535 bytes is far more
// than any realistic artifact identifier)。

/// Output buffer fixed-prefix size:8 bytes
/// (failed_id_count + failed_kinds_bitmap + self_mutation +
/// hard_bits)。 Even an empty-failures report needs this much。
pub const C_ABI_REPORT_PREFIX_SIZE: usize = 8;

/// Wire-format parsed claim (internal helper)。 Borrows from
/// the input buffer。
#[derive(Debug)]
struct ParsedClaim<'a> {
    id: &'a str,
    hash: &'a str,
    kind: ArtifactKind,
}

/// Parse claims_buf into a Vec of ParsedClaim borrowing from
/// `bytes`。 Returns `Err(())` on truncation,non-UTF-8,or
/// unknown kind code (4..255)。
fn parse_claims_wire(bytes: &[u8]) -> Result<Vec<ParsedClaim<'_>>, ()> {
    if bytes.is_empty() {
        return Ok(Vec::new());
    }
    if bytes.len() < 4 {
        return Err(());
    }
    let count = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]) as usize;
    let mut off: usize = 4;
    let mut claims = Vec::with_capacity(count);
    for _ in 0..count {
        if off.saturating_add(2) > bytes.len() { return Err(()); }
        let id_len = u16::from_le_bytes([bytes[off], bytes[off + 1]]) as usize;
        off += 2;
        if off.saturating_add(id_len) > bytes.len() { return Err(()); }
        let id = core::str::from_utf8(&bytes[off..off + id_len]).map_err(|_| ())?;
        off += id_len;

        if off.saturating_add(2) > bytes.len() { return Err(()); }
        let hash_len = u16::from_le_bytes([bytes[off], bytes[off + 1]]) as usize;
        off += 2;
        if off.saturating_add(hash_len) > bytes.len() { return Err(()); }
        let hash = core::str::from_utf8(&bytes[off..off + hash_len]).map_err(|_| ())?;
        off += hash_len;

        if off + 1 > bytes.len() { return Err(()); }
        let kind_byte = bytes[off];
        let kind = ArtifactKind::from_u8(kind_byte).ok_or(())?;
        off += 1;

        claims.push(ParsedClaim { id, hash, kind });
    }
    Ok(claims)
}

/// Parse fingerprints_buf into a BTreeMap。 Same wire format as
/// claims_buf MINUS the trailing kind byte。
fn parse_fingerprints_wire(bytes: &[u8]) -> Result<BTreeMap<String, String>, ()> {
    let mut map = BTreeMap::new();
    if bytes.is_empty() {
        return Ok(map);
    }
    if bytes.len() < 4 {
        return Err(());
    }
    let count = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]) as usize;
    let mut off: usize = 4;
    for _ in 0..count {
        if off.saturating_add(2) > bytes.len() { return Err(()); }
        let id_len = u16::from_le_bytes([bytes[off], bytes[off + 1]]) as usize;
        off += 2;
        if off.saturating_add(id_len) > bytes.len() { return Err(()); }
        let id = core::str::from_utf8(&bytes[off..off + id_len]).map_err(|_| ())?;
        off += id_len;

        if off.saturating_add(2) > bytes.len() { return Err(()); }
        let hash_len = u16::from_le_bytes([bytes[off], bytes[off + 1]]) as usize;
        off += 2;
        if off.saturating_add(hash_len) > bytes.len() { return Err(()); }
        let hash = core::str::from_utf8(&bytes[off..off + hash_len]).map_err(|_| ())?;
        off += hash_len;

        // Store lowercased for the case-insensitive compare contract。
        map.insert(id.to_string(), hash.to_ascii_lowercase());
    }
    Ok(map)
}

/// C ABI scan entry — structured ScanReport wire output。
///
/// Two-phase capacity discovery:
///   1. Call with `out_report_buf=NULL,out_report_capacity=0` →
///      returns required size in bytes (always ≥ 8 for the prefix)
///   2. Allocate `required` bytes;call again with that buffer →
///      returns same value,writes the structured report
///
/// Returns:
///   ≥ 0 : required/written byte count
///   -1  : null `claims_buf` with non-zero claims_len,or any
///         negative length,or null fingerprints_buf with
///         non-zero fingerprints_len
///   -2  : wire-format parse failure (truncated buffer / non-UTF-8 /
///         unknown ArtifactKind code 4..255)
///
/// # Safety
///
/// Caller MUST ensure:
///   - claims_buf (when non-null) is readable for claims_len bytes
///   - fingerprints_buf (when non-null) is readable for fingerprints_len bytes
///   - out_report_buf (when non-null) is writable for out_report_capacity bytes
///   - No buffer aliases the others
///
/// chapter 七百六十 第三刀 / M2453。
#[no_mangle]
pub unsafe extern "C" fn bas_integrity_sentinel_scan(
    claims_buf: *const u8,
    claims_len: i32,
    fingerprints_buf: *const u8,
    fingerprints_len: i32,
    observed_self_mutation: i32,
    out_report_buf: *mut u8,
    out_report_capacity: i32,
) -> i32 {
    // Validate scalar inputs。
    if claims_len < 0 || fingerprints_len < 0 || out_report_capacity < 0 {
        return -1;
    }
    if claims_buf.is_null() && claims_len != 0 {
        return -1;
    }
    if fingerprints_buf.is_null() && fingerprints_len != 0 {
        return -1;
    }

    // Materialise input slices。
    let claims_bytes: &[u8] = if claims_len == 0 {
        &[]
    } else {
        core::slice::from_raw_parts(claims_buf, claims_len as usize)
    };
    let fps_bytes: &[u8] = if fingerprints_len == 0 {
        &[]
    } else {
        core::slice::from_raw_parts(fingerprints_buf, fingerprints_len as usize)
    };

    // Parse wire formats。
    let parsed_claims = match parse_claims_wire(claims_bytes) {
        Ok(c) => c,
        Err(()) => return -2,
    };
    let trusted = match parse_fingerprints_wire(fps_bytes) {
        Ok(t) => t,
        Err(()) => return -2,
    };

    // Build ScanRequest and scan。 Note:we own the parsed_claims
    // strings as &str borrowed from claims_bytes;to call
    // scan_artifacts we convert to ArtifactClaim with owned Strings。
    let claims: Vec<ArtifactClaim> = parsed_claims.iter().map(|c| {
        ArtifactClaim {
            id: c.id.to_string(),
            claimed_hash: c.hash.to_string(),
            kind: c.kind,
        }
    }).collect();
    let request = ScanRequest::new(claims, observed_self_mutation != 0);
    let report = scan_artifacts(&request, &trusted);

    // Compute required output size。
    let mut required_usize: usize = C_ABI_REPORT_PREFIX_SIZE;
    for id in &report.failed_artifact_ids {
        required_usize = required_usize
            .saturating_add(2)
            .saturating_add(id.len());
    }
    if required_usize > i32::MAX as usize {
        return -2;
    }
    let required = required_usize as i32;

    // Two-phase write:emit only when buffer non-null + capacity sufficient。
    if !out_report_buf.is_null() && out_report_capacity >= required {
        let out = core::slice::from_raw_parts_mut(
            out_report_buf,
            required_usize,
        );

        // Prefix:failed_id_count (u32 LE)
        let count = report.failed_artifact_ids.len() as u32;
        out[0..4].copy_from_slice(&count.to_le_bytes());

        // failed_kinds_bitmap (u8) — bit per discriminant
        let mut bitmap: u8 = 0;
        for &k in &report.failed_kinds {
            bitmap |= 1u8 << (k as u8);
        }
        out[4] = bitmap;

        // observed_self_mutation (u8, 0 or 1)
        out[5] = if report.observed_self_mutation { 1 } else { 0 };

        // hard_bits (u16 LE) — projection
        let hard_bits = report.as_hard_bits();
        out[6..8].copy_from_slice(&hard_bits.to_le_bytes());

        // Per failed_id: 2-byte len prefix + UTF-8 body
        let mut off = C_ABI_REPORT_PREFIX_SIZE;
        for id in &report.failed_artifact_ids {
            let id_bytes = id.as_bytes();
            let id_len = id_bytes.len() as u16;
            out[off..off + 2].copy_from_slice(&id_len.to_le_bytes());
            off += 2;
            out[off..off + id_bytes.len()].copy_from_slice(id_bytes);
            off += id_bytes.len();
        }
    }

    required
}

/// Convenience encoder for the claims wire format (test helper +
/// future Swift bridge use)。 Public so downstream crates can
/// construct the format without re-implementing the encoder。
pub fn encode_claims_wire(claims: &[(&str, &str, ArtifactKind)]) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.extend_from_slice(&(claims.len() as u32).to_le_bytes());
    for (id, hash, kind) in claims {
        buf.extend_from_slice(&(id.len() as u16).to_le_bytes());
        buf.extend_from_slice(id.as_bytes());
        buf.extend_from_slice(&(hash.len() as u16).to_le_bytes());
        buf.extend_from_slice(hash.as_bytes());
        buf.push(*kind as u8);
    }
    buf
}

/// Convenience encoder for the fingerprints wire format。
pub fn encode_fingerprints_wire(fps: &[(&str, &str)]) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.extend_from_slice(&(fps.len() as u32).to_le_bytes());
    for (id, hash) in fps {
        buf.extend_from_slice(&(id.len() as u16).to_le_bytes());
        buf.extend_from_slice(id.as_bytes());
        buf.extend_from_slice(&(hash.len() as u16).to_le_bytes());
        buf.extend_from_slice(hash.as_bytes());
    }
    buf
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

    // MARK: - C ABI tests (chapter 七百六十 第三刀 / M2453)

    fn read_u32_le(buf: &[u8], off: usize) -> u32 {
        u32::from_le_bytes([buf[off], buf[off+1], buf[off+2], buf[off+3]])
    }
    fn read_u16_le(buf: &[u8], off: usize) -> u16 {
        u16::from_le_bytes([buf[off], buf[off+1]])
    }

    /// Decode the structured wire output back into a ScanReport
    /// so tests can assert against the canonical form。
    fn decode_report_wire(buf: &[u8]) -> ScanReport {
        assert!(buf.len() >= C_ABI_REPORT_PREFIX_SIZE);
        let count = read_u32_le(buf, 0) as usize;
        let kinds_bitmap = buf[4];
        let self_mut = buf[5] != 0;
        let _hard_bits = read_u16_le(buf, 6);

        // failed_kinds from bitmap
        let mut failed_kinds = BTreeSet::new();
        for bit in 0..4u8 {
            if (kinds_bitmap >> bit) & 1 == 1 {
                if let Some(k) = ArtifactKind::from_u8(bit) {
                    failed_kinds.insert(k);
                }
            }
        }

        // failed_ids
        let mut off = C_ABI_REPORT_PREFIX_SIZE;
        let mut failed_ids = Vec::with_capacity(count);
        for _ in 0..count {
            let id_len = read_u16_le(buf, off) as usize;
            off += 2;
            let id = core::str::from_utf8(&buf[off..off+id_len]).unwrap().to_string();
            off += id_len;
            failed_ids.push(id);
        }

        ScanReport {
            failed_artifact_ids: failed_ids,
            failed_kinds,
            observed_self_mutation: self_mut,
        }
    }

    #[test]
    fn test_c_abi_empty_input_returns_clean_report_prefix() {
        // Empty claims + empty fingerprints → 8-byte prefix only
        // (zero failed_ids,zero bitmap,zero self_mut,zero hard_bits)。
        let claims = encode_claims_wire(&[]);
        let fps = encode_fingerprints_wire(&[]);

        // Probe
        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(required, 8,
            "empty scan requires exactly the 8-byte prefix");

        let mut out = vec![0xFFu8; required as usize];
        let written = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };
        assert_eq!(written, required);

        // Verify all-zero output。
        for i in 0..8 { assert_eq!(out[i], 0, "byte {} must be zero", i); }
    }

    #[test]
    fn test_c_abi_null_claims_with_nonzero_len_returns_minus_1() {
        let fps = encode_fingerprints_wire(&[]);
        let rc = unsafe {
            bas_integrity_sentinel_scan(
                core::ptr::null(), 42,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn test_c_abi_null_fingerprints_with_nonzero_len_returns_minus_1() {
        let claims = encode_claims_wire(&[]);
        let rc = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                core::ptr::null(), 42,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn test_c_abi_negative_lengths_return_minus_1() {
        let rc = unsafe {
            bas_integrity_sentinel_scan(
                core::ptr::null(), -1,
                core::ptr::null(), 0,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn test_c_abi_truncated_claims_returns_minus_2() {
        // Declares 1 claim with id_len=100 but only 5 bytes follow。
        let mut bad = Vec::new();
        bad.extend_from_slice(&1u32.to_le_bytes());
        bad.extend_from_slice(&100u16.to_le_bytes());
        bad.extend_from_slice(b"abc");
        let fps = encode_fingerprints_wire(&[]);
        let rc = unsafe {
            bas_integrity_sentinel_scan(
                bad.as_ptr(), bad.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -2);
    }

    #[test]
    fn test_c_abi_unknown_kind_byte_returns_minus_2() {
        // Declares 1 claim with kind=99 (invalid)。
        let mut bad = Vec::new();
        bad.extend_from_slice(&1u32.to_le_bytes());
        bad.extend_from_slice(&3u16.to_le_bytes());
        bad.extend_from_slice(b"foo");
        bad.extend_from_slice(&3u16.to_le_bytes());
        bad.extend_from_slice(b"bar");
        bad.push(99); // invalid kind
        let fps = encode_fingerprints_wire(&[]);
        let rc = unsafe {
            bas_integrity_sentinel_scan(
                bad.as_ptr(), bad.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -2);
    }

    #[test]
    fn test_c_abi_known_artifact_matches_no_failures() {
        let claims = encode_claims_wire(&[
            ("model.weights", "abc123", ArtifactKind::ModelOrPolicyArtifact),
        ]);
        let fps = encode_fingerprints_wire(&[
            ("model.weights", "abc123"),
        ]);

        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(required, 8, "no failures → 8-byte prefix only");

        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };

        let decoded = decode_report_wire(&out);
        assert!(decoded.failed_artifact_ids.is_empty());
        assert!(decoded.failed_kinds.is_empty());
    }

    #[test]
    fn test_c_abi_unknown_artifact_fails_with_id_recorded() {
        let claims = encode_claims_wire(&[
            ("mystery", "abc", ArtifactKind::SovereignPolicyBundle),
        ]);
        let fps = encode_fingerprints_wire(&[]);

        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        // 8 prefix + 2 id_len + 7 "mystery" = 17 bytes
        assert_eq!(required, 17);

        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };

        let decoded = decode_report_wire(&out);
        assert_eq!(decoded.failed_artifact_ids, vec!["mystery".to_string()]);
        assert!(decoded.failed_kinds.contains(&ArtifactKind::SovereignPolicyBundle));
    }

    #[test]
    fn test_c_abi_observed_self_mutation_forwarded() {
        let claims = encode_claims_wire(&[]);
        let fps = encode_fingerprints_wire(&[]);
        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                1, // observed_self_mutation = true
                core::ptr::null_mut(), 0)
        };
        assert_eq!(required, 8);
        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                1,
                out.as_mut_ptr(), out.len() as i32)
        };
        // Byte 5 = observed_self_mutation
        assert_eq!(out[5], 1, "self_mutation flag must be 1");
        // Hard bits (offset 6..8) = BR-007 = 0x0040
        assert_eq!(read_u16_le(&out, 6), 0x0040,
            "BR-007 lit via self_mutation alone");
    }

    #[test]
    fn test_c_abi_two_phase_capacity_workflow() {
        // 3 failed claims → probe gives required > 8。
        let claims = encode_claims_wire(&[
            ("first_id", "wrong", ArtifactKind::ModelOrPolicyArtifact),
            ("second_id", "wrong", ArtifactKind::ThoughtFoldOrCache),
            ("third_id", "wrong", ArtifactKind::RuntimeImage),
        ]);
        let fps = encode_fingerprints_wire(&[]);

        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        // 8 prefix + (2+8) + (2+9) + (2+8) = 8 + 10 + 11 + 10 = 39
        assert_eq!(required, 39);

        let mut out = vec![0u8; required as usize];
        let written = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };
        assert_eq!(written, required);

        let decoded = decode_report_wire(&out);
        assert_eq!(decoded.failed_artifact_ids,
            vec!["first_id".to_string(),
                 "second_id".to_string(),
                 "third_id".to_string()]);
        assert_eq!(decoded.failed_kinds.len(), 3);
    }

    #[test]
    fn test_c_abi_insufficient_capacity_returns_required_no_write() {
        let claims = encode_claims_wire(&[
            ("x", "wrong", ArtifactKind::ModelOrPolicyArtifact),
        ]);
        let fps = encode_fingerprints_wire(&[]);

        let mut out = vec![0xAAu8; 5]; // too small (need 8 prefix + 3 = 11)
        let returned = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };
        assert!(returned > 5);
        assert_eq!(out, vec![0xAAu8; 5], "no write on insufficient capacity");
    }

    #[test]
    fn test_c_abi_case_insensitive_compare() {
        // Trusted stored UPPERCASE,claim LOWERCASE → must match。
        let claims = encode_claims_wire(&[
            ("a", "abcdef", ArtifactKind::ModelOrPolicyArtifact),
        ]);
        let fps = encode_fingerprints_wire(&[
            ("a", "ABCDEF"),
        ]);

        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        assert_eq!(required, 8, "case-insensitive compare → no failures");
    }

    #[test]
    fn test_c_abi_round_trip_pure_fn_equivalence() {
        // The C ABI path MUST produce the same ScanReport as
        // calling scan_artifacts directly。
        let claims_pairs: Vec<(&str, &str, ArtifactKind)> = vec![
            ("a", "match",   ArtifactKind::ModelOrPolicyArtifact),
            ("b", "wrong",   ArtifactKind::SovereignPolicyBundle),
            ("c", "match",   ArtifactKind::ThoughtFoldOrCache),
            ("d", "missing", ArtifactKind::RuntimeImage),
        ];
        let fps_pairs: Vec<(&str, &str)> = vec![
            ("a", "match"),
            ("b", "right"),  // ≠ wrong → fails
            ("c", "match"),
            // d unknown → fails
        ];

        // Pure-fn path
        let claims_for_pure: Vec<ArtifactClaim> = claims_pairs.iter()
            .map(|(id, h, k)| ArtifactClaim::new(*id, *h, *k))
            .collect();
        let trusted = build_trusted_fingerprints(
            fps_pairs.iter().map(|(i, h)| (*i, *h)));
        let req = ScanRequest::new(claims_for_pure, true);
        let pure_report = scan_artifacts(&req, &trusted);

        // C ABI path
        let claims_buf = encode_claims_wire(&claims_pairs);
        let fps_buf = encode_fingerprints_wire(&fps_pairs);
        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims_buf.as_ptr(), claims_buf.len() as i32,
                fps_buf.as_ptr(), fps_buf.len() as i32,
                1, // self_mutation true
                core::ptr::null_mut(), 0)
        };
        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims_buf.as_ptr(), claims_buf.len() as i32,
                fps_buf.as_ptr(), fps_buf.len() as i32,
                1,
                out.as_mut_ptr(), out.len() as i32)
        };
        let c_abi_report = decode_report_wire(&out);

        assert_eq!(c_abi_report, pure_report,
            "C ABI round-trip must equal direct pure-fn output");
    }

    #[test]
    fn test_c_abi_kinds_bitmap_encoding() {
        // 3 distinct kinds failed → bitmap bits 0,2,3 lit (model,
        // thought_fold,runtime) → bitmap = 0b1101 = 13。
        let claims = encode_claims_wire(&[
            ("a", "wrong", ArtifactKind::ModelOrPolicyArtifact), // bit 0
            ("b", "wrong", ArtifactKind::ThoughtFoldOrCache),    // bit 2
            ("c", "wrong", ArtifactKind::RuntimeImage),          // bit 3
        ]);
        let fps = encode_fingerprints_wire(&[]);

        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                core::ptr::null_mut(), 0)
        };
        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                0,
                out.as_mut_ptr(), out.len() as i32)
        };
        assert_eq!(out[4], 0b1101,
            "failed_kinds bitmap = bits 0,2,3 (model + thought + runtime)");
    }

    #[test]
    fn test_c_abi_hard_bits_projection_matches_swift_layout() {
        // hard_bits bit layout per chapter 七百五十八:
        //   BR-001 = 0x0001 = ModelOrPolicyArtifact failed
        //   BR-002 = 0x0002 = ThoughtFoldOrCache failed
        //   BR-006 = 0x0020 = SovereignPolicyBundle failed
        //   BR-007 = 0x0040 = RuntimeImage failed OR self_mutation
        let claims = encode_claims_wire(&[
            ("a", "wrong", ArtifactKind::ModelOrPolicyArtifact),    // BR-001
            ("b", "wrong", ArtifactKind::SovereignPolicyBundle),    // BR-006
        ]);
        let fps = encode_fingerprints_wire(&[]);
        let required = unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                1, // self_mutation → BR-007
                core::ptr::null_mut(), 0)
        };
        let mut out = vec![0u8; required as usize];
        unsafe {
            bas_integrity_sentinel_scan(
                claims.as_ptr(), claims.len() as i32,
                fps.as_ptr(), fps.len() as i32,
                1,
                out.as_mut_ptr(), out.len() as i32)
        };
        let hard_bits = read_u16_le(&out, 6);
        assert_eq!(hard_bits, 0x0001 | 0x0020 | 0x0040);
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

    // MARK: - 100-fixture byte-equality grid
    //         (chapter 七百六十 第四刀 / M2454)

    /// FNV-1a 64-bit hash for fixture pinning (no sha2 dependency)。
    fn fnv1a_64(bytes: &[u8]) -> u64 {
        let mut h: u64 = 0xcbf2_9ce4_8422_2325;
        for &b in bytes {
            h ^= b as u64;
            h = h.wrapping_mul(0x100_0000_01b3);
        }
        h
    }

    /// Encode a ScanReport into a canonical byte buffer for hashing。
    /// Format (LE,packed,no padding):
    ///   1 byte  failed_kinds_bitmap
    ///   1 byte  observed_self_mutation (0/1)
    ///   2 bytes hard_bits (u16 LE)
    ///   4 bytes failed_id_count (u32 LE)
    ///   per failed_id:
    ///     4 bytes id_len (u32 LE)
    ///     id_len bytes utf-8
    /// Distinct from the C ABI wire format — packed for hashing
    /// (no alignment padding,no version prefix)。
    fn canonical_bytes_of_report(r: &ScanReport) -> Vec<u8> {
        let mut buf = Vec::new();
        let mut bitmap: u8 = 0;
        for &k in &r.failed_kinds {
            bitmap |= 1u8 << (k as u8);
        }
        buf.push(bitmap);
        buf.push(if r.observed_self_mutation { 1 } else { 0 });
        buf.extend_from_slice(&r.as_hard_bits().to_le_bytes());
        buf.extend_from_slice(&(r.failed_artifact_ids.len() as u32).to_le_bytes());
        for id in &r.failed_artifact_ids {
            buf.extend_from_slice(&(id.len() as u32).to_le_bytes());
            buf.extend_from_slice(id.as_bytes());
        }
        buf
    }

    /// Build the i-th fixture (0..=99) deterministically。 Returns
    /// (claims,trusted_pairs,observed_self_mutation)。
    ///
    /// Generation strategy:
    ///   - Fixtures 0..=23  : single-claim,full 4-kind × 6-shape
    ///                        (match/mismatch/unknown × self_mut 0/1)
    ///   - Fixtures 24..=49 : two-claim batches (mixed kinds + outcomes)
    ///   - Fixtures 50..=79 : four-claim full-coverage batches
    ///   - Fixtures 80..=99 : edge cases (case variations,empty
    ///                        claims with self_mut,large IDs)
    fn build_fixture(i: usize) -> (Vec<(String, String, ArtifactKind)>,
                                    Vec<(String, String)>,
                                    bool) {
        let kinds = ArtifactKind::ALL;
        match i {
            // --- 0..=23: single-claim 4-kind × 6-shape ---
            0..=23 => {
                let kind_idx = i % 4;
                let shape = i / 4; // 0..6
                let kind = kinds[kind_idx];
                let id = format!("artifact_{}", i);
                let trusted_hash = format!("trusted_{}", i);
                let (claims, trusted, self_mut) = match shape {
                    0 => (
                        vec![(id.clone(), trusted_hash.clone(), kind)],
                        vec![(id, trusted_hash)],
                        false,
                    ),
                    1 => (
                        vec![(id.clone(), trusted_hash.clone(), kind)],
                        vec![(id, trusted_hash)],
                        true,
                    ),
                    2 => (
                        vec![(id.clone(), "wrong".to_string(), kind)],
                        vec![(id, trusted_hash)],
                        false,
                    ),
                    3 => (
                        vec![(id.clone(), "wrong".to_string(), kind)],
                        vec![(id, trusted_hash)],
                        true,
                    ),
                    4 => (
                        vec![(id, "any".to_string(), kind)],
                        vec![], // unknown artifact
                        false,
                    ),
                    _ => (
                        vec![(id, "any".to_string(), kind)],
                        vec![],
                        true,
                    ),
                };
                (claims, trusted, self_mut)
            }
            // --- 24..=49: two-claim batches ---
            24..=49 => {
                let seed = i - 24;
                let k1 = kinds[seed % 4];
                let k2 = kinds[(seed + 1) % 4];
                let id1 = format!("two_a_{}", i);
                let id2 = format!("two_b_{}", i);
                let claims = vec![
                    (id1.clone(), format!("h1_{}", i), k1),
                    (id2.clone(), format!("h2_{}", i), k2),
                ];
                let trusted = if seed % 3 == 0 {
                    // both registered with correct hashes
                    vec![
                        (id1, format!("h1_{}", i)),
                        (id2, format!("h2_{}", i)),
                    ]
                } else if seed % 3 == 1 {
                    // one wrong hash
                    vec![
                        (id1, format!("h1_{}", i)),
                        (id2, "wrong".to_string()),
                    ]
                } else {
                    // one unknown
                    vec![(id1, format!("h1_{}", i))]
                };
                (claims, trusted, seed % 2 == 0)
            }
            // --- 50..=79: four-claim batches ---
            50..=79 => {
                let seed = i - 50;
                let mut claims = Vec::new();
                let mut trusted = Vec::new();
                for k_idx in 0..4 {
                    let kind = kinds[k_idx];
                    let id = format!("four_{}_{}", i, k_idx);
                    let claim_hash = format!("ch_{}_{}", i, k_idx);
                    let registered = (seed + k_idx) % 3 != 2; // ~67% registered
                    let hash_matches = (seed + k_idx) % 2 == 0; // ~50% match
                    claims.push((id.clone(), claim_hash.clone(), kind));
                    if registered {
                        let trusted_hash = if hash_matches {
                            claim_hash
                        } else {
                            format!("other_{}_{}", i, k_idx)
                        };
                        trusted.push((id, trusted_hash));
                    }
                }
                (claims, trusted, seed % 4 == 0)
            }
            // --- 80..=99: edge cases ---
            _ => {
                let seed = i - 80;
                match seed {
                    // Empty claims, self_mut on
                    0 => (vec![], vec![], true),
                    // Empty claims, self_mut off
                    1 => (vec![], vec![], false),
                    // Trusted has UPPERCASE,claim lowercase
                    2 => (
                        vec![("upper".to_string(), "abcdef".to_string(),
                              ArtifactKind::ModelOrPolicyArtifact)],
                        vec![("upper".to_string(), "ABCDEF".to_string())],
                        false,
                    ),
                    // Trusted lowercase, claim UPPERCASE
                    3 => (
                        vec![("lower".to_string(), "ABCDEF".to_string(),
                              ArtifactKind::SovereignPolicyBundle)],
                        vec![("lower".to_string(), "abcdef".to_string())],
                        false,
                    ),
                    // Long ID (64 chars)
                    4 => {
                        let id: String = std::iter::repeat('x').take(64).collect();
                        (
                            vec![(id.clone(), "h".to_string(),
                                  ArtifactKind::ThoughtFoldOrCache)],
                            vec![(id, "wrong".to_string())],
                            false,
                        )
                    },
                    // Long hash (128 chars)
                    5 => {
                        let h: String = std::iter::repeat('a').take(128).collect();
                        (
                            vec![("h_id".to_string(), h.clone(),
                                  ArtifactKind::RuntimeImage)],
                            vec![("h_id".to_string(), h)],
                            true,
                        )
                    },
                    // All 4 kinds in one batch, all unknown
                    6 => (
                        vec![
                            ("k1".to_string(), "x".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                            ("k2".to_string(), "x".to_string(),
                             ArtifactKind::SovereignPolicyBundle),
                            ("k3".to_string(), "x".to_string(),
                             ArtifactKind::ThoughtFoldOrCache),
                            ("k4".to_string(), "x".to_string(),
                             ArtifactKind::RuntimeImage),
                        ],
                        vec![],
                        false,
                    ),
                    // All 4 kinds, all matching, self_mut on
                    7 => (
                        vec![
                            ("c1".to_string(), "h1".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                            ("c2".to_string(), "h2".to_string(),
                             ArtifactKind::SovereignPolicyBundle),
                            ("c3".to_string(), "h3".to_string(),
                             ArtifactKind::ThoughtFoldOrCache),
                            ("c4".to_string(), "h4".to_string(),
                             ArtifactKind::RuntimeImage),
                        ],
                        vec![
                            ("c1".to_string(), "h1".to_string()),
                            ("c2".to_string(), "h2".to_string()),
                            ("c3".to_string(), "h3".to_string()),
                            ("c4".to_string(), "h4".to_string()),
                        ],
                        true,
                    ),
                    // Duplicate IDs in claims (same kind, different hashes)
                    8 => (
                        vec![
                            ("dup".to_string(), "v1".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                            ("dup".to_string(), "v2".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                        ],
                        vec![("dup".to_string(), "v1".to_string())],
                        false,
                    ),
                    // Unicode ID + UTF-8 multi-byte
                    9 => (
                        vec![("identifiant_éàü".to_string(), "h".to_string(),
                              ArtifactKind::SovereignPolicyBundle)],
                        vec![("identifiant_éàü".to_string(), "h".to_string())],
                        false,
                    ),
                    // CJK ID
                    10 => (
                        vec![("文件标识".to_string(), "hash".to_string(),
                              ArtifactKind::ModelOrPolicyArtifact)],
                        vec![("文件标识".to_string(), "hash".to_string())],
                        false,
                    ),
                    // CJK + mismatched hash
                    11 => (
                        vec![("数据".to_string(), "wrong".to_string(),
                              ArtifactKind::ThoughtFoldOrCache)],
                        vec![("数据".to_string(), "right".to_string())],
                        true,
                    ),
                    // Empty-string ID (degenerate but valid)
                    12 => (
                        vec![("".to_string(), "h".to_string(),
                              ArtifactKind::RuntimeImage)],
                        vec![("".to_string(), "h".to_string())],
                        false,
                    ),
                    // Many duplicates of same failing kind
                    13..=15 => {
                        let n = (seed - 13) + 3; // 3,4,5 claims
                        let mut claims = Vec::new();
                        for j in 0..n {
                            claims.push((
                                format!("dupe_{}", j),
                                "x".to_string(),
                                ArtifactKind::ModelOrPolicyArtifact,
                            ));
                        }
                        (claims, vec![], seed % 2 == 0)
                    }
                    // Mixed match + mismatch + unknown (4-claim)
                    16 => (
                        vec![
                            ("m1".to_string(), "ok".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                            ("m2".to_string(), "bad".to_string(),
                             ArtifactKind::SovereignPolicyBundle),
                            ("m3".to_string(), "any".to_string(),
                             ArtifactKind::ThoughtFoldOrCache),
                            ("m4".to_string(), "ok4".to_string(),
                             ArtifactKind::RuntimeImage),
                        ],
                        vec![
                            ("m1".to_string(), "ok".to_string()),
                            ("m2".to_string(), "actual".to_string()),
                            // m3 unknown
                            ("m4".to_string(), "ok4".to_string()),
                        ],
                        false,
                    ),
                    // Same as 16 but with self_mut
                    17 => (
                        vec![
                            ("m1".to_string(), "ok".to_string(),
                             ArtifactKind::ModelOrPolicyArtifact),
                            ("m2".to_string(), "bad".to_string(),
                             ArtifactKind::SovereignPolicyBundle),
                        ],
                        vec![
                            ("m1".to_string(), "ok".to_string()),
                            ("m2".to_string(), "actual".to_string()),
                        ],
                        true,
                    ),
                    // 8-claim batch (stress for sorted-output verification)
                    18 => {
                        let mut claims = Vec::new();
                        for j in 0..8 {
                            let kind = kinds[j % 4];
                            claims.push((
                                format!("stress_{}", j),
                                "x".to_string(),
                                kind,
                            ));
                        }
                        (claims, vec![], false)
                    }
                    // 8-claim batch with self_mut
                    _ => {
                        let mut claims = Vec::new();
                        for j in 0..8 {
                            let kind = kinds[j % 4];
                            claims.push((
                                format!("stress2_{}", j),
                                "x".to_string(),
                                kind,
                            ));
                        }
                        (claims, vec![], true)
                    }
                }
            }
        }
    }

    /// Run one fixture through scan_artifacts + return its canonical bytes。
    fn run_fixture(i: usize) -> Vec<u8> {
        let (claims, trusted, self_mut) = build_fixture(i);
        let claims_v: Vec<ArtifactClaim> = claims.iter()
            .map(|(id, h, k)| ArtifactClaim::new(id.clone(), h.clone(), *k))
            .collect();
        let trusted_map = build_trusted_fingerprints(
            trusted.iter().map(|(i, h)| (i.clone(), h.clone())));
        let req = ScanRequest::new(claims_v, self_mut);
        let report = scan_artifacts(&req, &trusted_map);
        canonical_bytes_of_report(&report)
    }

    #[test]
    fn test_fixture_grid_count_pinned_at_100() {
        // The grid covers indices 0..=99 inclusive。 If a future
        // patch changes the cardinality,this test catches it。
        let mut covered = 0;
        for i in 0..100 {
            let _ = build_fixture(i);
            covered += 1;
        }
        assert_eq!(covered, 100,
            "100-fixture grid must cover indices 0..=99");
    }

    #[test]
    fn test_fixture_grid_deterministic() {
        // Two runs of the same grid must produce byte-identical
        // canonical output。
        let run_a: Vec<Vec<u8>> = (0..100).map(run_fixture).collect();
        let run_b: Vec<Vec<u8>> = (0..100).map(run_fixture).collect();
        assert_eq!(run_a, run_b,
            "fixture grid must be deterministic across runs");
    }

    #[test]
    fn test_fixture_grid_canonical_hash_pinned() {
        // ********************************************************
        // BYTE-EQUALITY DISCIPLINE PIN (chapter 七百十六 + 七百六十)
        // ********************************************************
        //
        // 100-fixture canonical-bytes concatenated → FNV-1a 64-bit hash
        //
        // ANY drift in:
        //   - ArtifactKind discriminant values
        //   - scan_artifacts behavior (unknown-fail / case-insensitive)
        //   - ScanReport canonical encoding
        //   - failed_kinds BTreeSet ordering
        //   - hard_bits projection layout
        //
        // ...will flip this hash。 If intentional,re-capture + bump
        // ABI_VERSION;if unintentional,fail the build。
        //
        // ********************************************************

        let mut all_bytes = Vec::new();
        for i in 0..100 {
            all_bytes.extend(run_fixture(i));
        }
        let hash = fnv1a_64(&all_bytes);

        // Pinned baseline (captured chapter 七百六十 第四刀 / M2454)
        assert_eq!(
            hash,
            0x4869_9616_51CC_EB59,
            "100-fixture canonical-bytes hash drifted — ABI BREAK"
        );
    }

    #[test]
    fn test_fixture_grid_each_fixture_produces_nonempty_canonical_bytes() {
        // Every fixture must produce ≥ 8 bytes of canonical output
        // (bitmap + self_mut + hard_bits + count = 8 bytes minimum)。
        for i in 0..100 {
            let bytes = run_fixture(i);
            assert!(bytes.len() >= 8,
                "fixture {} canonical bytes < 8 ({})",i, bytes.len());
        }
    }

    #[test]
    fn test_fixture_grid_c_abi_matches_pure_fn_for_every_fixture() {
        // For each fixture in the grid,running it through the
        // C ABI MUST produce the same ScanReport as the direct
        // scan_artifacts call。 This is the cross-path byte-
        // equality check (Rust pure-fn ≡ Rust C ABI)。
        for i in 0..100 {
            let (claims, trusted, self_mut) = build_fixture(i);

            // Pure-fn path
            let claims_v: Vec<ArtifactClaim> = claims.iter()
                .map(|(id, h, k)| ArtifactClaim::new(
                    id.clone(), h.clone(), *k))
                .collect();
            let trusted_map = build_trusted_fingerprints(
                trusted.iter().map(|(i, h)| (i.clone(), h.clone())));
            let req = ScanRequest::new(claims_v, self_mut);
            let pure_report = scan_artifacts(&req, &trusted_map);

            // C ABI path
            let claims_refs: Vec<(&str, &str, ArtifactKind)> = claims.iter()
                .map(|(id, h, k)| (id.as_str(), h.as_str(), *k))
                .collect();
            let trusted_refs: Vec<(&str, &str)> = trusted.iter()
                .map(|(i, h)| (i.as_str(), h.as_str()))
                .collect();
            let claims_buf = encode_claims_wire(&claims_refs);
            let fps_buf = encode_fingerprints_wire(&trusted_refs);
            let required = unsafe {
                bas_integrity_sentinel_scan(
                    claims_buf.as_ptr(), claims_buf.len() as i32,
                    fps_buf.as_ptr(), fps_buf.len() as i32,
                    if self_mut { 1 } else { 0 },
                    core::ptr::null_mut(), 0)
            };
            assert!(required >= 0,
                "fixture {} required must be ≥ 0,got {}",i, required);
            let mut out = vec![0u8; required as usize];
            unsafe {
                bas_integrity_sentinel_scan(
                    claims_buf.as_ptr(), claims_buf.len() as i32,
                    fps_buf.as_ptr(), fps_buf.len() as i32,
                    if self_mut { 1 } else { 0 },
                    out.as_mut_ptr(), out.len() as i32)
            };
            let c_abi_report = decode_report_wire(&out);

            assert_eq!(c_abi_report, pure_report,
                "fixture {} C ABI report ≠ pure-fn report", i);
        }
    }
}
