// MARK: - BASV1MonolithProjectionsFoldDoctrineTests
// chapter 五百十五 / M1439 — typed milestone doctrine tests
//
// PROOF tests pinning the V1 monolith projections fold
// LOC + field-packaging invariants:
//   1. Chapter 515 ship-record pins match doctrine claims
//   2. locReductionNet = preFold - postFold (invariant)
//   3. Field accounting consistent: packaged + residual
//      = 56 (close to original 56-arg count)
//   4. Equatable + Codable conformance round-trip

import XCTest
@testable import BASRuntimeCore

final class BASV1MonolithProjectionsFoldDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Chapter 515 ship record pins

    func testChapter515ShipRecordPins() {
        let r = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        XCTAssertEqual(r.preFoldCallSiteLOC, 118)
        XCTAssertEqual(r.postFoldCallSiteLOC, 83)
        XCTAssertEqual(r.locReductionNet, 35)
        XCTAssertEqual(r.fieldsPackagedInBlocks, 37)
        XCTAssertEqual(r.residualNamedArgs, 22)
        XCTAssertEqual(r.chapterTag, "chapter 五百十五")
        XCTAssertEqual(r.mNumberAtShip, 1440)
    }

    // MARK: - 2) locReductionNet invariant

    func testLocReductionInvariant() {
        let r = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        XCTAssertEqual(
            r.preFoldCallSiteLOC
                - r.postFoldCallSiteLOC,
            r.locReductionNet,
            "locReductionNet must equal" +
            " (preFoldCallSiteLOC - postFoldCallSiteLOC)")
    }

    // MARK: - 3) Field accounting

    /// Fields packaged + residuals should sum near the
    /// original 56-arg shape (some args are merged/
    /// renamed in the fold so exact match isn't
    /// required). The pin: packaged + residual >= 55
    /// to catch silent shrinkage of the audit surface。
    func testFieldAccountingSumsCloseToOriginal() {
        let r = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        let total = r.fieldsPackagedInBlocks
            + r.residualNamedArgs
        XCTAssertEqual(
            total, 59,
            "packaged (37) + residual (22) = 59 fields" +
            " — exceeds original 56 because residuals" +
            " include some Cthulhu/Kunlun trio outputs" +
            " not packaged in their respective blocks")
    }

    // MARK: - 4) Byte-equality verification list

    func testByteEqualityVerificationListIsPopulated() {
        let r = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        XCTAssertFalse(
            r.byteEqualityVerifiedBy.isEmpty)
        XCTAssertGreaterThanOrEqual(
            r.byteEqualityVerifiedBy.count, 3,
            "must list >= 3 PROOF mechanisms")
        XCTAssertTrue(
            r.byteEqualityVerifiedBy
                .contains(where: { $0.contains(
                    "ThreeBlockUnifiedInit") }),
            "must reference the M1435 PROOF tests")
        XCTAssertTrue(
            r.byteEqualityVerifiedBy
                .contains(where: { $0.contains(
                    "StressSweep") }),
            "must reference the stress-sweep regression" +
            " guard")
    }

    // MARK: - 5) Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASV1MonolithProjectionsFoldDoctrine.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 6) Hashable conformance

    func testHashableConformance() {
        let r = BASV1MonolithProjectionsFoldDoctrine
            .chapter515ShipRecord
        var set: Set<BASV1MonolithProjectionsFoldDoctrine>
            = []
        set.insert(r)
        set.insert(r)  // dup
        XCTAssertEqual(set.count, 1,
            "Hashable + Equatable must collapse" +
            " duplicates")
    }
}
