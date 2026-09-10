import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-03` ContaminationGuard.
///
/// The guard is the *memory* of sovereign-decreed contamination. The
/// tests here exercise each lifecycle edge — explicit quarantine,
/// verdict-driven quarantine, kind isolation, batch probe, and lift —
/// because a bug in any of them either leaks tainted data into a
/// retrieval path or blocks clean data for no reason.
final class BASSovereignContaminationGuardTests: XCTestCase {
    func testDefaultIsClean() async {
        let guardActor = BASSovereignContaminationGuard()
        let isQ = await guardActor.isQuarantined(id: "atom-1", kind: .memoryAtom)
        XCTAssertFalse(isQ, "default world must be clean")
    }

    func testExplicitQuarantineIsRemembered() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "atom-1", kind: .memoryAtom, reasonCode: "BR-003")

        let isQ = await guardActor.isQuarantined(id: "atom-1", kind: .memoryAtom)
        XCTAssertTrue(isQ)

        let rec = await guardActor.record(id: "atom-1", kind: .memoryAtom)
        XCTAssertEqual(rec?.reasonCode, "BR-003")
    }

    func testKindsAreIsolated() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "x", kind: .memoryAtom, reasonCode: "BR-003")

        let asMemory = await guardActor.isQuarantined(id: "x", kind: .memoryAtom)
        let asTool = await guardActor.isQuarantined(id: "x", kind: .toolOutput)
        XCTAssertTrue(asMemory)
        XCTAssertFalse(asTool, "same id under a different kind must not inherit quarantine")
    }

    func testApplyVerdictBelowQuarantineLevelIsNoop() async {
        let guardActor = BASSovereignContaminationGuard()
        let softVerdict = BASSovereignVerdict(
            verdictID: "v-soft",
            verdictLevel: .throttle,
            latched: false,
            reasonCodes: ["SOFT"],
            revokedPermissions: [],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        await guardActor.apply(verdict: softVerdict, quarantining: ["a", "b"], kind: .memoryAtom)

        let count = await guardActor.quarantineCount()
        XCTAssertEqual(count, 0, "throttle verdict must not side-effect the guard")
    }

    func testApplyVerdictAtQuarantineLevelRecordsAllIDs() async {
        let guardActor = BASSovereignContaminationGuard()
        let verdict = BASSovereignVerdict(
            verdictID: "v-q",
            verdictLevel: .quarantine,
            latched: true,
            reasonCodes: ["BR-003"],
            revokedPermissions: [.rulePromotion],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        await guardActor.apply(verdict: verdict, quarantining: ["a", "b", "c"], kind: .memoryAtom)

        for id in ["a", "b", "c"] {
            let isQ = await guardActor.isQuarantined(id: id, kind: .memoryAtom)
            XCTAssertTrue(isQ, "\(id) must be quarantined")
        }
        let rec = await guardActor.record(id: "a", kind: .memoryAtom)
        XCTAssertEqual(rec?.originatingVerdictID, "v-q")
    }

    func testApplyVerdictAtRollbackOrDeadStopAlsoQuarantines() async {
        let guardActor = BASSovereignContaminationGuard()
        let rollback = BASSovereignVerdict(
            verdictID: "v-r",
            verdictLevel: .rollback,
            latched: true,
            reasonCodes: ["BR-002"],
            revokedPermissions: [],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        await guardActor.apply(verdict: rollback, quarantining: ["fold-1"], kind: .memoryAtom)
        let isQ = await guardActor.isQuarantined(id: "fold-1", kind: .memoryAtom)
        XCTAssertTrue(isQ, "rollback (rank > quarantine) must still record quarantine")
    }

    func testProbeReportsMixedResults() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "bad-1", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "bad-2", kind: .memoryAtom, reasonCode: "BR-003")

        let report = await guardActor.probe(ids: ["bad-1", "good-1", "bad-2", "good-2"], kind: .memoryAtom)
        XCTAssertEqual(Set(report.quarantinedIDs), ["bad-1", "bad-2"])
        XCTAssertEqual(Set(report.cleanIDs), ["good-1", "good-2"])
        XCTAssertTrue(report.hasQuarantinedHits,
                      "probe must surface the BR-003 spread signal")
    }

    func testLiftRemovesSingleQuarantine() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "a", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "b", kind: .memoryAtom, reasonCode: "BR-003")

        await guardActor.lift(id: "a", kind: .memoryAtom)

        let aQ = await guardActor.isQuarantined(id: "a", kind: .memoryAtom)
        let bQ = await guardActor.isQuarantined(id: "b", kind: .memoryAtom)
        XCTAssertFalse(aQ)
        XCTAssertTrue(bQ)
    }

    func testLiftAllByKindIsScoped() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "m", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "t", kind: .toolOutput, reasonCode: "BR-010")

        await guardActor.liftAll(kind: .memoryAtom)

        let mQ = await guardActor.isQuarantined(id: "m", kind: .memoryAtom)
        let tQ = await guardActor.isQuarantined(id: "t", kind: .toolOutput)
        XCTAssertFalse(mQ, "memoryAtom lift must clear the memory entry")
        XCTAssertTrue(tQ, "toolOutput entry must survive a memoryAtom-scoped lift")
    }

    func testQuarantineIsIdempotent() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "a", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "a", kind: .memoryAtom, reasonCode: "BR-003-AGAIN")

        let count = await guardActor.quarantineCount(kind: .memoryAtom)
        XCTAssertEqual(count, 1, "re-quarantining same key must not duplicate")

        let rec = await guardActor.record(id: "a", kind: .memoryAtom)
        XCTAssertEqual(rec?.reasonCode, "BR-003-AGAIN",
                       "re-quarantine must overwrite metadata with the latest reason")
    }

    func testDiagnosticsCountsByKindAndTotal() async {
        let guardActor = BASSovereignContaminationGuard()
        await guardActor.quarantine(id: "m1", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "m2", kind: .memoryAtom, reasonCode: "BR-003")
        await guardActor.quarantine(id: "t1", kind: .toolOutput, reasonCode: "BR-010")

        let total = await guardActor.quarantineCount()
        let mem = await guardActor.quarantineCount(kind: .memoryAtom)
        let tool = await guardActor.quarantineCount(kind: .toolOutput)
        let host = await guardActor.quarantineCount(kind: .hostVaultEntry)

        XCTAssertEqual(total, 3)
        XCTAssertEqual(mem, 2)
        XCTAssertEqual(tool, 1)
        XCTAssertEqual(host, 0)
    }
}
