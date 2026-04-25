import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M69 — `QinaoRuntime.prepareBudgetForTurn(_:)` +
/// `recordTurnOnLifecycle(runMode:durationSeconds:)`.
///
/// These tests prove the main-chain wiring from the L1 lifecycle into
/// per-turn `BASBudgetFrame`. Specifically:
///
/// 1. A runtime constructed **without** a lifecycle treats
///    `prepareBudgetForTurn` as an identity — the planned frame comes
///    back byte-for-byte unchanged (JSON round-trip equal), and
///    `recordTurnOnLifecycle` is a no-op returning `nil`.
/// 2. A runtime constructed **with** a lifecycle threads the
///    lifecycle's live thermal guard level into the returned frame.
///    Under a `.critical` reader the routed frame's guard level is
///    `.emergency`; other fields are preserved.
/// 3. `recordTurnOnLifecycle` forwards to the underlying lifecycle
///    and advances its state (lung accumulator + thermal resample),
///    returning a non-`nil` `TurnRecorded` outcome.
///
/// The M69 contract is narrow on purpose: it's a value-transform
/// seam, not a gate. The three-signature gate and the turn audit
/// stay covered by their existing test suites.
final class QinaoRuntimeLifecycleTests: XCTestCase {

    // MARK: - Thermal source (mirrors QinaoLifecycleTests)

