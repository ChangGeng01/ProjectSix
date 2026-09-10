// MARK: - BASStressSweepFixtureResultTests — chapter 四百十三 / M1023

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASStressSweepFixtureResultTests: XCTestCase {

    private func makeKey() -> BASTurnRuntimeStressFixtureKey {
        BASTurnRuntimeStressFixtureKey(
            risk: .high,
            permitMode: .answer,
            quarantines: false,
            anchorTone: false,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
    }

    // MARK: - Pass factory

    func testPassFactoryProducesByteEqual() {
        let r = BASStressSweepFixtureResult.pass(
            makeKey(), digest: "abc")
        XCTAssertEqual(r.verdict, .byteEqual)
        XCTAssertTrue(r.isPass)
        XCTAssertFalse(r.isFail)
        XCTAssertEqual(r.v1ResultDigest, "abc")
        XCTAssertEqual(r.v2ResultDigest, "abc")
    }

    // MARK: - Divergent factory

    func testDivergentFactoryHoldsBothDigests() {
        let r = BASStressSweepFixtureResult.divergent(
            makeKey(),
            v1Digest: "v1",
            v2Digest: "v2",
            diagnosticCodes: ["drift"])
        XCTAssertEqual(r.verdict, .divergent)
        XCTAssertTrue(r.isFail)
        XCTAssertEqual(r.v1ResultDigest, "v1")
        XCTAssertEqual(r.v2ResultDigest, "v2")
        XCTAssertEqual(r.diagnosticCodes, ["drift"])
    }

    // MARK: - V1Failed factory

    func testV1FailedFactoryHoldsDiagnostic() {
        let r = BASStressSweepFixtureResult.v1Failed(
            makeKey(), diagnosticCodes: ["v1-throw"])
        XCTAssertEqual(r.verdict, .v1Failed)
        XCTAssertNil(r.v1ResultDigest)
        XCTAssertNil(r.v2ResultDigest)
        XCTAssertEqual(r.diagnosticCodes, ["v1-throw"])
    }

    // MARK: - V2Failed factory

    func testV2FailedFactoryHoldsDiagnostic() {
        let r = BASStressSweepFixtureResult.v2Failed(
            makeKey(), diagnosticCodes: ["v2-throw"])
        XCTAssertEqual(r.verdict, .v2Failed)
        XCTAssertEqual(r.diagnosticCodes, ["v2-throw"])
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllFactoryFlavors()
        throws
    {
        let original =
            BASStressSweepFixtureResult.divergent(
                makeKey(),
                v1Digest: "v1",
                v2Digest: "v2",
                diagnosticCodes: ["a", "b"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASStressSweepFixtureResult.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testFactoryIsDeterministic() {
        let r1 = BASStressSweepFixtureResult.pass(
            makeKey(), digest: "x")
        let r2 = BASStressSweepFixtureResult.pass(
            makeKey(), digest: "x")
        XCTAssertEqual(r1, r2)
    }
}
