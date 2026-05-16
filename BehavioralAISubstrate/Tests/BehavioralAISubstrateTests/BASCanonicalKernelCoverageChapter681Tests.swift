// MARK: - BASCanonicalKernelCoverageChapter681Tests
// chapter 六百八十一 / M2102 第二刀 — 8-of-8 native coverage
//                                    milestone snapshot tests

import XCTest
@testable import BASMetalSubstrate

final class BASCanonicalKernelCoverageChapter681Tests:
    XCTestCase
{

    typealias B = BASCanonicalKernelCoverage

    // MARK: - 8-of-8 native coverage

    func testChapter681SnapshotHasEightItems() {
        let snapshot = B.chapter681Snapshot
        XCTAssertEqual(snapshot.items.count, 8)
    }

    func testChapter681SnapshotCoversAllBASNeuralOpCases() {
        let snapshot = B.chapter681Snapshot
        let covered = Set(snapshot.items.map(\.operation))
        let expected = Set(BASNeuralOp.allCases)
        XCTAssertEqual(covered, expected,
            "chapter 681 snapshot must cover all 8 " +
            "BASNeuralOp cases")
    }

    // MARK: - All 8 carry numerical correctness proof

    func testAllEightHaveNumericalCorrectnessProof() {
        let snapshot = B.chapter681Snapshot
        let proven = snapshot.items.filter {
            $0.hasNumericalCorrectnessProof
        }
        XCTAssertEqual(proven.count, 8)
        let unproven = snapshot.items.filter {
            !$0.hasNumericalCorrectnessProof
        }
        XCTAssertEqual(unproven.count, 0,
            "8-of-8 native coverage:NO kernel may lack " +
            "numerical correctness proof")
    }

    // MARK: - ssmScan now has proof (was the chapter 496
    // honest exception;chapter 678+ closed it)

    func testSSMScanHasNumericalCorrectnessProof() {
        let snapshot = B.chapter681Snapshot
        guard let item = snapshot.items.first(where: {
            $0.operation == .ssmScan
        }) else {
            return XCTFail("ssmScan missing")
        }
        XCTAssertTrue(item.hasNumericalCorrectnessProof,
            "ssmScan must carry numerical correctness " +
            "proof at chapter 681 snapshot")
    }

    func testSSMScanProvenanceBumpedToChapter678() {
        let snapshot = B.chapter681Snapshot
        guard let item = snapshot.items.first(where: {
            $0.operation == .ssmScan
        }) else {
            return XCTFail("ssmScan missing")
        }
        XCTAssertEqual(item.provenInChapter, 678)
        XCTAssertEqual(item.provenAtMNumber, 2089)
    }

    func testSSMScanTestCaseCountIs39() {
        let snapshot = B.chapter681Snapshot
        guard let item = snapshot.items.first(where: {
            $0.operation == .ssmScan
        }) else {
            return XCTFail("ssmScan missing")
        }
        // 5 basic + 11 CPU + 9 cross-val + 14 fixture-val
        // = 39 PROOF tests
        XCTAssertEqual(item.testCaseCount, 39)
    }

    // MARK: - Metadata pins

    func testMetadataMarks8of8Native() {
        let snapshot = B.chapter681Snapshot
        XCTAssertEqual(
            snapshot.metadata["coverage-target"],
            "8-of-8-native")
    }

    func testMetadataMentionsGpuAndCpuImpls() {
        let snapshot = B.chapter681Snapshot
        XCTAssertNotNil(
            snapshot.metadata["ssm-scan-gpu-impl"])
        XCTAssertNotNil(
            snapshot.metadata["ssm-scan-cpu-impl"])
    }

    func testMetadataOracleCountIs5() {
        let snapshot = B.chapter681Snapshot
        XCTAssertEqual(
            snapshot.metadata[
                "ssm-scan-correctness-oracle-count"],
            "5")
    }

    func testMetadataStatusIsProductionPlusSibling() {
        let snapshot = B.chapter681Snapshot
        XCTAssertEqual(
            snapshot.metadata["ssm-scan-status"],
            "metal-shader-production-plus-cpu-sibling")
    }

    // MARK: - Bundle is round-trip Codable

    func testChapter681SnapshotRoundTripCodable() throws {
        let original = B.chapter681Snapshot
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphKernelCoverageBundle.self,
            from: data)
        XCTAssertEqual(
            decoded.items.count, original.items.count)
        XCTAssertEqual(
            decoded.bundleID, original.bundleID)
    }

    // MARK: - Chapter 496 snapshot still preserved
    // (historical pin)

    func testChapter496SnapshotStillSaysSevenOfEight() {
        // Anti-drift PROOF that chapter 681 didn't
        // retroactively edit the chapter 496 snapshot —
        // history is preserved。
        let oldSnapshot = B.chapter496Snapshot
        XCTAssertEqual(
            oldSnapshot.metadata["coverage-target"],
            "7-of-8-native-plus-1-stub",
            "chapter 496 historical snapshot must NOT " +
            "have been mutated by chapter 681 work — " +
            "history pins persist")
    }

    // MARK: - Progression chapter 496 → 681 PROOF

    func testProgressionFromSevenOfEightToEightOfEight() {
        let oldSnapshot = B.chapter496Snapshot
        let newSnapshot = B.chapter681Snapshot

        let oldProven = oldSnapshot.items.filter {
            $0.hasNumericalCorrectnessProof
        }.count
        let newProven = newSnapshot.items.filter {
            $0.hasNumericalCorrectnessProof
        }.count

        XCTAssertEqual(oldProven, 7)
        XCTAssertEqual(newProven, 8)
        XCTAssertEqual(newProven - oldProven, 1,
            "chapter 681 closed exactly 1 kernel's " +
            "honest gap (ssmScan)")
    }
}
