import XCTest
@testable import BASMemory
@testable import BASObservability
@testable import BASRuntimeCore
@testable import BASAdmin

/// M118 — L13 `蜕变炉` whitepaper §5 + §4 organ-schema closure
/// tests.
///
/// L13 §5 lists 12 key objects. All 12 were **already in the
/// governance registry pre-M118** (shipped by M13-M80 era
/// milestones):
/// 1. ExperienceCandidate
/// 2. UpdateTicket
/// 3. RuleCandidate
/// 4. HostChangeCandidate
/// 5. WorkflowCandidate
/// 6. GuardTemplateCandidate
/// 7. BiasRecord
/// 8. ShadowTrialRecord
/// 9. VersionDelta
/// 10. RetractionOrder
/// 11. LearningExportBundle
/// 12. EvolutionSeal
///
/// §4 also describes 12 organs; 2 of them have substrate-side
/// schema types shipped by M94:
/// - Version Arboretum → `BASVersionArboretum` + `BASArboretumDelta`
/// - Retraction Furnace → `BASRetractionFurnace` +
///   `BASRetractionFurnaceEntry`
///
/// M94 added the schemas but didn't register them (M94 predates
/// the 3-site sync discipline from M106+). M118 closes the
/// governance-registration gap for all 4 M94 types + locks §5
/// with declarative parity tests.
final class BASL13EvolutionFurnaceWhitepaperTests: XCTestCase {

    // MARK: - 1. All 12 §5 types exist as BASSchemaVersioned

    func testAllTwelveSection5TypesExist() {
        XCTAssertFalse(
            BASExperienceCandidate.currentSchemaVersion
                .isEmpty)
        XCTAssertFalse(
            BASUpdateTicket.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASRuleCandidate.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASHostChangeCandidate.currentSchemaVersion
                .isEmpty)
        XCTAssertFalse(
            BASWorkflowCandidate.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASGuardTemplateCandidate.currentSchemaVersion
                .isEmpty)
        XCTAssertFalse(
            BASBiasRecord.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASShadowTrialRecord.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASVersionDelta.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASRetractionOrder.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASLearningExportBundle.currentSchemaVersion
                .isEmpty)
        XCTAssertFalse(
            BASEvolutionSeal.currentSchemaVersion.isEmpty)
    }

    // MARK: - 2. M94 §4 organ schemas exist

    func testM94OrganSchemasExist() {
        XCTAssertFalse(
            BASVersionArboretum.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASArboretumDelta.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASRetractionFurnace.currentSchemaVersion.isEmpty)
        XCTAssertFalse(
            BASRetractionFurnaceEntry.currentSchemaVersion
                .isEmpty)
    }

    // MARK: - 3. Governance registry coverage for §5

    func testAllTwelveSection5TypesRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let expected: Set<String> = [
            "ExperienceCandidate", "UpdateTicket",
            "RuleCandidate", "HostChangeCandidate",
            "WorkflowCandidate", "GuardTemplateCandidate",
            "BiasRecord", "ShadowTrialRecord",
            "VersionDelta", "RetractionOrder",
            "LearningExportBundle", "EvolutionSeal"
        ]
        let present = expected.intersection(ids)
        XCTAssertEqual(
            present.count, 12,
            "all 12 L13 §5 types must be in governance")
    }

    // MARK: - 4. Governance registry coverage for M94 organ schemas

    func testAllFourM94OrganSchemasRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let expected: Set<String> = [
            "VersionArboretum", "ArboretumDelta",
            "RetractionFurnace", "RetractionFurnaceEntry"
        ]
        let present = expected.intersection(ids)
        XCTAssertEqual(
            present.count, 4,
            "all 4 M94 L13 §4 organ schemas must be registered")
    }

    // MARK: - 5. Exchange-compatibility sample (EvolutionSeal)

    /// `BASEvolutionSeal` is the sovereign-gated seal §5's spec
    /// emphasizes — a round-trip confirms the governance-audit
    /// critical type survives canonical JSON.
    func testEvolutionSealCodableRoundTrip() throws {
        let orig = BASEvolutionSeal(
            sealID: "seal.rt",
            candidateRef: "cand.rt",
            allowedScope: "shadow",
            trialRequired: true,
            approvalRequirements: ["host", "sovereign"],
            signature: "sig.rt",
            approvalState: "pending")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASEvolutionSeal.self, from: data)
        XCTAssertEqual(decoded.sealID, "seal.rt")
        XCTAssertEqual(decoded.candidateRef, "cand.rt")
        XCTAssertEqual(
            decoded.approvalRequirements,
            ["host", "sovereign"])
    }
}
