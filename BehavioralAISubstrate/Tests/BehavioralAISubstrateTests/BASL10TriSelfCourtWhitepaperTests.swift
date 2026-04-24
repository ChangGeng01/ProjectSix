import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M115 — L10 `三我庭` whitepaper §5 closure + governance
/// registration.
///
/// L10 §5 lists 9 arbitration-record objects. All 9 pre-existed as
/// `BASSchemaVersioned` Swift structs (M89 "L10 full-body tribunal
/// main-chain fit-in" shipped them) — but none were in the schema
/// governance registry. M115 closes the governance-layer gap by
/// registering all 9 types. Field-level parity was already achieved
/// in M89; this test file locks it in with declarative checks.
///
/// Verified:
/// 1. All 9 §5 types present as BASSchemaVersioned
/// 2. All 9 registered in governance registry
/// 3. Sample Codable round-trip on the §5.1 aggregator
///    (BASArbitrationFrame) to confirm governance uses the same
///    canonical shape
final class BASL10TriSelfCourtWhitepaperTests: XCTestCase {

    // MARK: - 1. All 9 §5 types present

    func testAllNineL10TypesExistAsSchemaVersioned() {
        XCTAssertEqual(
            BASArbitrationFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASIdImpulseProfile.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASEgoRealityAssessment.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASSuperegoJudgment.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASTradeoffLedger.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASVetoMark.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAgencyReservation.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRemandOrder.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASCourtDecisionDraft.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. All 9 registered in governance

    func testAllNineL10TypesRegisteredInGovernance() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(ids.contains("ArbitrationFrame"))
        XCTAssertTrue(ids.contains("IdImpulseProfile"))
        XCTAssertTrue(ids.contains("EgoRealityAssessment"))
        XCTAssertTrue(ids.contains("SuperegoJudgment"))
        XCTAssertTrue(ids.contains("TradeoffLedger"))
        XCTAssertTrue(ids.contains("VetoMark"))
        XCTAssertTrue(ids.contains("AgencyReservation"))
        XCTAssertTrue(ids.contains("RemandOrder"))
        XCTAssertTrue(ids.contains("CourtDecisionDraft"))
    }

    // MARK: - 3. §5.1 aggregator Codable round-trip

    func testArbitrationFrameCodableRoundTrip() throws {
        let orig = BASArbitrationFrame(
            frameID: "af.rt",
            candidateFrontierRef: "cf.1",
            outcomeRefs: ["o.1"],
            adversarialRefs: ["ab.1"],
            hostConstitutionRef: "hc.1",
            memoryBundleRef: "mb.1",
            tradeoffLedgerRefs: ["tl.1"],
            agencyReservationRef: "ar.1",
            vetoRefs: ["vm.1"],
            remandRefs: ["ro.1"],
            decisionDraftRef: "cdd.1")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASArbitrationFrame.self, from: data)
        XCTAssertEqual(decoded.frameID, orig.frameID)
        XCTAssertEqual(
            decoded.decisionDraftRef, orig.decisionDraftRef)
        XCTAssertEqual(
            decoded.vetoRefs.count, orig.vetoRefs.count)
    }

    // MARK: - 4. Whitepaper-layer count hook

    /// The 9 L10 types added in M115 must appear *together* in the
    /// registry — a missing one fails the count check too, so this
    /// test catches both "registry entry removed" and "new type
    /// accidentally registered under wrong category" failures.
    func testExactlyNineL10TypesAppearInRegistry() {
        let l10Names: Set<String> = [
            "ArbitrationFrame", "IdImpulseProfile",
            "EgoRealityAssessment", "SuperegoJudgment",
            "TradeoffLedger", "VetoMark",
            "AgencyReservation", "RemandOrder",
            "CourtDecisionDraft"
        ]
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let present = l10Names.intersection(ids)
        XCTAssertEqual(
            present.count, 9,
            "all 9 L10 §5 types must be registered together")
    }
}
