import XCTest
@testable import BASOrchestration

/// M471-M475 (chapter 一百二十三 / Stream A β) — Kunlun memory +
/// equilibrium schema tests.
final class BASKunlunMemoryEquilibriumTests: XCTestCase {

    // MARK: - M471 BASJadeCasketSnapshot

    func testJadeCasketSchemaVersion() {
        XCTAssertEqual(
            BASJadeCasketSnapshot.currentSchemaVersion, "1.0.0")
    }

    func testJadeCasketHonorsAllJadeCanonInvariants() {
        let valid = BASJadeCasketSnapshot(
            snapshotID: "s1",
            foldRefs: ["f1"],
            integrityHash: "sha256:abc",
            sourceRiverRef: "river-1",
            restoreGateRef: "gate-1",
            rollbackWritRef: "writ-1")
        XCTAssertTrue(valid.honorsJadeCanonInvariants)
    }

    func testJadeCasketEmptyHashViolatesInvariant() {
        let invalid = BASJadeCasketSnapshot(
            snapshotID: "s2",
            foldRefs: ["f"],
            integrityHash: "",
            sourceRiverRef: "river",
            restoreGateRef: "gate",
            rollbackWritRef: "writ")
        XCTAssertFalse(invalid.honorsJadeCanonInvariants,
                       "empty integrityHash violates §4.2 无签名不进门")
    }

    func testJadeCasketEmptySourceViolatesInvariant() {
        let invalid = BASJadeCasketSnapshot(
            snapshotID: "s3",
            foldRefs: ["f"],
            integrityHash: "h",
            sourceRiverRef: "",
            restoreGateRef: "gate",
            rollbackWritRef: "writ")
        XCTAssertFalse(invalid.honorsJadeCanonInvariants,
                       "empty sourceRiverRef violates §4.2 无来源不成玉")
    }

    func testJadeCasketEmptyRestoreGateViolatesInvariant() {
        let invalid = BASJadeCasketSnapshot(
            snapshotID: "s4",
            foldRefs: ["f"],
            integrityHash: "h",
            sourceRiverRef: "r",
            restoreGateRef: "",
            rollbackWritRef: "w")
        XCTAssertFalse(invalid.honorsJadeCanonInvariants,
                       "empty restoreGateRef violates §4.2 无回放不升格")
    }

    func testJadeCasketEmptyRollbackViolatesInvariant() {
        let invalid = BASJadeCasketSnapshot(
            snapshotID: "s5",
            foldRefs: ["f"],
            integrityHash: "h",
            sourceRiverRef: "r",
            restoreGateRef: "g",
            rollbackWritRef: "")
        XCTAssertFalse(invalid.honorsJadeCanonInvariants,
                       "empty rollbackWritRef violates §4.2 无撤销路径不得长期生效")
    }

    func testJadeCasketRoundTripCodable() throws {
        let casket = BASJadeCasketSnapshot(
            snapshotID: "rt",
            foldRefs: ["f1", "f2"],
            integrityHash: "h",
            sourceRiverRef: "r",
            restoreGateRef: "g",
            rollbackWritRef: "w")
        let data = try JSONEncoder().encode(casket)
        let decoded = try JSONDecoder()
            .decode(BASJadeCasketSnapshot.self, from: data)
        XCTAssertEqual(casket, decoded)
    }

    // MARK: - M472 BASYaochiMemoryLayer

    func testYaochiMemoryLayerSchemaVersion() {
        XCTAssertEqual(
            BASYaochiMemoryLayer.currentSchemaVersion, "1.0.0")
    }

    func testYaochiAnchorInvariantWithSanctumPolicy() {
        let valid = BASYaochiMemoryLayer(
            layerID: "yaochi",
            memoryRefs: ["m1"],
            sanctumPolicy: "yaochi-strict",
            revealConditions: ["host-recall"],
            humanAnchorRequired: true,
            sovereignGateRequired: true)
        XCTAssertTrue(valid.honorsAnchorInvariant)
    }

    func testYaochiAnchorInvariantViolatedWhenSanctumWithoutAnchor() {
        let invalid = BASYaochiMemoryLayer(
            layerID: "yaochi-bad",
            memoryRefs: ["m"],
            sanctumPolicy: "yaochi-strict",
            revealConditions: [],
            humanAnchorRequired: false,
            sovereignGateRequired: false)
        XCTAssertFalse(invalid.honorsAnchorInvariant,
                       "non-empty sanctum policy without host anchor violates §5.8")
    }

