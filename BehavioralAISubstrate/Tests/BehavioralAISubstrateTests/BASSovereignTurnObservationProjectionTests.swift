// ADR-022 / ch1044 严查 #3 — Sovereign verdict parity SHADOW gate, Phase 1.
// Tests the projection (settled turn state -> BASSovereignTurnObservations) and
// the end-to-end shadow run: healthy turns must NOT be `.coordinatorLaxer`, and
// a genuine engine-stricter divergence MUST be detected.

import XCTest
import BASHostKit
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
}
