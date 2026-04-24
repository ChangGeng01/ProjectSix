import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASPolicy
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M137 — L10 triSelfTribunal + L11 riskGate co-derived from a
/// single `BASThoughtFrame` parameter. Both layers' `.derive()`
/// take the same source type, so one caller-supplied frame
/// drives both layers in a single gated path.
///
/// Pins:
///   1. No thoughtFrame → neither L10 nor L11 in bundle
///   2. thoughtFrame passed → BOTH L10 and L11 in bundle
///   3. Default expected-layer set expands to include L10+L11
final class QinaoRuntimeL10L11AutoStreamTests: XCTestCase {

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
            hostID: "host.m137",
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
            sessionID: "sess.m137",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeThoughtFrame() -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m137",
            stabilityScore: 0.7)
    }

    func testNoThoughtFrameSkipsL10L11() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.triSelfTribunal))
        XCTAssertFalse(layers.contains(.riskClimate))
    }

    func testThoughtFramePassedStreamsBothL10AndL11()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.with")
        let tf = makeThoughtFrame()
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            thoughtFrame: tf)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(
            layers.contains(.triSelfTribunal),
            "thoughtFrame passed → L10 in bundle")
        XCTAssertTrue(
            layers.contains(.riskClimate),
            "thoughtFrame passed → L11 in bundle")
    }

    func testDefaultExpectedLayersExpandsForL10AndL11()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.expand")
        let tf = makeThoughtFrame()
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            thoughtFrame: tf)
        let reading = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(reading)
        let missingLayerIDs: [String] =
            (reading?.findings ?? [])
            .compactMap { f in
                if case .missingLayer(let id) = f {
                    return id
                }
                return nil
            }
        XCTAssertFalse(missingLayerIDs.contains("L10"))
        XCTAssertFalse(missingLayerIDs.contains("L11"))
    }
}