    func testYaochiInvariantTriviallyHonoredWhenNoSanctumPolicy() {
        let layer = BASYaochiMemoryLayer(
            layerID: "open",
            memoryRefs: [],
            sanctumPolicy: "",
            revealConditions: [],
            humanAnchorRequired: false,
            sovereignGateRequired: false)
        XCTAssertTrue(layer.honorsAnchorInvariant,
                      "empty sanctum policy → anchor not required")
    }

    func testYaochiRoundTripCodable() throws {
        let layer = BASYaochiMemoryLayer(
            layerID: "rt",
            memoryRefs: ["m"],
            sanctumPolicy: "policy",
            revealConditions: ["c1"],
            humanAnchorRequired: true,
            sovereignGateRequired: false)
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder()
            .decode(BASYaochiMemoryLayer.self, from: data)
        XCTAssertEqual(layer, decoded)
    }

    // MARK: - M473 BASTianhengProfile (天衡庭)

    func testTianhengSchemaVersion() {
        XCTAssertEqual(
            BASTianhengProfile.currentSchemaVersion, "1.0.0")
    }

    func testTianhengAllScoresClampTo01() {
        let high = BASTianhengProfile(
            profileID: "h",
            idClaims: [], egoConstraints: [], superegoClaims: [],
            centerBias: 1.5,
            dignityFloor: 1.5,
            agencyFloor: 1.5,
            imbalanceCodes: [])
        XCTAssertEqual(high.centerBias, 1.0)
        XCTAssertEqual(high.dignityFloor, 1.0)
        XCTAssertEqual(high.agencyFloor, 1.0)
        let low = BASTianhengProfile(
            profileID: "l",
            idClaims: [], egoConstraints: [], superegoClaims: [],
            centerBias: -0.5,
            dignityFloor: -0.5,
            agencyFloor: -0.5,
            imbalanceCodes: [])
        XCTAssertEqual(low.centerBias, 0)
        XCTAssertEqual(low.dignityFloor, 0)
        XCTAssertEqual(low.agencyFloor, 0)
    }

    func testTianhengTrimsAllArrays() {
        let bal = BASTianhengProfile(
            profileID: "x",
            idClaims: ["want", "  "],
            egoConstraints: ["plan"],
            superegoClaims: ["should", ""],
            centerBias: 0.7,
            dignityFloor: 0.5,
            agencyFloor: 0.5,
            imbalanceCodes: ["id-overweight"])
        XCTAssertEqual(bal.idClaims, ["want"])
        XCTAssertEqual(bal.egoConstraints, ["plan"])
        XCTAssertEqual(bal.superegoClaims, ["should"])
        XCTAssertEqual(bal.imbalanceCodes, ["id-overweight"])
    }

    func testTianhengRoundTripCodable() throws {
        let bal = BASTianhengProfile(
            profileID: "rt",
            idClaims: ["a"], egoConstraints: ["b"],
            superegoClaims: ["c"],
            centerBias: 0.6,
            dignityFloor: 0.4,
            agencyFloor: 0.5,
            imbalanceCodes: ["i"])
        let data = try JSONEncoder().encode(bal)
        let decoded = try JSONDecoder()
            .decode(BASTianhengProfile.self, from: data)
        XCTAssertEqual(bal, decoded)
    }

    // MARK: - M474 BASJadePermitGrade

    func testJadePermitGradeSchemaVersion() {
        XCTAssertEqual(
            BASJadePermitGrade.currentSchemaVersion, "1.0.0")
    }

    func testJadePermitGradeNamedThresholdIsHalf() {
        XCTAssertEqual(
            BASJadePermitGrade.gateMandatoryScoreThreshold,
            0.5, accuracy: 0.001)
    }

    func testJadePermitGradeAllScoresClamp() {
        let g = BASJadePermitGrade(
            gradeID: "g",
            actionPermitRef: "p",
            clarityScore: 1.5,
            reversibilityScore: -0.5,
            provenanceScore: 0.7,
            gateRequirements: [],
            revocationPath: "")
        XCTAssertEqual(g.clarityScore, 1.0)
        XCTAssertEqual(g.reversibilityScore, 0.0)
        XCTAssertEqual(g.provenanceScore, 0.7, accuracy: 0.001)
    }

