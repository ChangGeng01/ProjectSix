// MARK: - BASAuditObservationProjectionsBundleEmitterTests
// chapter 五百十三 / M1429 — emitter facade tests
//
// PROOF tests for the typed facade routing projection-
// block observations:
//   1. Both inputs → .fullyCovered routing
//   2. kunlun only → .kunlunOnly routing
//   3. cthulhu only → .cthulhuOnly routing
//   4. Both nil → .uncovered routing
//   5. emit() forwards to observer.recordEmission
//   6. makeObservation() is pure (no actor mutation)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsBundleEmitterTests:
    XCTestCase
{

    // MARK: - Fixtures (reuse standard pattern)

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
            leaseID: "lease-emit",
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
            reasonCodes: ["emit"],
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
        let penta = BASTurnAuditProjectionsCthulhuPenta
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
                    BASUnknownAssertionCeiling.qualified
                        .rawValue,
                turnID: "t")
        return BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio: trio,
            cthulhuPenta: penta)
    }

    private func fixedDate() -> Date {
        return Date(timeIntervalSince1970: 1_705_000_000)
    }

    // MARK: - 1) both inputs → fullyCovered

    func testFacadeRoutesToFullyCovered() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let obs =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        XCTAssertTrue(obs.hasBothBlocks)
        XCTAssertEqual(
            obs.kunlunInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ki))
        XCTAssertEqual(
            obs.cthulhuInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ci))
    }

    // MARK: - 2) kunlun only → kunlunOnly

    func testFacadeRoutesToKunlunOnly() {
        let ki = makeKunlunInputs()
        let obs =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: nil)
        XCTAssertTrue(obs.kunlunCovered)
        XCTAssertFalse(obs.cthulhuCovered)
        XCTAssertEqual(
            obs.kunlunInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ki))
        XCTAssertNil(obs.cthulhuInputsHash)
    }

    // MARK: - 3) cthulhu only → cthulhuOnly

    func testFacadeRoutesToCthulhuOnly() {
        let ci = makeCthulhuInputs()
        let obs =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: nil,
                    cthulhuInputs: ci)
        XCTAssertFalse(obs.kunlunCovered)
        XCTAssertTrue(obs.cthulhuCovered)
        XCTAssertNil(obs.kunlunInputsHash)
        XCTAssertEqual(
            obs.cthulhuInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ci))
    }

    // MARK: - 4) both nil → uncovered

    func testFacadeRoutesToUncovered() {
        let obs =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: nil,
                    cthulhuInputs: nil)
        XCTAssertFalse(obs.kunlunCovered)
        XCTAssertFalse(obs.cthulhuCovered)
        XCTAssertEqual(obs.populatedBlockCount, 0)
    }

    // MARK: - 5) emit() forwards to observer

    func testEmitForwardsToObserver() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        await BASAuditObservationProjectionsBundleEmitter
            .emit(
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate(),
                to: observer,
                kunlunInputs: ki,
                cthulhuInputs: ci)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.count, 1)
        XCTAssertTrue(snap[0].hasBothBlocks)
        XCTAssertEqual(snap[0].turnID, "t")
    }

    // MARK: - 6) makeObservation is pure — no actor needed

    func testMakeObservationIsPureSync() {
        // Compile-time check: the function returns
        // synchronously without await — if a future
        // refactor accidentally makes it async, this
        // test fails to compile.
        let obs =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: nil,
                    cthulhuInputs: nil)
        // Repeated calls produce identical results
        // (purity invariant)
        let obs2 =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: nil,
                    cthulhuInputs: nil)
        XCTAssertEqual(obs, obs2)
    }
}
