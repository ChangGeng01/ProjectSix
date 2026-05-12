// MARK: - BASEndOfTurnAuditEmitterProjectionPipelineTests
// chapter 五百十三 / M1431 — 5th pipeline wire-in tests
//
// PROOF tests for the M1431 5th pipeline (projection-
// block observer) wired into BASEndOfTurnAuditEmitter:
//   1. Emitter with nil observer omits pipeline 5
//   2. Emitter with observer + records emits pipeline 5
//   3. hasProjectionBlockObserver flag reflects state
//   4. connectedPipelineCount counts up to 5
//   5. Empty observer snapshot returns empty bundle
//   6. snapshotAsBundle preserves arrival order

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASEndOfTurnAuditEmitterProjectionPipelineTests:
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
            leaseID: "lease-p5w",
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
            reasonCodes: ["p5w"],
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

    private func fixedDate(_ offset: TimeInterval = 0)
        -> Date
    {
        return Date(
            timeIntervalSince1970: 1_705_000_000 + offset)
    }

    // MARK: - 1) Emitter with nil observer omits P5

    func testEmitterWithNilObserverOmitsP5() async {
        let emitter = BASEndOfTurnAuditEmitter(
            projectionBlockObserver: nil)
        let record = await emitter.emit(
            turnID: "t",
            recordedAtMs: 1)
        XCTAssertNil(record.projectionBlockObservations)
        XCTAssertEqual(record.populatedPipelineCount, 0)
    }

    // MARK: - 2) Emitter with observer + records emits P5

    func testEmitterWithObserverAndRecordsEmitsP5()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        await observer.recordFullyCoveredEmission(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate(),
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs())
        let emitter = BASEndOfTurnAuditEmitter(
            projectionBlockObserver: observer)
        let record = await emitter.emit(
            turnID: "t",
            recordedAtMs: 1)
        XCTAssertNotNil(
            record.projectionBlockObservations)
        XCTAssertEqual(
            record.projectionBlockObservations?.count, 1)
        XCTAssertEqual(record.populatedPipelineCount, 1)
    }

    // MARK: - 3) hasProjectionBlockObserver flag

    func testHasProjectionBlockObserverFlag() {
        let withObs = BASEndOfTurnAuditEmitter(
            projectionBlockObserver:
                BASAuditObservationProjectionsBundleObserver())
        let withoutObs = BASEndOfTurnAuditEmitter(
            projectionBlockObserver: nil)
        XCTAssertTrue(
            withObs.hasProjectionBlockObserver)
        XCTAssertFalse(
            withoutObs.hasProjectionBlockObserver)
    }

    // MARK: - 4) connectedPipelineCount counts up to 5

    func testConnectedPipelineCountCountsUpToFive() {
        let none = BASEndOfTurnAuditEmitter()
        XCTAssertEqual(none.connectedPipelineCount, 0)
        let p5only = BASEndOfTurnAuditEmitter(
            projectionBlockObserver:
                BASAuditObservationProjectionsBundleObserver())
        XCTAssertEqual(p5only.connectedPipelineCount, 1)
    }

    // MARK: - 5) Empty observer snapshot returns empty bundle

    func testEmptyObserverProducesEmptyBundle() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let emitter = BASEndOfTurnAuditEmitter(
            projectionBlockObserver: observer)
        let record = await emitter.emit(
            turnID: "t",
            recordedAtMs: 1)
        XCTAssertNotNil(
            record.projectionBlockObservations)
        XCTAssertEqual(
            record.projectionBlockObservations?.count, 0,
            "empty observer must produce empty bundle" +
            " (not nil)")
    }

    // MARK: - 6) Arrival order preserved through emitter

    func testArrivalOrderPreservedThroughEmitter()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        await observer.recordEmission(
            .uncovered(
                turnID: "t1",
                sessionID: "s",
                emittedAt: fixedDate(0)))
        await observer.recordFullyCoveredEmission(
            turnID: "t2",
            sessionID: "s",
            emittedAt: fixedDate(1),
            kunlunInputs: makeKunlunInputs(),
            cthulhuInputs: makeCthulhuInputs())
        await observer.recordEmission(
            .kunlunOnly(
                turnID: "t3",
                sessionID: "s",
                emittedAt: fixedDate(2),
                kunlunInputs: makeKunlunInputs()))
        let emitter = BASEndOfTurnAuditEmitter(
            projectionBlockObserver: observer)
        let record = await emitter.emit(
            turnID: "turn-meta",
            recordedAtMs: 99)
        let bundle = record.projectionBlockObservations!
        XCTAssertEqual(bundle.count, 3)
        XCTAssertEqual(bundle.items[0].turnID, "t1")
        XCTAssertEqual(bundle.items[1].turnID, "t2")
        XCTAssertEqual(bundle.items[2].turnID, "t3")
    }
}
