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

/// M135 — L7 mirrorBlade auto-stream on sendSession, gated by
/// optional `decomposeFrame: BASDecomposeFrame?` parameter.
/// Same opt-in pattern as M134 L6 (contextFrame).
///
/// Pins:
///   1. No decomposeFrame → no L7 in bundle
///   2. decomposeFrame passed → L7 present in bundle
///   3. Default expectedCoverageLayerIDs expands to include L7
final class QinaoRuntimeL7AutoStreamTests: XCTestCase {

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
            hostID: "host.m135",
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
            sessionID: "sess.m135",
            turnID: turnID,
            snapshotRef: "snap",
            policyHash: "policy")
    }

    private func makeDecomposeFrame() -> BASDecomposeFrame {
        BASDecomposeFrame(
            facts: ["sky is blue"],
            goals: ["explain color"],
            emotions: ["curious"],
            unknowns: ["why blue not green"],
            contradictions: [],
            mirrorText: "You are asking about color perception.")
    }

    func testNoDecomposeFrameSkipsL7() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.mirrorBlade),
            "no decomposeFrame → no L7 in bundle")
    }

    func testDecomposeFramePassedStreamsL7() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.with")
        let df = makeDecomposeFrame()
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            decomposeFrame: df)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.mirrorBlade),
            "decomposeFrame passed → L7 in bundle")
    }

    func testDefaultExpectedLayersExpandsToIncludeL7()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.expand")
        let df = makeDecomposeFrame()
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            decomposeFrame: df)
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
        XCTAssertFalse(
            missingLayerIDs.contains("L7"),
            "L7 auto-inject satisfies expanded expectation")
    }

    func testBothL6AndL7StreamedTogether() async throws {
        // Pin that L6 + L7 can coexist in one sendSession call.
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.combined")
        let ctx = BASContextFrame(
            utterance: "hi",
            taskType: .chat,
            emotionalLoad: 0.2,
            timePressure: 0.1,
            relationPattern: "test",
            ambiguityScore: 0.1,
            consequenceLevel: 0.1,
            hostRelevance: 0.5)
        let df = makeDecomposeFrame()
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            contextFrame: ctx,
            decomposeFrame: df)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.presenceEye))
        XCTAssertTrue(layers.contains(.mirrorBlade))
        // Plus L14 (always), L3 + L5 (unconditional auto-inject).
        XCTAssertTrue(layers.contains(.sovereign))
        XCTAssertTrue(layers.contains(.thoughtFold))
        XCTAssertTrue(layers.contains(.hostConstitution))
    }
}
