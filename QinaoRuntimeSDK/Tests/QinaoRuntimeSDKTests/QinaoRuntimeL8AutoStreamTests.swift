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

/// M136 — L8 hippocampalWell auto-stream on sendSession, gated
/// by optional `memoryBundle: BASMemoryBundle?`.
///
/// Pins:
///   1. No memoryBundle → no L8 in bundle
///   2. memoryBundle passed → L8 present in bundle
///   3. Empty atoms memoryBundle still produces a non-nil L8
///      coverage summary (with hasBundleRetrieval=false)
final class QinaoRuntimeL8AutoStreamTests: XCTestCase {

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
        actor ToolRecorder {
            func record(name: String, payload: Data) -> Data {
                Data()
            }
        }
        let recorder = ToolRecorder()
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now)
        let risk = QinaoRiskGate(permitTTLSeconds: 10, now: now)
        let constitution = BASHostConstitution(
            hostID: "host.m136",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        let host = QinaoHost(pipeline: pipeline)
        let memory = QinaoMemory()
        let loop = QinaoLoop()

        let executor: QinaoRuntime.ToolExecutor = { name, payload in
            await recorder.record(name: name, payload: payload)
        }
        let runtime = QinaoRuntime(
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: executor, now: now, lifecycle: nil)
        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m136",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    func testNoMemoryBundleSkipsL8() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.hippocampalWell),
            "no memoryBundle → no L8")
    }

    func testMemoryBundlePassedStreamsL8() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.with")
        let mb = BASMemoryBundle(atoms: [])
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            memoryBundle: mb)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.hippocampalWell),
            "memoryBundle passed → L8 in bundle")
    }

    func testEmptyMemoryBundleStillProducesL8Summary()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.empty")
        let emptyBundle = BASMemoryBundle(atoms: [])
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            memoryBundle: emptyBundle)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let l8 = bundle?.summaries.first {
            $0.layer == .hippocampalWell
        }
        XCTAssertNotNil(
            l8,
            "empty bundle still produces L8 summary")
        // Note: `hasCoreSignalCoverage` semantics for L8 is
        // "a bundle-level retrieval event was observed" — true
        // whenever derive ran with a non-nil memory bundle, even
        // if atoms is empty. Empty vs populated memory is
        // distinguishable via `totalObservations` / `distinctSubjectCount`.
    }
}
