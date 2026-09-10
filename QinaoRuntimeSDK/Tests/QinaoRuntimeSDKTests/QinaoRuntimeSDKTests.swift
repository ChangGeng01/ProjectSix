import XCTest
@testable import QinaoRuntime
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop
@testable import QinaoMemory
@testable import QinaoUI

/// Scaffold-level sanity tests. The M7.2+ milestones will add
/// per-façade integration tests against the real BAS substrate.
final class QinaoRuntimeSDKTests: XCTestCase {

    func testUIComponentIDsAreStable() {
        XCTAssertEqual(
            QinaoUI.ComponentID.comparePanel.rawValue, "compare-panel")
        XCTAssertEqual(
            QinaoUI.ComponentID.draftShell.rawValue, "draft-shell")
        XCTAssertEqual(
            QinaoUI.ComponentID.delayPacket.rawValue, "delay-packet")
        XCTAssertEqual(
            QinaoUI.ComponentID.boundaryScript.rawValue, "boundary-script")
        XCTAssertEqual(
            QinaoUI.ComponentID.silentStub.rawValue, "silent-stub")
    }

    func testRiskGateIssuesLivePermitByDefault() async throws {
        let gate = QinaoRiskGate(permitTTLSeconds: 10)
        let intent = QinaoRiskGate.ActionIntent(
            digest: "intent.abc",
            toolName: "calendar.add_event",
            sessionID: "sess.1",
            hostVersionID: "host.v1",
            summary: "add an event")
        let permit = try await gate.requestActionPermit(for: intent)
        XCTAssertEqual(permit.digest, intent.digest)
        XCTAssertEqual(permit.sessionID, intent.sessionID)
        XCTAssertEqual(permit.mode, .allow)
        let valid = await gate.isPermitValid(permit, for: intent)
        XCTAssertTrue(valid)
    }

    func testMemoryEmptyRecallReturnsEmpty() async throws {
        let memory = QinaoMemory()
        let results = await memory.recall()
        XCTAssertTrue(results.isEmpty)
        let count = await memory.count()
        XCTAssertEqual(count, 0)
    }

    func testLoopRejectsUnknownSession() async throws {
        // Post-M7.5 contract: an unsubmitted session must throw a
        // typed `sessionUnknown` error, not silently return empty.
        // Silent empty would let callers mistake "never submitted"
        // for "submitted but nothing ranked" — two very different
        // states in the dream-loop / tribunal pipeline.
        let loop = QinaoLoop()
        do {
            _ = try await loop.candidateFrontier(sessionID: "s1")
            XCTFail("unknown session must throw sessionUnknown")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "s1")
        }
    }

    /// `QinaoSovereignControlPlane.bootstrap(configuration:)` is the
    /// only public way to construct a control plane — the BAS-typed
    /// init is `internal` so the verdict machinery (TokenAuthority,
    /// AuditLedger, etc.) never surfaces in the public API. This test
    /// exercises the bootstrap path end-to-end: Configuration goes
    /// in, a functional control plane comes out.
    func testSovereignBootstrapProducesFunctionalControlPlane()
        async throws
    {
        let secret = Data(repeating: 0xA3, count: 32)
        let config = QinaoSovereignControlPlane.Configuration(
            warrantTTLSeconds: 60,
            ledgerSigningSecret: secret)
        let (sovereign, _) =
            QinaoSovereignControlPlane.bootstrap(configuration: config)

        // Can issue a warrant for an intent and verify it — without
        // ever importing BASSovereign at the call site.
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "d1", sessionID: "s1", hostVersionID: "host.v1")
        let warrant = try await sovereign.issueWarrant(for: intent)
        let ok = await sovereign.isWarrantValid(warrant, for: intent)
        XCTAssertTrue(ok)
    }
}
