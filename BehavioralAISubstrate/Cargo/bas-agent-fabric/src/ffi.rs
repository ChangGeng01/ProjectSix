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
    let bytes = slice::from_raw_parts(ptr, len);
    fnv1a64(bytes)
}

/// Build the canonical mergeID string for `(turn_id, delta_ids)`。
///
/// Inputs:
///   - `turn_id_ptr` / `turn_id_len` — UTF-8 turn ID (caller-owned)
///   - `delta_ids_concat_ptr` / `delta_ids_concat_len` — UTF-8
///     null-byte (`\0`) separated concatenation of all delta IDs
///   - `delta_count` — number of delta IDs encoded
///
/// Output:writes the resulting mergeID (UTF-8) into `out_ptr`/
/// `out_cap`,returns the number of bytes written (excluding
/// NUL terminator,which is NOT written)。 Returns -1 if `out_cap`
/// is insufficient,and writes the required capacity into
/// `out_required` if non-null。
///
/// Safety:all pointer args must be valid for their declared lengths
/// when non-null。 Caller-owned;not freed here。
#[no_mangle]
pub unsafe extern "C" fn bas_agent_fabric_strong_merge_id(
    turn_id_ptr: *const c_char,
    turn_id_len: usize,
    delta_ids_concat_ptr: *const c_char,
    delta_ids_concat_len: usize,
    delta_count: usize,
    out_ptr: *mut u8,
    out_cap: usize,
    out_required: *mut usize,
) -> isize {
    // Decode turn_id
    let turn_id: &str = if turn_id_ptr.is_null() || turn_id_len == 0 {
        ""
    } else {
        let bytes = slice::from_raw_parts(
            turn_id_ptr as *const u8, turn_id_len);
        match std::str::from_utf8(bytes) {
            Ok(s) => s,
            Err(_) => return -2,  // -2 = malformed UTF-8 input
        }
    };
    // Decode delta IDs from null-byte separated buffer
    let delta_ids: Vec<String> = if delta_ids_concat_ptr.is_null()
        || delta_ids_concat_len == 0
        || delta_count == 0
    {
        Vec::new()
    } else {
        let bytes = slice::from_raw_parts(
            delta_ids_concat_ptr as *const u8,
            delta_ids_concat_len);
        let mut ids = Vec::with_capacity(delta_count);
        for chunk in bytes.split(|&b| b == 0) {
            if chunk.is_empty() && ids.len() == delta_count {
                break;
            }
            match std::str::from_utf8(chunk) {
                Ok(s) if !s.is_empty() => ids.push(s.to_string()),
                Ok(_) => {}
                Err(_) => return -2,
            }
            if ids.len() == delta_count {
                break;
            }
        }
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
