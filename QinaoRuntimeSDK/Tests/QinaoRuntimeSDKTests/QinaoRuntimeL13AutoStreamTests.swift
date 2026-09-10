import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASObservability
import BASPolicy
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M138 — L13 evolutionFurnace shadow-trial stream.
///
/// Whitepaper invariant #3 — "宿主私有经验不进权重" — forbids any
/// automatic path from an `UpdateTicket` to a real commit that
/// would touch neural weights / memory state / host constitution.
/// M138 ships the L13 per-turn observation stream, which records
/// PROPOSED changes in the L14 audit ledger as shadow-trial
/// evidence. The commit path stays entirely host-approved.
///
/// Pins:
///   1. Empty tickets list → no L13 in bundle (backward-compat).
///   2. Non-empty tickets list → L13 present.
///   3. Shadow-only: streaming a ticket does NOT mutate host
///      constitution (activeVersion stays unchanged) — invariant
///      #3 hard-pinned at the test layer.
///   4. Default expected-layer set expands to include L13.
final class QinaoRuntimeL13AutoStreamTests: XCTestCase {

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
        let host: QinaoHost
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
            hostID: "host.m138",
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
        return Fixture(
            runtime: runtime, sovereign: sovereign, host: host)
    }

    private func observations(
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m138",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeTicket(
        id: String = "ticket.m138.1"
    ) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess.m138",
            summary: "shadow-trial: user hinted a preference",
            memoryWriteSuggestion: "prefers terse responses",
            confidence: 0.7)
    }

    func testEmptyTicketsListSkipsL13() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.empty")
        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(
            layers.contains(.evolutionFurnace),
            "empty tickets → no L13")
    }

    func testTicketsPassedStreamsL13() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.with")
        let tickets = [
            makeTicket(id: "ticket.a"),
            makeTicket(id: "ticket.b"),
        ]
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            updateTickets: tickets)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertTrue(
            layers.contains(.evolutionFurnace),
            "tickets passed → L13 in bundle")
    }

    /// Invariant #3 HARD PIN: shadow-stream does NOT touch host
    /// constitution. Before + after sendSession, the active
    /// version on the host must be unchanged — the ticket was
    /// recorded but not committed.
    func testShadowStreamDoesNotMutateHostConstitution()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.invariant")

        let beforeVersion = await fx.host
            .currentConstitution().activeVersion
        let tickets = [
            makeTicket(id: "ticket.should-not-commit"),
        ]
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            updateTickets: tickets)
        let afterVersion = await fx.host
            .currentConstitution().activeVersion

        XCTAssertEqual(
            beforeVersion, afterVersion,
            "invariant #3: L13 shadow-stream must NOT commit" +
                " — activeVersion unchanged across sendSession")
    }

    func testDefaultExpectedLayersExpandsToIncludeL13()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.expand")
        let tickets = [makeTicket()]
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            updateTickets: tickets)
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
        XCTAssertFalse(missingLayerIDs.contains("L13"))
    }
}
