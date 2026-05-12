// MARK: - BASAuditObservationProjectionsBundleObservationTests
// chapter 五百十二 / M1425 — wire-in chain start
//
// PROOF tests for the per-turn projection-block observation
// record:
//   1. fullyCovered factory builds both-blocks record
//   2. kunlunOnly + cthulhuOnly factories build partial
//   3. uncovered factory builds no-blocks record
//   4. Coverage query accessors (hasBothBlocks /
//      hasNoBlocks / populatedBlockCount)
//   5. Hashable + Equatable + Codable round-trip
//   6. Determinism — same inputs produce same hashes

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsBundleObservationTests:
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
            leaseID: "lease-obs",
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
            reasonCodes: ["obs"],
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
                turnID: "turn-obs",
                sessionID: "session-obs",
                kunlunAxisID: "axis-obs"),
            hexa: BASTurnAuditProjectionsKunlunHexa.compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                permit: permit,
                candidates: candidates,
                turnID: "turn-obs"),
            trioTwo:
                BASTurnAuditProjectionsKunlunTrioTwo
                    .compute(
                        runMode: budget.runMode,
                        riskLevel: .medium,
                        candidates: candidates,
                        organRefMorph: "morph.a",
                        turnID: "turn-obs",
                        sessionID: "session-obs"),
            hexaTwo:
                BASTurnAuditProjectionsKunlunHexaTwo
                    .compute(
                        hostID: "host-obs",
                        sessionID: "session-obs",
                        turnID: "turn-obs",
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
                    turnID: "turn-obs")
        let penta = BASTurnAuditProjectionsCthulhuPenta
            .compute(
                routedBudget: budget,
                runMode: budget.runMode,
                hostID: "host-obs",
                riskLevel: .medium,
                memoryTemperatureLayer:
                    trio.memoryTemperatureLayer,
                candidates: makeCandidates(),
                unknownRefs: ["u-1"],
                assertionCeilingRaw:
                    BASUnknownAssertionCeiling.qualified
                        .rawValue,
                turnID: "turn-obs")
        return BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio: trio,
            cthulhuPenta: penta)
    }

    private func fixedDate() -> Date {
        return Date(timeIntervalSince1970: 1_705_000_000)
    }

    // MARK: - 1) fullyCovered factory

    func testFullyCoveredFactoryBuildsBothBlocksRecord() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t1",
                    sessionID: "s1",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        XCTAssertEqual(obs.turnID, "t1")
        XCTAssertEqual(obs.sessionID, "s1")
        XCTAssertEqual(obs.emittedAt, fixedDate())
        XCTAssertTrue(obs.kunlunCovered)
        XCTAssertTrue(obs.cthulhuCovered)
        XCTAssertEqual(
            obs.kunlunInputsHash, ki.hashValue)
        XCTAssertEqual(
            obs.cthulhuInputsHash, ci.hashValue)
    }

    // MARK: - 2) Partial factories

    func testKunlunOnlyFactoryBuildsPartialRecord() {
        let ki = makeKunlunInputs()
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .kunlunOnly(
                    turnID: "t2",
                    sessionID: "s1",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki)
        XCTAssertTrue(obs.kunlunCovered)
        XCTAssertFalse(obs.cthulhuCovered)
        XCTAssertEqual(
            obs.kunlunInputsHash, ki.hashValue)
        XCTAssertNil(obs.cthulhuInputsHash)
    }

    func testCthulhuOnlyFactoryBuildsPartialRecord() {
        let ci = makeCthulhuInputs()
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .cthulhuOnly(
                    turnID: "t3",
                    sessionID: "s1",
                    emittedAt: fixedDate(),
                    cthulhuInputs: ci)
        XCTAssertFalse(obs.kunlunCovered)
        XCTAssertTrue(obs.cthulhuCovered)
        XCTAssertNil(obs.kunlunInputsHash)
        XCTAssertEqual(
            obs.cthulhuInputsHash, ci.hashValue)
    }

    // MARK: - 3) uncovered factory

    func testUncoveredFactoryBuildsNoBlocksRecord() {
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .uncovered(
                    turnID: "t4",
                    sessionID: "s1",
                    emittedAt: fixedDate())
        XCTAssertFalse(obs.kunlunCovered)
        XCTAssertFalse(obs.cthulhuCovered)
        XCTAssertNil(obs.kunlunInputsHash)
        XCTAssertNil(obs.cthulhuInputsHash)
    }

    // MARK: - 4) Coverage query accessors

    func testCoverageQueryAccessors() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let bothBlocks =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        XCTAssertTrue(bothBlocks.hasBothBlocks)
        XCTAssertFalse(bothBlocks.hasNoBlocks)
        XCTAssertEqual(bothBlocks.populatedBlockCount, 2)
        let kOnly =
            BASAuditObservationProjectionsBundleObservation
                .kunlunOnly(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki)
        XCTAssertFalse(kOnly.hasBothBlocks)
        XCTAssertFalse(kOnly.hasNoBlocks)
        XCTAssertEqual(kOnly.populatedBlockCount, 1)
        let none =
            BASAuditObservationProjectionsBundleObservation
                .uncovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate())
        XCTAssertFalse(none.hasBothBlocks)
        XCTAssertTrue(none.hasNoBlocks)
        XCTAssertEqual(none.populatedBlockCount, 0)
    }

    // MARK: - 5) Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let original =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsBundleObservation
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 6) Determinism

    func testDeterminismSameInputsProduceSameHashes() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let obs1 =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        let obs2 =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        XCTAssertEqual(obs1, obs2)
        XCTAssertEqual(obs1.hashValue, obs2.hashValue)
        XCTAssertEqual(
            obs1.kunlunInputsHash,
            obs2.kunlunInputsHash)
        XCTAssertEqual(
            obs1.cthulhuInputsHash,
            obs2.cthulhuInputsHash)
    }
}
