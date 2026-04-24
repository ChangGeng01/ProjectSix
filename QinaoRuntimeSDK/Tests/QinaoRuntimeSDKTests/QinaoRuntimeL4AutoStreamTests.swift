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

/// M139 — L4 worldPrior auto-stream, piggybacked on the same
/// `thoughtFrame: BASThoughtFrame?` parameter that M137 introduced
/// for L10 + L11. Zero new API surface.
///
/// Pins:
///   1. No thoughtFrame → no L4 in bundle (same gating as L10+L11)
///   2. thoughtFrame passed → L4 present alongside L10+L11
///   3. Default expected-layer set expands to include L4, L10, L11
final class QinaoRuntimeL4AutoStreamTests: XCTestCase {

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
            hostID: "host.m139",
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
            sessionID: "sess.m139",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeTF() -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m139",
            stabilityScore: 0.7)
    }

    func testNoThoughtFrameSkipsL4() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.worldPrior))
    }

    func testThoughtFramePassedStreamsL4() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.with")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.worldPrior),
            "thoughtFrame passed → L4 in bundle")
        // Piggyback evidence: L10 + L11 also present.
        XCTAssertTrue(layers.contains(.triSelfTribunal))
        XCTAssertTrue(layers.contains(.riskClimate))
    }

    func testDefaultExpectedExpandsForL4L10L11() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.exp")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF())
        let reading = await fx.sovereign.coverageReading(
            sessionID: o.sessionID, turnID: o.turnID)
        let missing: [String] =
            (reading?.findings ?? [])
            .compactMap { f in
                if case .missingLayer(let id) = f { return id }
                return nil
            }
        XCTAssertFalse(missing.contains("L4"))
        XCTAssertFalse(missing.contains("L10"))
        XCTAssertFalse(missing.contains("L11"))
    }
}
