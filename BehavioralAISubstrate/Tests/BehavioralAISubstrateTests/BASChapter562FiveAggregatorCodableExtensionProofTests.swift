// MARK: - BASChapter562FiveAggregatorCodableExtensionProofTests
// chapter 五百六十二 / M1626 — PROOF tests for the 5
//                          newly-Codable aggregator
//                          types shipped at M1625
//
// ## Coverage
//
// 10 PROOF tests covering populated round-trip +
// sortedKeys determinism for:
//   - BASTurnAuditProjectionsSurfaceTrio
//   - BASTurnAuditProjectionsGateSideDeriveTrio
//   - BASTurnAuditProjectionsKunlunTrioTwo
//   - BASTurnAuditProjectionsLifecycleQuartet
//   - BASTurnAuditProjectionsKunlunTianmenTrio
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//     to these 5 newly-Codable aggregators
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1625 → M1626

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASHostKit
@testable import BASPolicy
@testable import BASWorldPrior

final class BASChapter562FiveAggregatorCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - Helper

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - SurfaceTrio (2 tests)

    func testSurfaceTrioPopulatedRoundTrips() throws {
        let original = BASTurnAuditProjectionsSurfaceTrio
            .compute(permitMode: .answer)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsSurfaceTrio.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSurfaceTrioEncodingIsDeterministic() throws {
        let trio = BASTurnAuditProjectionsSurfaceTrio
            .compute(permitMode: .mirror)
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(trio)
        let d2 = try encoder.encode(trio)
        let d3 = try encoder.encode(trio)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - GateSideDeriveTrio (2 tests)

    private func gateSideTrio() ->
        BASTurnAuditProjectionsGateSideDeriveTrio
    {
        let abyssal = BASAbyssalPressure(
            pressureID: "ap-562",
            unknownLoad: 0.2,
            consequenceRadius: 0.3,
            evidenceDebt: 0.1,
            ontologyDistortion: 0.05,
            manipulationIndex: 0.05,
            narrativePollution: 0.05,
            recommendedModes: [])
        let anchor = BASHumanAnchorSignal(
            anchorID: "ha-562",
            hostSummaryRef: "host-562",
            agencyRisk: 0.1,
            alienationRisk: 0.1,
            dignityRisk: 0.1,
            overwhelmRisk: 0.1,
            recommendedSurfaceTone: .plain,
            requiredAgencyReservation: "")
        let unknown = BASUnknownReserve(
            reserveID: "ur-562",
            unknownRefs: [],
            whyUnresolved: "test",
            forbiddenInferences: [],
            evidenceNeeded: [],
            assertionCeiling: .none)
        return BASTurnAuditProjectionsGateSideDeriveTrio(
            abyssalPressure: abyssal,
            humanAnchorSignal: anchor,
            unknownReserve: unknown)
    }

    func testGateSideDeriveTrioPopulatedRoundTrips()
        throws
    {
        let original = gateSideTrio()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsGateSideDeriveTrio
                .self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testGateSideDeriveTrioEncodingIsDeterministic()
        throws
    {
        let trio = gateSideTrio()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(trio)
        let d2 = try encoder.encode(trio)
        let d3 = try encoder.encode(trio)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - KunlunTrioTwo (2 tests)

    private func kunlunTrioTwo() ->
        BASTurnAuditProjectionsKunlunTrioTwo
    {
        let casket = BASJadeCasketSnapshot(
            snapshotID: "jc-562",
            foldRefs: [],
            integrityHash: "hash-562",
            sourceRiverRef: "river-562",
            restoreGateRef: "gate-562",
            rollbackWritRef: "rollback-562")
        let fidelity = BASJadeFidelityMap(
            mapID: "fm-562",
            organRef: "organ-562",
            fidelityLevel: .standard,
            degradationPolicy: "policy-562",
            contaminationTolerance: 0.1,
            auditRequired: false)
        return BASTurnAuditProjectionsKunlunTrioTwo(
            jadeCasket: casket,
            jadeRefinementTickets: [],
            jadeFidelityMap: fidelity)
    }

    func testKunlunTrioTwoPopulatedRoundTrips() throws {
        let original = kunlunTrioTwo()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsKunlunTrioTwo.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testKunlunTrioTwoEncodingIsDeterministic() throws
    {
        let trio = kunlunTrioTwo()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(trio)
        let d2 = try encoder.encode(trio)
        let d3 = try encoder.encode(trio)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - LifecycleQuartet (2 tests)

    private func lifecycleQuartet() ->
        BASTurnAuditProjectionsLifecycleQuartet
    {
        return BASTurnAuditProjectionsLifecycleQuartet(
            synthesizedSeals: [],
            sealAggregate: nil,
            lifecycleSessions: [],
            lifecycleAggregate: nil)
    }

    func testLifecycleQuartetEmptyRoundTrips() throws {
        let original = lifecycleQuartet()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsLifecycleQuartet.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLifecycleQuartetPopulatedSealRoundTrips()
        throws
    {
        let seal = BASSealEnvelope(
            sealID: "seal-562",
            targetRefs: ["target-562"],
            sealReason: "test-reason",
            accessPolicy: .auditedAccess,
            revealConditions: [],
            lineageCutRefs: [],
            auditRef: "audit-562")
        let original = BASTurnAuditProjectionsLifecycleQuartet(
            synthesizedSeals: [seal],
            sealAggregate: nil,
            lifecycleSessions: [],
            lifecycleAggregate: nil)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsLifecycleQuartet.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.synthesizedSeals.count, 1)
    }

    // MARK: - KunlunTianmenTrio (2 tests)

    private func tianmenTrio() ->
        BASTurnAuditProjectionsKunlunTianmenTrio
    {
        // Use the .compute(...) factory with minimal
        // inputs that produce a deterministic
        // populated state。
        return BASTurnAuditProjectionsKunlunTianmenTrio
            .compute(
                sessionID: "sess-562",
                permitMode: .answer,
                primaryCandidateID: "cand-562",
                worldAnchorRef: "world-562",
                centerlineRules: ["rule-562"],
                deviationCodes: [],
                heavenGateID: "gate-562",
                heavenGateIsReady: true,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID:
                    "warrant-562",
                jadeCanonSealRef: "jcs-562",
                riverOriginRef: "ro-562")
    }

    func testKunlunTianmenTrioPopulatedRoundTrips() throws
    {
        let original = tianmenTrio()
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnAuditProjectionsKunlunTianmenTrio.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertNotNil(decoded.tianmenWarrant)
    }

    func testKunlunTianmenTrioEncodingIsDeterministic()
        throws
    {
        let trio = tianmenTrio()
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(trio)
        let d2 = try encoder.encode(trio)
        let d3 = try encoder.encode(trio)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }
}
