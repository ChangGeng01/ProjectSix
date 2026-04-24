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

/// M155 — shared test fixture.
///
/// Pre-M155 every test file repeated ~80-100 lines of boilerplate:
///
///   actor ToolRecorder { ... }
///   struct Fixture: Sendable { runtime; sovereign }
///   private func makeRuntime(...) async -> Fixture {
///       let snapshotManager = ...; let versionTree = ...;
///       let ledger = ...; let coordinator = ...;
///       let tokenAuthority = ...; let engine = ...;
///       let verifier = ...; let sovereign = ...;
///       let risk = ...; let constitution = ...;
///       let tree = ...; let pipeline = ...;
///       let host = ...; let memory = ...; let loop = ...;
///       let executor = ...; let runtime = ...;
///       return Fixture(...)
///   }
///
/// Across 15-20 test files this ballooned to ~1500-2000 lines of
/// mechanical duplication. Any fixture adjustment (new field on
/// an actor, ctor signature change) had to ripple to every file.
///
/// Post-M155: one `QinaoTestFixture.make(...)` factory replaces
/// all of that. Test bodies keep the assertions; setup collapses
/// from ~100 lines per file to 1 line:
///
///     let fx = await QinaoTestFixture.make()
///     // or customized:
///     let fx = await QinaoTestFixture.make(
///         hostID: "host.custom", withLifecycle: true)
///
/// The factory is `async` because it crosses actor boundaries
/// and returns the seven most-accessed runtime surfaces as stored
/// properties (runtime / sovereign / host / memory / loop / risk /
/// ledger). Test files that need rare internals (e.g. the
/// snapshot manager) can build a QinaoRuntime directly; most
/// don't.
public struct QinaoTestFixture: Sendable {

    public let runtime: QinaoRuntime
    public let sovereign: QinaoSovereignControlPlane
    public let host: QinaoHost
    public let memory: QinaoMemory
    public let loop: QinaoLoop
    public let risk: QinaoRiskGate
    public let ledger: BASSovereignAuditLedger

    /// Build a fixture with defaults that satisfy the vast
    /// majority of tests. Every parameter has a sensible default;
    /// tests override only what they need.
    ///
    /// - Parameters:
    ///   - hostID: passed to `BASHostConstitution.hostID`.
    ///   - activeVersion: passed to
    ///     `BASHostConstitution.activeVersion` and registered
    ///     as the single `BASHostVersion` in the version tree.
    ///   - withLifecycle: when `true`, wires a real
    ///     `QinaoLifecycle` using `makeForTesting(...)` with
    ///     nominal thermal + no-op submitter/canceller.
    ///   - warrantTTLSeconds: forwarded to
    ///     `QinaoSovereignControlPlane`.
    ///   - permitTTLSeconds: forwarded to `QinaoRiskGate`.
    ///   - renderFrameCapacity: forwarded to
    ///     `QinaoSovereignControlPlane` (M132 cap).
    ///   - now: the shared clock for every time-sensitive
    ///     substrate component.
    public static func make(
        hostID: String = "host.test",
        activeVersion: String = "host.v1",
        withLifecycle: Bool = false,
        warrantTTLSeconds: TimeInterval = 10,
        permitTTLSeconds: TimeInterval = 10,
        renderFrameCapacity: Int =
            QinaoSovereignControlPlane
                .defaultRenderFrameCapacity,
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> QinaoTestFixture {
        let recorder = ToolRecorder()

        let snapshotManager = BASSovereignSnapshotManager(
            now: now)
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
            lifecycle: lifecycle)

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
