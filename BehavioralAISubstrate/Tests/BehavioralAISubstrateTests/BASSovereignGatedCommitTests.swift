// ADR-025 option B / ADR-026 — end-to-end tests for the host-callable gated-execution
// seam (`BASSovereignGatedCommit`). Proves the irreversible op runs ONLY on a clean
// authorization, and every gate failure (tampered artifact / aliased target / replay /
// TTL) keeps the op from running. Mirrors the enforcer-test fixtures.

import XCTest
import CryptoKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignGatedCommitTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Counts how many times a gated op actually ran — the proof an irreversible op did
    /// (or did NOT) execute.
    private actor OpCounter {
        private(set) var count = 0
        func bump() { count += 1 }
        func get() -> Int { count }
    }

    /// A brain-emitted renderHighRisk token (keyless SHA256 `signature`, as
    /// `makeCommitToken` produces). `actionDigest` is the canonical digest over
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

    private func makeGated(_ clock: BASAuthorityClock) -> BASSovereignGatedCommit {
        clock.set(t0)
        let authority = BASSovereignTokenAuthority(now: { clock.read() })
        let enforcer = BASSovereignCommitEnforcer(authority: authority, now: { clock.read() })
        return BASSovereignGatedCommit(enforcer: enforcer)
    }

    // MARK: - 1) Valid authorization runs the op + returns its value

    func testExecuteGatedRunsOpOnValidAuthorization() async throws {
        let gated = makeGated(BASAuthorityClock())
        let auth = try await gated.register(brainToken(), issuedAt: t0)
        let counter = OpCounter()
        let result = try await gated.executeGated(
            token: auth, scope: .renderHighRisk, target: "answer",
            approvedArtifactParts: ["answer", "headline", "approved-body"],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
        ) { await counter.bump(); return "rendered" }
        XCTAssertEqual(result, "rendered")
        let n = await counter.get()
        XCTAssertEqual(n, 1, "the op must run exactly once on a clean authorization")
    }

    // MARK: - 2) A tampered artifact → digest mismatch → op NEVER runs

    func testExecuteGatedDoesNotRunOpOnTamperedArtifact() async throws {
        let gated = makeGated(BASAuthorityClock())
        let auth = try await gated.register(brainToken(body: "approved-body"), issuedAt: t0)
        let counter = OpCounter()
        do {
            _ = try await gated.executeGated(
                token: auth, scope: .renderHighRisk, target: "answer",
                approvedArtifactParts: ["answer", "headline", "EVIL injected body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
            ) { await counter.bump(); return "rendered" }
            XCTFail("a tampered artifact must fail the gate before the op runs")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "the op must NOT run when the artifact digest mismatches")
    }

    // MARK: - 3) An aliased target → op NEVER runs

    func testExecuteGatedDoesNotRunOpOnAliasedTarget() async throws {
        let gated = makeGated(BASAuthorityClock())
        let auth = try await gated.register(brainToken(targets: ["answer"]), issuedAt: t0)
        let counter = OpCounter()
        do {
            _ = try await gated.executeGated(
                token: auth, scope: .renderHighRisk, target: "mirror",  // NOT in allowedTargets
                approvedArtifactParts: ["answer", "headline", "approved-body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
            ) { await counter.bump(); return "rendered" }
            XCTFail("an aliased target must be rejected before the op runs")
        } catch BASSovereignCommitEnforcer.EnforcementError.targetNotAllowed { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "the op must NOT run for an aliased target")
    }

    // MARK: - 4) Replay (single-use) → op runs once, second attempt rejected

    func testExecuteGatedRejectsReplay() async throws {
        let gated = makeGated(BASAuthorityClock())
        let auth = try await gated.register(brainToken(), issuedAt: t0)
        let counter = OpCounter()
        let parts = ["answer", "headline", "approved-body"]
        _ = try await gated.executeGated(
            token: auth, scope: .renderHighRisk, target: "answer",
            approvedArtifactParts: parts,
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
        ) { await counter.bump(); return "rendered" }
        do {
            _ = try await gated.executeGated(
                token: auth, scope: .renderHighRisk, target: "answer",
                approvedArtifactParts: parts,
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
            ) { await counter.bump(); return "rendered" }
            XCTFail("replay must be rejected (single-use)")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 1, "the irreversible op must run EXACTLY once across a replay")
    }

    // MARK: - 5) Expired token → op NEVER runs

    func testExecuteGatedRejectsExpiredToken() async throws {
        let clock = BASAuthorityClock()
        let gated = makeGated(clock)
        let auth = try await gated.register(brainToken(ttlMs: 30_000), issuedAt: t0)
        clock.advance(byMs: 31_000)  // past TTL
        let counter = OpCounter()
        do {
            _ = try await gated.executeGated(
                token: auth, scope: .renderHighRisk, target: "answer",
                approvedArtifactParts: ["answer", "headline", "approved-body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1"
            ) { await counter.bump(); return "rendered" }
            XCTFail("an expired token must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.expired { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "the op must NOT run for an expired token")
    }

    // MARK: - 6) register preserves the brain token's identity

    func testRegisterPreservesIdentity() async throws {
        let gated = makeGated(BASAuthorityClock())
        let brain = brainToken()
        let auth = try await gated.register(brain, issuedAt: t0)
        XCTAssertEqual(auth.tokenID, brain.tokenID)
        XCTAssertEqual(auth.nonce, brain.nonce)
        XCTAssertEqual(auth.scope, brain.scope)
        XCTAssertEqual(auth.actionDigest, brain.actionDigest)
        XCTAssertEqual(auth.allowedTargets, brain.allowedTargets)
        XCTAssertEqual(auth.policyHash, brain.policyHash)
    }
}
