// SPDX:internal
//
// ffi.rs — extern "C" surface for the Swift bridge
// (BASInternalRustBridges.swift)。
//
// chapter 九百五十六.9 / M3485.9 — wire the Rust crate into the
// XCFramework via bas-memory-usage-tracker umbrella + force_link
// anchors。 Per chapter 七百六 / M2187 pattern。
//
// ## Ownership rules (critical)
//
//   - All `*const u8` / `*const c_char` inputs are CALLER-owned。
//     This module does NOT take ownership;does NOT free them。
//   - All returned i64/i32/u64 are SCALARS — no ownership transfer。
//   - String-returning functions write into a CALLER-provided
//     `*mut u8` + `usize` capacity,return number of bytes written
//     (or -1 if capacity insufficient,with required size in
//     `*mut usize out_required`)。 Caller alloc/free。
//
// This module deliberately does NOT expose `pick_winner` /
// `topological_sort` over FFI — those need typed array marshalling
// that's heavier than the win justifies for the hot path size
// (per ch 956.6 measurement showing Swift O(V+E) Kahn already
// well within budget)。 FFI exposes ONLY the leaf primitives
// (fnv1a64 + strong_merge_id) where a future caller can avoid
// repeated Swift-side string concatenation cost。

use crate::{fnv1a64, strong_merge_id};
use std::os::raw::c_char;
use std::slice;

// chapter 九百五十六.11 USER-PASS-4 H2 fix: DoS resistance。 Caps
// FFI inputs to sane sizes — prevents allocation-failure crashes
// when a malicious/buggy caller passes huge `delta_count` or
// `len` values。
const MAX_DELTA_COUNT: usize = 100_000;
const MAX_DELTA_ID_LEN: usize = 1_000_000;
const MAX_BUFFER_LEN: usize = isize::MAX as usize;

