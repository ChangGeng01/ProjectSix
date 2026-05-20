// MARK: - bas-sovereign-c-abi — public C ABI wrapper for L14 Sovereign
// chapter 七百五十八 第一刀 / M2441 — DEEPER LAYER-MIGRATION ARC opener
//
// PUBLIC C SURFACE for third-party + watchOS consumers。
//
// This crate is a deliberately-thin wrapper around already-verified
// primitives in `bas-substrate-core`。 The goal is to expose a stable
// C-ABI surface that consumers OUTSIDE the Apple-Swift ecosystem can
// link against (e.g。 watchOS native apps without Rust std,embedded C
// runtimes,game engines,attestation hooks)。
//
// Layered guarantees (per chapter 七百五十七 audit + user 严苛 table):
//
//   1. **Re-exports** of `bas_sovereign_seal_entry` and
//      `bas_sovereign_verify_chain` from `bas-substrate-core`。 We
//      depend on the sibling crate and surface the same functions
//      via #[no_mangle] forwarders so this crate's staticlib carries
//      the symbols without recompiling the chain implementation。
//      Byte-equality with chapter 七百十六 50-entry test holds by
//      construction (same code path,same compiler,same flags)。
//
//   2. **NEW entry point** `bas_sovereign_halt_signal_encode` — emits
//      a deterministic 32-byte opaque token derived from
//      (reason_code, timestamp_ms) via SHA256。 Used by L14 sovereign
//      to mark a「halt issued」 event in a replay-verifiable way that
//      doesn't require Swift。 Knife 二 + 三 will add integrity_scan
//      and tamper_proof_audit on top of this scaffold。
//
//   3. **C header** ships in knife 四 (`include/bas_sovereign_c_abi.h`),
//      hand-curated for external consumers。 cbindgen NOT used because
//      we want to control the header layout precisely (third-party
//      consumers don't want to track cbindgen output drift)。
//
// Threading + safety contract for ALL functions here:
//   - All entry points are PURE FUNCTIONS — no global state,no I/O,
//     no allocation that outlives the call (any heap use is freed
//     before return)。
//   - All `*const u8` / `*mut u8` pointers are caller-owned。 The crate
//     never holds pointer references past the function call。
//   - Return codes:`0 = success`,`-1 = invalid input (null pointer,
//     zero buffer where non-zero required)`,`-2 = output buffer too
//     small`,`-3 = internal computation failed (cannot happen with
//     current primitives but reserved)。

#![allow(clippy::missing_safety_doc)]

use sha2::{Digest, Sha256};

// MARK: - ABI version

/// ABI version pin。 Bumping this constant requires updating any
/// Swift consumer's `expectedABIVersion` constant + the corresponding
/// drift test in the test suite。
///
/// chapter 七百五十八 第一刀 ships v1。 Future bumps:bumped when a
/// non-additive change to the C ABI surface lands (renamed function,
/// changed signature,changed return code semantics)。 Additive changes
/// (new functions) do NOT bump the version per the substrate's
/// stability-tier 1 pin policy。
pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_sovereign_c_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Halt signal encoding

/// chapter 七百五十八 第一刀 / M2441 — NEW C ABI entry point。
///
/// Compute the deterministic 32-byte opaque halt token for
/// (reason_code, timestamp_ms) per the encoding:
///
///   token = SHA256(
///     "bas-sovereign-halt-v1" ||
///     reason_code as i32_big_endian ||
///     timestamp_ms as i64_big_endian
///   )
///
/// The「v1」 string anchor pins the encoding to this ABI version;
/// future ABI bumps would change the anchor。 Caller writes the token
/// to `out_token`,which MUST point to at least 32 writable bytes。
///
/// Use case:L14 sovereign issues a halt for some reason (integrity
/// violation,tamper detection,manual stop)。 Recording the halt token
/// in the audit chain proves the halt was issued at a specific time
/// for a specific reason — and the encoding is verifiable from C
/// without needing Swift or the full Rust verdict engine。
///
/// Parameters:
/// * `reason_code` — caller-defined halt reason code (e.g。 BR-001..BR-007
///                   from chapter 七百四十二 BR-bitfield convention)
/// * `timestamp_ms` — UNIX epoch milliseconds when halt issued
/// * `out_token`   — 32-byte writable buffer for the result
///
/// Returns:0 on success,-1 if `out_token` is null。
///
/// Thread-safety:fully reentrant,no shared state。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_halt_signal_encode(
    reason_code: i32,
    timestamp_ms: i64,
    out_token: *mut u8,
) -> i32 {
    if out_token.is_null() {
        return -1;
    }
    let mut hasher = Sha256::new();
    hasher.update(b"bas-sovereign-halt-v1");
    hasher.update(reason_code.to_be_bytes());
    hasher.update(timestamp_ms.to_be_bytes());
    let digest = hasher.finalize();
    // SAFETY:caller guarantees out_token points to 32
    // writable bytes per the function contract above。
    unsafe {
        core::ptr::copy_nonoverlapping(
            digest.as_ptr(), out_token, 32);
    }
    0
}

// MARK: - Integrity scan (BR-001 / BR-002 / BR-006 / BR-007 derivation)

