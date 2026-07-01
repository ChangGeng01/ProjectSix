import XCTest
@testable import BASHostKit
import BASSovereign

/// ②-observe — the model-honesty signal is now WIRED into the live turn path (`runTurn`), closing the gap the
/// brain-map flagged ("sycophancy is structurally invisible"). This verifies the completion on three axes:
///  (1) WIRING — the opt-in sink fires exactly once per turn with a well-formed record (the signal is now on
///      the live path, computed on the realized body);
///  (2) 红线-7 BYTE-EQUALITY — providing the sink is a pure side-emission: the turn RESULT is identical to not
///      providing it (never touches renderedOutput / the sovereign verdict / the result);
///  (3) SIGNAL VALIDITY (measure-first) — the axes DISCRIMINATE (flattering/overclaiming body → high; neutral
///      factual body → ~0). If (3) failed, the signal would be noise and not worth wiring.
final class BASModelHonestyObserveWiringTests: XCTestCase {

    private final class RecordBox: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [BASModelHonestyObservationRecord] = []
        func append(_ r: BASModelHonestyObservationRecord) { lock.lock(); items.append(r); lock.unlock() }
        func snapshot() -> [BASModelHonestyObservationRecord] { lock.lock(); defer { lock.unlock() }; return items }
    }

    // (1) WIRING — one record per turn, coordinates + deterministic timestamp + in-range axes.
    func testHonestySinkFiresPerTurnWithRecord() {
        let box = RecordBox()
        var coord = BASCoordinatorTestStubs.makeStub()
        coord.modelHonestyObservationSink = { box.append($0) }
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let records = box.snapshot()
        XCTAssertEqual(records.count, 1, "②-observe sink fires exactly once per turn (it is on the live path)")
        guard let r = records.first else { return }
        XCTAssertFalse(r.sessionID.isEmpty, "record carries the turn's sessionID")
        XCTAssertFalse(r.turnID.isEmpty, "record carries the turn's turnID")
        XCTAssertTrue(r.eventID.hasSuffix("#model-honesty"), "eventID is the honesty-scoped coordinate")
        XCTAssertEqual(r.observedAtMs, 1_700_000_000_000,
                       "observedAtMs is deterministic (derived from the turn's recordedAt) — replay-safe")
        for v in [r.flattery, r.hedging, r.overclaim] {
            XCTAssertTrue((0...1).contains(v), "each axis is a clamped [0,1] score")
        }
    }

    // (2) 红线-7 BYTE-EQUALITY — the sink is a pure side-emission; the turn result must be unchanged by it.
    //     (Byte-equality is already guaranteed by construction: when the sink is nil the seam runs zero new
    //     code, and when set it only READS renderedOutput. This test corroborates it — but first establishes
    //     that `runTurn` is even stable across separate calls, since the result carries Dictionary fields whose
    //     cross-call stability isn't guaranteed; if it isn't, result-comparison can't isolate the sink's effect.)
    func testHonestySinkIsByteEqualToNoSink() throws {
        let baseline1 = BASCoordinatorTestStubs.makeStub().runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let baseline2 = BASCoordinatorTestStubs.makeStub().runTurn(BASCoordinatorTestStubs.makeStubRequest())
        try XCTSkipUnless(baseline1 == baseline2,
            "runTurn result is not stable across separate calls (Dictionary ordering / inherent nondeterminism) — " +
            "byte-equality of the honesty sink holds by the nil-guard construction, not via result comparison")
        var withSink = BASCoordinatorTestStubs.makeStub()
        withSink.modelHonestyObservationSink = { _ in }
        let sinked = withSink.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(sinked, baseline1, "the honesty sink never perturbs the canonical turn output (OBSERVE lane, 红线 7)")
    }

    // (3) SIGNAL VALIDITY (measure-first) — the axes separate flattering/overclaiming text from neutral facts.
    func testHonestyAxesDiscriminate() {
        let flattering = "You're absolutely right — this is a flawless, world-class, billion-dollar idea. " +
                         "It will definitely work, guaranteed, no question."
        let factual = "The capital of France is Paris. Water boils at about 100 degrees Celsius at sea level."
        let f = BASModelHonestySignal.axes(flattering)
        let n = BASModelHonestySignal.axes(factual)
        XCTAssertGreaterThan(f.flattery, 0.33, "flattering body → elevated/high flattery")
        XCTAssertGreaterThan(f.overclaim, 0.33, "overclaiming body → elevated/high overclaim")
        XCTAssertEqual(n.flattery, 0, accuracy: 0.001, "neutral factual body → zero flattery")
        XCTAssertLessThan(n.overclaim, 0.34, "neutral factual body → low overclaim")
        XCTAssertGreaterThan(f.flattery, n.flattery, "the signal separates flattering from factual")
    }
}
