// MARK: - BASMemoryAtomEventSourcingDoctrineTests
// chapter 四百二 / M951

import XCTest
@testable import BASRuntimeCore

final class BASMemoryAtomEventSourcingDoctrineTests:
    XCTestCase
{

    func testChapterTagIsNonEmpty() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            "chapter 四百二")
    }

    func testMNumberRangeMatchesPhase1() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberFirst,
            941)
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberLast,
            952)
    }

    func testMigrationModesNonEmpty() {
        XCTAssertFalse(
            BASMemoryAtomEventSourcingDoctrine
                .migrationModes.isEmpty)
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine
                .migrationModes.count,
            3)
    }

    func testMigrationModesContainExpectedKeys() {
        let modes = BASMemoryAtomEventSourcingDoctrine
            .migrationModes
        XCTAssertTrue(modes.contains("legacy:direct-store"))
        XCTAssertTrue(modes.contains("opt-in:event-sourced"))
        XCTAssertTrue(modes.contains("deprecation:phase-3"))
    }

    func testPinHeldContainsTen() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.pinHeld.count,
            10)
    }

    func testSummaryNonEmpty() {
        XCTAssertFalse(
            BASMemoryAtomEventSourcingDoctrine.summary.isEmpty)
    }
}
