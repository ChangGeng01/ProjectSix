// MARK: - BASAuditObservationProjectionsFourBlockUnified
//         InitTests
// chapter 五百十六 / M1442 — 4-block unified init tests
//
// PROOF tests for the M1442 4-block unified convenience
// init that takes ALL FOUR input blocks (Kunlun +
// Cthulhu + ObservationBundles + KunlunProtocol):
//   1. 4-block init equals 3-block init + protocol fields
//   2. Protocol block fields land in correct slots
//   3. Non-block args propagate verbatim
//   4. Determinism — same blocks produce same output
//   5. Empty protocol block produces nil protocol fields
//   6. All-blocks-populated baseline with default residuals

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsFourBlockUnifiedInitTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeBudget() -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 4,
            maxDecodeTokens: 256,
            retrievalDepth: 5,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            leaseID: "lease-4b",
            leaseExpiresAt: Date(
                timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["primary"],
            policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["d1"])
    }

    private func makePermit() -> BASActionPermit {
        return BASActionPermit(
            mode: .answer,
            reasonCodes: ["4b"],
            outputLengthCap: 200,
            tonePolicy: "calm",
            templatePolicy: "default")
    }

    private func makeCandidates() -> [BASCandidatePath] {
        return [
            BASCandidatePath(
                candidateID: "c-a",
                title: "Path A",
                actionSummary: "summary-a",
                expectedBenefit: 0.7,
                expectedCost: 0.2,
                reversibility: 0.9,
                confidence: 0.7),
        ]
    }

    private func makeKunlunInputs()
        -> BASAuditObservationProjectionsKunlunInputs
    {
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        return BASAuditObservationProjectionsKunlunInputs(
            trio: BASTurnAuditProjectionsKunlunTrio.compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "t",
                sessionID: "s",
                kunlunAxisID: "a"),
            hexa: BASTurnAuditProjectionsKunlunHexa.compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                permit: permit,
                candidates: candidates,
                turnID: "t"),
            trioTwo:
                BASTurnAuditProjectionsKunlunTrioTwo
                    .compute(
                        runMode: budget.runMode,
                        riskLevel: .medium,
                        candidates: candidates,
                        organRefMorph: "m",
                        turnID: "t",
                        sessionID: "s"),
            hexaTwo:
                BASTurnAuditProjectionsKunlunHexaTwo
                    .compute(
                        hostID: "h",
                        sessionID: "s",
                        turnID: "t",
                        unknownRefs: ["u-1"],
                        assertionCeiling: .qualified,
                        riskLevel: .medium,
                        candidates: candidates))
    }

    private func makeCthulhuInputs()
        -> BASAuditObservationProjectionsCthulhuInputs
    {
        let budget = makeBudget()
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: budget,
                    turnID: "t")
        return BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio: trio,
            cthulhuPenta:
                BASTurnAuditProjectionsCthulhuPenta
                    .compute(
                        routedBudget: budget,
                        runMode: budget.runMode,
                        hostID: "h",
                        riskLevel: .medium,
                        memoryTemperatureLayer:
                            trio.memoryTemperatureLayer,
                        candidates: makeCandidates(),
                        unknownRefs: ["u-1"],
                        assertionCeilingRaw:
                            BASUnknownAssertionCeiling
                                .qualified.rawValue,
                        turnID: "t"))
    }

    private func makeObservationBundles()
        -> BASAuditObservationProjectionsObservationBundlesBlock
    {
        return BASAuditObservationProjectionsObservationBundlesBlock
            .empty
    }

    private func makeKunlunProtocolBlock()
        -> BASAuditObservationProjectionsKunlunProtocolBlock
    {
        return BASAuditObservationProjectionsKunlunProtocolBlock(
            jadeCanonObjectClass: .actionPermit,
            yaochiSanctumClass: .boundary,
            tianmenGateClass: .public,
            tianmenPassState: .passed)
    }

    // MARK: - 1) 4-block init equals 3-block + protocol fields

    /// CRITICAL byte-equality PROOF: the 4-block init
    /// produces a value EQUAL to the 3-block init with
    /// the 9 protocol fields unpacked as named args。
    func testFourBlockInitEqualsThreeBlockPlusProtocolFields() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let ob = makeObservationBundles()
        let kp = makeKunlunProtocolBlock()
        let viaFourBlock = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp)
        let viaThreeBlock = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            jadeCanonObjectClass:
                kp.jadeCanonObjectClass,
            yaochiSanctumClass:
                kp.yaochiSanctumClass,
            tianmenGateClass: kp.tianmenGateClass,
            tianmenPassState: kp.tianmenPassState)
        XCTAssertEqual(viaFourBlock, viaThreeBlock)
    }

    // MARK: - 2) Protocol block fields land correctly

    func testProtocolBlockFieldsLandCorrectly() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let ob = makeObservationBundles()
        let kp = makeKunlunProtocolBlock()
        let result = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp)
        XCTAssertEqual(
            result.jadeCanonObjectClass,
            kp.jadeCanonObjectClass)
        XCTAssertEqual(
            result.yaochiSanctumClass,
            kp.yaochiSanctumClass)
        XCTAssertEqual(
            result.tianmenGateClass,
            kp.tianmenGateClass)
        XCTAssertEqual(
            result.tianmenPassState,
            kp.tianmenPassState)
    }

    // MARK: - 3) Non-block args propagate verbatim

    func testNonBlockArgsPropagate() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles: makeObservationBundles(),
            kunlunProtocolBlock:
                makeKunlunProtocolBlock(),
            escalationSuppressionCodes:
                ["esc-1", "esc-2"],
            cthulhuAssertionCeilingReasonCodes:
                ["a-1"])
        XCTAssertEqual(
            result.escalationSuppressionCodes,
            ["esc-1", "esc-2"])
        XCTAssertEqual(
            result.cthulhuAssertionCeilingReasonCodes,
            ["a-1"])
    }

    // MARK: - 4) Determinism

    func testDeterminism() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let ob = makeObservationBundles()
        let kp = makeKunlunProtocolBlock()
        let r1 = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp)
        let r2 = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 5) Empty protocol block → nil protocol fields

    func testEmptyProtocolBlockNilProtocolFields() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles: makeObservationBundles(),
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty)
        XCTAssertNil(result.jadeCanonObjectClass)
        XCTAssertNil(result.yaochiSanctumClass)
        XCTAssertNil(result.tianmenGateClass)
        XCTAssertNil(result.tianmenPassState)
        XCTAssertNil(result.kunlunAxisAlignment)
        XCTAssertNil(result.jadeCanonVerification)
        XCTAssertNil(result.riverOriginLineage)
        XCTAssertNil(result.yaochiAccess)
        XCTAssertNil(result.tianmenReadiness)
    }

    // MARK: - 6) All-blocks baseline + default residuals

    func testAllBlocksBaselineDefaultResiduals() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles: makeObservationBundles(),
            kunlunProtocolBlock:
                makeKunlunProtocolBlock())
        XCTAssertNil(result.candidateObservationBundle)
        XCTAssertNil(result.tribunalObservationBundle)
        XCTAssertNil(result.narrativeDistortionMap)
        XCTAssertNil(result.cthulhuSurfaceAlias)
        XCTAssertNil(result.kunlunSurfaceAlias)
        XCTAssertEqual(
            result.escalationSuppressionCodes, [])
    }
}
