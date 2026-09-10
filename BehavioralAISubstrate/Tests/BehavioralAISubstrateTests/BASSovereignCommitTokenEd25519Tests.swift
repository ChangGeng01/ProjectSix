// ch1044 #2 / DEFER-1 — ADR-025 option B: dual Ed25519 signature on a commit token.

import XCTest
import BASSovereign
import BASRuntimeCore
import CryptoKit

final class BASSovereignCommitTokenEd25519Tests: XCTestCase {

    private func makeToken() -> BASSovereignCommitToken {
        BASSovereignCommitToken(
            tokenID: "tok-1", sessionID: "s1", turnID: "t1", scope: .toolWrite,
            allowedTargets: ["a", "b"], actionDigest: "digest", snapshotRef: "snap",
            policyHash: "ph", ttlMs: 60_000, nonce: "nonce-1", signature: "sha256-tag")
    }

    // MARK: - 1) sign (post-hoc) then verify; SHA256 tag untouched

    func testSignThenVerify() throws {
        let key = Curve25519.Signing.PrivateKey()
        let token = makeToken()
        XCTAssertNil(token.ed25519Signature)                 // pre-dual
        let dual = try BASSovereignCommitTokenEd25519.signed(token, with: key)
        XCTAssertNotNil(dual.ed25519Signature)
        XCTAssertEqual(dual.signature, token.signature)      // SHA256 tag unchanged
        XCTAssertEqual(dual.tokenID, token.tokenID)          // identity unchanged
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(dual, with: key.publicKey), .valid)
    }

    // MARK: - 2) absent when no Ed25519 sig (pre-dual / SHA256-only)

    func testAbsentWhenNoEd25519() {
        let key = Curve25519.Signing.PrivateKey()
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(makeToken(), with: key.publicKey),
            .absent)
    }

    // MARK: - 3) tampered identity → invalid

    func testTamperedIdentityFailsVerification() throws {
        let key = Curve25519.Signing.PrivateKey()
        var tampered = try BASSovereignCommitTokenEd25519.signed(makeToken(), with: key)
        tampered.actionDigest = "TAMPERED"                   // identity field changed
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(tampered, with: key.publicKey),
            .invalid)
    }

    // MARK: - 4) wrong key → invalid

    func testWrongKeyFailsVerification() throws {
        let dual = try BASSovereignCommitTokenEd25519.signed(
            makeToken(), with: Curve25519.Signing.PrivateKey())
        let otherKey = Curve25519.Signing.PrivateKey()
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(dual, with: otherKey.publicKey),
            .invalid)
    }

    // MARK: - 5) CRITICAL regression: in-band separator cannot forge a target set

    /// ch1044 audit fix. Under the old `\u{1E}`-join, `["a␞b","c"]` and
    /// `["a","b␞c"]` produced byte-identical signed bytes → one signature validated
    /// for two DIFFERENT authorized-target sets (a scope-expansion forgery). The
    /// injective length-prefixed encoding must make them distinct.
    func testInBandSeparatorCannotForgeDifferentTargets() throws {
        let key = Curve25519.Signing.PrivateKey()
        func tok(_ targets: [String]) -> BASSovereignCommitToken {
            BASSovereignCommitToken(
                tokenID: "tok-1", sessionID: "s1", turnID: "t1", scope: .toolWrite,
                allowedTargets: targets, actionDigest: "digest", snapshotRef: "snap",
                policyHash: "ph", ttlMs: 60_000, nonce: "nonce-1", signature: "tag")
        }
        let a = tok(["a\u{1E}b", "c"])
        let b = tok(["a", "b\u{1E}c"])
        XCTAssertNotEqual(
            a.identityCanonicalBytes(), b.identityCanonicalBytes(),
            "distinct target sets must not share canonical bytes")
        // A signature minted for A must NOT validate for B (no forgery).
        let signedA = try BASSovereignCommitTokenEd25519.signed(a, with: key)
        var bWithASig = b
        bWithASig.ed25519Signature = signedA.ed25519Signature
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(bWithASig, with: key.publicKey),
            .invalid)
    }

    // MARK: - 6) requireValid rejects BOTH absent (downgrade) and invalid

    func testRequireValidRejectsAbsentAndWrongKey() throws {
        let key = Curve25519.Signing.PrivateKey()
        XCTAssertFalse(  // absent → reject (strip-the-sig downgrade)
            BASSovereignCommitTokenEd25519.requireValid(makeToken(), with: key.publicKey))
        let dual = try BASSovereignCommitTokenEd25519.signed(makeToken(), with: key)
        XCTAssertTrue(
            BASSovereignCommitTokenEd25519.requireValid(dual, with: key.publicKey))
        XCTAssertFalse(  // wrong key → reject
            BASSovereignCommitTokenEd25519.requireValid(
                dual, with: Curve25519.Signing.PrivateKey().publicKey))
    }

    // MARK: - 7) present-but-malformed base64 signature → invalid (not a crash)

    func testMalformedBase64SignatureIsInvalid() {
        let key = Curve25519.Signing.PrivateKey()
        var bad = makeToken()
        bad.ed25519Signature = "!!!not-base64!!!"
        XCTAssertEqual(
            BASSovereignCommitTokenEd25519.verify(bad, with: key.publicKey), .invalid)
    }
}
