// MARK: - BASRuntimeModeOverrideDoctrineTests
// chapter 六百七十二 / M2067 — anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASRuntimeModeOverrideDoctrineTests: XCTestCase {
    typealias D = BASRuntimeModeOverrideDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十二")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase L") }

    func testFourKnifeMNumbers() {
        XCTAssertEqual(D.firstKnifeMNumber, 2065)
        XCTAssertEqual(D.secondKnifeMNumber, 2066)
        XCTAssertEqual(D.thirdKnifeMNumber, 2067)
        XCTAssertEqual(D.fourthKnifeMNumber, 2068)
    }

    func testOverrideEnvVarName() {
        XCTAssertEqual(D.overrideEnvVarName,
            "BAS_RUNTIME_MODE_OVERRIDE")
    }

    func testPriorityOrder() {
        XCTAssertEqual(D.priorityOrder.count, 3)
        XCTAssertEqual(D.priorityOrder[0],
            "BAS_RUNTIME_MODE_OVERRIDE (if set + valid)")
        XCTAssertEqual(D.priorityOrder[1],
            "BAS_RUNTIME_MODE (if set + valid)")
        XCTAssertEqual(D.priorityOrder[2],
            "defaultModeWhenAbsent (.v1ByteEqual)")
    }

    func testNewApiMethods() {
        XCTAssertEqual(D.newApiMethods.count, 2)
        XCTAssertTrue(D.newApiMethods.contains(
            "currentRuntimeModeRespectingOverride(environment:)"))
        XCTAssertTrue(D.newApiMethods.contains(
            "isOverrideActive(environment:)"))
    }

    func testProofTestCount() {
        XCTAssertEqual(D.proofTestCount, 14)
    }

    func testOriginalCurrentRuntimeModeUnchanged() {
        XCTAssertTrue(D.originalCurrentRuntimeModeUnchanged)
    }

    func testIsPhaseLPreFlipSafetyNet() {
        XCTAssertTrue(D.isPhaseLPreFlipSafetyNet)
    }

    func testPhaseLFlipMarkers() {
        XCTAssertEqual(D.phaseLFlipChapter,
            "chapter 六百七十四")
        XCTAssertEqual(D.phaseLFlipMNumber, 2074)
    }

    func testTaggedCommitName() {
        XCTAssertEqual(D.taggedCommitName,
            "pre-default-flip-M2068")
    }
    func testTaggedCommitMNumber() {
        XCTAssertEqual(D.taggedCommitMNumber, 2068)
    }

    func testCrossDoctrineRefs() {
        XCTAssertEqual(D.priorPhaseKCloseOutRef,
            "BASPhaseKRuntimeModeToggleCompletionDoctrine")
        XCTAssertEqual(D.priorPreFlipGateContractRef,
            "BASPhaseLPreFlipGateContractDoctrine")
    }

    func testRevertPathName() {
        XCTAssertEqual(D.revertPathName,
            "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal")
    }

    func testZeroRedeployRollback() {
        XCTAssertTrue(D.zeroRedeployRollback)
    }
}
