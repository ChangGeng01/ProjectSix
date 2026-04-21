import Foundation
import CryptoKit
import BASMemory
import BASSovereign
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop
@testable import QinaoRuntime

/// Shared harness for the five integrity-property demos.
///
/// These demos prove end-to-end property behaviour against the
/// Qinao *public* API. Setup of the underlying substrate (host
/// pipeline, snapshot manager, version tree, ledger, token
/// authority) is test-only scaffolding; in a real host, the
/// `QinaoSovereignControlPlane.bootstrap(configuration:)` factory
/// wraps all of that and nothing substrate-typed crosses the
/// application's top level.
///
/// We keep the fixture `internal` (not `public`) so the demos can
/// use full access while leaving the production-surface narrative
/// clean.
enum PropertyDemoFixture {

    static let frozenNow: @Sendable () -> Date = {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// One fully-wired runtime plus the pieces the demos need to
    /// drive it (recorder for side-effect proofs, sovereign +
    /// risk handles for issuing signatures inside the test, plus
    /// the snapshot manager / version tree the halt-path demo
    /// needs to bind a real anchor before `haltSession` succeeds).
    struct Runtime {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
        let risk: QinaoRiskGate
        let host: QinaoHost
        let memory: QinaoMemory
        let loop: QinaoLoop
        let recorder: ToolRecorder
        let snapshotManager: BASSovereignSnapshotManager
        let versionTree: BASSovereignHostVersionTree
    }

    /// Thread-safe call recorder — lets the demos count side
    /// effects without fighting the actor isolation.
    actor ToolRecorder {
        private(set) var callCount: Int = 0
        private(set) var lastPayload: Data?
        func record(name: String, payload: Data) -> Data {
            callCount += 1
            lastPayload = payload
            return Data("ok".utf8)
        }
    }

    static func makeRuntime(
        now: @escaping @Sendable () -> Date = frozenNow
    ) -> Runtime {
        let recorder = ToolRecorder()

        // --- Sovereign control plane (demo uses internal init so
        // the demo can reach into the same snapshot manager /
        // version tree the proof anchor points at). In production
        // code a host uses the `bootstrap(configuration:)` factory
        // and never sees these types.
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
            warrantTTLSeconds: 30,
            now: now)

        // --- Risk gate.
        let risk = QinaoRiskGate(
            permitTTLSeconds: 30,
            defaultDelaySeconds: 60,
            now: now)

        // --- Host constitution pipeline (seeded with a single
        // version so rollback/approve have a starting point).
        let constitution = BASHostConstitution(
            hostID: "demo-host",
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

        return Runtime(
            runtime: runtime,
            sovereign: sovereign,
            risk: risk,
            host: host,
            memory: memory,
            loop: loop,
            recorder: recorder,
            snapshotManager: snapshotManager,
            versionTree: versionTree)
    }

    // MARK: - Halt plumbing helper

    /// Register a snapshot anchor + host version + binding so that
    /// `fx.sovereign.haltSession(...)` can plan a real deadStop
    /// reboot instead of throwing `unknownVersion`. The demos use
    /// this to prove the "sleep" half of 会醒会停 end-to-end.
    static func prepareHaltPlumbing(
        runtime fx: Runtime,
        anchorID: String = "anchor.demo",
        versionID: String = "host.v1",
        payload: Data = Data("demo-payload".utf8)
    ) async throws {
        let digest = SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
        let anchor = BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: anchorID,
            safeSnapshotRef: "snap.\(anchorID)",
            integrityHash: digest)
        _ = try await fx.snapshotManager.register(
            anchor: anchor, sealedPayload: payload)
        try await fx.versionTree.registerGenesis(
            versionID: versionID, diffSummary: "genesis")
        try await fx.sovereign.bindSnapshotAnchor(
            anchorID: anchorID, toVersionID: versionID)
    }

    // MARK: - Intent + proof helpers

    static func intent(
        digest: String = "intent.demo",
        sessionID: String = "sess.demo",
        toolName: String = "calendar.add_event"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: toolName,
            sessionID: sessionID,
            hostVersionID: "host.v1",
            summary: "demo intent")
    }

    static func validProof(
        for intent: QinaoRiskGate.ActionIntent,
        at now: Date = frozenNow(),
        ttl: TimeInterval = 30
    ) -> QinaoRuntime.SnapshotContinuityProof {
        QinaoRuntime.SnapshotContinuityProof(
            proofID: "proof-\(UUID().uuidString)",
            sessionID: intent.sessionID,
            anchorID: "anchor-host.v1",
            intentDigest: intent.digest,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttl))
    }

    /// Build a fully-signed bundle — used by demos that need to
    /// cross the three-signature gate in the happy path.
    static func signBundle(
        for intent: QinaoRiskGate.ActionIntent,
        runtime fx: Runtime
    ) async throws -> QinaoRuntime.Signatures {
        let permit = try await fx.risk.requestActionPermit(for: intent)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let proof = validProof(for: intent)
        return QinaoRuntime.Signatures(
            permit: permit,
            warrant: warrant,
            snapshotProof: proof)
    }
}
