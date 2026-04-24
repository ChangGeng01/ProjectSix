import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASPolicy
import BASSovereign
import BASOrchestration
import BASWorldPrior
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M140 — L2 neuralOrgan auto-stream gated by
/// `neuralOrganMap: BASNeuralOrganMap?`. Same opt-in pattern
/// as L6/L7/L8.
///
/// Pins:
///   1. No neuralOrganMap → no L2 in bundle
///   2. neuralOrganMap passed → L2 present
///   3. Default expected-layer set expands for L2
final class QinaoRuntimeL2AutoStreamTests: XCTestCase {

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
            hostID: "host.m140",
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

    private func obs(
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m140",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeMap() -> BASNeuralOrganMap {
        BASNeuralOrganMap(
            morph: .engage,
            activeOrgans: [],
            routingPolicy: .conversationalBalance)
    }

    func testNoMapSkipsL2() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.neuralOrgan))
    }

    func testMapPassedStreamsL2() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.with")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            neuralOrganMap: makeMap())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(layers.contains(.neuralOrgan))
    }

    func testDefaultExpectedExpandsForL2() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.exp")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            neuralOrganMap: makeMap())
        let reading = await fx.sovereign.coverageReading(
            sessionID: o.sessionID, turnID: o.turnID)
        let missing: [String] =
            (reading?.findings ?? [])
            .compactMap { f in
                if case .missingLayer(let id) = f { return id }
                return nil
            }
        XCTAssertFalse(missing.contains("L2"))
    }
}
