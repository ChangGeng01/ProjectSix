// SPDX:internal
//
// sha256.rs — chapter 七百三 第一刀 / M2171
//
// Pure SHA-256 implementation routed through the `sha2` crate
// (RustCrypto)。 Byte-equal to NIST FIPS 180-4 reference vectors,
// which means this is the FIRST Rust path the substrate can use
// to retire the CryptoKit-only sites that were pinned against
// `SHA256("abc") == ba7816bf...` (e.g.
// `M341SHA256ReferenceVectorsTests`,
// `BASMemoryAtomEventPayload.sha256Hex` NIST test).

use sha2::{Digest, Sha256};

/// Compute SHA-256 of `data` and return the 32-byte digest。
pub fn sha256(data: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(data);
    let digest = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(digest.as_slice());
    out
}

/// Concatenated SHA-256 — equivalent to SHA256(a || b || c …)
/// without intermediate allocation。 Useful for the audit-ledger
/// canonical-bytes assembler that prior Swift code did by
/// appending into a `Data` buffer。
pub fn sha256_concat(parts: &[&[u8]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    for p in parts {
        hasher.update(p);
    }
    let digest = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(digest.as_slice());
    out
}

/// Lowercase hex encode a 32-byte digest。 Mirrors the
/// `digest.map { String(format: "%02x", $0) }.joined()`
/// idiom used in 11 Swift sites。
pub fn hex_lower(digest: &[u8; 32]) -> String {
    use core::fmt::Write as _;
    let mut s = String::with_capacity(64);
    for b in digest {
        // unwrap-safe: write_fmt on a String never errors。
        let _ = write!(s, "{:02x}", b);
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use Vec;

    /// NIST FIPS 180-4 reference vector — SHA-256 of "abc"。
    /// Pinned by Swift's `BASMemoryAtomEventPayloadTests`。
    #[test]
    fn nist_abc_vector() {
        let d = sha256(b"abc");
        let expected = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ];
        assert_eq!(d, expected);
    }

    /// NIST FIPS 180-4 reference vector — SHA-256 of empty input。
    #[test]
    fn nist_empty_vector() {
        let d = sha256(b"");
        let expected_hex =
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
        assert_eq!(hex_lower(&d), expected_hex);
    }

    /// NIST 56-byte vector — SHA-256 of
    /// "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"。
    #[test]
    fn nist_56byte_vector() {
        let input =
            b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        let d = sha256(input);
        let expected_hex =
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1";
        assert_eq!(hex_lower(&d), expected_hex);
    }

    /// 1-million 'a's vector (FIPS 180-4 Appendix B)。
    #[test]
    fn nist_million_a_vector() {
        let mut input = Vec::with_capacity(1_000_000);
        input.resize(1_000_000, b'a');
        let d = sha256(&input);
        let expected_hex =
            "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0";
        assert_eq!(hex_lower(&d), expected_hex);
    }

    #[test]
    fn concat_equals_join() {
        let a = b"hello ";
        let b = b"world!";
        let joined = {
            let mut v = Vec::new();
            v.extend_from_slice(a);
            v.extend_from_slice(b);
            v
        };
        assert_eq!(sha256(&joined), sha256_concat(&[a, b]));
    }

    #[test]
    fn hex_lower_round_trip() {
        // Spot-check format and length。
        let d = [0xab; 32];
        let s = hex_lower(&d);
        assert_eq!(s.len(), 64);
        assert!(s.chars().all(|c| c.is_ascii_lowercase()
            || c.is_ascii_digit()));
        assert_eq!(&s[..4], "abab");
    }

    /// Determinism — same input → same digest, every time。
    /// Mirrors `BAS392MemoryAtomReplayDeterminismPin
    /// Tests.testSha256HelperIsDeterministic`。
    #[test]
    fn determinism() {
        let s = "fixed-content";
        let h1 = sha256(s.as_bytes());
        let h2 = sha256(s.as_bytes());
        let h3 = sha256(s.as_bytes());
        assert_eq!(h1, h2);
        assert_eq!(h2, h3);
    }

    /// Cross-input variance — distinct inputs must hash to
    /// distinct digests with overwhelming probability。
    #[test]
    fn cross_input_variance() {
        let a = sha256(b"alpha");
        let b = sha256(b"beta");
        assert_ne!(a, b);
    }
}
