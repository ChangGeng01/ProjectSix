import XCTest
import CryptoKit
@testable import BASSovereign

/// M296.2 — dual-key commit cryptographic contract tests.
///
/// Doctrine pinned:
/// - Two distinct Ed25519 keypairs sign an intent digest → both
///   sigs validate → verifier returns true
/// - Wrong primary signature → verifier returns false
/// - Wrong secondary signature → verifier returns false
/// - Mismatched primary keyID → verifier returns false (cheap
///   check before crypto)
/// - Mismatched secondary keyID → verifier returns false
/// - Different intent digest at verification time → false
/// - Same keyID in both slots at sign time → SigningError
/// - Codable round-trip preserves commit byte-for-byte
/// - Deterministic: same `(keys, digest)` → same commit
final class BASSovereignDualKeyCommitTests: XCTestCase {

    // MARK: - Fixtures

    private func makePrimary() -> BASSovereignEd25519KeyPair {
        // Deterministic seed for reproducible tests.
        try! BASSovereignEd25519KeyPair.fromSeed("primary-seed")
    }

    private func makeSecondary() -> BASSovereignEd25519KeyPair {
        try! BASSovereignEd25519KeyPair.fromSeed("secondary-seed")
    }

    private func makeIntentDigest() -> Data {
        Data(SHA256.hash(
            data: Data("delete-host-version-7".utf8)))
    }

    // MARK: - Happy path

    func test_validDualKeyCommit_verifies() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()

        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "primary-key",
            secondary: secondary,
            secondaryKeyID: "secondary-key")

        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "primary-key",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "secondary-key",
            secondaryPublicKey: secondary.publicKey)

        XCTAssertTrue(verifier.verify(commit))
    }

    // MARK: - Tampered signatures

    func test_tamperedPrimarySignature_failsVerify() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        var commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        var bad = commit.primarySignature
        bad[0] ^= 0xFF
        commit = BASSovereignDualKeyCommit(
            intentDigest: commit.intentDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: bad,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: commit.secondarySignature)
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(verifier.verify(commit))
    }

    func test_tamperedSecondarySignature_failsVerify() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        var commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        var bad = commit.secondarySignature
        bad[bad.count - 1] ^= 0xFF
        commit = BASSovereignDualKeyCommit(
            intentDigest: commit.intentDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: commit.primarySignature,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: bad)
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(verifier.verify(commit))
    }

    // MARK: - Wrong key IDs

    func test_wrongPrimaryKeyID_failsBeforeCrypto() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "primary",
            secondary: secondary,
            secondaryKeyID: "secondary")
        // Verifier registered with different primaryKeyID:
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "different-primary",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "secondary",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(verifier.verify(commit))
    }

    func test_wrongSecondaryKeyID_failsBeforeCrypto() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "different-secondary",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(verifier.verify(commit))
    }

    // MARK: - Different digest

    func test_differentDigestFailsVerify() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let original = makeIntentDigest()
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: original,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Mutate digest after-the-fact (simulates an attacker
        // swapping the payload while keeping the original
        // signatures).
        let differentDigest = Data(
            SHA256.hash(data: Data("different-intent".utf8)))
        let tampered = BASSovereignDualKeyCommit(
            intentDigest: differentDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: commit.primarySignature,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: commit.secondarySignature)
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(verifier.verify(tampered))
    }

    // MARK: - Same keyID guard

    func test_sameKeyIDForBothSlots_throwsAtSignTime() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        do {
            _ = try BASSovereignDualKeySigning.makeCommit(
                intentDigest: digest,
                primary: primary,
                primaryKeyID: "same-id",
                secondary: secondary,
                secondaryKeyID: "same-id")
            XCTFail("expected SigningError.sameKeyIDForBothSlots")
        } catch let error as
            BASSovereignDualKeySigning.SigningError {
            XCTAssertEqual(
                error,
                .sameKeyIDForBothSlots("same-id"))
        }
    }

    // MARK: - Degenerate verifier fails closed (audit 2026-06-12)

    /// makeCommit rejects a same-keyID pair, but the public commit init
    /// bypasses that guard — so the VERIFIER (the enforcement point) must
    /// also fail closed when its own two slots collapse to one identity.
    /// Otherwise a host could mint a single-key commit + a same-key verifier
    /// and silently downgrade "dual-key" to single-principal protection.
    func test_degenerateSameKeyIDVerifier_failsClosed() throws {
        let primary = makePrimary()
        let digest = makeIntentDigest()
        // A single-key commit (same keyID + same key in both slots),
        // minted via the public init that bypasses makeCommit's guard.
        let sig = try primary.privateKey.signature(for: digest)
        let commit = BASSovereignDualKeyCommit(
            intentDigest: digest,
            primaryKeyID: "same-id",
            primarySignature: sig,
            secondaryKeyID: "same-id",
            secondarySignature: sig)
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "same-id",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "same-id",
            secondaryPublicKey: primary.publicKey)
        XCTAssertFalse(
            verifier.verify(commit),
            "a same-identity verifier must fail closed — " +
            "dual-key must mean two distinct principals")
    }

    /// Two distinct keyIDs but the SAME public key in both slots is still
    /// single-principal — the public-key-collision guard must reject it.
    func test_distinctKeyIDsButSamePublicKey_failsClosed() throws {
        let primary = makePrimary()
        let digest = makeIntentDigest()
        let sig = try primary.privateKey.signature(for: digest)
        let commit = BASSovereignDualKeyCommit(
            intentDigest: digest,
            primaryKeyID: "p",
            primarySignature: sig,
            secondaryKeyID: "s",
            secondarySignature: sig)
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: primary.publicKey)  // collision
        XCTAssertFalse(
            verifier.verify(commit),
            "same public key in both slots is single-principal — " +
            "must fail closed even with distinct keyIDs")
    }

    // MARK: - Codable round-trip

    func test_commitRoundTripsViaCodable() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        let original = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSovereignDualKeyCommit.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Both signings verify (Apple CryptoKit Ed25519 has
    // random nonces; sign-twice does not byte-equal but both
    // commits must verify under the same verifier).

    func test_repeatedSigning_bothCommitsVerify() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        let a = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let b = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertTrue(verifier.verify(a))
        XCTAssertTrue(verifier.verify(b))
    }

    // MARK: - Cross-key swap fails

    func test_swappedKeyPairsFailVerify() throws {
        let primary = makePrimary()
        let secondary = makeSecondary()
        let digest = makeIntentDigest()
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Verifier with primary/secondary public keys swapped.
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: secondary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: primary.publicKey)
        // Primary sig was over digest by primary.privateKey;
        // verifier expects it under secondary.publicKey → fails.
        XCTAssertFalse(verifier.verify(commit))
    }
}