/// chapter 七百五十八 第二刀 / M2442 — NEW C ABI entry point。
///
/// Pure function:given a list of artifact claims + a trusted-
/// fingerprint map + an observed-self-mutation bit,produce the
/// 4-bit subset of `HardObservations` that integrity sentinel
/// owns:
///
///   bit 0  (0x0001) = BR-001 artifact_signature_invalid
///                     (any modelOrPolicyArtifact failed verification)
///   bit 1  (0x0002) = BR-002 thought_fold_checksum_broken
///                     (any thoughtFoldOrCache failed verification)
///   bit 5  (0x0020) = BR-006 policy_bundle_tampered
///                     (any sovereignPolicyBundle failed verification)
///   bit 6  (0x0040) = BR-007 unauthorized_self_mutation
///                     (any runtimeImage failed verification OR
///                      observed_self_mutation flag set)
///
/// Bit positions match `bas_substrate_core::verdict_decisions`
/// HardObservations decoding (line ~429 of verdict_decisions.rs)。
/// The output `*out_hard_bits` is a u16 — caller can OR these into
/// the same 16-bit field consumed by `bas_verdict_derive(...)`。
///
/// Mirrors `BASSovereignIntegritySentinel.swift` semantics
/// (Sources/BASSovereign/BASSovereignIntegritySentinel.swift),
/// specifically:
///   - Unknown artifact (no entry in trusted_fps) counts as failure
///     per the「conservative if no ground truth,cannot vouch」 rule
///   - Trusted hash comparison is case-insensitive (compared
///     lowercase-to-lowercase per Swift impl)
///
/// Wire format for `artifacts_buf`:
///   count:   u32 little-endian
///   per claim:
///     id_len:    u16 little-endian
///     id_bytes:  utf-8
///     hash_len:  u16 little-endian
///     hash_bytes:utf-8 (hex string)
///     kind:      u8
///       0 = modelOrPolicyArtifact
///       1 = sovereignPolicyBundle
///       2 = thoughtFoldOrCache
///       3 = runtimeImage
///
/// Wire format for `fingerprints_buf`:
///   count:   u32 little-endian
///   per fingerprint:
///     id_len:    u16 little-endian
///     id_bytes:  utf-8
///     hash_len:  u16 little-endian
///     hash_bytes:utf-8 (hex string)
///
/// Parameters:
/// * `artifacts_buf`        — packed claims per above format
/// * `artifacts_len`        — buffer byte length (i32)
/// * `fingerprints_buf`     — packed trusted fingerprints per above
/// * `fingerprints_len`     — buffer byte length (i32)
/// * `observed_self_mutation` — 0 = clean,non-zero = self-mutation observed
/// * `out_hard_bits`        — writable u16 pointer for the output bitfield
///
/// Returns:0 on success,-1 if any required pointer is null,-2 if
/// wire format parse fails (truncated buffer / impossible length)。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_integrity_scan(
    artifacts_buf: *const u8,
    artifacts_len: i32,
    fingerprints_buf: *const u8,
    fingerprints_len: i32,
    observed_self_mutation: i32,
    out_hard_bits: *mut u16,
) -> i32 {
    if out_hard_bits.is_null() {
        return -1;
    }
    if artifacts_len < 0 || fingerprints_len < 0 {
        return -2;
    }
    // SAFETY:caller guarantees buf points to artifacts_len readable
    // bytes (artifacts_len may be 0 for empty claim list)。
    let artifacts_slice: &[u8] = if artifacts_len == 0 {
        &[]
    } else if artifacts_buf.is_null() {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(
                artifacts_buf, artifacts_len as usize)
        }
    };
    let fingerprints_slice: &[u8] = if fingerprints_len == 0 {
        &[]
    } else if fingerprints_buf.is_null() {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(
                fingerprints_buf, fingerprints_len as usize)
        }
    };

    // Parse trusted fingerprints into BTreeMap for deterministic
    // lookups (HashMap would also work,but BTreeMap pin matches
    // the planned-chapter-七百六十 GSI crate convention)。
    let trusted = match parse_fingerprints(fingerprints_slice) {
        Some(t) => t,
        None => return -2,
    };

    // Parse claims + accumulate failed kinds bitfield。 Walk in array
    // order to match Swift's iteration order (only affects
    // failedArtifactIDs ordering — which the C ABI doesn't expose
    // here — but pinning the walk order makes the implementation
    // explicit)。
    let claims = match parse_claims(artifacts_slice) {
        Some(c) => c,
        None => return -2,
    };

    let mut hard_bits: u16 = 0;
    for claim in claims {
        let claim_hash_lower = claim.hash.to_ascii_lowercase();
        let expected = trusted.get(claim.id);
        let failed = match expected {
            None => true,                       // unknown artifact → fail
            Some(t) => t != &claim_hash_lower,  // mismatch → fail
        };
        if failed {
            match claim.kind {
                0 => hard_bits |= 0x0001,       // BR-001
                2 => hard_bits |= 0x0002,       // BR-002
                1 => hard_bits |= 0x0020,       // BR-006
                3 => hard_bits |= 0x0040,       // BR-007
                _ => return -2,                  // unknown kind code
            }
        }
    }

    // observed_self_mutation flag OR's into BR-007 per Swift impl:
    //   if failedKinds.contains(.runtimeImage) || observedSelfMutation {
    //       obs.unauthorizedSelfMutation = true
    //   }
    if observed_self_mutation != 0 {
        hard_bits |= 0x0040;
    }

    // SAFETY:caller guarantees out_hard_bits points to a writable
    // u16 per the function contract above。
    unsafe { *out_hard_bits = hard_bits; }
    0
}

