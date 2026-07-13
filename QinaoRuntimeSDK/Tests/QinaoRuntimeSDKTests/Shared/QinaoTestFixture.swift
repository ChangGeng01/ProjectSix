import Foundation
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

/// Shared test fixture. Replaces the per-file `makeRuntime(...)`
/// boilerplate that used to ripple across every test file when a
/// constructor signature changed.
///
/// `package` access (M169) — this is a test util, not a public
/// SDK surface. `package` keeps it visible across test targets
/// in the same SPM package without polluting the SemVer surface.
///
/// `now: @Sendable () -> Date` is a REQUIRED parameter (M169) —
/// no wall-clock default. TTL-based tests on slow CI flake when
/// the wall clock advances mid-test; every fixture call site
/// must pass a `FakeClock`-style closure or
/// `QinaoTestFixture.frozenClock(at:)` so the test owns time.
package struct QinaoTestFixture: Sendable {

    package let runtime: QinaoRuntime
    package let sovereign: QinaoSovereignControlPlane
    package let host: QinaoHost
    package let memory: QinaoMemory
    package let loop: QinaoLoop
    package let risk: QinaoRiskGate
    package let ledger: BASSovereignAuditLedger

    /// Frozen `now` closure pinned to a specific instant.
    /// Default fixture argument when the call site doesn't care
    /// about time but should NOT inherit wall-clock flakiness.
    package static func frozenClock(
        at instant: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> @Sendable () -> Date {
        { instant }
    }

    /// Build a fixture. M169 — `now` is required (no wall-clock
    /// default); pass `QinaoTestFixture.frozenClock()` for tests
    /// that don't exercise time advancement, or a closure backed
    /// by a stepping `actor` for tests that do.
    package static func make(
        hostID: String = "host.test",
        activeVersion: String = "host.v1",
        withLifecycle: Bool = false,
        warrantTTLSeconds: TimeInterval = 10,
        permitTTLSeconds: TimeInterval = 10,
        renderFrameCapacity: Int =
            QinaoSovereignControlPlane
                .defaultRenderFrameCapacity,
        now: @escaping @Sendable () -> Date =
            QinaoTestFixture.frozenClock(),
        metricsRecorder: QinaoRuntime.MetricsRecorder? = nil
    ) async -> QinaoTestFixture {
        let recorder = ToolRecorder()

        let snapshotManager = BASSovereignSnapshotManager(
            now: now)
        // deep-audit P0-4: pre-register the anchors that fixture-based tests mint snapshot-
        // continuity proofs against, so those proofs verify under the new registration check
        // (a proof for an unregistered anchor is now refused). Extra registrations are harmless.
        for anchorID in ["anchor", "anchor-triple", "anchor-v0", "anchor.demo", "anchor-host.v1",
                         "anchor.host.v1", "a.v1", "a-demo-warm", "a-demo-reserved"] {
            let payload = Data(anchorID.utf8)
            _ = try? await snapshotManager.register(
                anchor: BASSovereignSnapshotManager.SnapshotAnchor(
                    anchorID: anchorID, safeSnapshotRef: "snap.\(anchorID)",
                    integrityHash: SHA256.hash(data: payload)
                        .map { String(format: "%02x", $0) }.joined()),
                sealedPayload: payload)
        }
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(
            now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: warrantTTLSeconds,
            now: now,
            renderFrameCapacity: renderFrameCapacity)

        let risk = QinaoRiskGate(
            permitTTLSeconds: permitTTLSeconds, now: now)
        let constitution = BASHostConstitution(
            hostID: hostID,
            activeVersion: activeVersion)
        let tree = BASHostVersionTree(
            activeVersionID: activeVersion,
            versions: [
                BASHostVersion(
                    versionID: activeVersion,
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

        let executor: QinaoRuntime.ToolExecutor = {
            name, payload in
            await recorder.record(
                name: name, payload: payload)
        }

        let lifecycle: QinaoLifecycle?
        if withLifecycle {
            let thermalHolder = ThermalHolder()
            let submitter = NoopSubmitter()
            let canceller = NoopCanceller()
            lifecycle = QinaoLifecycle.makeForTesting(
                taskIdentifierPrefix: "qinao.test.breath",
                timeConstantSeconds: 180,
                thermalReader: { thermalHolder.get() },
                submitter: { id, date in
                    await submitter.record(
                        identifier: id, date: date)
                },
                canceller: { id in
                    await canceller.record(id)
                },
                clock: {
                    Date(timeIntervalSince1970: 1_700_000_000)
                })
        } else {
            lifecycle = nil
        }

        let runtime = QinaoRuntime(
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: executor, now: now,
            lifecycle: lifecycle,
            metricsRecorder: metricsRecorder)

        return QinaoTestFixture(
            runtime: runtime,
            sovereign: sovereign,
            host: host,
            memory: memory,
            loop: loop,
            risk: risk,
            ledger: ledger)
    }

    /// Convenience: build a `TurnObservations` with the fixture's
    /// default session + snapshot + policy, varying only turnID.
    /// Replaces the `obs(turnID:)` helper that every test file
    /// defined locally.
    public func observations(
        sessionID: String = "sess.test",
        turnID: String = "turn.1",
        snapshotRef: String = "snap.test",
        policyHash: String = "policy.test"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash)
    }

    // MARK: - Private setup helpers

    /// Thread-safe thermal holder used by the lifecycle factory.
    /// `ProcessInfo.ThermalState` parity — nominal by default.
    private final class ThermalHolder: @unchecked Sendable {
        private let lock = NSLock()
        private var state: BASThermalTwin.OSThermalState =
            .nominal
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }
            return state
        }
    }

    /// Noop submit for BGTaskScheduler bridge — records nothing,
    /// always says "accepted". Tests that want real bridge
    /// behavior build their own QinaoBGMaintenanceBridge.
    private actor NoopSubmitter {
        func record(
            identifier: String, date: Date
        ) -> Bool { true }
    }

    private actor NoopCanceller {
        func record(_ identifier: String) {}
    }

    private actor ToolRecorder {
        func record(
            name: String, payload: Data
        ) -> Data {
            Data()
        }
    }
}
