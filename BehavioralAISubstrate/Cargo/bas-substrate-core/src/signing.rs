// SPDX:internal
//
// signing.rs — chapter 七百三 第一刀 / M2171
//
// Ed25519 signing + verification ported from
// `BASSovereignEd25519Signing.swift`。 Routed through the
// `ed25519-dalek` crate which implements the RFC 8032 reference
// curve。 Byte-equal to `Curve25519.Signing.PrivateKey
// .signature(for:)` for the deterministic-signing variant used
// by the substrate's tests。

use ed25519_dalek::{Signature, Signer, SigningKey,
    Verifier, VerifyingKey};

/// Sign `message` under a 32-byte seed (RFC 8032 deterministic)
/// and return the 64-byte signature。 Matches the
/// `BASSovereignEd25519KeyPair.fromSeed(_:).privateKey
/// .signature(for: data)` Swift idiom。
pub fn ed25519_sign(seed32: &[u8; 32], message: &[u8]) -> [u8; 64] {
    let signing_key = SigningKey::from_bytes(seed32);
    let sig: Signature = signing_key.sign(message);
    sig.to_bytes()
}

/// Verify a 64-byte signature on `message` under a 32-byte
/// public key。 Returns true on success,false on any error。
pub fn ed25519_verify(
    pub_32: &[u8; 32],
    message: &[u8],
    sig_64: &[u8; 64],
) -> bool {
    let pub_key = match VerifyingKey::from_bytes(pub_32) {
        Ok(k) => k,
        Err(_) => return false,
    };
    let sig = Signature::from_bytes(sig_64);
    pub_key.verify(message, &sig).is_ok()
}

/// Derive the 32-byte Ed25519 PUBLIC key from a 32-byte seed。
/// Used by hosts that want the deterministic public-half
/// pre-cached before signing。
pub fn ed25519_public_from_seed(seed32: &[u8; 32]) -> [u8; 32] {
    let signing_key = SigningKey::from_bytes(seed32);
    signing_key.verifying_key().to_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Round-trip: signature produced by `ed25519_sign` must
    /// verify under `ed25519_verify` with the matching public
    /// key。
    #[test]
    fn sign_verify_round_trip() {
        let seed = [0xab_u8; 32];
        let message = b"sovereign-audit-entry-payload";
        let sig = ed25519_sign(&seed, message);
        let pub_key = ed25519_public_from_seed(&seed);
        assert!(ed25519_verify(&pub_key, message, &sig));
    }

    /// Tampered message must NOT verify under original signature。
    #[test]
    fn tampered_message_fails_verify() {
        let seed = [0xcd_u8; 32];
        let pub_key = ed25519_public_from_seed(&seed);
        let sig = ed25519_sign(&seed, b"original-payload");
        assert!(!ed25519_verify(
            &pub_key, b"different-payload", &sig));
    }

    /// Wrong public key must NOT verify a signature。
    #[test]
    fn wrong_pub_key_fails_verify() {
        let seed1 = [0x11_u8; 32];
        let seed2 = [0x22_u8; 32];
        let sig = ed25519_sign(&seed1, b"data");
        let pub2 = ed25519_public_from_seed(&seed2);
        assert!(!ed25519_verify(&pub2, b"data", &sig));
    }

    /// Tampered signature must NOT verify。
    #[test]
    fn tampered_signature_fails_verify() {
        let seed = [0x33_u8; 32];
        let pub_key = ed25519_public_from_seed(&seed);
        let mut sig = ed25519_sign(&seed, b"data");
        sig[0] ^= 0xff; // flip first byte
        assert!(!ed25519_verify(&pub_key, b"data", &sig));
    }

    /// Determinism — same seed + same message → same
    /// signature (RFC 8032 deterministic Ed25519)。
    #[test]
    fn deterministic_signing() {
        let seed = [0x42_u8; 32];
        let s1 = ed25519_sign(&seed, b"same-message");
        let s2 = ed25519_sign(&seed, b"same-message");
        assert_eq!(s1, s2);
    }

    /// Empty message can be signed + verified。 Useful for
    /// zero-length canonical-bytes edge cases。
    #[test]
    fn empty_message_round_trip() {
        let seed = [0x55_u8; 32];
        let sig = ed25519_sign(&seed, b"");
        let pub_key = ed25519_public_from_seed(&seed);
        assert!(ed25519_verify(&pub_key, b"", &sig));
    }
}
