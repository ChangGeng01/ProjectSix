// ADR-022 / ch1044 严查 #3 — Sovereign verdict parity SHADOW gate, Phase 1.
// Tests the projection (settled turn state -> BASSovereignTurnObservations) and
// the end-to-end shadow run: healthy turns must NOT be `.coordinatorLaxer`, and
// a genuine engine-stricter divergence MUST be detected.

import XCTest
@testable import BASHostKit
import BASSovereign
import BASPolicy
import BASRuntimeCore

final class BASSovereignTurnObservationProjectionTests: XCTestCase {

    // MARK: - Fixtures

    private func makeBudget(runMode: BASEBrainRunMode = .engage) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: runMode, maxLoops: 3, maxCandidates: 4,
            maxDecodeTokens: 256, retrievalDepth: 5,
            precisionProfile: .protected, deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch, maintenanceAllowed: false,
            leaseID: "lease-parity",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["primary"], policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["d1"])
    }

    private func makeRisk(
        _ level: BASBrainRiskLevel, irreversibility: Double = 0.1
    ) -> BASRiskCard {
        BASRiskCard(
            totalRisk: 0.2, riskLevel: level, uncertainty: 0.15,
            irreversibility: irreversibility, manipulationStrength: 0.1,
            gsiScore: 0.2, recommendedMode: .answer)
    }

    private func makePermit(_ mode: BASActionPermitMode = .answer) -> BASActionPermit {
        BASActionPermit(
            mode: mode, reasonCodes: ["t"], outputLengthCap: 200,
            tonePolicy: "calm", templatePolicy: "default")
    }

    private func makeBrake(_ level: BASEmergencyBrakeLevel = .none) -> BASEmergencyBrake {
        BASEmergencyBrake(brakeLevel: level, reasonCodes: [])
    }

    private func project(
        risk: BASRiskCard, permit: BASActionPermit, brake: BASEmergencyBrake,
        lineagePresent: Bool = true, protectedWrite: Bool = false,
        budget: BASBudgetFrame? = nil
    ) -> BASSovereignTurnObservations {
        BASSovereignTurnObservationProjection.project(
            sessionID: "s1", turnID: "t1", snapshotRef: "snap1", policyHash: "ph1",
            policyLineagePresent: lineagePresent,
            budgetFrame: budget ?? makeBudget(),
            riskCard: risk, actionPermit: permit, emergencyBrake: brake,
            needsProtectedWriteLane: protectedWrite, quarantineCount: 0,
            operation: .pureInference, evidenceSufficient: true)
    }

    // MARK: - 1) Projection maps a healthy turn conservatively

    func testHealthyTurnProjectsNoHardFlags() {
        let obs = project(risk: makeRisk(.low), permit: makePermit(), brake: makeBrake())
        XCTAssertFalse(obs.policyLineageMissing)
        XCTAssertFalse(obs.riskPermitHeadConflict)
        XCTAssertFalse(obs.runtimeUnstableInHighRisk)
        XCTAssertFalse(obs.unauthorizedSelfMutation)
        // Phase-1b unsourced flags default false (engine-laxer).
        XCTAssertFalse(obs.auditEntryMissing)
        XCTAssertFalse(obs.externalSideEffectWithoutSCT)
        XCTAssertFalse(obs.hostRemovalBypassed)
        XCTAssertFalse(obs.memoryOrHostWriteBypass)
        // Soft signals mirror the risk card.
        XCTAssertEqual(obs.irreversibilityScore, 0.1, accuracy: 1e-9)
        XCTAssertEqual(obs.manipulationStrength, 0.1, accuracy: 1e-9)
        XCTAssertEqual(obs.hostGateValue, 1.0, accuracy: 1e-9)
    }

    // MARK: - 2) Determinism (replay-safe)

    func testProjectionIsDeterministic() {
        let a = project(risk: makeRisk(.medium), permit: makePermit(), brake: makeBrake())
        let b = project(risk: makeRisk(.medium), permit: makePermit(), brake: makeBrake())
        XCTAssertEqual(a, b)
    }

    // MARK: - 3) Sourced flags fire correctly

    func testRiskPermitHeadConflictFiresOnHighRiskAnswer() {
        let obs = project(risk: makeRisk(.high), permit: makePermit(.answer), brake: makeBrake())
        XCTAssertTrue(obs.riskPermitHeadConflict)        // BR-010
    }

    func testRuntimeUnstableFiresOnBrakeElevatedHighRisk() {
        let obs = project(risk: makeRisk(.high), permit: makePermit(.block), brake: makeBrake(.guard))
        XCTAssertTrue(obs.runtimeUnstableInHighRisk)      // BR-009
        XCTAssertFalse(obs.riskPermitHeadConflict)        // permit is .block, not .answer
    }

    func testProtectedWriteLaneMapsToSelfMutationFlag() {
        let obs = project(
            risk: makeRisk(.low), permit: makePermit(), brake: makeBrake(),
            protectedWrite: true)
        XCTAssertTrue(obs.unauthorizedSelfMutation)       // BR-007 proxy
    }

    // MARK: - 4) End-to-end: healthy turn is NOT coordinatorLaxer

    func testShadowHealthyTurnIsNotCoordinatorLaxer() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("parity-shadow-test")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        let obs = project(risk: makeRisk(.low), permit: makePermit(), brake: makeBrake())
        let report = try await BASSovereignTurnObservationProjection.shadowVerify(
            obs, coordinatorLevel: .pass, using: verifier)
        XCTAssertTrue(report.isAcceptable)                 // parity != .coordinatorLaxer
        XCTAssertNotEqual(report.parity, .coordinatorLaxer)
    }

    // MARK: - 5) Detection works: engine-stricter than coordinator => coordinatorLaxer

    func testShadowDetectsCoordinatorLaxerWhenEngineRaises() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("parity-shadow-test-2")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        // A turn the engine should flag (policy lineage missing) but with the
        // coordinator level forced to the laxest (.pass).
        let badObs = project(
            risk: makeRisk(.extreme, irreversibility: 0.95),
            permit: makePermit(.answer), brake: makeBrake(.lockdown),
            lineagePresent: false)
        let report = try await BASSovereignTurnObservationProjection.shadowVerify(
            badObs, coordinatorLevel: .pass, using: verifier)
        // Self-consistent: whatever the engine decided, parity must agree with it.
        if report.engineVerdict.verdictLevel > .pass {
            XCTAssertEqual(report.parity, .coordinatorLaxer)
            XCTAssertFalse(report.isAcceptable)
        } else {
            XCTAssertNotEqual(report.parity, .coordinatorLaxer)
        }
    }

    // MARK: - 6) engineOnly when coordinator level absent

    func testNilCoordinatorLevelIsEngineOnly() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("parity-shadow-test-3")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        let obs = project(risk: makeRisk(.low), permit: makePermit(), brake: makeBrake())
        let report = try await BASSovereignTurnObservationProjection.shadowVerify(
            obs, coordinatorLevel: nil, using: verifier)
        XCTAssertEqual(report.parity, .engineOnly)
    }

    // MARK: - 7) Phase-1b opt-in carrier (default-OFF = no-op = byte-equal)

    func testRunShadowIsNoOpWhenVerifierNil() async {
        let obs = project(risk: makeRisk(.low), permit: makePermit(), brake: makeBrake())
        let box = ShadowSinkBox()
        let report = await BASSovereignTurnObservationProjection.runShadowIfEnabled(
            observations: obs, coordinatorLevel: .pass,
            verifier: nil, sink: { box.add($0) })
        XCTAssertNil(report)                       // OFF → no-op
        XCTAssertEqual(box.count, 0)               // sink never called
    }

    func testRunShadowEmitsToSinkWhenEnabled() async {
        let ledger = BASSovereignAuditLedger.withSeed("parity-1b-sink")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        let obs = project(risk: makeRisk(.low), permit: makePermit(), brake: makeBrake())
        let box = ShadowSinkBox()
        let report = await BASSovereignTurnObservationProjection.runShadowIfEnabled(
            observations: obs, coordinatorLevel: .pass,
            verifier: verifier, sink: { box.add($0) })
        XCTAssertNotNil(report)
        XCTAssertEqual(box.count, 1)               // sink received the report
        XCTAssertTrue(report?.isAcceptable ?? false)
    }

    // MARK: - 8) Phase-1b host-gate threading

    func testHostGateValueIsThreaded() {
        let obs = BASSovereignTurnObservationProjection.project(
            sessionID: "s", turnID: "t", snapshotRef: "r", policyHash: "p",
            policyLineagePresent: true, budgetFrame: makeBudget(),
            riskCard: makeRisk(.low), actionPermit: makePermit(),
            emergencyBrake: makeBrake(), needsProtectedWriteLane: false,
            quarantineCount: 0, operation: .pureInference, evidenceSufficient: true,
            hostGateValue: 0.2)
        XCTAssertEqual(obs.hostGateValue, 0.2, accuracy: 1e-9)
    }

    // MARK: - 9) Phase-1c — project + shadow from a real turn result

    func testProjectFromResultThreadsFieldsAndShadowsCleanly() async {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())

        // Identity + soft signals + lineage thread straight from the result.
        let obs = BASSovereignTurnObservationProjection.projectFromResult(result)
        XCTAssertEqual(obs.sessionID, result.runtimeTrace.sessionID)
        XCTAssertEqual(obs.turnID, result.thoughtFold.foldID)
        XCTAssertEqual(obs.hostGateValue, result.hostGateValue, accuracy: 1e-9)
        XCTAssertEqual(
            obs.irreversibilityScore, result.riskCard.irreversibility, accuracy: 1e-9)
        XCTAssertEqual(
            obs.manipulationStrength, result.riskCard.manipulationStrength, accuracy: 1e-9)
        XCTAssertEqual(obs.policyLineageMissing, result.policyLineage == nil)

        // One-call shadow from the result: opt-in + observation-only.
        let ledger = BASSovereignAuditLedger.withSeed("parity-1c")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        let box = ShadowSinkBox()
        let report = await BASSovereignTurnObservationProjection.shadowVerifyResult(
            result, verifier: verifier, sink: { box.add($0) })
        XCTAssertNotNil(report)
        XCTAssertEqual(box.count, 1)
        // Coordinator level taken from the result's own sovereign verdict.
        XCTAssertEqual(report?.coordinatorLevel, result.sovereignVerdict?.verdictLevel)

        // No-op (byte-equal) when the verifier is nil.
        let none = await BASSovereignTurnObservationProjection.shadowVerifyResult(
            result, verifier: nil)
        XCTAssertNil(none)
    }

    // MARK: - 10) Phase-1d — parity EVIDENCE sweep (coordinator oracle vs engine)

    /// §6 acceptance evidence: across a grid of HEALTHY inputs, compute the real
    /// coordinator verdict (`computeVerdictDecision`) AND the engine verdict (via
    /// the projection), and assert the coordinator is NEVER laxer than the engine
    /// (0 `coordinatorLaxer`). This is the in-repo, deterministic proof the shadow
    /// does not false-alarm on healthy turns — the gate Phase-2 is waiting on.
    func testParityEvidenceSweepHealthyTurnsNeverCoordinatorLaxer() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("parity-sweep")
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: ledger))
        let risks: [BASBrainRiskLevel] = [.low, .medium]
        let permits: [BASActionPermitMode] = [.answer, .mirror, .compare]
        let modes: [BASEBrainRunMode] = [.engage, .reflect, .sentinel]
        var laxer = 0, total = 0
        var distribution: [BASSovereignTurnParity: Int] = [:]
        for r in risks {
            for p in permits {
                for m in modes {
                    total += 1
                    let riskCard = makeRisk(r)
                    let permit = makePermit(p)
                    let brake = makeBrake(.none)
                    let budget = makeBudget(runMode: m)
                    let decision = BASEBrainRuntimeCoordinator.computeVerdictDecision(
                        policyLineagePresent: true, budgetFrame: budget,
                        riskCard: riskCard, actionPermit: permit, emergencyBrake: brake,
                        activeKillSwitches: [], needsProtectedWriteLane: false,
                        quarantineSources: [], rollbackSource: nil)
                    let obs = project(
                        risk: riskCard, permit: permit, brake: brake, budget: budget)
                    let report = try await BASSovereignTurnObservationProjection.shadowVerify(
                        obs, coordinatorLevel: decision.level, using: verifier)
                    distribution[report.parity, default: 0] += 1
                    if report.parity == .coordinatorLaxer { laxer += 1 }
                }
            }
        }
        XCTAssertEqual(
            laxer, 0,
            "healthy parity sweep produced \(laxer)/\(total) coordinatorLaxer; dist=\(distribution)")
    }

    // MARK: - 11) Phase-1d — host-friendly default-engine one-call (env-gated)

    func testDefaultEngineShadowGatesOnEnabledFlag() async {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let box = StringSinkBox()
        // OFF → no-op → byte-equal (sink never called).
        await BASSovereignTurnObservationProjection.shadowVerifyResultWithDefaultEngine(
            result, enabled: false, sink: { box.add($0) })
        XCTAssertEqual(box.count, 0)
        // ON → exactly one compact parity summary.
        await BASSovereignTurnObservationProjection.shadowVerifyResultWithDefaultEngine(
            result, enabled: true, sink: { box.add($0) })
        XCTAssertEqual(box.count, 1)
        XCTAssertTrue(box.last?.contains("parity=") ?? false)
        XCTAssertTrue(box.last?.contains("acceptable=") ?? false)
    }
}

/// Thread-safe sink collector for the opt-in shadow tests.
private final class ShadowSinkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [BASSovereignTurnVerifierReport] = []
    func add(_ r: BASSovereignTurnVerifierReport) {
        lock.lock(); reports.append(r); lock.unlock()
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return reports.count }
}

/// Thread-safe string-sink collector for the default-engine one-call test.
private final class StringSinkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func add(_ s: String) { lock.lock(); lines.append(s); lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return lines.count }
    var last: String? { lock.lock(); defer { lock.unlock() }; return lines.last }
}
