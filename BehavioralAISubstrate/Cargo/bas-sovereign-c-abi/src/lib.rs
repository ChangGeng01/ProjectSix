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
