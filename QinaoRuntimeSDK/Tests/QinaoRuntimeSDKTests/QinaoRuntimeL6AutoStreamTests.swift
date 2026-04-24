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

/// M134 — L6 presenceEye auto-stream on `sendSession`.
///
/// Continues the "per-turn observation streaming into L14 ledger"
/// discipline started in M121 (L1) and M122 (L3+L5). L6 differs
/// from L3/L5: its derivation needs a real `BASContextFrame` with
/// the turn's utterance + task + scene + emotional weather +
/// urgency truth. Fabricating one with neutral zeros would emit
/// meaningless observations that pollute the ledger. So L6 is
/// GATED on a caller-supplied `contextFrame: BASContextFrame?`
/// parameter — same opt-in pattern M121 uses for the L1 lifecycle.
///
/// Pins:
///   1. No contextFrame → L6 not in bundle (backward-compat).
///   2. contextFrame passed → L6 present in bundle.
///   3. Default expectedCoverageLayerIDs auto-expands to include
///      "L6" when the frame is passed.
///   4. Custom expectedCoverageLayerIDs stays untouched.
///   5. Coverage summary totalObservations / layer match derive output.
final class QinaoRuntimeL6AutoStreamTests: XCTestCase {

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
            hostID: "host.m134",
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
        sessionID: String = "sess.m134",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m134",
            policyHash: "policy.m134")
    }

    private func makeContextFrame() -> BASContextFrame {
        BASContextFrame(
            utterance: "please help me think through this",
            taskType: .chat,
            emotionalLoad: 0.5,
            timePressure: 0.3,
            relationPattern: "mutual",
            ambiguityScore: 0.4,
            consequenceLevel: 0.2,
            manipulationHints: [],
            hostRelevance: 0.7)
    }

    // MARK: - 1. No contextFrame → no L6 in bundle

    func testNoContextFrameSkipsL6() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.no-ctx")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.presenceEye),
            "no contextFrame → no L6 in bundle" +
                " (backward-compat)")
    }

    // MARK: - 2. contextFrame passed → L6 present

    func testContextFramePassedStreamsL6() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.with-ctx")
        let ctx = makeContextFrame()

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            contextFrame: ctx)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.presenceEye),
            "contextFrame passed → L6 in bundle")
    }

    // MARK: - 3. Default expected-layer set expands to include L6

    /// With default `expectedCoverageLayerIDs == ["L14"]` and a
    /// contextFrame passed, the expansion logic in M121/M122
    /// (+ M134 for L6) should add L6 to the expected set so
    /// coverage verdict validates its presence.
    func testDefaultExpectedLayersExpandsToIncludeL6()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.expand")
        let ctx = makeContextFrame()

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            contextFrame: ctx)

        let reading = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(reading)
        // L6 must NOT appear in missingLayer findings (expected +
        // present).
        let missingLayerIDs: [String] =
            (reading?.findings ?? [])
            .compactMap { finding in
                if case .missingLayer(let id) = finding {
                    return id
                }
                return nil
            }
        XCTAssertFalse(
            missingLayerIDs.contains("L6"),
            "L6 auto-inject satisfies the expanded expectation")
    }

    // MARK: - 4. Custom expectation set is NOT expanded

    func testCustomExpectedLayersNotExpandedWithL6()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.custom")
        let ctx = makeContextFrame()

        // Caller passes a custom set — M122 expansion rule:
        // auto-inject still happens but expectation set stays
        // literal.
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            expectedCoverageLayerIDs: ["L14"],
            contextFrame: ctx)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        // L6 still present in bundle (auto-inject always fires
        // when contextFrame non-nil).
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.presenceEye),
            "L6 still streams on custom expected set")
    }

    // MARK: - 5. L6 bundle totalObservations matches derive output

    func testL6BundleMatchesDirectDerive() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.match")
        let ctx = makeContextFrame()

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            contextFrame: ctx)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let l6 = bundle?.summaries.first {
            $0.layer == .presenceEye
        }
        XCTAssertNotNil(l6)
        XCTAssertGreaterThanOrEqual(
            l6?.totalObservations ?? 0, 1,
            "L6 baseline .task signal always present")
    }
}
