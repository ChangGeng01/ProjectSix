import Foundation
import CryptoKit

// M296.2 — dual-key commit for high-consequence sovereign actions.
//
// ## Why this exists
//
// Single-key signing (M87 Ed25519 audit ledger) is enough for tamper
// detection on routine sovereign entries: anyone with the public key
// can verify the ledger wasn't rewritten. But manifest v2 calls out
// **极高后果操作**（删除 host version / 改 sovereign policy /
// 跨设备 sentinel override 等）需要"双钥提交"——单一密钥被攻陷不应
// 等同于 sovereign capitulation. M296.2 ships the cryptographic
// primitive that lets the verdict engine require *two* independent
// Ed25519 signatures against the intent digest before allowing such
// an action to commit.
//
// ## Properties
//
// 1. **Both signatures must validate** against the same intent digest
//    or `verify()` returns false. No partial credit.
// 2. **Key IDs must match registration.** A commit naming an unknown
//    or swapped keyID fails before signature verification — this
//    catches "primary slot signed by secondary keypair" mistakes
//    cheaply.
// 3. **Verifiability over byte equality** — Apple CryptoKit's
//    Ed25519 implementation uses a random nonce per call (it
//    deviates from RFC 8032's deterministic-k for hedging against
//    fault attacks). Two `makeCommit(...)` calls with the same
//    inputs therefore return commits that BOTH VERIFY but may NOT
//    byte-compare equal. Audit code that needs replay should
//    re-verify, not equality-check.
// 4. **No throw on verify failure.** Failure returns false; callers
//    branch on Bool. Cryptographic primitives that throw on
//    "untrusted-data-failed-verification" tend to leak side-channel
//    information through error type.
//
// ## What this explicitly does NOT do
//
// - Key rotation / multi-key thresholds (k-of-n) — those are richer
//   schemes worth their own milestones.
// - Verdict-engine integration — M296.2 ships the primitive; wiring
//   it into `BASSovereignVerdictEngine` so the engine *requires* a
//   dual-key commit on configured high-consequence actions is a
//   follow-up.
// - Cross-device key distribution — that's M296.3 territory.

public struct BASSovereignDualKeyCommit:
    Sendable, Equatable, Hashable, Codable
{
    /// SHA-256 (or other host-chosen digest) of the intent payload
    /// the two signers committed to. Both signatures are over this
    /// exact byte sequence.
    public let intentDigest: Data

    /// Stable identifier of the primary signing key. Compared by
    /// the verifier against the registered primaryKeyID; a mismatch
    /// fails verification before signature checking.
    public let primaryKeyID: String

    /// Ed25519 signature produced by the primary private key over
    /// `intentDigest`.
    public let primarySignature: Data

    /// Stable identifier of the secondary signing key.
    public let secondaryKeyID: String

    /// Ed25519 signature produced by the secondary private key over
    /// `intentDigest`.
    public let secondarySignature: Data

    public init(
        intentDigest: Data,
        primaryKeyID: String,
        primarySignature: Data,
        secondaryKeyID: String,
        secondarySignature: Data
    ) {
        self.intentDigest = intentDigest
        self.primaryKeyID = primaryKeyID
        self.primarySignature = primarySignature
        self.secondaryKeyID = secondaryKeyID
        self.secondarySignature = secondarySignature
    }
}

public enum BASSovereignDualKeySigning {

    /// Errors thrown when constructing a commit. Verification
    /// failures do NOT throw — they return false on the verifier.
    public enum SigningError: Error, Equatable, Sendable {
        /// Same key ID supplied for both primary and secondary —
        /// dual-key requires two distinct signers.
        case sameKeyIDForBothSlots(String)
    }

    /// Produce a dual-key commit by signing `intentDigest` with two
    /// independent Ed25519 key pairs. Throws if `primaryKeyID ==
    /// secondaryKeyID` (dual signing requires distinct identities;
    /// the cryptographic check would still pass with a duplicate
    /// pair, but the *identity* check is what makes "dual" mean
    /// "two principals").
    public static func makeCommit(
        intentDigest: Data,
        primary: BASSovereignEd25519KeyPair,
        primaryKeyID: String,
        secondary: BASSovereignEd25519KeyPair,
        secondaryKeyID: String
    ) throws -> BASSovereignDualKeyCommit {
        guard primaryKeyID != secondaryKeyID else {
            throw SigningError.sameKeyIDForBothSlots(primaryKeyID)
        }
        let primarySig = try primary.privateKey.signature(
            for: intentDigest)
        let secondarySig = try secondary.privateKey.signature(
            for: intentDigest)
        return BASSovereignDualKeyCommit(
            intentDigest: intentDigest,
            primaryKeyID: primaryKeyID,
            primarySignature: primarySig,
            secondaryKeyID: secondaryKeyID,
            secondarySignature: secondarySig)
    }
}

public struct BASSovereignDualKeyVerifier: Sendable {
    public let primaryKeyID: String
    public let primaryPublicKey: Curve25519.Signing.PublicKey
    public let secondaryKeyID: String
    public let secondaryPublicKey: Curve25519.Signing.PublicKey

    public init(
        primaryKeyID: String,
        primaryPublicKey: Curve25519.Signing.PublicKey,
        secondaryKeyID: String,
        secondaryPublicKey: Curve25519.Signing.PublicKey
    ) {
        self.primaryKeyID = primaryKeyID
        self.primaryPublicKey = primaryPublicKey
        self.secondaryKeyID = secondaryKeyID
        self.secondaryPublicKey = secondaryPublicKey
    }

    /// Verify a dual-key commit. Returns true iff:
    /// - both keyID slots match the verifier's registered IDs
    /// - the primary signature validates under `primaryPublicKey`
    /// - the secondary signature validates under `secondaryPublicKey`
    /// - both signatures are over `commit.intentDigest`
    /// Otherwise returns false. Does not throw.
    public func verify(
        _ commit: BASSovereignDualKeyCommit
    ) -> Bool {
        guard commit.primaryKeyID == primaryKeyID else {
            return false
        }
        guard commit.secondaryKeyID == secondaryKeyID else {
            return false
        }
        guard primaryPublicKey.isValidSignature(
            commit.primarySignature,
            for: commit.intentDigest)
        else { return false }
        guard secondaryPublicKey.isValidSignature(
            commit.secondarySignature,
            for: commit.intentDigest)
        else { return false }
        return true
    }
}
