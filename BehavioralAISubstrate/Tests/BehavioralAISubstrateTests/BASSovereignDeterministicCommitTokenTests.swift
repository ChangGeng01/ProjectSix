// ch1044 #2 / DEFER-1 — deterministic Ed25519 commit-token mint.
// The bridge that lets the deterministic commit gate adopt Ed25519 without losing
// replay-determinism. Production makeCommitToken is untouched (byte-equal); this
// proves the deterministic-Ed25519 path is real, verifiable, and single-use.

import XCTest
import BASSovereign
import BASRuntimeCore
import CryptoKit

private let detFixedNow = Date(timeIntervalSince1970: 1_700_000_000)

final class BASSovereignDeterministicCommitTokenTests: XCTestCase {

    private func makeIntent() -> BASSovereignTokenAuthority.CommitIntent {
        BASSovereignTokenAuthority.CommitIntent(
            sessionID: "s1", turnID: "t1", scope: .toolWrite,
            allowedTargets: ["target.a"], actionDigest: "digest-1",
            snapshotRef: "snap-1")
    }

    // MARK: - 1) Deterministic IDENTITY (signature is randomized — see ADR-025)

    func testDeterministicMintHasReproducibleIdentity() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        let token = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-det-1", nonce: "nonce-1", issuedAt: detFixedNow)
        // The IDENTITY fields are caller-supplied → reproducible (the replay-stable
        // part). A tokenID is single-use, so re-minting it is rejected (FINDING 4) —
        // identity-determinism is therefore asserted by the fields equalling the
        // supplied inputs, not by a second mint of the same tokenID.
        XCTAssertEqual(token.tokenID, "sct-det-1")
        XCTAssertEqual(token.nonce, "nonce-1")
        XCTAssertEqual(token.actionDigest, "digest-1")
        XCTAssertFalse(token.signature.isEmpty)
        XCTAssertTrue(token.singleUse)
        try await authority.verifyCommitToken(
            token, expectedScope: .toolWrite, expectedActionDigest: "digest-1", redeem: false)
    }

    // MARK: - 1b) The ADR-025 finding: CryptoKit Ed25519 is RANDOMIZED (same key)

    func testCryptoKitEd25519IsRandomized() throws {
        // Same key, same message, twice → DIFFERENT signatures (hedged Ed25519). This
        // is WHY full-token byte-determinism including the signature is unachievable
        // with CryptoKit, so the replay identity is the SHA256 tag + identity fields.
        let key = Curve25519.Signing.PrivateKey()
        let msg = Data("same-message".utf8)
        let s1 = try key.signature(for: msg)
        let s2 = try key.signature(for: msg)
        XCTAssertNotEqual(s1, s2, "CryptoKit Curve25519 signing is randomized (hedged)")
    }

    // MARK: - 2) Verifies through the real Ed25519 path

    func testDeterministicTokenVerifies() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        let token = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-det-2", nonce: "n2", issuedAt: detFixedNow)
        // Real Ed25519 verification (signature over canonical bytes).
        try await authority.verifyCommitToken(
            token, expectedScope: .toolWrite,
            expectedActionDigest: "digest-1", redeem: false)
    }

    // MARK: - 3) Tampered signature is rejected

    func testTamperedSignatureRejected() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        let t = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-det-3", nonce: "n3", issuedAt: detFixedNow)
        let tampered = BASSovereignCommitToken(
            tokenID: t.tokenID, sessionID: t.sessionID, turnID: t.turnID,
            scope: t.scope, allowedTargets: t.allowedTargets,
            actionDigest: t.actionDigest, snapshotRef: t.snapshotRef,
            policyHash: t.policyHash, ttlMs: t.ttlMs, nonce: t.nonce,
            singleUse: t.singleUse, signature: "dGFtcGVyZWQ=")  // "tampered"
        do {
            try await authority.verifyCommitToken(
                tampered, expectedScope: .toolWrite,
                expectedActionDigest: "digest-1", redeem: false)
            XCTFail("expected signatureInvalid for a tampered signature")
        } catch { /* expected */ }
    }

    // MARK: - 4) Single-use: redeem once, then rejected

    func testSingleUseRedemption() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        let t = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-det-4", nonce: "n4", issuedAt: detFixedNow)
        try await authority.verifyCommitToken(
            t, expectedScope: .toolWrite, expectedActionDigest: "digest-1", redeem: true)
        do {
            try await authority.verifyCommitToken(
                t, expectedScope: .toolWrite, expectedActionDigest: "digest-1", redeem: true)
            XCTFail("expected alreadyUsed after redemption")
        } catch { /* expected */ }
    }

    // MARK: - 5) Re-minting a tokenID is rejected (single-use ledger, FINDING 4)

    func testReMintingSameTokenIDRejected() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        _ = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-remint", nonce: "n-a", issuedAt: detFixedNow)
        do {
            _ = try await authority.issueDeterministicCommitToken(
                for: makeIntent(), tokenID: "sct-remint", nonce: "n-b", issuedAt: detFixedNow)
            XCTFail("re-minting an existing tokenID must be rejected (double-spend)")
        } catch { /* expected alreadyUsed */ }
    }

    // MARK: - 6) Reusing a nonce is rejected (FINDING 4)

    func testReusingNonceRejected() async throws {
        let authority = BASSovereignTokenAuthority(now: { detFixedNow })
        _ = try await authority.issueDeterministicCommitToken(
            for: makeIntent(), tokenID: "sct-n-1", nonce: "shared", issuedAt: detFixedNow)
        do {
            _ = try await authority.issueDeterministicCommitToken(
                for: makeIntent(), tokenID: "sct-n-2", nonce: "shared", issuedAt: detFixedNow)
            XCTFail("reusing a nonce must be rejected")
        } catch { /* expected */ }
    }
}
