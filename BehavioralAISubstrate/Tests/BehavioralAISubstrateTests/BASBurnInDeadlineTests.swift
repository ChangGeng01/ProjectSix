import XCTest
@testable import BASRuntimeCore

/// audit M-i MED-4 — the burn-in deadline state machine, now Mac-verified.
/// The device instrument's runM4 uses BASBurnInDeadline; this proves the guard
/// that a plateau does NOT end the run mid-burn-in (the invalid-measurement bug).
final class BASBurnInDeadlineTests: XCTestCase {

    private let window = 12.0 * 60, burnCap = 20.0 * 60

    func testAtPlateauEntersBurnInWithTheCapNotTheWindow() {
        let d = BASBurnInDeadline.atUnplug(nowEpoch: 1000, atPlateau: true,
                                           windowSec: window, burnCapSec: burnCap)
        XCTAssertTrue(d.burning)
        XCTAssertEqual(d.deadlineEpoch, 1000 + burnCap, "plateau ⇒ deadline is the 20-min burn cap")
        XCTAssertNotEqual(d.deadlineEpoch, 1000 + window, "must NOT arm the 12-min counted window")
    }

    func testNotAtPlateauArmsTheCountedWindow() {
        let d = BASBurnInDeadline.atUnplug(nowEpoch: 1000, atPlateau: false,
                                           windowSec: window, burnCapSec: burnCap)
        XCTAssertFalse(d.burning)
        XCTAssertEqual(d.deadlineEpoch, 1000 + window)
    }

    /// THE MED-4 GUARD: a plateau that outlasts the window must NOT expire the run
    /// while burning — the burn cap (20 min) governs, not the 12-min window.
    func testPlateauOutlastingWindowDoesNotEndRunMidBurnIn() {
        let d = BASBurnInDeadline.atUnplug(nowEpoch: 0, atPlateau: true,
                                           windowSec: window, burnCapSec: burnCap)
        // 13 min in, still at plateau (battery ≥ 99.5) — a sample must NOT restart/expire.
        let still = d.onSample(nowEpoch: 13 * 60, plugged: false, batteryPct: 99.8)
        XCTAssertTrue(still.burning, "still burning at the plateau")
        XCTAssertFalse(still.isExpired(nowEpoch: 13 * 60),
            "13 min < 20-min burn cap — the run must NOT end mid-burn-in (the invalid-M4 bug)")
    }

    /// Burn-in completes when the reading first dips → a FRESH counted window starts.
    func testDipEndsBurnInAndRestartsCountedWindow() {
        let d = BASBurnInDeadline.atUnplug(nowEpoch: 0, atPlateau: true,
                                           windowSec: window, burnCapSec: burnCap)
        let dipped = d.onSample(nowEpoch: 15 * 60, plugged: false, batteryPct: 99.3)
        XCTAssertFalse(dipped.burning, "reading dipped ⇒ burn-in complete")
        XCTAssertEqual(dipped.deadlineEpoch, 15 * 60 + window, "counted window restarts at the dip")
    }

    /// Plugged samples never end burn-in (charging invalidates the delta).
    func testPluggedSampleDoesNotEndBurnIn() {
        let d = BASBurnInDeadline.atUnplug(nowEpoch: 0, atPlateau: true,
                                           windowSec: window, burnCapSec: burnCap)
        let plugged = d.onSample(nowEpoch: 5 * 60, plugged: true, batteryPct: 40)
        XCTAssertTrue(plugged.burning, "a plugged reading must not end burn-in")
    }
}