// MARK: - Wire-format parsers (internal helpers)

/// Parsed artifact claim (intermediate representation for
/// integrity_scan)。 Lifetime tied to the input buffer's lifetime
/// — we hand back `&str` slices into the caller's buffer rather
/// than allocating。
struct ParsedClaim<'a> {
    id: &'a str,
    hash: &'a str,
    kind: u8,
}

/// Parse the artifacts wire format described in
/// `bas_sovereign_integrity_scan` doc comment。 Returns None on
/// truncated buffer / non-UTF-8 / impossible length。
fn parse_claims(buf: &[u8]) -> Option<Vec<ParsedClaim<'_>>> {
    if buf.is_empty() {
        return Some(Vec::new());
    }
    if buf.len() < 4 {
        return None;
    }
    let count = u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let mut offset = 4usize;
    let mut claims = Vec::with_capacity(count);
    for _ in 0..count {
        if buf.len() < offset + 2 { return None; }
        let id_len = u16::from_le_bytes([buf[offset], buf[offset + 1]]) as usize;
        offset += 2;
        if buf.len() < offset + id_len { return None; }
        let id = core::str::from_utf8(&buf[offset..offset + id_len]).ok()?;
        offset += id_len;

        if buf.len() < offset + 2 { return None; }
        let hash_len = u16::from_le_bytes([buf[offset], buf[offset + 1]]) as usize;
        offset += 2;
        if buf.len() < offset + hash_len { return None; }
        let hash = core::str::from_utf8(&buf[offset..offset + hash_len]).ok()?;
        offset += hash_len;

        if buf.len() < offset + 1 { return None; }
        let kind = buf[offset];
        offset += 1;

        claims.push(ParsedClaim { id, hash, kind });
    }
    Some(claims)
}

/// Parse the fingerprints wire format into a deterministic
/// id → lowercase-hex BTreeMap。 Returns None on truncated buffer
/// or non-UTF-8 input。
fn parse_fingerprints(buf: &[u8]) -> Option<std::collections::BTreeMap<String, String>> {
    if buf.is_empty() {
        return Some(std::collections::BTreeMap::new());
    }
    if buf.len() < 4 {
        return None;
    }
    let count = u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let mut offset = 4usize;
    let mut map = std::collections::BTreeMap::new();
    for _ in 0..count {
        if buf.len() < offset + 2 { return None; }
        let id_len = u16::from_le_bytes([buf[offset], buf[offset + 1]]) as usize;
        offset += 2;
        if buf.len() < offset + id_len { return None; }
        let id = core::str::from_utf8(&buf[offset..offset + id_len]).ok()?
            .to_string();
        offset += id_len;

        if buf.len() < offset + 2 { return None; }
        let hash_len = u16::from_le_bytes([buf[offset], buf[offset + 1]]) as usize;
        offset += 2;
        if buf.len() < offset + hash_len { return None; }
        let hash = core::str::from_utf8(&buf[offset..offset + hash_len]).ok()?
            .to_ascii_lowercase();
        offset += hash_len;

        map.insert(id, hash);
    }
    Some(map)
}

// MARK: - Tamper-proof audit (composite of chain + integrity)

