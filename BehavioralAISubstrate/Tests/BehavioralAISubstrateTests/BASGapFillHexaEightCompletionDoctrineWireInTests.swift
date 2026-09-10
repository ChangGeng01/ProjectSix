// MARK: - BASGapFillHexaEightCompletionDoctrineWireInTests
// chapter 六百六十三 / M2031 — wire-in PROOF tests cross-
//                              checking the M2029 hexa #8
//                              catalog against the 6
//                              source per-entry extension
//                              doctrines

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaEightCompletionDoctrineWireInTests: XCTestCase {
    typealias C = BASGapFillHexaEightCompletionDoctrine

    // Entry 1 — roadmap-eval-mock-trio (chapter 657)
    func testEntry1MNumberWiresIn() {
        XCTAssertEqual(C.entries[0].mNumberFirst,
            BASRoadmapEvalMockTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry1TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[0].typesExtended,
            BASRoadmapEvalMockTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry1ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[0].chapterTag,
            BASRoadmapEvalMockTrioCodableExtensionDoctrine.chapterTag)
    }

    // Entry 2 — biomimetic-observation-trio (chapter 658)
    func testEntry2MNumberWiresIn() {
        XCTAssertEqual(C.entries[1].mNumberFirst,
            BASBiomimeticObservationTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry2TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[1].typesExtended,
            BASBiomimeticObservationTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry2ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[1].chapterTag,
            BASBiomimeticObservationTrioCodableExtensionDoctrine.chapterTag)
    }

    // Entry 3 — kernel-result-trio (chapter 659)
    func testEntry3MNumberWiresIn() {
        XCTAssertEqual(C.entries[2].mNumberFirst,
            BASKernelResultTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry3TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[2].typesExtended,
            BASKernelResultTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry3ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[2].chapterTag,
            BASKernelResultTrioCodableExtensionDoctrine.chapterTag)
    }

    // Entry 4 — host-projection-trio (chapter 660)
    func testEntry4MNumberWiresIn() {
        XCTAssertEqual(C.entries[3].mNumberFirst,
            BASHostProjectionTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry4TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[3].typesExtended,
            BASHostProjectionTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry4ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[3].chapterTag,
            BASHostProjectionTrioCodableExtensionDoctrine.chapterTag)
    }

    // Entry 5 — convenience-cadence-record-trio (chapter 661)
    func testEntry5MNumberWiresIn() {
        XCTAssertEqual(C.entries[4].mNumberFirst,
            BASConvenienceCadenceRecordTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry5TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[4].typesExtended,
            BASConvenienceCadenceRecordTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry5ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[4].chapterTag,
            BASConvenienceCadenceRecordTrioCodableExtensionDoctrine.chapterTag)
    }

    // Entry 6 — biomimetic-signal-record-trio (chapter 662)
    func testEntry6MNumberWiresIn() {
        XCTAssertEqual(C.entries[5].mNumberFirst,
            BASBiomimeticSignalRecordTrioCodableExtensionDoctrine.extensionMNumber)
    }
    func testEntry6TypesExtendedWiresIn() {
        XCTAssertEqual(C.entries[5].typesExtended,
            BASBiomimeticSignalRecordTrioCodableExtensionDoctrine.totalTypesExtended)
    }
    func testEntry6ChapterTagWiresIn() {
        XCTAssertEqual(C.entries[5].chapterTag,
            BASBiomimeticSignalRecordTrioCodableExtensionDoctrine.chapterTag)
    }
}
