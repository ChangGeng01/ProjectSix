// MARK: - BASCanonicalKernelCoverageChapter496Tests
// chapter 四百九十六 / M1363 — coverage snapshot tests

import XCTest
@testable import BASMetalSubstrate

final class BASCanonicalKernelCoverageChapter496Tests:
    XCTestCase
{

    // MARK: - 1) Snapshot has 8 items

    func testChapter496SnapshotHasEightItems() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        XCTAssertEqual(snapshot.items.count, 8)
    }

    // MARK: - 2) Snapshot covers all 8 BASNeuralOp cases

    func testChapter496SnapshotCoversAllBASNeuralOpCases() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        let covered = Set(snapshot.items.map(\.operation))
        let expected = Set(BASNeuralOp.allCases)
        XCTAssertEqual(covered, expected,
            "chapter 496 snapshot must cover all 8" +
            " BASNeuralOp cases (7 native MPSGraph +" +
            " 1 stubbed ssmScan)")
    }

    // MARK: - 3) 7 of 8 have numerical correctness proof
    //             (ssmScan is the honest exception)

    func testSevenOfEightHaveNumericalCorrectnessProof() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        let proven = snapshot.items.filter {
            $0.hasNumericalCorrectnessProof
        }
        XCTAssertEqual(proven.count, 7)
        let unproven = snapshot.items.filter {
            !$0.hasNumericalCorrectnessProof
        }
        XCTAssertEqual(unproven.count, 1)
        XCTAssertEqual(unproven.first?.operation,
                       .ssmScan,
            "the only kernel WITHOUT numerical-" +
            "correctness proof must be ssmScan" +
            " (Tier 2 phase K deferred per chapter 496" +
            " doctrine)")
    }

    // MARK: - 4) ssmScan provenance points at the stub

    func testSSMScanProvenanceMatchesStubChapter() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        guard
            let item = snapshot.items
                .first(where: { $0.operation == .ssmScan })
        else {
            return XCTFail("ssmScan missing from snapshot")
        }
        XCTAssertEqual(item.provenInChapter, 496)
        XCTAssertEqual(item.provenAtMNumber, 1361)
        XCTAssertEqual(item.testCaseCount, 7)
        XCTAssertFalse(item.hasNumericalCorrectnessProof)
    }

    // MARK: - 5) Native MPSGraph kernels carry numerical proof

    func testAllNativeMPSGraphKernelsCarryNumericalProof() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        let nativeOps: Set<BASNeuralOp> = [
            .matMul, .rmsNorm, .rotaryEmbedding,
            .attention, .softmax, .layerNorm, .conv2D,
        ]
        for op in nativeOps {
            guard
                let item = snapshot.items
                    .first(where: { $0.operation == op })
            else {
                XCTFail("native MPSGraph \(op) missing")
                continue
            }
            XCTAssertTrue(
                item.hasNumericalCorrectnessProof,
                "\(op) must carry numerical correctness" +
                " proof at chapter 496 snapshot")
        }
    }

    // MARK: - 6) Metadata carries Tier 2 phase K marker

    func testMetadataMarksTier2PhaseKDeferred() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter496Snapshot
        XCTAssertEqual(
            snapshot.metadata["coverage-target"],
            "7-of-8-native-plus-1-stub")
        XCTAssertEqual(
            snapshot.metadata["ssm-scan-status"],
            "stub-identity-scan-tier-2-phase-K-deferred")
    }

    // MARK: - 7) Bundle is round-trip Codable

    func testChapter496SnapshotIsRoundTripCodable() throws {
        let original = BASCanonicalKernelCoverage
            .chapter496Snapshot
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphKernelCoverageBundle.self,
            from: data)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
        XCTAssertEqual(decoded.bundleID,
                       original.bundleID)
    }
}
