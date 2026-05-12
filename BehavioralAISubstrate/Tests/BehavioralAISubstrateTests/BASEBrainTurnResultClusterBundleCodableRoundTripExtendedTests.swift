// MARK: - BASEBrainTurnResultClusterBundleCodableRoundTripExtendedTests
// chapter 五百四十三 / M1549 — Codable round-trip PROOF
//                              tests for 2 more cluster
//                              bundles with required-
//                              field fixtures
//                              (HostBundle +
//                              ForensicMetadataBundle)
//
// Chapter 542 M1545 shipped 7 round-trip tests for the
// 3 bundles with `.empty` defaults。 This chapter extends
// coverage to 2 more bundles with required fields,using
// minimal fixtures。
//
// Coverage progression:
//   - Chapter 542 / M1545:3 bundles (Evolution +
//     Sovereign + AuditProjectionForward)
//   - Chapter 543 / M1549:5 bundles cumulative (adds
//     Host + ForensicMetadata)
//   - Future arcs:remaining 4 (Cognitive Frames +
//     RiskChoice + Misc + DeviceLifecycle)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableRoundTripExtendedTests:
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

    // MARK: - HostBundle fixture

    private func makeHostBundle()
        -> BASEBrainTurnResultHostBundle
    {
        let hostProfile = BASHostProfile(
            hostID: "host-fixture-001",
            longTermGoals: [],
            noGoZones: [])
        return BASEBrainTurnResultHostBundle(
            hostContext: hostProfile)
    }

    func testHostBundleMinimumRoundTrips() throws {
        let original = makeHostBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.populatedFieldCount, 1)
    }

    func testHostBundleEncodingIsDeterministic() throws {
        // sortedKeys JSON must produce byte-identical
        // output across repeated encodings of the same
        // value (chapter 三百九二 replay-determinism)。
        let bundle = makeHostBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        let data3 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }

    // MARK: - ForensicMetadataBundle fixture

    private func makeForensicMetadataBundle()
        -> BASEBrainTurnResultForensicMetadataBundle
    {
        // Pin recordedAt for deterministic Codable round-
        // trip — `.now` would produce different values
        // per fixture construction。
        let fixedDate = Date(timeIntervalSince1970:
            1_700_000_000)
        let trace = BASRuntimeTrace(
            sessionID: "sess-fixture-001",
            recordedAt: fixedDate,
            modelRoute: "fixture-route")
        return BASEBrainTurnResultForensicMetadataBundle(
            runtimeTrace: trace)
    }

    func testForensicMetadataBundleMinimumRoundTrips()
        throws
    {
        let original = makeForensicMetadataBundle()
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.populatedFieldCount, 1)
    }

    func testForensicMetadataBundleEncodingIsDeterministic()
        throws
    {
        let bundle = makeForensicMetadataBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(bundle)
        let data2 = try encoder.encode(bundle)
        XCTAssertEqual(data1, data2)
    }

    // MARK: - Cross-bundle round-trip determinism PROOF

    func testTwoBundlesRoundTripPreservesFieldEquality()
        throws
    {
        let host = makeHostBundle()
        let forensic = makeForensicMetadataBundle()
        let decodedHost = try roundTrip(host)
        let decodedForensic = try roundTrip(forensic)
        // Bundles are distinct types — equality only
        // holds for like-typed values。
        XCTAssertEqual(decodedHost, host)
        XCTAssertEqual(decodedForensic, forensic)
    }
}
