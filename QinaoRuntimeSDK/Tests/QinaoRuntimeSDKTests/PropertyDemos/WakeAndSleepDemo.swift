import XCTest
import CryptoKit
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoSovereign
@testable import QinaoRisk

/// Property 1 · 会醒会停 — Wake and sleep.
///
/// **What this demo proves:** the runtime is not a pipe. It is a
/// gate that knows when the session is awake and when it is
/// halted — and it refuses to execute a tool in the halted state
/// even when every signature on the bundle is structurally
/// valid.
///
/// We walk three phases:
///
/// 1. **Wake** — sign a real intent, call `execute`, observe the
///    host-provided tool executor run.
/// 2. **Sleep** — plan a deadStop reboot via the control plane.
///    The session is now halted. A re-execute with the very same
///    signatures (which are still unexpired) is refused at the
///    gate with `RuntimeError.sessionHalted`.
/// 3. **Wake again** — clear the halt. The gate accepts tool
///    calls again.
///
/// No substrate type leaks into the demo — everything is done
/// through the public Qinao API (plus the test-only helper on
/// `PropertyDemoFixture` that wires the snapshot anchor the halt
/// planner needs).
final class WakeAndSleepDemo: XCTestCase {

    func testSessionWakesSleepsAndWakesAgain() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        try await PropertyDemoFixture.prepareHaltPlumbing(runtime: fx)
        // deep-audit P0-4: signBundle's proof binds "anchor-host.v1" — register it so the proof
        // verifies under the new registration check.
        _ = try? await fx.snapshotManager.register(
            anchor: BASSovereignSnapshotManager.SnapshotAnchor(
                anchorID: "anchor-host.v1", safeSnapshotRef: "snap.anchor-host.v1",
                integrityHash: SHA256.hash(data: Data("anchor-host.v1".utf8))
                    .map { String(format: "%02x", $0) }.joined()),
            sealedPayload: Data("anchor-host.v1".utf8))

        let intent = PropertyDemoFixture.intent(
            sessionID: "sess.wake-sleep")
        let signatures = try await PropertyDemoFixture.signBundle(
            for: intent, runtime: fx)

        // Phase 1 — wake. Tool executes, recorder sees one call.
        let result = try await fx.runtime.execute(
            toolName: intent.toolName,
            payload: Data("{}".utf8),
            intent: intent,
            signatures: signatures)
        XCTAssertEqual(result, Data("ok".utf8))
        var callCount = await fx.recorder.callCount
        XCTAssertEqual(callCount, 1)

        // Phase 2 — sleep. The control plane plans a deadStop
        // reboot; the session is marked halted until cleared.
        _ = try await fx.sovereign.haltSession(
            sessionID: intent.sessionID,
            fromVersionID: "host.v1")
        let isHalted = await fx.sovereign.isSessionHalted(intent.sessionID)
        XCTAssertTrue(isHalted)

        // Re-executing with the same (unexpired) signatures is
        // refused *at the gate* — the substrate tool executor is
        // never reached. callCount stays at 1.
        do {
            _ = try await fx.runtime.execute(
                toolName: intent.toolName,
                payload: Data("{}".utf8),
                intent: intent,
                signatures: signatures)
            XCTFail("expected sessionHalted refusal")
        } catch QinaoRuntime.RuntimeError.sessionHalted(let id) {
            XCTAssertEqual(id, intent.sessionID)
        }
        callCount = await fx.recorder.callCount
        XCTAssertEqual(callCount, 1)

        // Phase 3 — wake again. Clearing the halt re-opens the gate;
        // fresh signatures (the old warrant/permit may still be live
        // too) go through.
        await fx.sovereign.clearHalt(sessionID: intent.sessionID)
        let freshSignatures = try await PropertyDemoFixture.signBundle(
            for: intent, runtime: fx)
        _ = try await fx.runtime.execute(
            toolName: intent.toolName,
            payload: Data("{}".utf8),
            intent: intent,
            signatures: freshSignatures)
        callCount = await fx.recorder.callCount
        XCTAssertEqual(callCount, 2)
    }

    /// Symmetric proof: `issueWarrant` itself refuses to sign an
    /// intent while the session is halted — "sleep" reaches back
    /// to the signature issuance layer, not just the gate.
    func testHaltedSessionRefusesToIssueFreshWarrants() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        try await PropertyDemoFixture.prepareHaltPlumbing(runtime: fx)

        let intent = PropertyDemoFixture.intent(
            sessionID: "sess.sleep-refuse-signing")
        _ = try await fx.sovereign.haltSession(
            sessionID: intent.sessionID,
            fromVersionID: "host.v1")

        do {
            _ = try await fx.sovereign.issueWarrant(
                for: QinaoSovereignControlPlane.Intent(
                    digest: intent.digest,
                    sessionID: intent.sessionID,
                    hostVersionID: intent.hostVersionID))
            XCTFail("expected sessionHalted during issueWarrant")
        } catch QinaoSovereignControlPlane.SovereignError
            .sessionHalted(let sid)
        {
            XCTAssertEqual(sid, intent.sessionID)
        }
    }
}
