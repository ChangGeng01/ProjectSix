// ch1044 #2 / DEFER-1 — deterministic Ed25519 commit-token mint.
// The bridge that lets the deterministic commit gate adopt Ed25519 without losing
// replay-determinism. Production makeCommitToken is untouched (byte-equal); this
// proves the deterministic-Ed25519 path is real, verifiable, and single-use.

import XCTest
import BASSovereign
import BASRuntimeCore

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
        let intent = makeIntent()
        let a = try await authority.issueDeterministicCommitToken(
            for: intent, tokenID: "sct-det-1", nonce: "nonce-1", issuedAt: detFixedNow)
        let b = try await authority.issueDeterministicCommitToken(
            for: intent, tokenID: "sct-det-1", nonce: "nonce-1", issuedAt: detFixedNow)
        // The IDENTITY fields are caller-supplied → reproducible (the replay-stable
        // part). The SIGNATURE is a RANDOMIZED CryptoKit Ed25519 sig, so it is NOT
        // bit-reproducible — full-token byte-determinism is not achievable with
        // CryptoKit Ed25519 (ADR-025 finding). Both signatures still verify.
        XCTAssertEqual(a.tokenID, b.tokenID)
        XCTAssertEqual(a.nonce, b.nonce)
        XCTAssertEqual(a.actionDigest, b.actionDigest)
        XCTAssertNotEqual(a.signature, b.signature, "CryptoKit Ed25519 is randomized")
        XCTAssertFalse(a.signature.isEmpty)
        XCTAssertTrue(a.singleUse)
        try await authority.verifyCommitToken(
            a, expectedScope: .toolWrite, expectedActionDigest: "digest-1", redeem: false)
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
}
