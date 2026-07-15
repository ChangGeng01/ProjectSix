import XCTest
@testable import BASHostKit

/// gaps-reconciliation hostkit-rest LOW-4 (2026-07-11): the advisory ledger's stored array grew
/// UNBOUNDED (manual reset only). Now a drop-oldest ring capped at maxStoredAdvisories with a
/// droppedAdvisoryCount audit counter — and the honesty AGGREGATES (total/honored/ratio/distinct
/// hosts) are running counters that survive ring drops (a capped ring must not skew them).
final class BASAdvisoryLedgerBoundedGrowthTests: XCTestCase {

    private func advisory(_ i: Int, honored: Bool) -> BASEBrainHostRuntimeModeAdvisory {
        BASEBrainHostRuntimeModeAdvisoryDoctrine.advisoryFor(
            preferredMode: honored ? .v1ByteEqual : .nativeV2,
            hostID: "host-\(i % 3)",
            recordedAtMs: Int64(1_000 + i))
    }

    func testRingCapsStorageAndCountsDrops() async {
        let ledger = BASEBrainHostRuntimeModeAdvisoryLedger(maxStoredAdvisories: 8)
        for i in 0..<20 { await ledger.record(advisory: advisory(i, honored: i % 2 == 0)) }
        let stored = await ledger.allAdvisories()
        XCTAssertEqual(stored.count, 8, "stored ring holds exactly the cap")
        let dropped = await ledger.droppedAdvisoryCount
        XCTAssertEqual(dropped, 12, "every eviction is audited")
        // drop-OLDEST: the survivors are the 12..<20 tail, in arrival order
        XCTAssertEqual(stored.first?.recordedAtMs, 1_012)
        XCTAssertEqual(stored.last?.recordedAtMs, 1_019)
    }

    func testAggregatesSurviveRingDrops() async {
        let ledger = BASEBrainHostRuntimeModeAdvisoryLedger(maxStoredAdvisories: 4)
        for i in 0..<10 { await ledger.record(advisory: advisory(i, honored: i % 2 == 0)) }
        let total = await ledger.totalAdvisoryCount
        let honored = await ledger.honoredAdvisoryCount
        let unhonored = await ledger.unhonoredAdvisoryCount
        let ratio = await ledger.honoredRatio
        let hosts = await ledger.distinctHostCount
        XCTAssertEqual(total, 10, "total is a running counter, not the ring size")
        XCTAssertEqual(honored, 5)
        XCTAssertEqual(unhonored, 5)
        XCTAssertEqual(ratio, 0.5, accuracy: 1e-12,
            "honoredRatio reflects ALL advisories ever recorded — the ring cap must not skew it")
        XCTAssertEqual(hosts, 3, "distinct hosts survive drops")
    }

    func testUnboundedOptOutStoresEverything() async {
        let ledger = BASEBrainHostRuntimeModeAdvisoryLedger(maxStoredAdvisories: nil)
        for i in 0..<50 { await ledger.record(advisory: advisory(i, honored: true)) }
        let stored = await ledger.allAdvisories()
        XCTAssertEqual(stored.count, 50, "nil cap = the explicit unbounded replay-test mode")
        let dropped = await ledger.droppedAdvisoryCount
        XCTAssertEqual(dropped, 0)
    }
}
