// Adversarial (red-team) tests of the commit-token / commit-gate authority.
//
// The fail-closed contract these probe (mirrors the existing enforcer / gated-turn
// suites): the Ed25519 `BASSovereignTokenAuthority` is LOAD-BEARING. A commit token only
// authorizes an irreversible op if the authority MINTED + LEDGERED it — so a token absent
// from the authority's ledger is rejected (`unknownToken`) BEFORE its carried `signature`
// is ever examined; tokens + ledgers do NOT cross host boundaries; and a single-use burn is
// race-safe under concurrent replay. Each test stands up real objects exactly as the existing
// tests do and asserts the verify/authorize path THROWS — i.e. the op would NEVER run.
//
// SCOPE NOTE (honest): these tests probe the REGISTRATION / LEDGER guard, which fires first.
// The keyless-tag-vs-Ed25519-signature distinction itself (a LEDGERED token whose signature is
// forged → `signatureInvalid`) is exercised at the authority level by
// BASSovereignTokenAuthorityTests.testVerifyCommitTokenRejectsTamperedSignature.

import XCTest
import CryptoKit
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASCommitGateRedTeamTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers (mirror BASSovereignCommitEnforcerTests / GatedTurnTests)

    /// An enforcer backed by a fresh authority whose clock is pinned to `t0`. Mirrors the
    /// `makeEnforcer` helper in the existing enforcer suite (authority + same `now`).
    private func makeEnforcer(_ clock: BASAuthorityClock) -> BASSovereignCommitEnforcer {
        clock.set(t0)
        let authority = BASSovereignTokenAuthority(now: { clock.read() })
        return BASSovereignCommitEnforcer(authority: authority, now: { clock.read() })
    }

    /// A brain-emitted renderHighRisk token — same construction as the existing suites'
    /// `brainToken` helper. `actionDigest` is the shared canonical digest over
    /// `["answer","headline",body]` + turn identity, so the host's independent recompute
    /// (`expectedDigest`) matches a LEGITIMATELY registered token.
    private func brainToken(
        body: String = "approved-body",
        targets: [String] = ["answer"],
        policyHash: String = "ph-1",
        ttlMs: Int = 60_000,
        signature: String = "keyless-sha256"
    ) -> BASSovereignCommitToken {
        let digest = BASSovereignActionDigest.compute(
            scope: .renderHighRisk,
            actionDigestParts: ["answer", "headline", body],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: policyHash)
        return BASSovereignCommitToken(
            tokenID: "tok-render", sessionID: "s1", turnID: "t1", scope: .renderHighRisk,
            allowedTargets: targets, actionDigest: digest, snapshotRef: "snap",
            policyHash: policyHash, ttlMs: ttlMs, nonce: "nonce-1", singleUse: true,
            signature: signature)
    }

    /// The host's INDEPENDENT recompute from the artifact it is ACTUALLY about to render —
    /// identical formula to the existing suites' `expectedDigest` helper.
    private func expectedDigest(body: String, policyHash: String = "ph-1") -> String {
        BASSovereignActionDigest.compute(
            scope: .renderHighRisk,
            actionDigestParts: ["answer", "headline", body],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: policyHash)
    }

    // MARK: - 1) An unregistered token is rejected by the ledger guard (before any signature check)

    /// What this proves: a token that was never minted/registered through the Ed25519 authority is rejected at
    /// the LEDGER guard (`unknownToken`), which fires FIRST in `verifyCommitToken` — before scope/digest/policy
    /// and before the signature is ever examined. So the token's carried `signature` value is irrelevant here:
    /// the authority trusts only its own ledger. (The signature-forgery branch is covered separately by
    /// BASSovereignTokenAuthorityTests.testVerifyCommitTokenRejectsTamperedSignature.) `target` is a LEGAL
    /// allowedTarget so the enforcer's target gate passes and control reaches the AUTHORITY verify — proving the
    /// authority (not the target gate) rejects, via `unknownToken` carrying the tokenID.
    func testUnregisteredTokenRejectedByLedgerGuard() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        // A token NEVER passed through `enforcer.register(...)`, so the authority has no ledger record for its
        // tokenID. Its `signature` string is arbitrary — and never reached, since the ledger guard fires first.
        let unregistered = brainToken(signature: "arbitrary-tag-never-reached-the-signature-check")
        do {
            try await enforcer.authorize(
                unregistered, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: expectedDigest(body: "approved-body"),
                expectedPolicyHash: "ph-1")
            XCTFail("an unregistered token (never minted via the Ed25519 authority) must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.unknownToken(let id) {
            XCTAssertEqual(id, "tok-render",
                "rejected by the AUTHORITY's ledger guard (not the enforcer target gate)")
        }
    }

    // MARK: - 2) Cross-host token is rejected (LEDGER isolation across hosts)

    /// Mint/register a token via authority A; build authority B with a DIFFERENT key AND an empty ledger; present
    /// A's token to B. B's ledger has no record of A's tokenID, so verify throws `unknownToken` at the FIRST
    /// guard — before B's public key is ever consulted. So what this proves is LEDGER isolation across hosts (a
    /// token only authorizes against the authority that ledgered it), not signature/key validation (that branch
    /// is unreached here; it is covered by BASSovereignTokenAuthorityTests). The differing signing keys make A's
    /// token genuinely foreign, but the ledger guard is what fires.
    func testCrossHostTokenRejectedByLedgerIsolation() async throws {
        // Host A — register a real Ed25519 token in A's ledger.
        let clockA = BASAuthorityClock(); clockA.set(t0)
        let authorityA = BASSovereignTokenAuthority(
            signingKey: Curve25519.Signing.PrivateKey(), now: { clockA.read() })
        let enforcerA = BASSovereignCommitEnforcer(authority: authorityA, now: { clockA.read() })
        let registered = try await enforcerA.register(brainToken(), issuedAt: t0)

        // Host B — a DIFFERENT signing key, a DIFFERENT (empty) ledger.
        let clockB = BASAuthorityClock(); clockB.set(t0)
        let authorityB = BASSovereignTokenAuthority(
            signingKey: Curve25519.Signing.PrivateKey(), now: { clockB.read() })
        let enforcerB = BASSovereignCommitEnforcer(authority: authorityB, now: { clockB.read() })

        // A's registered token presented to B's enforcer → B never minted this tokenID → unknownToken.
        do {
            try await enforcerB.authorize(
                registered, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: expectedDigest(body: "approved-body"),
                expectedPolicyHash: "ph-1")
            XCTFail("a token minted by host A must not authorize an op against host B")
        } catch BASSovereignTokenAuthority.AuthorityError.unknownToken {
            // expected — B's ledger has no record of A's tokenID (the guard that fires first).
        }

        // Direct authority-level cross-check: A's registered token against B's verify path.
        do {
            try await authorityB.verifyCommitToken(
                registered, expectedScope: .renderHighRisk,
                expectedActionDigest: registered.actionDigest,
                expectedPolicyHash: "ph-1", redeem: false)
            XCTFail("cross-host verify must fail (ledger isolation)")
        } catch BASSovereignTokenAuthority.AuthorityError.unknownToken {
            // expected — ledger isolation
        }
    }

    // MARK: - 3) Concurrent replay burns EXACTLY once (race-safe single-use)

    /// Register ONE single-use token, then fire N concurrent `authorize` calls. The
    /// actor-isolated enforcer/authority must serialize the single-use burn so EXACTLY one
    /// succeeds and the rest throw `alreadyUsed`. Locals are hoisted so the task closures
    /// capture only Sendable values (the actor + plain strings).
    func testConcurrentReplayBurnsExactlyOnce() async throws {
        let enforcer = makeEnforcer(BASAuthorityClock())
        let registered = try await enforcer.register(brainToken(), issuedAt: t0)

        // Hoisted Sendable locals — no non-Sendable capture inside the task closures.
        let attempts = 16
        let token = registered
        let digest = expectedDigest(body: "approved-body")
        let policyHash = "ph-1"

        let successes = await withTaskGroup(of: Bool.self) { group -> Int in
            for _ in 0..<attempts {
                group.addTask {
                    do {
                        try await enforcer.authorize(
                            token, scope: .renderHighRisk, target: "answer",
                            expectedActionDigest: digest, expectedPolicyHash: policyHash)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var count = 0
            for await ok in group where ok { count += 1 }
            return count
        }

        XCTAssertEqual(
            successes, 1,
            "a single-use token must authorize EXACTLY once across \(attempts) concurrent replays")

        // And it stays burned afterwards.
        do {
            try await enforcer.authorize(
                token, scope: .renderHighRisk, target: "answer",
                expectedActionDigest: digest, expectedPolicyHash: policyHash)
            XCTFail("a burned single-use token must stay burned after the concurrent race")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed { /* expected */ }
    }
}
