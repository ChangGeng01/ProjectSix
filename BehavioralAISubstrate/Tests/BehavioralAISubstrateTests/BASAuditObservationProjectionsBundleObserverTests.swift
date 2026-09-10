// MARK: - BASAuditObservationProjectionsBundleObserverTests
// chapter 五百十二 / M1426 — wire-in chain continues
//
// PROOF tests for the actor-isolated projection-block
// observer:
//   1. Empty observer reports zero metrics
//   2. recordEmission appends in arrival order
//   3. recordFullyCoveredEmission convenience builds + appends
//   4. Coverage metrics roll up correctly
//   5. snapshot returns immutable copy (mutation isolation)
//   6. reset clears state

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsBundleObserverTests:
    XCTestCase
{

    // MARK: - Fixtures (reuse M1425 pattern)

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
            leaseID: "lease-obs2",
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
            reasonCodes: ["obs2"],
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

    private func fixedDate(_ offset: TimeInterval = 0)
        -> Date
    {
        return Date(
            timeIntervalSince1970: 1_705_000_000 + offset)
    }

    // MARK: - 1) Empty observer

    func testEmptyObserverReportsZeroMetrics() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let count = await observer.emissionCount
        let full = await observer.fullyCoveredCount
        let cold = await observer.coldEmissionCount
        let ratio = await observer.fullyCoveredRatio
        let cum =
            await observer.cumulativePopulatedBlockCount
        let distinct = await observer.distinctTurnCount
        let snap = await observer.snapshot()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(full, 0)
        XCTAssertEqual(cold, 0)
        XCTAssertEqual(ratio, 0)
        XCTAssertEqual(cum, 0)
        XCTAssertEqual(distinct, 0)
        XCTAssertEqual(snap, [])
    }

    // MARK: - 2) Records preserved in arrival order

    func testRecordEmissionPreservesArrivalOrder() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let obs1 =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t1",
                    sessionID: "s",
                    emittedAt: fixedDate(0),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        let obs2 =
            BASAuditObservationProjectionsBundleObservation
                .uncovered(
                    turnID: "t2",
                    sessionID: "s",
                    emittedAt: fixedDate(1))
        let obs3 =
            BASAuditObservationProjectionsBundleObservation
                .kunlunOnly(
                    turnID: "t3",
                    sessionID: "s",
                    emittedAt: fixedDate(2),
                    kunlunInputs: ki)
        await observer.recordEmission(obs1)
        await observer.recordEmission(obs2)
        await observer.recordEmission(obs3)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(snap[0].turnID, "t1")
        XCTAssertEqual(snap[1].turnID, "t2")
        XCTAssertEqual(snap[2].turnID, "t3")
    }

    // MARK: - 3) Convenience-emission builds + appends

    func testConvenienceFullyCoveredAppendsRecord()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        await observer.recordFullyCoveredEmission(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate(),
            kunlunInputs: ki,
            cthulhuInputs: ci)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.count, 1)
        XCTAssertTrue(snap[0].hasBothBlocks)
        XCTAssertEqual(snap[0].turnID, "t")
        XCTAssertEqual(
            snap[0].kunlunInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ki))
        XCTAssertEqual(
            snap[0].cthulhuInputsHash, BASAuditObservationProjectionsBundleObservation.canonicalInputsDigest(ci))
    }

    // MARK: - 4) Coverage metrics roll up correctly

    func testCoverageMetricsRollUpCorrectly() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        // 2 full + 1 cold + 1 kunlun-only = 4 emissions
        // populated block count: 2*2 + 0 + 1 = 5
        await observer.recordEmission(
            .fullyCovered(
                turnID: "t1",
                sessionID: "s",
                emittedAt: fixedDate(0),
                kunlunInputs: ki,
                cthulhuInputs: ci))
        await observer.recordEmission(
            .fullyCovered(
                turnID: "t2",
                sessionID: "s",
                emittedAt: fixedDate(1),
                kunlunInputs: ki,
                cthulhuInputs: ci))
        await observer.recordEmission(
            .uncovered(
                turnID: "t3",
                sessionID: "s",
                emittedAt: fixedDate(2)))
        await observer.recordEmission(
            .kunlunOnly(
                turnID: "t4",
                sessionID: "s",
                emittedAt: fixedDate(3),
                kunlunInputs: ki))
        let emissionCount = await observer.emissionCount
        let fullCount = await observer.fullyCoveredCount
        let coldCount = await observer.coldEmissionCount
        let ratio = await observer.fullyCoveredRatio
        let cum =
            await observer.cumulativePopulatedBlockCount
        let distinct = await observer.distinctTurnCount
        XCTAssertEqual(emissionCount, 4)
        XCTAssertEqual(fullCount, 2)
        XCTAssertEqual(coldCount, 1)
        XCTAssertEqual(ratio, 0.5, accuracy: 1e-6)
        XCTAssertEqual(cum, 5)
        XCTAssertEqual(distinct, 4)
    }

    // MARK: - 5) Snapshot returns immutable copy

    func testSnapshotIsImmutableCopy() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        await observer.recordEmission(
            .uncovered(
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate()))
        var snap = await observer.snapshot()
        snap.removeAll()  // Mutates the local copy
        // Observer state must NOT be affected
        let count = await observer.emissionCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - 6) reset clears state

    func testResetClearsState() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        await observer.recordEmission(
            .fullyCovered(
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate(),
                kunlunInputs: ki,
                cthulhuInputs: ci))
        let beforeReset = await observer.emissionCount
        XCTAssertEqual(beforeReset, 1)
        await observer.reset()
        let countAfter = await observer.emissionCount
        let fullAfter = await observer.fullyCoveredCount
        let cumAfter =
            await observer.cumulativePopulatedBlockCount
        XCTAssertEqual(countAfter, 0)
        XCTAssertEqual(fullAfter, 0)
        XCTAssertEqual(cumAfter, 0)
    }
}
