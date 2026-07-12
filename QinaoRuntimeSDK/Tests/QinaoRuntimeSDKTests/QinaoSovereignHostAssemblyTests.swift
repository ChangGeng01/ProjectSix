import XCTest
import CryptoKit
import BASSovereign
@testable import QinaoDefaults
@testable import QinaoRuntime
@testable import QinaoMemory
@testable import QinaoSovereign
@testable import QinaoRisk
@testable import QinaoSeats
@testable import QinaoLoop

/// integration S2 (2026-07-12) — the LLM-free integrated sovereign host assembly.
///
/// Adoption proof for turn-path finding C + the convergence map: ONE path now composes
/// sovereign audit (A) + persistent keyed ledger (K) + memory (M) + the runtime tool
/// gate (T) — with the LLM outside the boundary (L stays data-only, by charter).
final class QinaoSovereignHostAssemblyTests: XCTestCase {

    private actor ToolLog {
        private(set) var calls: [String] = []
        func record(_ name: String) { calls.append(name) }
    }

    private func makeHost(
        ledgerPath: String? = nil,
        toolLog: ToolLog? = nil
    ) async throws -> QinaoSovereignHost {
        try await QinaoDefaults.makeSovereignHost(
            hostID: "host.assembly",
            activeVersion: "host.v1",
            ledgerSigningSecret: Data("assembly-secret".utf8),
            ledgerDatabasePath: ledgerPath,
            toolExecutor: { name, _ in
                await toolLog?.record(name)
                return Data("ok".utf8)
            },
            now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    // MARK: - Assembly completeness

    /// All 9 council seats are registered — "所有 Qinao 组成" means the full council.
    func testAssemblyRegistersFullCouncil() async throws {
        let host = try await makeHost()
        let registered = await host.seats.registeredSeats()
        XCTAssertEqual(Set(registered), Set(QinaoSeat.allCases),
            "the integrated host must seat the full 9-member council")
    }

    /// The boundary: the assembled loop has NO endpoint — generation gives the typed
    /// refusal, it does not silently pretend.
    func testLoopIsEndpointLessWithTypedRefusal() async throws {
        let host = try await makeHost()
        let stream = await host.loop.streamBody(
            sessionID: "s.boundary", prompt: "generate")
        do {
            for try await _ in stream {
                XCTFail("endpoint-less loop must refuse generation")
            }
            XCTFail("stream must terminate with the typed refusal")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "no-endpoint-configured")
        }
    }

    // MARK: - One turn engages A + M; the keyed ledger persists (K)

    /// A full sendSession turn on the assembled runtime: memory reaches L8 (M), the
    /// audit machinery runs (A), and the keyed ledger has PERSISTED rows on disk (K) —
    /// the L14 entry no longer dies unsigned in a result struct.
    func testOneTurnComposesAuditMemoryAndPersistentLedger() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-assembly-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let ledgerPath = dir.appendingPathComponent("sovereign-ledger.sqlite").path

        let host = try await makeHost(ledgerPath: ledgerPath)

        // M — admit a memory; S1 wiring must carry it into the turn's L8 layer.
        _ = try await host.memory.admit(QinaoMemory.AdmitRequest(
            kind: .semantic, content: "assembly adoption memory",
            scope: .session, sensitivity: .low, confidence: 0.9))

        var inputs = QinaoRuntime.TurnInputs(
            observations: QinaoSovereignControlPlane.TurnObservations(
                sessionID: "sess.assembly", turnID: "turn.1",
                snapshotRef: "snap.1", policyHash: "policy.1"),
            coordinatorSeverity: nil)
        inputs.expectedCoverageLayerIDs = ["L8", "L14"]

        let outcome = try await host.runtime.sendSession(inputs)

        // A — the audit ran and the turn is healthy.
        XCTAssertFalse(outcome.sessionHalted)
        // M — L8 emitted (no missing-layer finding), fed by the runtime's own memory.
        XCTAssertFalse(outcome.coverage.findings.contains(
            .missingLayer(layerID: "L8")),
            "the assembled runtime's memory must reach L8")

        // K — the keyed ledger persisted to disk: reopen it COLD (fresh storage +
        // ledger over the same secret) and count entries — rows must be there and the
        // HMAC chain must verify (a quarantined reload would zero the count).
        let storage2 = try BASSovereignLedgerSQLiteStorage(path: ledgerPath)
        let ledger2 = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data: Data("assembly-secret".utf8)),
            storage: storage2)
        let count2 = await ledger2.count()
        let quarantined = await ledger2.isIntegrityQuarantined
        XCTAssertFalse(quarantined, "reloaded keyed ledger must verify its chain")
        XCTAssertGreaterThan(count2, 0,
            "the turn's sovereign entries must be PERSISTED in the keyed ledger")
    }

    // MARK: - T: the three-signature tool gate fires on the assembled runtime

    /// The first real fire of capability T on an integrated path: permit + warrant +
    /// snapshot proof → execute() runs the tool; the swapped-tool attempt still fails.
    func testThreeSignatureExecuteFiresToolOnAssembledHost() async throws {
        let log = ToolLog()
        let host = try await makeHost(toolLog: log)

        let intent = QinaoRiskGate.ActionIntent(
            digest: "intent.assembly.tool",
            toolName: "journal.append",
            sessionID: "sess.assembly",
            hostVersionID: "host.v1",
            summary: "append a journal entry")
        let permit = try await host.risk.requestActionPermit(for: intent)
        let warrant = try await host.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let proof = await host.sovereign.issueSnapshotContinuityProof(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID),
            anchorID: "anchor.host.v1")

        let result = try await host.runtime.execute(
            toolName: "journal.append",
            payload: Data("entry".utf8),
            intent: intent,
            signatures: .init(permit: permit, warrant: warrant, snapshotProof: proof))
        XCTAssertEqual(String(data: result, encoding: .utf8), "ok")
        let calls = await log.calls
        XCTAssertEqual(calls, ["journal.append"], "the gated tool must have executed")

        // Swapped tool with the same valid signatures must still be refused (F1).
        await XCTAssertThrowsErrorAsync(
            try await host.runtime.execute(
                toolName: "mail.send_all", payload: Data(),
                intent: intent,
                signatures: .init(permit: permit, warrant: warrant, snapshotProof: proof))
        ) { error in
            guard case QinaoRuntime.RuntimeError.toolMismatch = error else {
                return XCTFail("expected toolMismatch, got \(error)")
            }
        }
    }
}
