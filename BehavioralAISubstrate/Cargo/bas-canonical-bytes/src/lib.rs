// SPDX:internal
//
// bas-canonical-bytes — chapter 七百三 第四刀 / M2174
//
// Canonical-bytes assembler ported from Swift's
// `basSovereignAuditCanonicalBytes(for: priorHash:)` helper。
// Produces the byte buffer the audit ledger hashes + signs。
//
// ## Why canonical bytes matter
//
// The audit ledger signs `canonicalBytes(entry, priorHash)`。 If
// two implementations of `canonicalBytes` disagree on field order
// or string encoding,signatures fail to verify across the
// Swift/Rust boundary。 Tests pin specific byte vectors so any
// drift surfaces loudly。
//
// ## CANONICAL layout (1.2.0, ABI v2 — `v1_2.rs`)
//
// The current form is the INJECTIVE length-prefixed encoding
// mirroring Swift's `basSovereignAuditCanonicalBytes` 1.2.0
// branch:each part is `<utf8ByteCount>:<bytes>`,arrays emit a
// count-marker part then one part per element,part order is
// schemaVersion … signingNamespace (see v1_2.rs)。
//
// ## LEGACY layout (pre-1.2.0 — `assembler.rs`, record only)
//
//   priorHash (utf8 bytes) || 0x1F || auditID (utf8 bytes) ||
//   0x1F || sessionID … (0x1F-delimiter-join)
//
// The 0x1F delimiter-join is AMBIGUOUS for real content (the
// substrate legitimately uses U+001F/U+001E inside refs) — it was
// superseded by 1.2.0 (ch1044 D2) and is retained here only so
// already-persisted pre-1.2.0 evidence remains decodable。

#![forbid(unsafe_op_in_unsafe_fn)]

// audit rust LOW / operator decision 5: the legacy pre-1.2.0 `assembler` encoder used a FORGEABLE
// 0x1F delimiter-join (a collision surface). It has zero production callers, so compile-time-fence it
// behind `#[cfg(test)]` — its round-trip tests still run, but it is unreachable outside tests.
#[cfg(test)]
mod assembler;
pub mod field;
pub mod v1_2;

/// ABI v2 (全面进化 T2.1a): adds `bas_canonical_bytes_assemble_v1_2` — the INJECTIVE
/// length-prefixed 1.2.0 form mirroring Swift's current `basSovereignAuditCanonicalBytes`.
/// The legacy `assembler.rs` (delimiter-join, pre-1.2.0) is retained for the record only.
pub const ABI_VERSION: i32 = 2;

#[no_mangle]
pub extern "C" fn bas_canonical_bytes_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - extern "C" surface for the 1.2.0 injective assembler
//
// Byte-slice semantics throughout (length prefixes are UTF-8 byte counts; content passes through
// raw). String arrays arrive as parallel (ptrs, lens, count) triplets. Two-call-friendly: returns
// the TOTAL byte length needed; writes min(needed, out_cap) into out_buf. A null/0-cap out_buf is
// a pure size query.

#[inline]
unsafe fn slice_or_empty<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    if len == 0 || ptr.is_null() {
        &[]
    } else {
        // SAFETY: caller guarantees ptr..ptr+len is a live, readable buffer for the call duration.
        unsafe { core::slice::from_raw_parts(ptr, len) }
    }
}

#[inline]
unsafe fn gather<'a>(
    ptrs: *const *const u8,
    lens: *const usize,
    count: usize,
) -> Vec<&'a [u8]> {
    if count == 0 || ptrs.is_null() || lens.is_null() {
        return Vec::new();
    }
    // SAFETY: caller guarantees both arrays hold `count` live elements for the call duration.
    let ptrs = unsafe { core::slice::from_raw_parts(ptrs, count) };
    let lens = unsafe { core::slice::from_raw_parts(lens, count) };
    (0..count)
        .map(|i| unsafe { slice_or_empty(ptrs[i], lens[i]) })
        .collect()
}

/// Assemble the 1.2.0 injective canonical bytes (C ABI). Returns the TOTAL byte length needed;
/// writes `min(needed, out_cap)` bytes into `out_buf` when non-null.
///
/// # Safety
/// Every (ptr, len) pair must reference a live, readable buffer of at least `len` bytes for the
/// duration of the call (null/0-len pairs are treated as empty). Each array triplet's `ptrs` and
/// `lens` must each hold `count` live elements whose inner pairs meet the same contract. `out_buf`,
/// when non-null, must be writable for `out_cap` bytes and must not alias any input buffer.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn bas_canonical_bytes_assemble_v1_2(
    schema_version: *const u8, schema_version_len: usize,
    audit_id: *const u8, audit_id_len: usize,
    session_id: *const u8, session_id_len: usize,
    turn_id: *const u8, turn_id_len: usize,
    verdict_ref: *const u8, verdict_ref_len: usize,
    rule_ids_ptrs: *const *const u8, rule_ids_lens: *const usize, rule_ids_count: usize,
    signal_refs_ptrs: *const *const u8, signal_refs_lens: *const usize, signal_refs_count: usize,
    action_refs_ptrs: *const *const u8, action_refs_lens: *const usize, action_refs_count: usize,
    snapshot_ref: *const u8, snapshot_ref_len: usize,
    actor: *const u8, actor_len: usize,
    appended_at_ms: i64,
    prior_hash: *const u8, prior_hash_len: usize,
    signing_namespace: *const u8, signing_namespace_len: usize,
    out_buf: *mut u8, out_cap: usize,
) -> isize {
    let rule_ids = unsafe { gather(rule_ids_ptrs, rule_ids_lens, rule_ids_count) };
    let signal_refs = unsafe { gather(signal_refs_ptrs, signal_refs_lens, signal_refs_count) };
    let action_refs = unsafe { gather(action_refs_ptrs, action_refs_lens, action_refs_count) };
    let bytes = v1_2::assemble_v1_2(
        unsafe { slice_or_empty(schema_version, schema_version_len) },
        unsafe { slice_or_empty(audit_id, audit_id_len) },
        unsafe { slice_or_empty(session_id, session_id_len) },
        unsafe { slice_or_empty(turn_id, turn_id_len) },
        unsafe { slice_or_empty(verdict_ref, verdict_ref_len) },
        &rule_ids,
        &signal_refs,
        &action_refs,
        unsafe { slice_or_empty(snapshot_ref, snapshot_ref_len) },
        unsafe { slice_or_empty(actor, actor_len) },
        appended_at_ms,
        unsafe { slice_or_empty(prior_hash, prior_hash_len) },
        unsafe { slice_or_empty(signing_namespace, signing_namespace_len) },
    );
    if !out_buf.is_null() && out_cap > 0 {
        let n = bytes.len().min(out_cap);
        // SAFETY: caller guarantees out_buf..out_buf+out_cap is writable.
        unsafe { core::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf, n) };
    }
    bytes.len() as isize
}