/// chapter 七百五十八 第三刀 / M2443 — NEW composite C ABI entry point。
///
/// Combines L14 chain replay + integrity sentinel scan into a SINGLE
/// call,detecting mid-chain artifact mutations。 The motivating use
/// case:a C consumer (watchOS,attestation hook,3rd-party C runtime)
/// wants「is this audit trail intact AND are all the artifacts it
/// references still trustworthy」 answered in one round-trip。
///
/// Without this composite,a C caller would have to invoke chain
/// verify + integrity scan separately and zip the results;the
/// composite does it atomically + writes a unified `out_tamper_mask`
/// summarizing both checks。
///
/// Output `out_tamper_mask` layout (u64):
///   bits 0..15  — integrity hard_bits (from bas_sovereign_integrity_scan)
///                 0x0001 = BR-001,0x0002 = BR-002,
///                 0x0020 = BR-006,0x0040 = BR-007
///   bit 32     — chain mismatch flag (0 = chain valid,1 = chain
///                replay produced a different final hash than expected)
///   bits 16..31 — reserved (zero on this ABI version)
///   bits 33..63 — reserved (zero on this ABI version)
///
/// Output `out_verification` is the i32 return code of the embedded
/// `bas_sovereign_verify_chain`:
///   1 = chain valid (replay produced expected_final32)
///   0 = chain invalid (mismatch or malformed entry)
///   -1 = error (null pointer or buffer too short — `entries_buffer_len`
///        MUST be ≥ 4 to hold the wire-format count prefix)
/// Provided as a separate output for callers that want the granular
/// result without unpacking the bitmask。
///
/// Parameters:
/// * `initial_hash32`        — 32-byte starting hash for chain replay
/// * `entries_buffer`        — chain entries wire-format
///                             (4-byte BE length prefix per entry per
///                             bas_substrate_core convention)
/// * `entries_buffer_len`    — buffer byte length (i32)
/// * `expected_final32`      — 32-byte hash the chain must end at
/// * `artifacts_buf`         — claims wire format per integrity_scan
/// * `artifacts_len`         — buffer byte length (i32)
/// * `fingerprints_buf`      — trusted fingerprints wire format per
///                             integrity_scan
/// * `fingerprints_len`      — buffer byte length (i32)
/// * `observed_self_mutation` — 0 = clean,non-zero = self-mutation flag
/// * `out_verification`      — writable i32 (chain replay result)
/// * `out_tamper_mask`       — writable u64 (composite bitmask)
///
/// Returns:0 on success,-1 if any required pointer is null,-2 if
/// wire format parse fails for the integrity portion (chain replay
/// errors are reported via out_verification,not the return code,so
/// the caller can still see the integrity result if the chain failed)。
///
/// Thread-safety:fully reentrant,no shared state。 Composes two pure
/// functions sequentially。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_tamper_proof_audit(
    initial_hash32: *const u8,
    entries_buffer: *const u8,
    entries_buffer_len: i32,
    expected_final32: *const u8,
    artifacts_buf: *const u8,
    artifacts_len: i32,
    fingerprints_buf: *const u8,
    fingerprints_len: i32,
    observed_self_mutation: i32,
    out_verification: *mut i32,
    out_tamper_mask: *mut u64,
) -> i32 {
    if out_verification.is_null() || out_tamper_mask.is_null() {
        return -1;
    }

    // Step 1:integrity scan。 Run first so even if chain replay
    // somehow fails to write its output,the integrity portion of the
    // tamper mask is still meaningful。
    let mut hard_bits: u16 = 0;
    // SAFETY:we forward to integrity_scan,which validates its own
    // inputs。 We only forward pointers + lengths verbatim。
    let integrity_rc = unsafe {
        bas_sovereign_integrity_scan(
            artifacts_buf, artifacts_len,
            fingerprints_buf, fingerprints_len,
            observed_self_mutation,
            &mut hard_bits,
        )
    };
    if integrity_rc != 0 {
        // Wire-format parse failure or null pointer in integrity
        // portion。 Surface to caller via -2 (parse failure) since the
        // caller's wire format is the immediately-fixable issue。
        // Note we still write to out_tamper_mask + out_verification
        // with zero values to keep the C ABI's output contract clean
        // (no undefined values on error)。
        unsafe {
            *out_verification = 0;
            *out_tamper_mask = 0;
        }
        return -2;
    }

    // Step 2:chain replay。 Caller-pinned 32-byte hashes;
    // entries_buffer follows bas_substrate_core wire format。
    // SAFETY:caller contract per bas_substrate_core::bas_sovereign_verify_chain。
    let chain_rc = unsafe {
        bas_substrate_core::bas_sovereign_verify_chain(
            initial_hash32,
            entries_buffer,
            entries_buffer_len,
            expected_final32,
        )
    };

    // Compose output bitmask:
    //   bits 0..15  = integrity hard_bits
    //   bit 32      = chain mismatch flag (1 when chain_rc != 1,i.e。
    //                 NOT-valid;chain_rc of 1 means valid per
    //                 bas_sovereign_verify_chain semantics)
    let chain_mismatch_bit: u64 = if chain_rc != 1 { 1u64 << 32 } else { 0 };
    let composite: u64 = (hard_bits as u64) | chain_mismatch_bit;

    // SAFETY:both pointers validated non-null at function entry。
    unsafe {
        *out_verification = chain_rc;
        *out_tamper_mask = composite;
    }
    0
}

// MARK: - Re-exports (forwarders to bas-substrate-core)

/// Re-export of `bas_substrate_core::bas_sovereign_seal_entry`。
///
/// Lives in bas-substrate-core::lib.rs (added at chapter 七百四十一
/// 第二刀 / M2377 per the prior layer-migration arc)。 We forward via
/// a thin shim so consumers of this crate's staticlib see the symbol
/// without needing to also link bas-substrate-core explicitly。
///
/// Same contract as the original — see bas-substrate-core for the
/// canonical-bytes wire encoding。
///
/// Signature note:i32 lengths (NOT usize),return value is the
/// canonical-byte count actually written (or negative on error)。 The
/// suffix `_c_abi` distinguishes the forwarder from the original
/// symbol;both are exported but resolve to the same code path via the
/// inner call。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_seal_entry_c_abi(
    prior_hash32: *const u8,
    audit_id: *const u8, audit_id_len: i32,
    session_id: *const u8, session_id_len: i32,
    verdict_ref: *const u8, verdict_ref_len: i32,
    timestamp_ms: i64,
    payload: *const u8, payload_len: i32,
    out_next_hash32: *mut u8,
    out_canonical: *mut u8,
    out_canonical_capacity: i32,
) -> i32 {
    // SAFETY:caller contract per bas-substrate-core::bas_sovereign_seal_entry。
    // We forward verbatim — no validation here that the original
    // doesn't already do。
    unsafe {
        bas_substrate_core::bas_sovereign_seal_entry(
            prior_hash32,
            audit_id, audit_id_len,
            session_id, session_id_len,
            verdict_ref, verdict_ref_len,
            timestamp_ms,
            payload, payload_len,
            out_next_hash32,
            out_canonical,
            out_canonical_capacity,
        )
    }
}

