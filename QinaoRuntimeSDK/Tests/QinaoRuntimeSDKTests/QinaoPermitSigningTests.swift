import XCTest
import CryptoKit
@testable import QinaoRisk

/// integration permit-signing (2026-07-12) — the risk permit, the three-signature gate's
/// last field-binding-only lane, is now HMAC-signed at mint and verified signature-first.
/// This is the cross-process precondition: a permit minted on one gate verifies on
/// another gate holding the SAME key, and on nothing else.
final class QinaoPermitSigningTests: XCTestCase {

    private func makeIntent() -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: "intent.permit.sign", toolName: "calendar.add_event",
            sessionID: "sess.ps", hostVersionID: "host.v1", summary: "s")
    }

    /// A hand-built permit with perfect fields and mode .allow but no key → invalid.
    /// (Pre-signing this passed every check — the confused-deputy forgery lane.)
    func testHandBuiltAllowPermitFailsVerification() async {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let intent = makeIntent()
        let forged = QinaoRiskGate.ActionPermit(
            permitID: "permit-forged", digest: intent.digest,
            sessionID: intent.sessionID, mode: .allow,
            reasonCodes: [], issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(30),
            signature: "deadbeef")
        let ok = await gate.isPermitValid(forged, for: intent)
        XCTAssertFalse(ok, "a permit not minted with the gate's key must fail closed")
    }

    /// Tampering a signed field after mint (digest redirect) breaks the tag even when
    /// the redirected intent matches the tampered fields.
    func testRedirectedPermitBreaksSignature() async throws {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let intent = makeIntent()
        let real = try await gate.requestActionPermit(for: intent)

        let redirected = QinaoRiskGate.ActionPermit(
            permitID: real.permitID, digest: "intent.SWAPPED",
            sessionID: real.sessionID, mode: real.mode,
            reasonCodes: real.reasonCodes, issuedAt: real.issuedAt,
            expiresAt: real.expiresAt, signature: real.signature)
        let swapped = QinaoRiskGate.ActionIntent(
            digest: "intent.SWAPPED", toolName: intent.toolName,
            sessionID: intent.sessionID, hostVersionID: intent.hostVersionID,
            summary: intent.summary)
        let ok = await gate.isPermitValid(redirected, for: swapped)
        XCTAssertFalse(ok, "redirecting a signed permit to another digest must fail")
    }

    /// THE cross-process story: two gates sharing a key — permit minted on gate A
    /// verifies on gate B; a third gate with a DIFFERENT key refuses it.
    func testSharedKeyVerifiesAcrossGateInstances() async throws {
        let sharedKey = SymmetricKey(data: Data("cross-process-permit-key".utf8))
        let gateA = QinaoRiskGate(permitTTLSeconds: 30, permitTagKey: sharedKey)
        let gateB = QinaoRiskGate(permitTTLSeconds: 30, permitTagKey: sharedKey)
        let gateC = QinaoRiskGate(permitTTLSeconds: 30)  // different (random) key
        let intent = makeIntent()

        let permit = try await gateA.requestActionPermit(for: intent)
        let onB = await gateB.isPermitValid(permit, for: intent)
        XCTAssertTrue(onB, "same key on the far side of the boundary must verify")
        let onC = await gateC.isPermitValid(permit, for: intent)
        XCTAssertFalse(onC, "a gate with a different key must refuse the permit")
    }

    /// Freshly minted permit verifies on its own gate (happy path stays green).
    func testMintedPermitVerifies() async throws {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let intent = makeIntent()
        let permit = try await gate.requestActionPermit(for: intent)
        XCTAssertFalse(permit.signature.isEmpty, "mint must sign")
        let ok = await gate.isPermitValid(permit, for: intent)
        XCTAssertTrue(ok)
    }

    /// Injectivity guard: reason-code arity is folded into the tag, so shifting content
    /// between the reason list and adjacent fields cannot alias.
    func testReasonCodeArityIsBoundIntoTag() async throws {
        let key = SymmetricKey(data: Data("arity-key".utf8))
        let base = QinaoRiskGate.ActionPermit(
            permitID: "p", digest: "d", sessionID: "s", mode: .allow,
            reasonCodes: ["a", "b"], issuedAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 30), signature: "")
        let shifted = QinaoRiskGate.ActionPermit(
            permitID: "p", digest: "d", sessionID: "s", mode: .allow,
            reasonCodes: ["a"], issuedAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 30), signature: "")
        XCTAssertNotEqual(
            QinaoRiskGate.permitTag(key: key, base),
            QinaoRiskGate.permitTag(key: key, shifted))
    }
}
