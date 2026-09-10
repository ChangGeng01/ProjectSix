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

/// M142 — L9 dreamLoop auto-stream. Closes the 14/14 layer auto-
/// stream matrix. Required a new BAS-side
/// `BASCandidateObservationBundle.derive(fromFrontier:...)` helper
/// landed alongside — the schema has existed since M24 but the
/// value-transform bridge from a frontier back to a bundle was
/// never written.
///
/// Pins:
///   1. No candidateFrontier → no L9 in bundle
///   2. candidateFrontier passed → L9 present
///   3. Derive produces at least the baseline diversity signal
///      even for an empty frontier (no crash, no nil bundle)
///   4. Default expected-layer set expands for L9
final class QinaoRuntimeL9AutoStreamTests: XCTestCase {

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
            hostID: "host.m142",
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
            sessionID: "sess.m142",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeFrontier() -> BASCandidateFrontier {
        BASCandidateFrontier(
            candidateIDs: ["cand.a", "cand.b", "cand.c"],
            dominanceOrder: ["cand.a", "cand.b", "cand.c"],
            reversiblePaths: ["cand.a"],
            guardPaths: ["cand.c"],
            frontierWidth: 3,
            diversityScore: 0.6,
            delayedPaths: [])
    }

    func testNoFrontierSkipsL9() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.dreamLoop))
    }

    func testFrontierPassedStreamsL9() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.with")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            candidateFrontier: makeFrontier())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(layers.contains(.dreamLoop))
    }

    /// BAS-side derive helper correctness: an empty frontier
    /// (no candidates, no ranks) still produces a bundle with the
    /// baseline `.diversitySignal` anchored on `frontier.<turnID>`.
    func testEmptyFrontierProducesBaselineDiversity() {
        let emptyFrontier = BASCandidateFrontier(
            candidateIDs: [],
            dominanceOrder: [],
            frontierWidth: 0,
            diversityScore: 0.0)
        let bundle = BASCandidateObservationBundle.derive(
            fromFrontier: emptyFrontier,
            turnID: "turn.empty",
            sessionID: "sess.m142",
            emittedAt: Date())
        XCTAssertEqual(
            bundle.observations.count, 1,
            "empty frontier → 1 baseline diversity signal")
        XCTAssertEqual(
            bundle.observations.first?.kind, .diversitySignal)
        XCTAssertEqual(
            bundle.observations.first?.candidateID,
            "frontier.turn.empty",
            "synthetic anchor when no candidates")
    }

    /// BAS-side derive helper correctness: rich frontier produces
    /// observations for every signal kind in the expected order.
    func testRichFrontierProducesAllSignalKinds() {
        let bundle = BASCandidateObservationBundle.derive(
            fromFrontier: makeFrontier(),
            turnID: "turn.rich",
            sessionID: "sess.m142",
            emittedAt: Date())
        // 3 candidates + 3 dominance + 1 reversible + 1 guard +
        // 1 diversity + 0 delayed = 9 observations.
        XCTAssertEqual(bundle.observations.count, 9)
        let kinds = Set(bundle.observations.map(\.kind))
        XCTAssertTrue(kinds.contains(.candidate))
        XCTAssertTrue(kinds.contains(.dominanceSignal))
        XCTAssertTrue(kinds.contains(.reversibilitySignal))
        XCTAssertTrue(kinds.contains(.guardianBranch))
        XCTAssertTrue(kinds.contains(.diversitySignal))
        XCTAssertFalse(kinds.contains(.delayRecommendation))
    }

    func testDefaultExpectedExpandsForL9() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.exp")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            candidateFrontier: makeFrontier())
        let reading = await fx.sovereign.coverageReading(
            sessionID: o.sessionID, turnID: o.turnID)
        let missing: [String] =
            (reading?.findings ?? [])
            .compactMap { f in
                if case .missingLayer(let id) = f { return id }
                return nil
            }
        XCTAssertFalse(missing.contains("L9"))
    }
}
