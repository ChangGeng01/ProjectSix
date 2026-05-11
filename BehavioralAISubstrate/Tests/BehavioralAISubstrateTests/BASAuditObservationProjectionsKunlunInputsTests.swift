// MARK: - BASAuditObservationProjectionsKunlunInputsTests
// chapter 五百十一 / M1421 — V1 monolith fold continues
//
// PROOF tests for the Kunlun inputs typed-surface block:
//   1. compose() produces all 4 typed trio outputs
//   2. Pass-through accessors return the same fields as
//      the underlying trios (no transformation)
//   3. Determinism — same inputs produce same outputs
//   4. Hashable + Sendable conformance (compile-time)
//   5. kunlunFieldCount pinned to 18 (anti-drift)
//   6. Round-trip: trio fields equal block-accessor fields

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASAuditObservationProjectionsKunlunInputsTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeBudget(
        runMode: BASEBrainRunMode = .engage
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: runMode,
            maxLoops: 3,
            maxCandidates: 4,
            maxDecodeTokens: 256,
            retrievalDepth: 5,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            leaseID: "lease-block",
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
            reasonCodes: ["pilot"],
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
            BASCandidatePath(
                candidateID: "c-b",
                title: "Path B",
                actionSummary: "summary-b",
                expectedBenefit: 0.6,
                expectedCost: 0.3,
                reversibility: 0.8,
                confidence: 0.6),
        ]
    }

    private func makeAllFourTrios() -> (
        trio: BASTurnAuditProjectionsKunlunTrio,
        hexa: BASTurnAuditProjectionsKunlunHexa,
        trioTwo: BASTurnAuditProjectionsKunlunTrioTwo,
        hexaTwo: BASTurnAuditProjectionsKunlunHexaTwo
    ) {
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        let trio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "turn-block",
                sessionID: "session-block",
                kunlunAxisID: "axis-block")
        let hexa = BASTurnAuditProjectionsKunlunHexa
            .compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                permit: permit,
                candidates: candidates,
                turnID: "turn-block")
        let trioTwo = BASTurnAuditProjectionsKunlunTrioTwo
            .compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                candidates: candidates,
                organRefMorph: "morph.a",
                turnID: "turn-block",
                sessionID: "session-block")
        let hexaTwo = BASTurnAuditProjectionsKunlunHexaTwo
            .compute(
                hostID: "host-block",
                sessionID: "session-block",
                turnID: "turn-block",
                unknownRefs: ["u-1"],
                assertionCeiling: .qualified,
                riskLevel: .medium,
                candidates: candidates)
        return (trio, hexa, trioTwo, hexaTwo)
    }

    // MARK: - 1) compose() produces all 4 trio outputs

    func testComposeProducesAllFourTrioOutputs() {
        let parts = makeAllFourTrios()
        let inputs =
            BASAuditObservationProjectionsKunlunInputs
                .compose(
                    trio: parts.trio,
                    hexa: parts.hexa,
                    trioTwo: parts.trioTwo,
                    hexaTwo: parts.hexaTwo)
        XCTAssertEqual(inputs.trio, parts.trio)
        XCTAssertEqual(inputs.hexa, parts.hexa)
        XCTAssertEqual(inputs.trioTwo, parts.trioTwo)
        XCTAssertEqual(inputs.hexaTwo, parts.hexaTwo)
    }

    // MARK: - 2) Pass-through accessors mirror trios

    func testPassThroughAccessorsMirrorUnderlyingTrios() {
        let parts = makeAllFourTrios()
        let inputs =
            BASAuditObservationProjectionsKunlunInputs(
                trio: parts.trio,
                hexa: parts.hexa,
                trioTwo: parts.trioTwo,
                hexaTwo: parts.hexaTwo)
        // Trio fields
        XCTAssertEqual(
            inputs.ascentLease, parts.trio.ascentLease)
        XCTAssertEqual(
            inputs.axisDeviation, parts.trio.axisDeviation)
        XCTAssertEqual(
            inputs.gatePressure, parts.trio.gatePressure)
        // Hexa fields
        XCTAssertEqual(
            inputs.yaochiMemoryLayer,
            parts.hexa.yaochiMemoryLayer)
        XCTAssertEqual(
            inputs.tianhengProfile,
            parts.hexa.tianhengProfile)
        XCTAssertEqual(
            inputs.jadePermitGrade,
            parts.hexa.jadePermitGrade)
        XCTAssertEqual(
            inputs.ascentBranches,
            parts.hexa.ascentBranches)
        XCTAssertEqual(
            inputs.restSteps, parts.hexa.restSteps)
        XCTAssertEqual(
            inputs.returnPaths, parts.hexa.returnPaths)
        // Trio #2 fields
        XCTAssertEqual(
            inputs.jadeCasket, parts.trioTwo.jadeCasket)
        XCTAssertEqual(
            inputs.jadeRefinementTickets,
            parts.trioTwo.jadeRefinementTickets)
        XCTAssertEqual(
            inputs.jadeFidelityMap,
            parts.trioTwo.jadeFidelityMap)
        // Hexa #2 fields
        XCTAssertEqual(
            inputs.hostJadeRegister,
            parts.hexaTwo.hostJadeRegister)
        XCTAssertEqual(
            inputs.jadeMirrorDraft,
            parts.hexaTwo.jadeMirrorDraft)
        XCTAssertEqual(
            inputs.kunlunUnnamableSet,
            parts.hexaTwo.kunlunUnnamableSet)
        XCTAssertEqual(
            inputs.returnPathRefs,
            parts.hexaTwo.returnPathRefs)
        XCTAssertEqual(
            inputs.kunlunAscentView,
            parts.hexaTwo.kunlunAscentView)
        XCTAssertEqual(
            inputs.kunlunFarWestReserve,
            parts.hexaTwo.kunlunFarWestReserve)
    }

    // MARK: - 3) Determinism — same inputs produce same outputs

    func testDeterminismAcrossRepeatComposeCalls() {
        let parts = makeAllFourTrios()
        let inputs1 =
            BASAuditObservationProjectionsKunlunInputs(
                trio: parts.trio,
                hexa: parts.hexa,
                trioTwo: parts.trioTwo,
                hexaTwo: parts.hexaTwo)
        let inputs2 =
            BASAuditObservationProjectionsKunlunInputs(
                trio: parts.trio,
                hexa: parts.hexa,
                trioTwo: parts.trioTwo,
                hexaTwo: parts.hexaTwo)
        XCTAssertEqual(inputs1, inputs2)
        XCTAssertEqual(
            inputs1.hashValue, inputs2.hashValue,
            "Hashable conformance must agree with " +
            "Equatable")
    }

    // MARK: - 4) Hashable + Sendable conformance

    /// Compile-time test: if BASAuditObservationProjections
    /// KunlunInputs ever loses Hashable or Sendable
    /// conformance,this method body fails to compile.
    func testHashableAndSendableConformance() {
        let parts = makeAllFourTrios()
        let inputs =
            BASAuditObservationProjectionsKunlunInputs(
                trio: parts.trio,
                hexa: parts.hexa,
                trioTwo: parts.trioTwo,
                hexaTwo: parts.hexaTwo)
        var set: Set<
            BASAuditObservationProjectionsKunlunInputs> = []
        set.insert(inputs)
        XCTAssertEqual(set.count, 1)
        // Sendable check — pass through closure-captured
        // reference compile-time gate
        let captured: @Sendable () ->
            BASAuditObservationProjectionsKunlunInputs = {
            inputs
        }
        XCTAssertEqual(captured(), inputs)
    }

    // MARK: - 5) kunlunFieldCount pinned to 18

    /// Anti-drift PROOF: if a future trio adds a field,
    /// this constant moves AND BASAuditObservation
    /// Projections gains a matching field, OR the audit
    /// emission silently loses coverage. The number 18
    /// is the chapter-511-ship count.
    func testKunlunFieldCountPinnedToEighteen() {
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunInputs
                .kunlunFieldCount,
            18,
            "Kunlun field count must match" +
            " BASAuditObservationProjections" +
            " kunlun-source field count")
    }

    // MARK: - 6) Different inputs produce different outputs

    func testDifferentInputsProduceDifferentOutputs() {
        let partsA = makeAllFourTrios()
        let inputsA =
            BASAuditObservationProjectionsKunlunInputs(
                trio: partsA.trio,
                hexa: partsA.hexa,
                trioTwo: partsA.trioTwo,
                hexaTwo: partsA.hexaTwo)
        // Recompute with different turn/session IDs
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        let trioB = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "turn-OTHER",
                sessionID: "session-OTHER",
                kunlunAxisID: "axis-OTHER")
        let inputsB =
            BASAuditObservationProjectionsKunlunInputs(
                trio: trioB,
                hexa: partsA.hexa,
                trioTwo: partsA.trioTwo,
                hexaTwo: partsA.hexaTwo)
        XCTAssertNotEqual(
            inputsA, inputsB,
            "Different trio inputs must produce" +
            " different blocks")
    }
}
