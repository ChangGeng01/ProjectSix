// MARK: - BASChapter563SevenAggregatorCodableExtensionProofTests
// chapter 五百六十三 / M1630 — PROOF tests for the 7
//                          newly-Codable aggregator
//                          types shipped at M1629
//
// ## Coverage
//
// 7 compile-time Codable conformance PROOF tests (1
// per newly-Codable type)。 Use the assertConforms
// pattern that PROOFs Codable at compile time —
// failure would prevent build,not just test failure。
//
// Plus 2 round-trip PROOF tests on the types whose
// `.compute()` factory has tractable inputs:
//   - LateClusterD via .compute(sessionID:,
//     confidenceFloor:, quarantineRecords:)
//   - LateClusterD round-trip determinism (3-encode)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 7 newly-Codable aggregators
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1629 → M1630

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASHostKit
@testable import BASPolicy
@testable import BASWorldPrior

final class BASChapter563SevenAggregatorCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - Compile-time conformance helper

    /// Generic conformance check — compiles only when
    /// `T: Codable`。 If any aggregator loses Codable,
    /// this test fails to compile loudly。
    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    // MARK: - 7 compile-time conformance PROOFs

    func testCthulhuPentaConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsCthulhuPenta.self)
    }

    func testKunlunHexaConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsKunlunHexa.self)
    }

    func testKunlunHexaTwoConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsKunlunHexaTwo.self)
    }

    func testLateClusterBConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsLateClusterB.self)
    }

    func testLateClusterCConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsLateClusterC.self)
    }

    func testLateClusterDConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsLateClusterD.self)
    }

    func testKunlunSealRiverConformsToCodable() {
        assertCodable(
            BASTurnAuditProjectionsKunlunSealRiver.self)
    }

    // MARK: - LateClusterD round-trip PROOF

    /// LateClusterD has a simple .compute(...) factory
    /// — exercise it for a real populated round-trip。
    func testLateClusterDPopulatedRoundTrips() throws {
        let original = BASTurnAuditProjectionsLateClusterD
            .compute(
                sessionID: "sess-563",
                confidenceFloor: 0.3,
                quarantineRecords: [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsLateClusterD.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLateClusterDEncodingIsDeterministic() throws
    {
        let original = BASTurnAuditProjectionsLateClusterD
            .compute(
                sessionID: "sess-563-D",
                confidenceFloor: 0.5,
                quarantineRecords: [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }
}