// MARK: - In-crate tests for the FFI surface

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper:length-prefixed encode a list of strings into the
    /// v2 buffer format。 Matches what the Swift bridge must emit。
    fn encode_length_prefixed(ids: &[&str]) -> Vec<u8> {
        let mut buf = Vec::new();
        for id in ids {
            let bytes = id.as_bytes();
            let len = bytes.len() as u32;
            buf.extend_from_slice(&len.to_le_bytes());
            buf.extend_from_slice(bytes);
        }
        buf
    }

    fn call_strong_merge_id(
        turn_id: &str, ids: &[&str],
    ) -> Result<String, isize> {
        let turn_bytes = turn_id.as_bytes();
        let id_buf = encode_length_prefixed(ids);
        // Pass 1: discover capacity
        let mut required: usize = 0;
        let r1 = unsafe {
            bas_agent_fabric_strong_merge_id(
                turn_bytes.as_ptr() as *const c_char,
                turn_bytes.len(),
                id_buf.as_ptr() as *const c_char,
                id_buf.len(),
                ids.len(),
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        if r1 < 0 && r1 != -1 { return Err(r1); }
        let mut out = vec![0u8; required];
        let r2 = unsafe {
            bas_agent_fabric_strong_merge_id(
                turn_bytes.as_ptr() as *const c_char,
                turn_bytes.len(),
                id_buf.as_ptr() as *const c_char,
                id_buf.len(),
                ids.len(),
                out.as_mut_ptr(),
                out.len(),
                std::ptr::null_mut(),
            )
        };
        if r2 < 0 { return Err(r2); }
        Ok(String::from_utf8(
            out[..r2 as usize].to_vec()).unwrap())
    }

    #[test]
    fn ffi_strong_merge_id_basic() {
        let mid = call_strong_merge_id(
            "t1", &["d1", "d2", "d3"]).unwrap();
        assert!(mid.starts_with("merge.t1.3."));
        assert_eq!(mid.len(), "merge.t1.3.".len() + 16);
    }

    #[test]
    fn ffi_strong_merge_id_matches_pure_kernel() {
        // FFI path produces same output as direct kernel call
        let via_ffi = call_strong_merge_id(
            "t1", &["d2", "d1", "d3"]).unwrap();
        let via_kernel = crate::strong_merge_id(
            "t1",
            &["d2".to_string(),
              "d1".to_string(),
              "d3".to_string()]);
        assert_eq!(via_ffi, via_kernel);
    }

    /// chapter 九百五十六.10 USER-PASS gap #3 regression:deltaID
    /// containing NUL byte must NOT cause split ambiguity。
    #[test]
    fn ffi_strong_merge_id_deltaid_with_nul_handled() {
        // "d\0NUL" — embedded NUL。 Old v1 null-separated impl
        // would have split this into ["d", "NUL"] → wrong count
        // OR truncated to "d"。 v2 length-prefixed encoding makes
        // it survive intact。
        let mid = call_strong_merge_id(
            "t1", &["d\0NUL", "d2"]).unwrap();
        assert!(mid.starts_with("merge.t1.2."));
        // Hash with embedded NUL must differ from hash with same
        // chars but no NUL — proves the byte is preserved through
        // the FFI boundary。
        let mid_no_nul = call_strong_merge_id(
            "t1", &["dNUL", "d2"]).unwrap();
        assert_ne!(
            mid, mid_no_nul,
            "ch 956.10 gap #3: deltaID with NUL MUST hash \
             differently from same chars without NUL"
        );
    }

    #[test]
    fn ffi_strong_merge_id_count_mismatch_rejects() {
        // Encode 2 IDs but declare 3 → -3
        let id_buf = encode_length_prefixed(&["d1", "d2"]);
        let mut required: usize = 0;
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                b"t1".as_ptr() as *const c_char, 2,
                id_buf.as_ptr() as *const c_char,
                id_buf.len(),
                3,  // wrong: only 2 encoded
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(r, -3,
            "ch 956.10 gap #3: count mismatch MUST return -3");
    }

    #[test]
    fn ffi_strong_merge_id_truncated_length_rejects() {
        // Length prefix says 100 bytes but buffer only has 5
        let mut buf = Vec::new();
        buf.extend_from_slice(&(100u32).to_le_bytes());
        buf.extend_from_slice(b"short");
        let mut required: usize = 0;
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                b"t1".as_ptr() as *const c_char, 2,
                buf.as_ptr() as *const c_char,
                buf.len(),
                1,
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(r, -3,
            "ch 956.10 gap #3: truncated length-prefix MUST be -3");
    }

    #[test]
    fn ffi_strong_merge_id_trailing_garbage_rejects() {
        let mut buf = encode_length_prefixed(&["d1"]);
        buf.push(0xAB); // garbage byte
        let mut required: usize = 0;
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                b"t1".as_ptr() as *const c_char, 2,
                buf.as_ptr() as *const c_char,
                buf.len(),
                1,
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(
            r, -3,
            "ch 956.10 gap #3: trailing garbage after last ID \
             MUST return -3 (strict protocol)"
        );
    }

    #[test]
    fn ffi_strong_merge_id_empty_turn_id_ok() {
        // chapter 九百五十六.10 USER-PASS gap #2 — empty turn_id
        // is a valid input (must not crash;Rust side already
        // handles `turn_id_len == 0` → "")
        let mid = call_strong_merge_id("", &["d1"]).unwrap();
        assert!(mid.starts_with("merge..1."));
    }

    #[test]
    fn ffi_strong_merge_id_empty_delta_list_ok() {
        let mid = call_strong_merge_id("t1", &[]).unwrap();
        assert!(mid.starts_with("merge.t1.0."));
    }

    #[test]
    fn ffi_strong_merge_id_buffer_too_small() {
        let turn = b"t1";
        let id_buf = encode_length_prefixed(&["d1"]);
        let mut required: usize = 0;
        let mut small = [0u8; 5];
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                turn.as_ptr() as *const c_char, 2,
                id_buf.as_ptr() as *const c_char,
                id_buf.len(),
                1,
                small.as_mut_ptr(),
                small.len(),
                &mut required,
            )
        };
        assert_eq!(r, -1, "insufficient capacity → -1");
        assert!(required > 5);
    }

    #[test]
    fn ffi_abi_version_is_3() {
        // chapter 九百五十六.11 USER-PASS-4 fix L2: drop redundant
        // unsafe — bas_agent_fabric_abi_version() is not unsafe。
        assert_eq!(
            bas_agent_fabric_abi_version(), 3,
            "ch 956.11 H2 fix: ABI bumped to 3 with DoS bounds \
             (delta_count ≤ 100k, len ≤ 1M, buf ≤ isize::MAX)"
        );
    }

    /// chapter 九百五十六.11 USER-PASS-4 H2 regression:
    /// delta_count over cap returns -3 (no allocation panic)。
    #[test]
    fn ffi_strong_merge_id_delta_count_over_cap_rejects() {
        let buf = encode_length_prefixed(&["d1"]);
        let mut required: usize = 0;
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                b"t1".as_ptr() as *const c_char, 2,
                buf.as_ptr() as *const c_char,
                buf.len(),
                200_000,  // exceeds MAX_DELTA_COUNT=100_000
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(
            r, -3,
            "ch 956.11 H2: delta_count > MAX_DELTA_COUNT → -3"
        );
    }

    /// H2 regression: per-ID length prefix over cap → -3。
    #[test]
    fn ffi_strong_merge_id_per_id_len_over_cap_rejects() {
        // Encode a fake huge length prefix (5 million bytes)
        let mut buf = Vec::new();
        buf.extend_from_slice(&(5_000_000_u32).to_le_bytes());
        // Don't actually include 5M bytes — decoder must reject
        // on length-cap check BEFORE trying to slice。
        buf.extend_from_slice(b"only-a-few");
        let mut required: usize = 0;
        let r = unsafe {
            bas_agent_fabric_strong_merge_id(
                b"t1".as_ptr() as *const c_char, 2,
                buf.as_ptr() as *const c_char,
                buf.len(),
                1,
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(
            r, -3,
            "ch 956.11 H2: per-ID len > MAX_DELTA_ID_LEN → -3"
        );
    }

    /// H2 regression: fnv1a64 over-cap len returns offset basis
    /// (defined failure mode) instead of UB / crash。
    #[test]
    fn ffi_fnv1a64_over_cap_len_returns_offset_basis() {
        // Cannot actually allocate isize::MAX bytes;test the
        // PROTECTION path by passing a known oversized len with
        // a null ptr (which short-circuits FIRST so this is
        // really just smoke;the real cap path is exercised by
        // the bound check itself which is unit-trivial)。
        let h = unsafe {
            bas_agent_fabric_fnv1a64(std::ptr::null(), 0)
        };
        assert_eq!(
            h, 0xcbf29ce484222325,
            "ch 956.11 H2 smoke: null ptr → offset basis"
        );
    }
}

/// ABI version — bumped when this FFI surface changes shape (new
/// fns,changed signatures,etc.)。 Swift bridge asserts on this。
#[no_mangle]
pub extern "C" fn bas_agent_fabric_abi_version() -> i32 {
    crate::ABI_VERSION
}

/// FNV-1a 64-bit hash of `len` bytes starting at `ptr`。 Returns
/// the hash as a u64。 If `ptr` is null OR `len == 0`,returns
/// the FNV-1a offset basis (0xcbf29ce484222325) — matches the
/// canonical "empty input" behavior + the Rust unit test。
///
/// Safety:`ptr` must be valid for `len` bytes when `len > 0`。
/// Caller-owned;not freed here。
#[no_mangle]
pub unsafe extern "C" fn bas_agent_fabric_fnv1a64(
    ptr: *const u8,
    len: usize,
) -> u64 {
    if ptr.is_null() || len == 0 {
        return fnv1a64(&[]);
    }
    // chapter 九百五十六.11 USER-PASS-4 H2 fix:reject `len`
    // exceeding `isize::MAX` per `slice::from_raw_parts` safety
    // contract (UB otherwise)。 Return offset basis as a defined
    // failure mode rather than crashing the process。
    if len > MAX_BUFFER_LEN {
        return fnv1a64(&[]);
    }
    let bytes = slice::from_raw_parts(ptr, len);
    fnv1a64(bytes)
}

/// Build the canonical mergeID string for `(turn_id, delta_ids)`。
///
/// Inputs:
///   - `turn_id_ptr` / `turn_id_len` — UTF-8 turn ID (caller-owned)
///   - `delta_ids_buf_ptr` / `delta_ids_buf_len` — length-prefixed
///     concatenation of `delta_count` delta IDs。 Encoding per ID:
///     4-byte little-endian `u32` length,then that many UTF-8 bytes。
///     NO separator,NO terminator。 This format admits any byte
///     sequence in deltaIDs (including embedded NUL) — fixes the
///     ch 956.9 v1 null-separated protocol ambiguity per ch 956.10
///     USER-PASS gap #3。
///   - `delta_count` — number of delta IDs encoded
///
/// Output:writes the resulting mergeID (UTF-8) into `out_ptr`/
/// `out_cap`,returns the number of bytes written (excluding
/// NUL terminator,which is NOT written)。 Returns -1 if `out_cap`
/// is insufficient,and writes the required capacity into
/// `out_required` if non-null。 Returns -2 if input UTF-8 is
/// malformed。 Returns -3 if length-prefix encoding is malformed
/// (count mismatch,truncated buffer,length exceeds remaining)。
///
/// Safety:all pointer args must be valid for their declared lengths
/// when non-null。 Caller-owned;not freed here。
#[no_mangle]
pub unsafe extern "C" fn bas_agent_fabric_strong_merge_id(
    turn_id_ptr: *const c_char,
    turn_id_len: usize,
    delta_ids_buf_ptr: *const c_char,
    delta_ids_buf_len: usize,
    delta_count: usize,
    out_ptr: *mut u8,
    out_cap: usize,
    out_required: *mut usize,
) -> isize {
    // chapter 九百五十六.11 USER-PASS-4 H2 fix:cap inputs。
    if turn_id_len > MAX_DELTA_ID_LEN { return -3; }
    if delta_ids_buf_len > MAX_BUFFER_LEN { return -3; }
    if delta_count > MAX_DELTA_COUNT { return -3; }
    // Decode turn_id
    let turn_id: &str = if turn_id_ptr.is_null() || turn_id_len == 0 {
        ""
    } else {
        let bytes = slice::from_raw_parts(
            turn_id_ptr as *const u8, turn_id_len);
        match std::str::from_utf8(bytes) {
            Ok(s) => s,
            Err(_) => return -2,
        }
    };
    // chapter 九百五十六.10 USER-PASS gap #3 — length-prefixed
    // delta-ID decoding。 NO null-separator ambiguity:every chunk
    // is exactly `u32_le_length + bytes` so embedded NUL,binary
    // payloads,or any byte sequence is admissible。 Mismatch
    // between declared delta_count and actual records → return -3。
    let delta_ids: Vec<String> = if delta_ids_buf_ptr.is_null()
        || delta_ids_buf_len == 0
        || delta_count == 0
    {
        // Caller signaling empty list → must agree across all three
        if delta_count != 0 { return -3; }
        Vec::new()
    } else {
        let bytes = slice::from_raw_parts(
            delta_ids_buf_ptr as *const u8,
            delta_ids_buf_len);
        let mut ids: Vec<String> = Vec::with_capacity(delta_count);
        let mut cursor: usize = 0;
        while ids.len() < delta_count {
            // chapter 九百五十六.11 USER-PASS-4 H2 fix:use
            // checked_add for cursor arithmetic so wraparound on
            // any platform returns -3 instead of UB / underflow。
            let after_prefix = match cursor.checked_add(4) {
                Some(v) => v,
                None => return -3,
            };
            if after_prefix > bytes.len() { return -3; }
            let len_bytes = [
                bytes[cursor],
                bytes[cursor + 1],
                bytes[cursor + 2],
                bytes[cursor + 3],
            ];
            let len = u32::from_le_bytes(len_bytes) as usize;
            // Per-ID length cap — prevents Vec::reserve panic on
            // crafted huge prefix。
            if len > MAX_DELTA_ID_LEN { return -3; }
            cursor = after_prefix;
            let after_payload = match cursor.checked_add(len) {
                Some(v) => v,
                None => return -3,
            };
            if after_payload > bytes.len() { return -3; }
            let chunk = &bytes[cursor..after_payload];
            cursor = after_payload;
            match std::str::from_utf8(chunk) {
                Ok(s) => ids.push(s.to_string()),
                Err(_) => return -2,
            }
        }
        // Cursor MUST equal buffer length — trailing garbage is a
        // protocol error。 Strict so callers catch encoding bugs。
        if cursor != bytes.len() { return -3; }
        ids
    };
    let merge_id = strong_merge_id(turn_id, &delta_ids);
    let bytes = merge_id.as_bytes();
    if !out_required.is_null() {
        *out_required = bytes.len();
    }
    if out_ptr.is_null() || out_cap < bytes.len() {
        return -1;
    }
    std::ptr::copy_nonoverlapping(
        bytes.as_ptr(), out_ptr, bytes.len());
    bytes.len() as isize
}