    func testJadePermitGradeHonorsGateInvariantWhenAllAboveThreshold() {
        let pristine = BASJadePermitGrade(
            gradeID: "ok",
            actionPermitRef: "p",
            clarityScore: 0.9,
            reversibilityScore: 0.9,
            provenanceScore: 0.9,
            gateRequirements: [],
            revocationPath: "")
        XCTAssertTrue(pristine.honorsGateInvariant,
                      "all scores above threshold → no gate required")
    }

    func testJadePermitGradeRequiresGateWhenScoreBelowThreshold() {
        let lowClarity = BASJadePermitGrade(
            gradeID: "low",
            actionPermitRef: "p",
            clarityScore: 0.3,
            reversibilityScore: 0.9,
            provenanceScore: 0.9,
            gateRequirements: [],
            revocationPath: "")
        XCTAssertFalse(lowClarity.honorsGateInvariant,
                       "low clarity + empty gateRequirements violates §5.11 合度地过")

        let lowWithGate = BASJadePermitGrade(
            gradeID: "ok-low",
            actionPermitRef: "p",
            clarityScore: 0.3,
            reversibilityScore: 0.9,
            provenanceScore: 0.9,
            gateRequirements: ["heaven-gate-1"],
            revocationPath: "writ")
        XCTAssertTrue(lowWithGate.honorsGateInvariant)
    }

    func testJadePermitGradeRoundTripCodable() throws {
        let g = BASJadePermitGrade(
            gradeID: "rt",
            actionPermitRef: "p",
            clarityScore: 0.7,
            reversibilityScore: 0.6,
            provenanceScore: 0.8,
            gateRequirements: ["g1"],
            revocationPath: "w")
        let data = try JSONEncoder().encode(g)
        let decoded = try JSONDecoder()
            .decode(BASJadePermitGrade.self, from: data)
        XCTAssertEqual(g, decoded)
    }

    // MARK: - M475 BASJadeRefinementTicket

    func testJadeRefinementTicketSchemaVersion() {
        XCTAssertEqual(
            BASJadeRefinementTicket.currentSchemaVersion, "1.0.0")
    }

    func testJadeRefinementHonorsNoGhostInvariant() {
        let valid = BASJadeRefinementTicket(
            ticketID: "t",
            candidateRef: "c",
            impurityCodes: ["host-private"],
            refinementSteps: ["scrub"],
            shadowTrialRef: "st",
            fracturePath: "fracture-path-1",
            promotionGateRef: "g")
        XCTAssertTrue(valid.honorsNoGhostInvariant)
    }

    func testJadeRefinementEmptyFractureViolatesInvariant() {
        let invalid = BASJadeRefinementTicket(
            ticketID: "bad",
            candidateRef: "c",
            impurityCodes: [],
            refinementSteps: [],
            shadowTrialRef: "st",
            fracturePath: "",
            promotionGateRef: "g")
        XCTAssertFalse(invalid.honorsNoGhostInvariant,
                       "empty fracturePath violates §5.13 不留幽灵")
    }

    func testJadeRefinementTrimsArrays() {
        let r = BASJadeRefinementTicket(
            ticketID: "  t  ",
            candidateRef: "c",
            impurityCodes: ["x", "  "],
            refinementSteps: ["scrub", ""],
            shadowTrialRef: "st",
            fracturePath: "fp",
            promotionGateRef: "g")
        XCTAssertEqual(r.ticketID, "t")
        XCTAssertEqual(r.impurityCodes, ["x"])
        XCTAssertEqual(r.refinementSteps, ["scrub"])
    }

    func testJadeRefinementRoundTripCodable() throws {
        let r = BASJadeRefinementTicket(
            ticketID: "rt",
            candidateRef: "c",
            impurityCodes: ["a"],
            refinementSteps: ["s1"],
            shadowTrialRef: "st",
            fracturePath: "fp",
            promotionGateRef: "g")
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder()
            .decode(BASJadeRefinementTicket.self, from: data)
        XCTAssertEqual(r, decoded)
    }

    // MARK: - Cross-schema doctrine pins

    func testAllChapter123SchemasAtV1Point0() {
        XCTAssertEqual(
            BASJadeCasketSnapshot.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASYaochiMemoryLayer.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASTianhengProfile.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASJadePermitGrade.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASJadeRefinementTicket.currentSchemaVersion, "1.0.0")
    }
}
