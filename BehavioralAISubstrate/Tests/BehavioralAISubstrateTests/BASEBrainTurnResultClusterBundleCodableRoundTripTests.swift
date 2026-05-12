// MARK: - BASEBrainTurnResultClusterBundleCodableRoundTripTests
// chapter 五百四十二 / M1545 — explicit Codable round-trip
//                              PROOF tests for the
//                              cluster bundles that
//                              support default-init
//                              fixtures
//
// Chapter 541 M1543 shipped COMPILE-TIME conformance
// checks via a generic helper。 This chapter adds the
// next layer of PROOF:explicit ENCODE-DECODE-COMPARE
// round-trip tests using sortedKeys JSON encoding。
//
// Of the 9 cluster bundles,3 have a `static let empty`
// default fixture (chapter 五百二十四/五百二十五/五百二十六
// arcs):BASEBrainTurnResultEvolutionBundle +
// BASEBrainTurnResultSovereignBundle +
// BASEBrainTurnResultAuditProjectionForwardBundle。
// These are exercised here via the simplest possible
// fixture path。 The remaining 6 bundles have required
// fields without empty defaults;their round-trip PROOF
// is deferred to a follow-up arc that ships fixture
// builders。

import XCTest
@testable import BASHostKit

final class BASEBrainTurnResultClusterBundleCodableRoundTripTests:
    XCTestCase
{

    // MARK: - Round-trip helper

    private func roundTrip<T: Codable & Equatable>(
        _ value: T
    ) throws -> T {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(
            T.self, from: data)
    }

    // MARK: - Evolution bundle (10 fields,empty default)

    func testEvolutionBundleEmptyRoundTrips() throws {
        let original =
            BASEBrainTurnResultEvolutionBundle.empty
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testEvolutionBundleDefaultInitRoundTrips() throws
    {
        // Verify the default init (== empty) round-trips
        // as well。 Pins the two paths byte-equal at the
        // serialization layer。
        let original =
            BASEBrainTurnResultEvolutionBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded,
            BASEBrainTurnResultEvolutionBundle.empty)
    }

    // MARK: - Sovereign bundle (8 fields,empty default)

    func testSovereignBundleEmptyRoundTrips() throws {
        let original =
            BASEBrainTurnResultSovereignBundle.empty
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testSovereignBundleDefaultInitRoundTrips() throws
    {
        let original =
            BASEBrainTurnResultSovereignBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded,
            BASEBrainTurnResultSovereignBundle.empty)
    }

    // MARK: - AuditProjectionForward bundle (7 fields,
    //         empty default)

    func testAuditProjectionForwardBundleEmptyRoundTrips()
        throws
    {
        let original =
            BASEBrainTurnResultAuditProjectionForwardBundle
                .empty
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testAuditProjectionForwardBundleDefaultInitRoundTrips()
        throws
    {
        let original =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded,
            BASEBrainTurnResultAuditProjectionForwardBundle
                .empty)
    }

    // MARK: - JSON sortedKeys determinism PROOF

    func testEncodingIsDeterministicAcrossRepeatedRuns()
        throws
    {
        // chapter 三百九二 replay-determinism pin:
        // sortedKeys JSON encoding must produce
        // BYTE-IDENTICAL output across repeated
        // encodings of the same Codable input。
        let bundle =
            BASEBrainTurnResultEvolutionBundle.empty
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        let data3 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }
}