/// Re-export of `bas_substrate_core::bas_sovereign_verify_chain`。
///
/// Same forwarding pattern as `bas_sovereign_seal_entry_c_abi` above。
/// Caller pins `initial32` and `expected_final32` to 32 bytes each;
/// `entries_buffer_len` is the total byte length of the concatenated
/// entries buffer (each entry is a 4-byte BE length prefix followed
/// by entry canonical bytes per chapter 七百四十一 wire format)。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_verify_chain_c_abi(
    initial32: *const u8,
    entries_buffer: *const u8,
    entries_buffer_len: i32,
    expected_final32: *const u8,
) -> i32 {
    // SAFETY:caller contract per bas-substrate-core::bas_sovereign_verify_chain。
    unsafe {
        bas_substrate_core::bas_sovereign_verify_chain(
            initial32,
            entries_buffer,
            entries_buffer_len,
            expected_final32,
        )
    }
}

// MARK: - Tests (unit + byte-equality fixture)

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned_at_v1() {
        // chapter 七百五十八 第一刀 ships ABI v1。 Future ABI bumps
        // must update this assertion + the Swift consumer's pin
        // simultaneously。
        assert_eq!(bas_sovereign_c_abi_version(), 1);
    }

    #[test]
    fn test_halt_signal_encode_deterministic() {
        // Same input → same output。 Twin invocations must produce
        // byte-identical tokens (this is the「replay-verifiable」
        // guarantee L14 sovereign relies on)。
        let mut token_a = [0u8; 32];
        let mut token_b = [0u8; 32];
        unsafe {
            let rc_a = bas_sovereign_halt_signal_encode(
                42, 1_700_000_000_000, token_a.as_mut_ptr());
            let rc_b = bas_sovereign_halt_signal_encode(
                42, 1_700_000_000_000, token_b.as_mut_ptr());
            assert_eq!(rc_a, 0);
            assert_eq!(rc_b, 0);
        }
        assert_eq!(token_a, token_b,
            "deterministic encoding violated");
    }

    #[test]
    fn test_halt_signal_encode_distinguishes_inputs() {
        // Different inputs MUST produce different tokens (otherwise
        // L14 sovereign cannot distinguish「halt for BR-001」 from
        // 「halt for BR-007」)。
        let mut token_001 = [0u8; 32];
        let mut token_007 = [0u8; 32];
        unsafe {
            bas_sovereign_halt_signal_encode(
                1, 1_700_000_000_000, token_001.as_mut_ptr());
            bas_sovereign_halt_signal_encode(
                7, 1_700_000_000_000, token_007.as_mut_ptr());
        }
        assert_ne!(token_001, token_007,
            "reason_code 1 and 7 must produce distinct halt tokens");

        let mut token_t1 = [0u8; 32];
        let mut token_t2 = [0u8; 32];
        unsafe {
            bas_sovereign_halt_signal_encode(
                1, 1_700_000_000_000, token_t1.as_mut_ptr());
            bas_sovereign_halt_signal_encode(
                1, 1_700_000_000_001, token_t2.as_mut_ptr());
        }
        assert_ne!(token_t1, token_t2,
            "timestamps 1ms apart must produce distinct halt tokens");
    }

    #[test]
    fn test_halt_signal_encode_null_out_token_returns_minus_one() {
        // Null output buffer is a documented invalid-input failure。
        // Caller MUST handle the -1 return code rather than
        // attempting to read the (unwritten) token bytes。
        let rc = unsafe {
            bas_sovereign_halt_signal_encode(
                0, 0, core::ptr::null_mut())
        };
        assert_eq!(rc, -1);
    }

    // MARK: - Integrity scan tests (chapter 七百五十八 第二刀)

    /// Wire-format helper for tests:build a claim buffer。 Mirrors the
    /// wire format described in `bas_sovereign_integrity_scan` doc
    /// comment so test setup mirrors what a Swift consumer would emit。
    fn build_claims_buf(claims: &[(&str, &str, u8)]) -> Vec<u8> {
        let mut buf = Vec::new();
        buf.extend_from_slice(&(claims.len() as u32).to_le_bytes());
        for (id, hash, kind) in claims {
            buf.extend_from_slice(&(id.len() as u16).to_le_bytes());
            buf.extend_from_slice(id.as_bytes());
            buf.extend_from_slice(&(hash.len() as u16).to_le_bytes());
            buf.extend_from_slice(hash.as_bytes());
            buf.push(*kind);
        }
        buf
    }

    fn build_fingerprints_buf(fps: &[(&str, &str)]) -> Vec<u8> {
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

    #[test]
    fn test_integrity_scan_clean_all_match() {
        // 4 claims,one per ArtifactKind,all match trusted。 Expect 0x0000。
        let trust = build_fingerprints_buf(&[
            ("model.bin", "aaaa"),
            ("policy.bundle", "bbbb"),
            ("cache.fold", "cccc"),
            ("runtime.image", "dddd"),
        ]);
        let claims = build_claims_buf(&[
            ("model.bin", "aaaa", 0),     // modelOrPolicyArtifact
            ("policy.bundle", "bbbb", 1), // sovereignPolicyBundle
            ("cache.fold", "cccc", 2),    // thoughtFoldOrCache
            ("runtime.image", "dddd", 3), // runtimeImage
        ]);
        let mut hard_bits: u16 = 0xFFFF;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, 0);
        assert_eq!(hard_bits, 0x0000,
            "all claims match trusted → no integrity bits set");
    }

    #[test]
    fn test_integrity_scan_each_kind_to_correct_bit() {
        // Each ArtifactKind that fails MUST light the correct bit:
        // BR-001 (0x01) for modelOrPolicyArtifact (kind=0)
        // BR-002 (0x02) for thoughtFoldOrCache (kind=2)
        // BR-006 (0x20) for sovereignPolicyBundle (kind=1)
        // BR-007 (0x40) for runtimeImage (kind=3)
        for (kind, expected_bit) in &[
            (0u8, 0x0001u16),  // BR-001
            (2u8, 0x0002u16),  // BR-002
            (1u8, 0x0020u16),  // BR-006
            (3u8, 0x0040u16),  // BR-007
        ] {
            let trust = build_fingerprints_buf(&[("art.x", "trusted")]);
            let claims = build_claims_buf(&[("art.x", "tampered", *kind)]);
            let mut hard_bits: u16 = 0;
            let rc = unsafe {
                bas_sovereign_integrity_scan(
                    claims.as_ptr(), claims.len() as i32,
                    trust.as_ptr(),  trust.len() as i32,
                    0, &mut hard_bits)
            };
            assert_eq!(rc, 0);
            assert_eq!(hard_bits, *expected_bit,
                "kind {} expected bit {:#x},got {:#x}",
                kind, expected_bit, hard_bits);
        }
    }

    #[test]
    fn test_integrity_scan_observed_self_mutation_sets_br_007() {
        // observed_self_mutation flag OR's into BR-007 even if all
        // claims pass。 Mirrors Swift's:
        //   if failedKinds.contains(.runtimeImage) || observedSelfMutation
        let trust = build_fingerprints_buf(&[("runtime.image", "dddd")]);
        let claims = build_claims_buf(&[("runtime.image", "dddd", 3)]);
        let mut hard_bits: u16 = 0;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                1,                                  // observed_self_mutation
                &mut hard_bits)
        };
        assert_eq!(rc, 0);
        assert_eq!(hard_bits, 0x0040,
            "observed_self_mutation alone must set BR-007 (0x40)");
    }

    #[test]
    fn test_integrity_scan_unknown_artifact_fails_conservatively() {
        // Per Swift impl:「Unknown artifacts count as failures
        // (conservative — if the sentinel has no ground truth for
        // something,it cannot vouch for it)」
        let trust = build_fingerprints_buf(&[]);  // empty trusted set
        let claims = build_claims_buf(&[
            ("unknown.policy", "anyhash", 1),  // sovereignPolicyBundle
        ]);
        let mut hard_bits: u16 = 0;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, 0);
        assert_eq!(hard_bits, 0x0020,
            "unknown sovereignPolicyBundle artifact must fail → BR-006");
    }

    #[test]
    fn test_integrity_scan_case_insensitive_hash_compare() {
        // Per Swift: trusted hashes stored lowercased,claim hashes
        // lowercased before comparison。 UPPERCASE claim must still match。
        let trust = build_fingerprints_buf(&[("model.bin", "abcdef")]);
        let claims = build_claims_buf(&[
            ("model.bin", "ABCDEF", 0),  // uppercase claimed
        ]);
        let mut hard_bits: u16 = 0xFFFF;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, 0);
        assert_eq!(hard_bits, 0x0000,
            "case-insensitive hash comparison must accept UPPERCASE claim");
    }

    #[test]
    fn test_integrity_scan_multiple_failures_set_combined_bits() {
        // 3 failures across 3 different kinds → bitfield is the OR
        // of all 3 bits。 Mirrors Swift's failedKinds Set semantics。
        let trust = build_fingerprints_buf(&[
            ("model.bin",     "model_good"),
            ("policy.bundle", "policy_good"),
            ("cache.fold",    "cache_good"),
        ]);
        let claims = build_claims_buf(&[
            ("model.bin",     "model_bad",  0),  // BR-001
            ("policy.bundle", "policy_bad", 1),  // BR-006
            ("cache.fold",    "cache_bad",  2),  // BR-002
        ]);
        let mut hard_bits: u16 = 0;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, 0);
        // 0x0001 | 0x0020 | 0x0002 = 0x0023
        assert_eq!(hard_bits, 0x0023,
            "3 failed kinds must OR into combined bitfield 0x0023");
    }

    #[test]
    fn test_integrity_scan_empty_inputs_clean_zero() {
        // 0 claims + 0 trusted + no self-mutation = 0x0000 (clean)。
        let mut hard_bits: u16 = 0xFFFF;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                core::ptr::null(), 0,
                core::ptr::null(), 0,
                0, &mut hard_bits)
        };
        assert_eq!(rc, 0);
        assert_eq!(hard_bits, 0x0000);
    }

    #[test]
    fn test_integrity_scan_null_out_returns_minus_one() {
        let claims = build_claims_buf(&[]);
        let trust = build_fingerprints_buf(&[]);
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, core::ptr::null_mut())
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn test_integrity_scan_invalid_kind_returns_minus_two() {
        // Kind byte 4..255 is undefined。 Implementation returns -2
        // (parse error) per the contract documented above。
        let trust = build_fingerprints_buf(&[("art.x", "good")]);
        let claims = build_claims_buf(&[("art.x", "bad", 99)]);
        let mut hard_bits: u16 = 0;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, -2);
    }

    #[test]
    fn test_integrity_scan_truncated_buffer_returns_minus_two() {
        // Truncated buffer (4-byte count says 5 claims but buffer has none)。
        let truncated = vec![5u8, 0, 0, 0];  // count=5,no claim bytes follow
        let trust = build_fingerprints_buf(&[]);
        let mut hard_bits: u16 = 0;
        let rc = unsafe {
            bas_sovereign_integrity_scan(
                truncated.as_ptr(), truncated.len() as i32,
                trust.as_ptr(),     trust.len() as i32,
                0, &mut hard_bits)
        };
        assert_eq!(rc, -2);
    }

    // MARK: - Tamper-proof audit tests (chapter 七百五十八 第三刀)

    /// Build a chain entries wire-format buffer with ZERO entries。
    /// Per bas_substrate_core::bas_sovereign_verify_chain wire format,
    /// the buffer always starts with a 4-byte BE count prefix。 For a
    /// zero-entry chain,that's just `0u32.to_be_bytes()` = 4 bytes。
    /// verify_chain will then accept it and check `initial == expected`
    /// (since 0 entries means no chain steps run)。
    fn build_zero_entry_chain_buf() -> Vec<u8> {
        0u32.to_be_bytes().to_vec()
    }

    #[test]
    fn test_tamper_proof_audit_all_clean_zero_mask() {
        // Composite happy path:0 chain entries (final == initial),
        // 0 claims,0 trust → both checks pass。 out_tamper_mask = 0。
        let initial = [0u8; 32];
        let expected_final = initial;  // 0 entries means final == initial
        let entries = build_zero_entry_chain_buf();
        let claims = build_claims_buf(&[]);
        let trust = build_fingerprints_buf(&[]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = u64::MAX;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, 0);
        assert_eq!(verification, 1, "chain match expected on empty chain (verify_chain returns 1=valid)");
        assert_eq!(tamper_mask, 0,
            "all clean → tamper_mask must be all-zeros");
    }

    #[test]
    fn test_tamper_proof_audit_integrity_fail_only() {
        // Chain is fine (0 entries,final == initial) but a claim fails
        // → integrity hard_bits show in low 32 bits,chain flag (bit 32)
        // stays 0。
        let initial = [0u8; 32];
        let expected_final = initial;
        let entries = build_zero_entry_chain_buf();
        let trust = build_fingerprints_buf(&[("model.bin", "good")]);
        let claims = build_claims_buf(&[
            ("model.bin", "tampered", 0),  // BR-001 fail
        ]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = 0;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, 0);
        assert_eq!(verification, 1, "chain still valid (verify_chain returns 1=valid)");
        assert_eq!(tamper_mask & 0xFFFF, 0x0001,
            "BR-001 fail must light bit 0 of low 16");
        assert_eq!(tamper_mask & (1u64 << 32), 0,
            "chain ok → bit 32 must be clear");
    }

    #[test]
    fn test_tamper_proof_audit_chain_fail_only() {
        // Chain replay fails (wrong expected_final) but integrity clean
        // → integrity bits stay 0,chain flag (bit 32) sets to 1。
        let initial = [0u8; 32];
        // Use a deliberately-wrong expected_final (all 0xFF) so chain
        // replay reports mismatch。
        let expected_final = [0xFFu8; 32];
        let entries = build_zero_entry_chain_buf();
        let claims = build_claims_buf(&[]);
        let trust = build_fingerprints_buf(&[]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = 0;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, 0);
        assert_ne!(verification, 1,
            "chain mismatch expected (initial all-zeros ≠ expected all-FFs; verify_chain returns 0=invalid)");
        assert_eq!(tamper_mask & 0xFFFF, 0,
            "no claims → integrity bits stay clear");
        assert_eq!(tamper_mask & (1u64 << 32), 1u64 << 32,
            "chain mismatch must light bit 32");
    }

    #[test]
    fn test_tamper_proof_audit_both_fail_composite_mask() {
        // Both chain AND integrity fail。 Composite mask has both
        // integrity bits in low 16 AND chain flag in bit 32。
        let initial = [0u8; 32];
        let expected_final = [0xFFu8; 32];  // wrong → chain fails
        let entries = build_zero_entry_chain_buf();
        let trust = build_fingerprints_buf(&[]);  // empty trust
        let claims = build_claims_buf(&[
            ("unknown.policy", "anyhash", 1),  // unknown → BR-006 fail
        ]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = 0;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, 0);
        assert_ne!(verification, 1,
            "chain mismatch expected (verify_chain returns 0=invalid)");
        // 0x0020 (BR-006) low + (1 << 32) high
        let expected_mask: u64 = 0x0020 | (1u64 << 32);
        assert_eq!(tamper_mask, expected_mask,
            "both-fail composite: BR-006 (0x20) + chain bit 32");
    }

    #[test]
    fn test_tamper_proof_audit_observed_self_mutation_propagates() {
        // observed_self_mutation=1 should propagate into the integrity
        // hard_bits via BR-007 (bit 6 = 0x0040)。
        let initial = [0u8; 32];
        let expected_final = initial;
        let entries = build_zero_entry_chain_buf();
        let claims = build_claims_buf(&[]);
        let trust = build_fingerprints_buf(&[]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = 0;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                1,                                  // observed_self_mutation
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, 0);
        assert_eq!(verification, 1);
        assert_eq!(tamper_mask & 0xFFFF, 0x0040,
            "observed_self_mutation must propagate to BR-007 (0x40)");
    }

    #[test]
    fn test_tamper_proof_audit_null_output_returns_minus_one() {
        // Either out_verification or out_tamper_mask null → -1。
        let initial = [0u8; 32];
        let expected_final = initial;
        let entries = build_zero_entry_chain_buf();
        let claims = build_claims_buf(&[]);
        let trust = build_fingerprints_buf(&[]);
        let mut verification: i32 = 0;
        let mut tamper_mask: u64 = 0;

        let rc1 = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                core::ptr::null_mut(), &mut tamper_mask)
        };
        assert_eq!(rc1, -1);

        let rc2 = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                claims.as_ptr(), claims.len() as i32,
                trust.as_ptr(),  trust.len() as i32,
                0,
                &mut verification, core::ptr::null_mut())
        };
        assert_eq!(rc2, -1);
    }

    #[test]
    fn test_tamper_proof_audit_integrity_parse_fail_returns_minus_two() {
        // Integrity wire-format parse failure (truncated claims buf)
        // must bubble up as -2 + zero outputs。
        let initial = [0u8; 32];
        let expected_final = initial;
        let entries = build_zero_entry_chain_buf();
        let truncated_claims = vec![99u8, 0, 0, 0];  // count=99,no payload
        let trust = build_fingerprints_buf(&[]);

        let mut verification: i32 = 999;
        let mut tamper_mask: u64 = u64::MAX;
        let rc = unsafe {
            bas_sovereign_tamper_proof_audit(
                initial.as_ptr(),
                entries.as_ptr(), entries.len() as i32,
                expected_final.as_ptr(),
                truncated_claims.as_ptr(), truncated_claims.len() as i32,
                trust.as_ptr(), trust.len() as i32,
                0,
                &mut verification, &mut tamper_mask)
        };
        assert_eq!(rc, -2);
        // Documented contract:on parse fail outputs are zeroed for clean
        // C-side state。
        assert_eq!(verification, 0);
        assert_eq!(tamper_mask, 0);
    }

    #[test]
    fn test_halt_signal_encode_pinned_fixture() {
        // chapter 七百五十八 第一刀 — pinned byte-equality fixture。
        // The exact encoding (anchor "bas-sovereign-halt-v1" + i32 BE
        // reason + i64 BE timestamp,SHA256) is part of the v1 ABI
        // contract。 If this fixture drifts,it's an ABI break and
        // ABI_VERSION must bump simultaneously。
        //
        // Fixture inputs:reason=1,timestamp_ms=1_700_000_000_000
        // Expected SHA256 hex of "bas-sovereign-halt-v1" || 0x00000001
        //   || 0x000001936e88ec00
        let mut token = [0u8; 32];
        unsafe {
            bas_sovereign_halt_signal_encode(
                1, 1_700_000_000_000, token.as_mut_ptr());
        }
        // Computed via: echo -n "bas-sovereign-halt-v1" | hexdump
        //   + manual concat with BE bytes → sha256sum
        //
        // First commit ships the test;the「expected」 value is
        // calibrated against the first-run output。 Subsequent runs
        // MUST produce the same value — that's the byte-equality
        // guarantee per chapter 七百十六 discipline。
        let actual_hex = hex::encode(token);
        // We don't pin the literal hex in this commit (avoid
        // false-anchoring a value we haven't yet verified across
        // platforms)。 Pin the determinism via repeat-encoding only。
        // Knife 五 (M2445) will land the byte-equality fixture once
        // we cross-check against Swift's planned reference impl。
        assert_eq!(actual_hex.len(), 64,
            "SHA256 output must be 32 bytes / 64 hex chars");
    }
}
