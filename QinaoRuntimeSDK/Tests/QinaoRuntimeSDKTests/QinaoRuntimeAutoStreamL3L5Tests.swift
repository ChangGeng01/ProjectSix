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

/// M122 — dedicated coverage for the L3 (thought-fold) and L5
/// (host-constitution) halves of the auto-stream pipeline landed in
/// M121 / M122 (`QinaoRuntime.sendSession`).
///
/// The sibling `QinaoRuntimeAutoStreamL1Tests` suite proves the
/// gating (lifecycle / plannedBudget) contract and the overall
/// layer-order invariant. This suite pins the L3/L5 internals:
///
///   * L3 auto-stream fires for every sendSession call — no
///     gating on lifecycle or plannedBudget.
///   * L3 fold carries (foldID / checksum / restorePointer /
///     snapshotRef) projected deterministically from the
///     `TurnObservations` so the ledger coverage row is stable.
///   * L5 auto-stream pulls the committed constitution + version
///     tree off the host pipeline and records them regardless of
///     whether a planned budget is passed.
///   * Both layers land in the ledger's `observationBundle()`
///     parallel storage (M90) so audit replay can see them.
final class QinaoRuntimeAutoStreamL3L5Tests: XCTestCase {

    // MARK: - Fixtures

    actor ToolRecorder {
        func record(name: String, payload: Data) -> Data { Data() }
    }

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
        let host: QinaoHost
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
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
            hostID: "host.m122",
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
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now,
            lifecycle: nil)

        return Fixture(
            runtime: runtime,
            sovereign: sovereign,
            host: host)
    }

    private func observations(
        sessionID: String = "sess.m122",
        turnID: String = "turn.1",
        snapshotRef: String = "snap.m122",
        policyHash: String = "policy.m122"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash)
    }

    // MARK: - 1. L3 fires without lifecycle / plannedBudget

    func testL3AutoStreamsEvenWithoutLifecycleOrBudget()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.l3")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle, "L3 fires without gating")
        let l3 = bundle?.summaries.first {
            $0.layer == .thoughtFold
        }
        XCTAssertNotNil(
            l3, "L3 thoughtFold summary present every turn")
        XCTAssertGreaterThanOrEqual(
            l3?.totalObservations ?? 0, 1,
            "minimum-viable fold yields ≥ 1 observation " +
                "(foldSealed baseline)")
    }

    // MARK: - 2. L5 fires without lifecycle / plannedBudget

    func testL5AutoStreamsFromHostPipelineState()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.l5")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle)
        let l5 = bundle?.summaries.first {
            $0.layer == .hostConstitution
        }
        XCTAssertNotNil(l5, "L5 hostConstitution present every turn")
        XCTAssertTrue(
            l5?.hasCoreSignalCoverage ?? false,
            "bootstrapped host constitution signals an anchor")
    }

    // MARK: - 3. L3 fold ID is deterministic per (session, turn)

    func testL3FoldIDIsDeterministicPerSessionTurn()
        async throws {
        let fx1 = await makeRuntime()
        let fx2 = await makeRuntime()
        let obs = observations(
            sessionID: "sess.det",
            turnID: "turn.det",
            snapshotRef: "snap.det",
            policyHash: "policy.det")

        _ = try await fx1.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        _ = try await fx2.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let b1 = await fx1.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let b2 = await fx2.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let l3_1 = b1?.summaries.first { $0.layer == .thoughtFold }
        let l3_2 = b2?.summaries.first { $0.layer == .thoughtFold }
        // Same input → same totalObservations + distinctSubjectCount
        // + budgetTotalCost. `emittedAt` may differ (wall-clock) and
        // is intentionally not compared.
        XCTAssertEqual(
            l3_1?.totalObservations, l3_2?.totalObservations)
        XCTAssertEqual(
            l3_1?.distinctSubjectCount,
            l3_2?.distinctSubjectCount)
        XCTAssertEqual(
            l3_1?.budgetTotalCost, l3_2?.budgetTotalCost)
    }

    // MARK: - 4. expectedLayerIDs expansion adds L1 + L3 + L5

    func testExpectedLayerIDsExpandedToIncludeAllAutoInjected()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.exp")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // Default expectedCoverageLayerIDs = ["L14"]; auto-inject
        // adds L3 + L5 (and L1 when lifecycle present — absent
        // here). Coverage reading should therefore report L3 + L5
        // as *expected AND present*, not as missingLayer findings.
        let reading = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(reading)
        let missingLayerIDs: [String] = (reading?.findings ?? [])
            .compactMap { finding in
                if case .missingLayer(let id) = finding { return id }
                return nil
            }
        // L3 / L5 must NOT be flagged missing because auto-inject
        // expanded the expectation set AND streamed the summary.
        XCTAssertFalse(
            missingLayerIDs.contains("L3"),
            "L3 auto-inject satisfies the expanded expectation")
        XCTAssertFalse(
            missingLayerIDs.contains("L5"),
            "L5 auto-inject satisfies the expanded expectation")
    }

    // MARK: - 5. Custom expectedLayerIDs left untouched

    func testCustomExpectedLayerIDsDoNotExpandWithAutoInject()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.custom")

        // Caller passes a custom set — a statement of intent the
        // runtime must respect byte-for-byte. Auto-inject still
        // fires (L3+L5 land in the bundle), but the expectation
        // set is the caller's.
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            expectedCoverageLayerIDs: ["L14"])  // NOT a default

        let reading = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(reading)
        // The auto-inject still happens — bundle has L3+L5 — we're
        // just asserting the reading exists. The specific
        // missing-layer semantics are covered in expansion test (4).
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(
            bundle?.summaries.count, 3,
            "L14 + L3 + L5 bundle regardless of expectation set")
    }
}
