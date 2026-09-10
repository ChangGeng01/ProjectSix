import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M145 — `TurnOutcome.surfaceDecision` is now non-optional.
///
/// Closes self-critique #3: the field was optional only because
/// I was hedging against a hypothetical future code path that
/// bypassed the derivation. But every production return path in
/// sendSession populates it (pinned across M125/M126/M131), so
/// the option wrapper was dead weight — it forced callers to
/// unwrap a value that can never be nil in production.
///
/// M145 tightens the type: field is `BASSurfaceDecision` (no `?`).
/// Pre-M145 `outcome.surfaceDecision` sites that used
/// `if let d = outcome.surfaceDecision` or
/// `try XCTUnwrap(outcome.surfaceDecision)` still work (the
/// let-binding simplifies to direct assignment; XCTUnwrap on a
/// non-optional returns the value unchanged). Pre-M145 sites that
/// constructed TurnOutcome directly without surfaceDecision now
/// get a compile error until they migrate — that's the
/// intentional API-break signal.
///
/// Pins:
///   1. Healthy turn outcome's surfaceDecision is directly
///      accessible without unwrap.
///   2. Auto-halt turn outcome (rollback/deadStop) also populates
///      surfaceDecision directly.
///   3. Direct construction requires surfaceDecision argument.
final class QinaoRuntimeM145NonOptionalDecisionTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture.


    // MARK: - 1. Healthy return path — direct access

    func testHealthyOutcomeHasDirectSurfaceDecision()
        async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m145")
        let obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m145",
            turnID: "turn.healthy",
            snapshotRef: "s",
            policyHash: "p")
        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // M145 — no ?. needed; compile-time proof the field is
        // non-optional. For .pass severity the derivation ships
        // draftShell.
        XCTAssertEqual(
            outcome.surfaceDecision.surface, .draftShell)
        XCTAssertEqual(
            outcome.surfaceDecision.agency, .userAffirm)
        XCTAssertEqual(
            outcome.surfaceDecision.auditReference,
            outcome.audit.auditRef)
    }

    // MARK: - 2. Direct construction enforces surfaceDecision

    func testDirectConstructionRequiresSurfaceDecision() {
        // Produce a valid synthetic decision for a halt branch.
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .rollback,
            coverageSeverity: .clean,
            auditRef: "audit.halt.m145")
        let outcome = QinaoRuntime.TurnOutcome(
            audit: QinaoSovereignControlPlane.AuditReport(
                sessionID: "sess.m145",
                turnID: "turn.halt",
                severity: .rollback,
                coordinatorSeverity: .pass,
                parity: .match,
                reasonCodes: [],
                auditRef: "audit.halt.m145"),
            coverage: QinaoSovereignControlPlane.CoverageReading(
                sessionID: "sess.m145",
                turnID: "turn.halt",
                severity: .clean,
                findings: [],
                emittedAt: Date()),
            sessionHalted: true,
            surfaceDecision: decision)
        XCTAssertEqual(
            outcome.surfaceDecision.surface, .boundaryScript,
            ".rollback severity → boundary-script")
    }

    // MARK: - 3. No-unwrap compile-time pin

    /// This test would have failed to compile pre-M145 (the
    /// `let d:` binding would need `?`). Post-M145 the type of
    /// `outcome.surfaceDecision` is `BASSurfaceDecision`, not
    /// `BASSurfaceDecision?` — compile-time proof of the API
    /// tightening.
    func testSurfaceDecisionTypeIsNonOptional() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m145")
        let obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m145",
            turnID: "turn.type",
            snapshotRef: "s",
            policyHash: "p")
        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let d: BASSurfaceDecision = outcome.surfaceDecision
        XCTAssertEqual(d.surface, .draftShell)
    }
}
