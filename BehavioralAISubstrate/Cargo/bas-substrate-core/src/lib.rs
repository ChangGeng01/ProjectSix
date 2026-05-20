// SPDX:internal
//
// bas-substrate-core — chapter 七百三 第一刀 / M2171
//
// Rust port of the cryptographic + chain primitives previously
// served by `BASSovereignAuditLedger.swift` and the 17 scattered
// `CryptoKit.SHA256.hash(data:)` call sites across BASSovereign,
// BASHostKit, BASMemory, BASOrchestration, BASObservability,
// BASOrgan, and BASRuntimeCore。
//
// ## Why this crate exists
//
// Pre-chapter-七百三 the substrate had two cryptographic SHA256
// paths:
//   (a) CryptoKit (Apple-platform native)
//   (b) `bas_rust_ledger_append_step` (length-prefixed digest;
//        NOT byte-equal to pure SHA256(data))
//
// (b) was a stopgap that produced a chain-friendly hash but
// could NOT serve NIST-pinned sites like
// `M341SHA256ReferenceVectorsTests` which asserts SHA256("abc")
// == ba7816bf...。 This crate ships PURE SHA256 + HMAC-SHA256 +
// Ed25519 in Rust so every Swift CryptoKit site can route here
// without changing semantics。
//
// ## Public ABI surface (extern "C")
//
//   - `bas_substrate_sha256(data, len, out32)` — pure SHA256
//   - `bas_substrate_hmac_sha256(key, klen, data, dlen, out32)`
//   - `bas_substrate_ed25519_sign(priv32, msg, mlen, sig64)`
//   - `bas_substrate_ed25519_verify(pub32, msg, mlen, sig64) -> bool`
//   - `bas_substrate_chain_step(prev32, payload, plen, out32)` —
//     length-prefixed for chain-friendly hashing
//   - `bas_substrate_replay_verify(...)` — chain replay
//
// ## ABI versioning
//
// `bas_substrate_core_abi_version()` returns the current ABI
// version。 Bumping it requires updating BASSubstrateCoreBridge
// .swift's `expectedABIVersion` constant + the corresponding
// drift test simultaneously。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — observation plumbing only
//   - chapter 392 replay-determinism — every primitive is pure
//     (no allocator state, no global mutability)
//   - chapter 477 ADR-014 OPT-IN — Swift consumers gated behind
//     feature flags; this crate ships the alternative,not the
//     default

#![forbid(unsafe_op_in_unsafe_fn)]

// Substrate ships for Apple platforms which always provide std。
// Earlier scaffold had `#![no_std]` but the existing
// bas-memory-usage-tracker crate is already std-linked,so
// staying with std keeps the workspace consistent。

pub mod chain;
pub mod hmac_mod;
pub mod sha256;
pub mod signing;
// chapter 七百四十二 第一刀 / M2381 — L14 Sovereign Verdict
// Engine port。 Pure 3-stage decision tree (hard rules +
// lexicographic soft signals + evidence-insufficient upgrade)。
// See verdict_decisions.rs header for the LAYER-MIGRATION ARC
// context。
pub mod verdict_decisions;

// MARK: - ABI version

/// ABI version pin。 Returned by `bas_substrate_core_abi_version`。
/// Bumping this constant requires updating
/// `BASSubstrateCoreBridge.swift expectedABIVersion` AND the
/// `testSubstrateCoreABIVersion` drift test simultaneously。
pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_substrate_core_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - C ABI re-exports for the primitives below

