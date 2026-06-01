// ch1044 A1 — end-to-end tests for the production sovereign commit enforcement seam.
// Proves a host that wires the enforcer rejects a tampered render body / aliased
// target / replay / expired token BEFORE executing the irreversible op.

import XCTest
import CryptoKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignCommitEnforcerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// A brain-emitted renderHighRisk token (keyless SHA256 `signature`, as
    /// `makeCommitToken` produces). `actionDigest` is the shared canonical digest over
    /// `["answer","headline",body]` + turn identity.
    private func brainToken(
        body: String = "approved-body",
        targets: [String] = ["answer"],
        policyHash: String = "ph-1",
        ttlMs: Int = 60_000
    ) -> BASSovereignCommitToken {
        let digest = BASSovereignActionDigest.compute(
            scope: .renderHighRisk,
            actionDigestParts: ["answer", "headline", body],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: policyHash)
        return BASSovereignCommitToken(
            tokenID: "tok-render", sessionID: "s1", turnID: "t1", scope: .renderHighRisk,
            allowedTargets: targets, actionDigest: digest, snapshotRef: "snap",
            policyHash: policyHash, ttlMs: ttlMs, nonce: "nonce-1", singleUse: true,
            signature: "keyless-sha256")
    }

    /// The host's INDEPENDENT recompute from the artifact it is ACTUALLY about to render.
    private func expectedDigest(body: String, policyHash: String = "ph-1") -> String {
        BASSovereignActionDigest.compute(
            scope: .renderHighRisk,
            actionDigestParts: ["answer", "headline", body],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: policyHash)
    }

    private func makeEnforcer(_ clock: BASAuthorityClock) -> BASSovereignCommitEnforcer {
        clock.set(t0)
        let authority = BASSovereignTokenAuthority(now: { clock.read() })
        return BASSovereignCommitEnforcer(authority: authority, now: { clock.read() })
    }

    // MARK: - 1) Valid token authorizes the matching render

    func testValidTokenAuthorizes() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let auth = try await enforcer.register(brainToken(), issuedAt: t0)
        try await enforcer.authorize(
            auth, scope: .renderHighRisk, target: "answer",
            expectedActionDigest: expectedDigest(body: "approved-body"),
            expectedPolicyHash: "ph-1")  // must NOT throw
    }

    // MARK: - 2) A tampered render body is rejected end-to-end

    func testTamperedBodyIsRejected() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let auth = try await enforcer.register(brainToken(body: "approved-body"), issuedAt: t0)
        // The host is about to render a DIFFERENT (prompt-injected) body → its independent
        // recompute won't match the token's signed actionDigest.
        do {
            try await enforcer.authorize(
                auth, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: expectedDigest(body: "EVIL injected body"),
                expectedPolicyHash: "ph-1")
            XCTFail("a tampered render body must fail verification")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch { /* expected */ }
    }

    // MARK: - 3) An aliased target is rejected (allowedTargets membership)

    func testAliasedTargetIsRejected() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let auth = try await enforcer.register(brainToken(targets: ["answer"]), issuedAt: t0)
        do {
            try await enforcer.authorize(
                auth, scope: .renderHighRisk, target: "mirror",  // NOT in allowedTargets
                expectedActionDigest: expectedDigest(body: "approved-body"),
                expectedPolicyHash: "ph-1")
            XCTFail("an aliased target must be rejected")
        } catch BASSovereignCommitEnforcer.EnforcementError.targetNotAllowed { /* expected */ }
    }

    // MARK: - 4) Replay is rejected (single-use burn)

    func testReplayIsRejected() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let auth = try await enforcer.register(brainToken(), issuedAt: t0)
        try await enforcer.authorize(
            auth, scope: .renderHighRisk, target: "answer",
            expectedActionDigest: expectedDigest(body: "approved-body"),
            expectedPolicyHash: "ph-1")  // first use OK
        do {
            try await enforcer.authorize(
                auth, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: expectedDigest(body: "approved-body"),
                expectedPolicyHash: "ph-1")
            XCTFail("replay must be rejected (single-use)")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed { /* expected */ }
    }

    // MARK: - 5) Expired token is rejected (TTL)

    func testExpiredTokenIsRejected() async throws {
        let clock = BASAuthorityClock()
        let enforcer = makeEnforcer(clock)
        let auth = try await enforcer.register(brainToken(ttlMs: 30_000), issuedAt: t0)
        clock.advance(byMs: 31_000)  // past TTL
        do {
            try await enforcer.authorize(
                auth, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: expectedDigest(body: "approved-body"),
                expectedPolicyHash: "ph-1")
            XCTFail("an expired token must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.expired { /* expected */ }
    }
}
