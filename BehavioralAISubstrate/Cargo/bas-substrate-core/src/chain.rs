// SPDX:internal
//
// chain.rs — chapter 七百三 第一刀 / M2171
//
// Append-only hash-chain primitives ported from
// `BASSovereignAuditLedger.swift`'s prior implementation。 Both
// flavors are exposed:
//
//   - `append_step(prev, payload)` — length-prefixed chain step
//     (SHA256(prev || u32_be(len) || payload))。 Matches the
//     existing `bas_rust_ledger_append_step` ABI。
//   - `pure_chain_step(prev, payload)` — pure concatenation
//     (SHA256(prev || payload))。 Closer to Swift's
//     canonical-bytes-then-SHA256 idiom。
//   - `replay_verify(initial, payloads, expected_final)` —
//     reconstruct the chain inside Rust and verify the final
//     digest matches the expectation。
//
// Hosts persist a ledger as (initial_hash, [payloads],
// expected_final_hash);loading,call `replay_verify` to check
// the chain hasn't been tampered with。


use crate::sha256::sha256_concat;

/// Length-prefixed chain step matching the legacy
/// `bas_rust_ledger_append_step` ABI:
///     SHA256(prev || u32_be(payload_len) || payload)
pub fn append_step(prev32: &[u8; 32], payload: &[u8]) -> [u8; 32] {
    let len_be = (payload.len() as u32).to_be_bytes();
    sha256_concat(&[prev32, &len_be, payload])
}

/// Pure-concat chain step matching the canonical
/// `Data(SHA256.hash(data: canonicalBytes)).base64EncodedString()`
/// idiom from the original BASSovereignAuditLedger。
pub fn pure_chain_step(
    prev32: &[u8; 32], payload: &[u8]
) -> [u8; 32] {
    sha256_concat(&[prev32, payload])
}

/// Replay verification — given an initial hash + an ordered list
/// of payloads + the expected final hash, recompute the chain
/// using `append_step` and return true iff the recomputed final
/// hash matches the expectation。 O(N) hashing,no allocator
/// state。
pub fn replay_verify(
    initial32: &[u8; 32],
    payloads: &[&[u8]],
    expected_final32: &[u8; 32],
) -> bool {
    let mut acc = *initial32;
    for p in payloads {
        acc = append_step(&acc, p);
    }
    &acc == expected_final32
}

/// Genesis hash — 32 zero bytes。 Convention used by both the
/// BASSovereignAuditLedger and the Rust ledger core。
pub const GENESIS_HASH: [u8; 32] = [0; 32];

// MARK: - L14 Sovereign seal_entry (chapter 七百四十一 第一刀 / M2376)
//
// Higher-level wrapper matching the Swift BASSovereignAuditLedger
// .canonicalBytes(for: priorHash:) + chain semantics。 Each L14
// audit entry carries:
//
//   - prior_hash:  32-byte hash of the previous entry
//   - audit_id:    UTF-8 unique entry ID
//   - session_id:  UTF-8 owning session
//   - verdict_ref: UTF-8 reference to the L14 verdict
//   - timestamp_ms: i64 wall clock (UNIX epoch ms)
//   - payload:     opaque per-entry bytes (the audit body)
//
// Canonical-bytes format (matches the Swift L14 wire shape):
//
//   prior_hash (32 bytes) ||
//   u32_be(audit_id_len) || audit_id_bytes ||
//   u32_be(session_id_len) || session_id_bytes ||
//   u32_be(verdict_ref_len) || verdict_ref_bytes ||
//   i64_be(timestamp_ms) ||
//   u32_be(payload_len) || payload_bytes
//
// The seal hash = SHA256(canonical_bytes)。

/// Build canonical bytes for an L14 sovereign audit entry。
/// audit rust LOW: this is a SELF-CONTAINED Rust canonicalization — it is NOT byte-identical to
/// the Swift `BASSovereignAuditLedger.canonicalBytes(for:priorHash:)` (the old "mirrors … verbatim"
/// claim was false). The live seal path routes through the Swift/FFI implementation; this function
/// is an independent encoder, not a byte-for-byte port.
pub fn sovereign_canonical_bytes(
    prior_hash32: &[u8; 32],
    audit_id: &[u8],
    session_id: &[u8],
    verdict_ref: &[u8],
    timestamp_ms: i64,
    payload: &[u8],
) -> Vec<u8> {
    let mut buf: Vec<u8> = Vec::with_capacity(
        32 + 4 + audit_id.len() + 4 + session_id.len()
        + 4 + verdict_ref.len() + 8
        + 4 + payload.len());
    buf.extend_from_slice(prior_hash32);
    buf.extend_from_slice(
        &(audit_id.len() as u32).to_be_bytes());
    buf.extend_from_slice(audit_id);
    buf.extend_from_slice(
        &(session_id.len() as u32).to_be_bytes());
    buf.extend_from_slice(session_id);
    buf.extend_from_slice(
        &(verdict_ref.len() as u32).to_be_bytes());
    buf.extend_from_slice(verdict_ref);
    buf.extend_from_slice(&timestamp_ms.to_be_bytes());
    buf.extend_from_slice(
        &(payload.len() as u32).to_be_bytes());
    buf.extend_from_slice(payload);
    buf
}

