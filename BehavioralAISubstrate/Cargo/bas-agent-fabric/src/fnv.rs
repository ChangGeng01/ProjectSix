// SPDX:internal
//
// fnv.rs — FNV-1a 64-bit hash, parity with Swift's
// `BASAgentMergeEngine.fnv1a64` (chapter 九百五十六.5 USER-PASS
// gap #4 fix)。
//
// FNV-1a constants per IETF draft-eastlake-fnv-17:
//   - 64-bit offset basis: 0xcbf29ce484222325
//   - 64-bit prime: 0x100000001b3
//
// Test vectors verified against the well-known reference
// implementation (https://github.com/lcn2/fnv reference values)。

/// FNV-1a 64-bit hash of arbitrary bytes。 Non-cryptographic,
/// strong enough for content-id deduplication at substrate scale
/// (collision probability ≤ 2^-64 ≈ 5.4e-20)。 Pure function:
/// same input → same output across runs / devices / processes /
/// languages (Swift parity proven by chapter 九百五十六.8 tests)。
#[inline]
pub fn fnv1a64(bytes: &[u8]) -> u64 {
    let mut hash: u64 = 0xcbf29ce484222325;
    for &b in bytes {
        hash ^= b as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}
