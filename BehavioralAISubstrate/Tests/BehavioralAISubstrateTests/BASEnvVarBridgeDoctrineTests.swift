// MARK: - BASEnvVarBridgeDoctrineTests
// chapter 六百七十 / M2059 — anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASEnvVarBridgeDoctrineTests: XCTestCase {
    typealias D = BASEnvVarBridgeDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase K") }

    func testFourKnifeMNumbers() {
        XCTAssertEqual(D.firstKnifeMNumber, 2057)
        XCTAssertEqual(D.secondKnifeMNumber, 2058)
        XCTAssertEqual(D.thirdKnifeMNumber, 2059)
        XCTAssertEqual(D.fourthKnifeMNumber, 2060)
    }

    func testBridgeTypeName() {
        XCTAssertEqual(D.bridgeTypeName,
            "BASSampleHostRuntimeModeEnvVarBridge")
    }
    func testEnvVarName() {
        XCTAssertEqual(D.envVarName, "BAS_RUNTIME_MODE")
    }

    func testEnvVarValidValues() {
        XCTAssertEqual(D.envVarValidValueCount, 3)
        XCTAssertTrue(D.envVarValidValues.contains(
            "v1-byte-equal"))
        XCTAssertTrue(D.envVarValidValues.contains(
            "native-v2"))
        XCTAssertTrue(D.envVarValidValues.contains(
            "stress-sweep-dual"))
    }

    func testDefaultModeRawValue() {
        XCTAssertEqual(D.defaultModeRawValue,
            "v1-byte-equal")
    }
    func testUnrecognizedValueFallback() {
        XCTAssertEqual(D.unrecognizedValueFallback,
            "v1-byte-equal")
    }

    func testBridgeApiSurfaces() {
        XCTAssertEqual(D.bridgeApiSurfaceCount, 4)
        XCTAssertTrue(D.bridgeApiSurfaces.contains(
            "envVarName"))
        XCTAssertTrue(D.bridgeApiSurfaces.contains(
            "defaultModeWhenAbsent"))
        XCTAssertTrue(D.bridgeApiSurfaces.contains(
            "currentRuntimeMode(environment:)"))
        XCTAssertTrue(D.bridgeApiSurfaces.contains(
            "isOptedInToNonDefault(environment:)"))
    }

    func testProofTestCount() {
        XCTAssertEqual(D.proofTestCount, 13)
    }

    func testPriorChapter669Ref() {
        XCTAssertEqual(D.priorChapter669Ref,
            "BASPhaseKDualModeStressSweepDoctrine")
    }

    func testFlags() {
        XCTAssertTrue(D.adr014OptInPreserved)
        XCTAssertTrue(D.byteEqualityPreserved)
        XCTAssertTrue(D.isOptInOnly)
    }
}
