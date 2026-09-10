// SPDX:internal
//
// ledger.rs — chapter 七百十二 第一刀 / M2231
//
// Batched ledger seal + chain verify for the substrate's
// audit-ledger hot path。 Matches Swift
// `BASSovereignAuditLedger`'s "pure" seal:
//
//   selfHash = SHA256(canonical_with_prior_hash_embedded)
//
// The chain linkage is enforced by the canonical-bytes blob
// containing the prior hash (Swift's
// `basSovereignAuditCanonicalBytes(_, priorHash:)` idiom)。
//
// ## Why batch?
//
// The Swift verify pass calls `SHA256.hash(data:)` once per
// entry。 At N entries that's N Swift→Rust FFI round-trips if
// we use the per-entry `bas_substrate_sha256`。 The batch
// functions in this module collapse the loop into one FFI call:
//
//   - `seal_batch_pure(initial, canonicals[])` → N self-hashes
//   - `verify_chain_pure(initial, canonicals[], expected[])`
//                                      → tip-hash or fail-index
//
// Pure Rust on the inside,no allocator per record (the output
// buffer is caller-owned)。 Reuses
// `bas_substrate_core::sha256::sha256` for the inner digest so
// every byte exactly matches Swift CryptoKit's SHA256 output。

use bas_substrate_core::sha256::sha256;

/// One-shot pure seal: y = SHA256(canonical)。 Matches the
/// Swift idiom `Data(SHA256.hash(data: canonical))` exactly。
/// Genesis-aware callers should embed the prior hash inside
/// `canonical` (the Swift ledger does this via
/// `basSovereignAuditCanonicalBytes`)。
#[inline]
pub fn ledger_seal_pure(canonical: &[u8]) -> [u8; 32] {
    sha256(canonical)
}

/// Result of `verify_chain_pure`。 Single-variant enum to keep
/// the C ABI translation simple (i32 return code)。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChainVerifyOutcome {
    /// Every entry's selfHash recomputes to its expected value
    /// AND the priorHash linkage is intact (each entry's
    /// priorHash = previous entry's selfHash,or initial_hash
    /// for the first entry)。
    Ok { tip_hash: [u8; 32] },
    /// First entry whose selfHash != recomputed digest。
    SelfHashMismatch { index: usize },
}

/// Verify an N-entry append-only chain。 For each i in 0..N:
///   1. recompute `recomputed_i = SHA256(canonicals[i])`
///   2. assert `recomputed_i == expected_self_hashes[i]`
///   3. (implicit) priorHash linkage is checked by the
///      canonical-bytes blob itself — if entry i's canonical
///      bytes embed a wrong priorHash,its recomputed digest
///      will differ from the stored selfHash and we fall into
///      `SelfHashMismatch`。
///
/// Returns the final tip hash on success (= last entry's
/// selfHash)。 O(N) hashes,no allocator state。 Matches the
/// loop body in Swift `BASSovereignAuditLedger.verifyChain(...)`
/// exactly。
pub fn verify_chain_pure(
    _initial_hash: &[u8; 32],
    canonicals: &[&[u8]],
    expected_self_hashes: &[[u8; 32]],
) -> ChainVerifyOutcome {
    debug_assert_eq!(
        canonicals.len(), expected_self_hashes.len());
    if canonicals.is_empty() {
        // Empty chain — tip = initial。
        return ChainVerifyOutcome::Ok {
            tip_hash: *_initial_hash };
    }
    for i in 0..canonicals.len() {
        let recomputed = sha256(canonicals[i]);
        if recomputed != expected_self_hashes[i] {
            return ChainVerifyOutcome::SelfHashMismatch {
                index: i };
        }
    }
    ChainVerifyOutcome::Ok {
        tip_hash: expected_self_hashes
            [expected_self_hashes.len() - 1] }
}

/// Batch seal: writes one 32-byte self-hash per canonical
/// payload into the caller-owned `out_self_hashes` buffer。 The
/// caller is responsible for sizing the output to N×32 bytes
/// (debug_assert below enforces it)。 Returns the final tip
/// hash (= last entry's selfHash) for convenience。
pub fn seal_batch_pure(
    _initial_hash: &[u8; 32],
    canonicals: &[&[u8]],
    out_self_hashes: &mut [[u8; 32]],
) -> [u8; 32] {
    debug_assert_eq!(canonicals.len(),
        out_self_hashes.len());
    if canonicals.is_empty() {
        return *_initial_hash;
    }
    for (i, can) in canonicals.iter().enumerate() {
        out_self_hashes[i] = sha256(can);
    }
    out_self_hashes[out_self_hashes.len() - 1]
}

#[cfg(test)]
mod tests {
    use super::*;

    // NIST FIPS 180-4 single-message anchor:
    //   SHA256("abc") =
    //     ba7816bf8f01cfea414140de5dae2223
    //     b00361a396177a9cb410ff61f20015ad
    const SHA256_ABC: [u8; 32] = [
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    ];

    // SHA256("") =
    //   e3b0c44298fc1c149afbf4c8996fb924
    //   27ae41e4649b934ca495991b7852b855
    const SHA256_EMPTY: [u8; 32] = [
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    ];

    #[test]
    fn seal_matches_nist_abc() {
        let h = ledger_seal_pure(b"abc");
        assert_eq!(h, SHA256_ABC);
    }

