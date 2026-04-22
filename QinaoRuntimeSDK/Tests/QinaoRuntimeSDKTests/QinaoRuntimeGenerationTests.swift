import XCTest
import CryptoKit
import BASRuntimeCore
import BASOrgan
import BASLeaseLife
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M78 — `QinaoRuntime.generateCandidatesForTurn(...)`.
///
/// M77 proved the routing function + loop integration; M70 proved the
/// lifecycle → budget seam. M78 tests prove the three seams stitch
/// correctly at the `QinaoRuntime` boundary:
///
/// 1. `prepareBudgetForTurn` first (live thermal → budget);
/// 2. `QinaoOrganRouting.decide(...)` per seed (routed budget →
///    decision); and
/// 3. `QinaoLoop.generateCandidates(...routedBudget:routingPolicy:)`
///    (decision → endpoint).
///
/// The fixture wires a `BudgetAwareSpyEndpoint` (a near-copy of the
/// M77 routing suite's spy) into a full `QinaoRuntime` so the tests
/// walk end-to-end from "caller hands in plannedBudget" to "endpoint
/// sees routed decision" without stubbing a single layer.
final class QinaoRuntimeGenerationTests: XCTestCase {

    // MARK: - Thermal source (mirrors QinaoRuntimeLifecycleTests)

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

    // MARK: - Spy endpoint (mirrors QinaoOrganRoutingTests)

