import XCTest
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASAdmin

/// M113 — L8 `海马井` whitepaper §5 closure tests.
///
/// L8 §5 lists 12 concept objects. Pre-M113 substrate had 11/12
/// present (MemoryAtom / EpisodeArc / TemperatureProfile /
/// ProvenanceSeal / ConflictCluster / ReplayFrame / ForgetCascade
/// / MemoryBundle / SanctumEntry / QuarantineRecord /
/// ContinuityAnchor). The one gap: **PromotionPetition** (no
/// whitepaper counterpart existed in code).
///
/// M113 adds `BASMemoryPromotionPetition` with its 7 whitepaper-
/// literal fields + 5-case approval-state enum. Reuses the
/// existing `BASMemoryTemperatureBand` enum (whitepaper §4.2
/// parity was already achieved long ago with hot/warm/cold/sealed
/// /quarantine).
final class BASL8HippocampalWellWhitepaperTests: XCTestCase {

    // MARK: - 1. All 12 §5 types present

    func testAllTwelveL8TypesExistAsSchemaVersioned() {
        XCTAssertEqual(
            BASMemoryAtom.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryEpisodeArc.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryTemperatureProfile.currentSchemaVersion,
            "1.0.0")
        XCTAssertEqual(
            BASMemoryProvenanceSeal.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryConflictCluster.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryPromotionPetition.currentSchemaVersion,
            "1.0.0")
        XCTAssertEqual(
            BASMemoryReplayFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryForgetCascade.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryBundle.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemorySanctumEntry.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryQuarantineRecord.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMemoryContinuityAnchor.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. BASMemoryPromotionPetition fields

    func testPromotionPetitionBasicFields() {
        let p = BASMemoryPromotionPetition(
            petitionID: "p.1",
            targetMemoryRef: "mem.alpha",
            fromBand: .warm,
            toBand: .hot,
            evidenceRefs: ["ev.1", "ev.2"],
            repetitionScore: 0.7,
            hostRelevance: 0.8,
            approvalState: .reviewing)
        XCTAssertEqual(p.petitionID, "p.1")
        XCTAssertEqual(p.targetMemoryRef, "mem.alpha")
        XCTAssertEqual(p.fromBand, .warm)
        XCTAssertEqual(p.toBand, .hot)
        XCTAssertEqual(p.evidenceRefs, ["ev.1", "ev.2"])
        XCTAssertEqual(p.repetitionScore, 0.7)
        XCTAssertEqual(p.hostRelevance, 0.8)
        XCTAssertEqual(p.approvalState, .reviewing)
    }

    // MARK: - 3. Score clamping + trim

    func testPromotionPetitionClampsScores() {
        let p = BASMemoryPromotionPetition(
            petitionID: "  p.2  ",
            targetMemoryRef: "  mem  ",
            fromBand: .cold,
            toBand: .warm,
            repetitionScore: 1.5,
            hostRelevance: -0.3)
        XCTAssertEqual(p.petitionID, "p.2")
        XCTAssertEqual(p.targetMemoryRef, "mem")
        XCTAssertEqual(p.repetitionScore, 1.0)
        XCTAssertEqual(p.hostRelevance, 0.0)
    }

    // MARK: - 4. Approval state enum

    func testApprovalStateHasFiveWhitepaperCases() {
        let expected: Set<String> = [
            "pending", "reviewing",
            "approved", "rejected", "deferred"
        ]
        XCTAssertEqual(
            Set(BASMemoryPromotionApprovalState.allCases
                .map(\.rawValue)),
            expected)
    }

    // MARK: - 5. Reuse existing BASMemoryTemperatureBand

    func testBandEnumMatchesWhitepaperFiveCases() {
        let expected: Set<String> = [
            "hot", "warm", "cold", "sealed", "quarantine"
        ]
        XCTAssertEqual(
            Set(BASMemoryTemperatureBand.allCases
                .map(\.rawValue)),
            expected)
    }

    // MARK: - 6. Codable round-trip

    func testPromotionPetitionCodableRoundTrip() throws {
        let orig = BASMemoryPromotionPetition(
            petitionID: "p.rt",
            targetMemoryRef: "mem.rt",
            fromBand: .sealed,
            toBand: .cold,
            evidenceRefs: ["ev.a"],
            repetitionScore: 0.4,
            hostRelevance: 0.3,
            approvalState: .approved)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASMemoryPromotionPetition.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 7. Registry membership

    func testPromotionPetitionRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(
            ids.contains("MemoryPromotionPetition"))
    }
}
