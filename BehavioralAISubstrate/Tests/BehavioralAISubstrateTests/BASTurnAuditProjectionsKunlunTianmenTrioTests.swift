// MARK: - BASTurnAuditProjectionsKunlunTianmenTrioTests
// chapter 四百九十四 / M1353 — Tianmen trio fold tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy

final class BASTurnAuditProjectionsKunlunTianmenTrioTests:
    XCTestCase
{

    // MARK: - 1) AxisView always present + carries refs

    func testAxisViewCarriesAllFields() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "world-anchor-S",
                centerlineRules: ["a", "b", "c"],
                deviationCodes: ["d1", "d2"],
                heavenGateID: "gate-S",
                heavenGateIsReady: true,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID: "W1",
                jadeCanonSealRef: "jade-permit-S",
                riverOriginRef: "river-S")
        XCTAssertEqual(result.axisView.worldRef,
                       "world-anchor-S")
        XCTAssertEqual(result.axisView.centerlinePriors,
                       ["a", "b", "c"])
        XCTAssertEqual(result.axisView.deviationPatterns,
                       ["d1", "d2"])
        XCTAssertEqual(result.axisView.scaleLadders,
                       ["personal", "civilizational"])
        XCTAssertEqual(result.axisView.orderConstraints,
                       ["a", "b", "c"])
    }

    // MARK: - 2) Tianmen warrant mints when ready + warrant exists

    func testTianmenWarrantMintedWhenReadyAndWarrantExists() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "world-S",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "gate-X",
                heavenGateIsReady: true,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID: "W1",
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        let warrant = result.tianmenWarrant
        XCTAssertNotNil(warrant)
        XCTAssertEqual(warrant?.warrantID,
                       "tianmen-warrant-W1")
        XCTAssertEqual(warrant?.actionRef, "permit-answer")
        XCTAssertEqual(warrant?.gateRef, "gate-X")
        XCTAssertEqual(warrant?.sovereignBasis, "W1")
        XCTAssertEqual(warrant?.jadeCanonSealRef, "JS")
        XCTAssertEqual(warrant?.riverOriginRef, "RS")
        XCTAssertEqual(warrant?.passScope, .scoped)
    }

    // MARK: - 3) No warrant when not ready

    func testNoTianmenWarrantWhenNotReady() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: false,
                heavenGateReasonCodes: ["nope"],
                firstSovereignWarrantID: "W1",
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        XCTAssertNil(result.tianmenWarrant)
    }

    // MARK: - 4) No warrant when warrant ID missing

    func testNoTianmenWarrantWhenWarrantIDMissing() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: true,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID: nil,
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        XCTAssertNil(result.tianmenWarrant)
    }

    // MARK: - 5) Gate denial writ mints when NOT ready + reasons present

    func testGateDenialMintedWhenNotReadyWithReasons() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .block,
                primaryCandidateID: "C-X",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: false,
                heavenGateReasonCodes:
                    ["abyssal-extreme"],
                firstSovereignWarrantID: nil,
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        let writ = result.gateDenialWrit
        XCTAssertNotNil(writ)
        XCTAssertEqual(writ?.writID, "tianmen-writ-S")
        XCTAssertEqual(writ?.sourceRef, "C-X")
        XCTAssertEqual(writ?.deniedDomain,
                       "domain-block")
        XCTAssertEqual(writ?.reasonCodes,
                       ["abyssal-extreme"])
        XCTAssertEqual(writ?.returnPathRef,
                       "rollback-S")
    }

    // MARK: - 6) No writ when reasons empty (该断时断 doctrine)

    func testNoWritWhenNotReadyButReasonsEmpty() {
        let result =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: false,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID: nil,
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        XCTAssertNil(result.gateDenialWrit)
    }

    // MARK: - 7) Warrant + denial mutually exclusive

    func testWarrantAndDenialAreMutuallyExclusive() {
        let ready =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .answer,
                primaryCandidateID: "C",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: true,
                heavenGateReasonCodes: [],
                firstSovereignWarrantID: "W1",
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        XCTAssertNotNil(ready.tianmenWarrant)
        XCTAssertNil(ready.gateDenialWrit)

        let blocked =
            BASTurnAuditProjectionsKunlunTianmenTrio.compute(
                sessionID: "S",
                permitMode: .block,
                primaryCandidateID: "C",
                worldAnchorRef: "W",
                centerlineRules: ["a"],
                deviationCodes: [],
                heavenGateID: "G",
                heavenGateIsReady: false,
                heavenGateReasonCodes: ["x"],
                firstSovereignWarrantID: nil,
                jadeCanonSealRef: "JS",
                riverOriginRef: "RS")
        XCTAssertNil(blocked.tianmenWarrant)
        XCTAssertNotNil(blocked.gateDenialWrit)
    }
}
