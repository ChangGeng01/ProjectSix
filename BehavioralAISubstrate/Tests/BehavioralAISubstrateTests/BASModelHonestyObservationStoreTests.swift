import XCTest
@testable import BASSovereign

/// ②-observe durable sink — the per-turn honesty record + its DEFAULT-OFF opt-in seam.
/// The no-op-when-disabled property is the safety contract (a non-opting host is byte-equal),
/// so it is tested explicitly.
final class BASModelHonestyObservationStoreTests: XCTestCase {

    func testEnvGateDefaultsOff() {
        XCTAssertFalse(BASModelHonestyObservation.isObservationEnabled([:]),
                       "no env ⇒ observation OFF (byte-equal no-op)")
        XCTAssertFalse(BASModelHonestyObservation.isObservationEnabled(["BAS_HONESTY_OBSERVE": "0"]))
        XCTAssertTrue(BASModelHonestyObservation.isObservationEnabled(["BAS_HONESTY_OBSERVE": "1"]))
    }

    func testDisabledIsPureNoOp() async {
        let store = BASInMemoryModelHonestyObservationStore()
        let rec = await BASModelHonestyObservation.recordIfEnabled(
            body: "You absolutely nailed it, pure genius!",
            sessionID: "s1", turnID: "t1", eventID: "e1", observedAtMs: 0,
            into: store, enabled: false)
        XCTAssertNil(rec, "disabled ⇒ returns nil")
        let n = await store.count()
        XCTAssertEqual(n, 0, "disabled ⇒ store untouched (byte-equal no-op)")
    }

    func testEnabledRecordsTheBand() async {
        let store = BASInMemoryModelHonestyObservationStore()
        let rec = await BASModelHonestyObservation.recordIfEnabled(
            body: "You absolutely nailed it, pure genius, no notes!",
            sessionID: "s1", turnID: "t1", eventID: "e1", observedAtMs: 123,
            into: store, enabled: true)
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.flatteryBand, .high, "flagrant flattery is observed high")
        XCTAssertEqual(rec?.observedAtMs, 123, "caller-supplied timestamp preserved (deterministic)")
        let recs = await store.records(forSession: "s1")
        XCTAssertEqual(recs.count, 1)
    }

    func testHonestReplyRecordsOk() async {
        let store = BASInMemoryModelHonestyObservationStore()
        let rec = await BASModelHonestyObservation.recordIfEnabled(
            body: "I can't confirm it's a billion-dollar idea; I'm happy to review the risks.",
            sessionID: "s1", turnID: "t1", eventID: "e1", observedAtMs: 1,
            into: store, enabled: true)
        XCTAssertEqual(rec?.flatteryBand, .ok, "honest decline is observed ok")
    }

    func testDuplicateEventIDRejected() async {
        let store = BASInMemoryModelHonestyObservationStore()
        let r = BASModelHonestyObservationRecord(
            eventID: "dup", sessionID: "s", turnID: "t",
            axes: BASModelHonestySignal.axes("neutral text"), observedAtMs: 0)
        _ = try? await store.appendRecord(r)
        var threw = false
        do { _ = try await store.appendRecord(r) } catch { threw = true }
        XCTAssertTrue(threw, "duplicate eventID must be rejected (idempotent ledger)")
    }
}
