// MARK: - BASChapter561TrioCodableExtensionProofTests
// chapter 五百六十一 / M1622 — PROOF tests for the
//                          3 newly-Codable Trio /
//                          Protocol audit-projection
//                          types shipped at M1621
//
// ## Why this test exists
//
// M1621 added Codable + Equatable to 3 aggregator
// types that previously sat at Sendable / Hashable
// only:
//
//   - BASTurnAuditProjectionsKunlunAxisProtocol
//   - BASTurnAuditProjectionsKunlunTrio
//   - BASTurnAuditProjectionsAbyssalThermalTrio
//
// All field types are BASSchemaVersioned-conforming
// (Codable + Equatable + Sendable) so Codable
// synthesis works cleanly。 This file PROOFs that the
// synthesis produces correct round-trip behavior on
// populated instances。
//
// 8 PROOF tests:
//   - 1 round-trip per type (3)
//   - sortedKeys determinism per type (3)
//   - distinct-values produce distinct bytes per type (2 across types,
//     consolidated test)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive test surface
//   - chapter 三百九二:replay-determinism extends
//     to these 3 newly-Codable aggregators
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1621 → M1622

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASPolicy

final class BASChapter561TrioCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - Helper

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - Test fixtures

    private func axisProtocol() ->
        BASTurnAuditProjectionsKunlunAxisProtocol
    {
        return BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "sess-561",
                hostID: "host-561",
                permitMode: .answer,
                riskLevel: .low,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "cand-561",
                kunlunActiveLayerRefs: [
                    "L4-worldview"
                ],
                centerlineRules: [
                    "host-boundary"
                ],
                kunlunAxisDeviationThreshold: 0.4)
    }

    private func kunlunTrio() ->
        BASTurnAuditProjectionsKunlunTrio
    {
        let lease = BASAscentLease(
            leaseID: "ascent-lease-561",
            runLeaseRef: "run-lease-561",
            ascentMode: .ascending,
            maxSteps: 3,
            gateBudget: 2,
            returnRequired: true,
            sovereignReserve: 1)
        let deviation = BASAxisDeviation(
            deviationID: "axis-deviation-561",
            situationRef: "situation-561",
            centerlineRef: "axis-561",
            deviationScore: 0.25,
            reasonCodes: ["minor-drift"])
        let pressure = BASGatePressure(
            pressureID: "gate-pressure-561",
            situationRef: "situation-561",
            approachingDomains: ["host-version"],
            urgency: 0.3,
            reversible: true,
            gateRequired: false)
        return BASTurnAuditProjectionsKunlunTrio(
            ascentLease: lease,
            axisDeviation: deviation,
            gatePressure: pressure)
    }

    private func abyssalTrio() ->
        BASTurnAuditProjectionsAbyssalThermalTrio
    {
        let budget = BASAbyssBudget(
            budgetID: "abyss-budget-561",
            deepDiveQuota: 0.5,
            anomalyTolerance: 0.3,
            safeSurfaceFloor: 0.2,
            sovereignReserve: 0.4)
        return BASTurnAuditProjectionsAbyssalThermalTrio(
            abyssalRunMode: .nearShore,
            abyssBudget: budget,
            memoryTemperatureLayer: .midLayerMemory)
    }

    // MARK: - Round-trip PROOF (3 tests)

    func testKunlunAxisProtocolRoundTrips() throws {
        let original = axisProtocol()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsKunlunAxisProtocol.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.matched, original.matched)
        XCTAssertEqual(
            decoded.deviationCodes,
            original.deviationCodes)
    }

    func testKunlunTrioRoundTrips() throws {
        let original = kunlunTrio()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsKunlunTrio.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.ascentLease.leaseID,
            "ascent-lease-561")
    }

    func testAbyssalThermalTrioRoundTrips() throws {
        let original = abyssalTrio()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsAbyssalThermalTrio.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.abyssalRunMode, .nearShore)
    }

    // MARK: - sortedKeys determinism (3 tests)

    func testKunlunAxisProtocolEncodingIsDeterministic()
        throws
    {
        let original = axisProtocol()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    func testKunlunTrioEncodingIsDeterministic() throws {
        let original = kunlunTrio()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    func testAbyssalThermalTrioEncodingIsDeterministic()
        throws
    {
        let original = abyssalTrio()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - Distinct-values produce distinct bytes (2 tests)

    /// Two BASTurnAuditProjectionsKunlunAxisProtocol
    /// instances with different sessionIDs produce
    /// different encoded bytes — PROOF Codable isn't
    /// silently dropping the differing field。
    func testDistinctKunlunAxisProtocolsProduceDistinctBytes()
        throws
    {
        let a = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "sess-A",
                hostID: "host",
                permitMode: .answer,
                riskLevel: .low,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "cand",
                kunlunActiveLayerRefs: [],
                centerlineRules: [],
                kunlunAxisDeviationThreshold: 0.5)
        let b = BASTurnAuditProjectionsKunlunAxisProtocol
            .compute(
                sessionID: "sess-B",
                hostID: "host",
                permitMode: .answer,
                riskLevel: .low,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    .plain,
                sovereignEscalationHint: nil,
                primaryCandidateID: "cand",
                kunlunActiveLayerRefs: [],
                centerlineRules: [],
                kunlunAxisDeviationThreshold: 0.5)
        let encoder = canonicalEncoder()
        XCTAssertNotEqual(
            try encoder.encode(a),
            try encoder.encode(b))
    }

    /// Two Trio types with different rune modes
    /// produce different encoded bytes。
    func testDistinctAbyssalTriosProduceDistinctBytes()
        throws
    {
        let budget = BASAbyssBudget(
            budgetID: "shared",
            deepDiveQuota: 0.5,
            anomalyTolerance: 0.5,
            safeSurfaceFloor: 0.5,
            sovereignReserve: 0.5)
        let a = BASTurnAuditProjectionsAbyssalThermalTrio(
            abyssalRunMode: .tideSurface,
            abyssBudget: budget,
            memoryTemperatureLayer: .midLayerMemory)
        let b = BASTurnAuditProjectionsAbyssalThermalTrio(
            abyssalRunMode: .deepDive,
            abyssBudget: budget,
            memoryTemperatureLayer: .midLayerMemory)
        let encoder = canonicalEncoder()
        XCTAssertNotEqual(
            try encoder.encode(a),
            try encoder.encode(b))
    }
}