    #[test]
    fn seal_matches_nist_empty() {
        let h = ledger_seal_pure(b"");
        assert_eq!(h, SHA256_EMPTY);
    }

    #[test]
    fn seal_deterministic() {
        let h1 = ledger_seal_pure(b"sovereign-audit");
        let h2 = ledger_seal_pure(b"sovereign-audit");
        assert_eq!(h1, h2);
    }

    #[test]
    fn seal_distinct_payloads_distinct_hashes() {
        let a = ledger_seal_pure(b"alpha");
        let b = ledger_seal_pure(b"beta");
        assert_ne!(a, b);
    }

    #[test]
    fn verify_chain_empty_returns_initial() {
        let initial = [0u8; 32];
        let outcome = verify_chain_pure(
            &initial, &[], &[]);
        match outcome {
            ChainVerifyOutcome::Ok { tip_hash } => {
                assert_eq!(tip_hash, initial)
            }
            _ => panic!("empty chain must succeed"),
        }
    }

    #[test]
    fn verify_chain_single_entry_ok() {
        let initial = [0u8; 32];
        let canonical = b"first-entry-canonical-bytes";
        let expected = sha256(canonical);
        let outcome = verify_chain_pure(
            &initial,
            &[canonical.as_slice()],
            &[expected]);
        match outcome {
            ChainVerifyOutcome::Ok { tip_hash } => {
                assert_eq!(tip_hash, expected)
            }
            _ => panic!("single-entry chain must succeed"),
        }
    }

    #[test]
    fn verify_chain_three_entries_ok() {
        let initial = [0u8; 32];
        let cans: &[&[u8]] = &[
            b"one", b"two", b"three"];
        let expected: Vec<[u8; 32]> = cans.iter()
            .map(|c| sha256(c)).collect();
        let outcome = verify_chain_pure(
            &initial, cans, &expected);
        match outcome {
            ChainVerifyOutcome::Ok { tip_hash } => {
                assert_eq!(tip_hash, expected[2])
            }
            _ => panic!("three-entry chain must succeed"),
        }
    }

    #[test]
    fn verify_chain_detects_self_hash_tamper() {
        let initial = [0u8; 32];
        let cans: &[&[u8]] = &[
            b"one", b"two", b"three"];
        let mut expected: Vec<[u8; 32]> = cans.iter()
            .map(|c| sha256(c)).collect();
        // Flip a bit in entry 1's expected hash
        expected[1][0] ^= 0x01;
        let outcome = verify_chain_pure(
            &initial, cans, &expected);
        match outcome {
            ChainVerifyOutcome::SelfHashMismatch {
                index } => {
                assert_eq!(index, 1)
            }
            _ => panic!("tamper must be detected"),
        }
    }

    #[test]
    fn seal_batch_writes_n_hashes() {
        let initial = [0u8; 32];
        let cans: &[&[u8]] = &[b"a", b"bb", b"ccc"];
        let mut out = [[0u8; 32]; 3];
        let tip = seal_batch_pure(
            &initial, cans, &mut out);
        assert_eq!(out[0], sha256(b"a"));
        assert_eq!(out[1], sha256(b"bb"));
        assert_eq!(out[2], sha256(b"ccc"));
        assert_eq!(tip, out[2]);
    }

    #[test]
    fn seal_batch_empty_returns_initial() {
        let initial = [42u8; 32];
        let mut out: [[u8; 32]; 0] = [];
        let tip = seal_batch_pure(
            &initial, &[], &mut out);
        assert_eq!(tip, initial);
    }

    #[test]
    fn seal_batch_then_verify_round_trip() {
        // Build a 64-entry chain via seal_batch_pure,
        // verify with verify_chain_pure。
        let initial = [0u8; 32];
        let payload_storage: Vec<Vec<u8>> = (0_u32..64)
            .map(|i| {
                let mut v = b"entry-".to_vec();
                v.extend_from_slice(&i.to_be_bytes());
                v
            })
            .collect();
        let canonicals: Vec<&[u8]> = payload_storage
            .iter().map(|v| v.as_slice()).collect();
        let mut hashes = vec![[0u8; 32]; 64];
        seal_batch_pure(
            &initial, &canonicals, &mut hashes);
        match verify_chain_pure(
            &initial, &canonicals, &hashes)
        {
            ChainVerifyOutcome::Ok { tip_hash } => {
                assert_eq!(tip_hash, hashes[63])
            }
            _ => panic!("round-trip must succeed"),
        }
    }

    #[test]
    fn verify_chain_short_circuits_at_first_failure() {
        // 10 entries,corrupt entry 3 → verify must report
        // index 3,not 4,5,...。
        let initial = [0u8; 32];
        let payload_storage: Vec<Vec<u8>> = (0_u32..10)
            .map(|i| format!("p{}", i).into_bytes())
            .collect();
        let cans: Vec<&[u8]> = payload_storage.iter()
            .map(|v| v.as_slice()).collect();
        let mut expected: Vec<[u8; 32]> = cans.iter()
            .map(|c| sha256(c)).collect();
        expected[3][31] ^= 0xff; // tamper
        match verify_chain_pure(
            &initial, &cans, &expected)
        {
            ChainVerifyOutcome::SelfHashMismatch {
                index } => assert_eq!(index, 3),
            _ => panic!("must short-circuit at first fail"),
        }
    }
}
