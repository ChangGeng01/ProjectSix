// MARK: - BASSessionMilestoneDoctrineCatalogueDoctrineTests
// chapter 五百五十 / M1578 — anti-drift PROOF tests for
//                            the session milestone
//                            doctrine catalogue

import XCTest
@testable import BASRuntimeCore

final class BASSessionMilestoneDoctrineCatalogueDoctrineTests:
    XCTestCase
{

    // MARK: - Count invariants

    func testMilestoneDoctrineCountIsSeven() {
        XCTAssertEqual(
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .milestoneDoctrineCount,
            7)
    }

    func testEntriesArrayLengthIsSeven() {
        XCTAssertEqual(
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entries.count,
            7)
    }

    func testIDEnumHasSevenCases() {
        XCTAssertEqual(
            BASSessionMilestoneDoctrineID.allCases.count,
            7)
    }

    // MARK: - Consistency invariant

    func testCatalogueIsConsistent() {
        XCTAssertTrue(
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .catalogueIsConsistent)
    }

    // MARK: - M-number range

    func testFirstMilestoneMNumberIs1509() {
        XCTAssertEqual(
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .firstMilestoneMNumber,
            1509)
    }

    func testLastMilestoneMNumberIs1573() {
        XCTAssertEqual(
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .lastMilestoneMNumber,
            1573)
    }

    // MARK: - Per-entry lookups

    func testFoldArcSealedEntry() {
        let entry =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entry(for: .basEBrainTurnResultFoldArcSealed)!
        XCTAssertEqual(entry.typeName,
            "BASEBrainTurnResultFoldArcSealedDoctrine")
        XCTAssertEqual(entry.originMNumber, 1509)
    }

    func testCoordinatorPurgeEntry() {
        let entry =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entry(for: .coordinatorDeadDeclarationPurge)!
        XCTAssertEqual(entry.originMNumber, 1514)
    }

    func testStateOfTheUnionEntry() {
        let entry =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entry(for: .sessionStateOfTheUnion)!
        XCTAssertEqual(entry.typeName,
            "BASAutonomousSessionStateOfTheUnionDoctrine")
        XCTAssertEqual(entry.originMNumber, 1573)
    }

    // MARK: - Chronological order

    func testEntriesAreChronologicallyOrdered() {
        let entries =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entries
        for i in 1..<entries.count {
            XCTAssertGreaterThan(
                entries[i].originMNumber,
                entries[i - 1].originMNumber,
                "Entries must be chronologically " +
                "ordered by originMNumber")
        }
    }

    // MARK: - Unique type names

    func testEntryTypeNamesAreUnique() {
        let names =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entries.map { $0.typeName }
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: - Unique IDs

    func testEntryIDsAreUnique() {
        let ids = BASSessionMilestoneDoctrineCatalogueDoctrine
            .entries.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Codable round-trip

    func testEntryIsCodableRoundTrip() throws {
        let original =
            BASSessionMilestoneDoctrineCatalogueDoctrine
                .entries[0]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASSessionMilestoneDoctrineCatalogueEntry.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
