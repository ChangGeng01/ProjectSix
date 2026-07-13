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

        // deep-audit P0-4: register the anchor `validProof` mints against, so the happy-path proofs
        // verify under the new registration check (a proof for an unregistered anchor is refused).
        _ = try? await snapshotManager.register(
            anchor: BASSovereignSnapshotManager.SnapshotAnchor(
                anchorID: "anchor-host.v1",
                safeSnapshotRef: "snap.host.v1",
                integrityHash: Self.sha256Hex(Data("host.v1".utf8))),
            sealedPayload: Data("host.v1".utf8))

        return Fixture(
            runtime: runtime,
            recorder: recorder,
            sovereign: sovereign,
            risk: risk,
            snapshotManager: snapshotManager,
            versionTree: versionTree)
    }

    // deep-audit P0-1: the standard payload the canonical-digest intents bind (execute() now
    // recomputes the digest from the presented tool+payload, so intent and execute must agree).
    private static let gatePayload = Data("meet".utf8)

    private func intent(
        digest: String? = nil,
        sessionID: String = "sess.1"
    ) -> QinaoRiskGate.ActionIntent {
        // Default: a canonical digest binding tool+payload+session+host (the form execute enforces).
        // An explicit `digest:` (mismatch tests) overrides it to exercise the rejection path.
        let d = digest ?? QinaoRiskGate.ActionIntent.canonicalDigest(
            toolName: "calendar.add_event", payload: Self.gatePayload,
            sessionID: sessionID, hostVersionID: "host.v1")
        return QinaoRiskGate.ActionIntent(
            digest: d,
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

    /// integration S3: proofs are minted by the control plane (HMAC-signed).
    private func validProof(
        for intent: QinaoRiskGate.ActionIntent,
        sovereign: QinaoSovereignControlPlane,
        ttl: TimeInterval = 10
    ) async -> QinaoRuntime.SnapshotContinuityProof {
        await sovereign.issueSnapshotContinuityProof(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID),
            anchorID: "anchor-host.v1",
            ttlSeconds: ttl)
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
        let proof = await validProof(for: it, sovereign: sovereign)
        let sigs = QinaoRuntime.Signatures(
            permit: permit, warrant: warrant, snapshotProof: proof)

        let result = try await runtime.execute(
            toolName: "calendar.add_event",
            payload: Self.gatePayload,
            intent: it,
            signatures: sigs)

        XCTAssertEqual(String(data: result, encoding: .utf8), "ok")
        let count = await recorder.callCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - deep-audit P0-1: permit binds tool AND payload

    /// A fully-valid bundle minted for payload A cannot be reused to execute a DIFFERENT payload B.
    /// The permit signs the canonical digest of (tool, payload, session, host); presenting payload B
    /// recomputes a different digest and fails the gate. Pre-fix the payload was never in the signed
    /// material, so B would have executed under A's approval.
    func testPermitCannotBeReusedForADifferentPayload() async throws {
        let fx = await makeRuntime()
        let it = intent()   // binds Self.gatePayload
        let permit = try await fx.risk.requestActionPermit(for: it)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID))
        let proof = await validProof(for: it, sovereign: fx.sovereign)
        let sigs = QinaoRuntime.Signatures(permit: permit, warrant: warrant, snapshotProof: proof)

        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: "calendar.add_event",
                payload: Data("A DIFFERENT PAYLOAD".utf8),   // ≠ the bound gatePayload
                intent: it, signatures: sigs)
        ) { error in
            guard case QinaoRuntime.RuntimeError.digestMismatch = error else {
                return XCTFail("a swapped payload must be refused at the canonical binding, got \(error)")
            }
        }
        let count = await fx.recorder.callCount
        XCTAssertEqual(count, 0, "the tool must not run with a payload the permit never bound")
    }

    // MARK: - deep-audit P0-2: single-use bundle (no replay within TTL)

    /// A fully-valid, unexpired (permit, warrant, proof) bundle fires the tool exactly ONCE.
    /// A second execute() with the SAME bundle throws tokenAlreadyConsumed and does NOT re-run
    /// the tool — proving the side effect cannot be replayed within the TTL. Pre-fix (stateless
    /// validation, no consume) the second call would run the tool a second time.
    func testSameBundleCannotBeReplayedWithinTTL() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let it = intent()
        let permit = try await fx.risk.requestActionPermit(for: it)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID))
        let proof = await validProof(for: it, sovereign: fx.sovereign)
        let sigs = QinaoRuntime.Signatures(
            permit: permit, warrant: warrant, snapshotProof: proof)

        _ = try await runtime.execute(
            toolName: "calendar.add_event", payload: Self.gatePayload, intent: it, signatures: sigs)

        do {
            _ = try await runtime.execute(
                toolName: "calendar.add_event", payload: Self.gatePayload,
                intent: it, signatures: sigs)
            XCTFail("a consumed bundle must not execute again")
        } catch QinaoRuntime.RuntimeError.tokenAlreadyConsumed {
            // expected
        }
        let count = await recorder.callCount
        XCTAssertEqual(count, 1, "the tool must have run exactly once despite the replay attempt")
    }

    // MARK: - deep-audit P0-4: proof must prove a LIVE anchor

    /// A structurally valid, correctly-signed, unexpired proof whose anchorID is NOT registered
    /// must be refused — the proof previously "verified" as a signed string that proved no live
    /// snapshot chain. execute() throws missingSnapshotProof for it.
    func testProofForUnregisteredAnchorIsRefused() async throws {
        let fx = await makeRuntime()
        let it = intent()
        let permit = try await fx.risk.requestActionPermit(for: it)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID))
        // Mint a proof for an anchor that was never registered.
        let orphanProof = await fx.sovereign.issueSnapshotContinuityProof(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID),
            anchorID: "anchor.NEVER-REGISTERED", ttlSeconds: 10)

        let valid = await fx.sovereign.isSnapshotProofValid(
            orphanProof,
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID))
        XCTAssertFalse(valid, "a proof for an unregistered anchor must not verify")

        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: "calendar.add_event", payload: Self.gatePayload, intent: it,
                signatures: .init(permit: permit, warrant: warrant, snapshotProof: orphanProof))
        ) { error in
            guard case QinaoRuntime.RuntimeError.missingSnapshotProof = error else {
                return XCTFail("expected missingSnapshotProof, got \(error)")
            }
        }
    }

    // MARK: - audit F1: tool-swap rejection (valid signatures, wrong tool)

    /// A caller with FULLY VALID signatures for intent A (tool "calendar.add_event") passes a
    /// DIFFERENT toolName. execute() must bind the executed tool to the signed intent.toolName
    /// and refuse — before the fix, toolName was a dead field and B would have run under A's
    /// approval (confused deputy / approval reuse).
    func testMismatchedToolNameIsRejectedEvenWithValidSignatures() async throws {
        let fx = await makeRuntime()
        let runtime = fx.runtime
        let recorder = fx.recorder
        let sovereign = fx.sovereign
        let risk = fx.risk
        let it = intent()  // toolName == "calendar.add_event"
        let permit = try await risk.requestActionPermit(for: it)
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: it.digest, sessionID: it.sessionID, hostVersionID: it.hostVersionID))
        let proof = await validProof(for: it, sovereign: sovereign)
        let sigs = QinaoRuntime.Signatures(
            permit: permit, warrant: warrant, snapshotProof: proof)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "mail.send_all",  // ← swapped tool, same (valid) signatures
                payload: Self.gatePayload,
                intent: it,
                signatures: sigs)
        ) { error in
            guard case QinaoRuntime.RuntimeError.toolMismatch(let expected, let got) = error
            else { return XCTFail("expected toolMismatch, got \(error)") }
            XCTAssertEqual(expected, "calendar.add_event")
            XCTAssertEqual(got, "mail.send_all")
        }
        let count = await recorder.callCount
        XCTAssertEqual(count, 0, "the swapped tool must NOT execute")
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
        let proof = await validProof(for: it, sovereign: sovereign)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Self.gatePayload,
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
            // deep-audit P0-1: the wrong permit is now rejected at the canonical tool+payload
            // binding check (which fires first). `got` is the wrong permit's digest; `expected` is
            // the SDK-canonical bound digest for the presented tool+payload.
            XCTAssertEqual(got, "intent.other")
            XCTAssertEqual(expected, QinaoRiskGate.ActionIntent.canonicalDigest(
                toolName: "calendar.add_event", payload: Self.gatePayload,
                sessionID: it.sessionID, hostVersionID: "host.v1"))
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
        let proof = await validProof(for: it, sovereign: sovereign)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Self.gatePayload,
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
        let wrongProof = await validProof(
            for: intent(digest: "intent.other"), sovereign: sovereign)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Self.gatePayload,
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
        let proof = await validProof(for: it, sovereign: sovereign, ttl: 60)

        await XCTAssertThrowsErrorAsync(
            try await runtime.execute(
                toolName: "calendar.add_event",
                payload: Self.gatePayload,
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
        let proof = await validProof(for: it, sovereign: fx.sovereign)

        _ = try await fx.sovereign.haltSession(
            sessionID: sessionID,
            fromVersionID: "host.v1")

        await XCTAssertThrowsErrorAsync(
            try await fx.runtime.execute(
                toolName: "calendar.add_event",
                payload: Self.gatePayload,
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
