// ch1044 #2 / DEFER-1 — ADR-025 option B: post-hoc dual Ed25519 signature for a
// commit token.
//
// The host adds an asymmetric Ed25519 signature ALONGSIDE the deterministic
// SHA256 `signature` tag (which stays the replay-stable identity), then re-injects
// the token. Additive — the production commit gate (`makeCommitToken`) is
// UNTOUCHED, so this is byte-equal until a host opts in. The Ed25519 signature
// covers the token's IDENTITY canonical bytes (every stored field except the two
// signatures), so it is verifiable from the token ALONE via the authority's public
// key. Because the signing happens post-hoc on the finished token (whose identity
// fields already encode the mint-time issuedAt), no invasive threading of a signer
// through the sovereign commit-token call chain is required.

import Foundation
import CryptoKit
import BASRuntimeCore

public enum BASSovereignCommitTokenEd25519 {

    /// Outcome of a dual Ed25519 verification.
    public enum Verification: Sendable, Equatable {
        /// The token carries no Ed25519 signature (SHA256-tag-only / pre-dual).
        case absent
        /// A valid Ed25519 signature for the given public key.
        case valid
        /// Present but does not verify (tampered identity, or wrong key).
        case invalid
    }

    /// Return a copy of `token` with `ed25519Signature` populated — an Ed25519
    /// signature over the token's identity canonical bytes. The SHA256 `signature`
    /// tag is unchanged (replay-stable). CryptoKit Ed25519 is randomized, so the
    /// signature is not bit-reproducible — but it always verifies, and the token's
    /// REPLAY identity (`signature` tag + the identity fields) is untouched.
    public static func signed(
        _ token: BASSovereignCommitToken,
        with key: Curve25519.Signing.PrivateKey
    ) throws -> BASSovereignCommitToken {
        let sig = try key.signature(for: token.identityCanonicalBytes())
            .base64EncodedString()
        var copy = token
        copy.ed25519Signature = sig
        return copy
    }

    /// Verify a token's `ed25519Signature` against a public key. `.absent` when the
    /// token carries none; `.invalid` when present but not a valid signature for
    /// the token's identity bytes under `publicKey`.
    public static func verify(
        _ token: BASSovereignCommitToken,
        with publicKey: Curve25519.Signing.PublicKey
    ) -> Verification {
        guard let sigB64 = token.ed25519Signature else { return .absent }
        guard let sigData = Data(base64Encoded: sigB64) else { return .invalid }
        let ok = publicKey.isValidSignature(
            sigData, for: token.identityCanonicalBytes())
        return ok ? .valid : .invalid
    }

    /// Policy-safe verification for an Ed25519-REQUIRED gate: `true` ONLY for a
    /// present, valid signature. Collapses BOTH `.absent` (no signature — i.e. a
    /// strip-the-sig downgrade attempt) and `.invalid` to `false`, so a caller
    /// cannot accidentally accept an unsigned token by treating `.absent` as
    /// acceptable. Use `verify` only when you genuinely must distinguish the three
    /// states (e.g. logging "not yet dual-signed" vs "tampered").
    public static func requireValid(
        _ token: BASSovereignCommitToken,
        with publicKey: Curve25519.Signing.PublicKey
    ) -> Bool {
        verify(token, with: publicKey) == .valid
    }
}
