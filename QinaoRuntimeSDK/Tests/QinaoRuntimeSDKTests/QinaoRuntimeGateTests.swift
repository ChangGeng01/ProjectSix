import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M7.2 — QinaoRuntime three-signature gate.
///
/// These tests enforce invariant #2 ("神经不直接掌权"):
///
///     ActionPermit + SovereignWarrant + SnapshotContinuityProof
///     must all be present, unexpired, and bound to the same
///     intent digest, or the runtime refuses the tool call.
///
/// Every rejection path is proven in isolation so a regression
/// in any one of the three arms is caught at the gate rather
/// than downstream.
final class QinaoRuntimeGateTests: XCTestCase {

    // MARK: - Fixture

    actor ToolRecorder {
        var callCount = 0
        var lastToolName: String?
        var lastPayload: Data?

        func record(name: String, payload: Data) -> Data {
            callCount += 1
            lastToolName = name
            lastPayload = payload
            return Data("ok".utf8)
        }
    }

    /// Full runtime + the substrate plumbing the halt test needs.
    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let recorder: ToolRecorder
        let sovereign: QinaoSovereignControlPlane
        let risk: QinaoRiskGate
        let snapshotManager: BASSovereignSnapshotManager
        let versionTree: BASSovereignHostVersionTree
    }

    /// Build a fully-wired runtime with a recorder-backed tool
    /// executor. The runtime is the same shape a host would see.
    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture
    {
        let recorder = ToolRecorder()

        // Substrate-level coordinator dependencies. The control
        // plane doesn't call into them in the happy path of this
        // test suite (rollback isn't exercised here), so empty
        // stubs are enough.
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
        let engine = BASSovereignVerdictEngine(ledger: ledger, now: now)
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
            hostID: "host",
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
            now: now)

        return Fixture(
            runtime: runtime,
            recorder: recorder,
            sovereign: sovereign,
            risk: risk,
            snapshotManager: snapshotManager,
            versionTree: versionTree)
    }

    private func intent(
        digest: String = "intent.abc",
        sessionID: String = "sess.1"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: "calendar.add_event",
            sessionID: sessionID,
            hostVersionID: "host.v1",
            summary: "add a calendar event")
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func validProof(
        for intent: QinaoRiskGate.ActionIntent,
        at now: Date = Date(),
        ttl: TimeInterval = 10
    ) -> QinaoRuntime.SnapshotContinuityProof {
        QinaoRuntime.SnapshotContinuityProof(
            proofID: "proof-\(UUID().uuidString)",
            sessionID: intent.sessionID,
            anchorID: "anchor-host.v1",
            intentDigest: intent.digest,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttl))
    }

    // MARK: - Happy path

    func testExecuteWithAllThreeSignaturesRunsTool() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let sovereign = fx.sovereign
        let risk = fx.risk
        let it = intent()
        let permit = try await risk.requestActionPermit(for: it)
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest,
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        let proof = validProof(for: it)
        let sigs = QinaoRuntime.Signatures(
            permit: permit, warrant: warrant, snapshotProof: proof)

        let result = try await runtime.execute(
            toolName: "calendar.add_event",
            payload: Data("meet".utf8),
            intent: it,
            signatures: sigs)

        XCTAssertEqual(String(data: result, encoding: .utf8), "ok")
        let count = await recorder.callCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - Digest mismatch (each arm in isolation)

    func testPermitWithWrongDigestIsRejected() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let sovereign = fx.sovereign
        let risk = fx.risk
        let it = intent(digest: "intent.real")
        let wrongPermit = try await risk.requestActionPermit(
            for: intent(digest: "intent.other"))
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest,
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        let proof = validProof(for: it)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Data(),
                intent: it,
                signatures: .init(
                    permit: wrongPermit,
                    warrant: warrant,
                    snapshotProof: proof))
        ) { error in
            guard case QinaoRuntime.RuntimeError
                .digestMismatch(let expected, let got) = error
            else {
                return XCTFail("expected digestMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "intent.real")
            XCTAssertEqual(got, "intent.other")
        }
        let count = await recorder.callCount
        XCTAssertEqual(count, 0)
    }

    func testWarrantWithWrongDigestIsRejected() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let sovereign = fx.sovereign
        let risk = fx.risk
        let it = intent(digest: "intent.real")
        let permit = try await risk.requestActionPermit(for: it)
        let wrongWarrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: "intent.other",
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        let proof = validProof(for: it)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Data(),
                intent: it,
                signatures: .init(
                    permit: permit,
                    warrant: wrongWarrant,
                    snapshotProof: proof))
        ) { error in
            guard case QinaoRuntime.RuntimeError.digestMismatch = error
            else { return XCTFail("expected digestMismatch, got \(error)") }
        }
        let count = await recorder.callCount
        XCTAssertEqual(count, 0)
    }

    func testSnapshotProofWithWrongDigestIsRejected() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let sovereign = fx.sovereign
        let risk = fx.risk
        let it = intent(digest: "intent.real")
        let permit = try await risk.requestActionPermit(for: it)
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest,
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        let wrongProof = validProof(
            for: intent(digest: "intent.other"))

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Data(),
                intent: it,
                signatures: .init(
                    permit: permit,
                    warrant: warrant,
                    snapshotProof: wrongProof))
        ) { error in
            guard case QinaoRuntime.RuntimeError.digestMismatch = error
            else { return XCTFail("expected digestMismatch, got \(error)") }
        }
        let count = await recorder.callCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Expiry

    func testExpiredPermitIsRejected() async throws {
        // Freeze now so expiry is deterministic.
        let frozen = Date(timeIntervalSince1970: 1_700_000_000)
        // Clock starts at frozen, then jumps past permit TTL.
        final class Clock: @unchecked Sendable {
            var t: Date
            init(_ t: Date) { self.t = t }
        }
        let clock = Clock(frozen)
        let nowFn: @Sendable () -> Date = { [clock] in clock.t }
        let fx = await makeRuntime(now: nowFn)
        let runtime = fx.runtime
        let sovereign = fx.sovereign
        let risk = fx.risk

        let it = intent()
        let permit = try await risk.requestActionPermit(for: it)
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest,
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        // Advance past permit TTL (10s); warrant TTL is also 10s —
        // the runtime checks permit first, so that's what we observe.
        clock.t = frozen.addingTimeInterval(11)
        let proof = validProof(for: it, at: clock.t, ttl: 60)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Data(),
                intent: it,
                signatures: .init(
                    permit: permit,
                    warrant: warrant,
                    snapshotProof: proof))
        ) { error in
            guard case QinaoRuntime.RuntimeError.permitExpired = error
            else { return XCTFail("expected permitExpired, got \(error)") }
        }
    }

    // MARK: - Halted session short-circuit

    func testHaltedSessionRefusesEvenWithValidSignatures() async throws {
        let fx = await makeRuntime()
        let sessionID = "sess.halted"
        let it = intent(sessionID: sessionID)

        // Real halt plumbing: register a snapshot anchor, bind it
        // to host.v1, then call `haltSession` — the façade marks
        // the session halted only after the coordinator successfully
        // plans a deadStop reboot against a real anchor.
        let payload = Data("halt-payload".utf8)
        let anchor = BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: "anchor.halt",
            safeSnapshotRef: "snap.halt",
            integrityHash: Self.sha256Hex(payload))
        _ = try await fx.snapshotManager.register(
            anchor: anchor,
            sealedPayload: payload)
        try await fx.versionTree.registerGenesis(
            versionID: "host.v1",
            diffSummary: "genesis")
        try await fx.sovereign.bindSnapshotAnchor(
            anchorID: "anchor.halt",
            toVersionID: "host.v1")

        // Mint signatures BEFORE halting (so they're all structurally
        // valid), then halt and prove the runtime still refuses.
        let permit = try await fx.risk.requestActionPermit(for: it)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest,
                sessionID: it.sessionID,
                hostVersionID: it.hostVersionID))
        let proof = validProof(for: it)

        _ = try await fx.sovereign.haltSession(
            sessionID: sessionID,
            fromVersionID: "host.v1")

        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: "calendar.add_event",
                payload: Data(),
                intent: it,
                signatures: .init(
                    permit: permit,
                    warrant: warrant,
                    snapshotProof: proof))
        ) { error in
            guard case QinaoRuntime.RuntimeError
                .sessionHalted(let sid) = error
            else {
                return XCTFail("expected sessionHalted, got \(error)")
            }
            XCTAssertEqual(sid, sessionID)
        }
        let count = await fx.recorder.callCount
        XCTAssertEqual(count, 0)
    }

    func testIssueWarrantOnHaltedSessionThrows() async throws {
        let fx = await makeRuntime()
        let sessionID = "sess.warrant-halted"
        let payload = Data("payload".utf8)
        let anchor = BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: "anchor.warrant-halt",
            safeSnapshotRef: "snap.warrant-halt",
            integrityHash: Self.sha256Hex(payload))
        _ = try await fx.snapshotManager.register(
            anchor: anchor,
            sealedPayload: payload)
        try await fx.versionTree.registerGenesis(versionID: "host.v1")
        try await fx.sovereign.bindSnapshotAnchor(
            anchorID: "anchor.warrant-halt",
            toVersionID: "host.v1")
        _ = try await fx.sovereign.haltSession(
            sessionID: sessionID,
            fromVersionID: "host.v1")

        await XCTAssertThrowsErrorAsync(
            try await fx.sovereign.issueWarrant(
                for: QinaoSovereignControlPlane.Intent(
                    digest: "d",
                    sessionID: sessionID,
                    hostVersionID: "host.v1"))
        ) { error in
            guard case QinaoSovereignControlPlane.SovereignError
                .sessionHalted(let sid) = error
            else {
                return XCTFail("expected sessionHalted, got \(error)")
            }
            XCTAssertEqual(sid, sessionID)
        }
    }
}

// MARK: - Async throws helper

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(
            "Expected throw; message: \(message())",
            file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
