// MARK: - BASAuditObservationProjectionsKunlunInputs
//         ConvenienceInitTests
// chapter 五百十一 / M1422 — V1 monolith fold continues
//
// PROOF tests for the M1422 convenience init on
// BASAuditObservationProjections that accepts a
// BASAuditObservationProjectionsKunlunInputs block。
//
// Critical invariant: calling the convenience init with the
// kunlun inputs block produces a BASAuditObservation
// Projections value equal to calling the all-fields init
// with the 18 unpacked field values directly。 This is the
// byte-equality regression guard for M1423 splice into V1
// monolith。

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsKunlunInputsConvenienceInitTests:
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
            leaseID: "lease-conv",
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
            reasonCodes: ["conv"],
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

    private func makeInputs()
        -> BASAuditObservationProjectionsKunlunInputs
    {
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        let trio = BASTurnAuditProjectionsKunlunTrio.compute(
            routedBudget: budget,
            riskLevel: .medium,
            permit: permit,
            turnID: "turn-conv",
            sessionID: "session-conv",
            kunlunAxisID: "axis-conv")
        let hexa = BASTurnAuditProjectionsKunlunHexa.compute(
            runMode: budget.runMode,
            riskLevel: .medium,
            permit: permit,
            candidates: candidates,
            turnID: "turn-conv")
        let trioTwo =
            BASTurnAuditProjectionsKunlunTrioTwo.compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                candidates: candidates,
                organRefMorph: "morph.a",
                turnID: "turn-conv",
                sessionID: "session-conv")
        let hexaTwo =
            BASTurnAuditProjectionsKunlunHexaTwo.compute(
                hostID: "host-conv",
                sessionID: "session-conv",
                turnID: "turn-conv",
                unknownRefs: ["u-1"],
                assertionCeiling: .qualified,
                riskLevel: .medium,
                candidates: candidates)
        return BASAuditObservationProjectionsKunlunInputs(
            trio: trio,
            hexa: hexa,
            trioTwo: trioTwo,
            hexaTwo: hexaTwo)
    }

    // MARK: - 1) Convenience init equals all-fields init

    /// CRITICAL byte-equality PROOF: the convenience init
    /// must produce a result EQUAL to the all-fields init
    /// when called with the 18 unpacked Kunlun fields。
    /// If this fails, any V1 monolith splice (M1423) would
    /// silently corrupt audit emission。
    func testConvenienceInitEqualsAllFieldsInit() {
        let inputs = makeInputs()
        let viaConvenience =
            BASAuditObservationProjections(
                kunlunInputs: inputs)
        let viaAllFields = BASAuditObservationProjections(
            ascentLease: inputs.ascentLease,
            axisDeviation: inputs.axisDeviation,
            gatePressure: inputs.gatePressure,
            yaochiMemoryLayer: inputs.yaochiMemoryLayer,
            tianhengProfile: inputs.tianhengProfile,
            jadePermitGrade: inputs.jadePermitGrade,
            ascentBranches: inputs.ascentBranches,
            restSteps: inputs.restSteps,
            returnPaths: inputs.returnPaths,
            jadeCasket: inputs.jadeCasket,
            jadeRefinementTickets:
                inputs.jadeRefinementTickets,
            jadeFidelityMap: inputs.jadeFidelityMap,
            hostJadeRegister: inputs.hostJadeRegister,
            jadeMirrorDraft: inputs.jadeMirrorDraft,
            kunlunUnnamableSet: inputs.kunlunUnnamableSet,
            kunlunAscentView: inputs.kunlunAscentView,
            kunlunFarWestReserve:
                inputs.kunlunFarWestReserve)
        XCTAssertEqual(
            viaConvenience, viaAllFields,
            "convenience init MUST produce byte-equal" +
            " result to all-fields init with same" +
            " Kunlun field values")
    }

    // MARK: - 2) Non-Kunlun fields default correctly

    func testNonKunlunFieldsDefaultToNilOrEmpty() {
        let inputs = makeInputs()
        let p = BASAuditObservationProjections(
            kunlunInputs: inputs)
        XCTAssertNil(p.candidateObservationBundle)
        XCTAssertNil(p.tribunalObservationBundle)
        XCTAssertNil(p.abyssalPressure)
        XCTAssertNil(p.humanAnchorSignal)
        XCTAssertNil(p.sealAggregate)
        XCTAssertNil(p.lifecycleAggregate)
        XCTAssertNil(p.narrativeDistortion)
        XCTAssertEqual(p.abyssalBranches, [])
        XCTAssertEqual(p.escalationSuppressionCodes, [])
        XCTAssertEqual(
            p.cthulhuAssertionCeilingReasonCodes, [])
        XCTAssertEqual(
            p.cthulhuPermitEscalationReasonCodes, [])
    }

    // MARK: - 3) Non-Kunlun args propagate verbatim

    func testNonKunlunFieldsPropagateThroughInit() {
        let inputs = makeInputs()
        let codes = ["esc-1", "esc-2"]
        let p = BASAuditObservationProjections(
            kunlunInputs: inputs,
            escalationSuppressionCodes: codes,
            cthulhuAssertionCeilingReasonCodes: ["a-1"],
            cthulhuPermitEscalationReasonCodes: ["p-1"])
        XCTAssertEqual(
            p.escalationSuppressionCodes, codes)
        XCTAssertEqual(
            p.cthulhuAssertionCeilingReasonCodes, ["a-1"])
        XCTAssertEqual(
            p.cthulhuPermitEscalationReasonCodes, ["p-1"])
    }

    // MARK: - 4) Kunlun fields end up populated on result

    func testKunlunFieldsPopulatedOnResult() {
        let inputs = makeInputs()
        let p = BASAuditObservationProjections(
            kunlunInputs: inputs)
        XCTAssertEqual(p.ascentLease, inputs.ascentLease)
        XCTAssertEqual(
            p.axisDeviation, inputs.axisDeviation)
        XCTAssertEqual(p.gatePressure, inputs.gatePressure)
        XCTAssertEqual(
            p.yaochiMemoryLayer, inputs.yaochiMemoryLayer)
        XCTAssertEqual(
            p.tianhengProfile, inputs.tianhengProfile)
        XCTAssertEqual(
            p.jadePermitGrade, inputs.jadePermitGrade)
        XCTAssertEqual(
            p.ascentBranches, inputs.ascentBranches)
        XCTAssertEqual(p.restSteps, inputs.restSteps)
        XCTAssertEqual(
            p.returnPaths, inputs.returnPaths)
        XCTAssertEqual(p.jadeCasket, inputs.jadeCasket)
        XCTAssertEqual(
            p.jadeRefinementTickets,
            inputs.jadeRefinementTickets)
        XCTAssertEqual(
            p.jadeFidelityMap, inputs.jadeFidelityMap)
        XCTAssertEqual(
            p.hostJadeRegister, inputs.hostJadeRegister)
        XCTAssertEqual(
            p.jadeMirrorDraft, inputs.jadeMirrorDraft)
        XCTAssertEqual(
            p.kunlunUnnamableSet,
            inputs.kunlunUnnamableSet)
        XCTAssertEqual(
            p.kunlunAscentView, inputs.kunlunAscentView)
        XCTAssertEqual(
            p.kunlunFarWestReserve,
            inputs.kunlunFarWestReserve)
    }

    // MARK: - 5) Determinism — same inputs produce same output

    func testDeterminismAcrossRepeatCalls() {
        let inputs = makeInputs()
        let p1 = BASAuditObservationProjections(
            kunlunInputs: inputs)
        let p2 = BASAuditObservationProjections(
            kunlunInputs: inputs)
        XCTAssertEqual(p1, p2)
    }

    // MARK: - 6) Different inputs produce different output

    func testDifferentInputsProduceDifferentOutputs() {
        let inputsA = makeInputs()
        let trioB =
            BASTurnAuditProjectionsKunlunTrio.compute(
                routedBudget: makeBudget(),
                riskLevel: .medium,
                permit: makePermit(),
                turnID: "turn-OTHER",
                sessionID: "session-OTHER",
                kunlunAxisID: "axis-OTHER")
        let inputsB =
            BASAuditObservationProjectionsKunlunInputs(
                trio: trioB,
                hexa: inputsA.hexa,
                trioTwo: inputsA.trioTwo,
                hexaTwo: inputsA.hexaTwo)
        let pA = BASAuditObservationProjections(
            kunlunInputs: inputsA)
        let pB = BASAuditObservationProjections(
            kunlunInputs: inputsB)
        XCTAssertNotEqual(pA, pB)
    }
}
