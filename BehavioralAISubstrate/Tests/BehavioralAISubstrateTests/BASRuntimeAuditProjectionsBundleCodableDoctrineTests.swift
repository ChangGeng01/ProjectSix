// MARK: - BASRuntimeAuditProjectionsBundleCodableDoctrineTests
// chapter 五百五十一 / M1583 — PROOF tests for the
//                              cascading Codable
//                              conformance + the
//                              audit projections
//                              bundle Codable round-trip

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASRuntimeAuditProjectionsBundleCodableDoctrineTests:
    XCTestCase
{

    // MARK: - Doctrine invariants

    func testTypesGainedCodableIsFour() {
        XCTAssertEqual(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .typesGainedCodable,
            4)
    }

    func testCascadeAddedAtM1581() {
        XCTAssertEqual(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .cascadeAddedAtMNumber,
            1581)
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .byteEqualityPreserved)
    }

    func testUsesSynthesizedConformancePinned() {
        XCTAssertTrue(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .usesSynthesizedConformance)
    }

    func testReplayDeterminismProofMethodPinned() {
        XCTAssertEqual(
            BASRuntimeAuditProjectionsBundleCodableDoctrine
                .replayDeterminismProof,
            "codable-sortedKeys-json-round-trip")
    }

    // MARK: - Compile-time conformance PROOF

    private func assertConformsToCodable<T: Codable>(
        _ type: T.Type
    ) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testAllFourTypesConformToCodable() {
        // Compile-time PROOF — if any type loses Codable,
        // this test fails to compile loudly。
        assertConformsToCodable(
            BASCthulhuPermitEscalationDecision.self)
        assertConformsToCodable(
            BASCthulhuAssertionCeilingDecision.self)
        assertConformsToCodable(
            BASCthulhuAuditProjections.self)
        assertConformsToCodable(
            BASRuntimeAuditProjectionsBundle.self)
    }

    // MARK: - Empty aggregate bundle Codable round-trip

    func testEmptyAggregateBundleRoundTrips() throws {
        let original = BASRuntimeAuditProjectionsBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testNoneStaticBundleRoundTrips() throws {
        let original = BASRuntimeAuditProjectionsBundle.none()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - sortedKeys determinism PROOF

    func testEncodingIsDeterministicAcrossRepeatedRuns()
        throws
    {
        let bundle = BASRuntimeAuditProjectionsBundle.none()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        let data3 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }

    // MARK: - Empty Cthulhu projections round-trip

    func testEmptyCthulhuProjectionsRoundTrips() throws {
        let original = BASCthulhuAuditProjections.none()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCthulhuAuditProjections.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
