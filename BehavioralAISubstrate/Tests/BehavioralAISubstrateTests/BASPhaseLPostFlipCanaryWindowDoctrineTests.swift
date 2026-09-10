// MARK: - BASPhaseLPostFlipCanaryWindowDoctrineTests
// chapter 六百七十五 / M2077 — anti-drift tests

import XCTest
@testable import BASRuntimeCore

final class BASPhaseLPostFlipCanaryWindowDoctrineTests:
    XCTestCase
{
    typealias D = BASPhaseLPostFlipCanaryWindowDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十五")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase L") }

    func testFourKnifeMNumbers() {
        XCTAssertEqual(D.firstKnifeMNumber, 2077)
        XCTAssertEqual(D.secondKnifeMNumber, 2078)
        XCTAssertEqual(D.thirdKnifeMNumber, 2079)
        XCTAssertEqual(D.fourthKnifeMNumber, 2080)
    }

    func testFlipMarkers() {
        XCTAssertEqual(D.flipChapterTag,
            "chapter 六百七十四")
        XCTAssertEqual(D.flipMNumber, 2074)
    }

    func testCanaryWindow() {
        XCTAssertEqual(D.canaryWindowChapters, 5)
        XCTAssertEqual(D.canaryStartChapterTag,
            "chapter 六百七十五")
        XCTAssertEqual(D.canaryEndChapterTag,
            "chapter 六百八十")
        XCTAssertEqual(D.v1DeletionEligibleAtChapterTag,
            "chapter 六百八十六")
    }

    func testV1PathStillCallable() {
        XCTAssertTrue(D.v1PathStillCallable)
    }

    func testV1CallableMechanisms() {
        XCTAssertEqual(D.v1CallableMechanisms.count, 2)
    }

    func testPriorChapter674Ref() {
        XCTAssertEqual(D.priorChapter674Ref,
            "BASPhaseLDefaultFlipCompletionDoctrine")
    }

    func testPhaseLClosure() {
        XCTAssertEqual(D.phaseLChaptersTotal, 4)
        XCTAssertEqual(D.phaseLClosedAt,
            "chapter 六百七十五")
        XCTAssertTrue(D.isPhaseLFinalChapter)
    }
}
