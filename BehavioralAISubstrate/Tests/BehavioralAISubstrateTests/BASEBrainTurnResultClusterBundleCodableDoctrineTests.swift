// MARK: - BASEBrainTurnResultClusterBundleCodableDoctrineTests
// chapter 五百四十一 / M1543 — anti-drift PROOF tests
//                              for the Codable
//                              conformance addition
//                              doctrine + compile-time
//                              conformance checks
//
// The tests use generic helpers parameterized on
// `Codable` types。 If any cluster bundle loses its
// Codable conformance,the type-erased lookup or the
// generic helper fails at compile time。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableDoctrineTests:
    XCTestCase
{

    // MARK: - Doctrine invariants

    func testBundlesGainedCodableIsNine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .bundlesGainedCodable,
            9)
    }

    func testMatchesFoldArcCountInvariantHolds() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .matchesFoldArcCount,
            "bundlesGainedCodable must equal " +
            "BASEBrainTurnResultFoldArcSealedDoctrine" +
            ".clusterBundleCount — every fold-arc " +
            "bundle gained Codable")
    }

    func testConformanceAddedAtM1541() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .conformanceAddedAtMNumber,
            1541)
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .byteEqualityPreserved)
    }

    func testReplayDeterminismProofMethodPinned() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .replayDeterminismProof,
            "codable-sortedKeys-json-round-trip")
    }

    func testUsesSynthesizedConformancePinned() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .usesSynthesizedConformance)
    }

    // MARK: - Compile-time Codable conformance checks
    //
    // Generic helper that requires `Codable` — if any
    // bundle loses Codable conformance,the call fails
    // at compile time。

    private func assertConformsToCodable<T: Codable>(
        _ type: T.Type
    ) {
        // The function signature itself is the proof;
        // we just need to invoke it for each bundle。
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testAllNineBundlesConformToCodable() {
        // 9 compile-time PROOF — if any bundle's Codable
        // conformance is removed,this test file fails
        // to compile。
        assertConformsToCodable(
            BASEBrainTurnResultEvolutionBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultSovereignBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultAuditProjectionForwardBundle
                .self)
        assertConformsToCodable(
            BASEBrainTurnResultHostBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultCognitiveFramesBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultRiskChoiceBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultMiscBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultDeviceLifecycleBundle.self)
        assertConformsToCodable(
            BASEBrainTurnResultForensicMetadataBundle.self)
    }
}