/// Compute the next L14 audit chain hash by sealing one entry。
/// Returns (next_hash, canonical_bytes)。 The canonical_bytes
/// MUST be persisted alongside the hash so a later replay can
/// reconstruct + verify。
pub fn seal_sovereign_entry(
    prior_hash32: &[u8; 32],
    audit_id: &[u8],
    session_id: &[u8],
    verdict_ref: &[u8],
    timestamp_ms: i64,
    payload: &[u8],
) -> ([u8; 32], Vec<u8>) {
    let canonical = sovereign_canonical_bytes(
        prior_hash32, audit_id, session_id,
        verdict_ref, timestamp_ms, payload);
    let next = crate::sha256::sha256(&canonical);
    (next, canonical)
}

/// Verify an L14 audit chain by replaying entries from the
/// initial hash through each canonical-bytes blob and asserting
/// the final hash matches the expected hash。 Each `entries`
/// element is a pre-computed canonical_bytes buffer (from
/// `sovereign_canonical_bytes` or persisted from a previous run)。
///
/// O(N) hashing,no allocator state across iterations。
pub fn verify_sovereign_chain(
    initial32: &[u8; 32],
    entries: &[&[u8]],
    expected_final32: &[u8; 32],
) -> bool {
    let mut acc = *initial32;
    for canonical in entries {
        // Each canonical buffer's first 32 bytes MUST equal
        // the running accumulator (the chain link)。 If not,
        // the chain is broken。
        if canonical.len() < 32 {
            return false;
        }
        if &canonical[0..32] != acc.as_slice() {
            return false;
        }
        acc = crate::sha256::sha256(canonical);
    }
    &acc == expected_final32
}

