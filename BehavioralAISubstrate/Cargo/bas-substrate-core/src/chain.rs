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
