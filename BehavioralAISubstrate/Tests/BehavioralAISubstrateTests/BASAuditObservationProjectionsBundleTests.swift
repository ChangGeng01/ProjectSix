// MARK: - BASAuditObservationProjectionsBundleTests
// chapter 五百十二 / M1427 — 12th BASBundle<Item> adoption
//
// PROOF tests for the typed BASBundle wrapping projection-
// block observations:
//   1. Empty bundle reports zero rollups
//   2. Coverage rollups (fullyCoveredTurnCount, etc.)
//      compute correctly
//   3. snapshotAsBundle bridge from observer works
//   4. Codable round-trip via sortedKeys JSON
//   5. Hashable conformance + value equality
//   6. Distinct-turn count works as expected
//   7. Filtered accessors (kunlunCoveredItems /
//      cthulhuCoveredItems) preserve arrival order

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsBundleTests:
    XCTestCase
{

    // MARK: - Fixtures (same pattern as M1425/M1426)

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
            leaseID: "lease-bundle",
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
            reasonCodes: ["bundle"],
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

    // MARK: - 1) Empty bundle reports zero rollups

    func testEmptyBundleReportsZeroRollups() {
        let bundle = BASAuditObservationProjectionsBundle(
            items: [])
        XCTAssertEqual(bundle.count, 0)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 0)
        XCTAssertEqual(bundle.coldTurnCount, 0)
        XCTAssertEqual(bundle.fullyCoveredTurnRatio, 0)
        XCTAssertEqual(
            bundle.cumulativePopulatedBlockCount, 0)
        XCTAssertEqual(bundle.distinctTurnCount, 0)
        XCTAssertEqual(bundle.kunlunCoveredItems, [])
        XCTAssertEqual(bundle.cthulhuCoveredItems, [])
    }

    // MARK: - 2) Coverage rollups compute correctly

    func testCoverageRollupsComputeCorrectly() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let items:
            [BASAuditObservationProjectionsBundleObservation]
            = [
                .fullyCovered(
                    turnID: "t1",
                    sessionID: "s",
                    emittedAt: fixedDate(0),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
                .fullyCovered(
                    turnID: "t2",
                    sessionID: "s",
                    emittedAt: fixedDate(1),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
                .uncovered(
                    turnID: "t3",
                    sessionID: "s",
                    emittedAt: fixedDate(2)),
                .kunlunOnly(
                    turnID: "t4",
                    sessionID: "s",
                    emittedAt: fixedDate(3),
                    kunlunInputs: ki),
            ]
        let bundle = BASAuditObservationProjectionsBundle(
            items: items)
        XCTAssertEqual(bundle.count, 4)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 2)
        XCTAssertEqual(bundle.coldTurnCount, 1)
        XCTAssertEqual(
            bundle.fullyCoveredTurnRatio, 0.5,
            accuracy: 1e-6)
        XCTAssertEqual(
            bundle.cumulativePopulatedBlockCount, 5)
        XCTAssertEqual(bundle.distinctTurnCount, 4)
    }

    // MARK: - 3) snapshotAsBundle bridge

    func testObserverSnapshotAsBundleBridge() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        await observer.recordFullyCoveredEmission(
            turnID: "t1",
            sessionID: "s",
            emittedAt: fixedDate(0),
            kunlunInputs: ki,
            cthulhuInputs: ci)
        await observer.recordEmission(
            .uncovered(
                turnID: "t2",
                sessionID: "s",
                emittedAt: fixedDate(1)))
        let bundle = await observer.snapshotAsBundle()
        XCTAssertEqual(bundle.count, 2)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 1)
        XCTAssertEqual(bundle.coldTurnCount, 1)
        XCTAssertEqual(bundle.items[0].turnID, "t1")
        XCTAssertEqual(bundle.items[1].turnID, "t2")
    }

    // MARK: - 4) Codable round-trip

    func testCodableRoundTripPreservesData() throws {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let bundle = BASAuditObservationProjectionsBundle(
            bundleID: "bundle-codable-1",
            items: [
                .fullyCovered(
                    turnID: "t1",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
                .uncovered(
                    turnID: "t2",
                    sessionID: "s",
                    emittedAt: fixedDate(1)),
            ],
            recordedAt: fixedDate(10))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            BASAuditObservationProjectionsBundle.self,
            from: data)
        XCTAssertEqual(decoded, bundle)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(
            decoded.fullyCoveredTurnCount, 1)
    }

    // MARK: - 5) Equatable + Codable + Sendable conformance

    func testEquatableAndValueEquality() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        // Pin bundleID + recordedAt for deterministic
        // equality (default init uses UUID + Date()).
        let pinnedID = "bundle-pin-1"
        let pinnedAt = Date(
            timeIntervalSince1970: 1_705_000_000)
        let b1 = BASAuditObservationProjectionsBundle(
            bundleID: pinnedID,
            items: [
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
            ],
            recordedAt: pinnedAt)
        let b2 = BASAuditObservationProjectionsBundle(
            bundleID: pinnedID,
            items: [
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
            ],
            recordedAt: pinnedAt)
        XCTAssertEqual(b1, b2)
    }

    // MARK: - 6) Filtered accessors preserve arrival order

    func testFilteredAccessorsPreserveArrivalOrder() {
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let bundle = BASAuditObservationProjectionsBundle(
            items: [
                .kunlunOnly(
                    turnID: "t1",
                    sessionID: "s",
                    emittedAt: fixedDate(0),
                    kunlunInputs: ki),
                .uncovered(
                    turnID: "t2",
                    sessionID: "s",
                    emittedAt: fixedDate(1)),
                .cthulhuOnly(
                    turnID: "t3",
                    sessionID: "s",
                    emittedAt: fixedDate(2),
                    cthulhuInputs: ci),
                .fullyCovered(
                    turnID: "t4",
                    sessionID: "s",
                    emittedAt: fixedDate(3),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
            ])
        // kunlunCoveredItems = items where kunlunCovered=true
        // t1 (kunlunOnly) + t4 (fullyCovered) = 2 items
        XCTAssertEqual(
            bundle.kunlunCoveredItems.count, 2)
        XCTAssertEqual(
            bundle.kunlunCoveredItems[0].turnID, "t1")
        XCTAssertEqual(
            bundle.kunlunCoveredItems[1].turnID, "t4")
        // cthulhuCoveredItems = t3 + t4
        XCTAssertEqual(
            bundle.cthulhuCoveredItems.count, 2)
        XCTAssertEqual(
            bundle.cthulhuCoveredItems[0].turnID, "t3")
        XCTAssertEqual(
            bundle.cthulhuCoveredItems[1].turnID, "t4")
    }

    // MARK: - 7) Distinct turn count handles dups

    func testDistinctTurnCountHandlesRepeatedTurnIDs() {
        let bundle = BASAuditObservationProjectionsBundle(
            items: [
                .uncovered(
                    turnID: "t1",
                    sessionID: "s",
                    emittedAt: fixedDate(0)),
                .uncovered(
                    turnID: "t1",  // dup
                    sessionID: "s",
                    emittedAt: fixedDate(1)),
                .uncovered(
                    turnID: "t2",
                    sessionID: "s",
                    emittedAt: fixedDate(2)),
            ])
        XCTAssertEqual(bundle.count, 3)
        XCTAssertEqual(bundle.distinctTurnCount, 2)
    }
}