/// Encode a length-prefixed buffer of payloads,matching the
/// wire format the existing
/// `bas_rust_ledger_replay_verify` FFI accepts。 Useful for
/// callers wanting to share one byte buffer across the bridge。
pub fn encode_replay_buffer(payloads: &[&[u8]]) -> Vec<u8> {
    let mut buf = Vec::new();
    let count = (payloads.len() as u32).to_be_bytes();
    buf.extend_from_slice(&count);
    for p in payloads {
        let len = (p.len() as u32).to_be_bytes();
        buf.extend_from_slice(&len);
        buf.extend_from_slice(p);
    }
    buf
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn append_step_deterministic() {
        let prev = [0u8; 32];
        let payload = b"hello";
        let h1 = append_step(&prev, payload);
        let h2 = append_step(&prev, payload);
        assert_eq!(h1, h2);
    }

    #[test]
    fn append_step_distinct_payloads_distinct_hashes() {
        let prev = [0u8; 32];
        let a = append_step(&prev, b"alpha");
        let b = append_step(&prev, b"beta");
        assert_ne!(a, b);
    }

    #[test]
    fn append_step_empty_payload_works() {
        let prev = GENESIS_HASH;
        let h = append_step(&prev, &[]);
        // Sanity: SHA256(0x00*32 || 0x00*4 || empty) is a
        // specific 32-byte value — assert non-zero。
        assert_ne!(h, [0u8; 32]);
    }

    #[test]
    fn pure_chain_step_distinct_from_append_step() {
        let prev = [0u8; 32];
        let payload = b"payload";
        assert_ne!(
            append_step(&prev, payload),
            pure_chain_step(&prev, payload));
    }

    #[test]
    fn replay_verify_good_chain() {
        let initial = GENESIS_HASH;
        let payloads: &[&[u8]] = &[
            b"first", b"second", b"third"];
        // Compute expected final by hand。
        let mut acc = initial;
        for p in payloads {
            acc = append_step(&acc, p);
        }
        assert!(replay_verify(&initial, payloads, &acc));
    }

    #[test]
    fn replay_verify_tampered_chain_fails() {
        let initial = GENESIS_HASH;
        let payloads: &[&[u8]] = &[b"first", b"second"];
        let mut bogus_final = [0u8; 32];
        bogus_final[0] = 0xff;
        assert!(!replay_verify(
            &initial, payloads, &bogus_final));
    }

    #[test]
    fn encode_replay_buffer_shape() {
        let payloads: &[&[u8]] = &[b"a", b"bb"];
        let buf = encode_replay_buffer(payloads);
        // 4 bytes count + 4 bytes len + 1 + 4 bytes len + 2
        assert_eq!(buf.len(), 4 + 4 + 1 + 4 + 2);
        // count = 2
        assert_eq!(&buf[0..4], &2_u32.to_be_bytes());
    }

    // MARK: - L14 sovereign seal/verify tests
    //         (chapter 七百四十一 第一刀 / M2376)

    #[test]
    fn sovereign_canonical_bytes_has_expected_length() {
        let prior = [0u8; 32];
        let canon = sovereign_canonical_bytes(
            &prior, b"AID", b"SID", b"VR", 1700000000,
            b"payload");
        // 32 prior + (4 + 3) + (4 + 3) + (4 + 2) + 8
        //   + (4 + 7) = 71
        assert_eq!(canon.len(),
            32 + 4 + 3 + 4 + 3 + 4 + 2 + 8 + 4 + 7);
        // First 32 bytes = prior hash
        assert_eq!(&canon[0..32], &prior);
    }

    #[test]
    fn seal_sovereign_entry_is_deterministic() {
        let prior = [0u8; 32];
        let (h1, c1) = seal_sovereign_entry(
            &prior, b"A", b"S", b"V", 100, b"p");
        let (h2, c2) = seal_sovereign_entry(
            &prior, b"A", b"S", b"V", 100, b"p");
        assert_eq!(h1, h2);
        assert_eq!(c1, c2);
    }

    #[test]
    fn seal_sovereign_distinct_payloads_distinct_hashes() {
        let prior = [0u8; 32];
        let (h1, _) = seal_sovereign_entry(
            &prior, b"A", b"S", b"V", 100, b"p1");
        let (h2, _) = seal_sovereign_entry(
            &prior, b"A", b"S", b"V", 100, b"p2");
        assert_ne!(h1, h2);
    }

    #[test]
    fn verify_sovereign_chain_replays_correctly() {
        let initial = GENESIS_HASH;
        let (h1, c1) = seal_sovereign_entry(
            &initial, b"A1", b"S", b"V", 100, b"p1");
        let (h2, c2) = seal_sovereign_entry(
            &h1, b"A2", b"S", b"V", 101, b"p2");
        let (h3, c3) = seal_sovereign_entry(
            &h2, b"A3", b"S", b"V", 102, b"p3");
        let canonicals: Vec<&[u8]> =
            vec![c1.as_slice(), c2.as_slice(),
                 c3.as_slice()];
        assert!(verify_sovereign_chain(
            &initial, &canonicals, &h3));
    }

    #[test]
    fn verify_sovereign_chain_detects_broken_link() {
        let initial = GENESIS_HASH;
        let (h1, _) = seal_sovereign_entry(
            &initial, b"A1", b"S", b"V", 100, b"p1");
        // Manufacture a fake second-entry canonical that
        // does NOT carry h1 as its prior hash → should fail
        let fake = sovereign_canonical_bytes(
            &[0xff; 32], b"A2", b"S", b"V", 101, b"p2");
        let canonicals: Vec<&[u8]> =
            vec![fake.as_slice()];
        let mut bogus_final = [0u8; 32];
        bogus_final[0] = 0xab;
        assert!(!verify_sovereign_chain(
            &initial, &canonicals, &bogus_final));
        // Also test:wrong expected_final → false even
        // if links match
        let (_, c1) = seal_sovereign_entry(
            &initial, b"A1", b"S", b"V", 100, b"p1");
        let cs: Vec<&[u8]> = vec![c1.as_slice()];
        // h1 was real but bogus_final is fake → false
        assert!(!verify_sovereign_chain(
            &initial, &cs, &bogus_final));
        // Don't shadow the canonical we already computed
        let _ = h1;
    }

    #[test]
    fn verify_sovereign_chain_short_buffer_fails_gracefully() {
        let short: Vec<&[u8]> = vec![b"too short"];
        let initial = [0u8; 32];
        let bogus_final = [0u8; 32];
        assert!(!verify_sovereign_chain(
            &initial, &short, &bogus_final));
    }

    #[test]
    fn long_chain_replay() {
        // Build a 100-step chain, verify。
        let initial = GENESIS_HASH;
        let mut payload_storage: Vec<Vec<u8>>
            = Vec::new();
        for i in 0_u32..100 {
            let mut p = Vec::new();
            p.extend_from_slice(b"step-");
            p.extend_from_slice(&i.to_be_bytes());
            payload_storage.push(p);
        }
        let payload_refs: Vec<&[u8]> =
            payload_storage.iter().map(|v| v.as_slice())
            .collect();
        let mut acc = initial;
        for p in &payload_refs {
            acc = append_step(&acc, p);
        }
        assert!(replay_verify(
            &initial, &payload_refs, &acc));
    }
}