    final class ThermalSource: @unchecked Sendable {
        private let lock = NSLock()
        private var _state: BASThermalTwin.OSThermalState = .nominal
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }
            return _state
        }
        func set(_ v: BASThermalTwin.OSThermalState) {
            lock.lock(); defer { lock.unlock() }
            _state = v
        }
    }

    // MARK: - Runtime fixture

    private func makeRuntime(
        lifecycle: QinaoLifecycle? = nil,
        now: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
    ) -> QinaoRuntime {
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
            hostID: "host", activeVersion: "host.v1")
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

        let executor: QinaoRuntime.ToolExecutor = { _, _ in Data() }

        return QinaoRuntime(
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now,
            lifecycle: lifecycle)
    }

    private func makeLifecycle(
        thermal: ThermalSource,
        submitCallsOK: Bool = true
    ) -> QinaoLifecycle {
        QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "test.breath",
            timeConstantSeconds: 180,
            thermalReader: { thermal.get() },
            submitter: { _, _ in submitCallsOK },
            canceller: { _ in },
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func plannedBudget(
        thermalGuardLevel: BASThermalGuardLevel = .nominal
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 5,
            maxDecodeTokens: 128,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: true,
            leaseID: "lease-m69",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_700_000_500),
            maintenanceClass: .light,
            wakeIntentID: "wake-m69",
            allowedHeads: ["scout.default", "core.default"],
            policyBundleVersion: "policy-v1.3",
            policyDecisionIDs: ["p-1", "p-2"])
    }

    // MARK: - Backwards-compat: no lifecycle

    func testPrepareBudgetWithoutLifecycleIsIdentity() async throws {
        let runtime = makeRuntime(lifecycle: nil)
        // M162 — the default `BudgetThermalAdapter` is 1.0× under
        // `.nominal`, so a no-lifecycle + nominal-planned call is
        // byte-identity. Hot planned levels under default adapter
        // would compress (covered by M162 tests).
        let planned = plannedBudget(thermalGuardLevel: .nominal)

        let routed = await runtime.prepareBudgetForTurn(planned)

        // JSON-level byte-for-byte equality over the whole struct.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let a = try encoder.encode(planned)
        let b = try encoder.encode(routed)
        XCTAssertEqual(a, b,
            "without a lifecycle and under nominal thermal, "
            + "prepareBudgetForTurn must return the planned frame "
            + "byte-for-byte unchanged")
    }

    /// M162 — same call but with explicit `.identity` adapter is
    /// byte-identity even when planned thermal is hot. Hosts that
    /// run their own compression elsewhere can opt out this way.
    func testPrepareBudgetWithoutLifecycleIdentityAdapterPreservesHotPlan()
        async throws {
        let runtime = makeRuntime(lifecycle: nil)
        let planned = plannedBudget(thermalGuardLevel: .emergency)

        let routed = await runtime.prepareBudgetForTurn(
            planned, thermalAdapter: .identity)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let a = try encoder.encode(planned)
        let b = try encoder.encode(routed)
        XCTAssertEqual(a, b,
            "with .identity adapter, prepareBudgetForTurn is "
            + "byte-identity even at .emergency planned thermal")
    }

    func testRecordTurnOnLifecycleWithoutLifecycleReturnsNil() async {
        let runtime = makeRuntime(lifecycle: nil)
        let outcome = await runtime.recordTurnOnLifecycle(
            runMode: .engage, durationSeconds: 1.0)
        XCTAssertNil(outcome,
            "without a lifecycle, recordTurnOnLifecycle must be a no-op")
    }

    func testLifecyclePropertyIsNilWhenNotProvided() {
        let runtime = makeRuntime(lifecycle: nil)
        XCTAssertNil(runtime.lifecycle)
    }

    // MARK: - With lifecycle: live thermal reaches the frame

    func testPrepareBudgetWithLifecycleRoutesLiveGuardLevel() async {
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        // M162 — exercise pre-compression behavior here so the M69
        // contract (live thermal lands on the routed frame) is
        // pinned without entanglement with the M162 work-volume
        // compressor. M162 compression is exhaustively covered by
        // QinaoRuntimeM162ThermalAdaptiveBudgetTests.
        let routed = await runtime.prepareBudgetForTurn(
            planned, thermalAdapter: .identity)

        XCTAssertEqual(routed.thermalGuardLevel, .emergency,
            ".critical reader → guard .emergency on the routed frame")
        // Other fields preserved (spot check the ones most likely
        // to drift if a future refactor broke the helper).
        XCTAssertEqual(routed.runMode, planned.runMode)
        XCTAssertEqual(routed.maxLoops, planned.maxLoops)
        XCTAssertEqual(routed.deviceRoute, planned.deviceRoute)
        XCTAssertEqual(routed.leaseID, planned.leaseID)
        XCTAssertEqual(routed.allowedHeads, planned.allowedHeads)
        XCTAssertEqual(routed.policyDecisionIDs,
                       planned.policyDecisionIDs)
    }

    /// M162 — same lifecycle path but under the default adapter:
    /// `.critical` reader → routed `.emergency` thermal AND the
    /// numeric work-volume fields are compressed by 0.25×. This
    /// pins the integrated M69 + M162 behavior on the main
    /// `prepareBudgetForTurn` call.
    func testPrepareBudgetWithLifecycleAndDefaultAdapterCompressesUnderEmergency()
        async {
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let routed = await runtime.prepareBudgetForTurn(planned)

        XCTAssertEqual(routed.thermalGuardLevel, .emergency)
        // 3 × 0.25 = 0.75 → banker-rounded to 1.
        XCTAssertEqual(routed.maxLoops, 1)
        // 5 × 0.25 = 1.25 → rounded to 1.
        XCTAssertEqual(routed.maxCandidates, 1)
        // 128 × 0.25 = 32 → 32.
        XCTAssertEqual(routed.maxDecodeTokens, 32)
        // 4 × 0.25 = 1.0 → 1.
        XCTAssertEqual(routed.retrievalDepth, 1)
        // Non-numeric fields preserved.
        XCTAssertEqual(routed.runMode, planned.runMode)
        XCTAssertEqual(routed.deviceRoute, planned.deviceRoute)
        XCTAssertEqual(routed.leaseID, planned.leaseID)
        XCTAssertEqual(routed.allowedHeads, planned.allowedHeads)
        XCTAssertEqual(routed.policyDecisionIDs,
                       planned.policyDecisionIDs)
    }

    func testPrepareBudgetWithLifecycleForcesSampleWhenCold() async {
        // No prior `recordTurn` / `resample` — the lifecycle has
        // never observed a turn. The runtime's prepare seam still
        // reaches a live reading via the thermal twin's force-sample
        // fallback.
        let thermal = ThermalSource()
        thermal.set(.serious)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let routed = await runtime.prepareBudgetForTurn(planned)

        // `.serious` → thermal .hot → guard .throttle at zero pressure.
        XCTAssertEqual(routed.thermalGuardLevel, .throttle)
    }

    func testPrepareBudgetLiveReadingOverridesPlannedValue() async {
        // Caller planned `.throttle` but the live reading is nominal;
        // the routed frame must reflect the live truth, not the plan.
        let thermal = ThermalSource()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        _ = await lifecycle.resample()  // warm cache

        let planned = plannedBudget(thermalGuardLevel: .throttle)
        let routed = await runtime.prepareBudgetForTurn(planned)

        XCTAssertEqual(routed.thermalGuardLevel, .nominal,
            "live lifecycle reading must beat the caller's plan")
    }

    func testPrepareBudgetDoesNotMutateSourceFrame() async {
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        _ = await runtime.prepareBudgetForTurn(planned)

        // `BASBudgetFrame` is a value type — the routed copy must not
        // leak back into the caller's source frame.
        XCTAssertEqual(planned.thermalGuardLevel, .nominal)
    }

    // MARK: - recordTurnOnLifecycle forwarding

    func testRecordTurnOnLifecycleForwardsAndAccumulates() async {
        let thermal = ThermalSource()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        let outcome = await runtime.recordTurnOnLifecycle(
            runMode: .deepLoop, durationSeconds: 2.0)

        let recorded = try? XCTUnwrap(outcome)
        XCTAssertEqual(recorded?.lung.turnCount, 1,
            "forwarded recordTurn must advance the lung turn count")
        XCTAssertGreaterThan(recorded?.lung.pressure ?? -1, 0.0,
            "deepLoop for 2s must push pressure above baseline")
    }

    func testLifecyclePropertyReturnsInjectedInstance() async {
        let thermal = ThermalSource()
        let lifecycle = makeLifecycle(thermal: thermal)
        let runtime = makeRuntime(lifecycle: lifecycle)

        XCTAssertNotNil(runtime.lifecycle)
        XCTAssertTrue(runtime.lifecycle === lifecycle,
            "runtime.lifecycle must expose the injected instance for "
            + "hosts that want direct access (thermalActor / bridge).")
    }
}
