// MARK: - BASAuditObservationProjectionsFiveBlockUnified
//         InitTests
// chapter 五百十七 / M1446 — 5-block unified init tests
//
// PROOF tests for the M1446 5-block unified convenience
// init that takes ALL FIVE input blocks (Kunlun +
// Cthulhu + ObservationBundles + KunlunProtocol +
// CthulhuAggregates).

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsFiveBlockUnifiedInitTests:
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
            leaseID: "lease-5b",
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
            reasonCodes: ["5b"],
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

    private func makeAggregatesBlock()
        -> BASAuditObservationProjectionsCthulhuAggregatesBlock
    {
        return BASAuditObservationProjectionsCthulhuAggregatesBlock(
            abyssalBranches: [
                BASAbyssalBranch(
                    branchID: "b-1",
                    sourceCandidateRef: "c-a",
                    triggerReasons: ["r-1"],
                    unknownLoad: 0.5,
                    manipulationLoad: 0.1,
                    ontologyDistortion: 0.2,
                    protectivePathRefs: [],
                    requiredClosureConditions: []),
            ])
    }

    // MARK: - 1) 5-block init equals 4-block + aggregates

    func testFiveBlockInitEqualsFourBlockPlusAggregates() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let ob = BASAuditObservationProjectionsObservationBundlesBlock
            .empty
        let kp = BASAuditObservationProjectionsKunlunProtocolBlock
            .empty
        let ag = makeAggregatesBlock()
        let viaFiveBlock = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp,
            cthulhuAggregatesBlock: ag)
        let viaFourBlock = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles: ob,
            kunlunProtocolBlock: kp,
            abyssalBranches: ag.abyssalBranches)
        XCTAssertEqual(viaFiveBlock, viaFourBlock)
    }

    // MARK: - 2) Aggregate fields land correctly

    func testAggregateFieldsLandCorrectly() {
        let ag = makeAggregatesBlock()
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock: ag)
        XCTAssertEqual(
            result.abyssalBranches, ag.abyssalBranches)
        XCTAssertNil(result.abyssalPressure)
        XCTAssertNil(result.humanAnchorSignal)
        XCTAssertNil(result.sealAggregate)
        XCTAssertNil(result.lifecycleAggregate)
        XCTAssertNil(result.narrativeDistortion)
        XCTAssertNil(result.anomalyTrace)
    }

    // MARK: - 3) Determinism

    func testDeterminism() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let ag = makeAggregatesBlock()
        let r1 = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock: ag)
        let r2 = BASAuditObservationProjections(
            kunlunInputs: ki,
            cthulhuInputs: ci,
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock: ag)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 4) Empty aggregates block produces nil aggregates

    func testEmptyAggregatesBlockProducesEmptyAggregates() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock:
                BASAuditObservationProjectionsCthulhuAggregatesBlock
                    .empty)
        XCTAssertNil(result.abyssalPressure)
        XCTAssertNil(result.humanAnchorSignal)
        XCTAssertEqual(result.abyssalBranches, [])
    }

    // MARK: - 5) Non-block args propagate

    func testNonBlockArgsPropagate() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock:
                BASAuditObservationProjectionsCthulhuAggregatesBlock
                    .empty,
            escalationSuppressionCodes: ["esc-1"])
        XCTAssertEqual(
            result.escalationSuppressionCodes, ["esc-1"])
    }

    // MARK: - 6) All-empty baseline

    func testAllEmptyBlocksBaseline() {
        let result = BASAuditObservationProjections(
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs(),
            observationBundles:
                BASAuditObservationProjectionsObservationBundlesBlock
                    .empty,
            kunlunProtocolBlock:
                BASAuditObservationProjectionsKunlunProtocolBlock
                    .empty,
            cthulhuAggregatesBlock:
                BASAuditObservationProjectionsCthulhuAggregatesBlock
                    .empty)
        XCTAssertNil(result.candidateObservationBundle)
        XCTAssertEqual(
            result.escalationSuppressionCodes, [])
        XCTAssertEqual(
            result.cthulhuAssertionCeilingReasonCodes, [])
    }
}
