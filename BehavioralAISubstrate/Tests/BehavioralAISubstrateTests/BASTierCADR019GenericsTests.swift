// MARK: - BASTierCADR019GenericsTests
// chapter 六百九十二 / M2140 第三刀 — Tier C ADR-019
//                                  completion doctrine
//                                  PROOF tests (reframed
//                                  contract: 2 generic +
//                                  2 typed concrete =
//                                  4-of-4 final shape)。

import XCTest
@testable import BASRuntimeCore

final class BASTierCADR019GenericsTests: XCTestCase {

    // MARK: - Tier C completion doctrine pins

    func testChapterTag() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine.chapterTag,
            "chapter 六百九十二")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .milestoneMNumber, 2140)
    }

    func testCandidateCountIs4() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .candidateCount, 4)
    }

    func testCandidateInventoryCountIs4() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .candidateInventoryCount, 4)
    }

    func testParametricGenericCountIs2() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .parametricGenericCount, 2)
    }

    func testTypedConcreteStructCountIs2() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .typedConcreteStructCount, 2)
    }

    func testParametricPlusConcreteEqualsCandidateCount() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .parametricGenericCount
                + BASTierCADR019CompletionDoctrine
                    .typedConcreteStructCount,
            BASTierCADR019CompletionDoctrine
                .candidateCount)
    }

    func testAllCandidatesExistInFinalShape() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .allCandidatesExistInFinalShape)
    }

    func testADR019StatusIsImplemented() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .adr019Status, "implemented")
    }

    func testContractReframedFromParametricOnly() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .contractReframedFromParametricOnly)
    }

    func testDirectiveScoreImpactIsZero() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .directiveScoreImpact, 0)
    }

    func testShapeRationaleCountIs4() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .shapeRationaleCount, 4)
    }

    func testPriorADR019ProposalRef() {
        XCTAssertEqual(
            BASTierCADR019CompletionDoctrine
                .priorADR019ProposalRef,
            "BASADR019TierCProposalDoctrine (chapter 507 / M1405)")
    }

    func testTierCCompleted() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .tierCCompleted)
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .purelyAdditive)
    }

    // MARK: - Inventory mentions all 4 candidates

    func testAllFourCandidatesMentionedInInventory() {
        let combined = BASTierCADR019CompletionDoctrine
            .candidateInventory.joined(separator: " ")
        XCTAssertTrue(combined.contains(
            "BASInspectionFrame"))
        XCTAssertTrue(combined.contains(
            "BASGovernanceCard"))
        XCTAssertTrue(combined.contains("BASRiskCard"))
        XCTAssertTrue(combined.contains(
            "BASArbitrationFrame"))
    }

    func testInventoryMentionsChapter507() {
        let combined = BASTierCADR019CompletionDoctrine
            .candidateInventory.joined(separator: " ")
        XCTAssertTrue(combined.contains("五百七"))
    }

    func testInventoryMentionsChapter508() {
        let combined = BASTierCADR019CompletionDoctrine
            .candidateInventory.joined(separator: " ")
        XCTAssertTrue(combined.contains("五百八"))
    }

    // MARK: - Shape rationale per candidate

    func testShapeRationaleMentionsAllFour() {
        let keys = Set(BASTierCADR019CompletionDoctrine
            .shapeRationale.keys)
        XCTAssertTrue(keys.contains("BASInspectionFrame"))
        XCTAssertTrue(keys.contains("BASGovernanceCard"))
        XCTAssertTrue(keys.contains("BASRiskCard"))
        XCTAssertTrue(keys.contains("BASArbitrationFrame"))
    }

    func testInspectionFrameRationaleIsParametricGeneric()
    {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .shapeRationale["BASInspectionFrame"]?
                .contains("parametric generic") ?? false)
    }

    func testGovernanceCardRationaleIsParametricGeneric()
    {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .shapeRationale["BASGovernanceCard"]?
                .contains("parametric generic") ?? false)
    }

    func testRiskCardRationaleIsTypedConcrete() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .shapeRationale["BASRiskCard"]?
                .contains("typed concrete struct") ?? false)
    }

    func testArbitrationFrameRationaleIsTypedConcrete() {
        XCTAssertTrue(
            BASTierCADR019CompletionDoctrine
                .shapeRationale["BASArbitrationFrame"]?
                .contains("typed concrete struct") ?? false)
    }

    // MARK: - Existing generic surfaces reachable
    // (proof that 2-of-4 parametric generics work today)

    func testBASInspectionFrameExistsAsGeneric() {
        let f = BASInspectionFrame<String>(
            inspectionID: "i1",
            schemaVersion: "v1",
            inspectorRefs: ["inspector.a"],
            inspectedRefs: ["object.b"],
            inspectionPolicy: "policy.test",
            inspectedAtMs: 0,
            body: "payload",
            diagnostics: [])
        XCTAssertEqual(f.inspectionID, "i1")
        XCTAssertEqual(f.body, "payload")
    }

    func testBASGovernanceCardExistsAsGeneric() {
        let c = BASGovernanceCard<String, String>(
            governanceID: "g1",
            schemaVersion: "v1",
            authority: "auth",
            decision: "granted",
            sourceRefs: ["src.a"],
            effectiveAtMs: 0,
            rationale: [])
        XCTAssertEqual(c.governanceID, "g1")
        XCTAssertEqual(c.decision, "granted")
    }
}
