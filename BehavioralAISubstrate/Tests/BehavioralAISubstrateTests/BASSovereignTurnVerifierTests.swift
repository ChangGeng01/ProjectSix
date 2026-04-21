import XCTest
import BASRuntimeCore
@testable import BASSovereign

/// M9.3 — parity-invariant tests for `BASSovereignTurnVerifier`.
///
/// Every test fixes an `Observations` primitive record, runs it
/// through the real `BASSovereignVerdictEngine`, and asserts the
/// engine verdict matches the expected BR-rule signature and parity
/// status against a synthetic coordinator level.
final class BASSovereignTurnVerifierTests: XCTestCase {

    // MARK: - Fixture helpers

    private func makeEngine() -> (
        engine: BASSovereignVerdictEngine,
        ledger: BASSovereignAuditLedger
    ) {
        let ledger = BASSovereignAuditLedger.withSeed("verifier-test-secret")
        let engine = BASSovereignVerdictEngine(
            ledger: ledger,
            now: { Date(timeIntervalSince1970: 1_714_000_000) }
        )
        return (engine, ledger)
    }

    private func cleanObservations(
        sessionID: String = "sess.m9",
        turnID: String = "turn.m9",
        operation: BASSovereignVerdictEngine.OperationDomain = .pureInference
    ) -> BASSovereignTurnObservations {
        BASSovereignTurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m9",
            policyHash: BASSovereignTrustConstants.builtInPolicyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.0,
            manipulationStrength: 0.0,
            uncertaintyScore: 0.0,
            gsiScore: 0.0,
            hostGateValue: 0.9,
            quarantineCount: 0,
            runMode: .engage,
            emergencyBrakeLevel: .none,
            operation: operation,
            evidenceSufficient: true
        )
    }

    // MARK: - Happy path

    /// A clean turn produces a `.pass` engine verdict and `.match`
    /// parity when the coordinator agrees.
    func testCleanTurnPasses() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let report = try await verifier.verify(
            cleanObservations(),
            coordinatorLevel: .pass)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .pass)
        XCTAssertEqual(report.parity, .match)
        XCTAssertTrue(report.isAcceptable)
    }

    /// With no coordinator verdict, parity is `.engineOnly`.
    func testEngineOnlyWhenNoCoordinatorVerdict() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let report = try await verifier.verify(
            cleanObservations(),
            coordinatorLevel: nil)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .pass)
        XCTAssertEqual(report.parity, .engineOnly)
    }

    // MARK: - Hard-rule BR coverage (subset derived from turn result)

    /// BR-006: missing policy lineage fires `policyBundleTampered`,
    /// minimum level `.deadStop`.
    func testPolicyLineageMissingFiresBR006() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: true,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .deadStop)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .deadStop)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-006"))
        XCTAssertEqual(report.parity, .match)
    }

    /// BR-012: missing audit entry fires `auditAppendFailed`,
    /// minimum level `.deadStop`.
    func testAuditEntryMissingFiresBR012() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: true,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .deadStop)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .deadStop)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-012"))
    }

    /// BR-009: runtime unstable under high risk fires `.shadowLock`
    /// minimum; the actual verdict may be higher via soft signals.
    func testRuntimeUnstableFiresBR009() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .shadowLock)
        XCTAssertGreaterThanOrEqual(
            report.engineVerdict.verdictLevel, .shadowLock)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-009"))
    }

    /// BR-010: permit head conflict fires `.throttle` minimum.
    func testRiskPermitHeadConflictFiresBR010() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: true,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .throttle)
        XCTAssertGreaterThanOrEqual(
            report.engineVerdict.verdictLevel, .throttle)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-010"))
    }

    /// BR-003: external side effect without SCT fires `.deadStop`.
    func testExternalSideEffectWithoutSCTFiresBR003() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations(operation: .toolWrite)
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: true,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.5, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0.5,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .toolWrite, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .deadStop)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .deadStop)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-003"))
    }

    /// BR-005: host removal bypassed fires `.quarantine`.
    func testHostRemovalBypassedFiresBR005() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: true,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .hostMutate, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .quarantine)
        XCTAssertGreaterThanOrEqual(
            report.engineVerdict.verdictLevel, .quarantine)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-005"))
    }

    /// BR-007: unauthorized self-mutation fires `.deadStop`.
    func testUnauthorizedSelfMutationFiresBR007() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations(operation: .rulePromotion)
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: true,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .rulePromotion, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .deadStop)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .deadStop)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-007"))
    }

    /// BR-004: memory/host write bypass fires `.memoryFreeze`.
    func testMemoryWriteBypassFiresBR004() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations(operation: .memoryPromote)
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: true,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .memoryPromote, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .memoryFreeze)
        XCTAssertGreaterThanOrEqual(
            report.engineVerdict.verdictLevel, .memoryFreeze)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-004"))
    }

    // MARK: - Evidence-upgrade path (§12.3)

    /// Irreversible op + high GSI + insufficient evidence upgrades
    /// the verdict to at least `.toolCut` even absent any BR-rule hit.
    func testIrreversibleOpWithInsufficientEvidenceUpgrades() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations(operation: .toolWrite)
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0.85,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .toolWrite, evidenceSufficient: false
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .toolCut)
        XCTAssertGreaterThanOrEqual(
            report.engineVerdict.verdictLevel, .toolCut)
        XCTAssertTrue(report.engineVerdict.reasonCodes.contains("BR-008"))
    }

    // MARK: - Soft-signal derivation

    /// High manipulation strength alone (no hard-rule hit) should
    /// push the engine above `.pass` via the lex-order §12.2 walk.
    func testHighManipulationPushesAbovePass() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0.9,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        let report = try await verifier.verify(obs, coordinatorLevel: .toolCut)
        XCTAssertGreaterThan(report.engineVerdict.verdictLevel, .pass)
    }

    // MARK: - Parity invariants

    /// Coordinator being stricter than engine is ACCEPTABLE — the
    /// report is still `isAcceptable == true`.
    func testCoordinatorStricterIsAcceptable() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        // Clean obs → engine says .pass; force coordinator to .rollback.
        let report = try await verifier.verify(
            cleanObservations(),
            coordinatorLevel: .rollback)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .pass)
        XCTAssertEqual(report.parity, .coordinatorStricter)
        XCTAssertTrue(report.isAcceptable)
    }

    /// Coordinator being laxer than engine is the fail-closed signal:
    /// `isAcceptable == false`, parity `.coordinatorLaxer`.
    func testCoordinatorLaxerIsFailClosed() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: true,   // → engine deadStop
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0, manipulationStrength: 0,
            uncertaintyScore: 0, gsiScore: 0,
            hostGateValue: 0.9, quarantineCount: 0,
            runMode: .engage, emergencyBrakeLevel: .none,
            operation: .pureInference, evidenceSufficient: true
        )
        // Coordinator wrongly says .pass while engine demands deadStop.
        let report = try await verifier.verify(obs, coordinatorLevel: .pass)
        XCTAssertEqual(report.engineVerdict.verdictLevel, .deadStop)
        XCTAssertEqual(report.parity, .coordinatorLaxer)
        XCTAssertFalse(report.isAcceptable)
    }

    // MARK: - Determinism

    /// Same observations + same time source → byte-equal verdict
    /// level, reason-code set, and revoked-permissions set.
    func testDeterministicOnSameObservations() async throws {
        let (engine, _) = makeEngine()
        let verifier = BASSovereignTurnVerifier(engine: engine)
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: true,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.3, manipulationStrength: 0.5,
            uncertaintyScore: 0.2, gsiScore: 0.4,
            hostGateValue: 0.8, quarantineCount: 1,
            runMode: .engage, emergencyBrakeLevel: .caution,
            operation: .toolRead, evidenceSufficient: true
        )
        let first = try await verifier.verify(obs, coordinatorLevel: nil)
        let second = try await verifier.verify(obs, coordinatorLevel: nil)
        XCTAssertEqual(first.engineVerdict.verdictLevel,
                       second.engineVerdict.verdictLevel)
        XCTAssertEqual(Set(first.engineVerdict.reasonCodes),
                       Set(second.engineVerdict.reasonCodes))
        XCTAssertEqual(Set(first.engineVerdict.revokedPermissions),
                       Set(second.engineVerdict.revokedPermissions))
    }

    // MARK: - Static context helper (pure)

    /// `makeContext` is pure — no actor hops, no ledger write — and
    /// must produce the same `VerdictContext` fields as what the
    /// verifier hands to the engine.
    func testMakeContextIsPureAndReflectsObservations() throws {
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: "sess.ctx", turnID: "turn.ctx",
            snapshotRef: "snap.ctx", policyHash: "policy.ctx",
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.4, manipulationStrength: 0.6,
            uncertaintyScore: 0.3, gsiScore: 0.2,
            hostGateValue: 0.4, quarantineCount: 2,
            runMode: .recovery, emergencyBrakeLevel: .guard,
            operation: .hostMutate, evidenceSufficient: false
        )
        let ctx = BASSovereignTurnVerifier.makeContext(from: obs)
        XCTAssertEqual(ctx.sessionID, "sess.ctx")
        XCTAssertEqual(ctx.turnID, "turn.ctx")
        XCTAssertEqual(ctx.operation, .hostMutate)
        XCTAssertEqual(ctx.snapshotRef, "snap.ctx")
        XCTAssertEqual(ctx.policyHash, "policy.ctx")
        XCTAssertFalse(ctx.evidenceSufficient)
        XCTAssertTrue(ctx.hardObservations.runtimeUnstableInHighRisk)
        XCTAssertEqual(ctx.softSignals.irreversibleHarm, 0.4, accuracy: 1e-9)
        XCTAssertEqual(ctx.softSignals.manipulationIntrusion, 0.6, accuracy: 1e-9)
        XCTAssertGreaterThan(ctx.softSignals.integrity, 0.0) // host gate < 0.5
        XCTAssertGreaterThan(ctx.softSignals.runtimeInstability, 0.0) // brake guard
        XCTAssertGreaterThan(ctx.softSignals.memoryContamination, 0.0) // quarantines
    }

    // MARK: - Parity static helper

    /// Parity static helper is pure — tested directly without an
    /// engine instance.
    func testParityStaticHelper() {
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: nil, engine: .pass),
            .engineOnly)
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .pass, engine: .pass),
            .match)
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .rollback, engine: .pass),
            .coordinatorStricter)
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .pass, engine: .rollback),
            .coordinatorLaxer)
    }
}
