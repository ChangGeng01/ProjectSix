// MARK: - BASAuditObservationProjectionsObservationBundles
//         BlockConvenienceInitTests
// chapter 五百十四 / M1434 — convenience init tests
//
// PROOF tests for the M1434 convenience init on
// BASAuditObservationProjections that accepts a
// BASAuditObservationProjectionsObservationBundlesBlock。
//
// Critical invariant: calling the convenience init with
// the block produces a BASAuditObservationProjections
// value equal to calling the all-fields init with the
// 11 unpacked field values directly。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsObservationBundlesBlockConvenienceInitTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makePresence()
        -> BASPresenceObservationBundle
    {
        return BASPresenceObservationBundle(
            turnID: "t",
            sessionID: "s",
            observations: [],
            emittedAt: Date(
                timeIntervalSince1970: 1_705_000_000))
    }

    private func makeRisk()
        -> BASRiskObservationBundle
    {
        return BASRiskObservationBundle(
            turnID: "t",
            sessionID: "s",
            observations: [],
            emittedAt: Date(
                timeIntervalSince1970: 1_705_000_000))
    }

    // MARK: - 1) Convenience init equals all-fields init

    /// CRITICAL byte-equality PROOF: calling the
    /// convenience init with the block produces a
    /// BASAuditObservationProjections EQUAL to calling
    /// the all-fields init with the 11 unpacked field
    /// values directly。
    func testConvenienceInitEqualsAllFieldsInit() {
        let p = makePresence()
        let r = makeRisk()
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p,
                risk: r)
        let viaConvenience =
            BASAuditObservationProjections(
                observationBundles: block)
        let viaAllFields = BASAuditObservationProjections(
            presenceObservationBundle: p,
            riskObservationBundle: r)
        XCTAssertEqual(
            viaConvenience, viaAllFields,
            "convenience init MUST produce byte-equal" +
            " result to all-fields init with same" +
            " bundle field values")
    }

    // MARK: - 2) Non-bundle fields default to nil/empty

    func testNonBundleFieldsDefault() {
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock
                .empty
        let p = BASAuditObservationProjections(
            observationBundles: block)
        XCTAssertNil(p.candidateObservationBundle)
        XCTAssertNil(p.tribunalObservationBundle)
        XCTAssertNil(p.abyssalPressure)
        XCTAssertNil(p.humanAnchorSignal)
        XCTAssertEqual(p.abyssalBranches, [])
        XCTAssertEqual(p.escalationSuppressionCodes, [])
    }

    // MARK: - 3) Non-bundle args propagate verbatim

    func testNonBundleArgsPropagate() {
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock
                .empty
        let codes = ["esc-1", "esc-2"]
        let p = BASAuditObservationProjections(
            observationBundles: block,
            escalationSuppressionCodes: codes)
        XCTAssertEqual(
            p.escalationSuppressionCodes, codes)
    }

    // MARK: - 4) 11 cognitive fields populate on result

    func testElevenCognitiveFieldsPopulate() {
        let p = makePresence()
        let r = makeRisk()
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p,
                risk: r)
        let result = BASAuditObservationProjections(
            observationBundles: block)
        XCTAssertEqual(
            result.presenceObservationBundle, p)
        XCTAssertEqual(
            result.riskObservationBundle, r)
        // Remaining 9 bundle fields stay nil
        XCTAssertNil(
            result.decompositionObservationBundle)
        XCTAssertNil(result.softHandObservationBundle)
        XCTAssertNil(result.leaseLifeObservationBundle)
        XCTAssertNil(
            result.hostConstitutionObservationBundle)
        XCTAssertNil(
            result.thoughtFoldObservationBundle)
        XCTAssertNil(
            result.neuralOrganObservationBundle)
        XCTAssertNil(
            result.hippocampalMemoryObservationBundle)
        XCTAssertNil(
            result.worldPriorObservationBundle)
        XCTAssertNil(
            result.updateTicketObservationBundle)
    }

    // MARK: - 5) Empty block produces empty bundle fields

    func testEmptyBlockProducesEmptyBundleFields() {
        let p = BASAuditObservationProjections(
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty)
        XCTAssertNil(p.presenceObservationBundle)
        XCTAssertNil(p.riskObservationBundle)
        XCTAssertNil(p.updateTicketObservationBundle)
    }

    // MARK: - 6) Determinism

    func testDeterminismAcrossRepeatCalls() {
        let p = makePresence()
        let block =
            BASAuditObservationProjectionsObservationBundlesBlock(
                presence: p)
        let r1 = BASAuditObservationProjections(
            observationBundles: block)
        let r2 = BASAuditObservationProjections(
            observationBundles: block)
        XCTAssertEqual(r1, r2)
    }
}
