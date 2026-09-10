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

/// M141 — L12 gentleHand auto-stream gated by BOTH
/// `thoughtFrame: BASThoughtFrame?` AND
/// `renderedOutput: BASRenderedOutput?`. Both must be non-nil.
///
/// Pins:
///   1. Neither → no L12
///   2. Only thoughtFrame → no L12 (half-supplied)
///   3. Only renderedOutput → no L12 (half-supplied)
///   4. BOTH → L12 present
final class QinaoRuntimeL12AutoStreamTests: XCTestCase {

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
            hostID: "host.m141",
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
            sessionID: "sess.m141",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeTF() -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m141",
            stabilityScore: 0.7)
    }

    private func makeRO() -> BASRenderedOutput {
        BASRenderedOutput(
            mode: .answer,
            headline: "Response",
            body: "Hello.",
            alternativeActions: [],
            explanationCodes: [])
    }

    func testNeitherSkipsL12() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.none")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.gentleHand))
    }

    func testOnlyThoughtFrameSkipsL12() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.tf-only")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.gentleHand),
            "half-supplied params don't stream L12")
    }

    func testOnlyRenderedOutputSkipsL12() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.ro-only")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            renderedOutput: makeRO())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.gentleHand),
            "half-supplied params don't stream L12")
    }

    func testBothStreamsL12() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.both")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF(),
            renderedOutput: makeRO())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.gentleHand))
        // Also confirms L4/L10/L11 still stream (thoughtFrame
        // drives four layers now).
        XCTAssertTrue(layers.contains(.worldPrior))
        XCTAssertTrue(layers.contains(.triSelfTribunal))
        XCTAssertTrue(layers.contains(.riskClimate))
    }
}
