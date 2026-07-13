import XCTest
import CryptoKit
@testable import QinaoRuntime
@testable import QinaoSovereign
@testable import QinaoRisk

/// integration S3 (2026-07-12) — audit F2 discharge: warrant + snapshot proof are
/// HMAC-signed at mint and verified signature-first. Forgery now requires the key.
final class QinaoTokenSigningTests: XCTestCase {

    private func frozen() -> @Sendable () -> Date {
        { Date(timeIntervalSince1970: 1_700_000_000) }
    }

    // MARK: - Warrant

    /// A hand-built warrant with perfect field binding but no key → invalid.
    func testForgedWarrantFailsVerification() async {
        let fx = await QinaoTestFixture.make()
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "intent.forge", sessionID: "sess.f", hostVersionID: "host.v1")
        let forged = QinaoSovereignControlPlane.Warrant(
            warrantID: "wa-forged",
            sessionID: intent.sessionID,
            intentDigest: intent.digest,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_000_030),
            signature: "deadbeef")
        let valid = await fx.sovereign.isWarrantValid(forged, for: intent)
        XCTAssertFalse(valid, "a warrant not minted with the control plane's key must fail")
    }

    /// Tampering ANY signed field after mint invalidates the warrant (signature binds all 5).
    func testTamperedWarrantFieldBreaksSignature() async throws {
        let fx = await QinaoTestFixture.make()
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "intent.real", sessionID: "sess.t", hostVersionID: "host.v1")
        let real = try await fx.sovereign.issueWarrant(for: intent)
        let sane = await fx.sovereign.isWarrantValid(real, for: intent)
        XCTAssertTrue(sane, "freshly-minted warrant must verify")

        // Same signature, redirected digest → the tag no longer matches.
        let redirected = QinaoSovereignControlPlane.Warrant(
            warrantID: real.warrantID,
            sessionID: real.sessionID,
            intentDigest: "intent.SWAPPED",
            issuedAt: real.issuedAt,
            expiresAt: real.expiresAt,
            signature: real.signature)
        let swappedIntent = QinaoSovereignControlPlane.Intent(
            digest: "intent.SWAPPED", sessionID: "sess.t", hostVersionID: "host.v1")
        let valid = await fx.sovereign.isWarrantValid(redirected, for: swappedIntent)
        XCTAssertFalse(valid, "redirecting a signed warrant to another digest must fail")
    }

    // MARK: - Snapshot proof (the pre-S3 gate checked ONLY intentDigest)

    // deep-audit P0-1: the intent's digest canonically binds the presented tool+payload — the gate
    // tests below execute with an empty payload, so bind that.
    private func makeIntent(session: String = "sess.p") -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            toolName: "calendar.add_event", payload: Data(),
            sessionID: session, hostVersionID: "host.v1", summary: "s")
    }

    private func signatures(
        fx: QinaoTestFixture,
        intent: QinaoRiskGate.ActionIntent,
        proof: QinaoRuntime.SnapshotContinuityProof
    ) async throws -> QinaoRuntime.Signatures {
        let permit = try await fx.risk.requestActionPermit(for: intent)
        let warrant = try await fx.sovereign.issueWarrant(
            for: .init(digest: intent.digest, sessionID: intent.sessionID,
                       hostVersionID: intent.hostVersionID))
        return .init(permit: permit, warrant: warrant, snapshotProof: proof)
    }

    /// A hand-built (unsigned) proof with a matching digest — passed the pre-S3 gate,
    /// must now be refused.
    func testHandBuiltProofIsRefusedByGate() async throws {
        let fx = await QinaoTestFixture.make()
        let intent = makeIntent()
        let handBuilt = QinaoRuntime.SnapshotContinuityProof(
            proofID: "proof-hand", sessionID: intent.sessionID,
            anchorID: "anchor", intentDigest: intent.digest,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_000_030),
            signature: "")
        let sigs = try await signatures(fx: fx, intent: intent, proof: handBuilt)
        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: intent.toolName, payload: Data(),
                intent: intent, signatures: sigs)
        ) { error in
            guard case QinaoRuntime.RuntimeError.missingSnapshotProof = error else {
                return XCTFail("expected missingSnapshotProof, got \(error)")
            }
        }
    }

    /// An EXPIRED signed proof — expiry was silently unchecked pre-S3; must now refuse.
    func testExpiredProofIsRefusedByGate() async throws {
        let clock = QinaoTestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        let fx = await QinaoTestFixture.make(now: { clock.t })
        let intent = makeIntent()
        let proof = await fx.sovereign.issueSnapshotContinuityProof(
            for: .init(digest: intent.digest, sessionID: intent.sessionID,
                       hostVersionID: intent.hostVersionID),
            anchorID: "anchor", ttlSeconds: 5)
        // permit/warrant TTL default 10s in fixture; advance past the proof's 5s only.
        clock.t = clock.t.addingTimeInterval(7)
        let sigs = try await signatures(fx: fx, intent: intent, proof: proof)
        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: intent.toolName, payload: Data(),
                intent: intent, signatures: sigs)
        ) { error in
            guard case QinaoRuntime.RuntimeError.missingSnapshotProof = error else {
                return XCTFail("expected missingSnapshotProof, got \(error)")
            }
        }
    }

    /// A signed proof for the SAME digest but ANOTHER session — sessionID was silently
    /// unchecked pre-S3; must now refuse.
    func testCrossSessionProofIsRefusedByGate() async throws {
        let fx = await QinaoTestFixture.make()
        let intent = makeIntent(session: "sess.real")
        let otherSessionProof = await fx.sovereign.issueSnapshotContinuityProof(
            for: .init(digest: intent.digest, sessionID: "sess.OTHER",
                       hostVersionID: intent.hostVersionID),
            anchorID: "anchor")
        let sigs = try await signatures(fx: fx, intent: intent, proof: otherSessionProof)
        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: intent.toolName, payload: Data(),
                intent: intent, signatures: sigs)
        ) { error in
            guard case QinaoRuntime.RuntimeError.missingSnapshotProof = error else {
                return XCTFail("expected missingSnapshotProof, got \(error)")
            }
        }
    }

    /// Happy path stays green: minted warrant + minted proof cross the gate.
    func testMintedTokensCrossTheGate() async throws {
        let fx = await QinaoTestFixture.make()
        let intent = makeIntent()
        let proof = await fx.sovereign.issueSnapshotContinuityProof(
            for: .init(digest: intent.digest, sessionID: intent.sessionID,
                       hostVersionID: intent.hostVersionID),
            anchorID: "anchor")
        let sigs = try await signatures(fx: fx, intent: intent, proof: proof)
        // The fixture's recorder-executor returns empty Data; the assertion is that the
        // gate PASSED (no throw) with minted tokens — the negative tests above prove the
        // same gate refuses forged/expired/cross-session tokens.
        _ = try await fx.runtime.execute(
            toolName: intent.toolName, payload: Data(),
            intent: intent, signatures: sigs)  // P0-1: match makeIntent binding
    }
}

/// Mutable clock for TTL tests (class + @unchecked Sendable, single-test use).
final class QinaoTestClock: @unchecked Sendable {
    var t: Date
    init(start: Date) { self.t = start }
}
