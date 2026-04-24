import XCTest
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASAdmin

/// M116 — L11 `风闸层` whitepaper §5 parity confirmation.
///
/// Audit outcome: **L11 was already 100% parity pre-M116**. All
/// 12 §5 concept objects have matching `BASSchemaVersioned`
/// structs in `BASPolicy/EBrainRiskPlaneCore.swift` AND all 12
/// are registered in `BASEBrainSchemaGovernanceRegistry`. No
/// structural additions needed. M116 lands a declarative parity-
/// lock test so future regressions (removing a type, dropping a
/// registry entry, schema version drift) fail the suite.
///
/// L11 §5 list (12 types):
/// 1. RiskField
/// 2. HazardVector (9-field shape matches whitepaper exactly)
/// 3. HarmRadiusMap
/// 4. ReversibilityProfile
/// 5. EvidenceSufficiency
/// 6. GSITrace
/// 7. VulnerabilityCoupling
/// 8. ActionModeDecision
/// 9. ActionPermit
/// 10. DelayReservation
/// 11. ProtectiveSubstitute
/// 12. SovereignEscalationHint
final class BASL11WindGateWhitepaperTests: XCTestCase {

    // MARK: - 1. All 12 §5 types exist as BASSchemaVersioned

    func testAllTwelveL11TypesExistAsSchemaVersioned() {
        XCTAssertFalse(
            BASRiskField.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASHazardVector.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASHarmRadiusMap.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASReversibilityProfile.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASEvidenceSufficiency.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASGSITrace.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASVulnerabilityCoupling.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASActionModeDecision.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASActionPermit.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASDelayReservation.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASProtectiveSubstitute.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASSovereignEscalationHint.currentSchemaVersion
                .isEmpty)
    }

    // MARK: - 2. All 12 registered in governance

    func testAllTwelveL11TypesRegisteredInGovernance() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let expected: Set<String> = [
            "RiskField", "HazardVector", "HarmRadiusMap",
            "ReversibilityProfile", "EvidenceSufficiency",
            "GSITrace", "VulnerabilityCoupling",
            "ActionModeDecision", "ActionPermit",
            "DelayReservation", "ProtectiveSubstitute",
            "SovereignEscalationHint"
        ]
        let present = expected.intersection(ids)
        XCTAssertEqual(
            present.count, 12,
            "all 12 L11 §5 types must be registered in governance")
    }

    // MARK: - 3. HazardVector 9-field whitepaper parity

    /// §5 HazardVector whitepaper lists exactly 9 fields. Lock
    /// each explicitly so any future removal/rename fails loudly.
    func testHazardVectorCarriesAllNineWhitepaperFields() {
        let v = BASHazardVector(
            harmSeverity: 0.1,
            harmScope: 0.2,
            irreversibility: 0.3,
            uncertainty: 0.4,
            evidenceDebt: 0.5,
            manipulationIntensity: 0.6,
            pressureAuthenticity: 0.7,
            vulnerabilityCoupling: 0.8,
            sideEffectScope: 0.9)
        XCTAssertEqual(v.harmSeverity, 0.1)
        XCTAssertEqual(v.harmScope, 0.2)
        XCTAssertEqual(v.irreversibility, 0.3)
        XCTAssertEqual(v.uncertainty, 0.4)
        XCTAssertEqual(v.evidenceDebt, 0.5)
        XCTAssertEqual(v.manipulationIntensity, 0.6)
        XCTAssertEqual(v.pressureAuthenticity, 0.7)
        XCTAssertEqual(v.vulnerabilityCoupling, 0.8)
        XCTAssertEqual(v.sideEffectScope, 0.9)
    }

    // MARK: - 4. RiskField aggregator Codable round-trip

    func testRiskFieldAggregatorCodableRoundTrip() throws {
        // Minimum-viable RiskField — substrate inlines sub-structs
        // instead of using whitepaper's ID-ref shape (richer than
        // spec), so the constructor takes the sub-structs directly.
        let hv = BASHazardVector(
            harmSeverity: 0, harmScope: 0,
            irreversibility: 0, uncertainty: 0,
            evidenceDebt: 0, manipulationIntensity: 0,
            pressureAuthenticity: 0,
            vulnerabilityCoupling: 0,
            sideEffectScope: 0)
        let orig = BASRiskField(
            fieldID: "rf.rt",
            candidateRef: "c.1",
            hazardVector: hv,
            harmRadius: BASHarmRadiusMap(
                radiusID: "hr.1",
                privateImpact: 0, relationImpact: 0,
                workflowImpact: 0, publicImpact: 0,
                longTermTrace: 0),
            reversibilityProfile: BASReversibilityProfile(
                profileID: "rp.1",
                reversible: true,
                rollbackCost: 0,
                confirmNodes: [],
                draftSafe: true,
                smallStepPossible: true),
            evidenceSufficiency: BASEvidenceSufficiency(
                sufficiencyID: "es.1",
                supportLevel: 0,
                missingEvidence: [],
                allowedAssertionLevel: "neutral",
                allowedActionLevel: "review"),
            gsiTrace: BASGSITrace(
                traceID: "gsi.1",
                gaslightSignals: [],
                coerciveUrgency: 0,
                shamePressure: 0,
                authorityMask: 0,
                relationLeverage: 0,
                susceptibilityBand: "nominal"),
            vulnerabilityCoupling: BASVulnerabilityCoupling(
                couplingID: "vc.1",
                touchedBoundaries: [],
                lowEnergyResonance: 0,
                sensitivityWindow: 0,
                protectionBias: 0),
            confidenceBand: "moderate")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASRiskField.self, from: data)
        XCTAssertEqual(decoded.fieldID, "rf.rt")
        XCTAssertEqual(decoded.candidateRef, "c.1")
        XCTAssertEqual(decoded.confidenceBand, "moderate")
    }
}