#[no_mangle]
pub unsafe extern "C" fn bas_substrate_sha256(
    data: *const u8,
    data_len: usize,
    out32: *mut u8,
) -> i32 {
    if out32.is_null() {
        return -1;
    }
    let slice: &[u8] = if data_len == 0 {
        &[]
    } else if data.is_null() {
        return -1;
    } else {
        // SAFETY: caller guarantees data points to `data_len`
        // bytes of readable memory。
        unsafe { core::slice::from_raw_parts(data, data_len) }
    };
    let digest = sha256::sha256(slice);
    // SAFETY: caller guarantees out32 points to 32 writable
    // bytes。
    unsafe {
        core::ptr::copy_nonoverlapping(
            digest.as_ptr(), out32, 32);
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn bas_substrate_hmac_sha256(
    key: *const u8,
    key_len: usize,
    data: *const u8,
    data_len: usize,
    out32: *mut u8,
) -> i32 {
    if out32.is_null() {
        return -1;
    }
    let key_slice: &[u8] = if key_len == 0 {
        &[]
    } else if key.is_null() {
        return -1;
    } else {
        unsafe { core::slice::from_raw_parts(key, key_len) }
    };
    let data_slice: &[u8] = if data_len == 0 {
        &[]
    } else if data.is_null() {
        return -1;
    } else {
        unsafe { core::slice::from_raw_parts(data, data_len) }
    };
    let mac = hmac_mod::hmac_sha256(key_slice, data_slice);
    unsafe {
        core::ptr::copy_nonoverlapping(
            mac.as_ptr(), out32, 32);
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn bas_substrate_chain_step(
    prev32: *const u8,
    payload: *const u8,
    payload_len: usize,
    out32: *mut u8,
) -> i32 {
    if prev32.is_null() || out32.is_null() {
        return -1;
    }
    let prev_slice: &[u8] =
        unsafe { core::slice::from_raw_parts(prev32, 32) };
    let payload_slice: &[u8] = if payload_len == 0 {
        &[]
    } else if payload.is_null() {
        return -1;
    } else {
        unsafe {
            core::slice::from_raw_parts(payload, payload_len)
        }
    };
    let mut prev_arr = [0u8; 32];
    prev_arr.copy_from_slice(prev_slice);
    let next = chain::append_step(&prev_arr, payload_slice);
    unsafe {
        core::ptr::copy_nonoverlapping(
            next.as_ptr(), out32, 32);
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn bas_substrate_ed25519_sign(
    priv_seed_32: *const u8,
    msg: *const u8,
    msg_len: usize,
    out_sig_64: *mut u8,
) -> i32 {
    if priv_seed_32.is_null() || out_sig_64.is_null() {
        return -1;
    }
    let seed_slice: &[u8] =
        unsafe { core::slice::from_raw_parts(priv_seed_32, 32) };
    let msg_slice: &[u8] = if msg_len == 0 {
        &[]
    } else if msg.is_null() {
        return -1;
    } else {
        unsafe { core::slice::from_raw_parts(msg, msg_len) }
    };
    let mut seed_arr = [0u8; 32];
    seed_arr.copy_from_slice(seed_slice);
    let sig = signing::ed25519_sign(&seed_arr, msg_slice);
    unsafe {
        core::ptr::copy_nonoverlapping(
            sig.as_ptr(), out_sig_64, 64);
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn bas_substrate_ed25519_verify(
    pub_32: *const u8,
    msg: *const u8,
    msg_len: usize,
    sig_64: *const u8,
) -> i32 {
    if pub_32.is_null() || sig_64.is_null() {
        return -1;
    }
    let pub_slice: &[u8] =
        unsafe { core::slice::from_raw_parts(pub_32, 32) };
    let sig_slice: &[u8] =
        unsafe { core::slice::from_raw_parts(sig_64, 64) };
    let msg_slice: &[u8] = if msg_len == 0 {
        &[]
    } else if msg.is_null() {
        return -1;
    } else {
        unsafe { core::slice::from_raw_parts(msg, msg_len) }
    };
    let mut pub_arr = [0u8; 32];
    pub_arr.copy_from_slice(pub_slice);
    let mut sig_arr = [0u8; 64];
    sig_arr.copy_from_slice(sig_slice);
    match signing::ed25519_verify(&pub_arr, msg_slice, &sig_arr) {
        true => 1,
        false => 0,
    }
}

// MARK: - L14 Sovereign seal/verify C ABI
//         (chapter 七百四十一 第二刀 / M2377)

/// Build canonical bytes + seal one L14 entry。 Two-phase
/// capacity pattern matches bas_tokenizer:caller invokes
/// with out_canonical_capacity=0 to discover required size,
/// then realloc + retry。
///
/// `out_next_hash32` is ALWAYS written (32 bytes) if the call
/// succeeds — even on the capacity-discovery phase。
///
/// Returns:
///   ≥ 0  — bytes that WERE written to out_canonical (or
///          required if capacity was 0)
///   -1   — null required pointer (prior_hash32 / out_next_hash32
///          or non-empty payload with null pointer)
///   -2   — would-truncate canonical (out_canonical_capacity
///          smaller than needed but > 0;caller should retry
///          with the returned size)。 NOT a fatal error。
///
/// SAFETY: all input pointers must point to N bytes of
/// readable memory matching the declared length;output
/// pointers must point to writable memory of declared
/// capacity。
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_seal_entry(
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
    if prior_hash32.is_null() || out_next_hash32.is_null() {
        return -1;
    }
    // SAFETY:caller pins prior_hash32 to 32 bytes
    let prior_slice = unsafe {
        core::slice::from_raw_parts(prior_hash32, 32)
    };
    let mut prior_arr = [0u8; 32];
    prior_arr.copy_from_slice(prior_slice);

    let audit_slice = match read_byte_slice(
        audit_id, audit_id_len) {
        Some(s) => s, None => return -1,
    };
    let session_slice = match read_byte_slice(
        session_id, session_id_len) {
        Some(s) => s, None => return -1,
    };
    let verdict_slice = match read_byte_slice(
        verdict_ref, verdict_ref_len) {
        Some(s) => s, None => return -1,
    };
    let payload_slice = match read_byte_slice(
        payload, payload_len) {
        Some(s) => s, None => return -1,
    };

    let (next, canonical) = chain::seal_sovereign_entry(
        &prior_arr,
        audit_slice, session_slice, verdict_slice,
        timestamp_ms, payload_slice);

    // SAFETY:caller pins out_next_hash32 to 32 bytes
    unsafe {
        core::ptr::copy_nonoverlapping(
            next.as_ptr(), out_next_hash32, 32);
    }

    let needed = canonical.len() as i32;
    if out_canonical_capacity == 0 || out_canonical.is_null()
    {
        return needed;
    }
    if needed > out_canonical_capacity {
        return -2;
    }
    // SAFETY:caller pins out_canonical to capacity bytes;
    // needed ≤ capacity here
    unsafe {
        core::ptr::copy_nonoverlapping(
            canonical.as_ptr(),
            out_canonical, canonical.len());
    }
    needed
}

/// Verify an L14 audit chain by replaying entries from the
/// initial hash through each canonical-bytes blob and
/// asserting the final hash matches expected_final32。
///
/// `entries_buffer` carries N entries length-prefixed:
///   u32_be(count) || [u32_be(entry_len) || entry_bytes]*
///
/// Returns:
///   1  — chain verifies (final hash matches expected)
///   0  — chain BROKEN (mismatch detected)
///   -1 — null pointer or malformed buffer
#[no_mangle]
pub unsafe extern "C" fn bas_sovereign_verify_chain(
    initial32: *const u8,
    entries_buffer: *const u8,
    entries_buffer_len: i32,
    expected_final32: *const u8,
) -> i32 {
    if initial32.is_null()
        || entries_buffer.is_null()
        || expected_final32.is_null()
        || entries_buffer_len < 4
    {
        return -1;
    }
    // SAFETY:caller pins pointer lengths per the FFI contract
    let initial_slice = unsafe {
        core::slice::from_raw_parts(initial32, 32)
    };
    let buf = unsafe {
        core::slice::from_raw_parts(
            entries_buffer, entries_buffer_len as usize)
    };
    let expected_slice = unsafe {
        core::slice::from_raw_parts(expected_final32, 32)
    };
    let mut initial_arr = [0u8; 32];
    initial_arr.copy_from_slice(initial_slice);
    let mut expected_arr = [0u8; 32];
    expected_arr.copy_from_slice(expected_slice);

    // Parse length-prefixed entries buffer
    let count = u32::from_be_bytes(
        [buf[0], buf[1], buf[2], buf[3]]) as usize;
    let mut entries: Vec<&[u8]> = Vec::with_capacity(count);
    let mut off = 4_usize;
    for _ in 0..count {
        if off + 4 > buf.len() { return -1; }
        let elen = u32::from_be_bytes([
            buf[off], buf[off + 1],
            buf[off + 2], buf[off + 3]]) as usize;
        off += 4;
        if off + elen > buf.len() { return -1; }
        entries.push(&buf[off..off + elen]);
        off += elen;
    }
    if chain::verify_sovereign_chain(
        &initial_arr, &entries, &expected_arr)
    { 1 } else { 0 }
}

fn read_byte_slice<'a>(
    ptr: *const u8, len: i32
) -> Option<&'a [u8]> {
    if len < 0 { return None; }
    if len == 0 { return Some(&[]); }
    if ptr.is_null() { return None; }
    // SAFETY:caller pins ptr to len bytes per the FFI contract
    Some(unsafe {
        core::slice::from_raw_parts(ptr, len as usize)
    })
}
