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

/// M123 — 骨架: `BASSovereignFrame` per-turn aggregation wired into
/// the ledger's parallel `sovereignFrames[]` storage.
///
/// M121/M122 landed the blood (L1+L3+L5 observation bundle summaries
/// streamed via `observationBundles[]`). M123 lands the skeleton —
/// the L14 whitepaper §5.1 aggregator that binds session/turn IDs,
/// device/host/continuity/fold refs + policy hash + future
/// permit/jurisdiction/time-lock/contamination refs into a single
/// per-turn value the ledger indexes alongside the chain entry and
/// the observation bundle.
///
/// Pins:
///   1. Every healthy `sendSession` call records one frame.
///   2. The frame's `frameID` is deterministic per (session, turn).
///   3. Fields derived from TurnObservations (continuityRef,
///      policyHash, thoughtFoldRef, hostVersionRef) match their
///      source values byte-for-byte.
///   4. Frame replaces in place on re-emit (last-write-wins).
///   5. deviceStateRef is non-nil when lifecycle+plannedBudget
///      present, nil otherwise.
final class QinaoRuntimeSovereignFrameTests: XCTestCase {

    // MARK: - Fixtures (parallel to AutoStream test suites)

    actor ToolRecorder {
        func record(name: String, payload: Data) -> Data { Data() }
    }

    final class ThermalSource: @unchecked Sendable {
        private let lock = NSLock()
        private var _state: BASThermalTwin.OSThermalState = .nominal
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }; return _state
        }
    }

    actor NoopSubmitter {
        func record(identifier: String, date: Date) -> Bool { true }
    }

    actor NoopCanceller {
        func record(_ identifier: String) {}
    }

    // M155 — migrated to shared QinaoTestFixture.


    private func observations(
        sessionID: String = "sess.m123",
        turnID: String = "turn.1",
        snapshotRef: String = "snap.m123",
        policyHash: String = "policy.m123"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash)
    }

    // MARK: - 1. Every healthy sendSession records a frame

    func testHealthyTurnRecordsSovereignFrame() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: false)
        let obs = observations(turnID: "turn.record")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let frame = await fx.sovereign.sovereignFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(
            frame,
            "sovereignFrame must be recorded for healthy turn")
    }

    // MARK: - 2. frameID deterministic per (session, turn)

    func testFrameIDIsDeterministicPerSessionTurn() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: false)
        let obs = observations(
            sessionID: "sess.det",
            turnID: "turn.det")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let frame = await fx.sovereign.sovereignFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(
            frame?.frameID,
            "frame.sess.det.turn.det",
            "frameID = 'frame.<sessionID>.<turnID>' deterministic")
    }

    // MARK: - 3. Source fields byte-equal their TurnObservations
    //         inputs (policyHash / continuityRef / hostVersionRef /
    //         thoughtFoldRef)

    func testFrameCarriesTurnObservationsVerbatim() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: false)
        let obs = observations(
            sessionID: "sess.verbatim",
            turnID: "turn.verbatim",
            snapshotRef: "snap.abc",
            policyHash: "policy.xyz")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let frame = await fx.sovereign.sovereignFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(
            frame?.policyHash, "policy.xyz",
            "policyHash byte-equal")
        XCTAssertEqual(
            frame?.continuityRef, "snap.abc",
            "continuityRef = observations.snapshotRef")
        XCTAssertEqual(
            frame?.hostVersionRef, "host.v1",
            "hostVersionRef = L5 constitution.activeVersion")
        XCTAssertEqual(
            frame?.thoughtFoldRef,
            "fold.sess.verbatim.turn.verbatim",
            "thoughtFoldRef = L3 fold's deterministic foldID")
    }

    // MARK: - 4. Re-emit replaces in place (LWW)

    func testReEmitReplacesFrameInPlace() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: false)
        let obs = observations(turnID: "turn.rewrite")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let firstCount = await fx.sovereign.sovereignFrameCount()

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let secondCount = await fx.sovereign.sovereignFrameCount()

        XCTAssertEqual(
            firstCount, secondCount,
            "re-emit must replace in place — no accretion")
        XCTAssertEqual(
            firstCount, 1,
            "one frame per (sess, turn)")
    }

    // MARK: - 5. deviceStateRef populated iff lifecycle+plannedBudget

    func testDeviceStateRefReflectsLifecycleAndBudget() async throws {
        // With lifecycle + plannedBudget → deviceStateRef =
        // routed budget's leaseID.
        let fx1 = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: true)
        let obs1 = observations(turnID: "turn.with")
        let plannedBudget = BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 3,
            maxDecodeTokens: 512,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false,
            leaseID: "lease.m123",
            leaseExpiresAt: Date().addingTimeInterval(60),
            maintenanceClass: .light,
            wakeIntentID: "wake.m123",
            allowedHeads: ["answer"],
            policyBundleVersion: "pb.v1",
            policyDecisionIDs: [])
        _ = try await fx1.runtime.sendSession(
            obs1,
            coordinatorSeverity: .pass,
            plannedBudget: plannedBudget)
        let frame1 = await fx1.sovereign.sovereignFrame(
            sessionID: obs1.sessionID, turnID: obs1.turnID)
        XCTAssertEqual(
            frame1?.deviceStateRef, "lease.m123",
            "deviceStateRef = routed budget leaseID when present")

        // Without lifecycle → routedBudget is nil → deviceStateRef nil.
        let fx2 = await QinaoTestFixture.make(hostID: "host.m123", withLifecycle: false)
        let obs2 = observations(turnID: "turn.without")
        _ = try await fx2.runtime.sendSession(
            obs2, coordinatorSeverity: .pass)
        let frame2 = await fx2.sovereign.sovereignFrame(
            sessionID: obs2.sessionID, turnID: obs2.turnID)
        XCTAssertNil(
            frame2?.deviceStateRef,
            "deviceStateRef nil without routed budget")
    }
}
