// ADR-032 — tests for the host-side LIVE crypto commit-gate (BASSovereignGatedTurn) and
// the shared per-scope artifact formula (BASSovereignTurnArtifactParts). Proves the gate
// runs the host op ONLY when the result's artifact matches the emitted token, and fails
// CLOSED on every divergence (tampered artifact / aliased target / replay / no token).
// Uses the primitive core so no heavy BASEBrainTurnResult fixture is needed.

import XCTest
import CryptoKit
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignGatedTurnTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private actor OpCounter {
        private(set) var count = 0
        func bump() { count += 1 }
        func get() -> Int { count }
    }

    /// Test provider for the gate's INDEPENDENT trusted-policy-hash recompute. Defaults to "ph-1" (the
    /// renderToken's policyHash) for the happy path; can return a stale hash or throw to exercise rejection.
    private struct StubPolicyHashProvider: BASTrustedPolicyHashProvider {
        var hash: String? = "ph-1"
        var error: Error? = nil
        func trustedPolicyHash() throws -> String {
            if let error { throw error }
            return hash ?? ""
        }
    }

    private func makeEnforcer(_ clock: BASAuthorityClock) -> BASSovereignCommitEnforcer {
        clock.set(t0)
        return BASSovereignCommitEnforcer(
            authority: BASSovereignTokenAuthority(now: { clock.read() }),
            now: { clock.read() })
    }

    /// A renderHighRisk commit token whose signed digest is over `body` (the approved
    /// artifact) — exactly as `buildSovereignCommitTokens` would emit it (same shared
    /// parts formula), so the gate's recompute matches when the host's body matches.
    private func renderToken(body: String, mode: String = "answer", ttlMs: Int = 60_000) -> BASSovereignCommitToken {
        let parts = BASSovereignTurnArtifactParts.parts(
            scope: .renderHighRisk, foldID: "f1", renderMode: mode,
            renderHeadline: "head", renderBody: body,
            ticketActionDigestParts: [], ticketCount: 0)!
        let digest = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: parts,
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")
        return BASSovereignCommitToken(
            tokenID: "tok-render", sessionID: "s1", turnID: "t1", scope: .renderHighRisk,
            allowedTargets: [mode], actionDigest: digest, snapshotRef: "snap",
            policyHash: "ph-1", ttlMs: ttlMs, nonce: "nonce-1", singleUse: true,
            signature: "keyless-sha256")
    }

    @discardableResult
    private func gateRender(
        tokens: [BASSovereignCommitToken], target: String, body: String, mode: String = "answer",
        enforcer: BASSovereignCommitEnforcer, counter: OpCounter,
        provider: BASTrustedPolicyHashProvider = StubPolicyHashProvider()
    ) async throws -> String {
        try await BASSovereignGatedTurn.gate(
            commitTokens: tokens, scope: .renderHighRisk, target: target,
            foldID: "f1", renderMode: mode, renderHeadline: "head", renderBody: body,
            ticketActionDigestParts: [], ticketCount: 0, enforcer: enforcer,
            trustedPolicyHashProvider: provider
        ) { await counter.bump(); return "rendered" }
    }

    // MARK: - 1) artifact matches the emitted token → op runs

    func testGateRunsOpWhenArtifactMatchesToken() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        let out = try await gateRender(
            tokens: [renderToken(body: "approved")], target: "answer",
            body: "approved", enforcer: enforcer, counter: counter)
        XCTAssertEqual(out, "rendered")
        let n = await counter.get()
        XCTAssertEqual(n, 1, "op must run exactly once when the artifact matches the token")
    }

    // MARK: - 2) tampered artifact (body differs) → DENY, op never runs

    func testGateDeniesTamperedArtifact() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        do {
            _ = try await gateRender(
                tokens: [renderToken(body: "approved")], target: "answer",
                body: "EVIL injected body", enforcer: enforcer, counter: counter)
            XCTFail("a tampered artifact must be denied before the op runs")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "op must NOT run when the artifact digest mismatches")
    }

    // MARK: - 3) no emitted token for the scope → fail-closed

    func testGateFailsClosedWhenNoTokenForScope() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        do {
            _ = try await gateRender(
                tokens: [], target: "answer", body: "approved",
                enforcer: enforcer, counter: counter)
            XCTFail("no commit token for the scope must fail CLOSED")
        } catch BASSovereignGatedTurn.GateError.noCommitTokenForScope(let s) {
            XCTAssertEqual(s, .renderHighRisk)
        }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "op must NOT run when the brain emitted no token for the scope")
    }

    // MARK: - 4) aliased target → DENY

    func testGateDeniesAliasedTarget() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        do {
            _ = try await gateRender(
                tokens: [renderToken(body: "approved")], target: "mirror",  // not in allowedTargets
                body: "approved", enforcer: enforcer, counter: counter)
            XCTFail("an aliased target must be denied")
        } catch BASSovereignCommitEnforcer.EnforcementError.targetNotAllowed { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "op must NOT run for an aliased target")
    }

    // MARK: - 5) replay (single-use) → op runs exactly once

    func testGateRejectsReplay() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        let tokens = [renderToken(body: "approved")]
        _ = try await gateRender(tokens: tokens, target: "answer", body: "approved", enforcer: enforcer, counter: counter)
        do {
            _ = try await gateRender(tokens: tokens, target: "answer", body: "approved", enforcer: enforcer, counter: counter)
            XCTFail("replay must be rejected (single-use)")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed { /* expected */ }
        let n = await counter.get()
        XCTAssertEqual(n, 1, "the irreversible op must run EXACTLY once across a replay")
    }

    // MARK: - 5b) stale/swapped policy hash → DENY (the independent recompute closes the tautology)

    func testGateDeniesStalePolicyHash() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        do {
            _ = try await gateRender(
                tokens: [renderToken(body: "approved")], target: "answer", body: "approved",
                enforcer: enforcer, counter: counter,
                provider: StubPolicyHashProvider(hash: "ph-STALE-rotated"))   // trusted ≠ token's "ph-1"
            XCTFail("a token minted under a different policy lineage must be denied")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch {
            // expected — policyHash folds into the actionDigest, so the independent recompute's digest mismatches
            // FIRST (verifyCommitToken checks actionDigest before policyHash). The isolated policyHashMismatch
            // path is covered by BASSovereignTokenAuthorityTests.testVerifyCommitTokenRejectsPolicyHashMismatch.
        }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "op must NOT run when the trusted policy hash differs from the token's")
    }

    // MARK: - 5c) trusted policy hash unavailable (nil/malformed host lineage) → FAIL CLOSED

    func testGateFailsClosedWhenTrustedPolicyHashUnavailable() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let counter = OpCounter()
        do {
            _ = try await gateRender(
                tokens: [renderToken(body: "approved")], target: "answer", body: "approved",
                enforcer: enforcer, counter: counter,
                provider: StubPolicyHashProvider(
                    hash: nil, error: BASTrustedPolicyHashError.missingRuntimePolicyLineage))
            XCTFail("a missing host policy lineage must fail CLOSED (op never runs)")
        } catch BASTrustedPolicyHashError.missingRuntimePolicyLineage {
            // expected — the gate cannot source a trusted hash, so it must not proceed
        }
        let n = await counter.get()
        XCTAssertEqual(n, 0, "op must NOT run when the trusted policy hash is unavailable")
    }

    // MARK: - 6) the shared parts formula — all scopes + tamper-sensitivity

    func testArtifactPartsFormula() {
        XCTAssertEqual(
            BASSovereignTurnArtifactParts.parts(
                scope: .checkpointCommit, foldID: "F", renderMode: "answer",
                renderHeadline: "h", renderBody: "b",
                ticketActionDigestParts: [["a"], ["b"]], ticketCount: 2),
            ["checkpoint", "F", "answer", "2"])
        XCTAssertEqual(
            BASSovereignTurnArtifactParts.parts(
                scope: .memoryWrite, foldID: "F", renderMode: "answer",
                renderHeadline: "h", renderBody: "b",
                ticketActionDigestParts: [["t1a", "t1b"], ["t2a"]], ticketCount: 2),
            ["t1a", "t1b", "t2a"])
        XCTAssertEqual(
            BASSovereignTurnArtifactParts.parts(
                scope: .renderHighRisk, foldID: "F", renderMode: "answer",
                renderHeadline: "head", renderBody: "body",
                ticketActionDigestParts: [], ticketCount: 0),
            ["answer", "head", "body"])
        // Tamper-sensitivity: changing the body changes the render parts → digest → deny.
        let approved = BASSovereignTurnArtifactParts.parts(
            scope: .renderHighRisk, foldID: "F", renderMode: "answer",
            renderHeadline: "head", renderBody: "approved",
            ticketActionDigestParts: [], ticketCount: 0)
        let tampered = BASSovereignTurnArtifactParts.parts(
            scope: .renderHighRisk, foldID: "F", renderMode: "answer",
            renderHeadline: "head", renderBody: "EVIL",
            ticketActionDigestParts: [], ticketCount: 0)
        XCTAssertNotEqual(approved, tampered)
    }
}