    /// Dual-purpose spy: conforms to `QinaoBudgetAwareOrganEndpoint`
    /// and captures every call so tests can assert the decision the
    /// runtime computed actually reached the endpoint in lockstep
    /// with what `generateCandidatesForTurn` returned.
    actor BudgetAwareSpyEndpoint: QinaoBudgetAwareOrganEndpoint {
        struct RoutedCall: Sendable, Equatable {
            let prompt: String
            let context: [String]
            let sessionID: String
            let decision: QinaoLoop.QinaoOrganRoutingDecision
        }
        struct LegacyCall: Sendable, Equatable {
            let prompt: String
            let context: [String]
            let role: QinaoLoop.OrganRole
            let sessionID: String
        }
        private(set) var routedCalls: [RoutedCall] = []
        private(set) var legacyCalls: [LegacyCall] = []
        private let providerID: String
        init(providerID: String = "spy.m78.v1") {
            self.providerID = providerID
        }
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            legacyCalls.append(LegacyCall(
                prompt: prompt, context: context,
                role: role, sessionID: sessionID))
            return QinaoLoop.OrganResponse(
                body: "[legacy:\(role.rawValue)] \(prompt)",
                providerID: providerID,
                traceID: "legacy-\(legacyCalls.count)")
        }
        func produceBody(
            prompt: String,
            context: [String],
            sessionID: String,
            decision: QinaoLoop.QinaoOrganRoutingDecision
        ) async throws -> QinaoLoop.OrganResponse {
            routedCalls.append(RoutedCall(
                prompt: prompt, context: context,
                sessionID: sessionID, decision: decision))
            return QinaoLoop.OrganResponse(
                body: "[routed:\(decision.role.rawValue)] \(prompt)",
                providerID: providerID,
                traceID: "routed-\(routedCalls.count)")
        }
        func observedRoutedCalls() -> [RoutedCall] { routedCalls }
        func observedLegacyCalls() -> [LegacyCall] { legacyCalls }
    }

    // MARK: - Fixtures

    /// Builds a full `QinaoRuntime` with optional lifecycle + optional
    /// organ endpoint. The endpoint is injected through `QinaoLoop`
    /// so the runtime's `generateCandidatesForTurn` drives the real
    /// loop path — not a stub — and the spy sees the actual per-seed
    /// decisions the loop dispatches.
    private func makeRuntime(
        lifecycle: QinaoLifecycle? = nil,
        organEndpoint: (any QinaoOrganEndpoint)? = nil,
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
        let loop: QinaoLoop
        if let endpoint = organEndpoint {
            loop = QinaoLoop(organEndpoint: endpoint)
        } else {
            loop = QinaoLoop()
        }

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
        thermal: ThermalSource
    ) -> QinaoLifecycle {
        QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "test.m78.breath",
            timeConstantSeconds: 180,
            thermalReader: { thermal.get() },
            submitter: { _, _ in true },
            canceller: { _ in },
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func plannedBudget(
        precision: BASRuntimePrecisionProfile = .protected,
        thermalGuardLevel: BASThermalGuardLevel = .nominal
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 1,
            maxCandidates: 2,
            maxDecodeTokens: 512,
            retrievalDepth: 2,
            precisionProfile: precision,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: false)
    }

    private func makeSeed(
        _ id: String,
        role: QinaoLoop.OrganRole
    ) -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: id,
            title: "t-\(id)",
            prompt: "p-\(id)",
            context: [],
            role: role,
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: 0.5,
            confidence: 0.5)
    }

    // MARK: - 1. Nil plannedBudget → budget-absent defaults

    func testRoutedGenerationNilPlannedBudgetUsesDefaults() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let seeds = [
            makeSeed("c1", role: .scout),
            makeSeed("c2", role: .core),
        ]
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-nil",
            seeds: seeds,
            plannedBudget: nil)

        XCTAssertNil(result.routedBudget,
            "nil plannedBudget → nil routedBudget")
        XCTAssertEqual(result.decisions.count, 2)
        for d in result.decisions {
            XCTAssertEqual(d.reasonCodes, ["budget-absent"],
                "nil routed budget must produce budget-absent decisions")
        }
        // Role preserved under budget-absent default policy:
        // scout→scout, core→core.
        XCTAssertEqual(result.decisions[0].role, .scout)
        XCTAssertEqual(result.decisions[1].role, .core)

        let routed = await endpoint.observedRoutedCalls()
        XCTAssertEqual(routed.count, 2,
            "loop must still dispatch routed calls even with "
            + "budget-absent decisions")
        XCTAssertEqual(routed[0].decision.reasonCodes, ["budget-absent"])
        XCTAssertEqual(routed[1].decision.reasonCodes, ["budget-absent"])
    }

    // MARK: - 2. Emergency downgrades core seed to scout

    func testRoutedGenerationEmergencyDowngradesCoreSeed() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .emergency)
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-emerg",
            seeds: [makeSeed("c1", role: .core)],
            plannedBudget: planned)

        XCTAssertNotNil(result.routedBudget)
        XCTAssertEqual(result.routedBudget?.thermalGuardLevel, .emergency,
            "no lifecycle → prepareBudgetForTurn is an identity, "
            + "planned .emergency flows through to routedBudget")
        XCTAssertEqual(result.decisions.count, 1)
        XCTAssertEqual(result.decisions[0].role, .scout,
            "emergency must downgrade core seed to scout role")
        XCTAssertTrue(result.decisions[0].reasonCodes.contains(
            "thermal-emergency-forces-scout"))
        XCTAssertTrue(result.decisions[0].reasonCodes.contains(
            "thermal-emergency-cools-temperature"))
        XCTAssertTrue(result.decisions[0].deterministic,
            "scout-resolved role is always deterministic")

        // Endpoint must actually see the downgraded decision the
        // runtime returned — the audit surface and the wire must agree.
        let routed = await endpoint.observedRoutedCalls()
        XCTAssertEqual(routed.count, 1)
        XCTAssertEqual(routed[0].decision.role, .scout)
        XCTAssertEqual(routed[0].decision, result.decisions[0],
            "endpoint-observed decision must byte-equal the "
            + "runtime-returned audit decision")
    }

    // MARK: - 3. Throttle pins core deterministic

    func testRoutedGenerationThrottlePinsCoreDeterministic() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .throttle)
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-throttle",
            seeds: [makeSeed("c1", role: .core)],
            plannedBudget: planned)

        XCTAssertEqual(result.decisions.count, 1)
        XCTAssertEqual(result.decisions[0].role, .core,
            "throttle is not an emergency — role not downgraded")
        XCTAssertTrue(result.decisions[0].deterministic,
            "throttle + core must pin deterministic=true")
        XCTAssertTrue(result.decisions[0].reasonCodes.contains(
            "thermal-throttle-forces-deterministic"))
    }

    // MARK: - 4. Minimal precision halves token budget

    func testRoutedGenerationMinimalPrecisionShrinksTokens() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(
            precision: .minimal, thermalGuardLevel: .nominal)
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-min",
            seeds: [makeSeed("c1", role: .core)],
            plannedBudget: planned)

        XCTAssertEqual(result.decisions.count, 1)
        // Default policy: coreMaxOutputTokens=1024,
        // minimalPrecisionTokenFraction=0.5 → 512.
        XCTAssertEqual(result.decisions[0].maxOutputTokens, 512,
            "default fraction 0.5 * 1024 = 512")
        XCTAssertTrue(result.decisions[0].reasonCodes.contains(
            "precision-minimal-reduces-tokens"))
    }

    // MARK: - 5. Decisions array parallel to seeds

    func testRoutedGenerationDecisionsParallelSeeds() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .throttle)
        let seeds = [
            makeSeed("a", role: .scout),
            makeSeed("b", role: .core),
            makeSeed("c", role: .scout),
        ]
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-multi",
            seeds: seeds,
            plannedBudget: planned)

        XCTAssertEqual(result.decisions.count, 3,
            "decisions.count must equal seeds.count")
        // Role alignment by seed index under throttle (no downgrade).
        XCTAssertEqual(result.decisions[0].role, .scout)
        XCTAssertEqual(result.decisions[1].role, .core)
        XCTAssertEqual(result.decisions[2].role, .scout)
        // Only the core seed picks up the deterministic pin reason.
        XCTAssertFalse(result.decisions[0].reasonCodes.contains(
            "thermal-throttle-forces-deterministic"))
        XCTAssertTrue(result.decisions[1].reasonCodes.contains(
            "thermal-throttle-forces-deterministic"))
        XCTAssertFalse(result.decisions[2].reasonCodes.contains(
            "thermal-throttle-forces-deterministic"))
    }

    // MARK: - 6. Candidates + endpoint visibility

    func testRoutedGenerationEndpointSeesEverySeed() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let seeds = [
            makeSeed("a", role: .scout),
            makeSeed("b", role: .core),
        ]
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-visibility",
            seeds: seeds,
            plannedBudget: planned)

        XCTAssertEqual(result.candidates.count, 2,
            "every seed must produce one generated candidate")
        let routed = await endpoint.observedRoutedCalls()
        let legacy = await endpoint.observedLegacyCalls()
        XCTAssertEqual(routed.count, 2,
            "budget-aware path must fire for both seeds")
        XCTAssertEqual(legacy.count, 0,
            "legacy path must not fire when routed path is available")
    }

    // MARK: - 7. Lifecycle integration — live thermal overrides plan

    func testRoutedGenerationLifecycleOverridesPlannedThermal() async throws {
        // Caller plans .nominal, lifecycle reader reports .critical →
        // prepareBudgetForTurn elevates routedBudget to .emergency,
        // which in turn downgrades the core seed to scout. This is the
        // full three-seam stitch: lifecycle → routed budget → decision.
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(
            lifecycle: lifecycle,
            organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-lifecycle",
            seeds: [makeSeed("c1", role: .core)],
            plannedBudget: planned)

        XCTAssertEqual(result.routedBudget?.thermalGuardLevel, .emergency,
            ".critical reader must elevate routed thermal to .emergency, "
            + "overriding the caller's .nominal plan")
        XCTAssertEqual(result.decisions[0].role, .scout,
            "emergency on routed budget must downgrade the core seed")
        XCTAssertTrue(result.decisions[0].reasonCodes.contains(
            "thermal-emergency-forces-scout"))

        // Double-check: the endpoint that ran on the wire saw the
        // same scout role, so the audit record and the adapter call
        // agree on the downgrade.
        let routed = await endpoint.observedRoutedCalls()
        XCTAssertEqual(routed.count, 1)
        XCTAssertEqual(routed[0].decision.role, .scout)
    }

    // MARK: - 8. Empty seeds throws

    func testRoutedGenerationEmptySeedsThrows() async {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .nominal)
        do {
            _ = try await runtime.generateCandidatesForTurn(
                sessionID: "s-empty",
                seeds: [],
                plannedBudget: planned)
            XCTFail("empty seeds must throw LoopError")
        } catch let error as QinaoLoop.LoopError {
            // Any loop-level rejection is acceptable; empty submission
            // is the canonical one but we don't pin the exact reason
            // string in case a future refactor reworks the validation
            // path — the surface contract is "empty seeds raises
            // QinaoLoop.LoopError".
            XCTAssertTrue(
                String(describing: error).contains("empty"),
                "expected empty-submission rejection, got: \(error)")
        } catch {
            XCTFail("expected QinaoLoop.LoopError, got: \(error)")
        }
    }

    // MARK: - 9. No-lifecycle byte-identity with planned budget

    func testRoutedGenerationNoLifecyclePreservesPlannedBudget() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let runtime = makeRuntime(lifecycle: nil, organEndpoint: endpoint)
        let planned = plannedBudget(thermalGuardLevel: .watch)
        let result = try await runtime.generateCandidatesForTurn(
            sessionID: "s-no-life",
            seeds: [makeSeed("c1", role: .core)],
            plannedBudget: planned)

        // Without a lifecycle, prepareBudgetForTurn is an identity;
        // routedBudget must round-trip byte-for-byte with the plan.
        // This is the same guarantee M69 ships at the lifecycle seam —
        // M78 must not introduce any side effect on top of it.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let routed = try XCTUnwrap(result.routedBudget,
            "plannedBudget non-nil → routedBudget non-nil")
        let a = try encoder.encode(planned)
        let b = try encoder.encode(routed)
        XCTAssertEqual(a, b,
            "no lifecycle → routedBudget byte-equal to plannedBudget")
    }
}
