// MARK: - BASMPSGraphKernelCoverageBundleTests
// chapter 四百七十七 / M1286
//
// PROOF that the SECOND BASBundle<Item> typealias
// migration works correctly + the canonical chapter 477
// snapshot pins 4-of-4 MPSGraph kernel coverage。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphKernelCoverageBundleTests:
    XCTestCase
{

    // MARK: - Typealias resolves

    func testTypealiasResolvesToBASBundle() {
        let bundle: BASMPSGraphKernelCoverageBundle =
            BASBundle(items: [])
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - Canonical chapter 477 snapshot pinned

    func testCanonicalSnapshotCoversAllFourMPSGraphKernels() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter477Snapshot
        XCTAssertEqual(snapshot.count, 4,
            "4-of-4 MPSGraph kernels covered:" +
            " matMul / rmsNorm / rotaryEmbedding /" +
            " attention")
        XCTAssertEqual(snapshot.provenCount, 4,
            "every item has numerical-correctness PROOF")
    }

    func testCanonicalSnapshotTestCaseSum() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter477Snapshot
        XCTAssertEqual(
            snapshot.totalTestCaseCount, 19,
            "5 (matMul M1277) + 5 (rmsNorm M1280) +" +
            " 5 (rotary M1282) + 4 (attention M1284)" +
            " = 19 test cases")
    }

    func testCanonicalSnapshotHasMetalSilverBundleID() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter477Snapshot
        XCTAssertEqual(
            snapshot.bundleID,
            "mpsgraph-coverage-chapter-477")
        XCTAssertEqual(
            snapshot.metadataValue(
                forKey: "coverage-target"),
            "4-of-4-mpsgraph-kernels")
    }

    // MARK: - Coverage lookup

    func testLookupCoverageForKnownOps() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter477Snapshot
        XCTAssertEqual(
            snapshot.coverage(for: .matMul)?
                .provenAtMNumber, 1277)
        XCTAssertEqual(
            snapshot.coverage(for: .rmsNorm)?
                .provenAtMNumber, 1280)
        XCTAssertEqual(
            snapshot.coverage(for: .rotaryEmbedding)?
                .provenAtMNumber, 1282)
        XCTAssertEqual(
            snapshot.coverage(for: .attention)?
                .provenAtMNumber, 1284)
    }

    func testLookupCoverageReturnsNilForUnknownOps() {
        let snapshot = BASCanonicalKernelCoverage
            .chapter477Snapshot
        XCTAssertNil(snapshot.coverage(for: .ssmScan),
            "ssmScan kernel doesn't exist yet —" +
            " coverage should be nil")
        XCTAssertNil(snapshot.coverage(for: .conv2D),
            "conv2D kernel doesn't exist yet")
        XCTAssertNil(snapshot.coverage(for: .softmax),
            "softmax kernel doesn't exist yet")
        XCTAssertNil(snapshot.coverage(for: .layerNorm),
            "layerNorm kernel doesn't exist yet")
    }

    // MARK: - Codable round trip

    func testBundleRoundTripsViaJSON() throws {
        let original = BASCanonicalKernelCoverage
            .chapter477Snapshot
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphKernelCoverageBundle.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "Codable round-trip must preserve all" +
            " fields (chapter 三百九二)")
    }

    // MARK: - Custom bundle construction works

    func testCustomBundleConstructionAndAppending() {
        var bundle = BASMPSGraphKernelCoverageBundle(
            items: [])
        bundle = bundle.appending(item:
            BASMPSGraphKernelCoverageItem(
                operation: .softmax,
                provenInChapter: 999,
                provenAtMNumber: 9999,
                testCaseCount: 3,
                hasNumericalCorrectnessProof: false))
        XCTAssertEqual(bundle.count, 1)
        XCTAssertEqual(bundle.provenCount, 0,
            "hasNumericalCorrectnessProof = false →" +
            " not counted as proven")
        XCTAssertEqual(bundle.totalTestCaseCount, 3)
    }
}
