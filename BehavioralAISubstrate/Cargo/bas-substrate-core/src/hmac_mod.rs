// SPDX:internal
//
// hmac_mod.rs — chapter 七百三 第一刀 / M2171
//
// Pure HMAC-SHA-256 routed through the `hmac` crate (RustCrypto)
// composed with the `sha2` crate。 Byte-equal to RFC 4231 test
// vectors and to Swift's `HMAC<SHA256>.authenticationCode(for:
// using:)` previously used by `BASSovereignAuditLedger.sign(_:)`。

use hmac::{Hmac, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

/// Compute HMAC-SHA256 of `data` under `key` and return the
/// 32-byte tag。 RFC 4231 byte-equal。
pub fn hmac_sha256(key: &[u8], data: &[u8]) -> [u8; 32] {
    // Note: HMAC supports arbitrary key sizes (small or large)
    // by definition;the `new_from_slice` constructor never
    // rejects valid byte slices for SHA256 underneath。
    let mut mac =
        HmacSha256::new_from_slice(key).expect(
            "HmacSha256::new_from_slice cannot fail with sha2");
    mac.update(data);
    let tag = mac.finalize().into_bytes();
    let mut out = [0u8; 32];
    out.copy_from_slice(tag.as_slice());
    out
}

/// HMAC-SHA256 with a key derived deterministically from a
/// string seed (SHA256 of seed.utf8)。 Mirrors the Swift
/// idiom `SymmetricKey(data: SHA256.hash(data: Data(seed.utf8)))`
/// used in `BASSovereignAuditLedger.withSeed(_:)`。
pub fn hmac_sha256_with_seed(
    seed: &str, data: &[u8],
) -> [u8; 32] {
    let key = crate::sha256::sha256(seed.as_bytes());
    hmac_sha256(&key, data)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// RFC 4231 test case 1 — key=20× 0x0b, data="Hi There"。
    #[test]
    fn rfc4231_case1() {
        let key = [0x0b_u8; 20];
        let data = b"Hi There";
        let mac = hmac_sha256(&key, data);
        let expected_hex =
            "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7";
        assert_eq!(crate::sha256::hex_lower(&mac),
            expected_hex);
    }

    /// RFC 4231 test case 2 — key="Jefe", data=
    /// "what do ya want for nothing?"。 Verifies short-key path。
    #[test]
    fn rfc4231_case2() {
        let key = b"Jefe";
        let data = b"what do ya want for nothing?";
        let mac = hmac_sha256(key, data);
        let expected_hex =
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843";
        assert_eq!(crate::sha256::hex_lower(&mac),
            expected_hex);
    }

    /// Determinism — same (key, data) → same MAC every time。
    #[test]
    fn determinism() {
        let key = b"some-key";
        let data = b"some-data";
        let m1 = hmac_sha256(key, data);
        let m2 = hmac_sha256(key, data);
        assert_eq!(m1, m2);
    }

    /// Seed derivation matches BASSovereignAuditLedger
    /// .withSeed(_:) shape。
    #[test]
    fn seed_derived_key_path() {
        let m1 = hmac_sha256_with_seed("test-seed", b"data");
        let derived_key =
            crate::sha256::sha256(b"test-seed");
        let m2 = hmac_sha256(&derived_key, b"data");
        assert_eq!(m1, m2);
    }
}
