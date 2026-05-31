import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-06` TokenAuthority.
///
/// The TokenAuthority is the second of the three gates that sit between
/// a generative action and its irreversible execution (the other two
/// being L11 ActionPermit and L14 SnapshotContinuityProof). Every test
/// here exercises one of the rejection paths that has to be impossible
/// to bypass for the "神经不直接掌权" invariant to mean anything in
/// public. If any of these tests ever start passing when they should
/// fail, the invariant is broken.
final class BASSovereignTokenAuthorityTests: XCTestCase {
    // MARK: - Helpers

    private func makeAuthority(
        at baseline: Date = Date(timeIntervalSince1970: 1_700_000_000),
        clock: BASAuthorityClock = BASAuthorityClock()
    ) -> BASSovereignTokenAuthority {
        clock.set(baseline)
        return BASSovereignTokenAuthority(
            signingKey: Curve25519.Signing.PrivateKey(),
            now: { clock.read() }
        )
    }

    private func makeCommitIntent(
        session: String = "session-A",
        turn: String = "turn-1",
        scope: BASSovereignCommitScope = .toolWrite,
        actionDigest: String = "sha256:abc123",
        snapshot: String = "snap-1",
        ttlMs: Int = BASSovereignTrustConstants.defaultCommitTokenTTLMs,
        policyHash: String = BASSovereignTrustConstants.builtInPolicyHash
    ) -> BASSovereignTokenAuthority.CommitIntent {
        BASSovereignTokenAuthority.CommitIntent(
            sessionID: session,
            turnID: turn,
            scope: scope,
            allowedTargets: ["fs.write:/tmp/out"],
            actionDigest: actionDigest,
            snapshotRef: snapshot,
            ttlMs: ttlMs,
            policyHash: policyHash
        )
    }

    private func makeWarrantIntent(
        scope: BASSovereignCommitScope = .hostMutate,
        actionDigest: String = "sha256:host-mut-1",
        jurisdiction: String = "jur-1",
        snapshot: String = "snap-1",
        timeLock: String = "tl-1",
        ttlMs: Int = BASSovereignTrustConstants.defaultCommitTokenTTLMs,
        policyHash: String = BASSovereignTrustConstants.builtInPolicyHash
    ) -> BASSovereignTokenAuthority.WarrantIntent {
        BASSovereignTokenAuthority.WarrantIntent(
            scope: scope,
            actionDigest: actionDigest,
            jurisdictionRef: jurisdiction,
            snapshotRef: snapshot,
            timeLockRef: timeLock,
            ttlMs: ttlMs,
            witnessRefs: ["w-1"],
            policyHash: policyHash
        )
    }

    // MARK: - Commit token: happy paths

    func testIssueCommitTokenBindsAllIntentFields() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent()

        let token = try await authority.issueCommitToken(for: intent)

        XCTAssertTrue(token.tokenID.hasPrefix("sct-"))
        XCTAssertEqual(token.sessionID, intent.sessionID)
        XCTAssertEqual(token.turnID, intent.turnID)
        XCTAssertEqual(token.scope, intent.scope)
        XCTAssertEqual(token.actionDigest, intent.actionDigest)
        XCTAssertEqual(token.snapshotRef, intent.snapshotRef)
        XCTAssertEqual(token.policyHash, intent.policyHash)
        XCTAssertEqual(token.ttlMs, intent.ttlMs)
        XCTAssertTrue(token.singleUse)
        XCTAssertFalse(token.signature.isEmpty)
        XCTAssertFalse(token.nonce.isEmpty)
    }

    func testVerifyCommitTokenPassesForFreshUnredeemedToken() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent()
        let token = try await authority.issueCommitToken(for: intent)

        try await authority.verifyCommitToken(
            token,
            expectedScope: intent.scope,
            expectedActionDigest: intent.actionDigest,
            redeem: false
        )
    }

    func testRedeemingCommitTokenMarksItSpent() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent()
        let token = try await authority.issueCommitToken(for: intent)

        try await authority.verifyCommitToken(
            token,
            expectedScope: intent.scope,
            expectedActionDigest: intent.actionDigest,
            redeem: true
        )

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("re-verifying a redeemed single-use token must throw alreadyUsed")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed(let tokenID) {
            XCTAssertEqual(tokenID, token.tokenID)
        }
    }

    // MARK: - Commit token: rejection paths

    func testVerifyCommitTokenRejectsUnknownToken() async {
        let authority = makeAuthority()
        // Hand-construct a token the authority never issued.
        let orphan = BASSovereignCommitToken(
            tokenID: "sct-orphan",
            sessionID: "s",
            turnID: "t",
            scope: .toolWrite,
            allowedTargets: [],
            actionDigest: "d",
            snapshotRef: "r",
            policyHash: BASSovereignTrustConstants.builtInPolicyHash,
            ttlMs: 1_000,
            nonce: "n",
            signature: "sig"
        )
        do {
            try await authority.verifyCommitToken(
                orphan,
                expectedScope: .toolWrite,
                expectedActionDigest: "d",
                redeem: false
            )
            XCTFail("unknown token must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.unknownToken(let id) {
            XCTAssertEqual(id, "sct-orphan")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testVerifyCommitTokenRejectsScopeMismatch() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent(scope: .toolWrite)
        let token = try await authority.issueCommitToken(for: intent)

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: .memoryWrite, // wrong scope
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("scope mismatch must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.scopeMismatch(let expected, let got) {
            XCTAssertEqual(expected, .memoryWrite)
            XCTAssertEqual(got, .toolWrite)
        }
    }

    func testVerifyCommitTokenRejectsActionDigestMismatch() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent(actionDigest: "sha256:real")
        let token = try await authority.issueCommitToken(for: intent)

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: intent.scope,
                expectedActionDigest: "sha256:forged",
                redeem: false
            )
            XCTFail("actionDigest mismatch must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch(let id) {
            XCTAssertEqual(id, token.tokenID)
        }
    }

    func testVerifyCommitTokenRejectsPolicyHashMismatch() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent(policyHash: "sovereign.policy.v1.0.0")
        let token = try await authority.issueCommitToken(for: intent)

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                expectedPolicyHash: "sovereign.policy.v9.9.9",
                redeem: false
            )
            XCTFail("policyHash mismatch must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.policyHashMismatch(let id) {
            XCTAssertEqual(id, token.tokenID)
        }
    }

    func testVerifyCommitTokenRejectsExpiredToken() async throws {
        let clock = BASAuthorityClock()
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let authority = makeAuthority(at: baseline, clock: clock)

        let intent = makeCommitIntent(ttlMs: 5_000) // 5s TTL
        let token = try await authority.issueCommitToken(for: intent)

        // Advance past TTL.
        clock.advance(byMs: 10_000)

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("expired token must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.expired(let id) {
            XCTAssertEqual(id, token.tokenID)
        }
    }

    func testVerifyCommitTokenRejectsTamperedSignature() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent()
        let token = try await authority.issueCommitToken(for: intent)

        var tampered = token
        // Flip a byte in the base64 signature to a guaranteed-different but
        // still well-formed b64 character.
        tampered.signature = String(token.signature.prefix(token.signature.count - 4)) + "AAAA"

        do {
            try await authority.verifyCommitToken(
                tampered,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("tampered signature must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.signatureInvalid(let id) {
            XCTAssertEqual(id, tampered.tokenID)
        }
    }

    // MARK: - Commit token: invalid intent

    func testIssueCommitTokenRejectsEmptySessionOrTurn() async {
        let authority = makeAuthority()
        let bad = makeCommitIntent(session: "", turn: "")
        do {
            _ = try await authority.issueCommitToken(for: bad)
            XCTFail("empty session/turn must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.invalidIntent {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testIssueCommitTokenRejectsEmptyActionDigest() async {
        let authority = makeAuthority()
        let bad = makeCommitIntent(actionDigest: "")
        do {
            _ = try await authority.issueCommitToken(for: bad)
            XCTFail("empty actionDigest must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.invalidIntent {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testIssueCommitTokenRejectsNonPositiveTTL() async {
        let authority = makeAuthority()
        let bad = makeCommitIntent(ttlMs: 0)
        do {
            _ = try await authority.issueCommitToken(for: bad)
            XCTFail("non-positive ttl must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.invalidIntent {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Nonce uniqueness

    func testNoncesAreUniqueAcrossManyIssuances() async throws {
        let authority = makeAuthority()
        var nonces: Set<String> = []
        for i in 0..<100 {
            let token = try await authority.issueCommitToken(
                for: makeCommitIntent(turn: "turn-\(i)")
            )
            XCTAssertFalse(nonces.contains(token.nonce), "duplicate nonce at \(i)")
            nonces.insert(token.nonce)
        }
        XCTAssertEqual(nonces.count, 100)
    }

    // MARK: - Revocation

    func testRevokeSingleTokenBlocksLaterVerification() async throws {
        let authority = makeAuthority()
        let intent = makeCommitIntent()
        let token = try await authority.issueCommitToken(for: intent)

        await authority.revoke(tokenID: token.tokenID)

        do {
            try await authority.verifyCommitToken(
                token,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("revoked token must be rejected as alreadyUsed")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed(let id) {
            XCTAssertEqual(id, token.tokenID)
        }
    }

    func testRevokeAllTokensBurnsEveryActiveToken() async throws {
        let authority = makeAuthority()
        let t1 = try await authority.issueCommitToken(for: makeCommitIntent(turn: "t-1"))
        let t2 = try await authority.issueCommitToken(for: makeCommitIntent(turn: "t-2"))

        await authority.revokeAllTokens(forSession: "session-A")

        for token in [t1, t2] {
            do {
                try await authority.verifyCommitToken(
                    token,
                    expectedScope: token.scope,
                    expectedActionDigest: token.actionDigest,
                    redeem: false
                )
                XCTFail("revoked token \(token.tokenID) must be rejected")
            } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed {
                // expected
            }
        }

        let activeCount = await authority.activeTokenCount()
        XCTAssertEqual(activeCount, 0)
    }

    // MARK: - Warrants

    func testIssueWarrantBindsAllIntentFields() async throws {
        let authority = makeAuthority()
        let intent = makeWarrantIntent()
        let warrant = try await authority.issueWarrant(for: intent)

        XCTAssertTrue(warrant.warrantID.hasPrefix("swt-"))
        XCTAssertEqual(warrant.scope, intent.scope)
        XCTAssertEqual(warrant.actionDigest, intent.actionDigest)
        XCTAssertEqual(warrant.jurisdictionRef, intent.jurisdictionRef)
        XCTAssertEqual(warrant.snapshotRef, intent.snapshotRef)
        XCTAssertEqual(warrant.timeLockRef, intent.timeLockRef)
        XCTAssertEqual(warrant.policyHash, intent.policyHash)
        XCTAssertEqual(warrant.witnessRefs, intent.witnessRefs)
        XCTAssertNotNil(warrant.issuedAt)
        XCTAssertNotNil(warrant.expiresAt)
        XCTAssertFalse(warrant.signature.isEmpty)
    }

    func testVerifyWarrantHappyPathAndSingleUse() async throws {
        let authority = makeAuthority()
        let intent = makeWarrantIntent()
        let warrant = try await authority.issueWarrant(for: intent)

        try await authority.verifyWarrant(
            warrant,
            expectedScope: intent.scope,
            expectedActionDigest: intent.actionDigest,
            redeem: true
        )

        do {
            try await authority.verifyWarrant(
                warrant,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("redeemed single-use warrant must be rejected on re-verify")
        } catch BASSovereignTokenAuthority.AuthorityError.alreadyUsed(let id) {
            XCTAssertEqual(id, warrant.warrantID)
        }
    }

    func testVerifyWarrantRejectsExpired() async throws {
        let clock = BASAuthorityClock()
        let authority = makeAuthority(clock: clock)
        let intent = makeWarrantIntent(ttlMs: 2_000)
        let warrant = try await authority.issueWarrant(for: intent)

        clock.advance(byMs: 5_000)

        do {
            try await authority.verifyWarrant(
                warrant,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("expired warrant must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.expired(let id) {
            XCTAssertEqual(id, warrant.warrantID)
        }
    }

    func testVerifyWarrantRejectsScopeAndDigestMismatch() async throws {
        let authority = makeAuthority()
        let intent = makeWarrantIntent(scope: .hostMutate, actionDigest: "sha256:mut")
        let warrant = try await authority.issueWarrant(for: intent)

        do {
            try await authority.verifyWarrant(
                warrant,
                expectedScope: .memoryWrite,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("scope mismatch must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.scopeMismatch {
            // expected
        }

        do {
            try await authority.verifyWarrant(
                warrant,
                expectedScope: intent.scope,
                expectedActionDigest: "sha256:forged",
                redeem: false
            )
            XCTFail("digest mismatch must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch {
            // expected
        }
    }

    func testVerifyWarrantRejectsTamperedSignature() async throws {
        let authority = makeAuthority()
        let intent = makeWarrantIntent()
        let warrant = try await authority.issueWarrant(for: intent)

        var tampered = warrant
        tampered.signature = String(warrant.signature.prefix(warrant.signature.count - 4)) + "AAAA"

        do {
            try await authority.verifyWarrant(
                tampered,
                expectedScope: intent.scope,
                expectedActionDigest: intent.actionDigest,
                redeem: false
            )
            XCTFail("tampered warrant signature must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.signatureInvalid(let id) {
            XCTAssertEqual(id, tampered.warrantID)
        }
    }

    // MARK: - Warrant canonical-bytes injectivity (ch1044 全面 audit forgery class)

    private func forge(
        _ w: BASSovereignWarrant,
        jurisdictionRef: String? = nil,
        snapshotRef: String? = nil,
        witnessRefs: [String]? = nil
    ) -> BASSovereignWarrant {
        // A forged warrant: keep the original warrantID + signature (so the ledger
        // lookup + scope/digest/policy checks all pass), but shift a delimiter
        // boundary. Under the OLD `,`/`|`-join these canonicalize identically to the
        // original, so the original signature would validate — the injective encoder
        // must make the canonical bytes DISTINCT so verification fails.
        BASSovereignWarrant(
            warrantID: w.warrantID, scope: w.scope, actionDigest: w.actionDigest,
            commitTokenRef: w.commitTokenRef,
            jurisdictionRef: jurisdictionRef ?? w.jurisdictionRef,
            snapshotRef: snapshotRef ?? w.snapshotRef, timeLockRef: w.timeLockRef,
            policyHash: w.policyHash, issuedAt: w.issuedAt, expiresAt: w.expiresAt,
            witnessRefs: witnessRefs ?? w.witnessRefs, singleUse: w.singleUse,
            signature: w.signature)
    }

    private func warrantIntent(
        actionDigest: String, jurisdiction: String, snapshot: String,
        witnessRefs: [String]
    ) -> BASSovereignTokenAuthority.WarrantIntent {
        BASSovereignTokenAuthority.WarrantIntent(
            scope: .hostMutate, actionDigest: actionDigest, jurisdictionRef: jurisdiction,
            snapshotRef: snapshot, timeLockRef: "tl-1", ttlMs: 60_000,
            witnessRefs: witnessRefs,
            policyHash: BASSovereignTrustConstants.builtInPolicyHash)
    }

    /// witnessRefs `["a,b"]` and `["a","b"]` `,`-join to the same string — the list
    /// boundary forgery. The injective `.list(...)` (count + per-element length
    /// prefix) must make them cross-validate-proof.
    func testWarrantWitnessRefListBoundaryCannotForge() async throws {
        let authority = makeAuthority()
        let warrantA = try await authority.issueWarrant(
            for: warrantIntent(actionDigest: "sha256:wf1", jurisdiction: "jur",
                               snapshot: "snap", witnessRefs: ["a,b"]))
        let forged = forge(warrantA, witnessRefs: ["a", "b"])
        do {
            try await authority.verifyWarrant(
                forged, expectedScope: .hostMutate, expectedActionDigest: "sha256:wf1",
                redeem: false)
            XCTFail("witnessRef list-boundary forgery must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.signatureInvalid { /* expected */ }
    }

    /// jurisdictionRef `"j"` + snapshotRef `"s|x"` vs `"j|s"` + `"x"` `|`-join to the
    /// same field stream — the field boundary forgery.
    func testWarrantFieldBoundaryCannotForge() async throws {
        let authority = makeAuthority()
        let warrantA = try await authority.issueWarrant(
            for: warrantIntent(actionDigest: "sha256:wf2", jurisdiction: "j",
                               snapshot: "s|x", witnessRefs: ["w"]))
        let forged = forge(warrantA, jurisdictionRef: "j|s", snapshotRef: "x")
        do {
            try await authority.verifyWarrant(
                forged, expectedScope: .hostMutate, expectedActionDigest: "sha256:wf2",
                redeem: false)
            XCTFail("field-boundary forgery must be rejected")
        } catch BASSovereignTokenAuthority.AuthorityError.signatureInvalid { /* expected */ }
    }

    /// Positive control: a LEGITIMATE warrant whose fields genuinely CONTAIN `,`/`|`
    /// must still round-trip issue→verify. The injective encoder HANDLES separators
    /// (unlike rejecting them) — distinct content stays distinct, valid content stays
    /// valid.
    func testWarrantWithSeparatorsInFieldsStillRoundTrips() async throws {
        let authority = makeAuthority()
        let warrant = try await authority.issueWarrant(
            for: warrantIntent(actionDigest: "sha256:rt", jurisdiction: "a|b",
                               snapshot: "c,d", witnessRefs: ["x,y", "z"]))
        try await authority.verifyWarrant(
            warrant, expectedScope: .hostMutate, expectedActionDigest: "sha256:rt",
            redeem: true)
    }

    // MARK: - Diagnostics

    func testDiagnosticsTrackIssuanceAndActiveCounts() async throws {
        let authority = makeAuthority()
        var issued = await authority.issuedTokenCount()
        var active = await authority.activeTokenCount()
        XCTAssertEqual(issued, 0)
        XCTAssertEqual(active, 0)

        let t = try await authority.issueCommitToken(for: makeCommitIntent())
        issued = await authority.issuedTokenCount()
        active = await authority.activeTokenCount()
        XCTAssertEqual(issued, 1)
        XCTAssertEqual(active, 1)

        try await authority.verifyCommitToken(
            t,
            expectedScope: t.scope,
            expectedActionDigest: t.actionDigest,
            redeem: true
        )
        issued = await authority.issuedTokenCount()
        active = await authority.activeTokenCount()
        XCTAssertEqual(issued, 1)
        XCTAssertEqual(active, 0)

        _ = try await authority.issueWarrant(for: makeWarrantIntent())
        let warrants = await authority.issuedWarrantCount()
        XCTAssertEqual(warrants, 1)
    }
}

// MARK: - Test clock

/// Simple mutable clock for deterministic TTL tests. Lives in the test
/// target only; production code uses wall-clock `Date()`.
final class BASAuthorityClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func read() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }

    func advance(byMs ms: Int) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(TimeInterval(ms) / 1000.0)
    }
}
