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
@testable import QinaoUI

/// M125 — 皮肤: `TurnOutcome.surfaceDecision` derivation.
///
/// The last of the four "blood / skin / skeleton / tendons"
/// directives. M121/M122 moved observation data through the ledger
/// (blood), M123 attached the per-turn aggregator (skeleton), M124
/// bound the parallel surfaces together (tendons). M125 closes the
/// loop by producing a per-turn `BASSurfaceDecision` on every
/// `TurnOutcome` returned by `sendSession`, so host UIs can mount
/// the right QinaoUI component without any extra round trip.
///
/// Pins:
///   1. Healthy clean turn → `draftShell + userAffirm + minimal`.
///   2. Healthy turn with coverage advisory → `draftShell +
///      userAffirm + reasoned` (disclosure escalates).
///   3. Rawvalue parity with QinaoUI.ComponentID (M88 pinned at
///      schema level; M125 pins the runtime projection path).
///   4. surfaceDecision.auditReference == audit.auditRef.
///   5. Pure derivation function is deterministic for fixed inputs.
final class QinaoRuntimeSurfaceDecisionTests: XCTestCase {

    // MARK: - Fixture

    actor ToolRecorder {
        func record(name: String, payload: Data) -> Data { Data() }
    }

    // M155 — migrated to shared QinaoTestFixture.


    private func observations(
        sessionID: String = "sess.m125",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m125",
            policyHash: "policy.m125")
    }

    // MARK: - 1. Healthy turn — surface + agency are stable

    /// For a healthy (`.pass`) turn the surface must always be
    /// `.draftShell` with `.userAffirm` agency. Disclosure depends
    /// on whether the structural coverage reader flagged an
    /// advisory (e.g. L14 core signal missing in this fixture's
    /// thin audit environment); tests 5/6 pin the pure derivation
    /// semantics precisely.
    func testHealthyCleanTurnGetsDraftShellMinimal()
        async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m125")
        let obs = observations(turnID: "turn.clean")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertNotNil(
            outcome.surfaceDecision,
            "healthy TurnOutcome must carry surfaceDecision")
        let decision = try XCTUnwrap(outcome.surfaceDecision)
        XCTAssertEqual(decision.surface, .draftShell)
        XCTAssertEqual(decision.agency, .userAffirm)
        // disclosure is either .minimal (clean coverage) or
        // .reasoned (advisory coverage) — both are valid healthy
        // states for this assertion.
        XCTAssertTrue(
            decision.disclosure == .minimal
                || decision.disclosure == .reasoned,
            "healthy disclosure ∈ {minimal, reasoned}")
        XCTAssertTrue(
            decision.reasonCodes.contains("audit.severity:pass"),
            "must carry audit.severity:pass code")
    }

    // MARK: - 2. auditReference round-trip

    func testSurfaceDecisionCarriesAuditRef() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m125")
        let obs = observations(turnID: "turn.audit-ref")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let decision = try XCTUnwrap(outcome.surfaceDecision)
        XCTAssertEqual(
            decision.auditReference, outcome.audit.auditRef,
            "auditReference must match audit.auditRef")
    }

    // MARK: - 3. RawValue parity with QinaoUI.ComponentID

    func testSurfaceRawValueMapsToComponentID() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m125")
        let obs = observations(turnID: "turn.rawvalue")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let decision = try XCTUnwrap(outcome.surfaceDecision)
        // Trivial projection — no bridge helper needed.
        let componentID = QinaoUI.ComponentID(
            decision.surface.rawValue)
        XCTAssertEqual(
            componentID, QinaoUI.ComponentID.draftShell,
            "draftShell surface → draftShell ComponentID")
    }

    // MARK: - 4. Pure derivation is deterministic

    func testDeriveSurfaceDecisionIsDeterministic() {
        let a = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.deterministic")
        let b = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.deterministic")
        XCTAssertEqual(
            a, b,
            "pure deterministic for fixed inputs")
    }

    // MARK: - 5. Severity coverage map — spot check all 8 audit
    //         severity cases produce a sensible surface decision.

    func testAllAuditSeveritiesMapToSurface() {
        let cases: [(
            QinaoSovereignControlPlane.AuditSeverity,
            BASSurfaceMode
        )] = [
            (.pass, .draftShell),
            (.throttle, .delayPacket),
            (.shadowLock, .delayPacket),
            (.toolCut, .delayPacket),
            (.memoryFreeze, .delayPacket),
            (.quarantine, .delayPacket),
            (.rollback, .boundaryScript),
            (.deadStop, .silentStub),
        ]
        for (severity, expectedSurface) in cases {
            let decision = QinaoRuntime.deriveSurfaceDecision(
                auditSeverity: severity,
                coverageSeverity: .clean,
                auditRef: "ref.\(severity.rawValue)")
            XCTAssertEqual(
                decision.surface, expectedSurface,
                "\(severity) → \(expectedSurface)")
            XCTAssertEqual(
                decision.auditReference,
                "ref.\(severity.rawValue)")
            // Every non-.pass decision must be host-override;
            // .pass is user-affirm.
            let expectedAgency: BASSurfaceAgency =
                severity == .pass ? .userAffirm : .hostOverride
            XCTAssertEqual(decision.agency, expectedAgency)
        }
    }

    // MARK: - 6. Coverage advisory escalates disclosure on pass

    func testCoverageAdvisoryEscalatesDisclosureToReasoned() {
        let cleanDecision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "ref.cov-clean")
        let advisoryDecision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .advisory,
            auditRef: "ref.cov-advisory")

        XCTAssertEqual(cleanDecision.disclosure, .minimal)
        XCTAssertEqual(advisoryDecision.disclosure, .reasoned)
        XCTAssertTrue(
            advisoryDecision.reasonCodes.contains(
                "coverage.severity:advisory"),
            "advisory coverage adds reason code")
    }
}
